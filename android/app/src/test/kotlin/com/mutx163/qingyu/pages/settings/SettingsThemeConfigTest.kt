package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.AppThemeMode
import com.mutx163.qingyu.app.SectionTimeDisplayMode
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.TimetableCourseSpacingMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 主题管理页四处死控件的**数据层**：导出 / 导入 / 保存当前主题 / 已存主题四动作。
 *
 * ## 为什么这条测试必须存在
 *
 * 2026-10-29 一轮审核的 P0：这四处**点了完全没反应**——分派器把动作翻成
 * `ClipboardExport` / `ShowDialog` / `ShowSheet` 之后全仓 0 消费者，宿主把它们交给
 * 一个默认空实现的 `onIntent`。修法是「宿主自己消费 + 分派器提供纯逻辑」，
 * 而这个文件钉的就是**分派器那半**：键名、版本号、四个动作的读写语义。
 *
 * 期望值来源不是实现：键名抄 Dart `ThemeConfig.toJson`
 * （`lib/models/timetable_settings.dart:123-144`）、条目形状抄 `SavedTheme.toJson`
 * （`:39-44`）、id 口径抄 `timetable_theme_service.dart:73`。
 */
class SettingsThemeConfigTest {

    private val base = TimetableSettingsModel()

    // ------------------------------------------------------------------ 导出

    @Test
    fun `导出的主题配置带版本号 2 与 Dart 的短键`() {
        val config = SettingsActionDispatcher.themeConfigOf(base)
        assertEquals(
            "版本号必须写进导出（Dart `_importTheme` 用 v==2 决定要不要校验必填色）",
            2,
            config["v"],
        )
        // Dart ThemeConfig.toJson 的 18 个短键（`bg` 不在本模型覆盖范围内）。
        val expectedKeys = setOf(
            "seed", "uc", "ucOn", "mode", "ccl", "ccd", "cdl", "cdd",
            "wbl", "wbd", "wal", "wad", "tal", "tad", "link",
            "hideWeekend", "spacing", "timeDisplay",
        )
        assertEquals(
            "导出键必须与 Dart ThemeConfig.toJson 逐字一致",
            expectedKeys + "v",
            config.keys,
        )
        assertEquals("#2563EB", config["seed"])
        assertEquals("system", config["mode"])
        // 默认值来自模型构造：spacing=NARROW("narrow")、timeDisplay=START_AND_END("start_and_end")
        assertEquals("narrow", config["spacing"])
        assertEquals("start_and_end", config["timeDisplay"])
    }

    @Test
    fun `导出的颜色不归一大小写`() {
        // Dart `fromSettings` 原样搬 getter 的值，不做大小写归一；写回路径才归一。
        val model = base.copy(themeSeedColor = "#abcdef")
        assertEquals("#abcdef", SettingsActionDispatcher.themeConfigOf(model)["seed"])
    }

    // ------------------------------------------------------------------ 导入

    @Test
    fun `导入 v2 缺 seed 或 ccl 判为不可用`() {
        assertFalse(
            "v2 缺 seed 必须拒绝（Dart `_importTheme` 的必填校验）",
            SettingsActionDispatcher.themeConfigIsUsable(mapOf("v" to 2, "ccl" to "#FFFFFF")),
        )
        assertFalse(
            SettingsActionDispatcher.themeConfigIsUsable(mapOf("v" to 2, "seed" to "#112233")),
        )
        assertTrue(
            SettingsActionDispatcher.themeConfigIsUsable(
                mapOf("v" to 2, "seed" to "#112233", "ccl" to "#FFFFFF"),
            ),
        )
    }

    @Test
    fun `缺 v 或 v1 的老格式放行`() {
        // Dart：`version = lenientInt(json['v']) ?? 1`，v1 只走颜色、不校验必填。
        assertTrue(SettingsActionDispatcher.themeConfigIsUsable(mapOf("seed" to "#112233")))
        assertTrue(SettingsActionDispatcher.themeConfigIsUsable(mapOf("v" to 1)))
    }

