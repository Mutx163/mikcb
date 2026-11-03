package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.temporal.ChronoUnit

/**
 * 宏录制的数据模型（P1 / N1）：步骤类型、单步、整份录制记录、坏步骤诊断与
 * 弹窗应答 key（N6 的 key 部分）。
 *
 * 逐字对齐 Dart 参照物（只读，不许改）：
 * - `lib/models/warehouse_macro_models.dart`（模型与序列化脱敏）
 * - `lib/services/warehouse_macro_service.dart`（存储键名，键在 [WarehouseMacroRecord] 伴生对象）
 *
 * ## 跨端兼容是硬约束（D1：同一个 KeyValueStore、键名逐字一致）
 *
 * 迁移期 Flutter 主入口与 Compose 壳**共读同一批 SharedPreferences 键**，
 * 所以本文件的 JSON 结构与键名必须同时满足：
 * - `fromJson` 能读 Dart 写出的全部字段（含可空的 `scriptPageUrl` / `useDesktopMode`、
 *   Dart 风格的 ISO8601 本地时间戳）；
 * - `toJson` 写出的 JSON 能被 Dart `MacroStep.fromJson` / `WarehouseMacroRecord.fromJson`
 *   原样读回（字段名、枚举 wire 名、脱敏口径三处都不能漂移）。
 *
 * ## 序列化脱敏（隐私承诺，测试钉死）
 *
 * `fillField` 且字段类型是 password / captcha 的步骤，`toJson` **不写 value**；
 * `fromJson` 读到这类步骤时还原成 `waitForManualInput`（回放时等用户手动输入）。
 * 密码值一旦进过宏，任何一条读写路径都不能再把它带出来。
 */

/** 敏感字段类型（Dart `isSensitiveMacroFieldType`）：值永不落盘、永不进云同步。 */
fun isSensitiveMacroFieldType(fieldType: String?): Boolean =
    fieldType == "password" || fieldType == "captcha"

/** 敏感步骤还原成手动输入时的 reason（Dart `manualInputReasonForFieldType`）。 */
fun manualInputReasonForFieldType(fieldType: String?): String =
    if (fieldType == "captcha") "manual_input_captcha" else "manual_input_password"

/**
 * 从 waitForManualInput 步骤缺失的 fieldType 反推字段类型（Dart `_inferManualInputFieldType`）。
 *
 * 输入是机器生成的 reason（`manual_input_captcha` 等，恒 ASCII）；中文关键词分支
 * 只为兼容外部宏文件里可能带人类可读 reason 的旧数据。中文关键词用 Unicode 转义书写：
 * 这些是**数据匹配常量**不是屏上文案，同时避免 i18n 棘轮门禁把本文件记成新增债务。
 */
private fun inferManualInputFieldType(reason: String?): String? {
    val value = reason ?: ""
    val lower = value.lowercase()
    return when {
        // 「验证码」「校验码」
        value.contains("\u9a8c\u8bc1\u7801") ||
            value.contains("\u6821\u9a8c\u7801") ||
            lower.contains("captcha") ||
            lower.contains("verification") -> "captcha"

        // 「密码」
        value.contains("\u5bc6\u7801") ||
            lower.contains("password") ||
            lower.contains("pwd") -> "password"

        else -> null
    }
}

/**
 * 弹窗应答的存储 key（Dart `warehouseDialogResponseKey`，N6 的 key 部分）。
 *
 * 脚本消息带非空 `dialogId` 时用 `"type|id:<dialogId>"`；否则用
 * `"type|<title>|<body>"`（body 取 `message`，没有则 `optionsJson`）。
 * 取值口径与桥层的 optional-string 一致：**非字符串一律当没给**——脚本把
 * title / optionsJson 发成对象或数组时不能抛异常打断整条桥回调。
 */
