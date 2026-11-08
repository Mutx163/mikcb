package com.mutx163.qingyu.pages.schedule

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.preference.SwitchPreference

/**
 * 作息时间表自动切换日期规则页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/schedule_date_rule_screen.dart`：
 * 规则卡片列表 + 新增/编辑弹层 + 删除二次确认。
 */
@Composable
fun ScheduleDateRulePage(
    rules: List<ScheduleDateRuleItemView>,
    availableSchemes: List<Pair<String, String>>, // id to name
    onBack: () -> Unit,
    onSaveRule: (ScheduleDateRuleData) -> Unit,
    onDeleteRule: (ScheduleDateRuleData) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var editingRule by remember { mutableStateOf<ScheduleDateRuleData?>(null) }
    var isAddingNew by remember { mutableStateOf(false) }
    var deletingRule by remember { mutableStateOf<ScheduleDateRuleData?>(null) }
    var bannerMessage by remember { mutableStateOf<String?>(null) }
    // 弹层常驻（为了退场动画），表单状态不能只靠「重新进入组合」重置；
    // 每次打开编辑框都递增这个会话号，编辑框里用 remember(session) 重建字段。
    var editorSession by remember { mutableStateOf(0) }

    // 共享骨架（2026-11-05 B 组迁移）：官方顶栏 + 标准返回键 + 顶栏毛玻璃 + actions 槽。
    // 返回键的显隐与玻璃圆底的出没门控都由骨架注入；大标题仍可折叠
    //（Dart `schedule_date_rule_screen.dart:27` 走 HyperosSubpage 默认参数）。
    QingyuPageScaffold(
        title = ScheduleStrings.scheduleDateRuleSectionTitle.text,
        onBack = onBack,
        // Dart 侧右侧是 FHeaderAction(Icons.add_rounded)。
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
        actions = {
            QingyuGlassIconButton(
                onClick = {
                    if (availableSchemes.isEmpty()) {
                        bannerMessage = ScheduleStrings.scheduleDateRuleNeedScheme.text
                        return@QingyuGlassIconButton
                    }
                    if (rules.size >= ScheduleDateRuleDomain.MAX_RULES_PER_DEVICE) {
                        bannerMessage = ScheduleStrings.scheduleDateRuleMaxReached.text
                        return@QingyuGlassIconButton
                    }
                    bannerMessage = null
                    isAddingNew = true
                    editingRule = ScheduleDateRuleData(
                        id = "rule_${System.currentTimeMillis()}",
                        name = "",
                        timeSchemeId = availableSchemes.first().first,
                        startDate = "2026-10-01",
                        endDate = "2027-04-30",
                        enabled = true,
                    )
                    editorSession++
                },
                contentDescription = ScheduleStrings.scheduleDateRuleAdd.text,
                icon = MiuixIcons.Add,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        },
    ) {
        // 主滚动统一走共享套件（R2）：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
        // 与右侧滚动条。底部手势条由本页**显式**算一次放进 contentPadding，所以喂给套件的
        // innerPadding 只取顶部——套件内部还会再加一次它的 bottom，两份都给会算两遍。
        QingyuPageList(
            innerPadding = PaddingValues(top = innerPadding.calculateTopPadding()),
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(
                top = 4.dp,
                // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                bottom = innerPadding.calculateBottomPadding() + 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 说明小标题：仅在有规则时显示；空态走统一空状态，不再「说明一行 + 空卡片」叠着。
            if (rules.isNotEmpty()) {
                item(key = "subtitle") {
                    Text(
                        text = ScheduleStrings.scheduleDateRuleSectionSubtitle.text,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            }

            bannerMessage?.let { banner ->
                item(key = "banner") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                        insideMargin = PaddingValues(10.dp),
                    ) {
                        Text(
                            text = banner,
                            color = Color(QingyuTheme.error(dark)),
                            style = MiuixTheme.textStyles.footnote1,
                        )
                    }
                }
            }

            if (rules.isEmpty()) {
                // ── 空态：与 App 其它页（TaskEmptyState / CourseOverviewEmptyState）统一：
                // 居中 图标(48) + 主标题(headline1) + 主操作按钮；不再 fillParentMaxSize + 空卡片。──
                item(key = "empty") {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 32.dp, vertical = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            imageVector = MiuixIcons.Months,
                            contentDescription = null,
                            tint = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.size(48.dp),
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = ScheduleStrings.scheduleDateRuleEmpty.text,
                            style = MiuixTheme.textStyles.headline1,
                            color = Color(QingyuTheme.primaryText(dark)),
                            textAlign = TextAlign.Center,
                        )
                        Spacer(modifier = Modifier.height(20.dp))
                        ScheduleActionButton(
                            text = ScheduleStrings.scheduleDateRuleAdd.text,
                            primary = true,
                            onClick = {
                                if (availableSchemes.isEmpty()) {
                                    bannerMessage = ScheduleStrings.scheduleDateRuleNeedScheme.text
                                    return@ScheduleActionButton
                                }
                                bannerMessage = null
                                isAddingNew = true
                                editingRule = ScheduleDateRuleData(
                                    id = "rule_${System.currentTimeMillis()}",
                                    name = "",
                                    timeSchemeId = availableSchemes.first().first,
                                    startDate = "2026-10-01",
                                    endDate = "2027-04-30",
                                    enabled = true,
                                )
                                editorSession++
                            },
                        )
                    }
                }
            } else {
                // ── 规则卡片列表：横向留白按配方由每张卡自己带 12dp ──
                items(rules, key = { it.rule.id }) { item ->
                    ScheduleDateRuleCard(
                        item = item,
                        dark = dark,
                        modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                        onEdit = {
                            isAddingNew = false
                            editingRule = item.rule
                            editorSession++
                        },
                        onDelete = {
                            deletingRule = item.rule
                        },
                    )
                }
            }
        }
    }

    // 新增/编辑规则弹框：官方 OverlayDialog，由 `show` 驱动（弹层常驻，退场动画不被掐）。
    RuleEditorDialog(
        draft = editingRule,
        isNew = isAddingNew,
        session = editorSession,
        existingRules = rules.map { it.rule },
        availableSchemes = availableSchemes,
        dark = dark,
        onDismiss = { editingRule = null },
        onConfirm = { updatedRule ->
            onSaveRule(updatedRule)
            editingRule = null
        },
    )

    // 删除规则确认框
    RuleDeleteConfirmDialog(
        candidate = deletingRule,
        onDismiss = { deletingRule = null },
        onConfirm = { rule ->
            onDeleteRule(rule)
            deletingRule = null
        },
    )
}

