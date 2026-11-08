package com.mutx163.qingyu.pages.shell

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.rememberHomeBackdropChrome
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.FloatingActionButton
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 首页**玻璃坞**（药丸 + 右侧圆钮）的唯一渲染入口。
 *
 * ## 为什么要有这个文件（2026-11-01 搬层）
 *
 * 底栏原先由壳（`PagesShellActivity`）画在 `NavDisplay` **之上**，是页面栈的兄弟节点。
 * 后果有三个，都是用户真机上看到的：
 *
 * 1. **它不跟着页面动**：页面推入 / 缩放时底栏纹丝不动，只能整块消失；
 * 2. **预览卡里没有它**：外观编辑页的缩尺预览只渲染课表页本体，底栏不在那棵树里；
 * 3. **条目解析散在两处**：壳里一份、别处想复用只能再抄一份。
 *
 * 现在它由**栈底条目**（`ShellRoute.Dock`）的内容自己画：底栏于是和首页同属一棵子树，
 * 跟着页面转场（覆盖视差、将来的缩放）一起动；外观编辑页的预览卡也调这同一个组件，
 * 卡片里从此有底栏。条目解析 / 材质 / 圆钮图标的口径只在这里维护一份。
 *
 * ## 调用方要给的
 *
 * * [settingsModel]：底栏排列、形态、圆钮图标、材质都从它读（预览卡传**草稿**，
 *   拖材质滑杆时卡片里的坞当场跟着变）；
 * * [selectedId]：当前主屏内容对应的条目 id（`week` / `day` / `tasks` …），
 *   决定高亮第几格；排列里没有它时整栏不亮（Dart 同口径）；
 * * [isNavigable]：「这个 id 点得开吗」——壳传真实页面映射表，预览卡传同一张表；
 * * [onSelect] / [onRoundButton]：预览卡传空实现（那一层本来就吞掉所有输入）。
 *
 * @param backdrop 玻璃采样源：调用方把**页面内容**（不含底栏自己）录进这个 backdrop，
 *   坞才采得到「它底下的画面」。null = 不采样，坞退回实体档（低版本无 runtime shader 时同此）。
 * @param replacedByRail 宽屏档被左侧 [ShellNavigationRail] 取代时由壳传 true：坞整块
 *   **不组合**（不是 alpha 藏起来，省一层图层；方案迁移顺序第 2 批的口径）。默认 false，
 *   外观编辑页的缩尺预览卡不受影响——预览的是紧凑形态，坞照画。
 */