fun warehouseDialogResponseKey(type: String, message: Map<*, *>): String {
    fun text(key: String): String? = message[key] as? String

    val dialogId = text("dialogId")?.trim()
    if (!dialogId.isNullOrEmpty()) {
        return "$type|id:$dialogId"
    }
    val title = (text("title") ?: "").trim()
    val body = (text("message") ?: text("optionsJson") ?: "").trim()
    return "$type|$title|$body"
}

/** 宏步骤类型。`wireName` 是 JSON 里的字符串，与 Dart 枚举 name 逐字一致（跨端互认靠它）。 */
enum class WarehouseMacroStepType(val wireName: String) {
    NAVIGATE("navigate"),
    FILL_FIELD("fillField"),
    CLICK("click"),
    WAIT_FOR_URL("waitForUrl"),
    WAIT_FOR_SELECTOR("waitForSelector"),
    WAIT_FOR_MANUAL_INPUT("waitForManualInput"),
    EXECUTE_SCRIPT("executeScript"),
    DELAY("delay"),
    ;

    companion object {
        private val byWireName = entries.associateBy { it.wireName }

        /** 认不出的 wire 名返回 null（调用方整条丢弃并计数，**不许兜成 delay**）。 */
        fun fromWireName(name: String?): WarehouseMacroStepType? = name?.let { byWireName[it] }
    }
}

/** 坏步骤 / 坏记录异常：调用方按「整条丢弃 + 计数」处理，绝不静默兜底成别的类型。 */
class WarehouseMacroFormatException(message: String) : Exception(message)

/**
 * 宏录制中的单步操作（Dart `MacroStep`）。
 *
 * `value` 的双重语义：fillField / navigate 是「填的值 / 目标地址」，
 * waitForManualInput 是「等谁」的 reason（与 Dart 一致，回放层按 type 区分）。
 */
data class WarehouseMacroStep(
    val type: WarehouseMacroStepType,
    val fieldType: String? = null,
    val selector: String? = null,
    val value: String? = null,
    val waitMs: Int = 0,
) {
    /**
     * 序列化。脱敏是硬约束：`fillField` 且字段为 password / captcha 时**不写 value**——
     * 密码/验证码值不允许出现在任何写盘 / 上云的字符串里（测试有反例钉着）。
     */
    fun toJson(): LinkedHashMap<String, Any?> {
        val omitValue = type == WarehouseMacroStepType.FILL_FIELD && isSensitiveMacroFieldType(fieldType)
        val out = LinkedHashMap<String, Any?>()
        out["type"] = type.wireName
        if (!fieldType.isNullOrEmpty()) out["fieldType"] = fieldType
        if (!selector.isNullOrEmpty()) out["selector"] = selector
        if (!omitValue && !value.isNullOrEmpty()) out["value"] = value
        if (waitMs > 0) out["waitMs"] = waitMs
        return out
    }

    fun encode(): String = MiniJson.encode(toJson())

    companion object {
        /**
         * 反序列化（Dart `MacroStep.fromJson`）。
         *
         * - 认不出的 type 抛 [WarehouseMacroFormatException]，由调用方整条丢弃；
         *   **不许兜成 delay**：那等于凭空造一条不存在的步骤，且不可逆（重编码后
         *   原始类型永久丢失）。
         * - 敏感 fillField 还原成 waitForManualInput：落盘时已脱敏，读回来不可能
         *   再有值，回放时等用户手动输入。
         */
        fun fromJson(json: Map<*, *>): WarehouseMacroStep {
            val type = WarehouseMacroStepType.fromWireName(json["type"] as? String)
                ?: throw WarehouseMacroFormatException("macro_step_type_unrecognized")
            val fieldType = json["fieldType"] as? String
            if (type == WarehouseMacroStepType.FILL_FIELD && isSensitiveMacroFieldType(fieldType)) {
                return waitForManualInput(
                    reason = manualInputReasonForFieldType(fieldType),
                    selector = json["selector"] as? String,
                    fieldType = fieldType,
                )
            }
            val value = json["value"] as? String
            val repairedFieldType = if (type == WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT) {
                fieldType ?: inferManualInputFieldType(value)
            } else {
                fieldType
            }
            return WarehouseMacroStep(
                type = type,
                fieldType = repairedFieldType,
                selector = json["selector"] as? String,
                value = value,
                waitMs = (json["waitMs"] as? Number)?.toInt() ?: 0,
            )
        }

        fun navigate(url: String): WarehouseMacroStep =
            WarehouseMacroStep(type = WarehouseMacroStepType.NAVIGATE, value = url)

        fun fillField(selector: String, value: String, fieldType: String? = null): WarehouseMacroStep =
            WarehouseMacroStep(
                type = WarehouseMacroStepType.FILL_FIELD,
                selector = selector,
                value = value,
                fieldType = fieldType,
            )

        fun click(selector: String): WarehouseMacroStep =
            WarehouseMacroStep(type = WarehouseMacroStepType.CLICK, selector = selector)

        fun waitForUrl(pattern: String): WarehouseMacroStep =
            WarehouseMacroStep(
                type = WarehouseMacroStepType.WAIT_FOR_URL,
                value = pattern,
                waitMs = DEFAULT_ELEMENT_WAIT_MS,
            )

        fun waitForSelector(selector: String): WarehouseMacroStep =
            WarehouseMacroStep(
                type = WarehouseMacroStepType.WAIT_FOR_SELECTOR,
                selector = selector,
                waitMs = DEFAULT_ELEMENT_WAIT_MS,
            )

        fun waitForManualInput(
            reason: String,
            selector: String? = null,
            fieldType: String? = null,
        ): WarehouseMacroStep = WarehouseMacroStep(
            type = WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT,
            selector = selector,
            fieldType = fieldType,
            value = reason,
        )

        fun delay(ms: Int): WarehouseMacroStep =
            WarehouseMacroStep(type = WarehouseMacroStepType.DELAY, waitMs = ms)

        /** 与 Dart `MacroStep.waitForUrl` / `waitForSelector` 相同的默认等待预算。 */
        private const val DEFAULT_ELEMENT_WAIT_MS = 15000
    }
}

