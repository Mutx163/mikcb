package com.mutx163.qingyu.pages.import.warehouse

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

private const val CUSTOM_DEBUG_LOG_TAG = "WarehouseCustomDebugHost"

/**
 * 自定义调试页的**真宿主**（`g2.customDebug`）。
 *
 * ## 每个按钮的落点
 *
 * | 控件 | 真落点 |
 * |---|---|
 * | 保存调试记录 | [WarehouseCustomDebugStore.save] → 盘上 `warehouse_custom_debug_records`（键与 JSON 形状和 Dart 逐字一致） |
 * | 删除 | 官方 [OverlayDialog] 先确认 → [WarehouseCustomDebugStore.delete] → Toast「已删除调试记录：…」 |
 * | 开始调试 | **诚实失败**：脚本引擎（F08-8c）未移植，Toast「执行失败：不可用」，原因进 Log |
 * | 列表读取 | 进页读一次盘；保存/删除后就地刷新 |
 *
 * ## 诚实边界
 *
 * - 「开始调试」没有假装成功：Dart 那边是在 WebView 里注入记录里的脚本抓课表，
 *   Kotlin 的脚本引擎还没移植（与 `WarehouseImportHosts` 的诚实边界同一条），
 *   所以这里只能明确报「不可用」。
 * - 保存是同步 `commit()` 落盘（[PrefsKeyValueStore] 的实现口径），因此页面能在
 *   写失败时留在表单上并显示「保存失败」，而不是先收起表单再悄悄丢数据。
 * - 真机未对照：本刀只证明 JVM 单测与代码可读；用户需在开发壳里新增/删除一条记录
 *   并杀进程重开，确认记录还在。
 */
@Composable
fun WarehouseCustomDebugHost(onBack: () -> Unit) {
    val context = LocalContext.current
    val store = remember(context) { WarehouseCustomDebugStore(PrefsKeyValueStore(context)) }

    var records by remember { mutableStateOf<List<WarehouseCustomDebugRecord>>(emptyList()) }
    var pendingDelete by remember { mutableStateOf<WarehouseCustomDebugRecord?>(null) }
    var reloadToken by remember { mutableStateOf(0) }

    LaunchedEffect(reloadToken) {
        records = withContext(Dispatchers.IO) {
            runCatching { store.load() }.getOrElse { error ->
                Log.w(CUSTOM_DEBUG_LOG_TAG, "records load failed: ${error.message}")
                emptyList()
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        WarehouseCustomDebugPage(
            records = records,
            onBack = onBack,
            onRunDebug = { record ->
                // 脚本引擎未移植（F08-8c）：不假装执行成功，给一句明确的失败原因。
                Log.w(
                    CUSTOM_DEBUG_LOG_TAG,
                    "script execution unavailable record=${record.id} (engine not ported, F08-8c)",
                )
                Toast.makeText(
                    context,
                    WarehouseStrings.executeFailedWithError.filled(
                        "error",
                        SettingsStrings.aboutUnavailable.zh,
                    ),
                    Toast.LENGTH_SHORT,
                ).show()
            },
            onSaveRecord = { record ->
                val saved = runCatching { store.save(record) }.getOrElse { error ->
                    Log.w(CUSTOM_DEBUG_LOG_TAG, "save failed id=${record.id}: ${error.message}")
                    false
                }
                if (saved) {
                    records = runCatching { store.load() }.getOrDefault(records)
                }
                saved
            },
            onDeleteRecord = { recordId ->
                pendingDelete = records.firstOrNull { it.id == recordId }
            },
        )

        val target = pendingDelete
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = target != null,
            title = WarehouseStrings.deleteDebugRecordTitle.zh,
            onDismissRequest = { pendingDelete = null },
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = WarehouseStrings.deleteDebugRecordMessage.filled(
                        "name",
                        target?.name.orEmpty(),
                    ),
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    lineHeight = 20.sp,
                )
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = {
                        val record = pendingDelete
                        pendingDelete = null
                        if (record != null) {
                            val deleted = runCatching { store.delete(record.id) }.getOrElse { error ->
                                Log.w(
                                    CUSTOM_DEBUG_LOG_TAG,
                                    "delete failed id=${record.id}: ${error.message}",
                                )
                                false
                            }
                            if (deleted) {
                                records = runCatching { store.load() }.getOrDefault(
                                    records.filterNot { it.id == record.id },
                                )
                                Toast.makeText(
                                    context,
                                    WarehouseStrings.deletedDebugRecord.filled("name", record.name),
                                    Toast.LENGTH_SHORT,
                                ).show()
                            } else {
                                Toast.makeText(context, WarehouseStrings.saveFailed.zh, Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    content = { Text(WarehouseStrings.deleteAction.zh) },
                    colors = ButtonDefaults.buttonColors(
                        color = MiuixTheme.colorScheme.surfaceVariant,
                        contentColor = MiuixTheme.colorScheme.error,
                    ),
                )
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = { pendingDelete = null },
                    modifier = Modifier.fillMaxWidth(),
                    content = { Text(WarehouseStrings.cancelAction.zh) },
                    colors = ButtonDefaults.buttonColors(
                        color = MiuixTheme.colorScheme.surfaceVariant,
                        contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                    ),
                )
            }
        }
    }
}