@Composable
fun HomeGlassDock(
    settingsModel: TimetableSettingsModel,
    selectedId: String?,
    isNavigable: (String) -> Boolean,
    onSelect: (String) -> Unit,
    onRoundButton: () -> Unit,
    modifier: Modifier = Modifier,
    backdrop: Backdrop? = null,
    replacedByRail: Boolean = false,
    /**
     * 坞底下是不是**壁纸**（周 / 日 / 月三个视图为 true；任务、设置这类内嵌实色页为 false）。
     *
     * 墨色判据（[DockInkRule]）要按「药丸 + 底下那层」的合成亮度翻黑 / 白；内嵌页底下
     * 是不透明主题面，若仍拿壁纸亮度算，浅色主题 + 暗壁纸就会给浅底配白字。
     * Dart 旧版对应 `isInlinePage`（`timetable_glass_dock.dart:85-86`）。
     * 默认 true = 预览卡（外观编辑页）预览的就是课表首页，底下一定有壁纸。
     */
    overWallpaper: Boolean = true,
    /**
     * 坞压住的壁纸亮度（0~1）。由调用方（壳）把**页面同一份** `bands.dock` 传进来时优先用它；
     * 不传（默认 null）则内部按缓存版本响应式回读 `cachedWallpaperInkBands` 兜底。
     */
    wallpaperLuminance: Double? = null,
    /**
     * 学期开学日（本机本地日期）。周视图图标算「开学第几周」用；null = 无学期数据，
     * 不显示周数、保留原周视图图标。由调用方从仓储快照的 core 设置传入。
     */
    semesterStartDate: LocalDate? = null,
    /** 学期总周数（`TimetableSettings.semesterWeekCount`），用于判定今天是否仍在学期内。 */
    semesterWeekCount: Int = 0,
) {
    if (!homeDockVisible(settingsModel) || replacedByRail) return

    // 底栏「日」「周」两格的图标（用户 2026-11-04 报「日课表图标永远显示 1」）：
    //  · 日视图 → 按**今天几号**选 miuix Th{d}（原写死 Th1，日历中间永远是 1）；
    //  · 周视图 → 学期内换成「开学第几周」日历图标，学期外（没开学 / 已过 / 无数据）保留原图标。
    // 日期由 [rememberDockToday] 提供：跨零点自动翻页、回前台校正（不再停在进页那一天）。
    // 「id → 图标」的解析在 `HomeNavIcons.dockItems`：宽屏档的侧边导航栏调的是同一个函数
    // （2026-11-05 修：那两条渲染路径原本各算一次，平板那份漏了日号 / 周数）。
    val today = rememberDockToday()

    // 底栏条目：**由用户存档决定**（Dart `resolveGlassDockActionIds`）。空表回退默认三格；
    // 用户没自定义过时，开发壳的「页面索引」追加到末尾（与拆壳前的壳层口径一致）。
    // 走 `resolveDockIds` 合一入口：壳的 Pager 页列表、Rail 都由同一方法解析，三处同源。
    val dockIds = remember(settingsModel, isNavigable) {
        HomeDockNavModel.resolveDockIds(settingsModel.glassDockActions) { id ->
            isNavigable(id)
        }
    }
    val isDark = isSystemInDarkTheme()
    // 壁纸存在性以快照为准：`snapshotOf` 会做文件存在性过滤 / 旧字段解析。
    // 不能用原始路径字段——文件被删或只有旧字段时，页面按纯色底画，
    // 坞却认为「有壁纸但亮度未知」⇒ 永久白字（2026-11-07 审核 P1）。
    val chrome = rememberHomeBackdropChrome(settingsModel)
    val hasBackdrop = chrome.hasBackdrop
    val material: HomeMaterialRenderSpec? = remember(settingsModel, isDark, hasBackdrop) {
        SettingsMaterialModel.renderSpecOf(
            model = settingsModel,
            isDark = isDark,
            hasBackdrop = hasBackdrop,
        )
    }
    val roundActionId = HomeDockNavModel.roundButtonAction(settingsModel.glassDockButtonEntryId)
    // 坞压住的那条壁纸带亮度（墨色判据的唯一输入）。
    // ⚠️ 不能只靠 `chrome.bands`：它内部是 remember 一次性冷读，坞不渲染 chrome.backdrop、
    // 拿不到 onInkBands 回调，页面异步量出 bands 后这里不会更新 ⇒ 深/黑壁纸时
    // wallpaperLuminance 常为 null，退回纯白主题面判成深墨 → 黑字压黑药丸看不见（2026-11-04）。
    // 修法：读缓存版本作可观察信号，量完即回读 cachedWallpaperInkBands；调用方显式传入的
    // `wallpaperLuminance` 优先（壳后续可把页面同一份 bands 传进来）。
    val snap = chrome.snapshot
    val density = LocalDensity.current
    val appContext = LocalContext.current.applicationContext
    val inkBandsStore = remember(appContext) { HomeInkBandsStore(appContext) }
    val viewportWidthPx = with(density) { LocalConfiguration.current.screenWidthDp.dp.roundToPx() }
    val viewportHeightPx = with(density) { LocalConfiguration.current.screenHeightDp.dp.roundToPx() }
    val cacheVersion = wallpaperInkBandsCacheVersion()
    val cachedDockLuminance = remember(
        snap?.wallpaperPath, snap?.decodeWidthPx, snap?.scale, snap?.alignX, snap?.alignY,
        viewportWidthPx, viewportHeightPx, cacheVersion, overWallpaper,
    ) {
        if (!overWallpaper || snap == null || snap.wallpaperPath.isNullOrEmpty()) {
            null
        } else {
            cachedWallpaperInkBands(
                path = snap.wallpaperPath,
                decodeWidthPx = snap.decodeWidthPx,
                viewportWidthPx = viewportWidthPx,
                viewportHeightPx = viewportHeightPx,
                scale = snap.scale,
                alignX = snap.alignX,
                alignY = snap.alignY,
                store = inkBandsStore,
            )?.dock
        }
    }
    val resolvedWallpaperLuminance = wallpaperLuminance ?: cachedDockLuminance

    GlassDockNavigationBar(
        // 图标 + 文案来自共享解析（与宽屏档 Rail 同一份，见 HomeNavIcons.dockItems）。
        items = remember(dockIds, today, semesterStartDate, semesterWeekCount) {
            HomeNavIcons.dockItems(dockIds, today, semesterStartDate, semesterWeekCount)
        },
        selectedIndex = HomeDockNavModel.selectedIndex(dockIds, selectedId),
        onSelect = { index -> onSelect(dockIds[index]) },
        // 设备不支持 runtime shader 时别把 backdrop 传进去：传了也画不出模糊，
        // 反而会多录一层、白费一次采样（与壳层同一条纪律）。
        backdrop = backdrop,
        material = material,
        wallpaperLuminance = resolvedWallpaperLuminance,
        overWallpaper = overWallpaper,
        // 真正有没有壁纸可采样（路径非空）：无壁纸时坞墨色按页面底色判，不走「壁纸未知→浅墨」。
        hasWallpaper = hasBackdrop,
        modifier = modifier,
        // 只有「点开换主屏内容」的条目（视图动作 / 内嵌页）才挪选中指示器；
        // 点开是推一层页面的条目（外观编辑器、表单页）主屏没换，指示器必须留在原格，
        // 否则页面退回来底栏还亮着它（2026-11-01 用户报）。
        isTab = { index -> HomeDockNavModel.rendersAsRoot(dockIds[index]) },
        trailingContent = if (settingsModel.glassDockShowAddButton) {
            {
                GlassDockRoundButton(
                    // 用户挑的图标名优先；没挑 / 名字已撤 / 矢量表缺项时回退到圆钮
                    // 绑定动作的目录图标（缺省动作 = 加课 = 加号）。
                    icon = glassDockRoundButtonIcon(
                        chosenName = settingsModel.glassDockButtonIconName,
                        roundActionId = roundActionId,
                    ),
                    contentDescription = HomeNavIcons.labelOf(roundActionId),
                    onClick = onRoundButton,
                )
            }
        } else {
            null
        },
    )
}

