package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 圆钮图标挑选页（`lib/screens/settings/settings_glass_dock_icon_editor.dart`）结构测试。
 *
 * 期望值来源：Dart 源（过滤口径 / 列数公式 / 首格语义）+ ARB（文案），
 * 不从 Kotlin 实现倒推。
 *
 * ## 这一页在做什么
 *
 * 首页那颗圆形「加号」按钮，用户可以换成一个 Miuix 扩展图标。页面顶部是搜索卡，
 * 下面是把全部扩展图标按 N 列铺成网格；**第一格永远是「默认 加号」**（= 清空自定义，
 * 换回加号），其余是过滤结果。点任意一格立即选中并返回上一页。
 *
 * ## 图标名清单为什么不进模型
 *
 * Dart 侧取自 `MiuixIcons.extended.names`（flutter_miuix 包内数据）。Kotlin 侧同一份
 * 数据在 `miuix-icons` 的 AAR 里，而 `main` 源集**不能**依赖 Miuix（全变体编译）。
 * 所以模型只负责「过滤 + 网格排布 + 选中态」这套纯逻辑，名字清单由调用方（渲染层）
 * 作为 [IconPickerState.names] 传进来——过滤逻辑照样能在 JVM 里被钉死。
 */
class SettingsGlassDockIconEditorPageTest {

    /** 一小段假图标名（大小写混合，专门用来钉住「不区分大小写、保留原始顺序」）。 */
    private val sampleNames = listOf(
        "alarm-clock",
        "ArrowUp",
        "arrow-down",
        "battery",
        "Calendar",
        "camera",
        "wifi",
    )

    private fun state(
        names: List<String> = sampleNames,
        selected: String? = null,
        query: String = "",
    ) = IconPickerState(names = names, selectedName = selected, query = query)

