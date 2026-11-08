package com.mutx163.qingyu.pages.timetable.month

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 面板半的折叠状态机、版面账、概览统计与「还有 N 天」行数分配。
 *
 * ## 期望值从哪来
 *
 * 全部**人推**，不是从实现里抄的：
 * * 折叠判据（0.35 行程 / 180dp·s⁻¹ 甩速 / 1 行保留）来自
 *   `lib/domain/month_grid_collapse.dart` 的注释与常量；
 * * 「收起时格子不能变高」「面板不许被挤没」这两条是不变量，写成人能一句话
 *   说清的关系式（网格高 + 面板高 + 卡内开销 = 可用高）；
 * * 概览与「还有 N 天」的数字用手算的月历样例（2026 年 10 月，
 *   1 号是周四 → 42 格从 9/28 周一起算）。
 */
class MonthPanelModelTest {

    // ------------------------------------------------------------------
    // 一、折叠状态机
    // ------------------------------------------------------------------

    @Test
    fun `窗口行数在收起与展开之间线性插值`() {
        // 6 行月：收起 1 行、展开 6 行、半程 3.5 行。
        assertEquals(1.0, MonthPanelModel.visibleRows(0.0), 1e-9)
        assertEquals(6.0, MonthPanelModel.visibleRows(1.0), 1e-9)
        assertEquals(3.5, MonthPanelModel.visibleRows(0.5), 1e-9)

        // 5 行月（2026 年 10 月就是 5 行）：展开只露 5 行，不是 6 —— 固定 6 行
        // 会在尾部多出一整行纯邻月灰号（Dart 侧 2026-10-25 的改动理由）。
        assertEquals(5.0, MonthPanelModel.visibleRows(1.0, rowCount = 5), 1e-9)
        assertEquals(3.0, MonthPanelModel.visibleRows(0.5, rowCount = 5), 1e-9)

        // 越界输入：进度钳回 0..1，行数钳回 1..6（渲染路径不许抛）。
        assertEquals(1.0, MonthPanelModel.visibleRows(-3.0), 1e-9)
        assertEquals(6.0, MonthPanelModel.visibleRows(9.0), 1e-9)
        assertEquals(6.0, MonthPanelModel.visibleRows(1.0, rowCount = 99), 1e-9)
        assertEquals(1.0, MonthPanelModel.visibleRows(1.0, rowCount = 0), 1e-9)
    }

    @Test
    fun `拖拽行程按本页真实行数算 而不是固定六行口径`() {
        // 归一化基准 = (本页行数 − 1) × 行高（Dart `month_grid_collapse.dart:165-178`）。
        // 6 行月（默认）仍是 5 × 40 = 200。
        assertEquals(200.0, MonthPanelModel.dragExtent(40.0), 1e-9)
        assertEquals(160.0, MonthPanelModel.dragExtent(40.0, rowCount = 5), 1e-9)
        assertEquals(120.0, MonthPanelModel.dragExtent(40.0, rowCount = 4), 1e-9)

        // 5 行月：拖满 4 行高度（160dp）就完全收起；按旧 200dp 口径只走到 0.8，
        // 手指后半段白走 40dp —— 这正是 Dart 2026-11 修掉的「格子跟不上手指」。
        assertEquals(0.0, MonthPanelModel.progressAfterDrag(1.0, -160.0, 40.0, rowCount = 5), 1e-9)
        assertEquals(0.5, MonthPanelModel.progressAfterDrag(1.0, -80.0, 40.0, rowCount = 5), 1e-9)

        // 6 行月：上滑 100 = 半程；下 100 从收起 = 半程。
        assertEquals(0.5, MonthPanelModel.progressAfterDrag(1.0, -100.0, 40.0), 1e-9)
        assertEquals(0.5, MonthPanelModel.progressAfterDrag(0.0, 100.0, 40.0), 1e-9)
        // 拖过头钳在两端，不会得到负进度或大于 1 的进度。
        assertEquals(0.0, MonthPanelModel.progressAfterDrag(0.2, -900.0, 40.0), 1e-9)
        assertEquals(1.0, MonthPanelModel.progressAfterDrag(0.8, 900.0, 40.0), 1e-9)
        // 行高算不出来时原样返回（不能除 0，也不该跳到端点）。
        assertEquals(0.42, MonthPanelModel.progressAfterDrag(0.42, -100.0, 0.0), 1e-9)
        // 行数越界钳到 1..6：一行月行程为 0，原样返回。
        assertEquals(0.42, MonthPanelModel.progressAfterDrag(0.42, -100.0, 40.0, rowCount = 0), 1e-9)
        assertEquals(200.0, MonthPanelModel.dragExtent(40.0, rowCount = 99), 1e-9)
    }

