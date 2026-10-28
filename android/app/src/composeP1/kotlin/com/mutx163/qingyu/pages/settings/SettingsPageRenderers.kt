package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.components.QingyuBackIconButton
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuFixedTokens
import com.mutx163.qingyu.theme.QingyuShapes
import com.mutx163.qingyu.theme.QingyuTypography
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.BasicComponentDefaults
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Slider
import top.yukonga.miuix.kmp.basic.SmallTopAppBar
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.CheckboxPreference
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.RadioButtonPreference
import top.yukonga.miuix.kmp.preference.SliderPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.ArrowRight
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 设置族三页的**渲染层**：把模型层的 [SettingsPageSpec] 喂给官方 Miuix 组件。
 *
 * 只放在 `composeP1` 源集：官方 Miuix 只挂在这个变体的 classpath 上
 * （`android/app/build.gradle:253-257`），main 源集全变体编译、不能 import 它。
 *
 * ## 组件落点（详见 [SettingsRowRenderTable]）
 *
 * 0.8.8 的设置行整套在 `top.yukonga.miuix.kmp.extra` 的 `Super*` 家族里，
 * 直接 import 使用，没有一处自绘控件：
 *
 * | 模型 | 组件 |
 * |---|---|
 * | [MiuixRowComponent.ARROW] | `extra.SuperArrow` |
 * | [MiuixRowComponent.SWITCH] | `extra.SuperSwitch` |
 * | [MiuixRowComponent.DROPDOWN] | `extra.SuperDropdown` |
 * | [MiuixRowComponent.RADIO] | `extra.SuperRadioButton` |
 * | [MiuixRowComponent.CHECKBOX] | `extra.SuperCheckbox` |
 * | [MiuixRowComponent.SLIDER] | `basic.BasicComponent` + `basic.Slider`（0.8.8 无 SuperSlider） |
 * | [MiuixRowComponent.COLOR_SWATCH] | `extra.SuperArrow` + 行尾 36dp 色块（官方无颜色行） |
 *
 * ## 颜色与尺寸一律走 theme/ 桥
 *
 * 页面底色/卡片/文字色全部取 `MiuixTheme.colorScheme`——由接线层（shell）按
 * `docs/plans/2026-10-26-compose-phase3-prep.md` §2.1 的对照表把 Flutter 色板填进
 * `lightColorScheme()/darkColorScheme()`，本文件不硬编码任何品牌色；
 * 官方没有的语义槽（危险色）取 [QingyuFixedTokens.DESTRUCTIVE]；
 * 字号/圆角/行内边距取 [QingyuTypography] / [QingyuShapes]。
 *
 * ## 本层不做的三件事（都在宿主接线层）
 *
 * 1. **下拉/选色/确认弹层的弹开**：行点击只回调 [onAction]，弹层由宿主接
 *    （官方 Overlay 系需要 Scaffold 内置 `MiuixPopupHost`，见选型文档 :44）；
 * 2. **课卡页顶部周预览**：官方无对应物（自绘白名单第 ② 项），由 [preview] 槽位注入；
 * 3. **设置写回与失败回滚**：模型只标 [SettingsAction]，行为在仓库既有 provider 层。
 */
