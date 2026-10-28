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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import com.mutx163.qingyu.components.QingyuBackIconButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
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
    onSaveRecord: (WarehouseCustomDebugRecord) -> Unit = {},
    onDeleteRecord: (String) -> Unit = {},
) {
    var editingRecord by remember { mutableStateOf<WarehouseCustomDebugRecord?>(null) }
    var isAddingNew by remember { mutableStateOf(false) }
    // Dart warehouse_custom_debug_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    val scrollBehavior = MiuixScrollBehavior()

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
        onSaveRecord(recordToValidate)
        editingRecord = null
        isAddingNew = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = WarehouseStrings.warehouseCustomDebugTitle.zh,
                largeTitle = WarehouseStrings.warehouseCustomDebugTitle.zh,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    QingyuBackIconButton(
                        onBack = onBack,
                        contentDescription = WarehouseStrings.cancelAction.zh,
                    )
                },
                actions = {
                    IconButton(onClick = { openEditor(null) }) {
                        Icon(imageVector = MiuixIcons.Add, contentDescription = WarehouseStrings.addDebugRecordTooltip.zh)
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (isAddingNew || editingRecord != null) {
                // 编辑表单卡片
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = if (isAddingNew) WarehouseStrings.addDebugRecordTitle.zh else WarehouseStrings.editDebugRecordTitle.zh,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
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
                                color = MiuixTheme.colorScheme.error,
                                fontSize = 12.sp
                            )
                        }

                        Spacer(modifier = Modifier.height(14.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
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
                                    contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions
                                )
                            )
                            Button(
                                onClick = ::submitForm,
                                modifier = Modifier.weight(1f),
                                content = { Text(text = WarehouseStrings.saveDebugRecordAction.zh) }
                            )
                        }
                    }
                }
            }

            // 调试记录列表
            if (records.isEmpty() && !isAddingNew && editingRecord == null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = WarehouseStrings.noSavedDebugRecords.zh,
                            fontWeight = FontWeight.Medium,
                            fontSize = 15.sp,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = WarehouseStrings.noSavedDebugRecordsHint.zh,
                            fontSize = 12.sp,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = { openEditor(null) },
                            content = { Text(text = WarehouseStrings.addDebugRecordAction.zh) }
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .nestedScroll(scrollBehavior.nestedScrollConnection),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                        bottom = innerPadding.calculateBottomPadding() + 8.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(records, key = { it.id }) { record ->
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp)
                            ) {
                                Text(
                                    text = record.name,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = WarehouseStrings.debugScriptLength.filled("length", record.scriptLength.toString()),
                                    fontSize = 12.sp,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                                )
                                if (!record.customUrl.isNullOrBlank()) {
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = "入口：${record.customUrl}",
                                        fontSize = 12.sp,
                                        color = MiuixTheme.colorScheme.primary
                                    )
                                }

                                Spacer(modifier = Modifier.height(12.dp))
                                HorizontalDivider()
                                Spacer(modifier = Modifier.height(10.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Button(
                                        onClick = { onRunDebug(record) },
                                        modifier = Modifier.weight(1.2f),
                                        content = { Text(text = WarehouseStrings.startDebugAction.zh) }
                                    )
                                    Button(
                                        onClick = { openEditor(record) },
                                        modifier = Modifier.weight(1f),
                                        content = { Text(text = WarehouseStrings.editAction.zh) },
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.surfaceVariant,
                                            contentColor = MiuixTheme.colorScheme.primary
                                        )
                                    )
                                    Button(
                                        onClick = { onDeleteRecord(record.id) },
                                        modifier = Modifier.weight(1f),
                                        content = { Text(text = WarehouseStrings.deleteAction.zh) },
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
            }
        }
    }
}