    @Test
    fun `导入写回 18 个字段`() {
        val config = mapOf(
            "v" to 2,
            "seed" to "#112233",
            "ucOn" to true,
            "mode" to "dark",
            "ccl" to "#AABBCC",
            "hideWeekend" to true,
            "spacing" to "wide",
            "timeDisplay" to "startAndEnd",
        )
        val next = SettingsActionDispatcher.applyThemeConfig(base, config)
        assertEquals("#112233", next.themeSeedColor)
        assertTrue(next.timetableUseUnifiedCardColor)
        assertEquals(AppThemeMode.DARK, next.appThemeMode)
        assertEquals("#AABBCC", next.courseCardTitleColorLight)
        assertTrue(next.timetableHideWeekends)
        assertEquals(TimetableCourseSpacingMode.WIDE, next.timetableCourseSpacingMode)
        assertEquals(
            SectionTimeDisplayMode.START_AND_END,
            next.timetableSectionTimeDisplayMode,
        )
    }

    @Test
    fun `导入遇到不认识的键安静忽略而不炸`() {
        val next = SettingsActionDispatcher.applyThemeConfig(
            base,
            mapOf("seed" to "#112233", "bg" to "#FFFFFF", "nonsense" to 42),
        )
        assertEquals("#112233", next.themeSeedColor)
        // `bg`（课表背景色）不在本模型覆盖范围内：放过但不写坏别的字段。
        assertEquals(base.timetableHideWeekends, next.timetableHideWeekends)
    }

    @Test
    fun `导出再导入能还原同一套主题`() {
        val model = base.copy(
            themeSeedColor = "#0F172A",
            appThemeMode = AppThemeMode.LIGHT,
            courseCardTitleColorLight = "#F8FAFC",
            timetableHideWeekends = true,
        )
        val json = MiniJson.encode(SettingsActionDispatcher.themeConfigOf(model))
        val parsed = MiniJson.tryParse(json) as Map<*, *>
        val config = parsed.entries.mapNotNull { (k, v) -> (k as? String)?.let { it to v } }.toMap()
        val restored = SettingsActionDispatcher.applyThemeConfig(base, config)
        assertEquals(model.themeSeedColor, restored.themeSeedColor)
        assertEquals(model.appThemeMode, restored.appThemeMode)
        assertEquals(model.courseCardTitleColorLight, restored.courseCardTitleColorLight)
        assertEquals(model.timetableHideWeekends, restored.timetableHideWeekends)
    }

    // -------------------------------------------------------------- 保存当前主题

    @Test
    fun `保存当前主题追加一条四键条目`() {
        val next = SettingsActionDispatcher.saveTheme(base, "  晚自习  ", "1700000000000", "2026-10-29T21:00:00")
        assertNotNull(next)
        assertEquals(1, next!!.savedThemes.size)
        val entry = next.savedThemes.single()
        assertEquals("1700000000000", entry["id"])
        assertEquals("名字要去首尾空白", "晚自习", entry["name"])
        assertEquals("2026-10-29T21:00:00", entry["createdAt"])
        val themeData = entry["themeData"] as Map<*, *>
        assertEquals("themeData 必须是 ThemeConfig 的短键", "#2563EB", themeData["seed"])
        assertEquals(2, themeData["v"])
    }

    @Test
    fun `保存当前主题空名字不写盘`() {
        assertNull(SettingsActionDispatcher.saveTheme(base, "   ", "1", "now"))
    }

    @Test
    fun `保存不改检查点`() {
        // Dart `saveTheme` 只 append，不动 `themeCheckpointName`（`timetable_theme_service.dart:69-83`）。
        val withCheckpoint = base.copy(themeCheckpointName = "旧主题")
        val next = SettingsActionDispatcher.saveTheme(withCheckpoint, "新主题", "1", "now")
        assertEquals("旧主题", next!!.themeCheckpointName)
    }

    // -------------------------------------------------------------- 已存主题四动作

    private fun withSavedTheme(): TimetableSettingsModel =
        SettingsActionDispatcher.saveTheme(base, "夜景", "11", "2026-10-29T20:00:00")!!.let { saved ->
            // 把这份主题改成与 base 不同的值，便于断言「应用」真的生效。
            val entry = saved.savedThemes.single()
            val themeData = (entry["themeData"] as Map<String, Any?>) + mapOf(
                "seed" to "#FF0000",
                "mode" to "dark",
            )
            saved.copy(savedThemes = listOf(entry + ("themeData" to themeData)))
        }

