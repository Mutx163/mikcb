package com.mutx163.qingyu.pages.import.warehouse

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 教务导入脚本的**原生对话框**（I2-1；替换 `warehouseBridgeFallbackAnswer` 的确定性兜底）。
 *
 * 对应 Dart `warehouse_adapter_web_login_screen.dart` 的 `_showScriptConfirmDialog` /
 * `_showScriptPromptDialog` / `_showScriptSingleSelectionDialog`：
 * 脚本经 `AndroidBridgePromise` 发来请求 → 这里弹原生弹窗 → 用户回答由宿主
 * 经 [warehouseBridgeResolveScript] resolve 回网页侧 Promise。
 *
 * ## 弹层规矩（与全仓一致，别破）
 *
 * - **常驻组合 + show 驱动 + remember 最后非空请求**：退场动画期间正文照常渲染；
 * - 动作统一两枚等宽横排 [TextButton]（取消在左、确认主色字在右），与
 *   `WarehouseCustomDebugHost` 删除确认 / `TimeSchemeManagementDialogs` 同一形态；
 * - 文案默认值全部取 [WarehouseStrings]（ARB 原文）：脚本没给 title/message/confirmText
 *   时的兜底分别是 `confirmImportAction` / `defaultContinuePrompt` / `confirmImportAction`，
 *   prompt 标题兜底 `inputRequiredTitle`、确认键 `saveAction`，单选标题 `pleaseChooseTitle`。
 * - **不加自动聚焦**（拍板 #1）。
 *
 * ## 取消语义（逐字对齐 Dart）
 *
 * | 弹窗 | 取消/点外部 | resolve 值 |
 * |---|---|---|
 * | confirm | 含「取消」按钮与遮罩 | `false` |
 * | prompt | 同上 | `null` |
 * | singleSelection | 同上 | `null` |
 */

/** 退场快照：与 `AchievementDetailSheet` 同款（弹层常驻组合，入参变 null 时留最后一份非空）。 */
@Composable
private fun <T : Any> rememberLastRequest(current: T?): T? {
    var shown by remember { mutableStateOf(current) }
    if (current != null) {
        shown = current
    }
    return shown
}

/** 确认/取消双动作行：取消在左（中性字）、确认在右（主色字）。 */
@Composable
private fun ScriptDialogActions(
    cancelLabel: String,
    confirmLabel: String,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TextButton(
            modifier = Modifier.weight(1f),
            text = cancelLabel,
            onClick = onCancel,
        )
        TextButton(
            modifier = Modifier.weight(1f),
            text = confirmLabel,
            onClick = onConfirm,
            colors = ButtonDefaults.textButtonColorsPrimary(),
        )
    }
}

/** 脚本 `confirm`（Dart `_showScriptConfirmDialog`）。 */
@Composable
fun WarehouseScriptConfirmDialog(
    show: Boolean,
    request: WarehouseBridgeDialogRequest?,
    onResult: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val shown = rememberLastRequest(request)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = shown?.title?.ifBlank { WarehouseStrings.confirmImportAction.zh }
            ?: WarehouseStrings.confirmImportAction.zh,
        onDismissRequest = { onResult(false) },
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = shown?.message?.ifBlank { WarehouseStrings.defaultContinuePrompt.zh }
                    ?: WarehouseStrings.defaultContinuePrompt.zh,
                style = MiuixTheme.textStyles.body2,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(16.dp))
            ScriptDialogActions(
                cancelLabel = WarehouseStrings.cancelAction.zh,
                confirmLabel = shown?.confirmText?.ifBlank { WarehouseStrings.confirmImportAction.zh }
                    ?: WarehouseStrings.confirmImportAction.zh,
                onCancel = { onResult(false) },
                onConfirm = { onResult(true) },
            )
        }
    }
}

/**
 * 脚本 `prompt`（Dart `_showScriptPromptDialog`）。
 *
 * `validatorName == "validateYearInput"` 时本地校验 4 位年份，不过则提示并**留在弹窗**
 * （Dart 同口径：`validate` 返回 false 不收起对话框）。
 */
