package com.mutx163.qingyu.pages

import android.content.Intent
import android.provider.Settings
import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.KeepAliveAccessibilityStatus
import com.mutx163.qingyu.app.AddTaskFormReducer
import com.mutx163.qingyu.app.SettingsHost
import com.mutx163.qingyu.app.WeeklyReportScheduleLogic
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.pages.about.AboutStaticPage
import com.mutx163.qingyu.pages.about.ChangelogPage
import com.mutx163.qingyu.pages.about.OpenSourceLicensesPage
import com.mutx163.qingyu.pages.about.SupportCreatorPage
import com.mutx163.qingyu.pages.conflict.CourseConflictPage
import com.mutx163.qingyu.pages.conflict.buildCourseConflictView
import com.mutx163.qingyu.pages.course.AddCourseEntryClock
import com.mutx163.qingyu.pages.course.AddCoursePage
import com.mutx163.qingyu.pages.course.CourseOverviewLogic
import com.mutx163.qingyu.pages.course.CourseOverviewPage
import com.mutx163.qingyu.infra.DiagnosticsLogSnapshot
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogViewport
import com.mutx163.qingyu.pages.diagnostics.LiveDiagnosticsLogPage
import com.mutx163.qingyu.pages.diagnostics.LiveTestingFixturePage
import com.mutx163.qingyu.pages.diagnostics.MemoryStatsPage
import com.mutx163.qingyu.pages.diagnostics.PerfReportPage
import com.mutx163.qingyu.pages.diagnostics.buildDiagnosticsLogViewState
import com.mutx163.qingyu.pages.diagnostics.buildLiveFixtureViewState
import com.mutx163.qingyu.pages.diagnostics.buildMemoryStatsViewState
import com.mutx163.qingyu.pages.diagnostics.buildPerfReportViewState
import com.mutx163.qingyu.pages.exam.AddExamPage
import com.mutx163.qingyu.pages.exam.AddExamViewState
import com.mutx163.qingyu.pages.exam.ExamListLogic
import com.mutx163.qingyu.pages.exam.ExamListPage
import com.mutx163.qingyu.pages.export.IcsExportOptions
import com.mutx163.qingyu.pages.export.IcsExportPage
import com.mutx163.qingyu.pages.export.IcsExportViewState
import com.mutx163.qingyu.pages.feedback.FeedbackPage
import com.mutx163.qingyu.pages.guide.HyperosShowcasePage
import com.mutx163.qingyu.pages.guide.MoreFeaturesPage
import com.mutx163.qingyu.pages.guide.MoreFeaturesSearchOverlay
import com.mutx163.qingyu.pages.guide.StartupFlowPage
import com.mutx163.qingyu.pages.guide.UserGuidePage
import com.mutx163.qingyu.pages.import.IcsImportPage
import com.mutx163.qingyu.pages.import.IcsImportViewState
import com.mutx163.qingyu.pages.import.ImportEntryPage
import com.mutx163.qingyu.pages.import.ImportEntryViewState
import com.mutx163.qingyu.pages.import.SpreadsheetImportPage
import com.mutx163.qingyu.pages.import.SpreadsheetImportViewState
import com.mutx163.qingyu.pages.import.warehouse.AiImageCourseImportPage
import com.mutx163.qingyu.pages.import.warehouse.WarehouseAdapterDetailPage
import com.mutx163.qingyu.pages.import.warehouse.WarehouseAdapterEntry
import com.mutx163.qingyu.pages.import.warehouse.WarehouseCourseImportPage
import com.mutx163.qingyu.pages.import.warehouse.WarehouseCustomDebugPage
import com.mutx163.qingyu.pages.import.warehouse.WarehouseSchoolAdaptersPage
import com.mutx163.qingyu.pages.import.warehouse.WarehouseSchoolEntry
import com.mutx163.qingyu.pages.import.warehouse.WarehouseWebLoginPage
import com.mutx163.qingyu.pages.import.warehouse.WarehouseWebLoginSessionState
import com.mutx163.qingyu.pages.import.warehouse.WarehouseWebLoginWebState
import com.mutx163.qingyu.pages.live.DisplaySettingsPage
import com.mutx163.qingyu.pages.live.LiveKeepAliveSettingsPage
import com.mutx163.qingyu.pages.live.LiveReminderTimingPage
import com.mutx163.qingyu.pages.schedule.AddScheduleItemPage
import com.mutx163.qingyu.pages.schedule.ScheduleDateRulePage
import com.mutx163.qingyu.pages.schedule.ScheduleItemData
import com.mutx163.qingyu.pages.schedule.ScheduleListEntry
import com.mutx163.qingyu.pages.schedule.ScheduleListGroups
import com.mutx163.qingyu.pages.schedule.ScheduleListPage
import com.mutx163.qingyu.pages.settings.BingGalleryState
import com.mutx163.qingyu.pages.settings.BackdropFlowState
import com.mutx163.qingyu.pages.settings.GlassDockEditorState
import com.mutx163.qingyu.pages.settings.RecentWallpaperState
import com.mutx163.qingyu.pages.settings.SettingsAppearanceEditorPage
import com.mutx163.qingyu.pages.settings.SettingsAppearancePage
import com.mutx163.qingyu.pages.settings.SettingsBackdropFlowPage
import com.mutx163.qingyu.pages.settings.SettingsBingWallpaperGalleryPage
import com.mutx163.qingyu.pages.settings.SettingsCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsDiagnosticsPage
import com.mutx163.qingyu.pages.settings.SettingsGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsGlassDockEditorPage
import com.mutx163.qingyu.pages.settings.SettingsGlassDockIconEditorPage
import com.mutx163.qingyu.pages.settings.SettingsHolidayAdvancedPage
import com.mutx163.qingyu.pages.settings.SettingsHolidayPage
import com.mutx163.qingyu.pages.settings.SettingsHomeMenuEditorPage
import com.mutx163.qingyu.pages.settings.SettingsHomeMenuEditorState
import com.mutx163.qingyu.pages.settings.SettingsHomeNavigationPage
import com.mutx163.qingyu.pages.settings.SettingsHomeNavigationState
import com.mutx163.qingyu.pages.settings.SettingsHomeWidgetPage
import com.mutx163.qingyu.pages.settings.SettingsHomeWidgetState
import com.mutx163.qingyu.pages.settings.SettingsLivePage
import com.mutx163.qingyu.pages.settings.SettingsLiveSelfCheckPage
import com.mutx163.qingyu.pages.settings.SettingsMaterialCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsMaterialGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsRecentWallpaperSection
import com.mutx163.qingyu.pages.settings.SettingsResetPage
import com.mutx163.qingyu.pages.settings.SettingsThemeManagePage
import com.mutx163.qingyu.pages.settings.SettingsTimetablePage
import com.mutx163.qingyu.pages.settings.SettingsTimetablePageSettingsPage
import com.mutx163.qingyu.pages.settings.TimetablePageSettingsState
import com.mutx163.qingyu.pages.settings.SettingsTimetableState
import com.mutx163.qingyu.pages.settings.SettingsWeatherPage
import com.mutx163.qingyu.pages.showcase.MiuixShowcasePage
import com.mutx163.qingyu.WeeklyReportScheduler
import com.mutx163.qingyu.pages.statistics.CourseStatisticsLogic
import com.mutx163.qingyu.pages.statistics.CourseStatisticsPage
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModule
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisPage
import com.mutx163.qingyu.pages.statistics.StatisticsFeed
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel
import com.mutx163.qingyu.pages.statistics.StatisticsSessionPage
import com.mutx163.qingyu.pages.statistics.StatisticsSettingsLogic
import com.mutx163.qingyu.pages.statistics.StatisticsSettingsPage
import com.mutx163.qingyu.pages.sync.CloudBackupListPage
import com.mutx163.qingyu.pages.sync.CloudBackupListViewState
import com.mutx163.qingyu.pages.sync.CloudSyncController
import com.mutx163.qingyu.pages.sync.CloudSyncLogic
import com.mutx163.qingyu.pages.sync.CloudSyncPage
import com.mutx163.qingyu.pages.sync.CloudSyncStatusSource
import com.mutx163.qingyu.pages.sync.CoupleBusyState
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsLogic
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsPage
import com.mutx163.qingyu.pages.sync.WebdavConnectSheet
import com.mutx163.qingyu.platform.AppLocalSnapshotStore
import com.mutx163.qingyu.platform.KeystoreSecretCipher
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.platform.WebdavConfigStoreImpl
import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.pages.task.AddTaskPage
import com.mutx163.qingyu.pages.task.AddTaskViewState
import com.mutx163.qingyu.pages.task.TaskDateFilter
import com.mutx163.qingyu.pages.task.TaskListViewState
import com.mutx163.qingyu.pages.task.TaskListPage
import com.mutx163.qingyu.pages.time_scheme.LocationTimeMatchModel
import com.mutx163.qingyu.pages.time_scheme.LocationTimeMatchPage
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeManagementModel
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeManagementPage
import com.mutx163.qingyu.pages.timetable.TimetableProfilesController
import com.mutx163.qingyu.pages.timetable.toastOrNull
import com.mutx163.qingyu.pages.timetable.TimetableProfilesPage
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
import com.mutx163.qingyu.pages.timetable.day.DayAgendaEntry
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.DayViewPageData
import com.mutx163.qingyu.pages.timetable.day.DayViewSummaryLogic
import com.mutx163.qingyu.pages.timetable.month.MonthViewHost
import com.mutx163.qingyu.pages.transfer.DataTransferPage
import com.mutx163.qingyu.pages.transfer.DataTransferViewState
import com.mutx163.qingyu.pages.transfer.LanEditModel
import com.mutx163.qingyu.pages.transfer.LanEditPage
import com.mutx163.qingyu.pages.transfer.PickupCodesPage
import com.mutx163.qingyu.pages.transfer.QrTransferSendHost
import com.mutx163.qingyu.pages.transfer.QrTransferScanHost
import com.mutx163.qingyu.pages.transfer.QrTransferSendSession
import com.mutx163.qingyu.pages.transfer.TransferOverviewInput
import com.mutx163.qingyu.pages.weather.WeatherCityPickerPage
import com.mutx163.qingyu.theme.QingyuTheme
import java.time.LocalDate
import java.time.LocalDateTime
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 页面索引的**分派层**：一个 id 一个 Composable。
 *
 * ## 这个文件解决的问题
 *
 * `composeUi` 壳原先只有三个槽位，75 个页面在真机上**点不进去**，L4（逐页对照）做不了。
 * 这里把 `ShellPageCatalog` 里的每一条接到它自己的 Composable 上；点索引里的一行，
 * 就由这里决定渲染谁。
 *
 * ## 三条接线纪律（本文件的全部争议点都在这里）
 *
 * 1. **能零参就零参**。页面自带默认值的，不喂任何数据——`ShellPageCatalog` 里标 `DIRECT`。
 * 2. **必须传视图状态的，喂「最小可用」的演示数据**，并且数据必须满足页面的前置条件
 *    （例如统计主页的 `tabs` 不能空、`selectedTabIndex` 不能越界），宁可少几块内容，
 *    也**不能让页面一点就崩**。这类在目录里标 `DEMO`，索引行上会写「演示数据」。
 * 3. **缺宿主能力的绝不造假**。二维码发送/扫码要求外部传 `qrSlot` / `cameraSlot`，
 *    仓库里既没有二维码编码器也没有相机依赖，所以它们**不在这里**——目录里标 `UNAVAILABLE`，
 *    索引行写清缺什么。造一个假二维码比不给入口更糟：用户会以为真能扫。
 *
 * ## 为什么演示数据的构建逻辑放这里而不是模型层
 *
 * 这些数据是「给壳看的壳数据」，没有任何业务语义（例如进度卡的 20 周、示例日程的三条），
 * 放进模型层会被误当成业务默认值。模型层只留真正的逻辑（`buildViewState` 之类）。
 */
