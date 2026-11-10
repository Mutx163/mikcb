package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 玻璃坞底栏编辑器（`lib/screens/settings/settings_glass_dock_editor.dart`）结构测试。
 *
 * 期望值来源：Dart 源（行顺序 / 控件类型 / 上限 / 条件分支）+ ARB（文案），
 * 不从 Kotlin 实现倒推。每处断言都写了 Dart 出处，便于逐项复核。
 *
 * ## 页面在做什么（先讲清再做断言）
 *
 * 用户自定义首页玻璃坞的按钮排列：最多 5 个，可拖动排序、可移除、可从目录加。
 * 顶部是实时预览；「已启用」区是当前排列（每行带移除按钮）；下面是「视图切换」
 * 伪分组（日/周是动作不是页面）与四个目录分类的未启用条目；最后是「恢复默认排列」。
 */
class SettingsGlassDockEditorPageTest {

    private fun spec(
        ids: List<String> = SettingsGlassDockEditorPage.DEFAULT_ACTIONS,
        debugBuild: Boolean = false,
    ) = SettingsGlassDockEditorPage.spec(
        SettingsPageState(),
        GlassDockEditorState(enabledIds = ids, debugBuild = debugBuild),
    )

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 glassDockCustomizeTitle`() {
        // settings_glass_dock_editor.dart:89 `title: Text(l10n.glassDockCustomizeTitle)`
        val page = spec()
        assertEquals("settings-glass-dock-editor", page.id)
        assertEquals("glassDockCustomizeTitle", page.titleKey)
        assertEquals("自定义底栏按钮", page.title)
    }

    @Test
    fun `槽位上限与默认排列照抄 HomeDockMenu`() {
        // 发布 tag v2.1.4.1 timetable_settings_enums.dart:214-216
        assertEquals(5, SettingsGlassDockEditorPage.MAX_SLOTS)
        assertEquals(listOf("day", "week"), SettingsGlassDockEditorPage.DEFAULT_ACTIONS)
    }

    @Test
    fun `顶层骨架顺序 预览卡 提示 已启用 视图切换 目录分类 恢复默认`() {
        // settings_glass_dock_editor.dart:92-118 的完整节点顺序（含每个 12dp 空档）。
        // 提示句已按用户要求从「已启用」之后提到它之前（先给「按住才排序」的规则再看图标）。
        // 用只启用 tasks 的状态：这样视图切换伪分组也在（日/周都还没启用）。
        assertEquals(
            listOf(
                "dock.preview",
                "dock.gap.afterPreview",
                "dock.hint",
                "dock.enabled.label",
                "dock.enabled",
                "dock.viewSwitch.gap",
                "dock.viewSwitch.label",
                "dock.viewSwitch",
                "dock.catalog.features.gap",
                "dock.catalog.features.label",
                "dock.catalog.features",
                "dock.catalog.data.gap",
                "dock.catalog.data.label",
                "dock.catalog.data",
                "dock.catalog.preferences.gap",
                "dock.catalog.preferences.label",
                "dock.catalog.preferences",
                "dock.catalog.about.gap",
                "dock.catalog.about.label",
                "dock.catalog.about",
                "dock.gap.reset",
                "dock.reset",
            ),
            spec(listOf("tasks")).topLevelIds(),
        )
    }

    // -------------------------------------------------------------- 预览卡

    @Test
    fun `预览卡按当前排列顺序展示每个按钮`() {
        // :181-229 `for (final id in _ids)`，标签走 glassDockActionLabel
        val preview = spec(listOf("week", "tasks", "day")).flatten()
            .filterIsInstance<SettingsInline>()
            .first { it.id == "dock.preview" }
        assertEquals(InlineKind.CONTROL_CARD, preview.kind)
        assertEquals(
            listOf("周课表", "任务清单", "日课表"),
            preview.texts.map { it.text },
        )
        assertEquals(
            listOf("glassDockTabWeek", "homeMenuTasksTitle", "glassDockTabDay"),
            preview.texts.map { it.key },
        )
    }

    @Test
    fun `预览卡不塞任何非 ARB 文案`() {
        // 预览格里的字全部来自 ARB（glassDockTabDay / 目录标题）
        val preview = spec().flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "dock.preview" }
        preview.texts.forEach { assertTrue("键为空：${it.text}", it.key.isNotEmpty()) }
    }

    // ------------------------------------------------------------ 已启用区

    @Test
    fun `已启用区的行等于当前排列 且都有移除动作`() {
        // :94-95 + :231-268 `ReorderableListView(itemCount: _ids.length)`
        val page = spec(listOf("day", "week", "tasks"))
        val group = page.group("dock.enabled")
        assertEquals(listOf("dock.slot.day", "dock.slot.week", "dock.slot.tasks"), group.childRowIds())
        group.children.filterIsInstance<SettingsRow>().forEach { row ->
            assertEquals(MiuixRowComponent.ARROW, row.component)
            // 每行右侧的移除按钮（:330-341），文案来自 homeGridEditorRemoveTooltip
            assertEquals("homeGridEditorRemoveTooltip", row.trailingActionKey)
            assertEquals("移除", row.trailingAction)
            assertTrue("行 ${row.id} 应可点击", row.enabled)
        }
    }

    @Test
    fun `只剩一个按钮时移除按钮不可用`() {
        // :48 `_canRemove => _ids.length > 1`；:332 `onPressed: canRemove ? onRemove : null`
        val single = spec(listOf("day")).group("dock.enabled")
        assertFalse("只剩一个时不该允许移除", single.children.filterIsInstance<SettingsRow>().single().enabled)
        val two = spec(listOf("day", "week")).group("dock.enabled")
        assertTrue(two.children.filterIsInstance<SettingsRow>().all { it.enabled })
    }

    @Test
    fun `已启用区的行标题就是按钮名`() {
        val group = spec(listOf("day", "tasks")).group("dock.enabled")
        val rows = group.children.filterIsInstance<SettingsRow>()
        assertEquals(listOf("日课表", "任务清单"), rows.map { it.title })
    }

    // ------------------------------------------------------------ 提示文案

    @Test
    fun `提示文案把上限填进占位符`() {
        // :96-98 `homeGridEditorHintBody(_maxSlots)`；ARB 模板「最多放 {max} 个」。
        val hint = spec().flatten().filterIsInstance<SettingsDescription>().single { it.id == "dock.hint" }
        assertEquals("homeGridEditorHintBody", hint.textKey)
        assertEquals("最多放 5 个，按住条目可排序", hint.text)
    }

    // -------------------------------------------------------- 视图切换伪分组

    @Test
    fun `视图切换分组只列尚未启用的日与周`() {
        // :122-148：candidates = [day, week] 里 !_ids.contains 的那些
        val page = spec(listOf("tasks"))
        assertEquals(
            listOf("dock.viewSwitch.day", "dock.viewSwitch.week"),
            page.group("dock.viewSwitch").childRowIds(),
        )
        val both = spec(listOf("day", "week")).topLevelIds()
        assertFalse("两个视图都已启用时不该出现该分组", both.contains("dock.viewSwitch"))
        val one = spec(listOf("day")).group("dock.viewSwitch").childRowIds()
        assertEquals(listOf("dock.viewSwitch.week"), one)
    }

    @Test
    fun `视图切换分组的标题取自 homeDockEditorViewCategory`() {
        // :135 `HyperosSectionLabel(text: l10n.homeDockEditorViewCategory)`
        val label = spec(listOf("tasks")).flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "dock.viewSwitch.label" }
        assertEquals("homeDockEditorViewCategory", label.textKey)
        assertEquals("视图切换", label.text)
    }

    // ------------------------------------------------------------ 目录分类

    @Test
    fun `四个分类按 Dart 声明顺序出现`() {
        // HomeMenuEntryCategory = features, data, preferences, about（home_top_menu.dart:10）
        val labels = spec().flatten().filterIsInstance<SettingsLabel>()
            .filter { it.id.startsWith("dock.catalog.") }
        assertEquals(
            listOf(
                "dock.catalog.features.label",
                "dock.catalog.data.label",
                "dock.catalog.preferences.label",
                "dock.catalog.about.label",
            ),
            labels.map { it.id },
        )
        assertEquals(
            listOf("功能入口", "数据与同步", "偏好设置", "关于与支持"),
            labels.map { it.text },
        )
    }

    @Test
    fun `分类内的候选条目保持目录声明顺序且排除已启用的`() {
        // :155-162 `kHomeMenuCatalog.where(category == c && visible && !_ids.contains(id))`
        val page = spec(listOf("day", "week", "tasks"))
        val features = page.group("dock.catalog.features")
        // catalog 里 features 的前几项（home_menu_catalog.dart:44-135）里，tasks 已启用
        assertEquals(
            listOf("update", "pickupCode", "overview", "statistics", "addCourse", "exams", "importCourses"),
            features.childRowIds().take(7).map { it.removePrefix("dock.catalog.features.") },
        )
        assertFalse(
            "已启用的 tasks 不该再出现在候选里",
            features.childRowIds().any { it.endsWith(".tasks") },
        )
    }

    @Test
    fun `分类下没有候选时给一句所有入口都已启用`() {
        // :163-165 `if (candidates.isEmpty) return [HyperosSectionDescription(homeGridEditorAllAdded)]`
        // 构造：data 分类只有 4 项（home_menu_catalog.dart:276-304），全启用后正好还剩 1 个槽位
        val allData = SettingsGlassDockEditorPage.catalog
            .filter { it.category == DockCategory.DATA }
            .map { it.id }
        assertEquals("data 分类应有 4 项", 4, allData.size)
        val page = spec(allData + "day")
        val empty = page.flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "dock.catalog.data.empty" }
        assertEquals("homeGridEditorAllAdded", empty.textKey)
        assertEquals("所有入口都已启用", empty.text)
        assertFalse(
            "data 分类全启用后不该再有那张卡",
            page.flatten().filterIsInstance<SettingsGroup>().any { it.id == "dock.catalog.data" },
        )
        // 别的分类仍有候选，不该也出现空态说明
        assertTrue(
            page.flatten().filterIsInstance<SettingsGroup>().any { it.id == "dock.catalog.features" },
        )
    }

    @Test
    fun `目录里共 47 个条目 四个分类都有内容`() {
        // home_menu_catalog.dart 的 kHomeMenuCatalog 实际条目数（脚本核对：47）
        assertEquals(47, SettingsGlassDockEditorPage.catalog.size)
        DockCategory.entries.forEach { category ->
            assertTrue(
                "分类 $category 在目录里没有条目",
                SettingsGlassDockEditorPage.catalog.any { it.category == category },
            )
        }
        // 分类计数也钉住，防止「归类挪错」这种静默变化
        assertEquals(23, SettingsGlassDockEditorPage.catalog.count { it.category == DockCategory.FEATURES })
        assertEquals(4, SettingsGlassDockEditorPage.catalog.count { it.category == DockCategory.DATA })
        assertEquals(13, SettingsGlassDockEditorPage.catalog.count { it.category == DockCategory.PREFERENCES })
        assertEquals(7, SettingsGlassDockEditorPage.catalog.count { it.category == DockCategory.ABOUT })
    }

    @Test
    fun `调试专属条目只在调试构建里进候选`() {
        // home_menu_catalog.dart:442-449 `visible: () => MemoryStatsService.isDiagnosticsBuildCached`
        val releaseFeatures = spec(debugBuild = false).flatten().filterIsInstance<SettingsGroup>()
            .flatMap { it.children }
            .filterIsInstance<SettingsRow>()
            .map { it.id }
        assertFalse("正式版不该出现内存状态", releaseFeatures.any { it.endsWith(".memoryStats") })
        val debugRows = spec(debugBuild = true).flatten().filterIsInstance<SettingsGroup>()
            .flatMap { it.children }
            .filterIsInstance<SettingsRow>()
            .map { it.id }
        assertTrue("调试版应能看到内存状态", debugRows.any { it.endsWith(".memoryStats") })
    }

    // ------------------------------------------------------------ 已达上限

    @Test
    fun `占满槽位时候选行给出已达上限并禁用`() {
        // :142-143 / :173-174 `details: _canAdd ? null : l10n.homeGridEditorMaxReached`
        //      `onTap: _canAdd ? () => _add(id) : null`
        val full = spec(listOf("day", "week", "tasks", "exams", "overview")).flatten()
            .filterIsInstance<SettingsRow>()
            .filter { it.id.startsWith("dock.catalog.") || it.id.startsWith("dock.viewSwitch.") }
        assertTrue("满 5 个后应还有候选行", full.isNotEmpty())
        full.forEach { row ->
            assertEquals("住 ${row.id} 的行尾应显示已达上限", "homeGridEditorMaxReached", row.detailsKey)
            assertEquals("已达上限", row.details)
            assertFalse("行 ${row.id} 应被禁用", row.enabled)
        }
    }

    @Test
    fun `未满时候选行没有行尾文案且可点`() {
        val rows = spec(listOf("day")).flatten().filterIsInstance<SettingsRow>()
            .filter { it.id.startsWith("dock.catalog.") }
        rows.forEach { row ->
            assertNull("行 ${row.id} 不该有行尾文案", row.details)
            assertTrue("行 ${row.id} 应可点", row.enabled)
        }
    }

    // ------------------------------------------------------------ 恢复默认

    @Test
    fun `页尾恢复默认排列行`() {
        // :108-116 `HyperosListTile(title: l10n.homeGridEditorResetAction, onTap: _resetToDefault)`
        val row = spec().row("dock.reset.row")
        assertEquals("homeGridEditorResetAction", row.titleKey)
        assertEquals("恢复默认排列", row.title)
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals(SettingsGlassDockEditorPage.RESET_TARGET, row.actionTarget)
        assertFalse("恢复排列不是危险操作，不该标红", row.destructive)
    }

    // ------------------------------------------------------------ 排列变换

    @Test
    fun `添加时守住上限与去重`() {
        // :65-70 `if (!_canAdd || _ids.contains(id)) return;`
        val five = GlassDockEditorState(enabledIds = listOf("day", "week", "tasks", "exams", "overview"))
        // 满 5 个后加不进去，原样返回（含 debugBuild 等其它字段）
        assertEquals(five, SettingsGlassDockEditorPage.add(five, "monthView"))
        // 已存在的 id 不重复添加，原样返回
        val single = GlassDockEditorState(listOf("day"))
        assertEquals(single, SettingsGlassDockEditorPage.add(single, "day"))
        // 正常添加：追加到末尾
        val added = SettingsGlassDockEditorPage.add(GlassDockEditorState(listOf("day")), "tasks")
        assertEquals(listOf("day", "tasks"), added.enabledIds)
        // 变换不该丢其它字段（debugBuild 是页面级的，不是排列的一部分）
        assertEquals(
            true,
            SettingsGlassDockEditorPage.add(
                GlassDockEditorState(listOf("day"), debugBuild = true),
                "tasks",
            ).debugBuild,
        )
    }

    @Test
    fun `移除时至少留一个`() {
        // :72-78 `if (!_canRemove) return;`
        val single = GlassDockEditorState(listOf("day"))
        assertEquals(single, SettingsGlassDockEditorPage.removeAt(single, 0))
        val two = GlassDockEditorState(listOf("day", "week"))
        assertEquals(listOf("week"), SettingsGlassDockEditorPage.removeAt(two, 0).enabledIds)
        assertEquals(listOf("day"), SettingsGlassDockEditorPage.removeAt(two, 1).enabledIds)
    }

    @Test
    fun `拖动排序把元素搬到目标位`() {
        // :57-63 `final moved = _ids.removeAt(oldIndex); _ids.insert(newIndex, moved);`
        // 注意 onReorderItem 已经校正过下移的 newIndex（settings_home_menu_editor.dart:53）
        val state = GlassDockEditorState(listOf("day", "week", "tasks"))
        assertEquals(listOf("week", "day", "tasks"), SettingsGlassDockEditorPage.move(state, 0, 1).enabledIds)
        assertEquals(listOf("tasks", "day", "week"), SettingsGlassDockEditorPage.move(state, 2, 0).enabledIds)
        assertEquals(listOf("day", "week", "tasks"), SettingsGlassDockEditorPage.move(state, 1, 1).enabledIds)
    }

    @Test
    fun `恢复默认排列回到 day week`() {
        // :80-82 `_commit(HomeDockMenu.defaultActions)`（发布 tag v2.1.4.1 :216 = 日/周）
        assertEquals(
            listOf("day", "week"),
            SettingsGlassDockEditorPage.reset(GlassDockEditorState(listOf("exams"))).enabledIds,
        )
    }

    // -------------------------------------------------------- 种子阶段过滤

    @Test
    fun `种子阶段丢弃当前环境不可用的 id`() {
        // :26-37 `for (final id in widget.initialIds) if (_isAvailable(id)) id`
        assertEquals(
            listOf("day", "tasks"),
            SettingsGlassDockEditorPage.sanitize(listOf("day", "notARealEntry", "tasks", "memoryStats"), debugBuild = false),
        )
        assertEquals(
            listOf("day", "memoryStats"),
            SettingsGlassDockEditorPage.sanitize(listOf("day", "memoryStats"), debugBuild = true),
        )
        assertTrue(SettingsGlassDockEditorPage.sanitize(emptyList(), debugBuild = false).isEmpty())
    }
}
