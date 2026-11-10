package com.mutx163.qingyu.pages.showcase

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.basic.SearchBarDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.Search
import top.yukonga.miuix.kmp.icon.basic.SearchCleanup
import top.yukonga.miuix.kmp.icon.extended.Search as ExtendedSearch
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Create
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * Miuix 展示册 · 主页面（Compose 渲染层）。
 *
 * 对应 Flutter `lib/screens/miuix_showcase_screen.dart`：
 * 包含 13 大类组件目录列表、实时检索、搜索历史与分类详情交互视图。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MiuixShowcasePage(
    onBack: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))

    var searchQuery by remember { mutableStateOf("") }
    var searchHistory by remember {
        mutableStateOf(listOf("按钮", "输入", "卡片", "选择器"))
    }
    var activeCategory by remember { mutableStateOf<ShowcaseCategoryId?>(null) }
    var interactionState by remember { mutableStateOf(ShowcaseInteractionState()) }

    val filteredEntries = remember(searchQuery) {
        MiuixShowcaseCatalog.filterEntries(searchQuery)
    }

    // Dart miuix_showcase_screen.dart:604-622 的 MiuixTopAppBar 传了 scrollBehavior 且没关大标题，
    // largeTitle 默认等于 title ⇒ 保留可折叠大标题（由共享骨架给）。
    val pageTitle = if (activeCategory == null) {
        ShowcaseStrings.showcaseScreenTitle.text
    } else {
        MiuixShowcaseCatalog.findEntryByCategory(activeCategory!!).title
    }

    // 骨架 / 顶栏 / 返回键走共享套件（R1）：返回键在子分类里是「回到目录」，
    // 与 Dart 侧行为一致；页面级滚动走 QingyuPageList（R2）。
    QingyuPageScaffold(
        title = pageTitle,
        onBack = {
            if (activeCategory != null) {
                activeCategory = null
            } else {
                onBack()
            }
        },
    ) {

        // 若进入子分类，则渲染该分类对应的交互详情页
        if (activeCategory != null) {
            MiuixShowcaseCategoryDetail(
                category = activeCategory!!,
                state = interactionState,
                onStateChange = { interactionState = it },
                dark = dark,
                primaryColor = primaryColor,
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
            )
        } else {
            // 否则渲染主目录列表与搜索栏
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                // 官方配方：页面横向 0，留白由每个块自己带（卡片 12dp）——
                // 与分类详情页（MiuixShowcaseSubpages）同一套刻度。
                // 滚动条位置与此无关：miuix 竖条只用 trackPadding 的上下两个值，
                // 左右两个值不参与定位。
                horizontalPadding = QingyuPageCardMargin,
                contentPadding = PaddingValues(top = 12.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 1. 搜索框：miuix 官方 `InputField` 胶囊（45dp、surfaceContainerHigh、
                // 左右 16/8 图标位），不再套卡片、也不自拼 Row+TextField。
                item(key = "search") {
                    InputField(
                        query = searchQuery,
                        onQueryChange = { searchQuery = it },
                        // 输入即筛，没有独立提交动作（回车只收键盘）。
                        onSearch = { },
                        expanded = false,
                        onExpandedChange = { },
                        modifier = Modifier.fillMaxWidth(),
                        label = ShowcaseStrings.showcaseSearchHint.text,
                        // 默认放大镜的朗读文案是库里的英文 "Search"；输入框已有 label，
                        // 图标纯装饰 ⇒ 交回正文朗读。
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
                        // 清空键：44dp 触区、start 8 / end 16、无涟漪；文案复用全站「清空」。
                        trailingIcon = {
                            AnimatedVisibility(
                                visible = searchQuery.isNotEmpty(),
                                enter = fadeIn(),
                                exit = fadeOut(),
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.Basic.SearchCleanup,
                                    contentDescription = SettingsStringsExt4.clearSearchAction.text,
                                    tint = MiuixTheme.colorScheme.onSurface,
                                    modifier = Modifier
                                        .size(44.dp)
                                        .padding(start = 8.dp, end = 16.dp)
                                        .clickable(interactionSource = null, indication = null) {
                                            searchQuery = ""
                                        },
                                )
                            }
                        },
                    )
                }

                // 2. 搜索历史（当搜索词为空时展示）
                if (searchQuery.isEmpty() && searchHistory.isNotEmpty()) {
                    item(key = "history") {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                // 列表 12 + 16 = 28：与下面卡片里首列文字同一条轴线。
                                .padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = ShowcaseStrings.showcaseSearchHistoryTitle.text,
                                style = MiuixTheme.textStyles.footnote1,
                                fontWeight = FontWeight.Medium,
                                color = Color(QingyuTheme.secondaryText(dark))
                            )
                            Text(
                                text = ShowcaseStrings.showcaseClearHistory.text,
                                style = MiuixTheme.textStyles.footnote1,
                                color = primaryColor,
                                modifier = Modifier.clickable {
                                    searchHistory = emptyList()
                                }
                            )
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        // 胶囊与标题同一条左缘（另外让出 16dp 时，标签会比标题缩进一格）。
                        FlowRow(
                            modifier = Modifier.padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            searchHistory.forEach { tag ->
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(16.dp))
                                        .background(Color(QingyuTheme.card(dark)))
                                        .clickable { searchQuery = tag }
                                        .padding(horizontal = 12.dp, vertical = 6.dp)
                                ) {
                                    Text(
                                        text = tag,
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = Color(QingyuTheme.primaryText(dark))
                                    )
                                }
                            }
                        }
                    }
                }

                // 3. 统计计数
                item(key = "count") {
                    QingyuSectionTitle(
                        text = if (searchQuery.isEmpty()) {
                            ShowcaseStrings.showcaseCategoryCountLabel.filled(
                                "count",
                                filteredEntries.size.toString()
                            )
                        } else {
                            "检索结果 (${filteredEntries.size})"
                        },
                        // 列表 12 + 16 = 28：与卡片内容左缘对齐（默认 28 会变成 40）。
                        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    )
                }

                // 4. 空态提示：改调共享空态组件（C37）——示例页自己先用上，顺带自证
                // 尺寸/字阶/墨色一套（48dp 图标 + 17sp 标题），不再自拼 Box + 灰字。
                if (filteredEntries.isEmpty()) {
                    item(key = "empty") {
                        QingyuEmptyState(
                            icon = MiuixIcons.Info,
                            title = ShowcaseStrings.showcaseSearchNoResults.text,
                        )
                    }
                }

                // 5. 分类卡片列表
                items(filteredEntries, key = { it.id }) { entry ->
                    ShowcaseEntryCard(
                        entry = entry,
                        dark = dark,
                        primaryColor = primaryColor,
                        onClick = {
                            searchHistory = MiuixShowcaseCatalog.addSearchHistory(
                                searchHistory,
                                entry.title
                            )
                            activeCategory = entry.category
                        }
                    )
                }
            }
        }
    }
}

