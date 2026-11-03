package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.timetable.TimetableStrings
import com.mutx163.qingyu.weather.WeatherCategoryLocalizer
import com.mutx163.qingyu.weather.WeatherProvider
import java.time.LocalDate

/**
 * 日视图课卡「天气一行」的取数（模型层胶水）。
 *
 * Dart 对位：`lib/widgets/timetable/day_view/day_course_weather_row.dart`
 * ——日课卡在时间胶囊下方多一行天气（现象 / 温度 / 降水概率三档由设置控制）。
 *
 * 2026-10-29 二轮审核：Compose 的 `DayViewCourseCard.weatherInfo` 参数**从来没有调用方**
 *（`DayViewScrollContent` 不传），所以日视图天气行永不出现。
 *
 * 把「provider + 设置」→「(日期, 课程) → 一行文本」的绑定收敛在这里，
 * 壳里只要一行调用，不必自己拼文案（文案模板在 `TimetableStrings.formatWeatherLine`）。
 */
object DayViewWeather {

    /**
     * 构造日卡天气取数器；不该出现天气行时返回 null（调用方据此不渲染）。
     *
     * @param settingsModel 用户设置（`weatherShowOnDayCard` 为主开关，另有三档细分开关）
     * @param provider 设备级天气 provider（只在壳里有；null = 天气功能未接）
     */
    fun lineProvider(
        settingsModel: TimetableSettingsModel?,
        provider: WeatherProvider?,
    ): ((date: LocalDate?, course: Course) -> String?)? {
        if (provider == null) return null
        if (settingsModel?.weatherShowOnDayCard == false) return null
        val showPhenomenon = settingsModel?.weatherShowPhenomenon ?: true
        val showTemperature = settingsModel?.weatherShowTemperature ?: true
        val showProbability = settingsModel?.weatherShowProbability ?: false
        return { date, course ->
            if (date == null) {
                null
            } else {
                provider.summaryForCourse(date.atStartOfDay(), course.startTime, course.endTime)
                    ?.let { summary ->
                        TimetableStrings.formatWeatherLine(
                            phenomenon = WeatherCategoryLocalizer.label(summary.category),
                            temperatureC = summary.temperatureC,
                            probability = summary.precipitationProbability,
                            showPhenomenon = showPhenomenon,
                            showTemperature = showTemperature,
                            showProbability = showProbability,
                        )
                    }
            }
        }
    }
}