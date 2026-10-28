package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [TimetableSettingsModel] 的读口径 / 写口径 / 合并写测试。
 *
 * 期望值全部来自 Dart `lib/models/timetable_settings.dart` 的 `fromJson`（行号写在断言旁），
 * 不是从实现里抄的。三条最容易错的：
 * - `themeSeedColor` 缺键回落 **`#2563EB`**（:1696），不是构造默认 `#3482FF`（:889）；
 * - `linkCourseCardColors` 为真时**详情字色被标题字色覆盖**（:1304-1311）；
 * - `appFontWeight` / `appTextScale` / `pageTransitionSpeed` / 冲突透明度读侧都有 **clamp / 规范化**。
 */
class TimetableSettingsModelTest {

    private fun storeOf(initial: Map<String, String> = emptyMap()): Pair<InMemoryKeyValueStore, TimetableSettingsModelStore> {
        val raw = InMemoryKeyValueStore(initial)
        return raw to TimetableSettingsModelStore(TimetableStore(raw))
    }

    private fun json(text: String): Map<String, Any?> =
        MiniJson.parse(text) as Map<String, Any?>

    // ---------- 缺键回落（逐键对齐 Dart fromJson） ----------

    @Test
    fun missingKeysFallBackToDartFromJsonDefaults() {
        val model = TimetableSettingsModel.fromJson(emptyMap())

        assertEquals("", model.appLocaleTag) // :1474
        assertEquals(1.0, model.pageTransitionSpeed, 0.0) // :1533
        assertTrue(model.enableHaptics) // :1532
        assertFalse(model.homePullQuickImportEnabled) // :1537
        assertTrue(model.enableHolidayMarking) // :1397
        assertEquals(AppThemeMode.SYSTEM, model.appThemeMode) // :1464
        assertEquals(AppFontMode.SYSTEM, model.appFontMode) // :1467
        assertEquals(400, model.appFontWeight) // :1468 → kAppFontWeightDefault
        assertEquals(1.0, model.appTextScale, 0.0) // :1471 → kAppTextScaleDefault
        assertEquals(ForuiTheme.MIUI, model.foruiTheme) // :1697
        // 坑：构造默认是 #3482FF，读侧缺键默认是 #2563EB。
        assertEquals("#2563EB", model.themeSeedColor)
        assertNull(model.themeCheckpointName)
        assertNull(model.themeCheckpointConfig)
        assertTrue(model.savedThemes.isEmpty())
        assertTrue(model.courseCardShowName) // :1405
        assertTrue(model.courseCardShowTeacher) // :1406
        assertTrue(model.courseCardShowLocation) // :1407
        assertFalse(model.courseCardShowTime) // :1409
        assertTrue(model.courseCardShowTimeLabels) // :1410
        assertFalse(model.courseCardShowWeeks) // :1412
        assertFalse(model.courseCardShowDescription) // :1413
        assertEquals(CourseCardSurfaceStyle.SOLID, model.courseCardSurfaceStyle)
        assertEquals(CourseCardVerticalAlign.CENTER, model.courseCardVerticalAlign) // :1426
        assertEquals(CourseCardHorizontalAlign.CENTER, model.courseCardHorizontalAlign) // :1429
        assertEquals(9.0, model.courseCardFontSize, 0.0) // :1432
        assertEquals(9.0, model.compactFontSize, 0.0) // :1386
        assertFalse(model.timetableUseUnifiedCardColor) // :1726
        assertEquals("#2563EB", model.timetableUnifiedCardColor) // :1728
        assertTrue(model.showConflictBadgeOnTimetable) // :1400
        assertEquals(0.70, model.timetableConflictCourseOpacity, 0.0) // :1402
        assertTrue(model.linkCourseCardColors) // :1296
        assertEquals("#FFFFFF", model.courseCardTitleColorLight) // :1298/:283
        assertEquals("#FFFFFF", model.courseCardTitleColorDark)
        assertEquals("#FFFFFF", model.courseCardDetailColorLight) // 联动为真 → 取标题色
        assertEquals("#FFFFFF", model.courseCardDetailColorDark)
        // ---- batch 2：课表显示其余 ----
        assertEquals(68.0, model.sectionHeight, 0.0) // :1385
        assertFalse(model.timetableAutoFitSectionHeight) // :1387
        assertFalse(model.timetableShowNonCurrentWeekCourses) // :1398
        assertTrue(model.weekGridShowExams) // :1416
        assertTrue(model.weekGridShowSchedules) // :1417
        assertTrue(model.weatherShowOnDayCard) // :1415
        assertTrue(model.weatherShowOnWeekCard) // :1419
        assertTrue(model.weatherShowOnSheet) // :1420
        assertTrue(model.weatherShowPhenomenon) // :1421
        assertTrue(model.weatherShowTemperature) // :1422
        assertFalse(model.weatherShowProbability) // :1424
        assertEquals(TimetableTimeColumnWidthMode.NARROW, model.timetableTimeColumnWidthMode)
        assertEquals(TimetableCourseSpacingMode.NARROW, model.timetableCourseSpacingMode)
        assertEquals(1.25, model.timetableCourseCardGap, 0.0) // :1436-1440 窄档
        assertEquals(SectionTimeDisplayMode.START_AND_END, model.timetableSectionTimeDisplayMode)
        assertFalse(model.timetableHideWeekends) // :1531
        assertEquals(1, model.timetableLastViewedDayOfWeek) // :1521
        assertFalse(model.coupleTimetableOverlayEnabled) // :1526
        assertTrue(model.screenshotSharePromptEnabled) // :1539
        assertFalse(model.longPressEmptySlotToAddCourseEnabled) // :1541
        // ---- batch 2：星期栏 / 时间轴字色（:285-290） ----
        assertEquals("#000000", model.weekdayBarFontColorLight)
        assertEquals("#FFFFFF", model.weekdayBarFontColorDark)
        assertEquals("#2563EB", model.weekdayBarAccentColorLight)
        assertEquals("#93C5FD", model.weekdayBarAccentColorDark)
        assertEquals("#757575", model.timeAxisFontColorLight)
        assertEquals("#FFFFFF", model.timeAxisFontColorDark)
    }

