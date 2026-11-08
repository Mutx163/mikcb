package com.mutx163.qingyu.pages.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.basic.SearchBarDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.Search
import top.yukonga.miuix.kmp.icon.basic.SearchCleanup
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.squircle.squircleBackground
import top.yukonga.miuix.kmp.squircle.squircleBorder
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 圆钮图标挑选页的**渲染层**（`lib/screens/settings/settings_glass_dock_icon_editor.dart`）。
 *
 * 页面只有两块，与 Dart 逐段对应：
 *
 * 1. 顶部搜索框（Dart :171-189）：Dart 先垫一张白卡再放 `HyperosSearchBar`，原因是它自带的
 *    填充色对页面背景没有对比。这里不再照抄那层卡——官方 `InputField`（`SearchBar.kt`）
 *    本身就是 45dp 胶囊 + `surfaceContainerHigh` 填充，放大镜与清除键都在内部，
 *    「卡里再套一个框」只会多出一圈白边和两层圆角；
 * 2. 图标网格（Dart :194-238）：首格固定「默认 加号」，其后是过滤结果。列数、格间距、
 *    行间距、最小格宽全部来自 [SettingsGlassDockIconEditorPage] 的常量/函数，本文件不另存
 *    一套几何数字。
 *
 * ## 为什么不让通用渲染层画这一页
 *
 * 通用 `CONTROL_CARD` 只会把 `texts` 铺成一排按钮；156 个图标塞进一行既装不下，
 * 也没有「当前选中」的视觉。所以这一页需要自己的宿主（[GlassDockIconEditorHost] 负责
 * 读写），壳里应把 `b.glassDockIcon` 从 `SettingsHost` 换成它。
 *
 * ## 选中就返回
 *
 * Dart :233-236 点任意格 `_select(name)` 后立刻 `Navigator.pop(context)`。这里保持
 * 同语义：回调只把「选中的名字」交给宿主，返回动作由宿主在落盘成功后执行。
 *
 * @param initialName 当前设置里的图标名；null = 默认加号
 * @param onSelect 选中一格（null = 默认加号）；名字来自 [IconCell.name]
 * @param onBack 返回上一页
 */
@Composable
fun GlassDockIconPickerScreen(
    initialName: String?,
    onSelect: (String?) -> Unit,
    onBack: () -> Unit,
) {
    var query by remember { mutableStateOf("") }

    QingyuPageScaffold(
        title = SettingsStringsExt4.glassDockButtonIconTitle.text,
        onBack = onBack,
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            // Dart :147-148：内容宽 = 页面宽 − 列表左右内边距。这里列表两侧各留
            // QingyuPageCardMargin（12dp），与搜索卡的左右边缘同源。
            val contentWidthDp = (maxWidth - QingyuPageCardMargin * 2).value.toDouble()
            // Dart 的过滤结果缓存（:59-60 `_filteredNames`）：只在搜索词/选中值变化时重算，
            // 不在每次重组里重新扫 156 个名字。
            val picker = remember(initialName, query) {
                IconPickerState(
                    names = GlassDockIconCatalog.names,
                    selectedName = initialName,
                    query = query,
                )
            }
            val columns = remember(contentWidthDp) {
                SettingsGlassDockIconEditorPage.columnCount(contentWidthDp)
            }
            val rows = remember(picker, contentWidthDp) {
                SettingsGlassDockIconEditorPage.cells(picker, contentWidthDp)
            }

            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                horizontalPadding = QingyuPageCardMargin,
                contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
            ) {
                item(key = "icon.search") {
                    IconSearchField(query = query, onQueryChange = { query = it })
                }
                itemsIndexed(rows) { rowIndex, row ->
                    IconGridRow(
                        row = row,
                        columns = columns,
                        onTap = { columnIndex ->
                            val next = SettingsGlassDockIconEditorPage.select(
                                picker,
                                cellIndex = rowIndex * columns + columnIndex,
                            )
                            onSelect(next.selectedName)
                        },
                    )
                }
            }
        }
    }
}

/**
 * 搜索框：miuix 官方 `InputField`（`SearchBar.kt`）的**页内常驻**用法（Dart :171-189）。
 *
 * 45dp 胶囊、`surfaceContainerHigh` 填充、左右自带放大镜与清除键，全在组件内部；
 * 外层只管左右边距（= [QingyuPageCardMargin]，与下方图标格同一条轴线）。
 * `expanded` 恒 false：这一页是「边输边筛」，不展开成全屏搜索页。
 */
