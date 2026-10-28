package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Remove

/**
 * 情侣课表设置页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/couple_timetable_settings_screen.dart`：
 * 绑定信息 → 坚果云拉取（状态 / 远程路径 / 上次拉取 / 动作按钮）→
 * 情侣课表三个动作（导出 / 导入 / 解除）→ 周次偏移 → 叠加颜色。
 *
 * 未绑定、未连接、忙碌态的显隐与文案全部来自 [CoupleTimetableSettingsViewState]，
 * 这里只摆位置、把点击转成按 id 的回调。
 */
@Composable
fun CoupleTimetableSettingsPage(
    viewState: CoupleTimetableSettingsViewState,
    onBack: () -> Unit,
    onAction: (actionId: String) -> Unit,
    onShiftWeekOffset: (delta: Int) -> Unit,
    onPickColor: (rowIndex: Int, hex: String) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(title = viewState.title, onBack = onBack, smallTopBar = true) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {

            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                horizontalPadding = 16.dp,
                contentPadding = PaddingValues(top = 4.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // ── 1. 绑定状态 + 对方信息 ──
                item(key = "binding") {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        SectionHeader(viewState.sectionTitle, dark)
                        Spacer(modifier = Modifier.height(6.dp))
                        if (viewState.bound) {
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                            ) {
                                InfoRow(
                                    label = viewState.partnerNameLabel,
                                    value = viewState.partnerName,
                                    dark = dark,
                                )
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
                        SectionHeader(viewState.webdavTitle, dark)
                        Spacer(modifier = Modifier.height(6.dp))
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            Text(
                                text = viewState.webdavStatusText,
                                style = MiuixTheme.textStyles.body1,
                                fontWeight = FontWeight.Medium,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = viewState.webdavRemotePathText,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                            viewState.webdavLastPulledText?.let { lastPulled ->
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = lastPulled,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                            Spacer(modifier = Modifier.height(10.dp))
                            ActionButtonColumn(buttons = viewState.webdavButtons, onAction = onAction)
                        }
                    }
                }

                // ── 3. 情侣课表动作 ──
                item(key = "couple_actions") {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        SectionHeader(viewState.coupleSectionTitle, dark)
                        Spacer(modifier = Modifier.height(6.dp))
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            ActionButtonColumn(buttons = viewState.coupleButtons, onAction = onAction)
                        }
                    }
                }

                // ── 4. 周次偏移（未绑定不出现） ──
                if (viewState.showWeekOffset) {
                    item(key = "week_offset") {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            SectionHeader(viewState.weekOffsetTitle, dark)
                            Spacer(modifier = Modifier.height(6.dp))
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(horizontal = 14.dp, vertical = 14.dp),
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
                                    Text(
                                        text = viewState.weekOffsetLabel,
                                        style = MiuixTheme.textStyles.body1,
                                        fontWeight = FontWeight.Medium,
                                        color = Color(QingyuTheme.primaryText(dark)),
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.weight(1f),
                                    )
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
                                    style = MiuixTheme.textStyles.footnote1,
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
                            SectionHeader(viewState.colorsTitle, dark)
                            Spacer(modifier = Modifier.height(6.dp))
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                            ) {
                                viewState.colorRows.forEachIndexed { index, row ->
                                    if (index > 0) Spacer(modifier = Modifier.height(14.dp))
                                    Text(
                                        text = row.label,
                                        style = MiuixTheme.textStyles.body2,
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
    }
}

@Composable
private fun SectionHeader(title: String, dark: Boolean) {
    // 官方 SmallTitle：自带 28dp 左缘，与「Card 12 + 行内 16」的轴线对齐。
    QingyuSectionTitle(title)
}

@Composable
private fun InfoRow(label: String, value: String, dark: Boolean) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            textAlign = TextAlign.End,
        )
    }
}

/** 一组动作按钮：每行一个，loading 时左侧转圈、禁用时不可点。 */
@Composable
private fun ActionButtonColumn(
    buttons: List<CoupleActionButton>,
    onAction: (String) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (button in buttons) {
            Button(
                onClick = { onAction(button.id) },
                enabled = button.enabled,
                modifier = Modifier.fillMaxWidth(),
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

/** 周次偏移的 −/+ 圆形按钮（禁用时降到 35% 透明，Dart 同口径）。 */
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

/** 颜色快选：一行 8 个圆形色块（超出换行），选中的加一圈主题色描边。 */
@Composable
private fun ColorChipRow(
    row: CoupleColorRowView,
    dark: Boolean,
    onPick: (String) -> Unit,
) {
    val selected = row.selectedHex.uppercase()
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (chunk in row.paletteHexes.chunked(8)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (hex in chunk) {
                    val isSelected = hex.uppercase() == selected
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(parseHexColor(hex))
                            .then(
                                if (isSelected) {
                                    Modifier.border(
                                        width = 2.dp,
                                        color = Color(QingyuTheme.primary(dark = dark)),
                                        shape = RoundedCornerShape(999.dp),
                                    )
                                } else {
                                    Modifier
                                },
                            )
                            .clickable { onPick(hex) },
                    )
                }
            }
        }
    }
}

private fun parseHexColor(hex: String): Color {
    val trimmed = hex.trim().removePrefix("#")
    return try {
        when (trimmed.length) {
            6 -> Color(trimmed.toLong(16) or 0xFF000000)
            8 -> Color(trimmed.toLong(16))
            else -> Color(0xFF2196F3)
        }
    } catch (_: NumberFormatException) {
        Color(0xFF2196F3)
    }
}
