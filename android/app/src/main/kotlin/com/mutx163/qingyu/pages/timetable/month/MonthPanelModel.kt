package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import java.time.LocalDateTime
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * 月视图**下半屏（信息面板半）**的全部纯逻辑：折叠档位、拖拽分流、概览统计、
 * 「本月有安排的日子」的行数分配、当日议程行。
 *
 * ## 为什么单独一文件
 *
 * `MonthGridModel.kt` 管的是「上面那张日历」（42 格、每天有几件事）；本文件管
 * 「下面那层面板」（收放进度、概览数字、议程行）。两半共用的判据只有一条
 * 「这天有没有安排」—— 那条住在 [MonthDayEntry.hasContent] 里，这里直接复用，
 * 不另写一份（写两份就会在「补位格算不算」这种细节上漂）。
 *
 * ## 为什么全部是纯函数
 *
 * 这一层有大量**期望值是人推出来的**结论：拖多少算翻面、收起后还剩几行、
 * 概览数字排除了哪些格子、「还有 N 天」的 N 怎么来。埋在 Composable 里就只能
 * 靠肉眼看，而肉眼看不出「35% 行程」与「34% 行程」的区别。所以全部落在这里，
 * 由 `MonthPanelModelTest` / `MonthDayAgendaModelTest` 用 JVM 单测钉住。
 *
 * ⚠️ **本文件是纯 Kotlin，不含 Compose / Android**：它同时被渲染层引用，
 * 并且必须能在 L0（免 Gradle 的 kotlinc + JUnit）里编译。任何
 * `androidx.compose.*` / `top.yukonga.miuix.*` 的 import 都会让 L0 破功。
 *
 * ## 逐值出处
 *
 * 几何常量全部来自 [MonthMetrics]（Lead 已收口，本文件不新增裸数值）；
 * 判据本身逐条对齐 `lib/domain/month_grid_collapse.dart` 与
 * `lib/widgets/timetable/month_view/month_panel_overview.dart`（Dart 原件
 * 只读，那批文件仍是另一会话的未提交工作）。
 */

/**
 * 面板的**档位**（展开进度落在哪一段）。
 *
 * ## 为什么是三个档、但只有两个吸附点
 *
 * Dart 原件（`month_grid_collapse.dart:monthGridSettleTarget`）的吸附目标是
 * **两端**：0 = 收起（只露一行）、1 = 展开（整月）。中间那一段是「手正拖着」
 * 的瞬时态，不是可停留的状态 —— 拖到一半松手会弹回或翻面，不会停在半收。
 *
 * 所以本枚举分两层：
 * * [snapTargets] = 真正的吸附端点（[COLLAPSED] / [EXPANDED]），拖拽结束由
 *   [MonthPanelModel.settleTarget] 决定落在哪一端；
 * * [HALF] 是**派生态**，由 [MonthPanelModel.levelOf] 按进度算出来，用于
 *   无障碍朗读、拉杆外观这类「此刻大概什么状态」的判断。
 *
 * 刻意**没有**凭空加第三个吸附点：原件没有它，多一个会让「松手后停在哪」与
 * 原页面不一致 —— 那属于改行为，不属于迁移。
 */
enum class MonthPanelLevel(val progress: Double) {
    /** 收起：网格窗口只露保留的那一行，面板占满其余高度。 */
    COLLAPSED(0.0),

    /** 半收：拖到中间、还没松手（或松手前的那一帧）的瞬时态。 */
    HALF(0.5),

    /** 展开：整月可见（4~6 行，按数据给）。 */
    EXPANDED(1.0),
    ;

    companion object {
        /** 真正的吸附端点（拖拽结束只可能停在这两个上）。 */
        val snapTargets: List<MonthPanelLevel> get() = listOf(COLLAPSED, EXPANDED)

        /** 吸附端点对应的进度值（0.0 / 1.0）。 */
        val snapProgresses: List<Double> get() = snapTargets.map { it.progress }
    }
}

/** 折叠几何的口径常量（对齐 `lib/domain/month_grid_collapse.dart` 的 `k*` 常量）。 */
object MonthCollapse {

    /** 网格**最大**行数（42 格口径）。实际画几行由 [MonthGrid.rowsInMonth] 给（4~6）。 */
    const val MAX_ROWS: Int = MonthGridModel.ROW_COUNT

    /** 收起态保留的行数：1 行（外加星期表头）。 */
    const val COLLAPSED_ROWS: Int = 1

    /** 一行 7 天。 */
    const val DAYS_PER_ROW: Int = MonthGridModel.DAYS_PER_ROW

    /**
     * 面板至少要留多高（dp）。
     *
     * 网格展开态按「满行铺满可用高度」算，屏幕矮（横屏 / 分屏 / 平板横放）时会把
     * 面板挤成 0 —— Dart 侧实测 800×600 下 panelHeight=0：面板整个不可见，
     * 拖动也就无从谈起。给一个下限让网格让步：宁可格子矮一点，也不能让面板消失。
     */
    const val PANEL_MIN_HEIGHT: Double = 96.0

