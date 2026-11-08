package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
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
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Email
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Home
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Link
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Messages
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Remove
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.icon.extended.Sort
import top.yukonga.miuix.kmp.icon.extended.Stopwatch
import top.yukonga.miuix.kmp.icon.extended.Store
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.icon.extended.Theme
import top.yukonga.miuix.kmp.icon.extended.Update
import top.yukonga.miuix.kmp.icon.extended.UploadCloud
import top.yukonga.miuix.kmp.icon.extended.Weeks
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlin.math.roundToInt

/**
 * 两个「按钮编辑器」页面（玻璃坞底栏 / 八宫格菜单）的 Compose 渲染层。
 *
 * 对应 Flutter：
 * - 底栏按钮编辑器：`lib/screens/settings/settings_glass_dock_editor.dart`（348 行）
 * - 八宫格菜单编辑器：`lib/screens/settings/settings_home_menu_editor.dart`（328 行）
 *
 * ## 版式（两页共用一个内部骨架 [EditorPage]）
 *
 * 先用共享套件搭好官方骨架，再按 Dart 的层级逐段摆放：
 *
 * ```
 * QingyuPageScaffold(title, onBack)              // 顶栏 + 返回键 + 可折叠大标题
 *   QingyuPageList(horizontalPadding = 12dp)     // 惰性列表 + 滚动三件套 + 滚动条
 *     item  预览卡            EditorPreviewCard  // 一排「圆角图标格 + 下方小字」
 *     item  分组标题           QingyuSectionTitle
 *     item  「已启用」可拖动列表 EnabledReorderList
 *     item  整宽提示句         EditorDescription
 *     item  各分类标题 + 候选行 CandidateCard / EditorDescription
 *     item  「恢复默认排列」   ResetCard
 * ```
 *
 * 两页差异只在候选分组：底栏多一个「视图切换」伪分组（日/周是动作不是页面），
 * 八宫格多一个「钉住的 `settings` 不可移除」规则，其余骨架完全一致，因此收口到 [EditorPage]。
 *
 * ## 拖动排序的实现方式（关键）
 *
 * 「已启用」是短列表（底栏 ≤5、八宫格 ≤8），所以**不用惰性列表**，直接用普通 [Column]，
 * 每行固定高 [DockSlotRowHeight]（56dp）+ [DockSlotRowGap]（8dp）间距，行距
 * `pitch = 64dp`。行首手柄上挂
 * [detectDragGesturesAfterLongPress]（长按后拖动，避免与页面纵向滚动抢手势）：
 *
 * 1. `onDragStart` 记录当前被拖的 index，并把该行标成 `isDragging`；
 * 2. `onDrag` 把每帧 `dragAmount.y` 累加到协程内的局部变量 `acc`（不依赖旧值，避免
 *    在 pointerInput 协程里读到过期的 composition 值），同时把 `acc` 回传给父层驱动
 *    `graphicsLayer.translationY` 做拖动反馈（轻微放大 1.02）；
 * 3. `onDragEnd` 用 `to = (index + round(acc / pitch)).coerceIn(0, itemCount - 1)` 算出目标位，
 *    `to != index` 时调 `onMove(from, to)`；然后复位拖动状态。
 *
 * 索引语义与 Dart 一致：Dart 用 `onReorderItem`（框架已校正下移时的插入位），
 * 所以 `onMove` 的 `to` 就是最终下标，宿主按此直接 `remove + insert`，**不要再减一**。
 *
 * ## 图标说明（近似）
 *
 * 目录条目模型（[DockCatalogEntry] / [SettingsHomeNavigationPage.CatalogEntry]）没有 icon 字段，
 * 本文件用 [dockGlyph] 建了一张 `id -> ImageVector` 的**近似**映射（语义接近的 Miuix 图标），
 * 未知 id 回退通用图标 [MiuixIcons.Info]。**精确图标需要后续补一张完整的 id→icon 表**，
 * 本版只保证结构、行样式、交互一致，不保证图标逐项对齐 Flutter。
 *
 * ## 契约
 *
 * 渲染层只画 [state] 里的 `enabledIds`，不再做种子清洗（清洗是宿主/模型层
 * `sanitize`/`sanitizeSeed` 的职责），以保证 `onMove(from, to)` 的索引与宿主持有的列表一致。
 */

