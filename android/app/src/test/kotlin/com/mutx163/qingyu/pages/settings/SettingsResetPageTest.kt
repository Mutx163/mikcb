package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「恢复默认」页（`lib/screens/settings/settings_reset.dart`）结构测试。
 *
 * 期望值来源：Dart 源（五个作用域各自的字段清单 / 说明文案 / 确认弹窗正文）+ ARB，
 * 不从 Kotlin 实现倒推。
 *
 * ## 这个 Dart 文件在做什么
 *
 * 它不产一页独立界面，而是产一个「恢复默认」白卡（`SettingsResetTile`），
 * 被**五张设置页**分别摆在页尾：课程卡片 / 课表页面 / 外观与配色 / 首页与导航 / 桌面小组件。
 *
 * 关键设计（本测试要钉住的三条）：
 * 1. **作用域字段两两不重叠**——在 A 页恢复默认不许动 B 页的东西；
 * 2. **逐字段显式列出**，整页替换会把课程数据/时间模板一起清掉（:41-44 的注释）；
 * 3. **可空字段必须走 clear 标记**——`copyWith` 对可空字段是 `??` 语义，传 null 等于「不改」
 *    （:135-144 的事故记录：那条缺陷让「恢复默认」留下用户那套参数）。
 *
 * ## 本页 spec 的口径
 *
 * Flutter 侧没有「恢复默认」独立页，所以 [SettingsResetPage.spec] 的定位是
 * **全部作用域的对照视图**（五张卡按 Dart 的枚举顺序排开），供文案对拍与人工核对；
 * 真实使用时每张设置页调 [SettingsResetPage.resetCard] 取自己那一段。
 */
class SettingsResetPageTest {

