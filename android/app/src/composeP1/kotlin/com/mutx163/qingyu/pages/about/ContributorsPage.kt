package com.mutx163.qingyu.pages.about

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.infra.MaintainerGroup
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 代码贡献者页 · Compose 渲染层（2026-10-28 新建）。
 *
 * 对照 Flutter `ContributorsScreen`（`about_screen.dart:2291-2557`）：
 * 开发人员卡 + 教务导入适配者卡（加载/失败/空/分组）+ 参与适配卡（打开适配仓 / 复制地址）。
 *
 * ## 数据从哪来
 *
 * 与 Flutter 一致：适配者名单由宿主提供（Flutter 是网络拉取 + 本地缓存）。
 * 本渲染层只按 [maintainers] / [isLoading] / [error] 三态画，不自己发网络——
 * Compose 侧目前还没有移植 `WarehouseRepositoryService`（见本轮审计报告），
 * 待适配仓服务接线后由宿主喂真数据。现在宿主喂空列表时，页面显示 Flutter 同款空态文案。
 *
 * ## 文案纪律
 *
 * 无中文字面量，全部取自 main 层 [ContributorsStrings]。
 */
@Composable
fun ContributorsPage(
    maintainers: List<MaintainerGroup>,
    isLoading: Boolean,
    error: String?,
    onBack: () -> Unit,
    onReload: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val groups = sortedContributorGroups(maintainers)

    QingyuPageScaffold(title = ContributorsStrings.screenTitle, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // ── 开发人员 ──
            item { QingyuSectionTitle(ContributorsStrings.developersTitle) }
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    ContributorRow(
                        name = ContributorsStrings.developerName,
                        subtitle = ContributorsStrings.developerSubtitle,
                    )
                }
            }

            // ── 教务导入适配者 ──
            item { QingyuSectionTitle(ContributorsStrings.maintainersTitle) }
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = ContributorsStrings.maintainersIntro,
                            style = MiuixTheme.textStyles.footnote1,
                            lineHeight = 19.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        when {
                            isLoading -> Row(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                                horizontalArrangement = Arrangement.Center,
                            ) {
                                CircularProgressIndicator()
                            }

                            error != null && groups.isEmpty() -> Text(
                                text = ContributorsStrings.loadFailed(error),
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.error(dark)),
                            )

                            groups.isEmpty() -> Text(
                                text = ContributorsStrings.maintainersEmpty,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )

                            else -> for (group in groups) {
                                ContributorRow(
                                    name = group.name,
                                    subtitle = ContributorsStrings.maintainerCount(group.adapterLabels.size),
                                    details = group.adapterLabels,
                                )
                            }
                        }
                    }
                }
            }

            // ── 参与适配 ──
            item { QingyuSectionTitle(ContributorsStrings.participateTitle) }
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(
                            text = ContributorsStrings.participateSubtitle,
                            style = MiuixTheme.textStyles.footnote1,
                            lineHeight = 20.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Button(
                                onClick = { openUrl(context, ContributorsStrings.warehouseRepoUrl) },
                                colors = ButtonDefaults.buttonColors(),
                            ) {
                                Text(ContributorsStrings.openWarehouseRepoAction)
                            }
                            TextButton(
                                text = ContributorsStrings.copyAddress,
                                onClick = {
                                    copyToClipboard(context, ContributorsStrings.warehouseRepoUrl)
                                    Toast.makeText(
                                        context,
                                        ContributorsStrings.copiedAddress,
                                        Toast.LENGTH_SHORT,
                                    ).show()
                                },
                                colors = ButtonDefaults.textButtonColors(),
                            )
                        }
                    }
                }
            }
        }
    }
}

/** 一行贡献者：名字 + 副标题 +（可选）适配项 bullet 列表。 */
@Composable
private fun ContributorRow(
    name: String,
    subtitle: String,
    details: List<String> = emptyList(),
) {
    val dark = isSystemInDarkTheme()
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = name,
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.SemiBold,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Text(
            text = subtitle,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        for (detail in details) {
            Text(
                text = "• $detail",
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

/** 用系统浏览器打开一个外部链接。 */
private fun openUrl(context: Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

/** 复制文本到剪贴板。 */
private fun copyToClipboard(context: Context, text: String) {
    val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    manager?.setPrimaryClip(ClipData.newPlainText("", text))
}
