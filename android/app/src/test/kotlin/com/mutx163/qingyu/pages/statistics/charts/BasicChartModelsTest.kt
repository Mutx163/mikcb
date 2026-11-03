package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.DailyAverageStats
import com.mutx163.qingyu.statistics.DailyStats
import com.mutx163.qingyu.statistics.SemesterHeatmap
import com.mutx163.qingyu.statistics.WeeklyTrendPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** 造一个趋势点；只有周次与课时参与绘图，其余字段按"有课"填。 */
private fun trendPoint(week: Int, sections: Int) = WeeklyTrendPoint(
    weekNumber = week,
    sections = sections,
    courseCount = if (sections > 0) 1 else 0,
    requiredSections = sections,
    electiveSections = 0,
    activeDayCount = if (sections > 0) 1 else 0,
)

/** 学期口径的每日平均课时。 */
private fun dailyAverage(day: Int, average: Double) = DailyAverageStats(
    dayOfWeek = day,
    averageSections = average,
    totalSections = (average * 16).toInt(),
    courseCount = if (average > 0) 1 else 0,
)

/** 周口径的每日节数。 */
private fun dailySection(day: Int, sections: Int) = DailyStats(
    dayOfWeek = day,
    sectionCount = sections,
    courseCount = if (sections > 0) 1 else 0,
)

class TrendChartModelTest {

    @Test
    fun `空趋势返回 null 交给调用方不画`() {
        // Dart `if (trend.isEmpty) return const SizedBox.shrink()`
        assertNull(TrendChartModel.build(emptyList(), currentWeek = 5))
    }

    @Test
    fun `按当前周切开实线与未来线`() {
        // 20 周，课时 = 周次 × 2（2,4,…,40）；当前第 8 周
        val trend = (1..20).map { trendPoint(it, it * 2) }
        val spec = TrendChartModel.build(trend, currentWeek = 8)!!
        // 1..8 是已过（8 个点），9..20 是未来（12 个点）
        assertEquals(8, spec.elapsed.size)
        assertEquals(12, spec.future.size)
        assertEquals(1, spec.elapsed.first().week)
        assertEquals(8, spec.elapsed.last().week)
        assertEquals(9, spec.future.first().week)
        assertEquals(20, spec.future.last().week)
    }

    @Test
    fun `坐标轴范围与上限`() {
        val trend = (1..20).map { trendPoint(it, it * 2) }
        val spec = TrendChartModel.build(trend, currentWeek = 8)!!
        assertEquals(1, spec.minWeek)
        assertEquals(20, spec.maxWeek)
        // 最大课时 40 → 上限 41（+1 留白）
        assertEquals(40, spec.maxSections)
        assertEquals(41.0, spec.maxY, 1e-9)
        // 40 > 8 → 纵轴交给自动间隔
        assertNull(spec.leftInterval)
    }

    @Test
    fun `课时不多时纵轴间隔是二`() {
        // 全部 3 节：3 ≤ 8，手动间隔 2；上限 3+1=4
        val spec = TrendChartModel.build((1..10).map { trendPoint(it, 3) }, currentWeek = 10)!!
        assertEquals(4.0, spec.maxY, 1e-9)
        assertEquals(2, spec.leftInterval)
        // 10 周 ≤ 12 → 周刻度间隔 2；末周 10 不是间隔整数倍，Dart 也不标
        assertEquals(listOf(1, null, 3, null, 5, null, 7, null, 9, null), spec.weekLabels)
    }

    @Test
    fun `周标签只在首周与间隔整数倍处出现`() {
        // 20 周 → 间隔 4；fl_chart 从轴最小值起递增：1、5、9、13、17，末周 20 不补标
        val labels = TrendChartModel.weekLabels(1, 20, 4)
        assertEquals(20, labels.size)
        assertEquals(1, labels[0])
        assertNull(labels[1])
        assertNull(labels[2])
        assertNull(labels[3])
        assertEquals(5, labels[4])
        assertEquals(9, labels[8])
        assertEquals(13, labels[12])
        assertEquals(17, labels[16])
        assertNull(labels[19])

        // 末周不是间隔整数倍时同样不标（第 18 周，间隔 4）
        val uneven = TrendChartModel.weekLabels(1, 18, 4)
        assertNull(uneven[17])
        // 首周不是间隔整数倍时仍要标（从第 3 周起，间隔 4 → 3、7、11，末周 14 不标）
        val offset = TrendChartModel.weekLabels(3, 14, 4)
        assertEquals(3, offset[0])
        assertEquals(7, offset[4])
        assertEquals(11, offset[8])
        assertNull(offset[11])
        // 中间那些周不标
        assertNull(offset[1])
        assertNull(offset[10])

        // 非法区间（末 < 首）返回空表，不抛
        assertEquals(0, TrendChartModel.weekLabels(9, 3, 4).size)
    }

