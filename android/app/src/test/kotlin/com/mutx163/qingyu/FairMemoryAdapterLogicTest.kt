package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FairMemoryAdapterLogicTest {
    @Test
    fun classifiesKillActions() {
        assertEquals(FairMemoryActionKind.KILL, classifyFairMemoryAction("kill", 1000))
        assertEquals(FairMemoryActionKind.KILL, classifyFairMemoryAction("KILL", 2000))
        assertEquals(FairMemoryActionKind.KILL, classifyFairMemoryAction("exception_kill", 0))
    }

    @Test
    fun classifiesTrimActions() {
        assertEquals(FairMemoryActionKind.TRIM, classifyFairMemoryAction("trim", 1000))
        assertEquals(FairMemoryActionKind.TRIM, classifyFairMemoryAction("TRIM_MEMORY", 2000))
        assertEquals(FairMemoryActionKind.TRIM, classifyFairMemoryAction("warning", 0))
    }

    @Test
    fun emptyActionDefaultsToTrimToAvoidDestructiveKillPath() {
        assertEquals(FairMemoryActionKind.TRIM, classifyFairMemoryAction(null, 1000))
        assertEquals(FairMemoryActionKind.TRIM, classifyFairMemoryAction("", 2000))
        assertEquals(FairMemoryActionKind.TRIM, classifyFairMemoryAction("   ", 0))
    }

    @Test
    fun protectsLiveIslandAndHomeWidgetPrefs() {
        assertTrue(isFairMemoryProtectedPrefsName("live_update_scheduler"))
        assertTrue(isFairMemoryProtectedPrefsName("home_widget_prefs"))
        assertTrue(isFairMemoryProtectedPrefsName("FlutterSharedPreferences"))
        assertTrue(isFairMemoryProtectedPrefsName("native_runtime_prefs"))
        assertFalse(isFairMemoryProtectedPrefsName("fair_memory_runtime"))
    }

    @Test
    fun protectedSetNeverIncludesFairMemoryOwnPrefs() {
        assertFalse(
            FairMemoryAdapter.PROTECTED_SHARED_PREFS_NAMES.contains("fair_memory_runtime"),
        )
    }
}