/** 「已启用」单行固定高度（Dart `_DockSlotRow` / `_GridSlotRow` 的 56dp）。 */
private val DockSlotRowHeight: Dp = 56.dp

/** 「已启用」相邻行间距（Dart `EdgeInsets.only(bottom: 8)`）。 */
private val DockSlotRowGap: Dp = 8.dp

/** 一条候选入口：id + 已解析标题 + 近似图标。 */
private data class EditorCandidate(
    val id: String,
    val label: String,
    val glyph: ImageVector,
)

/** 一个候选分组：分组标题 + 该组下尚未启用的候选。 */
private data class EditorSection(
    val label: String,
    val candidates: List<EditorCandidate>,
)

// ============================================================ 公共入口

/**
 * 玻璃坞底栏按钮编辑器。
 *
 * @param state 当前草稿（`enabledIds` 由宿主清洗后传入，渲染层按原序绘制）
 * @param onAdd 添加一个入口（参数是入口 id）
 * @param onRemove 移除一个入口（参数是入口 id）
 * @param onMove 拖动排序完成时回调（`from`/`to` 为最终下标）
 * @param onReset 恢复默认排列
 */
@Composable
fun GlassDockEditorScreen(
    state: GlassDockEditorState,
    onBack: () -> Unit,
    onAdd: (String) -> Unit,
    onRemove: (String) -> Unit,
    onMove: (from: Int, to: Int) -> Unit,
    onReset: () -> Unit,
) {
    val enabled = state.enabledIds
    val labelOf: (String) -> String = { SettingsGlassDockEditorPage.labelOf(it).text }
    val glyphOf: (String) -> ImageVector = { dockGlyph(it) }

    val sections = buildList {
        // 视图切换伪分组：日/周是动作而非页面，排在目录分类之前；两个都启用时整组消失。
        val viewSwitch = SettingsGlassDockEditorPage.VIEW_SWITCH_ACTIONS
            .filter { it.id !in enabled }
        if (viewSwitch.isNotEmpty()) {
            add(
                EditorSection(
                    label = SettingsStringsExt4.homeDockEditorViewCategory.text,
                    candidates = viewSwitch.map {
                        EditorCandidate(it.id, it.title.text, dockGlyph(it.id))
                    },
                ),
            )
        }
        // 四个目录分类，声明顺序即屏上分组顺序。
        DockCategory.entries.forEach { category ->
            val candidates = SettingsGlassDockEditorPage.candidates(category, enabled, state.debugBuild)
            add(
                EditorSection(
                    label = category.label.text,
                    candidates = candidates.map {
                        EditorCandidate(it.id, it.title.text, dockGlyph(it.id))
                    },
                ),
            )
        }
    }

    EditorPage(
        title = SettingsStringsExt4.glassDockCustomizeTitle.text,
        enabledIds = enabled,
        labelOf = labelOf,
        glyphOf = glyphOf,
        canAdd = enabled.size < SettingsGlassDockEditorPage.MAX_SLOTS,
        canRemove = enabled.size > 1,
        pinnedId = null,
        enabledTitle = SettingsStringsExt4.homeGridEditorEnabledTitle.text,
        hintText = SettingsStringsExt4.homeGridEditorHintBody
            .filled("max", SettingsGlassDockEditorPage.MAX_SLOTS.toString()),
        allAddedText = SettingsStringsExt4.homeGridEditorAllAdded.text,
        maxReachedText = SettingsStringsExt4.homeGridEditorMaxReached.text,
        removeTooltip = SettingsStringsExt4.homeGridEditorRemoveTooltip.text,
        pinnedTooltip = SettingsStringsExt4.homeGridEditorRemoveTooltip.text,
        resetLabel = SettingsStringsExt4.homeGridEditorResetAction.text,
        sections = sections,
        onBack = onBack,
        onAdd = onAdd,
        onRemove = onRemove,
        onMove = onMove,
        onReset = onReset,
    )
}

