package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
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
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = WarehouseStrings.adapterInfoTitle.zh,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(imageVector = MiuixIcons.Back, contentDescription = WarehouseStrings.cancelAction.zh)
                    }
                }
            )
        },
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MiuixTheme.colorScheme.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                Button(
                    onClick = onOpenWebLogin,
                    modifier = Modifier.fillMaxWidth(),
                    text = WarehouseStrings.openLoginInAppAction.zh
                )
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 元数据卡片
            item(key = "meta_card") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = adapter.adapterName,
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = school.name,
                            fontSize = 14.sp,
                            color = MiuixTheme.colorScheme.primary,
                            fontWeight = FontWeight.Medium
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
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                        ) {
                            Text(
                                text = "使用说明",
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 15.sp
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = adapter.description,
                                fontSize = 13.sp,
                                color = MiuixTheme.colorScheme.onSurfaceVariant,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
            }

            // 自定义登录入口地址卡片
            item(key = "custom_url_card") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = WarehouseStrings.customLoginAddressAction.zh,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = if (isCustomized) WarehouseStrings.adapterOverrideImportUrlHint.zh else "可覆盖默认登录地址（如学校内网或 VPN 登录页）",
                            fontSize = 12.sp,
                            color = if (isCustomized) MiuixTheme.colorScheme.primary else MiuixTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        TextField(
                            value = editUrl,
                            onValueChange = { editUrl = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = adapter.importUrl.ifEmpty { "https://..." },
                            singleLine = true,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Button(
                                onClick = { onSaveCustomUrl(editUrl) },
                                modifier = Modifier.weight(1f),
                                text = WarehouseStrings.saveAction.zh
                            )
                            if (isCustomized) {
                                Button(
                                    onClick = {
                                        editUrl = ""
                                        onClearCustomUrl()
                                    },
                                    modifier = Modifier.weight(1f),
                                    text = WarehouseStrings.clearCustomLoginAddressAction.zh,
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.error
                                    )
                                )
                            }
                        }
                    }
                }
            }

            // 快捷复制卡片
            item(key = "links_card") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = "链接与调试",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Button(
                                onClick = onCopyLoginUrl,
                                modifier = Modifier.weight(1f),
                                text = WarehouseStrings.copyLoginAddressAction.zh,
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
                                    contentColor = MiuixTheme.colorScheme.primary
                                )
                            )
                            Button(
                                onClick = onCopyScriptUrl,
                                modifier = Modifier.weight(1f),
                                text = WarehouseStrings.copyScriptAddressAction.zh,
                                colors = ButtonDefaults.buttonColors(
                                    color = MiuixTheme.colorScheme.surfaceVariant,
                                    contentColor = MiuixTheme.colorScheme.primary
                                )
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
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            color = MiuixTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium
        )
    }
}
