package com.mutx163.qingyu.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.InfiniteProgressIndicator
import top.yukonga.miuix.kmp.basic.LinearProgressIndicator
import top.yukonga.miuix.kmp.basic.ProgressIndicatorDefaults
import top.yukonga.miuix.kmp.theme.LocalContentColor

/**
 * 全软件加载态统一套件（总清单 D1，2026-11-10）。
 *
 * ## 为什么有这一层
 *
 * 改造前全仓 28 个文件、47 个渲染点各写各的：出了 8 种直径（14/16/18/20/22/24/28/48 加官方默认
 * 30）、6 档垂直留白（8/24/28/32/48/120dp）、两种写法（`size =` 与 `Modifier.size()`），
 * 还有 3 处把默认主色的蓝圈画在 primary 蓝底按钮上（等于隐形）。所有数值各不相同，
 * 但语义只有四类，所以这里收口成 [QingyuLoadingCenter] / [QingyuLoadingInline] /
 * [QingyuLoadingScrim] / [QingyuLoadingProgressBar] 四个入口；唯一例外是行首方块位的
 * [QingyuLoadingAccentGlyph]（22 / 2.2，颜色随该行 accent，见其 KDoc）。
 *
 * 基准是已发布版 tag `v2.1.4.1` 的真实行为，不是照抄开发期 Dart 源：
 *
 * - 扫弧（一段圆弧来回扫）用于常规加载：`lib/ui/hyperos/hyperos_progress.dart:7-24`
 *   （`HyperosCircularProgress`，默认 `size = 24`、`strokeWidth = 2.5`，见 `:10-11`）。
 * - 细环 + 绕行小圆点用于「不可测进度」：同文件 `:48-71`（`HyperosInfiniteProgress`），
 *   注释原话「**不可测进度**的场景（不知道还剩多久、只是要告诉用户还在转）一律用这个」（`:43-44`）。
 * - 整页居中 6 处全是 `Center(HyperosCircularProgress())`，无文案：
 *   `lib/screens/changelog_screen.dart:256`、`open_source_licenses_screen.dart:193`、
 *   `user_guide_screen.dart:530`、`cloud_sync_screen.dart:765` 与 `:941`、
 *   `live_diagnostics_log_viewer_screen.dart:574`。
 * - 行内三档尺寸各有槽位：按钮内 16（`cloud_sync_screen.dart:22-28`）、
 *   图标位替换 18（`live_diagnostics_log_viewer_screen.dart:518`、`:528`）、
 *   极小角标 14（同文件 `:619`）。
 * - 命中遮罩/压暗底一律细环 + 绕行点 28/24/18：
 *   `settings_appearance_editor.dart:2581-2583`、`bing_wallpaper_gallery_page.dart:616`、`:569`、`:532`。
 * - 确定性进度：文案在上、条在下、条高走官方默认：`lib/widgets/home_update_prompt.dart:623-667`。
 *
 * ## 三条硬口径（改这一层之前先读）
 *
 * 1. **居中加载不配文案、不给卡片、不给底色**——发布版 6 处全是裸圈。加文案的只有「局部遮罩」，
 *    而那是调用方自己的排版（例：外观编辑页加载罩），不在这里加参数。
 * 2. **档 A / 档 B 不传 colors**：官方默认取 `primary` / `disabledPrimarySlider` / `secondaryContainer`
 *    （`ProgressIndicatorDefaults.progressIndicatorColors()`），明暗主题自动切换。传死色就丢了暗色适配。
 * 3. **档 C 必须显式给色**：`InfiniteProgressIndicator` 的默认色是写死的 `Color.Gray`
 *    （`third_party/miuix-ui/.../ProgressIndicator.kt:222`），**不跟主题**。压暗底用白，亮底用 onSurface。
 *
 * ## 尺寸默认值为什么不用官方默认
 *
 * 官方 `CircularProgressIndicator` 默认 30dp / 线宽 4dp（`ProgressIndicator.kt:326,329`），
 * 而发布版始终传 24 / 2.5。不传就是「比发布版粗一倍」，所以这里把发布版的数值设成默认。
 */
object QingyuLoadingDefaults {

    /** 档 A 居中加载：发布版 `HyperosCircularProgress()` 默认值（`hyperos_progress.dart:10-11`）。 */
    val PageSize = 24.dp

