package com.mutx163.qingyu.pages.timetable

import kotlin.math.max

/**
 * 首页「周 → 日」摘要卡飞行的纯几何与节奏（2026-11-03，阶段 A）。
 *
 * ## 它补的是哪一刀
 *
 * 2026-11-02 只做了「28dp 圆角窗口从选中列长到整屏」——那是 Flutter 原版的一层，
 * 但不是主体。用户口径「还是很恶心的展开效果」：真正让原版读起来**不是擦除**的，
 * 是卡片**自己从格位飞向落点**（`morph_card_flight_layer.dart` /
 * `summary_card_flight.dart`）。本文件只承接摘要卡那一颗（阶段 A）；课程卡逐卡飞行
 * 是阶段 B。
 *
 * ## 逐项对齐的 Flutter 出处
 *
 * | 这里 | Flutter |
 * |---|---|
 * | [homeViewSummaryStartCell]（起点 = 星期栏当日格） | `summary_card_flight.dart:260-284` |
 * | [homeViewSummaryFlightRect]（逐分量 lerp） | 同文件 `:397-412` |
 * | [homeViewSummaryFlightCornerDp] 14 → 16 | 同文件 `:71-72` / `:412` |
 * | [HOME_VIEW_SUMMARY_FLIGHT_TEXT_SWITCH_AT] 0.45 换文案 | 同文件 `:378` |
 * | [homeViewSummarySurfaceAlpha] 前 30% 淡入卡面 | 同文件 `:434` |
 * | [homeViewSummaryWeekdayLine] / [homeViewSummaryDateLine] 字号与对齐 | 同文件 `:410-440` |
 *
 * ## 起点「算」、终点「量」
 *
 * 星期格是纯布局产物（`时间列宽 + 下标 × 日宽`），算出来的值与真实格子逐像素一致；
 * 摘要卡高度随内容变（考试 / 进行中 / 冲突 / 情侣空闲），算不出来。与 Flutter 同一条分工。
 *
 * 本文件**不 import Compose**：几何与节奏都能被 JVM 单测直接钉住
 * （`HomeViewExpandFlightTest`）。渲染层只允许调用这里的函数，不许另写插值公式。
 */

/** 转场层局部坐标里的像素矩形（原点 = 首页内容区左上角）。 */
data class HomeViewFlightRect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
) {
    val width: Float get() = max(0f, right - left)
    val height: Float get() = max(0f, bottom - top)
}

/** 起点圆角：星期格的点击水波纹半径（Flutter `SummaryFlightSpec.startRadius = 14`）。 */
const val HOME_VIEW_SUMMARY_FLIGHT_START_CORNER_DP = 14f

/**
 * 终点圆角：必须等于摘要卡的真实圆角（[com.mutx163.qingyu.components.QingyuCardDefaults.Corner]，
 * 16dp）。守卫 `HomeViewExpandFlightTest` 直接断言两者相等——改卡片圆角时这里必须一起改，
 * 否则落定那一帧会看到圆角跳一下。
 */
const val HOME_VIEW_SUMMARY_FLIGHT_END_CORNER_DP = 16f

/** 文案切换点：0.45 之前用星期格的紧凑日期，之后换成摘要卡的完整标题。 */
const val HOME_VIEW_SUMMARY_FLIGHT_TEXT_SWITCH_AT = 0.45f

/** 卡面淡入带：前 30% 只有格里的字在长大，卡面随之包上来（起点不能凭空冒出一张卡）。 */
const val HOME_VIEW_SUMMARY_FLIGHT_SURFACE_RAMP = 0.30f

/**
 * 起点：星期栏里选中日那一格在**内容区局部坐标**里的矩形。
 *
 * 星期栏在内容区之上，所以 `header` 的 `top` 是负数（例如 -40dp）。
 * 宽度取**整格**（星期栏的点击区铺满它），不是格子内部 1dp 外边距后的可视宽度。
 *
 * @param header 星期栏整条在本层坐标里的矩形（实测：左 / 上 / 宽 / 高）。
 * @param timeColumnWidth 周视图左侧时间列宽（像素）。
 * @param visibleDayCount 可见天数（隐藏周末时为 5）。
 * @param selectedDayIndex 选中日在 [visibleDayCount] 里的下标（越界静默夹到边界）。
 */
fun homeViewSummaryStartCell(
    header: HomeViewFlightRect,
    timeColumnWidth: Float,
    visibleDayCount: Int,
    selectedDayIndex: Int,
): HomeViewFlightRect {
    if (visibleDayCount <= 0) {
        // 退化成一个 1px 宽的点，避免调用方拿到 0 宽矩形后除零或画出 NaN。
        return HomeViewFlightRect(header.left, header.top, header.left + 1f, header.bottom)
    }
    val index = selectedDayIndex.coerceIn(0, visibleDayCount - 1)
    val dayWidth = max(1f, (header.width - timeColumnWidth) / visibleDayCount)
    val left = header.left + timeColumnWidth + index * dayWidth
    return HomeViewFlightRect(left, header.top, left + dayWidth, header.bottom)
}

