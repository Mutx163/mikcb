package com.mutx163.qingyu.pages.statistics.charts

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** 画布上的一个点（px）。 */
data class ChartPoint(val x: Float, val y: Float)

/** 三次贝塞尔的两个控制点（px）。 */
data class CubicControls(val c1x: Float, val c1y: Float, val c2x: Float, val c2y: Float)

/** 环形图的一段弧：起始角与扫过角（度，0° 指向圆心右侧，顺时针增长）。 */
data class DonutArc(val startDegrees: Float, val sweepDegrees: Float)

/** 环形图几何：半径 / 中心孔半径 / 是否需要中心提示。 */
data class DonutGeometry(
    val radius: Float,
    val centerRadius: Float,
    val missingLabel: String?,
    val hasData: Boolean,
)

/** 环形图一段（含"空侧补位段"）。 */
data class DonutSlice(
    val value: Double,
    val nature: NatureKind,
    /** 补位段：某侧 0 门课时补一段极浅轨道，避免纯色圆被误读为 100%。 */
    val placeholder: Boolean,
) {
    enum class NatureKind { REQUIRED, ELECTIVE }
}

/** 柱状图单根的强调档（决定颜色）。 */
enum class BarEmphasis { MAX, MIN, NORMAL }

/**
 * 统计图表层的**纯几何 / 纯算法**内核。
 *
 * 全部数值从 Dart 侧 `lib/widgets/statistics/` 下的 fl_chart 配置逐条抄来，
 * 每条 KDoc 标了出处行；这些函数不碰 Compose、不碰 Android，可直接进 JVM 单测。
 *
 * ## 为什么算法要单独成层
 *
 * 图表一旦"看起来差不多"，错在哪里就没人查得出来了。刻度上限、点位映射、
 * 热力分级、并列名次都是**人可以先手算**的量，所以期望值写在 `ChartMathTest` 里
 * 由人推出来（不是从实现里抄），实现改坏一处就红一条。
 */
object ChartMath {

    // ══════════════════════ 刻度上限 ══════════════════════

    /**
     * 纵轴上限：**最大值 + 1**（Dart `trend_chart.dart:32` `maxY: (maxY + 1).toDouble()`
     * ；`daily_chart.dart:31`、`week_stats_view.dart:206` 同口径）。
     *
     * 下限钳到 1：全零数据时 fl_chart 若 maxY=1 仍是合法值域，而 maxY=0 会让
     * 归一化除零。这条钳制是迁移时补的（Dart 侧 `fold` 从 0 起算，全零时
     * `(0+1)` 恰好也是 1，所以行为一致）。
     */
    fun axisMax(value: Int): Double = axisMax(value.toDouble())

    /** 见 [axisMax] 的 Int 重载。 */
    fun axisMax(value: Double): Double = (value + AXIS_HEADROOM).coerceAtLeast(1.0)

    /** 纵轴留白：恒为 1 个单位（"最高柱上方留一格"）。 */
    const val AXIS_HEADROOM: Double = 1.0

    /**
     * 折线图横轴刻度的间隔（周）：`trend_chart.dart:176-183` `_labelInterval`。
     *
     * | 最后一周 | 间隔 |
     * |---|---|
     * | ≤ 6  | 1 |
     * | ≤ 12 | 2 |
     * | ≤ 24 | 4 |
     * | 其它 | 8 |
     */
    fun trendLabelInterval(lastWeek: Int): Int = when {
        lastWeek <= 6 -> 1
        lastWeek <= 12 -> 2
        lastWeek <= 24 -> 4
        else -> 8
    }

    /**
     * 纵轴刻度间隔：`null` 表示交给图表自己算（fl_chart 的自动间隔）。
     *
     * 出处：`trend_chart.dart:83` `interval: maxY > 8 ? null : 2`
     * ；`daily_chart.dart:139` `maxAverage > 4 ? null : 1`
     * ；`week_stats_view.dart:271` `maxSections > 6 ? null : 1`。
     *
     * @param maxValue 纵轴数据最大值（注意是原始值，不是加了留白的上限）
     * @param autoAbove 超过这个值就交给自动间隔
     * @param manualInterval 不超过时的手动间隔
     */
    fun axisTitleInterval(maxValue: Double, autoAbove: Double, manualInterval: Int): Int? =
        if (maxValue > autoAbove) null else manualInterval

