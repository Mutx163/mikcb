package com.mutx163.qingyu.pages.timetable.month

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.LocalGlassDockScrollRelief
import com.mutx163.qingyu.components.QingyuBackIconButton
import com.mutx163.qingyu.components.rememberShellShouldShowBackButton
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableChromeBandGlass
import com.mutx163.qingyu.pages.timetable.TimetableTopBar
import com.mutx163.qingyu.pages.timetable.chromeDisplayedPage
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.abs
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import java.time.LocalDate
import java.time.LocalDateTime
import androidx.compose.ui.tooling.preview.Preview
import com.mutx163.qingyu.components.QingyuPageTheme
import java.util.LinkedHashMap

/**
 * 月视图整页壳：**日历卡**（上半）+ **可折叠信息面板**（下半）。
 *
 * 移植自 `lib/screens/month_view_screen.dart`（2026-10-27 的 952 行那版）。那一页
 * 自己的注释把「为什么是这样的结构」写透了，这里只留三条对 Compose 同样成立的：
 *
 * 1. **不是「一个滚动视图把网格和议程串起来」**，而是「网格在上、面板在下」两段式。
 *    用户口径：「上滑 → 上面几行向上收起、下面几行被下面的东西盖起来、底部出现
 *    拉杆；条目视图只支持上下滑（那就是收放）；月份网格支持左右滑（翻月）」。
 * 2. **两个位移同时发生**：网格窗口变矮 **且** 面板变高。只做其中一个，收起后
 *    会露出半格（Dart 2026-10-21 实际踩过）。
 * 3. **面板的列表用户滚动必须关掉**（`userScrollEnabled = false`）：只要面板高度
 *    在同一次手势里变化，`Scrollable` 就会自己被边界判定结束拖动。位移由
 *    [MonthPanelDragArea] 一处算好再落进去（详见那个文件）。
 *
 * ## 本页只管四件事
 *
 * * 聚焦哪个月（工具栏箭头 / 横向手势翻月 / 点邻月补位格）；
 * * 选中哪天（点格子 / 点预览行；再点同一天取消）；
 * * 展开进度（拉杆 / 面板任意位置纵向拖 / 松手吸附）；
 * * 把两半画出来。
 *
 * 数据与导航去处都由宿主注入：网格来自 [MonthGridModel.build]、议程行来自
 * [MonthDayAgendaModel.build]，本页不读 provider。**42 格缓存留在本页**（只留三页，
 * 对应 Dart `MonthViewDataCache`）：横向滑动会同时组合相邻月，交给宿主反而要求
 * 它替我们做缓存。
 *
 * @param gridProvider 给定年月产出 42 格月历。**必须幂等**：本页在年月或
 *   [dataRevision] 变化时重新调用，其余时间复用最近三页的结果。
 * @param agendaProvider 给定日期产出当日议程行（已经排好序）。
 * @param dataRevision 数据版本戳：宿主的数据（课程 / 考试 / 日程）一变就换一个新值，
 *   本页据此丢弃缓存的两份数据。传 null 表示「只在换月时重取」。
 * @param onOpenAgendaRow 点议程行（去课程 / 考试 / 日程的编辑页）。
 * @param onAddCourse 空态卡里的「加课」（带上那天的星期与所在周）。
 */
