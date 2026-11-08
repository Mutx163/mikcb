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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.ExamReminderPreset
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
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
    val pageTitle = if (viewState.isEditing) ExamStrings.editExam.text else ExamStrings.addExam.text

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃 + actions 槽；大标题可折叠
    // （Dart `add_exam_screen.dart:83-86` 走 HyperosSubpage 默认参数）。
    QingyuPageScaffold(
        title = pageTitle,
        onBack = onBack,
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影
        //（`QingyuGlassIconButton`；本页走共享骨架 ⇒ 有实时 backdrop，是真玻璃）。
        actions = {
            if (viewState.isEditing) {
                QingyuGlassIconButton(
                    onClick = { confirmDelete = true },
                    contentDescription = ExamStrings.deleteExam.text,
                    icon = MiuixIcons.Delete,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
            QingyuGlassIconButton(
                onClick = onSave,
                contentDescription = ExamStrings.saveExam.text,
                icon = MiuixIcons.Ok,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        },
    ) {
        // 页面主滚动走共享套件：末端轻震 + 过度滚动 + 顶栏联动 + 滚动条。
        // 表单页同样是一整页纵向内容，每张卡片一个 item（惰性组合），不再用非惰性的 Column。
        // 表单页：imePadding 把整页抬到键盘之上（壳是 edge-to-edge，adjustResize 不生效）。
        QingyuPageList(
            innerPadding = innerPadding,
            // QingyuPageList 的 contentPadding 只吃底部与横向，顶部 8dp 留白用 modifier 补。
            modifier = Modifier.padding(top = 8.dp).imePadding(),
            scrollBehavior = scrollBehavior,
            horizontalPadding = 16.dp,
            contentPadding = PaddingValues(bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val toast = viewState.toastMessage
            if (!toast.isNullOrEmpty()) {
                item(key = "toast") {
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
            }

            // ── 关联课程 ──
            item(key = "course") {
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
                                    text = ExamStrings.linkCourse.text,
                                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
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
                                text = ExamStrings.linkCourseRequired.text,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.error(dark)),
                                modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 12.dp),
                            )
                        }
                    }
                }
            }

            // ── 名称 / 日期 / 时间 ──
            item(key = "nameAndTime") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        TextField(
                            value = viewState.name,
                            onValueChange = onNameChange,
                            label = ExamStrings.examNameLabel.text,
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
                            title = ExamStrings.examDateLabel.text,
                            value = dateDisplayText,
                            dark = dark,
                            onClick = onPickDate,
                        )
                        ExamSettingRow(
                            icon = MiuixIcons.Timer,
                            title = ExamStrings.examStartTimeLabel.text,
                            value = viewState.startTime,
                            dark = dark,
                            onClick = onPickStartTime,
                        )
                        ExamSettingRow(
                            icon = MiuixIcons.Timer,
                            title = ExamStrings.examEndTimeLabel.text,
                            value = viewState.endTime,
                            dark = dark,
                            onClick = onPickEndTime,
                        )
                    }
                }
            }

            // ── 考场 / 座位号 ──
            item(key = "locationAndSeat") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextField(
                            value = viewState.location,
                            onValueChange = onLocationChange,
                            label = ExamStrings.examLocationLabel.text,
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
                            label = ExamStrings.examSeatLabel.text,
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }

            // ── 提醒设置 ──
            item(key = "reminders") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    // 包 `*Preference` 行时不传 insideMargin（见 QingyuCard KDoc）：原先给 2dp，
                    // 下拉偏好自带的按压指示只画在组件自身 bounds，上下各差 2dp 盖不满卡片。
                    insideMargin = PaddingValues(0.dp),
                ) {
                    val presetOptions = AddExamLogic.reminderPresetOptions()
                    WindowDropdownPreference(
                        // 偏好行的按压 ripple 是矩形；裁到与卡片一致的圆角，按压态才完整
                        // 贴合这个圆角框，不露直角/露边（miuix BasicComponent 的 clickable 在
                        // insideMargin 之外，尺寸铺满整卡，仅需按卡片圆角裁剪）。
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)),
                        items = presetOptions.map { it.second },
                        selectedIndex = presetOptions.indexOfFirst { it.first == viewState.reminderPreset }
                            .coerceAtLeast(0),
                        title = ExamStrings.examReminderLabel.text,
                        onSelectedIndexChange = { index ->
                            presetOptions.getOrNull(index)?.let { onReminderPresetChange(it.first) }
                        },
                    )

                    if (viewState.reminderPreset == ExamReminderPreset.CUSTOM) {
                        val offsets = AddExamLogic.sortedOffsets(viewState.customReminderMinutes)
                        if (offsets.isEmpty()) {
                            Text(
                                text = ExamStrings.examReminderCustomEmptyHint.text,
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
                                        contentDescription = ExamStrings.deleteAction.text,
                                        tint = Color(QingyuTheme.error(dark)),
                                        modifier = Modifier.size(17.dp),
                                    )
                                }
                            }
                        }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .sizeIn(minHeight = 48.dp)
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
                                text = ExamStrings.examReminderAddCustom.text,
                                style = MiuixTheme.textStyles.body1,
                                color = Color(QingyuTheme.primary(dark = dark)),
                            )
                        }
                    }
                }
            }

            // ── 备注 ──
            item(key = "note") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    TextField(
                        value = viewState.note,
                        onValueChange = onNoteChange,
                        label = ExamStrings.examNoteLabel.text,
                        useLabelAsPlaceholder = true,
                        minLines = 3,
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }

    // 常驻组合（2026-11-04 弹层债收口）：显隐只由 `show` 驱动，关闭不再整棵摘出组合，
    // 官方退场动画（fadeOut + scaleOut + slideOut）才能播完。正文取自 `viewState.name`，
    // 不是会被清空的瞬时状态，退场期间照常可读。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = confirmDelete,
        title = ExamStrings.deleteExam.text,
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
                Text(text = ExamStrings.cancelAction.text)
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
                Text(text = ExamStrings.deleteAction.text)
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 about/ContributorsPage.kt 样板铺）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 3 档：新建空表单 / 编辑已有考试 / 校验失败；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 暗色 —— 历史上出现过「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()）；这一档就是防它复发；
//   · 大字号 —— 「提前 1 天 + 提前 1 小时」这类提醒行与时间行最先折行；
//   · 新建 / 编辑 —— 顶栏标题与右上动作两个套（编辑多了删除），且未选课程时多一行红字；
//   · 校验失败 —— 字段错误（名称下红字）+ 页顶错误条是两条独立渲染分支。
//
// 日期一律用全限定 java.time.LocalDateTime（本文件不为预览添 import）。
// 固定写法：主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }；
// 字号用 QingyuPageTheme(textScale = …)，不用 @Preview(fontScale = …)；
// 宽度按 400dp（本仓折行实测口径），高度给一屏多。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：关联课程（页上只用到名字 / 教师 / 教室）。 */
private fun previewExamCourse(): Course = Course(
    id = "course_preview_1",
    name = "高等数学（上）",
    teacher = "王老师",
    location = "三教 204",
    dayOfWeek = 3,
    startSection = 1,
    endSection = 2,
    startTime = "08:00",
    endTime = "09:40",
    color = "#2196F3",
)

