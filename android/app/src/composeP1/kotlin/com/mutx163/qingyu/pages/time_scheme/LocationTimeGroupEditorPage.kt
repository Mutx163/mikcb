package com.mutx163.qingyu.pages.time_scheme

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.RadioButtonPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 时间模板下拉/选择项（宿主把模板列表转成这个即可，避免页面依赖模板模型层）。 */
data class SchemeOption(val id: String, val name: String)

/**
 * 地点作息匹配 · 编辑页渲染层（补齐 Dart `_LocationTimeGroupEditorScreen`，:367-1131）。
 *
 * ## 覆盖的表单
 *
 * 组名 → 绑定时间模板 → 启用开关 → 地点关键词（已选 chip + 增删）→ 从课表识别的楼栋建议
 * （一键添加）→ 保存。校验顺序在 [LocationTimeGroupEditorValidation]（照 Dart `_save`），
 * 楼栋聚类在 [LocationBuildingClusterLogic]（照 Dart 逐行移植）。
 *
 * ## 与 Dart 的两处有意简化（认领文件也记了一份，别当漏迁）
 *
 * 1. **不用模态对话框 / 底部选择 sheet**：Dart 的关键词录入、`showCourseFieldPickerSheet`
 *    是 Hyperos 对话框/sheet。Compose 侧当前没有等价的通用弹层组件，这里改成就地内联
 *    （文本框 + 模式三选行 + 「添加」行），功能等价、少一次跨组件契约。
 * 2. **时间模板用可点选列表行代替 `HyperosSelectTile` 下拉**：同样为避免依赖未迁的下拉件。
 *
 * 其余交互（增删关键词、冲突校验、楼栋一键添加、保存回写）与 Dart 一致。
 */
