package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程卡片设置页（`lib/screens/settings/settings_course_card.dart`）结构测试。
 *
 * 该页还有两块由别的文件渲染、但**渲染在这一页上**的内容，一并对照：
 * - `lib/widgets/timetable_text_color_settings.dart`（文字颜色区块，scope=courseCard）
 * - `lib/screens/settings/settings_reset.dart`（页尾恢复默认，scope=courseCard）
 * 期望值来源：Dart 源 + ARB。
 */
class SettingsCourseCardPageTest {

    private fun spec(state: SettingsPageState = SettingsPageState()) =
        SettingsCourseCardPage.spec(state)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题与不折叠大标题`() {
        // settings_course_card.dart:76-81（collapsibleLargeTitle: false，预览不在顶栏下）
        val page = spec()
        assertEquals("settings-course-card", page.id)
        assertEquals("courseCardSettingsTitle", page.titleKey)
        assertEquals("课程卡片", page.title)
        assertFalse(page.collapsibleLargeTitle)
    }

    @Test
    fun `预览四成可调项六成`() {
        // :84-125（flex 4 / flex 6，小屏上 50:50 只剩三四行可见）
        val page = spec()
        assertEquals(4, page.previewFlex)
        assertEquals(6, page.contentFlex)
    }

    @Test
    fun `八个区块的节点顺序`() {
        // :131-341：0 显示字段 · 1 开关组 · 2 空档 · 3 布局 · 4 空档 · 5 颜色 ·
        // 6 文字颜色（自带前导空档）· 7 恢复默认（自带空档）
        assertEquals(
            listOf(
                "courseCard.fields.label",
                "courseCard.fields",
                "courseCard.gap.layout",
                "courseCard.layout.label",
                "courseCard.layout",
                "courseCard.gap.color",
                "courseCard.color.label",
                "courseCard.color",
                "courseCard.gap.textColors",
                "courseCard.textColors.label",
                "courseCard.textColors",
                "courseCard.gap.textColors.afterLink",
                "courseCard.gap.light",
                "courseCard.textColors.light.label",
                "courseCard.textColors.light",
                "courseCard.gap.textColors.afterLight",
                "courseCard.gap.dark",
                "courseCard.textColors.dark.label",
                "courseCard.textColors.dark",
                "courseCard.gap.reset",
                "courseCard.reset",
            ),
            spec().topLevelIds(),
        )
    }

    @Test
    fun `文字颜色两处空档是双份`() {
        // 忠实搬运 timetable_text_color_settings.dart:86+90、:130+133：
        // 12dp 的 SizedBox 与 12dp 的 HyperosSectionGap 各一次 → 24dp
        val ids = spec().topLevelIds()
        val light = ids.indexOf("courseCard.textColors.light.label")
        assertEquals("courseCard.gap.textColors.afterLink", ids[light - 2])
        assertEquals("courseCard.gap.light", ids[light - 1])
        val dark = ids.indexOf("courseCard.textColors.dark.label")
        assertEquals("courseCard.gap.textColors.afterLight", ids[dark - 2])
        assertEquals("courseCard.gap.dark", ids[dark - 1])
    }

    // ------------------------------------------------------------ 显示字段

    @Test
    fun `显示字段七行顺序`() {
        // :137-194
        assertEquals("courseCardSectionFields", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "courseCard.fields.label" }.textKey)
        assertEquals(
            listOf(
                "courseCard.show.name",
                "courseCard.show.teacher",
                "courseCard.show.location",
                "courseCard.show.time",
                "courseCard.show.timeLabels",
                "courseCard.show.weeks",
                "courseCard.show.description",
            ),
            spec().group("courseCard.fields").childRowIds(),
        )
    }

    @Test
    fun `显示字段七行的文案与默认开关`() {
        // 文案 :141-192；默认值 timetable_settings.dart:765-771
        val page = spec()
        val expected = listOf(
            Triple("courseCard.show.name", "显示课程名", true),
            Triple("courseCard.show.teacher", "显示教师", true),
            Triple("courseCard.show.location", "显示教室", true),
            Triple("courseCard.show.time", "显示时间", false),
            Triple("courseCard.show.timeLabels", "显示上下课字样", true),
            Triple("courseCard.show.weeks", "显示周数", false),
            Triple("courseCard.show.description", "显示课程简介", false),
        )
        expected.forEach { (id, title, default) ->
            val row = page.row(id)
            assertEquals(title, row.title)
            assertEquals("$id 应是开关行", MiuixRowComponent.SWITCH, row.component)
            assertEquals("$id 的默认开关态", default, row.switchValue)
        }
        assertTrue("显示字段组七行都无副标题", page.group("courseCard.fields").children
            .filterIsInstance<SettingsRow>().all { it.subtitle == null })
    }

    @Test
    fun `上下课字样随显示时间联动`() {
        // :168-178：courseCardShowTime 为 false 时 onChanged 传 null → 行禁用
        assertFalse(spec(SettingsPageState(courseCardShowTime = false)).row("courseCard.show.timeLabels").enabled)
        assertTrue(spec(SettingsPageState(courseCardShowTime = true)).row("courseCard.show.timeLabels").enabled)
        // 反向：其余六行不受影响
        val page = spec(SettingsPageState(courseCardShowTime = false))
        assertEquals(
            listOf("courseCard.show.timeLabels"),
            page.group("courseCard.fields").children.filterIsInstance<SettingsRow>()
                .filter { !it.enabled }.map { it.id },
        )
    }

    // ---------------------------------------------------------------- 布局

    @Test
    fun `布局组五行`() {
        // :197-266
        assertEquals("courseCardSectionLayout", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "courseCard.layout.label" }.textKey)
        assertEquals(
            listOf(
                "courseCard.surfaceStyle",
                "courseCard.verticalAlign",
                "courseCard.horizontalAlign",
                "courseCard.cardFontSize",
                "courseCard.compactFontSize",
            ),
            spec().group("courseCard.layout").childRowIds(),
        )
    }

    @Test
    fun `卡片外观是跳转牌不是选择器`() {
        // :204-214（2026-09-25 入口收敛：三档与八根旋钮只在材质面板里调）
        val row = spec(SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS))
            .row("courseCard.surfaceStyle")
        assertEquals("卡片外观", row.title)
        assertEquals("courseCardSurfaceStyleLiquidGlass", row.detailsKey)
        assertEquals("液态玻璃", row.details)
        assertTrue("跳转牌不是下拉", row.options.isEmpty())
        assertEquals(SettingsAction.MATERIAL_PANEL, row.action)
        assertEquals("实体卡片", spec(SettingsPageState()).row("courseCard.surfaceStyle").details)
    }

    @Test
    fun `垂直与水平排版选项`() {
        // :215-238
        val vertical = spec(SettingsPageState(courseCardVerticalAlign = CourseCardVerticalAlign.BOTTOM))
            .row("courseCard.verticalAlign")
        assertEquals("垂直排版", vertical.title)
        assertEquals(listOf("顶部对齐", "垂直居中", "底部对齐", "上下均布"), vertical.options.map { it.label })
        assertEquals(listOf("top", "center", "bottom", "space_evenly"), vertical.options.map { it.id })
        assertEquals("bottom", vertical.selectedOptionId)

        val horizontal = spec(SettingsPageState(courseCardHorizontalAlign = CourseCardHorizontalAlign.RIGHT))
            .row("courseCard.horizontalAlign")
        assertEquals("水平排版", horizontal.title)
        assertEquals(listOf("居左", "居中", "居右"), horizontal.options.map { it.label })
        assertEquals(listOf("left", "center", "right"), horizontal.options.map { it.id })
        assertEquals("right", horizontal.selectedOptionId)
    }

    @Test
    fun `两根字号滑杆上下限`() {
        // :239-262（min 7 / max 12 / divisions 10，读数一位小数）
        val card = spec(SettingsPageState(courseCardFontSize = 9.0)).row("courseCard.cardFontSize")
        assertEquals("课程卡片字号", card.title)
        assertEquals(7.0, card.slider!!.min, 0.0)
        assertEquals(12.0, card.slider!!.max, 0.0)
        assertEquals(10, card.slider!!.divisions)
        assertEquals("9.0", card.value)

        val compact = spec(SettingsPageState(compactFontSize = 7.5)).row("courseCard.compactFontSize")
        assertEquals("紧凑字号", compact.title)
        assertEquals(7.0, compact.slider!!.min, 0.0)
        assertEquals(12.0, compact.slider!!.max, 0.0)
        assertEquals("7.5", compact.value)
    }

    // ---------------------------------------------------------------- 颜色

    @Test
    fun `颜色组结构`() {
        // :269-328
        assertEquals("courseCardSectionColor", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "courseCard.color.label" }.textKey)
        assertEquals(
            listOf(
                "courseCard.unifiedColor",
                "courseCard.recolor",
                "courseCard.conflictBadge",
                "courseCard.conflictOpacity",
            ),
            spec().group("courseCard.color").childRowIds(),
        )
        assertEquals(
            listOf(
                "courseCard.unifiedColor",
                "courseCard.colorChips",
                "courseCard.recolor",
                "courseCard.conflictBadge",
                "courseCard.conflictOpacity",
            ),
            spec(SettingsPageState(timetableUseUnifiedCardColor = true)).group("courseCard.color").childIds(),
        )
    }

    @Test
    fun `统一卡片色开关文案与默认值`() {
        // :276-285；默认 false 见 timetable_settings.dart:901
        val row = spec().row("courseCard.unifiedColor")
        assertEquals("统一课程卡片颜色", row.title)
        assertEquals("unifiedCourseCardColorSubtitle", row.subtitleKey)
        assertEquals("关闭后继续使用每门课程自己的颜色", row.subtitle)
        assertEquals(false, row.switchValue)
        assertEquals(true, spec(SettingsPageState(timetableUseUnifiedCardColor = true))
            .row("courseCard.unifiedColor").switchValue)
    }

    @Test
    fun `统一卡片色色板八色与选中`() {
        // :286-299 + :42-51 的 _cardColors
        val chips = spec(
            SettingsPageState(timetableUseUnifiedCardColor = true, timetableUnifiedCardColor = "#059669"),
        ).flatten().filterIsInstance<SettingsInline>().first { it.id == "courseCard.colorChips" }
        assertEquals(InlineKind.COLOR_CHIP_GROUP, chips.kind)
        assertEquals(
            listOf("#2563EB", "#7C3AED", "#059669", "#DC2626", "#EA580C", "#0891B2", "#4F46E5", "#DB2777"),
            chips.colors,
        )
        assertEquals("#059669", chips.selectedColor)
        assertEquals(
            listOf("#2563EB", "#7C3AED", "#059669", "#DC2626", "#EA580C", "#0891B2", "#4F46E5", "#DB2777"),
            SettingsCourseCardPage.CARD_COLORS,
        )
    }

    @Test
    fun `课表重新配色的跳转牌`() {
        // :301-305
        val row = spec().row("courseCard.recolor")
        assertEquals("课表重新配色", row.title)
        assertEquals("courseRecolorTileSubtitle", row.subtitleKey)
        assertEquals("不用重新导入，可随时换色", row.subtitle)
        assertEquals(SettingsAction.RECOLOR_SHEET, row.action)
    }

    @Test
    fun `冲突角标开关与透明度滑杆`() {
        // :306-326；默认 true / 0.70 见 timetable_settings.dart:763-764
        val badge = spec().row("courseCard.conflictBadge")
        assertEquals("首页显示冲突小胶囊", badge.title)
        assertEquals(true, badge.switchValue)

        val opacity = spec(SettingsPageState(timetableConflictCourseOpacity = 0.7)).row("courseCard.conflictOpacity")
        assertEquals("冲突课程透明度", opacity.title)
        assertEquals(0.2, opacity.slider!!.min, 0.0)
        assertEquals(1.0, opacity.slider!!.max, 0.0)
        assertEquals(16, opacity.slider!!.divisions)
        assertEquals("70%", opacity.value)
    }

    @Test
    fun `课卡页三根滑杆的当前值`() {
        assertEquals(9.0, spec().row("courseCard.cardFontSize").sliderValue!!, 0.0)
        assertEquals(7.5, spec(SettingsPageState(compactFontSize = 7.5)).row("courseCard.compactFontSize").sliderValue!!, 0.0)
        assertEquals(0.70, spec().row("courseCard.conflictOpacity").sliderValue!!, 1e-9)
        assertEquals(
            0.35,
            spec(SettingsPageState(timetableConflictCourseOpacity = 0.35)).row("courseCard.conflictOpacity").sliderValue!!,
            1e-9,
        )
    }

    @Test
    fun `透明度读数按四舍五入取整百分数`() {
        // :320-321 `'${(opacity * 100).round()}%'`
        assertEquals("20%", SettingsCourseCardPage.conflictOpacityLabel(0.2))
        assertEquals("70%", SettingsCourseCardPage.conflictOpacityLabel(0.70))
        assertEquals("100%", SettingsCourseCardPage.conflictOpacityLabel(1.0))
        assertEquals("35%", SettingsCourseCardPage.conflictOpacityLabel(0.345))
    }

    // ------------------------------------------------------------ 文字颜色

    @Test
    fun `文字颜色区块结构`() {
        // timetable_text_color_settings.dart:50-171（scope=courseCard）
        assertEquals("appearanceTextColorsSectionTitle", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "courseCard.textColors.label" }.textKey)
        assertEquals("themeModeLight", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "courseCard.textColors.light.label" }.textKey)
        assertEquals("themeModeDark", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "courseCard.textColors.dark.label" }.textKey)
        assertEquals(listOf("courseCard.textColors.link"), spec().group("courseCard.textColors").childRowIds())
        assertEquals(
            listOf("courseCard.textColors.light.title", "courseCard.textColors.light.detail"),
            spec().group("courseCard.textColors.light").childRowIds(),
        )
        assertEquals(
            listOf("courseCard.textColors.dark.title", "courseCard.textColors.dark.detail"),
            spec().group("courseCard.textColors.dark").childRowIds(),
        )
    }

    @Test
    fun `独立设置详情颜色开关是取反的`() {
        // timetable_text_color_settings.dart:65-66 `value: !settings.linkCourseCardColors`
        assertEquals(false, spec(SettingsPageState(linkCourseCardColors = true))
            .row("courseCard.textColors.link").switchValue)
        assertEquals(true, spec(SettingsPageState(linkCourseCardColors = false))
            .row("courseCard.textColors.link").switchValue)
        assertEquals("独立设置详情颜色", spec().row("courseCard.textColors.link").title)
    }

    @Test
    fun `详情色行在联动时禁用`() {
        // 同文件 :237 `enabled: !settings.linkCourseCardColors`
        assertFalse(spec(SettingsPageState(linkCourseCardColors = true))
            .row("courseCard.textColors.light.detail").enabled)
        assertTrue(spec(SettingsPageState(linkCourseCardColors = false))
            .row("courseCard.textColors.light.detail").enabled)
        assertTrue("标题色行不受联动影响", spec(SettingsPageState(linkCourseCardColors = true))
            .row("courseCard.textColors.light.title").enabled)
    }

    @Test
    fun `四行颜色行的文案与当前值`() {
        // :224-241
        val page = spec(
            SettingsPageState(
                linkCourseCardColors = false,
                courseCardTitleColor = "#112233",
                courseCardDetailColor = "#445566",
                courseCardTitleColorDark = "#778899",
                courseCardDetailColorDark = "#AABBCC",
            ),
        )
        assertEquals("课程卡片标题颜色", page.row("courseCard.textColors.light.title").title)
        assertEquals("#112233", page.row("courseCard.textColors.light.title").value)
        assertEquals("课程卡片详情颜色", page.row("courseCard.textColors.light.detail").title)
        assertEquals("#445566", page.row("courseCard.textColors.light.detail").value)
        assertEquals("#778899", page.row("courseCard.textColors.dark.title").value)
        assertEquals("#AABBCC", page.row("courseCard.textColors.dark.detail").value)
        assertTrue("颜色行是官方没有对应物的那一类", page.row("courseCard.textColors.light.title").component == MiuixRowComponent.COLOR_SWATCH)
        assertEquals(SettingsAction.COLOR_PICKER, page.row("courseCard.textColors.light.title").action)
    }

    // ------------------------------------------------------------ 恢复默认

    @Test
    fun `课卡页恢复默认行无作用域说明`() {
        // settings_reset.dart:226-233（只有 appearance / timetablePage 有 _scopeNote）
        val row = spec().row("courseCard.reset.row")
        assertEquals("恢复默认设置", row.title)
        assertNull(row.subtitle)
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals("courseCard", row.actionTarget)
        assertTrue(row.destructive)
    }

    @Test
    fun `默认字号读数一位小数`() {
        // :245/:257 `toStringAsFixed(1)`
        assertEquals("9.0", SettingsCourseCardPage.fontSizeLabel(9.0))
        assertEquals("7.5", SettingsCourseCardPage.fontSizeLabel(7.5))
        assertEquals("12.0", SettingsCourseCardPage.fontSizeLabel(12.0))
    }
}
