package com.mutx163.qingyu.sync

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.TimeScheme

/**
 * 云同步快照的解析门 / 宽松列表解析 / meta 往返纯函数
 * （移植自 lib/services/app_sync_snapshot_service.dart 中不触 IO 的部分；
 * 判据/冲突/自动上传/信封版本门已由本包 SyncConflict.kt 前泳道交付）。
 *
 * 刻意不移植（触 IO / 组合层，见泳道交付说明的 IO 清单）：
 * collectSnapshot（仓储/SharedPreferences/文件）、buildSnapshotJson*（日志副作用）、
 * applySnapshot* /undoLastApply（TransferDiffService + 仓储 + 基线重置钩子）、
 * 各模型 fromJson（WarehouseSyncBundle/WarehouseMacroRecord/HolidayEntry/
 * PartnerTimetableBinding/TimetableProfile 组装归模型族泳道）。
 *
 * Dart 对拍锚点：test/services/app_sync_snapshot_service.dart_test.dart
 * （997 行）逐条转录；错误码逐字一致。
 */

// ---------- 错误码（Dart FormatException.message 原样） ----------

const val SNAPSHOT_PARSE_ERROR_UNRECOGNIZED = "unrecognized_sync_snapshot"
const val SNAPSHOT_PARSE_ERROR_MISSING_TIMETABLE = "missing_sync_timetable_data"
const val SNAPSHOT_PARSE_ERROR_CHECKSUM_INVALID = "invalid_sync_snapshot_checksum"
const val SNAPSHOT_PARSE_ERROR_CHECKSUM_FAILED = "sync_snapshot_checksum_failed"
const val SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID = "invalid_sync_snapshot_payload"
const val SNAPSHOT_PARSE_ERROR_META_INVALID = "invalid_sync_snapshot_meta"

// ---------- JSON 根解码（Dart _decodeSnapshotObject 原样） ----------

/**
 * Dart `_decodeSnapshotObject`：合法 JSON 对象 → Map；根不是对象 →
 * `invalid_sync_snapshot_payload`；JSON 本身解析失败原样上抛
 * （Dart 对 FormatException rethrow，不换文案）——本侧统一为
 * [DartFormatException]，调用方按「根对象解码失败」一类处理。
 */
fun decodeSnapshotObject(content: String): Map<String, Any?> {
    val decoded = try {
        MiniJson.parse(content)
    } catch (e: DartFormatException) {
        throw e
    } catch (e: Exception) {
        throw DartFormatException(SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID)
    }
    if (decoded !is Map<*, *>) {
        throw DartFormatException(SNAPSHOT_PARSE_ERROR_PAYLOAD_INVALID)
    }
    @Suppress("UNCHECKED_CAST")
    return decoded as Map<String, Any?>
}

// ---------- 信封 + 校验和对账（Dart parseSnapshotJson :495-526 原样） ----------

/**
 * 信封/核心列表/校验和三道门的判定结果。
 *
 * - [isValid] == false：[errorCode] 是第一条命中的门错误码，其余字段无意义；
 * - [isValid] == true：[payloadWithoutHash] 是去掉 `contentSha256` 后的哈希
 *   输入（键序保持原 JSON 序），[expectedHash] 为包内声明（`''` 表示没带或
 *   带空串——两种都跳过校验，Dart :522-524），[actualHash] 为按内容重算值。
 *
 * Dart 侧 parseSnapshotJson 的门序（逐字）：
 * 1. app/backupType 必须是 String、schemaVersion 必须是整数（num 且值==toInt）
 *    → unrecognized_sync_snapshot；
 * 2. app=='mikcb' && version==2 && type=='sync' → 否则 unrecognized_sync_snapshot；
 * 3. profiles / timeSchemes 必须是 List → missing_sync_timetable_data；
 * 4. contentSha256 非 null 时必须是 String → invalid_sync_snapshot_checksum；
 * 5. 声明非空且不等于重算 → sync_snapshot_checksum_failed。
 */
data class SnapshotEnvelopeCheck(
    val isValid: Boolean,
    val errorCode: String? = null,
    val payloadWithoutHash: LinkedHashMap<String, Any?>? = null,
    val expectedHash: String = "",
    val actualHash: String = "",
)

