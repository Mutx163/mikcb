package com.mutx163.qingyu.app

import android.Manifest
import android.content.Context
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.CalendarSync
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.platform.ResultSink
import com.mutx163.qingyu.calendar.HolidayPreferences
import com.mutx163.qingyu.pages.ShellWiring
import com.mutx163.qingyu.pages.export.ExportStrings
import com.mutx163.qingyu.pages.export.IcsCollectedEvents
import com.mutx163.qingyu.pages.export.IcsEventCollection
import com.mutx163.qingyu.pages.export.IcsExportBlocker
import com.mutx163.qingyu.pages.export.IcsExportLogic
import com.mutx163.qingyu.pages.export.IcsExportOptions
import com.mutx163.qingyu.pages.export.IcsExportPage
import com.mutx163.qingyu.pages.export.IcsExportProfile
import com.mutx163.qingyu.pages.export.IcsExportSource
import com.mutx163.qingyu.pages.export.IcsExportViewState
import com.mutx163.qingyu.pages.export.IcsShareLogic
import com.mutx163.qingyu.pages.export.IcsShareWiring
import com.mutx163.qingyu.platform.AndroidShareAdapter
import com.mutx163.qingyu.platform.IcsShareOutcome
import com.mutx163.qingyu.platform.IcsSharePreparation
import com.mutx163.qingyu.platform.IcsShareResultReceiver
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

/**
 * 「导出日历」页（`g3.icsExport`）的**真宿主**。
 *
 * ## 接的是什么（壳里原来是什么）
 *
 * 壳里原来的写法是 `IcsExportPage(viewState = IcsExportViewState(options = 写死的今天-7天..今天), 11 个空回调)`：
 * 课表下拉永远空（`profiles = emptyList()` ⇒ 显示「暂无可导出的课表」）、日期点了不动、
 * 导出/分享/保存/同步/移除**十一个动作一个都不通**。页面上能点的东西全是死的。
 *
 * 本宿主把回路接起来：
 *
 * | 控件 | 真落点 |
 * |---|---|
 * | 课表下拉 | 仓储快照里的档案（`snapshot.profiles`），换档案后按**该档案的学期**重算默认区间 |
 * | 开始/结束日期 | `IcsExportLogic.onFromDateChanged` / `onToDateChanged`（互相顶的规则在模型层） |
 * | 日历内容三勾选 | 模型层 `eventKinds`；勾了课程才出现「跳过节假日课程」 |
 * | 跳过节假日课程 | 本地假期数据（官方 + 自定义）+ 设置里的「假期标记」开关，与首页判据同源 |
 * | 导出并分享 | 收集事件 → 序列化 → 弹「分享 / 保存」二选一 |
 * | 分享给别人 | `AndroidShareAdapter.prepareShare` + `StartIntentSenderForResult` 拉起系统面板（选定目标 / 划掉取消 / 失败三种提示） |
 * | 保存到手机目录 | SAF `CreateDocument("text/calendar")` → `contentResolver.openOutputStream` |
 * | 同步到系统日历 | `CalendarSync` 的 ContentProvider 批处理（专属日历，幂等覆盖） |
 * | 移除已同步的日程 | `CalendarSync` 的 deleteCalendar（只删本应用账户下那个日历） |
 *
 * ## 为什么不新写一套能力
 *
 * - 事件收集：课程走 `transfer.collectCourseEvents`（已迁、有单测）；考试/日程由本批补在
 *   `pages/export/IcsEventCollection.kt`（纯 Kotlin、有单测）。宿主这里不做任何「算日期」的事。
 * - 分享与文件名：判据全在 `IcsShareLogic` / `IcsExportLogic`，适配器只照单执行。
 * - 系统日历：**不复制 CalendarProvider 逻辑**。`CalendarSync` 是现成的（清旧 + 整批插入同事务），
 *   它的入口是去 Flutter 依赖的原生 `handle(method, arguments, activity, context, ResultSink)`
 *   （2026-11-07 去 Flutter 化阶段 1 起），这里按 Dart 同一份载荷契约
 *   （`calendarName` + `events[{startMs,endMs,title,location,description}]`）直接调
 *   —— 不产生第二份日历写入实现。
 * - 权限：用 `rememberLauncherForActivityResult(RequestMultiplePermissions)` 在本页申请。
 *   `PagesShellActivity` 是 `ComponentActivity`，且仓内已有同款先例
 *   （`CoupleTimetableSettingsHost` 的 SAF 启动器），不需要改 Activity（那是 Lead 的文件）。
 *
 * ## 诚实边界（不假装能跑的部分）
 *
 * 1. **真机没对照过**：分享面板是否真的弹、目标应用能否导入 `.ics`、系统日历里是否出现
 *    「轻屿课表·xxx」日历，全部归用户验收（本批只到「编译通过 + JVM 单测通过」）。
 * 2. **权限被拒时说人话**：落到 `icsExportSyncCalendarPermissionDenied`（原文「未获得日历权限，
 *    请在系统设置中允许后重试」），**不**在权限没拿到时谎报「已同步 0 个日程」。
 * 3. **假期数据缺年**时不静默当成「全是假期」：拿不到官方条目且没有自定义条目 ⇒ 不过滤
 *    （`isHoliday = null`），宁可多导出几节课，也不把用户的课表导出成空文件。
 * 4. **不消费 `holidayOverrideEnabled`**（诊断页的假期模拟开关）：Dart 明确不继承它
 *    （`ics_export_screen.dart:481-490`），一旦继承，用户忘了关就会导出「一节课都没有」的日历。
 */
