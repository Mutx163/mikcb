package com.mutx163.qingyu.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.pages.settings.GlassDockEditorScreen
import com.mutx163.qingyu.pages.settings.GlassDockEditorState
import com.mutx163.qingyu.pages.settings.HomeMenuEditorScreen
import com.mutx163.qingyu.pages.settings.SettingsGlassDockEditorPage
import com.mutx163.qingyu.pages.settings.SettingsHomeMenuEditorPage
import com.mutx163.qingyu.pages.settings.SettingsHomeMenuEditorState
import com.mutx163.qingyu.pages.settings.SettingsHomeNavigationPage
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.pages.settings.SettingsStringsExt1
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.pages.settings.SettingsTimetablePageSettingsPage
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Slider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.util.Locale

/**
 * 设置族宿主（Phase 3.5 · 设置族竖切第一刀）。
 *
 * 一份渲染层（`SettingsPageScreen(spec, …)`）服务 20 页，所以宿主也只有这一份：
 *
 * ```
 * TimetableSettingsModelStore ──load──▶ TimetableSettingsModel
 *          ▲                                  │ SettingsPageBridge.toSettingsPageState
 *          │ save                             ▼
 *          └──────── Write ◀── SettingsActionDispatcher ◀── onAction(action, target, rowId)
 *                                            │
 *                                            └── 其余意图（导航/弹层/剪贴板/恢复默认）→ 壳
 * ```
 *
 * ## 本刀只认 4 页
 *
 * 通用 / 外观 / 主题管理 / 课程卡片（[SettingsPageBridge.SUPPORTED_PAGE_IDS]）。
 * 传别的页 id ⇒ `specFor` 返回 null ⇒ **本宿主什么都不渲染**（由壳决定要不要回退到
 * 演示数据），不会崩。
 *
 * ## 写回与重组
 *
 * `WRITE_SETTING` 由分派器算出新模型 → `store.save(...)`（**合并写**，只覆盖本模型
 * 拥有的 35 个键）→ 更新本地状态 → 重组。界面立刻跟着变，盘上也同步变了。
 *
 * ## 与仓储（`TimetableRepository`）共用同一个键，为什么不冲突
 *
 * 仓储只写 `timetable_settings` 里的 **core 4 键**（sections / activeTimeSchemeId /
 * semesterWeekCount / semesterStartDate），本模型写另外 35 个显示键；两者都走
 * `TimetableStore.saveSettingsPatch` 的**读-合并-写**，所以谁都不会覆盖谁。
 * ⚠️ 反过来：仓储在内存里那份设置与本宿主不同步，宿主**不做**外部变更订阅——
 * 本刀里设置只从本宿主改（Dart 侧 `_updateDraft` → `_enqueuePersist` 也是这个形态）。
 *
 * ## 预览区
 *
 * 课程卡片页的 `previewFlex = 4` 需要一张课卡预览，本刀**不提供**（`preview = null`）：
 * 渲染层在 preview 为 null 时忽略 flex、内容占满（`SettingsPageRenderers.kt:112-121`），
 * 所以不会出现空白条。真预览要接课程数据与壁纸采样，留给下一刀。
 *
 * @param pageId 四个受支持页 id 之一。
 * @param store 设置模型的读写入口（壳里由 `PrefsKeyValueStore` 构造）。
 * @param onBack 返回；null = 无返回键（与 `SettingsPageScreen` 的语义一致）。
 * @param onNavigate 推页（`NAVIGATE` 意图的路由）。
 * @param onIntent 其余界面意图（弹层 / 剪贴板 / 恢复默认确认 / RUN_NOW 等），由壳执行。
 * @param onRequestColor 选色：壳弹官方 `ColorPicker`，选完调 `commit(hex)`。
 *   不传 = 该行的选色不弹（no-op），不会崩。
 */