    /**
     * 拖动判定为「翻面」的比例：拖过总行程的这个比例就吸附到对面，否则弹回起点。
     *
     * 取 0.35 而不是 0.5：收起 / 展开是**低风险、可逆**的小动作，手指轻轻一划
     * 就该响应，太重会读成「卡住不动」。
     */
    const val FLIP_TRAVEL: Double = 0.35

    /**
     * 松手时判方向用的速度阈值（dp/s）。
     *
     * 比 Flutter 的 `kMinFlingVelocity`（50）严：手一抖就翻面会让「想看整月却
     * 只剩一行」频繁误触发，宁可要求更明确的一甩。
     */
    const val FLING_VELOCITY: Double = 180.0
}

/**
 * 信息卡「卡壳」的尺寸账（对齐 Dart `_InfoCard.padVertical` / `titleGap` /
 * `titleLineHeight` / `fillChrome`）。
 *
 * ## 为什么这三个数没进 [MonthMetrics]
 *
 * 它们是 Dart `_InfoCard` 这个**私有类**里的常数（不在 `month_metrics.dart` 的
 * 公开版面常量里），而 [MonthMetrics] 是 Lead 收口的只读共享层。为了不把
 * 「卡内文字内边距」这类实现细节混进「整页栅格」，也为了不让渲染层写裸数字，
 * 收在这里一处定义、两处消费（渲染层的卡壳 + 本层的行数分配）。
 *
 * ⚠️ **改这里的任一个数，渲染层的 `MonthPanelOverview` 必须一起改**：
 * 行数是「卡高 − [INFO_CARD_CHROME]」反算出来的，账不对就会溢出或留白。
 * [MonthPanelModel.upcomingSlice] 的单调性测试只能证明「算得单调」，
 * 证明不了「账与真实布局同源」—— 后者靠这条注释与实机对照。
 */
object MonthPanelChrome {

    /** 卡内**上下**内边距（单边）。Dart `_InfoCard.padVertical = 13`。 */
    const val CARD_PADDING_VERTICAL: Double = 13.0

    /** 标题行与内容之间那段间距。Dart `_InfoCard.titleGap = 10`。 */
    const val CARD_TITLE_GAP: Double = 10.0

    /**
     * 标题行的行高：Dart `_InfoCard.titleLineHeight = 20`
     * （[MonthType.TITLE] = 15 按默认行高系数约 1.33 取整）。
     *
     * 写成常数而不是 `MonthType.TITLE * 1.33`：字号一改这里要跟着重算，而
     * 「重算」这个动作必须看得见 —— 乘出来的浮点值会掩盖「标题换档了」。
     */
    const val CARD_TITLE_LINE: Double = 20.0

    /** 卡片**内部**不属于内容的高度（Dart `_InfoCard.fillChrome` = 56）。 */
    const val INFO_CARD_CHROME: Double =
        CARD_PADDING_VERTICAL * 2 + CARD_TITLE_LINE + CARD_TITLE_GAP

    /**
     * 给定**整卡高度**，算出内容区还能用多高（下限 0）。
     *
     * 下限 0 是「诚实答案」：卡被塞得比卡壳还矮时不能返回负数去算出「-1 行」。
     * 正常路径到不了这里 —— [MonthCollapse.PANEL_MIN_HEIGHT] 保证信息区至少有
     * 标题 + 1 行的高度。
     */
    fun contentHeight(cardHeightDp: Double): Double =
        (cardHeightDp - INFO_CARD_CHROME).coerceAtLeast(0.0)
}

/**
 * 某个展开进度下的完整版面：网格窗口高、面板高、内容位移。
 *
 * 三者必须**同源算出来**，否则「面板盖到哪儿」「网格顶到哪儿」会各说各话 ——
 * 症状就是收起后仍露出半格（Dart 侧 2026-10-21 实际发生过一次）。
 */
data class MonthPanelLayout(
    /** 单行高度（正方形目标）。 */
    val rowHeight: Double,

    /** 网格**可见窗口**高度（含上内边距与星期表头）。 */
    val gridHeight: Double,

    /** 下方信息区高度（吃掉剩下的空间）。 */
    val panelHeight: Double,

    /** 网格内容相对窗口的纵向位移（**正数**；绘制时取负即上移）。 */
    val scrollOffset: Double,

    /** 收起后停住的那一行（0 基）。 */
    val keptRow: Int,

    /** 窗口此刻露几行（1..rowCount，含小数；直线插值，不是整数）。 */
    val visibleRows: Double,
)

