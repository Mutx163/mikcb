package com.mutx163.qingyu.calendar

/**
 * 一条 ARB 文案（键 + zh 模板）。
 *
 * 与 `pages/weather/WeatherStrings.kt` 的同名声明的区别：那个在 `pages.weather` 包里，
 * 本目录（`calendar/` 是 L0 共享模型目录）不能反向依赖某个页面域，所以这里自带一份
 * **同形**的最小实现（只有 [filled] 一个方法）。两处都存在的重复是刻意的：共享模型层
 * 与页面域各自可被单独编译，跨域 import 会让 `pages/holiday` 的 L0 顺带拉进 pages/weather。
 */
data class ArbText(val key: String, val zh: String) {

    /** 替换模板里的占位符（`{name}` → [value]，按 `{}` 字面匹配）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

/**
 * 节假日更新日志的 19 条文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * 纪律：**逐字照抄 ARB**，键名逐字一致、标点（含「……」这种双省略号）不改，
 * 由 `HolidayStringsParityTest` 机械对拍；改文案只能改 ARB 再同步回来。
 *
 * 19 条 = `lib/l10n/holiday_log_localizer.dart` 的 19 个 switch 分支，一条不多一条不少。
 * 其中 [holidayLogPrimaryApiFailed] / [holidayLogNoValidEntries] / [holidayLogFallbackApiError]
 * 三条**不带占位符**（Dart 侧也是无参 getter，别顺手给它们加参数）。
 */
object HolidayStrings {

    // ── 缓存命中 / 取数流程（Dart holiday_service.dart:109-161）──
    val holidayLogMemoryCacheHit =
        ArbText("holidayLogMemoryCacheHit", "{year} 年：命中内存缓存 {count} 条，后台刷新中")
    val holidayLogLocalCacheHit =
        ArbText("holidayLogLocalCacheHit", "{year} 年：命中本地缓存 {count} 条，后台刷新中")
    val holidayLogNoCacheFetching =
        ArbText("holidayLogNoCacheFetching", "{year} 年：无缓存，正在拉取远程数据……")
    val holidayLogRemoteSuccess =
        ArbText("holidayLogRemoteSuccess", "{year} 年：远程拉取成功 {count} 条，已缓存")
    val holidayLogRemoteFailedBuiltin =
        ArbText("holidayLogRemoteFailedBuiltin", "{year} 年：远程拉取失败，使用内置资产兜底")
    val holidayLogBuiltinLoaded =
        ArbText("holidayLogBuiltinLoaded", "{year} 年：加载内置数据 {count} 条")

    // ── 后台刷新（Dart `_backgroundRefresh`，:165-206）──
    val holidayLogBackgroundSuccess =
        ArbText("holidayLogBackgroundSuccess", "{year} 年：后台更新成功 {count} 条，已覆盖缓存")
    val holidayLogBackgroundNoData =
        ArbText("holidayLogBackgroundNoData", "{year} 年：后台更新未获取到新数据")

    // ── 主端点（Dart `_fetchFromXiaoai`，:263-313）──
    val holidayLogPrimaryApiFailed =
        ArbText("holidayLogPrimaryApiFailed", "主 API 失败，尝试备用 API……")
    val holidayLogRequesting = ArbText("holidayLogRequesting", "正在请求 {uri} ……")
    val holidayLogPrimaryApiStatus =
        ArbText("holidayLogPrimaryApiStatus", "主 API 响应 {statusCode}，跳过")
    val holidayLogPrimaryApiError =
        ArbText("holidayLogPrimaryApiError", "主 API 返回错误：{message}")
    val holidayLogPrimaryApiException =
        ArbText("holidayLogPrimaryApiException", "主 API 异常：{error}")
    val holidayLogPrimaryApiParsing =
        ArbText("holidayLogPrimaryApiParsing", "主 API 返回 {count} 条原始数据，正在解析……")
    val holidayLogNoValidEntries = ArbText("holidayLogNoValidEntries", "解析后无有效条目，跳过")

    // ── 备用端点（Dart `_fetchFromAilcc`，:315-362）──
    val holidayLogFallbackApiStatus =
        ArbText("holidayLogFallbackApiStatus", "备用 API 响应 {statusCode}，跳过")
    val holidayLogFallbackApiError = ArbText("holidayLogFallbackApiError", "备用 API 返回错误")
    val holidayLogFallbackApiParsing =
        ArbText("holidayLogFallbackApiParsing", "备用 API 返回 {count} 条原始数据，正在解析……")
    val holidayLogFallbackApiException =
        ArbText("holidayLogFallbackApiException", "备用 API 异常：{error}")

