package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartFormatException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * D3 守卫：`HolidayData.year` 接受带空白的数字字符串。
 *
 * Dart 侧 `holiday_entry.dart:228` 用 `int.tryParse(rawYear)`（**不** trim），
 * Kotlin 侧多做了 `.trim()`，属于「读入放宽」。按 D2 的统一口径，读入口径
 * 故意比 Dart 宽（历史脏数据要能读出来），所以这里不删 trim，只用测试把
 * 这个决定钉住，防止后续被误改成收紧。
 */
class HolidayYearLenientReadTest {

    @Test
    fun `带空白与正号的年份字符串仍可读`() {
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to " 2026 ")).year)
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to "\t2026\n")).year)
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to "+2026")).year)
    }

    @Test
    fun `非整数年份字符串仍然拒绝`() {
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(mapOf("year" to "2026.5"))
        }
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(mapOf("year" to ""))
        }
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(mapOf("year" to "abc"))
        }
    }

    @Test
    fun `全角数字按 JVM 字符口径仍可解析`() {
        // Dart 的 int.tryParse 只认 ASCII，Kotlin 走 JVM 的 Unicode 数字识别——
        // 属于「读入更宽」，不影响写出口径，故保留并钉住。
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to "２０２６")).year)
    }
}