/**
 * 八宫格菜单按钮编辑器。
 *
 * 与底栏唯一的行为差异：`settings`（[SettingsHomeMenuEditorPage.PINNED_ACTION_ID]）是
 * 回到本页的稳定入口，**始终显示但在只剩一个 / 钉住时不可移除**。
 *
 * @param state 当前草稿（`enabledIds` 由宿主清洗后传入）
 * @param onAdd 添加一个入口（参数是入口 id）
 * @param onRemove 移除一个入口（参数是入口 id）
 * @param onMove 拖动排序完成时回调（`from`/`to` 为最终下标）
 * @param onReset 恢复默认排列
 */
@Composable
fun HomeMenuEditorScreen(
    state: SettingsHomeMenuEditorState,
    onBack: () -> Unit,
    onAdd: (String) -> Unit,
    onRemove: (String) -> Unit,
    onMove: (from: Int, to: Int) -> Unit,
    onReset: () -> Unit,
) {
    val enabled = state.enabledIds
    val build = state.diagnosticsBuild
    val labelOf: (String) -> String = { id ->
        SettingsHomeNavigationPage.catalog(build).firstOrNull { it.id == id }?.label?.text ?: id
    }
    val glyphOf: (String) -> ImageVector = { dockGlyph(it) }

    val sections = SettingsHomeMenuEditorPage.CATEGORIES.map { category ->
        val candidates = SettingsHomeMenuEditorPage.candidatesFor(category, enabled, build)
        EditorSection(
            label = homeMenuCategoryLabelZh(category),
            candidates = candidates.map {
                EditorCandidate(it.id, it.label.text, dockGlyph(it.id))
            },
        )
    }

    EditorPage(
        title = SettingsStringsExt2.homeMenuCustomizeTitle.text,
        enabledIds = enabled,
        labelOf = labelOf,
        glyphOf = glyphOf,
        canAdd = enabled.size < SettingsHomeMenuEditorPage.MAX_SLOTS,
        canRemove = enabled.size > 1,
        pinnedId = SettingsHomeMenuEditorPage.PINNED_ACTION_ID,
        enabledTitle = SettingsStringsExt2.homeGridEditorEnabledTitle.text,
        hintText = SettingsStringsExt2.homeGridEditorHintBody
            .filled("max", SettingsHomeMenuEditorPage.MAX_SLOTS.toString()),
        allAddedText = SettingsStringsExt2.homeGridEditorAllAdded.text,
        maxReachedText = SettingsStringsExt2.homeGridEditorMaxReached.text,
        removeTooltip = SettingsStringsExt2.homeGridEditorRemoveTooltip.text,
        pinnedTooltip = SettingsStringsExt2.homeGridEditorPinnedTooltip.text,
        resetLabel = SettingsStringsExt2.homeGridEditorResetAction.text,
        sections = sections,
        onBack = onBack,
        onAdd = onAdd,
        onRemove = onRemove,
        onMove = onMove,
        onReset = onReset,
    )
}

// ============================================================ 共用骨架

