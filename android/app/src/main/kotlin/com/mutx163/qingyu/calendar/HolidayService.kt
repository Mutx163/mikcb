package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.MiniJson
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * 节假日**远程取数**接缝（[HolidayService] 的实现契约，单测注入假网关）。
 *
 * 抽出这个接口的唯一理由是「能在 JVM 上测」：L0（`scripts/test-kotlin-module.ps1`）的
 * classpath 只有 kotlin-stdlib + junit，没有 OkHttp、没有 Android 的 `SharedPreferences`，
 * 也没有网络。假网关把「远端拿回什么」变成入参，[HolidayProvider] 的缓存 / 兜底 / 合并语义
 * 才能被普通单测钉死。
 *
 * 与 Dart 的对应：`holiday_service.dart:255-261 _fetchRemoteUpdate`（主端点 → 备用端点）。
 */
interface HolidayRemoteGateway {

    /**
     * 拉取 [year] 年的远程节假日数据；**失败一律返回 null，绝不抛**（节假日是装饰性
     * 信息，不该把一个页面拖崩——与 Dart 逐条 try/catch 的口径一致）。
     *
     * [log] 收的是**未本地化**的原始日志串，形如 `键|k=v|k=v`
     * （Dart `_logKey`，`holiday_service.dart:83-97`）。之所以用回调而不是让本接口
     * 自己存日志：日志的归宿是 [HolidayProvider.logs]（界面要按「时刻 + 正文」展示），
     * 网关不该持有界面状态；同时单测可以直接收原始键做断言，不必比对中文字符串。
     */
    fun fetchYear(year: Int, log: (String) -> Unit): HolidayData?
}

/**
 * 一次 HTTP 响应的最小形态（状态码 + body 文本）。
 *
 * 必须把「传输失败」与「HTTP 状态码非 200」分开：[HolidayService] 对前者记
 * `holiday_log_*_exception`、对后者记 `holiday_log_*_status`（Dart 同样是两条分支，
 * 见 `holiday_service.dart:280-286` 与 `:309-312`）。用一个 `String?` 表达不了这个区别。
 */
data class HolidayHttpResponse(val statusCode: Int, val body: String)

/**
 * 一个「GET 一个 URL」的最小接缝（真实实现走 [JdkHolidayHttp]）。
 *
 * 返回 null 表示**连不上 / 超时 / 读不到 body**（Dart 侧的 `ClientException` 家族），
 * 不是「服务器回了空」——后者是 200 + 空 body，要进解析分支。
 */
interface HolidayHttp {
    fun get(url: String): HolidayHttpResponse?
}

/**
 * 真实 HTTP 实现：JDK [HttpURLConnection]（零新依赖，与 `weather/WeatherService.kt`
 * 的 `JdkWeatherHttp` 同一写法，理由见那儿的注释）。
 *
 * 两个细节与 Dart 对齐：
 * - 超时 8 秒（Dart `.timeout(const Duration(seconds: 8))`，`holiday_service.dart:279`）；
 * - 请求头 `Accept: application/json` + `User-Agent: mikcb-holiday-sync`（`:274-277`）。
 */
