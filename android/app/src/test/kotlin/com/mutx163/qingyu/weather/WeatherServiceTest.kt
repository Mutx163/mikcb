package com.mutx163.qingyu.weather

import com.mutx163.qingyu.infra.AppLogStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.time.LocalDateTime

/**
 * 天气取数服务（Dart `lib/services/weather_service.dart` 的移植）的解析层。
 *
 * 用假 [WeatherHttp] 注入固定响应，验证「URL 拼装 → JSON 解析 → 模型」这条纯逻辑链，
 * 不触网。期望值来自 [Dart推演]（对照 Dart `_parseLocation` / `searchLocations` 语义）。
 */
class WeatherServiceTest {

    private class FakeHttp(private val routes: List<Pair<String, String?>>) : WeatherHttp {
        val calls = mutableListOf<String>()
        override fun get(url: String): String? {
            calls.add(url)
            for ((fragment, body) in routes) {
                if (url.contains(fragment)) return body
            }
            return null
        }
    }

    private val fixedNow = LocalDateTime.of(2026, 10, 28, 8, 0)

    private fun service(vararg routes: Pair<String, String?>): Pair<WeatherService, FakeHttp> {
        val http = FakeHttp(routes.toList())
        return WeatherService(http, now = { fixedNow }) to http
    }

    // ---------- 地名搜索 ----------

    @Test
    fun search_parses_results_and_coarsens_coordinates() {
        val json = """
            {"results":[
              {"name":"杭州","latitude":30.29365,"longitude":120.16142,"admin1":"浙江","country":"中国","timezone":"Asia/Shanghai"},
              {"name":"杭州","latitude":30.06517,"longitude":102.19527,"admin1":"四川","country":"中国"}
            ]}
        """.trimIndent()
        val (svc, _) = service("geocoding-api" to json)
        val results = svc.searchLocations("杭州")!!

        assertEquals(2, results.size)
        assertEquals("杭州", results[0].name)
        assertEquals(30.29, results[0].latitude, 1e-9) // 30.29365 → 30.29
        assertEquals(120.16, results[0].longitude, 1e-9)
        assertEquals("浙江", results[0].admin1)
        assertEquals(30.07, results[1].latitude, 1e-9)
        assertEquals(102.2, results[1].longitude, 1e-9) // 102.19527 → 102.2
    }

    @Test
    fun search_short_query_short_circuits_without_http() {
        val (svc, http) = service()
        // 少于 2 字不算失败：没发请求，就是「没有结果」。
        assertTrue(svc.searchLocations("杭")!!.isEmpty())
        assertTrue(http.calls.isEmpty())
    }

    @Test
    fun search_http_failure_returns_null_not_empty() {
        val (svc, _) = service() // 没有任何路由 → http 返回 null
        // null = 请求失败（界面显示「搜索失败」+ 重试）；空表 = 搜到了但没有。
        // 两者共用空表就是本条要挡的回归：断网会被说成「这个城市不存在」。
        assertNull(svc.searchLocations("杭州"))
    }

    @Test
    fun search_unparsable_body_returns_null_not_empty() {
        val (svc, _) = service("geocoding-api" to "<html>502 Bad Gateway</html>")
        assertNull(svc.searchLocations("杭州"))
    }

    @Test
    fun search_missing_results_returns_empty() {
        // 合法 JSON 但没有 results：接口说「搜到了、没匹配」，这是真空结果不是故障。
        val (svc, _) = service("geocoding-api" to """{"generationtime_ms":0.1}""")
        assertTrue(svc.searchLocations("杭州")!!.isEmpty())
    }

    // ---------- 反查 / IP 估算 ----------

