package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「超级岛显示设置 / 提醒时段」读写层的行为测试（F01）。
 *
 * 期望值全部按 Dart 源**手推**，不从 Kotlin 实现里抄：
 * - 键名：`lib/models/timetable_settings.dart:1145-1240`（toJson）；
 * - 默认值 & 回退：同文件 `:1544-1700`（fromJson）；
 * - wire 值：`lib/models/settings/timetable_settings_extensions.dart:140-290`；
 * - 原生消费侧交叉校验：`LiveUpdateScheduler.kt:1610-1770`（它按同名键读）。
 *
 * 四类断言各有分工：
 * 1. **往返**：写下去读回来逐字段相等（回显的前提）；
 * 2. **不越界**：写本页的键不许动盘上别人的键（`timetable_settings` 是 250+ 字段共用对象）；
 * 3. **两档不串**：课中/下课页只写 `liveDuringEnd*`，上课前档一个字节都不许变；
 * 4. **键名/wire 值对拍**：钉死字面量，改一个就会被这条抓住。
 */
class LiveDisplayStoreTest {

    private fun disk(initialJson: String? = null): InMemoryKeyValueStore =
        if (initialJson == null) {
            InMemoryKeyValueStore()
        } else {
            InMemoryKeyValueStore(mapOf("timetable_settings" to initialJson))
        }

    private fun store(raw: KeyValueStore): LiveDisplayStore = LiveDisplayStore(TimetableStore(raw))

    /** 盘上 `timetable_settings` 的原始 JSON 对象（不做模型解析）。 */
    private fun rawJson(raw: KeyValueStore): Map<String, Any?> {
        val text = raw.getString("timetable_settings") ?: return emptyMap()
        @Suppress("UNCHECKED_CAST")
        return MiniJson.tryParse(text) as? Map<String, Any?> ?: emptyMap()
    }

    // ==========================================================
    // 1. 空盘 = Dart 默认值
    // ==========================================================

    @Test
    fun `空盘读显示设置给默认值（上课前档）`() {
        val loaded = store(disk()).loadDisplay(forDuringEnd = false)

        assertEquals(LiveDisplayState(), loaded)
        // 逐个钉一遍易错项，避免「data class 默认值被人顺手改了」也算绿。
        assertTrue(loaded.showCourseName)
        assertTrue(loaded.hidePrefixText)
        assertEquals(LiveCountdownTextStyle.SMART, loaded.countdownTextStyle)
        assertEquals(MiuiIslandLabelStyle.TEXT_ONLY, loaded.miuiIslandLabelStyle)
        assertEquals("#FFFFFF", loaded.miuiIslandLabelFontColor)
        assertEquals(LiveBeforeClassQuickAction.NONE, loaded.beforeClassQuickAction)
        assertEquals(60, loaded.endSecondsCountdownThreshold)
        // null = 全部显示（不是空列表 = 全部隐藏）
        assertNull(loaded.expandedDetailFields)
    }

    @Test
    fun `空盘读课中档 = 跟随上课前档（默认 true）`() {
        val loaded = store(disk()).loadDisplay(forDuringEnd = true)
        assertTrue(loaded.duringEndFollowBeforeClass)
        assertEquals(LiveDisplayState(), loaded)
    }

    @Test
    fun `空盘读提醒时段给默认值`() {
        val loaded = store(disk()).loadReminderTiming()
        assertEquals(ReminderTimingState(), loaded)
        assertTrue(loaded.liveEnableBeforeClass)
        assertEquals(20, loaded.liveShowBeforeClassMinutes)
        assertEquals(0, loaded.liveClassReminderStartMinutes)
        assertEquals(60, loaded.liveEndSecondsCountdownThreshold)
    }

    // ==========================================================
    // 2. 往返（这页「改了不落盘」就是靠它抓的）
    // ==========================================================

