package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
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
 * 云同步协调层单测（C1 真收发；2026-11-02 起按 Dart 协议对拍）。
 *
 * ## 期望值哪来的（人推的，不是从实现抄的）
 * - 「上传后远端布局」= Dart `_publishSnapshotVersion` + `_writeBackupHistory`：
 *   根目录版本化正文 + `snapshot.meta.json` 指针 + `history/<ts>-<hash8>.mikcb` + `history/index.json`；
 * - 「列备份」= index.json 条目；index 缺失/损坏时按恢复决策从 listing 重建；
 * - 「下载并解出快照」= 远端快照信封合法、内容哈希可算出、落盘字节与远端一致；
 * - 「meta 与正文不配对」= `sync_snapshot_meta_mismatch`，绝不落盘；
 * - 「冲突」= 首次同步（双基线空）且本机与远端内容不同 —— 这是产品定义，不是实现细节；
 * - 「断线/超时」失败码沿用 `WebdavFailures` 的安全短码口径；
 * - 「中途退出」= 网络已返回但用户已离开页面，**绝不能把字节写进本机**。
 */
class CloudSyncCoordinatorTest {

    private fun coordinator(
        transport: FakeRemoteTransport = FakeRemoteTransport(),
        store: FakeLocalSnapshotStore = FakeLocalSnapshotStore(),
    ): WebdavSyncCoordinator = WebdavSyncCoordinator(transport, store)

    private val exportIso = "2026-03-07T09:05:00.000"

    // ---------- 列远端备份（index 驱动） ----------

    @Test
    fun `列远端备份_读index逐字段解析`() {
        val transport = FakeRemoteTransport()
        val config = WebdavSyncConfig()
        val snapshot = buildSyncSnapshotBytes()
        val hash = WebdavSyncCoordinator.snapshotContentHash(snapshot)!!
        val history = config.historyRemoteFolder
        transport.files["${history}20260307-171501-$hash.mikcb"] = snapshot
        transport.files[config.historyIndexRemotePath] = """
            {"version":1,"entries":[{
              "id":"20260307-171501-$hash",
              "fileName":"20260307-171501-$hash.mikcb",
              "exportedAt":"2026-03-07T17:15:01.000",
              "contentSha256":"$hash",
              "deviceId":"devA",
              "deviceLabel":"Pixel",
              "isCurrent":true,
              "source":"manual",
              "profileCount":1,
              "courseCount":0
            }]}
        """.trimIndent().toByteArray()

        val outcome = coordinator(transport).listRemoteBackups(config)

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertEquals(1, outcome.files.size)
        val file = outcome.files.single()
        assertEquals("20260307-171501-$hash.mikcb", file.fileName)
        assertEquals("${history}20260307-171501-$hash.mikcb", file.remotePath)
        assertEquals(hash, file.contentSha256)
        assertEquals("devA", file.deviceId)
        assertEquals("Pixel", file.deviceLabel)
        assertEquals(CloudBackupSource.MANUAL, file.source)
        assertTrue(file.isCurrent)
        assertEquals(1, file.profileCount)
    }

    @Test
    fun `列远端备份_index缺失时从listing重建`() {
        val transport = FakeRemoteTransport()
        val config = WebdavSyncConfig()
        val snapshot = buildSyncSnapshotBytes()
        val hash = WebdavSyncCoordinator.snapshotContentHash(snapshot)!!
        // Flutter 旧布局：只有 history 文件，没有 index.json。
        transport.files["${config.historyRemoteFolder}20260307-171501-$hash.mikcb"] = snapshot

        val outcome = coordinator(transport).listRemoteBackups(config)

        assertEquals(SyncOpKind.OK, outcome.kind)
        val file = outcome.files.single()
        assertEquals(hash, file.contentSha256)
        assertEquals("devA", file.deviceId)
        assertEquals(1, file.profileCount)
        assertFalse(file.isCurrent) // meta 缺失 → currentHash 空 → 无人标当前
    }

    @Test
    fun `列远端备份_index损坏时从listing重建_坏体跳过`() {
        val transport = FakeRemoteTransport()
        val config = WebdavSyncConfig()
        val snapshot = buildSyncSnapshotBytes()
        val hash = WebdavSyncCoordinator.snapshotContentHash(snapshot)!!
        transport.files[config.historyIndexRemotePath] = "not-json".toByteArray()
        transport.files["${config.historyRemoteFolder}good.mikcb"] = snapshot
        transport.files["${config.historyRemoteFolder}corrupt.mikcb"] = "垃圾字节".toByteArray()

        val outcome = coordinator(transport).listRemoteBackups(config)

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertEquals(listOf("good.mikcb"), outcome.files.map { it.fileName })
        assertEquals(hash, outcome.files.single().contentSha256)
    }

