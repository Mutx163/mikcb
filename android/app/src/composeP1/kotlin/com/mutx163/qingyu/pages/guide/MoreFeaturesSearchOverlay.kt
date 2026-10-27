package com.mutx163.qingyu.pages.guide

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 全部功能页全屏搜索浮层 · Compose 渲染层。
 * 对应 Flutter `lib/screens/more_features_search_overlay.dart`：
 * 1. 全屏沉浸式遮罩；
 * 2. 顶部实时搜索输入框与「取消」按钮；
 * 3. 搜索关键词高亮与空态提示。
 */
@Composable
fun MoreFeaturesSearchOverlay(
    groups: List<MoreFeatureGroup> = MoreFeaturesModel.buildDefaultFeatureGroups(),
    onDismiss: () -> Unit,
    onSelectFeature: (featureId: String) -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))
    val filteredGroups = remember(searchQuery, groups) {
        MoreFeaturesModel.filterGroups(groups, searchQuery)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(QingyuTheme.scaffoldBackground(dark)))
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // 顶部搜索栏与取消按钮
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(modifier = Modifier.weight(1f)) {
                    TextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                Spacer(modifier = Modifier.width(10.dp))

                Button(
                    onClick = onDismiss,
                    colors = ButtonDefaults.buttonColors(Color.Transparent)
                ) {
                    Text(
                        text = "取消",
                        color = primaryColor,
                        style = MiuixTheme.textStyles.body2,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            if (filteredGroups.isEmpty()) {
                // 搜索空态提示
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Box(
                            modifier = Modifier
                                .size(56.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(primaryColor.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Search,
                                contentDescription = null,
                                tint = primaryColor,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = GuideStrings.homeMenuMoreSearchEmptyTitle.zh,
                            style = MiuixTheme.textStyles.body1,
                            fontWeight = FontWeight.Bold,
                            color = Color(QingyuTheme.primaryText(dark))
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = GuideStrings.homeMenuMoreSearchEmptyHint.zh,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark))
                        )
                    }
                }
            } else {
                // 搜索结果列表
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    items(filteredGroups, key = { it.id }) { group ->
                        Column {
                            Text(
                                text = group.title,
                                style = MiuixTheme.textStyles.footnote1,
                                fontWeight = FontWeight.SemiBold,
                                color = primaryColor,
                                modifier = Modifier.padding(start = 6.dp, bottom = 6.dp)
                            )

                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(horizontal = 14.dp, vertical = 6.dp)
                            ) {
                                Column {
                                    group.items.forEachIndexed { idx, item ->
                                        if (idx > 0) HorizontalDivider()
                                        SearchResultRow(
                                            item = item,
                                            query = searchQuery,
                                            onClick = {
                                                onSelectFeature(item.id)
                                                onDismiss()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 带有高亮效果的搜索结果行。
 */
@Composable
private fun SearchResultRow(
    item: MoreFeatureItem,
    query: String,
    onClick: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))
    val highlightParts = remember(item.title, query) {
        MoreFeaturesModel.highlightText(item.title, query)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                highlightParts.forEach { part ->
                    Text(
                        text = part.text,
                        style = MiuixTheme.textStyles.body2,
                        fontWeight = if (part.isHighlight) FontWeight.Bold else FontWeight.Normal,
                        color = if (part.isHighlight) primaryColor else Color(QingyuTheme.primaryText(dark))
                    )
                }
            }

            if (!item.subtitle.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = item.subtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark))
                )
            }
        }

        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(16.dp)
        )
    }
}