@Composable
private fun EditorPage(
    title: String,
    enabledIds: List<String>,
    labelOf: (String) -> String,
    glyphOf: (String) -> ImageVector,
    canAdd: Boolean,
    canRemove: Boolean,
    pinnedId: String?,
    enabledTitle: String,
    hintText: String,
    allAddedText: String,
    maxReachedText: String,
    removeTooltip: String,
    pinnedTooltip: String,
    resetLabel: String,
    sections: List<EditorSection>,
    onBack: () -> Unit,
    onAdd: (String) -> Unit,
    onRemove: (String) -> Unit,
    onMove: (from: Int, to: Int) -> Unit,
    onReset: () -> Unit,
) {
    QingyuPageScaffold(title = title, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 横向 12dp + 卡片内 Preference 风格 16dp = 文字左缘 28dp，与 SmallTitle 对齐。
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
        ) {
            item(key = "editor.preview") {
                EditorPreviewCard(enabledIds, labelOf, glyphOf)
            }
            item(key = "editor.enabled.title") {
                QingyuSectionTitle(text = enabledTitle)
            }
            item(key = "editor.enabled.list") {
                EnabledReorderList(
                    ids = enabledIds,
                    labelOf = labelOf,
                    glyphOf = glyphOf,
                    canRemove = canRemove,
                    pinnedId = pinnedId,
                    removeTooltip = removeTooltip,
                    pinnedTooltip = pinnedTooltip,
                    onRemove = onRemove,
                    onMove = onMove,
                )
            }
            item(key = "editor.hint") {
                EditorDescription(hintText)
            }
            sections.forEachIndexed { index, section ->
                item(key = "editor.section.$index.title") {
                    QingyuSectionTitle(text = section.label)
                }
                if (section.candidates.isEmpty()) {
                    // 该分类全部启用时给一句说明，而不是留一张空卡（Dart :163-165 / :131-133）。
                    item(key = "editor.section.$index.empty") {
                        EditorDescription(allAddedText)
                    }
                } else {
                    item(key = "editor.section.$index.card") {
                        CandidateCard(
                            candidates = section.candidates,
                            canAdd = canAdd,
                            maxReachedText = maxReachedText,
                            onAdd = onAdd,
                        )
                    }
                }
            }
            item(key = "editor.reset") {
                ResetCard(label = resetLabel, onReset = onReset)
            }
        }
    }
}

