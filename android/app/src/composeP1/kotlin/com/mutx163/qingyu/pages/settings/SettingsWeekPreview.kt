package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.timetable.parseHexColor
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「课程卡片 / 课表页面」两页顶部那块**本周课表缩略预览**。
 *
 * ## 为什么自绘而不复用整页周视图
 *
 * Flutter 侧这块叫 `TimetableWeekPreview`，是把首页周网格按真机比例缩进 4 成高度里
 * 的一张只读缩略图（`settings_course_card.dart:85-114`）。Compose 侧没有对应物
 * （迁移台账把「周视图网格」列为自绘白名单第 ② 项）。这里不把整页 `TimetableWeekPage`
 * 塞进来（它有自己 Scaffold / 顶栏 / 翻周手势），而是按「星期栏 + 等分节次网格 +
 * 课程色块」直接画一张缩略图：
 *
 * - 只读：没有点击/拖拽，纯展示；
 * - 自适应当前可用高度：节次行高由「可用高度 ÷ 节次」算，塞进 4 成里不溢出；
 * - 用仓储真数据：课程按 [currentWeek] 过滤，颜色取课程自带色，不造假数据。
 *
 * @param courses 仓储全量课程（本组件内部按周过滤，不要求调用方先筛）
 * @param settings 课表设置（只用 sections / semesterStartDate 决定网格密度与日期）
 * @param currentWeek 当前周（决定显示哪一周、以及哪些课程算「本周」）
 * @param timeScheme 当前作息（优先用它的节次表；为空回落到 settings.sections）
 */
@Composable
fun SettingsWeekPreview(
    courses: List<Course>,
    settings: TimetableSettings,
    currentWeek: Int,
    timeScheme: TimeScheme?,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val visibleDays = listOf(1, 2, 3, 4, 5, 6, 7)
    // 星期短名走 ARB（`weekdayShortMonday`..`weekdayShortSunday`）。
    // 2026-10-29 修（一轮审核 D3）：这里以前写死 `listOf("一", …, "日")`——渲染层中文字面量，
    // 换语言/换表都不跟着变；ARB 里本来就有这七个键。
    val dayLabels = listOf(
        SettingsStrings.weekdayShortMonday.zh,
        SettingsStrings.weekdayShortTuesday.zh,
        SettingsStrings.weekdayShortWednesday.zh,
        SettingsStrings.weekdayShortThursday.zh,
        SettingsStrings.weekdayShortFriday.zh,
        SettingsStrings.weekdayShortSaturday.zh,
        SettingsStrings.weekdayShortSunday.zh,
    )
    val sections = timeScheme?.sections?.takeIf { it.isNotEmpty() } ?: settings.sections
    val sectionCount = sections.size.coerceIn(1, 14)
    val weekCourses = remember(courses, currentWeek) {
        courses.filter { it.isInWeek(currentWeek) }
    }
    val labelColor = Color(QingyuTheme.secondaryText(dark))
    val gridColor = Color(QingyuTheme.dividerLine(dark)).copy(alpha = 0.35f)

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(QingyuTheme.card(dark))),
    ) {
        val headerHeight = 22.dp
        val bodyHeight = (maxHeight - headerHeight).coerceAtLeast(1.dp)
        val sectionHeight = (bodyHeight / sectionCount.toFloat()).coerceAtLeast(2.dp)
        val dayWidth = maxWidth / visibleDays.size.toFloat()

        Column(modifier = Modifier.fillMaxSize()) {
            // ── 星期栏 ──
            Row(
                modifier = Modifier.fillMaxWidth().height(headerHeight),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                for (label in dayLabels) {
                    Box(
                        modifier = Modifier.weight(1f),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            style = MiuixTheme.textStyles.footnote2,
                            color = labelColor,
                        )
                    }
                }
            }

            // ── 网格 + 课程色块 ──
            Box(modifier = Modifier.fillMaxWidth().height(bodyHeight)) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val stroke = 0.5.dp.toPx()
                    val rowStep = sectionHeight.toPx()
                    for (i in 1 until sectionCount) {
                        val y = rowStep * i
                        drawLine(gridColor, Offset(0f, y), Offset(size.width, y), stroke)
                    }
                    val colStep = size.width / visibleDays.size
                    for (i in 1 until visibleDays.size) {
                        val x = colStep * i
                        drawLine(gridColor, Offset(x, 0f), Offset(x, size.height), stroke)
                    }
                }

                for (course in weekCourses) {
                    val dayIndex = visibleDays.indexOf(course.dayOfWeek)
                    if (dayIndex < 0) continue
                    val start = course.startSection.coerceIn(1, sectionCount)
                    val end = course.endSection.coerceIn(start, sectionCount)
                    val span = end - start + 1
                    Box(
                        modifier = Modifier
                            .offset(
                                x = dayWidth * dayIndex.toFloat() + 1.dp,
                                y = sectionHeight * (start - 1).toFloat() + 1.dp,
                            )
                            .size(
                                width = (dayWidth - 2.dp).coerceAtLeast(1.dp),
                                height = (sectionHeight * span.toFloat() - 2.dp)
                                    .coerceAtLeast(1.dp),
                            )
                            .clip(RoundedCornerShape(3.dp))
                            .background(parseHexColor(course.color).copy(alpha = 0.9f)),
                    )
                }

                if (weekCourses.isEmpty()) {
                    Text(
                        // 2026-10-29：原来写死「本周没有排课」（ARB 里根本没有这句），
                        // 改用 ARB 已有的 `dayViewEmptyTitle`（"暂无课程"）。
                        text = SettingsStrings.weekPreviewEmpty.zh,
                        modifier = Modifier.align(Alignment.Center),
                        style = MiuixTheme.textStyles.footnote2,
                        color = labelColor,
                    )
                }
            }
        }
    }
}
