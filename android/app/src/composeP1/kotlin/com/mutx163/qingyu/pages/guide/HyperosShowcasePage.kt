package com.mutx163.qingyu.pages.guide

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
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
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSlider
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * HyperOS 澎湃组件规范展示册 · Compose 渲染层。
 * 对应 Flutter `lib/screens/hyperos_showcase_screen.dart`：
 * 供开发与设计做视觉 QA 对照验收。
 */
@Composable
fun HyperosShowcasePage(
    onBack: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    var switchState by remember { mutableStateOf(true) }
    var checkboxState by remember { mutableStateOf(true) }
    var selectedRadio by remember { mutableStateOf("A") }
    var sliderValue by remember { mutableFloatStateOf(0.6f) }
    var sampleInputText by remember { mutableStateOf(GuideStrings.hyperosShowcaseSampleText.zh) }
    var pickerValue by remember { mutableIntStateOf(18) }
    var accordionExpanded1 by remember { mutableStateOf(true) }
    var accordionExpanded2 by remember { mutableStateOf(false) }
    var selectedColorIndex by remember { mutableIntStateOf(0) }
    var showDialogDemo by remember { mutableStateOf(false) }

    val presetColors = listOf(
        Color(0xFF3482FF), // Blue
        Color(0xFF34C759), // Green
        Color(0xFFFF9500), // Orange
        Color(0xFFAF52DE), // Purple
        Color(0xFFFF3B30)  // Red
    )

    // 大标题折叠行为：Dart 原件 lib/screens/hyperos_showcase_screen.dart:92 走 HyperosSubpage，
    // 大标题可折叠（collapsibleLargeTitle 默认 true）。不传 scrollBehavior 则永不收起。
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = GuideStrings.hyperosShowcaseTitle.zh,
                largeTitle = GuideStrings.hyperosShowcaseTitle.zh,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.primaryText(dark))
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .scrollEndHaptic()
                    .overScrollVertical()
                    .nestedScroll(scrollBehavior.nestedScrollConnection),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = 8.dp,
                    bottom = innerPadding.calculateBottomPadding() + 32.dp
                ),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // 1. 概要卡片
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionSummary.zh)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(16.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(primaryColor),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.Tune,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                            Spacer(modifier = Modifier.width(14.dp))
                            Column {
                                Text(
                                    text = "HyperOS UI Kit",
                                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = GuideStrings.hyperosShowcaseKitSubtitle.zh,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark))
                                )
                            }
                        }
                    }
                }

                // 2. 标签与手风琴 (Accordion)
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionTags.zh)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp)
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            // 提示横幅
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = MiuixIcons.Info,
                                    contentDescription = null,
                                    tint = primaryColor,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "HyperosHintBanner · 信息提示横幅",
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                            }

                            HorizontalDivider()

                            // 手风琴 1
                            AccordionRow(
                                title = GuideStrings.hyperosShowcaseAccordionSection1.zh,
                                body = GuideStrings.hyperosShowcaseAccordionSection1Body.zh,
                                expanded = accordionExpanded1,
                                onToggle = { accordionExpanded1 = !accordionExpanded1 }
                            )

                            HorizontalDivider()

                            // 手风琴 2
                            AccordionRow(
                                title = GuideStrings.hyperosShowcaseAccordionSection2.zh,
                                body = GuideStrings.hyperosShowcaseAccordionSection2Body.zh,
                                expanded = accordionExpanded2,
                                onToggle = { accordionExpanded2 = !accordionExpanded2 }
                            )
                        }
                    }
                }

                // 3. 控件卡片 (按钮、分段、滑条)
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionControls.zh)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(16.dp)
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Text(
                                text = "按钮样式 (Buttons)",
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                                color = Color(QingyuTheme.primaryText(dark))
                            )

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Button(
                                    onClick = {},
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(primaryColor)
                                ) {
                                    Text("主要按钮", color = Color.White)
                                }

                                Button(
                                    onClick = {},
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(Color(QingyuTheme.scaffoldBackground(dark)))
                                ) {
                                    Text("次要按钮", color = Color(QingyuTheme.primaryText(dark)))
                                }
                            }

                            HorizontalDivider()

                            // 滑动条 (Slider)
                            Text(
                                text = "滑块数值: ${(sliderValue * 100).toInt()}%",
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.primaryText(dark))
                            )

                            QingyuSlider(
                                value = sliderValue,
                                onValueChange = { sliderValue = it },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }

                // 4. 基础控件行内 (开关、多选、单选)
                item {
                    ShowcaseSectionHeader(title = "基础控件 · 行内")
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp)
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            // 开关行
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "开关项 (Switch)",
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                                Switch(
                                    checked = switchState,
                                    onCheckedChange = { switchState = it }
                                )
                            }

                            HorizontalDivider()

                            // 多选行
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "多选项 (Checkbox)",
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                                Checkbox(
                                    state = if (checkboxState) ToggleableState.On else ToggleableState.Off,
                                    onClick = { checkboxState = !checkboxState }
                                )
                            }

                            HorizontalDivider()

                            // 单选组
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "尺寸选择",
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    listOf("S", "M", "L").forEach { opt ->
                                        val isSel = selectedRadio == opt
                                        Box(
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(
                                                    if (isSel) primaryColor else primaryColor.copy(alpha = 0.08f)
                                                )
                                                .clickable { selectedRadio = opt }
                                                .padding(horizontal = 12.dp, vertical = 6.dp)
                                        ) {
                                            Text(
                                                text = opt,
                                                color = if (isSel) Color.White else primaryColor,
                                                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.BOLD)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 5. 输入与选择器
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionInput.zh)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(16.dp)
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(
                                text = "文本输入 (TextField)",
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark))
                            )
                            TextField(
                                value = sampleInputText,
                                onValueChange = { sampleInputText = it },
                                modifier = Modifier.fillMaxWidth()
                            )

                            HorizontalDivider()

                            // 滚轮选择器模拟行
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = GuideStrings.hyperosShowcasePickerCurrentValue.filled("value", "$pickerValue"),
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primaryText(dark))
                                )
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Button(
                                        onClick = { if (pickerValue > 1) pickerValue-- },
                                        colors = ButtonDefaults.buttonColors(Color(QingyuTheme.scaffoldBackground(dark)))
                                    ) {
                                        Text("-", color = primaryColor)
                                    }
                                    Button(
                                        onClick = { if (pickerValue < 30) pickerValue++ },
                                        colors = ButtonDefaults.buttonColors(Color(QingyuTheme.scaffoldBackground(dark)))
                                    ) {
                                        Text("+", color = primaryColor)
                                    }
                                }
                            }
                        }
                    }
                }

                // 6. 颜色选择
                item {
                    ShowcaseSectionHeader(title = "颜色选择 · ColorChip")
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(16.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            presetColors.forEachIndexed { idx, color ->
                                val isSelected = idx == selectedColorIndex
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(color)
                                        .clickable { selectedColorIndex = idx },
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (isSelected) {
                                        Box(
                                            modifier = Modifier
                                                .size(14.dp)
                                                .clip(CircleShape)
                                                .background(Color.White)
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
}

/** 章节标题 */
@Composable
private fun ShowcaseSectionHeader(title: String) {
    Text(
        text = title,
        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
        color = Color(0xFF3482FF),
        modifier = Modifier.padding(start = 4.dp, bottom = 2.dp)
    )
}

/** 手风琴折叠行 */
@Composable
private fun AccordionRow(
    title: String,
    body: String,
    expanded: Boolean,
    onToggle: () -> Unit
) {
    val dark = isSystemInDarkTheme()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark))
            )
            Icon(
                imageVector = if (expanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark))
            )
        }

        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn(tween(150)) + expandVertically(tween(150)),
            exit = fadeOut(tween(150)) + shrinkVertically(tween(150))
        ) {
            Text(
                text = body,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                lineHeight = 18.sp,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}