    /**
     * 横轴网格线是否绘制：三张图都是 `drawVerticalLine: false`（只画横向网格）。
     */
    fun drawVerticalGridLine(): Boolean = false

    // ══════════════════════ 百分比 / 比例归一 ══════════════════════

    /** 占比；[total] ≤ 0 时返回 0（不抛、不 NaN）。 */
    fun ratio(part: Int, total: Int): Double =
        if (total > 0) part.toDouble() / total else 0.0

    /** 占比并四舍五入成整数百分数（Dart `(ratio * 100).round()`，`nature_ratio.dart:186`）。 */
    fun percentRounded(part: Int, total: Int): Int = (ratio(part, total) * 100).roundToInt()

    /** 把值归一化到 0.0~1.0；[max] ≤ 0 时返回 0。 */
    fun normalize(value: Double, max: Double): Double =
        if (max <= 0.0) 0.0 else (value / max).coerceIn(0.0, 1.0)

    // ══════════════════════ 热力图分级 ══════════════════════

    /** 热力图档位数：空 + 4 档色阶（`heatmap_card.dart:38-46`）。 */
    const val HEAT_LEVEL_EMPTY = 0

    /** 热力图 4 档的透明度（`heatmap_card.dart:41-45`）。 */
    val HEAT_ALPHAS: List<Float> = listOf(0.22f, 0.45f, 0.68f, 1.0f)

    /**
     * 热力分级：0 表示空格（当日无课），1~4 表示由浅到深四档。
     *
     * 判据照抄 `heatmap_card.dart:36-46`：
     * ```
     * t = value / max(maxSections, 1)        // 钳 0..1
     * t < 0.25 → 档1   t < 0.5 → 档2   t < 0.75 → 档3   否则 档4
     * ```
     * 边界是**左闭右开**：t 恰为 0.25 落档 2，恰为 0.75 落档 4。
     */
    fun heatLevel(value: Int, maxSections: Int): Int {
        if (value <= 0) return HEAT_LEVEL_EMPTY
        val max = if (maxSections < 1) 1 else maxSections
        val t = (value.toDouble() / max).coerceIn(0.0, 1.0)
        return when {
            t < 0.25 -> 1
            t < 0.5 -> 2
            t < 0.75 -> 3
            else -> 4
        }
    }

    /** 档位 → 主色透明度；空格返回 0（渲染层改用"行高亮"底色）。 */
    fun heatAlpha(level: Int): Float =
        if (level <= HEAT_LEVEL_EMPTY) 0f else HEAT_ALPHAS[(level - 1).coerceIn(0, HEAT_ALPHAS.size - 1)]

    /** 该周是否标出周次文字：`week % 4 == 1` 或最后一周（`heatmap_card.dart:118`）。 */
    fun heatmapShowWeekLabel(week: Int, weekCount: Int): Boolean =
        week % 4 == 1 || week == weekCount

    // ══════════════════════ 柱状图几何 ══════════════════════

    /**
     * 每根柱子分到的槽宽（fl_chart `BarChartAlignment.spaceAround`：
     * 7 组均分整宽，柱子在槽内居中）。
     */
    fun barSlotWidth(canvasWidth: Float, count: Int): Float =
        if (count <= 0) 0f else canvasWidth / count

    /** 第 [index] 根柱子的中心 x（槽内居中）。 */
    fun barCenterX(index: Int, count: Int, canvasWidth: Float): Float {
        if (count <= 0) return 0f
        val slot = barSlotWidth(canvasWidth, count)
        return slot * index + slot / 2f
    }

    /**
     * 柱子绘制宽度。
     *
     * Dart 写死 `width: 20`（`daily_chart.dart:204`、`week_stats_view.dart:337`）。
     * 迁移时补一条上限：**不超过槽宽的一半**——窄屏（7 槽挤在 200dp 里）时
     * 固定 20dp 会让相邻柱粘连，钳制只在那种情况下生效，常规宽度下与 Dart 等价。
     */
    fun barWidthPx(slotWidth: Float, capPx: Float, maxSlotFraction: Float = 0.5f): Float =
        min(capPx, slotWidth * maxSlotFraction)