/**
 * 坞**会不会真的采样背景**（= 调用方挂 `layerBackdrop` 是否值得）。
 *
 * 与 `GlassDockNavigationBar` 的 `isBlurActive` 同一判据：材质解析成实体档 / 关掉时，
 * 坞根本不跑 `drawBackdrop`，但 `Modifier.layerBackdrop` 是「先上屏、再整屏录一遍」——
 * 白挂一层就是每次重绘都多画一遍整页（外观编辑页拖材质滑杆时尤其明显，2026-11-01 审计）。
 *
 * 调用方还要自己再判 `isRuntimeShaderSupported()`：低版本机上坞一定会退化成实体档。
 */
@Composable
fun rememberHomeDockUsesBackdrop(settingsModel: TimetableSettingsModel): Boolean {
    if (!homeDockVisible(settingsModel)) return false
    val isDark = isSystemInDarkTheme()
    // 与坞本体同一把尺：快照口径（含文件存在性 / 旧字段解析）。
    // 用原始路径字段会在文件被删时白挂一层全屏录制。
    val hasBackdrop = rememberHomeBackdropChrome(settingsModel).hasBackdrop
    return remember(settingsModel, isDark, hasBackdrop) {
        val spec = SettingsMaterialModel.renderSpecOf(
            model = settingsModel,
            isDark = isDark,
            hasBackdrop = hasBackdrop,
        )
        spec.dock != SurfaceMaterialState.SOLID && spec.dock != SurfaceMaterialState.OFF
    }
}

/**
 * 玻璃坞形态下才画底栏。
 *
 * Dart `home_chrome_spec.dart:78-80`：`glassDockForm = homeNavigationForm == glassDock`，
 * 非坞档直接返回 `dockContent`，**坞层连建都不建**。调用方（壳的录制门控、预览卡）
 * 与 [HomeGlassDock] 自己都按这一条判，避免「坞不画了但还在录屏」这类半吊子状态。
 */
fun homeDockVisible(settingsModel: TimetableSettingsModel): Boolean =
    settingsModel.homeNavigationForm == HomeNavigationForm.GLASS_DOCK

/**
 * 「今天」的唯一取法：**会跨零点 / 回前台自己刷新**的本机本地日期。
 *
 * ## 为什么要单独一层（2026-11-05 修）
 *
 * 底栏「日」格画今天几号、周格画「开学第几周」，原来在组合期直接 `LocalDate.now()`。
 * 那是一次性读取：进程常驻跨过零点、或从后台回前台却没有任何状态变化触发重组时，
 * 底栏会一直停在**进入那天**的日号 / 周数。
 *
 * ## 两条刷新路径
 *
 * 1. **定时**：睡到「本机下一个零点 + 1s」再重读；key 带当天日期，翻页后自动排下一觉。
 * 2. **生命周期**：`ON_RESUME` 校正一次。设备深睡时 `delay` 会被系统压后，醒来未必立刻到点，
 *    回前台就把日期对齐 —— 这是「隔夜再用 App」最常见的路径。
 *
 * 读本机本地日期（跟系统日期 / 时区走），与学期周数口径（`HomeDockNavModel.dockWeekNumber`）
 * 同源；纯展示值，不写盘、不触发 IO。底栏与侧边导航栏都调这一个。
 */