    @Test
    fun unknownEnumValuesFallBackToDartDefaults() {
        val model = TimetableSettingsModel.fromJson(
            json(
                """
                {"appThemeMode":"nope","appFontMode":42,"foruiTheme":"brand-new",
                 "courseCardSurfaceStyle":"liquidGlass",
                 "courseCardVerticalAlign":"middle","courseCardHorizontalAlign":"justify"}
                """.trimIndent(),
            ),
        )

        assertEquals(AppThemeMode.SYSTEM, model.appThemeMode)
        // lenientString(42) = "42" → 不是合法值 → system
        assertEquals(AppFontMode.SYSTEM, model.appFontMode)
        assertEquals(ForuiTheme.MIUI, model.foruiTheme)
        // 老字符串 'liquidGlass' 不是磁盘值（磁盘值是 refraction）→ 回落 solid
        assertEquals(CourseCardSurfaceStyle.SOLID, model.courseCardSurfaceStyle)
        assertEquals(CourseCardVerticalAlign.CENTER, model.courseCardVerticalAlign)
        assertEquals(CourseCardHorizontalAlign.CENTER, model.courseCardHorizontalAlign)
    }

    @Test
    fun badTypesFallBackToDefaultsInsteadOfGuessing() {
        val model = TimetableSettingsModel.fromJson(
            json(
                """
                {"enableHaptics":"yes","courseCardShowTime":1,"courseCardFontSize":"abc",
                 "savedThemes":"not-a-list","themeCheckpointConfig":[],
                 "pageTransitionSpeed":"fast","appFontWeight":"heavy"}
                """.trimIndent(),
            ),
        )

        // lenientBool 不猜：'yes' / 1 都不是 bool。
        assertTrue(model.enableHaptics)
        assertFalse(model.courseCardShowTime)
        assertEquals(9.0, model.courseCardFontSize, 0.0)
        assertTrue(model.savedThemes.isEmpty())
        assertNull(model.themeCheckpointConfig)
        assertEquals(1.0, model.pageTransitionSpeed, 0.0)
        assertEquals(400, model.appFontWeight)
    }

