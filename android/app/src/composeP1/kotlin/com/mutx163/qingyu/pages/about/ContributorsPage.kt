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
 * 本渲染层只按 [maintainers] / [isLoading] / [error] / [cachedAt] 四态画，不自己发网络——
 * 2026-10-29（F09）起宿主是 [ContributorsHostPage]：读 `index/root_index.yaml` +
 * 每校 `adapters.yaml`（见 `WarehouseMaintainersFeed`），缓存优先、后台刷新、失败可重试。
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
    /**
     * 当前展示的名单是**缓存**时，这份缓存被写入的时刻（已格式化，见
     * `formatMaintainersCacheTime`）。null = 展示的是刚拉到的数据。
     *
     * 为什么必须有这个参数：缓存优先 + 后台刷新的页面，用户看到「有名单」并不等于
     * 「刚刚拉到」；不标时间就等于把昨天的名单当成今天的结果（F09 验收第一条）。
     */
    cachedAt: String? = null,
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
                        // 缓存时间：只在「正在显示上次缓存」时出现，后台刷新成功后本行自动消失。
                        cachedAt?.let { time ->
                            Text(
                                text = ContributorsStrings.cachedAtLabel(time),
                                style = MiuixTheme.textStyles.footnote2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                        when {
                            // 「转圈」只用于**手上什么都没有**的时候。已有缓存时后台还在刷新：
                            // 继续显示旧数据，靠上面那行缓存时间说明它有多旧——本页自己的说明句
                            // 就写着「若本地已有缓存，会先显示缓存，再后台刷新」，被转圈盖住等于说话不算数。
                            isLoading && groups.isEmpty() -> Row(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                                horizontalArrangement = Arrangement.Center,
                            ) {
                                CircularProgressIndicator()
                            }

                            error != null && groups.isEmpty() -> Column(
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    text = ContributorsStrings.loadFailed(error),
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.error(dark)),
                                )
                                TextButton(
                                    text = ContributorsStrings.reloadAction,
                                    onClick = onReload,
                                )
                            }

                            groups.isEmpty() -> Text(
                                text = ContributorsStrings.maintainersEmpty,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )

                            else -> {
                                // 有缓存但刷新失败：名单照常显示（比空屏有用），但要如实说明
                                // 「这次没拉到」并给重试，不许让旧数据冒充刚刷新的结果。
                                if (error != null) {
                                    Text(
                                        text = ContributorsStrings.loadFailed(error),
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = Color(QingyuTheme.error(dark)),
                                    )
                                    TextButton(
                                        text = ContributorsStrings.reloadAction,
                                        onClick = onReload,
                                    )
                                }
                                for (group in groups) {
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
