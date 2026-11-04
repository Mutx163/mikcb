package com.mutx163.qingyu.pages.timetable

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Locale

/**
 * 节次兜底时刻必须**不随设备 Locale 变字形**。
 *
 * `String.format("%02d", …)` 在 `ar-EG` 下会输出 `٢٠` 这类阿拉伯数字，而 Dart 的
 * `padLeft` 恒为 ASCII —— 跨端文本/哈希会被判成「内容不同」。本用例把默认 Locale
 * 临时切到 `ar-EG`，断言兜底生成的时刻仍是 ASCII；`@After` 一定还原，避免污染
 * 同 JVM 的其他用例。
 */
class TimetableGridMetricsLocaleTest {

    private lateinit var original: Locale

    @Before
    fun 切到阿拉伯语数字的默认Locale() {
        original = Locale.getDefault()
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
    }

    @After
    fun 还原默认Locale() {
        Locale.setDefault(original)
    }

    @Test
    fun 超出预设节次时兜底时刻仍是ASCII数字() {
        val slots = TimetableGridMetrics.defaultSectionTimeSlots(count = 14)

        // 第 13 节起走兜底分支（预设只到 21:45）。
        assertEquals("20:00", slots[12].startTime)
        assertEquals("20:45", slots[12].endTime)
        assertEquals("21:00", slots[13].startTime)
        assertEquals("21:45", slots[13].endTime)

        slots.forEach { slot ->
            assertTrue("起始时刻 [${slot.startTime}] 含非 ASCII 字符", slot.startTime.all { it.code < 128 })
            assertTrue("结束时刻 [${slot.endTime}] 含非 ASCII 字符", slot.endTime.all { it.code < 128 })
        }
    }

    @Test
    fun 预设节次时刻不受Locale影响() {
        val slots = TimetableGridMetrics.defaultSectionTimeSlots(count = 12)
        assertEquals("08:00", slots.first().startTime)
        assertEquals("22:30", slots.last().endTime)
    }
}