@Composable
fun ShellPageContent(
    pageId: String,
    onBack: () -> Unit,
    wiring: ShellWiring,
    /** 页面内部要「推一个新页」时用它（路由字符串 → 壳页面 id 由 [shellPageIdForRoute] 负责）。 */
    onOpenPage: (String) -> Unit = {},
) {
    when (pageId) {
        // ── P3-A 关于与说明 ────────────────────────────────────────────
        "a.about" -> AboutStaticPage(onBack = onBack, onEntryClick = {})
        // 2026-10-28 补口：这一屏原先只有解析模型没有界面（台账虚标三处之一）。
        // 零参调用：页面自己去读 assets 里的发布说明。
        "a.changelog" -> ChangelogPage(onBack = onBack)
        "a.licenses" -> OpenSourceLicensesPage(
            packages = emptyList(),
            onBack = onBack,
            onOpenPackage = {},
            isLoading = false,
            loadError = null,
        )
        "a.support" -> SupportCreatorPage(
            donorData = null,
            onBack = onBack,
            onReload = {},
            onSaveQr = {},
            isLoading = false,
            loadError = null,
        )

        // ── P3-B 设置族（24 屏共用一个渲染层）─────────────────────────
        "b.settingsHome" -> SettingsScreen(SettingsTimetablePage.spec(SettingsTimetableState()), onBack)
        "b.semester" -> SettingsScreen(SettingsTimetablePage.semesterSpec(SettingsTimetableState()), onBack)
        // Phase 3.5 设置族第一刀：下面 4 页改用**真宿主**（真数据 + 真写回 + 真导航）。
        // 其余设置页仍是演示数据 —— 每接一页，就把它的 spec id 加进
        // `SettingsPageBridge.SUPPORTED_PAGE_IDS`，并在这里换成分派。
        "b.general" -> SettingsHost(
            pageId = SettingsGeneralPage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        "b.appearance" -> SettingsHost(
            pageId = SettingsAppearancePage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        "b.theme" -> SettingsHost(
            pageId = SettingsThemeManagePage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        "b.appearanceEditor" -> SettingsScreen(SettingsAppearanceEditorPage.spec(SettingsPageState()), onBack)
        "b.materialGeneral" -> SettingsScreen(SettingsMaterialGeneralPage.spec(SettingsPageState()), onBack)
        "b.materialCourseCard" -> SettingsScreen(SettingsMaterialCourseCardPage.spec(SettingsPageState()), onBack)
        "b.backdropFlow" -> SettingsScreen(SettingsBackdropFlowPage.settingsPage(BackdropFlowState()), onBack)
        "b.recentWallpaper" -> SettingsScreen(SettingsRecentWallpaperSection.spec(RecentWallpaperState()), onBack)
        "b.bingGallery" -> SettingsScreen(SettingsBingWallpaperGalleryPage.spec(BingGalleryState()), onBack)
        "b.homeWidget" -> SettingsScreen(SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()), onBack)
        "b.homeNavigation" -> SettingsScreen(SettingsHomeNavigationPage.spec(SettingsHomeNavigationState()), onBack)
        "b.homeMenuEditor" -> SettingsScreen(SettingsHomeMenuEditorPage.spec(SettingsHomeMenuEditorState()), onBack)
        "b.courseCard" -> SettingsHost(
            pageId = SettingsCourseCardPage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        // 2026-10-28 补口：这一屏原先只有入口行没有落点（台账虚标三处之一）。
        "b.timetablePage" -> SettingsScreen(
            SettingsTimetablePageSettingsPage.spec(TimetablePageSettingsState()),
            onBack,
        )
        "b.live" -> SettingsPageScreen(
            spec = SettingsLivePage.spec(SettingsPageState()),
            onBack = onBack,
            // 入口页 5 行都走 NAVIGATE：把 actionTarget（路由形态）映射成壳页面 id 再推页。
            // 原来这里是 no-op 的 SettingsScreen，导致整页点了全无反应。
            onAction = { _, target, _ -> target?.let { shellPageIdForRoute(it)?.let(onOpenPage) } },
        )
        "b.liveSelfCheck" -> SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)
        "b.holiday" -> SettingsScreen(SettingsHolidayPage.spec(SettingsPageState()), onBack)
        "b.holidayAdvanced" -> SettingsScreen(SettingsHolidayAdvancedPage.spec(SettingsPageState()), onBack)
        "b.weather" -> SettingsScreen(SettingsWeatherPage.spec(SettingsPageState()), onBack)
        "b.diagnostics" -> SettingsScreen(SettingsDiagnosticsPage.spec(SettingsPageState()), onBack)
        "b.glassDock" -> SettingsScreen(
            SettingsGlassDockEditorPage.spec(SettingsPageState(), GlassDockEditorState()),
            onBack,
        )
        "b.glassDockIcon" -> SettingsScreen(SettingsGlassDockIconEditorPage.spec(SettingsPageState()), onBack)
        "b.reset" -> SettingsScreen(SettingsResetPage.spec(SettingsPageState()), onBack)

        // ── P3-C1 课表 · 周视图 ────────────────────────────────────────
        // T1：与底部坞的课表槽位共用同一份接线（含课程操作弹层），两个入口行为一致。
        "c1.week" -> TimetableWithCourseActions(wiring = wiring, onNavigate = onOpenPage)
        "c1.profiles" -> {
            val repository = wiring.timetable
            // 订阅照仓储 KDoc：先读 snapshot 拿初值，再 observe（与 TimetableWithCourseActions 同一套）。
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            val controller = remember(repository) { TimetableProfilesController(repository) }
            var toast by remember { mutableStateOf<String?>(null) }

            TimetableProfilesPage(
                // ⚠️ 用 `snapshot` 当 key：`items()` 内部读的是仓储当前值，
                // 不读这个被观察的 state 就不会随变更重组——页面会**停在首次的旧列表上**，
                // 表现为「新建/切换点了没反应」，其实数据已经写进去了。
                profiles = remember(snapshot) { controller.items() },
                onBack = onBack,
                onCreateProfile = { name -> toast = controller.createProfile(name).toastOrNull() },
                onSwitchProfile = { id -> toast = controller.switchProfile(id).toastOrNull() },
                onRenameProfile = { id, newName ->
                    toast = controller.renameProfile(id, newName).toastOrNull()
                },
                onDuplicateProfile = { id -> toast = controller.duplicateProfile(id).toastOrNull() },
                onClearCourses = { id -> toast = controller.clearCourses(id).toastOrNull() },
                onDeleteProfile = { id -> toast = controller.deleteProfile(id).toastOrNull() },
                // 「成没成 / 为什么没成」由控制器算好，壳只负责把字符串放上去——
                // 不在壳里另写一套判据（那会是第二份判据）。
                toastMessage = toast,
                onDismissToast = { toast = null },
            )
        }

        // ── P3-C2 课表 · 月视图 ────────────────────────────────────────
        "c2.month" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            MonthViewHost(
                snapshot = snapshot,
                onAddCourse = { date ->
                    wiring.pendingAddCourseSeed = Pair(date.dayOfWeek.value, 1)
                    wiring.pendingEditCourse = null
                    onOpenPage("d1.addCourse")
                },
            )
        }

        // ── P3-C3 课表 · 日视图 ────────────────────────────────────────
        "c3.day" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            DayViewPage(
                initialWeek = snapshot.currentWeek.coerceAtLeast(1),
                initialDayOfWeek = LocalDate.now().dayOfWeek.value,
                dataProvider = { week, dayOfWeek ->
                    val dayCourses = snapshot.courses.filter { c ->
                        c.dayOfWeek == dayOfWeek && c.isActiveInWeek(week)
                    }
                    DayViewPageData(
                        summaryState = DayViewSummaryLogic.buildSummaryState(
                            week = week,
                            dateLabel = "第 $week 周 · 周$dayOfWeek",
                            isToday = week == snapshot.currentWeek && dayOfWeek == LocalDate.now().dayOfWeek.value,
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
                onCloseToWeekView = onBack,
                onOpenCourse = { courseId ->
                    wiring.pendingEditCourse = snapshot.courses.firstOrNull { it.id == courseId }
                    wiring.pendingAddCourseSeed = null
                    onOpenPage("d1.addCourse")
                },
            )
        }

        // ── P3-D1 课程表单与概览 ───────────────────────────────────────
        // Phase 3.5：这一页改成**真接线**——周次表与节数取自仓储快照，
        // 保存回调真的写进仓储（以前 `onSave` 是默认的空实现，所以点了「保存」什么也不发生）。
        "d1.addCourse" -> {
            val snapshot = wiring.timetable.snapshot
            AddCoursePage(
                initialCourse = wiring.pendingEditCourse,
                initialDayOfWeek = wiring.pendingAddCourseSeed?.first,
                initialStartSection = wiring.pendingAddCourseSeed?.second,
                availableWeeks = (1..snapshot.settings.semesterWeekCount.coerceAtLeast(1)).toList(),
                globalSectionCount = snapshot.settings.sections.size,
                // 表单要一个「节次 → 起止时间」的解析器；优先用**用户自己的作息表**，
                // 拿不到才退回壳里的线性示例（08:00 起每节 45+10 分）。
                clockResolver = { entry ->
                    val sections = snapshot.settings.sections
                    val index = (entry.startSection - 1).coerceAtLeast(0)
                    val section = sections.getOrNull(index)
                    if (section != null) {
                        AddCourseEntryClock(startTime = section.startTime, endTime = section.endTime)
                    } else {
                        val startMinutes = 8 * 60 + index * 55
                        AddCourseEntryClock(
                            startTime = clockText(startMinutes),
                            endTime = clockText(startMinutes + 45),
                        )
                    }
                },
                onSave = { payload ->
                    wiring.applyAddCourseSave(payload)
                    wiring.clearAddCourseIntent()
                    onBack()
                },
                onDelete = {
                    // 确认弹窗由 AddCoursePage 自己渲染（`AddCoursePage.kt:556-580`），
                    // 这里只在用户确认后执行删除；失败则留在页面上（Dart 口径：不报成功、不关页）。
                    if (wiring.deleteEditingCourse()) {
                        wiring.clearAddCourseIntent()
                        onBack()
                    }
                },
                onBack = {
                    wiring.clearAddCourseIntent()
                    onBack()
                },
            )
        }
        "d1.overview" -> CourseOverviewPage(
            viewState = CourseOverviewLogic.buildViewState(emptyList(), emptyMap()),
            onBack = onBack,
            onAddCourse = {},
            onOpenGroup = {},
            onOpenConflictDetail = {},
            onSortModeSelected = {},
        )

        // ── P3-D2 日程与任务 ──────────────────────────────────────────
        "d2.scheduleList" -> ScheduleListPage(
            groups = shellSampleScheduleGroups(),
            onBack = onBack,
            onAddSchedule = {},
            onEditSchedule = {},
            onDeleteSchedule = {},
        )
        "d2.addSchedule" -> AddScheduleItemPage(
            onBack = onBack,
            onSave = { _, _ -> },
            onDelete = { _, _ -> },
        )
        "d2.dateRule" -> ScheduleDateRulePage(
            rules = emptyList(),
            availableSchemes = emptyList(),
            onBack = onBack,
            onSaveRule = {},
            onDeleteRule = {},
        )
        "d2.taskList" -> TaskListPage(
            viewState = shellSampleTaskViewState(),
            onBack = onBack,
            onDateFilterChange = {},
            onCourseFilterClick = {},
            onAddTask = {},
            onEditTask = {},
            onToggleTask = {},
            onDeleteTask = {},
        )
        // T1 收尾：作业表单接上真状态机。
        // 之前这里是 `AddTaskViewState(isEditing = false, title = "")` 写死 + 全部回调空 `{}`
        // ⇒ 从课程操作弹层点「作业」进来，课程不会被预选，表单也不能输入/保存。
        // 现在：预选课程（+ 那节课的发生日期作为默认到期日）由 `AddTaskFormReducer.initial`
        // 算好，回调接到同一个状态机上，保存真写 `TimetableCourseService.addTask`。
        "d2.addTask" -> {
            val taskSnapshot = wiring.timetable.snapshot
            val preselectedCourse = wiring.pendingTaskCourse
            var taskForm by remember(preselectedCourse?.id) {
                mutableStateOf(
                    AddTaskFormReducer.initial(
                        preselectedCourse = preselectedCourse,
                        sourceWeek = taskSnapshot.currentWeek,
                        courseOccurrenceDate = preselectedCourse?.let {
                            wiring.timetable.dateForCourseOccurrence(it, taskSnapshot.currentWeek)
                        },
                    ),
                )
            }
            AddTaskPage(
                viewState = taskForm,
                onBack = onBack,
                onTitleChange = { taskForm = AddTaskFormReducer.withTitle(taskForm, it) },
                onNoteChange = { taskForm = AddTaskFormReducer.withNote(taskForm, it) },
                // task-18：两个子弹层的**候选数据 + 处理函数**（弹层由页面自己弹）。
                // 页面用「回调是否为 null」判断弹不弹：不接就维持「点了不动」的旧行为，
                // **而不是弹一个空弹层**——把死入口伪装成活入口比不弹更糟。
                courseOptions = AddTaskFormReducer.coursePickerOptions(
                    wiring.timetable.snapshot.courses,
                    taskForm.courseId,
                ),
                onCourseOptionPicked = { id ->
                    taskForm = AddTaskFormReducer.applyPickedCourseOption(
                        taskForm,
                        wiring.timetable.snapshot.courses,
                        id,
                    )
                },
                onDueDatePicked = { date -> taskForm = AddTaskFormReducer.withDueDate(taskForm, date) },
                onDueDateCleared = { taskForm = AddTaskFormReducer.withHasDueDate(taskForm, false) },
                onPickCourseClick = {},
                onHasDueDateChange = { taskForm = AddTaskFormReducer.withHasDueDate(taskForm, it) },
                onPickDueDateClick = {},
                onCompletedChange = { taskForm = AddTaskFormReducer.withCompleted(taskForm, it) },
                onSave = {
                    val titleError = AddTaskFormReducer.validate(taskForm)
                    if (titleError != null) {
                        taskForm = taskForm.copy(titleError = titleError)
                    } else {
                        TimetableCourseService.addTask(
                            wiring.timetable,
                            AddTaskFormReducer.buildTask(taskForm),
                        )
                        wiring.pendingTaskCourse = null
                        onBack()
                    }
                },
            )
        }

        // ── P3-D3 作息与考试 ──────────────────────────────────────────
        "d3.timeSchemes" -> TimeSchemeManagementPage(
            model = TimeSchemeManagementModel(),
            onBack = onBack,
            onCreate = {},
            onOpenScheme = {},
            onMenuAction = { _, _ -> },
            onOpenLocationEntry = {},
            onOpenDateRules = {},
        )
        "d3.locationMatch" -> LocationTimeMatchPage(
            model = LocationTimeMatchModel(),
            onBack = onBack,
            onCreateGroup = {},
            onEditGroup = {},
            onDeleteGroup = {},
            onToggleGroup = { _, _ -> },
            onApplyActive = {},
        )
        "d3.addExam" -> AddExamPage(
            viewState = AddExamViewState(isEditing = false),
            selectedCourse = null,
            courseGroupsEmpty = false,
            dateDisplayText = "",
            locationHintText = "",
            onBack = onBack,
            onSave = {},
            onDelete = {},
            onNameChange = {},
            onPickCourse = {},
            onPickDate = {},
            onPickStartTime = {},
            onPickEndTime = {},
            onLocationChange = {},
            onSeatChange = {},
            onNoteChange = {},
            onReminderPresetChange = {},
            onAddCustomReminder = {},
            onEditCustomReminder = {},
            onRemoveCustomReminder = {},
        )
        "d3.examList" -> ExamListPage(
            viewState = ExamListLogic.buildListViewState(
                exams = emptyList(),
                courses = emptyList(),
                semesterStart = null,
                now = LocalDateTime.now(),
            ),
            onBack = onBack,
            onAddExam = {},
            onOpenExam = {},
            onDeleteExam = {},
        )

        // ── P3-E 统计族 ───────────────────────────────────────────────
        "e.statistics" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            // 壳内局部状态：分段（学期/周）与周视图选中的周。
            var semesterView by remember { mutableStateOf(true) }
            var selectedWeek by remember { mutableStateOf<Int?>(null) }
            // 一次装配两份状态——`StatisticsFeed` 的 KDoc 明说必须同源，
            // 否则「主页说 3 门课、明细页只有一个可选」这类不一致会天天出现。
            val feedState = remember(snapshot, semesterView, selectedWeek) {
                StatisticsFeed.feed(
                    input = StatisticsFeed.Input.fromSnapshot(snapshot),
                    now = LocalDateTime.now(),
                    selectedWeek = selectedWeek,
                    semesterView = semesterView,
                )
            }
            CourseStatisticsPage(
                viewState = feedState.home,
                onBack = onBack,
                // tab 0 = 学期视图（`CourseStatisticsPage.kt:170` `selectedTabIndex == 0 && semester != null`）
                onTabSelected = { index -> semesterView = index == 0 },
                onOpenSettings = { onOpenPage("e.statisticsSettings") },
                // ⚠️ **链缺口**（交付方核实）：Kotlin 侧没有「统计图导出并分享」的实现
                // （Dart 走 `StatisticsShareService.exportAndShare`：光栅化 + 系统分享），
                // 而仓库里现有的分享适配器只管**日历/文件**，不是画图。
                // ⇒ 这里**有意留空**并记录为待办；**不塞假动作**让它看起来接完了。
                onOpenShare = {},
                onWeekChanged = { week -> selectedWeek = week },
                onOpenAnalysis = { module ->
                    wiring.pendingAnalysisModule = module
                    onOpenPage("e.analysis")
                },
                onOpenSessions = { onOpenPage("e.session") },
            )
        }
        "e.statisticsSettings" -> {
            StatisticsSettingsPage(
                viewState = StatisticsSettingsLogic.buildViewState(
                    // 走 `WeeklyReportScheduler.isEnabled`（本次新加的公开读访问器）——
                    // **不复制 prefs 键名**：键名是 private，复制会形成一份无守卫的隐式契约，
                    // 哪天那边改了键名或默认值，这里会静默读成 false（用户开着、界面显示关着）。
                    weeklyReportEnabled = WeeklyReportScheduler.isEnabled(wiring.context),
                    now = LocalDateTime.now(),
                ),
                onBack = onBack,
                // `scheduleNext` 要的四个参数由 `WeeklyReportScheduleLogic` 算（纯逻辑，JVM 可测）：
                // 触发时刻逐字对齐 Dart `weekly_report_service.dart:23-34`（**每周日 21:00**，
                // 「已到点」也算已到点、顺延一周）；标题/正文对齐 `:36` / `:38-71`。
                // 统计数字**不重算**——复用已交付的 `statistics/StatisticsService`。
                onWeeklyReportToggle = { enabled ->
                    if (enabled) {
                        val now = LocalDateTime.now()
                        val snap = wiring.timetable.snapshot
                        WeeklyReportScheduler.scheduleNext(
                            context = wiring.context,
                            enabled = true,
                            fireAtMillis = WeeklyReportScheduleLogic.nextFireAtMillis(now),
                            title = WeeklyReportScheduleLogic.buildTitle(),
                            body = WeeklyReportScheduleLogic.buildBody(
                                courses = snap.courses,
                                currentWeek = snap.currentWeek,
                                semesterWeekCount = snap.settings.semesterWeekCount,
                            ),
                        )
                    } else {
                        WeeklyReportScheduler.cancel(wiring.context)
                    }
                },
            )
        }
        "e.analysis" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            val feedState = remember(snapshot) {
                StatisticsFeed.feed(
                    input = StatisticsFeed.Input.fromSnapshot(snapshot),
                    now = LocalDateTime.now(),
                )
            }
            StatisticsAnalysisPage(
                viewState = StatisticsAnalysisModel.viewState(
                    module = wiring.pendingAnalysisModule,
                    courseCount = feedState.courseCount,
                ),
                onBack = onBack,
                // ⚠️ 页面签名里 `onOpenCourse` 的默认实现就是空的（普查第 6 个盲区：
                // 「只扫显式空回调」扫不到签名默认值）⇒ 点课程名进该课明细**尚不可用**。
                // 有意不在这里塞一个空 lambda 冒充「已接」，等明细页选中态可复用后再接。
            )
        }
        "e.session" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            var selectedCourse by remember { mutableStateOf<String?>(null) }
            val feedState = remember(snapshot, selectedCourse) {
                StatisticsFeed.feed(
                    input = StatisticsFeed.Input.fromSnapshot(snapshot),
                    now = LocalDateTime.now(),
                    previousSelection = selectedCourse,
                )
            }
            StatisticsSessionPage(
                viewState = feedState.session,
                onBack = onBack,
                onSelectCourse = { name -> selectedCourse = name },
            )
        }

        // ── P3-F 同步与备份 ───────────────────────────────────────────
        // ── P3-F 同步与备份（控制器驱动；task-22 `f39bcd11`） ─────────────
        // 以前这里传的是**写死的假 viewState + 16 个空回调** ⇒ 整页是死的。
        "f.cloudSync" -> {
            val context = LocalContext.current
            val configStore = remember(context) {
                WebdavConfigStoreImpl(
                    store = PrefsKeyValueStore(context),
                    cipher = KeystoreSecretCipher(),
                )
            }
            val controller = remember(configStore) {
                CloudSyncController(
                    store = configStore,
                    snapshotStore = AppLocalSnapshotStore(context),
                    deviceLabel = configStore.readDeviceLabel() ?: "Compose 壳",
                )
            }
            var showConnect by remember { mutableStateOf(false) }
            CloudSyncPage(
                controller = controller,
                onBack = onBack,
                onConnect = { showConnect = true },
                // ⚠️ 备份详情/恢复 sheet 本批不做 ⇒ 点某条备份**只会提示、不会打开详情**。
                // 按「不许假装」的标准，这里给一句诚实的提示而不是空 lambda（空 lambda
                // 会让用户以为是自己点歪了）。真正的详情 sheet 是下一批。
                onOpenBackup = {
                    Toast.makeText(context, "备份详情尚未开放", Toast.LENGTH_SHORT).show()
                },
                onViewAllBackups = { onOpenPage("f.backupList") },
            )
            if (showConnect) {
                WebdavConnectSheet(
                    initialUsername = controller.config.username,
                    testing = false,
                    connecting = false,
                    onTestConnection = { u, p ->
                        if (!controller.testConnection(u, p)) {
                            Toast.makeText(context, "连接测试失败", Toast.LENGTH_SHORT).show()
                        }
                    },
                    onConfirm = { u, p ->
                        controller.connect(u, p)
                        showConnect = false
                    },
                    onCancel = { showConnect = false },
                )
            }
        }
        "f.backupList" -> {
            val context = LocalContext.current
            val configStore = remember(context) {
                WebdavConfigStoreImpl(
                    store = PrefsKeyValueStore(context),
                    cipher = KeystoreSecretCipher(),
                )
            }
            val controller = remember(configStore) {
                CloudSyncController(
                    store = configStore,
                    snapshotStore = AppLocalSnapshotStore(context),
                    deviceLabel = configStore.readDeviceLabel() ?: "Compose 壳",
                )
            }
            CloudBackupListPage(
                controller = controller,
                onBack = onBack,
                onOpenBackup = {
                    Toast.makeText(context, "备份详情尚未开放", Toast.LENGTH_SHORT).show()
                },
            )
        }
        "f.couple" -> CoupleTimetableSettingsPage(
            viewState = CoupleTimetableSettingsLogic.buildViewState(
                binding = null,
                webdavConfig = CoupleWebdavConfig(),
                hasStoredPassword = false,
                busy = CoupleBusyState(),
                partnerCourseCount = 0,
                partnerProfileName = null,
                myWeek = 1,
                partnerWeek = 1,
            ),
            onBack = onBack,
            onAction = {},
            onShiftWeekOffset = {},
            onPickColor = { _, _ -> },
        )

        // ── P3-G1 导入 · 基础 ────────────────────────────────────────
        "g1.importEntry" -> ImportEntryPage(
            viewState = ImportEntryViewState(),
            onBack = onBack,
            onToggleRandomColors = {},
            onPickColorGroup = {},
            onOpenDestination = {},
        )
        "g1.icsImport" -> IcsImportPage(
            viewState = IcsImportViewState(),
            onBack = onBack,
            onChooseFile = {},
        )
        "g1.spreadsheetImport" -> SpreadsheetImportPage(
            viewState = SpreadsheetImportViewState(),
            onBack = onBack,
            onDownloadTemplate = {},
            onChooseFile = {},
        )

        // ── P3-G2 导入 · 仓库适配 ────────────────────────────────────
        "g2.schoolAdapters" -> WarehouseSchoolAdaptersPage(
            school = SHELL_DEMO_SCHOOL,
            adapters = emptyList(),
            onBack = onBack,
        )
        "g2.adapterDetail" -> WarehouseAdapterDetailPage(
            school = SHELL_DEMO_SCHOOL,
            adapter = SHELL_DEMO_ADAPTER,
            onBack = onBack,
        )
        "g2.warehouseImport" -> WarehouseCourseImportPage(onBack = onBack)
        "g2.webLogin" -> {
            // I2（`383df743`）：以前这里传的是空 `sessionState`，`currentUrl` 为空 ⇒
            // 宿主按设计「空地址不加载任何东西」⇒ **白屏**。所以必须给一个可加载地址。
            //
            // ⚠️ `SHELL_DEMO_LOGIN_URL` 只是**开发壳的占位地址**：`WarehouseSchoolEntry`
            // 目前**没有 URL 字段**（学校条目只带名字与适配器标识），真正的教务地址要等
            // 那个字段落地后从条目里取。用 `example.com` 是因为它是 IANA 保留的示例域、
            // 永远可解析，不会指向任何真实学校站点。
            var webLoginState by remember {
                mutableStateOf(WarehouseWebLoginSessionState(currentUrl = SHELL_DEMO_LOGIN_URL))
            }
            WarehouseWebLoginPage(
                title = SHELL_DEMO_SCHOOL.name,
                sessionState = webLoginState,
                onBack = onBack,
                onWebProgress = { progress ->
                    webLoginState = webLoginState.withStage(
                        WarehouseWebLoginWebState.stageForProgress(progress),
                    )
                },
                onWebPageStarted = { url -> webLoginState = webLoginState.copy(currentUrl = url) },
                onWebPageFinished = { url -> webLoginState = webLoginState.copy(currentUrl = url) },
                onWebError = { error ->
                    webLoginState = webLoginState.withStage(
                        newStage = WarehouseWebLoginWebState.stageForError(),
                        // ⚠️ 已知缺口：`importCleartextBlockedHint` 在 ARB 里有、但 `WarehouseStrings.kt`
                        // 里没有对应成员（那个文件不在本批写作用域）⇒ 这里取不到中文文案，
                        // 回落到系统原文。**不是漏写，是缺件**；补 ARB 成员后把 `null` 换掉即可。
                        error = WarehouseWebLoginWebState.errorText(error) { null },
                    )
                },
                // 已过消息门禁（UI 类消息只在导入执行期放行，见交付方的源码级守卫）。
                // 真正「收到消息后做什么」属导入执行链路，另一个批次。
                onWebBridgeMessage = { /* 导入执行链路未接，见 I2 认领文件 §7 */ },
            )
        }
        "g2.customDebug" -> WarehouseCustomDebugPage(onBack = onBack)
        "g2.aiImageImport" -> AiImageCourseImportPage(onBack = onBack)

        // ── P3-G3 导出与传输 ──────────────────────────────────────────
        "g3.dataTransfer" -> {
            val repository = wiring.timetable
            val snapshot = repository.snapshot
            val activeProfile = snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
                ?: snapshot.profiles.firstOrNull()
            DataTransferPage(
                viewState = DataTransferViewState(
                    overview = TransferOverviewInput(
                        courseCount = snapshot.courses.size,
                        activeProfileName = activeProfile?.name,
                        profileCount = snapshot.profiles.size,
                        timeSchemeCount = 1,
                        currentWeek = snapshot.currentWeek,
                        semesterStartDate = snapshot.settings.semesterStartDate?.toLocalDate(),
                    ),
                ),
                onBack = onBack,
                onExportCurrent = {},
                onExportAllData = {},
                onExportTimeTemplate = {},
                onOpenIcsExport = { onOpenPage("g3.icsExport") },
                onChooseFileAndImport = {},
                onQrSend = { _, _ -> onOpenPage("g3.qrSend") },
                onQrSendAll = { onOpenPage("g3.qrSend") },
                onQrScan = { onOpenPage("g3.qrScan") },
                onUndo = {},
            )
        }
        "g3.qrSend" -> {
            val repository = wiring.timetable
            val snapshot = repository.snapshot
            val activeProfile = snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
                ?: snapshot.profiles.firstOrNull()
            val profileName = activeProfile?.name ?: "默认课表"
            val payload = remember(profileName) {
                "QingyuTimetable:$profileName".toByteArray(Charsets.UTF_8)
            }
            val session = remember(payload) {
                QrTransferSendSession.prepare(payload)
            }
            QrTransferSendHost(
                session = session,
                onBack = onBack,
                onStop = onBack,
            )
        }
        "g3.qrScan" -> {
            QrTransferScanHost(
                onBack = onBack,
                onImportFullBackup = {
                    onBack()
                },
            )
        }
        "g3.icsExport" -> IcsExportPage(
            viewState = IcsExportViewState(
                options = IcsExportOptions(
                    fromDate = LocalDate.now().minusDays(7),
                    toDate = LocalDate.now(),
                ),
            ),
            onBack = onBack,
            onSelectProfile = {},
            onFromDateChange = {},
            onToDateChange = {},
            onToggleEventKind = { _, _ -> },
            onSkipHolidayCoursesChange = {},
            onExport = {},
            onShareExported = {},
            onSaveExported = {},
            onDismissExportMenu = {},
            onSyncCalendar = {},
            onRemoveCalendar = {},
        )
        "g3.lanEdit" -> LanEditPage(
            model = LanEditModel(),
            onBack = onBack,
            onToggleRunning = {},
            onCopyAddress = {},
            onKeepAliveChange = {},
        )
        "g3.pickupCodes" -> PickupCodesPage(
            onBack = onBack,
            onEntryClick = {},
        )

        // ── P3-H 诊断与测试夹具 ──────────────────────────────────────
        "h.log" -> LiveDiagnosticsLogPage(
            viewState = buildDiagnosticsLogViewState(
                title = "实时诊断日志",
                parsed = DiagnosticsLogSnapshot.EMPTY,
                viewport = DiagnosticsLogViewport(),
            ),
            onBack = onBack,
            onSelectLevel = {},
            onLoadEarlier = {},
            onToggleEntry = {},
            onToggleDeviceInfo = {},
            onViewModeChange = {},
            onTimeSortChange = {},
            onCopy = {},
            onExport = {},
            onClear = {},
        )
        "h.memory" -> MemoryStatsPage(
            viewState = buildMemoryStatsViewState(
                snapshot = null,
                autoRefreshEnabled = false,
                refreshIntervalSeconds = 0,
                lastRefreshedAt = null,
            ),
            onBack = onBack,
            onRefresh = {},
            onCopyJson = {},
            onToggleAutoRefresh = {},
            onOpenPerfReport = {},
        )
        "h.perfReport" -> PerfReportPage(
            viewState = buildPerfReportViewState(snapshot = null),
            onBack = onBack,
            onRefresh = {},
            onExport = {},
            onClearLedger = {},
            onToggleRaw = {},
            onCopyTextReport = {},
            onCopyJson = {},
        )
        "h.fixture" -> LiveTestingFixturePage(
            viewState = buildLiveFixtureViewState(
                sections = emptyList(),
                courses = emptyList(),
                activeSchemeName = null,
                now = LocalDateTime.now(),
            ),
            onBack = onBack,
            onInstall = {},
            onClear = {},
            onSelectLead = {},
            onTriggerSection = { _, _ -> },
        )

        // ── P3-I 引导与展示 ──────────────────────────────────────────
        "i.startup" -> StartupFlowPage(onBack = onBack)
        "i.userGuide" -> UserGuidePage(onBack = onBack)
        "i.more" -> MoreFeaturesWithSearch(onBack = onBack)
        "i.moreSearch" -> MoreFeaturesSearchOverlay(
            onDismiss = onBack,
            onSelectFeature = {},
        )
        "i.hyperosShowcase" -> HyperosShowcasePage(onBack = onBack)

        // ── P3-I2 Miuix 展示册 ───────────────────────────────────────
        "i2.showcase" -> MiuixShowcasePage(onBack = onBack)

        // ── P3-J 实时活动与天气 ──────────────────────────────────────
        // j.live 现在指向**忠实重建的显示设置页**（原 LiveSettingsPage 是错位的演示壳，已弃用）。
        "j.live" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
        "j.displayBefore" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
        "j.displayDuring" -> DisplaySettingsPage(forDuringEnd = true, onBack = onBack)
        "j.reminderTiming" -> LiveReminderTimingPage(onBack = onBack)
        // 2026-10-28 补口：这一屏原先只有入口行没有落点（台账虚标三处之一）。
        // 走**状态化重载**而不是零参重载：零参重载的探测回调恒返回「未开启」，
        // 那样 L4 只看得到一种状态，「已开启（绿勾 + 整行不可点）」那一支永远对不上。
        // 所以无障碍状态读平台真值。
        // 「从最近任务中隐藏」现在**真落盘**：与 MainActivity/LiveUpdateService 同一份 prefs
        // （`native_runtime_prefs` / `hide_from_recents`），并真实应用到 appTasks。
        "j.keepAlive" -> {
            val context = LocalContext.current
            val initialHideFromRecents = remember {
                context.getSharedPreferences("native_runtime_prefs", android.content.Context.MODE_PRIVATE)
                    .getBoolean("hide_from_recents", false)
            }
            LiveKeepAliveSettingsPage(
                initialState = com.mutx163.qingyu.pages.live.LiveKeepAliveState(
                    hideFromRecents = initialHideFromRecents,
                ),
                onBack = onBack,
                onPersistHideFromRecents = { hidden ->
                    runCatching {
                        context.getSharedPreferences("native_runtime_prefs", android.content.Context.MODE_PRIVATE)
                            .edit().putBoolean("hide_from_recents", hidden).apply()
                        val am = context.getSystemService(android.content.Context.ACTIVITY_SERVICE) as? android.app.ActivityManager
                        am?.appTasks?.forEach { it.setExcludeFromRecents(hidden) }
                        true
                    }.getOrDefault(false)
                },
                onProbeAccessibilityEnabled = { KeepAliveAccessibilityStatus.isEnabled(context) },
                onOpenAccessibilitySettings = {
                    // 壳里点「去开启」也要真的能跳到系统无障碍设置页，否则对照不了
                    // 「点完回来状态变了」这条路径。取不到目标页时静默失败，不崩壳。
                    runCatching {
                        context.startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    }
                },
            )
        }
        "j.weatherCity" -> WeatherCityPickerPage(
            onBack = onBack,
            onSelectCity = {},
        )

        // ── P3-K 冲突与反馈 ──────────────────────────────────────────
        "k.conflict" -> CourseConflictPage(
            view = buildCourseConflictView(emptyList()),
            onBack = onBack,
        )
        "k.feedback" -> FeedbackPage(onBack = onBack)

        // 目录里登记了、分派里没接：**宁可明确报错，也不要静默显示空白**
        else -> ShellMissingPage(pageId = pageId, onBack = onBack)
    }
}