@Composable
fun SettingsPageScreen(
    spec: SettingsPageSpec,
    preview: (@Composable () -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit = { _, _, _ -> },
) {
    val colors = MiuixTheme.colorScheme
    // 大标题要「跟着滚动收起」，官方 demo（docs/reference/miuix-demo topappbar.md:67-96）要求三件齐：
    // 一个 ScrollBehavior 实例、顶栏拿到它、本页唯一的滚动容器把滚动手势喂给它。
    // 少任何一件，Miuix 0.9.4 的 TopAppBar 都会把 largeTitle 常驻显示（它默认等于 title），
    // 表现就是「上下拉，一直显示的都是大标题」。
    val scrollBehavior = MiuixScrollBehavior()
    Scaffold(
        modifier = Modifier.fillMaxSize(),
        topBar = {
            if (spec.collapsibleLargeTitle) {
                TopAppBar(
                    title = spec.title,
                    largeTitle = spec.title,
                    navigationIcon = { if (onBack != null) BackIconButton(onBack = onBack) },
                    scrollBehavior = scrollBehavior,
                )
            } else {
                // 与 Dart 侧 collapsibleLargeTitle: false 的设置页对齐（settings_course_card.dart:81、
                // settings_timetable_page.dart:102 等）：这些页本来就没有大标题，
                // 用官方「无大标题」变体 SmallTopAppBar——它会把共享状态钉死，不会漏出大标题。
                SmallTopAppBar(
                    title = spec.title,
                    navigationIcon = { if (onBack != null) BackIconButton(onBack = onBack) },
                    scrollBehavior = scrollBehavior,
                )
            }
        },
        containerColor = colors.surface,
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            // 课程卡片页：预览占 4 成、可调项占 6 成（settings_course_card.dart:84-125）
            if (preview != null && spec.previewFlex != null && spec.contentFlex != null) {
                Box(modifier = Modifier.fillMaxWidth().weight(spec.previewFlex.toFloat())) {
                    preview()
                }
            }
            val listWeight = if (preview != null && spec.contentFlex != null) {
                Modifier.weight(spec.contentFlex.toFloat())
            } else {
                Modifier.fillMaxSize()
            }
            LazyColumn(
                modifier = listWeight.fillMaxWidth().nestedScroll(scrollBehavior.nestedScrollConnection),
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                items(items = spec.nodes, key = { it.id }) { node ->
                    SettingsNodeView(node = node, onAction = onAction)
                }
            }
        }
    }
}

@Composable
private fun BackIconButton(onBack: () -> Unit) {
    // 全站统一：官方 TopAppBar 里的标准左箭头（MiuixIcons.Back）。
    // 旧实现把 Basic.ArrowRight 旋转 180° 凑数（0.8.8 时代没有返回箭头），
    // 形状与其它页面不一致，已按用户口径换掉。
    QingyuBackIconButton(onBack = onBack)
}

@Composable
private fun SettingsNodeView(
    node: SettingsNode,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    when (node) {
        is SettingsLabel -> SectionLabel(text = node.text)
        is SettingsDescription -> SectionDescription(text = node.text)
        is SettingsGap -> Spacer(modifier = Modifier.height(node.heightDp.dp))
        is SettingsGroup -> SettingsGroupCard(group = node, onAction = onAction)
        is SettingsInline -> SettingsInlineView(node = node, onAction = onAction)
        is SettingsRow -> SettingsRowView(row = node, onAction = onAction)
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = QingyuShapes.SECTION_LABEL_INSET.dp,
                end = QingyuShapes.SECTION_LABEL_INSET.dp,
                bottom = 8.dp,
            ),
        color = MiuixTheme.colorScheme.onSurfaceVariantActions,
        style = MiuixTheme.textStyles.footnote1,
    )
}

@Composable
private fun SectionDescription(text: String) {
    Text(
        text = text,
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = QingyuShapes.SECTION_LABEL_INSET.dp,
                end = QingyuShapes.SECTION_LABEL_INSET.dp,
                top = 8.dp,
            ),
        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        style = MiuixTheme.textStyles.footnote1,
    )
}

/** 一个白卡分组（`HyperosListGroup`）。分组内**不自动加分隔线**：Flutter 侧也不加。 */
@Composable
private fun SettingsGroupCard(
    group: SettingsGroup,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        cornerRadius = QingyuShapes.SETTINGS_GROUP_RADIUS.dp,
        insideMargin = PaddingValues(0.dp),
    ) {
        group.children.forEach { child -> SettingsNodeView(node = child, onAction = onAction) }
    }
}

