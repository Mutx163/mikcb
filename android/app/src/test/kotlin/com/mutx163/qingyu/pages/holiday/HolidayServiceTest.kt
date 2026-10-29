package com.mutx163.qingyu.pages.holiday

import com.mutx163.qingyu.calendar.HolidayHttp
import com.mutx163.qingyu.calendar.HolidayHttpResponse
import com.mutx163.qingyu.calendar.HolidayService
import com.mutx163.qingyu.calendar.HolidayServiceConstants
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 节假日远程取数（`HolidayService`，Dart `holiday_service.dart:255-362`）的 JVM 单测。
 *
 * 期望值全部是**人推出来的**（照 Dart 的转换规则手算），不从实现里抄：
 * - 10-01/02/03 连续三天 → 一组，名字判 `national_day`（`_nameForGroup` 判据：月份 10、日 ≤ 7）；
 * - 10-10 是调休上班（daytype 3 且 rest 0），距该组组尾 7 天（≤21）→ 挂到 `holiday-2026-0`。
 */
class HolidayServiceTest {

    // 端点字面量独立写在测试里：生产代码若改了 URL，这里立刻红（契约钉住）。
    private val primary2026 = "https://publicapi.xiaoai.me/holiday/year?year=2026"
    private val fallback2026 = "https://holiday.ailcc.com/api/holiday/year/2026"

    @Test
    fun `主端点成功时不再请求备用端点`() {
        val body = """
            {"code":0,"msg":"ok","data":[
              {"date":"2026-10-01","daytype":1,"rest":1},
              {"date":"2026-10-02","daytype":1,"rest":1},
              {"date":"2026-10-03","daytype":1,"rest":1},
              {"date":"2026-10-10","daytype":3,"rest":0},
              {"date":"2026-10-11","daytype":4,"rest":1}
            ]}
        """.trimIndent()
        val http = FakeHttp(primary2026 to HolidayHttpResponse(200, body))
        val logs = mutableListOf<String>()

        val data = HolidayService(http).fetchYear(2026) { logs += it }

        assertNotNull("主端点返回了有效数据，不该整体失败", data)
        assertEquals(2026, data!!.year)
        assertEquals(1, data.version)
        assertEquals("3 天假期 + 1 天调休上班 = 4 条（daytype 4 的普通工作日被跳过）", 4, data.entries.size)

        val vacations = data.entries.filter { it.type == HolidayType.Vacation }
        assertEquals(3, vacations.size)
        for (entry in vacations) {
            assertEquals("holiday_name:national_day", entry.name)
            assertEquals("holiday-2026-0", entry.groupId)
        }

        val makeup = data.entries.single { it.type == HolidayType.AdjustedWorkday }
        assertEquals(10, makeup.date.dayOfMonth)
        assertEquals(HolidayServiceConstants.HOLIDAY_NAME_MAKEUP_WORKDAY_KEY, makeup.name)
        assertEquals("距组尾 7 天，落在 21 天窗口内 → 挂到第 0 组", "holiday-2026-0", makeup.groupId)

        assertEquals("主端点成功即返回，不该再打备用端点", listOf(primary2026), http.requests)
        assertTrue(
            "解析日志要记原始条目数 5（含被跳过的 daytype 4）",
            logs.contains("holiday_log_primary_api_parsing|count=5"),
        )
        assertTrue("主端点成功时不该记 primary_api_failed", !logs.contains("holiday_log_primary_api_failed"))
    }

    @Test
    fun `主端点非 200 时退到备用端点`() {
        val ailcc = """
            {"code":0,"holiday":{
              "01-01":{"holiday":true,"name":"元旦节（休）","date":"2026-01-01"},
              "01-04":{"holiday":false,"name":"补班","date":"2026-01-04"}
            }}
        """.trimIndent()
        val http = FakeHttp(
            primary2026 to HolidayHttpResponse(404, ""),
            fallback2026 to HolidayHttpResponse(200, ailcc),
        )
        val logs = mutableListOf<String>()

        val data = HolidayService(http).fetchYear(2026) { logs += it }

        assertNotNull(data)
        assertEquals(2, data!!.entries.size)
        assertEquals("2026-01-01", data.entries[0].date.toLocalDate().toString())
        assertEquals("holiday_name:new_year", data.entries[0].name)
        assertEquals(HolidayType.Vacation, data.entries[0].type)
        assertEquals("2026-01-04", data.entries[1].date.toLocalDate().toString())
        assertEquals(HolidayType.AdjustedWorkday, data.entries[1].type)

        assertEquals(listOf(primary2026, fallback2026), http.requests)
        assertTrue(
            "非 200 要记状态码而不是当成解析失败",
            logs.contains("holiday_log_primary_api_status|statusCode=404"),
        )
        assertTrue(logs.contains("holiday_log_primary_api_failed"))
    }

