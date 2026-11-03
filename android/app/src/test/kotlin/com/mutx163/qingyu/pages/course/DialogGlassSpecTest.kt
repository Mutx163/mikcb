package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.DialogGlassSpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 弹窗玻璃配方的 JVM 契约测试（2026-11-03 用户批准「改库」）。
 *
 * 渲染在本地 fork 的 miuix-ui 里，数值在 [DialogGlassSpec] 里——这里钉住数值本身与两条
 * 纯逻辑（深浅判定、能否实时模糊），保证「同一台机器同一档参数」不因改调用点而漂移。
 *
 * 放 course 域随 L0 跑（试点弹窗就在 course 域）。
 */
class DialogGlassSpecTest {

    @Test
    fun `配方数值与 Nexio 弹窗档一致`() {
        assertEquals("模糊半径必须是 24dp", 24f, DialogGlassSpec.BLUR_RADIUS_DP)
        assertEquals("亮色压色 0.78", 0.78f, DialogGlassSpec.TINT_ALPHA_LIGHT)
        assertEquals("深色压色 0.87", 0.87f, DialogGlassSpec.TINT_ALPHA_DARK)
        assertEquals("通透感 1.5", 1.5f, DialogGlassSpec.SATURATION)
        assertEquals("圆角钉 32dp", 32f, DialogGlassSpec.CORNER_RADIUS_DP)
        assertEquals("降级描边 1dp", 1f, DialogGlassSpec.FALLBACK_BORDER_WIDTH_DP)
    }

    @Test
    fun `压色按底色深浅分档`() {
        assertEquals(0.78f, DialogGlassSpec.tintAlpha(isDark = false))
        assertEquals(0.87f, DialogGlassSpec.tintAlpha(isDark = true))
        // 深色压得更实：深色底上不透明一点才能保住文字对比度。
        assertTrue(DialogGlassSpec.tintAlpha(isDark = true) > DialogGlassSpec.tintAlpha(isDark = false))
    }

    @Test
    fun `深浅判定只看底色亮度`() {
        // 纯白 / 纯黑 / 中灰（0xFF808080 亮度约 0.5，按阈值 <0.5 判浅色，与官方口径一致）。
        assertFalse(DialogGlassSpec.isDarkBackground(0xFFFFFFFF.toInt()))
        assertTrue(DialogGlassSpec.isDarkBackground(0xFF000000.toInt()))
        assertFalse(DialogGlassSpec.isDarkBackground(0xFF808080.toInt()))
        // 主题可以是「浅色主题 + 深色系统」，这里不受系统深浅影响，只看底色。
        assertTrue(DialogGlassSpec.isDarkBackground(0xFF10141C.toInt()))
        assertFalse(DialogGlassSpec.isDarkBackground(0xFFF2F2F2.toInt()))
    }

    @Test
    fun `拿不到录像带或不支持 RuntimeShader 就不能糊`() {
        assertTrue(DialogGlassSpec.canBlur(hasBackdrop = true, runtimeShaderSupported = true))
        assertFalse("老设备不支持 RuntimeShader ⇒ 必须走压色+描边降级", DialogGlassSpec.canBlur(true, false))
        assertFalse("页面没提供录像带 ⇒ 必须走压色+描边降级", DialogGlassSpec.canBlur(false, true))
        assertFalse(DialogGlassSpec.canBlur(false, false))
    }

    @Test
    fun `一键回退默认开启`() {
        // 守卫也钉这一行；这里再钉一次默认值（关掉玻璃是可以的，默认必须开）。
        assertTrue(DialogGlassSpec.enabled)
    }
}
