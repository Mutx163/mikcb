package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimeSchemeImportUpdate
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.ServiceMessage
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.transfer.buildExpandedSections
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * courses 导入的**收尾落盘层**：节次扩容 + 学期设置 + 课程写回（F32 第二批）。
 *
 * ## 旧版口径（逐条核实 `import_shared.dart` / `timetable_import_export_service.dart`）
 *
 * - **依据最大结束节号**：需要多少节 = 全部课程 `endSection` 的最大值
 *   （Dart `previewImportedCourseRequiredSectionCount`），现有节次表装不下才补；
 * - **时间怎么补**：[buildExpandedSections]（Dart `buildExpandedSections` 的对拍件）——
 *   锚点是「从后往前第一条能解析的结束时间」，时长取最后一段可解析时长（兜底 45 分钟）、
 *   课间取最后一个空隙（兜底 10 分钟）；一条都解析不出、或补到 `24:00` 当天结束就停；
 * - **补不满如实失败**：返回的表比要求短时**不写任何东西**，按 service message
 *   `section_count_below_usage` 报错（Dart `ensureSectionCapacityForImport:386-390`，
 *   2026-10-08 补的洞——静默短表会让部分课导入后没有钟点、用户以为导入成功）；
 * - **与自定义节次表的关系**：扩节只**追加**、绝不改已有条目；有主时间模板时页面读的
 *   是模板节次，写设置不生效，所以写模板（`updateTimeScheme`），否则写设置——与同域
 *   `AiImageImportApply` 的判据同源；
 * - **失败回滚**：任一步失败——**抛异常，或写回层返回 `Failed`**——都把设置（含开学日/
 *   周数/节次表）、主模板节次与（覆盖模式下的）自建日程恢复成导入前的样子。设置与课程
 *   仍是两次独立落盘，没有跨 key 事务；课程写回走 [WarehouseCourseWriteBack.apply] 的
 *   原子入口，并把**导入前快照**传下去当回滚基线（写回层自己的入口快照已被本层写过的
 *   设置污染，见 P0-3）。
 */
object WarehouseCoursesImportApply {

    /** 一次待落盘的 courses 导入：课程已平移、已配色。 */
    data class Request(
        val courses: List<Course>,
        val semesterStartDate: LocalDate,
        val replaceExisting: Boolean,
        val preserveLocalColors: Boolean,
        /** 用户在「时间模板节次不足」确认框里同意了自动补齐。 */
        val expandSections: Boolean,
    )

    sealed interface Result {
        /** 课程写回完成；[importedCount] 为实际新增 + 更新条数。 */
        data class Done(val importedCount: Int) : Result

        /**
         * 失败（已回滚）。[serviceMessage] 非空 = 仓储/校验返回的服务码
         * （如节次补不满），宿主过 [TimeSchemeServiceMessages localize] 再展示。
         */
        data class Failed(val serviceMessage: String?) : Result
    }

    /** 导入课程需要的最大节号（没有课为 0；Dart `previewImportedCourseRequiredSectionCount`）。 */
    fun requiredSectionCount(courses: List<Course>): Int =
        courses.maxOfOrNull { it.endSection } ?: 0

    /** 现有节次表装不装得下：需要到第 [requiredSectionCount] 节而表没有那么多节。 */
    fun needsExpansion(currentSections: List<SectionTime>, requiredSectionCount: Int): Boolean =
        requiredSectionCount > currentSections.size

    /** 当前生效的节次表：有主时间模板取模板，否则取设置里的（与课表页判据同源）。 */
    fun activeSections(settings: TimetableSettings, schemeSections: List<SectionTime>?): List<SectionTime> =
        schemeSections ?: settings.sections

    /** 补节后的表；调用方必须检查长度（补不满是合法结果，不是异常）。 */
    fun expandedSections(currentSections: List<SectionTime>, requiredSectionCount: Int): List<SectionTime> =
        buildExpandedSections(currentSections, requiredSectionCount)

    fun apply(repository: TimetableRepository, request: Request): Result {
        val before = repository.snapshot
        val scheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = before.timeSchemes,
            activeTimeSchemeId = before.activeTimeSchemeId,
        )
        val currentSections = activeSections(before.settings, scheme?.sections)
        val required = requiredSectionCount(request.courses)
        val needsExpansionNow = request.expandSections && needsExpansion(currentSections, required)

        var nextSections = currentSections
        if (needsExpansionNow) {
            nextSections = expandedSections(currentSections, required)
            if (nextSections.size < required) {
                // 补不满：一条结束时间都解析不出 / 当天已无余量。不写任何东西。
                return Result.Failed(
                    ServiceMessage.encode(
                        "section_count_below_usage",
                        mapOf("requiredMaxSection" to required),
                    ),
                )
            }
        }

        /**
         * 共享模板扩容时仓储会新建 `<原名>（导入补齐）` 副本并返回它的 id（不原地改
         * 别人的课表）。失败回滚要先恢复设置、再删掉这份副本，否则留下孤儿模板。
         */
        var createdSchemeId: String? = null

