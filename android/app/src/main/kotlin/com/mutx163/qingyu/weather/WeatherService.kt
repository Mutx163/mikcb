package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDateTime

/**
 * Dart `lib/services/weather_service.dart` 的移植。
 *
 * 三个端点（与 Dart 逐字一致）：
 * - Open-Meteo 预报 `https://api.open-meteo.com/v1/forecast`
 * - Open-Meteo 正向地理编码（按名字搜城市）`https://geocoding-api.open-meteo.com/v1/search`
 * - BigDataCloud 反查/按 IP 估算 `https://api.bigdatacloud.net/data/reverse-geocode-client`
 *
 * **纯 Kotlin（只用 JDK 的 [HttpURLConnection]，零新依赖）**：这样 `weather/` 能进
 * `scripts/test-kotlin-module.ps1` 的 JVM 单测 classpath（那里只有 kotlin-stdlib + junit）。
 * 失败一律返回 null / 空列表，绝不向上抛（天气是装饰性信息）。
 */

/** 天气取数的四个动作（[WeatherService] 的实现契约，供单测注入假件）。 */
interface WeatherGateway {
    fun fetchForecast(location: WeatherLocation): WeatherForecast?
    fun searchLocations(query: String): List<WeatherLocation>
    fun reverseGeocode(latitude: Double, longitude: Double): WeatherLocation?
    fun networkGeocode(): WeatherLocation?
}

/** 一个「GET 一个 URL，返回 body 文本或 null」的接缝（真实实现走 [HttpURLConnection]）。 */
interface WeatherHttp {
    fun get(url: String): String?
}

/**
 * 真实 HTTP 实现：JDK [HttpURLConnection]。
 *
 * 显式按 UTF-8 读 body（中文城市名落 latin1 会变乱码）；任何异常返回 null。
 */
