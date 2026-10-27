package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.theme.QingyuTheme

/**
 * 课表周视图网格主体布局（Timetable Week Grid · Compose Phase 3）。
 *
 * 对应 Flutter `lib/widgets/timetable/timetable_week_grid.dart`：
 * - 二维网格系统：按 (dayOfWeek, section) 将课程卡片绝对定位到精确像素坐标；
 * - 连堂撑满：多节次连堂课程纵向高度自动为 (endSection - startSection + 1) * sectionHeight；
 * - 冲突并列：同天同节次重叠课程自动分列（Interval Scheduling 算法），按比例平分当天宽度并展示冲突状态；
 * - 背景辅助线：节次之间淡灰色水平线、日期列之间垂直分割线；
 * - 空白点击：点击无课节次网格立即回调 [onEmptySlotClick]，方便快捷添课。
 */
@Composable
fun TimetableWeekGrid(
    courses: List<Course>,
    week: Int,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    sectionCount: Int = 12,
    sectionHeight: Dp = 64.dp,
    onCourseClick: (Course) -> Unit = {},
    onEmptySlotClick: (dayOfWeek: Int, section: Int) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val totalHeight = sectionHeight * sectionCount
    val dividerColor = Color(QingyuTheme.dividerLine(dark)).copy(alpha = 0.35f)

    // ── 算法：按天对课程进行冲突分组与分列排版 ──
    val layoutModels = remember(courses, week, visibleDays) {
        buildWeekGridLayout(courses, week, visibleDays)
    }

    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(totalHeight),
    ) {
        val totalWidth = maxWidth
        val dayCount = visibleDays.size.coerceAtLeast(1)
        val dayWidth = totalWidth / dayCount

        // ── 1. 背景网格细线 ──
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeWidth = 0.5.dp.toPx()
            val canvasWidth = size.width
            val canvasHeight = size.height

            // 水平节次线
            val sectionHeightPx = sectionHeight.toPx()
            for (i in 1 until sectionCount) {
                val y = i * sectionHeightPx
                drawLine(
                    color = dividerColor,
                    start = Offset(0f, y),
                    end = Offset(canvasWidth, y),
                    strokeWidth = strokeWidth,
                )
            }

            // 垂直日列线
            val dayWidthPx = canvasWidth / dayCount
            for (i in 1 until dayCount) {
                val x = i * dayWidthPx
                drawLine(
                    color = dividerColor,
                    start = Offset(x, 0f),
                    end = Offset(x, canvasHeight),
                    strokeWidth = strokeWidth,
                )
            }
        }

        // ── 2. 空白节次点击响应层 ──
        // 覆盖在背景网格上方、课程卡片下方；未被课程阻挡的点击将触发空白加课
        for (dayIndex in visibleDays.indices) {
            val dayOfWeek = visibleDays[dayIndex]
            val xOffset = dayWidth * dayIndex

            for (section in 1..sectionCount) {
                val yOffset = sectionHeight * (section - 1)
                Box(
                    modifier = Modifier
                        .offset(x = xOffset, y = yOffset)
                        .size(width = dayWidth, height = sectionHeight)
                        .clickable { onEmptySlotClick(dayOfWeek, section) },
                )
            }
        }

        // ── 3. 课程卡片层 ──
        for (model in layoutModels) {
            val course = model.course
            val dayIndex = visibleDays.indexOf(course.dayOfWeek)
            if (dayIndex < 0) continue

            val startSec = course.startSection.coerceIn(1, sectionCount)
            val endSec = course.endSection.coerceIn(startSec, sectionCount)
            val span = endSec - startSec + 1

            val colWidth = dayWidth / model.totalCols.coerceAtLeast(1)
            val x = dayWidth * dayIndex + colWidth * model.colIndex
            val y = sectionHeight * (startSec - 1)
            val cardHeight = sectionHeight * span

            Box(
                modifier = Modifier
                    .offset(x = x, y = y)
                    .size(width = colWidth, height = cardHeight),
            ) {
                CourseGridCard(
                    model = model,
                    onClick = onCourseClick,
                )
            }
        }
    }
}

/**
 * 将整周的课程列表进行空间排版与分列计算。
 */
private fun buildWeekGridLayout(
    courses: List<Course>,
    week: Int,
    visibleDays: List<Int>,
): List<WeekGridCardModel> {
    val result = mutableListOf<WeekGridCardModel>()

    for (dayOfWeek in visibleDays) {
        val dayCourses = courses.filter { it.dayOfWeek == dayOfWeek }
        if (dayCourses.isEmpty()) continue

        // 按照起始节次升序排，节次相同按结束节次降序排
        val sortedCourses = dayCourses.sortedWith(
            compareBy<Course> { it.startSection }.thenByDescending { it.endSection },
        )

        // 划分相互重叠的冲突群簇 (Clusters)
        val clusters = mutableListOf<MutableList<Course>>()
        for (course in sortedCourses) {
            var added = false
            for (cluster in clusters) {
                // 如果当前课程与群簇中任意一门课时段重叠，则加入该群簇
                val hasOverlap = cluster.any { existing ->
                    !(course.endSection < existing.startSection || existing.endSection < course.startSection)
                }
                if (hasOverlap) {
                    cluster.add(course)
                    added = true
                    break
                }
            }
            if (!added) {
                clusters.add(mutableListOf(course))
            }
        }

        // 对每个群簇分配分列索引 (Greedy Interval Coloring)
        for (cluster in clusters) {
            if (cluster.size == 1) {
                val c = cluster.first()
                result.add(
                    WeekGridCardModel(
                        course = c,
                        isCurrentWeek = c.isActiveInWeek(week),
                        isConflicting = false,
                        colIndex = 0,
                        totalCols = 1,
                    ),
                )
                continue
            }

            // 存在多门课程重叠，分配列号
            val columnsLastEnd = mutableListOf<Int>()
            val assignments = mutableListOf<Pair<Course, Int>>()

            for (c in cluster) {
                var assignedCol = -1
                for (col in columnsLastEnd.indices) {
                    if (columnsLastEnd[col] < c.startSection) {
                        assignedCol = col
                        columnsLastEnd[col] = c.endSection
                        break
                    }
                }
                if (assignedCol == -1) {
                    assignedCol = columnsLastEnd.size
                    columnsLastEnd.add(c.endSection)
                }
                assignments.add(c to assignedCol)
            }

            val totalCols = columnsLastEnd.size
            for ((c, colIndex) in assignments) {
                result.add(
                    WeekGridCardModel(
                        course = c,
                        isCurrentWeek = c.isActiveInWeek(week),
                        isConflicting = totalCols > 1,
                        colIndex = colIndex,
                        totalCols = totalCols,
                    ),
                )
            }
        }
    }

    return result
}
