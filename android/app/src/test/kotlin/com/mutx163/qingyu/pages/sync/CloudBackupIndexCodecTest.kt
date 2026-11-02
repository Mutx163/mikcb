package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.WebdavSyncConfig
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `history/index.json` / `snapshot.meta.json` 编解码 + Dart 历史命名 + 保留策略单测。
 *
 * ## 样本来源（互通的硬要求）
 * 「Flutter 格式的样本」在这里是**手工按 Dart 实现逐字构造的字面量**：
 * - index 样本按 `lib/services/cloud_backup_index_service.dart` 的
 *   `CloudBackupIndex.toJson` / `CloudBackupEntry.toJson` 键序，用 Dart
 *   `JsonEncoder.withIndent('  ')` 的输出形态写成字符串字面量；
 * - meta 样本按 `lib/services/app_sync_snapshot_service.dart` 的
 *   `AppSyncSnapshotMeta.toJson`。
 * 本壳写出方向的反向验证：用 `MiniJson.encode` 生成字节 → 再按 Dart 读取口径
 * （fromJson 缺省值 / 键存在性）逐字段断言。
 */
class CloudBackupIndexCodecTest {

    private val zone = ZoneId.of("Asia/Shanghai")

    // ---------- Dart 历史命名 ----------

    @Test
    fun `buildBackupId_本地墙上时刻加哈希前8位`() {
        val id = CloudBackupIndexCodec.buildBackupId(
            exportedAtIso = "2026-11-02T20:33:12.000",
            contentSha256 = "abcdef1234567890",
            zone = zone,
        )
        assertEquals("20261102-203312-abcdef12", id)
        assertEquals("20261102-203312-abcdef12.mikcb", CloudBackupIndexCodec.buildBackupFileName(id))
    }

    @Test
    fun `buildBackupId_带时区串转本地时刻`() {
        // 2026-11-02T12:33:12Z = 上海时间 20:33:12。
        val id = CloudBackupIndexCodec.buildBackupId(
            exportedAtIso = "2026-11-02T12:33:12.000Z",
            contentSha256 = "abcdef1234567890",
            zone = zone,
        )
        assertEquals("20261102-203312-abcdef12", id)
    }

    @Test
    fun `buildBackupId_哈希不足8位用全长_时间解不出回落纪元`() {
        assertEquals(
            "19700101-080000-ab",
            CloudBackupIndexCodec.buildBackupId("not-a-time", "ab", zone),
        )
    }

    // ---------- index.json：本壳写出 → Flutter 读取口径 ----------

    @Test
    fun `encodeIndex_键序与条件省略对齐Dart_toJson`() {
        val full = CloudBackupEntryModel(
            id = "20261102-203312-abcdef12",
            fileName = "20261102-203312-abcdef12.mikcb",
            exportedAtIso = "2026-11-02T20:33:12.000",
            contentSha256 = "abcdef1234567890",
            deviceId = "devA",
            deviceLabel = "Pixel",
            appVersion = "1.2.3",
            isCurrent = true,
            source = CloudBackupSource.MANUAL,
            profileCount = 2,
            courseCount = 30,
        )
        val minimal = full.copy(appVersion = null, profileCount = null, courseCount = null)

        val root = MiniJson.parse(String(CloudBackupIndexCodec.encodeIndex(listOf(full, minimal)))) as Map<*, *>
        assertEquals(1L, (root["version"] as Number).toLong())
        val entries = root["entries"] as List<*>
        assertEquals(2, entries.size)

        val fullJson = entries[0] as Map<*, *>
        // Dart CloudBackupEntry.toJson 的键序（cloud_backup_index_service.dart:32-44）。
        assertEquals(
            listOf("id", "fileName", "exportedAt", "contentSha256", "deviceId", "deviceLabel",
                "appVersion", "isCurrent", "source", "profileCount", "courseCount"),
            fullJson.keys.toList(),
        )
        assertEquals("manual", fullJson["source"])
        assertEquals(true, fullJson["isCurrent"])
        // 可空键缺省时 Dart 条件不写（:39/:42-43），本壳同样不写。
        val minimalJson = entries[1] as Map<*, *>
        assertFalse(minimalJson.containsKey("appVersion"))
        assertFalse(minimalJson.containsKey("profileCount"))
        assertFalse(minimalJson.containsKey("courseCount"))
        // Flutter 端 `(json['profileCount'] as num?)?.toInt()` 读到 null。
        assertNull(minimalJson["profileCount"])
    }

