package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.pages.course.AddCourseFormLogic
import com.mutx163.qingyu.pages.course.AddCourseGroupData
import com.mutx163.qingyu.pages.course.AddCourseSaveMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * Phase 3.5 · L4 宿主层纯逻辑单测。
 *
 * 期望值全部**手推**（照 Dart 出处一条条推），不从实现里抄：
 * - `lib/domain/timetable_layout.dart:6-17`（可见天 / 时间列宽）
 * - `lib/models/timetable_settings.dart:754`（节次行高默认 68）
 * - `lib/widgets/timetable/timetable_empty_slot_layer.dart:46,111`（空档加课开关）
 * - `lib/services/storage_service.dart:1645`（首启档案名「默认课表」）
 * - `lib/screens/add_course_screen.dart:2044-2064`（保存三分支）/ `:448-473`、`:1406-1425`（删除两分支）
 */
class TimetableHostLogicTest {

    private val baseTime = LocalDateTime.of(2026, 10, 28, 8, 0)

    // ── 1. 可见星期几 ──

    @Test
    fun `隐藏周末时只留周一到周五`() {
        assertEquals(listOf(1, 2, 3, 4, 5), TimetableHostLogic.visibleDayNumbers(hideWeekends = true))
    }

    @Test
    fun `不隐藏周末时是完整七天`() {
        assertEquals(
            listOf(1, 2, 3, 4, 5, 6, 7),
            TimetableHostLogic.visibleDayNumbers(hideWeekends = false),
        )
    }

    // ── 2. 时间列宽 ──

    @Test
    fun `时间列宽窄档 34 宽档 40`() {
        assertEquals(34f, TimetableHostLogic.timeColumnWidthDp(wide = false), 0f)
        assertEquals(40f, TimetableHostLogic.timeColumnWidthDp(wide = true), 0f)
    }

    @Test
    fun `节次行高默认取 Dart 的 68 而不是页面签名占位 64`() {
        assertEquals(68f, TimetableHostLogic.DEFAULT_SECTION_HEIGHT_DP, 0f)
        assertEquals(68f, TimetableHostDisplayPrefs().sectionHeightDp, 0f)
    }

    // ── 3. 空档加课开关 ──