@Composable
private fun ScheduleDateRuleCard(
item: ScheduleDateRuleItemView,
dark: Boolean,
modifier: Modifier = Modifier,
onEdit: () -> Unit,
onDelete: () -> Unit,
) {
val rule = item.rule
val rangeText = ScheduleStrings.scheduleDateRuleRangeSummary
    .filled("start" to rule.startDate, "end" to rule.endDate)

QingyuCard(
    modifier = modifier.fillMaxWidth(),
    insideMargin = PaddingValues(14.dp),
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = rule.name,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.primaryText(dark)),
            )
            if (item.isActiveToday) {
                Text(
                    text = ScheduleStrings.scheduleDateRuleActiveToday.text,
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primary(dark = dark)),
                )
            }
        }

        Text(
            text = rangeText,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )

        Text(
            text = item.schemeName.ifEmpty { ScheduleStrings.locationTimeMatchUnknownScheme.text },
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )

        HorizontalDivider(modifier = Modifier.fillMaxWidth())

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ScheduleActionButton(
                text = ScheduleStrings.editAction.text,
                onClick = onEdit,
            )
            Spacer(modifier = Modifier.width(8.dp))
            ScheduleActionButton(
                text = ScheduleStrings.deleteAction.text,
                onClick = onDelete,
                destructive = true,
            )
        }
    }
}
}