fun checkSnapshotEnvelopeAndChecksum(json: Map<String, Any?>): SnapshotEnvelopeCheck {
    // 1. 类型门（Dart :498-503）
    val rawApp = json["app"]
    val rawVersion = json["schemaVersion"]
    val rawType = json["backupType"]
    val versionIsIntegral = when (rawVersion) {
        is Int, is Long -> true
        is Double -> rawVersion == Math.floor(rawVersion) && !rawVersion.isInfinite()
        is Float -> rawVersion.toDouble() == Math.floor(rawVersion.toDouble())
        else -> false
    }
    if (rawApp !is String || rawType !is String || !versionIsIntegral) {
        return SnapshotEnvelopeCheck(false, SNAPSHOT_PARSE_ERROR_UNRECOGNIZED)
    }
    // 2. 值门（Dart :508-510；SNAPSHOT_* 常量复用 SyncConflict.kt）
    if (rawApp != SNAPSHOT_APP_ID ||
        (rawVersion as Number).toLong() != SNAPSHOT_SCHEMA_VERSION.toLong() ||
        rawType != SNAPSHOT_BACKUP_TYPE
    ) {
        return SnapshotEnvelopeCheck(false, SNAPSHOT_PARSE_ERROR_UNRECOGNIZED)
    }
    // 3. 核心列表门（Dart :512-516）
    if (json["profiles"] !is List<*> || json["timeSchemes"] !is List<*>) {
        return SnapshotEnvelopeCheck(false, SNAPSHOT_PARSE_ERROR_MISSING_TIMETABLE)
    }
    // 4. 哈希字段形态门（Dart :517-521）
    val rawHash = json["contentSha256"]
    if (rawHash != null && rawHash !is String) {
        return SnapshotEnvelopeCheck(false, SNAPSHOT_PARSE_ERROR_CHECKSUM_INVALID)
    }
    // 5. 对账（Dart :517-526）：声明空串/缺失跳过，非空必须与重算一致。
    val payloadWithoutHash = LinkedHashMap<String, Any?>(json)
    payloadWithoutHash.remove("contentSha256")
    val expectedHash = rawHash as String? ?: ""
    val actualHash = computeContentSha256(payloadWithoutHash)
    if (expectedHash.isNotEmpty() && expectedHash != actualHash) {
        return SnapshotEnvelopeCheck(
            false,
            SNAPSHOT_PARSE_ERROR_CHECKSUM_FAILED,
            payloadWithoutHash,
            expectedHash,
            actualHash,
        )
    }
    return SnapshotEnvelopeCheck(
        isValid = true,
        payloadWithoutHash = payloadWithoutHash,
        expectedHash = expectedHash,
        actualHash = actualHash,
    )
}

// ---------- 宽松解析（Dart _parseStringList / _parseOptionalList / _selectSnapshotMacros） ----------

/** Dart `_parseStringList`：只留字符串且非空项，其余静默丢弃。 */
fun parseSnapshotStringList(raw: Any?): List<String> {
    if (raw !is List<*>) return emptyList()
    return raw.filterIsInstance<String>().filter { it.isNotEmpty() }
}

/** Dart `_selectSnapshotMacros`：warehouse.macros 列表优先，回落顶层 macros 键。 */
fun selectSnapshotMacros(json: Map<String, Any?>): Any? {
    val warehouse = json["warehouse"]
    if (warehouse is Map<*, *> && warehouse["macros"] is List<*>) {
        return warehouse["macros"]
    }
    return json["macros"]
}

data class OptionalMapParseResult(
    val valid: List<Map<String, Any?>>,
    val rawCount: Int,
    val dropped: Int,
)

/**
 * Dart `_parseOptionalList`：非 List → 空；逐条只收「能被模型 fromJson 解析」
 * 的 Map 条目（模型解析归调用方，本函数收解析回调），坏条目静默丢弃；
 * 同时回报原始条数与丢弃数（Dart :589-592 用「raw 非空但 0 条有效」判
 * 核心负载损坏，missing_sync_timetable_data）。
 */
inline fun parseOptionalSnapshotMaps(
    raw: Any?,
    parse: (Map<String, Any?>) -> Any?,
): OptionalMapParseResult {
    if (raw !is List<*>) return OptionalMapParseResult(emptyList(), 0, 0)
    val valid = ArrayList<Map<String, Any?>>()
    var dropped = 0
    for (item in raw) {
        if (item !is Map<*, *>) {
            dropped++
            continue
        }
        @Suppress("UNCHECKED_CAST")
        val map = item as Map<String, Any?>
        try {
            parse(map)
            valid.add(map)
        } catch (_: Exception) {
            dropped++
        }
    }
    return OptionalMapParseResult(valid, raw.size, dropped)
}

/** Dart `_optionalString`（parseSnapshotJson 内成员版）：只收字符串，其余 null。 */
fun optionalSnapshotString(raw: Any?): String? = raw as? String

data class OptionalStringParseResult(
    val valid: List<String>,
    val dropped: Int,
)

/** Dart `_parseOptionalList` 的 String 特化（customHolidays 等不用，备用对齐）。 */
fun parseOptionalSnapshotStrings(raw: Any?): OptionalStringParseResult {
    if (raw !is List<*>) return OptionalStringParseResult(emptyList(), 0)
    var dropped = 0
    val valid = ArrayList<String>()
    for (item in raw) {
        val value = item as? String
        if (value == null) dropped++ else valid.add(value)
    }
    return OptionalStringParseResult(valid, dropped)
}

// ---------- meta 往返（Dart AppSyncSnapshotMeta toJson/fromJson 原样） ----------

data class SnapshotMetaParseResult(
    val isValid: Boolean,
    val errorCode: String? = null,
    val exportedAtIso: String? = null,
    val contentSha256: String? = null,
    val deviceId: String? = null,
    val appVersion: String? = null,
    val snapshotPath: String? = null,
)