class JdkWeatherHttp(
    private val timeoutMillis: Int = 10_000,
) : WeatherHttp {
    override fun get(url: String): String? {
        val connection = try {
            (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = timeoutMillis
                readTimeout = timeoutMillis
                setRequestProperty("Accept", "application/json")
                setRequestProperty("User-Agent", "mikcb-weather")
            }
        } catch (_: Exception) {
            return null
        }
        return try {
            if (connection.responseCode != 200) return null
            val bytes = connection.inputStream.use { it.readBytes() }
            String(bytes, Charsets.UTF_8)
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }
}

/** 天气与地名数据访问（构造与解析，不做缓存/节流/过期判定——那些在 [WeatherProvider]）。 */
class WeatherService(
    private val http: WeatherHttp,
    private val now: () -> LocalDateTime = { LocalDateTime.now() },
) : WeatherGateway {

    companion object {
        const val FORECAST_BASE_URL = "https://api.open-meteo.com/v1/forecast"
        const val GEOCODING_BASE_URL = "https://geocoding-api.open-meteo.com/v1/search"
        const val REVERSE_GEOCODE_BASE_URL = "https://api.bigdatacloud.net/data/reverse-geocode-client"

        /** 请求的逐小时变量（字段名即接口契约）。 */
        const val HOURLY_VARIABLES =
            "temperature_2m,precipitation_probability,precipitation,snowfall,weather_code"

        /** 回溯 1 天：当天已上完的课也能显示天气。 */
        const val PAST_DAYS = 1

        /** 预报窗口 16 天（接口上限）。 */
        const val FORECAST_DAYS = 16
    }

    /** 按关键字搜索地点；名字不足 2 字符直接短路（接口只返回空）。 */
    override fun searchLocations(query: String): List<WeatherLocation> {
        val trimmed = query.trim()
        if (trimmed.length < 2) return emptyList()

        val body = http.get(
            buildUrl(
                GEOCODING_BASE_URL,
                listOf(
                    "name" to trimmed,
                    "count" to "10",
                    "language" to "zh",
                    "format" to "json",
                ),
            ),
        ) ?: return emptyList()

        val json = parseObject(body) ?: return emptyList()
        val results = json["results"]
        if (results !is List<*>) return emptyList()

        val locations = ArrayList<WeatherLocation>()
        for (item in results) {
            if (item !is Map<*, *>) continue
            val name = (item["name"] as? String)?.trim()
            val latitude = (item["latitude"] as? Number)?.toDouble()
            val longitude = (item["longitude"] as? Number)?.toDouble()
            if (name.isNullOrEmpty() || latitude == null || longitude == null) continue
            locations.add(
                WeatherLocation(
                    name = name,
                    admin1 = item["admin1"] as? String,
                    country = item["country"] as? String,
                    district = item["district"] as? String,
                    // 产出坐标一律取整（隐私承诺：约 1 公里精度）。
                    latitude = coarsenCoordinate(latitude),
                    longitude = coarsenCoordinate(longitude),
                    timezone = item["timezone"] as? String,
                ),
            )
        }
        return locations
    }

    /** 按坐标反查可读地名（BigDataCloud）；失败或解析不出地名时返回 null。 */
    override fun reverseGeocode(latitude: Double, longitude: Double): WeatherLocation? {
        val coarsenedLatitude = coarsenCoordinate(latitude)
        val coarsenedLongitude = coarsenCoordinate(longitude)
        val body = http.get(
            buildUrl(
                REVERSE_GEOCODE_BASE_URL,
                listOf(
                    "latitude" to coarsenedLatitude.toString(),
                    "longitude" to coarsenedLongitude.toString(),
                    // 必须 zh-Hans：传 zh / zh-CN 会返回繁体。
                    "localityLanguage" to "zh-Hans",
                ),
            ),
        ) ?: return null
        return parseLocation(body, coarsenedLatitude, coarsenedLongitude)
    }

    /** 按网络出口 IP 估算所在地（同一接口，不带坐标）；结果必须由界面标注为「估算」。 */
    override fun networkGeocode(): WeatherLocation? {
        val body = http.get(
            buildUrl(REVERSE_GEOCODE_BASE_URL, listOf("localityLanguage" to "zh-Hans")),
        ) ?: return null
        return parseLocation(body, null, null)
    }

    /** 拉取 [location] 的逐小时预报；失败或没有有效数据时返回 null。 */
    override fun fetchForecast(location: WeatherLocation): WeatherForecast? {
        val body = http.get(
            buildUrl(
                FORECAST_BASE_URL,
                listOf(
                    "latitude" to coarsenCoordinate(location.latitude).toString(),
                    "longitude" to coarsenCoordinate(location.longitude).toString(),
                    // 用城市自己的时区，别让服务端按请求 IP 猜；hourly.time 是不带偏移的墙钟串。
                    "timezone" to (location.timezone ?: "auto"),
                    "hourly" to HOURLY_VARIABLES,
                    "past_days" to PAST_DAYS.toString(),
                    "forecast_days" to FORECAST_DAYS.toString(),
                ),
            ),
        ) ?: return null
        val json = parseObject(body) ?: return null
        return try {
            val forecast = WeatherForecast.fromOpenMeteoResponse(typed(json), now())
            if (forecast.hourly.isEmpty()) null else forecast
        } catch (_: Exception) {
            null
        }
    }

    // ---------- 内部 ----------

    /** 反查与 IP 估算响应字段完全一样，共用一份解析（市级名 city 优先，其次 locality）。 */
    private fun parseLocation(
        body: String,
        fallbackLatitude: Double?,
        fallbackLongitude: Double?,
    ): WeatherLocation? {
        val json = parseObject(body) ?: return null
        val name = text(json["city"]) ?: text(json["locality"]) ?: return null
        val latitude = fallbackLatitude ?: (json["latitude"] as? Number)?.toDouble() ?: return null
        val longitude = fallbackLongitude ?: (json["longitude"] as? Number)?.toDouble() ?: return null
        val locality = text(json["locality"])
        return WeatherLocation(
            name = name,
            admin1 = text(json["principalSubdivision"]),
            country = text(json["countryName"]),
            // 区名与市名相同时不重复记（直辖市政区反查会给出同名 city / locality）。
            district = if (locality == name) null else locality,
            latitude = coarsenCoordinate(latitude),
            longitude = coarsenCoordinate(longitude),
        )
    }

    private fun parseObject(body: String): Map<*, *>? = try {
        MiniJson.parse(body) as? Map<*, *>
    } catch (_: Exception) {
        null
    }

    /** 把 `Map<*,*>` 规整成 `Map<String, Any?>`（[WeatherForecast.fromOpenMeteoResponse] 的入参类型）。 */
    private fun typed(json: Map<*, *>): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        for ((k, v) in json) out[k.toString()] = v
        return out
    }

    private fun text(raw: Any?): String? {
        if (raw !is String) return null
        val trimmed = raw.trim()
        return if (trimmed.isEmpty()) null else trimmed
    }

    private fun buildUrl(base: String, params: List<Pair<String, String>>): String {
        val query = params.joinToString("&") { (key, value) ->
            "${encode(key)}=${encode(value)}"
        }
        return "$base?$query"
    }

    private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")
}