    /** 全部 19 条，供逐字对拍测试遍历（顺序与 [HolidayLogLocalizer] 的分支顺序一致）。 */
    val allArbTexts: List<ArbText> = listOf(
        holidayLogMemoryCacheHit,
        holidayLogLocalCacheHit,
        holidayLogNoCacheFetching,
        holidayLogRemoteSuccess,
        holidayLogRemoteFailedBuiltin,
        holidayLogBuiltinLoaded,
        holidayLogBackgroundSuccess,
        holidayLogBackgroundNoData,
        holidayLogPrimaryApiFailed,
        holidayLogRequesting,
        holidayLogPrimaryApiStatus,
        holidayLogPrimaryApiError,
        holidayLogPrimaryApiException,
        holidayLogPrimaryApiParsing,
        holidayLogNoValidEntries,
        holidayLogFallbackApiStatus,
        holidayLogFallbackApiError,
        holidayLogFallbackApiParsing,
        holidayLogFallbackApiException,
    )
}

/**
 * 更新日志键本地化（逐行移植 `lib/l10n/holiday_log_localizer.dart`）。
 *
 * ## 为什么日志存的是「键|k=v」而不是格式化好的中文
 *
 * Dart 侧的日志是**落盘/内存里存的原始键串**（`HolidayService._logKey`），渲染时才翻译。
 * 这样切语言不必重跑更新流程，界面也能在日志不可解析时原样展示。
 *
 * ## 参数解析口径（与 Dart `:6-17` 逐字一致）
 *
 * - 按 `|` 切段，第 0 段是键；
 * - 其余段按**第一个** `=` 切（`idx > 0` 才算，所以没有 `=` 的段被丢弃、`uri=https://x?y=1`
 *   这种值里带 `=` 的不会被切坏）；
 * - 同名参数后出现者覆盖前者；
 * - 需要整数的占位符走 `toIntOrNull() ?: 0`（Dart `int.tryParse(...) ?? 0`），
 *   缺参 / 空串 / 非数字统一回落 0；
 * - 字符串占位符缺参时回落空串（Dart `params['uri'] ?? ''`）；
 * - **未识别的键原样返回**（Dart `_ => message`）——自定义假期损坏那条
 *   `custom_holidays_corrupted` 就靠这条分支露出原文，不做假翻译。
 */
object HolidayLogLocalizer {

    private const val KEY_VALUE_SEPARATOR = '|'
    private const val PARAM_SEPARATOR = '='

    fun localize(raw: String): String {
        val parts = raw.split(KEY_VALUE_SEPARATOR)
        val key = parts.first()
        val params = LinkedHashMap<String, String>()
        for (part in parts.drop(1)) {
            val idx = part.indexOf(PARAM_SEPARATOR)
            if (idx > 0) {
                params[part.substring(0, idx)] = part.substring(idx + 1)
            }
        }

        fun intParam(name: String): String = (params[name]?.toIntOrNull() ?: 0).toString()
        fun textParam(name: String): String = params[name] ?: ""

        return when (key) {
            "holiday_log_memory_cache_hit" -> HolidayStrings.holidayLogMemoryCacheHit.filled(
                "year" to intParam("year"),
                "count" to intParam("count"),
            )
            "holiday_log_local_cache_hit" -> HolidayStrings.holidayLogLocalCacheHit.filled(
                "year" to intParam("year"),
                "count" to intParam("count"),
            )
            "holiday_log_no_cache_fetching" -> HolidayStrings.holidayLogNoCacheFetching.filled(
                "year" to intParam("year"),
            )
            "holiday_log_remote_success" -> HolidayStrings.holidayLogRemoteSuccess.filled(
                "year" to intParam("year"),
                "count" to intParam("count"),
            )
            "holiday_log_remote_failed_builtin" -> HolidayStrings.holidayLogRemoteFailedBuiltin.filled(
                "year" to intParam("year"),
            )
            "holiday_log_builtin_loaded" -> HolidayStrings.holidayLogBuiltinLoaded.filled(
                "year" to intParam("year"),
                "count" to intParam("count"),
            )
            "holiday_log_background_success" -> HolidayStrings.holidayLogBackgroundSuccess.filled(
                "year" to intParam("year"),
                "count" to intParam("count"),
            )
            "holiday_log_background_no_data" -> HolidayStrings.holidayLogBackgroundNoData.filled(
                "year" to intParam("year"),
            )
            "holiday_log_primary_api_failed" -> HolidayStrings.holidayLogPrimaryApiFailed.zh
            "holiday_log_requesting" -> HolidayStrings.holidayLogRequesting.filled(
                "uri" to textParam("uri"),
            )
            "holiday_log_primary_api_status" -> HolidayStrings.holidayLogPrimaryApiStatus.filled(
                "statusCode" to intParam("statusCode"),
            )
            "holiday_log_primary_api_error" -> HolidayStrings.holidayLogPrimaryApiError.filled(
                "message" to textParam("message"),
            )
            "holiday_log_primary_api_exception" -> HolidayStrings.holidayLogPrimaryApiException.filled(
                "error" to textParam("error"),
            )
            "holiday_log_primary_api_parsing" -> HolidayStrings.holidayLogPrimaryApiParsing.filled(
                "count" to intParam("count"),
            )
            "holiday_log_no_valid_entries" -> HolidayStrings.holidayLogNoValidEntries.zh
            "holiday_log_fallback_api_status" -> HolidayStrings.holidayLogFallbackApiStatus.filled(
                "statusCode" to intParam("statusCode"),
            )
            "holiday_log_fallback_api_error" -> HolidayStrings.holidayLogFallbackApiError.zh
            "holiday_log_fallback_api_parsing" -> HolidayStrings.holidayLogFallbackApiParsing.filled(
                "count" to intParam("count"),
            )
            "holiday_log_fallback_api_exception" -> HolidayStrings.holidayLogFallbackApiException.filled(
                "error" to textParam("error"),
            )
            else -> raw
        }
    }
}
