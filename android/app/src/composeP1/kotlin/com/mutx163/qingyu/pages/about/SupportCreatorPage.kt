package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 支持作者页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/support_creator_screen.dart`：紧凑头图 + 收款方式卡 +
 * 鸣谢名单。结构与文案在 main 源集的 [SupportDonorData] / [SupportCreatorStrings]。
 *
 * ## 组件选择
 *
 * Scaffold / Card / Text / CircularProgressIndicator 全部官方 `miuix.kmp.basic.*`；
 * 收款方式切换用两枚 Card 按钮拼「分段控件」（0.8.8 没有 preference 模块，也没有
 * 官方 SegmentedControl 对应物，这里不画控件、只用官方 Card 的按压反馈）。
 *
 * ## 已知未接线（不假装完成）
 *
 * 二维码图与「保存到相册」依赖 Flutter 侧 `bundled_assets`（资产在 Flutter 资产目录，
 * 不在 Android res/）；本批只落结构与交互入口，图片加载与相册写入留 Phase 4
 * 的原生能力对齐一起做。因此这里 [onSaveQr] 只是回调，不落盘。
 */
@Composable
fun SupportCreatorPage(
    donorData: SupportDonorData?,
    onBack: () -> Unit,
    onReload: () -> Unit,
    onSaveQr: () -> Unit,
    isLoading: Boolean = false,
    loadError: String? = null,
) {
    var method by remember { mutableStateOf(SupportMethod.WECHAT) }
    val colors = MiuixTheme.colorScheme

    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "返回",
                    fontSize = 15.sp,
                    color = colors.primary,
                    modifier = Modifier.clickable { onBack() },
                )
                Text(
                    text = SupportCreatorStrings.heroTitle,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                )
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                // ── 紧凑头图：标题 + 副标题 + 三个能力胶囊 ──
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = SupportCreatorStrings.heroTitle,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = colors.onSurface,
                            )
                            Text(
                                text = SupportCreatorStrings.heroSubtitle,
                                fontSize = 13.sp,
                                lineHeight = 19.sp,
                                color = colors.onSurfaceVariantSummary,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                FeatureChip(SupportCreatorStrings.chipAdapters)
                                FeatureChip(SupportCreatorStrings.chipFixes)
                                FeatureChip(SupportCreatorStrings.chipPolish)
                            }
                        }
                    }
                }

                // ── 收款方式卡 ──
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = SupportCreatorStrings.methodTitle,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = colors.onSurface,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                MethodTab(
                                    label = SupportCreatorStrings.wechatLabel,
                                    selected = method == SupportMethod.WECHAT,
                                    onClick = { method = SupportMethod.WECHAT },
                                )
                                MethodTab(
                                    label = SupportCreatorStrings.alipayLabel,
                                    selected = method == SupportMethod.ALIPAY,
                                    onClick = { method = SupportMethod.ALIPAY },
                                )
                            }
                            Text(
                                text = SupportCreatorStrings.scanTitleFor(method),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = colors.onSurface,
                            )
                            Text(
                                text = SupportCreatorStrings.scanQrSubtitle,
                                fontSize = 12.sp,
                                color = colors.onSurfaceVariantSummary,
                            )
                            // 二维码位：图未接线（见文件头 kdoc），先占位保持版式与文案。
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .aspectRatio(1f),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = SupportCreatorStrings.hintFor(method),
                                    fontSize = 13.sp,
                                    textAlign = TextAlign.Center,
                                    color = colors.onSurfaceVariantSummary,
                                )
                            }
                            Text(
                                text = SupportCreatorStrings.tapQrHint,
                                fontSize = 12.sp,
                                color = colors.onSurfaceVariantSummary,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                MethodTab(
                                    label = SupportCreatorStrings.saveShort,
                                    selected = false,
                                    onClick = onSaveQr,
                                )
                                MethodTab(
                                    label = SupportCreatorStrings.saveToGallery,
                                    selected = false,
                                    onClick = onSaveQr,
                                )
                            }
                        }
                    }
                }

                // ── 鸣谢名单 ──
                item {
                    Text(
                        text = SupportCreatorStrings.donorListTitle,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.onSurface,
                    )
                }

                when {
                    isLoading -> item {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                            horizontalArrangement = Arrangement.Center,
                        ) {
                            CircularProgressIndicator()
                        }
                    }

                    loadError != null -> item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(14.dp),
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(
                                    text = SupportCreatorStrings.donorListLoadFailed,
                                    fontSize = 13.sp,
                                    color = colors.onSurfaceVariantSummary,
                                )
                                Text(
                                    text = SupportCreatorStrings.reloadAction,
                                    fontSize = 14.sp,
                                    color = colors.primary,
                                    modifier = Modifier.clickable { onReload() },
                                )
                            }
                        }
                    }

                    donorData == null || donorData.donors.isEmpty() -> item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(14.dp),
                        ) {
                            Text(
                                text = SupportCreatorStrings.donorListEmpty,
                                fontSize = 13.sp,
                                lineHeight = 19.sp,
                                color = colors.onSurfaceVariantSummary,
                            )
                        }
                    }

                    else -> {
                        donorData.updatedAt?.takeIf { it.isNotEmpty() }?.let { updatedAt ->
                            item {
                                Text(
                                    text = SupportCreatorStrings.updatedAtLabel(updatedAt),
                                    fontSize = 12.sp,
                                    color = colors.onSurfaceVariantSummary,
                                )
                            }
                        }
                        items(donorData.donors) { donor -> DonorRow(donor) }
                    }
                }
            }
        }
    }
}

/** 能力胶囊（Dart `_FeatureCapsule`）。 */
@Composable
private fun FeatureChip(label: String) {
    val colors = MiuixTheme.colorScheme
    Card(insideMargin = PaddingValues(horizontal = 10.dp, vertical = 6.dp)) {
        Text(
            text = label,
            fontSize = 12.sp,
            color = colors.onSurfaceVariantSummary,
        )
    }
}

/** 收款方式/操作按钮：官方 Card 承载，选中态用强调色文字区分。 */
@Composable
private fun MethodTab(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.clickable { onClick() },
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) colors.primary else colors.onSurface,
        )
    }
}

/** 名单一行：名字 + 金额/日期 + 留言。 */
@Composable
private fun DonorRow(donor: SupportDonorEntry) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = donor.name,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = colors.onSurface,
                )
                donor.amount?.takeIf { it.isNotEmpty() }?.let { amount ->
                    Text(
                        text = amount,
                        fontSize = 13.sp,
                        color = colors.primary,
                    )
                }
            }
            val meta = listOfNotNull(
                donor.date?.takeIf { it.isNotEmpty() },
                donor.message?.takeIf { it.isNotEmpty() },
            ).joinToString(" · ")
            if (meta.isNotEmpty()) {
                Text(
                    text = meta,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    color = colors.onSurfaceVariantSummary,
                )
            }
        }
    }
}