    @Test
    fun `应用已存主题写回字段并把检查点换成它`() {
        val model = withSavedTheme()
        val next = SettingsActionDispatcher.applySavedTheme(model, "11")
        assertNotNull(next)
        assertEquals("#FF0000", next!!.themeSeedColor)
        assertEquals(AppThemeMode.DARK, next.appThemeMode)
        assertEquals("夜景", next.themeCheckpointName)
        assertEquals("#FF0000", next.themeCheckpointConfig?.get("seed"))
    }

    @Test
    fun `应用不存在的主题返回 null`() {
        assertNull(SettingsActionDispatcher.applySavedTheme(withSavedTheme(), "999"))
    }

    @Test
    fun `重命名只换名字`() {
        val model = withSavedTheme()
        val next = SettingsActionDispatcher.renameSavedTheme(model, "11", " 深夜 ")
        assertNotNull(next)
        val entry = next!!.savedThemes.single()
        assertEquals("深夜", entry["name"])
        assertEquals("id 不许变", "11", entry["id"])
        assertEquals("2026-10-29T20:00:00", entry["createdAt"])
        assertEquals(
            "themeData 不许动",
            (model.savedThemes.single()["themeData"] as Map<*, *>)["seed"],
            (entry["themeData"] as Map<*, *>)["seed"],
        )
    }

    @Test
    fun `重命名空名字或未知 id 返回 null`() {
        val model = withSavedTheme()
        assertNull(SettingsActionDispatcher.renameSavedTheme(model, "11", "  "))
        assertNull(SettingsActionDispatcher.renameSavedTheme(model, "999", "x"))
    }

    @Test
    fun `复制沿用 themeData 且名字由调用方给`() {
        val model = withSavedTheme()
        val next = SettingsActionDispatcher.duplicateSavedTheme(
            model = model,
            sourceId = "11",
            newId = "12",
            newName = "夜景 副本",
            createdAtIso = "2026-10-29T21:00:00",
        )
        assertNotNull(next)
        assertEquals(2, next!!.savedThemes.size)
        val copy = next.savedThemes.last()
        assertEquals("12", copy["id"])
        assertEquals("夜景 副本", copy["name"])
        assertEquals(
            "副本的 themeData 必须与源一致",
            (model.savedThemes.single()["themeData"] as Map<*, *>)["seed"],
            (copy["themeData"] as Map<*, *>)["seed"],
        )
    }

    @Test
    fun `删除按 id 移除且未知 id 返回 null`() {
        val model = withSavedTheme()
        val next = SettingsActionDispatcher.deleteSavedTheme(model, "11")
        assertNotNull(next)
        assertTrue(next!!.savedThemes.isEmpty())
        assertNull(SettingsActionDispatcher.deleteSavedTheme(model, "999"))
    }

    @Test
    fun `行 id 前缀解析`() {
        assertEquals("11", SettingsActionDispatcher.savedThemeIdOf("theme.saved.11"))
        assertNull(SettingsActionDispatcher.savedThemeIdOf("theme.save"))
        assertNull(SettingsActionDispatcher.savedThemeIdOf("theme.saved."))
        assertNull(SettingsActionDispatcher.savedThemeIdOf("theme.export"))
    }

    // -------------------------------------------------------------- 落盘读回校验

    @Test
    fun `改动过的键没进盘就返回 false`() {
        val before = base
        val after = base.copy(enableHaptics = !base.enableHaptics)
        val disk = before // 写失败：盘上还是旧值
        assertFalse(
            "写完回读还是旧值 ⇒ 必须判失败（宿主据此把草稿拉回真值并提示）",
            SettingsActionDispatcher.persistLanded(before, after, disk),
        )
    }

    @Test
    fun `改动过的键进了盘就返回 true 且不看未改动键的类型`() {
        val before = base
        val after = base.copy(enableHaptics = !base.enableHaptics, pageTransitionSpeed = 1.5)
        val disk = after
        assertTrue(SettingsActionDispatcher.persistLanded(before, after, disk))
    }

    @Test
    fun `只比改动过的键`() {
        val before = base
        val after = base.copy(enableHaptics = !base.enableHaptics)
        // 盘上「其它键」被别处改过（比如另一个页面同时写），不应影响本次判定。
        val disk = base.copy(pageTransitionSpeed = 2.5, enableHaptics = after.enableHaptics)
        assertTrue(
            SettingsActionDispatcher.persistLanded(before, after, disk),
        )
    }
}
