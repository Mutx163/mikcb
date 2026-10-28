package com.mutx163.qingyu.pages

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.KeepAliveAccessibilityStatus
import com.mutx163.qingyu.components.QingyuCard
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
import com.mutx163.qingyu.pages.live.LiveKeepAliveSettingsPage
import com.mutx163.qingyu.pages.live.LiveSettingsPage
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
import com.mutx163.qingyu.pages.statistics.CourseStatisticsLogic
import com.mutx163.qingyu.pages.statistics.CourseStatisticsPage
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModule
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisPage
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel
import com.mutx163.qingyu.pages.statistics.StatisticsSessionPage
import com.mutx163.qingyu.pages.statistics.StatisticsSettingsLogic
import com.mutx163.qingyu.pages.statistics.StatisticsSettingsPage
import com.mutx163.qingyu.pages.sync.CloudBackupListPage
import com.mutx163.qingyu.pages.sync.CloudBackupListViewState
import com.mutx163.qingyu.pages.sync.CloudSyncLogic
import com.mutx163.qingyu.pages.sync.CloudSyncPage
import com.mutx163.qingyu.pages.sync.CloudSyncStatusSource
import com.mutx163.qingyu.pages.sync.CoupleBusyState
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsLogic
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsPage
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
import com.mutx163.qingyu.pages.timetable.TimetableProfilesPage
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.DayViewPageData
import com.mutx163.qingyu.pages.timetable.day.DayViewSummaryLogic
import com.mutx163.qingyu.pages.transfer.DataTransferPage
import com.mutx163.qingyu.pages.transfer.DataTransferViewState
import com.mutx163.qingyu.pages.transfer.LanEditModel
import com.mutx163.qingyu.pages.transfer.LanEditPage
import com.mutx163.qingyu.pages.transfer.PickupCodesPage
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
        "b.general" -> SettingsScreen(SettingsGeneralPage.spec(SettingsPageState()), onBack)
        "b.appearance" -> SettingsScreen(SettingsAppearancePage.spec(SettingsPageState()), onBack)
        "b.theme" -> SettingsScreen(SettingsThemeManagePage.spec(SettingsPageState()), onBack)
        "b.appearanceEditor" -> SettingsScreen(SettingsAppearanceEditorPage.spec(SettingsPageState()), onBack)
        "b.materialGeneral" -> SettingsScreen(SettingsMaterialGeneralPage.spec(SettingsPageState()), onBack)
        "b.materialCourseCard" -> SettingsScreen(SettingsMaterialCourseCardPage.spec(SettingsPageState()), onBack)
        "b.backdropFlow" -> SettingsScreen(SettingsBackdropFlowPage.settingsPage(BackdropFlowState()), onBack)
        "b.recentWallpaper" -> SettingsScreen(SettingsRecentWallpaperSection.spec(RecentWallpaperState()), onBack)
        "b.bingGallery" -> SettingsScreen(SettingsBingWallpaperGalleryPage.spec(BingGalleryState()), onBack)
        "b.homeWidget" -> SettingsScreen(SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()), onBack)
        "b.homeNavigation" -> SettingsScreen(SettingsHomeNavigationPage.spec(SettingsHomeNavigationState()), onBack)
        "b.homeMenuEditor" -> SettingsScreen(SettingsHomeMenuEditorPage.spec(SettingsHomeMenuEditorState()), onBack)
        "b.courseCard" -> SettingsScreen(SettingsCourseCardPage.spec(SettingsPageState()), onBack)
        // 2026-10-28 补口：这一屏原先只有入口行没有落点（台账虚标三处之一）。
        "b.timetablePage" -> SettingsScreen(
            SettingsTimetablePageSettingsPage.spec(TimetablePageSettingsState()),
            onBack,
        )
        "b.live" -> SettingsScreen(SettingsLivePage.spec(SettingsPageState()), onBack)
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
        "c1.week" -> TimetableWeekPage()
        "c1.profiles" -> TimetableProfilesPage(
            profiles = emptyList(),
            onBack = onBack,
            onCreateProfile = {},
            onSwitchProfile = {},
            onRenameProfile = { _, _ -> },
            onDuplicateProfile = {},
            onClearCourses = {},
            onDeleteProfile = {},
        )

        // ── P3-C3 课表 · 日视图 ────────────────────────────────────────
        "c3.day" -> DayViewPage(
            initialWeek = 1,
            initialDayOfWeek = 1,
            dataProvider = { week, dayOfWeek ->
                DayViewPageData(
                    summaryState = DayViewSummaryLogic.buildSummaryState(
                        week = week,
                        dateLabel = "第 $week 周 · 周$dayOfWeek",
                        isToday = false,
                        courseCount = 0,
                        scheduleCount = 0,
                    ),
                )
            },
            onCloseToWeekView = onBack,
        )

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
        "d2.addTask" -> AddTaskPage(
            viewState = AddTaskViewState(isEditing = false, title = ""),
            onBack = onBack,
            onTitleChange = {},
            onNoteChange = {},
            onPickCourseClick = {},
            onHasDueDateChange = {},
            onPickDueDateClick = {},
            onCompletedChange = {},
            onSave = {},
        )

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
        "e.statistics" -> CourseStatisticsPage(
            viewState = CourseStatisticsLogic.buildViewState(
                courses = emptyList(),
                currentWeek = 1,
                semesterWeekCount = 20,
                semesterStartDate = null,
                selectedWeek = 1,
                semesterView = true,
                hasOtherProfiles = false,
            ),
            onBack = onBack,
            onTabSelected = {},
            onOpenSettings = {},
            onOpenShare = {},
            onWeekChanged = {},
            onOpenAnalysis = {},
            onOpenSessions = {},
        )
        "e.statisticsSettings" -> StatisticsSettingsPage(
            viewState = StatisticsSettingsLogic.buildViewState(
                weeklyReportEnabled = false,
                now = LocalDateTime.now(),
            ),
            onBack = onBack,
            onWeeklyReportToggle = {},
        )
        "e.analysis" -> StatisticsAnalysisPage(
            // 六个模块共用一页；壳里默认进「趋势」。courseCount=0 → 空态。
            viewState = StatisticsAnalysisModel.viewState(
                module = StatisticsAnalysisModule.TREND,
                courseCount = 0,
            ),
            onBack = onBack,
        )
        "e.session" -> StatisticsSessionPage(
            viewState = StatisticsSessionModel.viewState(
                courseNames = emptyList(),
                previousSelection = null,
                statsOf = { null },
                dateTextOf = { null },
            ),
            onBack = onBack,
            onSelectCourse = {},
        )

        // ── P3-F 同步与备份 ───────────────────────────────────────────
        "f.cloudSync" -> CloudSyncPage(
            viewState = CloudSyncLogic.buildViewState(
                config = WebdavSyncConfig(),
                hasStoredPassword = false,
                status = CloudSyncStatusSource(),
                isCreatingBackup = false,
                loadingBackups = false,
                backupEntries = emptyList(),
                isLoading = false,
                deviceLabel = "Compose 壳",
            ),
            onBack = onBack,
            onConnect = {},
            onDisconnect = {},
            onToggleEnabled = {},
            onProviderSelected = {},
            onModeSelected = {},
            onBaseUrlChange = {},
            onRemoteFolderChange = {},
            onDeviceLabelChange = {},
            onSaveAdvanced = {},
            onSyncNow = {},
            onCreateBackup = {},
            onOpenBackup = {},
            onViewAllBackups = {},
            onMaxCountSelected = {},
            onMaxAgeSelected = {},
            onManualProtectedChange = {},
        )
        "f.backupList" -> CloudBackupListPage(
            viewState = CloudBackupListViewState(
                isLoading = false,
                isCreatingBackup = false,
                rows = emptyList(),
                title = "云备份",
                createLabel = "创建备份",
                emptyText = "暂无备份",
            ),
            onBack = onBack,
            onCreateBackup = {},
            onOpenBackup = {},
        )
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
        "g2.webLogin" -> WarehouseWebLoginPage(
            title = SHELL_DEMO_SCHOOL.name,
            sessionState = WarehouseWebLoginSessionState(),
            onBack = onBack,
        )
        "g2.customDebug" -> WarehouseCustomDebugPage(onBack = onBack)
        "g2.aiImageImport" -> AiImageCourseImportPage(onBack = onBack)

        // ── P3-G3 导出与传输（二维码两页不在此，见文件头第 3 条）─────
        "g3.dataTransfer" -> DataTransferPage(
            viewState = DataTransferViewState(
                overview = TransferOverviewInput(
                    courseCount = 0,
                    activeProfileName = null,
                    profileCount = 0,
                    timeSchemeCount = 0,
                    currentWeek = 1,
                    semesterStartDate = null,
                ),
            ),
            onBack = onBack,
            onExportCurrent = {},
            onExportAllData = {},
            onExportTimeTemplate = {},
            onOpenIcsExport = {},
            onChooseFileAndImport = {},
            onQrSend = { _, _ -> },
            onQrSendAll = {},
            onQrScan = {},
            onUndo = {},
        )
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
        "j.live" -> LiveSettingsPage(onBack = onBack)
        // 2026-10-28 补口：这一屏原先只有入口行没有落点（台账虚标三处之一）。
        // 走**状态化重载**而不是零参重载：零参重载的探测回调恒返回「未开启」，
        // 那样 L4 只看得到一种状态，「已开启（绿勾 + 整行不可点）」那一支永远对不上。
        // 所以无障碍状态读平台真值。
        // 唯一不真实的地方是「从最近任务中隐藏」不落盘（壳没有数据层），故归 DEMO。
        "j.keepAlive" -> {
            val context = LocalContext.current
            LiveKeepAliveSettingsPage(
                onBack = onBack,
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
