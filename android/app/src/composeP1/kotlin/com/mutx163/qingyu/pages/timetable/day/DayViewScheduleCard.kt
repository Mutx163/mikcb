package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图日程议程卡 · Compose 渲染层。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_schedule_agenda_card.dart`：
 * - 顶栏：起止时间胶囊 + 日程徽标 + 跨天徽标（若跨天展示）；
 * - 标题：日程主题文字；
 * - 详情：地点信息（若有）、备注说明（若有）；
 * - 动态态：若处于进行中，展示 600ms 动态进度填充条与「剩余 N 分钟 / 即将结束」胶囊。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DayViewScheduleCard(
    entry: DayAgendaEntry.ScheduleEntry,
    progress: DayAgendaProgress? = null,
    onTap: (() -> Unit)? = null,
    radius: Dp = 16.dp,
    /** 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为（实体日程色）。 */
    material: HomeMaterialRenderSpec? = null,
    /** 液态档的整页共享背景采样源（见 [dayAgendaSurface]）。 */
    glassBackdrop: Backdrop? = null,
    modifier: Modifier = Modifier,
) {
    // 日程色是用户数据色；缺省/解析失败时退回主题 primary（不写死字面量，R5）。
    val baseColor = parseHexColorOrFallback(entry.scheduleItem.color, fallback = MiuixTheme.colorScheme.primary)
    // 卡面档位与周网格课卡同一条口径（见 [dayAgendaSurfaceAlpha]）：实体 0.95、
    // 高斯降级 0.55×、液态走卡片自己的染色旋钮。
    val cardColor = baseColor.copy(
        alpha = dayAgendaSurfaceAlpha(material, 0.95f).coerceIn(0.08f, 1f),
    )
    val ink = calculateCardInk(baseColor)
    val shape = RoundedCornerShape(radius)
    // 跨日徽标只看**这一次发生**的区间：Dart 用物化后的 `effectiveItem`
    //（`timetable_day_agenda_models.dart:84-93`，重复日程物化成当天起止），所以
    // 重复系列本身跨月并不等于这一次跨日。`continuesFrom/To` 正是按目标日算出来的。
    val isCrossDay = entry.continuesFromPreviousDay || entry.continuesToNextDay

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .dayAgendaSurface(
                glassBackdrop = dayAgendaGlassBackdrop(material, glassBackdrop),
                shape = shape,
                fill = cardColor,
                material = material,
            )
            .then(if (onTap != null) Modifier.clickable(onClick = onTap) else Modifier),
    ) {
        // 进行中状态 600ms 动态进度背景填充
        if (progress != null) {
            val animatedProgress by animateFloatAsState(
                targetValue = progress.quantizedProgress.toFloat().coerceIn(0f, 1f),
                animationSpec = tween(durationMillis = 600, easing = LinearOutSlowInEasing),
                label = "ScheduleCardProgress",
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
                .padding(start = 14.dp, top = 12.dp, end = 14.dp, bottom = 12.dp),
        ) {
            // 顶栏：时间胶囊与徽标组
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
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
                        Text(
                            text = "${entry.startTime} - ${entry.endTime}",
                            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = ink,
                        )
                    }
                }

                // 日程徽标
                DayAgendaBadge(
                    text = DayViewStrings.scheduleBadgeLabel.zh,
                    textColor = ink,
                    backgroundColor = dayAgendaInkWash(ink, 0.18f),
                )

                // 跨日徽标
                if (isCrossDay) {
                    DayAgendaBadge(
                        text = DayViewStrings.crossDayBadgeLabel.zh,
                        textColor = ink,
                        backgroundColor = dayAgendaInkWash(ink, 0.18f),
                    )
                }

                // 进行中状态徽标
                if (progress != null) {
                    val statusText = if (progress.isEndingSoon) {
                        DayViewStrings.scheduleAgendaEndingSoonStatus(progress.remainingMinutes)
                    } else {
                        DayViewStrings.scheduleAgendaInProgressStatus(progress.remainingMinutes)
                    }
                    DayAgendaBadge(
                        text = statusText,
                        textColor = ink,
                        backgroundColor = Color.White.copy(alpha = 0.22f),
                        weightDelta = QingyuWeightDelta.MEDIUM,
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // 日程标题
            Text(
                text = entry.scheduleItem.title,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.BOLD),
                color = ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 22.sp,
            )

            // 地点
            entry.scheduleItem.location?.takeIf { it.isNotBlank() }?.let { loc ->
                Spacer(modifier = Modifier.height(8.dp))
                DayAgendaInfoRow(
                    icon = MiuixIcons.Location,
                    text = DayViewStrings.locationPrefix(loc.trim()),
                    ink = ink,
                )
            }

            // 备注
            entry.scheduleItem.note?.takeIf { it.isNotBlank() }?.let { noteText ->
                Spacer(modifier = Modifier.height(4.dp))
                DayAgendaInfoRow(
                    icon = MiuixIcons.Notes,
                    text = noteText.trim(),
                    ink = ink,
                )
            }
        }
    }
}