@Composable
fun IcsExportHost(
    wiring: ShellWiring,
    onBack: () -> Unit,
    today: LocalDate = LocalDate.now(),
) {
    val appContext = LocalContext.current.applicationContext
    val repository = wiring.timetable

    // 订阅语义与其它宿主一致：`observe` 订阅那一刻不推当前值，首帧先读 `snapshot`。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    // ── 1. 课表清单：档案 → 导出页需要的四个字段 ──
    val profileRows = remember(snapshot.profiles) {
        snapshot.profiles.map { profile ->
            IcsExportProfile(
                id = profile.id,
                name = profile.name,
                // 学期开始日/周数在档案自己的 settings 里（不是全局 settings），
                // 换档案后默认区间就该跟着换。
                semesterStartDate = profile.settings.semesterStartDate?.toLocalDate(),
                semesterWeekCount = profile.settings.semesterWeekCount,
            )
        }
    }
    var selectedProfileId by remember { mutableStateOf<String?>(null) }
    val effectiveProfileId = selectedProfileId
        ?: snapshot.activeProfileId?.takeIf { id -> profileRows.any { it.id == id } }
        ?: profileRows.firstOrNull()?.id
    val selectedProfile = profileRows.firstOrNull { it.id == effectiveProfileId }

    // ── 2. 表单状态：用户没动过时，区间按「当前档案的学期」实时派生 ──
    var options by remember { mutableStateOf<IcsExportOptions?>(null) }
    val derivedOptions = remember(selectedProfile, today) {
        val range = IcsExportLogic.defaultRangeFor(selectedProfile, today)
        IcsExportOptions(fromDate = range.from, toDate = range.to)
    }
    val effectiveOptions = options ?: derivedOptions

    // ── 3. 导出内容：选中档案的课程 / 考试 / 日程 ──
    val selectedSource: IcsExportSource? = remember(snapshot.profiles, effectiveProfileId) {
        snapshot.profiles.firstOrNull { it.id == effectiveProfileId }?.let { profile ->
            IcsExportSource(
                profileId = profile.id,
                profileName = profile.name,
                courses = profile.courses,
                exams = profile.exams,
                scheduleItems = profile.scheduleItems,
                semesterStartDate = profile.settings.semesterStartDate,
            )
        }
    }

    // ── 4. 假期判据：官方数据按年取 + 自定义条目合并（与 HolidayProvider.mergedData 同口径，
    //       区别只在这里要覆盖导出区间可能跨的年） ──
    val holidayPreferences = remember(appContext) { HolidayPreferences(PrefsKeyValueStore(appContext)) }
    val holidayMarkingEnabled = remember(wiring) {
        runCatching { wiring.settingsModel.load().enableHolidayMarking }.getOrDefault(true)
    }
    fun holidayFilter(from: LocalDate, to: LocalDate): ((LocalDate) -> Boolean)? {
        val custom = runCatching { holidayPreferences.loadCustomHolidays() }.getOrNull().orEmpty()
        val officialByYear = HashMap<Int, HolidayData?>()
        for (year in from.year..to.year) {
            officialByYear[year] = runCatching { holidayPreferences.loadYear(year) }.getOrNull()
        }
        // 一年数据都没有、也没有自定义假期 ⇒ 没有判据可用，返回 null（调用方不过滤）。
        if (custom.isEmpty() && officialByYear.values.all { it == null }) return null

        // 判据仍然只有一份：每天都问 `HolidayData.isHoliday`（自定义条目优先、调休上班日优先），
        // 本层不重写「哪天才算假期」。
        fun isHolidayDay(date: LocalDate): Boolean {
            val official = officialByYear[date.year]
            return HolidayData(
                year = date.year,
                version = official?.version ?: 0,
                entries = (official?.entries ?: emptyList()) + custom,
            ).isHoliday(date.atStartOfDay())
        }

        // 一次导出会问「这一天放假吗」成千上万次（每门课 × 每周），逐次拼列表既慢又吃内存，
        // 所以先把**区间内**的假期日算成一个集合；区间异常大时（用户手选十几年）退回逐日判定，
        // 宁可慢一点，也不静默丢掉节假日过滤。
        val days = ChronoUnit.DAYS.between(from, to) + 1
        if (days <= 0 || days > HOLIDAY_PRECOMPUTE_MAX_DAYS) {
            return { isHolidayDay(it) }
        }
        val holidayDates = HashSet<LocalDate>((days / 8).toInt() + 8)
        var cursor = from
        while (!cursor.isAfter(to)) {
            if (isHolidayDay(cursor)) holidayDates.add(cursor)
            cursor = cursor.plusDays(1)
        }
        return { it in holidayDates }
    }

    // ── 5. 运行期状态 ──
    var isExporting by remember { mutableStateOf(false) }
    var isSyncing by remember { mutableStateOf(false) }
    var isRemoving by remember { mutableStateOf(false) }
    var menuVisible by remember { mutableStateOf(false) }
    /** 已生成、等待「分享 / 保存」二选一的 `.ics` 正文（不落临时文件）。 */
    var pendingContent by remember { mutableStateOf<String?>(null) }
    var pendingCount by remember { mutableStateOf(0) }
    /** 同步前的一次性说明（Dart 只在首次同步时弹，确认后写 prefs）。 */
    var syncNoticeVisible by remember { mutableStateOf(false) }
    /** 移除已同步日程的确认（Dart 每次都问）。 */
    var removeConfirmVisible by remember { mutableStateOf(false) }

    // 与 Dart 共用的偏好存储（键名逐字一致，见 CALENDAR_SYNC_NOTICE_KEY）。
    val shellPreferences: KeyValueStore = remember(appContext) { PrefsKeyValueStore(appContext) }

    val toast: (String) -> Unit = { message ->
        Toast.makeText(appContext, message, Toast.LENGTH_LONG).show()
    }
    val shareAdapter = remember(appContext) { AndroidShareAdapter(appContext) }

    /** 按当前勾选收集事件；假期开关同时受「跳过节假日课程」与设置里的「假期标记」门控。 */
    fun collectEvents(): IcsCollectedEvents {
        val source = selectedSource ?: return IcsCollectedEvents(emptyList(), 0)
        val opts = effectiveOptions
        val filterEnabled = opts.skipHolidayCourses && holidayMarkingEnabled
        return IcsEventCollection.collect(
            source = source,
            kinds = opts.eventKinds,
            from = opts.fromDate,
            to = opts.toDate,
            skipHolidayCourses = filterEnabled,
            isHoliday = if (filterEnabled) holidayFilter(opts.fromDate, opts.toDate) else null,
        )
    }

    /**
     * 导出与「同步到系统日历」共用的前置校验（Dart `_export` 与 `_syncToSystemCalendar`
     * 的三条分支同源，见 `ics_export_screen.dart:442-466` / `:588-612`）。
     *
     * 通过才执行 [action]；不通过就按门栏种类给一句实话，**不做任何半截动作**。
     */
    fun runAfterValidation(action: () -> Unit) {
        when (IcsExportLogic.validate(selectedProfile, effectiveOptions)) {
            IcsExportBlocker.NO_PROFILES -> toast(ExportStrings.icsExportNoProfiles.zh)
            IcsExportBlocker.NO_SELECTION -> toast(ExportStrings.icsExportNoSelection.zh)
            IcsExportBlocker.SEMESTER_START_REQUIRED ->
                toast(ExportStrings.icsExportSemesterStartRequired.zh)
            null -> action()
        }
    }

    // ── 6. 导出：校验 → 收集 → 序列化 → 展开二选一菜单 ──
    val runExport: () -> Unit = {
        val opts = effectiveOptions
        runAfterValidation {
            isExporting = true
            try {
                val collected = collectEvents()
                if (collected.events.isEmpty()) {
                    // Dart 同口径：0 条事件不弹菜单，直接说清楚。
                    toast(ExportStrings.icsExportNoEvents.zh)
                } else {
                    val profileName = selectedSource?.profileName.orEmpty()
                    val request = IcsShareWiring.requestFromEvents(
                        calendarName = IcsEventCollection.exportCalendarName(
                            profileName,
                            opts.fromDate,
                            opts.toDate,
                        ),
                        fromDateTime = opts.fromDate.atStartOfDay(),
                        toDateTime = opts.toDate.atStartOfDay(),
                        generatedAt = LocalDateTime.now(),
                        events = collected.events,
                        applicationId = appContext.packageName,
                        profileName = profileName,
                        from = opts.fromDate,
                        to = opts.toDate,
                    )
                    pendingContent = request.content
                    pendingCount = collected.events.size
                    menuVisible = true
                }
            } catch (e: Exception) {
                toast(ExportStrings.icsExportFailed.zh)
            } finally {
                isExporting = false
            }
        }
    }

    // ── 7. 分享：写 cacheDir → FileProvider → 系统分享面板，关闭后用广播回执判结局 ──
    //
    // 2026-11-05：旧写法是 `context.startActivity(chooser)`，拿不到任何结果，用户把面板
    // 划掉之后一句提示都没有（Dart 会弹「已取消分享日历」，
    // `v2.1.4.1:lib/screens/ics_export_screen.dart:805-811`）。
    //
    // **判据不是 launcher 的 resultCode**：Android 选择器普遍恒回 `RESULT_CANCELED`，
    // 拿它当判据会把「分享成功」也说成取消。发布版用的 share_plus 同样不看 resultCode，
    // 而是给 `Intent.createChooser(intent, title, sender)` 挂一个广播 sender，
    // 由系统在用户真选定目标时投 `EXTRA_CHOSEN_COMPONENT`（本仓对位
    // `platform/IcsShareResultReceiver`）。launcher 只负责等「面板关了」这一下。

    /** 本次分享的回执通道是否可用（`prepareShare` 给出）；回调是异步的，先存住再读。 */
    var shareRelayAvailable by remember { mutableStateOf(false) }

    val shareLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { _ ->
        val outcome = shareAdapter.outcomeForClose(
            chosenComponent = IcsShareResultReceiver.take(),
            relayAvailable = shareRelayAvailable,
        )
        pendingContent = null
        menuVisible = false
        shareRelayAvailable = false
        when (outcome) {
            IcsShareOutcome.Shared ->
                toast(ExportStrings.icsExportShared.filled("count", pendingCount.toString()))
            IcsShareOutcome.Cancelled -> toast(ExportStrings.icsExportCancelled.zh)
            // 回执通道没接上（manifest 少一行接收器声明）：分不清取消与成功，宁可不说话。
            IcsShareOutcome.Unconfirmed -> Unit
            is IcsShareOutcome.Failed -> toast(ExportStrings.icsExportFailed.zh)
        }
    }

    val runShare: () -> Unit = {
        val content = pendingContent
        menuVisible = false
        if (content == null) {
            toast(ExportStrings.icsExportFailed.zh)
        } else {
            val profileName = selectedSource?.profileName.orEmpty()
            when (
                val prepared = shareAdapter.prepareShare(
                    content = content,
                    profileName = profileName,
                    from = effectiveOptions.fromDate,
                    to = effectiveOptions.toDate,
                )
            ) {
                is IcsSharePreparation.Failed -> {
                    // 拉起之前就失败（写文件 / FileProvider / Uri 形状）：与「取消」不同，报失败。
                    pendingContent = null
                    toast(ExportStrings.icsExportFailed.zh)
                }

                is IcsSharePreparation.Ready -> {
                    shareRelayAvailable = prepared.resultRelayAvailable
                    runCatching { shareLauncher.launch(prepared.chooser) }.onFailure {
                        // 没有能接 `text/calendar` 的应用 / 系统拒绝拉起：也报失败，不谎报取消。
                        shareRelayAvailable = false
                        pendingContent = null
                        toast(ExportStrings.icsExportFailed.zh)
                    }
                }
            }
        }
    }

    // ── 8. 保存：SAF（文本按 UTF-8 写进用户选的文件） ──
    val saveLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument(IcsShareLogic.MIME_TYPE_CALENDAR),
    ) { uri: Uri? ->
        val content = pendingContent
        pendingContent = null
        menuVisible = false
        if (uri == null || content == null) {
            toast(ExportStrings.icsExportSaveCancelled.zh)
        } else if (writeTextToUri(appContext, uri, content)) {
            toast(ExportStrings.icsExportSavedCount.filled("count", pendingCount.toString()))
        } else {
            toast(ExportStrings.icsExportSaveFailed.zh)
        }
    }

    // ── 9. 同步到系统日历 / 移除：都走 CalendarSync 的既有实现 ──
    val runSync: () -> Unit = {
        // 同步与导出**共用同一份区间/勾选口径**（Dart `collectEvents` 也是两条链路同源）。
        val collected = collectEvents()
        if (collected.events.isEmpty()) {
            toast(ExportStrings.icsExportNoEvents.zh)
        } else {
            isSyncing = true
            val calendarName = IcsExportLogic.syncCalendarName(selectedSource?.profileName.orEmpty())
            invokeCalendarSync(
                context = appContext,
                method = "sync",
                arguments = mapOf(
                    "calendarName" to calendarName,
                    "events" to IcsEventCollection.syncPayload(collected.events),
                ),
                onSuccess = { value ->
                    isSyncing = false
                    val count = (value as? Number)?.toInt() ?: 0
                    toast(IcsExportLogic.syncSuccessMessage(count, collected.skippedHolidayCourses))
                },
                onError = { code ->
                    isSyncing = false
                    toast(
                        if (code == PERMISSION_DENIED_CODE) {
                            ExportStrings.icsExportSyncCalendarPermissionDenied.zh
                        } else {
                            ExportStrings.icsExportSyncCalendarFailed.zh
                        },
                    )
                },
            )
        }
    }

    val runRemove: () -> Unit = {
        isRemoving = true
        invokeCalendarSync(
            context = appContext,
            method = "deleteCalendar",
            arguments = emptyMap(),
            onSuccess = { value ->
                isRemoving = false
                val deleted = value as? Boolean ?: false
                toast(
                    if (deleted) {
                        ExportStrings.icsExportRemoveCalendarSuccess.zh
                    } else {
                        // 从没同步过：`deleteLocalCalendar` 返回 false。
                        ExportStrings.icsExportRemoveCalendarNothing.zh
                    },
                )
            },
            onError = { code ->
                isRemoving = false
                toast(
                    if (code == PERMISSION_DENIED_CODE) {
                        ExportStrings.icsExportSyncCalendarPermissionDenied.zh
                    } else {
                        ExportStrings.icsExportRemoveCalendarFailed.zh
                    },
                )
            },
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        if (grants.isNotEmpty() && grants.values.all { granted -> granted }) {
            runSync()
        } else {
            toast(ExportStrings.icsExportSyncCalendarPermissionDenied.zh)
        }
    }

    /** 权限已拿到就直接同步；否则先申请（申请结果经 [permissionLauncher] 回到 `runSync`）。 */
    val proceedSync: () -> Unit = {
        if (CalendarSync.hasCalendarPermission(appContext)) {
            runSync()
        } else {
            permissionLauncher.launch(
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            )
        }
    }

    val requestSync: () -> Unit = {
        // 与 Dart 同序：先过三条校验（`ics_export_screen.dart:588-612`），再讲规则、再要权限。
        runAfterValidation {
            // Dart 只在**第一次**同步前讲清规则（覆盖语义 + 日历归属），确认过就写 prefs，
            // 之后按钮是一键直达（`ics_export_screen.dart:612-636`）。
            if (shellPreferences.getBool(CALENDAR_SYNC_NOTICE_KEY, false)) {
                proceedSync()
            } else {
                syncNoticeVisible = true
            }
        }
    }

    val requestRemove: () -> Unit = {
        // 删除是破坏性动作：Dart 每次都先确认（`_removeFromSystemCalendar` 无 prefs 豁免）。
        removeConfirmVisible = true
    }

    val confirmSyncNotice: () -> Unit = {
        syncNoticeVisible = false
        // 记不住也不拦本次同步（Dart 同样 `setBool` 后继续）：写失败只会导致下次再问一遍，
        // 比「以为记住了其实没记住」安全。
        runCatching { shellPreferences.putBool(CALENDAR_SYNC_NOTICE_KEY, true) }
        proceedSync()
    }

    val confirmRemove: () -> Unit = {
        removeConfirmVisible = false
        if (CalendarSync.hasCalendarPermission(appContext)) {
            runRemove()
        } else {
            // 删除也要 READ+WRITE；没有权限时如实说，不去系统里乱删。
            toast(ExportStrings.icsExportSyncCalendarPermissionDenied.zh)
        }
    }

    IcsExportPage(
        viewState = IcsExportViewState(
            profiles = profileRows,
            selectedProfileId = effectiveProfileId,
            options = effectiveOptions,
            isExporting = isExporting,
            isSyncing = isSyncing,
            isRemoving = isRemoving,
            exportActionMenuVisible = menuVisible,
            pendingEventCount = pendingCount,
        ),
        onBack = onBack,
        onSelectProfile = { id ->
            selectedProfileId = id
            // 换档案**只重算区间**：Dart `_handleProfileChanged` 只改 `_fromDate/_toDate`
            // （`ics_export_screen.dart:406-418`），用户勾过/取消过的「日历内容」与
            // 「跳过节假日课程」必须原样保留 —— 否则换个课表就把勾选悄悄改回默认值。
            val nextProfile = profileRows.firstOrNull { it.id == id }
            val range = IcsExportLogic.defaultRangeFor(nextProfile, today)
            options = effectiveOptions.copy(fromDate = range.from, toDate = range.to)
        },
        onFromDateChange = { date ->
            options = IcsExportLogic.onFromDateChanged(effectiveOptions, date)
        },
        onToDateChange = { date ->
            options = IcsExportLogic.onToDateChanged(effectiveOptions, date)
        },
        onToggleEventKind = { kind, enabled ->
            val kinds = if (enabled) {
                effectiveOptions.eventKinds + kind
            } else {
                effectiveOptions.eventKinds - kind
            }
            options = effectiveOptions.copy(eventKinds = kinds)
        },
        onSkipHolidayCoursesChange = { skip ->
            options = effectiveOptions.copy(skipHolidayCourses = skip)
        },
        onExport = runExport,
        onShareExported = runShare,
        onSaveExported = {
            val content = pendingContent
            if (content == null) {
                menuVisible = false
            } else {
                // Dart 先收起二选一菜单再弹系统保存框（`_handleExportAction` 先走退场再执行动作）；
                // 不收起的话保存框关掉后菜单还挂着，看起来像没生效。
                menuVisible = false
                saveLauncher.launch(
                    IcsExportLogic.buildFileName(
                        selectedSource?.profileName.orEmpty(),
                        effectiveOptions.fromDate,
                        effectiveOptions.toDate,
                    ),
                )
            }
        },
        onDismissExportMenu = {
            menuVisible = false
            pendingContent = null
        },
        onSyncCalendar = requestSync,
        onRemoveCalendar = requestRemove,
        syncNoticeVisible = syncNoticeVisible,
        onConfirmSyncNotice = confirmSyncNotice,
        onDismissSyncNotice = { syncNoticeVisible = false },
        removeConfirmVisible = removeConfirmVisible,
        onConfirmRemove = confirmRemove,
        onDismissRemoveConfirm = { removeConfirmVisible = false },
    )
}