// ============================================================ 预览卡

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EditorPreviewCard(
    ids: List<String>,
    labelOf: (String) -> String,
    glyphOf: (String) -> ImageVector,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = QingyuSectionGap),
        insideMargin = PaddingValues(16.dp),
    ) {
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ids.forEach { id ->
                Column(
                    modifier = Modifier.width(72.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    DockIconBadge(glyph = glyphOf(id))
                    Spacer(modifier = Modifier.height(5.dp))
                    Text(
                        text = labelOf(id),
                        style = MiuixTheme.textStyles.footnote1,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

// ============================================================ 已启用可拖动列表

@Composable
private fun EnabledReorderList(
    ids: List<String>,
    labelOf: (String) -> String,
    glyphOf: (String) -> ImageVector,
    canRemove: Boolean,
    pinnedId: String?,
    removeTooltip: String,
    pinnedTooltip: String,
    onRemove: (String) -> Unit,
    onMove: (from: Int, to: Int) -> Unit,
) {
    val density = LocalDensity.current
    val pitchPx = with(density) { (DockSlotRowHeight + DockSlotRowGap).toPx() }

    var draggingIndex by remember { mutableStateOf(-1) }
    var dragOffsetY by remember { mutableStateOf(0f) }

    Column(modifier = Modifier.fillMaxWidth()) {
        ids.forEachIndexed { index, id ->
            val pinned = id == pinnedId
            val rowCanRemove = canRemove && !pinned
            DockSlotRow(
                index = index,
                itemCount = ids.size,
                pitchPx = pitchPx,
                title = labelOf(id),
                glyph = glyphOf(id),
                tooltip = if (pinned) pinnedTooltip else removeTooltip,
                canRemove = rowCanRemove,
                isDragging = draggingIndex == index,
                dragOffsetY = dragOffsetY,
                onRemove = { onRemove(id) },
                onDragStart = {
                    draggingIndex = index
                    dragOffsetY = 0f
                },
                onDragDelta = { dragOffsetY = it },
                onDragEnd = { to ->
                    draggingIndex = -1
                    dragOffsetY = 0f
                    if (to != index) onMove(index, to)
                },
                onDragCancel = {
                    draggingIndex = -1
                    dragOffsetY = 0f
                },
            )
        }
    }
}

@Composable
private fun DockSlotRow(
    index: Int,
    itemCount: Int,
    pitchPx: Float,
    title: String,
    glyph: ImageVector,
    tooltip: String,
    canRemove: Boolean,
    isDragging: Boolean,
    dragOffsetY: Float,
    onRemove: () -> Unit,
    onDragStart: () -> Unit,
    onDragDelta: (Float) -> Unit,
    onDragEnd: (Int) -> Unit,
    onDragCancel: () -> Unit,
) {
    // pointerInput 只在 (index, itemCount) 变化时重启；用 rememberUpdatedState 取最新回调，
    // 避免重排后指针协程里仍调用上一帧捕获的旧 onMove/onDrag* 闭包。
    val currentOnDragStart by rememberUpdatedState(onDragStart)
    val currentOnDragDelta by rememberUpdatedState(onDragDelta)
    val currentOnDragEnd by rememberUpdatedState(onDragEnd)
    val currentOnDragCancel by rememberUpdatedState(onDragCancel)
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = DockSlotRowGap)
            .zIndex(if (isDragging) 1f else 0f)
            .graphicsLayer {
                if (isDragging) {
                    translationY = dragOffsetY
                    scaleX = 1.02f
                    scaleY = 1.02f
                }
            },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(DockSlotRowHeight),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // 行首拖动手柄：长按后拖动该行排序。
            Box(
                modifier = Modifier
                    .padding(start = 8.dp)
                    .width(32.dp)
                    .height(DockSlotRowHeight)
                    .pointerInput(index, itemCount) {
                        var acc = 0f
                        detectDragGesturesAfterLongPress(
                            onDragStart = {
                                acc = 0f
                                currentOnDragStart()
                            },
                            onDrag = { change, dragAmount ->
                                change.consume()
                                acc += dragAmount.y
                                currentOnDragDelta(acc)
                            },
                            onDragEnd = {
                                val to = (index + (acc / pitchPx).roundToInt())
                                    .coerceIn(0, itemCount - 1)
                                currentOnDragEnd(to)
                            },
                            onDragCancel = { currentOnDragCancel() },
                        )
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = MiuixIcons.Sort,
                    contentDescription = null,
                    tint = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    modifier = Modifier.size(20.dp),
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            DockIconBadge(glyph = glyph)
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = title,
                modifier = Modifier.weight(1f),
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = MiuixTheme.colorScheme.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            IconButton(
                onClick = onRemove,
                modifier = Modifier.size(44.dp),
                enabled = canRemove,
            ) {
                Icon(
                    imageVector = MiuixIcons.Remove,
                    contentDescription = tooltip,
                    tint = if (canRemove) {
                        MiuixTheme.colorScheme.error
                    } else {
                        MiuixTheme.colorScheme.onSurfaceVariantSummary.copy(alpha = 0.4f)
                    },
                    modifier = Modifier.size(22.dp),
                )
            }
            Spacer(modifier = Modifier.width(6.dp))
        }
    }
}

// ============================================================ 候选行 / 恢复默认 / 说明

@Composable
private fun CandidateCard(
    candidates: List<EditorCandidate>,
    canAdd: Boolean,
    maxReachedText: String,
    onAdd: (String) -> Unit,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = QingyuSectionGap),
        insideMargin = PaddingValues(0.dp),
    ) {
        candidates.forEach { candidate ->
            CandidateRow(
                candidate = candidate,
                canAdd = canAdd,
                maxReachedText = maxReachedText,
                onAdd = onAdd,
            )
        }
    }
}

/**
 * 候选行：点击把该入口加入已启用列表。
 *
 * Dart 侧候选行与设置导航行是**同一个** `HyperosListTile`（行首彩色徽章 + 标题 +
 * 行尾读数 + chevron，`tiles.dart:268-271`；`settings_glass_dock_editor.dart:139-144`），
 * Compose 侧因此与设置族渲染层用同一件官方 `ArrowPreference`，不再自拼 `Row`。
 *
 * 与 Dart 的两处差异（有意，且都在这里留痕）：
 * * 行首徽章：Dart 的 `HyperosListTile` 行内徽章是 26dp 实底款（`HyperosIconBadge`），
 *   46dp 那种是**预览卡**里的（`:198-213`）。原先这里误用了预览款（46dp、浅 tint），
 *   现在换成设置族同一块 [SettingsIconBadge]（26dp、实底、白图标）；
 * * 满格时：`onClick = null` + `enabled = false`——官方行整行灰化、点不动，与 Dart 一致。
 *   「已达上限」读数留在行尾：Dart 渲染层对不可点行其实不画 details（`tiles.dart:358`），
 *   但它是「为什么不可用」的有效说明，删掉等于砍提示，超出行控件替换的范畴，故保留。
 *   另外 [ArrowPreference] 的箭头恒画（`ArrowPreference.kt:80-83`，不随 `onClick` 消失），
 *   满格时比 Dart 多一枚灰箭头——组件能力缺口，如实记录。
 */
@Composable
private fun CandidateRow(
    candidate: EditorCandidate,
    canAdd: Boolean,
    maxReachedText: String,
    onAdd: (String) -> Unit,
) {
    ArrowPreference(
        title = candidate.label,
        startAction = { SettingsIconBadge(glyph = candidate.glyph, tintHex = null) },
        onClick = if (canAdd) {
            { onAdd(candidate.id) }
        } else {
            null
        },
        enabled = canAdd,
        endActions = {
            if (!canAdd) {
                Text(
                    text = maxReachedText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
            }
        },
    )
}

/**
 * 「恢复默认排列」：Dart 侧就是分组白卡内的一条普通导航行
 * （`HyperosListGroup` + `HyperosListTile(title, onTap)`，`settings_glass_dock_editor.dart:109-116`），
 * 与设置族「卡片 + 官方行」同构。原先自拼 `Row + ChevronForward`（定高 56dp 行），
 * 现在换官方 [ArrowPreference]：行高、行内边距、箭头尺寸（10×16dp）、按压反馈
 * 全部交给官方组件，与设置族所有箭头行同一套手感（2026-11-02 对齐官方 preference 组件）。
 */
@Composable
private fun ResetCard(
    label: String,
    onReset: () -> Unit,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = QingyuSectionGap),
        insideMargin = PaddingValues(0.dp),
    ) {
        ArrowPreference(title = label, onClick = onReset)
    }
}

/** 整宽说明句（Dart `HyperosSectionDescription`）：不受行内单行宽度口径约束，允许折行。 */
@Composable
private fun EditorDescription(text: String) {
    Text(
        text = text,
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 8.dp),
        style = MiuixTheme.textStyles.footnote1,
        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
    )
}

