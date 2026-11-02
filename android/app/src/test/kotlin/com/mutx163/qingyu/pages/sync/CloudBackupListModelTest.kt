package com.mutx163.qingyu.pages.sync

import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云备份列表页模型层测试（源：`lib/screens/cloud_backup_list_screen.dart`、
 * `cloud_backup_ui_helpers.dart`、`lib/services/webdav_sync_service.dart:618-645`）。
 *
 * 期望值全部按 Dart 原文手推，不从实现里抄：
 * - `formatBackupDateTime` = `yyyy-MM-dd HH:mm`（`toLocal()` 之后，补零到分钟）；
 * - `DateTime.tryParse` 失败回落 `fromMillisecondsSinceEpoch(0)`；
 * - `fetchBackupList` 在服务层已按 `exportedAt` 倒序，列表只消费该顺序；
 * - 详情弹窗对「当前版本」不提供删除按钮（Dart `if (!entry.isCurrent)`）。
 */
class CloudBackupListModelTest {

    private val zone: ZoneId = ZoneId.of("Asia/Shanghai")

    private fun entry(
        id: String = "e1",
        exportedAtIso: String = "2026-03-07T09:05:30.000",
        deviceLabel: String = "我的手机",
        isCurrent: Boolean = false,
        source: CloudBackupSource = CloudBackupSource.AUTO,
        profileCount: Int? = 2,
        courseCount: Int? = 30,
    ): CloudBackupEntryModel = CloudBackupEntryModel(
        id = id,
        fileName = "$id.mikcb",
        exportedAtIso = exportedAtIso,
        contentSha256 = "0123456789abcdef",
        deviceId = "device-1",
        deviceLabel = deviceLabel,
        isCurrent = isCurrent,
        source = source,
        profileCount = profileCount,
        courseCount = courseCount,
    )

    // ==========================================
    // 1. 时间格式化
    // ==========================================

    @Test
    fun `导出时间格式化为补零到分钟的本地时间`() {
        assertEquals("2026-03-07 09:05", CloudBackupListLogic.formatBackupDateTime(
            CloudBackupListLogic.parseExportedAtMillis("2026-03-07T09:05:30.000", zone),
            zone,
        ))
        // 1 月 2 日的 3 点 4 分：月/日/时/分都要补零（Dart padLeft(2, '0')）。
        assertEquals("2026-01-02 03:04", CloudBackupListLogic.formatBackupDateTime(
            CloudBackupListLogic.parseExportedAtMillis("2026-01-02T03:04:05.000", zone),
            zone,
        ))
    }

    @Test
    fun `带时区的导出时间换算到本地时区`() {
        // 2026-01-02T03:04:05Z 在 +08:00 是同日 11:04。
        val millis = CloudBackupListLogic.parseExportedAtMillis("2026-01-02T03:04:05Z", zone)
        assertEquals("2026-01-02 11:04", CloudBackupListLogic.formatBackupDateTime(millis, zone))
    }

    @Test
    fun `导出时间解析失败回落纪元零点`() {
        // Dart: DateTime.tryParse(...) ?? DateTime.fromMillisecondsSinceEpoch(0)
        // 纪元毫秒 0 = 1970-01-01T00:00Z，在 +08:00 渲染为 08:00。
        assertEquals(0L, CloudBackupListLogic.parseExportedAtMillis("not-a-date", zone))
        assertEquals(0L, CloudBackupListLogic.parseExportedAtMillis(null, zone))
        assertEquals(0L, CloudBackupListLogic.parseExportedAtMillis("", zone))
        assertEquals(
            "1970-01-01 08:00",
            CloudBackupListLogic.formatBackupDateTime(0L, zone),
        )
    }

    // ==========================================
    // 2. 设备名 / 来源文案
    // ==========================================

    @Test
    fun `设备名称为空时回落到本机`() {
        assertEquals("本机", CloudBackupListLogic.resolveBackupDeviceLabel(""))
        assertEquals("本机", CloudBackupListLogic.resolveBackupDeviceLabel("   "))
        assertEquals("我的手机", CloudBackupListLogic.resolveBackupDeviceLabel("  我的手机  "))
    }

