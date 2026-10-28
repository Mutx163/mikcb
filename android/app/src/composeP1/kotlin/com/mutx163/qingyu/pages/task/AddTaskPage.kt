package com.mutx163.qingyu.pages.task

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
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
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.SelectAll
import top.yukonga.miuix.kmp.theme.MiuixTheme
import androidx.compose.foundation.layout.imePadding
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior

/**
 * 添加 / 编辑任务表单页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/add_task_screen.dart`：
 * - 顶栏：返回按钮 + 标题（"添加任务" / "编辑任务"）+ 删除按钮（仅编辑态）+ 保存按钮
 * - 表单卡片 1：任务标题输入框（带必填校验报错提示）+ 备注说明输入框
 * - 表单卡片 2：
 *   - 来源课程选择行（点击弹出课程选择弹层）
 *   - 截止日期开关（关闭时提示 "日视图不显示，只在「全部」里看得到"）
 *   - 截止日期选择行（仅开启时显示，点击唤起日期选择器）
 *   - 已完成状态开关
 */
@Composable
fun AddTaskPage(
    viewState: AddTaskViewState,
    onBack: () -> Unit,
    onTitleChange: (String) -> Unit,
    onNoteChange: (String) -> Unit,
    onPickCourseClick: () -> Unit,
    onHasDueDateChange: (Boolean) -> Unit,
    onPickDueDateClick: () -> Unit,
    onCompletedChange: (Boolean) -> Unit,
    onSave: () -> Unit,
    onDelete: (() -> Unit)? = null,
    // ---- task-18 追加：两个子弹层的入参 ----
    // ⚠️ 回调故意用**可空**默认值：宿主没接之前，这两行保持「点了不动」的旧行为，
    // 而不是弹出一个空弹层（那等于把「死入口」伪装成「活入口」，比不弹更糟）。
    // 宿主接上 `onCourseOptionPicked` / `onDueDatePicked` 之后才会弹。
    /** 选课程弹层的候选项（`AddTaskFormReducer.coursePickerOptions` 生成）。 */
    courseOptions: List<TaskCourseOption> = emptyList(),
    /** 选中项 id（`AddTaskFormReducer.NO_COURSE_OPTION_ID` 或某条课程 id）；`null` = 取消。 */
    onCourseOptionPicked: ((String?) -> Unit)? = null,
    /** 选日期弹层确认。 */
    onDueDatePicked: ((java.time.LocalDateTime) -> Unit)? = null,
    /** 选日期弹层「无到期日」。 */
    onDueDateCleared: (() -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme

    val pageTitle = if (viewState.isEditing) TaskStrings.editTask else TaskStrings.addTask

    // 顶栏折叠行为：与 Dart 侧 HyperosSubpage（overlayHeader + collapsibleLargeTitle
    // 均为默认 true）的可折叠大标题一致。必须同时传给 TopAppBar 和内容的 nestedScroll。
    val scrollBehavior = MiuixScrollBehavior()

    // task-18：两个子弹层由页面自己持有开关（判据仍在宿主的 reducer 里）。
    var showCoursePicker by remember { mutableStateOf(false) }
    var showDueDatePicker by remember { mutableStateOf(false) }

    TaskCoursePickerSheet(
        show = showCoursePicker,
        options = courseOptions,
        onPick = { optionId ->
            showCoursePicker = false
            onCourseOptionPicked?.invoke(optionId)
        },
    )
    TaskDueDatePickerSheet(
        show = showDueDatePicker,
        initial = viewState.dueDate,
        onPick = { date ->
            showDueDatePicker = false
            onDueDatePicked?.invoke(date)
        },
        onClear = {
            showDueDatePicker = false
            onDueDateCleared?.invoke()
        },
        onDismiss = { showDueDatePicker = false },
    )

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，
            // 放进槽位后 Scaffold 不再重复给这份内边距（第一版就是在这里算了两遍）。
            topBar = {
                TopAppBar(
                    title = pageTitle,
                    largeTitle = pageTitle,
                    scrollBehavior = scrollBehavior,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = TaskStrings.cancelAction,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    actions = {
                        if (viewState.isEditing && onDelete != null) {
                            IconButton(onClick = onDelete) {
                                Icon(
                                    imageVector = MiuixIcons.Delete,
                                    contentDescription = TaskStrings.taskDelete,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                        }
                        IconButton(onClick = onSave, enabled = viewState.canSave) {
                            Icon(
                                imageVector = MiuixIcons.SelectAll,
                                contentDescription = TaskStrings.saveTask,
                                tint = if (viewState.canSave) {
                                    Color(QingyuTheme.actionIcon(dark))
                                } else {
                                    Color(QingyuTheme.actionIcon(dark)).copy(alpha = 0.4f)
                                },
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    // 表单页必须避让键盘：底部输入框被 IME 盖住的话没法填。
                    // Dart 侧靠 resizeToAvoidBottomInset: true 达到同一效果。
                    .imePadding(),
            ) {
                QingyuPageList(
                    innerPadding = innerPadding,
                    scrollBehavior = scrollBehavior,
                    // 官方配方：横向留白由卡片自己带（12dp），滚动条才贴得到屏幕边缘。
                    horizontalPadding = QingyuPageCardMargin,
                    // 顶部 8dp 是页面自己的留白；底部手势条那段由 QingyuPageList
                    // 内部按 innerPadding 算（等价于原先手写的
                    // innerPadding.calculateBottomPadding()），不要重复相加。
                    contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    // ── 1. 标题与备注输入卡片 ──
                    item {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Column(modifier = Modifier.fillMaxWidth()) {
                                    TextField(
                                        value = viewState.title,
                                        onValueChange = onTitleChange,
                                        modifier = Modifier.fillMaxWidth(),
                                        label = TaskStrings.taskTitleLabel,
                                        singleLine = true,
                                    )
                                    if (!viewState.titleError.isNullOrBlank()) {
                                        Text(
                                            text = viewState.titleError,
                                            style = MiuixTheme.textStyles.footnote1,
                                            color = colors.error,
                                            modifier = Modifier.padding(start = 4.dp, top = 4.dp),
                                        )
                                    }
                                }

                                TextField(
                                    value = viewState.note,
                                    onValueChange = onNoteChange,
                                    modifier = Modifier.fillMaxWidth(),
                                    label = TaskStrings.taskNoteLabel,
                                    singleLine = false,
                                    maxLines = 4,
                                )
                            }
                        }
                    }

                    // ── 2. 课程关联、到期日与完成状态卡片 ──
                    item {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(vertical = 4.dp),
                        ) {
                            Column(modifier = Modifier.fillMaxWidth()) {
                                // 来源课程行
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            // task-18：这一行以前点不动（宿主给的回调是空实现，
                                            // 页面自己也没有子弹层）。现在页面自己弹选课程层，
                                            // 选完通过 onCourseOptionPicked 交给宿主的 reducer。
                                            // 宿主没接（回调为 null）或没有候选项时不弹——
                                            // 弹一个空列表等于把死入口伪装成活入口。
                                            onPickCourseClick()
                                            if (onCourseOptionPicked != null && courseOptions.isNotEmpty()) {
                                                showCoursePicker = true
                                            }
                                        }
                                        .padding(horizontal = 14.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = viewState.selectedCourseName,
                                            style = MiuixTheme.textStyles.body1,
                                            fontWeight = FontWeight.Medium,
                                            color = Color(QingyuTheme.primaryText(dark)),
                                        )
                                        Text(
                                            text = TaskStrings.taskCourseLabel,
                                            style = MiuixTheme.textStyles.footnote1,
                                            color = Color(QingyuTheme.secondaryText(dark)),
                                            modifier = Modifier.padding(top = 2.dp),
                                        )
                                    }
                                    Icon(
                                        imageVector = MiuixIcons.ChevronForward,
                                        contentDescription = null,
                                        tint = Color(QingyuTheme.actionIcon(dark)),
                                    )
                                }

                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))

                                // 截止日期开关行
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 14.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = TaskStrings.taskDueDateLabel,
                                            style = MiuixTheme.textStyles.body1,
                                            fontWeight = FontWeight.Medium,
                                            color = Color(QingyuTheme.primaryText(dark)),
                                        )
                                        if (!viewState.hasDueDate) {
                                            Text(
                                                text = TaskStrings.taskDueDateHint,
                                                style = MiuixTheme.textStyles.footnote1,
                                                color = Color(QingyuTheme.secondaryText(dark)),
                                                modifier = Modifier.padding(top = 2.dp),
                                            )
                                        }
                                    }
                                    Switch(
                                        checked = viewState.hasDueDate,
                                        onCheckedChange = onHasDueDateChange,
                                    )
                                }

                                // 截止日期选择行（仅在开启截止日期时展示）
                                if (viewState.hasDueDate) {
                                    HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))

                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                // task-18：同上，日期行以前也点不动。
                                                // 宿主没接 onDueDatePicked 时不弹（见签名处说明）。
                                                onPickDueDateClick()
                                                if (onDueDatePicked != null) {
                                                    showDueDatePicker = true
                                                }
                                            }
                                            .padding(horizontal = 14.dp, vertical = 12.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        Text(
                                            text = viewState.dueDateFormatted.ifEmpty { TaskStrings.taskDueDateLabel },
                                            style = MiuixTheme.textStyles.body1,
                                            fontWeight = FontWeight.Medium,
                                            color = Color(QingyuTheme.primaryText(dark)),
                                            modifier = Modifier.weight(1f),
                                        )
                                        Icon(
                                            imageVector = MiuixIcons.ChevronForward,
                                            contentDescription = null,
                                            tint = Color(QingyuTheme.actionIcon(dark)),
                                        )
                                    }
                                }

                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))

                                // 已完成开关行
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 14.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Text(
                                        text = TaskStrings.taskCompletedSection,
                                        style = MiuixTheme.textStyles.body1,
                                        fontWeight = FontWeight.Medium,
                                        color = Color(QingyuTheme.primaryText(dark)),
                                        modifier = Modifier.weight(1f),
                                    )
                                    Switch(
                                        checked = viewState.isCompleted,
                                        onCheckedChange = onCompletedChange,
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