// ============================================================ 图标徽章 & 近似图标

/** 图标徽章：46dp 圆角 14dp 方块，底色 primary 浅 tint，图标 primary 24dp。 */
@Composable
private fun DockIconBadge(glyph: ImageVector) {
    val primary = MiuixTheme.colorScheme.primary
    Box(
        modifier = Modifier
            .size(46.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(primary.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = glyph,
            contentDescription = null,
            tint = primary,
            modifier = Modifier.size(24.dp),
        )
    }
}

/** 分类小标题（`homeMenuEntryCategoryLabel`，`home_top_menu.dart:12-20`）的 ARB 值。 */
private fun homeMenuCategoryLabelZh(category: String): String = when (category) {
    "features" -> SettingsStringsExt2.homeMenuCategoryFeatures.text
    "data" -> SettingsStringsExt2.homeMenuCategoryData.text
    "preferences" -> SettingsStringsExt2.homeMenuCategoryPreferences.text
    else -> SettingsStringsExt2.homeMenuCategoryAbout.text
}

/**
 * 入口 id → 近似图标。**精确图标需后续补一张 id→icon 表，本版为近似映射**；
 * 未收录的 id 回退到通用图标 [MiuixIcons.Info]。
 */
private fun dockGlyph(id: String): ImageVector = when (id) {
    "day" -> MiuixIcons.Notes
    "week" -> MiuixIcons.Weeks
    "tasks" -> MiuixIcons.Tasks
    "update" -> MiuixIcons.Update
    "pickupCode" -> MiuixIcons.Store
    "overview" -> MiuixIcons.ListView
    "statistics" -> MiuixIcons.Sort
    "addCourse" -> MiuixIcons.Add
    "exams" -> MiuixIcons.Alarm
    "importCourses" -> MiuixIcons.Import
    "courseRecolor" -> MiuixIcons.Theme
    "shareTimetable" -> MiuixIcons.Share
    "addExam" -> MiuixIcons.Add
    "addTask" -> MiuixIcons.Add
    "addScheduleItem" -> MiuixIcons.Add
    "scheduleList" -> MiuixIcons.Notes
    "courseConflict" -> MiuixIcons.Report
    "locationTimeMatch" -> MiuixIcons.Location
    "scheduleDateRule" -> MiuixIcons.Months
    "icsExport" -> MiuixIcons.File
    "monthView" -> MiuixIcons.Months
    "timeSchemes" -> MiuixIcons.Stopwatch
    "profiles" -> MiuixIcons.ListView
    "quickSwitchTimetable" -> MiuixIcons.Refresh
    "more" -> MiuixIcons.More
    "dataTransfer" -> MiuixIcons.Replace
    "cloudSync" -> MiuixIcons.UploadCloud
    "lanEdit" -> MiuixIcons.Link
    "coupleTimetable" -> MiuixIcons.Favorites
    "settings" -> MiuixIcons.Settings
    "homeNavigation" -> MiuixIcons.Home
    "generalSettings" -> MiuixIcons.Settings
    "appearanceSettings" -> MiuixIcons.Theme
    "appearanceEditor" -> MiuixIcons.Theme
    "timetablePageSettings" -> MiuixIcons.ListView
    "courseCardSettings" -> MiuixIcons.Notes
    "weatherSettings" -> MiuixIcons.Image
    "liveSettings" -> MiuixIcons.Messages
    "holidaySettings" -> MiuixIcons.Months
    "homeWidgetSettings" -> MiuixIcons.GridView
    "diagnosticsSettings" -> MiuixIcons.Report
    "statisticsSettings" -> MiuixIcons.Sort
    "support" -> MiuixIcons.Email
    "aboutApp" -> MiuixIcons.Info
    "changelog" -> MiuixIcons.Notes
    "userGuide" -> MiuixIcons.Help
    "feedback" -> MiuixIcons.Messages
    "openSourceLicenses" -> MiuixIcons.File
    "memoryStats" -> MiuixIcons.Report
    else -> MiuixIcons.Info
}

// ── Android Studio 预览（@Preview）────────────────────────────────────────────
//
// 与 `ContributorsPage` 同一套口径：一个 `Preview<页面>` 承担「已启用排列 + 外观档位」，
// 下面每个 `@Preview` 只选一档。预览不接宿主：回调一律空实现（添加 / 移除 / 拖动 / 重置）。
//
// 排列档位按页面的真实分支选，不凑数：
// * 满格（底栏 5 / 八宫格 8）→ 候选行整行灰化、行尾「已达上限」，分类全启用时换一句说明；
// * 只剩一格 → 「已启用」行的减号变灰不可点；
// * 八宫格里 `settings` 钉住，即使未满格也不可移除。

/** 底栏出厂的三个入口（`SettingsGlassDockEditorPage.DEFAULT_ACTIONS`）。 */
private val previewDockDefaultIds = listOf("day", "week", "tasks")

/** 底栏满格：出厂三个 + 两个功能入口（`MAX_SLOTS = 5`）。 */
private val previewDockFullIds = listOf("day", "week", "tasks", "exams", "importCourses")

/** 底栏只剩一格：此时 `canRemove = false`。 */
private val previewDockSingleIds = listOf("week")

/** 八宫格出厂排列（`SettingsHomeMenuEditorPage.DEFAULT_ACTIONS`，已满 8 格）。 */
private val previewHomeMenuDefaultIds = listOf(
    "overview", "statistics", "addCourse", "exams",
    "tasks", "importCourses", "settings", "support",
)

/** 八宫格未满格：四个入口，其中 `settings` 被钉住。 */
private val previewHomeMenuPartialIds = listOf("overview", "addCourse", "settings", "support")

/** 一档预览的公共身体：玻璃坞底栏的已启用排列 + 外观档位。 */
@Composable
private fun PreviewGlassDockEditorScreen(
    enabledIds: List<String> = previewDockDefaultIds,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        GlassDockEditorScreen(
            state = GlassDockEditorState(enabledIds = enabledIds),
            onBack = {},
            onAdd = {},
            onRemove = {},
            onMove = { _, _ -> },
            onReset = {},
        )
    }
}

