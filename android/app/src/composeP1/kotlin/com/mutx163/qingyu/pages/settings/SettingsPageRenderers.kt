package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.Image
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.R
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSliderPreference
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuFixedTokens
import com.mutx163.qingyu.theme.QingyuShapes
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.theme.QingyuTypography
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.BasicComponentDefaults
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.ArrowRight
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Background
import top.yukonga.miuix.kmp.icon.extended.Backup
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.CloudFill
import top.yukonga.miuix.kmp.icon.extended.ConvertFile
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.FavoritesFill
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Home
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Layers
import top.yukonga.miuix.kmp.icon.extended.Link
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Pin
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Show
import top.yukonga.miuix.kmp.icon.extended.Sidebar
import top.yukonga.miuix.kmp.icon.extended.Stopwatch
import top.yukonga.miuix.kmp.icon.extended.Theme
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.icon.extended.Weeks
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.CheckboxPreference
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.RadioButtonPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「已过去」的行降到的透明度（Flutter `Opacity(opacity: 0.55)`，`settings_holiday.dart:613-614`）。
 * 55% 是 Dart 侧写死的值，不是随手挑的——见 [SettingsRow.dimmed]。
 */
private const val ROW_DIMMED_ALPHA = 0.55f

/**
 * 顶栏动作行的 rowId：`SettingsTopAction` 没有「行」，但宿主仍需要一个稳定的
 * rowId 来区分「这个 NAVIGATE 是顶栏发出来的」。壳侧按它做分支即可。
 */
const val TOP_ACTION_ROW_ID = "topAction"

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
    // 顶栏 + 折叠行为 + 返回键统一交给共享骨架（规则 R1）：
    // 骨架内部自己持有一个 ScrollBehavior，并通过 content 槽把它交给下面的 QingyuPageList，
    // 于是「大标题跟着滚动收起」这条要求只需要在这里声明，不需要本页再手接一遍。
    //
    // 两个变体与 Dart 侧一一对应（`collapsibleLargeTitle`）：
    //   true  → 官方可折叠大标题（smallTopBar = false，与 HyperosSubpage 默认一致）；
    //   false → 官方 SmallTopAppBar（单行小标题，settings_course_card.dart:81 等本来就是它）。
    //
    // onBack 为 null 时骨架仍会画出返回键（套件的返回键是恒定存在的），这里退化成空实现：
    // 20 页的真实宿主（SettingsHost / ShellPageIndex）**都**传了 onBack，null 只出现在
    // 未接线的预览调用里，不构成「看得见却按不动」的线上路径。
    // 顶栏右侧动作（Flutter `HyperosSubpage(suffixes: [FHeaderAction(...)])`）与固定底栏
    // （Flutter `Column` 的最后一个子项）都在这里接——两件事都属「壳的能力」，不属单页：
    // 顶栏 action 槽由 [QingyuPageScaffold] 的 `actions` 承载，底栏由它的 `bottomBar` 承载。
    // 见 `settings_holiday.dart:466-478`（齿轮进高级页）与 `:792-812`（固定的检查更新按钮）。
    val dark = isSystemInDarkTheme()
    val topAction = spec.topBarAction
    val footer = spec.footerNode
    val footerSlot: (@Composable () -> Unit)? = if (footer == null) {
        null
    } else {
        { SettingsNodeView(node = footer, onAction = onAction) }
    }
    QingyuPageScaffold(
        title = spec.title,
        onBack = onBack ?: {},
        smallTopBar = !spec.collapsibleLargeTitle,
        actions = {
            if (topAction != null) {
                IconButton(
                    onClick = {
                        onAction(SettingsAction.NAVIGATE, topAction.route, TOP_ACTION_ROW_ID)
                    },
                ) {
                    Icon(
                        imageVector = MiuixIcons.Tune,
                        contentDescription = topAction.semanticsLabel,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
            }
        },
        bottomBar = footerSlot,
    ) {
        // 两页（课程卡片 / 课表页面）是「上方预览 + 下方设置列表」的 4:6 分栏；
        // 其余设置页没有预览，列表就是整页。
        val previewSlot = preview
        val previewFlex = spec.previewFlex
        val contentFlex = spec.contentFlex
        if (previewSlot != null && previewFlex != null && contentFlex != null) {
            // 预览与列表都用 weight 拿**固定**高度：列表段因此得到一个有界的视口，
            // 长内容能正常滚动；预览段固定在顶部，不随列表滚走。
            Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(previewFlex.toFloat()),
                ) {
                    previewSlot()
                }
                QingyuPageList(
                    innerPadding = PaddingValues(0.dp),
                    modifier = Modifier
                        .weight(contentFlex.toFloat())
                        .fillMaxWidth(),
                    scrollBehavior = scrollBehavior,
                    contentPadding = PaddingValues(bottom = 24.dp),
                ) {
                    items(items = spec.nodes, key = { it.id }) { node ->
                        SettingsNodeView(node = node, onAction = onAction)
                    }
                }
            }
        } else {
            // 无预览的页面：列表直接做 Scaffold 的内容根、自己吃 innerPadding——
            // 与全站其它列表页（CourseOverviewPage 等）同一套配方。QingyuPageList 内部是
            // Box + LazyColumn(fillMaxSize)，只有把 innerPadding 交给它、让它贴着 Scaffold
            // 的内容区，才能拿到完整可视高度并正常滚动（旧写法把列表塞进一个 Column 再让它
            // fillMaxSize，长内容会被截断且滑不动）。
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                items(items = spec.nodes, key = { it.id }) { node ->
                    SettingsNodeView(node = node, onAction = onAction)
                }
            }
        }
    }
}

