package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.WebdavSyncConfig
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 两步恢复（prepare → confirm）的控制器行为单测：
 *
 * 1. prepare（预览）返回差异概要且**零副作用**——不写本机快照文件、不写课表仓储；
 * 2. confirm（应用）把 prepare 缓存的字节原样写回，撤销点随之出现、可见性联动；
 * 3. 没有准备 / 已丢弃 / 已断开时 confirm 直接失败，绝不误写。
 */
class CloudRestorePrepareTest {

    private val config = WebdavSyncConfig()

    // ── 数据构造（MiniJson 编解码往返，与真实快照读取路径同构） ──

    private fun course(id: String, name: String = "课程$id"): Map<String, Any?> =
        linkedMapOf("id" to id, "name" to name)

    private fun scheme(id: String): Map<String, Any?> = linkedMapOf("id" to id, "name" to "作息$id")

    private fun snapshotPayload(
        profiles: List<Map<String, Any?>>,
        timeSchemes: List<Map<String, Any?>> = listOf(scheme("t1")),
    ): Map<String, Any?> = linkedMapOf(
        "app" to "mikcb",
        "schemaVersion" to 2,
        "backupType" to "sync",
        "exportedAt" to "2026-03-07T09:05:00.000",
        "deviceId" to "devA",
        "profiles" to profiles,
        "timeSchemes" to timeSchemes,
    )

    private fun bytes(payload: Map<String, Any?>): ByteArray =
        MiniJson.encode(payload).toByteArray(Charsets.UTF_8)

    private fun profile(id: String, vararg courses: Map<String, Any?>): Map<String, Any?> =
        linkedMapOf("id" to id, "courses" to courses.toList())

    /** 记录 applier 收到的字节（confirm 是否把预览字节原样交给了仓储）。 */
    private class ApplierSpy : (ByteArray) -> SnapshotApplyResult {
        val applied = ArrayList<ByteArray>()
        var failWith: String? = null
        override fun invoke(bytes: ByteArray): SnapshotApplyResult {
            applied.add(bytes)
            return failWith?.let { SnapshotApplyResult.Failed(it) } ?: SnapshotApplyResult.Applied
        }
    }

    // ── 控制器装配 ──

    private fun controller(
        transport: FakeRemoteTransport = FakeRemoteTransport(),
        snapshotStore: FakeLocalSnapshotStore = FakeLocalSnapshotStore(),
        snapshotProvider: (() -> SnapshotBuildResult)? = null,
        applier: ApplierSpy? = null,
        undoStore: CloudSyncUndoStore = CloudSyncUndoStore(),
    ): CloudSyncController {
        val spy = applier
        return CloudSyncController(
            store = FakeConfigStore(),
            snapshotStore = snapshotStore,
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
            snapshotProvider = snapshotProvider,
            snapshotApplier = spy?.let { f -> ({ bytes -> f(bytes) }) },
            undoStore = undoStore,
        )
    }

    /** 种一条远端备份（走 index.json，条目不经体校验，便于注入坏体做失败分支）。 */
    private fun seedBackup(
        transport: FakeRemoteTransport,
        fileName: String,
        body: ByteArray?,
        exportedAtIso: String = "2026-03-07T09:05:00+08:00",
    ) {
        transport.files[config.historyIndexRemotePath] = CloudBackupIndexCodec.encodeIndex(
            listOf(
                CloudBackupEntryModel(
                    id = fileName.removeSuffix(".mikcb"),
                    fileName = fileName,
                    exportedAtIso = exportedAtIso,
                    contentSha256 = "",
                    deviceId = "devA",
                    deviceLabel = "",
                ),
            ),
        )
        body?.let { transport.files[config.historyBackupRemotePath(fileName)] = it }
    }

    private fun connect(controller: CloudSyncController) {
        assertTrue(controller.connect("me@example.com", "pw").success)
    }

    // ── prepare：概要 + 零副作用 ──