    // ---------- 规范化 / clamp（Dart 读侧不是原样返回） ----------

    @Test
    fun appFontWeightIsRoundedAndClamped() {
        // 数字字符串走 tryParse；round 后 clamp 100~900（:1468 / enums:40-45）。
        assertEquals(451, TimetableSettingsModel.normalizeAppFontWeight(450.6))
        assertEquals(900, TimetableSettingsModel.normalizeAppFontWeight(1000.0))
        assertEquals(100, TimetableSettingsModel.normalizeAppFontWeight(50.0))
        assertEquals(400, TimetableSettingsModel.normalizeAppFontWeight(null))
        assertEquals(
            600,
            TimetableSettingsModel.fromJson(json("""{"appFontWeight":"600"}""")).appFontWeight,
        )
    }

    @Test
    fun appTextScaleIsClampedThenRoundedToTwoDecimals() {
        // :1471 / enums:46-51：clamp 0.85~1.6 → toStringAsFixed(2)。
        assertEquals(1.6, TimetableSettingsModel.normalizeAppTextScale(2.0), 0.0)
        assertEquals(0.85, TimetableSettingsModel.normalizeAppTextScale(0.5), 0.0)
        assertEquals(1.23, TimetableSettingsModel.normalizeAppTextScale(1.234), 0.0)
        assertEquals(1.5, TimetableSettingsModel.normalizeAppTextScale(1.5), 0.0)
        assertEquals(1.0, TimetableSettingsModel.normalizeAppTextScale(null), 0.0)
    }

    @Test
    fun pageTransitionSpeedAndConflictOpacityAreClamped() {
        assertEquals(
            2.5,
            TimetableSettingsModel.fromJson(json("""{"pageTransitionSpeed":9.0}""")).pageTransitionSpeed,
            0.0,
        )
        assertEquals(
            0.5,
            TimetableSettingsModel.fromJson(json("""{"pageTransitionSpeed":0.1}""")).pageTransitionSpeed,
            0.0,
        )
        assertEquals(
            1.0,
            TimetableSettingsModel.fromJson(
                json("""{"timetableConflictCourseOpacity":5.0}"""),
            ).timetableConflictCourseOpacity,
            0.0,
        )
        assertEquals(
            0.2,
            TimetableSettingsModel.fromJson(
                json("""{"timetableConflictCourseOpacity":0.0}"""),
            ).timetableConflictCourseOpacity,
            0.0,
        )
    }

    @Test
    fun appLocaleTagIsNormalizedAndFallsBackToLegacyKey() {
        // lib/utils/app_locale_tag.dart:7-17
        assertEquals("", TimetableSettingsModel.normalizeAppLocaleTag(null))
        assertEquals("", TimetableSettingsModel.normalizeAppLocaleTag("system"))
        assertEquals("", TimetableSettingsModel.normalizeAppLocaleTag("   "))
        assertEquals("zh", TimetableSettingsModel.normalizeAppLocaleTag("zh-CN"))
        assertEquals("en", TimetableSettingsModel.normalizeAppLocaleTag("en-US"))
        // 只归一 en_us / zh_cn 两个；其余保留大小写、只把 '-' 换 '_'。
        assertEquals("zh_TW", TimetableSettingsModel.normalizeAppLocaleTag("zh-TW"))
        assertEquals("ja", TimetableSettingsModel.normalizeAppLocaleTag("ja"))

        // 旧键 appLocaleMode 是回落来源（:1474-1477）。
        val legacy = TimetableSettingsModel.fromJson(json("""{"appLocaleMode":"zh-CN"}"""))
        assertEquals("zh", legacy.appLocaleTag)
        // 新键优先。
        val both = TimetableSettingsModel.fromJson(
            json("""{"appLocaleTag":"ja","appLocaleMode":"zh-CN"}"""),
        )
        assertEquals("ja", both.appLocaleTag)
    }

