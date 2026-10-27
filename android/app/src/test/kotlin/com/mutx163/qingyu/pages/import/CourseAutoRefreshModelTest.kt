package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import java.time.Duration
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课表自动更新判据测试（P3-G1 · course_auto_refresh_runner.dart 及其依赖
 * course_auto_refresh_decision.dart / course_auto_refresh_controller.dart /
 * course_timetable_signature.dart）。
 *
 * 判据真源是 `decideCourseAutoRefresh`：判「上次成功」+ 独立失败冷却。
 * 期望值全部按 Dart 源手推。
 */
class CourseAutoRefreshModelTest {

    private val now = LocalDateTime.of(2026, 10, 27, 12, 0)

    private fun schedule(
        enabled: Boolean = true,
        mode: CourseAutoRefreshMode = CourseAutoRefreshMode.EVERY_LAUNCH,
        intervalHours: Int = 24,
        dailyMinuteOfDay: Int = 450,
    ) = CourseAutoRefreshSchedule(enabled, mode, intervalHours, dailyMinuteOfDay)

    // ==========================================
    // 1. 三种模式的时间窗判定
    // ==========================================

    @Test
    fun `功能关闭一律 disabled`() {
        assertEquals(
            CourseAutoRefreshDecision.DISABLED,
            CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(enabled = false), now, null, null),
        )
    }

    @Test
    fun `每次打开模式带 30 分钟冷却`() {
        // 从未成功 → 立即跑
        assertEquals(CourseAutoRefreshDecision.RUN, CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(), now, null, null))
        // 10 分钟前刚成功 → 冷却中
        assertEquals(
            CourseAutoRefreshDecision.WAIT,
            CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(), now, now.minusMinutes(10), null),
        )
        // 31 分钟前成功 → 冷却已过
        assertEquals(
            CourseAutoRefreshDecision.RUN,
            CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(), now, now.minusMinutes(31), null),
        )
    }

    @Test
    fun `间隔模式距上次成功满 N 小时才跑`() {
        val interval = schedule(mode = CourseAutoRefreshMode.INTERVAL_HOURS, intervalHours = 24)
        assertEquals(CourseAutoRefreshDecision.RUN, CourseAutoRefreshModel.decideCourseAutoRefresh(interval, now, null, null))
        assertEquals(
            CourseAutoRefreshDecision.WAIT,
            CourseAutoRefreshModel.decideCourseAutoRefresh(interval, now, now.minus(Duration.ofHours(23)), null),
        )
        assertEquals(
            CourseAutoRefreshDecision.RUN,
            CourseAutoRefreshModel.decideCourseAutoRefresh(interval, now, now.minus(Duration.ofHours(25)), null),
        )
    }

    @Test
    fun `每天定时模式按最近一档比较`() {
        val daily = schedule(mode = CourseAutoRefreshMode.DAILY_AT, dailyMinuteOfDay = 450) // 07:30

        // 从未成功 → 跑
        assertEquals(CourseAutoRefreshDecision.RUN, CourseAutoRefreshModel.decideCourseAutoRefresh(daily, now, null, null))

        // 现在 12:00，今天 07:30 已过：昨天成功 → 跑；今天 08:00 成功 → 等待
        assertEquals(
            CourseAutoRefreshDecision.RUN,
            CourseAutoRefreshModel.decideCourseAutoRefresh(daily, now, LocalDateTime.of(2026, 10, 26, 8, 0), null),
        )
        assertEquals(
            CourseAutoRefreshDecision.WAIT,
            CourseAutoRefreshModel.decideCourseAutoRefresh(daily, now, LocalDateTime.of(2026, 10, 27, 8, 0), null),
        )
    }

    @Test
    fun `每天定时跨零点用昨天那一档`() {
        // now = 06:00，今天的 07:30 档还没到 → 目标是昨天 07:30
        val early = LocalDateTime.of(2026, 10, 27, 6, 0)
        val daily = schedule(mode = CourseAutoRefreshMode.DAILY_AT, dailyMinuteOfDay = 450)
        // 昨天 08:00 成功（晚于昨天档）→ 等待
        assertEquals(
            CourseAutoRefreshDecision.WAIT,
            CourseAutoRefreshModel.decideCourseAutoRefresh(daily, early, LocalDateTime.of(2026, 10, 26, 8, 0), null),
        )
        // 昨天 07:00 成功（早于昨天档）→ 跑
        assertEquals(
            CourseAutoRefreshDecision.RUN,
            CourseAutoRefreshModel.decideCourseAutoRefresh(daily, early, LocalDateTime.of(2026, 10, 26, 7, 0), null),
        )
    }

    @Test
    fun `mostRecentDailySlot 今天档没到就回退到昨天`() {
        assertEquals(
            LocalDateTime.of(2026, 10, 27, 7, 30),
            CourseAutoRefreshModel.mostRecentDailySlot(LocalDateTime.of(2026, 10, 27, 8, 0), 450),
        )
        assertEquals(
            LocalDateTime.of(2026, 10, 26, 7, 30),
            CourseAutoRefreshModel.mostRecentDailySlot(LocalDateTime.of(2026, 10, 27, 6, 0), 450),
        )
        // 恰好到点：今天这一档算「已过去的时刻」
        assertEquals(
            LocalDateTime.of(2026, 10, 27, 7, 30),
            CourseAutoRefreshModel.mostRecentDailySlot(LocalDateTime.of(2026, 10, 27, 7, 30), 450),
        )
    }

    // ==========================================
    // 2. 失败冷却（判据独立于成功时间窗）
    // ==========================================

    @Test
    fun `上次尝试失败且在冷却期内不再打扰`() {
        // 尝试(11:50) 晚于 成功(11:40) → 判失败；冷却 30 分钟没到 → 等待
        val lastAttempt = now.minusMinutes(10)
        val lastSuccess = now.minusMinutes(20)
        assertEquals(
            CourseAutoRefreshDecision.WAIT,
            CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(), now, lastSuccess, lastAttempt),
        )
    }

    @Test
    fun `失败冷却过了之后回到模式判定`() {
        val lastAttempt = now.minusMinutes(31)
        val lastSuccess = now.minusMinutes(60)
        // 每次打开模式：成功在 60 分钟前 → 冷却也过了 → 跑
        assertEquals(
            CourseAutoRefreshDecision.RUN,
            CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(), now, lastSuccess, lastAttempt),
        )
    }

    @Test
    fun `成功晚于尝试时失败冷却不生效`() {
        // 成功(11:55) 晚于尝试(11:50)：最后一次是成功的 → 不看失败冷却，看模式
        // 每次打开模式：成功在 5 分钟前 → 冷却中 → 等待
        val lastAttempt = now.minusMinutes(10)
        val lastSuccess = now.minusMinutes(5)
        assertEquals(
            CourseAutoRefreshDecision.WAIT,
            CourseAutoRefreshModel.decideCourseAutoRefresh(schedule(), now, lastSuccess, lastAttempt),
        )
    }

    // ==========================================
    // 3. 配置对象：钳制与序列化
    // ==========================================

    @Test
    fun `间隔小时与每日分钟钳制到合法区间`() {
        assertEquals(1, CourseAutoRefreshModel.clampIntervalHours(0))
        assertEquals(1, CourseAutoRefreshModel.clampIntervalHours(-5))
        assertEquals(168, CourseAutoRefreshModel.clampIntervalHours(999))
        assertEquals(24, CourseAutoRefreshModel.clampIntervalHours(24))
        assertEquals(0, CourseAutoRefreshModel.clampDailyMinute(-1))
        assertEquals(1439, CourseAutoRefreshModel.clampDailyMinute(2000))
        assertEquals(450, CourseAutoRefreshModel.clampDailyMinute(450))
    }

    @Test
    fun `配置 JSON 容错解析坏值退回默认`() {
        // 非 Map → 全默认
        val defaults = CourseAutoRefreshSchedule.fromJson("garbage")
        assertEquals(false, defaults.enabled)
        assertEquals(CourseAutoRefreshMode.EVERY_LAUNCH, defaults.mode)
        assertEquals(24, defaults.intervalHours)
        assertEquals(450, defaults.dailyMinuteOfDay)

        // 字段坏：字符串数字不算数（Dart hours is int 判定）→ 默认
        val dirty = CourseAutoRefreshSchedule.fromJson(
            MiniJson.parse("""{"enabled":true,"mode":"dailyAt","intervalHours":"48","dailyMinuteOfDay":600}"""),
        )
        assertTrue(dirty.enabled)
        assertEquals(CourseAutoRefreshMode.DAILY_AT, dirty.mode)
        assertEquals(24, dirty.intervalHours)
        assertEquals(600, dirty.dailyMinuteOfDay)

        // 越界值钳制
        val clamped = CourseAutoRefreshSchedule.fromJson(
            MiniJson.parse("""{"enabled":true,"intervalHours":999,"dailyMinuteOfDay":2000}"""),
        )
        assertEquals(168, clamped.intervalHours)
        assertEquals(1439, clamped.dailyMinuteOfDay)
    }

    @Test
    fun `配置 JSON 键名与 Dart 逐字一致且可往返`() {
        val schedule = schedule(enabled = true, mode = CourseAutoRefreshMode.INTERVAL_HOURS, intervalHours = 48, dailyMinuteOfDay = 600)
        val json = schedule.toJson()
        assertEquals(setOf("enabled", "mode", "intervalHours", "dailyMinuteOfDay"), json.keys)
        assertEquals(true, json["enabled"])
        assertEquals("intervalHours", json["mode"]) // Dart enum name 序列化
        assertEquals(48, json["intervalHours"])
        assertEquals(600, json["dailyMinuteOfDay"])

        val restored = CourseAutoRefreshSchedule.fromJson(MiniJson.parse(MiniJson.encode(json)))
        assertEquals(schedule, restored)
    }

    // ==========================================
    // 4. 课表内容指纹（timetableContentSignature）
    // ==========================================

    private fun course(
        id: String,
        name: String = "高等数学",
        teacher: String = "李老师",
        color: String = "#2196F3",
        note: String? = null,
    ) = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = "教学楼101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "08:45",
        color = color,
        startWeek = 1,
        endWeek = 16,
        note = note,
    )

    @Test
    fun `空课表指纹是 empty`() {
        assertEquals("empty", CourseAutoRefreshModel.timetableContentSignature(emptyList()))
    }

    @Test
    fun `指纹与顺序无关`() {
        val a = course("a", name = "课程A")
        val b = course("b", name = "课程B")
        assertEquals(
            CourseAutoRefreshModel.timetableContentSignature(listOf(a, b)),
            CourseAutoRefreshModel.timetableContentSignature(listOf(b, a)),
        )
    }

    @Test
    fun `指纹不收 id 颜色与备注`() {
        // 这些是本机编辑物/随机分配物：重导一遍颜色不应被判成「有新课表」
        val base = course("a")
        val recolored = course("different-id", color = "#EF4444", note = "随手记的")
        assertEquals(
            CourseAutoRefreshModel.timetableContentSignature(listOf(base)),
            CourseAutoRefreshModel.timetableContentSignature(listOf(recolored)),
        )
    }

    @Test
    fun `教务会改的字段变化会改指纹`() {
        val base = course("a")
        val renamed = course("a", name = "高等数学(下)")
        assertTrue(
            CourseAutoRefreshModel.timetableContentSignature(listOf(base)) !=
                CourseAutoRefreshModel.timetableContentSignature(listOf(renamed)),
        )
        val retimed = course("a").copy(hasCustomTime = true)
        assertTrue(
            CourseAutoRefreshModel.timetableContentSignature(listOf(base)) !=
                CourseAutoRefreshModel.timetableContentSignature(listOf(retimed)),
        )
    }

    @Test
    fun `指纹格式为 行数井号加 8 位十六进制`() {
        val signature = CourseAutoRefreshModel.timetableContentSignature(listOf(course("a")))
        assertTrue(signature, Regex("^1#[0-9a-f]{8}$").matches(signature))
    }

    // ==========================================
    // 5. 下次运行时刻（nextRunAt，设置页显示用）
    // ==========================================

    @Test
    fun `nextRunAt 功能关闭返回 null`() {
        assertNull(
            CourseAutoRefreshModel.nextRunAt(schedule(enabled = false), lastSuccessAt = null, now = now),
        )
    }

    @Test
    fun `nextRunAt 每次打开模式按成功时间加冷却`() {
        // 从未成功：现在就跑
        assertEquals(now, CourseAutoRefreshModel.nextRunAt(schedule(), null, now))
        // 成功于 10 分钟前：下次 = 成功 + 30 分钟
        assertEquals(
            now.plusMinutes(20),
            CourseAutoRefreshModel.nextRunAt(schedule(), now.minusMinutes(10), now),
        )
    }

    @Test
    fun `nextRunAt 间隔模式按成功时间加间隔`() {
        val interval = schedule(mode = CourseAutoRefreshMode.INTERVAL_HOURS, intervalHours = 48)
        assertEquals(now, CourseAutoRefreshModel.nextRunAt(interval, null, now))
        assertEquals(
            now.minusMinutes(10).plus(Duration.ofHours(48)),
            CourseAutoRefreshModel.nextRunAt(interval, now.minusMinutes(10), now),
        )
    }

    @Test
    fun `nextRunAt 每天定时已抓过今天档就推到明天`() {
        val daily = schedule(mode = CourseAutoRefreshMode.DAILY_AT, dailyMinuteOfDay = 450)
        val todaySlot = LocalDateTime.of(2026, 10, 27, 7, 30)
        // 今天 08:00 已成功（晚于今天档）→ 明天 07:30
        assertEquals(
            LocalDateTime.of(2026, 10, 28, 7, 30),
            CourseAutoRefreshModel.nextRunAt(daily, LocalDateTime.of(2026, 10, 27, 8, 0), now),
        )
        // 还没抓今天档 → 今天 07:30
        assertEquals(
            todaySlot,
            CourseAutoRefreshModel.nextRunAt(daily, LocalDateTime.of(2026, 10, 26, 8, 0), now),
        )
    }

    // ==========================================
    // 6. 结局枚举与常量（对齐 Dart 命名语义）
    // ==========================================

    @Test
    fun `结局枚举七个值与 Dart 对齐`() {
        assertEquals(
            setOf(
                CourseAutoRefreshOutcome.DISABLED,
                CourseAutoRefreshOutcome.NOT_DUE,
                CourseAutoRefreshOutcome.NO_SOURCE,
                CourseAutoRefreshOutcome.BUSY,
                CourseAutoRefreshOutcome.UNCHANGED,
                CourseAutoRefreshOutcome.UPDATED,
                CourseAutoRefreshOutcome.FAILED,
            ),
            CourseAutoRefreshOutcome.entries.toSet(),
        )
    }

    @Test
    fun `冷却与默认值常量对齐 Dart`() {
        assertEquals(Duration.ofMinutes(30), CourseAutoRefreshModel.LAUNCH_COOLDOWN)
        assertEquals(Duration.ofMinutes(30), CourseAutoRefreshModel.RETRY_COOLDOWN)
        assertEquals(1, CourseAutoRefreshModel.MIN_INTERVAL_HOURS)
        assertEquals(168, CourseAutoRefreshModel.MAX_INTERVAL_HOURS)
        assertEquals(24, CourseAutoRefreshModel.DEFAULT_INTERVAL_HOURS)
        assertEquals(450, CourseAutoRefreshModel.DEFAULT_DAILY_MINUTE)
    }
}