    @Test
    fun `松手吸附_甩动方向压过行程`() {
        // 明确向上甩（≤ −180）：无论行程多少都收起。
        assertEquals(0.0, MonthPanelModel.settleTarget(1.0, 0.99, -180.0), 1e-9)
        assertEquals(0.0, MonthPanelModel.settleTarget(0.6, 0.55, -400.0), 1e-9)
        // 明确向下甩：一律展开。
        assertEquals(1.0, MonthPanelModel.settleTarget(0.0, 0.01, 180.0), 1e-9)
        assertEquals(1.0, MonthPanelModel.settleTarget(0.4, 0.45, 400.0), 1e-9)
        // 差一点点不够甩速（−179）：不看速度、看行程。
        assertEquals(1.0, MonthPanelModel.settleTarget(1.0, 0.99, -179.0), 1e-9)
    }

    @Test
    fun `松手吸附_没甩够就看行程`() {
        // 从展开走了 0.40 → 翻面收起。
        assertEquals(0.0, MonthPanelModel.settleTarget(1.0, 0.60, 0.0), 1e-9)
        // 从展开只走 0.30 → 也算翻面（2026-11-08 从 0.35 降到 0.10）。
        // 旧口径在这里弹回，「轻划一下不收」就是它造成的。
        assertEquals(0.0, MonthPanelModel.settleTarget(1.0, 0.70, 0.0), 1e-9)
        // 走过 0.12 → 翻面（0.10 的门槛）。
        assertEquals(0.0, MonthPanelModel.settleTarget(1.0, 0.88, 0.0), 1e-9)
        // 只走 0.05（真抖动）→ 弹回展开。
        assertEquals(1.0, MonthPanelModel.settleTarget(1.0, 0.95, 0.0), 1e-9)
        // 从收起往下走 0.40 → 翻面展开。
        assertEquals(1.0, MonthPanelModel.settleTarget(0.0, 0.40, 0.0), 1e-9)
        // 从收起只走 0.05 → 弹回收起。
        assertEquals(0.0, MonthPanelModel.settleTarget(0.0, 0.05, 0.0), 1e-9)
        // 从收起走 0.12 → 展开（与收起方向对称）。
        assertEquals(1.0, MonthPanelModel.settleTarget(0.0, 0.12, 0.0), 1e-9)
    }

    @Test
    fun `档位是派生态_只有两端可停留`() {
        // 吸附端点只有两个（Dart 原件没有「半收停住」这种状态）。
        assertEquals(
            listOf(MonthPanelLevel.COLLAPSED, MonthPanelLevel.EXPANDED),
            MonthPanelLevel.snapTargets,
        )
        assertEquals(listOf(0.0, 1.0), MonthPanelLevel.snapProgresses)

        // 分界 = 0.35 / 2 = 0.175：0.825 起读作展开、0.175 及以下读作收起。
        assertEquals(MonthPanelLevel.EXPANDED, MonthPanelModel.levelOf(1.0))
        assertEquals(MonthPanelLevel.EXPANDED, MonthPanelModel.levelOf(0.825))
        assertEquals(MonthPanelLevel.HALF, MonthPanelModel.levelOf(0.824))
        assertEquals(MonthPanelLevel.HALF, MonthPanelModel.levelOf(0.5))
        assertEquals(MonthPanelLevel.HALF, MonthPanelModel.levelOf(0.176))
        assertEquals(MonthPanelLevel.COLLAPSED, MonthPanelModel.levelOf(0.175))
        assertEquals(MonthPanelLevel.COLLAPSED, MonthPanelModel.levelOf(0.0))

        assertTrue(MonthPanelModel.isExpanded(0.9))
        assertTrue(MonthPanelModel.isExpanded(0.825))
        assertFalse(MonthPanelModel.isExpanded(0.82))
        assertFalse(MonthPanelModel.isExpanded(0.0))
    }