@Composable
private fun RuleEditorDialog(
draft: ScheduleDateRuleData?,
isNew: Boolean,
session: Int,
existingRules: List<ScheduleDateRuleData>,
availableSchemes: List<Pair<String, String>>,
dark: Boolean,
onDismiss: () -> Unit,
onConfirm: (ScheduleDateRuleData) -> Unit,
) {
// 弹层常驻（为了退场动画），字段状态按 `session` 重建：否则关掉再开同一条规则，
// 会看到上一次没提交的编辑残留。
val currentDraft = draft
var name by remember(session) { mutableStateOf(currentDraft?.name.orEmpty()) }
var startDate by remember(session) { mutableStateOf(currentDraft?.startDate.orEmpty()) }
var endDate by remember(session) { mutableStateOf(currentDraft?.endDate.orEmpty()) }
var schemeId by remember(session) { mutableStateOf(currentDraft?.timeSchemeId.orEmpty()) }
var enabled by remember(session) { mutableStateOf(currentDraft?.enabled ?: true) }
var dialogError by remember(session) { mutableStateOf<String?>(null) }

// 字段多：矮屏或键盘弹出时必须能滚。限高按屏高走，动作行固定留在滚动区外。
// 不用 `Column + verticalScroll`（R2 守卫判红、且非惰性），走官方 LazyColumn + 滚动两件套。
val maxFormHeight = rememberSheetMaxHeight(0.55f)

OverlayDialog(
    show = currentDraft != null,
    title = if (isNew) {
        ScheduleStrings.scheduleDateRuleAdd.text
    } else {
        ScheduleStrings.scheduleDateRuleEdit.text
    },
    onDismissRequest = onDismiss,
    insideMargin = DpSize(16.dp, 16.dp),
) {
    if (currentDraft != null) {
        Column(modifier = Modifier.fillMaxWidth()) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxFormHeight)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                item(key = "form") {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        dialogError?.let { err ->
                            Text(
                                text = err,
                                color = Color(QingyuTheme.error(dark)),
                                style = MiuixTheme.textStyles.footnote1,
                            )
                        }

                        TextField(
                            value = name,
                            onValueChange = { name = it },
                            label = ScheduleStrings.scheduleDateRuleNameLabel.text,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TextField(
                                value = startDate,
                                onValueChange = { startDate = it },
                                label = ScheduleStrings.scheduleDateRuleStartDate.text,
                                modifier = Modifier.weight(1f),
                            )
                            TextField(
                                value = endDate,
                                onValueChange = { endDate = it },
                                label = ScheduleStrings.scheduleDateRuleEndDate.text,
                                modifier = Modifier.weight(1f),
                            )
                        }

                        // 方案单选行
                        Text(
                            text = ScheduleStrings.scheduleDateRuleBoundScheme.text,
                            style = MiuixTheme.textStyles.footnote1,
                            // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                            color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            for ((id, schemeName) in availableSchemes) {
                                val isSelected = schemeId == id
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { schemeId = id }
                                        .padding(vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Text(
                                        text = schemeName,
                                        style = MiuixTheme.textStyles.body2.shiftWeight(
                                            if (isSelected) QingyuWeightDelta.SEMIBOLD else 0,
                                        ),
                                        color = if (isSelected) {
                                            Color(QingyuTheme.primary(dark = dark))
                                        } else {
                                            Color(QingyuTheme.primaryText(dark))
                                        },
                                    )
                                    if (isSelected) {
                                        Text(
                                            text = "✓",
                                            style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                                            color = Color(QingyuTheme.primary(dark = dark)),
                                        )
                                    }
                                }
                            }
                        }

                        // 2026-10-29 修（审核 misc-wiring P1-7）：原来是「文字 + 一颗会变字的按钮」，
                        // 按钮文案 `已启用` / `已停用` 是渲染层写死的中文，ARB 里没有这两个词；
                        // 而 Dart `schedule_date_rule_screen.dart:328-333` 用的是带 label 的开关
                        // （`_DateRuleSwitchField`：左侧文案 + 右侧 `HyperosSwitch`，整行可点）。
                        // 现改回官方 `SwitchPreference`，文案走 `ScheduleStrings.scheduleDateRuleEnabled`（="启用"）。
                        SwitchPreference(
                            title = ScheduleStrings.scheduleDateRuleEnabled.text,
                            checked = enabled,
                            onCheckedChange = { enabled = it },
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.text,
                    onClick = onDismiss,
                )
                ScheduleActionButton(
                    text = ScheduleStrings.saveAction.text,
                    onClick = {
                        val candidate = currentDraft.copy(
                            name = name.trim(),
                            startDate = startDate.trim(),
                            endDate = endDate.trim(),
                            timeSchemeId = schemeId,
                            enabled = enabled,
                        )
                        val result = ScheduleDateRuleDomain.validateRule(
                            draft = candidate,
                            existingRules = existingRules,
                            isEditing = !isNew,
                        )
                        when (result) {
                            is ScheduleDateRuleValidationResult.Valid -> {
                                dialogError = null
                                onConfirm(candidate)
                            }
                            is ScheduleDateRuleValidationResult.Invalid -> {
                                dialogError = result.errorText
                            }
                        }
                    },
                    modifier = Modifier.weight(1f),
                    primary = true,
                )
                }
            }
        }
    }
}

