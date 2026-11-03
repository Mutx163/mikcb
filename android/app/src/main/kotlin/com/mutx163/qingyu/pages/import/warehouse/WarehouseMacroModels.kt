package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 教务宏录制的**数据模型**（I2-4 录制侧；逐字对齐 Dart `lib/models/warehouse_macro_models.dart`）。
 *
 * ## 与 Dart 共享存档
 *
 * 宏记录写在与 Flutter 同一份 SharedPreferences 里（键名逐字一致：
 * `warehouse_macro_record_<schoolId>_<adapterId>` + 索引 `warehouse_macro_record_index`），
 * 迁移期两个界面读同一份宏。JSON 形状与 Dart `WarehouseMacroRecord.toJson` 逐键一致，
 * **不许改键名/缺省口径**——改了就是两套互不相认的存档。
 *
 * ## 脱敏口径（与 Dart 一致，别放松）
 *
 * - 录制时密码/验证码字段的 `value` 不落盘（见录制 JS：敏感字段发空串）；
 * - 读旧记录时 `fillField` + 敏感 `fieldType` 会被**修复**成 `waitForManualInput`
 *   （[WarehouseMacroStep.fromJson]），写回由 [WarehouseMacroStore] 在「没丢步骤」时做。
 * - 认不出的步骤 `type` **抛异常**（由上层按条目丢弃）：兜成 `delay` 等于凭空造步骤，
 *   而且不可逆——用户「另存」一次原始类型就永久丢了（Dart 注释原话）。
 */

/** 宏录制中的一步操作类型；`jsonName` 逐字对齐 Dart `MacroStepType.name`。 */
enum class WarehouseMacroStepType(val jsonName: String) {
    NAVIGATE("navigate"),
    FILL_FIELD("fillField"),
    CLICK("click"),
    WAIT_FOR_URL("waitForUrl"),
    WAIT_FOR_SELECTOR("waitForSelector"),
    WAIT_FOR_MANUAL_INPUT("waitForManualInput"),
    EXECUTE_SCRIPT("executeScript"),
    DELAY("delay");

    companion object {
        fun fromJsonName(name: String?): WarehouseMacroStepType? =
            entries.firstOrNull { it.jsonName == name }
    }
}

/** 密码 / 验证码字段的值**不落盘**（Dart `isSensitiveMacroFieldType`）。 */
fun isSensitiveWarehouseMacroFieldType(fieldType: String?): Boolean =
    fieldType == "password" || fieldType == "captcha"

/** 敏感字段转「等用户手动输」的原因串（Dart `manualInputReasonForFieldType`）。 */
fun warehouseManualInputReasonForFieldType(fieldType: String?): String =
    if (fieldType == "captcha") "manual_input_captcha" else "manual_input_password"

/**
 * 旧宏的 `waitForManualInput` 可能没存 `fieldType`，从原因串反推
 * （Dart `_inferManualInputFieldType`：中文「验证码/校验码」、captcha/verification → captcha；
 * 「密码」/password/pwd → password）。
 *
 * 中文匹配串集中在 WarehouseFormLabelStrings（Lead 拍板的方案 A 收敛：
 * 功能识别串登记基线保持可见，不转义、不整文件跳过）。
 */
internal fun inferWarehouseManualInputFieldType(reason: String?): String? {
    val value = reason ?: return null
    val lower = value.lowercase()
    if (value.contains(WarehouseFormLabelStrings.CAPTCHA_PRIMARY) ||
        value.contains(WarehouseFormLabelStrings.CAPTCHA_SECONDARY) ||
        lower.contains("captcha") || lower.contains("verification")
    ) {
        return "captcha"
    }
    if (
        value.contains(WarehouseFormLabelStrings.PASSWORD) ||
        lower.contains("password") || lower.contains("pwd")
    ) {
        return "password"
    }
    return null
}

/**
 * 脚本对话框应答的**稳定匹配键**（Dart `warehouseDialogResponseKey`）：
 * 录制时关联「用户在这个弹窗里答了什么」，回放时按同一把键找回。
 * 适配脚本给了 `dialogId` 就优先用；否则用 `type|title|正文/选项JSON`。
 *
 * ⚠️ 取值口径必须是「不是字符串就当没给」（Dart 2026-10 修过的 TypeError 洞）：
 * 脚本把 `title`/`optionsJson` 发成对象/数组时不能抛。
 */