@Composable
fun MonthViewPage(
    gridProvider: (year: Int, month: Int) -> MonthGrid,
    agendaProvider: (LocalDateTime) -> List<MonthAgendaRow>,
    modifier: Modifier = Modifier,
    initialYear: Int = LocalDate.now().year,
    initialMonth: Int = LocalDate.now().monthValue,
    today: LocalDateTime = LocalDateTime.now(),
    /**
     * 初始选中的日期（null = 进页面不选中）。**只作初值**：之后由点格子 / 点预览行接管，
     * 宿主换页不重设。预览靠它铺「当日议程」两档（静态预览点不了格子）。
     */
    initialSelectedDate: LocalDateTime? = null,
    /**
     * 初始展开进度：1 = 展开（默认，Dart 口径）、0 = 收起。同样**只作初值**，
     * 之后由拖拽 / 吸附接管；预览靠它铺「日历收起」那一档版面。
     */
    initialExpandProgress: Float = 1f,
    dataRevision: Any? = null,
    showWeekNumbers: Boolean = true,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit = {},
    onAddCourse: (LocalDateTime) -> Unit = {},
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    profileName: String? = null,
    showTopBar: Boolean = true,
    /** 把当前聚焦月（只月份，不带年份）回传给宿主，供顶部角格显示。 */
    onMonthLabelChanged: (String) -> Unit = {},
    /** 把月网格里选中的日期回传给宿主，供顶部星期栏显示“选中那一天所在周”的日期。 */
    onSelectedDateChanged: (LocalDateTime?) -> Unit = {},
    /**
     * 非空 = 作为 `c1.week` 的**第三种页内态**渲染（2026-11-07）。
     *
     * 此时本页不再自己搭 `Scaffold`、顶栏玻璃带与壁纸：宿主的顶栏、壁纸、坞都已在
     * 上面一层画好，本页只画「日历卡 + 面板」。这样周 / 日 / 月三种态共用同一张
     * 页面级静态壁纸，翻月/切态不会带动壁纸。
     */
    embedded: Boolean = false,
    /** 顶栏返回键的去处。显隐由根页判据决定（见 `navigationIcon` 传参处）。 */
    onBack: () -> Unit = {},
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
    /**
     * 页面**最底层**的背景槽（首页壁纸，`HomeWallpaperBackdrop`）。与周 / 日视图同一条
     * 层次：非空时页面底色改透明、把这层画在内容下面；为空时行为与旧版一致。
     */
    backdrop: (@Composable BoxScope.() -> Unit)? = null,
    /**
     * 壁纸上的顶栏墨色：`Light` = 浅墨（深色壁纸）、`Dark` = 深墨（浅色壁纸）、
     * `null` = 没有壁纸 ⇒ 主题墨色。判据在宿主侧（`HomeBackgroundModel.chromeInkPolarity`）。
     */
    chromeInk: HomeInkPolarity? = null,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为
     * （顶栏不画玻璃带、页面用不透明主题底）。
     */
    material: HomeMaterialRenderSpec? = null,
    /** 当前有没有可用壁纸；没有时液态档一律回落实体（模糊空气只会得到一块脏灰）。 */
    hasBackdrop: Boolean = false,
    /** 无壁纸 / 实体玻璃带用的页底色（ARGB，来自 `HomeBackdropSnapshot.pageColorArgb`）。 */
    pageColorArgb: Int? = null,
) {
    // ── 状态：翻月 pager + 选中日 + 展开进度 ──
    //
    // 初始进度 1 = 展开：用户没要求记住收起态，进页面看整月是默认预期（Dart 口径）。
    val initialPage = remember(initialYear, initialMonth) {
        MonthPagerModel.pageOf(initialYear, initialMonth)
    }
    val pagerState = rememberPagerState(
        initialPage = initialPage,
        pageCount = { MonthPagerModel.PAGE_COUNT },
    )
    // 聚焦月跟**落定的页**走，不直接读 `currentPage`：手指还按着时那个值在
    // 滑过半页就跳，标题与面板会中途改字。判据复用周视图那条（`chromeDisplayedPage`
    // 已有 JVM 单测）：手势进行中保持上一次落定页，完全停稳后才跟当前页。
    var appliedPage by remember(pagerState) { mutableIntStateOf(initialPage) }
    val focused = MonthPagerModel.monthOfPage(appliedPage)
    val focusedYear = focused.first
    val focusedMonth = focused.second
    var selectedDate by remember { mutableStateOf(initialSelectedDate) }
    LaunchedEffect(selectedDate) {
        onSelectedDateChanged(selectedDate)
    }
    // 展开进度（1 = 展开、0 = 收起）。用普通 Float 状态而不是 `Animatable`：
    // 拖拽中每次指针事件**同步**写入（Compose 快照合并到每帧一次重组），
    // 不再为每个事件 `launch { snapTo() }`（那会排队/掉帧，是收起生硬的根因之一）；
    // 松手吸附用官方 `animate(...)` 一次性驱动（见 onDragEnd）。
    var expandValue by remember {
        mutableFloatStateOf(initialExpandProgress.coerceIn(0f, 1f))
    }
    // 进行中的吸附动画：新一次按下/松手先取消它，避免两条动画抢同一个值。
    var settleJob by remember { mutableStateOf<Job?>(null) }
    // 这次吸附**要去的那一端**（0 或 1）：吸附被新触摸打断时把进度直接补到它，
    // 而不是把动画停在半截（见下方 onDragStart）。
    var settleTargetValue by remember { mutableStateOf<Float?>(null) }
    // 吸附**世代令牌**：每次起吸附 / 每次按下打断都自增。
    //
    // 为什么必须有：`cancel()` 不等待——挂在 `withFrameNanos` 上的取消要**下一帧**才落地，
    // 于是旧 job 的 `finally` 会在新手势的第一发 update **之后**才执行。没有令牌时它会把
    // `expandValue` 写回**旧 target**（一帧回跳）、还会把可能已是新目标的 `settleTargetValue`
    // 清成 null。`finally` 只在自己仍是当前世代时才落端点（2026-11-11 复核指出）。
    var settleGeneration by remember { mutableIntStateOf(0) }
    // 拖拽起点：松手判「翻面还是弹回」的基准（判据在 settleTarget）。
    var dragStart by remember { mutableStateOf(1f) }

    // 数据：只在年月 / 版本戳变化时重取（拖拽期间每帧重算 42 格是纯浪费）。
    val gridSource by rememberUpdatedState(gridProvider)
    val agendaSource by rememberUpdatedState(agendaProvider)
    // 翻月缓存只留三页（Dart `MonthViewDataCache` 同口径）：滑动途中相邻页会被
    // 组合，不缓存就等于每帧重算 42 格。
    val gridCache = remember(dataRevision) { LinkedHashMap<Int, MonthGrid>() }
    val gridForPage: (Int) -> MonthGrid = remember(dataRevision) {
        { page ->
            gridCache[page] ?: run {
                val (year, month) = MonthPagerModel.monthOfPage(page)
                gridSource(year, month).also { built ->
                    if (gridCache.size >= GRID_CACHE_PAGES) {
                        gridCache.remove(gridCache.keys.first())
                    }
                    gridCache[page] = built
                }
            }
        }
    }
    val grid = remember(appliedPage, dataRevision) { gridForPage(appliedPage) }
    val selectedInMonth = selectedDate?.takeIf {
        it.year == focusedYear && it.monthValue == focusedMonth
    }
    val agendaRows = remember(selectedInMonth, dataRevision) {
        selectedInMonth?.let { agendaSource(it) } ?: emptyList()
    }
    val upcoming = remember(grid, today) {
        MonthPanelModel.scheduledDays(grid, today)
    }

    // 翻页落定 → 聚焦月同步**一次**（与周视图 `chromeDisplayedPage` 同一条规则）：
    // 手势 / 吸附进行中保持旧页，停稳后才切换。这里没有第二条「外部周次」跳页
    // 源（`initialYear/initialMonth` 只是初值），所以不需要 `targetPage` 那种防抢。
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage to pagerState.isScrollInProgress }
            .collect { (page, scrolling) ->
                val next = chromeDisplayedPage(page, scrolling, appliedPage)
                if (next != appliedPage) appliedPage = next
            }
    }

    // ── 壁纸 + 顶栏玻璃带（2026-11-01 补，与周 / 日视图同一套）──
    // 之前月视图没有这三层：壁纸不显示、顶栏是一块不透明主题底。用户从周视图
    // 切到月视图会看到壁纸"消失"。
    //   ① 把壁纸层录进 `pageBackdrop`（记录 ≠ 上屏，壁纸照常画）；
    //   ② 顶栏带（状态栏 + 标题行）在带子上采样 + 高斯 + 折射 + 染色。
    val density = LocalDensity.current
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))
    val pageBackdrop = rememberLayerBackdrop()
    // 玻璃带是否「液态档 + 真有壁纸 + 设备支持」：判据与渲染层同一份
    //（`TimetableChromeBandGlass` 里那段 `when`）。这里留一份决定要不要挂录像层。
    val bandBlurActive = material?.band == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    val bandSolidColor = pageColorArgb?.let { Color(it) } ?: scaffoldBg
    val bandOverdrawBaseDp = SettingsMaterialModel.bandGlassOverdrawDp(
        material?.liquidRefractionBand ?: 0f,
    )
    val pageBackdropActive = bandBlurActive

    // ── 拖拽接线：拉杆与面板共用同一份状态 ──
    val scope = rememberCoroutineScope()
    val dragState = remember {
        MonthPanelDragState()
    }

    // ── 纵向滑动诊断（2026-11-11 加）──
    // 只在 dev / bench 包里挂窗口帧监听：正式包里 `attach` 第一行就返回 false，
    // 不采数、不打日志。证据口径与怎么读见 `MonthScrollProbe` 的类注释。
    val probeContext = LocalContext.current
    LaunchedEffect(probeContext) { MonthScrollProbe.attach(probeContext) }

    val isCurrentMonth = focusedYear == today.year && focusedMonth == today.monthValue
    LaunchedEffect(focusedYear, focusedMonth) {
        onMonthLabelChanged(MonthText.monthLabel(focusedMonth))
    }
    // 翻月入口（箭头 / 补位格）统一走 pager：`animateScrollToPage` 会自己把
    // 标题的连续进度喂给工具栏，落定后再由上面的 effect 同步聚焦月。
    val slideToPage: (Int) -> Unit = { page ->
        scope.launch {
            pagerState.animateScrollToPage(
                page.coerceIn(0, MonthPagerModel.PAGE_COUNT - 1),
                animationSpec = MONTH_SLIDE_SPEC,
            )
        }
    }
    // 连点箭头必须**累加目标**，不能读 `currentPage`：动画前半程 currentPage 还没翻页，
    // 第二下会算出同一个目标（用户口径：连点三下只走一个月）。`targetPage` 是动画的
    // 目的地，进行中读它才是「上一跳之后该去的页」。
    val shiftMonth: (Int) -> Unit = { delta ->
        val base = if (pagerState.isScrollInProgress) pagerState.targetPage else pagerState.currentPage
        slideToPage(base + delta)
    }

    // 网格 + 面板的统一出口：正常页面把它放进 Scaffold 的内容区；embedded 模式
    // （c1.week 的第三种页内态）直接把它铺在宿主顶栏下方，不再自己搭壳。
    val renderBody: @Composable (Dp) -> Unit = { bottomInset ->
        MonthViewBody(
            grid = grid,
            gridForPage = gridForPage,
            pagerState = pagerState,
            agendaRows = agendaRows,
            upcoming = upcoming,
            today = today,
            selectedInMonth = selectedInMonth,
            focusedYear = focusedYear,
            focusedMonth = focusedMonth,
            isCurrentMonth = isCurrentMonth,
            expandProgress = { expandValue },
            // 小数页号也走 lambda：组合期读它会让整个 body（含两页 42 格）每帧重组，
            // 见 MonthViewBody 里「卡高在测量阶段才取页号」那段。
            pageValue = {
                pagerState.currentPage.toDouble() +
                    pagerState.currentPageOffsetFraction.toDouble()
            },
            showWeekNumbers = showWeekNumbers,
            showChrome = !embedded,
            innerBottomPadding = bottomInset,
            dragState = dragState,
            onPreviousMonth = { shiftMonth(-1) },
            onNextMonth = { shiftMonth(1) },
            // 三条翻月入口都**只滑、不预置 appliedPage**：聚焦月由落定判据同步（见上面
            // 的 snapshotFlow）。以前先把 appliedPage 写成目标月，于是面板 / 选中态 /
            // 「本月」药丸当帧就换到目标月，卡片却还在旧页——观感是「内容先跳、卡片后到」。
            onBackToCurrentMonth = {
                slideToPage(MonthPagerModel.pageOf(today.year, today.monthValue))
            },
            onDayTap = { date ->
                val page = MonthPagerModel.pageOf(date.year, date.monthValue)
                if (page != appliedPage) {
                    selectedDate = date
                    slideToPage(page)
                } else {
                    selectedDate = if (selectedDate == date) null else date
                }
            },
            onDaySelect = { date -> selectedDate = date },
            onOpenAgendaRow = onOpenAgendaRow,
            onAddCourse = onAddCourse,
            onDragStart = {
                // 先作废在跑的吸附（连同它**迟到的 finally**）：cancel 不等待，令牌才是判据。
                settleGeneration++
                settleJob?.cancel()
                settleJob = null
                // 被打断的吸附**不留半行**（2026-11-11 用户报「收起后卡在两行中间」）：
                // 旧写法只 cancel，进度就冻在动画中途（例如 0.1 ⇒ 窗口 1.5 行、横切行边界）。
                // 现在直接补到它原本要去的那一端，再以那一端作为本次拖拽的起点。
                settleTargetValue?.let { expandValue = it }
                settleTargetValue = null
                dragStart = expandValue
            },
            onDragUpdate = { dy, rowHeightDp, rowCount ->
                expandValue = MonthPanelModel.progressAfterDrag(
                    progress = expandValue.toDouble(),
                    deltaDy = dy.toDouble(),
                    rowHeightDp = rowHeightDp,
                    rowCount = rowCount,
                ).toFloat()
                // 诊断探针：只累加（不打日志、不分配日志字符串），详见 MonthScrollProbe。
                MonthScrollProbe.onDragEvent(dy)
            },
            onDragEnd = { velocityDy ->
                MonthScrollProbe.endDrag(
                    velocityDp = velocityDy.toDouble(),
                    startProgress = dragStart,
                    endProgress = expandValue,
                )
                val target = MonthPanelModel.settleTarget(
                    startValue = dragStart.toDouble(),
                    currentValue = expandValue.toDouble(),
                    velocityDy = velocityDy.toDouble(),
                )
                settleJob?.cancel()
                val generation = ++settleGeneration
                settleTargetValue = target.toFloat()
                settleJob = scope.launch {
                    try {
                        // 吸附曲线：**时长跟着剩余距离走**（70~220ms），而不是固定 260ms。
                        // 固定时长在两头都不对：快甩时前几帧近乎不动（掉一拍），只差
                        // 2% 时又拖了一整拍（过阻尼）。距离越短动画越短，松手即到。
                        val distance = abs(target.toFloat() - expandValue)
                        val durationMs = (SNAP_MS_MIN + SNAP_MS_PER_UNIT * distance)
                            .toInt()
                            .coerceIn(SNAP_MS_MIN, SNAP_MS_MAX)
                        animate(
                            initialValue = expandValue,
                            targetValue = target.toFloat(),
                            animationSpec = tween(
                                durationMillis = durationMs,
                                easing = FastOutSlowInEasing,
                            ),
                        ) { value, _ -> expandValue = value }
                    } finally {
                        // 端点写死放在 finally：正常落定、被新触摸打断、协程被取消都走这里。
                        // ⚠️ **只在本世代才写**：cancel 不等待，旧 job 的 finally 可能迟到一帧，
                        // 那时新手势已经跑过 update 了 —— 让它写就会把进度写回旧 target（一帧回跳）
                        // 并把可能已是新目标的 settleTargetValue 清掉（2026-11-11 复核结论）。
                        if (settleGeneration == generation) {
                            // 浮点残差与中途打断都不会让「收起」停在 1.0001 行或 1.5 行
                            //（几何侧还有一道 `dockedProgress` 兜底）。
                            expandValue = target.toFloat()
                            settleTargetValue = null
                        }
                    }
                }
            },
        )
    }

    if (embedded) {
        // 宿主已经画了状态栏 / 顶栏 / 壁纸；这里只铺网格与面板，底部避让交给
        // `LocalGlassDockScrollRelief`（坞的占位），不重复吃系统内边距。
        //
        // 系统返回：月视图是 c1.week 的第三种**页内态**，返回应该先回周视图，而不是
        // 直接退出 App（宿主给 embedded 页传的 onBack 就是 selectRoot(ROOT_WEEK)）。
        // 这里不画顶栏返回键（宿主顶栏已经有一条），只接管系统返回。
        BackHandler { onBack() }
        renderBody(0.dp)
        return
    }

    Scaffold(
        // 有壁纸时底色必须透明，否则不透明主题底会把壁纸整张盖掉。
        containerColor = if (backdrop == null) scaffoldBg else Color.Transparent,
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize()) {
        // 壁纸层在最底（与周 / 日视图同层次）。没有壁纸时这一行什么也不画。
        if (backdrop != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (pageBackdropActive) Modifier.layerBackdrop(pageBackdrop)
                        else Modifier,
                    ),
            ) {
                backdrop.invoke(this)
            }
        }
        Column(
            modifier = modifier
                .fillMaxSize()
                // 左右吃安全区；顶部**刻意不吃** —— 玻璃带要从 y = 0（状态栏背后）开始，
                // 由带子内部用等高的 Spacer 把标题行顶到状态栏下面（与周 / 日视图同口径）。
                .padding(
                    start = innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    end = innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                ),
        ) {
            // ── 顶栏玻璃带：状态栏 + 标题行 = 同一条带 ──
            // 玻璃层是共享件（`TimetableChromeBandGlass`），与周 / 日视图同一条带；
            // 外溢量还要叠上安全区，否则横屏挖孔时形状边界会落进可见区、读成一条竖折射边。
            TimetableChromeBandGlass(
                material = material,
                hasBackdrop = hasBackdrop,
                backdrop = pageBackdrop,
                solidColor = bandSolidColor,
                overdrawDp = bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                ),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    // 状态栏区域留白：带子画到屏幕最顶，内容仍停在状态栏下面。
                    Spacer(modifier = Modifier.height(innerPadding.calculateTopPadding()))
                    // 顶栏「轻屿课表」+ 右上角「更多」菜单。
                    if (showTopBar) {
                        TimetableTopBar(
                            brand = homeTitleStyle == HomeTitleStyle.BRAND,
                            inkPolarity = chromeInk,
                            profileName = profileName,
                            homeMenuStyle = homeMenuStyle,
                            menuItems = homeMenuItems,
                            onMenuSelect = onHomeMenuSelect,
                            // 「更多」玻璃球的采样源 = 顶栏玻璃带自己在用的那一层（同一个对象）。
                            backdrop = pageBackdrop,
                            // 根页（底栏栈底）不画返回键；从「更多功能」等处推入时画出。
                            navigationIcon = if (rememberShellShouldShowBackButton()) {
                                { QingyuBackIconButton(onBack = onBack) }
                            } else {
                                null
                            },
                        )
                    }
                }
            }
            renderBody(innerPadding.calculateBottomPadding())
        }
        }
    }
}

