package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import java.time.LocalDateTime
import java.util.Locale

/**
 * 自检预设课/测试课表合成（移植 lib/services/live_testing_fixture_service.dart
 * 的纯函数：buildPresetCourses / buildTimedTestCourse / buildSlotTemplate /
 * buildHourlySections / sectionNumberForTime / formatClock 判定）。
 *
 * 不移植：ensureHourlyTimeScheme / installSectionGrid / upsertTimedFixtureCourse /
 * removeAllFixtureCourses——它们写课表存储（host.initialize/addCourse/updateCourse/
 * importParsedCourses），属于 IO 面。
 */
object LiveTestingFixtureData {

    const val COURSE_ID_PREFIX = "live_test_"
    const val DEFAULT_PRESET_LEAD_MINUTES = 1L
    const val DEFAULT_PRESET_DURATION_MINUTES = 3L
    const val DEFAULT_PRESET_GAP_MINUTES = 1L

    const val PRESET_COURSE_ID_A = "${COURSE_ID_PREFIX}preset_a"
    const val PRESET_COURSE_ID_B = "${COURSE_ID_PREFIX}preset_b"

    // 预设课 A 的展示字段（速览兜底副本与 buildPresetCourses 必须同源）。
    const val PRESET_COURSE_A_NAME = "自检预设课 A"
    const val PRESET_COURSE_A_SHORT_NAME = "自检A"
    const val PRESET_COURSE_A_TEACHER = "自检教师"
    const val PRESET_COURSE_A_LOCATION = "自检教室 A"

    fun isFixtureCourse(course: Course): Boolean = course.id.startsWith(COURSE_ID_PREFIX)

    fun isPresetCourse(course: Course): Boolean = course.id.startsWith("${COURSE_ID_PREFIX}preset_")

    /** 1-based section number → stable fixture id (`live_test_01` …)。 */
    fun fixtureIdForSection(sectionNumber: Int): String {
        val normalized = if (sectionNumber < 1) 1 else sectionNumber
        return String.format(Locale.ROOT, "$COURSE_ID_PREFIX%02d", normalized)
    }

    /**
     * 自检预设课（buildPresetCourses，:309-373）：真实课表无课可测时的兜底测试数据。
     * 第一门从现在起 [leadMinutes] 分钟后上课，第二门在 [gapMinutes] 后接棒。
     * 临近期午夜会生成跨日钟点 → 抛 IllegalStateException（Dart StateError 同义）。
     */
    fun buildPresetCourses(
        now: LocalDateTime,
        targetWeek: Int,
        semesterWeekCount: Int,
        leadMinutes: Long = DEFAULT_PRESET_LEAD_MINUTES,
        durationMinutes: Long = DEFAULT_PRESET_DURATION_MINUTES,
        gapMinutes: Long = DEFAULT_PRESET_GAP_MINUTES,
    ): List<Course> {
        if (durationMinutes <= 0) {
            throw IllegalArgumentException("duration must be positive")
        }
        if (gapMinutes < 0) {
            throw IllegalArgumentException("gap must not be negative")
        }
        val firstStart = now.plusMinutes(leadMinutes)
        val firstEnd = firstStart.plusMinutes(durationMinutes)
        val secondStart = firstEnd.plusMinutes(gapMinutes)
        val secondEnd = secondStart.plusMinutes(durationMinutes)
        // 与 buildTimedTestCourse 相同的不跨日约束：课表不支持隔夜课。
        for (time in listOf(firstStart, firstEnd, secondStart, secondEnd)) {
            if (time.year != now.year || time.monthValue != now.monthValue || time.dayOfMonth != now.dayOfMonth) {
                throw IllegalStateException("当前时间距离午夜太近，无法生成不跨日预设测试课，请在午夜后重试")
            }
        }
        // 覆盖选课路径实际使用的日历周：学期未开始是第 0 周，学期结束后会超过
        // semesterWeekCount，两种情况都要让周次规则照常放行。
        val startWeek = if (targetWeek < 1) targetWeek else 1
        val endWeek = maxOf(targetWeek, semesterWeekCount, 1)
        return listOf(
            Course(
                id = PRESET_COURSE_ID_A,
                name = PRESET_COURSE_A_NAME,
                shortName = PRESET_COURSE_A_SHORT_NAME,
                teacher = PRESET_COURSE_A_TEACHER,
                location = PRESET_COURSE_A_LOCATION,
                dayOfWeek = now.dayOfWeek.value,
                startSection = 1,
                endSection = 1,
                startTime = WidgetDataClock.formatClock(firstStart),
                endTime = WidgetDataClock.formatClock(firstEnd),
                color = colorForSection(11, 24),
                startWeek = startWeek,
                endWeek = endWeek,
                note = "自检预设课程（仅超级岛测试用，不写入课表）",
            ),
            Course(
                id = PRESET_COURSE_ID_B,
                name = "自检预设课 B",
                shortName = "自检B",
                teacher = "自检教师",
                location = "自检教室 B",
                dayOfWeek = now.dayOfWeek.value,
                startSection = 2,
                endSection = 2,
                startTime = WidgetDataClock.formatClock(secondStart),
                endTime = WidgetDataClock.formatClock(secondEnd),
                color = colorForSection(17, 24),
                startWeek = startWeek,
                endWeek = endWeek,
                note = "自检预设课程（仅超级岛测试用，不写入课表）",
            ),
        )
    }

