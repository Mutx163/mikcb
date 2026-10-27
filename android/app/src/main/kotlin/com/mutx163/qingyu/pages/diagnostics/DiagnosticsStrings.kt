package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.DiagnosticsLogLevel

/**
 * 诊断 / 日志模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [DiagnosticsStringsParityTest] 里与 ARB
 * 机械比对，键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+
 * 重新生成 `gen-l10n`，再同步这里。
 *
 * 命名与 ARB 键逐字一致（`appLogsCopyAction` 等），便于 `grep` 双向核对。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

object DiagnosticsStrings {

    // ── 日志查看器：顶栏动作与提示 ──
    val appLogsCopyAction = ArbText("appLogsCopyAction", "复制日志")
    val appLogsCopied = ArbText("appLogsCopied", "已复制当前日志")
    val appLogsExportAction = ArbText("appLogsExportAction", "导出日志")
    val appLogsClearAction = ArbText("appLogsClearAction", "清空日志")
    val appLogsCleared = ArbText("appLogsCleared", "已清空应用日志")
    val appLogsClearFailed = ArbText("appLogsClearFailed", "清空应用日志失败")
    val appLogsRecordingPausedHint =
        ArbText("appLogsRecordingPausedHint", "记录已关闭，下方为历史日志，关闭后不再新增")

    /** 顶栏返回按钮的无障碍标签（Dart 走 `HyperosSubpage` 的默认返回语义）。 */
    val closeAction = ArbText("closeAction", "关闭")

    // ── 日志查看器：来源与等级 ──
    val appLogsSourceApp = ArbText("appLogsSourceApp", "应用")
    val appLogsSourceNative = ArbText("appLogsSourceNative", "超级岛")
    val diagnosticsLevelLabel = ArbText("diagnosticsLevelLabel", "等级")
    val diagnosticsLevelAll = ArbText("diagnosticsLevelAll", "全部")
    val diagnosticsLevelError = ArbText("diagnosticsLevelError", "错误")
    val diagnosticsLevelWarn = ArbText("diagnosticsLevelWarn", "警告")
    val diagnosticsLevelInfo = ArbText("diagnosticsLevelInfo", "信息")
    val diagnosticsLevelDebug = ArbText("diagnosticsLevelDebug", "调试")
    val diagnosticsLevelVerbose = ArbText("diagnosticsLevelVerbose", "详细")
    val diagnosticsLevelInferred = ArbText("diagnosticsLevelInferred", "推断等级")

    // ── 日志查看器：视图与排序 ──
    val diagnosticsDisplayOptionsTitle = ArbText("diagnosticsDisplayOptionsTitle", "查看与排序")
    val diagnosticsStructuredTab = ArbText("diagnosticsStructuredTab", "结构化")
    val diagnosticsRawTab = ArbText("diagnosticsRawTab", "原文")
    val diagnosticsTimeSortAscending = ArbText("diagnosticsTimeSortAscending", "正序")
    val diagnosticsTimeSortDescending = ArbText("diagnosticsTimeSortDescending", "倒序")

    // ── 日志查看器：状态与分页 ──
    val diagnosticsEmptyTitle = ArbText("diagnosticsEmptyTitle", "暂无日志")
    val diagnosticsNoMatchingTitle = ArbText("diagnosticsNoMatchingTitle", "当前筛选下没有日志")
    val diagnosticsLoadFailedTitle = ArbText("diagnosticsLoadFailedTitle", "日志加载失败")
    val diagnosticsLogTitleFallback = ArbText("diagnosticsLogTitleFallback", "超级岛诊断日志")
    val diagnosticsLoadEarlierLabel =
        ArbText("diagnosticsLoadEarlierLabel", "加载更早日志 剩余 {count} 条")
    val diagnosticsShowingCount = ArbText("diagnosticsShowingCount", "显示 {shown} / {total} 条日志")
    val liveTestingRefreshAction = ArbText("liveTestingRefreshAction", "刷新诊断")

    // ── 日志查看器：设备与导出信息 ──
    val diagnosticsDeviceInfoTitle = ArbText("diagnosticsDeviceInfoTitle", "设备与导出信息")
    val diagnosticsExportedAt = ArbText("diagnosticsExportedAt", "导出时间")
    val diagnosticsTime = ArbText("diagnosticsTime", "时间")
    val diagnosticsCategory = ArbText("diagnosticsCategory", "类别")
    val diagnosticsMessage = ArbText("diagnosticsMessage", "消息")
    val diagnosticsStackTrace = ArbText("diagnosticsStackTrace", "堆栈")

    // ── 三份日志入口（log_viewer_entry）──
    val aboutAppLogsTitle = ArbText("aboutAppLogsTitle", "应用日志")
    val aboutNoDiagnosticsExportYet = ArbText("aboutNoDiagnosticsExportYet", "还没有可导出的应用日志")
    val appLogsShareText = ArbText(
        "appLogsShareText",
        "这是轻屿课表导出的应用日志，包含整个软件的本地运行记录，可用于排查更新、导入、通知、页面和崩溃问题",
    )
    val appLogsShareSubject = ArbText("appLogsShareSubject", "轻屿课表 - 应用日志")
    val liveDiagnosticsViewerTitle = ArbText("liveDiagnosticsViewerTitle", "超级岛日志")
    val liveDiagnosticsUnavailable = ArbText("liveDiagnosticsUnavailable", "当前还没有可查看的超级岛日志")
    val liveDiagnosticsNothingToExport =
        ArbText("liveDiagnosticsNothingToExport", "当前没有可导出的日志文件，也没有可导出的状态快照")
    val liveDiagnosticsShareText =
        ArbText("liveDiagnosticsShareText", "轻屿课表超级岛运行日志，用于排查不显示等问题")
    val liveDiagnosticsShareSubject = ArbText("liveDiagnosticsShareSubject", "轻屿课表 - 超级岛日志")
    val warehouseImportExecutionLogTitle =
        ArbText("warehouseImportExecutionLogTitle", "课表导入执行日志")
    val warehouseImportExecutionLogShareText = ArbText(
        "warehouseImportExecutionLogShareText",
        "这是轻屿课表导出的教务导入执行日志，包含脚本注入、桥接消息、超时与导入结果等过程记录，可直接反馈给开发人员排查问题",
    )
    val warehouseImportExecutionLogShareSubject =
        ArbText("warehouseImportExecutionLogShareSubject", "轻屿课表 - 课表导入执行日志")
    val warehouseImportExecutionLogEmpty =
        ArbText("warehouseImportExecutionLogEmpty", "暂无导入执行记录。请先打开教务网页并执行导入脚本，再回来查看。")

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            appLogsCopyAction,
            appLogsCopied,
            appLogsExportAction,
            appLogsClearAction,
            appLogsCleared,
            appLogsClearFailed,
            appLogsRecordingPausedHint,
            closeAction,
            appLogsSourceApp,
            appLogsSourceNative,
            diagnosticsLevelLabel,
            diagnosticsLevelAll,
            diagnosticsLevelError,
            diagnosticsLevelWarn,
            diagnosticsLevelInfo,
            diagnosticsLevelDebug,
            diagnosticsLevelVerbose,
            diagnosticsLevelInferred,
            diagnosticsDisplayOptionsTitle,
            diagnosticsStructuredTab,
            diagnosticsRawTab,
            diagnosticsTimeSortAscending,
            diagnosticsTimeSortDescending,
            diagnosticsEmptyTitle,
            diagnosticsNoMatchingTitle,
            diagnosticsLoadFailedTitle,
            diagnosticsLogTitleFallback,
            diagnosticsLoadEarlierLabel,
            diagnosticsShowingCount,
            liveTestingRefreshAction,
            diagnosticsDeviceInfoTitle,
            diagnosticsExportedAt,
            diagnosticsTime,
            diagnosticsCategory,
            diagnosticsMessage,
            diagnosticsStackTrace,
            aboutAppLogsTitle,
            aboutNoDiagnosticsExportYet,
            appLogsShareText,
            appLogsShareSubject,
            liveDiagnosticsViewerTitle,
            liveDiagnosticsUnavailable,
            liveDiagnosticsNothingToExport,
            liveDiagnosticsShareText,
            liveDiagnosticsShareSubject,
            warehouseImportExecutionLogTitle,
            warehouseImportExecutionLogShareText,
            warehouseImportExecutionLogShareSubject,
            warehouseImportExecutionLogEmpty,
        )
    }

    /** 等级名（Dart `_levelLabel`）。 */
    fun levelLabel(level: DiagnosticsLogLevel): String = when (level) {
        DiagnosticsLogLevel.ALL -> diagnosticsLevelAll.zh
        DiagnosticsLogLevel.ERROR -> diagnosticsLevelError.zh
        DiagnosticsLogLevel.WARN -> diagnosticsLevelWarn.zh
        DiagnosticsLogLevel.INFO -> diagnosticsLevelInfo.zh
        DiagnosticsLogLevel.DEBUG -> diagnosticsLevelDebug.zh
        DiagnosticsLogLevel.VERBOSE -> diagnosticsLevelVerbose.zh
    }
}
