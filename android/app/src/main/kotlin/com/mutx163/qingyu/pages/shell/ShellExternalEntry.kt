package com.mutx163.qingyu.pages.shell

/**
 * 外部入口（R1 切壳补口，2026-11-02）的**纯判定逻辑**：外部应用把文件 / scheme / 调试
 * 深链打进本 App 时，判断「这是什么、该落到壳的哪一页」。零 `android.*` 导入，进
 * `pages/shell` 域的 L0 单测。
 *
 * ## 背景：为什么要有这个文件
 *
 * 2026-11-02 起 launcher 已切到 Compose 壳（`1158ee20`），但三条外部入口的
 * intent-filter 仍挂在 Flutter 的 `.MainActivity` 上：`VIEW` / `SEND` 文件导入、
 * `um.<key>://` 友盟 scheme、（debug overlay 的）`mikcb-debug://` 自动化深链。
 * 删掉 Flutter 前必须把它们挪到不依赖 Flutter 的组件上——本文件提供判定，
 * `pages/ShellExternalEntryActivity`（透明跳板）提供 Android 胶水，
 * 壳 [com.mutx163.qingyu.pages.PagesShellActivity] 只留一行消费钩子。
 *
 * ## 判定逻辑的出处
 *
 * 深链路径规范化与导入 kind 识别**逐字**照搬 `MainActivity`
 * （`handleDebugDeepLinkIntent` / `detectImportKind`，2026-10-19 落地）的同名口径；
 * MainActivity 那份在 R2 摘 Flutter 时随壳一起删除，过渡期两份并存，**以本文件为
 * 新壳的唯一事实源**，改动必须同步单测（`ShellExternalEntryTest`）。
 */
object ShellExternalEntry {

    // ── mikcb-debug 自动化深链 ──────────────────────────────────────────────

    /** 深链 scheme：与 `MainActivity.handleDebugDeepLinkIntent` 同值。 */
    const val DEBUG_SCHEME = "mikcb-debug"

    /**
     * 调试自动化深链只在 `*.debug` / `*.profile` 包生效
     * （与 `MainActivity.isDebugAutomationPackage` 同口径）。
     */
    fun isDebugAutomationPackageId(packageName: String): Boolean =
        packageName.endsWith(".debug") || packageName.endsWith(".profile")

    /**
     * 深链路径规范化（`handleDebugDeepLinkIntent` :1389-1405 逐字口径）：
     * 优先「路径绝对形」`mikcb-debug:///settings/live`（host 空）；兼容
     * 「host 形」`mikcb-debug://settings/live`。两段都有用 `/` 拼接。
     * 全空回落 `"home"`。
     */
    fun normalizeDebugDeepLinkPath(host: String?, pathSegment: String?): String {
        val trimmedHost = host?.trim().orEmpty()
        val trimmedPath = pathSegment?.trim().orEmpty().removePrefix("/")
        return when {
            trimmedHost.isEmpty() && trimmedPath.isEmpty() -> "home"
            trimmedHost.isEmpty() -> trimmedPath
            trimmedPath.isEmpty() -> trimmedHost
            else -> "$trimmedHost/$trimmedPath"
        }.trim().removePrefix("/")
    }

    /**
     * 规范化 path → 壳页面 id。映射表由调用方注入（正式接线传
     * `ShellWiring::shellPageIdForRoute`，纯逻辑不反向依赖 pages 根的接线层）；
     * 映射不到返回 null = 落壳首页（与 Dart 收到未知路由后的行为一致：no-op）。
     */
    fun debugRoutePageId(path: String, routeToPage: (String) -> String?): String? =
        routeToPage(path)

    // ── 外部文件导入（VIEW / SEND）──────────────────────────────────────────

    /**
     * 这条 intent 是否按「外部文件导入」处理。
     *
     * VIEW / SEND 共享 `ACTION_VIEW` 与深链：`mikcb-debug://` 的 VIEW 绝不能当
     * content URI 打开（会向 logcat 刷 `FileNotFoundException: No content provider`，
     * `MainActivity.handleExternalImportIntent` :1438-1446 同一口径）。
     */
    fun isExternalImportAction(action: String?, dataScheme: String?): Boolean {
        if (action != "android.intent.action.VIEW" && action != "android.intent.action.SEND") {
            return false
        }
        return dataScheme != DEBUG_SCHEME
    }

    /** 导入文件体积上限：与 `ExternalImportReader.MAX_IMPORT_BYTES` 同值（对方 object 可引用，此处写常量供纯逻辑层判断用）。 */
    const val MAX_IMPORT_BYTES: Long = 20L * 1024 * 1024

    /** 分享导入超限时交给导入页的 kind（`MainActivity.EXTERNAL_IMPORT_TOO_LARGE_KIND` 同值）。 */
    const val IMPORT_KIND_TOO_LARGE = "too_large"

