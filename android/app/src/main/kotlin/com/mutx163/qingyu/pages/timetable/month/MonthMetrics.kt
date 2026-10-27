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

    /** 标题级：分区标题、卡片标题、当日议程的行标题。 */
    const val TITLE = 15.0

    /** 日期数字（网格格子里）——格子的主体，比 [TITLE] 大一级。 */
    const val DAY_NUMBER = 18.0

    /** 展示级：本月概览的三个大数字，**也是**工具行的月份（`10月`）。 */
    const val DISPLAY = 22.0

    /**
     * 周次轨（`第 17 周`）。**阶梯之外的专用值**：列宽被 40dp 卡死，
     * 取 11 会让「第 17 周」折成两行。必须配合单行 + 缩放使用。
     */
    const val RAIL = 10.0

    /** 阶梯本体（小 → 大）。守卫按它逐级验「相邻比 ≥1.15」与「级数 ≤6」。 */
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

    /** 表头 / 注脚 / 图标（对比度 3.79:1，**文字能用的最低一档**）。 */
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

    /** 卡片之间、格子之间的缝。 */
    const val CELL_GAP = 1.5

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
     * 日期格**底边分段色带**的高度。
     *
     * 取代原来的圆点行，理由纯粹是**宽度**：一格内容区 40.43dp，4 个圆点要
     * 44dp、5 个要 55dp，分别溢出 3.57 / 14.57dp。色带按格宽均分，段数再多
     * 只会变窄，**永远不会溢出**。顺序：课程色（最多 4 段）→ 考试红 → 日程蓝。
     */
    const val CELL_STRIP_HEIGHT = 3.0

    /** 日期数字与色带之间的间距。 */
    const val DAY_NUMBER_STRIP_GAP = 5.0

    /**
     * **色带槽位**的高度：无论这一格有没有色带，都占同样的高。
     *
     * 2026-10-25 修「高低不齐」：条件渲染色带会让同一行 7 个日号的顶边在
     * 271/275 之间跳（离散 4px）。修法不是给没课的日子画假色带，而是让槽位恒在
     * —— 无色带时留空但高度不变，日号自然落在同一条线上（离散 0px）。
     */
    const val CELL_STRIP_SLOT_HEIGHT = DAY_NUMBER_STRIP_GAP + CELL_STRIP_HEIGHT

    /** 日期格内边距（横向）：色带要贴到格子左右内沿。 */
    const val CELL_INNER_PADDING = 2.0

    /** 信息卡圆角（与日视图议程卡同档）。 */
    const val CARD_RADIUS = 20.0

    /** 卡片投影强度（上下两种卡共用一档）。 */
    const val CARD_SHADOW_ALPHA = 0.06

    /** 日历卡圆角：比信息卡再大一级（外大内小，层级才分得开）。 */
    const val CALENDAR_CARD_RADIUS = 24.0

    /** 日期格圆角（20 会把 ~44dp 的格子削成圆形，正是旧实现「一排药丸」的原因）。 */
    const val CELL_RADIUS = 12.0

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