@Composable
fun SettingsHost(
    pageId: String,
    store: TimetableSettingsModelStore,
    onBack: (() -> Unit)? = null,
    onNavigate: (route: String) -> Unit = {},
    onIntent: (SettingsDispatch) -> Unit = {},
    /** 传 null 时宿主自带一个 RGB 选色弹窗；壳想接官方选色器时再传实现。 */
    onRequestColor: ((rowId: String, currentHex: String, commit: (String) -> Unit) -> Unit)? = null,
    /** 顶部预览槽（课程卡片 / 课表页面两页的 4:6 分栏用）；null = 该页无预览。 */
    preview: (@Composable () -> Unit)? = null,
) {
    var model by remember(store) { mutableStateOf(store.load()) }
    var pendingReset by remember { mutableStateOf<String?>(null) }
    var pendingColor by remember { mutableStateOf<ColorEdit?>(null) }

    // 写路径只有这一条：算新模型 → 落盘 → 更新状态（界面跟着重组）。
    fun commitWrite(target: String?, rowId: String) {
        when (
            val result = SettingsActionDispatcher.dispatch(
                kind = SettingsActionKind.WRITE_SETTING,
                target = target,
                rowId = rowId,
                model = model,
            )
        ) {
            is SettingsDispatch.Write -> {
                store.save(result.model)
                model = result.model
            }
            // 值不认识 / rowId 不认识：不写、不崩，交给壳记录。
            else -> onIntent(result)
        }
    }

    /** 恢复默认：**先确认**，确认后把该作用域写回并落盘（Dart 同口径）。 */
    fun applyReset(scope: String) {
        SettingsActionDispatcher.applyResetScope(model, scope)?.let { next ->
            store.save(next)
            model = next
        }
    }

    val state = SettingsPageBridge.toSettingsPageState(model)
    val spec = SettingsPageBridge.specFor(pageId, state) ?: return

    Box(modifier = Modifier.fillMaxSize()) {
        SettingsPageScreen(
            spec = spec,
            preview = preview,
            onBack = onBack,
            onAction = { action, target, rowId ->
                when (val kind = SettingsPageBridge.toKind(action)) {
                    SettingsActionKind.WRITE_SETTING -> commitWrite(target, rowId)

                    // 原来这些动作全被转给 onIntent（壳没传 ⇒ 默认空实现），于是
                    // 「外观编辑器/主题管理」两个入口、课程卡片的材质面板都点了没反应。
                    // 导航类意图现在由宿主直接交给壳的路由回调。
                    SettingsActionKind.NAVIGATE,
                    SettingsActionKind.MATERIAL_PANEL -> target?.let(onNavigate)

                    // 恢复默认：弹确认框，确认后写回（Dart `settings_reset.dart` 也是先确认）。
                    SettingsActionKind.RESET_SCOPE -> target?.let { pendingReset = it }

                    // 选色：壳没提供选色器时，宿主自带一个 RGB 弹窗。
                    SettingsActionKind.COLOR_PICKER -> {
                        val current = SettingsPageBridge.currentColorHex(model, rowId)
                        when {
                            current == null -> onIntent(
                                SettingsDispatch.Ignored(
                                    kind = kind,
                                    target = target,
                                    rowId = rowId,
                                    // 开发者向诊断码，不是屏上文案（CjkLiteralGateTest）。
                                    reason = "row_not_a_color_row",
                                ),
                            )
                            onRequestColor != null -> onRequestColor(rowId, current) { hex ->
                                commitWrite(hex, rowId)
                            }
                            else -> pendingColor = ColorEdit(rowId, current)
                        }
                    }

                    // 剪贴板 / 对话框 / 底部弹层 / 立刻更新等仍交给壳（见诚实清单）。
                    else -> onIntent(
                        SettingsActionDispatcher.dispatch(kind, target, rowId, model),
                    )
                }
            },
        )

        pendingReset?.let { scope ->
            SettingsConfirmResetDialog(
                scope = scope,
                onDismiss = { pendingReset = null },
                onConfirm = {
                    applyReset(scope)
                    pendingReset = null
                },
            )
        }

        pendingColor?.let { edit ->
            SettingsColorPickerDialog(
                initialHex = edit.hex,
                onDismiss = { pendingColor = null },
                onConfirm = { hex ->
                    commitWrite(hex, edit.rowId)
                    pendingColor = null
                },
            )
        }
    }
}