fun warehouseDialogResponseKey(type: String, message: Map<*, *>): String {
    fun text(key: String): String? = message[key] as? String

    val dialogId = text("dialogId")?.trim().orEmpty()
    if (dialogId.isNotEmpty()) {
        return "$type|id:$dialogId"
    }
    val title = text("title")?.trim().orEmpty()
    val body = (text("message") ?: text("optionsJson"))?.trim().orEmpty()
    return "$type|$title|$body"
}

/** 宏录制中的单步操作。 */
data class WarehouseMacroStep(
    val type: WarehouseMacroStepType,
    /** 字段类型：username / password / captcha / other。 */
    val fieldType: String? = null,
    /** CSS 选择器或 URL 模式。 */
    val selector: String? = null,
    /** 填充的值（敏感字段恒为空/null，见文件头脱敏口径）。 */
    val value: String? = null,
    /** 等待时长（毫秒），用于 delay / waitForUrl / waitForSelector 的超时。 */
    val waitMs: Int = 0,
) {
    fun toJson(): Map<String, Any?> {
        val shouldOmitValue =
            type == WarehouseMacroStepType.FILL_FIELD && isSensitiveWarehouseMacroFieldType(fieldType)
        val map = LinkedHashMap<String, Any?>()
        map["type"] = type.jsonName
        if (!fieldType.isNullOrEmpty()) map["fieldType"] = fieldType
        if (!selector.isNullOrEmpty()) map["selector"] = selector
        if (!shouldOmitValue && !value.isNullOrEmpty()) map["value"] = value
        if (waitMs > 0) map["waitMs"] = waitMs
        return map
    }

    companion object {
        /**
         * 从 JSON 还原一步。**认不出的 `type` 抛 [IllegalArgumentException]**（契约见文件头）；
         * 上层 loader 对坏条目按「整条丢弃、其余照常」处理。
         */
        fun fromJson(json: Map<*, *>): WarehouseMacroStep {
            val type = WarehouseMacroStepType.fromJsonName(json["type"] as? String)
                ?: throw IllegalArgumentException("macro_step_type_unrecognized")
            val fieldType = json["fieldType"] as? String
            if (type == WarehouseMacroStepType.FILL_FIELD && isSensitiveWarehouseMacroFieldType(fieldType)) {
                return waitForManualInput(
                    warehouseManualInputReasonForFieldType(fieldType),
                    selector = json["selector"] as? String,
                    fieldType = fieldType,
                )
            }
            val value = json["value"] as? String
            val repairedFieldType = if (type == WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT) {
                fieldType ?: inferWarehouseManualInputFieldType(value)
            } else {
                fieldType
            }
            return WarehouseMacroStep(
                type = type,
                fieldType = repairedFieldType,
                selector = json["selector"] as? String,
                value = value,
                waitMs = WarehouseCourseImportLogic.coerceInt(json["waitMs"]) ?: 0,
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
            WarehouseMacroStep(type = WarehouseMacroStepType.WAIT_FOR_URL, value = pattern, waitMs = 15000)

        fun waitForSelector(selector: String): WarehouseMacroStep =
            WarehouseMacroStep(type = WarehouseMacroStepType.WAIT_FOR_SELECTOR, selector = selector, waitMs = 15000)

        fun waitForManualInput(reason: String, selector: String? = null, fieldType: String? = null): WarehouseMacroStep =
            WarehouseMacroStep(
                type = WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT,
                selector = selector,
                fieldType = fieldType,
                value = reason,
            )

        val executeScript: WarehouseMacroStep = WarehouseMacroStep(type = WarehouseMacroStepType.EXECUTE_SCRIPT)

        fun delay(ms: Int): WarehouseMacroStep = WarehouseMacroStep(type = WarehouseMacroStepType.DELAY, waitMs = ms)
    }
}

/** 解析宏记录里的步骤列表；坏条目整条丢弃（Dart 同口径），并告诉调用方丢了几条。 */
data class WarehouseMacroStepsParse(val steps: List<WarehouseMacroStep>, val droppedStepCount: Int)

fun parseWarehouseMacroStepsWithDiagnostics(rawStepsJson: Any?): WarehouseMacroStepsParse {
    val rawSteps = rawStepsJson as? List<*> ?: return WarehouseMacroStepsParse(emptyList(), 0)
    val out = ArrayList<WarehouseMacroStep>(rawSteps.size)
    var dropped = 0
    for (entry in rawSteps) {
        if (entry !is Map<*, *>) {
            dropped++
            continue
        }
        try {
            out.add(WarehouseMacroStep.fromJson(entry))
        } catch (_: Exception) {
            dropped++
        }
    }
    return WarehouseMacroStepsParse(out, dropped)
}

/** 与学校+适配器关联的宏录制记录（JSON 形状逐键对齐 Dart `WarehouseMacroRecord`）。 */
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
    /** 脚本执行成功时所在页地址（加速回放的落点）；旧宏没有。 */
    val scriptPageUrl: String? = null,
    /** 录制时的桌面 UA 开关；null 视为桌面（Dart 缺省口径）。 */
    val useDesktopMode: Boolean? = null,
) {
    fun toJson(): Map<String, Any?> {
        val map = LinkedHashMap<String, Any?>()
        map["schoolId"] = schoolId
        map["adapterId"] = adapterId
        map["schoolName"] = schoolName
        map["adapterName"] = adapterName
        map["importUrl"] = importUrl
        map["schoolResourceFolder"] = schoolResourceFolder
        map["adapterAssetJsPath"] = adapterAssetJsPath
        map["steps"] = steps.map { it.toJson() }
        map["dialogResponses"] = dialogResponses
        map["createdAt"] = createdAt.format(ISO)
        map["updatedAt"] = updatedAt.format(ISO)
        map["successfulImportCount"] = successfulImportCount
        if (!scriptPageUrl.isNullOrEmpty()) map["scriptPageUrl"] = scriptPageUrl
        if (useDesktopMode != null) map["useDesktopMode"] = useDesktopMode
        return map
    }

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /** 记录本体的 key 前缀。注意 [INDEX_KEY] 也以它开头，按前缀扫描时必须排掉。 */
        const val RECORD_KEY_PREFIX = "warehouse_macro_record_"

        /** 所有宏记录索引的 key。 */
        const val INDEX_KEY = "warehouse_macro_record_index"

        /** ISO_LOCAL_DATE_TIME 与 Dart `DateTime.toIso8601String` / `tryParse` 双向兼容。 */
        private val ISO: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

        fun storageKey(schoolId: String, adapterId: String): String =
            "$RECORD_KEY_PREFIX${schoolId}_$adapterId"

        fun fromJson(json: Map<*, *>): WarehouseMacroRecord {
            val schoolId = json["schoolId"] as? String ?: ""
            val dialogResponses = (json["dialogResponses"] as? Map<*, *>)
                ?.mapKeys { it.key.toString() }
                ?: emptyMap()
            return WarehouseMacroRecord(
                schoolId = schoolId,
                adapterId = json["adapterId"] as? String ?: "",
                schoolName = json["schoolName"] as? String ?: "",
                adapterName = json["adapterName"] as? String ?: "",
                importUrl = json["importUrl"] as? String ?: "",
                schoolResourceFolder = json["schoolResourceFolder"] as? String ?: schoolId,
                adapterAssetJsPath = json["adapterAssetJsPath"] as? String ?: "",
                steps = parseWarehouseMacroStepsWithDiagnostics(json["steps"]).steps,
                dialogResponses = dialogResponses,
                createdAt = parseIso(json["createdAt"] as? String),
                updatedAt = parseIso(json["updatedAt"] as? String),
                successfulImportCount = WarehouseCourseImportLogic.coerceInt(json["successfulImportCount"]) ?: 0,
                scriptPageUrl = sanitizeWarehouseScriptPageUrl(json["scriptPageUrl"] as? String),
                useDesktopMode = json["useDesktopMode"] as? Boolean,
            )
        }

        /** 解析失败回 epoch 零点（Dart `DateTime.fromMillisecondsSinceEpoch(0)` 的本地零点口径）。 */
        private fun parseIso(text: String?): LocalDateTime =
            text?.let { runCatching { LocalDateTime.parse(it, ISO) }.getOrNull() }
                ?: LocalDateTime.of(1970, 1, 1, 0, 0)
    }
}

