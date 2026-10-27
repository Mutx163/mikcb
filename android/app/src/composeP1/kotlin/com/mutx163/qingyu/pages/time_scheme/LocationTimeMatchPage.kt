package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference

/**
 * 地点作息匹配页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/location_time_match_screen.dart` 的**列表页部分**（:29-160）：
 *
 * ```
 * 分区标题「地点作息匹配」
 * 空态：一行「新建地点组」HyperosActionTile
 * 有规则：每张卡是一组地点关键词 → 一套时间模板
 *         卡内第一行是开关行（组名 + 副标题 + 开关），下面还有编辑/删除行
 * 分区说明（subtitle）
 * 尾部（有规则时）：「重新匹配当前课表」一行
 * ```
 *
 * ## 试匹配输入框
 *
 * Dart 在编辑页里有「试匹配地点」输入框（:495+）。这一页的列表页也放了一份同名入口：
 * 输入地点 → 当场显示「将匹配：组 · 模板，关键词 X」，命不中就给「未命中」那句话。
 * 判定本身在 [LocationTimeMatchModel.previewText]（走 Phase 2 已迁好的匹配逻辑）。
 *
 * ## 已知差异（认领文件也记了一份）
 *
 * 编辑页（`_LocationTimeGroupEditorScreen`，:367-1131，约 760 行）与两个对话框
 * （关键词录入 / 删除确认）本批**只落模型层校验与文案**，不落页面：那部分的交互是
 * 「关键词增删 + 楼栋聚类挑选 + 三档匹配方式」，体量与列表页相当，拆成下一批更稳。
 *
 * @param model 已算好的页面模型
 * @param onBack 返回
 * @param onCreateGroup 新建地点组
 * @param onEditGroup 编辑某组
 * @param onDeleteGroup 删除某组
 * @param onToggleGroup 开关某组
 * @param onApplyActive 「重新匹配当前课表」
 */
@Composable
fun LocationTimeMatchPage(
    model: LocationTimeMatchModel,
    onBack: () -> Unit,
    onCreateGroup: () -> Unit,
    onEditGroup: (String) -> Unit,
    onDeleteGroup: (String) -> Unit,
    onToggleGroup: (groupId: String, enabled: Boolean) -> Unit,
    onApplyActive: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var previewInput by remember { mutableStateOf("") }

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = model.title,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = model.title,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    actions = {
                        IconButton(onClick = onCreateGroup) {
                            Icon(
                                imageVector = MiuixIcons.Add,
                                contentDescription = model.createGroupLabel,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            // 官方页面骨架：LazyColumn + 滚动条 + 末端触感（见 QingyuPageList 注释）
            QingyuPageList(
                innerPadding = innerPadding,
                horizontalPadding = QingyuPageCardMargin,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // ── 分区标题 ──
                        QingyuSectionTitle(text = LocationTimeMatchStrings.entryTitle.zh)

                        if (model.isEmpty) {
                            // Dart：空态是一行「新建地点组」ActionTile，不是自造空态文案
                            // 只包 Preference：不传 insideMargin（Preference 自带 16dp）
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                                ArrowPreference(
                                    title = model.createGroupLabel,
                                    summary = null,
                                    onClick = onCreateGroup,
                                )
                            }
                        } else {
                            // ── 规则卡 ──
                            for ((index, card) in model.cards().withIndex()) {
                                GroupCardView(
                                    card = card,
                                    onToggle = { enabled -> onToggleGroup(card.groupId, enabled) },
                                    onEdit = { onEditGroup(card.groupId) },
                                    onDelete = { onDeleteGroup(card.groupId) },
                                )
                                if (index < model.cards().lastIndex) {
                                    Spacer(Modifier.height(8.dp))
                                }
                            }
                        }

                        // ── 试匹配 ──
                        // 包自绘内容（TextField + 结果文本）：用官方 ContentInsideMargin(16dp)
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = QingyuCardDefaults.ContentInsideMargin,
                        ) {
                            Column {
                                TextField(
                                    value = previewInput,
                                    onValueChange = { previewInput = it },
                                    label = model.previewLabel,
                                    singleLine = true,
                                )
                                Spacer(Modifier.height(6.dp))
                                val preview = model.previewText(previewInput)
                                Text(
                                    text = preview ?: model.previewHint,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                        }

                        // ── 分区说明 ──
                        Text(
                            text = model.footerNote,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
                        )

                        // ── 尾部：重新匹配当前课表（有规则时才出现，Dart 同口径） ──
                        if (!model.isEmpty) {
                            // 只包 Preference：不传 insideMargin
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
                                ArrowPreference(
                                    title = model.applyActiveLabel,
                                    summary = null,
                                    onClick = onApplyActive,
                                )
                            }
                        }

                    }
                }
            }
        }
    }
}

/** 一张规则卡：开关行 + 编辑/删除行（Dart `HyperosControlCard(edgeToEdge: true)`）。 */
@Composable
private fun GroupCardView(
    card: LocationTimeMatchModel.GroupCard,
    onToggle: (Boolean) -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    // 混装 SwitchPreference 与自绘操作行：不传 insideMargin（各自带 16dp 横向）
    QingyuCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            // 第一行：组名 + 副标题 + 开关
            SwitchPreference(
                checked = card.enabled,
                onCheckedChange = onToggle,
                title = card.title,
                summary = card.subtitle,
            )
            // 下面两行：编辑 / 删除（Dart 卡内是「编辑地点组」与删除动作两行）
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = LocationTimeMatchStrings.editGroup.zh,
                    style = MiuixTheme.textStyles.body2,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.primary(dark = dark)),
                    modifier = Modifier
                        .weight(1f)
                        .padding(vertical = 2.dp),
                )
                Text(
                    text = LocationTimeMatchStrings.deleteTitle.zh,
                    style = MiuixTheme.textStyles.body2,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.error(dark)),
                )
            }
        }
    }
}
