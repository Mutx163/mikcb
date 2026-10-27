package com.mutx163.qingyu.pages.schedule

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
import androidx.compose.foundation.layout.statusBarsPadding
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.theme.MiuixTheme

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

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            // ── 顶栏 ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack, backgroundColor = Color.Transparent) {
                    Icon(
                        imageVector = MiuixIcons.Back,
                        contentDescription = ScheduleStrings.cancelAction.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
                Text(
                    text = ScheduleStrings.scheduleDateRuleSectionTitle.zh,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.weight(1f),
                )
                MiuixActionButton(
                    text = ScheduleStrings.scheduleDateRuleAdd.zh,
                    onClick = {
                        if (availableSchemes.isEmpty()) {
                            bannerMessage = ScheduleStrings.scheduleDateRuleNeedScheme.zh
                            return@MiuixActionButton
                        }
                        if (rules.size >= ScheduleDateRuleDomain.MAX_RULES_PER_DEVICE) {
                            bannerMessage = ScheduleStrings.scheduleDateRuleMaxReached.zh
                            return@MiuixActionButton
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
                    },
                )
            }

            // 说明小标题
            Text(
                text = ScheduleStrings.scheduleDateRuleSectionSubtitle.zh,
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )

            bannerMessage?.let { banner ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    insideMargin = PaddingValues(10.dp),
                ) {
                    Text(
                        text = banner,
                        color = Color(QingyuTheme.error(dark)),
                        fontSize = 13.sp,
                    )
                }
            }

            if (rules.isEmpty()) {
                // ── 空态 ──
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(24.dp),
                    ) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Text(
                                text = ScheduleStrings.scheduleDateRuleEmpty.zh,
                                fontSize = 16.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                            MiuixActionButton(
                                text = ScheduleStrings.scheduleDateRuleAdd.zh,
                                onClick = {
                                    if (availableSchemes.isEmpty()) {
                                        bannerMessage = ScheduleStrings.scheduleDateRuleNeedScheme.zh
                                        return@MiuixActionButton
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
                                },
                            )
                        }
                    }
                }
            } else {
                // ── 规则卡片列表 ──
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(rules, key = { it.rule.id }) { item ->
                        ScheduleDateRuleCard(
                            item = item,
                            dark = dark,
                            onEdit = {
                                isAddingNew = false
                                editingRule = item.rule
                            },
                            onDelete = {
                                deletingRule = item.rule
                            },
                        )
                    }
                }
            }
        }
    }

    // 新增/编辑规则弹框
    editingRule?.let { draft ->
        RuleEditorDialog(
            draft = draft,
            isNew = isAddingNew,
            existingRules = rules.map { it.rule },
            availableSchemes = availableSchemes,
            dark = dark,
            onDismiss = { editingRule = null },
            onConfirm = { updatedRule ->
                onSaveRule(updatedRule)
                editingRule = null
            },
        )
    }

    // 删除规则确认框
    deletingRule?.let { candidate ->
        RuleDeleteConfirmDialog(
            candidate = candidate,
            dark = dark,
            onDismiss = { deletingRule = null },
            onConfirm = {
                onDeleteRule(candidate)
                deletingRule = null
            },
        )
    }
}

@Composable
private fun ScheduleDateRuleCard(
    item: ScheduleDateRuleItemView,
    dark: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val rule = item.rule
    val rangeText = ScheduleStrings.scheduleDateRuleRangeSummary
        .filled("start" to rule.startDate, "end" to rule.endDate)

    Card(
        modifier = Modifier.fillMaxWidth(),
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
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                if (item.isActiveToday) {
                    Text(
                        text = ScheduleStrings.scheduleDateRuleActiveToday.zh,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color(QingyuTheme.primary(dark = dark)),
                    )
                }
            }

            Text(
                text = rangeText,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )

            Text(
                text = item.schemeName.ifEmpty { ScheduleStrings.locationTimeMatchUnknownScheme.zh },
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )

            HorizontalDivider(modifier = Modifier.fillMaxWidth())

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                MiuixActionButton(
                    text = ScheduleStrings.editAction.zh,
                    onClick = onEdit,
                )
                Spacer(modifier = Modifier.width(8.dp))
                MiuixActionButton(
                    text = ScheduleStrings.deleteAction.zh,
                    onClick = onDelete,
                )
            }
        }
    }
}

