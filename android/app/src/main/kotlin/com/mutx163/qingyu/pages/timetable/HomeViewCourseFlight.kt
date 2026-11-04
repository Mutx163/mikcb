package com.mutx163.qingyu.pages.timetable

/**
 * 首页「周 → 日」展开时**课程卡逐卡飞行**的纯几何与节奏（2026-11-03，阶段 B）。
 *
 * 阶段 A（[HomeViewExpandFlight]）只补了摘要卡那一颗；本文件承接课程卡：
 * 每张卡从周网格里自己那格，飞到日视图议程里的实测落点。
 *
 * ## 对齐 Flutter 的出处
 *
 * | 这里 | Flutter |
 * |---|---|
 * | [homeViewCourseFlightRect] 逐分量 lerp | `morph_card_flight_layer.dart` 的 `_lerpRect` |
 * | [homeViewCourseFlightCornerDp] 8 → 16 | `flight_card_body.dart`（周卡 8，议程卡 16） |
 * | [homeViewCourseFlightShadowAlpha] 0 → 0.18 | 同文件 `shadowOpacity`（议程卡投影 0.18） |
 * | [HOME_VIEW_COURSE_FLIGHT_TEXT_SWITCH_AT] 0.45 换文案 | `flight_text_metrics.dart` 的 `kFlightTextSwitchAt` |
 * | [homeViewCourseFlightStartOnlyAlpha] 0.45→0.58 淡出 | 同文件「只起点有的行」注释 |
 * | [homeViewCourseFlightEndOnlyAlpha] 0.58→0.85 淡入 | 同文件「只终点有的行」注释 |
 *
 * ## Flutter 侧的三条处理策略（逐条复刻）
 *
 * 1. **不设逐卡延迟**：所有卡共用同一个 `progress`（`morph_card_flight_layer.dart`
 *    里每张卡拿到的是同一个 `animation`）。所以这里也没有 stagger，卡片同起同落。
 * 2. **只飞「两端都量到」的卡**：Flutter 用 `hasFlightTargetFor(courseId)` 过滤，
 *    没落点的卡（滚出视口的议程卡）留在原地不隐藏。这里有
 *    [CourseFlightMeasureHost.isFlying] 同一判据。
 * 3. **卡片多时降级文字**：逐字排版每张卡都要量两端锚点，卡一多就是线性开销。
 *    这里按 [homeViewCourseFlightTextMode] 三档：
 *    ≤ [HOME_VIEW_COURSE_FLIGHT_FULL_TEXT_MAX_CARDS] 全量行；
 *    再多只留课名 + 时间（[HOME_VIEW_COURSE_FLIGHT_COMPACT_TEXT_MAX_CARDS] 以内）；
 *    超过后**只飞卡面**（文字全不画）。卡面本身永远飞，观感主体的「卡片自己过去」不丢。
 *
 * 本文件**不 import Compose**：几何与节奏都能被 JVM 单测直接钉住
 * （`HomeViewCourseFlightTest`）。渲染层只允许调用这里的函数，不许另写插值公式。
 */

/** 起点圆角：周网格课卡的卡面圆角（[WeekCardMetrics.CORNER_RADIUS_DP] 同值）。 */
const val HOME_VIEW_COURSE_FLIGHT_START_CORNER_DP = 8f

/** 终点圆角：日视图议程卡的卡面圆角（`DayViewCourseCard.radius` 默认 16dp；别改真卡）。 */
const val HOME_VIEW_COURSE_FLIGHT_END_CORNER_DP = 16f

/** 投影终点强度（议程卡同款）。 */
const val HOME_VIEW_COURSE_FLIGHT_SHADOW_ALPHA = 0.18f

/** 文案切换点：0.45 之前用周网格卡的紧凑文案，之后换成议程卡文案。 */
const val HOME_VIEW_COURSE_FLIGHT_TEXT_SWITCH_AT = 0.45f

/** 只起点有的行（周数 / 备注 / 天气）开始淡出的进度（到 0.58 全消）。 */
const val HOME_VIEW_COURSE_FLIGHT_START_ONLY_FADE_END = 0.58f

/** 只终点有的行的淡入区间：0.58 起，0.85 到满。 */
const val HOME_VIEW_COURSE_FLIGHT_END_ONLY_FADE_START = 0.58f
const val HOME_VIEW_COURSE_FLIGHT_END_ONLY_FADE_END = 0.85f

/** 全量文字卡片的张数上限（超过后只留课名 + 时间）。 */
const val HOME_VIEW_COURSE_FLIGHT_FULL_TEXT_MAX_CARDS = 10

/** 连课名 + 时间都不再画的张数上限（超过后只飞卡面）。 */
const val HOME_VIEW_COURSE_FLIGHT_COMPACT_TEXT_MAX_CARDS = 16

/** 飞行卡上各行 id 的**固定绘制顺序**（先画的在下，后画的压在上面）。 */
val HOME_VIEW_COURSE_FLIGHT_LINE_ORDER: List<String> = listOf(
    "overline",
    "name",
    "teacher",
    "location",
    "time",
    "timeEnd",
    "weeks",
    "description",
    "weather",
    "note",
)

/** 文字档位：全量 / 只课名与时间 / 只飞卡面。 */
enum class HomeViewCourseFlightTextMode {
    FULL,
    COMPACT,
    SURFACE_ONLY,
}

