package com.mutx163.qingyu.app

import android.util.Log
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.MemoryStatsCollector
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsRecordingLogic
import com.mutx163.qingyu.pages.diagnostics.PerformanceSnapshot
import com.mutx163.qingyu.pages.diagnostics.RecordingToggleOutcome
import com.mutx163.qingyu.pages.settings.DiagnosticsPageData
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsDiagnosticsPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsStringsExt3
import com.mutx163.qingyu.platform.PrefsKeyValueStore

/**
 * 设置→诊断页的**真实宿主**（取代壳里 `SettingsScreen(SettingsDiagnosticsPage.spec(SettingsPageState()), onBack)`
 * 那份空 state：四行里有两行永远不出现、开关拨了没反应、点应用日志没动作）。
 *
 * 源：`lib/screens/settings/settings_diagnostics.dart`（148 行）。四行逐条：
 *
 * | Dart | 本宿主 |
 * |---|---|
 * | `HyperosListTile(应用日志)` → `openLogViewer(context, AppLogSource.merged)`（:56-60 / :118-119） | `onNavigate(SettingsDiagnosticsPage.ROUTE_APP_LOGS)`（壳里映射到日志页，默认就是 merged 源） |
 * | `HyperosSwitchTile(记录应用日志)`（:61-66 / :121-147） | 读 `store.load().liveEnableLocalDiagnostics`，写回走 [DiagnosticsRecordingLogic]（合并写）；失败拨回真源 + 提示 |
 * | `if (showMemoryStats) HyperosListTile(内存状态)`（:67-79） | 可见性 = `MemoryStatsCollector.isDiagnosticsPackage(context)`（Kotlin 侧**同步**，不用像 Dart 那样等 Future ⇒ 不会先画一版「两行都不在」再跳出来） |
 * | `if (showMemoryStats) HyperosListTile(设置快照)`（:83-88 / :100-115） | [PerformanceSnapshot] 组装一条真快照 → `AppLogStore.append` + logcat + toast |
 *
 * ## 两条失败路径分开（Dart :121-147）
 *
 * Dart 里 `updateTimetableSettings` 有两种失败：**规则拒绝**（返回非空消息码）与
 * **落盘异常**（provider 回滚后 rethrow）。两者都要「提示 + 让开关回到真源」，
 * 但提示不同：前者要把消息码本地化，后者弹统一的 `saveFailed`。判定与回滚口径在
 * [DiagnosticsRecordingLogic]（纯逻辑，JVM 单测覆盖），这里只负责弹 toast。
 *
 * ⚠️ 现状差异（已登记在 `.agents/compose-phase3/claims/_DIAG-settings-fixture-gaps.md`）：
 * `liveEnableLocalDiagnostics` 是**纯显示开关**，Kotlin 的合并写（`TimetableStore.saveSettingsPatch`）
 * 对这批键不做规则校验 ⇒ 「规则拒绝」这一支今天不可达。逻辑位保留、单测钉住，
 * 真出现规则时直接接上，不必再改宿主。
 *
 * ## 设置快照为什么要自己读一次 core 设置
 *
 * 快照里 `sectionCount` 取自**节次表长度**（Dart `sectionCount => sections.length`），
 * 而节次表归 `core/TimetableSettings`，不归 [TimetableSettingsModelStore]。宿主签名
 * （`store + onBack + onNavigate`）拿不到它，所以这里按 `AboutUpdateHost` 的既有做法
 * 用同一个 `PrefsKeyValueStore` 再开一个**只读** `TimetableStore`——读的是同一份
 * `timetable_settings`（合并写，互不覆盖），不是另造一份数据。
 *
 * @param store 设置模型读写入口（壳里是 `wiring.settingsModel`）
 * @param onBack 返回
 * @param onNavigate 收 Dart 形态路由串（`app-logs` / `/settings/memory-stats`），壳里已有映射
 */
