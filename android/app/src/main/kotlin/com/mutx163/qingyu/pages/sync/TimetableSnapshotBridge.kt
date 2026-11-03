package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.sync.SNAPSHOT_APP_ID
import com.mutx163.qingyu.sync.SNAPSHOT_BACKUP_TYPE
import com.mutx163.qingyu.sync.SNAPSHOT_SCHEMA_VERSION
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decodeSnapshotObject

/**
 * 课表仓储 ⇄ 云同步快照字节的**桥**（修「立即备份必然失败 / 恢复点了没效果」）。
 *
 * ## 它补的是什么（两个 P0 的共同根因）
 *
 * 接线前上传读的是 `LocalSnapshotStore.readSnapshot()`，而生产代码**从未写过**这个文件；
 * 恢复则只把下载字节写进同一个文件，**全仓没有代码把它写回仓储**。于是：
 * - 「立即备份 / 立即同步」永远拿不到字节 → 必然失败；
 * - 「恢复」即使下载成功，课表也一点没变 → 提示成功但数据没动。
 *
 * 本对象是这两条路唯一的翻译层：仓储 → 快照 JSON 字节（上传用），快照字节 → 仓储（恢复用）。
 * 信封 / 校验和口径直接复用 `sync/AppSyncSnapshotCodec.kt`，不另造一套。
 *
 * ## 诚实边界（仍未做，别当成已完工）
 *
 * 1. 快照只带**课表族**（档案 / 作息表 / 日期规则 / 地点分组）。Dart 快照里的
 *    warehouse / macros / customHolidays / teacherRecords / partnerTimetableBinding
 *    在这里不开采——Dart 端读这份快照时这几块会是空，反之亦然。
 * 2. 档案内嵌的 `settings` 只有 core 四键（`TimetableSettings.toJson()` 的移植边界）。
 *    恢复时 `TimetableStore.saveProfiles` 会按 id 把旧档案的其余设置铺底保留，
 *    所以不会清掉用户的其它设置，但也**不会**从快照里恢复它们。
 * 3. 没有差异预览：恢复是整份覆盖。
 */
object TimetableSnapshotBridge {

    /** 上传侧：本机当前课表 → 快照字节。 */
    fun buildSnapshotBytes(
        repository: TimetableRepository,
        deviceId: String,
        exportedAtIso: String,
    ): SnapshotBuildResult {
        val snapshot = repository.snapshot
        if (snapshot.profiles.isEmpty()) {
            // 没有档案 = 没有可同步的用户数据。**不产出空包**：那会把云端好数据顶成空壳。
            return SnapshotBuildResult.NoLocalData
        }
        val payload = linkedMapOf<String, Any?>(
            "app" to SNAPSHOT_APP_ID,
            "schemaVersion" to SNAPSHOT_SCHEMA_VERSION,
            "backupType" to SNAPSHOT_BACKUP_TYPE,
            "exportedAt" to exportedAtIso,
            "deviceId" to deviceId,
            "activeProfileId" to snapshot.activeProfileId,
            "profiles" to snapshot.profiles.map { it.toJson() },
            "timeSchemes" to snapshot.timeSchemes.map { it.toJson() },
            "locationTimeGroups" to snapshot.locationTimeGroups.map { it.toJsonMap() },
            "scheduleDateRules" to snapshot.scheduleDateRules.map { it.toJson() },
            // 顶层设置是 Compose 侧的扩展键（Dart 快照没有这个键，它的设置内嵌在档案里）。
            // 有了它，「恢复」才能如实还原用户改过、但还没写进档案的那批核心设置；
            // Dart 解析时按未知键忽略，不影响互通。
            "settings" to snapshot.settings.toJson(),
        )
        // 与 BackupFileWriteLogic / Dart buildSnapshotJsonFromSnapshot 同口径：写重算值。
        payload["contentSha256"] = computeContentSha256(payload)
        return try {
            SnapshotBuildResult.Success(MiniJson.encode(payload).toByteArray(Charsets.UTF_8))
        } catch (error: Exception) {
            SnapshotBuildResult.Failure("sync_snapshot_serialize_failed")
        }
    }

