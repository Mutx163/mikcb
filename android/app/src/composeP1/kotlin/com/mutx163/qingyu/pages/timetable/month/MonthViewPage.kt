package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableChromeBandGlass
import com.mutx163.qingyu.pages.timetable.TimetableTopBar
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import java.time.LocalDate
import java.time.LocalDateTime

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
 * * 聚焦哪个月（工具栏 / 点邻月补位格）；
 * * 选中哪天（点格子 / 点预览行；再点同一天取消）；
 * * 展开进度（拉杆 / 面板任意位置纵向拖 / 松手吸附）；
 * * 把两半画出来。
 *
 * 数据与导航去处都由宿主注入：网格来自 [MonthGridModel.build]、议程行来自
 * [MonthDayAgendaModel.build]，本页不读 provider（Dart 侧的 provider 订阅与
 * 42 格缓存是宿主的事）。
 *
 * @param gridProvider 给定年月产出 42 格月历。**必须幂等**：本页在年月或
 *   [dataRevision] 变化时重新调用，其余时间复用上次结果。
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
    dataRevision: Any? = null,
    showWeekNumbers: Boolean = true,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit = {},
    onAddCourse: (LocalDateTime) -> Unit = {},
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    profileName: String? = null,
    showTopBar: Boolean = true,
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
    // ── 状态：聚焦月 + 选中日 + 展开进度 ──
    //
    // 初始进度 1 = 展开：用户没要求记住收起态，进页面看整月是默认预期（Dart 口径）。
    var focusedYear by remember { mutableIntStateOf(initialYear) }
    var focusedMonth by remember { mutableIntStateOf(initialMonth) }
    var selectedDate by remember { mutableStateOf<LocalDateTime?>(null) }
    val expand = remember { Animatable(1f) }
    // 拖拽起点：松手判「翻面还是弹回」的基准（判据在 settleTarget）。
    var dragStart by remember { mutableStateOf(1f) }

    // 数据：只在年月 / 版本戳变化时重取（拖拽期间每帧重算 42 格是纯浪费）。
    val gridSource by rememberUpdatedState(gridProvider)
    val agendaSource by rememberUpdatedState(agendaProvider)
    val grid = remember(focusedYear, focusedMonth, dataRevision) {
        gridSource(focusedYear, focusedMonth)
    }
    val selectedInMonth = selectedDate?.takeIf {
        it.year == focusedYear && it.monthValue == focusedMonth
    }
    val agendaRows = remember(selectedInMonth, dataRevision) {
        selectedInMonth?.let { agendaSource(it) } ?: emptyList()
    }
    val upcoming = remember(grid, today) {
        MonthPanelModel.scheduledDays(grid, today)
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

    val isCurrentMonth = focusedYear == today.year && focusedMonth == today.monthValue
    val shiftMonth: (Int) -> Unit = { delta ->
        // 用 Calendar 语义做年月进位，避免 12 月 +1 后出现「13 月」。
        val base = LocalDate.of(focusedYear, focusedMonth, 1).plusMonths(delta.toLong())
        focusedYear = base.year
        focusedMonth = base.monthValue
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
                        )
                    }
                }
            }
            MonthViewBody(
                grid = grid,
                agendaRows = agendaRows,
                upcoming = upcoming,
                today = today,
                selectedInMonth = selectedInMonth,
                focusedYear = focusedYear,
                focusedMonth = focusedMonth,
                isCurrentMonth = isCurrentMonth,
                expandProgress = { expand.value },
                showWeekNumbers = showWeekNumbers,
                dragState = dragState,
                onPreviousMonth = { shiftMonth(-1) },
                onNextMonth = { shiftMonth(1) },
                onBackToCurrentMonth = {
                    focusedYear = today.year
                    focusedMonth = today.monthValue
                },
                onDayTap = { date ->
                    if (date.year != focusedYear || date.monthValue != focusedMonth) {
                        // 点到邻月补位格：翻到那个月再选中它（否则点了什么都不发生）。
                        focusedYear = date.year
                        focusedMonth = date.monthValue
                        selectedDate = date
                    } else {
                        // 再点同一天 = 取消选中（与「点同一档 Tab 收起」同口径）。
                        selectedDate = if (selectedDate == date) null else date
                    }
                },
                onDaySelect = { date -> selectedDate = date },
                onOpenAgendaRow = onOpenAgendaRow,
                onAddCourse = onAddCourse,
                onDragStart = {
                    // 手指按下即接管：停掉正在跑的吸附动画，记下起点。
                    dragStart = expand.value
                    scope.launch { expand.stop() }
                },
                onDragUpdate = { dy, rowHeightDp ->
                    scope.launch {
                        expand.snapTo(
                            MonthPanelModel.progressAfterDrag(
                                progress = expand.value.toDouble(),
                                deltaDy = dy.toDouble(),
                                rowHeightDp = rowHeightDp,
                            ).toFloat(),
                        )
                    }
                },
                onDragEnd = { velocityDy ->
                    val target = MonthPanelModel.settleTarget(
                        startValue = dragStart.toDouble(),
                        currentValue = expand.value.toDouble(),
                        velocityDy = velocityDy.toDouble(),
                    )
                    scope.launch {
                        expand.animateTo(
                            targetValue = target.toFloat(),
                            animationSpec = tween(
                                durationMillis = GRID_COLLAPSE_MS,
                                easing = FastOutSlowInEasing,
                            ),
                        )
                    }
                },
            )
        }
        }
    }
}

/** 吸附动画时长（Dart `_kGridCollapseBaseMs`）。 */
private const val GRID_COLLAPSE_MS = 260