/** 本月概览的三个总数 + 「有安排的天数」。 */
data class MonthOverviewCounts(
    /** 本月课程**节次**总和（同一天两节课算 2，不是 1 门）。 */
    val courseCount: Int,

    /** 本月未过期考试场次。 */
    val examCount: Int,

    /** 本月日程实例数。 */
    val scheduleCount: Int,

    /** 本月有安排（任意一种）的**天数**。 */
    val scheduledDayCount: Int,
) {
    /**
     * 整月没有任何安排 —— 渲染层据此只留一块空态，不摆三个 0。
     *
     * 「0 节课 / 0 场考试 / 0 个日程」读起来像加载失败，而不是「这个月确实没事」。
     */
    val isEmpty: Boolean
        get() = courseCount == 0 && examCount == 0 && scheduleCount == 0

    companion object {
        /** 空月（与 [isEmpty] 配套使用）。 */
        val EMPTY: MonthOverviewCounts = MonthOverviewCounts(0, 0, 0, 0)
    }
}

/**
 * 「本月有安排的日子」这一节的分页结果：显示前几行、共几条、还剩几条。
 *
 * [capacity] 是**按可用高度算出来的容量**（不是 [shown] 的长度）：容量可能大于
 * 实际条数，两者的差正是「这张卡没填满」的诚实读数。
 */
data class MonthUpcomingSlice(
    val shown: List<MonthDayEntry>,
    val total: Int,
    val remaining: Int,
    val capacity: Int,
)

/** 当日议程行的类别（渲染层按它选强调色与去处）。 */
enum class MonthAgendaKind {
    COURSE,
    EXAM,
    SCHEDULE,
}

/**
 * 当日议程的一行：课程 / 考试 / 日程混排。
 *
 * 字段是 Dart `MonthAgendaRow`（`lib/domain/month_view_logic.dart:144`）的展示子集
 * + 导航所需的原对象：渲染层只用前六个字段，点击时把 [course] / [exam] /
 * [schedule] 原样交给表单（月视图不做编辑，只转发）。
 */
data class MonthAgendaRow(
    val kind: MonthAgendaKind,

    /** 稳定身份（`LazyColumn` 的 key 与单测断言都用它）。 */
    val id: String,

    /**
     * 展示钟点（"HH:mm"）。课程节次映射不到作息时间时为 null —— 排序垫底，
     * 渲染层画占位（"`--:--`"）。
     */
    val clockText: String?,

    val title: String,

    /** 副行：课程地点 / 考试地点 / 日程地点；空串一律收成 null（渲染层少画一行）。 */
    val subtitle: String?,

    /** 课程 / 日程颜色 hex；考试为 null（渲染层固定用考试红）。 */
    val colorHex: String?,

    val course: Course? = null,
    val exam: Exam? = null,
    val schedule: MonthScheduleInstance? = null,
)

/**
 * 面板拖拽的**分流判据**（一个指针源，同时驱动「网格收放」与「列表滚动」）。
 *
 * ## 用户口径（Dart 侧三次，最后一条是实际滑过之后说的）
 *
 * 1. 「底部信息区域，应该支持在任意位置上下滑动，可以操作日期表格的上下收起展开」；
 * 2. 「向下滑的时候应该是**先收起上面为一行**，**然后再是下面信息区域滚动**」；
 * 3. 「为什么现在滚动的时候，手拉下面信息区域，它可以直接下滑信息区域滚动，
 *    而不是先收起上面的东西，**这两个滚动没有一体化的效果**」。
 *
 * ## 为什么判据是纯函数
 *
 * Dart 侧有两版失败实现（外层 `Listener` 判归属被事件派发顺序打败；自定义
 * `ScrollPhysics` 被「面板高度变化 ⇒ maxScrollExtent 缩到 0 ⇒ goBallistic」
 * 当场判死）。最终形态是「列表的用户滚动整个关掉、位移由一处算好再 jump 进去」，
 * 于是**唯一容易改错的就是「这段位移归谁」**。抽成静态纯函数才钉得住。
 *
 * ## 顺序（用户口径那张表）
 *
 * | 手势 | 第一优先 | 之后 |
 * |---|---|---|
 * | 向上拖（dy < 0，看下面） | 网格收起（t → 0） | 收到底后滚列表 |
 * | 向下拖（dy > 0，往回看） | 列表退回顶部 | 到顶后网格展开（t → 1） |
 */
object MonthPanelDragRouting {

    /**
     * 抬手后列表惯性的估算系数（秒）。
     *
     * 没有还原原生摩擦模型：面板内容是一列卡片、滚动距离短，线性近似的手感
     * 差别看不出来，而省掉一整套摩擦模拟。
     */
    const val FLING_DURATION_FACTOR: Double = 0.12

    /** 触发惯性的最小抬手速度（dp/s）。 */
    const val FLING_MIN_VELOCITY: Double = 120.0