/** `CalendarSync` 用这个码表示「系统拒绝（权限没拿到）」，见 `CalendarSync.handle` 的 catch 分支。 */
private const val PERMISSION_DENIED_CODE = "PERMISSION_DENIED"

/**
 * 假期日预计算的区间上限（天）。超过就退回「逐日问 `HolidayData.isHoliday`」。
 *
 * 3 年 ≈ 1100 天：正常学期/学年区间都在这以内；用户把日期手推到 1970~2100 时不至于
 * 一次点导出就扫两万天。
 */
private const val HOLIDAY_PRECOMPUTE_MAX_DAYS = 1100L

/**
 * 「同步前说明已确认过」的标记键（**与 Dart 同一个键**）。
 *
 * Dart：`ics_export_screen.dart:21` `ics_calendar_sync_notice_acknowledged_v1`。
 * 键名必须逐字一致：Dart 时代已经确认过的用户，切到 Compose 壳后不该再被问一次。
 */
private const val CALENDAR_SYNC_NOTICE_KEY = "ics_calendar_sync_notice_acknowledged_v1"

/**
 * 调 [CalendarSync] 的**原生入口**（去 Flutter 化阶段 1，2026-11-07）。
 *
 * 旧写法构造一次 `MethodCall` / `MethodChannel.Result` 去复用 Dart 通道形状；现在
 * [CalendarSync.handle] 已经是去 Flutter 依赖的原生入口（吃方法名 + 参数表 + [ResultSink]），
 * 这里直接调，**载荷契约不变**（`calendarName` + `events`），日历写入仍只有一份实现，
 * 不会出现「Dart 走一条、Compose 走另一条」的双判据。
 *
 * `activity` 传 `null`：`handle` 里只有 `requestPermission` 分支需要它，而权限由调用方
 * 用 `rememberLauncherForActivityResult` 申请（结果直接回到 Compose 的回调，不经过
 * `onRequestPermissionsResult`，因此 `PagesShellActivity` 无需转发）。
 */
