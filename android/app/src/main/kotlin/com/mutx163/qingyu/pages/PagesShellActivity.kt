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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.pages.shell.GlassDockItem
import com.mutx163.qingyu.pages.shell.GlassDockNavigationBar
import com.mutx163.qingyu.pages.task.TaskListPage
import com.mutx163.qingyu.app.ScheduleListHost
import com.mutx163.qingyu.app.TimetableHost
import java.time.LocalDate
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.nav.core.NavDisplay
import top.yukonga.miuix.kmp.nav.core.NavDisplayEffects
import top.yukonga.miuix.kmp.nav.core.navBackStackOf
import top.yukonga.miuix.kmp.nav.transition.NavTransitions
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.icon.extended.Settings

/**
 * Compose 迁移 Phase 3 · 页面开发壳（composeUi 变体专属）。
 *
 * ## 结构按原 App 骨架排版（2026-10-27 起，替代早期的「示例菜单」）
 *
 * 主屏 = 课表周视图；底部 dock 三个槽位：课表 / 日程 / 任务——与正式 App 的
 * 「课表主屏 + 玻璃坞内嵌页」同构（玻璃/壁纸效果不在壳里复刻，那属于样式批次）。
 * 带 `.ui` 包名后缀，与正式版/调试版并存，**不会覆盖手机上的正式版**。
 *
 * ## 数据是示例值，不是真实数据
 *
 * 本壳读不到正式版的 FlutterSharedPreferences。日程页喂示例条目只为核对版式与
 * 文案；任务页/课表是空态骨架，示例条目与真实数据接线属于后续批次。
 *
 * ## 接线进度（2026-10-27 晚）
 *
 * 三个槽位（课表周视图 / 日程列表 / 任务列表）与之前**完全一样**，一个字都没动。
 *
 * 第四槽位「索引」是**旁路**：原来的三个槽位没覆盖到的 75 个页面，在索引里点一行
 * 就进得去，返回回到索引。没有它，那 75 个页面在真机上一个都点不到，
 * L4 逐页对照就无从做起。目录（[com.mutx163.qingyu.pages.shell.ShellPageCatalog]）
 * 与分派（[ShellPageContent]）分开：加一页只改这两处，不碰槽位逻辑。
 *
 * 索引里每条都标了数据来路：
 * - 无标记：页面自带默认值，直接进；
 * - 「演示数据」：壳读不到正式版数据，喂的是示例值，只看版式与文案；
 * - 「暂不可用」：缺宿主能力（二维码发送/扫码要拍照与编解码，仓库里没有），
 *   宁可不给入口，也不造个假实现骗人点。
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

    // 页面层用 miuix-nav 的返回栈（唯一合规做法，不自研转场）。栈底是 [ShellRoute.Dock]
    // （底部四槽主屏），打开一页 push 一层、返回 pop 一层；切槽 = 替换栈底那条路由。
    // 所有转场由 NavDisplay（NavTransitions.MiuixDefault + NavDisplayEffects.Default）负责，
    // 不写一行自研动画。
    val backStack = remember { navBackStackOf(ShellRoute.Dock(DockSlot.TIMETABLE.id)) }

    fun popPage() {
        if (backStack.size > 1) backStack.removeLastOrNull()
    }

    fun pushPage(id: String) {
        val route = ShellRoute.Page(id)
        // 幂等：同一页已在栈里就不再压（重复 contentKey 会被运行时拒绝，也会让返回分叉）。
        if (route !in backStack) backStack.add(route)
    }

    // 栈顶路由：是 Dock 则停在主屏某个槽；是 Page 则压着页面层。
    val topRoute = backStack.lastOrNull()
    val currentSlot = (topRoute as? ShellRoute.Dock)
        ?.let { r -> DockSlot.entries.firstOrNull { it.id == r.slotId } }
        ?: DockSlot.TIMETABLE
    val atRoot = topRoute is ShellRoute.Dock

    // 切槽 = 替换栈底那条 Dock 路由（过渡交给 NavDisplay）。压着页面时坞不显示，走不到这。
    fun selectSlot(newSlot: DockSlot) {
        if (backStack.size == 1) backStack[0] = ShellRoute.Dock(newSlot.id)
    }

    // 系统返回：压着页面时由 NavDisplay.onBack 弹层；栈底且非课表槽时回课表主屏。
    BackHandler(enabled = atRoot && currentSlot != DockSlot.TIMETABLE) {
        selectSlot(DockSlot.TIMETABLE)
    }

    // 玻璃的背景采样源：整个内容区先被录进这个 layer，底栏再拿它当 backdrop。
    // 必须挂在**内容**上、而不是包住整个 Column —— 包住就会把底栏自己也录进去，
    // 底栏于是拿「含自己」的图去算模糊，展开动画里明暗会来回颤。
    val backdrop = rememberLayerBackdrop()
    val glassAvailable = isRuntimeShaderSupported()

    // 根 Scaffold：只为一件事——把弹层（`OverlayBottomSheet` / `OverlayListPopup`）的宿主
    // 抬到玻璃底栏之上。miuix 的弹层走「root scaffold」这条通道；没有这层根 Scaffold 时，
    // 它落在课表页自己的 Scaffold 里，而玻璃底栏画在页内容的上一层 → 弹层底部会被底栏盖住。
    // 容器透明 + 窗口内缩置零：不改变页面自身的边到边布局。
    Scaffold(
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
    ) { _ ->
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .layerBackdrop(backdrop),
            ) {
                NavDisplay(
                    backStack = backStack,
                    onBack = { popPage() },
                    transition = NavTransitions.MiuixDefault,
                    effects = NavDisplayEffects.Default,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    // 栈底：底部四槽主屏。切槽已经过「替换这条路由」，转场由 NavDisplay 做。
                    entry<ShellRoute.Dock> { route ->
                        val dockSlot = DockSlot.entries.firstOrNull { it.id == route.slotId }
                            ?: DockSlot.TIMETABLE
                        when (dockSlot) {
                            // Phase 3.5：课表槽位改用**真宿主**——真数据 + 真回调。
                            DockSlot.TIMETABLE -> TimetableWithCourseActions(
                                wiring = wiring,
                                onNavigate = { target -> pushPage(target) },
                            )
                            DockSlot.SCHEDULE -> ScheduleListHost(
                                repository = wiring.timetable,
                                todayIso = LocalDate.now().toString(),
                                onBack = { selectSlot(DockSlot.TIMETABLE) },
                                onAdd = {
                                    wiring.clearScheduleIntent()
                                    wiring.pendingScheduleInitialDate = LocalDate.now().toString()
                                    pushPage("d2.addSchedule")
                                },
                                onEdit = { item ->
                                    wiring.pendingScheduleEdit = item
                                    wiring.pendingScheduleOccurrenceDate = null
                                    pushPage("d2.addSchedule")
                                },
                                onDelete = { item -> wiring.deleteScheduleItem(item, null) },
                            )
                            DockSlot.TASK -> TaskListPage(
                                viewState = shellSampleTaskViewState(),
                                onBack = { selectSlot(DockSlot.TIMETABLE) },
                                onDateFilterChange = { },
                                onCourseFilterClick = { },
                                onAddTask = { pushPage("d2.addTask") },
                                onEditTask = { pushPage("d2.addTask") },
                                onToggleTask = { },
                                onDeleteTask = { },
                            )
                            // 设置主槽位：直接渲染设置主页，点击子项自然 push 子页面。
                            DockSlot.SETTINGS -> ShellPageContent(
                                pageId = "b.settingsHome",
                                onBack = { selectSlot(DockSlot.TIMETABLE) },
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

            // 只在栈底（没压页面）时显示玻璃坞：页面层占满整屏，底部操作区不能被坞压住；
            // 压着页面时点坞也会让「返回」语义分叉。
            if (atRoot) {
                GlassDockNavigationBar(
                    items = dockItems,
                    selectedIndex = currentSlot.ordinal,
                    onSelect = { index -> selectSlot(DockSlot.entries[index]) },
                    // 设备不支持 runtime shader 时别把 backdrop 传进去：
                    // 传了也画不出模糊，反而会多录一层、白费一次采样。
                    backdrop = if (glassAvailable) backdrop else null,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }
    }
}

/**
 * 四个槽位的图标。
 *
 * 选型理由：课表=日历格（`Months`）、日程=清单（`ListView`）、任务=勾选（`Tasks`）、
 * 索引=笔记/目录（`Notes`）——前三个与 Flutter 版玻璃坞的图标语义对齐；
 * 名字都取自 `miuix-icons` 的 extended 组，已确认存在（见 `MiuixIcons` 扩展属性）。
 *
 * 第四个是迁移期专用：正式 App 的玻璃坞只有三个槽位，这里多出来的是
 * 「其余 75 页怎么点到」的入口，给完之后随页面接线一起拆。
 */
