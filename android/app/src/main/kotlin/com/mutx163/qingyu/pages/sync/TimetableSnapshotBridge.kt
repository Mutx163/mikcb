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
import com.mutx163.qingyu.sync.SnapshotUserDataSignals
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decodeSnapshotObject
import com.mutx163.qingyu.sync.selectSnapshotMacros
import com.mutx163.qingyu.sync.hasUserAuthoredData
import com.mutx163.qingyu.sync.matchesFactoryDefaultTimeScheme

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
 * 1. 快照带的课表族（档案 / 作息表 / 日期规则 / 地点分组）之外，另带 **宏录制**
 *    （`warehouse.macros`，P3 接上）。宏的编解码留在 warehouse 域，这里只当
 *    `List<Map<String, Any?>>` 放进去 / 回调原始列表出去（sync 模块不能反向依赖
 *    warehouse，否则 `-Module pages/sync` 的 L0 编不过）。Dart 快照里其余 warehouse
 *    偏好（记住的登录 / 自定义地址 / 最近学校 / 调试记录）、customHolidays /
 *    teacherRecords / partnerTimetableBinding 仍未开采——Dart 读这份快照时这几块会是空，
 *    反之亦然。
 * 2. 档案内嵌的 `settings` **按整份写入快照**（对齐 Dart `buildSnapshotJsonFromSnapshot`
 *    `app_sync_snapshot_service.dart:338-400`：每档序列化完整 profile）。写入前从磁盘取
 *    完整内嵌对象（`TimetableProfile.toJson()` 只有 core 4 键），再用内存模型覆盖 core 键。
 *    恢复时备份那份优先落盘（见 `TimetableStore.saveProfiles` 的 `preferredEmbeddedSettings`），
 *    不再被本机当前内嵌盖住；老备份内嵌只有 4 键时，本机其余键照旧铺底保留。
 * 3. 没有差异预览：恢复是整份覆盖。
 */
object TimetableSnapshotBridge {

