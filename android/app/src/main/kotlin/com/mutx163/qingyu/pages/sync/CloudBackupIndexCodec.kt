package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.snapshotMetaToJson
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

/**
 * 云备份 `history/index.json` 与 `snapshot.meta.json` 的**编解码 + 命名 + 纯操作**
 * （协议互通第 2 段：本壳与 Flutter 版共盘的格式合同）。
 *
 * Dart 对拍锚点（逐字对齐，键序/默认值/失败回落不许偏）：
 * - `lib/services/cloud_backup_index_service.dart`：`CloudBackupIndex.toJson/fromJson`、
 *   `CloudBackupEntry.toJson/fromJson`、`buildBackupId`、`buildBackupFileName`、
 *   `addEntry`/`markCurrent`/`removeEntry`、`countProfilesInSnapshotJson`/`countCoursesInSnapshotJson`；
 * - `lib/services/app_sync_snapshot_service.dart`：`AppSyncSnapshotMeta.toJson`
 *   （exportedAt/contentSha256/deviceId/appVersion?/snapshotPath?，snapshotPath 空白不写）；
 * - `lib/services/webdav_sync_service.dart`：`_loadRemoteBackupIndex` 的重建分支
 *   （id = 文件名去 `.mikcb`、坏体跳过）。
 *
 * 有意偏差（都偏保守，互通不受影响）：
 * 1. `decodeIndex` 的单条解析失败回落与 Dart `CloudBackupEntry.fromJson` 一致
 *    （缺字段给空/纪元），但**整根解析失败**时 Dart 的 `_loadRemoteBackupIndex`
 *    会先把「可读性」判成 failed 再走恢复；这里只负责给空列表，恢复决策在协调器。
 * 2. `exportedAt` 解析失败：Dart `fromJson` 回落纪元 0；本侧同样保留原字符串、
 *    由 `CloudBackupListLogic.parseExportedAtMillis` 统一回落 0——保留策略据此
 *    「解析不出时间的绝不删」（比 Dart 的「纪元 0 会被过期淘汰」更保守）。
 * 3. `encodeIndex` 用 `MiniJson.encode`（紧凑单行）；Dart 用 2 空格缩进。
 *    JSON 语义等价，两端解析结果一致。
 */
object CloudBackupIndexCodec {

    /** Dart `CloudBackupIndex.schemaVersion`。 */
    const val SCHEMA_VERSION = 1

    /** Dart `buildBackupId`：导出时刻的**本地墙上时刻** `yyyyMMdd-HHmmss` + `-` + 哈希前 8 位。 */
    fun buildBackupId(
        exportedAtIso: String,
        contentSha256: String,
        zone: ZoneId = ZoneId.systemDefault(),
    ): String {
        val local = parseExportedAtLocal(exportedAtIso, zone)
        val timestamp = "${pad(local.year, 4)}${pad(local.monthValue, 2)}${pad(local.dayOfMonth, 2)}-" +
            "${pad(local.hour, 2)}${pad(local.minute, 2)}${pad(local.second, 2)}"
        val hashSuffix = if (contentSha256.length >= 8) contentSha256.substring(0, 8) else contentSha256
        return "$timestamp-$hashSuffix"
    }

    /** Dart `buildBackupFileName`。 */
    fun buildBackupFileName(backupId: String): String = "$backupId.mikcb"

    // ---------- index.json ----------

    /**
     * 单条 → Dart `CloudBackupEntry.toJson` 键序原样：
     * id / fileName / exportedAt / contentSha256 / deviceId / deviceLabel /
     * appVersion? / isCurrent / source / profileCount? / courseCount?。
     * 三个可空键在 Dart 是条件写入（null 不写键），这里同样剔除。
     */
    fun entryToJson(entry: CloudBackupEntryModel): LinkedHashMap<String, Any?> {
        val out = linkedMapOf(
            "id" to entry.id,
            "fileName" to entry.fileName,
            "exportedAt" to entry.exportedAtIso,
            "contentSha256" to entry.contentSha256,
            "deviceId" to entry.deviceId,
            "deviceLabel" to entry.deviceLabel,
            "appVersion" to entry.appVersion,
            "isCurrent" to entry.isCurrent,
            "source" to entry.source.wire,
            "profileCount" to entry.profileCount,
            "courseCount" to entry.courseCount,
        )
        return out.filterValues { it != null } as LinkedHashMap<String, Any?>
    }

