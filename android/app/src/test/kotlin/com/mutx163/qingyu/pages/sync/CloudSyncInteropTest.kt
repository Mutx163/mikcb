package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.parseSnapshotMetaFields
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **双向互通验收**（任务硬要求：本壳写出的备份 Flutter 必须能读，Flutter 写的备份本壳必须能读）。
 *
 * ## 样本来源（诚实清单）
 *
 * **Flutter → 本壳方向**：远端状态是手工按 Dart 侧实现逐字构造的字面量——
 * - meta：`lib/services/app_sync_snapshot_service.dart` `AppSyncSnapshotMeta.toJson`（:213-220）；
 * - 版本化正文路径：`lib/services/webdav_sync_service.dart` `_versionedSnapshotRemotePath`（:536-547）；
 * - history 文件名与 index.json：`lib/services/cloud_backup_index_service.dart`
 *   `buildBackupId`（:139-155）/`CloudBackupIndex.toJson`（:103-106），
 *   以 Dart `JsonEncoder.withIndent('  ')` 的输出形态写成字符串。
 *
 * **本壳 → Flutter 方向**：无法在本 JVM 单测里跑 Dart，替代证据是把 Dart 读取方的
 * 逐字段口径移植为断言（与 Dart 源逐行对拍）：
 * - meta 用 [parseSnapshotMetaFields]（`AppSyncSnapshotMeta.fromJson` 的移植，锚点 :222-240）；
 * - index 用 [CloudBackupIndexCodec.decodeIndex] → [CloudBackupEntryModel.fromJson]
 *   （`CloudBackupEntry.fromJson` 的移植，锚点 cloud_backup_index_service.dart:46-65），
 *   并额外断言「写出键名 ⊆ Dart toJson 键名集合」「键序逐字一致」。
 * 真双端互读仍需两台真机各跑一版（见汇报「必须真机验的路径」），本文件是格式合同的 JVM 侧钉子。
 */
class CloudSyncInteropTest {

    private val config = WebdavSyncConfig()
    private val folder = config.normalizedRemoteFolder // /Apps/qingyu-sync/
    private val history = config.historyRemoteFolder

    // ---------- 方向 A：Flutter 写的云端 → 本壳必须能读 ----------

    /** 按 Dart 实现构造一份完整的 Flutter 云端状态（meta + 根目录正文 + 历史 + index）。 */
    private fun seedFlutterCloud(
        transport: FakeRemoteTransport,
        snapshotJson: String,
    ): String {
        val exportedAtIso = "2026-11-01T09:15:00.000Z"
        val deviceId = "flutter-pixel"
        val hash = WebdavSyncCoordinator.snapshotContentHash(snapshotJson.toByteArray(Charsets.UTF_8))!!
        // Dart _versionedSnapshotRemotePath：exportedAt.toUtc().microsecondsSinceEpoch。
        val micros = 1_795_877_700_000_000L // 2026-11-01T09:15:00Z 的微秒（测试固定值）
        val bodyPath = "${folder}snapshot-$hash-$micros-$deviceId.mikcb"
        val bodyBytes = snapshotJson.toByteArray(Charsets.UTF_8)
        transport.files[bodyPath] = bodyBytes
        // Dart AppSyncSnapshotMeta.toJson 的输出形态。
        transport.files[config.metaRemotePath] = """
            {"exportedAt":"$exportedAtIso","contentSha256":"$hash","deviceId":"$deviceId",
             "appVersion":"2.0.1","snapshotPath":"$bodyPath"}
        """.trimIndent().toByteArray()

        // Dart buildBackupId：本地时刻 yyyyMMdd-HHmmss + hash8（这里上海时区 → 17:15:00）。
        val historyName = "20261101-171500-${hash.substring(0, 8)}.mikcb"
        transport.files["$history$historyName"] = bodyBytes
        // Dart JsonEncoder.withIndent('  ') 编码 CloudBackupIndex.toJson 的输出形态。
        transport.files[config.historyIndexRemotePath] = """
            {
              "version": 1,
              "entries": [
                {
                  "id": "20261101-171500-${hash.substring(0, 8)}",
                  "fileName": "$historyName",
                  "exportedAt": "$exportedAtIso",
                  "contentSha256": "$hash",
                  "deviceId": "$deviceId",
                  "deviceLabel": "Pixel 8",
                  "appVersion": "2.0.1",
                  "isCurrent": true,
                  "source": "manual",
                  "profileCount": 2,
                  "courseCount": 17
                }
              ]
            }
        """.trimIndent().toByteArray()
        return bodyPath
    }

