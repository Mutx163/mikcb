package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 适配器详情页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_adapter_detail_screen.dart`：
 * 1. 适配器元数据卡片（名称、分类、维护者、学校代码）；
 * 2. 脚本使用说明与描述；
 * 3. 自定义登录入口地址覆盖编辑与恢复；
 * 4. 复制地址、脚本链接及直接拉起网页登录。
 */
@Composable
fun WarehouseAdapterDetailPage(
    school: WarehouseSchoolEntry,
    adapter: WarehouseAdapterEntry,
    customImportUrl: String? = null,
    onBack: () -> Unit = {},
    onSaveCustomUrl: (String) -> Unit = {},
    onClearCustomUrl: () -> Unit = {},
    onCopyLoginUrl: () -> Unit = {},
    onCopyScriptUrl: () -> Unit = {},
    onOpenWebLogin: () -> Unit = {},
) {
    var editUrl by remember(customImportUrl) { mutableStateOf(customImportUrl ?: "") }
    val isCustomized = !customImportUrl.isNullOrBlank()

    // Dart warehouse_adapter_detail_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    // 骨架、顶栏、返回键统一走共享套件（R1）；滚动走 QingyuPageList（R2）。
    QingyuPageScaffold(
        title = WarehouseStrings.adapterInfoTitle.zh,
        onBack = onBack,
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MiuixTheme.colorScheme.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                Button(
                    onClick = onOpenWebLogin,
                    modifier = Modifier.fillMaxWidth(),
                    content = { Text(text = WarehouseStrings.openLoginInAppAction.zh) },
                )
            }
        },
    ) { innerPadding, scrollBehavior ->
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            // 元数据卡片
            item(key = "meta_card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    // 卡片里是普通内容（非 Preference 行），内边距必须自己给。
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = adapter.adapterName,
                            style = MiuixTheme.textStyles.title4,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = school.name,
                            style = MiuixTheme.textStyles.body2,
                            color = MiuixTheme.colorScheme.primary,
                            fontWeight = FontWeight.Medium,
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        HorizontalDivider()
                        Spacer(modifier = Modifier.height(12.dp))

                        DetailMetaRow(WarehouseStrings.categoryLabel.zh, adapter.category)
                        Spacer(modifier = Modifier.height(6.dp))
                        DetailMetaRow(WarehouseStrings.maintainerLabel.zh, adapter.maintainer.ifEmpty { "社区成员" })
                        if (adapter.schoolCode.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(6.dp))
                            DetailMetaRow("学校代码", adapter.schoolCode)
                        }
                    }
                }
            }

            // 说明卡片
            if (adapter.description.isNotBlank()) {
                item(key = "desc_card") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = "使用说明",
                                style = MiuixTheme.textStyles.body1,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = adapter.description,
                                style = MiuixTheme.textStyles.footnote1,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                lineHeight = 18.sp,
                            )
                        }
                    }
                }
            }

            // 自定义登录入口地址卡片
            item(key = "custom_url_card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = WarehouseStrings.customLoginAddressAction.zh,
                            style = MiuixTheme.textStyles.body1,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = if (isCustomized) WarehouseStrings.adapterOverrideImportUrlHint.zh else "可覆盖默认登录地址（如学校内网或 VPN 登录页）",
                            style = MiuixTheme.textStyles.footnote1,
                            color = if (isCustomized) MiuixTheme.colorScheme.primary else MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        TextField(
                            value = editUrl,
                            onValueChange = { editUrl = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = adapter.importUrl.ifEmpty { "https://..." },
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Button(
                                onClick = { onSaveCustomUrl(editUrl) },
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.saveAction.zh) },
                            )
                            if (isCustomized) {
                                Button(
                                    onClick = {
                                        editUrl = ""
                                        onClearCustomUrl()
                                    },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.clearCustomLoginAddressAction.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.error,
                                    ),
                                )
                            }
                        }
                    }
                }
            }

            // 快捷复制卡片
            item(key = "links_card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "链接与调试",
                            style = MiuixTheme.textStyles.body1,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Button(
                                onClick = onCopyLoginUrl,
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.copyLoginAddressAction.zh) },
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
                                    contentColor = MiuixTheme.colorScheme.primary,
                                ),
                            )
                            Button(
                                onClick = onCopyScriptUrl,
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.copyScriptAddressAction.zh) },
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
                                    contentColor = MiuixTheme.colorScheme.primary,
                                ),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailMetaRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote1,
            fontWeight = FontWeight.Medium,
        )
    }
}
