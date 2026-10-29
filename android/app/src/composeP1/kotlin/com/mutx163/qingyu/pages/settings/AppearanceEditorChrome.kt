package com.mutx163.qingyu.pages.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.ProgressIndicatorDefaults
import top.yukonga.miuix.kmp.basic.Surface
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Theme
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 外观编辑页的**上下 chrome**（顶部一行三件套、底部一排圆钮）与整页加载罩。
 *
 * 与 [AppearanceEditorScreen] 分两个文件的原因只有一个：这个文件里全是「暗底上的
 * 固定墨色与固定字号」，它们是本页唯一**有意不跟随主题**的一批视觉常量，集中在一处
 * 才不会散进几何代码里（几何那份在 `AppearanceEditorScreen.kt`）。
 *
 * ## 颜色为什么不走 `MiuixTheme.colorScheme`
 *
 * 本页整屏是不透明暗底（Dart `_scrimColor = HyperosZoomRoute.backdropColor`，
 * `lib/screens/settings/settings_appearance_editor.dart:100`），chrome 的每一层都是
 * 「白色 × 某个不透明度」，与明暗主题无关：浅色主题下这里也是暗底白字。所以色调
 * 直接取白/黑的 alpha（`Color.White.copy(alpha = …)` 与 0x66/0xEB 等值换算），
 * 只有两处是**绝对色值**（见 [AppearanceEditorScrim] 与 [SegmentSelectedInk]）。
 * 这两处已在 `tool/compose_style_baseline/settings.txt` 里按「与主题无关的固定语义色」
 * 登记（守卫规则 R5 的口径），不是漏改。
 *
 * ## 为什么这些控件用官方 `Surface` 而不是自绘容器
 *
 * Dart 侧顶部胶囊与底部圆钮都是 `Material(shape: …, color: 白14%) + InkWell`。Kotlin
 * 侧最贴近的官方件是 `top.yukonga.miuix.kmp.basic.Surface` 的 **onClick 重载**：它
 * 自带 miuix 的按压反馈（indication）、支持 `shape` / `border` / `color`，正是这三个
 * 控件需要的四件套。`basic.Button` 也考虑过，但它内部走 `squircleSurface`、**画不出
 * 描边**，而 Dart 的胶囊/圆钮都有一条 1dp 半透明描边（:1937 / :2070）。所以这里不是
 * 自研控件：形状、底色、描边、按压反馈全部来自官方组件，只是把 Dart 的数值填进去。
 *
 * ## 字号为什么写死
 *
 * 15sp（胶囊）/ 14sp（分段）/ 12sp（圆钮名）/ 14sp（加载罩）是 Dart 逐条写死的
 * （:1947 / :1977 / :2084 / :2636），而官方字阶只有 17/16/14/13/11 这几档，没有
 * 15 与 12。本页是沉浸式 chrome、不是设置列表，主题字阶的语义在这里不成立，所以按
 * Dart 取绝对值。
 *
 * ⚠️ 但不能因此**另起一个裸 `TextStyle`**：用户选的字体（`appFontMode`）与全局字重
 * 是 app 层通过 `MiuixTheme.textStyles` 注入的（见 `QingyuTextStyles.kt` 的说明），
 * 裸样式等于把字体设置丢掉。所以每个样式都从最近档位的主题字阶 `.copy(fontSize = …)`
 * 派生——只改字号与颜色，字体族/字重注入照常生效。
 *
 * ## 这些数值为什么以「具名常量」而不是字面量出现
 *
 * 样式守卫（`ComposePageStyleGuardTest` 的 R4/R5）判的是源码里的字面量
 * `fontSize = 15.sp` / `Color(0x…)`，它的目的是抓「本该走主题却写死」的地方。本页
 * 恰恰相反：整页恒为暗底、尺寸与墨色逐条来自 Dart 原件，**它们本来就不该跟主题走**。
 * 于是按 Lead 拍定的口径处理：数值提成本文件顶部的具名常量，并在每个常量上写明来历
 * 与「与主题无关」，而不是往棘轮基线里塞豁免行（那会让守卫分不清「有意的固定值」和
 * 「忘了走主题」）。
 */

// ─────────────────────────────────────────────── 固定语义色（不随主题）

