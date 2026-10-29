package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 时间模板「编辑节次」页 · Compose 渲染层（P35-TS · ts-editor）。
 *
 * ## 对应 Dart 的哪几段
 *
 * | Dart（`lib/screens/time_scheme_management_screen.dart`） | 这里 |
 * |---|---|
 * | `_TimeSchemeEditorScreen` 类本身 `:1227-1258`（持有 `name` 文本 + `sections` 列表 + 上一个快捷生成 preset） | **本层不持有状态**，全部由 [TimeSchemeEditorModel] 给出，改动通过回调上报（`onNameChange` / `onAddSection` / …）。这是与 Dart 最大的结构差异：Dart 是 StatefulWidget 自己 `setState`，Compose 侧把「状态」与「渲染」分给模型层和本文件 |
 * | `build` `:1261-1397` 的页面本体（`HyperosSubpage` 顶栏 + 两张 `HyperosControlCard`） | [QingyuPageScaffold] 顶栏 + 两张 [QingyuCard] |
 * | 卡一「模板名称」`:1284-1339`（输入框 / 状态徽标 / 三个计数 chip / 影响提示 / 引用预览） | [NameCard] |
 * | 卡二「节次时间」`:1341-1393`（副标题 / 四个按钮 / 每节一行） | [SectionsCard] |
 * | `_editSectionTime` `:1399-1457`（开始 → 结束**两跳**时间选择器 + 跨天判定 + 整表校验） | **不在本文件**：本层只从行点击里把「点了第几节」上报给宿主（`onPickSectionTime(index)`）。两跳、`isSectionTimeSpanValid` 的跨天判定、`24:00` 哨兵的保留都归宿主串（契约 §3 明写「页面只报点了第几节」），单节落地判据在模型层的 `withSectionTime` |
 * | `_addSection` / `_removeSection` / `_resetSections` `:1459-1480` | 三个回调；**判据不在本层**：按钮是否置灰取模型层的 `canAdd` / `canRemove`（Dart 是当场算 `canAppendSection(_sections)`） |
 * | `_save` `:1588-1618`（落盘 + 校验码提示 + 成功才 pop） | `onSave` 一个回调。**故意不在此处判可点**：Dart 的保存按钮永远可点，校验失败由落盘那一步返回提示码再弹 toast；这里照同口径交给宿主，不静默禁用 |
 *
 * ## 与 Dart 的三处有意偏差（都是「官方组件替代同语义」）
 *
 * 1. **保存按钮**：Dart 是顶栏右上**一个勾选图标**（`FHeaderAction(Icons.check_rounded)`，
 *    语义标签 `saveAction`）。这里用官方 `TextButton` 把「保存」写成**可见文字**：同一个
 *    `saveAction` 文案，一步可认，不必猜勾是保存还是确认。
 * 2. **卡片标题**：Dart 的 `HyperosControlCard(title: …)` 把标题画在**卡片内部**；
 *    这里按官方 demo 的页面轴线改成卡外的 [QingyuSectionTitle]（R6：`SmallTitle` 自带 28dp 左缘，
 *    与卡内 16dp 内边距+卡外 12dp 外边距落在同一条竖线上），因此**标题文字一致、位置差一层卡片圆角**。
 * 3. **每节行的行尾**：Dart 写 `'${start} - ${end}'`（连字符两侧各一个空格）。模型层的
 *    `TimeSchemeSectionRow.rangeText` 取的是 core 的 `displayText`（`08:00-08:45`，**无空格**，
 *    列表页首节起止用的就是这一份）。本层按 Dart 这一处**逐字**复原成 `start + " - " + end`，
 *    两边都用的是同一组 `startTime` / `endTime`，不是第二套格式化判据。
 *
 * ## 界面上没有的文案，本层不编
 *
 * 屏上每一句都来自 [TimeSchemeManagementStrings]（名称/徽标/三个 chip 的 label 与 value/两句影响提示/
 * 副标题/四个按钮/保存/「第 {section} 节」），与 `lib/l10n/app_zh.arb` 逐字对拍过。
 *
 * @param model 已算好的编辑器状态（名称、节次行、顶部信息区、四个按钮的置灰判据）
 * @param onBack 返回
 * @param onNameChange 名称输入框每次改动
 * @param onSave 右上「保存」：**永远可点**，校验与提示由宿主/`validateForSave()` 给
 * @param onPickSectionTime 点了第几节（0 基）→ 宿主弹「开始 → 结束」两跳时间选择器
 * @param onAddSection 新增一节（宿主侧还会再过一遍 `canAdd`）
 * @param onRemoveLastSection 删除末节
 * @param onResetSections 恢复默认作息
 * @param onOpenQuickGenerate 打开快捷生成弹层（[TimeSchemeQuickGenerateSheet]）
 */
