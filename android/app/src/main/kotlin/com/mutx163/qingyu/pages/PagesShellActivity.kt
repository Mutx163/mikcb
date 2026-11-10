package com.mutx163.qingyu.pages

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.LocaleList
import android.provider.Settings
import android.view.Choreographer
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.DeviceFontFamilyName
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.core.content.ContextCompat
import com.mutx163.qingyu.LiveUpdateScheduler
import com.mutx163.qingyu.ExamReminderCoordinator
import com.mutx163.qingyu.ScheduleReminderCoordinator
import com.mutx163.qingyu.NotificationLaunchTarget
import com.mutx163.qingyu.UmengApplication
import com.mutx163.qingyu.app.AppFontMode
import com.mutx163.qingyu.app.AppLocaleRuntime
import com.mutx163.qingyu.app.AppLocaleUiBridge
import com.mutx163.qingyu.app.AppThemeMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.app.rememberHomeBackdropChrome
import com.mutx163.qingyu.components.QingyuLocalWindowAdaptive
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.LocalQingyuPageIsRootEntry
import com.mutx163.qingyu.components.rememberQingyuShellRailAdaptive
import com.mutx163.qingyu.app.TimetableHomeViewMode
import com.mutx163.qingyu.pages.schedule.ScheduleDateRuleAutoApplyHost
import com.mutx163.qingyu.pages.live.LiveSnapshotBuilder
import com.mutx163.qingyu.pages.live.LiveSnapshotSyncRegistry
import com.mutx163.qingyu.pages.live.LiveSnapshotSyncer
import com.mutx163.qingyu.pages.guide.FirstRunPrivacyGate
import com.mutx163.qingyu.pages.guide.PrivacyConsentPreferences
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.platform.PerfProbe
import com.mutx163.qingyu.platform.ScreenCaptureWatcher
import com.mutx163.qingyu.app.CourseRecolorSheetHost
import com.mutx163.qingyu.pages.import.CourseRecolorHistoryStore
import com.mutx163.qingyu.pages.import.ImportRandomColorStore
import com.mutx163.qingyu.pages.shell.HomeDockNavModel
import com.mutx163.qingyu.pages.shell.HomeMenuNavModel
import com.mutx163.qingyu.pages.shell.DockPagerMotion
import com.mutx163.qingyu.pages.shell.HomeGlassDock
import com.mutx163.qingyu.pages.shell.ShellNavigationRail
import com.mutx163.qingyu.pages.shell.homeDockVisible
import com.mutx163.qingyu.pages.shell.localeTagFromRawSettingsJson
import com.mutx163.qingyu.pages.shell.rememberHomeDockUsesBackdrop
import kotlin.math.roundToInt
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.nav.core.NavDisplay
import top.yukonga.miuix.kmp.nav.core.NavDisplayEffects
import top.yukonga.miuix.kmp.nav.core.NavKey
import top.yukonga.miuix.kmp.nav.core.navBackStackOf
import top.yukonga.miuix.kmp.nav.runtime.NavProgrammaticEasing
import top.yukonga.miuix.kmp.nav.transition.NavMotion
import top.yukonga.miuix.kmp.nav.transition.NavSettleSpec
import top.yukonga.miuix.kmp.nav.transition.NavSwipeDirection
import top.yukonga.miuix.kmp.nav.transition.NavTransition
import top.yukonga.miuix.kmp.nav.transition.NavTransitionScope
import top.yukonga.miuix.kmp.nav.transition.NavTransitions
import top.yukonga.miuix.kmp.utils.springAnimateToPage
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
 * 主屏切换的转场（2026-11-03 起）：内容区是 `HorizontalPager`，主屏条目由壳的
 * `currentRootId` 状态持有，点底栏用 miuix 官方 `springAnimateToPage` 沿标签顺序
 * 滑到目标页（右边的标签从右进、左边反之）。miuix-nav 对路由替换（`NavChange.Replace`）
 * 官方就是瞬时直切 —— 根级切换要动画只有这条官方形态（官方 demo `AppContent.kt`
 * 的 `MainPagerState` 同款）；换条目不再动返回栈。周 / 日两格是同一课表页的
 * 两种展开态，互点不滑动、保留页内的展开窗口动画。
 *
 * 推入的页面有两种转场（都是官方能力，壳不自研几何）：
 * * 普通页走官方 `NavTransitions.MiuixDefault` 侧滑；
 * * 「首页缩放」档（目前只有外观编辑页，Dart `HomeMenuEntry.zoomTransition` 同口径）走
 *   官方 `NavTransitions.None` **瞬时切换** —— 那一页自己会把首页缩进预览卡，
 *   壳叠一层侧滑就变成「新页从右边滑进来」了（2026-11-01 用户报的现象）。
 *   见 [ShellRoute.ZoomPage] 与 `HomeDockNavModel.zoomsFromHome`。
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

    /**
     * 通知权限申请入口（Android 13+）。
     *
     * 为什么壳里必须自己申请：`dev` / `bench` 变体把 [com.mutx163.qingyu.MainActivity]
     * 置为禁用、由本壳当启动页，而项目里唯一申请过 `POST_NOTIFICATIONS` 的地方是
     * MainActivity 的方法通道（由 Flutter 侧在用户打开相关开关时调用）。壳里根本不经过
     * 那条路，于是考试提醒 / 周报 / 实时活动 / 局域网前台服务的通知在壳包里全都发不出来。
     *
     * 只问一次（结果写进独立 prefs），拒绝后不再反复弹窗；权限本身由系统设置管理，
     * 用户随时可以自己开。
     */
    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    /**
     * 应用语言：在 Context 挂载前按存档里的 `appLocaleTag` 覆写配置语言。
     *
     * 只用 Android 原生路径（`LocaleList` + `createConfigurationContext`）——本工程没有
     * appcompat，`AppCompatDelegate.setApplicationLocales` 不可用。
     *
     * ⚠️ 效果边界：壳的页面文案来自各页 `*Strings.text` 常量（非 Android 资源），所以
     * 这里只影响 `Locale.getDefault()` / 资源语言，**不会把界面文字换成外语**。
     * 要真正多语言，得先把文案资源化（ARB），不在本文件的能力范围。
     *
     * 空串 = 跟随系统（不覆写）。
     */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(withAppLocale(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // R09 通知点击落页（冷启动）：解析 open_route / open_lan_edit，投进
        // ShellExternalEntryHub；壳里既有的 ShellExternalEntryEffect 负责推页
        //（组合树尚未建立也能落页，hub 是进程级状态）。无页面参数时是空操作。
        //
        // 守卫为什么是 savedInstanceState == null：本 Activity 在 manifest 的
        // configChanges 已含 orientation|screenSize，**旋转 / 分屏不重建 Activity**，
        // 所以这里防的不是旋转，而是「进程被系统回收后按原任务恢复」——那会把用户
        // 已经关掉的页面重新推出来。非空 savedInstanceState 只在恢复场景出现，故跳过。
        //
        // ⚠️ 已知边缘（真机确认项，别当没有）：进程死亡后用户从通知栏点一条**新**通知
        // 冷启，若系统同时带回非空 savedInstanceState，本守卫会把这条新落点一起吞掉，
        // 表现为「点通知回到壳却没进对应页」。需真机复现「杀进程 → 点通知」确认；
        // 若命中，改用「该 Intent 是否真的携带页面 extra」而非 savedInstanceState 作判据。
        if (savedInstanceState == null) {
            NotificationLaunchTarget.postLaunchPage(intent)
        }

        // 实时活动的设置只在 Compose 宿主落盘（`timetable_settings`），而原生岛读的是
        // `LiveUpdateScheduler` 的 `snapshot_json`——两者之间原本没有桥，于是「改了显示
        // 设置，岛毫无变化」。这里把同步器挂到进程级注册点，由 [LiveSnapshotSyncRegistry]
        // 在每次显示设置 / 提醒时段落盘后调用（见 pages/live/LiveDisplayStore.kt）。
        installLiveSnapshotSync(applicationContext)

        // 通知权限弹窗**不**在这里申请（2026-11-09）：它是系统弹窗，冷启动一开就盖在
        // 启动画面上，用户还没看到首页就先被问一句；且第一次申请要走权限服务的 binder。
        // 改成首帧画完之后再问（见文件末尾的 Choreographer 回调），两不耽误。

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

        // 截屏检测（Android 14+ 官方 ScreenCaptureCallback）：注册/注销由组件自管
        // （STARTED 才注册、退后台/销毁自动摘除），壳只在这里挂一次。
        // 事件出口 onScreenshot 暂无消费方（Dart 版的「分享课表图」提示未移植），
        // 接线方式见 platform/ScreenCaptureWatcher.kt 头注。
        ScreenCaptureWatcher.attach(this)

        // 语言切换的 UI 桥：必须在首次组合前装好，后续 `set()` 才能把
        // `AppLocaleRuntime` 的变化变成 Compose 可观察的状态（不重建壳）。
        AppLocaleUiBridge.install()

        setContent {
            // ── 外观设置 → 主题桥 ──────────────────────────────────────────────
            // 设置存储没有变更通道（只有 load / save），所以这里读一次进 state；
            // `PagesShell` 在「回到主屏」时重读并回推（`onReloadSettings`），
            // 外观页改完返回后立刻生效。
            //
            // 2026-11-01 之前这里只写 `QingyuPageTheme { PagesShell() }`：明暗恒取
            // `isSystemInDarkTheme()`、字重恒 400、字体/字号/种子色/语言**没有任何消费方**
            // ——外观页改了设置，界面纹丝不动。现在逐项接上：
            // * `appThemeMode` → 解析出 `isDark`，同时由 QingyuPageTheme 覆写
            //   `LocalConfiguration`，让 91 处页面级 `isSystemInDarkTheme()` 同口径；
            // * `themeSeedColor` → 配色板的 primary / primaryVariant；
            // * `appFontWeight` / `appFontMode` → 字阶字重与字族；
            // * `appTextScale` → `LocalDensity.fontScale` 缩放；
            // * `appLocaleTag` → `attachBaseContext`（仅启动时生效，见该方法注释）。
            val wiring = rememberShellWiring()
            // ── 首启隐私门（B1，2026-11-10）──────────────────────────────────────
            // 冷启动先读两枚 Dart 契约键（`flutter.accepted_privacy_policy` /
            // `flutter.has_seen_user_guide`）：都齐 → 直接进壳（对齐 v2.1.4.1
            // `_handleStartupFlows` 的快速路径）；否则先渲染首启门，勾选同意并退出
            // 后才挂壳。首启门的落盘与守门逻辑在 `FirstRunPrivacyGate`。
            val privacyPrefs = remember {
                PrivacyConsentPreferences(PrefsKeyValueStore(applicationContext))
            }
            var firstRunDone by remember { mutableStateOf(privacyPrefs.isFirstRunComplete()) }
            LaunchedEffect(firstRunDone) {
                if (!firstRunDone) return@LaunchedEffect
                // 友盟 `init` 只能在同意之后：`Application` 里只做了 `preInit`；
                // 这里按同意键兜住「老用户冷启 + 刚同意」两条路径（幂等）。
                withContext(Dispatchers.IO) {
                    UmengApplication.initializeAnalyticsIfConsented(applicationContext)
                }
                // 通知权限顺延到首启门之后：未同意隐私前不弹系统权限框。
                Choreographer.getInstance().postFrameCallback {
                    requestNotificationPermissionOnce()
                }
            }
            // 日程提醒 / 日期规则自动套用：仓储是纯 Kotlin，Android 侧的回调与端口在这里装上。
            // 日程提醒还会在每次增删改后由 `TimetableRepository.syncExamReminders()` 触发重排。
            val schedulePrefs = remember { PrefsKeyValueStore(applicationContext) }
            LaunchedEffect(wiring) {
                // 首启隐私门未过之前不跑启动副作用（天气初始化可能发网、提醒协调器会排
                // AlarmManager）：在这里**等门打开**再执行一次，而不是把 firstRunDone 加进
                // key——加 key 会让整个副作用块在翻门时重跑，行为不再等价于旧版「启动一次」。
                if (!firstRunDone) {
                    snapshotFlow { firstRunDone }.first { it }
                }
                withContext(Dispatchers.IO) {
                    // 启动对账（settings → native pref）从 ShellWiring 构造函数搬到首帧之后：
                    // 它要读整份设置 JSON，还可能排一次 AlarmManager（binder），
                    // 都不属于首帧渲染所需。见 `ShellWiring.reconcileStartupPrefs`。
                    wiring.reconcileStartupPrefs()
                    ScheduleReminderCoordinator.install(applicationContext, wiring.timetable)
                    // 考试提醒：考试 / 课程 / 日程增删改与冷启动、恢复备份后整表重排
                    //（对位上面日程提醒的安装；开机 / 换时区补排走 ExamReminderReceiver，无需在此装）。
                    ExamReminderCoordinator.install(applicationContext, wiring.timetable)
                    ScheduleDateRuleAutoApplyHost.applyDue(wiring.timetable, schedulePrefs)
                    // 天气：Dart 是 `ChangeNotifierProvider(create: (_) => WeatherProvider()..initialize())`
                    //（`lib/main.dart:492`）——**启动即读配置 + 补一次过期就刷**。
                    // 此前 Compose 侧唯一调用点是「设置 → 天气」页，于是冷启动到首页时
                    // `enabled` 还是默认 false，日卡/周卡天气行整块不渲染，用户得偶然进一次
                    // 设置页才看得到天气。initialize() 幂等（内部 `initialized` 门控），
                    // 放 IO 里是因为它会读盘并可能发一次网。
                    wiring.weather.initialize()
                }
            }
            // A1（2026-11-03）：初值不再自己解析一遍 JSON —— 取 ShellWiring 构造时
            // 那一次共享解析（`initialSettings`）；之后的更新仍走 onReloadSettings /
            // settingsRevision（回主屏重读），那条纪律不变。
            var settingsModel by remember(wiring) {
                mutableStateOf(wiring.initialSettings)
            }
            // 语言：冷启动已在 `attachBaseContext` 里按存档写过一次；这里兜住「切换后立即生效」——
            // 回调在事件线程执行，不靠重组副作用，下一帧就是新语言。
            SideEffect { AppLocaleRuntime.set(settingsModel.appLocaleTag) }
            val appDark = resolveAppDark(
                mode = settingsModel.appThemeMode,
                systemDark = isSystemInDarkTheme(),
            )
            // 字族实例每次调用都是新对象；按字体档 remember 一下，免得字阶 remember 键抖动。
            val fontFamily = remember(settingsModel.appFontMode) {
                appFontFamily(settingsModel.appFontMode)
            }
            SideEffect { applyShellSystemBars(isDark = appDark) }
            // 壳的主题必须也走主题桥：无参 MiuixTheme{ } 的配色恒取官方默认亮色板，
            // 系统切深色后卡片仍是 #FFFFFF，而正文取的是 QingyuTheme 的深色白字
            // → 白字白底、内容不可读（页面层已由 QingyuPageTheme 兜住，壳这层是
            // 根因，此处一并修掉）。用 QingyuPageTheme 后页面里的同款包装成为
            // 重复但等价的一层，后续可逐页摘除。
            QingyuPageTheme(
                isDark = appDark,
                seedColor = settingsModel.themeSeedColor,
                userFontWeight = settingsModel.appFontWeight,
                fontFamily = fontFamily,
                textScale = settingsModel.appTextScale.toFloat(),
            ) {
                // 语言切走的是「重组」而不是「重建壳」：`ArbText.text` 每次取值都会读
                // `AppLocaleUiBridge` 的 revision state，语言一变，正在显示的文案自动重组；
                // 返回栈、滚动位置、表单草稿都保留（不会弹回首页）。
                if (firstRunDone) {
                    PagesShell(
                        wiring = wiring,
                        settingsModel = settingsModel,
                        onReloadSettings = {
                            settingsModel = it
                            AppLocaleRuntime.set(it.appLocaleTag)
                        },
                    )
                } else {
                    FirstRunPrivacyGate(
                        wiring = wiring,
                        onCompleted = { routePageId ->
                            firstRunDone = true
                            // 指南里的「导入 / 恢复 / 课程总览」入口：首启门完成后把目标页
                            // 交给壳的进程级落点通道（`ShellExternalEntryEffect` 消费；
                            // 壳还没挂载时 post 不会丢）。
                            if (routePageId != null) {
                                ShellExternalEntryHub.post(routePageId, null)
                            }
                        },
                    )
                }
            }
        }

        // A2（2026-11-03）：启动打点「首帧」段。Choreographer 首帧回调是标准做法，
        // 不新造机制：setContent 之后排一个一次性回调，第一个 vsync 到来时补记
        // firstFrame。此时探针已安装（onCreate 早段 PerfProbe.attach），打点走探针
        // 自己的单调时钟；正式包探针未安装，这条打点被直接丢弃，零成本。
        // 语义边界（如实说明）：它是「setContent 后第一个 vsync」，极端情况下可能
        // 略早于 Compose 首绘完成，读数是首帧耗时的近似上界。启动分段于是有三段：
        // mainEnter（进程进入 Application）→ shellAttach（壳挂载）→ firstFrame（首帧）。
        Choreographer.getInstance().postFrameCallback {
            PerfProbe.markStartup("firstFrame")
            // 通知权限不在这里申请：B1（2026-11-10）起顺延到首启隐私门通过之后，
            // 见 setContent 里的 `LaunchedEffect(firstRunDone)`——避免系统权限框
            // 盖在隐私页前面，把「先同意再要权限」的次序打乱。
        }
    }

    /**
     * R09 通知点击落页（后台 singleTop 复用）：manifest 里本 Activity 是
     * `launchMode="singleTop"`，通知 Intent 带 FLAG_ACTIVITY_SINGLE_TOP 时走这里，
     * 不重建 Activity。解析后同样投进 ShellExternalEntryHub，推页由壳的组合钩子完成。
     *
     * `setIntent` 保证后续代码（含 Activity 重建）读到的是最新 Intent；已解析的
     * extra 由 [NotificationLaunchTarget.postLaunchPage] 移除，重建不会重复推页。
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        NotificationLaunchTarget.postLaunchPage(intent)
    }

    /** 当前资源配置是否为深色。仅作首帧兜底，组合内以「主题模式 + 系统」解析出的明暗为准。 */
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

    /** 见 [notificationPermissionLauncher]：Android 13+ 且未授权、且没问过时，问一次。 */
    private fun requestNotificationPermissionOnce() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return
        val prefs = getSharedPreferences(NOTIFICATION_PERMISSION_PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_NOTIFICATION_PERMISSION_ASKED, false)) return
        prefs.edit().putBoolean(KEY_NOTIFICATION_PERMISSION_ASKED, true).apply()
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}

