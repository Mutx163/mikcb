package com.mutx163.qingyu.pages.settings

import android.graphics.BitmapFactory
import android.os.SystemClock
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.WidgetPreviewRenderer
import com.mutx163.qingyu.theme.QingyuShapes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlin.math.absoluteValue
import kotlin.math.roundToInt

/**
 * 「桌面小组件」设置页的效果预览轮播（`settings_home_widget.dart:405-499`）。
 *
 * ## 它为什么不能是一个普通 miuix 组件
 *
 * 这一块显示的不是「用 Compose 重画的近似卡片」，而是**十张真实卡片**的位图：
 * 原生侧 inflate 同一份 `widget_*.xml`、跑同一段填数据代码，再把 RemoteViews 就地
 * 画成 PNG（[WidgetPreviewRenderer]）。所以它必须：
 *
 * 1. 有分页（每张卡片的格位尺寸不同：2×2 / 2×4 / 4×4 / 4×1 / 4×2）；
 * 2. 每页一张位图 + 指示点 + 卡片名 + 尺寸读数 + 「添加到桌面」；
 * 3. 位图要按当前设置**重渲染**（`revision` 变了整批作废）。
 *
 * miuix 没有「位图轮播」这种控件，分页由 `HorizontalPager` 承担；卡片名 / 按钮 /
 * 加载圈仍用 miuix 组件与主题槽位（不写死颜色与字号）。例外登记见
 * `docs/reference/miuix-component-first-standard.md`。
 *
 * ## 与 Dart 逐项对齐（行号见 Dart 源）
 *
 * | Dart | 这里 |
 * |---|---|
 * | `HyperosSectionLabel(homeWidgetPreviewTitle)`（:425） | 复用页面同一个 `SectionLabel` |
 * | `PageView.builder` + `PageScrollPhysics`（:441-460） | [HorizontalPager] |
 * | 视口高 = 当前页 `heightDp + 56`（:110-111 / :433） | `animateDpAsState` + [VIEWPORT_EXTRA_DP] |
 * | `Transform.scale(1 - 0.03 * distance)`（:559-562） | `graphicsLayer`（按滚动位置连续缩放） |
 * | `_buildPreviewDots`（:678-700） | [PreviewDots] |
 * | 卡片名 `HyperosTypography.listTitle`（:467-471） | `MiuixTheme.textStyles.headline1` |
 * | 尺寸读数 `'${w.round()} × ${h.round()} dp'`（:86 / :475-485） | [SettingsHomeWidgetPage.sizeLabel] |
 * | `_buildPinWidgetButton` + `loading`（:638-660 / :487-490） | miuix [Button] |
 * | 精确闹钟引导条（:493-496） | **不在本组件里**：它是模型里独立的 CONTROL_CARD 节点 |
 *
 * ## 刻意没照抄的两处
 *
 * 1. **不做「溢出到 16dp 列表内边距之外」**（Dart `OverflowBox`，:434-439）：Dart 那层
 *    是为了「滑动边界正好是屏幕边界」。Compose 里让列表项做负外边距要绕过布局约束，
 *    收益只有每侧 16dp 的滑动余量；而格位尺寸按屏宽算出来的最大一张（4 格 =
 *    屏宽 − 40dp）本来就放得进列表内容宽度（屏宽 − 32dp），不会被裁。
 * 2. **渲染与解码都放 IO 线程**：Dart 走平台通道、原生在后台执行器里画；Compose 侧
 *    直接调渲染器，留在主线程就是每张上百毫秒的掉帧。
 */
