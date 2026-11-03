package com.mutx163.qingyu.pages.statistics.charts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 图表几何内核 [ChartMath] 的单测。
 *
 * **期望值全部是人推的**（拿笔算，不从实现里抄）。每条用例的"为什么是这个数"
 * 写在断言上方的注释里；改坏实现就红，改坏期望值也要能看出跟哪条 Dart 出处不符。
 */
class ChartMathTest {

    // ────────────── 刻度上限 ──────────────

    @Test
    fun `纵轴上限是数据最大值加一`() {
        // Dart `maxY: (maxY + 1).toDouble()`：7 节 → 上限 8
        assertEquals(8.0, ChartMath.axisMax(7), 1e-9)
        // 全零：0 + 1 = 1（不是 0，否则归一化除零）
        assertEquals(1.0, ChartMath.axisMax(0), 1e-9)
        // 小数值同样加一：12.5 → 13.5
        assertEquals(13.5, ChartMath.axisMax(12.5), 1e-9)
        // 负数被钳到 1（钳制是迁移时补的，Dart 不会出现负课时）
        assertEquals(1.0, ChartMath.axisMax(-3), 1e-9)
    }

    // ────────────── 横轴 / 纵轴刻度间隔 ──────────────

    @Test
    fun `折线图周刻度间隔按最后一周分四档`() {
        // 出处 trend_chart.dart:176-183：≤6→1，≤12→2，≤24→4，其它→8
        assertEquals(1, ChartMath.trendLabelInterval(1))
        assertEquals(1, ChartMath.trendLabelInterval(6))
        assertEquals(2, ChartMath.trendLabelInterval(7))
        assertEquals(2, ChartMath.trendLabelInterval(12))
        assertEquals(4, ChartMath.trendLabelInterval(13))
        assertEquals(4, ChartMath.trendLabelInterval(24))
        assertEquals(8, ChartMath.trendLabelInterval(25))
        assertEquals(8, ChartMath.trendLabelInterval(100))
    }

    @Test
    fun `纵轴刻度间隔在门槛之内手动 超出则交给自动`() {
        // 折线图：maxY > 8 ? null : 2 —— 8 不触发，9 触发
        assertEquals(2, ChartMath.axisTitleInterval(8.0, 8.0, 2))
        assertNull(ChartMath.axisTitleInterval(9.0, 8.0, 2))
        // 学期平均课时图：maxAverage > 4 ? null : 1 —— 4 不触发，4.5 触发
        assertEquals(1, ChartMath.axisTitleInterval(4.0, 4.0, 1))
        assertNull(ChartMath.axisTitleInterval(4.5, 4.0, 1))
        // 周视图：maxSections > 6 ? null : 1
        assertEquals(1, ChartMath.axisTitleInterval(6.0, 6.0, 1))
        assertNull(ChartMath.axisTitleInterval(7.0, 6.0, 1))
    }

    @Test
    fun `三张图都不画竖向网格线`() {
        // Dart 三处都是 drawVerticalLine: false
        assertEquals(false, ChartMath.drawVerticalGridLine())
    }

    // ────────────── 比例 / 百分比 ──────────────

    @Test
    fun `占比在分母为零时是零而不是崩溃`() {
        assertEquals(0.0, ChartMath.ratio(3, 0), 1e-9)
        assertEquals(0.0, ChartMath.ratio(0, 0), 1e-9)
        assertEquals(0.25, ChartMath.ratio(3, 12), 1e-9)
    }

    @Test
    fun `百分比归一四舍五入`() {
        // 3/12 = 25%
        assertEquals(25, ChartMath.percentRounded(3, 12))
        // 1/3 = 33.33 → 33
        assertEquals(33, ChartMath.percentRounded(1, 3))
        // 2/3 = 66.67 → 67
        assertEquals(67, ChartMath.percentRounded(2, 3))
        assertEquals(0, ChartMath.percentRounded(0, 5))
        assertEquals(100, ChartMath.percentRounded(5, 5))
        // 分母 0 不抛：返回 0
        assertEquals(0, ChartMath.percentRounded(2, 0))
    }

