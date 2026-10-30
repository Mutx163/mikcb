package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **导出 → 解析 → 落盘计划** 的整条数据链路（2026-10-29 二轮修复的牙齿）。
 *
 * ## 这个用例在钉什么
 *
 * 修的是一个「用户点得到、看得出来」的缺陷：导入时作业 / 考试 / 日程条目 /
 * 时间模板 / 日程规则**全部被丢掉**（旧 `applyImport` 只写档案、课表、设置、当前周）。
 * 那种缺陷的危险之处在于**单看每个函数都正常**——拼包对、解析对、写入也对，
 * 只有把三段连起来才能看出少了几类数据。所以这里不走单个函数，走整条链：
 *
 * ```
 * TimetableSnapshot ──build──▶ 包 JSON ──parse──▶ TransferImportPlan ──planWrites──▶ 要写的内容
 * ```
 *
 * 断言的是**最后一列**：包里有的东西，要写的内容里也必须都有、且内容一致。
 * 仓储（`TimetableRepository`）进不了 JVM 单测，所以边界画在「要写什么」这一层，
 * 真正的 `repository.xxx()` 调用由宿主负责（那部分只能真机验，见审核文档 §六）。
 *
 * 反向验证（咬合探针）：把 `planWrites` 里的 `tasks = plan.tasks` 改回
 * `tasks = current.tasks`，`单个课表包 导出再导入 作业与考试都还在` 这条会立刻红
 * （expected:<1> but was:<0>）；把 `timeSchemes = plan.timeSchemes` 删掉，
 * 时间模板那条会红。
 */
class DataTransferRoundTripTest {

    private val now = LocalDateTime.of(2026, 3, 2, 10, 0)

    // ── 1. 单课表包：导出 → 导入，五类附属数据都在 ──────────────────

