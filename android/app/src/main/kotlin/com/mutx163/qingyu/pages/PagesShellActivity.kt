package com.mutx163.qingyu.pages

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.LocaleList
import android.view.View
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.DeviceFontFamilyName
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.core.content.ContextCompat
import com.mutx163.qingyu.LiveUpdateScheduler
import com.mutx163.qingyu.ScheduleReminderCoordinator
import com.mutx163.qingyu.app.AppFontMode
import com.mutx163.qingyu.app.AppThemeMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.app.TimetableHomeViewMode
import com.mutx163.qingyu.pages.schedule.ScheduleDateRuleAutoApplyHost
import com.mutx163.qingyu.pages.live.LiveSnapshotBuilder
import com.mutx163.qingyu.pages.live.LiveSnapshotSyncRegistry
import com.mutx163.qingyu.pages.live.LiveSnapshotSyncer
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.platform.PerfProbe
import com.mutx163.qingyu.pages.shell.HomeDockNavModel
import com.mutx163.qingyu.pages.shell.HomeGlassDock
import com.mutx163.qingyu.pages.shell.homeDockVisible
import com.mutx163.qingyu.pages.shell.rememberHomeDockUsesBackdrop
import kotlin.math.roundToInt
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
     * ⚠️ 效果边界：壳的页面文案来自各页 `*Strings.zh` 常量（非 Android 资源），所以
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

        // 实时活动的设置只在 Compose 宿主落盘（`timetable_settings`），而原生岛读的是
        // `LiveUpdateScheduler` 的 `snapshot_json`——两者之间原本没有桥，于是「改了显示
        // 设置，岛毫无变化」。这里把同步器挂到进程级注册点，由 [LiveSnapshotSyncRegistry]
        // 在每次显示设置 / 提醒时段落盘后调用（见 pages/live/LiveDisplayStore.kt）。
        installLiveSnapshotSync(applicationContext)

        requestNotificationPermissionOnce()

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
            // 日程提醒 / 日期规则自动套用：仓储是纯 Kotlin，Android 侧的回调与端口在这里装上。
            // 日程提醒还会在每次增删改后由 `TimetableRepository.syncExamReminders()` 触发重排。
            val schedulePrefs = remember { PrefsKeyValueStore(applicationContext) }
            LaunchedEffect(wiring) {
                withContext(Dispatchers.IO) {
                    ScheduleReminderCoordinator.install(applicationContext, wiring.timetable)
                    ScheduleDateRuleAutoApplyHost.applyDue(wiring.timetable, schedulePrefs)
                }
            }
            var settingsModel by remember(wiring) {
                mutableStateOf(wiring.settingsModel.load())
            }
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
                PagesShell(
                    wiring = wiring,
                    settingsModel = settingsModel,
                    onReloadSettings = { settingsModel = it },
                )
            }
        }
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
 */
