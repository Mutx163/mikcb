package com.mutx163.qingyu.pages.settings

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.squircle.squircleBackground
import top.yukonga.miuix.kmp.squircle.squircleBorder
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 圆钮图标挑选页的**渲染层**（`lib/screens/settings/settings_glass_dock_icon_editor.dart`）。
 *
 * 页面只有两块，与 Dart 逐段对应：
 *
 * 1. 顶部搜索卡（Dart :171-189）：Dart 先垫一张白卡再放 `HyperosSearchBar`，原因是
 *    搜索框填充色对页面背景没有对比；这里照抄「卡内搜索框」的做法——官方
 *    `TextField` 放在 `QingyuCard` 里；
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
        title = SettingsStringsExt4.glassDockButtonIconTitle.zh,
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
                    IconSearchCard(query = query, onQueryChange = { query = it })
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

/** 搜索卡：官方 `TextField` + 前置放大镜 + 有文字时给清除按钮（Dart :171-189）。 */
@Composable
private fun IconSearchCard(
    query: String,
    onQueryChange: (String) -> Unit,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp, bottom = 12.dp),
        insideMargin = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = MiuixIcons.Search,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            )
            Spacer(modifier = Modifier.width(8.dp))
            TextField(
                value = query,
                onValueChange = onQueryChange,
                modifier = Modifier.weight(1f),
                label = SettingsStringsExt4.glassDockButtonIconSearchHint.zh,
                useLabelAsPlaceholder = true,
                singleLine = true,
            )
            if (query.isNotEmpty()) {
                IconButton(onClick = { onQueryChange("") }) {
                    Icon(
                        imageVector = MiuixIcons.Close,
                        contentDescription = SettingsStringsExt4.clearSearchAction.zh,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }
    }
}

/**
 * 一行图标格（Dart :194-222）。
 *
 * [row] 由模型保证长度 = [columns]（末行不足处是 null 占位）。首末格贴边，相邻格之间
 * 各留半个 [SettingsGlassDockIconEditorPage.CELL_SPACING_DP]（4 + 4 = 8），这样每行
 * 的左右总宽与上方搜索卡完全一致。
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
