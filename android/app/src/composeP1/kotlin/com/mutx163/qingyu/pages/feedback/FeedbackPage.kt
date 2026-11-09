package com.mutx163.qingyu.pages.feedback

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.R
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 问题反馈页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/feedback_screen.dart`：一个列表组里五个渠道行
 * （品牌徽标 + 标题 + 副标题 + 右侧复制按钮），点行打开、点复制按钮复制。
 *
 * ## 分层
 *
 * 本文件在 **composeP1** 源集；渠道清单/文案/URL 顺序/打开语义都在 main 源集的
 * `FeedbackModel.kt`（纯 Kotlin，可用 `runFeedbackOpenPlan` 单测顺序与回落）。
 *
 * ## 组件与已知差异
 *
 * - Scaffold / Card / Text / Icon / IconButton 走官方 Miuix；两张多色 PNG 徽标用
 *   Compose 官方 `Image`（Miuix `Icon` 的 KDoc 明确建议多色图用 `Image`，避免被染色）；
 * - 返回键由共享骨架 `QingyuPageScaffold` 提供；复制用官方图标 `MiuixIcons.Copy`
 *   （依赖 `miuix-icons-android:0.8.8`，用户 2026-10-26 批准）；
 * - **品牌徽标用 Flutter 真图**：github/xiaohongshu/qq 三张 SVG 已转成
 *   `res/drawable/ic_brand_*.xml` 单色 vector，coolapk/launcher_icon 两张 PNG 放在
 *   `res/drawable-nodpi/`；`BrandBadge` 用 `painterResource` 画，并按 Dart 原版补 1dp 描边。
 *   不再画首字占位，也不读 `assets/flutter_assets`。
 * - Toast/剪贴板/拉起外部应用属宿主能力：本页只回调
 *   [onCopyChannel] / [onOpenChannel]，宿主用 `channel.copyToast` 与
 *   `runFeedbackOpenPlan` 决定提示与回落。
 */
@Composable
fun FeedbackPage(
    view: FeedbackPageView = buildFeedbackPageView(),
    onBack: () -> Unit,
    onOpenChannel: (FeedbackChannel) -> Unit = {},
    onCopyChannel: (FeedbackChannel) -> Unit = {},
) {
    val colors = MiuixTheme.colorScheme

    QingyuPageScaffold(title = view.title, onBack = onBack, smallTopBar = true) {
        // 滚动走官方配方（QingyuPageList：末端轻震 + 过度滚动 + 顶栏联动 + 右侧滚动条）；
        // 页面横向 16dp 由 horizontalPadding 给，卡片内边距交给每行自己。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = 16.dp,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            item(key = "channels") {
                // 单个列表组（Dart 侧 HyperosListGroup 只放这一组）。
                QingyuCard(modifier = Modifier.fillMaxWidth()) {
                    Column {
                        view.channels.forEachIndexed { index, channel ->
                            FeedbackChannelRow(
                                channel = channel,
                                onOpen = { onOpenChannel(channel) },
                                onCopy = { onCopyChannel(channel) },
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 一个渠道行：品牌徽标 + 标题/副标题 + 复制按钮。
 *
 * 原 Dart `_FeedbackChannelTile`（`feedback_screen.dart:272-331`）：
 * 行最小高 56、左徽标 26、标题 17、副标题 14、右侧复制按钮。
 */
@Composable
private fun FeedbackChannelRow(
    channel: FeedbackChannel,
    onOpen: () -> Unit,
    onCopy: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpen() }
            .padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        BrandBadge(channel = channel)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = channel.title,
                style = MiuixTheme.textStyles.main,
                color = colors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = channel.subtitle,
                style = MiuixTheme.textStyles.body2,
                color = colors.onSurfaceVariantSummary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        IconButton(onClick = onCopy, backgroundColor = Color.Transparent) {
            Icon(
                imageVector = MiuixIcons.Copy,
                contentDescription = "复制 ${channel.copyValue}",
                tint = colors.onSurfaceVariantActions,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

/**
 * 品牌徽标：26dp 圆角方块（7dp 圆角 = `HyperosTokens.iconBadgeRadius` 比例）。
 *
 * 内容用 Flutter 那套真图：GitHub / QQ / 小红书是单色 SVG 转的 vector，用 [Icon] 染色；
 * 酷安、微信公众号是 PNG，用 [Image] 原样画。底色按 Flutter 原样：
 * GitHub / QQ / 微信公众号白底 + 品牌色标，小红书红底白标，酷安绿底白标；
 * 深色下白底也保持白色，避免 GitHub 黑标落在深色卡面上看不见。
 * 1dp 描边（浅色黑 8% / 深色白 12%）补齐 Dart `_FeedbackBrandBadge` 的边。
 */
@Composable
private fun BrandBadge(channel: FeedbackChannel) {
    val colors = MiuixTheme.colorScheme
    val badge = channel.badge
    val background = badge.backgroundColorHex
        ?.let { runCatching { Color(android.graphics.Color.parseColor(it)) }.getOrNull() }
        ?: colors.surfaceContainer
    val tint = badge.tintHex
        ?.let { runCatching { Color(android.graphics.Color.parseColor(it)) }.getOrNull() }
        ?: Color.Unspecified
    val shape = RoundedCornerShape(7.dp)
    val borderColor = colors.onSurface.copy(
        alpha = if (isSystemInDarkTheme()) 0.12f else 0.08f,
    )
    val drawable = brandDrawableFor(badge.assetPath)

    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(shape)
            .background(background)
            .border(1.dp, borderColor, shape),
        contentAlignment = Alignment.Center,
    ) {
        when {
            drawable == null -> Text(
                text = channel.title.take(1),
                style = MiuixTheme.textStyles.footnote1
                    .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = if (background.luminance() > 0.5f) Color.Black else Color.White,
            )
            badge.isSvg -> Icon(
                painter = painterResource(drawable),
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(14.dp),
            )
            else -> Image(
                painter = painterResource(drawable),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                contentScale = ContentScale.Fit,
            )
        }
    }
}

/** Flutter `assets/branding/…` 到 Compose drawable 的映射；未登记的新渠道回落首字。 */
private fun brandDrawableFor(assetPath: String): Int? = when (assetPath) {
    "assets/branding/github.svg" -> R.drawable.ic_brand_github
    "assets/branding/xiaohongshu.svg" -> R.drawable.ic_brand_xiaohongshu
    "assets/branding/coolapk.png" -> R.drawable.brand_coolapk
    "assets/branding/qq.svg" -> R.drawable.ic_brand_qq
    "assets/branding/launcher_icon.png" -> R.drawable.brand_launcher_icon
    else -> null
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照抄 about/ContributorsPage.kt 的样板）
//
// 只给实现阶段看效果，不进业务路径。本页是静态渠道清单，只有「有渠道 / 渠道为空」
// 两种数据形态，所以铺：默认清单、空清单 + 亮色 / 暗色 / 大字号 1.3 三档外观。
//
// 固定写法（与样板一致，别自己改）：
//   • 主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }：页面取色走
//     isSystemInDarkTheme()，只有它会改写 LocalConfiguration 的 uiMode，预览才和真机同口径；
//   • 字号用 QingyuPageTheme(textScale = …)，不要用 @Preview(fontScale = …)；
//   • 宽度按 400dp（本仓折行实测口径），高度给一屏多。
//
// 注意：渠道徽标现在是品牌色方块 + 标题首字的占位（真图等 Phase 4），预览里看到的
// 方块就是当前实现，不是渲染失败。
// ─────────────────────────────────────────────────────────────────────────────

/** 空清单：页面里那排渠道行整块消失，用来确认空态不会画出一张空卡片。 */
private fun previewFeedbackEmptyView(): FeedbackPageView = FeedbackPageView(
    title = FeedbackStrings.title,
    channels = emptyList(),
)

/** 一档预览的公共身体：数据形态 + 外观档位。 */
@Composable
private fun PreviewFeedbackPage(
    view: FeedbackPageView = buildFeedbackPageView(),
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        FeedbackPage(
            view = view,
            onBack = {},
            onOpenChannel = {},
            onCopyChannel = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 五个渠道", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewFeedbackChannels() {
    PreviewFeedbackPage()
}

@Suppress("unused")
@Preview(name = "2 渠道为空", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewFeedbackEmpty() {
    PreviewFeedbackPage(previewFeedbackEmptyView())
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewFeedbackDark() {
    PreviewFeedbackPage(dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewFeedbackLargeText() {
    PreviewFeedbackPage(textScale = 1.3f)
}
