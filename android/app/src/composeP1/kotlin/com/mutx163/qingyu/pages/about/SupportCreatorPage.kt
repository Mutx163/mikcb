package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 支持作者页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/support_creator_screen.dart`：紧凑头图 + 收款方式卡 +
 * 鸣谢名单。结构与文案在 main 源集的 [SupportDonorData] / [SupportCreatorStrings]。
 *
 * 骨架与行走 [QingyuPageScaffold] / [QingyuRow]；收款方式切换用官方 [Card] 的
 * 可点击重载（带按压反馈）拼「分段控件」——0.8.8 没有官方 SegmentedControl 对应物，
 * 这里不画控件，只用官方卡片的按压态。
 *
 * ## 已知未接线（不假装完成）
 *
 * 二维码图与「保存到相册」依赖 Flutter 侧 `bundled_assets`（资产在 Flutter 资产目录，
 * 不在 Android res/）；本批只落结构与交互入口，图片加载与相册写入留 Phase 4
 * 的原生能力对齐一起做。因此 [onSaveQr] 只是回调，不落盘。
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
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(title = SupportCreatorStrings.heroTitle, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 官方配方：横向留白由卡片自己带（12dp），滚动条才贴得到屏幕边缘。
            horizontalPadding = QingyuPageCardMargin,
            // 底部手势条那段由 QingyuPageList 内部按 innerPadding 算
            //（等价于原先手写的 innerPadding.calculateBottomPadding()），
            // 这里只补额外的滚动留白，避免重复相加。
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // ── 紧凑头图：副标题 + 三个能力胶囊 ──
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(14.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = SupportCreatorStrings.heroSubtitle,
                            style = MiuixTheme.textStyles.footnote1,
                            lineHeight = 19.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
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
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(14.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = SupportCreatorStrings.methodTitle,
                            style = MiuixTheme.textStyles.body2,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
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
                            style = MiuixTheme.textStyles.body2,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Text(
                            text = SupportCreatorStrings.scanQrSubtitle,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        // 二维码位：图未接线（见文件头 kdoc），先占位保持版式与文案。
                        Box(
                            modifier = Modifier.fillMaxWidth().aspectRatio(1f),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = SupportCreatorStrings.hintFor(method),
                                style = MiuixTheme.textStyles.footnote1,
                                textAlign = TextAlign.Center,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                        Text(
                            text = SupportCreatorStrings.tapQrHint,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
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

            item { QingyuSectionTitle(SupportCreatorStrings.donorListTitle) }

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
                    QingyuRow(
                        title = SupportCreatorStrings.donorListLoadFailed,
                        icon = {
                            Icon(
                                imageVector = MiuixIcons.Refresh,
                                contentDescription = null,
                                tint = Color(QingyuIconColors.ORANGE),
                            )
                        },
                        onClick = onReload,
                    )
                }

                donorData == null || donorData.donors.isEmpty() -> item {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Text(
                            text = SupportCreatorStrings.donorListEmpty,
                            style = MiuixTheme.textStyles.footnote1,
                            lineHeight = 19.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                }

                else -> {
                    donorData.updatedAt?.takeIf { it.isNotEmpty() }?.let { updatedAt ->
                        item {
                            Text(
                                text = SupportCreatorStrings.updatedAtLabel(updatedAt),
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(start = 4.dp),
                            )
                        }
                    }
                    items(donorData.donors) { donor -> DonorRow(donor) }
                }
            }
        }
    }
}

/** 能力胶囊（Dart `_FeatureCapsule`）。 */
@Composable
private fun FeatureChip(label: String) {
    val dark = isSystemInDarkTheme()
    QingyuCard(insideMargin = PaddingValues(horizontal = 10.dp, vertical = 6.dp)) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/** 收款方式/操作按钮：官方 Card 可点击重载，选中态用强调色区分。 */
@Composable
private fun MethodTab(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
        onClick = onClick,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) {
                Color(QingyuTheme.primary(dark = dark))
            } else {
                Color(QingyuTheme.primaryText(dark))
            },
        )
    }
}

/** 名单一行：名字 + 金额/日期/留言。 */
@Composable
private fun DonorRow(donor: SupportDonorEntry) {
    val dark = isSystemInDarkTheme()
    val meta = listOfNotNull(
        donor.amount?.takeIf { it.isNotEmpty() },
        donor.date?.takeIf { it.isNotEmpty() },
        donor.message?.takeIf { it.isNotEmpty() },
    ).joinToString(" · ")

    QingyuRow(
        title = donor.name,
        subtitle = meta.takeIf { it.isNotEmpty() },
        icon = {
            Icon(
                imageVector = MiuixIcons.Favorites,
                contentDescription = null,
                tint = Color(QingyuIconColors.YELLOW),
            )
        },
    )
}
