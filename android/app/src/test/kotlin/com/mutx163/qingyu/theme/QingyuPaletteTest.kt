package com.mutx163.qingyu.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 色板转录 + 语义分支测试。
 *
 * Dart 源：`lib/ui/hyperos/hyperos_miuix_spec.dart:99-215`（亮/暗 hex）、
 * `lib/ui/hyperos/hyperos_theme.dart:15-54,119-179`（语义分支）。
 * 期望值全部人推（对照表 §2.1 逐项 + Flutter 源 hex），不是从实现里抄的。
 */
class QingyuPaletteTest {

    // --- Miuix 转录快照：亮 ---

    @Test fun `light primary转录`() {
        assertEquals(0xFF3482FFL.toInt(), QingyuLightPalette.PRIMARY)
    }

    @Test fun `light error与success转录`() {
        assertEquals(0xFFE94634L.toInt(), QingyuLightPalette.ERROR)
        assertEquals(0xFFFFFFFFL.toInt(), QingyuLightPalette.ON_ERROR)
        assertEquals(0xFF0E8043L.toInt(), QingyuLightPalette.SUCCESS)
    }

    @Test fun `light容器三档转录`() {
        assertEquals(0xFFFFFFFFL.toInt(), QingyuLightPalette.SURFACE_CONTAINER)
        assertEquals(0xFFE8E8E8L.toInt(), QingyuLightPalette.SURFACE_CONTAINER_HIGH)
        assertEquals(0xFFE8E8E8L.toInt(), QingyuLightPalette.SURFACE_CONTAINER_HIGHEST)
    }

    @Test fun `light分隔与遮罩转录`() {
        assertEquals(0xFFE0E0E0L.toInt(), QingyuLightPalette.DIVIDER_LINE)
        assertEquals(0xFFD9D9D9L.toInt(), QingyuLightPalette.OUTLINE)
        assertEquals(0x4D000000L.toInt(), QingyuLightPalette.WINDOW_DIMMING)
    }

    // --- Miuix 转录快照：暗 ---

    @Test fun `dark primary转录`() {
        assertEquals(0xFF277AF7L.toInt(), QingyuDarkPalette.PRIMARY)
    }

    @Test fun `dark error与success转录`() {
        assertEquals(0xFFF12522L.toInt(), QingyuDarkPalette.ERROR)
        assertEquals(0xFFFFFFFFL.toInt(), QingyuDarkPalette.ON_ERROR)
        assertEquals(0xFF3FD684L.toInt(), QingyuDarkPalette.SUCCESS)
    }

    @Test fun `dark容器三档转录`() {
        assertEquals(0xFF242424L.toInt(), QingyuDarkPalette.SURFACE_CONTAINER)
        assertEquals(0xFF242424L.toInt(), QingyuDarkPalette.SURFACE_CONTAINER_HIGH)
        assertEquals(0xFF2D2D2DL.toInt(), QingyuDarkPalette.SURFACE_CONTAINER_HIGHEST)
    }

    @Test fun `dark分隔与遮罩转录`() {
        assertEquals(0xFF393939L.toInt(), QingyuDarkPalette.DIVIDER_LINE)
        assertEquals(0xFF404040L.toInt(), QingyuDarkPalette.OUTLINE)
        assertEquals(0x99000000L.toInt(), QingyuDarkPalette.WINDOW_DIMMING)
    }

    // --- mikcb 实测覆写 ---

    @Test fun `mikcb覆写四值转录`() {
        assertEquals(0xFFF2F2F2L.toInt(), QingyuMikcbOverrides.SETTINGS_BACKGROUND)
        assertEquals(0xFF333333L.toInt(), QingyuMikcbOverrides.SETTINGS_PRIMARY_TEXT)
        assertEquals(0xFF999999L.toInt(), QingyuMikcbOverrides.SETTINGS_SECONDARY_TEXT)
        assertEquals(0xFFE0E0E0L.toInt(), QingyuMikcbOverrides.SETTINGS_PRESSED)
    }

    @Test fun `图标彩豆九色转录`() {
        assertEquals(0xFF3482FFL.toInt(), QingyuIconColors.BLUE)
        assertEquals(0xFF10C550L.toInt(), QingyuIconColors.GREEN)
        assertEquals(0xFFFF6B00L.toInt(), QingyuIconColors.ORANGE)
        assertEquals(0xFF8B5CF6L.toInt(), QingyuIconColors.PURPLE)
        assertEquals(0xFF14B8A6L.toInt(), QingyuIconColors.TEAL)
        assertEquals(0xFFFA382EL.toInt(), QingyuIconColors.RED)
        assertEquals(0xFFF5A623L.toInt(), QingyuIconColors.YELLOW)
        assertEquals(0xFF6366F1L.toInt(), QingyuIconColors.INDIGO)
        assertEquals(0xFF06B6D4L.toInt(), QingyuIconColors.CYAN)
    }

    @Test fun `固定token转录`() {
        assertEquals(0xFFE05D44L.toInt(), QingyuFixedTokens.DESTRUCTIVE)
        assertEquals(0xFF5A5A5AL.toInt(), QingyuFixedTokens.FIELD_LABEL_LIGHT)
        assertEquals(0xFFB8B8B8L.toInt(), QingyuFixedTokens.FIELD_LABEL_DARK)
    }

    // --- 语义分支（HyperosColors 口径）：亮/暗各走各的槽 ---