    @Test
    fun `归一化钳在零到一之间`() {
        assertEquals(0.5, ChartMath.normalize(5.0, 10.0), 1e-9)
        assertEquals(1.0, ChartMath.normalize(15.0, 10.0), 1e-9)
        assertEquals(0.0, ChartMath.normalize(-1.0, 10.0), 1e-9)
        assertEquals(0.0, ChartMath.normalize(5.0, 0.0), 1e-9)
    }

    // ────────────── 热力分级 ──────────────

    @Test
    fun `热力分级把零与负数当空格`() {
        assertEquals(ChartMath.HEAT_LEVEL_EMPTY, ChartMath.heatLevel(0, 5))
        assertEquals(ChartMath.HEAT_LEVEL_EMPTY, ChartMath.heatLevel(-2, 5))
    }

    @Test
    fun `热力四级按四分之一分段 边界左闭右开`() {
        // max=5：1→0.20 档1；2→0.40 档2；3→0.60 档3；4→0.80 档4；5→1.00 档4
        assertEquals(1, ChartMath.heatLevel(1, 5))
        assertEquals(2, ChartMath.heatLevel(2, 5))
        assertEquals(3, ChartMath.heatLevel(3, 5))
        assertEquals(4, ChartMath.heatLevel(4, 5))
        assertEquals(4, ChartMath.heatLevel(5, 5))

        // max=4 时边界正好落在刻度上：1→0.25 落档 2（不是档 1）
        assertEquals(2, ChartMath.heatLevel(1, 4))
        assertEquals(3, ChartMath.heatLevel(2, 4))
        // max=8 时 6→0.75 落档 4（不是档 3）
        assertEquals(3, ChartMath.heatLevel(5, 8))
        assertEquals(4, ChartMath.heatLevel(6, 8))
    }

    @Test
    fun `热力分母为零时按一算`() {
        // maxSections < 1 → 用 1：任何非零值都拉满到档 4
        assertEquals(4, ChartMath.heatLevel(1, 0))
        assertEquals(4, ChartMath.heatLevel(3, -5))
    }

    @Test
    fun `热力档位对应的透明度`() {
        assertEquals(0f, ChartMath.heatAlpha(0), 1e-6f)
        assertEquals(0.22f, ChartMath.heatAlpha(1), 1e-6f)
        assertEquals(0.45f, ChartMath.heatAlpha(2), 1e-6f)
        assertEquals(0.68f, ChartMath.heatAlpha(3), 1e-6f)
        assertEquals(1.0f, ChartMath.heatAlpha(4), 1e-6f)
        // 越界档位钳到最浓一档，不数组越界
        assertEquals(1.0f, ChartMath.heatAlpha(9), 1e-6f)
    }

    @Test
    fun `周次标签每四周标一个且最后一周必标`() {
        // week % 4 == 1 → 第 1、5、9… 周
        assertEquals(true, ChartMath.heatmapShowWeekLabel(1, 10))
        assertEquals(false, ChartMath.heatmapShowWeekLabel(2, 10))
        assertEquals(true, ChartMath.heatmapShowWeekLabel(5, 10))
        // 最后一周即便不是 4n+1 也要标（第 10 周 → 10 % 4 = 2）
        assertEquals(true, ChartMath.heatmapShowWeekLabel(10, 10))
        // 第 9 周不是最后一周、但满足 4n+1
        assertEquals(true, ChartMath.heatmapShowWeekLabel(9, 10))
        assertEquals(false, ChartMath.heatmapShowWeekLabel(8, 10))
    }

    // ────────────── 柱状图几何 ──────────────

