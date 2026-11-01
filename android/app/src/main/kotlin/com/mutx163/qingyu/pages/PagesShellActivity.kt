package com.mutx163.qingyu.pages

import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.TimetableHomeViewMode
import com.mutx163.qingyu.platform.PerfProbe
import com.mutx163.qingyu.pages.shell.GlassDockGeometry
import com.mutx163.qingyu.pages.shell.GlassDockNavigationBar
import com.mutx163.qingyu.pages.shell.HomeDockNavModel
import com.mutx163.qingyu.pages.shell.HomeNavIcons
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import top.yukonga.miuix.kmp.basic.FloatingActionButton
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.nav.core.NavDisplay
import top.yukonga.miuix.kmp.nav.core.NavDisplayEffects
import top.yukonga.miuix.kmp.nav.core.navBackStackOf
import top.yukonga.miuix.kmp.nav.runtime.NavProgrammaticEasing
import top.yukonga.miuix.kmp.nav.transition.NavMotion
import top.yukonga.miuix.kmp.nav.transition.NavSettleSpec
import top.yukonga.miuix.kmp.nav.transition.NavSwipeDirection
import top.yukonga.miuix.kmp.nav.transition.NavTransition
import top.yukonga.miuix.kmp.nav.transition.NavTransitionScope
import top.yukonga.miuix.kmp.nav.transition.NavTransitions
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop

/**
 * Compose 迁移 · 页面壳（dev 变体的入口 Activity，包名带 `.ui` 后缀，与正式版并存）。
 *
 * ## 结构（2026-10-31 起：底栏由**用户存档**决定，不再写死四个槽位）
 *
 * 主屏 = 某个底栏条目对应的内容：`week` / `day` / `monthView` 是三个课表视图，
 * 其余条目（`tasks` / `scheduleList` / `settings` / `statistics` …）渲染成对应页面，
 * **底栏保持可见**——与 Flutter「玻璃坞内嵌页」（`kInlineDockPages`）同构：
 * 点底栏换内容、返回回周视图。打开底栏以外的页面才 push 一层、底栏让位。
 *
 * 条目集合、顺序、上限（5 个）、圆钮加课、`classic` 无坞形态、冷启动恢复的视图档
 * 全部来自用户存档（`glassDockActions` / `glassDockShowAddButton` /
 * `glassDockButtonEntryId` / `homeNavigationForm` / `timetableHomeViewMode`），
 * 解析规则在 [com.mutx163.qingyu.pages.shell.HomeDockNavModel]（纯 Kotlin，L0 单测钉住）。
 * 2026-10-31 之前这四项写死为「课表 / 日程 / 任务 / 索引」，设置里改底栏没有任何效果。
 *
 * ## 数据
 *
 * 壳读写的是**自己那份** `FlutterSharedPreferences`（包名隔离），格式与正式版同一套冻结
 * 格式，但内容不共享。因此壳里看到的是壳自己的数据，不是手机上正式版的课表。
 *
 * ## 索引页（旁路）
 *
 * 目录（[com.mutx163.qingyu.pages.shell.ShellPageCatalog]）与分派（[ShellPageContent]）
 * 分开：加一页只改这两处，不碰导航逻辑。索引里每条都标了数据来路：
 * - 无标记：页面自带默认值，直接进；
 * - 「演示数据」：壳里喂的是示例值，只看版式与文案；
 * - 「暂不可用」：缺宿主能力，宁可不给入口，也不造假实现。
 */
class PagesShellActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 系统栏这件事有两层，缺任一层都会在屏幕上留黑条（2026-10-28 第二轮查清）：
        //
        // 第一层（窗口标志）：系统只对「自己声明要画系统栏背景」的窗口让步。
        // 这一位由主题的 windowDrawsSystemBarBackgrounds / 运行时 addFlags 打开，
        // 见下面 applyShellSystemBars()。Flutter 侧一直显式加它，所以正式版能把
        // 内容画进上下两条栏；壳从来没有，系统就按老规矩自己把两条栏涂成不透明黑。
        //
        // 第二层（窗口内缩）：只 import 而不调用 enableEdgeToEdge 时，窗口不会
        // 铺满整屏，壳的内容区被挤到黑条下面（2026-10-27 19:0x 修的就是这层）。
        //
        // 2026-10-28 09:57 那版改成「把栏色写进主题」，真机复验「没区别」——不是
        // 颜色值不对，是 Android 15+ 起 targetSdk ≥ 35 的窗口被平台强制边到边：
        // PhoneWindow.generateLayout() 里 mEdgeToEdgeEnforced=true 会跳过主题里的
        // statusBarColor/navigationBarColor、把栏色强制成透明，setStatusBarColor() 也
        // 直接 return。所以第一层只能靠窗口标志，与栏色无关。
        //
        // 系统栏图标必须跟壳的明暗走：亮色界面要深色图标（light()），深色界面
        // 要浅色图标（dark()）。此前固定 light()，系统切深色后图标与背景同色，
        // 状态栏内容直接不可见。这里先按当前配置给出首帧的正确值，之后由
        // setContent 内的 SideEffect 跟随 isSystemInDarkTheme() 持续校正
        // （manifest 未声明 uiMode 的 configChanges，切深色通常走 Activity 重建，
        // 但 SideEffect 能兜住不重建的路径，两条路都不会留错色）。
        //
        // scrim 参数只对 API 26–28 的三键导航栏有意义，本工程 minSdk 33，
        // 透明即可。页面侧的内缩不在这里补——课表页已有 statusBarsPadding()、
        // 底部 dock 已有 navigationBarsPadding()，在这里再加会让顶部空白翻倍。
        applyShellSystemBars(isDark = isNightMode())

        // 帧性能探针（性能报告页 h.perfReport 的数据源）：窗口已就绪，挂上逐帧 FrameMetrics 采集。
        // 正式包里 `isEnabled` 判 false ⇒ 空操作，报表页如实显示 Dart 同款「Probe is not installed」
        // 文案，不伪造数据。`markStartup` 记下「壳挂载完成」这一刻，启动分段里才有基线。
        // 换页打点在 `ShellPageContent`（只有那里知道当前页 id），这里是「装 + 挂窗口」。
        PerfProbe.attach(this)
        PerfProbe.markStartup("shellAttach")

        setContent {
            val dark = isSystemInDarkTheme()
            SideEffect { applyShellSystemBars(isDark = dark) }
            // 壳的主题必须也走主题桥：无参 MiuixTheme{ } 的配色恒取官方默认亮色板，
            // 系统切深色后卡片仍是 #FFFFFF，而正文取的是 QingyuTheme 的深色白字
            // → 白字白底、内容不可读（页面层已由 QingyuPageTheme 兜住，壳这层是
            // 根因，此处一并修掉）。用 QingyuPageTheme 后页面里的同款包装成为
            // 重复但等价的一层，后续可逐页摘除。
            QingyuPageTheme { PagesShell() }
        }
    }

    /** 当前资源配置是否为深色。仅作首帧兜底，组合内以 isSystemInDarkTheme() 为准。 */
    private fun isNightMode(): Boolean =
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    /** 系统栏全透明，图标明暗跟随壳的明暗。 */
    @Suppress("DEPRECATION")
    private fun applyShellSystemBars(isDark: Boolean) {
        // 窗口标志：告诉系统「系统栏区域由本窗口负责画」。缺这一位时系统会自己给
        // 上下两条栏涂不透明底（本机 Android 16 上是纯黑），壳的内容再透明也透不出来。
        // 主题 ComposeShellTheme 里已经有 windowDrawsSystemBarBackgrounds=true，
        // 这里再补一次是运行时兜底（Activity 重建、别的入口进来都能覆盖到），
        // 与 FlutterActivity.configureStatusBarForFullscreenFlutterExperience()
        // 加的是同一位。
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        // 旧路径的「铺满整屏」位。Android 15+ 认的是新路径（setDecorFitsSystemWindows），
        // 但部分 ROM 的窗口放大逻辑只看这几位，留着兜底；设错也不会缩小窗口。
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )

        val transparent = android.graphics.Color.TRANSPARENT
        enableEdgeToEdge(
            statusBarStyle = if (isDark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
            navigationBarStyle = if (isDark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
        )
    }
}

