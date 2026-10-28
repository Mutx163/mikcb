package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课表档案管理「仓储接线控制器」单测。
 *
 * 全部用例都用**真** [TimetableRepository] + [InMemoryKeyValueStore]（同一套前缀/编码规则），
 * 期望值是人推的（不是从实现抄的）：新档名、激活指针、课程数、落盘内容、作业/考试的保留与否。
 */
class TimetableProfilesControllerTest {

    // ============ 新建 ============

    @Test
    fun `新建课表落盘、成为激活档、课程为空`() {
        val f = fixture(
            profiles = listOf(profile("p1", "旧课表", courses = listOf(course("c1")))),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        val result = controller.createProfile("  大二上  ")

        assertTrue(result is TimetableProfileActionResult.Success)
        assertEquals(listOf("p1", "p2"), f.repo.snapshot.profiles.map { it.id })
        val created = f.repo.snapshot.profiles.first { it.id == "p2" }
        assertEquals("名称应 trim", "大二上", created.name)
        assertTrue("新档课程必须为空", created.courses.isEmpty())
        // 新建后立即成为激活档（Dart createProfile: 新档即当前课表）。
        assertEquals("p2", f.repo.snapshot.activeProfileId)
        assertTrue("新档为空，首页读到的课程应为空", f.repo.snapshot.courses.isEmpty())
        // 真落盘：活动档案 id 已写、新档名进了 profiles。
        assertEquals("p2", f.store.loadActiveProfileId())
        assertTrue(f.raw.getString("timetable_profiles")!!.contains("大二上"))
        // 杀进程重开（同一份盘、新实例）仍读得出新档且是激活档。
        val reopened = TimetableRepository(TimetableStore(f.raw))
        assertEquals(listOf("p1", "p2"), reopened.snapshot.profiles.map { it.id })
        assertEquals("p2", reopened.snapshot.activeProfileId)
    }

    @Test
    fun `新建空白名称回落未命名课表`() {
        val f = fixture(profiles = listOf(profile("p1")), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.createProfile("   ")

        val created = f.repo.snapshot.profiles.first { it.id == "p2" }
        assertEquals(TimetableStrings.unnamedTimetableProfile.zh, created.name)
    }

    @Test
    fun `新建沿用当前生效作息模板的节次`() {
        val scheme = TimeScheme(
            id = "ts1",
            name = "两节作息",
            sections = listOf(SectionTime("09:00", "09:45"), SectionTime("09:55", "10:40")),
            createdAt = t0,
            updatedAt = t0,
        )
        val f = fixture(
            profiles = listOf(profile("p1")),
            activeId = "p1",
            schemes = listOf(scheme),
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.createProfile("新课表")

        val created = f.repo.snapshot.profiles.first { it.id == "p2" }
        assertEquals("ts1", created.settings.activeTimeSchemeId)
        assertEquals(
            listOf(SectionTime("09:00", "09:45"), SectionTime("09:55", "10:40")),
            created.settings.sections,
        )
    }

    // ============ 切换（含「首页数据跟着变」契约） ============

    @Test
    fun `切换档案后首页数据（snapshot courses）跟着变并落盘激活 id`() {
        val f = fixture(
            profiles = listOf(
                profile("p1", "课表1", courses = listOf(course("c1", "数学"))),
                profile("p2", "课表2", courses = listOf(course("c2", "物理"))),
            ),
            activeId = "p1",
        )
        // 首帧：首页读到的是 p1 的课。
        assertEquals(listOf("c1"), f.repo.snapshot.courses.map { it.id })
        val notifications = mutableListOf<com.mutx163.qingyu.app.TimetableSnapshot>()
        f.repo.observe { notifications.add(it) }

        val controller = TimetableProfilesController(f.repo)
        val result = controller.switchProfile("p2")

        assertTrue(result is TimetableProfileActionResult.Success)
        assertEquals("p2", f.repo.snapshot.activeProfileId)
        // 这是「切档案 → 首页数据跟着变」的契约点：首页读的就是 snapshot.courses。
        assertEquals(listOf("c2"), f.repo.snapshot.courses.map { it.id })
        assertEquals("p2", f.store.loadActiveProfileId())
        // 一次切换 = 一次通知，且通知里的数据已是新档的课。
        assertEquals(1, notifications.size)
        assertEquals(listOf("c2"), notifications.single().courses.map { it.id })
    }

    @Test
    fun `切换到情侣导入课表被拒且不改任何东西`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED, courses = listOf(course("cx")))
        val f = fixture(
            profiles = listOf(profile("p1", "课表1", courses = listOf(course("c1"))), partner),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo)

        val result = controller.switchProfile("p_partner")

        assertTrue(result is TimetableProfileActionResult.Rejected)
        assertEquals("p1", f.repo.snapshot.activeProfileId)
        assertEquals(listOf("c1"), f.repo.snapshot.courses.map { it.id })
    }

    @Test
    fun `切换到已是当前档或不存在时为空操作`() {
        val f = fixture(profiles = listOf(profile("p1"), profile("p2")), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        assertTrue(controller.switchProfile("p1") is TimetableProfileActionResult.Rejected)
        assertTrue(controller.switchProfile("ghost") is TimetableProfileActionResult.Rejected)
        assertEquals("p1", f.repo.snapshot.activeProfileId)
    }

    // ============ 重命名 ============

    @Test
    fun `重命名落盘并通知，空白名与原值相同则不动`() {
        val f = fixture(profiles = listOf(profile("p1", "旧名字")), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        val ok = controller.renameProfile("p1", "  新名字  ")
        assertTrue(ok is TimetableProfileActionResult.Success)
        assertEquals("新名字", f.repo.snapshot.profiles.single().name)
        assertTrue(f.raw.getString("timetable_profiles")!!.contains("新名字"))

        // 空白名不改
        assertTrue(controller.renameProfile("p1", "   ") is TimetableProfileActionResult.Rejected)
        assertEquals("新名字", f.repo.snapshot.profiles.single().name)
        // 与原值相同不改（且不算一次变更）
        assertTrue(controller.renameProfile("p1", "新名字") is TimetableProfileActionResult.Rejected)
        assertEquals("新名字", f.repo.snapshot.profiles.single().name)
    }

    @Test
    fun `重命名情侣导入课表被拒`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val f = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        assertTrue(controller.renameProfile("p_partner", "新名字") is TimetableProfileActionResult.Rejected)
        assertEquals("TA的课表", f.repo.snapshot.profiles.first { it.id == "p_partner" }.name)
    }

    // ============ 复制 ============

    @Test
    fun `复制档案保留课程并成为激活档，名字加副本后缀`() {
        val f = fixture(
            profiles = listOf(profile("p1", "原课表", courses = listOf(course("c1"), course("c2")))),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p_copy" }, clock = { t0 })

        val result = controller.duplicateProfile("p1")

        assertTrue(result is TimetableProfileActionResult.Success)
        assertEquals(listOf("p1", "p_copy"), f.repo.snapshot.profiles.map { it.id })
        val copy = f.repo.snapshot.profiles.first { it.id == "p_copy" }
        assertEquals("原课表 副本", copy.name)
        assertEquals(listOf("c1", "c2"), copy.courses.map { it.id })
        // Dart duplicateActiveProfile：复制品成为激活档。
        assertEquals("p_copy", f.repo.snapshot.activeProfileId)
        assertEquals(listOf("c1", "c2"), f.repo.snapshot.courses.map { it.id })
    }

    @Test
    fun `复制情侣导入课表被拒`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val f = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, idFactory = { "x" }, clock = { t0 })

        assertTrue(controller.duplicateProfile("p_partner") is TimetableProfileActionResult.Rejected)
        assertEquals(2, f.repo.snapshot.profiles.size)
    }

    // ============ 删除 ============

    @Test
    fun `删除当前激活档自动激活剩余档并落盘`() {
        val f = fixture(
            profiles = listOf(
                profile("p1", "课表1", courses = listOf(course("c1", "数学"))),
                profile("p2", "课表2", courses = listOf(course("c2", "物理"))),
            ),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo)

        val result = controller.deleteProfile("p1")

        assertTrue(result is TimetableProfileActionResult.Success)
        assertEquals(listOf("p2"), f.repo.snapshot.profiles.map { it.id })
        assertEquals("p2", f.repo.snapshot.activeProfileId)
        assertEquals("删激活档后首页应切到剩余档的课", listOf("c2"), f.repo.snapshot.courses.map { it.id })
        // 落盘：profiles 与激活 id 都写了。
        assertEquals(listOf("p2"), f.store.loadProfiles().profiles.map { it.id })
        assertEquals("p2", f.store.loadActiveProfileId())
    }

    @Test
    fun `删除非激活档保持激活指针不变`() {
        val f = fixture(
            profiles = listOf(profile("p1", courses = listOf(course("c1"))), profile("p2", courses = listOf(course("c2")))),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo)

        controller.deleteProfile("p2")

        assertEquals(listOf("p1"), f.repo.snapshot.profiles.map { it.id })
        assertEquals("p1", f.repo.snapshot.activeProfileId)
    }

    @Test
    fun `唯一档案拒绝删除并返回至少保留一个课表`() {
        val f = fixture(profiles = listOf(profile("p1")), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        val result = controller.deleteProfile("p1")

        assertTrue(result is TimetableProfileActionResult.Rejected)
        assertEquals(TimetableStrings.keepAtLeastOneProfile.zh, (result as TimetableProfileActionResult.Rejected).message)
        assertEquals(1, f.repo.snapshot.profiles.size)
    }

    @Test
    fun `情侣导入档拒绝删除`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val f = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        assertTrue(controller.deleteProfile("p_partner") is TimetableProfileActionResult.Rejected)
        assertEquals(2, f.repo.snapshot.profiles.size)
    }

    @Test
    fun `删除激活档但剩余全是情侣导入档时拒绝（无可工作回退档）`() {
        val f = fixture(
            profiles = listOf(
                profile("p1", "我的课表"),
                profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED),
            ),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo)

        val result = controller.deleteProfile("p1")

        assertTrue(result is TimetableProfileActionResult.Rejected)
        assertEquals(2, f.repo.snapshot.profiles.size)
    }