    @Test
    fun `七根柱子均分画布 每根居中`() {
        // 宽 350 分 7 槽 → 每槽 50；第 0 根中心 25，第 6 根中心 325
        assertEquals(50f, ChartMath.barSlotWidth(350f, 7), 1e-4f)
        assertEquals(25f, ChartMath.barCenterX(0, 7, 350f), 1e-4f)
        assertEquals(75f, ChartMath.barCenterX(1, 7, 350f), 1e-4f)
        assertEquals(325f, ChartMath.barCenterX(6, 7, 350f), 1e-4f)
        // 槽数为 0 不除零
        assertEquals(0f, ChartMath.barCenterX(3, 0, 350f), 1e-4f)
    }

    @Test
    fun `柱宽不超过槽宽一半`() {
        // 槽宽 50、标准宽 20 → 20 < 25，用 20（与 Dart 的 width:20 一致）
        assertEquals(20f, ChartMath.barWidthPx(50f, 20f), 1e-4f)
        // 槽宽 20（窄屏）→ 一半是 10，钳到 10，避免相邻柱粘连
        assertEquals(10f, ChartMath.barWidthPx(20f, 20f), 1e-4f)
    }

    @Test
    fun `柱顶坐标自底向上`() {
        // 高 100，上限 10：值 5 → 顶在 50；0 → 100；10 → 0
        assertEquals(50f, ChartMath.barTopY(5.0, 10.0, 100f), 1e-4f)
        assertEquals(100f, ChartMath.barTopY(0.0, 10.0, 100f), 1e-4f)
        assertEquals(0f, ChartMath.barTopY(10.0, 10.0, 100f), 1e-4f)
        // 超上限钳在顶端
        assertEquals(0f, ChartMath.barTopY(20.0, 10.0, 100f), 1e-4f)
        // 上限为 0（理论上不会发生）退化成贴底
        assertEquals(100f, ChartMath.barTopY(5.0, 0.0, 100f), 1e-4f)
    }

    @Test
    fun `学期口径的柱强调档`() {
        // 无活跃日（整周没课）：谁都不强调
        assertEquals(BarEmphasis.NORMAL, ChartMath.dailyBarEmphasis(0.0, 0.0, 0.0, 0))
        // 常规：最大值 MAX、最小值 MIN、中间 NORMAL（max=5, min=1, 5 个活跃日）
        assertEquals(BarEmphasis.MAX, ChartMath.dailyBarEmphasis(5.0, 5.0, 1.0, 5))
        assertEquals(BarEmphasis.MIN, ChartMath.dailyBarEmphasis(1.0, 5.0, 1.0, 5))
        assertEquals(BarEmphasis.NORMAL, ChartMath.dailyBarEmphasis(3.0, 5.0, 1.0, 5))
        // 全周课时相同：全部命中 MAX（Dart 就是这行为，不额外去重）
        assertEquals(BarEmphasis.MAX, ChartMath.dailyBarEmphasis(2.0, 2.0, 2.0, 7))
    }

    @Test
    fun `周口径的柱强调档要求大于零且最低档排除最高档`() {
        // 0 节不强调（哪怕全周都是 0）
        assertEquals(BarEmphasis.NORMAL, ChartMath.weekBarEmphasis(0, 0, 0))
        // 常规（max=6, min=2）
        assertEquals(BarEmphasis.MAX, ChartMath.weekBarEmphasis(6, 6, 2))
        assertEquals(BarEmphasis.MIN, ChartMath.weekBarEmphasis(2, 6, 2))
        assertEquals(BarEmphasis.NORMAL, ChartMath.weekBarEmphasis(4, 6, 2))
        // 全周只有一天有课：max == min == 5 → 只能是 MAX，不能同时是 MIN
        assertEquals(BarEmphasis.MAX, ChartMath.weekBarEmphasis(5, 5, 5))
    }

    // ────────────── 点位映射 ──────────────