    @Test
    fun `点位按 fl_chart 边到边映射 首末周贴边`() {
        // fl_chart `getPixelX`：x = (value - minX) / (maxX - minX) * width，
        // 周次 1..20、宽 400 → 第 1 周在 0、第 20 周在 400（不是槽心 10 / 390）
        assertEquals(0f, TrendChartModel.pointX(1, 1, 20, 400f), 1e-4f)
        assertEquals(400f, TrendChartModel.pointX(20, 1, 20, 400f), 1e-4f)
        // 第 2 周 = 400 × 1/19 ≈ 21.05
        assertEquals(400f / 19f, TrendChartModel.pointX(2, 1, 20, 400f), 1e-4f)
        // 起点不是第 1 周时同样按 minWeek..maxWeek 铺满：周次 3..14，第 7 周 = 400 × 4/11
        assertEquals(400f * 4f / 11f, TrendChartModel.pointX(7, 3, 14, 400f), 1e-4f)
        // 只有一个周次：值域退化（fl_chart 会算 NaN），退到画布正中
        assertEquals(200f, TrendChartModel.pointX(5, 5, 5, 400f), 1e-4f)
        // 纵轴：上限 4、高 160，值 3 → 160 - 3/4*160 = 40
        assertEquals(40f, TrendChartModel.pointY(3, 4.0, 160f), 1e-4f)
        assertEquals(160f, TrendChartModel.pointY(0, 4.0, 160f), 1e-4f)
    }

    @Test
    fun `周标签的落点与折线点位同口径`() {
        // 标签行第 i 个槽位的中心 = width × i/(n-1)；点位应是同一个 x，
        // 否则刻度会与折线错位（这正是上一版槽心映射的问题）。
        val labels = TrendChartModel.weekLabels(1, 20, 4)
        val indexOfWeek5 = labels.indexOf(5)
        assertEquals(4, indexOfWeek5)
        val labelCenter = 400f * indexOfWeek5 / (labels.size - 1)
        assertEquals(labelCenter, TrendChartModel.pointX(5, 1, 20, 400f), 1e-4f)
    }

    @Test
    fun `已过周超过二十个就不画圆点`() {
        // Dart `show: elapsed.length <= 20`
        val twenty = (1..20).map { trendPoint(it, it) }
        assertTrue(TrendChartModel.build(twenty, currentWeek = 20)!!.showDots)
        val twentyOne = (1..21).map { trendPoint(it, it) }
        assertEquals(false, TrendChartModel.build(twentyOne, currentWeek = 21)!!.showDots)
    }

    @Test
    fun `尺寸常量照抄 Dart`() {
        val spec = TrendChartModel.build(listOf(trendPoint(1, 4)), currentWeek = 1)!!
        assertEquals(160f, spec.chartHeightDp, 1e-4f)
        assertEquals(26f, spec.bottomReserveDp, 1e-4f)
        assertEquals(28f, spec.leftReserveDp, 1e-4f)
        // 只有一周且已过：未来线为空，实线一个点
        assertEquals(1, spec.elapsed.size)
        assertEquals(0, spec.future.size)
    }

    @Test
    fun `提示文案与 ARB 逐字一致`() {
        assertEquals("第 5 周 · 12 节", TrendChartModel.tooltip(5, 12))
        assertEquals("第 1 周 · 0 节", TrendChartModel.tooltip(1, 0))
    }
}

class DailyChartModelTest {

    @Test
    fun `空列表返回 null`() {
        assertNull(DailyChartModel.averageSpec(emptyList()))
        assertNull(DailyChartModel.weekSpec(emptyList()))
    }

    @Test
    fun `学期口径的柱高 强调档 与轴上限`() {
        // 周一~周日：2、4、0、3、5、0、1
        val stats = listOf(
            dailyAverage(1, 2.0), dailyAverage(2, 4.0), dailyAverage(3, 0.0),
            dailyAverage(4, 3.0), dailyAverage(5, 5.0), dailyAverage(6, 0.0),
            dailyAverage(7, 1.0),
        )
        val spec = DailyChartModel.averageSpec(stats)!!
        assertEquals(7, spec.bars.size)
        // 最大值 5 → 上限 6
        assertEquals(5.0, spec.maxValue, 1e-9)
        assertEquals(6.0, spec.maxY, 1e-9)
        // 5 > 4 → 自动间隔
        assertNull(spec.leftInterval)
        // 周五最大、周日最小，其余（含没课的两天）都是普通色
        assertEquals(BarEmphasis.MAX, spec.bars[4].emphasis)
        assertEquals(BarEmphasis.MIN, spec.bars[6].emphasis)
        assertEquals(BarEmphasis.NORMAL, spec.bars[0].emphasis)
        assertEquals(BarEmphasis.NORMAL, spec.bars[2].emphasis)
        // 横轴标签是周几短名
        assertEquals("一", spec.bars[0].label)
        assertEquals("日", spec.bars[6].label)
    }