    /**
     * Dart `CloudBackupIndex.toJson`：`{"version": 1, "entries": [...]}`。
     * 单条缺失的 `appVersion`/`profileCount`/`courseCount`：Dart 条件写入（null 不写键），
     * 这里同样删掉 null 键，保证 Flutter 端 `as String?` / `as num?` 读到的就是 null。
     */
    fun encodeIndex(entries: List<CloudBackupEntryModel>): ByteArray {
        val root = linkedMapOf<String, Any?>(
            "version" to SCHEMA_VERSION,
            "entries" to entries.map { entryToJson(it) },
        )
        return MiniJson.encode(root).toByteArray(Charsets.UTF_8)
    }

    /**
     * Dart `CloudBackupIndex.fromJson`：根不是 Map / `entries` 不是 List → 空索引；
     * 单条不是 Map 跳过；单条解析按 [CloudBackupEntryModel.fromJson] 的缺省口径
     * （缺字段给空/纪元，source 未知回落 auto）。
     */
    fun decodeIndex(content: String): List<CloudBackupEntryModel> {
        val decoded = try {
            MiniJson.parse(content)
        } catch (_: Exception) {
            return emptyList()
        }
        if (decoded !is Map<*, *>) return emptyList()
        val rawEntries = decoded["entries"] ?: return emptyList()
        if (rawEntries !is List<*>) return emptyList()
        return rawEntries.filterIsInstance<Map<*, *>>().map { item ->
            @Suppress("UNCHECKED_CAST")
            val map = item as Map<String, Any?>
            CloudBackupEntryModel.fromJson(map)
        }
    }

    // ---------- index 条目纯操作（Dart CloudBackupIndexService 同名方法） ----------

    /** Dart `markCurrent`：`isCurrent` 只落在内容哈希等于当前版本的那条上。 */
    fun markCurrent(
        entries: List<CloudBackupEntryModel>,
        currentContentSha256: String,
    ): List<CloudBackupEntryModel> = entries.map {
        it.copy(isCurrent = it.contentSha256 == currentContentSha256)
    }

    /**
     * Dart `addEntry`：非手动上传时若索引里已有同哈希条目，**不新增**、只重标当前版本
     * （自动同步同一份内容反复传，历史里不堆重复条目）；手动允许重复哈希。
     */
    fun addEntry(
        entries: List<CloudBackupEntryModel>,
        entry: CloudBackupEntryModel,
        currentContentSha256: String,
        allowDuplicateHash: Boolean,
    ): List<CloudBackupEntryModel> {
        if (!allowDuplicateHash && entries.any { it.contentSha256 == entry.contentSha256 }) {
            return markCurrent(entries, currentContentSha256)
        }
        val normalized = entry.copy(isCurrent = entry.contentSha256 == currentContentSha256)
        val next = ArrayList<CloudBackupEntryModel>(entries.size + 1)
        next.add(normalized)
        for (existing in entries) {
            if (existing.id != normalized.id) next.add(existing)
        }
        return markCurrent(next, currentContentSha256)
    }

    /** Dart `removeEntry`：按 id 删。 */
    fun removeEntry(entries: List<CloudBackupEntryModel>, entryId: String): List<CloudBackupEntryModel> =
        entries.filter { it.id != entryId }