    @Test
    fun `点位映射把值域铺满画布并对超界钳制`() {
        // x：1..9 映射到 0..800，中点 5 → 400
        assertEquals(0f, ChartMath.mapX(1.0, 1.0, 9.0, 800f), 1e-4f)
        assertEquals(400f, ChartMath.mapX(5.0, 1.0, 9.0, 800f), 1e-4f)
        assertEquals(800f, ChartMath.mapX(9.0, 1.0, 9.0, 800f), 1e-4f)
        // 值域退化（只有一周）退到画布正中，不出 NaN
        assertEquals(400f, ChartMath.mapX(3.0, 3.0, 3.0, 800f), 1e-4f)
        // 超界钳制
        assertEquals(800f, ChartMath.mapX(20.0, 1.0, 9.0, 800f), 1e-4f)

        // y：0 在底、10 在上（画布高 100）
        assertEquals(100f, ChartMath.mapY(0.0, 10.0, 100f), 1e-4f)
        assertEquals(50f, ChartMath.mapY(5.0, 10.0, 100f), 1e-4f)
        assertEquals(0f, ChartMath.mapY(10.0, 10.0, 100f), 1e-4f)
        assertEquals(0f, ChartMath.mapY(20.0, 10.0, 100f), 1e-4f)
        assertEquals(100f, ChartMath.mapY(5.0, 0.0, 100f), 1e-4f)
    }

    // ────────────── 平滑曲线 ──────────────

    @Test
    fun `线性数据的控制点必须仍落在同一条直线上`() {
        // 四个等距点在 y=0 的水平线上：控制点的 y 必须还是 0
        val flat = ChartMath.cubicControls(0f, 0f, 10f, 0f, 20f, 0f, 30f, 0f)
        assertEquals(0f, flat.c1y, 1e-4f)
        assertEquals(0f, flat.c2y, 1e-4f)
        // k = smoothness/2 = 0.125：c1x = 10 + (20-0)*0.125 = 12.5
        //                          c2x = 20 - (30-10)*0.125 = 17.5
        assertEquals(12.5f, flat.c1x, 1e-4f)
        assertEquals(17.5f, flat.c2x, 1e-4f)

        // 对角线上的点：控制点也在 y = x 上
        val diag = ChartMath.cubicControls(0f, 0f, 10f, 10f, 20f, 20f, 30f, 30f)
        assertEquals(diag.c1x, diag.c1y, 1e-4f)
        assertEquals(diag.c2x, diag.c2y, 1e-4f)
    }

    @Test
    fun `平滑度为零时控制点退化成端点本身`() {
        // k = 0/2 = 0 → c1 = p1、c2 = p2，曲线变成直线
        val straight = ChartMath.cubicControls(0f, 0f, 10f, 5f, 20f, 1f, 30f, 9f, smoothness = 0f)
        assertEquals(10f, straight.c1x, 1e-4f)
        assertEquals(5f, straight.c1y, 1e-4f)
        assertEquals(20f, straight.c2x, 1e-4f)
        assertEquals(1f, straight.c2y, 1e-4f)
    }

    // ────────────── 虚线切段 ──────────────

    @Test
    fun `二十像素直线按六实四空切成两段`() {
        // 沿 x 轴 0→20，周期 10：实线 [0,6] 与 [10,16]，尾部 [20,20] 长度为零不画
        val segments = ChartMath.dashPolyline(
            listOf(ChartPoint(0f, 0f), ChartPoint(20f, 0f)),
            dash = 6f,
            gap = 4f,
        )
        assertEquals(2, segments.size)
        assertEquals(0f, segments[0].first().x, 1e-4f)
        assertEquals(6f, segments[0].last().x, 1e-4f)
        assertEquals(10f, segments[1].first().x, 1e-4f)
        assertEquals(16f, segments[1].last().x, 1e-4f)
    }

    @Test
    fun `虚线跨拐点时续接 且点数不足时返回空`() {
        // 单点或空折线不产生任何实线段
        assertEquals(0, ChartMath.dashPolyline(emptyList()).size)
        assertEquals(0, ChartMath.dashPolyline(listOf(ChartPoint(1f, 1f))).size)

        // 7px 的正交折线（0,0）→（7,0）：实线 [0,6] 一段，剩下的 1px 停在空档开头
        val bent = ChartMath.dashPolyline(
            listOf(ChartPoint(0f, 0f), ChartPoint(7f, 0f)),
            dash = 6f,
            gap = 4f,
        )
        assertEquals(1, bent.size)
        assertEquals(6f, bent[0].last().x, 1e-4f)
    }