/**
 * 应用语言：按存档的 `appLocaleTag` 覆写配置语言。空串 = 跟随系统。
 *
 * 见 [PagesShellActivity.attachBaseContext] 的效果边界说明。
 *
 * A1（2026-11-03）：这里早于一切 UI，此前为了拿一个语言键把整份设置模型反序列化
 * 一遍（首帧前 4 遍解析之一）。现在只读 `timetable_settings` 原始串、单键捞出语言
 * 标记，读口径与全量模型逐字一致（对拍测试 `ShellColdStartSettingsTest` 钉住）；
 * 损坏留档仍由冷启动必经的 `ShellWiring` 解析在同一次启动里完成，最终状态不变。
 */
private fun withAppLocale(base: Context): Context {
    val tag = runCatching {
        localeTagFromRawSettingsJson(
            PrefsKeyValueStore(base).getString(TimetableStore.KEY_SETTINGS),
        )
    }.getOrNull().orEmpty()
    if (tag.isBlank()) {
        AppLocaleRuntime.set("")
        return base
    }
    val locale = runCatching { LocaleList.forLanguageTags(tag)[0] }.getOrNull() ?: return base
    AppLocaleRuntime.set(tag)
    Locale.setDefault(locale)
    val config = Configuration(base.resources.configuration).apply { setLocale(locale) }
    return base.createConfigurationContext(config)
}

