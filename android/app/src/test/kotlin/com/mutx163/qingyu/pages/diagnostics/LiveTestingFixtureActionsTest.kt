package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.widgetdata.LiveTestingFixtureData
import com.mutx163.qingyu.widgetdata.SectionTimeData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 临时测试课表夹具的写盘逻辑测试（源：`lib/services/live_testing_fixture_service.dart`）。
 *
 * 期望值从 Dart 源手推：
 * - 夹具 id / 课名 / 教室 / 备注：`buildSlotTemplate`（:244-269）；
 * - 24 段整点：`buildHourlySections`（:116-126）；
 * - 只挪钟点：`buildTimedTestCourse`（:273-301，跨日抛错）；
 * - 清空：`removeAllFixtureCourses`（:398-410，只按 `live_test_` 前缀筛）。
 *
 * **本文件的核心是「清空夹具课不得误删用户真实课程」**：那条用例做过咬合探针
 * （把 `splitCourses` 的判据反过来 → 必须红，见 `_DIAG-settings-fixture-gaps.md`）。
 */
class LiveTestingFixtureActionsTest {

    /** 周四 10:30（2026-10-29）。 */
    private val now = LocalDateTime.of(2026, 10, 29, 10, 30)

    /**
     * 内存版宿主：把 Dart 的 `LiveFixtureProviderAccess` 换成两个可变列表。
     * `replaceCalls` 记录每次整份替换，用来验证「一次落盘」这件事。
     */
    private class FakeHost(
        private var storedCourses: List<Course>,
        private var storedSettings: TimetableSettings = TimetableSettings(
            sections = (1..12).map {
                SectionTime(startTime = "%02d:00".format(it), endTime = "%02d:45".format(it))
            },
            semesterWeekCount = 18,
        ),
    ) : LiveTestingFixtureHost {

        val replaceCalls = mutableListOf<List<Course>>()
        val addCalls = mutableListOf<Course>()
        val updateCalls = mutableListOf<Course>()
        var appliedSections: List<SectionTimeData>? = null

        override fun courses(): List<Course> = storedCourses

        override fun settings(): TimetableSettings = storedSettings

        override fun addCourse(course: Course) {
            addCalls += course
            storedCourses = storedCourses + course
        }

        override fun updateCourse(course: Course) {
            updateCalls += course
            storedCourses = storedCourses.map { if (it.id == course.id) course else it }
        }

        override fun replaceCourses(courses: List<Course>) {
            replaceCalls += courses
            storedCourses = courses
        }

        override fun applySections(sections: List<SectionTimeData>) {
            appliedSections = sections
            storedSettings = storedSettings.copy(
                sections = sections.map { SectionTime(it.startTime, it.endTime) },
            )
        }
    }