        /**
         * 把本层先行写入的学期设置、主模板节次与（覆盖模式下）自建日程恢复成导入前。
         *
         * **两条失败路径都要调**：本层是「设置先落盘、课程后落盘」，写回层返回 `Failed`
         * 时不抛异常（磁盘满 / `saveActiveProfileId` 抛 / 课程钟点同步抛都经返回值），
         * 旧实现只在 `catch` 里回滚——界面报「导入失败」，盘上却留着新的开学日 / 周数 /
         * 扩出来的节次（P0-3）。只在值真的变了时才写，避免失败路径多一次无谓通知。
         */
        fun rollbackImportState() {
            // 日程是内存态（`scheduleItems` setter 不落盘），必须在写模板之前还原：
            // `updateTimeScheme` 会把内存里的档案整份落盘。
            if (request.replaceExisting && repository.snapshot.scheduleItems != before.scheduleItems) {
                runCatching { repository.scheduleItems = before.scheduleItems }
            }
            if (repository.snapshot.settings != before.settings) {
                runCatching { repository.updateSettings(before.settings) }
            }
            if (needsExpansionNow && scheme != null && createdSchemeId == null) {
                runCatching { repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections) }
            }
            // 恢复设置（已改回原模板引用）之后再删副本，`deleteTimeScheme` 的 in-use 守卫才放行。
            createdSchemeId?.let { created -> runCatching { repository.deleteTimeScheme(created) } }
        }

        return try {
            if (needsExpansionNow) {
                if (scheme != null) {
                    // 有主模板时页面读的是模板节次；模板被别的课表共用时必须复制副本
                    // （`updateTimeSchemeForImport`），不能原地改把别人的课表一起改了。
                    when (val update = repository.updateTimeSchemeForImport(scheme.id, scheme.name, nextSections)) {
                        is TimeSchemeImportUpdate.Rejected -> return Result.Failed(update.serviceMessage)
                        is TimeSchemeImportUpdate.Applied -> createdSchemeId = update.createdSchemeId
                    }
                } else {
                    repository.updateSettings(before.settings.copy(sections = nextSections))
                }
            }
            val settingsNow = repository.snapshot.settings
            // 对齐旧版 importParsedCourses：用户确认的开学日写进设置；周数不够自动扩。
            val requiredWeeks = warehouseMaxCourseWeek(request.courses, settingsNow.semesterWeekCount)
            val nextSettings = settingsNow.copy(
                semesterStartDate = request.semesterStartDate.atStartOfDay(),
                semesterWeekCount = maxOf(settingsNow.semesterWeekCount, requiredWeeks),
            )
            // 无变化的设置写跳过：开学日没动、周数没抬时，落盘+通知纯属全档案级噪音。
            // （合并结果若还需更多周——现有课比导入课更长——下游写回层会补写，见下。）
            if (nextSettings != settingsNow) {
                repository.updateSettings(nextSettings)
            }
            // 开学日确认变更（用户在弹层里改了学期起点）时，课程落盘后按今天重算当前周
            // ——收尾在下面统一做（成功一律重算，见下）。
            val importedCount = when (val result = WarehouseCourseWriteBack.apply(
                repository = repository,
                courses = request.courses,
                requestedMode = if (request.replaceExisting) {
                    WarehouseCourseWriteBack.Mode.REPLACE
                } else {
                    WarehouseCourseWriteBack.Mode.MERGE
                },
                preserveLocalColors = request.preserveLocalColors,
                // 开学日/周数已由本层按导入课写入：显式传 null，写回层不再动开学日；
                // 合并结果（含现有课）的周数若仍需抬升，写回层的「有变化才写」会补上。
                semesterStartDate = null,
                // 用户拒绝扩节时，写回层不得再补节（本层上面已按同一 flag 判断过一次）。
                allowSectionExpansion = request.expandSections,
                // 回滚基线必须是**本层写设置之前**的现场：写回层自己抓的入口快照已经是
                // 「开学日/周数/节次写完之后」的污染值，拿它回滚只能回到半套状态（P0-3）。
                importBaseline = before,
            )) {
                is WarehouseCourseWriteBack.Result.Done -> result.outcome.importedCount
                // 到不了：宿主在进确认流程前已挡掉空课表；防御性按「无事发生」收尾。
                is WarehouseCourseWriteBack.Result.NoImportableCourses -> 0
                is WarehouseCourseWriteBack.Result.Failed -> {
                    // 返回 Failed = 写回层内部已经把异常收成了返回值，不会进下面的 catch。
                    // 旧实现在这里直接 return，本层先写的设置与节次就留在了盘上（P0-3）。
                    rollbackImportState()
                    return Result.Failed(null)
                }
            }
            // 对齐发布版：仓库导入的开学日恒由用户确认（非空），**导入成功一律按今天重算
            // 当前周**（Dart `_timetableImportParsedCourses` 只要 `semesterStart != null` 就
            // 重算，`import_export_service.dart:431`）。不能只在「开学日变了」时重算：上一次
            // 导入失败若已把开学日写进盘（P0-3 的残留现场），重试时开学日已相同，当前周会
            // 永远停在旧值。
            val settingsAfter = repository.snapshot.settings
            runCatching {
                repository.setCurrentWeek(
                    WeekCalculator.weekForDate(
                        date = LocalDateTime.now(),
                        semesterStart = settingsAfter.semesterStartDate,
                        semesterWeekCount = settingsAfter.semesterWeekCount,
                        fallback = before.currentWeek,
                    ),
                )
            }
            Result.Done(importedCount)
        } catch (_: Exception) {
            // 抛异常路径（写回层之外的本层写入 / 读快照等）：同一条回滚。
            rollbackImportState()
            Result.Failed(null)
        }
    }
}
