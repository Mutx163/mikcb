package com.mutx163.qingyu.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 天气聚合逻辑（Dart `lib/domain/weather_logic.dart` 的移植）。
 *
 * 期望值来源：[Dart推演] 对照 Dart 实现语义手推 + [Dart抄录] 关键数值。
 */
class WeatherLogicTest {

    private val day = LocalDateTime.of(2026, 10, 28, 0, 0)

    private fun forecastOf(points: List<HourlyWeatherPoint>): WeatherForecast =
        WeatherForecast(30.29, 120.16, LocalDateTime.of(2026, 10, 28, 7, 0), points)

    private fun point(
        hour: Int,
        temperature: Double? = 20.0,
        probability: Int? = null,
        precipitationMm: Double? = null,
        snowfallCm: Double? = null,
        weatherCode: Int? = null,
    ): HourlyWeatherPoint = HourlyWeatherPoint(
        time = LocalDateTime.of(2026, 10, 28, hour, 0),
        temperatureC = temperature,
        precipitationProbability = probability,
        precipitationMm = precipitationMm,
        snowfallCm = snowfallCm,
        weatherCode = weatherCode,
    )

    // ---------- WMO 码映射 ----------

    @Test
    fun wmo_maps_known_codes() {
        assertEquals(WeatherCategory.CLEAR, weatherCategoryFromWmo(0))
        assertEquals(WeatherCategory.PARTLY_CLOUDY, weatherCategoryFromWmo(2))
        assertEquals(WeatherCategory.FOG, weatherCategoryFromWmo(45))
        assertEquals(WeatherCategory.LIGHT_RAIN, weatherCategoryFromWmo(61))
        assertEquals(WeatherCategory.RAIN, weatherCategoryFromWmo(63))
        assertEquals(WeatherCategory.LIGHT_SNOW, weatherCategoryFromWmo(71))
        assertEquals(WeatherCategory.THUNDERSTORM, weatherCategoryFromWmo(95))
        assertEquals(WeatherCategory.THUNDERSTORM_HAIL, weatherCategoryFromWmo(99))
    }

    @Test
    fun wmo_unknown_code_falls_back_to_clear() {
        assertEquals(WeatherCategory.CLEAR, weatherCategoryFromWmo(12345))
    }

    @Test
    fun severity_is_ordered() {
        assertTrue(
            weatherCategorySeverity(WeatherCategory.THUNDERSTORM_HAIL) >
                weatherCategorySeverity(WeatherCategory.RAIN),
        )
        assertTrue(
            weatherCategorySeverity(WeatherCategory.RAIN) >
                weatherCategorySeverity(WeatherCategory.CLEAR),
        )
        assertEquals(0, weatherCategorySeverity(WeatherCategory.CLEAR))
    }

    @Test
    fun rain_and_snow_families() {
        assertTrue(weatherCategoryIsRain(WeatherCategory.FREEZING_RAIN))
        assertTrue(weatherCategoryIsSnow(WeatherCategory.SNOW_SHOWERS))
        // 冻雨不算雪：它是雨落地结冰。
        assertFalse(weatherCategoryIsSnow(WeatherCategory.FREEZING_RAIN))
        assertFalse(weatherCategoryIsRain(WeatherCategory.CLEAR))
    }

    // ---------- combineDateAndTime ----------

    @Test
    fun combine_date_and_time_valid() {
        assertEquals(
            LocalDateTime.of(2026, 10, 28, 8, 30),
            combineDateAndTime(day, "08:30"),
        )
    }

    @Test
    fun combine_date_and_time_invalid_returns_null() {
        assertNull(combineDateAndTime(day, "bad"))
        assertNull(combineDateAndTime(day, "24:00"))
        assertNull(combineDateAndTime(day, "08"))
    }

    // ---------- 聚合覆盖 + 代表现象 ----------

