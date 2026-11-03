package com.mutx163.qingyu.app

import android.content.Context
import android.net.Uri
import android.util.Log
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.settings.AppearanceEditorBridge
import com.mutx163.qingyu.pages.settings.AppearanceEditorPreviewStrings
import com.mutx163.qingyu.pages.settings.AppearanceEditorScreen
import com.mutx163.qingyu.pages.settings.BingGalleryApplyPlanner
import com.mutx163.qingyu.pages.settings.BingGalleryDataSource
import com.mutx163.qingyu.pages.settings.BingGalleryDownloadResult
import com.mutx163.qingyu.pages.settings.BingGalleryDownloader
import com.mutx163.qingyu.pages.settings.BingWallpaperStore
import com.mutx163.qingyu.pages.settings.MaterialSheetBody
import com.mutx163.qingyu.pages.settings.MaterialSheetPages
import com.mutx163.qingyu.pages.settings.RECENT_WALLPAPER_UNDO_WINDOW_MS
import com.mutx163.qingyu.pages.settings.SelectionPageState
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsBingWallpaperGalleryPage
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.WallpaperAutoApplyLogic
import com.mutx163.qingyu.pages.settings.WallpaperEvictionSources
import com.mutx163.qingyu.pages.settings.WallpaperHistoryLedger
import com.mutx163.qingyu.pages.settings.WallpaperSheetBody
import com.mutx163.qingyu.pages.settings.WallpaperSheetIntent
import com.mutx163.qingyu.pages.settings.WallpaperSheetPages
import com.mutx163.qingyu.pages.settings.appearanceEditorResyncOnResume
import com.mutx163.qingyu.pages.settings.backdropFlowState
import com.mutx163.qingyu.pages.settings.parseWallpaperSheetTarget
import com.mutx163.qingyu.pages.settings.wallpaperSheetBottomGap
import com.mutx163.qingyu.pages.shell.HomeDockNavModel
import com.mutx163.qingyu.pages.shell.HomeGlassDock
import com.mutx163.qingyu.pages.shell.homeDockVisible
import com.mutx163.qingyu.pages.shell.rememberHomeDockUsesBackdrop
import com.mutx163.qingyu.pages.shell.rememberHomeFloatingInsets
import com.mutx163.qingyu.pages.shellTimetableMenuPageId
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.pages.timetable.day.DayAgendaEntry
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.DayViewPageData
import com.mutx163.qingyu.pages.timetable.day.DayViewSummaryLogic
import com.mutx163.qingyu.weather.BingAutoApplyDecision
import com.mutx163.qingyu.weather.DailyApplyOutcome
import com.mutx163.qingyu.weather.DailyWallpaperMapper
import com.mutx163.qingyu.weather.WallpaperTargetSize
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import java.io.File
import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
 * * 本页与其它设置页一样**即时落盘**：面板里改一下，预览与磁盘同时变；没有任何字段
 *   是「等到点完成才提交」的（「完成」不是提交按钮）；
 * * 「完成」= 把欠着的最后一档写完、确认真的进盘，再返回；**写不进去就不退**并提示
 *   `saveFailed`（见 [done] 的注释：这一点比 Dart 更严）；
 * * 「取消」= 把**进页那一刻的整份设置写回**再返回。不是「什么都不做」——因为改动
 *   早就落盘了，不做回滚的话按钮名与行为不符；防抖里欠着的那一档**丢弃不写**；
 * * 系统返回 = 取消（`BackHandler` 只在两个面板都关着时接管；面板开着时交给官方
 *   `OverlayBottomSheet` 自己关）。**退场缩放照播**：接管后不直接 `cancel()`，而是把
 *   那一下转交页面壳的 `requestExit`，与点「取消」逐字同路（2026-11-02 修「系统返回
 *   是闪现关闭、按钮退出才缩回」）。
 * * 落盘**每次都读回校验**：`store.save` 不抛异常也不返回失败（commit() 的布尔被丢了），
 *   所以写完必须重新 `load()` 一次、只比这次改动过的键；没落地就把草稿拉回盘上真值
 *   并提示 —— 不许出现「看着存了、其实没存」。
 *
 * ## 落盘节奏（`:622-631`）
 *
 * Dart 对滑杆给了 250ms 防抖、其余控件立即写。这里照做：滑杆行
 * （材质那三组八根旋钮、壁纸模糊）走 [APPEARANCE_EDITOR_SAVE_DEBOUNCE_MS] 防抖，
 * 其余立即写。**内存里的草稿永远立刻更新**（预览不延迟），防抖只影响写盘；
 * 取消 / 完成 / 推页 / 离开本页前会把欠着的那一档处理掉（取消是丢弃、其余是补写），
 * 不会丢最后一格。写盘本身是同步的 `SharedPreferences.commit()`，同一线程上天然串行
 * （Dart 那条 `_saveQueue` 在这里不需要另建一条队列）。
 *
 * ## 两个面板（`:777-919`）
 *
 * 两块面板都走共享套件 [QingyuSheet]（不是裸 `OverlayBottomSheet`）：左右 16 的内缩与
 * 底部「手势区 + 16」的让位口径由套件统一给，两个面板的数字不会各走各的。
 * 面板内容最多占屏高 **50%**（Dart `_materialSheetMaxHeightFactor = 0.5`，`:116-120`；
 * 壁纸面板同口径，`:839-841`），超出部分由面板内部自己滚——面板存在的意义就是
 * 「改一处、看预览」，长高到盖住卡片就失去意义了。
 *
 * 打开 / 收起全部由本宿主驱动（底部两颗圆钮 → [openWallpaper] / [openMaterial]；
 * 弹层返回键 / 点空白 → `onDismissRequest`），并且**每次打开都重建正文**、停在调用方
 * 指定的页签（Dart 每次开面板都是一条新弹层路由）。面板里要推整页的动作
 * （「调整位置」「每日壁纸」）先收起弹层再推 —— 否则新页会被弹层遮罩压住点不到
 * （Dart `_withHostSheetClosed`，`settings_home_backdrop_flow.dart:115-148`）。
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
 * 2. **「完成」写盘失败不退出**：见 [done]。Dart 是先 pop 再在 dispose 里补写
 *    （`:586-592`），失败时页面已拆、`reportSettingsPersistFailure` 因 `!mounted`
 *    直接吞掉，只留下一句没人看见的日志。这里改成先写、确认进盘才退；这是刻意比
 *    Dart 更严的一处；
 * 3. **壁纸「文件已丢失」警示仍由接线层填**：[SelectionPageState.fileMissing] 需要
 *    真实路径探测（Dart `homePageImageProvider`，`:873-881`），本宿主没有算它，
 *    所以那条警示行目前永远不出现。缩略图条本身已由 `WallpaperSheetBody` 绘制。
 * 4. **预览里的坞是「同组件、不同实例」**（2026-11-01 起卡片里有坞了）：坞由
 *    [HomeGlassDock] 画，与壳的栈底条目是同一份实现、同一份设置，所以排列 / 高亮 /
 *    圆钮 / 材质逐项一致；但它不是真机那一颗坞（各自一层玻璃采样），观感上允许有
 *    采样源差异。顶部菜单条目仍按空列表渲染（壳没把菜单注进预览）。
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
    // 草稿：一进页就从盘上读一份。
    var model by remember(store) { mutableStateOf(store.load()) }
    // 「取消」要回滚到的那份进页快照（`:179-182`）。
    //
    // ⚠️ 必须是 `rememberSaveable`，不能用普通 `remember`：从壁纸/材质面板推「调整位置」
    // 「每日壁纸」这类整页时，本页会被 NavDisplay 移出组合（被覆盖的条目不在可见窗口里，
    // 状态靠条目自己的 saveable holder 保存）。普通 `remember` 回来时会重新初始化成
    // 「回来那一刻」的值 ⇒ 取消只回滚回来之后的改动，推页前那几笔漏掉。
    var openedWith by rememberSaveable(store, stateSaver = TimetableSettingsModelSaver) {
        mutableStateOf(model)
    }
    // 深链接只消费一次：Dart `_pendingMaterialPage` 开过即清（`:243-247`、`:560`）。
    // 同样要 saveable —— 否则推页回来时会重新触发一次「自动打开弹层」。
    var deepLinkConsumed by rememberSaveable { mutableStateOf(false) }
    // 最近一次**确认已落盘**的模型：读回校验的「改动前」基准（见 [writeVerified]）。
    // 不需要 saveable：被移出组合后重新回来时，重新从盘上读就是正确的基准。
    var landed by remember(store) { mutableStateOf(model) }
    // 面板要读的值全部从设置模型推出来（逐键同源在 AppearanceEditorBridge，单测在那边）。
    val appearance = remember(model) { AppearanceEditorBridge.toState(model) }

    val context = LocalContext.current

    // ------------------------------------------------ 壁纸：设备级台账 + 执行体
    //
    // 开关与下载台账的真源是 `BingWallpaperStore`（设备级，不进课表设置，也不随备份走；
    // Dart `bing_wallpaper_store.dart:11-30`）。宿主从这里读快照喂面板，并在台账变更时
    // 递增 revision 触发重组 —— 弹层正文不在本页的 widget 树下，光靠 `model` 带不动它
    // （Dart 给那颗开关挂 `ValueListenableBuilder` 的同一理由，`:501-526`）。
    val bingStore = remember(context) { BingWallpaperStore(PrefsKeyValueStore(context)) }

    // 档案原始 JSON 的只读入口：删除壁纸前要拿到「其它档案内嵌的壁纸路径」。
    // 这些键不在仓储快照里——`TimetableProfile.settings` 只解析时间/周次四键
    //（`core/TimetableSettings.kt:22-27`），而盘上每份档案的 settings 是整份对象
    //（`app/TimetableStore.kt:111-115`）。与 bingStore 读的是同一份 `flutter.` 存储。
    val wallpaperProfilesPrefs = remember(context) { PrefsKeyValueStore(context) }
    var bingRevision by remember { mutableIntStateOf(0) }
    DisposableEffect(bingStore) {
        val listener = { bingRevision += 1 }
        bingStore.addListener(listener)
        onDispose { bingStore.removeListener(listener) }
    }
    val autoApplySnapshot = remember(bingStore, bingRevision) { bingStore.snapshot() }

    val bingSource = remember { BingGalleryDataSource() }
    // 受管壁纸目录与图库宿主同名（App 私有，卸载即清）。
    val wallpaperDir = remember(context) { File(context.filesDir, WALLPAPER_DIR_NAME) }
    val bingDownloader = remember(wallpaperDir) { BingGalleryDownloader(wallpaperDir) }
    val screenSize = remember(context) {
        val metrics = context.resources.displayMetrics
        WallpaperTargetSize(metrics.widthPixels, metrics.heightPixels)
    }
    // 删除排期**不挂在页面组合的 scope 上**：用户点完删除立刻退出本页时，文件仍应按时
    // 删掉（Dart 的 `Future.delayed` 也不随页面销毁取消）。任务 2.5 秒内自会结束。
    val wallpaperCleanupScope = remember {
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }

    // 「最近使用」删除的 2.5s 反悔窗（Dart `_pendingRemovals` / `_pendingBackdropDeletions`）：
    // 连删两张时两张都留在待删清单里，第二次删除**重新起算整窗**，到点整批删。
    val pendingRemovals = remember { mutableListOf<PendingWallpaperRemoval>() }
    val pendingDeletionPaths = remember { LinkedHashSet<String>() }
    var removalJob by remember { mutableStateOf<Job?>(null) }
    // `_exiting`（`:132`、`:702-727`）：连点「取消 / 完成 / 返回」时只认第一次，
    // 否则第二次会在已经退栈的页面上再退一层。
    var exiting by remember { mutableStateOf(false) }

    var materialSheet by remember { mutableStateOf(false) }
    var materialInitialPageIndex by remember { mutableIntStateOf(MaterialSheetPages.GENERAL) }
    // 弹层**每次打开**都重建正文（Dart 每次开面板都是新压一条弹层路由）：
    // 页签停回调用方指定的那一页，上一次的「已发起移除」等界面态也不会带过来。
    var materialSheetGeneration by remember { mutableIntStateOf(0) }
    var wallpaperSheet by remember { mutableStateOf(false) }
    var wallpaperInitialPageIndex by remember { mutableIntStateOf(WallpaperSheetPages.PICKER) }
    var wallpaperSheetGeneration by remember { mutableIntStateOf(0) }

    // 欠写的那一档 + 防抖任务（见类注释「落盘节奏」）。
    var pendingSave by remember { mutableStateOf<TimetableSettingsModel?>(null) }
    var saveJob by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()

    /** 一次提示（Dart `showAppToast` 的对应物；设置族宿主统一用系统 Toast）。 */
    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /**
     * 一次落盘 + **读回校验**，返回「这次改动真的进盘了」。
     *
     * 为什么不能只看 `store.save` 抛没抛：`PrefsKeyValueStore` 把
     * `SharedPreferences.commit()` 的布尔丢了 ⇒ 写失败既不抛异常也不返回 false
     * （`SettingsHost.saveVerified` 是同一条结论；那边是私有函数，这里按同口径再写一份，
     * 不跨文件去碰别人的写作用域）。
     *
     * 失败时把草稿拉回**盘上真值**并提示（Dart `reportSettingsPersistFailure(resetDraft)`，
     * `:656-664`）：界面不许停在「看着存了、其实没存」的状态。
     */
    fun writeVerified(next: TimetableSettingsModel): Boolean {
        val result = runCatching {
            store.save(next)
            store.load()
        }
        val disk = result.getOrNull()
        if (disk != null && SettingsActionDispatcher.persistLanded(landed, next, disk)) {
            landed = next
            return true
        }
        // 盘上那份就是「真正已生效」的值；读不到时退回本页已知的基准。
        val actual = disk ?: landed
        landed = actual
        model = actual
        Log.e(LOG_TAG, "appearance editor save did not land", result.exceptionOrNull())
        toast(SettingsStringsExt2.saveFailed.zh)
        return false
    }

    /** 把欠着的那一档写掉；没有欠档视为成功。 */
    fun flushPendingSave(): Boolean {
        val next = pendingSave ?: return true
        pendingSave = null
        return writeVerified(next)
    }

    /** 立刻写掉欠档（取消 / 完成 / 推页 / 离开本页前都用它）。 */
    fun persistNow(): Boolean {
        saveJob?.cancel()
        saveJob = null
        return flushPendingSave()
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

    /**
     * 删壁纸文件前的权威判定（**唯一口径**，见 [WallpaperEvictionSources.planEviction]）。
     *
     * 白名单四路：**所有档案**内嵌的壁纸路径 + 当前课表 + 本页草稿 + 图库台账。
     * 「其它档案」的路径只能从盘上 `timetable_profiles` 原始 JSON 读——仓储快照里的
     * `TimetableProfile.settings` 只解析时间 / 周次四键，没有壁纸键。
     *
     * 档案 JSON 读不懂时**一张都不删**（保守策略）：无法确认别的档案没在用，
     * 就不能拿残缺结果当白名单；只记一条日志说明跳过原因。
     */
    fun deleteWallpaperFiles(paths: List<String>) {
        if (paths.isEmpty()) return
        val profilesJson = try {
            wallpaperProfilesPrefs.getString(WallpaperEvictionSources.PROFILES_KEY)
        } catch (error: Exception) {
            Log.w(LOG_TAG, "wallpaper profile settings read failed", error)
            return
        }
        val currentPath = model.homePageWallpaperPath
        val galleryPaths = bingStore.snapshot().downloadedPaths
        wallpaperCleanupScope.launch {
            withContext(Dispatchers.IO) {
                val plan = WallpaperEvictionSources.planEviction(
                    evictedPaths = paths,
                    profilesJson = profilesJson,
                    currentPath = currentPath,
                    draftPath = currentPath,
                    galleryLedgerPaths = galleryPaths,
                )
                if (plan.profilesUnreadable) {
                    Log.w(LOG_TAG, "skip wallpaper deletion: profile settings unreadable")
                    return@withContext
                }
                for (path in plan.deletable) {
                    val deleted = runCatching { File(path).delete() }.getOrDefault(false)
                    if (!deleted) Log.w(LOG_TAG, "wallpaper file was not deleted: $path")
                }
            }
        }
    }

    /** 相册 URI → 受管壁纸目录；读不出来返回 null（取消 / 权限 / 空文件）。 */
    fun importPickedWallpaper(uri: Uri): String? {
        val bytes = runCatching {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        }.getOrNull()
        if (bytes == null || bytes.isEmpty()) return null
        val dir = wallpaperDir.apply { mkdirs() }
        val target = File(
            dir,
            "wallpaper_${System.currentTimeMillis()}.${wallpaperExtensionOf(context, uri)}",
        )
        return runCatching {
            target.writeBytes(bytes)
            target.absolutePath
        }.getOrNull()
    }

    /** 「选择图片」返回：先收进受管目录，再记历史 + 写路径与居中取景（Dart `:1007-1019`）。 */
    fun applyPickedWallpaper(uriText: String) {
        val uri = runCatching { Uri.parse(uriText) }.getOrNull() ?: return
        scope.launch {
            val path = withContext(Dispatchers.IO) { importPickedWallpaper(uri) }
            if (path == null) {
                toast(SettingsStringsExt2.saveFailed.zh)
                return@launch
            }
            val picked = WallpaperHistoryLedger.applyPicked(model, path) ?: return@launch
            commit(picked.settings, debounce = false)
            deleteWallpaperFiles(picked.evictedPaths)
        }
    }

    /** 切回「最近使用」里的一条：连取景三件一起还原（Dart `:294-316`）。 */
    fun applyHistorySelection(key: String) {
        val selected = WallpaperHistoryLedger.select(model, key) ?: return
        commit(selected.settings, debounce = false)
        deleteWallpaperFiles(selected.evictedPaths)
    }

    /**
     * 确认删除一条历史：摘条目并落盘，**2.5 秒后**再审一遍白名单删文件
     * （Dart `:325-354`）。
     *
     * 连删两张时第二下会把计时**重新起算整窗**（Dart `_scheduleBackdropFileDeletion`
     * 的同一口径）；到点一次删完整份待删清单，撤销只摘最后一张。
     */
    fun confirmHistoryRemoval(key: String) {
        val removal = WallpaperHistoryLedger.remove(model, key) ?: return
        commit(removal.settings, debounce = false)
        pendingRemovals.add(
            PendingWallpaperRemoval(
                path = removal.removedPath,
                previousHistory = removal.previousHistory,
            ),
        )
        pendingDeletionPaths.add(removal.removedPath)
        removalJob?.cancel()
        removalJob = wallpaperCleanupScope.launch {
            delay(RECENT_WALLPAPER_UNDO_WINDOW_MS)
            removalJob = null
            if (pendingDeletionPaths.isEmpty()) return@launch
            val paths = pendingDeletionPaths.toList()
            pendingDeletionPaths.clear()
            pendingRemovals.clear()
            deleteWallpaperFiles(paths)
        }
    }

    /** 撤销删除：整份旧历史原样放回，并把这张图从待删清单里摘掉（Dart `:356-378`）。 */
    fun undoHistoryRemoval(key: String) {
        val pending = pendingRemovals.lastOrNull() ?: return
        if (pending.path != key) return
        pendingRemovals.removeAt(pendingRemovals.lastIndex)
        pendingDeletionPaths.remove(pending.path)
        if (pendingDeletionPaths.isEmpty()) {
            removalJob?.cancel()
            removalJob = null
        }
        commit(WallpaperHistoryLedger.undo(model, pending.previousHistory), debounce = false)
    }

    /**
     * 打开自动换时**立刻换一次**（不等下次启动，Dart `:572-642`）。
     *
     * 四种结局各一句提示；只有真换上时才写设置（路径 + 居中取景，**不碰历史**）并回收
     * 台账溢出文件。整套判据在 [WallpaperAutoApplyLogic]，本函数只做 IO 与落盘。
     */
    fun runAutoApplyOnce() {
        scope.launch {
            val snapshot = bingStore.snapshot()
            val items = withContext(Dispatchers.IO) {
                runCatching { bingSource.fetch() }.getOrDefault(emptyList())
            }
            val newest = items.firstOrNull()
            if (newest == null) {
                WallpaperAutoApplyLogic.outcomeNotice(DailyApplyOutcome.Failed)
                    ?.let { toast(it.text.zh) }
                return@launch
            }
            if (WallpaperAutoApplyLogic.decide(snapshot, newest) is BingAutoApplyDecision.AlreadyApplied) {
                WallpaperAutoApplyLogic.outcomeNotice(DailyApplyOutcome.AlreadyApplied)
                    ?.let { toast(it.text.zh) }
                return@launch
            }
            val downloaded = withContext(Dispatchers.IO) {
                bingDownloader.download(newest, screenSize)
            }
            var evicted: List<String> = emptyList()
            val applied = when (downloaded) {
                is BingGalleryDownloadResult.Success -> {
                    val path = downloaded.file.absolutePath
                    val targetSize = BingGalleryApplyPlanner
                        .plan(newest, screenSize, downloaded.resolution)
                        .targetSize
                    evicted = bingStore.recordApplied(
                        dateKey = newest.dateKey,
                        resolution = downloaded.resolution,
                        path = path,
                        autoApplied = true,
                        targetSize = targetSize,
                    ).evictedPaths
                    DailyWallpaperMapper.fromBing(
                        WallpaperAutoApplyLogic.outcomeFor(newest, LocalDateTime.now()),
                        path,
                        newest.dateKey,
                    )
                }

                is BingGalleryDownloadResult.Failure -> DailyWallpaperMapper.fromBing(
                    BingAutoApplyDecision.Outcome.Failed,
                    null,
                    newest.dateKey,
                )
            }
            WallpaperAutoApplyLogic.outcomeNotice(applied.outcome, dateKey = applied.itemId)
                ?.let { toast(it.text.zh) }
            val next = WallpaperAutoApplyLogic.settingsAfterApply(model, applied.path)
            if (next != null) {
                // 先更新草稿 / 落盘，再走与手动删除**同一条**入口：
                // 白名单在 [deleteWallpaperFiles] 里统一组装（所有档案 + 当前/草稿 +
                // 图库台账），自动换与手动换不会各算一套。
                commit(next, debounce = false)
                deleteWallpaperFiles(evicted)
            }
        }
    }

    /**
     * 拨一次「每天自动更换」。
     *
     * 动作拆解与提示文案全在 [WallpaperAutoApplyLogic.togglePlan] / `toggleNotice`：
     * 打开 = 落盘 + 提示 + 立刻换一次；关闭 = 只落盘。开关真源是台账，**不走**草稿
     * （Dart `:537-555`，2026-10-06 实报「点了一下没反应」的根因）。
     */
    fun toggleAutoApply() {
        val snapshot = bingStore.snapshot()
        val newValue = !snapshot.enabled
        val plan = WallpaperAutoApplyLogic.togglePlan(snapshot.enabled, newValue)
        if (plan.persistEnabled) bingStore.setAutoApplyEnabled(newValue)
        if (plan.showApplying) toast(WallpaperAutoApplyLogic.toggleNotice().text.zh)
        if (plan.runApplyOnce) runAutoApplyOnce()
    }

    /**
     * 壁纸面板发来的数据动作 → 具体执行。
     *
     * 分派器只给原始 target（它不许碰 IO / pages.settings），解析与执行都在本宿主。
     * 行导航（相册 / 调整位置 / 图库）与「清除图片」不经过这里。
     */
    fun handleWallpaperTarget(target: String) {
        when (val intent = parseWallpaperSheetTarget(target)) {
            is WallpaperSheetIntent.Picked -> applyPickedWallpaper(intent.uri)
            is WallpaperSheetIntent.SelectHistory -> applyHistorySelection(intent.key)
            is WallpaperSheetIntent.ConfirmRemove -> confirmHistoryRemoval(intent.key)
            is WallpaperSheetIntent.UndoRemove -> undoHistoryRemoval(intent.key)
            WallpaperSheetIntent.ToggleAutoApply -> toggleAutoApply()
            else -> Log.w(LOG_TAG, "unhandled wallpaper target: $target")
        }
    }

    /** 开材质面板并停在指定页（每次打开都从该页重建正文）。 */
    fun openMaterial(page: Int) {
        materialInitialPageIndex = page.coerceIn(0, MaterialSheetPages.COUNT - 1)
        materialSheetGeneration++
        // 一块弹层只有一个位置：开这块就把另一块关掉，不叠着开。
        wallpaperSheet = false
        materialSheet = true
    }

    /** 开壁纸面板并停在指定页（理由同 [openMaterial]）。 */
    fun openWallpaper(page: Int) {
        wallpaperInitialPageIndex = page.coerceIn(0, WallpaperSheetPages.COUNT - 1)
        wallpaperSheetGeneration++
        materialSheet = false
        wallpaperSheet = true
    }

    /**
     * 取消：回滚到进页快照再返回（`:735-740`）。
     *
     * 与「完成后不退出」不同，取消**无论如何都要离开**：用户已经决定放弃这一页的改动，
     * 回滚写失败时提示一句就够（Dart `_popSelf` 同样不等回滚结果）。
     */
    fun cancel() {
        if (exiting) return
        exiting = true
        // Dart 取消时把防抖计时器直接 cancel（`:622-628` 之后走 `_updateDraft(_openedWith)`），
        // 那一档草稿**不写**：盘上最终只应留下进页快照。
        saveJob?.cancel()
        saveJob = null
        pendingSave = null
        // 本页退出后弹层不能继续压在新页面上（`:679-727`）。
        materialSheet = false
        wallpaperSheet = false
        if (model != openedWith) {
            model = openedWith
            writeVerified(openedWith)
        }
        onBack()
    }

    /**
     * 完成：把欠档写完 + 返回（`:672-675`）。
     *
     * **写盘没落地就不退出**：Dart 是先 pop、在 dispose 里补写（`:586-592`），
     * 失败提示此时页面已经拆掉、`mounted == false` 直接被吞掉 —— 用户看到的是
     * 「点了完成、设置没存、也没有任何提示」。这里改成先验证再退出：
     * 失败时留在本页、草稿拉回盘上真值并弹 `saveFailed`，可以让用户重试。
     * 这是**刻意比 Dart 更严**的一处，不是漏搬。
     */
    fun done() {
        if (exiting) return
        if (!persistNow()) return
        exiting = true
        materialSheet = false
        wallpaperSheet = false
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
            is SettingsDispatch.Write -> {
                val wallpaperTarget = dispatch.wallpaperTarget
                if (wallpaperTarget != null) {
                    // 壁纸数据动作：分派器刻意不写模型（要碰文件 / 网络 / 台账，见
                    // `SettingsActionDispatcher.wallpaperIntentTarget`），这里消费原始 target。
                    handleWallpaperTarget(wallpaperTarget)
                } else {
                    commit(dispatch.model, debounce = isDebouncedSliderRow(rowId))
                }
            }

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
                // 弹层里的「调整位置 / 每日壁纸」要推整页：**先收起宿主弹层再推**
                // （Dart `_withHostSheetClosed`，`settings_home_backdrop_flow.dart:115-148`）。
                // 弹层留着的话，新页会被它的遮罩压在下面、点不到 —— 原件 2026-09-20
                // 真机口径「页面在弹窗背后，什么都点不到」就是这件事。
                materialSheet = false
                wallpaperSheet = false
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

    // 回到页顶时把草稿对齐盘上真值（2026-11-03 用户实报「Bing 壁纸点应用，
    // 预览要点完成才变」）。
    //
    // 根因：Bing 图库 / 调整位置这类被本页推开的整页，应用结果直接 `store.save()`
    // 落盘、不经过本页草稿；而本页被覆盖期间**仍组合着**（miuix `NavDisplay` 可见
    // 窗口 `opaqueDepth = 1`，depth=1 的被覆盖页不销毁），返回后草稿还是旧内存值，
    // 预览（读草稿）就停在旧壁纸上——直到「完成」退出本页、首页按 `settingsRevision`
    // 重读盘才看到。
    //
    // 修法：NavDisplay 给每个条目发独立生命周期（页顶 RESUMED、被覆盖 STARTED，
    // 官方 `NavEntryLifecycle.kt` §5.3，经 `LocalLifecycleOwner` 注入本页）。监听
    // ON_RESUME：先补写欠档（防抖里那一档不丢），再读一次盘，与本页不同就把草稿
    // 对齐——预览与首页从此同一份真值，「应用」那一刻（落盘后立刻 pop 回本页）
    // 预览当场跟上，「完成」只负责收尾，不再承担刷新职责。
    val entryLifecycle = LocalLifecycleOwner.current
    DisposableEffect(entryLifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            if (event != Lifecycle.Event.ON_RESUME) return@LifecycleEventObserver
            if (!persistNow()) return@LifecycleEventObserver
            val resync = appearanceEditorResyncOnResume(
                disk = store.load(),
                draft = model,
                exiting = exiting,
            )
            if (resync != null) {
                model = resync
                // 盘上真值同时是「最近一次确认已落盘」的新基准（外部页写的键也要算数，
                // 否则下一次 writeVerified 的改动键比对会拿旧基准误判）。
                landed = resync
            }
        }
        entryLifecycle.lifecycle.addObserver(observer)
        onDispose { entryLifecycle.lifecycle.removeObserver(observer) }
    }

    // 系统返回 = 取消。面板开着时**不接管**：那一下应该先关面板（Dart 的 `_popSelf`
    // 也是先摘弹层再摘自己，`:702-727`）。
    //
    // ⚠️ 这里**不再直接调 [cancel]**：以前是直接 `cancel()`（立刻退栈），而页面壳的退场
    // 缩放只有点「取消 / 完成」才会播 ⇒ 系统返回是硬切、按钮退出是缩回，两条路两种观感
    // （2026-11-02 用户实报「系统返回是闪现关闭」）。现在只把「该不该接管」这个判据放在
    // 宿主（它才知道弹层开没开），退场动作交给页面壳的 `requestExit(onCancel)`
    // —— 系统返回与点「取消」从此逐字同一条路。
    val backExitEnabled = !materialSheet && !wallpaperSheet
    BackHandler(enabled = backExitEnabled) { /* 转交页面壳：见下方 requestBackExit */ }

    // 深链接：进页后自动打开面板并停在指定页（Dart 等转场落定才开，`:243-247`；
    // Compose 这里首帧之后开等价，面板本来就是根覆盖层条目、不参与页面转场）。
    //
    // 两块面板**互斥**：一块弹层一个位置，两个 initial* 同时非空时以材质优先（防守写法，
    // 正常调用不会同时给两个）。
    LaunchedEffect(initialMaterialPage, initialWallpaperPage) {
        // 只消费一次（见 [deepLinkConsumed] 的声明）。
        if (deepLinkConsumed) return@LaunchedEffect
        val materialPage = initialMaterialPage
        val wallpaperPage = initialWallpaperPage
        when {
            materialPage != null -> {
                deepLinkConsumed = true
                openMaterial(materialPage)
            }

            wallpaperPage != null -> {
                deepLinkConsumed = true
                openWallpaper(wallpaperPage)
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
            openWallpaper(WallpaperSheetPages.PICKER)
        },
        onMaterial = {
            openMaterial(MaterialSheetPages.GENERAL)
        },
        // 系统返回由页面壳接管（它才播得了退场缩放）：宿主只给「现在该不该接管」
        // —— 弹层开着时不接管，那一下留给官方 `OverlayBottomSheet` 关面板
        // （同上面那颗 `BackHandler` 的判据，两处共用同一个值）。
        requestBackExit = backExitEnabled,
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
        // 每次打开换一个 key ⇒ 正文整块重建：页签从调用方指定的那一页起，
        // 不会带着上一次打开时滑到的页 / 移除确认态（Dart 每次都是新弹层路由）。
        key(materialSheetGeneration) {
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
        key(wallpaperSheetGeneration) {
            WallpaperSheetBody(
                state = appearance,
                onAction = { action, target, rowId -> handleAction(action, target, rowId) },
                // 「最近使用」的选择态：壁纸键集合与当前壁纸都从同一份状态推出来；
                // `armedKey`（移除确认）属于缩略图条自己的界面态，见类注释「已知差异」第 3 条。
                selection = SelectionPageState(backdrop = backdropFlowState(appearance)),
                // 设备级台账快照：传了它就等于「真源已接」——开关显示真实值且可点，
                // 台账变更经 bingRevision 触发重组（见上方说明）。
                autoApplySnapshot = autoApplySnapshot,
                // 底部留白由**滚动内容**自己带（Dart `scrollableBottomGap`：系统手势区 + 16，
                // `miui_bottom_sheet.dart:448-458`）。宿主不垫：垫在视口外面会让内容永远滚不进去。
                contentPadding = wallpaperSheetBottomGap(),
                initialPage = wallpaperInitialPageIndex,
            )
        }
    }
}

/**
 * 卡片里那份**真首页**：课表页（周 = [TimetableHost]，日 = [DayViewPreview]）+ 玻璃坞。
 *
 * 为什么周视图不自己再抄一份 `TimetableWeekPage(...)` 的参数：那份喂法已经在
 * [TimetableHost] 里（设置 → 风格的映射、时间模板解析、当前周钳制、考试/日程、标题与
 * 菜单样式），抄第二份的唯一结果是两边迟早漂。日视图在壳里也只有一处喂法
 * （`ShellPageIndex` 的 `c3.day`），这里与它逐字同形。
 *
 * 坞走 [HomeGlassDock]（壳的栈底条目用的是同一个组件）—— 卡片与真机首页不会各画一份坞。
 *
 * 预览读的是**草稿** [settingsModel] ⇒ 面板里改材质/显示偏好，卡片当场跟着变。
 */
@Composable
private fun TimetablePreviewPage(
    dayView: Boolean,
    repository: TimetableRepository,
    settingsModel: TimetableSettingsModel,
) {
    // 预览卡 = **整个首页**：课表页（周 / 日）+ 玻璃坞。
    //
    // 坞走 [HomeGlassDock] —— 与壳的栈底条目**同一份实现**，所以卡片里的坞与真机首页逐参一致
    // （条目排列 / 高亮 / 圆钮图标 / 材质都读同一份草稿设置；拖材质滑杆卡片当场跟着变）。
    // 2026-11-01 之前卡片里没有坞：坞画在壳层、不在页面树里，这是用户报的「预览里没底栏」。
    Box(modifier = Modifier.fillMaxSize()) {
        val glassAvailable = isRuntimeShaderSupported()
        val dockBackdrop = rememberLayerBackdrop()
        // 坞要采样它底下的页面内容；没坞（classic 形态）/ 无 runtime shader 时不录
        // —— 与壳里 `recordBackdrop` 同一条纪律（录制 = 整屏离屏重绘一次）。
        // 同壳里那条：坞真的会采样才录（实体档时录了也没人用）。
        val recordDockBackdrop = glassAvailable && rememberHomeDockUsesBackdrop(settingsModel)
        Box(
            modifier = Modifier
                .fillMaxSize()
                .then(
                    if (recordDockBackdrop) Modifier.layerBackdrop(dockBackdrop) else Modifier,
                ),
        ) {
            if (dayView) {
                DayViewPreview(repository = repository, settingsModel = settingsModel)
            } else {
                TimetableHost(
                    repository = repository,
                    // 点击在页面壳那一层就被全部吞掉（`Modifier.consumeAllPointerEvents`），
                    // 这两个回调永远不会被调用；给空实现是为了让「预览不可操作」这件事只有一处真源。
                    onOpenAddCourse = { _, _ -> },
                    onOpenCourse = {},
                    settingsModel = settingsModel,
                    // 预览不接截屏监听：真首页那一份已经接上了，再来一份等于截一次屏
                    // 弹两次提示（Dart `_isPreview` 守卫，timetable_screen.dart:913-917）。
                    screenshotSharePromptEnabled = false,
                )
            }
        }
        HomeGlassDock(
            settingsModel = settingsModel,
            // 高亮跟着预览当前停的视图走：卡片就是「首页」，坞亮的自然是首页当前那一格。
            selectedId = if (dayView) {
                HomeDockNavModel.ACTION_DAY
            } else {
                HomeDockNavModel.ACTION_WEEK
            },
            // 「这个 id 点得开吗」用与壳同一张映射表（预览不交互，只为条目取舍与真机一致）。
            isNavigable = { id -> shellTimetableMenuPageId(id) != null },
            onSelect = {},
            onRoundButton = {},
            backdrop = if (glassAvailable) dockBackdrop else null,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

/**
 * 预览卡里的**日视图**：与壳的「日视图」页（`ShellPageIndex` 的 `c3.day`）逐字同形。
 *
 * 日视图要的是一份快照（周视图那份订阅在 `TimetableHost` 内部）：先读当前值再订阅，
 * 与仓储的通知语义一致（`observe` 只推后续变更，不会补推当前值）。
 */
@Composable
private fun DayViewPreview(
    repository: TimetableRepository,
    settingsModel: TimetableSettingsModel,
) {
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

    // 预览里的壁纸 / 材质：与真页面同一条推导（草稿模型 ⇒ 卡片当场跟着变）。
    val homeChrome = rememberHomeBackdropChrome(settingsModel)
    // 预览里的浮钮避让：与壳同一条（卡片里那颗坞就是同一个组件，占位也一样）。
    val floatingInsets = rememberHomeFloatingInsets(settingsModel)

    DayViewPage(
        initialWeek = snapshot.currentWeek.coerceAtLeast(1),
        initialDayOfWeek = initialDayOfWeek,
        visibleDays = visibleDays,
        totalWeeks = snapshot.settings.semesterWeekCount,
        // 壁纸层 + 材质快照 + 顶栏墨色（与壳里的 `c3.day` 同一份）。
        backdrop = homeChrome.backdrop,
        chromeInk = homeChrome.chromeInk,
        // 星期栏 / 空态压在壁纸上的字色（2026-11-01）。
        wallpaperBands = homeChrome.bands,
        material = homeChrome.material,
        hasBackdrop = homeChrome.hasBackdrop,
        pageColorArgb = homeChrome.pageColorArgb,
        floatingButtonBottomInset = floatingInsets.buttonBottom,
        contentBottomInset = floatingInsets.contentBottom,
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

/** 2.5 秒反悔窗里待删的那一张；撤销凭据是删除前的整份历史（Dart `:31-39`）。 */
private data class PendingWallpaperRemoval(
    val path: String,
    val previousHistory: List<WallpaperHistoryRowModel>,
)

/** 受管壁纸目录（与 `BingGalleryHost` 同名：App 私有，卸载即清，不进相册）。 */
private const val WALLPAPER_DIR_NAME = "wallpapers"

/**
 * 相册 URI 的落盘扩展名：先看 MIME，再看路径后缀，最后退回 png。
 *
 * 不用 `MimeTypeMap`：它需要平台映射表，而这层只要图片常见的几种；
 * 认不出来时 png 是安全的（解码只看内容，不看扩展名）。
 */
private fun wallpaperExtensionOf(context: Context, uri: Uri): String {
    val mime = runCatching { context.contentResolver.getType(uri) }.getOrNull()
    when (mime) {
        "image/jpeg" -> return "jpg"
        "image/png" -> return "png"
        "image/webp" -> return "webp"
        "image/gif" -> return "gif"
        "image/heic", "image/heif" -> return "heic"
    }
    val extension = uri.lastPathSegment
        ?.substringAfterLast('.', missingDelimiterValue = "")
        ?.lowercase()
        .orEmpty()
    return if (extension.length in 1..5 && extension.all { it.isLetterOrDigit() }) {
        extension
    } else {
        "png"
    }
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

/**
 * 进页快照的可保存形式：就是落盘用的那份 JSON patch。
 *
 * 只用来保住**本模型拥有的键**（取消时写回的也正是这些键），所以直接用
 * [TimetableSettingsModel.toJsonPatch] 往返，不另造一套序列化。
 * 需要它的原因：推整页时本页会被移出组合，普通 `remember` 的进页快照会丢。
 */
@Suppress("UNCHECKED_CAST")
private val TimetableSettingsModelSaver: Saver<TimetableSettingsModel, String> = Saver(
    save = { MiniJson.encode(it.toJsonPatch()) },
    restore = { json ->
        (MiniJson.tryParse(json) as? Map<String, Any?>)
            ?.let { TimetableSettingsModel.fromJson(it) }
    },
)

/** 两个面板的内容最多占屏高 50%（Dart `_materialSheetMaxHeightFactor = 0.5`，`:120`）。 */
private const val APPEARANCE_EDITOR_SHEET_MAX_HEIGHT_FACTOR = 0.5f

private const val LOG_TAG = "appearance-editor"
