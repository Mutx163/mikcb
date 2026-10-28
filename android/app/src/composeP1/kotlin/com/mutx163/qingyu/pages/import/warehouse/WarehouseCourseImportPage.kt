package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Search
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
    onBack: () -> Unit = {},
    onSelectSchool: (WarehouseSchoolEntry) -> Unit = {},
    onQuickImportClick: () -> Unit = {},
    onFeedbackClick: () -> Unit = {},
    onCustomDebugClick: () -> Unit = {},
    onExecutionLogClick: () -> Unit = {},
) {
    var searchQuery by remember { mutableStateOf("") }
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
        title = WarehouseStrings.importMethodWarehouseTitle.zh,
        onBack = onBack,
        actions = {
            IconButton(onClick = { showMoreMenu = !showMoreMenu }) {
                Icon(imageVector = MiuixIcons.More, contentDescription = WarehouseStrings.moreActionsTooltip.zh)
            }
        },
    ) { innerPadding, scrollBehavior ->
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 8.dp),
        ) {
            // 搜索输入栏
            item(key = "search_bar") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 8.dp),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = MiuixIcons.Search,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        TextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            modifier = Modifier.weight(1f),
                            label = WarehouseStrings.searchSchoolHint.zh,
                            useLabelAsPlaceholder = true,
                            singleLine = true,
                        )
                        if (isSearching) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(
                                    imageVector = MiuixIcons.Close,
                                    contentDescription = WarehouseStrings.clearSearchTooltip.zh,
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                    }
                }
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
                                    text = WarehouseStrings.quickImportAction.zh,
                                    style = MiuixTheme.textStyles.body1,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = WarehouseStrings.selectQuickImportTitle.zh,
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
                // 空状态
                item(key = "empty") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = if (isSearching) WarehouseStrings.noMatchingSchools.zh else WarehouseStrings.noAvailableSchools.zh,
                                style = MiuixTheme.textStyles.body1,
                                fontWeight = FontWeight.Medium,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                            )
                            if (isSearching) {
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = WarehouseStrings.searchSchoolSuggestion.zh,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                )
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(
                                    onClick = onFeedbackClick,
                                    content = { Text(text = WarehouseStrings.warehouseFeedbackMissingSchoolTitle.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.primary,
                                    ),
                                )
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
                                "★" -> WarehouseStrings.recentSchoolLabel.zh
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
                                        style = MiuixTheme.textStyles.body1,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                    Spacer(modifier = Modifier.height(3.dp))
                                    val matched = adapterMatches[bean.school.id]
                                    val subtitle = if (!matched.isNullOrEmpty()) {
                                        WarehouseStrings.warehouseMatchedAdaptersLabel.filled("adapters", matched.joinToString("、"))
                                    } else if (bean.isRecent) {
                                        WarehouseStrings.recentSchoolLabel.zh
                                    } else {
                                        WarehouseStrings.warehouseSchoolTapHint.zh
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