    /**
     * 这段位移该归网格（true）还是归列表（false）。
     *
     * @param dy 本次指针位移（向上为负）。
     * @param listCanScroll 列表此刻还能不能往这个方向滚（判据见 [listCanScroll]）。
     * @param gridCanAbsorb 网格此刻还能不能往这个方向收放。
     */
    fun collapseTakesPriority(
        dy: Double,
        listCanScroll: Boolean,
        gridCanAbsorb: Boolean,
    ): Boolean {
        if (dy == 0.0) return false
        if (dy < 0) {
            // 往上拖 = 要看下面：网格先让位，与列表当前位置无关。
            return gridCanAbsorb
        }
        // 往下拖 = 往回看：列表先退回顶部，到顶了才轮到网格展开。
        if (listCanScroll) return false
        return gridCanAbsorb
    }

    /**
     * 列表此刻还能不能往 [dy] 方向滚。
     *
     * 判据直接吃 Compose 的 `canScrollForward` / `canScrollBackward`，**不再自己
     * 用 pixels / min / max 判边界**：`LazyListState` 不暴露 maxScrollExtent（它要
     * 靠已测量的项累加），而那两个 flag 已经把边界与亚像素余量都算进去了。自己
     * 凑一个近似的 max，反而会在「滚到底差 0.5dp」时判错 —— 用户在那儿拖会觉得
     * 第一下没反应。
     *
     * 两个 flag 都为 false（没有滚动视图、或内容没超过一屏）时恒 false：概览态
     * 内容正好填满，本来就没有可滚的位移，那时位移应当**全部**交给网格收放。
     */
    fun listCanScroll(
        dy: Double,
        canScrollForward: Boolean,
        canScrollBackward: Boolean,
    ): Boolean = when {
        dy < 0 -> canScrollForward
        dy > 0 -> canScrollBackward
        else -> false
    }

    /** 这一段抬手速度够不够触发惯性（列表的用户滚动被关掉了，惯性得自己补）。 */
    fun hasFling(velocityDy: Double): Boolean = abs(velocityDy) >= FLING_MIN_VELOCITY

    /**
     * 抬手惯性要滚多远（dp；**与速度同号**）。
     *
     * 手指向下（velocityDy > 0）⇒ 内容回退 ⇒ 要往回滚；符号只在调用点转换成
     * Compose 的 `animateScrollBy` 口径（与 `dispatchRawDelta` 相反），转换点
     * 只有一处。
     *
     * 没有还原原生摩擦模型：面板内容是一列卡片、滚动距离短，线性近似的手感差别
     * 看不出来，而省掉一整套摩擦模拟。
     */
    fun flingDelta(velocityDy: Double): Double {
        if (!hasFling(velocityDy)) return 0.0
        return velocityDy * FLING_DURATION_FACTOR
    }
}

/**
 * 面板半的全部纯逻辑入口（折叠状态机 + 概览 + 行数分配）。
 *
 * 与 [MonthGridModel] 同一套收口思路：渲染层只画，判据全在这里。
 */
object MonthPanelModel {

    // ------------------------------------------------------------------
    // 一、折叠状态机
    // ------------------------------------------------------------------

    /**
     * 展开进度 [progress]（0..1，0 = 收起）下**网格窗口**应露出几行（表头除外）。
     *
     * 注意这是**窗口**的行数，不是网格内容的行数 —— 内容是 [rowCount] 行，
     * 收起只是窗口变小：上面几行被顶出窗口、下面几行被面板盖住。
     *
     * **行数线性插值而不是总高插值**：直接插总高会让整块同时缩放，看起来像
     * 「整块被压扁」。越界的进度钳回 0..1。
     *
     * @param rowCount 这批日期实际要画的行数（[MonthGrid.rowsInMonth]，4~6）。
     *   越界值钳到 [MonthCollapse.COLLAPSED_ROWS]..[MonthCollapse.MAX_ROWS]。
     */
    fun visibleRows(progress: Double, rowCount: Int = MonthCollapse.MAX_ROWS): Double {
        val clamped = progress.coerceIn(0.0, 1.0)
        val rows = rowCount.coerceIn(MonthCollapse.COLLAPSED_ROWS, MonthCollapse.MAX_ROWS)
        return MonthCollapse.COLLAPSED_ROWS +
            (rows - MonthCollapse.COLLAPSED_ROWS) * clamped
    }