    /**
     * 导入 kind 判定（`MainActivity.detectImportKind` :1637-1691 逐字搬移）。
     * 返回 `ics` / `backup` / `spreadsheet` / null（不是可导入内容）。
     */
    fun detectImportKind(fileName: String, mimeType: String?, bytes: ByteArray): String? {
        val extension = fileName.substringAfterLast('.', "").lowercase(java.util.Locale.US)
        val normalizedMime = mimeType?.lowercase(java.util.Locale.US)
        val textPreview = if (bytes.size <= 65536) {
            bytes.toString(Charsets.UTF_8)
        } else {
            bytes.copyOf(65536).toString(Charsets.UTF_8)
        }

        when {
            extension == "ics" || normalizedMime?.startsWith("text/calendar") == true -> {
                return "ics"
            }
            extension == "mikcb" -> return "backup"
            extension == "json" || normalizedMime == "application/json" -> return "backup"
            extension == "csv" ||
                normalizedMime == "text/csv" ||
                normalizedMime == "text/comma-separated-values" -> {
                return "spreadsheet"
            }
            extension == "xlsx" ||
                normalizedMime ==
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> {
                return "spreadsheet"
            }
        }

        if (normalizedMime == "application/octet-stream" || normalizedMime == "*/*") {
            when (extension) {
                "ics" -> return "ics"
                "mikcb", "json" -> return "backup"
                "csv", "xlsx" -> return "spreadsheet"
            }
        }

        if (textPreview.contains("VCALENDAR", ignoreCase = true)) {
            return "ics"
        }
        if (textPreview.trimStart().startsWith("{") && textPreview.contains("\"mikcb\"")) {
            return "backup"
        }
        if (bytes.size >= 4 &&
            bytes[0] == 0x50.toByte() &&
            bytes[1] == 0x4B.toByte() &&
            (extension == "xlsx" || extension.isEmpty())
        ) {
            return "spreadsheet"
        }

        return null
    }

    /** 「provider 自报体积超上限」的纯判定（读流之前的短路，与读胶水配合用）。 */
    fun declaredSizeExceedsCap(declaredBytes: Long): Boolean = declaredBytes > MAX_IMPORT_BYTES

    // ── 待导入 payload 与壳页面落点 ─────────────────────────────────────────

    /**
     * 一次已读好的外部导入（跳板在后台线程组装，壳的导入页族消费）。
     *
     * 文本类（ics / backup）读成 UTF-8 文本（坏字节 U+FFFD，与 Dart
     * `utf8.decode(allowMalformed: true)` 同口径）；表格保留原始字节（csv 编码探测 /
     * xlsx 容器解码都发生在导入页的解析层）。**不再落盘缓存文件**——Flutter 版给
     * Dart 传的是缓存路径，壳里的 [com.mutx163.qingyu.pages.import.SpreadsheetImportHost]
     * 直接吃字节，省一次落盘。
     */
    sealed interface ImportPayload {
        val fileName: String

        /** WakeUp 风格日历文本；已过「含 VCALENDAR」校验。 */
        data class Ics(override val fileName: String, val text: String) : ImportPayload

        /** `.mikcb` / `.json` 备份文本；已过「含 "mikcb"」校验。 */
        data class Backup(override val fileName: String, val text: String) : ImportPayload

        /** csv / xlsx 原始字节。 */
        data class Spreadsheet(override val fileName: String, val bytes: ByteArray) : ImportPayload

        /** provider 自报超限：导入页据此弹本地化的「文件过大」。 */
        data class TooLarge(override val fileName: String, val maxBytes: Long) : ImportPayload
    }

    /**
     * payload → 壳页面 id。
     *
     * backup（数据传输页 `g3.dataTransfer`）：跳板只负责「带到对的页面」，
     * 备份文本由传输页宿主经 [com.mutx163.qingyu.pages.ShellExternalEntryHub.consumeImport]
     * 接进导入预览（与「选择文件导入」同一条链路，2026-11-02 接上）。
     */
    fun importTargetPage(payload: ImportPayload): String = when (payload) {
        is ImportPayload.Ics -> "g1.icsImport"
        is ImportPayload.Spreadsheet -> "g1.spreadsheetImport"
        is ImportPayload.Backup -> "g3.dataTransfer"
        is ImportPayload.TooLarge -> "g1.importEntry"
    }

    /**
     * 字节 + kind → payload；文本类校验不过返回 null（不是可导入内容，
     * 与 `MainActivity.loadExternalImportFromUri` :1496-1516 同口径）。
     */
    fun buildImportPayload(
        kind: String,
        fileName: String,
        bytes: ByteArray,
    ): ImportPayload? = when (kind) {
        "ics" -> {
            val text = bytes.toString(Charsets.UTF_8)
            if (!text.contains("VCALENDAR", ignoreCase = true)) null else ImportPayload.Ics(fileName, text)
        }
        "backup" -> {
            val text = bytes.toString(Charsets.UTF_8)
            if (!text.contains("\"mikcb\"")) null else ImportPayload.Backup(fileName, text)
        }
        "spreadsheet" -> ImportPayload.Spreadsheet(fileName, bytes)
        else -> null
    }
}
