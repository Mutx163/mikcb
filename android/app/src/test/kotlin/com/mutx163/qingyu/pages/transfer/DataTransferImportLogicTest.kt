package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * 导入侧模型层单测：解析（含失败码）/ 8 类差分 / 预览弹窗正文。
 *
 * 期望值全部手写：包体是手敲的 JSON（不是从 [DataTransferPackageLogic] 打出来的），
 * 差分是手数的增改删，正文是手拼的换行。任何一处被实现「顺手改好看了」，这里就红。
 */
class DataTransferImportLogicTest {

    // ---------- 手写包体 ----------

    /** 合法的单课表包：1 课 / 1 作业 / 1 考试 / 0 日程 / 1 规则 / 1 作息 / 带设置。 */
    private val singleProfilePackage = """{""" +
        """"app":"mikcb","packageType":"transfer","schemaVersion":1,""" +
        """"packageId":"pkg-in","scope":"current_timetable","channel":"file",""" +
        """"exportedAt":"2026-03-02T08:30:00.000","profileName":"2026 春","currentWeek":3,""" +
        """"settings":{"sections":[{"startTime":"08:00","endTime":"08:45"}],""" +
        """"activeTimeSchemeId":"ts1","semesterWeekCount":16,""" +
        """"semesterStartDateText":"2026-03-02"},""" +
        """"courses":[{"id":"c1","name":"高等数学","teacher":"张老师","location":"A101",""" +
        """"dayOfWeek":1,"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40"}],""" +
        """"tasks":[{"id":"t1","title":"作业一","courseId":"c1",""" +
        """"createdAt":"2026-02-01T00:00:00.000","updatedAt":"2026-02-01T00:00:00.000"}],""" +
        """"scheduleItems":[],""" +
        """"exams":[{"id":"e1","courseId":"c1","name":"期中","dateTime":"2026-04-20T09:00:00.000",""" +
        """"startTime":"09:00","endTime":"11:00",""" +
        """"createdAt":"2026-02-01T00:00:00.000","updatedAt":"2026-02-01T00:00:00.000"}],""" +
        """"timeSchemes":[{"id":"ts1","name":"默认作息","sections":[{"startTime":"08:00",""" +
        """"endTime":"08:45"}],"createdAt":"2026-02-01T00:00:00.000",""" +
        """"updatedAt":"2026-02-01T00:00:00.000"}],""" +
        """"scheduleDateRules":[{"id":"r1","name":"规则一","timeSchemeId":"ts1","enabled":true,""" +
        """"startDate":"2026-03-02","endDate":"2026-03-08"}],""" +
        """"locationTimeGroups":[],"profiles":[]}"""

    /** 合法的全量包：顶层列表全空、一张带 1 门课的档案。 */
    private val fullBackupPackage = """{""" +
        """"app":"mikcb","packageType":"transfer","schemaVersion":1,""" +
        """"packageId":"pkg-full","scope":"all_data","channel":"qr","backupType":"full",""" +
        """"exportedAt":"2026-03-02T08:30:00.000","activeProfileId":"p1",""" +
        """"courses":[],"tasks":[],"scheduleItems":[],"exams":[],"timeSchemes":[],""" +
        """"scheduleDateRules":[],"locationTimeGroups":[],""" +
        """"profiles":[{"id":"p1","name":"2026 春","courses":[{"id":"c9","name":"物理",""" +
        """"teacher":"李老师","location":"B203","dayOfWeek":3,"startSection":3,"endSection":4,""" +
        """"startTime":"10:00","endTime":"11:40"}],"tasks":[],"scheduleItems":[],"exams":[],""" +
        """"settings":{"sections":[{"startTime":"08:00","endTime":"08:45"}],""" +
        """"semesterWeekCount":16},"currentWeek":2,""" +
        """"createdAt":"2026-02-01T00:00:00.000","lastUsedAt":"2026-02-02T00:00:00.000"}]}"""

    private fun valid(result: TransferImportParseResult): TransferImportParseResult.Valid {
        assertTrue("期望 Valid，实际 $result", result is TransferImportParseResult.Valid)
        return result as TransferImportParseResult.Valid
    }

