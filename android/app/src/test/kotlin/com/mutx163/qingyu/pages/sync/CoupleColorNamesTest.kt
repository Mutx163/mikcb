package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CoupleColorNamesTest {

    @Test
    fun `快速选色板每个色值都有两字中文名`() {
        CoupleTimetableSettingsLogic.QUICK_PICK_HEXES.forEach { hex ->
            val name = CoupleColorNames.nameFor(hex)
            assertEquals("$hex 应有两字名，实际 $name", 2, name.length)
            assertEquals("$hex 不应退回 hex", false, name.startsWith("#"))
        }
    }

    @Test
    fun `两个默认色也有名字`() {
        assertEquals(2, CoupleColorNames.nameFor(CoupleTimetableSettingsLogic.MINE_COLOR_DEFAULT).length)
        assertEquals(2, CoupleColorNames.nameFor(CoupleTimetableSettingsLogic.PARTNER_COLOR_DEFAULT).length)
        assertEquals(2, CoupleColorNames.nameFor(CoupleTimetableSettingsLogic.TOGETHER_COLOR_DEFAULT).length)
    }

    @Test
    fun `大小写与未知色值`() {
        val lower = "#ef4444"
        assertEquals(CoupleColorNames.nameFor("#EF4444"), CoupleColorNames.nameFor(lower))
        assertTrue(CoupleColorNames.nameFor("#123456").startsWith("#"))
    }
}
