package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
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

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃 + actions 槽；大标题可折叠。
    QingyuPageScaffold(
        title = model.title,
        onBack = onBack,
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
        actions = {
            QingyuGlassIconButton(
                onClick = onCreateGroup,
                contentDescription = model.createGroupLabel,
                icon = MiuixIcons.Add,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        },
    ) {
        // 官方页面骨架：LazyColumn + 滚动条 + 末端触感（见 QingyuPageList 注释）
        // 试匹配输入框在列表里：imePadding 把列表抬到键盘之上。
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
                        // ── 分区标题 ──
                        QingyuSectionTitle(text = LocationTimeMatchStrings.entryTitle.text)

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
            // 下面两行：编辑 / 删除（Dart `_buildGroupCard` 用 `editAction` / `deleteAction`
            // 两个通用动作词，不是分区标题 `editGroup` / `deleteTitle`；且都要能点）。
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = LocationTimeMatchStrings.editAction.text,
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.primary(dark = dark)),
                    modifier = Modifier
                        .weight(1f)
                        .clickable(onClick = onEdit)
                        .padding(vertical = 2.dp),
                )
                Text(
                    text = LocationTimeMatchStrings.deleteAction.text,
                    style = MiuixTheme.textStyles.body2,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.error(dark)),
                    modifier = Modifier
                        .clickable(onClick = onDelete)
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                )
            }
        }
    }
}

// ── Android Studio 预览（@Preview）────────────────────────────────────────────
//
// 与 `ContributorsPage` 同一套口径：一个 `Preview<页面>` 承担「示例数据 + 外观档位」，
// 下面每个 `@Preview` 只选一档。预览不接宿主：回调一律空实现，数据全是中文实义值。
//
// 地点组用 `LocationTimeGroup.fromJson` 装配（写全限定名是刻意的：预览段只允许新增
// `Preview` / `QingyuPageTheme` 两个 import，本文件原本没引 core，不为预览再补一条）。

/** 预览用的模板名表（id → 名字）：故意漏掉 `scheme-deleted`，让「未知时间模板」兜底露出来。 */
private fun previewSchemeNames(): Map<String, String> = mapOf(
    "scheme-winter" to "秋冬作息",
    "scheme-spring" to "春夏作息",
)

/** 预览用一个地点组（[keywords] 里每项是「关键词 to 匹配方式」）。 */
private fun previewGroup(
    id: String,
    name: String,
    schemeId: String,
    enabled: Boolean = true,
    keywords: List<Pair<String, String>> = emptyList(),
): com.mutx163.qingyu.core.LocationTimeGroup =
    com.mutx163.qingyu.core.LocationTimeGroup.fromJson(
        mapOf(
            "id" to id,
            "name" to name,
            "timeSchemeId" to schemeId,
            "enabled" to enabled,
            "keywords" to keywords.map { (pattern, mode) ->
                mapOf("pattern" to pattern, "mode" to mode)
            },
        ),
    )

/** 预览用的地点组：有关键词的、只绑模板的、停用且模板已删的，三种卡面各来一张。 */
private fun previewLocationGroups(): List<com.mutx163.qingyu.core.LocationTimeGroup> = listOf(
    previewGroup(
        id = "group-arts",
        name = "艺术楼专业课",
        schemeId = "scheme-winter",
        keywords = listOf("艺术楼" to "prefix", "琴房" to "contains"),
    ),
    previewGroup(
        id = "group-lab",
        name = "实验楼晚课",
        schemeId = "scheme-spring",
        keywords = listOf("实验楼" to "prefix"),
    ),
    previewGroup(
        id = "group-stadium",
        name = "体育馆早操",
        schemeId = "scheme-deleted",
        enabled = false,
    ),
)

/** 一档预览的公共身体：模型 + 外观档位。 */
@Composable
private fun PreviewLocationTimeMatchPage(
    model: LocationTimeMatchModel,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        LocationTimeMatchPage(
            model = model,
            onBack = {},
            onCreateGroup = {},
            onEditGroup = {},
            onDeleteGroup = {},
            onToggleGroup = { _, _ -> },
            onApplyActive = {},
        )
    }
}

/** 预览用的模型：三组地点规则 + 模板名表。 */
private fun previewMatchModel(): LocationTimeMatchModel = LocationTimeMatchModel(
    groups = previewLocationGroups(),
    schemeNames = previewSchemeNames(),
)

@Suppress("unused")
@Preview(name = "1 有规则", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LocationTimeMatchPagePreviewGroups() {
    PreviewLocationTimeMatchPage(model = previewMatchModel())
}

@Suppress("unused")
@Preview(name = "2 空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LocationTimeMatchPagePreviewEmpty() {
    PreviewLocationTimeMatchPage(model = LocationTimeMatchModel())
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LocationTimeMatchPagePreviewDark() {
    PreviewLocationTimeMatchPage(model = previewMatchModel(), dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LocationTimeMatchPagePreviewLargeText() {
    PreviewLocationTimeMatchPage(model = previewMatchModel(), textScale = 1.3f)
}
