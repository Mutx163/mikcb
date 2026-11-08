package com.mutx163.qingyu.pages.timetable.month

/**
 * 月视图的**字阶与栅格**：整页只有一个真源。
 *
 * 逐值转录自 `lib/widgets/timetable/month_view/month_metrics.dart`（2026-10-27，
 * Dart 侧 338 行那版）。那份文件的注释里记着三次返工的理由，这里只留结论，
 * 需要来龙去脉时去看 Dart 原件（它是唯一的历史档案）。
 *
 * ## 为什么这些数必须收在一处
 *
 * 2026-10-21 的量测：这一页曾经同时用 9 级字号（9 / 9.5 / 11 / 11.5 / 12 / 12.5 /
 * 13 / 13.5 / 14 / 15 / 16 / 17 / 21）与四条左线（11.7 / 13.5 / 14.1 / 17.2）。
 * 半像素字号与差 1~5dp 的轴线让层级完全不可预期。收口之后只剩五级字阶、
 * 五档墨色、一条左轴。
 *
 * ⚠️ **本文件是纯常量，不含 Compose**：它同时被模型层单测与渲染层引用，
 * 并且必须能在 L0（免 Gradle 的 kotlinc + JUnit）里编译。
 * 任何 `androidx.compose.*` / `top.yukonga.miuix.*` 的 import 都会让 L0 破功。
 */
object MonthType {
    /** 最小一级：星期表头、统计标签、角标、注脚。 */
    const val CAPTION = 11.0

    /** 正文/副标题：卡片副行、空态说明、按钮文字、工具行的年份。 */
    const val BODY = 13.0

    /** 标题级：卡片标题、当日议程的行标题。= `body2`（14sp）。 */
    const val TITLE = 14.0

    /** 日期数字（网格格子里）——格子的主体。= `body1`（16sp）。
     *
     * 2026-11-07 从 18 降到 16：42 个 18sp 数字会在白卡里形成一张“数字表”，
     * 压过 20sp 的月份标题；16 与 14 的卡片标题、18 的统计数字拉开一层，
     * 又不至于把日期读成次要信息。 */
    const val DAY_NUMBER = 16.0

    /**
     * 展示级：工具行的月份（`10月`）。= `title3`（20sp）。
     *
     * 概览卡的三个统计数字**不再**用这一级，改用 [DAY_NUMBER]（18sp）：
     * 它们和「这是哪个月」不是同一层信息，同尺寸会互相抢。
     */
    const val DISPLAY = 20.0

    /**
     * 周次轨（`第 17 周`）：复用 caption 字号（11sp）。
     *
     * 40dp 列宽扣掉 4dp 右留白后还剩 36dp，11sp 的「第 17 周」约 33dp，一行放得下；
     * 真放不下时由 `WeekRailLabel` 按测量结果等比缩小（渲染兜底，不是第七级字号）。
     * 旧注释写的「10sp 专用值」从未上屏（代码一直用 `footnote2` = 11sp），已删。
     */
    const val RAIL = CAPTION

    /**
     * 阶梯本体（小 → 大）。
     *
     * ⚠️ 这五级全部是 Miuix 官方字级（11 / 13 / 14 / 18 / 20），不是一条等比数列：
     * 13→14 只有 1.08、18→20 只有 1.11，靠**字重**补层级（卡片标题 BOLD、正文常规）。
     * 旧规则「相邻比 ≥1.15」在本项目的官方字库里做不到，已改成「只许官方字级 + 严格递增」，
     * 见 `MonthMetricsTest`。
     */
    val ladder: List<Double> = listOf(CAPTION, BODY, TITLE, DAY_NUMBER, DISPLAY)
}

/**
 * 月视图的**墨色档**：只留五档，每档一个明确语义。
 *
 * 旧实现散着 15 个 alpha，其中 0.55/0.62/0.66/0.70/0.72 五档几乎看不出差别
 * 却分别用在「表头、副行、注脚、箭头」四种语义上；而 0.38/0.42 压在卡面上
 * 只有 2.34:1 / 2.60:1，低于 3:1 底线 —— 箭头与空态图标基本靠猜。
 */
