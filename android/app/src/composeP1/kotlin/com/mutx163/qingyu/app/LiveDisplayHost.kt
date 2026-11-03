package com.mutx163.qingyu.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.ExternalImportReader
import com.mutx163.qingyu.R
import com.mutx163.qingyu.pages.import.ImportSharedModel
import com.mutx163.qingyu.pages.import.ImportStrings
import com.mutx163.qingyu.pages.live.DisplaySettingsPage
import com.mutx163.qingyu.pages.live.DisplaySettingsStrings
import com.mutx163.qingyu.pages.live.LiveCourseTestStage
import com.mutx163.qingyu.pages.live.LiveCourseTestSessions
import com.mutx163.qingyu.pages.live.LiveCurrentCourseSource
import com.mutx163.qingyu.pages.live.LiveDisplayStore
import com.mutx163.qingyu.pages.live.LiveImagePickLogic
import com.mutx163.qingyu.pages.live.LiveImagePickTarget
import com.mutx163.qingyu.pages.live.LiveReminderTimingPage
import com.mutx163.qingyu.pages.live.MiuiIslandExpandedIconMode
import com.mutx163.qingyu.pages.live.ReminderTimingState
import com.mutx163.qingyu.pages.live.toIslandPreviewInfo
import com.mutx163.qingyu.pages.live.withMiuiIslandExpandedIconMode
import com.mutx163.qingyu.pages.live.withMiuiIslandExpandedIconPath
import com.mutx163.qingyu.pages.live.withMiuiIslandLabelLogoPath
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.widgetdata.MILESTONE_RECENT_END_LABEL_KEY
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDateTime

/**
 * 「超级岛 · 显示设置」页的**真实宿主**（取代壳里 `DisplaySettingsPage(forDuringEnd = …, onBack = …)`
 * 那份「状态永远是默认值、三个回调全是空实现」的挂法）。
 *
 * ## 三个路由共用它
 *
 * `j.live` / `j.displayBefore` 传 `forDuringEnd = false`（上课前档），
 * `j.displayDuring` 传 `true`（课中/下课档）。**改一处三页一起活**，
 * 但两档的键组不同 —— 见 [LiveDisplayStore] 的「两套键」一节。
 *
 * ## 每个交互的落点
 *
 * | 页面交互 | Dart | 本宿主 |
 * |---|---|---|
 * | 任何开关 / 下拉 / 滑杆 | `_updateDisplay` → `updateTimetableSettings` | [LiveDisplayStore.saveDisplay]（读-合并写，250ms 防抖，离开页面补写一次） |
 * | 选左侧标签 Logo / 展开态大图标 | `_pickAndStoreImage`（`live_settings_subpages.dart:1310-1364`） | 系统选图 → 复制进 `app_flutter/miui_label_logos` / `miui_expanded_icons`，文件名前缀与 Dart 逐字一致 |
 * | 免打扰权限 | `_openDoNotDisturbAccess` | [Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS] |
 * | 速览「试弹 / 停止」 | `triggerLiveStagePreviewTest` / `cancelLiveUpdateCourseTest` | [LiveTestTrigger]：合成 30 秒单阶段窗口 → 双暂停（Kotlin 侧只剩原生闹钟一路）→ 完整载荷起前台服务 → 成功后自动退后台；按钮态跨页面由 [LiveCourseTestSessions] 单槽记录，到点自动翻回 |
 *
 * ## 为什么防抖而不是每次改动直接写
 *
 * 滑杆一次拖动会连发几十次 `onStateChange`，每次都 `commit()` 落盘等于主线程卡顿；
 * Dart 侧同样是 250ms 防抖 + 离开页面补写（`live_settings_subpages.dart:247-256 / :395-399`）。
 * 这里用 `LaunchedEffect(version)` 实现：`version` 一变就取消上一次待写任务。
 *
 * ## 试弹会话进行中改设置 = 热更新
 *
 * Dart `hotUpdateLiveCourseTestSession`：会话在跑时调整显示配置，真机岛即时响应。
 * 本宿主在防抖落盘后调 [LiveTestTrigger.hotUpdateIfSettingsChanged]——设置指纹没变
 * （无关字段）不重发载荷，变了才重投。
 */
