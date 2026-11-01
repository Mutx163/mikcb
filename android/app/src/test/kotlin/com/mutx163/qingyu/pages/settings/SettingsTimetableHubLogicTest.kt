package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * `SettingsTimetableHubLogic` 的 JVM 单测：钉住设置首页那五行「读的是真源、不是构造默认值」。
 *
 * 背景：这五行原先全都落回 [SettingsTimetableState] 的默认值（课表名空白、时间模板恒
 * 「未选择」、节假日恒「已开启」、天气恒「未设置」、情侣恒「未绑定」）。单测的写法刻意
 * 让**每一行都给一个与默认值相反的真值**——只要实现退回去写死默认值，对应断言必然红。
 *
 * 期望值全部是「人按 Dart `timetable_settings_screen.dart` 的取值方式手写」的，
 * 不从实现里反抄：
 *
 * | 行 | Dart | 真值 |
 * |---|---|---|
 * | 课表名 | `provider.activeProfile?.name`（:413） | `profiles` 里 `activeProfileId` 命中的那份 |
 * | 时间模板 | `provider.activeTimeScheme?.name`（:433） | `timeSchemes` 里 `activeTimeSchemeId` 命中的那套 |
 * | 节假日 | `settings.enableHolidayMarking`（:447） | 完整设置模型的同名布尔 |
 * | 天气 | `weather?.location?.name`（:493） | 调用方传进来的城市名 |
 * | 情侣 | `provider.hasPartnerBinding`（:602） | 调用方从绑定存储算出的布尔 |
 */
class SettingsTimetableHubLogicTest {

    private val now: LocalDateTime = LocalDateTime.of(2026, 10, 29, 8, 0)

    private fun profile(id: String, name: String): TimetableProfile = TimetableProfile(
        id = id,
        name = name,
        currentWeek = 3,
        createdAt = now,
        lastUsedAt = now,
    )

    private fun scheme(id: String, name: String): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = listOf(SectionTime("08:00", "08:45")),
        createdAt = now,
        updatedAt = now,
    )

    // ------------------------------------------------------------------ 全五行的真值

    @Test
    fun `五行都取真值而不是构造默认值`() {
        val snapshot = TimetableSnapshot(
            profiles = listOf(profile("a", "课表 A"), profile("b", "课表 B")),
            activeProfileId = "b",
            timeSchemes = listOf(scheme("s1", "模板一"), scheme("s2", "模板二")),
            activeTimeSchemeId = "s2",
            settings = TimetableSettings(
                semesterWeekCount = 18,
                semesterStartDate = LocalDateTime.of(2026, 9, 1, 0, 0),
            ),
            currentWeek = 5,
        )

        val state = SettingsTimetableHubLogic.stateOf(
            snapshot = snapshot,
            // 与默认值 true 相反的 false，确保不是写死「已开启」。
            settings = TimetableSettingsModel(enableHolidayMarking = false),
            weatherCityName = "杭州",
            partnerBound = true,
        )

        assertEquals("课表 B", state.activeProfileName)
        assertEquals("模板二", state.activeTimeSchemeName)
        assertFalse(state.holidayMarkingEnabled)
        assertEquals("杭州", state.weatherCityName)
        assertTrue(state.partnerBound)
        // 学期摘要卡也一并跟着快照走（本批不回归）。
        assertEquals(5, state.currentWeek)
        assertEquals(18, state.semesterWeekCount)
        assertEquals(Triple(2026, 9, 1), state.semesterStartDate)
    }

    // ------------------------------------------------------------------ 时间模板

    @Test
    fun `没有激活时间模板时是未选择 不会偷挑第一套`() {
        val snapshot = TimetableSnapshot(
            profiles = listOf(profile("a", "课表 A")),
            activeProfileId = "a",
            timeSchemes = listOf(scheme("s1", "模板一")),
            activeTimeSchemeId = null,
        )

        val state = SettingsTimetableHubLogic.stateOf(
            snapshot = snapshot,
            settings = TimetableSettingsModel(),
        )

        // Dart `activeTimeScheme => _getTimeSchemeById(null) => null` ⇒ 行尾「未选择」。
        assertNull(state.activeTimeSchemeName)
    }

    @Test
    fun `激活 id 指向不存在的模板时也不显示任何模板名`() {
        val snapshot = TimetableSnapshot(
            profiles = listOf(profile("a", "课表 A")),
            activeProfileId = "a",
            timeSchemes = listOf(scheme("s1", "模板一")),
            activeTimeSchemeId = "missing",
        )

        val state = SettingsTimetableHubLogic.stateOf(
            snapshot = snapshot,
            settings = TimetableSettingsModel(),
        )

        assertNull(state.activeTimeSchemeName)
    }

    // ------------------------------------------------------------------ 课表名

    @Test
    fun `激活档案 id 悬空时回落第一份档案名`() {
        val snapshot = TimetableSnapshot(
            profiles = listOf(profile("a", "课表 A"), profile("b", "课表 B")),
            activeProfileId = "missing",
        )

        val state = SettingsTimetableHubLogic.stateOf(
            snapshot = snapshot,
            settings = TimetableSettingsModel(),
        )

        // 仓储的 activeProfile 在装载时就把悬空 id 回落成第一份，这里保持同一口径。
        assertEquals("课表 A", state.activeProfileName)
    }

    @Test
    fun `一份档案都没有时课表名是空的`() {
        val state = SettingsTimetableHubLogic.stateOf(
            snapshot = TimetableSnapshot(),
            settings = TimetableSettingsModel(),
        )

        assertNull(state.activeProfileName)
    }

    // ------------------------------------------------------------------ 节假日开关

    @Test
    fun `节假日开关跟着设置模型走 默认 true 与关过的 false 都能表达`() {
        val snapshot = TimetableSnapshot()

        assertTrue(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(), // 构造默认 true
            ).holidayMarkingEnabled,
        )
        assertFalse(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(enableHolidayMarking = false),
            ).holidayMarkingEnabled,
        )
    }

    // ------------------------------------------------------------------ 天气

    @Test
    fun `没有天气 provider 或城市名为空时保持未设置`() {
        val snapshot = TimetableSnapshot()

        assertNull(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(),
                weatherCityName = null,
            ).weatherCityName,
        )
        assertNull(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(),
                weatherCityName = "   ",
            ).weatherCityName,
        )
    }

    // ------------------------------------------------------------------ 情侣绑定

    @Test
    fun `情侣绑定态按传入的真实绑定结果显示`() {
        val snapshot = TimetableSnapshot()

        assertTrue(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(),
                partnerBound = true,
            ).partnerBound,
        )
        assertFalse(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(),
                partnerBound = false,
            ).partnerBound,
        )
        // 不传 = 没有绑定数据 ⇒ 未绑定（不能默认 true）。
        assertFalse(
            SettingsTimetableHubLogic.stateOf(
                snapshot = snapshot,
                settings = TimetableSettingsModel(),
            ).partnerBound,
        )
    }
}
