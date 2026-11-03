package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.share.TransferApplyMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云备份「恢复前差异预览」（2026-11-03 接 `previewBackupRestore`）契约测试。
 *
 * ## 它钉的是什么
 *
 * 接预览前 `CloudBackupDetailHost` 点「恢复」直接落盘：用户不知道这份备份比本机
 * 多几门课、少几场考试。现在多出一道「下载 → 解析 → 差异弹窗 → 选模式 → 落盘」的链，
 * 最容易悄悄坏掉的是三处：
 * 1. **预览不落盘**：只读远端字节，绝不碰本机快照文件（落盘是选定模式后的事）；
 * 2. **正文格式**：逐字对 Dart `showTransferPreviewDialog` 的「头信息 + merge/overwrite
 *    两段摘要」格式（用户在两台手机间逐字对数字）；
 * 3. **快照恒全量 ⇒ 不给合并**：与传输页同一条理由（合并服务不存在，点了必然失败）。
 *
 * ## 期望值来源（独立于实现）
 *
 * - Dart `cloud_backup_list_screen.dart:135-178`（`previewBackupRestore` →
 *   `showTransferPreviewDialog` → `applyPreviewedBackupRestore`）；
 * - `DataTransferImportLogic.previewMessage` 的逐字格式（`merge:`/`overwrite:` 段）；
 * - `DataTransferApplyLogic.isFullBackupPlan`（profiles 非空 ⇒ 全量 ⇒ 不给合并）。
 */
class CloudBackupRestorePreviewTest {

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

    /** 连上 + 造一条远端历史备份。index 缺失 → 从 listing 重建，体必须是合法快照。 */
    private fun connected(transport: FakeRemoteTransport): CloudSyncController {
        val controller = controller(transport = transport)
        controller.connect("me@example.com", "pw")
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] =
            buildSyncSnapshotBytes(profileId = "p1")
        controller.refreshBackups()
        return controller
    }

    // ---------- 预览 ----------

    @Test
    fun `预览成功_返回载荷且不落盘`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore()
        val controller = CloudSyncController(
            store = FakeConfigStore(),
            snapshotStore = snapshotStore,
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
        )
        controller.connect("me@example.com", "pw")
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] =
            buildSyncSnapshotBytes(profileId = "p1")
        controller.refreshBackups()
        val writesBefore = snapshotStore.writeCount

        val preview = controller.previewBackupRestore("2026-03-06.mikcb")

        assertNotNull("预览应返回载荷，lastErrorCode=${controller.lastErrorCode}", preview)
        // 只读：本机快照文件一个字节都不许动（落盘是选定模式后的事）。
        assertEquals("预览阶段绝不能写本机快照", writesBefore, snapshotStore.writeCount)
    }

    @Test
    fun `预览正文含channel_cloud与scope_all_data`() {
        val controller = connected(FakeRemoteTransport())

        val preview = controller.previewBackupRestore("2026-03-06.mikcb")

        assertNotNull(preview)
        assertTrue(
            "正文应含 channel=cloud（Dart `TransferChannel.cloud`），实际=${preview!!.message}",
            preview.message.contains("channel=cloud"),
        )
        assertTrue(
            "正文应含 scope=all_data（快照恒全量），实际=${preview.message}",
            preview.message.contains("scope=all_data"),
        )
    }

    @Test
    fun `预览正文含courses与settings摘要行`() {
        val controller = connected(FakeRemoteTransport())

        val preview = controller.previewBackupRestore("2026-03-06.mikcb")!!

        // 无 merge 时最后一段整段就是 overwrite 汇总（Dart 同格式）；
        // 行格式 = `kind: +added / ~updated / -removed`（DataTransferLogic.diffSummaryLine）。
        // 八行全输出是冻结契约（缺一行用户就以为那类数据不会被动）——挑两条最常被读的行钉住。
        assertTrue(
            "应含 courses 摘要行，实际=${preview.message}",
            preview.message.lines().any { it.startsWith("courses:") },
        )
        assertTrue(
            "应含 settings 摘要行，实际=${preview.message}",
            preview.message.lines().any { it.startsWith("settings:") },
        )
    }

    @Test
    fun `快照恒全量_canMerge恒false`() {
        val controller = connected(FakeRemoteTransport())

        val preview = controller.previewBackupRestore("2026-03-06.mikcb")!!

        // 与传输页「全量包不摆合并按钮」同一条理由：合并服务不存在，点了必然失败。
        assertTrue("快照恒是全量包，canMerge 必须 false", !preview.canMerge)
    }

    @Test
    fun `未连接时预览回null_不崩`() {
        val controller = controller()

        assertNull(controller.previewBackupRestore("2026-03-06.mikcb"))
    }

    @Test
    fun `不存在的entryId预览回null`() {
        val controller = connected(FakeRemoteTransport())

        assertNull(controller.previewBackupRestore("不存在.mikcb"))
    }

    @Test
    fun `预览失败写lastErrorCode_不落脏数据`() {
        val transport = FakeRemoteTransport()
        transport.getResultOverride = com.mutx163.qingyu.sync.GetBytesResult.failed("network")
        val controller = connected(transport)

        val preview = controller.previewBackupRestore("2026-03-06.mikcb")

        assertNull(preview)
        assertEquals("network", controller.lastErrorCode)
    }

    @Test
    fun `损坏快照预览回null_错误码是人话安全码`() {
        val transport = FakeRemoteTransport()
        transport.getResultOverride = null
        val controller = connected(transport)
        // 把体换成垃圾：downloadSnapshot 的信封门会拦，预览这层同样要拦。
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] = "not-json".toByteArray()

        val preview = controller.previewBackupRestore("2026-03-06.mikcb")

        assertNull(preview)
        val code = controller.lastErrorCode
        assertTrue(
            "lastErrorCode 期望是原始诊断码或 null，实际=$code",
            code == null || code.none { it.code > 127 },
        )
    }

    // ---------- 按预览落盘 ----------

    @Test
    fun `选定覆盖模式落盘回DOWNLOADED_列表仍可读`() {
        val transport = FakeRemoteTransport()
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] =
            buildSyncSnapshotBytes(profileId = "pRemote")
        val controller = connected(transport)
        val preview = controller.previewBackupRestore("2026-03-06.mikcb")!!

        val kind = controller.applyPreviewedBackupRestore(preview, TransferApplyMode.OVERWRITE)

        assertEquals(SyncResultKind.DOWNLOADED, kind)
        assertTrue(controller.backupListViewState().rows.isNotEmpty())
    }

    @Test
    fun `选定模式后撤销点已就位`() {
        val transport = FakeRemoteTransport()
        transport.files["/Apps/qingyu-sync/history/2026-03-06.mikcb"] =
            buildSyncSnapshotBytes(profileId = "pRemote")
        // 撤销点 = 恢复前快照 + 可写回的落点（`effectiveSnapshotApplier`）；
        // 缺 applier 时 openBackup 成功也不留撤销点（控制器类注释明写）。
        val controller = CloudSyncController(
            store = FakeConfigStore(),
            snapshotStore = FakeLocalSnapshotStore(),
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
            snapshotProvider = { SnapshotBuildResult.Success(buildSyncSnapshotBytes(profileId = "pBefore")) },
            snapshotApplier = { SnapshotApplyResult.Applied },
        )
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()
        val preview = controller.previewBackupRestore("2026-03-06.mikcb")!!

        controller.applyPreviewedBackupRestore(preview, TransferApplyMode.OVERWRITE)

        assertTrue("恢复成功后撤销点必须就位", controller.canUndoLastRestore)
    }
}