    // ────────────── 环形图 ──────────────

    @Test
    fun `环形图正常态用二十与二十八 缺一侧时收细加大孔`() {
        // 两侧都有课：ring 20 / 孔 28（20+28=48 → 直径 96，塞进 100 的盒子不裁边）
        val normal = ChartMath.donutGeometry(3, 4)
        assertEquals(20f, normal.radius, 1e-4f)
        assertEquals(28f, normal.centerRadius, 1e-4f)
        assertNull(normal.missingLabel)
        assertEquals(true, normal.hasData)

        // 必修为 0：ring 18 / 孔 32，中心报"暂无必修"
        val noRequired = ChartMath.donutGeometry(0, 4)
        assertEquals(18f, noRequired.radius, 1e-4f)
        assertEquals(32f, noRequired.centerRadius, 1e-4f)
        assertEquals("暂无必修", noRequired.missingLabel)

        // 选修为 0：同样收细加大，中心报"暂无选修"
        val noElective = ChartMath.donutGeometry(3, 0)
        assertEquals(18f, noElective.radius, 1e-4f)
        assertEquals(32f, noElective.centerRadius, 1e-4f)
        assertEquals("暂无选修", noElective.missingLabel)

        // 两边都为 0：没数据，不报"暂无必修"（否则像已经算过一遍）
        val none = ChartMath.donutGeometry(0, 0)
        assertEquals(false, none.hasData)
        assertNull(none.missingLabel)
        assertEquals(20f, none.radius, 1e-4f)
    }

    @Test
    fun `环形图段列表按必修 选修 补位段排序`() {
        // 两侧都有：只有两段
        val both = ChartMath.donutSlices(3, 4)
        assertEquals(2, both.size)
        assertEquals(3.0, both[0].value, 1e-9)
        assertEquals(DonutSlice.NatureKind.REQUIRED, both[0].nature)
        assertEquals(4.0, both[1].value, 1e-9)
        assertEquals(DonutSlice.NatureKind.ELECTIVE, both[1].nature)
        assertEquals(false, both[0].placeholder)

        // 必修为 0：第三段是必修补位段（value 1），否则"纯色圆"会被读成 100% 必修
        val noRequired = ChartMath.donutSlices(0, 4)
        assertEquals(3, noRequired.size)
        assertEquals(0.0, noRequired[0].value, 1e-9)
        assertEquals(1.0, noRequired[2].value, 1e-9)
        assertEquals(DonutSlice.NatureKind.REQUIRED, noRequired[2].nature)
        assertEquals(true, noRequired[2].placeholder)

        // 选修为 0：第三段是选修补位段
        val noElective = ChartMath.donutSlices(3, 0)
        assertEquals(3, noElective.size)
        assertEquals(DonutSlice.NatureKind.ELECTIVE, noElective[2].nature)
        assertEquals(true, noElective[2].placeholder)
    }

    @Test
    fun `环形图弧角按占比切分并各让出半缝隙`() {
        // 3 : 4 = 154.2857° : 205.7143°，总 360
        val arcs = ChartMath.donutArcs(listOf(3.0, 4.0))
        assertEquals(2, arcs.size)
        // 起始 -90°（12 点），先让出半缝隙 1°
        assertEquals(-89f, arcs[0].startDegrees, 1e-4f)
        // 扫角 = 154.2857 - 2 = 152.2857
        assertEquals(152.2857f, arcs[0].sweepDegrees, 1e-3f)
        // 第二段起点 = -90 + 154.2857 + 1 = 65.2857
        assertEquals(65.2857f, arcs[1].startDegrees, 1e-3f)
        assertEquals(203.7143f, arcs[1].sweepDegrees, 1e-3f)
        // 两段扫角 + 两道缝隙 = 360
        assertEquals(360f, arcs[0].sweepDegrees + arcs[1].sweepDegrees + 4f, 1e-3f)
    }

