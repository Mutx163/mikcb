package com.mutx163.qingyu.app

import android.util.Log
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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.pages.import.CourseAutoRefreshModel
import com.mutx163.qingyu.pages.import.CourseAutoRefreshSchedule
import com.mutx163.qingyu.pages.import.CourseAutoRefreshSettingsLogic
import com.mutx163.qingyu.pages.import.CourseAutoRefreshStore
import com.mutx163.qingyu.pages.settings.GlassDockEditorScreen
import com.mutx163.qingyu.pages.settings.GlassDockEditorState
import com.mutx163.qingyu.pages.settings.HomeMenuEditorScreen
import com.mutx163.qingyu.pages.settings.MiuixRowComponent
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsGlassDockEditorPage
import com.mutx163.qingyu.pages.settings.SettingsGroup
import com.mutx163.qingyu.pages.settings.SettingsHomeMenuEditorPage
import com.mutx163.qingyu.pages.settings.SettingsHomeMenuEditorState
import com.mutx163.qingyu.pages.settings.SettingsHomeNavigationPage
import com.mutx163.qingyu.pages.settings.SettingsNode
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageSpec
import com.mutx163.qingyu.pages.settings.SettingsRow
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.pages.settings.SettingsThemeManagePage
import com.mutx163.qingyu.pages.settings.SettingsStringsExt1
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.pages.settings.SettingsTimetablePageSettingsPage
import com.mutx163.qingyu.core.MiniJson
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.ui.platform.LocalContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Slider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDateTime
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
 * @param onIntent 其余界面意图的**覆盖实现**；不传（默认 `null`）走本宿主内置的消费端
 *   [handleIntent]（剪贴板导出/导入、保存主题对话框、已存主题动作表、重新配色说明）。
 *   壳只有在想自己接管这些弹层时才传——**默认值不再是空实现**（2026-10-29 补口）。
 * @param onRequestColor 选色：壳弹官方 `ColorPicker`，选完调 `commit(hex)`。
 *   不传 = 宿主自带的 RGB 弹窗（见 [SettingsColorPickerDialog]），不会静默。
 */
