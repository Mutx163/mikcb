package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 弹层底部留白判据的单测（2026-11-03）。
 *
 * 覆盖四种组合：键盘弹出 / 收起 × 手势导航 / 三键导航。
 * 核心期望：**键盘弹出时不叠导航栏高度**（否则真机上会多出一截空白），
 * 键盘收起时仍按「导航栏 + 16」让位（否则最后一排会被小白条压住）。
 */
class SheetContentBottomGapTest {

    @Test
    fun `键盘弹出 + 手势导航：只留 16dp 呼吸`() {
        assertEquals(
            16f,
            SheetContentBottomGap.bottomGapDp(imeVisible = true, navigationBarBottomDp = 24f),
            0.001f,
        )
    }

    @Test
    fun `键盘收起 + 手势导航：手势区 24 + 16`() {
        assertEquals(
            40f,
            SheetContentBottomGap.bottomGapDp(imeVisible = false, navigationBarBottomDp = 24f),
            0.001f,
        )
    }

    @Test
    fun `键盘弹出 + 三键导航：只留 16dp 呼吸`() {
        assertEquals(
            16f,
            SheetContentBottomGap.bottomGapDp(imeVisible = true, navigationBarBottomDp = 48f),
            0.001f,
        )
    }

    @Test
    fun `键盘收起 + 三键导航：导航栏 48 + 16`() {
        assertEquals(
            64f,
            SheetContentBottomGap.bottomGapDp(imeVisible = false, navigationBarBottomDp = 48f),
            0.001f,
        )
    }

    @Test
    fun `IME 像素值换算：大于 0 视为弹出`() {
        assertFalse(SheetContentBottomGap.isImeVisible(0))
        assertTrue(SheetContentBottomGap.isImeVisible(1))
        assertTrue(SheetContentBottomGap.isImeVisible(900))
    }

    @Test
    fun `呼吸值与套件口径一致`() {
        assertEquals(16f, SheetContentBottomGap.CONTENT_BOTTOM_GAP_DP, 0.001f)
    }
}
