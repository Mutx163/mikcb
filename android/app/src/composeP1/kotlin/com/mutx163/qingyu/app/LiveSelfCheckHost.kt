package com.mutx163.qingyu.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.BuildConfig
import com.mutx163.qingyu.R
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.LiveUpdateService
import com.mutx163.qingyu.UmengApplication
import com.mutx163.qingyu.UmengDiagnosticReporter
import com.mutx163.qingyu.components.rememberCappedSheetHeight
import com.mutx163.qingyu.core.LenientJson
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.infra.redactedLiveDebugSnapshot
import com.mutx163.qingyu.pages.diagnostics.AppLogSource
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsStrings
import com.mutx163.qingyu.pages.diagnostics.LogViewerEntryLogic
import com.mutx163.qingyu.pages.diagnostics.perfSnapshotJsonText
import com.mutx163.qingyu.pages.live.LiveCourseTestStage
import com.mutx163.qingyu.pages.live.LiveDisplayStore
import com.mutx163.qingyu.pages.live.LiveSelfCheckNotificationController
import com.mutx163.qingyu.pages.live.LiveSelfCheckNotificationPort
import com.mutx163.qingyu.pages.live.LiveSelfCheckNotificationRows
import com.mutx163.qingyu.pages.settings.LiveDebugRow
import com.mutx163.qingyu.pages.settings.LiveDebugSection
import com.mutx163.qingyu.pages.settings.LiveSelfCheckData
import com.mutx163.qingyu.pages.settings.SettingsLiveSelfCheckPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsStringsExt3
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.widgetdata.MILESTONE_RECENT_END_LABEL_KEY
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 本地日志卡「清空日志」的节点 rowId（`SettingsLiveSelfCheckPage.localLogButtons` 的第一个动作）。 */
private const val ROW_LOCAL_LOGS_CLEAR = "liveSelfCheck.card.localLogs.clear"

/** 本地日志卡「查看手机日志」的节点 rowId：跳到应用日志查看器（`h.log`）。 */
private const val ROW_LOCAL_LOGS_VIEW = "liveSelfCheck.card.localLogs.view"

/** 本地日志卡「更多测试者选项」的节点 rowId：Kotlin 侧还没有对应能力，诚实提示不可用。 */
private const val ROW_LOCAL_LOGS_MORE = "liveSelfCheck.card.localLogs.more"

/** 上岛状态卡「刷新诊断」的节点 rowId（`SettingsLiveSelfCheckPage.islandStatusButtons` 的第一个）。 */
private const val ROW_ISLAND_REFRESH = "liveSelfCheck.island.refresh"

/** 上岛状态卡「自动刷新」开关的节点 id（`SettingsLiveSelfCheckPage.autoRefreshRow`）。 */
private const val ROW_ISLAND_AUTO_REFRESH = "liveSelfCheck.island.autoRefresh"

/** 上岛状态卡「导出并分享日志」的节点 rowId（`islandStatusButtons` 的第二个）。 */
private const val ROW_ISLAND_EXPORT = "liveSelfCheck.island.export"

/** 假期覆盖开关的节点 id（`SettingsLiveSelfCheckPage.holidaySwitchRow`）。 */
private const val ROW_HOLIDAY_SWITCH = "liveSelfCheck.holidaySwitch"

/** 测试通知卡「崩溃测试 / 异常卡顿测试」（仅 debug 构建渲染）。 */
private const val ROW_NOTIFICATION_CRASH = "liveSelfCheck.notification.crashTest"
private const val ROW_NOTIFICATION_ANR = "liveSelfCheck.notification.anrTest"

/** `timetable_settings` 里的假期覆盖键（Dart `TimetableSettings.toJson` 同名）。 */
private const val KEY_HOLIDAY_OVERRIDE = "holidayOverrideEnabled"

/** 崩溃 / 卡顿测试先弹提示再触发，给 toast 留出上屏时间（Dart `:1332` 的 300ms）。 */
private const val TEST_TRIGGER_DELAY_MILLIS = 300L

/** logcat 标签：失败路径没有 ARB 文案时的唯一留痕（与日志查看器同口径）。 */
private const val LOG_TAG = "[live-self-check]"

/** 应用日志查看器的路由（壳里 `"h.log" -> DiagnosticsLogHost(...)`）。 */
private const val LOG_VIEWER_PAGE_ID = "h.log"

