package com.mutx163.qingyu.sync

import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.carriesSettings

/**
 * 传输包包体 schema 校验 / 拼包（移植自 lib/services/transfer_package.dart 的
 * `TransferPackage` 静态校验面；信封常量复用 share/TransferEnvelope，不复制）。
 *
 * 刻意不做模型反序列化：`_parseList` 里「逐条 parse 成模型」那一步交给数据
 * 传输族（core 模型族已备好 fromJson），这里移植 Dart 在 parse 前后做的
 * **结构性校验**，错误码与判定顺序逐字对齐：
 * - `_requiredListKinds` / `_requiredEntityFields` 两张表（[TRANSFER_REQUIRED_LIST_KINDS]
 *   / [TRANSFER_REQUIRED_ENTITY_FIELDS]，字段清单与顺序逐字一致）；
 * - `fromJson` 的信封/版本/必填标量/backupType/settings 门（transfer_*_* 错误码）；
 * - `_validateEntityMap` / `_validateProfileNestedMaps` 的字段在场校验（含 profile 嵌套）；
 * - `_requireUniqueIds` / `_requireUniqueIdsAcross` / `_requireUniqueIdsAllowingCrossProfile`
 *   三种唯一 id 规则：cloud 通道与全量包（backupType=full）允许跨课表重复 id，
 *   file/qr/lan 的非全量包把顶层与各课表的 id 池在一起查重（「导入为新课表」
 *   保留来源 id 的合法重复只发生在全量语义下）；
 * - 构造后 `validate()` 的结构诊断（empty / full 缺 profiles / 空时间模板 /
 *   未知 activeProfileId 警告）；
 * - `toJson` 的拼包键序（[buildTransferPackageJson]）。
 *
 * Dart 对拍锚点：test/services/transfer_package_test.dart。
 *
 * 与 Dart 的已知偏差（刻意）：
 * - `_parseList` 内「模型 parse 抛错 → transfer_${kind}_invalid」的兜底分支
 *   不在本层（没有模型 parse）；字段在场校验先于模型 parse 执行，因此缺字段
 *   报 `transfer_${kind}_${field}_required`，与 Dart 顺序一致；
 * - `encode()` 是缩进 JSON，本层只产 Map，序列化交给 MiniJson（紧凑）——
 *   字节级与 Dart 导出不等，仅语义等价。
 */
data class TransferPackageValidation(
    val errors: List<String> = emptyList(),
    val warnings: List<String> = emptyList(),
) {
    val isValid: Boolean get() = errors.isEmpty()
    val hasWarnings: Boolean get() = warnings.isNotEmpty()
}

/** Dart `TransferPackage._requiredListKinds` 原样（JSON 键 → 列表种类错误码段）。 */
val TRANSFER_REQUIRED_LIST_KINDS: Map<String, String> = linkedMapOf(
    "courses" to "course",
    "tasks" to "task",
    "scheduleItems" to "schedule_item",
    "exams" to "exam",
    "timeSchemes" to "time_scheme",
    "scheduleDateRules" to "time_rule",
    "locationTimeGroups" to "location_group",
    "profiles" to "profile",
)

/** Dart `TransferPackage._requiredEntityFields` 原样（种类 → 必填字段，顺序即报错顺序）。 */
val TRANSFER_REQUIRED_ENTITY_FIELDS: Map<String, List<String>> = linkedMapOf(
    "course" to listOf(
        "id", "name", "teacher", "location", "dayOfWeek",
        "startSection", "endSection", "startTime", "endTime",
    ),
    "task" to listOf("id", "title", "createdAt", "updatedAt"),
    "schedule_item" to listOf(
        "id", "title", "startDate", "endDate", "startTime", "endTime",
        "createdAt", "updatedAt", "recurrence", "exceptionDates", "enabled",
    ),
    "exam" to listOf(
        "id", "courseId", "name", "dateTime", "startTime", "endTime",
        "createdAt", "updatedAt",
    ),
    "time_scheme" to listOf("id", "name", "sections", "createdAt", "updatedAt"),
    "time_rule" to listOf(
        "id", "name", "timeSchemeId", "enabled", "startDate", "endDate",
    ),
    "location_group" to listOf(
        "id", "name", "timeSchemeId", "enabled", "priority", "keywords",
    ),
    "profile" to listOf(
        "id", "name", "courses", "tasks", "scheduleItems", "exams",
        "settings", "currentWeek", "createdAt", "lastUsedAt",
    ),
)

