package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.infra.NetLog
import java.net.URLEncoder
import java.time.LocalDateTime

/**
 * Dart `lib/services/weather_service.dart` 的移植。
 *
 * 端点（与 Dart 逐字一致）：
 * - Open-Meteo 预报 `https://api.open-meteo.com/v1/forecast`（**唯一预报源**）
 * - BigDataCloud 反查/按 IP 估算 `https://api.bigdatacloud.net/data/reverse-geocode-client`
 * - Open-Meteo 正向地理编码（按名字搜城市）`https://geocoding-api.open-meteo.com/v1/search`
 *
 * **纯 Kotlin（只用 JDK 类型 + [NetLog]，零 HTTP 客户端依赖）**：真实传输实现
 * （OkHttp）在 `platform/OkHttpWeatherHttp`，不进本文件的 L0 编译面；本文件只依赖
 * [WeatherHttp] 接口，JVM 单测注入假件即可。
 *
 * ## 2026-11-14：失败必须能解释（A 类）
 *
 * 用户实报「天气一直上次更新失败」；手机浏览器能拿到 JSON，说明不是网络到不了。
 * 取数结果从「单个 null」升级成 [WeatherFetchResult]，失败四类各有名字：
 * 连不上、超时、非 200、非 JSON、解析失败（字段 + 响应行 + 代码行）、空时次。
 * 每次预报取数按 [NetLog] 的同一套字段写进应用日志，诊断页直接能看到。
 *
 * **不做备用源**（用户 2026-11-14 决定）：手机能拿到 JSON，说明网络与证书没问题，
 * 问题在 App 自己的请求或解析；切源会把「我们自己哪里错了」掩盖掉。
 */

/** 取数失败分类（A 类：失败必须可见——五类各有名字，日志里一眼能分清）。 */
enum class WeatherFetchFailure {
    /** 连不上 / DNS / TLS 握手失败：请求根本没拿到响应。 */
    NETWORK,

    /** 连接或读取超时（[WeatherHttpResult] 会带耗时，日志里能看出卡在哪一段）。 */
    TIMEOUT,

    /** 拿到响应但状态码不是 200（429 / 5xx / 403 …）。 */
    HTTP_STATUS,

    /** 拿到了 body，但不是合法 JSON（日志里带响应行号与偏移）。 */
    NOT_JSON,

    /** JSON 合法但结构不对（缺 hourly / 坐标），或解析抛错（日志里带字段与代码行）。 */
    PARSE,

    /** 结构合法但没有任何有效小时点。 */
    EMPTY,

    /** 测试假件没有分类；生产实现不会用它（只在日志里兜底）。 */
    UNKNOWN,
}

/** 数据源标识（只进日志与诊断页；不含坐标、不含 URL 参数）。 */
object WeatherSource {
    const val OPEN_METEO: String = "open-meteo"
}

/**
 * 一次取数的诊断（**脱敏**：分类 / 数据源 / 状态码 / 耗时 / 字节数 / 异常类名 / 字段与行号；
 * 没有坐标、没有完整 URL、没有响应体）。
 */
data class WeatherFetchDiagnostics(
    val source: String?,
    val failure: WeatherFetchFailure?,
    val httpStatus: Int? = null,
    val elapsedMs: Long = 0L,
    val bodyBytes: Long? = null,
    val errorClass: String? = null,
    val detail: String? = null,
)

/** 一次取数的结果：成功的预报与失败的诊断二选一。 */
data class WeatherFetchResult(
    val forecast: WeatherForecast?,
    val diagnostics: WeatherFetchDiagnostics,
)

/** 一个「GET 一个 URL」的结果；[failure] 非空表示没拿到可用 body。 */
data class WeatherHttpResult(
    val body: String? = null,
    val httpStatus: Int? = null,
    val failure: WeatherFetchFailure? = null,
    val elapsedMs: Long = 0L,
    val bodyBytes: Long? = null,
    val errorClass: String? = null,
)

