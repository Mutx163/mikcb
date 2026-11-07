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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.SearchCleanup
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.More
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
            if (!isSearching && hasQuickImportMacro) {
                item(key = "quick_import") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin, vertical = 4.dp),
                        onClick = onQuickImportClick,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(MiuixTheme.colorScheme.primary.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "⚡",
                                    style = MiuixTheme.textStyles.title4,
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = WarehouseStrings.quickImportAction.text,
                                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = WarehouseStrings.selectQuickImportTitle.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
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

            // 搜索结果或按字母分组的学校列表
            if (sections.isEmpty()) {
                // 空状态：三种相位说三句不同的话（拉取中 / 拉取失败 / 真没有）
                item(key = "empty") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            if (phase == WarehouseListPhase.Loading) {
                                CircularProgressIndicator()
                            } else {
                                Text(
                                    text = when {
                                        phase == WarehouseListPhase.Failed ->
                                            WarehouseStrings.warehouseRootLoadFailedTitle.text

                                        isSearching -> WarehouseStrings.noMatchingSchools.text
                                        else -> WarehouseStrings.noAvailableSchools.text
                                    },
                                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                )
                                if (phase == WarehouseListPhase.Failed) {
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Button(
                                        onClick = onRetry,
                                        content = { Text(text = WarehouseStrings.reloadAction.text) },
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.primary.copy(alpha = 0.12f),
                                            contentColor = MiuixTheme.colorScheme.primary,
                                        ),
                                    )
                                } else if (isSearching) {
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(
                                        text = WarehouseStrings.searchSchoolSuggestion.text,
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                    )
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Button(
                                        onClick = onFeedbackClick,
                                        content = { Text(text = WarehouseStrings.warehouseFeedbackMissingSchoolTitle.text) },
                                        colors = ButtonDefaults.buttonColors(
                                            color = MiuixTheme.colorScheme.surfaceVariant,
                                            contentColor = MiuixTheme.colorScheme.primary,
                                        ),
                                    )
                                }
                            }
                        }
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
