package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.task.TaskListController
import com.mutx163.qingyu.pages.task.TaskListPage
import com.mutx163.qingyu.pages.task.TaskStrings

/**
 * Phase 3.5 · 任务域宿主层：把 [TimetableRepository] 接到任务清单页上。
 *
 * ## 为什么要抽这一层（2026-10-29 任务族复刻收口时发现的事故）
 *
 * 任务清单有**两个入口**：
 *
 * 1. 页面路由 `d2.taskList`（`ShellPageIndex.kt`）——上一轮已接真数据；
 * 2. **底栏常驻「任务」tab**（`PagesShellActivity.kt` 的 `DockSlot.TASK`）——仍然喂
 *    `shellSampleTaskViewState()`（演示空态）+ 5 个空回调。
 *
 * 于是同一个页面「从路由进去是活的、从底栏进去是死的」，而且底栏恰恰是最常用的入口。
 * 两份渲染点各写一遍接线一定会再次漂移，所以与 [ScheduleListHost] 同形：**一个宿主、两处复用**。
 *
 * ## 与 `TimetableHost` 同一套订阅语义
 *
 * `observe` **订阅那一刻不推当前值**，所以首帧必须先读 `repository.snapshot`（接口语义，不是优化）；
 * 勾选/删除后仓储 `notifyStateChanged`，这里 `tick++` 触发重算。
 *
 * ## 诚实边界
 *
 * - 本层只负责「读真数据 + 写动作落盘 + 失败报出来」。导航（新建/编辑/看课程）**不在这里**，
 *   由调用方给三个 `onOpen*` 回调——底栏与路由的导航语义不同（一个 push 页面、一个走路由串）。
 * - 不加任何业务计算：筛选/分组/文案全在 `TaskListController` → `TaskFilterLogic`（JVM 可测）。
 */
@Composable
fun TaskListHost(
    repository: TimetableRepository,
    onBack: () -> Unit,
    /** 顶栏「+」与空态按钮：进新建任务表单。 */
    onOpenAddTask: () -> Unit,
    /** 点任务行：进编辑任务表单（带原任务）。 */
    onOpenEditTask: (CourseTask) -> Unit,
    /** 行尾「查看课程」：进课程编辑页；`sourceWeek` 为这条作业的来源周（Dart 同款透传）。 */
    onOpenCourse: (Course, Int?) -> Unit,
) {
    val shellContext = LocalContext.current

    // observe 回调里 tick++ 无条件触发重组：勾选/删除任务后会 notifyStateChanged，列表据此即时刷新。
    var tick by remember(repository) { mutableStateOf(0) }
    DisposableEffect(repository) {
        val subscription = repository.observe { tick++ }
        onDispose { subscription.close() }
    }

    val controller = remember(repository) { TaskListController(repository) }

    TaskListPage(
        viewState = remember(tick, controller.dateFilter, controller.courseFilter) {
            controller.viewState()
        },
        onBack = onBack,
        onDateFilterChange = {
            controller.setDateFilter(it)
            tick++
        },
        // 课程筛选弹层：候选来自 controller.courseOptions()，选中回写 controller。
        courseFilterOptions = controller.courseOptions(),
        onCourseFilterPicked = { picked ->
            controller.setCourseFilter(picked)
            tick++
        },
        onAddTask = onOpenAddTask,
        onEditTask = onOpenEditTask,
        // 勾选 / 删除落盘失败会回滚并抛异常：必须报出来，否则勾选框弹回去、用户零提示。
        onToggleTask = { task ->
            runCatching { controller.toggleTask(task) }
                .onFailure {
                    Toast.makeText(shellContext, TaskStrings.saveFailed, Toast.LENGTH_SHORT).show()
                }
        },
        onDeleteTask = { task ->
            runCatching { controller.deleteTask(task) }
                .onFailure {
                    Toast.makeText(shellContext, TaskStrings.saveFailed, Toast.LENGTH_SHORT).show()
                }
        },
        // 课程直达：与课程总览点课程同一落点（`d1.addCourse`），并带上来源周次。
        onViewCourse = { task ->
            val course = task.courseId?.let { id ->
                repository.snapshot.courses.firstOrNull { it.id == id }
            }
            if (course != null) {
                onOpenCourse(course, task.sourceWeek?.toInt())
            }
        },
    )
}
