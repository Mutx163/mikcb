package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.CourseActionStrings
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.core.ClassAlarmEvent
import com.mutx163.qingyu.core.ClassAlarmPlan
import com.mutx163.qingyu.core.ClassAlarmPlanLogic
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.exam.ExamTimePickerSheet
import com.mutx163.qingyu.theme.QingyuTheme
import java.time.LocalDate
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「这节课闹钟」子弹层（Dart `lib/widgets/class_reminder_sheet.dart`）。
 *
 * ## 写入走系统时钟
 *
 * 三个动作全部落在系统时钟 App 上：快捷响点（开始 − 提前量）、自定义时间（miuix
 * 双列滚轮，复用考试页的 [ExamTimePickerSheet]）、打开系统时钟列表。确认后经
 * [ClassAlarmEvent.SetSystemAlarm] 抛给宿主，由宿主调 `SystemAlarmHelper.fireSetAlarm`
 * （`AlarmClock.ACTION_SET_ALARM`）并弹 toast——**本层不起 Intent**。
 *
 * ## 与 Dart 的两处已知差异（诚实清单）
 *
 * 1. Dart 成功打开系统时钟后**先收起本弹层**、失败留在原地；这里统一「点了就收」，
 *    失败由宿主 toast 说明——宿主无法把启动结果同步回弹层，与其等一个假的同步点，
 *    不如让用户从入口行重开（入口行的出现判据不受影响）。
 * 2. 「已设提醒：HH:mm / 取消」读旧版一次性本地通知条目（`timetable_settings.classReminders`，
 *    Dart `:259-281` / `:329-337`）。渲染侧已就位：响点由宿主经 [existingReminderMinuteOfDay]
 *    传入、移除回调经 [onRemoveReminder] 抛回——**任一未接（默认 null）整块不渲染**，
 *    与课卡铃铛同一条「拿不到就不亮」口径，不画点不掉的假入口。缺口只剩宿主接线：
 *    读侧（`classReminders` 按 course+日期匹配）与写侧（`ClassReminderLogic.remove` +
 *    `TimetableStore.saveSettingsPatch` 落盘、`classAlarmRemovedToast`、成功才收弹层）。
 *
 * 确认文案的星期跟随**真实响点**（提前量把响点挪过午夜时是前一天，Dart `:117-125`）。
 *
 * @param resolvedStartTime 生效作息下这一节的开始钟点 `HH:mm`（判据已保证非 null 才开）。
 * @param courseDate 这节课在本周的真实日期（信息行用；null 只影响信息行首段）。
 * @param leadMinutes 提前量（宿主从设置读，[ClassAlarmPlanLogic.leadMinutesFromSettings]）。
 * @param skipUi 是否跳过系统时钟保存页（[ClassAlarmPlanLogic.skipUiFromSettings]）。
 * @param existingReminderMinuteOfDay 旧版一次性提醒的响点（当日分钟数）；null = 不画已设块。
 * @param onRemoveReminder 移除回调；null = 不画取消入口。只删旧条目，不动系统时钟闹钟
 *   （Dart `_removeLegacyReminder` 同口径）；持久化、toast 与是否收弹层归宿主。
 */
