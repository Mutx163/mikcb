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
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
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
                WarehouseStrings.debugRecordNameRequired.text
            } else {
                WarehouseStrings.debugScriptRequired.text
            }
            return
        }
        // 真落盘成功才收起表单：写失败时留在原地并给出「保存失败」，不让用户以为存上了。
        if (!onSaveRecord(recordToValidate)) {
            formError = WarehouseStrings.saveFailed.text
            return
        }
        editingRecord = null
        isAddingNew = false
    }

    // 骨架 / 顶栏 / 返回键走共享套件（R1），页面级滚动走 QingyuPageList（R2）：
    // 编辑表单与记录列表同处一个惰性列表，长记录列表不再整页逐项组合。
    QingyuPageScaffold(
        title = WarehouseStrings.warehouseCustomDebugTitle.text,
        onBack = onBack,
        actions = {
            IconButton(onClick = { openEditor(null) }) {
                Icon(imageVector = MiuixIcons.Add, contentDescription = WarehouseStrings.addDebugRecordTooltip.text)
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
                                text = if (isAddingNew) WarehouseStrings.addDebugRecordTitle.text else WarehouseStrings.editDebugRecordTitle.text,
                                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            TextField(
                                value = formName,
                                onValueChange = { formName = it },
                                modifier = Modifier.fillMaxWidth(),
                                label = WarehouseStrings.debugRecordNameHint.text,
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
                                label = WarehouseStrings.debugScriptHint.text,
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
                                    content = { Text(text = WarehouseStrings.cancelAction.text) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.secondary,
                                        contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                    ),
                                )
                                Button(
                                    onClick = ::submitForm,
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.saveDebugRecordAction.text) },
                                )
                            }
                        }
                    }
                }
            }

            // 调试记录列表
            if (records.isEmpty() && !isAddingNew && editingRecord == null) {
                item(key = "empty") {
                    // C20：统一空态组件（发布版 `HyperosEmptyState` 几何：图标 48dp、标题 17sp、
                    // 说明 14sp、外边距 32/48，不再自拼 Box + 两行不同字阶的 Text）。
                    QingyuEmptyState(
                        icon = MiuixIcons.Add,
                        title = WarehouseStrings.noSavedDebugRecords.text,
                        description = WarehouseStrings.noSavedDebugRecordsHint.text,
                        action = {
                            Button(
                                onClick = { openEditor(null) },
                                content = { Text(text = WarehouseStrings.addDebugRecordAction.text) },
                            )
                        },
                    )
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
                                        content = { Text(text = WarehouseStrings.startDebugAction.text) },
                                    )
                                }
                                Button(
                                    onClick = { openEditor(record) },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.editAction.text) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.secondary,
                                        contentColor = MiuixTheme.colorScheme.primary,
                                    ),
                                )
                                Button(
                                    onClick = { onDeleteRecord(record.id) },
                                    modifier = Modifier.weight(1f),
                                    content = { Text(text = WarehouseStrings.deleteAction.text) },
                                    // 发布版这一颗是 `HyperosButtonVariant.destructive`，即
                                    // `error` 底 + `onError` 字（实心红，`hyperos_controls.dart`
                                    // 的 HyperosButton destructive 分支）；红字 + 淡红水洗是首页
                                    // 磨砂面板那条 `HyperosFrostedSheetButton` 的形制，不适用于此。
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.error,
                                        contentColor = MiuixTheme.colorScheme.onError,
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄）：主题包 `QingyuPageTheme(isDark = …)`，
// 字号用 `textScale = …`（不用 `@Preview(fontScale = …)`），宽度 400dp 是本仓折行实测口径。
//
// 本页只有「有记录 / 空态」两帧静态形态；编辑表单是页面内 `remember` 的开关，
// 从外面顶不进去——要看表单与报错请用交互预览或真机。
// ─────────────────────────────────────────────────────────────────────────────

/**
 * 预览用：两条调试记录。
 *
 * 第二条带自定义入口地址，用来确认「入口：https://…」那一行会出现、且长地址不把卡片撑爆。
 */
private fun previewDebugRecords(): List<WarehouseCustomDebugRecord> = listOf(
    WarehouseCustomDebugRecord(
        id = "preview-record-1",
        name = "示例大学 · 本科教务",
        script = "// 预览用占位脚本，不执行。真实脚本由用户从适配仓录制或粘贴。",
        customUrl = "https://jw.example.edu.cn/login",
    ),
    WarehouseCustomDebugRecord(
        id = "preview-record-2",
        name = "示例学院 · 研究生教务",
        script = "// 预览用占位脚本，不执行。",
        customUrl = null,
    ),
)

/** 一档预览的公共身体：记录数据 + 外观档位。 */
@Composable
private fun PreviewWarehouseCustomDebugPage(
    records: List<WarehouseCustomDebugRecord>,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        WarehouseCustomDebugPage(
            records = records,
            onBack = {},
            onRunDebug = { _ -> },
            onSaveRecord = { _ -> true },
            onDeleteRecord = { _ -> },
            // 「开始调试」默认不渲染（脚本引擎未移植，点了必失败），预览也按宿主的真实取值。
            showRunButton = false,
        )
    }
}

@Suppress("unused")
@Preview(name = "1 有记录", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCustomDebugPagePreviewRecords() {
    PreviewWarehouseCustomDebugPage(previewDebugRecords())
}

@Suppress("unused")
@Preview(name = "2 空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCustomDebugPagePreviewEmpty() {
    PreviewWarehouseCustomDebugPage(emptyList())
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCustomDebugPagePreviewDark() {
    PreviewWarehouseCustomDebugPage(previewDebugRecords(), dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCustomDebugPagePreviewLargeText() {
    PreviewWarehouseCustomDebugPage(previewDebugRecords(), textScale = 1.3f)
}