/** 吸附时长：基础 + 每单位剩余距离，钳在 [SNAP_MS_MIN]..[SNAP_MS_MAX]。 */
private const val SNAP_MS_MIN = 70
private const val SNAP_MS_PER_UNIT = 160
private const val SNAP_MS_MAX = 220

/** 卡顶导航行：只在这一层读页号，滑动时只重组标题。 */
@Composable
private fun MonthNavigatorForPage(
    pageValue: () -> Double,
    isCurrentMonth: Boolean,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onBackToCurrentMonth: () -> Unit,
) {
    val page = pageValue()
    val basePage = MonthPagerModel.pagerPage(page)
    val (baseYear, baseMonth) = MonthPagerModel.monthOfPage(basePage)
    MonthViewToolbar(
        year = baseYear,
        month = baseMonth,
        isCurrentMonth = isCurrentMonth,
        onPreviousMonth = onPreviousMonth,
        onNextMonth = onNextMonth,
        onBackToCurrentMonth = onBackToCurrentMonth,
        pageFraction = MonthPagerModel.pageFraction(page).toFloat(),
    )
}

/** 翻月动画时长（Dart `260.scaledMs`；本仓不做系统速度倍率，取同一基数）。 */
private const val MONTH_SLIDE_MS = 260

/** 翻月缓动：Dart `Curves.easeOutCubic` = cubic-bezier(0.215, 0.61, 0.355, 1)。 */
private val MONTH_SLIDE_SPEC = tween<Float>(
    durationMillis = MONTH_SLIDE_MS,
    easing = CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f),
)

