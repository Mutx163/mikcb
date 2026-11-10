package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.app.TimeSchemeImportUpdate
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
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
        /**
         * 用脚本课程整份替换当前档案的课程（保留同名课程的本地 id / 颜色等字段）。
         *
         * 与发布版覆盖导入一致：**自建日程一并清空**（旧日程属于上一套课表，
         * `import_export_service.dart:384` 的 `host._scheduleItems = []`）。
         */
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
        /**
         * 用户是否同意「节次容量不足时自动补齐」。
         *
         * 宿主在「时间模板节次不足」弹窗里选“不同意”时传 `false`：本层**不得补节**，
         * 否则覆盖掉 [WarehouseCoursesImportApply] 里已做过的用户意图判断（拒绝扩节仍被补节）。
         * 默认 `true` 保持 [WarehouseCourseWriteBack] 独立调用（含其单测）历史行为。
         */
        allowSectionExpansion: Boolean = true,
        /**
         * **本次导入开始前**的快照（由 [WarehouseCoursesImportApply] 传入）。
         *
         * 为什么不能用本层入口快照当回滚基线：收尾层在调本层之前已经写过开学日 /
         * 周数 / 节次，入口快照是**写完之后**的污染值，拿它回滚只能回到半套状态
         * （P0-3：界面报「导入失败」、盘上却留着新设置）。独立调用不传时退回入口快照，
         * 保持历史行为。
         */
        importBaseline: TimetableSnapshot? = null,
    ): Result {
        if (courses.isEmpty()) {
            return Result.NoImportableCourses(droppedCount)
        }

        val before = repository.snapshot
        // 失败回滚目标：优先用调用方给的「导入前」现场（含本层不拥有的设置写入）。
        val rollbackBaseline = importBaseline ?: before
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
        val needsSectionExpansion = allowSectionExpansion &&
            AiImageImportApply.needsExpansion(currentSections, requiredSections)
        var sectionsExpanded = false
        /** 共享模板扩容时仓储新建的 `（导入补齐）` 副本 id；失败回滚要删掉它。 */
        var createdSchemeId: String? = null
        if (needsSectionExpansion) {
            val nextSections = AiImageImportApply.expandedSections(currentSections, requiredSections)
            try {
                if (scheme != null) {
                    // 模板被别的课表共用时仓储会复制副本、只改绑当前课表（不原地改别人的）。
                    when (val update = repository.updateTimeSchemeForImport(scheme.id, scheme.name, nextSections)) {
                        is TimeSchemeImportUpdate.Rejected -> {
                            // 校验拒绝 = 一笔没写；但调用方（收尾层）可能已改过设置，
                            // 统一走同一条回滚，别把半套状态留给上层。
                            rollbackImportWrites(
                                repository, rollbackBaseline, scheme,
                                sectionsExpanded = false, settingsWritten = false,
                                createdSchemeId = null,
                            )
                            return Result.Failed(null)
                        }

                        is TimeSchemeImportUpdate.Applied -> createdSchemeId = update.createdSchemeId
                    }
                } else {
                    repository.updateSettings(before.settings.copy(sections = nextSections))
                }
                sectionsExpanded = true
            } catch (error: Exception) {
                rollbackImportWrites(
                    repository, rollbackBaseline, scheme,
                    sectionsExpanded = true, settingsWritten = false,
                    createdSchemeId = createdSchemeId,
                )
                return Result.Failed(error)
            }
        }

        // Dart 导入会按「合并后课程的最大周次」抬高学期总周数（只升不降，封顶 30 周，
        // Dart `import_export_logic.dart:39` + `timetable_import_export_service.dart:588-601`），
        // 否则第 21-25 周的课会落盘却永远点不出来。
        //
        // 算术只在 [SemesterWeekUplift] 一处：表格导入（`ImportFlowModel.nextSemesterWeekCount`）
        // 与本函数同调该对象，**不要再在这里写第二份 max/coerceIn**。
        //
        // J1：派生源必须是**当前**快照，不能用户外入口的 `before.settings`。本层上面的
        // 扩节分支可能已经调用 `updateTimeSchemeForImport` 把当前档改绑到「（导入补齐）」
        // 副本；再从旧快照派生设置，会把 `activeTimeSchemeId` 退回原模板——副本变孤儿，
        // 高节次课程也按原模板取不到钟点。发布版同一处同样是 `host._settings.copyWith(...)`
        //（`import_export_service.dart:423-429`）。
        val currentSettings = repository.snapshot.settings
        val nextWeekCount = SemesterWeekUplift.nextSemesterWeekCount(
            currentSettings.semesterWeekCount,
            mergedCourses,
        )
        val nextSettings = currentSettings.copy(
            semesterStartDate = semesterStartDate ?: currentSettings.semesterStartDate,
            semesterWeekCount = nextWeekCount,
        )
        // 与 Dart 一致：有课程变化、或用户确认了新开学日，才动设置；
        // 「合并无变化 + 没传开学日」保持完全不动盘。
        // 再加一道「值真的变了」防线：上游（[WarehouseCoursesImportApply]）可能已经
        // 写过一次设置，这里 nextSettings 与现值全等时跳过，避免重复落盘+通知。
        val shouldWriteSettings = (semesterStartDate != null ||
            (importedCount > 0 && nextWeekCount > currentSettings.semesterWeekCount)) &&
            nextSettings != currentSettings
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
                rollbackImportWrites(repository, rollbackBaseline, scheme, sectionsExpanded, settingsWritten, createdSchemeId)
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
        // 合并后没有任何变化：若学期设置也没变，且没有需要补钟点的存量课，
        // 不写、不通知，界面不需要闪一下。
        //
        // 为什么同步要放在早退之前：升级前用旧代码导入的课 `startTime/endTime` 是空的；
        // 重导入同一份课表会得到 `importedCount == 0`。提前返回的话，这些存量坏数据
        // 永远自愈不了，用户会看到「课表没有变化、时间还是空」。
        val after = repository.snapshot
        val syncedCourses = try {
            // Dart `importParsedCourses` 在落库前按生效时间模板回填钟点
            // （`syncCoursesWithEffectiveTimeSchemes`）。
            TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(
                source = mergedCourses,
                schemes = after.timeSchemes,
                settings = after.settings,
                locationTimeGroups = after.locationTimeGroups,
                scheduleDateRules = after.scheduleDateRules,
            )
        } catch (error: Exception) {
            rollbackImportWrites(repository, rollbackBaseline, scheme, sectionsExpanded, settingsWritten, createdSchemeId)
            return Result.Failed(error)
        }
        // 只有本地已存在的课（id 匹配）才计入「补时间」条数；新导入课已算在 importedCount。
        val beforeTimes = before.courses.associate { it.id to (it.startTime to it.endTime) }
        val timesFilledCount = syncedCourses.count { course ->
            val old = beforeTimes[course.id] ?: return@count false
            old.first != course.startTime || old.second != course.endTime
        }
        if (importedCount == 0 && timesFilledCount == 0) {
            refreshCurrentWeek()
            return Result.Done(outcome)
        }

        return try {
            // 发布版覆盖导入会清空自建日程（`import_export_service.dart:384`
            // `host._scheduleItems = []`）：旧日程属于上一套课表，留在新表下就是脏数据。
            // `scheduleItems` setter 只改内存、不落盘，由下面 `replaceActiveProfileContent`
            // 一次写盘带上（与发布版「清内存 + 单次 persist」同序）；失败时先还原内存。
            if (mode == Mode.REPLACE) {
                repository.scheduleItems = emptyList()
            }
            repository.replaceActiveProfileContent(
                courses = syncedCourses,
                tasks = repository.tasks,
                exams = repository.exams,
            )
            refreshCurrentWeek()
            // 只补了存量课时间时也要告诉用户「更新了几门」，不能报「没有变化」。
            Result.Done(outcome.copy(importedCount = maxOf(importedCount, timesFilledCount)))
        } catch (error: Exception) {
            // 仓储先落盘、成功才改内存；抛错时内存仍是旧课表，宿主据此提示失败。
            // 日程是内存态：先还原再回滚设置/节次——`updateTimeScheme` 会把内存档案整份落盘。
            if (mode == Mode.REPLACE) {
                runCatching { repository.scheduleItems = rollbackBaseline.scheduleItems }
            }
            // 学期设置/补齐的节次已先行写入，这里尽力回滚，避免「课没进、作息却变了」的半个状态。
            rollbackImportWrites(repository, rollbackBaseline, scheme, sectionsExpanded, settingsWritten, createdSchemeId)
            // J2：仓储写档案是「profiles → active id」两笔写。第一笔已把**清空后的日程**
            // 写进盘、第二笔才抛错时，只还原内存是不够的——盘上日程已经真丢了。
            // 还原完内存与设置后补一次整体落盘，把旧日程写回盘（尽力而为：磁盘持续写不进去
            // 时这里也只能失败，但至少不会在能写的时候把「盘上已丢」谎报成没事）。
            if (mode == Mode.REPLACE) {
                runCatching { repository.persistActiveProfileState() }
            }
            Result.Failed(error)
        }
    }

    /**
     * 把先行写入的学期设置与补齐的节次恢复成**导入前**的值（尽力而为，不掩盖原始错误）。
     *
     * 判据三条，缺一条都会留半套状态：
     * 1. [settingsWritten]：本层刚写过设置（周数抬升）；
     * 2. `sectionsExpanded && scheme == null`：节次表写在设置里，扩过就得退；
     * 3. **设置与基线不一致**：调用方（收尾层）在进本层前可能已经写过开学日/周数/节次
     *    ——写回层"只回滚自己写的那几笔"会把它那份留在盘上（P0-3）。
     *    只在该项真的变了时才写，正常失败路径不会多一次通知。
     *
     * 主模板同理：模板节次可能已被收尾层先写过，有导入前基线就还原它那一份，
     * 不能拿本层入口的（已被污染的）节次当"原始值"。共享模板扩容会新建
     * `（导入补齐）` 副本（[createdSchemeId] 非空）：此时要删副本，不能去改原模板。
     */
    private fun rollbackImportWrites(
        repository: TimetableRepository,
        baseline: TimetableSnapshot,
        scheme: TimeScheme?,
        sectionsExpanded: Boolean,
        settingsWritten: Boolean,
        createdSchemeId: String? = null,
    ) {
        val settingsDrifted = repository.snapshot.settings != baseline.settings
        if (settingsWritten || (sectionsExpanded && scheme == null) || settingsDrifted) {
            runCatching { repository.updateSettings(baseline.settings) }
        }
        if (createdSchemeId != null) {
            // 共享模板扩容时新建的副本：设置已恢复成原模板引用，删副本不会撞 in-use。
            runCatching { repository.deleteTimeScheme(createdSchemeId) }
        } else if (scheme != null) {
            val originalSections = baseline.timeSchemes
                .firstOrNull { it.id == scheme.id }
                ?.sections
            if (originalSections != null && originalSections != scheme.sections) {
                runCatching { repository.updateTimeScheme(scheme.id, scheme.name, originalSections) }
            }
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
