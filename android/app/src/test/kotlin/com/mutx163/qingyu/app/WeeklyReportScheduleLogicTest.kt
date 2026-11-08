package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 周报通知纯逻辑单测（补齐「周报开关写路径」的缺件）。
 *
 * 期望值手推，出处 `lib/services/weekly_report_service.dart`：
 * `nextFireAt` `:23-34`（每周日 21:00，已过则顺延一周）、`buildTitle` `:36`、
 * `buildBody` `:38-71`（空课表 / 差值文案 / 星期简写）、星期表 `:108-119`。
 *
 * 毫秒戳那条用 **GNU `date`** 独立算出的常量当基准（不是拿同一个 API 再算一遍）：
 * `date -d "2026-11-01 21:00:00 +0800" +%s` → 1793538000 ⇒ 1793538000000 ms。
 */
class WeeklyReportScheduleLogicTest {

    private val shanghai: ZoneId = ZoneId.of("Asia/Shanghai")

    // 2026-10-26 是周一，2026-11-01 是周日，2026-11-08 是次周日（GNU date 核过）

    @Test
    fun `周一算到本周日 21 点`() {
        val fire = WeeklyReportScheduleLogic.nextFireAt(
            LocalDateTime.of(2026, 10, 26, 10, 0),
        )
        assertEquals(LocalDateTime.of(2026, 11, 1, 21, 0), fire)
    }

    @Test
    fun `周日 20 点 59 分算今天 21 点`() {
        val fire = WeeklyReportScheduleLogic.nextFireAt(
            LocalDateTime.of(2026, 11, 1, 20, 59),
        )
        assertEquals(LocalDateTime.of(2026, 11, 1, 21, 0), fire)
    }

    @Test
    fun `周日正好 21 点要顺延一周`() {
        // Dart 判据是 `if (!fire.isAfter(current))`（`:30`）⇒ 等于 21:00 也算「不晚于现在」
        val fire = WeeklyReportScheduleLogic.nextFireAt(
            LocalDateTime.of(2026, 11, 1, 21, 0),
        )
        assertEquals(LocalDateTime.of(2026, 11, 8, 21, 0), fire)
    }

    @Test
    fun `周日过了 21 点也顺延一周`() {
        val fire = WeeklyReportScheduleLogic.nextFireAt(
            LocalDateTime.of(2026, 11, 1, 21, 1),
        )
        assertEquals(LocalDateTime.of(2026, 11, 8, 21, 0), fire)
    }

    @Test
    fun `毫秒戳与独立算出的基准一致`() {
        val millis = WeeklyReportScheduleLogic.nextFireAtMillis(
            now = LocalDateTime.of(2026, 10, 26, 10, 0),
            zone = shanghai,
        )
        assertEquals(1_793_538_000_000L, millis)
        // 再独立核一次形态：这个时刻落在周日 21:00
        val back = java.time.Instant.ofEpochMilli(millis).atZone(shanghai).toLocalDateTime()
        assertEquals(LocalDateTime.of(2026, 11, 1, 21, 0), back)
        assertEquals(java.time.DayOfWeek.SUNDAY, back.dayOfWeek)
    }

    @Test
    fun `标题就是 ARB 的周报标题`() {
        assertEquals("本周课程小结", WeeklyReportScheduleLogic.buildTitle())
    }

    @Test
    fun `空课表用空态文案`() {
        assertEquals(
            "本周暂无课程，好好休息吧",
            WeeklyReportScheduleLogic.buildBody(
                courses = emptyList(),
                currentWeek = 3,
                semesterWeekCount = 16,
            ),
        )
    }

    @Test
    fun `一门课第 2 周的正文按真实数字拼`() {
        // 手推：1 门课、节次 1..2 ⇒ 本周 2 节、1 门课；
        // 最忙的一天 = 该课所在星期（5 ⇒ 「五」）；
        // 第 2 周与第 1 周课量相同 ⇒ 差值 0 ⇒ "0"。
        val body = WeeklyReportScheduleLogic.buildBody(
            courses = listOf(course(dayOfWeek = 5, startSection = 1, endSection = 2)),
            currentWeek = 2,
            semesterWeekCount = 16,
        )

        assertEquals(
            "第 2 周 · 共 2 节 · 1 门课\n较上周 0 节\n最忙的一天是 五",
            body,
        )
    }

    @Test
    fun `第 1 周的差值位置显示新学期第一周`() {
        val body = WeeklyReportScheduleLogic.buildBody(
            courses = listOf(course(dayOfWeek = 2, startSection = 1, endSection = 3)),
            currentWeek = 1,
            semesterWeekCount = 16,
        )

        assertTrue("第一周不该显示数字差值，实际：$body", body.contains("较上周 新学期第一周 节"))
        assertTrue(body.contains("第 1 周 · 共 3 节 · 1 门课"))
    }

    @Test
    fun `停课周不进本周节数`() {
        // 同一门课但第 3 周停课 ⇒ 本周 0 节、0 门课；最忙的一天为空 ⇒ 文案尾部为空串。
        val suspended = course(dayOfWeek = 4, startSection = 1, endSection = 2)
            .copy(suspendedWeeks = listOf(3))

        val body = WeeklyReportScheduleLogic.buildBody(
            courses = listOf(suspended),
            currentWeek = 3,
            semesterWeekCount = 16,
        )

        assertTrue("停课周应为 0 节，实际：$body", body.contains("第 3 周 · 共 0 节 · 0 门课"))
        assertTrue("没有最忙的一天时尾部为空，实际：$body", body.endsWith("最忙的一天是 "))
    }

    @Test
    fun `星期简写越界退化成数字`() {
        assertEquals("一", WeeklyReportScheduleLogic.weekdayShortLabel(1))
        assertEquals("日", WeeklyReportScheduleLogic.weekdayShortLabel(7))
        assertEquals("9", WeeklyReportScheduleLogic.weekdayShortLabel(9))
        assertEquals("0", WeeklyReportScheduleLogic.weekdayShortLabel(0))
    }

    @Test
    fun `周报文案与 app_zh_arb 逐字一致`() {
        val arb = loadArbZh()
        for (item in WeeklyReportStrings.allTexts) {
            val template = arb[item.key]
            assertTrue("ARB 缺少键 `${item.key}`", template != null)
            if (!template!!.contains('{')) {
                assertEquals("键 `${item.key}` 与 ARB 不一致", template, item.zh)
            } else {
                // 占位符模板：逐段核对（与仓里其它文案对拍同口径）
                val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
                var cursor = 0
                for (segment in segments) {
                    val index = item.zh.indexOf(segment, cursor)
                    assertTrue("键 `${item.key}` 的模板片段『$segment』对不上", index >= 0)
                    cursor = index + segment.length
                }
            }
        }
        assertEquals("11 条文案都要覆盖", 11, WeeklyReportStrings.allTexts.size)
    }

    private fun course(
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
    ): Course = Course(
        id = "c1",
        name = "高等数学",
        teacher = "张老师",
        location = "三教-101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:35",
        startWeek = 1,
        endWeek = 16,
    )

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var file: File? = null
        repeat(8) {
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                file = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val arbFile = file ?: error("找不到 i18n/app_zh.arb")
        val parsed = MiniJson.parse(arbFile.readText(Charsets.UTF_8))
        val map = LinkedHashMap<String, String>()
        (parsed as Map<*, *>).forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
