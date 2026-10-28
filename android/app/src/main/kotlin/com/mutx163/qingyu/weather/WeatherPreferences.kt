package com.mutx163.qingyu.weather

import com.mutx163.qingyu.app.KeyValueStore

/**
 * Dart `lib/services/weather_preferences.dart` 的移植。
 *
 * 设备级天气配置（开关 / 所选城市 / 预报缓存）——**刻意不进 TimetableSettings**：
 * 那份设置会随课表档案进备份与云同步，而「所在城市」是设备属性（两台设备一在杭州一在成都，
 * 同步一个城市必有一台错）。
 *
 * ## 键契约（与 Dart 逐字一致，保证与 Flutter 侧落盘数据互读）
 *
 * Dart 走 `SharedPreferences`（物理键带 `flutter.` 前缀），本类走 [KeyValueStore]，
 * 契约键**不带前缀**、物理前缀由存储实现统一加。三个键同 Dart：
 * [ENABLED_KEY] / [LOCATION_KEY] / [FORECAST_KEY]。
 */
class WeatherPreferences(private val store: KeyValueStore) {

    companion object {
        const val ENABLED_KEY = "weather_enabled_v1"
        const val LOCATION_KEY = "weather_city_v1"
        const val FORECAST_KEY = "weather_forecast_v1"

        /** 默认关闭：未选城市前打开开关只会得到一排空白，不如先选城市。 */
        const val DEFAULT_ENABLED = false
    }

    fun isEnabled(): Boolean = store.getBool(ENABLED_KEY, DEFAULT_ENABLED)

    fun setEnabled(enabled: Boolean) = store.putBool(ENABLED_KEY, enabled)

    fun loadLocation(): WeatherLocation? = WeatherLocation.tryDecode(store.getString(LOCATION_KEY))

    fun saveLocation(location: WeatherLocation) =
        store.putString(LOCATION_KEY, location.toJsonString())

    fun loadForecast(): WeatherForecast? = WeatherForecast.tryDecode(store.getString(FORECAST_KEY))

    fun saveForecast(forecast: WeatherForecast) {
        store.putString(FORECAST_KEY, forecast.toJsonString())
    }

    fun clearForecast() = store.remove(FORECAST_KEY)
}