@Composable
private fun PagesShell() {
    // Phase 3.5 接线层：壳自己的存储 + 课表仓储。
    val wiring = rememberShellWiring()

    // ── 用户设置（底栏排列 / 底栏形态 / 圆钮 / 首页视图档）──────────────────────
    // 设置存储没有变更通道（`TimetableSettingsModelStore` 只有 load / save），旧做法是
    // 「每次重组 load 一遍」。这里读一次进 state，并在**回到主屏**时重读：设置页改完
    // 返回后立刻生效，滚动、动画的每一帧又不用重新解析一遍 JSON。
    var settingsModel by remember(wiring) { mutableStateOf(wiring.settingsModel.load()) }

    // 底栏条目：**由用户存档决定**，不再写死「课表 / 日程 / 任务 / 设置」。
    // Dart `resolveGlassDockActionIds`（`home_menu_catalog.dart:536-556`）同一口径：
    // 空表回退 `HomeDockMenu.defaultActions` = 日课表 / 周课表 / 任务。
    // 「有没有去处」传的是壳的页面映射表：本仓还没移植的目录条目（如 courseRecolor
    // 的颜色重设弹层）在这里被丢掉，宁可不放进底栏，也不给一个点了没反应的按钮。
    val dockIds = remember(settingsModel) {
        val resolved = HomeDockNavModel.resolveIds(settingsModel.glassDockActions) { id ->
            rootPageIdFor(id) != null
        }
        // 开发壳的「页面索引」入口（L4 逐页对照用，见 [HomeDockNavModel.DEV_INDEX_ID]）：
        // **只在用户没自定义过底栏时**追加到末尾；用户动过底栏就完全按存档来。
        if (settingsModel.glassDockActions.isEmpty() && resolved.size < HomeDockNavModel.MAX_SLOTS) {
            resolved + HomeDockNavModel.DEV_INDEX_ID
        } else {
            resolved
        }
    }
    // 底栏形态：`classic` 是 Dart 的「不挂玻璃坞」档（`home_chrome_spec.dart:78-80`：
    // `glassDockForm = homeNavigationForm == glassDock`，非坞档直接返回 `dockContent`，
    // 坞层连建都不建）。这里照做：classic 不画底栏。回到设置的路径两边也一致——
    // 顶栏右上角「更多」菜单（默认含「设置」）。
    val showDock = settingsModel.homeNavigationForm == HomeNavigationForm.GLASS_DOCK

    // ── 两个「运行期偏好」：改了当场生效，不用重启（Dart 是同一个形态）───────────────
    val systemHaptics = LocalHapticFeedback.current
    val shellHaptics: HapticFeedback =
        if (wiring.enableHaptics) systemHaptics else NoopHapticFeedback
    val pageTransition = remember(wiring.pageTransitionSpeed) {
        NavTransitions.MiuixDefault.scaledToUserSpeed(wiring.pageTransitionSpeed)
    }

    // 页面层用 miuix-nav 的返回栈（唯一合规做法，不自研转场）。栈底是 [ShellRoute.Dock]
    // （主屏：某个底栏条目/视图），打开一页 push 一层、返回 pop 一层；切底栏 = 替换栈底
    // 那条路由。所有转场由 NavDisplay（NavTransitions.MiuixDefault + NavDisplayEffects.Default）
    // 负责，不写一行自研动画。
    //
    // 首屏停在哪个视图由存档决定（Dart `timetableHomeViewMode`，冷启动恢复上次停留的
    // 周 / 日 / 月）—— 这是此前同样没接上的一个死键。
    val initialRootId = remember(wiring) {
        rootItemIdForView(wiring.settingsModel.load().timetableHomeViewMode)
    }
    val backStack = remember { navBackStackOf(ShellRoute.Dock(initialRootId)) }

    fun popPage() {
        if (backStack.size > 1) backStack.removeLastOrNull()
    }

    fun pushPage(id: String) {
        val route = ShellRoute.Page(id)
        // 幂等 + 环状导航：同一页已在栈里时**弹回那一层**，而不是什么都不做。
        // 2026-10-31 审核 P2-1：旧写法 `if (route !in backStack) add` 让
        // 「A 页 → B 页 → 又点 A」静默无反应（用户点了没动静，只能猜）。
        val existing = backStack.indexOf(route)
        if (existing >= 0) {
            while (backStack.size > existing + 1) backStack.removeLastOrNull()
            return
        }
        backStack.add(route)
    }

    // ── 视图档落盘：**必须离开点击所在的那一帧** ─────────────────────────────
    // `settingsModel.save` 内部是两次 `SharedPreferences.commit()`（同步等磁盘落盘），
    // 其中 `saveSettingsPatchToActiveProfile` 还会把整份课表档案 JSON（全部课程 /
    // 任务 / 考试）读出来、解析、重编码再写回。这一句原先就写在 [selectRoot] 里，
    // 于是「点底栏 日/周/月 切视图」= 在下一帧画出来之前把主线程堵住 —— 用户反馈的
    // 那一下「顿」（2026-11-01，性能版）。
    //
    // 三条纪律：
    // 1. 写盘在 IO 线程，屏幕不等磁盘（与 Dart `timetable_screen.dart:1011-1016` 的
    //    lightweight path 同口径：先改内存、后异步落盘）。
    // 2. 互斥量串行：连点两次时两次写同时起飞，先发起的那次可能最后落盘，冷启动就
    //    会恢复成上一个视图；串行保证「最后一次点击 = 最后一次写」。
    // 3. **不写 `settingsModel` 这个 state**：它不影响屏幕上的任何一个像素，写它只会
    //    让整个壳——含底栏三层玻璃的 effects——白白重组一遍，比它要省下的那次落盘贵
    //    得多。「当前停在哪一档」以路由（`backStack`）为准，那才是真源。
    //
    // 只写 `timetableHomeViewMode` 一个键（`saveHomeViewMode`），不再拿整份设置快照
    // 覆盖：底栏只在栈底可见，此时写设置页的路径都不在栈顶，单键写的窗口更小。
    val persistScope = rememberCoroutineScope()
    val persistMutex = remember { Mutex() }

    /** 切到主屏某个条目（= Flutter 玻璃坞点某个槽位）。 */
    fun selectRoot(itemId: String) {
        val mode = homeViewModeOf(itemId)
        // 当前视图档必须在改 `backStack` **之前**取（改完就拿到新值了）。
        val currentMode = homeViewModeOf(
            (backStack.lastOrNull() as? ShellRoute.Dock)?.itemId ?: ROOT_WEEK,
        )
        if (backStack.size == 1) backStack[0] = ShellRoute.Dock(itemId)
        // 视图档写回存档（Dart `timetableHomeViewMode` 同样是「切了就存」）；
        // 同档重复点不写。
        if (mode == null || mode == currentMode) return
        persistScope.launch(Dispatchers.IO) {
            persistMutex.withLock {
                runCatching { wiring.settingsModel.saveHomeViewMode(mode) }
            }
        }
    }

    /** 圆钮（右侧独立按钮）：Dart `handleRoundButtonTap`（`home_menu_controller.dart:306-333`）。 */
    fun handleRoundButton() {
        val action = HomeDockNavModel.roundButtonAction(settingsModel.glassDockButtonEntryId)
        val target = if (action == HomeDockNavModel.ACTION_ADD_COURSE) null else rootPageIdFor(action)
        if (target == null) {
            // 加课：清掉可能残留的「编辑目标」，否则会把上一门课载进新建表单。
            wiring.pendingAddCourseSeed = null
            wiring.pendingEditCourse = null
            pushPage("d1.addCourse")
        } else {
            pushPage(target)
        }
    }

    // 栈顶路由：是 Dock 则停在主屏某个条目；是 Page 则压着页面层。
    val topRoute = backStack.lastOrNull()
    val currentRootId = (topRoute as? ShellRoute.Dock)?.itemId ?: ROOT_WEEK
    val atRoot = topRoute is ShellRoute.Dock

    // 回到主屏时重读设置：设置页里改完底栏排列 / 形态，返回主屏立刻是新的。
    LaunchedEffect(atRoot) {
        if (atRoot) settingsModel = wiring.settingsModel.load()
    }

    // 系统返回：压着页面时由 NavDisplay.onBack 弹层；栈底且不在周视图时回周视图。
    BackHandler(enabled = atRoot && currentRootId != ROOT_WEEK) {
        selectRoot(ROOT_WEEK)
    }

    // 玻璃的背景采样源：整个内容区先被录进这个 layer，底栏再拿它当 backdrop。
    // 必须挂在**内容**上、而不是包住整个 Column —— 包住就会把底栏自己也录进去，
    // 底栏于是拿「含自己」的图去算模糊，展开动画里明暗会来回颤。
    //
    // ⚠️ 录制有成本：miuix 的 `LayerBackdropNode.draw()` 实际是
    // `drawContent(); recordLayer { onDraw() }` —— 内容每重绘一帧（滚动、转场、任何动画），
    // 都会先在屏幕上画一遍、再把整屏录进一张离屏 GraphicsLayer。所以只在
    // **栈底 + 有底栏 + 设备支持 runtime shader** 时才挂：压着页面时底栏不显示
    // （`atRoot=false`），没有任何东西采样它，那段录制是纯浪费（2026-10-29 审计第 1 条）。
    val backdrop = rememberLayerBackdrop()
    val glassAvailable = isRuntimeShaderSupported()
    val recordBackdrop = atRoot && showDock && glassAvailable

    // 底栏材质（2026-11-01）：总闸 / 「作用范围 → 玻璃坞」/ 八根旋钮终于落到坞上。
    // 与周视图共用同一份纯推导（`SettingsMaterialModel.renderSpecOf`），不在这里
    // 另判 `frostedBlurEnabled`；明暗变了要重算（深色档 + 深色配方）。
    val isDarkTheme = isSystemInDarkTheme()
    val hasBackdrop = !settingsModel.homePageWallpaperPath.isNullOrEmpty() ||
        !settingsModel.homePageBackgroundImagePath.isNullOrEmpty()
    val dockMaterial = remember(settingsModel, isDarkTheme, hasBackdrop) {
        SettingsMaterialModel.renderSpecOf(
            model = settingsModel,
            isDark = isDarkTheme,
            hasBackdrop = hasBackdrop,
        )
    }

    // 根 Scaffold：只为一件事——把弹层（`OverlayBottomSheet` / `OverlayListPopup`）的宿主
    // 抬到玻璃底栏之上。miuix 的弹层走「root scaffold」这条通道；没有这层根 Scaffold 时，
    // 它落在课表页自己的 Scaffold 里，而玻璃底栏画在页内容的上一层 → 弹层底部会被底栏盖住。
    // 容器透明 + 窗口内缩置零：不改变页面自身的边到边布局。
    Scaffold(
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
    ) { _ ->
    // 震动总开关的落点：整棵页面树都挂在它下面（含玻璃坞与两个入口页）。
    CompositionLocalProvider(LocalHapticFeedback provides shellHaptics) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    // 只有栈底且能画模糊时才录制（理由见上方 `backdrop` 的注释）。
                    // 压着页面时不录制，回栈底那一帧由新的内容重绘重新录一次。
                    .then(
                        if (recordBackdrop) Modifier.layerBackdrop(backdrop) else Modifier,
                    ),
            ) {
                NavDisplay(
                    backStack = backStack,
                    onBack = { popPage() },
                    // 官方预设 + 按用户倍率缩放过的时长（见 [scaledToUserSpeed]）。
                    transition = pageTransition,
                    effects = NavDisplayEffects.Default,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    // 栈底：主屏。**内容由底栏条目 id 决定**（不再是四个写死的槽位）：
                    // `week`/`day`/`monthView` → 周 / 日 / 月视图；其余条目 → 对应页面。
                    // 与 Dart「内嵌页」同构：底栏保持可见，返回回到周视图。
                    entry<ShellRoute.Dock> { route ->
                        if (route.itemId == HomeDockNavModel.DEV_INDEX_ID) {
                            // 开发壳专属：页面索引（L4 逐页对照）。它不是一个业务页面，
                            // 所以直接画在这里，不进 `ShellPageContent` 的分派表。
                            ShellPageIndexScreen(
                                onOpenPage = { target -> pushPage(target) },
                                onBack = { selectRoot(ROOT_WEEK) },
                            )
                        } else {
                            ShellPageContent(
                                pageId = rootPageIdFor(route.itemId) ?: ROOT_WEEK_PAGE_ID,
                                onBack = { selectRoot(ROOT_WEEK) },
                                wiring = wiring,
                                onOpenPage = { target -> pushPage(target) },
                            )
                        }
                    }
                    // 页面层：任意目录 id 的一层。返回 = 弹掉这层，回到它下面那一页/主屏。
                    entry<ShellRoute.Page> { route ->
                        ShellPageContent(
                            pageId = route.id,
                            onBack = { popPage() },
                            wiring = wiring,
                            // 页面内部「推新页」：路由字符串 → 壳页面 id（映射表在 ShellWiring.kt）。
                            onOpenPage = { target -> pushPage(target) },
                        )
                    }
                }
            }

            // 玻璃坞只在栈底显示（压着页面时它会压住页面底部操作区，且点它会分叉返回语义）。
            // classic 形态不画（Dart `homeNavigationForm == classic` ⇒ 没有坞层）。
            if (atRoot && showDock) {
                val roundActionId =
                    HomeDockNavModel.roundButtonAction(settingsModel.glassDockButtonEntryId)
                GlassDockNavigationBar(
                    items = dockIds.map { HomeNavIcons.dockItem(it) },
                    selectedIndex = HomeDockNavModel.selectedIndex(dockIds, currentRootId),
                    onSelect = { index -> selectRoot(dockIds[index]) },
                    // 设备不支持 runtime shader 时别把 backdrop 传进去：
                    // 传了也画不出模糊，反而会多录一层、白费一次采样。
                    backdrop = if (glassAvailable) backdrop else null,
                    material = dockMaterial,
                    modifier = Modifier.align(Alignment.BottomCenter),
                    trailingContent = if (settingsModel.glassDockShowAddButton) {
                        {
                            GlassDockRoundButton(
                                icon = HomeNavIcons.iconOf(roundActionId),
                                contentDescription = HomeNavIcons.labelOf(roundActionId),
                                onClick = { handleRoundButton() },
                            )
                        }
                    } else {
                        null
                    },
                )
            }
        }
    }
    }
}

