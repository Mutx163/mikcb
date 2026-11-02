package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外部入口纯判定的单测（判据出处见 [ShellExternalEntry] 文件头）。
 *
 * 覆盖：深链路径规范化（`MainActivity.handleDebugDeepLinkIntent` 同口径的四分支）、
 * 包名门控、导入 intent 判定（mikcb-debug 不当导入）、kind 识别（`detectImportKind`
 * 逐字搬移后的等价性）、payload 校验与壳页面落点。
 */
class ShellExternalEntryTest {

    // ── normalizeDebugDeepLinkPath ──────────────────────────────────────────

    @Test
    fun debugPath_emptyHostAndPath_fallsBackToHome() {
        assertEquals("home", ShellExternalEntry.normalizeDebugDeepLinkPath(null, null))
        assertEquals("home", ShellExternalEntry.normalizeDebugDeepLinkPath("", ""))
    }

    @Test
    fun debugPath_pathAbsoluteForm_prefersPathSegment() {
        assertEquals(
            "settings/live",
            ShellExternalEntry.normalizeDebugDeepLinkPath(null, "/settings/live"),
        )
    }

    @Test
    fun debugPath_hostForm_usesHost() {
        assertEquals(
            "settings/live",
            ShellExternalEntry.normalizeDebugDeepLinkPath("settings/live", null),
        )
    }

    @Test
    fun debugPath_bothPresent_joinsWithSlash() {
        assertEquals(
            "settings/live",
            ShellExternalEntry.normalizeDebugDeepLinkPath("settings", "/live"),
        )
    }

    // ── debugRoutePageId ─────────────────────────────────────────────────────

    @Test
    fun debugRoute_knownPath_mapsViaInjectedTable() {
        // 与 ShellWiring.shellPageIdForRoute 的真实映射抽查两条同值。
        assertEquals("b.live", ShellExternalEntry.debugRoutePageId("/settings/live") { route ->
            mapOf("/settings/live" to "b.live")[route]
        })
    }

    @Test
    fun debugRoute_unknownPath_returnsNullForHome() {
        assertNull(ShellExternalEntry.debugRoutePageId("/no/such/route") { null })
    }

    // ── isDebugAutomationPackageId ───────────────────────────────────────────

    @Test
    fun debugPackage_gateMatchesSuffixOnly() {
        assertTrue(ShellExternalEntry.isDebugAutomationPackageId("com.mutx163.qingyu.debug"))
        assertTrue(ShellExternalEntry.isDebugAutomationPackageId("com.mutx163.qingyu.profile"))
        assertFalse(ShellExternalEntry.isDebugAutomationPackageId("com.mutx163.qingyu"))
        assertFalse(ShellExternalEntry.isDebugAutomationPackageId("com.mutx163.qingyu.ui"))
        // 「.debug」必须是后缀，不能是中间段。
        assertFalse(ShellExternalEntry.isDebugAutomationPackageId("com.debug.qingyu"))
    }

    // ── isExternalImportAction ───────────────────────────────────────────────

    @Test
    fun importAction_viewAndSendAccepted() {
        assertTrue(ShellExternalEntry.isExternalImportAction("android.intent.action.VIEW", "content"))
        assertTrue(ShellExternalEntry.isExternalImportAction("android.intent.action.SEND", null))
    }

    @Test
    fun importAction_debugSchemeNeverTreatedAsImport() {
        assertFalse(
            ShellExternalEntry.isExternalImportAction(
                "android.intent.action.VIEW",
                ShellExternalEntry.DEBUG_SCHEME,
            ),
        )
    }

    @Test
    fun importAction_otherActionsRejected() {
        assertFalse(ShellExternalEntry.isExternalImportAction("android.intent.action.MAIN", "content"))
        assertFalse(ShellExternalEntry.isExternalImportAction(null, "content"))
    }

    // ── detectImportKind（逐字搬移后的等价性抽查）────────────────────────────

    @Test
    fun detectKind_extensionWins() {
        assertEquals(
            "ics",
            ShellExternalEntry.detectImportKind("a.ics", "application/octet-stream", ByteArray(0)),
        )
        assertEquals(
            "backup",
            ShellExternalEntry.detectImportKind("a.mikcb", null, ByteArray(0)),
        )
        assertEquals(
            "backup",
            ShellExternalEntry.detectImportKind("a.json", null, ByteArray(0)),
        )
        assertEquals(
            "spreadsheet",
            ShellExternalEntry.detectImportKind("a.csv", "text/plain", ByteArray(0)),
        )
        assertEquals(
            "spreadsheet",
            ShellExternalEntry.detectImportKind("a.xlsx", "application/octet-stream", ByteArray(0)),
        )
    }