object MonthInk {
    /** 主文字：日期数字、卡标题、议程行标题。即主题 `onSurface` 原色。 */
    const val PRIMARY = 1.0

    /** 副行 / 说明：卡内副标题、空态正文、日期摘要（对比度 6.14:1）。 */
    const val SECONDARY = 0.70

    /**
     * 表头 / 弱化图标 / 非关键注脚。
     *
     * 压在 #FFF 上约 3.2:1（旧注释写的 3.79 是按更深的 `onSurface` 算的，与网格实际
     * 用的 #333 不符）：够非文字图标的 3:1，**不够 11sp 正文的 4.5:1**。
     * 11sp 及以下的说明文字一律用 [SECONDARY]；本档只给图标、箭头、分隔与装饰。
     */
    const val TERTIARY = 0.55

    /** **非文字**：分隔线、卡底拉杆、装饰描边。 */
    const val HAIRLINE = 0.12

    /** **非文字**：卡内色块底（日期筹码、今天药丸、分区底）。 */
    const val FILL = 0.06

    /** 五档本体（深 → 浅）。守卫按它验「档数 ≤5」与「文字档对比度 ≥3:1」。 */
    val levels: List<Double> = listOf(PRIMARY, SECONDARY, TERTIARY, HAIRLINE, FILL)

    /** 可以拿来写字的档。[HAIRLINE] / [FILL] 不在其中。 */
    val textLevels: List<Double> = listOf(PRIMARY, SECONDARY, TERTIARY)
}

/**
 * 月视图的栅格与间距。
 *
 * ## 版面语言（2026-10-23 定稿）
 *
 * 「壁纸 + 白卡 + 白卡」：日历卡与信息卡都直接浮在壁纸上、共用同一条外沿
 * [CARD_INSET]，与周/日视图的课程卡同一套语言。日历卡里的格子居中，
 * 所以格子填充边比外沿再让 [CELL_GAP]，让第一列日期数字的墨迹落在 [AXIS_INSET]。
 *
 * ⚠️ **卡是实底的**：卡片不透壁纸，所以卡片里的字一律按**主题**判，不按壁纸亮度。
 */
object MonthMetrics {
    /** **卡片外沿**：日历卡与信息卡距离屏幕左右的距离（同一条线）。 */
    const val CARD_INSET = 8.0

    /** 卡片**内部**的文字内边距。 */
    const val CARD_PADDING = 14.0

    /** **唯一的左轴**：品牌名、日期数字、信息卡标题全部落在这条线上。 */
    const val AXIS_INSET = CARD_INSET + CARD_PADDING

    /**
     * 日期格之间的缝。**2026-11-07 改为 0**：
     *
     * 旧实现是 1.5dp 缝 + 小圆角方块，读起来像“日期选择器”而不是月历；
     * 与整页的大圆角白卡、圆形/胶囊状态不搭。改成连续网格后，日期列直接
     * 拼成一张 7 列的矩阵，今天/选中用数字后面的圆形表达。
     */
    const val CELL_GAP = 0.0

    /** 工具行左右的内边距（取 6：箭头是 40dp 圆钮，内置 22dp 图标后左沿≈15）。 */
    const val TOOLBAR_INSET = 6.0

    /** 网格左右内边距（**从屏幕边量起**）= 外沿 + 内边距 − 格缝。 */
    const val GRID_HORIZONTAL_PADDING = AXIS_INSET - CELL_GAP

    /**
     * 日历卡**内部**的左右内边距（从卡片边缘到第一列）。
     *
     * 必须等于 `GRID_HORIZONTAL_PADDING - CARD_INSET`，**不能写成 CELL_GAP**：
     * 写成 1.5 会让表头「周一」紧贴卡片边缘，24dp 圆角的白卡看起来像
     * 内容溢出被裁了一刀；而且它与行高预算必须同源，否则「正方形行高」会偏。
     */
    const val GRID_INNER_PADDING = GRID_HORIZONTAL_PADDING - CARD_INSET

    /** 分区之间（概览卡 → 「本月有安排的日子」）的竖向间距。 */
    const val SECTION_GAP = 18.0

    /** 分区标题与它下面第一张卡之间。 */
    const val SECTION_TITLE_GAP = 8.0