/** 选色弹窗的一次编辑目标：行 id + 当前色。 */
private data class ColorEdit(val rowId: String, val hex: String)

/** 全屏遮罩 + 居中卡片；点遮罩关闭。 */
@Composable
private fun SettingsDialogFrame(
    onDismiss: () -> Unit,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.45f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        // 内层再拦一次点击，避免点卡片本身把弹窗关掉。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .clickable(onClick = {}),
        ) {
            content()
        }
    }
}

/** 恢复默认确认弹窗（作用域不同，正文不同；文案全部取 ARB）。 */
@Composable
private fun SettingsConfirmResetDialog(
    scope: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val body = when (scope) {
        SettingsActionDispatcher.SCOPE_COURSE_CARD ->
            SettingsStringsExt4.settingsResetConfirmBodyCourseCard.zh
        SettingsActionDispatcher.SCOPE_APPEARANCE ->
            SettingsStringsExt4.settingsResetConfirmBodyAppearance.zh
        SettingsActionDispatcher.SCOPE_HOME_NAVIGATION ->
            SettingsStringsExt4.settingsResetConfirmBodyHomeNavigation.zh
        else -> SettingsStringsExt4.settingsResetScopeNoticeAppearance.zh
    }
    SettingsDialogFrame(onDismiss = onDismiss) {
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = SettingsStringsExt4.settingsResetDefaultsConfirmTitle.zh,
                    style = MiuixTheme.textStyles.title4,
                    fontWeight = FontWeight.Bold,
                    color = MiuixTheme.colorScheme.onBackground,
                )
                Text(
                    text = body,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                ) {
                    Button(onClick = onDismiss) {
                        Text(
                            text = SettingsStringsExt4.cancelAction.zh,
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(onClick = onConfirm) {
                        Text(
                            text = SettingsStrings.themeResetToPreset.zh,
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                }
            }
        }
    }
}

/** RGB 选色弹窗：三通道滑杆 + 实时预览 + 十六进制读数。 */
@Composable
private fun SettingsColorPickerDialog(
    initialHex: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    val initial = remember(initialHex) { parseHexRgb(initialHex) }
    var red by remember(initialHex) { mutableStateOf(initial[0]) }
    var green by remember(initialHex) { mutableStateOf(initial[1]) }
    var blue by remember(initialHex) { mutableStateOf(initial[2]) }
    val hex = rgbToHex(red, green, blue)

    SettingsDialogFrame(onDismiss = onDismiss) {
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "RGB",
                        style = MiuixTheme.textStyles.title4,
                        fontWeight = FontWeight.Bold,
                        color = MiuixTheme.colorScheme.onBackground,
                    )
                    Text(
                        text = hex,
                        style = MiuixTheme.textStyles.body2,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(red, green, blue)),
                )
                ColorChannel("R", red) { red = it }
                ColorChannel("G", green) { green = it }
                ColorChannel("B", blue) { blue = it }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                ) {
                    Button(onClick = onDismiss) {
                        Text(
                            text = SettingsStringsExt4.cancelAction.zh,
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(onClick = { onConfirm(hex) }) {
                        Text(
                            text = SettingsStringsExt1.appearanceEditorDoneAction.zh,
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ColorChannel(label: String, value: Int, onChange: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            modifier = Modifier.width(20.dp),
            style = MiuixTheme.textStyles.body2,
            color = MiuixTheme.colorScheme.onBackground,
        )
        Slider(
            value = value / 255f,
            onValueChange = { onChange((it * 255f).toInt().coerceIn(0, 255)) },
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value.toString(),
            modifier = Modifier.width(40.dp),
            style = MiuixTheme.textStyles.body2,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        )
    }
}

/** `#RRGGBB` / `#AARRGGBB` → [r, g, b]（0..255）；坏值按黑处理。 */
private fun parseHexRgb(hex: String): IntArray {
    val cleaned = hex.trim().removePrefix("#")
    val value = cleaned.toLongOrNull(16) ?: 0L
    return intArrayOf(
        ((value shr 16) and 0xFF).toInt(),
        ((value shr 8) and 0xFF).toInt(),
        (value and 0xFF).toInt(),
    )
}

private fun rgbToHex(r: Int, g: Int, b: Int): String =
    "#%02X%02X%02X".format(Locale.ROOT, r, g, b)

// =====================================================================================
// S2 接线：首页与导航 + 两个编辑器（真数据 / 真落盘）
// =====================================================================================

/**
 * 「首页与导航」设置页的**真宿主**（S2 接线，替代壳里 no-op 的 `SettingsScreen`）。
 *
 * 与 [SettingsHost] 同一套「读模型 → 建 spec → 动作回分派 → 合并落盘」循环，差异三点：
 * 1. spec 由 [SettingsHomeNavigationPage.spec] 出（不是 [SettingsPageBridge.specFor] 的那 4 页）；
 * 2. `NAVIGATE` 交给壳的 [onNavigate]（路由串 → 页面 id 由壳映射后推页）；
 * 3. `RESET_SCOPE` 调 [SettingsActionDispatcher.applyResetScope]（作用域 `homeNavigation`）。
 *
 * Dart 原文 `settings_home_navigation.dart:168-172` 的「三子页返回后重读草稿」，由「每次进入
 * 本页都重新 `store.load()` 建宿主」自然满足：壳按 pageId 重组，从子页返回即重建、重新读盘。
 */
@Composable
fun HomeNavigationHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
    onNavigate: (route: String) -> Unit = {},
) {
    var model by remember(store) { mutableStateOf(store.load()) }
    fun apply(newModel: TimetableSettingsModel) {
        store.save(newModel)
        model = newModel
    }
    val state = SettingsPageBridge.toHomeNavigationState(model)
    SettingsPageScreen(
        spec = SettingsHomeNavigationPage.spec(state),
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (SettingsPageBridge.toKind(action)) {
                SettingsActionKind.WRITE_SETTING -> {
                    val result = SettingsActionDispatcher.dispatch(
                        SettingsActionKind.WRITE_SETTING,
                        target,
                        rowId,
                        model,
                    )
                    if (result is SettingsDispatch.Write) apply(result.model)
                }

                SettingsActionKind.NAVIGATE -> target?.let(onNavigate)

                SettingsActionKind.RESET_SCOPE -> {
                    target?.let { scope ->
                        SettingsActionDispatcher.applyResetScope(model, scope)?.let { apply(it) }
                    }
                }

                else -> Unit
            }
        },
    )
}

/**
 * 「课表页面设置」真宿主（S2 接线第二批）。
 *
 * 与 [SettingsHost] 同一套「读模型 → 建 spec → 动作回分派 → 合并落盘」循环；差异是
 * spec 由 [SettingsTimetablePageSettingsPage.spec] 出，状态是页面私有的
 * `TimetablePageSettingsState`（不是共享的 `SettingsPageState`）。
 *
 * ## 背景色板的拦截（重要）
 *
 * 渲染层的 `ColorChipGroup` 历史原因固定发 `ROW_CARD_COLOR_CHIPS`（课卡统一色）。
 * 本页的背景色板复用了它，若直接分派会把「课表背景色」写成「课卡统一色」。
 * 所以这里把该 rowId 拦成 [SettingsActionDispatcher.ROW_TP_BG_CHIPS]（本模型不拥有
 * 背景色 ⇒ Ignored），宁可不写也不写错字段。
 */
@Composable
fun TimetablePageSettingsHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
    onNavigate: (route: String) -> Unit = {},
    /** 顶部预览槽（4:6 分栏）；null = 不画预览。 */
    preview: (@Composable () -> Unit)? = null,
) {
    var model by remember(store) { mutableStateOf(store.load()) }

    fun commitWrite(target: String?, rowId: String) {
        val actual = if (rowId == SettingsActionDispatcher.ROW_CARD_COLOR_CHIPS) {
            SettingsActionDispatcher.ROW_TP_BG_CHIPS
        } else {
            rowId
        }
        when (
            val result = SettingsActionDispatcher.dispatch(
                kind = SettingsActionKind.WRITE_SETTING,
                target = target,
                rowId = actual,
                model = model,
            )
        ) {
            is SettingsDispatch.Write -> {
                store.save(result.model)
                model = result.model
            }
            else -> Unit
        }
    }

    SettingsPageScreen(
        spec = SettingsTimetablePageSettingsPage.spec(SettingsPageBridge.toTimetablePageState(model)),
        preview = preview,
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (SettingsPageBridge.toKind(action)) {
                SettingsActionKind.WRITE_SETTING -> commitWrite(target, rowId)
                SettingsActionKind.NAVIGATE -> target?.let(onNavigate)
                else -> Unit
            }
        },
    )
}