/** 主题模式 + 系统明暗 → 壳的实际明暗。 */
private fun resolveAppDark(mode: AppThemeMode, systemDark: Boolean): Boolean = when (mode) {
    AppThemeMode.SYSTEM -> systemDark
    AppThemeMode.LIGHT -> false
    AppThemeMode.DARK -> true
}

/**
 * 应用字体 → Compose 字族。`SYSTEM` 返回 null（不覆写，跟随系统默认）。
 *
 * 名称与 Dart `lib/ui/app_fonts.dart:137-163` 的 `fontFamily` 逐字一致（同一批系统字体）。
 * Android 侧必须走 `Font(DeviceFontFamilyName(...))`：本工程用的是 KMP 版 Compose，
 * `Font(deviceFontFamilyName: String)` 那个 Android 专属重载不存在，直接传 String 会
 * 落到 `Font(resId: Int)` 而编译失败（2026-11-01 实测）。系统上没有该字体时 Compose
 * 自动回落到默认，不会崩。
 */
private fun deviceFontFamily(name: String): FontFamily =
    FontFamily(Font(DeviceFontFamilyName(name)))

private fun appFontFamily(mode: AppFontMode): FontFamily? = when (mode) {
    AppFontMode.SYSTEM -> null
    AppFontMode.SANS_SERIF -> FontFamily.SansSerif
    AppFontMode.SERIF -> FontFamily.Serif
    AppFontMode.MONOSPACE -> FontFamily.Monospace
    AppFontMode.MI_SANS -> deviceFontFamily("MiSans")
    AppFontMode.HARMONY_OS -> deviceFontFamily("HarmonyOS Sans SC")
    AppFontMode.OPPO_SANS -> deviceFontFamily("OPlus Sans SC 3.5")
    AppFontMode.PING_FANG -> deviceFontFamily("PingFang SC")
    AppFontMode.NOTO_SANS -> deviceFontFamily("Noto Sans CJK SC")
    AppFontMode.SONG_TI -> deviceFontFamily("Songti SC")
}

/**
 * 把「设置落盘 → 同步原生岛快照」的桥挂到进程级注册点。
 *
 * ## 怎么做
 *
 * 原生岛读的是 `LiveUpdateScheduler` 的 `snapshot_json`；本壳的显示设置页只写
 * `timetable_settings`。两者的「settings」子树本是一份数据（Dart
 * `buildLiveSnapshotSettingsJson` = `settings.toJson()` + 展开详情版本号），所以这里
 * **不重建整份快照**（那需要课程 / 当前周 / 节假日，壳不拥有），而是读既有快照、
 * 只替换 `settings` 子树（课程等原样保留），再交给 `LiveUpdateScheduler.syncSnapshot`。
 *
 * ## 边界（如实说明）
 *
 * 盘上还没有任何快照时（例如全新 dev 壳，原生侧从未被 Dart 同步过）**什么都不做**：
 * 凭空造一份没有课程的快照只会把岛打成「空课表」。快照的首次建立仍由 Dart 侧的
 * 课程同步负责；本桥负责的是「快照已存在时，设置改动也能传到岛」。
 *
 * prefs 名 / key 与 `LiveUpdateScheduler` 的私有常量同值（对方是 private，引用不到）。
 */
private fun installLiveSnapshotSync(context: Context) {
    LiveSnapshotSyncRegistry.install(
        LiveSnapshotSyncer { settingsJson ->
            val prefs = context.getSharedPreferences(LIVE_SCHEDULER_PREFS, Context.MODE_PRIVATE)
            val existing = prefs.getString(LIVE_SNAPSHOT_KEY, null)
            val merged = LiveSnapshotBuilder.withSettings(existing, settingsJson)
            if (merged != null) {
                runCatching { LiveUpdateScheduler.syncSnapshot(context, merged) }
            }
        },
    )
}

/** 与 `LiveUpdateScheduler.PREFS_NAME` 同值（对方 private）。 */
private const val LIVE_SCHEDULER_PREFS = "live_update_scheduler"

/** 与 `LiveUpdateScheduler.KEY_SNAPSHOT_JSON` 同值（对方 private）。 */
private const val LIVE_SNAPSHOT_KEY = "snapshot_json"

