package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlin.math.roundToInt

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
 * 4. **空白格的「两步式添加」**（2026-11-09 补齐，Dart `timetable_screen.dart:4751`
 *    `_buildEmptySlotGestureArea`）：点空白什么都不做；开了「长按空白格加课」后，
 *    **长按先出虚线框标记（不跳页）**，按住拖动可跟手换格，松手后标记留在原处，
 *    拖框上/下细杠可把框拉长成多节，**点虚线框才进加课页**并预填星期 + 起止节次。
 *    旧实现一长按就直接跳加课页，虚线框 / 跟手换格 / 跨节拉长三件全丢。
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
    /**
     * 两步式添加的**确认回调**（点虚线框时回传星期 + 起止节次，Dart
     * `_openAddCourseFromEmptySlot(week, dayOfWeek, startSection, endSection)`）。
     *
     * 非 null 时优先用它，[onLongPressEmptySlot] 只作兼容回退（只有起始节次，
     * 给还没接三参的宿主用）。语义上长按不再直接回调——必须点框才确认。
     */
    onLongPressEmptySlotSpan: ((dayOfWeek: Int, startSection: Int, endSection: Int) -> Unit)? = null,
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

    // ── 空白格「两步式添加」状态（Dart `timetable_screen.dart:251-267` 那几个字段）──
    // markerDay == 0 = 没有标记；否则标记覆盖 markerStart..markerEnd 节。
    var markerDay by remember { mutableIntStateOf(0) }
    var markerStart by remember { mutableIntStateOf(0) }
    var markerEnd by remember { mutableIntStateOf(0) }
    // 拖框上/下边时锚在**按下那一刻**的框上（Dart `_emptySlotResizeBaseStart/End`）：
    // 用框自己的实时值当基准，节数换算会随框变化漂移（越拖越快 / 拖不回去）。
    var resizeTopEdge by remember { mutableStateOf(false) }
    var resizeBaseStart by remember { mutableIntStateOf(0) }
    var resizeBaseEnd by remember { mutableIntStateOf(0) }
    var resizeAccum by remember { mutableFloatStateOf(0f) }
    // 本次长按手势是不是**从空白格起来**的：起点落在课卡上时不落标记，
    // 拖到空格也不补（Dart 的手势层在课卡下面，起点在卡上就整段都不响应）。
    var emptySlotDragActive by remember { mutableStateOf(false) }
    // 按下那一刻是否已有标记：长按刚落下的那一下抬手不能被 tap 判成「点空白清标记」。
    var markerDayAtPress by remember { mutableIntStateOf(0) }
    // 本次手势里长按有没有成立过：成立过就说明标记是这次手势自己落的，
    // 抬手不能当成「点空白取消选择」。
    var emptySlotLongPressed by remember { mutableStateOf(false) }

    val emptySlotGestureEnabled = style.longPressEmptySlotToAddCourse &&
        (onLongPressEmptySlot != null || onLongPressEmptySlotSpan != null)

    // 有课 / 有日程的节次：长按落点与跨节拉长都不许压上去（Dart `occupiedSections`）。
    val occupiedByDay: Map<Int, Set<Int>> = remember(cardsByDay, agendaByDay, sectionCount) {
        val occupied = HashMap<Int, MutableSet<Int>>()
        cardsByDay.forEach { (day, cards) ->
            val sections = occupied.getOrPut(day) { HashSet() }
            cards.forEach { card ->
                val start = card.course.startSection.coerceIn(1, sectionCount)
                val end = card.course.endSection.coerceIn(start, sectionCount)
                for (section in start..end) sections.add(section)
            }
        }
        agendaByDay.forEach { (day, entries) ->
            val sections = occupied.getOrPut(day) { HashSet() }
            entries.forEach { entry ->
                val start = entry.startSection.coerceIn(1, sectionCount)
                val end = entry.endSection.coerceIn(start, sectionCount)
                for (section in start..end) sections.add(section)
            }
        }
        occupied
    }

    val haptic = LocalHapticFeedback.current
    val sectionHeightPx = with(LocalDensity.current) { sectionHeight.toPx() }

    fun clearEmptySlotMarker() {
        markerDay = 0
        markerStart = 0
        markerEnd = 0
        resizeBaseStart = 0
        resizeBaseEnd = 0
        resizeAccum = 0f
    }

    // 点虚线框才进加课（Dart `_openAddCourseFromEmptySlot`）：先清标记再回传，
    // 保证「标记 → 表单」是一次确认，跳页后网格上不留残影。
    fun confirmEmptySlotMarker() {
        val day = markerDay
        val start = markerStart
        val end = markerEnd
        if (day <= 0 || start <= 0 || end < start) return
        clearEmptySlotMarker()
        val spanCallback = onLongPressEmptySlotSpan
        if (spanCallback != null) {
            spanCallback(day, start, end)
        } else {
            onLongPressEmptySlot?.invoke(day, start)
        }
    }

    // 拖上/下边改首尾（Dart `_resizeEmptySlotMarker`）：越界钳住、首尾不交叉；
    // 往大拉时遇到有课的格就停在它前面，收缩方向永远放行。
    fun resizeEmptySlotMarker(deltaDy: Float) {
        val baseStart = resizeBaseStart
        val baseEnd = resizeBaseEnd
        if (baseStart <= 0 || baseEnd < baseStart || sectionHeightPx <= 0f) return
        resizeAccum += deltaDy
        val delta = (resizeAccum / sectionHeightPx).roundToInt()
        var newStart = baseStart
        var newEnd = baseEnd
        val occupied = occupiedByDay[markerDay].orEmpty()
        if (resizeTopEdge) {
            newStart = (baseStart + delta).coerceIn(1, baseEnd)
            var section = baseStart - 1
            while (section >= newStart) {
                if (occupied.contains(section)) {
                    newStart = section + 1
                    break
                }
                section -= 1
            }
        } else {
            newEnd = (baseEnd + delta).coerceIn(baseStart, sectionCount)
            var section = baseEnd + 1
            while (section <= newEnd) {
                if (occupied.contains(section)) {
                    newEnd = section - 1
                    break
                }
                section += 1
            }
        }
        if (newStart != markerStart || newEnd != markerEnd) {
            markerStart = newStart
            markerEnd = newEnd
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        }
    }

    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(totalHeight),
    ) {
        val dayWidth: Dp = maxWidth / dayCount.toFloat()
        val density = LocalDensity.current
        val dayWidthPx = with(density) { dayWidth.toPx() }

        // 网格级手势层（Dart 挂在整块日列 Row 上，见 `_buildEmptySlotGestureArea`）：
        // 长按 → 标记落格；按住拖动 → 标记跟手换格（滑过课卡时保持原格不动）；
        // 点别处 → 清掉标记。坐标换算直接用事件自带的 position（本层即网格坐标）。
        val emptySlotGestureModifier = if (emptySlotGestureEnabled) {
            Modifier
                .pointerInput(visibleDays, sectionCount, occupiedByDay) {
                    // 点空白 = 取消选择（Dart `_buildEmptySlotGestureArea` 的 onTap）。
                    // 只在「按下时已经有标记」才清——否则长按刚落下的那一下抬手会把
                    // 刚出现的虚线框顺手清掉。
                    detectTapGestures(
                        onPress = {
                            emptySlotLongPressed = false
                            markerDayAtPress = markerDay
                        },
                        onTap = {
                            if (!emptySlotLongPressed && markerDayAtPress != 0) {
                                clearEmptySlotMarker()
                            }
                        },
                    )
                }
                .pointerInput(visibleDays, sectionCount, occupiedByDay, dayWidthPx, sectionHeightPx) {
                    detectDragGesturesAfterLongPress(
                        onDragStart = { position ->
                            emptySlotLongPressed = true
                            val cell = emptySlotCellAt(
                                position = position,
                                dayWidthPx = dayWidthPx,
                                sectionHeightPx = sectionHeightPx,
                                visibleDays = visibleDays,
                                sectionCount = sectionCount,
                                occupiedByDay = occupiedByDay,
                            )
                            emptySlotDragActive = cell != null
                            if (cell != null) {
                                clearEmptySlotMarker()
                                markerDay = cell.first
                                markerStart = cell.second
                                markerEnd = cell.second
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            }
                        },
                        onDrag = drag@{ change, _ ->
                            change.consume()
                            if (!emptySlotDragActive) return@drag
                            val cell = emptySlotCellAt(
                                position = change.position,
                                dayWidthPx = dayWidthPx,
                                sectionHeightPx = sectionHeightPx,
                                visibleDays = visibleDays,
                                sectionCount = sectionCount,
                                occupiedByDay = occupiedByDay,
                            )
                            if (cell != null &&
                                (cell.first != markerDay || cell.second != markerStart)
                            ) {
                                markerDay = cell.first
                                markerStart = cell.second
                                markerEnd = cell.second
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            }
                        },
                        onDragEnd = { emptySlotDragActive = false },
                        onDragCancel = { emptySlotDragActive = false },
                    )
                }
        } else {
            Modifier
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(emptySlotGestureModifier),
        ) {
            for (dayOfWeek in visibleDays) {
                val cards = cardsByDay[dayOfWeek].orEmpty()
                val agenda = agendaByDay[dayOfWeek].orEmpty()
                Box(
                    modifier = Modifier
                        .width(dayWidth)
                        .fillMaxHeight(),
                ) {
                    // ── 1. 空白格两步式标记（Dart `_EmptySlotAddMarker`，画在课卡下面）──
                    if (emptySlotGestureEnabled && markerDay == dayOfWeek && markerStart >= 1) {
                        val markerSpan = (markerEnd - markerStart + 1).coerceAtLeast(1)
                        EmptySlotAddMarker(
                            modifier = Modifier
                                .offset(y = sectionHeight * (markerStart - 1))
                                .fillMaxWidth()
                                .height(sectionHeight * markerSpan),
                            sectionHeight = sectionHeight,
                            span = markerSpan,
                            inset = (style.cardInsetDp + 2).dp,
                            onConfirm = { confirmEmptySlotMarker() },
                            onResizeStart = { isTopEdge ->
                                resizeTopEdge = isTopEdge
                                resizeBaseStart = markerStart
                                resizeBaseEnd = markerEnd
                                resizeAccum = 0f
                            },
                            onResizeBy = { deltaDy -> resizeEmptySlotMarker(deltaDy) },
                            onResizeEnd = {
                                resizeBaseStart = 0
                                resizeBaseEnd = 0
                                resizeAccum = 0f
                            },
                        )
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
                        TimetableStrings.examBadgeLabel.text
                    } else {
                        TimetableStrings.scheduleBadgeLabel.text
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

/**
 * 指针局部坐标 → （星期, 节次）；越界或该格有课 / 有日程时返回 null。
 *
 * 直接对应 Dart `_buildEmptySlotGestureArea` 里的 `cellAt`：坐标系是整块日列 Row，
 * 所以 `x / dayWidth` 落在第几列、`y / sectionHeight` 落在第几节。
 * 有课的格返回 null —— 拖过课程卡时标记保持原格不动（与 Dart 同口径）。
 */
private fun emptySlotCellAt(
    position: Offset,
    dayWidthPx: Float,
    sectionHeightPx: Float,
    visibleDays: List<Int>,
    sectionCount: Int,
    occupiedByDay: Map<Int, Set<Int>>,
): Pair<Int, Int>? {
    if (visibleDays.isEmpty()) return null
    if (dayWidthPx <= 0f || sectionHeightPx <= 0f) return null
    if (position.x < 0f || position.y < 0f) return null
    val dayIndex = (position.x / dayWidthPx).toInt().coerceIn(0, visibleDays.lastIndex)
    val section = (position.y / sectionHeightPx).toInt() + 1
    if (section < 1 || section > sectionCount) return null
    val dayOfWeek = visibleDays[dayIndex]
    if (occupiedByDay[dayOfWeek]?.contains(section) == true) return null
    return dayOfWeek to section
}

/**
 * 空白格的虚线加号标记（Dart `_EmptySlotAddMarker`，`timetable_screen.dart:7994-8071`）。
 *
 * 视觉：圆角 12dp 虚线框（描边 1.5dp、dash 4 / gap 3.5、填充 8% 淡墨）+ 居中加号；
 * 框的上下各有一条 26×3dp 细杠提示可拖。交互：点框（含细杠）→ 进加课表单；
 * 拖细杠 → 改首尾节次（换算与越界钳制在 [TimetableWeekGrid] 的 `resizeEmptySlotMarker`）。
 *
 * 墨色走 `onSurfaceVariantSummary`（弱化文字槽），与时间轴副文本同一档，不写死颜色。
 */
@Composable
private fun EmptySlotAddMarker(
    sectionHeight: Dp,
    span: Int,
    inset: Dp,
    onConfirm: () -> Unit,
    onResizeStart: (isTopEdge: Boolean) -> Unit,
    onResizeBy: (deltaDy: Float) -> Unit,
    onResizeEnd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ink = MiuixTheme.colorScheme.onSurfaceVariantSummary
    val shape = RoundedCornerShape(12.dp)
    // 单节框很矮时按 1/3 高收窄把手，避免两条把手吃掉整个点击区（Dart 同口径）。
    val handleHeight = ((sectionHeight * span.toFloat()) / 3f).coerceIn(8.dp, 16.dp)
    Box(
        modifier = modifier
            .padding(inset)
            .drawBehind {
                drawRoundRect(color = ink.copy(alpha = 0.08f))
                drawRoundRect(
                    color = ink.copy(alpha = 0.55f),
                    style = Stroke(
                        width = 1.5.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(
                            intervals = floatArrayOf(4.dp.toPx(), 3.5.dp.toPx()),
                        ),
                    ),
                    cornerRadius = CornerRadius(12.dp.toPx()),
                )
            }
            .clip(shape)
            .clickable(onClick = onConfirm),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Add,
            contentDescription = null,
            tint = ink,
            modifier = Modifier.size((sectionHeight * 0.3f).coerceIn(16.dp, 26.dp)),
        )
        ResizeHandle(
            isTopEdge = true,
            handleHeight = handleHeight,
            ink = ink,
            onResizeStart = onResizeStart,
            onResizeBy = onResizeBy,
            onResizeEnd = onResizeEnd,
        )
        ResizeHandle(
            isTopEdge = false,
            handleHeight = handleHeight,
            ink = ink,
            onResizeStart = onResizeStart,
            onResizeBy = onResizeBy,
            onResizeEnd = onResizeEnd,
        )
    }
}

/**
 * 标记框上/下边缘的纵拖把手（Dart `_buildResizeHandle`）：细杠只是视觉提示，
 * 整条把手区域都收拖动；点它由外层标记的 `clickable` 兜住（内层不吞 up）。
 */
@Composable
private fun BoxScope.ResizeHandle(
    isTopEdge: Boolean,
    handleHeight: Dp,
    ink: Color,
    onResizeStart: (isTopEdge: Boolean) -> Unit,
    onResizeBy: (deltaDy: Float) -> Unit,
    onResizeEnd: () -> Unit,
) {
    Box(
        modifier = Modifier
            .align(if (isTopEdge) Alignment.TopCenter else Alignment.BottomCenter)
            .fillMaxWidth()
            .height(handleHeight)
            .pointerInput(isTopEdge) {
                detectVerticalDragGestures(
                    onDragStart = { onResizeStart(isTopEdge) },
                    onVerticalDrag = { change, dragAmount ->
                        change.consume()
                        onResizeBy(dragAmount)
                    },
                    onDragEnd = { onResizeEnd() },
                    onDragCancel = { onResizeEnd() },
                )
            },
        contentAlignment = if (isTopEdge) Alignment.TopCenter else Alignment.BottomCenter,
    ) {
        Box(
            modifier = Modifier
                .padding(
                    top = if (isTopEdge) 4.dp else 0.dp,
                    bottom = if (isTopEdge) 0.dp else 4.dp,
                )
                .width(26.dp)
                .height(3.dp)
                .clip(RoundedCornerShape(1.5.dp))
                .background(ink.copy(alpha = 0.75f)),
        )
    }
}
