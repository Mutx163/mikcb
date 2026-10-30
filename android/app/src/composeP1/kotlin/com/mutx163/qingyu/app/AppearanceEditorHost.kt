package com.mutx163.qingyu.app

import android.util.Log
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.pages.settings.AppearanceEditorBridge
import com.mutx163.qingyu.pages.settings.AppearanceEditorPreviewStrings
import com.mutx163.qingyu.pages.settings.AppearanceEditorScreen
import com.mutx163.qingyu.pages.settings.MaterialSheetBody
import com.mutx163.qingyu.pages.settings.MaterialSheetPages
import com.mutx163.qingyu.pages.settings.SelectionPageState
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.WallpaperSheetBody
import com.mutx163.qingyu.pages.settings.WallpaperSheetPages
import com.mutx163.qingyu.pages.settings.backdropFlowState
import com.mutx163.qingyu.pages.settings.wallpaperSheetBottomGap
import com.mutx163.qingyu.pages.timetable.day.DayAgendaEntry
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.DayViewPageData
import com.mutx163.qingyu.pages.timetable.day.DayViewSummaryLogic
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate

/**
 * 外观编辑页的**宿主**：草稿 / 落盘 / 取消回滚 / 两个底部面板 / 真课表页预览。
 *
 * Dart 原件：`lib/screens/settings/settings_appearance_editor.dart`（本类注释里所有
 * `:数字` 都是它的行号）。页面壳与几何在
 * `pages/settings/AppearanceEditorScreen.kt`，上下 chrome 在
 * `pages/settings/AppearanceEditorChrome.kt`。
 *
 * ## 编辑语义（`:729-740`、`:672-675`）
 *
 * * 本页与其它设置页一样**即时落盘**：面板里改一下，预览与磁盘同时变；
 * * 「完成」= 直接返回（改动已落盘）；
 * * 「取消」= 把**进页那一刻的整份设置写回**再返回。不是「什么都不做」——因为改动
 *   早就落盘了，不做回滚的话按钮名与行为不符；
 * * 系统返回 = 取消（`BackHandler` 只在两个面板都关着时接管；面板开着时交给官方
 *   `OverlayBottomSheet` 自己关）。
 *
 * ## 落盘节奏（`:622-631`）
 *
 * Dart 对滑杆给了 250ms 防抖、其余控件立即写。这里照做：滑杆行
 * （材质那三组八根旋钮、壁纸模糊）走 [APPEARANCE_EDITOR_SAVE_DEBOUNCE_MS] 防抖，
 * 其余立即写。**内存里的草稿永远立刻更新**（预览不延迟），防抖只影响写盘。
 * 离开本页 / 关面板时会把欠着的那一档补写掉，不会丢最后一格。
 *
 * ## 两个面板（`:777-919`）
 *
 * 两块面板都走共享套件 [QingyuSheet]（不是裸 `OverlayBottomSheet`）：左右 16 的内缩与
 * 底部「手势区 + 16」的让位口径由套件统一给，两个面板的数字不会各走各的。
 * 面板内容最多占屏高 **50%**（Dart `_materialSheetMaxHeightFactor = 0.5`，`:116-120`；
 * 壁纸面板同口径，`:839-841`），超出部分由面板内部自己滚——面板存在的意义就是
 * 「改一处、看预览」，长高到盖住卡片就失去意义了。
 *
 * 面板打开期间上下 chrome **保持常显、位置不动**（2026-09-19 口径，`:780-782`）：
 * 它们是页面那一层的常驻子节点，弹层的遮罩只会把它们压暗、接走点击。
 *
 * ## 预览（`:1761-1783`）
 *
 * * 周：直接复用 [TimetableHost]（它内部就是 `TimetableWeekPage` 的逐参喂法：时间模板、
 *   显示偏好、风格映射、考试/日程、标题样式与菜单）；
 * * 日：`DayViewPage`，喂参与壳的「日视图」页（`ShellPageIndex` 的 `c3.day`）逐字同形。
 *
 * 两者都读**草稿** `model`（不是盘上那份），于是面板里拖滑杆、切日/周、改材质都能
 * 立刻反映到卡片上。点击在页面壳那一层就被全部吃掉，这里传的回调永远不会被调用，
 * 所以一律给空实现——预览不是第二个可操作的课表页。
 *
 * ## 已知差异（照实写，不糊）
 *
 * 1. **加载罩不进树**：Dart 的罩子是给「烤图要等」用的（`:277-301`）。本仓预览是活树、
 *    首帧就有内容，所以这里传 `previewReady = true`。页面那一侧的三态门与 6 秒兜底
 *    都实现了，将来预览改成异步图源时把这里换成真实就绪信号即可；
 * 2. **落盘失败只记日志**：Dart 走 `reportSettingsPersistFailure` 弹轻提示（`:656-664`），
 *    壳里目前没有轻提示宿主，这里 `Log.e` 留痕，草稿仍留在内存里（不静默回滚）；
 * 3. **「最近使用」缩略图条还没有渲染层**：`SettingsPageRenderers.ControlCard` 目前只画
 *    `texts` 里的按钮、不画 `colors` 里的壁纸键（属于壁纸面板/渲染层的活）。所以
 *    [SelectionPageState.armedKey] 现在恒为 null，本宿主不伪造一个走不通的移除确认流程；
 * 4. **预览里没有壳的玻璃底栏**：Dart 的缩尺卡是「整个首页」，含底部坞；Kotlin 的玻璃
 *    底栏由壳（`PagesShellActivity`）画、不在页面层，所以 `TimetableHost` 这份预览只到
 *    课表页本身，顶部菜单条目也按空列表渲染。等底栏/菜单搬进共享渲染层后，预览要跟着
 *    补上（否则卡片比真实首页少一条底栏）。
 *
 * @param store 设置模型读写（壳里 `wiring.settingsModel`）；与课表仓储共用同一个
 *   `timetable_settings` 键、各自合并写，互不覆盖。
 * @param repository 课表仓储：预览要它的课表/考试/日程与当前周。
 * @param onBack 返回（本页已落盘或已回滚）。
 * @param onNavigate 面板里 `NAVIGATE` 动作的路由（如「调整位置」「每日壁纸」），由壳映射成页面 id。
 * @param onIntent 本宿主不自己处理的界面意图（`SHEET` / `DIALOG` / 剪贴板 / `RUN_NOW` …），
 *   原样转给壳；壳不接也只是 no-op，不会崩。
 * @param initialMaterialPage 非空时**进页后自动打开材质面板并停在该页**
 *   （`0` = 通用、`1` = 课程卡片）。Dart 用它做「课程卡片设置 → 卡片外观」的直达
 *   （`:78-88`、`:243-247`、`:403-410`）。
 * @param initialWallpaperPage 与 [initialMaterialPage] 同语义，但打开的是**壁纸面板**
 *   （`0` = 壁纸 / `1` = 设置，见 [WallpaperSheetPages]）。「课表页面」设置里的壁纸入口
 *   与「最近使用」都是这块面板的页签、不是独立页面，所以它们也落到本宿主。
 *   两个 `initial*` 同时非空时**以材质优先**（只有一块弹层的位置，不能叠着开）。
 */
