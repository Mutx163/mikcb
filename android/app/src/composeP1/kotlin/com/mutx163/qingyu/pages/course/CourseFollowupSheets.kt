package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.rememberCappedSheetHeight
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Clear
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Pause
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 周视图课程弹层的四个「后续弹层」渲染层（Phase 3.5 · 泳道 F）。
 *
 * Dart 唯一判据 `lib/widgets/course_followup_sheets.dart`（1015 行）：
 *
 * | 弹层 | Dart 出处 | 本文件 |
 * |---|---|---|
 * | 删除范围 | `:99-150` | [CourseDeleteScopeSheet] |
 * | 停课范围 | `:152-209` | [CourseSuspendScopeSheet] |
 * | 删除确认 | `:211-276` | [CourseDeleteConfirmSheet] |
 * | 调课 | `:278-735` | [CourseRescheduleSheet] |
 * | 共用外观 | `:737-1015` | 本文件下半部分的 `Followup*` 私有件 |
 *
 * ## 为什么要拆成「模型 + 渲染」
 *
 * 判据（能不能删这节课、步进到哪、节次区间换成几点、有没有变化、预览行怎么写）
 * 全在 [CourseFollowupModel] / [CourseRescheduleDraft] 里，**纯 Kotlin、JVM 可测**；
 * 本文件只画不算，一个判据都不自己判断 —— 所以单测能钉住行为，而不需要跑真机。
 *
 * ## 与 Dart 的三处已知差异（都在报告里报过）
 *
 * 1. **地点候选历史（已接线，2026-11-10）**：Dart 的调课弹层会弹
 *    `showCourseFieldPickerSheet` 列出历史地点（`locationSuggestions`，`course_followup_sheets.dart:421`）。
 *    本层现在有 `locationSuggestions` 入参：候选由壳用
 *    `CourseFieldSuggestionLogic.build(snapshot.courses, snapshot.scheduleItems)` 算好注入，
 *    弹层里「手输 + 历史候选」并存；候选为空时就是纯手输，**不伪造历史**。
 * 2. **周 / 节次选择器**：Dart 是 `showHyperosSelectSheet`（列表弹层），本层同样是列表弹层
 *    （[FollowupPickerSheet]），不是数字步进；步进只留给「周」那对 ± 按钮（Dart 也有）。
 * 3. **容器高度**：Dart 调课弹层限高 `屏高 × 0.88` + 顶部滚动 + 底部按钮固定。
 *    本层用 `heightIn(max = 屏高 × 0.72)` 的可滚列表 + 固定底部按钮，效果同构（列表自己滚）；
 *    0.72 = Dart 的 0.88 总预算扣掉固定的底部按钮区 + 底部让位 + miuix 顶部把手，
 *    与同域 `AddCoursePage.kt` 的正文限高比例一致，矮屏时列表跟着缩、按钮不再被挤出屏。
 *
 * ## 纪律
 *
 * 渲染层**零中文字面量**（`CjkLiteralGateTest` course 域基线为空）：屏上每个字都从
 * [CourseFollowupStrings] 或 [CourseRescheduleDraft.presentation] 来。
 */

// ─────────────────────────────────────────────────────────────────────
// 一、共用外观（Dart `:737-1015`）
// ─────────────────────────────────────────────────────────────────────

/**
 * 弹层容器（Dart `_FollowupSheetContainer` `:852-864`：`HyperosSheetFrame` + 四边内缩）。
 *
 * 左右 16dp、底部让出手势区 + 16、限高与滚动**全部由 [QingyuSheet] 套件统一给**
 *（口径来源见那支文件的 KDoc：miuix 默认 24 侧边距 + 只让键盘不让手势条，两处都跟
 * Dart 不一样）。本函数只保留「内容成一个 Column」这一件事。
 */
@Composable
private fun FollowupSheet(
    show: Boolean,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    QingyuSheet(show = show, onDismissRequest = onDismiss) {
        Column(modifier = Modifier.fillMaxWidth(), content = content)
    }
}