    /** 柱顶 y 坐标（自画布底部向上生长）。 */
    fun barTopY(value: Double, maxY: Double, canvasHeight: Float): Float {
        if (maxY <= 0.0) return canvasHeight
        val h = canvasHeight * (value / maxY).coerceIn(0.0, 1.0)
        return canvasHeight - h.toFloat()
    }

    /**
     * 每日平均课时图（学期口径）的柱子强调档 —— `daily_chart.dart:174-180`：
     * ```
     * isMax = 有活跃日 && value == maxAverage
     * isMin = 有活跃日 && value == minAverage && value > 0
     * 颜色优先级：MAX > MIN > NORMAL
     * ```
     * 注意 `isMax` **不排除 0**：若整周都是 0（`activeDays` 为空）则谁都不是强调色。
     */
    fun dailyBarEmphasis(value: Double, maxAverage: Double, minAverage: Double, activeDayCount: Int): BarEmphasis =
        when {
            activeDayCount <= 0 -> BarEmphasis.NORMAL
            value == maxAverage -> BarEmphasis.MAX
            value == minAverage && value > 0.0 -> BarEmphasis.MIN
            else -> BarEmphasis.NORMAL
        }

    /**
     * 周视图每日课时图（单周口径）的柱子强调档 —— `week_stats_view.dart:317-322`：
     * ```
     * isMax = value == maxSections && value > 0
     * isMin = value == minSections && value > 0 && !isMax     ← 比学期口径多了 !isMax
     * ```
     * 两个口径的差别是**真实的**（整周只有一天有课时，学期口径会同时命中 max 与 min
     * 而按优先级取 MAX；周口径显式排除）。
     */
    fun weekBarEmphasis(value: Int, maxSections: Int, minSections: Int): BarEmphasis = when {
        value == maxSections && value > 0 -> BarEmphasis.MAX
        value == minSections && value > 0 -> BarEmphasis.MIN
        else -> BarEmphasis.NORMAL
    }

    // ══════════════════════ 折线点位映射 ══════════════════════

    /**
     * 数据域 → 画布 x。值域退化（首尾同周）时退到画布正中，
     * 避免除以 0（fl_chart 在这种情况下会画出 NaN 路径）。
     */
    fun mapX(value: Double, domainMin: Double, domainMax: Double, canvasWidth: Float): Float {
        val span = domainMax - domainMin
        if (abs(span) < 1e-9) return canvasWidth / 2f
        return ((value - domainMin) / span * canvasWidth).toFloat().coerceIn(0f, canvasWidth)
    }

    /** 数据域 → 画布 y（y 轴向上为正，画布向下为正，故反向）。超出值域钳在画布内。 */
    fun mapY(value: Double, domainMax: Double, canvasHeight: Float): Float {
        if (domainMax <= 0.0) return canvasHeight
        return (canvasHeight - value / domainMax * canvasHeight).toFloat().coerceIn(0f, canvasHeight)
    }

    // ══════════════════════ 平滑曲线 ══════════════════════

    /**
     * Catmull-Rom → 三次贝塞尔的控制点。
     *
     * fl_chart `isCurved: true` + `curveSmoothness: 0.25`（`trend_chart.dart:129,157`）：
     * 曲线穿过每个数据点，控制点沿「前一点→后一点」的切线方向偏移
     * `smoothness / 2` 个切向量。首尾点用端点自身兜底（不在两端甩出画布）。
     *
     * 不变量（单测钉住的）：三个等距共线点时，两个控制点必然**仍在这条直线上**
     * ——线性数据画出来必须是直线，不能被平滑拐弯。
     */
    fun cubicControls(
        x0: Float, y0: Float,
        x1: Float, y1: Float,
        x2: Float, y2: Float,
        x3: Float, y3: Float,
        smoothness: Float = CURVE_SMOOTHNESS,
    ): CubicControls {
        val k = smoothness / 2f
        return CubicControls(
            c1x = x1 + (x2 - x0) * k,
            c1y = y1 + (y2 - y0) * k,
            c2x = x2 - (x3 - x1) * k,
            c2y = y2 - (y3 - y1) * k,
        )
    }

    /** 折线平滑度（Dart `curveSmoothness: 0.25`）。 */
    const val CURVE_SMOOTHNESS: Float = 0.25f