    @Test fun `scaffoldBackground亮用实测灰暗用Miuix背景`() {
        assertEquals(0xFFF2F2F2L.toInt(), QingyuTheme.scaffoldBackground(dark = false))
        assertEquals(0xFF242424L.toInt(), QingyuTheme.scaffoldBackground(dark = true))
    }

    @Test fun `card亮用surfaceContainer暗用最高级`() {
        // 咬合点：暗 card 必须是 0xFF2D2D2D（surfaceContainerHighest），
        // 若误用 surfaceContainer（0xFF242424）则与页底同色、卡片隐形。
        assertEquals(0xFFFFFFFFL.toInt(), QingyuTheme.card(dark = false))
        assertEquals(0xFF2D2D2DL.toInt(), QingyuTheme.card(dark = true))
    }

    @Test fun `主次文字亮用覆写暗用Miuix`() {
        assertEquals(0xFF333333L.toInt(), QingyuTheme.primaryText(dark = false))
        assertEquals(0xE6FFFFFFL.toInt(), QingyuTheme.primaryText(dark = true))
        assertEquals(0xFF999999L.toInt(), QingyuTheme.secondaryText(dark = false))
        assertEquals(0x80FFFFFFL.toInt(), QingyuTheme.secondaryText(dark = true))
    }

    @Test fun `actionIcon与rowHighlight分支`() {
        assertEquals(0x66000000L.toInt(), QingyuTheme.actionIcon(dark = false))
        assertEquals(0x66FFFFFFL.toInt(), QingyuTheme.actionIcon(dark = true))
        assertEquals(0xFFE0E0E0L.toInt(), QingyuTheme.rowHighlight(dark = false))
        assertEquals(0xFF505050L.toInt(), QingyuTheme.rowHighlight(dark = true))
    }

    @Test fun `容器错误成功墨线分支`() {
        assertEquals(0xFFFFFFFFL.toInt(), QingyuTheme.surfaceContainer(dark = false))
        assertEquals(0xFF242424L.toInt(), QingyuTheme.surfaceContainer(dark = true))
        assertEquals(0xFFE8E8E8L.toInt(), QingyuTheme.surfaceContainerHighest(dark = false))
        assertEquals(0xFF2D2D2DL.toInt(), QingyuTheme.surfaceContainerHighest(dark = true))
        assertEquals(0xFFE94634L.toInt(), QingyuTheme.error(dark = false))
        assertEquals(0xFFF12522L.toInt(), QingyuTheme.error(dark = true))
        assertEquals(0xFF0E8043L.toInt(), QingyuTheme.success(dark = false))
        assertEquals(0xFF3FD684L.toInt(), QingyuTheme.success(dark = true))
        assertEquals(0xFFE0E0E0L.toInt(), QingyuTheme.dividerLine(dark = false))
        assertEquals(0xFF393939L.toInt(), QingyuTheme.dividerLine(dark = true))
        assertEquals(0xFFD9D9D9L.toInt(), QingyuTheme.outline(dark = false))
        assertEquals(0xFF404040L.toInt(), QingyuTheme.outline(dark = true))
    }

    @Test fun `textFieldContainer亮降一级暗维持默认`() {
        // 亮 secondary（#E6E6E6），不取 secondaryContainer（#F0F0F0，会融进页面）；
        // 暗维持 secondaryContainer（#434343）。
        assertEquals(0xFFE6E6E6L.toInt(), QingyuTheme.textFieldContainer(dark = false))
        assertEquals(0xFF434343L.toInt(), QingyuTheme.textFieldContainer(dark = true))
    }

    @Test fun `destructive与fieldLabel`() {
        assertEquals(0xFFE05D44L.toInt(), QingyuTheme.destructive())
        assertEquals(0xFF5A5A5AL.toInt(), QingyuTheme.fieldLabel(dark = false))
        assertEquals(0xFFB8B8B8L.toInt(), QingyuTheme.fieldLabel(dark = true))
    }

    // --- 未知 key 回落：不崩，返回 null 由调用方回落默认 ---

    @Test fun `未知槽位key回落null`() {
        assertNull(QingyuTheme.colorFor("not_a_slot", dark = false))
        assertNull(QingyuTheme.colorFor("", dark = true))
        // 大小写不敏感：全大写同样命中。
        assertEquals(
            QingyuTheme.primary(dark = false),
            QingyuTheme.colorFor("PRIMARY", dark = false),
        )
    }

    @Test fun `已知槽位key可查且与类型化访问一致`() {
        assertEquals(
            QingyuTheme.scaffoldBackground(dark = false),
            QingyuTheme.colorFor("scaffoldBackground", dark = false),
        )
        assertEquals(
            QingyuTheme.card(dark = true),
            QingyuTheme.colorFor("card", dark = true),
        )
        assertEquals(
            QingyuTheme.error(dark = true),
            QingyuTheme.colorFor("error", dark = true),
        )
        // 大小写混写同样命中。
        assertEquals(
            QingyuTheme.card(dark = true),
            QingyuTheme.colorFor("Card", dark = true),
        )
    }

    @Test fun `成功墨与次墨快照`() {
        assertEquals(0xFF410002L.toInt(), QingyuLightPalette.ON_ERROR_CONTAINER)
        assertEquals(0xFFFFDAD6L.toInt(), QingyuDarkPalette.ON_ERROR_CONTAINER)
        assertTrue(QingyuLightPalette.SLIDER_BACKGROUND ushr 24 == 0x0F)
        assertTrue(QingyuDarkPalette.SLIDER_BACKGROUND ushr 24 == 0x26)
    }
}
