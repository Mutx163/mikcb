package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import java.io.IOException
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * [TimetableRepository] 的写入口 / 通知 / 落盘测试。
 *
 * 期望值**人推**：
 * - 节次钟点取自 [TimetableSettings.DEFAULT_SECTIONS] 的明文常量（第 1 节 08:00-08:45、
 *   第 2 节 08:55-09:40），不是从实现里读出来的；
 * - 课次日期：2026-09-07 是**周一**（2026-01-01 是周四，+249 天 ≡ +4 天 → 周一），
 *   周一起算 + (week-1)*7 + (dayOfWeek-1)；
 * - 通知次数按「一次成功变更 = 一次通知」数。
 */
class TimetableRepositoryTest {

    // ---------- add ----------

    @Test
    fun addCoursePersistsToDiskAndNotifiesOnce() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.addCourse(course("c1", name = "数学"))

        assertEquals(listOf("c1"), repository.snapshot.courses.map { it.id })
        assertEquals(1, seen.size)
        assertEquals(listOf("c1"), seen[0].courses.map { it.id })

        // 真落盘：v1 布局是 JSON 数组，且 schema 版本盖章、活动档案 id 也写了。
        val profilesJson = raw.getString("timetable_profiles")!!
        assertTrue(profilesJson.trimStart().startsWith("["))
        assertTrue(profilesJson.contains("\"c1\""))
        assertEquals(1, TimetableStore(raw).profilesSchemaVersion())
        assertEquals(TimetableRepository.DEFAULT_PROFILE_ID, raw.getString("active_timetable_profile_id"))
    }

    @Test
    fun addCourseFillsClockTimesFromEffectiveSectionsAndTrimsText() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        repository.addCourse(
            course("c1", name = "  数学  ").copy(
                teacher = "  张老师 ",
                location = " A101 ",
                startSection = 1,
                endSection = 2,
                startTime = "00:00",
                endTime = "00:00",
            ),
        )

        val saved = repository.snapshot.courses.single()
        assertEquals("数学", saved.name)
        assertEquals("张老师", saved.teacher)
        assertEquals("A101", saved.location)
        // 未绑方案时按 settings.sections（默认节次表）补齐钟点。
        assertEquals("08:00", saved.startTime)
        assertEquals("09:40", saved.endTime)
    }

    // ---------- update ----------

    @Test
    fun updateCoursePersistsAndNotifies() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        repository.addCourse(course("c1", name = "数学"))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.updateCourse(repository.snapshot.courses.single().copy(name = "高等数学"))

        assertEquals(listOf("高等数学"), repository.snapshot.courses.map { it.name })
        assertEquals(1, seen.size)
        assertEquals("高等数学", seen[0].courses.single().name)
        assertTrue(raw.getString("timetable_profiles")!!.contains("高等数学"))
    }

    // ---------- delete ----------

    @Test
    fun deleteCourseRemovesFromSnapshotAndDiskAndNotifies() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        repository.addCourse(course("c1", name = "数学"))
        repository.addCourse(course("c2", name = "物理"))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.deleteCourse("c1")

        assertEquals(listOf("c2"), repository.snapshot.courses.map { it.id })
        assertEquals(1, seen.size)
        assertFalse(raw.getString("timetable_profiles")!!.contains("\"c1\""))
    }

    // ---------- 档案切换 ----------

    @Test
    fun setActiveProfileSwitchesCoursesAndPersistsActiveId() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveProfiles(
            listOf(
                profile("p1", listOf(course("c1", name = "数学"))),
                profile("p2", listOf(course("c2", name = "物理"))),
            ),
        )
        store.saveActiveProfileId("p1")
        val repository = TimetableRepository(store)
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        assertEquals(listOf("c1"), repository.snapshot.courses.map { it.id })

        assertTrue(repository.setActiveProfile("p2"))

        assertEquals("p2", repository.snapshot.activeProfileId)
        assertEquals(listOf("c2"), repository.snapshot.courses.map { it.id })
        assertEquals(1, seen.size)
        assertEquals("p2", raw.getString("active_timetable_profile_id"))
    }

    @Test
    fun setActiveProfileRejectsUnknownIdAndDoesNotNotify() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveProfiles(listOf(profile("p1", listOf(course("c1")))))
        store.saveActiveProfileId("p1")
        val repository = TimetableRepository(store)
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        assertFalse(repository.setActiveProfile("nope"))
        assertFalse("切到当前档案不算变更", repository.setActiveProfile("p1"))
        assertTrue(seen.isEmpty())
    }

    @Test
    fun danglingActiveProfileIdFallsBackToFirstProfile() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveProfiles(listOf(profile("p1", listOf(course("c1")))))
        store.saveActiveProfileId("ghost")

        val repository = TimetableRepository(store)

        assertEquals("p1", repository.snapshot.activeProfileId)
    }

    // ---------- 写失败：不许通知 ----------

    @Test
    fun updateCourseOnWriteFailureRollsBackAndDoesNotNotify() {
        val failing = FailingWriteStore(
            mapOf("timetable_profiles" to "[${profile("p1", listOf(course("c1", name = "数学"))).toJsonString()}]"),
        )
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }
        assertEquals(listOf("数学"), repository.snapshot.courses.map { it.name })

        try {
            repository.updateCourse(repository.snapshot.courses.single().copy(name = "高数"))
            fail("落盘失败必须上抛")
        } catch (expected: IllegalStateException) {
            assertEquals("disk_full", expected.message)
        }

        // 服务回滚了内存快照；且**没有**通知（通知在落盘之后）。
        assertEquals(listOf("数学"), repository.snapshot.courses.map { it.name })
        assertTrue("落盘失败不许通知", seen.isEmpty())
    }

    // ---------- 设置 ----------

    @Test
    fun updateSettingsPersistsMergedAndNotifies() {
        val raw = InMemoryKeyValueStore(
            mapOf("timetable_settings" to """{"cornerRadius":22}"""),
        )
        val repository = TimetableRepository(TimetableStore(raw))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.updateSettings(TimetableSettings(semesterWeekCount = 16))

        assertEquals(16, repository.snapshot.settings.semesterWeekCount)
        assertEquals(16, repository.semesterWeekCount)
        assertEquals(1, seen.size)
        assertTrue("别人的字段要留着", raw.getString("timetable_settings")!!.contains("cornerRadius"))
    }

    // ---------- 教师/地点历史 ----------

    @Test
    fun recordTeacherAndLocationAreIdempotentAndSorted() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        repository.recordTeacher("王老师")
        repository.recordTeacher("张老师")
        repository.recordTeacher("张老师")
        repository.recordTeacher("   ")

        assertEquals(listOf("张老师", "王老师"), TimetableStore(raw).loadTeacherRecords())

        repository.recordLocation("A101")
        repository.recordLocation("A101")
        assertEquals(listOf("A101"), TimetableStore(raw).loadLocationRecords())
    }

    @Test
    fun addCourseAlsoRecordsTeacherAndLocation() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        repository.addCourse(course("c1", name = "数学"))

        val store = TimetableStore(raw)
        assertEquals(listOf("张老师"), store.loadTeacherRecords())
        assertEquals(listOf("A101"), store.loadLocationRecords())
    }

    // ---------- 端口读成员 ----------

    @Test
    fun getCourseByIdReadsActiveProfileOnly() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        repository.addCourse(course("c1", name = "数学"))

        assertEquals("数学", repository.getCourseById("c1")?.name)
        assertNull(repository.getCourseById("nope"))
    }

    @Test
    fun dateForCourseOccurrenceAnchorsToSemesterStartMonday() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        // 2026-09-07 是周一。
        repository.updateSettings(TimetableSettings(semesterStartDate = LocalDateTime.of(2026, 9, 7, 0, 0)))

        val wednesday = course("c1").copy(dayOfWeek = 3)
        val monday = course("c2").copy(dayOfWeek = 1)

        assertEquals(LocalDateTime.of(2026, 9, 9, 0, 0), repository.dateForCourseOccurrence(wednesday, 1))
        assertEquals(LocalDateTime.of(2026, 9, 14, 0, 0), repository.dateForCourseOccurrence(monday, 2))
        // 学期未配置时没有日期可算。
        val fresh = TimetableRepository(TimetableStore(InMemoryKeyValueStore()))
        assertNull(fresh.dateForCourseOccurrence(wednesday, 1))
    }

    @Test
    fun semesterStartEpochDayComesFromSettings() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        assertNull(repository.snapshot.semesterStartEpochDay)

        repository.updateSettings(TimetableSettings(semesterStartDate = LocalDateTime.of(2026, 9, 7, 0, 0)))

        // 2026-09-07 的天序（LocalDate.toEpochDay）。
        assertEquals(LocalDateTime.of(2026, 9, 7, 0, 0).toLocalDate().toEpochDay(), repository.snapshot.semesterStartEpochDay)
    }

    // ---------- 绑定了时间方案的课：节次越界写不进 ----------

    @Test
    fun addCourseBoundToSchemeMissingTheSectionIsRejected() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveTimeSchemes(
            listOf(
                TimeScheme(
                    id = "ts-1",
                    name = "两节作息",
                    sections = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")),
                    createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
                    updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
                ),
            ),
        )
        val repository = TimetableRepository(store)
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.addCourse(
                course("c1").copy(timeSchemeIdOverride = "ts-1", startSection = 1, endSection = 3),
            )
            fail("绑定方案只有 2 节，写第 3 节必须被拒")
        } catch (expected: IllegalArgumentException) {
            assertTrue("错误码要可本地化：${expected.message}", expected.message!!.contains("time_scheme_sections_insufficient"))
        }

        assertTrue(repository.snapshot.courses.isEmpty())
        assertTrue(seen.isEmpty())
        assertFalse(raw.contains("timetable_profiles"))
    }

    @Test
    fun addCourseBoundToSchemeThatExistsIsAccepted() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveTimeSchemes(
            listOf(
                TimeScheme(
                    id = "ts-1",
                    name = "三节作息",
                    sections = listOf(
                        SectionTime("08:00", "08:45"),
                        SectionTime("08:55", "09:40"),
                        SectionTime("10:00", "10:45"),
                    ),
                    createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
                    updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
                ),
            ),
        )
        val repository = TimetableRepository(store)

        repository.addCourse(course("c1").copy(timeSchemeIdOverride = "ts-1", startSection = 1, endSection = 3))

        val saved = repository.snapshot.courses.single()
        assertEquals("08:00", saved.startTime)
        assertEquals("10:45", saved.endTime)
    }

    // ---------- 当前周次 ----------

    @Test
    fun setCurrentWeekClampsNotifiesAndPersistsBothPlaces() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        repository.updateSettings(TimetableSettings(semesterWeekCount = 18))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.setCurrentWeek(7)

        assertEquals(7, repository.snapshot.currentWeek)
        assertEquals(1, seen.size)
        assertEquals(7, seen[0].currentWeek)
        assertEquals("7", raw.rawSnapshot()["flutter.current_week"])
        // 档案自带的 currentWeek 也要跟着走（Dart _persistActiveProfileState）。
        assertEquals(7L, repository.snapshot.profiles.single().currentWeek)

        // 越界按 Dart clampCurrentWeekToSettings：<1 归 1，> semesterWeekCount 归上限。
        repository.setCurrentWeek(0)
        assertEquals(1, repository.snapshot.currentWeek)
        repository.setCurrentWeek(99)
        assertEquals(18, repository.snapshot.currentWeek)
        assertEquals(3, seen.size)
    }

    @Test
    fun setCurrentWeekSurvivesReload() {
        val raw = InMemoryKeyValueStore()
        val first = TimetableRepository(TimetableStore(raw))
        first.updateSettings(TimetableSettings(semesterWeekCount = 20))
        first.addCourse(course("c1"))
        first.setCurrentWeek(9)

        // 「杀进程重开」：同一份盘、新的仓储实例。
        val reopened = TimetableRepository(TimetableStore(raw))

        assertEquals(9, reopened.snapshot.currentWeek)
        assertEquals(9L, reopened.snapshot.profiles.single().currentWeek)
    }

    @Test
    fun setCurrentWeekOnWriteFailureDoesNotNotify() {
        val failing = FailingWriteStore()
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.setCurrentWeek(4)
            fail("落盘失败必须上抛")
        } catch (expected: IllegalStateException) {
            assertEquals("disk_full", expected.message)
        }

        assertTrue("落盘失败不许通知", seen.isEmpty())
    }

    // ---------- 写失败（IOException 形态：与 PrefsKeyValueStore 的 commit() 失败同型） ----------
    //
    // 生产实现 `PrefsKeyValueStore` 在磁盘满时抛 IOException（2026-11-02 修复：
    // 以前 commit() 的布尔被丢掉，界面假成功、重启回退）。下面用**按 key 选择性失败**
    // 的替身证明：失败以 IOException 形态上抛时，「内存与监听者都不动」的契约同样成立，
    // 且多笔写的入口要能把已落盘的那几笔回滚掉。

    @Test
    fun restoreFromCloudSnapshotOnIoFailureLeavesMemoryAndListenersUntouched() {
        val delegate = InMemoryKeyValueStore()
        val seed = TimetableStore(delegate)
        seed.saveProfiles(listOf(profile("p1", listOf(course("c1", name = "数学")))))
        seed.saveActiveProfileId("p1")
        val failing = SelectiveFailStore(delegate, failKeys = setOf("timetable_profiles"))
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.restoreFromCloudSnapshot(
                profiles = listOf(profile("p9", listOf(course("c9", name = "云上的课")))),
                activeProfileId = "p9",
                timeSchemes = emptyList(),
                scheduleDateRules = emptyList(),
                locationTimeGroups = emptyList(),
            )
            fail("落盘失败必须上抛")
        } catch (expected: IOException) {
            assertEquals("disk_full", expected.message)
        }

        assertEquals(listOf("p1"), repository.snapshot.profiles.map { it.id })
        assertEquals(listOf("数学"), repository.snapshot.courses.map { it.name })
        assertTrue("落盘失败不许通知", seen.isEmpty())
        // 盘上也没有被写一半的恢复数据（第一笔就失败了）。
        assertTrue(delegate.getString("timetable_profiles")!!.contains("\"p1\""))
        assertFalse(delegate.getString("timetable_profiles")!!.contains("\"p9\""))
    }

    @Test
    fun updateScheduleDateRulesOnIoFailureLeavesMemoryAndDiskUntouched() {
        val delegate = InMemoryKeyValueStore()
        val seed = TimetableStore(delegate)
        val oldRule = ScheduleDateRule("r1", "秋假", "ts-1", "2026-10-01", "2026-10-07")
        seed.saveScheduleDateRules(listOf(oldRule))
        val failing = SelectiveFailStore(delegate, failKeys = setOf("schedule_date_rules"))
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.updateScheduleDateRules(
                listOf(oldRule, ScheduleDateRule("r2", "寒假", "ts-1", "2027-01-20", "2027-02-20")),
            )
            fail("落盘失败必须上抛")
        } catch (expected: IOException) {
            assertEquals("disk_full", expected.message)
        }

        assertEquals(listOf("r1"), repository.snapshot.scheduleDateRules.map { it.id })
        assertTrue("落盘失败不许通知", seen.isEmpty())
        assertEquals(1, TimetableStore(delegate).loadScheduleDateRules().size)
    }

    @Test
    fun updateTimeSchemeSecondWriteFailureWritesOldSchemeBackToDisk() {
        // 两笔写：第一笔（作息表）成功、第二笔（档案）失败 ⇒ update 里那个补偿分支
        // 必须把**旧作息表**写回盘上；否则冷启动后「被告知没改成」的新节次自己生效
        //（updateTimeScheme KDoc 里记的正是这个事故）。
        val delegate = InMemoryKeyValueStore()
        val seed = TimetableStore(delegate)
        seed.saveTimeSchemes(listOf(twoSectionScheme("ts-1")))
        seed.saveProfiles(listOf(profile("p1", listOf(course("c1")))))
        seed.saveActiveProfileId("p1")
        val failing = SelectiveFailStore(delegate, failKeys = setOf("timetable_profiles"))
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.updateTimeScheme(
                "ts-1",
                "三节作息",
                listOf(
                    SectionTime("08:00", "08:45"),
                    SectionTime("08:55", "09:40"),
                    SectionTime("10:00", "10:45"),
                ),
            )
            fail("第二笔落盘失败必须上抛")
        } catch (expected: IOException) {
            assertEquals("disk_full", expected.message)
        }

        // 内存维持旧模板。
        assertEquals(2, repository.snapshot.timeSchemes.single().sections.size)
        // 盘上：第一笔曾写成 3 节，补偿后必须回到 2 节。
        assertEquals(2, TimetableStore(delegate).loadTimeSchemes().schemes.single().sections.size)
        assertTrue("落盘失败不许通知", seen.isEmpty())
    }

    /** 两节作息模板（2026-09-01 起）。 */
    private fun twoSectionScheme(id: String) = TimeScheme(
        id = id,
        name = "两节作息",
        sections = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")),
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    // ---------- 订阅 ----------

    @Test
    fun observeDoesNotFireOnSubscribeAndStopsAfterClose() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        val seen = mutableListOf<TimetableSnapshot>()

        val subscription = repository.observe { seen.add(it) }
        assertTrue("订阅瞬间不许回调", seen.isEmpty())

        repository.addCourse(course("c1"))
        assertEquals(1, seen.size)

        subscription.close()
        repository.addCourse(course("c2"))
        assertEquals("退订后不再收到", 1, seen.size)
    }

    // ---------- 夹具 ----------

    private fun course(id: String, name: String = "数学") = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun profile(id: String, courses: List<Course> = emptyList()) = TimetableProfile(
        id = id,
        name = "课表-$id",
        courses = courses,
        currentWeek = 3L,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = LocalDateTime.of(2026, 9, 2, 8, 0),
    )

    // ---------- 备份恢复用的原子入口 ----------

    @Test
    fun replaceActiveProfileContentWritesAllThreeBlocksWithOneNotification() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))
        repository.addCourse(course("c1", name = "数学"))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.replaceActiveProfileContent(
            courses = listOf(course("c9", name = "恢复的课")),
            tasks = listOf(task("t1", courseId = "c9")),
            exams = listOf(exam("e1", courseId = "c9")),
        )

        val snapshot = repository.snapshot
        assertEquals(listOf("c9"), snapshot.courses.map { it.id })
        assertEquals(listOf("t1"), snapshot.profiles.single().tasks.map { it.id })
        assertEquals(listOf("e1"), snapshot.profiles.single().exams.map { it.id })
        // 一次原子替换 = 一次通知（逐个 setter 会是三次）。
        assertEquals(1, seen.size)
        assertEquals(listOf("c9"), seen[0].courses.map { it.id })
        // 三块内容都真落盘了。
        val written = raw.getString("timetable_profiles")!!
        assertTrue(written.contains("\"c9\""))
        assertTrue(written.contains("\"t1\""))
        assertTrue(written.contains("\"e1\""))
    }

    @Test
    fun replaceActiveProfileContentOnWriteFailureLeavesMemoryAndListenersUntouched() {
        val failing = FailingWriteStore(
            mapOf(
                "timetable_profiles" to
                    "[${profile("p1", listOf(course("c1", name = "数学"))).toJsonString()}]",
            ),
        )
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.replaceActiveProfileContent(listOf(course("c9")), emptyList(), emptyList())
            fail("落盘失败必须上抛")
        } catch (expected: IllegalStateException) {
            assertEquals("disk_full", expected.message)
        }

        // 先落盘后改内存 ⇒ 失败时内存原样。
        assertEquals(listOf("c1"), repository.snapshot.courses.map { it.id })
        assertTrue("落盘失败不许通知", seen.isEmpty())
    }

    @Test
    fun replaceAllProfilesPersistsEverythingAndKeepsDanglingIdAsDartDoes() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveProfiles(listOf(profile("p1", listOf(course("c1")))))
        store.saveActiveProfileId("p1")
        val repository = TimetableRepository(store)
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        repository.replaceAllProfiles(listOf(profile("p2", listOf(course("c2")))), "ghost")

        // 写侧：Dart 恢复流程不校验 activeProfileId，悬空值原样落盘。
        assertEquals("ghost", raw.getString("active_timetable_profile_id"))
        assertEquals(listOf("p2"), repository.snapshot.profiles.map { it.id })
        // 读侧：本层回落第一份（Dart 只对「情侣导入档」回落，其余悬空保留 → provider 侧 null；
        // 这里是有意放宽，见 replaceAllProfiles KDoc）。
        assertEquals("p2", repository.snapshot.activeProfileId)
        assertEquals(listOf("c2"), repository.snapshot.courses.map { it.id })
        assertEquals(1, seen.size)
        assertTrue(raw.getString("timetable_profiles")!!.contains("\"p2\""))

        // 「杀进程重开」：同一份盘、新实例，仍然读得出来（悬空 id 回落）。
        val reopened = TimetableRepository(TimetableStore(raw))
        assertEquals(listOf("p2"), reopened.snapshot.profiles.map { it.id })
        assertEquals("p2", reopened.snapshot.activeProfileId)
    }

    @Test
    fun replaceAllProfilesWithNullActiveIdClearsTheKey() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        store.saveProfiles(listOf(profile("p1")))
        store.saveActiveProfileId("p1")
        val repository = TimetableRepository(store)

        repository.replaceAllProfiles(listOf(profile("p1", listOf(course("c1")))), null)

        assertFalse("null 表示没有激活档案，键要被删掉", raw.contains("active_timetable_profile_id"))
        // 读侧仍然给得出一个激活档案（回落第一份），宿主不会拿到 null。
        assertEquals("p1", repository.snapshot.activeProfileId)
    }

    @Test
    fun replaceAllProfilesOnWriteFailureLeavesMemoryAndListenersUntouched() {
        val failing = FailingWriteStore(
            mapOf(
                "timetable_profiles" to "[${profile("p1", listOf(course("c1"))).toJsonString()}]",
            ),
        )
        val repository = TimetableRepository(TimetableStore(failing))
        val seen = mutableListOf<TimetableSnapshot>()
        repository.observe { seen.add(it) }

        try {
            repository.replaceAllProfiles(listOf(profile("pX")), "pX")
            fail("落盘失败必须上抛")
        } catch (expected: IllegalStateException) {
            assertEquals("disk_full", expected.message)
        }

        assertEquals(listOf("p1"), repository.snapshot.profiles.map { it.id })
        assertTrue("落盘失败不许通知", seen.isEmpty())
    }

    // ---------- 夹具 ----------

    private fun task(id: String, courseId: String? = null) = CourseTask(
        id = id,
        title = "作业-$id",
        courseId = courseId,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun exam(id: String, courseId: String) = Exam(
        id = id,
        courseId = courseId,
        name = "考试-$id",
        dateTime = LocalDateTime.of(2026, 10, 1, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    /** 读正常、**写一律抛**的存储：用来验证「落盘失败 → 回滚 → 不通知」。 */
    private class FailingWriteStore(initial: Map<String, String> = emptyMap()) : KeyValueStore {
        private val delegate = InMemoryKeyValueStore(initial)

        override fun getString(key: String): String? = delegate.getString(key)
        override fun getInt(key: String, default: Int): Int = delegate.getInt(key, default)
        override fun getLong(key: String, default: Long): Long = delegate.getLong(key, default)
        override fun getBool(key: String, default: Boolean): Boolean = delegate.getBool(key, default)
        override fun getStringList(key: String): List<String>? = delegate.getStringList(key)
        override fun putString(key: String, value: String) = failWrite()
        override fun putInt(key: String, value: Int) = failWrite()
        override fun putLong(key: String, value: Long) = failWrite()
        override fun putBool(key: String, value: Boolean) = failWrite()
        override fun putStringList(key: String, value: List<String>) = failWrite()
        override fun remove(key: String) = failWrite()
        override fun contains(key: String): Boolean = delegate.contains(key)
        override fun archiveCorruptAndRemove(key: String, micros: Long): String = failWrite()
        override fun keys(): Set<String> = delegate.keys()

        private fun failWrite(): Nothing = throw IllegalStateException("disk_full")
    }

    /**
     * 读与**未列出**的 key 写入正常透传；列出的 key 的写（含留档）抛 [IOException]。
     *
     * 与 [FailingWriteStore] 的区别：失败按 key 选择、且失败类型与生产实现
     * `PrefsKeyValueStore` 的 `commit()` 失败（IOException）同型——用来测多笔写入口的
     * 「第一笔成功、第二笔失败」的补偿路径。
     */
    private class SelectiveFailStore(
        private val delegate: InMemoryKeyValueStore,
        private val failKeys: Set<String>,
    ) : KeyValueStore {
        override fun getString(key: String): String? = delegate.getString(key)
        override fun getInt(key: String, default: Int): Int = delegate.getInt(key, default)
        override fun getLong(key: String, default: Long): Long = delegate.getLong(key, default)
        override fun getBool(key: String, default: Boolean): Boolean = delegate.getBool(key, default)
        override fun getStringList(key: String): List<String>? = delegate.getStringList(key)
        override fun putString(key: String, value: String) = failIfListed(key) { delegate.putString(key, value) }
        override fun putInt(key: String, value: Int) = failIfListed(key) { delegate.putInt(key, value) }
        override fun putLong(key: String, value: Long) = failIfListed(key) { delegate.putLong(key, value) }
        override fun putBool(key: String, value: Boolean) = failIfListed(key) { delegate.putBool(key, value) }
        override fun putStringList(key: String, value: List<String>) =
            failIfListed(key) { delegate.putStringList(key, value) }

        override fun remove(key: String) = failIfListed(key) { delegate.remove(key) }
        override fun contains(key: String): Boolean = delegate.contains(key)
        override fun archiveCorruptAndRemove(key: String, micros: Long): String =
            failIfListed(key) { delegate.archiveCorruptAndRemove(key, micros) }

        override fun keys(): Set<String> = delegate.keys()

        private inline fun <T> failIfListed(key: String, block: () -> T): T =
            if (key in failKeys) throw IOException("disk_full") else block()
    }
}