/** 新建：未选课程、名称为空，日期落在默认的「七天后」。 */
private fun previewAddExamStateCreate(): AddExamViewState = AddExamViewState(
    isEditing = false,
    selectedCourseId = null,
    name = "",
    hasSelectedDate = true,
    selectedDate = java.time.LocalDateTime.of(2026, 11, 15, 0, 0),
    startTime = "08:30",
    endTime = "10:30",
    reminderPreset = ExamReminderPreset.DAY_1_AND_HOUR_1,
)

/** 编辑：全部字段有值，提醒用自定义两档（走「提前 N 天 · 提前 N 小时」分支）。 */
private fun previewAddExamStateEditing(): AddExamViewState = AddExamViewState(
    isEditing = true,
    selectedCourseId = "course_preview_1",
    name = "高等数学（上）期末考试",
    hasSelectedDate = true,
    selectedDate = java.time.LocalDateTime.of(2026, 11, 20, 0, 0),
    startTime = "09:00",
    endTime = "11:00",
    location = "三教 204",
    seatNumber = "27",
    note = "带学生证和黑色签字笔",
    reminderPreset = ExamReminderPreset.CUSTOM,
    customReminderMinutes = listOf(1440, 60),
)

/** 校验失败：名称下红字 + 页顶错误条同时出现。 */
private fun previewAddExamStateInvalid(): AddExamViewState = previewAddExamStateCreate().copy(
    nameError = "请输入考试名称",
    toastMessage = "请先选择关联课程",
)

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewAddExamPage(
    viewState: AddExamViewState,
    selectedCourse: Course? = null,
    courseGroupsEmpty: Boolean = false,
    dateDisplayText: String = "2026年11月20日 周五",
    locationHintText: String = "上课教室：三教 204",
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        AddExamPage(
            viewState = viewState,
            selectedCourse = selectedCourse,
            courseGroupsEmpty = courseGroupsEmpty,
            dateDisplayText = dateDisplayText,
            locationHintText = locationHintText,
            onBack = {},
            onSave = {},
            onDelete = {},
            onNameChange = {},
            onPickCourse = {},
            onPickDate = {},
            onPickStartTime = {},
            onPickEndTime = {},
            onLocationChange = {},
            onSeatChange = {},
            onNoteChange = {},
            onReminderPresetChange = {},
            onAddCustomReminder = {},
            onEditCustomReminder = {},
            onRemoveCustomReminder = {},
        )
    }
}