/** 编辑器「已启用」初始值：空表回退出厂默认，否则按当前值清洗脏/不可见 id（同 Dart 种子口径）。 */
private fun dockEditorSeed(raw: List<String>): List<String> =
    if (raw.isEmpty()) {
        SettingsGlassDockEditorPage.DEFAULT_ACTIONS
    } else {
        SettingsGlassDockEditorPage.sanitize(raw, debugBuild = false)
    }

private fun menuEditorSeed(raw: List<String>): List<String> =
    if (raw.isEmpty()) {
        SettingsHomeMenuEditorPage.DEFAULT_ACTIONS
    } else {
        SettingsHomeMenuEditorPage.sanitizeSeed(raw, diagnosticsBuild = false)
    }

/**
 * 「自定义底栏按钮」编辑器真宿主：把 [GlassDockEditorScreen] 的增/删/移/恢复回调翻译成
 * `dock.*` 分派 → 写回 `glassDockActions` → 合并落盘。
 */
@Composable
fun GlassDockEditorHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
) {
    var model by remember(store) { mutableStateOf(store.load()) }
    fun write(rowId: String, target: String?) {
        // 空表（从没存过）先回退出厂排列：否则「加一个」以空表为底会把 day/week 一起丢掉。
        val base = if (model.glassDockActions.isEmpty()) {
            model.copy(glassDockActions = SettingsGlassDockEditorPage.DEFAULT_ACTIONS)
        } else {
            model
        }
        val result = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            target,
            rowId,
            base,
        )
        if (result is SettingsDispatch.Write) {
            store.save(result.model)
            model = result.model
        }
    }
    GlassDockEditorScreen(
        state = GlassDockEditorState(enabledIds = dockEditorSeed(model.glassDockActions)),
        onBack = onBack,
        onAdd = { id -> write(SettingsActionDispatcher.ROW_DOCK_ADD, id) },
        onRemove = { id -> write(SettingsActionDispatcher.ROW_DOCK_REMOVE, id) },
        onMove = { from, to -> write(SettingsActionDispatcher.ROW_DOCK_MOVE, "$from:$to") },
        onReset = { write(SettingsActionDispatcher.ROW_DOCK_RESET, null) },
    )
}

