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
import com.mutx163.qingyu.pages.diagnostics.LiveFixtureActions
import com.mutx163.qingyu.pages.import.ImportSharedModel
import com.mutx163.qingyu.pages.import.ImportStrings
import com.mutx163.qingyu.pages.live.DisplaySettingsPage
import com.mutx163.qingyu.pages.live.DisplaySettingsStrings
import com.mutx163.qingyu.pages.live.LiveDisplayStore
import com.mutx163.qingyu.pages.live.LiveImagePickLogic
import com.mutx163.qingyu.pages.live.LiveImagePickTarget
import com.mutx163.qingyu.pages.live.LiveReminderTimingPage
import com.mutx163.qingyu.pages.live.MiuiIslandExpandedIconMode
import com.mutx163.qingyu.pages.live.ReminderTimingState
import com.mutx163.qingyu.pages.live.withMiuiIslandExpandedIconMode
import com.mutx163.qingyu.pages.live.withMiuiIslandExpandedIconPath
import com.mutx163.qingyu.pages.live.withMiuiIslandLabelLogoPath
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

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
 * | 速览「试弹 / 停止」 | `triggerLiveStagePreviewTest` | **起不了岛**：Kotlin 侧没有原生触发管线，点了给一句实话（[LiveFixtureActions.TRIGGER_REFRESH_MISSING]），按钮不装成「正在跑」 |
 *
 * ## 为什么防抖而不是每次改动直接写
 *
 * 滑杆一次拖动会连发几十次 `onStateChange`，每次都 `commit()` 落盘等于主线程卡顿；
 * Dart 侧同样是 250ms 防抖 + 离开页面补写（`live_settings_subpages.dart:247-256 / :395-399`）。
 * 这里用 `LaunchedEffect(version)` 实现：`version` 一变就取消上一次待写任务。
 *
 * ## 速览为什么不做「假动画」
 *
 * 台账 §1.2：能力没到位不许装成能用。岛由原生 `LiveUpdateService` 弹，
 * 触发链（`live_testing_trigger.dart` 978 行）在 Kotlin 侧还没有对应物，
 * 所以按钮照常渲染、点了一句话说明差哪一步，**不翻成「停止测试」态**。
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
    /** 防抖写盘计数器：每次用户改动 +1，`LaunchedEffect` 随之重启待写任务。 */
    var version by remember { mutableStateOf(0) }
    /** 正在等选图结果的目标（选图是异步的，回调里才知道用户选没选）。 */
    var pendingPick by remember { mutableStateOf<LiveImagePickTarget?>(null) }
    val latestState by rememberUpdatedState(state)

    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    // 250ms 防抖：期间又改就取消上一次，只写最后一份。
    LaunchedEffect(version) {
        if (version == 0) return@LaunchedEffect
        delay(SAVE_DEBOUNCE_MILLIS)
        store.saveDisplay(latestState, forDuringEnd)
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
                        ImportSharedModel.formatByteBudget(ExternalImportReader.MAX_IMPORT_BYTES),
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
        // 选图是异步的：这里先登记目标并拉起系统选图，返回 null 让页面别自己改状态，
        // 真正的状态更新在选图回调里做（页面那份同步口径做不到异步选图）。
        onPickImage = { target ->
            pendingPick = target
            pickLauncher.launch(IMAGE_MIME)
            null
        },
        onOpenDoNotDisturbAccess = { openDoNotDisturbAccess(context, ::showToast) },
        // 起不了岛就给实话，不假装在跑（见类注释「速览为什么不做假动画」）。
        onStagePreviewStart = { showToast(LiveFixtureActions.TRIGGER_REFRESH_MISSING) },
        onStagePreviewStop = { showToast(LiveFixtureActions.TRIGGER_REFRESH_MISSING) },
        stagePreviewActive = false,
        stagePreviewBusy = false,
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
