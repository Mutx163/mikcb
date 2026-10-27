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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「全部功能」目录全览页 · Compose 渲染层。
 * 对应 Flutter `lib/screens/more_features_screen.dart`：
 * 1. 顶部折叠态搜索胶囊，点击弹出搜索浮层；
 * 2. 6 大用户任务分组（课表内容、外观显示、通知与桌面、应用偏好、数据同步、关于支持）；
 * 3. 各条目展示当前状态副文本（如当前课表名/作息名）。
 */
@Composable
fun MoreFeaturesPage(
    activeProfileName: String? = null,
    activeTimeSchemeName: String? = null,
    onBack: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenFeature: (featureId: String) -> Unit
) {
    val dark = isSystemInDarkTheme()
    val primaryColor = Color(QingyuTheme.primary(dark = dark))
    val groups = MoreFeaturesModel.buildDefaultFeatureGroups(
        activeProfileName = activeProfileName,
        activeTimeSchemeName = activeTimeSchemeName
    )

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark))
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = GuideStrings.homeMenuMoreTitle.zh,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.primaryText(dark))
                        )
                    }
                }
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = innerPadding.calculateTopPadding() + 4.dp,
                    bottom = 24.dp
                ),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // 顶部搜索胶囊入口
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(24.dp))
                            .background(Color(QingyuTheme.card(dark)))
                            .clickable(onClick = onOpenSearch)
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = MiuixIcons.Search,
                                contentDescription = null,
                                tint = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                text = GuideStrings.homeMenuMoreSearchHint.zh,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark))
                            )
                        }
                    }
                }

                // 6 个任务分组卡片
                items(groups, key = { it.id }) { group ->
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
                                group.items.forEachIndexed { index, item ->
                                    if (index > 0) HorizontalDivider()
                                    FeatureItemRow(
                                        item = item,
                                        onClick = { onOpenFeature(item.id) }
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

/**
 * 单个功能行。
 */
@Composable
private fun FeatureItemRow(
    item: MoreFeatureItem,
    onClick: () -> Unit
) {
    val dark = isSystemInDarkTheme()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.title,
                style = MiuixTheme.textStyles.body2,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark))
            )
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
