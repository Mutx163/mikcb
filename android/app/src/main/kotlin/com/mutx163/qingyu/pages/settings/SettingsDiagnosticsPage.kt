package com.mutx163.qingyu.pages.settings

/**
 * 诊断页（`lib/screens/settings/settings_diagnostics.dart:24-148`）结构模型。
 *
 * ## 这一页是个「入口收口处」
 *
 * 排障入口此前散在三处：应用日志在「关于」，内存监测在设置页脚。出问题的人
 * 要在多处找线索，这里收成一个口子（:14-19）。超级岛自检**有意不收**——
 * 它是超级岛的功能入口，收进诊断页曾收到用户反馈「太深、不知道功能去哪了」。
 *
 * ## 后两行是条件渲染，而且条件是异步的
 *
 * `MemoryStatsService.isDiagnosticsBuild()`（:32-34）是 `Future<bool>`，
 * 拿不到之前 `snapshot.data == true` 为 false → 按普通构建渲染。所以模型用
 * **可空**的 `showMemoryStats: Boolean?` 表达三态，null 与 false 同效。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: diagnosticsEntryTitle)`（:44） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosListView` 里唯一的 `HyperosListGroup`（:54-90） | `diagnostics.group.main` | `basic.Card` |
 * | `HyperosListTile(应用日志, details)`（:56-60） | `diagnostics.appLogs` | `MiuixArrowPreference` |
 * | `HyperosSwitchTile(记录应用日志)`（:61-66） | `diagnostics.recordDiagnostics` | `MiuixSwitchPreference` |
 * | `if (showMemoryStats) HyperosListTile(内存状态)`（:67-79） | `diagnostics.memoryStats` | `MiuixArrowPreference` |
 * | `if (showMemoryStats) HyperosListTile(设置快照)`（:83-88） | `diagnostics.performanceSnapshot` | 同上（点了打一条日志，不换页） |
 *
 * ## 不写进模型的三件事
 *
 * 1. **开关写盘的两条失败路径**（:121-146）：规则拒绝（`message != null`）与
 *    落盘异常要走不同的提示，且开关必须拨回真源；
 * 2. 成功后的 toast 文案（:140-146）由接线层弹，不在页面上；
 * 3. 应用日志走统一入口 `openLogViewer(context, AppLogSource.merged)`（:118-119）——
 *    不是普通路由，所以 [ROUTE_APP_LOGS] 是逻辑键而非路由名。
 */
object SettingsDiagnosticsPage {

    const val ID = "settings-diagnostics"

    const val ID_TITLE_KEY = "diagnosticsEntryTitle"

    /** 内存监测页的具名路由（:73-76）。 */
    const val ROUTE_MEMORY_STATS = "/settings/memory-stats"

    /** 应用日志不是路由：走 `openLogViewer`（:118-119），这里只作接线层的逻辑键。 */
    const val ROUTE_APP_LOGS = "app-logs"

    fun spec(
        state: SettingsPageState,
        data: DiagnosticsPageData = DiagnosticsPageData(),
    ): SettingsPageSpec {
        val s = SettingsStringsExt3
        val rows = mutableListOf<SettingsNode>()

        // :56-60 `HyperosListTile(title: aboutAppLogsTitle, details: aboutAppLogsSubtitle)`
        // 注意：说明在 details（行尾）槽位，不是 subtitle —— Dart 就是这么写的
        rows += settingsRow(
            id = "diagnostics.appLogs",
            component = MiuixRowComponent.ARROW,
            title = s.aboutAppLogsTitle,
            details = s.aboutAppLogsSubtitle,
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_APP_LOGS,
        )

        // :61-66 `HyperosSwitchTile`
        rows += settingsRow(
            id = "diagnostics.recordDiagnostics",
            component = MiuixRowComponent.SWITCH,
            title = s.aboutRecordDiagnosticsTitle,
            subtitle = s.aboutRecordDiagnosticsSubtitle,
            switchValue = data.recordingEnabled,
            action = SettingsAction.WRITE_SETTING,
        )

        // ：67-88 两行同受 `showMemoryStats` 门控；null（Future 未完成）按 false 处理
        if (data.showMemoryStats == true) {
            rows += settingsRow(
                id = "diagnostics.memoryStats",
                component = MiuixRowComponent.ARROW,
                title = s.memoryStatsEntryTitle,
                action = SettingsAction.NAVIGATE,
                actionTarget = ROUTE_MEMORY_STATS,
            )
            rows += settingsRow(
                id = "diagnostics.performanceSnapshot",
                component = MiuixRowComponent.ARROW,
                title = s.performanceSnapshotEntryTitle,
                subtitle = s.performanceSnapshotEntrySubtitle,
                // :100-115 打一条快照并弹 toast，不换页
                action = SettingsAction.RUN_NOW,
            )
        }

        return SettingsPageSpec(
            id = ID,
            titleKey = s.diagnosticsEntryTitle.key,
            title = s.diagnosticsEntryTitle.text,
            nodes = listOf(
                SettingsGroup(id = "diagnostics.group.main", children = rows),
            ),
        )
    }
}

/**
 * 诊断页的一份输入。
 *
 * [showMemoryStats] 三态的语义与 Dart 一致：
 * - `true` = 当前是诊断构建（与内存监测同一个包名门控）；
 * - `false` = 普通构建；
 * - `null` = `FutureBuilder` 还没拿到值（`snapshot.data == true` 为 false）。
 */
data class DiagnosticsPageData(
    val showMemoryStats: Boolean? = null,
    /** `settings.liveEnableLocalDiagnostics`，默认 false（`timetable_settings.dart:851`）。 */
    val recordingEnabled: Boolean = false,
)
