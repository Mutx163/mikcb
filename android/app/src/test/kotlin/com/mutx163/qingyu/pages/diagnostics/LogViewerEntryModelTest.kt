package com.mutx163.qingyu.pages.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日志入口配置测试（源：`lib/screens/log_viewer_entry.dart`）。
 *
 * 期望值从 Dart 源手推：三个 `_build*Viewer` 各自传进去的 title / route / 文件名前缀 /
 * 分享文案 / 空态行为，以及「live 没有 onClear」这条注释里写明的取舍。
 */
class LogViewerEntryModelTest {

    @Test
    fun `合并日志入口用应用日志的标题与路由`() {
        val config = LogViewerEntryLogic.configFor(AppLogSource.MERGED)

        assertEquals("应用日志", config.title)
        assertEquals("/logs/app", config.routeName)
        assertEquals("mikcb-app-logs-", config.exportFileNamePrefix)
        assertEquals("log", config.exportFileExtension)
        assertEquals("轻屿课表 - 应用日志", config.shareSubject)
        assertTrue(config.shareText.startsWith("这是轻屿课表导出的应用日志"))
        assertEquals("还没有可导出的应用日志", config.emptyExportMessage)
        assertTrue(config.supportsClear)
        assertFalse(config.popsOnEmpty)
    }

    @Test
    fun `超级岛日志入口没有清空且空态自己退出`() {
        val config = LogViewerEntryLogic.configFor(AppLogSource.LIVE)

        assertEquals("超级岛日志", config.title)
        assertEquals("/logs/live", config.routeName)
        assertEquals("mikcb-live-diagnostics-", config.exportFileNamePrefix)
        assertEquals("轻屿课表 - 超级岛日志", config.shareSubject)
        // 源文件注释：`Deliberately no onClear`——一空就 pop，页面内清空会关掉脚下的页面。
        assertFalse(config.supportsClear)
        assertEquals("当前还没有可查看的超级岛日志", config.emptyLoadMessage)
        assertTrue(config.popsOnEmpty)
    }

    @Test
    fun `教务导入入口导出 txt 且空态给轻提示`() {
        val config = LogViewerEntryLogic.configFor(AppLogSource.WAREHOUSE_IMPORT)

        assertEquals("课表导入执行日志", config.title)
        assertEquals("/logs/warehouse-import", config.routeName)
        assertEquals("qingyu-warehouse-import-log-", config.exportFileNamePrefix)
        assertEquals("txt", config.exportFileExtension)
        assertEquals("轻屿课表 - 课表导入执行日志", config.shareSubject)
        // 这个入口导出时不校验空文本：会话日志为空也允许导出，只给轻提示。
        assertNull(config.emptyExportMessage)
        assertTrue(config.supportsClear)
        assertTrue(config.usesLightTipOnEmpty)
        assertFalse(config.popsOnEmpty)
    }

    @Test
    fun `三个入口的路由名互不重复`() {
        val routes = AppLogSource.entries.map { LogViewerEntryLogic.configFor(it).routeName }

        assertEquals(listOf("/logs/app", "/logs/live", "/logs/warehouse-import"), routes)
        assertEquals(routes.size, routes.distinct().size)
    }

    @Test
    fun `导出文件名是前缀加时间戳加扩展名`() {
        assertEquals(
            "mikcb-app-logs-1700000000000.log",
            LogViewerEntryLogic.exportFileName(AppLogSource.MERGED, 1_700_000_000_000L),
        )
        assertEquals(
            "mikcb-live-diagnostics-1700000000000.log",
            LogViewerEntryLogic.exportFileName(AppLogSource.LIVE, 1_700_000_000_000L),
        )
        assertEquals(
            "qingyu-warehouse-import-log-1700000000000.txt",
            LogViewerEntryLogic.exportFileName(AppLogSource.WAREHOUSE_IMPORT, 1_700_000_000_000L),
        )
    }

    @Test
    fun `双击保护在打开中时忽略第二次`() {
        assertTrue(LogViewerEntryLogic.shouldIgnoreOpen(isOpening = true))
        assertFalse(LogViewerEntryLogic.shouldIgnoreOpen(isOpening = false))
    }
}
