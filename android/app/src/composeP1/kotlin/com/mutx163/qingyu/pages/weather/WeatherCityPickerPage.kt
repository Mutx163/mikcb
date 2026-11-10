package com.mutx163.qingyu.pages.weather

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import com.mutx163.qingyu.components.EmptyStateHintEmphasis
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuEmptyHint
import com.mutx163.qingyu.components.QingyuLoadingAccentGlyph
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.settings.SettingsIconBadge
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.weather.WeatherLocation
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.basic.SearchBarDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.Search
import top.yukonga.miuix.kmp.icon.basic.SearchCleanup
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 行首徽章的底色：发布版 `HyperosIconColors.blue`（`hyperos_tokens.dart`，`0xFF3482FF`）。
 *
 * 写死而不是跟主题主色：发布版这颗 accent 是**常量**，暗色主题下也保持同一个蓝；
 * 参数走 `SettingsIconBadge(tintHex = …)` 的既有取值口，不在页内另造色板。
 */
private const val ICON_BADGE_BLUE = "#3482FF"

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
    /**
     * 这次搜索**请求失败**（断网 / 超时 / 接口返回非 JSON）。
     *
     * 与「搜到了但没有匹配」必须分开：前者要一句「搜索失败」+ 重试，后者才是
     * 「没有找到匹配的城市」。原先两者都走空结果，断网时等于告诉用户这个城市不存在。
     */
    val searchFailed: Boolean = false,
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
    /** 搜索失败时的「重试」：按当前关键字再搜一次。 */
    onRetrySearch: () -> Unit = {},
) {
    val colors = MiuixTheme.colorScheme

    QingyuPageScaffold(
        title = WeatherStrings.weatherCityPickerTitle.text,
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
                QingyuSectionTitle(WeatherStrings.weatherSectionCurrentLocation.text)
            }
            item(key = "location-card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                    // 行内边距：发布版是 `hyperosListRowShell(padding: 16/13/16/13)`
                    // （`HyperosMiuixSpec.settingsRowPadding`，`hyperos_miuix_spec.dart:88`）。
                    // 旧写法是四边 14，比发布版左右各窄 2、上下各多 1。
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 13.dp),
                    onClick = if (state.locating) null else onRelocate,
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        // 行首徽章：发布版 `HyperosListTile(icon:)` 画的不是裸图标，而是
                        // `HyperosIconBadge(icon, accent: HyperosIconColors.blue)`——
                        // 26dp 实心蓝 #3482FF 方块 + 7dp 圆角 + 白色 14dp 字形
                        // （`tiles.dart:310-316`、`indicators.dart:142-163`、`hyperos_tokens.dart:63-65`）。
                        // 直接复用设置族的同一块 `SettingsIconBadge`（几何逐字对齐、白字形写死），
                        // 不在这页另抄一份 26/7/14——抄两份迟早分叉。
                        SettingsIconBadge(glyph = MiuixIcons.Location, tintHex = ICON_BADGE_BLUE)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            // 标题：发布版 `listTitle` = 17sp w400（`hyperos_theme.dart:497-505`
                            // → `HyperosMiuixSpec.preferenceTitleSize = 17`）；旧写法是 16sp Medium。
                            Text(
                                text = WeatherStrings.weatherUseCurrentLocation.text,
                                style = MiuixTheme.textStyles.headline1,
                                color = colors.onSurface,
                            )
                            // 标题→副标题 3dp：发布版 `HyperosTokens.titleCaptionGap`（旧写法 2dp）。
                            Spacer(modifier = Modifier.height(3.dp))
                            val subtitle = when {
                                state.locating -> WeatherStrings.weatherLocating.text
                                state.error != null -> state.error
                                state.currentCity != null -> state.currentCity.displayName
                                else -> WeatherStrings.weatherCityNotSet.text
                            }
                            // 副标题：发布版 `listDetail` = body2 14sp w400（旧写法 13sp footnote1）。
                            Text(
                                text = subtitle,
                                style = MiuixTheme.textStyles.body2,
                                color = if (state.error != null) colors.error else colors.onSurfaceVariantSummary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        // 行尾**不画任何东西**（2026-11-10 裁决：撤除超出发布版的增强）。
                        // 发布版这一行就是「图标 + 标题 + 副标题（定位中是「正在定位……」）
                        // + 整行 onTap:null」（`weather_city_picker_screen.dart:139-146`）——
                        // 既没有行尾刷新图标、也没有转圈；重定位本来就是**点整行**触发的
                        // （上面的 `onClick = if (state.locating) null else onRelocate`）。
                    }
                }
            }

            // ── 2. 搜索城市 ──
            item(key = "search-title") {
                QingyuSectionTitle(WeatherStrings.weatherSectionSearchCity.text)
            }
            item(key = "search") {
                // 搜索框：miuix 官方 `InputField`（`SearchBar.kt:158`）的**页内常驻**用法
                // ——45dp 胶囊、`surfaceContainerHigh` 填充、放大镜与清除键都在组件内部。
                // 旧写法是「`QingyuCard` 里再套 `Row(Icon + TextField)`」，卡里套框两层底、
                // 高度与发布版对不上（发布版 `weather_city_picker_screen.dart:171-189` 是
                // 一颗 `HyperosSearchBar`）。配方与先例逐条一致：`2ecfbe15b`（坞图标选择器）、
                // `2cf97759b`（教务导入选校页）。
                WeatherSearchField(
                    query = state.query,
                    onQueryChange = onQueryChange,
                )
            }

            // ── 3. 结果区 ──
            when {
                state.searching -> item(key = "searching") {
                    // 搜索中：发布版是「28dp 上留白 + 居中的 22dp 细环」
                    // （`weather_city_picker_screen.dart:175-179`：`SizedBox(height: 28)` +
                    //  `SizedBox(22×22, CircularProgressIndicator(strokeWidth: 2.2))`）。
                    // 档 A 是 24 / 2.5，比发布版粗一档；套件里尺寸正好对得上的是 B′ 入口
                    // `QingyuLoadingAccentGlyph`（22 / 2.2、单圈无底环），颜色跟主题主色
                    // ——发布版这颗圈不传色，本来就是 primary。
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 28.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        QingyuLoadingAccentGlyph(accent = colors.primary)
                    }
                }

                state.searchFailed -> item(key = "search-failed") {
                    // **失败态不并进空态**（方案 C36 注：空说「没有」、失败说「为什么」）。
                    // 这里保留「红字 + 重试」的卡片形态：`QingyuEmptyHint` 只有次级墨，
                    // 把这句话刷成灰色反而丢掉「这次没搜到、是出错了」的区别。
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = WeatherStrings.weatherCitySearchFailed.text,
                                modifier = Modifier.weight(1f),
                                style = MiuixTheme.textStyles.body2,
                                color = colors.error,
                            )
                            TextButton(
                                text = WeatherStrings.weatherRetryAction.text,
                                onClick = onRetrySearch,
                            )
                        }
                    }
                }

                state.settled && state.results.isEmpty() -> item(key = "search-empty") {
                    // 真·空态：换共享行内提示（`QingyuEmptyHint`，14sp 正文档 + 次级墨），
                    // 字号与灰阶从此跟全站其它「没有结果」一致；位置与留白保持原样
                    // （方案 §4.1 C36 / §7.3 白名单：只换口径、不动布局）。
                    QingyuEmptyHint(
                        text = WeatherStrings.weatherCitySearchEmpty.text,
                        emphasis = EmptyStateHintEmphasis.Body,
                        modifier = Modifier.padding(horizontal = QingyuPageCardMargin, vertical = 16.dp),
                    )
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

// ── 预览：Android Studio 里免装机看效果（2026-11-08 加）────────────────────
//
// 本页是纯展示，结果区完全由 [WeatherCityPickerUiState] 决定，所以按「结果区四态」
// （搜索中 / 有结果 / 无结果 / 搜索失败）铺档，再加定位中与定位失败两态。

/** 搜索「杭州」会真实回来的地名：主标题 + 行政区副标题的层级要能一眼分清。 */
private val previewWeatherResults = listOf(
    WeatherLocation(
        name = "杭州",
        latitude = 30.2741,
        longitude = 120.1551,
        admin1 = "浙江省",
        country = "中国",
    ),
    WeatherLocation(
        name = "余杭",
        latitude = 30.4186,
        longitude = 120.3011,
        admin1 = "浙江省",
        country = "中国",
    ),
    WeatherLocation(
        name = "临安",
        latitude = 30.2337,
        longitude = 119.7247,
        admin1 = "浙江省",
        country = "中国",
    ),
)

/** 一档预览：状态名 + UI 状态快照。 */
private data class PreviewWeatherCityState(
    /** 只用来给预览命名，不参与渲染。 */
    val name: String,
    val state: WeatherCityPickerUiState,
)

private val previewWeatherCityStates: List<PreviewWeatherCityState> = listOf(
    PreviewWeatherCityState(
        name = "有结果",
        state = WeatherCityPickerUiState(
            query = "杭州",
            results = previewWeatherResults,
            settled = true,
            currentCity = previewWeatherResults.first(),
        ),
    ),
    PreviewWeatherCityState(
        name = "搜索中",
        state = WeatherCityPickerUiState(query = "北京", searching = true),
    ),
    PreviewWeatherCityState(
        name = "无结果",
        state = WeatherCityPickerUiState(query = "未来城", settled = true),
    ),
    PreviewWeatherCityState(
        name = "搜索失败",
        state = WeatherCityPickerUiState(query = "北京", settled = true, searchFailed = true),
    ),
    PreviewWeatherCityState(
        name = "定位中",
        state = WeatherCityPickerUiState(
            locating = true,
            currentCity = previewWeatherResults.first(),
        ),
    ),
    PreviewWeatherCityState(
        name = "定位失败",
        state = WeatherCityPickerUiState(error = "定位权限被拒绝"),
    ),
)

private fun previewWeatherCityState(name: String): WeatherCityPickerUiState =
    previewWeatherCityStates.first { it.name == name }.state

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewWeatherCityPickerPage(
    state: WeatherCityPickerUiState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        WeatherCityPickerPage(
            state = state,
            onBack = {},
            onQueryChange = {},
            onSelect = {},
            onRelocate = {},
            onRetrySearch = {},
        )
    }
}

