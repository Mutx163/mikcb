package com.mutx163.qingyu.pages.feedback

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
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
 * - Scaffold / Card / Text / Icon / IconButton / HorizontalDivider 全部官方 Miuix；
 * - 返回与复制用官方图标 `MiuixIcons.Back` / `MiuixIcons.Copy`
 *   （依赖 `miuix-icons-android:0.8.8`，用户 2026-10-26 批准）；
 * - **品牌徽标暂用占位**：原图是 Flutter 资产（github/xiaohongshu/qq 是 SVG），
 *   Compose 侧没有 SVG 渲染器、也不应读 `assets/flutter_assets`（Phase 5 会删），
 *   这里画同尺寸品牌色圆角方块 + 标题首字，等 Phase 4 换真图。资产路径已记录在
 *   [FeedbackBadge.assetPath]，换图时按图索骥。
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

    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            // ── 标题栏：返回 + 标题 ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack, backgroundColor = Color.Transparent) {
                    Icon(
                        imageVector = MiuixIcons.Back,
                        contentDescription = "返回",
                        tint = colors.onBackground,
                    )
                }
                Text(
                    text = view.title,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                // 单个列表组（Dart 侧 HyperosListGroup 只放这一组）。
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    // 行内边距由每行自己给（水平 16 / 垂直 13）。
                    insideMargin = PaddingValues(0.dp),
                ) {
                    Column {
                        view.channels.forEachIndexed { index, channel ->
                            if (index > 0) {
                                HorizontalDivider(
                                    modifier = Modifier.padding(start = 16.dp),
                                    thickness = 0.75.dp,
                                    color = colors.dividerLine,
                                )
                            }
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
                fontSize = 17.sp,
                color = colors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = channel.subtitle,
                fontSize = 14.sp,
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
 * 品牌徽标占位：26dp 圆角方块（7dp 圆角 = `HyperosTokens.iconBadgeRadius` 比例）。
 *
 * 有品牌底色时用它并自动选黑白字；没有时跟随主题卡面。字母取标题首字
 * （GitHub→G、小红书→小、酷安→酷、QQ→Q、微信公众号→微），仅为占位可读，
 * **不是最终视觉**——Phase 4 换回 `assets/branding/…` 真图。
 */
@Composable
private fun BrandBadge(channel: FeedbackChannel) {
    val colors = MiuixTheme.colorScheme
    val background = channel.badge.backgroundColorHex
        ?.let { runCatching { Color(android.graphics.Color.parseColor(it)) }.getOrNull() }
        ?: colors.surfaceContainer
    val letterColor = if (background.luminance() > 0.5f) Color.Black else Color.White

    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(RoundedCornerShape(7.dp))
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = channel.title.take(1),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = letterColor,
        )
    }
}