    @Test
    fun `备份来源对应自动备份与手动备份`() {
        assertEquals("自动备份", CloudBackupListLogic.resolveBackupSourceLabel(CloudBackupSource.AUTO))
        assertEquals("手动备份", CloudBackupListLogic.resolveBackupSourceLabel(CloudBackupSource.MANUAL))
    }

    // ==========================================
    // 3. 行标题 / 副标题 / 徽标
    // ==========================================

    @Test
    fun `非当前备份行标题是导出时间且无徽标`() {
        val row = CloudBackupListLogic.buildRow(entry(), zone)
        assertEquals("2026-03-07 09:05", row.title)
        assertNull(row.details)
        assertFalse(row.isCurrent)
    }

    @Test
    fun `当前备份行标题是当前版本且有当前徽标`() {
        val row = CloudBackupListLogic.buildRow(entry(isCurrent = true), zone)
        assertEquals("当前版本", row.title)
        assertEquals("当前", row.details)
        assertTrue(row.isCurrent)
    }

    @Test
    fun `副标题拼接设备与内容摘要`() {
        assertEquals("我的手机 · 2 个课表 · 30 门课程", CloudBackupListLogic.buildSubtitle(entry()))
    }

    @Test
    fun `缺少任一计数时副标题只有设备`() {
        // Dart: profileCount != null && courseCount != null ? summary : null
        assertEquals(
            "我的手机",
            CloudBackupListLogic.buildSubtitle(entry(profileCount = null, courseCount = 30)),
        )
        assertEquals(
            "我的手机",
            CloudBackupListLogic.buildSubtitle(entry(profileCount = 2, courseCount = null)),
        )
    }

    @Test
    fun `空设备名在副标题里也回落本机`() {
        assertEquals("本机 · 0 个课表 · 0 门课程",
            CloudBackupListLogic.buildSubtitle(entry(deviceLabel = " ", profileCount = 0, courseCount = 0)))
    }

    @Test
    fun `详情摘要行仅在两项计数齐全时出现`() {
        val full = CloudBackupListLogic.buildDetail(entry(), zone)
        assertEquals("内容：2 个课表 · 30 门课程", full.summaryLine)
        assertNull(CloudBackupListLogic.buildDetail(entry(courseCount = null), zone).summaryLine)
    }

    // ==========================================
    // 4. 排序（fetchBackupList 的倒序契约）
    // ==========================================

    @Test
    fun `备份按导出时间倒序排列`() {
        val sorted = CloudBackupListLogic.sortByExportedAtDesc(
            listOf(
                entry(id = "old", exportedAtIso = "2026-03-01T08:00:00.000"),
                entry(id = "new", exportedAtIso = "2026-03-09T22:15:00.000"),
                entry(id = "mid", exportedAtIso = "2026-03-05T12:00:00.000"),
            ),
            zone,
        )
        assertEquals(listOf("new", "mid", "old"), sorted.map { it.id })
    }

    // ==========================================
    // 5. 详情动作
    // ==========================================

    @Test
    fun `当前备份详情不给删除动作`() {
        val detail = CloudBackupListLogic.buildDetail(entry(isCurrent = true), zone)
        assertEquals(listOf(CloudBackupDetailAction.RESTORE), detail.actions)
        assertFalse(detail.canDelete)
        // 当前版本标题换成「当前版本」，而不是导出时间。
        assertEquals("当前版本", detail.title)
    }

    @Test
    fun `非当前备份详情可恢复也可删除`() {
        val detail = CloudBackupListLogic.buildDetail(entry(), zone)
        assertEquals(
            listOf(CloudBackupDetailAction.RESTORE, CloudBackupDetailAction.DELETE),
            detail.actions,
        )
        assertTrue(detail.canDelete)
        assertEquals("设备：我的手机", detail.deviceLine)
        assertEquals("来源：自动备份", detail.sourceLine)
    }

    @Test
    fun `删除确认文案带导出时间`() {
        assertEquals(
            "确定删除 2026-03-07 09:05 的云端备份吗？此操作不可撤销",
            CloudBackupListLogic.deleteConfirmMessage(entry(), zone),
        )
    }

    @Test
    fun `恢复预览标题与设为当前版本确认弹框`() {
        assertEquals("恢复到此备份", CloudBackupListLogic.restorePreviewTitle())

        val dialog = CloudBackupListLogic.uploadAsCurrentDialog()
        assertEquals("设为当前云端版本", dialog.title)
        assertEquals("是否将此备份设为当前云端版本？建议开启，可避免其他设备同步冲突", dialog.message)
        assertEquals("设为当前版本", dialog.confirmLabel)
        assertEquals("仅恢复本地", dialog.cancelLabel)
    }