/** 一档预览的公共身体：八宫格菜单的已启用排列 + 外观档位。 */
@Composable
private fun PreviewHomeMenuEditorScreen(
    enabledIds: List<String> = previewHomeMenuDefaultIds,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        HomeMenuEditorScreen(
            state = SettingsHomeMenuEditorState(enabledIds = enabledIds),
            onBack = {},
            onAdd = {},
            onRemove = {},
            onMove = { _, _ -> },
            onReset = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 玻璃坞·出厂三格", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockEditorScreenPreviewDefault() {
    PreviewGlassDockEditorScreen()
}

@Suppress("unused")
@Preview(name = "2 玻璃坞·满格五格", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockEditorScreenPreviewFull() {
    PreviewGlassDockEditorScreen(enabledIds = previewDockFullIds)
}

@Suppress("unused")
@Preview(name = "3 玻璃坞·只剩一格", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockEditorScreenPreviewSingle() {
    PreviewGlassDockEditorScreen(enabledIds = previewDockSingleIds)
}

@Suppress("unused")
@Preview(name = "4 玻璃坞·暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockEditorScreenPreviewDark() {
    PreviewGlassDockEditorScreen(dark = true)
}

@Suppress("unused")
@Preview(name = "5 玻璃坞·大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun GlassDockEditorScreenPreviewLargeText() {
    PreviewGlassDockEditorScreen(textScale = 1.3f)
}

@Suppress("unused")
@Preview(name = "6 八宫格·出厂八格", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HomeMenuEditorScreenPreviewDefault() {
    PreviewHomeMenuEditorScreen()
}

@Suppress("unused")
@Preview(name = "7 八宫格·未满格", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HomeMenuEditorScreenPreviewPartial() {
    PreviewHomeMenuEditorScreen(enabledIds = previewHomeMenuPartialIds)
}

@Suppress("unused")
@Preview(name = "8 八宫格·暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HomeMenuEditorScreenPreviewDark() {
    PreviewHomeMenuEditorScreen(dark = true)
}

@Suppress("unused")
@Preview(name = "9 八宫格·大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun HomeMenuEditorScreenPreviewLargeText() {
    PreviewHomeMenuEditorScreen(textScale = 1.3f)
}