    @Test
    fun `环形图三等分时每段让出缝隙后仍对称`() {
        // 1:2 占比 → 120° 与 240°
        val arcs = ChartMath.donutArcs(listOf(1.0, 2.0))
        assertEquals(-89f, arcs[0].startDegrees, 1e-4f)
        assertEquals(118f, arcs[0].sweepDegrees, 1e-4f)
        // 第二段起点 = -90 + 120 + 1 = 31
        assertEquals(31f, arcs[1].startDegrees, 1e-4f)
        assertEquals(238f, arcs[1].sweepDegrees, 1e-4f)
    }

    // ────────────── 名次（1:1 对齐 Dart，并列不特殊处理） ──────────────

    @Test
    fun `名次就是序号加一 并列课程不特殊处理`() {
        // 首页 course_ranking.dart:52 是 `rank: index + 1`：
        // 四门课（40/36/36/20）排出来是 1、2、3、4——并列的两门拿不到同一个名次。
        // 这是原实现的已知缺陷，本批**有意保持 1:1** 以保住逐页对照基线。
        assertEquals(listOf(1, 2, 3, 4), ChartMath.sequentialRanks(4))
        // 名次与分数无关，只看位置：分数重复也照编号
        assertEquals(2, ChartMath.rankOf(1))
        assertEquals(3, ChartMath.rankOf(2))
        assertEquals(1, ChartMath.rankOf(0))
        // 边界
        assertEquals(emptyList<Int>(), ChartMath.sequentialRanks(0))
        assertEquals(emptyList<Int>(), ChartMath.sequentialRanks(-1))
        assertEquals(listOf(1), ChartMath.sequentialRanks(1))
    }

    // ────────────── 纵轴刻度与曲线采样（渲染层依赖的两条） ──────────────

    @Test
    fun `纵轴刻度从零起步按步长递增且不越过上限`() {
        // 上限 4、步长 2 → 0、2、4
        assertEquals(listOf(0, 2, 4), ChartMath.leftAxisTicks(4.0, 2))
        // 上限 6、步长 1 → 0..6 共 7 条
        assertEquals(listOf(0, 1, 2, 3, 4, 5, 6), ChartMath.leftAxisTicks(6.0, 1))
        // 上限 8、步长 2 → 0、2、4、6、8
        assertEquals(listOf(0, 2, 4, 6, 8), ChartMath.leftAxisTicks(8.0, 2))
        // 上限 5、步长 2 → 最后一条 4（不越界画 6）
        assertEquals(listOf(0, 2, 4), ChartMath.leftAxisTicks(5.0, 2))
    }

    @Test
    fun `自动步长最多四格`() {
        // 41 / 4 = 10.25 → 进位 11 → 0、11、22、33
        assertEquals(listOf(0, 11, 22, 33), ChartMath.leftAxisTicks(41.0, null))
        // 6 / 4 = 1.5 → 进位 2 → 0、2、4、6
        assertEquals(listOf(0, 2, 4, 6), ChartMath.leftAxisTicks(6.0, null))
        // 刚好整除：9 / 4 = 2.25 → 3
        assertEquals(listOf(0, 3, 6, 9), ChartMath.leftAxisTicks(9.0, null))
        // 上限不足 1 只留 0（不画密度线）
        assertEquals(listOf(0), ChartMath.leftAxisTicks(0.5, null))
        assertEquals(listOf(0), ChartMath.leftAxisTicks(0.0, 2))
    }