/**
 * 单个节点 → 官方 Miuix 组件。
 *
 * 可见性从 `private` 放宽到 `internal`（2026-10-29）：外观编辑页的两个底部面板是
 * **根覆盖层自插条目**，面板正文只能内联渲染，而它们的内容与设置列表同源
 * （同一批 [SettingsNode]）—— 面板那两页因此直接复用这里的行部件，不另写一套
 * 「长得像」的控件（两套方言迟早分叉：字号、圆角、按压反馈各走各的）。
 */
@Composable
internal fun SettingsNodeView(
    node: SettingsNode,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
    /**
     * 分组白卡的左右内缩；`null` = 用设置列表的默认轴线
     * （卡片 12 + 行 16 = 文字左缘 28，见 `docs/reference/compose-page-style-rules.md`）。
     *
     * 只有「嵌在底部弹层里」的那两处需要改它：弹层自己在官方 `insideMargin` 里已经给到
     * 16，卡片再垫 12 就成了 44，而行部件内部还有 16 ⇒ 比 Dart 面板多出整整 12。
     * 传 `0.dp` 后行左缘 = 弹层 16 + 行 16 = 32，与 Dart 面板一致。
     */
    rowInset: Dp? = null,
) {
    when (node) {
        is SettingsLabel -> SectionLabel(text = node.text)
        is SettingsDescription -> SectionDescription(text = node.text)
        is SettingsGap -> Spacer(modifier = Modifier.height(node.heightDp.dp))
        is SettingsGroup -> SettingsGroupCard(group = node, onAction = onAction, rowInset = rowInset)
        is SettingsInline -> SettingsInlineView(node = node, onAction = onAction)
        is SettingsRow ->
            // 「已过去」的行整行降到 55% 透明度（Flutter `Opacity(0.55)`，settings_holiday.dart:613-614）。
            // 包在行外面而不是改组件内部颜色：卡片/背景/描边一起变淡才与原版一致，
            // 也不影响点击热区与禁用态语义（那两件事各有自己的字段）。
            Box(
                modifier = if (node.dimmed) {
                    Modifier.alpha(ROW_DIMMED_ALPHA)
                } else {
                    Modifier
                },
            ) {
                if (node.standaloneSummaryCard) {
                    SummaryCardRow(row = node, onAction = onAction)
                } else {
                    SettingsRowView(row = node, onAction = onAction)
                }
            }
    }
}

/**
 * 分组小标题（`HyperosSectionLabel`）。
 *
 * 2026-10-31（F20-B）从 `private` 放宽到 `internal`：桌面小组件的预览轮播有自己的
 * 复合区块（`HomeWidgetPreviewCarousel.WidgetPreviewSection`），顶部要用的正是**同一条**
 * 轴线与字阶。让它自己再抄一份样式，两处迟早会分叉（一处 13sp 一处 12sp、
 * 一处内缩 16 一处 14），所以开放同一个实现，而不是复制。
 */