    // ---------- 联动回填 ----------

    @Test
    fun linkedCardColorsOverrideStoredDetailColors() {
        // :1304-1311：联动为真（默认）时详情字色取标题字色，存档里的旧值不读。
        val linked = TimetableSettingsModel.fromJson(
            json(
                """
                {"courseCardTitleColorLight":"#111111","courseCardTitleColorDark":"#222222",
                 "courseCardDetailColorLight":"#000000","courseCardDetailColorDark":"#333333"}
                """.trimIndent(),
            ),
        )

        assertTrue(linked.linkCourseCardColors)
        assertEquals("#111111", linked.courseCardDetailColorLight)
        assertEquals("#222222", linked.courseCardDetailColorDark)
    }

    @Test
    fun unlinkedCardColorsKeepTheirOwnStoredValues() {
        val unlinked = TimetableSettingsModel.fromJson(
            json(
                """
                {"linkCourseCardColors":false,
                 "courseCardTitleColorLight":"#111111","courseCardTitleColorDark":"#222222",
                 "courseCardDetailColorLight":"#000000","courseCardDetailColorDark":"#333333"}
                """.trimIndent(),
            ),
        )

        assertFalse(unlinked.linkCourseCardColors)
        assertEquals("#000000", unlinked.courseCardDetailColorLight)
        assertEquals("#333333", unlinked.courseCardDetailColorDark)
    }

    // ---------- batch 2 专有口径 ----------

    @Test
    fun courseCardGapFallsBackFromSpacingModeRawStringNotAConstant() {
        // :1436-1440：缺键时按 spacingMode 的**原始字符串**推导 —— wide → 2.0，其余 → 1.25。
        assertEquals(
            2.0,
            TimetableSettingsModel.fromJson(json("""{"timetableCourseSpacingMode":"wide"}"""))
                .timetableCourseCardGap,
            0.0,
        )
        assertEquals(
            1.25,
            TimetableSettingsModel.fromJson(json("""{"timetableCourseSpacingMode":"narrow"}"""))
                .timetableCourseCardGap,
            0.0,
        )
        // 坏值 / 缺键都走 1.25 这一支（不是抛、也不是按枚举默认 narrow 之外的别的值）。
        assertEquals(
            1.25,
            TimetableSettingsModel.fromJson(json("""{"timetableCourseSpacingMode":123}"""))
                .timetableCourseCardGap,
            0.0,
        )
        assertEquals(1.25, TimetableSettingsModel.fromJson(emptyMap()).timetableCourseCardGap, 0.0)
        // 显式给了 gap 就以它为准（字符串数字也收）。
        assertEquals(
            4.5,
            TimetableSettingsModel.fromJson(
                json("""{"timetableCourseCardGap":"4.5","timetableCourseSpacingMode":"wide"}"""),
            ).timetableCourseCardGap,
            0.0,
        )
    }

    @Test
    fun lastViewedDayOfWeekIsClampedToOneThroughSeven() {
        assertEquals(
            1,
            TimetableSettingsModel.fromJson(json("""{"timetableLastViewedDayOfWeek":0}"""))
                .timetableLastViewedDayOfWeek,
        )
        assertEquals(
            7,
            TimetableSettingsModel.fromJson(json("""{"timetableLastViewedDayOfWeek":9}"""))
                .timetableLastViewedDayOfWeek,
        )
        assertEquals(
            4,
            TimetableSettingsModel.fromJson(json("""{"timetableLastViewedDayOfWeek":"4"}"""))
                .timetableLastViewedDayOfWeek,
        )
    }

