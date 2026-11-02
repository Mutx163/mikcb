package com.mutx163.qingyu.pages.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.task.TaskStrings
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.theme.MiuixTheme
import androidx.compose.foundation.layout.imePadding
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import java.time.LocalDate
import java.time.YearMonth

private val kColorPalette = listOf(
    "#6366F1", "#0EA5E9", "#2196F3", "#8B5CF6", "#D946EF",
    "#F97316", "#22C55E", "#14B8A6", "#EF4444", "#F59E0B",
)

/**
 * 新增/编辑日程页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/add_schedule_item_screen.dart`：
 * 快捷模板横条 + 启用开关 + 标题/地点/备注 + 起止日期时间 + 颜色选择 + 重复频率 + 提醒设置。
 */
@Composable
fun AddScheduleItemPage(
    scheduleItem: ScheduleItemData? = null,
    initialDate: String = "2026-10-27",
    occurrenceDate: String? = null,
    onBack: () -> Unit,
    onSave: (ScheduleItemData, applyToAll: Boolean?) -> Unit,
    onDelete: (ScheduleItemData, applyToAll: Boolean?) -> Unit = { _, _ -> },
) {
    val dark = isSystemInDarkTheme()
    val isEditing = scheduleItem != null
    val isOccurrenceEditing = occurrenceDate != null && (scheduleItem?.isRecurring == true || scheduleItem?.seriesId != null)

    var title by remember { mutableStateOf(scheduleItem?.title ?: "") }
    var location by remember { mutableStateOf(scheduleItem?.location ?: "") }
    var note by remember { mutableStateOf(scheduleItem?.note ?: "") }
    var startDate by remember { mutableStateOf(scheduleItem?.startDate ?: initialDate) }
    var endDate by remember { mutableStateOf(scheduleItem?.endDate ?: initialDate) }
    var startTime by remember { mutableStateOf(scheduleItem?.startTime ?: "09:00") }
    var endTime by remember { mutableStateOf(scheduleItem?.endTime ?: "10:00") }
    var selectedColor by remember { mutableStateOf(scheduleItem?.color ?: kColorPalette.first()) }
    var recurrence by remember { mutableStateOf(scheduleItem?.recurrence ?: ScheduleRecurrence.NONE) }
    var reminderMinutes by remember { mutableStateOf(scheduleItem?.reminderMinutesBefore) }
    var enabled by remember { mutableStateOf(scheduleItem?.enabled ?: true) }
    var appliedPresetId by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var showOccurrenceScopeDialog by remember { mutableStateOf(false) }
    var pendingActionIsDelete by remember { mutableStateOf(false) }

    // 日期/时间滚轮弹层：正在选「哪一端」（对应 Dart `_pickDate` / `_pickTime` 的 isStart）。
    var pickingDate by remember { mutableStateOf<ScheduleEndpoint?>(null) }
    var pickingTime by remember { mutableStateOf<ScheduleEndpoint?>(null) }
    // Dart 打开滚轮前先收键盘（add_schedule_item_screen.dart:749-751）：
    // 弹层里没有文本框，不收的话键盘会顶在弹层底下。
    val focusManager = LocalFocusManager.current

    fun validateAndProceed(isDeleting: Boolean) {
        if (isDeleting) {
            if (isOccurrenceEditing) {
                pendingActionIsDelete = true
                showOccurrenceScopeDialog = true
            } else {
                scheduleItem?.let { onDelete(it, null) }
            }
            return
        }

        val trimmedTitle = title.trim()
        if (trimmedTitle.isEmpty()) {
            errorMessage = ScheduleStrings.scheduleTitleRequired.zh
            return
        }
        if (startDate == endDate) {
            val startMin = ScheduleDateUtils.parseMinutes(startTime)
            val endMin = ScheduleDateUtils.parseMinutes(endTime)
            if (endMin <= startMin) {
                errorMessage = ScheduleStrings.scheduleTimeRangeInvalid.zh
                return
            }
        }
        if (endDate < startDate) {
            errorMessage = ScheduleStrings.scheduleDateRangeInvalid.zh
            return
        }

        errorMessage = null

        val draft = ScheduleItemData(
            id = scheduleItem?.id ?: "draft_${System.currentTimeMillis()}",
            title = trimmedTitle,
            location = location.trim().ifEmpty { null },
            note = note.trim().ifEmpty { null },
            startDate = startDate,
            endDate = endDate,
            startTime = startTime,
            endTime = endTime,
            color = selectedColor,
            recurrence = recurrence,
            reminderMinutesBefore = reminderMinutes,
            enabled = enabled,
            seriesId = scheduleItem?.seriesId,
            occurrenceDate = occurrenceDate,
        )

        if (isOccurrenceEditing) {
            pendingActionIsDelete = false
            showOccurrenceScopeDialog = true
        } else {
            onSave(draft, null)
        }
    }

    // 顶栏折叠行为：Dart 侧 add_schedule_item_screen.dart:167 走 HyperosSubpage 默认参数
    //（overlayHeader / collapsibleLargeTitle 均 true）。
    val scrollBehavior = MiuixScrollBehavior()
    val pageTitle = if (isEditing) {
        ScheduleStrings.editScheduleTitle.zh
    } else {
        ScheduleStrings.addScheduleTitle.zh
    }

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，
            // 放进槽位后 Scaffold 不再重复给一份（第一版手搓 Row 时算了两遍）。
            topBar = {
                TopAppBar(
                    title = pageTitle,
                    largeTitle = pageTitle,
                    scrollBehavior = scrollBehavior,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = ScheduleStrings.cancelAction.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    // Dart 侧右侧是图标：编辑态 delete_outline_rounded + check_rounded。
                    actions = {
                        if (isEditing) {
                            IconButton(onClick = { validateAndProceed(isDeleting = true) }) {
                                Icon(
                                    imageVector = MiuixIcons.Delete,
                                    contentDescription = ScheduleStrings.deleteAction.zh,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                        }
                        IconButton(onClick = { validateAndProceed(isDeleting = false) }) {
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = ScheduleStrings.saveAction.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    // 表单页必须避让键盘，否则底部输入框被 IME 盖住。
                    .imePadding()
                    // 只吃顶部：底部手势条交给列表的 contentPadding 显式算一次
                    //（QingyuPageList 内部还会再加一次 innerPadding 的 bottom，
                    // 两份都给就会把小白条算两遍）。
                    .padding(top = innerPadding.calculateTopPadding()),
            ) {
            // 2026-10-28：这里原来还留着一版「手搓顶栏」Row（返回图标 + 标题 + 删除/保存按钮），
            // 是顶栏挪进 Scaffold 槽位之前的旧代码——结果标题和按钮在屏幕上出现两遍。
            // 顶栏现在只有 Scaffold 的 topBar 槽那一处。

            // ── 滚动表单 ──
            // 主滚动统一走共享套件（R2）：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
            // 与右侧滚动条；卡片间距由列表的 verticalArrangement 承担。
            // 横向留白按配方由每张卡自己带 QingyuPageCardMargin(12dp)，不放进 contentPadding。
            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                scrollBehavior = scrollBehavior,
                contentPadding = PaddingValues(
                    top = 8.dp,
                    // 底部把系统手势条那段算进去，否则最后一项钻到小白条底下。
                    bottom = innerPadding.calculateBottomPadding() + 8.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // 校验错误横幅
                errorMessage?.let { error ->
                    item(key = "error") {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                            insideMargin = PaddingValues(12.dp),
                        ) {
                            Text(
                                text = error,
                                color = Color(QingyuTheme.error(dark)),
                                style = MiuixTheme.textStyles.body2,
                            )
                        }
                    }
                }

                // 快捷模板选择区（新建时展示）
                if (!isEditing) {
                    item(key = "presets") {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                            insideMargin = PaddingValues(12.dp),
                        ) {
                            Column {
                                Text(
                                    text = ScheduleStrings.scheduleQuickPresetSectionTitle.zh,
                                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                    // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                    modifier = Modifier.padding(bottom = 8.dp),
                                )
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    val activePreset = scheduleQuickPresetActiveId(appliedPresetId, title)
                                    for (preset in kScheduleQuickPresets) {
                                        val isSelected = activePreset == preset.id
                                        val presetTitle = scheduleQuickPresetTitle(preset.id)
                                        val chipBg = if (isSelected) {
                                            Color(QingyuTheme.primary(dark = dark))
                                        } else {
                                            Color(QingyuTheme.card(dark))
                                        }
                                        val chipText = if (isSelected) {
                                            Color.White
                                        } else {
                                            Color(QingyuTheme.primaryText(dark))
                                        }

                                        Box(
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(chipBg)
                                                .border(
                                                    1.dp,
                                                    if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                                                    RoundedCornerShape(8.dp),
                                                )
                                                .clickable {
                                                    if (isSelected) {
                                                        appliedPresetId = null
                                                        title = ""
                                                    } else {
                                                        appliedPresetId = preset.id
                                                        title = presetTitle
                                                        selectedColor = preset.colorHex
                                                        val win = resolveSchedulePresetWindow(
                                                            ScheduleDateUtils.parseMinutes(startTime),
                                                            preset.durationMinutes,
                                                        )
                                                        startTime = ScheduleDateUtils.formatMinutes(win.startMinutes)
                                                        endTime = ScheduleDateUtils.formatMinutes(win.endMinutes)
                                                    }
                                                }
                                                .padding(horizontal = 12.dp, vertical = 8.dp),
                                        ) {
                                            Text(text = presetTitle, style = MiuixTheme.textStyles.footnote1, color = chipText)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 启用开关卡片
                item(key = "enabled") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(0.dp),
                    ) {
                        // 对齐 Dart `add_schedule_item_screen.dart:468-478` 的 `HyperosSwitchTile`：
                        // 标题 +（关时）副标题 + 右侧开关，整行可点。
                        //
                        // 2026-10-29 修（审核 misc-wiring P1-6）：这里原来是「文字 + 一颗会变字的按钮」，
                        // 按钮文案 `已启用` / `已暂停` 是**渲染层写死的中文**，ARB 里根本没有这两个词；
                        // 且 Dart 是开关、Compose 是按钮 ⇒ 同一功能两岸长得不一样。
                        // 现改回官方 `SwitchPreference`，文案全部来自
                        // `ScheduleStrings.scheduleEnabledTitle` / `scheduleDisabledSubtitle`。
                        SwitchPreference(
                            title = ScheduleStrings.scheduleEnabledTitle.zh,
                            summary = if (enabled) null else ScheduleStrings.scheduleDisabledSubtitle.zh,
                            checked = enabled,
                            onCheckedChange = { enabled = it },
                        )
                    }
                }

                // 日程信息卡片
                item(key = "info") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleInfoSectionTitle.zh,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            TextField(
                                value = title,
                                onValueChange = { title = it },
                                label = ScheduleStrings.scheduleTitleLabel.zh,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            TextField(
                                value = location,
                                onValueChange = { location = it },
                                label = ScheduleStrings.scheduleLocationLabel.zh,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            TextField(
                                value = note,
                                onValueChange = { note = it },
                                label = ScheduleStrings.scheduleNoteLabel.zh,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }

                // 时间安排与起止设置
                item(key = "time") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleTimeSectionTitle.zh,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )

                            // 起止日期/时间：四行「标签 → 取值」选值行，点行弹滚轮
                            //（Dart `add_schedule_item_screen.dart:331/338` 的 `HyperosPickerField`
                            // + `showMiuixDatePickerSheet` / `showMiuixTimePickerSheet`）。
                            // 原来是四个自由文本框：用户得手输 `2026-10-01` 这种格式，
                            // 还可能输进解析不出来的值。滚轮弹层见本文件底部。
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleStartDateLabel.zh,
                                value = formatScheduleDateDisplay(startDate),
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingDate = ScheduleEndpoint.Start
                                },
                            )
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleStartTimeLabel.zh,
                                value = startTime,
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingTime = ScheduleEndpoint.Start
                                },
                            )
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleEndDateLabel.zh,
                                value = formatScheduleDateDisplay(endDate),
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingDate = ScheduleEndpoint.End
                                },
                            )
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleEndTimeLabel.zh,
                                value = endTime,
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingTime = ScheduleEndpoint.End
                                },
                            )

                            // 跨天或重复提示
                            if (recurrence == ScheduleRecurrence.WEEKLY) {
                                Text(
                                    text = ScheduleStrings.scheduleRepeatWeeklyHint.zh,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            } else if (recurrence == ScheduleRecurrence.DAILY) {
                                Text(
                                    text = ScheduleStrings.scheduleRepeatEndDateHint.zh,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            } else if (endDate > startDate) {
                                Text(
                                    text = ScheduleStrings.scheduleCrossDaySpanHint
                                        .filled("start" to "$startDate $startTime", "end" to "$endDate $endTime"),
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }

                            HorizontalDivider(modifier = Modifier.fillMaxWidth())

                            // 颜色挑选横条
                            Text(
                                text = ScheduleStrings.scheduleAppearanceSectionTitle.zh,
                                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                for (hex in kColorPalette) {
                                    val isChosen = selectedColor.equals(hex, ignoreCase = true)
                                    Box(
                                        modifier = Modifier
                                            .size(34.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(Color(android.graphics.Color.parseColor(hex)))
                                            .border(
                                                width = if (isChosen) 3.dp else 1.dp,
                                                color = if (isChosen) Color.White else Color.Transparent,
                                                shape = RoundedCornerShape(8.dp),
                                            )
                                            .clickable { selectedColor = hex },
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        if (isChosen) {
                                            Box(
                                                modifier = Modifier
                                                    .size(10.dp)
                                                    .clip(CircleShape)
                                                    .background(Color.White),
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 重复规则设置卡片
                item(key = "recurrence") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleRepeatSectionTitle.zh,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                val options = listOf(
                                    ScheduleRecurrence.NONE to ScheduleStrings.scheduleRepeatNone.zh,
                                    ScheduleRecurrence.DAILY to ScheduleStrings.scheduleRepeatDaily.zh,
                                    ScheduleRecurrence.WEEKLY to ScheduleStrings.scheduleRepeatWeekly.zh,
                                )
                                for ((rec, label) in options) {
                                    val isSelected = recurrence == rec
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) {
                                                    Color(QingyuTheme.primary(dark = dark))
                                                } else {
                                                    Color(QingyuTheme.card(dark))
                                                },
                                            )
                                            .border(
                                                1.dp,
                                                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                                                RoundedCornerShape(8.dp),
                                            )
                                            .clickable {
                                                recurrence = rec
                                                if (recurrence != ScheduleRecurrence.NONE && endDate < startDate) {
                                                    endDate = startDate
                                                }
                                            }
                                            .padding(vertical = 10.dp),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text(
                                            text = label,
                                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                            color = if (isSelected) Color.White else Color(QingyuTheme.primaryText(dark)),
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // 提醒时间设置卡片
                item(key = "reminder") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleReminderSectionTitle.zh,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            val reminderChoices = listOf(
                                null to ScheduleStrings.scheduleReminderOff.zh,
                                5 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "5"),
                                10 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "10"),
                                15 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "15"),
                                30 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "30"),
                                60 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "60"),
                            )
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                for ((mins, label) in reminderChoices) {
                                    val isSelected = reminderMinutes == mins
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) {
                                                    Color(QingyuTheme.primary(dark = dark))
                                                } else {
                                                    Color(QingyuTheme.card(dark))
                                                },
                                            )
                                            .border(
                                                1.dp,
                                                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                                                RoundedCornerShape(8.dp),
                                            )
                                            .clickable { reminderMinutes = mins }
                                            .padding(horizontal = 12.dp, vertical = 8.dp),
                                    ) {
                                        Text(
                                            text = label,
                                            style = MiuixTheme.textStyles.footnote1,
                                            color = if (isSelected) Color.White else Color(QingyuTheme.primaryText(dark)),
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

    // 重复日程修改/删除范围确认弹框。
    //
    // 原来是一张裸 QingyuCard：没有遮罩、点外部不关、返回键会把整个编辑页退掉
    //（未保存内容一起丢）。现改官方 OverlayDialog 并交给 `show` 驱动：
    // 返回键 / 点外部只关弹窗，不再退页。
    val scopeTitleText = if (pendingActionIsDelete) {
        ScheduleStrings.scheduleDeleteScopeTitle.zh
    } else {
        ScheduleStrings.scheduleEditScopeTitle.zh
    }
    val thisActionText = if (pendingActionIsDelete) {
        ScheduleStrings.scheduleDeleteScopeThis.zh
    } else {
        ScheduleStrings.scheduleEditScopeThis.zh
    }
    val allActionText = if (pendingActionIsDelete) {
        ScheduleStrings.scheduleDeleteScopeAll.zh
    } else {
        ScheduleStrings.scheduleEditScopeAll.zh
    }

    OverlayDialog(
        show = showOccurrenceScopeDialog,
        title = scopeTitleText,
        onDismissRequest = { showOccurrenceScopeDialog = false },
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = ScheduleStrings.scheduleOccurrenceEditHint.zh,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            // 「本次 / 全部」都是出口，没有第三颗取消；两个都用主色实心。
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ScheduleActionButton(
                    text = thisActionText,
                    onClick = {
                        showOccurrenceScopeDialog = false
                        val draft = ScheduleItemData(
                            id = scheduleItem?.id ?: "",
                            title = title.trim(),
                            location = location.trim().ifEmpty { null },
                            note = note.trim().ifEmpty { null },
                            startDate = startDate,
                            endDate = endDate,
                            startTime = startTime,
                            endTime = endTime,
                            color = selectedColor,
                            recurrence = recurrence,
                            reminderMinutesBefore = reminderMinutes,
                            enabled = enabled,
                            seriesId = scheduleItem?.seriesId,
                            occurrenceDate = occurrenceDate,
                        )
                        if (pendingActionIsDelete) {
                            onDelete(draft, false)
                        } else {
                            onSave(draft, false)
                        }
                    },
                    modifier = Modifier.weight(1f),
                    primary = true,
                )
                ScheduleActionButton(
                    text = allActionText,
                    onClick = {
                        showOccurrenceScopeDialog = false
                        val draft = ScheduleItemData(
                            id = scheduleItem?.id ?: "",
                            title = title.trim(),
                            location = location.trim().ifEmpty { null },
                            note = note.trim().ifEmpty { null },
                            startDate = startDate,
                            endDate = endDate,
                            startTime = startTime,
                            endTime = endTime,
                            color = selectedColor,
                            recurrence = recurrence,
                            reminderMinutesBefore = reminderMinutes,
                            enabled = enabled,
                            seriesId = scheduleItem?.seriesId,
                            occurrenceDate = occurrenceDate,
                        )
                        if (pendingActionIsDelete) {
                            onDelete(draft, true)
                        } else {
                            onSave(draft, true)
                        }
                    },
                    modifier = Modifier.weight(1f),
                    primary = true,
                )
            }
        }
    }

    // 起止日期滚轮（年/月/日三列官方 NumberPicker）。选完按 Dart `_pickDate` 归一：
    // 开始 > 结束时把另一端收拢，保证「结束不早于开始」。
    ScheduleDatePickerSheet(
        show = pickingDate != null,
        title = if (pickingDate == ScheduleEndpoint.End) {
            ScheduleStrings.scheduleEndDateLabel.zh
        } else {
            ScheduleStrings.scheduleStartDateLabel.zh
        },
        initialIso = if (pickingDate == ScheduleEndpoint.End) endDate else startDate,
        onConfirm = { iso ->
            when (pickingDate) {
                ScheduleEndpoint.Start -> {
                    startDate = iso
                    if (endDate < startDate) endDate = startDate
                }
                ScheduleEndpoint.End -> {
                    endDate = iso
                    if (endDate < startDate) startDate = endDate
                }
                null -> {}
            }
            pickingDate = null
        },
        onDismiss = { pickingDate = null },
    )

    // 起止时间滚轮（时/分两列官方 NumberPicker），标题与 Dart `_pickTime` 传的同键。
    ScheduleTimePickerSheet(
        show = pickingTime != null,
        title = if (pickingTime == ScheduleEndpoint.End) {
            ScheduleStrings.selectEndTimeTitle.zh
        } else {
            ScheduleStrings.selectStartTimeTitle.zh
        },
        initial = if (pickingTime == ScheduleEndpoint.End) endTime else startTime,
        onConfirm = { clock ->
            when (pickingTime) {
                ScheduleEndpoint.Start -> startTime = clock
                ScheduleEndpoint.End -> endTime = clock
                null -> {}
            }
            pickingTime = null
        },
        onDismiss = { pickingTime = null },
    )
    }
}

/** 滚轮正在选起止的哪一端（对应 Dart `_pickDate` / `_pickTime` 的 `isStart` 参数）。 */
private enum class ScheduleEndpoint { Start, End }

/** 日期滚轮可选范围：与 Dart `add_schedule_item_screen.dart:755-756` 的 firstDate/lastDate 同口径。 */
private const val SCHEDULE_DATE_FIRST_YEAR = 2020
private const val SCHEDULE_DATE_LAST_YEAR = 2100

/**
 * 日期/时间选值行：Dart `HyperosPickerField` 的等价物。
 *
 * 用官方 `BasicComponent`（标题 + 行尾取值 + 整行可点 + 官方按压反馈）承载，
 * 与 `SettingsHolidayHost.DatePickerField` / `TimeSchemeQuickGenerateSheet.TimeField` 同一先例。
 * 与 Dart 的差异只有外观：Dart 是一个「像输入框」的选值框（带图标），
 * 这里是一行「标签 → 取值」——点哪儿、点了会弹什么，两者一致。
 */
@Composable
private fun SchedulePickerField(label: String, value: String, onClick: () -> Unit) {
    BasicComponent(
        title = label,
        endActions = {
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        onClick = onClick,
    )
}

/**
 * 起止日期滚轮弹层：年 / 月 / 日三列官方 `NumberPicker` + 取消 / 确认。
 *
 * Dart 侧是月历弹层（`showMiuixDatePickerSheet`），Kotlin 侧 miuix 0.9.4 没有
 * DatePicker，只有 `NumberPicker`——沿用 `SettingsSemesterHost` 的既定等价做法
 * （三列滚轮，交互结果一致）。年不循环、月/日循环；年/月改动后「日」的上界跟着
 * 变并就地收拢，避免确认写进一个不存在的日期（Dart `_YearMonthWheelDialog` 同口径）。
 */
@Composable
private fun ScheduleDatePickerSheet(
    show: Boolean,
    title: String,
    initialIso: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val initial = remember(initialIso) {
        ScheduleDateUtils.parseDate(initialIso) ?: LocalDate.now()
    }
    var year by remember(show, initialIso) { mutableIntStateOf(initial.year) }
    var month by remember(show, initialIso) { mutableIntStateOf(initial.monthValue) }
    var day by remember(show, initialIso) { mutableIntStateOf(initial.dayOfMonth) }

    val maxDay = YearMonth.of(year, month).lengthOfMonth()
    val safeDay = day.coerceAtMost(maxDay)

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 内容根 Column 自己给了左右 16（三列滚轮 + 按钮行都不通栏）⇒ 框架侧横向归零，
        // 单边就是 16，不再叠成 32（与 SettingsSemesterHost 的日期滚轮同口径）。
        contentPadsHorizontally = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = year,
                    onValueChange = {
                        year = it
                        day = day.coerceAtMost(YearMonth.of(it, month).lengthOfMonth())
                    },
                    range = SCHEDULE_DATE_FIRST_YEAR..SCHEDULE_DATE_LAST_YEAR,
                    label = { "$it${TaskStrings.datePickerYear}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = month,
                    onValueChange = {
                        month = it
                        day = day.coerceAtMost(YearMonth.of(year, it).lengthOfMonth())
                    },
                    range = 1..12,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerMonth}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = safeDay,
                    onValueChange = { day = it },
                    range = 1..maxDay,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerDay}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        onConfirm(ScheduleDateUtils.formatDate(LocalDate.of(year, month, safeDay)))
                    },
                    // 弹层的主出口（不是取消）⇒ 强调色；默认 `buttonColors()` 是灰底，
                    // 读起来像禁用（审核 P1/S1 的同一条口径）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = TaskStrings.confirmAction)
                }
            }
        }
    }
}

