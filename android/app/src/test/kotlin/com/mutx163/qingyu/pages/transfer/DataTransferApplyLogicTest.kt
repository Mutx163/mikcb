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
    fun `同 id 模板产出 Update 步骤_但执行端不得应用`() {
        val steps = DataTransferApplyLogic.planTimeSchemeSteps(
            current = listOf(scheme("ts1", "默认", sectionsA)),
            incoming = listOf(scheme("ts1", "默认(新)", sectionsB)),
        )
        assertEquals(
            listOf(DataTransferApplyLogic.TimeSchemeStep.Update("ts1", "默认(新)", sectionsB)),
            steps,
        )
        assertTrue(
            "Update 绝不能进落盘列表（否则会改写本机模板）",
            DataTransferApplyLogic.timeSchemeStepsToCreate(steps).isEmpty(),
        )
    }

    @Test
    fun `同id更新不改签名索引_后续同签名表复用对的那套`() {
        // 2026-11-06 三轮返工：Update 不得污染签名索引。
        // 旧实现把「外来签名 → 本机 id」写进索引、并把本机真实签名挤出去：
        // ① 后来同签名的外来表会复用节次不符的本机模板；② 与本机真实签名相同的表会被判成
        // 「没有双胞胎」而重复新建。下面这个组合把两种症状都钉住。
        val localA = scheme("t1", "本机A", sectionsA)
        val localB = scheme("t2", "本机B", sectionsB)
        val incoming = listOf(
            scheme("t1", "外来A", sectionsB), // 同 id → Update（只标映射）
            scheme("x", "外来签名B", sectionsB), // 应复用 t2（签名 B）
            scheme("y", "外来签名A", sectionsA), // 应复用 t1（签名 A 仍在索引里）
            scheme("z", "全新", listOf(SectionTime("11:00", "11:45"))), // 新建
        )

        val steps = DataTransferApplyLogic.planTimeSchemeSteps(
            current = listOf(localA, localB),
            incoming = incoming,
        )

        assertEquals(
            "同 id 只出 Update",
            listOf("t1"),
            steps.filterIsInstance<DataTransferApplyLogic.TimeSchemeStep.Update>().map { it.localId },
        )
        assertEquals(
            "外来 B 必须复用本机 t2（不是被 Update 污染成 t1）",
            listOf("t2"),
            steps.filterIsInstance<DataTransferApplyLogic.TimeSchemeStep.Reuse>()
                .filter { it.incomingId == "x" }.map { it.localId },
        )
        assertEquals(
            "外来 A 必须复用本机 t1（本机真实签名不许被挤出索引）",
            listOf("t1"),
            steps.filterIsInstance<DataTransferApplyLogic.TimeSchemeStep.Reuse>()
                .filter { it.incomingId == "y" }.map { it.localId },
        )
        assertEquals(
            "只有真正全新的那套才新建（不许重复建一套 A 节次）",
            listOf("z"),
            DataTransferApplyLogic.timeSchemeStepsToCreate(steps).map { it.incomingId },
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

    // ── 「导入为新课表」（2026-11-06，对齐 Dart importAppDataBackupAsNewProfile） ──

    @Test
    fun `导入为新课表拒绝全量备份`() {
        assertEquals(
            "import_use_overwrite_for_full_backup",
            DataTransferApplyLogic.importAsNewRejectionCode(
                fullBackupPlan(profiles = listOf(profile("p1", "大一上"))),
            ),
        )
        assertNull(
            "单课表包可以导入为新课表（内容少就是一份内容少的课表）",
            DataTransferApplyLogic.importAsNewRejectionCode(
                singleProfilePlan(courses = listOf(course("a", "高数"))),
            ),
        )
    }

    @Test
    fun `导入为新课表的撤销范围是整份档案表`() {
        val plan = singleProfilePlan(courses = listOf(course("a", "高数")))
        assertEquals(
            "多一份档 + 换激活 id + 换全局设置，撤销必须整份还原",
            TransferUndoScope.FULL_PROFILES,
            DataTransferApplyLogic.undoKindFor(plan, importAsNew = true),
        )
        // 不开 as-new 时仍是「只还原当前档内容」——旧行为不能被这条改掉。
        assertEquals(
            TransferUndoScope.ACTIVE_PROFILE_CONTENT,
            DataTransferApplyLogic.undoKindFor(plan),
        )
    }

    @Test
    fun `新档名沿用包内名_空则导入课表`() {
        assertEquals("我的课表", DataTransferApplyLogic.resolvedProfileName("  我的课表 "))
        assertEquals(
            "默认名走文案系统，值与发布版字面量逐字相同",
            TransferStrings.transferImportedProfileName.zh,
            DataTransferApplyLogic.resolvedProfileName(null),
        )
        assertEquals(
            "全空白也回落默认名",
            TransferStrings.transferImportedProfileName.zh,
            DataTransferApplyLogic.resolvedProfileName("   "),
        )
    }

    @Test
    fun `导入为新课表建出的档案内容正确`() {
        val plan = singleProfilePlan(
            courses = listOf(course("a", "高数", 1, 2), course("b", "英语", 1, 2)),
        ).copy(
            tasks = listOf(task("t1", "a"), task("t2", "orphan")),
            exams = listOf(exam("e1", "a")),
            currentWeek = 99,
        )
        val settings = TimetableSettings.defaults().copy(semesterWeekCount = 20)
        val newProfile = DataTransferApplyLogic.planImportAsNew(
            plan = plan,
            profileName = "我的课表",
            settings = settings,
            schemes = listOf(scheme("local", "默认", sectionsA)),
            newProfileId = "new-id",
            now = LocalDateTime.of(2026, 11, 6, 12, 0),
        )

        assertEquals("new-id", newProfile.id)
        assertEquals("我的课表", newProfile.name)
        assertEquals("包里的课全都要带过来", listOf("a", "b"), newProfile.courses.map { it.id })
        assertEquals(
            "作业按 courseId 过滤孤儿（Dart）",
            listOf("t1"),
            newProfile.tasks.map { it.id },
        )
        assertEquals(listOf("e1"), newProfile.exams.map { it.id })
        assertEquals("currentWeek 钳到学期周数", 20L, newProfile.currentWeek)
        assertEquals(settings, newProfile.settings)
    }

    @Test
    fun `设置对齐模板表_本机有则复用并把节次换成本机这套`() {
        val local = scheme("ts-1", "本机作息", sectionsA)
        val settings = TimetableSettings.defaults()
            .copy(activeTimeSchemeId = "ts-1", sections = sectionsB)

        val resolution = DataTransferApplyLogic.resolveSettingsAgainstSchemes(
            settings = settings,
            schemes = listOf(local),
            fallbackSchemeName = "我的课表 时间",
            newSchemeId = "new-ts",
            now = LocalDateTime.of(2026, 11, 6, 12, 0),
        )

        assertEquals("ts-1", resolution.settings.activeTimeSchemeId)
        assertEquals("sections 必须换成本机模板那套（否则设置与模板打架）", sectionsA, resolution.settings.sections)
        assertNull("本机已有就不该新建模板", resolution.schemeToCreate)
    }

    @Test
    fun `设置对齐模板表_节次签名相同则复用`() {
        val twin = scheme("ts-2", "同节次", sectionsA)
        val settings = TimetableSettings.defaults()
            .copy(activeTimeSchemeId = "ghost", sections = sectionsA)

        val resolution = DataTransferApplyLogic.resolveSettingsAgainstSchemes(
            settings = settings,
            schemes = listOf(scheme("ts-x", "别的节次", sectionsB), twin),
            fallbackSchemeName = "我的课表 时间",
            newSchemeId = "new-ts",
            now = LocalDateTime.of(2026, 11, 6, 12, 0),
        )

        assertEquals("ts-2", resolution.settings.activeTimeSchemeId)
        assertNull("签名相同就是同一套，别再堆一套重复模板", resolution.schemeToCreate)
    }

    @Test
    fun `设置对齐模板表_都没有则新建一套以课表名命名`() {
        val settings = TimetableSettings.defaults()
            .copy(activeTimeSchemeId = "ghost", sections = sectionsB)
        val now = LocalDateTime.of(2026, 11, 6, 12, 0)

        val resolution = DataTransferApplyLogic.resolveSettingsAgainstSchemes(
            settings = settings,
            schemes = listOf(scheme("ts-x", "别的节次", sectionsA)),
            fallbackSchemeName = "我的课表 时间",
            newSchemeId = "new-ts",
            now = now,
        )

        assertEquals("new-ts", resolution.settings.activeTimeSchemeId)
        assertEquals("我的课表 时间", resolution.schemeToCreate?.name)
        assertEquals(sectionsB, resolution.schemeToCreate?.sections)
        assertEquals(now, resolution.schemeToCreate?.createdAt)
    }

    // ── 返工（2026-11-06）：模板表整份还原 + 不改写本机模板 ──────────

    @Test
    fun `模板对齐只新建_同id与同签名一律不动本机模板`() {
        val localSameId = scheme("ts-1", "我的作息", sectionsA)
        val localTwin = scheme("ts-2", "同节次", sectionsB)
        val incoming = listOf(
            // 同 id、但名称与节次都被包改过 → plan 会产出 Update；**必须不被应用**。
            scheme("ts-1", "别人的作息", sectionsB),
            // 签名与 ts-2 相同、id 不同 → Reuse。
            scheme("ts-x", "随便叫", sectionsB),
            // 全新 → Create。
            scheme("ts-new", "新模板", listOf(SectionTime("10:00", "10:45"))),
        )

        val steps = DataTransferApplyLogic.planTimeSchemeSteps(
            current = listOf(localSameId, localTwin),
            incoming = incoming,
        )
        // 前提：三种步骤都真的出现，否则下面的过滤断言会空转。
        assertTrue("应有 Update 步骤", steps.any { it is DataTransferApplyLogic.TimeSchemeStep.Update })
        assertEquals(
            "应有 1 个 Reuse",
            1,
            steps.count { it is DataTransferApplyLogic.TimeSchemeStep.Reuse },
        )
        assertEquals(
            "应有 1 个 Create",
            1,
            steps.count { it is DataTransferApplyLogic.TimeSchemeStep.Create },
        )

        val toCreate = DataTransferApplyLogic.timeSchemeStepsToCreate(steps)
        assertEquals("只允许新建这一种落盘", 1, toCreate.size)
        assertEquals("ts-new", toCreate.single().incomingId)
        assertTrue(
            "同 id 那条绝不能进落盘列表（否则会改写本机模板）",
            toCreate.none { it.incomingId == "ts-1" },
        )
    }

    @Test
    fun `撤销快照能带上时间模板表整份`() {
        val schemes = listOf(scheme("ts-1", "我的作息", sectionsA))
        val snapshot = TransferUndoSnapshot(
            kind = TransferUndoScope.FULL_PROFILES,
            timeSchemes = schemes,
        )
        assertEquals("模板表必须原样存在快照里，撤销才有东西写回", schemes, snapshot.timeSchemes)
        assertNull("没有模板表的快照 = 不负责还原它（老调用点）", TransferUndoSnapshot(
            kind = TransferUndoScope.ACTIVE_PROFILE_CONTENT,
        ).timeSchemes)
    }

    @Test
    fun `会重排所有档的导入_撤销范围必须是整份档案表`() {
        // 2026-11-06 三轮返工：`updateLocationTimeGroups(resync = true)` 会把**所有档**的
        // 课程钟点重排；回滚若只还原活动档，其它档就停在新钟点上（半还原）。改多少必须能还原多少。
        val plan = singleProfilePlan(courses = listOf(course("a", "高数")))
        assertEquals(
            "不重排时仍是「只还原当前档」",
            TransferUndoScope.ACTIVE_PROFILE_CONTENT,
            DataTransferApplyLogic.undoKindFor(plan),
        )
        assertEquals(
            "会重排所有档 ⇒ 快照必须整份档案表",
            TransferUndoScope.FULL_PROFILES,
            DataTransferApplyLogic.undoKindFor(plan, rewritesAllProfiles = true),
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