    @Test
    fun `两端都连不上时返回 null 并各记一条异常`() {
        val http = FakeHttp() // 表里没有 url → 一律当传输失败
        val logs = mutableListOf<String>()

        val data = HolidayService(http).fetchYear(2026) { logs += it }

        assertNull("两端都拿不到数据时必须返回 null，交给内置资产兜底", data)
        assertEquals(2, http.requests.size)
        assertTrue(logs.any { it.startsWith("holiday_log_primary_api_exception|error=") })
        assertTrue(logs.contains("holiday_log_primary_api_failed"))
        assertTrue(logs.any { it.startsWith("holiday_log_fallback_api_exception|error=") })
    }

    @Test
    fun `主端点 code 非 0 时记错误消息并退备用`() {
        val ailcc = """
            {"code":0,"holiday":{
              "05-01":{"holiday":true,"name":"劳动节（休）","date":"2026-05-01"}
            }}
        """.trimIndent()
        val http = FakeHttp(
            primary2026 to HolidayHttpResponse(200, """{"code":1,"msg":"boom"}"""),
            fallback2026 to HolidayHttpResponse(200, ailcc),
        )
        val logs = mutableListOf<String>()

        val data = HolidayService(http).fetchYear(2026) { logs += it }

        assertNotNull(data)
        assertEquals(1, data!!.entries.size)
        assertEquals("holiday_name:labor_day", data.entries[0].name)
        assertTrue(logs.contains("holiday_log_primary_api_error|message=boom"))
        assertTrue(logs.contains("holiday_log_primary_api_failed"))
    }

    @Test
    fun `条目全坏时两端都判失败且不留毒数据`() {
        // 4 条全是坏的：日期不可解析 / 缺日期 / 缺 daytype / 日期空白 → 转换后 0 条。
        val badPrimary = """
            {"code":0,"data":[
              {"date":"not-a-date","daytype":1,"rest":1},
              {"daytype":1,"rest":1},
              {"date":"2026-10-01"},
              {"date":"   ","daytype":1,"rest":1}
            ]}
        """.trimIndent()
        val http = FakeHttp(
            primary2026 to HolidayHttpResponse(200, badPrimary),
            fallback2026 to HolidayHttpResponse(200, """{"code":0,"holiday":{}}"""),
        )
        val logs = mutableListOf<String>()

        val data = HolidayService(http).fetchYear(2026) { logs += it }

        assertNull("全坏 = 没拿到有效数据，不能当成成功（否则空数据会被写进缓存）", data)
        assertEquals(listOf(primary2026, fallback2026), http.requests)
        assertEquals(
            "两端各判一次「解析后无有效条目」",
            2,
            logs.count { it == "holiday_log_no_valid_entries" },
        )
    }

    @Test
    fun `响应体不是 JSON 对象时记异常而不是崩`() {
        val http = FakeHttp(
            primary2026 to HolidayHttpResponse(200, "[]"),
            fallback2026 to HolidayHttpResponse(200, "not json"),
        )
        val logs = mutableListOf<String>()

        val data = HolidayService(http).fetchYear(2026) { logs += it }

        assertNull(data)
        assertTrue(logs.any { it.startsWith("holiday_log_primary_api_exception|error=") })
        assertTrue(logs.any { it.startsWith("holiday_log_fallback_api_exception|error=") })
    }

    @Test
    fun `端点地址与超时常量与 Dart 逐字一致`() {
        assertEquals("https://publicapi.xiaoai.me/holiday/year", HolidayService.PRIMARY_BASE_URL)
        assertEquals("https://holiday.ailcc.com/api/holiday/year", HolidayService.FALLBACK_BASE_URL)
        assertEquals(primary2026, HolidayService.primaryUrl(2026))
        assertEquals(fallback2026, HolidayService.fallbackUrl(2026))
        assertEquals("Dart .timeout(Duration(seconds: 8))", 8_000, HolidayService.TIMEOUT_MILLIS)
        assertEquals(1, HolidayService.REMOTE_VERSION)
    }
}

/** 假 HTTP：按 url 查表，查不到返回 null（= 连不上，走异常分支）。 */
private class FakeHttp(vararg responses: Pair<String, HolidayHttpResponse?>) : HolidayHttp {

    private val table = responses.toMap()

    val requests = mutableListOf<String>()

    override fun get(url: String): HolidayHttpResponse? {
        requests += url
        return table[url]
    }
}
