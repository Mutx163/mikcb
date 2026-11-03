package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.RadioButtonPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 网页对话框的**原生界面**（F32 收口）：confirm / prompt / 单选 / 保存配置四类交互
 * 从「降级默认值」升级为用户可看可选的真弹层。
 *
 * ## 形态对齐 Dart 旧版
 *
 * | 交互 | Dart 旧版 | 本层 | 回传 |
 * |---|---|---|---|
 * | `confirm` | 居中对话框（`showHyperosConfirmDialog`） | 官方 [OverlayDialog] | 确认 `true` / 取消 `false` |
 * | `prompt` | 底部输入弹层（`showHyperosSheet`） | 官方 `OverlayBottomSheet`（[QingyuSheet]） | 保存输入串 / 取消 `null` |
 * | 单选 | 底部单选弹层 | [QingyuSheet] + 官方 `RadioButtonPreference` | 保存下标 / 取消 `null` |
 * | 保存配置 | 无 UI 直接落盘 | [OverlayDialog] 字段表单（键名原样、按类型走官方控件） | 落盘 `true` / 取消 `false` |
 *
 * 旧版「保存配置」没有界面、直接落盘；本层按 F32 任务书把 payload 渲染成表单让
 * 用户确认后再落盘——回传结构不变（true/false），行为差异已记录在认领结论里。
 *
 * ## 弹层纪律（不许退）
 *
 * 常驻组合（弹层不许条件挂载）：三个弹层体**始终组合**，`show` 由 [request] 实时
 * 驱动；正文用 remember 保留的**最后一份非空请求**渲染（`shown`），点取消后退场
 * 动画期间不会塌成空板。输入/选中/开关状态都以 requestId 为 remember 键：脚本的
 * requestId 带时间戳与随机段，每次调用必然不同，天然做到「新请求 = 全新表单」。
 * [OverlayDialog] 的 `insideMargin` 显式给 16dp（本仓口径，不吃组件默认）。
 *
 * 诚实边界：`savePresetTimeSlots` 载荷是数组，解析不出字段表（模型层回 null），
 * 宿主对它走降级回答——本层没有画一个「确认保存」却什么都不存的假界面。
 */

/** 渲染层 → 宿主的用户最终动作；宿主翻成回传 Answer（SaveConfig 先落盘再回答）。 */
sealed class WarehouseBridgeDialogUserAction {
    abstract val requestId: String

    /** confirm 两个按钮。 */
    data class Confirm(override val requestId: String, val confirmed: Boolean) :
        WarehouseBridgeDialogUserAction()

    /** prompt 保存；[text] 是输入框当前值。 */
    data class Prompt(override val requestId: String, val text: String) :
        WarehouseBridgeDialogUserAction()

    /** 单选保存。 */
    data class Selection(override val requestId: String, val index: Int) :
        WarehouseBridgeDialogUserAction()

    /** 保存配置确认；[values] 是编辑后的 payload 值树（保持网页字段序）。 */
    data class SaveConfig(override val requestId: String, val values: Map<String, Any?>) :
        WarehouseBridgeDialogUserAction()

    /** 取消（按钮 / 点空白 / 返回键），宿主按请求类型回「取消值」。 */
    data class Dismiss(override val requestId: String) : WarehouseBridgeDialogUserAction()
}