    /**
     * 拖拽行程的**归一化基准**：从完全展开拖到收起，手指要走多少 dp。
     *
     * 必须按**这一页真实行数**算：`(行数 − 保留行数) × 行高`（Dart
     * `month_grid_collapse.dart:165-178` 的 `monthGridDragTravel`）。
     * 4/5 行月的旧实现按 6 行口径写死，手指走满 5 行距离时窗口早已停在 1 行，
     * 后半段变成「手指还在动、格子不动」—— 2026-11 Dart 侧修的就是这个。
     *
     * @param rowCount 本页实际行数（[MonthGrid.rowsInMonth]，4~6）；越界值钳到
     *   [MonthCollapse.COLLAPSED_ROWS]..[MonthCollapse.MAX_ROWS]。
     */
    fun dragExtent(rowHeightDp: Double, rowCount: Int = MonthCollapse.MAX_ROWS): Double {
        val rows = rowCount.coerceIn(MonthCollapse.COLLAPSED_ROWS, MonthCollapse.MAX_ROWS)
        return (rows - MonthCollapse.COLLAPSED_ROWS) * rowHeightDp
    }

    /**
     * 拖拽位移 → 新进度（1:1 跟手，手指向上移 [deltaDy] < 0 即收起）。
     *
     * 行程按 [dragExtent]（本页真实行数）算；为 0（行高算不出来 / 屏幕为零 /
     * 只有一行）时原样返回并钳在 0..1：不能除以 0，也不该把「算不出」
     * 翻译成「跳到端点」。
     */
    fun progressAfterDrag(
        progress: Double,
        deltaDy: Double,
        rowHeightDp: Double,
        rowCount: Int = MonthCollapse.MAX_ROWS,
    ): Double {
        val clamped = progress.coerceIn(0.0, 1.0)
        val extent = dragExtent(rowHeightDp, rowCount)
        if (extent <= 0.0) return clamped
        return (clamped + deltaDy / extent).coerceIn(0.0, 1.0)
    }

    /**
     * 松手吸附目标（0 = 收起、1 = 展开）。
     *
     * 判据按优先级：
     * 1. 明确的甩动方向压倒一切（[velocityDy] 向上 = 收起、向下 = 展开）；
     * 2. 没甩够速度就看**行程**：从 [startValue] 走过 [MonthCollapse.FLIP_TRAVEL]
     *    的比例就吸附到对面；
     * 3. 都不够 → 弹回起点状态（手指在临界点抖动不会翻面）。
     */
    fun settleTarget(startValue: Double, currentValue: Double, velocityDy: Double): Double {
        if (velocityDy <= -MonthCollapse.FLING_VELOCITY) return 0.0
        if (velocityDy >= MonthCollapse.FLING_VELOCITY) return 1.0
        val traveled = abs(startValue - currentValue)
        if (traveled >= MonthCollapse.FLIP_TRAVEL) {
            return if (currentValue < startValue) 0.0 else 1.0
        }
        return if (startValue >= 0.5) 1.0 else 0.0
    }

    /** 松手吸附到哪个档（[settleTarget] 的枚举版，供无障碍与拉杆外观使用）。 */
    fun settleLevel(startValue: Double, currentValue: Double, velocityDy: Double): MonthPanelLevel =
        levelOf(settleTarget(startValue, currentValue, velocityDy))

    /**
     * 进度落在哪一档（派生态，三个档位见 [MonthPanelLevel]）。
     *
     * 分界取 [MonthCollapse.FLIP_TRAVEL] 的一半：那正是「松手必定翻面」的行程
     * 门槛，于是「拖到会被判成展开的位置」与「读取为展开」说的是同一件事 ——
     * 不会出现「界面说展开、松手却收起」的错位。
     */
    fun levelOf(progress: Double): MonthPanelLevel {
        val clamped = progress.coerceIn(0.0, 1.0)
        val margin = MonthCollapse.FLIP_TRAVEL / 2
        return when {
            clamped >= 1.0 - margin -> MonthPanelLevel.EXPANDED
            clamped <= margin -> MonthPanelLevel.COLLAPSED
            else -> MonthPanelLevel.HALF
        }
    }

    /**
     * 表格当前是不是「展开」（对齐 Dart `monthGridIsExpanded`）。
     *
     * 收起 = 只露一行；展开 = 满行全露。阈值同 [levelOf]。
     */
    fun isExpanded(progress: Double): Boolean = levelOf(progress) == MonthPanelLevel.EXPANDED

    /**
     * 收起态保留哪一行（0 基）。
     *
     * 优先级：含 [selectedDate] 的行 → 含 [today] 的行 → 含本月 1 号的行。
     * 最后一个兜底是给「翻到很远的月份、又没选日期」的场景：那页没有今天，
     * 保留 1 号所在行就是「这页主体开始的那行」。
     *
     * @param dates 42 格日期（[MonthGridModel.monthGridDates] 的输出，也可以传
     *   [MonthGrid.days] 的日期）。
     * 返回值恒落在合法行号内（输入异常时钳到 0 —— 这是渲染路径上的函数，
     * 宁可画第一行也不要抛异常白屏）。
     */
    fun rowToKeep(
        dates: List<LocalDateTime>,
        year: Int,
        month: Int,
        selectedDate: LocalDateTime?,
        today: LocalDateTime,
    ): Int {
        if (dates.isEmpty()) return 0

        fun rowOf(target: LocalDateTime): Int? {
            val key = normalizeDay(target)
            for (index in dates.indices) {
                if (normalizeDay(dates[index]) == key) {
                    return index / MonthCollapse.DAYS_PER_ROW
                }
            }
            return null
        }

        if (selectedDate != null) {
            rowOf(selectedDate)?.let { return it }
        }
        rowOf(today)?.let { return it }
        // 月份越界（13 月）按日历顺延：与 Dart `DateTime(year, month)` 同口径，
        // 翻到 12 月再 +1 时不必在这里另写边界。
        return rowOf(DartTime.dateTime(year, month, 1)) ?: 0
    }

