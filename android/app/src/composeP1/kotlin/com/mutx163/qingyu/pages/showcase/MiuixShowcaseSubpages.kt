package com.mutx163.qingyu.pages.showcase

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Slider
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.extra.SuperArrow
import top.yukonga.miuix.kmp.extra.SuperCheckbox
import top.yukonga.miuix.kmp.extra.SuperRadioButton
import top.yukonga.miuix.kmp.extra.SuperSwitch
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Check
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.overlay.OverlayDialog

/**
 * 分类详情视图分发路由。
 */
@Composable
fun MiuixShowcaseCategoryDetail(
    category: ShowcaseCategoryId,
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        when (category) {
            ShowcaseCategoryId.BUTTONS -> item {
                ShowcaseButtonsSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.INPUTS -> item {
                ShowcaseInputsSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.MENUS -> item {
                ShowcaseMenusSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.DISPLAY -> item {
                ShowcaseDisplaySection(dark, primaryColor)
            }
            ShowcaseCategoryId.PREFERENCES -> item {
                ShowcasePreferencesSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.PICKERS -> item {
                ShowcasePickersSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.FEEDBACK -> item {
                ShowcaseFeedbackSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.OVERLAYS -> item {
                ShowcaseOverlaysSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.NAVIGATION -> item {
                ShowcaseNavigationSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.UTILITY -> item {
                ShowcaseUtilitySection(dark, primaryColor)
            }
            ShowcaseCategoryId.THEMING -> item {
                ShowcaseThemingSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.BLUR -> item {
                ShowcaseBlurSection(state, onStateChange, dark, primaryColor)
            }
            ShowcaseCategoryId.FOUNDATION -> item {
                ShowcaseFoundationSection(state, onStateChange, dark, primaryColor)
            }
        }
    }
}

// ─────────────────────────────────────────────
// 1. 按钮展示
// ─────────────────────────────────────────────
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ShowcaseButtonsSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "MiuixButton · 基础按钮")
        Card(insideMargin = PaddingValues(16.dp)) {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = { onStateChange(state.onButtonClick("Primary")) }
                ) {
                    Text(ShowcaseStrings.btnPrimary.zh)
                }
                Button(
                    onClick = { onStateChange(state.onButtonClick("Secondary")) }
                ) {
                    Text(ShowcaseStrings.btnSecondary.zh)
                }
                Button(
                    onClick = { onStateChange(state.onButtonClick("Error")) }
                ) {
                    Text(ShowcaseStrings.btnError.zh)
                }
                Button(
                    onClick = {},
                    enabled = false
                ) {
                    Text(ShowcaseStrings.btnDisabled.zh)
                }
            }
        }

        SmallTitle(text = "MiuixTextButton · 文本按钮")
        Card(insideMargin = PaddingValues(16.dp)) {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                TextButton(
                    text = ShowcaseStrings.btnConfirm.zh,
                    onClick = { onStateChange(state.onButtonClick("确定")) }
                )
                TextButton(
                    text = ShowcaseStrings.btnCancel.zh,
                    onClick = { onStateChange(state.onButtonClick("取消")) }
                )
                TextButton(
                    text = ShowcaseStrings.btnDisabledZh.zh,
                    onClick = {},
                    enabled = false
                )
            }
        }

        SmallTitle(text = "MiuixIconButton · 图标按钮")
        Card(insideMargin = PaddingValues(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                IconButton(onClick = { onStateChange(state.onButtonClick("Favorites")) }) {
                    Icon(imageVector = MiuixIcons.Favorites, contentDescription = "收藏", tint = primaryColor)
                }
                IconButton(onClick = { onStateChange(state.onButtonClick("Share")) }) {
                    Icon(imageVector = MiuixIcons.Share, contentDescription = "分享", tint = primaryColor)
                }
                IconButton(onClick = { onStateChange(state.onButtonClick("Settings")) }) {
                    Icon(imageVector = MiuixIcons.Settings, contentDescription = "设置", tint = primaryColor)
                }
                IconButton(onClick = { onStateChange(state.onButtonClick("Delete")) }) {
                    Icon(
                        imageVector = MiuixIcons.Delete,
                        contentDescription = "删除",
                        tint = Color(0xFFFF3B30)
                    )
                }
            }
        }

        if (state.buttonClickCount > 0) {
            Text(
                text = "点击记录：${state.lastClickedButton} (累计 ${state.buttonClickCount} 次)",
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(horizontal = 4.dp)
            )
        }
    }
}

// ─────────────────────────────────────────────
// 2. 输入展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseInputsSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "MiuixTextField · 文本输入")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TextField(
                    value = state.usernameInput,
                    onValueChange = { onStateChange(state.setUsername(it)) },
                    label = ShowcaseStrings.inputUsername.zh,
                    modifier = Modifier.fillMaxWidth()
                )
                TextField(
                    value = "******",
                    onValueChange = {},
                    label = ShowcaseStrings.inputPassword.zh,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }

        SmallTitle(text = "MiuixSwitch · 开关控件")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(ShowcaseStrings.inputWifi.zh, fontSize = 15.sp)
                    Switch(
                        checked = state.wifiEnabled,
                        onCheckedChange = { onStateChange(state.toggleWifi()) }
                    )
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(ShowcaseStrings.inputBluetooth.zh, fontSize = 15.sp)
                    Switch(
                        checked = state.bluetoothEnabled,
                        onCheckedChange = { onStateChange(state.toggleBluetooth()) }
                    )
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(ShowcaseStrings.inputAirplane.zh, fontSize = 15.sp)
                    Switch(
                        checked = state.airplaneMode,
                        onCheckedChange = { onStateChange(state.toggleAirplaneMode()) }
                    )
                }
            }
        }

        SmallTitle(text = "MiuixCheckbox & Radio · 复选与单选")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onStateChange(state.toggleRememberPassword()) },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = state.rememberPassword,
                        onCheckedChange = { onStateChange(state.toggleRememberPassword()) }
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(ShowcaseStrings.inputRememberPassword.zh, fontSize = 15.sp)
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onStateChange(state.cycleTriState()) },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = state.triState == true,
                        onCheckedChange = { onStateChange(state.cycleTriState()) }
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        "${ShowcaseStrings.inputTriState.zh} (状态: ${state.triState})",
                        fontSize = 15.sp
                    )
                }
            }
        }

        SmallTitle(text = "MiuixSlider · 滑块")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    "${ShowcaseStrings.inputContinuousSlider.zh}: ${(state.continuousSliderValue * 100).toInt()}%",
                    fontSize = 14.sp
                )
                Slider(
                    value = state.continuousSliderValue,
                    onValueChange = { onStateChange(state.setContinuousSlider(it)) },
                    modifier = Modifier.fillMaxWidth()
                )
                HorizontalDivider()
                Text(
                    "${ShowcaseStrings.inputSteppedSlider.zh}: ${state.steppedSliderValue} 档",
                    fontSize = 14.sp
                )
                Slider(
                    value = state.steppedSliderValue.toFloat() / 10f,
                    onValueChange = { onStateChange(state.setSteppedSlider((it * 10).toInt())) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

// ─────────────────────────────────────────────
// 3. 菜单展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseMenusSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    val options = listOf("红色", "绿色", "蓝色", "黄色")
    val swatchColors = listOf(Color(0xFFFF5B29), Color(0xFF34C759), Color(0xFF3482FF), Color(0xFFFFB21D))

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "Dropdown 菜单选择演示")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                options.forEachIndexed { index, name ->
                    if (index > 0) HorizontalDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onStateChange(state.setDropdownIndex(index)) }
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(20.dp)
                                    .clip(CircleShape)
                                    .background(swatchColors[index])
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(name, fontSize = 15.sp)
                        }
                        if (state.dropdownSelectedIndex == index) {
                            Icon(
                                imageVector = MiuixIcons.Check,
                                contentDescription = "已选",
                                tint = primaryColor,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// 4. 显示组件展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseDisplaySection(
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "MiuixText · 字阶规范")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Title 1 示例文本", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text("Headline 示例文本", fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                Text("Subtitle 示例文本", fontSize = 17.sp, fontWeight = FontWeight.Medium)
                Text("Body 1 示例文本", fontSize = 15.sp)
                Text("Footnote 示例文本", fontSize = 12.sp, color = Color(QingyuTheme.secondaryText(dark)))
            }
        }

        SmallTitle(text = "MiuixCard · 卡片容器")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("强调态主色卡片", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = primaryColor)
                Text(
                    "使用 RoundedCornerShape 与 squircle 连续曲率平滑边框，带来澎湃 OS 现代美学感受。",
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }

        SmallTitle(text = "BasicComponent · 基础图文混排")
        Card(insideMargin = PaddingValues(16.dp)) {
            BasicComponent(
                title = "带图标的基础列表行",
                summary = "支持 startAction 与 endActions 自由插槽",
                leftAction = {
                    Icon(
                        imageVector = MiuixIcons.Info,
                        contentDescription = null,
                        tint = primaryColor,
                        modifier = Modifier.size(20.dp)
                    )
                }
            )
        }
    }
}