@Composable
fun WarehouseScriptPromptDialog(
    show: Boolean,
    request: WarehouseBridgeDialogRequest?,
    onResult: (String?) -> Unit,
) {
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    val shown = rememberLastRequest(request)
    var input by remember { mutableStateOf("") }
    // 每次打开回填脚本给的默认值；关闭期间不重置（退场动画里内容不能塌）。
    LaunchedEffect(show, shown?.requestId) {
        if (show) input = shown?.defaultValue.orEmpty()
    }
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = shown?.title?.ifBlank { WarehouseStrings.inputRequiredTitle.zh }
            ?: WarehouseStrings.inputRequiredTitle.zh,
        onDismissRequest = { onResult(null) },
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            val message = shown?.message.orEmpty()
            if (message.isNotBlank()) {
                Text(
                    text = message,
                    style = MiuixTheme.textStyles.body2,
                    lineHeight = 20.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Spacer(modifier = Modifier.height(12.dp))
            }
            TextField(
                value = input,
                onValueChange = { input = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            Spacer(modifier = Modifier.height(16.dp))
            ScriptDialogActions(
                cancelLabel = WarehouseStrings.cancelAction.zh,
                confirmLabel = WarehouseStrings.saveAction.zh,
                onCancel = { onResult(null) },
                onConfirm = {
                    if (shown?.validatorName == "validateYearInput" &&
                        !Regex("^[0-9]{4}$").matches(input)
                    ) {
                        Toast.makeText(
                            context,
                            WarehouseStrings.pleaseEnterFourDigitYear.zh,
                            Toast.LENGTH_SHORT,
                        ).show()
                    } else {
                        onResult(input)
                    }
                },
            )
        }
    }
}

/** 脚本 `singleSelection`（Dart `_showScriptSingleSelectionDialog`）：标题 + 单选列表 + 取消/保存。 */
@Composable
fun WarehouseScriptSingleSelectionDialog(
    show: Boolean,
    request: WarehouseBridgeDialogRequest?,
    onResult: (Int?) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val shown = rememberLastRequest(request)
    var selected by remember { mutableIntStateOf(0) }
    LaunchedEffect(show, shown?.requestId) {
        if (show) selected = shown?.selectedIndex ?: 0
    }
    // 选项数无上界（脚本给多少是多少）：清单限高可滚，动作区留在滚动之外。
    val maxListHeight = (LocalConfiguration.current.screenHeightDp * 0.5f).dp
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = shown?.title?.ifBlank { WarehouseStrings.pleaseChooseTitle.zh }
            ?: WarehouseStrings.pleaseChooseTitle.zh,
        onDismissRequest = { onResult(null) },
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            val options = shown?.options.orEmpty()
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxListHeight)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                itemsIndexed(options, key = { index, _ -> index }) { index, option ->
                    val isSelected = index == selected
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selected = index }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = option,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.primaryText(dark)),
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f),
                        )
                        if (isSelected) {
                            Spacer(modifier = Modifier.width(6.dp))
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = null,
                                modifier = Modifier.size(22.dp),
                                tint = MiuixTheme.colorScheme.primary,
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            ScriptDialogActions(
                cancelLabel = WarehouseStrings.cancelAction.zh,
                confirmLabel = WarehouseStrings.saveAction.zh,
                onCancel = { onResult(null) },
                onConfirm = {
                    val current = shown
                    if (current == null || current.options.isEmpty()) {
                        onResult(null)
                    } else {
                        onResult(selected.coerceIn(0, current.options.size - 1))
                    }
                },
            )
        }
    }
}

/**
 * 录制收尾的「保存为快捷导入？」确认（Dart `_stopMacroRecording` / `_completeMacroAndPop`
 * 里的 `showAppConfirmDialog`）。
 *
 * @param autoRecord 列表页「录制导入」进来的一录到底流程：用 Dart 的自动录制文案变体。
 */
@Composable
fun WarehouseMacroSaveConfirmDialog(
    show: Boolean,
    stepCount: Int,
    autoRecord: Boolean,
    onSave: () -> Unit,
    onDiscard: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.courseImportSaveRecordingTitle.zh,
        onDismissRequest = onDiscard,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = if (autoRecord) {
                    WarehouseStrings.courseImportSaveAutoRecordingMessage.filled("count", stepCount.toString())
                } else {
                    WarehouseStrings.courseImportSaveRecordingMessage.filled("count", stepCount.toString())
                },
                style = MiuixTheme.textStyles.body2,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(16.dp))
            ScriptDialogActions(
                cancelLabel = WarehouseStrings.cancelAction.zh,
                confirmLabel = WarehouseStrings.saveAction.zh,
                onCancel = onDiscard,
                onConfirm = onSave,
            )
        }
    }
}
