package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 八宫格按钮自定义编辑器（`lib/screens/settings/settings_home_menu_editor.dart`）结构测试。
 *
 * 期望值来源：Dart 源 + ARB，不从实现倒推。
 *
 * 本页最容易被写错的四处：
 * 1. 「已启用」列表里钉住的 `settings` 不可移除（:231-232），但也**不隐藏**；
 * 2. 只剩一个入口时全列不可移除（`_canRemove => _ids.length > 1`，:44）；
 * 3. 候选按分类分组，已启用的不再出现在候选里（:123-130）；
 * 4. 某分类的候选全启用时，给一句「所有入口都已启用」而不是空组（:131-133）。
 */
class SettingsHomeMenuEditorPageTest {

    private fun spec(state: SettingsHomeMenuEditorState = SettingsHomeMenuEditorState()) =
        SettingsHomeMenuEditorPage.spec(state)

    private val defaultIds = listOf("overview", "statistics", "addCourse", "settings")

    private fun defaultState() = SettingsHomeMenuEditorState(enabledIds = defaultIds)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 homeMenuCustomizeTitle`() {
        val page = spec(defaultState())
        assertEquals("settings-home-menu-editor", page.id)
        assertEquals("homeMenuCustomizeTitle", page.titleKey)
        assertEquals("自定义菜单按钮", page.title)
        // settings_home_menu_editor.dart:86 `title: Text(l10n.homeMenuCustomizeTitle)`
    }

    @Test
    fun `顶层区块顺序为预览-已启用-说明-候选-重置`() {
        val ids = spec(defaultState()).topLevelIds()
        // 预览卡 → gap → 「已启用」label → 已启用列表 → 说明句 →
        // 各分类 gap+label+组…… → gap → 恢复默认组
        assertEquals("homeMenuEditor.preview", ids.first())
        assertEquals("homeMenuEditor.gap.preview", ids[1])
        assertEquals("homeMenuEditor.enabled.label", ids[2])
        assertEquals("homeMenuEditor.enabled", ids[3])
        assertEquals("homeMenuEditor.hint", ids[4])
        assertEquals("homeMenuEditor.reset", ids.last())
        assertEquals("homeMenuEditor.gap.reset", ids[ids.size - 2])
    }

    @Test
    fun `已启用列表按当前顺序逐行列出`() {
        // settings_home_menu_editor.dart:202-246
        val page = spec(defaultState())
        assertEquals(
            defaultIds.map { "homeMenuEditor.enabled.$it" },
            page.group("homeMenuEditor.enabled").childRowIds(),
        )
    }

    @Test
    fun `已启用行标题是目录标题`() {
        val page = spec(defaultState())
        val first = page.row("homeMenuEditor.enabled.overview")
        assertEquals("课程总览", first.title)
        assertEquals("homeMenuOverviewTitle", first.titleKey)
        assertEquals("课表设置", page.row("homeMenuEditor.enabled.settings").title)
    }

    @Test
    fun `未知 id 在构造时就被丢弃`() {
        // settings_home_menu_editor.dart:33-38：种子阶段丢 dropped 不可解析 id
        val page = spec(
            SettingsHomeMenuEditorState(
                enabledIds = listOf("overview", "no-such-entry", "settings"),
            ),
        )
        assertEquals(
            listOf("homeMenuEditor.enabled.overview", "homeMenuEditor.enabled.settings"),
            page.group("homeMenuEditor.enabled").childRowIds(),
        )
    }

    // ------------------------------------------------------------ 移除按钮

    @Test
    fun `钉住的课表设置行不可移除且提示不同`() {
        // settings_home_menu_editor.dart:229-243
        val page = spec(defaultState())
        val pinned = page.row("homeMenuEditor.enabled.settings")
        assertEquals(false, pinned.enabled)
        assertEquals("homeGridEditorPinnedTooltip", pinned.trailingActionKey)
        assertEquals("此入口用于重新打开本页，不能移除", pinned.trailingAction)
        assertEquals(SettingsAction.DIALOG, pinned.trailingActionKind)

        val removable = page.row("homeMenuEditor.enabled.overview")
        assertTrue(removable.enabled)
        assertEquals("homeGridEditorRemoveTooltip", removable.trailingActionKey)
        assertEquals("移除", removable.trailingAction)
    }

    @Test
    fun `只剩一个入口时全列不可移除`() {
        // :44 `_canRemove => _ids.length > 1`
        val page = spec(SettingsHomeMenuEditorState(enabledIds = listOf("overview")))
        assertFalse(page.row("homeMenuEditor.enabled.overview").enabled)
        // 提示文案仍是「移除」，因为不可移除的原因不是「钉住」
        assertEquals("homeGridEditorRemoveTooltip", page.row("homeMenuEditor.enabled.overview").trailingActionKey)
    }

    @Test
    fun `两个入口时钉住项仍不可移除另一项可移除`() {
        val page = spec(SettingsHomeMenuEditorState(enabledIds = listOf("overview", "settings")))
        assertTrue(page.row("homeMenuEditor.enabled.overview").enabled)
        assertFalse(page.row("homeMenuEditor.enabled.settings").enabled)
    }

    // ------------------------------------------------------------- 重置行

    @Test
    fun `恢复默认排列回到出厂八项`() {
        // :77-79 `_resetToDefault => _commit(HomeGridMenu.defaultActions)`
        val page = spec(defaultState())
        val row = page.row("homeMenuEditor.reset.row")
        assertEquals("恢复默认排列", row.title)
        assertEquals("homeGridEditorResetAction", row.titleKey)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
        assertEquals(
            listOf("overview", "statistics", "addCourse", "exams", "tasks", "importCourses", "settings", "support"),
            SettingsHomeMenuEditorPage.DEFAULT_ACTIONS,
        )
    }

    // ------------------------------------------------------------- 说明句

    @Test
    fun `槽位上限说明带八`() {
        // :94 `HyperosSectionDescription(text: l10n.homeGridEditorHintBody(_maxSlots))`
        val hint = spec(defaultState()).flatten().filterIsInstance<SettingsDescription>()
            .first { it.id == "homeMenuEditor.hint" }
        assertEquals("homeGridEditorHintBody", hint.textKey)
        assertEquals("最多放 8 个，按住条目可排序", hint.text)
        assertEquals("homeGridEditorEnabledTitle", spec(defaultState()).flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "homeMenuEditor.enabled.label" }.textKey)
        assertEquals("已启用", spec(defaultState()).flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "homeMenuEditor.enabled.label" }.text)
    }

    // ------------------------------------------------------------- 候选分组

    @Test
    fun `候选按四个分类分组且已启用的不出现`() {
        val page = spec(defaultState())
        val groups = page.flatten().filterIsInstance<SettingsGroup>()
            .filter { it.id.startsWith("homeMenuEditor.category.") }
        assertEquals(
            listOf(
                "homeMenuEditor.category.features",
                "homeMenuEditor.category.data",
                "homeMenuEditor.category.preferences",
                "homeMenuEditor.category.about",
            ),
            groups.map { it.id },
        )
        // 已启用的 overview/statistics/addCourse/settings 不能再出现在候选里
        val candidateIds = groups.flatMap { it.children.filterIsInstance<SettingsRow>() }.map { it.id }
        assertFalse(candidateIds.contains("homeMenuEditor.candidate.overview"))
        assertFalse(candidateIds.contains("homeMenuEditor.candidate.statistics"))
        assertFalse(candidateIds.contains("homeMenuEditor.candidate.addCourse"))
        assertFalse(candidateIds.contains("homeMenuEditor.candidate.settings"))
        assertTrue(candidateIds.contains("homeMenuEditor.candidate.update"))
        assertTrue(candidateIds.contains("homeMenuEditor.candidate.dataTransfer"))
    }

    @Test
    fun `分类小标题文案`() {
        val labels = spec(defaultState()).flatten().filterIsInstance<SettingsLabel>()
            .filter { it.id.startsWith("homeMenuEditor.category.") }
        assertEquals(
            listOf("功能入口", "数据与同步", "偏好设置", "关于与支持"),
            labels.map { it.text },
        )
    }

    @Test
    fun `候选行在未满时可用且没有行尾说明`() {
        // :141 `details: _canAdd ? null : l10n.homeGridEditorMaxReached`
        val page = spec(defaultState())
        val row = page.row("homeMenuEditor.candidate.update")
        assertTrue(row.enabled)
        assertNull(row.details)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
        assertEquals("update", row.actionTarget)
    }

    @Test
    fun `满八格时候选行禁用并显示已达上限`() {
        // :40-42 `_canAdd => _ids.length < _maxSlots`
        val full = listOf(
            "overview", "statistics", "addCourse", "exams",
            "tasks", "importCourses", "settings", "support",
        )
        val page = spec(SettingsHomeMenuEditorState(enabledIds = full))
        val row = page.row("homeMenuEditor.candidate.update")
        assertFalse(row.enabled)
        assertEquals("已达上限", row.details)
        assertEquals("homeGridEditorMaxReached", row.detailsKey)
    }

    @Test
    fun `分类候选全启用时给一句说明而不是空组`() {
        // :131-133 `if (candidates.isEmpty) return [HyperosSectionDescription(text: l10n.homeGridEditorAllAdded)]`
        // 偏好设置分类现有 13 项（settings / homeNavigation / 10 个新设置页 / statisticsSettings），
        // 必须全部启用才会出现空态
        val page = spec(
            SettingsHomeMenuEditorState(
                enabledIds = listOf(
                    "settings", "homeNavigation", "generalSettings", "appearanceSettings",
                    "appearanceEditor", "timetablePageSettings", "courseCardSettings",
                    "weatherSettings", "liveSettings", "holidaySettings",
                    "homeWidgetSettings", "diagnosticsSettings", "statisticsSettings",
                ),
            ),
        )
        val description = page.flatten().filterIsInstance<SettingsDescription>()
            .firstOrNull { it.id == "homeMenuEditor.category.preferences.empty" }
        assertEquals("homeGridEditorAllAdded", description!!.textKey)
        assertEquals("所有入口都已启用", description.text)
        // 该分类下确实没有候选组了
        assertNull(
            page.flatten().filterIsInstance<SettingsGroup>()
                .firstOrNull { it.id == "homeMenuEditor.category.preferences" },
        )
    }

    @Test
    fun `某分类候选非空时不出现空态说明`() {
        val page = spec(defaultState())
        assertNull(
            page.flatten().filterIsInstance<SettingsDescription>()
                .firstOrNull { it.id == "homeMenuEditor.category.preferences.empty" },
        )
    }

    // ------------------------------------------------------------- 预览卡

    @Test
    fun `预览卡列出已启用的瓷贴`() {
        // settings_home_menu_editor.dart:149-200
        val preview = spec(defaultState()).flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "homeMenuEditor.preview" }
        assertEquals(InlineKind.PREVIEW_CARD, preview.kind)
        assertEquals(
            listOf("课程总览", "课程统计", "添加", "课表设置"),
            preview.texts.map { it.text },
        )
    }

    // ------------------------------------------------------------ 纯函数行为

    @Test
    fun `种子清洗丢弃未知与不可见 id 并去重保序`() {
        // :33-38
        assertEquals(
            listOf("overview", "settings"),
            SettingsHomeMenuEditorPage.sanitizeSeed(
                listOf("overview", "no-such", "settings", "overview"),
                diagnosticsBuild = false,
            ),
        )
        // 调试专属条目在正式版被丢弃
        assertEquals(
            listOf("overview"),
            SettingsHomeMenuEditorPage.sanitizeSeed(
                listOf("overview", "memoryStats"),
                diagnosticsBuild = false,
            ),
        )
        assertEquals(
            listOf("overview", "memoryStats"),
            SettingsHomeMenuEditorPage.sanitizeSeed(
                listOf("overview", "memoryStats"),
                diagnosticsBuild = true,
            ),
        )
    }

    @Test
    fun `写入基准先清掉未知 id 再加一项得到八项`() {
        val raw = listOf(
            "overview", "statistics", "addCourse", "exams",
            "tasks", "importCourses", "settings",
            // 旧版本目录里存在、现已下线的入口：不能继续占槽位。
            "advancedMaterialSettings",
        )
        val seed = SettingsHomeMenuEditorPage.editorSeed(raw)
        assertEquals("界面只应看到清洗后的 7 项", 7, seed.size)

        val result = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            "support",
            SettingsActionDispatcher.ROW_MENU_ADD,
            TimetableSettingsModel(homeGridMenuActions = seed),
        ) as SettingsDispatch.Write

        assertEquals(8, result.model.homeGridMenuActions.size)
        assertTrue("support" in result.model.homeGridMenuActions)
        assertFalse("advancedMaterialSettings" in result.model.homeGridMenuActions)
    }

    @Test
    fun `候选列表按分类过滤已启用项`() {
        val candidates = SettingsHomeMenuEditorPage.candidatesFor(
            category = "preferences",
            enabledIds = listOf("settings"),
            diagnosticsBuild = false,
        )
        assertEquals(
            listOf(
                "homeNavigation", "generalSettings", "appearanceSettings", "appearanceEditor",
                "timetablePageSettings", "courseCardSettings", "weatherSettings", "liveSettings",
                "holidaySettings", "homeWidgetSettings", "diagnosticsSettings", "statisticsSettings",
            ),
            candidates.map { it.id },
        )
    }

    @Test
    fun `分类顺序与 Dart 枚举一致`() {
        assertEquals(
            listOf("features", "data", "preferences", "about"),
            SettingsHomeMenuEditorPage.CATEGORIES,
        )
    }

    @Test
    fun `槽位上限为八且钉住项为课表设置`() {
        // timetable_settings_enums.dart:162 / :170
        assertEquals(8, SettingsHomeMenuEditorPage.MAX_SLOTS)
        assertEquals("settings", SettingsHomeMenuEditorPage.PINNED_ACTION_ID)
    }
}