    /**
     * 网格**内容**相对窗口的纵向偏移（非负；调用方取负后上移）。
     *
     * 把保留行顶到窗口顶端 —— 于是保留行上方的行走出窗口（视觉上向上收起）。
     *
     * @param rowOffsetProgress 1 = 完全顶上去（收起态）、0 = 不动（展开态）。
     */
    fun scrollOffset(
        keptRow: Int,
        rowHeightDp: Double,
        rowOffsetProgress: Double,
    ): Double = keptRow * rowHeightDp * rowOffsetProgress.coerceIn(0.0, 1.0)

    /**
     * 算出某一刻的完整版面。
     *
     * 两个位移**同时发生**（用户口径「上面三行向上收起，下面两行往上逐渐被下面
     * 的东西盖起来」）：
     *
     * * 网格窗口从「表头 + 满行」缩到「表头 + 1 行」；
     * * 面板高度从 0 长到「可用高 − 收起后网格窗口高」，把网格下方的行盖掉。
     *
     * 行高按 [rowCount] 行的可用空间算：收起只缩小窗口，行高本身不能跟着变
     * （否则收起时格子会突然变高，读起来像「字放大了」）。
     *
     * @param headerHeightDp 星期表头高度。
     * @param weekLabelWidthDp 周次列宽度（`weekNumberColumnVisible = false` 时不占位）。
     * @param handleHeightDp 卡内**非表格**的开销（卡顶导航行 + 分隔线 + 卡底拉杆）。
     *   少扣一个，网格就放不下必然溢出（Dart 侧 2026-10-23 实测过 41px 溢出）。
     * @param topPaddingDp 网格外面那层上内边距。它**算进** [MonthPanelLayout.gridHeight]，
     *   因为窗口是从页面顶边量起的；行高预算里也扣了它，两处不能重复扣。
     */
    fun layout(
        progress: Double,
        availableHeightDp: Double,
        availableWidthDp: Double,
        headerHeightDp: Double,
        weekLabelWidthDp: Double,
        minRowHeightDp: Double,
        maxRowHeightDp: Double,
        keptRow: Int,
        weekNumberColumnVisible: Boolean = true,
        handleHeightDp: Double = 0.0,
        topPaddingDp: Double = 0.0,
        rowCount: Int = MonthCollapse.MAX_ROWS,
    ): MonthPanelLayout {
        val t = progress.coerceIn(0.0, 1.0)
        val rows = rowCount.coerceIn(MonthCollapse.COLLAPSED_ROWS, MonthCollapse.MAX_ROWS)
        val visible = visibleRows(t, rows)

        // 行高只能用「扣掉上内边距、卡内开销、面板下限之后」的高度：这些都占同一块
        // 可用高度，少扣一个算出的行高就偏大，放不下必然溢出。
        //
        // minRowHeight **不参与**这里的下限钳制：屏幕矮到连 rows × minRowHeight 都
        // 放不下时，宁可格子比「可读下限」还矮，也不能让网格溢出（溢出 = 底部内容
        // 被裁掉且控制台报错）。真机矮屏（横屏 / 分屏）会走这条路。
        val gridSpaceForRows = max(
            0.0,
            availableHeightDp - topPaddingDp - handleHeightDp - headerHeightDp -
                MonthCollapse.PANEL_MIN_HEIGHT,
        )
        val squareRowHeight = MonthMetrics.gridRowHeight(
            availableWidthDp,
            if (weekNumberColumnVisible) weekLabelWidthDp else 0.0,
        )
        val rowHeight = min(
            squareRowHeight.coerceIn(minRowHeightDp, maxRowHeightDp),
            // 硬上限：rows 行 + 表头必须塞进「可用高度 − 上内边距 − 卡内开销 − 面板下限」。
            gridSpaceForRows / rows,
        )

        // gridHeight **包含**页面那层上内边距：调用方会把网格包在一个
        // `top = topPaddingDp` 的 Padding 里，那几 dp 是真实占用的高度。
        // 不包含的话少给几 dp，网格溢出（Dart 侧实际踩过 overflow 8px）。
        val rawGridHeight = topPaddingDp + headerHeightDp + visible * rowHeight
        // 封顶上限是「可用高度 − 上内边距 − 卡内开销 − 面板下限」，但**加回**
        // topPaddingDp 才是窗口能占的高度（窗口含内边距，而上面那笔账是从
        // 「不含内边距的空间」推出来的）。
        //
        // 下限保留「上内边距 + 表头 + 保留那一行」：再怎么压缩也得放得下表头与
        // 那一行，否则网格本身没意义。
        val gridHeightCap = max(
            topPaddingDp + headerHeightDp + rowHeight,
            availableHeightDp - handleHeightDp - MonthCollapse.PANEL_MIN_HEIGHT,
        )
        val gridHeight = min(rawGridHeight, gridHeightCap)

        return MonthPanelLayout(
            rowHeight = rowHeight,
            gridHeight = gridHeight,
            // 面板吃掉剩下的空间，扣掉网格窗口与卡内开销那一条。
            //
            // ⚠️ **不要再减 topPaddingDp**：它已经算在 gridHeight 里面了。
            panelHeight = max(0.0, availableHeightDp - gridHeight - handleHeightDp),
            scrollOffset = scrollOffset(
                keptRow = keptRow,
                rowHeightDp = rowHeight,
                // 展开态保留行就在原位（0），收起态把它顶到窗口顶端（1）。
                rowOffsetProgress = 1.0 - t,
            ),
            keptRow = keptRow,
            visibleRows = visible,
        )
    }