@Composable
private fun SettingsRowView(
    row: SettingsRow,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val click: (() -> Unit)? = row.action?.let { action ->
        { onAction(action, row.actionTarget, row.id) }
    }
    when (row.component) {
        MiuixRowComponent.SWITCH -> SwitchPreference(
            checked = row.switchValue ?: false,
            onCheckedChange = {
                onAction(row.action ?: SettingsAction.WRITE_SETTING, row.actionTarget, row.id)
            },
            title = row.title,
            summary = row.subtitle,
            enabled = row.enabled,
        )

        MiuixRowComponent.ARROW -> ArrowPreference(
            title = row.title,
            titleColor = titleColors(row),
            summary = row.subtitle,
            onClick = click,
            enabled = row.enabled,
            endActions = {
                TrailingText(SettingsRowRenderTable.trailingText(row))
                row.trailingAction?.let { TrailingActionHint(it) }
            },
        )

        MiuixRowComponent.SLIDER -> SliderRow(row = row, onAction = onAction)

        MiuixRowComponent.DROPDOWN -> OverlayDropdownPreference(
            items = row.options.map { it.label },
            selectedIndex = row.options.indexOfFirst { it.id == row.selectedOptionId },
            title = row.title,
            summary = row.subtitle,
            enabled = row.enabled,
            onSelectedIndexChange = { index ->
                val option = row.options.getOrNull(index)
                onAction(
                    row.action ?: SettingsAction.WRITE_SETTING,
                    option?.id ?: row.actionTarget,
                    row.id,
                )
            },
        )

        MiuixRowComponent.RADIO -> RadioButtonPreference(
            title = row.title,
            selected = row.selectedOptionId != null,
            onClick = click ?: {},
            summary = row.subtitle,
            enabled = row.enabled,
            endActions = { row.trailingAction?.let { TrailingActionHint(it) } },
        )

        MiuixRowComponent.CHECKBOX -> CheckboxPreference(
            title = row.title,
            checked = row.switchValue ?: false,
            onCheckedChange = {
                onAction(row.action ?: SettingsAction.WRITE_SETTING, row.actionTarget, row.id)
            },
            summary = row.subtitle,
            enabled = row.enabled,
        )

        MiuixRowComponent.COLOR_SWATCH -> ArrowPreference(
            title = row.title,
            titleColor = titleColors(row),
            onClick = click,
            enabled = row.enabled,
            endActions = { ColorSwatch(hex = row.value) },
        )
    }
    // 行尾附加按钮（已存主题的「更多操作」）只渲染提示文案，点击由宿主按
    // trailingActionKind 接（见 SettingsRowRenderTable 的契约断言）。
}

/**
 * 滑杆行。
 *
 * 2026-10-27 起用**官方** `preference.SliderPreference`（0.9.4 才有这个组件）。
 * 在此之前这里是「`basic.BasicComponent` + `basic.Slider` 包一层」的手写实现
 * ——那是 0.8.8 时代没有官方滑杆行的临时方案，现在官方有了就不该再自绘
 * （规格 Failure mode 6：官方已有组件直接 import，不许重复造轮子）。
 *
 * `steps` 口径差异照旧：模型层 [SettingsSliderSpec.divisions] 是「区间数」，
 * 而官方 `steps`（Material 口径）是「端点之间的档数」→ 差 1。
 */
@Composable
private fun SliderRow(
    row: SettingsRow,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val spec = row.slider ?: return
    val value = row.sliderValue ?: spec.defaultValue
    SliderPreference(
        value = value.toFloat(),
        onValueChange = { changed ->
            onAction(
                SettingsAction.WRITE_SETTING,
                changed.toString(),
                row.id,
            )
        },
        title = row.title,
        summary = row.subtitle,
        valueText = row.value,
        enabled = row.enabled,
        valueRange = spec.min.toFloat()..spec.max.toFloat(),
        steps = (spec.divisions - 1).coerceAtLeast(0),
    )
}

/** 行尾读数（`HyperosSliderTile.valueLabel` / `HyperosNavTile.details` 同一槽位）。 */
@Composable
private fun RowScope.TrailingText(text: String?) {
    if (text.isNullOrEmpty()) return
    Text(
        text = text,
        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        style = MiuixTheme.textStyles.body2,
    )
}

@Composable
private fun RowScope.TrailingActionHint(text: String) {
    Text(
        text = text,
        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        style = MiuixTheme.textStyles.footnote1,
    )
}