    @Test
    fun `单个课表包 导出再导入 作业与考试都还在`() {
        val snapshot = snapshot()
        val plan = parse(export(snapshot, TransferScope.CURRENT_TIMETABLE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        // 旧版就是在这里丢了：`tasks = repository.tasks`（本机旧值）导致 0 条。
        assertEquals("作业应随包写回", listOf("task-1"), writes.tasks.map { it.id })
        assertEquals("作业标题应逐字保留", "作业-task-1", writes.tasks.single().title)
        assertEquals("作业指向的课不能丢", "c1", writes.tasks.single().courseId)
        assertEquals("考试应随包写回", listOf("exam-1"), writes.exams.map { it.id })
        assertEquals("考试时间应逐字保留", LocalDateTime.of(2026, 6, 20, 9, 0), writes.exams.single().dateTime)
    }

    @Test
    fun `单个课表包 导出再导入 日程条目与时间模板都还在`() {
        val snapshot = snapshot()
        val plan = parse(export(snapshot, TransferScope.CURRENT_TIMETABLE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals("日程条目应随包写回", listOf("item-1"), writes.scheduleItems.map { it.id })
        assertEquals("时间模板应随包写回", listOf("ts1"), writes.timeSchemes.map { it.id })
        assertEquals("模板节次表应逐字保留", 3, writes.timeSchemes.single().sections.size)
        assertEquals("日程规则应随包写回", listOf("rule-1"), writes.scheduleDateRules.map { it.id })
        assertEquals("规则绑的模板 id 不能变", "ts1", writes.scheduleDateRules.single().timeSchemeId)
    }

    @Test
    fun `单个课表包 导出再导入 课表 设置与当前周都在`() {
        val snapshot = snapshot()
        val plan = parse(export(snapshot, TransferScope.CURRENT_TIMETABLE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals(listOf("c1"), writes.courses.map { it.id })
        assertEquals("当前周应随包写回", 3, writes.currentWeek)
        assertNotNull("设置应随包写回", writes.settings)
        assertEquals("活动作息应保留", "ts1", writes.settings?.activeTimeSchemeId)
        assertTrue("不该被当成全量包", !writes.isFullBackup)
    }

    // ── 2. 全量包：档案里的附属数据跟着档案一起走 ────────────────────

    @Test
    fun `全量包 导出再导入 档案里的作业考试日程都还在`() {
        val snapshot = snapshot()
        val plan = parse(export(snapshot, TransferScope.ALL_DATA))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.ALL_DATA,
        )

        assertTrue("全量包应走 profiles 分支", writes.isFullBackup)
        assertEquals(listOf("p1"), writes.profiles.map { it.id })
        val profile = writes.profiles.single()
        assertEquals("档案里的作业应保留", listOf("task-1"), profile.tasks.map { it.id })
        assertEquals("档案里的考试应保留", listOf("exam-1"), profile.exams.map { it.id })
        assertEquals("档案里的日程应保留", listOf("item-1"), profile.scheduleItems.map { it.id })
        assertEquals("档案里的课表应保留", listOf("c1"), profile.courses.map { it.id })
        assertEquals("激活档案 id 应保留", "p1", writes.activeProfileId)
        assertEquals("时间模板应随全量包写回", listOf("ts1"), writes.timeSchemes.map { it.id })
        assertEquals("日程规则应随全量包写回", listOf("rule-1"), writes.scheduleDateRules.map { it.id })
        assertEquals("全量包也要还原活动作息", "ts1", writes.settings?.activeTimeSchemeId)
    }

    // ── 3. 合并模式：本机的与包里的一起在（不是「包覆盖一切」） ────────

    @Test
    fun `合并模式 本机作业不丢 包里的作业也进来`() {
        val plan = parse(export(snapshot(), TransferScope.CURRENT_TIMETABLE))
        val current = DataTransferApplyLogic.TransferCurrentContent(
            courses = listOf(course("c9", "本机课")),
            tasks = listOf(task("task-local", "c9")),
            exams = listOf(exam("exam-local", "c9")),
        )

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.MERGE,
            current = current,
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals(
            "合并：同 id 更新、新 id 追加、缺的不删",
            listOf("task-local", "task-1"),
            writes.tasks.map { it.id },
        )
        assertEquals(listOf("exam-local", "exam-1"), writes.exams.map { it.id })
        assertEquals("课表同理", listOf("c9", "c1"), writes.courses.map { it.id })
    }

    @Test
    fun `合并模式 空包不动本机数据`() {
        val plan = transferEnvelopeOnlyPlan()
        val current = DataTransferApplyLogic.TransferCurrentContent(
            courses = listOf(course("c9", "本机课")),
            tasks = listOf(task("task-local", "c9")),
        )

        val writes = DataTransferApplyLogic.planWrites(
            plan,
            TransferApplyMode.MERGE,
            current,
            TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals(listOf("c9"), writes.courses.map { it.id })
        assertEquals(listOf("task-local"), writes.tasks.map { it.id })
        assertEquals("没有规则的包不该把本机规则清空", emptyList<ScheduleDateRule>(), writes.scheduleDateRules)
    }

    // ── 4. 时间模板 id 改写：跨设备导入时引用不能悬空 ────────────────

    @Test
    fun `模板 id 在本机不存在时 引用按映射改写`() {
        val plan = parse(export(snapshot(), TransferScope.CURRENT_TIMETABLE))
        val map = mapOf("ts1" to "ts-local-new")

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
            schemeIdMap = map,
        )

        assertEquals("活动作息要指到本机那套", "ts-local-new", writes.settings?.activeTimeSchemeId)
        assertEquals(
            "课程上的手动覆盖也要跟着改",
            "ts-local-new",
            writes.courses.single().timeSchemeIdOverride,
        )
    }

    // ── 5. 「覆盖」的边界按 scope 收窄（2026-10-30 三修） ────────────
    //
    // 判据源：Dart `_overwrite`（`lib/services/unified_transfer_service.dart:666-676`）——
    // `overwriteUsesMergeSemantics` 为真的 4 个 scope（`transfer_package.dart:44-52`：
    // selected_courses / selected_course / week_timetable / time_template）在「覆盖」下
    // 只更新包边界内的实体；time_template 另走专用分支，只并模板。

    @Test
    fun `时间模板包的覆盖 只并模板 不动课表`() {
        // 这类包不带课程（`buildCurrentPackage(timeTemplate)` 的课程列表恒空），旧版把它当
        // 单课表包落盘，`replaceActiveProfileContent(emptyList(), …)` 直接清空用户课表。
        val plan = parse(export(snapshot(), TransferScope.TIME_TEMPLATE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                courses = listOf(course("c9", "本机课")),
                tasks = listOf(task("task-local", "c9")),
                exams = listOf(exam("exam-local", "c9")),
                scheduleItems = listOf(scheduleItem("item-local")),
            ),
            scope = TransferScope.TIME_TEMPLATE,
        )

        assertEquals("只并模板", listOf("ts1"), writes.timeSchemes.map { it.id })
        assertTrue(
            "内容块整个不该动（宿主靠这个标志跳过 replaceActiveProfileContent）",
            !writes.writesActiveProfileContent,
        )
        assertEquals(emptyList<Course>(), writes.courses)
        assertTrue("当前周也不该被这类包改写", writes.currentWeek == null)
        assertTrue("设置也不该被这类包改写", writes.settings == null)
    }

    @Test
    fun `本周课表包的覆盖 不删本机包外的课`() {
        val plan = parse(export(snapshot(), TransferScope.WEEK_TIMETABLE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                courses = listOf(course("c9", "本机课")),
                tasks = listOf(task("task-local", "c9")),
                exams = listOf(exam("exam-local", "c9")),
                scheduleItems = listOf(scheduleItem("item-local")),
            ),
            scope = TransferScope.WEEK_TIMETABLE,
        )

        assertEquals("本机独有的课不能被删", listOf("c9", "c1"), writes.courses.map { it.id })
        assertEquals("作业同理", listOf("task-local", "task-1"), writes.tasks.map { it.id })
        assertEquals("考试同理", listOf("exam-local", "exam-1"), writes.exams.map { it.id })
        assertTrue("内容块仍要写（只是范围收窄了）", writes.writesActiveProfileContent)
    }

    @Test
    fun `整份课表包的覆盖 仍是整份替换`() {
        val plan = parse(export(snapshot(), TransferScope.CURRENT_TIMETABLE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                courses = listOf(course("c9", "本机课")),
                scheduleItems = listOf(scheduleItem("item-local")),
            ),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals(
            "current_timetable 不是合并语义：本机多出来的课真会被替换掉",
            listOf("c1"),
            writes.courses.map { it.id },
        )
        assertEquals(listOf("item-1"), writes.scheduleItems.map { it.id })
    }

    @Test
    fun `合并模式 日程条目也不删本机独有的`() {
        val plan = parse(export(snapshot(), TransferScope.CURRENT_TIMETABLE))

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.MERGE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                scheduleItems = listOf(scheduleItem("item-local")),
            ),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals("同 id 更新、新 id 追加、缺的不删", listOf("item-local", "item-1"), writes.scheduleItems.map { it.id })
    }

    // ── 夹具 ────────────────────────────────────────────────────────

    private fun export(snapshot: TimetableSnapshot, scope: TransferScope): String {
        val result = DataTransferPackageLogic.build(
            snapshot = snapshot,
            request = TransferPackageRequest(
                scope = scope,
                channel = TransferChannel.FILE,
                packageId = "pkg-round-trip",
                now = now,
            ),
        )
        val success = result as? TransferPackageResult.Success
        assertNotNull("拼包不该失败：$result", success)
        return success!!.json
    }

    private fun parse(json: String): TransferImportPlan {
        val parsed = DataTransferImportLogic.parse(json)
        val valid = parsed as? TransferImportParseResult.Valid
        assertNotNull("导出的包必须能被自己解析回来：$parsed", valid)
        return valid!!.plan
    }

    /** 只有信封、没有任何实体的包（验「空包不动本机」）。 */
    private fun transferEnvelopeOnlyPlan() = TransferImportPlan(
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

    private fun snapshot(): TimetableSnapshot {
        val course = course("c1", "高数").copy(timeSchemeIdOverride = "ts1")
        val profile = TimetableProfile(
            id = "p1",
            name = "大一上",
            courses = listOf(course),
            tasks = listOf(task("task-1", "c1")),
            scheduleItems = listOf(scheduleItem("item-1")),
            exams = listOf(exam("exam-1", "c1")),
            settings = settings(),
            currentWeek = 3L,
            createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
            lastUsedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        )
        return TimetableSnapshot(
            profiles = listOf(profile),
            activeProfileId = "p1",
            courses = listOf(course),
            scheduleItems = listOf(scheduleItem("item-1")),
            scheduleDateRules = listOf(rule("rule-1", "ts1")),
            settings = settings(),
            currentWeek = 3,
            semesterStartEpochDay = java.time.LocalDate.of(2026, 3, 2).toEpochDay(),
            timeSchemes = listOf(timeScheme("ts1", "默认作息")),
            activeTimeSchemeId = "ts1",
        )
    }

    private fun settings() = TimetableSettings.defaults().copy(activeTimeSchemeId = "ts1")

    private fun timeScheme(id: String, name: String) = TimeScheme(
        id = id,
        name = name,
        sections = listOf(
            SectionTime("08:00", "08:45"),
            SectionTime("08:55", "09:40"),
            SectionTime("10:00", "10:45"),
        ),
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun course(id: String, name: String) = Course(
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

    private fun task(id: String, courseId: String?) = CourseTask(
        id = id,
        title = "作业-$id",
        courseId = courseId,
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun exam(id: String, courseId: String) = Exam(
        id = id,
        courseId = courseId,
        name = "考试-$id",
        dateTime = LocalDateTime.of(2026, 6, 20, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun scheduleItem(id: String) = ScheduleItem(
        id = id,
        title = "日程-$id",
        startDate = LocalDateTime.of(2026, 3, 2, 0, 0),
        endDate = LocalDateTime.of(2026, 3, 2, 0, 0),
        startTime = "09:00",
        endTime = "10:00",
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun rule(id: String, schemeId: String) = ScheduleDateRule(
        id = id,
        name = "规则-$id",
        timeSchemeId = schemeId,
        startDate = "2026-03-02",
        endDate = "2026-03-08",
        enabled = true,
    )
}