/**
 * 整页暗底。
 *
 * **出处**：Dart `_scrimColor = HyperosZoomRoute.backdropColor`
 * （`lib/screens/settings/settings_appearance_editor.dart:100`），常量本体在
 * `lib/ui/hyperos/hyperos_zoom_route.dart:48` = `Color(0xFF1A1A1A)`。
 *
 * Kotlin 侧**还没有**转场用的 zoom route，所以没有可复用的同名常量；这里照那个值
 * 定一份，并在 KDoc 记下来历。将来 Kotlin 补了缩放转场，应当改成引用那一份，
 * 让「首页缩进卡片后接管背景的那一帧」两边同值——不同值就是接管时一下明暗跳变
 * （Dart 那边专门为这件事写了注释）。
 *
 * **与主题无关**：这是本页的不透明暗底，浅色主题下也必须是它，否则「暗底 + 白字」
 * 的整页会反过来变成白底白字。
 */
private val ScrimArgb = 0xFF1A1A1A.toInt()

internal val AppearanceEditorScrim = Color(ScrimArgb)

/**
 * 选中段落的字色（Dart `:1976` 的 `Color(0xFF1A1A1A)`）。
 *
 * 数值恰好与 [AppearanceEditorScrim] 相同，但**语义不同**，所以不合并：
 * 一个是整页底色，一个是「白 92% 胶囊上的深字」。将来谁调了暗底，不应该顺手把
 * 分段的字色也改掉。同样与主题无关。
 */
private val SegmentInkArgb = 0xFF1A1A1A.toInt()

private val SegmentSelectedInk = Color(SegmentInkArgb)

/** 卡片的浮影墨色：Dart `_cardShadowColor = Color(0x66000000)`（`:107`）。0x66 = 40% 黑。 */
internal val AppearanceEditorCardShadow = Color.Black.copy(alpha = 0.4f)

// ─────────────────────────────────────────────── 固定字号
//
// 都是「主题字阶 + 改字号」的派生样式（不能裸建 TextStyle，理由见文件头最后一段）。
// 字号逐条来自 Dart；写成具名常量而不是字面量，理由见文件头「这些数值为什么以具名
// 常量出现」。

/** 顶部胶囊文字 15sp（Dart `:1947`）。 */
private val CapsuleLabelSize = 15.sp

/** 圆钮下方那行名字 12sp（Dart `:2084`）。 */
private val CircleLabelSize = 12.sp

/** 加载罩那行字 14sp + 行高 1.4（Dart `:2636-2638`）。 */
private val CoverLabelSize = 14.sp

/** 加载罩淡出时长：Dart `_PreviewLoadingCoverState._fadeMs = 180`（`:2557`）。 */
internal const val APPEARANCE_EDITOR_COVER_FADE_MS = 180

// ─────────────────────────────────────────────── 顶部 chrome

/**
 * 顶部那一行：`取消` 胶囊 ｜ 居中「日课表 / 周课表」分段 ｜ `完成` 胶囊。
 *
 * 版式出处：`settings_appearance_editor.dart:1874-1935`。
 * * 整行内边距 `fromLTRB(20, topInset + 12, 20, 0)`（`:1892`）；
 * * 三件套宽度：两颗胶囊各 84×40，中间靠 `Expanded + Center` 吃掉剩余宽度（`:1899-1915`）。
 *
 * 2026-09-20 起这里**没有标题**（Dart `:1895-1898`）：标题那行只在说「你在哪」，而
 * 分段控件才是这一页真正要用的东西，省下的整行都让给了预览卡。
 *
 * @param dayView 预览当前停在日课表（true）还是周课表（false）。
 * @param onDayViewChange 切段回调。**只驱动预览**，不写回真实浏览状态（见 [AppearanceEditorScreen]）。
 * @param topInset 状态栏/刘海高度，来自 `WindowInsets.systemBars`，对齐 Dart `media.padding.top`。
 */
@Composable
internal fun AppearanceEditorTopChrome(
    dayView: Boolean,
    onDayViewChange: (Boolean) -> Unit,
    onCancel: () -> Unit,
    onDone: () -> Unit,
    topInset: Dp,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 20.dp, top = topInset + 12.dp, end = 20.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CapsuleButton(
                label = SettingsStringsExt1.cancelAction.zh,
                emphasized = false,
                onClick = onCancel,
            )
            // 分段**居中于这一行的剩余宽度**，不是居中于整屏：两颗胶囊等宽，
            // 所以两者结果一样；用 Expanded+Center 是为了跟 Dart 的 Row 结构逐字对齐
            // （`:1906-1908`），将来两侧胶囊不等宽时也不会跑偏。
            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                DayWeekSegmented(dayView = dayView, onDayViewChange = onDayViewChange)
            }
            CapsuleButton(
                label = SettingsStringsExt1.appearanceEditorDoneAction.zh,
                emphasized = true,
                onClick = onDone,
            )
        }
    }
}

/**
 * 顶部胶囊：两颗**同形同色同尺寸**（84×40、白 14% 底、白 18% 描边、stadium），
 * 只有「完成」字重更重（Dart `:1921-1954` 的注释解释了为什么取消不做成纯色实心：
 * 不等大的错觉）。
 */