    @Test
    fun sectionTimeDisplayModeUsesDiskValuesAndDefaultsToStartAndEnd() {
        // 磁盘值与枚举名不同名：start_only / start_and_end。
        assertEquals(
            SectionTimeDisplayMode.START_ONLY,
            TimetableSettingsModel.fromJson(json("""{"timetableSectionTimeDisplayMode":"start_only"}"""))
                .timetableSectionTimeDisplayMode,
        )
        assertEquals(
            SectionTimeDisplayMode.HIDDEN,
            TimetableSettingsModel.fromJson(json("""{"timetableSectionTimeDisplayMode":"hidden"}"""))
                .timetableSectionTimeDisplayMode,
        )
        // 未知值回落 startAndEnd（不是枚举第一项 hidden）。
        assertEquals(
            SectionTimeDisplayMode.START_AND_END,
            TimetableSettingsModel.fromJson(json("""{"timetableSectionTimeDisplayMode":"nope"}"""))
                .timetableSectionTimeDisplayMode,
        )
        assertEquals(
            SectionTimeDisplayMode.START_AND_END,
            TimetableSettingsModel.fromJson(emptyMap()).timetableSectionTimeDisplayMode,
        )
        assertEquals(SectionTimeDisplayMode.START_AND_END.value, "start_and_end")
    }

    @Test
    fun timetableDisplayBooleansAndEnumsFollowDartFallbacksOnBadTypes() {
        val model = TimetableSettingsModel.fromJson(
            json(
                """
                {"sectionHeight":"tall","weekGridShowExams":1,"weatherShowProbability":"yes",
                 "timetableTimeColumnWidthMode":42,"timetableHideWeekends":"maybe",
                 "timetableLastViewedDayOfWeek":"x"}
                """.trimIndent(),
            ),
        )

        assertEquals(68.0, model.sectionHeight, 0.0)
        assertTrue(model.weekGridShowExams)
        assertFalse(model.weatherShowProbability)
        assertEquals(TimetableTimeColumnWidthMode.NARROW, model.timetableTimeColumnWidthMode)
        assertFalse(model.timetableHideWeekends)
        assertEquals(1, model.timetableLastViewedDayOfWeek)
    }

    @Test
    fun weekdayAndTimeAxisColorsRoundTripWithDartDefaults() {
        val (_, store) = storeOf()
        val custom = TimetableSettingsModel(
            weekdayBarFontColorLight = "#101010",
            weekdayBarFontColorDark = "#202020",
            weekdayBarAccentColorLight = "#303030",
            weekdayBarAccentColorDark = "#404040",
            timeAxisFontColorLight = "#505050",
            timeAxisFontColorDark = "#606060",
        )

        store.save(custom)

        assertEquals(custom, store.load())
        assertEquals(
            "#000000",
            TimetableSettingsModel.fromJson(emptyMap()).weekdayBarFontColorLight,
        )
    }

    // ---------- 逐键往返 ----------

