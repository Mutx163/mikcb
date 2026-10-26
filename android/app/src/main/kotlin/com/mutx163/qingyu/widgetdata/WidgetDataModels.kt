package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import java.time.LocalDateTime

/**
 * 超级岛/小组件数据面的阶段枚举（移植 lib/domain/live_activity_logic.dart）。
 *
 * [value] 与 Dart 枚举名字符串逐字一致——岛/原生通道与阶段去重键都用它，
 * 键名漂移会让原生侧 switch 落空。
 */
enum class LiveActivityStage(val value: String) {
    BEFORE_CLASS("beforeClass"),
    DURING_CLASS_STATUS_BAR("duringClassStatusBar"),
    DURING_CLASS("duringClass"),
    BEFORE_END("beforeEnd"),
    ;

    companion object {
        fun fromValue(raw: String?): LiveActivityStage? =
            entries.firstOrNull { it.value == raw }
    }
}

/** 里程碑标签键（live_activity_logic.dart:12-15，安卓侧按 R.string.milestone_* 解析）。 */
const val MILESTONE_RECENT_END_LABEL_KEY = "milestone_recent_end"
const val MILESTONE_NEXT_START_LABEL_KEY = "milestone_next_start"

/** 课末提醒窗口：岛在课结束前 10 分钟切「即将结束」（timetable_live_activity_service.dart:108）。 */
const val LIVE_END_REMINDER_WINDOW_MINUTES = 10L

/** 选课结果（live_activity_logic.dart:17-27 的 Dart 结构对应物）。 */
data class LiveActivityCourseSelection(
    val currentCourse: Course,
    val nextCourse: Course?,
    val stage: LiveActivityStage,
)

/** 单节时间（timetable_settings_live.dart 的 SectionTime 对应物；本族只需要起止钟点）。 */
data class SectionTimeData(val startTime: String, val endTime: String)

/** 进度里程碑（buildLiveProgressMilestones 的条目结构）。 */
data class LiveProgressMilestone(
    val offsetMillis: Long,
    val labelKey: String,
    val timeText: String,
)

/**
 * 桌面卡片快照状态（home_widget_snapshot_service.dart:8-18）。
 * [value] 是快照 JSON 的 state 键取值，与 Dart 逐字一致。
 */
enum class HomeWidgetSnapshotState(val value: String) {
    NO_COURSE("no_course"),
    UPCOMING("upcoming"),
    ONGOING("ongoing"),
    COMPLETED("completed"),
    HOLIDAY("holiday"),
}

/**
 * 周末文案档位（weekend_mood_logic.dart:14-23）。
 * 独立于快照 state：只决定「没课时那句空槽文案」换不换成周末。
 */
enum class WeekendMoodData(val value: String) {
    NONE("none"),
    REST("rest"),
    AHEAD("ahead"),
}

/** 课程色贯穿档位（widget_course_accent.dart:10-20 的字符串取值）。 */
enum class WidgetCourseAccentModeData(val value: String) {
    OFF("off"),
    BAR("bar"),
    BAR_AND_TEXT("bar_and_text"),
}

/**
 * 快照课程摘要（home_widget_snapshot_service.dart:20-70）。
 * 字段与 Dart HomeWidgetCourseSummary 一一对应。
 */
data class HomeWidgetCourseSummary(
    val id: String,
    val name: String,
    val shortName: String?,
    val location: String,
    val startTime: String,
    val endTime: String,
    val startSection: Int,
    val endSection: Int,
    val color: String,
) {
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "shortName" to shortName,
        "location" to location,
        "startTime" to startTime,
        "endTime" to endTime,
        "startSection" to startSection,
        "endSection" to endSection,
        "color" to color,
    )

    companion object {
        fun fromCourse(course: Course): HomeWidgetCourseSummary = HomeWidgetCourseSummary(
            id = course.id,
            name = course.name,
            shortName = course.shortName,
            location = course.location,
            startTime = course.startTime,
            endTime = course.endTime,
            startSection = course.startSection,
            endSection = course.endSection,
            color = course.color,
        )
    }
}