    @Test
    fun `显示设置写下去再读回来逐字段相等（上课前档）`() {
        val raw = disk()
        val target = LiveDisplayState(
            showCourseName = false,
            showLocation = false,
            showCountdown = false,
            countdownTextStyle = LiveCountdownTextStyle.SECOND_ONLY_CN,
            showStageText = false,
            useShortName = false,
            hidePrefixText = false,
            duringClassTimeDisplayMode = LiveDuringClassTimeDisplayMode.TOTAL,
            enableMiuiIslandLabelImage = true,
            miuiIslandLabelStyle = MiuiIslandLabelStyle.ICON_AND_TEXT,
            miuiIslandLabelContent = MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION,
            miuiIslandLabelFontColor = "#123456",
            miuiIslandLabelFontWeight = MiuiIslandLabelFontWeight.MEDIUM,
            miuiIslandLabelRenderQuality = MiuiIslandLabelRenderQuality.ULTRA,
            miuiIslandLabelFontSize = 18.5,
            miuiIslandLabelOffsetX = -1.5,
            miuiIslandLabelOffsetY = 2.0,
            miuiIslandLabelLogoPath = "/data/x/logo.png",
            miuiIslandLabelLogoCornerRadius = 3.0,
            miuiIslandExpandedIconMode = MiuiIslandExpandedIconMode.CUSTOM_IMAGE,
            miuiIslandExpandedIconPath = "/data/x/icon.png",
            expandedDetailFields = listOf(
                LiveExpandedDetailField.TIME,
                LiveExpandedDetailField.LOCATION,
            ),
            beforeClassQuickAction = LiveBeforeClassQuickAction.PRIORITY_ONLY,
            beforeClassQuickActionAutoMinutes = 15,
            duringEndFollowBeforeClass = false,
            endSecondsCountdownThreshold = 30,
            promoteDuringClass = false,
        )

        store(raw).saveDisplay(target, forDuringEnd = false)
        // 换一个 store 实例读 = 真的从盘上读，不是读内存缓存。
        val reloaded = store(raw).loadDisplay(forDuringEnd = false)

        assertEquals(target, reloaded)
    }

    @Test
    fun `提醒时段写下去再读回来逐字段相等`() {
        val raw = disk()
        val target = ReminderTimingState(
            liveEnableBeforeClass = false,
            liveEnableDuringClass = false,
            liveEnableBeforeEnd = false,
            liveClassReminderStartMinutes = 15,
            liveShowDuringClassNotification = false,
            livePromoteDuringClass = false,
            liveShowBeforeClassMinutes = 40,
            liveEndSecondsCountdownThreshold = 15,
            liveDuringEndTimeDisplayMode = LiveDuringClassTimeDisplayMode.TOTAL,
        )

        store(raw).saveReminderTiming(target)

        assertEquals(target, store(raw).loadReminderTiming())
    }

    // ==========================================================
    // 3. 写本页的键，不许动盘上别人的键
    // ==========================================================

    @Test
    fun `改显示设置不清掉存档里其它键`() {
        // 盘上先有别的页面/模块的字段（主题、壁纸、同步配置），写完必须原样还在。
        val raw = disk(
            """
            {"themeSeedColor":"#123456","homePageWallpaperPath":"/w.jpg",
             "webdavUrl":"https://x","holidayOverrideEnabled":true,"liveShowLocation":false}
            """.trimIndent(),
        )

        store(raw).saveDisplay(LiveDisplayState(showLocation = true), forDuringEnd = false)

        val after = rawJson(raw)
        // 别人的字段一个不少
        assertEquals("#123456", after["themeSeedColor"])
        assertEquals("/w.jpg", after["homePageWallpaperPath"])
        assertEquals("https://x", after["webdavUrl"])
        assertEquals(true, after["holidayOverrideEnabled"])
        // 本页的键被覆盖
        assertEquals(true, after["liveShowLocation"])
    }

    @Test
    fun `改提醒时段不清掉显示设置的键`() {
        val raw = disk("""{"liveShowCourseName":false,"themeSeedColor":"#abcdef"}""")

        store(raw).saveReminderTiming(ReminderTimingState(liveEnableBeforeClass = false))

        val after = rawJson(raw)
        assertEquals(false, after["liveShowCourseName"])
        assertEquals("#abcdef", after["themeSeedColor"])
        assertEquals(false, after["liveEnableBeforeClass"])
    }

    // ==========================================================
    // 4. 两档不许串（Kotlin 只有一套字段，最容易在这里写错）
    // ==========================================================

