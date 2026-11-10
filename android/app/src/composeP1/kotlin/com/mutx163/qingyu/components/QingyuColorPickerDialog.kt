package com.mutx163.qingyu.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import java.util.Locale
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.ColorPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 选色弹窗：官方 [ColorPicker] + 取消 / 确认。
 *
 * 版式与落盘节奏对齐 `app/SettingsHost.kt` 的 `SettingsColorPickerDialog`（2026-11-03 换官方
 * ColorPicker 那处）：拖动中只改弹窗本地色值，**确认才回调一次 [onConfirm]**；取消不产生任何写入。
 * 发布版 `lib/widgets/timetable_text_color_settings.dart` 的 `_showColorPicker` 是同一结构
 * （`showHyperosDialog(title, body: MiuixColorPicker, actions: 取消 / 确认)`）。
 *
 * ## 常驻组合
 *
 * 调用方**常驻组合**本弹窗、只用 [show] 开关（与全仓弹层口径一致）：
 * `if (open) { OverlayDialog(show = true) }` 会在关闭那一帧把整棵树摘出组合，
 * 官方淡出 / 缩放退场一次都播不出来。重开时 [LaunchedEffect] 把草稿色重置回 [initialHex]，
 * 上一次被取消的颜色不会残留。
 *
 * @param show 显隐；由调用方的状态驱动，不用数据存在性当挂载开关。
 * @param initialHex 打开的初始色（`#RRGGBB` / `RRGGBB`），每次重新打开都从它起手。
 * @param title 弹窗标题。
 * @param cancelLabel / [confirmLabel] 两颗等宽动作的文案。
 * @param dark 深色主题档位：只影响解析失败时的兜底色。
 * @param onConfirm 确认时回调 `#RRGGBB`（大写六位，与课程 / 日程模型存的口径一致）。
 */
@Composable
fun QingyuColorPickerDialog(
    show: Boolean,
    initialHex: String,
    title: String,
    cancelLabel: String,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
    dark: Boolean = isSystemInDarkTheme(),
) {
    val fallback = Color(QingyuTheme.primary(dark = dark))
    var pickerColor by remember { mutableStateOf(parseChipColor(initialHex, fallback)) }
    // 每次重新打开都从当前真值起手：取消过的颜色不会在下次打开时闪一帧。
    LaunchedEffect(show) {
        if (show) pickerColor = parseChipColor(initialHex, fallback)
    }

    OverlayDialog(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ColorPicker(
                color = pickerColor,
                onColorChanged = { pickerColor = it },
            )
            // 与发布版同口径（`hyperos_dialog.dart` 对 2 个动作走 Row + Expanded + 12dp）：
            // 取消 + 确认两颗等宽并排，确认是主色实心。
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                ) {
                    Text(
                        text = cancelLabel,
                        style = MiuixTheme.textStyles.button,
                    )
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(pickerColor.toHexRgb()) },
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(
                        text = confirmLabel,
                        style = MiuixTheme.textStyles.button,
                    )
                }
            }
        }
    }
}

/** Compose 色 → 模型存的 `#RRGGBB`（不透明；色值只承载六位十六进制）。 */
private fun Color.toHexRgb(): String {
    val argb = toArgb()
    return "#%02X%02X%02X".format(
        Locale.ROOT,
        (argb shr 16) and 0xFF,
        (argb shr 8) and 0xFF,
        argb and 0xFF,
    )
}


// ── 预览（一屏档 400×900）────────────────────────────────────────────────

/**
 * 组件预览：取色弹窗打开态。
 *
 * 用一条课程色起手，标题 / 动作文案传预览串（与真机同一套组件；屏上文案仍走 ARB）。
 * 预览名与预览串是 IDE 标签、不是屏上文案，CJK 基线增量由提交窗统一登记。
 */
@Preview(name = "取色弹窗", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewQingyuColorPickerDialog() {
    QingyuPageTheme(isDark = false) {
        QingyuColorPickerDialog(
            show = true,
            initialHex = "#2196F3",
            title = "课程颜色",
            cancelLabel = "取消",
            confirmLabel = "确认",
            onDismiss = {},
            onConfirm = {},
            dark = false,
        )
    }
}