private val dockItems: List<GlassDockItem>
    @Composable get() = listOf(
        // 不再传 contentDescription：有 label 时读屏只该念可见文字，两样都给会念两遍
        // （详见 GlassDockNavigationBar 里那处 semantics 的注释）。
        GlassDockItem(icon = MiuixIcons.Months, label = DockSlot.TIMETABLE.label),
        GlassDockItem(icon = MiuixIcons.ListView, label = DockSlot.SCHEDULE.label),
        GlassDockItem(icon = MiuixIcons.Tasks, label = DockSlot.TASK.label),
        GlassDockItem(icon = MiuixIcons.Settings, label = DockSlot.SETTINGS.label),
    )

/** dock 槽位：课表 / 日程 / 任务 / 设置 四大常驻入口。[id] 是路由里用的稳定短串。 */
private enum class DockSlot(val id: String, val label: String) {
    TIMETABLE("timetable", "课表"),
    SCHEDULE("schedule", "日程"),
    TASK("task", "任务"),
    SETTINGS("settings", "设置"),
}

/*
 * 课表槽位占位页已于 2026-10-27 18:40 移除：P3-C1 的 `pages/timetable/` 已挂进
 * composeUi 源集并取得 L1 绿，槽位换回 `TimetableWeekPage()`。
 */
