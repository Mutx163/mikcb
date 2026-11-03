package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.AppFontMode
import com.mutx163.qingyu.app.CourseCardSurfaceStyle
import com.mutx163.qingyu.app.ForuiTheme
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * settings 落盘口径与 Dart 的对拍（只锁这三处真差异 + 合并写不误删）。
 *
 * Dart 取证：
 * - `lib/models/settings/timetable_settings_extensions.dart:61-80`（`AppFontMode` 落盘串是
 *   下划线，不是枚举名）；
 * - `lib/models/settings/timetable_settings_enums.dart:87-92`（`ForuiTheme` 读侧回落 blue）；
 * - `lib/models/settings/timetable_settings_extensions.dart:332-349`（卡片表面旧串迁移）。
 */
class TimetableSettingsDartParityTest {

    private fun storeOf(initial: Map<String, String> = emptyMap()): Pair<InMemoryKeyValueStore, TimetableStore> {
        val raw = InMemoryKeyValueStore(initial)
        return raw to TimetableStore(raw)
    }

    private fun json(text: String): Map<String, Any?> =
        MiniJson.parse(text) as Map<String, Any?>

    @Test
    fun appFontModeUsesDartDiskValuesNotEnumNames() {
        // Dart `AppFontMode.miSans.value == 'mi_sans'`（extensions:63）。
        assertEquals(AppFontMode.MI_SANS, AppFontMode.fromValue("mi_sans"))
        assertEquals(AppFontMode.SANS_SERIF, AppFontMode.fromValue("sans_serif"))
        assertEquals(AppFontMode.HARMONY_OS, AppFontMode.fromValue("harmony_os"))
        assertEquals(AppFontMode.OPPO_SANS, AppFontMode.fromValue("oppo_sans"))
        assertEquals(AppFontMode.PING_FANG, AppFontMode.fromValue("ping_fang"))
        assertEquals(AppFontMode.NOTO_SANS, AppFontMode.fromValue("noto_sans"))
        // 枚举名不是磁盘值 ⇒ 与 Dart 一样回落 system。
        assertEquals(AppFontMode.SYSTEM, AppFontMode.fromValue("miSans"))

        val (raw, store) = storeOf()
        TimetableSettingsModelStore(store).save(
            TimetableSettingsModel.fromJson(mapOf("appFontMode" to "mi_sans")),
        )
        val onDisk = json(raw.getString(TimetableStore.KEY_SETTINGS)!!)
        assertEquals("mi_sans", onDisk["appFontMode"])
        assertTrue("驼峰串不能出现在磁盘上", onDisk["appFontMode"] != "miSans")
    }

    @Test
    fun foruiThemeMissingOrUnknownFallsBackToBlue() {
        // 构造默认是 miui，但读侧缺键 / 未知值回落 blue（enums:87-92）。
        assertEquals(ForuiTheme.MIUI, TimetableSettingsModel().foruiTheme)
        assertEquals(ForuiTheme.BLUE, TimetableSettingsModel.fromJson(emptyMap()).foruiTheme)
        assertEquals(
            ForuiTheme.BLUE,
            TimetableSettingsModel.fromJson(mapOf("foruiTheme" to "brand-new")).foruiTheme,
        )
        assertEquals(
            ForuiTheme.MIUI,
            TimetableSettingsModel.fromJson(mapOf("foruiTheme" to "miui")).foruiTheme,
        )
    }

    @Test
    fun courseCardSurfaceStyleLegacyStringsFollowDartMigration() {
        // extensions:332-349：translucent→solid；glass / liquidGlass→gaussian。
        assertEquals(
            CourseCardSurfaceStyle.SOLID,
            CourseCardSurfaceStyle.fromValue("translucent"),
        )
        assertEquals(
            CourseCardSurfaceStyle.GAUSSIAN,
            CourseCardSurfaceStyle.fromValue("glass"),
        )
        assertEquals(
            CourseCardSurfaceStyle.GAUSSIAN,
            CourseCardSurfaceStyle.fromValue("liquidGlass"),
        )
        assertEquals(
            CourseCardSurfaceStyle.LIQUID_GLASS,
            CourseCardSurfaceStyle.fromValue("refraction"),
        )
        assertEquals(
            CourseCardSurfaceStyle.SOLID,
            CourseCardSurfaceStyle.fromValue("nope"),
        )
    }

    @Test
    fun embeddedMergeWriteKeepsLocaleAndUnknownKeys() {
        // 档案内嵌已有 appLocaleTag（全局键）与旧的未知键。
        val (_, store) = storeOf()
        store.saveRawProfiles(
            """[{"id":"p1","name":"P1","settings":{
               "semesterStartDate":"2026-09-07","totalWeeks":20,"currentWeek":3,
               "appLocaleTag":"zh_TW","legacyOnly":"keep"}}]""",
        )
        store.saveActiveProfileId("p1")

        // 完整模型写（会显式写 appLocaleTag 等 80+ 键）：合并写不得删掉/冲掉它们。
        TimetableSettingsModelStore(store).save(TimetableSettingsModelStore(store).load())

        val embedded = store.loadSettingsJson()
        assertEquals("zh_TW", embedded["appLocaleTag"])
        assertEquals("keep", embedded["legacyOnly"])

        val mirrored = json(store.rawJson(TimetableStore.KEY_SETTINGS)!!)
        assertEquals("zh_TW", mirrored["appLocaleTag"])
    }

    @Test
    fun topLevelMirrorKeepsUnknownAndGlobalKeysOnModelWrite() {
        // 无档案的旧世界：顶层 mirror 是唯一读源，未知键 + appLocaleTag 都要活下来。
        val (raw, store) = storeOf(
            mapOf(
                TimetableStore.KEY_SETTINGS to
                    """{"semesterStartDate":"2026-09-07","appLocaleTag":"ja","legacyOnlyTop":"keep"}""",
            ),
        )
        TimetableSettingsModelStore(store).save(TimetableSettingsModelStore(store).load())

        val mirrored = json(raw.getString(TimetableStore.KEY_SETTINGS)!!)
        assertEquals("ja", mirrored["appLocaleTag"])
        assertEquals("keep", mirrored["legacyOnlyTop"])
    }
}
