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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
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
                            style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
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
                                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
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
                                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
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

    // 解绑确认框常驻组合、show 由状态驱动（2026-11-03 弹层审计）：
    // 原先 `if (showUnlinkConfirm) { OverlayDialog(show = true) }` 条件挂载，退场动画永不播；
    // 标题/正文来自 viewState（页面级状态，非空），退场期间不会闪空。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = showUnlinkConfirm,
        title = viewState.unlinkConfirmTitle,
        summary = viewState.unlinkConfirmMessage,
        onDismissRequest = { showUnlinkConfirm = false },
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
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
                // 实心红是有意的语义强化（Dart 同按钮是 primary 主色，见拍板 #6）：
                // 解绑会直接删掉对方课表的本地绑定，红底比主色更能拦住误触。
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
 * 主按钮 = `buttonColorsPrimary()`（强调色实心，Dart `HyperosButtonVariant.primary`）；
 * 次按钮 = `buttonColors()`（`secondaryVariant` 灰底深字，Dart `secondary`）。
 *
 * **不要**再用 `primarySurface` 底 + `primary` 字做「tonal 次级」：没有 seed 时
 * `QingyuTheme.primarySurface(seedHex = null)` 直接返回 `PRIMARY`，与 `primary` 同色，
 * 按钮标签会完全看不见（2026-11-02 审核 P1）。
 *
 * 为什么不用 `TextButton`：官方那个组件的 `colors` 参数类型是 `TextButtonColors`
 * （与 `Button` 的 `ButtonColors` 不是同一个类型），而且它只收 `text: String`、
 * 没有内容槽——塞不进「转圈 + 文案」，而 Dart 的次要按钮忙碌时同样转圈。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ActionButtonRow(
    buttons: List<CoupleActionButton>,
    onAction: (String) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        for (button in buttons) {
            val colors = when (button.variant) {
                CoupleButtonVariant.PRIMARY -> ButtonDefaults.buttonColorsPrimary()
                CoupleButtonVariant.SECONDARY -> ButtonDefaults.buttonColors()
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
            contentDescription = if (isPlus) {
                CoupleStrings.increaseAction.text
            } else {
                CoupleStrings.decreaseAction.text
            },
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
            modifier = Modifier.semantics {
                contentDescription = CoupleStrings.colorOptionLabel.filled("name", CoupleColorNames.nameFor(hex))
                // 单选态交给语义属性，不写进文案。
                role = Role.RadioButton
                this.selected = selected
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 3 档：已绑定·坚果云已连接 / 未绑定·未连接 / 导入中（按钮变「导入中...」）；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 已绑定 / 未绑定 —— 绑定信息卡、周次偏移、叠加颜色三块只在绑定后出现，
//     「解除绑定」按钮也只在绑定后出现；
//   · 未连接 —— 坚果云那一段只剩「连接」一个主色按钮，与已连接的三个按钮布局不同；
//   · 导入中 —— 忙碌态只改按钮文案（接 `...`）与禁用，不动布局，最容易漏看；
//   · 暗色 / 大字号 —— 页面取色走 isSystemInDarkTheme()，只有 QingyuPageTheme 会把
//     LocalConfiguration 的 uiMode 一起改写；行内文案的折行点只在字放大后才暴露。
//
// 固定写法：主题一律 QingyuPageTheme(isDark = …)、字号走 textScale 参数
//（@Preview(fontScale = …) 绕过了应用的 appTextScale 口径）；宽度按 400dp（本仓折行实测口径）。
//
// 数据一律走 `CoupleTimetableSettingsLogic.buildViewState`，不手工拼 viewState：
// 显隐、按钮样式、色板都在模型层算，手工拼等于绕过被测代码。
// `CoupleWebdavConfig` 用全限定名，避免给页面文件新增业务 import（本批只允许加预览用 import）。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用坚果云配置：`connected = true` 时填示例账号与上次拉取时间。 */
private fun previewCoupleWebdavConfig(connected: Boolean): com.mutx163.qingyu.sync.CoupleWebdavConfig =
    com.mutx163.qingyu.sync.CoupleWebdavConfig(
        username = if (connected) "lisi@example.com" else "",
        lastPulledAtIso = if (connected) "2026-11-07T20:00:00" else null,
    )

/** 预览用绑定：对方「李四」、周偏移 +1、三个颜色都留默认。 */
private fun previewCoupleBinding(): PartnerTimetableBindingModel = PartnerTimetableBindingModel(
    partnerName = "李四",
    lastImportedAtIso = "2026-11-07T20:15:00",
    weekOffset = 1,
)

/** 一档预览：模型层输入；[name] 只用来给预览命名，不参与渲染。 */
private data class PreviewCoupleTimetableState(
    val name: String,
    val binding: PartnerTimetableBindingModel?,
    val webdavConnected: Boolean,
    val busy: CoupleBusyState = CoupleBusyState(),
)

private val previewCoupleTimetableStates: List<PreviewCoupleTimetableState> = listOf(
    PreviewCoupleTimetableState(
        name = "已绑定·已连接",
        binding = previewCoupleBinding(),
        webdavConnected = true,
    ),
    PreviewCoupleTimetableState(
        name = "未绑定·未连接",
        binding = null,
        webdavConnected = false,
    ),
    PreviewCoupleTimetableState(
        name = "导入中",
        binding = previewCoupleBinding(),
        webdavConnected = true,
        busy = CoupleBusyState(isImporting = true),
    ),
)

private fun previewCoupleTimetableState(name: String): PreviewCoupleTimetableState =
    previewCoupleTimetableStates.first { it.name == name }

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewCoupleTimetableSettingsPage(
    state: PreviewCoupleTimetableState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        CoupleTimetableSettingsPage(
            viewState = CoupleTimetableSettingsLogic.buildViewState(
                binding = state.binding,
                webdavConfig = previewCoupleWebdavConfig(state.webdavConnected),
                hasStoredPassword = state.webdavConnected,
                busy = state.busy,
                partnerCourseCount = 24,
                partnerProfileName = state.binding?.partnerName,
                myWeek = 8,
                partnerWeek = 8 + (state.binding?.weekOffset ?: 0),
            ),
            onBack = {},
            onAction = {},
            onShiftWeekOffset = {},
            onPickColor = { _, _ -> },
        )
    }
}

// ── 单档：三态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 已绑定·已连接", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CoupleTimetableSettingsPagePreviewBound() {
    PreviewCoupleTimetableSettingsPage(previewCoupleTimetableState("已绑定·已连接"))
}

@Suppress("unused")
@Preview(name = "2 未绑定·未连接", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CoupleTimetableSettingsPagePreviewUnbound() {
    PreviewCoupleTimetableSettingsPage(previewCoupleTimetableState("未绑定·未连接"))
}

@Suppress("unused")
@Preview(name = "3 导入中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CoupleTimetableSettingsPagePreviewImporting() {
    PreviewCoupleTimetableSettingsPage(previewCoupleTimetableState("导入中"))
}

// ── 单档：外观两档（以「已绑定·已连接」为基准）─────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CoupleTimetableSettingsPagePreviewDark() {
    PreviewCoupleTimetableSettingsPage(previewCoupleTimetableState("已绑定·已连接"), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CoupleTimetableSettingsPagePreviewLargeText() {
    PreviewCoupleTimetableSettingsPage(previewCoupleTimetableState("已绑定·已连接"), textScale = 1.3f)
}
