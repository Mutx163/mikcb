package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.transfer.MAX_ALLOWED_SEMESTER_WEEK_COUNT
import com.mutx163.qingyu.transfer.courseListsEqual
import com.mutx163.qingyu.transfer.dedupeImportedCourses
import com.mutx163.qingyu.transfer.replaceImportedCoursesPreservingLocalFields
import com.mutx163.qingyu.transfer.syncImportedCourses
import java.time.LocalDateTime

/**
 * 教务适配脚本回传课程 → **写回当前档案**（F32，补 F28 的「只记日志」缺口）。
 *
 * ## 与 Dart 的对应关系
 *
 * Dart `warehouse_adapter_web_login_screen.dart` 在收到 `courses` 后：
 * 解析 → 问用户「替换还是合并」→ 选开学日期/周次映射 → 合并/替换 → 写 provider。
 * 本层只接**最后一跳**，并且把「替换还是合并」做成**确定的默认策略**：
 *
 * | 当前档案已有课 | 默认 |
 * |---|---|
 * | 没有课 | [WarehouseCourseWriteMode.REPLACE]（空表替换等于直接写入，不会误删任何东西） |
 * | 已有课 | [WarehouseCourseWriteMode.MERGE]（只新增/更新，**绝不**静默清空用户原有课表） |
 *
 * 调用方可以用 [apply] 的 `requestedMode` 覆盖；原生「替换/合并」选择弹窗还没做
 * （见认领文件 F32），所以宿主当前不传。
 *
 * ## 失败语义
 *
 * 写回只走 [TimetableRepository.replaceActiveProfileContent] 这一个原子入口：
 * 它先落盘、成功后才改内存并通知。所以写盘抛错时**内存保持原样、界面不闪**，
 * 本层返回 [Result.Failed]。注意仓储层没有跨 key 事务：落盘分两次写
 * （profiles + active id），第二次失败会留下「盘新内存旧」，冷启动后以盘为准。
 *
 * 「没有可导入课程」「没有任何变化」都不写盘：空列表覆盖用户课表等于一键清空。
 */
object WarehouseCourseWriteBack {

    /** 写回策略。 */
    enum class Mode {
        /** 用脚本课程整份替换当前档案的课程（保留同名课程的本地 id / 颜色等字段）。 */
        REPLACE,

        /** 与现有课程合并：能匹配上的更新，匹配不上的新增。 */
        MERGE,
    }

    /** 一次写回的可展示结果。 */
    data class Outcome(
        val mode: Mode,
        /** 实际新增 + 更新的课程条数；合并时无变化为 0。 */
        val importedCount: Int,
        /** 解析阶段被丢弃的记录数（字段缺失 / 类型异常）。 */
        val droppedCount: Int,
        /** 导入成功但周次被削过的课程数。 */
        val weeksTrimmedCount: Int,
    )

    sealed interface Result {
        data class Done(val outcome: Outcome) : Result

        /** 解析后一门课都没有：不写盘，避免把用户课表清空。 */
        data class NoImportableCourses(val droppedCount: Int) : Result

        /** 落盘失败：内存与监听者都没动（仓储「成功才通知」语义）。 */
        data class Failed(val cause: Throwable?) : Result
    }

    /**
     * 从网页回传的 `courses` 载荷（JSON 数组文本）一路做到写回。
     *
     * 抽出来是为了让「解包 → 解析 → 写回」整条链在 L0 里可测；宿主只负责把
     * [PayloadResult] 翻成给用户看的话。
     */
    sealed interface PayloadResult {
        /** 写入成功（`importedCount == 0` 表示合并没有变化）。 */
        data class Done(val outcome: Outcome, val receivedCount: Int) : PayloadResult

        /** 解析后没有可导入课程；[droppedCount] 是被丢掉的记录数。 */
        data class NoImportableCourses(val droppedCount: Int, val receivedCount: Int) : PayloadResult

        /** 载荷不是 JSON 数组。 */
        object InvalidFormat : PayloadResult

        /** 落盘失败。 */
        data class Failed(val cause: Throwable?, val receivedCount: Int) : PayloadResult
    }