/**
 * 起止时间滚轮弹层：时 0-23 / 分 0-59（步长 1），官方 `NumberPicker` 两列。
 *
 * 与 Dart `showMiuixTimePickerSheet`（`miuix_time_picker_sheet.dart`）同口径：
 * 分钟不分档（这个页面 Dart 就是一分钟一档，区别于作息页的 5 分钟一档）、
 * `_twoDigits` 两位数字标签、滚轮高 220dp、title3 + w600。
 */
@Composable
private fun ScheduleTimePickerSheet(
    show: Boolean,
    title: String,
    initial: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val parsedMinutes = remember(initial) { ScheduleDateUtils.parseMinutes(initial) }
    var hour by remember(show, initial) { mutableIntStateOf(parsedMinutes / 60) }
    var minute by remember(show, initial) { mutableIntStateOf(parsedMinutes % 60) }

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 与日期滚轮同一个口径（见上）。
        contentPadsHorizontally = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = hour,
                    onValueChange = { hour = it },
                    range = 0..23,
                    wrapAround = true,
                    label = { it.toString().padStart(2, '0') },
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = minute,
                    onValueChange = { minute = it },
                    range = 0..59,
                    wrapAround = true,
                    label = { it.toString().padStart(2, '0') },
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(ScheduleDateUtils.formatMinutes(hour * 60 + minute)) },
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = TaskStrings.confirmAction)
                }
            }
        }
    }
}

/**
 * 选值行里的日期显示：与 Dart `_formatCompactDateLabel`（`add_schedule_item_screen.dart:735-741`）
 * 同口径——今年内只显示「M月d日」，跨年才带年份。单位词复用 ARB 既有键
 * （`datePickerYear/Month/Day`），不新增写死文案。
 */
private fun formatScheduleDateDisplay(iso: String): String {
    val date = ScheduleDateUtils.parseDate(iso) ?: return iso
    return if (date.year == LocalDate.now().year) {
        "${date.monthValue}${TaskStrings.datePickerMonth}${date.dayOfMonth}${TaskStrings.datePickerDay}"
    } else {
        "${date.year}${TaskStrings.datePickerYear}" +
            "${date.monthValue}${TaskStrings.datePickerMonth}${date.dayOfMonth}${TaskStrings.datePickerDay}"
    }
}
