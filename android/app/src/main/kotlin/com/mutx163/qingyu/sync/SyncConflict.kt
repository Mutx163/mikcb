package com.mutx163.qingyu.sync

import java.security.MessageDigest

/**
 * 快照合并判据 / 冲突检测 / 内容哈希纯逻辑。
 *
 * 源：
 * - lib/services/app_sync_snapshot_service.dart（computeContentSha256、
 *   hasUserAuthoredData、SyncConflict*、decideWebdavAutoUpload、
 *   webdavPullHasSyncConflict、webdavBackgroundPullShouldCancel、
 *   resolveManualPullConflictChoice、stripLiveTestingFixtureCourses）
 * - 信封版本门（parseSnapshotJson 的 app/schemaVersion/backupType 检查）。
 *
 * 不依赖 TimetableProfile 等模型：用户数据判定以 [SnapshotUserDataSignals]
 * 的布尔/计数信号输入，模型组装由调用方负责。
 */

const val SNAPSHOT_SCHEMA_VERSION = 2
const val SNAPSHOT_BACKUP_TYPE = "sync"
const val SNAPSHOT_APP_ID = "mikcb"

enum class SyncConflictChoice {
    KEEP_LOCAL,
    KEEP_REMOTE,
    CANCEL,
}

data class SyncConflictInfo(
    /** Dart DateTime.isAfter 的毫秒等价（越大越新）。 */
    val localExportedAtMillis: Long,
    val remoteExportedAtMillis: Long,
    val localHash: String,
    val remoteHash: String,
    /** 首次同步分歧（基线双空）触发的冲突，UI 换解释性文案。 */
    val isFirstSyncDivergence: Boolean = false,
    /** 本机快照是否含用户亲手沉淀的数据。 */
    val localHasUserData: Boolean = false,
)

/**
 * 手动拉取遇到冲突的预决策：无本地用户数据直接以云端为准，不弹选边框。
 * Dart `resolveManualPullConflictChoice` 原样。
 */
fun resolveManualPullConflictChoice(localHasUserData: Boolean): SyncConflictChoice? =
    if (localHasUserData) null else SyncConflictChoice.KEEP_REMOTE

/** LWW + hash 字典序平局判云端（Dart `resolveSyncConflictAutomatically` 原样）。 */
fun resolveSyncConflictAutomatically(info: SyncConflictInfo): SyncConflictChoice {
    if (info.remoteExportedAtMillis > info.localExportedAtMillis) {
        return SyncConflictChoice.KEEP_REMOTE
    }
    if (info.localExportedAtMillis > info.remoteExportedAtMillis) {
        return SyncConflictChoice.KEEP_LOCAL
    }
    return if (info.remoteHash.compareTo(info.localHash) >= 0) {
        SyncConflictChoice.KEEP_REMOTE
    } else {
        SyncConflictChoice.KEEP_LOCAL
    }
}

/**
 * 后台/自动拉取：永不静默用本地覆盖云端（C1）。
 * Dart `resolveSyncConflictForBackground` 原样。
 */
fun resolveSyncConflictForBackground(info: SyncConflictInfo): SyncConflictChoice {
    val automatic = resolveSyncConflictAutomatically(info)
    return if (automatic == SyncConflictChoice.KEEP_LOCAL) {
        SyncConflictChoice.KEEP_REMOTE
    } else {
        automatic
    }
}

/**
 * 后台自动拉取是否取消（Dart `webdavBackgroundPullShouldCancel` 原样）。
 * 保护首次同步的非空本地，以及自上次上传后本地已分歧的状态。
 */
fun webdavBackgroundPullShouldCancel(
    lastUploadedLocalHash: String?,
    lastAppliedRemoteHash: String?,
    localContentSha256: String,
    localHasUserData: Boolean,
): Boolean {
    val isFirstSyncWithoutBaseline =
        lastUploadedLocalHash == null && lastAppliedRemoteHash == null
    if (isFirstSyncWithoutBaseline && localHasUserData) {
        return true
    }
    return lastUploadedLocalHash != null && localContentSha256 != lastUploadedLocalHash
}

/** 自动上传能否覆盖远端（Dart `WebdavAutoUploadDecision` 原样）。 */
enum class WebdavAutoUploadDecision {
    ALLOW,
    UP_TO_DATE,
    REMOTE_DRIFTED,
    LOCAL_DATA_EMPTY,
}

/**
 * 自动上传判据（Dart `decideWebdavAutoUpload` 原样，顺序即语义）：
 * 1. 远端缺失 → ALLOW；2. 远近一致 → UP_TO_DATE；
 * 3. 本地掉空（且上次非确知为空）→ LOCAL_DATA_EMPTY；
 * 4. 命中基线 → ALLOW；否则 REMOTE_DRIFTED。
 */