@Composable
internal fun SectionLabel(text: String) {
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
    rowInset: Dp? = null,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = rowInset ?: QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        cornerRadius = QingyuShapes.SETTINGS_GROUP_RADIUS.dp,
        insideMargin = PaddingValues(0.dp),
    ) {
        group.children.forEach { child ->
            SettingsNodeView(node = child, onAction = onAction, rowInset = rowInset)
        }
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
    val icon = row.icon
    when (row.component) {
        MiuixRowComponent.SWITCH -> SwitchPreference(
            checked = row.switchValue ?: false,
            onCheckedChange = {
                onAction(row.action ?: SettingsAction.WRITE_SETTING, row.actionTarget, row.id)
            },
            title = row.title,
            summary = row.subtitle,
            enabled = row.enabled,
            startAction = if (icon != null) {
                { SettingsLeadingBadge(icon) }
            } else {
                null
            },
        )

        MiuixRowComponent.ARROW -> when {
            // 上下两行（高级页的更新日志：时刻在上、正文在下，Flutter `:750-781`）。
            row.stacked -> StackedRow(row = row)
            // 长按行（自定义假期的长按删除，Flutter `:568-570`）。
            row.longPressAction != null -> LongPressArrowRow(
                row = row,
                icon = icon,
                click = click,
                onAction = onAction,
            )
            else -> ArrowPreference(
                title = row.title,
                titleColor = titleColors(row),
                summary = row.subtitle,
                onClick = click,
                enabled = row.enabled,
                startAction = if (icon != null) {
                    { SettingsLeadingBadge(icon) }
                } else {
                    null
                },
                endActions = {
                    TrailingText(SettingsRowRenderTable.trailingText(row))
                    row.trailingAction?.let { TrailingActionHint(it) }
                },
            )
        }

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

        // 单选项有两种形态，靠 `options` 的条数区分：
        // * 一条 = 本仓设置族的常规写法「一选项一行」（`SettingsAppearancePage` 那批），
        //   行本身就是那颗单选钮；
        // * 多条 = **一行里横排全部分段**（材质面板的「默认材质 / 首页顶栏玻璃 /
        //   卡片外观」三处，Dart 是 `_MaterialSegmented`，即官方 `TabRow` 的轮廓轨道 +
        //   连续滑动指示器）。上一版只读 `selectedOptionId`、不画 `options`，
        //   于是这三处在屏上是「一行单选、选项既看不见也点不到」。
        MiuixRowComponent.RADIO -> if (row.options.size > 1) {
            SegmentedRow(row = row, onAction = onAction)
        } else {
            RadioButtonPreference(
                title = row.title,
                selected = row.selectedOptionId != null,
                onClick = click ?: {},
                summary = row.subtitle,
                enabled = row.enabled,
                endActions = { row.trailingAction?.let { TrailingActionHint(it) } },
            )
        }

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
 * 上下两行的行（[SettingsRow.stacked]）：第一行 [SettingsRow.title] 用次要色小字，
 * 第二行 [SettingsRow.subtitle] 用正文字色——逐字对齐 Flutter 高级页的更新日志条目
 * （`settings_holiday.dart:750-781`：时刻 `listDetail` + tabular 数字，正文 `listDetail`
 * + `primaryText` 色）。
 *
 * 用官方 `BasicComponent` 的 content 槽承载，不自绘行容器；`enabled = false` 让它不响应点击
 * （原版日志条目本来就不可点）。tabular 数字（`tnum`）在 Dart 侧是
 * `FontFeature.tabularFigures()`，Compose 的同义写法是 `fontFeatureSettings = "tnum"`。
 */
@Composable
private fun StackedRow(row: SettingsRow) {
    BasicComponent(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = BasicComponentDefaults.InsideMargin,
        enabled = row.enabled,
    ) {
        Text(
            text = row.title,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            style = MiuixTheme.textStyles.body2.copy(fontFeatureSettings = "tnum"),
        )
        if (!row.subtitle.isNullOrEmpty()) {
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = row.subtitle!!,
                color = MiuixTheme.colorScheme.onBackground,
                style = MiuixTheme.textStyles.body2,
            )
        }
    }
}

/**
 * 支持长按的行（[SettingsRow.longPressAction]）：外观与官方 `ArrowPreference` 一致
 * （标题 / 摘要 / 行首徽章 / 行尾文本 + 右箭头），但点击与长按都挂在我们自己的
 * `Modifier.combinedClickable` 上。
 *
 * 为什么要重画这一行：官方 `ArrowPreference` **没有长按回调**（0.9.4 `ArrowPreference.kt:49-62`
 * 的形参表里只有 `onClick`），而 Flutter 侧的自定义假期行有 `onLongPress`（`:568-570`）。
 * `BasicComponent` 只在 `onClick != null` 时才自己挂 `clickable`（`Component.kt:146-158`），
 * 所以这里传 `onClick = null`、由外层 `combinedClickable` 同时接管点击与长按——
 * 仍然是官方组件 + 官方指示（`LocalIndication`），没有自研控件。
 */
@Composable
private fun LongPressArrowRow(
    row: SettingsRow,
    icon: SettingsRowIcon?,
    click: (() -> Unit)?,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val longPress = row.longPressAction ?: return
    BasicComponent(
        modifier = Modifier.combinedClickable(
            interactionSource = interaction,
            indication = LocalIndication.current,
            enabled = row.enabled,
            onLongClick = { onAction(longPress, row.longPressTarget, row.id) },
            onClick = { click?.invoke() },
        ),
        title = row.title,
        titleColor = titleColors(row),
        summary = row.subtitle,
        startAction = if (icon != null) {
            { SettingsLeadingBadge(icon) }
        } else {
            null
        },
        endActions = {
            // 与官方 ArrowPreference 同一套排布：行尾读数（有的话）在前、右箭头在后。
            val trailing = SettingsRowRenderTable.trailingText(row)
            if (!trailing.isNullOrEmpty()) {
                Row(
                    modifier = Modifier
                        .align(Alignment.CenterVertically)
                        .padding(end = 8.dp),
                ) {
                    TrailingText(trailing)
                }
            }
            ArrowEndAction(enabled = row.enabled)
        },
        enabled = row.enabled,
        interactionSource = interaction,
    )
}

/**
 * 行尾右箭头：与官方 `ArrowPreference` 的 `ArrowPreferenceEndAction` **同尺寸同色**
 * （10×16dp、`onSurfaceVariantActions` / 禁用 `disabledOnSecondaryVariant`）。
 * 官方那个是 `private`，长按行只能按同样的口径画一次。
 */
@Composable
private fun RowScope.ArrowEndAction(enabled: Boolean) {
    val tint = if (enabled) {
        MiuixTheme.colorScheme.onSurfaceVariantActions
    } else {
        MiuixTheme.colorScheme.disabledOnSecondaryVariant
    }
    Icon(
        imageVector = MiuixIcons.Basic.ArrowRight,
        contentDescription = null,
        tint = tint,
        modifier = Modifier
            .align(Alignment.CenterVertically)
            .size(width = 10.dp, height = 16.dp),
    )
}

/**
 * 设置首页顶部的**学期摘要卡**（Flutter `HyperosSummaryCard`，`cards.dart:58-135`）：
 * 白卡 + 44dp 应用启动图（圆角 12）+「第 N 周 / 共 M 周」+ 开学日期 + 右箭头，可点进学期设置。
 *
 * 它不是普通设置行：不套在分组卡里，自己就是一张 16dp 内边距的可点白卡。原先模型把它
 * 当成一条普通 ARROW 行渲染，于是设置首页顶部**少了一整张卡**（用户 2026-10-28 指出）。
 */
@Composable
private fun SummaryCardRow(
    row: SettingsRow,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val click: (() -> Unit)? = row.action?.let { action ->
        { onAction(action, row.actionTarget, row.id) }
    }
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        cornerRadius = QingyuShapes.SETTINGS_GROUP_RADIUS.dp,
        insideMargin = PaddingValues(16.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .let { if (click != null) it.clickable(onClick = click) else it },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (row.leadingAppIcon) {
                // 自适应启动图的两层 PNG 叠起来画（与 StatisticsExportCards 同一套做法；
                // `ic_launcher.xml` 是 adaptive-icon，painterResource 在部分系统上画不出）。
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(12.dp)),
                ) {
                    Image(
                        painter = painterResource(id = R.mipmap.ic_launcher_background),
                        contentDescription = null,
                        modifier = Modifier.size(44.dp),
                        contentScale = ContentScale.Crop,
                    )
                    Image(
                        painter = painterResource(id = R.mipmap.ic_launcher_foreground),
                        contentDescription = null,
                        modifier = Modifier.size(44.dp),
                        contentScale = ContentScale.Crop,
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.title,
                    style = MiuixTheme.textStyles.body1,
                    color = MiuixTheme.colorScheme.onBackground,
                )
                row.subtitle?.let { sub ->
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = sub,
                        style = MiuixTheme.textStyles.footnote1,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    )
                }
            }
            if (click != null) {
                Spacer(modifier = Modifier.width(8.dp))
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

/**
 * 行首彩色图标徽章（Flutter `HyperosIconBadge` 的对应物）：26dp 圆角方块 + 14dp 白色图标。
 *
 * 尺寸/圆角逐字对齐 `hyperos_tokens.dart:63-65`（`iconBadgeSize=26`、`iconGlyphSize=14`、
 * `iconBadgeRadius=26*7/26=7`）——设置页每一行前面的彩色小方块就是它。
 * 官方 preference 族的 `startAction` 插槽正好承载这一块；颜色由模型给（`tintHex`），
 * 缺省退回主题主色。图标名走 [miuixIconByName] 映射，未知名退回 Info。
 */
@Composable
private fun SettingsLeadingBadge(icon: SettingsRowIcon) {
    val tint = parseHexColor(icon.tintHex) ?: MiuixTheme.colorScheme.primary
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(RoundedCornerShape(7.dp))
            .background(tint),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = miuixIconByName(icon.name),
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
    }
}

/**
 * 模型里的图标名 → miuix 官方图标。
 *
 * 名字与 Flutter 侧 `MiuixIcons.extended.byName('layers')` 的字符串**逐字一致**
 * （见 `timetable_settings_screen.dart` 各行 `settingsIconBadge(...)`）。
 * 认不出的名字退回 Info；新增图标时**两边一起加**，并有守卫测试扫源码防漏。
 */
private fun miuixIconByName(name: String): ImageVector = when (name) {
    "pin" -> MiuixIcons.Pin
    "location" -> MiuixIcons.Location
    "refresh" -> MiuixIcons.Refresh
    "layers" -> MiuixIcons.Layers
    "timer" -> MiuixIcons.Timer
    "favorites" -> MiuixIcons.Favorites
    "favoritesFill" -> MiuixIcons.FavoritesFill
    "gridView" -> MiuixIcons.GridView
    "months" -> MiuixIcons.Months
    "weeks" -> MiuixIcons.Weeks
    "cloudFill" -> MiuixIcons.CloudFill
    "alarm" -> MiuixIcons.Alarm
    "home" -> MiuixIcons.Home
    "theme" -> MiuixIcons.Theme
    "sidebar" -> MiuixIcons.Sidebar
    "tune" -> MiuixIcons.Tune
    "convertFile" -> MiuixIcons.ConvertFile
    "backup" -> MiuixIcons.Backup
    "link" -> MiuixIcons.Link
    "notes" -> MiuixIcons.Notes
    "report" -> MiuixIcons.Report
    "info" -> MiuixIcons.Info
    "background" -> MiuixIcons.Background
    "stopwatch" -> MiuixIcons.Stopwatch
    "listView" -> MiuixIcons.ListView
    "show" -> MiuixIcons.Show
    else -> MiuixIcons.Info
}

private fun parseHexColor(hex: String?): Color? {
    val raw = hex?.trim()?.removePrefix("#") ?: return null
    if (raw.length != 6) return null
    val value = raw.toLongOrNull(16) ?: return null
    // 动态十六进制色（来自用户课程色），不是写死的设计色；用 RGB 分量构造，
    // 语义等价（不透明），同时避开样式守卫对 `Color(0x…)` 固定色的拦截。
    return Color(
        red = ((value shr 16) and 0xFF).toFloat() / 255f,
        green = ((value shr 8) and 0xFF).toFloat() / 255f,
        blue = (value and 0xFF).toFloat() / 255f,
        alpha = 1f,
    )
}

/**
 * 滑杆行。
 *
 * 2026-10-27 起用**官方** `preference.SliderPreference`（0.9.4 才有这个组件）。
 * 在此之前这里是「`basic.BasicComponent` + `basic.Slider` 包一层」的手写实现
 * ——那是 0.8.8 时代没有官方滑杆行的临时方案，现在官方有了就不该再自绘
 * （规格 Failure mode 6：官方已有组件直接 import，不许重复造轮子）。
 *
 * 2026-11-02：官方 `Slider` 不认「点轨道」（纯点不越过 touch slop，`draggable`
 * 不启动），换成 [QingyuSliderPreference] —— 它是官方行的逐字副本，只把内层
 * `Slider` 换成 [com.mutx163.qingyu.components.QingyuSlider]（补点击跳转）。
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
    // 「点开数值输入框」：Dart `HyperosSliderTile.tapToEdit` 默认 true（:491-660），
    // 点行或数值 → `showHyperosSliderValueDialog`（:339-395）→ 确认后 `onChanged`。
    // 只有模型给了 `dialogHelper` 的行才开这个入口：没给的（全站其它滑杆）保持
    // `onClick = null`，该组件因此既不画行尾箭头、点行也没反应——与改动前完全一致。
    var editing by remember(row.id) { mutableStateOf(false) }
    QingyuSliderPreference(
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
        // `onClick != null` 时官方组件会在行尾补一个箭头（`SliderPreference.kt:112`
        // `val showArrow = onClick != null`），观感等同 Dart 的 `HyperosChevron`。
        onClick = spec.dialogHelper?.let { { editing = true } },
        valueRange = spec.min.toFloat()..spec.max.toFloat(),
        steps = (spec.divisions - 1).coerceAtLeast(0),
        // 建议点位原样交给官方组件（它自己画刻点并按 `magnetThreshold` 吸附）：
        // 材质面板那几根旋钮在 Dart 侧就是靠这个把「预设档」变得好停
        // （`settings_appearance_editor.dart:1441-1444` / :1492-1495 等）。
        showKeyPoints = spec.showKeyPoints && !spec.keyPoints.isNullOrEmpty(),
        keyPoints = spec.keyPoints?.map { it.toFloat() },
    )
    val helper = spec.dialogHelper
    if (editing && helper != null) {
        SliderValueDialog(
            title = row.title,
            helper = helper,
            initialValue = value,
            min = spec.min,
            max = spec.max,
            divisions = spec.divisions,
            onDismiss = { editing = false },
            onConfirm = { changed ->
                editing = false
                // 与拖动滑杆**同一条**写入口：同一个值串格式、同一个 rowId。
                onAction(SettingsAction.WRITE_SETTING, changed.toString(), row.id)
            },
        )
    }
}

/**
 * 滑杆的数值输入弹框（Dart `showHyperosSliderValueDialog` →
 * `_HyperosSliderValueSheetBody`，`lib/ui/hyperos/hyperos_controls.dart:339-470`）。
 *
 * 与 Dart 的形态差异（有意，且都只为「不新造界面方言」）：
 * - Dart 是 `HyperosSheetFrame(chrome: floating)` 的浮动面板；这里用官方 [OverlayDialog]——
 *   miuix 0.9.4 的 sheet 家族要走 `show` + 自定义 chrome，为一个数字输入框拉一套
 *   面板容器得不偿失，且设置页其它弹框（`SettingsHost` 的说明框）也都用 OverlayDialog；
 * - Dart `autofocus: true`（进来即弹键盘）；这里不抢焦点：Compose 侧自动弹键盘会让
 *   系统返回手势先收键盘、用户得点两次才关得掉弹框，收益不如代价。
 *
 * 校验口径与 Dart 一致：解析不出数字就停在原地并显示提示语（Dart `_errorText`），
 * 能解析则按 [SettingsSliderValueLogic.normalize] 吸附档位 + 夹到区间。
 */
@Composable
private fun SliderValueDialog(
    title: String,
    helper: String,
    initialValue: Double,
    min: Double,
    max: Double,
    divisions: Int,
    onDismiss: () -> Unit,
    onConfirm: (Double) -> Unit,
) {
    var text by remember {
        mutableStateOf(SettingsSliderValueLogic.inputText(initialValue, min, max, divisions))
    }
    var invalid by remember { mutableStateOf(false) }
    OverlayDialog(
        show = true,
        title = title,
        onDismissRequest = onDismiss,
        // 内容自留 8dp（与镜像地址弹框同一口径）；框架侧也 8 ⇒ 单边 16，不是默认 24 + 8。
        insideMargin = DpSize(8.dp, 16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            TextField(
                value = text,
                onValueChange = {
                    text = it
                    invalid = false
                },
                modifier = Modifier.fillMaxWidth(),
                // Dart `TextInputType.numberWithOptions(decimal: true)`：小数键盘。
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
            )
            Text(
                // Dart 解析失败时把 `helper` 塞进 `_errorText`，文案不变、只是变红。
                text = helper,
                style = MiuixTheme.textStyles.footnote1,
                color = if (invalid) {
                    MiuixTheme.colorScheme.error
                } else {
                    MiuixTheme.colorScheme.onSurfaceVariantSummary
                },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = SettingsStringsExt4.cancelAction.zh)
                }
                Button(
                    onClick = {
                        val parsed = text.trim().toDoubleOrNull()
                        if (parsed == null) {
                            invalid = true
                        } else {
                            val changed = SettingsSliderValueLogic.normalize(parsed, min, max, divisions)
                            // Dart：`if (result == null || result == value) return;`
                            // ——输入等于当前值就只关框，不产生一次无意义的写盘。
                            if (changed == initialValue) onDismiss() else onConfirm(changed)
                        }
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = SettingsStrings.confirmAction.zh)
                }
            }
        }
    }
}