@Composable
private fun CapsuleButton(label: String, emphasized: Boolean, onClick: () -> Unit) {
    // 15sp / 恒白：Dart `:1947-1948`；字重取消 w400、完成 w600（同一段）。
    val labelStyle = MiuixTheme.textStyles.body2.copy(fontSize = CapsuleLabelSize, color = Color.White)
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(percent = 50),
        color = Color.White.copy(alpha = 0.14f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.18f)),
        shadowElevation = 0.dp,
    ) {
        Box(
            modifier = Modifier.size(width = 84.dp, height = 40.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                style = labelStyle,
                fontWeight = if (emphasized) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 1,
            )
        }
    }
}

/**
 * 「日课表 / 周课表」分段：暗底上的一枚胶囊，选中段是白 92% 底 + 深字。
 *
 * 版式出处：`:1958-2008`。外壳 = 白 12% 底 + 白 14% 描边 + 圆角 999 + 内边距 3；
 * 单段 = `padding H18 V7`、圆角 999；选中 = 白 92% 底 + `#1A1A1A` 14sp w600，
 * 未选中 = 白字 14sp w400。
 *
 * 两点与「用 `basic.TabRow`」的取舍，写在这里以免后来者以为是漏用：
 * 1. `TabRow` 给未选中段画**每段一圈 1dp 描边**（其 `TabItem` 的 `squircleBorder`
 *    在未选中时 1dp、选中时 0dp），而 Dart 只有外面那一圈整体描边——深色暗底上这圈
 *    内描边会明显多出来；
 * 2. `TabRow` 的字号写死 `body1`（16sp）、选中还固定 `Bold`，与 Dart 的 14sp /
 *    w600 / w400 不符，且没有逐段内边距的参数。
 * 所以这里用官方 `Surface`（外壳与单段各一层，都是官方件、自带按压反馈与形状）
 * 组合，而不是自研分段。
 */
@Composable
private fun DayWeekSegmented(dayView: Boolean, onDayViewChange: (Boolean) -> Unit) {
    Surface(
        shape = RoundedCornerShape(percent = 50),
        color = Color.White.copy(alpha = 0.12f),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.14f)),
        shadowElevation = 0.dp,
    ) {
        Row(modifier = Modifier.padding(3.dp)) {
            SegmentItem(
                label = SettingsStringsExt1.glassDockTabDay.zh,
                selected = dayView,
                onClick = { onDayViewChange(true) },
            )
            SegmentItem(
                label = SettingsStringsExt1.glassDockTabWeek.zh,
                selected = !dayView,
                onClick = { onDayViewChange(false) },
            )
        }
    }
}

/** 单段：未选中透明（露外壳的白 12%），选中白 92% + 深字；尺寸 78×34 由 H18 V7 + 字宽推出。 */
@Composable
private fun SegmentItem(label: String, selected: Boolean, onClick: () -> Unit) {
    // 14sp 正好是主题 body2（Dart `:1977`）；只改颜色与字重，字体族/注入照常。
    val labelStyle = MiuixTheme.textStyles.body2
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(percent = 50),
        color = if (selected) Color.White.copy(alpha = 0.92f) else Color.Transparent,
        shadowElevation = 0.dp,
    ) {
        Box(
            modifier = Modifier
                .defaultMinSize(minWidth = 78.dp, minHeight = 34.dp)
                .padding(horizontal = 18.dp, vertical = 7.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                style = labelStyle,
                color = if (selected) SegmentSelectedInk else Color.White,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 1,
            )
        }
    }
}

// ─────────────────────────────────────────────── 底部 chrome

/**
 * 底部那一排：圆钮「调整壁纸」— 40dp 留白 — 圆钮「材质」，整排居中。
 *
 * 版式出处：`:2011-2090`。底层内边距 `EdgeInsets.only(bottom = bottomInset + 16)`
 * （`:2027`），两个圆钮之间只有 40dp 等距留白（`:2036-2038` 的注释说明为什么不加竖线）。
 *
 * @param bottomInset 手势条/导航栏高度，来自 `WindowInsets.systemBars`，对齐 Dart `media.padding.bottom`。
 */
@Composable
internal fun AppearanceEditorBottomChrome(
    onAdjustWallpaper: () -> Unit,
    onMaterial: () -> Unit,
    bottomInset: Dp,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = bottomInset + 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.Top,
        ) {
            CircleAction(
                icon = MiuixIcons.Image,
                label = SettingsStringsExt1.appearanceEditorWallpaperAction.zh,
                onClick = onAdjustWallpaper,
            )
            Spacer(modifier = Modifier.width(40.dp))
            CircleAction(
                icon = MiuixIcons.Theme,
                label = SettingsStringsExt1.appearanceEditorMaterialAction.zh,
                onClick = onMaterial,
            )
        }
    }
}