    @Test
    fun `prepare返回差异概要且零副作用`() {
        val transport = FakeRemoteTransport()
        val cloudBytes = bytes(
            snapshotPayload(
                profiles = listOf(profile("p1", course("c1"), course("c2"))),
            ),
        )
        seedBackup(transport, "backup.mikcb", cloudBytes)
        val snapshotStore = FakeLocalSnapshotStore()
        val applier = ApplierSpy()
        val localBytes = bytes(
            snapshotPayload(profiles = listOf(profile("p1", course("c2"), course("c3")))),
        )
        val controller = controller(
            transport = transport,
            snapshotStore = snapshotStore,
            snapshotProvider = { SnapshotBuildResult.Success(localBytes) },
            applier = applier,
        )
        connect(controller)

        val prepared = controller.prepareRestore("backup.mikcb")

        // 概要与两边内容一致：c1 新增、c3 删除、c2 相同；p1 因课程变了记覆盖。
        val diff = (prepared as? RestorePrepareOutcome.Ready)?.diff
        assertNotNull("prepare 应就绪：$prepared", diff)
        assertEquals(RestoreDiffCounts(0, 1, 0), diff!!.profiles)
        assertEquals(RestoreDiffCounts(1, 0, 1), diff.courses)
        assertEquals(RestoreDiffCounts(0, 0, 0), diff.timeSchemes)
        // 零副作用：不写本机快照文件、不写课表仓储。
        assertEquals(0, snapshotStore.writeCount)
        assertTrue(applier.applied.isEmpty())
    }

    @Test
    fun `本机没有数据时概要全记新增`() {
        val transport = FakeRemoteTransport()
        val cloudBytes = bytes(
            snapshotPayload(profiles = listOf(profile("p1", course("c1"), course("c2")))),
        )
        seedBackup(transport, "backup.mikcb", cloudBytes)
        val controller = controller(
            transport = transport,
            snapshotProvider = { SnapshotBuildResult.NoLocalData },
        )
        connect(controller)

        val prepared = controller.prepareRestore("backup.mikcb")

        val diff = (prepared as? RestorePrepareOutcome.Ready)?.diff
        assertNotNull(diff)
        assertEquals(RestoreDiffCounts(1, 0, 0), diff!!.profiles)
        assertEquals(RestoreDiffCounts(2, 0, 0), diff.courses)
    }

    // ── confirm：应用缓存字节 + 撤销点 + 可见性联动 ──

    @Test
    fun `confirm应用预览字节并设撤销点`() {
        val transport = FakeRemoteTransport()
        val cloudBytes = bytes(snapshotPayload(profiles = listOf(profile("p1", course("c1")))))
        seedBackup(transport, "backup.mikcb", cloudBytes)
        val snapshotStore = FakeLocalSnapshotStore()
        val applier = ApplierSpy()
        val undoStore = CloudSyncUndoStore()
        val localBytes = bytes(snapshotPayload(profiles = listOf(profile("p1", course("c9")))))
        val controller = controller(
            transport = transport,
            snapshotStore = snapshotStore,
            snapshotProvider = { SnapshotBuildResult.Success(localBytes) },
            applier = applier,
            undoStore = undoStore,
        )
        connect(controller)

        assertTrue(controller.prepareRestore("backup.mikcb") is RestorePrepareOutcome.Ready)
        assertEquals(SyncResultKind.DOWNLOADED, controller.confirmPreparedRestore())

        // 仓储拿到的是**预览时的同一份字节**。
        assertArrayEquals(cloudBytes, applier.applied.single())
        // 本机快照文件同步换成远端这份（镜像下载落盘行为）。
        assertNotNull(snapshotStore.stored)
        assertArrayEquals(cloudBytes, snapshotStore.stored!!)
        // 撤销点：before = 恢复前的本机、after = 恢复写入的远端份。
        val point = undoStore.peek()
        assertNotNull(point)
        assertArrayEquals(localBytes, point!!.beforeBytes)
        assertArrayEquals(cloudBytes, point.afterBytes)
        // 撤销入口可见性联动（两份 viewState 都透出）。
        assertTrue(controller.canUndoLastRestore)
        assertTrue(controller.cloudSyncViewState().canUndoRestore)
        assertTrue(controller.backupListViewState().canUndoRestore)
    }

    @Test
    fun `confirm后撤销真的能回退并收回入口`() {
        val transport = FakeRemoteTransport()
        val cloudBytes = bytes(snapshotPayload(profiles = listOf(profile("p1", course("c1")))))
        seedBackup(transport, "backup.mikcb", cloudBytes)
        val applier = ApplierSpy()
        val localBytes = bytes(snapshotPayload(profiles = listOf(profile("p1", course("c9")))))
        val controller = controller(
            transport = transport,
            snapshotProvider = { SnapshotBuildResult.Success(localBytes) },
            applier = applier,
        )
        connect(controller)
        controller.prepareRestore("backup.mikcb")
        controller.confirmPreparedRestore()

        assertTrue(controller.undoLastRestore())

        assertFalse("撤销后入口必须消失", controller.canUndoLastRestore)
        assertFalse(controller.backupListViewState().canUndoRestore)
    }