    /** 恢复侧：快照字节 → 仓储（整份覆盖，写回成功后仓储只通知一次）。 */
    fun applySnapshot(repository: TimetableRepository, bytes: ByteArray): SnapshotApplyResult {
        val json = try {
            decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        } catch (error: Exception) {
            return SnapshotApplyResult.Invalid(error.message ?: "invalid_sync_snapshot_payload")
        }
        val envelope = checkSnapshotEnvelopeAndChecksum(json)
        if (!envelope.isValid) {
            return SnapshotApplyResult.Invalid(envelope.errorCode ?: "invalid_sync_snapshot_payload")
        }
        val rawProfiles = json["profiles"] as? List<*> ?: emptyList<Any?>()
        val profiles = TimetableProfile.parseProfilesPayload(rawProfiles).profiles
        // Dart parseSnapshotJson :601-607 的核心负载「全损」门：集合非空、但一条有效
        // 记录都没解出来 → 核心负载损坏。不能当「空课表」放行（否则整份覆盖会把
        // 用户课表清空），也别错报成 sync_snapshot_no_profiles。
        if (rawProfiles.isNotEmpty() && profiles.isEmpty()) {
            return SnapshotApplyResult.Invalid("missing_sync_timetable_data")
        }
        if (profiles.isEmpty()) {
            return SnapshotApplyResult.Invalid("sync_snapshot_no_profiles")
        }
        val rawTimeSchemes = json["timeSchemes"] as? List<*> ?: emptyList<Any?>()
        val timeSchemes = parseLenient(json["timeSchemes"]) { TimeScheme.fromJson(it) }
        if (rawTimeSchemes.isNotEmpty() && timeSchemes.isEmpty()) {
            return SnapshotApplyResult.Invalid("missing_sync_timetable_data")
        }
        val scheduleDateRules = parseLenient(json["scheduleDateRules"]) { ScheduleDateRule.fromJson(it) }
        val locationTimeGroups = parseLenient(json["locationTimeGroups"]) { LocationTimeGroup.fromJson(it) }
        val activeProfileId = json["activeProfileId"] as? String
        val settings = (json["settings"] as? Map<*, *>)?.let { raw ->
            @Suppress("UNCHECKED_CAST")
            runCatching { TimetableSettings.fromJson(raw as Map<String, Any?>) }.getOrNull()
        }
        return try {
            repository.restoreFromCloudSnapshot(
                profiles = profiles,
                activeProfileId = activeProfileId,
                timeSchemes = timeSchemes,
                scheduleDateRules = scheduleDateRules,
                locationTimeGroups = locationTimeGroups,
                settings = settings,
            )
            SnapshotApplyResult.Applied
        } catch (error: Exception) {
            SnapshotApplyResult.Failed("sync_snapshot_apply_failed")
        }
    }

    /** 逐条宽松解析：非 Map / 解析抛错的条目丢弃，不让一条坏数据炸掉整份恢复。 */
    private inline fun <T> parseLenient(raw: Any?, parse: (Map<String, Any?>) -> T): List<T> {
        val list = raw as? List<*> ?: return emptyList()
        val out = ArrayList<T>(list.size)
        for (item in list) {
            if (item !is Map<*, *>) continue
            @Suppress("UNCHECKED_CAST")
            val map = item as Map<String, Any?>
            try {
                out.add(parse(map))
            } catch (_: Exception) {
                // 与 TimetableStore 的读侧同口径：坏条目丢弃，其余照常。
            }
        }
        return out
    }
}

/** 构建快照字节的结局。 */
sealed interface SnapshotBuildResult {
    data class Success(val bytes: ByteArray) : SnapshotBuildResult

    /** 本机没有用户数据：不应上传（否则会把云端好数据覆盖成空壳）。 */
    data object NoLocalData : SnapshotBuildResult

    /** 序列化失败等，不产出空包。 */
    data class Failure(val errorCode: String) : SnapshotBuildResult
}

/** 快照写回仓储的结局。 */
sealed interface SnapshotApplyResult {
    data object Applied : SnapshotApplyResult

    /** 字节不是一份可信的快照（信封 / 校验和 / 无档案）。 */
    data class Invalid(val errorCode: String) : SnapshotApplyResult

    /** 内容可信，但落盘 / 写回仓储失败。 */
    data class Failed(val errorCode: String) : SnapshotApplyResult
}
