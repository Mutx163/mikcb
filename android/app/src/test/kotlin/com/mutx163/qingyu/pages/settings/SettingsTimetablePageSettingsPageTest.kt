package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「课表页面设置」页结构契约测试（2026-10-28 补口时建立）。
 *
 * ## 这一页为什么值得单独钉
 *
 * 它是 `l4-recon` 逐页核对时查出的三处「台账虚标」之一：入口行一直在、
 * 路由字符串一直指着 `/settings/timetable-page`，但**落点不存在**——
 * 设置族 20 页共用一个 `SettingsPageScreen(spec)`，所以「没写页面函数」和
 * 「没写页面」在人工登记里长得一模一样，谁看进度表都发现不了。
 *
 * 因此本文件钉的是三件事：
 * 1. 页面**结构**（分区顺序、条件行、禁用态、作用域）与 Dart 逐条对齐；
 * 2. 每一处**读数格式**（Dart 的 `toStringAsFixed` / `round()`）都由人推的期望值钉住，
 *    不是从实现里抄的；
 * 3. 页面私有状态与 `SettingsResetPage.TIMETABLE_PAGE.fields` 的对应关系可核对。
 */
class SettingsTimetablePageSettingsPageTest {

    private fun spec(supported: Boolean = true) = SettingsTimetablePageSettingsPage.spec(
        TimetablePageSettingsState(screenshotShareSupported = supported),
    )

    // ------------------------------------------------------------------ 骨架

    @Test
    fun `顶层分区顺序与 Dart 一致`() {
        // Dart :167 密度 → :298 回到当前周 → :327 背景 → :419 玻璃材质
        // → :394 文字颜色 → :399 恢复默认（偶数索引是 12dp 空档）
        assertEquals(
            listOf(
                "timetablePage.label.density",
                "timetablePage.density",
                "timetablePage.gap.backToWeek",
                "timetablePage.label.backToWeek",
                "timetablePage.backToWeek",
                "timetablePage.gap.background",
                "timetablePage.label.background",
                "timetablePage.background",
                "timetablePage.gap.glass",
                "timetablePage.label.glass",
                "timetablePage.glass",
                "timetablePage.gap.textColors",
                "timetablePage.textColors",
                "timetablePage.gap.reset",
                "timetablePage.reset",
            ),
            spec().topLevelIds(),
        )
    }

    @Test
    fun `预览区与可调项是四六分且顶栏大标题不折叠`() {
        // Dart :105-153：Expanded(flex: 4) 预览 + Expanded(flex: 6) 列表；
        // :102 collapsibleLargeTitle: false
        val page = spec()
        assertEquals(false, page.collapsibleLargeTitle)
        assertEquals(4, page.previewFlex)
        assertEquals(6, page.contentFlex)
    }

    @Test
    fun `密度组行顺序与 Dart 一致`() {
        assertEquals(
            listOf(
                "timetablePage.autoFit",
                "timetablePage.hideWeekends",
                "timetablePage.showOtherWeeks",
                "timetablePage.longPressEmptySlot",
                "timetablePage.weekGridExams",
                "timetablePage.weekGridSchedules",
                "timetablePage.screenshotShare",
                "timetablePage.timeColumnDisplay",
                "timetablePage.timeColumnWidth",
                "timetablePage.sectionHeight",
                "timetablePage.courseCardGap",
            ),
            spec(supported = true).group("timetablePage.density").childRowIds(),
        )
    }

    @Test
    fun `设备不支持截屏回调时那一行整行不出现而不是禁用`() {
        // Dart :227 `if (_screenshotShareSupported)` —— 不支持的平台**不展示**这个开关，
        // 「免得留给用户一个点了没反应的开关」。禁用态与不出现是两种不同的产品决定，
        // 所以这里分开断言，而不是只断言"没有崩溃"。
        val unsupported = spec(supported = false)
        assertFalse(
            "不支持截屏时不该出现这一行",
            unsupported.rows().any { it.id == "timetablePage.screenshotShare" },
        )
        val supported = spec(supported = true)
        val row = supported.row("timetablePage.screenshotShare")
        assertTrue("支持时必须出现且可用", row.enabled)
    }