    @Test
    fun `收起保留行_选中优先于今天优先于月首`() {
        val dates = MonthGridModel.monthGridDates(2026, 10)
        val today = LocalDateTime.of(2026, 10, 27, 9, 30)

        // 选中日优先：10/15 落在第 3 行（9/28 起算，index 17 → 17 / 7 = 2? 不——
        // 10/15 是第 18 格：index 17，17 / 7 = 2，即第 3 行 0 基 2）。
        assertEquals(
            2,
            MonthPanelModel.rowToKeep(
                dates = dates,
                year = 2026,
                month = 10,
                selectedDate = LocalDateTime.of(2026, 10, 15, 0, 0),
                today = today,
            ),
        )
        // 没选就跟着今天：10/27 是第 30 格，index 29 → 第 5 行（0 基 4）。
        assertEquals(
            4,
            MonthPanelModel.rowToKeep(
                dates = dates,
                year = 2026,
                month = 10,
                selectedDate = null,
                today = today,
            ),
        )
        // 翻到没有今天的月份：回落到本月 1 号所在行 —— 42 格从「含 1 号的周一」
        // 起算，所以恒为第 1 行（也验证了「没选、没有今天」不会返回怪行号）。
        assertEquals(
            0,
            MonthPanelModel.rowToKeep(
                dates = dates,
                year = 2026,
                month = 10,
                selectedDate = null,
                today = LocalDateTime.of(2026, 12, 25, 8, 0),
            ),
        )
        // 日期列表为空（数据异常）：钳到 0，不许抛。
        assertEquals(
            0,
            MonthPanelModel.rowToKeep(
                dates = emptyList(),
                year = 2026,
                month = 10,
                selectedDate = today,
                today = today,
            ),
        )
    }

    @Test
    fun `内容位移把保留行顶到窗口顶端`() {
        assertEquals(80.0, MonthPanelModel.scrollOffset(2, 40.0, 1.0), 1e-9)
        assertEquals(0.0, MonthPanelModel.scrollOffset(2, 40.0, 0.0), 1e-9)
        assertEquals(40.0, MonthPanelModel.scrollOffset(2, 40.0, 0.5), 1e-9)
        // 越界进度按 0 / 1 钳制：不能把内容推过头或反向推。
        assertEquals(0.0, MonthPanelModel.scrollOffset(2, 40.0, -1.0), 1e-9)
        assertEquals(80.0, MonthPanelModel.scrollOffset(2, 40.0, 3.0), 1e-9)
    }

    // ------------------------------------------------------------------
    // 二、版面账（网格高 + 面板高 + 卡内开销 = 可用高）
    // ------------------------------------------------------------------

    @Test
    fun `展开态网格铺满六行_面板吃掉剩下的高度`() {
        val layout = MonthPanelModel.layout(
            progress = 1.0,
            availableHeightDp = 800.0,
            availableWidthDp = 400.0,
            headerHeightDp = 28.0,
            weekLabelWidthDp = 40.0,
            minRowHeightDp = 40.0,
            maxRowHeightDp = 78.0,
            keptRow = 2,
            handleHeightDp = 66.0,
            topPaddingDp = 14.0,
            rowCount = 6,
        )

        // 行高由**宽度**决定（手机竖屏宽度更紧）：(400 − 左右内边距 − 周次列) / 7。
        // 左右内边距 = AXIS_INSET − CELL_GAP；2026-11-07 起 CELL_GAP = 0，
        // 这里直接读常量，避免下次改格缝又硬编码一次。
        val expectedRowHeight =
            (400.0 - 2 * MonthMetrics.GRID_HORIZONTAL_PADDING - 40.0) / 7.0
        assertEquals(expectedRowHeight, layout.rowHeight, 1e-6)

        // 展开态窗口 = 上内边距 + 表头 + 6 行。
        assertEquals(14.0 + 28.0 + 6 * expectedRowHeight, layout.gridHeight, 1e-6)
        assertEquals(6.0, layout.visibleRows, 1e-9)
        // 三块高度必须正好拼满可用高 —— 少减一个就会溢出（Dart 侧 2026-10-23
        // 实测 overflow 41px 就是这么来的）。
        assertEquals(
            800.0,
            layout.gridHeight + layout.panelHeight + 66.0,
            1e-6,
        )
        // 展开态保留行在原位，内容不上移。
        assertEquals(0.0, layout.scrollOffset, 1e-9)
    }

