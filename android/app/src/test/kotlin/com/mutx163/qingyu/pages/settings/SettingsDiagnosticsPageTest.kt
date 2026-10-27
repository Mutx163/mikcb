package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 诊断页（`lib/screens/settings/settings_diagnostics.dart`）结构测试。
 *
 * 期望值来源：Dart 源（单组四行的条件渲染）+ ARB（文案）。
 *
 * 这页最短，但有一条容易做错的：**后两行只在「诊断构建」变体里出现**
 * （`MemoryStatsService.isDiagnosticsBuild()`，:32-34 / :48），
 * 而且它是异步取的，所以还有一个「还没取到」的第三态。
 */
class SettingsDiagnosticsPageTest {

    private fun page(data: DiagnosticsPageData = DiagnosticsPageData()) =
        SettingsDiagnosticsPage.spec(SettingsPageState(), data)

    @Test
    fun `页面标题取自 diagnosticsEntryTitle`() {
        // settings_diagnostics.dart:44
        val spec = page()
        assertEquals("settings-diagnostics", spec.id)
        assertEquals("diagnosticsEntryTitle", spec.titleKey)
        assertEquals("诊断", spec.title)
    }

    @Test
    fun `整页只有一组 没有区块小标题也没有空档`() {
        // settings_diagnostics.dart:54-90：一个 HyperosListGroup 直接挂在 HyperosListView 下
        assertEquals(listOf("diagnostics.group.main"), page().topLevelIds())
        assertTrue(page().flatten().none { it is SettingsLabel })
        assertTrue(page().flatten().none { it is SettingsGap })
        assertTrue(page().flatten().none { it is SettingsDescription })
    }

    @Test
    fun `普通构建只有前两行`() {
        // settings_diagnostics.dart:67 / :83 两个 `if (showMemoryStats)`
        assertEquals(
            listOf("diagnostics.appLogs", "diagnostics.recordDiagnostics"),
            page(DiagnosticsPageData(showMemoryStats = false)).group("diagnostics.group.main").childRowIds(),
        )
    }

    @Test
    fun `诊断构建多出内存状态与设置快照两行`() {
        // settings_diagnostics.dart:67-88
        assertEquals(
            listOf(
                "diagnostics.appLogs",
                "diagnostics.recordDiagnostics",
                "diagnostics.memoryStats",
                "diagnostics.performanceSnapshot",
            ),
            page(DiagnosticsPageData(showMemoryStats = true)).group("diagnostics.group.main").childRowIds(),
        )
    }

    @Test
    fun `异步标志未取到时按普通构建渲染`() {
        // settings_diagnostics.dart:48 `snapshot.data == true`——拿不到就是 false
        assertEquals(
            listOf("diagnostics.appLogs", "diagnostics.recordDiagnostics"),
            page(DiagnosticsPageData(showMemoryStats = null)).group("diagnostics.group.main").childRowIds(),
        )
    }

    @Test
    fun `应用日志行的文案`() {
        // settings_diagnostics.dart:56-60
        val row = page().row("diagnostics.appLogs")
        assertEquals("aboutAppLogsTitle", row.titleKey)
        assertEquals("应用日志", row.title)
        // 注意：这里是 details（行尾静态文案），不是 subtitle
        assertEquals("aboutAppLogsSubtitle", row.detailsKey)
        assertEquals("查看运行日志", row.details)
        assertNull(row.subtitle)
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals(SettingsDiagnosticsPage.ROUTE_APP_LOGS, row.actionTarget)
    }

    @Test
    fun `记录应用日志开关的文案与默认值`() {
        // settings_diagnostics.dart:61-66；默认 false 见 timetable_settings.dart:851
        val row = page().row("diagnostics.recordDiagnostics")
        assertEquals("aboutRecordDiagnosticsTitle", row.titleKey)
        assertEquals("记录应用日志", row.title)
        assertEquals("aboutRecordDiagnosticsSubtitle", row.subtitleKey)
        assertEquals("持续记录运行日志，存本机", row.subtitle)
        assertEquals(MiuixRowComponent.SWITCH, row.component)
        assertEquals(false, row.switchValue)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
    }

    @Test
    fun `记录开关随状态走`() {
        val spec = SettingsDiagnosticsPage.spec(
            SettingsPageState(),
            DiagnosticsPageData(recordingEnabled = true),
        )
        assertEquals(true, spec.row("diagnostics.recordDiagnostics").switchValue)
    }

    @Test
    fun `内存状态行只有标题`() {
        // settings_diagnostics.dart:68-79
        val row = page(DiagnosticsPageData(showMemoryStats = true)).row("diagnostics.memoryStats")
        assertEquals("memoryStatsEntryTitle", row.titleKey)
        assertEquals("内存状态", row.title)
        assertNull(row.subtitle)
        assertNull(row.details)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals(SettingsDiagnosticsPage.ROUTE_MEMORY_STATS, row.actionTarget)
    }

    @Test
    fun `设置快照行的文案与动作`() {
        // settings_diagnostics.dart:83-88 + :100-115（打一条快照，不换页）
        val row = page(DiagnosticsPageData(showMemoryStats = true)).row("diagnostics.performanceSnapshot")
        assertEquals("performanceSnapshotEntryTitle", row.titleKey)
        assertEquals("设置快照", row.title)
        assertEquals("performanceSnapshotEntrySubtitle", row.subtitleKey)
        assertEquals("把当前设置写进应用日志", row.subtitle)
        assertEquals(SettingsAction.RUN_NOW, row.action)
        assertNull(row.actionTarget)
    }

    @Test
    fun `写入成功的 toast 文案不是行`() {
        // settings_diagnostics.dart:110-114 `showAppToast(performanceSnapshotEntryDone)`
        assertEquals("已写入应用日志", SettingsStringsExt3.performanceSnapshotEntryDone.zh)
        assertFalse(page().flattenedIds().any { it.contains("done") })
    }

    @Test
    fun `开关写盘被拒与失败的提示文案都存在`() {
        // settings_diagnostics.dart:131-139：reportSettingsPersistRejected / reportSettingsPersistFailure
        // 两句文案都在别的文件（settings_shared.dart:54 / :78），这里只钉它们进了本页文案表
        assertEquals("保存失败", SettingsStringsExt3.saveFailed.zh)
        assertEquals(
            "已开启应用日志记录",
            SettingsStringsExt3.aboutLiveDiagnosticsEnabled.zh,
        )
        assertEquals(
            "已关闭应用日志记录",
            SettingsStringsExt3.aboutLiveDiagnosticsDisabled.zh,
        )
    }

    @Test
    fun `两个路由名与 Dart 一致`() {
        // settings_diagnostics.dart:73（/settings/memory-stats）；应用日志走 openLogViewer
        assertEquals("/settings/memory-stats", SettingsDiagnosticsPage.ROUTE_MEMORY_STATS)
        assertEquals("app-logs", SettingsDiagnosticsPage.ROUTE_APP_LOGS)
    }
}
