package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.app.CourseCardSurfaceStyle
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 性能设置快照模型测试（源：`lib/logging/performance_settings_snapshot.dart`，340 行）。
 *
 * 期望值**不从实现里抄**，全部从 Dart 源手推：
 * - 键名与值编码：`_settingsDerivedSnapshot`（:98-222）逐行；
 * - `cardTextFields` 的拼接顺序与 `'none'` 兜底（:323-335）；
 * - `buildMode` 三值（:233-235）；
 * - `reason` 挂在 extras 上（:290-291）；
 * - 指纹比较（:266-272）。
 *
 * 最关键的一条是 [dartKeyInventoryIsFullyAccountedFor]：它把 Dart 的**全部键**硬编码在
 * 测试里，断言「已发出的键 + PENDING 登记的键」正好等于这张表。少一条 = 悄悄漏采，
 * 多一条 = 编了一个 Dart 没有的键，两者都会红。
 */
class PerformanceSettingsSnapshotTest {

    private fun core(sectionCount: Int = 12): TimetableSettings = TimetableSettings(
        sections = (1..sectionCount).map { index ->
            SectionTime(startTime = "%02d:00".format(index), endTime = "%02d:45".format(index))
        },
    )

    /** Dart `_settingsDerivedSnapshot` 的全部键，按 Dart 源顺序（:98-222）。 */
    private val dartDerivedKeys = listOf(
        "glassMode", "blurEnabled",
        "surfaceHomeBand", "surfaceSubpageHeader", "surfaceDock",
        "surfaceSheetDialog", "surfaceSelectSheet", "surfacePopup", "surfacePickerButtons",
        "surfaceCourseCard", "courseCardEffective",
        "lgDock", "lgPreset", "lgTuningSource",
        "lgRefraction", "lgRefractionBand", "lgRefractionEdgePow", "lgDispersion",
        "lgRimStrength", "lgRimWidth", "lgBlurSigma", "lgTintAlpha",
        "lgDarkTuningSource", "lgLinkDark", "lgDarkBoost",
        "lgDarkBlurSigma", "lgDarkRimStrength", "lgDarkDispersion", "lgDarkTintAlpha",
        "ccTuningSource", "ccPreset",
        "ccRefraction", "ccRefractionBand", "ccRefractionEdgePow", "ccDispersion",
        "ccRimStrength", "ccRimWidth", "ccBlurSigma", "ccTintAlpha",
        "homeBandGlassMaterial", "timeColumnBlur", "backdropFollowsWeekPager",
        "themeMode", "foruiTheme", "seedColor", "fontMode", "fontWeight", "textScale",
        "pageTransitionSpeed", "localeTag",
        "backgroundFill", "pageBackgroundColor",
        "wallpaperAlignX", "wallpaperAlignY", "wallpaperScale", "wallpaperBlurSigma",
        "backgroundScope", "backgroundScopeRegions",
        "courseCardStyle", "useUnifiedCardColor", "unifiedCardColor",
        "sectionHeight", "sectionCount", "autoFitSectionHeight",
        "compactFontSize", "courseCardFontSize", "courseCardGap",
        "timeColumnWidthMode", "courseSpacingMode", "hideWeekends", "showConflictBadge",
        "conflictCardOpacity", "floatButtonOpacity", "cardTextFields",
        "navigationForm", "menuStyle",
    )

    /** Dart `_environmentSnapshot` 的全部键（:231-247）。 */
    private val dartEnvironmentKeys = listOf(
        "buildMode", "systemTransitionScale", "userTransitionSpeed",
        "transitionDurationMs", "wallpaperConfigured", "wallpaperUsable",
    )