/** 行尾色块（`timetable_text_color_settings.dart:320-334`：36dp、圆角 10、1px 描边）。 */
@Composable
private fun RowScope.ColorSwatch(hex: String?) {
    val argb = SettingsRowRenderTable.colorFromHex(hex)
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Color(argb))
            .border(
                width = 1.dp,
                color = MiuixTheme.colorScheme.outline,
                shape = RoundedCornerShape(10.dp),
            ),
    )
}

/** 危险操作行的标题色：官方没有 destructive 槽，取 theme/ 桥的固定 token。 */
@Composable
private fun titleColors(row: SettingsRow): top.yukonga.miuix.kmp.basic.BasicComponentColors {
    if (!row.destructive) return BasicComponentDefaults.titleColor(
        MiuixTheme.colorScheme.onBackground,
        MiuixTheme.colorScheme.disabledOnSurface,
    )
    val destructive = Color(QingyuFixedTokens.DESTRUCTIVE)
    return BasicComponentDefaults.titleColor(destructive, destructive.copy(alpha = 0.45f))
}

@Composable
private fun SettingsInlineView(
    node: SettingsInline,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    when (node.kind) {
        InlineKind.PREVIEW_CARD -> PreviewCard(node = node)
        InlineKind.FONT_PREVIEW -> FontPreview(node = node)
        InlineKind.COLOR_CHIP_GROUP -> ColorChipGroup(node = node, onAction = onAction)
        InlineKind.CONTROL_CARD -> ControlCard(node = node, onAction = onAction)
    }
}

/** 主题/字体微缩预览（`settings_appearance.dart:116-193`）。 */
@Composable
private fun PreviewCard(node: SettingsInline) {
    val colors = MiuixTheme.colorScheme
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        cornerRadius = QingyuShapes.CARD_CORNER.dp,
        insideMargin = PaddingValues(QingyuShapes.SHEET_INSET.dp),
    ) {
        Text(
            text = node.label.orEmpty(),
            color = colors.onBackground,
            style = MiuixTheme.textStyles.headline1,
            fontWeight = FontWeight.Medium,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PreviewTile(
                modifier = Modifier.weight(1f),
                container = colors.primary,
                label = node.texts.getOrNull(0)?.text.orEmpty(),
                sublabel = node.texts.getOrNull(1)?.text.orEmpty(),
            )
            PreviewTile(
                modifier = Modifier.weight(1f),
                container = colors.surfaceContainer,
                label = node.texts.getOrNull(2)?.text.orEmpty(),
                sublabel = null,
            )
        }
    }
}

@Composable
private fun PreviewTile(
    modifier: Modifier,
    container: Color,
    label: String,
    sublabel: String?,
) {
    val colors = MiuixTheme.colorScheme
    Column(
        modifier = modifier
            .height(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(container)
            .padding(10.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            color = colors.onPrimary,
            style = MiuixTheme.textStyles.body2,
        )
        if (!sublabel.isNullOrEmpty()) {
            Text(
                text = sublabel,
                color = colors.onPrimary.copy(alpha = 0.7f),
                style = MiuixTheme.textStyles.footnote1,
            )
        }
    }
}

/** 字号实时预览（`settings_appearance.dart:297-318`）。 */
@Composable
private fun FontPreview(node: SettingsInline) {
    val colors = MiuixTheme.colorScheme
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                top = 8.dp,
                bottom = 12.dp,
            ),
        cornerRadius = 12.dp,
        insideMargin = PaddingValues(12.dp),
    ) {
        Text(
            text = node.texts.firstOrNull()?.text.orEmpty(),
            color = colors.onBackground,
            style = MiuixTheme.textStyles.body1,
        )
    }
}

/**
 * 统一课卡色的八色板（`settings_course_card.dart:286-299`）。
 *
 * 2026-10-28（task-15）：色块以前**没有 `clickable`**，点了没反应——用户说的「按钮点击都
 * 没有反应」有一处就是它。现在每个色块走的是与其它行**同一条** `onAction` 通路：
 * `WRITE_SETTING` + `target = 该色值` + `rowId = ROW_CARD_COLOR_CHIPS`；
 * 「点这个色值意味着什么」的判据仍在分派器里，渲染层只负责转达。
 */
