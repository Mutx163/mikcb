package com.mutx163.qingyu.weather

/**
 * 天气现象分类 → 中文标签的**纯映射**（对齐 Flutter `WeatherCategoryLocalizer.label`）。
 *
 * ## 为什么住在共享 weather/（2026-11-03 自 `pages/weather` 下沉）
 *
 * 天气现象名是**天气域的共享词汇**：除了天气页自己，课表域的日视图天气行
 * （`DayViewWeather`）也要把 `WeatherProvider`（本包）给出的现象分类翻成中文。
 * 原先映射长在 `pages.weather.WeatherStrings.categoryLabel`，课表域为此反向
 * import 天气页域，`pages/timetable` 的 L0 编不过。
 *
 * ## 纪律：与 ARB 逐字对拍
 *
 * 下面的中文逐字照抄 `lib/l10n/app_zh.arb` 的 `weatherXxx` 键，由
 * `WeatherCategoryLocalizerParityTest` 机械对拍；改文案只能改 ARB 再同步回来。
 * 与 `pages.weather.WeatherStrings` 里的同名 ArbText 条目是**刻意的两份**
 * （共享层不能反向依赖页面域，同形副本 + 双向对拍，与 `calendar/HolidayLogLocalizer`
 * 同一套做法），两份都以同一份 ARB 为真源，漂不了。
 */
object WeatherCategoryLocalizer {

    private const val CLEAR = "晴"
    private const val MAINLY_CLEAR = "晴间多云"
    private const val PARTLY_CLOUDY = "多云"
    private const val OVERCAST = "阴"
    private const val FOG = "雾"
    private const val DRIZZLE = "毛毛雨"
    private const val FREEZING_DRIZZLE = "冻毛毛雨"
    private const val LIGHT_RAIN = "小雨"
    private const val RAIN = "中雨"
    private const val HEAVY_RAIN = "大雨"
    private const val FREEZING_RAIN = "冻雨"
    private const val RAIN_SHOWERS = "阵雨"
    private const val HEAVY_RAIN_SHOWERS = "强阵雨"
    private const val SNOW_SHOWERS = "阵雪"
    private const val LIGHT_SNOW = "小雪"
    private const val SNOW = "中雪"
    private const val HEAVY_SNOW = "大雪"
    private const val SNOW_GRAINS = "米雪"
    private const val THUNDERSTORM = "雷阵雨"
    private const val THUNDERSTORM_HAIL = "雷阵雨伴冰雹"

    /** 天气现象分类 → 本地化名（`WeatherStrings.categoryLabel` 委托到这里）。 */
    fun label(category: WeatherCategory): String = when (category) {
        WeatherCategory.CLEAR -> CLEAR
        WeatherCategory.MAINLY_CLEAR -> MAINLY_CLEAR
        WeatherCategory.PARTLY_CLOUDY -> PARTLY_CLOUDY
        WeatherCategory.OVERCAST -> OVERCAST
        WeatherCategory.FOG -> FOG
        WeatherCategory.DRIZZLE -> DRIZZLE
        WeatherCategory.FREEZING_DRIZZLE -> FREEZING_DRIZZLE
        WeatherCategory.LIGHT_RAIN -> LIGHT_RAIN
        WeatherCategory.RAIN -> RAIN
        WeatherCategory.HEAVY_RAIN -> HEAVY_RAIN
        WeatherCategory.FREEZING_RAIN -> FREEZING_RAIN
        WeatherCategory.RAIN_SHOWERS -> RAIN_SHOWERS
        WeatherCategory.HEAVY_RAIN_SHOWERS -> HEAVY_RAIN_SHOWERS
        WeatherCategory.LIGHT_SNOW -> LIGHT_SNOW
        WeatherCategory.SNOW -> SNOW
        WeatherCategory.HEAVY_SNOW -> HEAVY_SNOW
        WeatherCategory.SNOW_GRAINS -> SNOW_GRAINS
        WeatherCategory.SNOW_SHOWERS -> SNOW_SHOWERS
        WeatherCategory.THUNDERSTORM -> THUNDERSTORM
        WeatherCategory.THUNDERSTORM_HAIL -> THUNDERSTORM_HAIL
    }
}
