package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.transfer.MAX_ALLOWED_SEMESTER_WEEK_COUNT
import com.mutx163.qingyu.transfer.replaceImportedCoursesPreservingLocalFields
import com.mutx163.qingyu.transfer.syncImportedCourses

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
     */
    fun apply(
        repository: TimetableRepository,
        courses: List<Course>,
        requestedMode: Mode? = null,
        droppedCount: Int = 0,
        weeksTrimmedCount: Int = 0,
        preserveLocalColors: Boolean = true,
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
                mergedCourses = replaceImportedCoursesPreservingLocalFields(
                    existingCourses = before.courses,
                    importedCourses = courses,
                    preserveLocalColors = preserveLocalColors,
                )
                importedCount = mergedCourses.size
            }

            Mode.MERGE -> {
                val synced = syncImportedCourses(
                    existingCourses = before.courses,
                    importedCourses = courses,
                    preserveLocalColors = preserveLocalColors,
                )
                mergedCourses = synced.mergedCourses
                importedCount = synced.addedCount + synced.updatedCount
            }
        }

        val outcome = Outcome(
            mode = mode,
            importedCount = importedCount,
            droppedCount = droppedCount,
            weeksTrimmedCount = weeksTrimmedCount,
        )
        // 合并后没有任何变化：不写、不通知，界面不需要闪一下。
        if (importedCount == 0) {
            return Result.Done(outcome)
        }

        return try {
            repository.replaceActiveProfileContent(
                courses = mergedCourses,
                tasks = repository.tasks,
                exams = repository.exams,
            )
            Result.Done(outcome)
        } catch (error: Exception) {
            // 仓储先落盘、成功才改内存；抛错时内存仍是旧课表，宿主据此提示失败。
            Result.Failed(error)
        }
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
    ): PayloadResult {
        val decoded = MiniJson.tryParse(payload)
        if (decoded !is List<*>) {
            return PayloadResult.InvalidFormat
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
        val receivedCount = courses.size + dropped

        return when (val result = apply(
            repository = repository,
            courses = courses,
            requestedMode = requestedMode,
            droppedCount = dropped,
            weeksTrimmedCount = weeksTrimmed,
        )) {
            is Result.Done -> PayloadResult.Done(result.outcome, receivedCount)
            is Result.NoImportableCourses ->
                PayloadResult.NoImportableCourses(result.droppedCount, receivedCount)

            is Result.Failed -> PayloadResult.Failed(result.cause, receivedCount)
        }
    }
}