    @Test
    fun everyFieldSurvivesAWriteReadRoundTrip() {
        val (_, store) = storeOf()
        val original = TimetableSettingsModel(
            appLocaleTag = "zh_TW",
            pageTransitionSpeed = 1.5,
            enableHaptics = false,
            homePullQuickImportEnabled = true,
            enableHolidayMarking = false,
            appThemeMode = AppThemeMode.DARK,
            appFontMode = AppFontMode.MI_SANS,
            appFontWeight = 500,
            appTextScale = 1.25,
            foruiTheme = ForuiTheme.VIOLET,
            themeSeedColor = "#EC003F",
            themeCheckpointName = "我的主题",
            themeCheckpointConfig = mapOf("themeSeedColor" to "#EC003F"),
            savedThemes = listOf(mapOf("id" to "t1", "name" to "夜间")),
            courseCardShowName = false,
            courseCardShowTeacher = false,
            courseCardShowLocation = false,
            courseCardShowTime = true,
            courseCardShowTimeLabels = false,
            courseCardShowWeeks = true,
            courseCardShowDescription = true,
            courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
            courseCardVerticalAlign = CourseCardVerticalAlign.SPACE_EVENLY,
            courseCardHorizontalAlign = CourseCardHorizontalAlign.RIGHT,
            courseCardFontSize = 11.5,
            compactFontSize = 8.5,
            timetableUseUnifiedCardColor = true,
            timetableUnifiedCardColor = "#123456",
            showConflictBadgeOnTimetable = false,
            timetableConflictCourseOpacity = 0.5,
            // 联动关，才能独立往返详情字色。
            linkCourseCardColors = false,
            courseCardTitleColorLight = "#111111",
            courseCardTitleColorDark = "#222222",
            courseCardDetailColorLight = "#333333",
            courseCardDetailColorDark = "#444444",
            // ---- batch 2 ----
            sectionHeight = 88.0,
            timetableAutoFitSectionHeight = true,
            timetableShowNonCurrentWeekCourses = true,
            weekGridShowExams = false,
            weekGridShowSchedules = false,
            weatherShowOnDayCard = false,
            weatherShowOnWeekCard = false,
            weatherShowOnSheet = false,
            weatherShowPhenomenon = false,
            weatherShowTemperature = false,
            weatherShowProbability = true,
            timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.WIDE,
            timetableCourseSpacingMode = TimetableCourseSpacingMode.WIDE,
            timetableCourseCardGap = 3.5,
            timetableSectionTimeDisplayMode = SectionTimeDisplayMode.HIDDEN,
            timetableHideWeekends = true,
            timetableLastViewedDayOfWeek = 7,
            coupleTimetableOverlayEnabled = true,
            screenshotSharePromptEnabled = false,
            longPressEmptySlotToAddCourseEnabled = true,
            weekdayBarFontColorLight = "#0A0A0A",
            weekdayBarFontColorDark = "#0B0B0B",
            weekdayBarAccentColorLight = "#0C0C0C",
            weekdayBarAccentColorDark = "#0D0D0D",
            timeAxisFontColorLight = "#0E0E0E",
            timeAxisFontColorDark = "#0F0F0F",
        )

        store.save(original)
        val loaded = store.load()

        assertEquals(original, loaded)
        // 液态玻璃档磁盘值必须是 refraction（不是 liquidGlass）。
        assertEquals(CourseCardSurfaceStyle.LIQUID_GLASS.value, "refraction")
    }

    @Test
    fun savedThemesAndCheckpointConfigRoundTripVerbatim() {
        val (raw, store) = storeOf()
        val archived = """
            {"savedThemes":[{"id":"t1","name":"夜间","config":{"themeSeedColor":"#000000","nested":{"a":[1,2]}}},
                            "bad-entry",
                            {"id":"t2","name":"日间"}],
             "themeCheckpointConfig":{"themeSeedColor":"#111111","extra":[{"x":1}]}}
        """.trimIndent()

        store.save(TimetableSettingsModel.fromJson(json(archived)))
        val after = json(raw.getString("timetable_settings")!!)

        // 坏条目在读侧丢弃（Dart SavedTheme.listFromJson 口径），其余逐字段原样保留。
        val themes = after["savedThemes"] as List<*>
        assertEquals(2, themes.size)
        val first = themes[0] as Map<*, *>
        assertEquals("t1", first["id"])
        assertEquals("夜间", first["name"])
        val firstConfig = first["config"] as Map<*, *>
        assertEquals("#000000", firstConfig["themeSeedColor"])
        assertEquals("[1,2]", MiniJson.encode((firstConfig["nested"] as Map<*, *>)["a"]))
        assertEquals("t2", (themes[1] as Map<*, *>)["id"])

        val checkpoint = after["themeCheckpointConfig"] as Map<*, *>
        assertEquals("#111111", checkpoint["themeSeedColor"])
        assertEquals("""[{"x":1}]""", MiniJson.encode(checkpoint["extra"]))
    }

    // ---------- 合并写红线 ----------

