package com.mutx163.qingyu.weather

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 天气状态机（Dart `lib/providers/weather_provider.dart` 的移植）。
 *
 * 同步实现 + 注入假网关/假定位源/可控时钟，逐条钉死 TTL、失败退避、换城作废、定位单飞、
 * 摘要计算这些语义。期望值来自 [Dart推演]（对照 Dart provider 的分支）。
 */
class WeatherProviderTest {

    private class FakeGateway : WeatherGateway {
        var forecast: WeatherForecast? = null
        var fetchCount = 0
        var searchResult: List<WeatherLocation> = emptyList()
        override fun fetchForecast(location: WeatherLocation): WeatherForecast? {
            fetchCount++
            return forecast
        }
        override fun searchLocations(query: String): List<WeatherLocation> = searchResult
        override fun reverseGeocode(latitude: Double, longitude: Double): WeatherLocation? = null
        override fun networkGeocode(): WeatherLocation? = null
    }

    private class FakeLocationSource(var outcome: DeviceLocationOutcome) : DeviceLocationSource {
        override fun locate(): DeviceLocationOutcome = outcome
    }

    private val hangzhou = WeatherLocation("杭州", 30.29, 120.16)
    private val chengdu = WeatherLocation("成都", 30.57, 104.07)

    private fun forecastAt(fetchedAt: LocalDateTime) = WeatherForecast(
        30.29,
        120.16,
        fetchedAt,
        listOf(
            HourlyWeatherPoint(LocalDateTime.of(2026, 10, 28, 9, 0), 20.0, 60, null, null, 61),
            HourlyWeatherPoint(LocalDateTime.of(2026, 10, 28, 10, 0), 22.0, 70, null, null, 63),
        ),
    )

    private fun provider(
        gateway: WeatherGateway,
        locationSource: DeviceLocationSource = FakeLocationSource(DeviceLocationOutcome.failure(DeviceLocationFailure.TIMEOUT)),
        clock: () -> LocalDateTime,
    ): WeatherProvider = WeatherProvider(gateway, WeatherPreferences(InMemoryKeyValueStore()), locationSource, clock)

    @Test
    fun disabled_by_default_does_not_fetch() {
        val gateway = FakeGateway()
        val provider = provider(gateway, clock = { LocalDateTime.of(2026, 10, 28, 8, 0) })
        provider.initialize()
        assertFalse(provider.enabled)
        assertEquals(0, gateway.fetchCount)
    }