/** 天气取数的四个动作（[WeatherService] 的实现契约，供单测注入假件）。 */
interface WeatherGateway {
    fun fetchForecast(location: WeatherLocation): WeatherForecast?

    /**
     * 带失败分类的取数。
     *
     * 默认实现只包 [fetchForecast]：测试里的老假件不必改签名；生产实现见 [WeatherService]。
     */
    fun fetchForecastWithDiagnostics(location: WeatherLocation): WeatherFetchResult =
        WeatherFetchResult(
            forecast = fetchForecast(location),
            diagnostics = WeatherFetchDiagnostics(source = null, failure = null),
        )

    /**
     * 按名字搜城市。
     *
     * **两件事必须分开**（2026-11-05 审核 G1）：
     * - `null` = 请求失败（断网 / 超时 / HTTP 非 200 / body 不是 JSON）——用户该看到
     *   「搜索失败，请稍后重试」+ 重试；
     * - 空列表 = 请求成功、但确实没有匹配的城市——用户该看到「没有找到匹配的城市」。
     */
    fun searchLocations(query: String): List<WeatherLocation>?

    fun reverseGeocode(latitude: Double, longitude: Double): WeatherLocation?
    fun networkGeocode(): WeatherLocation?
}

/**
 * 「GET 一个 URL」的接缝。
 *
 * 生产实现是 `platform/OkHttpWeatherHttp`（OkHttp；用户 2026-11-14 决定全软件网络走 OkHttp）；
 * 纯 JVM 单测实现 [get] 即可，默认 [getDetailed] 会把 null 归为「连不上」。
 */
interface WeatherHttp {
    fun get(url: String): String?

    /** 带状态码 / 耗时 / 字节数 / 失败分类的 GET（生产实现覆盖）。 */
    fun getDetailed(url: String): WeatherHttpResult =
        get(url)?.let { WeatherHttpResult(body = it) }
            ?: WeatherHttpResult(failure = WeatherFetchFailure.NETWORK)
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

    /**
     * 按关键字搜索地点；名字不足 2 字符直接短路（接口只返回空）。
     *
     * 返回 `null` 只在「请求失败」时；解析出合法 JSON 但没有 `results` 字段算**真空结果**。
     */
    override fun searchLocations(query: String): List<WeatherLocation>? {
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
        ) ?: return null

        val json = parseObject(body) ?: return null
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
    override fun fetchForecast(location: WeatherLocation): WeatherForecast? =
        fetchForecastWithDiagnostics(location).forecast

    /**
     * 拉取预报；无论成败都按 [NetLog] 的统一字段写一条网络日志（成功 info、失败 warn）。
     *
     * 日志里四样齐全：异常类名（或 `failure=` 分类）、HTTP 状态码、耗时毫秒、响应字节数；
     * 解析失败再补 `detail=field=hourly line=1 at=WeatherForecast.kt:216`。
     */
    override fun fetchForecastWithDiagnostics(location: WeatherLocation): WeatherFetchResult {
        val url = buildUrl(
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
        )
        val response = http.getDetailed(url)
        val result = interpret(response)
        NetLog.record(
            url = url,
            method = "GET",
            status = response.httpStatus,
            elapsedMs = response.elapsedMs,
            bytes = response.bodyBytes,
            failure = result.diagnostics.failure?.toNetLogFailure(),
            errorClass = response.errorClass,
            detail = result.diagnostics.detail,
        )
        return result
    }

    // ---------- 内部 ----------

