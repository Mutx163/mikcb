package com.mutx163.qingyu.components

import androidx.compose.ui.text.font.FontWeight
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `buildQingyuTextStyles` 的契约测试（2026-10-27）。
 *
 * ## 为什么这个函数值得单测
 *
 * 它是「用户字重 / 系统粗体」唯一的落点：miuix 的 Compose 侧 0.9.4 **没有**
 * `fontWeightAdjustment`（六模块 sources 全搜 0 命中），所以这两项能不能生效，
 * 全看这里算得对不对。算错的两种后果都是灾难且**肉眼难查**：
 *
 * * 哨兵值 `Int.MAX_VALUE` 没判掉 → 字重被钳到 w100，全站变极细；
 * * 平移写成覆盖 → 标题与正文压成同一档，卡片失去主次。
 *
 * ## 期望值都是手推的
 *
 * 官方默认字阶（`TextStyles.kt:146-238`）：main 17 / paragraph 17 / body1 16 /
 * body2 14 / button 17 / footnote1 13 / footnote2 11 / headline1 17 /
 * headline2 16 / subtitle 14+**Bold** / title1 32 / title2 24 / title3 20 / title4 18。
 * 除 subtitle 外**全都不带 fontWeight**（即 null → 按 w400 处理）。
 */
class QingyuTextStylesTest {

    @Test
    fun `默认参数下产出与官方完全一致`() {
        // 这条是「注入无副作用」的证明：没改任何设置时，我们送进去的字阶
        // 必须与官方默认逐槽相等，否则等于偷偷改了全站排版。
        val ours = buildQingyuTextStyles()
        val official = top.yukonga.miuix.kmp.theme.defaultTextStyles()

        assertEquals(official.main.fontSize, ours.main.fontSize)
        assertEquals(official.body1.fontSize, ours.body1.fontSize)
        assertEquals(official.body2.fontSize, ours.body2.fontSize)
        assertEquals(official.footnote1.fontSize, ours.footnote1.fontSize)
        assertEquals(official.footnote2.fontSize, ours.footnote2.fontSize)
        assertEquals(official.title1.fontSize, ours.title1.fontSize)
        assertEquals(official.title4.fontSize, ours.title4.fontSize)
        // subtitle 的 Bold 必须保留（官方唯一带字重的槽位）。
        assertEquals(FontWeight.Bold, ours.subtitle.fontWeight)
    }

    @Test
    fun `未指定字重时所有槽位按 w400 落地`() {
        // 官方除 subtitle 外都是 fontWeight = null。Compose 解析时按 w400，
        // 我们显式写死 w400 是等价的 —— 但不能写成别的。
        val ours = buildQingyuTextStyles()
        assertEquals(FontWeight.W400, ours.main.fontWeight)
        assertEquals(FontWeight.W400, ours.body1.fontWeight)
        assertEquals(FontWeight.W400, ours.footnote2.fontWeight)
        assertEquals(FontWeight.W400, ours.title1.fontWeight)
    }

    @Test
    fun `用户字重是按差值平移，不是覆盖`() {
        // 用户选 w600：比默认 400 多 200。
        // main（设计 400）→ 600；subtitle（设计 700 Bold）→ 900。
        // 若写成「覆盖」，两者都会变 600，层级被抹平 —— 那是错的。
        val ours = buildQingyuTextStyles(userFontWeight = 600)
        assertEquals(FontWeight.W600, ours.main.fontWeight)
        assertEquals(
            "subtitle 是唯一带设计字重（Bold=700）的槽位，平移后应为 900",
            FontWeight.W900,
            ours.subtitle.fontWeight,
        )
        // 差值保留：subtitle 必须比 main 粗，这是层级。
        assert(ours.subtitle.fontWeight!!.weight > ours.main.fontWeight!!.weight)
    }

    @Test
    fun `用户字重变细时同样按差值平移`() {
        // 用户选 w300：比默认少 100。main 400 → 300；subtitle 700 → 600。
        val ours = buildQingyuTextStyles(userFontWeight = 300)
        assertEquals(FontWeight.W300, ours.main.fontWeight)
        assertEquals(FontWeight.W600, ours.subtitle.fontWeight)
    }

    @Test
    fun `平移结果钳在 100 到 900`() {
        // 用户拉到极点也不能溢出字体可用的字重范围。
        assertEquals(
            FontWeight.W900,
            buildQingyuTextStyles(userFontWeight = 900).subtitle.fontWeight,
        )
        // w100 时 main（400-300）刚好 100，不越界。
        assertEquals(
            FontWeight.W100,
            buildQingyuTextStyles(userFontWeight = 100).main.fontWeight,
        )
        // 极端输入也不崩：非法值钳回范围内而不是抛。
        val extreme = buildQingyuTextStyles(userFontWeight = 5000)
        assertEquals(FontWeight.W900, extreme.main.fontWeight)
        val negative = buildQingyuTextStyles(userFontWeight = -999)
        assertEquals(FontWeight.W100, negative.main.fontWeight)
    }

    @Test
    fun `系统粗体增量走减法，避免与平台重复叠加`() {
        // Android 平台自己会把 fontWeightAdjustment 加到文字上；我们再加一次就是
        // 双倍。所以系统开了 +100 时，这里要减回 100：main 400 - 100 = 300。
        // 这与 Dart 侧 `resolveShiftedWeight` 的 `designWeight - systemFontWeightDelta` 同口径。
        val ours = buildQingyuTextStyles(systemWeightDelta = 100)
        assertEquals(FontWeight.W300, ours.main.fontWeight)
        // subtitle 700 - 100 = 600，层级仍在。
        assertEquals(FontWeight.W600, ours.subtitle.fontWeight)
    }

    @Test
    fun `字族为空时不覆写，有值时全槽位生效`() {
        // null = 跟随系统默认，不能塞一个空 FontFamily 进去（那会与主题的字族脱钩）。
        val withoutFamily = buildQingyuTextStyles(fontFamily = null)
        assertNull(withoutFamily.main.fontFamily)
        assertNull(withoutFamily.title1.fontFamily)

        // 有值时每个槽位都要挂上，漏一个槽就会有一处字体不一致。
        val family = androidx.compose.ui.text.font.FontFamily.Monospace
        val withFamily = buildQingyuTextStyles(fontFamily = family)
        assertEquals(family, withFamily.main.fontFamily)
        assertEquals(family, withFamily.body1.fontFamily)
        assertEquals(family, withFamily.footnote2.fontFamily)
        assertEquals(family, withFamily.subtitle.fontFamily)
        assertEquals(family, withFamily.title1.fontFamily)
        assertEquals(family, withFamily.title4.fontFamily)
    }

    @Test
    fun `字号一律不改，只动字重与字族`() {
        // 字号归官方字阶所有；这里若也改字号，就会与「用 textStyles 代替裸 fontSize」
        // 的整条纪律打架（官方字阶是唯一刻度）。
        val ours = buildQingyuTextStyles(userFontWeight = 700, systemWeightDelta = 50)
        val official = top.yukonga.miuix.kmp.theme.defaultTextStyles()
        assertEquals(official.title1.fontSize, ours.title1.fontSize)
        assertEquals(official.body2.fontSize, ours.body2.fontSize)
        assertEquals(official.footnote1.fontSize, ours.footnote1.fontSize)
        assertNotNull(ours.main)
    }
}