@Composable
fun LiveDisplayHost(
    forDuringEnd: Boolean,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember(context) { liveDisplayStore(context) }
    var state by remember(store, forDuringEnd) { mutableStateOf(store.loadDisplay(forDuringEnd)) }

    // 预览的真实课程来源：与课表页同一份仓储快照 + 同一条「当前课程」计算入口。
    // 本宿主不直接写课表，只用只读快照；仓储后续若有变更（别的页面改课）跟着刷新。
    val timetableRepository = remember(context) {
        TimetableRepository(TimetableStore(PrefsKeyValueStore(context)))
    }
    var timetableSnapshot by remember(timetableRepository) {
        mutableStateOf(timetableRepository.snapshot)
    }
    DisposableEffect(timetableRepository) {
        val subscription = timetableRepository.observe { timetableSnapshot = it }
        onDispose { subscription.close() }
    }
    // 上课中 / 课间会随时间切换：30 秒推进一次「现在」，不做每帧重算。
    var previewNow by remember { mutableStateOf(LocalDateTime.now()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(PREVIEW_CLOCK_TICK_MILLIS)
            previewNow = LocalDateTime.now()
        }
    }
    val currentCourse = remember(timetableSnapshot, previewNow) {
        LiveCurrentCourseSource.resolve(timetableSnapshot, previewNow)
    }
    val previewInfo = remember(currentCourse) { currentCourse.toIslandPreviewInfo() }
    /** 防抖写盘计数器：每次用户改动 +1，`LaunchedEffect` 随之重启待写任务。 */
    var version by remember { mutableStateOf(0) }
    /** 正在等选图结果的目标（选图是异步的，回调里才知道用户选没选）。 */
    var pendingPick by remember { mutableStateOf<LiveImagePickTarget?>(null) }
    val latestState by rememberUpdatedState(state)

    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    // ── 试弹（速览）管线：Context 侧调度器 + 页面按钮态 ──
    // 会话是进程级单槽：返回重进页面按会话恢复「停止测试」态（Dart 上收全局的同一动机）。
    // settingsJson 供给生产刷新用整份设置：与 [store] 同一份 SharedPreferences，读回一致。
    val triggerSettingsStore = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }
    val trigger = remember(context, timetableRepository) {
        LiveTestTrigger(
            context = context,
            repository = timetableRepository,
            settingsJson = { triggerSettingsStore.loadSettingsJson() },
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
    val previewStage = if (forDuringEnd) LiveCourseTestStage.DURING_CLASS else LiveCourseTestStage.BEFORE_CLASS
    val initialSession = remember { LiveCourseTestSessions.current() }
    var stagePreviewActive by remember { mutableStateOf(initialSession?.stage == previewStage) }
    var stagePreviewBusy by remember { mutableStateOf(false) }
    /** 会话终点毫秒：>0 时由下方 `LaunchedEffect` 到点把按钮翻回「试弹」态。 */
    var stagePreviewEndMillis by remember { mutableStateOf(initialSession?.sessionEndMillis ?: 0L) }

    fun startStagePreview() {
        if (stagePreviewBusy) return
        scope.launch {
            stagePreviewBusy = true
            val stageWord = if (forDuringEnd) {
                DisplaySettingsStrings.stagePreviewStageDuringClass.zh
            } else {
                DisplaySettingsStrings.stagePreviewStageBeforeClass.zh
            }
            when (val outcome = trigger.startStagePreview(forDuringEnd = forDuringEnd, display = latestState)) {
                is LiveTestTrigger.Outcome.Started -> {
                    stagePreviewActive = true
                    stagePreviewEndMillis = outcome.session.sessionEndMillis
                    showToast(DisplaySettingsStrings.stagePreviewStartedToast.filled("stage", stageWord))
                    // 岛只在桌面/状态栏可见：成功后自动退后台（等效按 Home）。
                    trigger.moveTaskToBack()
                }
                LiveTestTrigger.Outcome.InFlight ->
                    showToast(DisplaySettingsStrings.testingInFlight.zh)
                is LiveTestTrigger.Outcome.DispatchFailed ->
                    // Dart 同口径：sendFailedWithError 的 error 参数带失败细节。
                    showToast(
                        DisplaySettingsStrings.sendFailedWithError
                            .filled("error", outcome.detail),
                    )
            }
            stagePreviewBusy = false
        }
    }

    fun stopStagePreview() {
        if (stagePreviewBusy) return
        scope.launch {
            stagePreviewBusy = true
            trigger.cancelStagePreview()
            stagePreviewActive = false
            stagePreviewEndMillis = 0
            showToast(DisplaySettingsStrings.stagePreviewStoppedToast.zh)
            stagePreviewBusy = false
        }
    }

    // 250ms 防抖：期间又改就取消上一次，只写最后一份。
    LaunchedEffect(version) {
        if (version == 0) return@LaunchedEffect
        delay(SAVE_DEBOUNCE_MILLIS)
        store.saveDisplay(latestState, forDuringEnd)
        // 试弹会话在跑时，显示改动热更新真机岛（指纹没变 = 无关改动，不重发）。
        trigger.hotUpdateIfSettingsChanged(latestState)
    }
    // 速览会话到点：按钮自动翻回「试弹」态（岛已被原生按会话终点收尾）。
    LaunchedEffect(stagePreviewEndMillis) {
        if (stagePreviewEndMillis <= 0L) return@LaunchedEffect
        val remaining = stagePreviewEndMillis - System.currentTimeMillis()
        if (remaining > 0) delay(remaining)
        stagePreviewActive = false
        stagePreviewEndMillis = 0
    }
    // 离开页面补写：防抖窗口内退出时那一份不能丢（Dart `dispose` 同口径）。
    // `version == 0` = 用户什么都没改 ⇒ **一个字节都不写**：
    // 无脑补写会把「课中/下课档在跟随时派生出来的那 22 个键」也落盘，
    // 存档里凭空多出一批用户从没设过的字段，日后排查配置问题时是纯噪音。
    DisposableEffect(store, forDuringEnd) {
        onDispose {
            if (version > 0) store.saveDisplay(latestState, forDuringEnd)
        }
    }

    val pickLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? ->
        val target = pendingPick
        pendingPick = null
        if (uri == null || target == null) return@rememberLauncherForActivityResult
        scope.launch {
            val outcome = withContext(Dispatchers.IO) {
                persistPickedImage(
                    context = context,
                    uri = uri,
                    directoryName = when (target) {
                        LiveImagePickTarget.LABEL_LOGO -> LiveImagePickLogic.LABEL_LOGO_DIR
                        LiveImagePickTarget.EXPANDED_ICON -> LiveImagePickLogic.EXPANDED_ICON_DIR
                    },
                    filePrefix = when (target) {
                        LiveImagePickTarget.LABEL_LOGO ->
                            if (forDuringEnd) "during_end_label_logo" else "before_class_label_logo"
                        LiveImagePickTarget.EXPANDED_ICON ->
                            if (forDuringEnd) "during_end_expanded_icon" else "before_class_expanded_icon"
                    },
                )
            }
            when (outcome) {
                is ImagePickOutcome.Stored -> {
                    state = when (target) {
                        LiveImagePickTarget.LABEL_LOGO ->
                            state.withMiuiIslandLabelLogoPath(outcome.path)
                        // Dart `:1282-1296`：换图同时把展开态图标模式切到「自定义图片」，
                        // 否则用户选了图却看不到效果。
                        LiveImagePickTarget.EXPANDED_ICON ->
                            state.withMiuiIslandExpandedIconMode(MiuiIslandExpandedIconMode.CUSTOM_IMAGE)
                                .withMiuiIslandExpandedIconPath(outcome.path)
                    }
                    version++
                }
                ImagePickOutcome.TooLarge -> showToast(
                    ImportStrings.importFileTooLarge.filled(
                        "size",
                        // 与真正生效的上限用同一个常量：提示里写 20 MB、实际按别的数卡人，
                        // 用户会以为「明明没超」。
                        ImportSharedModel.formatByteBudget(LiveImagePickLogic.MAX_BYTES),
                    ),
                )
                ImagePickOutcome.Failed -> showToast(IMAGE_PICK_FAILED_MESSAGE)
            }
        }
    }

    DisplaySettingsPage(
        state = state,
        onStateChange = { next ->
            state = next
            version++
        },
        onBack = onBack,
        forDuringEnd = forDuringEnd,
        previewInfo = previewInfo,
        // 学期未设置时，空态除了「暂无课程」再给一句可操作的原因；其余空态只留主句。
        previewEmptyHint = if (previewInfo == null && currentCourse.semesterStartMissing) {
            DisplaySettingsStrings.islandPreviewSemesterUnsetHint.zh
        } else {
            null
        },
        // 选图是异步的：这里先登记目标并拉起系统选图，返回 null 让页面别自己改状态，
        // 真正的状态更新在选图回调里做（页面那份同步口径做不到异步选图）。
        onPickImage = { target ->
            pendingPick = target
            pickLauncher.launch(IMAGE_MIME)
            null
        },
        onOpenDoNotDisturbAccess = { openDoNotDisturbAccess(context, ::showToast) },
        // 试弹：真起岛（合成 30 秒单阶段窗口 + 完整载荷），停止则立即收岛并恢复正式调度。
        onStagePreviewStart = { startStagePreview() },
        onStagePreviewStop = { stopStagePreview() },
        stagePreviewActive = stagePreviewActive,
        stagePreviewBusy = stagePreviewBusy,
    )
}

