package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import com.mutx163.qingyu.core.TimetableSettings
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

    // ============ 新建档的作息模板兜底（Dart `_buildDefaultSettingsForNewProfile` :1787-1798） ============

    @Test
    fun `新建档时生效作息 id 有效 就用那一份 而不是第一份`() {
        val first = scheme("ts1", "08:00")
        val second = scheme("ts2", "09:00")
        val f = fixture(
            profiles = listOf(profile("p1")),
            activeId = "p1",
            schemes = listOf(first, second),
            settings = TimetableSettings.defaults().copy(activeTimeSchemeId = "ts2"),
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.createProfile("新课表")

        val created = f.repo.snapshot.profiles.first { it.id == "p2" }
        assertEquals("有效 id 必须用它，不能被 first 覆盖", "ts2", created.settings.activeTimeSchemeId)
        assertEquals(second.sections, created.settings.sections)
    }

    @Test
    fun `新建档时生效作息 id 失效 回落第一份方案`() {
        // Dart `activeTimeScheme`（timetable_provider.dart:612-613）按 id 查，查不到为 null；
        // `_buildDefaultSettingsForNewProfile` 再显式回落 `_timeSchemes.first`（:1787-1798）。
        val first = scheme("ts1", "08:00")
        val second = scheme("ts2", "09:00")
        val f = fixture(
            profiles = listOf(profile("p1")),
            activeId = "p1",
            schemes = listOf(first, second),
            settings = TimetableSettings.defaults().copy(activeTimeSchemeId = "gone"),
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.createProfile("新课表")

        val created = f.repo.snapshot.profiles.first { it.id == "p2" }
        assertEquals("ts1", created.settings.activeTimeSchemeId)
        assertEquals(first.sections, created.settings.sections)
    }

    @Test
    fun `没有任何作息方案时新建档用默认设置`() {
        val f = fixture(profiles = listOf(profile("p1")), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.createProfile("新课表")

        val base = TimetableSettings.defaults()
        val created = f.repo.snapshot.profiles.first { it.id == "p2" }
        assertEquals(base.activeTimeSchemeId, created.settings.activeTimeSchemeId)
        assertEquals(base.sections, created.settings.sections)
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
    fun `有绑定的情侣导入档仍拒绝删除`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val f = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1", partnerBinding = true)
        val controller = TimetableProfilesController(f.repo)

        assertTrue(controller.deleteProfile("p_partner") is TimetableProfileActionResult.Rejected)
        assertEquals(2, f.repo.snapshot.profiles.size)
    }

    /**
     * S1 自愈：恢复备份后留下的「有档案、没绑定」孤儿档必须能删。
     *
     * 判据是**盘上的绑定键**，不是内存里有没有绑定：删除入口与情侣页各走各的，
     * 不能互相顶牛。
     */
    @Test
    fun `无绑定的孤儿情侣档允许删除`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val f = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        val result = controller.deleteProfile("p_partner")

        assertTrue("孤儿档应可删：$result", result is TimetableProfileActionResult.Success)
        assertEquals(listOf("p1"), f.repo.snapshot.profiles.map { it.id })
        assertEquals("p1", f.repo.snapshot.activeProfileId)
        assertEquals("p1", f.store.loadActiveProfileId())
        assertTrue(
            "要真落盘：盘上档案列表里不该再出现 TA 的课表",
            !f.raw.getString(TimetableStore.KEY_PROFILES)!!.contains("TA的课表"),
        )
    }

    @Test
    fun `列表隐藏孤儿情侣档 有绑定时照常显示`() {
        val partner = profile("p_partner", "TA的课表", kind = TimetableProfileKind.PARTNER_IMPORTED)
        val orphan = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1")
        assertEquals(
            "没有绑定 ⇒ 孤儿档不给用户看（它既显示不出内容也切不走）",
            listOf("p1"),
            TimetableProfilesController(orphan.repo).items().map { it.id },
        )

        val bound = fixture(profiles = listOf(profile("p1"), partner), activeId = "p1", partnerBinding = true)
        assertEquals(
            "还绑定着 ⇒ 情侣课表必须留在列表里（带只读徽标）",
            listOf("p1", "p_partner"),
            TimetableProfilesController(bound.repo).items().map { it.id },
        )
        assertTrue(TimetableProfilesController(bound.repo).items().last().isPartnerImported)
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
        // partnerBinding = true：对方档还在绑定期（未绑定的孤儿档会被列表隐藏，见下方专门用例）。
        val f = fixture(profiles = listOf(mine, partner), activeId = "p1", partnerBinding = true)
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

    // ============ 换档必须换全局设置（Dart `_applyProfileState`） ============

    @Test
    fun `切换档案时全局设置跟着目标档走 而不是留在旧档`() {
        val oldStart = LocalDateTime.of(2026, 2, 23, 0, 0)
        val newStart = LocalDateTime.of(2026, 8, 31, 0, 0)
        val oldProfile = profile("p1", "旧课表")
            .copy(settings = profile("p1").settings.copy(semesterStartDate = oldStart, semesterWeekCount = 18))
        val newProfile = profile("p2", "新课表")
            .copy(settings = profile("p2").settings.copy(semesterStartDate = newStart, semesterWeekCount = 16))
        val f = fixture(profiles = listOf(oldProfile, newProfile), activeId = "p1")
        val controller = TimetableProfilesController(f.repo)

        val result = controller.switchProfile("p2")

        assertTrue(result is TimetableProfileActionResult.Success)
        assertEquals("开学日必须换成目标档的", newStart, f.repo.snapshot.settings.semesterStartDate)
        assertEquals("总周数必须换成目标档的", 16, f.repo.snapshot.settings.semesterWeekCount)
        // 落盘同样要换：杀进程重开不能又回到旧档的学期。
        val reopened = TimetableRepository(TimetableStore(f.raw))
        assertEquals(newStart, reopened.snapshot.settings.semesterStartDate)
        assertEquals(16, reopened.snapshot.settings.semesterWeekCount)
    }

    @Test
    fun `新建课表后全局设置用新档默认值 而不是沿用旧档开学日`() {
        val oldStart = LocalDateTime.of(2026, 2, 23, 0, 0)
        val oldProfile = profile("p1").copy(settings = profile("p1").settings.copy(semesterStartDate = oldStart))
        val f = fixture(profiles = listOf(oldProfile), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.createProfile("新课表")

        assertNull("新档默认不带开学日，全局设置也不能还留着旧档的", f.repo.snapshot.settings.semesterStartDate)
    }

    @Test
    fun `复制课表后全局设置沿用来源档`() {
        val sourceStart = LocalDateTime.of(2026, 8, 31, 0, 0)
        val source = profile("p1").copy(settings = profile("p1").settings.copy(semesterStartDate = sourceStart))
        val f = fixture(profiles = listOf(source), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t0 })

        controller.duplicateProfile("p1")

        assertEquals(sourceStart, f.repo.snapshot.settings.semesterStartDate)
    }

    // ============ 换档后的「当前周」游标（Dart `_applyProfileState` :1139-1148） ============

    @Test
    fun `切换档案时当前周按目标档开学日重算 而不是带上一份的周数`() {
        val oldStart = LocalDateTime.of(2026, 8, 31, 0, 0) // 旧档：t0 落在第 1 周
        val newStart = LocalDateTime.of(2026, 2, 23, 0, 0) // 新档：t0 落在第 28 周，钳到 18
        val oldProfile = profile("p1", "旧课表", currentWeek = 1L)
            .copy(settings = profile("p1").settings.copy(semesterStartDate = oldStart, semesterWeekCount = 16))
        val newProfile = profile("p2", "新课表", currentWeek = 7L)
            .copy(settings = profile("p2").settings.copy(semesterStartDate = newStart, semesterWeekCount = 18))
        val f = fixture(profiles = listOf(oldProfile, newProfile), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, clock = { t0 })

        val result = controller.switchProfile("p2")

        assertTrue(result is TimetableProfileActionResult.Success)
        // t0 = 2026-09-01，新档开学日 2026-02-23 ⇒ 第 28 个日历周，超学期 18 周 ⇒ 钳到 18。
        assertEquals("切档后当前周必须按目标档开学日算", 18, f.repo.snapshot.currentWeek)
        assertEquals(18L, f.repo.snapshot.profiles.first { it.id == "p2" }.currentWeek)
        // 同一次合并写入只通知一次（周次与设置一起落）。
        assertEquals("p2", f.repo.snapshot.activeProfileId)
    }

    @Test
    fun `换档后的当前周落盘 杀进程重开仍在`() {
        val newStart = LocalDateTime.of(2026, 2, 23, 0, 0)
        val oldProfile = profile("p1", currentWeek = 1L)
        val newProfile = profile("p2", currentWeek = 7L)
            .copy(settings = profile("p2").settings.copy(semesterStartDate = newStart, semesterWeekCount = 18))
        val f = fixture(profiles = listOf(oldProfile, newProfile), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, clock = { t0 })

        controller.switchProfile("p2")

        // 杀进程重开（同一份盘、新实例）：周次不能退回 7 或旧档的 1。
        val reopened = TimetableRepository(TimetableStore(f.raw))
        assertEquals(18, reopened.snapshot.currentWeek)
        assertEquals(18L, reopened.snapshot.profiles.first { it.id == "p2" }.currentWeek)
    }

    @Test
    fun `不传周次的写入路径保持旧行为 周次不被改写`() {
        // 重命名走 `replaceAllProfiles`（settings / currentWeek 都不传），
        // 必须与 L4 加参数之前完全一致：不写 `current_week`，周次仍是档案里的值。
        val f = fixture(profiles = listOf(profile("p1", "旧名字", currentWeek = 3L)), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, clock = { t0 })

        controller.renameProfile("p1", "新名字")

        assertEquals(3, f.repo.snapshot.currentWeek)
        assertFalse(
            "没传 currentWeek 就不该写 current_week 键",
            f.raw.contains(TimetableStore.KEY_CURRENT_WEEK),
        )
        val reopened = TimetableRepository(TimetableStore(f.raw))
        assertEquals(3, reopened.snapshot.currentWeek)
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

    @Test
    fun `复制档案外观与语言跟源档完全一致 不是默认值`() {
        // Dart `duplicateActiveProfile:1967-1972` 拷贝整份 `TimetableSettings`；
        // 这里源档完整内嵌 JSON 带全局键与非全局外观键，复制品必须逐键照抄。
        val f = fullSettingsFixture(
            profileJson(
                id = "p1",
                fullSettings = mapOf(
                    "semesterStartDate" to "2026-09-07T00:00:00",
                    "semesterWeekCount" to 18,
                    "appLocaleTag" to "zh_TW",
                    "appThemeMode" to "dark",
                    "themeSeedColor" to "#123456",
                    "courseCardFontSize" to 11.0,
                    "timetableHideWeekends" to true,
                ),
            ),
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p_copy" }, clock = { t1 })

        val result = controller.duplicateProfile("p1")
        assertTrue("result=$result", result is TimetableProfileActionResult.Success)

        val copySettings = rawSettings(f.raw, "p_copy")
        assertEquals("语言（全局键）必须跟源档一致", "zh_TW", copySettings["appLocaleTag"])
        assertEquals("主题（全局键）必须跟源档一致", "dark", copySettings["appThemeMode"])
        assertEquals("种子色必须跟源档一致", "#123456", copySettings["themeSeedColor"])
        assertEquals("课程卡字号必须跟源档一致", 11.0, copySettings["courseCardFontSize"])
        assertEquals("课表页显示项必须跟源档一致", true, copySettings["timetableHideWeekends"])
        // 杀进程重开也还在（真落盘，不是只改了内存快照）。
        assertEquals("zh_TW", rawSettings(f.raw, "p_copy")["appLocaleTag"])
    }

    @Test
    fun `新建档案不继承源档档案级外观 但保留全局偏好`() {
        // Dart `createProfile:1940-1943` 新档 settings = defaults() + 当前作息 sections，
        // 再经 `_applyProfileState` 叠全局偏好（`app_global_settings_service.dart:59-114`）。
        val f = fullSettingsFixture(
            profileJson(
                id = "p1",
                fullSettings = mapOf(
                    "semesterStartDate" to "2026-09-07T00:00:00",
                    "semesterWeekCount" to 18,
                    "appLocaleTag" to "zh_TW",
                    "appThemeMode" to "dark",
                    "themeSeedColor" to "#123456",
                    "courseCardFontSize" to 11.0,
                    "timetableHideWeekends" to true,
                ),
            ),
        )
        val controller = TimetableProfilesController(f.repo, idFactory = { "p2" }, clock = { t1 })

        val createResult = controller.createProfile("新课表")
        assertTrue("result=$createResult", createResult is TimetableProfileActionResult.Success)

        val created = rawSettings(f.raw, "p2")
        // 全局偏好（整机级）必须跟着走。
        assertEquals("zh_TW", created["appLocaleTag"])
        assertEquals("dark", created["appThemeMode"])
        assertEquals("#123456", created["themeSeedColor"])
        // 档案级外观/课表项不继承源档（缺键 = 读侧按 Dart lenient 回落默认值）。
        val parsed = TimetableSettingsModel.fromJson(rawMap(created))
        assertEquals("课程卡字号应回落默认 9.0", 9.0, parsed.courseCardFontSize, 0.0)
        assertFalse("周末隐藏应回落默认 false", parsed.timetableHideWeekends)
    }

    @Test
    fun `切档后目标档 lastUsedAt 更新且最近使用排序变化`() {
        val older = t0.minusDays(1)
        val p1 = profile("p1", "课表1").copy(lastUsedAt = older)
        val p2 = profile("p2", "课表2").copy(lastUsedAt = older)
        val f = fixture(profiles = listOf(p1, p2), activeId = "p1")
        val controller = TimetableProfilesController(f.repo, clock = { t1 })

        assertTrue(controller.switchProfile("p2") is TimetableProfileActionResult.Success)

        val switched = f.repo.snapshot.profiles
        assertEquals("目标档 lastUsedAt 必须刷新", t1, switched.first { it.id == "p2" }.lastUsedAt)
        assertEquals("非目标档 lastUsedAt 不动", older, switched.first { it.id == "p1" }.lastUsedAt)
        // 「最近使用」排序：切档前 p1/p2 同旧时间（按存储顺序），切档后 p2 必须排到最前。
        assertEquals(
            listOf("p2", "p1"),
            switched.sortedByDescending { it.lastUsedAt }.map { it.id },
        )
        // 落盘：重开仍是刷新后的时间。
        val reopened = TimetableRepository(TimetableStore(f.raw))
        assertEquals(t1, reopened.snapshot.profiles.first { it.id == "p2" }.lastUsedAt)
    }

    // ============ 夹具 ============

    private val t0: LocalDateTime = LocalDateTime.of(2026, 9, 1, 8, 0)
    private val t1: LocalDateTime = t0.plusDays(2)

    /**
     * 直接播种「完整内嵌 settings」的档案 JSON：Kotlin 的 `TimetableProfile.settings`
     * 只有 core 4 键，外观/语言只存在于磁盘内嵌 JSON，用 `saveProfiles` 造不出来。
     */
    private fun fullSettingsFixture(profilesJson: String): Fixture {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson,
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        val store = TimetableStore(raw)
        return Fixture(raw, store, TimetableRepository(store))
    }

    private fun profileJson(id: String, fullSettings: Map<String, Any?>): String {
        val base = profile(id, "源课表").toJson().toMutableMap()
        base["settings"] = fullSettings
        return MiniJson.encode(listOf(base))
    }

    /** 读档案在磁盘上的内嵌 settings（by id）。 */
    private fun rawSettings(raw: InMemoryKeyValueStore, profileId: String): Map<*, *> {
        val list = MiniJson.parse(raw.getString(TimetableStore.KEY_PROFILES)!!) as List<*>
        val entry = list.mapNotNull { it as? Map<*, *> }.first { it["id"] == profileId }
        return entry["settings"] as Map<*, *>
    }

    private fun rawMap(settings: Map<*, *>): Map<String, Any?> =
        settings.entries.mapNotNull { entry -> (entry.key as? String)?.let { it to entry.value } }.toMap()

    private class Fixture(
        val raw: InMemoryKeyValueStore,
        val store: TimetableStore,
        val repo: TimetableRepository,
    )

    private fun fixture(
        profiles: List<TimetableProfile>,
        activeId: String? = profiles.firstOrNull()?.id,
        schemes: List<TimeScheme> = emptyList(),
        settings: TimetableSettings? = null,
        /** true = 本机还持有对方课表绑定（写 `partner_timetable_binding` 键）。 */
        partnerBinding: Boolean = false,
    ): Fixture {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        if (profiles.isNotEmpty()) store.saveProfiles(profiles)
        store.saveActiveProfileId(activeId)
        settings?.let { store.saveSettings(it) }
        if (schemes.isNotEmpty()) store.saveTimeSchemes(schemes)
        // 与情侣页同一个逻辑 key（`CouplePartnerStorage.BINDING_KEY`；不带 flutter. 前缀）。
        if (partnerBinding) raw.putString("partner_timetable_binding", """{"partnerName":"小屿"}""")
        return Fixture(raw, store, TimetableRepository(store))
    }

    private fun scheme(id: String, startTime: String) = TimeScheme(
        id = id,
        name = "作息-$id",
        sections = listOf(SectionTime(startTime, "09:45"), SectionTime("09:55", "10:40")),
        createdAt = t0,
        updatedAt = t0,
    )

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
}