    @Test
    fun `收起态只剩一行_面板长高把下面的行盖住`() {
        val expanded = MonthPanelModel.layout(
            progress = 1.0,
            availableHeightDp = 800.0,
            availableWidthDp = 400.0,
            headerHeightDp = 28.0,
            weekLabelWidthDp = 40.0,
            minRowHeightDp = 40.0,
            maxRowHeightDp = 78.0,
            keptRow = 3,
            handleHeightDp = 66.0,
            topPaddingDp = 14.0,
            rowCount = 6,
        )
        val collapsed = MonthPanelModel.layout(
            progress = 0.0,
            availableHeightDp = 800.0,
            availableWidthDp = 400.0,
            headerHeightDp = 28.0,
            weekLabelWidthDp = 40.0,
            minRowHeightDp = 40.0,
            maxRowHeightDp = 78.0,
            keptRow = 3,
            handleHeightDp = 66.0,
            topPaddingDp = 14.0,
            rowCount = 6,
        )

        // 行高**不变**：收起只缩窗口，格子若跟着变高会读成「字放大了」。
        assertEquals(expanded.rowHeight, collapsed.rowHeight, 1e-9)
        // 窗口缩到「表头 + 1 行」。
        assertEquals(1.0, collapsed.visibleRows, 1e-9)
        assertEquals(14.0 + 28.0 + expanded.rowHeight, collapsed.gridHeight, 1e-6)
        // 面板长高同样的量 —— 网格是被「盖住」的，不是被裁掉的。
        assertEquals(
            expanded.panelHeight + (expanded.gridHeight - collapsed.gridHeight),
            collapsed.panelHeight,
            1e-6,
        )
        // 保留行（第 3 行 0 基）被顶到窗口顶端：位移 = 3 × 行高。
        assertEquals(3 * expanded.rowHeight, collapsed.scrollOffset, 1e-6)
    }

    @Test
    fun `面板高度随进度单调不增_网格单调不减`() {
        var previousGrid = -1.0
        var previousPanel = Double.MAX_VALUE
        for (step in 0..10) {
            val layout = MonthPanelModel.layout(
                progress = step / 10.0,
                availableHeightDp = 800.0,
                availableWidthDp = 400.0,
                headerHeightDp = 28.0,
                weekLabelWidthDp = 40.0,
                minRowHeightDp = 40.0,
                maxRowHeightDp = 78.0,
                keptRow = 0,
                handleHeightDp = 66.0,
                topPaddingDp = 14.0,
                rowCount = 6,
            )
            assertTrue("网格窗口不该随展开进度变矮", layout.gridHeight >= previousGrid - 1e-6)
            assertTrue("面板不该随展开进度变高", layout.panelHeight <= previousPanel + 1e-6)
            previousGrid = layout.gridHeight
            previousPanel = layout.panelHeight
        }
    }