@Composable
private fun IconSearchField(
    query: String,
    onQueryChange: (String) -> Unit,
) {
    val focusManager = LocalFocusManager.current
    InputField(
        query = query,
        onQueryChange = onQueryChange,
        // 没有独立提交动作，回车只收键盘（过滤在输入时已经发生）。
        onSearch = { focusManager.clearFocus() },
        expanded = false,
        onExpandedChange = { },
        label = SettingsStringsExt4.glassDockButtonIconSearchHint.text,
        // 官方默认放大镜的朗读文案是库里的英文 "Search"；这里是中文界面，且输入框
        // 自身已有 label，图标纯装饰 ⇒ 交回正文朗读。
        leadingIcon = {
            Icon(
                imageVector = MiuixIcons.Basic.Search,
                contentDescription = null,
                tint = MiuixTheme.colorScheme.onSurfaceContainerHigh,
                modifier = Modifier.padding(
                    start = SearchBarDefaults.LeadingIconStartPadding,
                    end = SearchBarDefaults.LeadingIconEndPadding,
                ),
            )
        },
        // 官方默认清除键朗读 "Search Cleanup"，换成「清空」；触区撑到 48×44，
        // 无涟漪（写法同 import/warehouse/WarehouseCourseImportPage.kt 的搜索栏）。
        trailingIcon = {
            AnimatedVisibility(
                visible = query.isNotEmpty(),
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                Box(
                    modifier = Modifier
                        .size(width = 48.dp, height = 44.dp)
                        .clickable(interactionSource = null, indication = null) {
                            focusManager.clearFocus()
                            onQueryChange("")
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = MiuixIcons.Basic.SearchCleanup,
                        contentDescription = SettingsStringsExt4.clearSearchAction.text,
                        tint = MiuixTheme.colorScheme.onSurfaceContainerHigh,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        },
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin)
            .padding(top = 4.dp, bottom = 8.dp),
    )
}

/**
 * 一行图标格（Dart :194-222）。
 *
 * [row] 由模型保证长度 = [columns]（末行不足处是 null 占位）。首末格贴边，相邻格之间
 * 各留半个 [SettingsGlassDockIconEditorPage.CELL_SPACING_DP]（4 + 4 = 8），这样每行
 * 的左右总宽与上方搜索框完全一致。
 */
@Composable
private fun IconGridRow(
    row: List<IconCell?>,
    columns: Int,
    onTap: (Int) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = SettingsGlassDockIconEditorPage.ROW_SPACING_DP.dp),
    ) {
        row.forEachIndexed { index, cell ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .padding(
                        start = if (index == 0) 0.dp else HalfCellSpacing,
                        end = if (index == columns - 1) 0.dp else HalfCellSpacing,
                    ),
            ) {
                if (cell != null) {
                    IconGridCell(cell = cell, onClick = { onTap(index) })
                }
            }
        }
    }
}

/**
 * 一格：26dp 矢量图标 + 11sp 名称小字（Dart :243-313）。
 *
 * 选中态照 Dart：主色图标/文字 + 12% 主色底 + 1.6dp 主色描边。
 * 「默认加号」格没有矢量名，回落官方 [MiuixIcons.Add]。
 *
 * 描边用官方 `squircleBorder`（而非 `Modifier.border`），与 `QingyuCard` 的
 * squircle 表面同一形状；卡片底色在选中时置透明，底层由 `squircleBackground`
 * 铺 12% 主色——否则卡自带的背景会把描边盖住。
 */