@Composable
fun WidgetPreviewSection(node: SettingsInline) {
    val host = LocalHomeWidgetPreviewHost.current
    val configuration = LocalConfiguration.current
    // 格位尺寸按**屏幕逻辑宽度**换算（`buildHomeWidgetPreviewSpecs`，
    // `home_widget_service.dart:96-127`）：格数固定，dp 随屏幕变，比例不变。
    // 形参是 Double（F20-A 的 `HomeWidgetPreviewSpecs.build`）：尺寸口径只留一处，
    // 不在这里多写一个 Int 重载。
    val specs = remember(configuration.screenWidthDp) {
        HomeWidgetPreviewSpecs.build(configuration.screenWidthDp.toDouble())
    }

    // 宿主没接线（例如将来有人直接拿模型画这一页）：标题照给，正文退化成一行说明，
    // 不崩、不空白。
    if (host == null) {
        SectionLabel(text = node.label.orEmpty())
        Text(
            text = SettingsStringsExt2.homeWidgetPreviewUnavailable.text,
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                    end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                    bottom = 8.dp,
                ),
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            style = MiuixTheme.textStyles.footnote1,
        )
        return
    }

    // 拿不到屏幕宽度时整块不占位，连标题都不画（Dart `_buildPreviewSection` :406-409
    // 返回 `SizedBox.shrink()`）：一个孤零零的「效果预览」标题下面是空的，比没有更怪。
    if (specs.isEmpty()) return

    // 标题与页面其它区块同一套样式（复用同一个 internal SectionLabel，不另抄一份）。
    SectionLabel(text = node.label.orEmpty())

    val dark = isSystemInDarkTheme()
    // 语言也按 App 当前档给（桌面上卡片跟随系统应用语言，App 内可单独切）；
    // 不覆盖的话中文界面里会冒出英文卡片（同 `WidgetPreviewRenderer.themedContext` 的注释）。
    val languageTag = remember(configuration) {
        runCatching { configuration.locales[0].toLanguageTag() }.getOrDefault("")
    }
    val appContext = LocalContext.current.applicationContext
    val pagerState = rememberPagerState(pageCount = { specs.size })
    val renderLock = remember { Mutex() }
    // 缓存键含 revision ⇒ 设置一改，键就变，LaunchedEffect 重跑、旧位图不再命中。
    // 同时按 revision `remember` 两个表：旧代次的位图直接丢掉，不让它们一直占内存。
    val bitmaps = remember(host.revision) { mutableStateMapOf<String, PreviewBitmap>() }
    val failedAt = remember(host.revision) { mutableStateMapOf<String, Long>() }

    val currentIndex = pagerState.currentPage.coerceIn(0, specs.lastIndex)
    val currentSpec = specs[currentIndex]
    // 视口高度跟着**当前页卡片的格位高度**走（Dart `_previewViewportHeight`，:110-111）：
    // 固定成最大卡的高度会让 4×1 横条上下空出一大片，反过来又裁掉 4×4 大卡。
    // 多出来的 56dp = 上下各 28dp，给投影留位置（投影向下占用 25dp）。
    val viewportHeight by animateDpAsState(
        targetValue = currentSpec.heightDp.dp + VIEWPORT_EXTRA_DP.dp,
        animationSpec = tween(durationMillis = PREVIEW_ANIMATION_MILLIS, easing = EASE_OUT_CUBIC),
    )

    Column(modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(viewportHeight),
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
                // 预取左右各一张（Dart `_prefetchPreviewAround`，:702-707）：
                // 翻到相邻页时图已经在了，不会停在转圈上。
                // 参数名按本仓 Compose Foundation 的版本（1.12 仍是
                // `beyondViewportPageCount`，`beyondBoundsPageCount` 是更新的重命名）。
                beyondViewportPageCount = 1,
            ) { pageIndex ->
                val spec = specs[pageIndex]
                val targetId = spec.targetId
                val cellWidthDp = spec.widthDp
                val cellHeightDp = spec.heightDp
                val cacheKey = previewCacheKey(
                    targetId = targetId,
                    sizeKey = "${cellWidthDp}x${cellHeightDp}",
                    dark = dark,
                    languageTag = languageTag,
                    revision = host.revision,
                )
                LaunchedEffect(cacheKey) {
                    loadPreview(
                        cacheKey = cacheKey,
                        targetId = targetId,
                        widthDp = cellWidthDp.roundToInt(),
                        heightDp = cellHeightDp.roundToInt(),
                        dark = dark,
                        languageTag = languageTag,
                        settingsJson = host.settingsJson,
                        context = appContext,
                        renderLock = renderLock,
                        bitmaps = bitmaps,
                        failedAt = failedAt,
                    )
                }
                val preview = bitmaps[cacheKey]
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        // 只做极轻的缩放（Dart :559-562 的 `1 - 0.03 * distance`）：
                        // 卡片贴边滑动时若再叠加透明度，边缘会发虚、浅色卡片甚至会
                        // 「消失」——Dart 那边踩过（:557-560 的注释）。
                        .graphicsLayer {
                            val current = pagerState.currentPage + pagerState.currentPageOffsetFraction
                            val distance = (pageIndex - current).absoluteValue.coerceIn(0f, 1f)
                            val scale = 1f - PAGE_SCALE_STEP * distance
                            scaleX = scale
                            scaleY = scale
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    when {
                        preview != null -> PreviewImage(
                            preview = preview,
                            cornerRadius = host.cornerRadius,
                            dark = dark,
                        )

                        // 失败态：文案取 ARB `homeWidgetPreviewUnavailable`，5 秒后
                        // 自动重试（Dart :717-730 / :776-787）——一次偶发失败不该让
                        // 这一页永远空着。
                        failedAt.containsKey(cacheKey) -> Box(
                            modifier = Modifier.size(cellWidthDp.dp, cellHeightDp.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = SettingsStringsExt2.homeWidgetPreviewUnavailable.text,
                                textAlign = TextAlign.Center,
                                // Dart 是 fontSize 12 + 次要色；这里取最近的一档字阶
                                // （footnote1 = 13），不写死字号以跟随用户字重。
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                style = MiuixTheme.textStyles.footnote1,
                            )
                        }

                        else -> Box(
                            // 出图前按**格位**尺寸撑开（Dart :645-676），出图时换成
                            // 卡片本身的尺寸，不会先撑大再缩、看着跳版。
                            modifier = Modifier.size(cellWidthDp.dp, cellHeightDp.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))
        PreviewDots(count = specs.size, current = currentIndex)
        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = SettingsHomeWidgetPage.targetLabelFor(currentSpec.targetId).text,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            color = MiuixTheme.colorScheme.onBackground,
            style = MiuixTheme.textStyles.headline1,
        )
        Spacer(modifier = Modifier.height(3.dp))

        // 还没出图时不显示尺寸（Dart :473-475）：那时只能报格位尺寸，出图后又会跳成
        // 卡片尺寸，数字变一次反而让人以为哪里错了。固定 16dp 占位，出图时不跳版。
        val sizeLabel = bitmaps[
            previewCacheKey(
                targetId = currentSpec.targetId,
                sizeKey = "${currentSpec.widthDp}x${currentSpec.heightDp}",
                dark = dark,
                languageTag = languageTag,
                revision = host.revision,
            )
        ]?.let {
            SettingsHomeWidgetPage.sizeLabel(it.widthDp.toDouble(), it.heightDp.toDouble())
        }.orEmpty()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = sizeLabel,
                textAlign = TextAlign.Center,
                // Dart 是 fontSize 12 + 次要色；同上取 footnote1，不写死字号。
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                style = MiuixTheme.textStyles.footnote1,
            )
        }
        Spacer(modifier = Modifier.height(14.dp))

        Button(
            onClick = { host.onPin(currentSpec.targetId) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
            // Dart `canPin = !checking && canPin && !loading`（:638-646）：
            // 宿主已经把「正在请求 pin」并进 checkingPin，这里只管两个开关。
            enabled = host.canPin && !host.checkingPin,
            // Dart `_buildPinWidgetButton`（settings_home_widget.dart:1078-1093）是
            // `HyperosButtonVariant.secondary`：`secondary` 灰底 + `onSecondaryVariant` 墨
            // （hyperos_controls.dart:719-727）。官方默认 `buttonColors()` 取的是
            // `secondaryVariant`（亮 #F0F0F0），与设置页底 #F2F2F2 的对比比只有 ~1.02，
            // 按钮整个融进背景（用户 2026-11-03 实报）；必须显式降到 `secondary`（#E6E6E6）。
            colors = ButtonDefaults.buttonColors(
                color = MiuixTheme.colorScheme.secondary,
                contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
            ),
        ) {
            if (host.checkingPin) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(
                // 按钮文案由模型给（`homeWidgetPreviewAddAction`「添加到桌面」）：
                // 卡片身份由上方标题与尺寸行表达，按钮只表达动作（Dart :638-641）。
                // 墨色随 `contentColor`（Dart 是 onSecondaryVariant 深灰，不是主色蓝）。
                text = node.texts.firstOrNull()?.text.orEmpty(),
                style = MiuixTheme.textStyles.button,
            )
        }
        // 末尾留白：Dart 在「添加到桌面」与精确闹钟引导条之间有 14dp（:493-495），
        // 引导条是模型里下一个独立节点，间距由这里给。
        Spacer(modifier = Modifier.height(14.dp))
    }
}

