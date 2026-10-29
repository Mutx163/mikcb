package com.mutx163.qingyu.infra

import com.mutx163.qingyu.core.MiniJson
import java.io.File

/**
 * 应用日志落盘的**纯逻辑核**（源：`lib/services/app_log_service.dart`）。
 *
 * 与 `InfraLog`（[buildLogEntryPayload]）、[injectSourceIntoSections] 同源：
 * 单条 payload 的组装、脱敏、截断计算都复用那里，本文件只补「文件 / 头部 /
 * 合并 / 指纹 / 记录开关」这几块 `AppLogService` 独有的口径。
 *
 * ## 为什么这一层必须纯 JVM
 *
 * `scripts/test-kotlin-module.ps1` 的判定是「共享目录里只要有一个 .kt 引
 * `android.*` 就**跳过整个目录**」。`infra/` 现在被全队（每个模块的 L0）收进
 * classpath，一旦这里出现 `import android.content.Context`，24 个模块的 L0
 * 会同时报 `Unresolved reference: infra`。所以：
 *
 * - **本文件与 [AppLogStore] 一律不 import android / androidx / miuix**；
 * - Android 侧只允许把 `Context` 当 `Any` 传进来（[AppLogStore.initialize] 内反射取
 *   `getFilesDir()`），代价是一个反射调用，换来全队 L0 不受牵连。
 *
 * ## 口径（逐条对齐 Dart，行号写在函数上）
 *
 * | 项 | Dart | 本文件 |
 * |---|---|---|
 * | 文件 | `filesDir/logs/app_runtime.log` | [APP_LOG_FILE_NAME] |
 * | 单条 payload | `_buildEntryPayload` :529-590 | [buildAppLogEntryPayload] |
 * | 头部 | `_buildHeader` :515-527 | [buildAppLogHeader] |
 * | 超限截断 | `_trimIfNeeded` :499-513 | [trimAppLogIfNeeded] |
 * | 合并源 | `readMergedLogsText` :266-290 | [mergeAppLogText] |
 * | 轮询指纹 | `_logFileFingerprint` :489-497 | [appLogFingerprint] |
 * | 记录开关 | `_readLoggingEnabledFromPrefs` :429-480 | [recordingEnabledFromPrefs] |
 */

/** 单个日志文件上限（Dart `_maxLogBytes = 512 * 1024`）。 */
const val appLogMaxBytes: Int = 512 * 1024

/** 日志目录名（Dart `'${directory.path}/logs/$_logFileName'`）。 */
const val APP_LOG_DIR_NAME: String = "logs"

/** 应用日志文件名（Dart `_logFileName`）。 */
const val APP_LOG_FILE_NAME: String = "app_runtime.log"

/**
 * 原生超级岛诊断日志文件名。
 *
 * 写入方是 `UmengDiagnosticReporter.appendToLocalFile`（`UmengDiagnosticReporter.kt:405`），
 * 本层只读它、合并它、清空时删它——**不重写写入方**。
 */
const val NATIVE_DIAGNOSTICS_FILE_NAME: String = "live_update_diagnostics.log"

/** 头部首行（Dart `_logTitleKey = AppLogMessages.logExportTitle` = `'log_export_title'`）。 */
const val APP_LOG_HEADER_TITLE: String = "log_export_title"

/** `platform=` 的取值（Dart `defaultTargetPlatform.name`，Android 上恒为 `android`）。 */
const val APP_LOG_PLATFORM: String = "android"

/** 时间排序偏好的盘上 key（Dart `diagnostics_log_viewer_preferences.dart`，写入恒带 `flutter.` 前缀）。 */
const val DIAGNOSTICS_LOG_TIME_SORT_KEY: String = "diagnostics_log_time_sort"

/**
 * 单条落盘文本（Dart `_buildEntryPayload` :529-590）。
 *
 * 顺序与 Dart 逐行一致：`time` → `level` → `source=app` → `category` → `message`
 * → `extras`（缩进两格）→ `error` → `stackTrace` → 一个空行。
 * 级别先过 [normalizeLogLevel]（未知级别回落 `info`），message / error / stackTrace
 * 走脱敏出口，extras 命中个人字段表整值抹成 `**` —— 这些都在 [buildLogEntryPayload]
 * 里，本函数不重复实现。
 */
fun buildAppLogEntryPayload(
    level: String,
    category: String,
    message: String,
    extras: Map<String, Any?> = emptyMap(),
    nowMillis: Long,
): String = buildLogEntryPayload(
    level = normalizeLogLevel(level),
    category = category,
    message = message,
    extras = extras,
    timeMillis = nowMillis,
)

/**
 * 头部文本（Dart `_buildHeader` :515-527）。
 *
 * ```
 * log_export_title
 * exportedAt=<millis>      // 仅导出时
 * platform=android
 * version=<version>+<build> // 拿不到 PackageInfo 时整行省略
 * ----
 * ```
 *
 * [version] 由调用方组好（`version+buildNumber`），保持纯函数。
 */
fun buildAppLogHeader(
    version: String?,
    forExport: Boolean,
    nowMillis: Long,
): String {
    val lines = mutableListOf(APP_LOG_HEADER_TITLE)
    if (forExport) {
        lines.add("exportedAt=$nowMillis")
    }
    lines.add("platform=$APP_LOG_PLATFORM")
    if (!version.isNullOrEmpty()) {
        lines.add("version=$version")
    }
    lines.add("----")
    return lines.joinToString("\n")
}

