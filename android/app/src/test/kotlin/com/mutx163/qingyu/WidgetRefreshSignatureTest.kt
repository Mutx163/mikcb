package com.mutx163.qingyu

import com.mutx163.qingyu.app.WidgetRefreshSignature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WidgetRefreshSignature] 的 JVM 单测。期望值全部人推，不从实现里抄。
 *
 * 覆盖三件事：
 * 1. **监视清单**恰好是卡片真正会读的那几个键（多一个会白刷，少一个会漏刷）；
 * 2. **相关键判据**：年度假期按前缀认、空年份不算、无关键一律不认；
 * 3. **签名编码**：同内容同签名、内容变即变、`null` 与空串可区分、
 *    值里带分隔符 / 切分位置不同都不能撞签名（撞了就是「改了没刷」）。
 */
class WidgetRefreshSignatureTest {

    // ---------- 监视清单 ----------

    /**
     * 清单是**刻意**精确到卡片真实读取的键：
     * `TodayWidgetSupport.buildSnapshotFromFlutterState` / `StatsWidgetSupport.readSnapshot`
     * 只读档案 JSON、活动档案 id、TA 绑定与假期数据。
     * 若将来卡片开始读新键，改清单的同时把这条测试一起改——它红了就是在提醒这件事。
     */
    @Test
    fun watchedKeysAreExactlyWhatWidgetsRead() {
        assertEquals(
            listOf(
                "timetable_profiles",
                "active_timetable_profile_id",
                "partner_timetable_binding",
                "custom_holidays",
            ),
            WidgetRefreshSignature.WATCHED_KEYS,
        )
    }

    @Test
    fun relativeKeysAccepted() {
        assertTrue(WidgetRefreshSignature.isRelevant("timetable_profiles"))
        assertTrue(WidgetRefreshSignature.isRelevant("active_timetable_profile_id"))
        assertTrue(WidgetRefreshSignature.isRelevant("partner_timetable_binding"))
        assertTrue(WidgetRefreshSignature.isRelevant("custom_holidays"))
    }

    @Test
    fun yearlyHolidayKeysAcceptedByPrefix() {
        assertTrue(WidgetRefreshSignature.isRelevant("holiday_data_2026"))
        assertTrue(WidgetRefreshSignature.isRelevant("holiday_data_2027"))
    }

    @Test
    fun holidayPrefixWithoutYearIsNotRelevant() {
        // 空年份不是任何一年的数据键；放行它只会让一条无意义的写入触发重画。
        assertFalse(WidgetRefreshSignature.isRelevant("holiday_data_"))
    }

    @Test
    fun unrelatedKeysRejected() {
        // 卡片不读这些键（读的是档案内嵌 settings 与课程条目上的现成时间），
        // 它们变化不该让桌面卡片重画。
        assertFalse(WidgetRefreshSignature.isRelevant("timetable_settings"))
        assertFalse(WidgetRefreshSignature.isRelevant("current_week"))
        assertFalse(WidgetRefreshSignature.isRelevant("time_schemes"))
        assertFalse(WidgetRefreshSignature.isRelevant("schedule_date_rules"))
        assertFalse(WidgetRefreshSignature.isRelevant("location_time_groups"))
        assertFalse(WidgetRefreshSignature.isRelevant("weather_cache"))
        assertFalse(WidgetRefreshSignature.isRelevant("timetable_profiles_schema_version"))
    }

    // ---------- 签名编码 ----------

    @Test
    fun sameContentProducesSameSignature() {
        val parts = listOf("{\"courses\":[]}", "profile-1", null, "[]")
        assertEquals(WidgetRefreshSignature.build(parts), WidgetRefreshSignature.build(parts))
    }

    @Test
    fun changedContentProducesDifferentSignature() {
        assertNotEquals(
            WidgetRefreshSignature.build(listOf("{\"courses\":[]}", "profile-1")),
            WidgetRefreshSignature.build(listOf("{\"courses\":[1]}", "profile-1")),
        )
    }

    @Test
    fun nullAndEmptyStringAreDistinct() {
        // 键不存在（null）与键存在但值为空是两种状态：
        // 前者可能意味着「从未保存过」，后者是「保存了一次空内容」。
        assertNotEquals(
            WidgetRefreshSignature.build(listOf(null)),
            WidgetRefreshSignature.build(listOf("")),
        )
    }

    @Test
    fun encodingIsPinnedToLengthPrefix() {
        // 钉住编码形态本身：长度前缀 + 冒号 + 原文 + 分号，null 记作 N;。
        assertEquals("1:a;N;0:;", WidgetRefreshSignature.build(listOf("a", null, "")))
        assertEquals("", WidgetRefreshSignature.build(emptyList()))
    }

    @Test
    fun separatorInsideValueCannotFakeAnotherSplit() {
        // 值里带分隔符时，直接 join 会让 ["a\u001Fb"] 与 ["a","b"] 撞签名 ⇒ 漏刷。
        val unitSeparator = '\u001F'
        assertNotEquals(
            WidgetRefreshSignature.build(listOf("a${unitSeparator}b")),
            WidgetRefreshSignature.build(listOf("a", "b")),
        )
    }

    @Test
    fun shiftedSplitDiffers() {
        // 长度前缀还挡住「拼接串相同、切分不同」：["ab","c"] 与 ["a","bc"]。
        assertNotEquals(
            WidgetRefreshSignature.build(listOf("ab", "c")),
            WidgetRefreshSignature.build(listOf("a", "bc")),
        )
    }

    @Test
    fun fieldOrderMatters() {
        // 顺序就是各字段的语义位置；换顺序必须换签名，否则「换档」这类改动会被吞掉。
        assertNotEquals(
            WidgetRefreshSignature.build(listOf("profile-1", "profile-2")),
            WidgetRefreshSignature.build(listOf("profile-2", "profile-1")),
        )
    }
}