    /**
     * 保留策略（Dart `CloudBackupIndexService.prune` 移植 + 一条保守护栏）：
     * 按导出时间倒序；当前版本 / 受保护手动备份豁免；其余「过期或超上限」即删。
     *
     * 保守护栏：导出时间解析不出（epoch 0）的条目**不参与计数也绝不删**。
     * Dart 索引里每条都有可用时间（纪元回落的条目会被当 1970 年清掉）；
     * 本壳不跟着删——索引可能来自别的工具，时间不可信时删等于赌。
     */
    fun planHistoryPrune(
        entries: List<CloudBackupEntryModel>,
        config: WebdavSyncConfig,
        nowMillis: Long,
        manualFileNames: Set<String> = emptySet(),
    ): List<CloudBackupEntryModel> {
        if (entries.isEmpty()) return emptyList()
        val dayMillis = 24L * 60L * 60L * 1000L
        val cutoff = nowMillis - config.maxBackupAgeDays * dayMillis
        val sorted = entries
            .map { it to entryMillis(it) }
            .filter { it.second > 0L }
            .sortedByDescending { it.second }
        val kept = ArrayList<CloudBackupEntryModel>(sorted.size)
        val removed = ArrayList<CloudBackupEntryModel>()
        for ((entry, millis) in sorted) {
            val isProtectedManual = config.manualBackupProtected &&
                (entry.source == CloudBackupSource.MANUAL || entry.fileName in manualFileNames)
            when {
                entry.isCurrent || isProtectedManual -> kept.add(entry)
                millis < cutoff || kept.size >= config.maxBackupCount -> removed.add(entry)
                else -> kept.add(entry)
            }
        }
        return removed
    }

    // ---------- snapshot.meta.json ----------

    /**
     * Dart `AppSyncSnapshotMeta.toJson` → JSON 字节（键序原样；snapshotPath 空白不写）。
     * 指向**不可变正文版本**：并发写者即使没有锁/ETag 也不会把别人的正文配上我们的 meta。
     */
    fun buildMetaBytes(
        exportedAtIso: String,
        contentSha256: String,
        deviceId: String,
        appVersion: String?,
        snapshotPath: String,
    ): ByteArray = MiniJson.encode(
        snapshotMetaToJson(exportedAtIso, contentSha256, deviceId, appVersion, snapshotPath),
    ).toByteArray(Charsets.UTF_8)

    // ---------- 快照计数（Dart countProfilesInSnapshotJson / countCoursesInSnapshotJson） ----------

    /** profiles 列表长度；缺/坏 → 0。 */
    fun countProfilesInSnapshot(payload: Map<String, Any?>): Int =
        (payload["profiles"] as? List<*>)?.size ?: 0

    /** 各 profile 的 courses 列表长度之和；缺/坏按 0 计。 */
    fun countCoursesInSnapshot(payload: Map<String, Any?>): Int {
        val profiles = payload["profiles"] as? List<*> ?: return 0
        var total = 0
        for (profile in profiles) {
            if (profile is Map<*, *> && profile["courses"] is List<*>) {
                total += (profile["courses"] as List<*>).size
            }
        }
        return total
    }

    // ---------- 内部 ----------

    fun entryMillis(entry: CloudBackupEntryModel, zone: ZoneId = ZoneId.systemDefault()): Long =
        CloudBackupListLogic.parseExportedAtMillis(entry.exportedAtIso, zone)

    /**
     * Dart `DateTime.tryParse` 的本地投影：带时区按瞬时转 [zone]，不带时区按当地墙上时刻。
     * 解析不了回落纪元 0（与 [CloudBackupListLogic.parseExportedAtMillis] 同口径）。
     */
    private fun parseExportedAtLocal(raw: String, zone: ZoneId): LocalDateTime {
        val text = raw.trim()
        if (text.isEmpty()) return LocalDateTime.ofInstant(Instant.ofEpochMilli(0L), zone)
        runCatching {
            return LocalDateTime.ofInstant(OffsetDateTime.parse(text).toInstant(), zone)
        }
        runCatching { return LocalDateTime.parse(text) }
        return LocalDateTime.ofInstant(Instant.ofEpochMilli(0L), zone)
    }

    private fun pad(value: Int, width: Int): String = value.toString().padStart(width, '0')
}
