package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
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
        title = ImportStrings.courseImportTitle.text,
        onBack = onBack,
    ) { innerPadding, scrollBehavior ->
        // 页面级滚动走共享套件（官方三件套 + 右侧滚动条 + 顶栏折叠联动）。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // ── 随机配色开关（Dart widgets/import_random_color_toggle.dart）──
            item(key = "random_color_switch") {
                ImportSwitchRow(
                    title = ImportStrings.importRandomCourseColorTitle.text,
                    subtitle = ImportStrings.importRandomCourseColorSubtitle.text,
                    icon = ImportEntryIcons.randomColor, // Dart Icons.palette_outlined 的最接近官方图标
                    accentHex = "purple",
                    checked = viewState.randomColorsEnabled,
                    enabled = viewState.preferencesLoaded,
                    onCheckedChange = onToggleRandomColors,
                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                )
            }
            item(key = "random_color_group") {
                ImportValueRow(
                    title = ImportStrings.importRandomColorGroupTitle.text,
                    value = ImportSharedModel.colorGroupDisplayName(viewState.randomColorGroupId),
                    enabled = viewState.preferencesLoaded && viewState.randomColorsEnabled,
                    onClick = onPickColorGroup,
                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                )
            }
            // ── 选择导入方式 ──
            item(key = "method_label") {
                // 分组标题走官方 SmallTitle（自带 28dp 左缘），与「Card 12 + 行内 16」对齐。
                QingyuSectionTitle(
                    text = ImportStrings.chooseImportMethodTitle.text,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
            items(ImportEntryModel.entries.size, key = { index -> "method-$index" }) { index ->
                val entry = ImportEntryModel.entries[index]
                ImportNavRow(
                    title = entry.title,
                    subtitle = entry.subtitle,
                    icon = entryIcon(entry.destination),
                    accentHex = entry.accentSlot,
                    onClick = { onOpenDestination(entry.destination) },
                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄，别自己想）：
//   · 主题一律包 `QingyuPageTheme(isDark = …)`，不要直接 `MiuixTheme { }`：页面取色走
//     `isSystemInDarkTheme()`，只有它会把 `LocalConfiguration` 的 uiMode 一起改写，
//     预览才和真机同口径；
//   · 字号用 `QingyuPageTheme(textScale = …)`，不要用 `@Preview(fontScale = …)`，后者绕过了
//     应用的 appTextScale 口径；
//   · 宽度按 400dp（本仓折行实测口径），高度给一屏多，避免列表被截断看不清。
//
// 档位：偏好已读完（默认）、偏好未读完（两行都灰）、随机配色关（选组行灰）各一档，
// 再加暗色与大字号——这三条分支各改一次文案/交互，最容易只改其中一条。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用：偏好已读完、随机配色开、配色组为「全部颜色」，即宿主最常见的首帧。 */
private val previewImportEntryLoaded = ImportEntryViewState(
    randomColorsEnabled = true,
    randomColorGroupId = ImportSharedModel.COURSE_COLOR_GROUP_ALL_ID,
    preferencesLoaded = true,
)

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewImportEntryPage(
    state: ImportEntryViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        ImportEntryPage(
            viewState = state,
            onBack = {},
            onToggleRandomColors = { _ -> },
            onPickColorGroup = {},
            onOpenDestination = { _ -> },
        )
    }
}

@Suppress("unused")
@Preview(name = "1 默认·偏好已读完", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ImportEntryPagePreviewDefault() {
    PreviewImportEntryPage(previewImportEntryLoaded)
}

@Suppress("unused")
@Preview(name = "2 偏好未读完", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ImportEntryPagePreviewPreferencesLoading() {
    PreviewImportEntryPage(ImportEntryViewState(preferencesLoaded = false))
}

@Suppress("unused")
@Preview(name = "3 随机配色关闭", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ImportEntryPagePreviewRandomColorsOff() {
    PreviewImportEntryPage(
        ImportEntryViewState(randomColorsEnabled = false, preferencesLoaded = true),
    )
}

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ImportEntryPagePreviewDark() {
    PreviewImportEntryPage(previewImportEntryLoaded, dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ImportEntryPagePreviewLargeText() {
    PreviewImportEntryPage(previewImportEntryLoaded, textScale = 1.3f)
}