    private fun spec(state: IconPickerState = state(), contentWidthDp: Double = 328.0) =
        SettingsGlassDockIconEditorPage.spec(SettingsPageState(), state, contentWidthDp)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 glassDockButtonIconTitle`() {
        // settings_glass_dock_icon_editor.dart:142 `title: Text(l10n.glassDockButtonIconTitle)`
        val page = spec()
        assertEquals("settings-glass-dock-icon-editor", page.id)
        assertEquals("glassDockButtonIconTitle", page.titleKey)
        assertEquals("圆钮图标", page.title)
    }

    @Test
    fun `只有搜索卡与网格两块 没有恢复默认行`() {
        // :153-165 `HyperosListView(itemCount: rowCount + 1)`，第 0 项是搜索卡
        assertEquals(listOf("icon.search", "icon.grid"), spec().topLevelIds())
    }

    @Test
    fun `搜索卡提示语与当前过滤词`() {
        // :178-186 `hint: l10n.glassDockButtonIconSearchHint`
        val search = spec(state(query = "arrow")).flatten()
            .filterIsInstance<SettingsInline>().first { it.id == "icon.search" }
        assertEquals("glassDockButtonIconSearchHint", search.labelKey)
        assertEquals("搜索图标名称", search.label)
        assertEquals("arrow", search.value)
    }

    @Test
    fun `搜索卡在网格之前`() {
        // :156-158 `if (index == 0) return _buildSearchCard(l10n);`
        val ids = spec().topLevelIds()
        assertTrue("搜索卡必须排在网格前", ids.indexOf("icon.search") < ids.indexOf("icon.grid"))
    }

    // -------------------------------------------------------------- 过滤口径

    @Test
    fun `空搜索词返回全部图标且保持原顺序`() {
        // :79-87 `query.isEmpty() ? names : names.where(...)`
        assertEquals(sampleNames, SettingsGlassDockIconEditorPage.filteredNames(state()))
        assertEquals(sampleNames, SettingsGlassDockIconEditorPage.filteredNames(state(query = "   ")))
    }

    @Test
    fun `过滤不区分大小写且保留原始大小写`() {
        // :80,85 `final query = _filter.trim().toLowerCase(); n.toLowerCase().contains(query)`
        assertEquals(
            listOf("ArrowUp", "arrow-down"),
            SettingsGlassDockIconEditorPage.filteredNames(state(query = "ARROW")),
        )
        assertEquals(
            listOf("alarm-clock"),
            SettingsGlassDockIconEditorPage.filteredNames(state(query = "  alarm  ")),
        )
    }

    @Test
    fun `过滤无命中时结果为空`() {
        assertTrue(SettingsGlassDockIconEditorPage.filteredNames(state(query = "zzz")).isEmpty())
    }

    // -------------------------------------------------------------- 列数公式

    @Test
    fun `列数按可用宽度推导并夹在三到六列`() {
        // :127-135 `columnCountFor`: floor((w + 8) / (76 + 8)) 后 clamp(3, 6)
        // 人推算例：360dp 屏 − 左右各 16dp 列表内边距 = 328 → (328+8)/84 = 4.0 → 4 列
        assertEquals(4, SettingsGlassDockIconEditorPage.columnCount(328.0))
        // 4 列的临界：4*76 + 3*8 = 328；差 1dp 就掉回 3 列
        assertEquals(3, SettingsGlassDockIconEditorPage.columnCount(327.0))
        assertEquals(3, SettingsGlassDockIconEditorPage.columnCount(76.0))
        assertEquals(3, SettingsGlassDockIconEditorPage.columnCount(60.0))
        assertEquals(3, SettingsGlassDockIconEditorPage.columnCount(0.0))
        // 6 列的临界：6*76 + 5*8 = 496，往上都夹在 6
        assertEquals(5, SettingsGlassDockIconEditorPage.columnCount(495.0))
        assertEquals(6, SettingsGlassDockIconEditorPage.columnCount(496.0))
        assertEquals(6, SettingsGlassDockIconEditorPage.columnCount(600.0))
    }

    @Test
    fun `网格是行列表 首格固定默认加号`() {
        // :150-151 `cellCount = _filteredNames.length + 1`；:226-230 `isDefault = cellIndex == 0`
        val rows = SettingsGlassDockIconEditorPage.cells(state(), contentWidthDp = 328.0)
        val flat = rows.flatten()
        assertEquals(sampleNames.size + 1, flat.size)
        val first = flat.first()!!
        assertNull("首格代表「默认加号」，它的图标名为 null", first.name)
        assertEquals("glassDockButtonIconDefault", first.labelKey)
        assertEquals("默认 加号", first.label)
        assertEquals(sampleNames, flat.drop(1).map { it!!.name })
    }

    @Test
    fun `末行不足处用空位补齐 保证每行等宽`() {
        // :218-219 `for (var i = end; i < first + columns; i++) Expanded(child: SizedBox.shrink())`
        val rows = SettingsGlassDockIconEditorPage.cells(state(), contentWidthDp = 328.0)
        val columns = SettingsGlassDockIconEditorPage.columnCount(328.0)
        assertEquals("7 个名字 + 默认格 = 8 格，4 列应排 2 行", 2, rows.size)
        rows.forEach { assertEquals("每行都补齐到 $columns 格", columns, it.size) }
        // 8 / 4 = 2 行正好填满，最后一行不留空位
        assertTrue(rows.last().all { it != null })
    }

    @Test
    fun `末行确实会留空位`() {
        // 首格是「默认加号」（name=null），其后才是过滤结果；2 个名字 → 3 格
        val rows = SettingsGlassDockIconEditorPage.cells(
            state(names = listOf("a", "b")),
            contentWidthDp = 328.0,
        )
        assertEquals(1, rows.size)
        assertEquals(4, rows[0].size)
        // 第 0 格是默认格（name 为 null 但 label 是「默认 加号」），第 1/2 格是 a/b，
        // 第 3 格是补齐用的空占位（整个 IconCell 为 null）
        assertEquals(listOf(null, "a", "b", null), rows[0].map { it?.name })
        assertEquals("glassDockButtonIconDefault", rows[0][0]!!.labelKey)
        assertNull("末格的补齐是真占位，不是默认格", rows[0][3])
    }

    @Test
    fun `行数与格数的关系`() {
        val names = (1..10).map { "icon$it" }
        val rows = SettingsGlassDockIconEditorPage.cells(state(names = names), contentWidthDp = 328.0)
        // 11 格 / 4 列 = 3 行
        assertEquals(3, rows.size)
        assertEquals(11, rows.flatten().count { it != null })
    }

    // -------------------------------------------------------------- 选中态

    @Test
    fun `未设置图标时默认格被选中`() {
        // :228 `final selected = isDefault ? _selected == null : _selected == name;`
        val flat = SettingsGlassDockIconEditorPage.cells(state(selected = null), 328.0).flatten()
        assertTrue(flat.first()!!.selected)
        assertTrue(flat.drop(1).all { !it!!.selected })
    }

    @Test
    fun `设置了图标时对应格被选中 默认格取消`() {
        val flat = SettingsGlassDockIconEditorPage.cells(state(selected = "camera"), 328.0).flatten()
        assertFalse(flat.first()!!.selected)
        assertEquals(listOf("camera"), flat.filterNotNull().filter { it.selected }.map { it.name })
    }

    @Test
    fun `点默认格传 null 表示清空自定义`() {
        // :96-101 `void _select(String? name)` → onChanged(name)
        //      :227 `final name = isDefault ? null : _filteredNames[cellIndex - 1];`
        assertNull(SettingsGlassDockIconEditorPage.select(state(selected = "camera"), cellIndex = 0).selectedName)
        assertEquals("wifi", SettingsGlassDockIconEditorPage.select(state(), cellIndex = 7).selectedName)
    }

    // -------------------------------------------------------------- 空结果

    @Test
    fun `没有命中时网格只剩默认格`() {
        val rows = SettingsGlassDockIconEditorPage.cells(state(query = "zzz"), 328.0)
        assertEquals(1, rows.size)
        val first = rows[0].first()!!
        assertNull(first.name)
        assertTrue(first.selected)
    }

    @Test
    fun `网格节点带上当前选中值与可见格数`() {
        // 渲染层拿不到图标矢量（在 AAR 里），所以网格以「数据块」形式交给渲染层：
        // 选中值 + 每个单元格的文案。文案全部来自 ARB 或图标名本身。
        val grid = spec(state(selected = "camera")).flatten()
            .filterIsInstance<SettingsInline>().first { it.id == "icon.grid" }
        assertEquals("camera", grid.value)
        assertEquals(sampleNames.size + 1, grid.texts.size)
        assertEquals("默认 加号", grid.texts.first().text)
        assertEquals("glassDockButtonIconDefault", grid.texts.first().key)
        assertEquals("alarm-clock", grid.texts[1].text)
        // 图标名是 AAR 里的数据，不是 ARB 文案 → 键为空（对照测试跳过）
        assertEquals(NON_ARB_TEXT, grid.texts[1].key)
    }

    @Test
    fun `网格节点说明官方没有二十宫格控件`() {
        val grid = spec().flatten().filterIsInstance<SettingsInline>().first { it.id == "icon.grid" }
        assertTrue("note 要写清为什么不是一行 Preference", grid.note.contains("官方"))
        assertEquals(InlineKind.CONTROL_CARD, grid.kind)
    }
}