/**
 * 不抛错的包 JSON 校验（Dart `TransferPackage.validateJson` 原样语义）：
 * 任何一道门失败 → 单条错误码；全部通过 → `validate()` 的结构诊断
 * （可能有空包错误或 activeProfileId 警告）。
 */
fun validateTransferPackageJson(content: String): TransferPackageValidation {
    val decoded = try {
        MiniJson.parse(content)
    } catch (_: Exception) {
        return TransferPackageValidation(errors = listOf("transfer_package_json_invalid"))
    }
    if (decoded !is Map<*, *>) {
        return TransferPackageValidation(errors = listOf("transfer_package_root_invalid"))
    }
    @Suppress("UNCHECKED_CAST")
    val json = decoded as Map<String, Any?>
    val gateError = transferPackageGateError(json) ?: return structuralTransferPackageValidation(json)
    return TransferPackageValidation(errors = listOf(gateError))
}

/**
 * 拼包（Dart `TransferPackage.toJson` 键序原样）：信封常量取自
 * [TransferEnvelope]；`backupType: full` 只在全量时输出；可选标量缺省不输出；
 * 各列表键恒定输出（空列表也写）。
 */
fun buildTransferPackageJson(
    packageId: String,
    scope: TransferScope,
    exportedAtIso: String,
    channel: TransferChannel = TransferChannel.FILE,
    profileName: String? = null,
    currentWeek: Int? = null,
    activeProfileId: String? = null,
    settingsJson: Map<String, Any?>? = null,
    coursesJson: List<Any?> = emptyList(),
    tasksJson: List<Any?> = emptyList(),
    scheduleItemsJson: List<Any?> = emptyList(),
    examsJson: List<Any?> = emptyList(),
    timeSchemesJson: List<Any?> = emptyList(),
    scheduleDateRulesJson: List<Any?> = emptyList(),
    locationTimeGroupsJson: List<Any?> = emptyList(),
    profilesJson: List<Any?> = emptyList(),
    isFullBackup: Boolean = false,
): LinkedHashMap<String, Any?> {
    val out = LinkedHashMap<String, Any?>()
    out["app"] = TransferEnvelope.APP_ID
    out["packageType"] = TransferEnvelope.PACKAGE_TYPE
    out["schemaVersion"] = TransferEnvelope.SCHEMA_VERSION
    out["packageId"] = packageId.trim()
    out["scope"] = scope.value
    out["channel"] = channel.value
    if (isFullBackup) out["backupType"] = "full"
    out["exportedAt"] = exportedAtIso
    if (profileName != null) out["profileName"] = profileName
    if (currentWeek != null) out["currentWeek"] = currentWeek
    if (activeProfileId != null) out["activeProfileId"] = activeProfileId
    if (settingsJson != null) out["settings"] = settingsJson
    out["courses"] = coursesJson
    out["tasks"] = tasksJson
    out["scheduleItems"] = scheduleItemsJson
    out["exams"] = examsJson
    out["timeSchemes"] = timeSchemesJson
    out["scheduleDateRules"] = scheduleDateRulesJson
    out["locationTimeGroups"] = locationTimeGroupsJson
    out["profiles"] = profilesJson
    return out
}

// ---------- 内部：门检查（Dart fromJson 判定顺序原样） ----------

/**
 * Dart `fromJson` 的全部结构门 + 构造器唯一 id 检查，按 Dart 执行顺序返回
 * 第一条错误码；null 表示结构合法。
 */
