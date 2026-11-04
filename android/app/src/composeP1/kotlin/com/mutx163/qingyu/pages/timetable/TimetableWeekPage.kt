package com.mutx163.qingyu.pages.timetable

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.BackToTodayFab
import com.mutx163.qingyu.components.FAB_SHADOW_REACH_DP
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.timetable.day.DayViewDataAssembler
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayGlassBackdrop
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayWallpaperBackdrop
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayTransitionSettled
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.max
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime
import kotlin.math.roundToInt

/**
 * 课表周视图完整页面（对应 Flutter `lib/screens/timetable_screen.dart` 的周视图部分）。
 *
 * ## 2026-10-29 重做的四个决定
 *
 * 1. **不画自造空态**：旧版在「本周无课」时盖一张卡「本周没有排课 / 点击空白格子…」。
 *    Dart 周网格没有空态（`grep 本周没有排课 lib/` = 0），无课就是一张空白网格。
 * 2. **节高按设置 + 自动充满**：`weekSectionHeight` 走
 *    `settings.timetableAutoFitSectionHeight`（Dart `gridSectionHeight`），
 *    旧版永远用宿主注入的固定值。
 * 3. **「回本周」浮钮**：当浏览的周 ≠ 按开学日算出的真实周时出现（Dart
 *    `_shouldShowFloatingBackToCurrentWeekButton`），点它跳回本周。
 * 4. **设置全部下传**：卡面字段/字号/材质/冲突开关/时间列显示档/星期栏字色都由
 *    [WeekViewStyle] 决定，页面不再写死。
 *
 * ## 已知未复刻（见 `docs/plans/2026-10-29-compose-week-view-audit.md` §六）
 *
 * 壁纸 / 玻璃坞 / 课卡天气行已由宿主接上；周↔日已有**锚点窗口展开**
 *（2026-11-02，见下方 `dayMode`）；逐卡飞行、月视图飞行动效尚未复刻。
 * 仍未接：下拉快捷导入（`homePull`）、情侣课表叠加。
 */