    private fun invalidCode(result: TransferImportParseResult): String {
        assertTrue("期望 Invalid，实际 $result", result is TransferImportParseResult.Invalid)
        return (result as TransferImportParseResult.Invalid).code
    }

    // ---------- 解析：成功路径 ----------

    @Test
    fun `单课表包解析出自述信息与全部实体`() {
        val parsed = valid(DataTransferImportLogic.parse(singleProfilePackage))
        val info = parsed.info
        assertEquals(TransferScope.CURRENT_TIMETABLE, info.scope)
        assertEquals(TransferChannel.FILE, info.channel)
        assertEquals("pkg-in", info.packageId)
        assertTrue(!info.isFullBackup)
        assertEquals("2026 春", info.profileName)
        assertEquals(3, info.currentWeek)
        assertEquals(1, info.courseCount)
        assertEquals(0, info.profileCount)

        val plan = parsed.plan
        assertTrue("单课表包没有档案表", plan.profiles.isEmpty())
        assertNull(plan.activeProfileId)
        assertEquals(listOf("c1"), plan.courses.map { it.id })
        assertEquals("高等数学", plan.courses[0].name)
        assertEquals(listOf("t1"), plan.tasks.map { it.id })
        assertEquals(listOf("e1"), plan.exams.map { it.id })
        assertEquals(listOf("ts1"), plan.timeSchemes.map { it.id })
        assertEquals(listOf("r1"), plan.scheduleDateRules.map { it.id })
        assertTrue(plan.scheduleItems.isEmpty())
        assertEquals(3, plan.currentWeek)

        val settings = plan.settings
        assertTrue("设置必须解析出来", settings != null)
        assertEquals(16, settings!!.semesterWeekCount)
        assertEquals("ts1", settings.activeTimeSchemeId)
        assertEquals(
            "开学日是日历日，解析后是本地零点",
            LocalDate.of(2026, 3, 2).atStartOfDay(),
            settings.semesterStartDate,
        )
    }

    @Test
    fun `全量包按整份档案表解析`() {
        val parsed = valid(DataTransferImportLogic.parse(fullBackupPackage))
        assertEquals(TransferScope.ALL_DATA, parsed.info.scope)
        assertEquals(TransferChannel.QR, parsed.info.channel)
        assertTrue(parsed.info.isFullBackup)
        assertEquals(1, parsed.info.profileCount)
        assertEquals("顶层 0 + 档案内 1", 1, parsed.info.courseCount)
        assertEquals("p1", parsed.plan.activeProfileId)
        assertEquals(1, parsed.plan.profiles.size)
        assertEquals("p1", parsed.plan.profiles[0].id)
        assertEquals("2026 春", parsed.plan.profiles[0].name)
        assertEquals(listOf("c9"), parsed.plan.profiles[0].courses.map { it.id })
        assertEquals(2L, parsed.plan.profiles[0].currentWeek)
        assertTrue("全量包的顶层列表是空的", parsed.plan.courses.isEmpty())
    }

    // ---------- 解析：失败路径（异常一律变码，不许漏给界面）----------

    @Test
    fun `坏 JSON 与坏根节点各报 Dart 的码`() {
        assertEquals("transfer_package_json_invalid", invalidCode(DataTransferImportLogic.parse("{oops")))
        assertEquals("transfer_package_root_invalid", invalidCode(DataTransferImportLogic.parse("[]")))
    }

    @Test
    fun `信封不对时报 transfer_package_type_invalid`() {
        assertEquals(
            "transfer_package_type_invalid",
            invalidCode(DataTransferImportLogic.parse("""{"app":"other","packageType":"x"}""")),
        )
    }

    @Test
    fun `缺课程必填字段时报字段码而不是抛异常`() {
        // course 少了 location：Dart `_validateEntityMap` 按字段顺序报
        // `transfer_course_location_required`。
        val broken = singleProfilePackage.replace(
            """"teacher":"张老师","location":"A101",""",
            """"teacher":"张老师",""",
        )
        assertEquals("transfer_course_location_required", invalidCode(DataTransferImportLogic.parse(broken)))
    }

