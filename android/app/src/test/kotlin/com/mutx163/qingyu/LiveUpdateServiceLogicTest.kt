package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveUpdateServiceLogicTest {
    @Test
    fun beforeClassQuickActionRestoresAfterClassEndWhenDue() {
        assertTrue(
            beforeClassQuickActionShouldRestoreAfterClassEnd(
                nowMillis = 1_700_000_000_000L,
                restoreAtMillis = 1_699_999_000_000L,
            )
        )
    }

    @Test
    fun beforeClassQuickActionDoesNotRestoreBeforeClassEnd() {
        assertFalse(
            beforeClassQuickActionShouldRestoreAfterClassEnd(
                nowMillis = 1_699_999_000_000L,
                restoreAtMillis = 1_700_000_000_000L,
            )
        )
    }

    @Test
    fun promotedApi36PlusDoesNotMirrorStatusIntoMiuiFocusHint() {
        assertFalse(
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = 36,
                shouldPromote = true,
            )
        )
    }

    @Test
    fun nonPromotedOrOlderBuildsKeepMiuiFocusHint() {
        assertTrue(
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = 35,
                shouldPromote = true,
            )
        )
        assertTrue(
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = 36,
                shouldPromote = false,
            )
        )
    }
}