/** 栈底默认条目：周视图（Dart `TimetableHomeViewMode.week`）。 */
private const val ROOT_WEEK = "week"

/** 周视图对应的壳页面 id（`ShellPageIndex` 的 `c1.week` = 真宿主 `TimetableWithCourseActions`）。 */
private const val ROOT_WEEK_PAGE_ID = "c1.week"

/**
 * 底栏条目 id → 壳页面 id。
 *
 * 与 `shellTimetableMenuPageId` 的关系：它是「菜单/目录条目 → 页面」的全量表，
 * 这里只多出**三个视图动作**（`week` / `day` / `monthView` 里的前两个不由目录驱动），
 * 其余一律转交那张表，避免二份路由口径。
 *
 * 返回 null = 本仓还没有这一项的去处（`courseRecolor` 的颜色重设弹层、
 * `shareTimetable` 的分享面板都还没移植），底栏解析时会被丢弃。
 */
private fun rootPageIdFor(itemId: String): String? = when (itemId) {
    ROOT_WEEK -> ROOT_WEEK_PAGE_ID
    HomeDockNavModel.ACTION_DAY -> "c3.day"
    else -> shellTimetableMenuPageId(itemId)
}

/** 条目 id → 存档里的视图档；不是视图动作时返回 null（不写 `timetableHomeViewMode`）。 */
private fun homeViewModeOf(itemId: String): TimetableHomeViewMode? = when (itemId) {
    ROOT_WEEK -> TimetableHomeViewMode.WEEK
    HomeDockNavModel.ACTION_DAY -> TimetableHomeViewMode.DAY
    "monthView" -> TimetableHomeViewMode.MONTH
    else -> null
}