/**
 * 「一行里横排全部分段」的单选行。
 *
 * ## 它对应 Dart 的哪个控件
 *
 * `_MaterialSegmented`（`settings_appearance_editor.dart:2358-2398`）—— 薄适配层，真正
 * 的控件是全 App 共用的 `HyperosTabRow`，内部即官方 `MiuixTabRowWithContour`
 * （超椭圆轨道 + 一整块连续滑动的指示器 + 选中态自动加粗 + 每格自带
 * 「第几个 / 共几个、是否选中」的读屏语义）。Compose 侧因此直接用它，
 * **不要再手搓灰轨道 + 全圆胶囊**：那一版 2026-09-26 已被否掉（圆角塌成胶囊撞上
 * 本项目的圆角规矩），而且会造出全项目第二个分段方言。
 *
 * ## 为什么要把 min/max 宽度改成 0 / ∞
 *
 * 上游默认按 62~84dp 定宽从左排，格数少时右边空一大块（`calculateTabWidth` 把
 * 理想宽度夹到这个区间）。Dart 的适配层把这一条改掉了（「默认铺满整行」），
 * 这里用同一手法：夹取区间放到两端，于是 `idealWidth = 可用宽 / 格数` 原样生效。
 *
 * ## 为什么这一行不画 `row.title`
 *
 * 材质面板三处（默认材质 / 首页顶栏玻璃 / 卡片外观）在 Dart 里都是
 * 「`HyperosSectionLabel` 分组标题 + 分段」，分段自身没有标题；模型里的
 * `row.title` 只是给文案对照测试用的元数据，画出来会和分组标题重复一遍。
 */