    /** 槽位模板课（buildSlotTemplate，:244-269）。 */
    fun buildSlotTemplate(
        sectionNumber: Int,
        section: SectionTimeData,
        dayOfWeek: Int,
        semesterWeekCount: Int,
    ): Course {
        val normalizedSection = if (sectionNumber < 1) 1 else sectionNumber
        val color = colorForSection(normalizedSection, 24)
        val padded = String.format(Locale.ROOT, "%02d", normalizedSection)
        return Course(
            id = fixtureIdForSection(normalizedSection),
            name = "测试 第${normalizedSection}节",
            shortName = "测$padded",
            teacher = "测试教师",
            location = "测试教室 $padded",
            dayOfWeek = dayOfWeek,
            startSection = normalizedSection,
            endSection = normalizedSection,
            startTime = section.startTime,
            endTime = section.endTime,
            color = color,
            endWeek = semesterWeekCount,
            note = "超级岛快捷测试课（可安全删除）",
        )
    }

    /**
     * 只挪钟点、保留节次下标（buildTimedTestCourse，:273-301）：
     * 周次网格位置稳定，超级岛按自由时钟选课。跨日（午夜前 lead 分钟）拒绝。
     */
    fun buildTimedTestCourse(
        template: Course,
        now: LocalDateTime,
        leadMinutes: Long,
        durationMinutes: Long = 3,
    ): Course {
        if (durationMinutes <= 0) {
            throw IllegalArgumentException("duration must be positive")
        }
        val start = now.plusMinutes(leadMinutes)
        val end = start.plusMinutes(durationMinutes)
        if (start.year != end.year || start.monthValue != end.monthValue || start.dayOfMonth != end.dayOfMonth) {
            throw IllegalStateException("当前时间距离午夜太近，无法生成不跨日测试课，请在午夜后重试")
        }
        return template.copy(
            dayOfWeek = start.dayOfWeek.value,
            startTime = WidgetDataClock.formatClock(start),
            endTime = WidgetDataClock.formatClock(end),
        )
    }

    /** 24 段整点节次（buildHourlySections，:116-126）：第 n 节 = n-1:00–n:00。 */
    fun buildHourlySections(): List<SectionTimeData> = (0 until 24).map { hour ->
        val endHour = if (hour == 23) 23 else hour + 1
        val endMinute = if (hour == 23) 59 else 0
        SectionTimeData(
            startTime = String.format(Locale.ROOT, "%02d:00", hour),
            endTime = String.format(Locale.ROOT, "%02d:%02d", endHour, endMinute),
        )
    }

    private fun clockMinutes(clock: String): Int? {
        val parts = clock.split(":")
        if (parts.size < 2) return null
        val hour = parts[0].trim().toIntOrNull() ?: return null
        val minute = parts[1].trim().toIntOrNull() ?: return null
        return hour * 60 + minute
    }

    /**
     * [time] 落在第几节（sectionNumberForTime，:195-212）：优先进行中，
     * 其次下一节，全天已过返回最后一节。
     */
    fun sectionNumberForTime(time: LocalDateTime, sections: List<SectionTimeData>): Int {
        if (sections.isEmpty()) return 1
        val minutes = time.hour * 60 + time.minute
        for (index in sections.indices) {
            val startMinutes = clockMinutes(sections[index].startTime) ?: 0
            val endMinutes = clockMinutes(sections[index].endTime) ?: (startMinutes + 1)
            if (minutes < startMinutes) return index + 1
            if (minutes < endMinutes) return index + 1
        }
        return sections.size
    }

    /** [sectionNumberForTime] 的下一节，末节后回绕到 1（:215-224）。 */
    fun nextSectionNumberForTime(time: LocalDateTime, sections: List<SectionTimeData>): Int {
        if (sections.isEmpty()) return 1
        val current = sectionNumberForTime(time, sections)
        return if (current >= sections.size) 1 else current + 1
    }

    /** 节次环色（colorForSection，:375-383）：HSL 均匀取色。 */
    fun colorForSection(sectionNumber: Int, totalSections: Int): String {
        val safeTotal = if (totalSections < 1) 1 else totalSections
        val hueStep = 360.0 / safeTotal
        val hue = ((sectionNumber - 1).coerceIn(0, safeTotal - 1) * hueStep) % 360
        // HSL(hue, 0.58, 0.48) → RGB（与 Dart HSLColor.fromAHSL 同公式）。
        return hslToHex(hue, 0.58, 0.48)
    }

    private fun hslToHex(hue: Double, saturation: Double, lightness: Double): String {
        val c = (1 - Math.abs(2 * lightness - 1)) * saturation
        val hPrime = hue / 60.0
        val x = c * (1 - Math.abs(hPrime % 2 - 1))
        val m = lightness - c / 2
        val (r, g, b) = when (hPrime) {
            in 0.0..<1.0 -> Triple(c, x, 0.0)
            in 1.0..<2.0 -> Triple(x, c, 0.0)
            in 2.0..<3.0 -> Triple(0.0, c, x)
            in 3.0..<4.0 -> Triple(0.0, x, c)
            in 4.0..<5.0 -> Triple(x, 0.0, c)
            else -> Triple(c, 0.0, x)
        }
        fun channel(v: Double): String =
            String.format(Locale.ROOT, "%02x", ((v + m) * 255.0).toInt().coerceIn(0, 255))
        return "#${channel(r)}${channel(g)}${channel(b)}"
    }
}