/**
 * 标题行：48dp 图标块 + 标题 + 可选副题（Dart `_FollowupSheetHeader` `:866-919`）。
 *
 * @param iconTint 图标与图标块底色（块底色 = 该色 12% 透明度，Dart `:891`）
 */
@Composable
private fun FollowupHeader(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    subtitle: String?,
) {
    val secondaryText = Color(QingyuTheme.secondaryText(isSystemInDarkTheme()))
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        // 图标块：48dp、圆角 14、底色 = 图标色 12%（Dart `:887-896`）
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(iconTint.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(24.dp),
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
                color = Color(QingyuTheme.primaryText(isSystemInDarkTheme())),
            )
            if (subtitle != null && subtitle.isNotEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = subtitle,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                )
            }
        }
    }
}

/**
 * 选项行：图标 + 标题 + 副题 + 箭头（Dart `_FollowupOptionTile` `:921-995`）。
 *
 * [enabled] 为 false 时整行置灰、不可点（Dart 传 `onTap: null`）——**灰着但仍读得出理由**，
 * 这就是「本周不能删这节课」的解释入口。
 */
@Composable
private fun FollowupOptionRow(
    icon: ImageVector,
    title: String,
    subtitle: String?,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val foreground = if (enabled) primaryText else secondaryText
    val chevronColor = if (enabled) secondaryText else secondaryText.copy(alpha = 0.5f)

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 12.dp,
        insideMargin = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        onClick = if (enabled) onClick else null,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = foreground,
                modifier = Modifier.size(18.dp),
            )
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = foreground,
                )
                if (subtitle != null && subtitle.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = subtitle,
                        style = MiuixTheme.textStyles.footnote2,
                        color = secondaryText,
                    )
                }
            }
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = chevronColor,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/** 通栏「取消」按钮（Dart `_FollowupCancelButton` `:997-1015`）。 */
@Composable
private fun FollowupCancelButton(onPress: () -> Unit) {
    Button(
        onClick = onPress,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(text = CourseFollowupStrings.cancelAction.text)
    }
}

/**
 * 「标签 + 取值 + 箭头」的可点字段（Dart `_buildCompactSelectField` `:432-480`）。
 *
 * 标签用次要色、取值用前景色，单行省略（Dart 的 `maxLines: 1` + `ellipsis`）。
 */
@Composable
private fun FollowupFieldCard(
    field: CourseFollowupField,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)?,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        cornerRadius = 10.dp,
        insideMargin = PaddingValues(horizontal = 10.dp, vertical = 8.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = field.label,
                style = MiuixTheme.textStyles.footnote2,
                color = secondaryText,
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = field.value,
                style = MiuixTheme.textStyles.body2,
                color = primaryText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = secondaryText,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

/** 周次步进的 ± 按钮（Dart `_RescheduleStepButton` `:776-795`，禁用即彻底不可点）。 */
@Composable
private fun FollowupStepButton(
    icon: ImageVector,
    contentDescription: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    IconButton(
        onClick = onClick,
        enabled = enabled,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = if (enabled) {
                Color(QingyuTheme.primaryText(dark))
            } else {
                Color(QingyuTheme.secondaryText(dark))
            },
            modifier = Modifier.size(18.dp),
        )
    }
}

/**
 * 星期胶囊（Dart `_WeekdayChoiceChip` `:797-850`）。
 *
 * 选中态 = 强调色描边 + 强调色文字 + 10% 底色（Dart `:826-843`），未选中 = 常规前景色。
 */
@Composable
private fun FollowupWeekdayChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val accent = MiuixTheme.colorScheme.primary
    val highlight = if (selected) accent else Color(QingyuTheme.primaryText(dark))

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 999.dp,
        insideMargin = PaddingValues(horizontal = 4.dp, vertical = 6.dp),
        colors = followupCardColors(if (selected) accent.copy(alpha = 0.10f) else Color.Transparent),
        onClick = onClick,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(
                if (selected) QingyuWeightDelta.BOLD else QingyuWeightDelta.MEDIUM,
            ),
            color = highlight,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** 卡片配色：只改底色（`QingyuCard` 的语义圆角与按压反馈照旧）。 */