    @Test
    fun `矮屏宁可格子矮也不让面板消失`() {
        // 800×600 的横屏/分屏正是 Dart 侧实测「panelHeight = 0」的场景。
        val layout = MonthPanelModel.layout(
            progress = 1.0,
            availableHeightDp = 600.0,
            availableWidthDp = 800.0,
            headerHeightDp = 28.0,
            weekLabelWidthDp = 40.0,
            minRowHeightDp = 40.0,
            maxRowHeightDp = 78.0,
            keptRow = 0,
            handleHeightDp = 66.0,
            topPaddingDp = 14.0,
            rowCount = 6,
        )
        assertTrue(
            "面板必须至少留 ${MonthCollapse.PANEL_MIN_HEIGHT}dp，否则拖动无从谈起",
            layout.panelHeight >= MonthCollapse.PANEL_MIN_HEIGHT - 1e-6,
        )
        // 网格窗口被压到上限以内（不溢出）。
        assertTrue(600.0 - 66.0 >= layout.gridHeight)

        // 极矮：连面板下限都放不下时，网格窗口仍保证「表头 + 1 行」。
        val tiny = MonthPanelModel.layout(
            progress = 0.0,
            availableHeightDp = 150.0,
            availableWidthDp = 400.0,
            headerHeightDp = 28.0,
            weekLabelWidthDp = 40.0,
            minRowHeightDp = 40.0,
            maxRowHeightDp = 78.0,
            keptRow = 0,
            handleHeightDp = 66.0,
            topPaddingDp = 14.0,
            rowCount = 6,
        )
        assertTrue(tiny.gridHeight >= 14.0 + 28.0 + tiny.rowHeight - 1e-6)
        assertTrue("面板高度不许是负数", tiny.panelHeight >= 0.0)
    }

    @Test
    fun `周次列隐藏时不占宽度`() {
        fun rowHeight(weekColumnVisible: Boolean) = MonthPanelModel.layout(
            progress = 1.0,
            availableHeightDp = 800.0,
            availableWidthDp = 400.0,
            headerHeightDp = 28.0,
            weekLabelWidthDp = 40.0,
            minRowHeightDp = 1.0,
            maxRowHeightDp = 200.0,
            keptRow = 0,
            weekNumberColumnVisible = weekColumnVisible,
            rowCount = 6,
        ).rowHeight

        // 学期没配置时周次列整列不画，行高因此变宽 40/7。
        assertEquals(
            rowHeight(weekColumnVisible = false) - rowHeight(weekColumnVisible = true),
            40.0 / 7.0,
            1e-6,
        )
    }

    // ------------------------------------------------------------------
    // 三、本月概览
    // ------------------------------------------------------------------

    @Test
    fun `概览只数本月的格子_补位格不算`() {
        val grid = buildGrid(2026, 10) { date, outside ->
            when {
                // 本月：10/5 两节课 + 一场考试；10/6 一条日程；10/7 什么都没有。
                !outside && date.dayOfMonth == 5 -> intArrayOf(2, 1, 0)
                !outside && date.dayOfMonth == 6 -> intArrayOf(0, 0, 1)
                // 补位格（9/30 与 11/1 都在 42 格里）：有内容也**不许**算进概览。
                outside && date.dayOfMonth == 30 -> intArrayOf(3, 2, 1)
                outside && date.dayOfMonth == 1 -> intArrayOf(1, 1, 1)
                else -> null
            }
        }

        val counts = MonthPanelModel.overviewCounts(grid)
        assertEquals(2, counts.courseCount)
        assertEquals(1, counts.examCount)
        assertEquals(1, counts.scheduleCount)
        // 有安排的天数 = 10/5 与 10/6 两天（10/7 空白，补位格排除）。
        assertEquals(2, counts.scheduledDayCount)
        assertFalse(counts.isEmpty)
    }

    @Test
    fun `整月无安排时概览为空态`() {
        val empty = MonthPanelModel.overviewCounts(buildGrid(2026, 10) { _, _ -> null })
        assertTrue(empty.isEmpty)
        assertEquals(0, empty.courseCount)
        assertEquals(0, empty.scheduledDayCount)
        assertEquals(MonthOverviewCounts.EMPTY, empty)

        // 只有补位格有安排：仍然算空态（用户这个月确实没事）。
        val outsideOnly = MonthPanelModel.overviewCounts(
            buildGrid(2026, 10) { _, outside -> if (outside) intArrayOf(2, 0, 0) else null },
        )
        assertTrue(outsideOnly.isEmpty)
        assertEquals(0, outsideOnly.scheduledDayCount)
    }