private fun transferPackageGateError(json: Map<String, Any?>): String? {
    // 1. 信封（Dart :342-344）
    if (json["app"] != TransferEnvelope.APP_ID || json["packageType"] != TransferEnvelope.PACKAGE_TYPE) {
        return "transfer_package_type_invalid"
    }
    // 2. 版本（Dart :345-348；num 语义下 1.0 == 1 成立，bool true 不成立）
    if (!isSupportedTransferSchemaVersion(json["schemaVersion"])) {
        return "transfer_package_schema_unsupported"
    }
    // 3. 八张列表键必须在场且非 null（Dart :350-354，声明序即检查序）
    for ((key, kind) in TRANSFER_REQUIRED_LIST_KINDS) {
        if (!json.containsKey(key) || json[key] == null) {
            return "transfer_${kind}_list_required"
        }
    }
    // 4. packageId（Dart :356，_requiredString）
    if (!isNonBlankTransferString(json["packageId"])) {
        return "transfer_package_id_required"
    }
    // 5. scope（Dart :357-359：先 _requiredString 再 TransferScope.fromValue）
    val scopeRaw = json["scope"]
    if (scopeRaw !is String || scopeRaw.trim().isEmpty()) {
        return "transfer_scope_required"
    }
    val scope = try {
        TransferScope.fromValue(scopeRaw)
    } catch (_: Exception) {
        return "transfer_scope_invalid"
    }
    // 6. channel（Dart :360，_parseChannel：必须显式字符串，未知报 invalid——
    //    与 TransferChannel.fromValue 的「回落 file」不同，这里是解析门）
    val channel = when (val channelRaw = json["channel"]) {
        !is String -> return "transfer_channel_required"
        else -> {
            val value = channelRaw.trim().lowercase()
            TransferChannel.entries.firstOrNull { it.value == value }
                ?: return "transfer_channel_invalid"
        }
    }
    // 7. exportedAt（Dart :361，_parseExportedAt）
    val exportedAtRaw = json["exportedAt"]
    if (exportedAtRaw !is String || exportedAtRaw.trim().isEmpty()) {
        return "transfer_exported_at_required"
    }
    if (DartTime.tryParseIso(exportedAtRaw) == null) {
        return "transfer_exported_at_invalid"
    }
    // 8. 可选字符串（Dart :362-363，_optionalString：类型不符报 invalid）
    for (key in listOf("profileName", "activeProfileId")) {
        if (json.containsKey(key) && json[key] != null && json[key] !is String) {
            return "transfer_${key}_invalid"
        }
    }
    // 9. currentWeek（Dart :364，_optionalInt：num 且整值）
    json["currentWeek"]?.let { week ->
        val isInteger = when (week) {
            is Int, is Long -> true
            is Double -> week == Math.floor(week) && !week.isInfinite()
            is Float -> week.toDouble() == Math.floor(week.toDouble())
            else -> false
        }
        if (!isInteger) return "transfer_current_week_invalid"
    }
    // 10. backupType（Dart :365-368：null 或 "full"）
    when (val backupType = json["backupType"]) {
        null, "full" -> Unit
        else -> return "transfer_backup_type_invalid"
    }
    // 11. settings（Dart :370-383：null 放行，非 Map 或解析失败报 invalid）
    val settingsRaw = json["settings"]
    if (settingsRaw != null) {
        if (settingsRaw !is Map<*, *>) return "transfer_settings_invalid"
        try {
            @Suppress("UNCHECKED_CAST")
            TimetableSettings.fromJson(settingsRaw as Map<String, Any?>)
        } catch (_: Exception) {
            return "transfer_settings_invalid"
        }
    }
    // 12. 八张列表逐张：非 List / 元素非 Map / 字段缺失 / 列表内 id 查重
    //    （Dart :385-420 的 _parseList；模型 parse 兜底分支不在本层）
    for ((key, kind) in TRANSFER_REQUIRED_LIST_KINDS) {
        parseListGateError(kind, json[key])?.let { return it }
    }
    // 13. scope 语义门（Dart :421-433）
    val profilesRaw = json["profiles"] as? List<*> ?: emptyList<Any?>()
    val profileScoped = profilesRaw.isNotEmpty()
    if (scope.carriesSettings && settingsRaw == null && !profileScoped) {
        return "transfer_settings_required"
    }
    if (json["currentWeek"] == null &&
        scope != TransferScope.TIME_TEMPLATE &&
        scope != TransferScope.SELECTED_COURSE &&
        scope != TransferScope.SELECTED_COURSES &&
        !profileScoped
    ) {
        return "transfer_current_week_required"
    }
    // 14. 构造器唯一 id 检查（Dart :230-279，构造器在 fromJson 门后执行）
    val isFullBackup = json["backupType"] == "full"
    val entityKinds = linkedMapOf(
        "course" to "courses",
        "task" to "tasks",
        "schedule_item" to "scheduleItems",
        "exam" to "exams",
    )
    if (channel == TransferChannel.CLOUD || isFullBackup) {
        // 允许跨课表重复：顶层自查 + 每张课表内部自查（Dart _requireUniqueIdsAllowingCrossProfile）
        for ((kind, key) in entityKinds) {
            uniqueIdsError(kind, transferEntityIds(json[key]))?.let { return it }
            for (ids in transferPerProfileEntityIds(profilesRaw, key)) {
                uniqueIdsError(kind, ids)?.let { return it }
            }
        }
    } else {
        // 顶层 + 全部课表池在一起查重（Dart _requireUniqueIdsAcross）
        for ((kind, key) in entityKinds) {
            val pooled = ArrayList<String>(transferEntityIds(json[key]))
            for (ids in transferPerProfileEntityIds(profilesRaw, key)) {
                pooled.addAll(ids)
            }
            uniqueIdsError(kind, pooled)?.let { return it }
        }
    }
    // profile / time_scheme / time_rule / location_group 永远全局唯一（Dart :273-279）
    uniqueIdsError("profile", transferEntityIds(json["profiles"]))?.let { return it }
    uniqueIdsError("time_scheme", transferEntityIds(json["timeSchemes"]))?.let { return it }
    uniqueIdsError("time_rule", transferEntityIds(json["scheduleDateRules"]))?.let { return it }
    uniqueIdsError("location_group", transferEntityIds(json["locationTimeGroups"]))?.let { return it }
    return null
}

