package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 自定义脚本调试记录管理页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_custom_debug_screen.dart`：
 * 1. 顶部栏返回与新增记录动作；
 * 2. 调试说明卡片；
 * 3. 调试记录卡片列表（名称、脚本字符数、自定义登录入口、执行/编辑/删除按钮）；
 * 4. 内嵌新增/编辑表单。
 */
@Composable
fun WarehouseCustomDebugPage(
    records: List<WarehouseCustomDebugRecord> = emptyList(),
    onBack: () -> Unit = {},
    onRunDebug: (WarehouseCustomDebugRecord) -> Unit = {},
    onSaveRecord: (WarehouseCustomDebugRecord) -> Boolean = { false },
    onDeleteRecord: (String) -> Unit = {},
    /**
     * 「开始调试」按钮显隐开关（2026-11-05 死控件收口，默认 `false` = 隐藏）。
     *
     * 为什么默认隐藏：Kotlin 侧脚本引擎（F08-8c）未移植，宿主 [WarehouseCustomDebugHost]
     * 对 `onRunDebug` 只能给「诚实失败」Toast——按钮留着就是一颗**点了必失败**的按钮。
     * 等价于 Dart 侧「无引擎时隐藏入口」的口径，宿主无法从外部隐藏（按钮在本页）。
     *
     * 将来接了脚本引擎怎么恢复：宿主把 `onRunDebug` 接到真执行链路后，调用处传
     * `showRunButton = true` 即可重新渲染按钮；本页无需再改（排版按三钮 weight 自动回满）。
     */
    showRunButton: Boolean = false,
) {
    var editingRecord by remember { mutableStateOf<WarehouseCustomDebugRecord?>(null) }
    var isAddingNew by remember { mutableStateOf(false) }

    var formName by remember { mutableStateOf("") }
    var formScript by remember { mutableStateOf("") }
    var formUrl by remember { mutableStateOf("") }
    var formError by remember { mutableStateOf<String?>(null) }

    fun openEditor(record: WarehouseCustomDebugRecord?) {
        editingRecord = record
        isAddingNew = record == null
        formName = record?.name.orEmpty()
        formScript = record?.script.orEmpty()
        formUrl = record?.customUrl.orEmpty()
        formError = null
    }

    fun submitForm() {
        val recordToValidate = WarehouseCustomDebugRecord(
            id = editingRecord?.id ?: java.util.UUID.randomUUID().toString(),
            name = formName,
            script = formScript,
            customUrl = formUrl.ifBlank { null }
        )
        val err = recordToValidate.validate()
        if (err != null) {
            formError = if (err == WarehouseStrings.debugRecordNameRequired.key) {
                WarehouseStrings.debugRecordNameRequired.zh
            } else {
                WarehouseStrings.debugScriptRequired.zh
            }
            return
        }
        // 真落盘成功才收起表单：写失败时留在原地并给出「保存失败」，不让用户以为存上了。
        if (!onSaveRecord(recordToValidate)) {
            formError = WarehouseStrings.saveFailed.zh
            return
        }
        editingRecord = null
        isAddingNew = false
    }

    // 骨架 / 顶栏 / 返回键走共享套件（R1），页面级滚动走 QingyuPageList（R2）：
    // 编辑表单与记录列表同处一个惰性列表，长记录列表不再整页逐项组合。
    QingyuPageScaffold(
        title = WarehouseStrings.warehouseCustomDebugTitle.zh,
        onBack = onBack,
        actions = {
            IconButton(onClick = { openEditor(null) }) {
                Icon(imageVector = MiuixIcons.Add, contentDescription = WarehouseStrings.addDebugRecordTooltip.zh)
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            if (isAddingNew || editingRecord != null) {
                // 编辑表单卡片
                item(key = "editor") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 12.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = if (isAddingNew) WarehouseStrings.addDebugRecordTitle.zh else WarehouseStrings.editDebugRecordTitle.zh,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            TextField(
                                value = formName,
                                onValueChange = { formName = it },
                                modifier = Modifier.fillMaxWidth(),
                                label = WarehouseStrings.debugRecordNameHint.zh,
                                useLabelAsPlaceholder = true,
                                singleLine = true,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            TextField(
                                value = formUrl,
                                onValueChange = { formUrl = it },
                                modifier = Modifier.fillMaxWidth(),
                                label = "登录入口地址（可选，https://...）",
                                useLabelAsPlaceholder = true,
                                singleLine = true,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            TextField(
                                value = formScript,
                                onValueChange = { formScript = it },
                                modifier = Modifier.fillMaxWidth(),
                                label = WarehouseStrings.debugScriptHint.zh,
                                useLabelAsPlaceholder = true,
                                minLines = 4,
                                maxLines = 10,
                            )

                            if (formError != null) {
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = formError!!,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.error,
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Button(
                                    onClick = {
                                        editingRecord = null
                                        isAddingNew = false
                                    },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.cancelAction.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                    ),
                                )
                                Button(
                                    onClick = ::submitForm,
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.saveDebugRecordAction.zh) },
                                )
                            }
                        }
                    }
                }
            }

            // 调试记录列表
            if (records.isEmpty() && !isAddingNew && editingRecord == null) {
                item(key = "empty") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = WarehouseStrings.noSavedDebugRecords.zh,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = WarehouseStrings.noSavedDebugRecordsHint.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = { openEditor(null) },
                                content = { Text(text = WarehouseStrings.addDebugRecordAction.zh) },
                            )
                        }
                    }
                }
            } else {
                items(records, key = { it.id }) { record ->
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .padding(top = 12.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = record.name,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = WarehouseStrings.debugScriptLength.filled("length", record.scriptLength.toString()),
                                style = MiuixTheme.textStyles.footnote1,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )
                            if (!record.customUrl.isNullOrBlank()) {
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = "入口：${record.customUrl}",
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.primary,
                                )
                            }

                            Spacer(modifier = Modifier.height(12.dp))
                            HorizontalDivider()
                            Spacer(modifier = Modifier.height(10.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                // 「开始调试」默认不渲染（脚本引擎 F08-8c 未移植，点了必失败）；
                                // 恢复方式见本页 [showRunButton] 参数的 KDoc。隐藏时其余两钮
                                // 借三钮布局的 weight 自动铺满整行，无需另调排版。
                                if (showRunButton) {
                                    Button(
                                        onClick = { onRunDebug(record) },
                                        modifier = Modifier.weight(1.2f),
                                        content = { Text(text = WarehouseStrings.startDebugAction.zh) },
                                    )
                                }
                                Button(
                                    onClick = { openEditor(record) },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.editAction.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.primary,
                                    ),
                                )
                                Button(
                                    onClick = { onDeleteRecord(record.id) },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.deleteAction.zh) },
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
        }
    }
}
