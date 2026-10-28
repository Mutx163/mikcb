package com.mutx163.qingyu.pages.live

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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.roundToInt
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Slider
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 实时活动与超级岛设置页 · Compose 渲染层（Phase 3 P3-J）。
 *
 * 对应 Flutter `lib/screens/live_settings_subpages.dart`：
 * - Miuix 风格顶栏（返回 + "实时活动设置"）
 * - 实时活动卡片预览区（[LivePreviewCard]，动态演示标准胶囊 / 小卡片 / 极简文字展开态）
 * - 核心开关行（实时活动主开关、超级岛灵动开关、课中进度条开关）
 * - 提前提醒时间滑块（5..60 分钟）
 * - 下课后驻留时间滑块（0..30 分钟）
 * - 样式选择列表（标准胶囊、小卡片、极简文字）
 * - 保存与恢复默认配置操作
 */
@Composable
fun LiveSettingsPage(
    state: LiveSettingsState,
    onStateChange: (LiveSettingsState) -> Unit,
    onBack: () -> Unit,
    onSave: () -> Unit = {},
    onResetDefaults: () -> Unit = {},
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme

    QingyuPageScaffold(
        title = LiveStrings.liveActivitySettingsTitle,
        onBack = onBack,
        smallTopBar = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 28.dp),
            ) {
                // ── 实时活动卡片预览区 ──
                item {
                    LivePreviewCard(state = state, dark = dark)
                }

                // ── 核心开关组 ──
                item {
                    LiveSectionTitle(text = "核心功能")
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    ) {
                        Column {
                            LiveSwitchRow(
                                title = "开启实时活动",
                                subtitle = LiveStrings.liveActivityEnableSubtitle,
                                checked = state.isLiveEnabled,
                                onCheckedChange = { onStateChange(state.withToggledLive()) },
                                dark = dark,
                            )
                            HorizontalDivider(
                                modifier = Modifier.padding(vertical = 4.dp),
                                color = Color(QingyuTheme.dividerLine(dark)),
                            )
                            LiveSwitchRow(
                                title = LiveStrings.enableIslandDisplayTitle.zh,
                                subtitle = "在状态栏灵动胶囊中实时展示",
                                checked = state.showIsland && state.isLiveEnabled,
                                onCheckedChange = { onStateChange(state.withToggledIsland()) },
                                enabled = state.isLiveEnabled,
                                dark = dark,
                            )
                            HorizontalDivider(
                                modifier = Modifier.padding(vertical = 4.dp),
                                color = Color(QingyuTheme.dividerLine(dark)),
                            )
                            LiveSwitchRow(
                                title = "课中显示进度条",
                                subtitle = "在课中阶段实时展示课程时间流逝进度",
                                checked = state.showOngoingProgress && state.isLiveEnabled,
                                onCheckedChange = { onStateChange(state.withToggledOngoingProgress()) },
                                enabled = state.isLiveEnabled,
                                dark = dark,
                            )
                        }
                    }
                }

                // ── 提醒时间阈值 ──
                item {
                    LiveSectionTitle(text = "提醒时间阈值")
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            // 提前提醒时间
                            Column {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = LiveStrings.beforeClassReminderTitle.zh,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Color(QingyuTheme.primaryText(dark)),
                                    )
                                    Text(
                                        text = LiveStrings.formatLeadMinutes(state.leadMinutesBeforeClass),
                                        fontSize = 13.sp,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                    )
                                }
                                Slider(
                                    value = state.leadMinutesBeforeClass.toFloat(),
                                    onValueChange = { onStateChange(state.withLeadMinutes(it.roundToInt())) },
                                    valueRange = LiveSettingsModel.MIN_LEAD_MINUTES.toFloat()..LiveSettingsModel.MAX_LEAD_MINUTES.toFloat(),
                                    steps = 10,
                                    enabled = state.isLiveEnabled,
                                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                                )
                            }

                            HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))

                            // 下课后驻留时间
                            Column {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = LiveStrings.liveReminderDismissAfterClass,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Color(QingyuTheme.primaryText(dark)),
                                    )
                                    Text(
                                        text = LiveStrings.formatKeepMinutes(state.keepMinutesAfterClass),
                                        fontSize = 13.sp,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                    )
                                }
                                Slider(
                                    value = state.keepMinutesAfterClass.toFloat(),
                                    onValueChange = { onStateChange(state.withKeepMinutes(it.roundToInt())) },
                                    valueRange = LiveSettingsModel.MIN_KEEP_MINUTES.toFloat()..LiveSettingsModel.MAX_KEEP_MINUTES.toFloat(),
                                    steps = 5,
                                    enabled = state.isLiveEnabled,
                                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                                )
                            }
                        }
                    }
                }

                // ── 样式选择 ──
                item {
                    LiveSectionTitle(text = LiveStrings.liveIslandStyleTitle)
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    ) {
                        Column {
                            LiveIslandStyle.entries.forEachIndexed { index, style ->
                                if (index > 0) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(vertical = 4.dp),
                                        color = Color(QingyuTheme.dividerLine(dark)),
                                    )
                                }
                                LiveStyleOptionRow(
                                    style = style,
                                    isSelected = state.islandStyle == style,
                                    onClick = { onStateChange(state.withIslandStyle(style)) },
                                    dark = dark,
                                )
                            }
                        }
                    }
                }

                // ── 保存与恢复默认操作 ──
                item {
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        TextButton(
                            text = LiveStrings.resetDefaultAction.zh,
                            onClick = onResetDefaults,
                            modifier = Modifier.weight(1f),
                        )
                        Button(
                            content = { Text(text = "保存设置") },
                            onClick = onSave,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 状态化重载封装（便于独立预览与简单挂载）。
 */
@Composable
fun LiveSettingsPage(
    initialState: LiveSettingsState = LiveSettingsState(),
    onBack: () -> Unit,
    onSave: (LiveSettingsState) -> Unit = {},
) {
    var state by remember { mutableStateOf(initialState) }
    LiveSettingsPage(
        state = state,
        onStateChange = { state = it },
        onBack = onBack,
        onSave = { onSave(state) },
        onResetDefaults = { state = state.resetDefaults() },
    )
}

/**
 * 实时活动卡片预览组件（LivePreviewCard）。
 */
@Composable
private fun LivePreviewCard(
    state: LiveSettingsState,
    dark: Boolean,
) {
    val colors = MiuixTheme.colorScheme

    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 预览小标题与当前状态
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = LiveStrings.liveIslandPreviewTitle.zh,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.sectionLabel(dark)),
                )
                Text(
                    text = if (state.isLiveEnabled) "实时演示中" else "已停用",
                    fontSize = 12.sp,
                    color = if (state.isLiveEnabled) colors.primary else Color(QingyuTheme.secondaryText(dark)),
                )
            }

            // 仿灵动岛 / 实时通知胶囊容器
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(if (dark) Color(0xFF1E1E1E) else Color(0xFF111111))
                    .padding(horizontal = 16.dp, vertical = 14.dp),
            ) {
                if (!state.isLiveEnabled) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "实时活动已关闭，开启后可预览胶囊效果",
                            fontSize = 13.sp,
                            color = Color(0xFF888888),
                        )
                    }
                } else {
                    when (state.islandStyle) {
                        LiveIslandStyle.STANDARD -> StandardIslandPreview(state = state)
                        LiveIslandStyle.CARD -> CardIslandPreview(state = state)
                        LiveIslandStyle.MINIMAL -> MinimalIslandPreview(state = state)
                    }
                }
            }
        }
    }
}

