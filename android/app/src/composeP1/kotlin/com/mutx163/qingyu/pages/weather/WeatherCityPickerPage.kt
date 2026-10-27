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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
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

    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            // ── 标题栏：返回 + "选择城市" ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack, backgroundColor = Color.Transparent) {
                    Icon(
                        imageVector = MiuixIcons.Back,
                        contentDescription = "返回",
                        tint = colors.onBackground,
                    )
                }
                Text(
                    text = WeatherStrings.weatherCityPickerTitle.zh,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                )
            }

            // ── 搜索输入框 ──
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp),
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

            // ── 滚动内容区 ──
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                if (state.query.isNotBlank()) {
                    // ── 搜索结果区 ──
                    if (state.searchResults.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 40.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = WeatherStrings.weatherCitySearchEmpty.zh,
                                    fontSize = 14.sp,
                                    color = colors.onSurfaceVariantSummary,
                                )
                            }
                        }
                    } else {
                        item {
                            SectionHeader(WeatherStrings.weatherSectionSearchCity.zh)
                        }
                        item {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 4.dp),
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
                    item {
                        SectionHeader(WeatherStrings.weatherSectionCurrentLocation.zh)
                    }
                    item {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 4.dp),
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
                                        fontSize = 16.sp,
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
                                        fontSize = 13.sp,
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
                    item {
                        SectionHeader(WeatherStrings.hotCitiesSection)
                    }
                    item {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 4.dp),
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
                                                fontSize = 14.sp,
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
                    item {
                        SectionHeader(WeatherStrings.allCitiesSection)
                    }
                    val provinces = groupCitiesByProvince(DEFAULT_CITIES)
                    provinces.forEach { (province, cities) ->
                        item {
                            Text(
                                text = province,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Normal,
                                color = colors.onSurfaceVariantSummary,
                                modifier = Modifier.padding(start = 24.dp, top = 8.dp, bottom = 2.dp),
                            )
                        }
                        item {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 2.dp),
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
private fun SectionHeader(title: String) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = title,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = colors.onSurfaceVariantSummary,
        modifier = Modifier.padding(start = 20.dp, top = 14.dp, bottom = 4.dp),
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
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = colors.onSurface,
            )
            if (city.province.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                val region = WeatherStrings.formatRegionLabel(city.province, null, city.name)
                Text(
                    text = region.ifBlank { city.province },
                    fontSize = 13.sp,
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
