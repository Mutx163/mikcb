package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FairMemoryAdapterLogicTest {
    @Test
    fun classifiesKillActions() {
        assertEquals(
            FairMemoryActionKind.KILL,
            classifyFairMemoryAction(
                intentAction = FairMemoryAdapter.ITGSA_ACTION_KILL,
                actionRaw = null,
                notifyType = 1000,
            ),
        )
        assertEquals(
            FairMemoryActionKind.KILL,
            classifyFairMemoryAction(
                intentAction = null,
                actionRaw = "kill",
                notifyType = 1000,
            ),
        )
        assertEquals(
            FairMemoryActionKind.KILL,
            classifyFairMemoryAction(
                intentAction = null,
                actionRaw = "exception_kill",
                notifyType = 0,
            ),
        )
    }

    @Test
    fun classifiesTrimActions() {
        assertEquals(
            FairMemoryActionKind.TRIM,
            classifyFairMemoryAction(
                intentAction = FairMemoryAdapter.ITGSA_ACTION_TRIM,
                actionRaw = null,
                notifyType = 1000,
            ),
        )
        assertEquals(
            FairMemoryActionKind.TRIM,
            classifyFairMemoryAction(
                intentAction = null,
                actionRaw = "TRIM_MEMORY",
                notifyType = 2000,
            ),
        )
        assertEquals(
            FairMemoryActionKind.TRIM,
            classifyFairMemoryAction(
                intentAction = null,
                actionRaw = "warning",
                notifyType = 0,
            ),
        )
    }

    @Test
    fun emptyActionDefaultsToTrimToAvoidDestructiveKillPath() {
        assertEquals(
            FairMemoryActionKind.TRIM,
            classifyFairMemoryAction(null, null, 1000),
        )
        assertEquals(
            FairMemoryActionKind.TRIM,
            classifyFairMemoryAction(null, "", 2000),
        )
        assertEquals(
            FairMemoryActionKind.TRIM,
            classifyFairMemoryAction(null, "   ", 0),
        )
    }

    @Test
    fun intentKillWinsOverAmbiguousCommonField() {
        assertEquals(
            FairMemoryActionKind.KILL,
            classifyFairMemoryAction(
                intentAction = FairMemoryAdapter.ITGSA_ACTION_KILL,
                actionRaw = "trim",
                notifyType = 1000,
            ),
        )
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

    @Test
    fun onlyCompletedOrEngineUnavailableCanReturnSuccess() {
        assertTrue(
            isFairMemoryHandlingSuccessful(
                nativeHandlingSucceeded = true,
                flutterOutcome = FlutterHandlingOutcome.COMPLETED,
            ),
        )
        assertTrue(
            isFairMemoryHandlingSuccessful(
                nativeHandlingSucceeded = true,
                flutterOutcome = FlutterHandlingOutcome.ENGINE_UNAVAILABLE,
            ),
        )
        assertFalse(
            isFairMemoryHandlingSuccessful(
                nativeHandlingSucceeded = true,
                flutterOutcome = FlutterHandlingOutcome.FAILED,
            ),
        )
        assertFalse(
            isFairMemoryHandlingSuccessful(
                nativeHandlingSucceeded = true,
                flutterOutcome = FlutterHandlingOutcome.TIMED_OUT,
            ),
        )
        assertFalse(
            isFairMemoryHandlingSuccessful(
                nativeHandlingSucceeded = false,
                flutterOutcome = FlutterHandlingOutcome.ENGINE_UNAVAILABLE,
            ),
        )
    }
}