fun decideWebdavAutoUpload(
    remoteContentSha256: String?,
    lastAppliedRemoteHash: String?,
    lastUploadedLocalHash: String?,
    localContentSha256: String,
    localHasUserAuthoredData: Boolean,
    lastUploadedHadUserData: Boolean? = null,
): WebdavAutoUploadDecision {
    val remoteHash = remoteContentSha256?.trim()
    if (remoteHash.isNullOrEmpty()) {
        return WebdavAutoUploadDecision.ALLOW
    }
    if (remoteHash == localContentSha256) {
        return WebdavAutoUploadDecision.UP_TO_DATE
    }
    if (!localHasUserAuthoredData && lastUploadedHadUserData != false) {
        return WebdavAutoUploadDecision.LOCAL_DATA_EMPTY
    }
    val matchesBaseline =
        remoteHash == lastAppliedRemoteHash || remoteHash == lastUploadedLocalHash
    return if (matchesBaseline) {
        WebdavAutoUploadDecision.ALLOW
    } else {
        WebdavAutoUploadDecision.REMOTE_DRIFTED
    }
}

/**
 * 拉取是否构成冲突（Dart `webdavPullHasSyncConflict` 原样）。
 * 基线存在时需两侧都变；首同步（双基线空）本地远端不一致即冲突。
 */
fun webdavPullHasSyncConflict(
    lastUploadedLocalHash: String?,
    lastAppliedRemoteHash: String?,
    localContentSha256: String,
    remoteContentSha256: String,
): Boolean {
    val localChangedSinceSync =
        lastUploadedLocalHash != null && localContentSha256 != lastUploadedLocalHash
    val remoteChangedSinceSync =
        lastAppliedRemoteHash != null && remoteContentSha256 != lastAppliedRemoteHash
    val divergedOnFirstSync =
        lastUploadedLocalHash == null &&
            lastAppliedRemoteHash == null &&
            localContentSha256 != remoteContentSha256
    return (localChangedSinceSync && remoteChangedSinceSync) || divergedOnFirstSync
}

/** 快照信封版本门（Dart parseSnapshotJson 的 app/version/type 检查）。 */
fun isCompatibleSnapshotEnvelope(
    app: String?,
    schemaVersion: Int?,
    backupType: String?,
): Boolean = app == SNAPSHOT_APP_ID &&
    schemaVersion == SNAPSHOT_SCHEMA_VERSION &&
    backupType == SNAPSHOT_BACKUP_TYPE

/**
 * 宽松版信封门：Dart 要求 version 为整数（int，或值与 toInt 相等的 num）。
 * Double 2.0 视为兼容，2.5 / 非数字 / 缺键一律不兼容。
 */
fun isCompatibleSnapshotEnvelopeRaw(
    app: Any?,
    schemaVersion: Any?,
    backupType: Any?,
): Boolean {
    if (app !is String || backupType !is String) return false
    val versionInt = when (schemaVersion) {
        is Int -> schemaVersion
        is Long -> {
            if (schemaVersion in Int.MIN_VALUE..Int.MAX_VALUE) schemaVersion.toInt() else return false
        }
        is Double -> {
            if (schemaVersion % 1.0 != 0.0) return false
            schemaVersion.toInt()
        }
        is Float -> {
            if (schemaVersion % 1.0f != 0.0f) return false
            schemaVersion.toInt()
        }
        is Number -> {
            val d = schemaVersion.toDouble()
            if (d % 1.0 != 0.0) return false
            d.toInt()
        }
        else -> return false
    }
    return isCompatibleSnapshotEnvelope(app, versionInt, backupType)
}

// ---------- 内容哈希 ----------

/**
 * 内容一致性哈希（Dart `computeContentSha256` 原样）。
 * 排除 exportedAt/deviceId/contentSha256 后 canonical JSON → SHA-256 hex。
 */
fun computeContentSha256(payload: Map<String, Any?>): String {
    val forHash = payload.filterKeys { it != "exportedAt" && it != "deviceId" && it != "contentSha256" }
    val canonical = canonicalize(forHash)
    val json = canonicalJson(canonical)
    val digest = MessageDigest.getInstance("SHA-256").digest(json.toByteArray(Charsets.UTF_8))
    return digest.joinToString("") { "%02x".format(it) }
}

/** 递归排序 Map 键（键按 toString 排），List 保持序（Dart `_canonicalize` 原样）。 */
fun canonicalize(value: Any?): Any? = when (value) {
    is Map<*, *> -> {
        val sortedKeys = value.keys.map { it.toString() }.sorted()
        val out = linkedMapOf<String, Any?>()
        for (k in sortedKeys) {
            // 同名键以最后一次出现为准（Dart Map 语义）；源 payload 键唯一。
            val raw = value.entries.firstOrNull { it.key.toString() == k }?.value
            out[k] = canonicalize(raw)
        }
        out
    }
    is List<*> -> value.map { canonicalize(it) }
    else -> value
}

/**
 * 最小确定性 JSON 编码（与 Dart jsonEncode 对齐：紧凑分隔符、键已排序、
 * 字符串转义 `"` `\` 控制字符、非 ASCII 不转义）。
 */
fun canonicalJson(value: Any?): String {
    val sb = StringBuilder()
    writeCanonicalJson(sb, value)
    return sb.toString()
}