    @Test
    fun unknownKeysSurviveAModelWrite() {
        val (raw, store) = storeOf(
            mapOf(
                "timetable_settings" to
                    """{"themeSeedColor":"#000000","frostedBlurEnabled":true,
                       "liveShowCourseName":false,"widgetCornerRadius":22,
                       "homePageWallpaperScale":1.4,"deep":{"x":[1,2,3]}}""",
            ),
        )

        store.save(TimetableSettingsModel(appThemeMode = AppThemeMode.DARK, enableHaptics = false))

        val written = json(raw.getString("timetable_settings")!!)
        // 注意：这些必须是**本模型仍不拥有**的键；随着覆盖批次推进要同步换样本，
        // 否则「未知键不丢」这条会退化成「自有键被自己写」的假绿。
        assertEquals(true, written["frostedBlurEnabled"])
        assertEquals(false, written["liveShowCourseName"])
        assertEquals(22, (written["widgetCornerRadius"] as Number).toInt())
        assertEquals(1.4, written["homePageWallpaperScale"])
        assertEquals("""{"x":[1,2,3]}""", MiniJson.encode(written["deep"]))
        // 本模型确实改了它拥有的键。
        assertEquals("dark", written["appThemeMode"])
        assertEquals(false, written["enableHaptics"])
    }

    @Test
    fun explicitNullActuallyClearsTheCheckpointKey() {
        // 合并写下「省略」= 保留旧值，所以 toJsonPatch 必须把 null 显式写出去，
        // 否则用户清掉主题存档后重开又冒出来。
        val (raw, store) = storeOf(
            mapOf("timetable_settings" to """{"themeCheckpointName":"旧主题"}"""),
        )

        store.save(TimetableSettingsModel(themeCheckpointName = null))

        val written = json(raw.getString("timetable_settings")!!)
        assertTrue("键必须显式存在（值 null）", written.containsKey("themeCheckpointName"))
        assertNull(written["themeCheckpointName"])
        assertNull(store.load().themeCheckpointName)
    }

    @Test
    fun ownedKeysAndPatchKeysStayInSync() {
        // 结构守卫：加字段时忘了同步 OWNED_KEYS / toJsonPatch 会被这条抓住。
        val patch = TimetableSettingsModel().toJsonPatch()
        assertEquals(TimetableSettingsModel.OWNED_KEYS.toSet(), patch.keys)
        assertEquals(TimetableSettingsModel.OWNED_KEYS.size, patch.size)
    }

    // ---------- 坏值留档 ----------

    @Test
    fun corruptSettingsJsonIsArchivedAndDefaultsAreReturned() {
        val raw = InMemoryKeyValueStore(mapOf("timetable_settings" to "[1,2,3]"))
        val store = TimetableSettingsModelStore(TimetableStore(raw, nowMicros = { 999L }))

        val model = store.load()

        assertEquals(TimetableSettingsModel(), model)
        assertEquals("[1,2,3]", raw.rawSnapshot()["flutter.timetable_settings_corrupt_backup_999"])
        assertFalse(raw.contains("timetable_settings"))
    }

    @Test
    fun coreFourKeysAreNotOwnedByThisModel() {
        // 所有权划分：core 4 键归 core/TimetableSettings + TimetableStore.saveSettings，
        // 本模型不许碰它们（碰了就会与 core 子集互相覆盖）。
        val owned = TimetableSettingsModel.OWNED_KEYS.toSet()
        assertFalse(owned.contains("sections"))
        assertFalse(owned.contains("activeTimeSchemeId"))
        assertFalse(owned.contains("semesterWeekCount"))
        assertFalse(owned.contains("semesterStartDate"))
        assertFalse(owned.contains("semesterStartDateText"))

        // 反向：core 4 键写进去后，模型读+写一遍不会把它们弄丢。
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_settings" to
                    """{"semesterWeekCount":18,"activeTimeSchemeId":"ts-1",
                       "semesterStartDateText":"2026-09-07"}""",
            ),
        )
        val store = TimetableSettingsModelStore(TimetableStore(raw))
        store.save(store.load().copy(appThemeMode = AppThemeMode.LIGHT))

        val written = json(raw.getString("timetable_settings")!!)
        assertEquals(18, (written["semesterWeekCount"] as Number).toInt())
        assertEquals("ts-1", written["activeTimeSchemeId"])
        assertEquals("2026-09-07", written["semesterStartDateText"])
        assertNotNull(written["appThemeMode"])
    }
}