/**
 * 「提醒时段」页的**真实宿主**：读快照 → 渲染 → 每次改动落盘。
 *
 * 根因是 `LiveReminderTimingPage(onBack = onBack)` 那条挂法：`onPersist` 默认空实现
 * ⇒ 提醒时机 / 课前分钟 / 秒级阈值改了全都不落盘，退出重进一律回到默认值。
 *
 * 这一页与显示设置页共用 `liveEndSecondsCountdownThreshold` / `livePromoteDuringClass`
 * 等键（Dart 同一个 `_draft`），所以**必须**走同一个 [LiveDisplayStore] 的读-合并写，
 * 否则两个页面会互相把对方的字段冲掉。
 */
@Composable
fun LiveReminderTimingHost(onBack: () -> Unit) {
    val context = LocalContext.current
    val store = remember(context) { liveDisplayStore(context) }
    var state by remember(store) { mutableStateOf(store.loadReminderTiming()) }
    var version by remember { mutableStateOf(0) }
    val latestState by rememberUpdatedState(state)

    LaunchedEffect(version) {
        if (version == 0) return@LaunchedEffect
        delay(SAVE_DEBOUNCE_MILLIS)
        store.saveReminderTiming(latestState)
    }
    // 没改过就不写（理由同显示设置宿主）。
    DisposableEffect(store) {
        onDispose { if (version > 0) store.saveReminderTiming(latestState) }
    }

    LiveReminderTimingPage(
        onBack = onBack,
        initialState = state,
        onPersist = { next: ReminderTimingState ->
            state = next
            version++
        },
    )
}