private fun writeCanonicalJson(sb: StringBuilder, value: Any?) {
    when (value) {
        null -> sb.append("null")
        is String -> writeJsonString(sb, value)
        is Boolean -> sb.append(if (value) "true" else "false")
        is Int -> sb.append(value.toString())
        is Long -> sb.append(value.toString())
        is Double -> {
            // Dart jsonEncode 对 double 用最短往返；Kotlin toString 足够判等（两侧同实现）。
            if (value.isNaN() || value.isInfinite()) sb.append("null") else sb.append(value.toString())
        }
        is Float -> {
            val d = value.toDouble()
            if (d.isNaN() || d.isInfinite()) sb.append("null") else sb.append(d.toString())
        }
        is Number -> sb.append(value.toLong().toString())
        is Map<*, *> -> {
            sb.append('{')
            val sorted = value.keys.map { it.toString() }.sorted()
            var first = true
            for (k in sorted) {
                if (!first) sb.append(',')
                first = false
                writeJsonString(sb, k)
                sb.append(':')
                writeCanonicalJson(sb, value.entries.firstOrNull { it.key.toString() == k }?.value)
            }
            sb.append('}')
        }
        is Iterable<*> -> {
            sb.append('[')
            var first = true
            for (item in value) {
                if (!first) sb.append(',')
                first = false
                writeCanonicalJson(sb, item)
            }
            sb.append(']')
        }
        else -> writeJsonString(sb, value.toString())
    }
}

private fun writeJsonString(sb: StringBuilder, value: String) {
    sb.append('"')
    for (c in value) {
        when (c.code) {
            0x22 -> sb.append("\\\"")
            0x5C -> sb.append("\\\\")
            0x0A -> sb.append("\\n")
            0x0D -> sb.append("\\r")
            0x09 -> sb.append("\\t")
            0x08 -> sb.append("\\b")
            0x0C -> sb.append("\\f")
            else -> if (c.code < 0x20) {
                sb.append("\\u").append(c.code.toString(16).padStart(4, '0'))
            } else {
                sb.append(c)
            }
        }
    }
    sb.append('"')
}

// ---------- 用户数据判定（无模型版） ----------

/**
 * 快照是否含用户亲手沉淀数据的信号包。
 * Dart `AppSyncSnapshot.hasUserAuthoredData` 逐分支的无模型投影：
 * 调用方把各集合是否非空/计数/默认名改名等事实填进来，本函数只做判据。
 */
data class SnapshotUserDataSignals(
    val teacherRecordsNotEmpty: Boolean = false,
    val locationRecordsNotEmpty: Boolean = false,
    val locationTimeGroupsNotEmpty: Boolean = false,
    val scheduleDateRulesNotEmpty: Boolean = false,
    val customHolidaysNotEmpty: Boolean = false,
    val macrosNotEmpty: Boolean = false,
    val partnerBindingPresent: Boolean = false,
    val rememberedLoginsNotEmpty: Boolean = false,
    val customImportUrlsNotEmpty: Boolean = false,
    val recentSchoolIdsNotEmpty: Boolean = false,
    val customDebugRecordsNotEmpty: Boolean = false,
    val timeSchemeCount: Int = 0,
    /** count==1 时是否与出厂默认作息逐段一致。 */
    val timeSchemeMatchesFactoryDefault: Boolean = true,
    val profileCount: Int = 0,
    val profilesHaveCourses: Boolean = false,
    val partnerImportedPresent: Boolean = false,
    val renamedAwayFromDefaultPresent: Boolean = false,
)

/** Dart `hasUserAuthoredData` 判据原样（顺序即 Dart 顺序）。 */
fun hasUserAuthoredData(s: SnapshotUserDataSignals): Boolean {
    if (s.teacherRecordsNotEmpty || s.locationRecordsNotEmpty) return true
    if (s.locationTimeGroupsNotEmpty || s.scheduleDateRulesNotEmpty) return true
    if (s.customHolidaysNotEmpty || s.macrosNotEmpty) return true
    if (s.partnerBindingPresent) return true
    if (s.rememberedLoginsNotEmpty || s.customImportUrlsNotEmpty ||
        s.recentSchoolIdsNotEmpty || s.customDebugRecordsNotEmpty
    ) return true
    if (s.timeSchemeCount > 1) return true
    if (s.profileCount > 1) return true
    if (s.profilesHaveCourses) return true
    if (s.partnerImportedPresent) return true
    if (s.renamedAwayFromDefaultPresent) return true
    if (s.timeSchemeCount == 1 && !s.timeSchemeMatchesFactoryDefault) return true
    return false
}

/** 调试课 `live_test_*` 永不经云同步外发（Dart stripLiveTestingFixtureCourses 的 id 判据）。 */
fun isLiveTestingFixtureCourseId(id: String): Boolean = id.startsWith("live_test_")

fun stripLiveTestingFixtureCourseIds(ids: List<String>): List<String> =
    ids.filter { !isLiveTestingFixtureCourseId(it) }