@Composable
fun DiagnosticsSettingsHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
    onNavigate: (String) -> Unit,
) {
    val context = LocalContext.current
    // 诊断包门控：Kotlin 同步判定，所以后两行「该出现就出现」。
    val isDiagnosticsBuild = remember(context) { MemoryStatsCollector.isDiagnosticsPackage(context) }
    // core 4 键的只读入口（只为 sectionCount 快照读数，见 KDoc）。
    val coreStore = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }
    var model by remember(store) { mutableStateOf(store.load()) }

    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /** 开关写回：合并写失败或被规则拒绝时，一律把界面拨回盘上的真值（Dart 的回滚等价物）。 */
    fun toggleRecording(value: Boolean) {
        val outcome = DiagnosticsRecordingLogic.toggle(model, value) { next ->
            // 返回 null = 没有规则拒绝；落盘异常以异常形式抛出（与 Dart 同形状）。
            store.save(next)
            null
        }
        when (outcome) {
            is RecordingToggleOutcome.Saved -> {
                model = model.copy(liveEnableLocalDiagnostics = outcome.enabled)
                toast(
                    if (outcome.enabled) {
                        SettingsStringsExt3.aboutLiveDiagnosticsEnabled.zh
                    } else {
                        SettingsStringsExt3.aboutLiveDiagnosticsDisabled.zh
                    },
                )
            }
            is RecordingToggleOutcome.PersistRejected -> {
                // 真源：盘上是多少就显示多少（Dart provider 已回滚 + watch 重建）。
                model = store.load()
                toast(SettingsStringsExt3.saveFailed.zh)
            }
            is RecordingToggleOutcome.PersistFailed -> {
                model = store.load()
                toast(SettingsStringsExt3.saveFailed.zh)
            }
        }
    }

    /** 「设置快照」：真打一条（Dart `_logPerformanceSnapshot` :100-115，`reason: manualExport`）。 */
    fun logPerformanceSnapshot() {
        val extras = PerformanceSnapshot.buildExtras(
            model = model,
            coreSettings = coreStore.loadSettings(),
            buildMode = diagnosticsBuildMode(context.packageName),
            reason = PerformanceSnapshot.REASON_MANUAL_EXPORT,
        )
        // 落盘那条是**被门控**的：用户没开「记录应用日志」时写不进去（Dart 同语义）。
        if (model.liveEnableLocalDiagnostics) {
            AppLogStore.append(
                level = "info",
                category = PerformanceSnapshot.CATEGORY,
                message = PerformanceSnapshot.MESSAGE,
                extras = extras,
            )
        }
        // logcat 那条不可省：刚装上的包往往一条都没开记录，且性能版 kDebugMode==false。
        Log.i(PerformanceSnapshot.TAG, MiniJson.encode(extras))
        toast(SettingsStringsExt3.performanceSnapshotEntryDone.zh)
    }

    val data = DiagnosticsPageData(
        // 同步门控：true/false 直接定格，不再有 FutureBuilder 的 null 中间态。
        showMemoryStats = isDiagnosticsBuild,
        recordingEnabled = model.liveEnableLocalDiagnostics,
    )
    val spec = SettingsDiagnosticsPage.spec(SettingsPageState(), data)

    SettingsPageScreen(
        spec = spec,
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (action) {
                // 「应用日志」「内存状态」两行都是箭头行，target 由模型层给（逻辑键 / 具名路由）。
                SettingsAction.NAVIGATE -> (target ?: rowId).let(onNavigate)
                SettingsAction.WRITE_SETTING ->
                    if (rowId == DiagnosticsRecordingLogic.ROW_RECORD_DIAGNOSTICS) {
                        toggleRecording(!model.liveEnableLocalDiagnostics)
                    }
                SettingsAction.RUN_NOW ->
                    if (rowId == DiagnosticsRecordingLogic.ROW_PERFORMANCE_SNAPSHOT) {
                        logPerformanceSnapshot()
                    }
                else -> {}
            }
        },
    )
}

/**
 * 快照里的 `buildMode`（Dart `_environmentSnapshot` :233-235 的 `kReleaseMode/kProfileMode`）。
 *
 * 迁移期 flavor 删除后，诊断包就是 `.debug` / `.profile` 两个后缀；其余一律 release。
 * 两个迁移期 flavor 之外的自定义 suffix 也不当诊断包（与 `MemoryStatsCollector` 同口径）。
 */
internal fun diagnosticsBuildMode(packageName: String): String = when {
    packageName.endsWith(".debug") -> "debug"
    packageName.endsWith(".profile") -> "profile"
    else -> "release"
}
