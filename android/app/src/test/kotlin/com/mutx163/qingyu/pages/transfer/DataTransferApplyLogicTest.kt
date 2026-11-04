package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入落盘与撤销的纯逻辑（2026-10-29 审核补）。
 *
 * 期望值按 Dart 手推：
 * - 合并语义：`unified_transfer_service.dart:485-507` 的 `mode: merge`（同 id 更新、新增追加、**缺的不删**）；
 * - 全量包合并：Dart 支持逐实体合并，Kotlin 侧明确拒绝并保持数据不动（本批的刻意差异）；
 * - 撤销范围：写入多少就抓多少（见 [DataTransferApplyLogic.undoKindFor]）。
 */
class DataTransferApplyLogicTest {

    // ── 可应用性 ────────────────────────────────────────────────────

    @Test
    fun `单课表包两种模式都可应用`() {
        val plan = singleProfilePlan(courses = listOf(course("a", "高数")))
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.OVERWRITE))
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.MERGE))
    }

    @Test
    fun `全量包覆盖可用但合并明确拒绝`() {
        val plan = fullBackupPlan(profiles = listOf(profile("p1", "大一上")))
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.OVERWRITE))
        assertEquals(
            "full_backup_merge_unsupported",
            DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.MERGE),
        )
    }

    @Test
    fun `全量包没有档案时覆盖也拒绝`() {
        // 防御式：解析层已挡过空 profiles，但调用方可能直接构造计划。
        val plan = fullBackupPlan(profiles = emptyList())
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.OVERWRITE))
        assertFalse(DataTransferApplyLogic.isFullBackupPlan(plan))
    }

    // ── 合并算法 ────────────────────────────────────────────────────

    @Test
    fun `合并时同 id 用包里的值`() {
        val current = listOf(course("a", "高数"), course("b", "英语"))
        val incoming = listOf(course("a", "高数(新)"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(listOf("高数(新)", "英语"), merged.map { it.name })
    }

    @Test
    fun `合并时新 id 追加到末尾并保持包里顺序`() {
        val current = listOf(course("a", "高数"))
        val incoming = listOf(course("x", "体育"), course("y", "物理"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(listOf("高数", "体育", "物理"), merged.map { it.name })
    }

    @Test
    fun `合并时不删除当前独有的课`() {
        val current = listOf(course("a", "高数"), course("b", "英语"), course("c", "化学"))
        val incoming = listOf(course("a", "高数"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(3, merged.size)
        assertTrue(merged.any { it.id == "c" })
    }

    @Test
    fun `包里没有课程时合并等于原样`() {
        val current = listOf(course("a", "高数"))
        assertEquals(current, DataTransferApplyLogic.mergeCourses(current, emptyList()))
    }

    @Test
    fun `合并后同一 id 不重复出现`() {
        val current = listOf(course("a", "高数"))
        val incoming = listOf(course("a", "高数"), course("a", "高数"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(1, merged.count { it.id == "a" })
    }

    // ── 超出作息的课 ────────────────────────────────────────────────

    @Test
    fun `超出作息节数的课按节次上限统计`() {
        val courses = listOf(
            course("a", "早八", start = 1, end = 2),
            course("b", "超出", start = 12, end = 14),
            course("c", "节次倒挂", start = 5, end = 3),
        )
        // Dart `TimeSchemeLogic.countCoursesWithoutVisibleRow`：start<1 或 end<start 或 end>节数。
        assertEquals(2, DataTransferApplyLogic.coursesBeyondScheme(courses, sectionCount = 12))
        assertEquals(0, DataTransferApplyLogic.coursesBeyondScheme(courses, sectionCount = 0))
    }

    // ── 撤销快照范围 ────────────────────────────────────────────────

    @Test
    fun `全量包撤销抓整份档案表`() {
        assertEquals(
            TransferUndoScope.FULL_PROFILES,
            DataTransferApplyLogic.undoKindFor(fullBackupPlan(profiles = listOf(profile("p1", "大一上")))),
        )
    }

    // ── 模板 id 改写（2026-11-01 P1：规则与地点分组也要改） ──────────────

    @Test
    fun `跨设备导入时 日程规则与地点分组的模板引用一起改写`() {
        val plan = planWithRulesAndGroups()
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
            schemeIdMap = mapOf("ts-old" to "ts-new"),
        )
        assertEquals(
            "日程规则指向的模板必须按映射改写，否则规则静默失效",
            "ts-new",
            writes.scheduleDateRules.single().timeSchemeId,
        )
        assertEquals(
            "地点分组指向的模板必须按映射改写",
            "ts-new",
            writes.locationTimeGroups.single().timeSchemeId,
        )
    }

    @Test
    fun `映射里没有的模板引用保持原值而不是被置空`() {
        // 映射只覆盖「本机新建的那几套」；id 恰好一致的模板不会进映射，
        // 若按缺失置空，同设备往返会把所有引用抹掉（净损失）。
        val plan = planWithRulesAndGroups()
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
            schemeIdMap = mapOf("another-scheme" to "whatever"),
        )
        assertEquals("ts-old", writes.scheduleDateRules.single().timeSchemeId)
        assertEquals("ts-old", writes.locationTimeGroups.single().timeSchemeId)
    }

    // ── 全量包当前周（2026-11-01 P1） ───────────────────────────────

    @Test
    fun `全量包顶层没有当前周时取活动档案自己那份`() {
        val plan = fullBackupPlan(
            profiles = listOf(profile("p1", "大一上").copy(currentWeek = 5L)),
        ).copy(currentWeek = null)
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.ALL_DATA,
        )
        assertEquals("顶层不带时回落到档案的当前周", 5, writes.currentWeek)
    }

    @Test
    fun `全量包顶层有当前周时以顶层为准`() {
        val plan = fullBackupPlan(
            profiles = listOf(profile("p1", "大一上").copy(currentWeek = 5L)),
        ).copy(currentWeek = 8)
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.ALL_DATA,
        )
        assertEquals(8, writes.currentWeek)
    }

    @Test
    fun `单课表包撤销只抓当前档案的三块与设置`() {
        assertEquals(
            TransferUndoScope.ACTIVE_PROFILE_CONTENT,
            DataTransferApplyLogic.undoKindFor(singleProfilePlan(courses = listOf(course("a", "高数")))),
        )
    }

    // ── 落盘前引用校验（2026-11-03 补 Dart `validate`） ──────────────

    @Test
    fun `考试指向不存在的课时报 exam_course_missing`() {
        val plan = singleProfilePlan(courses = listOf(course("a", "高数")))
            .copy(exams = listOf(exam("e1", courseId = "ghost")))
        assertEquals(
            listOf("exam_course_missing:e1"),
            DataTransferApplyLogic.referenceErrors(plan, DataTransferApplyLogic.TransferReferenceBaseline()),
        )
    }

    @Test
    fun `本机已有课程可作为引用基线`() {
        val plan = singleProfilePlan(courses = emptyList())
            .copy(tasks = listOf(task("t1", courseId = "c-local")))
        assertEquals(
            emptyList<String>(),
            DataTransferApplyLogic.referenceErrors(
                plan,
                DataTransferApplyLogic.TransferReferenceBaseline(courseIds = setOf("c-local")),
            ),
        )
    }

    @Test
    fun `规则与地点分组指向不存在的作息表时逐个报错`() {
        assertEquals(
            listOf("time_rule_scheme_missing:r1", "location_scheme_missing:g1"),
            DataTransferApplyLogic.referenceErrors(
                planWithRulesAndGroups(),
                DataTransferApplyLogic.TransferReferenceBaseline(),
            ),
        )
    }

    @Test
    fun `全空全量包报 transfer_all_data_empty`() {
        val plan = TransferImportPlan(
            profiles = emptyList(),
            activeProfileId = null,
            courses = emptyList(),
            settings = null,
            currentWeek = null,
            timeSchemes = emptyList(),
            tasks = emptyList(),
            exams = emptyList(),
            scheduleItems = emptyList(),
            scheduleDateRules = emptyList(),
        )
        assertEquals(
            listOf("transfer_all_data_empty"),
            DataTransferApplyLogic.referenceErrors(plan, DataTransferApplyLogic.TransferReferenceBaseline()),
        )
    }

    // ── 时间模板落盘步骤（Dart `_mergeTimeSchemes`） ─────────────────

    @Test
    fun `同 id 模板走更新`() {
        val steps = DataTransferApplyLogic.planTimeSchemeSteps(
            current = listOf(scheme("ts1", "默认", sectionsA)),
            incoming = listOf(scheme("ts1", "默认(新)", sectionsB)),
        )
        assertEquals(
            listOf(DataTransferApplyLogic.TimeSchemeStep.Update("ts1", "默认(新)", sectionsB)),
            steps,
        )
    }

    @Test
    fun `节次表完全相同的模板复用本机 id 且不改名`() {
        // Dart :866-877：id 不同但节次表一致 ⇒ 同一张表的另一份，复用本机 id。
        // 旧宿主只做「同 id 更新 / 其余新建」，每次跨设备导入都会多堆一套相同的模板。
        val steps = DataTransferApplyLogic.planTimeSchemeSteps(
            current = listOf(scheme("local-ts", "我的作息", sectionsA)),
            incoming = listOf(scheme("remote-ts", "对方作息", sectionsA)),
        )
        assertEquals(
            listOf(DataTransferApplyLogic.TimeSchemeStep.Reuse("remote-ts", "local-ts")),
            steps,
        )
    }

    @Test
    fun `完全陌生的模板才新建`() {
        val steps = DataTransferApplyLogic.planTimeSchemeSteps(
            current = listOf(scheme("local-ts", "我的作息", sectionsA)),
            incoming = listOf(scheme("remote-ts", "对方作息", sectionsB)),
        )
        assertEquals(
            listOf(DataTransferApplyLogic.TimeSchemeStep.Create("remote-ts", "对方作息", sectionsB)),
            steps,
        )
    }

    // ── 构造器 ──────────────────────────────────────────────────────

    private fun singleProfilePlan(courses: List<Course>) = TransferImportPlan(
        profiles = emptyList(),
        activeProfileId = "p1",
        courses = courses,
        settings = TimetableSettings.defaults(),
        currentWeek = 3,
        timeSchemes = emptyList(),
        tasks = emptyList(),
        exams = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = emptyList(),
    )

    private fun fullBackupPlan(profiles: List<TimetableProfile>) = TransferImportPlan(
        profiles = profiles,
        activeProfileId = profiles.firstOrNull()?.id,
        courses = emptyList(),
        settings = TimetableSettings.defaults(),
        currentWeek = 1,
        timeSchemes = emptyList(),
        tasks = emptyList(),
        exams = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = emptyList(),
    )

    /** 单课表计划，带一条日期规则与一个地点分组，模板都指向 `ts-old`。 */
    private fun planWithRulesAndGroups() = TransferImportPlan(
        profiles = emptyList(),
        activeProfileId = "p1",
        courses = emptyList(),
        settings = null,
        currentWeek = 1,
        timeSchemes = emptyList(),
        tasks = emptyList(),
        exams = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = listOf(
            ScheduleDateRule(
                id = "r1",
                name = "国庆调休",
                timeSchemeId = "ts-old",
                startDate = "2026-10-01",
                endDate = "2026-10-07",
                enabled = true,
            ),
        ),
        locationTimeGroups = listOf(
            LocationTimeGroup(id = "g1", name = "实验室作息", timeSchemeId = "ts-old"),
        ),
    )

    private fun profile(id: String, name: String) = TimetableProfile(
        id = id,
        name = name,
        currentWeek = 1L,
        createdAt = java.time.LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = java.time.LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun course(
        id: String,
        name: String,
        start: Int = 1,
        end: Int = 2,
    ) = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = start,
        endSection = end,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun exam(id: String, courseId: String) = Exam(
        id = id,
        courseId = courseId,
        name = "期中",
        dateTime = LocalDateTime.of(2026, 4, 20, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun task(id: String, courseId: String) = CourseTask(
        id = id,
        title = "作业",
        courseId = courseId,
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun scheme(id: String, name: String, sections: List<SectionTime>) = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private val sectionsA = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40"))
    private val sectionsB = listOf(SectionTime("09:00", "09:45"), SectionTime("09:55", "10:40"))
}
