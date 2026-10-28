package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.AppThemeMode
import com.mutx163.qingyu.app.ForuiTheme
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class GuideSettingsMappingTest {

    @Test
    fun `applyPatch 三个可写字段都能回环读回`() {
        val base = TimetableSettingsModel(
            homeMenuStyle = HomeMenuStyle.LIST,
            appThemeMode = AppThemeMode.SYSTEM,
            foruiTheme = ForuiTheme.MIUI,
            themeSeedColor = ForuiTheme.MIUI.seedHex,
        )
        // 基线：列表 + 系统 + MIUI
        assertFalse(GuideSettingsMapping.snapshotFrom(base).homeMenuGrid)
        assertEquals(GuideThemeMode.SYSTEM, GuideSettingsMapping.snapshotFrom(base).themeMode)
        assertEquals(ForuiTheme.MIUI.seedHex, GuideSettingsMapping.snapshotFrom(base).seedHex)

        // HomeMenuGrid 回环
        val grid = GuideSettingsMapping.applyPatch(base, GuideSettingsPatch.HomeMenuGrid(true))
        assertTrue(GuideSettingsMapping.snapshotFrom(grid).homeMenuGrid)
        assertEquals(HomeMenuStyle.GRID, grid.homeMenuStyle)

        // ThemeMode 回环
        val dark = GuideSettingsMapping.applyPatch(
            base,
            GuideSettingsPatch.ThemeMode(GuideThemeMode.DARK),
        )
        assertEquals(GuideThemeMode.DARK, GuideSettingsMapping.snapshotFrom(dark).themeMode)
        assertEquals(AppThemeMode.DARK, dark.appThemeMode)

        val light = GuideSettingsMapping.applyPatch(
            base,
            GuideSettingsPatch.ThemeMode(GuideThemeMode.LIGHT),
        )
        assertEquals(GuideThemeMode.LIGHT, GuideSettingsMapping.snapshotFrom(light).themeMode)

        // SeedColor 回环：按 hex 反查到对应 ForuiTheme，同时写 themeSeedColor
        val greenHex = ForuiTheme.GREEN.seedHex
        val seeded = GuideSettingsMapping.applyPatch(base, GuideSettingsPatch.SeedColor(greenHex))
        assertEquals(greenHex, GuideSettingsMapping.snapshotFrom(seeded).seedHex)
        assertEquals(ForuiTheme.GREEN, seeded.foruiTheme)
        assertEquals(greenHex, seeded.themeSeedColor)
    }

    @Test
    fun `SeedColor 遇到自定义色时保留原枚举只改种子色`() {
        val base = TimetableSettingsModel(foruiTheme = ForuiTheme.BLUE)
        val custom = "#123456"
        val patched = GuideSettingsMapping.applyPatch(base, GuideSettingsPatch.SeedColor(custom))
        assertEquals(ForuiTheme.BLUE, patched.foruiTheme) // 反查不到 → 保留
        assertEquals(custom, patched.themeSeedColor)
    }

    @Test
    fun `MaterialSolid 补丁不改模型且快照恒为 false`() {
        val base = TimetableSettingsModel()
        val patched = GuideSettingsMapping.applyPatch(base, GuideSettingsPatch.MaterialSolid(true))
        assertSame("MaterialSolid 目前应为 no-op，返回同一实例", base, patched)
        assertFalse(GuideSettingsMapping.snapshotFrom(base).materialSolid)
    }

    @Test
    fun `seedOptions 非空_覆盖全部主题且 hex 合法`() {
        val options = GuideSettingsMapping.seedOptions()
        assertTrue("色板不应为空", options.isNotEmpty())
        assertEquals(ForuiTheme.entries.size, options.size)

        val hexRegex = Regex("^#[0-9A-Fa-f]{6}$")
        for (option in options) {
            assertTrue("hex 非法：${option.hex}", hexRegex.matches(option.hex))
            assertTrue("label 不应为空：${option.hex}", option.label.isNotBlank())
        }
        // 与枚举种子色一一对应、无重复
        assertEquals(
            ForuiTheme.entries.map { it.seedHex }.toSet(),
            options.map { it.hex }.toSet(),
        )
        assertEquals(options.size, options.map { it.hex.uppercase() }.toSet().size)
    }
}