// ─────────────────────────────────────────────
// 5. 偏好设置项展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcasePreferencesSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "SuperPreference 族 · 澎湃设置行规范")
        Card(insideMargin = PaddingValues(12.dp)) {
            Column {
                SuperArrow(
                    title = ShowcaseStrings.prefSecurity.zh,
                    summary = ShowcaseStrings.prefSecuritySummary.zh,
                    onClick = {}
                )
                HorizontalDivider()
                SuperArrow(
                    title = ShowcaseStrings.prefGeneral.zh,
                    onClick = {}
                )
                HorizontalDivider()
                SuperSwitch(
                    title = ShowcaseStrings.prefLocation.zh,
                    checked = state.locationEnabled,
                    onCheckedChange = { onStateChange(state.toggleLocation()) }
                )
                HorizontalDivider()
                SuperCheckbox(
                    title = ShowcaseStrings.inputRememberPassword.zh,
                    checked = state.rememberPassword,
                    onCheckedChange = { onStateChange(state.toggleRememberPassword()) }
                )
            }
        }

        SmallTitle(text = "单选群组 · 主题模式")
        Card(insideMargin = PaddingValues(12.dp)) {
            Column {
                val themes = listOf(
                    ShowcaseStrings.prefThemeFollowSystem.zh,
                    ShowcaseStrings.prefThemeLight.zh,
                    ShowcaseStrings.prefThemeDark.zh
                )
                themes.forEachIndexed { index, name ->
                    if (index > 0) HorizontalDivider()
                    SuperRadioButton(
                        title = name,
                        selected = state.themeModeIndex == index,
                        onClick = { onStateChange(state.setThemeModeIndex(index)) }
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// 6. 选择器展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcasePickersSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    val spaces = listOf("HSV", "OkHSV", "OkLab", "OkLch")
    val timeFormatted = "%02d:%02d".format(state.pickerHour, state.pickerMinute)

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "NumberPicker · 时间滚轮选择器")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = ShowcaseStrings.pickerCurrentTime.filled("time", timeFormatted),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = primaryColor
                )
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        IconButton(onClick = { onStateChange(state.adjustHour(1)) }) {
                            Icon(imageVector = MiuixIcons.Add, contentDescription = "+1小时")
                        }
                        Text("${state.pickerHour} 时", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        IconButton(onClick = { onStateChange(state.adjustHour(-1)) }) {
                            Icon(imageVector = MiuixIcons.Remove, contentDescription = "-1小时")
                        }
                    }

                    Text(":", fontSize = 24.sp, fontWeight = FontWeight.Bold)

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        IconButton(onClick = { onStateChange(state.adjustMinute(5)) }) {
                            Icon(imageVector = MiuixIcons.Add, contentDescription = "+5分")
                        }
                        Text("${state.pickerMinute} 分", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        IconButton(onClick = { onStateChange(state.adjustMinute(-5)) }) {
                            Icon(imageVector = MiuixIcons.Remove, contentDescription = "-5分")
                        }
                    }
                }
            }
        }

        SmallTitle(text = "色彩空间选择")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    ShowcaseStrings.pickerColorSpace.filled("space", spaces[state.pickerColorSpaceIndex]),
                    fontSize = 14.sp,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    spaces.forEachIndexed { idx, sp ->
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (state.pickerColorSpaceIndex == idx) primaryColor
                                    else primaryColor.copy(alpha = 0.1f)
                                )
                                .clickable { onStateChange(state.setColorSpaceIndex(idx)) }
                                .padding(vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = sp,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (state.pickerColorSpaceIndex == idx) Color.White else primaryColor
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// 7. 反馈展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseFeedbackSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "MiuixDialog · 对话框")
        Card(insideMargin = PaddingValues(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onStateChange(state.showBasicDialog(true)) }
                ) {
                    Text("普通对话框")
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onStateChange(state.showConfirmDialog(true)) }
                ) {
                    Text("确认对话框")
                }
            }
        }

        SmallTitle(text = "ProgressIndicator · 进度")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(28.dp))
                    Text("环形旋转进度指示器", fontSize = 14.sp)
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("线性进度：${(state.progress * 100).toInt()}%", fontSize = 14.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(
                            text = "+20%",
                            onClick = { onStateChange(state.stepProgress(0.2f)) }
                        )
                        TextButton(
                            text = "重置",
                            onClick = { onStateChange(state.resetProgress()) }
                        )
                    }
                }
            }
        }

        // 弹窗对话框实体
        OverlayDialog(
            show = state.isBasicDialogOpen,
            title = ShowcaseStrings.feedbackDialogTitle.zh,
            summary = ShowcaseStrings.feedbackDialogMessage.zh,
            onDismissRequest = { onStateChange(state.showBasicDialog(false)) }
        ) {
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { onStateChange(state.showBasicDialog(false)) }
            ) {
                Text(ShowcaseStrings.feedbackKnown.zh)
            }
        }

        OverlayDialog(
            show = state.isConfirmDialogOpen,
            title = ShowcaseStrings.feedbackConfirmTitle.zh,
            summary = ShowcaseStrings.feedbackConfirmMessage.zh,
            onDismissRequest = { onStateChange(state.showConfirmDialog(false)) }
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ShowcaseStrings.btnCancel.zh,
                    onClick = { onStateChange(state.showConfirmDialog(false)) }
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onStateChange(state.showConfirmDialog(false)) }
                ) {
                    Text(ShowcaseStrings.btnConfirm.zh)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// 8. 浮层展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseOverlaysSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "OverlayBottomSheet · 底部弹窗")
        Card(insideMargin = PaddingValues(16.dp)) {
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { onStateChange(state.showBottomSheet(true)) }
            ) {
                Text("弹出底部抽屉")
            }
        }

        SmallTitle(text = "FloatingToolbar · 悬浮工具栏")
        Card(insideMargin = PaddingValues(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    ShowcaseStrings.overlayCounterLabel.filled("count", state.counter.toString()),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    IconButton(onClick = { onStateChange(state.decrementCounter()) }) {
                        Icon(imageVector = MiuixIcons.Remove, contentDescription = "-1")
                    }
                    IconButton(onClick = { onStateChange(state.incrementCounter()) }) {
                        Icon(imageVector = MiuixIcons.Add, contentDescription = "+1")
                    }
                }
            }
        }

        OverlayBottomSheet(
            show = state.isBottomSheetOpen,
            title = ShowcaseStrings.overlaySheetTitle.zh,
            onDismissRequest = { onStateChange(state.showBottomSheet(false)) }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = ShowcaseStrings.overlaySheetContent.zh,
                    fontSize = 14.sp,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { onStateChange(state.showBottomSheet(false)) }
                ) {
                    Text(ShowcaseStrings.feedbackKnown.zh)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// 9. 导航展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseNavigationSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    val tabs = listOf(
        ShowcaseStrings.navTabRecommend.zh,
        ShowcaseStrings.navTabFollow.zh,
        ShowcaseStrings.navTabHot.zh,
        ShowcaseStrings.navTabNearby.zh
    )

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "TabRow · 标签栏")
        Card(insideMargin = PaddingValues(12.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TabRow(
                    tabs = tabs,
                    selectedTabIndex = state.selectedTabRowIndex,
                    onTabSelected = { onStateChange(state.setTabRowIndex(it)) }
                )
                Text(
                    text = ShowcaseStrings.navCurrentSelected.filled("tab", tabs[state.selectedTabRowIndex]),
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }
    }
}