    @Test
    fun `学期口径 最高值小于等于四时纵轴按一节一格`() {
        // 全部 1.0：1 ≤ 4 → 间隔 1；上限 2
        val spec = DailyChartModel.averageSpec((1..7).map { dailyAverage(it, 1.0) })!!
        assertEquals(1, spec.leftInterval)
        assertEquals(2.0, spec.maxY, 1e-9)
        // 全周一样多 → 七天全部命中 MAX（Dart 原行为，不做去重）
        assertEquals(7, spec.bars.count { it.emphasis == BarEmphasis.MAX })
    }

    @Test
    fun `周口径的柱高与强调档`() {
        // 周一到周日：0、2、4、2、6、0、3
        val stats = listOf(
            dailySection(1, 0), dailySection(2, 2), dailySection(3, 4),
            dailySection(4, 2), dailySection(5, 6), dailySection(6, 0),
            dailySection(7, 3),
        )
        val spec = DailyChartModel.weekSpec(stats)!!
        assertEquals(6.0, spec.maxValue, 1e-9)
        assertEquals(7.0, spec.maxY, 1e-9)
        // 6 > 6 不成立 → 手动间隔 1
        assertEquals(1, spec.leftInterval)
        assertEquals(BarEmphasis.MAX, spec.bars[4].emphasis)
        // 最低的活跃日是周二/周四（2 节）
        assertEquals(BarEmphasis.MIN, spec.bars[1].emphasis)
        assertEquals(BarEmphasis.MIN, spec.bars[3].emphasis)
        // 没课的两天不是"最低档"，是普通色
        assertEquals(BarEmphasis.NORMAL, spec.bars[0].emphasis)
        assertEquals(BarEmphasis.NORMAL, spec.bars[5].emphasis)
        assertEquals(BarEmphasis.NORMAL, spec.bars[6].emphasis)
    }

    @Test
    fun `周口径单日有课时不会同时成为最低档`() {
        // 只有周三有 5 节：max == min == 5，但周口径下只能算 MAX
        val stats = (1..7).map { dailySection(it, if (it == 3) 5 else 0) }
        val spec = DailyChartModel.weekSpec(stats)!!
        assertEquals(BarEmphasis.MAX, spec.bars[2].emphasis)
        assertEquals(0, spec.bars.count { it.emphasis == BarEmphasis.MIN })
    }

    @Test
    fun `周口径超过六节才交给自动间隔`() {
        val stats = (1..7).map { dailySection(it, if (it == 1) 7 else 0) }
        val spec = DailyChartModel.weekSpec(stats)!!
        // 7 > 6 → 自动；上限 8
        assertNull(spec.leftInterval)
        assertEquals(8.0, spec.maxY, 1e-9)
    }

    @Test
    fun `提示文案 学期保留一位小数 周取整`() {
        assertEquals("5.0 节", DailyChartModel.averageTooltip(5.0))
        assertEquals("2.5 节", DailyChartModel.averageTooltip(2.5))
        assertEquals("6 节", DailyChartModel.weekTooltip(6))
        assertEquals("0 节", DailyChartModel.weekTooltip(0))
    }

    @Test
    fun `尺寸常量照抄 Dart`() {
        assertEquals(20f, DailyChartModel.BAR_WIDTH_DP, 1e-4f)
        assertEquals(6f, DailyChartModel.BAR_CORNER_DP, 1e-4f)
        assertEquals(168f, DailyChartModel.AVERAGE_CHART_HEIGHT_DP, 1e-4f)
        assertEquals(150f, DailyChartModel.WEEK_CHART_HEIGHT_DP, 1e-4f)
        assertEquals(28f, DailyChartModel.AVERAGE_BOTTOM_RESERVE_DP, 1e-4f)
        assertEquals(26f, DailyChartModel.WEEK_BOTTOM_RESERVE_DP, 1e-4f)
        assertEquals(0.35f, DailyChartModel.NORMAL_BAR_ALPHA, 1e-4f)
    }
}

class HeatmapModelTest {

    /** 6 周的热力图：周一那行是 1..6，其余全 0。 */
    private fun sampleHeatmap(): SemesterHeatmap {
        val monday = listOf(1, 2, 3, 4, 5, 6)
        val rows = List(7) { day -> if (day == 0) monday else List(6) { 0 } }
        return SemesterHeatmap(weekCount = 6, maxSections = 6, rows = rows)
    }

