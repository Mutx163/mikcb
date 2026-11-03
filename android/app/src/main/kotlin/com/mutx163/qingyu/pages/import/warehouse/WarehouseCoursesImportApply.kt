package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.ServiceMessage
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.transfer.buildExpandedSections
import java.time.LocalDate

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
 * - **失败回滚**：任一步抛错，把设置（含开学日/周数/节次表）与主模板节次都恢复成
 *   导入前的样子（同 `AiImageImportApply` 的回滚语义）。设置与课程仍是两次独立落盘，
 *   没有跨 key 事务；课程写回走 [WarehouseCourseWriteBack.apply] 的原子入口。
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

        return try {
            if (needsExpansionNow) {
                if (scheme != null) {
                    // 有主模板时页面读的是模板节次，写设置里的节次表不会生效。
                    val error = repository.updateTimeScheme(scheme.id, scheme.name, nextSections)
                    if (error != null) {
                        return Result.Failed(error)
                    }
                } else {
                    repository.updateSettings(before.settings.copy(sections = nextSections))
                }
            }
            val settingsNow = repository.snapshot.settings
            // 对齐旧版 importParsedCourses：用户确认的开学日写进设置；周数不够自动扩。
            val requiredWeeks = warehouseMaxCourseWeek(request.courses, settingsNow.semesterWeekCount)
            repository.updateSettings(
                settingsNow.copy(
                    semesterStartDate = request.semesterStartDate.atStartOfDay(),
                    semesterWeekCount = maxOf(settingsNow.semesterWeekCount, requiredWeeks),
                ),
            )
            when (val result = WarehouseCourseWriteBack.apply(
                repository = repository,
                courses = request.courses,
                requestedMode = if (request.replaceExisting) {
                    WarehouseCourseWriteBack.Mode.REPLACE
                } else {
                    WarehouseCourseWriteBack.Mode.MERGE
                },
                preserveLocalColors = request.preserveLocalColors,
            )) {
                is WarehouseCourseWriteBack.Result.Done -> Result.Done(result.outcome.importedCount)
                // 到不了：宿主在进确认流程前已挡掉空课表；防御性按「无事发生」收尾。
                is WarehouseCourseWriteBack.Result.NoImportableCourses -> Result.Done(0)
                is WarehouseCourseWriteBack.Result.Failed -> Result.Failed(null)
            }
        } catch (_: Exception) {
            // 回滚：设置（开学日/周数/节次表）与主模板节次恢复成导入前的样子。
            runCatching { repository.updateSettings(before.settings) }
            if (needsExpansionNow && scheme != null) {
                runCatching { repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections) }
            }
            Result.Failed(null)
        }
    }
}
