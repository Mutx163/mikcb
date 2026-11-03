package com.mutx163.qingyu.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [ButtonContrastRules] 的判据单测：用本仓真实色板值钉死阈值两侧行为。
 *
 * 阈值 1.05 的两侧必须各有一批实测色，防止将来有人「顺手」把阈值调成 1.2
 * 把 Dart 原版 secondary 弱表面也误杀，或调成 1.0 让故障复活。
 */
class ButtonContrastRulesTest {

    // ------------------------------------------------------------ 故障侧（必须判「融」）

    @Test
    fun `官方默认按钮灰落在设置页底上_必须判融进背景`() {
        // QingyuPalette.SECONDARY_VARIANT(#F0F0F0, miuix 默认按钮容器) vs 设置页底 #F2F2F2。
        val ratio = ButtonContrastRules.contrastRatio(0xFFF0F0F0.toInt(), 0xFFF2F2F2.toInt())
        assertEquals(1.018, ratio, 0.01)
        assertTrue(ButtonContrastRules.isIndistinguishable(0xFFF0F0F0.toInt(), 0xFFF2F2F2.toInt()))
    }

    @Test
    fun `官方默认按钮灰落在暗色页底之外的暗容器上_同样要能识别`() {
        // 暗色 secondaryVariant 官方默认 #434343 vs 暗色卡片 #2D2D2D：对比比 ~1.39，
        // 不在 1.05 判内（暗色系默认按钮尚可辨），此用例钉住「不误杀」。
        assertFalse(ButtonContrastRules.isIndistinguishable(0xFF434343.toInt(), 0xFF2D2D2D.toInt()))
    }

    // ------------------------------------------------------------ 合法侧（必须放过）

    @Test
    fun `Dart原版secondary按钮灰落在设置页底上_是合法弱表面_不判融`() {
        // QingyuLightPalette.SECONDARY #E6E6E6 vs 页底 #F2F2F2：对比比 ~1.11，
        // 靠 onSecondaryVariant 墨色承担可读性，HyperOS 设计如此。
        val ratio = ButtonContrastRules.contrastRatio(0xFFE6E6E6.toInt(), 0xFFF2F2F2.toInt())
        assertEquals(1.115, ratio, 0.01)
        assertFalse(ButtonContrastRules.isIndistinguishable(0xFFE6E6E6.toInt(), 0xFFF2F2F2.toInt()))
    }

    @Test
    fun `官方默认按钮灰落在白卡片上_不判融`() {
        // 亮色卡片 surfaceContainer #FFFFFF 上的默认灰按钮（官方弹层正统用法）。
        assertFalse(ButtonContrastRules.isIndistinguishable(0xFFF0F0F0.toInt(), 0xFFFFFFFF.toInt()))
    }

    @Test
    fun `次级按钮secondary灰落在白卡片上_清晰可辨_不判融`() {
        // 2026-11-03 适配器页重排定稿的次级按钮：secondary #E6E6E6 vs 白卡 #FFFFFF。
        val ratio = ButtonContrastRules.contrastRatio(0xFFE6E6E6.toInt(), 0xFFFFFFFF.toInt())
        assertEquals(1.25, ratio, 0.01)
        assertFalse(ButtonContrastRules.isIndistinguishable(0xFFE6E6E6.toInt(), 0xFFFFFFFF.toInt()))
    }

    @Test
    fun `surfaceVariant白底落在白卡片上_必须判融`() {
        // 适配器页「录制导入/查看详情」旧写法：容器取 surfaceVariant（本仓亮色接线
        // 未覆写 = 官方默认纯白），落在白卡上对比比 1.0 —— 用户实报「只剩一行蓝字」。
        // WarehouseAdapterActionsGuardTest 据此禁掉这个配色。
        assertTrue(ButtonContrastRules.isIndistinguishable(0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt()))
        assertEquals(1.0, ButtonContrastRules.contrastRatio(0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt()), 0.0)
    }

    @Test
    fun `主色蓝落在设置页底上_远高于阈值`() {
        val ratio = ButtonContrastRules.contrastRatio(0xFF3482FF.toInt(), 0xFFF2F2F2.toInt())
        assertEquals(3.24, ratio, 0.05)
        assertFalse(ButtonContrastRules.isIndistinguishable(0xFF3482FF.toInt(), 0xFFF2F2F2.toInt()))
    }

    @Test
    fun `纯黑对纯白_对比比恒为21`() {
        assertEquals(21.0, ButtonContrastRules.contrastRatio(0xFF000000.toInt(), 0xFFFFFFFF.toInt()), 0.01)
    }

    @Test
    fun `同色对比比恒为1_判融`() {
        assertTrue(ButtonContrastRules.isIndistinguishable(0xFFE6E6E6.toInt(), 0xFFE6E6E6.toInt()))
        assertEquals(1.0, ButtonContrastRules.contrastRatio(0xFFE6E6E6.toInt(), 0xFFE6E6E6.toInt()), 0.0)
    }

    @Test
    fun `前后景互换_对比比不变`() {
        assertEquals(
            ButtonContrastRules.contrastRatio(0xFF3482FF.toInt(), 0xFFF2F2F2.toInt()),
            ButtonContrastRules.contrastRatio(0xFFF2F2F2.toInt(), 0xFF3482FF.toInt()),
            0.0,
        )
    }
}
