package com.mutx163.qingyu.pages.weather

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.weather.WeatherLocation
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
 * 天气选城市页 · Compose 渲染层（1:1 对齐 Flutter `weather_city_picker_screen.dart`）。
 *
 * 结构（与 Dart 一致）：**「当前位置」分组 + 「搜索城市」输入框 + 结果列表**。
 * 与旧版的区别：去掉了原版没有的「热门城市」标签流与 40 城静态全量列表——原版是
 * 通过 Open-Meteo 地理编码**联网搜任意城市**，结果行带行政区（`regionLabel`）以便区分同名村。
 *
 * 本页是**纯展示**：搜索、防抖、定位、落盘都在宿主 [WeatherCityPickerHost]（数据来自
 * 单一天气 provider）。这样本文件不依赖网络/状态机，可单独预览。
 */
data class WeatherCityPickerUiState(
    val query: String = "",
    val results: List<WeatherLocation> = emptyList(),
    val searching: Boolean = false,
    /** 已经搜过一次（用于区分「还没搜」与「搜了没结果」）。 */
    val settled: Boolean = false,
    val locating: Boolean = false,
    /** 当前已选城市（尾随「当前位置」行显示其地名）。 */
    val currentCity: WeatherLocation? = null,
    /** 出错文案（定位失败等）。 */
    val error: String? = null,
)

@Composable
fun WeatherCityPickerPage(
    state: WeatherCityPickerUiState,
    onBack: () -> Unit,
    onQueryChange: (String) -> Unit,
    onSelect: (WeatherLocation) -> Unit,
    onRelocate: () -> Unit,
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
            modifier = Modifier.imePadding(),
        ) {
            // ── 1. 当前位置 ──
            item(key = "location-title") {
                QingyuSectionTitle(WeatherStrings.weatherSectionCurrentLocation.zh)
            }
            item(key = "location-card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                    insideMargin = PaddingValues(14.dp),
                    onClick = if (state.locating) null else onRelocate,
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
                                style = MiuixTheme.textStyles.body1
                                    .shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = colors.onSurface,
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            val subtitle = when {
                                state.locating -> WeatherStrings.weatherLocating.zh
                                state.error != null -> state.error
                                state.currentCity != null -> state.currentCity.displayName
                                else -> WeatherStrings.weatherCityNotSet.zh
                            }
                            Text(
                                text = subtitle,
                                style = MiuixTheme.textStyles.footnote1,
                                color = if (state.error != null) colors.error else colors.onSurfaceVariantSummary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        if (state.locating) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp))
                        } else {
                            IconButton(onClick = onRelocate, backgroundColor = Color.Transparent) {
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

            // ── 2. 搜索城市 ──
            item(key = "search-title") {
                QingyuSectionTitle(WeatherStrings.weatherSectionSearchCity.zh)
            }
            item(key = "search") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
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

            // ── 3. 结果区 ──
            when {
                state.searching -> item(key = "searching") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 28.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(22.dp))
                    }
                }

                state.settled && state.results.isEmpty() -> item(key = "search-empty") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 16.dp),
                    ) {
                        Text(
                            text = WeatherStrings.weatherCitySearchEmpty.zh,
                            style = MiuixTheme.textStyles.body2,
                            color = colors.onSurfaceVariantSummary,
                        )
                    }
                }

                state.results.isNotEmpty() -> item(key = "search-results") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                        insideMargin = PaddingValues(0.dp),
                    ) {
                        Column {
                            state.results.forEachIndexed { index, location ->
                                if (index > 0) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(start = 16.dp),
                                        thickness = 0.75.dp,
                                        color = colors.dividerLine,
                                    )
                                }
                                WeatherCityRow(
                                    location = location,
                                    selected = state.currentCity?.isSamePlaceAs(location) == true,
                                    onClick = { onSelect(location) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WeatherCityRow(
    location: WeatherLocation,
    selected: Boolean,
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
                text = location.name,
                style = MiuixTheme.textStyles.body1
                    .shiftWeight(QingyuWeightDelta.MEDIUM),
                color = colors.onSurface,
            )
            if (location.regionLabel.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = location.regionLabel,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                )
            }
        }
        if (selected) {
            Icon(
                imageVector = MiuixIcons.Ok,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = colors.primary,
            )
        }
    }
}
