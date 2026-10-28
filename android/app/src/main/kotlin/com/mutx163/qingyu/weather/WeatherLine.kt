package com.mutx163.qingyu.weather

/**
 * 天气行「该不该画、画哪几项、图标由谁认领」的纯决策（Dart `course_weather_display.dart` 去掉 UI 部分）。
 *
 * 三处显示面（日卡 / 周卡 / 课程详情弹窗）共用这一份判定，避免「有没有天气行」的规则在三个地方各写一遍。
 * 真正的图标与本地化文案在界面层做——本文件不依赖 Compose / Android，可进 JVM 单测。
 *
 * ## 「认领」原则
 *
 * 这一行画出来的每一样都必须有一个勾上的开关认领它。文字各归各的开关；图标只有一个位置，
 * 按固定优先级（现象 → 温度 → 概率）由第一个勾上的项认领。三种「整行消失」统一成同一个出口：
 * 没有摘要 / 三项全关 / 只勾了降水概率但它不可用。
 */
enum class WeatherIconKind { PHENOMENON, TEMPERATURE, PROBABILITY }

/** 一条天气行的渲染计划。`probability` 非空表示「概率这一项要显示且可用」。 */
class WeatherLinePlan(
    val category: WeatherCategory,
    val temperatureC: Int,
    val showPhenomenon: Boolean,
    val showTemperature: Boolean,
    val probability: Int?,
    /** 图标由谁认领（决定图标形状：天气图标 / 温度计 / 百分号）。 */
    val iconKind: WeatherIconKind,
)

/**
 * 由摘要 + 三个内容开关算出渲染计划；不该画时返回 null。
 *
 * 与 Dart `courseWeatherDisplayFor` 同口径：「只勾了降水概率但概率不可用」也返回 null。
 */
fun planWeatherLine(
    summary: CourseWeatherSummary?,
    showPhenomenon: Boolean,
    showTemperature: Boolean,
    showProbability: Boolean,
): WeatherLinePlan? {
    if (summary == null) return null
    if (!showPhenomenon && !showTemperature && !showProbability) return null

    val probabilityUsable =
        showProbability && summary.showPrecipitationProbability && summary.precipitationProbability != null
    // 唯一勾上的项是「概率」而它不可用 → 没有东西可画。
    if (!showPhenomenon && !showTemperature && !probabilityUsable) return null

    val iconKind = when {
        showPhenomenon -> WeatherIconKind.PHENOMENON
        showTemperature -> WeatherIconKind.TEMPERATURE
        else -> WeatherIconKind.PROBABILITY
    }
    return WeatherLinePlan(
        category = summary.category,
        temperatureC = summary.temperatureC,
        showPhenomenon = showPhenomenon,
        showTemperature = showTemperature,
        probability = if (probabilityUsable) summary.precipitationProbability else null,
        iconKind = iconKind,
    )
}

/**
 * 窄面（周视图格子）的文字只写一项、**温度优先**；温度没勾时退回图标认领者那一项。
 *
 * @return 该写哪一项：`"temperature"` / `"phenomenon"` / `"probability"`；无可用项时返回 null
 *   （理论上 plan 非空时必有一项可用）。
 */
fun compactWeatherItem(plan: WeatherLinePlan): String? = when {
    plan.showTemperature -> "temperature"
    plan.showPhenomenon -> "phenomenon"
    plan.probability != null -> "probability"
    else -> null
}