    // ==========================================
    // 6. 整页状态
    // ==========================================

    @Test
    fun `空列表状态`() {
        val state = CloudBackupListLogic.buildListViewState(
            entries = emptyList(),
            isLoading = false,
            isCreatingBackup = false,
            zone = zone,
        )
        assertTrue(state.isEmpty)
        assertEquals("备份版本", state.title)
        assertEquals("立即备份", state.createLabel)
        assertEquals("还没有备份版本", state.emptyText)
        assertFalse(state.isLoading)
        assertTrue(state.rows.isEmpty())
    }

    @Test
    fun `可撤销恢复的显隐与文案透出到渲染层`() {
        val hidden = CloudBackupListLogic.buildListViewState(
            entries = emptyList(),
            isLoading = false,
            isCreatingBackup = false,
            zone = zone,
            canUndoRestore = false,
        )
        assertFalse(hidden.canUndoRestore)

        val shown = CloudBackupListLogic.buildListViewState(
            entries = emptyList(),
            isLoading = false,
            isCreatingBackup = false,
            zone = zone,
            canUndoRestore = true,
        )
        assertTrue(shown.canUndoRestore)
        assertEquals("撤销上次恢复", shown.undoRestoreTitle)
        assertEquals("重启应用后失效", shown.undoRestoreSummary)
        assertEquals("撤销", shown.undoRestoreActionLabel)
    }

    @Test
    fun `加载中状态与创建中状态透出到渲染层`() {
        val state = CloudBackupListLogic.buildListViewState(
            entries = listOf(entry()),
            isLoading = true,
            isCreatingBackup = true,
            zone = zone,
        )
        assertTrue(state.isLoading)
        assertTrue(state.isCreatingBackup)
        assertFalse(state.isEmpty)
        assertEquals(1, state.rows.size)
    }

    // ==========================================
    // 7. JSON 解析（Dart CloudBackupEntry.fromJson 的默认值）
    // ==========================================

    @Test
    fun `缺字段时按 Dart 默认值解析`() {
        val parsed = CloudBackupEntryModel.fromJson(emptyMap())
        assertEquals("", parsed.id)
        assertEquals("", parsed.fileName)
        assertEquals("", parsed.contentSha256)
        assertEquals("", parsed.deviceId)
        assertEquals("", parsed.deviceLabel)
        assertNull(parsed.appVersion)
        assertFalse(parsed.isCurrent)
        assertEquals(CloudBackupSource.AUTO, parsed.source)
        assertNull(parsed.profileCount)
        assertNull(parsed.courseCount)
    }

    @Test
    fun `未知来源回落到自动备份`() {
        assertEquals(
            CloudBackupSource.AUTO,
            CloudBackupEntryModel.fromJson(mapOf("source" to "weekly")).source,
        )
        assertEquals(
            CloudBackupSource.MANUAL,
            CloudBackupEntryModel.fromJson(mapOf("source" to "manual")).source,
        )
    }

    @Test
    fun `计数按数字解析且布尔与字符串原样`() {
        val parsed = CloudBackupEntryModel.fromJson(
            mapOf(
                "id" to "20260307-090530-01234567",
                "exportedAt" to "2026-03-07T09:05:30.000",
                "deviceLabel" to "我的手机",
                "isCurrent" to true,
                "profileCount" to 3,
                "courseCount" to 42.0,
            ),
        )
        assertEquals("20260307-090530-01234567", parsed.id)
        assertEquals("我的手机", parsed.deviceLabel)
        assertTrue(parsed.isCurrent)
        assertEquals(3, parsed.profileCount)
        assertEquals(42, parsed.courseCount)
        // isCurrent=true 时行标题换成「当前版本」（导出时间只在非当前行出现）。
        assertEquals("当前版本", CloudBackupListLogic.buildRow(parsed, zone).title)
        // 缺省 fileName/sha 也能原样落到副标题（设备 + 摘要）。
        assertEquals("我的手机 · 3 个课表 · 42 门课程",
            CloudBackupListLogic.buildRow(parsed, zone).subtitle)
    }
}