/**
 * 目录单个条目卡片。
 */
@Composable
private fun ShowcaseEntryCard(
    entry: ShowcaseEntry,
    dark: Boolean,
    primaryColor: Color,
    onClick: () -> Unit
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 图标徽标
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(primaryColor.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                val iconVector = when (entry.iconName) {
                    "create" -> MiuixIcons.Create
                    "edit" -> MiuixIcons.Edit
                    "listView" -> MiuixIcons.ListView
                    "gridView" -> MiuixIcons.GridView
                    "info" -> MiuixIcons.Info
                    "image" -> MiuixIcons.Image
                    "search" -> MiuixIcons.ExtendedSearch
                    else -> MiuixIcons.Settings
                }
                Icon(
                    imageVector = iconVector,
                    contentDescription = null,
                    tint = primaryColor,
                    modifier = Modifier.size(22.dp)
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            // 标题与说明
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = entry.title,
                    style = MiuixTheme.textStyles.body1,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.primaryText(dark))
                )
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = entry.summary,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 2
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = "查看",
                tint = Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.6f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照抄 about/ContributorsPage.kt 的样板）
//
// 只给实现阶段看效果，不进业务路径。本页没有外部数据入参（目录、搜索历史都是页内
// `remember`），所以只铺外观三档：亮色 / 暗色 / 大字号 1.3。
//
// 固定写法（与样板一致，别自己改）：
//   • 主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }：页面取色走
//     isSystemInDarkTheme()，只有它会改写 LocalConfiguration 的 uiMode，预览才和真机同口径；
//   • 字号用 QingyuPageTheme(textScale = …)，不要用 @Preview(fontScale = …)；
//   • 宽度按 400dp（本仓折行实测口径），高度给一屏多。
//
// 子分类详情页不在本页预览范围内：它由页面内 `activeCategory` 驱动，
// 要单独看请点进预览里的某一类，或给 `MiuixShowcaseCategoryDetail` 另铺预览。
// ─────────────────────────────────────────────────────────────────────────────

/** 一档预览的公共身体：外观档位。 */
@Composable
private fun PreviewMiuixShowcasePage(
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        MiuixShowcasePage(onBack = {})
    }
}

@Suppress("unused")
@Preview(name = "1 亮色目录", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewMiuixShowcaseLight() {
    PreviewMiuixShowcasePage()
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewMiuixShowcaseDark() {
    PreviewMiuixShowcasePage(dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewMiuixShowcaseLargeText() {
    PreviewMiuixShowcasePage(textScale = 1.3f)
}

// ── 整页档（2000dp）────────────────────────────────────────────────────────
//
// 本页是 13 类组件的长目录，900dp 一屏只能看到前三四张卡；整页档给 2000dp，
// 用来检查「搜索框 → 历史标签 → 计数标题 → 13 张分类卡」的整页节奏与末项留白。
// 原 900 档保留：900 看首屏，2000 看整页。

@Suppress("unused")
@Preview(name = "4 整页", showBackground = true, widthDp = 400, heightDp = 2000)
@Composable
private fun PreviewMiuixShowcaseFullPage() {
    PreviewMiuixShowcasePage()
}
