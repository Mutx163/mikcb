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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuColorChips
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSlider
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
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
    var sampleInputText by remember { mutableStateOf(GuideStrings.hyperosShowcaseSampleText.text) }
    var pickerValue by remember { mutableIntStateOf(18) }
    var accordionExpanded1 by remember { mutableStateOf(true) }
    var accordionExpanded2 by remember { mutableStateOf(false) }
    var selectedColorIndex by remember { mutableIntStateOf(0) }
    var showDialogDemo by remember { mutableStateOf(false) }

    // Dart `hyperos_showcase_screen.dart:53-59` 的 `_chipColors`：取应用层彩豆 token，
    // Miuix colorScheme 无对应槽，不写字面量（R5）。
    //
    // 2026-11-10 颜色配方 v2：本页色块改调共享件 `QingyuColorChips`（squircle 12dp +
    // 选中 2dp primary 描边 + 勾）。组件吃 `#RRGGBB`，所以这里把 token 掩成 hex 串——
    // 颜色来源仍是 token，不是字面量；换色板只改 QingyuIconColors 一处。
    val presetColorHex = listOf(
        QingyuIconColors.BLUE,
        QingyuIconColors.GREEN,
        QingyuIconColors.ORANGE,
        QingyuIconColors.PURPLE,
        QingyuIconColors.RED,
    ).map { "#" + (it and 0xFFFFFF).toString(16).padStart(6, '0').uppercase() }

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃；大标题可折叠
    // （Dart 原件 hyperos_showcase_screen.dart:92 走 HyperosSubpage 默认）。
    QingyuPageScaffold(title = GuideStrings.hyperosShowcaseTitle.text, onBack = onBack) {
        // 展示册里含 TextField 演示项：imePadding 把列表抬到键盘之上。
        QingyuPageList(
            modifier = Modifier.imePadding(),
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = 16.dp,
            contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
                // 1. 概要卡片
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionSummary.text, dark = dark)
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
                                    text = GuideStrings.hyperosShowcaseKitSubtitle.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark))
                                )
                            }
                        }
                    }
                }

                // 2. 标签与手风琴 (Accordion)
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionTags.text, dark = dark)
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


                            // 手风琴 1
                            AccordionRow(
                                title = GuideStrings.hyperosShowcaseAccordionSection1.text,
                                body = GuideStrings.hyperosShowcaseAccordionSection1Body.text,
                                expanded = accordionExpanded1,
                                onToggle = { accordionExpanded1 = !accordionExpanded1 }
                            )


                            // 手风琴 2
                            AccordionRow(
                                title = GuideStrings.hyperosShowcaseAccordionSection2.text,
                                body = GuideStrings.hyperosShowcaseAccordionSection2Body.text,
                                expanded = accordionExpanded2,
                                onToggle = { accordionExpanded2 = !accordionExpanded2 }
                            )
                        }
                    }
                }

                // 3. 控件卡片 (按钮、分段、滑条)
                item {
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionControls.text, dark = dark)
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
                    ShowcaseSectionHeader(title = "基础控件 · 行内", dark = dark)
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
                    ShowcaseSectionHeader(title = GuideStrings.hyperosShowcaseSectionInput.text, dark = dark)
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

                // 6. 颜色选择：改调共享色块件（配方 v2：36dp squircle + 选中勾 + 2dp 描边），
                // 白点标记退役。
                item {
                    ShowcaseSectionHeader(title = "颜色选择 · ColorChip", dark = dark)
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(16.dp)
                    ) {
                        QingyuColorChips(
                            colors = presetColorHex,
                            selectedHex = presetColorHex[selectedColorIndex],
                            onSelect = { hex -> selectedColorIndex = presetColorHex.indexOf(hex) },
                            // 档位参数**故意不传**：本页只是「色块示例」，用组件默认档即可。
                            // 传具名档位会把我这条线绑死在 `QingyuColorChipSize` 的枚举值上，
                            // 而那枚举正在定稿（Couple/Settings/QuickRow ↔ Large/Medium/Small），
                            // 颜色线的定稿一变这里就断链——示例页不值得占这个依赖。
                            dark = dark,
                        )
                    }
                }
        }
    }
}

/** 章节标题（取色对齐 Dart `HyperosColors.sectionLabel`）。 */
@Composable
private fun ShowcaseSectionHeader(title: String, dark: Boolean) {
    Text(
        text = title,
        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
        color = Color(QingyuTheme.sectionLabel(dark)),
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

// ── 预览：Android Studio 里免装机看效果（2026-11-08 加）────────────────────
//
// 本页**没有数据状态分支**：开关 / 单选 / 滑杆 / 输入框 / 手风琴的值全是页面内的
// `remember` 初值，静态预览看到的就是默认形态。所以只铺外观三档。

/** 一档预览的公共身体：外观档位。 */
@Composable
private fun PreviewHyperosShowcasePage(
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        HyperosShowcasePage(onBack = {})
    }
}

@Suppress("unused")
@Preview(name = "1 亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HyperosShowcasePagePreviewLight() {
    PreviewHyperosShowcasePage()
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HyperosShowcasePagePreviewDark() {
    PreviewHyperosShowcasePage(dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HyperosShowcasePagePreviewLargeText() {
    PreviewHyperosShowcasePage(textScale = 1.3f)
}