// ───────────────────────── 选图落盘 ─────────────────────────

/** 防抖窗口（Dart `_updateDraft` 的 `Duration(milliseconds: 250)`）。 */
private const val SAVE_DEBOUNCE_MILLIS: Long = 250L

/** 预览「现在」的推进间隔：只用来跨过上课/下课边界，不需要逐秒。 */
private const val PREVIEW_CLOCK_TICK_MILLIS: Long = 30_000L

private const val IMAGE_MIME = "image/*"

/**
 * 选图失败提示。文案走 `DisplaySettingsStrings`（ARB `liveImagePickFailed`），
 * 不再在渲染层写死中文——2026-10-29 质量审核发现该句绕过了 i18n 层。
 */
private val IMAGE_PICK_FAILED_MESSAGE: String = DisplaySettingsStrings.imagePickFailed.zh

/** 选图结果三态：成功带绝对路径 / 超限 / 其他失败。 */
private sealed interface ImagePickOutcome {
    data class Stored(val path: String) : ImagePickOutcome
    data object TooLarge : ImagePickOutcome
    data object Failed : ImagePickOutcome
}

/**
 * 把系统选图结果**复制**进应用私有目录，返回绝对路径。
 *
 * 为什么不直接用 `content://` URI：超级岛由原生 `LiveUpdateService` 在后台读这张图，
 * 拿到的是一条**纯路径字符串**（`liveMiuiIslandLabelLogoPath`），
 * 而 `content://` 的读权限只在当前会话内、重启即失效。
 *
 * 判据（超不超限 / 存成什么名字 / 哪些旧图该删）一律交给
 * [LiveImagePickLogic]——那层是纯函数、有 JVM 单测；这里只做「读流、写文件」。
 *
 * 两条**顺序**要求都不能颠倒：
 * 1. **先挡声明长度，再读**：能挡住就别把 20 MB 读进内存；
 * 2. **先写新图，再清旧图**：写失败时最多「多留一张旧图」，不会把用户已有的图弄没
 *    （Dart `:1350-1361` 也是先 `writeAsBytes` 再 `_deleteManagedImageArtifacts`）。
 *
 * Flutter 的 documents 目录在 Android 上是 `<pkg>/app_flutter`（`path_provider` 口径），
 * 这里按同样位置拼：`filesDir.parent / app_flutter / <dir>`；取不到父目录就退到 `filesDir`。
 * 壳是独立包名（`.ui`），路径本来就与正式版不同 —— 但**目录名与文件名**保持一致，
 * 将来搬进正式包时不用改宿主逻辑。
 */