    @Test
    fun reverse_geocode_uses_fallback_coordinates_and_locality_as_district() {
        val json = """
            {"city":"杭州","locality":"拱墅区","principalSubdivision":"浙江省","countryName":"中国"}
        """.trimIndent()
        val (svc, _) = service("reverse-geocode-client" to json)
        val location = svc.reverseGeocode(30.29365, 120.16142)!!

        assertEquals("杭州", location.name)
        assertEquals("拱墅区", location.district)
        assertEquals("浙江省", location.admin1)
        assertEquals(30.29, location.latitude, 1e-9)
        assertEquals(120.16, location.longitude, 1e-9)
    }

    @Test
    fun reverse_geocode_drops_district_when_same_as_name() {
        // 直辖市政区反查会给出同名的 city 与 locality。
        val json = """{"city":"重庆","locality":"重庆","principalSubdivision":"重庆市","countryName":"中国"}"""
        val (svc, _) = service("reverse-geocode-client" to json)
        assertNull(svc.reverseGeocode(29.56, 106.55)!!.district)
    }

    @Test
    fun network_geocode_reads_coordinates_from_response() {
        val json = """
            {"city":"杭州","locality":"西湖区","latitude":30.26,"longitude":120.13,"principalSubdivision":"浙江省","countryName":"中国"}
        """.trimIndent()
        val (svc, _) = service("reverse-geocode-client" to json)
        val location = svc.networkGeocode()!!
        assertEquals("杭州", location.name)
        assertEquals(30.26, location.latitude, 1e-9)
        assertEquals(120.13, location.longitude, 1e-9)
    }

    // ---------- 预报 ----------

    @Test
    fun fetch_forecast_parses_hourly_columns() {
        val json = """
            {"latitude":30.25,"longitude":120.16,"hourly":{
              "time":["2026-10-28T09:00","2026-10-28T10:00"],
              "temperature_2m":[20.4,21.6],
              "precipitation_probability":[80,60],
              "precipitation":[0,0.2],
              "snowfall":[0,0],
              "weather_code":[61,63]
            }}
        """.trimIndent()
        val (svc, _) = service("api.open-meteo.com/v1/forecast" to json)
        val location = WeatherLocation("杭州", 30.29, 120.16, timezone = "Asia/Shanghai")
        val forecast = svc.fetchForecast(location)!!

        assertEquals(2, forecast.hourly.size)
        assertEquals(20.4, forecast.hourly[0].temperatureC!!, 1e-9)
        assertEquals(80, forecast.hourly[0].precipitationProbability)
        assertEquals(61, forecast.hourly[0].weatherCode)
        assertEquals(fixedNow, forecast.fetchedAt)
    }

    @Test
    fun fetch_forecast_returns_null_on_empty_hourly() {
        val json = """{"latitude":30.25,"longitude":120.16,"hourly":{"time":[]}}"""
        val (svc, _) = service("api.open-meteo.com/v1/forecast" to json)
        val location = WeatherLocation("杭州", 30.29, 120.16)
        assertNull(svc.fetchForecast(location))
    }

    @Test
    fun fetch_forecast_returns_null_on_http_failure() {
        val (svc, _) = service()
        val location = WeatherLocation("杭州", 30.29, 120.16)
        assertNull(svc.fetchForecast(location))
    }

    // ---------- 失败分类与网络日志（2026-11-14 A 类：打开就能看到原因）----------

    private class ClassifiedHttp(private val result: WeatherHttpResult) : WeatherHttp {
        override fun get(url: String): String? = result.body
        override fun getDetailed(url: String): WeatherHttpResult = result
    }

    @Test
    fun timeout_is_reported_with_elapsed_and_error_class() {
        val http = ClassifiedHttp(
            WeatherHttpResult(
                failure = WeatherFetchFailure.TIMEOUT,
                elapsedMs = 20_000,
                errorClass = "SocketTimeoutException",
            ),
        )
        val result = WeatherService(http, now = { fixedNow })
            .fetchForecastWithDiagnostics(WeatherLocation("北京", 39.91, 116.4))

        assertNull(result.forecast)
        assertEquals(WeatherFetchFailure.TIMEOUT, result.diagnostics.failure)
        assertEquals(20_000L, result.diagnostics.elapsedMs)
        assertEquals("SocketTimeoutException", result.diagnostics.errorClass)
    }

