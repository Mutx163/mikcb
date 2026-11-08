package com.mutx163.qingyu.pages.settings

import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.util.Log
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.glass.QingyuGlassSurface
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.GlassSpec
import com.mutx163.qingyu.core.GlassSpecResolver
import com.mutx163.qingyu.core.GlassTuning
import com.mutx163.qingyu.pages.shell.HomeBackdropScope
import com.mutx163.qingyu.pages.shell.HomeBackdropSize
import com.mutx163.qingyu.pages.shell.HomeBackdropSnapshot
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.shell.HomeInkBandsStore
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.pages.shell.HomeWallpaperBackdrop
import com.mutx163.qingyu.pages.shell.cachedWallpaperInkBands
import com.mutx163.qingyu.pages.timetable.ApplyChromeStatusBarInk
import com.mutx163.qingyu.platform.ManagedWallpaperStore
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Surface
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 壁纸「拖动取景」页（发布版 Dart `lib/widgets/wallpaper_position_picker_sheet.dart:123-828`）。
 *
 * ## 它补的是哪个洞
 *
 * 外观编辑 → 壁纸面板 →「调整位置」原来只弹一句「不可用」：Dart 的取景页在 Kotlin 侧
 * 根本没移植（`WallpaperSheetBody.kt` 的 `wantsAdjust` 分支）。本页把它补上，写回
 * `homePageWallpaperAlignX` / `homePageWallpaperAlignY` / `homePageWallpaperScale`，
 * 首页 `HomeWallpaperBackdrop` 用同一套几何就能看到新取景。
 *
 * ## 版式（2026-11-08 按发布版重做）
 *
 * 这一页是**全屏取景器**，不是设置列表：壁纸铺满整屏（含状态栏与导航条），操作项
 * **悬浮在照片上**，中间一行字都不挡。
 *
 * * **顶部**：`退出` 胶囊 ｜ 居中标题（16sp / w500）｜ `完成` 胶囊，整行
 *   `SafeArea` + 左右 12dp、上下 8dp（Dart `:596-644`）；
 * * **底部**：`重置` 与 `换壁纸` 两颗胶囊**居中并排**、间距 12dp，距屏幕底 24dp + 手势条
 *   （Dart `:650-669`）；
 * * 胶囊本体：圆角 16dp、文字 14sp / w500、最小 56×36（顶部三件套）/ 120×40（底部两颗），
 *   内边距 16dp 或 24dp + 上下 4dp（Dart `_HyperosHeaderTextButton`，`:851-1010`）。
 *
 * ### 为什么不再是两张通栏 `QingyuCard`
 *
 * 上一版把顶 / 底各自包成一张通栏卡片：在照片上就是两条不透明的白条，既压掉预览，
 * 又和发布版「悬浮玻璃小件」的样子完全不同（用户 2026-11-08：「这个页面看起来很奇怪」）。
 * 这里回到发布版的做法：**没有底色条**，只有按内容宽度收窄的玻璃胶囊。
 *
 * 同域先例：[AppearanceEditorScreen] 也是沉浸式整屏、不走页面骨架；本页同理，
 * 套 `QingyuPageScaffold` 会把预览压掉一截，所见即所得就不成立（取景值虽归一，但预览
 * 与首页的裁剪窗口不再一致）。
 *
 * ### 墨色：跟着壁纸顶部亮度翻黑 / 白
 *
 * 发布版用 `homePageChromeForegroundForLuminance(_topLuminance)` 决定按钮是深墨还是浅墨，
 * 再压一层极性水洗（`HomePageChromeGlassFill.scrimColor`：深色壁纸压黑 28%、浅色压白 30%）
 * 保证文字在照片上能读。这里**不自己定阈值**，走全站唯一入口
 * `HomeBackgroundModel.chromeInkPolarity(bands.top)`（与首页顶栏同一条判据），水洗按同一
 * 极性取黑 / 白。状态栏图标同样按 `statusBarInkPolarity` 翻（`ApplyChromeStatusBarInk`）。
 *
 * 亮度带首帧**同步查缓存**（`cachedWallpaperInkBands`，与 `rememberHomeBackdropChrome`
 * 同口径）：首页 / 外观编辑页早就量过这张图，进页第一帧就是正确墨色，不会先画一帧
 * 再翻面。取景变了（拖动 / 缩放停下 200ms）补量一次 —— 墨色要跟着「屏幕上真正看到的
 * 那一块」走（Dart 在 `onScaleEnd` 重新采样，`:787`）。
 *
 * ### 玻璃
 *
 * 胶囊用全站唯一玻璃件 `QingyuGlassSurface` 采样「壁纸那一层」（`layerBackdrop` 只挂在
 * 壁纸上，不录按钮自己，否则玻璃会把上一帧的自己叠进去）。口径与设置页左上角返回键
 * 同一档（发布版这一页的按钮锁 `LiquidGlassRole.pinnedChrome`，注释原文：「必须和设置
 * 界面左上角返回键保持强制同材质」）。设备没有 `RuntimeShader` 时不录屏、不挂玻璃，
 * 胶囊退成「水洗底色 + 细描边」——发布版画不出折射时的回落也是磨砂 / 衬底，不是实体卡。
 *
 * ## 交互契约（逐项照 Dart，纯运算在 [SettingsWallpaperPositionPage]）
 *
 * * **拖动**：单指拖动与双指捏合同一个 `transformable` 手势；拖动位移按「当前倍数下的
 *   真实溢出」折算，内容与手指 1:1；对齐值夹 [-1, 1]，该轴不溢出时归 0；
 * * **缩放**：倍数夹 1..4，绕对齐点放大（绘制由 `HomeWallpaperBackdrop` 的
 *   `drawRect` 完成，与首页同一份几何）；
 * * **重置**：位置与缩放一起回 0 / 0 / 1（`:473-483`）；
 * * **退出（系统返回 / 左按钮）**：不写任何设置，直接返回（Dart `confirmed = false`）；
 * * **完成**：写路径 + 三个取景值，并把这幅图的「最近使用」条目更新为新取景，然后返回
 *   （Dart `:1069-1091`）。
 *
 * ## 「换壁纸」（2026-11-03 R14 补上）
 *
 * 底部第二颗按钮，对应 Dart `_switchWallpaper`（`:429-465`）：相册选图 → 收进受管
 * 目录（`ManagedWallpaperStore`，与外观编辑页选图**同一个目录、同一套命名**）→
 * 预览换成新图、取景回「居中 + 原大小」。**选图当下不写设置**：按「完成」才把路径 +
 * 三个取景值 + 「最近使用」一起落盘（Dart 也是确认时才写）。
 *
 * 本次交互里选过、最终没有被任何设置引用的图，在「完成」落盘后或「退出」时删掉
 * （Dart `_discardUnreferencedBackdrops`，`settings_home_backdrop_flow.dart:1097-1130`）。
 * 系统返回按「退出」处理（[BackHandler]）。
 *
 * ## 已知差异（照实写）
 *
 * 1. **墨色不是逐帧跟随**：发布版在每次手势结束时重采样；这里是「停下 200ms 后补量一次」，
 *    拖动过程中胶囊不翻面（中途翻面读起来像闪，且每帧扫一遍像素没必要）；
 * 2. **落盘失败只记日志 + 一句「保存失败」**：与外观编辑页 / Bing 图库同一处理
 *    （`AppearanceEditorHost` 是 `Log.e`，`BingGalleryHost` 多弹一句），不静默回滚。
 *
 * @param store 设置模型读写（壳里 `wiring.settingsModel`）；与外观编辑页共用同一个
 *   `timetable_settings` 键与合并写。返回上一页时编辑器会重新 `load()`，看到的就是新值。
 * @param onBack 返回（保存成功后由本页调用；取消时直接调用）。
 */
