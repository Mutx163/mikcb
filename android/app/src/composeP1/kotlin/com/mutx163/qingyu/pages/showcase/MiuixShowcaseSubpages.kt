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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuSlider
import com.mutx163.qingyu.theme.QingyuFixedTokens
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.roundToInt
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.blur.BlurDefaults
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.blur.textureBlur
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.CheckboxPreference
import top.yukonga.miuix.kmp.preference.RadioButtonPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 分类详情视图分发路由。
 *
 * 页面级滚动走共享套件 `QingyuPageList`（R2：官方三件套 + 右侧滚动条 + 顶栏折叠联动），
 * `innerPadding` 与 `scrollBehavior` 由调用它的 [MiuixShowcasePage] 从骨架里取。
 */
@Composable
fun MiuixShowcaseCategoryDetail(
    category: ShowcaseCategoryId,
    state: ShowcaseInteractionState,
    onStateChange: (ShowcaseInteractionState) -> Unit,
    dark: Boolean,
    primaryColor: Color,
    innerPadding: PaddingValues,
    scrollBehavior: ScrollBehavior?,
) {
    QingyuPageList(
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
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
            ShowcaseCategoryId.BLUR -> {
                item {
                    ShowcaseBlurSection(state, onStateChange, dark, primaryColor)
                }
                // 深水区视觉效果（G4–G8，照抄官方 demo），2026-11-03 批次。
                item {
                    ShowcaseDeepGlassSection(dark, primaryColor)
                }
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
                        // 危险色取固定 token（亮暗同值），不再写字面量（R5）。
                        tint = Color(QingyuFixedTokens.DESTRUCTIVE)
                    )
                }
            }
        }

        if (state.buttonClickCount > 0) {
            Text(
                text = "点击记录：${state.lastClickedButton} (累计 ${state.buttonClickCount} 次)",
                style = MiuixTheme.textStyles.footnote1,
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
                    Text(ShowcaseStrings.inputWifi.zh, style = MiuixTheme.textStyles.body1)
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
                    Text(ShowcaseStrings.inputBluetooth.zh, style = MiuixTheme.textStyles.body1)
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
                    Text(ShowcaseStrings.inputAirplane.zh, style = MiuixTheme.textStyles.body1)
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
                        state = if (state.rememberPassword) ToggleableState.On else ToggleableState.Off,
                        onClick = { onStateChange(state.toggleRememberPassword()) }
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(ShowcaseStrings.inputRememberPassword.zh, style = MiuixTheme.textStyles.body1)
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onStateChange(state.cycleTriState()) },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        state = when (state.triState) {
                            true -> ToggleableState.On
                            false -> ToggleableState.Off
                            null -> ToggleableState.Indeterminate
                        },
                        onClick = { onStateChange(state.cycleTriState()) }
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        "${ShowcaseStrings.inputTriState.zh} (状态: ${state.triState})",
                        style = MiuixTheme.textStyles.body1
                    )
                }
            }
        }

        SmallTitle(text = "MiuixSlider · 滑块")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    "${ShowcaseStrings.inputContinuousSlider.zh}: ${(state.continuousSliderValue * 100).toInt()}%",
                    style = MiuixTheme.textStyles.body2
                )
                QingyuSlider(
                    value = state.continuousSliderValue,
                    onValueChange = { onStateChange(state.setContinuousSlider(it)) },
                    modifier = Modifier.fillMaxWidth()
                )
                HorizontalDivider()
                Text(
                    "${ShowcaseStrings.inputSteppedSlider.zh}: ${state.steppedSliderValue} 档",
                    style = MiuixTheme.textStyles.body2
                )
                // steps = 9 ⇒ 10 个区间 / 11 个档位（0..10）：让滑杆自己量化到档，
                // 演示的才是官方「步进滑杆」能力（Flutter 演示页同样传 steps）。
                QingyuSlider(
                    value = state.steppedSliderValue.toFloat() / 10f,
                    // 四舍五入而不是截断：0.7f 实际是 0.6999999，`toInt()` 会落回 6，
                    // 拖到第 7 档会自己弹回第 6 档。
                    onValueChange = { onStateChange(state.setSteppedSlider((it * 10).roundToInt())) },
                    modifier = Modifier.fillMaxWidth(),
                    steps = 9
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
    // 彩豆取应用层 token（QingyuIconColors，Miuix colorScheme 无对应槽），不写字面量（R5）。
    val swatchColors = listOf(
        Color(QingyuIconColors.RED),
        Color(QingyuIconColors.GREEN),
        Color(QingyuIconColors.BLUE),
        Color(QingyuIconColors.YELLOW),
    )

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
                            Text(name, style = MiuixTheme.textStyles.body1)
                        }
                        if (state.dropdownSelectedIndex == index) {
                            Icon(
                                imageVector = MiuixIcons.Ok,
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
                Text("Title 1 示例文本", style = MiuixTheme.textStyles.title1, fontWeight = FontWeight.Bold)
                Text("Headline 示例文本", style = MiuixTheme.textStyles.title3, fontWeight = FontWeight.SemiBold)
                Text("Subtitle 示例文本", style = MiuixTheme.textStyles.main, fontWeight = FontWeight.Medium)
                Text("Body 1 示例文本", style = MiuixTheme.textStyles.body1)
                Text("Footnote 示例文本", style = MiuixTheme.textStyles.footnote1, color = Color(QingyuTheme.secondaryText(dark)))
            }
        }

        SmallTitle(text = "MiuixCard · 卡片容器")
        Card(insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("强调态主色卡片", style = MiuixTheme.textStyles.body1, fontWeight = FontWeight.SemiBold, color = primaryColor)
                Text(
                    "使用 RoundedCornerShape 与 squircle 连续曲率平滑边框，带来澎湃 OS 现代美学感受。",
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }

        SmallTitle(text = "BasicComponent · 基础图文混排")
        Card(insideMargin = PaddingValues(16.dp)) {
            BasicComponent(
                title = "带图标的基础列表行",
                summary = "支持 startAction 与 endActions 自由插槽",
                startAction = {
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
                ArrowPreference(
                    title = ShowcaseStrings.prefSecurity.zh,
                    summary = ShowcaseStrings.prefSecuritySummary.zh,
                    onClick = {}
                )
                HorizontalDivider()
                ArrowPreference(
                    title = ShowcaseStrings.prefGeneral.zh,
                    onClick = {}
                )
                HorizontalDivider()
                SwitchPreference(
                    title = ShowcaseStrings.prefLocation.zh,
                    checked = state.locationEnabled,
                    onCheckedChange = { onStateChange(state.toggleLocation()) }
                )
                HorizontalDivider()
                CheckboxPreference(
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
                    RadioButtonPreference(
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
                    style = MiuixTheme.textStyles.title4,
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
                        Text("${state.pickerHour} 时", style = MiuixTheme.textStyles.body1, fontWeight = FontWeight.SemiBold)
                        IconButton(onClick = { onStateChange(state.adjustHour(-1)) }) {
                            Icon(imageVector = MiuixIcons.Remove, contentDescription = "-1小时")
                        }
                    }

                    Text(":", style = MiuixTheme.textStyles.title2, fontWeight = FontWeight.Bold)

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        IconButton(onClick = { onStateChange(state.adjustMinute(5)) }) {
                            Icon(imageVector = MiuixIcons.Add, contentDescription = "+5分")
                        }
                        Text("${state.pickerMinute} 分", style = MiuixTheme.textStyles.body1, fontWeight = FontWeight.SemiBold)
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
                    style = MiuixTheme.textStyles.body2,
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
                                style = MiuixTheme.textStyles.footnote1,
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
                    Text("环形旋转进度指示器", style = MiuixTheme.textStyles.body2)
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("线性进度：${(state.progress * 100).toInt()}%", style = MiuixTheme.textStyles.body2)
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
            insideMargin = DpSize(16.dp, 16.dp),
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
            insideMargin = DpSize(16.dp, 16.dp),
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
                    onClick = { onStateChange(state.showConfirmDialog(false)) },
                    // 「确认」是出口键：miuix `Button` 不传 colors 是 secondaryVariant 灰底，
                    // 确认键应走主色（与诊断日志清空确认框同口径）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
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
                    style = MiuixTheme.textStyles.body1,
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

        // 底部弹层走共享套件 [QingyuSheet]（全 App 底栏弹层统一入口，不直调 miuix）：
        // - insideMargin 由套件给本仓口径 16dp —— 此前不传，miuix 默认横向 24 叠上内容
        //   自带的 16 成了单边 40dp；内容自己带 16 ⇒ `contentPadsHorizontally` 归零框架侧。
        // - 底部手势区让位由套件在内容末尾补 Spacer（内容不滚动时自动），不再贴到小白条。
        QingyuSheet(
            show = state.isBottomSheetOpen,
            title = ShowcaseStrings.overlaySheetTitle.zh,
            onDismissRequest = { onStateChange(state.showBottomSheet(false)) },
            contentPadsHorizontally = true,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = ShowcaseStrings.overlaySheetContent.zh,
                    style = MiuixTheme.textStyles.body2,
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
                    style = MiuixTheme.textStyles.footnote1,
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
                Text("阻尼弹性滚动与刷新表面", style = MiuixTheme.textStyles.body1, fontWeight = FontWeight.SemiBold)
                Text(
                    "为课表主视图、日程流与列表提供自然且符合 HyperOS 物理阻尼直觉的滚动边界触感。",
                    style = MiuixTheme.textStyles.footnote1,
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
                Text(ShowcaseStrings.themeSeedColor.zh, style = MiuixTheme.textStyles.body2)
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
                                    imageVector = MiuixIcons.Ok,
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
                    Text(ShowcaseStrings.themeModeLabel.zh, style = MiuixTheme.textStyles.body1)
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
                // ── 真模糊（2026-10-27 修正）──
                //
                // 旧版这里用「主色 + alpha」冒充模糊，而文案写着「背景捕获 + 高斯模糊」——
                // 属于 AGENTS.md COPY-STYLE 里点名要改的「不实说明」。现在走官方
                // `textureBlur`：先铺一层有内容的背景并录进 backdrop，再采样它做高斯模糊，
                // 饱和度滑杆真的接到 `colorControls` 上。
                val backdrop = rememberLayerBackdrop()
                val blurActive = isRuntimeShaderSupported()
                val blurColors = BlurDefaults.blurColors(saturation = state.blurSaturation)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(110.dp)
                        .clip(RoundedCornerShape(16.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    // ① 被捕获层：几条彩带，模糊之后仍看得出结构（纯色块糊完是纯色，看不出效果）
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .layerBackdrop(backdrop),
                    ) {
                        ShowcaseBlurSampleBackground(primaryColor)
                    }
                    // ② 模糊面：采样 ① 并模糊。
                    //    设备不支持 runtime shader 时不叠这一层，直接露出清晰底图 ——
                    //    比糊一块假的诚实。
                    if (blurActive) {
                        Box(
                            modifier = Modifier
                                .matchParentSize()
                                .textureBlur(
                                    backdrop = backdrop,
                                    shape = RoundedCornerShape(16.dp),
                                    blurRadius = state.blurRadius.coerceIn(
                                        0f,
                                        BlurDefaults.MaxBlurRadius,
                                    ),
                                    colors = blurColors,
                                ),
                        )
                    }
                    Text(
                        text = "液态玻璃预览\nR=${state.blurRadius.toInt()} · Sat=${state.blurSaturation}",
                        style = MiuixTheme.textStyles.body1,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                Text(
                    ShowcaseStrings.blurRadiusLabel.filled("radius", state.blurRadius.toInt().toString()),
                    style = MiuixTheme.textStyles.body2
                )
                QingyuSlider(
                    value = state.blurRadius / 60f,
                    onValueChange = { onStateChange(state.setBlurRadius(it * 60f)) },
                    modifier = Modifier.fillMaxWidth()
                )

                Text(
                    ShowcaseStrings.blurSaturationLabel.filled(
                        "saturation",
                        "%.1f".format(state.blurSaturation)
                    ),
                    style = MiuixTheme.textStyles.body2
                )
                QingyuSlider(
                    value = state.blurSaturation / 2f,
                    onValueChange = { onStateChange(state.setBlurSaturation(it * 2f)) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

/**
 * 模糊演示的**采样底图**：几条斜向彩带 + 几个色块。
 *
 * 为什么不用纯色：纯色糊完还是纯色，看不出模糊有没有生效 —— 演示页会失去意义。
 * 用有结构的图形才能一眼看出「边缘被抹开了」。
 *
 * 颜色刻意选高对比（主色 / 青 / 红 / 黄，取 QingyuIconColors 彩豆 token），因为 `vibrancy` 那档加饱和
 * 在高饱和图上才看得出来。
 */
@Composable
private fun ShowcaseBlurSampleBackground(primaryColor: Color) {
    Box(modifier = Modifier.fillMaxSize()) {
        // 主色打底
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(primaryColor),
        )
        // 斜向彩带：给模糊一个明确的"边缘"去抹。
        // 三个色带取应用层彩豆 token（青 / 红 / 黄），只要求彼此高对比，不写字面量（R5）。
        Row(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .background(Color(QingyuIconColors.CYAN)),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .background(Color(QingyuIconColors.RED)),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .background(Color(QingyuIconColors.YELLOW)),
            )
        }
        // 一组圆点：模糊后会变成柔和的光斑，是"糊开了"最直观的证据
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            repeat(4) {
                Box(
                    modifier = Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.9f)),
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
                    style = MiuixTheme.textStyles.body2
                )
                QingyuSlider(
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
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }
    }
}