@Composable
fun WarehouseBridgeDialogHost(
    request: WarehouseBridgeDialogRequest?,
    onAction: (WarehouseBridgeDialogUserAction) -> Unit,
) {
    // 退场动画期间保留最后一份非空请求（常驻组合配方，见文件头「弹层纪律」）。
    var shown by remember { mutableStateOf<WarehouseBridgeDialogRequest?>(null) }
    if (request != null) shown = request
    val current = shown

    // ------------------------------------------------------------------
    // confirm：居中确认框（Dart showHyperosConfirmDialog 的对应物）
    // ------------------------------------------------------------------
    val confirm = current as? WarehouseBridgeDialogRequest.Confirm
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = confirm != null,
        title = confirm?.title?.ifBlank { WarehouseStrings.confirmImportAction.zh },
        summary = confirm?.message?.takeIf { it.isNotBlank() },
        onDismissRequest = { confirm?.let { onAction(WarehouseBridgeDialogUserAction.Dismiss(it.requestId)) } },
    ) {
        val c = confirm
        if (c != null) {
            // message 为空时给旧版同款兜底文案（`?? l10n.defaultContinuePrompt`）。
            if (c.message.isBlank()) {
                Text(
                    text = WarehouseStrings.defaultContinuePrompt.zh,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    lineHeight = 20.sp,
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            DialogActionRow(
                cancelText = WarehouseStrings.cancelAction.zh,
                confirmText = c.confirmText.ifBlank { WarehouseStrings.confirmImportAction.zh },
                onCancel = { onAction(WarehouseBridgeDialogUserAction.Confirm(c.requestId, confirmed = false)) },
                onConfirm = { onAction(WarehouseBridgeDialogUserAction.Confirm(c.requestId, confirmed = true)) },
            )
        }
    }

    // ------------------------------------------------------------------
    // prompt：底部输入弹层（Dart showHyperosSheet + 输入框的对应物）
    // ------------------------------------------------------------------
    val prompt = current as? WarehouseBridgeDialogRequest.Prompt
    var promptText by remember(current?.requestId) {
        mutableStateOf((current as? WarehouseBridgeDialogRequest.Prompt)?.defaultValue.orEmpty())
    }
    var promptInvalid by remember(current?.requestId) { mutableStateOf(false) }
    QingyuSheet(
        show = prompt != null,
        onDismissRequest = { prompt?.let { onAction(WarehouseBridgeDialogUserAction.Dismiss(it.requestId)) } },
        title = prompt?.title?.ifBlank { WarehouseStrings.inputRequiredTitle.zh },
        maxHeightFraction = 0.6f,
    ) {
        val p = prompt
        if (p != null) {
            if (p.message.isNotBlank()) {
                Text(
                    text = p.message,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    lineHeight = 20.sp,
                )
                Spacer(modifier = Modifier.height(12.dp))
            }
            TextField(
                value = promptText,
                onValueChange = {
                    promptText = it
                    promptInvalid = false
                },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            if (promptInvalid) {
                Text(
                    text = WarehouseStrings.pleaseEnterFourDigitYear.zh,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.error(isSystemInDarkTheme())),
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            DialogActionRow(
                cancelText = WarehouseStrings.cancelAction.zh,
                confirmText = WarehouseStrings.saveAction.zh,
                onCancel = { onAction(WarehouseBridgeDialogUserAction.Dismiss(p.requestId)) },
                onConfirm = {
                    // 校验不过不关层（对齐 Dart validate 分支：提示 + 留在原地）。
                    if (p.validate(promptText)) {
                        onAction(WarehouseBridgeDialogUserAction.Prompt(p.requestId, promptText))
                    } else {
                        promptInvalid = true
                    }
                },
            )
        }
    }

    // ------------------------------------------------------------------
    // singleSelection：底部单选弹层（Dart showAppSingleChoiceDialog 的对应物）
    // ------------------------------------------------------------------
    val selection = current as? WarehouseBridgeDialogRequest.SingleSelection
    var selectedIndex by remember(current?.requestId) {
        mutableStateOf((current as? WarehouseBridgeDialogRequest.SingleSelection)?.selectedIndex ?: 0)
    }
    QingyuSheet(
        show = selection != null,
        onDismissRequest = { selection?.let { onAction(WarehouseBridgeDialogUserAction.Dismiss(it.requestId)) } },
        title = selection?.title?.ifBlank { WarehouseStrings.pleaseChooseTitle.zh },
        maxHeightFraction = 0.6f,
    ) {
        val s = selection
        if (s != null) {
            s.options.forEachIndexed { index, option ->
                RadioButtonPreference(
                    title = option,
                    selected = index == selectedIndex,
                    onClick = { selectedIndex = index },
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            DialogActionRow(
                cancelText = WarehouseStrings.cancelAction.zh,
                confirmText = WarehouseStrings.saveAction.zh,
                onCancel = { onAction(WarehouseBridgeDialogUserAction.Dismiss(s.requestId)) },
                onConfirm = { onAction(WarehouseBridgeDialogUserAction.Selection(s.requestId, selectedIndex)) },
            )
        }
    }

    // ------------------------------------------------------------------
    // saveCourseConfig：字段表单（键名原样渲染，类型走官方控件）
    // ------------------------------------------------------------------
    val form = current as? WarehouseBridgeDialogRequest.SaveConfig
    var edits by remember(current?.requestId) {
        mutableStateOf(warehouseBridgeFormFieldEdits(form?.fields.orEmpty()))
    }
    fun updateEdit(key: String, transform: (WarehouseBridgeFormFieldEdit) -> WarehouseBridgeFormFieldEdit) {
        edits = edits.map { if (it.key == key) transform(it) else it }
    }

    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = form != null,
        // 无标题：旧版本无此界面， payload 键即信息本体，不再造一句没出处的文案。
        onDismissRequest = { form?.let { onAction(WarehouseBridgeDialogUserAction.Dismiss(it.requestId)) } },
    ) {
        val f = form
        if (f != null) {
            Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                edits.forEach { edit ->
                    when (edit.kind) {
                        WarehouseBridgeFormFieldKind.TEXT, WarehouseBridgeFormFieldKind.NUMBER -> TextField(
                            value = edit.text,
                            onValueChange = { value ->
                                updateEdit(edit.key) { it.copy(text = value) }
                            },
                            // 键名原样当占位：字段从网页传什么就显示什么，不翻译。
                            label = edit.key,
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        WarehouseBridgeFormFieldKind.FLAG -> SwitchPreference(
                            checked = edit.flagValue == true,
                            onCheckedChange = { value ->
                                updateEdit(edit.key) { it.withFlagValue(value) }
                            },
                            title = edit.key,
                            summary = null,
                        )

                        WarehouseBridgeFormFieldKind.READONLY -> Column {
                            Text(
                                text = edit.key,
                                style = MiuixTheme.textStyles.footnote1,
                            )
                            // 嵌套对象 / 数组 / null 解析不出控件：只读展示原文，
                            // 确认时原样保留（不悄悄丢字段）。
                            Text(
                                text = MiniJson.encode(edit.original),
                                style = MiuixTheme.textStyles.footnote2,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            DialogActionRow(
                cancelText = WarehouseStrings.cancelAction.zh,
                confirmText = WarehouseStrings.saveAction.zh,
                onCancel = { onAction(WarehouseBridgeDialogUserAction.Dismiss(f.requestId)) },
                onConfirm = {
                    onAction(WarehouseBridgeDialogUserAction.SaveConfig(f.requestId, warehouseBridgeFormValues(edits)))
                },
            )
        }
    }
}

/** 弹层底部动作行：取消在左、主按钮在右，等宽横排（与本仓其余弹层同一配方）。 */
@Composable
private fun DialogActionRow(
    cancelText: String,
    confirmText: String,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TextButton(
            modifier = Modifier.weight(1f),
            text = cancelText,
            onClick = onCancel,
        )
        Button(
            onClick = onConfirm,
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) {
            Text(text = confirmText)
        }
    }
}