@Composable
fun TimeSchemeEditorPage(
    model: TimeSchemeEditorModel,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onSave: () -> Unit,
    onPickSectionTime: (index: Int) -> Unit,
    onAddSection: () -> Unit,
    onRemoveLastSection: () -> Unit,
    onResetSections: () -> Unit,
    onOpenQuickGenerate: () -> Unit,
) {
    QingyuPageScaffold(
        title = model.sheet.title,
        onBack = onBack,
        actions = {
            // Dart `:1271-1277` 的 FHeaderAction：永远可点，点了直接提交流程（校验在保存那一步）。
            TextButton(
                text = model.sheet.saveLabel,
                onClick = onSave,
                colors = ButtonDefaults.textButtonColorsPrimary(),
            )
        },
    ) {
        // 官方页面骨架：LazyColumn + 滚动三件套 + 滚动条（见 QingyuPageList 注释）。
        // Dart 用的是 `HyperosListView`（标准列表路径，大标题可折叠）——同一个角色。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(key = "name") {
                NameCard(model = model, onNameChange = onNameChange)
            }
            item(key = "sections") {
                SectionsCard(
                    model = model,
                    onPickSectionTime = onPickSectionTime,
                    onAddSection = onAddSection,
                    onRemoveLastSection = onRemoveLastSection,
                    onResetSections = onResetSections,
                    onOpenQuickGenerate = onOpenQuickGenerate,
                )
            }
        }
    }
}

/**
 * 卡一「模板名称」（Dart `:1284-1339`）：输入框 + 状态徽标 + 三个计数 chip + 影响提示 + 引用预览。
 *
 * 包的是普通内容（输入框与自排的 chip 流），所以必须给 `ContentInsideMargin`（16dp）——
 * 不给就贴着卡片边（见 `QingyuCard` 注释）。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun NameCard(
    model: TimeSchemeEditorModel,
    onNameChange: (String) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val header = model.header

    Column(modifier = Modifier.fillMaxWidth()) {
        QingyuSectionTitle(text = TimeSchemeManagementStrings.timeSchemeNameLabel.zh)
        Spacer(Modifier.height(8.dp))
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = QingyuCardDefaults.ContentInsideMargin,
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                TextField(
                    value = model.name,
                    onValueChange = onNameChange,
                    // Dart 传的是 `hint: l10n.timeSchemeNameHint`（占位符，不是浮动标签）：
                    // 「模板名称」这四个字已经由上面的分组标题承担，卡里再飘一遍就是同屏念两遍。
                    label = TimeSchemeManagementStrings.timeSchemeNameHint.zh,
                    useLabelAsPlaceholder = true,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )

                Spacer(Modifier.height(12.dp))

                // Dart `Wrap(spacing: 8, runSpacing: 8)` → 官方 FlowRow（同一个换行语义）。
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    // `if (isActive) _TimeSchemeBadge(text: currentInUse)`：主色 12% 底 + 主色字，
                    // 比计数 chip 更"亮"一档，与 Dart 一致（`:1768-1785`）。
                    if (header.showInUseBadge) {
                        EditorTag(text = header.inUseBadgeText, accent = true)
                    }
                    // 三个计数 chip：`'$label $value'`（Dart `_TimeSchemeInfoChip` :1756-1766）。
                    for (chip in header.chips) {
                        EditorTag(text = "${chip.label} ${chip.value}")
                    }
                }

                // 影响提示：`if (isActive || usage.courseCount > 0)`——由模型层挑好那一句，
                // 本层只认「空串 = 不显示」。
                if (header.impactHint.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = header.impactHint,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }

                // 引用预览：`if (usage.previewText != null)`，最多两行省略（Dart `:1327-1335`）。
                val preview = header.previewText
                if (!preview.isNullOrEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = preview,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

/**
 * 卡二「节次时间」（Dart `:1341-1393`）：副标题 + 四个按钮 + 每节一行。
 *
 * 内边距分两层，照 Dart 的 `HyperosControlCard` 骨架：
 *
 * - 上半块（副标题 + 按钮流）自带 16dp：`HyperosControlCardInset`；
 * - 每节一行是 `HyperosListTile`，**自带 16dp**。
 *
 * 所以卡片本身 `insideMargin = 0`，上下两块各自带 16 —— 两边都落在「12（卡外）+16 = 28」这条线上，
 * 不会出现「副标题比行标题左缩 16dp」的错位。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SectionsCard(
    model: TimeSchemeEditorModel,
    onPickSectionTime: (index: Int) -> Unit,
    onAddSection: () -> Unit,
    onRemoveLastSection: () -> Unit,
    onResetSections: () -> Unit,
    onOpenQuickGenerate: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val sheet = model.sheet

    Column(modifier = Modifier.fillMaxWidth()) {
        QingyuSectionTitle(text = sheet.sectionTimesTitle)
        Spacer(Modifier.height(8.dp))
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            // 行子是 BasicComponent（自带 16dp），上半块自己补 16dp ⇒ 卡片本身不留边。
            insideMargin = PaddingValues(0.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp),
            ) {
                Text(
                    text = sheet.sectionTimesSubtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Spacer(Modifier.height(12.dp))
                // Dart `Wrap(spacing: 8, runSpacing: 8)` 里四个 `HyperosButton(variant: secondary)`。
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    // 快捷生成：永远可点（Dart 没给它置灰条件）。
                    SectionActionButton(
                        label = sheet.quickGenerateLabel,
                        enabled = true,
                        onClick = onOpenQuickGenerate,
                    )
                    // 新增一节：`canAppendSection(_sections) ? _addSection : null`。
                    SectionActionButton(
                        label = sheet.addSectionLabel,
                        enabled = model.canAdd,
                        onClick = onAddSection,
                    )
                    // 删除末节：`_sections.length <= 1 ? null : _removeSection`。
                    SectionActionButton(
                        label = sheet.removeLastSectionLabel,
                        enabled = model.canRemove,
                        onClick = onRemoveLastSection,
                    )
                    // 恢复默认：Dart 无条件可点（`canReset` 恒 true，模型层保留成判据以防以后变）。
                    SectionActionButton(
                        label = sheet.resetDefaultLabel,
                        enabled = model.canReset,
                        onClick = onResetSections,
                    )
                }
            }

            // Dart `if (_sections.isNotEmpty) HyperosControlCardRows(...)`：一节都没有时整块不画。
            for (row in model.rows) {
                BasicComponent(
                    title = row.label,
                    startAction = { SectionTimeBadge() },
                    endActions = {
                        // Dart `details: '${start} - ${end}'`（连字符两侧各一空格），见文件头偏差 3。
                        Text(
                            text = "${row.startTime} - ${row.endTime}",
                            style = MiuixTheme.textStyles.body2,
                            color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        )
                    },
                    // 点这一行 → 宿主弹「开始 → 结束」两跳时间选择器（单节落地判据在模型层）。
                    onClick = { onPickSectionTime(row.index) },
                )
            }
        }
    }
}

/**
 * 节次行行首的图标徽标：Dart `HyperosListTile(icon: access_time_rounded, iconAccent: teal)`。
 *
 * `HyperosIconBadge` 的形状是「26dp 实色圆角方块 + 14dp 白色字形」（`tiles.dart:155-164`），
 * 与 `CourseOverviewPage` 里同一处 Dart 写法的落地方式一致（那边是 orange 的告警徽标）。
 */
