package com.mutx163.qingyu.pages.timetable

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.font.FontWeight

/**
 * 课程卡飞行的**两端实测登记处**（2026-11-03，阶段 B）。
 *
 * ## 为什么用实测而不是算
 *
 * 周网格的起点能算（`时间列宽 + 下标 × 日宽` + 节高 × 节次），但两处都算不准：
 * 网格在可滚动容器里（起点随滚动变化），日视图议程卡高度随内容变（课名折行、
 * 天气 / 单周备注行）。Flutter 侧同一分工：起点算、终点量；这里再退一步，
 * **两端都量**——两张卡本来就在组合树里，量一次比复算一份布局便宜，也不会偏。
 *
 * ## 为什么不是每帧读进度
 *
 * 卡片的「飞行期间不画」只在 `drawWithContent` 里判一个**布尔**
 * （[isFlying]），不读 `dayExpand.value`。周视图 / 日视图的子树都挂着恒定图层缓存
 * （2026-11-03 卡顿修复），一旦逐帧读进度，图层逐帧失效、缓存等于没挂。
 * 布尔只在展开起步与落定各翻一次。
 */
class CourseFlightMeasureHost(
    /** 是否处于「飞行区间」（展开起步到落定前）；由宿主用 `derivedStateOf` 提供。 */
    private val active: () -> Boolean,
) {
    /** 周网格卡面实测（根坐标 + 卡面填充色）。 */
    val weekSurfaces = mutableStateMapOf<String, CourseFlightSurface>()

    /** 日视图议程卡面实测（根坐标 + 卡面填充色）。 */
    val daySurfaces = mutableStateMapOf<String, CourseFlightSurface>()

    /** 周网格卡的文字行实测：键 `卡片键|行 id`。 */
    val weekTexts = mutableStateMapOf<String, CourseFlightTextAnchor>()

    /** 日视图议程卡的文字行实测：键 `卡片键|行 id`。 */
    val dayTexts = mutableStateMapOf<String, CourseFlightTextAnchor>()

    /** 周网格卡面：登记四边与填充色。 */
    fun weekSurfaceModifier(
        cardKey: String,
        fill: Color,
    ): Modifier = Modifier.onGloballyPositioned { coords ->
        val next = CourseFlightSurface(coords.boundsInRoot(), fill)
        if (weekSurfaces[cardKey] != next) weekSurfaces[cardKey] = next
    }

    /** 日视图卡面：登记四边与填充色。 */
    fun daySurfaceModifier(
        cardKey: String,
        fill: Color,
    ): Modifier = Modifier.onGloballyPositioned { coords ->
        val next = CourseFlightSurface(coords.boundsInRoot(), fill)
        if (daySurfaces[cardKey] != next) daySurfaces[cardKey] = next
    }

    /** 周网格卡的一行文字。 */
    fun weekTextModifier(
        cardKey: String,
        lineId: String,
        text: String,
        fontSizeSp: Float,
        weight: FontWeight,
        ink: Color,
        maxLines: Int,
        lineHeightSp: Float,
    ): Modifier = textModifier(weekTexts, cardKey, lineId, text, fontSizeSp, weight, ink, maxLines, lineHeightSp)

    /** 日视图卡的一行文字。 */
    fun dayTextModifier(
        cardKey: String,
        lineId: String,
        text: String,
        fontSizeSp: Float,
        weight: FontWeight,
        ink: Color,
        maxLines: Int,
        lineHeightSp: Float,
    ): Modifier = textModifier(dayTexts, cardKey, lineId, text, fontSizeSp, weight, ink, maxLines, lineHeightSp)

    /**
     * 这张卡是否正在飞（两端都量到才飞，与 Flutter `hasFlightTargetFor` 同判据）。
     *
     * **只在 draw 阶段调用**：读的是布尔 + 两个登记表的「有没有」，不逐帧读进度。
     */
    fun isFlying(cardKey: String): Boolean =
        active() && weekSurfaces.containsKey(cardKey) && daySurfaces.containsKey(cardKey)

    private fun textModifier(
        table: androidx.compose.runtime.snapshots.SnapshotStateMap<String, CourseFlightTextAnchor>,
        cardKey: String,
        lineId: String,
        text: String,
        fontSizeSp: Float,
        weight: FontWeight,
        ink: Color,
        maxLines: Int,
        lineHeightSp: Float,
    ): Modifier = Modifier.onGloballyPositioned { coords ->
        val next = CourseFlightTextAnchor(
            bounds = coords.boundsInRoot(),
            text = text,
            fontSizeSp = fontSizeSp,
            weight = weight,
            ink = ink,
            maxLines = maxLines,
            lineHeightSp = lineHeightSp,
        )
        val key = "$cardKey|$lineId"
        if (table[key] != next) table[key] = next
    }

    /** 某张周卡 Dispose 时移除它的周侧登记（P-4：跨周翻页不增长）。 */
    fun removeWeek(cardKey: String) {
        weekSurfaces.remove(cardKey)
        val prefix = "$cardKey|"
        weekTexts.keys.toList().forEach { if (it.startsWith(prefix)) weekTexts.remove(it) }
    }

    /** 某张日卡 Dispose 时移除它的日侧登记（P-4：换日/换周不增长）。 */
    fun removeDay(cardKey: String) {
        daySurfaces.remove(cardKey)
        val prefix = "$cardKey|"
        dayTexts.keys.toList().forEach { if (it.startsWith(prefix)) dayTexts.remove(it) }
    }

    /**
     * 清空四张登记表（P1-10）。宿主 Dispose 时调用：快照状态表挂在对象上，
     * 页面销毁后不清会一直持有 Rect / Color 引用。
     */
    fun clear() {
        weekSurfaces.clear()
        daySurfaces.clear()
        weekTexts.clear()
        dayTexts.clear()
    }
}

/** 一片卡面的实测：根坐标四边 + 当时的填充色（两端插值用）。 */
data class CourseFlightSurface(
    val bounds: Rect,
    val fill: Color,
)

/**
 * 一行文字的实测：根坐标四边 + 文案 / 字号（sp）/ 字重 / 墨色 / 最大行数 / 行高（sp）。
 *
 * [maxLines] / [lineHeightSp] 让飞行层按两端真实排版插值行数与行高（P1-5/6/7，
 * 不再靠 `lineId == "name"` 猜行数）。[lineHeightSp] = 0f 表示该行未显式指定行高。
 */
data class CourseFlightTextAnchor(
    val bounds: Rect,
    val text: String,
    val fontSizeSp: Float,
    val weight: FontWeight,
    val ink: Color,
    val maxLines: Int,
    val lineHeightSp: Float,
)

/**
 * 当前组合树里的飞行登记处。null = 不在首页展开态（独立日视图页 / 预览），一切不登记。
 */
val LocalCourseFlightMeasure = compositionLocalOf<CourseFlightMeasureHost?> { null }