@Composable
private fun PagesShell(
    /** Phase 3.5 接线层：壳自己的存储 + 课表仓储（由 [PagesShellActivity] 组合级持有）。 */
    wiring: ShellWiring,
    /**
     * 用户设置（底栏排列 / 形态 / 圆钮 / 首页视图档，以及外观项）。
     *
     * 状态提到 `setContent` 顶层持有——[QingyuPageTheme] 包在 `PagesShell` 外面，
     * 只有在外层拿到它，主题 / 字重 / 字号才可能在设置变化时重组。
     */
    settingsModel: TimetableSettingsModel,
    /** 回到主屏时重读设置后的回推（外层据此更新主题）。 */
    onReloadSettings: (TimetableSettingsModel) -> Unit,
) {
    // ── 用户设置 ────────────────────────────────────────────────────────────
    // 设置存储没有变更通道（`TimetableSettingsModelStore` 只有 load / save），旧做法是
    // 「每次重组 load 一遍」。这里读一次进 state，并在**回到主屏**时重读：设置页改完
    // 返回后立刻生效，滚动、动画的每一帧又不用重新解析一遍 JSON。
    // 状态本体已提到外层（见参数注释），这里只负责触发重读。

    // 底栏条目排列 / 图标 / 圆钮的解析**不在这里**：坞由栈底条目自己画（见 `HomeGlassDock`），
    // 排列解析与渲染同处一处，壳只负责告诉它「当前是哪个条目」和「哪个 id 有去处」。
    //
    // 底栏形态：`classic` 是 Dart 的「不挂玻璃坞」档（`home_chrome_spec.dart:78-80`：
    // `glassDockForm = homeNavigationForm == glassDock`，非坞档直接返回 `dockContent`，
    // 坞层连建都不建）。这里照做：classic 不画底栏，也不录它的采样层。
    val showDock = homeDockVisible(settingsModel)

    // ── 宽屏三档（2026-11-03 第 2 批：壳层侧边导航栏）────────────────────────
    // Rail 是玻璃坞在宽档的替身：只在「玻璃坞形态 + 真实宽窗口」（平板 / 折叠屏内屏）
    // 出现——classic 档用户显式关掉了导航，宽屏也不加回（尊重用户的选择）。
    // 判据与数值全在 core/QingyuAdaptiveRules.kt；Rail 出现后页面骨架按「内容区宽」
    // 取值，经下方 CompositionLocalProvider 注入（第 1 批预留的 QingyuLocalWindowAdaptive）。
    // 手机竖屏（<600dp）时 railVisible 恒 false，下方 Row 退化为单个内容盒，逐像素同前。
    val shellRail = rememberQingyuShellRailAdaptive(railEnabled = showDock)

    // ── 两个「运行期偏好」：改了当场生效，不用重启（Dart 是同一个形态）───────────────
    val systemHaptics = LocalHapticFeedback.current
    val shellHaptics: HapticFeedback =
        if (wiring.enableHaptics) systemHaptics else NoopHapticFeedback
    val pageTransition = remember(wiring.pageTransitionSpeed) {
        NavTransitions.MiuixDefault.scaledToUserSpeed(wiring.pageTransitionSpeed)
    }

    // 页面层用 miuix-nav 的返回栈（推页/返回的转场仍由它负责，不自研）。栈底是
    // [ShellRoute.Dock]（主屏，无参数）；打开一页 push 一层、返回 pop 一层。
    // **换底栏条目不再动返回栈**（2026-11-03）：主屏停在第几个条目由下面的
    // [currentRootId] 状态持有，内容区用 `HorizontalPager` 承载、点底栏
    // `springAnimateToPage`（miuix 官方工具，官方 demo 同款）滑过去 —— miuix-nav 对
    // `NavChange.Replace` 官方就是瞬时直切（旧条目同帧卸载、驱动 float 不动），
    // 根级切换要左右滑只能走官方 demo 的 Pager 形态。
    //
    // 首屏停在哪个视图由存档决定（Dart `timetableHomeViewMode`，冷启动恢复上次停留的
    // 周 / 日 / 月）—— 这是此前同样没接上的一个死键。
    // A1（2026-11-03）：初值改取 ShellWiring 共享的那一次解析（`initialSettings`），
    // 不再整份重读 JSON。键仍是 `remember(wiring)`：换 wiring 才重算。
    val initialRootId = remember(wiring) {
        rootItemIdForView(wiring.initialSettings.timetableHomeViewMode)
    }
    // 底栏条目排列：与坞 / Rail 同一个解析入口（`HomeDockNavModel.resolveDockIds`，
    // 用户存档驱动 + 开发壳索引追加），Pager 的页列表由它派生，三处逐字同源。
    val dockIds = remember(settingsModel) {
        HomeDockNavModel.resolveDockIds(settingsModel.glassDockActions) { id ->
            rootPageIdFor(id) != null
        }
    }
    // Pager 页列表：主屏内渲染的条目按规范键去重（day/week 是同一课表宿主的两种
    // 展开态，必须是同一页）；冷启动恢复的条目不在排列里时补到末尾。映射与方向
    // 判据在 `DockPagerMotion`（纯逻辑，JVM 单测钉住）。
    val dockPageIds = remember(dockIds, initialRootId) {
        DockPagerMotion.pageItemIds(dockIds, initialRootId)
    }
    // 当前主屏条目：**高亮与滑动目标的事实源**。点击底栏立即更新（选中态即时响应），
    // 内容区由 [animateDockPagerTo] 在点击作用域内直接滑到对应页。
    var currentRootId by remember { mutableStateOf(initialRootId) }
    val pagerState = rememberPagerState(
        initialPage = DockPagerMotion.indexOfPage(dockPageIds, initialRootId) ?: 0,
    ) {
        dockPageIds.size
    }
    val backStack = remember { navBackStackOf(ShellRoute.Dock) }

    // 底栏切换动画的启动器（官方 demo `MainPagerState.animateToPage` 的壳侧等价）：
    // **点击作用域内直接 launch**，不等重组——如果经由 `LaunchedEffect(currentRootId)` 触发，
    // 点击帧只写状态、动画要等下一帧重组应用后才起步，中间隔出 1~2 帧零位移
    //（用户 2026-11-03 报的「切换起步顿一下」主因之一，同帧还有目标页首帧组合，见
    // Pager 的 beyondViewportPageCount 注释）。连点不同标签时取消上一个滑动协程再起新的，
    // 收敛到最新目标（demo 的 `navJob?.cancel()` 同语义）。系统关动画
    //（`ANIMATOR_DURATION_SCALE` ≤ 0，判据 `DockPagerMotion.reducedMotion`）时直接落定、
    // 零中间帧；系统值只在组合期读一次，改开发者选项后壳会重建取新值。
    val context = LocalContext.current
    val pagerReducedMotion = remember(context) {
        DockPagerMotion.reducedMotion(
            Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            ),
        )
    }
    val pagerAnimScope = rememberCoroutineScope()
    // 在飞滑动协程的引用：连点时取消上一个。不进快照状态（job 变化不需要重组）。
    val pagerAnimJobRef = remember { java.util.concurrent.atomic.AtomicReference<kotlinx.coroutines.Job?>(null) }
    // 「最新一次点击」的序号：只有它那条协程落定（或被打断）后才允许回写 currentRootId，
    // 避免旧协程追上新的点击结果。与 pushSeq 同一手法，只是这里比的是「谁最新」。
    val pagerAnimSeq = remember { java.util.concurrent.atomic.AtomicLong(0L) }

    // ── 底栏「弹层动作」通道（Dart `HomeMenuEntry.open`，2026-11-09）──────────────
    // `courseRecolor`（弹重配色面板）与 `shareTimetable`（分享本周课表图）是目录里的
    // **合法条目**，但都不是页面。底栏/八宫格必须共用 [shellTimetableMenuSupported]
    // 这一条判据，否则「编辑器里加得进去、底栏上不出现」（用户报的整格消失同源）。
    // 这两个 id 点下来在这里落地：配色弹面板、分享直接发起。
    var pendingMenuAction by remember { mutableStateOf<String?>(null) }
    val recolorColorStore = remember(context) {
        ImportRandomColorStore(PrefsKeyValueStore(context))
    }
    val recolorHistoryStore = remember(context) {
        CourseRecolorHistoryStore(PrefsKeyValueStore(context))
    }

    /**
     * 把 [currentRootId] 对齐到 Pager **真正停着的那一页**（高亮 / 坞墨色的事实源）。
     *
     * 官方 demo 同口径：`MainPagerState.animateToPage` 的 `finally` 里用
     * `pagerState.currentPage` 回写 `selectedPage`（`AppContent.kt:837-848`）——动画被
     * 连点取消、或被系统压成零时长时，高亮仍落在眼前实际那一页上。
     */
    fun reconcileRootWithPager() {
        val actual = dockPageIds.getOrNull(pagerState.currentPage) ?: return
        if (actual != currentRootId) currentRootId = actual
    }

    /**
     * 取消在飞的底栏滑动，并让它的对账**失效**：seq 前进 ⇒ 被取消那条协程的 `finally`
     * 看到序号已不是最新，不再回写 `currentRootId`。
     *
     * 所有「换掉当前滑动」的路径都必须走它（不要各自 `cancel()`）：漏掉 bump 时，老协程会在
     * `finally` 里把 `currentRootId` 按「取消那一刻 Pager 所在的页」回写，覆盖掉调用方刚写的新值
     * （2026-11-05 复核：`openZoomFromWeek` 曾漏掉这一句，从外观编辑页返回后底栏高亮会指错格）。
     *
     * @return 本次取消之后的「最新序号」；需要自己回写的调用方拿它当自己的 seq。
     */
    fun cancelPagerAnim(): Long {
        val seq = pagerAnimSeq.incrementAndGet()
        pagerAnimJobRef.getAndSet(null)?.cancel()
        return seq
    }

    /** 点击作用域内直接滑到 [itemId] 对应的主屏页（起步不隔帧，见上方注释）。 */
    fun animateDockPagerTo(itemId: String) {
        val target = DockPagerMotion.indexOfPage(dockPageIds, itemId)
        if (target == null) {
            // 目标页不在 Pager 里（条目被移出底栏 / 页列表缩了）：不滑，也**不让
            // currentRootId 悬空**——调用方通常已经先写了它，这里立刻按眼前那一页回写。
            // 所有调用方共用这一个出口，所以这条对账只写一遍。
            reconcileRootWithPager()
            return
        }
        val seq = cancelPagerAnim()
        pagerAnimJobRef.set(
            pagerAnimScope.launch {
                try {
                    if (pagerReducedMotion) {
                        pagerState.scrollToPage(target)
                    } else {
                        pagerState.springAnimateToPage(target)
                    }
                } finally {
                    // 只有「仍是最新一次点击」的那条才回写（旧协程被取消后也会走 finally）。
                    if (pagerAnimSeq.get() == seq) reconcileRootWithPager()
                }
            },
        )
    }

    /**
     * 推页序号：每次 push 分配一个递增 token，让两条路由的值互不相等。
     *
     * 为什么不复用同一个 key（2026-11-01 真机事故「退出外观编辑页后再进不来」）：
     * miuix-nav 在旧页仍在退场（约 500ms）时又推入 **相同 key** 的页，会复用旧条目实例、
     * 不重建 composition —— 页面自己的入场进度与 `exiting` 守卫都停在退场那一刻，
     * 于是「点了没反应」（外观编辑页表现为停在全屏预览卡、取消/完成也不响应）。
     * 每次一个新 token ⇒ 新条目、新 composition；旧条目照常自己播完退场。
     */
    val pushSeq = remember { java.util.concurrent.atomic.AtomicLong(0L) }

    fun popPage() {
        if (backStack.size > 1) backStack.removeLastOrNull()
    }

    /** 推一层页面：幂等 + 环状导航（同一页已在栈里时弹回那一层，而不是静默无反应）。 */
    fun pushRoute(route: ShellRoute) {
        // 2026-10-31 审核 P2-1：旧写法 `if (route !in backStack) add` 让
        // 「A 页 → B 页 → 又点 A」静默无反应（用户点了没动静，只能猜）。
        //
        // 判重看的是「同一类 + 同一个 id」，**忽略 pushToken**（每次推页都不相同）；
        // 否则连点两次同一入口会压出两层一模一样的页面。
        val existing = backStack.indexOfFirst { it.sameTargetAs(route) }
        if (existing >= 0) {
            while (backStack.size > existing + 1) backStack.removeLastOrNull()
            return
        }
        backStack.add(route)
    }

    fun pushPage(id: String) {
        pushRoute(ShellRoute.Page(id, pushToken = pushSeq.incrementAndGet()))
    }

    /**
     * 推一层**「首页缩放」档**的页面（见 [ShellRoute.ZoomPage]）。
     *
     * 与 [pushPage] 只差路由类型：那一档的入场是瞬时切换，页面自己负责把首页缩进预览卡。
     */
    fun pushZoomPage(id: String) {
        pushRoute(ShellRoute.ZoomPage(id, pushToken = pushSeq.incrementAndGet()))
    }

    /**
     * 打开「首页缩放」档页面（外观编辑）：先把主屏 Pager 滑回周视图，**落定后**再推 ZoomPage。
     *
     * 为什么要先滑回周视图：ZoomPage 的入场是「把整屏首页缩进预览卡」，收缩底图 = 栈底
     * Pager 的当前页。若此刻停在统计 / 设置等非课表页，直接 pushZoomPage 会把那一页
     * 缩进卡片（用户 2026-11-04 报：别的页面点外观编辑，缩放底图不是周视图）。故先
     * `currentRootId = ROOT_WEEK` 再滑到周视图页，等 `springAnimateToPage` 挂起返回（= 落定）
     * 后再推页，避免 InstantSwap 把滑动从中间截断。
     *
     * 压着推入页（从设置页点进）时先弹回主屏让 Pager 可见 —— 这正是「先滑回周视图」的前提，
     * 与「返回键回首页」BackHandler 不冲突（滑完推页后 atRoot 变 false，本函数不在其块内）。
     */
    fun openZoomFromWeek(id: String) {
        // 先弹回主屏：设置页 / 深层页压着时 Pager 在下面看不见，谈不上「滑回周视图」。
        while (backStack.size > 1) backStack.removeLastOrNull()
        val target = DockPagerMotion.indexOfPage(dockPageIds, ROOT_WEEK)
        if (target == null) {
            // 极端：底栏里根本没有周视图页（日/周都移出底栏且冷启动不在周）。无可滑目标，
            // 退化为直接推页，不猜、不崩。
            pushZoomPage(id)
            return
        }
        // 与点底栏同一套：**先 bump seq 再取消**在飞的滑动（2026-11-05 复核）。
        // 只 cancel 不 bump 的话，被取消那条老协程的 `finally` 仍认为自己是「最新」，
        // 会执行 reconcileRootWithPager()，把下面刚设的 ROOT_WEEK 覆盖成「取消那一刻所在的页」
        // ⇒ 从外观编辑页返回后，画面是周视图、底栏高亮（与坞墨色）却指在别的格。
        cancelPagerAnim()
        pagerAnimJobRef.set(
            pagerAnimScope.launch {
                currentRootId = ROOT_WEEK
                if (pagerReducedMotion) {
                    pagerState.scrollToPage(target)
                } else {
                    // 挂起函数：animateToPage 播完、updateCurrentPage 后才返回 = Pager 落定。
                    pagerState.springAnimateToPage(target)
                }
                // 落定后再缩放进入，缩放底图此刻必是周视图。
                pushZoomPage(id)
            },
        )
    }

    /** 页面推入口统一出口：外观编辑走「先回周视图再缩放」，其余照旧普通推页。 */
    fun openPage(target: String) {
        if (HomeDockNavModel.zoomsFromHome(target)) openZoomFromWeek(target) else pushPage(target)
    }

    // 外部入口落点（R1 补口 2026-11-02）：VIEW/SEND 导入 / umeng scheme / mikcb-debug
    // 深链由透明跳板 ShellExternalEntryActivity 解析后 post 到 hub，这里一行消费推页。
    ShellExternalEntryEffect(onOpenPage = { target -> pushPage(target) })

    // 底栏「弹层动作」的落地：与八宫格共用同一份白名单
    // （[HomeMenuNavModel.MENU_ACTION_IDS]）。之前在底栏解析里被「没有页面」丢掉，
    // 现在条目能出现在坞上，点下来在这里执行。
    if (pendingMenuAction == HomeMenuNavModel.ACTION_COURSE_RECOLOR) {
        CourseRecolorSheetHost(
            repository = wiring.timetable,
            colorStore = recolorColorStore,
            historyStore = recolorHistoryStore,
            onDismiss = { pendingMenuAction = null },
            onToast = { message -> Toast.makeText(context, message, Toast.LENGTH_SHORT).show() },
        )
    }
    // 分享是「一次性动作」：定位到本周周图、发起系统分享，然后把待办动作清掉。
    LaunchedEffect(pendingMenuAction) {
        if (pendingMenuAction == HomeMenuNavModel.ACTION_SHARE_TIMETABLE) {
            wiring.shareCurrentWeekImage(context)
            pendingMenuAction = null
        }
    }

    // 视图档落盘（`timetableHomeViewMode` / `timetableLastViewedDayOfWeek`）已搬进
    // `ShellWiring.switchHomeViewMode` / `setHomeSelection`：周 / 日是页内展开态，
    // 写入口不止底栏一处（星期栏点某天、日视图翻页也要写），放到壳里会变成多份
    // 互斥量/线程池。那边仍是「先改内存、IO 线程串行单键写」，纪律不变。

    /** 切到主屏某个条目（= Flutter 玻璃坞点某个槽位）。 */
    fun selectRoot(itemId: String) {
        // 推入转场期间栈底条目仍在屏幕上（被滑入的页盖住一部分），坞会露出一条可点的边。
        // 这时改主屏内容既看不到效果，还会把「没到过的视图」写进存档（2026-11-01 审计）。
        if (backStack.size > 1) return
        // 弹层动作（课表重新配色 / 分享课表图片）：不是页面，当场执行；
        // 不参与 Pager 页列表与高亮（判据见 [HomeMenuNavModel.MENU_ACTION_IDS]）。
        if (HomeMenuNavModel.isMenuAction(itemId)) {
            pendingMenuAction = itemId
            return
        }
        // 目录页（外观编辑器 / 统计 / 考试…）不是主屏内容：**推一层**，底栏随之让位。
        // 以前这里不分流，任何条目都替换栈底，于是把「外观编辑器」排进底栏后底栏一直压在
        // 它上面（`atRoot` 恒 true）：既不参与页面的入场动画，页面上也多一条不属于它的坞
        // （2026-11-01 用户报「底栏没跟着缩小、留在了原来的位置」）。
        // 分流判据是纯逻辑，见 `HomeDockNavModel.rendersAsRoot`。
        if (!HomeDockNavModel.rendersAsRoot(itemId)) {
            val target = rootPageIdFor(itemId) ?: return
            // 「首页缩放」档（目前只有外观编辑页）：那一页自己把首页缩进预览卡，
            // 壳用瞬时切换、不再叠侧滑（见 [ShellRoute.ZoomPage]）。
            if (HomeDockNavModel.zoomsFromHome(target)) openZoomFromWeek(target) else pushPage(target)
            return
        }

        val mode = homeViewModeOf(itemId)

        // ── 周 / 日：同一个首页宿主的两种展开态，特殊效果不经 Pager ──
        // 原版 Flutter 的底栏「日/周」就是在首页内部切展开态（`toggleDayView`），
        // 「选中的那一列长成整屏」的窗口动画由页面自己播（2026-11-02 用户实报后接的）。
        // day 与 week 在 Pager 里也是同一页（`DockPagerMotion.normalizePageKey`），
        // 所以这两格互点不滑动，只在「从别的底栏页切回课表」时才让 Pager 滑过去。
        if (mode == TimetableHomeViewMode.WEEK ||
            mode == TimetableHomeViewMode.DAY ||
            mode == TimetableHomeViewMode.MONTH
        ) {
            if (DockPagerMotion.slideStep(currentRootId, ROOT_WEEK, dockPageIds) == 0) {
                // 已在课表页：只切页内态，页面自己播窗口动画（周/日）或直接换正文（月）。
                if (mode == TimetableHomeViewMode.MONTH) {
                    if (wiring.homeViewMode == TimetableHomeViewMode.MONTH) return
                    // 月视图没有展开/收起几何：在同一宿主里横向滑入/滑出，
                    // 壁纸仍由宿主最底层静态画，不跟着走。
                    wiring.switchHomeViewMode(
                        TimetableHomeViewMode.MONTH,
                        animate = true,
                        horizontal = true,
                    )
                    return
                }
                if (mode == TimetableHomeViewMode.DAY) {
                    // 重复点「日」同档：无动作（Dart `timetable_dock_actions.dart` 同口径）。
                    if (wiring.homeViewMode == TimetableHomeViewMode.DAY) return
                    wiring.setHomeSelection(wiring.homeSelectedWeek, wiring.homeSelectedDayOfWeek)
                    // 底栏两格互点：横向 translateX 滑入/滑出（animate=true + horizontal=true）。
                    wiring.switchHomeViewMode(TimetableHomeViewMode.DAY, animate = true, horizontal = true)
                } else {
                    if (wiring.homeViewMode == TimetableHomeViewMode.WEEK) return
                    // 底栏两格互点：横向 translateX 滑入/滑出。
                    wiring.switchHomeViewMode(TimetableHomeViewMode.WEEK, animate = true, horizontal = true)
                }
                return
            }
            // 从别的底栏页切回课表：只让 Pager 做一次水平滑动，**不再重放日视图展开**。
            // 旧写法在进日视图时登记 `requestHomeViewMotion(WEEK)`，新宿主会把 `dayExpand`
            // 从 0 播到 1（从上往下展开），叠在横滑上就是用户报的「底栏切换上下翻」。
            // 现在不登记起点：宿主首帧直接按目标档落定（`dayProgressSeed` = 1/0），
            // 只有 Pager 的左右滑；「点星期栏某天进日视图」的 top-down 仍由
            // `switchHomeViewMode` → `dayExpand` 页内动画负责，与本路径无关。
            // 跨页来源：animate=false（页面 snapTo，不播 dayExpand），只让 Pager 横滑。
            // 目标页不在 Pager 里（用户把课表两格都从底栏删了）时**什么都不改**：
            // 改 homeViewMode / currentRootId 而 Pager 滑不过去，正是「高亮和画面分叉」的来源。
            if (DockPagerMotion.indexOfPage(dockPageIds, ROOT_WEEK) == null) return
            wiring.switchHomeViewMode(mode, animate = false)
            currentRootId = ROOT_WEEK
            animateDockPagerTo(ROOT_WEEK)
            return
        }

        // ── 其余主屏条目（任务 / 设置…）：Pager 沿标签顺序滑动 ──
        // 方向由页下标决定（目标在右从右进、在左反之），判据是纯逻辑
        // `DockPagerMotion.slideStep`；0 = 重复点当前页，无动作（Dart 同口径）。
        if (DockPagerMotion.slideStep(currentRootId, itemId, dockPageIds) == 0) return
        if (mode != null) wiring.switchHomeViewMode(mode)
        currentRootId = itemId
        animateDockPagerTo(itemId)
    }

    /**
     * 侧边导航栏（宽屏档）点条目：**先弹回主屏，再切换**（demo `AppContent.kt:371`
     * `popUntil { it is Route.Main }` 同口径）。
     *
     * 为什么不能直接用 [selectRoot]：它带「栈上有推入页就忽略」的守卫（紧凑档坞被页面
     * 盖住、点不到，所以那条守卫是对的）；Rail 在宽档**常驻**、压着页面也能点，
     * 直接调会变成「点了没反应」。先弹回主屏再走同一条 [selectRoot] 分流
     * （非 `rendersAsRoot` 条目照样推页）。
     */
    fun railSelectRoot(itemId: String) {
        while (backStack.size > 1) backStack.removeLastOrNull()
        selectRoot(itemId)
    }

    /** 圆钮（右侧独立按钮）：Dart `handleRoundButtonTap`（`home_menu_controller.dart:306-333`）。 */
    fun handleRoundButton() {
        val action = HomeDockNavModel.roundButtonAction(settingsModel.glassDockButtonEntryId)
        // 圆钮绑到弹层动作时同样当场执行。少了这一条会落到下面的
        // 「target == null ⇒ 开加课」分支：绑了「分享课表」却弹出加课页。
        if (HomeMenuNavModel.isMenuAction(action)) {
            pendingMenuAction = action
            return
        }
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

    // 栈顶路由：是 Dock 则停在主屏；是 Page 则压着页面层。
    val topRoute = backStack.lastOrNull()
    val atRoot = topRoute is ShellRoute.Dock

    // 底栏排列变化的对齐（不是点击切换的路径——那个由 [animateDockPagerTo] 在点击作用域
    // 内直接启动）：设置里改完底栏排列回主屏，页列表可能缩/移，把 Pager 对回当前条目
    // 对应的页。瞬时落定即可（低频、非观感路径）。
    LaunchedEffect(dockPageIds) {
        val target = DockPagerMotion.indexOfPage(dockPageIds, currentRootId)
        if (target != null) {
            if (target != pagerState.targetPage) {
                pagerState.scrollToPage(target)
            }
        } else {
            // 当前条目被移出底栏（或页列表缩了）：跟 Pager 实际停留的那一页对齐，
            // 别让高亮 / 坞墨色悬在一个已经不在排列里的 id 上（页面本身没换）。
            reconcileRootWithPager()
        }
    }

    // 高亮口径（侧边导航栏与玻璃坞**同源**，2026-11-03 第 2 批）：课表宿主的条目固定在
    // [ROOT_WEEK]（周 / 日是页内展开态，不换条目），高亮跟 `homeViewMode` 走
    //（[dockSelectedIdOf]）。主屏条目事实源是 [currentRootId]：压着页面时它不变，
    // Rail 仍亮背后的那个条目 —— 与 demo「推页不改 Rail 选中」一致；坞条目渲染在
    // 栈底条目里，按同一状态算高亮（推入转场期间坞还露着，高亮不能闪到别的条目上）。
    val railSelectedId = dockSelectedIdOf(currentRootId, wiring.homeViewMode)

    // 回到主屏时重读设置：设置页里改完底栏排列 / 形态 / 圆钮图标，返回主屏立刻是新的。
    // 设置页与图标挑选页都压在这个返回栈里（`ShellRoute.Page`）：push 时 `atRoot` 变 false，
    // pop 回栈底时再变 true，本效果于是重跑一次 `load()`。少了这一步，`glassDockButtonIconName`
    // 只在进程重启后才生效。
    //
    // 同时自增 [ShellWiring.settingsRevision]：首页页面内容（周 / 日 / 月视图）是在**组合期
    // 裸调** `settingsModel.load()` 读盘的，不是可观察状态 —— 返回主屏时页面条目一直被
    // NavDisplay 保持组合、参数又没变（Compose 强跳过），不通知就**不会重组**，材质 / 壁纸
    // 会停在进设置页之前的旧值上，直到用户翻一下页才刷新（2026-11-02 用户实报）。
    LaunchedEffect(atRoot) {
        if (atRoot) {
            onReloadSettings(wiring.settingsModel.load())
            wiring.settingsRevision++
        }
    }

    // 系统返回：压着页面（ShellRoute.Page / ZoomPage）时由 NavDisplay.onBack 弹层；
    // 停在主屏时 → 直接回**首页根**（2026-11-04 用户口径：回首页，不是回周视图）。
    //
    // 首页根 = 课表宿主 `c1.week`（周 / 日两档同页）+ 月档的 `monthView` 页；视图档
    // 原样取 `wiring.homeViewMode`（日→日、周→周、月→月），**不写死 WEEK** —— 从任意
    // 底栏内嵌页（任务 / 设置 / 统计 / 考试 / 总览…）按返回都回到用户当前所在的课表
    // 视图，而不是被强行拉回周视图。条目映射复用冷启动恢复的 `rootItemIdForView`
    // （WEEK/DAY → ROOT_WEEK、MONTH → monthView），不新增常量。
    //
    // 已停在首页根（周视图 / 日视图 / 月视图本身）时不拦，交系统退 App（与发布版一致）；
    // 日视图不再「收起成周视图」——那正是要修掉的「返回周视图」。
    val homeRootId = rootItemIdForView(wiring.homeViewMode)
    // 首页根**必须真的在 Pager 里**才拦返回：底栏既没排课表 / 月视图格、冷启动也没落在那里时
    // 根本没有可回的目标，交系统退 App —— 否则这会变成「按了没反应」的死键。
    val homeRootPageIndex = DockPagerMotion.indexOfPage(dockPageIds, homeRootId)
    BackHandler(enabled = atRoot && currentRootId != homeRootId && homeRootPageIndex != null) {
        // 只切栈底条目 + Pager 滑回首页根；不调 switchHomeViewMode，避免把日/月档写成 WEEK。
        // animateDockPagerTo 走 indexOfPage 命中才滑（与底栏切换同一套对齐逻辑，不猜）：
        // 月档页在 homeViewMode=MONTH 时必在 dockPageIds（底栏格或冷启动 ensure 补入）。
        currentRootId = homeRootId
        animateDockPagerTo(homeRootId)
    }

    // 玻璃的背景采样源：**栈底条目的页面内容**先被录进这个 layer，坞再拿它当 backdrop。
    // 必须挂在页面内容上、而不是包住底栏自己 —— 包住就会把坞自己也录进去，
    // 坞于是拿「含自己」的图去算模糊，动画里明暗会来回颤（与搬层前的纪律同一条）。
    //
    // ⚠️ 录制有成本：miuix 的 `LayerBackdropNode.draw()` 实际是
    // `drawContent(); recordLayer { onDraw() }` —— 内容每重绘一帧（滚动、转场、任何动画），
    // 都会先在屏幕上画一遍、再把整屏录进一张离屏 GraphicsLayer。所以只在
    // **有坞 + 设备支持 runtime shader** 时才挂；坞搬进栈底条目之后，压着页面时坞不再
    // 绘制（栈底条目不再重绘），这段录制也随之停下。
    val backdrop = rememberLayerBackdrop()
    val glassAvailable = isRuntimeShaderSupported()
    // 只有坞**真的会采样**（液态 / 磨砂档 + 设备支持 + 宽屏档坞没被 Rail 取代）才挂录像层：
    // 实体档 / 关掉时坞不跑 drawBackdrop，录像纯属每次重绘多画一遍整页（2026-11-01 审计）；
    // 宽屏档坞整块不组合（`replacedByRail`），采样源也随之停掉。
    val recordBackdrop = glassAvailable && !shellRail.railVisible &&
        rememberHomeDockUsesBackdrop(settingsModel)

    // 学期开学日 / 总周数：玻璃坞与宽屏档侧边导航栏**共用这一份**（「周」格画「开学第几周」
    // 的唯一输入）。读一次、两处传参 —— 两条渲染路径各拼一遍时口径迟早分叉。
    val semesterStartDate = wiring.timetable.snapshot.settings.semesterStartDate?.toLocalDate()
    val semesterWeekCount = wiring.timetable.snapshot.settings.semesterWeekCount

    // 根 Scaffold：只为一件事——把弹层（`OverlayBottomSheet` / `OverlayListPopup`）的宿主
    // 抬到玻璃底栏之上。miuix 的弹层走「root scaffold」这条通道；没有这层根 Scaffold 时，
    // 它落在课表页自己的 Scaffold 里，而玻璃底栏画在页内容的上一层 → 弹层底部会被底栏盖住。
    // 容器透明 + 窗口内缩置零：不改变页面自身的边到边布局。
    Scaffold(
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
    ) { _ ->
    // 震动总开关的落点：整棵页面树都挂在它下面（含玻璃坞与两个入口页）。
    // 宽屏自适应注入（第 2 批）：Rail 出现后，页面骨架的限宽/顶栏按「内容区宽」取值
    // （`QingyuPageScaffold` 经第 1 批预留的 [QingyuLocalWindowAdaptive] 消费）；
    // 无 Rail 时注入值与按窗口宽自算等价，手机竖屏行为不变。
    CompositionLocalProvider(
        LocalHapticFeedback provides shellHaptics,
        QingyuLocalWindowAdaptive provides shellRail.contentAdaptive,
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // 宽屏档：Rail 在 NavDisplay 左侧（demo `AppContent.kt:251-276` 同一结构）。
            // Row 无条件存在、Rail 条件组合——NavDisplay 保持**同一个组合位置**，
            // 宽窄切换（旋转/分屏）只增删外壳，不重建当前路由、不丢返回栈与转场状态。
            Row(modifier = Modifier.fillMaxSize()) {
                if (shellRail.railVisible) {
                    ShellNavigationRail(
                        settingsModel = settingsModel,
                        selectedId = railSelectedId,
                        // 条目 → 壳页面：与坞同一张表（视图动作另有分支）。
                        isNavigable = { id -> shellTimetableMenuSupported(id) },
                        // Rail 常驻可点：先弹回主屏再切换（`selectRoot` 的栈守卫会把
                        // 压着页面时的点击吞掉，见 [railSelectRoot] 注释）。
                        onSelect = { id -> railSelectRoot(id) },
                        onRoundButton = { handleRoundButton() },
                        expanded = shellRail.railExpanded,
                        // 与坞同一份学期数据：宽屏档坞不组合，周格「第几周」只能靠这里画。
                        semesterStartDate = semesterStartDate,
                        semesterWeekCount = semesterWeekCount,
                    )
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxSize()
                        // 宽屏档：Rail 已经占掉左边那条边，页面再按窗口的起始侧内边距
                        // （挖孔 / 侧边导航）缩一次，就会在容器里整体偏右、右边变窄。
                        // 官方 miuix-nav 文档「多栏」一节的第三条就是这条口径：
                        // pane 旁边有 chrome 时，chrome 已吃掉的边内边距不要再加一次。
                        .then(
                            if (shellRail.railVisible) {
                                Modifier.consumeWindowInsets(
                                    WindowInsets.systemBars
                                        .union(WindowInsets.displayCutout)
                                        .only(WindowInsetsSides.Start),
                                )
                            } else {
                                Modifier
                            },
                        )
                        // 宽屏档转场层不许画到 Rail 上面（demo `AppContent.kt:263` 同一条）。
                        .then(if (shellRail.railVisible) Modifier.clipToBounds() else Modifier),
                ) {
                    NavDisplay(
                        backStack = backStack,
                        onBack = { popPage() },
                        // 官方预设 + 按用户倍率缩放过的时长（见 [scaledToUserSpeed]）。
                        transition = pageTransition,
                        effects = NavDisplayEffects.Default,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                // 栈底：主屏 = **页面内容 + 玻璃坞**。坞由这一层自己画（2026-11-01 搬层），
                // 于是它与首页同属一棵子树：页面推入 / 缩放时坞跟着一起动，而不是整块消失；
                // 外观编辑页的缩尺预览卡也画这同一个组件，卡片里从此有坞。
                //
                // 内容区是 **HorizontalPager**（2026-11-03 左右滑转场）：主屏条目各占一页，
                // 点底栏由上面的切换效果 `springAnimateToPage` 滑到目标页（官方 demo 同款，
                // miuix-nav 的 Replace 无转场，根级切换只有这条官方形态）。手势翻页关闭：
                // 课表 / 月视图页内有自己的横向手势（翻周 / 翻月），Pager 不与之抢。
                // 页列表 `dockPageIds` 由底栏排列派生（day/week 归一成同一课表页）。
                entry<ShellRoute.Dock> { _ ->
                    // 根页标记（2026-11-03）：本条目是页面栈的栈底主屏（从底栏进入的那些页），
                    // 注入 true 后骨架不再画返回箭头——根页没有上一级可回。消费方只有
                    // QingyuPageScaffold（一处判定、全站生效）；物理返回键行为不在这里，
                    // 仍由下方 BackHandler / NavDisplay.onBack 负责，语义不变。
                    CompositionLocalProvider(
                        LocalQingyuPageIsRootEntry provides true,
                        // 玻璃坞满屏悬浮时，把「坞占用+系统安全区」作为底部滚动余量注入首页根页；
                        // QingyuPageList 自动消费（复刻 Flutter GlassDockScrollReliefScope）。
                        com.mutx163.qingyu.components.LocalGlassDockScrollRelief provides
                            com.mutx163.qingyu.pages.shell.rememberHomeFloatingInsets(settingsModel).scrollRelief,
                    ) {
                        Box(modifier = Modifier.fillMaxSize()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    // 只有真要采样的那一档才录制（理由见上方 `backdrop` 注释）。
                                    .then(
                                        if (recordBackdrop) {
                                            Modifier.layerBackdrop(backdrop)
                                        } else {
                                            Modifier
                                        },
                                    ),
                            ) {
                                HorizontalPager(
                                    state = pagerState,
                                    modifier = Modifier.fillMaxSize(),
                                    userScrollEnabled = false,
                                    // 预组合相邻 1 页（2026-11-03 起步顿挫修）：默认 0 时目标页
                                    // 在滑动第一帧才进入组合窗口，重页（课表/统计）首帧组合掉帧
                                    // 就是「起步一顿」的另一半成因。代价（如实）：
                                    // ① 冷启动首帧多组合 1 个相邻页（一次性，页在视口外不绘制）；
                                    // ② 常驻组合数 = 当前页 ± 1（内存多一份相邻页的组合树）。
                                    beyondViewportPageCount = 1,
                                ) { page ->
                                    val pageItemId = dockPageIds[page]
                                    if (pageItemId == HomeDockNavModel.DEV_INDEX_ID) {
                                        // 开发壳专属：页面索引（L4 逐页对照）。它不是一个业务页面，
                                        // 所以直接画在这里，不进 `ShellPageContent` 的分派表。
                                        ShellPageIndexScreen(
                                            onOpenPage = { target -> openPage(target) },
                                            onBack = { selectRoot(ROOT_WEEK) },
                                        )
                                    } else {
                                        ShellPageContent(
                                            pageId = rootPageIdFor(pageItemId) ?: ROOT_WEEK_PAGE_ID,
                                            onBack = { selectRoot(ROOT_WEEK) },
                                            wiring = wiring,
                                            onOpenPage = { target -> openPage(target) },
                                            // 设置页当场换肤：把新模型回推到 `setContent` 顶层的
                                            // `settingsModel`，`QingyuPageTheme` 立刻重建。
                                            onSettingsChanged = onReloadSettings,
                                        )
                                    }
                                }
                            }
                            HomeGlassDock(
                                // 坞的壁纸亮度：与页面同一份亮度带（已落盘，冷启动首帧可读）。
                                wallpaperLuminance = rememberHomeBackdropChrome(settingsModel).bands?.dock,
                                settingsModel = settingsModel,
                                // 高亮口径与 Rail 同源（见 [dockSelectedIdOf] 与 railSelectedId 注释）。
                                selectedId = dockSelectedIdOf(currentRootId, wiring.homeViewMode),
                                // 宽屏档整块不组合，由左侧 Rail 接管导航（方案第 2 批口径）。
                                replacedByRail = shellRail.railVisible,
                                // 底栏条目 → 壳页面：与「有没有去处」同一张表（视图动作另有分支）。
                                isNavigable = { id -> shellTimetableMenuSupported(id) },
                                onSelect = { id -> selectRoot(id) },
                                onRoundButton = { handleRoundButton() },
                                // 设备不支持 runtime shader 时别把 backdrop 传进去：
                                // 传了也画不出模糊，反而会多录一层、白费一次采样。
                                backdrop = if (glassAvailable) backdrop else null,
                                // 墨色判据要知道「坞底下是不是照片」：周 / 日 / 月视图是，
                                // 任务、设置这些内嵌页是不透明主题面（Dart `isInlinePage` 同口径）。
                                overWallpaper = DockPagerMotion.showsWallpaper(currentRootId),
                                // 与宽屏档 Rail 同一份学期数据（见上层 `semesterStartDate` 注释）。
                                semesterStartDate = semesterStartDate,
                                semesterWeekCount = semesterWeekCount,
                                modifier = Modifier.align(Alignment.BottomCenter),
                            )
                        }
                    }
                }
                // 页面层：任意目录 id 的一层。返回 = 弹掉这层，回到它下面那一页/主屏。
                // 它**盖住**栈底条目（含坞）—— 与 Dart 推入路由页同口径。
                // 注入 false：推入的二级/更深页保留返回箭头（设置 → 关于 → 更新这类）。
                entry<ShellRoute.Page> { route ->
                    CompositionLocalProvider(LocalQingyuPageIsRootEntry provides false) {
                        ShellPageContent(
                            pageId = route.id,
                            onBack = { popPage() },
                            // 导入成功后的「自动回首页」：弹到栈底（Dock），再归位到课表周视图。
                            // 只弹栈会落在用户进导入前停留的底栏格（统计/设置等），不是课表首页。
                            onBackToRoot = {
                                while (backStack.size > 1) backStack.removeLastOrNull()
                                selectRoot(ROOT_WEEK)
                            },
                            wiring = wiring,
                            // 页面内部「推新页」：路由字符串 → 壳页面 id（映射表在 ShellWiring.kt）。
                            onOpenPage = { target -> openPage(target) },
                            onSettingsChanged = onReloadSettings,
                        )
                    }
                }
                // 「首页缩放」档（目前只有外观编辑页）：官方 `NavTransitions.None` = 瞬时切换，
                // 页面自己从整屏缩进预览卡（`AppearanceEditorScreen` 的入场）。
                // 不写自研转场：这里只是**不插一脚**，几何全在页面内部。
                entry<ShellRoute.ZoomPage>(transition = InstantSwap) { route ->
                    // 推入型条目（外观编辑页从底栏点进也是推一层）：与 Page 同判，保留返回箭头。
                    CompositionLocalProvider(LocalQingyuPageIsRootEntry provides false) {
                        ShellPageContent(
                            pageId = route.id,
                            onBack = { popPage() },
                            wiring = wiring,
                            onOpenPage = { target -> openPage(target) },
                            onSettingsChanged = onReloadSettings,
                        )
                    }
                }
            }
                }
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
 * 主屏条目的**高亮 id**（玻璃坞与侧边导航栏同源的口径，2026-11-03 第 2 批）。
 *
 * 课表宿主固定对应 [ROOT_WEEK] 条目（周 / 日是页内展开态，不换条目），
 * 所以「日」档时高亮要落在日动作条目上；其余条目就是条目 id 本身。
 */
private fun dockSelectedIdOf(itemId: String, homeViewMode: TimetableHomeViewMode): String =
    if (itemId == ROOT_WEEK) {
        when (homeViewMode) {
            TimetableHomeViewMode.DAY -> HomeDockNavModel.ACTION_DAY
            TimetableHomeViewMode.MONTH -> "monthView"
            else -> ROOT_WEEK
        }
    } else {
        itemId
    }

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
    // 日视图（2026-11-02 起）是 `c1.week` 宿主里的展开态，不再有自己的页面。
    // 保留这个映射是为了「存档里残留 day / 从别处进来的 day 路由」也落在同一个宿主。
    HomeDockNavModel.ACTION_DAY -> ROOT_WEEK_PAGE_ID
    // 月视图（2026-11-07 起）是 `c1.week` 的第三种页内态：与周/日共用一张页面级
    // 静态壁纸。它的整页 `c2.month` 仍留给「更多功能」等直接推入的入口。
    "monthView" -> ROOT_WEEK_PAGE_ID
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
    // 周 / 日共用同一个栈底路由：日视图是页内展开态，冷启动恢复也走 `homeViewMode`，
    // 不靠路由 id（否则首帧会先落到 c3.day 再切回来）。
    TimetableHomeViewMode.WEEK -> ROOT_WEEK
    TimetableHomeViewMode.DAY -> ROOT_WEEK
    // 月视图也是 `c1.week` 的页内态：冷启动落在周宿主，由 `homeViewMode` 决定
    // `TimetableWithCourseActions` 渲染月内容。
    TimetableHomeViewMode.MONTH -> ROOT_WEEK
}

/**
 * 两条页面路由是否指向**同一个目标**（推页幂等的判据）。
 *
 * 同类 + 同 id 即视为同一目标，**忽略每次推送分配的 `pushToken`** —— 那个 token
 * 只用来保证路由值互不相等、让 miuix 每次推页都建新条目（见 `pushSeq` 的注释）。
 */
private fun NavKey.sameTargetAs(other: NavKey): Boolean = when {
    this is ShellRoute.Page && other is ShellRoute.Page -> id == other.id
    this is ShellRoute.ZoomPage && other is ShellRoute.ZoomPage -> id == other.id
    else -> this == other
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

// 栈底「替换」（底栏切页）已不复存在（2026-11-03）：主屏条目由壳的 currentRootId 状态
// 持有、内容区走 HorizontalPager 滑动，栈底 ShellRoute.Dock 无参数、永不替换 ——
// 旧版为「复刻 Flutter 直切」而写的 instantOnReplace 连同 NavChange.Replace 的判定
// 一起删除。NavDisplay 转场只剩推入（Push）/ 返回（Pop）/ 多层弹回（MultiPop），
// 全部由官方预设负责。

/** 通知权限「是否已问过」的 prefs 名与键：与业务设置分开，设置重置不影响它。 */
private const val NOTIFICATION_PERMISSION_PREFS = "shell_notification_permission"
private const val KEY_NOTIFICATION_PERMISSION_ASKED = "asked"

/** 转场速度滑杆的下限（`TimetableSettings.minPageTransitionSpeed`）。 */
private const val MIN_PAGE_TRANSITION_SPEED = 0.5

/** 转场速度滑杆的上限（`TimetableSettings.maxPageTransitionSpeed`）。 */
private const val MAX_PAGE_TRANSITION_SPEED = 2.5

/**
 * `NavTransitions.None` + **短驱动时长**（[INSTANT_SWAP_DURATION_MS]）。
 *
 * 「首页缩放」档几何上零位移（位置全在页面自己的入场里），但 miuix-nav 的驱动 float 仍要
 * 从 0 走到 1（推入）/ 1 走到 0（退出），默认 500ms。这段时间里**已经看不见的旧条目
 * 还在挡点击**（`NavEntryHost` 的 `opaqueInputModifier`）——用户 2026-11-01 报的
 * 「退出外观编辑页后再点底栏没反应」，一部分就是这个窗口。压到 100ms 后视觉上仍是
 * 瞬时切换，点击也马上回得来。
 *
 * 仍然是官方预设 + 只换时长（与 [scaledToUserSpeed] 同一手法），不是自研转场。
 */
private val InstantSwap: NavTransition = object : NavTransition {
    private val delegate = NavTransitions.None
    private val fastMotion = NavMotion(
        programmatic = NavSettleSpec.Tween(INSTANT_SWAP_DURATION_MS, NavProgrammaticEasing),
    )

    override fun Modifier.transformEntry(scope: NavTransitionScope): Modifier =
        with(delegate) { this@transformEntry.transformEntry(scope) }

    override val opaqueDepth: Float get() = delegate.opaqueDepth

    override val dismissDirection: NavSwipeDirection get() = delegate.dismissDirection

    override val motion: NavMotion get() = fastMotion

    override fun scrimFraction(scope: NavTransitionScope): Float = delegate.scrimFraction(scope)
}

/** 「首页缩放」档的驱动时长：只够把旧条目卸掉，不构成可见动画。 */
private const val INSTANT_SWAP_DURATION_MS = 100

/** miuix `NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS` 的默认值（对方是 internal）。 */
private const val OFFICIAL_PROGRAMMATIC_DURATION_MILLIS = 500

/** 震动关掉时的空实现：所有 `performHapticFeedback` 都静默丢弃。 */
private object NoopHapticFeedback : HapticFeedback {
    override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) = Unit
}
