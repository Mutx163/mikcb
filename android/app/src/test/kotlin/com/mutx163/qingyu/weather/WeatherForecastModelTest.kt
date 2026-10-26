package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * WeatherLocation / WeatherForecast：模型行为与 JSON 契约（字段名逐字一致）。
 *
 * 期望值来源：[Dart抄录] test/services/weather_service_test.dart（模型断言部分），
 * 其余为 [Dart推演]（对照 lib/models/weather_forecast.dart 的实现语义）。
 */
class WeatherForecastModelTest {

    private val hangzhou = WeatherLocation(
        name = "杭州",
        latitude = 30.29365,
        longitude = 120.16142,
        admin1 = "浙江",
        country = "中国",
        timezone = "Asia/Shanghai",
    )

    private val gazhu = WeatherLocation(
        name = "杭州",
        latitude = 30.06517,
        longitude = 102.19527,
        admin1 = "四川",
        country = "中国",
        timezone = "Asia/Shanghai",
    )

    // ---------- WeatherLocation ----------

    @Test
    fun `region label skips empty duplicate and keeps admin`() { // [Dart抄录] weather_service_test:262
        assertEquals("浙江 · 中国", hangzhou.regionLabel)
        assertEquals("四川 · 中国", gazhu.regionLabel)
    }

    @Test
    fun `region label with no admin gives empty`() { // [Dart抄录] weather_service_test:494
        val bare = WeatherLocation(name = "杭州市", latitude = 30.29, longitude = 120.16)
        assertEquals("", bare.regionLabel)
    }

    @Test
    fun `displayName joins district only when meaningful`() { // [Dart抄录] weather_service_test:384, 434
        val withDistrict = hangzhou.copy(district = "拱墅区")
        assertEquals("杭州 · 拱墅区", withDistrict.displayName)
        // 区名与市名相同时不重复记。
        assertEquals("铜梁区", WeatherLocation(name = "铜梁区", latitude = 29.86, longitude = 106.03).displayName)
    }

    @Test
    fun `same place compares on coarsened coords`() { // [Dart抄录] weather_service_test:265-268 同名不同地必须区分开
        assertTrue(!hangzhou.isSamePlaceAs(gazhu))
        // 5 位与 2 位小数是同一地点（内存旧数据 vs 落盘数据）。
        assertTrue(
            hangzhou.isSamePlaceAs(
                WeatherLocation(name = "杭州", latitude = 30.29, longitude = 120.16),
            ),
        )
    }

    @Test
    fun `coarsened keeps name and drops precision`() { // [Dart推演] coarsened() 拷贝语义
        val coarsened = hangzhou.coarsened()
        assertEquals("杭州", coarsened.name)
        assertEquals("浙江", coarsened.admin1)
        assertEquals(30.29, coarsened.latitude, 0.0)
        assertEquals(120.16, coarsened.longitude, 0.0)
    }

    @Test
    fun `location json contract keeps field names`() { // [Dart抄录] toJson 的键逐字一致
        val json = hangzhou.toJson()
        assertEquals(listOf("name", "admin1", "country", "district", "latitude", "longitude", "timezone"), json.keys.toList())
        assertNull(json["district"])
        assertEquals("杭州", json["name"])
    }

    @Test
    fun `location json round trip`() { // [Dart推演]
        val restored = WeatherLocation.fromJson(MiniJsonMap.of(hangzhou.toJson()))
        assertEquals(hangzhou, restored)
    }

    @Test
    fun `location from json rejects missing name or coords`() { // [Dart推演] 结构性缺失抛 FormatException
        assertThrowsFormat {
            WeatherLocation.fromJson(linkedMapOf("latitude" to 30.0, "longitude" to 120.0))
        }
        assertThrowsFormat {
            WeatherLocation.fromJson(linkedMapOf("name" to "杭州"))
        }
        // 空白名字同缺失。
        assertThrowsFormat {
            WeatherLocation.fromJson(linkedMapOf("name" to "   ", "latitude" to 30.0, "longitude" to 120.0))
        }
    }