@Composable
private fun RuleDeleteConfirmDialog(
    candidate: ScheduleDateRuleData?,
    onDismiss: () -> Unit,
    onConfirm: (ScheduleDateRuleData) -> Unit,
) {
    OverlayDialog(
        show = candidate != null,
        title = ScheduleStrings.scheduleDateRuleDeleteTitle.text,
        summary = candidate?.let {
            ScheduleStrings.scheduleDateRuleDeleteMessage.filled("name", it.name)
        },
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        if (candidate != null) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.text,
                    onClick = onDismiss,
                )
                ScheduleActionButton(
                    text = ScheduleStrings.deleteAction.text,
                    onClick = { onConfirm(candidate) },
                    modifier = Modifier.weight(1f),
                    destructive = true,
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 about/ContributorsPage.kt 样板铺）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 3 档：两条规则（今天生效 + 未生效）/ 还没有规则 / 只有一条可用方案；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 暗色 —— 历史上出现过「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()）；这一档就是防它复发；
//   · 大字号 —— 卡片里的「2026-11-01 至 2027-03-31」区间行最先被挤掉；
//   · 空规则 —— 空态与其右上的「+」是另一套渲染分支；
//   · 只有一条可用方案 —— 新建对话框只剩一个可选方案（唯一选项）路径。
//
// 固定写法：主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }；
// 字号用 QingyuPageTheme(textScale = …)，不用 @Preview(fontScale = …)；
// 宽度按 400dp（本仓折行实测口径），高度给一屏多。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：两条日期规则，一条今天生效、一条未启用。 */
private fun previewScheduleDateRules(): List<ScheduleDateRuleItemView> = listOf(
    ScheduleDateRuleItemView(
        rule = ScheduleDateRuleData(
            id = "rule_preview_1",
            name = "冬季作息",
            timeSchemeId = "scheme_winter",
            startDate = "2026-11-01",
            endDate = "2027-03-31",
            enabled = true,
        ),
        schemeName = "冬季作息（8:00 上课）",
        isActiveToday = true,
    ),
    ScheduleDateRuleItemView(
        rule = ScheduleDateRuleData(
            id = "rule_preview_2",
            name = "夏季作息",
            timeSchemeId = "scheme_summer",
            startDate = "2027-04-01",
            endDate = "2027-10-31",
            enabled = false,
        ),
        schemeName = "夏季作息（8:30 上课）",
        isActiveToday = false,
    ),
)

/** 预览用作息方案：id to 名称。 */
private val previewAvailableSchemes: List<Pair<String, String>> = listOf(
    "scheme_winter" to "冬季作息（8:00 上课）",
    "scheme_summer" to "夏季作息（8:30 上课）",
)

/** 一档预览的公共身体：规则数据 + 外观档位。 */
@Composable
private fun PreviewScheduleDateRulePage(
    rules: List<ScheduleDateRuleItemView>,
    availableSchemes: List<Pair<String, String>> = previewAvailableSchemes,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        ScheduleDateRulePage(
            rules = rules,
            availableSchemes = availableSchemes,
            onBack = {},
            onSaveRule = {},
            onDeleteRule = {},
        )
    }
}

// ── 单档：数据三态 × 亮色 ──────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 两条规则", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleDateRulePagePreviewData() {
    PreviewScheduleDateRulePage(previewScheduleDateRules())
}

@Suppress("unused")
@Preview(name = "2 还没有规则", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleDateRulePagePreviewEmpty() {
    PreviewScheduleDateRulePage(rules = emptyList())
}

@Suppress("unused")
@Preview(name = "3 只有一条方案", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleDateRulePagePreviewSingleScheme() {
    PreviewScheduleDateRulePage(
        rules = previewScheduleDateRules().take(1),
        availableSchemes = previewAvailableSchemes.take(1),
    )
}

// ── 单档：外观两档（以「两条规则」为基准）──────────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleDateRulePagePreviewDark() {
    PreviewScheduleDateRulePage(previewScheduleDateRules(), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleDateRulePagePreviewLargeText() {
    PreviewScheduleDateRulePage(previewScheduleDateRules(), textScale = 1.3f)
}

// ── 总览：三态并排，一屏看完 ─────────────────────────────────────────────────

/**
 * 一屏总览：两条规则 / 空规则 / 暗色 横向并排，用来一眼比结构差异。
 *
 * 3 × 400dp + 2 × 16dp 间距 = 1232dp，所以画布给 1280dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~5 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·三态并排", showBackground = true, widthDp = 1280, heightDp = 900)
@Composable
private fun ScheduleDateRulePagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewScheduleDateRulePage(previewScheduleDateRules())
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewScheduleDateRulePage(rules = emptyList())
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewScheduleDateRulePage(previewScheduleDateRules(), dark = true)
        }
    }
}