@Composable
fun rememberDockToday(): LocalDate {
    var today by remember { mutableStateOf(LocalDate.now()) }
    // ① 跨零点：睡到下一个零点之后一点，醒来重读（key 变了 ⇒ 自动排下一次）。
    LaunchedEffect(today) {
        val now = LocalDateTime.now(ZoneId.systemDefault())
        val nextMidnight = now.toLocalDate().plusDays(1).atStartOfDay()
        val untilMidnightMs = Duration.between(now, nextMidnight).toMillis()
        delay(untilMidnightMs.coerceAtLeast(0L) + MIDNIGHT_WAKE_SLACK_MS)
        today = LocalDate.now()
    }
    // ② 回前台：定时器被系统压后时在这里对齐。
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                val current = LocalDate.now()
                if (current != today) today = current
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    return today
}

/**
 * 跨零点唤醒的富余量：宁可晚 1 秒，不要早 1 毫秒
 * （早醒会读到「还没到零点」的旧日期，白醒一次）。
 */
private const val MIDNIGHT_WAKE_SLACK_MS = 1_000L

/**
 * 首页里「贴着屏幕底」的两样东西该让到哪里：浮钮（回本周 / 回今日）与可滚动内容。
 *
 * 玻璃坞形态下按**药丸真实占用**算（底部内边距 + 药丸高 54），经典形态只让开系统
 * 手势条。算术在 [HomeFloatingMetrics]（纯函数、有单测），这里只负责把
 * `WindowInsets.navigationBars` 读出来。
 *
 * @param settingsModel 用户存档；`null` = 读不到设置 ⇒ 按经典形态算（不假设有坞）。
 */
data class HomeFloatingInsets(
    /** 浮钮底边距（从屏幕底端起，已含系统内边距）。 */
    val buttonBottom: Dp,
    /** 可滚动内容底部避让（从屏幕底端起，已含系统内边距）。 */
    val contentBottom: Dp,
    /** 注入给首页根页 `LocalGlassDockScrollRelief` 的坞避让：坞档=药丸总占用(含系统栏)，无坞=0。 */
    val scrollRelief: Dp,
)

@Composable
fun rememberHomeFloatingInsets(settingsModel: TimetableSettingsModel?): HomeFloatingInsets {
    val navBarBottomInset = WindowInsets.navigationBars
        .only(WindowInsetsSides.Bottom)
        .asPaddingValues()
        .calculateBottomPadding()
    val glassDock = settingsModel != null && homeDockVisible(settingsModel)
    return remember(glassDock, navBarBottomInset) {
        HomeFloatingInsets(
            buttonBottom = HomeFloatingMetrics
                .floatingButtonBottomDp(glassDock, navBarBottomInset.value)
                .dp,
            contentBottom = HomeFloatingMetrics
                .contentBottomDp(glassDock, navBarBottomInset.value)
                .dp,
            scrollRelief = HomeFloatingMetrics
                .dockScrollReliefDp(glassDock, navBarBottomInset.value)
                .dp,
        )
    }
}

/**
 * 玻璃坞右侧的独立圆钮（Flutter `glassDockShowAddButton` 那个「加课」按钮）。
 *
 * 用官方 [FloatingActionButton]（miuix 基础件）而不是自绘一块玻璃：本仓对「自研形状/
 * 动画」有禁令，而官方这颗按钮的按压反馈、阴影、无障碍语义都是现成的。
 * 直径与药丸同高（[GlassDockGeometry.HeightDp]），右侧留 8dp 由底栏负责。
 *
 * 原先是 `PagesShellActivity` 的私有件；底栏搬进页面层时一并搬到这里，
 * 让壳与预览卡用的是同一颗按钮（守卫 `GlassDockRoundButtonIconWiringGuardTest`
 * 盯的仍是「设置里的图标名必须传到这里」）。
 * `internal`：宽屏档的侧边导航栏（[ShellNavigationRail]）把这颗圆钮放进官方
 * `header` 槽复用同一颗，图标解析也走同一个 `glassDockRoundButtonIcon`。
 */
@Composable
internal fun GlassDockRoundButton(
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