    @Test
    fun `课中档写的是 liveDuringEnd 键而不是上课前档`() {
        val raw = disk()

        store(raw).saveDisplay(
            LiveDisplayState(showCourseName = false, showLocation = false, duringEndFollowBeforeClass = false),
            forDuringEnd = true,
        )

        val after = rawJson(raw)
        // 课中档键被写
        assertEquals(false, after["liveDuringEndShowCourseName"])
        assertEquals(false, after["liveDuringEndShowLocation"])
        assertEquals(false, after["liveDuringEndFollowBeforeClass"])
        // 上课前档键**一个都不许出现**
        assertNull(after["liveShowCourseName"])
        assertNull(after["liveShowLocation"])
        assertNull(after["liveShowCountdown"])
        assertNull(after["liveCountdownTextStyle"])
        assertNull(after["liveMiuiIslandLabelStyle"])
    }

    @Test
    fun `上课前档写的是 live 键而不是 liveDuringEnd`() {
        val raw = disk()

        store(raw).saveDisplay(LiveDisplayState(showCourseName = false), forDuringEnd = false)

        val after = rawJson(raw)
        assertEquals(false, after["liveShowCourseName"])
        assertNull(after["liveDuringEndShowCourseName"])
    }

    @Test
    fun `课中档缺键时逐字段回退到上课前档`() {
        // 老存档：只有上课前档写过，课中档那些键本来就不存在。
        val raw = disk(
            """
            {"liveShowCourseName":false,"liveShowLocation":false,"liveUseShortName":false,
             "liveCountdownTextStyle":"minute_second_colon","liveDuringEndFollowBeforeClass":false}
            """.trimIndent(),
        )

        val loaded = store(raw).loadDisplay(forDuringEnd = true)

        assertFalse(loaded.showCourseName)
        assertFalse(loaded.showLocation)
        assertFalse(loaded.useShortName)
        assertEquals(LiveCountdownTextStyle.MINUTE_SECOND_COLON, loaded.countdownTextStyle)
        assertFalse(loaded.duringEndFollowBeforeClass)
        // 没写过的训练照 Dart 默认值
        assertTrue(loaded.showCountdown)
    }

    @Test
    fun `跟随开关为真时课中档等于上课前档`() {
        val raw = disk(
            """
            {"liveShowCourseName":false,"liveUseShortName":false,"liveDuringEndFollowBeforeClass":true,
             "liveDuringEndShowCourseName":true}
            """.trimIndent(),
        )

        val loaded = store(raw).loadDisplay(forDuringEnd = true)

        // 跟随优先：即便课中档自己写了值，也按上课前档显示（Dart `duringEndDisplaySettings`）
        assertFalse(loaded.showCourseName)
        assertFalse(loaded.useShortName)
        assertTrue(loaded.duringEndFollowBeforeClass)
    }

    @Test
    fun `关掉跟随后课中档把当前这组值固化下来`() {
        // 与 Dart 的**故意**差异（见 duringEndPatch KDoc）：
        // Dart 只写 flag，退出再进来会跳回默认值；这里把当时看到的整套写进课中档键。
        val raw = disk("""{"liveShowCourseName":false,"liveUseShortName":false}""")
        val store = store(raw)

        val current = store.loadDisplay(forDuringEnd = true)
        assertTrue(current.duringEndFollowBeforeClass)
        store.saveDisplay(current.copy(duringEndFollowBeforeClass = false), forDuringEnd = true)

        val reloaded = store(raw).loadDisplay(forDuringEnd = true)
        assertFalse(reloaded.duringEndFollowBeforeClass)
        assertFalse(reloaded.showCourseName)
        assertFalse(reloaded.useShortName)
    }

    // ==========================================================
    // 5. 键名与 wire 值对拍（手抄自 Dart，不是从实现抄）
    // ==========================================================