/**
 * 飞行卡的卡片键：`周|星期|课程 id|起始节`。
 *
 * 同一门课一周可能出现在多列、同一门课在不同周也各有一张卡；只用课程 id
 * 会让不同周的测量互相覆盖（pager 邻居页也在组合）。
 *
 * **两端必须传同一个原始起始节**（取 `course.startSection`），越界规整只在这里做一次
 * （`coerceAtLeast(1)`）——否则周侧 `coerceIn(1, sectionCount)`、日侧不 coerce 时，
 * 脏数据（如 startSection ≤ 0 或超节数）会让两端 key 不等、配对断掉（P-5）。
 */
fun courseFlightCardKey(week: Int, dayOfWeek: Int, courseId: String, startSection: Int): String =
    "$week|$dayOfWeek|$courseId|${startSection.coerceAtLeast(1)}"

/** 某一帧的飞行矩形：四边逐分量 lerp（与 Flutter `_lerpRect` 同一条）。 */
fun homeViewCourseFlightRect(
    start: HomeViewFlightRect,
    end: HomeViewFlightRect,
    progress: Float,
): HomeViewFlightRect = homeViewSummaryFlightRect(start, end, progress)

/** 飞行中的圆角（dp）：8（周卡）→ 16（真议程卡默认半径），与矩形同一条进度。 */
fun homeViewCourseFlightCornerDp(progress: Float): Float {
    val t = progress.coerceIn(0f, 1f)
    return HOME_VIEW_COURSE_FLIGHT_START_CORNER_DP +
        (HOME_VIEW_COURSE_FLIGHT_END_CORNER_DP - HOME_VIEW_COURSE_FLIGHT_START_CORNER_DP) * t
}

/** 投影强度：0 → 0.18，与 Flutter `shadowOpacity` 同一条。 */
fun homeViewCourseFlightShadowAlpha(progress: Float): Float =
    HOME_VIEW_COURSE_FLIGHT_SHADOW_ALPHA * progress.coerceIn(0f, 1f)

/** 只起点有的行：切换点之后快速淡出（0.45 → 0.58），避免两种写法同时在屏。 */
fun homeViewCourseFlightStartOnlyAlpha(progress: Float): Float {
    val k = progress.coerceIn(0f, 1f)
    return (1f - (k - HOME_VIEW_COURSE_FLIGHT_TEXT_SWITCH_AT) / 0.13f).coerceIn(0f, 1f)
}

/** 只终点有的行：等起点行淡完再进（0.58 → 0.85）。 */
fun homeViewCourseFlightEndOnlyAlpha(progress: Float): Float {
    val k = progress.coerceIn(0f, 1f)
    val span = HOME_VIEW_COURSE_FLIGHT_END_ONLY_FADE_END -
        HOME_VIEW_COURSE_FLIGHT_END_ONLY_FADE_START
    return ((k - HOME_VIEW_COURSE_FLIGHT_END_ONLY_FADE_START) / span).coerceIn(0f, 1f)
}

/** 共享行的文案用哪一端：0.45 之前起点，之后终点（与 Flutter 同一个切换点）。 */
fun homeViewCourseFlightUsesEndText(progress: Float): Boolean =
    progress.coerceIn(0f, 1f) >= HOME_VIEW_COURSE_FLIGHT_TEXT_SWITCH_AT

/** 按同时飞行的卡片张数决定文字档位（见文件头「卡片多时降级文字」）。 */
fun homeViewCourseFlightTextMode(cardCount: Int): HomeViewCourseFlightTextMode = when {
    cardCount <= HOME_VIEW_COURSE_FLIGHT_FULL_TEXT_MAX_CARDS -> HomeViewCourseFlightTextMode.FULL
    cardCount <= HOME_VIEW_COURSE_FLIGHT_COMPACT_TEXT_MAX_CARDS ->
        HomeViewCourseFlightTextMode.COMPACT
    else -> HomeViewCourseFlightTextMode.SURFACE_ONLY
}

/** 这一行在这个档位下要不要画（[HomeViewCourseFlightTextMode.SURFACE_ONLY] 一律不画）。 */
fun homeViewCourseFlightLineVisible(
    mode: HomeViewCourseFlightTextMode,
    lineId: String,
): Boolean = when (mode) {
    HomeViewCourseFlightTextMode.FULL -> lineId in HOME_VIEW_COURSE_FLIGHT_LINE_ORDER
    HomeViewCourseFlightTextMode.COMPACT -> lineId == "name" || lineId == "time"
    HomeViewCourseFlightTextMode.SURFACE_ONLY -> false
}

/**
 * 换文案点处的最大行数（P1-5/6）：0.45 之前用起点卡的（周卡课名按 span 可 4/3/2 行、
 * 简介 2 行），之后用终点卡的（日卡课名 2 行）。飞行层不再硬编码 `name?2:1`。
 */
fun homeViewCourseFlightMaxLines(
    weekMaxLines: Int,
    dayMaxLines: Int,
    useEndText: Boolean,
): Int = if (useEndText) dayMaxLines else weekMaxLines

/**
 * 飞行中的行高（sp，P1-7）：两端都有实测行高时线性插值；一端为 0（未指定）时按换文案点取。
 * 保证落定那一帧的文字高度与真卡一致，不跳一下。
 */
fun homeViewCourseFlightLineHeight(
    weekLineHeightSp: Float,
    dayLineHeightSp: Float,
    progress: Float,
): Float {
    val t = progress.coerceIn(0f, 1f)
    return when {
        weekLineHeightSp > 0f && dayLineHeightSp > 0f ->
            weekLineHeightSp + (dayLineHeightSp - weekLineHeightSp) * t
        t >= HOME_VIEW_COURSE_FLIGHT_TEXT_SWITCH_AT -> dayLineHeightSp
        else -> weekLineHeightSp
    }
}