@Composable
fun SettingsHost(
    pageId: String,
    store: TimetableSettingsModelStore,
    onBack: (() -> Unit)? = null,
    onNavigate: (route: String) -> Unit = {},
    onIntent: ((SettingsDispatch) -> Unit)? = null,
    /** 传 null 时宿主自带一个 RGB 选色弹窗；壳想接官方选色器时再传实现。 */
    onRequestColor: ((rowId: String, currentHex: String, commit: (String) -> Unit) -> Unit)? = null,
    /** 顶部预览槽（课程卡片 / 课表页面两页的 4:6 分栏用）；null = 该页无预览。 */
    preview: (@Composable () -> Unit)? = null,
    /**
     * 「课表自动更新」的本地存储（通用页用）。
     *
     * `null` = 壳没接这份存储 ⇒ `general.autoRefresh.*` 整块不渲染（页面按
     * `autoRefresh == null` 判掉，与 Phase 3.5 第一刀行为一致，不崩）。
     * 真值来自另一个 prefs 键，不来自 [TimetableSettingsModel]——理由见
     * Dart `lib/services/course_auto_refresh_store.dart:9-18`。
     */
    autoRefreshStore: CourseAutoRefreshStore? = null,
    /**
     * 页面转场速度**当场生效**的回调（滑杆拖到哪，转场就立刻变到哪）。
     *
     * Dart 同口径：`settings_general.dart:74-80` 先 `applyUserTransitionSpeed(value)`
     * 再做 250ms 防抖落盘。这里只广播值，怎么缩放转场由壳决定。
     */
    onTransitionSpeedChanged: (Double) -> Unit = {},
    /** 应用内震动总开关的当场生效回调（壳据此决定还要不要发触感反馈）。 */
    onHapticsChanged: (Boolean) -> Unit = {},
) {
    var model by remember(store) { mutableStateOf(store.load()) }
    var pendingReset by remember { mutableStateOf<String?>(null) }
    var pendingColor by remember { mutableStateOf<ColorEdit?>(null) }
    var showDailyTimeSheet by remember { mutableStateOf(false) }
    var showRunNowNotice by remember { mutableStateOf(false) }
    /** 自动更新的配置（独立 prefs 键，不在 [TimetableSettingsModel] 里）。null = 没接。 */
    var schedule by remember(autoRefreshStore) { mutableStateOf(autoRefreshStore?.load()) }

    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    /**
     * 主题管理页的弹层状态（保存 / 重命名 / 删除确认 / 已存主题动作表）。
     *
     * 四种形态共用一个 sealed 层，弹层本体见文件末尾的 [SettingsThemeDialogHost]。
     * Dart 对应物：`_showSaveThemeDialog` / `_showRenameDialog` /
     * `showThemeDeleteConfirmDialog` / `showSavedThemeActionSheet`（`settings_appearance.dart:612-620`）。
     */
    var themeDialog by remember { mutableStateOf<ThemeDialogState?>(null) }

    /** 「能力还没接」的诚实说明框（重新配色等）；null = 不显示。 */
    var notice by remember { mutableStateOf<SettingsNotice?>(null) }

    /** 一次提示（Dart `showAppToast` / `showThemeFeedbackToast` 的对应物，宿主用系统 Toast）。 */
    fun toast(message: String) {
        if (message.isBlank()) return
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    // 「上次 X / 下次约 Y」两段标签（`course_auto_refresh_settings.dart:226-240`）。
    //
    // ⚠️ 必须包 `remember`：这个 store 是**无状态**的，`lastSuccessAt/nextRunAt`
    // 每次都真读盘（1 个 JSON + 2 个 long），直接写在重组路径里等于每帧读三次 prefs。
    // 键取 `schedule`（写回后它就是新对象）与 store 本身，改设置或换宿主才重算。
    val autoState = remember(schedule, autoRefreshStore) {
        schedule?.let { current ->
            SettingsPageBridge.toAutoRefreshState(
                enabled = current.enabled,
                modeValue = current.mode.serialName,
                intervalHours = current.intervalHours,
                dailyMinuteOfDay = current.dailyMinuteOfDay,
                lastSuccess = autoRefreshStore?.lastSuccessAt(),
                nextRun = autoRefreshStore?.nextRunAt(LocalDateTime.now()),
            )
        }
    }

    val state = SettingsPageBridge.toSettingsPageState(model, autoState)
    val spec = SettingsPageBridge.specFor(pageId, state) ?: return

    /**
     * 拖动类（滑杆）行：拖动中只改内存，**250ms 后才落一次盘**。
     *
     * Dart 同一策略（`settings_general.dart:109-126`：`Timer(250ms)` + 离开前 flush）。
     * 不做这一步时 `PrefsKeyValueStore.putString` 的 `commit()` 会被拖动回调**每 tick**
     * 在主线程上同步调一次（读-合并-序列化-落盘整套），既卡又放大写盘。
     */
    val sliderRowIds = remember(spec) {
        spec.rowsOnScreen()
            .filter { it.component == MiuixRowComponent.SLIDER }
            .map { it.id }
            .toSet()
    }
    val writer = remember(store) {
        DebouncedSettingsWriter(store, scope) {
            // 滑杆那一档没落盘：内存拉回盘上真值 + 提示（Dart `resetDraft` + `saveFailed`）。
            model = runCatching { store.load() }.getOrNull() ?: model
            Log.e(LOG_TAG, "debounced settings save did not land")
            toast(SettingsStringsExt2.saveFailed.zh)
        }
    }
    // 离开本页：把防抖里欠着的那一档补写掉（Dart `dispose()` 同口径）。
    DisposableEffect(writer) { onDispose { writer.flush() } }

    /** 转场速度 / 震动开关：**当场生效**，不等落盘（Dart 先广播再防抖落盘）。 */
    fun notifyRuntimePrefs(rowId: String, next: TimetableSettingsModel) {
        when (rowId) {
            SettingsActionDispatcher.ROW_TRANSITION_SPEED ->
                onTransitionSpeedChanged(next.pageTransitionSpeed)
            SettingsActionDispatcher.ROW_HAPTICS -> onHapticsChanged(next.enableHaptics)
            else -> Unit
        }
    }

    // 设置模型这条写路径只有一条：算新模型 → 落盘 → **读回校验** → 更新状态。
    //
    // 读回校验（2026-10-29 补口，一轮审核 P1）：`KeyValueStore.putX` 把
    // `SharedPreferences.commit()` 的返回值丢了（`PrefsKeyValueStore.kt:90-92`），
    // 所以「写盘失败」既不抛异常、也不返回 false —— 宿主原来那个
    // `runCatching { store.save(...) }.onFailure { notify }` 永远进不去。改成写完
    // 回读一遍、只比**本次改动过的键**：不一致 = 盘上还是旧值，此时把内存也拉回
    // 盘上的真值并提示（Dart `settings_general.dart:155-163` 的
    // `reportSettingsPersistFailure(resetDraft)` 同一语义：草稿回到存档真值）。
    fun commitModel(next: TimetableSettingsModel) {
        val before = model
        val persisted = saveVerified(store, before, next)
        model = if (persisted) next else runCatching { store.load() }.getOrNull() ?: before
        if (!persisted) {
            Log.e(LOG_TAG, "settings save did not land: page=$pageId")
            toast(SettingsStringsExt2.saveFailed.zh)
        }
    }

    // ================================================================ 意图消费端
    //
    // 2026-10-29 补口（一轮审核 P0）：`SHEET` / `DIALOG` / `CLIPBOARD_EXPORT` /
    // `CLIPBOARD_IMPORT` / `RECOLOR_SHEET` 以前全部落到 `onIntent`，而它的默认值是 `{}`、
    // 壳一处都没传 ⇒ 主题管理页四处 + 课卡「重新配色」**点了完全没反应**。
    // 现在默认值改成 `null`，不传就走下面这套内置实现；壳想自己接管时再传 `onIntent`。
    //
    // ⚠️ 顺序有讲究：这些是 `@Composable` 体内的**局部函数**，Kotlin 不允许前向引用，
    // 所以 `deliverIntent`（调用 `handleIntent`）必须排在 `handleIntent` **之后**。
    // 2026-10-29 L1 就因此红过一次（`Unresolved reference 'handleIntent'`）。

    fun clipboardManager(): ClipboardManager? =
        context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager

    /** 「导出主题」：当前设置 → 主题配置 JSON → 剪贴板（Dart `_exportTheme`，`:823-838`）。 */
    fun exportTheme() {
        val json = MiniJson.encode(SettingsActionDispatcher.themeConfigOf(model))
        val manager = clipboardManager()
        if (manager == null) {
            Log.e(LOG_TAG, "clipboard unavailable: export theme")
            toast(SettingsStringsExt2.saveFailed.zh)
            return
        }
        manager.setPrimaryClip(ClipData.newPlainText(CLIPBOARD_LABEL_THEME, json))
        toast(SettingsStrings.themeExportSuccess.zh)
    }

    /**
     * 「导入主题」：剪贴板 → 结构校验 → 写回 + 换检查点（Dart `_importTheme`，`:845-880`）。
     *
     * 三种失败都归到同一句 `themeImportFailed`（与 Dart 同口径）：剪贴板为空 / 不是 JSON 对象 /
     * v2 缺 `seed` 或 `ccl`。**不**部分应用——宁可一句「格式错误」，也不留半套主题。
     */
    fun importTheme() {
        val raw = clipboardManager()?.primaryClip
            ?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)
            ?.coerceToText(context)
            ?.toString()
        val parsed = raw?.let { MiniJson.tryParse(it) } as? Map<*, *>
        val config: Map<String, Any?>? = parsed
            ?.entries
            ?.mapNotNull { (key, value) -> (key as? String)?.let { it to value } }
            ?.toMap()
        if (config == null || !SettingsActionDispatcher.themeConfigIsUsable(config)) {
            toast(SettingsStrings.themeImportFailed.zh)
            return
        }
        // Dart 导入成功也把检查点换成这份配置
        // （`_applyThemeWithUndo(config, themeName: l10n.themeImport)`）。
        commitModel(
            SettingsActionDispatcher.applyThemeConfig(model, config).copy(
                themeCheckpointName = SettingsStrings.themeImport.zh,
                themeCheckpointConfig = config,
            ),
        )
        toast(SettingsStrings.themeImportSuccess.zh)
    }

    /** 已存主题的名字（行 id → 列表里的 name）；找不到返回空串。 */
    fun savedThemeName(id: String): String =
        model.savedThemes
            .firstOrNull { it[SettingsActionDispatcher.SAVED_THEME_KEY_ID] == id }
            ?.get(SettingsActionDispatcher.SAVED_THEME_KEY_NAME) as? String ?: ""

    /** 已存主题的四种动作（Dart `showSavedThemeActionSheet` + 四个 handler，`:612-700`）。 */
    fun runSavedThemeAction(action: ThemeRowAction, id: String) {
        val name = savedThemeName(id)
        when (action) {
            ThemeRowAction.APPLY -> {
                val previous = model
                val next = SettingsActionDispatcher.applySavedTheme(model, id)
                if (next == null) {
                    Log.w(LOG_TAG, "saved theme not found: $id")
                    return
                }
                commitModel(next)
                // Dart `_applyThemeWithUndo` 弹「已切换到 X + 撤销」；撤销在这里用同一个对话框承载。
                notice = SettingsNotice(
                    title = SettingsStrings.themeApply.zh,
                    body = SettingsStrings.themeChanged.filled("themeName", name),
                    undoLabel = SettingsStrings.themeUndo.zh,
                    onUndo = { commitModel(previous) },
                )
            }

            ThemeRowAction.RENAME ->
                themeDialog = ThemeDialogState(ThemeDialogMode.RENAME, id, name)

            ThemeRowAction.DUPLICATE -> {
                val next = SettingsActionDispatcher.duplicateSavedTheme(
                    model = model,
                    sourceId = id,
                    newId = themeEntryId(System.currentTimeMillis()),
                    newName = SettingsStrings.themeDuplicateCopyName.filled("name", name),
                    createdAtIso = LocalDateTime.now().toString(),
                )
                if (next == null) {
                    Log.w(LOG_TAG, "duplicate saved theme failed: $id")
                    return
                }
                commitModel(next)
            }

            ThemeRowAction.DELETE ->
                themeDialog = ThemeDialogState(ThemeDialogMode.DELETE, id, name)
        }
    }

    /** 内置意图消费：五种此前「意图被丢弃」的动作都在这里有落点。 */
    fun handleIntent(dispatch: SettingsDispatch) {
        when (dispatch) {
            is SettingsDispatch.ClipboardExport -> exportTheme()

            is SettingsDispatch.ClipboardImport -> importTheme()

            is SettingsDispatch.ShowDialog ->
                if (dispatch.rowId == SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE ||
                    dispatch.rowId == SettingsThemeManagePage.ROW_SAVE_CURRENT
                ) {
                    themeDialog = ThemeDialogState(ThemeDialogMode.SAVE_CURRENT)
                } else {
                    // 其它弹层不在本宿主范围：留痕 + 一句实话，不假装成功。
                    Log.w(LOG_TAG, "unhandled dialog: rowId=${dispatch.rowId}")
                    toast(SettingsStrings.aboutUnavailable.zh)
                }

            is SettingsDispatch.ShowSheet -> {
                val id = SettingsActionDispatcher.savedThemeIdOf(dispatch.rowId)
                if (id != null) {
                    themeDialog = ThemeDialogState(ThemeDialogMode.ACTIONS, id, savedThemeName(id))
                } else {
                    Log.w(LOG_TAG, "unhandled sheet: rowId=${dispatch.rowId}")
                    toast(SettingsStrings.aboutUnavailable.zh)
                }
            }

            // 课表重新配色：完整复刻要 Dart 那 479 行弹层 + 配色历史服务 + 调色板
            // （`lib/widgets/course_recolor_sheet.dart` / `course_recolor_history_service.dart`），
            // 属独立批次。这里**不假装能跑**：给一句「不可用」，而不是点了没反应。
            is SettingsDispatch.ShowRecolorSheet -> notice = SettingsNotice(
                title = SettingsStrings.courseRecolorTileTitle.zh,
                body = SettingsStrings.aboutUnavailable.zh,
            )

            is SettingsDispatch.Ignored -> Log.w(
                LOG_TAG,
                "ignored: rowId=${dispatch.rowId} target=${dispatch.target} reason=${dispatch.reason}",
            )

            // 这些在 onRowAction 里已就地处理（写 / 导航 / 恢复默认确认 / 选色器）。
            is SettingsDispatch.Write,
            is SettingsDispatch.Navigate,
            is SettingsDispatch.ShowColorPicker,
            is SettingsDispatch.ShowMaterialPanel,
            is SettingsDispatch.ConfirmReset,
            -> Unit

            is SettingsDispatch.RunNow -> Log.w(LOG_TAG, "unhandled run-now: rowId=${dispatch.rowId}")
        }
    }

    /**
     * 意图出口：壳传了 [onIntent] 就交给壳，没传就由本宿主消费（[handleIntent]）。
     *
     * 必须定义在 [handleIntent] 之后——本文件里的这些都是 `@Composable` 体内的局部函数，
     * Kotlin 不允许前向引用。
     */
    fun deliverIntent(dispatch: SettingsDispatch) {
        val override = onIntent
        if (override != null) override(dispatch) else handleIntent(dispatch)
    }

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
                notifyRuntimePrefs(rowId, result.model)
                if (rowId in sliderRowIds) {
                    // 拖动中只改内存，250ms 后一次落盘（落盘失败由 writer 回读后纠正）。
                    model = result.model
                    writer.schedule(result.model)
                } else {
                    // 先补写防抖里欠着的那一档，避免旧值后落地把新值盖回去。
                    writer.flush()
                    commitModel(result.model)
                }
            }
            else -> {
                // 「没写」也要留痕，再交给消费端（默认 [handleIntent]）。
                if (result is SettingsDispatch.Ignored) {
                    Log.w(
                        LOG_TAG,
                        "ignored setting write: rowId=${result.rowId} target=${result.target} " +
                            "reason=${result.reason}",
                    )
                }
                deliverIntent(result)
            }
        }
    }

    /** 恢复默认：**先确认**，确认后把该作用域写回并落盘（Dart 同口径）。 */
    fun applyReset(scope: String) {
        SettingsActionDispatcher.applyResetScope(model, scope)?.let { next ->
            writer.flush()
            commitModel(next)
        }
    }

    /** 「课表自动更新」那五行的写路径：改的是**另一个 prefs 键**，不是设置模型。 */
    fun commitAutoRefresh(target: String?, rowId: String) {
        val autoStore = autoRefreshStore ?: return
        val next = CourseAutoRefreshSettingsLogic.applyEdit(
            rowId = rowId,
            target = target,
            current = schedule ?: CourseAutoRefreshSchedule(),
        )
        if (next == null) {
            Log.w(LOG_TAG, "ignored auto-refresh edit: rowId=$rowId target=$target")
            return
        }
        if (autoStore.saveSchedule(next)) {
            schedule = next
        } else {
            // 落盘失败：屏上继续显示旧值（Dart 也是把草稿拉回存档真值再提示）。
            Log.e(LOG_TAG, "auto-refresh schedule save failed: rowId=$rowId")
        }
    }

    fun onRowAction(action: SettingsAction, target: String?, rowId: String) {
        // 自动更新那五行走独立存储，先拦掉，别让它们落到分派器的 Ignored 里。
        if (autoRefreshStore != null && rowId in AUTO_REFRESH_ROWS) {
            when (action) {
                SettingsAction.WRITE_SETTING -> commitAutoRefresh(target, rowId)
                SettingsAction.SHEET -> showDailyTimeSheet = true
                SettingsAction.RUN_NOW -> showRunNowNotice = true
                else -> Log.w(LOG_TAG, "unexpected auto-refresh action: rowId=$rowId action=$action")
            }
            return
        }
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
                    current == null -> deliverIntent(
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

            // 剪贴板 / 对话框 / 底部弹层 / 立刻更新等：壳接管则给壳，否则走内置消费端。
            else -> deliverIntent(
                SettingsActionDispatcher.dispatch(kind, target, rowId, model),
            )
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        SettingsPageScreen(
            spec = spec,
            preview = preview,
            onBack = onBack,
            // 行动作的落点全部在 [onRowAction]（自动更新那五行走独立存储，见其 KDoc）。
            onAction = ::onRowAction,
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

        // 「每天更新时刻」：官方 `NumberPicker` 两列滚轮（Dart 是同一个形态，见
        // `lib/widgets/miuix_time_picker_sheet.dart:8-20`：时/分双列滚轮 + 确认）。
        if (showDailyTimeSheet) {
            AutoRefreshDailyTimeSheet(
                initialMinute = schedule?.dailyMinuteOfDay
                    ?: CourseAutoRefreshModel.DEFAULT_DAILY_MINUTE,
                onDismiss = { showDailyTimeSheet = false },
                onConfirm = { minute ->
                    showDailyTimeSheet = false
                    val autoStore = autoRefreshStore
                    val current = schedule
                    if (autoStore != null && current != null) {
                        val next = current.copy(
                            dailyMinuteOfDay = CourseAutoRefreshModel.clampDailyMinute(minute),
                        )
                        if (autoStore.saveSchedule(next)) {
                            schedule = next
                        } else {
                            Log.e(LOG_TAG, "auto-refresh daily time save failed")
                        }
                    }
                },
            )
        }

        // 「立即试一次」：见 [AutoRefreshRunNowNotice] 的说明——执行器还没随壳迁移，
        // 这里至少给出**看得懂的反馈**，而不是点了没反应。
        if (showRunNowNotice) {
            AutoRefreshRunNowNotice(onDismiss = { showRunNowNotice = false })
        }

        // ---- 主题管理页的四类弹层（2026-10-29 补口：此前这四个动作**全无落点**）----
        themeDialog?.let { dialog ->
            SettingsThemeDialogHost(
                state = dialog,
                onDismiss = { themeDialog = null },
                onSaveCurrent = { name ->
                    themeDialog = null
                    val next = SettingsActionDispatcher.saveTheme(
                        model = model,
                        name = name,
                        id = themeEntryId(System.currentTimeMillis()),
                        createdAtIso = LocalDateTime.now().toString(),
                    )
                    if (next == null) {
                        // 名字为空：不写盘、不假装成功（确认按钮本来就是禁用的，这里再兜一层）。
                        Log.w(LOG_TAG, "save theme rejected: blank name")
                    } else {
                        commitModel(next)
                    }
                },
                onRename = { id, name ->
                    themeDialog = null
                    val next = SettingsActionDispatcher.renameSavedTheme(model, id, name)
                    if (next == null) {
                        Log.w(LOG_TAG, "rename theme failed: id=$id")
                        toast(SettingsStringsExt2.saveFailed.zh)
                    } else {
                        commitModel(next)
                    }
                },
                onDelete = { id ->
                    themeDialog = null
                    val deletedName = savedThemeName(id)
                    val next = SettingsActionDispatcher.deleteSavedTheme(model, id)
                    if (next == null) {
                        Log.w(LOG_TAG, "delete theme failed: id=$id")
                        toast(SettingsStringsExt2.saveFailed.zh)
                    } else {
                        // 删掉的正是「当前主题」那一份 ⇒ 检查点一起清掉，否则「当前主题」卡片
                        // 会指着一份已经不存在的存档（Dart 侧 `deleteTheme` 后也不会再选中它）。
                        val cleared = if (deletedName.isNotEmpty() &&
                            next.themeCheckpointName == deletedName
                        ) {
                            next.copy(themeCheckpointName = null, themeCheckpointConfig = null)
                        } else {
                            next
                        }
                        commitModel(cleared)
                    }
                },
                onAction = { action, id -> themeDialog = null; runSavedThemeAction(action, id) },
            )
        }

        notice?.let { current ->
            SettingsNoticeDialog(
                notice = current,
                onDismiss = { notice = null },
            )
        }
    }
}

/**
 * 摊平页面节点树，只收**行控件**（分组内的行按屏上顺序）。
 *
 * 为什么不复用测试里那个 `flatten()`：它在 `src/test` 下，生产代码引用不到。
 * 这里也不需要「所有节点」——宿主只关心哪些行是滑杆（拖动类，要防抖）。
 */
private fun SettingsPageSpec.rowsOnScreen(): List<SettingsRow> {
    val out = ArrayList<SettingsRow>()
    fun visit(node: SettingsNode) {
        when (node) {
            is SettingsRow -> out.add(node)
            is SettingsGroup -> node.children.forEach { visit(it) }
            else -> Unit
        }
    }
    nodes.forEach { visit(it) }
    return out
}

/** 通用页「课表自动更新」那五行的 rowId（与 `SettingsGeneralPage.autoRefreshRows` 一致）。 */private val AUTO_REFRESH_ROWS = setOf(
    CourseAutoRefreshSettingsLogic.ROW_SWITCH,
    CourseAutoRefreshSettingsLogic.ROW_MODE,
    CourseAutoRefreshSettingsLogic.ROW_INTERVAL,
    CourseAutoRefreshSettingsLogic.ROW_DAILY_TIME,
    CourseAutoRefreshSettingsLogic.ROW_TRY_NOW,
)

/** 日志标签：只进 logcat，不上屏（不上屏就不归 i18n 管）。 */
private const val LOG_TAG = "SettingsHost"

/**
 * 拖动类设置行的**防抖落盘**（Dart `settings_general.dart:109-126` 的 Kotlin 版）。
 *
 * 拖动中只更新内存，最后一次改动之后 [DEBOUNCE_MILLIS] 毫秒才 `save` 一次；
 * 离开页面时由宿主的 `DisposableEffect` 调 [flush] 补写，所以**不会丢最后一档**。
 *
 * 为什么非要做：`PrefsKeyValueStore.putString` 是 `commit()`（同步落盘），
 * 而滑杆的 `onValueChange` 每个像素都会回调一次 —— 不做防抖就是主线程上每帧
 * 一次「读-合并-序列化-写盘」。
 */
/**
 * 落盘 + **读回校验**：返回「这次改动真的进盘了」。
 *
 * 单一实现，宿主与本文件里另外三个（导航 / 两个编辑器）写路径共用——写盘失败时
 * 一律**不改内存模型**（界面停在旧值），不制造「看起来改了」的假象。
 */
private fun saveVerified(
    store: TimetableSettingsModelStore,
    before: TimetableSettingsModel,
    next: TimetableSettingsModel,
): Boolean {
    store.save(next)
    val disk = runCatching { store.load() }.getOrNull() ?: return false
    return SettingsActionDispatcher.persistLanded(before, next, disk)
}

private class DebouncedSettingsWriter(
    private val store: TimetableSettingsModelStore,
    private val scope: CoroutineScope,
    /**
     * 防抖那一档**写失败**时的回调（2026-10-29 补口）：
     * 宿主据此把内存模型拉回盘上真值并提示，与 Dart 的 `resetDraft` 同语义。
     */
    private val onWriteFailed: () -> Unit = {},
) {

    private var pending: TimetableSettingsModel? = null
    private var job: Job? = null

    /** 上一次成功落盘的模型；读回校验的「改动前」基准（null = 还没写过，flush 时现读盘）。 */
    private var lastLanded: TimetableSettingsModel? = null

    fun schedule(next: TimetableSettingsModel) {
        pending = next
        job?.cancel()
        job = scope.launch {
            delay(DEBOUNCE_MILLIS)
            flush()
        }
    }

    fun flush() {
        job?.cancel()
        job = null
        val next = pending ?: return
        pending = null
        val before = lastLanded ?: store.load()
        if (saveVerified(store, before, next)) {
            lastLanded = next
        } else {
            onWriteFailed()
        }
    }

    companion object {
        /** Dart 侧同一个数（`settings_general.dart:116` 的 `Duration(milliseconds: 250)`）。 */
        const val DEBOUNCE_MILLIS: Long = 250L
    }
}

/**
 * 「每天更新时刻」弹层：时 / 分两列官方 `NumberPicker` + 取消 / 确认。
 *
 * 形态逐条照 Dart `showMiuixTimePickerSheet`（`lib/widgets/miuix_time_picker_sheet.dart`）：
 * 底部 sheet、24 小时制、时 0..23 与分 0..59 各一个滚轮、两列都补零。
 */
@Composable
private fun AutoRefreshDailyTimeSheet(
    initialMinute: Int,
    onDismiss: () -> Unit,
    onConfirm: (Int) -> Unit,
) {
    val initial = CourseAutoRefreshModel.clampDailyMinute(initialMinute)
    var hour by remember(initial) { mutableIntStateOf(initial / 60) }
    var minute by remember(initial) { mutableIntStateOf(initial % 60) }

    QingyuSheet(
        show = true,
        title = SettingsStrings.courseAutoRefreshDailyTimeTitle.zh,
        // 内容根是 `Column(padding(horizontal = 16.dp))` ⇒ 框架侧横向归零，单边仍是 16
        //（不然 24 + 16 = 40）。
        contentPadsHorizontally = true,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = hour,
                    onValueChange = { hour = it },
                    range = 0..23,
                    wrapAround = true,
                    label = { "%02d".format(Locale.ROOT, it) },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = minute,
                    onValueChange = { minute = it },
                    range = 0..59,
                    wrapAround = true,
                    label = { "%02d".format(Locale.ROOT, it) },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = SettingsStringsExt4.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(hour * 60 + minute) },
                ) {
                    Text(text = SettingsStrings.confirmAction.zh)
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/**
 * 「立即试一次」的反馈弹窗。
 *
 * ## 为什么这里没有「真的跑一次」
 *
 * Dart 那一侧是 `runCourseAutoRefreshNow` → `runHomePullWarehouseQuickImport`：用一个
 * 隐形 WebView 回放**用户录好的教务快捷导入宏**，再比课表内容指纹判断有没有更新
 * （`lib/screens/import/course_auto_refresh_runner.dart:104-125`）。
 *
 * Compose 壳里这条链路的三个前提件都还没有：
 * 1. 没有后台导入执行器（`WarehouseWebViewHost` 只存在于登录页内部）；
 * 2. 登录页本身是演练壳（`ShellPageIndex` 里喂的是 `example.com` 演示地址）；
 * 3. 没有宏记录的存储格式（Dart 的 `warehouse_macro_record_*` 在 `android/` 下 0 命中）。
 *
 * 所以这里**不假装能跑**：点下去给一句实话（正文取 ARB 已有的 `aboutUnavailable`，
 * 标题就是「立即试一次」）。开关/档位/时刻这些是真的写盘的，执行器一到位就能跑。
 */
@Composable
private fun AutoRefreshRunNowNotice(onDismiss: () -> Unit) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = true,
        title = SettingsStrings.courseAutoRefreshTryNowTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = SettingsStrings.aboutUnavailable.zh,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                Button(onClick = onDismiss) {
                    Text(text = SettingsStrings.confirmAction.zh)
                }
            }
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
        // 与 SettingsHost 同一条写路径：写完读回校验，没落盘就不改内存（界面停在旧值）。
        if (saveVerified(store, model, newModel)) {
            model = newModel
        } else {
            Log.e(LOG_TAG, "home navigation save did not land")
        }
    }
    val state = SettingsPageBridge.toHomeNavigationState(model)
    SettingsPageScreen(
        spec = SettingsHomeNavigationPage.spec(state),
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (val kind = SettingsPageBridge.toKind(action)) {
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

                // 「没写 / 没导航」也要留痕：静默分支排查时什么都看不到（与 SettingsHost 同口径）。
                else -> Log.w(LOG_TAG, "unhandled home-navigation action: $kind rowId=$rowId")
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
                if (saveVerified(store, model, result.model)) {
                    model = result.model
                } else {
                    Log.e(LOG_TAG, "timetable page settings save did not land")
                }
            }
            else -> Unit
        }
    }

    SettingsPageScreen(
        spec = SettingsTimetablePageSettingsPage.spec(SettingsPageBridge.toTimetablePageState(model)),
        preview = preview,
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (val kind = SettingsPageBridge.toKind(action)) {
                SettingsActionKind.WRITE_SETTING -> commitWrite(target, rowId)
                SettingsActionKind.NAVIGATE -> target?.let(onNavigate)
                // 本页当前没有弹层/剪贴板行；真出现时留痕，别让「点了没反应」无从查起。
                else -> Log.w(LOG_TAG, "unhandled timetable-page action: $kind rowId=$rowId")
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
            if (saveVerified(store, model, result.model)) {
                model = result.model
            } else {
                Log.e(LOG_TAG, "glass dock editor save did not land")
            }
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
            if (saveVerified(store, model, result.model)) {
                model = result.model
            } else {
                Log.e(LOG_TAG, "home menu editor save did not land")
            }
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

// ============================================================================
// 主题管理页的四类弹层 + 「能力未接」说明框 + 落盘读回校验
// （2026-10-29 补口，一轮审核 P0/P1；此前这四类动作的意图对象全仓 0 消费者）
// ============================================================================

/** 剪贴板里主题 JSON 的标签（Android 10+ 会在系统提示里显示它，属于系统 UI 我们的部分）。 */
private const val CLIPBOARD_LABEL_THEME = "qingyu-theme"

/** 主题条目的 id：Dart `DateTime.now().millisecondsSinceEpoch.toString()`（`timetable_theme_service.dart:73`）。 */
internal fun themeEntryId(epochMillis: Long): String = epochMillis.toString()

/** 主题弹层的四种形态（Dart 那边是四个独立函数）。 */
internal enum class ThemeDialogMode {
    /** 「保存当前主题」：输入名字 → 追加一条已存主题（Dart `_showSaveThemeDialog`）。 */
    SAVE_CURRENT,

    /** 重命名（Dart `_showRenameDialog`）。 */
    RENAME,

    /** 删除确认（Dart `showThemeDeleteConfirmDialog`）。 */
    DELETE,

    /** 已存主题的动作表：应用 / 重命名 / 复制 / 删除（Dart `showSavedThemeActionSheet`）。 */
    ACTIONS,
}

/** 已存主题动作表里的四项。 */
internal enum class ThemeRowAction { APPLY, RENAME, DUPLICATE, DELETE }

internal data class ThemeDialogState(
    val mode: ThemeDialogMode,
    /** 目标已存主题 id；`SAVE_CURRENT` 时为 null。 */
    val themeId: String? = null,
    /** 已存主题的名字（弹层标题/删除正文要用）。 */
    val themeName: String = "",
)

/**
 * 一个「说明框」：标题 + 正文 +（可选）撤销按钮。
 *
 * 三种用法：能力未接的诚实说明（重新配色）、应用主题后的「已切换到 X + 撤销」。
 */
internal data class SettingsNotice(
    val title: String,
    val body: String,
    val undoLabel: String? = null,
    val onUndo: (() -> Unit)? = null,
)

/**
 * 主题管理页的弹层宿主：把 [ThemeDialogState] 四种形态渲染成官方弹层。
 *
 * 形态逐条照 Dart（`settings_appearance.dart` + `lib/widgets/theme_manage_sheets.dart`）：
 * 保存/重命名 = 单行输入框 + 取消/确认（名字为空时确认禁用，不给「存了个空名」的机会）；
 * 删除 = 确认框（`themeDeleteConfirmMessage` 带主题名）；
 * 动作表 = 底部四行（应用 / 重命名 / 复制 / 删除）。
 */
@Composable
internal fun SettingsThemeDialogHost(
    state: ThemeDialogState,
    onDismiss: () -> Unit,
    onSaveCurrent: (name: String) -> Unit,
    onRename: (id: String, name: String) -> Unit,
    onDelete: (id: String) -> Unit,
    onAction: (ThemeRowAction, id: String) -> Unit,
) {
    when (state.mode) {
        ThemeDialogMode.SAVE_CURRENT, ThemeDialogMode.RENAME -> {
            val initial = if (state.mode == ThemeDialogMode.RENAME) state.themeName else ""
            var text by remember(state) { mutableStateOf(initial) }
            OverlayDialog(
                insideMargin = DpSize(16.dp, 16.dp),
                show = true,
                title = if (state.mode == ThemeDialogMode.RENAME) {
                    SettingsStrings.themeRename.zh
                } else {
                    SettingsStrings.themeSaveCurrent.zh
                },
                onDismissRequest = onDismiss,
            ) {
                TextField(
                    value = text,
                    onValueChange = { text = it },
                    label = SettingsStrings.themeNameHint.zh,
                    useLabelAsPlaceholder = true,
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp),
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = SettingsStringsExt4.cancelAction.zh,
                        onClick = onDismiss,
                    )
                    Button(
                        modifier = Modifier.weight(1f),
                        // 空名字点不动：Dart 的保存对话框同样不给提交空名。
                        enabled = text.isNotBlank(),
                        onClick = {
                            val id = state.themeId
                            if (state.mode == ThemeDialogMode.RENAME && id != null) {
                                onRename(id, text)
                            } else {
                                onSaveCurrent(text)
                            }
                        },
                    ) {
                        Text(text = SettingsStrings.confirmAction.zh)
                    }
                }
            }
        }

        ThemeDialogMode.DELETE -> OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = true,
            title = SettingsStrings.themeDelete.zh,
            summary = SettingsStrings.themeDeleteConfirmMessage.filled("name", state.themeName),
            onDismissRequest = onDismiss,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = SettingsStringsExt4.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { state.themeId?.let(onDelete) },
                ) {
                    Text(text = SettingsStrings.themeDelete.zh)
                }
            }
        }

        // 内容根是 `Column(padding(horizontal = 16.dp, …))` ⇒ 框架侧横向归零（单边仍是 16）。
        ThemeDialogMode.ACTIONS -> QingyuSheet(
            show = true,
            // 标题是用户数据（主题名），不来自 ARB。
            title = state.themeName,
            contentPadsHorizontally = true,
            onDismissRequest = onDismiss,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ThemeActionRow(SettingsStrings.themeApply.zh) {
                    state.themeId?.let { onAction(ThemeRowAction.APPLY, it) }
                }
                ThemeActionRow(SettingsStrings.themeRename.zh) {
                    state.themeId?.let { onAction(ThemeRowAction.RENAME, it) }
                }
                ThemeActionRow(SettingsStrings.themeDuplicate.zh) {
                    state.themeId?.let { onAction(ThemeRowAction.DUPLICATE, it) }
                }
                ThemeActionRow(SettingsStrings.themeDelete.zh) {
                    state.themeId?.let { onAction(ThemeRowAction.DELETE, it) }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun ThemeActionRow(label: String, onClick: () -> Unit) {
    Button(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Text(text = label, style = MiuixTheme.textStyles.button)
    }
}

/**
 * 「说明框」：标题 + 正文，可选一个撤销按钮。
 *
 * 与 [AutoRefreshRunNowNotice] 同一套（`OverlayDialog` + 正文取 ARB），
 * 区别只在多了 [SettingsNotice.onUndo] 这条撤销通路。
 */
@Composable
private fun SettingsNoticeDialog(notice: SettingsNotice, onDismiss: () -> Unit) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = true,
        title = notice.title,
        onDismissRequest = onDismiss,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = notice.body,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                val undo = notice.onUndo
                val undoLabel = notice.undoLabel
                if (undo != null && undoLabel != null) {
                    TextButton(
                        text = undoLabel,
                        onClick = {
                            undo()
                            onDismiss()
                        },
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Button(onClick = onDismiss) {
                    Text(text = SettingsStrings.confirmAction.zh)
                }
            }
        }
    }
}