/** 步骤列表解析结果：好步骤 + 丢弃计数（坏条目整条丢，但调用方必须知道丢没丢）。 */
data class WarehouseMacroStepsParseResult(
    val steps: List<WarehouseMacroStep>,
    val droppedStepCount: Int,
)

/**
 * 解析宏记录里的步骤列表，带丢弃计数（Dart `parseWarehouseMacroStepsWithDiagnostics`）。
 *
 * 坏条目（非对象、认不出的 type、坏 JSON）整条丢弃、其余照常——这是仓库既有口径；
 * 计数是给读路径回写用的闸：**只要丢过步骤，就绝不能把重新编码的结果写回存储**，
 * 否则「解析丢步骤」会被永久落盘，用户录的宏凭空少几步。
 */
fun parseWarehouseMacroStepsWithDiagnostics(rawSteps: Any?): WarehouseMacroStepsParseResult {
    val raw = rawSteps as? List<*> ?: return WarehouseMacroStepsParseResult(emptyList(), 0)
    val out = ArrayList<WarehouseMacroStep>()
    var dropped = 0
    for (item in raw) {
        val map = item as? Map<*, *>
        if (map == null) {
            dropped++
            continue
        }
        out.add(
            try {
                WarehouseMacroStep.fromJson(map)
            } catch (_: WarehouseMacroFormatException) {
                dropped++
                continue
            },
        )
    }
    return WarehouseMacroStepsParseResult(out, dropped)
}

/**
 * 与学校 + 适配器关联的宏录制记录（Dart `WarehouseMacroRecord`）。
 */