@Composable
private fun RuleEditorDialog(
    draft: ScheduleDateRuleData,
    isNew: Boolean,
    existingRules: List<ScheduleDateRuleData>,
    availableSchemes: List<Pair<String, String>>,
    dark: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (ScheduleDateRuleData) -> Unit,
) {
    var name by remember { mutableStateOf(draft.name) }
    var startDate by remember { mutableStateOf(draft.startDate) }
    var endDate by remember { mutableStateOf(draft.endDate) }
    var schemeId by remember { mutableStateOf(draft.timeSchemeId) }
    var enabled by remember { mutableStateOf(draft.enabled) }
    var dialogError by remember { mutableStateOf<String?>(null) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = if (isNew) ScheduleStrings.scheduleDateRuleAdd.zh else ScheduleStrings.scheduleDateRuleEdit.zh,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color(QingyuTheme.primaryText(dark)),
            )

            dialogError?.let { err ->
                Text(
                    text = err,
                    color = Color(QingyuTheme.error(dark)),
                    fontSize = 12.sp,
                )
            }

            TextField(
                value = name,
                onValueChange = { name = it },
                label = ScheduleStrings.scheduleDateRuleNameLabel.zh,
                modifier = Modifier.fillMaxWidth(),
            )

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextField(
                    value = startDate,
                    onValueChange = { startDate = it },
                    label = ScheduleStrings.scheduleDateRuleStartDate.zh,
                    modifier = Modifier.weight(1f),
                )
                TextField(
                    value = endDate,
                    onValueChange = { endDate = it },
                    label = ScheduleStrings.scheduleDateRuleEndDate.zh,
                    modifier = Modifier.weight(1f),
                )
            }

            // 方案单选行
            Text(
                text = ScheduleStrings.scheduleDateRuleBoundScheme.zh,
                fontSize = 13.sp,
                color = Color(QingyuTheme.sectionLabel(dark)),
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
                            fontSize = 14.sp,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) Color(QingyuTheme.primary(dark = dark)) else Color(QingyuTheme.primaryText(dark)),
                        )
                        if (isSelected) {
                            Text(
                                text = "✓",
                                color = Color(QingyuTheme.primary(dark = dark)),
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = ScheduleStrings.scheduleDateRuleEnabled.zh,
                    fontSize = 14.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                MiuixActionButton(
                    text = if (enabled) "已启用" else "已停用",
                    onClick = { enabled = !enabled },
                )
            }

            HorizontalDivider(modifier = Modifier.fillMaxWidth())

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                MiuixActionButton(
                    text = ScheduleStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Spacer(modifier = Modifier.width(8.dp))
                MiuixActionButton(
                    text = ScheduleStrings.saveAction.zh,
                    onClick = {
                        val candidate = draft.copy(
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
                )
            }
        }
    }
}

@Composable
private fun RuleDeleteConfirmDialog(
    candidate: ScheduleDateRuleData,
    dark: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = ScheduleStrings.scheduleDateRuleDeleteTitle.zh,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = ScheduleStrings.scheduleDateRuleDeleteMessage.filled("name", candidate.name),
                fontSize = 14.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                MiuixActionButton(
                    text = ScheduleStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Spacer(modifier = Modifier.width(8.dp))
                MiuixActionButton(
                    text = ScheduleStrings.deleteAction.zh,
                    onClick = onConfirm,
                )
            }
        }
    }
}


/**
 * miuix 0.9.4 对齐补丁：0.9.4 的 `Button` 只有 `content: @Composable RowScope.() -> Unit`，
 * 不再有 `text` 参数（0.8.8 才有）。这里包一层，保持既有调用点的 `text = …` 形状，
 * 避免把每处按钮正文都重写一遍。
 */
@Composable
private fun MiuixActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(onClick = onClick, modifier = modifier, enabled = enabled) {
        Text(
            text = text,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = MiuixTheme.colorScheme.onPrimary,
        )
    }
}