    @Test
    fun `方向A_Flutter云端_列表读出索引全字段`() {
        val transport = FakeRemoteTransport()
        seedFlutterCloud(transport, buildSyncSnapshotJson())

        val outcome = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore()).listRemoteBackups(config)

        assertEquals(SyncOpKind.OK, outcome.kind)
        val file = outcome.files.single()
        assertEquals(CloudBackupSource.MANUAL, file.source) // index 里的真实来源
        assertEquals("Pixel 8", file.deviceLabel)
        assertEquals("2.0.1", file.appVersion)
        assertTrue(file.isCurrent)
        assertEquals(2, file.profileCount)
        assertEquals(17, file.courseCount)
        assertEquals("flutter-pixel", file.deviceId)
        assertNotNull(file.exportedAtMillis)
    }

    @Test
    fun `方向A_Flutter云端_立即同步拉取meta指向的正文并写基线`() {
        val transport = FakeRemoteTransport()
        val flutterSnapshot = buildSyncSnapshotJson(exportedAt = "2026-11-01T09:15:00.000Z")
        seedFlutterCloud(transport, flutterSnapshot)
        val localBytes = buildSyncSnapshotBytes(profileId = "pLocal")
        val localHash = WebdavSyncCoordinator.snapshotContentHash(localBytes)
        val store = FakeLocalSnapshotStore(initial = localBytes)
        val controller = CloudSyncController(
            // 基线钉在本地旧值：模拟「之前同步过、之后 Flutter 那台又推了新版」。
            store = FakeConfigStore(
                config = WebdavSyncConfig().copyWith(
                    lastAppliedRemoteHash = localHash,
                    lastUploadedLocalHash = localHash,
                ),
            ),
            snapshotStore = store,
            transportFactory = { _, _ -> transport },
            clock = { "2026-11-01T18:00:00+08:00" },
            snapshotApplier = { SnapshotApplyResult.Applied },
            undoStore = CloudSyncUndoStore(),
        )
        controller.connect("me@example.com", "pw")

        assertEquals(SyncResultKind.DOWNLOADED, controller.syncNow())

        assertArrayEquals(flutterSnapshot.toByteArray(Charsets.UTF_8), store.stored)
        val flutterHash = WebdavSyncCoordinator.snapshotContentHash(flutterSnapshot.toByteArray(Charsets.UTF_8))
        assertEquals(flutterHash, controller.config.lastAppliedRemoteHash)
        assertEquals(flutterHash, controller.config.lastUploadedLocalHash)
        assertNull(controller.pendingSyncConflict)
    }

    @Test
    fun `方向A_meta与正文被并发拆散时拒绝落盘`() {
        val transport = FakeRemoteTransport()
        val bodyPath = seedFlutterCloud(transport, buildSyncSnapshotJson())
        // 模拟并发写者已换了正文内容：meta 声明的哈希与正文对不上。
        transport.files[bodyPath] = buildSyncSnapshotBytes(profileId = "tampered")
        val localHash = WebdavSyncCoordinator.snapshotContentHash(buildSyncSnapshotBytes(profileId = "pLocal"))
        val store = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pLocal"))
        val controller = CloudSyncController(
            store = FakeConfigStore(
                config = WebdavSyncConfig().copyWith(
                    lastAppliedRemoteHash = localHash,
                    lastUploadedLocalHash = localHash,
                ),
            ),
            snapshotStore = store,
            transportFactory = { _, _ -> transport },
            clock = { "2026-11-01T18:00:00+08:00" },
            snapshotApplier = { SnapshotApplyResult.Applied },
            undoStore = CloudSyncUndoStore(),
        )
        controller.connect("me@example.com", "pw")

        assertEquals(SyncResultKind.FAILED, controller.syncNow())

        assertEquals("sync_snapshot_meta_mismatch", controller.lastErrorCode)
        assertEquals("配不上的正文绝不能落盘", 0, store.writeCount)
    }

    @Test
    fun `方向A_Flutter的手动备份在本壳保留策略下受保护`() {
        val transport = FakeRemoteTransport()
        seedFlutterCloud(transport, buildSyncSnapshotJson())
        val controller = CloudSyncController(
            store = FakeConfigStore(config = WebdavSyncConfig(maxBackupCount = 1)), // 手动保护默认开
            snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pLocal")),
            transportFactory = { _, _ -> transport },
            clock = { "2026-11-01T18:00:00+08:00" },
            snapshotApplier = { SnapshotApplyResult.Applied },
            undoStore = CloudSyncUndoStore(),
        )
        controller.connect("me@example.com", "pw")

        assertEquals(SyncResultKind.UPLOADED, controller.createBackup()) // 上限 1，Flutter 手动备份最老

        // Flutter 那条手动备份必须还在：index 来源为 manual ⇒ 受保护，不被本壳 prune 清掉。
        val remaining = transport.files.keys
            .filter { it.startsWith(history) && it.endsWith(".mikcb") }
            .map { it.substringAfterLast('/') }
        assertEquals(2, remaining.size)
    }

    // ---------- 方向 B：本壳写出的云端 → Flutter 必须能读 ----------

    @Test
    fun `方向B_上传布局与Dart读法逐字段对拍`() {
        val transport = FakeRemoteTransport()
        val coordinator = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore())
        val bytes = buildSyncSnapshotBytes(exportedAt = "2026-03-07T09:05:00.000")
        val hash = WebdavSyncCoordinator.snapshotContentHash(bytes)!!

        assertEquals(
            SyncOpKind.OK,
            coordinator.uploadSnapshot(
                config, bytes,
                exportedAtIso = "2026-03-07T09:05:00.000",
                deviceId = "compose-dev",
                source = CloudBackupSource.MANUAL,
                appVersion = "1.9.0",
            ).kind,
        )

        // 1) meta：键名与 Dart toJson 完全一致；Flutter 的 fromJson（parseSnapshotMetaFields）读回。
        val metaJson = String(transport.files[config.metaRemotePath]!!, Charsets.UTF_8)
        val metaMap = MiniJson.parse(metaJson) as Map<*, *>
        assertEquals(
            listOf("exportedAt", "contentSha256", "deviceId", "appVersion", "snapshotPath"),
            metaMap.keys.toList(), // AppSyncSnapshotMeta.toJson 键序（app_sync_snapshot_service.dart:213-220）
        )
        val meta = parseSnapshotMetaFields(MiniJson.parse(metaJson) as Map<String, Any?>)
        assertTrue(meta.isValid)
        assertEquals(hash, meta.contentSha256)
        assertEquals("compose-dev", meta.deviceId)
        assertEquals("1.9.0", meta.appVersion)

        // 2) 版本化正文在根目录，路径与 Dart _versionedSnapshotRemotePath 的拼法一致
        //    （snapshot-<sha256>-<微秒>-<设备>.mikcb；测试独立按 Dart 算法重算一遍）。
        val micros = CloudBackupListLogic.parseExportedAtMillis("2026-03-07T09:05:00.000") * 1000L
        val expectedBodyPath = "${folder}snapshot-$hash-$micros-compose-dev.mikcb"
        assertEquals(expectedBodyPath, meta.snapshotPath)
        assertArrayEquals(bytes, transport.files[expectedBodyPath])

        // 3) 历史文件名符合 Dart buildBackupId 的形态：本地时刻 yyyyMMdd-HHmmss-<hash8>.mikcb。
        val historyName = transport.files.keys
            .filter { it.startsWith(history) && it.endsWith(".mikcb") && it != config.historyIndexRemotePath }
            .single().substringAfterLast('/')
        assertTrue(
            "Dart 命名应形如 20260307-090500-<hash8>.mikcb：$historyName",
            historyName.matches(Regex("""20260307-090500-[0-9a-f]{8}\.mikcb""")),
        )
        assertArrayEquals(bytes, transport.files["$history$historyName"])

        // 4) index.json：Flutter CloudBackupIndex.fromJson / CloudBackupEntry.fromJson 读回逐字段一致。
        val indexText = String(transport.files[config.historyIndexRemotePath]!!, Charsets.UTF_8)
        val indexRoot = MiniJson.parse(indexText) as Map<*, *>
        assertEquals(1L, (indexRoot["version"] as Number).toLong())
        val entryMap = (indexRoot["entries"] as List<*>).single() as Map<*, *>
        // 键序与 Dart CloudBackupEntry.toJson 逐字一致（cloud_backup_index_service.dart:32-44）。
        assertEquals(
            listOf("id", "fileName", "exportedAt", "contentSha256", "deviceId", "deviceLabel",
                "appVersion", "isCurrent", "source", "profileCount", "courseCount"),
            entryMap.keys.toList(),
        )
        val entries = CloudBackupIndexCodec.decodeIndex(indexText) // Dart fromJson 缺省口径的移植
        val entry = entries.single()
        assertEquals(historyName.removeSuffix(".mikcb"), entry.id) // Dart 重建口径：id = 文件名去 .mikcb
        assertEquals(historyName, entry.fileName)
        assertEquals(hash, entry.contentSha256)
        assertEquals("compose-dev", entry.deviceId)
        assertEquals("1.9.0", entry.appVersion)
        assertTrue(entry.isCurrent)
        assertEquals(CloudBackupSource.MANUAL, entry.source) // source 落盘，Flutter 能认出手动备份
        assertEquals("2026-03-07T09:05:00.000", entry.exportedAtIso) // Dart DateTime.tryParse 可解析
        assertEquals(1, entry.profileCount)
    }

    @Test
    fun `方向B_本壳上传后Flutter端删除语义可用_索引自洽`() {
        val transport = FakeRemoteTransport()
        val coordinator = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore())
        val bytes = buildSyncSnapshotBytes()
        assertEquals(
            SyncOpKind.OK,
            coordinator.uploadSnapshot(config, bytes, exportedAtIso = "2026-03-07T09:05:00.000", deviceId = "d").kind,
        )
        // 上传后的 index 里条目 id/fileName 与实际 history 文件一一对应（Flutter deleteBackup 靠它定位）。
        val entries = CloudBackupIndexCodec.decodeIndex(String(transport.files[config.historyIndexRemotePath]!!, Charsets.UTF_8))
        val entry = entries.single()
        assertTrue(transport.files.containsKey(config.historyBackupRemotePath(entry.fileName)))
        assertEquals(entry.fileName.removeSuffix(".mikcb"), entry.id)
        // 当前版本在索引里被标记（Flutter 删除闸门 entry.isCurrent 靠它拒绝删当前）。
        assertTrue(entry.isCurrent)
    }

    @Test
    fun `方向B_自动同步同内容不堆重复历史但meta始终指最新`() {
        val transport = FakeRemoteTransport()
        val coordinator = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore())
        val bytes = buildSyncSnapshotBytes()
        repeat(2) {
            assertEquals(
                SyncOpKind.OK,
                coordinator.uploadSnapshot(config, bytes, exportedAtIso = "2026-03-07T09:05:00.000", deviceId = "d").kind,
            )
        }
        val entries = CloudBackupIndexCodec.decodeIndex(String(transport.files[config.historyIndexRemotePath]!!, Charsets.UTF_8))
        assertEquals("Dart addEntry 去重口径：同哈希自动上传不新增条目", 1, entries.size)
    }

    // ---------- 兼容边界 ----------

    @Test
    fun `兼容_本壳旧格式云端_无meta有legacy指针仍能拉取`() {
        val transport = FakeRemoteTransport()
        val remoteOld = buildSyncSnapshotBytes(profileId = "pOldShell")
        transport.files[config.snapshotRemotePath] = remoteOld // 本壳旧版只写这个指针
        val localBytes = buildSyncSnapshotBytes(profileId = "pLocal")
        val localHash = WebdavSyncCoordinator.snapshotContentHash(localBytes)
        val store = FakeLocalSnapshotStore(initial = localBytes)
        val controller = CloudSyncController(
            // 基线钉在本地旧值：模拟「同步过、旧壳那台之后又推了一版」（否则是首同步分歧，会挂冲突）。
            store = FakeConfigStore(
                config = WebdavSyncConfig().copyWith(
                    lastAppliedRemoteHash = localHash,
                    lastUploadedLocalHash = localHash,
                ),
            ),
            snapshotStore = store,
            transportFactory = { _, _ -> transport },
            clock = { "2026-03-07T09:05:00+08:00" },
            snapshotApplier = { SnapshotApplyResult.Applied },
            undoStore = CloudSyncUndoStore(),
        )
        controller.connect("me@example.com", "pw")

        assertEquals(SyncResultKind.DOWNLOADED, controller.syncNow())

        assertArrayEquals(remoteOld, store.stored)
    }

    @Test
    fun `兼容_Flutter旧格式历史_无index的backup命名文件能被重建识别`() {
        val transport = FakeRemoteTransport()
        // Flutter 端 index 丢失后的残局：只有 history/backup-*.mikcb（Dart 旧命名）。
        val oldBackup = buildSyncSnapshotBytes(exportedAt = "2026-01-15T08:00:00.000", profileId = "pOld")
        transport.files["${history}backup-20260115-080000-abcdef12.mikcb"] = oldBackup

        val outcome = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore()).listRemoteBackups(config)

        assertEquals(SyncOpKind.OK, outcome.kind)
        val file = outcome.files.single()
        assertEquals("backup-20260115-080000-abcdef12.mikcb", file.fileName)
        assertEquals(WebdavSyncCoordinator.snapshotContentHash(oldBackup), file.contentSha256)
    }

    @Test
    fun `兼容_解析不出时间的文件绝不删`() {
        val transport = FakeRemoteTransport()
        // 体不是合法快照：重建认不出（不进索引、不显示），但文件必须原地保留。
        transport.files["${history}mystery.mikcb"] = "不可识别的字节".toByteArray()
        val coordinator = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore())
        val bytes = buildSyncSnapshotBytes(exportedAt = "2026-11-01T09:00:00.000")
        assertEquals(
            SyncOpKind.OK,
            coordinator.uploadSnapshot(
                WebdavSyncConfig(maxBackupCount = 1), bytes,
                exportedAtIso = "2026-11-01T09:00:00.000", deviceId = "d",
            ).kind,
        )
        assertTrue(
            "不认识的远端文件绝不能被本壳删掉",
            transport.files.containsKey("${history}mystery.mikcb"),
        )
    }

    @Test
    fun `兼容_index损坏从listing重建_瞬时错误不用空索引顶掉好索引`() {
        val transport = FakeRemoteTransport()
        transport.files[config.historyIndexRemotePath] = "{broken".toByteArray()
        transport.files["${history}good.mikcb"] = buildSyncSnapshotBytes()

        val coordinator = WebdavSyncCoordinator(transport, FakeLocalSnapshotStore())
        assertEquals(SyncOpKind.OK, coordinator.listRemoteBackups(config).kind)

        // listing 也坏了：宁可失败，也不把「网络错误」当「空云端」。
        val broken = FakeRemoteTransport()
        broken.listResultOverride = com.mutx163.qingyu.sync.HistoryListResult.failed("connection_failed")
        broken.files[config.historyIndexRemotePath] = "{broken".toByteArray()
        val outcome = WebdavSyncCoordinator(broken, FakeLocalSnapshotStore()).listRemoteBackups(config)
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("connection_failed", outcome.errorCode)
    }

    @Test
    fun `兼容_拉取冲突仍然挂起给用户选边_绝不静默覆盖`() {
        val transport = FakeRemoteTransport()
        seedFlutterCloud(transport, buildSyncSnapshotJson(exportedAt = "2026-11-01T09:15:00.000Z"))
        val store = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pLocal"))
        val controller = CloudSyncController(
            store = FakeConfigStore(), // 双基线空 → 首次同步分歧
            snapshotStore = store,
            transportFactory = { _, _ -> transport },
            clock = { "2026-11-01T18:00:00+08:00" },
            snapshotApplier = { SnapshotApplyResult.Applied },
            undoStore = CloudSyncUndoStore(),
        )
        controller.connect("me@example.com", "pw")

        assertEquals(SyncResultKind.CANCELLED, controller.syncNow())

        val conflict = controller.pendingSyncConflict
        assertNotNull("首次分歧必须挂起等用户选边", conflict)
        assertTrue(conflict!!.isFirstSyncDivergence)
        // 挂起期间两端原地不动。
        assertArrayEquals(buildSyncSnapshotBytes(profileId = "pLocal"), store.stored)
        assertEquals(0, store.writeCount)
        // 选「使用云端」后正常落地。
        assertEquals(SyncResultKind.DOWNLOADED, controller.resolveSyncConflict(SyncConflictChoice.KEEP_REMOTE))
        assertEquals(1, store.writeCount)
    }
}
