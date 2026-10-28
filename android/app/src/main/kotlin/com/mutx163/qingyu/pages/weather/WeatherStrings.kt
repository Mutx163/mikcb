package com.mutx163.qingyu.pages.weather

import com.mutx163.qingyu.weather.WeatherCategory

/**
 * 天气与城市选择模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * ## 纪律与原则
 *
 * 1. 每一条 ARB 词条必须与 `lib/l10n/app_zh.arb` 逐字对齐，由 [WeatherStringsParityTest] 机械校验；
 * 2. 属于纯界面组织结构（如热门城市分区标题）的常量，明确标注为界面辅助词；
 * 3. 包含地区标签与定位错误转换等格式化纯函数。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

/** 定位失败原因枚举（对齐 Flutter `DeviceLocationFailure`）。 */
enum class WeatherLocationFailure {
    SERVICE_DISABLED,
    PERMISSION_DENIED,
    PERMISSION_DENIED_FOREVER,
    TIMEOUT,
    FAILED,
    ADDRESS_UNAVAILABLE,
}

object WeatherStrings {

    // ── 选城市页主文案（ARB 逐字对拍）──
    val weatherCityPickerTitle = ArbText("weatherCityPickerTitle", "选择城市")
    val weatherCitySearchHint = ArbText("weatherCitySearchHint", "输入城市名称")
    val weatherCitySearchEmpty = ArbText("weatherCitySearchEmpty", "没有找到匹配的城市")
    val weatherCitySearchFailed = ArbText("weatherCitySearchFailed", "搜索失败，请稍后重试")
    val weatherSectionCurrentLocation = ArbText("weatherSectionCurrentLocation", "当前位置")
    val weatherUseCurrentLocation = ArbText("weatherUseCurrentLocation", "使用当前位置")
    val weatherLocating = ArbText("weatherLocating", "正在定位……")
    val weatherSectionSearchCity = ArbText("weatherSectionSearchCity", "搜索城市")
    val weatherCityLabel = ArbText("weatherCityLabel", "城市")
    val weatherCityNotSet = ArbText("weatherCityNotSet", "未设置")
    val weatherRetryAction = ArbText("weatherRetryAction", "重试")

    // ── 定位失败与状态提示文案（ARB 逐字对拍）──
    val weatherLocationServiceDisabled = ArbText("weatherLocationServiceDisabled", "请先开启系统定位服务")
    val weatherLocationPermissionDenied = ArbText("weatherLocationPermissionDenied", "没有位置权限，无法获取当前位置")
    val weatherLocationPermissionDeniedForever = ArbText("weatherLocationPermissionDeniedForever", "位置权限已被拒绝，请到系统设置里允许本应用使用位置")
    val weatherLocationTimeout = ArbText("weatherLocationTimeout", "定位超时，请到窗边或室外再试，或直接搜索城市")
    val weatherLocationFailed = ArbText("weatherLocationFailed", "定位失败，请改用手动搜索城市")
    val weatherLocationAddressUnavailable = ArbText("weatherLocationAddressUnavailable", "已定位，但解析不出地名，请改用手动搜索城市")
    val weatherLocationEstimated = ArbText("weatherLocationEstimated", "已按网络位置估算，可能不精确")

    // ── 天气现象与取值格式（ARB 逐字对拍，供卡片/详情弹窗天气行使用）──
    val weatherClear = ArbText("weatherClear", "晴")
    val weatherMainlyClear = ArbText("weatherMainlyClear", "晴间多云")
    val weatherPartlyCloudy = ArbText("weatherPartlyCloudy", "多云")
    val weatherOvercast = ArbText("weatherOvercast", "阴")
    val weatherFog = ArbText("weatherFog", "雾")
    val weatherDrizzle = ArbText("weatherDrizzle", "毛毛雨")
    val weatherFreezingDrizzle = ArbText("weatherFreezingDrizzle", "冻毛毛雨")
    val weatherLightRain = ArbText("weatherLightRain", "小雨")
    val weatherRain = ArbText("weatherRain", "中雨")
    val weatherHeavyRain = ArbText("weatherHeavyRain", "大雨")
    val weatherFreezingRain = ArbText("weatherFreezingRain", "冻雨")
    val weatherLightSnow = ArbText("weatherLightSnow", "小雪")
    val weatherSnow = ArbText("weatherSnow", "中雪")
    val weatherHeavySnow = ArbText("weatherHeavySnow", "大雪")
    val weatherSnowGrains = ArbText("weatherSnowGrains", "米雪")
    val weatherRainShowers = ArbText("weatherRainShowers", "阵雨")
    val weatherHeavyRainShowers = ArbText("weatherHeavyRainShowers", "强阵雨")
    val weatherSnowShowers = ArbText("weatherSnowShowers", "阵雪")
    val weatherThunderstorm = ArbText("weatherThunderstorm", "雷阵雨")
    val weatherThunderstormHail = ArbText("weatherThunderstormHail", "雷阵雨伴冰雹")
    val weatherTemperatureValue = ArbText("weatherTemperatureValue", "{temperature}°")
    val weatherProbabilityValue = ArbText("weatherProbabilityValue", "{probability}%")
    val weatherSummarySeparator = ArbText("weatherSummarySeparator", " · ")

