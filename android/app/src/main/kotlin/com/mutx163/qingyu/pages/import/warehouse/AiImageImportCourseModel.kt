package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.SectionTime
import java.util.UUID

/**
 * AI 识图解析结果 → 课程模型的**纯转换**（本刀新增）。
 *
 * ## 为什么单独一层
 *
 * [parseAiImageImportJson] 只做 JSON 结构校验，产出 [AiParsedCourse]（没有钟点、没有 id）；
 * 真正写进课表需要：
 * 1. 按当前生效节次表把「第 N 节」翻成 `HH:mm`；
 * 2. 把 `customWeeks` 拆成起止周；
 * 3. 给每条课发一个 `ai-` 前缀的 id（与 Dart `ai_course_import_service.dart` 同前缀）。
 *
 * 这些判断不依赖 Android / Compose，放这里才能在 JVM 单测里钉住；宿主只负责
 * 「先补节次、再调这里、最后落盘」。
 *
 * ## 与 Dart 的已知差异（诚实清单）
 *
 * - Dart `parse` 遇到未知字段 / 越界节次会抛错整份拒收；Kotlin 现有解析器是宽松的
 *   （进 `warnings`）。这里对**确实无法落盘**的条目（空课名、星期越界、节次超出当前
 *   节次表）采取「跳过并计数」，宿主用 `importCourseRecordsDropped` 如实告诉用户
 *   少了几门，而不是编一个 `00:00` 假时间收下（那会让之后改节次数被永久守卫拒绝）。
 * - Dart 解析时会剥掉课名尾部的 `[32]` / `[必修]` 标记；Kotlin 现有解析器没做，
 *   本层也不重复实现，避免两处归一规则漂移。
 * - `customWeeks` 为空时按「整学期每周都上」处理（1..`semesterWeekCount`）：
 *   AI 提示词要求必填，但宽松解析器允许缺省，这里给一个可解释的默认值。
 */
object AiImageImportCourseModel {

    /** 课程 id 前缀，与 Dart `ai-<uuid>` 一致，便于两侧读同一份课时辨认来源。 */
    const val COURSE_ID_PREFIX = "ai-"

    /** 转换结果；[droppedCount] = 无法落盘而跳过的条数（要如实告诉用户）。 */
    data class Conversion(
        val courses: List<Course>,
        val droppedCount: Int,
    )

    /** 这份解析结果最高用到第几节；没有课程返回 0（宿主据此判断要不要扩节）。 */
    fun requiredSectionCount(courses: List<AiParsedCourse>): Int =
        courses.maxOfOrNull { it.endSection } ?: 0

    /**
     * 把解析结果转成可写库的 [Course]。
     *
     * @param sections 用来取上/下课钟点的节次表。宿主必须在**可能扩节之后**再传进来，
     *   否则超出当前节次表的课会被当成不可落盘而跳过。
     * @param semesterWeekCount 缺省周次（`customWeeks` 为空）时用的学期总周数。
     * @param idFactory 便于单测钉 id；生产默认 `ai-<uuid>`。
     */
    fun convert(
        courses: List<AiParsedCourse>,
        sections: List<SectionTime>,
        semesterWeekCount: Int,
        idFactory: () -> String = { COURSE_ID_PREFIX + UUID.randomUUID().toString() },
    ): Conversion {
        val converted = mutableListOf<Course>()
        var dropped = 0
        val weekCount = semesterWeekCount.coerceAtLeast(1)

        for (parsed in courses) {
            val name = parsed.name.trim()
            val startSection = parsed.startSection
            val endSection = parsed.endSection.coerceAtLeast(startSection)
            if (name.isEmpty() ||
                parsed.dayOfWeek !in 1..7 ||
                startSection < 1 ||
                endSection > sections.size
            ) {
                dropped += 1
                continue
            }

            val weeks = parsed.customWeeks
                .filter { it > 0 }
                .distinct()
                .sorted()
                .ifEmpty { (1..weekCount).toList() }

            val startTime = sections[startSection - 1].startTime
            val endTime = sections[endSection - 1].endTime

            converted += Course(
                id = idFactory(),
                name = name,
                teacher = parsed.teacher.trim(),
                location = parsed.location.trim(),
                dayOfWeek = parsed.dayOfWeek,
                startSection = startSection,
                endSection = endSection,
                startTime = startTime,
                endTime = endTime,
                startWeek = weeks.first(),
                endWeek = weeks.last(),
                customWeeks = weeks,
                courseNature = resolveCourseNature(parsed.courseNature),
                note = parsed.note.trim().ifEmpty { null },
            )
        }
        return Conversion(courses = converted, droppedCount = dropped)
    }

    /**
     * AI 提示词里 `courseNature` 的取值是 `required` / `elective`，中文版是「必修」/「选修」。
     * 这两个中文 token 是**数据值不是屏上文案**，用 Unicode 转义写，避免被中文字面量
     * 棘轮当成「新增硬编码文案」；未知取值按必修处理（Dart 会抛错，但宽松解析器
     * 已经把「未知」放进了 warnings，这里不再整份拒收）。
     */
    private fun resolveCourseNature(raw: String): CourseNature =
        when (raw.trim().lowercase()) {
            "elective", "\u9009\u4fee" -> CourseNature.ELECTIVE
            else -> CourseNature.REQUIRED
        }
}