    @Test
    fun detectKind_mimeFallback() {
        assertEquals(
            "ics",
            ShellExternalEntry.detectImportKind("noext", "text/calendar", ByteArray(0)),
        )
        assertEquals(
            "backup",
            ShellExternalEntry.detectImportKind("noext", "application/json", ByteArray(0)),
        )
        assertEquals(
            "spreadsheet",
            ShellExternalEntry.detectImportKind(
                "noext",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                ByteArray(0),
            ),
        )
    }

    @Test
    fun detectKind_octetStreamFallsBackToExtension() {
        assertEquals(
            "ics",
            ShellExternalEntry.detectImportKind("a.ics", "application/octet-stream", ByteArray(0)),
        )
        assertEquals(
            "backup",
            ShellExternalEntry.detectImportKind("a.json", "*/*", ByteArray(0)),
        )
        // octet-stream + 无扩展名：不猜。
        assertNull(
            ShellExternalEntry.detectImportKind("a", "application/octet-stream", ByteArray(0)),
        )
    }

    @Test
    fun detectKind_contentSniffing() {
        assertEquals(
            "ics",
            ShellExternalEntry.detectImportKind("a", null, "BEGIN:VCALENDAR".toByteArray()),
        )
        assertEquals(
            "backup",
            ShellExternalEntry.detectImportKind("a", null, """{"app":"mikcb"}""".toByteArray()),
        )
        // PK 魔数 + xlsx 扩展名 → spreadsheet。
        val zip = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
        assertEquals("spreadsheet", ShellExternalEntry.detectImportKind("a.xlsx", null, zip))
        // PK 魔数但扩展名不是 xlsx/空 → 不猜。
        assertNull(ShellExternalEntry.detectImportKind("a.zip", null, zip))
    }

    @Test
    fun detectKind_unknownReturnsNull() {
        assertNull(ShellExternalEntry.detectImportKind("a.txt", "text/plain", "hello".toByteArray()))
    }

    // ── buildImportPayload / importTargetPage ────────────────────────────────

    @Test
    fun payload_icsRequiresVCalendar() {
        val ok = ShellExternalEntry.buildImportPayload(
            "ics", "a.ics", "BEGIN:VCALENDAR\nEND:VCALENDAR".toByteArray(),
        )
        assertTrue(ok is ShellExternalEntry.ImportPayload.Ics)
        assertNull(ShellExternalEntry.buildImportPayload("ics", "a.ics", "not a calendar".toByteArray()))
    }

    @Test
    fun payload_backupRequiresMikcbMarker() {
        val ok = ShellExternalEntry.buildImportPayload("backup", "a.json", """{"mikcb":1}""".toByteArray())
        assertTrue(ok is ShellExternalEntry.ImportPayload.Backup)
        assertNull(ShellExternalEntry.buildImportPayload("backup", "a.json", """{"other":1}""".toByteArray()))
    }

    @Test
    fun payload_spreadsheetKeepsRawBytes() {
        val bytes = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
        val payload = ShellExternalEntry.buildImportPayload("spreadsheet", "a.xlsx", bytes)
        assertTrue(payload is ShellExternalEntry.ImportPayload.Spreadsheet)
        assertEquals(bytes, (payload as ShellExternalEntry.ImportPayload.Spreadsheet).bytes)
    }

    @Test
    fun targetPage_eachPayloadLandsOnItsShellPage() {
        assertEquals(
            "g1.icsImport",
            ShellExternalEntry.importTargetPage(ShellExternalEntry.ImportPayload.Ics("a.ics", "BEGIN:VCALENDAR")),
        )
        assertEquals(
            "g1.spreadsheetImport",
            ShellExternalEntry.importTargetPage(ShellExternalEntry.ImportPayload.Spreadsheet("a.xlsx", ByteArray(0))),
        )
        assertEquals(
            "g3.dataTransfer",
            ShellExternalEntry.importTargetPage(ShellExternalEntry.ImportPayload.Backup("a.mikcb", "{}")),
        )
        assertEquals(
            "g1.importEntry",
            ShellExternalEntry.importTargetPage(ShellExternalEntry.ImportPayload.TooLarge("a.csv", 100)),
        )
    }

    // ── declaredSizeExceedsCap ───────────────────────────────────────────────

    @Test
    fun declaredSize_capBoundary() {
        assertFalse(ShellExternalEntry.declaredSizeExceedsCap(ShellExternalEntry.MAX_IMPORT_BYTES))
        assertTrue(ShellExternalEntry.declaredSizeExceedsCap(ShellExternalEntry.MAX_IMPORT_BYTES + 1))
        // 缺失（-1）不算超限。
        assertFalse(ShellExternalEntry.declaredSizeExceedsCap(-1L))
    }
}
