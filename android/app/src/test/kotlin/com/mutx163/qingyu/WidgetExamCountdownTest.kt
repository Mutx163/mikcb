package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class WidgetExamCountdownTest {
    private fun midnightMillis(date: String, zone: ZoneId): Long =
        LocalDate.parse(date).atStartOfDay(zone).toInstant().toEpochMilli()

    @Test
    fun countsPlainCalendarDays() {
        val utc = ZoneId.of("UTC")
        assertEquals(
            0,
            widgetExamDaysUntil("2026-10-02", midnightMillis("2026-10-02", utc), utc),
        )
        assertEquals(
            1,
            widgetExamDaysUntil("2026-10-03", midnightMillis("2026-10-02", utc), utc),
        )
        assertEquals(
            12,
            widgetExamDaysUntil("2026-10-14", midnightMillis("2026-10-02", utc), utc),
        )
    }

    @Test
    fun pastExamsClampToZero() {
        val utc = ZoneId.of("UTC")
        assertEquals(
            0,
            widgetExamDaysUntil("2026-09-30", midnightMillis("2026-10-02", utc), utc),
        )
    }

    // 2026-03-08 是美国「拨快」那天：本地 00:00 → 次日 00:00 只经过 23 小时。
    // 原来 `(examMidnight - todayMidnight) / 86_400_000` 整除后得 0，明天的考试
    // 角标显示成「今天」。
    @Test
    fun springForwardDayStillCountsAsOneDay() {
        val newYork = ZoneId.of("America/New_York")
        val nowMillis = midnightMillis("2026-03-08", newYork)

        assertEquals(1, widgetExamDaysUntil("2026-03-09", nowMillis, newYork))
        assertEquals(2, widgetExamDaysUntil("2026-03-10", nowMillis, newYork))
    }

    // 2026-11-01 是「拨慢」那天，跨它的一天有 25 小时，整除法会多算一天。
    @Test
    fun fallBackDayDoesNotAddAnExtraDay() {
        val newYork = ZoneId.of("America/New_York")
        val nowMillis = midnightMillis("2026-10-31", newYork)

        assertEquals(1, widgetExamDaysUntil("2026-11-01", nowMillis, newYork))
        assertEquals(2, widgetExamDaysUntil("2026-11-02", nowMillis, newYork))
    }

    @Test
    fun malformedDatesYieldNullInsteadOfThrowing() {
        val utc = ZoneId.of("UTC")
        val now = midnightMillis("2026-10-02", utc)

        // 这三条以前会在 RemoteViewsFactory 里抛 NumberFormatException，
        // 表现是整个小组件持续「加载失败」而不是少一个角标。
        assertNull(widgetExamDaysUntil("2026-10", now, utc))
        assertNull(widgetExamDaysUntil("a-b-c", now, utc))
        assertNull(widgetExamDaysUntil("2026-13-45", now, utc))
        assertNull(widgetExamDaysUntil("", now, utc))
    }
}
