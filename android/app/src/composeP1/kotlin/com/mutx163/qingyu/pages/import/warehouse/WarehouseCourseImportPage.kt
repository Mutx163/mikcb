package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.SearchCleanup
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 仓库教务导入主页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_course_import_screen.dart`：
 * 1. 顶部搜索栏，支持快速检索学校名、首字母、代码与适配器名；
 * 2. 快捷导入卡片（若存在已录制宏）；
 * 3. 分组列表（最近使用 ★、通用教务 通、A-Z 首字母排序）；
 * 4. 搜索空态提示与缺少学校反馈引导。
 */
@Composable
fun WarehouseCourseImportPage(
    allSchools: List<WarehouseSchoolEntry> = emptyList(),
    recentSchoolIds: List<String> = emptyList(),
    adapterMatches: Map<String, List<String>> = emptyMap(),
    hasQuickImportMacro: Boolean = false,
    quickImportMacroCount: Int = 0,
    /**
     * 当前搜索词（受控状态，由宿主保存）。
     *
     * 为什么不让页面自己 `remember`：点学校是**本条目内换页**（见 `WarehouseImportHosts`），
     * 列表页会整体离开组合，页面内的 remember 会清零，返回列表就丢了筛选条件；
     * 发布版是 Navigator 压栈（列表页留在栈里，`_searchQuery` 是 State 字段），返回后
     * 搜索词与筛选结果都还在。把状态提到宿主才能复现这个观感。
     */
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    onBack: () -> Unit = {},
    onSelectSchool: (WarehouseSchoolEntry) -> Unit = {},
    onQuickImportClick: () -> Unit = {},
    onFeedbackClick: () -> Unit = {},
    onCustomDebugClick: () -> Unit = {},
    onExecutionLogClick: () -> Unit = {},
    /**
     * 这一屏当前处于什么相位（8b 接真数据源时新增）。
     *
     * 默认 [WarehouseListPhase.Idle]：没接数据层的调用点传空列表 ⇒ 空态文案与改动前一致。
     * 宿主接了真仓库后必须传 Loading / Failed，否则「正在拉学校清单」会被说成「暂无可用学校」。
     */
    phase: WarehouseListPhase = WarehouseListPhase.Idle,
    onRetry: () -> Unit = {},
    /**
     * 列表滚动位置（由宿主持有）。
     *
     * 为什么不在页面内自己 `rememberLazyListState()`：点学校是**本条目内换页**
     * （见 `WarehouseImportHosts`），列表页会整体离开组合，页面内的滚动状态会清零；
     * 发布版是 Navigator 压栈（列表页留在栈里），返回后仍停在原位置。由宿主传进来
     * 才能在「学校列表 ↔ 适配器列表」这次换页里活下来。
     */
    listState: LazyListState = rememberLazyListState(),
) {
    var showMoreMenu by remember { mutableStateOf(false) }

    val filteredSchools = remember(allSchools, searchQuery, adapterMatches) {
        filterWarehouseSchools(allSchools, searchQuery, adapterMatches)
    }

    val beans = remember(filteredSchools, recentSchoolIds) {
        schoolsToBeans(filteredSchools, recentSchoolIds)
    }

    val sections = remember(beans) {
        schoolsToSections(beans)
    }

    val isSearching = searchQuery.trim().isNotEmpty()

    // Dart warehouse_course_import_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    // 骨架 / 顶栏 / 返回键走共享套件（R1），页面级滚动走 QingyuPageList（R2）：
    // 搜索栏、快捷导入、分组标题与学校卡片同处一个惰性列表。
    QingyuPageScaffold(
        title = WarehouseStrings.importMethodWarehouseTitle.text,
        onBack = onBack,
        actions = {
            IconButton(onClick = { showMoreMenu = !showMoreMenu }) {
                Icon(imageVector = MiuixIcons.More, contentDescription = WarehouseStrings.moreActionsTooltip.text)
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 8.dp),
            state = listState,
        ) {
            // 搜索输入栏：miuix 官方 `InputField`（`SearchBar.kt`）的**页内常驻**用法——
            // 自己就是一个 45dp 高、胶囊形、surfaceContainerHigh 底色的搜索框，左右自带
            // 放大镜与「清空」两个图标，不需要再套一层卡片、也不该自己拼 Row+TextField。
            // 参数按官方 demo（`SuperSearchBar.kt` 的 SearchBarFake / SearchBar）取：
            // 水平 12dp 外边距（= QingyuPageCardMargin，与下面学校卡同一条轴线）、底部 6dp。
            // `expanded` 恒 false：本页是「边输边滤」的常驻搜索框，不展开成全屏搜索页；
            // minSdk 33 不触发库内 API 26-27 的焦点补丁，隐藏 label 也不会让输入框变禁用。
            item(key = "search_bar") {
                InputField(
                    query = searchQuery,
                    onQueryChange = onSearchQueryChange,
                    // 输入即筛，没有独立提交动作（对齐发布版：回车只收键盘）。
                    onSearch = { },
                    expanded = false,
                    onExpandedChange = { },
                    label = WarehouseStrings.searchSchoolHint.text,
                    // 清空图标自己画一颗：官方默认那颗的无障碍文案是库里的英文 "Search Cleanup"，
                    // 发布版这里是「清空」（`clearSearchTooltip`）。写法照官方 demo
                    // `SuperSearchBar.kt:254-273`：44dp 触区 + start 8 / end 16 内边距、
                    // 无涟漪点击、输入非空才出现（与库内默认的显隐条件一致）。
                    trailingIcon = {
                        AnimatedVisibility(
                            visible = searchQuery.isNotEmpty(),
                            enter = fadeIn(),
                            exit = fadeOut(),
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Basic.SearchCleanup,
                                contentDescription = WarehouseStrings.clearSearchTooltip.text,
                                tint = MiuixTheme.colorScheme.onSurface,
                                modifier = Modifier
                                    .size(44.dp)
                                    .padding(start = 8.dp, end = 16.dp)
                                    .clickable(interactionSource = null, indication = null) {
                                        onSearchQueryChange("")
                                    },
                            )
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(top = 8.dp, bottom = 6.dp),
                )
            }

            // 快捷导入卡片
            //
            // 2026-11-10 用户拍板 B 方案：行本体交官方 `ArrowPreference`（与入口页四种导入方式
            // 同一个官方行），只在行首槽位放一块导入族的软底徽标。迁移期那版是自拼 Row +
            // 「emoji ⚡ + 主题色正圆」——emoji 不可跟主题着色、正圆是全站唯一一颗、
            // 主题蓝还和「教务系统导入」的教务绿打架（三处都不协调，用户实报「不好看」）。
            if (!isSearching && hasQuickImportMacro) {
                item(key = "quick_import") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                    ) {
                        ArrowPreference(
                            title = WarehouseStrings.quickImportAction.text,
                            summary = WarehouseStrings.quickImportRowSubtitle.text,
                            startAction = { QuickImportIconBadge() },
                            onClick = onQuickImportClick,
                        )
                    }
                }
            }

            // 搜索结果或按字母分组的学校列表
            if (sections.isEmpty()) {
                // 空状态：三种相位分开——拉取中用 D1 档 A2 转圈，失败/无结果走统一空态组件
                // （C18：`components/QingyuEmptyState.kt`，发布版 `HyperosEmptyState` 的逐字几何）。
                item(key = "empty") {
                    if (phase == WarehouseListPhase.Loading) {
                        QingyuLoadingCenter(fillPage = false)
                    } else {
                        QingyuEmptyState(
                            icon = MiuixIcons.Search,
                            title = if (phase == WarehouseListPhase.Failed) {
                                WarehouseStrings.warehouseRootLoadFailedTitle.text
                            } else if (isSearching) {
                                WarehouseStrings.noMatchingSchools.text
                            } else {
                                WarehouseStrings.noAvailableSchools.text
                            },
                            description = if (isSearching && phase != WarehouseListPhase.Failed) {
                                WarehouseStrings.searchSchoolSuggestion.text
                            } else {
                                null
                            },
                            action = when {
                                phase == WarehouseListPhase.Failed -> {
                                    {
                                        Button(
                                            onClick = onRetry,
                                            content = { Text(text = WarehouseStrings.reloadAction.text) },
                                            colors = ButtonDefaults.buttonColors(
                                                color = MiuixTheme.colorScheme.primary.copy(alpha = 0.12f),
                                                contentColor = MiuixTheme.colorScheme.primary,
                                            ),
                                        )
                                    }
                                }
                                isSearching -> {
                                    {
                                        Button(
                                            onClick = onFeedbackClick,
                                            content = { Text(text = WarehouseStrings.warehouseFeedbackMissingSchoolTitle.text) },
                                            colors = ButtonDefaults.buttonColors(
                                                color = MiuixTheme.colorScheme.secondary,
                                                contentColor = MiuixTheme.colorScheme.primary,
                                            ),
                                        )
                                    }
                                }
                                else -> null
                            },
                        )
                    }
                }
            } else {
                for (section in sections) {
                    item(key = "section_${section.tag}") {
                        // 分组标题走官方 SmallTitle（自带 28dp 左缘），与卡片正文同一条轴线。
                        QingyuSectionTitle(
                            text = when (section.tag) {
                                "★" -> WarehouseStrings.recentSchoolLabel.text
                                "通" -> "通用教务系统"
                                else -> section.tag
                            },
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }

                    items(section.items, key = { it.school.id }) { bean ->
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin)
                                .padding(top = 10.dp),
                            onClick = { onSelectSchool(bean.school) },
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = bean.school.name,
                                        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                                    )
                                    Spacer(modifier = Modifier.height(3.dp))
                                    val matched = adapterMatches[bean.school.id]
                                    val subtitle = if (!matched.isNullOrEmpty()) {
                                        WarehouseStrings.warehouseMatchedAdaptersLabel.filled("names", matched.joinToString("、"))
                                    } else if (bean.isRecent) {
                                        WarehouseStrings.recentSchoolLabel.text
                                    } else {
                                        WarehouseStrings.warehouseSchoolTapHint.text
                                    }
                                    Text(
                                        text = subtitle,
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                }
                                Icon(
                                    imageVector = MiuixIcons.ChevronForward,
                                    contentDescription = null,
                                    tint = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 快捷导入行的图标徽标（2026-11-10 用户拍板 B 方案）。
 *
 * 为什么是这个形态：
 * - **位置**：发布版这颗入口是顶栏一颗纯图标动作（`Icons.flash_on_rounded`，
 *   `warehouse_course_import_screen.dart:547-551`），页内并不存在这张卡；迁移期把它
 *   改成页内行是可用的增强，但当时画成了「emoji ⚡ + 主题色正圆」，全站只此一颗。
 * - **形状/材质**：36dp / 圆角 12 / 12% 淡底 + 18dp 同色矢量图标，与导入入口页四种方式、
 *   首页八宫格瓷贴同一族（emoji 是系统彩字，既不可跟主题着色，也会随系统字体换字形）。
 * - **配色**：教务绿 `QingyuIconColors.GREEN`（与入口页「教务系统导入」那一行的色槽呼应），
 *   不再是主题蓝——原来「黄 emoji 压在蓝底上」是撞色。
 * - **字形**：官方图标集没有闪电（`miuix-icons` 全表无 Flash/Bolt/Zap），
 *   回放语义取官方 `Play`。
 */
@Composable
private fun QuickImportIconBadge() {
    val accent = Color(QingyuIconColors.GREEN)
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(accent.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Play,
            contentDescription = null,
            tint = accent,
            modifier = Modifier.size(18.dp),
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄）：主题包 `QingyuPageTheme(isDark = …)`，
// 字号用 `textScale = …`（不用 `@Preview(fontScale = …)`），宽度 400dp 是本仓折行实测口径。
//
// 本页空列表有三种含义（拉取中 / 拉取失败 / 真没有）、搜索空结果还有另一句话，
// 四句都不同、按钮也不一样，所以逐档铺开；暗色与大字号以「学校列表」为基准。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用：七所学校，能同时撑出「★ 最近」「通 通用」「B / D / S」四类分组。 */
private fun previewImportSchools(): List<WarehouseSchoolEntry> = listOf(
    WarehouseSchoolEntry(
        id = "example-university",
        name = "示例大学",
        initial = "S",
        category = "本科教务",
        code = "10001",
        province = "示例省",
    ),
    WarehouseSchoolEntry(
        id = "north-industry",
        name = "北方工业大学",
        initial = "B",
        category = "本科教务",
        province = "示例省",
    ),
    WarehouseSchoolEntry(
        id = "donghai-vocational",
        name = "东海职业技术学院",
        initial = "D",
        category = "专科教务",
        province = "示例省",
    ),
    WarehouseSchoolEntry(
        id = "generic-chaoxing",
        name = "通用教务系统（超星）",
        initial = "T",
        category = "通用",
    ),
    WarehouseSchoolEntry(
        id = "generic-zhengfang",
        name = "通用教务系统（正方）",
        initial = "T",
        category = "通用",
    ),
)

/** 一档预览的公共身体：学校数据 + 搜索词 + 相位 + 外观档位。 */
@Composable
private fun PreviewWarehouseCourseImportPage(
    allSchools: List<WarehouseSchoolEntry> = previewImportSchools(),
    searchQuery: String = "",
    phase: WarehouseListPhase = WarehouseListPhase.Idle,
    hasQuickImportMacro: Boolean = true,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        WarehouseCourseImportPage(
            allSchools = allSchools,
            recentSchoolIds = listOf("example-university"),
            adapterMatches = mapOf(
                "north-industry" to listOf("本科教务系统", "研究生教务"),
            ),
            hasQuickImportMacro = hasQuickImportMacro,
            quickImportMacroCount = 1,
            searchQuery = searchQuery,
            onSearchQueryChange = { _ -> },
            onBack = {},
            onSelectSchool = { _ -> },
            onQuickImportClick = {},
            onFeedbackClick = {},
            onCustomDebugClick = {},
            onExecutionLogClick = {},
            phase = phase,
            onRetry = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 学校列表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewList() {
    PreviewWarehouseCourseImportPage()
}

@Suppress("unused")
@Preview(name = "2 搜索无结果", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewNoMatch() {
    PreviewWarehouseCourseImportPage(allSchools = previewImportSchools(), searchQuery = "不存在的学校")
}

@Suppress("unused")
@Preview(name = "3 空·加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewLoading() {
    PreviewWarehouseCourseImportPage(
        allSchools = emptyList(),
        phase = WarehouseListPhase.Loading,
        hasQuickImportMacro = false,
    )
}

@Suppress("unused")
@Preview(name = "4 空·拉取失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewFailed() {
    PreviewWarehouseCourseImportPage(
        allSchools = emptyList(),
        phase = WarehouseListPhase.Failed,
        hasQuickImportMacro = false,
    )
}

@Suppress("unused")
@Preview(name = "5 空·确实没有学校", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewEmpty() {
    PreviewWarehouseCourseImportPage(allSchools = emptyList(), hasQuickImportMacro = false)
}

@Suppress("unused")
@Preview(name = "6 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewDark() {
    PreviewWarehouseCourseImportPage(dark = true)
}

@Suppress("unused")
@Preview(name = "7 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun WarehouseCourseImportPagePreviewLargeText() {
    PreviewWarehouseCourseImportPage(textScale = 1.3f)
}