    /** 档 A 线宽。 */
    val PageStrokeWidth = 2.5.dp

    /** 档 A 在列表项内的最小高度：让转圈落在内容区中段，而不是贴着上方卡片。 */
    val BlockMinHeight = 120.dp

    /** 档 B 按钮内：发布版 `_buttonLoadingPrefix()`（`cloud_sync_screen.dart:22-28`）。 */
    val InlineSize = 16.dp

    /**
     * 档 B 按钮内的**大档**：18dp。
     *
     * 2026-11-10 评审三-08 收口：发布版页脚栏（FooterBar）的「检查更新」忙态是
     * `SizedBox(18×18) + CircularProgressIndicator(strokeWidth: 2)`
     * （`settings_holiday.dart:777-798`），比云同步那种按钮前缀大 2dp。
     * 发布版自己就是 16/18 两套并存，所以这里**保留两个具名档**而不是把 16 改成 18——
     * 改动面最小、两处各自对齐自己的发布版出处；数值钉死，不开放调用方自由传尺寸。
     */
    val InlineLargeSize = 18.dp

    /** 档 B 图标位替换。 */
    val IconSlotSize = 18.dp

    /** 档 B 极小角标。 */
    val BadgeSize = 14.dp

    /** 档 B 统一线宽。 */
    val InlineStrokeWidth = 2.dp

    /** 档 C 整块遮罩 / 下载中。 */
    val ScrimSize = 28.dp

    /** 档 C 卡片内排队中。 */
    val QueuedSize = 24.dp

    /** 档 C 缩略图格。 */
    val ThumbnailSize = 18.dp

    /**
     * 行首方块位（取件码页「跳转中」）：22dp。
     *
     * 证据不是 v2.1.4.1——这一页是 tag 之后（2026-10-20 `2ae5eb28c`）才加的：
     * 发布版删 Dart 层前的 `lib/screens/pickup_codes_screen.dart`（`303220db1^`）写的是
     * `SizedBox(22×22) + CircularProgressIndicator(strokeWidth: 2.2, color: accent)`。
     */
    val AccentGlyphSize = 22.dp

    /** 行首方块位线宽。 */
    val AccentGlyphStrokeWidth = 2.2.dp
}

/** 档 B 的四个槽位：尺寸不同是因为构图位置不同，不是随便挑一个。 */
enum class QingyuLoadingSlot(val size: Dp, val strokeWidth: Dp) {
    /** 按钮内（文字左侧），16dp：云同步 / 导入 / WebDAV 那一族。 */
    Button(QingyuLoadingDefaults.InlineSize, QingyuLoadingDefaults.InlineStrokeWidth),

    /**
     * 按钮内的**大档**，18dp：发布版页脚栏忙态（`settings_holiday.dart:777-798`）。
     *
     * 与 [IconSlot] 数值相同（都是 18/2）但**语义不同**：这一档吃按钮内容色
     * （走 [QingyuLoadingInButtonLarge]），[IconSlot] 是替换一个图标位、走主题色。
     * 分开列是为了让后来者一眼看出「按钮内不要直接套图标槽」。
     */
    ButtonLarge(QingyuLoadingDefaults.InlineLargeSize, QingyuLoadingDefaults.InlineStrokeWidth),

    /** 替换掉一个 24dp 图标的位置。 */
    IconSlot(QingyuLoadingDefaults.IconSlotSize, QingyuLoadingDefaults.InlineStrokeWidth),

    /** 行尾的极小角标。 */
    Badge(QingyuLoadingDefaults.BadgeSize, QingyuLoadingDefaults.InlineStrokeWidth),

    /**
     * 行首方块位（22 / 2.2）：颜色跟着该行的 accent，不是主题色。
     *
     * 这个槽位**不能**用 [QingyuLoadingInline]——那里不许传颜色；走 [QingyuLoadingAccentGlyph]。
     */
    AccentGlyph(QingyuLoadingDefaults.AccentGlyphSize, QingyuLoadingDefaults.AccentGlyphStrokeWidth),
}

