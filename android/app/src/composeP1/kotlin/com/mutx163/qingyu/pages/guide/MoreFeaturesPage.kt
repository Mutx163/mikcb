package com.mutx163.qingyu.pages.guide

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.preference.ArrowPreference

/**
 * 「全部功能」目录全览页 · Compose 渲染层。
 * 对应 Flutter `lib/screens/more_features_screen.dart`：
 * 1. 顶部搜索入口（发布版 `MiuixSearchBar` + `MiuixInputField`，点击展开全屏搜索浮层）；
 * 2. 6 大用户任务分组（课表内容、外观显示、通知与桌面、应用偏好、数据同步、关于支持）；
 * 3. 各条目展示当前状态副文本（如当前课表名/作息名）。
 *
 * ## 2026-11-10 整页观感对齐（D1 同波次）
 *
 * 用户反馈「这页 UI 很小，跟别页完全不一样」。根因不是预览参数（四档都是 400×900，
 * 与 `ImportEntryPage` 一致），而是**用手拼行冒充官方列表行**：
 * - 行标题 `body2` = 14sp，全站官方行（`ArrowPreference` → `BasicComponent`）是
 *   `headline1` = 17sp（小 3sp，-21%）；
 * - 副文本 `footnote1` = 13sp，官方行副文本 `body2` = 14sp；
 * - 分组标题自拼 `footnote1` + `start = 6.dp` → 左缘 22dp，官方 `SmallTitle` 是
 *   `subtitle`(14sp/Bold) + 28dp 左缘（正文左缘 28 = 卡 12 + 行内 16，错 6dp）；
 * - 搜索条是自绘圆角 24 胶囊（14sp 文字），发布版是官方 `SearchBar` + `InputField`
 *   （胶囊形、17sp Medium、官方前后图标与内边距）。
 *
 * 现在与 `ImportEntryPage` 同一配方：卡 12 + 官方 preference 行内 16 + 组标题 28 轴、组间距 12。
 */
@Composable
fun MoreFeaturesPage(
    activeProfileName: String? = null,
    activeTimeSchemeName: String? = null,
    onBack: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenFeature: (featureId: String) -> Unit
) {
    val groups = MoreFeaturesModel.buildDefaultFeatureGroups(
        activeProfileName = activeProfileName,
        activeTimeSchemeName = activeTimeSchemeName
    )

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃；大标题可折叠
    // （Dart 原件 lib/screens/more_features_screen.dart:196 走 HyperosSubpage 默认）。
    QingyuPageScaffold(title = GuideStrings.homeMenuMoreTitle.text, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 与全站列表页同一配方（见 `ImportEntryPage.kt:61-116`）：
            // 列表不加横向 padding，卡片自己带 `QingyuPageCardMargin`(12)，
            // 行内 16 由官方 preference 组件给 → 文字左缘落在 28dp 轴；
            // 组间距 12 是本仓统一刻度（发布版 `HyperosSectionGap` 也是 12）。
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // 顶部搜索入口：**直接**官方 `InputField`，与全屏浮层里那颗是同一个组件、同一组默认值
            // （45dp 胶囊 / `surfaceContainerHigh` / 官方放大镜与清空键）。
            //
            // 2026-11-10 搜索框统一（评审配方）：原先外面套了一层 `SearchBar`，而 `SearchBar` 自带
            // `InsideMargin = DpSize(12.dp, 0.dp)`（`SearchBar.kt:315`）——于是本页这颗左缘是
            // 12(卡距)+12(外壳)=24dp，浮层那颗是 16dp，点开前后横向「跳」一下。去掉外壳、
            // 横向自己给 16dp，与浮层同一轴线，点开不断档。
            item(key = "search") {
                InputField(
                    query = "",
                    onQueryChange = {},
                    onSearch = {},
                    expanded = false,
                    onExpandedChange = { if (it) onOpenSearch() },
                    label = GuideStrings.homeMenuMoreSearchHint.text,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                )
            }

            // 6 个任务分组：官方 SmallTitle + 官方 ArrowPreference 行（17sp 标题 / 官方行高 /
            // 官方按压反馈与箭头），与设置族、导入族同一套行组件。
            items(groups, key = { it.id }) { group ->
                QingyuSectionTitle(text = group.title)

                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                ) {
                    Column {
                        group.items.forEach { item ->
                            ArrowPreference(
                                title = item.title,
                                summary = item.subtitle,
                                onClick = { onOpenFeature(item.id) },
                            )
                        }
                    }
                }
            }
        }
    }
}

// ── 预览：Android Studio 里免装机看效果（2026-11-08 加）────────────────────
//
// 本页只有**一个外部可变项**：首页菜单里当前选中的课表方案名 / 作息方案名，
// 它们作为右侧尾随取值出现在行尾。因此铺「已选 / 未选」两档，再加外观两档。

/** 一档预览的公共身体：方案名 + 外观档位。 */
@Composable
private fun PreviewMoreFeaturesPage(
    activeProfileName: String? = "默认课表",
    activeTimeSchemeName: String? = "秋冬作息",
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        MoreFeaturesPage(
            activeProfileName = activeProfileName,
            activeTimeSchemeName = activeTimeSchemeName,
            onBack = {},
            onOpenSearch = {},
            onOpenFeature = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 已选方案", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MoreFeaturesPagePreviewWithActiveSchemes() {
    PreviewMoreFeaturesPage()
}

@Suppress("unused")
@Preview(name = "2 未选方案", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MoreFeaturesPagePreviewWithoutActiveSchemes() {
    PreviewMoreFeaturesPage(activeProfileName = null, activeTimeSchemeName = null)
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MoreFeaturesPagePreviewDark() {
    PreviewMoreFeaturesPage(dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun MoreFeaturesPagePreviewLargeText() {
    PreviewMoreFeaturesPage(textScale = 1.3f)
}