// ── 单档：数据三态 × 亮色 ──────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 新建空表单", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddExamPagePreviewCreate() {
    PreviewAddExamPage(viewState = previewAddExamStateCreate())
}

@Suppress("unused")
@Preview(name = "2 编辑已有考试", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddExamPagePreviewEdit() {
    PreviewAddExamPage(
        viewState = previewAddExamStateEditing(),
        selectedCourse = previewExamCourse(),
    )
}

@Suppress("unused")
@Preview(name = "3 校验失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddExamPagePreviewInvalid() {
    PreviewAddExamPage(viewState = previewAddExamStateInvalid())
}

// ── 单档：外观两档（以「编辑已有考试」为基准）──────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddExamPagePreviewDark() {
    PreviewAddExamPage(
        viewState = previewAddExamStateEditing(),
        selectedCourse = previewExamCourse(),
        dark = true,
    )
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddExamPagePreviewLargeText() {
    PreviewAddExamPage(
        viewState = previewAddExamStateEditing(),
        selectedCourse = previewExamCourse(),
        textScale = 1.3f,
    )
}

// ── 总览：三态并排，一屏看完 ─────────────────────────────────────────────────

/**
 * 一屏总览：新建 / 编辑 / 暗色 横向并排，用来一眼比结构差异。
 *
 * 3 × 400dp + 2 × 16dp 间距 = 1232dp，所以画布给 1280dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~5 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·三态并排", showBackground = true, widthDp = 1280, heightDp = 900)
@Composable
private fun AddExamPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewAddExamPage(viewState = previewAddExamStateCreate())
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewAddExamPage(
                viewState = previewAddExamStateEditing(),
                selectedCourse = previewExamCourse(),
            )
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewAddExamPage(
                viewState = previewAddExamStateEditing(),
                selectedCourse = previewExamCourse(),
                dark = true,
            )
        }
    }
}
