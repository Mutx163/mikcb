package com.mutx163.qingyu.pages.holiday

import com.mutx163.qingyu.calendar.HolidayLogLocalizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日志本地化（`HolidayLogLocalizer`，移植 `lib/l10n/holiday_log_localizer.dart` 的 19 个分支）。
 *
 * 期望值逐条按 ARB 中文模板 + 手算参数替换写出，**不从实现里取**。
 */
class HolidayLogLocalizerTest {

    @Test
    fun `19 个分支逐条本地化且参数按 k=v 替换`() {
        val cases = listOf(
            "holiday_log_memory_cache_hit|year=2026|count=12" to
                "2026 年：命中内存缓存 12 条，后台刷新中",
            "holiday_log_local_cache_hit|year=2025|count=3" to
                "2025 年：命中本地缓存 3 条，后台刷新中",
            "holiday_log_no_cache_fetching|year=2027" to
                "2027 年：无缓存，正在拉取远程数据……",
            "holiday_log_remote_success|year=2026|count=18" to
                "2026 年：远程拉取成功 18 条，已缓存",
            "holiday_log_remote_failed_builtin|year=2026" to
                "2026 年：远程拉取失败，使用内置资产兜底",
            "holiday_log_builtin_loaded|year=2026|count=18" to
                "2026 年：加载内置数据 18 条",
            // changed 是 Dart 记账用的附加参数，界面文案里没有它 → 必须被忽略
            "holiday_log_background_success|year=2026|count=18|changed=true" to
                "2026 年：后台更新成功 18 条，已覆盖缓存",
            "holiday_log_background_no_data|year=2026" to
                "2026 年：后台更新未获取到新数据",
            "holiday_log_primary_api_failed" to
                "主 API 失败，尝试备用 API……",
            // 值里带 `=`：按第一个 `=` 切，后面的原样留在值里
            "holiday_log_requesting|uri=https://publicapi.xiaoai.me/holiday/year?year=2026" to
                "正在请求 https://publicapi.xiaoai.me/holiday/year?year=2026 ……",
            "holiday_log_primary_api_status|statusCode=503" to
                "主 API 响应 503，跳过",
            "holiday_log_primary_api_error|message=boom" to
                "主 API 返回错误：boom",
            "holiday_log_primary_api_exception|error=java.io.IOException: timeout" to
                "主 API 异常：java.io.IOException: timeout",
            "holiday_log_primary_api_parsing|count=365" to
                "主 API 返回 365 条原始数据，正在解析……",
            "holiday_log_no_valid_entries" to
                "解析后无有效条目，跳过",
            "holiday_log_fallback_api_status|statusCode=429" to
                "备用 API 响应 429，跳过",
            "holiday_log_fallback_api_error" to
                "备用 API 返回错误",
            "holiday_log_fallback_api_parsing|count=42" to
                "备用 API 返回 42 条原始数据，正在解析……",
            "holiday_log_fallback_api_exception|error=SocketTimeoutException" to
                "备用 API 异常：SocketTimeoutException",
        )

        assertEquals("19 个分支一条不能少", 19, cases.size)
        for ((raw, expected) in cases) {
            assertEquals("键 ${raw.substringBefore('|')} 的本地化结果不对", expected, HolidayLogLocalizer.localize(raw))
            assertTrue("本地化后不该再残留键名", !HolidayLogLocalizer.localize(raw).startsWith("holiday_log_"))
        }
    }

    @Test
    fun `未识别的键原样返回`() {
        val raw = "custom_holidays_corrupted|error=FormatException"

        assertEquals(
            "Dart 的 `_ => message` 分支：不认识就原样透传，不做假翻译",
            raw,
            HolidayLogLocalizer.localize(raw),
        )
        assertEquals("空串也一样原样返回", "", HolidayLogLocalizer.localize(""))
    }

    @Test
    fun `缺参数或参数非数字时回落为 0`() {
        assertEquals(
            "2026 年：远程拉取成功 0 条，已缓存",
            HolidayLogLocalizer.localize("holiday_log_remote_success|year=2026"),
        )
        assertEquals(
            "主 API 响应 0，跳过",
            HolidayLogLocalizer.localize("holiday_log_primary_api_status|statusCode=abc"),
        )
    }

    @Test
    fun `缺字符串参数时回落为空串`() {
        assertEquals(
            "主 API 返回错误：",
            HolidayLogLocalizer.localize("holiday_log_primary_api_error"),
        )
        assertEquals(
            "正在请求  ……",
            HolidayLogLocalizer.localize("holiday_log_requesting"),
        )
    }

    @Test
    fun `没有等号的片段被忽略`() {
        // 第 2 段没有 `=`（Dart `idx > 0` 判据），第 3 段键为空也不算 → 只有 uri 生效。
        assertEquals(
            "正在请求 https://a.example/x ……",
            HolidayLogLocalizer.localize("holiday_log_requesting|uri=https://a.example/x|裸片段|=空键"),
        )
    }

    @Test
    fun `同名参数后出现者覆盖前者`() {
        assertEquals(
            "2026 年：命中内存缓存 5 条，后台刷新中",
            HolidayLogLocalizer.localize("holiday_log_memory_cache_hit|year=2020|count=9|count=5|year=2026"),
        )
    }
}
