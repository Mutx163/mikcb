package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P3-B-2 四页的**文案逐字对拍**（ARB 真源：`lib/l10n/app_zh.arb`）。
 *
 * ## 为什么单独一个文件
 *
 * 验收门槛第 3 条要求「新建的每条文案都能在 ARB 里找到」。设置页 90% 的像素
 * 就是文字，「看着差不多」不能靠人眼抽查——这里把四份 spec 的每一处屏上文案
 * 与 ARB 机械比对：键缺失、文案被改写、漏抄一处都会红。
 *
 * 与 `SettingsArbParityTest`（基线 4 页）分开，是因为本批四页由另一条泳道交付、
 * 对应另一份 `SettingsStringsExt2`；两个文件互不依赖，任何一方重写都不会误伤。
 *
 * ## 覆盖面
 *
 * 四份 spec 都取**条件分支最多的状态**（玻璃坞 + 圆钮开 + 有已添加卡片 + 诊断构建），
 * 保证 `if` 里的文案也被走到；另外单独给一份「最小状态」防止只测了满配。
 */
class SettingsHomeWidgetPageStringsParityTest {

    private fun specs(): List<SettingsPageSpec> = listOf(
        // 桌面小组件：最满状态（有卡片 + 有情侣课表 + 未授权闹钟 → 引导条也渲染）
        SettingsHomeWidgetPage.spec(
            SettingsHomeWidgetState(
                widgetInstances = listOf(HomeWidgetInstanceSpec(appWidgetId = 11)),
                profiles = listOf(ProfileSpec(id = "p1", name = "我的课表")),
                partnerProfile = ProfileSpec(id = "ta", name = "TA的课表"),
                exactAlarmGranted = false,
            ),
        ),
        // 首页与导航：玻璃坞 + 圆钮开（底栏四行全出现）
        SettingsHomeNavigationPage.spec(
            SettingsHomeNavigationState(
                navigationForm = "glassDock",
                showAddButton = true,
            ),
        ),
        // 八宫格编辑器：候选非空（四种分类都有内容）
        SettingsHomeMenuEditorPage.spec(
            SettingsHomeMenuEditorState(
                enabledIds = listOf("overview", "statistics", "addCourse", "settings"),
            ),
        ),
        // 课表设置 hub：诊断构建 + 开发者工具全开
        SettingsTimetablePage.spec(
            SettingsTimetableState(
                diagnosticsBuild = true,
                releaseBuild = false,
                semesterStartDate = Triple(2026, 9, 1),
                activeProfileName = "大二上",
                activeTimeSchemeName = "标准作息",
                weatherCityName = "杭州",
                notificationPermissionGranted = true,
                cloudSyncState = "enabled",
                partnerBound = true,
            ),
        ),
        SettingsTimetablePage.semesterSpec(
            SettingsTimetableState(semesterStartDate = Triple(2026, 9, 1), semesterWeekCount = 20),
        ),
    )

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        var checked = 0
        for (spec in specs()) {
            for ((key, text) in spec.allArbTexts()) {
                assertMatchesArb(key, text)
                checked++
            }
        }
        // 防空转：遍历器坏掉（返回空清单）时这条必须红，而不是「零违规 = 绿」
        assertTrue("逐字对照的文案条数太少（$checked），遍历器可能失效", checked >= 120)
    }

    @Test
    fun `spec 里用到的每个 ARB 键都真的存在于 arb`() {
        val keys = specs().flatMap { it.allArbTexts() }.map { it.first }.toSet()
        val missing = keys.filter { !ArbZh.strings.containsKey(it) }
        assertEquals("这些键在 app_zh.arb 里不存在", emptyList<String>(), missing)
    }

    /**
     * `SettingsStringsExt2` 里声明的每一条都必须与 ARB 逐字一致。
     *
     * 这条**独立于 spec**：只要某人改了 Ext2 里的一句文案（哪怕该页暂时没渲染那行），
     * 这里立刻红。反射读不到 `object` 的 val 列表，所以用显式清单 —— 清单与
     * Ext2 的字段一一对应，漏写会被下面「条数」那条发现。
     */
    @Test
    fun `Ext2 的文案表逐条等于 ARB`() {
        val table: List<ArbText> = SettingsStringsExt2.all()
        assertTrue("Ext2 的文案条数太少（${table.size}）", table.size >= 180)
        table.forEach { assertMatchesArb(it.key, it.zh) }
        // 键不得重复（同一键只能有一处真源）
        val dup = table.groupBy { it.key }.filterValues { it.size > 1 }.keys
        assertEquals("Ext2 里重复声明的键", emptySet<String>(), dup)
    }

    @Test
    fun `Ext2 不与共享件 SettingsStrings 重复声明`() {
        val shared = setOf(
            "courseRecolorTileTitle",
            "courseCardSettingsTitle",
            "generalSettingsTitle",
            "settingsResetDefaultsTitle",
        )
        val overlaps = SettingsStringsExt2.all().map { it.key }.filter { it in shared }
        assertEquals("这些键已在 SettingsStrings 里，Ext2 不该重复定义", emptyList<String>(), overlaps)
    }

    /**
     * 占位符模板按「片段按序出现」判定：渲染值允许替换占位符，但不许改写片段本身。
     */
    @Test
    fun `占位符模板按片段比对而不是整串相等`() {
        // 人推的反例：homeGridCustomizeDetails 的渲染值是「已启用 8/8 个」，
        // 与模板「已启用 {count}/{max} 个」不同但必须通过；改掉片段必须红。
        assertMatchesArb("homeGridCustomizeDetails", "已启用 8/8 个")
        assertMatchesArb("semesterOverviewCurrentWeek", "当前第 5 周 / 共 20 周")
        assertEquals("已启用 {count}/{max} 个", ArbZh.value("homeGridCustomizeDetails"))
        assertEquals("当前第 {current} 周 / 共 {total} 周", ArbZh.value("semesterOverviewCurrentWeek"))
        val failed = runCatching { assertMatchesArb("homeGridCustomizeDetails", "已开启 8/8 个") }
        assertTrue("改掉模板片段应当比对失败", failed.isFailure)
    }

    private fun assertMatchesArb(key: String, text: String) {
        val template = ArbZh.value(key)
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
    }
}
