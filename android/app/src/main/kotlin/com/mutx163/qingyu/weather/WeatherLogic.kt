package com.mutx163.qingyu.weather

import java.time.LocalDateTime

/**
 * Dart `lib/domain/weather_logic.dart` 的移植（天气聚合：WMO 码 → 现象分类 → 按时段摘要）。
 *
 * 与 Dart 逐条对齐：
 * - [WeatherCategory] 20 类、[weatherCategorySeverity] 序、[weatherCategoryFromWmo] 映射；
 * - [summarizeCourseWeather] 的覆盖规则「取所有与 `[start, end]` 有交集的小时桶」，
 *   即左开 `t > start`、右开 `t < end + 1h`；
 * - 温度四舍五入用「半远离零」（Dart `num.round()`），不用 JVM `Math.round`（半向上）。
 *
 * 纯 Kotlin（无 Android / Compose / kotlinx 依赖），可进 JVM 模块单测。
 */

/** 天气现象分类（由 WMO 码归并而来，粒度取「图标能区分 + 用户需要知道差别」）。 */
enum class WeatherCategory {
    CLEAR,
    MAINLY_CLEAR,
    PARTLY_CLOUDY,
    OVERCAST,
    FOG,
    DRIZZLE,
    FREEZING_DRIZZLE,
    LIGHT_RAIN,
    RAIN,
    HEAVY_RAIN,
    FREEZING_RAIN,
    RAIN_SHOWERS,
    HEAVY_RAIN_SHOWERS,
    LIGHT_SNOW,
    SNOW,
    HEAVY_SNOW,
    SNOW_GRAINS,
    SNOW_SHOWERS,
    THUNDERSTORM,
    THUNDERSTORM_HAIL,
}

/** 天气现象严重度序（数值越大越恶劣）。 */
fun weatherCategorySeverity(category: WeatherCategory): Int = when (category) {
    WeatherCategory.CLEAR -> 0
    WeatherCategory.MAINLY_CLEAR -> 1
    WeatherCategory.PARTLY_CLOUDY -> 2
    WeatherCategory.OVERCAST -> 3
    WeatherCategory.FOG -> 4
    WeatherCategory.DRIZZLE -> 5
    WeatherCategory.FREEZING_DRIZZLE -> 6
    WeatherCategory.LIGHT_RAIN -> 7
    WeatherCategory.RAIN -> 8
    WeatherCategory.HEAVY_RAIN -> 9
    WeatherCategory.FREEZING_RAIN -> 10
    WeatherCategory.RAIN_SHOWERS -> 11
    WeatherCategory.HEAVY_RAIN_SHOWERS -> 12
    WeatherCategory.LIGHT_SNOW -> 13
    WeatherCategory.SNOW -> 14
    WeatherCategory.HEAVY_SNOW -> 15
    WeatherCategory.SNOW_GRAINS -> 16
    WeatherCategory.SNOW_SHOWERS -> 17
    WeatherCategory.THUNDERSTORM -> 18
    WeatherCategory.THUNDERSTORM_HAIL -> 19
}

/** WMO 天气现象码 → 分类。未知码兜底为 [WeatherCategory.CLEAR]（宁可少报也不臆测暴雨）。 */
fun weatherCategoryFromWmo(code: Int): WeatherCategory = when (code) {
    0 -> WeatherCategory.CLEAR
    1 -> WeatherCategory.MAINLY_CLEAR
    2 -> WeatherCategory.PARTLY_CLOUDY
    3 -> WeatherCategory.OVERCAST
    45, 48 -> WeatherCategory.FOG
    51, 53, 55 -> WeatherCategory.DRIZZLE
    56, 57 -> WeatherCategory.FREEZING_DRIZZLE
    61 -> WeatherCategory.LIGHT_RAIN
    63 -> WeatherCategory.RAIN
    65 -> WeatherCategory.HEAVY_RAIN
    66, 67 -> WeatherCategory.FREEZING_RAIN
    80, 81 -> WeatherCategory.RAIN_SHOWERS
    82 -> WeatherCategory.HEAVY_RAIN_SHOWERS
    71 -> WeatherCategory.LIGHT_SNOW
    73 -> WeatherCategory.SNOW
    75 -> WeatherCategory.HEAVY_SNOW
    77 -> WeatherCategory.SNOW_GRAINS
    85, 86 -> WeatherCategory.SNOW_SHOWERS
    95 -> WeatherCategory.THUNDERSTORM
    96, 99 -> WeatherCategory.THUNDERSTORM_HAIL
    else -> WeatherCategory.CLEAR
}

/** 是否属于雪家族。冻雨不算雪（它是雨落地结冰）。 */
fun weatherCategoryIsSnow(category: WeatherCategory): Boolean = when (category) {
    WeatherCategory.LIGHT_SNOW,
    WeatherCategory.SNOW,
    WeatherCategory.HEAVY_SNOW,
    WeatherCategory.SNOW_GRAINS,
    WeatherCategory.SNOW_SHOWERS -> true
    else -> false
}

/** 是否属于雨家族（含冻雨、毛毛雨、阵雨）。 */
fun weatherCategoryIsRain(category: WeatherCategory): Boolean = when (category) {
    WeatherCategory.DRIZZLE,
    WeatherCategory.FREEZING_DRIZZLE,
    WeatherCategory.LIGHT_RAIN,
    WeatherCategory.RAIN,
    WeatherCategory.HEAVY_RAIN,
    WeatherCategory.FREEZING_RAIN,
    WeatherCategory.RAIN_SHOWERS,
    WeatherCategory.HEAVY_RAIN_SHOWERS -> true
    else -> false
}

