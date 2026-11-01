package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 周视图课程网格（对应 Dart `lib/widgets/timetable/timetable_week_grid.dart` +
 * `timetable_day_column.dart`）。
 *
 * ## 与旧实现的差别（2026-10-29 重做）
 *
 * 1. **不再画背景网格线**：Dart 周网格没有横线/竖线（`timetable_day_column.dart`
 *    的 `gridLines` 只放空白标记槽，不是分隔线）。旧实现用 Canvas 画了一整张
 *    网格，视觉上比原版重得多。
 * 2. **课程卡占满整列**：Dart 的课卡是 `Positioned(left: 0, right: 0)`，同天
 *    重叠时后画的压住先画的；旧实现自己发明了「按列平分」，与 Flutter 完全不同。
 * 3. **考试 / 日程落格卡**：Dart 会把当天的考试与日程按钟点映射成节次卡，画在
 *    课程卡**之上**（`WeekGridAgendaPlacement`），旧实现完全没有。
 * 4. **空白格**：Dart 里点空白什么都不做；只有开了「长按空白格加课」时长按才
 *    出现加课入口。旧实现把每一格都挂成「点一下就加课」，误触很多。
 */
@Composable
fun TimetableWeekGrid(
    cardsByDay: Map<Int, List<WeekCardModel>>,
    agendaByDay: Map<Int, List<WeekAgendaCardModel>> = emptyMap(),
    visibleDays: List<Int> = (1..7).toList(),
    sectionCount: Int = 12,
    sectionHeight: Dp = 68.dp,
    style: WeekViewStyle = WeekViewStyle(),
    holidayForDay: (Int) -> Boolean = { false },
    onCourseClick: (Course) -> Unit = {},
    onAgendaClick: (WeekAgendaCardModel) -> Unit = {},
    onLongPressEmptySlot: ((dayOfWeek: Int, section: Int) -> Unit)? = null,
    modifier: Modifier = Modifier,
    material: HomeMaterialRenderSpec? = null,
    /**
     * 课卡液态档的背景采样源（整页共享，见 `TimetableWeekPage.cardGlassBackdrop`）。
     * null = 各卡走原有透明度填充；非空时所有卡片采同一层，不额外建录像带。
     */
    cardGlassBackdrop: Backdrop? = null,
) {
    val totalHeight = sectionHeight * sectionCount
    val dayCount = visibleDays.size.coerceAtLeast(1)

    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(totalHeight),
    ) {
        val dayWidth: Dp = maxWidth / dayCount.toFloat()

        Row(modifier = Modifier.fillMaxWidth()) {
            for (dayOfWeek in visibleDays) {
                val cards = cardsByDay[dayOfWeek].orEmpty()
                val agenda = agendaByDay[dayOfWeek].orEmpty()
                Box(
                    modifier = Modifier
                        .width(dayWidth)
                        .fillMaxHeight(),
                ) {
                    // ── 1. 空白格长按层（Dart `TimetableEmptySlotGestureArea`）──
                    if (onLongPressEmptySlot != null && style.longPressEmptySlotToAddCourse) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            for (section in 1..sectionCount) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(sectionHeight)
                                        .pointerInput(dayOfWeek, section) {
                                            detectTapGestures(
                                                onLongPress = {
                                                    onLongPressEmptySlot(dayOfWeek, section)
                                                },
                                            )
                                        },
                                )
                            }
                        }
                    }

                    // ── 2. 课程卡（整列宽，重叠时按排序叠放）──
                    for (card in cards) {
                        val startSection = card.course.startSection.coerceIn(1, sectionCount)
                        val endSection = card.course.endSection.coerceIn(startSection, sectionCount)
                        val span = endSection - startSection + 1
                        Box(
                            modifier = Modifier
                                .offset(y = sectionHeight * (startSection - 1))
                                .fillMaxWidth()
                                .height(sectionHeight * span),
                        ) {
                            CourseGridCard(
                                model = card,
                                style = style,
                                sectionHeight = sectionHeight,
                                isHoliday = holidayForDay(dayOfWeek),
                                onClick = { onCourseClick(card.course) },
                                material = material,
                                glassBackdrop = cardGlassBackdrop,
                            )
                        }
                    }

                    // ── 3. 考试 / 日程卡（画在课程卡之上，Dart 同序）──
                    for (entry in agenda) {
                        val start = entry.startSection.coerceIn(1, sectionCount)
                        val end = entry.endSection.coerceIn(start, sectionCount)
                        val span = end - start + 1
                        Box(
                            modifier = Modifier
                                .offset(y = sectionHeight * (start - 1))
                                .fillMaxWidth()
                                .height(sectionHeight * span),
                        ) {
                            WeekAgendaCard(
                                model = entry,
                                style = style,
                                sectionHeight = sectionHeight,
                                onClick = { onAgendaClick(entry) },
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 周网格里的考试 / 日程卡（Dart `week_grid_agenda_card.dart`）。
 *
 * 视觉口径：圆角 8、徽标药丸（考试红 / 日程本色）、标题两行、非跨天时补一行时刻。
 */
@Composable
private fun WeekAgendaCard(
    model: WeekAgendaCardModel,
    style: WeekViewStyle,
    sectionHeight: Dp,
    onClick: () -> Unit,
) {
    val isExam = model.kind == WeekAgendaKind.EXAM
    val fill = if (isExam) {
        MiuixTheme.colorScheme.error
    } else {
        parseHexColor(model.colorHex, fallback = MiuixTheme.colorScheme.primary)
    }
    val ink = calculateInk(fill)
    val titleFontSize = style.cardTitleFontSize + 1f
    val detailFontSize = style.cardTitleFontSize.coerceIn(7f, 13f)
    val verticalPadding = if (sectionHeight < 64.dp) 3.dp else 5.dp
    val shape = RoundedCornerShape(WeekCardMetrics.CORNER_RADIUS_DP.dp)

    Box(
        modifier = Modifier
            .padding(style.cardInsetDp.dp)
            .fillMaxWidth()
            .fillMaxHeight()
            .clip(shape)
            .background(fill.copy(alpha = 0.9f))
            .pointerInput(model.id) {
                detectTapGestures(onTap = { onClick() })
            },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = WeekCardMetrics.INNER_HORIZONTAL_DP.dp,
                    vertical = verticalPadding,
                ),
            verticalArrangement = Arrangement.Top,
        ) {
            // 徽标药丸：考试 / 日程
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(ink.copy(alpha = 0.18f))
                    .padding(horizontal = 3.dp, vertical = 1.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                Text(
                    text = if (isExam) {
                        TimetableStrings.examBadgeLabel.zh
                    } else {
                        TimetableStrings.scheduleBadgeLabel.zh
                    },
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                    fontSize = detailFontSize.sp,
                    color = ink,
                    maxLines = 1,
                )
            }
            Spacer(modifier = Modifier.height(WeekCardMetrics.LINE_GAP_DP.dp))
            Text(
                text = model.title,
                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                fontSize = titleFontSize.sp,
                color = ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            // 跨天日程的时刻是 00:00–23:59（整列占位），画出来只是噪音。
            if (!model.isCrossDay && model.startTime.isNotEmpty()) {
                Spacer(modifier = Modifier.height(WeekCardMetrics.LINE_GAP_DP.dp))
                Text(
                    text = "${model.startTime} - ${model.endTime}",
                    style = MiuixTheme.textStyles.footnote2,
                    fontSize = detailFontSize.sp,
                    color = ink.copy(alpha = 0.88f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