    @Test
    fun `location from json tolerates wrong types on optional fields`() { // [Dart推演] is String ?: null 口径
        val parsed = WeatherLocation.fromJson(
            linkedMapOf(
                "name" to "杭州",
                "admin1" to 42L,
                "country" to true,
                "district" to listOf<String>(),
                "timezone" to 1.5,
                "latitude" to 30.29,
                "longitude" to 120.16,
            ),
        )
        assertNull(parsed.admin1)
        assertNull(parsed.country)
        assertNull(parsed.district)
        assertNull(parsed.timezone)
    }

    @Test
    fun `tryDecode tolerates garbage`() { // [Dart抄录] weather_service_test:589-594 城市数据损坏时按未设置处理
        assertNull(WeatherLocation.tryDecode(null))
        assertNull(WeatherLocation.tryDecode("   "))
        assertNull(WeatherLocation.tryDecode("not json"))
        assertNull(WeatherLocation.tryDecode("[1,2,3]"))
        assertNull(WeatherLocation.tryDecode("""{"latitude":1}"""))
        assertNull(WeatherLocation.tryDecode("""{"name":"  ","latitude":30.0,"longitude":120.0}"""))
        val restored = WeatherLocation.tryDecode(MiniJson.encode(hangzhou.toJson()))
        assertEquals(hangzhou, restored)
    }

    // ---------- HourlyWeatherPoint / WeatherForecast ----------

    private fun point(time: String, temp: Double? = null): HourlyWeatherPoint =
        HourlyWeatherPoint(time = com.mutx163.qingyu.core.DartTime.parseIso(time), temperatureC = temp)

    @Test
    fun `forecast sorts hourly ascending`() { // [Dart推演] 构造器拷贝并按时间升序
        val forecast = WeatherForecast(
            latitude = 30.0,
            longitude = 120.0,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
            hourly = listOf(
                point("2026-09-18T10:00"),
                point("2026-09-18T08:00"),
                point("2026-09-18T09:00"),
            ),
        )
        assertEquals(
            listOf(8, 9, 10),
            forecast.hourly.map { it.time.hour },
        )
    }

