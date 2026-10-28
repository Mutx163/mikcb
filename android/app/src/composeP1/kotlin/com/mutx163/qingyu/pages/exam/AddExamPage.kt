package com.mutx163.qingyu.pages.exam

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.ExamReminderPreset
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Link
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.WindowDropdownPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 添加 / 编辑考试页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/add_exam_screen.dart`（1290 行）：
 * - 顶栏：返回 + 「添加考试 / 编辑考试」+（编辑时）删除 + 保存
 * - 关联课程行（未选课程时下方给出「请选择关联课程」）
 * - 名称 / 日期 / 开始时间 / 结束时间
 * - 考场（提示优先显示上课教室）/ 座位号
 * - 提醒设置下拉 + 自定义提醒列表（可改可删）+ 添加提醒
 * - 备注
 *
 * **不做业务计算**：默认值、校验、日期串、提醒换算法全部来自 [AddExamLogic]，
 * 本文件只把 [AddExamViewState] 摊到屏上并回调出去。
 *
 * 与 Dart 的差异：
 * - 日期 / 时间 / 关联课程三个选择器在 Dart 走 `miuix_date_picker_sheet`、
 *   `miuix_time_picker_sheet`、`course_template_picker_sheet`（台账 §6 的共享件，
 *   尚未迁到 Kotlin）。这里只暴露回调（`onPickDate` / `onPickStartTime` /
 *   `onPickEndTime` / `onPickCourse`），由壳层接线，页面不假装自己有选择器。
 * - 校验失败在 Dart 是 toast；这里用页内错误条（同一个 `toastMessage` 文案）。
 */
@Composable
fun AddExamPage(
    viewState: AddExamViewState,
    selectedCourse: Course?,
    courseGroupsEmpty: Boolean,
    dateDisplayText: String,
    locationHintText: String,
    onBack: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
    onNameChange: (String) -> Unit,
    onPickCourse: () -> Unit,
    onPickDate: () -> Unit,
    onPickStartTime: () -> Unit,
    onPickEndTime: () -> Unit,
    onLocationChange: (String) -> Unit,
    onSeatChange: (String) -> Unit,
    onNoteChange: (String) -> Unit,
    onReminderPresetChange: (ExamReminderPreset) -> Unit,
    onAddCustomReminder: () -> Unit,
    onEditCustomReminder: (Int) -> Unit,
    onRemoveCustomReminder: (Int) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var confirmDelete by remember { mutableStateOf(false) }
    val pageTitle = if (viewState.isEditing) ExamStrings.editExam.zh else ExamStrings.addExam.zh
    // 顶栏折叠行为：Dart `add_exam_screen.dart:83-86` 走 HyperosSubpage 默认参数
    // （`collapsibleLargeTitle` 默认 true，见 `hyperos_page.dart:170`），标题是纯 Text ⇒ 有大标题。
    // 一个页面实例一个：返回重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，放进槽位后 Scaffold 不再重复给一份。
        topBar = {
            TopAppBar(
                title = pageTitle,
                largeTitle = pageTitle,
                scrollBehavior = scrollBehavior,
                color = Color(QingyuTheme.scaffoldBackground(dark)),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = ExamStrings.cancelAction.zh,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
                actions = {
                    if (viewState.isEditing) {
                        IconButton(onClick = { confirmDelete = true }) {
                            Icon(
                                imageVector = MiuixIcons.Delete,
                                contentDescription = ExamStrings.deleteExam.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    }
                    IconButton(onClick = onSave) {
                        Icon(
                            imageVector = MiuixIcons.Ok,
                            contentDescription = ExamStrings.saveExam.zh,
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
                .padding(innerPadding),
        ) {
            // nestedScroll 必须挂在滚动容器外层：顺序反了滚动手势不会上抛，大标题永不折叠。
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .nestedScroll(scrollBehavior.nestedScrollConnection)
                    .verticalScroll(rememberScrollState())
                    .padding(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        // 底部把系统手势条那段算进去，否则最后一项钻到小白条底下。
                        bottom = innerPadding.calculateBottomPadding() + 8.dp,
                    ),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                val toast = viewState.toastMessage
                if (!toast.isNullOrEmpty()) {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                    ) {
                        Text(
                            text = toast,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.error(dark)),
                        )
                    }
                }

                // ── 关联课程 ──
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(0.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(enabled = !courseGroupsEmpty, onClick = onPickCourse)
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(Color(QingyuTheme.surfaceContainerHighest(dark))),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.Link,
                                    contentDescription = null,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = ExamStrings.linkCourse.zh,
                                    style = MiuixTheme.textStyles.body1,
                                    fontWeight = FontWeight.Medium,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                )
                                Text(
                                    text = AddExamLogic.courseDetailsText(selectedCourse, courseGroupsEmpty),
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(top = 2.dp),
                                )
                            }
                            if (!courseGroupsEmpty) {
                                Icon(
                                    imageVector = MiuixIcons.ChevronForward,
                                    contentDescription = null,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                    modifier = Modifier.size(16.dp),
                                )
                            }
                        }
                        if (viewState.selectedCourseId.isNullOrBlank()) {
                            Text(
                                text = ExamStrings.linkCourseRequired.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.error(dark)),
                                modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 12.dp),
                            )
                        }
                    }
                }

                // ── 名称 / 日期 / 时间 ──
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        TextField(
                            value = viewState.name,
                            onValueChange = onNameChange,
                            label = ExamStrings.examNameLabel.zh,
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                        val nameError = viewState.nameError
                        if (!nameError.isNullOrEmpty()) {
                            Text(
                                text = nameError,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.error(dark)),
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }

                        Spacer(modifier = Modifier.height(4.dp))
                        ExamCardDivider(dark)
                        ExamSettingRow(
                            icon = MiuixIcons.Months,
                            title = ExamStrings.examDateLabel.zh,
                            value = dateDisplayText,
                            dark = dark,
                            onClick = onPickDate,
                        )
                        ExamSettingRow(
                            icon = MiuixIcons.Timer,
                            title = ExamStrings.examStartTimeLabel.zh,
                            value = viewState.startTime,
                            dark = dark,
                            onClick = onPickStartTime,
                        )
                        ExamSettingRow(
                            icon = MiuixIcons.Timer,
                            title = ExamStrings.examEndTimeLabel.zh,
                            value = viewState.endTime,
                            dark = dark,
                            onClick = onPickEndTime,
                        )
                    }
                }

                // ── 考场 / 座位号 ──
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextField(
                            value = viewState.location,
                            onValueChange = onLocationChange,
                            label = ExamStrings.examLocationLabel.zh,
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Text(
                            text = locationHintText,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        TextField(
                            value = viewState.seatNumber,
                            onValueChange = onSeatChange,
                            label = ExamStrings.examSeatLabel.zh,
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }

                // ── 提醒设置 ──
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(vertical = 2.dp),
                ) {
                    val presetOptions = AddExamLogic.reminderPresetOptions()
                    WindowDropdownPreference(
                        items = presetOptions.map { it.second },
                        selectedIndex = presetOptions.indexOfFirst { it.first == viewState.reminderPreset }
                            .coerceAtLeast(0),
                        title = ExamStrings.examReminderLabel.zh,
                        onSelectedIndexChange = { index ->
                            presetOptions.getOrNull(index)?.let { onReminderPresetChange(it.first) }
                        },
                    )

                    if (viewState.reminderPreset == ExamReminderPreset.CUSTOM) {
                        HorizontalDivider(
                            modifier = Modifier.padding(horizontal = 14.dp),
                            color = Color(QingyuTheme.dividerLine(dark)),
                        )
                        val offsets = AddExamLogic.sortedOffsets(viewState.customReminderMinutes)
                        if (offsets.isEmpty()) {
                            Text(
                                text = ExamStrings.examReminderCustomEmptyHint.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            )
                        }
                        offsets.forEach { minutes ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onEditCustomReminder(minutes) }
                                    .padding(start = 14.dp, end = 6.dp, top = 10.dp, bottom = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = ExamListLogic.reminderOffsetLabel(minutes),
                                    style = MiuixTheme.textStyles.body1,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                    modifier = Modifier.weight(1f),
                                )
                                IconButton(
                                    onClick = { onRemoveCustomReminder(minutes) },
                                    modifier = Modifier.size(36.dp),
                                ) {
                                    Icon(
                                        imageVector = MiuixIcons.Remove,
                                        contentDescription = ExamStrings.deleteAction.zh,
                                        tint = Color(QingyuTheme.error(dark)),
                                        modifier = Modifier.size(17.dp),
                                    )
                                }
                            }
                        }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(onClick = onAddCustomReminder)
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Add,
                                contentDescription = null,
                                tint = Color(QingyuTheme.primary(dark = dark)),
                                modifier = Modifier.size(17.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = ExamStrings.examReminderAddCustom.zh,
                                style = MiuixTheme.textStyles.body1,
                                color = Color(QingyuTheme.primary(dark = dark)),
                            )
                        }
                    }
                }

                // ── 备注 ──
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    TextField(
                        value = viewState.note,
                        onValueChange = onNoteChange,
                        label = ExamStrings.examNoteLabel.zh,
                        useLabelAsPlaceholder = true,
                        minLines = 3,
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }

    if (confirmDelete) {
        OverlayDialog(
            show = true,
            title = ExamStrings.deleteExam.zh,
            summary = ExamStrings.deleteExamConfirm.filled("name", viewState.name),
            onDismissRequest = { confirmDelete = false },
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = { confirmDelete = false },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = ExamStrings.cancelAction.zh)
                }
                top.yukonga.miuix.kmp.basic.Button(
                    onClick = {
                        confirmDelete = false
                        onDelete()
                    },
                    modifier = Modifier.weight(1f),
                    colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                ) {
                    Text(text = ExamStrings.deleteAction.zh)
                }
            }
        }
    }
}

/** 卡片内的分组细线（宽度收进卡内边距）。 */
@Composable
private fun ExamCardDivider(dark: Boolean) {
    HorizontalDivider(
        modifier = Modifier.padding(vertical = 8.dp),
        color = Color(QingyuTheme.dividerLine(dark)),
    )
}

/** 「标题 + 当前值 + 箭头」的设置行（Dart `HyperosListTile` 的等价物）。 */
@Composable
private fun ExamSettingRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    value: String,
    dark: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(17.dp),
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(modifier = Modifier.width(6.dp))
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(14.dp),
        )
    }
}