@Composable
fun TimetableWeekPage(
    courses: List<Course> = emptyList(),
    timeScheme: TimeScheme? = null,
    settings: TimetableSettings = TimetableSettings.defaults(),
    style: WeekViewStyle = WeekViewStyle(),
    profileName: String = "",
    currentWeek: Int = 1,
    totalWeeks: Int = 20,
    initialWeek: Int = currentWeek,
    visibleDays: List<Int> = (1..7).toList(),
    exams: List<Exam> = emptyList(),
    scheduleItems: List<ScheduleItem> = emptyList(),
    now: LocalDateTime = LocalDateTime.now(),
    todayDate: LocalDate = now.toLocalDate(),
    onCourseClick: (Course) -> Unit = {},
    onAgendaClick: (WeekAgendaCardModel) -> Unit = {},
    /**
     * 某周某天是否假期（Dart `timetable_day_column.dart:76` `provider.isHoliday(date)`）。
     *
     * 2026-10-29 二轮修复：以前 `TimetableWeekGrid.holidayForDay` 全仓没有调用方，
     * 恒 `{ false }` ⇒ 假期课卡既不压淡、也没有「假」角标。
     */
    holidayOf: (week: Int, dayOfWeek: Int) -> Boolean = { _, _ -> false },
    /**
     * 某天某节课的天气一行（Dart `weather: callbacks.weather(item, date)`）。
     *
     * 为 null（宿主没接天气）或返回 null（设置关 / 没数据）时卡面不出现天气行。
     */
    weatherOf: ((week: Int, dayOfWeek: Int, Course) -> String?)? = null,
    onLongPressEmptySlot: (dayOfWeek: Int, section: Int) -> Unit = { _, _ -> },
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onSwitchProfileClick: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
    /**
     * 页面**最底层**的背景槽（首页壁纸，`HomeWallpaperBackdrop`）。
     *
     * 非空时页面底色改透明、把这层画在内容下面 —— 对应 Dart `TimetableHomeStack`
     * 的层次（壁纸 → 状态栏遮罩 → 内容）：有壁纸时 `scaffoldBackgroundColor` 也是
     * `Colors.transparent`（`lib/ui/home/home_chrome_spec.dart:126-128`）。
     *
     * 为空时行为与旧版完全一致（不透明主题底）。壁纸数据由宿主 `TimetableHost`
     * 从用户存档建快照后传进来，本页不读设置。
     */
    backdrop: (@Composable BoxScope.() -> Unit)? = null,
    /**
     * 壁纸上的顶栏墨色：`Light` = 浅墨（深色壁纸）、`Dark` = 深墨（浅色壁纸）、
     * `null` = 没有壁纸 ⇒ 走主题墨色（旧行为）。
     *
     * 判据不在这里算：宿主用壁纸顶部亮度过
     * [com.mutx163.qingyu.pages.shell.HomeBackgroundModel] 的 `chromeInkPolarity`
     * （阈值与 Dart `homePageChromeForegroundForLuminance` 一致，0.45）。
     */
    chromeInk: HomeInkPolarity? = null,
    /**
     * 壁纸三档亮度带（顶栏 / 星期栏 / 正文）。**压在壁纸上的字色**靠它决定深墨还是浅墨：
     * 星期栏用 `weekday` 那档、时间列用 `body` 那档（Dart `homePageOverWallpaperInk`
     * 的同一口径，见 [com.mutx163.qingyu.pages.shell.HomeBackgroundModel.inkOverWallpaperArgb]）。
     * `null` = 没有壁纸 / 亮度还没量到 ⇒ 保持设置 / 主题里的原色（旧行为）。
     */
    wallpaperBands: HomeBackgroundModel.InkBands? = null,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。null = 老行为
     * （顶栏不画带、课卡按 [WeekViewStyle.surfaceStyle] 的旧透明度）。
     *
     * 页面**不读设置**：哪一档、多大模糊 / 染色由模型层算好，这里只执行。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 当前有没有可用壁纸。顶栏玻璃带与课卡液态档都只有在壁纸之上才值得采样
     * （没有壁纸时 Dart `homePageHeaderUsesFrostedChrome` 恒 false、课卡也一律回落实体）。
     */
    hasBackdrop: Boolean = false,
    /**
     * 无壁纸 / 实体玻璃带用的页底色（ARGB，来自 `HomeBackdropSnapshot.pageColorArgb`）。
     * null = 主题兜底色（老行为）。不传的话「课表页背景色板」选的自定义色会在
     * 顶栏实心条上露出一截主题色，与页面底色对不上。
     */
    pageColorArgb: Int? = null,
    /**
     * 「回本周」浮钮的底边距（从屏幕底端起，已含系统内边距）。
     *
     * 由宿主按**玻璃坞药丸的真实占用**算好传进来（`HomeFloatingMetrics`）：页面自己
     * 拿不到坞的几何，以前写死的 `72dp` 在水势导航下正好落在药丸里 —— 用户报的
     * 「按钮在导航栏底下」就是这一条。
     *
     * `null` = 宿主没接 ⇒ 退回旧口径（系统内边距 + 72dp）。
     */
    floatingButtonBottomInset: Dp? = null,
    // ── 首页「周 ↔ 日」展开态（2026-11-02）────────────────────────────────
    /** 当前是不是日视图展开态（首页宿主的状态，不是本页自己记的）。 */
    dayMode: Boolean = false,
    /** 日视图正看着的那一周（星期栏在日视图下显示它，而不是周 pager 的当前页）。 */
    selectedWeek: Int = 1,
    /** 日视图正看着的那一天（1..7）。 */
    selectedDayOfWeek: Int = 1,
    /**
     * 首帧展开进度（0 = 周视图，1 = 日视图）。
     *
     * 只在**宿主被重建**时需要：从别的底栏页切回课表时，路由替换是瞬时的，
     * 新宿主首帧如果直接落定就看不到展开/收起。常驻时切换不看它（`dayMode` 变化
     * 本身会触发动画）。
     */
    dayProgressSeed: Float = 0f,
    /**
     * 本次周↔日切换是否 `animateTo`（来源判据）：`false` = 直接 `snapTo`（跨页切回课表，
     * 只让外层 Pager 横滑）；`true` = 播动画（几何看 [daySwitchHorizontal]）。
     */
    daySwitchAnimate: Boolean = true,
    /**
     * 本次周↔日切换几何是否走横滑（translateX）：`true` = 周内容左出、日内容右入（底栏
     * 「周/日」两格互点）；`false` = 原 heightFactor 从上往下展开（点星期栏某天/页内关闭）。
     * 两者共用同一个 [dayExpand] 进度；与 [daySwitchAnimate] 正交。
     */
    daySwitchHorizontal: Boolean = false,
    /** 点了星期栏某一天 / 翻到另一周某一天。宿主据此切到日视图并记住选中日。 */
    onSelectDay: (week: Int, dayOfWeek: Int) -> Unit = { _, _ -> },
    /** 日视图摘要卡上的关闭叉（收回周视图）。 */
    onCloseDay: () -> Unit = {},
    /**
     * 日视图正文（整屏尺寸的页面），由壳注入。
     *
     * 参数是「首页顶栏玻璃带的高度」：日视图在展开窗口里只画正文，顶栏 / 星期栏
     * 由本页画（与周视图共用一条带），正文从这条高度往下开始。
     */
    dayContent: (@Composable (contentTop: Dp, summaryModifier: Modifier) -> Unit)? = null,
    /** 用户设置的页面转场速度（1.0 = 原速；周→日展开与其它转场同一口径缩放）。 */
    transitionSpeed: Double = 1.0,
    /**
     * 截屏「分享课表图」提示是否接到本页（提示壳见 [ScreenshotSharePromptHost]）。
     *
     * 宿主按用户存档 `screenshotSharePromptEnabled` 喂；**预览卡必须传 false**——
     * 外观编辑页的缩尺预览复用整个宿主链，预览再接一份监听等于截一次屏弹两次提示
     * （Dart `_isPreview` 守卫，`timetable_screen.dart:913-917`）。默认 false：
     * 没接宿主的调用方（历史零参调用）保持完全旧行为。
     */
    screenshotSharePromptEnabled: Boolean = false,
    /**
     * 截屏提示上「分享」按钮的动作（2026-11-03 导出链路落地后接通）。
     *
     * 参数是**页面侧**算好的「用户正看着哪张图」：周图 `(week, null)`、日图
     * `(selectedWeek, selectedDayOfWeek)`——与 Dart `_shareTimetableImage`（:969-986）
     * 用 `_visibleWeek` / `_selectedDayOfWeek` 同一取数口径。只有页面知道当前可见周，
     * 宿主拿不到 pager 内部状态，所以由页面组装请求、宿主实现动作（null = 不画按钮，
     * 历史零参调用保持旧行为）。
     */
    onShareScreenshot: ((week: Int, dayOfWeek: Int?) -> Unit)? = null,
    /**
     * 设置页顶部预览模式（2026-11-04「课程卡片设置页预览」改造，见 R06）：
     * 预览里**不画**状态栏留白与顶栏「轻屿课表」，让 [TimetableWeekdayHeader] 当首行；
     * 网格按预览框高自适应节高、铺满不裁（对齐 Flutter `TimetableWeekPreview` 的
     * `includeAppHeader=false` + `heightBudget` 分支）。只给两个设置页预览用，正常页面恒 false。
     */
    previewMode: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val coroutineScope = rememberCoroutineScope()
    // 日视图实时选中桥：DayViewPage 分页器把「当前页」写进来，星期栏读它 → 选中高亮即时跟手、
    // 蓝条平滑滑动（只驱动显示，不落盘）。初值用宿主当前选中播种，首帧不闪。
    val daySelectionBridge = remember { DaySelectionBridge().also { it.update(selectedWeek, selectedDayOfWeek) } }

    val pageCount = totalWeeks.coerceAtLeast(1)
    val startPage = (initialWeek - 1).coerceIn(0, pageCount - 1)
    val pagerState = rememberPagerState(initialPage = startPage, pageCount = { pageCount })

    // 外部周次同步（换课表档 / 改学期起点与总周数 / 跨零点）：`initialWeek` 只是初值，
    // 不跟着走 pager 会停在旧周（Dart `syncWeekPageWithProvider` 在 build 里每帧收敛）。
    // 手势进行中绝不抢页，判据见 [WeekPagerSync.targetPage]。
    LaunchedEffect(initialWeek, pageCount) {
        val target = WeekPagerSync.targetPage(
            externalWeek = initialWeek,
            pageCount = pageCount,
            currentPage = pagerState.currentPage,
            isScrollInProgress = pagerState.isScrollInProgress,
        ) ?: return@LaunchedEffect
        pagerState.scrollToPage(target)
    }

    // 翻页 → 通知宿主（Dart `commitPendingWeek`：停稳后写回 provider.currentWeek）。
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            onWeekChanged(page + 1)
        }
    }

    val browsingWeek = pagerState.currentPage + 1
    var showWeekSelectorDialog by remember { mutableStateOf(false) }

    // ── 共享玻璃带上的星期栏跟哪一页（2026-11-01）──
    // 星期栏从 pager 内部提出来之后不再跟手指滑动，但也不能每帧跟 `currentPage`：
    // 那个值在滑过半页时就跳，左端「第 N 周」和日期会在拖动中来回改字。
    // 口径见 `chromeDisplayedPage`（main 源集纯函数）：滚动/吸附中保持上一次落定的页，
    // 完全停稳后才切到当前页。
    var displayedPage by remember(pagerState) {
        mutableIntStateOf(pagerState.currentPage)
    }
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage to pagerState.isScrollInProgress }
            .collect { (page, scrolling) ->
                val next = chromeDisplayedPage(
                    currentPage = page,
                    isScrollInProgress = scrolling,
                    previousPage = displayedPage,
                )
                if (next != displayedPage) displayedPage = next
            }
    }

    // ── 周 ↔ 日展开态（对齐 2026-11-04 用户口径：全宽 / 从上往下展开 / 壁纸页面级静态底）──
    //
    // 日视图是一整块面板：**全宽、从顶部往下长高露出**（heightFactor 裁剪窗口长大，非缩放、
    // 非逐卡飞行、非按当天列的水平锚点/宽度收缩）；同时淡入 + 圆角收平，周网格按原始进度淡出。
    // **不做垂直位移**：面板内容与壁纸都钉在顶部，避免带动壁纸上下动（见下方日视图展开层）。
    // 时长 360ms、面板进度曲线 easeInOutCubicEmphasized（三点贝塞尔，见 HomeViewExpandMotion）。
    val dayExpand = remember { Animatable(dayProgressSeed.coerceIn(0f, 1f)) }
    val dayExpandEasing = remember { homeViewEaseInOutCubicEmphasized }
    val dayExpandDuration = homeViewExpandDurationMillis(transitionSpeed)
    // ── 「减少动画」降级（2026-11-03 补齐，对齐 Flutter DayViewExpandMotion.expand/collapse）──
    // 系统把「动画时长缩放」归零时，展开/收起都**不播逐帧形变**：直接 snap 到目标值。
    // 判据是纯函数（[homeViewExpandReducedMotion]，JVM 单测在 HomeViewExpandMotionTest），
    // 这里只是 Android 取值的薄适配。系统设置进程内不广播，remember 一次即可
    // （Flutter 的 MediaQuery 同样只在配置变化时刷新，行为一致）。
    // `LocalContext.current` 是 composable 调用，必须在 remember 外取（calculation
    // 标了 @DisallowComposableCalls），context 作 key 只是为了调用结构正确。
    val resolverContext = LocalContext.current
    val dayExpandReducedMotion = remember(resolverContext) {
        homeViewExpandReducedMotion(
            Settings.Global.getFloat(
                resolverContext.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            ),
        )
    }
    // ── 展开层的可见性：由 `dayMode` + 动画进度**同步派生**（2026-11-03 修）──
    //
    // 旧写法用 `closing` 状态、在 LaunchedEffect(dayMode) 里置位。收起时 dayMode 先变假，
    // 组合期读到的 `closing` 还是 false ⇒ dayVisible 当帧为假 ⇒ 日视图整棵被销毁；
    // 下一帧 effect 才把 closing 置真、再把整棵重建。结果是收起方向每次多付一次首组合，
    // 日视图内部的 pager / 列表滚动位置也一起丢（用户报「切周视图也会卡」）。
    //
    // 现在用 derivedStateOf：布尔值只在「进度跨过 0」时翻一次，动画期间不会逐帧重组
    //（直接读 `dayExpand.value` 才会）。收起动画因此在原树上播完，播完那一帧才交接。
    val currentDayMode by rememberUpdatedState(dayMode)
    // 本次切换是否播上下翻：底栏/导航栏/跨页来源 = false（snapTo），点星期栏某天 = true（animateTo）。
    // 用 rememberUpdatedState 读，保证 LaunchedEffect(dayMode) 只按 dayMode 触发时也能拿到最新来源。
    val currentDaySwitchAnimate by rememberUpdatedState(daySwitchAnimate)
    val dayVisible by remember {
        derivedStateOf { currentDayMode || dayExpand.value > 0f }
    }
    // 进入 / 切回日视图时用宿主当前选中给桥播种，避免首帧蓝条从默认格滑过来。
    LaunchedEffect(dayVisible) {
        if (dayVisible) daySelectionBridge.update(selectedWeek, selectedDayOfWeek)
    }
    // 展开/收起过渡是否**已落定**（dayExpand 到终值）：布尔只在跨过 0.999 时翻一次，
    // 动画期间不逐帧重组。日视图拿它门控「回今日」浮钮——过渡期间不显示、不随转场位移，
    // 落定后再按共用件自带的 fadeIn+scaleIn 淡入（与周视图「回本周」同一份出场动效）。
    val dayExpandSettled by remember {
        derivedStateOf { currentDayMode && dayExpand.value >= 0.999f }
    }
    // 展开层是否**已经挂载过**：打开过一次就跨开合保活，收起后不再卸载整棵树。
    // 只有「从没打开过」才完全不组合（不占内存、不跑日视图的任何 effect）。
    var dayLayerReady by remember { mutableStateOf(dayMode) }
    LaunchedEffect(dayMode) {
        if (dayMode) dayLayerReady = true
    }
    // 展开层**是否留在树上**：可见时当然留；不可见但已预热/挂载过也留（保活）。
    // 注意与 `dayVisible` 的分工：dayMounted 决定「组合/测量」，dayVisible 决定
    // 「绘制与命中」——隐藏时树还在，但不画、不接事件（见下方展开层的 inert 门控）。
    val dayMounted = dayVisible || dayLayerReady

    LaunchedEffect(dayMode) {
        val expandTarget = if (dayMode) 1f else 0f
        if (dayExpandReducedMotion || !currentDaySwitchAnimate) {
            // 两条都直接落定、不播逐帧形变：
            // ① 系统「减少动画」降级（Dart `controller.value = 1/0` 同口径）；
            // ② **底栏 / 导航栏 / 跨页来源的切换**（`daySwitchAnimate = false`）——用户口径
            //   「底栏/导航栏就是左右滑」，绝不能再播从上往下的展开/收起；横向由外层 Pager
            //   负责，这里瞬时落定。
            // snap 后 value 恰为 1.0/0.0，下方落定判据当帧即成立，不存在中间帧。
            dayExpand.snapTo(expandTarget)
        } else {
            dayExpand.animateTo(
                targetValue = expandTarget,
                animationSpec = tween(durationMillis = dayExpandDuration, easing = dayExpandEasing),
            )
        }
        // 收起**动画播完**后把展开层卸载：日视图关闭后隐藏的 DayViewPage 不再常驻组合树，
        // 周浏览时省掉它的布局/effect 成本（R07 减负）。只在落定（value==0）且已非日模式时卸，
        // 不在收起动画中途卸，避免重组打断收起动画。
        if (!dayMode && dayExpand.value <= 0f) {
            dayLayerReady = false
        }
    }

    // 收起落定后把周 pager 对到「日视图刚才看的那一周」：否则收起会跳回进日视图前的旧周。
    var wasDayMode by remember { mutableStateOf(dayMode) }
    LaunchedEffect(dayMode) {
        if (wasDayMode && !dayMode) {
            val targetPage = (selectedWeek - 1).coerceIn(0, pageCount - 1)
            if (pagerState.currentPage != targetPage) pagerState.scrollToPage(targetPage)
        }
        wasDayMode = dayMode
    }

    val accentColor = Color(QingyuTheme.primary(dark = dark))
    val textColor = Color(QingyuTheme.primaryText(dark))
    val subTextColor = Color(QingyuTheme.secondaryText(dark))
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))

    // ── 首页顶栏玻璃带（2026-11-01）──
    // Dart 这条带是「标题行 + 星期栏」共用的一条连续玻璃（`home_page_region_blur.dart`
    // 的 `HomePageChromeGlassFill`）。本页在 2026-11-01 把状态栏也并进来：
    // 带子从屏幕 y = 0 画到星期栏底边，三块内容装在**同一个** Box 里。
    //
    // 三步接线的第 ① 步：把壁纸层录进 `pageBackdrop`（记录 ≠ 上屏，原内容照常画）；
    // 第 ② 步在带子上 `drawBackdrop` 采样 + 高斯 + 染色。只有「液态 + 真有壁纸 +
    // 设备支持 RuntimeShader」三件事同时成立才录，否则省掉整层采样。
    // 课卡玻璃（下面 `cardGlassActive`）复用同一层录像带。
    val density = LocalDensity.current
    // ── 整页只有**一层**壁纸录像带 ──
    // 顶栏玻璃带与周网格课程卡片都从它采样。卡片数量多（一屏 20~50 张），
    // 一张卡建一层录像带会把整屏复制几十份；Dart 也是同一结论
    // （`course_surface.dart:197-208`：一屏一张预糊位图，多卡共用）。
    val pageBackdrop = rememberLayerBackdrop()
    // 课卡的**共享预糊层**：整屏只糊这一趟，卡片各自从这张图里取自己那一块
    // （Dart `PreblurredWallpaperCache` 的 Compose 等价物）。
    val cardGlassBackdrop = rememberLayerBackdrop()
    // ── 「回本周」浮钮的**真实内容**录制层（B1，2026-11-04）──
    // 浮钮原采 pageBackdrop（只录壁纸），即便下面压着课卡也只看得到壁纸。这一层录
    // [壁纸 + 预糊层 + 内容 Column]（不含浮钮自己），浮钮摘成录制层外的兄弟再采它。
    val contentBackdrop = rememberLayerBackdrop()
    val materialSpec = material
    // 玻璃带是否处于「液态档 + 真有壁纸 + 设备支持」，判据与渲染层同一份
    //（`TimetableChromeBandGlass` 里那段 `when`）；这里单独留一份只是为了给
    // 下面 `pageBackdropActive`（决定要不要挂录像层）用，不参与画玻璃。
    val bandBlurActive = materialSpec?.band == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    // 星期栏背后到底是不是壁纸：没画带子（老行为 / OFF）或是液态玻璃 ⇒ 是；
    // 实体档 ⇒ 带子不透明，字压在页底色上，不该按壁纸亮度翻色。
    val bandOverWallpaper = materialSpec == null ||
        materialSpec.band == SurfaceMaterialState.OFF ||
        bandBlurActive
    val bandSolidColor = pageColorArgb?.let { Color(it) } ?: scaffoldBg
    // 形状边界要往屏幕外推多少（逻辑 dp，只算作用带那一份）：取值理由见
    // `SettingsMaterialModel.bandGlassOverdrawDp`。左右还要再叠上安全区，
    // 那一步要 `innerPadding`，所以在 Scaffold 内容里算（见下方 bandOverdrawPx）。
    val bandOverdrawBaseDp = SettingsMaterialModel.bandGlassOverdrawDp(
        materialSpec?.liquidRefractionBand ?: 0f,
    )
    //
    // 标题行、星期栏、状态栏**共用这一个玻璃节点**：带子只挂一次，
    // 一个节点 = 一次采样 + 一次高斯 + 一次折射 + 一次染色，交界不会出现第二份模糊核。

    // ── 状态栏图标 / 文字的明暗（2026-11-01）──
    // 玻璃带盖住状态栏之后，系统图标原本只在「主题明暗」变化时被 Activity 设一次
    // （`PagesShellActivity.applyShellSystemBars`），不知道壁纸是什么颜色。
    // 这里沿用标题行同一条判据 [chromeInk]（宿主用壁纸顶部亮度算出来的）：
    //   Light = 深色壁纸 ⇒ 浅墨 ⇒ 状态栏图标要浅色（isAppearanceLightStatusBars = false）
    //   Dark  = 浅色壁纸 ⇒ 深墨 ⇒ 状态栏图标要深色（true）
    // 没有壁纸 / 亮度还没量出来 ⇒ 跟系统明暗，与 Activity 的兜底一致。
    val lightStatusBarIcons = when (chromeInk) {
        HomeInkPolarity.Light -> false
        HomeInkPolarity.Dark -> true
        null -> !dark
    }
    // 预览模式不改真实系统状态栏（预览只是缩略窗口，不该改设备状态栏图标极性）。
    if (!previewMode) ApplyStatusBarInk(lightIcons = lightStatusBarIcons, themeDark = dark)

    // 星期栏的两枚圆点判据：提到共享带之后只算一次（以前每页各算一份）。
    val hasExamOnDate: (LocalDate) -> Boolean = remember(exams, now) {
        { date -> WeekAgendaLogic.hasExamOn(date, exams, now) }
    }
    val hasScheduleOnDate: (LocalDate) -> Boolean = remember(scheduleItems) {
        { date -> WeekAgendaLogic.hasScheduleOn(date, scheduleItems) }
    }

    // ── 课卡液态档（2026-11-01）──
    // 门控与顶栏带同构：液态档 + 真有壁纸 + 设备支持 runtime shader。模型层已把
    // 「无壁纸 / 模糊总闸关 / 用户选实体或高斯」降成非液态，这里再挡一次系统能力；
    // 三件事缺一件就**退回各卡原有的透明度填充**（`CourseGridCard` 的 `background(fill)`）。
    val cardGlassActive = materialSpec?.courseCard == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    val cardBlurSigmaPx = with(density) {
        (materialSpec?.courseCardBlurSigma ?: 0f).dp.toPx()
    }
    // σ = 0 是**有效的清档**（Dart 清澈档，`preblurred_wallpaper_glass.dart:493-498`）：
    // 背景原样透出、不跑高斯，所以连预糊那一趟也省掉。
    val cardPreblurActive = cardGlassActive && cardBlurSigmaPx > 0f
    // 卡片采哪一层：σ > 0 采共享预糊层；σ = 0（清澈档）直接采原壁纸录像层。
    val cardGlassSource: Backdrop? = when {
        !cardGlassActive -> null
        cardPreblurActive -> cardGlassBackdrop
        else -> pageBackdrop
    }

    val sectionTimes: List<SectionTime> = timeScheme?.sections?.takeIf { it.isNotEmpty() }
        ?: settings.sections
    // 节数口径：Dart `settings.sectionCount => sections.length`
    //（`lib/models/timetable_settings.dart:2479`，周网格 `List.generate(settings.sectionCount)`）。
    // 旧实现写成 `coerceAtLeast(12)`，用户把作息表配成 10 节时 Compose 仍画 12 行、Dart 只画 10 行。
    val sectionCount = sectionTimes.size
    val semesterStart = settings.semesterStartDate?.toLocalDate()

    // 单节课提醒键（`courseId|yyyy-MM-dd`）：课卡右上角铃铛的唯一数据源
    //（`core/TimetableSettings.classReminders`，随仓储快照进来）。
    val reminderKeys = remember(settings.classReminders) {
        settings.classReminders.map { it.key }.toSet()
    }
    val realCurrentWeek = currentSemesterWeek(semesterStart, totalWeeks, todayDate)
    val showBackToCurrentWeek = style.showBackToCurrentWeek &&
        realCurrentWeek != null &&
        realCurrentWeek != browsingWeek

    // 浮钮与玻璃坞同一档：真有壁纸 + 设备支持 runtime shader + 坞本身是玻璃材质。
    // 只是「要不要录整屏」的判据；真正的档位判断在共用件里再做一次。
    val floatingGlassActive = showBackToCurrentWeek && !dayVisible &&
        hasBackdrop && isRuntimeShaderSupported() &&
        (materialSpec?.dock == SurfaceMaterialState.LIQUID_GLASS ||
            materialSpec?.dock == SurfaceMaterialState.FROST)

    // pageBackdrop 只给顶栏带 / 课卡玻璃采样（只录壁纸）；「回本周」浮钮改用独立的
    // contentBackdrop（录真实内容），故这里不含 floatingGlassActive（否则浮钮一开就多录一层）。
    // 但嵌入日页的「回今日」浮钮要按**窗口坐标**采这一层壁纸（避免日页面板内本地补画下偏），
    // 所以「日视图可见 + 有壁纸 + 支持 shader + 浮钮玻璃档」时也要录这层壁纸交给嵌入日页。
    val dayFabGlassActive = dayVisible && hasBackdrop && isRuntimeShaderSupported() &&
        (materialSpec?.dock == SurfaceMaterialState.LIQUID_GLASS ||
            materialSpec?.dock == SurfaceMaterialState.FROST)
    val pageBackdropActive = bandBlurActive || cardGlassActive || dayFabGlassActive

    Scaffold(
        // 有壁纸时底色必须透明，否则不透明主题底会把壁纸整张盖掉。
        containerColor = if (backdrop == null) scaffoldBg else Color.Transparent,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        Box(
            modifier = Modifier.fillMaxSize(),
        ) {
        // ── 真实内容录制层（B1）：录 [壁纸 + 预糊层 + 内容 Column]，浮钮放在本层之外 ──
        // 只有「回本周」浮钮真要采玻璃时才挂录像（录制 = 整屏离屏重画一帧，门控同 dock）。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .then(
                    if (floatingGlassActive) {
                        Modifier.layerBackdrop(contentBackdrop)
                    } else {
                        Modifier
                    },
                ),
        ) {
        // 壁纸层在最底（Dart 的层次：壁纸 → 内容）。没有壁纸时这一行什么也不画。
        // 顶栏玻璃带与课卡玻璃都要采样它，所以包一层（只有真要玻璃时才挂 `layerBackdrop`）。
        if (backdrop != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (pageBackdropActive) {
                            Modifier.layerBackdrop(pageBackdrop)
                        } else {
                            Modifier
                        },
                    ),
            ) {
                backdrop.invoke(this)
            }
        }
        // ── 课卡的共享预糊层：整屏只糊**这一趟** ──
        // `alpha(0f)` = 这一层不上屏，唯一作用是把自己录进 `cardGlassBackdrop`
        // （与玻璃坞 ② 层「图标折射副本」同一手法）。它画在壁纸录像层之后，
        // 才采得到这一帧的壁纸。所有卡片随后都只从这张图里取自己那块：
        // 一屏 20~50 张卡共用一次高斯，而不是每卡一次实时模糊。
        if (cardPreblurActive) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .alpha(0f)
                    .layerBackdrop(cardGlassBackdrop)
                    .drawBackdrop(
                        backdrop = pageBackdrop,
                        shape = { RectangleShape },
                        effects = {
                            blur(cardBlurSigmaPx)
                            // 与顶栏带同一条：少了它玻璃会发灰。
                            vibrancy()
                        },
                    ),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 左右吃安全区；顶部**刻意不吃**——玻璃带要从 y = 0（状态栏背后）开始，
                // 由带子内部用等高的 Spacer 把标题行顶到状态栏下面。
                // 底部也刻意不吃——滚动视口要铺到屏幕最底，卡片从手势条底下穿过去
                // （2026-10-28 用户反馈「卡片被手势条截断」就是这层多算了一次）。
                .padding(
                    start = innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    end = innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                ),
        ) {
            // 玻璃节点是**带子盒子的孩子**，而带子盒子被左右安全区内缩过（下面 Column 的
            // `padding(start/end)`）。横屏挖孔时只推「作用带 + 1」还压不住屏幕边 ——
            // 形状的左 / 右边界会落进可见区，读成一条竖折射边。把安全区一起加进外溢量，
            // 形状边界才真的出屏（Dart 那条带是 `Positioned(left: 0, right: 0)` 的全宽层，
            // 天然没有这问题；Compose 这边靠这一项补平）。
            val bandOverdrawPx = with(density) {
                (bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                )).toPx()
            }
            // ── 顶栏玻璃带：状态栏 + 标题行 + 星期栏 = 同一条带 ──
            // 三块内容装在同一个盒子里，玻璃只在**一个**节点上挂一次（一次采样、
            // 一次高斯、一次折射、一次染色）—— 各挂一次会在交界处截断模糊核并叠加染色。
            // 玻璃层本身是共享件（`TimetableChromeBandGlass`），日/月视图同一条带。
            TimetableChromeBandGlass(
                material = materialSpec,
                hasBackdrop = hasBackdrop,
                backdrop = pageBackdrop,
                solidColor = bandSolidColor,
                overdrawDp = (bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                )),
            ) {

                Column(modifier = Modifier.fillMaxWidth()) {
                    // 预览模式（2026-11-04）：不画状态栏留白与顶栏「轻屿课表」，
                    // 让星期栏当首行（对齐 Flutter `TimetableWeekPreview` 的 includeAppHeader=false）。
                    if (!previewMode) {
                        // 状态栏区域留白：带子画到屏幕最顶，内容仍停在状态栏下面。
                        Spacer(modifier = Modifier.height(innerPadding.calculateTopPadding()))

                        // ── 顶栏「轻屿课表」+ 右上角「更多」菜单（三视图共用一份）──
                        TimetableTopBar(
                            brand = homeTitleStyle == HomeTitleStyle.BRAND,
                            inkPolarity = chromeInk,
                            profileName = profileName,
                            onTitleClick = onSwitchProfileClick,
                            homeMenuStyle = homeMenuStyle,
                            menuItems = homeMenuItems,
                            onMenuSelect = onHomeMenuSelect,
                        )
                    }

                    // ── 星期栏：从 pager 里提出来，不跟横向翻页滑动 ──
                    // 显示「落定后的那一页」；滑动过程中保持上一页（见 displayedPage）。
                    // 日视图展开时改跟「日视图正在看的那一周/那一天」：日视图可以连续翻周，
                    // 而周 pager 停在下面不动，继续读 displayedPage 会把星期栏钉在旧周上。
                    TimetableWeekdayHeader(
                        // 2141：不再需要飞行起点测量。
                        week = if (dayVisible) selectedWeek else displayedPage + 1,
                        currentWeek = currentWeek,
                        todayDate = todayDate,
                        semesterStartDate = semesterStart,
                        visibleDays = visibleDays,
                        style = style,
                        // 星期栏压在**壁纸**上才谈壁纸墨色：实体档的带子是不透明的页底色条，
                        // 底下根本没有壁纸（Dart `homePageWeekdayBarOverWallpaper`，
                        // `home_page_region_blur.dart:332-347`）。以前无脑传会得到
                        // 「浅色实心带 + 白色字」。
                        wallpaperLuminance = wallpaperBands?.weekday?.takeIf {
                            bandOverWallpaper
                        },
                        timeColumnWidth = style.timeColumnWidthDp.dp,
                        // 日视图用强调色标出正在看的那一天（Dart 同一条栏、同一个高亮）；
                        // 周视图不标。
                        selectedDayOfWeek = selectedDayOfWeek.takeIf { dayVisible },
                        // 日视图改读分页器实时选中（即时跟手 + 蓝条平滑滑动）；周视图 / 预览为 null。
                        selectionBridge = if (dayVisible) daySelectionBridge else null,
                        hasExamOnDate = hasExamOnDate,
                        hasScheduleOnDate = hasScheduleOnDate,
                        // 周视图：点哪天 = 从周视图展开到那一天（不再推 c3.day 路由）。
                        // 日视图：点另一天 = 在同一展开层里换日；点**当前这一天** = 收起
                        //（Dart `DayViewTransitionController.toggle` 的
                        // `sameSelectionCloses = true`，底栏与星期栏同一条口径）。
                        onDayClick = { dayOfWeek ->
                            when {
                                dayMode && dayOfWeek == selectedDayOfWeek -> onCloseDay()
                                dayMode -> onSelectDay(selectedWeek, dayOfWeek)
                                else -> onSelectDay(displayedPage + 1, dayOfWeek)
                            }
                        },
                        onWeekTitleClick = { showWeekSelectorDialog = true },
                    )
                }
            }

            // 下方内容：从玻璃带底部开始，占满剩余高度（底部仍铺到屏幕最底）。
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                if (previewMode) {
                    // 预览：单周、按框高自适应节高（对齐 Flutter `_TimetableWeekPreviewBody`
                    // 的 heightBudget 分支：sectionHeight = 可用高 / 可见节数）。
                    // 不接 pager（预览不可横滑；禁交互由外层挖洞件的 pointer 拦截负责），也不淡出。
                    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                        val previewSectionHeight = if (sectionCount > 0) {
                            (maxHeight / sectionCount.toFloat()).coerceAtLeast(0.dp)
                        } else {
                            0.dp
                        }
                        WeekPageContent(
                            pageWeek = initialWeek,
                            semesterStart = semesterStart,
                            reminderKeys = reminderKeys,
                            visibleDays = visibleDays,
                            courses = courses,
                            style = style,
                            sectionTimes = sectionTimes,
                            sectionCount = sectionCount,
                            exams = exams,
                            scheduleItems = scheduleItems,
                            now = now,
                            bottomInset = 0.dp,
                            holidayOf = holidayOf,
                            weatherOf = weatherOf,
                            onCourseClick = {},
                            onAgendaClick = {},
                            onLongPressEmptySlot = { _, _ -> },
                            material = material,
                            cardGlassBackdrop = cardGlassSource,
                            wallpaperLuminance = wallpaperBands?.body,
                            modifier = Modifier.fillMaxSize(),
                            sectionHeightOverride = previewSectionHeight,
                            bottomClearanceDp = 0.dp,
                        )
                    }
                } else HorizontalPager(
                    state = pagerState,
                    modifier = Modifier
                        .fillMaxSize()
                        // 2141：周网格按原始进度淡出（alpha = 1 - value，不缓动）。
                        // 只挂 pager 自己：外层还要画日面板与「回今日」浮钮。
                        // ⚠️ 性能（R07）：仅在日视图可见/过渡（dayVisible）时才挂这层离屏 alpha；
                        // 普通周浏览（dayExpand 稳定 0、dayVisible=false）不挂任何 alpha 层，
                        // 否则整块 pager 每帧走离屏合成 → 周视图左右滑卡顿。
                        .then(
                            when {
                                !dayVisible -> Modifier
                                // 横滑（底栏「周/日」两格互点）：周内容随进度向**右**滑出（p: 0→1）。
                                // 只做绘制期 translationX，不挂 alpha、不加手势。
                                daySwitchHorizontal -> Modifier.graphicsLayer {
                                    translationX =
                                        dayExpandEasing.transform(dayExpand.value) * size.width.toFloat()
                                }
                                // 上下翻（点星期栏某天）：周网格按原始进度淡出（2141 口径，不缓动）。
                                else -> Modifier.graphicsLayer {
                                    alpha = (1f - dayExpand.value).coerceIn(0f, 1f)
                                }
                            },
                        ),
                ) { page ->
                    WeekPageContent(
                        pageWeek = page + 1,
                        semesterStart = semesterStart,
                        reminderKeys = reminderKeys,
                        visibleDays = visibleDays,
                        courses = courses,
                        style = style,
                        sectionTimes = sectionTimes,
                        sectionCount = sectionCount,
                        exams = exams,
                        scheduleItems = scheduleItems,
                        now = now,
                        bottomInset = maxOf(
                            innerPadding.calculateBottomPadding(),
                            // 玻璃坞满屏悬浮的底部避让（共享注入=药丸总占用，含系统栏）；用 max 去重。
                            com.mutx163.qingyu.components.LocalGlassDockScrollRelief.current,
                        ) + if (showBackToCurrentWeek && !dayVisible) {
                            // 非本周「回本周」浮钮可见：叠一段让最后一行能滑到钮上方；本周无钮=0。
                            com.mutx163.qingyu.pages.shell.HomeFloatingMetrics.BACK_TO_TODAY_SCROLL_EXTRA_DP.dp
                        } else {
                            0.dp
                        },
                        holidayOf = holidayOf,
                        weatherOf = weatherOf,
                        onCourseClick = onCourseClick,
                        onAgendaClick = onAgendaClick,
                        onLongPressEmptySlot = onLongPressEmptySlot,
                        material = material,
                        cardGlassBackdrop = cardGlassSource,
                        // 时间列压在壁纸的正文带上：同一档亮度决定字色。
                        wallpaperLuminance = wallpaperBands?.body,
                        // ── 内容层缓存（2026-11-03 卡顿修复）──
                        // 展开/收起期间本页的 draw 块逐帧执行（读 `dayExpand.value`），
                        // 若子树没有自己的图层，整页绘制命令会被并进 pager 那一层的
                        // DisplayList、每帧重录一遍（几十张卡的文字与圆角）。
                        // 挂一层**配置恒定**（不读进度、不读动画状态）的 `graphicsLayer`，
                        // 内容录一次后复用，动画帧只换外层裁切。配置一旦随进度变化
                        // （例如把 alpha/scale 接到 dayExpand），图层失效，缓存等于没挂。
                        // 同一条性能口径（R07）：每页这层常驻 alpha 只在日过渡期用于缓存周内容；
                        // 普通周浏览不挂（省掉每页一层离屏合成）。
                        modifier = Modifier
                            .fillMaxSize()
                            .then(if (dayVisible) Modifier.graphicsLayer { alpha = 1f } else Modifier),
                    )
                }

                // ── 日视图展开层（2026-11-04 用户口径：全宽 + 从上往下展开 + 壁纸页面级静态不动）──
                // 只做「高度从顶部往下长大露出」：全宽面板、Alignment.TopCenter、heightFactor 裁剪窗口。
                // 不做按当天列的水平锚点 / 宽度收缩，也**不做垂直位移**——内容与壁纸都钉在顶部，
                // 避免带动壁纸上下动；壁纸由页面级最底层那层静态画（见上方 `backdrop`）。
                if (dayMounted && dayContent != null) {
                    // 日视图展开时**真拦截**命中：不只是「宣称」——pointerInput 必须 consume 掉事件，
                    // 否则下层周网格（长按空白格加课）仍能收到。周 pager 的横滑只移绘制
                    // （graphicsLayer translationX 不改命中区），所以拦截必须在这一层做。
                    val hitGate = if (dayVisible) {
                        Modifier.pointerInput(Unit) {
                            awaitPointerEventScope {
                                while (true) {
                                    val event = awaitPointerEvent()
                                    event.changes.forEach { it.consume() }
                                }
                            }
                        }
                    } else {
                        Modifier
                    }
                    if (daySwitchHorizontal) {
                        // 横滑（底栏「周/日」两格互点）：日内容从**左**滑入、周内容向右滑出。
                        // 与上下翻共用同一个 dayExpand 进度；只做绘制期 translationX、不加手势。
                        Box(
                            modifier = Modifier
                                .matchParentSize()
                                .clipToBounds()
                                .graphicsLayer {
                                    translationX =
                                        -(1f - dayExpandEasing.transform(dayExpand.value)) * size.width.toFloat()
                                }
                                .then(hitGate),
                        ) {
                            CompositionLocalProvider(
                                LocalEmbeddedDayGlassBackdrop provides cardGlassSource,
                                LocalEmbeddedDayTransitionSettled provides dayExpandSettled,
                                LocalEmbeddedDayWallpaperBackdrop provides pageBackdrop,
                                LocalDaySelectionBridge provides daySelectionBridge,
                            ) {
                                dayContent(0.dp, Modifier)
                            }
                        }
                    } else {
                        // 上下翻（点星期栏某天 / 页内关闭）：原 heightFactor 顶部往下展开，几何不动。
                        val rawValue = dayExpand.value
                        val progress = dayExpandEasing.transform(rawValue)
                        val heightFactor = max(0.04f, progress)
                        val panelAlpha = homeViewEaseOutCubic(progress)
                        val cornerDp = 28f * homeViewExpandCornerRadiusFactor(progress)
                        BoxWithConstraints(
                            modifier = Modifier
                                .matchParentSize()
                                .clipToBounds()
                                .then(hitGate),
                        ) {
                            val maxW = maxWidth
                            val maxH = maxHeight
                            val panelH = maxH * heightFactor
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopCenter)
                                    .width(maxW)
                                    .height(panelH)
                                    .clip(RoundedCornerShape(cornerDp.dp)),
                            ) {
                                Box(
                                    modifier = Modifier
                                        .requiredSize(maxW, maxH)
                                        .graphicsLayer { alpha = panelAlpha },
                                ) {
                                    // contentTopInset = 0：面板铺满内容区，页面自己只加正文顶缝 14dp。
                                    // 壁纸由本页最底层静态画；把**页面级预糊层**经 CompositionLocal 交给
                                    // 嵌入的日视图做卡片玻璃采样——它自己不再画壁纸，壁纸因此不随展开层移动。
                                    CompositionLocalProvider(
                                        LocalEmbeddedDayGlassBackdrop provides cardGlassSource,
                                        LocalEmbeddedDayTransitionSettled provides dayExpandSettled,
                                        LocalEmbeddedDayWallpaperBackdrop provides pageBackdrop,
                                        LocalDaySelectionBridge provides daySelectionBridge,
                                    ) {
                                        dayContent(0.dp, Modifier)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }  // 关闭真实内容录制层（B1）

        // ── 「回本周」浮钮（搬出录制层，采它背后的真实内容）──
        // 与日视图「回今日」共用同一颗 [BackToTodayFab]；backdrop 从 pageBackdrop（只录壁纸）
        // 改为 contentBackdrop（壁纸 + 课卡 + 文字）。可见性 / 点击行为不变。
        val buttonOpacity = style.backToCurrentWeekOpacity.coerceIn(0f, 1f)
        BackToTodayFab(
            onClick = {
                realCurrentWeek?.let { target ->
                    coroutineScope.launch {
                        pagerState.animateScrollToPage(
                            (target - 1).coerceIn(0, pageCount - 1),
                        )
                    }
                }
            },
            label = DayViewStrings.backToTodayShort.zh,
            contentDescription = TimetableStrings.backToCurrentWeekAction.zh,
            visible = !previewMode && showBackToCurrentWeek && !dayVisible,
            backdrop = if (floatingGlassActive) contentBackdrop else pageBackdrop,
            material = materialSpec,
            hasBackdrop = hasBackdrop,
            alpha = buttonOpacity,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                // 底边距由宿主按玻璃坞药丸的真实占用算好（见 `HomeFloatingMetrics`）。
                .padding(
                    bottom = (floatingButtonBottomInset
                        ?: (innerPadding.calculateBottomPadding() + 72.dp)) -
                        FAB_SHADOW_REACH_DP.dp,
                ),
        )

        // ── 截屏「分享课表图」提示（Dart timetable_screen.dart:935-963）────────
        // 挂在根 Box 最后一层：压在内容 / 日视图展开层之上，但弹层通道（Overlay 系列）
        // 仍在其上。检测事件由壳挂的 ScreenCaptureWatcher 出，门控三道（设置开关 /
        // 本页置顶 / 6 秒冷却）在提示宿主里。胶囊抬到「回本周」浮钮上方，不再压住它。
        ScreenshotSharePromptHost(
            enabled = screenshotSharePromptEnabled,
            onShare = onShareScreenshot?.let { onShare ->
                {
                    // 与 Dart _shareTimetableImage（:981-984）同一取数：日视图分享
                    // 「正在看的那一天」，周视图分享当前可见周。
                    if (dayVisible) {
                        onShare(selectedWeek, selectedDayOfWeek)
                    } else {
                        onShare(browsingWeek, null)
                    }
                }
            },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(
                    bottom = (floatingButtonBottomInset
                        ?: (innerPadding.calculateBottomPadding() + 72.dp)) + 48.dp,
                ),
        )
        }
    }

    // ── 周次选择弹层（点星期栏左端「8 周」打开）──
    // Dart `week_selector_picker_sheet.dart`：底部弹层 + 4 列网格 + 「第 N 周」+ 说明行 + 回本周。
    // 旧实现是居中 Dialog + 5 列 + 只写数字 + 固定 220dp 高（用户口径「看起来非常奇怪」），
    // 逐条对照后重写，见 `WeekSelectorSheet.kt` 的 KDoc 对照表。
    WeekSelectorSheet(
        show = showWeekSelectorDialog,
        // 可选周次 = 1..总周数（Dart `settings.availableWeeks` 即 startWeek..endWeek，
        // 学期周数在宿主侧已经钳过，这里不再二次过滤）。
        availableWeeks = (1..pageCount).toList(),
        // 日视图展开时显示「日视图正在看的那一周」，否则显示周 pager 落定的那一周。
        visibleWeek = if (dayVisible) selectedWeek else browsingWeek,
        currentSemesterWeek = realCurrentWeek,
        onDismiss = { showWeekSelectorDialog = false },
        onSelect = { week ->
            showWeekSelectorDialog = false
            if (dayVisible) {
                // 展开层常驻：换周不重建日视图，交给它按 requested 目标滚过去。
                onSelectDay(week, selectedDayOfWeek)
            } else {
                coroutineScope.launch {
                    pagerState.animateScrollToPage((week - 1).coerceIn(0, pageCount - 1))
                }
            }
        },
    )
}