/**
 * 月份切换不需要额外节流：连续快速点箭头时 `Animatable` 会自己接续
 * （新的目标覆盖旧的动画）。
 */

/** 页面主体：把「版面账」与「两半内容」放在同一个有界宽高里算。 */
@Composable
private fun MonthViewBody(
    grid: MonthGrid,
    agendaRows: List<MonthAgendaRow>,
    upcoming: List<MonthDayEntry>,
    today: LocalDateTime,
    selectedInMonth: LocalDateTime?,
    focusedYear: Int,
    focusedMonth: Int,
    isCurrentMonth: Boolean,
    expandProgress: () -> Float,
    showWeekNumbers: Boolean,
    dragState: MonthPanelDragState,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onBackToCurrentMonth: () -> Unit,
    onDayTap: (LocalDateTime) -> Unit,
    onDaySelect: (LocalDateTime) -> Unit,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit,
    onAddCourse: (LocalDateTime) -> Unit,
    onDragStart: () -> Unit,
    onDragUpdate: (dy: Float, rowHeightDp: Double) -> Unit,
    onDragEnd: (velocityDy: Float) -> Unit,
) {
    androidx.compose.foundation.layout.BoxWithConstraints(
        modifier = Modifier.fillMaxSize(),
    ) {
        val availableWidthDp = maxWidth.value.toDouble()
        val availableHeightDp = maxHeight.value.toDouble()
        val progress = expandProgress().toDouble()
        val keptRow = MonthPanelModel.rowToKeep(
            dates = grid.days.map { it.date },
            year = focusedYear,
            month = focusedMonth,
            selectedDate = selectedInMonth,
            today = today,
        )
        val layout = MonthPanelModel.layout(
            progress = progress,
            availableHeightDp = availableHeightDp,
            availableWidthDp = availableWidthDp,
            headerHeightDp = MonthGridMetrics.HEADER_HEIGHT,
            weekLabelWidthDp = MonthGridMetrics.WEEK_LABEL_WIDTH,
            minRowHeightDp = MonthGridMetrics.MIN_ROW_HEIGHT,
            maxRowHeightDp = MonthGridMetrics.MAX_ROW_HEIGHT,
            keptRow = keptRow,
            // 学期没配置时周次列整列不画：判据与 MonthGrid 内部同源（全 null = 不占位）。
            weekNumberColumnVisible = showWeekNumbers && grid.days.any { it.weekIndex != null },
            // 卡内非表格开销（导航 + 分隔线 + 拉杆）：与卡自己同一个常量，少扣就溢出。
            handleHeightDp = MonthCalendarChrome.CARD_CHROME,
            // 网格外面那层上内边距也算进窗口高度。
            topPaddingDp = MonthMetrics.CARD_PADDING,
            rowCount = grid.rowsInMonth,
        )

        val rowHeightDp = layout.rowHeight
        // 网格窗口高度 = 版面账里的 gridHeight 减掉上内边距（卡片自己加那段 padding）。
        val gridWindowHeightDp =
            (layout.gridHeight - MonthMetrics.CARD_PADDING).coerceAtLeast(0.0)
        val cardHeightDp = layout.gridHeight + MonthCalendarChrome.CARD_CHROME

        Column(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = MonthMetrics.CARD_INSET.dp),
            ) {
                MonthCalendarCard(
                    modifier = Modifier.height(cardHeightDp.dp),
                    navigator = {
                        MonthViewToolbar(
                            year = focusedYear,
                            month = focusedMonth,
                            isCurrentMonth = isCurrentMonth,
                            onPreviousMonth = onPreviousMonth,
                            onNextMonth = onNextMonth,
                            onBackToCurrentMonth = onBackToCurrentMonth,
                        )
                    },
                    onDragStart = onDragStart,
                    onDragUpdate = { dy -> onDragUpdate(dy, rowHeightDp) },
                    onDragEnd = onDragEnd,
                ) {
                    // 窗口裁剪在我们这层：MonthGrid 画全部 4~6 行，窗口只露 visible 行，
                    // 超出的部分被裁掉 —— 正是「下面几行被面板盖住」那一半。
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(gridWindowHeightDp.dp)
                            .clipToBounds(),
                    ) {
                        MonthGrid(
                            grid = grid,
                            today = today,
                            selectedDate = selectedInMonth,
                            onDayTap = onDayTap,
                            rowHeight = rowHeightDp.dp,
                            visibleRows = grid.rowsInMonth,
                            rowOffset = layout.scrollOffset.dp,
                            showWeekNumbers = showWeekNumbers,
                        )
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
                    dragState = dragState,
                    onDaySelect = onDaySelect,
                    onOpenAgendaRow = onOpenAgendaRow,
                    onAddCourse = onAddCourse,
                )
            }
        }

        // 接线在重组时刷新：拖拽回调闭包捕获的是**这一帧**的行高与状态读取器。
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
        dragState.onCollapseUpdate = { dy -> onDragUpdate(dy, rowHeightDp) }
        dragState.onCollapseEnd = onDragEnd
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
    dragState: MonthPanelDragState,
    onDaySelect: (LocalDateTime) -> Unit,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit,
    onAddCourse: (LocalDateTime) -> Unit,
) {
    val padding = PaddingValues(
        start = MonthMetrics.CARD_INSET.dp,
        end = MonthMetrics.CARD_INSET.dp,
        top = MonthMetrics.ITEM_GAP.dp,
        // 底部留白：玻璃坞药丸悬在它上面，滚到底时最后一张卡不被压住。
        bottom = MonthMetrics.PANEL_BOTTOM_INSET.dp,
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
