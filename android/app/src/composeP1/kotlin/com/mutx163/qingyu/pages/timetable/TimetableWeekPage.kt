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
import androidx.compose.foundation.ScrollState
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
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.core.view.WindowCompat
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.BackToTodayFab
import com.mutx163.qingyu.components.FAB_SHADOW_REACH_DP
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.timetable.day.DAY_VIEW_TOP_SEAM_DP
import com.mutx163.qingyu.pages.timetable.day.DayViewDataAssembler
import com.mutx163.qingyu.pages.timetable.day.DayViewSharedFreeSource
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.pages.timetable.day.LocalDayViewSharedFree
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayGlassBackdrop
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayInkBands
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayWallpaperBackdrop
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayTransitionSettled
import com.mutx163.qingyu.pages.timetable.day.LocalEmbeddedDayUnderlapBand
import com.mutx163.qingyu.pages.timetable.month.MonthMetrics
import com.mutx163.qingyu.pages.timetable.month.MonthWeekdayHeader
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.widgetdata.CoupleOverlay
import kotlin.math.max
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import java.time.LocalDate
import java.time.LocalDateTime
import androidx.compose.ui.tooling.preview.Preview
import com.mutx163.qingyu.components.QingyuPageTheme
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
    /**
     * 情侣课表叠加（B1 第二阶段，2026-11-06）。非 null 时周网格把对方课按周偏移叠进来，
     * 情侣三色优先于统一卡片颜色；null = 完全现行为（未绑定 / 预览）。
     */
    coupleOverlay: CoupleOverlay? = null,
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
    /**
     * 外层底栏 Pager 是否**仍在 spring 滑行**（默认 `false` = 未接线，行为与今天一致）。
     *
     * 为什么页面需要知道：月视图过渡以前只按 [daySwitchAnimate] 判断，于是**连点底栏**那一刻
     * 外层 Pager 还在 spring 滑行、页内又同时播 360ms tween —— 这是**已知的一条叠加路径**
     * （两段位移各动一半，画面像被拽了两次）。
     *
     * ⚠️ 接线后**是否真在叠加那一帧生效属未验证假设**：它依赖壳侧父级 `SideEffect` 写
     * `isScrollInProgress` 与子组合 `LaunchedEffect` 启动的先后顺序 —— 本 effect 的键变化要等
     * 一次重组才生效，effect 重进之前可能已经播了 1~2 帧 tween。**真机未验**，别把这里当已验过。
     *
     * 判据是纯函数（[MonthSwitchMotion.shouldSnap]，JVM 单测在 `MonthSwitchMotionTest`），
     * 本页只负责把布尔喂进去。壳侧由 `PagesShellActivity` 传 `pagerState.isScrollInProgress`、
     * 经 `ShellWiring` 下传到 `TimetableHost`。
     *
     * ⚠️ **没接线时默认 `false`** ⇒ `shouldSnap` 的这一项恒不成立，周 / 日 / 月的全部行为与接线前
     * 完全一致（不会因为新增参数悄悄改掉任何存量路径）。
     */
    homePagerScrolling: Boolean = false,
    /** 点了星期栏某一天 / 翻到另一周某一天。宿主据此切到日视图并记住选中日。 */
    onSelectDay: (week: Int, dayOfWeek: Int) -> Unit = { _, _ -> },
    /** 日视图摘要卡上的关闭叉（收回周视图）。 */
    onCloseDay: () -> Unit = {},
    /**
     * 日视图正文（整屏尺寸的页面），由壳注入。
     *
     * 参数①是「本页顶栏玻璃带的高度」；2026-11-08 起首页展开层传 `0.dp`，
     * 带高改经 [LocalEmbeddedDayUnderlapBand] 提供给日页列表做下穿留白
     *（面板由本页向上接到屏幕顶，顶栏 / 星期栏仍由本页画）。参数②是摘要卡飞行
     * 修饰器，壳必须原样挂到真摘要卡上。
     */
    dayContent: (@Composable (contentTop: Dp, summaryModifier: Modifier) -> Unit)? = null,
    /**
     * 当前是不是**月视图页内态**（`c1.week` 的第三种态，与 [dayMode] 互斥）。
     *
     * 为 true 时本页不画星期栏、周 pager 与日展开层，只保留顶栏玻璃带，
     * 把 [monthContent] 铺在顶栏下方 —— 壁纸仍由本页最底层那一份静态画，
     * 所以周 / 日 / 月三态切换不会带动壁纸。
     */
    monthMode: Boolean = false,
    /** 顶部角格显示的月份（只月份，不带年份；由月页翻月落定后回传）。 */
    monthLabel: String? = null,
    /** 月网格选中的日期；顶部星期栏据此显示选中周与选中日。 */
    monthSelectedDate: LocalDateTime? = null,
    /** 月视图正文（由宿主注入 `ShellPageContent("c2.month", monthEmbedded = true)`）。 */
    monthContent: (@Composable () -> Unit)? = null,
    /**
     * 周视图滚动体的可选外层（首页下拉快捷导入用）。
     *
     * 只包「玻璃带下方那一块」：指示器才会长在星期栏底下，而不是压到状态栏上
     * （包整页时 miuix 的表头被正文盖住，等于隐形）。日/月/预览分支不经过它。
     */
    weekScrollWrapper: (@Composable (content: @Composable () -> Unit) -> Unit)? = null,
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
    /**
     * 预览里**单独放开**「点星期栏 → 日视图」这一条交互（2026-11-10 用户指令：
     * 课程卡片设置页顶部预览，点星期栏要能像真首页一样切到日视图）。
     *
     * 只影响 [previewMode] 下 `onDayClick` 的那一支（`previewMode` 的其它封禁不变：
     * 顶栏/状态栏留白、周次选择弹窗、回本周浮钮、课卡点击、长按加课、pager）。
     * 默认 `false` = 预览里星期栏仍只作列头，其它预览调用点行为零变化。
     */
    previewAllowsDaySwitch: Boolean = false,
    /**
     * 预览里的节高基准（首页网格可用高，dp）。
     *
     * 2026-11-08：预览窗口只有 4 行高，但行高必须与首页一致。预览分支把这份基准转给
     * [WeekPageContent]，让「自动充满」按首页算、而不是按 4 行高的窗口除 12 节
     *（那会得到 27dp/行，正是 2026-11-04 被否掉的「逐节压扁」）。
     * null = 以自己的盒子为基准（真页面口径）。
     */
    previewSectionBasisDp: Dp? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val coroutineScope = rememberCoroutineScope()

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

    // 翻页 → 通知宿主（Dart `commitPendingWeek`：**停稳后**写回 provider.currentWeek）。
    //
    // ⚠️ 2026-11-05 修「左右滑不跟手 / 滑了半天没反应」：原来收的是裸
    // `snapshotFlow { currentPage }`，而 pager 的 `currentPage` 在**拖动过半就翻**，
    // 于是回调落在「手指还按在屏上」的那一帧。回调链是
    // `onWeekChanged` → `ShellWiring` 的 `repository.setCurrentWeek()` →
    // `TimetableRepository.persistActiveProfileState()`：**同步**把整份档案
    // （全部课表 + 设置）序列化后写盘 4 次，同时改 Compose 状态让首页宿主整棵重组。
    // 一次滑动里每跨一页就来一遍 ⇒ 拖到临界点整页冻住、松手或再滑才"跟上来"。
    // 现在与日视图那条 `if (scrolling) return` 同款：停稳才提交；
    // `committedPage` 去重，免得「拖出去又拖回原页」用同一个周次再写一次盘，
    // 也免得进页首帧就把刚读到的周次原样写回去（旧写法每次开页都多一次整档落盘）。
    LaunchedEffect(pagerState) {
        var committedPage = pagerState.currentPage
        snapshotFlow { pagerState.currentPage to pagerState.isScrollInProgress }
            .collect { (page, scrolling) ->
                if (scrolling) return@collect
                if (page == committedPage) return@collect
                committedPage = page
                onWeekChanged(page + 1)
            }
    }

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

    // 「当前在看的周」= 星期栏同一个**落定页**（`chromeDisplayedPage`），不是 pager 的 `currentPage`。
    // `currentPage` 在拖动过半就翻：拿它算「回本周」浮钮可见性与底部余量，会让浮钮出入场、
    // 每页内距在拖动中途突变一帧；星期栏早就改用 displayedPage，这里统一过来。
    val browsingWeek = displayedPage + 1

    // ── 每周一个纵向滚动控制器（对齐发布版 `_weekGridScrollKey` / `PageStorageKey` 口径）──
    // pager 离屏后会销毁页内容，`rememberScrollState()` 建在页内 ⇒ 划到相邻周再看回来就弹回顶部
    // （发布版是「下周看一眼再回来仍停在第 8 节」）。控制器因此活在 pager 外层、按周次取。
    // 只存 ScrollState（每页几十字节），页数上限就是总周数，不会无界增长。
    // 走 [WeekScrollStatesSaver]：切深色模式这类 Activity 重建后位置也能恢复（只存偏移量，
    // ScrollState 实例重建——它不是 Bundle 可存类型，身上的动画/手势状态本来也不该跨重建）。
    val weekScrollStates = rememberSaveable(saver = WeekScrollStatesSaver) {
        mutableMapOf<Int, ScrollState>()
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
    // 日视图实时选中桥：DayViewPage 分页器把「当前页」写进来，星期栏读它 → 选中高亮即时跟手、
    // 蓝条平滑滑动（只驱动显示，不落盘）。
    // 关键：桥在**组合期**用 `remember(dayVisible)` 播种 —— 进入日视图那一帧就以「宿主当前选中」
    // 建桥，避免先记住旧值导致首帧错位/蓝条从左边滑一下（不用组合后才跑的 LaunchedEffect 播种）。
    val daySelectionBridge = remember(dayVisible) {
        DaySelectionBridge().also { it.update(selectedWeek, selectedDayOfWeek) }
    }
    // 展开/收起过渡是否**已落定**（dayExpand 到终值）：布尔只在跨过 0.999 时翻一次，
    // 动画期间不逐帧重组。日视图拿它门控「回今日」浮钮——过渡期间不显示、不随转场位移，
    // 落定后再按共用件自带的 fadeIn+scaleIn 淡入（与周视图「回本周」同一份出场动效）。
    val dayExpandSettled by remember {
        derivedStateOf { currentDayMode && dayExpand.value >= 0.999f }
    }

    // ── 月视图页内态的横向滑入 / 滑出（与日视图共用时长与缓动）──
    // 三视图归一成 c1.week 后，Dock Pager 不再为月视图翻页；如果不补这一层，
    // 底栏从周/日切到月会“瞬间换字”（2026-11-07 用户实报）。
    val currentMonthMode by rememberUpdatedState(monthMode)
    var monthMounted by remember { mutableStateOf(monthMode) }
    val monthExpand = remember { Animatable(if (monthMode) 1f else 0f) }
    val monthVisible by remember {
        derivedStateOf { currentMonthMode || monthExpand.value > 0f }
    }
    // 月层子树是否**已完成至少一次组合**：由月层里的 [MonthContentMountSignal] 在组合落地后
    // 置真，月层卸载时清回假 —— 下一次打开要重新等这一下。
    var monthContentComposed by remember { mutableStateOf(false) }
    // ⚠️ 键里必须带 `monthContentComposed`：打开方向要靠它分两步走（先挂树 → 等首组合 → 再开播）。
    // 键只写 `monthMode` 就等于「首组合和动画第一帧挤同一帧」——正是本轮要修的那 1~2 帧空。
    // ⚠️ 键里还必须带 `homePagerScrolling`（2026-11-12 修 M1）：它是 `shouldSnap` 的第三个判据，
    // 判据读了、键里却没有 ⇒ 外层 Pager 从静止开始滑（false → true）时本 effect 不重进，
    // 「接线后在叠加那一帧生效」就只是没验证过的假设。键带上它之后**不会重播、也不会抖**，
    // 因果可以按下面两个分支逐条复核（不是结论式描述）：
    //   · 键变化重进时，若 `monthExpand.value` 已等于 `target`（例如此前刚 `snapTo` 过、或本来
    //     就是 1/0），会落到 `else if (monthExpand.value != target)` 的**假**分支 ⇒ 整段不调
    //     `animateTo`，只有 value 与目标不等时才会走到下面的 `animateTo`；
    //   · 若外层在 `animateTo` 播到一半时开始滑：键变 ⇒ 本 effect 的协程被取消（正在跑的
    //     `animateTo` 一起取消），重进后 `MonthSwitchMotion.shouldSnap(...)` 为真 ⇒
    //     `monthExpand.snapTo(target)` 把值直接拉到终点；外层滑行结束时键再变回 false、
    //     effect 再重进一次，此时 `value == target` ⇒ 又落到上面那个假分支，不会二次开播。
    // 仍未验证（别把这两条因果当成「实机已验」）：键变化要等一次重组才生效，而壳侧是在父级
    // `SideEffect` 里写 `isScrollInProgress` 的 —— effect 重进之前可能已经播了 1~2 帧 tween。
    LaunchedEffect(monthMode, monthContentComposed, homePagerScrolling) {
        // ① 先挂树：下面几支都依赖月层已经在这棵树上（要等的信号也只能来自已挂上的树）。
        if (monthMode) monthMounted = true
        val target = if (monthMode) 1f else 0f
        if (MonthSwitchMotion.shouldSnap(dayExpandReducedMotion, daySwitchAnimate, homePagerScrolling)) {
            // ② 直接落定，不播逐帧形变。三条来源：
            //    a. 系统「减少动画」降级（与日视图同口径）；
            //    b. 调用方要求不播 —— 跨过周档的「日 ↔ 月」直达（`HomeViewSwitchMotion.directAcrossWeek`），
            //       播了会把淡出中的周网格露在中间；
            //    c. **外层底栏 Pager 仍在 spring 滑行** —— 页内再播 360ms tween 就是真叠加。
            // ⚠️ 这一支必须留在下面的 gate **之前**：底栏切月要当帧落定，不能被「先挂树」拖一帧。
            // 判据是纯函数 [MonthSwitchMotion.shouldSnap]（JVM 单测在 `MonthSwitchMotionTest`）。
            monthExpand.snapTo(target)
        } else if (
            MonthSwitchMotion.needsMountWait(monthMode, monthContentComposed, monthContent != null)
        ) {
            // ③ 打开方向 · 第一步：本帧只挂树，不启动横向滑入。
            // 月层是「换档下一帧才首次组合」（`monthMounted` 先置真、月层才挂树），若这里直接
            // `animateTo`，首组合 / 首测量就和 tween 第一帧挤在同一帧里 ⇒ 起步空 / 顿 1~2 帧。
            // 本帧面板刚组好，什么都不做；月层里的 [MonthContentMountSignal] 会在本帧组合落地后
            // 把 `monthContentComposed` 置真，键里带着它 ⇒ 本 effect 重进一次才走到下面的
            // `animateTo`，动画因此从**已经画好的树**上起步。
            // 等待期间 `monthExpand` 仍是 0（月层整体偏出一个屏宽），屏幕上没有可察觉的变化。
            // 兜底：`monthContent == null` 时不进这一支（见 [MonthSwitchMotion.needsMountWait]）——
            // 没有内容可挂就永远等不到信号，`monthVisible` 会一直是真、命中层一直吃事件，页面就点不动了。
        } else if (monthExpand.value != target) {
            // ④ 已经在终点就不白跑一趟协程：清假会让本 effect 因第二个键再进一次，
            // 那次 value 已等于目标（0→0），这里直接跳过，不重播一遍 animateTo。
            monthExpand.animateTo(
                targetValue = target,
                animationSpec = tween(
                    durationMillis = dayExpandDuration,
                    easing = dayExpandEasing,
                ),
            )
        }
        // ⑤ 收起**动画播完**后才把月层卸载（只在落定 value==0 且已非月模式时卸），
        // 不在收起动画中途卸，避免重组打断收起动画。
        // 「已组合过」的清假**不这里做**：`monthContentComposed` 是本 effect 的键，在体内写它
        // 会把自己取消重启；见下面独立的 `LaunchedEffect(monthMounted)`。
        if (!monthMode && monthExpand.value <= 0f) monthMounted = false
    }

    // 月层被卸载（`monthMounted` 真 → 假）后把「已组合过」清回假：下次打开必须重新挂树、
    // 重新等一次首组合信号，否则会拿着上一次的旧值直接开播，又变回首组合与首帧抢同一帧。
    // 单独立一个 effect：`monthContentComposed` 是上面那个计时 effect 的键，在那边体内写它
    // 会把正在跑的 animateTo 取消掉。这里只在「树真的卸了」之后清。
    LaunchedEffect(monthMounted) {
        if (!monthMounted) monthContentComposed = false
    }

    // 展开层是否**本次开合期间挂在树上**：打开时置真，收起动画播完就置假 ——
    // 即**不跨开合保活**。周浏览时没有日视图的布局 / effect 成本（R07，`417db2569` 的口径），
    // 代价是每次打开都要重新组合一次日视图整棵树，所以打开方向必须「先挂树、再播下推」
    // （见下方 `LaunchedEffect(dayMode, dayContentComposed)` 的第一步）。
    // 只有「从没打开过」或「已收起」才完全不组合（不占内存、不跑日视图的任何 effect）。
    //
    // ⚠️ 历史（2026-11-05 复核）：`ffb858ffd` 原本是「收起后保活、不再卸载整棵树」，
    // `417db2569` 为了让周视图左右滑不卡改成了收起即卸载，但那段「保活」注释和
    // `DayViewOverlayPerfWiringGuardTest` 的「保活」断言都没跟着改 —— 守卫因此咬不住真正
    // 被改掉的行为，永远是绿的。现在注释按实话写，守卫要咬的是「先挂载后启动」的时序。
    var dayLayerReady by remember { mutableStateOf(dayMode) }
    // 日视图子树是否**已完成至少一次组合**：由面板里的 [DayContentMountSignal] 在组合落地后
    // 置真，收起卸载时清回假 —— 下一次打开要重新等这一下。
    var dayContentComposed by remember { mutableStateOf(false) }
    LaunchedEffect(dayMode) {
        if (dayMode) dayLayerReady = true
    }
    // 展开层**是否留在树上**：可见时留；已挂载、但收起动画还在播的也留（动画得在原树上播完）。
    // 注意与 `dayVisible` 的分工：dayMounted 决定「组合/测量」，dayVisible 决定
    // 「绘制与命中」——隐藏时不画、不接事件（见下方展开层的 inert 门控）。
    val dayMounted = dayVisible || dayLayerReady

    // ⚠️ 键里必须带 `dayContentComposed`：打开方向要靠它分两步走。
    // 键只写 `dayMode` 就等于「首组合和动画第一帧挤同一帧」，正是本次要修的那一帧顿。
    LaunchedEffect(dayMode, dayContentComposed) {
        val expandTarget = if (dayMode) 1f else 0f
        if (dayExpandReducedMotion || !currentDaySwitchAnimate) {
            // 两条都直接落定、不播逐帧形变：
            // ① 系统「减少动画」降级（Dart `controller.value = 1/0` 同口径）；
            // ② **底栏 / 导航栏 / 跨页来源的切换**（`daySwitchAnimate = false`）——用户口径
            //   「底栏/导航栏就是左右滑」，绝不能再播从上往下的展开/收起；横向由外层 Pager
            //   负责，这里瞬时落定。
            // snap 后 value 恰为 1.0/0.0，下方落定判据当帧即成立，不存在中间帧。
            // ⚠️ 这一支必须留在下面的 gate **之前**：底栏切日要当帧落定，不能被「先挂树」拖一帧。
            dayExpand.snapTo(expandTarget)
        } else if (dayMode && !dayContentComposed && dayContent != null) {
            // ── 打开方向 · 第一步：先只挂树，不启动下推（2026-11-05 方案 1）──
            // 收起即卸载（见上面 `dayLayerReady` 的口径）⇒ 每次打开的那一刻，整棵日视图
            // （pager + 卡片 + 数据装配）都还一次没组合过。若这里直接 `animateTo`，
            // 首组合 / 首测量就和动画第一帧挤在同一帧里，表现为「从上往下」一开头顿一下。
            // 本帧面板刚组好，什么都不做；面板里的 [DayContentMountSignal] 会在本帧组合落地后
            // 把 `dayContentComposed` 置真，键里带着它 ⇒ 本 effect 重进一次才走到下面的
            // `animateTo`。中间这一帧用于测量 / 放置 / 绘制，动画因此从**已经画好的树**上起步。
            // 等待期间 `dayExpand` 仍是 0（面板高 4%、alpha 0），屏幕上什么都看不见。
            // 兜底：`dayContent == null` 时不进这一支（见上面的 gate 条件）——没有内容可挂就
            // 照旧直接播，否则 `dayVisible` 会一直是真、命中层一直吃事件，页面就点不动了。
        } else if (dayExpand.value != expandTarget) {
            // 已经在终点就不白跑一趟协程：收尾清假会让本 effect 因第二个键再进一次，
            // 那次 value 已等于目标（0→0），这里直接跳过，不重播一遍 animateTo。
            dayExpand.animateTo(
                targetValue = expandTarget,
                animationSpec = tween(durationMillis = dayExpandDuration, easing = dayExpandEasing),
            )
        }
        // 收起**动画播完**后把展开层卸载：日视图关闭后隐藏的 DayViewPage 不再常驻组合树，
        // 周浏览时省掉它的布局/effect 成本（R07 减负）。只在落定（value==0）且已非日模式时卸，
        // 不在收起动画中途卸，避免重组打断收起动画。
        // 「已组合过」的清假**不这里做**，见下面独立的 `LaunchedEffect(dayMounted)`：
        // 它是本 effect 的键，在本 effect 体内写它会把自己取消重启。
        if (!dayMode && dayExpand.value <= 0f) {
            dayLayerReady = false
        }
    }

    // 展开层被卸载（dayMounted 真 → 假）后把「已组合过」清回假：下次打开必须重新挂树、
    // 重新等一次首组合信号，否则会拿着上一次的旧值直接开播，又变回首组合与首帧抢同一帧。
    // 单独立一个 effect：`dayContentComposed` 是上面那个计时 effect 的键，在那边体内写它
    // 会把正在跑的 animateTo 取消掉。这里只在「树真的卸了」之后清。
    LaunchedEffect(dayMounted) {
        if (!dayMounted) dayContentComposed = false
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
    // ── 课卡「钻进星期栏底下」的两块（2026-11-08）──
    // 用户口径：课卡往上滑，插进星期栏以后就没了（硬切），而不是被玻璃糊住。
    // 根因见 `TimetableBandUnderlap` 的 KDoc：网格视口原来只到带子下沿。
    //
    // `bandHeightPxState`：带子真实高度（px）。首帧为 0 —— 这一帧不下穿、不录制，
    // 下一帧测量拿到真值。下穿量与滚动内容顶部的等高 Spacer 用的是同一个数，两者
    // 相抵，所以第 1 节始终停在带子下沿，不会因为这里晚一帧而跳一下。
    val bandHeightPxState = remember { mutableIntStateOf(0) }
    val bandStripMarginPx = with(density) { TIMETABLE_BAND_STRIP_MARGIN_DP.dp.roundToPx() }
    // 时间列宽（px）：第二遍玻璃**不录**这一列。
    //
    // 时间列是 34dp 宽、几乎只有深色小字、没有卡片底色。第二遍玻璃只做模糊、不染色，
    // 把这一列录进去以后，小字被高斯糊成一条连续黑灰带，读起来就是「左边节次时间表
    // 变超黑」（2026-11-08 用户实报）。它是坐标轴，不是内容：只让第一遍的
    // 「壁纸模糊 + 染色」盖住它，滑到带子下沿干净消失即可。
    val timeColumnWidthPx = with(density) { style.timeColumnWidthDp.dp.toPx() }
    val isRtlLayout = LocalLayoutDirection.current == LayoutDirection.Rtl
    // 录制层只录「带子那一条」（带高 + 下沿余量）：录制 = 整屏离屏重画一帧，而带子
    // 只需要它自己盖住的那几十 dp。`clipRect` 把重画范围夹住，条带以外的像素不下笔。
    // 自定义 `onDraw` 里 `drawContent()` 会被 miuix 重定向进图层（`LayoutNodeDrawScope.record`
    // 换的是绘制画布），和官方 `Modifier.layerBackdrop` 是同一条路。
    val bandStripBackdrop = rememberLayerBackdrop(
        onDraw = {
            // 必须先把 ContentDrawScope 抱出来：`clipRect` 的 lambda 会把隐式接收者换成
            // 普通 DrawScope，那里没有 `drawContent()`（K2 报 DSL_SCOPE_VIOLATION）。
            val content = this
            val strip = timetableBandStripPx(
                bandHeightPx = bandHeightPxState.intValue,
                marginPx = bandStripMarginPx,
                contentHeightPx = size.height.toInt(),
            )
            // 左边界从时间列右沿开始：节次时间列不进第二遍玻璃（见 `timeColumnWidthPx`）。
            // RTL 下时间列在右边，改成从右沿裁掉同样一列；否则会把网格裁掉、把时间列录进去。
            val left = if (isRtlLayout) 0f else timeColumnWidthPx.coerceIn(0f, size.width)
            val right = if (isRtlLayout) {
                (size.width - timeColumnWidthPx).coerceIn(0f, size.width)
            } else {
                size.width
            }
            if (strip > 0 && right > left) {
                clipRect(left, 0f, right, strip.toFloat()) { content.drawContent() }
            }
        },
    )
    // 日视图自己的条带录制层（2026-11-08）：日页列表也接到带子底下，第二遍玻璃要
    // 采到日卡。日页没有时间列，所以整条都录。只有日视图落定后才把它交给带子
    //（展开/收起过程中面板的裁剪高度还在变，采到的是半条，交界会发黑）。
    val dayStripBackdrop = rememberLayerBackdrop(
        onDraw = {
            val content = this
            val strip = timetableBandStripPx(
                bandHeightPx = bandHeightPxState.intValue,
                marginPx = bandStripMarginPx,
                contentHeightPx = size.height.toInt(),
            )
            if (strip > 0) {
                clipRect(0f, 0f, size.width, strip.toFloat()) { content.drawContent() }
            }
        },
    )
    // 预览不参与：预览框是独立窗口，往上顶会画出框外。
    val bandStripActive = bandBlurActive && !previewMode
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
    // 月视图的顶部星期栏：默认跟今天，选中某天后跟那一天所在的周。
    val monthHeaderDate = monthSelectedDate?.toLocalDate() ?: todayDate
    val monthHeaderWeek = WeekCalculator.weekForDate(
        date = monthHeaderDate.atStartOfDay(),
        semesterStart = semesterStart?.atStartOfDay(),
        semesterWeekCount = totalWeeks,
        fallback = displayedPage + 1,
    )
    val monthHeaderDayOfWeek = monthSelectedDate?.dayOfWeek?.value

    // 单节课提醒键（`courseId|yyyy-MM-dd`）：课卡右上角铃铛的唯一数据源
    //（`core/TimetableSettings.classReminders`，随仓储快照进来）。
    val reminderKeys = remember(settings.classReminders) {
        settings.classReminders.map { it.key }.toSet()
    }
    val realCurrentWeek = currentSemesterWeek(semesterStart, totalWeeks, todayDate)
    val showBackToCurrentWeek = !monthMode && style.showBackToCurrentWeek &&
        realCurrentWeek != null &&
        realCurrentWeek != browsingWeek

    // 浮钮与玻璃坞同一档：真有壁纸 + 设备支持 runtime shader + 坞本身是玻璃材质。
    // 只是「要不要录整屏」的判据；真正的档位判断在共用件里再做一次。
    // 预览模式不录：挖洞预览里的浮钮只是「看样式 / 看不透明度」的替身，
    // 为它整页离屏重画一帧不值得（预览里改用壁纸录像层，见下方 BackToTodayFab）。
    val floatingGlassActive = !previewMode && showBackToCurrentWeek && !dayVisible &&
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
                modifier = Modifier
                    // 带子画在网格**之后**：网格顶上来以后，玻璃得盖住钻进去的那一截。
                    .zIndex(1f)
                    // 带高是下穿量 / 顶部 Spacer / 录制条带三处的共同基准，量一次给三处用。
                    .onSizeChanged { bandHeightPxState.intValue = it.height },
                // 第二遍玻璃只糊「带子底下正在穿过去的内容」，不染色（第一遍已经铺底）。
                // 日视图落定后采日页条带（日卡钻到带子底下）；其余时候采周网格条带。
                // 日页展开/收起过程中不采它：面板裁剪高度还在变，条带只录到半截，
                // 带子下沿会采到透明像素、读成一条发黑的边。
                underlayBackdrop = if (dayVisible && dayExpandSettled) {
                    dayStripBackdrop.takeIf { bandStripActive }
                } else {
                    bandStripBackdrop.takeIf { bandStripActive }
                },
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
                            // 「更多」玻璃球的采样源 = 顶栏玻璃带自己在用的那一层（同一个对象）。
                            backdrop = pageBackdrop,
                        )
                    }

                    // ── 星期栏：从 pager 里提出来，不跟横向翻页滑动 ──
                    // 显示「落定后的那一页」；滑动过程中保持上一页（见 displayedPage）。
                    // 日视图展开时改跟「日视图正在看的那一周/那一天」：日视图可以连续翻周，
                    // 而周 pager 停在下面不动，继续读 displayedPage 会把星期栏钉在旧周上。
                    TimetableWeekdayHeader(
                        // 2141：不再需要飞行起点测量。
                        week = if (monthMode) {
                            monthHeaderWeek
                        } else if (dayVisible) {
                            selectedWeek
                        } else {
                            displayedPage + 1
                        },
                        currentWeek = currentWeek,
                        todayDate = todayDate,
                        semesterStartDate = semesterStart,
                        visibleDays = visibleDays,
                        // 跨周平移时把页号夹在学期内（末周不会画出第 N+1 周）。
                        totalWeeks = totalWeeks,
                        style = style,
                        // 星期栏压在**壁纸**上才谈壁纸墨色：实体档的带子是不透明的页底色条，
                        // 底下根本没有壁纸（Dart `homePageWeekdayBarOverWallpaper`，
                        // `home_page_region_blur.dart:332-347`）。以前无脑传会得到
                        // 「浅色实心带 + 白色字」。
                        wallpaperLuminance = wallpaperBands?.weekday?.takeIf {
                            bandOverWallpaper
                        },
                        timeColumnWidth = style.timeColumnWidthDp.dp,
                        // 月视图：同一条星期栏、同一套列宽/左右位置；只把左端周次换成月份，
                        // 并把日期/今天/考试点关掉。
                        monthMode = monthMode,
                        monthLabel = monthLabel,
                        // 日视图用强调色标出正在看的那一天（Dart 同一条栏、同一个高亮）；
                        // 周视图不标。
                        selectedDayOfWeek = if (monthMode) {
                            monthHeaderDayOfWeek
                        } else {
                            selectedDayOfWeek.takeIf { dayVisible }
                        },
                        // 日视图改读分页器实时选中（即时跟手 + 蓝条平滑滑动）；周视图 / 预览为 null。
                        selectionBridge = if (!monthMode && dayVisible) daySelectionBridge else null,
                        hasExamOnDate = hasExamOnDate,
                        hasScheduleOnDate = hasScheduleOnDate,
                        // 周视图：点哪天 = 从周视图展开到那一天（不再推 c3.day 路由）。
                        // 日视图：点另一天 = 在同一展开层里换日；点**当前这一天** = 收起
                        //（Dart `DayViewTransitionController.toggle` 的
                        // `sameSelectionCloses = true`，底栏与星期栏同一条口径）。
                        onDayClick = { dayOfWeek ->
                            when {
                                // 预览 / 月视图：星期栏只作列头，点它不切视图。
                                // 例外（2026-11-10）：课程卡片设置页的预览显式要「点星期栏切日视图」，
                                // 由 `previewAllowsDaySwitch` 单独放开；其余预览调用点仍走原封禁。
                                (previewMode && !previewAllowsDaySwitch) || monthMode -> Unit
                                dayMode && dayOfWeek == selectedDayOfWeek -> onCloseDay()
                                dayMode -> onSelectDay(selectedWeek, dayOfWeek)
                                else -> onSelectDay(displayedPage + 1, dayOfWeek)
                            }
                        },
                        onWeekTitleClick = {
                            // 预览 / 月视图不弹周次选择。
                            if (!previewMode && !monthMode) showWeekSelectorDialog = true
                        },
                    )
                }
            }

            // ── 情侣「共同空闲」数据源（日视图摘要卡消费）──────────────────────────
            //
            // 摘要卡在 `DayViewPage` → `DayViewScrollContent` 深处，拿不到我的课 / 对方课 /
            // 周偏移 / 节次表，所以由本页（唯一同时握有这四样的地方）装配好、经
            // `LocalDayViewSharedFree` 交下去，卡里按「周次 + 星期 + 是否今天」现算。
            //
            // null = 不渲染模块：没绑定 / 没开叠加 / 预览（预览本就不叠情侣课，见上面
            // `coupleOverlay = null`）—— 与发布版 `_isCoupleOverlayActive` 同口径。
            val sharedFreeSource = remember(courses, coupleOverlay, sectionTimes) {
                coupleOverlay?.let { overlay ->
                    DayViewSharedFreeSource(
                        myCourses = courses,
                        partnerCourses = overlay.partnerCourses,
                        partnerWeekOffset = overlay.weekOffset,
                        sections = sectionTimes,
                        partnerImportedAtMillis = overlay.partnerImportedAtMillis,
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
                    // 预览：单周、不接 pager（预览不可横滑），也不淡出。
                    //
                    // 2026-11-08 修正：预览不再把整页当一条长纸带滚（那样一滑就把星期栏
                    // 顶出窗口、第一行变成随手滑到的某一节）。现在是「窗口高 = 预览框」：
                    // 星期栏在玻璃带里钉住，只有下面这个盒子的网格自己上下滚。
                    //
                    // 节高仍按**首页**算：`previewSectionBasisDp` 是壳算好的「首页网格可用高」，
                    // 传下去交给 `weekSectionHeight`——不能拿这个 4 行高的盒子去除节数
                    //（12 节会压成 27dp 一行，正是 2026-11-04 被否掉的「逐节压扁」）。
                    // 预览自己的滚动状态（就地 remember，不进真页的按周池子）——2026-11-08 起它
                    // 就是「网格自己滚」那一层的手柄。
                    val previewScrollState = rememberScrollState()
                    // 每次进页从顶部开始（`rememberScrollState` 是带保存恢复的，
                    // 结构性重建会把上一次滑到的位置带回来；星期栏虽然钉住了，
                    // 但“进页就该看到第 1 节”是预览的约定）。
                    LaunchedEffect(Unit) { previewScrollState.scrollTo(0) }
                    WeekPageContent(
                        pageWeek = initialWeek,
                        // 预览用**独立**的滚动状态，不进 `weekScrollStates`：
                        // 那是首页真页按周保留位置的池子，预览滚一下不该改写首页那一周的位置。
                        scrollState = previewScrollState,
                        semesterStart = semesterStart,
                        reminderKeys = reminderKeys,
                        visibleDays = visibleDays,
                        courses = courses,
                        // 外观编辑页预览不叠加情侣课（与日视图预览「不受绑定影响」同口径）。
                        coupleOverlay = null,
                        style = style,
                        sectionTimes = sectionTimes,
                        sectionCount = sectionCount,
                        // 行高与首页逐像素对齐（2026-11-08）。
                        sectionHeightBasisDp = previewSectionBasisDp,
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
                        bottomClearanceDp = 0.dp,
                    )
                } else {
                    val weekPager: @Composable () -> Unit = {
                    HorizontalPager(
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
                                monthVisible && monthContent != null -> Modifier.graphicsLayer {
                                    val progress = dayExpandEasing.transform(monthExpand.value)
                                    translationX = -progress * size.width.toFloat()
                                    alpha = (1f - progress).coerceIn(0f, 1f)
                                }
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
                        // 按周次取控制器：pager 销毁页内容后，翻回来仍停在原来那一节
                        // （发布版 `_weekGridScrollKey` / `PageStorageKey` 同口径）。
                        scrollState = weekScrollStates.getOrPut(page + 1) { ScrollState(0) },
                        semesterStart = semesterStart,
                        reminderKeys = reminderKeys,
                        visibleDays = visibleDays,
                        courses = courses,
                        coupleOverlay = coupleOverlay,
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
                        // 网格顶上去了多少（= 带高）：滚动内容顶部补等高留白，第 1 节仍停在
                        // 带子下沿；节高计算再把这截减回去（见 `WeekPageContent`）。
                        underlapHeightDp = if (bandStripActive) {
                            with(density) { bandHeightPxState.intValue.toDp() }
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
                    }
                    // ── 周网格：向上顶进玻璃带底下（2026-11-08）──
                    // 用户口径：课卡往上滑到星期栏就没了，看不到它「钻进去」。
                    // 这里把视口向上接出去一截（量高不动外层布局），并给第二遍玻璃
                    // （带子的 `underlayBackdrop`）录一条只含「带子那一块」的采样层。
                    val weekGrid: @Composable () -> Unit = {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .bandUnderlap {
                                    if (bandStripActive) bandHeightPxState.intValue else 0
                                },
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .then(
                                        if (bandStripActive) {
                                            Modifier.layerBackdrop(bandStripBackdrop)
                                        } else {
                                            Modifier
                                        },
                                    ),
                            ) {
                                weekPager()
                            }
                        }
                    }
                    if (weekScrollWrapper != null) weekScrollWrapper(weekGrid) else weekGrid()
                }

                // ── 日视图展开层（2026-11-04 用户口径：全宽 + 从上往下展开 + 壁纸页面级静态不动）──
                // 只做「高度从顶部往下长大露出」：全宽面板、Alignment.TopCenter、heightFactor 裁剪窗口。
                // 不做按当天列的水平锚点 / 宽度收缩，也**不做垂直位移**——内容与壁纸都钉在顶部，
                // 避免带动壁纸上下动；壁纸由页面级最底层那层静态画（见上方 `backdrop`）。
                if (!monthVisible && dayMounted && dayContent != null) {
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
                                // 日页也接到带子底下（2026-11-08）：横滑展开时面板是全高，
                                // 多量一截带高并向上移，列表才能滑进玻璃带。
                                // 只在带子真的画玻璃时下穿：实体档没有第二遍采样，下穿只会
                                // 把内容藏到不透明色条底下（与周网格 `bandStripActive` 同口径）。
                                .bandUnderlap {
                                    if (dayVisible && bandStripActive) bandHeightPxState.intValue else 0
                                }
                                .clipToBounds()
                                .graphicsLayer {
                                    translationX =
                                        -(1f - dayExpandEasing.transform(dayExpand.value)) * size.width.toFloat()
                                }
                                .then(hitGate),
                        ) {
                            CompositionLocalProvider(
                                LocalDayViewSharedFree provides sharedFreeSource,
                                LocalEmbeddedDayGlassBackdrop provides cardGlassSource,
                                // 壁纸亮度带：嵌入的日页自己不画壁纸，量不到亮度（2026-11-09）——
                                // 把本页已经量好的那一份交给它，空态 / 卡片才能按壁纸翻黑白。
                                LocalEmbeddedDayInkBands provides wallpaperBands,
                                LocalEmbeddedDayTransitionSettled provides dayExpandSettled,
                                LocalEmbeddedDayWallpaperBackdrop provides pageBackdrop,
                                LocalDaySelectionBridge provides daySelectionBridge,
                                LocalEmbeddedDayUnderlapBand provides if (bandStripActive) {
                                    with(density) { bandHeightPxState.intValue.toDp() }
                                } else {
                                    0.dp
                                },
                            ) {
                                DayStripHost(backdrop = dayStripBackdrop.takeIf { bandStripActive }) {
                                    // 首组合打点（两支都要有）：组合落地后置真 ⇒ 外面那个 effect
                                    // 重进一次才开播。写重复值不进快照（结构化相等），不会多一轮重组。
                                    DayContentMountSignal { dayContentComposed = true }
                                    dayContent(0.dp, Modifier)
                                }
                            }
                        }
                    } else {
                        // 上下翻（点星期栏某天 / 页内关闭）：原 heightFactor 顶部往下展开，几何不动。
                        //
                        // ⚠️ 读值时机（2026-11-05）：高度 / 圆角 / 面板 alpha 原先都在**组合期**
                        // 从 `dayExpand.value` 换算，于是 360ms 转场里本页组合体逐帧重组、
                        // 连带日视图整棵子树每帧重新测量。现在按「谁用谁读、读在该读的阶段」分开：
                        //  · 高度 → 测量期（[expandPanelGeometry] 的 layout 块）；
                        //  · 圆角 → 绘制期（同一个 graphicsLayer 的 shape / clip）；
                        //  · 面板 alpha → 绘制期（[panelAlpha] 是 derivedStateOf 委托，
                        //    只在下面那个 `graphicsLayer{}` 块里取值，组合期不订阅）。
                        // 数值 / 曲线 / 时长一律没变，逐帧观感与改前一致。
                        val panelAlpha by remember {
                            derivedStateOf {
                                val progress = dayExpandEasing.transform(dayExpand.value)
                                homeViewEaseOutCubic(progress)
                            }
                        }
                        BoxWithConstraints(
                            modifier = Modifier
                                .matchParentSize()
                                // 日页也接到带子底下（2026-11-08）：多量一截带高、向上平移。
                                // 上报尺寸不变，展开窗口的几何账仍按原内容区算。
                                // 与周网格同口径：只有带子真画玻璃时才下穿。
                                .bandUnderlap {
                                    if (dayVisible && bandStripActive) bandHeightPxState.intValue else 0
                                }
                                .clipToBounds()
                                .then(hitGate),
                        ) {
                            val maxW = maxWidth
                            val maxH = maxHeight
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopCenter)
                                    .width(maxW)
                                    .expandPanelGeometry(
                                        easedProgress = { dayExpandEasing.transform(dayExpand.value) },
                                        maxHeight = maxH,
                                        // 面板向上多出来的那一截（带高）：高度账里把它固定加上，
                                        // 下沿仍按原进度长；band 那截被玻璃盖住。
                                        underlap = if (bandStripActive) {
                                            with(density) { bandHeightPxState.intValue.toDp() }
                                        } else {
                                            0.dp
                                        },
                                    ),
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
                                        LocalDayViewSharedFree provides sharedFreeSource,
                                        LocalEmbeddedDayGlassBackdrop provides cardGlassSource,
                                        // 同横滑支：日页不画壁纸 ⇒ 用本页量好的亮度带。
                                        LocalEmbeddedDayInkBands provides wallpaperBands,
                                        LocalEmbeddedDayTransitionSettled provides dayExpandSettled,
                                        LocalEmbeddedDayWallpaperBackdrop provides pageBackdrop,
                                        LocalDaySelectionBridge provides daySelectionBridge,
                                        LocalEmbeddedDayUnderlapBand provides if (bandStripActive) {
                                            with(density) { bandHeightPxState.intValue.toDp() }
                                        } else {
                                            0.dp
                                        },
                                    ) {
                                        DayStripHost(backdrop = dayStripBackdrop.takeIf { bandStripActive }) {
                                            // 首组合打点（两支都要有）：组合落地后置真 ⇒
                                            // 外面那个 effect 重进一次才开播。
                                            DayContentMountSignal { dayContentComposed = true }
                                            dayContent(0.dp, Modifier)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 月视图页内态：横向滑入 / 滑出层 ──
                // 与日视图同一套时长/缓动；周/日内容在下面由 pager 的 graphicsLayer
                // 向左让位。壁纸在本页最底层不动，所以只换正文，不带动照片。
                if (monthMounted && monthContent != null) {
                    val monthHitGate = if (monthVisible) {
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
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .clipToBounds()
                            .graphicsLayer {
                                val progress = dayExpandEasing.transform(monthExpand.value)
                                translationX = (1f - progress) * size.width.toFloat()
                            }
                            .then(monthHitGate),
                    ) {
                        // ── 顶部接缝：与日视图第一张卡上沿同一条线（2026-11-11 用户真机反馈）──
                        // 月页内（`MonthViewPage` 嵌入态）把日历卡直接铺在带子下沿，接缝是 0dp；
                        // 日视图首卡离星期栏 [DAY_VIEW_TOP_SEAM_DP]（14dp）。两者的差只在这 14dp，
                        // 所以在这里补：**月页可用高度也跟着少 14dp**，版面账（卡高 / 面板高）
                        // 自己会重算，底部不会溢出、面板不会被顶出去。
                        //
                        // 为什么挂在宿主层而不是月页里：`month/MonthViewPage.kt` 当前有他人在途，
                        // 不叠改；归属裁定后若月页内也加了顶缝，两处会叠（=28dp），由调度统一裁决。
                        // 常量与日视图共用一份，不许在别处再写 14。
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(top = DAY_VIEW_TOP_SEAM_DP.dp),
                        ) {
                            // 首组合打点：组合落地后置真 ⇒ 外面那个计时 effect 因键变化重进一次
                            // 才开播（「先挂树 → 等首组合 → 再播」两步门的第二步）。
                            MonthContentMountSignal { monthContentComposed = true }
                            monthContent()
                        }
                    }
                }
            }
        }
        }  // 关闭真实内容录制层（B1）

        // ── 「回本周」浮钮（搬出录制层，采它背后的真实内容）──
        // 与日视图「回今日」共用同一颗 [BackToTodayFab]；backdrop 从 pageBackdrop（只录壁纸）
        // 改为 contentBackdrop（壁纸 + 课卡 + 文字）。可见性 / 点击行为不变。
        //
        // ❗ 预览里**不画**（2026-11-08 用户口径：「这个页面不要显示」）。它的短标签只有一个字
        // 「今」，而预览里存着的那一周往往不是真实本周，于是这颗钮会永久亮在预览框里；
        // 它又点不动（挖洞预览不可操作），纯属噪点。
        // 代价：「浮钮不透明度」滑杆在预览里没有可看的目标了（2026-11-07 为此把它显过，
        // 现按用户口径收回）。
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
            // 单字「今」（用户设计意图：日/周共用同一个短字胶囊）。
            // 2026-11-10 用户报坏「回本周」全文字后恢复；读屏语义仍走完整动作。
            label = DayViewStrings.backToTodayShort.text,
            contentDescription = TimetableStrings.backToCurrentWeekAction.text,
            visible = !previewMode && showBackToCurrentWeek && !dayVisible,
            backdrop = when {
                // 真首页：浮钮采「壁纸 + 课卡 + 文字」的录制层。
                floatingGlassActive -> contentBackdrop
                else -> pageBackdrop
            },
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
    /**
     * 这一周的纵向滚动控制器，由 [TimetableWeekPage] 按周次持有（见 `weekScrollStates`）。
     * pager 离屏后会销毁页内容，控制器必须活在页外，翻走再翻回来才停在同一节。
     */
    scrollState: ScrollState,
    semesterStart: LocalDate?,
    /** 已设单节课提醒键（`courseId|yyyy-MM-dd`），空集 = 真的没设过。 */
    reminderKeys: Set<String> = emptySet(),
    visibleDays: List<Int>,
    courses: List<Course>,
    /** 情侣叠加（非 null 时周网格叠 TA 课，三色优先于统一色）。 */
    coupleOverlay: CoupleOverlay? = null,
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
    /** 底部避让余量；预览里传 0，避免 64dp 坞避让把网格撑出框。 */
    bottomClearanceDp: Dp = 0.dp,
    /**
     * 节高算「自动充满」时的可用高基准（dp）；null = 用自己盒子的高（真页面口径）。
     *
     * 只有设置页预览传值（2026-11-08）：预览窗口只有 4 行高，但行高必须与首页一致，
     * 所以把「首页网格可用高」当基准传进来。真页面的盒子就是首页那个盒子，传 null 即可。
     */
    sectionHeightBasisDp: Dp? = null,
    /**
     * 网格向上顶进玻璃带底下的高度（dp，= 带子高）。
     *
     * 非 0 时，滚动内容顶部补一个等高 `Spacer`，第 1 节仍停在带子下沿；同时节高
     * 「自动充满」的可用高要**减回这一截**——视口被接高了，不减就会把每一节撑高
     * （与座标同错）。预览不传（默认 0）。
     */
    underlapHeightDp: Dp = 0.dp,
    /** 内容层外壳（缓存图层挂在这里，见 pager 调用处的说明）。 */
    modifier: Modifier = Modifier,
) {
    val cardsByDay = remember(courses, pageWeek, style, visibleDays, weatherOf, reminderKeys, semesterStart, coupleOverlay) {
        if (coupleOverlay == null) {
            WeekGridCourseMapping.cardsForWeek(
                courses = courses,
                week = pageWeek,
                style = style,
                visibleDays = visibleDays,
                weatherOf = weatherOf,
                reminderKeys = reminderKeys,
                semesterStartDate = semesterStart,
            )
        } else {
            // 情侣叠加（B1 第二阶段）：情侣三色优先于统一卡片颜色，见该函数 KDoc。
            WeekGridCourseMapping.cardsForWeekWithCoupleOverlay(
                courses = courses,
                week = pageWeek,
                style = style,
                overlay = coupleOverlay,
                visibleDays = visibleDays,
                weatherOf = weatherOf,
                reminderKeys = reminderKeys,
                semesterStartDate = semesterStart,
            )
        }
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
        val sectionHeight = weekSectionHeight(
            style = style,
            // 预览：用壳给的首页基准；真页面：就用这个盒子的高。
            // 下穿那一截是**多出来**的视口（在带子底下），不属于可见网格区，减回去。
            availableHeightDp = (
                sectionHeightBasisDp ?: (maxHeight - underlapHeightDp).coerceAtLeast(0.dp)
                ).value,
            weekdayHeaderHeightDp = 0f,
            sectionCount = sectionCount,
        ).dp

        Column(
            modifier = Modifier
                .fillMaxSize()
                // 滚动反馈对齐日视图（`DayViewScrollContent.kt:117` 同款顺序）：
                // 滑到顶/底有一档 miuix 拉伸回弹 + 滚动结束触感，周网格与日议程列表手感一致。
                .scrollEndHaptic()
                .overScrollVertical()
                .verticalScroll(scrollState),
        ) {
            // 下穿留白：视口被接到屏幕顶部了，这截把第 1 节顶回带子下沿（可滚走）。
            if (underlapHeightDp > 0.dp) {
                Spacer(modifier = Modifier.height(underlapHeightDp))
            }
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
 * 周视图「每周一个滚动控制器」的保存器：**只存「周次 → 停在第几像素」**。
 *
 * 为什么不直接存 [ScrollState]：它不是 Bundle 可存类型，而且它身上的动画/手势状态
 * 本来也不该跨 Activity 重建带走。这里存扁平的 IntArray（`周次, 偏移, 周次, 偏移…`），
 * 是 Bundle 一定吃得下的形状；重建后按偏移量重建 ScrollState，位置就回来了。
 *
 * 用它的是 [TimetableWeekPage] 里的 `weekScrollStates`：pager 销毁页内容不会丢位置（内存级），
 * 切深色模式这类 Activity 重建也不会丢（靠这个 Saver）。
 */
private val WeekScrollStatesSaver: Saver<MutableMap<Int, ScrollState>, IntArray> = Saver(
    save = { states ->
        val flat = IntArray(states.size * 2)
        var index = 0
        states.forEach { (week, state) ->
            flat[index++] = week
            flat[index++] = state.value
        }
        flat
    },
    restore = { flat ->
        mutableMapOf<Int, ScrollState>().apply {
            var index = 0
            while (index + 1 < flat.size) {
                put(flat[index], ScrollState(flat[index + 1]))
                index += 2
            }
        }
    },
)

/**
 * 日视图展开面板的「首组合」打点（2026-11-05 方案 1：打开拆两步）。
 *
 * 必须放在面板的挂载块（`dayMounted && dayContent != null` 那个 `if` 体内）**内部**、
 * 紧挨 `dayContent(...)` 调用，且**横滑支与上下翻支各放一个**：两条都是进日视图的路
 * （底栏「周/日」互点走横滑支、点星期栏某天走上下翻支），少一条那条路上就永远等不到信号、
 * `dayExpand` 停在 0 但 `dayVisible` 已为真 ⇒ 命中层一直吃事件，页面点不动。
 *
 * 用 [SideEffect] 而不是在组合体里直接给状态赋值：SideEffect 在**本帧组合落地之后、测量之前**
 * 执行，因此置真时子树已经组好、下一帧即可绘制；直接写会触发「组合期写状态」再补一轮重组。
 * 重复置真不进快照（`mutableStateOf` 结构化相等），不会白白多跑一轮。
 */
@Composable
private fun DayContentMountSignal(onMounted: () -> Unit) {
    SideEffect(onMounted)
}

/**
 * 月视图页内态的「首组合」打点（2026-11-12）：与 [DayContentMountSignal] **同构**。
 *
 * 必须放在月层的挂载块（`monthMounted && monthContent != null` 那个 `if` 体内）内部、
 * 紧挨 `monthContent()` 调用：月层和日视图一样是「换档下一帧才首次组合」，若不等这一下，
 * `monthExpand` 的 tween 第一帧就撞上首组合 / 首测量，表现为月内容起步空 / 顿 1~2 帧。
 *
 * 用 [SideEffect] 而不是在组合体里直接给状态赋值：SideEffect 在**本帧组合落地之后、测量之前**
 * 执行，因此置真时子树已经组好、下一帧即可绘制；直接写会触发「组合期写状态」再补一轮重组。
 * 重复置真不进快照（`mutableStateOf` 结构化相等），不会白白多跑一轮。
 *
 * ⚠️ **不复用、也不改名**成 `DayContentMountSignal`：既有守卫
 * `DayViewOverlayPerfWiringGuardTest` 用文本判据咬「日视图两支挂载点各有一个信号，且
 * `dayContentComposed` 的置真**恰好两处**」（它按原文数出现次数，注释也算，所以这里
 * 不写那句赋值的样子）；借道会让那条守卫的计数前提变糊（月层一挂，「为什么只有两处」
 * 就说不清了），改名的连带面也更大。两个函数同构、名字分域，守卫各咬各的。
 */
@Composable
private fun MonthContentMountSignal(onMounted: () -> Unit) {
    SideEffect(onMounted)
}

/**
 * 日页条带的**录制壳**：把日视图正文录进 `dayStripBackdrop`，给顶栏第二遍玻璃采样。
 *
 * 只录不画：`layerBackdrop` 负责把子部树录进图层，子部树照常上屏。按带高夹住录制
 * 范围（`dayStripBackdrop` 的 `onDraw`），不整屏离屏重画。
 */
@Composable
private fun DayStripHost(
    backdrop: LayerBackdrop?,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .then(if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier),
    ) {
        content()
    }
}

/**
 * 日视图展开面板的几何（高度 + 圆角裁剪），**读数后移到测量期 / 绘制期**。
 *
 * 改前这两项都在组合期算：`heightFactor` / `cornerDp` 直接由 `dayExpand.value` 换算，
 * 于是 360ms 转场里外层组合体逐帧重组、日视图整棵子树每帧重新测量。
 * 这里把「高度」放进 measure 块、「圆角」放进 graphicsLayer 块：
 * 每帧只重新测量一层、重绘一层，不再牵动组合。
 *
 * 几何与 `Modifier.height(maxHeight * max(0.04f, p))` + `Modifier.clip(RoundedCornerShape(corner.dp))`
 * 逐项等价：高度同样夹到 `max(0.04f, p)`，圆角同样是 `28f * homeViewExpandCornerRadiusFactor(p)`，
 * 且两者都用**缓动后**的进度 `p`（与改前一致，不是夹过的 heightFactor）。
 *
 * [underlap] 是面板向上多占的带高（日页下穿用）：面板总高 = 可视内容高 + 带高，
 * 顶部那一截被顶栏玻璃盖住，下沿仍按进度长（见 [dayPanelHeightPx]）。
 *
 * [easedProgress] 必须在 measure / draw 阶段调用（本函数就是这么用的）——若在组合期先求
 * 值再传进来，就退化成改前的每帧重组，等于没改。
 */
private fun Modifier.expandPanelGeometry(
    easedProgress: () -> Float,
    maxHeight: Dp,
    underlap: Dp = 0.dp,
): Modifier = this
    .layout { measurable, constraints ->
        val progress = easedProgress()
        val totalPx = maxHeight.toPx()
        val overlapPx = underlap.toPx().coerceIn(0f, totalPx)
        val heightPx = dayPanelHeightPx(
            totalHeightPx = totalPx,
            underlapPx = overlapPx,
            progress = progress,
        )
        val placeable = measurable.measure(
            constraints.copy(minHeight = heightPx, maxHeight = heightPx),
        )
        layout(placeable.width, heightPx) { placeable.place(0, 0) }
    }
    .graphicsLayer {
        val progress = easedProgress()
        shape = RoundedCornerShape((28f * homeViewExpandCornerRadiusFactor(progress)).dp)
        clip = true
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（@Preview）
//
// 周视图入参全部有默认值，固定到「第 10 周 · 2026-11-08」拍一帧即可，
// 不依赖仓储、不读设置。示例课程覆盖周一到周六：单双周、连堂、跨 3 节、
// 周末课与「本周有作业」都在里面，预览里能看到真实卡面而不是一张空网格。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用作息表：直接用内置模板，课程起止钟点从这份表取，保证「第几节 = 几点」与真机同源。 */
private val previewWeekSections: List<SectionTime> = TimetableSettings.DEFAULT_SECTIONS

/** 预览用一门课（id 按 天-起始节 生成，同一天同节次不会被建两次）。 */
private fun previewWeekCourse(
    name: String,
    teacher: String,
    location: String,
    dayOfWeek: Int,
    startSection: Int,
    endSection: Int,
    color: String,
    shortName: String? = null,
    isOddWeek: Boolean = false,
    isEvenWeek: Boolean = false,
    homeWorkWeek: Int? = null,
): Course = Course(
    id = "preview-week-$dayOfWeek-$startSection",
    name = name,
    shortName = shortName,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = previewWeekSections[startSection - 1].startTime,
    endTime = previewWeekSections[endSection - 1].endTime,
    color = color,
    startWeek = 1,
    endWeek = 18,
    isOddWeek = isOddWeek,
    isEvenWeek = isEvenWeek,
    sessionNotes = homeWorkWeek?.let {
        mapOf(it to CourseSessionNote(text = "第 3 章习题", hasHomework = true))
    },
)

/** 预览用课表：周一~周五铺满、周六一门体育，颜色各异便于一眼分辨课卡色块。 */
private val previewWeekCourses: List<Course> = listOf(
    // 周一
    previewWeekCourse("高等数学", "张明", "A101", 1, 1, 2, "#3B82F6", shortName = "高数"),
    previewWeekCourse("大学英语", "李颖", "B204", 1, 3, 4, "#F59E0B"),
    previewWeekCourse("体育（羽毛球）", "赵强", "体育馆", 1, 7, 8, "#14B8A6"),
    // 周二
    previewWeekCourse("大学物理", "李海", "B203", 2, 1, 2, "#8B5CF6"),
    previewWeekCourse("数据结构", "陈晨", "C302", 2, 5, 6, "#06B6D4", homeWorkWeek = 10),
    // 周三：连堂 3 节，看跨节高度
    previewWeekCourse("程序设计实验", "陈晨", "实验楼 C301", 3, 5, 7, "#F97316"),
    previewWeekCourse("线性代数", "王静", "A108", 3, 1, 2, "#10B981"),
    // 周四
    previewWeekCourse("计算机网络", "周航", "B305", 4, 3, 4, "#EF4444"),
    previewWeekCourse("中国近现代史纲要", "孙悦", "A210", 4, 9, 10, "#64748B"),
    // 周五：单双周各一门，第 10 周只看得到双周课
    previewWeekCourse("概率论与数理统计", "吴涛", "A109", 5, 3, 4, "#0EA5E9", isEvenWeek = true),
    previewWeekCourse("学术写作", "何静", "B102", 5, 3, 4, "#A855F7", isOddWeek = true),
    // 周六
    previewWeekCourse("创新创业实践", "林峰", "创客空间", 6, 1, 2, "#D946EF"),
)

@Composable
private fun PreviewTimetableWeekPage(dark: Boolean = false, textScale: Float = 1f) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        TimetableWeekPage(
            courses = previewWeekCourses,
            currentWeek = 10,
            totalWeeks = 20,
            now = java.time.LocalDateTime.of(2026, 11, 8, 10, 0),
            todayDate = java.time.LocalDate.of(2026, 11, 8),
        )
    }
}

@Suppress("unused")
@Preview(name = "1 亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun TimetableWeekPagePreviewLight() {
    PreviewTimetableWeekPage()
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun TimetableWeekPagePreviewDark() {
    PreviewTimetableWeekPage(dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun TimetableWeekPagePreviewLargeText() {
    PreviewTimetableWeekPage(textScale = 1.3f)
}