/** 轮询间隔（Dart `:189` 默认 1 秒）。 */
private const val POLL_INTERVAL_MILLIS = 1_000L

/** `buildDebugStatus` 里每次都变的字段，指纹比对必须排除。 */
private const val KEY_GENERATED_AT = "generatedAtMillis"

/**
 * 「实时活动自检」页（`b.liveSelfCheck`）的**真宿主**。
 *
 * 壳里原来是 `SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)`：
 * 19 个字段全走默认值，8 块原生诊断卡永远不出现，三个本地日志按钮因为
 * `controlCardWiring` 白名单里没有对应键而点了没反应（认领文件 F23 §2）。
 *
 * ## 数据从哪来
 *
 * `LiveUpdateService.buildDebugStatus(context)`（`LiveUpdateService.kt:125`，companion 公开）
 * 一次给出 `summary` / 8 个诊断分区 / `recentDiagnostics`，每秒读一次。
 * 与日志查看器同一套**指纹去重**：`generatedAtMillis` 每次都变，先摘掉再取哈希；
 * 指纹没变就不重建行数据（Dart 侧「自检页自己把自己拖死」的修复，见
 * `DiagnosticsLogHost` 头注释）。
 *
 * 接真值的字段（页面数据类 19 个里的一半以上）：
 * `serviceRunning` / `statusText` / `notIslandReason` 来自 `summary`，
 * 8 块诊断卡来自对应分区（`recentDiagnostics` → `RECENT_LOGS`），
 * `rawDebugJson` 用与 Dart `JsonEncoder.withIndent('  ')` 逐字符对齐的
 * [perfSnapshotJsonText]，`refreshedAtText` 取 `generatedAtMillis`，
 * `semesterUnset` 读 `timetable_settings.semesterStartDate`。
 *
 * **没有 Kotlin 来源、保持默认值的 3 个**（不编数据）：
 * `timeCorrectionSeconds` / `sessionActive` / `courseTestLabel`；
 * `holidayBlocksIsland` 需要 Dart 侧的假期判定，同样保持默认。
 * `holidayOverrideEnabled` 本轮已接真源（见下表）。
 *
 * ## 交互落点
 *
 * | 按钮 / 开关 | 落点 |
 * |---|---|
 * | 清空日志 | `AppLogStore.clear()` + `clearNative()`，两者都成功才提示「已清空」 |
 * | 查看手机日志 | `onOpenPage("h.log")` |
 * | 更多测试者选项 | 诚实提示 `aboutUnavailable`（Kotlin 侧没有这个页面） |
 * | 刷新诊断 | 立刻重读一次 `buildDebugStatus` |
 * | 导出并分享日志 | `UmengDiagnosticReporter.exportLiveDiagnosticsFile` + 复用日志查看器的 [shareLogText]；拿不到文件时按 Dart 口径回退到**脱敏后的诊断快照** |
 * | 自动刷新开关 | 宿主本地状态（Dart `_autoRefreshEnabled` 也是本地态） |
 * | 假期覆盖开关 | 合并写 `timetable_settings.holidayOverrideEnabled`（顶层 + active profile 内嵌，与 `TimetableSettingsModelStore.save` 同一条路），读回校验失败就拨回并提示 |
 * | 崩溃测试 / 异常卡顿测试 | 真触发（动作与 `MainActivity` 的 `triggerTestCrash` / `triggerTestAnr` 通道分支一致）；release 下按钮本就不渲染 |
 * | 开始 / 取消测试、选课测试、停止选课测试 | 诚实提示 `aboutUnavailable`：Kotlin 侧没有测试夹具会话与强制起岛管线 |
 *
 * ## 已知边界（如实）
 *
 * - 假期覆盖开关只落盘：Compose 壳里没有「课表快照同步」（`syncScheduleSnapshot`
 *   仍只有 Dart 侧在调），所以原生实时服务这一轮不会立刻按新值重算；等 Kotlin 侧有
 *   快照同步后再补。Flutter 主壳读到的是同一份 prefs，值本身是真的。
 * - 分享面板拉不起来时只有 logcat（与日志查看器同口径），没有对应 ARB 键，不假装成功。
 */