    @Test
    fun `上课前档键名与 Dart toJson 逐字一致`() {
        val patch = LiveDisplayCodec.beforeClassPatch(LiveDisplayState())

        val expected = setOf(
            "liveShowCourseName",
            "liveShowLocation",
            "liveShowCountdown",
            "liveCountdownTextStyle",
            "liveShowStageText",
            "liveUseShortName",
            "liveHidePrefixText",
            "liveDuringClassTimeDisplayMode",
            "liveEnableMiuiIslandLabelImage",
            "liveMiuiIslandLabelStyle",
            "liveMiuiIslandLabelContent",
            "liveMiuiIslandLabelFontColor",
            "liveMiuiIslandLabelFontWeight",
            "liveMiuiIslandLabelRenderQuality",
            "liveMiuiIslandLabelFontSize",
            "liveMiuiIslandLabelOffsetX",
            "liveMiuiIslandLabelOffsetY",
            "liveMiuiIslandLabelLogoPath",
            "liveMiuiIslandLabelLogoCornerRadius",
            "liveMiuiIslandExpandedIconMode",
            "liveMiuiIslandExpandedIconPath",
            "liveExpandedDetailFields",
            "liveBeforeClassQuickAction",
            "liveBeforeClassQuickActionAutoMinutes",
            "liveDuringEndFollowBeforeClass",
            "liveEndSecondsCountdownThreshold",
            "livePromoteDuringClass",
        )

        assertEquals(expected, patch.keys)
    }

    @Test
    fun `课中档键名与 Dart toJson 逐字一致`() {
        val patch = LiveDisplayCodec.duringEndPatch(LiveDisplayState())

        val expected = setOf(
            "liveDuringEndShowCourseName",
            "liveDuringEndShowLocation",
            "liveDuringEndShowCountdown",
            "liveDuringEndCountdownTextStyle",
            "liveDuringEndShowStageText",
            "liveDuringEndUseShortName",
            "liveDuringEndHidePrefixText",
            // ⚠️ 课中档的时间显示键不带第二次 DuringClass，Dart `:1630` 与原生调度器都按这个读。
            "liveDuringEndTimeDisplayMode",
            "liveDuringEndEnableMiuiIslandLabelImage",
            "liveDuringEndMiuiIslandLabelStyle",
            "liveDuringEndMiuiIslandLabelContent",
            "liveDuringEndMiuiIslandLabelFontColor",
            "liveDuringEndMiuiIslandLabelFontWeight",
            "liveDuringEndMiuiIslandLabelRenderQuality",
            "liveDuringEndMiuiIslandLabelFontSize",
            "liveDuringEndMiuiIslandLabelOffsetX",
            "liveDuringEndMiuiIslandLabelOffsetY",
            "liveDuringEndMiuiIslandLabelLogoPath",
            "liveDuringEndMiuiIslandLabelLogoCornerRadius",
            "liveDuringEndMiuiIslandExpandedIconMode",
            "liveDuringEndMiuiIslandExpandedIconPath",
            "liveDuringEndExpandedDetailFields",
            "liveDuringEndFollowBeforeClass",
            "liveEndSecondsCountdownThreshold",
            "livePromoteDuringClass",
        )

        assertEquals(expected, patch.keys)
        // 课中档绝不许出现上课前档的键
        assertFalse(patch.containsKey("liveShowCourseName"))
        assertFalse(patch.containsKey("liveDuringClassTimeDisplayMode"))
    }

    @Test
    fun `提醒时段键名与 Dart toJson 逐字一致`() {
        val patch = LiveDisplayCodec.reminderTimingPatch(ReminderTimingState())

        val expected = setOf(
            "liveEnableBeforeClass",
            "liveEnableDuringClass",
            "liveEnableBeforeEnd",
            "liveClassReminderStartMinutes",
            "liveShowDuringClassNotification",
            "livePromoteDuringClass",
            "liveShowBeforeClassMinutes",
            "liveEndSecondsCountdownThreshold",
            "liveDuringEndTimeDisplayMode",
        )

        assertEquals(expected, patch.keys)
    }