private fun withAppLocale(base: Context): Context {
    val tag = runCatching {
        TimetableSettingsModelStore(
            TimetableStore(PrefsKeyValueStore(base)),
        ).load().appLocaleTag
    }.getOrNull().orEmpty()
    if (tag.isBlank()) return base
    val locale = runCatching { LocaleList.forLanguageTags(tag)[0] }.getOrNull() ?: return base
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

    // 外部入口落点（R1 补口 2026-11-02）：VIEW/SEND 导入 / umeng scheme / mikcb-debug
    // 深链由透明跳板 ShellExternalEntryActivity 解析后 post 到 hub，这里一行消费推页。
    ShellExternalEntryEffect(onOpenPage = { target -> pushPage(target) })

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
        // 推入转场期间栈底条目仍在屏幕上（被滑入的页盖住一部分），坞会露出一条可点的边。
        // 这时改主屏内容既看不到效果，还会把「没到过的视图」写进存档（2026-11-01 审计）。
        if (backStack.size > 1) return
        // 目录页（外观编辑器 / 统计 / 考试…）不是主屏内容：**推一层**，底栏随之让位。
        // 以前这里不分流，任何条目都替换栈底，于是把「外观编辑器」排进底栏后底栏一直压在
        // 它上面（`atRoot` 恒 true）：既不参与页面的入场动画，页面上也多一条不属于它的坞
        // （2026-11-01 用户报「底栏没跟着缩小、留在了原来的位置」）。
        // 分流判据是纯逻辑，见 `HomeDockNavModel.rendersAsRoot`。
        if (!HomeDockNavModel.rendersAsRoot(itemId)) {
            val target = rootPageIdFor(itemId) ?: return
            // 「首页缩放」档（目前只有外观编辑页）：那一页自己把首页缩进预览卡，
            // 壳用瞬时切换、不再叠侧滑（见 [ShellRoute.ZoomPage]）。
            if (HomeDockNavModel.zoomsFromHome(target)) pushZoomPage(target) else pushPage(target)
            return
        }
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

    // 系统返回：压着页面时由 NavDisplay.onBack 弹层；栈底且不在周视图时回周视图。
    BackHandler(enabled = atRoot && currentRootId != ROOT_WEEK) {
        selectRoot(ROOT_WEEK)
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
    // 只有坞**真的会采样**（液态 / 磨砂档 + 设备支持）才挂录像层：实体档 / 关掉时
    // 坞不跑 drawBackdrop，录像纯属每次重绘多画一遍整页（2026-11-01 审计）。
    val recordBackdrop = glassAvailable && rememberHomeDockUsesBackdrop(settingsModel)

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
                // 内容由底栏条目 id 决定：`week`/`day`/`monthView` → 周 / 日 / 月视图；
                // 内嵌页（Dart `inlineDockPages`）→ 对应页面，坞常驻；返回回到周视图。
                entry<ShellRoute.Dock> { route ->
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
                                    // 设置页当场换肤：把新模型回推到 `setContent` 顶层的
                                    // `settingsModel`，`QingyuPageTheme` 立刻重建。
                                    onSettingsChanged = onReloadSettings,
                                )
                            }
                        }
                        HomeGlassDock(
                            settingsModel = settingsModel,
                            selectedId = route.itemId,
                            // 底栏条目 → 壳页面：与「有没有去处」同一张表（视图动作另有分支）。
                            isNavigable = { id -> rootPageIdFor(id) != null },
                            onSelect = { id -> selectRoot(id) },
                            onRoundButton = { handleRoundButton() },
                            // 设备不支持 runtime shader 时别把 backdrop 传进去：
                            // 传了也画不出模糊，反而会多录一层、白费一次采样。
                            backdrop = if (glassAvailable) backdrop else null,
                            modifier = Modifier.align(Alignment.BottomCenter),
                        )
                    }
                }
                // 页面层：任意目录 id 的一层。返回 = 弹掉这层，回到它下面那一页/主屏。
                // 它**盖住**栈底条目（含坞）—— 与 Dart 推入路由页同口径。
                entry<ShellRoute.Page> { route ->
                    ShellPageContent(
                        pageId = route.id,
                        onBack = { popPage() },
                        wiring = wiring,
                        // 页面内部「推新页」：路由字符串 → 壳页面 id（映射表在 ShellWiring.kt）。
                        onOpenPage = { target -> pushPage(target) },
                        onSettingsChanged = onReloadSettings,
                    )
                }
                // 「首页缩放」档（目前只有外观编辑页）：官方 `NavTransitions.None` = 瞬时切换，
                // 页面自己从整屏缩进预览卡（`AppearanceEditorScreen` 的入场）。
                // 不写自研转场：这里只是**不插一脚**，几何全在页面内部。
                entry<ShellRoute.ZoomPage>(transition = InstantSwap) { route ->
                    ShellPageContent(
                        pageId = route.id,
                        onBack = { popPage() },
                        wiring = wiring,
                        onOpenPage = { target -> pushPage(target) },
                        onSettingsChanged = onReloadSettings,
                    )
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