    @Test
    fun `confirm写回失败不留撤销点`() {
        val transport = FakeRemoteTransport()
        seedBackup(transport, "backup.mikcb", bytes(snapshotPayload(profiles = listOf(profile("p1")))))
        val applier = ApplierSpy().apply { failWith = "sync_snapshot_apply_failed" }
        val undoStore = CloudSyncUndoStore()
        val controller = controller(
            transport = transport,
            snapshotProvider = { SnapshotBuildResult.Success(ByteArray(0)) },
            applier = applier,
            undoStore = undoStore,
        )
        connect(controller)

        assertTrue(controller.prepareRestore("backup.mikcb") is RestorePrepareOutcome.Ready)
        assertEquals(SyncResultKind.FAILED, controller.confirmPreparedRestore())

        assertNull("写回失败不得留撤销点", undoStore.peek())
        assertEquals("sync_snapshot_apply_failed", controller.lastErrorCode)
    }

    // ── confirm 的守门：没准备 / 已丢弃 / 已断开 绝不误写 ──

    @Test
    fun `没有准备时confirm直接失败`() {
        val applier = ApplierSpy()
        val controller = controller(applier = applier)
        connect(controller)

        assertEquals(SyncResultKind.FAILED, controller.confirmPreparedRestore())
        assertTrue(applier.applied.isEmpty())
    }

    @Test
    fun `丢弃后confirm失败且不写任何存储`() {
        val transport = FakeRemoteTransport()
        seedBackup(transport, "backup.mikcb", bytes(snapshotPayload(profiles = listOf(profile("p1")))))
        val snapshotStore = FakeLocalSnapshotStore()
        val applier = ApplierSpy()
        val controller = controller(
            transport = transport,
            snapshotStore = snapshotStore,
            applier = applier,
        )
        connect(controller)
        assertTrue(controller.prepareRestore("backup.mikcb") is RestorePrepareOutcome.Ready)

        controller.discardPreparedRestore()

        assertEquals(SyncResultKind.FAILED, controller.confirmPreparedRestore())
        assertEquals(0, snapshotStore.writeCount)
        assertTrue(applier.applied.isEmpty())
    }

    @Test
    fun `断开连接清掉预览缓存`() {
        val transport = FakeRemoteTransport()
        seedBackup(transport, "backup.mikcb", bytes(snapshotPayload(profiles = listOf(profile("p1")))))
        val applier = ApplierSpy()
        val controller = controller(transport = transport, applier = applier)
        connect(controller)
        assertTrue(controller.prepareRestore("backup.mikcb") is RestorePrepareOutcome.Ready)

        controller.disconnect()

        assertEquals(SyncResultKind.FAILED, controller.confirmPreparedRestore())
        assertTrue(applier.applied.isEmpty())
    }

    // ── prepare 的失败分支 ──

    @Test
    fun `远端没有这条备份返回NotFound且不写错误码`() {
        val controller = controller()
        connect(controller)

        val prepared = controller.prepareRestore("不存在.mikcb")

        assertEquals(RestorePrepareOutcome.NotFound, prepared)
        assertNull(controller.lastErrorCode)
    }

    @Test
    fun `未连接时prepare返回Missing`() {
        val controller = controller()

        assertEquals(RestorePrepareOutcome.Missing, controller.prepareRestore("backup.mikcb"))
    }

    @Test
    fun `坏体prepare失败并写错误码`() {
        val transport = FakeRemoteTransport()
        seedBackup(transport, "bad.mikcb", "不是快照的字节".toByteArray(Charsets.UTF_8))
        val controller = controller(transport = transport)
        connect(controller)

        val prepared = controller.prepareRestore("bad.mikcb")

        assertTrue("坏体应报 Failed：$prepared", prepared is RestorePrepareOutcome.Failed)
        assertNotNull(controller.lastErrorCode)
    }

    // ── 单步入口 openBackup = prepare + confirm 组合 ──

    @Test
    fun `单步openBackup与两步等价且消费掉预览缓存`() {
        val transport = FakeRemoteTransport()
        val cloudBytes = bytes(snapshotPayload(profiles = listOf(profile("p1", course("c1")))))
        seedBackup(transport, "backup.mikcb", cloudBytes)
        val applier = ApplierSpy()
        val controller = controller(transport = transport, applier = applier)
        connect(controller)

        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))

        assertArrayEquals(cloudBytes, applier.applied.single())
        // 组合壳把缓存消费掉了：再 confirm 不会重复写。
        assertEquals(SyncResultKind.FAILED, controller.confirmPreparedRestore())
        assertTrue(applier.applied.size == 1)
    }
}