/** 冷启动时按存档的视图档选栈底条目（Dart `timetableHomeViewMode` 的恢复）。 */
private fun rootItemIdForView(mode: TimetableHomeViewMode): String = when (mode) {
    TimetableHomeViewMode.WEEK -> ROOT_WEEK
    TimetableHomeViewMode.DAY -> HomeDockNavModel.ACTION_DAY
    TimetableHomeViewMode.MONTH -> "monthView"
}

/**
 * 玻璃坞右侧的独立圆钮（Flutter `glassDockShowAddButton` 那个「加课」按钮）。
 *
 * 用官方 [FloatingActionButton]（miuix 基础件）而不是自绘一块玻璃：本仓对「自研形状/
 * 动画」有禁令，而官方这颗按钮的按压反馈、阴影、无障碍语义都是现成的。
 * 直径与药丸同高（[GlassDockGeometry.HeightDp]），右侧留 8dp 由底栏负责。
 */
@Composable
private fun GlassDockRoundButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    FloatingActionButton(
        onClick = onClick,
        containerColor = MiuixTheme.colorScheme.primary,
        shadowElevation = 6.dp,
        minWidth = GlassDockGeometry.HeightDp.dp,
        minHeight = GlassDockGeometry.HeightDp.dp,
    ) {
        Icon(
            imageVector = icon,
            // 有可见文字的场景不存在（圆钮只有图标），所以这里必须给语义名。
            contentDescription = contentDescription,
            tint = MiuixTheme.colorScheme.onPrimary,
            modifier = Modifier.size(24.dp),
        )
    }
}