    @Test
    fun `倒计时格式的 12 个磁盘值逐字对拍`() {
        // 手抄自 `timetable_settings_extensions.dart:153-170`
        val expected = mapOf(
            LiveCountdownTextStyle.SMART to "smart",
            LiveCountdownTextStyle.SMART_MIN_S to "smart_min_s",
            LiveCountdownTextStyle.MINUTE_SECOND_CN to "minute_second_cn",
            LiveCountdownTextStyle.MINUTE_SECOND_COLON to "minute_second_colon",
            LiveCountdownTextStyle.MINUTE_SECOND_MIN_S to "minute_second_min_s",
            LiveCountdownTextStyle.MINUTE_SECOND_MIN_SLASH_S to "minute_second_min_slash_s",
            LiveCountdownTextStyle.MINUTE_ONLY_CN to "minute_only_cn",
            LiveCountdownTextStyle.MINUTE_ONLY_MIN to "minute_only_min",
            LiveCountdownTextStyle.MINUTE_ONLY_SLASH to "minute_only_slash",
            LiveCountdownTextStyle.SECOND_ONLY_CN to "second_only_cn",
            LiveCountdownTextStyle.SECOND_ONLY_SHORT to "second_only_short",
            LiveCountdownTextStyle.SECOND_ONLY_SLASH to "second_only_slash",
        )

        assertEquals(LiveCountdownTextStyle.entries.size, expected.size)
        for ((style, wire) in expected) {
            assertEquals(wire, style.wireValue())
        }
    }

    @Test
    fun `其余枚举的磁盘值逐字对拍`() {
        assertEquals(
            mapOf(
                MiuiIslandLabelStyle.TEXT_ONLY to "text_only",
                MiuiIslandLabelStyle.ICON_AND_TEXT to "icon_and_text",
            ),
            MiuiIslandLabelStyle.entries.associateWith { it.wireValue() },
        )
        assertEquals(
            mapOf(
                MiuiIslandLabelContent.COURSE_NAME to "course_name",
                MiuiIslandLabelContent.LOCATION to "location",
                MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION to "course_name_and_location",
            ),
            MiuiIslandLabelContent.entries.associateWith { it.wireValue() },
        )
        assertEquals(
            mapOf(
                MiuiIslandLabelFontWeight.REGULAR to "regular",
                MiuiIslandLabelFontWeight.MEDIUM to "medium",
                MiuiIslandLabelFontWeight.BOLD to "bold",
            ),
            MiuiIslandLabelFontWeight.entries.associateWith { it.wireValue() },
        )
        assertEquals(
            mapOf(
                MiuiIslandLabelRenderQuality.STANDARD to "standard",
                MiuiIslandLabelRenderQuality.HIGH to "high",
                MiuiIslandLabelRenderQuality.ULTRA to "ultra",
            ),
            MiuiIslandLabelRenderQuality.entries.associateWith { it.wireValue() },
        )
        assertEquals(
            mapOf(
                MiuiIslandExpandedIconMode.APP_ICON to "app_icon",
                MiuiIslandExpandedIconMode.CUSTOM_IMAGE to "custom_image",
                MiuiIslandExpandedIconMode.HIDDEN to "hidden",
            ),
            MiuiIslandExpandedIconMode.entries.associateWith { it.wireValue() },
        )
        assertEquals(
            mapOf(
                LiveBeforeClassQuickAction.NONE to "none",
                LiveBeforeClassQuickAction.SILENT to "silent",
                LiveBeforeClassQuickAction.DO_NOT_DISTURB to "do_not_disturb",
                LiveBeforeClassQuickAction.PRIORITY_ONLY to "priority_only",
                LiveBeforeClassQuickAction.BOTH to "both",
            ),
            LiveBeforeClassQuickAction.entries.associateWith { it.wireValue() },
        )
    }

    // ==========================================================
    // 6. 展开详情字段的三态语义
    // ==========================================================

    @Test
    fun `展开字段 缺键是全显示 空表是全隐藏`() {
        assertNull(store(disk()).loadDisplay(false).expandedDetailFields)
        assertEquals(emptyList<LiveExpandedDetailField>(), store(disk("""{"liveExpandedDetailFields":[]}""")).loadDisplay(false).expandedDetailFields)
        assertEquals(
            listOf(LiveExpandedDetailField.STAGE, LiveExpandedDetailField.NOTE),
            store(disk("""{"liveExpandedDetailFields":["stage","note"]}""")).loadDisplay(false).expandedDetailFields,
        )
    }

    @Test
    fun `展开字段认不出的项跳过 其余顺序不变`() {
        val loaded = store(
            disk("""{"liveExpandedDetailFields":["time","未知字段","note"]}"""),
        ).loadDisplay(false)

        assertEquals(
            listOf(LiveExpandedDetailField.TIME, LiveExpandedDetailField.NOTE),
            loaded.expandedDetailFields,
        )
    }