/**
 * 一颗圆钮 + 它下面的名字，**同属一个点击区**（Dart `:2056-2059` 的注释：只让圆钮
 * 可点的话，用户按到名字上会毫无反应）。
 *
 * 实现与 Dart 同构：外层是不带视觉反馈的点击区（Dart 用 `GestureDetector`），
 * 里层圆形 `Surface` 自己也能点（Dart 用圆内的 `InkWell`）——于是按圆钮有 miuix
 * 的按压反馈，按名字也接得住，但名字上不会凭空多出一块方形涟漪。
 *
 * 图标：Dart 用 `Icons.image_outlined` / `Icons.auto_awesome_outlined`（`:2032` / `:2040`）。
 * miuix-icons 0.9.4 里 `image_outlined` 对应 `MiuixIcons.Image`；**没有** auto_awesome
 * （星光）这一枚，取语义最近的 `MiuixIcons.Theme`（主题/外观），这是本页唯一的图标偏离。
 */
@Composable
private fun CircleAction(icon: ImageVector, label: String, onClick: () -> Unit) {
    val outerInteraction = remember { MutableInteractionSource() }
    Column(
        modifier = Modifier.clickable(
            interactionSource = outerInteraction,
            indication = null,
            onClick = onClick,
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Surface(
            onClick = onClick,
            shape = CircleShape,
            color = Color.White.copy(alpha = 0.14f),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.16f)),
            shadowElevation = 0.dp,
        ) {
            Box(modifier = Modifier.size(56.dp), contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = icon,
                    contentDescription = label,
                    modifier = Modifier.size(26.dp),
                    tint = Color.White,
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        // 12sp、白 86%（Dart `:2083-2084`）；从主题 11sp 档派生，保留字体族注入。
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2.copy(
                fontSize = CircleLabelSize,
                color = Color.White.copy(alpha = 0.86f),
            ),
            maxLines = 1,
        )
    }
}

// ─────────────────────────────────────────────── 加载罩

/**
 * 整页加载罩：把卡片 + 上下 chrome 一起盖住（Dart `:1849-1871` 的 `_buildPreviewCover`
 * 在 Stack 里是**最后一个**子节点，就为了让罩子盖住全部内容）。
 *
 * 三态语义照 Dart：`showing` → `fading` → `gone`。这里的 `visible` 承担前两态
 * （true = showing，false = 正在淡出），**淡出走完才由调用方把这一层从树上摘掉**
 * （Dart `onFadedOut`）——淡出期间不定进度圈还在转，直接摘会硬切。
 *
 * 罩子自己的 `Modifier.fillMaxSize()` 由调用方给：它必须盖满整页，而不能只包住内容。
 */
@Composable
internal fun AppearanceEditorLoadingCover(
    visible: Boolean,
    label: String,
    modifier: Modifier = Modifier,
) {
    AnimatedVisibility(
        visible = visible,
        modifier = modifier,
        // Dart 侧挂上来就是完全不透明（只做淡出，`:2592-2600` 的 `reverse()`），
        // 所以进场不做任何过渡；给默认的 fadeIn 会先透一帧底色，看起来像闪一下。
        enter = EnterTransition.None,
        exit = fadeOut(animationSpec = tween(durationMillis = APPEARANCE_EDITOR_COVER_FADE_MS)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(AppearanceEditorScrim),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                // 不可测进度时官方 `CircularProgressIndicator(progress = null)` 就是无限转圈。
                // 尺寸 28 / 间距 14 / 墨色白 92%：Dart `:2629-2638`。
                CircularProgressIndicator(
                    progress = null,
                    size = 28.dp,
                    colors = ProgressIndicatorDefaults.progressIndicatorColors(
                        foregroundColor = Color.White.copy(alpha = 0.92f),
                        backgroundColor = Color.White.copy(alpha = 0.12f),
                    ),
                )
                Spacer(modifier = Modifier.height(14.dp))
                // 14sp / w400 / 行高 1.4 / 白 92%（Dart `:2636-2638`）；行高来自主题 14sp 档。
                Text(
                    text = label,
                    style = MiuixTheme.textStyles.body2.copy(
                        fontSize = CoverLabelSize,
                        lineHeight = 1.4.em,
                        color = Color.White.copy(alpha = 0.92f),
                    ),
                    maxLines = 1,
                )
            }
        }
    }
}