@Composable
fun ClassAlarmSheet(
    show: Boolean,
    course: Course?,
    resolvedStartTime: String?,
    courseDate: LocalDate?,
    leadMinutes: Int,
    skipUi: Boolean,
    existingReminderMinuteOfDay: Int? = null,
    onRemoveReminder: (() -> Unit)? = null,
    onEvent: (ClassAlarmEvent) -> Unit,
    onDismiss: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val secondaryText = Color(QingyuTheme.secondaryText(dark))

    // Dart `_working` + `_addSystemAlarm` 的中间态：待确认的计划与用户选的响点（分钟）。
    var pendingConfirm by remember(show, course?.id) { mutableStateOf<Pair<ClassAlarmPlan, Int>?>(null) }
    var pickerShow by remember(show, course?.id) { mutableStateOf(false) }

    QingyuSheet(
        show = show,
        title = CourseActionStrings.classAlarmActionLabel.zh,
        onDismissRequest = onDismiss,
    ) {
        if (course == null || resolvedStartTime == null) return@QingyuSheet
        val startMinutes = ClassAlarmPlanLogic.parseClockMinutes(resolvedStartTime)
        val lead = ClassAlarmPlanLogic.clampLeadMinutes(leadMinutes)
        val courseLabel = course.shortName?.trim().takeUnless { it.isNullOrEmpty() }
            ?: course.name.trim()

        Column(modifier = Modifier.fillMaxWidth()) {
            // 信息行（Dart `:241-257`）：`10月10日 · 星期五 · 08:00`；钟点解析不出就不画钟点。
            val infoParts = buildList {
                courseDate?.let { add(CourseActionSheetStrings.dateLabel(it.monthValue, it.dayOfMonth)) }
                add(CourseActionSheetStrings.weekdayLabel(course.dayOfWeek))
                if (startMinutes != null) add(ClassAlarmPlanLogic.formatClock(startMinutes))
            }
            Text(
                text = infoParts.joinToString(" · "),
                style = MiuixTheme.textStyles.footnote2,
                color = secondaryText,
                maxLines = 1,
            )
            Spacer(modifier = Modifier.height(12.dp))

            // 已设提醒（Dart `:259-281`）：旧版一次性本地通知条目，宿主传了响点才画；
            // 新写入的系统时钟重复闹钟不受取消影响（Dart `_removeLegacyReminder` 注释同口径）。
            existingReminderMinuteOfDay?.let { minute ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = MiuixIcons.Alarm,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = Color(QingyuTheme.primary(dark = dark)),
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = CourseActionStrings.classAlarmExistingText(
                            ClassAlarmPlanLogic.formatClock(minute),
                        ),
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            // 快捷响点（Dart `:282-288`）：开始 − 提前量；越过午夜时交给计划的响点日。
            // 钟点解析不出时按 Dart 置灰（`:285` `onPressed: startMinutes == null ? null : …`）。
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = CourseActionStrings.classAlarmQuickLabel(lead),
                enabled = startMinutes != null,
                onClick = {
                    val picked = startMinutes!! - lead
                    val plan = ClassAlarmPlanLogic.planForPickedMinute(
                        minuteOfDay = picked,
                        course = course,
                        resolvedStartTime = resolvedStartTime,
                        label = courseLabel,
                        leadMinutes = lead,
                        skipUi = skipUi,
                    ) ?: return@TextButton
                    pendingConfirm = plan to picked
                },
            )
            Spacer(modifier = Modifier.height(8.dp))

            // 自定义时间（Dart `:290-307`）：先滚轮，再走同一条确认链。
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = CourseActionStrings.classAlarmCustomOption.zh,
                enabled = startMinutes != null,
                onClick = { pickerShow = true },
            )
            Spacer(modifier = Modifier.height(8.dp))

            // 打开系统时钟（Dart `:309-328`）。
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = CourseActionStrings.classAlarmOpenClock.zh,
                onClick = {
                    onEvent(ClassAlarmEvent.OpenSystemClock)
                    onDismiss()
                },
            )

            // 取消旧提醒（Dart `:329-337` destructive「取消」）：已设块在、写侧回调也接了才画。
            // 点击后**不自行收起**——持久化在宿主：成功才收弹层 + toast（Dart 成功才 pop）。
            if (existingReminderMinuteOfDay != null && onRemoveReminder != null) {
                Spacer(modifier = Modifier.height(8.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = CourseActionStrings.cancelAction.zh,
                    colors = ButtonDefaults.textButtonColors(
                        textColor = Color(QingyuTheme.destructive()),
                    ),
                    onClick = { onRemoveReminder?.invoke() },
                )
            }
        }
    }

    // 自定义时间选择（复用考试页的 miuix 双列滚轮；初值 = 当前开始钟点，Dart `:296-303`）。
    if (course != null && resolvedStartTime != null) {
        ExamTimePickerSheet(
            show = pickerShow,
            title = CourseActionStrings.selectTimeTitle.zh,
            initial = resolvedStartTime,
            onPick = { picked ->
                pickerShow = false
                val pickedMinutes = ClassAlarmPlanLogic.parseClockMinutes(picked) ?: return@ExamTimePickerSheet
                val plan = ClassAlarmPlanLogic.planForPickedMinute(
                    minuteOfDay = pickedMinutes,
                    course = course,
                    resolvedStartTime = resolvedStartTime,
                    label = course.shortName?.trim().takeUnless { it.isNullOrEmpty() }
                        ?: course.name.trim(),
                    leadMinutes = ClassAlarmPlanLogic.clampLeadMinutes(leadMinutes),
                    skipUi = skipUi,
                ) ?: return@ExamTimePickerSheet
                pendingConfirm = plan to pickedMinutes
            },
            onDismiss = { pickerShow = false },
        )
    }

    // 确认弹层（Dart `:142-152` `showAppConfirmDialogWithBody`）：星期跟随真实响点。
    val confirm = pendingConfirm
    if (confirm != null) {
        val (plan, pickedMinute) = confirm
        val ringIso = plan.repeatDays.firstOrNull()
            ?.let { ClassAlarmPlanLogic.isoWeekdayFromCalendar(it) }
            ?.takeIf { it != 0 }
            ?: course?.dayOfWeek
            ?: 1
        val startMinutesForLead = resolvedStartTime?.let { ClassAlarmPlanLogic.parseClockMinutes(it) }
        val lead = ClassAlarmPlanLogic.clampLeadMinutes(leadMinutes)
        val effectiveLead = if (startMinutesForLead == null) {
            lead
        } else {
            ClassAlarmPlanLogic.effectiveLead(pickedMinute, startMinutesForLead, lead)
        }
        OverlayDialog(
            show = true,
            title = CourseActionStrings.classAlarmCourseConfirmTitle.zh,
            summary = CourseActionStrings.classAlarmConfirmMessage(
                weekday = CourseActionSheetStrings.weekdayLabel(ringIso),
                time = ClassAlarmPlanLogic.formatClock(plan.hour * 60 + plan.minute),
                lead = effectiveLead,
                weeks = course?.let { ClassAlarmPlanLogic.weeksSummary(it) } ?: "—",
            ),
            onDismissRequest = { pendingConfirm = null },
        ) {
            Row(modifier = Modifier.fillMaxWidth()) {
                TextButton(
                    text = CourseActionStrings.cancelAction.zh,
                    onClick = { pendingConfirm = null },
                    modifier = Modifier.weight(1f),
                )
                Spacer(modifier = Modifier.width(10.dp))
                Button(
                    onClick = {
                        pendingConfirm = null
                        onEvent(
                            ClassAlarmEvent.SetSystemAlarm(
                                hour = plan.hour,
                                minute = plan.minute,
                                courseLabel = plan.label,
                                repeatDays = plan.repeatDays,
                                skipUi = plan.skipUi,
                            ),
                        )
                        onDismiss()
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = CourseActionStrings.confirmAction.zh)
                }
            }
        }
    }
}