// ── 单档：六态 × 亮色 ────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有结果", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewResults() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("有结果"))
}

/**
 * 搜索框：miuix 官方 `InputField`（`SearchBar.kt:158`）的**页内常驻**用法。
 *
 * 45dp 胶囊、`surfaceContainerHigh` 填充、放大镜与清除键都在组件内部；不再外套卡片、
 * 不自拼 `Row(Icon + TextField)`（那样两层底色 + 高度对不上发布版 `HyperosSearchBar`）。
 * 两颗图标的朗读文案照仓库先例自己画：放大镜纯装饰（输入框自带 label）⇒ `null`；
 * 清除键用 `clearSearchAction`（官方默认是库里的英文「Search Cleanup」）。
 */
@Composable
private fun WeatherSearchField(
    query: String,
    onQueryChange: (String) -> Unit,
) {
    val focusManager = LocalFocusManager.current
    InputField(
        query = query,
        onQueryChange = onQueryChange,
        // 没有独立提交动作：过滤随输入发生，回车只收键盘。
        onSearch = { focusManager.clearFocus() },
        expanded = false,
        onExpandedChange = { },
        label = WeatherStrings.weatherCitySearchHint.text,
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
        trailingIcon = {
            AnimatedVisibility(
                visible = query.isNotEmpty(),
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                Box(
                    modifier = Modifier
                        .size(width = 48.dp, height = 44.dp)
                        .clickable(interactionSource = null, indication = null) {
                            focusManager.clearFocus()
                            onQueryChange("")
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = MiuixIcons.Basic.SearchCleanup,
                        contentDescription = SettingsStringsExt4.clearSearchAction.text,
                        tint = MiuixTheme.colorScheme.onSurfaceContainerHigh,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        },
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin)
            .padding(top = 4.dp, bottom = 8.dp),
    )
}

@Suppress("unused")
@Preview(name = "2 搜索中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewSearching() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("搜索中"))
}

@Suppress("unused")
@Preview(name = "3 无结果", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewNoResult() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("无结果"))
}

@Suppress("unused")
@Preview(name = "4 搜索失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewSearchFailed() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("搜索失败"))
}

@Suppress("unused")
@Preview(name = "5 定位中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewLocating() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("定位中"))
}

@Suppress("unused")
@Preview(name = "6 定位失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewLocateFailed() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("定位失败"))
}

// ── 单档：外观两档（以「有结果」为基准）────────────────────────────────

@Suppress("unused")
@Preview(name = "7 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewDark() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("有结果"), dark = true)
}

@Suppress("unused")
@Preview(name = "8 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewLargeText() {
    PreviewWeatherCityPickerPage(previewWeatherCityState("有结果"), textScale = 1.3f)
}

// ── 总览：结果区四态并排 ────────────────────────────────────────────────

/**
 * 结果区四态横排：搜索中 / 有结果 / 无结果 / 搜索失败。
 *
 * 4 × 400dp + 3 × 16dp 间距 = 1648dp，所以画布给 1700dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~8 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·结果区四态", showBackground = true, widthDp = 1700, heightDp = 900)
@Composable
private fun WeatherCityPickerPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (name in listOf("搜索中", "有结果", "无结果", "搜索失败")) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewWeatherCityPickerPage(previewWeatherCityState(name))
            }
        }
    }
}
