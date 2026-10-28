package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.GetBytesResult
import com.mutx163.qingyu.sync.HistoryListResult
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.WebdavSyncConfig
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云同步协调层单测（C1 · 真收发接线）。
 *
 * ## 期望值哪来的（人推的，不是从实现抄的）
 * - 「列备份」= PROPFIND 目录里直接子文件数，空目录就是没有备份；
 * - 「上传后远端多一条」= 历史目录里 `.mikcb` 文件计数 +1；
 * - 「下载并解出快照」= 远端快照信封合法、内容哈希可算出、落盘字节与远端一致；
 * - 「冲突」= 首次同步（双基线空）且本机与远端内容不同 —— 这是产品定义，不是实现细节；
 * - 「断线/超时」失败码沿用 `WebdavFailures` 的安全短码口径；
 * - 「中途退出」= 网络已返回但用户已离开页面，**绝不能把字节写进本机**。
 */
class CloudSyncCoordinatorTest {

    private fun coordinator(
        transport: FakeRemoteTransport = FakeRemoteTransport(),
        store: FakeLocalSnapshotStore = FakeLocalSnapshotStore(),
    ): WebdavSyncCoordinator = WebdavSyncCoordinator(transport, store)

    // ---------- 列远端备份（PROPFIND） ----------

    @Test
    fun `列远端备份成功_解析版本化文件名元信息`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}snapshot-abc123-1700000000000000-devA.mikcb"] = byteArrayOf(1)
        transport.files["${folder}snapshot-def456-1700000123000000-devB.mikcb"] = byteArrayOf(2)

        val outcome = coordinator(transport).listRemoteBackups(WebdavSyncConfig())

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertEquals(2, outcome.files.size)
        val first = outcome.files.first { it.fileName.contains("abc123") }
        // 1700000000000000 微秒 = 1700000000000 毫秒
        assertEquals(1700000000000L, first.exportedAtMillis)
        assertEquals("abc123", first.contentSha256)
        assertEquals("devA", first.deviceId)
        assertEquals("${folder}snapshot-abc123-1700000000000000-devA.mikcb", first.remotePath)
    }

    @Test
    fun `列远端备份_空目录是没有备份而不是失败`() {
        val outcome = coordinator().listRemoteBackups(WebdavSyncConfig())
        assertEquals(SyncOpKind.EMPTY, outcome.kind)
        assertTrue(outcome.files.isEmpty())
        assertNull(outcome.errorCode)
    }

    @Test
    fun `列远端备份_目录不存在也当空目录`() {
        val transport = FakeRemoteTransport()
        transport.listResultOverride = HistoryListResult.notFound()
        val outcome = coordinator(transport).listRemoteBackups(WebdavSyncConfig())
        assertEquals(SyncOpKind.EMPTY, outcome.kind)
    }

    @Test
    fun `列远端备份_断线映射成安全短码`() {
        val transport = FakeRemoteTransport()
        transport.listResultOverride = HistoryListResult.failed("connection_failed")
        val outcome = coordinator(transport).listRemoteBackups(WebdavSyncConfig())
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("connection_failed", outcome.errorCode)
    }

    @Test
    fun `文件名不是版本化格式时仍算一条备份_元信息为空`() {
        val file = WebdavSyncCoordinator.parseRemoteBackupFile("random.mikcb", "/Apps/x/history/")
        assertEquals("random.mikcb", file.fileName)
        assertNull(file.exportedAtMillis)
        assertNull(file.contentSha256)
        assertNull(file.deviceId)
    }

    // ---------- 上传（PUT） ----------

    @Test
    fun `上传成功后远端多一条`() {
        val transport = FakeRemoteTransport()
        val store = FakeLocalSnapshotStore()
        val coord = coordinator(transport, store)
        val config = WebdavSyncConfig()
        val bytes = buildSyncSnapshotBytes()

        val upload = coord.uploadSnapshot(config, bytes, exportedAtUtcMicros = 1_700_000_000_000_000L, deviceId = "devA")
        assertEquals(SyncOpKind.OK, upload.kind)
        assertNotNull(upload.contentSha256)

        // 上传后目录里恰好 1 条（上传前是 0 条）。
        val listing = coord.listRemoteBackups(config)
        assertEquals(SyncOpKind.OK, listing.kind)
        assertEquals(1, listing.files.size)
        assertTrue(transport.files.containsKey(config.snapshotRemotePath))
    }

    @Test
    fun `上传时断线映射成安全短码_不抛异常`() {
        val transport = FakeRemoteTransport()
        transport.putFailureCode = "connection_failed"
        val outcome = coordinator(transport).uploadSnapshot(
            WebdavSyncConfig(),
            buildSyncSnapshotBytes(),
            exportedAtUtcMicros = 1_700_000_000_000_000L,
            deviceId = "devA",
        )
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("connection_failed", outcome.errorCode)
    }

    @Test
    fun `上传的正文不是合法快照时判负载非法`() {
        val outcome = coordinator().uploadSnapshot(
            WebdavSyncConfig(),
            "not-a-snapshot".toByteArray(),
            exportedAtUtcMicros = 1L,
            deviceId = "devA",
        )
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("invalid_sync_snapshot_payload", outcome.errorCode)
    }

    // ---------- 下载（GET）+ 快照解码 ----------

    @Test
    fun `下载并解出快照_内容一致时直接落盘`() {
        val config = WebdavSyncConfig()
        val snapshot = buildSyncSnapshotBytes(profileId = "p1")
        val transport = FakeRemoteTransport()
        transport.files[config.snapshotRemotePath] = snapshot
        val store = FakeLocalSnapshotStore(initial = snapshot) // 本机已有同一份内容

        val outcome = coordinator(transport, store).downloadSnapshot(config)

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertTrue(outcome.applied)
        assertEquals(1, store.writeCount)
        assertArrayEquals(snapshot, store.stored)
        // 远端内容哈希与本地内容哈希一致（同一份内容）。
        assertEquals(outcome.remoteContentSha256, outcome.localContentSha256)
        assertFalse(outcome.remoteContentSha256.isNullOrEmpty())
    }

    @Test
    fun `下载时远端缺失判备份不存在`() {
        val outcome = coordinator().downloadSnapshot(WebdavSyncConfig())
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("backup_not_found", outcome.errorCode)
    }

    @Test
    fun `下载时超时映射成安全短码`() {
        val transport = FakeRemoteTransport()
        transport.getResultOverride = GetBytesResult.failed("connection_timeout")
        val outcome = coordinator(transport).downloadSnapshot(WebdavSyncConfig())
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("connection_timeout", outcome.errorCode)
    }

    @Test
    fun `下载的正文信封不合法时判未识别快照`() {
        val config = WebdavSyncConfig()
        val transport = FakeRemoteTransport()
        transport.files[config.snapshotRemotePath] = "{}".toByteArray()
        val outcome = coordinator(transport).downloadSnapshot(config)
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("unrecognized_sync_snapshot", outcome.errorCode)
    }

    // ---------- 冲突判定 ----------

    @Test
    fun `首次同步_本地与远端内容不同即冲突_保留本机时不覆盖`() {
        val config = WebdavSyncConfig() // 双基线空 → 首次同步
        val localBytes = buildSyncSnapshotBytes(profileId = "p2")
        val remoteBytes = buildSyncSnapshotBytes(profileId = "p1")
        val transport = FakeRemoteTransport()
        transport.files[config.snapshotRemotePath] = remoteBytes
        val store = FakeLocalSnapshotStore(initial = localBytes)

        val outcome = coordinator(transport, store).downloadSnapshot(
            config,
            hasLocalUserData = true,
            resolver = { SyncConflictChoice.KEEP_LOCAL },
        )

        assertEquals(SyncOpKind.CONFLICT, outcome.kind)
        assertFalse(outcome.applied)
        assertEquals(0, store.writeCount)
        assertArrayEquals(localBytes, store.stored) // 本机一个字都没被动
        assertNotNull(outcome.conflict)
        assertTrue(outcome.conflict!!.isFirstSyncDivergence)
    }

    @Test
    fun `首次同步冲突_选云端则以远端覆盖本地`() {
        val config = WebdavSyncConfig()
        val localBytes = buildSyncSnapshotBytes(profileId = "p2")
        val remoteBytes = buildSyncSnapshotBytes(profileId = "p1")
        val transport = FakeRemoteTransport()
        transport.files[config.snapshotRemotePath] = remoteBytes
        val store = FakeLocalSnapshotStore(initial = localBytes)

        val outcome = coordinator(transport, store).downloadSnapshot(
            config,
            resolver = { SyncConflictChoice.KEEP_REMOTE },
        )

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertTrue(outcome.applied)
        assertArrayEquals(remoteBytes, store.stored)
    }

    // ---------- 中途退出（取消）不落脏数据 ----------

    @Test
    fun `下载中途退出_网络返回后也不落盘`() {
        val config = WebdavSyncConfig()
        val remoteBytes = buildSyncSnapshotBytes(profileId = "p1")
        val transport = FakeRemoteTransport()
        transport.files[config.snapshotRemotePath] = remoteBytes
        val store = FakeLocalSnapshotStore(initial = null)
        val coord = coordinator(transport, store)

        // 模拟：GET 途中用户离开了页面 → 协调器被 cancel；GET 仍然返回了完整字节。
        transport.beforeGet = { coord.cancel() }

        val outcome = coord.downloadSnapshot(config)

        assertEquals(SyncOpKind.CANCELLED, outcome.kind)
        assertFalse(outcome.applied)
        assertEquals(0, store.writeCount)
        assertNull(store.stored)
    }
}
