package com.mutx163.qingyu.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 三处显示面共用的天气行决策（Dart `courseWeatherDisplayFor` 的纯逻辑部分）。 */
class WeatherLineTest {

    private fun summary(
        probability: Int? = null,
        showProbability: Boolean = false,
        temperature: Int = 23,
        category: WeatherCategory = WeatherCategory.LIGHT_RAIN,
    ) = CourseWeatherSummary(
        category = category,
        temperatureC = temperature,
        hourCount = 2,
        precipitationProbability = probability,
        showPrecipitationProbability = showProbability,
        representativeWmoCode = 61,
    )

    @Test
    fun null_summary_returns_null() {
        assertNull(planWeatherLine(null, showPhenomenon = true, showTemperature = true, showProbability = true))
    }

    @Test
    fun all_switches_off_returns_null() {
        assertNull(
            planWeatherLine(
                summary(probability = 80, showProbability = true),
                showPhenomenon = false,
                showTemperature = false,
                showProbability = false,
            ),
        )
    }

    @Test
    fun only_probability_on_but_unusable_returns_null() {
        // 只勾了概率，但这条摘要的概率低于阈值（showProbability=false）→ 整行不画。
        assertNull(
            planWeatherLine(
                summary(probability = 20, showProbability = false),
                showPhenomenon = false,
                showTemperature = false,
                showProbability = true,
            ),
        )
    }

    @Test
    fun only_probability_on_and_usable_renders_probability_icon() {
        val plan = planWeatherLine(
            summary(probability = 80, showProbability = true),
            showPhenomenon = false,
            showTemperature = false,
            showProbability = true,
        )!!
        assertEquals(WeatherIconKind.PROBABILITY, plan.iconKind)
        assertEquals(80, plan.probability)
        assertEquals(false, plan.showPhenomenon)
        assertEquals(false, plan.showTemperature)
    }

    @Test
    fun phenomenon_claims_icon_first() {
        val plan = planWeatherLine(
            summary(probability = 80, showProbability = true),
            showPhenomenon = true,
            showTemperature = true,
            showProbability = true,
        )!!
        assertEquals(WeatherIconKind.PHENOMENON, plan.iconKind)
        assertEquals(WeatherCategory.LIGHT_RAIN, plan.category)
        assertEquals(80, plan.probability)
    }

    @Test
    fun temperature_claims_icon_when_phenomenon_off() {
        val plan = planWeatherLine(
            summary(probability = 80, showProbability = true),
            showPhenomenon = false,
            showTemperature = true,
            showProbability = true,
        )!!
        assertEquals(WeatherIconKind.TEMPERATURE, plan.iconKind)
        assertEquals(23, plan.temperatureC)
    }

    @Test
    fun probability_hidden_when_below_threshold_even_if_flag_on() {
        val plan = planWeatherLine(
            summary(probability = 20, showProbability = false),
            showPhenomenon = true,
            showTemperature = true,
            showProbability = true,
        )!!
        assertNull(plan.probability) // 阈值过滤后不可用 → 不显示
    }

    @Test
    fun compact_prefers_temperature_then_phenomenon_then_probability() {
        val full = planWeatherLine(
            summary(probability = 80, showProbability = true),
            showPhenomenon = true,
            showTemperature = true,
            showProbability = true,
        )!!
        assertEquals("temperature", compactWeatherItem(full))

        val noTemp = planWeatherLine(
            summary(probability = 80, showProbability = true),
            showPhenomenon = true,
            showTemperature = false,
            showProbability = true,
        )!!
        assertEquals("phenomenon", compactWeatherItem(noTemp))

        val probOnly = planWeatherLine(
            summary(probability = 80, showProbability = true),
            showPhenomenon = false,
            showTemperature = false,
            showProbability = true,
        )!!
        assertEquals("probability", compactWeatherItem(probOnly))
    }
}