    @Test
    fun dartKeyInventoryIsFullyAccountedFor() {
        val pending = PerformanceSnapshot.PENDING_DART_KEYS.keys.toList()

        // 无重复。
        assertEquals(
            PerformanceSnapshot.EMITTED_DERIVED_KEYS.size,
            PerformanceSnapshot.EMITTED_DERIVED_KEYS.toSet().size,
        )
        assertEquals(pending.size, pending.toSet().size)

        // 已发出的键必须是 Dart 有的键（不许自创）。
        assertTrue(dartDerivedKeys.containsAll(PerformanceSnapshot.EMITTED_DERIVED_KEYS))
        assertTrue(dartEnvironmentKeys.containsAll(PerformanceSnapshot.EMITTED_ENVIRONMENT_KEYS))

        // 已发出 + 待接 = Dart 全部键（不重复、不遗漏）。
        val coveredDerived = PerformanceSnapshot.EMITTED_DERIVED_KEYS.toSet() +
            pending.filter { dartDerivedKeys.contains(it) }.toSet()
        assertEquals(dartDerivedKeys.toSet(), coveredDerived)

        val coveredEnvironment = PerformanceSnapshot.EMITTED_ENVIRONMENT_KEYS.toSet() +
            pending.filter { dartEnvironmentKeys.contains(it) }.toSet()
        assertEquals(dartEnvironmentKeys.toSet(), coveredEnvironment)

        // 待接的键必须都写了「缺什么」，空串等于没解释。
        PerformanceSnapshot.PENDING_DART_KEYS.forEach { (key, why) ->
            assertTrue("$key 缺少待接原因", why.isNotBlank())
        }
    }

    @Test
    fun emittedKeysKeepDartOrder() {
        val derived = PerformanceSnapshot.buildSettingsDerivedSnapshot(
            TimetableSettingsModel(),
            core(),
        )
        // 顺序参与指纹比较（Dart 比的是整串 JSON），所以必须与 Dart 序一致。
        assertEquals(PerformanceSnapshot.EMITTED_DERIVED_KEYS, derived.keys.toList())
        assertEquals(
            PerformanceSnapshot.EMITTED_ENVIRONMENT_KEYS,
            PerformanceSnapshot.buildEnvironmentSnapshot("debug").keys.toList(),
        )
    }

    @Test
    fun enumValuesUseDartNamesNotDiskValues() {
        val model = TimetableSettingsModel(
            courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
            homeNavigationForm = HomeNavigationForm.GLASS_DOCK,
        )
        val snapshot = PerformanceSnapshot.buildSettingsDerivedSnapshot(model, core())

        // Dart 取 `.name`：液态玻璃是 liquidGlass，磁盘值才是 refraction（:1260 注释）。
        assertEquals("liquidGlass", snapshot["courseCardStyle"])
        // Dart 取 `.name`：glassDock；磁盘值是 glass_dock。
        assertEquals("glassDock", snapshot["navigationForm"])
        // 平面档同理。
        assertEquals(
            "solid",
            PerformanceSnapshot.buildSettingsDerivedSnapshot(TimetableSettingsModel(), core())[
                "courseCardStyle"
            ],
        )
    }

    @Test
    fun sectionCountComesFromCoreSectionsAndModeUsesValue() {
        val snapshot = PerformanceSnapshot.buildSettingsDerivedSnapshot(
            TimetableSettingsModel(homeMenuStyle = com.mutx163.qingyu.app.HomeMenuStyle.GRID),
            core(sectionCount = 9),
        )
        // Dart `sectionCount => sections.length`（:2479）。
        assertEquals(9, snapshot["sectionCount"])
        assertEquals("grid", snapshot["menuStyle"])
    }

    @Test
    fun themeModeFontModeAndTransitionSpeedUseDartValueEncoding() {
        val model = TimetableSettingsModel(
            appThemeMode = com.mutx163.qingyu.app.AppThemeMode.DARK,
            appFontMode = com.mutx163.qingyu.app.AppFontMode.MI_SANS,
            appFontWeight = 500,
            appTextScale = 1.25,
            pageTransitionSpeed = 1.5,
            appLocaleTag = "zh_TW",
            themeSeedColor = "#EC003F",
            foruiTheme = com.mutx163.qingyu.app.ForuiTheme.VIOLET,
        )
        val snapshot = PerformanceSnapshot.buildSettingsDerivedSnapshot(model, core())

        assertEquals("dark", snapshot["themeMode"])
        assertEquals("miSans", snapshot["fontMode"])
        assertEquals(500, snapshot["fontWeight"])
        assertEquals(1.25, snapshot["textScale"])
        assertEquals(1.5, snapshot["pageTransitionSpeed"])
        assertEquals("zh_TW", snapshot["localeTag"])
        assertEquals("#EC003F", snapshot["seedColor"])
        assertEquals("violet", snapshot["foruiTheme"])
    }