    @Test
    fun `曲线采样保持端点在线上且点数可预测`() {
        // 三个共线水平点，每段采 4 个点 → (3-1)*4+1 = 9 个
        val straight = listOf(ChartPoint(0f, 0f), ChartPoint(10f, 0f), ChartPoint(20f, 0f))
        val samples = ChartMath.sampleCurve(straight, samplesPerSegment = 4)
        assertEquals(9, samples.size)
        // 线性数据的曲线仍是直线：所有采样点 y 都是 0
        for (p in samples) assertEquals(0f, p.y, 1e-4f)
        // 端点原样保留
        assertEquals(0f, samples.first().x, 1e-4f)
        assertEquals(20f, samples.last().x, 1e-4f)
        // x 单调递增（没有回折）
        for (i in 1 until samples.size) {
            assertTrue("采样点 x 在 ${i} 处回折了", samples[i].x > samples[i - 1].x - 1e-4f)
        }
        // 点数不足时原样返回
        assertEquals(straight, ChartMath.sampleCurve(straight + emptyList(), samplesPerSegment = 1))
        assertEquals(2, ChartMath.sampleCurve(listOf(ChartPoint(0f, 0f), ChartPoint(1f, 1f)), samplesPerSegment = 1).size)
        assertEquals(1, ChartMath.sampleCurve(listOf(ChartPoint(3f, 3f)), samplesPerSegment = 4).size)
    }

    @Test
    fun `控制点数量是段数 首尾段用端点兜底`() {
        val points = listOf(
            ChartPoint(0f, 0f), ChartPoint(10f, 10f), ChartPoint(20f, 4f), ChartPoint(30f, 8f),
        )
        // 4 个点 → 3 段 → 3 组控制点
        assertEquals(3, ChartMath.curveControlPoints(points).size)
        // 单点 / 空表没有段
        assertEquals(0, ChartMath.curveControlPoints(listOf(ChartPoint(1f, 1f))).size)
        assertEquals(0, ChartMath.curveControlPoints(emptyList()).size)

        // 首段从点 0(0,0) 到点 1(10,10)，p0 用点 0 自身兜底：
        // c1x = x1 + (x2 - x0) * 0.125 = 0 + (10 - 0) * 0.125 = 1.25
        val first = ChartMath.curveControlPoints(points)[0]
        assertEquals(1.25f, first.c1x, 1e-4f)
        assertEquals(1.25f, first.c1y, 1e-4f)
        // c2x = x2 - (x3 - x1) * 0.125 = 10 - (20 - 0) * 0.125 = 7.5
        assertEquals(7.5f, first.c2x, 1e-4f)
    }

    // ────────────── 文案数字 ──────────────

    @Test
    fun `一位小数按四舍五入`() {
        assertEquals("5.0", ChartMath.oneDecimal(5.0))
        // 3.25 → 32.5 → 进位到 33 → "3.3"
        assertEquals("3.3", ChartMath.oneDecimal(3.25))
        // 2.04 → 20.4 → 20 → "2.0"
        assertEquals("2.0", ChartMath.oneDecimal(2.04))
        // 4.96 → 49.6 → 50 → "5.0"（不是 "4.10"）
        assertEquals("5.0", ChartMath.oneDecimal(4.96))
        // Dart `toStringAsFixed(1)` 保留负号；整数除法曾让 -0.3 显示成 "0.3"
        assertEquals("-0.3", ChartMath.oneDecimal(-0.3))
        assertEquals("-2.5", ChartMath.oneDecimal(-2.54))
        assertEquals("-0.0", ChartMath.oneDecimal(-0.04))
        // Dart `toStringAsFixed(1)` 的 .5 是「远离零」：-2.25 → "-2.3"。
        // 旧实现 `(value * 10).roundToInt()` 是「朝正无穷」，会得到 "-2.2"（真实差异，已修）。
        assertEquals("-2.3", ChartMath.oneDecimal(-2.25))
        assertEquals("-1.3", ChartMath.oneDecimal(-1.25))
    }

    @Test
    fun `差值文案正数带加号 零是零`() {
        assertEquals("+3", ChartMath.deltaText(3))
        assertEquals("-2", ChartMath.deltaText(-2))
        assertEquals("0", ChartMath.deltaText(0))
        assertEquals(ChartMath.DeltaTone.UP, ChartMath.deltaTone(3))
        assertEquals(ChartMath.DeltaTone.DOWN, ChartMath.deltaTone(-2))
        assertEquals(ChartMath.DeltaTone.FLAT, ChartMath.deltaTone(0))
    }
}