    @Test
    fun `有安排的日子从今天往后排_越过月尾回月首`() {
        val grid = buildGrid(2026, 10) { date, outside ->
            if (outside) {
                null
            } else {
                when (date.dayOfMonth) {
                    3, 20, 28 -> intArrayOf(1, 0, 0)
                    else -> null
                }
            }
        }

        // 今天是 10/15：接下来是 20、28，然后才回落到月初 3。
        assertEquals(
            listOf(20, 28, 3),
            MonthPanelModel.scheduledDays(grid, LocalDateTime.of(2026, 10, 15, 0, 0))
                .map { it.date.dayOfMonth },
        )
        // 今天正好是有安排的那天：从今天起排（含今天）。
        assertEquals(
            listOf(20, 28, 3),
            MonthPanelModel.scheduledDays(grid, LocalDateTime.of(2026, 10, 20, 22, 0))
                .map { it.date.dayOfMonth },
        )
        // 本月之后的安排都没了（今天 = 10/29）：从月首起排。
        assertEquals(
            listOf(3, 20, 28),
            MonthPanelModel.scheduledDays(grid, LocalDateTime.of(2026, 10, 29, 0, 0))
                .map { it.date.dayOfMonth },
        )
        // 整月无安排：空列表（面板走「这个月还没有安排」那条支线）。
        assertTrue(MonthPanelModel.scheduledDays(buildGrid(2026, 10) { _, _ -> null }, LocalDateTime.of(2026, 10, 15, 0, 0)).isEmpty())
    }

    @Test
    fun `还有N天的N等于总数减已列`() {
        val grid = buildGrid(2026, 10) { date, outside ->
            if (!outside && date.dayOfMonth in setOf(3, 20, 28)) intArrayOf(1, 0, 0) else null
        }
        val upcoming = MonthPanelModel.scheduledDays(grid, LocalDateTime.of(2026, 10, 1, 0, 0))
        assertEquals(3, upcoming.size)

        // 一行 44dp、行间 10dp 的缝不计入容量（共享层 upcomingRowCapacity 口径）：
        // 132dp 正好放 3 行。
        val three = MonthPanelModel.upcomingSlice(upcoming, contentHeightDp = 132.0)
        assertEquals(3, three.shown.size)
        assertEquals(0, three.remaining)
        assertEquals(3, three.capacity)

        // 88dp → 2 行；还有 1 天没列（标题右端显示「还有 1 天」）。
        val two = MonthPanelModel.upcomingSlice(upcoming, contentHeightDp = 88.0)
        assertEquals(2, two.shown.size)
        assertEquals(1, two.remaining)
        assertEquals(listOf(3, 20), two.shown.map { it.date.dayOfMonth })

        // 极矮：共享层保证至少 1 行（下限 1，不是 0）。
        assertEquals(1, MonthPanelModel.upcomingSlice(upcoming, contentHeightDp = 10.0).shown.size)
        // 高度给足也只有 3 条真实数据，不能凭空变出空行。
        assertEquals(3, MonthPanelModel.upcomingSlice(upcoming, contentHeightDp = 5000.0).shown.size)
        assertEquals(0, MonthPanelModel.upcomingSlice(upcoming, contentHeightDp = 5000.0).remaining)
    }

    @Test
    fun `容量随高度单调不减且不超过真实条数`() {
        val grid = buildGrid(2026, 10) { date, outside ->
            if (!outside && date.dayOfMonth % 2 == 1) intArrayOf(1, 0, 0) else null
        }
        val upcoming = MonthPanelModel.scheduledDays(grid, LocalDateTime.of(2026, 10, 1, 0, 0))
        assertTrue("本月奇数日都有安排，条数应远多于面板能列的行", upcoming.size > 5)

        var previous = 0
        for (height in 0..600 step 22) {
            val slice = MonthPanelModel.upcomingSlice(upcoming, contentHeightDp = height.toDouble())
            assertTrue("高度增加不该让列出的行变少（height=$height）", slice.shown.size >= previous)
            assertTrue(slice.shown.size <= upcoming.size)
            assertEquals(upcoming.size, slice.shown.size + slice.remaining)
            previous = slice.shown.size
        }
    }

