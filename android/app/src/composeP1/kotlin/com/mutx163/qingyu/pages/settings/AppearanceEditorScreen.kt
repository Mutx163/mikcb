package com.mutx163.qingyu.pages.settings

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.core.view.WindowCompat
import top.yukonga.miuix.kmp.squircle.addSquircleRect
import top.yukonga.miuix.kmp.squircle.squircleClip
import top.yukonga.miuix.kmp.squircle.squircleSurface
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * 外观编辑页的**沉浸式页面壳**：整屏暗底 + 中间一张「真课表页等比缩尺卡」+
 * 顶部一行 chrome + 底部两颗圆钮。**没有滚动、没有设置列表**。
 *
 * Dart 原件：`lib/screens/settings/settings_appearance_editor.dart`（2649 行）。
 * 本文件负责「几何 + 卡片容器 + 装配」；卡片的缩尺与转场重放在
 * `AppearanceEditorPreviewStage.kt`，上下 chrome 在 [AppearanceEditorChrome]，
 * 草稿 / 落盘 / 两个弹层在 `app/AppearanceEditorHost.kt`。
 *
 * ## 与 Dart「方案 A（烤图）」的等价物：活树缩放，而不是截图
 *
 * Dart 把真首页按整屏 1:1 渲染在页面底层，再由 `PreviewBakeBoundary` 录成一帧位图、
 * 卡片显示那张图（`:56-73` 的类注释写了为什么不是 `FittedBox` 活树直显：玻璃采样链
 * 在非原生尺度下坐标折算会漂）。Kotlin 侧没有那套玻璃烤图机制，这里用**同一棵树、
 * 原生尺度排版、只在外层做 `graphicsLayer` 缩放**（实现集中在
 * `AppearanceEditorPreviewStage`）：
 *
 * * 卡片里的课表页拿到的约束是**固定的整屏尺寸**（预览舞台里的自定义布局给
 *   `Constraints.fixed(整屏)`，不是 `requiredSize`）—— 它按**整屏 1:1** 排版，
 *   与真实课表页逐参一致，不另排一套「小屏布局」；
 * * 缩放在绘制层完成（`graphicsLayer(scaleX, scaleY, origin = (0,0))`），不改变
 *   子树里任何一次 layout/measure，于是「原样缩小」这件事成立；
 * * 外层 `clip` 到屏幕圆角 × 缩放比的圆角矩形，多余部分被裁掉。
 *
 * ⚠️ 为什么不用 `requiredSize`：页面比卡片大，`requiredSize` 在内容超出父约束时会
 * 「上报收缩后的尺寸 + 把内容居中」（`Placeable.apparentToRealOffset`）。居中量正好
 * 等于卡片在屏幕上的偏移 ⇒ 预览里只剩整页右下角一块（2026-11-01 真机事故，详见
 * `AppearanceEditorPreviewStage.fullScreenPageScaled` 的注释）。整页必须钉在卡片
 * 左上角再缩放。
 *
 * 这就是 Dart 类注释里「直接用首页那份代码、观感一致」在 Compose 里的对应做法；
 * 也不是自研控件：`graphicsLayer` / `clip` 都是官方 Compose 绘制原语，卡片本身没有
 * 任何自定义亚像素绘制。（将来若接回 miuix 的玻璃采样，需要重新评估这一层。）
 *
 * ## 卡片不是第二个可操作首页
 *
 * [consumeAllPointerEvents] 在 **Initial pass** 把每个 pointer change 都消费掉：
 * 点击、长按、拖动、滚动全部到不了子树。比「外层 `clickable` 吞点击」更彻底——
 * 拖动和滚动不会被漏掉。语义上等于 Dart 的 `IgnorePointer`（`:1776`）。
 *
 * ## 日 / 周分段只动预览
 *
 * 分段状态是**本页自己的** `remember`，初值取 [initialDayView]（= 持久化的
 * `timetableHomeViewMode`，Dart `:203-204` 的 `_dayPreview`）；切换只改这个局部值，
 * **不写回 `timetableHomeViewMode`**，也不写任何浏览位置 —— 等价于 Dart 的
 * `TimetableHomePreviewScope`「预览模式下不写回访状态」（`:195` 那条注释）。
 *
 * ## 加载罩
 *
 * [previewReady] 为 false 时盖整页（转圈 + 通用「加载中」），淡出后从树上摘掉。
 * Kotlin 这份预览是活树、首帧就有内容，所以宿主通常传 `true`（罩子不进树）；参数
 * 保留是为了将来预览改成异步图源时能直接复用 Dart 那套三态门。
 *
 * ## 入场 / 退场（本页自己的缩放，与壳的页面推入转场是两条）
 *
 * 进页后 380ms 内：整屏内容（真首页，含玻璃坞）按统一缓动缩进卡片落点；顶栏从 1.5 倍
 * 收拢（绕整屏中心，观感是从上方压进来）；底部两颗圆钮从「透明 + 下移 80dp + 模糊 8dp」
 * 归位。点「取消 / 完成」时先播 500ms 的反向动画，再回调宿主。
 *
 * **系统返回与按钮同一条路**（2026-11-02 修）：两者都从 [requestExit] 走，所以系统返回
 * 也播整段退场缩放。区别只在「该不该接管」——面板开着时系统返回留给官方弹层关面板
 * （[requestBackExit] 由宿主传）。
 *
 * 数值、曲线与分层插值都住在纯模型 [AppearanceEditorEntranceSpec] /
 * [appearanceEditorEntranceFrame]（可走 JVM 单测逐数断言），这里只把结果交给官方
 * `graphicsLayer`：容器布局不变、子树不重新 measure，进度在绘制 lambda 里读，
 * 预览树不会逐帧重组。
 *
 * ### 与壳的配合（2026-11-01 起）
 * * 从首页打开这一页时，壳走 [com.mutx163.qingyu.pages.ShellRoute.ZoomPage]：
 *   **官方 `NavTransitions.None`（瞬时切换、零位移）**，位移与缩放全部来自上面这段入场
 *   —— 于是读起来就是「首页缩进卡片」，而不是「新页从右边滑进来」（Dart 的
 *   `HomeMenuEntry.zoomTransition` 同口径，`home_menu_catalog.dart:456-490`）。
 * * 从设置页等其它入口推入时仍是普通 `ShellRoute.Page`（官方侧滑），此时本页的缩放入场
 *   会与侧滑同时进行 —— 与 Dart「只有从首页那颗入口进来才缩放」一致。
 *
 * ### 已知差异
 * * 卡片里那份首页是**同组件的新实例**（真首页此时被本页盖住），所以它总是「当前周 +
 *   滚动在顶部」；用户先把首页滚下去再进本页时，缩进去的那一屏与刚才那屏对不上
 *   （Dart 会把首页的滚动位置喂进预览源）。
 * * 底部工具的「模糊对焦」用 `Modifier.blur`，Android 12 以下不生效（退化为无模糊）。

 *
 * @param initialDayView 预览初始停在日课表（true）还是周课表（false）。
 * @param onCancel 「取消」：宿主回滚到进页快照后返回（Dart `:735-740`，不是什么都不做）。
 * @param onDone 「完成」：保留改动并返回（Dart `:672-675`）。
 * @param onAdjustWallpaper 底部「调整壁纸」圆钮：宿主开壁纸面板。
 * @param onMaterial 底部「材质」圆钮：宿主开材质面板。
 * @param requestBackExit 本页是否接管**系统返回**（`true` 时走 [requestExit] 播退场缩放
 *   再回调 [onCancel]，与点「取消」逐字同路）。宿主在**两个面板都关着**时传 true；
 *   面板开着时传 false —— 那一下应该先交给官方 `OverlayBottomSheet` 关面板，
 *   本页不抢（见 [AppearanceEditorHost] 的 `BackHandler`）。
 * @param previewReady 首帧预览是否已就绪；false 时显示加载罩。
 * @param preview 卡片内容槽：宿主在这里放**真课表页**（周 / 日由参数选）。
 *   **不要**在这里自己做缩放或裁剪，那两件事由页面壳与预览舞台负责。
 * @param enableTransitionPreview 预览区是否重放一次页面转场（见
 *   `AppearanceEditorPreviewStage`）。默认取编译期开关
 *   [APPEARANCE_EDITOR_TRANSITION_PREVIEW_ENABLED]；关掉就是纯静态缩尺卡。
 */
