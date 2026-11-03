package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.transfer.buildExpandedSections
import com.mutx163.qingyu.transfer.replaceImportedCoursesPreservingLocalFields
import com.mutx163.qingyu.transfer.syncImportedCourses
import java.time.LocalDateTime

/**
 * AI 识图导入的**落盘层**（本刀新增）。
 *
 * 落点与 ICS / 表格导入完全一致，不另造存储：
 * - 课程：`TimetableRepository.replaceActiveProfileContent(courses, tasks, exams)`
 *   （一次落盘 + 一次通知；作业与考试原样带上）；
 * - 开学日：`TimetableRepository.updateSettings(settings.copy(semesterStartDate = …))`；
 * - 节次不够且用户点「自动补齐」：有主时间模板就写模板（`updateTimeScheme`），否则写设置。
 *
 * ## 为什么这段逻辑不在 `ImportHosts.applyImport`
 *
 * 那一份是 `private`，而且本刀的写作用域不含 `ImportHosts.kt`。这里的顺序、判据、
 * 回滚语义**逐条照抄**它（同一套 Dart 行为），差别只有输入：那边是 ICS/表格解析出的
 * 课程，这边是 AI 解析结果转出的课程。等导入域统一共享件时，两处应合并成一份。
 *
 * ## 失败语义
 *
 * 先落盘、成功才改内存；任一步抛错就把已改的设置/节次恢复成导入前的样子并返回
 * [Result.Failed]。课程列表为空时**直接返回**，绝不拿空列表去覆盖用户课表——
 * 那等于一键清空。
 */
object AiImageImportApply {

    /** 一次待落盘的 AI 导入。课程必须已经转好、对齐过周次并配过色。 */
    data class Request(
        val courses: List<Course>,
        val semesterStartDate: LocalDateTime?,
        val replaceExisting: Boolean,
        val preserveLocalColors: Boolean,
    )

    sealed interface Result {
        val replaceExisting: Boolean

        data class Done(
            val importedCount: Int,
            override val replaceExisting: Boolean,
        ) : Result

        /** 写盘失败（已尝试回滚设置与节次表）。 */
        object Failed : Result {
            override val replaceExisting: Boolean get() = false
        }
    }

    /** 当前生效的节次表：有主时间模板取模板，否则取设置里的（与课表页判据同源）。 */
    fun activeSections(snapshot: TimetableSnapshot): List<SectionTime> =
        TimetableHostLogic.resolveActiveTimeScheme(
            schemes = snapshot.timeSchemes,
            activeTimeSchemeId = snapshot.activeTimeSchemeId,
        )?.sections ?: snapshot.settings.sections

    /**
     * 最终课表要用到的最大节次；没有课返回 0。
     *
     * 与 [com.mutx163.qingyu.pages.import.ImportFlowModel.requiredSectionCount] 同口径，
     * 两者由 `CapacityCriteriaParityTest` 对表钉住（见该测试的说明）。
     */
    fun requiredSectionCount(courses: List<Course>): Int = courses.maxOfOrNull { it.endSection } ?: 0

    /** 现有节次够不够用：需要到第 [requiredSectionCount] 节才算不够。 */
    fun needsExpansion(currentSections: List<SectionTime>, requiredSectionCount: Int): Boolean =
        requiredSectionCount > currentSections.size

    /** 补节后的节次表（纯算术，真正落盘由 [apply] 做）。 */
    fun expandedSections(currentSections: List<SectionTime>, requiredSectionCount: Int): List<SectionTime> =
        buildExpandedSections(currentSections, requiredSectionCount)

    fun apply(
        repository: TimetableRepository,
        request: Request,
        expandSections: Boolean,
    ): Result {
        // 空导入不是「覆盖成空」，而是什么都不做。
        if (request.courses.isEmpty()) {
            return Result.Done(importedCount = 0, replaceExisting = request.replaceExisting)
        }

        val before = repository.snapshot
        val currentSections = activeSections(before)
        val required = requiredSectionCount(request.courses)
        val scheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = before.timeSchemes,
            activeTimeSchemeId = before.activeTimeSchemeId,
        )
        val needsExpansionNow = expandSections && needsExpansion(currentSections, required)

        val mergedCourses: List<Course>
        val importedCount: Int
        if (request.replaceExisting) {
            mergedCourses = replaceImportedCoursesPreservingLocalFields(
                existingCourses = before.courses,
                importedCourses = request.courses,
                preserveLocalColors = request.preserveLocalColors,
            )
            importedCount = mergedCourses.size
        } else {
            val synced = syncImportedCourses(
                existingCourses = before.courses,
                importedCourses = request.courses,
                preserveLocalColors = request.preserveLocalColors,
            )
            mergedCourses = synced.mergedCourses
            importedCount = synced.addedCount + synced.updatedCount
        }

        return try {
            if (needsExpansionNow) {
                val nextSections = expandedSections(currentSections, required)
                if (scheme != null) {
                    // 有主模板时页面读的是模板节次，写设置里的节次表不会生效。
                    val error = repository.updateTimeScheme(scheme.id, scheme.name, nextSections)
                    if (error != null) {
                        return Result.Failed
                    }
                } else {
                    repository.updateSettings(before.settings.copy(sections = nextSections))
                }
            }
            request.semesterStartDate?.let { start ->
                repository.updateSettings(repository.snapshot.settings.copy(semesterStartDate = start))
            }
            repository.replaceActiveProfileContent(
                courses = mergedCourses,
                tasks = repository.tasks,
                exams = repository.exams,
            )
            Result.Done(importedCount = importedCount, replaceExisting = request.replaceExisting)
        } catch (_: Exception) {
            // 回滚：设置（含开学日与节次表）与主模板节次都恢复成导入前的样子。
            runCatching { repository.updateSettings(before.settings) }
            if (needsExpansionNow && scheme != null) {
                runCatching { repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections) }
            }
            Result.Failed
        }
    }
}
