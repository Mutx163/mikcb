package com.mutx163.qingyu.weather

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 天气设备本地配置（Dart `lib/services/weather_preferences.dart` 的移植）。
 *
 * 走 [InMemoryKeyValueStore]（与真实现共用 [com.mutx163.qingyu.app.FrozenValueCodec] 的前缀/编码规则），
 * 于是「键契约 + 往返」在 JVM 上可断言。
 */
class WeatherPreferencesTest {

    private fun forecast() = WeatherForecast(
        30.29,
        120.16,
        LocalDateTime.of(2026, 10, 28, 7, 0),
        listOf(
            HourlyWeatherPoint(
                time = LocalDateTime.of(2026, 10, 28, 9, 0),
                temperatureC = 20.4,
                precipitationProbability = 80,
                weatherCode = 61,
            ),
        ),
    )

    @Test
    fun default_disabled() {
        val prefs = WeatherPreferences(InMemoryKeyValueStore())
        assertFalse(prefs.isEnabled())
    }

    @Test
    fun enabled_round_trips_under_flutter_prefix() {
        val store = InMemoryKeyValueStore()
        val prefs = WeatherPreferences(store)
        prefs.setEnabled(true)
        assertTrue(WeatherPreferences(store).isEnabled())
        // 物理键必须带 Flutter 插件的 `flutter.` 前缀，才能与 Dart 侧互读。
        assertTrue(store.rawSnapshot().containsKey("flutter.weather_enabled_v1"))
    }

    @Test
    fun location_round_trips() {
        val store = InMemoryKeyValueStore()
        val prefs = WeatherPreferences(store)
        val location = WeatherLocation("杭州", 30.29, 120.16, district = "拱墅区")
        prefs.saveLocation(location)
        val loaded = WeatherPreferences(store).loadLocation()!!
        assertEquals("杭州", loaded.name)
        assertEquals("拱墅区", loaded.district)
        assertEquals(30.29, loaded.latitude, 1e-9)
    }

    @Test
    fun forecast_round_trips_and_clears() {
        val store = InMemoryKeyValueStore()
        val prefs = WeatherPreferences(store)
        prefs.saveForecast(forecast())
        val loaded = WeatherPreferences(store).loadForecast()!!
        assertEquals(1, loaded.hourly.size)
        assertEquals(20.4, loaded.hourly[0].temperatureC!!, 1e-9)
        prefs.clearForecast()
        assertNull(WeatherPreferences(store).loadForecast())
    }

    @Test
    fun corrupt_forecast_decodes_to_null() {
        val store = InMemoryKeyValueStore(mapOf("weather_forecast_v1" to "{not json"))
        assertNull(WeatherPreferences(store).loadForecast())
    }
}