    /**
     * 把一条折线按虚线节奏切成若干实线段。
     *
     * Dart 侧未来周用 `dashArray: [6, 4]`（`trend_chart.dart:156`）= 实 6 画 4，
     * 周期 10px。这里沿折线累积长度推进，跨拐点自动续接；长度不足一个虚线段时
     * 直接截断（不画零长度段，避免 Compose 画出圆头小点）。
     */
    fun dashPolyline(
        points: List<ChartPoint>,
        dash: Float = 6f,
        gap: Float = 4f,
    ): List<List<ChartPoint>> {
        if (points.size < 2) return emptyList()
        if (dash <= 0f) return listOf(points)
        if (gap <= 0f) return listOf(points)

        val result = mutableListOf<List<ChartPoint>>()
        var current = mutableListOf<ChartPoint>()
        var drawing = true
        // 当前相位（处于实线段/空白段的第几个像素；每切换状态归零）
        var phase = 0f

        for (i in 0 until points.size - 1) {
            val a = points[i]
            val b = points[i + 1]
            val dx = b.x - a.x
            val dy = b.y - a.y
            val segLen = kotlin.math.sqrt(dx * dx + dy * dy)
            if (segLen <= 0f) continue
            var travelled = 0f
            while (travelled < segLen - 1e-4f) {
                // 本段的"当前状态总长"：实线 dash / 空白 gap
                val slotLen = if (drawing) dash else gap
                val step = min(slotLen - phase, segLen - travelled)
                val t1 = (travelled + step) / segLen
                if (drawing) {
                    if (current.isEmpty()) current.add(ChartPoint(a.x, a.y))
                    current.add(ChartPoint(a.x + dx * t1, a.y + dy * t1))
                }
                travelled += step
                phase += step
                if (phase >= slotLen - 1e-4f) {
                    if (drawing) {
                        if (current.size >= 2) result.add(current)
                        current = mutableListOf()
                    } else {
                        current = mutableListOf(ChartPoint(a.x + dx * t1, a.y + dy * t1))
                    }
                    drawing = !drawing
                    phase = 0f
                }
            }
        }
        if (current.size >= 2) result.add(current)
        return result
    }

    // ══════════════════════ 环形图（必修 / 选修） ══════════════════════

    /** 环形图各段之间的缝隙角度（Dart `sectionsSpace: 2`，`nature_ratio.dart:96`）。 */
    const val DONUT_SECTIONS_SPACE_DEG = 2f

    /** 正常态环半径（`nature_ratio.dart:93`）。 */
    const val DONUT_RADIUS = 20f

    /** 缺一侧时的环半径：细一圈，给中心提示文案腾地方（`nature_ratio.dart:93`）。 */
    const val DONUT_RADIUS_WITH_LABEL = 18f

    /** 正常态中心孔半径（`nature_ratio.dart:94`，20 + 28 = 48 → 直径 96 < 100 容器）。 */
    const val DONUT_CENTER_RADIUS = 28f

    /** 缺一侧时的中心孔半径：加大 4dp 防多语言文案溢出（`nature_ratio.dart:94`）。 */
    const val DONUT_CENTER_RADIUS_WITH_LABEL = 32f

    /**
     * 环形图几何。
     *
     * 单侧缺失（必修=0 / 选修=0）时：环细一圈、孔加大，并给出中心提示文案
     * （两侧对称：必修为 0 优先报"暂无必修"）。
     */
    fun donutGeometry(requiredCount: Int, electiveCount: Int): DonutGeometry {
        val hasData = requiredCount + electiveCount > 0
        val missing = when {
            !hasData -> null
            requiredCount == 0 -> ChartsStrings.statisticsNatureNoneRequired.zh
            electiveCount == 0 -> ChartsStrings.statisticsNatureNoneElective.zh
            else -> null
        }
        val labelled = missing != null
        return DonutGeometry(
            radius = if (labelled) DONUT_RADIUS_WITH_LABEL else DONUT_RADIUS,
            centerRadius = if (labelled) DONUT_CENTER_RADIUS_WITH_LABEL else DONUT_CENTER_RADIUS,
            missingLabel = missing,
            hasData = hasData,
        )
    }