    @Test
    fun summarize_picks_worst_phenomenon_and_averages_temperature() {
        // 08:00-09:35 的课：命中 09:00、10:00 两个桶（08:00 桶覆盖 07~08，被左开排除）。
        val forecast = forecastOf(
            listOf(
                point(7, temperature = 18.0, weatherCode = 0),
                point(8, temperature = 19.0, weatherCode = 0),
                point(9, temperature = 20.4, probability = 80, weatherCode = 61),
                point(10, temperature = 21.6, probability = 60, weatherCode = 63),
                point(11, temperature = 22.0, weatherCode = 0),
            ),
        )
        val summary = summarizeCourseWeather(
            forecast,
            LocalDateTime.of(2026, 10, 28, 8, 0),
            LocalDateTime.of(2026, 10, 28, 9, 35),
        )!!
        assertEquals(2, summary.hourCount)
        assertEquals(WeatherCategory.RAIN, summary.category) // 61=小雨、63=中雨，取更恶劣的中雨
        assertEquals(21, summary.temperatureC) // (20.4+21.6)/2 = 21.0
        assertEquals(80, summary.precipitationProbability)
        assertTrue(summary.showPrecipitationProbability)
        assertEquals(63, summary.representativeWmoCode)
    }

    @Test
    fun summarize_snow_wins_over_rain_and_rounds_negative() {
        val forecast = forecastOf(
            listOf(
                point(9, temperature = -1.2, probability = 90, snowfallCm = 0.5, weatherCode = 71),
                point(10, temperature = -1.8, probability = 95, snowfallCm = 1.0, weatherCode = 73),
            ),
        )
        val summary = summarizeCourseWeather(
            forecast,
            LocalDateTime.of(2026, 10, 28, 8, 0),
            LocalDateTime.of(2026, 10, 28, 9, 35),
        )!!
        assertEquals(WeatherCategory.SNOW, summary.category) // 73=中雪 比 71=小雪 更恶劣
        // (-1.2 + -1.8)/2 = -1.5 → Dart round 半远离零 = -2（不是 JVM 的 -1）
        assertEquals(-2, summary.temperatureC)
    }

    @Test
    fun summarize_probability_below_threshold_is_not_shown() {
        val forecast = forecastOf(
            listOf(point(9, temperature = 20.0, probability = 20, weatherCode = 0)),
        )
        val summary = summarizeCourseWeather(
            forecast,
            LocalDateTime.of(2026, 10, 28, 8, 0),
            LocalDateTime.of(2026, 10, 28, 9, 35),
        )!!
        assertEquals(20, summary.precipitationProbability)
        assertFalse(summary.showPrecipitationProbability)
    }

    @Test
    fun summarize_without_temperature_returns_null() {
        val forecast = forecastOf(
            listOf(point(9, temperature = null, weatherCode = 61)),
        )
        assertNull(
            summarizeCourseWeather(
                forecast,
                LocalDateTime.of(2026, 10, 28, 8, 0),
                LocalDateTime.of(2026, 10, 28, 9, 35),
            ),
        )
    }

    @Test
    fun summarize_outside_window_returns_null() {
        // 只有 07:00 的点，全在 [08:00, 09:35] 之外。
        val forecast = forecastOf(listOf(point(7, temperature = 18.0, weatherCode = 0)))
        assertNull(
            summarizeCourseWeather(
                forecast,
                LocalDateTime.of(2026, 10, 28, 8, 0),
                LocalDateTime.of(2026, 10, 28, 9, 35),
            ),
        )
    }

    @Test
    fun summarize_non_positive_interval_returns_null() {
        val forecast = forecastOf(listOf(point(9, temperature = 20.0, weatherCode = 0)))
        assertNull(
            summarizeCourseWeather(
                forecast,
                LocalDateTime.of(2026, 10, 28, 9, 0),
                LocalDateTime.of(2026, 10, 28, 9, 0),
            ),
        )
    }
}