@Composable
fun AppearanceEditorHost(
    store: TimetableSettingsModelStore,
    repository: TimetableRepository,
    onBack: () -> Unit,
    onNavigate: (route: String) -> Unit = {},
    onIntent: (SettingsDispatch) -> Unit = {},
    initialMaterialPage: Int? = null,
    initialWallpaperPage: Int? = null,
) {
    // 草稿：一进页就从盘上读一份；`openedWith` 是「取消」要回滚到的那份快照（`:179-182`）。
    var model by remember(store) { mutableStateOf(store.load()) }
    val openedWith = remember(store) { model }
    // 面板要读的值全部从设置模型推出来（逐键同源在 AppearanceEditorBridge，单测在那边）。
    val appearance = remember(model) { AppearanceEditorBridge.toState(model) }

    var materialSheet by remember { mutableStateOf(false) }
    var materialInitialPageIndex by remember { mutableIntStateOf(MaterialSheetPages.GENERAL) }
    var wallpaperSheet by remember { mutableStateOf(false) }
    var wallpaperInitialPageIndex by remember { mutableIntStateOf(WallpaperSheetPages.PICKER) }

    // 欠写的那一档 + 防抖任务（见类注释「落盘节奏」）。
    var pendingSave by remember { mutableStateOf<TimetableSettingsModel?>(null) }
    var saveJob by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()

    fun flushPendingSave() {
        val next = pendingSave ?: return
        pendingSave = null
        // 合并写：只覆盖本模型拥有的键，不会顺手改掉课表仓储那份 core 4 键。
        runCatching { store.save(next) }
            .onFailure { Log.e(LOG_TAG, "appearance editor save failed, draft kept in memory", it) }
    }

    fun persistNow() {
        saveJob?.cancel()
        saveJob = null
        flushPendingSave()
    }

    fun commit(next: TimetableSettingsModel, debounce: Boolean) {
        // ✱ 先更新内存草稿：预览与控件必须当场跟着变，不等写盘。
        model = next
        pendingSave = next
        if (!debounce) {
            persistNow()
            return
        }
        saveJob?.cancel()
        saveJob = scope.launch {
            delay(APPEARANCE_EDITOR_SAVE_DEBOUNCE_MS)
            flushPendingSave()
        }
    }

    /** 取消：回滚到进页快照再返回（`:735-740`）。 */
    fun cancel() {
        // 先把欠着的最后一档写掉，再整份覆盖成进页那份；顺序反了会让防抖里那一档后落地。
        persistNow()
        if (model != openedWith) {
            model = openedWith
            runCatching { store.save(openedWith) }
                .onFailure { Log.e(LOG_TAG, "appearance editor rollback save failed", it) }
        }
        onBack()
    }

    /** 完成：保留改动并返回（`:672-675`）。 */
    fun done() {
        persistNow()
        onBack()
    }

    /**
     * 面板里的一行被操作。
     *
     * 页面层只把 `(action, target, rowId)` 原样转出来，**「改哪个字段」的判据在
     * [SettingsActionDispatcher]**（与设置族其余页共用同一份），本宿主只负责
     * 「算出来的新模型 → 落盘 + 重组」和「界面意图 → 壳」。
     */
    fun handleAction(action: SettingsAction, target: String?, rowId: String) {
        val dispatch = SettingsActionDispatcher.dispatch(
            kind = SettingsPageBridge.toKind(action),
            target = target,
            rowId = rowId,
            model = model,
        )
        when (dispatch) {
            is SettingsDispatch.Write ->
                commit(dispatch.model, debounce = isDebouncedSliderRow(rowId))

            // 面板里的「恢复默认」：液态玻璃那一档在 Dart 里**不走确认**，就是一次
            // `copyWith(preset = standard, tuning = defaults)`（`:1062-1070`），所以本地直接应用；
            // 其它作用域（外观 / 课表卡片）本来要二次确认，交给壳弹确认框。
            is SettingsDispatch.ConfirmReset -> {
                val reset = SettingsActionDispatcher.applyResetScope(model, dispatch.scope)
                if (reset != null) {
                    commit(reset, debounce = false)
                } else {
                    onIntent(dispatch)
                }
            }

            is SettingsDispatch.Navigate -> {
                // 推页前先把欠着的写掉：新页读的是盘上那份设置。
                persistNow()
                onNavigate(dispatch.route)
            }

            // no-op 也要留痕：壳没接的地方以前是彻底静默的，排查时什么都看不到。
            is SettingsDispatch.Ignored -> Log.w(
                LOG_TAG,
                "appearance editor ignored dispatch: rowId=${dispatch.rowId} " +
                    "target=${dispatch.target} reason=${dispatch.reason}",
            )

            // ShowSheet / ShowDialog / ShowColorPicker / ShowMaterialPanel / ShowRecolorSheet /
            // ClipboardExport / ClipboardImport / RunNow：本宿主不实现，交给壳。
            else -> onIntent(dispatch)
        }
    }

    // 离开本页时补写最后那档（`:586-592` 同一件事：防抖未到期不能丢）。
    DisposableEffect(Unit) {
        onDispose { persistNow() }
    }

    // 系统返回 = 取消。面板开着时**不接管**：那一下应该先关面板（Dart 的 `_popSelf`
    // 也是先摘弹层再摘自己，`:702-727`）。
    BackHandler(enabled = !materialSheet && !wallpaperSheet) { cancel() }

    // 深链接：进页后自动打开面板并停在指定页（Dart 等转场落定才开，`:243-247`；
    // Compose 这里首帧之后开等价，面板本来就是根覆盖层条目、不参与页面转场）。
    //
    // 两块面板**互斥**：一块弹层一个位置，两个 initial* 同时非空时以材质优先（防守写法，
    // 正常调用不会同时给两个）。
    LaunchedEffect(initialMaterialPage, initialWallpaperPage) {
        val materialPage = initialMaterialPage
        val wallpaperPage = initialWallpaperPage
        when {
            materialPage != null -> {
                materialInitialPageIndex = materialPage.coerceIn(0, MaterialSheetPages.COUNT - 1)
                wallpaperSheet = false
                materialSheet = true
            }

            wallpaperPage != null -> {
                wallpaperInitialPageIndex =
                    wallpaperPage.coerceIn(0, WallpaperSheetPages.COUNT - 1)
                materialSheet = false
                wallpaperSheet = true
            }
        }
    }

    AppearanceEditorScreen(
        // 初值跟首页当前视图走（Dart `:203-204`）：三者一致，进页那一帧才不会闪跳。
        initialDayView = appearance.previewDayView,
        onCancel = { cancel() },
        onDone = { done() },
        onAdjustWallpaper = {
            // 底部圆钮永远从「壁纸」那页开（Dart `_openWallpaperSheet` 不带页参数，`:777-807`）。
            wallpaperInitialPageIndex = WallpaperSheetPages.PICKER
            materialSheet = false
            wallpaperSheet = true
        },
        onMaterial = {
            materialInitialPageIndex = MaterialSheetPages.GENERAL
            wallpaperSheet = false
            materialSheet = true
        },
        // 见类注释「已知差异」第 1 条。
        previewReady = true,
        preview = { dayView ->
            TimetablePreviewPage(
                dayView = dayView,
                repository = repository,
                settingsModel = model,
            )
        },
    )

    QingyuSheet(
        show = materialSheet,
        // 不传 title：面板正文顶上那行「通用 / 课程卡片」翻页胶囊**就是**标题
        // （MaterialSheetBody 的 KDoc 同一条口径）。
        //
        // 左右内缩不再在这里传：miuix 默认 24、Dart 口径 16（`hyperosMiuixBottomSheetInsideMargin`），
        // 这个差由 [QingyuSheet] 统一给（内容自己没有横向内边距 ⇒ 走默认 `false`，
        // 框架侧给 16）。同样，底部「手势区 + 16」也由正文自己带
        // （`MaterialSheetBody` 内部算，Dart `scrollableBottomGap`），这里不要另垫。
        onDismissRequest = { materialSheet = false },
        // ⚠️ 正文里有**自己的**滚动（`HorizontalPager` + 每页一个 `SettingsNodeList`），
        // 而且 pager 带 `weight(1f)`：套件若再套 `verticalScroll` 就是嵌套滚动（weight 在
        // 无穷高约束里直接崩）。所以必须 `contentScrolls = true`。
        contentScrolls = true,
        // 面板内容最多占屏高 50%（Dart `_materialSheetMaxHeightFactor = 0.5`，`:116-120`）。
        // 以前是在调用点算 `screenHeightDp * 0.5`，现在照原值交给套件（`:839-841` 壁纸面板同口径）。
        maxHeightFraction = APPEARANCE_EDITOR_SHEET_MAX_HEIGHT_FACTOR,
    ) {
        MaterialSheetBody(
            state = appearance,
            onAction = { action, target, rowId -> handleAction(action, target, rowId) },
            // ⚠️ 不要传 `bottom = 24.dp`：面板底部留白是「手势区 + 16」且由滚动内容自带
            // （Dart `scrollableBottomGap: true`，见 `settings_appearance_editor.dart:890-894`），
            // 再叠一层 24 就是「手势区 + 40」。
            contentPadding = PaddingValues(),
            initialPage = materialInitialPageIndex,
        )
    }

    QingyuSheet(
        show = wallpaperSheet,
        // 内缩口径同材质面板（两个弹层的数字必须一致，否则并排看会一宽一窄）——
        // 两者都交给 [QingyuSheet] 默认那 16。
        onDismissRequest = { wallpaperSheet = false },
        // 同材质面板：壁纸面板正文也是 pager + 每页列表，`weight(1f)` 带自己的滚动。
        contentScrolls = true,
        maxHeightFraction = APPEARANCE_EDITOR_SHEET_MAX_HEIGHT_FACTOR,
    ) {
        WallpaperSheetBody(
            state = appearance,
            onAction = { action, target, rowId -> handleAction(action, target, rowId) },
            // 「最近使用」的选择态：壁纸键集合与当前壁纸都从同一份状态推出来；
            // `armedKey`（移除确认）属于缩略图条自己的界面态，见类注释「已知差异」第 3 条。
            selection = SelectionPageState(backdrop = backdropFlowState(appearance)),
            // 底部留白由**滚动内容**自己带（Dart `scrollableBottomGap`：系统手势区 + 16，
            // `miui_bottom_sheet.dart:448-458`）。宿主不垫：垫在视口外面会让内容永远滚不进去。
            contentPadding = wallpaperSheetBottomGap(),
            initialPage = wallpaperInitialPageIndex,
        )
    }
}