@Composable
private fun SectionTimeBadge() {
    Box(
        modifier = Modifier
            .size(26.dp)
            .background(Color(QingyuIconColors.TEAL), RoundedCornerShape(7.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Timer,
            // 装饰性图标：同一行里已经有「第 N 节」的文字，读屏不必再念一遍。
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
    }
}

/**
 * 卡里的四个次要按钮。官方 `Button` 的次要色（`buttonColors()`）+ `enabled`，
 * 与 Dart `HyperosButton(variant: HyperosButtonVariant.secondary, onPressed: null)` 的置灰同义。
 */
@Composable
private fun SectionActionButton(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(),
    ) {
        Text(text = label)
    }
}

/**
 * 小胶囊标签：Dart 的 `HyperosTag`（`lib/ui/hyperos/hyperos_badge.dart:55-97`）。
 *
 * 官方 miuix 没有 tag/chip 组件（`Badge` 是角标红点，语义不同），所以按 Dart 的参数逐项落：
 * 内边距 `horizontal 8 / vertical 2`、圆角 `6`、默认底色 `secondaryContainer`、
 * 字色默认 `onBackground`。`accent = true` 是 Dart `_TimeSchemeBadge` 那一档：
 * 底色换成主色 12%、字色换成主色（`:1775-1782`）。
 *
 * 字号：Dart `HyperosTag` 默认 12sp、`_TimeSchemeBadge` 用 13sp（`sectionDescriptionSize`）。
 * 官方字阶里没有 12sp（footnote1 = 13、footnote2 = 11），这里统一取 footnote1 ——
 * 徽标与计数 chip **同一档**，避免同一行里两个胶囊一大一小。
 */
@Composable
private fun EditorTag(
    text: String,
    accent: Boolean = false,
) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = if (accent) colors.primary else colors.onBackground,
        modifier = Modifier
            .background(
                color = if (accent) colors.primary.copy(alpha = 0.12f) else colors.secondaryContainer,
                shape = RoundedCornerShape(6.dp),
            )
            .padding(horizontal = 8.dp, vertical = 2.dp),
    )
}
