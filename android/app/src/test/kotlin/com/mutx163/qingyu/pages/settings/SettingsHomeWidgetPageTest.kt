package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 桌面小组件设置页（`lib/screens/settings/settings_home_widget.dart`）结构测试。
 *
 * 期望值来源：Dart 源（区块顺序 / 控件类型 / 上下限 / 条件分支）+ ARB（文案），
 * 不从 Kotlin 实现倒推。每处断言都写了 Dart 出处，便于逐项复核。
 *
 * 本页是设置族最重的一页（1154 行 / 43 个 l10n 键）：预览轮播 + 五个可调开关 +
 * 倒计时提前量与样式 + 两个滑杆 + 各卡片绑定管理 + 恢复默认。
 */
class SettingsHomeWidgetPageTest {

    private fun spec(state: SettingsHomeWidgetState = SettingsHomeWidgetState()) =
        SettingsHomeWidgetPage.spec(state)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 homeWidgetSettingsTitle`() {
        val page = spec()
        assertEquals("settings-home-widget", page.id)
        assertEquals("homeWidgetSettingsTitle", page.titleKey)
        assertEquals("桌面小组件", page.title)
        // settings_home_widget.dart:199 `title: Text(l10n.homeWidgetSettingsTitle)`
    }

    /**
     * `_homeWidgetSectionCount => (_draft.widgetShowCountdown ? 4 : 3) + 2`（:214），
     * 而 `_buildHomeWidgetSection` 里 section 偏移：
     *
     * ```
     * 0 预览 · 1 今日课程组件 · 2 倒计时（!!! 仅 widgetShowCountdown 时占位）·
     * 3 卡片外观 · 4 各卡片绑定管理 · 5 恢复默认
     * ```
     *
     * 关掉「显示倒计时」时 section 2 整块不存在，`if (!showCountdown && section >= 2)
     * section += 1`（:219-221）→ 倒计时提前量与样式两行**一起消失**。
     */
    @Test
    fun `区块顺序为预览-今日课程-倒计时-外观-绑定-重置`() {
        val ids = spec().topLevelIds()
        assertEquals(
            listOf(
                "homeWidget.preview",
                "homeWidget.gap.todayCourse",
                "homeWidget.todayCourse.label",
                "homeWidget.todayCourse",
                "homeWidget.gap.countdown",
                "homeWidget.countdown.label",
                "homeWidget.countdown",
                "homeWidget.gap.appearance",
                "homeWidget.appearance.label",
                "homeWidget.appearance",
                "homeWidget.gap.binding",
                "homeWidget.binding.label",
                "homeWidget.binding",
                "homeWidget.gap.resetOuter",
                "homeWidget.gap.reset",
                "homeWidget.reset",
            ),
            ids,
        )
    }

    @Test
    fun `关闭显示倒计时后倒计时整块消失`() {
        // settings_home_widget.dart:214 + :219-221
        val on = spec(SettingsHomeWidgetState(showCountdown = true)).topLevelIds()
        val off = spec(SettingsHomeWidgetState(showCountdown = false)).topLevelIds()
        assertTrue(on.contains("homeWidget.countdown"))
        assertTrue(on.contains("homeWidget.countdown.label"))
        assertFalse(off.contains("homeWidget.countdown"))
        assertFalse(off.contains("homeWidget.countdown.label"))
        // 关闭后其余区块照旧，只是整体上移一格
        assertEquals(on.size - 2, off.size)
    }

    // ------------------------------------------------------- 今日课程组件组

    @Test
    fun `今日课程组件组标题与六行顺序`() {
        // settings_home_widget.dart:229-296：背景样式 → 课程颜色 → 显示地点 →
        // 显示倒计时 → 隐藏已上完课程 → 课后显示明日课程
        val page = spec()
        val label = page.flatten().filterIsInstance<SettingsLabel>()[0]
        assertEquals("homeWidgetTodayCourseTitle", label.textKey)
        assertEquals("今日课程组件", label.text)
        assertEquals(
            listOf(
                "homeWidget.backgroundStyle",
                "homeWidget.courseAccent",
                "homeWidget.showLocation",
                "homeWidget.showCountdown",
                "homeWidget.hideCompleted",
                "homeWidget.showTomorrow",
            ),
            page.group("homeWidget.todayCourse").childRowIds(),
        )
    }

    @Test
    fun `背景样式下拉三档与选中值`() {
        // settings_home_widget.dart:232-241 + enum_localizations.dart:39-46
        val row = spec().row("homeWidget.backgroundStyle")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("homeWidgetBackgroundStyleLabel", row.titleKey)
        assertEquals("背景样式", row.title)
        assertEquals(listOf("glass", "solid", "gradient"), row.options.map { it.id })
        assertEquals(listOf("半透明玻璃感", "纯色卡片", "渐变卡片"), row.options.map { it.label })
        // TimetableSettings 默认 widgetBackgroundStyle = solid（timetable_settings.dart:786）
        assertEquals("solid", row.selectedOptionId)
        assertEquals(
            "gradient",
            spec(SettingsHomeWidgetState(backgroundStyle = "gradient"))
                .row("homeWidget.backgroundStyle").selectedOptionId,
        )
    }

    @Test
    fun `课程颜色下拉三档且不挂副标题`() {
        // settings_home_widget.dart:243-258；注释明确「不挂副标题」（:245-247）
        val row = spec().row("homeWidget.courseAccent")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("homeWidgetCourseAccentTitle", row.titleKey)
        assertEquals("课程颜色", row.title)
        assertNull("课程颜色行不得有副标题（Dart :245-247）", row.subtitle)
        assertEquals(listOf("off", "bar", "bar_and_text"), row.options.map { it.id })
        assertEquals(listOf("关闭", "仅色条", "色条 + 文字"), row.options.map { it.label })
        // 默认 barAndText（widget_course_accent.dart:36-38）
        assertEquals("bar_and_text", row.selectedOptionId)
    }

    @Test
    fun `四个开关的文案与当前值`() {
        // settings_home_widget.dart:259-294；默认值 timetable_settings.dart:788-791
        val page = spec()
        val location = page.row("homeWidget.showLocation")
        assertEquals("homeWidgetShowLocationTitle", location.titleKey)
        assertEquals("显示地点", location.title)
        assertEquals("homeWidgetShowLocationSubtitle", location.subtitleKey)
        assertEquals("关闭后改显周次与课程数", location.subtitle)
        assertEquals(MiuixRowComponent.SWITCH, location.component)
        assertEquals(true, location.switchValue)

        val countdown = page.row("homeWidget.showCountdown")
        assertEquals("显示倒计时", countdown.title)
        assertEquals("显示下节课倒计时", countdown.subtitle)
        assertEquals(true, countdown.switchValue)

        val hide = page.row("homeWidget.hideCompleted")
        assertEquals("隐藏已上完课程", hide.title)
        assertEquals("只显示未结束的课程", hide.subtitle)
        assertEquals(false, hide.switchValue)

        val tomorrow = page.row("homeWidget.showTomorrow")
        assertEquals("课后显示明日课程", tomorrow.title)
        assertEquals("今日课后自动显示明天课程", tomorrow.subtitle)
        assertEquals(true, tomorrow.switchValue)
    }

    @Test
    fun `四个开关按状态取值`() {
        val page = spec(
            SettingsHomeWidgetState(
                showLocation = false,
                hideCompleted = true,
                showTomorrow = false,
            ),
        )
        assertEquals(false, page.row("homeWidget.showLocation").switchValue)
        assertEquals(true, page.row("homeWidget.hideCompleted").switchValue)
        assertEquals(false, page.row("homeWidget.showTomorrow").switchValue)
    }

    // --------------------------------------------------------- 倒计时提前量

    @Test
    fun `倒计时提前量区标题与两行`() {
        // settings_home_widget.dart:303-332
        val page = spec()
        val labels = page.flatten().filterIsInstance<SettingsLabel>()
        assertEquals("homeWidgetCountdownLeadTitle", labels[1].textKey)
        assertEquals("倒计时提前量", labels[1].text)
        assertEquals(
            listOf("homeWidget.countdownLead", "homeWidget.countdownStyle"),
            page.group("homeWidget.countdown").childRowIds(),
        )
    }

    @Test
    fun `提前量下拉选项为零加九档分钟`() {
        // settings_home_widget.dart:306-319：始终显示 + [1,5,10,15,20,30,40,50,60]
        val row = spec().row("homeWidget.countdownLead")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        // 行标题复用区标题（Dart :307 label: l10n.homeWidgetCountdownLeadTitle）
        assertEquals("倒计时提前量", row.title)
        assertEquals(
            listOf("0", "1", "5", "10", "15", "20", "30", "40", "50", "60"),
            row.options.map { it.id },
        )
        assertEquals(
            listOf(
                "始终显示", "1 分钟", "5 分钟", "10 分钟", "15 分钟",
                "20 分钟", "30 分钟", "40 分钟", "50 分钟", "60 分钟",
            ),
            row.options.map { it.label },
        )
        // 默认 20 分钟（timetable_settings.dart:794）
        assertEquals("20", row.selectedOptionId)
    }

    @Test
    fun `提前量选项名都来自 ARB`() {
        val row = spec().row("homeWidget.countdownLead")
        assertEquals("homeWidgetCountdownLeadAlways", row.options[0].labelKey)
        // 其后九项是 beforeClassMinutesOption 的模板渲染值
        row.options.drop(1).forEach { assertEquals("beforeClassMinutesOption", it.labelKey) }
    }

    @Test
    fun `倒计时样式下拉十二档`() {
        // settings_home_widget.dart:320-332 + timetable_settings_enums.dart:244-257
        val row = spec().row("homeWidget.countdownStyle")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("widgetCountdownStyleTitle", row.titleKey)
        assertEquals("倒计时样式", row.title)
        assertEquals(12, row.options.size)
        assertEquals(
            listOf(
                "smart", "smart_min_s", "minute_second_cn", "minute_second_colon",
                "minute_second_min_s", "minute_second_min_slash_s",
                "minute_only_cn", "minute_only_min", "minute_only_slash",
                "second_only_cn", "second_only_short", "second_only_slash",
            ),
            row.options.map { it.id },
        )
        assertEquals("智能 中文", row.options[0].label)
        assertEquals("纯秒 5/s", row.options[11].label)
        // 默认 smart（timetable_settings.dart:795）
        assertEquals("smart", row.selectedOptionId)
    }

    // ------------------------------------------------------------- 卡片外观

    @Test
    fun `卡片外观两条滑杆的上下限`() {
        // settings_home_widget.dart:347-375
        val page = spec()
        val height = page.row("homeWidget.heightAdjust")
        assertEquals(MiuixRowComponent.SLIDER, height.component)
        assertEquals("卡片高度", height.title)
        assertEquals(-16.0, height.slider!!.min, 0.0)
        assertEquals(16.0, height.slider!!.max, 0.0)
        assertEquals(32, height.slider!!.divisions)
        assertEquals(0.0, height.slider!!.defaultValue, 0.0)

        val radius = page.row("homeWidget.cornerRadius")
        assertEquals(MiuixRowComponent.SLIDER, radius.component)
        assertEquals("卡片圆角", radius.title)
        // 默认 22 ± 14 → [8, 36]，28 档（:368-370）
        assertEquals(8.0, radius.slider!!.min, 0.0)
        assertEquals(36.0, radius.slider!!.max, 0.0)
        assertEquals(28, radius.slider!!.divisions)
        assertEquals(22.0, radius.slider!!.defaultValue, 0.0)
    }

    @Test
    fun `卡片高度滑杆用相对默认档的偏移`() {
        // 存储值 -11 是默认，滑杆读数是 -11 - (-11) = 0（:344-352）
        assertEquals(0.0, spec().row("homeWidget.heightAdjust").sliderValue!!, 0.0)
        // 存储 -3 → 偏移 +8
        assertEquals(
            8.0,
            spec(SettingsHomeWidgetState(heightAdjustment = -3.0))
                .row("homeWidget.heightAdjust").sliderValue!!,
            0.0,
        )
        // 存储 -20 → 偏移 -9
        assertEquals(
            -9.0,
            spec(SettingsHomeWidgetState(heightAdjustment = -20.0))
                .row("homeWidget.heightAdjust").sliderValue!!,
            0.0,
        )
    }

    @Test
    fun `卡片高度的值标签三分支`() {
        // settings_home_widget.dart:914-922 `_widgetHeightAdjustmentLabel`
        assertEquals("defaultLabel", spec().row("homeWidget.heightAdjust").valueKey)
        assertEquals("默认", spec().row("homeWidget.heightAdjust").value)

        val higher = spec(SettingsHomeWidgetState(heightAdjustment = -3.0))
            .row("homeWidget.heightAdjust")
        assertEquals("更高 8dp", higher.value)
        assertEquals("higherByValue", higher.valueKey)

        val lower = spec(SettingsHomeWidgetState(heightAdjustment = -20.0))
            .row("homeWidget.heightAdjust")
        assertEquals("更矮 9dp", lower.value)
        assertEquals("lowerByValue", lower.valueKey)
    }

    @Test
    fun `卡片圆角的值标签是整数 dp`() {
        // settings_home_widget.dart:366 `'${widgetCornerRadius.toStringAsFixed(0)}dp'`
        assertEquals("22dp", spec().row("homeWidget.cornerRadius").value)
        assertEquals(
            "30dp",
            spec(SettingsHomeWidgetState(cornerRadius = 30.0))
                .row("homeWidget.cornerRadius").value,
        )
        // toStringAsFixed(0) 是四舍五入而非截断
        assertEquals(
            "23dp",
            spec(SettingsHomeWidgetState(cornerRadius = 22.5))
                .row("homeWidget.cornerRadius").value,
        )
    }

    // --------------------------------------------------------- 各卡片绑定管理

    @Test
    fun `桌面上没有卡片时给空态文案`() {
        // settings_home_widget.dart:805-827：空态下整组只有一句说明
        val page = spec(SettingsHomeWidgetState())
        assertEquals(
            emptyList<String>(),
            page.group("homeWidget.binding").childRowIds(),
        )
        val description = page.flatten().filterIsInstance<SettingsDescription>().single()
        assertEquals("homeWidgetBindingEmpty", description.textKey)
        assertEquals("桌面上还没有今日课程卡片，先添加一张再回来绑定", description.text)
    }

    @Test
    fun `每张已添加的卡片各一行绑定下拉`() {
        // settings_home_widget.dart:841-863
        val page = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(
                    HomeWidgetInstanceSpec(appWidgetId = 11, widgetTypeValue = "compact"),
                    HomeWidgetInstanceSpec(appWidgetId = 12, widgetTypeValue = "today_strip"),
                ),
                profiles = listOf(ProfileSpec(id = "p1", name = "我的课表")),
            ),
        )
        assertEquals(
            listOf("homeWidget.binding.11", "homeWidget.binding.12"),
            page.group("homeWidget.binding").childRowIds(),
        )
        val first = page.row("homeWidget.binding.11")
        assertEquals(MiuixRowComponent.DROPDOWN, first.component)
        // 行标题是卡片类型名（compact → 主卡 2×2），见 :843-846
        assertEquals("主卡 2×2", first.title)
        assertEquals("homeWidgetTargetCompact22", first.titleKey)
        assertEquals("今日横条 4×1", page.row("homeWidget.binding.12").title)
    }

    @Test
    fun `绑定下拉选项为跟随当前课表加各课表`() {
        // settings_home_widget.dart:847-857
        val page = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11)),
                profiles = listOf(
                    ProfileSpec(id = "p1", name = "我的课表"),
                    ProfileSpec(id = "p2", name = "备用课表"),
                ),
            ),
        )
        val options = page.row("homeWidget.binding.11").options
        assertEquals(listOf("", "p1", "p2"), options.map { it.id })
        assertEquals(
            listOf("跟随当前课表", "我的课表", "备用课表"),
            options.map { it.label },
        )
        // 第一项来自 ARB；课表名是用户数据，不来自 ARB
        assertEquals("homeWidgetBindingFollowActive", options[0].labelKey)
        assertNull(options[1].labelKey)
    }

    @Test
    fun `已绑定课表时选中值是课表 id`() {
        val page = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(
                    HomeWidgetInstanceSpec(appWidgetId = 11, boundProfileId = "p2"),
                ),
                profiles = listOf(
                    ProfileSpec(id = "p1", name = "我的课表"),
                    ProfileSpec(id = "p2", name = "备用课表"),
                ),
            ),
        )
        assertEquals("p2", page.row("homeWidget.binding.11").selectedOptionId)
    }

    @Test
    fun `未登记绑定时选中跟随当前课表`() {
        // settings_home_widget.dart:49-52 + :858：null 用空串占位才显示得出「跟随当前课表」
        val page = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11, boundProfileId = null)),
                profiles = listOf(ProfileSpec(id = "p1", name = "我的课表")),
            ),
        )
        assertEquals("", page.row("homeWidget.binding.11").selectedOptionId)
    }

    @Test
    fun `情侣课表排在 TA 课表前面且只在已导入时出现`() {
        // settings_home_widget.dart:829-832 + :852-856：TA 课表本身带
        // isPartnerImported，所以不在「普通课表」里，只以两个专门的选项出现
        val withPartner = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11)),
                profiles = listOf(ProfileSpec(id = "p1", name = "我的课表")),
                partnerProfile = ProfileSpec(id = "ta", name = "TA的课表"),
            ),
        )
        assertEquals(
            listOf("", "p1", "couple-merged", "ta"),
            withPartner.row("homeWidget.binding.11").options.map { it.id },
        )
        assertEquals(
            listOf("跟随当前课表", "我的课表", "情侣课表", "TA的课表"),
            withPartner.row("homeWidget.binding.11").options.map { it.label },
        )
        assertEquals(
            "kHomeWidgetCoupleMergedBindingId（home_widget_binding_service.dart:19）",
            "couple-merged",
            withPartner.row("homeWidget.binding.11").options[2].id,
        )

        val without = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11)),
                profiles = listOf(ProfileSpec(id = "p1", name = "我的课表")),
            ),
        )
        assertEquals(
            listOf("", "p1"),
            without.row("homeWidget.binding.11").options.map { it.id },
        )
    }

    @Test
    fun `情侣导入的课表不重复进普通课表选项`() {
        // settings_home_widget.dart:829-831 `where((p) => !p.isPartnerImported)`
        val page = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11)),
                profiles = listOf(
                    ProfileSpec(id = "p1", name = "我的课表"),
                    ProfileSpec(id = "ta", name = "TA的课表", isPartnerImported = true),
                ),
                partnerProfile = ProfileSpec(id = "ta", name = "TA的课表"),
            ),
        )
        assertEquals(
            listOf("", "p1", "couple-merged", "ta"),
            page.row("homeWidget.binding.11").options.map { it.id },
        )
    }

    @Test
    fun `未知卡片类型回落主卡`() {
        // settings_home_widget.dart:870-880：null 与未知一律落 compact22
        val page = spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11, widgetTypeValue = null)),
            ),
        )
        assertEquals("主卡 2×2", page.row("homeWidget.binding.11").title)
    }

    // ----------------------------------------------------------- 效果预览区

    @Test
    fun `预览区文案与十张卡片格位`() {
        // settings_home_widget.dart:425 + :487-490；格位表见 home_widget_service.dart:115-126
        val page = spec()
        val preview = page.flatten().filterIsInstance<SettingsInline>().single()
        assertEquals(InlineKind.PREVIEW_CARD, preview.kind)
        assertEquals("homeWidgetPreviewTitle", preview.labelKey)
        assertEquals("效果预览", preview.label)
        assertEquals(
            listOf("添加到桌面"),
            preview.texts.map { it.text },
        )
        assertEquals(10, SettingsHomeWidgetPage.PREVIEW_TARGETS.size)
        assertEquals(
            listOf(
                "主卡 2×2", "迷你列表 2×2", "概览 2×4", "列表 4×4", "今日横条 4×1",
                "今日横宽 4×2", "统计 2×2", "统计概览 2×4", "统计横条 4×1", "考试倒计时 2×2",
            ),
            SettingsHomeWidgetPage.PREVIEW_TARGETS.map { it.label },
        )
        assertEquals(
            listOf(
                "compact", "mini_list", "medium", "large", "today_strip",
                "today_wide", "stats_compact", "stats_medium", "stats_strip", "exam_card",
            ),
            SettingsHomeWidgetPage.PREVIEW_TARGETS.map { it.id },
        )
    }

    @Test
    fun `精确闹钟未授权时预览区末尾多一条引导`() {
        // settings_home_widget.dart:212 `_showExactAlarmBanner => canScheduleExactAlarms == false`
        // 未查到（null）时不展示，避免首帧闪烁（:64-66）
        val unknown = spec(SettingsHomeWidgetState(exactAlarmGranted = null))
        assertFalse(unknown.flattenedIds().contains("homeWidget.preview.alarmBanner"))

        val granted = spec(SettingsHomeWidgetState(exactAlarmGranted = true))
        assertFalse(granted.flattenedIds().contains("homeWidget.preview.alarmBanner"))

        val denied = spec(SettingsHomeWidgetState(exactAlarmGranted = false))
            .flatten().filterIsInstance<SettingsInline>().last()
        assertEquals("homeWidget.preview.alarmBanner", denied.id)
        assertEquals(InlineKind.CONTROL_CARD, denied.kind)
        assertEquals("homeWidgetExactAlarmBannerTitle", denied.labelKey)
        assertEquals("精确闹钟权限未授予", denied.label)
        assertEquals("homeWidgetExactAlarmBannerText", denied.valueKey)
        assertEquals("缺少闹钟权限，卡片刷新可能延迟", denied.value)
        assertEquals(
            listOf("homeWidgetExactAlarmGrantAction"),
            denied.texts.map { it.key },
        )
        assertEquals(listOf("去授权"), denied.texts.map { it.text })
    }

    // ------------------------------------------------------------- 恢复默认

    @Test
    fun `页尾恢复默认是危险行且作用于 homeWidget`() {
        // settings_reset.dart:175-189（scope）+ :205-218（自带 gap + 危险色）
        val page = spec()
        assertEquals("homeWidget.gap.reset", page.topLevelIds()[14])
        val row = page.row("homeWidget.reset.row")
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertEquals("恢复默认设置", row.title)
        assertEquals("settingsResetDefaultsTitle", row.titleKey)
        assertTrue("恢复默认必须是危险行", row.destructive)
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals("homeWidget", row.actionTarget)
        // 本页作用域与页面标题不重合，但 settings_reset.dart:226-233 只给
        // appearance / timetablePage 两句说明，homeWidget 不加副标题
        assertNull(row.subtitle)
    }

    // ------------------------------------------------------------ 纯函数行为

    @Test
    fun `卡片高度的值标签边界`() {
        // 人推：0 → 默认；+1 → 更高 1dp；-1 → 更矮 1dp；小数四舍五入
        assertEquals("默认", SettingsHomeWidgetPage.heightAdjustmentLabel(-11.0))
        assertEquals("更高 1dp", SettingsHomeWidgetPage.heightAdjustmentLabel(-10.0))
        assertEquals("更矮 1dp", SettingsHomeWidgetPage.heightAdjustmentLabel(-12.0))
        assertEquals("更高 8dp", SettingsHomeWidgetPage.heightAdjustmentLabel(-3.4))
        // 「默认」只认偏移严格等于 0（Dart :917 `if (offset == 0)`）；
        // -11.4 的偏移是 -0.4，落到「更矮 0dp」——忠实搬运这个取整口径
        assertEquals("更矮 0dp", SettingsHomeWidgetPage.heightAdjustmentLabel(-11.4))
    }

    @Test
    fun `提前量下拉选项构造`() {
        val options = SettingsHomeWidgetPage.countdownLeadOptions()
        assertEquals(10, options.size)
        assertEquals("0", options.first().id)
        assertEquals("始终显示", options.first().label)
        assertEquals("60", options.last().id)
        assertEquals("60 分钟", options.last().label)
    }

    @Test
    fun `倒计时样式下拉覆盖全部枚举值`() {
        assertEquals(12, SettingsHomeWidgetPage.countdownStyleOptions().size)
        assertEquals(
            SettingsHomeWidgetPage.countdownStyleOptions().size,
            SettingsHomeWidgetPage.countdownStyleOptions().map { it.id }.toSet().size,
        )
    }

    @Test
    fun `卡片类型到预览格位的映射`() {
        // settings_home_widget.dart:870-880
        assertEquals("compact", SettingsHomeWidgetPage.pinTargetForType("compact"))
        assertEquals("mini_list", SettingsHomeWidgetPage.pinTargetForType("mini_list"))
        assertEquals("medium", SettingsHomeWidgetPage.pinTargetForType("medium"))
        assertEquals("large", SettingsHomeWidgetPage.pinTargetForType("large"))
        assertEquals("today_strip", SettingsHomeWidgetPage.pinTargetForType("today_strip"))
        assertEquals("today_wide", SettingsHomeWidgetPage.pinTargetForType("today_wide"))
        assertEquals("compact", SettingsHomeWidgetPage.pinTargetForType(null))
        assertEquals("compact", SettingsHomeWidgetPage.pinTargetForType("unknown"))
    }

    @Test
    fun `预览尺寸读数格式`() {
        // home_widget_service.dart:86 `'${w.round()} × ${h.round()} dp'`
        assertEquals("155 × 155 dp", SettingsHomeWidgetPage.sizeLabel(155.0, 155.0))
        assertEquals("173 × 89 dp", SettingsHomeWidgetPage.sizeLabel(172.6, 88.6))
    }

    @Test
    fun `高度偏移与存储值互相换算`() {
        // 滑杆读数是相对默认档 -11 的偏移（:344-352）
        assertEquals(0.0, SettingsHomeWidgetPage.heightOffset(-11.0), 0.0)
        assertEquals(-16.0, SettingsHomeWidgetPage.heightOffset(-27.0), 0.0)
        assertEquals(16.0, SettingsHomeWidgetPage.heightOffset(5.0), 0.0)
        assertEquals(-3.0, SettingsHomeWidgetPage.storedHeightFromOffset(8.0), 0.0)
        assertEquals(-11.0, SettingsHomeWidgetPage.storedHeightFromOffset(0.0), 0.0)
    }
}