/** 下一场考试在快照里的投影字段（考试倒计时与刷新触发点共用）。 */
data class ExamFace(
    val id: String,
    val name: String,
    val dateTime: LocalDateTime,
    val startTime: String,
    val endTime: String,
    val location: String? = null,
) {
    /** Dart Exam.isExpired：结束时刻（畸形钟点按 23:59 兜底）已过。 */
    fun isExpired(now: LocalDateTime): Boolean {
        val end = examDateTimeWithFallback(endTime, fallbackHour = 23, fallbackMinute = 59)
        return now.isAfter(end)
    }

    /** Dart Exam.examStartDateTime：考试日本地墙上时刻的开始。 */
    val examStartDateTime: LocalDateTime
        get() = examDateTimeWithFallback(startTime, fallbackHour = 0, fallbackMinute = 0)

    private fun examDateTimeWithFallback(rawTime: String, fallbackHour: Int, fallbackMinute: Int): LocalDateTime {
        val normalized = normalizeTimeOfDay(rawTime, fallback = "%02d:%02d".format(fallbackHour, fallbackMinute))
        val parts = normalized.split(":")
        val h = parts[0].toIntOrNull() ?: fallbackHour
        val m = parts[1].toIntOrNull() ?: fallbackMinute
        return LocalDateTime.of(dateTime.year, dateTime.monthValue, dateTime.dayOfMonth, h, m)
    }

    companion object {
        /** Dart Exam.normalizeTimeOfDay：非法回落 fallback（exam.dart:125-142）。 */
        fun normalizeTimeOfDay(raw: String?, fallback: String = "08:30"): String {
            val value = (raw ?: "").trim()
            val m = Regex("^(\\d{1,2}):(\\d{1,2})$").find(value) ?: return fallback
            val hour = m.groupValues[1].toIntOrNull()
            val minute = m.groupValues[2].toIntOrNull()
            if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                return fallback
            }
            return "%02d:%02d".format(hour, minute)
        }

        /** Dart Exam.compareByStart：开始 → 结束 → id（exam.dart:283-297）。 */
        fun compareByStart(left: ExamFace, right: ExamFace): Int {
            val startCompare = left.examStartDateTime.compareTo(right.examStartDateTime)
            if (startCompare != 0) return startCompare
            val leftEnd = left.examDateTimeWithFallback(left.endTime, 23, 59)
            val rightEnd = right.examDateTimeWithFallback(right.endTime, 23, 59)
            val endCompare = leftEnd.compareTo(rightEnd)
            if (endCompare != 0) return endCompare
            return left.id.compareTo(right.id)
        }
    }
}

/** 情侣合并视图里课程的三色分类（couple_timetable_logic.dart:7）。 */
enum class CoupleCourseKind { MINE, PARTNER, TOGETHER }

/**
 * 伴侣（TA）绑定（partner_timetable_binding.dart 的消费子集）。
 * fromJson 与 Dart 同口径：取不到退安全默认，不让脏数据带走整个绑定。
 */
