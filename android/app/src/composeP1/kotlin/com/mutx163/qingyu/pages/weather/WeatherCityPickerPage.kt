package com.mutx163.qingyu.pages.weather

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 天气模块选城市页 · Compose 渲染层（Phase 3 P3-J）。
 *
 * 对应 Flutter `lib/screens/weather_city_picker_screen.dart`：
 * - 官方 Miuix 风格顶栏（返回 + "选择城市"）
 * - 搜索输入框（输入城市名称或拼音实时过滤）
 * - 当前定位城市入口（带重新定位按钮与加载动画指示）
 * - 热门城市标签流（FlowRow / Chip 样式快速选择）
 * - 搜索结果或城市列表，支持点击返回与高亮勾选
 *
 * 骨架照 `docs/reference/compose-page-style-rules.md` §三 的标准配方：
 * 顶栏走 [QingyuPageScaffold]（本页是单行小标题，`smallTopBar = true`），
 * 整页只有一个官方滚动容器 [QingyuPageList]（末端轻震 + 过度滚动 + 右侧滚动条），
 * 搜索卡作为它的第一个 `item`——Dart 侧搜索框本来就在滚动内容的最前面，
 * 不是浮在列表外的固定条。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WeatherCityPickerPage(
    state: CityPickerState,
    onBack: () -> Unit,
    onSelectCity: (CityItem) -> Unit,
    onQueryChange: (String) -> Unit = {},
    onRelocate: () -> Unit = {},
) {
    val colors = MiuixTheme.colorScheme

    QingyuPageScaffold(
        title = WeatherStrings.weatherCityPickerTitle.zh,
        onBack = onBack,
        smallTopBar = true,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 24.dp),
        ) {

            // ── 搜索输入框（列表第一格）──
            item(key = "search") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 6.dp),
                    insideMargin = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(
                            imageVector = MiuixIcons.Search,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = colors.onSurfaceVariantSummary,
                        )
                        TextField(
                            value = state.query,
                            onValueChange = onQueryChange,
                            modifier = Modifier.fillMaxWidth(),
                            label = WeatherStrings.weatherCitySearchHint.zh,
                            singleLine = true,
                        )
                    }
                }
            }

            if (state.query.isNotBlank()) {
                // ── 搜索结果区 ──
                if (state.searchResults.isEmpty()) {
                    item(key = "search-empty") {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 40.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = WeatherStrings.weatherCitySearchEmpty.zh,
                                style = MiuixTheme.textStyles.body2,
                                color = colors.onSurfaceVariantSummary,
                            )
                        }
                    }
                } else {
                    item(key = "search-title") {
                        QingyuSectionTitle(WeatherStrings.weatherSectionSearchCity.zh)
                    }
                    item(key = "search-results") {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                            insideMargin = PaddingValues(0.dp),
                        ) {
                            Column {
                                state.searchResults.forEachIndexed { index, city ->
                                    if (index > 0) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(start = 16.dp),
                                            thickness = 0.75.dp,
                                            color = colors.dividerLine,
                                        )
                                    }
                                    CityListRow(
                                        city = city,
                                        isSelected = state.selectedCity?.id == city.id,
                                        onClick = { onSelectCity(city) },
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                // ── 1. 当前位置栏 ──
                item(key = "location-title") {
                    QingyuSectionTitle(WeatherStrings.weatherSectionCurrentLocation.zh)
                }
                item(key = "location-card") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                        insideMargin = PaddingValues(14.dp),
                        onClick = {
                            val current = state.currentLocatedCity
                            if (current != null) {
                                onSelectCity(current)
                            } else if (!state.isLocating) {
                                onRelocate()
                            }
                        },
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(38.dp)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(colors.primary.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = MiuixIcons.Location,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp),
                                    tint = colors.primary,
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = WeatherStrings.weatherUseCurrentLocation.zh,
                                    style = MiuixTheme.textStyles.body1,
                                    fontWeight = FontWeight.Medium,
                                    color = colors.onSurface,
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                val subtitle = when {
                                    state.isLocating -> WeatherStrings.weatherLocating.zh
                                    state.locationError != null -> state.locationError
                                    state.currentLocatedCity != null -> WeatherStrings.formatDisplayName(
                                        state.currentLocatedCity.name,
                                        state.currentLocatedCity.district,
                                    )
                                    else -> WeatherStrings.weatherCityNotSet.zh
                                }
                                Text(
                                    text = subtitle,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = if (state.locationError != null) colors.error else colors.onSurfaceVariantSummary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            if (state.isLocating) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(20.dp),
                                )
                            } else {
                                IconButton(
                                    onClick = onRelocate,
                                    backgroundColor = Color.Transparent,
                                ) {
                                    Icon(
                                        imageVector = MiuixIcons.Refresh,
                                        contentDescription = WeatherStrings.relocateAction,
                                        modifier = Modifier.size(18.dp),
                                        tint = colors.primary,
                                    )
                                }
                            }
                        }
                    }
                }

                // ── 2. 热门城市流式标签栏 ──
                item(key = "hot-title") {
                    QingyuSectionTitle(WeatherStrings.hotCitiesSection)
                }
                item(key = "hot-card") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                        insideMargin = PaddingValues(12.dp),
                    ) {
                        FlowRow(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            for (city in state.hotCities) {
                                val isSelected = state.selectedCity?.id == city.id
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(
                                            if (isSelected) colors.primary.copy(alpha = 0.15f)
                                            else colors.surfaceContainer
                                        )
                                        .clickable { onSelectCity(city) }
                                        .padding(horizontal = 14.dp, vertical = 8.dp),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    ) {
                                        Text(
                                            text = city.name,
                                            style = MiuixTheme.textStyles.body2,
                                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                            color = if (isSelected) colors.primary else colors.onSurface,
                                        )
                                        if (isSelected) {
                                            Icon(
                                                imageVector = MiuixIcons.Ok,
                                                contentDescription = null,
                                                modifier = Modifier.size(14.dp),
                                                tint = colors.primary,
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. 全部城市分组列表 ──
                item(key = "all-title") {
                    QingyuSectionTitle(WeatherStrings.allCitiesSection)
                }
                val provinces = groupCitiesByProvince(DEFAULT_CITIES)
                provinces.forEach { (province, cities) ->
                    item(key = "province-$province") {
                        Text(
                            text = province,
                            style = MiuixTheme.textStyles.footnote1,
                            fontWeight = FontWeight.Normal,
                            color = colors.onSurfaceVariantSummary,
                            // 与分组标题的 28dp 轴线对齐（Card 外边距 12 + 行内 16）。
                            modifier = Modifier.padding(
                                start = QingyuPageCardMargin + 16.dp,
                                top = 8.dp,
                                bottom = 2.dp,
                            ),
                        )
                    }
                    item(key = "cities-$province") {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin, vertical = 2.dp),
                            insideMargin = PaddingValues(0.dp),
                        ) {
                            Column {
                                cities.forEachIndexed { index, city ->
                                    if (index > 0) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(start = 16.dp),
                                            thickness = 0.75.dp,
                                            color = colors.dividerLine,
                                        )
                                    }
                                    CityListRow(
                                        city = city,
                                        isSelected = state.selectedCity?.id == city.id,
                                        onClick = { onSelectCity(city) },
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
 * 自包含状态的便捷重载版本。
 */
@Composable
fun WeatherCityPickerPage(
    initialCity: CityItem? = null,
    onBack: () -> Unit,
    onSelectCity: (CityItem) -> Unit,
    onRelocate: (() -> Unit)? = null,
) {
    var state by remember {
        mutableStateOf(CityPickerState(selectedCity = initialCity))
    }

    WeatherCityPickerPage(
        state = state,
        onBack = onBack,
        onSelectCity = onSelectCity,
        onQueryChange = { newQuery ->
            state = onQueryChanged(state, newQuery)
        },
        onRelocate = {
            if (onRelocate != null) {
                onRelocate()
            } else {
                state = onStartLocating(state)
            }
        },
    )
}

@Composable
private fun CityListRow(
    city: CityItem,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = city.name,
                style = MiuixTheme.textStyles.body1,
                fontWeight = FontWeight.Medium,
                color = colors.onSurface,
            )
            if (city.province.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                val region = WeatherStrings.formatRegionLabel(city.province, null, city.name)
                Text(
                    text = region.ifBlank { city.province },
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                )
            }
        }
        if (isSelected) {
            Icon(
                imageVector = MiuixIcons.Ok,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = colors.primary,
            )
        }
    }
}