private fun invokeCalendarSync(
    context: Context,
    method: String,
    arguments: Map<String, Any?>,
    onSuccess: (Any?) -> Unit,
    onError: (String?) -> Unit,
) {
    CalendarSync.handle(
        method = method,
        arguments = arguments,
        activity = null,
        context = context,
        result = object : ResultSink {
            override fun success(value: Any?) {
                onSuccess(value)
            }

            override fun error(code: String, message: String?, details: Any?) {
                onError(code)
            }

            override fun notImplemented() {
                onError("NOT_IMPLEMENTED")
            }
        },
    )
}

/**
 * 把文本写进 SAF 选中的 Uri（UTF-8）。
 *
 * `AndroidSafBackupAdapter.write` 是**备份 JSON 专用**（吃 `Map` 快照、走 `BackupFileWriteLogic`
 * 自校验），写不了 `.ics` 文本；所以这里不硬套它，只复用「SAF 选文件 + openOutputStream」
 * 这同一条机制。失败返回 false，调用方给 `icsExportSaveFailed`，不假装保存成功。
 */
private fun writeTextToUri(context: Context, uri: Uri, text: String): Boolean = try {
    context.contentResolver.openOutputStream(uri)?.use { stream ->
        stream.write(text.toByteArray(Charsets.UTF_8))
        stream.flush()
        true
    } ?: false
} catch (e: Exception) {
    false
}