/**
 * 给官方转场预设套一层**时长缩放**：几何一点不改，只把「程序化整步」那一档
 * 的时长换成按倍率缩放过的值。
 *
 * ## 为什么必须是「包一层」而不是自己写几何
 *
 * `MIUIX-FIRST` 规定页面转场只能用 miuix 官方能力（`NavTransitions.MiuixDefault`
 * + `NavDisplayEffects.Default`），自己写 `slideIn…` / `fadeIn…` 这类转场是禁区。
 * 而官方预设把时长写死在自己声明的 `NavMotion` 里（没有参数可传），所以这里用委托的方式：
 * `transformEntry / opaqueDepth / dismissDirection / scrimFraction` 全部原样转交
 * 官方对象，**只**替换 `motion.programmatic`。
 *
 * ## 倍率口径（与 Dart 逐条对齐）
 *
 * Dart `HyperosMotionPlatform.durationScaler` 把每个动画的基础毫秒数按倍率缩放，
 * 方向是「**速度越大、时长越短**」（`scaledDuration(base) = base / speed`）；
 * 上下限 `clamp(0.5, 2.5)` 与设置页滑杆的区间一致（`settings_general.dart:70-72`）。
 *
 * 基础时长取 500ms —— 这就是官方 `NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS`
 * 的默认值（那个对象是 `internal`，引用不到，只能把数值抄在这里并守住语义）。
 */