    @Test
    fun `课中档展开字段是脏类型时仍回退到上课前档`() {
        // 审核发现的等价性边界：Dart 的 `??` 在「解析成列表」之后
        // （`lenientStringList(dur) ?? lenientStringList(before)`），所以课中档那个键
        // 存在但不是列表时，必须继续回退。写成「先取原始值再 ?:」会在这里丢掉回退，
        // 页面上变成「全部显示」——用户的顺序设置看起来丢了。
        val raw = disk(
            """
            {"liveExpandedDetailFields":["time"],
             "liveDuringEndExpandedDetailFields":"不是列表",
             "liveDuringEndFollowBeforeClass":false}
            """.trimIndent(),
        )

        val loaded = store(raw).loadDisplay(forDuringEnd = true)

        assertEquals(listOf(LiveExpandedDetailField.TIME), loaded.expandedDetailFields)
    }

    @Test
    fun `展开字段写的也是 wireValue 字符串`() {
        val raw = disk()
        store(raw).saveDisplay(
            LiveDisplayState(expandedDetailFields = listOf(LiveExpandedDetailField.PROGRESS)),
            forDuringEnd = false,
        )
        @Suppress("UNCHECKED_CAST")
        val list = rawJson(raw)["liveExpandedDetailFields"] as List<Any?>
        assertEquals(listOf<Any?>("progress"), list)
    }

    // ==========================================================
    // 7. 提醒时段：开关迁移口径 + 坏值
    // ==========================================================

    @Test
    fun `课中与下课提醒任一为真则两个字段都为真`() {
        // Dart `:1551-1560`：同一个开关控制两个字段，只留一边为 true 会让界面与逻辑打架。
        val onlyBeforeEnd = store(disk("""{"liveEnableDuringClass":false,"liveEnableBeforeEnd":true}"""))
            .loadReminderTiming()
        assertTrue(onlyBeforeEnd.liveEnableDuringClass)
        assertTrue(onlyBeforeEnd.liveEnableBeforeEnd)

        val onlyDuringClass = store(disk("""{"liveEnableDuringClass":true,"liveEnableBeforeEnd":false}"""))
            .loadReminderTiming()
        assertTrue(onlyDuringClass.liveEnableDuringClass)
        assertTrue(onlyDuringClass.liveEnableBeforeEnd)

        val bothOff = store(disk("""{"liveEnableDuringClass":false,"liveEnableBeforeEnd":false}"""))
            .loadReminderTiming()
        assertFalse(bothOff.liveEnableDuringClass)
        assertFalse(bothOff.liveEnableBeforeEnd)
    }

    @Test
    fun `坏值退回默认值而不是崩`() {
        val raw = disk(
            """
            {"liveShowCourseName":"yes","liveMiuiIslandLabelFontSize":"abc",
             "liveEndSecondsCountdownThreshold":null,"liveCountdownTextStyle":"没有这个档",
             "liveMiuiIslandLabelStyle":42}
            """.trimIndent(),
        )

        val loaded = store(raw).loadDisplay(forDuringEnd = false)

        // "yes" 不是 bool（Dart lenientBool 只认 true/false）⇒ 默认 true
        assertTrue(loaded.showCourseName)
        // "abc" 转不成 double ⇒ 默认 14
        assertEquals(14.0, loaded.miuiIslandLabelFontSize, 0.0)
        // null ⇒ 默认 60
        assertEquals(60, loaded.endSecondsCountdownThreshold)
        // 未知档位 ⇒ SMART
        assertEquals(LiveCountdownTextStyle.SMART, loaded.countdownTextStyle)
        // 非字符串 ⇒ toString "42" 也认不出 ⇒ TEXT_ONLY
        assertEquals(MiuiIslandLabelStyle.TEXT_ONLY, loaded.miuiIslandLabelStyle)
    }

    @Test
    fun `timetable_settings 不是 JSON 对象时按空盘处理`() {
        val raw = InMemoryKeyValueStore(mapOf("timetable_settings" to "not json"))

        val loaded = store(raw).loadDisplay(forDuringEnd = false)

        assertEquals(LiveDisplayState(), loaded)
    }
}
