package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.timetable.CourseCardInk
import com.mutx163.qingyu.pages.timetable.WeekGridCourseMapping
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Background
import top.yukonga.miuix.kmp.icon.extended.ContactsCircle
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图课程议程卡 · Compose 渲染层。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_course_agenda_card.dart`
 * 与 `day_view_course_agenda_card_variants.dart`：
 * - 未上/普通课程：标准展示卡片（节次、时间、课名、教师、地点、单周备注、状态徽标）；
 * - 进行中课程：带有 600ms 动态进度填充层与「剩余 N 分钟 / 快下课了」胶囊；
 * - 交互入口：右上角记备注、记作业胶囊，点击卡片展开详情与编辑。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DayViewCourseCard(
    entry: DayAgendaEntry.CourseEntry,
    week: Int,
    progress: DayAgendaProgress? = null,
    // 能力型：null ⇒ 该入口不渲染（壳未接线时不画死按钮）
    onTap: (() -> Unit)? = null,
    onOpenNotes: (() -> Unit)? = null,
    onOpenTask: (() -> Unit)? = null,
    hasTask: Boolean = false,
    weatherInfo: String? = null,
    /** 「课卡显示冲突角标」开关（Dart `showConflictBadgeOnTimetable`）。关掉只藏角标，边框仍在。 */
    showConflictBadge: Boolean = true,
    radius: Dp = 16.dp,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。null = 老行为
     * （卡面恒为实体课色）。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 液态档的**整页共享**背景采样源（`DayViewPage` 建好后整页共用）。
     * 非空且生效档为液态时才真采样，否则退回卡色填充（见 [dayAgendaSurface]）。
     */
    glassBackdrop: Backdrop? = null,
    /**
     * 这张卡背后壁纸的**正文带**亮度（`DayViewPage` 一次采好逐卡下传）。
     * 玻璃 / 半透明档拿它算卡面有效亮度来定墨色；null = 没壁纸 / 还没采到 ⇒ 主题口径。
     */
    wallpaperLuminance: Double? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val rawColor = parseHexColorOrFallback(entry.course.color, fallback = Color(0xFF2196F3))
    val isSuspended = entry.course.isSuspendedInWeek(week)
    // 非本周灰改用域内唯一 token（Dart `kNonCurrentWeekCourseColorHex`），不再写第二份字面量。
    val baseCardColor = if (!entry.isCurrentWeekCourse) {
        parseHexColorOrFallback(WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX)
    } else {
        rawColor
    }
    val cardAlpha = if (isSuspended) 0.84f else if (!entry.isCurrentWeekCourse) 0.62f else 1f
    // 卡面档位（实体 / 高斯降级 / 液态染色）与周网格课卡同一条口径，见 [dayAgendaSurfaceAlpha]。
    val cardColor = baseCardColor.copy(
        alpha = dayAgendaSurfaceAlpha(material, cardAlpha).coerceIn(0.08f, 1f),
    )
    val glass = dayAgendaGlassBackdrop(material, glassBackdrop)
    // 墨色（2026-11-07）：玻璃 / 半透明档按**卡面实际呈现的亮度**翻黑白
    // （卡色 × 染色强度 + 背后壁纸 × 其余），参考历史实现的 `dayAgendaAutoInk`；
    // 实色档 / 亮度未知时按卡色自身的 WCAG 亮度择优（[CourseCardInk.bestContrastInk]）。
    // 旧实现在任何档位都只按**不透明卡色**判 —— 深树壁纸上的近透明卡因此拿到深字。
    val ink = Color(
        CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = baseCardColor.toArgb(),
            fillAlpha = cardColor.alpha,
            wallpaperLuminance = wallpaperLuminance,
            showsWallpaper = glass != null || cardColor.alpha < 1f,
            // 实心档（不露壁纸）：按**卡色自身的 WCAG 亮度**在白 / 近黑里择优，
            // 不再走 calculateCardInk 那套 gamma 0.55 阈值（#808080 会判成白字）。
            fallbackArgb = CourseCardInk.bestContrastInk(baseCardColor.toArgb()),
        ),
    )

    val shape = RoundedCornerShape(radius)
    val borderModifier = if (entry.isConflicting) {
        Modifier.border(1.5.dp, Color(QingyuTheme.error(dark)).copy(alpha = 0.4f), shape)
    } else {
        Modifier
    }

    // 2141 简单面板：不再有逐卡飞行；保留空修饰器占位，避免大改每行文字调用点。
    @Suppress("UNUSED_PARAMETER")
    fun flightAnchor(
        lineId: String,
        text: String,
        fontSizeSp: Float,
        weight: FontWeight,
        anchorInk: Color,
        maxLines: Int = 1,
        lineHeightSp: Float = 0f,
    ): Modifier = Modifier
    val nameFontSize = MiuixTheme.textStyles.main.fontSize.value
    val infoFontSize = MiuixTheme.textStyles.footnote1.fontSize.value
    val chipFontSize = MiuixTheme.textStyles.footnote2.fontSize.value

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .dayAgendaSurface(
                glassBackdrop = glass,
                shape = shape,
                fill = cardColor,
                material = material,
            )
            .then(borderModifier)
            .then(if (onTap != null) Modifier.clickable(onClick = onTap) else Modifier),
    ) {
        // 进行中状态 600ms 动态进度背景填充
        if (progress != null) {
            val animatedProgress by animateFloatAsState(
                targetValue = progress.quantizedProgress.toFloat().coerceIn(0f, 1f),
                animationSpec = tween(durationMillis = 600, easing = LinearOutSlowInEasing),
                label = "CourseCardProgress",
            )
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .fillMaxWidth(animatedProgress)
                    .background(ink.copy(alpha = 0.14f)),
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 14.dp, top = 12.dp, end = 12.dp, bottom = 12.dp),
        ) {
            // 顶栏：时间胶囊 + 状态徽标 + 右侧操作按钮
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                // 左侧胶囊与徽标组
                FlowRow(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    // 时间胶囊
                    Box(
                        modifier = Modifier
                            .background(dayAgendaInkWash(ink, 0.18f), RoundedCornerShape(8.dp))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = MiuixIcons.Alarm,
                                contentDescription = null,
                                modifier = Modifier.size(12.dp),
                                tint = ink,
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            val timeLabel = "${entry.course.startTime} - ${entry.course.endTime}"
                            Text(
                                text = timeLabel,
                                style = MiuixTheme.textStyles.footnote2,
                                color = ink,
                                modifier = flightAnchor(
                                    "time",
                                    timeLabel,
                                    chipFontSize,
                                    FontWeight.Normal,
                                    ink,
                                ),
                            )
                        }
                    }

                    // 进行中状态徽标
                    if (entry.isCurrentCourse || progress != null) {
                        val statusText = if (progress != null) {
                            if (progress.isEndingSoon) {
                                DayViewStrings.dayAgendaEndingSoonStatus(progress.remainingMinutes)
                            } else {
                                DayViewStrings.dayAgendaInProgressStatus(progress.remainingMinutes)
                            }
                        } else {
                            DayViewStrings.ongoingCourseBadge.zh
                        }
                        DayAgendaBadge(
                            text = statusText,
                            textColor = ink,
                            backgroundColor = Color.White.copy(alpha = 0.22f),
                            weightDelta = QingyuWeightDelta.MEDIUM,
                        )
                    }

                    // 冲突徽标（Dart `buildDayCourseDisplayItems` 的 `showConflictBadge` 开关；
                    // 关掉只藏角标，冲突边框仍保留）
                    if (entry.isConflicting && showConflictBadge) {
                        DayAgendaBadge(
                            text = DayViewStrings.conflictLabel.zh,
                            textColor = Color.White,
                            backgroundColor = Color(QingyuTheme.error(dark)),
                        )
                    }

                    // 对方课程（情侣）徽标
                    if (entry.isPartnerCourse) {
                        DayAgendaBadge(
                            text = DayViewStrings.coupleTimetableLegendPartner.zh,
                            textColor = Color.White,
                            backgroundColor = Color(0xFFE91E63),
                        )
                    }

                    // 非本周徽标
                    if (!entry.isCurrentWeekCourse) {
                        DayAgendaBadge(
                            text = DayViewStrings.nonCurrentWeekLabel.zh,
                            textColor = ink,
                            backgroundColor = Color.White.copy(alpha = 0.14f),
                        )
                    }

                    // 停课徽标
                    if (isSuspended) {
                        DayAgendaBadge(
                            text = DayViewStrings.suspendedBadgeLabel.zh,
                            textColor = Color.White,
                            backgroundColor = Color(0xFFD32F2F),
                        )
                    }

                    // 本周有作业指示红点
                    if (entry.course.hasHomeworkInWeek(week)) {
                        DayAgendaHomeworkDot()
                    }
                }

                Spacer(modifier = Modifier.width(6.dp))

                // 右侧操作：记作业与备注。
                // 壳没接线（回调为 null）时**整块不渲染**——审核 P0-1 就是这两个胶囊
                // 画在屏上、点下去什么都不发生。
                if (onOpenTask != null || onOpenNotes != null) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (onOpenTask != null) {
                            DayAgendaTaskAction(
                                ink = ink,
                                onPressed = onOpenTask,
                                hasTask = hasTask,
                            )
                        }
                        if (onOpenTask != null && onOpenNotes != null) {
                            Spacer(modifier = Modifier.width(5.dp))
                        }
                        if (onOpenNotes != null) {
                            DayAgendaNoteAction(
                                ink = ink,
                                onPressed = onOpenNotes,
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // 课程名称
            Text(
                text = entry.course.name,
                style = MiuixTheme.textStyles.main,
                color = ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 22.sp,
                modifier = flightAnchor(
                    "name",
                    entry.course.name,
                    nameFontSize,
                    MiuixTheme.textStyles.main.fontWeight ?: FontWeight.Normal,
                    ink,
                    maxLines = 2,
                    lineHeightSp = 22f,
                ),
            )

            Spacer(modifier = Modifier.height(8.dp))

            // 教师与节次
            val teacher = entry.course.teacher.trim().ifEmpty { DayViewStrings.unknownTeacher.zh }
            val section = DayViewStrings.sectionRangeLabel(entry.course.startSection, entry.course.endSection)
            val teacherLabel = "${DayViewStrings.teacherPrefix(teacher)} · $section"
            DayAgendaInfoRow(
                icon = MiuixIcons.ContactsCircle,
                text = teacherLabel,
                ink = ink,
                textModifier = flightAnchor(
                    "teacher",
                    teacherLabel,
                    infoFontSize,
                    FontWeight.Normal,
                    ink.copy(alpha = 0.85f),
                ),
            )

            // 地点
            val location = entry.course.location.trim().ifEmpty { DayViewStrings.unknownLocation.zh }
            val locationLabel = DayViewStrings.locationPrefix(location)
            Spacer(modifier = Modifier.height(4.dp))
            DayAgendaInfoRow(
                icon = MiuixIcons.Location,
                text = locationLabel,
                ink = ink,
                textModifier = flightAnchor(
                    "location",
                    locationLabel,
                    infoFontSize,
                    FontWeight.Normal,
                    ink.copy(alpha = 0.85f),
                ),
            )

            // 天气
            if (!weatherInfo.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                DayAgendaInfoRow(
                    icon = MiuixIcons.Background,
                    text = weatherInfo,
                    ink = ink,
                    textModifier = flightAnchor(
                        "weather",
                        weatherInfo,
                        infoFontSize,
                        FontWeight.Normal,
                        ink.copy(alpha = 0.85f),
                    ),
                )
            }

            // 单周备注预览
            val sessionNote = entry.course.sessionNoteForWeek(week)?.trimmedText
            if (!sessionNote.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                DayAgendaInfoRow(
                    icon = MiuixIcons.Notes,
                    text = sessionNote,
                    ink = ink,
                    textModifier = flightAnchor(
                        "note",
                        sessionNote,
                        infoFontSize,
                        FontWeight.Normal,
                        ink.copy(alpha = 0.85f),
                    ),
                )
            }
        }
    }
}