    /** 天气现象分类 → 本地化名（对齐 Flutter `WeatherCategoryLocalizer.label`）。 */
    fun categoryLabel(category: WeatherCategory): String = when (category) {
        WeatherCategory.CLEAR -> weatherClear.zh
        WeatherCategory.MAINLY_CLEAR -> weatherMainlyClear.zh
        WeatherCategory.PARTLY_CLOUDY -> weatherPartlyCloudy.zh
        WeatherCategory.OVERCAST -> weatherOvercast.zh
        WeatherCategory.FOG -> weatherFog.zh
        WeatherCategory.DRIZZLE -> weatherDrizzle.zh
        WeatherCategory.FREEZING_DRIZZLE -> weatherFreezingDrizzle.zh
        WeatherCategory.LIGHT_RAIN -> weatherLightRain.zh
        WeatherCategory.RAIN -> weatherRain.zh
        WeatherCategory.HEAVY_RAIN -> weatherHeavyRain.zh
        WeatherCategory.FREEZING_RAIN -> weatherFreezingRain.zh
        WeatherCategory.RAIN_SHOWERS -> weatherRainShowers.zh
        WeatherCategory.HEAVY_RAIN_SHOWERS -> weatherHeavyRainShowers.zh
        WeatherCategory.LIGHT_SNOW -> weatherLightSnow.zh
        WeatherCategory.SNOW -> weatherSnow.zh
        WeatherCategory.HEAVY_SNOW -> weatherHeavySnow.zh
        WeatherCategory.SNOW_GRAINS -> weatherSnowGrains.zh
        WeatherCategory.SNOW_SHOWERS -> weatherSnowShowers.zh
        WeatherCategory.THUNDERSTORM -> weatherThunderstorm.zh
        WeatherCategory.THUNDERSTORM_HAIL -> weatherThunderstormHail.zh
    }

    fun temperatureValue(celsius: Int): String =
        weatherTemperatureValue.filled("temperature", celsius.toString())

    fun probabilityValue(percent: Int): String =
        weatherProbabilityValue.filled("probability", percent.toString())

    // ── 格式化纯函数与辅助词（供 UI 与模型层调用）──
    const val hotCitiesSection: String = "热门城市"
    const val currentLocationCity: String = "当前定位城市"
    const val allCitiesSection: String = "全部城市"
    const val relocateAction: String = "重新定位"

    // 快捷别名
    val searchCityHint: String get() = weatherCitySearchHint.zh
    val locationPermissionDenied: String get() = weatherLocationPermissionDenied.zh
    val locateFailed: String get() = weatherLocationFailed.zh

    /** 所有需在 app_zh.arb 中严格存在的词条清单。 */
    val allArbTexts: List<ArbText> = listOf(
        weatherCityPickerTitle,
        weatherCitySearchHint,
        weatherCitySearchEmpty,
        weatherCitySearchFailed,
        weatherSectionCurrentLocation,
        weatherUseCurrentLocation,
        weatherLocating,
        weatherSectionSearchCity,
        weatherCityLabel,
        weatherCityNotSet,
        weatherRetryAction,
        weatherLocationServiceDisabled,
        weatherLocationPermissionDenied,
        weatherLocationPermissionDeniedForever,
        weatherLocationTimeout,
        weatherLocationFailed,
        weatherLocationAddressUnavailable,
        weatherLocationEstimated,
        weatherClear,
        weatherMainlyClear,
        weatherPartlyCloudy,
        weatherOvercast,
        weatherFog,
        weatherDrizzle,
        weatherFreezingDrizzle,
        weatherLightRain,
        weatherRain,
        weatherHeavyRain,
        weatherFreezingRain,
        weatherLightSnow,
        weatherSnow,
        weatherHeavySnow,
        weatherSnowGrains,
        weatherRainShowers,
        weatherHeavyRainShowers,
        weatherSnowShowers,
        weatherThunderstorm,
        weatherThunderstormHail,
        weatherTemperatureValue,
        weatherProbabilityValue,
        weatherSummarySeparator,
    )

    /**
     * 将定位错误枚举转换为用户提示语（对齐 Flutter `WeatherLocationFailureLocalizer`）。
     */
    fun locationFailureMessage(failure: WeatherLocationFailure): String = when (failure) {
        WeatherLocationFailure.SERVICE_DISABLED -> weatherLocationServiceDisabled.zh
        WeatherLocationFailure.PERMISSION_DENIED -> weatherLocationPermissionDenied.zh
        WeatherLocationFailure.PERMISSION_DENIED_FOREVER -> weatherLocationPermissionDeniedForever.zh
        WeatherLocationFailure.TIMEOUT -> weatherLocationTimeout.zh
        WeatherLocationFailure.FAILED -> weatherLocationFailed.zh
        WeatherLocationFailure.ADDRESS_UNAVAILABLE -> weatherLocationAddressUnavailable.zh
    }

    /**
     * 拼接结果列表副标题：行政区 + 国家，跳过空值与重复城市名（对齐 Flutter `WeatherLocation.regionLabel`）。
     */
    fun formatRegionLabel(admin1: String?, country: String?, cityName: String): String {
        val parts = mutableListOf<String>()
        for (value in listOf(admin1, country)) {
            val trimmed = value?.trim().orEmpty()
            if (trimmed.isEmpty() || trimmed == cityName || parts.contains(trimmed)) {
                continue
            }
            parts.add(trimmed)
        }
        return parts.joinToString(" · ")
    }

    /**
     * 格式化城市紧凑显示名（对齐 Flutter `WeatherLocation.displayName`）。
     *
     * 有区县时给出「市 · 区」，无区县或与市名相同时只给市名。
     */
    fun formatDisplayName(cityName: String, district: String?): String {
        val trimmedDistrict = district?.trim().orEmpty()
        if (trimmedDistrict.isEmpty() || trimmedDistrict == cityName) {
            return cityName
        }
        return "$cityName · $trimmedDistrict"
    }
}