@Composable
private fun ColorChipGroup(
    node: SettingsInline,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                top = 8.dp,
                bottom = 20.dp,
            ),
        cornerRadius = QingyuShapes.CARD_CORNER.dp,
        insideMargin = PaddingValues(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            node.colors.forEach { hex ->
                val selected = hex.equals(node.selectedColor, ignoreCase = true)
                val argb = SettingsRowRenderTable.colorFromHex(hex)
                Box(
                    modifier = Modifier
                        .size(QingyuShapes.ICON_BADGE_SIZE.dp)
                        .clip(RoundedCornerShape(QingyuShapes.ICON_BADGE_RADIUS.dp))
                        .background(Color(argb))
                        .border(
                            width = if (selected) 2.dp else 1.dp,
                            color = if (selected) colors.primary else colors.outline,
                            shape = RoundedCornerShape(QingyuShapes.ICON_BADGE_RADIUS.dp),
                        )
                        .clickable {
                            onAction(
                                SettingsAction.WRITE_SETTING,
                                hex,
                                SettingsActionDispatcher.ROW_CARD_COLOR_CHIPS,
                            )
                        },
                )
            }
        }
    }
}

/**
 * 控制卡头（`HyperosControlCard`）：标题 + 取值 + 可选按钮。
 *
 * 2026-10-28（task-15）：按钮以前是 `onClick = { }`（空实现），点不动。
 * 现在按 Dart `settings_appearance.dart:471-504` 的主题管理段接上：
 * - 「重置为预设」（ARB 键 `themeResetToPreset`）→ `WRITE_SETTING` +
 *   `rowId = ROW_THEME_CURRENT_RESET`，分派器把 `themeCheckpointConfig` 写回去；
 * - 「保存当前主题」（`themeSaveCurrent`）→ `DIALOG` + `rowId = ROW_THEME_CURRENT_SAVE`，
 *   对话框本体属宿主/页面层。
 *
 * 这里只做「按钮 → 动作」的翻译，**判据一律在分派器里**；认不出的键不给点击
 * （宁可点不动，也不要在渲染层猜一个语义）。
 */
@Composable
private fun ControlCard(
    node: SettingsInline,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        cornerRadius = QingyuShapes.SETTINGS_GROUP_RADIUS.dp,
        insideMargin = PaddingValues(QingyuShapes.SHEET_INSET.dp),
    ) {
        Text(
            text = node.label.orEmpty(),
            color = colors.onBackground,
            style = MiuixTheme.textStyles.headline1,
            fontWeight = FontWeight.Medium,
        )
        node.value?.let { value ->
            Text(
                text = value,
                modifier = Modifier.padding(top = 4.dp),
                color = colors.onSurfaceVariantSummary,
                style = MiuixTheme.textStyles.body2,
            )
        }
        if (node.texts.isNotEmpty()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                node.texts.forEach { action ->
                    val wiring = controlCardWiring(action.key)
                    Button(
                        onClick = {
                            if (wiring != null) {
                                onAction(wiring.first, null, wiring.second)
                            }
                        },
                    ) {
                        Text(
                            text = action.text,
                            color = colors.primary,
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                }
            }
        }
    }
}

/**
 * 控制卡按钮 → `(动作, rowId)`；认不出的 ARB 键返回 `null`（不给点击）。
 *
 * 键名是 `SettingsInline.texts[].key`（ARB 键），与
 * `SettingsStrings.themeResetToPreset` / `themeSaveCurrent` 一致。
 */
private fun controlCardWiring(textKey: String): Pair<SettingsAction, String>? = when (textKey) {
    "themeResetToPreset" -> SettingsAction.WRITE_SETTING to
        SettingsActionDispatcher.ROW_THEME_CURRENT_RESET

    "themeSaveCurrent" -> SettingsAction.DIALOG to
        SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE

    else -> null
}