/**
 * 某一帧的飞行矩形：四个分量逐项线性插值；宽高夹到 ≥1px。
 *
 * `progress == 0` 恰好等于 [start]（源格位），`progress == 1` 恰好等于 [end]（目标卡位），
 * 误差只来自 1px 夹底（正常格子与卡片都远大于 1px，所以实际为 0）。
 */
fun homeViewSummaryFlightRect(
    start: HomeViewFlightRect,
    end: HomeViewFlightRect,
    progress: Float,
): HomeViewFlightRect {
    val t = progress.coerceIn(0f, 1f)
    val left = lerp(start.left, end.left, t)
    val top = lerp(start.top, end.top, t)
    val width = max(1f, lerp(start.width, end.width, t))
    val height = max(1f, lerp(start.height, end.height, t))
    return HomeViewFlightRect(left, top, left + width, top + height)
}

/** 飞行中的圆角（dp）：14 → 16，与矩形同一条进度。 */
fun homeViewSummaryFlightCornerDp(progress: Float): Float = lerp(
    HOME_VIEW_SUMMARY_FLIGHT_START_CORNER_DP,
    HOME_VIEW_SUMMARY_FLIGHT_END_CORNER_DP,
    progress.coerceIn(0f, 1f),
)

/** 卡面可见度：起点 0（星期格里没有卡面），前 30% 淡入到 1。 */
fun homeViewSummarySurfaceAlpha(progress: Float): Float =
    (progress.coerceIn(0f, 1f) / HOME_VIEW_SUMMARY_FLIGHT_SURFACE_RAMP).coerceIn(0f, 1f)

/** 终点才有的「今天 · 第 N 周」：0.55 起淡入，0.90 到满。 */
fun homeViewSummaryMetaAlpha(progress: Float): Float =
    ((progress.coerceIn(0f, 1f) - 0.55f) / 0.35f).coerceIn(0f, 1f)

/** 终点才有的关闭叉：0.60 起淡入，1.00 到满。 */
fun homeViewSummaryCloseAlpha(progress: Float): Float =
    ((progress.coerceIn(0f, 1f) - 0.60f) / 0.40f).coerceIn(0f, 1f)

/**
 * 飞行卡里的一行字：位置 / 字号 / 水平对齐 / 透明度都由进度算出。
 *
 * 位置用「**对齐因子**」而不是算好的 left：文字真实宽度只有排版知道，
 * 用估算值在 50dp 的格子里会偏（Flutter 实测 `03/20` 偏 10px，见
 * `summary_card_flight.dart:448-457`）。因子 1 = 在卡里居中（格位那一端），
 * 0 = 靠左 14dp（摘要卡那一端），中间连续移动。
 */
data class HomeViewSummaryFlightLine(
    val text: String,
    val topDp: Float,
    val sizeSp: Float,
    val centerFactor: Float,
    val alpha: Float,
)

/** 起点那一行的星期名（「周五」）：固定 10sp / 顶边 6dp，后段淡出（终点标题里已含星期名）。 */
fun homeViewSummaryWeekdayLine(
    progress: Float,
    weekdayLabel: String,
): HomeViewSummaryFlightLine {
    val k = progress.coerceIn(0f, 1f)
    return HomeViewSummaryFlightLine(
        text = weekdayLabel,
        topDp = 6f,
        sizeSp = 10f,
        centerFactor = (1f - (k / 0.4f)).coerceIn(0f, 1f),
        // 0.25 起淡出、0.55 全消（Flutter `weekdayOpacity`，同文件 `:424`）。
        alpha = (1f - (k - 0.25f) / 0.3f).coerceIn(0f, 1f),
    )
}

/**
 * 第二行：格里的日期（「03/20」，8.5sp / 顶边 22dp）↔ 摘要卡标题（「10月27日 周二」，16sp / 顶边 46dp）。
 *
 * 文案在 [HOME_VIEW_SUMMARY_FLIGHT_TEXT_SWITCH_AT] 切换；字号 / 顶边 / 对齐连续插值。
 */
fun homeViewSummaryDateLine(
    progress: Float,
    cellDateLabel: String,
    titleLabel: String,
): HomeViewSummaryFlightLine {
    val k = progress.coerceIn(0f, 1f)
    return HomeViewSummaryFlightLine(
        text = if (k >= HOME_VIEW_SUMMARY_FLIGHT_TEXT_SWITCH_AT) titleLabel else cellDateLabel,
        topDp = lerp(22f, 46f, k),
        sizeSp = lerp(8.5f, 16f, k),
        centerFactor = (1f - (k / 0.4f)).coerceIn(0f, 1f),
        alpha = 1f,
    )
}

private fun lerp(a: Float, b: Float, t: Float): Float = a + (b - a) * t
