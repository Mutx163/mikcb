package com.mutx163.qingyu.pages.diagnostics

/**
 * 三份日志入口的统一配置（源：`lib/screens/log_viewer_entry.dart`）。
 *
 * Dart 侧这层存在的理由（源文件注释）：查看器一直是同一个 widget，但五个调用点各自
 * 拼配置，其中两处是逐字复制的副本，已经开始漂移（其中一处清空会弹两次 toast）。
 * 现在路由名、导出文件名、分享文案都收在这里；记录开关搬到「设置 → 诊断与日志」，
 * 查看器保持纯只读。
 *
 * 本文件把「每个入口长什么样」变成纯数据，渲染层（查看器本身）不用再关心来源：
 * - [AppLogSource]：合并应用日志 / 仅超级岛日志 / 教务导入会话日志；
 * - [LogViewerEntryLogic.configFor]：标题、路由名、导出文件名、分享文案、空态行为，
 *   以及「这个入口有没有清空按钮」。
 *
 * 注意：warehouseImport 的导出是 `.txt`，另两个是 `.log`；live 入口**故意没有清空**
 * （它一空就自己 pop，页面内清空会把用户脚下的页面关掉），清空动作归「超级岛自检」。
 */
enum class AppLogSource { MERGED, LIVE, WAREHOUSE_IMPORT }

/** 单个入口的完整配置。 */
data class LogViewerEntryConfig(
    val source: AppLogSource,
    val title: String,
    val routeName: String,
    val exportFileNamePrefix: String,
    val exportFileExtension: String,
    val shareText: String,
    val shareSubject: String,
    /** 导出时如果文本为空要提示什么（null = 不提示，直接导出）。 */
    val emptyExportMessage: String?,
    /** 有没有清空按钮（live 没有）。 */
    val supportsClear: Boolean,
    /** 日志为空时要弹出的提示（null = 什么都不做）。 */
    val emptyLoadMessage: String?,
    /** 空态时是否自己 pop 掉查看器（只有 live）。 */
    val popsOnEmpty: Boolean,
    /** 空态提示用「轻提示」而不是 toast（只有 warehouseImport）。 */
    val usesLightTipOnEmpty: Boolean,
)

object LogViewerEntryLogic {

    fun configFor(source: AppLogSource): LogViewerEntryConfig = when (source) {
        AppLogSource.MERGED -> LogViewerEntryConfig(
            source = source,
            title = DiagnosticsStrings.aboutAppLogsTitle.zh,
            routeName = "/logs/app",
            exportFileNamePrefix = "mikcb-app-logs-",
            exportFileExtension = "log",
            shareText = DiagnosticsStrings.appLogsShareText.zh,
            shareSubject = DiagnosticsStrings.appLogsShareSubject.zh,
            emptyExportMessage = DiagnosticsStrings.aboutNoDiagnosticsExportYet.zh,
            supportsClear = true,
            emptyLoadMessage = null,
            popsOnEmpty = false,
            usesLightTipOnEmpty = false,
        )

        AppLogSource.LIVE -> LogViewerEntryConfig(
            source = source,
            title = DiagnosticsStrings.liveDiagnosticsViewerTitle.zh,
            routeName = "/logs/live",
            exportFileNamePrefix = "mikcb-live-diagnostics-",
            exportFileExtension = "log",
            shareText = DiagnosticsStrings.liveDiagnosticsShareText.zh,
            shareSubject = DiagnosticsStrings.liveDiagnosticsShareSubject.zh,
            emptyExportMessage = DiagnosticsStrings.liveDiagnosticsNothingToExport.zh,
            supportsClear = false,
            emptyLoadMessage = DiagnosticsStrings.liveDiagnosticsUnavailable.zh,
            popsOnEmpty = true,
            usesLightTipOnEmpty = false,
        )

        AppLogSource.WAREHOUSE_IMPORT -> LogViewerEntryConfig(
            source = source,
            title = DiagnosticsStrings.warehouseImportExecutionLogTitle.zh,
            routeName = "/logs/warehouse-import",
            exportFileNamePrefix = "qingyu-warehouse-import-log-",
            exportFileExtension = "txt",
            shareText = DiagnosticsStrings.warehouseImportExecutionLogShareText.zh,
            shareSubject = DiagnosticsStrings.warehouseImportExecutionLogShareSubject.zh,
            emptyExportMessage = null,
            supportsClear = true,
            emptyLoadMessage = DiagnosticsStrings.warehouseImportExecutionLogEmpty.zh,
            popsOnEmpty = false,
            usesLightTipOnEmpty = true,
        )
    }

    /**
     * 导出文件名（Dart：`'${prefix}${DateTime.now().millisecondsSinceEpoch}.$ext'`）。
     *
     * 时间戳由调用方传入，保持纯函数可测。
     */
    fun exportFileName(source: AppLogSource, epochMillis: Long): String {
        val config = configFor(source)
        return "${config.exportFileNamePrefix}$epochMillis.${config.exportFileExtension}"
    }

    /** 双击保护：已经在打开中就忽略（Dart 的 `_opening` 标志）。 */
    fun shouldIgnoreOpen(isOpening: Boolean): Boolean = isOpening
}
