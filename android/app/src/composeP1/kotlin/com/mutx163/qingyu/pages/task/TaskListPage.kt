package com.mutx163.qingyu.pages.task

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.ContactsBook
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.theme.MiuixTheme
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior

/**
 * 任务清单页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/task_list_screen.dart`：
 * - 顶栏：返回按钮 + 页面标题（"任务清单"）+ 新建按钮（"+"）
 * - 分段控制器：全部 / 今日 / 本周
 * - 课程筛选入口卡片（全部课程 / 无关联课程 / 课程名）
 * - 任务分组展示：已逾期（红色高亮）、任务清单（进行中）、已完成（划线）
 * - 每行操作：勾选切换完成态、点击进入编辑、长按/删除按钮删除、关联课程直达入口
 * - 底部无日期作业隐藏提示条（点击切回「全部」）
 */
@Composable
fun TaskListPage(
    viewState: TaskListViewState,
    onBack: () -> Unit,
    onDateFilterChange: (TaskDateFilter) -> Unit,
    onCourseFilterClick: () -> Unit,
    onAddTask: () -> Unit,
    onEditTask: (CourseTask) -> Unit,
    onToggleTask: (CourseTask) -> Unit,
    onDeleteTask: (CourseTask) -> Unit,
    onViewCourse: ((CourseTask) -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme

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
                    title = TaskStrings.taskListTitle,
                    largeTitle = TaskStrings.taskListTitle,
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
                        IconButton(onClick = onAddTask) {
                            Icon(
                                imageVector = MiuixIcons.Add,
                                contentDescription = TaskStrings.addTask,
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
                LazyColumn(
                        modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                        bottom = innerPadding.calculateBottomPadding() + 24.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    // ── 1. 日期分段控制器（全部 / 今日 / 本周） ──
                    item {
                        TaskDateSegmentedControl(
                            currentFilter = viewState.dateFilter,
                            onFilterSelected = onDateFilterChange,
                            dark = dark,
                        )
                    }

                    // ── 2. 课程筛选入口 ──
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                            onClick = onCourseFilterClick,
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.ContactsBook,
                                    contentDescription = null,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                    modifier = Modifier.size(20.dp),
                                )
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = viewState.selectedCourseLabel,
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Color(QingyuTheme.primaryText(dark)),
                                    )
                                    Text(
                                        text = TaskStrings.taskCourseFilter,
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
                        }
                    }

                    // ── 3. 空态展示 ──
                    if (viewState.isEmpty) {
                        item {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 24.dp),
                                insideMargin = PaddingValues(24.dp),
                            ) {
                                Column(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(16.dp),
                                ) {
                                    Text(
                                        text = viewState.emptyTitle,
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.Normal,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                        textAlign = TextAlign.Center,
                                    )
                                    Button(onClick = onAddTask) {
                                        Text(text = TaskStrings.addTask)
                                    }
                                }
                            }
                        }
                    } else {
                        // ── 4. 任务分组列表（已逾期 / 任务清单 / 已完成） ──
                        viewState.sections.forEach { section ->
                            item {
                                Text(
                                    text = section.title,
                                    fontSize = 13.sp,
                                    color = Color(QingyuTheme.sectionLabel(dark)),
                                    modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
                                )
                            }

                            item {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    insideMargin = PaddingValues(vertical = 4.dp),
                                ) {
                                    Column(modifier = Modifier.fillMaxWidth()) {
                                        section.items.forEachIndexed { index, item ->
                                            if (index > 0) {
                                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                                            }
                                            TaskRowItem(
                                                item = item,
                                                onToggle = { onToggleTask(item.task) },
                                                onEdit = { onEditTask(item.task) },
                                                onDelete = { onDeleteTask(item.task) },
                                                onViewCourse = if (item.hasCourse && onViewCourse != null) {
                                                    { onViewCourse(item.task) }
                                                } else null,
                                                dark = dark,
                                                colors = colors,
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 5. 未设到期日被过滤隐藏条目提示条 ──
                    if (viewState.undatedHiddenCount > 0) {
                        item {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 8.dp),
                                insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                                onClick = { onDateFilterChange(TaskDateFilter.ALL) },
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = TaskStrings.taskUndatedHint(viewState.undatedHiddenCount),
                                            fontSize = 15.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = Color(QingyuTheme.primaryText(dark)),
                                        )
                                        Text(
                                            text = TaskStrings.taskUndatedHintSubtitle,
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
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 日期分段控制器。
 */
@Composable
private fun TaskDateSegmentedControl(
    currentFilter: TaskDateFilter,
    onFilterSelected: (TaskDateFilter) -> Unit,
    dark: Boolean,
) {
    val filters = listOf(
        TaskDateFilter.ALL to TaskStrings.taskAllFilter,
        TaskDateFilter.TODAY to TaskStrings.taskTodayFilter,
        TaskDateFilter.WEEK to TaskStrings.taskWeekFilter,
    )

    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            filters.forEach { (filter, label) ->
                val isSelected = currentFilter == filter
                val backgroundModifier = if (isSelected) {
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (dark) Color(0xFF2C2C2E) else Color(0xFFE5E5EA))
                } else {
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(8.dp))
                }

                Box(
                    modifier = backgroundModifier
                        .clickable { onFilterSelected(filter) }
                        .padding(vertical = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        fontSize = 14.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (isSelected) {
                            Color(QingyuTheme.primaryText(dark))
                        } else {
                            Color(QingyuTheme.secondaryText(dark))
                        },
                    )
                }
            }
        }
    }
}

/**
 * 单条任务行项组件。
 */
@Composable
private fun TaskRowItem(
    item: TaskItemView,
    onToggle: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onViewCourse: (() -> Unit)?,
    dark: Boolean,
    colors: top.yukonga.miuix.kmp.theme.Colors,
) {
    val titleColor = when {
        item.isOverdue -> colors.error
        else -> Color(QingyuTheme.primaryText(dark))
    }

    val detailColor = when {
        item.isOverdue -> colors.error
        else -> Color(QingyuTheme.secondaryText(dark))
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onEdit)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // 勾选框
        Checkbox(
            state = if (item.isCompleted) ToggleableState.On else ToggleableState.Off,
            onClick = onToggle,
        )

        // 任务详情文本区
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = titleColor,
                textDecoration = if (item.isCompleted) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = item.detailText,
                fontSize = 12.sp,
                color = detailColor,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
            if (!item.note.isNullOrBlank()) {
                Text(
                    text = item.note,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }

        // 课程直达入口
        if (onViewCourse != null) {
            IconButton(onClick = onViewCourse, modifier = Modifier.size(36.dp)) {
                Icon(
                    imageVector = MiuixIcons.ContactsBook,
                    contentDescription = TaskStrings.taskViewCourse,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        // 删除按钮
        IconButton(onClick = onDelete, modifier = Modifier.size(36.dp)) {
            Icon(
                imageVector = MiuixIcons.Delete,
                contentDescription = TaskStrings.taskDelete,
                tint = Color(QingyuTheme.actionIcon(dark)),
                modifier = Modifier.size(18.dp),
            )
        }
    }
}