/**
 * 档 A · 居中加载：首载、手上没有任何内容可显示时用。
 *
 * 用法分两种载体：
 * - [fillPage] = true（默认）：整页内容区居中，对应发布版 `Center(HyperosCircularProgress())`；
 * - [fillPage] = false：列表项 / 卡片内居中，高度取 [QingyuLoadingDefaults.BlockMinHeight]，
 *   对应发布版 `SliverFillRemaining(hasScrollBody: false)` + `_bodyArea`。
 *
 * **有缓存/旧数据时不要用它**：显示旧数据 + 一行来路说明，是本仓与发布版都认可的另一种口径
 * （`ContributorsPage` 的「已有缓存时后台还在刷新」、`BingGalleryHost` 的「显示的是上次加载的图」）。
 */
@Composable
fun QingyuLoadingCenter(
    modifier: Modifier = Modifier,
    fillPage: Boolean = true,
) {
    val container = if (fillPage) {
        modifier.fillMaxSize()
    } else {
        modifier.fillMaxWidth().heightIn(min = QingyuLoadingDefaults.BlockMinHeight)
    }
    Box(modifier = container, contentAlignment = Alignment.Center) {
        CircularProgressIndicator(
            size = QingyuLoadingDefaults.PageSize,
            strokeWidth = QingyuLoadingDefaults.PageStrokeWidth,
        )
    }
}

/**
 * 档 B · 行内加载（非按钮槽位）。
 *
 * **不开放颜色参数**：走官方主题色（`primary`），与发布版 `HyperosCircularProgress(size: 16)`
 * 不传色时的长相一致。2026-11-10 Chief 复核裁定「档 B 一律不传 tint」——发布版图标位是裸
 * `HyperosCircularProgress(18, 2)`，让转圈跟同排灰图标同色属于观感升级、不由 lane 自定；
 * 留一个参数就是留一个口子，守卫 `pages/loading/QingyuLoadingUsageGuardTest` 也按此拦。
 *
 * 两个唯一例外，各有专用入口：
 * - 按钮内 → [QingyuLoadingInButton]（必须跟按钮内容色，否则蓝底蓝圈看不见）；
 * - 取件码行首方块位 → [QingyuLoadingAccentGlyph]（跟该行 accent，发布版原样）。
 */
@Composable
fun QingyuLoadingInline(
    modifier: Modifier = Modifier,
    slot: QingyuLoadingSlot = QingyuLoadingSlot.Button,
) {
    QingyuLoadingIndicator(modifier = modifier, slot = slot, tint = null)
}

/**
 * 套件内部实现：**唯一**允许指定颜色的地方。
 *
 * `private` 是刻意的——公开入口只有 `QingyuLoadingInline`（无颜色）/`QingyuLoadingInButton`/
 * `QingyuLoadingAccentGlyph` 三个，颜色语义各归其位，不给调用方随便传色。
 */
@Composable
private fun QingyuLoadingIndicator(
    modifier: Modifier,
    slot: QingyuLoadingSlot,
    tint: Color?,
) {
    CircularProgressIndicator(
        modifier = modifier,
        colors = if (tint == null) {
            ProgressIndicatorDefaults.progressIndicatorColors()
        } else {
            ProgressIndicatorDefaults.progressIndicatorColors(foregroundColor = tint)
        },
        strokeWidth = slot.strokeWidth,
        size = slot.size,
    )
}

/**
 * 档 B′ · 行首方块位的加载圈（取件码页「跳转中」）：22dp / 2.2 线宽 / **该行 accent 色**。
 *
 * 为什么单独一个入口、不复用 [QingyuLoadingInline]：这里的颜色不是主题色，也不是「同排图标同色」
 * 那种观感升级，而是与行首方块同一个 accent（`pickupCodeAccentFor(context, entry.id)`）；
 * 底环必须透明——发布版 `CircularProgressIndicator(strokeWidth: 2.2, color: accent)` 只有一圈前景色，
 * 而 miuix 默认还会画底环。参数只有一个 [accent]，其余数值钉死在
 * [QingyuLoadingDefaults.AccentGlyphSize] / [QingyuLoadingDefaults.AccentGlyphStrokeWidth]，不开放随意传参。
 */