/** 翻月网格缓存页数（Dart `MonthViewDataCache` 只留三页）。 */
private const val GRID_CACHE_PAGES = 3

// 月份切换不需要额外节流：连续快速点箭头时 `PagerState.animateScrollToPage`
// 会从当前位置接续（新的目标覆盖旧的动画），不会叠成一串排队动画。
// 但目标页必须从 `targetPage` 累加，不能读 `currentPage`（见 `shiftMonth`）。

/** 页面主体：把「版面账」与「两半内容」放在同一个有界宽高里算。 */
@Composable
private fun MonthViewBody(
    grid: MonthGrid,
    gridForPage: (Int) -> MonthGrid,
    pagerState: PagerState,
    agendaRows: List<MonthAgendaRow>,
    upcoming: List<MonthDayEntry>,
    today: LocalDateTime,
    selectedInMonth: LocalDateTime?,
    focusedYear: Int,
    focusedMonth: Int,
    isCurrentMonth: Boolean,
    expandProgress: () -> Float,
    /** 小数页号（`currentPage + offsetFraction`）。**只能是 lambda**：组合期读它会让整页逐帧重组。 */
    pageValue: () -> Double,
    showWeekNumbers: Boolean,
    /** 是否画卡内月份行/星期表头；嵌入 c1.week 时为 false（顶部带已经画了）。 */
    showChrome: Boolean,
    /** Scaffold 的底部内边距（系统栏内边距）：与坞避让取 max 去重，不双计。 */
    innerBottomPadding: Dp,
    dragState: MonthPanelDragState,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onBackToCurrentMonth: () -> Unit,
    onDayTap: (LocalDateTime) -> Unit,
    onDaySelect: (LocalDateTime) -> Unit,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit,
    onAddCourse: (LocalDateTime) -> Unit,
    onDragStart: () -> Unit,
    onDragUpdate: (dy: Float, rowHeightDp: Double, rowCount: Int) -> Unit,
    onDragEnd: (velocityDy: Float) -> Unit,
) {
    // 诊断探针：这一层重组意味着拖拽把整页带进了组合（设计上不该发生）。
    // 非诊断包里 `bump` 第一行就返回，保留这个 SideEffect 只为让口径唯一。
    SideEffect { MonthScrollProbe.bump(MonthScrollProbe.C_BODY) }

    androidx.compose.foundation.layout.BoxWithConstraints(
        modifier = Modifier.fillMaxSize(),
    ) {
        val availableWidthDp = maxWidth.value.toDouble()
        val availableHeightDp = maxHeight.value.toDouble()
        // 嵌入态：顶部带已经画了“月份 + 星期”，卡里不再画；周次轨的 40dp 竖槽仍保留，
        // 给顶部角格的月份和网格的周次共用同一条列，列才能对齐。
        val reserveRail = !showChrome
        val weekNumberColumnVisible = reserveRail ||
            (showWeekNumbers && grid.days.any { it.weekIndex != null })
        val headerHeight = if (showChrome) MonthGridMetrics.HEADER_HEIGHT else 0.0
        val cardChrome = if (showChrome) {
            MonthCalendarChrome.CARD_CHROME
        } else {
            MonthCalendarChrome.HANDLE_AREA_HEIGHT
        }
        val keptRow = MonthPanelModel.rowToKeep(
            dates = grid.days.map { it.date },
            year = focusedYear,
            month = focusedMonth,
            selectedDate = selectedInMonth,
            today = today,
        )
        // 拖拽行程按**跨着的两页**里较多的行数算（判据在 `MonthPagerModel.cardRowCount`）：
        // 5 行月挨着 6 行月时行程若用聚焦月的行数，会走不满 / 走过头（差一整行）。
        //
        // 行高与行数**不在组合期算**（也就不会读 pageValue）：拖拽事件发生时才算，
        // 见下方 `dragMetrics()`。

        // ── 版面账：只读同一个函数，只有「读进度的时机」变了（2026-11-05）──
        //
        // 以前组合期直接把 `expandProgress()` 读出来算 3 次 `MonthPanelModel.layout`，
        // 于是每个指针事件都重组整个 `MonthViewBody` + 两页内容；拖动时真正在变的
        // 只有「卡高 / 表格窗口高 / 窗口行数 / 内容位移」这四个量。
        //
        // 现在组合期**一个进度都不读**：几何在 `heightDeferred` 的 measure lambda、
        // `graphicsLayer` 的绘图层里现取；`derivedStateOf` 让同一帧内多次读取只算一遍。
        // 公式、参数、返回的数值与改前**逐位相同**（同一个 `layout(...)`、同一组入参），
        // 变的只有「什么时候读」，所以观感、动画时长、缓动一律未动。
        fun layoutAt(progress: Double, rowCount: Int, weekNumberVisible: Boolean): MonthPanelLayout =
            MonthPanelModel.layout(
                progress = progress,
                availableHeightDp = availableHeightDp,
                availableWidthDp = availableWidthDp,
                headerHeightDp = headerHeight,
                weekLabelWidthDp = MonthGridMetrics.WEEK_LABEL_WIDTH,
                minRowHeightDp = MonthGridMetrics.MIN_ROW_HEIGHT,
                maxRowHeightDp = MonthGridMetrics.MAX_ROW_HEIGHT,
                keptRow = keptRow,
                weekNumberColumnVisible = weekNumberVisible,
                // 卡内非表格开销（导航 + 分隔线 + 拉杆）：嵌入态没有导航/分隔线，只剩拉杆。
                handleHeightDp = cardChrome,
                // 网格外面那层上内边距也算进窗口高度。
                topPaddingDp = MonthMetrics.CARD_PADDING,
                rowCount = rowCount,
            )

        fun layoutCardAt(
            progress: Double,
            rows: Double,
            weekNumberVisible: Boolean,
        ): MonthPanelLayout = MonthPanelModel.layoutExact(
            progress = progress,
            availableHeightDp = availableHeightDp,
            availableWidthDp = availableWidthDp,
            headerHeightDp = headerHeight,
            weekLabelWidthDp = MonthGridMetrics.WEEK_LABEL_WIDTH,
            minRowHeightDp = MonthGridMetrics.MIN_ROW_HEIGHT,
            maxRowHeightDp = MonthGridMetrics.MAX_ROW_HEIGHT,
            keptRow = keptRow,
            weekNumberColumnVisible = weekNumberVisible,
            handleHeightDp = cardChrome,
            topPaddingDp = MonthMetrics.CARD_PADDING,
            rowCount = rows,
        )

        // 卡的那份版面账：**读它才取页号 / 进度**（测量阶段读 → 只失效布局，不重组）。
        //
        // 卡高用**连续**行数：在 4/5/6 行之间按页进度插值，避免“手指刚动 ε 就长高
        // 一整行”与“落定瞬间缩回一整行”。以前把 `cardRowsExact` 当 remember 的 key，
        // 而它在滑动中每帧都变 → derivedStateOf 每帧被丢弃重建，同时把整页也带进重组。
        // 现在页号在 derivedStateOf 内部读，组合期一个页号都不看。
        val cardLayout by remember(
            availableHeightDp, availableWidthDp, keptRow, weekNumberColumnVisible,
        ) {
            derivedStateOf {
                layoutCardAt(
                    progress = expandProgress().toDouble(),
                    rows = MonthPagerModel.cardRows(pageValue()) { page ->
                        gridForPage(page).rowsInMonth
                    },
                    weekNumberVisible = weekNumberColumnVisible,
                )
            }
        }

        // 拖拽用的行高 / 行数：在**事件发生时**按当前页号算（组合期不读页号）。
        // 行程仍按跨页口径：两页行数取较大值，走满 / 不走过头。
        fun dragMetrics(): Pair<Double, Int> {
            val rows = MonthPagerModel.cardRowCount(pageValue()) { page ->
                gridForPage(page).rowsInMonth
            }
            return layoutAt(1.0, rows, weekNumberColumnVisible).rowHeight to rows
        }
        val dragUpdate: (Float) -> Unit = { dy ->
            val (height, rows) = dragMetrics()
            onDragUpdate(dy, height, rows)
        }
        // 手势协程的 key 必须恒定：旧写法 `.pointerInput(rowHeightDp, cardRowCount)` 的两个
        // key 都会随翻月进度变 → 拖动中途协程被取消，onDragEnd / onDragCancel 都不跑，
        // 日历停在半收（看起来像“收起后还剩两行”）。现在改用 rememberUpdatedState 拿最新值。
        val latestDragStart = rememberUpdatedState(onDragStart)
        val latestDragUpdate = rememberUpdatedState(dragUpdate)
        val latestDragEnd = rememberUpdatedState(onDragEnd)

        Column(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = MonthMetrics.CARD_INSET.dp),
            ) {
                MonthCalendarCard(
                    // 卡高 = 表格窗口高 + 卡内非表格开销。两个量都在**测量阶段**才读进度
                    //（`heightDeferred`，等价 `Modifier.height` 的约束语义），拖拽时只重测这一层。
                    modifier = Modifier.heightDeferred {
                        MonthScrollProbe.bump(MonthScrollProbe.C_CARD_MEASURE)
                        (cardLayout.gridHeight + cardChrome).dp
                    },
                    navigator = if (showChrome) {
                        {
                            // 标题跟手指连续滑动（Dart `month_view_toolbar.dart:235-266`
                            // 读 `PageController.page` 的 floor + frac）。读页号的作用域只在
                            // 这个子组件里：滑动时只重组标题行，卡片与网格不跟着重组。
                            MonthNavigatorForPage(
                                pageValue = pageValue,
                                isCurrentMonth = isCurrentMonth,
                                onPreviousMonth = onPreviousMonth,
                                onNextMonth = onNextMonth,
                                onBackToCurrentMonth = onBackToCurrentMonth,
                            )
                        }
                    } else {
                        null
                    },
                    onDragStart = onDragStart,
                    // 行程按**跨页口径**：拖拽行程用两页中较大的行数；卡高用连续行数，
                    // 两者取不同的量是有意的——行程要“走满”，卡高要“不跳”。
                    onDragUpdate = dragUpdate,
                    onDragEnd = onDragEnd,
                    // 卡底拉杆带不在 pager 里：横向手势在那里自己转成翻月。
                    onSwipeLeft = onNextMonth,
                    onSwipeRight = onPreviousMonth,
                ) {
                    // 窗口裁剪在我们这层：MonthGrid 画全部 4~6 行，窗口只露 visible 行，
                    // 超出的部分被裁掉 —— 正是「下面几行被面板盖住」那一半。
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            // 窗口高度 = 版面账里的 gridHeight 减掉上内边距（卡片自己加那段 padding）。
                            .heightDeferred {
                                MonthScrollProbe.bump(MonthScrollProbe.C_GRID_WINDOW_MEASURE)
                                (cardLayout.gridHeight - MonthMetrics.CARD_PADDING)
                                    .coerceAtLeast(0.0).dp
                            }
                            .clipToBounds()
                            // Dart 把纵向拖拽挂在整个日历 PageView 上（`month_view_screen.dart:439-443`），
                            // 不是只挂 26dp 拉杆：在格子上上下滑同样能收放。用触摸斜率判据
                            // （`detectVerticalDragGestures`），点格选日期不会被拖拽抢走；
                            // 与 pager 的横向手势正交，同一手势不会互相抢。
                            .pointerInput(Unit) {
                                // 速度按位移增量采样（见 `DragVelocitySampler`）。网格这层
                                // 上沿不动，`VelocityTracker` 本来也不会反号，但三条入口
                                // 用同一把尺子，免得以后挪动拖拽区又踩回面板那个坑。
                                val sampler = DragVelocitySampler()
                                detectVerticalDragGestures(
                                    onDragStart = {
                                        sampler.reset()
                                        MonthScrollProbe.beginDrag("grid")
                                        latestDragStart.value()
                                    },
                                    onVerticalDrag = { change, dragAmount ->
                                        sampler.add(change.uptimeMillis, dragAmount)
                                        change.consume()
                                        // PointerInputScope 本身就是 Density，直接换 dp；
                                        // 不再把 density / 行高捕获进协程（那会让 key 必须变）。
                                        latestDragUpdate.value(dragAmount.toDp().value)
                                    },
                                    onDragEnd = {
                                        latestDragEnd.value(
                                            sampler.velocityPerSecond().toDp().value,
                                        )
                                    },
                                    onDragCancel = { latestDragEnd.value(0f) },
                                )
                            },
                    ) {
                        HorizontalPager(
                            state = pagerState,
                            // 预组合左右各一页（默认 0）：不预组合时，进页面后的**第一下**
                            // 横滑要现组 42 格，最常见的「第一次滑顿一下」就在这里。
                            beyondViewportPageCount = 1,
                            modifier = Modifier.fillMaxSize(),
                        ) { page ->
                            // 每页用**自己**的行数与保留行算版面：相邻月行数可能不同，
                            // 复用聚焦月那份会让另一页格子高度错一整行（Dart
                            // `_buildGridPage` 同口径）。
                            val (year, month) = MonthPagerModel.monthOfPage(page)
                            val pageGrid = gridForPage(page)
                            val pageSelected = selectedInMonth?.takeIf {
                                it.year == year && it.monthValue == month
                            }
                            val pageKeptRow = MonthPanelModel.rowToKeep(
                                dates = pageGrid.days.map { it.date },
                                year = year,
                                month = month,
                                selectedDate = pageSelected,
                                today = today,
                            )
                            val pageRows = pageGrid.rowsInMonth
                            val pageWeekNumberVisible = reserveRail ||
                                (showWeekNumbers && pageGrid.days.any { it.weekIndex != null })
                            // 这一页的版面账：同样「读它才取进度」（测量 / 绘制阶段），
                            // 几何仍是同一个 `layoutAt`，参数与改前逐项一致。
                            val pageLayout by remember(
                                availableHeightDp,
                                availableWidthDp,
                                pageKeptRow,
                                pageRows,
                                pageWeekNumberVisible,
                            ) {
                                derivedStateOf {
                                    layoutAt(
                                        progress = expandProgress().toDouble(),
                                        rowCount = pageRows,
                                        weekNumberVisible = pageWeekNumberVisible,
                                    )
                                }
                            }
                            // 该页行高与进度无关（见上方 `rowHeightDp` 的说明），组合期取一次。
                            val pageRowHeightDp = remember(
                                availableHeightDp, availableWidthDp, pageRows, pageWeekNumberVisible,
                            ) {
                                layoutAt(1.0, pageRows, pageWeekNumberVisible).rowHeight
                            }.dp
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .heightDeferred {
                                        MonthScrollProbe.bump(MonthScrollProbe.C_GRID_WINDOW_MEASURE)
                                        (pageLayout.gridHeight - MonthMetrics.CARD_PADDING)
                                            .coerceAtLeast(0.0).dp
                                    }
                                    .clipToBounds(),
                            ) {
                                MonthGrid(
                                    grid = pageGrid,
                                    today = today,
                                    selectedDate = pageSelected,
                                    onDayTap = onDayTap,
                                    rowHeight = pageRowHeightDp,
                                    showHeader = showChrome,
                                    reserveRail = reserveRail,
                                    // 窗口行数（含小数）跟着展开进度走：收起只露 1 行，
                                    // 拖拽时连续变化；MonthGrid 内部据此裁剪、内容整体上移。
                                    // 两个都是 lambda：值在测量 / 绘制阶段才读（组合期不读进度）。
                                    visibleRows = { pageLayout.visibleRows.toFloat() },
                                    rowOffset = { pageLayout.scrollOffset.dp },
                                    showWeekNumbers = showWeekNumbers,
                                )
                            }
                        }
                    }
                }
            }

            // ── 下半：信息面板（概览态填满 / 议程态可滚）──
            MonthPanelDragArea(
                state = dragState,
                modifier = Modifier.weight(1f),
            ) {
                MonthPanelContent(
                    grid = grid,
                    agendaRows = agendaRows,
                    upcoming = upcoming,
                    selectedInMonth = selectedInMonth,
                    innerBottomPadding = innerBottomPadding,
                    dragState = dragState,
                    onDaySelect = onDaySelect,
                    onOpenAgendaRow = onOpenAgendaRow,
                    onAddCourse = onAddCourse,
                )
            }
        }

        // 接线在重组时刷新：拖拽回调闭包捕获的是**这一帧**的行高与状态读取器。
        // 走 `SideEffect`（与同文件 `MonthPanelContent` 里 `dragState.listState = …` 同一写法）：
        // 组合期只描述 UI、不写外部状态，真正的赋值放到这一帧提交之后。
        SideEffect {
            dragState.gridCanAbsorb = { dy ->
                if (dy < 0) {
                    expandProgress() > 0f
                } else if (dy > 0) {
                    expandProgress() < 1f
                } else {
                    false
                }
            }
            dragState.onCollapseStart = onDragStart
            // 行程同样按跨页口径（与卡高、拉杆两处一致）。
            dragState.onCollapseUpdate = { dy -> dragUpdate(dy) }
            dragState.onCollapseEnd = onDragEnd
        }
    }
}

