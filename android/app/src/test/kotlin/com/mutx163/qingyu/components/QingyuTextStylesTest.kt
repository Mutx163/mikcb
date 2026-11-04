package com.mutx163.qingyu.components

import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
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
    fun `用户改过字重时不再抵扣系统粗体增量`() {
        // Dart `AppFontScope.resolveShiftedWeight`（`lib/ui/app_fonts.dart:105-116`）是两分支：
        //   用户设非默认字重 → design + (user - 400)     —— 不减系统增量
        //   用户未改         → design - systemDelta      —— 减（见上一条用例）
        // 旧实现无条件减 delta，会让「系统粗体 + 应用字重 w600」的正文落到 w500，
        // 比 Dart 细一档；subtitle 还会从 900 掉到 800，课卡主次差被抹掉。
        val ours = buildQingyuTextStyles(userFontWeight = 600, systemWeightDelta = 100)
        assertEquals(FontWeight.W600, ours.main.fontWeight)
        assertEquals(FontWeight.W900, ours.subtitle.fontWeight)
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

    // ─────────────────────────────────────────────────────────────
    // 哨兵值（2026-10-27 咬合探针查出的缺口，补上）
    // ─────────────────────────────────────────────────────────────

    @Test
    fun `未设置系统粗体时的哨兵值必须归零`() {
        // `Configuration.FONT_WEIGHT_ADJUSTMENT_UNDEFINED` = Int.MAX_VALUE。
        //
        // 不判它的后果是灾难性的：`design + (用户字重 - 400) - Int.MAX_VALUE`
        // 会下溢成极大的负数，被 `coerceIn(100, 900)` 钳到 **w100** ——
        // 全站文字变成极细，而且不报错、不崩，只是"看起来不对劲"。
        //
        // 这条断言存在的直接理由：咬合探针把实现改回不判哨兵时，
        // 其余 8 例全绿 —— 说明当时这段判据是裸奔的。现在它被钉住了。
        assertEquals(0, normalizeSystemWeightDelta(Int.MAX_VALUE))

        // 真值必须原样通过（不能顺手把合法增量也吃掉）。
        assertEquals(100, normalizeSystemWeightDelta(100))
        assertEquals(-100, normalizeSystemWeightDelta(-100))
        assertEquals(0, normalizeSystemWeightDelta(0))

        // 端到端：哨兵值进来时字阶必须与"没开粗体"完全一致。
        val withSentinel = buildQingyuTextStyles(
            systemWeightDelta = normalizeSystemWeightDelta(Int.MAX_VALUE),
        )
        assertEquals(FontWeight.W400, withSentinel.main.fontWeight)
        assertEquals(FontWeight.Bold, withSentinel.subtitle.fontWeight)
    }

    @Test
    fun `哨兵值直接灌进内核会露馅（证明这条判据不可省）`() {
        // 反向验证：如果谁绕过 normalizeSystemWeightDelta、把哨兵原值直接给内核，
        // 字重会被钳到下限。这条断言把"为什么必须判"写成了可执行的证据。
        val broken = buildQingyuTextStyles(systemWeightDelta = Int.MAX_VALUE)
        assertEquals(
            "哨兵原值会让字重下溢并被钳到 w100 —— 这正是要防的",
            FontWeight.W100,
            broken.main.fontWeight,
        )
        // 而正规路径（经 normalize）不会发生这件事。
        assertEquals(
            FontWeight.W400,
            buildQingyuTextStyles(
                systemWeightDelta = normalizeSystemWeightDelta(Int.MAX_VALUE),
            ).main.fontWeight,
        )
    }

    // ─────────────────────────────────────────────────────────────
    // 页面强调：在主题字阶上平移，而不是写死绝对字重（2026-11-01）
    // ─────────────────────────────────────────────────────────────

    @Test
    fun `默认设置下页面强调与旧的写死字重逐档一致`() {
        // 这是替换 311 处 `fontWeight = FontWeight.X` 的等价性证明：
        // 用户 400、系统未开粗体时，shiftWeight 必须落在旧写法的同一个绝对值上，
        // 否则这次「清理」就变成了一次全站变粗/变细。
        val styles = buildQingyuTextStyles()
        assertEquals(
            FontWeight.W300,
            styles.title1.shiftWeight(QingyuWeightDelta.LIGHT).fontWeight,
        )
        assertEquals(
            FontWeight.W500,
            styles.body1.shiftWeight(QingyuWeightDelta.MEDIUM).fontWeight,
        )
        assertEquals(
            FontWeight.W600,
            styles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD).fontWeight,
        )
        assertEquals(
            FontWeight.W700,
            styles.footnote1.shiftWeight(QingyuWeightDelta.BOLD).fontWeight,
        )
        assertEquals(
            FontWeight.W800,
            styles.footnote2.shiftWeight(QingyuWeightDelta.EXTRABOLD).fontWeight,
        )
        // subtitle 本身设计就是 Bold（700），再加一档才是 800。
        assertEquals(
            FontWeight.W800,
            styles.subtitle.shiftWeight(QingyuWeightDelta.MEDIUM).fontWeight,
        )
    }

    @Test
    fun `页面强调跟随用户字重平移，不再盖掉设置`() {
        // 用户选 w600：字阶整体 +200，页面强调也要跟着 +200，
        // 否则「应用字重」在这一处失效（这正是旧写法的缺陷）。
        val styles = buildQingyuTextStyles(userFontWeight = 600)
        assertEquals(
            "正文平移后是 600，再强调一档应为 800",
            FontWeight.W800,
            styles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD).fontWeight,
        )
        // 上下限收敛：subtitle 700 + 200 = 900 已到顶，再强调仍钳在 900。
        assertEquals(
            FontWeight.W900,
            styles.subtitle.shiftWeight(QingyuWeightDelta.SEMIBOLD).fontWeight,
        )
    }

    @Test
    fun `页面强调的基准是系统粗体减法之后的字重`() {
        // 系统粗体 +100 时，内核先把字阶减回 300，避免平台再加一次造成双倍。
        // 页面强调必须在这个 300 的基准上叠加，而不是在 400 上。
        val styles = buildQingyuTextStyles(systemWeightDelta = 100)
        assertEquals(FontWeight.W300, styles.body1.fontWeight)
        assertEquals(
            FontWeight.W500,
            styles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD).fontWeight,
        )
    }

    @Test
    fun `页面强调钳在 100 到 900`() {
        val styles = buildQingyuTextStyles()
        assertEquals(
            FontWeight.W900,
            styles.body1.shiftWeight(5000).fontWeight,
        )
        assertEquals(
            FontWeight.W100,
            styles.body1.shiftWeight(-5000).fontWeight,
        )
    }

    @Test
    fun `页面强调只动字重，不动字号`() {
        val style = buildQingyuTextStyles().body1
        val shifted = style.shiftWeight(QingyuWeightDelta.SEMIBOLD)
        assertEquals(style.fontSize, shifted.fontSize)
        assertEquals(style.lineHeight, shifted.lineHeight)
        assertEquals(style.letterSpacing, shifted.letterSpacing)
    }

    @Test
    fun `增量为零时原样返回，不做无谓的复制`() {
        val style = buildQingyuTextStyles().body1
        assertSame(style, style.shiftWeight(0))
        val span = SpanStyle(fontWeight = FontWeight.W600)
        assertSame(span, span.shiftWeight(0))
    }

    @Test
    fun `SpanStyle 版本与 TextStyle 同口径`() {
        // AnnotatedString 里的局部加重走 SpanStyle。它的 fontWeight 允许为 null
        // （= 继承外层），这里按 w400 起算，与 TextStyle 版保持一致。
        assertEquals(
            FontWeight.W600,
            SpanStyle().shiftWeight(QingyuWeightDelta.SEMIBOLD).fontWeight,
        )
        assertEquals(
            FontWeight.W800,
            SpanStyle(fontWeight = FontWeight.W600)
                .shiftWeight(QingyuWeightDelta.SEMIBOLD)
                .fontWeight,
        )
    }
}
