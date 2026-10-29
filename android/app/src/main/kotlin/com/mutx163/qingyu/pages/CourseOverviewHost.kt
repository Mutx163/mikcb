package com.mutx163.qingyu.pages

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.mutx163.qingyu.course.CourseDomain
import com.mutx163.qingyu.pages.course.CourseOverviewLogic
import com.mutx163.qingyu.pages.course.CourseOverviewPage
import com.mutx163.qingyu.pages.course.CourseOverviewSortMode

/**
 * 课程总览页的**壳侧宿主**（`d1.overview` 的真实接线，2026-10-28）。
 *
 * ## 为什么单独一个文件
 *
 * `ShellPageIndex.kt` 是多个会话共编的热点文件。把「订阅仓储 / 排序档 UI 态 / 组装视图状态 /
 * 回调转导航」这些本页专属逻辑收在这里，分派层只需一行 [CourseOverviewHost] 调用，
 * 既减少与其它泳道的写冲突，也让本页接线自成一屏、可读。
 *
 * ## 接线内容（逐项对齐 Flutter `course_overview_screen.dart` + provider）
 *
 * | 数据/回调 | 来源 / 落点 |
 * |---|---|
 * | 课程列表 | `repository.snapshot.courses`（订阅 [TimetableRepository.observe]，先读 snapshot 拿初值） |
 * | 冲突索引 | `CourseDomain.buildConflictMap(courses)`（week=null，与 Dart `provider.courseConflictMap` 同口径） |
 * | 排序档 | 本页 `remember { mutableStateOf(ADDED) }`（Dart `_sortMode` 的 State；离开页面即复位） |
 * | 顶栏「+」/ 空态按钮 | `clearAddCourseIntent()` → 进 `d1.addCourse`（新建） |
 * | 点课程组 | `pendingEditGroup = group` → 进 `d1.addCourse`（**组编辑**，Dart `AddCourseScreen(courseGroup:)`） |
 * | 冲突入口 | 进 `k.conflict`（冲突详情页，已接真数据） |
 * | 选排序档 | 改本页 `sortMode`，重组即刷新 `viewState`（Dart `_onSortSelected`） |
 *
 * ## 订阅语义
 *
 * 与 `TimetableWithCourseActions` 一致：`observe` **订阅那一刻不推当前值**，所以首帧必须
 * 先读 `repository.snapshot`，否则第一次进来是空列表、要等下一次变更才出现课程。
 *
 * @param wiring 壳接线层（仓储 + 跨子树意图载体）
 * @param onBack 返回
 * @param onOpenPage 推壳内页面（`d1.addCourse` / `k.conflict`）
 */
@Composable
fun CourseOverviewHost(
    wiring: ShellWiring,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val repository = wiring.timetable
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    // 排序档是**纯 UI 状态**（Dart `_sortMode`）：离开本页即回到默认「按添加顺序」。
    var sortMode by remember { mutableStateOf(CourseOverviewSortMode.ADDED) }

    val viewState = remember(snapshot, sortMode) {
        CourseOverviewLogic.buildViewState(
            courses = snapshot.courses,
            conflictMap = CourseDomain.buildConflictMap(snapshot.courses),
            sortMode = sortMode,
        )
    }

    CourseOverviewPage(
        viewState = viewState,
        onBack = onBack,
        onAddCourse = {
            // 新建：清掉一切跨子树编辑意图（组/单课/空档预填）。
            wiring.clearAddCourseIntent()
            onOpenPage("d1.addCourse")
        },
        onOpenGroup = { group ->
            // 组编辑：与单课编辑互斥，只填组意图。
            wiring.pendingEditCourse = null
            wiring.pendingAddCourseSeed = null
            wiring.pendingEditGroup = group
            onOpenPage("d1.addCourse")
        },
        onOpenConflictDetail = { onOpenPage("k.conflict") },
        onSortModeSelected = { sortMode = it },
    )
}
