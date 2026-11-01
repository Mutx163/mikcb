package com.mutx163.qingyu.pages.settings

import kotlin.math.floor

/**
 * 圆钮图标挑选页（`lib/screens/settings/settings_glass_dock_icon_editor.dart`）结构模型。
 *
 * ## 这一页在做什么
 *
 * 首页那颗圆形「加号」按钮可以换成任意一个 Miuix 扩展图标。页面只有两块：
 * 顶部一张搜索卡，下面是把全部扩展图标按 N 列铺开的网格。**第一格永远是「默认 加号」**
 * （= 清空自定义、换回加号），其余是过滤结果；点任意一格就选中并返回上一页。
 *
 * ## 图标名清单为什么由调用方传进来
 *
 * Dart 用 `MiuixIcons.extended.names`（flutter_miuix 包内数据）。Kotlin 侧同一份数据
 * 在 `miuix-icons` 的 AAR 里，而 `main` 源集**不能**依赖 Miuix（全变体编译，
 * 见 `SettingsPageModel.kt` 顶部说明）。所以模型只负责这套纯逻辑：
 *
 * 1. 过滤（不区分大小写、保留原始顺序）——[filteredNames]；
 * 2. 列数推导（按可用宽度算，夹在 3~6 列）——[columnCount]；
 * 3. 网格排布（首格默认、末行补空位）——[cells]；
 * 4. 选中态与点击语义（点默认格传 null）——[select]。
 *
 * 名字清单由渲染层从 AAR 取出后作为 [IconPickerState.names] 传入；Kotlin 侧不再像 Dart
 * 那样能运行时枚举，所以清单的**唯一来源**是纯 Kotlin 的 [GlassDockIconCatalog]（156 个，
 * 与 Dart `_data` 键表逐项对应）。名字 → 矢量图标的映射在 `composeP1` 的
 * `GlassDockIconVectors`。过滤逻辑照样能被 JVM 单测钉死。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: glassDockButtonIconTitle)`（:140-142） | `titleKey/title` | `basic.TopAppBar` |
 * | 搜索卡（:171-189） | `icon.search`（CONTROL_CARD） | 官方无「卡片内搜索框」组合件，`basic.TextField` 由渲染层承担 |
 * | 图标网格（:194-238） | `icon.grid`（CONTROL_CARD） | 官方无图标网格组件，自绘白名单 |
 *
 * ## 几何常量（:43-50）一笔不差搬过来
 *
 * `_cellSpacing = 8`、`_rowSpacing = 10`、`_minCellWidth = 76`、`_maxColumns = 6`、
 * 列数下限 3、`_iconSize = 26`。这些数字决定「一行放几个」，与观感直接相关，
 * 所以进模型而不是散在渲染层里。
 */
object SettingsGlassDockIconEditorPage {

    const val ID = "settings-glass-dock-icon-editor"

    /** `_cellSpacing`（:43）：同排相邻格之间的水平间距。 */
    const val CELL_SPACING_DP = 8.0

    /** `_rowSpacing`（:45）：行与行之间的垂直间距。 */
    const val ROW_SPACING_DP = 10.0

    /** `_minCellWidth`（:46）：一格至少这么宽，列数由它反推。 */
    const val MIN_CELL_WIDTH_DP = 76.0

    /** `_maxColumns`（:47）。 */
    const val MAX_COLUMNS = 6

    /** 列数下限（:134 `columns.clamp(3, _maxColumns)`）。 */
    const val MIN_COLUMNS = 3

    /** `_iconSize`（:50）：格内矢量图标边长。 */
    const val ICON_SIZE_DP = 26.0

    /**
     * 页面结构。
     *
     * [contentWidthDp] 是**扣掉列表左右内边距之后**的可用宽度
     * （Dart :147-148 `constraints.maxWidth - HyperosTokens.listPadding.horizontal`，
     * 即宽屏也是这个口径），由渲染层按实际宽度算好传进来。
     *
     * [picker] 的默认值给**真实清单**（[GlassDockIconCatalog.names]），而不是空表：
     * 只要确认「这一页构造得出来」的调用点（批次完成度守卫 / 桥的兜底路径）也能拿到
     * 全部图标，不会渲染出一个只剩「默认 加号」的空网格。选中值仍默认 null（加号）。
     */
    fun spec(
        state: SettingsPageState,
        picker: IconPickerState = IconPickerState(names = GlassDockIconCatalog.names),
        contentWidthDp: Double = DEFAULT_CONTENT_WIDTH_DP,
    ): SettingsPageSpec {
        val filtered = filteredNames(picker)
        val columns = columnCount(contentWidthDp)
        val grid = cells(picker, contentWidthDp)

        val nodes = mutableListOf<SettingsNode>()

        // 0. 搜索卡：输入组件不裸放（:172-177 的注释：搜索框填充色对页面背景无对比）
        nodes += SettingsInline(
            id = "icon.search",
            kind = InlineKind.CONTROL_CARD,
            note = "搜索卡（settings_glass_dock_icon_editor.dart:171-189）：Dart 侧垫一张白卡" +
                "再放 HyperosSearchBar，官方没有「卡片内搜索框」这种组合件，由渲染层用 basic.TextField 拼",
            labelKey = SettingsStringsExt4.glassDockButtonIconSearchHint.key,
            label = SettingsStringsExt4.glassDockButtonIconSearchHint.zh,
            // 当前过滤词（动态取值，不是 ARB 文案）
            value = picker.query,
        )

        // 1. 图标网格
        nodes += SettingsInline(
            id = "icon.grid",
            kind = InlineKind.CONTROL_CARD,
            note = "图标网格（:194-238）：官方 preference 一族没有图标网格组件（自绘白名单）。" +
                "首格固定是「默认 加号」，其后是过滤结果；列数 $columns、" +
                "格间距 $CELL_SPACING_DP、行间距 $ROW_SPACING_DP、最小格宽 $MIN_CELL_WIDTH_DP 全部照抄 Dart 常量",
            // 选中值：null 表示「默认加号」
            value = picker.selectedName,
            texts = buildList {
                // 首格文案来自 ARB，其余是 AAR 里的图标名（不是 ARB 文案 → 键为空）
                add(
                    SettingsInlineText(
                        SettingsStringsExt4.glassDockButtonIconDefault.key,
                        SettingsStringsExt4.glassDockButtonIconDefault.zh,
                    ),
                )
                filtered.forEach { add(SettingsInlineText(NON_ARB_TEXT, it)) }
            },
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt4.glassDockButtonIconTitle.key,
            title = SettingsStringsExt4.glassDockButtonIconTitle.zh,
            nodes = nodes,
        )
    }