/**
 * 预览宿主的接线口（十张卡片的渲染输入 + 一个系统动作 onPin）。
 *
 * 为什么用 CompositionLocal 而不是给 [WidgetPreviewSection] 加参数：它的调用方是
 * [SettingsInlineView] 的 `when` 分支（一次 `SettingsNode` → 一个组件），那条路径拿不到
 * 宿主状态；而宿主（`HomeWidgetHost`）已经在本页根部，用局部值传下去只需改一处。
 *
 * 精确闹钟授权**不在这里**：它是模型里独立的 CONTROL_CARD 节点，动作走
 * `SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT` 的 RUN_NOW。
 */
data class HomeWidgetPreviewHost(
    /**
     * 宿主正在编辑的设置序列化成 JSON（`timetable_settings` 全量键）。
     *
     * 原生渲染会把它**合并**到 profile 内嵌的 settings 上（只覆盖同名键），所以
     * 传全量键最稳：少传的键会沿用到 profile 里的旧值（`WidgetPreviewSession.mergedSettings`）。
     */
    val settingsJson: String,
    /** 卡片圆角（dp）——位图圆角必须与原生按同一档画出来的卡片轮廓对齐。 */
    val cornerRadius: Double,
    /** 设置代次：变一次，已渲染的位图整批作废重出。 */
    val revision: Int,
    /** 桌面是否支持「请求添加卡片」（`WidgetSystemActions.canRequestPinWidget`）。 */
    val canPin: Boolean,
    /** 正在查「是否支持添加」或正在请求添加：按钮转圈且不可点。 */
    val checkingPin: Boolean,
    /** 「添加到桌面」：参数是卡型串（`specs[i].targetId`）。 */
    val onPin: (targetId: String) -> Unit,
)

