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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
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
import androidx.compose.ui.input.nestedscroll.nestedScroll
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
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme

    val pageTitle = if (viewState.isEditing) TaskStrings.editTask else TaskStrings.addTask

    // 顶栏折叠行为：与 Dart 侧 HyperosSubpage（overlayHeader + collapsibleLargeTitle
    // 均为默认 true）的可折叠大标题一致。必须同时传给 TopAppBar 和内容的 nestedScroll。
    val scrollBehavior = MiuixScrollBehavior()

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
                    .imePadding()
                    .padding(innerPadding),
            ) {
                LazyColumn(
                        modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                        bottom = innerPadding.calculateBottomPadding() + 24.dp,
                    ),
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
                                            fontSize = 12.sp,
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
                                        .clickable(onClick = onPickCourseClick)
                                        .padding(horizontal = 14.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = viewState.selectedCourseName,
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = Color(QingyuTheme.primaryText(dark)),
                                        )
                                        Text(
                                            text = TaskStrings.taskCourseLabel,
                                            fontSize = 12.sp,
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
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = Color(QingyuTheme.primaryText(dark)),
                                        )
                                        if (!viewState.hasDueDate) {
                                            Text(
                                                text = TaskStrings.taskDueDateHint,
                                                fontSize = 12.sp,
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
                                            .clickable(onClick = onPickDueDateClick)
                                            .padding(horizontal = 14.dp, vertical = 12.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        Text(
                                            text = viewState.dueDateFormatted.ifEmpty { TaskStrings.taskDueDateLabel },
                                            fontSize = 16.sp,
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
                                        fontSize = 16.sp,
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
