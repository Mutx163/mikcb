package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 单档包解析/组包（源：`lib/services/data_transfer_service.dart` 的
 * `buildBackupJson` / `parseBackupJson` / `isFullBackupJson` 与三处门）。
 *
 * 期望值按 Dart 原文手推，覆盖三类用户真的会遇到的坏文件：
 * **不是 mikcb 文件**、**是整机全量备份**、**课程列表整段坏掉**。
 */
class CouplePartnerPackageTest {

    private fun course(id: String, name: String): String = """
        {"id":"$id","name":"$name","teacher":"张老师","location":"A101","dayOfWeek":1,
         "startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40",
         "startWeek":1,"endWeek":16}
    """.trimIndent()

    private fun packageJson(
        courses: String,
        app: String = "mikcb",
        schemaVersion: Int = 1,
        withSettings: Boolean = true,
        extra: String = "",
    ): String {
        val settings = if (withSettings) "\"settings\":{}," else ""
        return """
            {"app":"$app","packageType":"transfer","schemaVersion":$schemaVersion,
             "packageId":"transfer-1-1","scope":"current_timetable","channel":"file",
             "exportedAt":"2026-10-29T10:00:00.000","profileName":"  小屿  ",
             "currentWeek":3,$settings"courses":[$courses],"tasks":[],
             "scheduleItems":[],"exams":[],"timeSchemes":[],"scheduleDateRules":[],
             "locationTimeGroups":[],"profiles":[]$extra}
        """.trimIndent()
    }

    @Test
    fun parsesSingleProfilePackage() {
        val result = CouplePartnerPackageCodec.parse(
            packageJson("${course("c1", "高数")},${course("c2", "英语")}"),
        )
        assertTrue(result is CouplePartnerParseResult.Ok)
        val pkg = (result as CouplePartnerParseResult.Ok).pkg
        assertEquals(2, pkg.courses.size)
        // Dart `profileName` 会 trim，空白串退回 null（调用方再回落「TA的课表」）。
        assertEquals("小屿", pkg.profileName)
        assertEquals(3L, pkg.currentWeek)
        assertEquals(0, pkg.droppedTotal)
    }

    @Test
    fun rejectsNonJson() {
        val result = CouplePartnerPackageCodec.parse("这不是 JSON")
        assertEquals(
            CouplePartnerPackageCodec.ERR_UNRECOGNIZED,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun rejectsForeignApp() {
        val result = CouplePartnerPackageCodec.parse(packageJson(course("c1", "高数"), app = "other"))
        assertEquals(
            CouplePartnerPackageCodec.ERR_UNRECOGNIZED,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun rejectsUnsupportedSchemaVersion() {
        val result = CouplePartnerPackageCodec.parse(packageJson(course("c1", "高数"), schemaVersion = 2))
        assertEquals(
            CouplePartnerPackageCodec.ERR_UNRECOGNIZED,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun rejectsFullBackupByBackupType() {
        val result = CouplePartnerPackageCodec.parse(
            packageJson(course("c1", "高数"), extra = ",\"backupType\":\"full\""),
        )
        assertEquals(
            CouplePartnerPackageCodec.ERR_REQUIRES_SINGLE_PROFILE,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun rejectsFullBackupByScopeAndProfiles() {
        // 只有 `scope = all_data` 且带 profiles 列表才算整机备份（Dart isFullBackupJson 的第二条）。
        val json = packageJson(course("c1", "高数"))
            .replace("\"scope\":\"current_timetable\"", "\"scope\":\"all_data\"")
            .replace("\"profiles\":[]", "\"profiles\":[{\"id\":\"p1\"}]")
        val result = CouplePartnerPackageCodec.parse(json)
        assertEquals(
            CouplePartnerPackageCodec.ERR_REQUIRES_SINGLE_PROFILE,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun allDataTypeWithProfilesListIsFullBackup() {
        // Dart 的判据是 `profiles is List`——**空列表也算**（`buildTransferPackage` 恒定写这个键）。
        val json = packageJson(course("c1", "高数"))
            .replace("\"scope\":\"current_timetable\"", "\"scope\":\"all_data\"")
        assertEquals(
            CouplePartnerPackageCodec.ERR_REQUIRES_SINGLE_PROFILE,
            (CouplePartnerPackageCodec.parse(json) as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun rejectsMissingCoursesKey() {
        val json = packageJson("").replace("\"courses\":[],", "")
        assertEquals(
            CouplePartnerPackageCodec.ERR_UNRECOGNIZED,
            (CouplePartnerPackageCodec.parse(json) as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun rejectsWhenEveryCourseIsBroken() {
        // 非空列表但一条都解析不出来 ⇒ 整份拒收（Dart `_parseListWithTotalLossGuard`）。
        val result = CouplePartnerPackageCodec.parse(packageJson("""{"oops":true}"""))
        assertEquals(
            CouplePartnerPackageCodec.ERR_UNRECOGNIZED,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun countsPartiallyBrokenCourses() {
        val result = CouplePartnerPackageCodec.parse(
            packageJson("""{"oops":true},${course("c1", "高数")}"""),
        )
        val pkg = (result as CouplePartnerParseResult.Ok).pkg
        assertEquals(1, pkg.courses.size)
        assertEquals(1, pkg.droppedTotal)
    }

    @Test
    fun rejectsMissingSettings() {
        val result = CouplePartnerPackageCodec.parse(
            packageJson(course("c1", "高数"), withSettings = false),
        )
        assertEquals(
            CouplePartnerPackageCodec.ERR_MISSING_SETTINGS,
            (result as CouplePartnerParseResult.Failed).errorCode,
        )
    }

    @Test
    fun buildMineRoundTripsThroughParse() {
        val settings = com.mutx163.qingyu.core.TimetableSettings.defaults()
        val mine = CouplePartnerPackageCodec.buildMine(
            profileName = "我的课表",
            courses = emptyList(),
            tasks = emptyList(),
            scheduleItems = emptyList(),
            settings = settings,
            currentWeek = 5,
            exportedAtIso = "2026-10-29T10:00:00.000",
            packageId = "transfer-1-2",
        )
        val parsed = CouplePartnerPackageCodec.parse(mine)
        assertTrue(parsed is CouplePartnerParseResult.Ok)
        val pkg = (parsed as CouplePartnerParseResult.Ok).pkg
        assertEquals("我的课表", pkg.profileName)
        assertEquals(5L, pkg.currentWeek)
        assertEquals(0, pkg.courses.size)
    }

    @Test
    fun blankProfileNameBecomesNull() {
        // parse 之后调用方要能区分「包里有名字」和「没有名字」，空白一律算没有。
        val json = packageJson(course("c1", "高数")).replace("\"  小屿  \"", "\"   \"")
        val pkg = (CouplePartnerPackageCodec.parse(json) as CouplePartnerParseResult.Ok).pkg
        assertNull(pkg.profileName)
    }
}