/**
 * 卡片里那份**真课表页**：周 = [TimetableHost]（内部即 `TimetableWeekPage` 的逐参喂法），
 * 日 = [DayViewPage]。
 *
 * 为什么周视图不自己再抄一份 `TimetableWeekPage(...)` 的参数：那份喂法已经在
 * [TimetableHost] 里（设置 → 风格的映射、时间模板解析、当前周钳制、考试/日程、标题与
 * 菜单样式），抄第二份的唯一结果是两边迟早漂。日视图在壳里也只有一处喂法
 * （`ShellPageIndex` 的 `c3.day`），这里与它逐字同形。
 *
 * 预览读的是**草稿** [settingsModel] ⇒ 面板里改材质/显示偏好，卡片当场跟着变。
 */
@Composable
private fun TimetablePreviewPage(
    dayView: Boolean,
    repository: TimetableRepository,
    settingsModel: TimetableSettingsModel,
) {
    if (!dayView) {
        TimetableHost(
            repository = repository,
            // 点击在页面壳那一层就被全部吞掉（`Modifier.consumeAllPointerEvents`），
            // 这两个回调永远不会被调用；给空实现是为了让「预览不可操作」这件事只有一处真源。
            onOpenAddCourse = { _, _ -> },
            onOpenCourse = {},
            settingsModel = settingsModel,
        )
        return
    }

    // 日视图要的是一份快照（周视图那份订阅在 TimetableHost 内部）。先读当前值再订阅，
    // 与仓储的通知语义一致：`observe` 只推后续变更，不会补推当前值。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }
    val display = remember(settingsModel) { TimetableHostDisplayPrefs.fromSettings(settingsModel) }
    val visibleDays = remember(display.hideWeekends) {
        TimetableHostLogic.visibleDayNumbers(display.hideWeekends)
    }
    // 「看哪一天」取持久化的上次浏览日（Dart `_previewDayOfWeekNotifier`，`:208-210`），
    // 不取今天：首页日视图看的也是那一天，两边一致才不会在卡片里跳一天。
    // 隐藏周末时那个日子可能不在可见列里（例如上次看周六），此时退到可见的第一天，
    // 否则日视图的页号与「第几周 · 周几」会对不上。
    val lastViewedDay = settingsModel.timetableLastViewedDayOfWeek.coerceIn(1, 7)
    val initialDayOfWeek = if (lastViewedDay in visibleDays) lastViewedDay else visibleDays.first()
    val today = LocalDate.now()
    val todayOfWeek = today.dayOfWeek.value

    DayViewPage(
        initialWeek = snapshot.currentWeek.coerceAtLeast(1),
        initialDayOfWeek = initialDayOfWeek,
        visibleDays = visibleDays,
        totalWeeks = snapshot.settings.semesterWeekCount,
        dataProvider = { week, dayOfWeek ->
            // 与壳的日视图页同一套数据形状（`ShellPageIndex` 的 `c3.day`）：课程按周过滤、
            // 日程/考试那几块在壳里也还没接，预览保持同形。
            val dayCourses = snapshot.courses.filter { course ->
                course.dayOfWeek == dayOfWeek && course.isActiveInWeek(week)
            }
            DayViewPageData(
                summaryState = DayViewSummaryLogic.buildSummaryState(
                    week = week,
                    dateLabel = AppearanceEditorPreviewStrings.dayLabel(week, dayOfWeek),
                    isToday = week == snapshot.currentWeek && dayOfWeek == todayOfWeek,
                    courseCount = dayCourses.size,
                    scheduleCount = 0,
                ),
                agendaEntries = dayCourses.map { course ->
                    DayAgendaEntry.CourseEntry(
                        course = course,
                        isCurrentWeekCourse = true,
                    )
                },
            )
        },
        // 预览里点任何东西都会被吞掉，这几个回调不会被调用。
        onCloseToWeekView = {},
        homeTitleStyle = settingsModel.homeTitleStyle,
        homeMenuStyle = settingsModel.homeMenuStyle,
        profileName = TimetableHostLogic.resolveProfileName(
            profiles = snapshot.profiles,
            activeProfileId = snapshot.activeProfileId,
        ),
    )
}

