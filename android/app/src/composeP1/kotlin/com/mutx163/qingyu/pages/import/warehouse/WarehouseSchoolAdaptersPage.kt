package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
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
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 学校适配器列表页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_school_adapters_screen.dart`：
 * 1. 学校概览卡片（学校名、所属省份、分类）；
 * 2. 适配器卡片流（脚本名、分类/维护者元数据、描述说明）；
 * 3. 动作按钮：网页登录导入、宏录制导入、适配器详情、一键快捷导入。
 */
@Composable
fun WarehouseSchoolAdaptersPage(
    school: WarehouseSchoolEntry,
    adapters: List<WarehouseAdapterEntry> = emptyList(),
    macroMap: Map<String, Boolean> = emptyMap(),
    onBack: () -> Unit = {},
    onRefresh: () -> Unit = {},
    onImportAdapter: (WarehouseAdapterEntry) -> Unit = {},
    onRecordAdapter: (WarehouseAdapterEntry) -> Unit = {},
    onViewAdapterDetail: (WarehouseAdapterEntry) -> Unit = {},
    onQuickImportAdapter: (WarehouseAdapterEntry) -> Unit = {},
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = school.name,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(imageVector = MiuixIcons.Back, contentDescription = WarehouseStrings.cancelAction.zh)
                    }
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.zh)
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 学校概览卡片
            item(key = "school_header") {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(MiuixTheme.colorScheme.primary.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = school.initial.ifEmpty { "学" },
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 18.sp,
                                    color = MiuixTheme.colorScheme.primary
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = school.name,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 17.sp
                                )
                                if (school.province.isNotEmpty()) {
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = school.province,
                                        fontSize = 13.sp,
                                        color = MiuixTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // 适配器列表
            if (adapters.isEmpty()) {
                item(key = "empty_adapters") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = WarehouseStrings.warehouseAdaptersLoadFailedTitle.zh,
                                fontWeight = FontWeight.Medium,
                                fontSize = 15.sp,
                                color = MiuixTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                items(adapters, key = { it.id }) { adapter ->
                    val hasMacro = macroMap[adapter.id] ?: false
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                        ) {
                            Text(
                                text = adapter.adapterName,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "${WarehouseStrings.categoryLabel.zh}：${adapter.category} · ${WarehouseStrings.maintainerLabel.zh}：${adapter.maintainer.ifEmpty { "社区" }}",
                                fontSize = 12.sp,
                                color = MiuixTheme.colorScheme.onSurfaceVariant
                            )

                            if (adapter.description.isNotBlank()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = adapter.description,
                                    fontSize = 13.sp,
                                    color = MiuixTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 3,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            // 动作按钮组
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Button(
                                    onClick = { onImportAdapter(adapter) },
                                    modifier = Modifier.weight(1f),
                                    text = WarehouseStrings.webLoginImport.zh
                                )
                                Button(
                                    onClick = { onRecordAdapter(adapter) },
                                    modifier = Modifier.weight(1f),
                                    text = WarehouseStrings.recordImportAction.zh,
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.primary
                                    )
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                if (hasMacro) {
                                    Button(
                                        onClick = { onQuickImportAdapter(adapter) },
                                        text = WarehouseStrings.quickImportAction.zh,
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.primary.copy(alpha = 0.12f),
                                            contentColor = MiuixTheme.colorScheme.primary
                                        )
                                    )
                                } else {
                                    Spacer(modifier = Modifier.width(1.dp))
                                }

                                Button(
                                    onClick = { onViewAdapterDetail(adapter) },
                                    text = WarehouseStrings.viewDetailsAction.zh,
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
}