/**
 * pager 里的一周：可纵向滚动的时间列 + 网格。
 *
 * 星期栏已经提到共享玻璃带里（见 [TimetableWeekPage]），这里不再画栏、也不占栏高。
 * 节高在这里定：`weekSectionHeight` 要拿到实际可用高度才能算「自动充满」。
 */
@Composable
private fun WeekPageContent(
    pageWeek: Int,
    semesterStart: LocalDate?,
    /** 已设单节课提醒键（`courseId|yyyy-MM-dd`），空集 = 真的没设过。 */
    reminderKeys: Set<String> = emptySet(),
    visibleDays: List<Int>,
    courses: List<Course>,
    style: WeekViewStyle,
    sectionTimes: List<SectionTime>,
    sectionCount: Int,
    exams: List<Exam>,
    scheduleItems: List<ScheduleItem>,
    now: LocalDateTime,
    bottomInset: Dp,
    holidayOf: (week: Int, dayOfWeek: Int) -> Boolean,
    weatherOf: ((week: Int, dayOfWeek: Int, Course) -> String?)?,
    onCourseClick: (Course) -> Unit,
    onAgendaClick: (WeekAgendaCardModel) -> Unit,
    onLongPressEmptySlot: (dayOfWeek: Int, section: Int) -> Unit,
    material: HomeMaterialRenderSpec? = null,
    /**
     * 课卡液态档的背景采样源（整页共享）。null = 走各卡原有的透明度填充。
     * 非空时它要么是「整屏预糊层」（σ > 0），要么是原壁纸录像层（清澈档 σ = 0），
     * 由 [TimetableWeekPage] 一次性算好，这里只往下透传。
     */
    cardGlassBackdrop: Backdrop? = null,
    /** 时间列那档壁纸亮度；null = 没壁纸（保持设置里的字色）。 */
    wallpaperLuminance: Double? = null,
    /**
     * 预览模式：显式节高覆盖（按预览框高自适应算好传进来，见 [TimetableWeekPage] 的 previewMode）。
     * null = 走原有 `weekSectionHeight`（自动充满或固定节高）。
     */
    sectionHeightOverride: Dp? = null,
    /** 底部避让余量；预览里传 0，避免 64dp 坞避让把网格撑出框。 */
    bottomClearanceDp: Dp = 0.dp,
    /** 内容层外壳（缓存图层挂在这里，见 pager 调用处的说明）。 */
    modifier: Modifier = Modifier,
) {
    val cardsByDay = remember(courses, pageWeek, style, visibleDays, weatherOf, reminderKeys, semesterStart) {
        WeekGridCourseMapping.cardsForWeek(
            courses = courses,
            week = pageWeek,
            style = style,
            visibleDays = visibleDays,
            weatherOf = weatherOf,
            reminderKeys = reminderKeys,
            semesterStartDate = semesterStart,
        )
    }
    val agendaByDay = remember(exams, scheduleItems, pageWeek, style, visibleDays, semesterStart) {
        buildAgendaByDay(
            week = pageWeek,
            semesterStart = semesterStart,
            visibleDays = visibleDays,
            sectionTimes = sectionTimes,
            exams = exams,
            scheduleItems = scheduleItems,
            now = now,
            style = style,
        )
    }

    // 星期栏已经提到共享玻璃带里（见 [TimetableWeekPage]），这里只剩网格。
    // `weekdayHeaderHeightDp = 0`：本 Box 的 maxHeight 已经不含星期栏，
    // 再减一次 40 会把节高压扁（旧结构里栏在页内、却又减了一遍栏高）。
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val sectionHeight = sectionHeightOverride ?: weekSectionHeight(
            style = style,
            availableHeightDp = maxHeight.value,
            weekdayHeaderHeightDp = 0f,
            sectionCount = sectionCount,
        ).dp

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    // 底部留白 = 手势条高度 + 底坞避让余量（最后一行能滑到坞上方）。
                    // 预览里 bottomClearanceDp = 0，不预留坞避让（否则会把网格撑出预览框）。
                    .padding(bottom = bottomInset + bottomClearanceDp),
            ) {
                TimetableTimeColumn(
                    sectionCount = sectionCount,
                    sectionTimes = sectionTimes,
                    sectionHeight = sectionHeight,
                    timeColumnWidth = style.timeColumnWidthDp.dp,
                    style = style,
                    wallpaperLuminance = wallpaperLuminance,
                )
                TimetableWeekGrid(
                    cardsByDay = cardsByDay,
                    agendaByDay = agendaByDay,
                    visibleDays = visibleDays,
                    sectionCount = sectionCount,
                    sectionHeight = sectionHeight,
                    style = style,
                    // 之前这个参数没人传（恒 { false }），假期压淡与「假」角标永远不出现。
                    holidayForDay = { dayOfWeek -> holidayOf(pageWeek, dayOfWeek) },
                    onCourseClick = onCourseClick,
                    onAgendaClick = onAgendaClick,
                    onLongPressEmptySlot = onLongPressEmptySlot,
                    modifier = Modifier.weight(1f),
                    material = material,
                    cardGlassBackdrop = cardGlassBackdrop,
                )
            }
        }
    }
}