    /**
     * 环形图的段列表（对齐 `nature_ratio.dart:97-125` 的 sections 顺序）：
     * 必修 → 选修 →（必修为 0 时）必修补位段 →（选修为 0 时）选修补位段。
     *
     * 补位段 `value = 1`、透明度 0.12：fl_chart 对 value=0 的段不画弧，
     * 补一段极浅轨道让"这一侧是空的"看得见，而不是被误读成 100%。
     */
    fun donutSlices(requiredCount: Int, electiveCount: Int): List<DonutSlice> {
        val slices = mutableListOf<DonutSlice>()
        slices.add(DonutSlice(requiredCount.toDouble(), DonutSlice.NatureKind.REQUIRED, false))
        slices.add(DonutSlice(electiveCount.toDouble(), DonutSlice.NatureKind.ELECTIVE, false))
        if (requiredCount == 0) {
            slices.add(DonutSlice(1.0, DonutSlice.NatureKind.REQUIRED, true))
        }
        if (electiveCount == 0) {
            slices.add(DonutSlice(1.0, DonutSlice.NatureKind.ELECTIVE, true))
        }
        return slices
    }

    /** 起始角：12 点钟方向（fl_chart 默认从 -90° 起画，顺时针）。 */
    const val DONUT_START_DEG = -90f

    /**
     * 段值 → 弧角度。每段占 `value / total * 360`，实际画出来两边各让出
     * `sectionsSpace / 2`，于是相邻两段之间留出完整的 `sectionsSpace` 度缝隙。
     *
     * 段太窄时扫角钳到 0（不画反向弧）。
     */
    fun donutArcs(values: List<Double>, sectionsSpaceDeg: Float = DONUT_SECTIONS_SPACE_DEG): List<DonutArc> {
        val total = values.sum()
        if (total <= 0.0) return values.map { DonutArc(DONUT_START_DEG, 0f) }
        var cursor = DONUT_START_DEG
        return values.map { v ->
            val sweep = (v / total * 360.0).toFloat()
            val arc = DonutArc(
                startDegrees = cursor + sectionsSpaceDeg / 2f,
                sweepDegrees = max(0f, sweep - sectionsSpaceDeg),
            )
            cursor += sweep
            arc
        }
    }

    // ══════════════════════ 名次 ══════════════════════

    /**
     * 名次：**序号即名次**，`[a,b,c,d]` → `[1,2,3,4]`。
     *
     * 严格对齐 Dart 原实现 `course_ranking.dart:52` `rank: index + 1`。
     *
     * ## 已知缺陷（**本批有意不修**）
     *
     * Dart 对并列**不做处理**：两门课时完全相同的课会被编成 2、3 号，
     * 看上去像"一样多却排在后面"。改成竞赛式并列（2、2、4）在语义上更对，
     * 但会让 L4 真机逐页对照时出现"同样数据、两版名次不一样"，
     * 用户只会当成迁移 bug 报回来。
     *
     * 2026-10-27 Lead 拍板：**保 1:1 对照基线**，改进等对照完成后再单开一批，
     * 两侧一起改。此处留文档而不是留一个悄悄改掉的实现。
     */
    fun sequentialRanks(count: Int): List<Int> =
        if (count <= 0) emptyList() else (1..count).toList()

    /** 单门课的名次（0 基下标 → 1 基名次）。 */
    fun rankOf(index: Int): Int = index + 1

    // ══════════════════════ 文案数字格式 ══════════════════════

    /** 保留一位小数（Dart `toStringAsFixed(1)`）。 */
    fun oneDecimal(value: Double): String {
        val rounded = (value * 10.0).roundToInt()
        val whole = rounded / 10
        val frac = abs(rounded % 10)
        return "$whole.$frac"
    }

    /**
     * 差值文案：正数带 `+`，负数带 `-`，零是 `0`
     * （`weekly_comparison_card.dart:32` `deltaText`）。
     */
    fun deltaText(delta: Int): String = when {
        delta > 0 -> "+$delta"
        delta < 0 -> delta.toString()
        else -> "0"
    }

    /** 差值的语义方向（决定红/绿/灰）。 */
    enum class DeltaTone { UP, DOWN, FLAT }

    /** 差值方向：正=UP（课时变多，红）、负=DOWN（绿）、0=FLAT（灰）。 */
    fun deltaTone(delta: Int): DeltaTone = when {
        delta > 0 -> DeltaTone.UP
        delta < 0 -> DeltaTone.DOWN
        else -> DeltaTone.FLAT
    }
}