/**
 * 「自定义菜单按钮」编辑器真宿主：把 [HomeMenuEditorScreen] 的增/删/移/恢复回调翻译成
 * `menu.*` 分派 → 写回 `homeGridMenuActions` → 合并落盘。
 */
@Composable
fun HomeMenuEditorHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
) {
    var model by remember(store) { mutableStateOf(store.load()) }
    fun write(rowId: String, target: String?) {
        val base = if (model.homeGridMenuActions.isEmpty()) {
            model.copy(homeGridMenuActions = SettingsHomeMenuEditorPage.DEFAULT_ACTIONS)
        } else {
            model
        }
        val result = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            target,
            rowId,
            base,
        )
        if (result is SettingsDispatch.Write) {
            store.save(result.model)
            model = result.model
        }
    }
    HomeMenuEditorScreen(
        state = SettingsHomeMenuEditorState(enabledIds = menuEditorSeed(model.homeGridMenuActions)),
        onBack = onBack,
        onAdd = { id -> write(SettingsActionDispatcher.ROW_MENU_ADD, id) },
        onRemove = { id -> write(SettingsActionDispatcher.ROW_MENU_REMOVE, id) },
        onMove = { from, to -> write(SettingsActionDispatcher.ROW_MENU_MOVE, "$from:$to") },
        onReset = { write(SettingsActionDispatcher.ROW_MENU_RESET, null) },
    )
}