    // -------------------------------------------------------------- 过滤

    /**
     * 过滤后的图标名（:79-87 `_recomputeFiltered`）。
     *
     * 口径逐字搬运：`query.trim().lowercase()`，命中判据是 `name.lowercase().contains(query)`；
     * 空查询原样返回全部（**不排序**，保持 AAR 的顺序，否则用户每次看到的图标位置都在变）。
     */
    fun filteredNames(picker: IconPickerState): List<String> {
        val query = picker.query.trim().lowercase()
        if (query.isEmpty()) return picker.names
        return picker.names.filter { it.lowercase().contains(query) }
    }

    // -------------------------------------------------------------- 列数

    /**
     * 列数推导（:127-135 `_columnCountFor`）。
     *
     * `floor((w + cellSpacing) / (minCellWidth + cellSpacing))` 后 `clamp(3, 6)`；
     * 宽度不超过一格最小宽时直接给下限 3。
     *
     * 算例（360dp 屏）：可用宽 328 → (328+8)/(76+8) = 4.0 → 4 列。
     */
    fun columnCount(contentWidthDp: Double): Int {
        if (contentWidthDp <= MIN_CELL_WIDTH_DP) return MIN_COLUMNS
        val columns = floor((contentWidthDp + CELL_SPACING_DP) / (MIN_CELL_WIDTH_DP + CELL_SPACING_DP)).toInt()
        return columns.coerceIn(MIN_COLUMNS, MAX_COLUMNS)
    }

    // -------------------------------------------------------------- 网格

    /**
     * 网格排布（:194-238 `_buildGridRow`）。
     *
     * 返回「行 → 格」的二维表；**每行长度都等于列数**，末行不足处为 null
     * （Dart :218-219 用 `Expanded(child: SizedBox.shrink())` 占位，保证已渲染的格子宽度
     * 与上方各行一致，左对齐收尾）。
     *
     * 首格（index 0）是「默认 加号」，[IconCell.name] 为 null。
     */
    fun cells(picker: IconPickerState, contentWidthDp: Double): List<List<IconCell?>> {
        val columns = columnCount(contentWidthDp)
        val filtered = filteredNames(picker)
        // 首格默认 + 过滤结果（:150-151 `cellCount = _filteredNames.length + 1`）
        val all: List<IconCell> = buildList {
            add(
                IconCell(
                    name = null,
                    labelKey = SettingsStringsExt4.glassDockButtonIconDefault.key,
                    label = SettingsStringsExt4.glassDockButtonIconDefault.zh,
                    selected = picker.selectedName == null,
                ),
            )
            filtered.forEach { name ->
                add(
                    IconCell(
                        name = name,
                        labelKey = NON_ARB_TEXT,
                        label = name,
                        selected = picker.selectedName == name,
                    ),
                )
            }
        }
        val rows = ArrayList<List<IconCell?>>()
        var index = 0
        while (index < all.size) {
            val row = ArrayList<IconCell?>(columns)
            repeat(columns) { offset ->
                row.add(all.getOrNull(index + offset))
            }
            rows.add(row)
            index += columns
        }
        return rows
    }

    // -------------------------------------------------------------- 选中

    /**
     * 点选中某一格（:96-101 + :225-238）。
     *
     * [cellIndex] 是**拍平后**的格序号（跨行连续，与 Dart 的 `cellIndex` 同义）：
     * 0 = 默认加号（选中值置 null = 清空自定义），其余按过滤结果取名字。
     */
    fun select(picker: IconPickerState, cellIndex: Int): IconPickerState {
        if (cellIndex < 0) return picker
        if (cellIndex == 0) return picker.copy(selectedName = null)
        val filtered = filteredNames(picker)
        val name = filtered.getOrNull(cellIndex - 1) ?: return picker
        return picker.copy(selectedName = name)
    }

    /** 328dp 是 360dp 屏（常见最小屏宽）扣掉列表左右各 16dp 后的可用宽度。 */
    const val DEFAULT_CONTENT_WIDTH_DP = 328.0
}

/**
 * 图标挑选页的交互输入。
 *
 * [names] 是全部候选图标名（真实清单见 [GlassDockIconCatalog.names]）。
 * [selectedName] 为 null 表示当前用的是「默认加号」。
 */
data class IconPickerState(
    val names: List<String> = emptyList(),
    val selectedName: String? = null,
    val query: String = "",
)

/**
 * 网格里的一格。
 *
 * [name] 为 null 表示这一格是「默认 加号」（清空自定义）；为 null 的**占位格**
 * 不产生 [IconCell]，而是由 [SettingsGlassDockIconEditorPage.cells] 用 null 填空。
 */
data class IconCell(
    val name: String?,
    val labelKey: String,
    val label: String,
    val selected: Boolean,
)