data class PartnerTimetableBinding(
    val partnerProfileId: String,
    val partnerName: String,
    val weekOffset: Int,
    val mineColorHex: String,
    val partnerColorHex: String,
    val togetherColorHex: String,
) {
    companion object {
        const val MINE_COLOR_DEFAULT = "#2196F3"
        const val PARTNER_COLOR_DEFAULT = "#E91E63"
        const val TOGETHER_COLOR_DEFAULT = "#9C27B0"

        /** 与 CoupleTimetableLogic.clampWeekOffset 一致。 */
        const val MIN_WEEK_OFFSET = -15
        const val MAX_WEEK_OFFSET = 15

        fun fromJson(json: Map<String, Any?>): PartnerTimetableBinding {
            fun readStr(key: String, fallback: String): String {
                val raw = json[key]
                return if (raw is String) raw else if (raw == null) fallback else raw.toString()
            }

            val weekOffsetRaw = json["weekOffset"]
            val weekOffset = (weekOffsetRaw as? Number)?.toInt() ?: 0
            return PartnerTimetableBinding(
                partnerProfileId = readStr("partnerProfileId", ""),
                partnerName = readStr("partnerName", "TA的课表"),
                weekOffset = weekOffset.coerceIn(MIN_WEEK_OFFSET, MAX_WEEK_OFFSET),
                mineColorHex = readStr("mineColorHex", MINE_COLOR_DEFAULT),
                partnerColorHex = readStr("partnerColorHex", PARTNER_COLOR_DEFAULT),
                togetherColorHex = readStr("togetherColorHex", TOGETHER_COLOR_DEFAULT),
            )
        }
    }
}

/**
 * 快照构建要消费的设置门面。
 *
 * Dart 侧 TimetableSettings 有 250+ 字段；本族只消费小组件/超级岛/节假日开关子集。
 * 按任务书纪律（不修改既有文件），用这个门面承接消费面——实现方既可以把
 * core.TimetableSettings 适配进来，也可以从 Flutter 存档 JSON 按键读取。
 * 默认值逐项对照 lib/models/timetable_settings.dart:760-910。
 */
data class WidgetSettingsFace(
    // widget 外观/行为（timetable_settings.dart:786-795）
    val widgetBackgroundStyle: String = "solid",
    val widgetCourseAccentMode: WidgetCourseAccentModeData = WidgetCourseAccentModeData.BAR_AND_TEXT,
    val widgetShowLocation: Boolean = true,
    val widgetShowCountdown: Boolean = true,
    val widgetHideCompletedCourses: Boolean = false,
    val widgetShowTomorrowCourses: Boolean = true,
    val widgetHeightAdjustment: Int = -11,
    val widgetCornerRadius: Int = 22,
    val widgetCountdownLeadMinutes: Int = 20,
    val widgetCountdownTextStyle: String = "smart",
    // live 阶段开关（timetable_settings.dart:830-886）
    val liveEnableBeforeClass: Boolean = true,
    val liveEnableDuringClass: Boolean = true,
    val liveEnableBeforeEnd: Boolean = true,
    val livePromoteDuringClass: Boolean = true,
    val liveShowDuringClassNotification: Boolean = true,
    val liveShowBeforeClassMinutes: Int = 20,
    val liveClassReminderStartMinutes: Int = 0,
    val liveEndSecondsCountdownThreshold: Int = 60,
    val liveTimeCorrectionSeconds: Int = 0,
    // 节假日（timetable_settings.dart:760/910）
    val enableHolidayMarking: Boolean = true,
    val holidayOverrideEnabled: Boolean = false,
    // 周次
    val semesterWeekCount: Int = 20,
    val semesterStartDate: LocalDateTime? = null,
)

/** 绑定卡构建用的档案门面（与 Dart TimetableProfile 的消费子集对应）。 */
data class ProfileFace(
    val id: String,
    val name: String,
    val courses: List<Course> = emptyList(),
    val exams: List<ExamFace> = emptyList(),
    val settings: WidgetSettingsFace = WidgetSettingsFace(),
    val currentWeek: Int = 1,
) {
    companion object {
        /** 便捷构造：settings 只差开学日时用。 */
        fun withSemesterStart(
            id: String,
            name: String,
            currentWeek: Int = 1,
            courses: List<Course> = emptyList(),
            exams: List<ExamFace> = emptyList(),
            semesterStartDate: LocalDateTime? = null,
        ): ProfileFace = ProfileFace(
            id = id,
            name = name,
            courses = courses,
            exams = exams,
            settings = WidgetSettingsFace(semesterStartDate = semesterStartDate),
            currentWeek = currentWeek,
        )
    }
}