    @Test
    fun `decodeIndex_Flutter格式样本逐字段读出`() {
        // 按 Dart JsonEncoder.withIndent('  ') 的输出形态手工构造（键序=toJson 键序）。
        val flutterSample = """
            {
              "version": 1,
              "entries": [
                {
                  "id": "20261101-091500-12345678",
                  "fileName": "20261101-091500-12345678.mikcb",
                  "exportedAt": "2026-11-01T09:15:00.000",
                  "contentSha256": "1234567890abcdef",
                  "deviceId": "flutter-dev-1",
                  "deviceLabel": "Mi 14",
                  "appVersion": "2.0.1",
                  "isCurrent": true,
                  "source": "auto",
                  "profileCount": 3,
                  "courseCount": 45
                },
                {
                  "id": "20261030-180001-87654321",
                  "fileName": "20261030-180001-87654321.mikcb",
                  "exportedAt": "2026-10-30T18:00:01.000Z",
                  "contentSha256": "87654321abcdef90",
                  "deviceId": "flutter-dev-2",
                  "deviceLabel": "",
                  "isCurrent": false,
                  "source": "manual"
                }
              ]
            }
        """.trimIndent()

        val entries = CloudBackupIndexCodec.decodeIndex(flutterSample)

        assertEquals(2, entries.size)
        val first = entries[0]
        assertEquals("20261101-091500-12345678", first.id)
        assertEquals("20261101-091500-12345678.mikcb", first.fileName)
        assertEquals("2026-11-01T09:15:00.000", first.exportedAtIso)
        assertEquals("1234567890abcdef", first.contentSha256)
        assertEquals("flutter-dev-1", first.deviceId)
        assertEquals("Mi 14", first.deviceLabel)
        assertEquals("2.0.1", first.appVersion)
        assertTrue(first.isCurrent)
        assertEquals(CloudBackupSource.AUTO, first.source)
        assertEquals(3, first.profileCount)
        assertEquals(45, first.courseCount)
        // 缺省可空键 → null（Dart fromJson orElse 口径）。
        val second = entries[1]
        assertNull(second.appVersion)
        assertNull(second.profileCount)
        assertNull(second.courseCount)
        assertEquals(CloudBackupSource.MANUAL, second.source)
        assertEquals("", second.deviceLabel)
    }

    @Test
    fun `decodeIndex_根不是对象或entries缺失给空索引`() {
        assertTrue(CloudBackupIndexCodec.decodeIndex("\"just a string\"").isEmpty())
        assertTrue(CloudBackupIndexCodec.decodeIndex("{\"version\":1}").isEmpty())
        assertTrue(CloudBackupIndexCodec.decodeIndex("{\"entries\":\"not-a-list\"}").isEmpty())
        assertTrue(CloudBackupIndexCodec.decodeIndex("not json at all").isEmpty())
    }

    @Test
    fun `decodeIndex_非Map条目跳过_未知来源回落auto`() {
        val sample = """
            {"version":1,"entries":[
              {"id":"a","fileName":"a.mikcb","exportedAt":"2026-11-01T09:15:00.000",
               "contentSha256":"h1","deviceId":"d","deviceLabel":"","isCurrent":false,"source":"weird"},
              42,
              {"id":"b","fileName":"b.mikcb","exportedAt":"2026-11-02T09:15:00.000",
               "contentSha256":"h2","deviceId":"d","deviceLabel":"","isCurrent":true,"source":"auto"}
            ]}
        """.trimIndent()
        val entries = CloudBackupIndexCodec.decodeIndex(sample)
        assertEquals(2, entries.size)
        assertEquals(CloudBackupSource.AUTO, entries[0].source)
        assertEquals("b", entries[1].id)
    }

    @Test
    fun `index_roundTrip_编解码还原条目`() {
        val entry = CloudBackupEntryModel(
            id = "id-1",
            fileName = "id-1.mikcb",
            exportedAtIso = "2026-11-02T20:00:00.000",
            contentSha256 = "hash-1",
            deviceId = "dev",
            deviceLabel = "label",
            isCurrent = true,
            source = CloudBackupSource.MANUAL,
            profileCount = 1,
            courseCount = 2,
        )
        val decoded = CloudBackupIndexCodec.decodeIndex(
            String(CloudBackupIndexCodec.encodeIndex(listOf(entry))), // UTF-8 往返
        )
        assertEquals(listOf(entry), decoded)
    }

    // ---------- index 条目纯操作 ----------