    @Test
    fun `开关开着且有跨度才放行`() {
        assertTrue(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = true,
                span = 1,
            ),
        )
    }

    @Test
    fun `开关关着一律不放行`() {
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = false,
                span = 1,
            ),
        )
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = false,
                span = 0,
            ),
        )
    }

    @Test
    fun `跨度为零或负不算空档 开关开着也不放行`() {
        // Dart 判据是 `!enabled || span <= 0`：两个条件都要过。
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = true,
                span = 0,
            ),
        )
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = true,
                span = -1,
            ),
        )
    }

    @Test
    fun `空档加课默认关闭`() {
        assertFalse(TimetableHostDisplayPrefs().longPressEmptySlotToAddCourseEnabled)
        assertFalse(TimetableHostDisplayPrefs().hideWeekends)
        assertFalse(TimetableHostDisplayPrefs().wideTimeColumn)
    }

    // ── 4. 档案名 ──

    @Test
    fun `当前档案命中时用它的名字`() {
        val profiles = listOf(profile("a", "课表 A"), profile("b", "课表 B"))
        assertEquals("课表 B", TimetableHostLogic.resolveProfileName(profiles, activeProfileId = "b"))
    }

    @Test
    fun `当前档案名是空白时退到未命名课表`() {
        val profiles = listOf(profile("a", "   "))
        assertEquals(
            TimetableProfile.UNNAMED,
            TimetableHostLogic.resolveProfileName(profiles, activeProfileId = "a"),
        )
    }

    @Test
    fun `当前档案 id 缺失时退到第一份档`() {
        val profiles = listOf(profile("a", "课表 A"), profile("b", "课表 B"))
        assertEquals("课表 A", TimetableHostLogic.resolveProfileName(profiles, activeProfileId = null))
    }

    @Test
    fun `当前档案 id 指向不存在的档时退到第一份档`() {
        val profiles = listOf(profile("a", "课表 A"))
        assertEquals("课表 A", TimetableHostLogic.resolveProfileName(profiles, activeProfileId = "zzz"))
    }

    @Test
    fun `一份档都没有时用首启兜底名`() {
        assertEquals(
            "默认课表",
            TimetableHostLogic.resolveProfileName(emptyList(), activeProfileId = null),
        )
        assertEquals("默认课表", TimetableHostLogic.DEFAULT_PROFILE_NAME)
    }

    // ── 5. 生效作息模板 ──

    @Test
    fun `生效模板命中时用它`() {
        val schemes = listOf(scheme("s1", "模板一"), scheme("s2", "模板二"))
        assertEquals("模板二", TimetableHostLogic.resolveActiveTimeScheme(schemes, "s2")?.name)
    }

    @Test
    fun `生效模板 id 缺失或指向不存在的档时退到第一份`() {
        val schemes = listOf(scheme("s1", "模板一"), scheme("s2", "模板二"))
        assertEquals("模板一", TimetableHostLogic.resolveActiveTimeScheme(schemes, null)?.name)
        assertEquals("模板一", TimetableHostLogic.resolveActiveTimeScheme(schemes, "zzz")?.name)
    }

    @Test
    fun `一份模板都没有时返回 null 让页面回落 settings 节次表`() {
        // 宿主不许自己造节次表：TimetableWeekPage.kt:126-127 会回落到 settings.sections。
        assertNull(TimetableHostLogic.resolveActiveTimeScheme(emptyList(), "s1"))
    }

    // ── 构造工具 ──

    private fun profile(id: String, name: String): TimetableProfile = TimetableProfile(
        id = id,
        name = name,
        currentWeek = 1,
        createdAt = baseTime,
        lastUsedAt = baseTime,
    )

    private fun scheme(id: String, name: String): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = listOf(SectionTime("08:00", "08:45")),
        createdAt = baseTime,
        updatedAt = baseTime,
    )

    // ── 6. 保存分派：整组替换（P3.5-1c 的验收核心）──

    @Test
    fun `组编辑后只剩两门课时 第三门必须真的从仓储消失`() {
        val repo = newRepository()
        repo.addCourse(course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1))
        repo.addCourse(course(id = "c2", name = "高等数学", dayOfWeek = 3, section = 3))
        repo.addCourse(course(id = "c3", name = "高等数学", dayOfWeek = 5, section = 5))
        assertEquals(3, groupSize(repo, "高等数学"))

        // 用户在编辑页把第三条课次删掉；保存载荷里只剩两条（整组替换的语义）。
        TimetableSaveDispatcher.applySave(
            port = repo,
            originalGroupName = "高等数学",
            courses = listOf(
                course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1),
                course(id = "c2", name = "高等数学", dayOfWeek = 3, section = 3),
            ),
        )

        assertEquals(2, groupSize(repo, "高等数学"))
        assertFalse(
            "第 3 门课必须真的从仓储消失——壳里旧的「逐课 updateCourse」实现会把它留在盘上",
            repo.snapshot.courses.any { it.id == "c3" },
        )
        assertTrue("保留的两条应当在", repo.snapshot.courses.any { it.id == "c1" })
        assertTrue("保留的两条应当在", repo.snapshot.courses.any { it.id == "c2" })
    }

    @Test
    fun `整组替换按原始组名摘除 改名后不留旧名课次`() {
        // Dart add_course_screen.dart:2049-2058 的注释：走 delete+add 会让同名兄弟
        // 课次活下来、再把旧的共享字段广播回去。整组替换必须按**原始**组名摘。
        val repo = newRepository()
        repo.addCourse(course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1))
        repo.addCourse(course(id = "c2", name = "高等数学", dayOfWeek = 3, section = 3))
        repo.addCourse(course(id = "c3", name = "高等数学", dayOfWeek = 5, section = 5))

        TimetableSaveDispatcher.applySave(
            port = repo,
            originalGroupName = "高等数学",
            courses = listOf(
                course(id = "c1", name = "高等数学 A", dayOfWeek = 1, section = 1),
                course(id = "c2", name = "高等数学 A", dayOfWeek = 3, section = 3),
            ),
        )

        assertEquals(0, groupSize(repo, "高等数学"))
        assertEquals(2, groupSize(repo, "高等数学 A"))
        assertEquals(2, repo.snapshot.courses.size)
    }

    @Test
    fun `空课次列表是 no-op 不会把整组抹掉`() {
        // 服务侧 updateGroup 对空集合直接 return（挡在摘除旧课次之前）：
        // 否则「表单里一条不剩」会把整组课无声删光。
        val repo = newRepository()
        repo.addCourse(course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1))
        repo.addCourse(course(id = "c2", name = "高等数学", dayOfWeek = 3, section = 3))

        TimetableSaveDispatcher.applySave(
            port = repo,
            originalGroupName = "高等数学",
            courses = emptyList(),
        )

        assertEquals(2, groupSize(repo, "高等数学"))
    }

    @Test
    fun `新建走逐条新增 不碰既有课次`() {
        val repo = newRepository()
        repo.addCourse(course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1))

        TimetableSaveDispatcher.applySave(
            port = repo,
            originalGroupName = null,
            courses = listOf(
                course(id = "n1", name = "大学物理", dayOfWeek = 2, section = 2),
                course(id = "n2", name = "大学物理", dayOfWeek = 4, section = 4),
            ),
        )

        assertEquals(1, groupSize(repo, "高等数学"))
        assertEquals(2, groupSize(repo, "大学物理"))
    }

    // ── 7. 删除分派 ──

    @Test
    fun `删除目标判定 组编辑优先整组 单课编辑只删一条 新建态没有删除入口`() {
        val existing = course(id = "c9", name = "高等数学", dayOfWeek = 1, section = 1)
        assertEquals(
            TimetableDeleteTarget.WholeGroup("高等数学"),
            TimetableSaveDispatcher.resolveDeleteTarget(
                originalGroupName = "高等数学",
                initialCourse = existing,
            ),
        )
        assertEquals(
            TimetableDeleteTarget.SingleCourse("c9"),
            TimetableSaveDispatcher.resolveDeleteTarget(
                originalGroupName = null,
                initialCourse = existing,
            ),
        )
        assertNull(
            TimetableSaveDispatcher.resolveDeleteTarget(
                originalGroupName = null,
                initialCourse = null,
            ),
        )
    }

    @Test
    fun `整组删除把同名的三条课次一起摘掉`() {
        val repo = newRepository()
        repo.addCourse(course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1))
        repo.addCourse(course(id = "c2", name = "高等数学", dayOfWeek = 3, section = 3))
        repo.addCourse(course(id = "c3", name = "高等数学", dayOfWeek = 5, section = 5))
        repo.addCourse(course(id = "p1", name = "大学物理", dayOfWeek = 2, section = 2))

        TimetableSaveDispatcher.applyDelete(
            port = repo,
            target = TimetableDeleteTarget.WholeGroup("高等数学"),
        )

        assertEquals(0, groupSize(repo, "高等数学"))
        assertEquals(1, groupSize(repo, "大学物理"))
    }

    @Test
    fun `单条删除只摘那一条 同组兄弟留着`() {
        val repo = newRepository()
        repo.addCourse(course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1))
        repo.addCourse(course(id = "c2", name = "高等数学", dayOfWeek = 3, section = 3))
        repo.addCourse(course(id = "c3", name = "高等数学", dayOfWeek = 5, section = 5))

        TimetableSaveDispatcher.applyDelete(
            port = repo,
            target = TimetableDeleteTarget.SingleCourse("c2"),
        )

        assertEquals(2, groupSize(repo, "高等数学"))
        assertFalse(repo.snapshot.courses.any { it.id == "c2" })
        assertTrue(repo.snapshot.courses.any { it.id == "c1" })
        assertTrue(repo.snapshot.courses.any { it.id == "c3" })
    }

    // ── 8. 分派判据的跨层契约（分派器依赖的那条等价关系）──

    @Test
    fun `编辑态载荷的 targetGroupName 非空 新建态为空`() {
        // `TimetableSaveDispatcher.applySave` 用「originalGroupName == null ? 新建 : 整组替换」
        // 判断分支，所以页面模型必须保证：编辑 ⟺ UPDATE_GROUP ⟺ targetGroupName != null。
        // 这条断言钉住的就是这个等价关系（壳里只传 payload.targetGroupName）。
        val existing = course(id = "c1", name = "高等数学", dayOfWeek = 1, section = 1)

        val singleEdit = AddCourseFormLogic.resolveSaveTarget(
            initialCourse = existing,
            courseGroup = null,
        )
        assertEquals(AddCourseSaveMode.UPDATE_GROUP, singleEdit.mode)
        assertEquals("高等数学", singleEdit.targetGroupName)

        val groupEdit = AddCourseFormLogic.resolveSaveTarget(
            initialCourse = null,
            courseGroup = AddCourseGroupData(name = "高等数学", courses = listOf(existing)),
        )
        assertEquals(AddCourseSaveMode.UPDATE_GROUP, groupEdit.mode)
        assertEquals("高等数学", groupEdit.targetGroupName)

        val create = AddCourseFormLogic.resolveSaveTarget(initialCourse = null, courseGroup = null)
        assertEquals(AddCourseSaveMode.ADD, create.mode)
        assertNull(create.targetGroupName)
    }

    // ── 测试夹具 ──

    private fun newRepository(): TimetableRepository =
        TimetableRepository(TimetableStore(InMemoryKeyValueStore()))

    private fun groupSize(repo: TimetableRepository, name: String): Int =
        repo.snapshot.courses.count { it.name == name }

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int,
        section: Int,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "三教-401",
        dayOfWeek = dayOfWeek,
        startSection = section,
        endSection = section,
        startTime = "08:00",
        endTime = "08:45",
    )
}