    /** 默认策略：空表替换、非空合并。 */
    fun resolveMode(existingCourseCount: Int, requested: Mode? = null): Mode =
        requested ?: if (existingCourseCount == 0) Mode.REPLACE else Mode.MERGE

    /**
     * 把解析好的课程写进当前档案。
     *
     * @param droppedCount / @param weeksTrimmedCount 解析阶段的统计，只用于上屏，不参与写入。
     * @param preserveLocalColors 合并时保留本地课程颜色（与 Dart / AI 导入同口径）。
     * @param semesterStartDate 用户在映射弹层确认的开学日；与 Dart
     *   `importParsedCourses(semesterStart: ...)` 一样，即使课程一字不差也要落盘。
     */
    fun apply(
        repository: TimetableRepository,
        courses: List<Course>,
        requestedMode: Mode? = null,
        droppedCount: Int = 0,
        weeksTrimmedCount: Int = 0,
        preserveLocalColors: Boolean = true,
        semesterStartDate: LocalDateTime? = null,
    ): Result {
        if (courses.isEmpty()) {
            return Result.NoImportableCourses(droppedCount)
        }

        val before = repository.snapshot
        val mode = resolveMode(before.courses.size, requestedMode)

        val mergedCourses: List<Course>
        val importedCount: Int
        when (mode) {
            Mode.REPLACE -> {
                // Dart `importParsedCourses` 覆盖导入先去重（导入包内互重的条目只留一条），
                // 「N 条」也按去重后的条数报。
                val deduped = dedupeImportedCourses(courses)
                mergedCourses = replaceImportedCoursesPreservingLocalFields(
                    existingCourses = before.courses,
                    importedCourses = deduped,
                    preserveLocalColors = preserveLocalColors,
                )
                importedCount = deduped.size
            }

            Mode.MERGE -> {
                val synced = syncImportedCourses(
                    existingCourses = before.courses,
                    importedCourses = courses,
                    preserveLocalColors = preserveLocalColors,
                )
                mergedCourses = synced.mergedCourses
                // Dart `effectiveImportedCount`：合并后若一门课都没变，这次导入算 0 条，
                // 不是「更新了 N 门」——否则界面会谎报一次没有实际变化的导入。
                importedCount = if (courseListsEqual(before.courses, mergedCourses)) {
                    0
                } else {
                    synced.addedCount + synced.updatedCount
                }
            }
        }

        // Dart `ensureImportSectionCapacity`：最终课表要用到第几节超过现有节次时先补齐，
        // 再写课程。
        //
        // 判据在 [AiImageImportApply]（与 `ImportFlowModel.needsSectionExpansion` /
        // `sectionsForImport` 同口径，由 `CapacityCriteriaParityTest` 对表钉住）。
        // 本文件的 L0 编译范围是 `pages/import/warehouse`，**收不到 `pages/import` 根目录**
        // 的 `ImportFlowModel.kt`（`test-kotlin-module.ps1` 的 mainDir 就是模块子目录），
        // 所以不直接引用它，而由测试在 `pages/import` 根目录同时看见两边、防止漂移。
        val currentSections = AiImageImportApply.activeSections(before)
        val requiredSections = AiImageImportApply.requiredSectionCount(mergedCourses)
        val scheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = before.timeSchemes,
            activeTimeSchemeId = before.activeTimeSchemeId,
        )
        val needsSectionExpansion = AiImageImportApply.needsExpansion(currentSections, requiredSections)
        var sectionsExpanded = false
        if (needsSectionExpansion) {
            val nextSections = AiImageImportApply.expandedSections(currentSections, requiredSections)
            try {
                if (scheme != null) {
                    // 有主模板时页面读的是模板节次，写设置里的节次表不会生效。
                    val error = repository.updateTimeScheme(scheme.id, scheme.name, nextSections)
                    if (error != null) {
                        return Result.Failed(null)
                    }
                } else {
                    repository.updateSettings(before.settings.copy(sections = nextSections))
                }
                sectionsExpanded = true
            } catch (error: Exception) {
                rollbackImportWrites(repository, before, scheme, sectionsExpanded = true, settingsWritten = false)
                return Result.Failed(error)
            }
        }