    @Test
    fun `零条那天不分配行也不留一条空白`() {
        val slice = MonthPanelModel.upcomingSlice(emptyList(), contentHeightDp = 500.0)
        assertEquals(0, slice.shown.size)
        assertEquals(0, slice.total)
        assertEquals(0, slice.remaining)
        assertEquals(0, slice.capacity)
        assertEquals(0, MonthPanelModel.upcomingCapacity(500.0, total = 0))
    }

    // ------------------------------------------------------------------
    // 四、拖拽分流（这段位移归网格还是归列表）
    // ------------------------------------------------------------------

    @Test
    fun `两个方向都是先动网格_再动列表`() {
        // 上滑（dy < 0）：网格只要还能收就先让它收。
        assertTrue(
            MonthPanelDragRouting.collapseTakesPriority(dy = -20.0, gridCanAbsorb = true),
        )
        // 网格已经收到底：位移交给列表。
        assertFalse(
            MonthPanelDragRouting.collapseTakesPriority(dy = -20.0, gridCanAbsorb = false),
        )
        // 下滑（dy > 0）：网格只要还能展开就先让它展开（2026-11-08 改）。
        // 旧实现这里会被列表吃掉，用户看到的就是「往下拉半天日历都不下来」。
        assertTrue(
            MonthPanelDragRouting.collapseTakesPriority(dy = 20.0, gridCanAbsorb = true),
        )
        // 网格已全展开：位移交给列表。
        assertFalse(
            MonthPanelDragRouting.collapseTakesPriority(dy = 20.0, gridCanAbsorb = false),
        )
        // 零位移不归任何人（避免空转一顿开始/结束回调）。
        assertFalse(
            MonthPanelDragRouting.collapseTakesPriority(dy = 0.0, gridCanAbsorb = true),
        )
    }


    @Test
    fun `抬手惯性线性估算_与速度同号且轻甩不补`() {
        // 手指向下甩 200dp/s：惯性 24dp（200 × 0.12），同号为正（内容回退）。
        assertEquals(24.0, MonthPanelDragRouting.flingDelta(200.0), 1e-9)
        // 手指向上甩 200dp/s：−24dp（内容继续往下走）。
        assertEquals(-24.0, MonthPanelDragRouting.flingDelta(-200.0), 1e-9)
        // 甩太轻（< 120）不补惯性。
        assertEquals(0.0, MonthPanelDragRouting.flingDelta(50.0), 1e-9)
        assertEquals(0.0, MonthPanelDragRouting.flingDelta(-50.0), 1e-9)

        assertTrue(MonthPanelDragRouting.hasFling(120.0))
        assertFalse(MonthPanelDragRouting.hasFling(119.9))
    }

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    /**
     * 造一份 42 格的月历（6 行 × 7 列）。
     *
     * [contentFor] 返回 `[课程数, 考试数, 日程数]`，null = 空白日。第二个参数是
     * 「是否补位格」——概览测试正是靠它把「补位格有安排但不算数」钉住。
     */
    private fun buildGrid(
        year: Int,
        month: Int,
        contentFor: (date: LocalDateTime, outside: Boolean) -> IntArray?,
    ): MonthGrid {
        val dates = MonthGridModel.monthGridDates(year, month)
        val entries = dates.map { date ->
            val outside = date.year != year || date.monthValue != month
            val content = contentFor(date, outside) ?: intArrayOf(0, 0, 0)
            MonthDayEntry(
                date = date,
                weekIndex = null,
                weekInSemester = false,
                courseCount = content[0],
                courseColorHexes = emptyList(),
                examCount = content[1],
                scheduleCount = content[2],
                isHoliday = false,
                isAdjustedWorkday = false,
                isOutsideMonth = outside,
            )
        }
        val weeks = (0 until MonthCollapse.MAX_ROWS).map { row ->
            MonthWeek(
                weekIndex = null,
                days = entries.subList(row * MonthCollapse.DAYS_PER_ROW, (row + 1) * MonthCollapse.DAYS_PER_ROW).toList(),
            )
        }
        return MonthGrid(
            year = year,
            month = month,
            weeks = weeks,
            busyDays = entries.filter { !it.isOutsideMonth && it.hasContent },
        )
    }
}