/** null = 这一页没有接预览宿主（渲染层退化成一行说明）。 */
val LocalHomeWidgetPreviewHost = compositionLocalOf<HomeWidgetPreviewHost?> { null }

/** 一张已渲染好的预览图（[widthDp] / [heightDp] 是**卡片本身**的尺寸，不是格位尺寸）。 */
private class PreviewBitmap(
    val image: ImageBitmap,
    val widthDp: Float,
    val heightDp: Float,
)

/**
 * 渲染一张预览图并写进缓存；失败则记下失败时刻，等 [RETRY_AFTER_MILLIS] 后重试。
 *
 * 串行（[renderLock]）而不是并发：一次出图要 inflate 一整套布局再画，几个 IO 线程
 * 同时画几张卡会跟主线程抢 CPU；Dart 侧走平台通道本来也是排队执行的。
 */
private suspend fun loadPreview(
    cacheKey: String,
    targetId: String,
    widthDp: Int,
    heightDp: Int,
    dark: Boolean,
    languageTag: String,
    settingsJson: String,
    context: android.content.Context,
    renderLock: Mutex,
    bitmaps: SnapshotStateMap<String, PreviewBitmap>,
    failedAt: SnapshotStateMap<String, Long>,
) {
    while (true) {
        if (bitmaps.containsKey(cacheKey)) return
        val lastFailure = failedAt[cacheKey]
        if (lastFailure != null) {
            val waited = SystemClock.elapsedRealtime() - lastFailure
            if (waited < RETRY_AFTER_MILLIS) {
                delay(RETRY_AFTER_MILLIS - waited)
                continue
            }
            failedAt.remove(cacheKey)
        }
        val rendered = renderLock.withLock {
            // 8 秒超时（Dart :751-753）：通道迟迟不回时那条「渲染中」的记账永远出不来，
            // 这一页就再也补不了图。这里同样兜一层——超时按失败处理，5 秒后重试。
            withTimeoutOrNull(RENDER_TIMEOUT_MILLIS) {
                withContext(Dispatchers.IO) {
                    val result = WidgetPreviewRenderer.render(
                        context = context,
                        widgetType = targetId,
                        widthDp = widthDp,
                        heightDp = heightDp,
                        nightMode = dark,
                        languageTag = languageTag,
                        settingsJson = settingsJson,
                    ) ?: return@withContext null
                    val bitmap = BitmapFactory
                        .decodeByteArray(result.png, 0, result.png.size)
                        ?.asImageBitmap()
                        ?: return@withContext null
                    PreviewBitmap(bitmap, result.widthDp, result.heightDp)
                }
            }
        }
        if (rendered == null) {
            failedAt[cacheKey] = SystemClock.elapsedRealtime()
        } else {
            bitmaps[cacheKey] = rendered
        }
    }
}

