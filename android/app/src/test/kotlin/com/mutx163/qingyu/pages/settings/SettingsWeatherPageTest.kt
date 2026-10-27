package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 天气设置页（`lib/screens/settings/settings_weather.dart`）结构测试。
 *
 * 期望值来源：Dart 源（三个区块 / 开关联动 / 条件行）+ ARB（文案）。
 *
 * 这一页有一条容易漏的联动：**总开关关掉后，下面五个显示开关全部禁用而不是隐藏**
 * （:39-41 注释：「用户能看到原来还有这些选项，也知道为什么点不动」）。
 */
class SettingsWeatherPageTest {

    private fun page(data: WeatherPageData = WeatherPageData()) =
        SettingsWeatherPage.spec(SettingsPageState(), data)

    @Test
    fun `页面标题取自 weatherSettingsTitle`() {
        // settings_weather.dart:63
        val spec = page()
        assertEquals("settings-weather", spec.id)
        assertEquals("weatherSettingsTitle", spec.titleKey)
        assertEquals("天气", spec.title)
    }

    @Test
    fun `三个带标题区块按来源 显示 内容排列 且各带前导空档`() {
        // settings_weather.dart:70-228：每个区块 = Gap + Label + Group（+ 可选 Description）
        assertEquals(
            listOf(
                "weather.gap.source",
                "weather.section.source",
                "weather.group.source",
                "weather.desc.attribution",
                "weather.gap.display",
                "weather.section.display",
                "weather.group.display",
                "weather.desc.coverage",
                "weather.gap.content",
                "weather.section.content",
                "weather.group.content",
            ),
            page().topLevelIds(),
        )
    }

    @Test
    fun `三个区块小标题的文案`() {
        // settings_weather.dart:71 / :144 / :195
        val labels = page().flatten().filterIsInstance<SettingsLabel>()
        assertEquals(
            listOf("weatherSectionSourceTitle", "weatherSectionDisplayTitle", "weatherSectionContentTitle"),
            labels.map { it.textKey },
        )
        assertEquals(listOf("数据来源", "显示", "显示内容"), labels.map { it.text })
    }

    // ------------------------------------------------------------- 数据来源

    @Test
    fun `数据来源组在成功态只有定位与城市两行`() {
        // settings_weather.dart:76-137（重试行仅 status == failed 时出现）
        assertEquals(
            listOf("weather.useCurrentLocation", "weather.city"),
            page().group("weather.group.source").childRowIds(),
        )
    }

    @Test
    fun `一键定位行的文案与可用性`() {
        // settings_weather.dart:76-96
        val row = page().row("weather.useCurrentLocation")
        assertEquals("weatherUseCurrentLocation", row.titleKey)
        assertEquals("使用当前位置", row.title)
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertEquals(SettingsAction.RUN_NOW, row.action)
        assertTrue(row.enabled)
    }

    @Test
    fun `定位中整行禁用`() {
        // settings_weather.dart:93 `onClick: (weather == null || weather.isLocating) ? null : …`
        assertFalse(page(WeatherPageData(locating = true)).row("weather.useCurrentLocation").enabled)
    }

    @Test
    fun `天气 provider 缺席时定位行也禁用`() {
        // settings_weather.dart:41 `enabled = weather?.enabled ?? false`；:93 weather == null → null
        assertFalse(page(WeatherPageData(providerAvailable = false)).row("weather.useCurrentLocation").enabled)
    }

    @Test
    fun `城市行的行尾是城市名`() {
        // settings_weather.dart:104-109 `weather?.location?.displayName ?? weatherCityNotSet`
        val set = page(WeatherPageData(cityDisplayName = "杭州市 · 拱墅区")).row("weather.city")
        assertEquals("weatherCityLabel", set.titleKey)
        assertEquals("城市", set.title)
        assertEquals("杭州市 · 拱墅区", set.value)
        // 城市名是运行时数据，不来自 ARB
        assertNull(set.valueKey)
        assertEquals(SettingsAction.NAVIGATE, set.action)
        assertEquals(SettingsWeatherPage.ROUTE_CITY_PICKER, set.actionTarget)
    }