    @Test
    fun `行 id 全页唯一`() {
        val ids = spec().flattenedIds()
        val dup = ids.groupingBy { it }.eachCount().filterValues { it > 1 }.keys
        assertEquals("重复的节点 id 会让 LazyColumn 的 key 撞车", emptySet<String>(), dup)
    }

    // ------------------------------------------------------------------ 纯逻辑（期望值人推）

    @Test
    fun `自动充满高度开着时行高滑杆禁用`() {
        // Dart :270 `enabled: !_draft.timetableAutoFitSectionHeight`
        assertFalse(
            "自动充满高度开着时，手调行高没有意义，必须是禁用态",
            SettingsTimetablePageSettingsPage.sectionHeightSliderEnabled(true),
        )
        assertTrue(SettingsTimetablePageSettingsPage.sectionHeightSliderEnabled(false))
    }

    @Test
    fun `自动充满高度时行高行确实是禁用态而不只是判据函数正确`() {
        // 上面那条钉的是函数；这条钉的是**接线**——函数对了但没接进行里，
        // 上一照样绿。这类"判据存在但没接上"是迁移里最常见的半失效。
        val autoFitOn = SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(autoFitSectionHeight = true),
        )
        assertFalse(autoFitOn.row("timetablePage.sectionHeight").enabled)
        val autoFitOff = SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(autoFitSectionHeight = false),
        )
        assertTrue(autoFitOff.row("timetablePage.sectionHeight").enabled)
    }

    @Test
    fun `节次高度读数取整到整数`() {
        // Dart :271 `toStringAsFixed(0)`
        assertEquals("48", SettingsTimetablePageSettingsPage.sectionHeightLabel(48.0))
        assertEquals("64", SettingsTimetablePageSettingsPage.sectionHeightLabel(64.0))
        assertEquals("92", SettingsTimetablePageSettingsPage.sectionHeightLabel(92.0))
        assertEquals("63", SettingsTimetablePageSettingsPage.sectionHeightLabel(63.4))
    }

    @Test
    fun `课程卡间距读数保留一位小数`() {
        // Dart :284 `toStringAsFixed(1)` —— 间距是 0.5 一档的，取整会把 1.5 显示成 2
        assertEquals("0.0", SettingsTimetablePageSettingsPage.cardGapLabel(0.0))
        assertEquals("1.5", SettingsTimetablePageSettingsPage.cardGapLabel(1.5))
        assertEquals("3.0", SettingsTimetablePageSettingsPage.cardGapLabel(3.0))
    }

    @Test
    fun `浮钮不透明度读数是四舍五入的整数百分比`() {
        // Dart :309 `'${(value * 100).round()}%'`
        assertEquals("100%", SettingsTimetablePageSettingsPage.opacityPercentLabel(1.0))
        assertEquals("55%", SettingsTimetablePageSettingsPage.opacityPercentLabel(0.55))
        assertEquals("56%", SettingsTimetablePageSettingsPage.opacityPercentLabel(0.556))
    }

    @Test
    fun `色板判据大小写不敏感且不认色板外的颜色`() {
        assertTrue(SettingsTimetablePageSettingsPage.isPaletteColor("#f8fafc"))
        assertTrue(SettingsTimetablePageSettingsPage.isPaletteColor("#F8FAFC"))
        assertFalse(SettingsTimetablePageSettingsPage.isPaletteColor("#123456"))
    }

    @Test
    fun `背景色板六个色值与 Dart 逐字一致`() {
        // Dart :53-60 `_backgroundColors`
        assertEquals(
            listOf("#F8FAFC", "#F7F7F5", "#FDF6EC", "#F2F7FF", "#F5F3FF", "#ECFDF5"),
            SettingsTimetablePageSettingsPage.BACKGROUND_COLORS,
        )
    }

    @Test
    fun `背景区含色板块与四行且顺序与 Dart 一致`() {
        assertEquals(
            listOf(
                "timetablePage.background.colorChips",
                "timetablePage.background.image",
                "timetablePage.background.recent",
                "timetablePage.background.followsWeek",
                "timetablePage.background.blur",
            ),
            spec().group("timetablePage.background").childIds(),
        )
    }

    @Test
    fun `壁纸模糊为 0 档时读数写关闭而不是 0`() {
        // 0 档是"完全没有模糊"，显示成「0」会让人以为还有一点点糊
        val off = SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(wallpaperBlurSigma = 0.0),
        ).row("timetablePage.background.blur")
        assertEquals("关闭", off.value)
        val on = SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(wallpaperBlurSigma = 12.0),
        ).row("timetablePage.background.blur")
        assertEquals("12", on.value)
    }

    @Test
    fun `存量越界的模糊值被夹回收口带`() {
        // 旧存档 / 手改 JSON 可能给出越界值；拇指与数字夹回，与出图侧同口径
        val huge = SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(wallpaperBlurSigma = 999.0),
        ).row("timetablePage.background.blur")
        assertEquals(24.0, huge.sliderValue!!, 1e-9)
        val negative = SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(wallpaperBlurSigma = -5.0),
        ).row("timetablePage.background.blur")
        assertEquals("关闭", negative.value)
    }

    @Test
    fun `文字颜色三行都是色块行且不受课卡联动开关影响`() {
        // page 作用域的三行没有 enabled 判据：联动开关只管课卡那两行
        val rows = spec().group("timetablePage.textColors").children
        assertEquals(3, rows.size)
        for (node in rows) {
            val row = node as SettingsRow
            assertEquals(MiuixRowComponent.COLOR_SWATCH, row.component)
            assertTrue("page 作用域的文字色行不该被禁用", row.enabled)
        }
        assertEquals(
            listOf(
                "timetablePage.textColors.weekday",
                "timetablePage.textColors.weekdayAccent",
                "timetablePage.textColors.timeAxis",
            ),
            spec().group("timetablePage.textColors").childRowIds(),
        )
    }

    @Test
    fun `恢复默认行指向课表页面作用域且是破坏性操作`() {
        val row = spec().row("timetablePage.reset.row")
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals(SettingsTimetablePageSettingsPage.RESET_SCOPE_TIMETABLE_PAGE, row.actionTarget)
        assertTrue("恢复默认要二次确认，行本身必须标破坏性", row.destructive)
    }

    @Test
    fun `玻璃材质区只有一条入口行`() {
        // Dart :407-413：质感方案 / 玻璃档位 / 各表面材质图 2026-09-19 整体划给
        // 「外观编辑」页，本页只留保证一键可达的那一条入口
        assertEquals(
            listOf("timetablePage.glass.appearanceEditor"),
            spec().group("timetablePage.glass").childRowIds(),
        )
        assertEquals(
            SettingsAppearancePage.ROUTE_APPEARANCE_EDITOR,
            spec().row("timetablePage.glass.appearanceEditor").actionTarget,
        )
    }

    @Test
    fun `两个下拉的选项 id 与 Dart 枚举名一致`() {
        assertEquals(
            listOf("hidden", "startOnly", "startAndEnd"),
            PageSectionTimeDisplayMode.entries.map { it.value },
        )
        assertEquals(
            listOf("narrow", "wide"),
            PageTimeColumnWidthMode.entries.map { it.value },
        )
        val page = spec()
        assertEquals(
            "startAndEnd",
            page.row("timetablePage.timeColumnDisplay").selectedOptionId,
        )
        assertEquals("narrow", page.row("timetablePage.timeColumnWidth").selectedOptionId)
    }

    @Test
    fun `滑杆区间与 Dart 的 min max divisions 逐条一致`() {
        val page = spec()
        val height = page.row("timetablePage.sectionHeight").slider!!
        assertEquals(48.0, height.min, 1e-9)
        assertEquals(92.0, height.max, 1e-9)
        assertEquals(11, height.divisions)

        val gap = page.row("timetablePage.courseCardGap").slider!!
        assertEquals(0.0, gap.min, 1e-9)
        assertEquals(3.0, gap.max, 1e-9)
        assertEquals(12, gap.divisions)

        val opacity = page.row("timetablePage.backToWeek.opacity").slider!!
        assertEquals(0.55, opacity.min, 1e-9)
        assertEquals(9, opacity.divisions)
    }
}