    // ------------------------------------------------------------------
    // 二、本月概览
    // ------------------------------------------------------------------

    /**
     * 本月概览的四个数（**只数落在本月**的格子）。
     *
     * 补位格必须排除，否则 10 月的概览会把 9 月末、11 月初那几天的课也算进来 ——
     * 用户看到的数字比实际多。[MonthDayEntry.isOutsideMonth] 是唯一判据。
     */
    fun overviewCounts(grid: MonthGrid): MonthOverviewCounts {
        var course = 0
        var exam = 0
        var schedule = 0
        var scheduledDays = 0
        for (day in grid.days) {
            if (day.isOutsideMonth) continue
            course += day.courseCount
            exam += day.examCount
            schedule += day.scheduleCount
            if (day.hasContent) scheduledDays++
        }
        return MonthOverviewCounts(
            courseCount = course,
            examCount = exam,
            scheduleCount = schedule,
            scheduledDayCount = scheduledDays,
        )
    }

    /**
     * 「本月有安排的日子」的展示顺序：**从今天往后**，越过月尾再回月首。
     *
     * 用户打开月视图首先关心的是「接下来还有什么」，而不是「月初那几天」；
     * 今天之后本月已无安排时回落到月首（那时用户在翻旧月份看记录）。
     *
     * @return 不含补位格的、有安排的日子；整月无安排时为空列表。
     */
    fun scheduledDays(grid: MonthGrid, today: LocalDateTime): List<MonthDayEntry> {
        val normalizedToday = normalizeDay(today)
        val busy = grid.days.filter { !it.isOutsideMonth && it.hasContent }
        if (busy.isEmpty()) return emptyList()
        val startIndex = busy.indexOfFirst { !it.date.isBefore(normalizedToday) }
        if (startIndex <= 0) return busy
        return busy.subList(startIndex, busy.size) + busy.subList(0, startIndex)
    }

    /**
     * 「本月有安排的日子」按可用高度能列几行（至少 1 行、最多真实条数）。
     *
     * 容量取自 [MonthMetrics.upcomingRowCapacity]（Lead 收口的共享判据）：收起
     * 网格后信息区变高，这里就该多列几行，而不是把腾出来的空间留成空白
     * （Dart 侧旧实现固定 3 行，收起态实测空出 304px = 35.7% 屏高）。
     */
    fun upcomingCapacity(contentHeightDp: Double, total: Int): Int {
        if (total <= 0) return 0
        return min(MonthMetrics.upcomingRowCapacity(contentHeightDp), total)
    }

    /**
     * 把「本月有安排的日子」切成本次要显示的行 + 剩余条数。
     *
     * 「还有 N 天」的 N 就是 [MonthUpcomingSlice.remaining]：它放在卡标题右端，
     * 语义是「这一节还有多少没列」，信息量增加、高度不增。
     */
    fun upcomingSlice(
        upcoming: List<MonthDayEntry>,
        contentHeightDp: Double,
    ): MonthUpcomingSlice {
        val total = upcoming.size
        val capacity = upcomingCapacity(contentHeightDp, total)
        val shown = if (capacity <= 0) emptyList() else upcoming.subList(0, capacity).toList()
        return MonthUpcomingSlice(
            shown = shown,
            total = total,
            remaining = total - shown.size,
            capacity = capacity,
        )
    }

    // ------------------------------------------------------------------
    // 内部实现
    // ------------------------------------------------------------------