@Composable
fun AppearanceEditorScreen(
    initialDayView: Boolean,
    onCancel: () -> Unit,
    onDone: () -> Unit,
    onAdjustWallpaper: () -> Unit,
    onMaterial: () -> Unit,
    modifier: Modifier = Modifier,
    requestBackExit: Boolean = false,
    previewReady: Boolean = true,
    enableTransitionPreview: Boolean = APPEARANCE_EDITOR_TRANSITION_PREVIEW_ENABLED,
    preview: @Composable (dayView: Boolean, glassSurfacesEnabled: Boolean) -> Unit,
) {
    // 状态栏图标：Dart 用 `AnnotatedRegion<SystemUiOverlayStyle>(value: light)`（`:1598-1600`），
    // 也就是「暗底 → 浅色图标」。Compose 侧等价物是窗口的 insets controller；离开本页
    // 时恢复（壳只在自己的主题变化时重设，不会替我们恢复）。
    ApplyLightSystemBarIcons()

    val density = LocalDensity.current
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp
    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    // Dart 取 `media.padding.top / bottom`（`:1587-1588`）：状态栏与导航栏/手势条。
    // `systemBars` 与它的口径一致（Dart 侧 MediaQuery.padding 在 edge-to-edge 下就是这两条）。
    //
    // ⚠️ `WindowInsets.systemBars` 是 **@Composable 属性**，必须先取到实例再进
    // `with(density) { }`（那个 lambda 不是 @Composable，直接写会编译不过）。
    val systemBars = WindowInsets.systemBars
    val topInset = with(density) { systemBars.getTop(this).toDp() }
    val bottomInset = with(density) { systemBars.getBottom(this).toDp() }

    var dayView by remember { mutableStateOf(initialDayView) }

    // ── 入场 / 退场：本页自己的缩放与分层出场（与壳的页面推入转场无关）──────
    //
    // 时间线（数值在 `AppearanceEditorEntranceSpec`，逐条有单测）：
    // * 整屏内容按统一缓动缩进卡片落点，退场反向长回整屏；
    // * 顶栏同时从 1.5 倍缩回 1 倍（绕整屏中心，观感是从屏幕上方压进来）；
    // * 底部两颗圆钮从「透明 + 下移 80dp + 模糊 8dp」归位。
    //
    // 进度用 `Animatable` 而不是 `animateFloatAsState`：退场要在回调宿主之前先播完，
    // 且入场没播完就点取消时要能从当前值反向续播（`Animatable.animateTo` 自带互斥）。
    val entrance = remember { Animatable(0f) }
    // 预览全程**恒开玻璃、不做切换**（用户拍板方案②）：不再有"过渡期关、落定开"的开关可露；
    // 逐帧缩放的玻璃接缝靠"整像素对齐 + 卡内同色内边 + 缩放层离屏合成(Offscreen)"压住。
    // 连点退出的守门：动画期间第二下直接忽略，回调只发一次。
    var exiting by remember { mutableStateOf(false) }
    val exitScope = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        entrance.animateTo(
            targetValue = 1f,
            animationSpec = tween(
                durationMillis = AppearanceEditorEntranceSpec.ENTER_DURATION_MS,
                easing = LinearEasing,
            ),
        )
    }

    /**
     * 先播完退场再回调宿主。
     *
     * 缓动由纯模型 [AppearanceEditorEntranceSpec.eased] 负责，这里用线性 `tween` 只当
     * 计时器——曲线只有一份，单测才能逐点断言。
     */
    fun requestExit(finish: () -> Unit) {
        if (exiting) return
        exiting = true
        exitScope.launch {
            // 入场还没播完就退出时（进页 380ms 内按返回），先吃掉剩下的入场再反向：
            // `animateTo(0f)` 会从**当前进度**直接反向，那一段的位移显得比正常退场短
            // （读起来就是「刚进来还没落定，退出闪得快一点」）。这一步只等到位、不额外
            // 延时——正好落定时是空操作，所以正常退场不受影响。
            if (entrance.value < 1f) {
                entrance.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(
                        durationMillis = AppearanceEditorEntranceSpec.ENTER_DURATION_MS,
                        easing = LinearEasing,
                    ),
                )
            }
            entrance.animateTo(
                targetValue = 0f,
                animationSpec = tween(
                    durationMillis = AppearanceEditorEntranceSpec.EXIT_DURATION_MS,
                    easing = LinearEasing,
                ),
            )
            finish()
        }
    }

    // 系统返回 == 点「取消」：**走同一条 [requestExit] 播退场缩放再回调宿主**。
    //
    // 以前这里分成两条路（2026-11-02 用户实报「系统返回是闪现关闭、点完成是正常缩回」）：
    // 宿主那颗 `BackHandler` 直接调 `cancel()`（立刻退栈），本页的退场进度从没被人推过
    // —— 于是系统返回是**硬切**，只有「取消 / 完成」才播缩放。
    //
    // 现在吞掉那一下、改走请求退场这条路（与按钮逐字同一条）；[enabled] 只在
    // [requestBackExit] 为 true 时成立 —— 面板开着时宿主传 false，那一下必须留给官方
    // `OverlayBottomSheet` 自己关面板（Dart `_popSelf` 也是先摘弹层再摘自己）。
    // 「取消」= 回滚到进页快照（Dart `:735-740`），所以退场回调 [onCancel]。
    BackHandler(enabled = requestBackExit) { requestExit(onCancel) }

    // 退场动画期间吞掉系统返回（本页的再吞一层，宿主的 `enabled` 已随 [requestBackExit]
    // 关掉；两层都留着是为了让「动画期间第二下无效」不依赖宿主那一侧的判据）。
    // 动画结束后由 finish() 退栈。
    BackHandler(enabled = exiting) { /* 等退场播完 */ }

    // 加载罩三态里的「还在树上」：淡出跑完才移除（见 [AppearanceEditorLoadingCover]）。
    var coverMounted by remember { mutableStateOf(!previewReady) }
    LaunchedEffect(previewReady) {
        if (!previewReady) {
            // 兜底：图源出问题时不能让用户对着永远转的圈干等（Dart `_previewCoverMaxWait`，`:301`）。
            delay(APPEARANCE_EDITOR_COVER_MAX_WAIT_MS)
            coverMounted = false
        } else {
            // 淡出这段还留在树上，动画跑完再摘（Dart `onFadedOut`，`:1860-1864`）。
            delay(APPEARANCE_EDITOR_COVER_FADE_MS.toLong())
            coverMounted = false
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AppearanceEditorScrim),
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val geometry = appearanceEditorCardGeometry(
                areaWidth = maxWidth,
                areaHeight = maxHeight,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                topInset = topInset,
                bottomInset = bottomInset,
            )
            val landingBox = geometry.toCardBox()
            // ── 卡片浮影（独立兄弟层，在离屏缩放层之外）────────────────────
            // 阴影只在落定帧全显；画在**兄弟节点**（非 offscreen、不缩放）上 → 模糊边不随逐帧
            // 缩放抖动，也不会被卡片的离屏缓冲裁掉。
            Box(
                modifier = Modifier
                    .absoluteOffset(x = geometry.cardLeft, y = geometry.cardTop)
                    .size(width = geometry.cardWidth, height = geometry.cardHeight)
                    .zIndex(0.9f)
                    .drawBehind {
                        if (entrance.value >= 0.999f) {
                            val spreadPx = 2.dp.toPx()
                            val radiusPx = geometry.radius.toPx() + spreadPx
                            val blurPx = APPEARANCE_EDITOR_CARD_SHADOW_BLUR.toPx()
                            val alpha255 = (AppearanceEditorTransitionSpec.CARD_SHADOW_ALPHA * 255f)
                                .roundToInt().coerceIn(0, 255)
                            val paint = Paint().apply {
                                isAntiAlias = true
                                color = android.graphics.Color.argb(alpha255, 0, 0, 0)
                                maskFilter = BlurMaskFilter(blurPx, BlurMaskFilter.Blur.NORMAL)
                            }
                            // 阴影与卡片同一 squircle 轮廓：纯圆弧的 drawRoundRect 在较大的
                            // 圆角上会和 squircle 卡边不贴（角上露出错位）。这里按 Dart 柔影的
                            // 外扩 2dp / 半径同量放大 / 模糊 32dp 不变，只把轮廓换成连续圆角路径。
                            val shadowPath = Path().apply {
                                addSquircleRect(
                                    width = size.width + spreadPx * 2f,
                                    height = size.height + spreadPx * 2f,
                                    cornerRadius = radiusPx,
                                    extension = APPEARANCE_EDITOR_SQUIRCLE_EXTENSION,
                                )
                            }
                            drawIntoCanvas { canvas ->
                                canvas.nativeCanvas.save()
                                canvas.nativeCanvas.translate(-spreadPx, -spreadPx)
                                canvas.nativeCanvas.drawPath(shadowPath.asAndroidPath(), paint)
                                canvas.nativeCanvas.restore()
                            }
                        }
                    },
            )

            // ── 中间那张卡：整屏尺寸的真课表页，等比缩进落点卡（**保住缩放**）──────
            // 内容按落点尺寸布局、内层单层静态 scale 缩好；入场/退场靠外层 `graphicsLayer` 的
            // 整像素对齐 scale/translation 从整屏缩进/缩出。玻璃**全程恒开、不切换**（方案②）：
            // 无"实体↔玻璃"开关可露；逐帧放大的玻璃接缝靠 `compositingStrategy=Offscreen`——
            // 把本层先按节点分辨率渲进离屏缓冲、再当纹理按 scale 缩放合成（栅格化与缩放解耦）。
            Box(
                modifier = Modifier
                    .absoluteOffset(x = geometry.cardLeft, y = geometry.cardTop)
                    .size(width = geometry.cardWidth, height = geometry.cardHeight)
                    .zIndex(1f)
                    .graphicsLayer {
                        val frame = appearanceEditorEntranceFrame(
                            progress = entrance.value,
                            screenWidthDp = screenWidth.value,
                            screenHeightDp = screenHeight.value,
                            landing = landingBox,
                        )
                        // 按**整像素**对齐绘制矩形（消「非整数倍缩放」下裁边 / 内容的亚像素 AA 抖动）：
                        // 把目标矩形四边取整到设备像素，再反推 scale / translation。
                        val nodeLeftPx = landingBox.cardLeftDp.dp.toPx()
                        val nodeTopPx = landingBox.cardTopDp.dp.toPx()
                        val landingWPx = landingBox.cardWidthDp.dp.toPx()
                        val drawnWpx = frame.cardWidthDp.dp.toPx().roundToInt().toFloat()
                        val alignedScale = if (landingWPx > 0.5f) drawnWpx / landingWPx else 1f
                        val drawnLeftPx = frame.cardLeftDp.dp.toPx().roundToInt().toFloat()
                        val drawnTopPx = frame.cardTopDp.dp.toPx().roundToInt().toFloat()
                        scaleX = alignedScale
                        scaleY = alignedScale
                        // 绕左上角缩放，位移补齐到整像素。
                        transformOrigin = TransformOrigin(0f, 0f)
                        translationX = drawnLeftPx - nodeLeftPx
                        translationY = drawnTopPx - nodeTopPx
                        // 关键（方案②）：本层离屏合成——玻璃按固定（节点）分辨率栅格化后整体按
                        // scale 缩放，帧间只缩放纹理、玻璃/接缝不逐帧重采样。
                        compositingStrategy = CompositingStrategy.Offscreen
                    }
                    // 卡片外形改用 miuix-squircle（连续曲率圆角），替代
                    // `clip(RoundedCornerShape) + background`：填充与裁剪同一条轮廓、一体完成。
                    // cornerRadius 用静态布局值（不随 entrance 动画变），shader 输出可缓存。
                    // 预览图出来之前那块底：与整页暗底同色，避免先白一下（Dart 卡片
                    // 在没图时是 `SizedBox.expand()`，透出来的是暗底，`:1815-1817`）。
                    .squircleSurface(
                        color = AppearanceEditorScrim,
                        cornerRadius = geometry.radius,
                        extension = APPEARANCE_EDITOR_SQUIRCLE_EXTENSION,
                    ),
            ) {
                // 缩尺首页 + 可选的真实转场重放（见 AppearanceEditorPreviewStage）。
                // 卡内留 1.5dp `AppearanceEditorScrim` 内边：让最外层随缩放抖动的粗边是「scrim vs 页面 scrim」
                // 同色不可见，把壁纸的高对比边收进去，减轻「边缘有线在闪」。
                // 内层也按 squircle 裁到 `圆角 - 1.5dp`：否则 1.5dp 是矩形内缩，
                // 四角会露出「方形内角 vs 圆弧外角」不重合的深色楔形/月牙。
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(1.5.dp)
                        .squircleClip(
                            cornerRadius = (geometry.radius - 1.5.dp).coerceAtLeast(0.dp),
                            extension = APPEARANCE_EDITOR_SQUIRCLE_EXTENSION,
                        ),
                ) {
                    AppearanceEditorPreviewStage(
                        dayView = dayView,
                        scale = geometry.scale,
                        screenWidth = screenWidth,
                        screenHeight = screenHeight,
                        topInset = topInset,
                        bottomInset = bottomInset,
                        replayTransition = enableTransitionPreview && !coverMounted,
                        modifier = Modifier.fillMaxSize(),
                        preview = preview,
                        // 方案②：玻璃全程恒开、不切换（无实体↔玻璃开关可露）。
                        glassSurfacesEnabled = true,
                    )
                }
            }

            // ── 上下 chrome：位置固定，弹层打开期间不动 ─────────────────
            // Dart 口径（2026-09-19）：弹窗打开时上下 chrome **保持常显、位置不变**
            // （`:780-782`），所以它们跟卡片一样是这一层的常驻子节点，不随弹层隐藏。
            //
            // 入场分层：顶栏 1.5 → 1 倍（绕**整屏中心**缩放，所以同时从屏幕上方压下来），
            // 底部两颗圆钮淡入 + 上移 80dp + 从 8dp 模糊对焦。进度同样在绘制 lambda 里读。
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        val scale = AppearanceEditorEntranceSpec.topChromeScale(entrance.value)
                        scaleX = scale
                        scaleY = scale
                        transformOrigin = TransformOrigin(0.5f, 0.5f)
                    },
            ) {
                AppearanceEditorTopChrome(
                    dayView = dayView,
                    onDayViewChange = { dayView = it },
                    // 退场先播完缩放再回调宿主；连点只认第一下。
                    onCancel = { requestExit(onCancel) },
                    onDone = { requestExit(onDone) },
                    topInset = topInset,
                    modifier = Modifier.align(Alignment.TopCenter),
                )
            }
            BottomChromeEntranceLayer(progress = { entrance.value }) {
                AppearanceEditorBottomChrome(
                    onAdjustWallpaper = onAdjustWallpaper,
                    onMaterial = onMaterial,
                    bottomInset = bottomInset,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }

            // ── 加载罩：Stack 的最后一个子节点 = 盖住卡片与上下 chrome ────
            if (coverMounted) {
                AppearanceEditorLoadingCover(
                    visible = !previewReady,
                    label = SettingsStringsExt1.commonLoadingLabel.zh,
                    modifier = Modifier
                        .fillMaxSize()
                        // 卡片恒有 `zIndex(1f)`，罩子必须更高才能真的盖住它。
                        .zIndex(2f)
                        // 完全盖住期间连点击一起挡（Dart 的 `ColoredBox` 命中测试是 opaque 的）。
                        .consumeAllPointerEvents(),
                )
            }
        }
    }
}

