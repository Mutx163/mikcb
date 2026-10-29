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
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.time.LocalDateTime

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
 * | 分享给别人 | `AndroidShareAdapter.share`（写 cacheDir → FileProvider → 系统分享面板） |
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
 *   它的入口是 Dart 通道形状的 `handle(MethodCall, …)`，所以这里按 Dart 同一份载荷契约
 *   （`calendarName` + `events[{startMs,endMs,title,location,description}]`）构造一次 `MethodCall`
 *   调它 —— 少一层平台通道，但不产生第二份日历写入实现。
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
        return { date ->
            val official = officialByYear[date.year]
            val entries = (official?.entries ?: emptyList()) + custom
            HolidayData(
                year = date.year,
                version = official?.version ?: 0,
                entries = entries,
            ).isHoliday(date.atStartOfDay())
        }
    }

    // ── 5. 运行期状态 ──
    var isExporting by remember { mutableStateOf(false) }
    var isSyncing by remember { mutableStateOf(false) }
    var isRemoving by remember { mutableStateOf(false) }
    var menuVisible by remember { mutableStateOf(false) }
    /** 已生成、等待「分享 / 保存」二选一的 `.ics` 正文（不落临时文件）。 */
    var pendingContent by remember { mutableStateOf<String?>(null) }
    var pendingCount by remember { mutableStateOf(0) }

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

    // ── 6. 导出：校验 → 收集 → 序列化 → 展开二选一菜单 ──
    val runExport: () -> Unit = {
        val opts = effectiveOptions
        when (IcsExportLogic.validate(selectedProfile, opts)) {
            IcsExportBlocker.NO_PROFILES -> toast(ExportStrings.icsExportNoProfiles.zh)
            IcsExportBlocker.NO_SELECTION -> toast(ExportStrings.icsExportNoSelection.zh)
            IcsExportBlocker.SEMESTER_START_REQUIRED ->
                toast(ExportStrings.icsExportSemesterStartRequired.zh)
            null -> {
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
    }

    // ── 7. 分享：写 cacheDir → FileProvider → 系统分享面板 ──
    val runShare: () -> Unit = {
        val content = pendingContent
        menuVisible = false
        if (content == null) {
            toast(ExportStrings.icsExportFailed.zh)
        } else {
            val profileName = selectedSource?.profileName.orEmpty()
            when (shareAdapter.share(content, profileName, effectiveOptions.fromDate, effectiveOptions.toDate)) {
                is IcsShareOutcome.Launched ->
                    toast(ExportStrings.icsExportShared.filled("count", pendingCount.toString()))
                is IcsShareOutcome.Failed -> toast(ExportStrings.icsExportFailed.zh)
            }
        }
        pendingContent = null
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

    val requestSync: () -> Unit = {
        if (CalendarSync.hasCalendarPermission(appContext)) {
            runSync()
        } else {
            permissionLauncher.launch(
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            )
        }
    }

    val requestRemove: () -> Unit = {
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
            // 换档案 ⇒ 区间回到新档案的默认学期区间（Dart `_handleProfileChanged`）。
            // 已经手改过区间的人，改完课表再看到的是「新档案的合理区间」，而不是上一份档案的。
            options = null
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
    )
}

/** `CalendarSync` 用这个码表示「系统拒绝（权限没拿到）」，见 `CalendarSync.handle` 的 catch 分支。 */
private const val PERMISSION_DENIED_CODE = "PERMISSION_DENIED"

/**
 * 调 [CalendarSync] 的既有实现（清旧 + 整批插入 / 删专属日历）。
 *
 * **为什么是 `MethodCall` 而不是一个 Kotlin 函数**：`CalendarSync` 的 public 入口只有
 * Dart 通道形状的 `handle(call, activity, context, result)`（`syncInternal` / `deleteLocalCalendar`
 * 都是 private）。本批的写作用域不包含 `CalendarSync.kt`（它是壳共享件，属别的批次/Lead），
 * 所以不去改它；这里按它**已经吃的那份载荷契约**构造一次 `MethodCall` 直接调，
 * 好处是日历写入只有一份实现，不会出现「Dart 走一条、Compose 走另一条」的双判据。
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
    val result = object : MethodChannel.Result {
        override fun success(result: Any?) {
            onSuccess(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            onError(errorCode)
        }

        override fun notImplemented() {
            onError("NOT_IMPLEMENTED")
        }
    }
    CalendarSync.handle(MethodCall(method, arguments), null, context, result)
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