    @Test
    fun location_fetch_sets_ready_forecast() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = forecastAt(now) }
        val provider = provider(gateway, clock = { now })

        provider.setEnabled(true)
        assertEquals(0, gateway.fetchCount) // 没有城市，不发请求
        provider.setLocation(hangzhou)

        assertEquals(1, gateway.fetchCount)
        assertEquals(WeatherState.READY, provider.state)
        assertEquals("杭州", provider.location?.name)
    }

    /** 窗口跨到 3 天后，用于把「TTL 过期」与「窗口走完」两件事分开测。 */
    private fun forecastLongWindow(fetchedAt: LocalDateTime) = WeatherForecast(
        30.29,
        120.16,
        fetchedAt,
        listOf(
            HourlyWeatherPoint(fetchedAt.plusHours(1).withMinute(0).withSecond(0), 20.0, 60, null, null, 61),
            HourlyWeatherPoint(fetchedAt.plusDays(3).withMinute(0).withSecond(0), 22.0, 70, null, null, 63),
        ),
    )

    @Test
    fun ttl_skips_fresh_refreshes_stale() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        // 窗口远长于 4h（跨到 3 天后），所以 +4h 的刷新只能由 TTL 触发、而非窗口走完。
        val gateway = FakeGateway().apply { forecast = forecastLongWindow(now) }
        val provider = provider(gateway, clock = { now })

        provider.setEnabled(true)
        provider.setLocation(hangzhou)
        assertEquals(1, gateway.fetchCount)

        now = LocalDateTime.of(2026, 10, 28, 9, 0) // +1h，仍在 3h TTL 内
        provider.ensureFresh()
        assertEquals(1, gateway.fetchCount)

        now = LocalDateTime.of(2026, 10, 28, 12, 0) // +4h，超过 3h TTL（窗口未走完）
        gateway.forecast = forecastLongWindow(now)
        provider.ensureFresh()
        assertEquals(2, gateway.fetchCount)
    }

    @Test
    fun failure_enters_backoff_then_retries_after_delay() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = null }
        val provider = provider(gateway, clock = { now })

        provider.setEnabled(true)
        provider.setLocation(hangzhou)
        assertEquals(WeatherState.FAILED, provider.state)
        assertEquals(1, gateway.fetchCount)

        now = LocalDateTime.of(2026, 10, 28, 8, 5) // 退避期内
        provider.ensureFresh()
        assertEquals(1, gateway.fetchCount)

        now = LocalDateTime.of(2026, 10, 28, 8, 20) // 超过 15min 退避
        provider.ensureFresh()
        assertEquals(2, gateway.fetchCount)
    }

    @Test
    fun changing_city_drops_old_forecast() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = forecastAt(now) }
        val provider = provider(gateway, clock = { now })

        provider.setEnabled(true)
        provider.setLocation(hangzhou)
        assertTrue(provider.forecast != null)

        gateway.forecast = null // 新城市取数失败
        provider.setLocation(chengdu)
        assertNull(provider.forecast) // 旧城市预报已被丢弃
    }

    @Test
    fun locate_success_sets_city_and_returns_null_failure() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = forecastAt(now) }
        val locationSource = FakeLocationSource(DeviceLocationOutcome.success(hangzhou))
        val provider = provider(gateway, locationSource, clock = { now })
        provider.setEnabled(true)

        val failure = provider.locateCurrentPosition()

        assertNull(failure)
        assertEquals("杭州", provider.location?.name)
        assertFalse(provider.isLocating)
        assertNull(provider.lastLocateFailure)
    }

    @Test
    fun locate_failure_does_not_touch_existing_city() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = forecastAt(now) }
        val locationSource = FakeLocationSource(DeviceLocationOutcome.failure(DeviceLocationFailure.PERMISSION_DENIED))
        val provider = provider(gateway, locationSource, clock = { now })
        provider.setEnabled(true)
        provider.setLocation(hangzhou)

        val failure = provider.locateCurrentPosition()

        assertEquals(DeviceLocationFailure.PERMISSION_DENIED, failure)
        assertEquals("杭州", provider.location?.name) // 原城市保留
        assertFalse(provider.isLocating)
    }

    @Test
    fun summary_for_course_uses_forecast_window() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = forecastAt(now) }
        val provider = provider(gateway, clock = { now })
        provider.setEnabled(true)
        provider.setLocation(hangzhou)

        val summary = provider.summaryForCourse(
            date = LocalDateTime.of(2026, 10, 28, 0, 0),
            startTime = "08:00",
            endTime = "09:35",
        )!!
        assertEquals(WeatherCategory.RAIN, summary.category)
        assertEquals(2, summary.hourCount)
    }

    @Test
    fun awaiting_data_false_when_disabled_or_failed() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val gateway = FakeGateway().apply { forecast = null }
        val provider = provider(gateway, clock = { now })

        assertFalse(provider.isAwaitingData) // 还没开
        provider.setEnabled(true)
        provider.setLocation(hangzhou) // 取数失败 → FAILED
        assertFalse(provider.isAwaitingData)
    }

    @Test
    fun search_delegates_to_gateway() {
        val gateway = FakeGateway().apply { searchResult = listOf(hangzhou) }
        val provider = provider(gateway, clock = { LocalDateTime.of(2026, 10, 28, 8, 0) })
        assertEquals(1, provider.searchLocations("杭州").size)
    }

    @Test
    fun initialize_reads_persisted_state_and_keeps_fresh_cache() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val store = InMemoryKeyValueStore()
        WeatherPreferences(store).apply {
            setEnabled(true)
            saveLocation(hangzhou)
            saveForecast(forecastAt(now))
        }
        val gateway = FakeGateway() // 返回 null 也无所谓：新鲜缓存不该触发请求
        val provider = WeatherProvider(
            gateway,
            WeatherPreferences(store),
            FakeLocationSource(DeviceLocationOutcome.failure(DeviceLocationFailure.TIMEOUT)),
            { now },
        )

        provider.initialize()

        assertTrue(provider.enabled)
        assertEquals("杭州", provider.location?.name)
        assertNotNull(provider.forecast)
        assertEquals(0, gateway.fetchCount) // 缓存新鲜 → 不补请求
    }

    @Test
    fun initialize_drops_cache_from_another_city() {
        var now = LocalDateTime.of(2026, 10, 28, 8, 0)
        val store = InMemoryKeyValueStore()
        val chengduForecast = WeatherForecast(
            30.57,
            104.07,
            now,
            listOf(HourlyWeatherPoint(now.plusHours(1), 20.0, 60, null, null, 61)),
        )
        WeatherPreferences(store).apply {
            setEnabled(true)
            saveLocation(hangzhou) // 选的是杭州
            saveForecast(chengduForecast) // 缓存却是成都
        }
        val gateway = FakeGateway().apply { forecast = forecastAt(now) }
        val provider = WeatherProvider(
            gateway,
            WeatherPreferences(store),
            FakeLocationSource(DeviceLocationOutcome.failure(DeviceLocationFailure.TIMEOUT)),
            { now },
        )

        provider.initialize()

        // 缓存城市与所选城市不一致 → 必须丢弃并重拉。
        assertEquals("杭州", provider.location?.name)
        assertEquals(1, gateway.fetchCount)
    }
}
