package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * 假期日期键必须是 ASCII 数字。
 *
 * Flutter 侧持久化并下发的假期键恒为 ASCII（`live_activity_controller.dart` 用
 * Dart 的 `yyyy-MM-dd` 格式化），而 `String.format("%04d-%02d-%02d", …)` 不带
 * 显式 Locale 时用的是**设备默认语言**的数字：阿语环境产出 `٢٠٢٦-١٠-٠٢`、
 * 波斯语环境产出 `۲۰۲۶-۱۰-۰۲`（本机 JDK 实测，Android 的 libcore Formatter
 * 同源）。两边永不相等，于是假期当天超级岛照开、开课前自动静音照常执行、
 * 桌面小组件的假期标记也失效 —— 全程没有任何报错，用户只会看到「国庆还弹课表」。
 *
 * `ExamReminderScheduler.kt:226` 对**同一个格式串**已经写了 `Locale.US`，本文件
 * 钉的是其余三处漏掉的。
 */
class LocaleIndependentDateKeyTest {
    private fun withLocale(tag: String, block: () -> Unit) {
        val previous = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag(tag))
            block()
        } finally {
            Locale.setDefault(previous)
        }
    }

    @Test
    fun widgetFormatDateStaysAsciiUnderArabicLocale() {
        withLocale("ar") {
            assertEquals("2026-10-02", widgetFormatDate(2026, 10, 2))
        }
        withLocale("fa") {
            assertEquals("2026-04-13", widgetFormatDate(2026, 4, 13))
        }
    }

    @Test
    fun holidayDateMatchStaysAsciiUnderArabicLocale() {
        withLocale("ar") {
            assertTrue(
                liveSchedulerIsDateHoliday(
                    holidayDates = setOf("2026-10-02"),
                    holidayOverrideEnabled = false,
                    enableHolidayMarking = true,
                    year = 2026,
                    month = 10,
                    dayOfMonth = 2,
                ),
            )
            assertFalse(
                liveSchedulerIsDateHoliday(
                    holidayDates = emptySet(),
                    holidayOverrideEnabled = false,
                    enableHolidayMarking = true,
                    year = 2026,
                    month = 10,
                    dayOfMonth = 2,
                    adjustedWorkdayDates = setOf("2026-10-02"),
                ),
            )
        }
    }

    @Test
    fun legacyHolidayFlagStaysAsciiUnderArabicLocale() {
        withLocale("ar") {
            assertTrue(
                liveSchedulerIsLegacyHolidayFlagActive(
                    isHoliday = true,
                    isHolidayDate = "2026-10-02",
                    year = 2026,
                    month = 10,
                    dayOfMonth = 2,
                ),
            )
        }
    }
}