    // ---------- 差分 ----------

    /**
     * 手数的增删改：
     * - 课程：c1 改名（updated）、新增 c3（added）、丢掉 c2（removed）→ +1/1/1
     * - 作业：新增 t2 → +1/0/0
     * - 其它四类（考试 / 日期规则 / 位置分组 / 日程 / 作息）没动 → 0/0/0
     * - 设置：incoming 是 `current_timetable`（carriesSettings）且两侧都有、内容不同 → 0/1/0
     */
    @Test
    fun `八类差分的顺序与增改删计数按 Dart 口径`() {
        val current = """{"scope":"current_timetable",""" +
            """"settings":{"semesterWeekCount":16},""" +
            """"courses":[{"id":"c1","name":"甲"},{"id":"c2","name":"乙"}],""" +
            """"tasks":[{"id":"t1","title":"作业"}],""" +
            """"scheduleItems":[],"exams":[],"scheduleDateRules":[],"timeSchemes":[],""" +
            """"locationTimeGroups":[],"profiles":[]}"""
        val incoming = """{"scope":"current_timetable",""" +
            """"settings":{"semesterWeekCount":18},""" +
            """"courses":[{"id":"c1","name":"甲改"},{"id":"c3","name":"丙"}],""" +
            """"tasks":[{"id":"t1","title":"作业"},{"id":"t2","title":"新作业"}],""" +
            """"scheduleItems":[],"exams":[],"scheduleDateRules":[],"timeSchemes":[],""" +
            """"locationTimeGroups":[],"profiles":[]}"""

        val summaries = DataTransferImportLogic.diffSummaries(current, incoming)
        assertEquals(
            listOf(
                "courses", "exams", "time_rules", "locations",
                "tasks", "schedule_items", "time_schemes", "settings",
            ),
            summaries.map { it.kind },
        )
        assertEquals(
            listOf(
                Triple(1, 1, 1), // courses
                Triple(0, 0, 0), // exams
                Triple(0, 0, 0), // time_rules
                Triple(0, 0, 0), // locations
                Triple(1, 0, 0), // tasks
                Triple(0, 0, 0), // schedule_items
                Triple(0, 0, 0), // time_schemes
                Triple(0, 1, 0), // settings
            ),
            summaries.map { Triple(it.added, it.updated, it.removed) },
        )
    }

    @Test
    fun `同一份包自比是八个零行`() {
        val summaries = DataTransferImportLogic.diffSummaries(singleProfilePackage, singleProfilePackage)
        assertEquals(8, summaries.size)
        assertTrue(
            "自比必须全零，实际 $summaries",
            summaries.all { it.added == 0 && it.updated == 0 && it.removed == 0 },
        )
    }

    @Test
    fun `键序不同但内容相同的实体不算改动`() {
        val current = """{"scope":"selected_courses","courses":[{"id":"c1","name":"甲",""" +
            """"teacher":"张"}],"profiles":[]}"""
        val incoming = """{"scope":"selected_courses","courses":[{"teacher":"张","name":"甲",""" +
            """"id":"c1"}],"profiles":[]}"""
        val summaries = DataTransferImportLogic.diffSummaries(current, incoming)
        val courses = summaries.first { it.kind == "courses" }
        assertEquals(0, courses.added)
        assertEquals(0, courses.updated)
        assertEquals(0, courses.removed)
    }

    /**
     * 局部范围的包不带设置：即使 incoming 顶部有 `settings` 字段，
     * `scope=selected_courses` 不 carriesSettings ⇒ 设置行恒 `0/0/0`（Dart 同判据）。
     */
    @Test
    fun `局部范围的包不算设置变更`() {
        val current = """{"scope":"selected_courses","settings":{"semesterWeekCount":16}}"""
        val incoming = """{"scope":"selected_courses","settings":{"semesterWeekCount":18}}"""
        val settings = DataTransferImportLogic.diffSummaries(current, incoming)
            .first { it.kind == "settings" }
        assertEquals(Triple(0, 0, 0), Triple(settings.added, settings.updated, settings.removed))
    }

