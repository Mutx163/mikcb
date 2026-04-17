package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveUpdateServiceLogicTest {
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
