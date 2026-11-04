package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 旧格式兼容解析（Dart `DataTransferService.parseCompatible` / `parseBackupJson` /
 * `parseFullBackupJson`）。
 *
 * 这些用例钉的是 2026-11-03 补上的那条通道：Kotlin 原先只认当前信封，
 * `unrecognized_mikcb_data_file` / `missing_settings_data` /
 * `unrecognized_mikcb_full_backup` / `missing_full_backup_data` 四个已注册错误码
 * 从来没有产出过。期望码与 Dart 逐字一致（`lib/services/data_transfer_service.dart:228-409`）。
 */
class DataTransferLegacyBackupLogicTest {

    // ---------- 手写旧档 ----------

    private val courseJson = """{"id":"c1","name":"高等数学","teacher":"张老师","location":"A101",""" +
        """"dayOfWeek":1,"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40"}"""

    private val courseJson2 = """{"id":"c2","name":"线性代数","teacher":"王老师","location":"B202",""" +
        """"dayOfWeek":2,"startSection":3,"endSection":4,"startTime":"10:00","endTime":"11:40"}"""

    private val settingsJson = """{"sections":[{"startTime":"08:00","endTime":"08:45"}],""" +
        """"activeTimeSchemeId":"ts1","semesterWeekCount":16,""" +
        """"semesterStartDateText":"2026-03-02"}"""

    private val schemeJson = """{"id":"ts1","name":"默认作息","sections":[{"startTime":"08:00",""" +
        """"endTime":"08:45"}],"createdAt":"2026-02-01T00:00:00.000",""" +
        """"updatedAt":"2026-02-01T00:00:00.000"}"""

    private val profileJson = """{"id":"p1","name":"2026 春","courses":[$courseJson],""" +
        """"tasks":[],"scheduleItems":[],"exams":[],"settings":$settingsJson,"currentWeek":2,""" +
        """"createdAt":"2026-02-01T00:00:00.000","lastUsedAt":"2026-02-02T00:00:00.000"}"""

    /** 旧版单课表备份：无 packageType、无 tasks/exams 等键、无 8 张必填列表。 */
    private fun legacySingle(
        currentWeek: Int = 5,
        courses: String = "[$courseJson,$courseJson2]",
        includeSettings: Boolean = true,
    ): String = """{"app":"mikcb","schemaVersion":1,"packageId":"old-1",""" +
        """"profileName":"旧档","currentWeek":$currentWeek,""" +
        (if (includeSettings) """"settings":$settingsJson,""" else "") +
        """"courses":$courses}"""

    /** 旧版全量备份：`backupType: full` + profiles + timeSchemes。 */
    private fun legacyFull(
        profiles: String = "[$profileJson]",
        timeSchemes: String? = "[$schemeJson]",
    ): String = """{"app":"mikcb","schemaVersion":1,"backupType":"full","packageId":"old-full",""" +
        """"activeProfileId":"p1","channel":"qr","profiles":$profiles,""" +
        (if (timeSchemes == null) "" else """"timeSchemes":$timeSchemes,""") +
        """"scheduleDateRules":[],"locationTimeGroups":[]}"""

    private fun valid(result: TransferImportParseResult): TransferImportParseResult.Valid {
        assertTrue("期望 Valid，实际 $result", result is TransferImportParseResult.Valid)
        return result as TransferImportParseResult.Valid
    }

    private fun invalidCode(result: TransferImportParseResult): String {
        assertTrue("期望 Invalid，实际 $result", result is TransferImportParseResult.Invalid)
        return (result as TransferImportParseResult.Invalid).code
    }

    // ---------- 旧单课表档 ----------

    @Test
    fun `旧单课表档缺信封也能导入`() {
        val parsed = valid(DataTransferLegacyBackupLogic.parseCompatible(legacySingle()))
        assertEquals(TransferScope.CURRENT_TIMETABLE, parsed.info.scope)
        assertEquals(TransferChannel.FILE, parsed.info.channel)
        assertEquals("old-1", parsed.info.packageId)
        assertEquals(listOf("c1", "c2"), parsed.plan.courses.map { it.id })
        assertEquals(5, parsed.plan.currentWeek)
        assertEquals(5, parsed.info.currentWeek)
        assertEquals(0, parsed.info.droppedTotal)
        assertTrue(parsed.plan.profiles.isEmpty())
    }

    @Test
    fun `通道覆盖按实际入口记（二维码导入旧档）`() {
        val parsed = valid(
            DataTransferLegacyBackupLogic.parseCompatible(legacySingle(), TransferChannel.QR),
        )
        assertEquals(TransferChannel.QR, parsed.info.channel)
    }

    @Test
    fun `部分坏条目逐条跳过并计数`() {
        val parsed = valid(
            DataTransferLegacyBackupLogic.parseCompatible(
                legacySingle(courses = "[$courseJson,\"broken\",3]"),
            ),
        )
        assertEquals(listOf("c1"), parsed.plan.courses.map { it.id })
        assertEquals(2, parsed.info.droppedCounts["courses"])
        assertEquals(2, parsed.info.droppedTotal)
    }

    @Test
    fun `课程整表全坏时拒收而不是清空课表`() {
        assertEquals(
            "unrecognized_mikcb_data_file",
            invalidCode(
                DataTransferLegacyBackupLogic.parseCompatible(
                    legacySingle(courses = "[\"broken\",3]"),
                ),
            ),
        )
    }