    @Test
    fun `列远端备份_空远端是没有备份而不是失败`() {
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

    // ---------- 上传（发布正文 + meta + 历史 + 索引） ----------

    @Test
    fun `上传后远端布局与Flutter协议一致`() {
        val transport = FakeRemoteTransport()
        val store = FakeLocalSnapshotStore()
        val coord = coordinator(transport, store)
        val config = WebdavSyncConfig()
        val bytes = buildSyncSnapshotBytes(exportedAt = exportIso)
        val hash = WebdavSyncCoordinator.snapshotContentHash(bytes)!!

        val upload = coord.uploadSnapshot(config, bytes, exportedAtIso = exportIso, deviceId = "devA")
        assertEquals(SyncOpKind.OK, upload.kind)
        assertEquals(hash, upload.contentSha256)

        // 1) 版本化正文在**根目录**（不是 history/），名字含完整 sha256 + 微秒 + 设备。
        val rootBody = transport.files.keys.single { it.startsWith(config.normalizedRemoteFolder) && it.endsWith(".mikcb") && !it.contains("/history/") }
        assertTrue(rootBody.contains("snapshot-$hash-"))
        assertTrue(rootBody.contains("-devA.mikcb"))
        assertArrayEquals(bytes, transport.files[rootBody])

        // 2) meta 指针：snapshotPath 指向那份正文，contentSha256 是本次哈希。
        val meta = MiniJson.parse(String(transport.files[config.metaRemotePath]!!, Charsets.UTF_8)) as Map<*, *>
        assertEquals(hash, meta["contentSha256"])
        assertEquals(rootBody, meta["snapshotPath"])
        assertEquals(exportIso, meta["exportedAt"])
        assertEquals("devA", meta["deviceId"])

        // 3) 历史文件用 Dart 命名（本地时刻 yyyyMMdd-HHmmss + hash8）。
        val historyName = transport.files.keys.single { it.startsWith(config.historyRemoteFolder) && it != config.historyIndexRemotePath }
        assertTrue("Dart 命名应形如 20260307-HHMMSS-<hash8>.mikcb：$historyName",
            Regex("""20260307-\d{6}-[0-9a-f]{8}\.mikcb$""").containsMatchIn(historyName))
        assertArrayEquals(bytes, transport.files[historyName])

        // 4) index.json 有这一条且标为当前版本。
        val index = MiniJson.parse(String(transport.files[config.historyIndexRemotePath]!!, Charsets.UTF_8)) as Map<*, *>
        val entries = index["entries"] as List<*>
        assertEquals(1, entries.size)
        val entry = entries.single() as Map<*, *>
        assertEquals(hash, entry["contentSha256"])
        assertEquals(true, entry["isCurrent"])
        assertEquals("auto", entry["source"])
        assertEquals(1L, (index["version"] as Number).toLong())
    }

    @Test
    fun `上传时锁被占是硬失败_远端一个字都不动`() {
        val transport = FakeRemoteTransport().apply {
            lockSupported = true
            lockConflict = true
        }
        val config = WebdavSyncConfig()
        val outcome = coordinator(transport).uploadSnapshot(
            config,
            buildSyncSnapshotBytes(exportedAt = exportIso),
            exportedAtIso = exportIso,
            deviceId = "devA",
        )
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("access_denied", outcome.errorCode)
        // 挂起期间远端必须原地不动。
        assertNull(transport.files[config.metaRemotePath])
        assertTrue(transport.files.keys.none { it.endsWith(".mikcb") })
    }

    @Test
    fun `上传时锁能力关闭_无If头照样发布_与今天一致`() {
        val transport = FakeRemoteTransport() // lockSupported = false
        val config = WebdavSyncConfig()

        val outcome = coordinator(transport).uploadSnapshot(
            config,
            buildSyncSnapshotBytes(exportedAt = exportIso),
            exportedAtIso = exportIso,
            deviceId = "devA",
        )

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertNull("无锁路径不得带 If 头", transport.lastConditionalPutLockToken)
        assertTrue(transport.lastConditionalPutHeaders.isNullOrEmpty())
        assertNotNull(transport.files[config.metaRemotePath])
    }

    @Test
    fun `上传时锁可用_PUT带锁token且用完释放`() {
        val transport = FakeRemoteTransport().apply { lockSupported = true }
        val config = WebdavSyncConfig()

        assertEquals(SyncOpKind.OK, coordinator(transport).uploadSnapshot(
            config,
            buildSyncSnapshotBytes(exportedAt = exportIso),
            exportedAtIso = exportIso,
            deviceId = "devA",
        ).kind)

        assertNotNull(transport.lastConditionalPutLockToken)
        assertNull("发布完成后锁必须释放", transport.heldLockToken)
    }

    @Test
    fun `上传正文读回不一致判失败`() {
        val transport = FakeRemoteTransport().apply { tamperNextGet = true }
        val config = WebdavSyncConfig()
        val outcome = coordinator(transport).uploadSnapshot(
            config,
            buildSyncSnapshotBytes(exportedAt = exportIso),
            exportedAtIso = exportIso,
            deviceId = "devA",
        )
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("sync_failed", outcome.errorCode)
        // 读回不合格 ⇒ meta 不许发布（正文/meta 配对不被拆散）。
        assertNull(transport.files[config.metaRemotePath])
    }

    @Test
    fun `上传时断线映射成安全短码_不抛异常`() {
        val transport = FakeRemoteTransport()
        transport.putFailureCode = "connection_failed"
        val outcome = coordinator(transport).uploadSnapshot(
            WebdavSyncConfig(),
            buildSyncSnapshotBytes(),
            exportedAtIso = exportIso,
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
            exportedAtIso = exportIso,
            deviceId = "devA",
        )
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("invalid_sync_snapshot_payload", outcome.errorCode)
    }

    @Test
    fun `上传同内容两次_index不堆重复条目`() {
        val transport = FakeRemoteTransport()
        val config = WebdavSyncConfig()
        val bytes = buildSyncSnapshotBytes(exportedAt = exportIso)
        val coord = coordinator(transport)

        assertEquals(SyncOpKind.OK, coord.uploadSnapshot(config, bytes, exportedAtIso = exportIso, deviceId = "devA").kind)
        assertEquals(SyncOpKind.OK, coord.uploadSnapshot(config, bytes, exportedAtIso = exportIso, deviceId = "devA").kind)

        val index = MiniJson.parse(String(transport.files[config.historyIndexRemotePath]!!, Charsets.UTF_8)) as Map<*, *>
        assertEquals(1, (index["entries"] as List<*>).size)
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
    fun `下载时meta与正文不配对判sync_snapshot_meta_mismatch`() {
        val config = WebdavSyncConfig()
        val snapshot = buildSyncSnapshotBytes(profileId = "p1")
        val transport = FakeRemoteTransport()
        transport.files["${config.normalizedRemoteFolder}body.mikcb"] = snapshot
        val store = FakeLocalSnapshotStore(initial = null)

        val outcome = coordinator(transport, store).downloadSnapshot(
            config,
            remotePath = "${config.normalizedRemoteFolder}body.mikcb",
            expectedRemoteHash = "deadbeef".repeat(4),
        )

        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("sync_snapshot_meta_mismatch", outcome.errorCode)
        assertEquals(0, store.writeCount)
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

    // ---------- 远端 meta ----------

    @Test
    fun `fetchRemoteMeta_缺失返回NotFound_损坏返回invalid_response`() {
        val transport = FakeRemoteTransport()
        val config = WebdavSyncConfig()
        val coord = coordinator(transport)

        assertEquals(RemoteMetaFetch.NotFound, coord.fetchRemoteMeta(config))

        transport.files[config.metaRemotePath] = "{broken".toByteArray()
        assertEquals("invalid_response", (coord.fetchRemoteMeta(config) as RemoteMetaFetch.Failed).errorCode)

        transport.files[config.metaRemotePath] = """{"contentSha256":42}""".toByteArray()
        assertEquals("invalid_response", (coord.fetchRemoteMeta(config) as RemoteMetaFetch.Failed).errorCode)
    }

    @Test
    fun `fetchRemoteMeta_Flutter格式读出全字段`() {
        val transport = FakeRemoteTransport()
        val config = WebdavSyncConfig()
        transport.files[config.metaRemotePath] = """
            {"exportedAt":"2026-11-01T09:15:00.000Z","contentSha256":"abc123",
             "deviceId":"flutter-dev-1","appVersion":"2.0.1",
             "snapshotPath":"/Apps/qingyu-sync/snapshot-abc123-123-flutter-dev-1.mikcb"}
        """.trimIndent().toByteArray()

        val meta = coordinator(transport).fetchRemoteMeta(config) as RemoteMetaFetch.Ok

        assertEquals("abc123", meta.contentSha256)
        assertEquals("flutter-dev-1", meta.deviceId)
        assertEquals("/Apps/qingyu-sync/snapshot-abc123-123-flutter-dev-1.mikcb", meta.snapshotPath)
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