/**
 * Dart `AppSyncSnapshotMeta.fromJson`：
 * - 五个键中任何一个「非 null 且非 String」→ invalid_sync_snapshot_meta；
 * - exportedAt 解不出 → epoch 0（本地墙上时刻，Dart :232-233）；
 * - contentSha256 / deviceId 缺省 ''，appVersion / snapshotPath 缺省 null。
 */
fun parseSnapshotMetaFields(json: Map<String, Any?>): SnapshotMetaParseResult {
    for (key in listOf("exportedAt", "contentSha256", "deviceId", "appVersion", "snapshotPath")) {
        if (json[key] != null && json[key] !is String) {
            return SnapshotMetaParseResult(false, SNAPSHOT_PARSE_ERROR_META_INVALID)
        }
    }
    val exportedAtIso = DartTime.toIso(
        DartTime.tryParseIso(json["exportedAt"] as? String) ?: DartTime.fromEpochMillis(0),
    )
    return SnapshotMetaParseResult(
        isValid = true,
        exportedAtIso = exportedAtIso,
        contentSha256 = (json["contentSha256"] as? String) ?: "",
        deviceId = (json["deviceId"] as? String) ?: "",
        appVersion = json["appVersion"] as? String,
        snapshotPath = json["snapshotPath"] as? String,
    )
}

/** Dart `AppSyncSnapshotMeta.toJson` 键序原样；snapshotPath 空白不写（Dart :217-218）。 */
fun snapshotMetaToJson(
    exportedAtIso: String,
    contentSha256: String,
    deviceId: String,
    appVersion: String?,
    snapshotPath: String?,
): LinkedHashMap<String, Any?> {
    val out = LinkedHashMap<String, Any?>()
    out["exportedAt"] = exportedAtIso
    out["contentSha256"] = contentSha256
    out["deviceId"] = deviceId
    if (appVersion != null) out["appVersion"] = appVersion
    if (!snapshotPath.isNullOrBlank()) out["snapshotPath"] = snapshotPath
    return out
}

// ---------- 快照标量读取（Dart parseSnapshotJson :632-656 原样） ----------

/** Dart :647-649：exportedAt 解不出回落「当前时刻」；[nowIso] 供纯测试注入。 */
fun snapshotExportedAtOrNow(json: Map<String, Any?>, nowIso: String? = null): String =
    DartTime.tryParseIso(optionalSnapshotString(json["exportedAt"]))
        ?.let { DartTime.toIso(it) }
        ?: (nowIso ?: DartTime.toIso(java.time.LocalDateTime.now()))

/** Dart :650：deviceId 缺省 ''（只收字符串）。 */
fun snapshotDeviceIdOrEmpty(json: Map<String, Any?>): String =
    optionalSnapshotString(json["deviceId"]) ?: ""

/** Dart _normalizedOptionalString：trim 后空串归 null（scheduleDateRuleLastAppliedSignature）。 */
fun normalizedOptionalSnapshotString(raw: Any?): String? =
    optionalSnapshotString(raw)?.trim()?.takeIf { it.isNotEmpty() }

// ---------- warehouse 在场标记（Dart WarehouseSyncSections.fromSnapshotJson 原样） ----------

/**
 * 「云端带了哪些类别」从原始 JSON 推导（Dart warehouse_import_preferences_service.dart
 * :299-309）：warehouse 不是 Map → 四类全不在场；在但缺子键 → 只有缺的类别不在场。
 * 返回在场的类别键集合（rememberedLogins / customImportUrls / recentSchoolIds /
 * customDebugRecords 的子集）。
 */
fun snapshotWarehouseSectionPresence(warehouseRaw: Any?): Set<String> {
    if (warehouseRaw !is Map<*, *>) return emptySet()
    val sections = linkedSetOf<String>()
    for (key in listOf("rememberedLogins", "customImportUrls", "recentSchoolIds", "customDebugRecords")) {
        if (warehouseRaw.containsKey(key)) sections.add(key)
    }
    return sections
}

// ---------- 出厂默认作息判定（Dart _matchesFactoryDefaultTimeScheme 原样） ----------

/**
 * 唯一一张作息表是否与出厂默认节次表逐段一致（Dart app_sync_snapshot_service.dart
 * :180-194）：段数不同即否；任一段 start/end 不等即否。用于
 * hasUserAuthoredData 的「深度自定义默认作息」分支（sync 包的信号版入口是
 * SnapshotUserDataSignals.timeSchemeMatchesFactoryDefault，由调用方用本函数填充）。
 */
fun matchesFactoryDefaultTimeScheme(scheme: TimeScheme): Boolean {
    val defaults = TimetableSettings.DEFAULT_SECTIONS
    if (scheme.sections.size != defaults.size) return false
    for (index in defaults.indices) {
        if (scheme.sections[index].startTime != defaults[index].startTime ||
            scheme.sections[index].endTime != defaults[index].endTime
        ) {
            return false
        }
    }
    return true
}
