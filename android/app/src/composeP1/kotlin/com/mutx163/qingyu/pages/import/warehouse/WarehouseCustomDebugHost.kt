package com.mutx163.qingyu.pages.import.warehouse

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
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
 * | 开始调试 | **诚实失败**：脚本引擎（F08-8c）未移植，Toast「执行失败：不可用」，原因进 Log。⚠️ 按钮本体渲染在 [WarehouseCustomDebugPage]（另一泳道文件），宿主侧隐藏不了——2026-11-05 死控件收口时已把「隐藏入口」的诉求记录在此：引擎移植前这个按钮点了必失败，正确做法是在页面里给 [WarehouseCustomDebugPage.onRunDebug] 加 `showRunButton` 一类开关（默认 false）由宿主关掉；接引擎时删开关、接真执行 |
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
                // ⚠️ 按钮本体在 WarehouseCustomDebugPage（非本泳道文件），无法从宿主侧隐藏；
                // 隐藏方案见本文件头 KDoc「开始调试」行——引擎移植前它就是一颗点了必失败的按钮。
                Log.w(
                    CUSTOM_DEBUG_LOG_TAG,
                    "script execution unavailable record=${record.id} (engine not ported, F08-8c)",
                )
                Toast.makeText(
                    context,
                    WarehouseStrings.executeFailedWithError.filled(
                        "error",
                        SettingsStrings.aboutUnavailable.text,
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
        // 退场动画期间保留最后一份非空记录：pendingDelete 置 null 触发关闭时，
        // 正文若直接跟着读 null 会塌成「删除「」？」——审核报告 P3（旧 :119）的
        // 「空板退场」。弹层常驻组合，show 仍由 pendingDelete 驱动。
        var shownDelete by remember { mutableStateOf<WarehouseCustomDebugRecord?>(null) }
        if (target != null) shownDelete = target
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = target != null,
            title = WarehouseStrings.deleteDebugRecordTitle.text,
            onDismissRequest = { pendingDelete = null },
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = WarehouseStrings.deleteDebugRecordMessage.filled(
                        "name",
                        shownDelete?.name.orEmpty(),
                    ),
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    lineHeight = 20.sp,
                )
                Spacer(modifier = Modifier.height(16.dp))
                // 两动作横排等宽（取消在左、删除在右），与 Dart `HyperosDialog` 的两动作行
                // 一致；改用 TextButton——原来两颗 surfaceVariant 实心按钮在深色下与对话框底
                // 同为 #242424，按钮边界直接消失，取消字色还是 40% 透明的
                // onSurfaceVariantActions（审核报告 P2 旧 :126）。
                // 删除 = destructive：中性底 + 危险色字；`textButtonColors(color = …)` 的
                // `color` 是**底色**位（会得到整颗红底 + 灰字），所以用 `textColor`。
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = WarehouseStrings.cancelAction.text,
                        onClick = { pendingDelete = null },
                    )
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = WarehouseStrings.deleteAction.text,
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
                                    Toast.makeText(context, WarehouseStrings.saveFailed.text, Toast.LENGTH_SHORT).show()
                                }
                            }
                        },
                        colors = ButtonDefaults.textButtonColors(
                            textColor = Color(QingyuTheme.error(isSystemInDarkTheme())),
                        ),
                    )
                }
            }
        }
    }
}