@Composable
private fun SegmentedRow(
    row: SettingsRow,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
) {
    val selectedIndex = row.options.indexOfFirst { it.id == row.selectedOptionId }
        .coerceAtLeast(0)
    TabRowWithContour(
        tabs = row.options.map { it.label },
        selectedTabIndex = selectedIndex,
        onTabSelected = { index ->
            val option = row.options.getOrNull(index)
            if (option != null) {
                onAction(row.action ?: SettingsAction.WRITE_SETTING, option.id, row.id)
            }
        },
        minWidth = 0.dp,
        maxWidth = Dp.Infinity,
        // 与行内其它控件同一条左缘轴线（官方 preference 的 `insideMargin` 是 16）。
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

/** 行尾读数（`HyperosSliderTile.valueLabel` / `HyperosNavTile.details` 同一槽位）。 */
@Composable
private fun RowScope.TrailingText(text: String?) {    if (text.isNullOrEmpty()) return
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
        // 桌面小组件「效果预览」：十张真实卡片位图的横向轮播
        // （`settings_home_widget.dart:405-499`）。它与 PREVIEW_CARD 完全不是一套管线，
        // 所以单独一个 kind、单独一个组件。
        InlineKind.WIDGET_PREVIEW -> WidgetPreviewSection(node = node)
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
            style = MiuixTheme.textStyles.headline1
                .shiftWeight(QingyuWeightDelta.MEDIUM),
        )
        Spacer(modifier = Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PreviewTile(
                modifier = Modifier.weight(1f),
                container = colors.primary,
                contentColor = colors.onPrimary,
                label = node.texts.getOrNull(0)?.text.orEmpty(),
                sublabel = node.texts.getOrNull(1)?.text.orEmpty(),
            )
            PreviewTile(
                modifier = Modifier.weight(1f),
                container = colors.surfaceContainer,
                // 第二块是「卡片色 + 正文色」的样张（Dart 用默认 listDetail 字色）。
                // 以前两块的文字都取 `onPrimary`，亮色下第二块是白底白字、整块看不见。
                contentColor = colors.onSurfaceContainer,
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
    contentColor: Color,
    label: String,
    sublabel: String?,
) {
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
            color = contentColor,
            style = MiuixTheme.textStyles.body2,
        )
        if (!sublabel.isNullOrEmpty()) {
            Text(
                text = sublabel,
                color = contentColor.copy(alpha = 0.7f),
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
                            // 2026-11-01 F25：回传**这一组**的 rowId（`node.id`），不再写死课卡色。
                            // 写死会让课表页背景色板也写成「课卡统一色」——宿主里还留着一层
                            // 从 ROW_CARD_COLOR_CHIPS 到 ROW_TP_BG_CHIPS 的翻译兜底，但那是补丁。
                            onAction(
                                SettingsAction.WRITE_SETTING,
                                hex,
                                node.id,
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
            style = MiuixTheme.textStyles.headline1
                .shiftWeight(QingyuWeightDelta.MEDIUM),
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
                            // busy 期间吞掉点击：Dart 的 `onPressed: _refreshing ? null : …`（`:807`）。
                            if (wiring != null && !node.busy) {
                                onAction(wiring.first, null, wiring.second)
                            }
                        },
                        enabled = !node.busy,
                    ) {
                        if (node.busy) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                        }
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

    // 节假日两页的两颗整宽按钮（2026-10-29）。键与行 id 都是页面模型里写死的那两处：
    // - 「添加假期」：`SettingsHolidayPage` 的 `holiday.card.add`（原版 `settings_holiday.dart:576-592`）；
    // - 「检查更新」：`SettingsHolidayAdvancedPage` 的 `holidayAdvanced.card.refresh`（`:792-812`）。
    // 动作语义：前者弹新增弹层（SHEET），后者立刻刷数据（RUN_NOW）；
    // 宿主按 rowId 认，两个都只当「界面意图」转出去，渲染层不碰业务判据。
    "customHolidayAdd" -> SettingsAction.SHEET to "holiday.card.add"

    "holidayCheckUpdate" -> SettingsAction.RUN_NOW to "holidayAdvanced.card.refresh"

    // 小组件页「精确闹钟未授权」引导条上的「去授权」（2026-10-31，F20-B）。
    // Dart :1043-1059 的 `HyperosButton(onPressed: _requestExactAlarmPermission)`；
    // 动作语义是 RUN_NOW（宿主按 rowId 走 `WidgetSystemActions.requestScheduleExactAlarm`），
    // 不走 WRITE_SETTING —— 分派器对这两行只回纯意图，不写设置。
    "homeWidgetExactAlarmGrantAction" -> SettingsAction.RUN_NOW to
        SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT

    // 「实时活动自检」页（b.liveSelfCheck，2026-10-31 F23）。这三个键原先不在白名单里，
    // 于是 `SettingsInlineText` 拿到 null wiring ⇒ onClick 为 null ⇒ **看着能点、点了没反应**
    // （认领文件 F23 §2 实测）。rowId 由宿主 `LiveSelfCheckHost` 自己的常量认领，
    // 不进 `SettingsActionDispatcher`（先例 `SettingsHolidayAdvancedHost.kt:23`）：
    // - 清空日志 → `AppLogStore.clear()` + `clearNative()`；
    // - 查看手机日志 → `onOpenPage("h.log")`；
    // - 更多测试者选项 → 诚实提示 `aboutUnavailable`（Kotlin 侧没有这个页面）。
    // 清空进行中的「正在清空…」不登记（那一瞬间按钮本就该无动作）。
    "liveTestingClearLogsAction" -> SettingsAction.RUN_NOW to
        "liveSelfCheck.card.localLogs.clear"

    "liveTestingViewPhoneLogsAction" -> SettingsAction.RUN_NOW to
        "liveSelfCheck.card.localLogs.view"

    "liveTestingMoreTesterOptionsAction" -> SettingsAction.RUN_NOW to
        "liveSelfCheck.card.localLogs.more"

    // 上岛状态卡「刷新诊断」：宿主收到 rowId 后立刻重读一次 `buildDebugStatus`。
    // 顺带登记「正在刷新…」那一个键——首次读取失败时它会一直留在按钮上，
    // 不登记就成了一条新的「看着能点、点了没反应」。
    "liveTestingRefreshAction" -> SettingsAction.RUN_NOW to "liveSelfCheck.island.refresh"

    "liveTestingRefreshing" -> SettingsAction.RUN_NOW to "liveSelfCheck.island.refresh"

    // 2026-11-01 F24：自检页剩余控件收口。同样由宿主常量认领 rowId，不进分派器。
    // - 导出并分享日志：主路径调原生 `UmengDiagnosticReporter.exportLiveDiagnosticsFile`，
    //   拿不到文件时回退到脱敏诊断快照（Dart `settings_live.dart:330-382` 同口径）；
    // - 测试通知四颗：崩溃 / 卡顿按 `MainActivity` 的 UMENG 通道分支搬运，真触发；
    //   开始/取消测试与选课测试原生侧没有入口 ⇒ 诚实提示不可用。
    // 「导出中」也登记到同一个 rowId：控制卡没有 busy 态，不登记就是又一颗点不动的死按钮；
    // 宿主开头有 `if (exportingDiagnostics) return`，重复点击是安全空操作。
    "liveTestingExportAction" -> SettingsAction.RUN_NOW to "liveSelfCheck.island.export"

    "liveTestingExporting" -> SettingsAction.RUN_NOW to "liveSelfCheck.island.export"

    "liveTestingStartAction" -> SettingsAction.RUN_NOW to "liveSelfCheck.notification.start"

    "liveTestingCancelAction" -> SettingsAction.RUN_NOW to "liveSelfCheck.notification.cancel"

    "liveTestingCourseTestAction" -> SettingsAction.RUN_NOW to
        "liveSelfCheck.notification.courseTest"

    "liveTestingCourseTestStopAction" -> SettingsAction.RUN_NOW to
        "liveSelfCheck.notification.courseTestStop"

    "liveTestingCrashAction" -> SettingsAction.RUN_NOW to "liveSelfCheck.notification.crashTest"

    "liveTestingAnrAction" -> SettingsAction.RUN_NOW to "liveSelfCheck.notification.anrTest"

    else -> null
}

/**
 * 只渲染节点列表、**不带页面骨架**的入口。
 *
 * 给「外观编辑」页的两个底部面板用（材质 / 壁纸）。面板是**根覆盖层自插条目**：
 * 任何二级路由 / 弹层都会落在它背面被挡住（2026-09-19 真机实锤），所以面板正文
 * 只能是内联的一层——但它的内容与设置列表**同源**（同一批 [SettingsNode]），
 * 于是这里把「列表那半」单独开放出来，行部件继续共用 [SettingsNodeView]。
 *
 * 与 [SettingsPageScreen] 的两处差异（有意）：
 * * 不带顶栏 / 返回键 / 大标题折叠——面板顶上是它自己的翻页胶囊，那才是这一层的标题；
 * * 不由本函数吃 `innerPadding`：面板的左右内缩来自官方弹层的 `insideMargin`，
 *   再垫一层就是 32。调用方按自己的面板几何传 [contentPadding]。
 *
 * @param rowInset 分组白卡的左右内缩；面板里传 `0.dp`（弹层的 `insideMargin` 已经是
 *   Dart 那个 16，卡片再垫 12 会让行左缘比 Dart 多 12）。`null` = 设置列表的默认轴线。
 */
@Composable
fun SettingsNodeList(
    nodes: List<SettingsNode>,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(bottom = 24.dp),
    rowInset: Dp? = null,
) {
    QingyuPageList(
        innerPadding = PaddingValues(0.dp),
        modifier = modifier,
        contentPadding = contentPadding,
    ) {
        items(items = nodes, key = { it.id }) { node ->
            SettingsNodeView(node = node, onAction = onAction, rowInset = rowInset)
        }
    }
}