class JdkHolidayHttp(
    private val timeoutMillis: Int = HolidayService.TIMEOUT_MILLIS,
) : HolidayHttp {

    override fun get(url: String): HolidayHttpResponse? {
        val connection = try {
            (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = timeoutMillis
                readTimeout = timeoutMillis
                setRequestProperty("Accept", "application/json")
                setRequestProperty("User-Agent", "mikcb-holiday-sync")
            }
        } catch (_: Exception) {
            return null
        }
        return try {
            val status = connection.responseCode
            // 非 200 时 errorStream 才是正文；Dart 的 http 包也是这么读的，这里不解析它，
            // 只把状态码带回去（调用方只记状态码）。
            val stream = if (status == 200) connection.inputStream else connection.errorStream
            val body = stream?.use { String(it.readBytes(), Charsets.UTF_8) } ?: ""
            HolidayHttpResponse(statusCode = status, body = body)
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }
}

/**
 * Dart `lib/services/holiday_service.dart` 里**只负责取网**的那一段
 * （`:255-362 _fetchRemoteUpdate / _fetchFromXiaoai / _fetchFromAilcc`）。
 *
 * 缓存（内存 / 本地 / 内置资产）与跨年合并**不在这里**：Dart 把它们和取网塞在同一个
 * `HolidayService` 里（`:105-162`），那需要 `SharedPreferences` 与 `rootBundle`，
 * 本目录进不了 JVM 单测。Kotlin 侧按职责切成两半：
 * - 本类 = HTTP + 双端点 + 解析 + 请求期日志；
 * - [HolidayProvider] = 缓存、兜底、合并、CRUD、日志列表。
 *
 * 双端点（顺序与 URL 逐字对齐 Dart）：
 * 1. 主端点 `https://publicapi.xiaoai.me/holiday/year?year=<y>`，响应
 *    `{"code":0,"data":[{"date":"2026-10-01","daytype":1,"rest":1},...]}`
 *    → [HolidayApiConverter.convertApiEntries]；
 * 2. 备用端点 `https://holiday.ailcc.com/api/holiday/year/<y>`，响应
 *    `{"code":0,"holiday":{"01-01":{"holiday":true,"name":"元旦节（休）","date":"2026-01-01"}}}`
 *    → [HolidayApiConverter.convertAilccEntries]。
 *
 * 失败语义：任一端点失败都只记日志并返回 null；两边都失败 → 整体 null
 * （由 [HolidayProvider] 接手内置资产兜底）。**解析不出任何有效条目也算失败**——
 * 这是「不留毒数据」的前置：空条目一旦被当成成功写进缓存，以后每次启动都会在
 * 「本地缓存命中」处短路，远程一直坏就永远读不到新数据。
 */
class HolidayService(
    private val http: HolidayHttp = JdkHolidayHttp(),
) : HolidayRemoteGateway {

    companion object {
        /** 主端点（Dart `_remoteHolidayBaseUrl`，`holiday_service.dart:38-39`）。 */
        const val PRIMARY_BASE_URL = "https://publicapi.xiaoai.me/holiday/year"

        /** 备用端点（Dart `_fallbackHolidayBaseUrl`，`:40-41`）。 */
        const val FALLBACK_BASE_URL = "https://holiday.ailcc.com/api/holiday/year"

        /** 单次请求超时（Dart 8 秒，`:279` / `:331`）。 */
        const val TIMEOUT_MILLIS = 8_000

        /** 远程数据的 version 恒为 1（Dart `HolidayData(year: year, version: 1, ...)`）。 */
        const val REMOTE_VERSION = 1

        fun primaryUrl(year: Int): String = "$PRIMARY_BASE_URL?year=$year"

        fun fallbackUrl(year: Int): String = "$FALLBACK_BASE_URL/$year"
    }

    override fun fetchYear(year: Int, log: (String) -> Unit): HolidayData? {
        // Dart `_fetchRemoteUpdate`：主端点成功即返回；否则记一条 primary_api_failed
        // （**注意 Dart 只在主端点「返回 null」时记这一条**，状态码 / 异常 / 解析失败
        // 各自已在上一步记过一条更具体的日志），然后无条件试备用端点。
        val primary = fetchFromPrimary(year, log)
        if (primary != null) return primary
        log(KEY_PRIMARY_API_FAILED)
        return fetchFromFallback(year, log)
    }

    // ---------- 主端点 ----------

    private fun fetchFromPrimary(year: Int, log: (String) -> Unit): HolidayData? {
        val url = primaryUrl(year)
        log("$KEY_REQUESTING|uri=$url")
        return try {
            val response = http.get(url) ?: throw IOException("primary: no http response")
            if (response.statusCode != 200) {
                log("$KEY_PRIMARY_API_STATUS|statusCode=${response.statusCode}")
                return null
            }
            val json = parseObject(response.body) ?: throw IllegalStateException("primary: body is not a json object")
            // Dart `if (json['code'] != 0)`：缺字段也走错误分支（null != 0）。
            if (!isZeroCode(json["code"])) {
                log("$KEY_PRIMARY_API_ERROR|message=${messageText(json["msg"])}")
                return null
            }
            // Dart `json['data'] as List<dynamic>`：不是数组就抛，落到下面的异常分支。
            val list = json["data"] as? List<*>
                ?: throw IllegalStateException("primary: data is not an array")
            log("$KEY_PRIMARY_API_PARSING|count=${list.size}")
            val entries = HolidayApiConverter.convertApiEntries(list, year)
            if (entries.isEmpty()) {
                log(KEY_NO_VALID_ENTRIES)
                return null
            }
            HolidayData(year = year, version = REMOTE_VERSION, entries = entries)
        } catch (e: Exception) {
            log("$KEY_PRIMARY_API_EXCEPTION|error=${e}")
            null
        }
    }

    // ---------- 备用端点 ----------

    private fun fetchFromFallback(year: Int, log: (String) -> Unit): HolidayData? {
        val url = fallbackUrl(year)
        log("$KEY_REQUESTING|uri=$url")
        return try {
            val response = http.get(url) ?: throw IOException("fallback: no http response")
            if (response.statusCode != 200) {
                log("$KEY_FALLBACK_API_STATUS|statusCode=${response.statusCode}")
                return null
            }
            val json = parseObject(response.body) ?: throw IllegalStateException("fallback: body is not a json object")
            if (!isZeroCode(json["code"])) {
                // Dart 这一条**不带参数**（`:341-343`），别自作主张加 message。
                log(KEY_FALLBACK_API_ERROR)
                return null
            }
            val holidayMap = json["holiday"] as? Map<*, *>
                ?: throw IllegalStateException("fallback: holiday is not an object")
            log("$KEY_FALLBACK_API_PARSING|count=${holidayMap.size}")
            @Suppress("UNCHECKED_CAST")
            val entries = HolidayApiConverter.convertAilccEntries(holidayMap as Map<String, Any?>, year)
            if (entries.isEmpty()) {
                log(KEY_NO_VALID_ENTRIES)
                return null
            }
            HolidayData(year = year, version = REMOTE_VERSION, entries = entries)
        } catch (e: Exception) {
            log("$KEY_FALLBACK_API_EXCEPTION|error=${e}")
            null
        }
    }

    // ---------- 解析小工具 ----------

    /** 顶层必须是对象；不是对象时返回 null，由调用方按「异常」处理（Dart 的类型转换失败同此）。 */
    private fun parseObject(body: String): Map<String, Any?>? {
        val decoded = MiniJson.parse(body)
        if (decoded !is Map<*, *>) return null
        @Suppress("UNCHECKED_CAST")
        return decoded as Map<String, Any?>
    }

    /** Dart `json['code'] != 0`：数字 0 / 0.0 算成功，其余（含缺失、字符串）算错误。 */
    private fun isZeroCode(raw: Any?): Boolean = (raw as? Number)?.toDouble() == 0.0

    /** Dart `'${json['msg']}'`：缺失时插值出字面量 `null`，这里保持同口径。 */
    private fun messageText(raw: Any?): String = (raw ?: "null").toString()
}

// 日志键（Dart `_logKey` 的字符串字面量，`:259` / `:281-310` / `:333-359`）。
// 放在文件级而不是 companion object 里：本文件的两个类共用这些键，且 `HolidayService`
// 已经有一个公开常量 companion（一个类只能有一个 companion object）。
private const val KEY_REQUESTING = "holiday_log_requesting"
private const val KEY_PRIMARY_API_FAILED = "holiday_log_primary_api_failed"
private const val KEY_PRIMARY_API_STATUS = "holiday_log_primary_api_status"
private const val KEY_PRIMARY_API_ERROR = "holiday_log_primary_api_error"
private const val KEY_PRIMARY_API_EXCEPTION = "holiday_log_primary_api_exception"
private const val KEY_PRIMARY_API_PARSING = "holiday_log_primary_api_parsing"
private const val KEY_FALLBACK_API_STATUS = "holiday_log_fallback_api_status"
private const val KEY_FALLBACK_API_ERROR = "holiday_log_fallback_api_error"
private const val KEY_FALLBACK_API_EXCEPTION = "holiday_log_fallback_api_exception"
private const val KEY_FALLBACK_API_PARSING = "holiday_log_fallback_api_parsing"
private const val KEY_NO_VALID_ENTRIES = "holiday_log_no_valid_entries"