    private fun interpret(response: WeatherHttpResult): WeatherFetchResult {
        val diagnostics = WeatherFetchDiagnostics(
            source = WeatherSource.OPEN_METEO,
            failure = response.failure,
            httpStatus = response.httpStatus,
            elapsedMs = response.elapsedMs,
            bodyBytes = response.bodyBytes,
            errorClass = response.errorClass,
        )
        val body = response.body
            ?: return WeatherFetchResult(null, diagnostics.copy(failure = response.failure ?: WeatherFetchFailure.NETWORK))

        val parsed = parseBody(body)
        if (parsed.json == null) {
            return WeatherFetchResult(
                null,
                diagnostics.copy(
                    failure = WeatherFetchFailure.NOT_JSON,
                    detail = parsed.parseError?.let { "field=body ${it.describe(body)}" },
                ),
            )
        }
        return try {
            val forecast = WeatherForecast.fromOpenMeteoResponse(typed(parsed.json), now())
            if (forecast.hourly.isEmpty()) {
                WeatherFetchResult(
                    null,
                    diagnostics.copy(
                        failure = WeatherFetchFailure.EMPTY,
                        detail = "field=hourly.time points=0",
                    ),
                )
            } else {
                WeatherFetchResult(forecast, diagnostics.copy(failure = null))
            }
        } catch (error: Exception) {
            WeatherFetchResult(
                null,
                diagnostics.copy(
                    failure = WeatherFetchFailure.PARSE,
                    detail = describeParseFailure(error),
                ),
            )
        }
    }

    /**
     * 解析 body，失败时保留**响应行号 + 偏移**（[MiniJson] 的异常消息带 `at <pos>`）。
     * 没有位置信息时只写异常类名，不猜行号。
     */
    private fun parseBody(body: String): ParsedBody = try {
        ParsedBody(json = MiniJson.parse(body) as? Map<*, *>, parseError = null)
    } catch (error: Exception) {
        ParsedBody(json = null, parseError = ParseError(error.javaClass.simpleName, error.message))
    }

    /**
     * 结构失败（缺字段 / 类型不对）→ `field=<接口字段> at=<文件>:<行>`。
     *
     * 字段名从 [WeatherForecast.fromOpenMeteoResponse] 的异常消息里取（它按
     * `weather forecast: missing hourly block` / `missing coordinates` 的固定格式抛）；
     * 代码行取异常栈里**第一个 `com.mutx163.qingyu.weather` 帧**——就是真正抛错的解析行。
     */
    private fun describeParseFailure(error: Exception): String {
        val message = error.message.orEmpty()
        val field = when {
            message.contains("hourly", ignoreCase = true) -> "hourly"
            message.contains("coordinates", ignoreCase = true) -> "latitude/longitude"
            message.contains("weather location", ignoreCase = true) -> "name/latitude/longitude"
            else -> "unknown"
        }
        val frame = error.stackTrace.firstOrNull { it.className.startsWith("com.mutx163.qingyu.weather") }
        val at = frame?.let { "${it.fileName}:${it.lineNumber}" } ?: "unknown"
        return "field=$field at=$at"
    }

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

    private fun WeatherFetchFailure.toNetLogFailure(): String = when (this) {
        WeatherFetchFailure.NETWORK -> NetLog.FAILURE_NETWORK
        WeatherFetchFailure.TIMEOUT -> NetLog.FAILURE_TIMEOUT
        WeatherFetchFailure.HTTP_STATUS -> NetLog.FAILURE_HTTP_STATUS
        WeatherFetchFailure.NOT_JSON -> NetLog.FAILURE_NOT_JSON
        WeatherFetchFailure.PARSE -> NetLog.FAILURE_PARSE
        WeatherFetchFailure.EMPTY -> NetLog.FAILURE_EMPTY
        WeatherFetchFailure.UNKNOWN -> "unknown"
    }

    /** [parseBody] 的输出：JSON 与解析错误二选一。 */
    private class ParsedBody(val json: Map<*, *>?, val parseError: ParseError?)

    /** 解析错误只留类名 + 位置；[describe] 把 MiniJson 的 `at <pos>` 换算成响应行号。 */
    private class ParseError(private val errorClass: String, private val message: String?) {
        fun describe(body: String): String {
            val offset = POS.find(message.orEmpty())?.groupValues?.get(1)?.toIntOrNull()
            val line = offset?.let { 1 + body.take(it.coerceIn(0, body.length)).count { ch -> ch == '\n' } }
            return "errorClass=$errorClass offset=${offset ?: "unknown"} line=${line ?: "unknown"}"
        }

        private companion object {
            val POS = Regex("""at\s+(\d+)""")
        }
    }
}