    // ============ 清空当前课表 ============

    @Test
    fun `清空当前课表删课与挂课作业、保留手写作业与考试`() {
        val f = fixture(
            profiles = listOf(
                profile(
                    "p1",
                    "课表1",
                    courses = listOf(course("c1", "数学")),
                    tasks = listOf(task("t1", courseId = "c1"), task("t2", courseId = null)),
                    exams = listOf(exam("e1", courseId = "c1")),
                ),
            ),
            activeId = "p1",
        )
        val controller = TimetableProfilesController(f.repo)

        val result = controller.clearCourses("p1")

        assertTrue(result is TimetableProfileActionResult.Success)
        val profile = f.repo.snapshot.profiles.single()
        assertTrue("课必须清空", profile.courses.isEmpty())
        assertEquals("挂课作业删、手写作业留", listOf("t2"), profile.tasks.map { it.id })
        assertEquals("考试刻意保留", listOf("e1"), profile.exams.map { it.id })
        assertTrue(f.repo.snapshot.courses.isEmpty())
    }

    @Test
    fun `清空无课程的课表返回无课程提示且不改动`() {
        val f = fixture(profiles = listOf(profile("p1", courses = emptyList())), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        val result = controller.clearCourses("p1")

        assertTrue(result is TimetableProfileActionResult.Rejected)
        assertEquals(TimetableStrings.noCoursesInCurrentProfile.zh, (result as TimetableProfileActionResult.Rejected).message)
    }

    // ============ WYSIWYG：条目映射 ============

    @Test
    fun `items 映射课程数、当前周、时间模板与激活态`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val mine = profile("p1", "我的课表", courses = listOf(course("c1"), course("c2")), currentWeek = 5L)
            .copy(settings = profile("p1").settings.copy(activeTimeSchemeId = "ts1"))
        val f = fixture(profiles = listOf(mine, partner), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        val items = controller.items()

        assertEquals(listOf("p1", "p_partner"), items.map { it.id })
        val mineItem = items.first { it.id == "p1" }
        assertEquals(2, mineItem.courseCount)
        assertEquals(5L, mineItem.currentWeek)
        assertEquals("ts1", mineItem.timeSchemeId)
        assertTrue(mineItem.isActive)
        assertFalse(mineItem.isPartnerImported)
        val partnerItem = items.first { it.id == "p_partner" }
        assertTrue(partnerItem.isPartnerImported)
        assertFalse(partnerItem.isActive)
    }

    // ============ 落盘失败：返回 Failed 且仓储不变 ============

    @Test
    fun `新建落盘失败返回 Failed 且不多出档案`() {
        val failing = FailingWriteStore(
            mapOf("timetable_profiles" to "[${profile("p1").toJsonString()}]", "active_timetable_profile_id" to "p1"),
        )
        val store = TimetableStore(failing)
        val repo = TimetableRepository(store)
        val controller = TimetableProfilesController(repo, idFactory = { "p2" }, clock = { t0 })

        val result = controller.createProfile("新课表")

        assertTrue(result is TimetableProfileActionResult.Failed)
        assertEquals(TimetableStrings.saveFailed.zh, (result as TimetableProfileActionResult.Failed).message)
        assertEquals("落盘失败必须回滚，不多出档案", listOf("p1"), repo.snapshot.profiles.map { it.id })
        assertNotEquals("p2", repo.snapshot.activeProfileId)
    }

    // ============ 夹具 ============

    private val t0: LocalDateTime = LocalDateTime.of(2026, 9, 1, 8, 0)

    private class Fixture(
        val raw: InMemoryKeyValueStore,
        val store: TimetableStore,
        val repo: TimetableRepository,
    )

    private fun fixture(
        profiles: List<TimetableProfile>,
        activeId: String? = profiles.firstOrNull()?.id,
        schemes: List<TimeScheme> = emptyList(),
    ): Fixture {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        if (profiles.isNotEmpty()) store.saveProfiles(profiles)
        store.saveActiveProfileId(activeId)
        if (schemes.isNotEmpty()) store.saveTimeSchemes(schemes)
        return Fixture(raw, store, TimetableRepository(store))
    }

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

    private fun profile(
        id: String,
        name: String = "课表-$id",
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        kind: TimetableProfileKind = TimetableProfileKind.NORMAL,
        currentWeek: Long = 3L,
    ) = TimetableProfile(
        id = id,
        name = name,
        courses = courses,
        tasks = tasks,
        exams = exams,
        currentWeek = currentWeek,
        createdAt = t0,
        lastUsedAt = t0,
        profileKind = kind,
    )

    private fun task(id: String, courseId: String?) = CourseTask(
        id = id,
        title = "作业-$id",
        courseId = courseId,
        createdAt = t0,
        updatedAt = t0,
    )

    private fun exam(id: String, courseId: String) = Exam(
        id = id,
        courseId = courseId,
        name = "考试-$id",
        dateTime = LocalDateTime.of(2026, 10, 1, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = t0,
        updatedAt = t0,
    )

    /** 读正常、**写一律抛**的存储：验证控制器的 Failed 路径（落盘失败 → 仓储回滚 → 返回 Failed）。 */
    private class FailingWriteStore(initial: Map<String, String> = emptyMap()) : KeyValueStore {
        private val delegate = InMemoryKeyValueStore(initial)

        override fun getString(key: String): String? = delegate.getString(key)
        override fun getInt(key: String, default: Int): Int = delegate.getInt(key, default)
        override fun getBool(key: String, default: Boolean): Boolean = delegate.getBool(key, default)
        override fun getStringList(key: String): List<String>? = delegate.getStringList(key)
        override fun putString(key: String, value: String) = failWrite()
        override fun putInt(key: String, value: Int) = failWrite()
        override fun putBool(key: String, value: Boolean) = failWrite()
        override fun putStringList(key: String, value: List<String>) = failWrite()
        override fun remove(key: String) = failWrite()
        override fun contains(key: String): Boolean = delegate.contains(key)
        override fun archiveCorruptAndRemove(key: String, micros: Long): String = failWrite()
        override fun keys(): Set<String> = delegate.keys()

        private fun failWrite(): Nothing = throw IllegalStateException("disk_full")
    }
}
