package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.app.TimetableSettingsModel

/**
 * 设置→诊断页「记录应用日志」开关的**写回逻辑**（纯 Kotlin，JVM 可测）。
 *
 * 源：`lib/screens/settings/settings_diagnostics.dart:121-147`
 * （`_updateRecordingPreference`）。
 *
 * ## 为什么单独一层
 *
 * 那段 Dart 代码有两种失败，提示与界面处置都不一样，而 Compose 宿主要弹 toast、
 * 要「把开关拨回真源」——两条分支若直接写在 `@Composable` 里，就只能在真机上试，
 * 单测一点也覆盖不到。搬成纯函数后：
 *
 * - [Save] 回调模拟 Dart 的 `provider.updateTimetableSettings(...)`：
 *   **返回非空字符串** = 被规则拒绝（Dart 返回编码过的消息码）；
 *   **抛异常** = 落盘失败（Dart provider 回滚内存与课表镜像后 rethrow）；
 * - 三种结果分别对应宿主的三条提示路径。
 *
 * ## 「拨回真源」在这里怎么表达
 *
 * 结果里**不带新模型**：宿主在 [RecordingToggleOutcome.Saved] 时用 `copy` 更新，
 * 其余两种情况一律 `store.load()` 重读——盘上是什么就显示什么，这才是真源。
 * 逻辑层不猜「回滚到哪个值」，避免和 store 的合并写语义各说一套。
 */
object DiagnosticsRecordingLogic {

    /** 行 id（`SettingsDiagnosticsPage.spec` 里 `settingsRow(id = ...)`，与渲染层同一份常量）。 */
    const val ROW_APP_LOGS = "diagnostics.appLogs"
    const val ROW_RECORD_DIAGNOSTICS = "diagnostics.recordDiagnostics"
    const val ROW_MEMORY_STATS = "diagnostics.memoryStats"
    const val ROW_PERFORMANCE_SNAPSHOT = "diagnostics.performanceSnapshot"

    /**
     * 把「记录应用日志」写成 [value]。
     *
     * @param current 当前界面显示的那份模型（Dart `provider.settings`）
     * @param value 开关被拨到的新值
     * @param save 合并写；返回非空 = 规则拒绝的消息码，抛异常 = 落盘失败
     */
    fun toggle(
        current: TimetableSettingsModel,
        value: Boolean,
        save: (TimetableSettingsModel) -> String?,
    ): RecordingToggleOutcome {
        val next = current.copy(liveEnableLocalDiagnostics = value)
        val rejected = try {
            save(next)
        } catch (t: Throwable) {
            // 落盘失败：Dart 也是 catch 住异常后提示，不往上抛（弹 toast 就完了）。
            return RecordingToggleOutcome.PersistFailed
        }
        if (!rejected.isNullOrBlank()) {
            return RecordingToggleOutcome.PersistRejected(rejected)
        }
        return RecordingToggleOutcome.Saved(value)
    }
}

/** 开关写回的三种结局（Dart `_updateRecordingPreference` 的三条出口）。 */
sealed interface RecordingToggleOutcome {

    /** 已落盘：显示新值 + 成功提示（Dart :140-146 两条文案按值分）。 */
    data class Saved(val enabled: Boolean) : RecordingToggleOutcome

    /**
     * 被底层规则拒绝（Dart `message != null` 分支 :131-134）：
     * 显示真源 + 提示（Dart 把消息码本地化后弹）。
     *
     * ⚠️ 今天的 Kotlin 合并写对显示设置键不做规则校验，所以宿主把这一支落在
     * 统一的 `saveFailed` 上；[message] 保留下来，等真规则上线再接本地化。
     */
    data class PersistRejected(val message: String) : RecordingToggleOutcome

    /** 落盘异常（Dart :135-139）：显示真源 + `saveFailed`。 */
    data object PersistFailed : RecordingToggleOutcome
}