/** Dart `is! num || toInt() != value` 的版本门特化（== 1）。 */
private fun isSupportedTransferSchemaVersion(raw: Any?): Boolean = when (raw) {
    is Int -> raw == TransferEnvelope.SCHEMA_VERSION
    is Long -> raw == TransferEnvelope.SCHEMA_VERSION.toLong()
    is Double -> raw == TransferEnvelope.SCHEMA_VERSION.toDouble()
    is Float -> raw.toDouble() == TransferEnvelope.SCHEMA_VERSION.toDouble()
    else -> false
}

private fun isNonBlankTransferString(raw: Any?): Boolean =
    raw is String && raw.trim().isNotEmpty()

/** Dart `_parseList` 的结构部分：null 放行（已由在场门拦）、类型与逐条字段校验、id 查重。 */
private fun parseListGateError(kind: String, raw: Any?): String? {
    if (raw == null) return null
    if (raw !is List<*>) return "transfer_${kind}_list_invalid"
    val ids = ArrayList<String>(raw.size)
    for (item in raw) {
        if (item !is Map<*, *>) return "transfer_${kind}_invalid"
        validateEntityMapError(kind, item)?.let { return it }
        ids.add(transferEntityIdOf(item))
    }
    return uniqueIdsError(kind, ids)
}

/** Dart `_validateEntityMap`：必填字段在场（null 即缺），profile 追加嵌套校验。 */
private fun validateEntityMapError(kind: String, json: Map<*, *>): String? {
    val fields = TRANSFER_REQUIRED_ENTITY_FIELDS[kind] ?: return null
    for (field in fields) {
        if (!json.containsKey(field) || json[field] == null) {
            return "transfer_${kind}_${field}_required"
        }
    }
    if (kind == "profile") {
        return validateProfileNestedMapsError(json)
    }
    return null
}