@Composable
private fun IconGridCell(
    cell: IconCell,
    onClick: () -> Unit,
) {
    val primary = MiuixTheme.colorScheme.primary
    val selected = cell.selected
    val iconColor = if (selected) primary else MiuixTheme.colorScheme.onBackground
    val labelColor = if (selected) primary else MiuixTheme.colorScheme.onSurfaceVariantSummary

    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (selected) {
                    Modifier
                        .squircleBackground(
                            color = primary.copy(alpha = SELECTED_TINT_ALPHA),
                            cornerRadius = CellCornerRadius,
                        )
                        .squircleBorder(
                            width = SELECTED_BORDER_WIDTH,
                            color = primary,
                            cornerRadius = CellCornerRadius,
                        )
                } else {
                    Modifier
                },
            ),
        cornerRadius = CellCornerRadius,
        insideMargin = PaddingValues(horizontal = 2.dp, vertical = 8.dp),
        colors = CardDefaults.defaultColors(
            color = if (selected) Color.Transparent else MiuixTheme.colorScheme.surfaceContainer,
        ),
        onClick = onClick,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val vector = cell.name?.let { GlassDockIconVectors.byName(it) }
            if (vector != null) {
                Icon(
                    imageVector = vector,
                    // 名称由下方 Text 提供，卡片合并语义后图标再报一次就是重复朗读。
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(SettingsGlassDockIconEditorPage.ICON_SIZE_DP.dp),
                )
            } else {
                // 默认格：Dart 用 Material 的 add_rounded；这里用官方 Miuix 加号。
                Icon(
                    imageVector = MiuixIcons.Add,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(DefaultIconSize),
                )
            }
            Spacer(modifier = Modifier.height(5.dp))
            Text(
                text = cell.label,
                style = MiuixTheme.textStyles.footnote2,
                color = labelColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/** 半格间距（Dart `_halfCellSpacing = _cellSpacing / 2`）。 */
private val HalfCellSpacing = (SettingsGlassDockIconEditorPage.CELL_SPACING_DP / 2).dp

/** 格子圆角（Dart `BorderRadius.circular(14)`）。 */
private val CellCornerRadius = 14.dp

/** 默认格加号边长（Dart `Icon(Icons.add_rounded, size: 22)`）。 */
private val DefaultIconSize = 22.dp

/** 选中描边宽度（Dart `Border.all(width: 1.6)`）。 */
private val SELECTED_BORDER_WIDTH = 1.6.dp

/** 选中底色透明度（Dart `accentSurfaceTintColor` = `accent.withValues(alpha: 0.12)`）。 */
private const val SELECTED_TINT_ALPHA = 0.12f

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）
//
// 只给实现阶段看效果，不进业务路径。
//
// 这一页只有两块（搜索卡 + 图标网格），分支也就两处，所以预览按分支铺：
//
//   1 默认加号 —— 没有选中项，首格是「默认」加号格；
//   2 选中图标 —— 传一个真实图标名，那一格画成选中态（12% 主色底 + 1.6dp 描边）；
//   3 暗色     —— 同一份数据换外观；
//   4 大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 选中态是这页**唯一**有颜色分支的格子（squircleBackground + squircleBorder），
//     不传名字就永远看不到它；
//   · 暗色 —— 选中底是 12% 主色透明，落在深色底上最容易「看不出选中」；
//   · 大字号 —— 格内名称是单行省略号，放大后才会暴露截断。
//
// 固定写法（与 about/ContributorsPage.kt 尾部那批同口径，照抄，别自己想）：
//   • 主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }：页面里取色走
//     isSystemInDarkTheme()，只有它会把 LocalConfiguration 的 uiMode 一起改写；
//   • 字号用 QingyuPageTheme(textScale = …)，不要用 @Preview(fontScale = …)；
//   • 宽度按 400dp（本仓折行实测口径），高度给一屏多。
// ─────────────────────────────────────────────────────────────────────────────

/**
 * 预览用的选中图标名：取清单里真实存在的一个（[GlassDockIconCatalog.names] 里有 `alarm`，
 * [GlassDockIconVectors.byName] 也认得），那一格才会走到「选中」分支。
 * 写成常量而不是 `names.first()`：首格已经被「默认加号」占了，再用 `add` 会两者撞脸。
 */
private const val PREVIEW_SELECTED_ICON_NAME = "alarm"

/** 一档预览的公共身体：选中档位 + 外观档位。 */
@Composable
private fun PreviewGlassDockIconPickerScreen(
    initialName: String?,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        GlassDockIconPickerScreen(
            initialName = initialName,
            onSelect = {},
            onBack = {},
        )
    }
}

// ── 单档：选中分支 × 外观 ───────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 默认加号", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockIconPickerScreenPreviewDefault() {
    PreviewGlassDockIconPickerScreen(initialName = null)
}

@Suppress("unused")
@Preview(name = "2 选中图标", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockIconPickerScreenPreviewSelected() {
    PreviewGlassDockIconPickerScreen(initialName = PREVIEW_SELECTED_ICON_NAME)
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockIconPickerScreenPreviewDark() {
    PreviewGlassDockIconPickerScreen(initialName = PREVIEW_SELECTED_ICON_NAME, dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockIconPickerScreenPreviewLargeText() {
    PreviewGlassDockIconPickerScreen(initialName = PREVIEW_SELECTED_ICON_NAME, textScale = 1.3f)
}