/**
 * 滑杆行的落盘防抖判据（Dart `_updateDraft(..., debounce: true)` 的调用点，`:622-631`）。
 *
 * 名单来自行 id 的字面前缀：
 * * 材质面板三组八根旋钮：`material.general.tuning.*` / `material.general.darkTuning.*` /
 *   `material.courseCard.tuning.*`（`SettingsMaterialPanels.kt` 的 `idPrefix`）；
 * * 壁纸模糊：`backdrop.blur`（`SettingsBackdropFlowPage.kt`）。
 */
private fun isDebouncedSliderRow(rowId: String): Boolean =
    (rowId.startsWith("material.") &&
        (rowId.contains(".tuning.") || rowId.contains(".darkTuning."))) ||
        rowId == SettingsActionDispatcher.ROW_BACKDROP_BLUR

/** Dart 滑杆防抖 250ms（`:624-627`）。 */
private const val APPEARANCE_EDITOR_SAVE_DEBOUNCE_MS = 250L

/** 两个面板的内容最多占屏高 50%（Dart `_materialSheetMaxHeightFactor = 0.5`，`:120`）。 */
private const val APPEARANCE_EDITOR_SHEET_MAX_HEIGHT_FACTOR = 0.5f

private const val LOG_TAG = "appearance-editor"
