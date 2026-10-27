package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 通用设置页（`lib/screens/settings/settings_general.dart`）结构测试。
 *
 * 期望值来源：Dart 源（行顺序 / 控件类型 / 上下限 / 条件分支）+ ARB（文案），
 * 不从 Kotlin 实现倒推。每处断言都写了 Dart 出处，便于逐项复核。
 */
class SettingsGeneralPageTest {

    private fun spec(state: SettingsPageState = SettingsPageState()) =
        SettingsGeneralPage.spec(state)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 generalSettingsTitle`() {
        val page = spec()
        assertEquals("settings-general", page.id)
        assertEquals("generalSettingsTitle", page.titleKey)
        assertEquals("通用", page.title)
        // settings_general.dart:52 `title: Text(l10n.generalSettingsTitle)`
    }

    @Test
    fun `首组四行按 Dart 顺序排列`() {
        // settings_general.dart:56-101：语言 → 转场速度 → 震动反馈 → 下拉快捷导入
        assertEquals(
            listOf(
                "general.language",
                "general.transitionSpeed",
                "general.haptics",
                "general.homePullImport",
            ),
            spec().group("general.main").childRowIds(),
        )
    }

    @Test
    fun `四行各自用的官方组件`() {
        val page = spec()
        assertEquals(MiuixRowComponent.DROPDOWN, page.row("general.language").component)
        assertEquals(MiuixRowComponent.SLIDER, page.row("general.transitionSpeed").component)
        assertEquals(MiuixRowComponent.SWITCH, page.row("general.haptics").component)
        assertEquals(MiuixRowComponent.SWITCH, page.row("general.homePullImport").component)
    }

    // -------------------------------------------------------------- 语言行

    @Test
    fun `语言行文案与选项表`() {
        // settings_general.dart:58-66 + settings_shared.dart:111-125
        val row = spec().row("general.language")
        assertEquals("languageModeLabel", row.titleKey)
        assertEquals("语言选择", row.title)
        assertEquals("languageSectionSubtitle", row.subtitleKey)
        assertEquals("可跟随系统，或手动切换到已适配语言", row.subtitle)
        assertEquals(
            listOf("跟随系统", "English", "日本語", "한국어", "简体中文", "繁體中文（香港）", "繁體中文（台灣）"),
            row.options.map { it.label },
        )
        assertEquals(
            listOf("", "en", "ja", "ko", "zh", "zh_HK", "zh_TW"),
            row.options.map { it.id },
        )
    }

    @Test
    fun `语言行选中值走 normalizeLocaleTagForDropdown`() {
        // settings_shared.dart:84-105
        assertEquals("", spec().row("general.language").selectedOptionId)
        assertEquals("zh", spec(SettingsPageState(appLocaleTag = "zh-Hans")).row("general.language").selectedOptionId)
        assertEquals("en", spec(SettingsPageState(appLocaleTag = "en-US")).row("general.language").selectedOptionId)
        assertEquals("zh_HK", spec(SettingsPageState(appLocaleTag = "zh_HK")).row("general.language").selectedOptionId)
    }

    @Test
    fun `locale 标签归一的边界`() {
        // 人推边界：空 / 前后空白 / 非法语言 / 只有语言码 / 大小写敏感
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag(""))
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag("   "))
        assertEquals("ja", SettingsGeneralPage.normalizeLocaleTag("  ja  "))
        assertEquals("zh", SettingsGeneralPage.normalizeLocaleTag("zh-Hans"))
        assertEquals("zh", SettingsGeneralPage.normalizeLocaleTag("zh_CN"))
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag("fr"))
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag("ZH"))
        // 多段标签落到语言码（Dart 同口径：先试完整标签，再试第一段）
        assertEquals("en", SettingsGeneralPage.normalizeLocaleTag("en_US_POSIX"))
    }

    // ------------------------------------------------------------ 转场滑杆

    @Test
    fun `转场速度滑杆上下限与档数`() {
        // settings_general.dart:67-81；上下限 timetable_settings.dart:345-346，档数硬编码 20
        val slider = spec().row("general.transitionSpeed").slider!!
        assertEquals(0.5, slider.min, 0.0)
        assertEquals(2.5, slider.max, 0.0)
        assertEquals(20, slider.divisions)
        assertEquals(1.0, slider.defaultValue, 0.0)
    }

    @Test
    fun `转场速度读数一位小数带乘号`() {
        // settings_general.dart:73 `'${_draft.pageTransitionSpeed.toStringAsFixed(1)}×'`
        assertEquals("1.0×", spec().row("general.transitionSpeed").value)
        assertEquals("2.5×", spec(SettingsPageState(pageTransitionSpeed = 2.5)).row("general.transitionSpeed").value)
        assertEquals("0.5×", spec(SettingsPageState(pageTransitionSpeed = 0.5)).row("general.transitionSpeed").value)
    }

    @Test
    fun `滑杆行的当前值随状态走`() {
        // value 是给人看的读数，sliderValue 是给组件定位滑块用的数
        assertEquals(1.0, spec().row("general.transitionSpeed").sliderValue!!, 0.0)
        assertEquals(
            2.5,
            spec(SettingsPageState(pageTransitionSpeed = 2.5)).row("general.transitionSpeed").sliderValue!!,
            0.0,
        )
        assertEquals(
            24.0,
            spec(
                SettingsPageState(
                    autoRefresh = AutoRefreshState(
                        enabled = true,
                        mode = CourseAutoRefreshMode.INTERVAL_HOURS,
                        intervalHours = 24,
                    ),
                ),
            ).row("general.autoRefresh.interval").sliderValue!!,
            0.0,
        )
    }

    // ------------------------------------------------------------ 两个开关

    @Test
    fun `震动反馈开关文案与默认值`() {
        // settings_general.dart:82-89；默认 true 见 timetable_settings.dart:820
        val row = spec().row("general.haptics")
        assertEquals("layoutEnableHapticsTitle", row.titleKey)
        assertEquals("启用应用内震动反馈", row.title)
        assertEquals("layoutEnableHapticsSubtitle", row.subtitleKey)
        assertEquals("关闭后页码切换不再震动", row.subtitle)
        assertEquals(true, row.switchValue)
        assertTrue(row.enabled)
    }

    @Test
    fun `下拉快捷导入开关文案与默认值`() {
        // settings_general.dart:90-99；默认 false 见 timetable_settings.dart:822
        val row = spec().row("general.homePullImport")
        assertEquals("homePullQuickImportTitle", row.titleKey)
        assertEquals("首页下拉快捷导入", row.title)
        assertEquals("homePullQuickImportSubtitle", row.subtitleKey)
        assertEquals("在首页下拉时自动执行教务快捷导入", row.subtitle)
        assertEquals(false, row.switchValue)
    }

    // -------------------------------------------------------- 课表自动更新

    @Test
    fun `自动更新未加载时整块不渲染`() {
        // widgets/course_auto_refresh_settings.dart:97-99 `if (_loading) return SizedBox.shrink()`
        val ids = spec(SettingsPageState(autoRefresh = null)).topLevelIds()
        assertFalse("未加载时不该出现自动更新分组", ids.contains("general.autoRefresh"))
        assertFalse(ids.contains("general.autoRefresh.label"))
        assertFalse(ids.contains("general.autoRefresh.summary"))
    }

    @Test
    fun `自动更新关闭时只剩开关行且底部灰字是副标题`() {
        // course_auto_refresh_settings.dart:107-114 + :226-228（!enabled → courseAutoRefreshSubtitle）
        val page = spec(SettingsPageState(autoRefresh = AutoRefreshState(enabled = false)))
        assertEquals(
            listOf("general.autoRefresh.switch"),
            page.group("general.autoRefresh").childRowIds(),
        )
        val switch = page.row("general.autoRefresh.switch")
        assertEquals("自动更新课表", switch.title)
        assertEquals("到点自动抓一次教务课表", switch.subtitle)
        assertEquals(false, switch.switchValue)
        val summary = page.flatten().filterIsInstance<SettingsDescription>().single()
        assertEquals("courseAutoRefreshSubtitle", summary.textKey)
        assertEquals("到点自动抓一次教务课表", summary.text)
    }

    @Test
    fun `自动更新区块标题与三档时机文案`() {
        // course_auto_refresh_settings.dart:104,116-130
        val page = spec(SettingsPageState(autoRefresh = AutoRefreshState(enabled = true)))
        val label = page.flatten().filterIsInstance<SettingsLabel>().single()
        assertEquals("courseAutoRefreshSectionTitle", label.textKey)
        assertEquals("课表自动更新", label.text)
        val mode = page.row("general.autoRefresh.mode")
        assertEquals("更新时机", mode.title)
        assertEquals(
            listOf("每次打开时", "每隔几小时", "每天定时"),
            mode.options.map { it.label },
        )
        assertEquals(listOf("everyLaunch", "intervalHours", "dailyAt"), mode.options.map { it.id })
    }

    @Test
    fun `间隔模式出现间隔滑杆且没有定时行`() {
        // course_auto_refresh_settings.dart:131-147
        val page = spec(
            SettingsPageState(
                autoRefresh = AutoRefreshState(
                    enabled = true,
                    mode = CourseAutoRefreshMode.INTERVAL_HOURS,
                    intervalHours = 24,
                ),
            ),
        )
        assertEquals(
            listOf(
                "general.autoRefresh.switch",
                "general.autoRefresh.mode",
                "general.autoRefresh.interval",
                "general.autoRefresh.tryNow",
            ),
            page.group("general.autoRefresh").childRowIds(),
        )
        val slider = page.row("general.autoRefresh.interval")
        assertEquals("间隔小时数", slider.title)
        assertEquals(1.0, slider.slider!!.min, 0.0)
        assertEquals(168.0, slider.slider!!.max, 0.0)
        // 档数跟着上下限走（168-1），不写死（同文件 :137-140）
        assertEquals(167, slider.slider!!.divisions)
        assertEquals("24h", slider.value)
        assertEquals("168h", spec(
            SettingsPageState(
                autoRefresh = AutoRefreshState(
                    enabled = true,
                    mode = CourseAutoRefreshMode.INTERVAL_HOURS,
                    intervalHours = 168,
                ),
            ),
        ).row("general.autoRefresh.interval").value)
    }

    @Test
    fun `每天定时模式出现时刻行且没有间隔滑杆`() {
        // course_auto_refresh_settings.dart:148-153
        val page = spec(
            SettingsPageState(
                autoRefresh = AutoRefreshState(
                    enabled = true,
                    mode = CourseAutoRefreshMode.DAILY_AT,
                    dailyMinuteOfDay = 7 * 60 + 30,
                ),
            ),
        )
        assertEquals(
            listOf(
                "general.autoRefresh.switch",
                "general.autoRefresh.mode",
                "general.autoRefresh.dailyTime",
                "general.autoRefresh.tryNow",
            ),
            page.group("general.autoRefresh").childRowIds(),
        )
        val daily = page.row("general.autoRefresh.dailyTime")
        assertEquals("每天更新时刻", daily.title)
        // 时刻是**动态取值**（今天选到几点就显示几点），按模型口径放 value；
        // details 留给来自 ARB 的静态行尾文案
        assertEquals("07:30", daily.value)
        assertNull(daily.details)
        assertEquals(MiuixRowComponent.ARROW, daily.component)
    }

    @Test
    fun `每次打开模式既无间隔滑杆也无时刻行`() {
        // 同文件 :131/:148 两个 if 都不成立
        assertEquals(
            listOf(
                "general.autoRefresh.switch",
                "general.autoRefresh.mode",
                "general.autoRefresh.tryNow",
            ),
            spec(
                SettingsPageState(
                    autoRefresh = AutoRefreshState(
                        enabled = true,
                        mode = CourseAutoRefreshMode.EVERY_LAUNCH,
                    ),
                ),
            ).group("general.autoRefresh").childRowIds(),
        )
    }

    @Test
    fun `立即试一次行的文案`() {
        // course_auto_refresh_settings.dart:154-158
        val row = spec(SettingsPageState(autoRefresh = AutoRefreshState(enabled = true)))
            .row("general.autoRefresh.tryNow")
        assertEquals("立即试一次", row.title)
        assertEquals("不等时间窗，马上跑一次", row.subtitle)
        assertEquals(SettingsAction.RUN_NOW, row.action)
    }

    @Test
    fun `底部灰字四种拼法`() {
        // course_auto_refresh_settings.dart:226-240 + :246-252 的短格式
        assertEquals(
            "到点自动抓一次教务课表",
            SettingsGeneralPage.autoRefreshSummary(AutoRefreshState(enabled = false)),
        )
        assertEquals(
            "还没成功更新过",
            SettingsGeneralPage.autoRefreshSummary(AutoRefreshState(enabled = true)),
        )
        assertEquals(
            "上次 9-21 07:30",
            SettingsGeneralPage.autoRefreshSummary(
                AutoRefreshState(enabled = true, lastSuccessLabel = "9-21 07:30"),
            ),
        )
        assertEquals(
            "上次 9-21 07:30 · 下次约 9-22 07:30",
            SettingsGeneralPage.autoRefreshSummary(
                AutoRefreshState(
                    enabled = true,
                    lastSuccessLabel = "9-21 07:30",
                    nextRunLabel = "9-22 07:30",
                ),
            ),
        )
    }

    @Test
    fun `短日期格式月不补零日补零`() {
        // course_auto_refresh_settings.dart:246-252
        assertEquals("9-21 07:30", SettingsGeneralPage.shortDateTime(9, 21, 7, 30))
        assertEquals("10-05 00:00", SettingsGeneralPage.shortDateTime(10, 5, 0, 0))
    }

    @Test
    fun `时刻读数两位补零`() {
        // course_auto_refresh_settings.dart:216-220
        assertEquals("07:30", SettingsGeneralPage.formatMinuteOfDay(7 * 60 + 30))
        assertEquals("00:00", SettingsGeneralPage.formatMinuteOfDay(0))
        assertEquals("23:59", SettingsGeneralPage.formatMinuteOfDay(23 * 60 + 59))
    }

    // ---------------------------------------------------------- 写盘语义

    @Test
    fun `通用页的行都带写设置动作`() {
        // 每行的 onChanged 都进 _updateDraft → _enqueuePersist
        val page = spec(SettingsPageState(autoRefresh = AutoRefreshState(enabled = true)))
        page.rows().forEach { row ->
            assertNull("行 ${row.id} 不应有导航目标", row.actionTarget)
        }
        assertEquals(SettingsAction.WRITE_SETTING, page.row("general.haptics").action)
        assertEquals(SettingsAction.WRITE_SETTING, page.row("general.language").action)
        assertEquals(SettingsAction.WRITE_SETTING, page.row("general.transitionSpeed").action)
    }
}