    @Test
    fun `周数小于一返回 null`() {
        assertNull(HeatmapModel.build(SemesterHeatmap(0, 0, emptyList()), currentWeek = 1))
    }

    @Test
    fun `未来周先置零再算配色标度`() {
        // 第 4 周视角：第 5、6 周被抹平，剩下的最大值是 4（不是 6）
        val spec = HeatmapModel.build(sampleHeatmap(), currentWeek = 4)!!
        assertEquals(6, spec.weekCount)
        assertEquals(4, spec.maxSections)
        // 周一：1/4=0.25 档2，2/4=0.5 档3，3/4=0.75 档4，4/4=1.0 档4，未来两格空
        assertEquals(listOf(2, 3, 4, 4, 0, 0), spec.levels[0])
        assertEquals(listOf(0.45f, 0.68f, 1.0f, 1.0f, 0.0f, 0.0f), spec.alphas[0])
        // 其余六天全空
        for (day in 1..6) {
            assertEquals(List(6) { 0 }, spec.levels[day])
        }
    }

    @Test
    fun `看完整学期时用学期最大值`() {
        val spec = HeatmapModel.build(sampleHeatmap(), currentWeek = 6)!!
        assertEquals(6, spec.maxSections)
        // 1/6≈0.167 档1，2/6≈0.333 档2，3/6=0.5 档3，4/6≈0.667 档3，5/6≈0.833 档4，6/6 档4
        assertEquals(listOf(1, 2, 3, 3, 4, 4), spec.levels[0])
        assertEquals(listOf(0.22f, 0.45f, 0.68f, 0.68f, 1.0f, 1.0f), spec.alphas[0])
    }

    @Test
    fun `周次标签每四周一个且末列必标`() {
        // 6 周：第 1 周（1%4==1）、第 5 周（5%4==1）、第 6 周（末列）
        assertEquals(listOf(1, null, null, null, 5, 6), HeatmapModel.weekLabels(6))
        // 10 周：1、5、9、10
        assertEquals(
            listOf(1, null, null, null, 5, null, null, null, 9, 10),
            HeatmapModel.weekLabels(10),
        )
    }

    @Test
    fun `格子几何 尺寸间距与圆角照抄 Dart`() {
        // 边长 13、间距 3
        assertEquals(13f, HeatmapSpec.CELL_SIZE_DP, 1e-4f)
        assertEquals(3f, HeatmapSpec.CELL_GAP_DP, 1e-4f)
        assertEquals(22f, HeatmapSpec.LABEL_WIDTH_DP, 1e-4f)
        assertEquals(6f, HeatmapSpec.LABEL_TO_GRID_GAP_DP, 1e-4f)
        assertEquals(3.5f, HeatmapSpec.CELL_CORNER_DP, 1e-4f)
        // 一行（含行缝）16
        assertEquals(16f, HeatmapSpec.ROW_PITCH_DP, 1e-4f)

        // 第 3 列左边缘 = 2 × (13+3) = 32；第 4 行顶部 = 3 × 16 = 48
        assertEquals(32f, HeatmapModel.cellLeft(2, 13f, 3f), 1e-4f)
        assertEquals(48f, HeatmapModel.cellTop(3, 13f, 3f), 1e-4f)
        // 6 列总宽 = 6*13 + 5*3 = 93
        assertEquals(93f, HeatmapModel.gridWidth(6, 13f, 3f), 1e-4f)
        // 7 行总高 = 7*13 + 6*3 = 109
        assertEquals(109f, HeatmapModel.gridHeight(13f, 3f), 1e-4f)
        // 0 列宽 0，不出现负宽
        assertEquals(0f, HeatmapModel.gridWidth(0, 13f, 3f), 1e-4f)
    }

    @Test
    fun `星期标签对应周一到周日`() {
        assertEquals("一", HeatmapModel.weekdayLabel(0))
        assertEquals("三", HeatmapModel.weekdayLabel(2))
        assertEquals("日", HeatmapModel.weekdayLabel(6))
    }

    @Test
    fun `全部无课时不出深色格`() {
        // 7×3 全零：分级全 0，透明度全 0（渲染层改用行高亮底色）
        val empty = SemesterHeatmap(3, 0, List(7) { List(3) { 0 } })
        val spec = HeatmapModel.build(empty, currentWeek = 3)!!
        assertNotNull(spec)
        for (row in spec.levels) assertEquals(List(3) { 0 }, row)
        for (row in spec.alphas) assertEquals(List(3) { 0f }, row)
        assertEquals(0, spec.maxSections)
    }
}