    private fun userCourse(id: String, name: String = "高等数学"): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 4,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        endWeek = 18,
    )

    private fun fixtureCourse(sectionNumber: Int): Course = Course(
        id = LiveTestingFixtureData.fixtureIdForSection(sectionNumber),
        name = "测试 第${sectionNumber}节",
        teacher = "测试教师",
        location = "测试教室",
        dayOfWeek = 4,
        startSection = sectionNumber,
        endSection = sectionNumber,
        startTime = "10:00",
        endTime = "11:00",
        note = "超级岛快捷测试课（可安全删除）",
    )

    // ---------- 清空：只删夹具课 ----------

    @Test
    fun clearDeletesOnlyFixtureCoursesAndKeepsUserCourses() {
        val user = listOf(userCourse("c1"), userCourse("c2", "线性代数"), userCourse("c3", "英语"))
        val fixtures = listOf(fixtureCourse(1), fixtureCourse(2), fixtureCourse(3))
        val host = FakeHost(user + fixtures)

        val removed = LiveFixtureActions.clear(host)

        assertEquals(3, removed)
        // 一次整份替换（不是三次 deleteCourse）。
        assertEquals(1, host.replaceCalls.size)
        // 剩下的必须**正好**是用户那三门，顺序也不能乱（周网格按列表重建）。
        assertEquals(user, host.courses())
        assertEquals(listOf("c1", "c2", "c3"), host.courses().map { it.id })
        // 用户课程字段一门都没被动过（名字/时间/周次）。
        assertEquals("线性代数", host.courses()[1].name)
        assertEquals("08:00", host.courses()[0].startTime)
        assertEquals(18, host.courses()[0].endWeek)
    }

    @Test
    fun clearKeepsNonPrefixLookalikes() {
        // 名字像测试课、但 id 不带 `live_test_` 前缀 = 用户自己建的课，不能删。
        val lookalike = userCourse("c9", "测试 第1节").copy(note = "超级岛快捷测试课（可安全删除）")
        val host = FakeHost(listOf(lookalike, fixtureCourse(1)))

        val removed = LiveFixtureActions.clear(host)

        assertEquals(1, removed)
        assertEquals(listOf(lookalike), host.courses())
    }

    @Test
    fun clearOnCleanTimetableDoesNotWriteAnything() {
        val user = listOf(userCourse("c1"))
        val host = FakeHost(user)

        val removed = LiveFixtureActions.clear(host)

        assertEquals(0, removed)
        // 没夹具课就不该碰盘（Dart 里同样是空循环）。
        assertTrue(host.replaceCalls.isEmpty())
        assertEquals(user, host.courses())
    }

    @Test
    fun clearRemovesPresetCoursesToo() {
        // 预设课 id 是 `live_test_preset_a/b`，同样属于夹具家族（isFixtureCourse 前缀匹配）。
        val preset = fixtureCourse(1).copy(id = LiveTestingFixtureData.PRESET_COURSE_ID_A)
        val host = FakeHost(listOf(userCourse("c1"), preset))

        val removed = LiveFixtureActions.clear(host)

        assertEquals(1, removed)
        assertEquals(listOf("c1"), host.courses().map { it.id })
    }

    // ---------- 安装 ----------

    @Test
    fun installGridAdds24FixtureCoursesAndKeepsUserCourses() {
        val user = listOf(userCourse("c1"))
        val host = FakeHost(user)

        val added = LiveFixtureActions.installGrid(host, now, semesterWeekCount = 18)

        assertEquals(24, added)
        // 用户那门课仍在第一位（Dart `replaceExisting: false`）。
        assertEquals(user.first(), host.courses().first())
        assertEquals(25, host.courses().size)
        // id 必须是 live_test_01 … live_test_24。
        assertEquals(
            (1..24).map { LiveTestingFixtureData.fixtureIdForSection(it) },
            host.courses().filter { LiveTestingFixtureData.isFixtureCourse(it) }.map { it.id },
        )
        // 第 1 节 = 00:00-01:00，第 24 节 = 23:00-23:59（buildHourlySections）。
        val first = host.courses().first { it.id == "live_test_01" }
        assertEquals("00:00", first.startTime)
        assertEquals("01:00", first.endTime)
        val last = host.courses().last()
        assertEquals("23:00", last.startTime)
        assertEquals("23:59", last.endTime)
        // 课名 / 教室 / 备注照 Dart buildSlotTemplate。
        assertEquals("测试 第1节", first.name)
        assertEquals("测01", first.shortName)
        assertEquals("测试教师", first.teacher)
        assertEquals("测试教室 01", first.location)
        assertEquals("超级岛快捷测试课（可安全删除）", first.note)
        // 周次跨度取学期的（endWeek = semesterWeekCount）。
        assertEquals(18, first.endWeek)
        // 排 today 的星期几（2026-10-29 是周四）。
        assertEquals(4, first.dayOfWeek)
        // 节次下标与 24 段对齐。
        assertEquals(1, first.startSection)
        assertEquals(24, last.startSection)
    }

    @Test
    fun installGridAppliesHourlySectionsSoRailMatchesCourses() {
        val host = FakeHost(emptyList())

        LiveFixtureActions.installGrid(host, now, semesterWeekCount = 18)

        val applied = host.appliedSections
        assertNotNull(applied)
        assertEquals(24, applied!!.size)
        assertEquals(LiveTestingFixtureData.buildHourlySections(), applied)
    }

    @Test
    fun installGridIsIdempotent() {
        // 连装两次不能变成 48 门（Dart 开头先 removeAllFixtureCourses）。
        val host = FakeHost(listOf(userCourse("c1")))

        LiveFixtureActions.installGrid(host, now, 18)
        val second = LiveFixtureActions.installGrid(host, now, 18)

        assertEquals(24, second)
        assertEquals(25, host.courses().size)
        assertEquals(
            24,
            host.courses().count { LiveTestingFixtureData.isFixtureCourse(it) },
        )
    }

    // ---------- 触发（只挪钟点）----------

    @Test
    fun upsertTimedAddsFixtureWhenSectionHasNone() {
        val host = FakeHost(listOf(userCourse("c1")))

        val course = LiveFixtureActions.upsertTimed(host, sectionNumber = 3, now = now, leadMinutes = 5)

        assertEquals(1, host.addCalls.size)
        assertTrue(host.updateCalls.isEmpty())
        assertEquals("live_test_03", course.id)
        // 10:30 + 5 分钟 = 10:35，时长 3 分钟（defaultCourseDuration）。
        assertEquals("10:35", course.startTime)
        assertEquals("10:38", course.endTime)
        // 「只挪钟点」：节次下标仍是模板的 3。
        assertEquals(3, course.startSection)
        assertEquals(3, course.endSection)
        assertEquals(4, course.dayOfWeek)
        // 用户课程不受影响。
        assertEquals(listOf("c1", "live_test_03"), host.courses().map { it.id })
    }

    @Test
    fun upsertTimedUpdatesExistingFixtureInPlace() {
        val host = FakeHost(listOf(fixtureCourse(2)))

        val course = LiveFixtureActions.upsertTimed(host, sectionNumber = 2, now = now, leadMinutes = 8)

        assertEquals(1, host.updateCalls.size)
        assertTrue(host.addCalls.isEmpty())
        assertEquals("10:38", course.startTime)
        assertEquals("10:41", course.endTime)
        assertEquals(1, host.courses().size)
        // 备注沿用模板（Dart `note ?? template.note`）：模板有备注就保留。
        assertEquals("超级岛快捷测试课（可安全删除）", course.note)
    }

    @Test
    fun upsertTimedKeepsTemplateWithoutNoteAsNull() {
        // 模板本来没有备注时不许凭空造一条（Dart `note ?? template.note` 在两者都为 null 时仍为 null）。
        val host = FakeHost(listOf(fixtureCourse(2).copy(note = null)))

        val course = LiveFixtureActions.upsertTimed(host, sectionNumber = 2, now = now, leadMinutes = 1)

        assertEquals(null, course.note)
        // 显式传 note 时才覆盖。
        val withNote = LiveFixtureActions.upsertTimed(
            host,
            sectionNumber = 2,
            now = now,
            leadMinutes = 1,
            note = "自定义备注",
        )
        assertEquals("自定义备注", withNote.note)
    }

    @Test
    fun upsertTimedClampsSectionIntoRange() {
        // 12 节节次表里要第 99 节 → 落到最后一节（Dart `clamp(1, sections.length)`）。
        val host = FakeHost(emptyList())

        val course = LiveFixtureActions.upsertTimed(host, sectionNumber = 99, now = now, leadMinutes = 1)

        assertEquals("live_test_12", course.id)
        assertEquals(12, course.startSection)
    }

    @Test(expected = IllegalStateException::class)
    fun upsertTimedRejectsCrossDayClock() {
        // 23:58 + 1 分钟 + 3 分钟 ⇒ 跨日，课表不支持隔夜课，必须抛而不是写一门坏课。
        LiveFixtureActions.upsertTimed(
            host = FakeHost(emptyList()),
            sectionNumber = 1,
            now = LocalDateTime.of(2026, 10, 29, 23, 58),
            leadMinutes = 1,
        )
    }

    @Test(expected = IllegalStateException::class)
    fun upsertTimedRejectsTimetableWithoutSections() {
        val host = FakeHost(emptyList(), TimetableSettings(sections = emptyList()))

        LiveFixtureActions.upsertTimed(host, sectionNumber = 1, now = now, leadMinutes = 1)
    }

    // ---------- 分组 ----------

    @Test
    fun splitCoursesSeparatesFixturesWithoutReordering() {
        val user = listOf(userCourse("c1"), userCourse("c2"))
        val fixtures = listOf(fixtureCourse(1))

        val (f, u) = LiveFixtureActions.splitCourses(listOf(user[0], fixtures[0], user[1]))

        assertEquals(fixtures, f)
        assertEquals(user, u)
        // 空表也不许返回 null 语义（Kotlin 侧全是不可变 List）。
        assertEquals(true, LiveFixtureActions.splitCourses(emptyList()).second.isEmpty())
    }

    @Test
    fun sectionTimeDataConversionKeepsBothClocks() {
        val data = LiveFixtureActions.toSectionTimeData(SectionTime("08:00", "09:40"))
        assertEquals("08:00", data.startTime)
        assertEquals("09:40", data.endTime)
    }

    // ---------- 消息文案 ----------

    @Test
    fun toastMessagesMatchDartLiterals() {
        assertEquals("已套用 超级岛测试24时段 并添加 24 门测试课，星期4", LiveFixtureMessages.installed("超级岛测试24时段", 24, 4))
        assertEquals("已清除 3 门测试课", LiveFixtureMessages.cleared(3))
        assertEquals("清除测试课表失败：boom", LiveFixtureMessages.clearFailed("boom"))
        assertEquals("安装测试课表失败：bad", LiveFixtureMessages.installFailed("bad"))
        // 触发管线已迁移（2026-11-03）：那句要**说清**课已改好、岛将按课前提醒设置弹出；
        // 占位话「管线尚未迁移」不得回来——回来就说明有人把功能改回了空壳。
        val triggered = LiveFixtureMessages.triggered(3, 5)
        assertTrue(triggered.contains("第3节"))
        assertTrue(triggered.contains("5 分钟"))
        assertTrue(triggered.contains("弹出"))
        assertFalse(triggered.contains("尚未迁移"))
        assertFalse(triggered.contains("null"))
    }
}