@Composable
private fun followupCardColors(color: Color) =
    CardDefaults.defaultColors(color = color)

/**
 * 列表选择弹层（Dart `showHyperosSelectSheet` 的对位件，`:482-500` 调用）。
 *
 * 与 `TaskPickerSheets` 同一配方：官方字阶 + 选中项打勾 + 末端轻震 + 过度滚动。
 */
@Composable
private fun FollowupPickerSheet(
    show: Boolean,
    title: String,
    options: List<CourseFollowupPickerItem>,
    onDismiss: () -> Unit,
    onPick: (Int) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val accent = MiuixTheme.colorScheme.primary

    QingyuSheet(
        show = show,
        title = title,
        // 内容自己有 LazyColumn ⇒ 滚动与底部让位都归它：套件不再套 verticalScroll
        //（否则嵌套滚动会崩），让位值由 `bottomInset` 塞进列表的 contentPadding。
        contentScrolls = true,
        onDismissRequest = onDismiss,
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = rememberCappedSheetHeight(380.dp))
                .scrollEndHaptic()
                .overScrollVertical(),
            contentPadding = PaddingValues(bottom = bottomInset),
        ) {
            items(options) { option ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(option.value) }
                        .padding(horizontal = 12.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = option.label,
                        style = MiuixTheme.textStyles.main.shiftWeight(
                            if (option.selected) QingyuWeightDelta.MEDIUM else 0,
                        ),
                        color = if (option.selected) accent else primaryText,
                        modifier = Modifier.weight(1f),
                    )
                    if (option.selected) {
                        Icon(
                            imageVector = MiuixIcons.Ok,
                            contentDescription = null,
                            tint = accent,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 地点编辑弹层（Dart `showCourseFieldPickerSheet` 的最小对位：**手输 + 历史候选 + 清空**）。
 *
 * 候选来自 [CourseRescheduleSheet] 的 `locationSuggestions`（壳用
 * `CourseFieldSuggestionLogic` 从课程 + 日程算好传进来）；输入即过滤（大小写不敏感，
 * 与发布版 `filterFieldSuggestions` 同口径）；候选为空时就是纯手输，不伪造历史。
 */
@Composable
private fun FollowupLocationSheet(
    show: Boolean,
    initial: String,
    title: String,
    suggestions: List<String> = emptyList(),
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var text by remember(show, initial) { mutableStateOf(TextFieldValue(initial)) }
    val dark = isSystemInDarkTheme()
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val normalized = text.text.trim().lowercase()
    val visible = if (normalized.isEmpty()) {
        suggestions
    } else {
        suggestions.filter { it.lowercase().contains(normalized) }
    }

    // 发布版 sheet 口径：**内容滚、按钮钉底**（候选长也不用滚到底才能确认）。
    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        contentScrolls = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = bottomInset),
        ) {
            TextField(
                value = text,
                onValueChange = { text = it },
                label = CourseFollowupStrings.locationLabel.text,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                trailingIcon = {
                    if (text.text.isNotEmpty()) {
                        IconButton(onClick = { text = TextFieldValue("") }) {
                            Icon(
                                imageVector = MiuixIcons.Clear,
                                contentDescription = CourseFollowupStrings.clearAction.text,
                                tint = secondaryText,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                },
            )
            if (visible.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = rememberSheetMaxHeight(0.4f))
                        .scrollEndHaptic()
                        .overScrollVertical(),
                ) {
                    items(visible) { suggestion ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                // 点候选即回填并关闭（发布版一步到位）。
                                .clickable { onConfirm(suggestion) }
                                .padding(horizontal = 12.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = suggestion,
                                style = MiuixTheme.textStyles.body2,
                                color = primaryText,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(14.dp))
            Row(modifier = Modifier.fillMaxWidth()) {
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                    // 取消 = secondary 实心（已裁口径：双键同组件，仅配色分主次）。
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = CourseFollowupStrings.cancelAction.text)
                }
                Spacer(modifier = Modifier.width(12.dp))
                Button(
                    onClick = { onConfirm(text.text) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = CourseFollowupStrings.confirmAction.text)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// 二、四个公开弹层
// ─────────────────────────────────────────────────────────────────────

/**
 * 删除范围（Dart `_CourseDeleteModeSheetBody` `:99-150`）。
 *
 * 「删这个课」永远可点；「删这节课」只在 [canDeleteOccurrence]（= 本周本来就有这门课）时
 * 可点，否则置灰并给出「为什么不能删」的副题。**这一步是误删保护的第一道门**：
 * 旧 Compose 版点「删除」直接删整门课，连问都不问。
 *
 * @param canDeleteOccurrence 本周是不是真有这一次课（调用方给，判据在
 *   `Course.isInWeek(week)`；本层不自己算，避免两处判据漂移）
 * @param week 当前浏览周次（副题占位符用）
 */
@Composable
fun CourseDeleteScopeSheet(
    show: Boolean,
    canDeleteOccurrence: Boolean,
    week: Int,
    onDismiss: () -> Unit,
    onSelect: (CourseDeleteScope) -> Unit,
) {
    val options = remember(canDeleteOccurrence, week) {
        CourseFollowupModel.deleteScopeOptions(canDeleteOccurrence = canDeleteOccurrence, week = week)
    }
    val destructive = MiuixTheme.colorScheme.error

    FollowupSheet(show = show, onDismiss = onDismiss) {
        FollowupHeader(
            icon = MiuixIcons.Delete,
            iconTint = destructive,
            title = CourseFollowupStrings.deleteModeTitle.text,
            subtitle = null,
        )
        Spacer(modifier = Modifier.height(14.dp))
        options.forEachIndexed { index, option ->
            if (index > 0) Spacer(modifier = Modifier.height(8.dp))
            FollowupOptionRow(
                icon = if (option.scope == CourseDeleteScope.WHOLE_COURSE) {
                    MiuixIcons.Delete
                } else {
                    MiuixIcons.Remove
                },
                title = option.title,
                subtitle = option.subtitle.ifEmpty { null },
                enabled = option.enabled,
                onClick = { onSelect(option.scope) },
            )
        }
        Spacer(modifier = Modifier.height(14.dp))
        FollowupCancelButton(onPress = onDismiss)
    }
}

/**
 * 停课范围（Dart `_CourseSuspendModeSheetBody` `:152-209`）。
 *
 * 文案按当前状态切（本周已停 → 「恢复」；有任一周停过 → 「恢复全部」），
 * 切换逻辑在 [CourseFollowupModel.suspendScopeOptions]，本层不重复判断。
 */
@Composable
fun CourseSuspendScopeSheet(
    show: Boolean,
    suspendedThisWeek: Boolean,
    hasAnySuspended: Boolean,
    onDismiss: () -> Unit,
    onSelect: (CourseSuspendScope) -> Unit,
) {
    val options = remember(suspendedThisWeek, hasAnySuspended) {
        CourseFollowupModel.suspendScopeOptions(
            suspendedThisWeek = suspendedThisWeek,
            hasAnySuspended = hasAnySuspended,
        )
    }
    val dark = isSystemInDarkTheme()
    val foreground = Color(QingyuTheme.primaryText(dark))

    FollowupSheet(show = show, onDismiss = onDismiss) {
        FollowupHeader(
            icon = if (suspendedThisWeek) MiuixIcons.Play else MiuixIcons.Pause,
            iconTint = foreground,
            title = CourseFollowupStrings.suspendSheetTitle.text,
            subtitle = CourseFollowupStrings.suspendSheetSubtitle.text,
        )
        Spacer(modifier = Modifier.height(14.dp))
        options.forEachIndexed { index, option ->
            if (index > 0) Spacer(modifier = Modifier.height(8.dp))
            FollowupOptionRow(
                icon = if (option.resuming) MiuixIcons.Play else MiuixIcons.Pause,
                title = option.title,
                subtitle = option.subtitle,
                enabled = true,
                onClick = { onSelect(option.scope) },
            )
        }
        Spacer(modifier = Modifier.height(14.dp))
        FollowupCancelButton(onPress = onDismiss)
    }
}

/**
 * 删除二次确认（Dart `_DeleteCourseConfirmSheetBody` `:211-276`）。
 *
 * **每次删除都走它**（删整门课、删单节课都一样）：标题 + 说明块 + 取消 / 删除。
 * 删除按钮用危险色，且与取消等宽并排 —— 不把危险动作做成更容易点到的整宽主按钮。
 *
 * @param title 标题由调用方给（Dart 用 `deleteScheduleTitle` / `deleteLessonTitle`）
 * @param message 说明块正文（Dart 用 `deleteScheduleConfirmMessage` 等长句）
 */
@Composable
fun CourseDeleteConfirmSheet(
    show: Boolean,
    title: String,
    message: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val destructive = MiuixTheme.colorScheme.error
    val secondaryText = Color(QingyuTheme.secondaryText(dark))

    FollowupSheet(show = show, onDismiss = onDismiss) {
        FollowupHeader(
            icon = MiuixIcons.Delete,
            iconTint = destructive,
            title = title,
            subtitle = null,
        )
        Spacer(modifier = Modifier.height(12.dp))
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            cornerRadius = 12.dp,
            insideMargin = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        ) {
            Text(
                text = message,
                style = MiuixTheme.textStyles.footnote2,
                color = secondaryText,
            )
        }
        Spacer(modifier = Modifier.height(14.dp))
        Row(modifier = Modifier.fillMaxWidth()) {
            TextButton(
                text = CourseFollowupStrings.cancelAction.text,
                onClick = onDismiss,
                modifier = Modifier.weight(1f),
            )
            Spacer(modifier = Modifier.width(12.dp))
            TextButton(
                text = CourseFollowupStrings.deleteAction.text,
                onClick = onConfirm,
                modifier = Modifier.weight(1f),
                // 发布版 destructive 磨砂钮 = 红字 + **淡红水洗底**（`hyperos_controls.dart:846-854`；
                // 这一处对应 `course_followup_sheets.dart:261-266`）：`color` 不给就是中性的
                // secondaryVariant 底；给饱和错误色会变整颗红底 + 灰字，对比度也坏。
                colors = ButtonDefaults.textButtonColors(
                    color = destructive.copy(alpha = if (dark) 0.14f else 0.10f),
                    disabledColor = destructive.copy(alpha = 0.06f),
                    textColor = destructive,
                    disabledTextColor = destructive.copy(alpha = 0.45f),
                ),
            )
        }
    }
}

/** 调课弹层里「正在用哪个选择器」的本地状态。 */
private enum class FollowupPickerKind { WEEK, START_SECTION, END_SECTION }

/**
 * 调课（Dart `_CourseRescheduleSheetBody` `:278-735`）。
 *
 * 结构照 Dart 从上到下：
 * 标题 → 副题 → 「当前：…」行 → 原地点行 → 目标周（± 步进 + 可点选择器）→ 星期胶囊 →
 * 开始/结束节次选择器 → 目标时段 → 地点（可改）→ 「→ …」目标预览 → 取消 / 确认调课。
 *
 * **确认按钮无变化时置灰**（[CourseReschedulePresentation.canConfirm] = `hasChanges`）。
 * 地点也算变化 —— 旧 Compose 版把地点漏在判据外，「只改地点」时确认是灰的，这一版修掉了。
 *
 * @param course 被调的课
 * @param sourceWeek 被调的那一次课所在周
 * @param weekCount 可选周次上界（Dart `settings.availableWeeks`；本层按 1..weekCount 展开）
 * @param weekdayLabels 7 条星期文案（ARB `weekdayMon..Sun`，由调用方注入）
 * @param sectionTimes 这门课解析后的作息节次表（决定可选节次与目标时段钟点）
 * @param locationSuggestions 地点候选（发布版 `locationSuggestions`：壳用
 *   `CourseFieldSuggestionLogic` 从课程 + 日程算好注入；空表 = 纯手输）
 */
@Composable
fun CourseRescheduleSheet(
    show: Boolean,
    course: Course,
    sourceWeek: Int,
    weekCount: Int,
    weekdayLabels: List<String>,
    sectionTimes: List<SectionTime>,
    locationSuggestions: List<String> = emptyList(),
    onDismiss: () -> Unit,
    onConfirm: (CourseRescheduleTarget) -> Unit,
) {
    var draft by remember(show, course.id, sourceWeek) {
        mutableStateOf(CourseRescheduleDraft.initial(course, sourceWeek))
    }
    var picking by remember(show, course.id, sourceWeek) {
        mutableStateOf<FollowupPickerKind?>(null)
    }
    var editingLocation by remember(show, course.id, sourceWeek) { mutableStateOf(false) }

    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val accent = MiuixTheme.colorScheme.primary
    val view = draft.presentation(
        course = course,
        sourceWeek = sourceWeek,
        weekCount = weekCount,
        weekdayLabels = weekdayLabels,
        sectionTimes = sectionTimes,
    )

    // 正文列表限高：屏高 × 0.72（写死 dp 值在矮屏会把底部按钮挤出弹层；
    // 比例依据见本文件 KDoc「与 Dart 的已知差异」第 3 条）。
    val maxListHeight = rememberSheetMaxHeight(RESCHEDULE_LIST_HEIGHT_FRACTION)

    QingyuSheet(
        show = show,
        // 正文里有自己的 LazyColumn（限高按屏高比例自己滚）⇒ 套件不再套 verticalScroll
        //（否则嵌套滚动崩）；底部让位由本层垫在固定按钮下面。
        contentScrolls = true,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = bottomInset),
        ) {
            // 正文可滚（官方手感：末端轻震 + 过度滚动），底部按钮固定在列表外
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxListHeight)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                item {
                    // ── 标题 + 副题（Dart `:571-582`）──
                    Text(
                        text = view.title,
                        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = primaryText,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = view.subtitle,
                        style = MiuixTheme.textStyles.footnote2,
                        color = secondaryText,
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    // ── 「当前：…」（Dart `:584-590`）──
                    Text(
                        text = view.currentLine,
                        style = MiuixTheme.textStyles.footnote2,
                        color = secondaryText,
                    )
                    if (view.currentLocationLine != null) {
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = view.currentLocationLine,
                            style = MiuixTheme.textStyles.footnote2,
                            color = secondaryText,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))

                    // ── 目标周：− 选择器 +（Dart `:601-631`）──
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        FollowupStepButton(
                            icon = MiuixIcons.Remove,
                            contentDescription = CourseFollowupStrings.reschedulePreviousWeekAction.text,
                            enabled = view.canDecrementWeek,
                            onClick = { draft = draft.previousWeek(weekCount) },
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        FollowupFieldCard(
                            field = view.weekField,
                            modifier = Modifier.weight(1f),
                            onClick = { picking = FollowupPickerKind.WEEK },
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        FollowupStepButton(
                            icon = MiuixIcons.Add,
                            contentDescription = CourseFollowupStrings.rescheduleNextWeekAction.text,
                            enabled = view.canIncrementWeek,
                            onClick = { draft = draft.nextWeek(weekCount) },
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))

                    // ── 星期胶囊（Dart `:633-648`）──
                    Row(modifier = Modifier.fillMaxWidth()) {
                        view.weekdayLabels.forEachIndexed { index, label ->
                            val dayOfWeek = index + 1
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .padding(horizontal = 2.dp),
                            ) {
                                FollowupWeekdayChip(
                                    label = label,
                                    selected = view.selectedDayOfWeek == dayOfWeek,
                                    onClick = { draft = draft.withDayOfWeek(dayOfWeek) },
                                )
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))

                    // ── 起止节次（Dart `:650-702`）──
                    Row(modifier = Modifier.fillMaxWidth()) {
                        FollowupFieldCard(
                            field = view.startSectionField,
                            modifier = Modifier.weight(1f),
                            onClick = { picking = FollowupPickerKind.START_SECTION },
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        FollowupFieldCard(
                            field = view.endSectionField,
                            modifier = Modifier.weight(1f),
                            onClick = { picking = FollowupPickerKind.END_SECTION },
                        )
                    }
                    if (view.targetTimeRange != null) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = view.targetTimeRange,
                            style = MiuixTheme.textStyles.footnote2,
                            color = secondaryText,
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))

                    // ── 地点（Dart `:704-710`：CourseFieldPickerTile）──
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        cornerRadius = 10.dp,
                        insideMargin = PaddingValues(horizontal = 10.dp, vertical = 8.dp),
                        onClick = { editingLocation = true },
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Location,
                                contentDescription = null,
                                tint = secondaryText,
                                modifier = Modifier.size(16.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = view.locationField.value,
                                style = MiuixTheme.textStyles.body2,
                                color = if (view.locationIsPlaceholder) secondaryText else primaryText,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f),
                            )
                            Icon(
                                imageVector = MiuixIcons.ChevronForward,
                                contentDescription = null,
                                tint = secondaryText,
                                modifier = Modifier.size(16.dp),
                            )
                        }
                    }

                    // ── 「→ …」目标预览（Dart `:711-730`）──
                    if (view.showTargetPreview) {
                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = view.targetLine,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = accent,
                        )
                        if (view.targetLocationLine != null) {
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = view.targetLocationLine,
                                style = MiuixTheme.textStyles.footnote2,
                                color = accent,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
            // ── 底部动作（Dart `:536-566`：取消 + 确认，确认无变化时置灰）──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    text = CourseFollowupStrings.cancelAction.text,
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = { onConfirm(draft.toTarget()) },
                    enabled = view.canConfirm,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = CourseFollowupStrings.confirmRescheduleAction.text)
                }
            }
        }
    }

    // ── 子弹层：周 / 开始节次 / 结束节次 / 地点 ──
    // 每个子弹层只关自己，不冒泡关掉调课弹层（Dart 里是各自 pop 自己的 sheet）。
    FollowupPickerSheet(
        show = picking == FollowupPickerKind.WEEK,
        title = view.weekField.pickerTitle,
        options = view.weekField.options,
        onDismiss = { picking = null },
        onPick = { week ->
            draft = draft.withWeek(week)
            picking = null
        },
    )
    FollowupPickerSheet(
        show = picking == FollowupPickerKind.START_SECTION,
        title = view.startSectionField.pickerTitle,
        options = view.startSectionField.options,
        onDismiss = { picking = null },
        onPick = { section ->
            draft = draft.withStartSection(section)
            picking = null
        },
    )
    FollowupPickerSheet(
        show = picking == FollowupPickerKind.END_SECTION,
        title = view.endSectionField.pickerTitle,
        options = view.endSectionField.options,
        onDismiss = { picking = null },
        onPick = { section ->
            draft = draft.withEndSection(section)
            picking = null
        },
    )
    FollowupLocationSheet(
        show = editingLocation,
        initial = draft.targetLocation,
        title = view.locationField.pickerTitle,
        suggestions = locationSuggestions,
        onDismiss = { editingLocation = false },
        onConfirm = { location ->
            draft = draft.withLocation(location)
            editingLocation = false
        },
    )
}

/**
 * 调课弹层正文列表的最大高度占屏高比例。
 *
 * Dart 整弹层限 `屏高 × 0.88`（`course_followup_sheets.dart` 容器）；本层的列表只占
 * 弹层的一部分 —— 扣掉 miuix 顶部把手/空标题（42dp）、底部固定按钮行、12dp 间距与
 * 手势区让位后约为 0.72，与同域 `AddCoursePage.kt` 的正文限高比例同源。按比例而不是
 * 写死 dp，矮屏（分屏 / 小屏设备）时列表自己缩，底部按钮始终留在屏内。
 */
private const val RESCHEDULE_LIST_HEIGHT_FRACTION = 0.72f
