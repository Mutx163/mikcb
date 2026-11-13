package com.mutx163.qingyu.pages.import.warehouse

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.BuildConfig
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

private const val LOG_TAG = "WarehouseImportLogPage"

/**
 * 教务导入执行日志面板（**只读**）。
 *
 * ## 这一页只做四件事
 *
 * 取快照铺列表、把 [LogEmphasis] 映射成主题颜色、横向滚动、复制/分享。
 * **分组与行格式全部在 [WarehouseImportLogView]（main，L0 可测）**——本文件再拼一次 `RUN n`、
 * 再排一次 `ts category k=v` 就会让那部分退回「只有真机能验」，源码守卫
 * `WarehouseImportLogEntryGuardTest` 因此禁止本文件出现组头拼接与 `.runs` 遍历。
 *
 * ## 为什么行是单行 + 横向滚动
 *
 * 适配脚本的 selector 动辄一两百字符，整页横滚会把顶栏/底栏一起带走；逐行横滚时每条日志
 * 自己滚自己的，行高固定、列表仍能纵向刷。所以 [WarehouseImportLogView.formatEntryLine] 的
 * 值不截断（截断会把「哪一段 selector 不匹配」这条最关键的信息砍掉），横向空间交给 UI。
 *
 * ## 颜色（R5）
 *
 * 只从 [MiuixTheme.colorScheme] 取：
 * - 失败（含失败 run 的整段）→ `error`；
 * - 跳过 → `primary`（警示但**不是**错误：miuix 色板没有独立的 warning 槽，用 error 会把
 *   「跳过一步」读成「这一轮挂了」）；
 * - 普通 → `onSurfaceVariantSummary`。
 *
 * @param buffer 日志缓冲（默认全局 [WarehouseImportLog]）；打开时取一次快照——面板是「看完就走」的
 *   只读视图，重新打开会重新取（组合重建）。需要实时刷新时由宿主重开面板，不在这里轮询。
 * @param onBack 顶栏返回。
 */
@Composable
fun WarehouseImportLogPage(
    buffer: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    val title = WarehouseStrings.warehouseImportExecutionLogTitle.text
    val snapshot = remember(buffer) { buffer.snapshot() }
    // 分组/行格式只来自纯逻辑层；UI 不再遍历 snapshot.runs（守卫盯着）。
    val sections = remember(snapshot) { WarehouseImportLogView.buildLogSections(snapshot) }
    // 复制/分享的正文也在纯逻辑层拼（模板由这里传入，逻辑层不写文案）。
    val share = remember(snapshot) {
        WarehouseImportLogView.buildShareText(
            snapshot = snapshot,
            deviceInfo = WarehouseDeviceInfo(
                model = Build.MODEL,
                androidVersion = Build.VERSION.RELEASE,
                appVersion = BuildConfig.VERSION_NAME,
            ),
            shareTextTemplate = WarehouseStrings.warehouseImportExecutionLogShareText.text,
            shareSubjectTemplate = WarehouseStrings.warehouseImportExecutionLogShareSubject.text,
        )
    }

    QingyuPageScaffold(
        title = title,
        onBack = onBack,
        smallTopBar = true,
        bottomBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = WarehouseStrings.duplicateAction.text,
                    onClick = { copyLogToClipboard(context, title, share.text) },
                )
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = WarehouseStrings.shareToOthersAction.text,
                    onClick = { shareLog(context, share) },
                )
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
        ) {
            if (sections.isEmpty()) {
                item(key = "empty") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 12.dp),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Text(
                            text = WarehouseStrings.warehouseImportExecutionLogEmpty.text,
                            style = MiuixTheme.textStyles.body1,
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        )
                    }
                }
            } else {
                sections.forEachIndexed { sectionIndex, section ->
                    item(key = "run-$sectionIndex") {
                        Text(
                            text = section.title,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 4.dp),
                            style = MiuixTheme.textStyles.body1
                                .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        )
                    }
                    itemsIndexed(
                        items = section.lines,
                        key = { lineIndex, _ -> "line-$sectionIndex-$lineIndex" },
                    ) { _, line ->
                        Text(
                            text = line.text,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                                .horizontalScroll(rememberScrollState()),
                            style = MiuixTheme.textStyles.footnote2,
                            color = logLineColor(line.emphasis),
                            maxLines = 1,
                            softWrap = false,
                        )
                    }
                }
            }
        }
    }
}

/** [LogEmphasis] → 主题色（唯一映射点；改配色只动这里）。 */
@Composable
private fun logLineColor(emphasis: LogEmphasis): Color = when (emphasis) {
    LogEmphasis.ERROR -> MiuixTheme.colorScheme.error
    LogEmphasis.WARN -> MiuixTheme.colorScheme.primary
    LogEmphasis.NORMAL -> MiuixTheme.colorScheme.onSurfaceVariantSummary
}

/** 复制到剪贴板（正文与分享同一份：已脱敏、已截断由纯逻辑层保证）。 */
private fun copyLogToClipboard(context: Context, label: String, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText(label, text))
}

/** 拉起系统分享面板：`ACTION_SEND` + `text/plain`，主题/正文都来自 [WarehouseLogShareText]。 */
private fun shareLog(context: Context, share: WarehouseLogShareText) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, share.subject)
        putExtra(Intent.EXTRA_TEXT, share.text)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(send, share.subject).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(chooser) }
        .onFailure { Log.w(LOG_TAG, "share failed: ${it.javaClass.simpleName}") }
}