/** 加载罩兜底时长：Dart `_previewCoverMaxWait = Duration(seconds: 6)`（`:301`）。 */
internal const val APPEARANCE_EDITOR_COVER_MAX_WAIT_MS = 6_000L

/**
 * 把每个 pointer change 在 **Initial pass** 消费掉。
 *
 * 只在 Initial 阶段消费才挡得住子树：`clickable` / `LazyColumn` 在 Main 阶段读到
 * `isConsumed = true` 就不再响应。`awaitPointerEvent(PointerEventPass.Final)` 那种写法
 * 只能事后观察、挡不住。
 */
internal fun Modifier.consumeAllPointerEvents(): Modifier = pointerInput(Unit) {
    awaitPointerEventScope {
        while (true) {
            awaitPointerEvent(PointerEventPass.Initial).changes.forEach { change -> change.consume() }
        }
    }
}

/**
 * 在**本页停留期间**把状态栏/导航栏图标切成浅色（暗底上的可读性），离开时还原。
 *
 * 为什么是命令式：Compose 没有 `AnnotatedRegion<SystemUiOverlayStyle>` 的等价物，
 * 系统栏外观唯一入口是窗口的 insets controller。壳只在自己的明暗主题变化时设置一次
 * （`PagesShellActivity.applyShellSystemBars`），不区分当前是哪一页 —— 所以这一页
 * 必须自己临时覆盖、并在 `onDispose` 还原，否则返回设置页后状态栏会一直停在浅色。
 */