/**
 * 一次性/会话类 URL 参数名（Dart `warehouseVolatileUrlParamKeys`）。
 * 精确名单之外还有子串口径：PHP `PHPSESSID`、ASP.NET `ASP.NET_SessionId` 才是教务站
 * 真正会发的名字，精确名单里一个都没有（Dart 2026-10-02 随机属性测试抓到）。
 */
private val WAREHOUSE_VOLATILE_URL_PARAM_KEYS = setOf(
    "jsessionid", "jsessionId", "JSESSIONID", "ticket", "token", "access_token",
    "refresh_token", "state", "nonce", "timestamp", "ts", "t", "random", "rnd",
    "sid", "sessionid", "sessionId",
)

/**
 * 某个 URL 参数名是不是「换一次会话就失效、而且可能是凭据」的那一类。
 * 密码类键名扩围是有意的：要存进宏、进云同步、写日志的值里不该有它们。
 */
fun isWarehouseVolatileUrlParamKey(key: String): Boolean {
    if (WAREHOUSE_VOLATILE_URL_PARAM_KEYS.contains(key)) return true
    val lowerKey = key.lowercase()
    if (WAREHOUSE_VOLATILE_URL_PARAM_KEYS.contains(lowerKey)) return true
    return lowerKey.contains("token") ||
        lowerKey.contains("ticket") ||
        lowerKey.contains("jsession") ||
        lowerKey.contains("sess") ||
        lowerKey.contains("pwd") ||
        lowerKey.contains("passwd") ||
        lowerKey.contains("password")
}