/**
 * 标准灵动胶囊预览态。
 */
@Composable
private fun StandardIslandPreview(state: LiveSettingsState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF333333)),
                contentAlignment = Alignment.Center,
            ) {
                Text(text = "课", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color.White)
            }
            Column {
                Text(
                    text = LiveStrings.liveIslandPreviewSampleCourse.zh,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                )
                Text(
                    text = LiveStrings.liveIslandPreviewSampleLocation.zh,
                    fontSize = 11.sp,
                    color = Color(0xFFAAAAAA),
                )
            }
        }

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFF2B2B2B))
                .padding(horizontal = 10.dp, vertical = 6.dp),
        ) {
            Text(
                text = LiveStrings.formatUntilClassStart("18:24"),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = Color(0xFF64B5F6),
            )
        }
    }
}

/**
 * 展开小卡片预览态。
 */
@Composable
private fun CardIslandPreview(state: LiveSettingsState) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = LiveStrings.liveIslandPreviewTitleBeforeClass.filled("course", LiveStrings.liveIslandPreviewSampleCourse.zh),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
            )
            Text(
                text = "18:24",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF64B5F6),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "${LiveStrings.liveIslandPreviewSampleLocation.zh} · ${LiveStrings.liveIslandPreviewSampleTeacher.zh}",
                fontSize = 12.sp,
                color = Color(0xFFAAAAAA),
            )
            Text(
                text = "下一节：${LiveStrings.liveIslandPreviewSampleNextClass.zh}",
                fontSize = 12.sp,
                color = Color(0xFF888888),
            )
        }

        if (state.showOngoingProgress) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color(0xFF333333)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.45f)
                        .height(4.dp)
                        .background(Color(0xFF4CAF50)),
                )
            }
        }
    }
}

/**
 * 极简文字预览态。
 */
@Composable
private fun MinimalIslandPreview(state: LiveSettingsState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "${LiveStrings.liveIslandPreviewSampleCourseShort.zh} · ${LiveStrings.liveIslandPreviewSampleLocation.zh}",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White,
        )
        Text(
            text = "18:24",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFF81C784),
        )
    }
}

/**
 * 开关设置行。
 */
@Composable
private fun LiveSwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    dark: Boolean,
    enabled: Boolean = true,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = if (enabled) Color(QingyuTheme.primaryText(dark)) else Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = subtitle,
                fontSize = 12.sp,
                lineHeight = 16.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = if (enabled) onCheckedChange else { _ -> },
        )
    }
}

/**
 * 样式选项行。
 */
@Composable
private fun LiveStyleOptionRow(
    style: LiveIslandStyle,
    isSelected: Boolean,
    onClick: () -> Unit,
    dark: Boolean,
) {
    val colors = MiuixTheme.colorScheme

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(
                text = style.label,
                fontSize = 15.sp,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) colors.primary else Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = style.description,
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }

        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(CircleShape)
                .border(
                    width = 2.dp,
                    color = if (isSelected) colors.primary else Color(QingyuTheme.secondaryText(dark)),
                    shape = CircleShape,
                )
                .padding(3.dp),
        ) {
            if (isSelected) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircleShape)
                        .background(colors.primary),
                )
            }
        }
    }
}

/**
 * 分组小标题。
 */
@Composable
private fun LiveSectionTitle(text: String) {
    val dark = isSystemInDarkTheme()
    Text(
        text = text,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Color(QingyuTheme.sectionLabel(dark)),
        modifier = Modifier.padding(start = 4.dp, top = 4.dp, bottom = 2.dp),
    )
}