@Composable
fun LocationTimeGroupEditorPage(
    existing: LocationTimeGroup?,
    schemes: List<SchemeOption>,
    allGroups: List<LocationTimeGroup>,
    availableLocations: List<String>,
    onBack: () -> Unit,
    onSave: (name: String, timeSchemeId: String, enabled: Boolean, keywords: List<LocationKeyword>) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val model = remember(allGroups) { LocationTimeMatchModel(groups = allGroups) }
    val editingGroupId = existing?.id
    val title = if (existing == null) LocationTimeMatchStrings.createGroup.text else LocationTimeMatchStrings.editGroup.text

    // 校验错误一律 toast，不放列表顶部横幅——底部「保存」与中段「添加关键词」都在滚动
    // 深处，横幅渲染在屏幕外时用户看到的是「点了没反应」。Dart 侧同一个入口全部走
    // `showAppToast`（`location_time_match_screen.dart:1036-1069`、`:521-535`）。
    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    var name by remember { mutableStateOf(existing?.name ?: "") }
    var timeSchemeId by remember {
        mutableStateOf(existing?.timeSchemeId?.takeIf { it.isNotEmpty() } ?: schemes.firstOrNull()?.id ?: "")
    }
    var enabled by remember { mutableStateOf(existing?.enabled ?: true) }
    var keywords by remember { mutableStateOf(existing?.keywords ?: emptyList<LocationKeyword>()) }
    var newPattern by remember { mutableStateOf("") }
    var newMode by remember { mutableStateOf(LocationKeywordMatchMode.PREFIX) }

    fun currentKeywords(): List<LocationKeyword> =
        keywords.map { LocationKeyword(it.pattern.trim(), it.mode) }.filter { it.pattern.isNotEmpty() }

    fun trySave() {
        val err = LocationTimeGroupEditorValidation.saveError(
            model = model,
            name = name,
            timeSchemeId = timeSchemeId,
            keywords = currentKeywords(),
            editingGroupId = editingGroupId,
        )
        if (err != null) {
            toast(err)
        } else {
            onSave(name.trim(), timeSchemeId, enabled, currentKeywords())
        }
    }

    /** 加一条关键词；@return 是否真的加进去了（调用方据此决定要不要清空输入框）。 */
    fun addKeyword(pattern: String, mode: LocationKeywordMatchMode): Boolean {
        val trimmed = pattern.trim()
        if (trimmed.isEmpty()) return false
        if (keywords.any { it.pattern.trim().equals(trimmed, ignoreCase = true) }) {
            toast(LocationTimeMatchStrings.keywordAlreadyExists.text)
            return false
        }
        val owner = model.keywordOwnerHint(trimmed, editingGroupId)
        if (owner != null) {
            toast(owner)
            return false
        }
        keywords = keywords + LocationKeyword(trimmed, mode)
        return true
    }

    // 楼栋建议：当前已有关键词 + 别的组关键词都算「已覆盖」
    val coveredKeywords = keywords + LocationTimeMatchLogicKeywordsFromOthers(allGroups, editingGroupId)
    val uncovered = remember(availableLocations, coveredKeywords) {
        LocationBuildingClusterLogic.uncoveredClusters(availableLocations, coveredKeywords)
    }

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃 + actions 槽；大标题可折叠。
    QingyuPageScaffold(
        title = title,
        onBack = onBack,
        actions = {
            // Dart `:1271-1277` 的 FHeaderAction：永远可点，点了直接提交流程（校验在 trySave）。
            TextButton(
                text = LocationTimeMatchStrings.saveAction.text,
                onClick = { trySave() },
                colors = ButtonDefaults.textButtonColorsPrimary(),
            )
        },
    ) {
        // 官方页面骨架 + imePadding：本页两处输入框（组名 / 关键词），键盘不遮输入。
        QingyuPageList(
            modifier = Modifier.imePadding(),
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
                item {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // 组名
                        QingyuSectionTitle(text = LocationTimeMatchStrings.groupNameLabel.text)
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = QingyuCardDefaults.ContentInsideMargin,
                        ) {
                            TextField(
                                value = name,
                                onValueChange = { name = it },
                                label = LocationTimeMatchStrings.groupNameHint.text,
                                singleLine = true,
                            )
                        }

                        // 绑定时间模板
                        QingyuSectionTitle(text = LocationTimeMatchStrings.boundSchemeLabel.text)
                        if (schemes.isEmpty()) {
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                                ArrowPreference(
                                    title = LocationTimeMatchStrings.needTimeScheme.text,
                                    summary = null,
                                    onClick = { toast(LocationTimeMatchStrings.needTimeScheme.text) },
                                )
                            }
                        } else {
                            // 同名模板追加 id 前 8 位（Dart `_timeSchemeSelectLabel`），否则两行
                            // 逐字相同的「默认作息」让用户选不出自己绑的是哪一套。
                            // 纯字符串装配（模板只有几套），不必 memo。
                            val schemeLabels = LocationTimeMatchModel.schemeSelectLabels(
                                schemes.map { it.id to it.name },
                            )
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                                Column {
                                    schemes.forEachIndexed { index, scheme ->
                                        // 单选用官方 RadioButtonPreference，不再用 ●/○ 前缀拼箭头行。
                                        RadioButtonPreference(
                                            title = schemeLabels[index],
                                            selected = scheme.id == timeSchemeId,
                                            onClick = { timeSchemeId = scheme.id },
                                        )
                                    }
                                }
                            }
                        }

                        // 启用开关
                        QingyuCard(modifier = Modifier.fillMaxWidth()) {
                            SwitchPreference(
                                checked = enabled,
                                onCheckedChange = { enabled = it },
                                title = LocationTimeMatchStrings.enabledLabel.text,
                                summary = null,
                            )
                        }

                        // 地点关键词
                        QingyuSectionTitle(text = LocationTimeMatchStrings.keywordsSection.text)
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = QingyuCardDefaults.ContentInsideMargin,
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(
                                    text = LocationTimeMatchStrings.selectedKeywords.text,
                                    style = MiuixTheme.textStyles.body2,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                )
                                if (keywords.isEmpty()) {
                                    Text(
                                        text = LocationTimeMatchStrings.noSelectedKeywords.text,
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                    )
                                } else {
                                    keywords.forEachIndexed { index, keyword ->
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = "${keyword.pattern} · ${model.modeLabel(keyword.mode)}",
                                                style = MiuixTheme.textStyles.footnote1,
                                                color = Color(QingyuTheme.primaryText(dark)),
                                                modifier = Modifier.weight(1f),
                                            )
                                            Text(
                                                text = "✕",
                                                style = MiuixTheme.textStyles.footnote1,
                                                color = Color(QingyuTheme.secondaryText(dark)),
                                                modifier = Modifier
                                                    .clickable { keywords = keywords.filterIndexed { i, _ -> i != index } }
                                                    .padding(horizontal = 8.dp, vertical = 2.dp),
                                            )
                                        }
                                    }
                                }
                                Spacer(Modifier.height(2.dp))
                                TextField(
                                    value = newPattern,
                                    onValueChange = { newPattern = it },
                                    label = LocationTimeMatchStrings.keywordHint.text,
                                    singleLine = true,
                                )
                                // 匹配模式三选一
                                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                    for (mode in LocationKeywordMatchMode.entries) {
                                        val selected = mode == newMode
                                        Text(
                                            text = model.modeLabel(mode),
                                            style = MiuixTheme.textStyles.footnote1.shiftWeight(
                                                if (selected) QingyuWeightDelta.BOLD else 0,
                                            ),
                                            color = Color(if (selected) QingyuTheme.primary(dark = dark) else QingyuTheme.secondaryText(dark)),
                                            modifier = Modifier.clickable { newMode = mode },
                                        )
                                    }
                                }
                                ArrowPreference(
                                    title = LocationTimeMatchStrings.addKeyword.text,
                                    summary = null,
                                    onClick = {
                                        // 加成功才清空输入框；被拒时保留原文，用户能就地改。
                                        if (addKeyword(newPattern, newMode)) newPattern = ""
                                    },
                                )
                            }
                        }
                        Text(
                            text = LocationTimeMatchStrings.keywordsHelp.text,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(horizontal = 4.dp),
                        )

                        // 楼栋建议
                        QingyuSectionTitle(text = LocationTimeMatchStrings.buildingSuggestions.text)
                        if (uncovered.isEmpty()) {
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                                ArrowPreference(
                                    title = LocationTimeMatchStrings.noBuildingSuggestions.text,
                                    summary = null,
                                    onClick = null,
                                    enabled = false,
                                )
                            }
                        } else {
                            uncovered.forEach { cluster ->
                                ClusterCard(
                                    cluster = cluster,
                                    onAdd = { addKeyword(cluster.suggestedKeyword.pattern, cluster.suggestedKeyword.mode) },
                                )
                            }
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                                ArrowPreference(
                                    title = LocationTimeMatchStrings.addAllBuildings.text,
                                    summary = null,
                                    onClick = {
                                        var added = 0
                                        for (cluster in uncovered) {
                                            val p = cluster.suggestedKeyword.pattern.trim()
                                            if (p.isEmpty()) continue
                                            if (keywords.any { it.pattern.trim().equals(p, ignoreCase = true) }) continue
                                            if (model.keywordOwnerHint(p, editingGroupId) != null) continue
                                            keywords = keywords + cluster.suggestedKeyword
                                            added++
                                        }
                                        if (added == 0) toast(LocationTimeMatchStrings.keywordAlreadyExists.text)
                                    },
                                )
                            }
                        }

                        // 保存（底部）
                        QingyuCard(modifier = Modifier.fillMaxWidth()) {
                            ArrowPreference(
                                title = LocationTimeMatchStrings.saveAction.text,
                                summary = null,
                                onClick = { trySave() },
                            )
                        }
                    }
                }
        }
    }
}

