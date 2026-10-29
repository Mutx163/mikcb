package com.mutx163.qingyu.pages.timetable

/**
 * 周视图渲染风格：**设置存档 → 渲染层**的纯数据桥（无 Compose / Android 依赖）。
 *
 * ## 为什么单独一层
 *
 * 2026-10-27 的域审核（`.agents/compose-phase3/audit-2026-10-27/G2-timetable.md`）
 * 给周视图的判定是「需重做」，首要原因不是缺件，而是**渲染层不读设置**：
 * 卡面字段开关（课名/教师/地点/时间/周次/简介）、字号、对齐、材质、冲突透明度、
 * 时间列显示档、星期栏字色……在设置模型里全都有键，页面一个都没接，于是
 * 「设置里改了没反应」。
 *
 * 本类把「Dart 侧渲染真正读到的那些键」收成一个不可变快照：
 * - 渲染层只认 [WeekViewStyle]，不直接摸 `TimetableSettingsModel`（分层）；
 * - 从设置模型到本类的映射只有一处 —— [TimetableStyleMapping.weekViewStyle]，
 *   带逐键行号，单测钉住（改映射不改渲染就会红）。
 *
 * 默认值**逐条对齐 Dart 构造默认**（`lib/models/timetable_settings.dart`），
 * 不是拍脑袋选的，见每个字段后面的行号注释。
 */
data class WeekViewStyle(
    // ── 课卡内容（Dart `:1405-1413`）──
    val showName: Boolean = true,
    val showTeacher: Boolean = true,
    val showLocation: Boolean = true,
    val showTime: Boolean = false,
    val showTimeLabels: Boolean = true,
    val showWeeks: Boolean = false,
    val showDescription: Boolean = false,
    // ── 课卡排版（Dart `:1432` `courseCardFontSize` / `:1386` `compactFontSize`）──
    val cardTitleFontSize: Float = 9f,
    val compactFontSize: Float = 9f,
    val verticalAlign: WeekCardVerticalAlign = WeekCardVerticalAlign.CENTER,
    val horizontalAlign: WeekCardHorizontalAlign = WeekCardHorizontalAlign.CENTER,
    // ── 材质与配色（Dart `:1420?` `courseCardSurfaceStyle` / `:1726-1728` 统一色）──
    val surfaceStyle: WeekCardSurface = WeekCardSurface.SOLID,
    val unifiedCardColorHex: String? = null,
    val cardTitleColorLight: String = "#FFFFFF",
    val cardTitleColorDark: String = "#FFFFFF",
    val cardDetailColorLight: String = "#FFFFFF",
    val cardDetailColorDark: String = "#FFFFFF",
    // ── 冲突（Dart `:1400` / `timetableConflictCourseOpacity` 默认 0.70）──
    val showConflictBadge: Boolean = true,
    val conflictCourseOpacity: Float = 0.70f,
    // ── 时间列（Dart `SectionTimeDisplayMode` 读侧缺省 `startAndEnd`）──
    val sectionTimeMode: WeekSectionTimeMode = WeekSectionTimeMode.START_AND_END,
    // ── 密度（Dart `:1385` sectionHeight=68 / `:1433` 时间列宽 / 卡片间隙）──
    val sectionHeightDp: Float = 68f,
    val autoFitSectionHeight: Boolean = false,
    val timeColumnWidthDp: Float = 34f,
    val cardInsetDp: Float = 1.25f,
    // ── 周网格内容（Dart `:1416-1417` / `:1531` / `:1541`）──
    val showNonCurrentWeekCourses: Boolean = false,
    val showWeekGridExams: Boolean = true,
    val showWeekGridSchedules: Boolean = true,
    val longPressEmptySlotToAddCourse: Boolean = false,
    val holidayMarkingEnabled: Boolean = true,
    // ── 墨色（Dart `:1755-1770`，用户可改；壁纸下另有明暗自适应，本层只管配出色）──
    val weekdayFontColorLight: String = "#000000",
    val weekdayFontColorDark: String = "#FFFFFF",
    val weekdayAccentColorLight: String = "#2563EB",
    val weekdayAccentColorDark: String = "#93C5FD",
    val timeAxisColorLight: String = "#757575",
    val timeAxisColorDark: String = "#FFFFFF",
    // ── 「回本周」浮钮（Dart `BackToCurrentWeekButtonStyle` 读侧恒 floating）──
    val showBackToCurrentWeek: Boolean = true,
    val backToCurrentWeekOpacity: Float = 0.96f,
    // ── 天气（Dart `:1419-1424`；本周视图尚未接线，先留好口径）──
    val showWeatherOnCard: Boolean = true,
)

/** 课卡材质（Dart `CourseCardSurfaceStyle`：solid / gaussian / refraction）。 */
enum class WeekCardSurface { SOLID, TRANSLUCENT, GAUSSIAN }

/** 课卡内容纵向对齐（Dart `CourseCardVerticalAlign`）。 */
enum class WeekCardVerticalAlign { TOP, CENTER, BOTTOM, SPACE_EVENLY }

/** 课卡内容横向对齐（Dart `CourseCardHorizontalAlign`）。 */
enum class WeekCardHorizontalAlign { LEFT, CENTER, RIGHT }

/** 时间列每节的显示档（Dart `SectionTimeDisplayMode`）。 */
enum class WeekSectionTimeMode { HIDDEN, START_ONLY, START_AND_END }

/**
 * 节次渲染高度（唯一事实来源，对应 Dart `domain/timetable_layout.dart:gridSectionHeight`）。
 *
 * - 未开「自动充满高度」⇒ 直接用设置里的节高；
 * - 开了 ⇒ `(可用高 - 星期栏高) / 节数`（不小于 0）。
 *
 * 与 Dart 一样不做上限 clamp：Dart 侧课表视图也没有 clamp（只有导出文档 clamp）。
 */
fun weekSectionHeight(
    style: WeekViewStyle,
    availableHeightDp: Float,
    weekdayHeaderHeightDp: Float,
    sectionCount: Int,
): Float {
    if (!style.autoFitSectionHeight || sectionCount <= 0) return style.sectionHeightDp
    val body = (availableHeightDp - weekdayHeaderHeightDp).coerceAtLeast(0f)
    return body / sectionCount
}
