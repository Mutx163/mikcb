package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「课表自动更新」落盘 store 的行为测试（P3-G1 · 移植
 * `lib/services/course_auto_refresh_store.dart` + `course_auto_refresh_settings.dart:107-158`）。
 *
 * 期望值全部按 Dart 源手推，不从 Kotlin 实现里抄：
 * 盘上格式（JSON 字符串 / 毫秒整数）、键名、默认值、夹值区间、`nextRunAt` 与 `isDue` 的判据。
 *
 * 时间换算只用 [ZoneId.systemDefault] 一处，**同一条断言里两边用同一个时区**，
 * 这样在任意时区的机器上结果都一样。
 */
class CourseAutoRefreshStoreTest {

    private val zone: ZoneId = ZoneId.systemDefault()

    /** 人推的期望毫秒值：按本机时区把「墙上的时刻」换成 epoch 毫秒。 */
    private fun millisOf(at: LocalDateTime): Long =
        at.atZone(zone).toInstant().toEpochMilli()

    private fun disk(initial: Map<String, String> = emptyMap()): InMemoryKeyValueStore =
        InMemoryKeyValueStore(initial)

    private fun schedule(
        enabled: Boolean = false,
        mode: CourseAutoRefreshMode = CourseAutoRefreshMode.EVERY_LAUNCH,
        intervalHours: Int = 24,
        dailyMinuteOfDay: Int = 450,
    ) = CourseAutoRefreshSchedule(enabled, mode, intervalHours, dailyMinuteOfDay)

    // ==========================================
    // 1. 空盘 = 默认（关 / 每次打开 / 24 小时 / 07:30）
    // ==========================================

    @Test
    fun `空盘读配置给默认值`() {
        val loaded = CourseAutoRefreshStore(disk()).load()

        // 默认关着：没配置过就不许偷偷联网抓课表。
        assertFalse(loaded.enabled)
        assertEquals(CourseAutoRefreshMode.EVERY_LAUNCH, loaded.mode)
        assertEquals(24, loaded.intervalHours)
        // 07:30 = 7 * 60 + 30
        assertEquals(450, loaded.dailyMinuteOfDay)
    }

    // ==========================================
    // 2. 往返 + 坏 JSON
    // ==========================================