private fun NavTransition.scaledToUserSpeed(speed: Double): NavTransition {
    val clamped = speed.coerceIn(MIN_PAGE_TRANSITION_SPEED, MAX_PAGE_TRANSITION_SPEED)
    val baseDuration = OFFICIAL_PROGRAMMATIC_DURATION_MILLIS
    // 速度 2.0 ⇒ 250ms；0.5 ⇒ 1000ms；1.0 ⇒ 500ms（原速）。
    val durationMillis = (baseDuration / clamped).roundToInt().coerceAtLeast(1)
    val scaledMotion = NavMotion(
        programmatic = NavSettleSpec.Tween(durationMillis, NavProgrammaticEasing),
    )
    val delegate = this
    return object : NavTransition {
        override fun Modifier.transformEntry(scope: NavTransitionScope): Modifier =
            with(delegate) { this@transformEntry.transformEntry(scope) }

        override val opaqueDepth: Float get() = delegate.opaqueDepth

        override val dismissDirection: NavSwipeDirection get() = delegate.dismissDirection

        override val motion: NavMotion get() = scaledMotion

        override fun scrimFraction(scope: NavTransitionScope): Float = delegate.scrimFraction(scope)
    }
}

/** 转场速度滑杆的下限（`TimetableSettings.minPageTransitionSpeed`）。 */
private const val MIN_PAGE_TRANSITION_SPEED = 0.5

/** 转场速度滑杆的上限（`TimetableSettings.maxPageTransitionSpeed`）。 */
private const val MAX_PAGE_TRANSITION_SPEED = 2.5

/** miuix `NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS` 的默认值（对方是 internal）。 */
private const val OFFICIAL_PROGRAMMATIC_DURATION_MILLIS = 500

/** 震动关掉时的空实现：所有 `performHapticFeedback` 都静默丢弃。 */
private object NoopHapticFeedback : HapticFeedback {
    override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) = Unit
}