    private fun spec() = SettingsResetPage.spec(SettingsPageState())

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 settingsResetDefaultsTitle`() {
        // settings_reset.dart:213 `title: l10n.settingsResetDefaultsTitle`
        val page = spec()
        assertEquals("settings-reset", page.id)
        assertEquals("settingsResetDefaultsTitle", page.titleKey)
        assertEquals("恢复默认设置", page.title)
    }

    @Test
    fun `五个作用域按 Dart 枚举顺序排列 各一张卡`() {
        // settings_reset.dart:18-33 的 SettingsResetScope 声明顺序
        assertEquals(
            listOf(
                "reset.courseCard",
                "reset.timetablePage",
                "reset.appearance",
                "reset.homeNavigation",
                "reset.homeWidget",
            ),
            spec().flatten()
                .filterIsInstance<SettingsGroup>()
                .filter { it.id.startsWith("reset.") }
                .map { it.id },
        )
    }

    @Test
    fun `每张卡自带上方的十二 dp 空档`() {
        // :209 `const HyperosSectionGap()` —— SettingsResetTile 自己带一个，宿主还会再插一个
        // （外观页因此有两个连着的空档，见 SettingsAppearancePage 的注释）
        val gaps = spec().flatten().filterIsInstance<SettingsGap>()
            .filter { it.id.startsWith("reset.") && it.id.endsWith(".gap") }
        assertEquals(
            listOf(
                "reset.courseCard.gap",
                "reset.timetablePage.gap",
                "reset.appearance.gap",
                "reset.homeNavigation.gap",
                "reset.homeWidget.gap",
            ),
            gaps.map { it.id },
        )
        gaps.forEach { assertEquals(SECTION_GAP_DP, it.heightDp, 0.0) }
    }

    @Test
    fun `每张卡只有一个行 且是危险操作`() {
        // :205-220 每张卡就是一个 HyperosListTile，:257 传 destructive: true
        spec().flatten().filterIsInstance<SettingsGroup>().forEach { group ->
            assertEquals("卡 ${group.id} 应只有一行", 1, group.childRowIds().size)
            val row = group.children.filterIsInstance<SettingsRow>().single()
            assertTrue("行 ${row.id} 必须标 destructive", row.destructive)
            assertEquals(MiuixRowComponent.ARROW, row.component)
            assertEquals(SettingsAction.RESET_SCOPE, row.action)
        }
    }

    @Test
    fun `每张卡指向自己的作用域`() {
        val rows = spec().rows().associateBy { it.id }
        assertEquals("courseCard", rows["reset.courseCard.row"]!!.actionTarget)
        assertEquals("timetablePage", rows["reset.timetablePage.row"]!!.actionTarget)
        assertEquals("appearance", rows["reset.appearance.row"]!!.actionTarget)
        assertEquals("homeNavigation", rows["reset.homeNavigation.row"]!!.actionTarget)
        assertEquals("homeWidget", rows["reset.homeWidget.row"]!!.actionTarget)
    }

    // --------------------------------------------------- 作用域说明（仅两页有）

    @Test
    fun `只有外观与课表页在标题下有作用域说明`() {
        // :226-233 `_scopeNote`：appearance / timetablePage 有，其余 null
        val rows = spec().rows().associateBy { it.id }
        assertEquals("settingsResetScopeNoticeAppearance", rows["reset.appearance.row"]!!.subtitleKey)
        assertEquals("主题、字体与玻璃质感", rows["reset.appearance.row"]!!.subtitle)
        assertEquals("settingsResetScopeNoticeTimetablePage", rows["reset.timetablePage.row"]!!.subtitleKey)
        assertEquals("课表显示与背景 含清除壁纸", rows["reset.timetablePage.row"]!!.subtitle)
        assertNull(rows["reset.courseCard.row"]!!.subtitle)
        assertNull(rows["reset.homeNavigation.row"]!!.subtitle)
        assertNull(rows["reset.homeWidget.row"]!!.subtitle)
    }

    // -------------------------------------------------------- 确认弹窗正文

    @Test
    fun `确认弹窗正文按作用域各说一句`() {
        // :237-247 `_confirmBody`：五个 scope 各自一句，不用「重置所有设置」糊过去
        assertEquals(
            "将把课程卡片的显示字段、布局与颜色恢复为默认值。",
            SettingsResetScope.COURSE_CARD.confirmBody?.zh,
        )
        assertEquals(
            "课表密度、回到本周按钮及背景设置将恢复默认，并清除壁纸。",
            SettingsResetScope.TIMETABLE_PAGE.confirmBody?.zh,
        )
        assertEquals(
            "将把主题模式、字体、主题色与玻璃质感恢复为默认值。",
            SettingsResetScope.APPEARANCE.confirmBody?.zh,
        )
        assertEquals(
            "将把底栏与首页标题设置恢复为默认值。",
            SettingsResetScope.HOME_NAVIGATION.confirmBody?.zh,
        )
        assertEquals(
            "将把桌面小组件的显示项与外观恢复为默认值。",
            SettingsResetScope.HOME_WIDGET.confirmBody?.zh,
        )
    }

    @Test
    fun `确认弹窗的标题按钮与语气`() {
        // :251-258 `showHyperosConfirmDialog(title:, message:, cancelLabel:, confirmLabel:, destructive: true)`
        val dialog = spec().flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "reset.confirmDialog" }
        assertEquals("settingsResetDefaultsConfirmTitle", dialog.labelKey)
        assertEquals("确认恢复", dialog.label)
        assertEquals("settingsResetDefaultsTitle", dialog.valueKey)
        assertEquals("恢复默认设置", dialog.value)
        val buttons = dialog.texts.map { it.text }
        assertEquals(listOf("取消", "恢复默认设置"), buttons)
        assertTrue("确认弹窗必须声明为危险操作", dialog.note.contains("destructive"))
    }

    @Test
    fun `重置完成提示取自 settingsResetDoneMessage`() {
        // :294 `showAppLightTip(context, message: l10n.settingsResetDoneMessage)`
        assertEquals("设置已重置", SettingsStringsExt4.settingsResetDoneMessage.zh)
        assertEquals("settingsResetDoneMessage", SettingsResetPage.DONE_MESSAGE_KEY)
    }

    // ---------------------------------------------------------- 作用域字段表

    @Test
    fun `课程卡片作用域逐字段列出二十项`() {
        // :50-73
        assertEquals(
            listOf(
                "courseCardShowName",
                "courseCardShowTeacher",
                "courseCardShowLocation",
                "courseCardShowTime",
                "courseCardShowTimeLabels",
                "courseCardShowWeeks",
                "courseCardShowDescription",
                "courseCardVerticalAlign",
                "courseCardHorizontalAlign",
                "courseCardFontSize",
                "compactFontSize",
                "timetableUseUnifiedCardColor",
                "timetableUnifiedCardColor",
                "showConflictBadgeOnTimetable",
                "timetableConflictCourseOpacity",
                "linkCourseCardColors",
                "courseCardTitleColorLight",
                "courseCardTitleColorDark",
                "courseCardDetailColorLight",
                "courseCardDetailColorDark",
            ),
            SettingsResetScope.COURSE_CARD.fields,
        )
    }

    @Test
    fun `课表页面作用域含壁纸清空标记`() {
        // :74-122，其中 :116-117 两个 clear 标记负责真的清掉壁纸指针
        val fields = SettingsResetScope.TIMETABLE_PAGE.fields
        assertEquals(23, fields.size)
        assertTrue(fields.contains("sectionHeight"))
        assertTrue(fields.contains("homePageWallpaperBlurSigma"))
        assertEquals(
            listOf("clearHomePageWallpaperPath", "clearHomePageBackgroundImagePath"),
            SettingsResetScope.TIMETABLE_PAGE.clearFlags,
        )
        // 材质轴 2026-09-22 已划给「外观」，本页不该再碰（:99-104 的注释）
        listOf("frostedBlurEnabled", "liquidGlassPreset", "courseCardSurfaceStyle").forEach { field ->
            assertFalse("课表页不该重置材质字段 $field", fields.contains(field))
        }
    }

    @Test
    fun `外观作用域把材质轴整套收进来且可空字段走 clear 标记`() {
        // :128-157；:139-150 三段注释解释了为什么必须 clear 而不是传 null
        val fields = SettingsResetScope.APPEARANCE.fields
        assertTrue("主题三项", fields.containsAll(listOf("appThemeMode", "appFontMode", "themeSeedColor")))
        assertTrue("材质轴", fields.containsAll(listOf("frostedBlurEnabled", "liquidGlassPreset")))
        assertTrue("卡片材质", fields.contains("courseCardSurfaceStyle"))
        assertEquals(
            listOf("clearLiquidGlassTuning", "clearLiquidGlassTuningDark", "clearCourseCardGlassTuning"),
            SettingsResetScope.APPEARANCE.clearFlags,
        )
    }

    @Test
    fun `首页与导航作用域含清空圆钮图标标记`() {
        // :162-174
        assertEquals(
            listOf(
                "homeNavigationForm",
                "glassDockActions",
                "glassDockShowAddButton",
                "glassDockButtonEntryId",
                "homeTitleStyle",
            ),
            SettingsResetScope.HOME_NAVIGATION.fields,
        )
        assertEquals(
            listOf("clearGlassDockButtonIconName"),
            SettingsResetScope.HOME_NAVIGATION.clearFlags,
        )
    }

    @Test
    fun `桌面小组件作用域含四个此前漏掉的可调项`() {
        // :175-189；:182-184 记录「原先漏在范围外」的四项
        assertEquals(
            listOf(
                "widgetBackgroundStyle",
                "widgetCourseAccentMode",
                "widgetShowLocation",
                "widgetShowCountdown",
                "widgetHideCompletedCourses",
                "widgetShowTomorrowCourses",
                "widgetCountdownLeadMinutes",
                "widgetCountdownTextStyle",
                "widgetHeightAdjustment",
                "widgetCornerRadius",
            ),
            SettingsResetScope.HOME_WIDGET.fields,
        )
    }

    @Test
    fun `五个作用域的字段两两不重叠`() {
        // :41-44 「作用域之间字段不重叠：同一个字段只会属于一页」
        val seen = mutableMapOf<String, SettingsResetScope>()
        val clashes = mutableListOf<String>()
        SettingsResetScope.entries.forEach { scope ->
            scope.fields.forEach { field ->
                val previous = seen.put(field, scope)
                if (previous != null) clashes += "$field（${previous.name} 与 ${scope.name}）"
            }
        }
        assertTrue("这些字段同时属于两个作用域：$clashes", clashes.isEmpty())
    }

    @Test
    fun `没有任何作用域去碰课程数据与账号绑定`() {
        // :15-17 「保证不会顺手把课程数据、时间模板、账号绑定一起清掉」
        val forbidden = listOf(
            "sections",
            "courses",
            "coursesJson",
            "homeGridMenuActions",
            "homeMenuStyle",
            "webdavUrl",
            "webdavPassword",
            "webdavUsername",
        )
        val touched = SettingsResetScope.entries
            .flatMap { it.fields + it.clearFlags }
            .filter { it in forbidden }
        assertEquals("这些字段不该被任何作用域重置：$touched", emptyList<String>(), touched)
    }

    @Test
    fun `菜单形态与菜单内容刻意不纳入`() {
        // :169-174 注释：copyWith 会把空表过一遍 normalize，把 [] 变成 ['settings']
        SettingsResetScope.entries.forEach { scope ->
            assertFalse(
                "作用域 ${scope.name} 不该动 homeMenuStyle",
                scope.fields.contains("homeMenuStyle"),
            )
            assertFalse(
                "作用域 ${scope.name} 不该动 homeGridMenuActions",
                scope.fields.contains("homeGridMenuActions"),
            )
        }
    }

    @Test
    fun `最近使用的壁纸历史不被重置`() {
        // :118-121 「⚠️ 最近使用不清：它是设备级全局历史」
        SettingsResetScope.entries.forEach { scope ->
            assertFalse(
                "作用域 ${scope.name} 不该碰最近使用壁纸",
                scope.fields.any { it.contains("WallpaperHistory") || it == "recentWallpapers" },
            )
        }
    }

    // -------------------------------------------------------- 单张卡的取用

    @Test
    fun `单页取用只拿到自己那一段`() {
        // :205-220 每页把自己的 scope 传给 SettingsResetTile
        val nodes = SettingsResetPage.resetCard(SettingsResetScope.COURSE_CARD)
        // 自带一个 12dp 空档（:209 `const HyperosSectionGap()`）+ 一张卡
        assertEquals(listOf("reset.courseCard.gap", "reset.courseCard"), nodes.map { it.id })
        assertEquals(SECTION_GAP_DP, (nodes.first() as SettingsGap).heightDp, 0.0)
        val row = (nodes.last() as SettingsGroup).children.filterIsInstance<SettingsRow>().single()
        assertEquals("courseCard", row.actionTarget)
        assertTrue(row.destructive)
        // 课卡作用域与页面标题重合 → 标题下不加作用范围说明（:226-233「宁少勿多」）
        assertNull(row.subtitle)
    }

    @Test
    fun `作用域行 id 与卡 id 一一对应`() {
        SettingsResetScope.entries.forEach { scope ->
            val nodes = SettingsResetPage.resetCard(scope)
            val group = nodes.filterIsInstance<SettingsGroup>().single()
            assertEquals("reset.${scope.arg}", group.id)
            assertEquals("reset.${scope.arg}.row", group.childRowIds().single())
        }
    }

    @Test
    fun `作用域参数名与 Dart 枚举名逐字一致`() {
        // settings_reset.dart:18-33
        assertEquals(
            listOf("courseCard", "timetablePage", "appearance", "homeNavigation", "homeWidget"),
            SettingsResetScope.entries.map { it.arg },
        )
    }
}