    @Test
    fun cardTextFieldsFollowsDartOrderAndNoneFallback() {
        // 全关 → none（Dart `enabled.isEmpty ? 'none'`）。
        assertEquals(
            "none",
            PerformanceSnapshot.buildCardTextFields(
                TimetableSettingsModel(
                    courseCardShowName = false,
                    courseCardShowTeacher = false,
                    courseCardShowLocation = false,
                    courseCardShowTime = false,
                    courseCardShowTimeLabels = false,
                    courseCardShowWeeks = false,
                    courseCardShowDescription = false,
                    weatherShowOnWeekCard = false,
                ),
            ),
        )

        // 默认值：name,teacher,location,timeLabels + weather（week 卡默认显示天气）。
        assertEquals(
            "name,teacher,location,timeLabels,weather",
            PerformanceSnapshot.buildCardTextFields(TimetableSettingsModel()),
        )

        // 全开 → Dart 的 if 顺序，weather 在最后（它不在 courseCard* 家族里）。
        assertEquals(
            "name,teacher,location,time,timeLabels,weeks,description,weather",
            PerformanceSnapshot.buildCardTextFields(
                TimetableSettingsModel(
                    courseCardShowTime = true,
                    courseCardShowWeeks = true,
                    courseCardShowDescription = true,
                ),
            ),
        )
    }

    @Test
    fun extrasCarrySnapshotPlusReason() {
        val extras = PerformanceSnapshot.buildExtras(
            TimetableSettingsModel(),
            core(),
            buildMode = "profile",
            reason = PerformanceSnapshot.REASON_MANUAL_EXPORT,
        )
        // 「设置快照」那一行用的就是 manualExport（Dart settings_diagnostics.dart:103-106）。
        assertEquals("manualExport", extras["reason"])
        assertEquals("profile", extras["buildMode"])
        // extras 是「推导部分 + 环境部分 + reason」，推导键一条不少。
        assertTrue(extras.keys.containsAll(PerformanceSnapshot.EMITTED_DERIVED_KEYS))
        assertEquals(
            PerformanceSnapshot.EMITTED_DERIVED_KEYS.size +
                PerformanceSnapshot.EMITTED_ENVIRONMENT_KEYS.size + 1,
            extras.size,
        )
    }

    @Test
    fun fingerprintSeesSettingChanges() {
        val base = TimetableSettingsModel()
        // 一级：改了会掉帧的设置 → 必须报「变了」。
        assertTrue(
            PerformanceSnapshot.shouldLogChange(
                base,
                core(),
                base.copy(sectionHeight = 80.0),
                core(),
            ),
        )
        // 二级：什么都没改 → 不许重复打日志。
        assertFalse(
            PerformanceSnapshot.shouldLogChange(base, core(), base.copy(), core()),
        )
        // 三级：节次表变了（`sectionCount` 在推导部分里）→ 也要报。
        // 反过来钉住「快照确实读到了 core 的节次」这件事，而不是只看显示设置。
        assertTrue(
            PerformanceSnapshot.shouldLogChange(base, core(12), base, core(9)),
        )
    }

    @Test
    fun logCategoryAndTagMatchDartLiterals() {
        // Dart `kPerformanceSnapshotCategory` / `kPerformanceSnapshotTag` / message 逐字。
        assertEquals("debug_snapshot", PerformanceSnapshot.CATEGORY)
        assertEquals("[settings-snapshot]", PerformanceSnapshot.TAG)
        assertEquals("render performance settings snapshot", PerformanceSnapshot.MESSAGE)
    }
}