    /** 上传侧：本机当前课表 → 快照字节。 */
    fun buildSnapshotBytes(
        repository: TimetableRepository,
        deviceId: String,
        exportedAtIso: String,
        /** 已存宏的 `toJson()` 列表；空表也照写，与 Dart 一致。 */
        macros: List<Map<String, Any?>> = emptyList(),
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
            // 档案要带走**完整内嵌 settings**（外观/语言/材质/桌面卡片等 250+ 键）。
            // 内存模型只有 core 4 键，整份设置只存在于磁盘档案里，故从这里取。
            "profiles" to snapshot.profiles.map { profile ->
                fullProfileJson(profile, repository.embeddedSettingsById()[profile.id])
            },
            "timeSchemes" to snapshot.timeSchemes.map { it.toJson() },
            "locationTimeGroups" to snapshot.locationTimeGroups.map { it.toJsonMap() },
            "scheduleDateRules" to snapshot.scheduleDateRules.map { it.toJson() },
            // 键位照 Dart `buildSnapshotJsonFromSnapshot`：宏在 `warehouse.macros` 下。
            // Dart 只把 warehouse 里**在场的子键**当数据（缺的类别不覆盖本地），
            // 所以这里只放 macros，Dart 恢复时不会误清它自己的仓库偏好。
            "warehouse" to linkedMapOf<String, Any?>(
                "macros" to macros,
            ),
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

    /**
     * 本机是否含**用户亲手沉淀**的课表数据（Dart `AppSyncSnapshot.hasUserAuthoredData`
     * 在 Kotlin 可观测域上的投影）。
     *
     * 用途同 Dart `resolveManualPullConflictChoice`：空壳本机（全新设备 / 只有出厂默认
     * 档案与默认作息）遇到云端有数据时不弹「选边」框，直接以云端为准——空壳没有可保护
     * 的本地内容，弹框只会让新用户以为同步出错。
     */
    fun localHasUserAuthoredData(repository: TimetableRepository): Boolean {
        val snapshot = repository.snapshot
        return hasUserAuthoredData(
            SnapshotUserDataSignals(
                locationTimeGroupsNotEmpty = snapshot.locationTimeGroups.isNotEmpty(),
                scheduleDateRulesNotEmpty = snapshot.scheduleDateRules.isNotEmpty(),
                timeSchemeCount = snapshot.timeSchemes.size,
                timeSchemeMatchesFactoryDefault = snapshot.timeSchemes.size == 1 &&
                    matchesFactoryDefaultTimeScheme(snapshot.timeSchemes.single()),
                profileCount = snapshot.profiles.size,
                profilesHaveCourses = snapshot.profiles.any { profile ->
                    profile.courses.isNotEmpty() ||
                        profile.tasks.isNotEmpty() ||
                        profile.exams.isNotEmpty() ||
                        profile.scheduleItems.isNotEmpty()
                },
                partnerImportedPresent = snapshot.profiles.any { it.isPartnerImported },
                renamedAwayFromDefaultPresent = snapshot.profiles.any { profile ->
                    profile.name.trim().isNotEmpty() &&
                        profile.name.trim() != TimetableRepository.DEFAULT_PROFILE_NAME
                },
            ),
        )
    }

    /**
     * 恢复侧：快照字节 → 仓储（整份覆盖，写回成功后仓储只通知一次）。
     *
     * [applyWarehouseMacros] 非空时同一趟把快照里的宏列表（原始 `List<*>`，可能为 null）
     * 交给调用方落库；抛错会按恢复失败上报（课表写入已生效，不静默吞）。为空则不动宏。
     */
    fun applySnapshot(
        repository: TimetableRepository,
        bytes: ByteArray,
        applyWarehouseMacros: ((Any?) -> Unit)? = null,
    ): SnapshotApplyResult {
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
        val warehouseMacros: Any? = if (applyWarehouseMacros != null) selectSnapshotMacros(json) else null
        // 备份里每档的完整内嵌设置：恢复时优先落盘，不被本机当前内嵌覆盖。
        val preferredEmbeddedSettings = embeddedSettingsFromProfiles(rawProfiles)
        return try {
            repository.restoreFromCloudSnapshot(
                profiles = profiles,
                activeProfileId = activeProfileId,
                timeSchemes = timeSchemes,
                scheduleDateRules = scheduleDateRules,
                locationTimeGroups = locationTimeGroups,
                settings = settings,
                preferredEmbeddedSettings = preferredEmbeddedSettings,
            )
            // 宏走 Dart 的整库覆盖语义：快照里没有宏（null/空表）也导入空表，
            // 即清空本地宏——云端没带宏就是「这份备份没有宏」，不能留下旧条目。
            applyWarehouseMacros?.invoke(warehouseMacros)
            SnapshotApplyResult.Applied
        } catch (error: Exception) {
            SnapshotApplyResult.Failed("sync_snapshot_apply_failed")
        }
    }

    /**
     * 档案 JSON 的**整份设置**：磁盘内嵌对象铺底，内存模型的 core 4 键覆盖。
     * 磁盘没有该档（或内嵌读不懂）时退回只有 core 4 键的原样 JSON。
     */
    private fun fullProfileJson(
        profile: TimetableProfile,
        embedded: Map<String, Any?>?,
    ): Map<String, Any?> {
        val json = LinkedHashMap<String, Any?>(profile.toJson())
        if (embedded == null) return json
        val merged = LinkedHashMap<String, Any?>(embedded)
        val core = json["settings"]
        if (core is Map<*, *>) {
            for ((key, value) in core) {
                if (key is String) merged[key] = value
            }
        }
        json["settings"] = merged
        return json
    }

    /** 从快照原始 profiles 提取每档完整内嵌 settings（id → 键值表）；读不懂的条目跳过。 */
    private fun embeddedSettingsFromProfiles(rawProfiles: List<*>): Map<String, Map<String, Any?>> {
        val out = LinkedHashMap<String, Map<String, Any?>>()
        for (item in rawProfiles) {
            if (item !is Map<*, *>) continue
            val id = item["id"] as? String ?: continue
            val settings = item["settings"]
            if (settings !is Map<*, *>) continue
            val copy = LinkedHashMap<String, Any?>()
            for ((key, value) in settings) {
                if (key is String) copy[key] = value
            }
            out[id] = copy
        }
        return out
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
