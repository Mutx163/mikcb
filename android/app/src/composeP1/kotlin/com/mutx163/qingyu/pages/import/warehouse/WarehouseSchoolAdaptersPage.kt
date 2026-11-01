package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
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
    /**
     * 这一屏当前处于什么相位（8b 接真数据源时新增）。
     *
     * 默认 [WarehouseListPhase.Idle]：还没接数据层的调用点传空列表，行为与改动前一致
     * （空列表 = 「暂时无法读取适配器列表」）。宿主接了真仓库后必须传 Loading / Failed，
     * 否则「还在请求」和「请求失败」都会显示成同一句空态，用户不知道该不该等。
     */
    phase: WarehouseListPhase = WarehouseListPhase.Idle,
    onRetry: () -> Unit = onRefresh,
) {
    // Dart warehouse_school_adapters_screen.dart 的 HyperosSubpage 标题是学校名 Text ⇒ 可折叠大标题。
    // 骨架 / 顶栏 / 返回键走共享套件（R1），页面级滚动走 QingyuPageList（R2）。
    QingyuPageScaffold(
        title = school.name,
        onBack = onBack,
        actions = {
            IconButton(onClick = onRefresh) {
                Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.zh)
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            // 学校概览卡片
            item(key = "school_header") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(MiuixTheme.colorScheme.primary.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = school.initial.ifEmpty { "学" },
                                    style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
                                    color = MiuixTheme.colorScheme.primary,
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = school.name,
                                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                                )
                                if (school.province.isNotEmpty()) {
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = school.province,
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
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
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            if (phase == WarehouseListPhase.Loading) {
                                // 请求还在路上：转圈，不写「读不到」——那会把「等一下」说成「坏了」。
                                CircularProgressIndicator()
                            } else {
                                Text(
                                    text = WarehouseStrings.warehouseAdaptersLoadFailedTitle.zh,
                                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                )
                                if (phase == WarehouseListPhase.Failed) {
                                    // 真失败才给重试；Idle 是「调用方没接数据层」，给重试按钮没有意义。
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Button(
                                        onClick = onRetry,
                                        content = { Text(text = WarehouseStrings.reloadAction.zh) },
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.primary.copy(alpha = 0.12f),
                                            contentColor = MiuixTheme.colorScheme.primary,
                                        ),
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                items(adapters, key = { it.id }) { adapter ->
                    val hasMacro = macroMap[adapter.id] ?: false
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 12.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = adapter.adapterName,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "${WarehouseStrings.categoryLabel.zh}：${adapter.category} · ${WarehouseStrings.maintainerLabel.zh}：${adapter.maintainer.ifEmpty { "社区" }}",
                                style = MiuixTheme.textStyles.footnote1,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )

                            if (adapter.description.isNotBlank()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = adapter.description,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                    maxLines = 3,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            // 动作按钮组
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Button(
                                    onClick = { onImportAdapter(adapter) },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.webLoginImport.zh) },
                                )
                                Button(
                                    onClick = { onRecordAdapter(adapter) },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.recordImportAction.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.primary,
                                    ),
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                if (hasMacro) {
                                    Button(
                                        onClick = { onQuickImportAdapter(adapter) },
                                        content = { Text(text = WarehouseStrings.quickImportAction.zh) },
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.primary.copy(alpha = 0.12f),
                                            contentColor = MiuixTheme.colorScheme.primary,
                                        ),
                                    )
                                } else {
                                    Spacer(modifier = Modifier.width(1.dp))
                                }

                                Button(
                                    onClick = { onViewAdapterDetail(adapter) },
                                    content = { Text(text = WarehouseStrings.viewDetailsAction.zh) },
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
}
