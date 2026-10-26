package com.mutx163.qingyu.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 字阶 + 字重测试。
 *
 * Dart 源：`lib/ui/hyperos/hyperos_miuix_spec.dart:221-237`（字号）、
 * `lib/ui/hyperos/hyperos_tokens.dart:71-87`（语义别名）、
 * `lib/models/settings/timetable_settings_enums.dart:27-43`（字重区间）、
 * `lib/ui/app_fonts.dart:84-116`（resolve 口径）。
 */
class QingyuTypographyTest {

    @Test fun `Miuix字阶逐项转录`() {
        assertEquals(17.0, QingyuTypography.MAIN, 0.0)
        assertEquals(17.0, QingyuTypography.PARAGRAPH, 0.0)
        assertEquals(1.2, QingyuTypography.PARAGRAPH_LINE_HEIGHT, 0.0)
        assertEquals(16.0, QingyuTypography.BODY1, 0.0)
        assertEquals(14.0, QingyuTypography.BODY2, 0.0)
        assertEquals(17.0, QingyuTypography.BUTTON, 0.0)
        assertEquals(13.0, QingyuTypography.FOOTNOTE1, 0.0)
        assertEquals(11.0, QingyuTypography.FOOTNOTE2, 0.0)
        assertEquals(17.0, QingyuTypography.HEADLINE1, 0.0)
        assertEquals(16.0, QingyuTypography.HEADLINE2, 0.0)
        assertEquals(14.0, QingyuTypography.SUBTITLE, 0.0)
        assertEquals(32.0, QingyuTypography.TITLE1, 0.0)
        assertEquals(24.0, QingyuTypography.TITLE2, 0.0)
        assertEquals(20.0, QingyuTypography.TITLE3, 0.0)
        assertEquals(18.0, QingyuTypography.TITLE4, 0.0)
    }

    @Test fun `语义别名与行高`() {
        assertEquals(17.0, QingyuTypography.PREFERENCE_TITLE, 0.0)
        assertEquals(14.0, QingyuTypography.LIST_DETAIL, 0.0)
        assertEquals(13.0, QingyuTypography.SECTION_LABEL, 0.0)
        assertEquals(13.0, QingyuTypography.SECTION_DESCRIPTION, 0.0)
        assertEquals(20.0, QingyuTypography.NESTED_HEADER_TITLE, 0.0)
        assertEquals(1.25, QingyuTypography.TITLE_LINE_HEIGHT, 0.0)
        assertEquals(1.4, QingyuTypography.LIST_DETAIL_LINE_HEIGHT, 0.0)
    }

    @Test fun `字重区间常量`() {
        assertEquals(400, QingyuTypography.WEIGHT_DEFAULT)
        assertEquals(100, QingyuTypography.WEIGHT_MIN)
        assertEquals(900, QingyuTypography.WEIGHT_MAX)
    }

    @Test fun `sizeFor已知槽未知回落`() {
        assertEquals(17.0, QingyuTypography.sizeFor("main")!!, 0.0)
        assertEquals(13.0, QingyuTypography.sizeFor("footnote1")!!, 0.0)
        assertEquals(32.0, QingyuTypography.sizeFor("title1")!!, 0.0)
        assertNull(QingyuTypography.sizeFor("nope"))
        assertNull(QingyuTypography.sizeFor(""))
    }

    @Test fun `resolveWeight用户未改只做系统增量补偿`() {
        assertEquals(400, QingyuTypography.resolveWeight(400, 400, 0))
        assertEquals(385, QingyuTypography.resolveWeight(400, 400, 15))
        assertEquals(100, QingyuTypography.resolveWeight(400, 100, 50))
        assertEquals(900, QingyuTypography.resolveWeight(400, 900, -50))
    }

    @Test fun `resolveWeight用户设定绝对覆盖并钳制`() {
        assertEquals(700, QingyuTypography.resolveWeight(700, 400, 0))
        assertEquals(900, QingyuTypography.resolveWeight(950, 400, 0))
        assertEquals(100, QingyuTypography.resolveWeight(50, 400, 0))
    }

    @Test fun `resolveShiftedWeight保留角色差`() {
        // 用户 500：标题 700→800、详情 400→500，差值 300 不变。
        assertEquals(800, QingyuTypography.resolveShiftedWeight(500, 700, 0))
        assertEquals(500, QingyuTypography.resolveShiftedWeight(500, 400, 0))
        // 极值收敛：用户 900 时标题顶到 900。
        assertEquals(900, QingyuTypography.resolveShiftedWeight(900, 700, 0))
    }

    @Test fun `normalizeWeight非法回落默认`() {
        assertEquals(400, QingyuTypography.normalizeWeight(null))
        assertEquals(400, QingyuTypography.normalizeWeight(399.6))
        assertEquals(100, QingyuTypography.normalizeWeight(-10.0))
        assertEquals(900, QingyuTypography.normalizeWeight(9999.0))
    }

    @Test fun `大标题字阶对齐折叠栏`() {
        assertTrue(QingyuTypography.TITLE1 > QingyuTypography.TITLE2)
        assertTrue(QingyuTypography.TITLE2 > QingyuTypography.TITLE3)
        // 磨砂子页居中标题 20 与 title3 同值：折叠大标题字阶对齐即此处。
        assertEquals(QingyuTypography.TITLE3, QingyuTypography.NESTED_HEADER_TITLE, 0.0)
    }
}