@Composable
fun LiveSelfCheckHost(
    onOpenPage: (String) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val timetableStore = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }

    // ── 测试通知卡的四颗按钮（2026-11-03）──
    //
    // 触发管线已在 Kotlin 侧（`pages/live` 的纯逻辑 + `LiveTestTrigger` 的 Context 宿主），
    // 本页只提供两个数据源：课表仓储（选课 / 正式刷新）与显示设置（岛样式）。
    // 「开始测试」在真实课表无课时注入自检预设课——只进原生快照，不写课表。
    val timetableRepository = remember(context) { TimetableRepository(timetableStore) }
    val displayStore = remember(timetableStore) { LiveDisplayStore(timetableStore) }
    val testTrigger = remember(context, timetableRepository, timetableStore) {
        LiveTestTrigger(
            context = context,
            repository = timetableRepository,
            settingsJson = { timetableStore.loadSettingsJson() },
            localizeMilestone = { key ->
                context.getString(
                    if (key == MILESTONE_RECENT_END_LABEL_KEY) {
                        R.string.milestone_recent_end
                    } else {
                        R.string.milestone_next_start
                    },
                )
            },
        )
    }
    /** 自检会话（预设课覆盖层）是否挂着；按钮文案据此在「开始/取消」间翻转。 */
    var sessionActive by remember { mutableStateOf(testTrigger.presetSessionActive) }
    /** 选课测试进行中的课程名；null = 没在测。 */
    var courseTestLabel by remember { mutableStateOf(testTrigger.courseTestLabel) }
    /** 选课弹层 / 阶段弹层的状态。 */
    var pickingCourse by remember { mutableStateOf(false) }
    var stageCourse by remember { mutableStateOf<Course?>(null) }

    val notificationController = remember(testTrigger, timetableRepository, displayStore) {
        LiveSelfCheckNotificationController(object : LiveSelfCheckNotificationPort {
            override fun startSession() {
                scope.launch {
                    showToast(
                        context,
                        when (testTrigger.startProductionSession()) {
                            LiveTestTrigger.ProductionOutcome.STARTED,
                            LiveTestTrigger.ProductionOutcome.STARTED_WITH_PRESET,
                            -> SettingsStringsExt3.liveTestingSessionRunning.text
                            LiveTestTrigger.ProductionOutcome.NO_COURSE ->
                                SettingsStringsExt3.liveTestingNoCourseAvailable.text
                        },
                    )
                    sessionActive = testTrigger.presetSessionActive
                }
            }

            override fun cancelSession() {
                scope.launch {
                    testTrigger.cancelProductionSession()
                    sessionActive = false
                    showToast(context, SettingsStringsExt3.liveTestingSessionCanceled.text)
                }
            }

            override fun startCourseTest(courseId: String, stage: LiveCourseTestStage) {
                scope.launch {
                    val course = timetableRepository.snapshot.courses
                        .firstOrNull { it.id == courseId }
                    if (course == null) {
                        showToast(context, SettingsStringsExt3.liveTestingNoCourseAvailable.text)
                        return@launch
                    }
                    val display = displayStore.loadDisplay(
                        forDuringEnd = stage == LiveCourseTestStage.DURING_CLASS,
                    )
                    showToast(
                        context,
                        when (testTrigger.startCourseTest(course, stage, display)) {
                            is LiveTestTrigger.Outcome.Started,
                            LiveTestTrigger.Outcome.InFlight,
                            -> SettingsStringsExt3.liveTestingSessionRunning.text
                            is LiveTestTrigger.Outcome.DispatchFailed ->
                                SettingsStrings.aboutUnavailable.text
                        },
                    )
                    courseTestLabel = testTrigger.courseTestLabel
                }
            }

            override fun stopCourseTest() {
                scope.launch {
                    testTrigger.cancelStagePreview()
                    courseTestLabel = null
                    showToast(
                        context,
                        SettingsStringsExt3.liveTestingCourseTestStoppedToast.text,
                    )
                }
            }
        })
    }

    // 会话 / 选课测试到点后由原生收岛；每秒同步一次按钮态（Dart 侧同样靠刷新恢复）。
    LaunchedEffect(testTrigger) {
        while (true) {
            sessionActive = testTrigger.presetSessionActive
            courseTestLabel = testTrigger.courseTestLabel
            delay(POLL_INTERVAL_MILLIS)
        }
    }

    var debugLoaded by remember { mutableStateOf(false) }
    var serviceRunning by remember { mutableStateOf(false) }
    var statusText by remember { mutableStateOf("") }
    var notIslandReason by remember { mutableStateOf("") }
    var semesterUnset by remember { mutableStateOf(false) }
    var debugSections by remember {
        mutableStateOf<Map<LiveDebugSection, List<LiveDebugRow>>>(emptyMap())
    }
    var rawDebugJson by remember { mutableStateOf("") }
    var refreshedAtText by remember { mutableStateOf<String?>(null) }
    var autoRefreshEnabled by remember { mutableStateOf(true) }
    var clearingDiagnostics by remember { mutableStateOf(false) }
    var exportingDiagnostics by remember { mutableStateOf(false) }
    var holidayOverrideEnabled by remember { mutableStateOf(false) }

    // 刷新按钮 → 自增一次，让下面的轮询 effect 立刻重跑一轮。
    var reloadTick by remember { mutableIntStateOf(0) }

    // 假期覆盖是盘上的真值（Dart `initState` 也只读一次）。
    LaunchedEffect(timetableStore) {
        holidayOverrideEnabled = withContext(Dispatchers.IO) {
            readHolidayOverride(timetableStore)
        }
    }

    LaunchedEffect(autoRefreshEnabled, reloadTick) {
        var lastFingerprint: String? = null
        while (true) {
            val reading = withContext(Dispatchers.IO) {
                readDebugReading(context, timetableStore, lastFingerprint)
            }
            if (reading != null) {
                lastFingerprint = reading.fingerprint
                // 「上次刷新」按**实际读取成功**的时刻算，不是数据变化的时刻：
                // 原生每隔一秒都会回一份新的 generatedAtMillis。
                refreshedAtText = reading.refreshedAtText
                // 原生状态没变就只动时刻那一行：8 块分区与原始 JSON 不重算。
                val changed = reading.changed
                if (changed != null) {
                    debugLoaded = true
                    serviceRunning = changed.serviceRunning
                    statusText = changed.statusText
                    notIslandReason = changed.notIslandReason
                    semesterUnset = changed.semesterUnset
                    debugSections = changed.sections
                    rawDebugJson = changed.rawJson
                }
            }
            if (!autoRefreshEnabled) {
                break
            }
            delay(POLL_INTERVAL_MILLIS)
        }
    }

    fun clearLogs() {
        if (clearingDiagnostics) {
            return
        }
        clearingDiagnostics = true
        scope.launch {
            // 与日志查看器同一口径：应用日志 + 原生诊断日志**两份都清掉**才算成功。
            // 失败必须如实提示，不能把「没清掉」报成「已清空」。
            val cleared = withContext(Dispatchers.IO) {
                val appCleared = AppLogStore.clear()
                val nativeCleared = AppLogStore.clearNative()
                appCleared && nativeCleared
            }
            clearingDiagnostics = false
            showToast(
                context,
                if (cleared) {
                    DiagnosticsStrings.appLogsCleared.text
                } else {
                    DiagnosticsStrings.appLogsClearFailed.text
                },
            )
        }
    }

    fun exportDiagnostics() {
        if (exportingDiagnostics) {
            return
        }
        exportingDiagnostics = true
        scope.launch {
            val outcome = try {
                withContext(Dispatchers.IO) { shareLiveDiagnostics(context) }
            } finally {
                // 任何路径都必须复位：Dart `_exportLiveDiagnostics` 的 finally 同口径。
                // 不复位的话按钮会永久停在「导出中」，再点又被开头的守卫静默吞掉。
                exportingDiagnostics = false
            }
            when (outcome) {
                DiagnosticsExportOutcome.SHARED -> Unit
                DiagnosticsExportOutcome.NOTHING_TO_EXPORT ->
                    showToast(context, DiagnosticsStrings.liveDiagnosticsNothingToExport.text)
                // 没有「分享面板拉不起来」的 ARB 键（与日志查看器同一处缺口），
                // 宁可只留 logcat，也不弹一句假的「已导出」。
                DiagnosticsExportOutcome.SHARE_NOT_LAUNCHED ->
                    Log.w(LOG_TAG, "share chooser not launched for live diagnostics")
            }
        }
    }

    /**
     * 假期覆盖开关。
     *
     * 真值在 `timetable_settings.holidayOverrideEnabled`（Dart `TimetableSettings`
     * 同名键）。写法和设置族完全一致：顶层 + active profile 内嵌两处一起合并写
     * （`TimetableSettingsModelStore.save` 的同一对调用），盘上其余键原样保留。
     *
     * 写入口没有失败返回值（`commit()` 的 Boolean 被 `KeyValueStore` 丢掉），
     * 所以**读回校验**：没落进去就拨回原值并提示，不把「没存上」画成「已开启」。
     */
    fun setHolidayOverride(enabled: Boolean) {
        val previous = holidayOverrideEnabled
        holidayOverrideEnabled = enabled
        scope.launch {
            val landed = withContext(Dispatchers.IO) {
                writeHolidayOverride(timetableStore, enabled)
            }
            // 只有「这次点击仍是最新一次」时才回滚，避免慢写的旧请求盖掉新点击。
            if (!landed && holidayOverrideEnabled == enabled) {
                holidayOverrideEnabled = previous
                showToast(context, SettingsStringsExt2.saveFailed.text)
            }
        }
    }

    /**
     * 崩溃测试：动作与 `MainActivity` 的 `triggerTestCrash` 通道分支**逐条一致**
     * （那是全仓唯一实现；它不是可复用的 Kotlin 入口，本文件不另造一套行为）。
     *
     * 先弹警告再触发（Dart `:1327-1336` 的 300ms）。用 `Handler.post` 而不是在协程里
     * 直接 throw：异常必须落到主线程未捕获处理器，才能被 U-APM 当成真实崩溃收走。
     */
    fun triggerTestCrash() {
        if (!BuildConfig.DEBUG) {
            // 页面本来就只在 debug 渲染这两颗按钮；通道层也有一道同样的门。
            showToast(context, SettingsStrings.aboutUnavailable.text)
            return
        }
        showToast(context, SettingsStringsExt3.liveTestingCrashSoon.text)
        scope.launch {
            delay(TEST_TRIGGER_DELAY_MILLIS)
            UmengApplication.initializeAnalyticsIfNeeded(context.applicationContext)
            Handler(Looper.getMainLooper()).post {
                throw RuntimeException("Manual Umeng U-APM test crash")
            }
        }
    }

    /** 异常卡顿测试：同上（`MainActivity.triggerTestAnr`：主线程睡 30 秒）。 */
    fun triggerTestAnr() {
        if (!BuildConfig.DEBUG) {
            showToast(context, SettingsStrings.aboutUnavailable.text)
            return
        }
        showToast(context, SettingsStringsExt3.liveTestingAnrSoon.text)
        scope.launch {
            delay(TEST_TRIGGER_DELAY_MILLIS)
            UmengApplication.initializeAnalyticsIfNeeded(context.applicationContext)
            Handler(Looper.getMainLooper()).post {
                try {
                    Thread.sleep(30_000L)
                } catch (_: InterruptedException) {
                }
            }
        }
    }

    val data = LiveSelfCheckData(
        isReleaseBuild = !BuildConfig.DEBUG,
        holidayOverrideEnabled = holidayOverrideEnabled,
        sessionActive = sessionActive,
        courseTestLabel = courseTestLabel,
        semesterUnset = semesterUnset,
        serviceRunning = serviceRunning,
        notIslandReason = notIslandReason,
        statusText = statusText,
        loadingDebugStatus = !debugLoaded,
        exportingDiagnostics = exportingDiagnostics,
        clearingDiagnostics = clearingDiagnostics,
        autoRefreshEnabled = autoRefreshEnabled,
        refreshedAtText = refreshedAtText,
        autoRefreshIntervalSeconds = (POLL_INTERVAL_MILLIS / 1_000L).toInt(),
        debugLoaded = debugLoaded,
        debugSections = debugSections,
        rawDebugJson = rawDebugJson,
    )

    SettingsPageScreen(
        spec = SettingsLiveSelfCheckPage.spec(SettingsPageState(), data),
        onBack = onBack,
        onAction = { _, _, rowId ->
            when (rowId) {
                ROW_LOCAL_LOGS_CLEAR -> clearLogs()
                ROW_LOCAL_LOGS_VIEW -> onOpenPage(LOG_VIEWER_PAGE_ID)
                ROW_LOCAL_LOGS_MORE -> showToast(context, SettingsStrings.aboutUnavailable.text)
                ROW_ISLAND_REFRESH -> reloadTick += 1
                ROW_ISLAND_AUTO_REFRESH -> autoRefreshEnabled = !autoRefreshEnabled
                ROW_ISLAND_EXPORT -> exportDiagnostics()
                ROW_HOLIDAY_SWITCH -> setHolidayOverride(!holidayOverrideEnabled)
                // 测试通知卡：会话起停 / 停止走真触发管线；「选课测试」先选课、再选阶段，
                // 两个弹层都关闭后才真正投递（避免弹层还在时岛先弹起来）。
                LiveSelfCheckNotificationRows.START,
                LiveSelfCheckNotificationRows.CANCEL,
                LiveSelfCheckNotificationRows.COURSE_TEST_STOP,
                -> notificationController.trigger(rowId)

                LiveSelfCheckNotificationRows.COURSE_TEST -> pickingCourse = true

                ROW_NOTIFICATION_CRASH -> triggerTestCrash()
                ROW_NOTIFICATION_ANR -> triggerTestAnr()
            }
        },
    )

    // 选课测试：先选课程，再选阶段。两个弹层都按官方 OverlayDialog 走
    //（遮罩、返回键、大屏行为由它提供），宿主只排正文。
    if (pickingCourse) {
        CourseTestPickerDialog(
            courses = timetableRepository.snapshot.courses
                .distinctBy { Triple(it.name, it.teacher, it.location) },
            onDismiss = { pickingCourse = false },
            onPick = { course ->
                pickingCourse = false
                stageCourse = course
            },
        )
    }
    val pickedCourse = stageCourse
    if (pickedCourse != null) {
        CourseTestStageDialog(
            courseName = pickedCourse.name,
            onDismiss = { stageCourse = null },
            onPick = { stage ->
                stageCourse = null
                notificationController.trigger(
                    rowId = LiveSelfCheckNotificationRows.COURSE_TEST,
                    courseId = pickedCourse.id,
                    stage = stage,
                )
            },
        )
    }
}