    @Test
    fun `未设置城市时行尾是未设置`() {
        // settings_weather.dart:107
        val row = page(WeatherPageData(cityDisplayName = null)).row("weather.city")
        assertEquals("weatherCityNotSet", row.valueKey)
        assertEquals("未设置", row.value)
    }

    @Test
    fun `取数失败时才出现重试行`() {
        // settings_weather.dart:123-137 `if (weather?.status == WeatherStatus.failed)`
        assertEquals(
            listOf("weather.useCurrentLocation", "weather.city", "weather.retry"),
            page(WeatherPageData(status = WeatherStatus.FAILED)).group("weather.group.source").childRowIds(),
        )
        val retry = page(WeatherPageData(status = WeatherStatus.FAILED)).row("weather.retry")
        assertEquals("weatherStatusFailed", retry.titleKey)
        assertEquals("上次更新失败", retry.title)
        assertEquals("weatherRetryAction", retry.valueKey)
        assertEquals("重试", retry.value)
        assertEquals(SettingsAction.RUN_NOW, retry.action)
    }

    @Test
    fun `加载中与空闲态都没有重试行`() {
        assertFalse(
            page(WeatherPageData(status = WeatherStatus.LOADING))
                .group("weather.group.source").childRowIds().contains("weather.retry"),
        )
        assertFalse(
            page(WeatherPageData(status = WeatherStatus.IDLE))
                .group("weather.group.source").childRowIds().contains("weather.retry"),
        )
    }