        // Dart 导入会按「合并后课程的最大周次」抬高学期总周数（只升不降，封顶 30 周，
        // Dart `import_export_logic.dart:39` + `timetable_import_export_service.dart:588-601`），
        // 否则第 21-25 周的课会落盘却永远点不出来。
        //
        // 算术只在 [SemesterWeekUplift] 一处：表格导入（`ImportFlowModel.nextSemesterWeekCount`）
        // 与本函数同调该对象，**不要再在这里写第二份 max/coerceIn**。
        val nextWeekCount = SemesterWeekUplift.nextSemesterWeekCount(
            before.settings.semesterWeekCount,
            mergedCourses,
        )
        val nextSettings = before.settings.copy(
            semesterStartDate = semesterStartDate ?: before.settings.semesterStartDate,
            semesterWeekCount = nextWeekCount,
        )
        // 与 Dart 一致：有课程变化、或用户确认了新开学日，才动设置；
        // 「合并无变化 + 没传开学日」保持完全不动盘。
        val shouldWriteSettings = semesterStartDate != null ||
            (importedCount > 0 && nextWeekCount > before.settings.semesterWeekCount)
        var settingsWritten = false
        // Dart 换了开学日就按今天重算当前周（`calculateWeekForDate`），不能留着旧开学日的周次。
        val nextCurrentWeek = if (semesterStartDate != null) {
            WeekCalculator.weekForDate(
                date = LocalDateTime.now(),
                semesterStart = nextSettings.semesterStartDate,
                semesterWeekCount = nextSettings.semesterWeekCount,
                fallback = before.currentWeek,
            )
        } else {
            before.currentWeek
        }
        if (shouldWriteSettings) {
            try {
                repository.updateSettings(nextSettings)
                settingsWritten = true
            } catch (error: Exception) {
                rollbackImportWrites(repository, before, scheme, sectionsExpanded, settingsWritten)
                return Result.Failed(error)
            }
        }
        // 当前周要等设置落盘后再重算；`setCurrentWeek` 会再持久化一次档案，
        // 所以放在「课程已写成功」之后，失败也不至于留下半张课表。
        fun refreshCurrentWeek() {
            if (semesterStartDate == null) return
            runCatching { repository.setCurrentWeek(nextCurrentWeek) }
        }

        val outcome = Outcome(
            mode = mode,
            importedCount = importedCount,
            droppedCount = droppedCount,
            weeksTrimmedCount = weeksTrimmedCount,
        )
        // 合并后没有任何变化：若学期设置也没变，不写、不通知，界面不需要闪一下。
        if (importedCount == 0) {
            refreshCurrentWeek()
            return Result.Done(outcome)
        }