    @Test
    fun non_200_is_reported_with_status_code() {
        val http = ClassifiedHttp(
            WeatherHttpResult(
                httpStatus = 503,
                failure = WeatherFetchFailure.HTTP_STATUS,
                elapsedMs = 42,
                bodyBytes = 0,
                errorClass = "HTTP",
            ),
        )
        val result = WeatherService(http, now = { fixedNow })
            .fetchForecastWithDiagnostics(WeatherLocation("北京", 39.91, 116.4))

        assertNull(result.forecast)
        assertEquals(WeatherFetchFailure.HTTP_STATUS, result.diagnostics.failure)
        assertEquals(503, result.diagnostics.httpStatus)
    }

    @Test
    fun not_json_reports_body_line() {
        val (svc, _) = service("api.open-meteo.com/v1/forecast" to "<html>502</html>")
        val result = svc.fetchForecastWithDiagnostics(WeatherLocation("北京", 39.91, 116.4))

        assertNull(result.forecast)
        assertEquals(WeatherFetchFailure.NOT_JSON, result.diagnostics.failure)
        val detail = result.diagnostics.detail!!
        assertTrue("detail 必须写字段：$detail", detail.contains("field=body"))
        assertTrue("detail 必须写响应行：$detail", detail.contains("line=1"))
    }

    @Test
    fun missing_hourly_reports_field_and_code_line() {
        val json = """{"latitude":39.91,"longitude":116.4}"""
        val (svc, _) = service("api.open-meteo.com/v1/forecast" to json)
        val result = svc.fetchForecastWithDiagnostics(WeatherLocation("北京", 39.91, 116.4))

        assertNull(result.forecast)
        assertEquals(WeatherFetchFailure.PARSE, result.diagnostics.failure)
        val detail = result.diagnostics.detail!!
        assertTrue("缺 hourly 必须写字段：$detail", detail.contains("field=hourly"))
        assertTrue("解析失败必须写代码行：$detail", detail.contains("at=WeatherForecast.kt"))
    }

    @Test
    fun empty_hourly_reports_field() {
        val json = """{"latitude":30.25,"longitude":120.16,"hourly":{"time":[]}}"""
        val (svc, _) = service("api.open-meteo.com/v1/forecast" to json)
        val result = svc.fetchForecastWithDiagnostics(WeatherLocation("杭州", 30.29, 120.16))

        assertNull(result.forecast)
        assertEquals(WeatherFetchFailure.EMPTY, result.diagnostics.failure)
        assertTrue(result.diagnostics.detail!!.contains("field=hourly.time"))
    }

    @Test
    fun parse_failure_writes_one_network_log_line_with_detail() {
        val dir = Files.createTempDirectory("mikcb-weather-netlog-parse").toFile()
        AppLogStore.initialize(dir)
        AppLogStore.clear()
        val (svc, _) = service("api.open-meteo.com/v1/forecast" to "<html>502</html>")
        svc.fetchForecast(WeatherLocation("杭州", 30.29, 120.16, timezone = "Asia/Shanghai"))

        val text = AppLogStore.readText()
        assertTrue("没有写网络日志：$text", text.contains("category=network"))
        assertTrue(text, text.contains("host=api.open-meteo.com"))
        assertTrue(text, text.contains("path=/v1/forecast"))
        assertTrue("解析失败必须写分类：$text", text.contains("failure=not_json"))
        assertTrue("解析失败必须写字段与行号：$text", text.contains("detail=field=body"))
        // 隐私：query 里的经纬度不能进日志。
        assertFalse("坐标进了日志：$text", text.contains("latitude="))
        assertFalse("坐标进了日志：$text", text.contains("longitude="))
    }
}
