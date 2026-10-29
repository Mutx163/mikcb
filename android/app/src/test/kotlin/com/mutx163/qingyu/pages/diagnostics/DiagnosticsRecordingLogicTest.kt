package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 设置→诊断页「记录应用日志」写回逻辑测试（源：`lib/screens/settings/settings_diagnostics.dart:121-147`）。
 *
 * 三条出口对应 Dart 的三段：
 * - 写成功 → toast「已开启/已关闭应用日志记录」（:140-146）；
 * - 规则拒绝（`message != null`）→ 显示真源 + 提示（:131-134）；
 * - 落盘异常 → 显示真源 + `saveFailed`（:135-139）。
 *
 * 这里钉的是「逻辑层不猜回滚值、也不吞异常」这件事；界面侧的「拨回真源」由宿主
 * （`app/DiagnosticsSettingsHost.kt`）执行 `store.load()`，不在本层。
 */
class DiagnosticsRecordingLogicTest {

    @Test
    fun successfulSaveReturnsSavedWithTheNewValue() {
        var written: TimetableSettingsModel? = null
        val current = TimetableSettingsModel(appThemeMode = com.mutx163.qingyu.app.AppThemeMode.DARK)

        val outcome = DiagnosticsRecordingLogic.toggle(current, true) { next ->
            written = next
            null
        }

        assertEquals(RecordingToggleOutcome.Saved(true), outcome)
        // 写进去的必须是「当前模型 + 这一个字段」，别的字段不能被这条开关顺手改掉。
        assertEquals(true, written?.liveEnableLocalDiagnostics)
        assertEquals(current.copy(liveEnableLocalDiagnostics = true), written)
        assertEquals(
            com.mutx163.qingyu.app.AppThemeMode.DARK,
            written?.appThemeMode,
        )
    }

    @Test
    fun turningOffSavesFalse() {
        var written: TimetableSettingsModel? = null
        val current = TimetableSettingsModel(liveEnableLocalDiagnostics = true)

        val outcome = DiagnosticsRecordingLogic.toggle(current, false) { next ->
            written = next
            null
        }

        assertEquals(RecordingToggleOutcome.Saved(false), outcome)
        assertEquals(false, written?.liveEnableLocalDiagnostics)
    }

    @Test
    fun rejectedSaveSurfacesTheMessageInsteadOfPretendingSuccess() {
        val outcome = DiagnosticsRecordingLogic.toggle(TimetableSettingsModel(), true) {
            "section_count_below_usage|requiredMaxSection=12"
        }

        assertTrue(outcome is RecordingToggleOutcome.PersistRejected)
        assertEquals(
            "section_count_below_usage|requiredMaxSection=12",
            (outcome as RecordingToggleOutcome.PersistRejected).message,
        )
    }

    @Test
    fun throwingSaveBecomesPersistFailedAndNeverPropagates() {
        // Dart 里 provider 回滚后 rethrow，页面 catch 住只弹提示；本层同样不许往上抛。
        val outcome = DiagnosticsRecordingLogic.toggle(TimetableSettingsModel(), true) {
            throw java.io.IOException("disk full")
        }

        assertEquals(RecordingToggleOutcome.PersistFailed, outcome)
    }

    @Test
    fun blankRejectionIsTreatedAsSuccess() {
        // 空串/空白不是「被拒绝」的消息码（Dart 判的是 `message != null`，服务层从不返回空串）。
        val outcome = DiagnosticsRecordingLogic.toggle(TimetableSettingsModel(), true) { "" }

        assertEquals(RecordingToggleOutcome.Saved(true), outcome)
    }

    @Test
    fun rowIdsMatchTheSettingsModelLiterals() {
        // 宿主的 when 分派就靠这四个串；与 `SettingsDiagnosticsPage.spec` 里的
        // `settingsRow(id = ...)` 必须一致（漂了就是点了没反应）。
        assertEquals("diagnostics.appLogs", DiagnosticsRecordingLogic.ROW_APP_LOGS)
        assertEquals("diagnostics.recordDiagnostics", DiagnosticsRecordingLogic.ROW_RECORD_DIAGNOSTICS)
        assertEquals("diagnostics.memoryStats", DiagnosticsRecordingLogic.ROW_MEMORY_STATS)
        assertEquals(
            "diagnostics.performanceSnapshot",
            DiagnosticsRecordingLogic.ROW_PERFORMANCE_SNAPSHOT,
        )
    }
}