/** 选课测试第一步：从真实课表里选一门课（同名同师同地的重复课只列一次）。 */
@Composable
private fun CourseTestPickerDialog(
    courses: List<Course>,
    onDismiss: () -> Unit,
    onPick: (Course) -> Unit,
) {
    OverlayDialog(
        show = true,
        title = SettingsStringsExt3.liveTestingCourseTestPickerTitle.text,
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Column(
            modifier = Modifier
                .heightIn(max = rememberCappedSheetHeight(420.dp))
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (courses.isEmpty()) {
                Text(
                    text = SettingsStringsExt3.liveTestingNoCourseAvailable.text,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
            } else {
                courses.forEach { course ->
                    Button(
                        onClick = { onPick(course) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColorsPrimary(),
                    ) {
                        Text(text = course.name)
                    }
                }
            }
            Button(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
                Text(text = SettingsStringsExt3.cancelAction.text)
            }
        }
    }
}

/** 选课测试第二步：选要预览的阶段（课前倒计时 / 上课中）。 */
@Composable
private fun CourseTestStageDialog(
    courseName: String,
    onDismiss: () -> Unit,
    onPick: (LiveCourseTestStage) -> Unit,
) {
    OverlayDialog(
        show = true,
        title = SettingsStringsExt3.liveTestingCourseTestStageTitle.text,
        onDismissRequest = onDismiss,
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = courseName,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                modifier = Modifier.padding(bottom = 4.dp),
            )
            Button(
                onClick = { onPick(LiveCourseTestStage.BEFORE_CLASS) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = SettingsStringsExt3.liveTestingCourseTestStageBeforeClass.text)
            }
            Button(
                onClick = { onPick(LiveCourseTestStage.DURING_CLASS) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(text = SettingsStringsExt3.liveTestingCourseTestStageDuringClass.text)
            }
            Button(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
                Text(text = SettingsStringsExt3.cancelAction.text)
            }
        }
    }
}

/** 假期覆盖的真值：`timetable_settings.holidayOverrideEnabled`（缺键 / 坏值按 false）。 */
private fun readHolidayOverride(store: TimetableStore): Boolean =
    LenientJson.bool(store.loadSettingsJson()[KEY_HOLIDAY_OVERRIDE]) ?: false

/**
 * 合并写两处（顶层 + active profile 内嵌），再**读回校验**。
 *
 * 与 `TimetableSettingsModelStore.save` 同一条路：桌面卡片读的是 profile 内嵌那份，
 * 只写顶层会出现「设置页改了、卡片不动」。写入口没有失败返回值（`commit()` 的
 * Boolean 被 `KeyValueStore` 丢掉），所以只能靠读回判真假。
 */
private fun writeHolidayOverride(store: TimetableStore, enabled: Boolean): Boolean =
    runCatching {
        val patch = mapOf<String, Any?>(KEY_HOLIDAY_OVERRIDE to enabled)
        store.saveSettingsPatch(patch)
        store.saveSettingsPatchToActiveProfile(patch)
        readHolidayOverride(store) == enabled
    }.getOrDefault(false)

/** 「导出并分享日志」的三种结局（宿主据此决定提示什么）。 */
private enum class DiagnosticsExportOutcome {
    SHARED,
    NOTHING_TO_EXPORT,
    SHARE_NOT_LAUNCHED,
}

/**
 * 「导出并分享日志」的真实现（Dart `_exportLiveDiagnostics` 的等价物）。
 *
 * 1. `UmengDiagnosticReporter.exportLiveDiagnosticsFile`：Dart 那个平台通道方法在
 *    原生侧的同一份实现；
 * 2. 拿不到文件时回退到**脱敏后**的诊断快照（Dart `_exportCurrentDebugSnapshot`，
 *    隐私审查 2026-10-09 发现 1）——复用同一份 `redactedLiveDebugSnapshot`，
 *    不自己再写一套脱敏规则；
 * 3. 分享统一走日志查看器的 [shareLogText]，不另造分享面板。
 *
 * 必须在 IO 线程调用（写文件、读 SharedPreferences）。
 */
private fun shareLiveDiagnostics(context: Context): DiagnosticsExportOutcome {
    val config = LogViewerEntryLogic.configFor(AppLogSource.LIVE)
    val exportedText = UmengDiagnosticReporter.exportLiveDiagnosticsFile(context)
        ?.takeIf { it.isNotBlank() }
        ?.let { path -> runCatching { File(path).readText() }.getOrNull() }
    if (!exportedText.isNullOrBlank()) {
        return shareTextFile(
            context = context,
            text = exportedText,
            fileName = LogViewerEntryLogic.exportFileName(
                AppLogSource.LIVE,
                System.currentTimeMillis(),
            ),
            shareText = config.shareText,
            shareSubject = config.shareSubject,
        )
    }

    // 原生导出拿不到（记录开关关着 / 文件不存在）→ 与 Dart 一样退回当前诊断快照。
    // 快照里有课程名 / 教室等个人字段，**必须**先脱敏再出门。
    val snapshot = runCatching { LiveUpdateService.buildDebugStatus(context) }.getOrNull()
        ?: return DiagnosticsExportOutcome.NOTHING_TO_EXPORT
    @Suppress("UNCHECKED_CAST")
    val redacted = redactedLiveDebugSnapshot(snapshot as Map<Any?, Any?>)
    val payload = linkedMapOf<String, Any?>(
        "exportedAtMillis" to System.currentTimeMillis(),
        "source" to "live_testing_screen_snapshot",
        "debugStatus" to redacted,
    )
    return shareTextFile(
        context = context,
        text = perfSnapshotJsonText(payload),
        fileName = "mikcb-live-debug-snapshot-${System.currentTimeMillis()}.json",
        shareText = SettingsStringsExt3.liveDiagnosticsSnapshotShareText.text,
        shareSubject = SettingsStringsExt3.liveDiagnosticsSnapshotShareSubject.text,
    )
}

private fun shareTextFile(
    context: Context,
    text: String,
    fileName: String,
    shareText: String,
    shareSubject: String,
): DiagnosticsExportOutcome = if (
    shareLogText(context, text, fileName, shareText, shareSubject)
) {
    DiagnosticsExportOutcome.SHARED
} else {
    DiagnosticsExportOutcome.SHARE_NOT_LAUNCHED
}

/**
 * 一轮轮询的结果。
 *
 * `fingerprint` 是**排除 `generatedAtMillis` 之后**整份状态的哈希；
 * `changed` 为 `null` 表示与上一轮完全相同（宿主只需更新刷新时刻，
 * 不必重建 8 块分区与原始 JSON——与日志查看器「不变就整轮跳过」同一纪律）。
 */
private class DebugReading(
    val fingerprint: String,
    val refreshedAtText: String,
    val changed: DebugSnapshot?,
)

/** 状态**变了**的那一份数据；`changed == null` 时宿主沿用上一份。 */
private class DebugSnapshot(
    val serviceRunning: Boolean,
    val statusText: String,
    val notIslandReason: String,
    val semesterUnset: Boolean,
    val sections: Map<LiveDebugSection, List<LiveDebugRow>>,
    val rawJson: String,
)

/**
 * 读一次原生诊断（必须在 IO 线程调用：里面会读 SharedPreferences 与日志尾部）。
 *
 * 失败返回 `null`，宿主保留上一份数据——不把异常翻译成「全 false」，那等于把
 * 「读不到」伪装成「服务没在跑」。
 */
private fun readDebugReading(
    context: Context,
    timetableStore: TimetableStore,
    previousFingerprint: String?,
): DebugReading? = runCatching {
    val status = LiveUpdateService.buildDebugStatus(context)
    val fingerprint = status.filterKeys { it != KEY_GENERATED_AT }.hashCode().toString()
    val generatedAt = (status[KEY_GENERATED_AT] as? Number)?.toLong()
    val refreshedAtText = formatClock(generatedAt ?: System.currentTimeMillis())

    if (fingerprint == previousFingerprint) {
        return@runCatching DebugReading(fingerprint, refreshedAtText, changed = null)
    }

    val summary = status["summary"] as? Map<*, *>
    val sections = linkedMapOf<LiveDebugSection, List<LiveDebugRow>>()
    LiveDebugSection.entries.forEach { section ->
        val raw = status[statusKeyOf(section)] as? Map<*, *> ?: return@forEach
        sections[section] = raw.entries.map { (key, value) ->
            LiveDebugRow(label = key.toString(), value = formatDebugValue(value))
        }
    }

    DebugReading(
        fingerprint = fingerprint,
        refreshedAtText = refreshedAtText,
        changed = DebugSnapshot(
            serviceRunning = summary?.get("serviceRunning") as? Boolean ?: false,
            statusText = summary?.get("statusText") as? String ?: "",
            notIslandReason = summary?.get("notIslandReason") as? String ?: "",
            semesterUnset = timetableStore.loadSettingsJson().let { json ->
                TimetableSettings.fromJson(json).semesterStartDate == null
            },
            sections = sections,
            rawJson = perfSnapshotJsonText(status),
        ),
    )
}.getOrNull()

/** 诊断分区 → `buildDebugStatus` 的顶层键（顺序与页面上的卡片顺序一致）。 */
private fun statusKeyOf(section: LiveDebugSection): String = when (section) {
    LiveDebugSection.ENVIRONMENT -> "environment"
    LiveDebugSection.SERVICE -> "service"
    LiveDebugSection.COURSE -> "course"
    LiveDebugSection.TIMING -> "timing"
    LiveDebugSection.SWITCHES -> "switches"
    LiveDebugSection.DISPLAY -> "display"
    LiveDebugSection.NOTIFICATION -> "notification"
    LiveDebugSection.RECENT_LOGS -> "recentDiagnostics"
}

/**
 * 原生字段值的展示口径。
 *
 * 标量直接 `toString()`（与 Dart 的 `'$value'` 一致）；嵌套的 Map / List 用
 * [MiniJson] 压成一行，避免 `{enabled=true, tail=…}` 这种 Java 默认写法。
 * `null` 交给页面统一渲染成 `-`（`debugValueRow` 的 `ifEmpty { "-" }`）。
 */
private fun formatDebugValue(value: Any?): String = when (value) {
    null -> ""
    is String -> value
    is Boolean, is Number -> value.toString()
    is Map<*, *>, is Iterable<*>, is Array<*> -> MiniJson.encode(value)
    else -> value.toString()
}

private fun formatClock(millis: Long): String =
    SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(millis))

private fun showToast(context: Context, message: String) {
    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
}