    @Test
    fun `数据来源署名是整宽说明而不是行`() {
        // settings_weather.dart:141（Open-Meteo 的 CC BY 4.0 条款要求）
        val desc = page().flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "weather.desc.attribution" }
        assertEquals("weatherAttribution", desc.textKey)
        assertEquals("天气数据来自 Open-Meteo.com", desc.text)
    }

    // ----------------------------------------------------------------- 显示

    @Test
    fun `显示组四个开关按总开关 日视图 周视图 详情弹窗排列`() {
        // settings_weather.dart:145-188
        assertEquals(
            listOf(
                "weather.enable",
                "weather.showOnDayCard",
                "weather.showOnWeekCard",
                "weather.showOnSheet",
            ),
            page().group("weather.group.display").childRowIds(),
        )
    }

    @Test
    fun `总开关文案与默认值`() {
        // settings_weather.dart:147-155；weather 设备级开关默认关
        val row = page().row("weather.enable")
        assertEquals("weatherEnableTitle", row.titleKey)
        assertEquals("显示天气", row.title)
        assertEquals("weatherEnableSubtitle", row.subtitleKey)
        assertEquals("关闭后不再获取天气数据", row.subtitle)
        assertEquals(false, row.switchValue)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
    }

    @Test
    fun `总开关打开后显示组开关才可用`() {
        // settings_weather.dart:158-187 `onChanged: enabled ? … : null`
        val off = page(WeatherPageData(enabled = false))
        assertFalse(off.row("weather.showOnDayCard").enabled)
        assertFalse(off.row("weather.showOnWeekCard").enabled)
        assertFalse(off.row("weather.showOnSheet").enabled)
        val on = page(WeatherPageData(enabled = true))
        assertTrue(on.row("weather.showOnDayCard").enabled)
        assertTrue(on.row("weather.showOnWeekCard").enabled)
        assertTrue(on.row("weather.showOnSheet").enabled)
    }

    @Test
    fun `三个显示位置开关的标题`() {
        // settings_weather.dart:159 / :168 / :181
        assertEquals("日视图课卡", page().row("weather.showOnDayCard").title)
        assertEquals("周视图课卡", page().row("weather.showOnWeekCard").title)
        assertEquals("课程详情弹窗", page().row("weather.showOnSheet").title)
    }

    @Test
    fun `只有周视图开关带说明`() {
        // settings_weather.dart:172 `subtitle: weatherShowOnWeekCardSubtitle`
        assertEquals("weatherShowOnWeekCardSubtitle", page().row("weather.showOnWeekCard").subtitleKey)
        assertEquals("格子窄，只写一项，优先温度", page().row("weather.showOnWeekCard").subtitle)
        assertNull(page().row("weather.showOnDayCard").subtitle)
        assertNull(page().row("weather.showOnSheet").subtitle)
    }

    @Test
    fun `三个显示位置开关的默认值都是开`() {
        // timetable_settings.dart:774-776
        val page = page(WeatherPageData(enabled = true))
        assertEquals(true, page.row("weather.showOnDayCard").switchValue)
        assertEquals(true, page.row("weather.showOnWeekCard").switchValue)
        assertEquals(true, page.row("weather.showOnSheet").switchValue)
    }

    @Test
    fun `三个显示位置开关随状态走`() {
        val page = page(
            WeatherPageData(
                enabled = true,
                showOnDayCard = false,
                showOnWeekCard = true,
                showOnSheet = false,
            ),
        )
        assertEquals(false, page.row("weather.showOnDayCard").switchValue)
        assertEquals(true, page.row("weather.showOnWeekCard").switchValue)
        assertEquals(false, page.row("weather.showOnSheet").switchValue)
    }

    @Test
    fun `覆盖范围说明是整宽脚注`() {
        // settings_weather.dart:192
        val desc = page().flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "weather.desc.coverage" }
        assertEquals("weatherCoverageNote", desc.textKey)
        assertEquals("预报只覆盖未来 16 天，更远不显示", desc.text)
    }

    // ------------------------------------------------------------- 显示内容

    @Test
    fun `显示内容组三个开关按现象 温度 概率排列`() {
        // settings_weather.dart:196-228
        assertEquals(
            listOf("weather.showPhenomenon", "weather.showTemperature", "weather.showProbability"),
            page().group("weather.group.content").childRowIds(),
        )
    }

    @Test
    fun `显示内容三项的文案`() {
        // settings_weather.dart:198-226
        val page = page()
        assertEquals("天气现象", page.row("weather.showPhenomenon").title)
        assertEquals("例如 小雨、多云", page.row("weather.showPhenomenon").subtitle)
        assertEquals("温度", page.row("weather.showTemperature").title)
        assertNull(page.row("weather.showTemperature").subtitle)
        assertEquals("降水概率", page.row("weather.showProbability").title)
        assertEquals("低于 30% 时不显示", page.row("weather.showProbability").subtitle)
    }

    @Test
    fun `显示内容三项默认值 现象与温度开 概率关`() {
        // timetable_settings.dart:777-779
        val page = page(WeatherPageData(enabled = true))
        assertEquals(true, page.row("weather.showPhenomenon").switchValue)
        assertEquals(true, page.row("weather.showTemperature").switchValue)
        assertEquals(false, page.row("weather.showProbability").switchValue)
    }

    @Test
    fun `总开关关掉后显示内容三项也禁用`() {
        // settings_weather.dart:202 / :212 / :221 三处 onChanged 都判 enabled
        val off = page(WeatherPageData(enabled = false))
        assertFalse(off.row("weather.showPhenomenon").enabled)
        assertFalse(off.row("weather.showTemperature").enabled)
        assertFalse(off.row("weather.showProbability").enabled)
    }

    @Test
    fun `总开关本身不受自身影响 恒定可用`() {
        // settings_weather.dart:151 只看 weather == null，不看 enabled
        assertTrue(page(WeatherPageData(enabled = false)).row("weather.enable").enabled)
    }

    @Test
    fun `网络估算提示不是屏上常驻文案`() {
        // settings_weather.dart:276 `showAppToast(weatherLocationEstimated)` —— toast，不是行
        assertEquals(
            "已按网络位置估算，可能不精确",
            SettingsStringsExt3.weatherLocationEstimated.zh,
        )
        val ids = page().flattenedIds()
        assertFalse(ids.any { it.contains("estimated") })
    }

    @Test
    fun `城市选择路由名与 Dart 一致`() {
        assertEquals("/settings/weather/city", SettingsWeatherPage.ROUTE_CITY_PICKER)
    }
}