/** 默认的降水概率显示阈值（低于该值等于「基本不下」，印出来是噪音）。 */
const val DEFAULT_PROBABILITY_VISIBILITY_THRESHOLD: Int = 30

/**
 * 把 `HH:mm` 拼到 [date] 的日期上；格式非法返回 null。
 *
 * 与 Dart `combineDateAndTime` 同口径：只取 [date] 的年月日。
 */
fun combineDateAndTime(date: LocalDateTime, time: String): LocalDateTime? {
    val parts = time.trim().split(':')
    if (parts.size < 2) return null
    val hour = parts[0].toIntOrNull() ?: return null
    val minute = parts[1].toIntOrNull() ?: return null
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null
    return LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, hour, minute)
}

/** 一节课时段内的天气摘要（`CourseWeatherSummary`）。 */
class CourseWeatherSummary(
    /** 时段内的代表天气现象。 */
    val category: WeatherCategory,
    /** 代表温度（摄氏度，四舍五入到整数）。 */
    val temperatureC: Int,
    /** 参与聚合的小时数（诊断与测试用，UI 不用）。 */
    val hourCount: Int,
    /** 时段内最高的降水概率；全缺报时为 null。 */
    val precipitationProbability: Int?,
    /** 是否值得把概率显示给用户。 */
    val showPrecipitationProbability: Boolean,
    /** 选出 category 时命中的 WMO 码（诊断与测试用，UI 不用）。 */
    val representativeWmoCode: Int?,
)

/**
 * 把一节课的时间区间聚合成一条天气摘要；无可用数据时返回 null。
 *
 * 覆盖规则见文件头注释。
 */
fun summarizeCourseWeather(
    forecast: WeatherForecast,
    start: LocalDateTime,
    end: LocalDateTime,
    probabilityVisibilityThreshold: Int = DEFAULT_PROBABILITY_VISIBILITY_THRESHOLD,
): CourseWeatherSummary? {
    if (!end.isAfter(start)) return null

    val windowEnd = end.plusHours(1)
    val firstIndex = firstIndexAfter(forecast.hourly, start)
    val selected = ArrayList<HourlyWeatherPoint>()
    for (i in firstIndex until forecast.hourly.size) {
        val point = forecast.hourly[i]
        if (!point.time.isBefore(windowEnd)) break
        selected.add(point)
    }
    if (selected.isEmpty()) return null

    var temperatureSum = 0.0
    var temperatureCount = 0
    for (point in selected) {
        val value = point.temperatureC ?: continue
        if (!value.isFinite()) continue
        temperatureSum += value
        temperatureCount++
    }
    if (temperatureCount == 0) {
        // 温度是这一行的主语；没有温度就不显示整行。
        return null
    }

    var probability: Int? = null
    var precipitationMm = 0.0
    var snowfallCm = 0.0
    val observed = ArrayList<ObservedWeather>()
    for (point in selected) {
        val p = point.precipitationProbability
        if (p != null) probability = if (probability == null) p else maxOf(p, probability)
        val precip = point.precipitationMm
        if (precip != null && precip.isFinite() && precip > precipitationMm) precipitationMm = precip
        val snow = point.snowfallCm
        if (snow != null && snow.isFinite() && snow > snowfallCm) snowfallCm = snow
        val code = point.weatherCode
        if (code != null) observed.add(ObservedWeather(weatherCategoryFromWmo(code), code))
    }
    probability = probability?.coerceIn(0, 100)

    val snowiest = mostSevere(observed) { weatherCategoryIsSnow(it) }
    val rainiest = mostSevere(observed) { weatherCategoryIsRain(it) }

    // 雪优先于雨：区间内任一小时下雪就报雪，哪怕同时也下雨。
    val category: WeatherCategory = when {
        snowfallCm > 0 || snowiest != null ->
            snowiest?.category ?: WeatherCategory.LIGHT_SNOW
        precipitationMm > 0.1 || rainiest != null ->
            rainiest?.category ?: WeatherCategory.LIGHT_RAIN
        else -> mostSevere(observed) { true }?.category ?: WeatherCategory.CLEAR
    }

    var representativeCode: Int? = null
    for (item in observed) {
        if (item.category == category) {
            representativeCode = item.code
            break
        }
    }

    return CourseWeatherSummary(
        category = category,
        temperatureC = dartRound(temperatureSum / temperatureCount),
        hourCount = selected.size,
        precipitationProbability = probability,
        showPrecipitationProbability = probability != null && probability >= probabilityVisibilityThreshold,
        representativeWmoCode = representativeCode,
    )
}

private class ObservedWeather(val category: WeatherCategory, val code: Int)

/** 第一个 `time > [threshold]` 的下标；全部不满足时返回列表长度。 */
private fun firstIndexAfter(points: List<HourlyWeatherPoint>, threshold: LocalDateTime): Int {
    var low = 0
    var high = points.size
    while (low < high) {
        val mid = (low + high) ushr 1
        if (points[mid].time.isAfter(threshold)) high = mid else low = mid + 1
    }
    return low
}

/** 挑出满足 [predicate] 且严重度最高的一个。 */
private fun mostSevere(
    items: List<ObservedWeather>,
    predicate: (WeatherCategory) -> Boolean,
): ObservedWeather? {
    var best: ObservedWeather? = null
    var bestSeverity = -1
    for (item in items) {
        if (!predicate(item.category)) continue
        val severity = weatherCategorySeverity(item.category)
        if (severity > bestSeverity) {
            best = item
            bestSeverity = severity
        }
    }
    return best
}

/** Dart `num.round()`：半远离零。 */
private fun dartRound(value: Double): Int =
    if (value >= 0) Math.floor(value + 0.5).toInt() else Math.ceil(value - 0.5).toInt()