@Composable
private fun ApplyLightSystemBarIcons() {
    val view = LocalView.current
    val context = LocalContext.current
    DisposableEffect(view) {
        val window = context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val previousStatus = controller?.isAppearanceLightStatusBars
        val previousNavigation = controller?.isAppearanceLightNavigationBars
        controller?.isAppearanceLightStatusBars = false
        controller?.isAppearanceLightNavigationBars = false
        onDispose {
            if (controller != null) {
                previousStatus?.let { controller.isAppearanceLightStatusBars = it }
                previousNavigation?.let { controller.isAppearanceLightNavigationBars = it }
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
private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}

// ─────────────────────────────────────────────── 入场 / 退场（数值本体在纯模型里）
//
// `AppearanceEditorEntranceSpec` / `appearanceEditorEntranceFrame` 住在 main 源集，
// 可走 L0 JVM 单测逐数断言；这里只做 dp ↔ Float 转换与官方 `graphicsLayer` 接线，
// 不另算第二份几何。

/** 把 Compose 侧的落点几何转回纯模型的 [AppearanceEditorCardBox]，避免两处各算一遍。 */
internal fun AppearanceEditorCardGeometry.toCardBox(): AppearanceEditorCardBox =
    AppearanceEditorCardBox(
        scale = scale,
        cardWidthDp = cardWidth.value,
        cardHeightDp = cardHeight.value,
        cardLeftDp = cardLeft.value,
        cardTopDp = cardTop.value,
        radiusDp = radius.value,
        topReserveDp = topReserve.value,
        bottomReserveDp = bottomReserve.value,
        availableHeightDp = availableHeight.value,
    )

/**
 * 底部 chrome 的入场层：淡入 + 自下而上 80dp + 从 8dp 模糊对焦。
 *
 * 只有这一层在组合期读进度（`Modifier.blur` 的半径只能在组合期给），代价是两颗圆钮
 * 逐帧重组；卡片与顶栏都在绘制 lambda 里读，不触发重组。
 */
@Composable
private fun BottomChromeEntranceLayer(
    progress: () -> Float,
    content: @Composable BoxScope.() -> Unit,
) {
    val t = progress()
    val alpha = AppearanceEditorEntranceSpec.bottomChromeAlpha(t)
    val offset = AppearanceEditorEntranceSpec.bottomChromeOffsetDp(t)
    val blurRadius = AppearanceEditorEntranceSpec.bottomChromeBlurDp(t)
    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .graphicsLayer {
                    this.alpha = alpha
                    translationY = offset.dp.toPx()
                }
                .then(
                    if (blurRadius > 0.01f) {
                        Modifier.blur(blurRadius.dp)
                    } else {
                        Modifier
                    },
                ),
            content = content,
        )
    }
}

// ─────────────────────────────────────────────── 几何（数值本体在纯模型里）
//
// 公式与常量都住在 `main/.../pages/settings/AppearanceEditorTransition.kt`，可以走
// L0 JVM 单测逐数断言（`AppearanceEditorTransitionTest`）。这里只做 dp ↔ Float 的
// 薄包装，免得 Compose 文件里再算第二份、两边迟早漂。

/**
 * 屏幕圆角兜底值（逻辑像素）。
 *
 * Dart 侧这个数从平台通道读（`AndroidAnimationScaleService.displayCornerRadiusDp`），
 * 拿不到时回落到 `kPageCornerRadiusFallbackDp = 28`
 * （`lib/models/page_corner_radius.dart:16`）。Kotlin 侧目前**没有**读屏幕圆角的
 * 平台层，所以先取同一个兜底值 —— 卡片圆角 = 这个值 × 缩放比（Dart `:1638-1642`）。
 * 将来补了平台读数，改纯模型里那一个常量即可。
 */
internal val APPEARANCE_EDITOR_SCREEN_CORNER_RADIUS_DP: Dp =
    AppearanceEditorTransitionSpec.SCREEN_CORNER_FALLBACK_DP.dp

/** 卡片浮影模糊半径：Dart `blurRadius: 32`（`:1838`）。 */
internal val APPEARANCE_EDITOR_CARD_SHADOW_BLUR: Dp =
    AppearanceEditorTransitionSpec.CARD_SHADOW_BLUR_DP.dp

/** 卡片相对可用宽度的上限比例：Dart `_cardMaxWidthFactor = 0.86`（`:109-114`）。 */
internal const val APPEARANCE_EDITOR_CARD_MAX_WIDTH_FACTOR =
    AppearanceEditorCardGeometrySpec.CARD_MAX_WIDTH_FACTOR

/**
 * 预览卡连续圆角（squircle）的曲率延伸倍数。
 *
 * 半径仍**严格对齐 Flutter 发布版**（`cardRadius = min(displayCornerRadiusDp * scale, cardHeight/2)`，
 * 见 [appearanceEditorCardBox]）；这里只调「角部曲线怎么转折」——`extension` 越大，直线与弧之间的
 * 曲率过渡区越宽、越连续圆润。miuix 默认 1.1（标准 squircle）；`1.0` 等同标准圆弧。
 *
 * 用户要「明显更圆润」的 Capsule 式连续圆角，故取 1.4（在 1.2–1.5 区间；真机若仍嫌不够再往 1.5 抬）。
 * 卡片填充/裁剪、内层 1.5dp 内边、阴影路径三处必须用**同一个值**，形状才重合。
 */
internal const val APPEARANCE_EDITOR_SQUIRCLE_EXTENSION = 1.4f

/**
 * 卡片的落点几何（单位都是 dp / 无单位缩放比）。
 *
 * 字段与 Dart `LayoutBuilder` 里那批局部变量一一对应（`:1624-1650`），命名尽量贴原变量，
 * 免得两边对不上。数值由 [appearanceEditorCardBox] 产出。
 */
internal data class AppearanceEditorCardGeometry(
    /** 卡片相对整屏的缩放比（Dart `scale`，`:1632`）。 */
    val scale: Float,
    /** 卡片宽（= 整屏宽 × scale，Dart `cardWidth`）。 */
    val cardWidth: Dp,
    /** 卡片高（= 整屏高 × scale，Dart `cardHeight`）。 */
    val cardHeight: Dp,
    /** 卡片左边（横向居中，Dart `cardLeft`）。 */
    val cardLeft: Dp,
    /** 卡片上边（纵向居中于「上下 chrome 之间」那条带，Dart `cardTop`）。 */
    val cardTop: Dp,
    /** 卡片圆角（= 屏幕圆角 × scale，再夹到 cardHeight/2，Dart `cardRadius`）。 */
    val radius: Dp,
    /** 顶部留给 chrome 的净空。 */
    val topReserve: Dp,
    /** 底部留给 chrome 的净空。 */
    val bottomReserve: Dp,
    /** 上下净空之间那条带的高度（卡片在其中居中）。 */
    val availableHeight: Dp,
)

/**
 * 按 Dart 的几何公式算出卡片矩形（`:1617-1650` 的 `LayoutBuilder` 逐行对应）。
 *
 * 真正的算式在纯模型 [appearanceEditorCardBox] 里（可 JVM 单测）；这里只把 dp 转成
 * Float 再转回来。公式里**没有任何手工修正项** —— Dart 明确撤掉了「视觉重心」偏移
 * （`:1643-1646`：加过一版，结果卡片压到底部按钮净空里）。
 *
 * @param areaWidth / areaHeight 整页可用区（`BoxWithConstraints` 的约束）。
 * @param screenWidth / screenHeight 整屏逻辑尺寸（Dart `media.size`）。
 * @param topInset / bottomInset 系统栏高度。
 * @param screenCornerRadius 屏幕圆角（见 [APPEARANCE_EDITOR_SCREEN_CORNER_RADIUS_DP]）。
 */
internal fun appearanceEditorCardGeometry(
    areaWidth: Dp,
    areaHeight: Dp,
    screenWidth: Dp,
    screenHeight: Dp,
    topInset: Dp,
    bottomInset: Dp,
    screenCornerRadius: Dp = APPEARANCE_EDITOR_SCREEN_CORNER_RADIUS_DP,
): AppearanceEditorCardGeometry {
    val box = appearanceEditorCardBox(
        areaWidthDp = areaWidth.value,
        areaHeightDp = areaHeight.value,
        screenWidthDp = screenWidth.value,
        screenHeightDp = screenHeight.value,
        topInsetDp = topInset.value,
        bottomInsetDp = bottomInset.value,
        screenCornerRadiusDp = screenCornerRadius.value,
    )
    return AppearanceEditorCardGeometry(
        scale = box.scale,
        cardWidth = box.cardWidthDp.dp,
        cardHeight = box.cardHeightDp.dp,
        cardLeft = box.cardLeftDp.dp,
        cardTop = box.cardTopDp.dp,
        radius = box.radiusDp.dp,
        topReserve = box.topReserveDp.dp,
        bottomReserve = box.bottomReserveDp.dp,
        availableHeight = box.availableHeightDp.dp,
    )
}