// ─────────────────────────────────────────────
// 10. 实用组件展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseUtilitySection(
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "Surface · 表面容器与滚动")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("阻尼弹性滚动与刷新表面", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    "为课表主视图、日程流与列表提供自然且符合 HyperOS 物理阻尼直觉的滚动边界触感。",
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }
    }
}

// ─────────────────────────────────────────────
// 11. 主题展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseThemingSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    val seeds = listOf(
        0xFF3482FF to "澎湃蓝",
        0xFFFF5B29 to "活力橙",
        0xFF34C759 to "葱郁绿",
        0xFFAF52DE to "优雅紫",
        0xFFFF3B30 to "热情红"
    )

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "DynamicTheme · 动态种子色取色")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(ShowcaseStrings.themeSeedColor.zh, fontSize = 14.sp)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    seeds.forEach { (colorHex, _) ->
                        val isSelected = state.selectedSeedColorHex == colorHex
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(Color(colorHex))
                                .clickable { onStateChange(state.setSeedColor(colorHex)) },
                            contentAlignment = Alignment.Center
                        ) {
                            if (isSelected) {
                                Icon(
                                    imageVector = MiuixIcons.Check,
                                    contentDescription = "选中",
                                    tint = Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    }
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(ShowcaseStrings.themeModeLabel.zh, fontSize = 15.sp)
                    Switch(
                        checked = state.isDarkTheme,
                        onCheckedChange = { onStateChange(state.toggleDarkTheme()) }
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// 12. 模糊展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseBlurSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "TextureBlur · 液态玻璃与模糊控制")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // 模拟模糊卡片预览
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(110.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            primaryColor.copy(alpha = (state.blurRadius / 100f).coerceIn(0.15f, 0.85f))
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "液态玻璃预览\nR=${state.blurRadius.toInt()} · Sat=${state.blurSaturation}",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                Text(
                    ShowcaseStrings.blurRadiusLabel.filled("radius", state.blurRadius.toInt().toString()),
                    fontSize = 14.sp
                )
                Slider(
                    value = state.blurRadius / 60f,
                    onValueChange = { onStateChange(state.setBlurRadius(it * 60f)) },
                    modifier = Modifier.fillMaxWidth()
                )

                Text(
                    ShowcaseStrings.blurSaturationLabel.filled(
                        "saturation",
                        "%.1f".format(state.blurSaturation)
                    ),
                    fontSize = 14.sp
                )
                Slider(
                    value = state.blurSaturation / 2f,
                    onValueChange = { onStateChange(state.setBlurSaturation(it * 2f)) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

// ─────────────────────────────────────────────
// 13. 基础与曲率圆角展示
// ─────────────────────────────────────────────
@Composable
private fun ShowcaseFoundationSection(
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color
) {
    val hapticTypes = listOf("选择", "轻", "中", "重")

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SmallTitle(text = "SquircleBorder · 平滑曲率圆角")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp)
                        .clip(RoundedCornerShape(state.squircleRadius.dp))
                        .background(primaryColor),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "Squircle R=${state.squircleRadius.toInt()}dp",
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }

                Text(
                    ShowcaseStrings.foundationRadiusLabel.filled(
                        "radius",
                        state.squircleRadius.toInt().toString()
                    ),
                    fontSize = 14.sp
                )
                Slider(
                    value = state.squircleRadius / 48f,
                    onValueChange = { onStateChange(state.setSquircleRadius(it * 48f)) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }

        SmallTitle(text = "ScrollEndHaptic · 触觉反馈类型")
        Card(insideMargin = PaddingValues(12.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                TabRow(
                    tabs = hapticTypes,
                    selectedTabIndex = state.hapticTypeIndex,
                    onTabSelected = { onStateChange(state.setHapticTypeIndex(it)) }
                )
                Text(
                    ShowcaseStrings.foundationHapticLabel.filled(
                        "type",
                        hapticTypes[state.hapticTypeIndex]
                    ),
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }
    }
}
