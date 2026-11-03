package com.mutx163.qingyu.pages.timetable

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
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
 * 壁纸与玻璃坞（属于壳）、下拉快捷导入（`homePull`）、周↔日/月飞行动效、
 * 课卡天气行、情侣课表叠加。这些不是本页能单独补齐的。
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
    ApplyStatusBarInk(lightIcons = lightStatusBarIcons, themeDark = dark)

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
    val realCurrentWeek = currentSemesterWeek(semesterStart, totalWeeks, todayDate)
    val showBackToCurrentWeek = style.showBackToCurrentWeek &&
        realCurrentWeek != null &&
        realCurrentWeek != browsingWeek

    // ── 「回本周」浮钮的玻璃档（2026-11-01）──
    // 与 Dart 同一条：浮钮跟的是**玻璃坞**那一档（作用范围 → 玻璃坞），不是课程卡片的
    // 材质 —— 它是浮在首页上的控件，与底栏同一族。见 `homeFloatingChipSurface`。
    val floatingGlassActive = materialSpec?.dock.let { dock ->
        (dock == SurfaceMaterialState.LIQUID_GLASS || dock == SurfaceMaterialState.FROST) &&
            hasBackdrop && isRuntimeShaderSupported()
    }
    // 录像带只在**真有人采**时才挂：顶栏带要采、课卡液态档要采，或浮钮真要玻璃。
    // 否则整屏录制是纯浪费（`PagesShellActivity.kt:296-300` 同一条纪律）。
    // 浮钮那一份只在它**真的可见**时才算 —— 不为一颗看不见的按钮录整屏。
    val pageBackdropActive = bandBlurActive || cardGlassActive ||
        (floatingGlassActive && showBackToCurrentWeek)

    Scaffold(
        // 有壁纸时底色必须透明，否则不透明主题底会把壁纸整张盖掉。
        containerColor = if (backdrop == null) scaffoldBg else Color.Transparent,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize()) {
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

                    // ── 星期栏：从 pager 里提出来，不跟横向翻页滑动 ──
                    // 显示「落定后的那一页」；滑动过程中保持上一页（见 displayedPage）。
                    TimetableWeekdayHeader(
                        week = displayedPage + 1,
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
                        hasExamOnDate = hasExamOnDate,
                        hasScheduleOnDate = hasScheduleOnDate,
                        onDayClick = onDayClick,
                        onWeekTitleClick = { showWeekSelectorDialog = true },
                    )
                }
            }

            // 下方内容：从玻璃带底部开始，占满剩余高度（底部仍铺到屏幕最底）。
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                ) { page ->
                    WeekPageContent(
                        pageWeek = page + 1,
                        semesterStart = semesterStart,
                        visibleDays = visibleDays,
                        courses = courses,
                        style = style,
                        sectionTimes = sectionTimes,
                        sectionCount = sectionCount,
                        exams = exams,
                        scheduleItems = scheduleItems,
                        now = now,
                        bottomInset = innerPadding.calculateBottomPadding(),
                        holidayOf = holidayOf,
                        weatherOf = weatherOf,
                        onCourseClick = onCourseClick,
                        onAgendaClick = onAgendaClick,
                        onLongPressEmptySlot = onLongPressEmptySlot,
                        material = material,
                        cardGlassBackdrop = cardGlassSource,
                        // 时间列压在壁纸的正文带上：同一档亮度决定字色。
                        wallpaperLuminance = wallpaperBands?.body,
                    )
                }

                // ── 「回本周」浮钮（Dart 浮钮唯一入口）──
                if (showBackToCurrentWeek) {
                    // Dart 把 `timetableFloatingBackToCurrentWeekButtonOpacity` 分别压在
                    // **染色**与**内容**两层，而不是包住整块玻璃（`timetable_back_to_current_week_button.dart:40-82`）：
                    // 包住会让采样失真。这里同口径。
                    val buttonOpacity = style.backToCurrentWeekOpacity.coerceIn(0f, 1f)
                    val buttonShape = RoundedCornerShape(ButtonDefaults.CornerRadius)
                    val chipSurface = homeFloatingChipSurface(
                        backdrop = if (floatingGlassActive) pageBackdrop else null,
                        material = materialSpec,
                        hasBackdrop = hasBackdrop,
                        shape = buttonShape,
                        solidColor = MiuixTheme.colorScheme.surface,
                        tintAlphaScale = buttonOpacity,
                    )
                    Button(
                        onClick = {
                            realCurrentWeek?.let { target ->
                                coroutineScope.launch {
                                    pagerState.animateScrollToPage(
                                        (target - 1).coerceIn(0, pageCount - 1),
                                    )
                                }
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            // 底边距由宿主按玻璃坞药丸的真实占用算好（见 `HomeFloatingMetrics`）；
                            // 宿主没接时退回旧口径（系统内边距 + 72dp），不再自己猜坞的高度。
                            .padding(
                                bottom = floatingButtonBottomInset
                                    ?: (innerPadding.calculateBottomPadding() + 72.dp),
                            )
                            .then(chipSurface),
                        // 卡面交给上面那条 modifier 画（玻璃 / 实底），按钮本体让开；
                        // 字色跟主题走（Dart 用 `onSurface`，图标才是强调色）。
                        colors = ButtonDefaults.buttonColors(
                            color = Color.Transparent,
                            contentColor = Color(QingyuTheme.primaryText(dark)),
                        ),
                    ) {
                        Text(
                            text = TimetableStrings.backToCurrentWeekAction.zh,
                            modifier = Modifier.alpha(buttonOpacity),
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                }
            }
        }
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
        visibleWeek = browsingWeek,
        currentSemesterWeek = realCurrentWeek,
        onDismiss = { showWeekSelectorDialog = false },
        onSelect = { week ->
            showWeekSelectorDialog = false
            coroutineScope.launch {
                pagerState.animateScrollToPage((week - 1).coerceIn(0, pageCount - 1))
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
) {
    val cardsByDay = remember(courses, pageWeek, style, visibleDays, weatherOf) {
        WeekGridCourseMapping.cardsForWeek(
            courses = courses,
            week = pageWeek,
            style = style,
            visibleDays = visibleDays,
            weatherOf = weatherOf,
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
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val sectionHeight = weekSectionHeight(
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
                    .padding(bottom = bottomInset + WEEK_GRID_BOTTOM_CLEARANCE_DP.dp),
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

/** 周网格底部避让：手势条之上再留 64dp 给浮坞。 */
private const val WEEK_GRID_BOTTOM_CLEARANCE_DP = 64f

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