    // ---------- 预览正文 ----------

    private val eightRows = listOf(
        TransferDiffSummary("courses", 1, 1, 1),
        TransferDiffSummary("exams", 0, 0, 0),
        TransferDiffSummary("time_rules", 0, 0, 0),
        TransferDiffSummary("locations", 0, 0, 0),
        TransferDiffSummary("tasks", 1, 0, 0),
        TransferDiffSummary("schedule_items", 0, 0, 0),
        TransferDiffSummary("time_schemes", 0, 0, 0),
        TransferDiffSummary("settings", 0, 1, 0),
    )

    private val eightRowsText = "courses: +1 / ~1 / -1\n" +
        "exams: +0 / ~0 / -0\n" +
        "time_rules: +0 / ~0 / -0\n" +
        "locations: +0 / ~0 / -0\n" +
        "tasks: +1 / ~0 / -0\n" +
        "schedule_items: +0 / ~0 / -0\n" +
        "time_schemes: +0 / ~0 / -0\n" +
        "settings: +0 / ~1 / -0"

    /** 无 merge 时：四段，最后一段整段就是覆盖式汇总（没有 `overwrite:` 前缀）。 */
    @Test
    fun `无备选预览时正文是四段且汇总不带前缀`() {
        val message = DataTransferImportLogic.previewMessage(
            channel = TransferChannel.FILE,
            scope = TransferScope.CURRENT_TIMETABLE,
            packageId = "pkg-in",
            overwrite = eightRows,
        )
        val expected = "你可以覆盖当前课表，或者把备份导入成一个新的独立课表\n\n" +
            "channel=file\n\n" +
            "scope=current_timetable\n\n" +
            "transferId=pkg-in\n\n" +
            eightRowsText
        assertEquals(expected, message)
    }

    /** 有备选时：同一段里并列 `merge:` 与 `overwrite:` 两坨汇总，段间空行。 */
    @Test
    fun `有备选预览时并列 merge 与 overwrite 两段`() {
        val mergeRows = eightRows.map { it.copy(added = 0, updated = 0, removed = 0) }
        val message = DataTransferImportLogic.previewMessage(
            channel = TransferChannel.QR,
            scope = TransferScope.WEEK_TIMETABLE,
            packageId = "pkg-qr",
            overwrite = eightRows,
            merge = mergeRows,
        )
        val mergeText = "courses: +0 / ~0 / -0\n" +
            "exams: +0 / ~0 / -0\n" +
            "time_rules: +0 / ~0 / -0\n" +
            "locations: +0 / ~0 / -0\n" +
            "tasks: +0 / ~0 / -0\n" +
            "schedule_items: +0 / ~0 / -0\n" +
            "time_schemes: +0 / ~0 / -0\n" +
            "settings: +0 / ~0 / -0"
        val expected = "你可以覆盖当前课表，或者把备份导入成一个新的独立课表\n\n" +
            "channel=qr\n\n" +
            "scope=week_timetable\n\n" +
            "transferId=pkg-qr\n\n" +
            "merge:\n" + mergeText + "\n\n" +
            "overwrite:\n" + eightRowsText
        assertEquals(expected, message)
    }

    /** 8 行无条件全输出：全零的一类也必须出现，否则用户会以为那类数据不会被动。 */
    @Test
    fun `全零的类别也照常输出`() {
        val zeros = listOf(
            "courses", "exams", "time_rules", "locations",
            "tasks", "schedule_items", "time_schemes", "settings",
        ).map { TransferDiffSummary(it, 0, 0, 0) }
        val message = DataTransferImportLogic.previewMessage(
            channel = TransferChannel.FILE,
            scope = TransferScope.TIME_TEMPLATE,
            packageId = "p",
            overwrite = zeros,
        )
        assertEquals(8, message.lines().count { it.contains(": +0 / ~0 / -0") })
    }
}