    /** 信息卡与卡之间的缝（卡片之间露出的是壁纸，太窄会读成「一整块被切开」）。 */
    const val ITEM_GAP = 10.0

    /** 同一张卡内、两行议程之间的间距（共享一张卡，靠间距分组）。 */
    const val ROW_GAP = 10.0

    /**
     * 日期格**标记**的尺寸（课程圆点 / 考试方块 / 日程圆环）。
     *
     * 旧实现是「底边整宽分段色带」，段宽 = 1/段数：同一天「两节课」在有日程时
     * 会从 1/2 缩到 1/4，超过 4 节还会静默消失。改成**固定 4dp 的标记**后，
     * 同一个量在任何日子里都是同一个大小；装不下时用「+」标记表示还有。
     */
    const val CELL_MARK_HEIGHT = 4.0

    /** 日期数字与标记行之间的间距。 */
    const val DAY_NUMBER_MARK_GAP = 4.0

    /**
     * **标记槽位**的高度：无论这一格有没有内容，都占同样的高。
     *
     * 2026-10-25 修「高低不齐」：条件渲染标记会让同一行 7 个日号的顶边在
     * 271/275 之间跳（离散 4px）。槽位恒在，无色带时留空但高度不变。
     */
    const val CELL_MARK_SLOT_HEIGHT = DAY_NUMBER_MARK_GAP + CELL_MARK_HEIGHT

    /** 日期格内边距（横向）：标记行不贴到格子左右内沿。 */
    const val CELL_INNER_PADDING = 2.0

    /** 信息卡圆角（与日视图议程卡同档）。 */
    const val CARD_RADIUS = 20.0

    /** 卡片投影强度（上下两种卡共用一档）。 */
    const val CARD_SHADOW_ALPHA = 0.06

    /** 日历卡圆角：比信息卡再大一级（外大内小，层级才分得开）。 */
    const val CALENDAR_CARD_RADIUS = 24.0

    /** 日期格圆角（**只给面板行水波纹用**；日期格本身已改成连续网格，不画圆角方块）。 */
    const val CELL_RADIUS = 10.0

    /** 信息区底部留白（玻璃坞药丸悬在它上面）。 */
    const val PANEL_BOTTOM_INSET = 28.0

    /**
     * 「本月有安排的日子」**一行**占的高度（不含 [ROW_GAP]）。
     *
     * 存在的唯一理由是**按可用高度反推能列几行**：收起网格后日历变矮，
     * 这里应该多列几行，而不是把腾出来的空间留成空白（旧实现固定 3 行，
     * 收起态实测空出 304px = 35.7% 屏高）。
     */
    const val UPCOMING_ROW_HEIGHT = 44.0

    /** 日历卡底部拉杆区的高度（视觉只是 5dp 横条，命中区不能是 5dp —— 手指点不中）。 */
    const val CALENDAR_HANDLE_HEIGHT = 26.0

    /**
     * 日历卡**卡顶导航行**的高度（`‹ 2026年10月 › 今天`）。
     *
     * 取 40 = 周/日视图的星期栏高度。刻意保留这个数：改变它会让三个视图的
     * 顶栏高度分家（用户 2026-10-20 报过「为什么和日视图周视图的顶栏不一样高」）。
     */
    const val CALENDAR_NAV_HEIGHT = 40.0

    /**
     * 按可用宽度算日期格的行高：目标是正方形。
     *
     * 格宽 = (可用宽 − 左右内边距 − 周次列宽) / 7；可用高度若更紧，
     * 调用方自行 `min`。这里只给由**宽度**决定的那一支（真机上它才是上限）。
     */
    fun gridRowHeight(availableWidthDp: Double, railWidthDp: Double = 40.0): Double {
        val usable = availableWidthDp - 2 * GRID_HORIZONTAL_PADDING - railWidthDp
        return (usable / 7.0).coerceAtLeast(0.0)
    }

    /** 收起态按可用高度能列几行「本月有安排的日子」（至少 1 行）。 */
    fun upcomingRowCapacity(availableHeightDp: Double): Int {
        val usable = availableHeightDp.coerceAtLeast(0.0)
        return (usable / UPCOMING_ROW_HEIGHT).toInt().coerceAtLeast(1)
    }
}