/**
 * 面板内容：**没选中日期**走概览（填满高度、不滚动），**选中了**走当日议程
 * （自然高度、可滚）。
 *
 * 两支的滚动策略不同是 Dart 侧踩出来的结论：
 * * 概览态的内容按可用高度反算行数，天然不会溢出，**不需要滚动视图**
 *   （那种树上 `ScrollController` 没有 clients，无条件 `jumpTo` 会断言失败）；
 * * 议程态可能有十几节课，高度不可预知，必须能滚；但它不能走「填满」那条路，
 *   否则短议程会被拉出一堆空白。
 */
@Composable
private fun MonthPanelContent(
    grid: MonthGrid,
    agendaRows: List<MonthAgendaRow>,
    upcoming: List<MonthDayEntry>,
    selectedInMonth: LocalDateTime?,
    innerBottomPadding: Dp,
    dragState: MonthPanelDragState,
    onDaySelect: (LocalDateTime) -> Unit,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit,
    onAddCourse: (LocalDateTime) -> Unit,
) {
    // 诊断探针：拖拽时这一层应为 0 次；跟着帧数长说明面板每帧都在重组。
    SideEffect { MonthScrollProbe.bump(MonthScrollProbe.C_PANEL_COMPOSE) }

    // 底部避让：取「设计留白 / Scaffold 系统栏内边距 / 共享坞避让」三者**最大**值去重
    //（不相加，系统导航条不双计；口径与列表页 / 日 / 周视图一致）。
    // 之前月视图这套自定义滚动漏了坞避让，议程最后一行一直停在底部导航栏（坞）后面、
    // 无法再上滑露出 —— 这就是「最底下内容被坞遮挡」的根因。
    val dockRelief = LocalGlassDockScrollRelief.current
    val bottomInset = maxOf(
        MonthMetrics.PANEL_BOTTOM_INSET.dp,
        innerBottomPadding,
        dockRelief,
    )
    val padding = PaddingValues(
        start = MonthMetrics.CARD_INSET.dp,
        end = MonthMetrics.CARD_INSET.dp,
        top = MonthMetrics.ITEM_GAP.dp,
        // 底部留白：玻璃坞药丸悬在它上面，滚到底时最后一张卡不被压住。
        bottom = bottomInset,
    )

    if (selectedInMonth == null) {
        // 概览态：没有滚动视图 → 位移全部归网格收放（判据自己会得到这个结论）。
        SideEffect { dragState.listState = null }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            MonthPanelOverview(
                grid = grid,
                upcoming = upcoming,
                onDayTap = onDaySelect,
                fillHeight = true,
            )
        }
        return
    }

    // 议程态：列表只作容器，用户滚动关掉（位移由 MonthPanelDragArea 落进来）。
    val listState = rememberLazyListState()
    SideEffect { dragState.listState = listState }
    // 换了一天就把列表滚回顶部：否则在概览里滚到 240dp 再点某天，议程会从半截开始
    //（Dart 2026-10-22 实测：14 节课时面板停在 240dp，标题已在屏幕外）。
    LaunchedEffect(selectedInMonth) {
        listState.scrollToItem(0)
    }

    LazyColumn(
        state = listState,
        userScrollEnabled = false,
        modifier = Modifier.fillMaxSize(),
        contentPadding = padding,
    ) {
        item(key = "agenda") {
            MonthDayAgenda(
                date = selectedInMonth,
                rows = agendaRows,
                onRowTap = onOpenAgendaRow,
                onAddCourse = { onAddCourse(selectedInMonth) },
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（@Preview）
//
// 一个 @Preview 一个状态，按「最常看 → 最少看」排：
//
//   1 有安排          网格圆点 + 本月概览统计 + 有安排的日子预览行
//   2 空课表          整月没有任何安排（概览空态卡）
//   3 选中日·有议程    课程 / 考试 / 日程三种行同屏（色条、钟点、箭头都在这）
//   4 选中日·无安排    当天空态（说明 + 加课入口），与「整月空」不是同一段
//   5 日历收起        网格只留一行、面板变高走的是另一套版面账
//   6 暗色            卡面与墨色走主题的另一支
//   7 大字号 1.3      最窄的「第 N 周」列与议程行先被挤掉，用议程态验折行
//
// 数据走**真链路**：`MonthViewDataSource` → `MonthGridModel` / `MonthDayAgendaModel`，
// 42 格与议程行都由真模型算，不手写、也不在这里另写一份 provider 参数。
// 学期固定 2026-09-07 开学、今天固定 2026-11-08（周日 · 第 9 周）。
//
// **看不到的**：翻月滑动与拖拽收放的**过程**（静态预览只给落点），要验靠 Studio
// 交互模式或真机。主题一律 `QingyuPageTheme(isDark = …)`、字号一律 `textScale = …`，
// 宽度 400dp，与本仓其它页面预览同口径。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用学期：2026-09-07（周一）开学 ⇒ 2026-11-08 落在第 9 周。 */
private val previewSemesterStart: LocalDateTime = LocalDateTime.of(2026, 9, 7, 0, 0)

/** 预览用「此刻」：2026-11-08（周日）10:00——今天高亮、「本月」药丸、考试过期都按它判。 */
private val previewToday: LocalDateTime = LocalDateTime.of(2026, 11, 8, 10, 0)

/** 预览用作息表：直接用内置模板，课程的起止钟点也从这份表里取，不另写一套时间。 */
private val previewSections: List<com.mutx163.qingyu.core.SectionTime> =
    com.mutx163.qingyu.core.TimetableSettings.DEFAULT_SECTIONS

/** 预览用一门课：起止钟点由节次从 [previewSections] 取，保证「第几节 = 几点」与真机同源。 */
private fun previewCourse(
    name: String,
    teacher: String,
    location: String,
    dayOfWeek: Int,
    startSection: Int,
    endSection: Int,
    color: String,
): com.mutx163.qingyu.core.Course = com.mutx163.qingyu.core.Course(
    id = "preview-course-$dayOfWeek-$startSection",
    name = name,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = previewSections[startSection - 1].startTime,
    endTime = previewSections[endSection - 1].endTime,
    color = color,
    startWeek = 1,
    endWeek = 18,
)

/** 预览用课程：周一到周五都有课，周四两段（含晚上），11 月每周都能看到圆点。 */
private val previewCourses: List<com.mutx163.qingyu.core.Course> = listOf(
    previewCourse("高等数学", "张明", "示例大学 A101", 1, 1, 2, "#3B82F6"),
    previewCourse("大学英语", "李颖", "示例大学 B204", 1, 3, 4, "#F59E0B"),
    previewCourse("大学物理", "李海", "示例大学 B203", 2, 3, 4, "#8B5CF6"),
    previewCourse("线性代数", "王静", "示例大学 A108", 3, 1, 2, "#10B981"),
    previewCourse("程序设计基础", "陈晨", "实验楼 C301", 4, 5, 6, "#F97316"),
    previewCourse("数据结构", "陈晨", "实验楼 C302", 4, 9, 10, "#06B6D4"),
)

/** 预览用考试：两场都还没过期（今天 11-08），网格角标与议程的考试红都靠它。 */
private val previewExams: List<com.mutx163.qingyu.core.Exam> = listOf(
    com.mutx163.qingyu.core.Exam(
        id = "preview-exam-math",
        courseId = "preview-course-1-1",
        name = "高等数学 · 期中考试",
        dateTime = LocalDateTime.of(2026, 11, 12, 0, 0),
        startTime = "10:00",
        endTime = "11:40",
        location = "教三 305",
        createdAt = previewToday,
        updatedAt = previewToday,
    ),
    com.mutx163.qingyu.core.Exam(
        id = "preview-exam-physics",
        courseId = "preview-course-2-3",
        name = "大学物理 · 期中考试",
        dateTime = LocalDateTime.of(2026, 11, 19, 0, 0),
        startTime = "14:00",
        endTime = "15:40",
        location = "教二 201",
        createdAt = previewToday,
        updatedAt = previewToday,
    ),
)

/** 预览用日程：一条每周重复（周四 19:00，和「数据结构」同钟点）+ 一条单次。 */
private val previewScheduleItems: List<com.mutx163.qingyu.core.ScheduleItem> = listOf(
    com.mutx163.qingyu.core.ScheduleItem(
        id = "preview-schedule-meeting",
        title = "实验室组会",
        location = "实验楼 C305",
        startDate = LocalDateTime.of(2026, 9, 17, 0, 0),
        endDate = LocalDateTime.of(2026, 12, 31, 0, 0),
        startTime = "19:00",
        endTime = "20:00",
        color = "#8E44AD",
        createdAt = previewToday,
        updatedAt = previewToday,
        recurrence = com.mutx163.qingyu.core.ScheduleRecurrence.WEEKLY,
    ),
    com.mutx163.qingyu.core.ScheduleItem(
        id = "preview-schedule-library",
        title = "图书馆自习",
        location = "图书馆 4 层",
        startDate = LocalDateTime.of(2026, 11, 14, 0, 0),
        endDate = LocalDateTime.of(2026, 11, 14, 0, 0),
        startTime = "09:00",
        endTime = "12:00",
        color = "#0EA5E9",
        createdAt = previewToday,
        updatedAt = previewToday,
    ),
)

/**
 * 一档预览的公共身体：数据状态 + 选中日 + 展开进度 + 外观档位。
 *
 * 两个 provider 由 [MonthViewDataSource] 现造（开学日 / 节次表 / 考试过期的取法
 * 与生产完全同一条路径），预览里不另写一份 `MonthGridModel.build(...)` 参数。
 */
@Composable
private fun PreviewMonthViewPage(
    courses: List<com.mutx163.qingyu.core.Course> = previewCourses,
    exams: List<com.mutx163.qingyu.core.Exam> = previewExams,
    scheduleItems: List<com.mutx163.qingyu.core.ScheduleItem> = previewScheduleItems,
    selectedDate: LocalDateTime? = null,
    expandProgress: Float = 1f,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    val source = remember(courses, exams, scheduleItems) {
        MonthViewDataSource(
            snapshot = com.mutx163.qingyu.app.TimetableSnapshot(
                courses = courses,
                scheduleItems = scheduleItems,
                settings = com.mutx163.qingyu.core.TimetableSettings(
                    sections = previewSections,
                    semesterStartDate = previewSemesterStart,
                ),
                currentWeek = 9,
                semesterStartEpochDay = previewSemesterStart.toLocalDate().toEpochDay(),
            ),
            now = previewToday,
            exams = exams,
        )
    }
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        MonthViewPage(
            gridProvider = source::grid,
            agendaProvider = source::agenda,
            initialYear = 2026,
            initialMonth = 11,
            today = previewToday,
            initialSelectedDate = selectedDate,
            initialExpandProgress = expandProgress,
            dataRevision = source.revision,
            // 预览里点不了，但参数留着：不传就是默认空实现，这里显式写明不做去处。
            onOpenAgendaRow = {},
            onAddCourse = {},
            onMonthLabelChanged = {},
            onSelectedDateChanged = {},
        )
    }
}

// ── 单档：内容状态（亮色）──────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有安排", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewBusy() {
    PreviewMonthViewPage()
}

@Suppress("unused")
@Preview(name = "2 空课表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewEmpty() {
    PreviewMonthViewPage(
        courses = emptyList(),
        exams = emptyList(),
        scheduleItems = emptyList(),
    )
}

@Suppress("unused")
@Preview(name = "3 选中日·有议程", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewAgenda() {
    // 11-12（周四）：考试 + 下午课 + 晚上的课与组会（同钟点两行）。
    PreviewMonthViewPage(selectedDate = LocalDateTime.of(2026, 11, 12, 0, 0))
}

@Suppress("unused")
@Preview(name = "4 选中日·无安排", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewAgendaEmpty() {
    // 11-15（周日）：当天没有课 / 考试 / 日程 ⇒ 议程卡空态（说明 + 加课）。
    PreviewMonthViewPage(selectedDate = LocalDateTime.of(2026, 11, 15, 0, 0))
}

@Suppress("unused")
@Preview(name = "5 日历收起", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewCollapsed() {
    PreviewMonthViewPage(expandProgress = 0f)
}

// ── 单档：外观（以内容最全的两档为基准）──────────────────────────────────

@Suppress("unused")
@Preview(name = "6 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewDark() {
    PreviewMonthViewPage(dark = true)
}

@Suppress("unused")
@Preview(name = "7 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MonthViewPagePreviewLargeText() {
    // 用议程态验折行：钟点列 + 标题/副行是这一页最窄的两段。
    PreviewMonthViewPage(
        selectedDate = LocalDateTime.of(2026, 11, 12, 0, 0),
        textScale = 1.3f,
    )
}
