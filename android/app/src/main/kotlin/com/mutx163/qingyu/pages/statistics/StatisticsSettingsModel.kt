package com.mutx163.qingyu.pages.statistics

import java.time.LocalDateTime

/**
 * 周报调度规则。
 *
 * 逐条对齐 Dart `lib/services/weekly_report_service.dart:WeeklyReportService.nextFireAt`：
 * 「从今天起算到最近的周日 21:00；若该时刻不晚于当前时刻，则顺延一周」。
 *
 * Dart 的判据是 `if (!fire.isAfter(current))` —— **恰好等于**也算「已到点」，要顺延；
 * 这里用 `isAfter` 保持同一语义（不是 `>=` 也不是 `>` 的直觉写法）。
 */
object WeeklyReportSchedule {

    /** Dart `_fireHour = 21`：每周日 21:00 推送。 */
    const val FIRE_HOUR: Int = 21

    fun nextFireAt(now: LocalDateTime): LocalDateTime {
        val today = now.toLocalDate()
        // java.time: 周一=1 … 周日=7，与 Dart DateTime.weekday 同口径。
        val daysUntilSunday = (7 - now.dayOfWeek.value + 7) % 7
        var fire = today.plusDays(daysUntilSunday.toLong()).atTime(FIRE_HOUR, 0)
        if (!fire.isAfter(now)) {
            fire = fire.plusDays(7)
        }
        return fire
    }
}

/**
 * 统计页用到的日期 / 时间标签。
 *
 * 口径对齐 Dart 侧的 intl（`DateFormat.MMMd/ yMMMd`，locale = zh）与手写的 `HH:mm`：
 * - `MMMd('zh')` → `M月d日`（不补零）；
 * - `yMMMd('zh')` → `y年M月d日`；
 * - 时刻一律两位补零。
 */
object StatisticsDateLabels {

    fun monthDay(date: LocalDateTime?): String =
        if (date == null) "" else "${date.monthValue}月${date.dayOfMonth}日"

    fun yearMonthDay(date: LocalDateTime?): String =
        if (date == null) "" else "${date.year}年${date.monthValue}月${date.dayOfMonth}日"

    fun clockTime(date: LocalDateTime): String =
        "${date.hour.toString().padStart(2, '0')}:${date.minute.toString().padStart(2, '0')}"
}

/**
 * 统计设置页整页视图状态（对齐 `lib/screens/statistics_settings_screen.dart`）。
 *
 * 屏上只有「一块 + 一行开关」：块头与开关行标题在 Dart 里都用 `weeklyReportTitle`，
 * 这里照抄（`sectionTitle == tileTitle`），不擅自合并。
 */
data class StatisticsSettingsViewState(
    val title: String,
    val sectionTitle: String,
    val tileTitle: String,
    val subtitle: String,
    val isEnabled: Boolean,
    val nextFireAt: LocalDateTime,
)

/**
 * 周报开关「打开」失败：**系统通知根本送不到**（POST_NOTIFICATIONS 未授予 / 应用通知被关 /
 * 周报渠道被调成静默）。
 *
 * 为什么不复用 `IllegalStateException` 让页面去认 message：页面按异常**类型**选一句人话
 * （「去开通知」≠「保存失败」），认字符串就是两处各解析一次，改一个字两边就漂。
 * 也不在不可达时假装成功——留一个「能打开但永远送不到」的开关就是假开关。
 */
class WeeklyReportNotificationUnavailableException(
    message: String = "weekly report notification not deliverable",
) : IllegalStateException(message)

/**
 * 统计设置页的纯逻辑：视图状态装配与操作反馈文案。
 */
object StatisticsSettingsLogic {

    /** 落盘失败提示（ARB `saveFailed`）。 */
    val SAVE_FAILED_MESSAGE: String = StatisticsStrings.saveFailed.text

    /**
     * 开关操作失败时给用户的那一句：
     * - 通知不可达（[WeeklyReportNotificationUnavailableException]）⇒ 告诉用户去开通知；
     * - 其余（落盘 / 调度抛错）⇒ 通用「保存失败」。
     */
    fun failureMessage(error: Throwable): String =
        if (error is WeeklyReportNotificationUnavailableException) {
            StatisticsStrings.weeklyReportPermissionMissing.text
        } else {
            SAVE_FAILED_MESSAGE
        }

    /**
     * 开关副标题：
     * - 开启：`weeklyReportNextFire`（"下次推送 {date} {time}"）；
     * - 关闭：`weeklyReportDisabledHint`。
     */
    fun subtitle(enabled: Boolean, nextFireAt: LocalDateTime): String =
        if (enabled) {
            StatisticsStrings.weeklyReportNextFire.filled(
                "date" to StatisticsDateLabels.monthDay(nextFireAt),
                "time" to StatisticsDateLabels.clockTime(nextFireAt),
            )
        } else {
            StatisticsStrings.weeklyReportDisabledHint.text
        }

    /** 切换成功后的提示：开 → `weeklyReportEnabledHint`，关 → `weeklyReportDisabledHint`。 */
    fun toggleResultMessage(enabled: Boolean): String =
        if (enabled) {
            StatisticsStrings.weeklyReportEnabledHint.text
        } else {
            StatisticsStrings.weeklyReportDisabledHint.text
        }

    /**
     * 装配整页视图状态。
     *
     * 下次推送时刻在 Dart 里每次 build 都重算（`WeeklyReportService.nextFireAt()` 不传
     * `now`，取的是真实当前时间）；这里把 `now` 作为显式入参，便于测试固定时钟。
     */
    fun buildViewState(
        weeklyReportEnabled: Boolean,
        now: LocalDateTime,
    ): StatisticsSettingsViewState {
        val nextFireAt = WeeklyReportSchedule.nextFireAt(now)
        return StatisticsSettingsViewState(
            title = StatisticsStrings.statisticsSettingsTitle.text,
            sectionTitle = StatisticsStrings.weeklyReportTitle.text,
            tileTitle = StatisticsStrings.weeklyReportTitle.text,
            subtitle = subtitle(weeklyReportEnabled, nextFireAt),
            isEnabled = weeklyReportEnabled,
            nextFireAt = nextFireAt,
        )
    }
}