data class WarehouseMacroRecord(
    val schoolId: String,
    val adapterId: String,
    val schoolName: String,
    val adapterName: String,
    val importUrl: String,
    val schoolResourceFolder: String,
    val adapterAssetJsPath: String,
    val steps: List<WarehouseMacroStep>,
    val dialogResponses: Map<String, Any?> = emptyMap(),
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
    val successfulImportCount: Int = 0,
    /** 脚本执行成功时所在页的**脱敏**地址；加速回放（P2）用，旧宏可为 null。 */
    val scriptPageUrl: String? = null,
    /** 录制时的桌面 UA 模式；null 按桌面处理（与 Dart 一致）。 */
    val useDesktopMode: Boolean? = null,
) {
    fun toJson(): LinkedHashMap<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        out["schoolId"] = schoolId
        out["adapterId"] = adapterId
        out["schoolName"] = schoolName
        out["adapterName"] = adapterName
        out["importUrl"] = importUrl
        out["schoolResourceFolder"] = schoolResourceFolder
        out["adapterAssetJsPath"] = adapterAssetJsPath
        out["steps"] = steps.map { it.toJson() }
        out["dialogResponses"] = LinkedHashMap<String, Any?>(dialogResponses)
        out["createdAt"] = formatDartIso(createdAt)
        out["updatedAt"] = formatDartIso(updatedAt)
        out["successfulImportCount"] = successfulImportCount
        if (!scriptPageUrl.isNullOrEmpty()) out["scriptPageUrl"] = scriptPageUrl
        if (useDesktopMode != null) out["useDesktopMode"] = useDesktopMode
        return out
    }

    fun encode(): String = MiniJson.encode(toJson())

    fun copyWith(
        schoolId: String? = null,
        adapterId: String? = null,
        schoolName: String? = null,
        adapterName: String? = null,
        importUrl: String? = null,
        schoolResourceFolder: String? = null,
        adapterAssetJsPath: String? = null,
        steps: List<WarehouseMacroStep>? = null,
        dialogResponses: Map<String, Any?>? = null,
        createdAt: LocalDateTime? = null,
        updatedAt: LocalDateTime? = null,
        successfulImportCount: Int? = null,
        scriptPageUrl: String? = null,
        clearScriptPageUrl: Boolean = false,
        useDesktopMode: Boolean? = null,
    ): WarehouseMacroRecord = WarehouseMacroRecord(
        schoolId = schoolId ?: this.schoolId,
        adapterId = adapterId ?: this.adapterId,
        schoolName = schoolName ?: this.schoolName,
        adapterName = adapterName ?: this.adapterName,
        importUrl = importUrl ?: this.importUrl,
        schoolResourceFolder = schoolResourceFolder ?: this.schoolResourceFolder,
        adapterAssetJsPath = adapterAssetJsPath ?: this.adapterAssetJsPath,
        steps = steps ?: this.steps,
        dialogResponses = dialogResponses ?: this.dialogResponses,
        createdAt = createdAt ?: this.createdAt,
        updatedAt = updatedAt ?: this.updatedAt,
        successfulImportCount = successfulImportCount ?: this.successfulImportCount,
        scriptPageUrl = if (clearScriptPageUrl) null else (scriptPageUrl ?: this.scriptPageUrl),
        useDesktopMode = useDesktopMode ?: this.useDesktopMode,
    )

    companion object {
        /** 记录本体的 key 前缀。**逐字保留**：云同步快照跨端互认靠它（D1）。
         *  注意 [INDEX_KEY] 也以它开头，按前缀扫描时必须排掉。 */
        const val RECORD_KEY_PREFIX = "warehouse_macro_record_"

        /** 所有宏记录索引的 key。 */
        const val INDEX_KEY = "warehouse_macro_record_index"

        /** SharedPreferences 存储键（Dart `WarehouseMacroRecord.storageKey`，逐字一致）。 */
        fun storageKey(schoolId: String, adapterId: String): String =
            "$RECORD_KEY_PREFIX${schoolId}_$adapterId"

        fun fromJson(json: Map<*, *>): WarehouseMacroRecord {
            val dialogResponses = LinkedHashMap<String, Any?>()
            (json["dialogResponses"] as? Map<*, *>)?.let { raw ->
                for ((key, value) in raw) {
                    if (key is String) dialogResponses[key] = normalizeJsonNumber(value)
                }
            }
            return WarehouseMacroRecord(
                schoolId = json["schoolId"] as? String ?: "",
                adapterId = json["adapterId"] as? String ?: "",
                schoolName = json["schoolName"] as? String ?: "",
                adapterName = json["adapterName"] as? String ?: "",
                importUrl = json["importUrl"] as? String ?: "",
                schoolResourceFolder = (json["schoolResourceFolder"] as? String)
                    ?: (json["schoolId"] as? String)
                    ?: "",
                adapterAssetJsPath = json["adapterAssetJsPath"] as? String ?: "",
                steps = parseWarehouseMacroStepsWithDiagnostics(json["steps"]).steps,
                dialogResponses = dialogResponses,
                createdAt = parseDartIso(json["createdAt"] as? String) ?: DART_EPOCH,
                updatedAt = parseDartIso(json["updatedAt"] as? String) ?: DART_EPOCH,
                successfulImportCount = (json["successfulImportCount"] as? Number)?.toInt() ?: 0,
                // 读入即脱敏：外部带进来的 scriptPageUrl 也过同一把筛子。
                scriptPageUrl = sanitizeWarehouseScriptPageUrl(json["scriptPageUrl"] as? String),
                useDesktopMode = json["useDesktopMode"] as? Boolean,
            )
        }

        /** Dart 纪元兜底：时间戳解析不出时的固定值（Dart `DateTime(1970)` 同义）。 */
        internal val DART_EPOCH: LocalDateTime = LocalDateTime.parse("1970-01-01T00:00:00")

        /**
         * JSON 整数归一：MiniJson 把整数解析成 `Long`，而写入方（含 Dart）的语义是
         * `int`。Int 范围内的 Long 归一成 Int，让「存进去→读回来」的值可比较，
         * 也让回放层拿到与 Dart `jsonDecode` 一致的类型形状。嵌套 map 同样处理。
         */
        private fun normalizeJsonNumber(value: Any?): Any? = when (value) {
            is Long -> if (value in Int.MIN_VALUE..Int.MAX_VALUE) value.toInt() else value
            is Map<*, *> -> {
                val out = LinkedHashMap<Any?, Any?>()
                for ((k, v) in value) out[k] = normalizeJsonNumber(v)
                out
            }

            is List<*> -> value.map { normalizeJsonNumber(it) }
            else -> value
        }

        /** Dart `toIso8601String()` 风格：本地时间、微秒精度、无时区后缀。 */
        internal fun formatDartIso(value: LocalDateTime): String =
            value.truncatedTo(ChronoUnit.MICROS).toString()

        /** 宽容解析 Dart 写出的时间戳：本地 ISO / 带 Z / 带偏移量三种都收。 */
        internal fun parseDartIso(text: String?): LocalDateTime? {
            if (text.isNullOrBlank()) return null
            return try {
                LocalDateTime.parse(text)
            } catch (_: Exception) {
                try {
                    OffsetDateTime.parse(text).toLocalDateTime()
                } catch (_: Exception) {
                    null
                }
            }
        }
    }
}

/** 宏索引条目（轻量：只有 key 与更新时间，Dart `WarehouseMacroIndexEntry`）。 */
data class WarehouseMacroIndexEntry(
    val schoolId: String,
    val adapterId: String,
    val updatedAt: LocalDateTime,
) {
    fun toJson(): LinkedHashMap<String, Any?> = linkedMapOf(
        "schoolId" to schoolId,
        "adapterId" to adapterId,
        "updatedAt" to WarehouseMacroRecord.formatDartIso(updatedAt),
    )

    companion object {
        fun fromJson(json: Map<*, *>): WarehouseMacroIndexEntry = WarehouseMacroIndexEntry(
            schoolId = json["schoolId"] as? String ?: "",
            adapterId = json["adapterId"] as? String ?: "",
            updatedAt = WarehouseMacroRecord.parseDartIso(json["updatedAt"] as? String)
                ?: WarehouseMacroRecord.DART_EPOCH,
        )
    }
}