// 周网格底部避让：改用共享坞避让（LocalGlassDockScrollRelief）+ 今浮钮动态避让，
// 不再无条件留固定的 64dp（那会在本周/无浮钮时也顶出空隙）。

/**
 * **保活但不参与绘制 / 命中 / 无障碍焦点**的修饰器（日视图展开层专用）。
 *
 * 为什么需要它：展开层收起后如果直接不组合，下一次展开又要在动画起步帧重建整棵树
 *（pager、滚动位置、两层录像带全丢）。反过来，若只把子树的绘制关掉、仍让它参与命中，
 * 隐藏的日视图会把周视图的点击全部吞掉。这里用 `layout(0, 0) { }`：
 * 子树**照常测量**（组合与布局状态都保留），只是不 place —— 不绘制、不进命中测试；
 * `clearAndSetSemantics {}` 再把语义清掉，读屏也不会聚焦到一块看不见的页面上。
 *
 * [active] 为真时是 no-op（直接返回 this），所以真展开时的布局与未加修饰器逐像素一致。
 */
private fun Modifier.inertUnless(active: Boolean): Modifier =
    if (active) {
        this
    } else {
        this
            .clearAndSetSemantics { }
            .layout { measurable, constraints ->
                measurable.measure(constraints)
                layout(0, 0) { }
            }
    }