/** 设置族 24 屏的统一入口：spec 由各页的模型层给，这里只负责壳的返回与空行为。 */
@Composable
private fun SettingsScreen(
    spec: com.mutx163.qingyu.pages.settings.SettingsPageSpec,
    onBack: () -> Unit,
) {
    SettingsPageScreen(
        spec = spec,
        onBack = onBack,
        // 写回与弹层由宿主接：壳里没有持久化层，点了不该崩，只当无操作。
        onAction = { _, _, _ -> },
    )
}

/**
 * 「全部功能」页 + 它自己的搜索浮层。
 *
 * 搜索浮层是同一页的组件（不是独立路由），所以在这里持有它的开关状态：
 * 点搜索胶囊 → 浮层盖上来；浮层里选一项 → 关掉浮层回目录。
 */
@Composable
private fun MoreFeaturesWithSearch(onBack: () -> Unit) {
    var searchOpen by remember { mutableStateOf(false) }
    MoreFeaturesPage(
        onBack = onBack,
        onOpenSearch = { searchOpen = true },
        onOpenFeature = {},
    )
    if (searchOpen) {
        MoreFeaturesSearchOverlay(
            onDismiss = { searchOpen = false },
            onSelectFeature = { searchOpen = false },
        )
    }
}

/** 分派漏了 id 时的兜底页：把 id 显示出来，方便定位是目录还是分派没对齐。 */
@Composable
private fun ShellMissingPage(pageId: String, onBack: () -> Unit) {
    val dark = isSystemInDarkTheme()
    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TopAppBar(
                title = "页面未接线",
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                },
            )
            QingyuCard(
                modifier = Modifier.fillMaxSize(),
                insideMargin = PaddingValues(14.dp),
            ) {
                Text(
                    text = "索引里有 `$pageId`，但分派层没有对应分支。",
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = "这是接线漏了，不是页面坏了。请把这一条报给 Lead。",
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────────
// 演示数据（索引行上标「演示数据」的那些）
// ────────────────────────────────────────────────────────────────────────

/** 壳里的示例学校/适配器：让「学校适配器」与「适配器详情」有东西可看，值一律写「示例」。 */
private val SHELL_DEMO_SCHOOL = WarehouseSchoolEntry(
    id = "shell-demo-school",
    name = "示例学校",
    initial = "示",
    code = "00000",
)

/**
 * 教务登录页在**开发壳**里的占位地址（I2，2026-10-28）。
 *
 * ## 为什么需要它
 *
 * `WarehouseWebLoginHost` 按设计「`currentUrl` 为空就不加载任何地址」——这是对的
 * （避免加载一个未知页面），但壳里如果传空状态，用户看到的就是**白屏**。
 *
 * ## 为什么是 `example.com`
 *
 * `WarehouseSchoolEntry` **目前没有 URL 字段**（学校条目只带名字与适配器标识），
 * 所以拿不到真实教务地址。选 `example.com` 的理由：它是 IANA 保留的示例域，
 * **永远可解析、且不指向任何真实学校站点**——不会误导成「这就是那所学校的登录页」。
 *
 * ⚠️ 真正的地址要等 `WarehouseSchoolEntry` 加上 URL 字段后从条目里取；
 * 在那之前，本常量只用于验证「WebView 能加载网页」这条链路本身。
 */
private const val SHELL_DEMO_LOGIN_URL = "https://example.com/"

private val SHELL_DEMO_ADAPTER = WarehouseAdapterEntry(
    id = "shell-demo-adapter",
    name = "示例适配器",
    script = "",
    description = "壳内演示条目：不对应任何真实教务系统",
)

/** `mm:ss` → 起点算出来的 `HH:mm`。日视图与课程表单共用的一小段换算。 */
private fun clockText(minutesOfDay: Int): String {
    val normalized = ((minutesOfDay % (24 * 60)) + 24 * 60) % (24 * 60)
    val hour = normalized / 60
    val minute = normalized % 60
    return "${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"
}

/**
 * 示例日程条目：与壳的三个槽位用同一份数据（槽位与索引看到的东西必须一致，
 * 否则同一页在两条路径上长得不一样，会被当成 bug 报上来）。
 */
internal fun shellSampleScheduleGroups(): ScheduleListGroups = ScheduleListGroups(
    upcoming = listOf(
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-1",
                title = "教研会议",
                location = "教学楼 302",
                note = "带教材与期末安排",
                startDate = "2026-11-02",
                startTime = "14:00",
                endTime = "15:30",
                reminderMinutesBefore = 30,
            ),
            nextDate = "2026-11-02",
        ),
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-2",
                title = "实验室例会",
                location = "实验楼 508",
                startDate = "2026-11-06",
                startTime = "09:00",
                endTime = "10:00",
            ),
            nextDate = "2026-11-06",
        ),
    ),
    past = listOf(
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-3",
                title = "期中答疑",
                location = "线上",
                startDate = "2026-10-16",
                startTime = "19:00",
                endTime = "20:00",
            ),
            nextDate = null,
        ),
    ),
    paused = listOf(
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-4",
                title = "暑假集训（已暂停）",
                startDate = "2026-07-01",
                endDate = "2026-08-31",
                startTime = "08:00",
                endTime = "11:30",
                enabled = false,
            ),
            nextDate = null,
        ),
    ),
)

/** 任务列表空态：先看版式骨架，示例条目等 CourseTask 样例批补。 */
internal fun shellSampleTaskViewState(): TaskListViewState = TaskListViewState(
    dateFilter = TaskDateFilter.ALL,
    courseFilter = null,
    selectedCourseLabel = "全部课程",
    sections = emptyList(),
    emptyTitle = "暂无任务",
    undatedHiddenCount = 0,
    totalTasksCount = 0,
)