    @Test
    fun `window start end and covers`() { // [Dart推演] covers 含端点
        val forecast = WeatherForecast(
            latitude = 30.0,
            longitude = 120.0,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 0),
            hourly = listOf(
                point("2026-09-18T08:00"),
                point("2026-09-18T09:00"),
                point("2026-09-18T10:00"),
            ),
        )
        assertEquals(LocalDateTime.of(2026, 9, 18, 8, 0), forecast.windowStart)
        assertEquals(LocalDateTime.of(2026, 9, 18, 10, 0), forecast.windowEnd)
        assertTrue(forecast.covers(LocalDateTime.of(2026, 9, 18, 8, 0)))
        assertTrue(forecast.covers(LocalDateTime.of(2026, 9, 18, 10, 0)))
        assertTrue(forecast.covers(LocalDateTime.of(2026, 9, 18, 9, 30)))
        assertFalse(forecast.covers(LocalDateTime.of(2026, 9, 18, 7, 59)))
        assertFalse(forecast.covers(LocalDateTime.of(2026, 9, 18, 10, 1)))
    }

    @Test
    fun `empty forecast lapses immediately`() { // [Dart推演] windowEnd 为 null 时 hasLapsedAt 恒真
        val empty = WeatherForecast(
            latitude = 30.0,
            longitude = 120.0,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 0),
            hourly = emptyList(),
        )
        assertNull(empty.windowStart)
        assertNull(empty.windowEnd)
        assertFalse(empty.covers(LocalDateTime.of(2026, 9, 18, 8, 0)))
        assertTrue(empty.hasLapsedAt(LocalDateTime.of(2026, 9, 18, 6, 0)))
    }

    @Test
    fun `hasLapsedAt only after window end`() { // [Dart推演]
        val forecast = WeatherForecast(
            latitude = 30.0,
            longitude = 120.0,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 0),
            hourly = listOf(point("2026-09-18T08:00"), point("2026-09-18T10:00")),
        )
        assertFalse(forecast.hasLapsedAt(LocalDateTime.of(2026, 9, 18, 10, 0)))
        assertTrue(forecast.hasLapsedAt(LocalDateTime.of(2026, 9, 18, 10, 1)))
    }

    @Test
    fun `matchesLocation coarsens before comparing`() { // [Dart推演] 同 isSamePlaceAs 口径
        val forecast = WeatherForecast(
            latitude = 30.29,
            longitude = 120.16,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 0),
            hourly = listOf(point("2026-09-18T08:00")),
        )
        assertTrue(forecast.matchesLocation(hangzhou))
        assertTrue(!forecast.matchesLocation(gazhu))
    }

    // ---------- 列式 JSON 契约 ----------

    @Test
    fun `columnar json keys and wall clock iso`() { // [Dart推演] toJson 的键与墙钟 ISO 口径
        val forecast = WeatherForecast(
            latitude = 30.29,
            longitude = 120.16,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
            hourly = listOf(
                HourlyWeatherPoint(
                    time = LocalDateTime.of(2026, 9, 18, 8, 0),
                    temperatureC = 25.1,
                    precipitationProbability = 8,
                    precipitationMm = 0.0,
                    snowfallCm = 0.0,
                    weatherCode = 3,
                ),
            ),
        )
        val json = forecast.toJson()
        assertEquals(
            listOf(
                "latitude", "longitude", "fetchedAt", "time",
                "temperature_2m", "precipitation_probability", "precipitation",
                "snowfall", "weather_code",
            ),
            json.keys.toList(),
        )
        assertEquals(listOf("2026-09-18T08:00"), json["time"])
        // 毫秒不含 .000 尾巴、UTC 不加 Z：墙钟存取一致。
        assertTrue(!(json["time"] as List<*>)[0].toString().contains("."))
        assertEquals(25.1, (json["temperature_2m"] as List<*>)[0])
    }

    @Test
    fun `columnar round trip preserves points`() { // [Dart推演]
        val forecast = WeatherForecast(
            latitude = 30.29,
            longitude = 120.16,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
            hourly = listOf(
                HourlyWeatherPoint(
                    time = LocalDateTime.of(2026, 9, 18, 8, 0),
                    temperatureC = 25.1,
                    precipitationProbability = 8,
                    precipitationMm = 0.2,
                    snowfallCm = null,
                    weatherCode = 3,
                ),
                HourlyWeatherPoint(
                    time = LocalDateTime.of(2026, 9, 18, 9, 0),
                    temperatureC = null,
                    precipitationProbability = null,
                    precipitationMm = null,
                    snowfallCm = null,
                    weatherCode = null,
                ),
            ),
        )
        val restored = WeatherForecast.fromJson(MiniJsonMap.of(forecast.toJson()))
        assertEquals(forecast.latitude, restored.latitude, 0.0)
        assertEquals(forecast.longitude, restored.longitude, 0.0)
        assertEquals(forecast.fetchedAt, restored.fetchedAt)
        assertEquals(2, restored.hourly.size)
        assertEquals(25.1, restored.hourly[0].temperatureC!!, 1e-9)
        assertEquals(8L, restored.hourly[0].precipitationProbability!!.toLong())
        assertEquals(0.2, restored.hourly[0].precipitationMm!!, 1e-9)
        assertEquals(3L, restored.hourly[0].weatherCode!!.toLong())
        assertNull(restored.hourly[1].temperatureC)
        assertNull(restored.hourly[1].weatherCode)
    }

    @Test
    fun `fromJson rejects missing header`() { // [Dart推演] 缺 header 抛 FormatException
        assertThrowsFormat { WeatherForecast.fromJson(linkedMapOf("latitude" to 30.0)) }
        assertThrowsFormat { WeatherForecast.fromJson(linkedMapOf("latitude" to 30.0, "longitude" to 120.0)) }
    }

    @Test
    fun `openMeteo response parses real shape`() { // [Dart抄录] weather_service_test 的 _forecastPayload
        val payload = linkedMapOf<String, Any?>(
            "latitude" to 30.263618,
            "longitude" to 120.14051,
            "utc_offset_seconds" to 28800L,
            "timezone" to "Asia/Shanghai",
            "hourly_units" to linkedMapOf<String, Any?>(
                "time" to "iso8601",
                "temperature_2m" to "°C",
            ),
            "hourly" to linkedMapOf<String, Any?>(
                "time" to listOf("2026-09-18T08:00", "2026-09-18T09:00", "2026-09-18T10:00"),
                "temperature_2m" to listOf(25.1, 25.8, 27.6),
                "precipitation_probability" to listOf(8L, 0L, 42L),
                "precipitation" to listOf(0.0, 0.0, 0.2),
                "snowfall" to listOf(0.0, 0.0, 0.0),
                "weather_code" to listOf(3L, 2L, 61L),
            ),
        )
        val forecast = WeatherForecast.fromOpenMeteoResponse(
            payload,
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
        )
        assertEquals(3, forecast.hourly.size)
        // 经纬度取响应回填的格点中心（不是请求坐标）。
        assertEquals(30.263618, forecast.latitude, 1e-9)
        assertEquals(120.14051, forecast.longitude, 1e-9)
        val first = forecast.hourly[0]
        assertEquals(LocalDateTime.of(2026, 9, 18, 8, 0), first.time)
        assertEquals(25.1, first.temperatureC!!, 1e-9)
        assertEquals(8L, first.precipitationProbability!!.toLong())
        assertEquals(0.0, first.precipitationMm!!, 1e-9)
        assertEquals(0.0, first.snowfallCm!!, 1e-9)
        assertEquals(3L, first.weatherCode!!.toLong())
        assertEquals(61L, forecast.hourly[2].weatherCode!!.toLong())
        assertEquals(42L, forecast.hourly[2].precipitationProbability!!.toLong())
    }

    @Test
    fun `openMeteo response rejects missing hourly block`() { // [Dart抄录] 缺 hourly 块抛 FormatException
        assertThrowsFormat {
            WeatherForecast.fromOpenMeteoResponse(
                linkedMapOf("latitude" to 30.26, "longitude" to 120.14),
                fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
            )
        }
        assertThrowsFormat {
            WeatherForecast.fromOpenMeteoResponse(
                linkedMapOf("hourly" to "not a map"),
                fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
            )
        }
    }

    @Test
    fun `openMeteo keeps grid center coords`() { // [Dart抄录] weather_service_test:115-117
        val forecast = WeatherForecast.fromOpenMeteoResponse(
            linkedMapOf<String, Any?>(
                "latitude" to 30.263618,
                "longitude" to 120.14051,
                "hourly" to linkedMapOf<String, Any?>(
                    "time" to listOf("2026-09-18T08:00"),
                    "temperature_2m" to listOf(25.1),
                ),
            ),
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
        )
        assertEquals(30.263618, forecast.latitude, 1e-9)
        assertEquals(120.14051, forecast.longitude, 1e-9)
    }

    @Test
    fun `openMeteo skips bad time entries`() { // [Dart推演] rawTime 非 String / 解析失败逐点跳过
        val forecast = WeatherForecast.fromOpenMeteoResponse(
            linkedMapOf<String, Any?>(
                "latitude" to 30.0,
                "longitude" to 120.0,
                "hourly" to linkedMapOf<String, Any?>(
                    "time" to listOf("2026-09-18T08:00", 42L, "not-a-time", "2026-09-18T10:00"),
                    "temperature_2m" to listOf(25.1, 25.8, 25.8, 27.6),
                ),
            ),
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
        )
        assertEquals(listOf(8, 10), forecast.hourly.map { it.time.hour })
    }

    @Test
    fun `column index beyond length reads null`() { // [Dart推演] 各列长度不齐时越界读 null
        val forecast = WeatherForecast.fromOpenMeteoResponse(
            linkedMapOf<String, Any?>(
                "latitude" to 30.0,
                "longitude" to 120.0,
                "hourly" to linkedMapOf<String, Any?>(
                    "time" to listOf("2026-09-18T08:00", "2026-09-18T09:00"),
                    "temperature_2m" to listOf(25.1),
                    "weather_code" to listOf(3L, 2L),
                ),
            ),
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
        )
        assertEquals(25.1, forecast.hourly[0].temperatureC!!, 1e-9)
        assertNull(forecast.hourly[1].temperatureC)
        assertEquals(2L, forecast.hourly[1].weatherCode!!.toLong())
    }

    @Test
    fun `tryDecode tolerates garbage and empty hourly`() { // [Dart抄录] weather_service_test:616-621 + 逐字语义
        assertNull(WeatherForecast.tryDecode(null))
        assertNull(WeatherForecast.tryDecode("   "))
        assertNull(WeatherForecast.tryDecode("{not json"))
        assertNull(WeatherForecast.tryDecode("[1,2,3]"))
        assertNull(WeatherForecast.tryDecode("""{"latitude":1}"""))
        // 没有任何小时点 → null。
        assertNull(
            WeatherForecast.tryDecode(
                """{"latitude":30.0,"longitude":120.0,"fetchedAt":1758165000000,"time":[],""" +
                    """"temperature_2m":[],"precipitation_probability":[],"precipitation":[],"snowfall":[],"weather_code":[]}""",
            ),
        )
    }

    @Test
    fun `tryDecode round trips a real forecast`() { // [Dart推演]
        val forecast = WeatherForecast.fromOpenMeteoResponse(
            linkedMapOf<String, Any?>(
                "latitude" to 30.263618,
                "longitude" to 120.14051,
                "hourly" to linkedMapOf<String, Any?>(
                    "time" to listOf("2026-09-18T08:00", "2026-09-18T09:00", "2026-09-18T10:00"),
                    "temperature_2m" to listOf(25.1, 25.8, 27.6),
                    "precipitation_probability" to listOf(8L, 0L, 42L),
                    "precipitation" to listOf(0.0, 0.0, 0.2),
                    "snowfall" to listOf(0.0, 0.0, 0.0),
                    "weather_code" to listOf(3L, 2L, 61L),
                ),
            ),
            fetchedAt = LocalDateTime.of(2026, 9, 18, 6, 30),
        )
        val restored = WeatherForecast.tryDecode(MiniJson.encode(forecast.toJson()))
        assertEquals(3, restored!!.hourly.size)
        assertEquals(LocalDateTime.of(2026, 9, 18, 10, 0), restored.hourly[2].time)
        assertEquals(42L, restored.hourly[2].precipitationProbability!!.toLong())
        assertEquals(61L, restored.hourly[2].weatherCode!!.toLong())
        assertEquals(LocalDateTime.of(2026, 9, 18, 6, 30), restored.fetchedAt)
    }

    private fun assertThrowsFormat(block: () -> Unit) {
        try {
            block()
        } catch (expected: com.mutx163.qingyu.core.DartFormatException) {
            return
        }
        throw AssertionError("expected DartFormatException")
    }
}

/** 测试辅助：把 kotlin 的 Map 透传成 fromJson 需要的形状。 */
private object MiniJsonMap {
    fun of(map: Map<String, Any?>): Map<String, Any?> = map
}
