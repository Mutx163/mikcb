package com.mutx163.qingyu

import android.content.res.Configuration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「深浅换档才重画」这条判据的守卫：只认 [Configuration.UI_MODE_NIGHT_MASK] 那一位，
 * 其它 uiMode 位（设备类型等）变化不该触发重画。
 */
class WidgetThemeWatcherTest {

    @Test
    fun maskKeepsOnlyNightBits() {
        assertEquals(
            Configuration.UI_MODE_NIGHT_NO,
            nightModeMask(Configuration.UI_MODE_NIGHT_NO),
        )
        assertEquals(
            Configuration.UI_MODE_NIGHT_YES,
            nightModeMask(
                Configuration.UI_MODE_TYPE_TELEVISION or Configuration.UI_MODE_NIGHT_YES,
            ),
        )
    }

    @Test
    fun sameNightModeDoesNotRerender() {
        assertFalse(
            nightModeChanged(
                Configuration.UI_MODE_NIGHT_NO,
                Configuration.UI_MODE_NIGHT_NO,
            ),
        )
        assertFalse(
            nightModeChanged(
                Configuration.UI_MODE_NIGHT_YES,
                Configuration.UI_MODE_NIGHT_YES,
            ),
        )
    }

    @Test
    fun otherUiModeBitsDoNotRerender() {
        // 同一深浅档、只有设备类型不同（UI_MODE_TYPE_*）：不是换档，不重画。
        val before = Configuration.UI_MODE_TYPE_NORMAL or Configuration.UI_MODE_NIGHT_NO
        val after = Configuration.UI_MODE_TYPE_TELEVISION or Configuration.UI_MODE_NIGHT_NO
        assertFalse(nightModeChanged(nightModeMask(before), nightModeMask(after)))
    }

    @Test
    fun switchingNightModeRerenders() {
        assertTrue(
            nightModeChanged(
                Configuration.UI_MODE_NIGHT_YES,
                Configuration.UI_MODE_NIGHT_NO,
            ),
        )
        assertTrue(
            nightModeChanged(
                Configuration.UI_MODE_NIGHT_NO,
                Configuration.UI_MODE_NIGHT_YES,
            ),
        )
    }

    @Test
    fun undefinedCountsAsChange() {
        // 进程刚起来时可能是 UNDEFINED，随后拿到明确的档：卡片可能按未定档画过，要重画一次。
        assertTrue(
            nightModeChanged(
                Configuration.UI_MODE_NIGHT_UNDEFINED,
                Configuration.UI_MODE_NIGHT_YES,
            ),
        )
        assertTrue(
            nightModeChanged(
                Configuration.UI_MODE_NIGHT_UNDEFINED,
                Configuration.UI_MODE_NIGHT_NO,
            ),
        )
    }
}
