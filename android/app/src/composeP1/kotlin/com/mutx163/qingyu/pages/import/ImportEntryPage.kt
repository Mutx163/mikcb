package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Community
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Months

/**
 * 课程导入入口页 · Compose 渲染层（P3-G1）。
 *
 * 对应 Flutter `lib/screens/import/course_import_entry_screen.dart`：
 * 随机配色开关 + 配色组行 → 「选择导入方式」分组标题 → 四种导入方式导航行。
 *
 * 页面是纯导航：可测逻辑（清单顺序 / 关单规则）在 [ImportEntryModel]，
 * 这里只消费 [ImportEntryViewState] 并把点击 / 开关抛给宿主。
 *
 * 版式说明：Dart 侧这些行在 `HyperosListGroup`（一张连续分组卡）里；本仓已交付页面的
 * 既有做法是一行一张官方 `Card`、8dp 间隔近似分组观感（about / schedule 同款，
 * 避免卡里套卡的双重底色），入口页照此办理。
 */
data class ImportEntryViewState(
    /** 随机课程颜色总开关（偏好服务的当前值）。 */
    val randomColorsEnabled: Boolean = false,
    /** 当前随机配色组 id（「全部颜色」/ 预设组）。 */
    val randomColorGroupId: String = ImportSharedModel.COURSE_COLOR_GROUP_ALL_ID,
    /** 偏好是否已读完：false 时开关与选组行都不可交互（Dart `_loaded`）。 */
    val preferencesLoaded: Boolean = false,
)

@Composable
fun ImportEntryPage(
    viewState: ImportEntryViewState,
    onBack: () -> Unit,
    onToggleRandomColors: (Boolean) -> Unit,
    onPickColorGroup: () -> Unit,
    onOpenDestination: (ImportEntryDestination) -> Unit,
) {
    ImportPageScaffold(
        title = ImportStrings.courseImportTitle.zh,
        onBack = onBack,
    ) { innerPadding, scrollBehavior ->
        LazyColumn(
            // 滚动手势必须喂给顶栏折叠行为，否则大标题永不收起（about 页教训）。
            modifier = Modifier
                .fillMaxSize()
                .nestedScroll(scrollBehavior.nestedScrollConnection),
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = innerPadding.calculateTopPadding() + 8.dp,
                bottom = innerPadding.calculateBottomPadding() + 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // ── 随机配色开关（Dart widgets/import_random_color_toggle.dart）──
            item(key = "random_color_switch") {
                ImportSwitchRow(
                    title = ImportStrings.importRandomCourseColorTitle.zh,
                    subtitle = ImportStrings.importRandomCourseColorSubtitle.zh,
                    icon = ImportEntryIcons.randomColor, // Dart Icons.palette_outlined 的最接近官方图标
                    accentHex = "purple",
                    checked = viewState.randomColorsEnabled,
                    enabled = viewState.preferencesLoaded,
                    onCheckedChange = onToggleRandomColors,
                )
            }
            item(key = "random_color_group") {
                ImportValueRow(
                    title = ImportStrings.importRandomColorGroupTitle.zh,
                    value = ImportSharedModel.colorGroupDisplayName(viewState.randomColorGroupId),
                    enabled = viewState.preferencesLoaded && viewState.randomColorsEnabled,
                    onClick = onPickColorGroup,
                )
            }
            // ── 选择导入方式 ──
            item(key = "method_label") {
                ImportSectionLabel(ImportStrings.chooseImportMethodTitle.zh)
            }
            items(ImportEntryModel.entries.size, key = { index -> "method-$index" }) { index ->
                val entry = ImportEntryModel.entries[index]
                ImportNavRow(
                    title = entry.title,
                    subtitle = entry.subtitle,
                    icon = entryIcon(entry.destination),
                    accentHex = entry.accentSlot,
                    onClick = { onOpenDestination(entry.destination) },
                )
            }
        }
    }
}

/** 四种导入方式的图标（Dart Material 图标 → 最接近的官方 Miuix 图标）。 */
private fun entryIcon(destination: ImportEntryDestination): ImageVector = when (destination) {
    // Dart Icons.event_note_rounded（带笔记的日历）
    ImportEntryDestination.ICS -> MiuixIcons.Months
    // Dart Icons.auto_awesome_rounded（✨）；Miuix 无 sparkle，识图语义取 Image
    ImportEntryDestination.AI -> MiuixIcons.Image
    // Dart Icons.school_outlined（学校）
    ImportEntryDestination.WAREHOUSE -> MiuixIcons.Community
    // Dart Icons.table_chart_outlined（表格）
    ImportEntryDestination.SPREADSHEET -> MiuixIcons.GridView
}

/** 入口页图标槽位（集中声明，避免在行构建处散落 when 分支）。 */
private object ImportEntryIcons {
    val randomColor: ImageVector = MiuixIcons.Favorites
}