private fun persistPickedImage(
    context: Context,
    uri: Uri,
    directoryName: String,
    filePrefix: String,
): ImagePickOutcome {
    return try {
        val declaredLength = context.contentResolver.openAssetFileDescriptor(uri, "r")
            ?.use { it.length } ?: -1L
        if (declaredLength > LiveImagePickLogic.MAX_BYTES) return ImagePickOutcome.TooLarge

        val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
            // 显式传上限：与 [LiveImagePickLogic.MAX_BYTES] 同一个数，不留第二份口径。
            ExternalImportReader.readCapped(input, LiveImagePickLogic.MAX_BYTES)
        }
        when (LiveImagePickLogic.classify(declaredLength, bytes)) {
            LiveImagePickLogic.Outcome.TOO_LARGE -> return ImagePickOutcome.TooLarge
            LiveImagePickLogic.Outcome.FAILED -> return ImagePickOutcome.Failed
            LiveImagePickLogic.Outcome.OK -> Unit
        }
        val payload = bytes ?: return ImagePickOutcome.Failed

        val root = context.filesDir?.parentFile ?: context.filesDir
        val targetDir = File(File(root, FLUTTER_DOCUMENTS_DIR), directoryName)
        if (!targetDir.exists() && !targetDir.mkdirs()) return ImagePickOutcome.Failed

        val fileName = LiveImagePickLogic.fileNameFor(filePrefix, context.contentResolver.getType(uri))
        val target = File(targetDir, fileName)
        target.writeBytes(payload)
        targetDir.listFiles()?.forEach { existing ->
            if (existing.isFile && LiveImagePickLogic.shouldDelete(existing.name, filePrefix, fileName)) {
                existing.delete()
            }
        }
        ImagePickOutcome.Stored(target.absolutePath)
    } catch (_: Exception) {
        ImagePickOutcome.Failed
    }
}

/** `path_provider` 在 Android 上的 documents 目录名。 */
private const val FLUTTER_DOCUMENTS_DIR = "app_flutter"

/**
 * 打开系统「勿扰权限」页面。
 *
 * 用 [Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS]（Dart 侧同样跳这个系统页）：
 * 「上课前快捷操作」选了勿扰 / 仅优先通知时，Android 要求用户在这里手工授权，
 * App 自己无法申请。**没有该页面**（个别 ROM 裁掉）时给一句话，不静默吞掉。
 */
private fun openDoNotDisturbAccess(context: Context, toast: (String) -> Unit) {
    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    val opened = runCatching { context.startActivity(intent) }.isSuccess
    if (!opened) toast(DisplaySettingsStrings.doNotDisturbAccessUnavailable.zh)
}

/** 壳与正式包共用的存储装配：`FlutterSharedPreferences` + 冻结键格式。 */
private fun liveDisplayStore(context: Context): LiveDisplayStore =
    LiveDisplayStore(TimetableStore(PrefsKeyValueStore(context)))