private val FRAGMENT_PARAM_KEY_REGEX = Regex("(?:^|[?&#;/])\\s*([A-Za-z_][A-Za-z0-9_.\\-]*)\\s*=")

/** fragment 里有没有夹带会话/凭据参数（OAuth 回调风格的 `#access_token=…`）。 */
fun warehouseFragmentCarriesVolatileParam(fragment: String): Boolean =
    FRAGMENT_PARAM_KEY_REGEX.findAll(fragment)
        .mapNotNull { it.groupValues.getOrNull(1) }
        .any { isWarehouseVolatileUrlParamKey(it) }

/**
 * 剥掉一次性/会话 query 参数，让存下来的脚本页地址跨会话可重放
 * （Dart `sanitizeWarehouseScriptPageUrl`）。不是合法 http(s) 绝对地址时回 null。
 *
 * Java `URI` 对 `http://host;jsessionid=ABC/path` 的 `host` 会判 null（`;` 非法），
 * 所以 host 从 rawAuthority 里手工清：先剥 userinfo，再从第一个 `;` 截断——
 * 域名里永远不该有 `;`（Dart 注释同口径）。
 */
fun sanitizeWarehouseScriptPageUrl(rawUrl: String?): String? {
    val trimmed = rawUrl?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    val uri = runCatching { java.net.URI(trimmed) }.getOrNull() ?: return null
    val scheme = uri.scheme?.lowercase()
    if (scheme != "http" && scheme != "https") return null

    val authority = uri.rawAuthority?.substringAfter('@') ?: return null
    val authorityClean = authority.substringBefore(';')
    val host = authorityClean.substringBefore(':')
    if (host.isEmpty()) return null
    val port = authorityClean.substringAfter(':', "").toIntOrNull()

    // Drop path-embedded ;jsessionid=...
    val cleanedPath = (uri.rawPath ?: "")
        .replace(Regex(";jsessionid=[^;/]+", RegexOption.IGNORE_CASE), "")
        .ifEmpty { "/" }

    val keptQuery = uri.rawQuery
        ?.split('&')
        ?.filter { pair ->
            val key = pair.substringBefore('=').substringBefore(';')
            key.isNotEmpty() && !isWarehouseVolatileUrlParamKey(key)
        }
        ?.takeIf { it.isNotEmpty() }
        ?.joinToString("&")

    // hash 路由的教务站（Vue/React SPA）把目标页整个写在 fragment 里，不能丢；
    // 但 fragment 也可能夹一次性回调凭据，命中就整段丢（与 query 同一份键名判据）。
    val fragment = uri.rawFragment
    val keptFragment = if (!fragment.isNullOrEmpty() && !warehouseFragmentCarriesVolatileParam(fragment)) {
        fragment
    } else {
        null
    }

    return buildString {
        append(scheme).append("://").append(host)
        if (port != null && port >= 0) append(':').append(port)
        append(cleanedPath)
        if (keptQuery != null) append('?').append(keptQuery)
        if (keptFragment != null) append('#').append(keptFragment)
    }
}
