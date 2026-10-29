package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 情侣课表设置页 · Compose 渲染层（Phase 3 + 2026-10-29 复刻收口）。
 *
 * 对应 Flutter `lib/screens/couple_timetable_settings_screen.dart`：
 * 绑定信息 → 坚果云拉取（状态 / 远程路径 / 上次拉取 / 动作按钮）→
 * 情侣课表三个动作（导出 / 导入 / 解除）→ 周次偏移 → 叠加颜色。
 *
 * ## 这一层只做「摆位置 + 转点击」
 *
 * 显隐、文案、忙碌态、色板全部来自 [CoupleTimetableSettingsViewState]；
 * 点了之后写到哪里全在 `CoupleTimetableSettingsController`。**本文件不碰存储、不弹 Toast**
 * （唯一自持的状态是「解绑确认框开没开」，那是纯 UI 态）。
 *
 * ## 与 Dart 对齐的三处版式（旧版都错了）
 *
 * 1. **轴线 28**：列表左右留白 `QingyuPageCardMargin`(12) + 卡内 `ContentInsideMargin`(16)；
 *    旧版是 16 + 14 = 30，与分组标题（`SmallTitle` 自带 28）差 2dp，整页「行不齐」。
 * 2. **动作按钮是流水布局**：Dart 用 `Wrap(spacing: 8)` 摆「导出 / 导入 / 解绑」，
 *    首个主色、其余次要样式；旧版是整宽竖排同一个主色，占满一屏且看不出主次。
 * 3. **色块 42dp 圆角方**：Dart `HyperosColorChip` 是 42dp、圆角 11.3dp、未选中 1dp 描边、
 *    选中 2dp 描边 + 打勾 + 同色投影、按 12dp 间距自动换行；旧版是 28dp 正圆、
 *    8dp 间距、固定 8 个一行、选中只加一圈主题色。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CoupleTimetableSettingsPage(
    viewState: CoupleTimetableSettingsViewState,
    onBack: () -> Unit,
    onAction: (actionId: String) -> Unit,
    onShiftWeekOffset: (delta: Int) -> Unit,
    onPickColor: (rowIndex: Int, hex: String) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 解绑二次确认：Dart 是 `showHyperosDialog`，确认后才真解绑。纯 UI 态，不进 viewState。
    var showUnlinkConfirm by remember { mutableStateOf(false) }

    QingyuPageScaffold(title = viewState.title, onBack = onBack, smallTopBar = true) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(top = 4.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
        ) {
            // ── 1. 绑定状态 + 对方信息 ──
            item(key = "binding") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    QingyuSectionTitle(viewState.sectionTitle)
                    if (viewState.bound) {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = QingyuCardDefaults.ContentInsideMargin,
                        ) {
                            InfoRow(
                                label = viewState.partnerNameLabel,
                                value = viewState.partnerName,
                                dark = dark,
                            )
                            // Dart `_buildInfoRow` 每行都留 8dp 底距（含末行）。
                            Spacer(modifier = Modifier.height(8.dp))
                            InfoRow(
                                label = viewState.courseCountLabel,
                                value = viewState.lastImportedText,
                                dark = dark,
                            )
                        }
                    }
                }
            }

            // ── 2. 坚果云拉取 ──
            item(key = "webdav") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    QingyuSectionTitle(viewState.webdavTitle)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        // Dart：状态行 `listTitle`(17) → main；说明行 `listDetail`(14) → body2。
                        Text(
                            text = viewState.webdavStatusText,
                            style = MiuixTheme.textStyles.main,
                            fontWeight = FontWeight.Medium,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = viewState.webdavRemotePathText,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        viewState.webdavLastPulledText?.let { lastPulled ->
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = lastPulled,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        ActionButtonRow(
                            buttons = viewState.webdavButtons,
                            dark = dark,
                            onAction = onAction,
                        )
                    }
                }
            }

            // ── 3. 情侣课表动作 ──
            item(key = "couple_actions") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    QingyuSectionTitle(viewState.coupleSectionTitle)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        ActionButtonRow(
                            buttons = viewState.coupleButtons,
                            dark = dark,
                            onAction = { actionId ->
                                // 解除绑定先过二次确认（Dart `_confirmUnlink`），其余直接交给宿主。
                                if (actionId == CoupleTimetableSettingsLogic.COUPLE_UNLINK) {
                                    showUnlinkConfirm = true
                                } else {
                                    onAction(actionId)
                                }
                            },
                        )
                    }
                }
            }

            // ── 4. 周次偏移（未绑定不出现） ──
            if (viewState.showWeekOffset) {
                item(key = "week_offset") {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        QingyuSectionTitle(viewState.weekOffsetTitle)
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = QingyuCardDefaults.ContentInsideMargin,
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                StepButton(
                                    isPlus = false,
                                    enabled = viewState.canDecrementOffset,
                                    dark = dark,
                                    onClick = { onShiftWeekOffset(-1) },
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    text = viewState.weekOffsetLabel,
                                    style = MiuixTheme.textStyles.main,
                                    fontWeight = FontWeight.Medium,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.weight(1f),
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                StepButton(
                                    isPlus = true,
                                    enabled = viewState.canIncrementOffset,
                                    dark = dark,
                                    onClick = { onShiftWeekOffset(1) },
                                )
                            }
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = viewState.weekOffsetPreview,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                    }
                }
            }

            // ── 5. 叠加颜色（未绑定不出现） ──
            if (viewState.showColors) {
                item(key = "colors") {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        QingyuSectionTitle(viewState.colorsTitle)
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = QingyuCardDefaults.ContentInsideMargin,
                        ) {
                            viewState.colorRows.forEachIndexed { index, row ->
                                if (index > 0) Spacer(modifier = Modifier.height(14.dp))
                                Text(
                                    text = row.label,
                                    style = MiuixTheme.textStyles.main,
                                    fontWeight = FontWeight.Medium,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                ColorChipRow(
                                    row = row,
                                    dark = dark,
                                    onPick = { hex -> onPickColor(index, hex) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (showUnlinkConfirm) {
        OverlayDialog(
            show = true,
            title = viewState.unlinkConfirmTitle,
            summary = viewState.unlinkConfirmMessage,
            onDismissRequest = { showUnlinkConfirm = false },
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Button(
                    onClick = { showUnlinkConfirm = false },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = viewState.unlinkConfirmCancelLabel)
                }
                Button(
                    onClick = {
                        showUnlinkConfirm = false
                        onAction(CoupleTimetableSettingsLogic.COUPLE_UNLINK)
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                ) {
                    Text(text = viewState.unlinkConfirmActionLabel)
                }
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String, dark: Boolean) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.main,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
            textAlign = TextAlign.End,
        )
    }
}

/**
 * 一组动作按钮：**流水布局**（Dart `Wrap(spacing: 8, runSpacing: 8)` 的对位件）。
 *
 * 主色按钮 = 默认按钮配色；次要按钮 = **同色系的 tonal 填充**
 * （`primarySurface` 底 + 主色字）。为什么不用 `TextButton`：官方那个组件的
 * `colors` 参数类型是 `TextButtonColors`（与 `Button` 的 `ButtonColors` 不是同一个类型），
 * 而且它只收 `text: String`、没有内容槽——塞不进「转圈 + 文案」，而 Dart 的次要按钮
 * 忙碌时同样转圈。tonal 填充在视觉上仍是「次级」，且保住了 loading 能力。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ActionButtonRow(
    buttons: List<CoupleActionButton>,
    dark: Boolean,
    onAction: (String) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        for (button in buttons) {
            val colors = when (button.variant) {
                CoupleButtonVariant.PRIMARY -> ButtonDefaults.buttonColors()
                CoupleButtonVariant.SECONDARY -> ButtonDefaults.buttonColors(
                    color = Color(QingyuTheme.primarySurface(dark = dark)),
                    contentColor = Color(QingyuTheme.primary(dark = dark)),
                )
            }
            Button(
                onClick = { onAction(button.id) },
                enabled = button.enabled,
                colors = colors,
            ) {
                if (button.loading) {
                    CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(text = button.label)
            }
        }
    }
}

/** 周次偏移的 −/+ 圆形按钮（禁用时降到 35% 透明，Dart `_WeekOffsetStepButton` 同口径）。 */
@Composable
private fun StepButton(
    isPlus: Boolean,
    enabled: Boolean,
    dark: Boolean,
    onClick: () -> Unit,
) {
    val tint = if (enabled) {
        Color(QingyuTheme.primary(dark = dark))
    } else {
        Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.35f)
    }
    IconButton(
        onClick = onClick,
        enabled = enabled,
        backgroundColor = Color(QingyuTheme.card(dark)),
        cornerRadius = 12.dp,
        minWidth = 44.dp,
        minHeight = 44.dp,
    ) {
        Icon(
            imageVector = if (isPlus) MiuixIcons.Add else MiuixIcons.Remove,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(20.dp),
        )
    }
}

/**
 * 一行颜色快选：按 Dart `HyperosHexColorChipGroup(distributeHorizontally: false)` 的口径
 * **自动流式换行**（间距 12/12），不按固定列数切。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ColorChipRow(
    row: CoupleColorRowView,
    dark: Boolean,
    onPick: (String) -> Unit,
) {
    val selected = row.selectedHex.uppercase()
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(ColorChipSpacing),
        verticalArrangement = Arrangement.spacedBy(ColorChipSpacing),
    ) {
        for (hex in row.paletteHexes) {
            ColorChip(
                hex = hex,
                selected = hex.uppercase() == selected,
                dark = dark,
                onPick = onPick,
            )
        }
    }
}

/**
 * 单颗色块（Dart `HyperosColorChip`）：42dp 圆角方、未选中 1dp `outline` 描边、
 * 选中 2dp `onSurface` 描边 + 45% 大小勾、同色 22% 投影。
 *
 * **按压面用官方 [IconButton]**（`backgroundColor` 承载色块本体），不自己写
 * `Box + clickable`：这样才能拿到官方的按压反馈与触觉，也符合 miuix-first 那条
 * 「不自己模拟按压反馈」。描边与投影只是外层装饰（Dart 原版同样是自绘，
 * miuix 0.9.4 没有色块快选组件——它的 `ColorPalette` / `ColorPicker` 是连续取色盘，
 * 不是「19 个预设色挑一个」的语义）。
 */
@Composable
private fun ColorChip(
    hex: String,
    selected: Boolean,
    dark: Boolean,
    onPick: (String) -> Unit,
) {
    val color = parseHexColor(hex, fallback = Color(QingyuTheme.primary(dark = dark)))
    val shape = RoundedCornerShape(ColorChipRadius)
    val outline = if (selected) {
        Color(QingyuTheme.primaryText(dark))
    } else {
        Color(QingyuTheme.outline(dark))
    }
    Box(
        modifier = Modifier
            .shadow(
                elevation = 4.dp,
                shape = shape,
                clip = false,
                ambientColor = color.copy(alpha = 0.22f),
                spotColor = color.copy(alpha = 0.22f),
            )
            .border(width = if (selected) 2.dp else 1.dp, color = outline, shape = shape),
    ) {
        IconButton(
            onClick = { onPick(hex) },
            backgroundColor = color,
            cornerRadius = ColorChipRadius,
            minWidth = ColorChipSize,
            minHeight = ColorChipSize,
        ) {
            if (selected) {
                // Dart `_contrastIconColor`：亮底用黑、暗底用白（阈值 0.55）。
                val iconColor = if (color.luminance() > 0.55f) Color.Black else Color.White
                Icon(
                    imageVector = MiuixIcons.Ok,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(ColorChipSize * 0.45f),
                )
            }
        }
    }
}

/** 色块边长：Dart `HyperosHexColorChipGroup.chipSize` 默认 42。 */
private val ColorChipSize = 42.dp

/**
 * 色块圆角：Dart `HyperosRadius.chipRadius(42)` = `42 * 7 / 26` ≈ 11.3dp
 * （再按 `clampCornerRadius` 夹到不超过边长一半）。
 */
private val ColorChipRadius = 42.dp * 7f / 26f

/** 色块间距：Dart `HyperosHexColorChipGroup` 的 spacing / runSpacing 默认都是 12。 */
private val ColorChipSpacing = 12.dp

/**
 * 十六进制色 → Compose 颜色。
 *
 * 解析不出来时用调用方给的 [fallback]（主色），**不要**写死一个字面色：
 * 写死会在换主题色 / 深色模式下与周围不一致（样式守卫 R5 也拦这条）。
 */
private fun parseHexColor(hex: String, fallback: Color): Color {
    val trimmed = hex.trim().removePrefix("#")
    return try {
        when (trimmed.length) {
            6 -> Color(trimmed.toLong(16) or 0xFF000000)
            8 -> Color(trimmed.toLong(16))
            else -> fallback
        }
    } catch (_: NumberFormatException) {
        fallback
    }
}
