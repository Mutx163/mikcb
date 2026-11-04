package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F12（半接收尾）· 云备份「详情 → 恢复 / 删除」接线契约测试。
 *
 * ## 它钉的是什么
 *
 * 接线前这两个页面的 `onOpenBackup` 是 `Toast("备份详情尚未开放")`：假入口。
 * 修好之后用户能点开详情、能恢复、能删除。**最容易悄悄坏掉的是「查找口径」**：
 * 列表行的 `entryId` 与远端文件名是不是同一套匹配？如果恢复与删除各写一套，
 * 就会出现「能恢复但删不掉」——只有真连过 WebDAV 才看得见，单测必须钉住。
 *
 * ## 期望值来源（独立于实现）
 *
 * - Dart `cloud_backup_list_screen.dart:111` `_openBackupDetail` → 三个动作 restore/delete；
 * - Dart `:218` `_deleteBackup`：删成功后刷新列表；失败提示带原因；
 * - 本仓 `WebdavRemoteTransport.deleteRemoteFile` 的返回值语义（204 成功 / 404 幂等）。
 */
class CloudBackupDetailWiringTest {

    private fun controller(
        transport: FakeRemoteTransport = FakeRemoteTransport(),
        store: FakeConfigStore = FakeConfigStore(),
    ): CloudSyncController = CloudSyncController(
        store = store,
        snapshotStore = FakeLocalSnapshotStore(),
        transportFactory = { _, _ -> transport },
        deviceLabel = "测试机",
        clock = { "2026-03-07T09:05:00+08:00" },
    )

    /** 连上 + 造一条远端历史备份，返回控制器。index 缺失 → 从 listing 重建，体必须是合法快照。 */
    private fun connected(transport: FakeRemoteTransport): CloudSyncController {
        val controller = controller(transport = transport)
        controller.connect("me@example.com", "pw")
        // 历史备份落在 history/ 下：listHistoryBackupFiles 会把它当候选条目。
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] = buildSyncSnapshotBytes(profileId = "p1")
        controller.refreshBackups()
        return controller
    }

    @Test
    fun `按entryId能取到条目_详情三行才画得出来`() {
        val transport = FakeRemoteTransport()
        val controller = connected(transport)
        val row = controller.backupListViewState().rows.first()

        val entry = controller.backupEntry(row.entryId)

        // 取不到 ⇒ 详情弹层会静默不显示（用户点了没反应），所以这条必须绿。
        assertTrue("按 entryId 取不到条目", entry != null)
        val detail = CloudBackupListLogic.buildDetail(entry!!)
        assertEquals(row.entryId, detail.entryId)
        assertTrue(detail.deviceLine.isNotEmpty())
        assertTrue(detail.sourceLine.isNotEmpty())
    }

    @Test
    fun `不存在的entryId回null_不抛异常`() {
        val controller = connected(FakeRemoteTransport())
        assertNull(controller.backupEntry("不存在的备份"))
    }

    @Test
    fun `删除成功_远端少一条且回BACKUP_DELETED`() {
        val transport = FakeRemoteTransport()
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] = buildSyncSnapshotBytes(profileId = "p1")
        transport.files["/Apps/qingyu-sync/history/2026-03-05.mikcb"] = buildSyncSnapshotBytes(profileId = "p2")
        val controller = connected(transport)

        val kind = controller.deleteBackup("2026-03-06.mikcb")

        assertEquals(SyncResultKind.BACKUP_DELETED, kind)
        // 真删了：远端少了这条。
        assertTrue(transport.files.keys.none { it.endsWith("2026-03-06.mikcb") })
        // 刷新后的列表只剩另一条。
        assertEquals(
            listOf("2026-03-05.mikcb"),
            controller.backupListViewState().rows.map { it.entryId },
        )
    }

    @Test
    fun `删除不存在的条目回FAILED_不静默成功`() {
        val controller = connected(FakeRemoteTransport())

        val kind = controller.deleteBackup("2026-01-01.mikcb")

        assertEquals(SyncResultKind.FAILED, kind)
        // Dart `deleteBackup` 查不到条目抛 `backup_not_found`，不能落成泛化「同步失败」。
        assertEquals("backup_not_found", controller.lastErrorCode)
    }

    @Test
    fun `未连接时删除回FAILED_不崩`() {
        val controller = controller()

        assertEquals(SyncResultKind.FAILED, controller.deleteBackup("2026-03-06.mikcb"))
        // Dart `buildConnectionParams == null` → `missing_credentials`。
        assertEquals("missing_credentials", controller.lastErrorCode)
    }

    @Test
    fun `删除失败提示带本地化原因`() {
        // 与渲染侧同一套映射：FAILED + 错误码 ⇒ 错误样式提示，不是「删除成功」。
        val toast = SyncResultToasts.forDeleteBackup(SyncResultKind.FAILED, "network")

        assertTrue(toast.isError)
        assertTrue(toast.message.isNotEmpty())
    }

    @Test
    fun `删除成功提示不是错误样式`() {
        val toast = SyncResultToasts.forDeleteBackup(SyncResultKind.BACKUP_DELETED, null)

        assertTrue(!toast.isError)
        assertTrue(toast.reloadBackups)
    }

    @Test
    fun `lastErrorCode开出来的是原始码_不是人话句子`() {
        // 渲染侧把码交给 `forRestore/forDeleteBackup` 再本地化一次；
        // 这里给成已本地化的句子会被二次包装成「恢复失败：恢复失败：…」。
        val transport = FakeRemoteTransport()
        val controller = controller(transport = transport)
        controller.connect("me@example.com", "pw")

        // 没有远端文件 ⇒ openBackup 直接 FAILED，且不该写入一个「看起来像人话」的码。
        controller.openBackup("不存在.mikcb")

        val code = controller.lastErrorCode
        assertTrue(
            "lastErrorCode 期望是原始诊断码或 null，实际=$code",
            code == null || code.none { it.code > 127 },
        )
    }

    @Test
    fun `恢复成功回DOWNLOADED_列表仍可读`() {
        val transport = FakeRemoteTransport()
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] = buildSyncSnapshotBytes(profileId = "pRemote")
        val controller = connected(transport)

        val kind = controller.openBackup("2026-03-06.mikcb")

        assertEquals(SyncResultKind.DOWNLOADED, kind)
        assertTrue(controller.backupListViewState().rows.isNotEmpty())
    }
}