    @Test
    fun `addEntry_同哈希非手动不新增只重标当前版本`() {
        val existing = listOf(entry("old", hash = "h-old"))
        val incoming = entry("new", hash = "h-old")

        val next = CloudBackupIndexCodec.addEntry(
            entries = existing,
            entry = incoming,
            currentContentSha256 = "h-old",
            allowDuplicateHash = false,
        )

        assertEquals(1, next.size)
        assertEquals("old", next.single().id)
        assertTrue(next.single().isCurrent)
    }

    @Test
    fun `addEntry_手动允许重复哈希_同id替换`() {
        val existing = listOf(entry("dup", hash = "h1").copy(isCurrent = true))
        val incoming = entry("dup", hash = "h1")

        val next = CloudBackupIndexCodec.addEntry(
            entries = existing,
            entry = incoming,
            currentContentSha256 = "h1",
            allowDuplicateHash = true,
        )

        assertEquals(1, next.size)
        assertEquals("dup", next.single().id)
    }

    @Test
    fun `markCurrent与removeEntry`() {
        val entries = listOf(entry("a", hash = "ha"), entry("b", hash = "hb"))
        assertEquals(
            listOf(true, false),
            CloudBackupIndexCodec.markCurrent(entries, "ha").map { it.isCurrent },
        )
        assertEquals(listOf("b"), CloudBackupIndexCodec.removeEntry(entries, "a").map { it.id })
    }

    // ---------- 保留策略（新命名 / 索引驱动下仍正确） ----------

    private val dayMillis = 24L * 60L * 60L * 1000L
    private val nowMillis = 1_800_000_000_000L

    private fun entry(
        id: String,
        hash: String = "hash-$id",
        ageMillis: Long = dayMillis,
        source: CloudBackupSource = CloudBackupSource.AUTO,
        isCurrent: Boolean = false,
        exportedAtIso: String? = null,
    ): CloudBackupEntryModel = CloudBackupEntryModel(
        id = id,
        fileName = "$id.mikcb",
        exportedAtIso = exportedAtIso ?: java.time.Instant.ofEpochMilli(nowMillis - ageMillis).toString(),
        contentSha256 = hash,
        deviceId = "dev",
        deviceLabel = "",
        isCurrent = isCurrent,
        source = source,
    )

    @Test
    fun `prune_超上限删最旧_当前版本豁免`() {
        val config = WebdavSyncConfig(maxBackupCount = 2)
        val removed = CloudBackupIndexCodec.planHistoryPrune(
            entries = listOf(
                entry("old", ageMillis = 3 * dayMillis),
                entry("mid", ageMillis = 2 * dayMillis),
                entry("new", ageMillis = dayMillis, isCurrent = true),
            ),
            config = config,
            nowMillis = nowMillis,
        )
        assertEquals(listOf("old"), removed.map { it.id })
    }

    @Test
    fun `prune_手动备份受保护_索引来源生效`() {
        val config = WebdavSyncConfig(maxBackupCount = 1, manualBackupProtected = true)
        val removed = CloudBackupIndexCodec.planHistoryPrune(
            entries = listOf(
                entry("manual", ageMillis = 10 * dayMillis, source = CloudBackupSource.MANUAL),
                entry("auto1", ageMillis = 5 * dayMillis),
                entry("auto2", ageMillis = dayMillis, isCurrent = true),
            ),
            config = config,
            nowMillis = nowMillis,
        )
        // current + 受保护手动都豁免，被挤掉的是 auto1。
        assertEquals(listOf("auto1"), removed.map { it.id })
    }

    @Test
    fun `prune_超过天数上限删除_关闭保护后手动参与淘汰`() {
        val expiry = WebdavSyncConfig(maxBackupCount = 30, maxBackupAgeDays = 7)
        assertEquals(
            listOf("expired"),
            CloudBackupIndexCodec.planHistoryPrune(
                entries = listOf(
                    entry("expired", ageMillis = 8 * dayMillis),
                    entry("fresh", ageMillis = dayMillis, isCurrent = true),
                ),
                config = expiry,
                nowMillis = nowMillis,
            ).map { it.id },
        )
        val noProtect = WebdavSyncConfig(maxBackupCount = 1, manualBackupProtected = false)
        assertEquals(
            listOf("manual"),
            CloudBackupIndexCodec.planHistoryPrune(
                entries = listOf(
                    entry("manual", ageMillis = 10 * dayMillis, source = CloudBackupSource.MANUAL),
                    entry("current", ageMillis = dayMillis, isCurrent = true),
                ),
                config = noProtect,
                nowMillis = nowMillis,
            ).map { it.id },
        )
    }