        return try {
            repository.replaceActiveProfileContent(
                courses = mergedCourses,
                tasks = repository.tasks,
                exams = repository.exams,
            )
            refreshCurrentWeek()
            Result.Done(outcome)
        } catch (error: Exception) {
            // 仓储先落盘、成功才改内存；抛错时内存仍是旧课表，宿主据此提示失败。
            // 学期设置/补齐的节次已先行写入，这里尽力回滚，避免「课没进、作息却变了」的半个状态。
            rollbackImportWrites(repository, before, scheme, sectionsExpanded, settingsWritten)
            Result.Failed(error)
        }
    }

    /**
     * 把先行写入的学期设置与补齐的节次恢复成写回前的值（尽力而为，不掩盖原始错误）。
     *
     * [settingsWritten] 为假时仍要恢复设置，只要本次确实扩过节且没有主模板——那种情况下
     * 节次表就写在设置里，不回滚等于「课没进、节次却变长」。
     */
    private fun rollbackImportWrites(
        repository: TimetableRepository,
        before: TimetableSnapshot,
        scheme: TimeScheme?,
        sectionsExpanded: Boolean,
        settingsWritten: Boolean,
    ) {
        if (settingsWritten || (sectionsExpanded && scheme == null)) {
            runCatching { repository.updateSettings(before.settings) }
        }
        if (sectionsExpanded && scheme != null) {
            runCatching { repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections) }
        }
    }

    /**
     * 脚本载荷 → 解析（**不写盘**）。
     *
     * 「替换/合并」弹窗（I2-3）要先拿到解析结果（课程数、丢弃数）给用户看，
     * 等用户在弹窗里选完才落盘——解析与写入因此拆成两步，[applyPayload] 是
     * 「解析 + 立即写入」的一步到位封装（旧调用点不变）。
     */
    sealed interface PayloadParse {
        /** 解析完成（`courses` 可能为空——空列表不写盘的判定在 [apply]）。 */
        data class Parsed(
            val courses: List<Course>,
            val droppedCount: Int,
            val weeksTrimmedCount: Int,
            val receivedCount: Int,
        ) : PayloadParse

        /** 载荷不是 JSON 数组。 */
        object InvalidFormat : PayloadParse
    }

    /** 只解析不写盘。参数口径与 [applyPayload] 一致。 */
    fun parsePayload(
        payload: String,
        unknownTeacher: String,
        unknownLocation: String,
        idFactory: () -> String,
        maxWeek: Int = MAX_ALLOWED_SEMESTER_WEEK_COUNT,
    ): PayloadParse {
        val decoded = MiniJson.tryParse(payload)
        if (decoded !is List<*>) {
            return PayloadParse.InvalidFormat
        }
        @Suppress("UNCHECKED_CAST")
        val rawCourses = decoded as List<Any?>

        var dropped = 0
        var weeksTrimmed = 0
        val courses = WarehouseCourseImportLogic.parse(
            rawCourses = rawCourses,
            idFactory = idFactory,
            unknownTeacher = unknownTeacher,
            unknownLocation = unknownLocation,
            maxWeek = maxWeek,
        ) { reason, _, _ ->
            when (reason) {
                WarehouseCourseImportLogic.SkipReason.MALFORMED,
                WarehouseCourseImportLogic.SkipReason.UNUSABLE,
                -> dropped += 1

                WarehouseCourseImportLogic.SkipReason.PARTIAL_WEEKS -> weeksTrimmed += 1
            }
        }
        // 被丢弃的记录要么是 MALFORMED、要么是 UNUSABLE，每条只计一次。
        return PayloadParse.Parsed(
            courses = courses,
            droppedCount = dropped,
            weeksTrimmedCount = weeksTrimmed,
            receivedCount = courses.size + dropped,
        )
    }

    /** 把解析好的课程写回（[apply] 的结果 + 解析统计拼成一次可展示结果）。 */
    fun applyParsed(
        repository: TimetableRepository,
        parsed: PayloadParse.Parsed,
        requestedMode: Mode? = null,
        preserveLocalColors: Boolean = true,
        semesterStartDate: LocalDateTime? = null,
    ): PayloadResult = when (
        val result = apply(
            repository = repository,
            courses = parsed.courses,
            requestedMode = requestedMode,
            droppedCount = parsed.droppedCount,
            weeksTrimmedCount = parsed.weeksTrimmedCount,
            preserveLocalColors = preserveLocalColors,
            semesterStartDate = semesterStartDate,
        )
    ) {
        is Result.Done -> PayloadResult.Done(result.outcome, parsed.receivedCount)
        is Result.NoImportableCourses ->
            PayloadResult.NoImportableCourses(result.droppedCount, parsed.receivedCount)

        is Result.Failed -> PayloadResult.Failed(result.cause, parsed.receivedCount)
    }

    /**
     * 脚本载荷 → 解析 → 写回。
     *
     * @param unknownTeacher / @param unknownLocation 空字段占位文案（宿主从 ARB 传，本层不硬写中文）。
     * @param idFactory 课程 id 生成器（宿主注入 UUID，便于测试钉死）。
     */
    fun applyPayload(
        repository: TimetableRepository,
        payload: String,
        unknownTeacher: String,
        unknownLocation: String,
        idFactory: () -> String,
        requestedMode: Mode? = null,
        maxWeek: Int = MAX_ALLOWED_SEMESTER_WEEK_COUNT,
    ): PayloadResult = when (val parsed = parsePayload(payload, unknownTeacher, unknownLocation, idFactory, maxWeek)) {
        PayloadParse.InvalidFormat -> PayloadResult.InvalidFormat
        is PayloadParse.Parsed -> applyParsed(repository, parsed, requestedMode)
    }
}
