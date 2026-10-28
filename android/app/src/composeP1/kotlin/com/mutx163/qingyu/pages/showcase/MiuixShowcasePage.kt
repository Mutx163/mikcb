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
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Clear
import top.yukonga.miuix.kmp.icon.extended.Create
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.icon.extended.Settings

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
    // largeTitle 默认等于 title ⇒ 保留可折叠大标题。
    val pageTitle = if (activeCategory == null) {
        ShowcaseStrings.showcaseScreenTitle.zh
    } else {
        MiuixShowcaseCatalog.findEntryByCategory(activeCategory!!).title
    }
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = pageTitle,
                largeTitle = pageTitle,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    IconButton(
                        onClick = {
                            if (activeCategory != null) {
                                activeCategory = null
                            } else {
                                onBack()
                            }
                        }
                    ) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.primaryText(dark))
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .nestedScroll(scrollBehavior.nestedScrollConnection)
                .padding(innerPadding)
        ) {

            // 若进入子分类，则渲染该分类对应的交互详情页
            if (activeCategory != null) {
                MiuixShowcaseCategoryDetail(
                    category = activeCategory!!,
                    state = interactionState,
                    onStateChange = { interactionState = it },
                    dark = dark,
                    primaryColor = primaryColor
                )
            } else {
                // 否则渲染主目录列表与搜索栏
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // 1. 搜索框
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.Search,
                                    contentDescription = null,
                                    tint = Color(QingyuTheme.secondaryText(dark)),
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                TextField(
                                    value = searchQuery,
                                    onValueChange = { searchQuery = it },
                                    label = ShowcaseStrings.showcaseSearchHint.zh,
                                    modifier = Modifier.weight(1f)
                                )
                                if (searchQuery.isNotEmpty()) {
                                    IconButton(onClick = { searchQuery = "" }) {
                                        Icon(
                                            imageVector = MiuixIcons.Clear,
                                            contentDescription = "清空",
                                            tint = Color(QingyuTheme.secondaryText(dark)),
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // 2. 搜索历史（当搜索词为空时展示）
                    if (searchQuery.isEmpty() && searchHistory.isNotEmpty()) {
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 4.dp, vertical = 2.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = ShowcaseStrings.showcaseSearchHistoryTitle.zh,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = Color(QingyuTheme.secondaryText(dark))
                                )
                                Text(
                                    text = ShowcaseStrings.showcaseClearHistory.zh,
                                    fontSize = 12.sp,
                                    color = primaryColor,
                                    modifier = Modifier.clickable {
                                        searchHistory = emptyList()
                                    }
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            FlowRow(
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
                                            fontSize = 13.sp,
                                            color = Color(QingyuTheme.primaryText(dark))
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // 3. 统计计数
                    item {
                        SmallTitle(
                            text = if (searchQuery.isEmpty()) {
                                ShowcaseStrings.showcaseCategoryCountLabel.filled(
                                    "count",
                                    filteredEntries.size.toString()
                                )
                            } else {
                                "检索结果 (${filteredEntries.size})"
                            }
                        )
                    }

                    // 4. 空态提示
                    if (filteredEntries.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 40.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = ShowcaseStrings.showcaseSearchNoResults.zh,
                                    fontSize = 14.sp,
                                    color = Color(QingyuTheme.secondaryText(dark))
                                )
                            }
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
                    "search" -> MiuixIcons.Search
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
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.primaryText(dark))
                )
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = entry.summary,
                    fontSize = 12.sp,
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