    /** 归一到当天 00:00（日历日口径，不做时长加减）。 */
    private fun normalizeDay(value: LocalDateTime): LocalDateTime =
        LocalDateTime.of(value.year, value.monthValue, value.dayOfMonth, 0, 0)
}

/**
 * 当日议程行的组装（课程 + 考试 + 日程混排，与日视图同一混排语义）。
 *
 * ## 为什么数据来源全部转调 [MonthGridModel]
 *
 * 「某天有哪些课 / 哪些未过期考试 / 哪些日程实例」这三条判据在
 * [MonthGridModel.coursesOnDate] / [examsOnDate] / [scheduleInstancesOnDate] 里
 * 已经有一份，而且月网格的颜色带、角标也在用同一份。这里若另写一遍，
 * 「网格说这格有 2 节课、议程却只列出 1 节」这种漂移迟早出现 —— 所以直接转调。
 *
 * ## 排序口径
 *
 * 钟点非空的按 [DayClock.compare]（钟点比较的正源，勿写字符串字典序）；
 * 课程节次映射不到作息时间的行钟点为 null、**垫底**；垫底层保持注入序稳定
 * （课 → 考试 → 日程 的注入顺序 + 各自原顺序）。
 */
object MonthDayAgendaModel {

    /**
     * 组装 [date] 的议程行。
     *
     * @param semesterStart 开学日（学期未配置传 null → 当天没有课）。
     * @param sections 作息时间表（当前生效的时间模板；缺失回落设置里那份）。
     * @param now 判断考试是否已过期的「此刻」。
     */
    fun build(
        date: LocalDateTime,
        courses: List<Course>,
        exams: List<Exam>,
        scheduleItems: List<ScheduleItem>,
        semesterStart: LocalDateTime?,
        sections: List<SectionTime>,
        now: LocalDateTime,
    ): List<MonthAgendaRow> {
        val rows = mutableListOf<MonthAgendaRow>()

        for (course in MonthGridModel.coursesOnDate(courses, date, semesterStart)) {
            rows += MonthAgendaRow(
                kind = MonthAgendaKind.COURSE,
                id = course.id,
                clockText = sectionStartClock(sections, course.startSection),
                title = course.name,
                subtitle = course.location.trim().ifEmpty { null },
                colorHex = course.color.trim().ifEmpty { null },
                course = course,
            )
        }
        for (exam in MonthGridModel.examsOnDate(exams, date, now)) {
            rows += MonthAgendaRow(
                kind = MonthAgendaKind.EXAM,
                id = exam.id,
                clockText = exam.startTime,
                title = exam.name,
                subtitle = exam.location?.trim()?.ifEmpty { null },
                // 考试没有自己的颜色：渲染层固定用考试红（与网格角标同源）。
                colorHex = null,
                exam = exam,
            )
        }
        for (instance in MonthGridModel.scheduleInstancesOnDate(scheduleItems, date)) {
            rows += MonthAgendaRow(
                kind = MonthAgendaKind.SCHEDULE,
                id = instance.occurrenceId,
                clockText = instance.item.startTime,
                title = instance.item.title,
                subtitle = instance.item.location?.trim()?.ifEmpty { null },
                colorHex = instance.item.color.trim().ifEmpty { null },
                schedule = instance,
            )
        }

        // 稳定排序：null 钟点垫底，其余按钟点；同钟点保持注入序。
        val indexed = rows.withIndex().toList()
        return indexed.sortedWith(
            Comparator { left, right ->
                val leftClock = left.value.clockText
                val rightClock = right.value.clockText
                when {
                    leftClock == null && rightClock == null -> left.index.compareTo(right.index)
                    leftClock == null -> 1
                    rightClock == null -> -1
                    else -> {
                        val compare = DayClock.compare(leftClock, rightClock)
                        if (compare != 0) compare else left.index.compareTo(right.index)
                    }
                }
            },
        ).map { it.value }
    }

    /**
     * 节次序号（1 起）→ 作息表起始钟点；越界或时间缺失返回 null。
     *
     * 映射不到时**不猜**（不拿课程自己的 startTime 顶上）：那是另一套口径，
     * 混用会让「同样是 3 节课」在不同页显示不同钟点。
     */
    fun sectionStartClock(sections: List<SectionTime>, startSection: Int): String? {
        val index = startSection - 1
        if (index < 0 || index >= sections.size) return null
        return sections[index].startTime.trim().ifEmpty { null }
    }

    /**
     * 空态判定：一行都没有 = 空态（卡里显示「这天没有安排」+「加课」）。
     *
     * 抽成函数而不是让渲染层写 `rows.isEmpty()`：空态是**用户看得见的一句文案**，
     * 判据若有第二种解释（比如以后要排除某类行），必须改在一个地方。
     */
    fun isEmpty(rows: List<MonthAgendaRow>): Boolean = rows.isEmpty()
}