/** Dart `_validateProfileNestedMaps`：四张嵌套列表必须为 List，元素必须是 Map 并过字段校验。 */
private fun validateProfileNestedMapsError(json: Map<*, *>): String? {
    val nestedKinds = linkedMapOf(
        "courses" to "course",
        "tasks" to "task",
        "scheduleItems" to "schedule_item",
        "exams" to "exam",
    )
    for ((key, kind) in nestedKinds) {
        val rawItems = json[key]
        if (rawItems !is List<*>) {
            return "transfer_profile_${key}_list_invalid"
        }
        for (item in rawItems) {
            if (item !is Map<*, *>) {
                return "transfer_${kind}_invalid"
            }
            validateEntityMapError(kind, item)?.let { return it }
        }
    }
    return null
}

/** Dart `_idOf` 的无模型投影：id 取原值（非字符串转字符串），缺/空由字段门与查重门接住。 */
private fun transferEntityIdOf(item: Map<*, *>): String = when (val raw = item["id"]) {
    null -> ""
    is String -> raw
    else -> raw.toString()
}.trim()

private fun transferEntityIds(raw: Any?): List<String> {
    if (raw !is List<*>) return emptyList()
    return raw.mapNotNull { item ->
        if (item is Map<*, *>) transferEntityIdOf(item) else null
    }
}

private fun transferPerProfileEntityIds(profiles: List<*>, key: String): List<List<String>> =
    profiles.mapNotNull { profile ->
        if (profile is Map<*, *>) transferEntityIds(profile[key]) else null
    }

/** Dart `_requireUniqueIds`：空 → id_required，重复 → id_duplicate。 */
private fun uniqueIdsError(kind: String, ids: List<String>): String? {
    val seen = HashSet<String>()
    for (rawId in ids) {
        val id = rawId.trim()
        if (id.isEmpty()) return "transfer_${kind}_id_required"
        if (!seen.add(id)) return "transfer_${kind}_id_duplicate"
    }
    return null
}

// ---------- 内部：结构诊断（Dart validate() 原样） ----------

/**
 * Dart `validate()`：不含本地比对的纯结构诊断。空包报 error；全量备份对
 * allData 必须带课表；时间模板必须带至少一张作息；activeProfileId 指不到
 * 课表只作警告（可导入，但预览会提示）。
 */
private fun structuralTransferPackageValidation(json: Map<String, Any?>): TransferPackageValidation {
    fun listNonEmpty(key: String): Boolean = (json[key] as? List<*>)?.isNotEmpty() == true
    val hasPayload = listNonEmpty("profiles") ||
        listNonEmpty("courses") ||
        listNonEmpty("tasks") ||
        listNonEmpty("scheduleItems") ||
        listNonEmpty("exams") ||
        listNonEmpty("timeSchemes") ||
        listNonEmpty("scheduleDateRules") ||
        listNonEmpty("locationTimeGroups") ||
        json["settings"] != null
    val errors = ArrayList<String>()
    val warnings = ArrayList<String>()
    if (!hasPayload) {
        errors.add("transfer_package_empty")
    }
    val scope = TransferScope.fromValue(json["scope"])
    if (json["backupType"] == "full" && scope == TransferScope.ALL_DATA && !listNonEmpty("profiles")) {
        errors.add("transfer_full_profiles_required")
    }
    if (scope == TransferScope.TIME_TEMPLATE && !listNonEmpty("timeSchemes")) {
        errors.add("transfer_time_template_empty")
    }
    val activeProfileId = json["activeProfileId"] as? String
    if (activeProfileId != null) {
        val profiles = json["profiles"] as? List<*> ?: emptyList<Any?>()
        val exists = profiles.any { (it as? Map<*, *>)?.get("id") == activeProfileId }
        if (profiles.isNotEmpty() && !exists) {
            warnings.add("active_profile_missing:$activeProfileId")
        }
    }
    return TransferPackageValidation(errors = errors, warnings = warnings)
}