/**
 * 头部 + 正文拼成一份完整文本（Dart `'$header\n$body'.trim()`）。
 *
 * 正文为空时只回头部——空文件也要有 `----` 之前的设备信息，否则查看器连
 * 「设备与导出信息」卡都画不出来。
 */
fun composeAppLogText(header: String, body: String): String {
    if (body.isBlank()) {
        return header
    }
    return "$header\n$body".trim()
}

/** 从完整文本里取出正文（`----` 之后）；没有分隔符时整份当正文（Dart `_extractBody`）。 */
fun extractAppLogBody(text: String): String = extractDiagnosticsLogBody(text)

/**
 * 超限截断（Dart `_trimIfNeeded` :499-513）：超过 [maxBytes] 时保留**后一半**字符、
 * 去掉前导空白，原地重写文件。
 *
 * 返回是否真的截断过（调用方日志/测试都靠它）。文件不存在、读失败、写失败一律
 * 返回 false 且**不抛**——日志系统的故障不能反向打断业务。
 */
fun trimAppLogIfNeeded(file: File, maxBytes: Int = appLogMaxBytes): Boolean {
    if (!file.isFile) {
        return false
    }
    if (file.length() <= maxBytes) {
        return false
    }
    return try {
        val text = file.readText()
        val retainLength = maxBytes / 2
        val retained = if (text.length <= retainLength) {
            text
        } else {
            text.substring(text.length - retainLength)
        }
        file.writeText(retained.trimStart())
        true
    } catch (t: Throwable) {
        false
    }
}

/**
 * 合并源（Dart `readMergedLogsText` :266-290）：应用日志正文 + 原生超级岛诊断日志正文，
 * 分别打上 `source=app` / `source=native` 后按「应用在前、原生在后」拼成一份。
 *
 * 已经有 `source=` 标记的段落**不动**——原生写入方自己会写 `source=`（级别推断依赖它，
 * 见 `infra/DiagnosticsLog.kt` 的 `sourceKey`），覆盖它等于篡改来源。
 */
fun mergeAppLogText(appBody: String, nativeBody: String): String {
    val sections = mutableListOf<String>()
    if (appBody.isNotEmpty()) {
        sections.add(injectSourceIntoSections(appBody, source = "app"))
    }
    if (nativeBody.isNotEmpty()) {
        sections.add(injectSourceIntoSections(nativeBody, source = "native"))
    }
    return sections.filter { it.trim().isNotEmpty() }.joinToString("\n\n").trim()
}

/**
 * 轮询指纹（Dart `_logFileFingerprint` :489-497）：`"size:mtimeMillis"`。
 *
 * 只做一次 `stat`，不读内容。文件不存在返回 null——轮询方据此知道「还没东西可合并」。
 */
fun appLogFingerprint(file: File?): String? {
    if (file == null || !file.isFile) {
        return null
    }
    return "${file.length()}:${file.lastModified()}"
}

/**
 * 「本地诊断日志」记录开关（Dart `_readLoggingEnabledFromPrefs` :429-480）。
 *
 * 读取顺序与 Dart 一致，**档案优先**：
 * 1. `timetable_profiles` 里当前激活档案（缺 id 时取第一份）的
 *    `settings.liveEnableLocalDiagnostics`；
 * 2. 都没有则读 `timetable_settings.liveEnableLocalDiagnostics`；
 * 3. 再没有（或 JSON 坏）回落到构造默认值 `false`（`timetable_settings.dart:851`）。
 *
 * JSON 由调用方给出（Android 侧来自 `FlutterSharedPreferences`），本函数不碰盘。
 */
fun recordingEnabledFromPrefs(
    settingsJson: String?,
    profilesJson: String?,
    activeProfileId: String?,
): Boolean {
    loggingEnabledFromProfiles(profilesJson, activeProfileId)?.let { return it }
    val json = settingsJson
    if (json.isNullOrEmpty()) {
        return false
    }
    val root = MiniJson.tryParse(json) as? Map<*, *> ?: return false
    return lenientBool(root["liveEnableLocalDiagnostics"]) ?: false
}

/** 档案里的开关（Dart `_readLoggingEnabledFromProfiles` :448-480），读不到返回 null。 */
private fun loggingEnabledFromProfiles(profilesJson: String?, activeProfileId: String?): Boolean? {
    if (profilesJson.isNullOrEmpty()) {
        return null
    }
    val profiles = MiniJson.tryParse(profilesJson) as? List<*> ?: return null
    if (profiles.isEmpty()) {
        return null
    }
    val candidates = profiles.mapNotNull { it as? Map<*, *> }
    if (candidates.isEmpty()) {
        return null
    }
    val active = if (activeProfileId.isNullOrEmpty()) {
        null
    } else {
        candidates.firstOrNull { it["id"] == activeProfileId }
    }
    val profile = active ?: candidates.first()
    val settings = profile["settings"] as? Map<*, *> ?: return null
    return lenientBool(settings["liveEnableLocalDiagnostics"])
}

/**
 * Dart `lenientBool`（`timetable_settings.dart`）的等价物：布尔直通，
 * `true/false/1/0/yes/no/on/off` 与数字都认，其余返回 null（调用方回落默认值）。
 */
private fun lenientBool(raw: Any?): Boolean? = when (raw) {
    is Boolean -> raw
    is Number -> raw.toDouble() != 0.0
    is String -> when (raw.trim().lowercase()) {
        "true", "1", "yes", "on" -> true
        "false", "0", "no", "off" -> false
        else -> null
    }
    else -> null
}