    @Test
    fun `课程键缺失时拒收`() {
        val text = """{"app":"mikcb","schemaVersion":1,"packageId":"old-1",""" +
            """"profileName":"旧档","currentWeek":5,"settings":$settingsJson}"""
        assertEquals(
            "unrecognized_mikcb_data_file",
            invalidCode(DataTransferLegacyBackupLogic.parseCompatible(text)),
        )
    }

    @Test
    fun `缺 settings 时报 missing_settings_data`() {
        assertEquals(
            "missing_settings_data",
            invalidCode(
                DataTransferLegacyBackupLogic.parseCompatible(legacySingle(includeSettings = false)),
            ),
        )
    }

    @Test
    fun `schemaVersion 不符时报 unrecognized_mikcb_data_file`() {
        val text = legacySingle().replace("\"schemaVersion\":1", "\"schemaVersion\":2")
        assertEquals(
            "unrecognized_mikcb_data_file",
            invalidCode(DataTransferLegacyBackupLogic.parseCompatible(text)),
        )
    }

    @Test
    fun `当前周先夹到 1 至 30 再按学期周数收敛`() {
        assertEquals(
            1,
            valid(DataTransferLegacyBackupLogic.parseCompatible(legacySingle(currentWeek = 0)))
                .plan.currentWeek,
        )
        assertEquals(
            16,
            valid(DataTransferLegacyBackupLogic.parseCompatible(legacySingle(currentWeek = 99)))
                .plan.currentWeek,
        )
    }

    // ---------- 旧全量备份 ----------

    @Test
    fun `旧全量备份解析成整份档案表`() {
        val parsed = valid(DataTransferLegacyBackupLogic.parseCompatible(legacyFull()))
        assertTrue(parsed.info.isFullBackup)
        assertEquals(TransferScope.ALL_DATA, parsed.info.scope)
        assertEquals(1, parsed.info.profileCount)
        assertEquals(1, parsed.info.courseCount)
        assertEquals(listOf("p1"), parsed.plan.profiles.map { it.id })
        assertEquals(listOf("ts1"), parsed.plan.timeSchemes.map { it.id })
        assertEquals("p1", parsed.plan.activeProfileId)
        assertNull("全量备份不带顶层设置", parsed.plan.settings)
    }

    @Test
    fun `全量备份容器条目变少时整份拒收`() {
        assertEquals(
            "missing_full_backup_data",
            invalidCode(
                DataTransferLegacyBackupLogic.parseCompatible(
                    legacyFull(profiles = "[$profileJson,\"broken\"]"),
                ),
            ),
        )
    }

    @Test
    fun `全量备份缺 timeSchemes 键时整份拒收`() {
        assertEquals(
            "missing_full_backup_data",
            invalidCode(DataTransferLegacyBackupLogic.parseCompatible(legacyFull(timeSchemes = null))),
        )
    }

    @Test
    fun `全量备份 backupType 不符时报 unrecognized_mikcb_full_backup`() {
        // `backupType: full` 才会进全量分支；改成 current 后走单课表旧档分支，
        // 又因为没有 courses 键而拒收——这里直接构造「声明 full 但 app 不对」。
        val text = legacyFull().replace("\"app\":\"mikcb\"", "\"app\":\"other\"")
        assertEquals(
            "unrecognized_mikcb_full_backup",
            invalidCode(DataTransferLegacyBackupLogic.parseCompatible(text)),
        )
    }

    // ---------- 信封 fail closed ----------

    @Test
    fun `坏信封绝不回退到旧格式`() {
        // 信封（app + packageType）成立但缺 scope：严格解析报 transfer_scope_required，
        // 不能因为「courses 都在」被旧通道当成旧档救回（Dart `parseCompatible` 同）。
        val text = """{"app":"mikcb","packageType":"transfer","schemaVersion":1,""" +
            """"packageId":"p","channel":"file","exportedAt":"2026-03-02T08:30:00.000",""" +
            """"courses":[$courseJson],"tasks":[],"scheduleItems":[],"exams":[],""" +
            """"timeSchemes":[],"scheduleDateRules":[],"locationTimeGroups":[],"profiles":[],""" +
            """"settings":$settingsJson}"""
        assertEquals(
            "transfer_scope_required",
            invalidCode(DataTransferLegacyBackupLogic.parseCompatible(text)),
        )
    }

    @Test
    fun `当前信封照旧走严格解析`() {
        val text = """{"app":"mikcb","packageType":"transfer","schemaVersion":1,""" +
            """"packageId":"p","scope":"current_timetable","channel":"file",""" +
            """"exportedAt":"2026-03-02T08:30:00.000","profileName":"2026 春","currentWeek":3,""" +
            """"settings":$settingsJson,""" +
            """"courses":[$courseJson],"tasks":[],"scheduleItems":[],"exams":[],""" +
            """"timeSchemes":[],"scheduleDateRules":[],"locationTimeGroups":[],"profiles":[]}"""
        val parsed = valid(DataTransferLegacyBackupLogic.parseCompatible(text, TransferChannel.LAN))
        assertEquals(TransferChannel.LAN, parsed.info.channel)
        assertEquals(0, parsed.info.droppedTotal)
    }
}