    @Test
    fun `写入后换一个实例读回同一份配置`() {
        val raw = disk()

        val saved = CourseAutoRefreshStore(raw)
            .saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.DAILY_AT, intervalHours = 12, dailyMinuteOfDay = 495))

        assertTrue("回读应与写入一致", saved)
        // 换实例读：证明真落盘了，不是留在某个字段里。
        assertEquals(
            schedule(enabled = true, mode = CourseAutoRefreshMode.DAILY_AT, intervalHours = 12, dailyMinuteOfDay = 495),
            CourseAutoRefreshStore(raw).load(),
        )
    }

    @Test
    fun `坏 JSON 与空串都退回默认且不崩`() {
        val broken = disk(mapOf(CourseAutoRefreshStore.KEY_SCHEDULE to "{oops"))
        assertEquals(CourseAutoRefreshSchedule(), CourseAutoRefreshStore(broken).load())

        val blank = disk(mapOf(CourseAutoRefreshStore.KEY_SCHEDULE to ""))
        assertEquals(CourseAutoRefreshSchedule(), CourseAutoRefreshStore(blank).load())
    }

    // ==========================================
    // 3. 越界值从盘上走一遍被夹回合法区间
    // ==========================================

    @Test
    fun `间隔小时越界读回被夹到 1 和 168`() {
        val zero = disk(
            mapOf(
                CourseAutoRefreshStore.KEY_SCHEDULE to
                    """{"enabled":true,"mode":"intervalHours","intervalHours":0,"dailyMinuteOfDay":450}""",
            ),
        )
        assertEquals(1, CourseAutoRefreshStore(zero).load().intervalHours)

        val huge = disk(
            mapOf(
                CourseAutoRefreshStore.KEY_SCHEDULE to
                    """{"enabled":true,"mode":"intervalHours","intervalHours":999,"dailyMinuteOfDay":450}""",
            ),
        )
        assertEquals(168, CourseAutoRefreshStore(huge).load().intervalHours)
    }

    @Test
    fun `每日时刻越界读回被夹到 0 和 1439`() {
        val negative = disk(
            mapOf(
                CourseAutoRefreshStore.KEY_SCHEDULE to
                    """{"enabled":true,"mode":"dailyAt","intervalHours":24,"dailyMinuteOfDay":-1}""",
            ),
        )
        assertEquals(0, CourseAutoRefreshStore(negative).load().dailyMinuteOfDay)

        val tooLarge = disk(
            mapOf(
                CourseAutoRefreshStore.KEY_SCHEDULE to
                    """{"enabled":true,"mode":"dailyAt","intervalHours":24,"dailyMinuteOfDay":2000}""",
            ),
        )
        // 24 * 60 - 1 = 1439（23:59）
        assertEquals(1439, CourseAutoRefreshStore(tooLarge).load().dailyMinuteOfDay)
    }

    // ==========================================
    // 4 / 5. 台账两个键的写入范围
    // ==========================================

    @Test
    fun `recordSuccess 同时写成功与尝试两个键`() {
        val raw = disk()
        val at = LocalDateTime.of(2026, 10, 29, 9, 15, 30)
        CourseAutoRefreshStore(raw).recordSuccess(at)

        val reread = CourseAutoRefreshStore(raw)
        assertEquals(at, reread.lastSuccessAt())
        assertEquals("成功之后尝试时间必须一起推到现在（否则会自相矛盾地进冷却）", at, reread.lastAttemptAt())

        // 盘上必须是**毫秒**十进制整数，不是秒、不是 JSON。
        val snapshot = raw.rawSnapshot()
        assertEquals(
            millisOf(at).toString(),
            snapshot["flutter." + CourseAutoRefreshStore.KEY_LAST_SUCCESS],
        )
        assertEquals(
            millisOf(at).toString(),
            snapshot["flutter." + CourseAutoRefreshStore.KEY_LAST_ATTEMPT],
        )
        // 1.7e12 量级，Int 装不下——这条断言钉住「毫秒」而不是「秒」。
        assertTrue(millisOf(at) > 1_000_000_000_000L)
    }

    @Test
    fun `recordAttempt 只写尝试键成功仍为空`() {
        val raw = disk()
        val at = LocalDateTime.of(2026, 10, 29, 9, 15, 30)
        CourseAutoRefreshStore(raw).recordAttempt(at)

        val reread = CourseAutoRefreshStore(raw)
        assertNull(reread.lastSuccessAt())
        assertEquals(at, reread.lastAttemptAt())
    }

    // ==========================================
    // 6. 键名逐字钉住
    // ==========================================

    @Test
    fun `三个键名与 Dart 逐字一致`() {
        assertEquals("course_auto_refresh_v1", CourseAutoRefreshStore.KEY_SCHEDULE)
        assertEquals("course_auto_refresh_last_success_v1", CourseAutoRefreshStore.KEY_LAST_SUCCESS)
        assertEquals("course_auto_refresh_last_attempt_v1", CourseAutoRefreshStore.KEY_LAST_ATTEMPT)

        // 落盘时由 KeyValueStore 加 flutter. 前缀（Dart 插件自动加的那一段）。
        val raw = disk()
        val store = CourseAutoRefreshStore(raw)
        store.saveSchedule(schedule(enabled = true))
        store.recordAttempt(LocalDateTime.of(2026, 10, 29, 9, 0))
        assertEquals(
            setOf(
                "flutter.course_auto_refresh_v1",
                "flutter.course_auto_refresh_last_attempt_v1",
            ),
            raw.rawSnapshot().keys,
        )
    }

    // ==========================================
    // 7. nextRunAt
    // ==========================================

    @Test
    fun `关着不推算下次运行`() {
        assertNull(CourseAutoRefreshStore(disk()).nextRunAt(LocalDateTime.of(2026, 10, 29, 12, 0)))
    }

    @Test
    fun `间隔模式下次等于上次成功加间隔`() {
        val raw = disk()
        val store = CourseAutoRefreshStore(raw)
        store.saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.INTERVAL_HOURS, intervalHours = 12))
        store.recordSuccess(LocalDateTime.of(2026, 10, 27, 8, 0))

        // 08:00 + 12h = 20:00
        assertEquals(
            LocalDateTime.of(2026, 10, 27, 20, 0),
            CourseAutoRefreshStore(raw).nextRunAt(LocalDateTime.of(2026, 10, 27, 12, 0)),
        )
    }

    @Test
    fun `每天定时_今天这一档已跑过就顺延到明天`() {
        val raw = disk()
        val store = CourseAutoRefreshStore(raw)
        store.saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.DAILY_AT, dailyMinuteOfDay = 450))
        // 今天 07:45 已经跑过 07:30 这一档
        store.recordSuccess(LocalDateTime.of(2026, 10, 29, 7, 45))

        assertEquals(
            LocalDateTime.of(2026, 10, 30, 7, 30),
            CourseAutoRefreshStore(raw).nextRunAt(LocalDateTime.of(2026, 10, 29, 12, 0)),
        )
    }

    @Test
    fun `每天定时_今天这一档还没到就是今天`() {
        val raw = disk()
        val store = CourseAutoRefreshStore(raw)
        store.saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.DAILY_AT, dailyMinuteOfDay = 450))
        // 只有昨天那一档跑过；现在是今天 06:00，07:30 还没到
        store.recordSuccess(LocalDateTime.of(2026, 10, 28, 7, 45))

        assertEquals(
            LocalDateTime.of(2026, 10, 29, 7, 30),
            CourseAutoRefreshStore(raw).nextRunAt(LocalDateTime.of(2026, 10, 29, 6, 0)),
        )
    }

    // ==========================================
    // 8. isDue
    // ==========================================

    @Test
    fun `关着一律不跑`() {
        assertFalse(CourseAutoRefreshStore(disk()).isDue(LocalDateTime.of(2026, 10, 29, 12, 0)))
    }

    @Test
    fun `间隔模式未到点不跑到点就跑`() {
        val raw = disk()
        val store = CourseAutoRefreshStore(raw)
        store.saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.INTERVAL_HOURS, intervalHours = 12))
        store.recordSuccess(LocalDateTime.of(2026, 10, 29, 8, 0))

        // 19:00 = 11 小时，未满 12
        assertFalse(CourseAutoRefreshStore(raw).isDue(LocalDateTime.of(2026, 10, 29, 19, 0)))
        // 20:00 = 正好 12 小时 ⇒ 到点
        assertTrue(CourseAutoRefreshStore(raw).isDue(LocalDateTime.of(2026, 10, 29, 20, 0)))
    }

    @Test
    fun `失败冷却内不跑冷却过后才跑`() {
        val now = LocalDateTime.of(2026, 10, 29, 12, 0)

        val coolingRaw = disk()
        val cooling = CourseAutoRefreshStore(coolingRaw)
        cooling.saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.EVERY_LAUNCH))
        // 10 分钟前尝试失败（没有成功记录），30 分钟冷却还没过
        cooling.recordAttempt(now.minusMinutes(10))
        assertFalse(CourseAutoRefreshStore(coolingRaw).isDue(now))

        val expiredRaw = disk()
        val expired = CourseAutoRefreshStore(expiredRaw)
        expired.saveSchedule(schedule(enabled = true, mode = CourseAutoRefreshMode.EVERY_LAUNCH))
        expired.recordAttempt(now.minusMinutes(31))
        assertTrue(CourseAutoRefreshStore(expiredRaw).isDue(now))
    }

    // ==========================================
    // 9. applyEdit
    // ==========================================

    @Test
    fun `开关行 target 为空时取反其它 target 一律不动`() {
        val off = schedule(enabled = false)
        assertEquals(
            true,
            CourseAutoRefreshSettingsLogic.applyEdit(CourseAutoRefreshSettingsLogic.ROW_SWITCH, null, off)?.enabled,
        )

        val on = schedule(enabled = true)
        assertEquals(
            false,
            CourseAutoRefreshSettingsLogic.applyEdit(CourseAutoRefreshSettingsLogic.ROW_SWITCH, null, on)?.enabled,
        )

        assertNull(
            "开关行不携带值，带值说明调错了行",
            CourseAutoRefreshSettingsLogic.applyEdit(CourseAutoRefreshSettingsLogic.ROW_SWITCH, "true", off),
        )
    }

    @Test
    fun `档位行认三个 serialName`() {
        val current = schedule(enabled = true)
        val row = CourseAutoRefreshSettingsLogic.ROW_MODE

        assertEquals(
            CourseAutoRefreshMode.EVERY_LAUNCH,
            CourseAutoRefreshSettingsLogic.applyEdit(row, "everyLaunch", current)?.mode,
        )
        assertEquals(
            CourseAutoRefreshMode.INTERVAL_HOURS,
            CourseAutoRefreshSettingsLogic.applyEdit(row, "intervalHours", current)?.mode,
        )
        assertEquals(
            CourseAutoRefreshMode.DAILY_AT,
            CourseAutoRefreshSettingsLogic.applyEdit(row, "dailyAt", current)?.mode,
        )
        assertNull("认不出的档位不许瞎猜", CourseAutoRefreshSettingsLogic.applyEdit(row, "hourly", current))
        assertNull(CourseAutoRefreshSettingsLogic.applyEdit(row, null, current))
    }

    @Test
    fun `间隔滑杆解析数字再四舍五入并夹区间`() {
        val current = schedule(enabled = true, mode = CourseAutoRefreshMode.INTERVAL_HOURS)
        val row = CourseAutoRefreshSettingsLogic.ROW_INTERVAL

        // 滑杆回传带小数点是常态
        assertEquals(24, CourseAutoRefreshSettingsLogic.applyEdit(row, "24.0", current)?.intervalHours)
        // 0.4 四舍五入成 0，再夹到下限 1
        assertEquals(1, CourseAutoRefreshSettingsLogic.applyEdit(row, "0.4", current)?.intervalHours)
        // 12.5 半入 ⇒ 13
        assertEquals(13, CourseAutoRefreshSettingsLogic.applyEdit(row, "12.5", current)?.intervalHours)
        // 999 夹到上限 168
        assertEquals(168, CourseAutoRefreshSettingsLogic.applyEdit(row, "999", current)?.intervalHours)

        assertNull(CourseAutoRefreshSettingsLogic.applyEdit(row, "abc", current))
        assertNull(CourseAutoRefreshSettingsLogic.applyEdit(row, null, current))
    }

    @Test
    fun `其余行与未知行一律不归本逻辑`() {
        val current = schedule(enabled = true)

        // 每日时刻由时间弹层处理、试运行由执行器处理，都不改配置对象。
        assertNull(CourseAutoRefreshSettingsLogic.applyEdit(CourseAutoRefreshSettingsLogic.ROW_DAILY_TIME, "480", current))
        assertNull(CourseAutoRefreshSettingsLogic.applyEdit(CourseAutoRefreshSettingsLogic.ROW_TRY_NOW, null, current))
        assertNull(CourseAutoRefreshSettingsLogic.applyEdit("general.autoRefresh.unknown", "x", current))
        assertNull(CourseAutoRefreshSettingsLogic.applyEdit("", "x", current))
    }

    @Test
    fun `行 id 与设置页约定逐字一致`() {
        assertEquals("general.autoRefresh.switch", CourseAutoRefreshSettingsLogic.ROW_SWITCH)
        assertEquals("general.autoRefresh.mode", CourseAutoRefreshSettingsLogic.ROW_MODE)
        assertEquals("general.autoRefresh.interval", CourseAutoRefreshSettingsLogic.ROW_INTERVAL)
        assertEquals("general.autoRefresh.dailyTime", CourseAutoRefreshSettingsLogic.ROW_DAILY_TIME)
        assertEquals("general.autoRefresh.tryNow", CourseAutoRefreshSettingsLogic.ROW_TRY_NOW)
    }

    // ==========================================
    // 10. 毫秒精度往返
    // ==========================================

    @Test
    fun `毫秒时间戳往返精确到毫秒`() {
        val at = LocalDateTime.of(2026, 10, 29, 13, 45, 30, 123_000_000) // 13:45:30.123
        val raw = disk()
        CourseAutoRefreshStore(raw).recordSuccess(at)

        val expectedMillis = millisOf(at)
        assertEquals(
            expectedMillis.toString(),
            raw.rawSnapshot()["flutter." + CourseAutoRefreshStore.KEY_LAST_SUCCESS],
        )

        // 同一条断言里两边都用 zone 换算，避免依赖机器时区。
        val reread = CourseAutoRefreshStore(raw).lastSuccessAt()
        assertEquals(LocalDateTime.ofInstant(Instant.ofEpochMilli(expectedMillis), zone), reread)
        assertEquals(at, reread)
    }

    // ==========================================
    // saveSchedule 的返回值不是摆设
    // ==========================================

    @Test
    fun `落盘被吞时 saveSchedule 返回 false`() {
        // 写下去但读不回来的存储：模拟「写入失败但没抛异常」。
        assertFalse(CourseAutoRefreshStore(SilentDropStore()).saveSchedule(schedule(enabled = true)))
    }

    /** 读正常、**写静默丢弃**的存储：用来证明 `saveSchedule` 确实做了回读验证。 */
    private class SilentDropStore : KeyValueStore {
        private val delegate = InMemoryKeyValueStore()

        override fun getString(key: String): String? = delegate.getString(key)
        override fun getInt(key: String, default: Int): Int = delegate.getInt(key, default)
        override fun getLong(key: String, default: Long): Long = delegate.getLong(key, default)
        override fun getBool(key: String, default: Boolean): Boolean = delegate.getBool(key, default)
        override fun getStringList(key: String): List<String>? = delegate.getStringList(key)
        override fun putString(key: String, value: String) = Unit
        override fun putInt(key: String, value: Int) = Unit
        override fun putLong(key: String, value: Long) = Unit
        override fun putBool(key: String, value: Boolean) = Unit
        override fun putStringList(key: String, value: List<String>) = Unit
        override fun remove(key: String) = Unit
        override fun contains(key: String): Boolean = delegate.contains(key)
        override fun archiveCorruptAndRemove(key: String, micros: Long): String = ""
        override fun keys(): Set<String> = delegate.keys()
    }
}
