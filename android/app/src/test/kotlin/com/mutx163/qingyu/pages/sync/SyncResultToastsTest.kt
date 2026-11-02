package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 同步/备份结果 → 屏上提示（toast）映射测试。
 *
 * 期望值按 Dart 原文手推（`cloud_sync_screen.dart` / `cloud_backup_list_screen.dart`）：
 * - 手动同步：cancelled 另给「以本机为准备份」直达动作；failed 走本地化；
 *   其余未知种类落到「本地与云端已一致」；
 * - 立即备份：`backupCreated` 与 `uploaded` 都算成功；
 * - 恢复成功带「撤销」动作；恢复失败/删除失败/备份失败都是「前缀 + 本地化原因」；
 * - 撤销失败时 Dart **不本地化**，直接把原文 `Undo failed` 拼进「恢复失败：{message}」。
 */
class SyncResultToastsTest {

    @Test
    fun `同步上传与下载成功后刷新备份列表`() {
        val uploaded = SyncResultToasts.forSyncNow(SyncResultKind.UPLOADED, null)
        assertEquals("已上传到云端", uploaded.message)
        assertFalse(uploaded.isError)
        assertTrue(uploaded.reloadBackups)
        assertNull(uploaded.actionLabel)

        val downloaded = SyncResultToasts.forSyncNow(SyncResultKind.DOWNLOADED, null)
        assertEquals("已从云端恢复", downloaded.message)
        assertTrue(downloaded.reloadBackups)
    }

    @Test
    fun `同步未变化不刷新备份列表`() {
        val toast = SyncResultToasts.forSyncNow(SyncResultKind.UP_TO_DATE, null)
        assertEquals("本地与云端已一致", toast.message)
        assertFalse(toast.isError)
        assertFalse(toast.reloadBackups)
    }

    @Test
    fun `取消同步给出以本机为准备份的直达动作`() {
        val toast = SyncResultToasts.forSyncNow(SyncResultKind.CANCELLED, null)
        assertEquals("已取消同步", toast.message)
        assertEquals("以本机为准备份", toast.actionLabel)
        // Dart 这里用的是 success 样式。
        assertFalse(toast.isError)
        assertFalse(toast.reloadBackups)
    }

    @Test
    fun `同步失败把错误码本地化后拼进文案`() {
        val toast = SyncResultToasts.forSyncNow(SyncResultKind.FAILED, "auth_failed")
        assertEquals("同步失败：账号或密码错误", toast.message)
        assertTrue(toast.isError)
        assertFalse(toast.reloadBackups)
    }

    @Test
    fun `同步失败无错误码时原因仍是同步失败`() {
        assertEquals("同步失败：同步失败", SyncResultToasts.forSyncNow(SyncResultKind.FAILED, null).message)
    }

    @Test
    fun `未知同步结果按本地与云端已一致处理`() {
        // Dart `_ => l10n.cloudSyncResultUpToDate`（含 backupDeleted 这类不该出现的种类）。
        assertEquals(
            "本地与云端已一致",
            SyncResultToasts.forSyncNow(SyncResultKind.BACKUP_DELETED, null).message,
        )
        assertEquals(
            "本地与云端已一致",
            SyncResultToasts.forSyncNow(SyncResultKind.UNKNOWN, null).message,
        )
    }

    @Test
    fun `立即备份的两种成功种类都算成功`() {
        for (kind in listOf(SyncResultKind.BACKUP_CREATED, SyncResultKind.UPLOADED)) {
            val toast = SyncResultToasts.forCreateBackup(kind, null)
            assertEquals("备份已保存到云端", toast.message)
            assertFalse(toast.isError)
            assertTrue(toast.reloadBackups)
        }
    }

    @Test
    fun `立即备份失败带本地化原因`() {
        val toast = SyncResultToasts.forCreateBackup(SyncResultKind.FAILED, "connection_timeout")
        assertEquals("备份失败：连接超时", toast.message)
        assertTrue(toast.isError)
        assertFalse(toast.reloadBackups)
    }

    @Test
    fun `立即备份的其他结果种类算失败`() {
        // Dart：succeeded = kind == backupCreated || uploaded；其余一律失败提示。
        val toast = SyncResultToasts.forCreateBackup(SyncResultKind.UP_TO_DATE, null)
        assertEquals("备份失败：同步失败", toast.message)
        assertTrue(toast.isError)
    }

    @Test
    fun `删除备份成功后刷新列表`() {
        val toast = SyncResultToasts.forDeleteBackup(SyncResultKind.BACKUP_DELETED, null)
        assertEquals("备份已删除", toast.message)
        assertFalse(toast.isError)
        assertTrue(toast.reloadBackups)
    }

    @Test
    fun `删除备份失败带本地化原因`() {
        val toast = SyncResultToasts.forDeleteBackup(SyncResultKind.FAILED, "backup_not_found")
        assertEquals("删除失败：备份不存在", toast.message)
        assertTrue(toast.isError)
        assertFalse(toast.reloadBackups)
    }

    @Test
    fun `恢复成功带撤销动作并刷新列表`() {
        val toast = SyncResultToasts.forRestore(applied = true, errorCode = null)
        assertEquals("已恢复到此备份", toast.message)
        assertEquals("撤销", toast.actionLabel)
        assertFalse(toast.isError)
        assertTrue(toast.reloadBackups)
    }

    @Test
    fun `恢复失败带本地化原因`() {
        val toast = SyncResultToasts.forRestore(applied = false, errorCode = "missing_backup_snapshot")
        assertEquals("恢复失败：备份缺失", toast.message)
        assertTrue(toast.isError)
        assertNull(toast.actionLabel)
    }

    @Test
    fun `撤销恢复成功与失败`() {
        val ok = SyncResultToasts.forUndoRestore(success = true)
        // 成功文案不能再复用「已恢复到此备份」——那会把撤销说成恢复。
        assertEquals("已撤销恢复", ok.message)
        assertFalse(ok.isError)
        assertTrue(ok.reloadBackups)

        val failed = SyncResultToasts.forUndoRestore(success = false, errorCode = "sync_snapshot_apply_failed")
        // 原生页把失败原因本地化；未知码落到「同步失败」。
        assertEquals("撤销失败：同步失败", failed.message)
        assertTrue(failed.isError)
        assertFalse(failed.reloadBackups)

        // 没有错误码时也要给出完整的失败句，不出现空的占位符。
        assertEquals(
            "撤销失败：同步失败",
            SyncResultToasts.forUndoRestore(success = false, errorCode = null).message,
        )
    }

    @Test
    fun `配置读取失败与地址非法都是错误提示`() {
        val loadFailed = SyncResultToasts.forConfigLoadFailed()
        assertEquals("云同步设置读取失败，请重新输入应用专用密码", loadFailed.message)
        assertTrue(loadFailed.isError)

        val invalid = SyncResultToasts.forBaseUrlInvalid()
        assertEquals("WebDAV 地址必须以 http:// 或 https:// 开头", invalid.message)
        assertTrue(invalid.isError)
    }

    @Test
    fun `测试连接的成败提示`() {
        assertEquals("WebDAV 连接成功", SyncResultToasts.forTestConnection(true).message)
        assertFalse(SyncResultToasts.forTestConnection(true).isError)
        assertEquals("WebDAV 连接失败，请检查账号、应用密码和网络",
            SyncResultToasts.forTestConnection(false).message)
        assertTrue(SyncResultToasts.forTestConnection(false).isError)
    }
}