@Composable
private fun ClusterCard(cluster: BuildingCluster, onAdd: () -> Unit) {
    val dark = isSystemInDarkTheme()
    val samples = cluster.sampleLocations.take(3).joinToString("、")
    val detailParts = buildList {
        add(LocationTimeMatchStrings.buildingRoomCount.filled("count", cluster.locationCount.toString()))
        if (samples.isNotEmpty()) add(samples)
        if (cluster.gateTags.isNotEmpty()) add(LocationTimeMatchStrings.buildingGateTags.filled("tags", cluster.gateTags.joinToString("、")))
    }
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = QingyuCardDefaults.ContentInsideMargin) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                text = "${cluster.buildingKey} · ${cluster.displayName}",
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = detailParts.joinToString(" · "),
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = LocationTimeMatchStrings.addBuilding.text,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primary(dark = dark)),
                modifier = Modifier
                    .clickable { onAdd() }
                    .padding(vertical = 4.dp),
            )
        }
    }
}

/** 除 [excludingGroupId] 外各组关键词（薄封装，避免页面直接依赖 core 的伴生方法签名）。 */
private fun LocationTimeMatchLogicKeywordsFromOthers(
    groups: List<LocationTimeGroup>,
    excludingGroupId: String?,
): List<LocationKeyword> {
    val result = ArrayList<LocationKeyword>()
    for (group in groups) {
        if (excludingGroupId != null && group.id == excludingGroupId) continue
        result.addAll(group.keywords)
    }
    return result
}