/** 某周某天的真实日期（Dart `timetable_weekday_header.dart:_dateForWeekDay`）。 */
fun dateForWeekDay(semesterStart: LocalDate?, week: Int, dayOfWeek: Int): LocalDate? =
    TimetableDateLogic.dateForWeekDay(semesterStart, week, dayOfWeek)

/**
 * 按开学日算出的「真实当前周」；学期未配置或超出周数范围返回 null。
 *
 * 对齐 Dart `_resolveCurrentSemesterWeek`：开学日先归一化到周一，
 * `(今天 - 周一)/7 + 1`，越界即 null（此时「回本周」浮钮不出现）。
 */
fun currentSemesterWeek(semesterStart: LocalDate?, totalWeeks: Int, today: LocalDate): Int? =
    TimetableDateLogic.currentSemesterWeek(semesterStart, totalWeeks, today)

/**
 * 整周的考试/日程落格（Dart `_agendaEntriesFor`）：逐天算日期再映射节次。
 *
 * 学期开始日未设置时返回空——与星期栏圆点同口径，避免「有点没卡」或
 * 「有卡没点」两边打架。
 */
fun buildAgendaByDay(
    week: Int,
    semesterStart: LocalDate?,
    visibleDays: List<Int>,
    sectionTimes: List<SectionTime>,
    exams: List<Exam>,
    scheduleItems: List<ScheduleItem>,
    now: LocalDateTime,
    style: WeekViewStyle,
): Map<Int, List<WeekAgendaCardModel>> {
    if (semesterStart == null) return emptyMap()
    if (!style.showWeekGridExams && !style.showWeekGridSchedules) return emptyMap()
    return visibleDays.associateWith { dayOfWeek ->
        val date = dateForWeekDay(semesterStart, week, dayOfWeek)
            ?: return@associateWith emptyList()
        WeekAgendaLogic.resolve(
            date = date,
            sections = sectionTimes,
            exams = exams,
            scheduleItems = scheduleItems,
            now = now,
            showExams = style.showWeekGridExams,
            showSchedules = style.showWeekGridSchedules,
        )
    }
}