    @Test
    fun `prune_解析不出时间的条目绝不删也不占名额`() {
        val config = WebdavSyncConfig(maxBackupCount = 1, maxBackupAgeDays = 7)
        val removed = CloudBackupIndexCodec.planHistoryPrune(
            entries = listOf(
                entry("foreign", exportedAtIso = "not-a-time"),
                entry("current", ageMillis = dayMillis, isCurrent = true),
            ),
            config = config,
            nowMillis = nowMillis,
        )
        assertTrue(removed.isEmpty())
    }

    // ---------- snapshot.meta.json ----------

    @Test
    fun `buildMetaBytes_键序与Dart一致且能被parseSnapshotMetaFields读回`() {
        val bytes = CloudBackupIndexCodec.buildMetaBytes(
            exportedAtIso = "2026-11-02T20:33:12.000",
            contentSha256 = "hash-abc",
            deviceId = "devA",
            appVersion = "1.2.3",
            snapshotPath = "/Apps/qingyu-sync/snapshot-hash-abc-1700000000-devA.mikcb",
        )
        val parsed = MiniJson.parse(String(bytes)) as Map<*, *>
        assertEquals(
            listOf("exportedAt", "contentSha256", "deviceId", "appVersion", "snapshotPath"),
            parsed.keys.toList(),
        )
        // 用 Dart fromJson 的移植版读回（app_sync_snapshot_service.dart:222-240）。
        @Suppress("UNCHECKED_CAST")
        val meta = com.mutx163.qingyu.sync.parseSnapshotMetaFields(parsed as Map<String, Any?>)
        assertTrue(meta.isValid)
        assertEquals("hash-abc", meta.contentSha256)
        assertEquals("devA", meta.deviceId)
        assertEquals("1.2.3", meta.appVersion)
        assertEquals("/Apps/qingyu-sync/snapshot-hash-abc-1700000000-devA.mikcb", meta.snapshotPath)
    }

    @Test
    fun `buildMetaBytes_appVersion为空时省键_与Dart条件写入一致`() {
        val bytes = CloudBackupIndexCodec.buildMetaBytes(
            exportedAtIso = "2026-11-02T20:33:12.000",
            contentSha256 = "hash-abc",
            deviceId = "devA",
            appVersion = null,
            snapshotPath = "/p.mikcb",
        )
        val parsed = MiniJson.parse(String(bytes)) as Map<*, *>
        assertEquals(listOf("exportedAt", "contentSha256", "deviceId", "snapshotPath"), parsed.keys.toList())
    }

    @Test
    fun `Flutter格式meta样本能被读回`() {
        // AppSyncSnapshotMeta.toJson（app_sync_snapshot_service.dart:213-220）的输出形态。
        val flutterMeta = """
            {"exportedAt":"2026-11-01T09:15:00.000Z","contentSha256":"1234567890abcdef",
             "deviceId":"flutter-dev-1","appVersion":"2.0.1",
             "snapshotPath":"/Apps/qingyu-sync/snapshot-1234567890abcdef-1793587700000000000-flutter-dev-1.mikcb"}
        """.trimIndent()
        val result = com.mutx163.qingyu.sync.parseSnapshotMetaFields(
            MiniJson.parse(flutterMeta) as Map<String, Any?>,
        )
        assertTrue(result.isValid)
        assertEquals("1234567890abcdef", result.contentSha256)
        assertEquals("flutter-dev-1", result.deviceId)
        assertEquals("2.0.1", result.appVersion)
        assertTrue(result.snapshotPath!!.endsWith("flutter-dev-1.mikcb"))
    }

    // ---------- 快照计数 ----------

    @Test
    fun `countProfiles与countCourses_坏形回落0`() {
        val payload = mapOf(
            "profiles" to listOf(
                mapOf("courses" to listOf(1, 2, 3)),
                mapOf<String, Any?>("courses" to null),
                mapOf("courses" to listOf(4)),
            ),
        )
        assertEquals(3, CloudBackupIndexCodec.countProfilesInSnapshot(payload))
        assertEquals(4, CloudBackupIndexCodec.countCoursesInSnapshot(payload))
        assertEquals(0, CloudBackupIndexCodec.countProfilesInSnapshot(mapOf("profiles" to "bad")))
        assertEquals(0, CloudBackupIndexCodec.countCoursesInSnapshot(emptyMap()))
    }
}