/** 卡片位图：按图自己的尺寸显示（不是格位尺寸）+ 跟随设置的圆角 + 淡投影。 */
@Composable
private fun PreviewImage(preview: PreviewBitmap, cornerRadius: Double, dark: Boolean) {
    val shape = RoundedCornerShape(cornerRadius.dp)
    // 投影色对齐 Dart（`settings_home_widget.dart:620-628`）：黑 12%（浅色）/ 45%（深色）。
    // 浅色下卡片底接近 #F8FAFC、页面底是 #F2F2F2，不补投影几乎看不出边界。
    val shadowColor = Color.Black.copy(alpha = if (dark) 0.45f else 0.12f)
    Image(
        bitmap = preview.image,
        // 卡片内容本身才是信息，位图是装饰（Dart `excludeFromSemantics: true`）。
        contentDescription = null,
        // Dart `BoxFit.fill`：位图已裁到卡片可见边界，按它自己的物理尺寸铺满即可。
        contentScale = ContentScale.FillBounds,
        modifier = Modifier
            // 用**图自带**的尺寸，不是 spec 的格位尺寸：卡片背景在格位里上下留了一圈
            // 内边距，按格位显示会让图被拉伸，视觉上就是「写着 173×173、看着是扁的」。
            .size(preview.widthDp.dp, preview.heightDp.dp)
            // Dart 是 `blurRadius 18 / offset(0,5) / spread -2`（:620-628）。
            // Compose 的 `shadow` 只有 elevation，没有 offset 与 spread，取 18dp 近似：
            // 形状与色一致、扩散略小，且投影四向均匀而不是只朝下。这是可接受的差异；
            // 换成自绘 `drawBehind` 能精确复刻，但那是自研投影（见 miuix 例外登记）。
            .shadow(
                elevation = PREVIEW_SHADOW_ELEVATION,
                shape = shape,
                clip = false,
                ambientColor = shadowColor,
                spotColor = shadowColor,
            )
            .clip(shape),
    )
}

/**
 * 十个小圆点（Dart `_buildPreviewDots`，:678-700）：当前页宽 14dp、其余 5dp，
 * 高都 5dp、圆角 3dp，色走主色 / 分隔线色，切换用 220ms 缓出。
 */
@Composable
private fun PreviewDots(count: Int, current: Int) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count) { index ->
            val width by animateDpAsState(
                targetValue = if (index == current) DOT_ACTIVE_WIDTH else DOT_INACTIVE_WIDTH,
                animationSpec = tween(
                    durationMillis = PREVIEW_ANIMATION_MILLIS,
                    easing = EASE_OUT_CUBIC,
                ),
            )
            Box(
                modifier = Modifier
                    // Dart 每个点 margin horizontal 3（:688）⇒ 相邻两点间距 6dp。
                    .padding(horizontal = 3.dp)
                    .width(width)
                    .height(DOT_HEIGHT)
                    .clip(RoundedCornerShape(DOT_CORNER))
                    .background(if (index == current) colors.primary else colors.dividerLine),
            )
        }
    }
}

/** 缓存键：同一张卡片换了尺寸 / 明暗 / 语言 / 设置代次都要重出图。 */
private fun previewCacheKey(
    targetId: String,
    sizeKey: String,
    dark: Boolean,
    languageTag: String,
    revision: Int,
): String = "$targetId|$sizeKey|$dark|$languageTag|$revision"

/** 视口比卡片本身多留的高度（Dart `_previewViewportExtraDp`，:109）：上下各 28dp。 */
private const val VIEWPORT_EXTRA_DP = 56.0

/** 出图超时（Dart `Duration(seconds: 8)`，:751-753）。 */
private const val RENDER_TIMEOUT_MILLIS = 8_000L

/** 失败后允许重试的间隔（Dart :717-730 的 5 秒）。 */
private const val RETRY_AFTER_MILLIS = 5_000L

/** Dart 的 `220.scaledMs`：这里不接系统动画时长缩放（与页面其它动画一致）。 */
private const val PREVIEW_ANIMATION_MILLIS = 220

/** 每页的缩放梯度（Dart `1 - 0.03 * distance`，:559-562）。 */
private const val PAGE_SCALE_STEP = 0.03f

/** `Curves.easeOutCubic` 的贝塞尔等价形式。 */
private val EASE_OUT_CUBIC = CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f)

/** 投影：Dart `blurRadius: 18`；Compose 的 elevation 没有 offset / spread，取同值近似。 */
private val PREVIEW_SHADOW_ELEVATION = 18.dp

private val DOT_ACTIVE_WIDTH = 14.dp
private val DOT_INACTIVE_WIDTH = 5.dp
private val DOT_HEIGHT = 5.dp
private val DOT_CORNER = 3.dp