/**
 * 在本页停留期间把状态栏图标切成浅色 / 深色，离开时还原。
 *
 * 为什么是命令式：Compose 没有 `AnnotatedRegion<SystemUiOverlayStyle>` 的等价物，
 * 系统栏外观的唯一入口是窗口的 insets controller。壳只在自己的明暗主题变化时设置
 * 一次（`PagesShellActivity.applyShellSystemBars` / `ComposeP1Activity`），不区分
 * 当前是哪一页、也不知道壁纸颜色 —— 所以首页要把「壁纸上的墨色」临时覆盖上去，
 * 并在 `onDispose` 还原，否则去别的页面后状态栏会一直停在壁纸那一档。
 *
 * 做法与设置页 `AppearanceEditorScreen.ApplyLightSystemBarIcons` 相同（那一份是
 * private，跨不了文件）；这里不另造机制。
 *
 * @param lightIcons 图标是否用深色（= 浅底）。
 * @param themeDark 只作为「重新应用」的触发键：主题切换时 Activity 会按主题重设一次
 *   系统栏，而有壁纸时 [lightIcons] 不随主题变，不重挂就会被覆盖回去。
 */
@Composable
private fun ApplyStatusBarInk(lightIcons: Boolean, themeDark: Boolean) {
    val view = LocalView.current
    val context = LocalContext.current
    DisposableEffect(view, lightIcons, themeDark) {
        val window = context.findHostActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val previous = controller?.isAppearanceLightStatusBars
        controller?.isAppearanceLightStatusBars = lightIcons
        onDispose {
            if (controller != null && previous != null) {
                controller.isAppearanceLightStatusBars = previous
            }
        }
    }
}

/**
 * 从 `LocalContext` 往上找宿主 `Activity`。
 *
 * 不能直接 `context as? Activity`：Activity 里的 Compose 上下文经常是
 * `ContextThemeWrapper`（主题包了一层），直接转型会得到 null、系统栏一句话都设不上。
 */
private fun Context.findHostActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}