@Composable
fun WallpaperPositionPickerHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    // 进页那一刻的取景就是初值（Dart `_alignX = widget.initialAlignX`，`:287-289`）。
    // 只读一次：本页存活期间没有别人能改这份设置。
    val openedWith = remember(store) { store.load() }
    // 当前预览的壁纸：进页时是盘上那张，「换壁纸」选中新图后就地换成新路径
    // （Dart `_imagePath` 是 State 字段，`:143` / `:445-455`）。
    //
    // `rememberSaveable`：本页被系统重建（深色模式切换等）后仍指向同一张图；
    // 否则会退回进页那张，用户刚选的新图白选。
    var wallpaperPath by rememberSaveable { mutableStateOf(openedWith.homePageWallpaperPath) }
    val hasWallpaper = !wallpaperPath.isNullOrBlank()
    // 本次交互里新落盘的图（Dart `pickedPaths`）。退出 / 确认后清掉没人引用的。
    var pickedPaths by rememberSaveable(
        stateSaver = listSaver(
            save = { it },
            restore = { it },
        ),
    ) { mutableStateOf(emptyList<String>()) }
    val scope = rememberCoroutineScope()
    // 清理用的 scope **不挂在页面组合上**：确认 / 退出后本页立刻退栈，组合 scope 会被
    // 取消，删文件的协程就永远跑不到（Dart 的 `Future.delayed` 也不随页面销毁取消）。
    // 与 `AppearanceEditorHost` 的 `wallpaperCleanupScope` 同一口径。
    val cleanupScope = remember { CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate) }

    var alignX by rememberSaveable {
        mutableStateOf(SettingsWallpaperPositionPage.clampAlign(openedWith.homePageWallpaperAlignX))
    }
    var alignY by rememberSaveable {
        mutableStateOf(SettingsWallpaperPositionPage.clampAlign(openedWith.homePageWallpaperAlignY))
    }
    var scale by rememberSaveable {
        mutableStateOf(SettingsWallpaperPositionPage.clampScale(openedWith.homePageWallpaperScale))
    }

    // 预览区尺寸（物理像素）：拖动折算的分母与解码宽都从这里来。
    var viewport by remember { mutableStateOf(IntSize.Zero) }
    // 图片原始尺寸（已按 EXIF 摆正）：尺寸没到之前拖动是空操作（Dart `:708-710`）。
    var imageSize by remember(wallpaperPath) { mutableStateOf<HomeBackdropSize?>(null) }
    var imageUnavailable by remember(wallpaperPath) { mutableStateOf(false) }
    val hasImage = hasWallpaper && !imageUnavailable

    LaunchedEffect(wallpaperPath) {
        // 先取本地值：`wallpaperPath` 是委托属性（`rememberSaveable`），不能智能转换。
        val path = wallpaperPath
        if (path.isNullOrBlank()) {
            imageSize = null
            imageUnavailable = false
            return@LaunchedEffect
        }
        // 只读头部拿宽高，不解码像素（Dart `:328-374` 的同一口径）。
        val size = withContext(Dispatchers.IO) { readOrientedSize(path) }
        imageSize = size
        imageUnavailable = size == null
    }

    // 「换壁纸」：系统图片选择器（Dart `_switchWallpaper` 调的 `onPickNewImage`）。
    // 只负责「选 + 落进受管目录 + 就地预览」；写设置留给「完成」，与 Dart 一致。
    val picker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        // 用户取消 → 什么都不做（Dart `_switchWallpaper` 的 `nextPath == null` 分支，`:436`）。
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val stored = withContext(Dispatchers.IO) {
                ManagedWallpaperStore.storePickedImage(context, uri)
            }
            if (stored == null) {
                // 无读权限 / 空文件 / 写盘失败：不把不存在的路径写进设置。
                Toast.makeText(
                    context,
                    SettingsStringsExt2.saveFailed.text,
                    Toast.LENGTH_SHORT,
                ).show()
                return@launch
            }
            pickedPaths = pickedPaths + stored
            wallpaperPath = stored
            // Dart `_switchWallpaper`（`:441-450`）：换图后回到「居中 + 原大小」，
            // 让用户重新选择显示区域；不继承上一张的取景。
            alignX = WallpaperFraming.DEFAULT.alignX
            alignY = WallpaperFraming.DEFAULT.alignY
            scale = WallpaperFraming.DEFAULT.scale
        }
    }

    val transformState = rememberTransformableState { zoomChange, panChange, _ ->
        // 顺序与 Dart 一致：先算新倍数，再用**新倍数**下的溢出量折算拖动
        // （`:742-762`；分母取小的那一版会让放大后「拖一点就飞」）。
        val nextScale = SettingsWallpaperPositionPage.scaleAfterPinch(scale, zoomChange.toDouble())
        val image = imageSize
        val overflowX = if (image != null) {
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = viewport.width,
                viewportHeight = viewport.height,
                imageWidth = image.width,
                imageHeight = image.height,
                horizontal = true,
                scale = nextScale,
            )
        } else {
            0.0
        }
        val overflowY = if (image != null) {
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = viewport.width,
                viewportHeight = viewport.height,
                imageWidth = image.width,
                imageHeight = image.height,
                horizontal = false,
                scale = nextScale,
            )
        } else {
            0.0
        }
        alignX = SettingsWallpaperPositionPage.alignAfterDrag(
            previousAlign = alignX,
            dragDelta = panChange.x.toDouble(),
            overflowExtent = overflowX,
        )
        alignY = SettingsWallpaperPositionPage.alignAfterDrag(
            previousAlign = alignY,
            dragDelta = panChange.y.toDouble(),
            overflowExtent = overflowY,
        )
        scale = nextScale
    }

    val snapshot = remember(wallpaperPath, alignX, alignY, scale, viewport) {
        HomeBackdropSnapshot(
            wallpaperPath = wallpaperPath,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
            // 取景页看的是原图（Dart 的 `Image` 不套模糊，`:774-822`）。
            blurSigma = 0.0,
            decodeWidthPx = HomeBackgroundModel.decodeWidthPx(
                viewport.width.takeIf { it > 0 },
            ),
            scope = HomeBackdropScope.DEFAULT,
            pageColorArgb = Color.Black.toArgb(),
            // 取景时背景不跟周页滑动。
            followsWeekPager = false,
        )
    }

    // ── 墨色：壁纸顶部亮度 → 浅墨 / 深墨（与首页顶栏同一个入口）──
    val inkBandsStore = remember(context.applicationContext) {
        HomeInkBandsStore(context.applicationContext)
    }
    val density = LocalDensity.current
    val screenWidthPx = with(density) { LocalConfiguration.current.screenWidthDp.dp.roundToPx() }
    val screenHeightPx = with(density) { LocalConfiguration.current.screenHeightDp.dp.roundToPx() }
    // 首帧同步查缓存（见 KDoc「墨色」一节）：命中就是这张图在这套取景下的真值。
    var inkBands by remember(wallpaperPath) {
        mutableStateOf(
            cachedWallpaperInkBands(
                path = wallpaperPath,
                decodeWidthPx = HomeBackgroundModel.decodeWidthPx(screenWidthPx),
                viewportWidthPx = screenWidthPx,
                viewportHeightPx = screenHeightPx,
                scale = scale,
                alignX = alignX,
                alignY = alignY,
                store = inkBandsStore,
            ),
        )
    }
    // 取景变了之后补量：拖动 / 缩放停下 200ms 才量一次（见 KDoc「已知差异」第 1 条）。
    LaunchedEffect(wallpaperPath, alignX, alignY, scale, viewport) {
        val path = wallpaperPath
        if (path.isNullOrBlank() || viewport.width <= 0) return@LaunchedEffect
        delay(INK_RESAMPLE_DEBOUNCE_MS)
        val measured = withContext(Dispatchers.IO) {
            cachedWallpaperInkBands(
                path = path,
                decodeWidthPx = snapshot.decodeWidthPx,
                viewportWidthPx = viewport.width,
                viewportHeightPx = viewport.height,
                scale = scale,
                alignX = alignX,
                alignY = alignY,
                store = inkBandsStore,
            )
        }
        if (measured != null) inkBands = measured
    }

    // 没图 / 图丢了 = 纯黑底，固定浅墨；有图跟着壁纸顶部亮度翻。
    val lightInk = !hasImage ||
        HomeBackgroundModel.chromeInkPolarity(inkBands?.top) == HomeInkPolarity.Light
    val ink = Color(
        if (lightInk) HomeBackgroundModel.WHITE_ARGB else HomeBackgroundModel.ON_LIGHT_INK_ARGB,
    )
    // 极性水洗（发布版 `HomePageChromeGlassFill.scrimColor`）：深色壁纸压黑、浅色压白。
    // 压在玻璃上保证文字可读；没有玻璃能力时它就是胶囊底色。
    val wash = if (lightInk) {
        Color.Black.copy(alpha = WASH_ON_DARK_ALPHA)
    } else {
        Color.White.copy(alpha = WASH_ON_LIGHT_ALPHA)
    }
    // 状态栏图标：浅色壁纸配深色图标，深色壁纸配浅色图标（与本页墨色同源）。
    ApplyChromeStatusBarInk(
        lightIcons = HomeBackgroundModel.statusBarInkPolarity(inkBands?.top) == HomeInkPolarity.Dark,
    )

    /**
     * 删掉本次交互里新落盘、但当前设置**没有任何引用**的图。
     *
     * 「换壁纸」每选一张就落一份文件；连选两张只确认第二张、或选完直接退出时，
     * 其余几张就成了没人引用的垃圾。判据与真删分离：判据在
     * [SettingsWallpaperPositionPage.unreferencedPicked]（纯运算、可测），这里只摸盘。
     *
     * 必须在设置**落盘之后**调用：先确认新路径已被当前壁纸 / 最近使用引用，再删别的。
     */
    fun discardUnreferencedPicked() {
        val victims = SettingsWallpaperPositionPage.unreferencedPicked(
            pickedPaths = pickedPaths,
            settings = runCatching { store.load() }.getOrNull(),
        )
        if (victims.isEmpty()) return
        cleanupScope.launch {
            withContext(Dispatchers.IO) {
                victims.forEach { path ->
                    val deleted = runCatching { File(path).delete() }.getOrDefault(false)
                    if (!deleted) Log.w(LOG_TAG, "discarded wallpaper was not deleted: $path")
                }
            }
        }
    }

    /** 「退出」/ 系统返回：不写任何设置，清掉本次选的图，再返回（Dart `_exit`，`:485-495`）。 */
    fun exit() {
        discardUnreferencedPicked()
        onBack()
    }

    /** 「完成」：写回并返回。Dart `_confirm`（`:497-507`）+ `:1069-1091`。 */
    fun confirm() {
        val path = wallpaperPath?.takeIf { it.isNotBlank() } ?: return exit()
        // 现读一份再合并写：与 BingGalleryHost / 外观编辑页同一条落盘路径，
        // 不会把本页不拥有的键覆盖掉。
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = store.load(),
            path = path,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
        ) ?: return exit()
        val saved = runCatching { store.save(next) }
        if (saved.isFailure) {
            Log.e(LOG_TAG, "save wallpaper framing failed", saved.exceptionOrNull())
            Toast.makeText(
                context,
                SettingsStringsExt2.saveFailed.text,
                Toast.LENGTH_SHORT,
            ).show()
            return
        }
        // 落盘成功后再清：新路径此刻已被设置 / 历史引用，留下的只有真正没人用的。
        discardUnreferencedPicked()
        onBack()
    }

    // 系统返回 = 退出：与底部「退出」同一条路（先清理本次选图，再返回）。
    BackHandler { exit() }

    QingyuPageTheme {
        // 玻璃采样源：**只录壁纸那一层**（按钮画在它之外，玻璃采不到自己）。
        // 设备不支持 runtime shader 时不留采样层——挂了也画不出模糊，白多一次整屏录制。
        // 类型写成 LayerBackdrop：`Modifier.layerBackdrop` 要的是「录像带」本身，
        // 而按钮那边收的是更宽的 `Backdrop` 接口（LayerBackdrop 就是它的实现）。
        val heroBackdrop: LayerBackdrop? =
            if (isRuntimeShaderSupported()) rememberLayerBackdrop() else null
        Box(
            modifier = Modifier
                .fillMaxSize()
                // 壁纸解码出来之前的那层底。Dart 也是 `Scaffold(backgroundColor: Colors.black)`：
                // 取景器里的黑是**固定语义色**（照片衬底），不跟主题明暗走。
                .background(Color.Black),
        ) {
            if (hasImage) {
                HomeWallpaperBackdrop(
                    snapshot = snapshot,
                    modifier = Modifier
                        .fillMaxSize()
                        .then(
                            if (heroBackdrop != null) {
                                Modifier.layerBackdrop(heroBackdrop)
                            } else {
                                Modifier
                            },
                        )
                        .onSizeChanged { viewport = it }
                        .transformable(transformState),
                    // 量出来的三档亮度就是墨色判据（取景变了由上面的 effect 补量）。
                    onInkBands = { bands -> inkBands = bands },
                )
            } else {
                // 没有壁纸 / 图片文件丢了：一句实话，底部仍有「换壁纸」可走（Dart 在进页前
                // 就会拦掉这两种情况，`:1135-1166`；这里兜住「从壳的页面索引直接进来」）。
                PickerEmptyState(imageMissing = imageUnavailable)
            }

            // 顶部：退出 ｜ 标题 ｜ 完成 —— 悬浮在照片上，没有底色条（发布版 `:596-644`）。
            PickerTopChrome(
                ink = ink,
                wash = wash,
                backdrop = heroBackdrop,
                onExit = { exit() },
                onDone = { confirm() },
                modifier = Modifier.align(Alignment.TopCenter),
            )

            // 底部：重置 ｜ 换壁纸 —— 居中并排（发布版 `:650-669`）。
            //
            // 「重置」只在有图可调时出现；「换壁纸」永远可点 —— 没图 / 图丢了的时候，
            // 它正是用户唯一的出路（Dart 那种情况下进不了本页，这里兜住壳的直达入口）。
            PickerBottomChrome(
                ink = ink,
                wash = wash,
                backdrop = heroBackdrop,
                onReset = if (hasImage) {
                    {
                        alignX = WallpaperFraming.DEFAULT.alignX
                        alignY = WallpaperFraming.DEFAULT.alignY
                        scale = WallpaperFraming.DEFAULT.scale
                    }
                } else {
                    null
                },
                onSwitch = {
                    picker.launch(
                        PickVisualMediaRequest(
                            ActivityResultContracts.PickVisualMedia.ImageOnly,
                        ),
                    )
                },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

// ─────────────────────────────────────────────── 悬浮操作条（发布版版式）

/**
 * 悬浮胶囊的玻璃口径：与设置页左上角返回键同一档（薄磨砂、不做折射 / 高光）。
 *
 * 发布版这一页的四颗按钮锁 `LiquidGlassRole.pinnedChrome`，注释原文要求「和设置界面
 * 左上角返回键保持强制同材质」；用户也不希望这几颗小件跟着材质滑杆变成另一种玻璃。
 * 数值与 `QingyuPageScaffold.QingyuChromeGlassSpec` 相同——那份是 private、不跨文件
 * 共享，所以这里按同值重建。**改动时两处要一起改**（同一份观感，两个文件）。
 */
private val PickerChromeGlassSpec: GlassSpec = GlassSpecResolver.resolve(
    GlassTuning(
        blurSigmaDp = 18f,
        tintAlpha = 0f,
        vibrancy = 1.15f,
        rimStrength = 0f,
        rimWidthDp = 0f,
        refractionBandDp = 0f,
        refractionAmountDp = 0f,
        dispersion = 0f,
    ),
)

/**
 * 顶部一行：`退出` 胶囊 ｜ 居中标题 ｜ `完成` 胶囊。
 *
 * 整行 `SafeArea` + 左右 12dp、上下 8dp（Dart `:596-600`）。标题用 `weight(1f)` 吃掉
 * 两颗胶囊之间的全部余量并居中 —— Dart 专门为这件事写过注释：早年的
 * `Spacer/Flexible/Spacer` 三分法每份只有 70-80px，「调整壁纸显示位置」会被截成
 * 「调整壁纸…」。
 */
@Composable
private fun PickerTopChrome(
    ink: Color,
    wash: Color,
    backdrop: Backdrop?,
    onExit: () -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PickerChromeButton(
            label = SettingsWallpaperPositionPage.EXIT.text,
            onClick = onExit,
            ink = ink,
            wash = wash,
            backdrop = backdrop,
            compact = true,
        )
        Text(
            text = SettingsWallpaperPositionPage.TITLE.text,
            modifier = Modifier.weight(1f),
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = ink,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        PickerChromeButton(
            label = SettingsWallpaperPositionPage.DONE.text,
            onClick = onDone,
            ink = ink,
            wash = wash,
            backdrop = backdrop,
            compact = true,
        )
    }
}

/**
 * 底部一排：`重置` ＋ 12dp ＋ `换壁纸`，整排居中。
 *
 * 距屏幕底 = 24dp + 手势条（Dart `:652` 的 `bottom: 24 + media.padding.bottom`）；
 * 实现上先吃 `navigationBarsPadding()` 再补 24dp，合起来就是同一个距离。
 *
 * @param onReset `null` = 没有可调的图（无壁纸 / 文件丢了），这一颗不出现。
 */
@Composable
private fun PickerBottomChrome(
    ink: Color,
    wash: Color,
    backdrop: Backdrop?,
    onReset: (() -> Unit)?,
    onSwitch: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(bottom = PICKER_BOTTOM_GAP),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onReset != null) {
            PickerChromeButton(
                label = SettingsWallpaperPositionPage.RESET.text,
                onClick = onReset,
                ink = ink,
                wash = wash,
                backdrop = backdrop,
            )
            Spacer(modifier = Modifier.width(PICKER_BOTTOM_GAP_HALF))
        }
        PickerChromeButton(
            label = SettingsWallpaperPositionPage.SWITCH.text,
            onClick = onSwitch,
            ink = ink,
            wash = wash,
            backdrop = backdrop,
        )
    }
}

/**
 * 悬浮胶囊按钮：玻璃底 + 极性水洗 + 细描边，点击反馈来自官方 `Surface`。
 *
 * 尺寸照发布版 `_HyperosHeaderTextButton`（`:851-1010`）：
 * * 紧凑（顶部三件套）：最小 56×36、左右 16dp；
 * * 常规（底部两颗）：最小 120×40、左右 24dp；
 * * 两者共用上下 4dp 与 16dp 圆角（`HyperosMiuixButton.cornerRadius`）、14sp / w500 文字。
 *
 * 有采样源时用 `QingyuGlassSurface` 糊底下的照片；没有（设备不支持 runtime shader）时
 * 退成水洗底色。发布版在画不出折射时的回落也是「磨砂 / 衬底 + 描边」，不是实体卡片。
 */
@Composable
private fun PickerChromeButton(
    label: String,
    onClick: () -> Unit,
    ink: Color,
    wash: Color,
    backdrop: Backdrop?,
    compact: Boolean = false,
) {
    val shape = RoundedCornerShape(PICKER_PILL_CORNER)
    val content: @Composable () -> Unit = {
        Surface(
            onClick = onClick,
            shape = shape,
            // 底色由玻璃 / 水洗负责，官方件只出形状与按压反馈。
            color = Color.Transparent,
            shadowElevation = 0.dp,
        ) {
            Box(
                modifier = Modifier
                    .defaultMinSize(
                        minWidth = if (compact) {
                            PICKER_PILL_MIN_WIDTH_COMPACT
                        } else {
                            PICKER_PILL_MIN_WIDTH
                        },
                        minHeight = if (compact) {
                            PICKER_PILL_MIN_HEIGHT_COMPACT
                        } else {
                            PICKER_PILL_MIN_HEIGHT
                        },
                    )
                    .padding(
                        horizontal = if (compact) {
                            PICKER_PILL_PAD_H_COMPACT
                        } else {
                            PICKER_PILL_PAD_H
                        },
                        vertical = PICKER_PILL_PAD_V,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    // 14sp 正好是主题 body2，w500 按设计增量加（不写死绝对字重，
                    // 用户改字重 / 系统粗体才跟得上）。
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = ink,
                    maxLines = 1,
                )
            }
        }
    }
    Box(
        modifier = Modifier.border(
            width = PICKER_PILL_BORDER_WIDTH,
            color = ink.copy(alpha = PICKER_PILL_BORDER_ALPHA),
            shape = shape,
        ),
    ) {
        if (backdrop != null) {
            QingyuGlassSurface(
                backdrop = backdrop,
                spec = PickerChromeGlassSpec,
                shape = shape,
                tintBrush = SolidColor(wash),
                content = content,
            )
        } else {
            Box(modifier = Modifier.background(wash, shape)) { content() }
        }
    }
}

/**
 * 没图 / 图丢了时的居中说明。底色是整页的固定黑，所以字固定用白，
 * 不跟主题明暗走（发布版这里是 `Center(Icon(broken_image, color: white38))`，
 * 这一版保留文字 -- 用户需要知道「是没有图」还是「文件没了」）。
 */
@Composable
private fun PickerEmptyState(imageMissing: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = if (imageMissing) {
                SettingsStringsExt1.homePageWallpaperFileMissingTitle.text
            } else {
                SettingsStringsExt1.homePageImageNotSelected.text
            },
            style = MiuixTheme.textStyles.body1,
            color = Color.White.copy(alpha = 0.86f),
            textAlign = TextAlign.Center,
        )
        if (imageMissing) {
            Text(
                text = SettingsStringsExt1.homePageWallpaperFileMissingSubtitle.text,
                modifier = Modifier.padding(top = 8.dp),
                style = MiuixTheme.textStyles.body2,
                color = Color.White.copy(alpha = 0.6f),
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ─────────────────────────────────────────────── 发布版几何 / 水洗常量

/** 胶囊圆角：`HyperosMiuixButton.cornerRadius`（`hyperos_miuix_spec.dart:305`）。 */
private val PICKER_PILL_CORNER = 16.dp

/** 顶部三件套的最小尺寸（Dart `isCompact: true` → 56×36）。 */
private val PICKER_PILL_MIN_WIDTH_COMPACT = 56.dp
private val PICKER_PILL_MIN_HEIGHT_COMPACT = 36.dp

/** 底部两颗的最小尺寸（Dart `HyperosMiuixButton.minWidth/minHeight` → 120×40）。 */
private val PICKER_PILL_MIN_WIDTH = 120.dp
private val PICKER_PILL_MIN_HEIGHT = 40.dp

/** 胶囊内边距：紧凑左右 16dp、常规左右 24dp，上下都是 4dp（Dart 同上）。 */
private val PICKER_PILL_PAD_H_COMPACT = 16.dp
private val PICKER_PILL_PAD_H = 24.dp
private val PICKER_PILL_PAD_V = 4.dp

/** 胶囊细描边：0.75dp、字色 18% —— 玻璃档没有折射高光时靠它立住轮廓。 */
private val PICKER_PILL_BORDER_WIDTH = 0.75.dp
private const val PICKER_PILL_BORDER_ALPHA = 0.18f

/** 极性水洗（发布版 `HomePageChromeGlassFill.scrimColor`：深色壁纸 28% 黑、浅色 30% 白）。 */
private const val WASH_ON_DARK_ALPHA = 0.28f
private const val WASH_ON_LIGHT_ALPHA = 0.30f

/** 底部操作条离屏幕底的空档（Dart `:652` 的 `24`）；两颗按钮之间是 12dp（`:664`）。 */
private val PICKER_BOTTOM_GAP = 24.dp
private val PICKER_BOTTOM_GAP_HALF = 12.dp

/** 取景停下多久才补量墨色：短到用户松手就能看到翻面，长到拖动过程中不会反复扫像素。 */
private const val INK_RESAMPLE_DEBOUNCE_MS = 200L

private const val LOG_TAG = "wallpaper-position-picker"

/**
 * 读图片的原始尺寸并按 EXIF 摆正（只读头部，不解码像素）。
 *
 * 与 Dart `_resolveImageSize`（`:332-374`）同一件事；方向规则复用
 * `HomeBackgroundModel.exifRotationDegrees` / `orientedSize`，保证与首页画出来的
 * 裁剪窗口同源（90°/270° 的照片宽高对调后，拖动溢出量才对得上）。
 *
 * 文件缺失 / 损坏返回 null：本页据此显示「图片文件已丢失」，而不是让异常冒到全局。
 */
private fun readOrientedSize(path: String): HomeBackdropSize? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    val orientation = runCatching {
        ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
    }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
    return HomeBackgroundModel.orientedSize(
        width = bounds.outWidth,
        height = bounds.outHeight,
        rotationDegrees = HomeBackgroundModel.exifRotationDegrees(orientation),
    )
}