@Composable
fun QingyuLoadingAccentGlyph(
    accent: Color,
    modifier: Modifier = Modifier,
) {
    CircularProgressIndicator(
        modifier = modifier,
        colors = ProgressIndicatorDefaults.progressIndicatorColors(
            foregroundColor = accent,
            backgroundColor = Color.Transparent,
        ),
        strokeWidth = QingyuLoadingDefaults.AccentGlyphStrokeWidth,
        size = QingyuLoadingDefaults.AccentGlyphSize,
    )
}

/**
 * 档 B · 按钮内的加载圈（文字左侧，调用方在它后面补 8dp 间距）。
 *
 * 颜色取 `LocalContentColor`：miuix `Button` 已经在内部把 `LocalContentColor` 设成
 * `colors.contentColor` / `colors.disabledContentColor`（`third_party/miuix-ui/.../Button.kt:71-72`），
 * 所以主色按钮上拿到的是 `onPrimary`（白），不会再出现「蓝底蓝圈看不见」；
 * 按钮禁用时跟着降到禁用内容色，与文字同色。
 */
@Composable
fun QingyuLoadingInButton(modifier: Modifier = Modifier) {
    QingyuLoadingIndicator(
        modifier = modifier,
        slot = QingyuLoadingSlot.Button,
        tint = LocalContentColor.current,
    )
}

/**
 * 档 B · **按钮内大档**（18dp / 2dp）：发布版页脚栏忙态那一颗
 * （`settings_holiday.dart:777-798`，`SizedBox(18×18) + CircularProgressIndicator(strokeWidth: 2)`）。
 *
 * 与 [QingyuLoadingInButton] 唯一的区别是直径；颜色同样取 `LocalContentColor`，
 * 所以主色底上是白圈、禁用时跟禁用内容色。
 *
 * 为什么不让调用方传尺寸（评审三-08 的收口要求）：一旦开放 `size` 参数，16/18/20 会重新长回来，
 * D1 又回到改造前的样子。**要新尺寸 = 在 [QingyuLoadingSlot] 里加一档并写清发布版出处**。
 */
@Composable
fun QingyuLoadingInButtonLarge(modifier: Modifier = Modifier) {
    QingyuLoadingIndicator(
        modifier = modifier,
        slot = QingyuLoadingSlot.ButtonLarge,
        tint = LocalContentColor.current,
    )
}

/**
 * 档 C · 局部遮罩转圈：细环 + 绕行小圆点（`InfiniteProgressIndicator`）。
 *
 * 发布版对「不知道还剩多久」的场景（加载罩、下载中、排队、缩略图还没到）一律用这个长相，
 * 不是扫弧。扫弧在那种场合「更像进度条在跳」（`hyperos_progress.dart:41-44` 的原话）。
 *
 * [color] 没有默认值是有意的：官方默认是写死的灰（`ProgressIndicator.kt:222`），
 * 压暗底上必须自己给白，否则暗色主题下看不见。
 */
@Composable
fun QingyuLoadingScrim(
    color: Color,
    modifier: Modifier = Modifier,
    size: Dp = QingyuLoadingDefaults.ScrimSize,
) {
    InfiniteProgressIndicator(
        modifier = modifier,
        color = color,
        size = size,
    )
}

/**
 * 档 D · 确定性进度条：文案由调用方放在上方（发布版 `home_update_prompt.dart:623-667`），
 * 条高不传（走官方默认 6dp，`ProgressIndicator.kt:323`）。
 *
 * **没有 `failed` 参数，是刻意的**（2026-11-10 评审 D1-4 + Chief 裁决「不给死参数」）：
 * 本仓的下载失败路径不在进度条上表达——`AboutUpdateHost.kt:280-284` 收到 `STATUS_FAILED`
 * 就关弹窗 + Toast `systemDownloaderFailed` + `appendLog("warn", DOWNLOAD_FAILED)`，
 * 入队失败同样 toast。用户能感知、日志留痕，与发布版「弹窗内进度条当场变红」**等价**，
 * 只是载体不同。既然模型层没有失败态可传，就不留一个永远 false 的参数。
 * 将来若真要在条上表达失败（发布版那套红条），先补模型的失败字段与宿主接线，再开参数。
 */
@Composable
fun QingyuLoadingProgressBar(
    progress: Float?,
    modifier: Modifier = Modifier,
) {
    LinearProgressIndicator(
        modifier = modifier,
        progress = progress,
        colors = ProgressIndicatorDefaults.progressIndicatorColors(),
    )
}
