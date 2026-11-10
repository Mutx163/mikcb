package com.mutx163.qingyu.pages

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.provider.Settings
import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.KeepAliveAccessibilityStatus
import com.mutx163.qingyu.app.AddTaskFormReducer
import com.mutx163.qingyu.app.CourseActionDispatcher
import com.mutx163.qingyu.app.CourseRecolorSheetHost
import com.mutx163.qingyu.app.TimetableHostDisplayPrefs
import com.mutx163.qingyu.app.TimetableHost
import com.mutx163.qingyu.app.AppearanceEditorHost
import com.mutx163.qingyu.app.DiagnosticsLogHost
import com.mutx163.qingyu.app.rememberMonthHolidayState
import com.mutx163.qingyu.app.rememberHomeBackdropChrome
import com.mutx163.qingyu.pages.shell.rememberHomeFloatingInsets
import com.mutx163.qingyu.app.DiagnosticsSettingsHost
import com.mutx163.qingyu.app.GlassDockEditorHost
import com.mutx163.qingyu.app.HomeMenuEditorHost
import com.mutx163.qingyu.app.HomeNavigationHost
import com.mutx163.qingyu.app.HomeWidgetHost
import com.mutx163.qingyu.app.IcsExportHost
import com.mutx163.qingyu.app.LiveDisplayHost
import com.mutx163.qingyu.app.LiveReminderTimingHost
import com.mutx163.qingyu.app.LiveSelfCheckHost
import com.mutx163.qingyu.app.LiveSettingsPageHost
import com.mutx163.qingyu.app.LiveTestingFixtureHost
import com.mutx163.qingyu.app.MemoryStatsHost
import com.mutx163.qingyu.app.PerfReportHost
import com.mutx163.qingyu.app.SettingsHolidayAdvancedHost
import com.mutx163.qingyu.app.SettingsHolidayHost
import com.mutx163.qingyu.app.SettingsHost
import com.mutx163.qingyu.app.SettingsSemesterHost
import com.mutx163.qingyu.app.SettingsTimetableHubHost
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WeatherSettingsHost
import com.mutx163.qingyu.platform.PerfProbe
import com.mutx163.qingyu.app.TimetablePageSettingsHost
import com.mutx163.qingyu.app.ScheduleDateRuleHost
import com.mutx163.qingyu.app.ScheduleListHost
import com.mutx163.qingyu.app.TaskListHost
import com.mutx163.qingyu.app.TimeSchemeEditorHost
import com.mutx163.qingyu.app.TimeSchemeManagementHost
import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.WeeklyReportScheduleLogic
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPreviewCutout
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.LocationTimeMatchLogic
import com.mutx163.qingyu.course.CoursePortExamAdapter
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.course.TimetableExamService
import com.mutx163.qingyu.pages.about.AboutStaticPage
import com.mutx163.qingyu.pages.about.AboutUpdateHostPage
import com.mutx163.qingyu.pages.about.ChangelogPage
import com.mutx163.qingyu.pages.about.ContributorsHostPage
import com.mutx163.qingyu.pages.about.ContributorsPage
import com.mutx163.qingyu.pages.about.OpenSourceLicensesHost
import com.mutx163.qingyu.pages.about.SupportCreatorHostPage
import com.mutx163.qingyu.pages.about.SupportCreatorPage
import com.mutx163.qingyu.pages.conflict.CourseConflictPage
import com.mutx163.qingyu.pages.conflict.buildCourseConflictView
import com.mutx163.qingyu.pages.course.AddCourseEntryClock
import com.mutx163.qingyu.pages.course.AddCoursePage
import com.mutx163.qingyu.pages.course.AddCourseStrings
import com.mutx163.qingyu.pages.course.CourseFieldSuggestionLogic
import com.mutx163.qingyu.pages.course.CourseNoteSheet
import com.mutx163.qingyu.pages.exam.AddExamFormReducer
import com.mutx163.qingyu.pages.exam.AddExamLogic
import com.mutx163.qingyu.pages.exam.AddExamPage
import com.mutx163.qingyu.pages.exam.ExamCoursePickerSheet
import com.mutx163.qingyu.pages.exam.ExamDatePickerSheet
import com.mutx163.qingyu.pages.exam.ExamListLogic
import com.mutx163.qingyu.pages.exam.ExamListPage
import com.mutx163.qingyu.pages.exam.ExamReminderPickerSheet
import com.mutx163.qingyu.pages.exam.ExamStrings
import com.mutx163.qingyu.pages.exam.ExamTimePickerSheet
import com.mutx163.qingyu.pages.feedback.FeedbackPage
import com.mutx163.qingyu.pages.feedback.FeedbackLaunchRules
import com.mutx163.qingyu.pages.feedback.feedbackOpenPlanFor
import com.mutx163.qingyu.pages.feedback.runFeedbackOpenPlan
import com.mutx163.qingyu.pages.guide.HyperosShowcasePage
import com.mutx163.qingyu.pages.guide.MoreFeaturesModel
import com.mutx163.qingyu.pages.guide.MoreFeaturesPage
import com.mutx163.qingyu.pages.guide.MoreFeaturesSearchOverlay
import com.mutx163.qingyu.pages.guide.GuideStrings
import com.mutx163.qingyu.pages.guide.STARTUP_LEGACY_PACKAGE_CANDIDATES
import com.mutx163.qingyu.pages.guide.StartupFlowPage
import com.mutx163.qingyu.pages.guide.StartupFlowPreferences
import com.mutx163.qingyu.pages.guide.StartupFlowState
import com.mutx163.qingyu.pages.guide.UserGuideHost
import com.mutx163.qingyu.pages.guide.planStartupSemesterWrite
import com.mutx163.qingyu.pages.import.IcsImportHost
import com.mutx163.qingyu.pages.import.ImportEntryHost
import com.mutx163.qingyu.pages.import.ImportShellBridge
import com.mutx163.qingyu.pages.import.SpreadsheetImportHost
import com.mutx163.qingyu.pages.import.warehouse.AiImageCourseImportHost
import com.mutx163.qingyu.pages.import.warehouse.WarehouseAdapterDetailHost
import com.mutx163.qingyu.pages.import.warehouse.WarehouseCustomDebugHost
import com.mutx163.qingyu.pages.import.warehouse.WarehouseImportHandoff
import com.mutx163.qingyu.pages.import.warehouse.WarehouseImportPickerHost
import com.mutx163.qingyu.pages.import.warehouse.WarehouseImportPrefs
import com.mutx163.qingyu.pages.import.warehouse.WarehouseSchoolAdaptersHost
import com.mutx163.qingyu.pages.import.warehouse.WarehouseShellState
import com.mutx163.qingyu.pages.import.warehouse.WarehouseWebLoginHost
import com.mutx163.qingyu.pages.live.LiveKeepAliveSettingsPage
import com.mutx163.qingyu.pages.schedule.ScheduleEditHost
import com.mutx163.qingyu.pages.schedule.ScheduleItemBridge
import com.mutx163.qingyu.pages.settings.BackdropFlowState
import com.mutx163.qingyu.pages.settings.BingGalleryHost
import com.mutx163.qingyu.pages.settings.GlassDockEditorState
import com.mutx163.qingyu.pages.settings.MaterialSheetPages
import com.mutx163.qingyu.pages.settings.RecentWallpaperState
import com.mutx163.qingyu.pages.settings.SettingsAppearanceEditorPage
import com.mutx163.qingyu.pages.settings.SettingsAppearancePage
import com.mutx163.qingyu.pages.settings.SettingsBackdropFlowPage
import com.mutx163.qingyu.pages.import.ImportRandomColorStore
import com.mutx163.qingyu.pages.import.CourseRecolorHistoryStore
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
import com.mutx163.qingyu.pages.settings.SettingsMaterialCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsMaterialGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsRecentWallpaperSection
import com.mutx163.qingyu.pages.settings.SettingsResetPage
import com.mutx163.qingyu.pages.settings.SettingsThemeManagePage
import com.mutx163.qingyu.pages.settings.GlassDockIconEditorHost
import com.mutx163.qingyu.pages.settings.WallpaperPositionPickerHost
import com.mutx163.qingyu.pages.settings.WallpaperSheetPages
import com.mutx163.qingyu.pages.settings.SettingsWeatherPage
import com.mutx163.qingyu.pages.shell.ShellPageCatalog
import com.mutx163.qingyu.pages.shell.HomeMenuNavModel
import com.mutx163.qingyu.pages.showcase.MiuixShowcasePage
import com.mutx163.qingyu.WeeklyReportScheduler
import com.mutx163.qingyu.pages.statistics.CourseStatisticsLogic
import com.mutx163.qingyu.pages.statistics.CourseStatisticsPage
import com.mutx163.qingyu.pages.statistics.charts.StatisticsExportContent
import com.mutx163.qingyu.pages.statistics.charts.StatisticsExportSheet
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModule
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisPage
import com.mutx163.qingyu.pages.statistics.StatisticsFeed
import com.mutx163.qingyu.pages.statistics.StatisticsRankingLinkModel
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel
import com.mutx163.qingyu.pages.statistics.StatisticsSessionPage
import com.mutx163.qingyu.pages.statistics.StatisticsSettingsLogic
import com.mutx163.qingyu.pages.statistics.StatisticsSettingsPage
import com.mutx163.qingyu.pages.statistics.StatisticsShareText
import com.mutx163.qingyu.pages.statistics.WeeklyReportToggleLogic
import com.mutx163.qingyu.pages.statistics.shareStatisticsExport
import com.mutx163.qingyu.pages.sync.CloudBackupDetailHost
import com.mutx163.qingyu.pages.sync.CloudBackupListPage
import com.mutx163.qingyu.pages.sync.CloudBackupListViewState
import com.mutx163.qingyu.pages.sync.CloudSyncController
import com.mutx163.qingyu.pages.sync.CloudSyncLogic
import com.mutx163.qingyu.pages.sync.CloudSyncPage
import com.mutx163.qingyu.pages.sync.CloudSyncStatusSource
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsHost
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsLogic
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsPage
import com.mutx163.qingyu.pages.sync.SyncStrings
import com.mutx163.qingyu.pages.sync.WebdavConnectSheet
import com.mutx163.qingyu.platform.AppLocalSnapshotStore
import com.mutx163.qingyu.platform.KeystoreSecretCipher
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.platform.WebdavConfigStoreImpl
import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.pages.task.AddTaskPage
import com.mutx163.qingyu.pages.task.AddTaskViewState
// 2026-10-29：任务清单渲染改走宿主 `app/TaskHost.kt`（`TaskListHost`），本文件不再直接引用
// `TaskListPage` / `TaskListController` / `TaskListViewState` / `TaskDateFilter`。
import com.mutx163.qingyu.pages.task.TaskFilterLogic
import com.mutx163.qingyu.pages.task.TaskStrings
import com.mutx163.qingyu.pages.task.TaskListController
import com.mutx163.qingyu.pages.time_scheme.LocationTimeApplyLogic
import com.mutx163.qingyu.pages.time_scheme.LocationTimeMatchHost
import com.mutx163.qingyu.pages.timetable.TimetableProfilesController
import com.mutx163.qingyu.pages.timetable.TimetableStyleMapping
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.pages.timetable.toastOrNull
import com.mutx163.qingyu.pages.timetable.TimetableProfilesPage
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
import com.mutx163.qingyu.pages.timetable.WeekdayHeaderMetrics
import com.mutx163.qingyu.pages.timetable.TimetableTopBarMetrics
import com.mutx163.qingyu.pages.timetable.day.DayViewDataAssembler
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.pages.timetable.day.DayViewWeather
import com.mutx163.qingyu.pages.timetable.day.dayViewPageDataOf
import com.mutx163.qingyu.widgetdata.CoupleOverlaySource
import com.mutx163.qingyu.pages.timetable.day.DayAgendaEntry
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.DayViewPageData
import com.mutx163.qingyu.pages.timetable.day.DayViewSummaryLogic
import com.mutx163.qingyu.pages.timetable.month.MonthAgendaKind
import com.mutx163.qingyu.pages.timetable.month.MonthViewHost
import com.mutx163.qingyu.pages.transfer.DataTransferHost
import com.mutx163.qingyu.pages.transfer.LanEditHost
import com.mutx163.qingyu.pages.transfer.PickupCodesHost
import com.mutx163.qingyu.pages.transfer.QrTransferSendHost
import com.mutx163.qingyu.pages.transfer.QrTransferScanHost
import com.mutx163.qingyu.pages.transfer.QrTransferSendSession
import com.mutx163.qingyu.pages.transfer.TransferShellBridge
import com.mutx163.qingyu.pages.weather.WeatherCityPickerHost
import com.mutx163.qingyu.theme.QingyuTheme
import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.theme.MiuixTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * 设置族「行点击 → 推页」的壳级回调。
 *
 * 设置族 20+ 页共用一个 `SettingsPageScreen(spec)` 渲染层，但**每个页面分支**都要能
 * 把行上的 `actionTarget`（Dart 路由串）交给壳去映射成页面 id。原先只有 4 个宿主页
 * 各自接了 `onNavigate`，其余页面统一走 `SettingsScreen`，而它的 `onAction` 是空实现
 * ⇒ 设置主页（`b.settingsHome`）与 17 个演示页的箭头行**全部点了没反应**。
 *
 * 用一个 CompositionLocal 把 `onOpenPage` 透到每个 `SettingsScreen`，避免逐个分支
 * 传参，也不会漏掉未来的新页面。**只对 `SettingsScreen` 生效，不改变各页自身的写回逻辑。**
 */
private val LocalShellOpenPage = staticCompositionLocalOf<(String) -> Unit> { {} }

/**
 * 把日视图塞进首页展开窗口时，壳需要额外知道的那几件事（2026-11-02）。
 *
 * 日视图的数据装配 / 点击落点仍然只有 `c3.day` 这一条分支（一份接线原则）；
 * 首页宿主（`TimetableWeekPage` 的展开层）只负责画窗口、算裁切，并把下面这些
 * 「窗口里的日视图该怎么表现」传进来：
 *
 * - [contentTopInset]：首页顶栏玻璃带的高度。日视图在窗口里**不画自己的顶栏/星期栏**
 *   （那两样由首页画，和周视图共用一条带），正文从这里往下开始。
 * - [initialWeek] / [initialDayOfWeek]：窗口第一次组合时落在哪一天。
 * - [requestedWeek] / [requestedDayOfWeek]：首页星期栏当前选中的那天。日视图翻页后
 *   会经 [onPageChanged] 回写，二者保持同源；外部点另一天时靠这两个值驱动 pager。
 * - [onRequestClose]：日视图摘要卡上那个「关闭」叉（回到周视图）。
 */
data class DayViewOverlayBinding(
    val contentTopInset: Dp,
    val initialWeek: Int,
    val initialDayOfWeek: Int,
    val requestedWeek: Int,
    val requestedDayOfWeek: Int,
    val onPageChanged: (week: Int, dayOfWeek: Int) -> Unit,
    val onRequestClose: () -> Unit,
    /**
     * 首页宿主**已经解析好**的设置模型（2026-11-03 修）。
     *
     * 展开层里的日视图是 `c3.day` 那条分支，它自己也会 `wiring.settingsModel.load()`——
     * 而同一帧里首页宿主（`TimetableWithCourseActions`）刚解析过一份。同一份
     * `timetable_settings` JSON 在展开第一帧被完整解析两遍（MiniJson + 80+ 键 fromJson），
     * 正好压在动画起步帧上。首页宿主把自己那份传进来，日视图就不再重复解析。
     *
     * null = 独立页面 / 页面索引进入（没有宿主可借），仍按旧路径自己 `load()`。
     */
    val settingsModel: TimetableSettingsModel? = null,
    /**
     * 摘要卡飞行的**测量 + 飞行期间隐藏**修饰器（2026-11-03，阶段 A）。
     *
     * 由首页周视图页生成（它持有展开层坐标系与两处实测值），原样挂到日视图的
     * 真摘要卡上。null / 默认 = 独立页面（没有首页展开态）⇒ 行为不变。
     */
    val summaryModifier: Modifier = Modifier,
)

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
    /** 「回到首页（栈底）」：导入成功后自动返回用；默认退一层，保持旧调用点行为。 */
    onBackToRoot: () -> Unit = onBack,
    wiring: ShellWiring,
    /** 页面内部要「推一个新页」时用它（路由字符串 → 壳页面 id 由 [shellPageIdForRoute] 负责）。 */
    onOpenPage: (String) -> Unit = {},
    /**
     * 设置页改动后的**即时回推**（外观页当场换肤用）。
     *
     * 只有外观 / 主题 / 恢复默认三页会用到：它们改的是主题桥读取的那批字段
     * （明暗 / 种子色 / 字重 / 字族 / 字号）。壳把回调接到 `setContent` 顶层的
     * `settingsModel` 状态上，`QingyuPageTheme` 立刻按新值重组。
     * 不传 = 旧行为（设置仍会落盘，只是要等回到主屏才换肤）。
     */
    onSettingsChanged: (TimetableSettingsModel) -> Unit = {},
    /** 非空 = 本页正作为**首页的日视图展开层**渲染（见 [DayViewOverlayBinding]）。 */
    dayOverlay: DayViewOverlayBinding? = null,
    /** 非空 = 本页正作为**首页的月视图第三种页内态**渲染（见 `MonthViewPage.embedded`）。 */
    monthEmbedded: Boolean = false,
    /** 月视图聚焦月（只月份）回传，供首页顶部角格显示。 */
    onMonthLabelChanged: ((String) -> Unit)? = null,
    /** 月视图选中日期回传，供首页顶部星期栏显示选中周。 */
    onMonthSelectedDateChanged: ((java.time.LocalDateTime?) -> Unit)? = null,
) {
    // 单一天气 provider（设备级状态：开关/城市/预报缓存）。2026-10-29 起实例住在
    // `ShellWiring.weather`（`by lazy`），不再在这里 `remember` 一份 —— 因为**底部坞**那条
    // 课表入口（`PagesShellActivity` 的 `DockSlot.TIMETABLE`）也要用它（弹层的天气行），
    // 两处各造一份会变成「两个城市、两份缓存」。跨页共享语义不变：
    // 设置页、选城页、课表弹层读的都是同一个实例（对齐 Dart 把 WeatherProvider 挂在 Navigator 之上）。
    val weatherProvider = wiring.weather
    // 把「推页」回调装进 CompositionLocal，供各设置页的 `SettingsScreen` 使用（见上方 KDoc）。
    // 帧性能台账的换页打点：Dart 侧由 `NavigatorObserver` 自动得到同一件事，壳里没有观察者，
    // 所以在**唯一知道当前页 id** 的这里报一次。`LaunchedEffect(pageId)` 而不是 `SideEffect`：
    // `PerfProbeCore.beginPage` 会「收掉上一段、开一段新的」，每帧重组都调会把一次停留
    // 切成无数个 0 帧片段。正式包里这条是空操作（探针未安装）。
    LaunchedEffect(pageId) { PerfProbe.beginPage(pageId) }
    CompositionLocalProvider(LocalShellOpenPage provides onOpenPage) {
    // 传输包跨路由暂存：「二维码发送」与「扫码接收」是两个独立路由，而发送载荷只有数据备份页
    // 才算得出来（要读仓储）。
    //
    // 2026-11-10 第二波：**必须是进程级单例**。原先这里 `remember { TransferShellBridge() }`
    // 而 `ShellPageContent` 由 `entry<ShellRoute.Page>` 每个路由条目各组合一次 ⇒ 发送页 /
    // 扫码页各拿一份空桥，发送页 session 恒 null、扫码回填的字节本页读不到。照
    // `WarehouseImportHandoff` 的 object 模式改全局一份（对象自己就是单例，本地 val 只是别名）。
    val transferBridge = TransferShellBridge
    // 导入三页的跨路由信号（2026-10-29 F07；2026-11-10 第二波改成进程级单例 + 代数）：
    // 子页成功落盘后通知入口页自关，对应 Dart 的 `Navigator.pop(true)` + 入口页
    // `_openImportPage` 的关单规则。同样不能是每路由一份，否则入口页永远读不到。
    // 2026-11-10 J12：宿主已改成直接调 `ImportShellBridge.markImported()`，壳这边不再需要
    // 本地别名（留着就是一条没人读的 val）。
    // 教务仓库三页的跨路由暂存（选中学校 / 适配器）。与 `TransferShellBridge` 同挂法：
    // 切页不丢，退出壳即丢（`WarehouseImportHosts.kt:70-80`）。
    val warehouseState = remember { WarehouseShellState() }
    val warehouseContext = LocalContext.current
    val warehousePrefs = remember(warehouseContext) {
        WarehouseImportPrefs(PrefsKeyValueStore(warehouseContext))
    }
    // 「课表重新配色」弹层的数据侧：课程来自仓储，颜色组偏好与配色历史都走键值存储。
    // 两个 store 只包着同一个 prefs，按 context 记住即可；弹层每次打开都重读历史。
    val recolorContext = LocalContext.current
    val recolorColorStore = remember(recolorContext) {
        ImportRandomColorStore(PrefsKeyValueStore(recolorContext))
    }
    val recolorHistoryStore = remember(recolorContext) {
        CourseRecolorHistoryStore(PrefsKeyValueStore(recolorContext))
    }
    when (pageId) {
        // ── P3-A 关于与说明 ────────────────────────────────────────────
        // 2026-10-28 补全：此前 onEntryClick 是空 lambda，10 个入口全部点了没反应；
        // 现在把「点了要去哪一页」交给壳（onOpenPage），页内说明/仓库弹层由页面自己处理。
        "a.about" -> AboutStaticPage(onBack = onBack, onOpenPage = onOpenPage)
        // 2026-10-28 补口：这一屏原先只有解析模型没有界面（台账虚标三处之一）。
        // 零参调用：页面自己去读 assets 里的发布说明。
        "a.changelog" -> ChangelogPage(onBack = onBack)
        // 2026-10-28 补口：接真实许可证数据（读 APK 内 NOTICES.Z）+ 页内详情导航。
        "a.licenses" -> OpenSourceLicensesHost(onBack = onBack)
        // 2026-10-29（F09）：此前 `donorData = null, onReload = {}` ⇒ 名单恒空、刷新点了没反应。
        // 现在宿主自己拉（官方 raw 主 / GitCode 直连备），失败显示真原因 + 可重试。
        "a.support" -> SupportCreatorHostPage(onBack = onBack)
        // 2026-10-29（F09）：此前 `maintainers = emptyList(), onReload = {}` ⇒ 恒空态。
        // 现在读 root_index + 每校 adapters.yaml，缓存优先并标注缓存时间，失败可重试。
        "a.contributors" -> ContributorsHostPage(onBack = onBack)
        // 版本更新页（`a.update`）：由「版本更新页 1:1 复刻」批次交付。
        // 宿主装配层（真实检查更新 / 系统下载 / 设置读写 / 镜像测速）在 AboutUpdateHostPage。
        "a.update" -> AboutUpdateHostPage(onBack = onBack)

        // ── P3-B 设置族（24 屏共用一个渲染层）─────────────────────────
        // 2026-10-29：首页那张「第 N 周 / 共 M 周 + 开学日期」摘要卡改为读真仓储
        // （原来喂空构造 state ⇒ 永远「第 1 周 / 共 20 周 / 未设置」，与子页真相矛盾）。
        // 2026-11-01 F25：其余五行（课表名 / 时间模板 / 节假日 / 天气 / 情侣）也接上真值，
        // 详见 `SettingsTimetableHubLogic`。
        "b.settingsHome" -> SettingsTimetableHubHost(
            repository = wiring.timetable,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            // 2026-11-01 F25：下面三个入参决定那几个摘要行说不说真话。
            // 以前只传仓储，于是课表名/时间模板/节假日/天气/情侣五行全是构造默认值。
            settingsStore = wiring.settingsModel,
            weather = weatherProvider,
        )
        // 2026-10-29 学期设置接真宿主：原先用**空构造 state** 渲染，三行永远长成
        // 「设置开学日期 / 20 周 / 同步当前周(禁用)」，而 SHEET / RUN_NOW 在壳里没有落点
        // ⇒ 用户点了没反应，也永远看不到自己真实的开学日期。宿主见 `SettingsSemesterHost`。
        "b.semester" -> SettingsSemesterHost(
            repository = wiring.timetable,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        // Phase 3.5 设置族第一刀：下面 4 页改用**真宿主**（真数据 + 真写回 + 真导航）。
        // 其余设置页仍是演示数据 —— 每接一页，就把它的 spec id 加进
        // `SettingsPageBridge.SUPPORTED_PAGE_IDS`，并在这里换成分派。
        // 2026-10-29 补口（通用页审计 P0）：这一屏原先把 `autoRefresh = null` 写死在桥里
        // ⇒ Flutter 原件里最长的那一块「课表自动更新」（分组标题 + 5 行 + 底部灰字）
        // **整块不在屏上**。现在把独立存储 `wiring.autoRefresh` 接进来，整块按真值渲染；
        // 转场速度与震动总开关也在这里接「当场生效」的回调（Dart 是同一个形态）。
        "b.general" -> SettingsHost(
            pageId = SettingsGeneralPage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            autoRefreshStore = wiring.autoRefresh,
            onTransitionSpeedChanged = { wiring.pageTransitionSpeed = it },
            onHapticsChanged = { wiring.enableHaptics = it },
            // 语言行在通用页：模型变更必须回推给壳，否则 `appLocaleTag` 只落盘，
            // 壳的 `AppLocaleRuntime` 不知道，界面仍停在旧语言（2026-11-07 用户实报）。
            onModelChanged = onSettingsChanged,
        )
        // 外观 / 主题管理：`onModelChanged` 接壳的 `onSettingsChanged`，改明暗、种子色、
        // 字重、字体、字号时**当场**换肤（不等回到主屏）。此前只写盘，用户看到的是
        // 「选项变了、界面纹丝不动」。
        "b.appearance" -> SettingsHost(
            pageId = SettingsAppearancePage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            onModelChanged = onSettingsChanged,
        )
        "b.theme" -> SettingsHost(
            pageId = SettingsThemeManagePage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            onModelChanged = onSettingsChanged,
        )
        // 2026-10-29 外观编辑页接真宿主。原先这一屏是
        // `SettingsScreen(SettingsAppearanceEditorPage.spec(SettingsPageState()))`——传**空构造的
        // state** 渲染成一份设置列表，形态与原件完全不同（原件是沉浸式整页：整屏暗底 +
        // 真课表页缩尺预览 + 顶部一行 chrome + 底部两颗圆钮），两颗入口的 target 在壳里
        // 也没有落点 ⇒ 点了全无反应。宿主见 `composeP1: app/AppearanceEditorHost.kt`。
        "b.appearanceEditor" -> AppearanceEditorHost(
            store = wiring.settingsModel,
            repository = wiring.timetable,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            onBeforeExit = { wiring.settingsRevision++ },
            homeViewMode = wiring.homeViewMode,
            homeSelectedWeek = wiring.homeSelectedWeek,
            homeSelectedDayOfWeek = wiring.homeSelectedDayOfWeek,
            // 预览与真首页同一份天气数据源（设备级 provider）。
            weatherProvider = weatherProvider,
        )
        // 「材质（通用 / 课程卡片）」在原版里**不是两页**，是外观编辑页那个底部弹层的
        // 两个页签（`settings_appearance_editor.dart:2253-2255`）。所以这两条路由直达同一
        // 个宿主并让弹层停在对应页签——关掉弹层落下的就是外观编辑页本身，与原件从
        // 「课程卡片」设置页跳进来时的落点一致。
        "b.materialGeneral" -> AppearanceEditorHost(
            store = wiring.settingsModel,
            repository = wiring.timetable,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            onBeforeExit = { wiring.settingsRevision++ },
            initialMaterialPage = MaterialSheetPages.GENERAL,
            homeViewMode = wiring.homeViewMode,
            homeSelectedWeek = wiring.homeSelectedWeek,
            homeSelectedDayOfWeek = wiring.homeSelectedDayOfWeek,
            weatherProvider = weatherProvider,
        )
        "b.materialCourseCard" -> AppearanceEditorHost(
            store = wiring.settingsModel,
            repository = wiring.timetable,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            onBeforeExit = { wiring.settingsRevision++ },
            initialMaterialPage = MaterialSheetPages.COURSE_CARD,
            homeViewMode = wiring.homeViewMode,
            homeSelectedWeek = wiring.homeSelectedWeek,
            homeSelectedDayOfWeek = wiring.homeSelectedDayOfWeek,
            weatherProvider = weatherProvider,
        )
        // 壁纸面板只有一个入口（Dart `settings_home_backdrop_flow.dart:439-472`：第一页
        // 同时含选图行与「最近使用」缩略图条，没有独立的「最近使用」页）。原先
        // `b.recentWallpaper` 与 `b.backdropFlow` 都落 PICKER、语义重复（R13），已合并为
        // 这一条；课表页「最近使用」行改由 `SettingsHost.timetablePageSheetRoute` 映射到
        // 同一个 `b.backdropFlow`。
        "b.backdropFlow" -> AppearanceEditorHost(
            store = wiring.settingsModel,
            repository = wiring.timetable,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            onBeforeExit = { wiring.settingsRevision++ },
            initialWallpaperPage = WallpaperSheetPages.PICKER,
            homeViewMode = wiring.homeViewMode,
            homeSelectedWeek = wiring.homeSelectedWeek,
            homeSelectedDayOfWeek = wiring.homeSelectedDayOfWeek,
            weatherProvider = weatherProvider,
        )
        // 2026-10-30 F05 收尾：这一页原先走空 state（永远「加载中」、点哪都没下文），
        // 换成真宿主：拉 Bing 每日壁纸清单 + 缩略图 + 点一张下载落盘并写设置。
        "b.bingGallery" -> BingGalleryHost(store = wiring.settingsModel, onBack = onBack)
        // 2026-11-01 F24：壁纸取景页。此前「调整位置」这一行点了没反应（Dart 的取景页
        // 在 Kotlin 侧没移植）；上一批只补了诚实提示，这批把整页搬过来了。
        "b.wallpaperPosition" -> WallpaperPositionPickerHost(
            store = wiring.settingsModel,
            onBack = onBack,
        )
        // 2026-10-31 F20 接线：这一页原先喂空构造 state——屏上恒默认值、6 个开关
        // 点了不落盘、预览区是两张占位小卡。换成真宿主：读设置模型 + 原生渲染的
        // 10 卡预览轮播 + 桌面真实卡片绑定 + 添加到桌面 / 精确闹钟授权。
        "b.homeWidget" -> HomeWidgetHost(
            store = wiring.settingsModel,
            repository = wiring.timetable,
            onBack = onBack,
        )
        // 2026-10-28 S2 接线：这两页原先走 no-op SettingsScreen（写死默认状态、点了不动），
        // 改成真宿主：读 TimetableSettingsModel、控件改动经分派器写回并合并落盘。
        "b.homeNavigation" -> HomeNavigationHost(
            store = wiring.settingsModel,
            onBack = onBack,
            // 子页（底栏编辑器 / 菜单编辑器 / 圆钮图标）走 NAVIGATE 路由，由壳映射并推页。
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        "b.homeMenuEditor" -> HomeMenuEditorHost(store = wiring.settingsModel, onBack = onBack)
        "b.courseCard" -> {
            // 「课表重新配色」：设置宿主拿不到课程数据，真弹层由壳在这里接线。
            // 空课表的提示由弹层自己给（Dart 只 toast、不弹层）。
            var showRecolorSheet by remember { mutableStateOf(false) }
            SettingsHost(
                pageId = SettingsCourseCardPage.ID,
                store = wiring.settingsModel,
                onBack = onBack,
                onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
                // 两页同一份回推接线：宿主草稿 → 预览槽（改开关 / 拖滑杆当场跟着变）。
                preview = { SettingsTimetablePreviewSlot(wiring, it) },
                onRecolorRequested = { showRecolorSheet = true },
            )
            if (showRecolorSheet) {
                CourseRecolorSheetHost(
                    repository = wiring.timetable,
                    colorStore = recolorColorStore,
                    historyStore = recolorHistoryStore,
                    onDismiss = { showRecolorSheet = false },
                    onToast = { message ->
                        Toast.makeText(recolorContext, message, Toast.LENGTH_SHORT).show()
                    },
                )
            }
        }
        // 2026-10-28 补口：这一屏原先只有入口行没有落点（台账虚标三处之一）。
        // S2 第二批：改真宿主——密度/浮钮不透明度读模型并合并落盘；背景/材质/字色待扩模型。
        "b.timetablePage" -> TimetablePageSettingsHost(
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            // 与「课程卡片」页同一份回推接线。
            preview = { SettingsTimetablePreviewSlot(wiring, it) },
        )
        // 2026-10-31 F23：这一屏原先 `SettingsLivePage.spec(SettingsPageState())` —— `data` 走默认
        // 构造，两行摘要（上课前显示 / 课中显示）恒为默认值。改真宿主：从 `LiveDisplayStore`
        // 读 `timetable_settings` 的两档显示设置（与「显示设置」子页同一个源），本页只读不写。
        "b.live" -> LiveSettingsPageHost(
            onBack = onBack,
            onOpenPage = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        // 2026-10-31 F23：这一屏原先 `SettingsLiveSelfCheckPage.spec(SettingsPageState())` ——
        // 19 个字段全走默认值，8 块原生诊断卡永远不出现，本地日志卡三颗按钮因为
        // `controlCardWiring` 白名单没有对应键而「看着能点、点了没反应」。改真宿主：
        // 每秒读一次 `LiveUpdateService.buildDebugStatus`（指纹去重，不变就不重建），
        // 三颗按钮分别落 `AppLogStore` 清空 / `h.log` 日志查看器 / 诚实不可用提示。
        "b.liveSelfCheck" -> LiveSelfCheckHost(
            // 宿主里跳的是壳的页面 id（`"h.log"`），不需要过 `shellPageIdForRoute` 转译。
            onOpenPage = onOpenPage,
            onBack = onBack,
        )
        // 2026-10-29 节假日两页接真宿主（此前是 `SettingsScreen(SettingsHolidayPage.spec(SettingsPageState()))`：
        // 入参是**默认构造**的 state，屏上永远「开关开、两个列表空、年份空」，开关写不落盘，
        // 添加 / 长按删除 / 检查更新也都没有落点）。数据源 `wiring.holiday` 与月视图、小组件共用一份。
        "b.holiday" -> SettingsHolidayHost(
            provider = wiring.holiday,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        "b.holidayAdvanced" -> SettingsHolidayAdvancedHost(
            provider = wiring.holiday,
            onBack = onBack,
        )
        "b.weather" -> WeatherSettingsHost(
            provider = weatherProvider,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        // 2026-10-29 接真宿主：原先 `SettingsScreen(SettingsDiagnosticsPage.spec(SettingsPageState()), onBack)`
        // 用空 state 渲染 ⇒ 开关恒 false 且写不落盘、`showMemoryStats = null` 让后两行永久消失、
        // 应用日志行没有 onAction。宿主见 `composeP1: app/DiagnosticsSettingsHost.kt`。
        "b.diagnostics" -> DiagnosticsSettingsHost(
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
        )
        "b.glassDock" -> GlassDockEditorHost(store = wiring.settingsModel, onBack = onBack)
        // 2026-11-01 F26：这一页原来走通用设置宿主，只能把图标铺成一排按钮，
        // 装不下搜索 + 156 格网格；换专用宿主（图标清单、搜索、选中写回与回显都在里面）。
        "b.glassDockIcon" -> GlassDockIconEditorHost(
            store = wiring.settingsModel,
            onBack = onBack,
        )
        "b.reset" -> SettingsHost(
            pageId = SettingsResetPage.ID,
            store = wiring.settingsModel,
            onBack = onBack,
            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
            // 「恢复默认」里也有外观作用域：恢复后当场换回默认主题。
            onModelChanged = onSettingsChanged,
        )

        // ── P3-C1 课表 · 周视图 ────────────────────────────────────────
        // T1：与底部坞的课表槽位共用同一份接线（含课程操作弹层），两个入口行为一致。
        // `weatherProvider` 必须显式传：弹层「天气」行的数据只在壳里（设备级 provider），
        // 漏传就是「设置里开了天气、弹层里没有那一行」。
        "c1.week" -> TimetableWithCourseActions(
            wiring = wiring,
            onNavigate = onOpenPage,
            weatherProvider = weatherProvider,
        )
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
            // 设置存储没有变更通道：把壳的变更序号读进组合，回到主屏时才会重读一次盘
            // （详见 `ShellWiring.settingsRevision`）。
            val appSettings = remember(wiring.settingsRevision) { wiring.settingsModel.load() }
            // 壁纸 / 材质 / 顶栏墨色：与周 / 日视图同一条推导（`rememberHomeBackdropChrome`
            // 是唯一出口）。不接这一层时月视图没有壁纸、顶栏是一块不透明主题底 ——
            // 用户从周视图切到月视图会看到壁纸"消失"。
            val homeChrome = rememberHomeBackdropChrome(appSettings)
            // 2026-11-01 F26：节假日三路数据（provider 在 IO 线程初始化，失败退空态）。
            val holidayState = rememberMonthHolidayState(wiring.holiday)
            // 八宫格里的「弹层动作」：与周视图同一判别（`HomeMenuNavModel.isMenuAction`）。
            // 只查页面映射的话，用户把「课程重新配色 / 分享课表」排进菜单后，切到月视图
            // 点它们会没反应（2026-11-10 评审尾巴）。配色用与课程卡片页同一份颜色仓储；
            // 分享按本周周图，与发布版从非首页入口进入时的兜底口径一致。
            var showRecolorSheet by remember { mutableStateOf(false) }
            if (showRecolorSheet) {
                CourseRecolorSheetHost(
                    repository = wiring.timetable,
                    colorStore = recolorColorStore,
                    historyStore = recolorHistoryStore,
                    onDismiss = { showRecolorSheet = false },
                    onToast = { message ->
                        Toast.makeText(recolorContext, message, Toast.LENGTH_SHORT).show()
                    },
                )
            }
            MonthViewHost(
                snapshot = snapshot,
                // 2026-11-01 F24：月网格的考试 / 日程落格与当日议程都靠这两份。
                // 不喂时页面画成「这个月没有考试、没有日程」——那是**假空态**，不是空数据。
                exams = repository.exams,
                scheduleItems = snapshot.scheduleItems,
                holidayData = holidayState.holidayData,
                holidayOverrideEnabled = holidayState.overrideEnabled,
                holidayMarkingEnabled = holidayState.markingEnabled,
                // 壁纸层 + 材质快照 + 顶栏墨色（与周 / 日视图同一个推导出口）。
                backdrop = homeChrome.backdrop,
                chromeInk = homeChrome.chromeInk,
                material = homeChrome.material,
                hasBackdrop = homeChrome.hasBackdrop,
                pageColorArgb = homeChrome.pageColorArgb,
                // 根页不画返回键、推入时画出：判据在页面里消费（`rememberShellShouldShowBackButton`）。
                onBack = onBack,
                onAddCourse = { date ->
                    wiring.pendingAddCourseSeed = Pair(date.dayOfWeek.value, 1)
                    wiring.pendingEditCourse = null
                    // 从月视图加课要落在「所点那一天所在的周」，不能退回当前周。
                    wiring.pendingEditWeek = WeekCalculator.weekForDate(
                        date = date,
                        semesterStart = snapshot.settings.semesterStartDate,
                        semesterWeekCount = snapshot.settings.semesterWeekCount,
                        fallback = snapshot.currentWeek,
                    )
                    onOpenPage("d1.addCourse")
                },
                // 点当日议程行 → 与日视图同一套落点（课程 / 考试 / 日程各进对应表单）。
                onOpenAgendaRow = { row ->
                    when (row.kind) {
                        MonthAgendaKind.COURSE -> row.course?.let { course ->
                            wiring.pendingEditCourse = course
                            wiring.pendingAddCourseSeed = null
                            wiring.pendingEditWeek = null
                            val siblings = snapshot.courses.filter { it.name == course.name }
                            wiring.pendingEditGroup = if (siblings.isEmpty()) {
                                null
                            } else {
                                com.mutx163.qingyu.pages.course.CourseGroup(
                                    name = course.name,
                                    courses = siblings,
                                )
                            }
                            onOpenPage("d1.addCourse")
                        }

                        MonthAgendaKind.EXAM -> row.exam?.let { exam ->
                            wiring.pendingEditExam = exam
                            onOpenPage("d3.addExam")
                        }

                        MonthAgendaKind.SCHEDULE -> row.schedule?.let { instance ->
                            wiring.clearScheduleIntent()
                            wiring.pendingScheduleEdit = ScheduleItemBridge.toUiData(instance.item)
                            wiring.pendingScheduleOccurrenceDate =
                                instance.date.toLocalDate().toString()
                            onOpenPage("d2.addSchedule")
                        }
                    }
                },
                homeTitleStyle = appSettings.homeTitleStyle,
                homeMenuStyle = appSettings.homeMenuStyle,
                profileName = TimetableHostLogic.resolveProfileName(
                    profiles = snapshot.profiles,
                    activeProfileId = snapshot.activeProfileId,
                ),
                // 月视图「更多」菜单与周/日视图同源：读用户存档的 homeGridMenuActions
                // （`homeTopMenuItems` 会做清洗 + 动作白名单 + 空表回退默认八项）。
                // 2026-11-10 前这里传的是死表 `TimetableMenuDefaults.entries()`，
                // 于是用户自定义的八宫格在月视图不生效、三个首页视图出现两套菜单。
                homeMenuItems = homeTopMenuItems(appSettings),
                embedded = monthEmbedded,
                onMonthLabelChanged = onMonthLabelChanged ?: {},
                onSelectedDateChanged = onMonthSelectedDateChanged ?: {},
                // 「添加课程」要带当前浏览周与今天星期几（Dart `openCourseForm`，
                // `timetable_screen.dart:1745-1752`）；其余项按「页面映射 ∪ 弹层动作」分流。
                // 2026-11-10：月/日视图补上动作通道，与周视图同一判别 —— 只查页面映射会让
                // 用户排进八宫格的「课程重新配色 / 分享课表」在这里点了没反应。
                onHomeMenuSelect = { id ->
                    when {
                        id == HomeMenuNavModel.ACTION_COURSE_RECOLOR -> showRecolorSheet = true
                        id == HomeMenuNavModel.ACTION_SHARE_TIMETABLE ->
                            wiring.shareCurrentWeekImage(recolorContext)
                        else -> shellTimetableMenuPageId(id)?.let { target ->
                            if (target == "d1.addCourse") wiring.seedAddCourseFromMenu(snapshot.currentWeek)
                            onOpenPage(target)
                        }
                    }
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
            // 设置存储没有变更通道：读壳的变更序号，回到主屏时才重读一次盘
            // （详见 `ShellWiring.settingsRevision`；也供下面的「上次看的是哪天」用）。
            //
            // 2026-11-03：作为首页展开层时，宿主（`TimetableWithCourseActions`）已经
            // 解析过同一份设置，经 `DayViewOverlayBinding.settingsModel` 传下来；
            // 这里直接用，不再重复 MiniJson 解析 + 80+ 键 fromJson（那是展开首帧的固定成本）。
            // 独立页面 / 页面索引进入时没有宿主可借，仍按旧路径自己 load()。
            val appSettings = dayOverlay?.settingsModel
                ?: remember(wiring.settingsRevision) { wiring.settingsModel.load() }
            // 八宫格里的「弹层动作」：与月/周视图同一判别（见上面月视图同一段注释）。
            var showRecolorSheet by remember { mutableStateOf(false) }
            if (showRecolorSheet) {
                CourseRecolorSheetHost(
                    repository = wiring.timetable,
                    colorStore = recolorColorStore,
                    historyStore = recolorHistoryStore,
                    onDismiss = { showRecolorSheet = false },
                    onToast = { message ->
                        Toast.makeText(recolorContext, message, Toast.LENGTH_SHORT).show()
                    },
                )
            }
            // ── 首页壁纸 / 材质 / 顶栏墨色（2026-11-01）──
            // 与周视图同一条推导（`rememberHomeBackdropChrome` 是唯一出口）：
            // 不接这一层时，日视图是一块不透明主题底 —— 用户在周视图看到的壁纸与玻璃
            // 一带到日视图就没了。判据、快照、降级全在那一份里，这里只往下透传。
            val homeChrome = rememberHomeBackdropChrome(appSettings)
            // 情侣课表叠加（B1 · 2026-11-06）：绑定不在仓储里，读一次键值存储拼 overlay。
            // `wiring.coupleOverlayRevision` 进 remember 键——情侣页改颜色/周偏移退出时自增，
            // 这里才重读；`snapshot` 也进键（云同步恢复会换整份档案，对方课跟着变）。
            // null = 没绑定/没对方档，装配层按「不叠加」走旧路径，行为不变。
            val coupleOverlayRevision = wiring.coupleOverlayRevision
            val partnerOverlay = remember(coupleOverlayRevision, snapshot) {
                CoupleOverlaySource.load(repository)
            }
            // 「回今日」浮钮与列表底部的避让：按玻璃坞药丸的真实占用算（见 `HomeFloatingMetrics`）。
            val floatingInsets = rememberHomeFloatingInsets(appSettings)
            // 「点星期栏某一天」是**单次意图**：`ShellWiring.onOpenDay` 写进
            // `pendingDayViewDayOfWeek`，这里读一次就清。读完不清会让下一次从底栏或
            // 菜单进日视图时沿用上一次点的那天。
            //
            // 作为首页展开层（`dayOverlay != null`）时**不消费**这个意图：窗口里的
            // 初始日由首页宿主当下的选中日直接给（同一个值，但不必借道单次意图，
            // 否则关掉日视图再开时会拿到已清空的值）。
            val dayIntent = remember(dayOverlay) {
                if (dayOverlay == null) wiring.consumeDayViewDayOfWeek() else null
            }
            // 翻页停稳后把「看的是哪一天」写回存档（Dart `persistHomeViewState` 的日那半边）。
            // 不写它会有两个可感知的后果：① 从底栏再进日视图回到今天而不是上次看的那天；
            // ② 外观编辑页的日预览按这个键取日期，会停在旧值上（用户 2026-11-02 实报
            // 「我滑到其他天，点外观编辑却显示另一天」）。
            // 写盘离开主线程并串行：`saveSettingsPatchToActiveProfile` 会重编码整份档案 JSON。
            val dayPersistScope = remember { CoroutineScope(SupervisorJob() + Dispatchers.IO) }
            val dayPersistMutex = remember { Mutex() }
            val displayPrefs = remember(appSettings) {
                TimetableHostDisplayPrefs.fromSettings(appSettings)
            }
            val visibleDays = remember(displayPrefs.hideWeekends) {
                TimetableHostLogic.visibleDayNumbers(displayPrefs.hideWeekends)
            }
            // 天气 provider 不是 Compose 可观察的（`addListener` 那套）：用计数把
            // 「预报到了 / 城市变了」转成重组；日卡天气行是否真的出现还由
            // `weatherShowOnDayCard` 决定（`DayViewWeather.lineProvider` 内判定）。
            var weatherTick by remember(weatherProvider) { mutableIntStateOf(0) }
            DisposableEffect(weatherProvider) {
                // 退订必须用**同一个** lambda 引用，否则监听器会漏在 provider 里。
                val listener: () -> Unit = { weatherTick += 1 }
                weatherProvider.addListener(listener)
                onDispose { weatherProvider.removeListener(listener) }
            }
            val weatherOf = remember(weatherTick, appSettings.weatherShowOnDayCard) {
                DayViewWeather.lineProvider(appSettings, weatherProvider)
            }
            // 课卡「备注」胶囊：Dart 打开的是**单节备注弹层**（`showCourseNoteSheet`），
            // 不是课程编辑表单；这里用弹层状态承载，弹层由页面外的 `CourseNoteSheet` 渲染。
            var noteTarget by remember { mutableStateOf<Pair<Course, Int>?>(null) }
            val shellContext = LocalContext.current
            val taskController = remember(repository) { TaskListController(repository) }
            Box(modifier = Modifier.fillMaxSize()) {
            // 日视图分支**只取一次钟**：上面「今天在哪一周」按 `today` 现算，下面装配器按 `now`
            // 判「今天/进行中/考试过期」。两处各自 `now()` 时跨零点一瞬会出现周次与「今天」错位
            //（例如 00:00:00 前取到周次、00:00:01 后取到日期）。
            val dayViewNow = LocalDateTime.now()
            DayViewPage(
                summaryModifier = dayOverlay?.summaryModifier ?: Modifier,
                // 日卡天气行挂载后补一次「过期就刷」（页面内部 LaunchedEffect → IO → ensureFresh）。
                // Dart 是每张天气行 addPostFrameCallback 里调（`day_course_weather_row.dart:72-80`），
                // 一屏多卡各调也只有第一次可能真发请求（provider 内部单飞 + 3h TTL + 15min 退避）。
                weatherProvider = weatherProvider,
                initialWeek = dayOverlay?.initialWeek ?: snapshot.currentWeek.coerceAtLeast(1),
                // 有显式意图（点星期栏某天）就用它；否则回到**上次看的那一天**，与 Dart
                // `_restoreViewStateFromProvider`（`timetable_screen.dart:862-890`）同口径。
                // 不能回落「今天」：从底栏再进日视图会跳回今天，与外观编辑页的预览
                //（按同一个键取日期）对不上（2026-11-02 用户实报）。
                initialDayOfWeek = dayOverlay?.initialDayOfWeek
                    ?: (dayIntent ?: appSettings.timetableLastViewedDayOfWeek),
                visibleDays = visibleDays,
                // 学期周数必须下传：页面默认 30 周，不传就能翻到学期之外。
                totalWeeks = snapshot.settings.semesterWeekCount,
                // ── 顶部星期条（2026-10-31 审核 P1-1）：日期、今天标记、考试/日程圆点、
                // 点某天换日、点周次开选择器都要这三样数据。不传时页面只能整条不画。
                semesterStartDate = snapshot.settings.semesterStartDate?.toLocalDate(),
                // 「今天在哪一周」必须按开学日**现算**，不能传 `snapshot.currentWeek`——
                // 那个值每次翻页都会被写成「正在浏览的周」，于是「回今日」会跳回浏览周
                // （P1：回不到今天）。学期没配 / 今天不在学期内时传 null，页面按同一判据
                // 算不出就不该乱跳（Dart `_resolveCurrentSemesterWeek` / `_canNavigateDayViewToToday`）。
                realCurrentWeek = TimetableDateLogic.currentSemesterWeek(
                    semesterStart = snapshot.settings.semesterStartDate?.toLocalDate(),
                    totalWeeks = snapshot.settings.semesterWeekCount,
                    today = dayViewNow.toLocalDate(),
                ),
                weekdayStyle = TimetableStyleMapping.weekViewStyle(appSettings),
                // 「课卡显示冲突角标」开关（Dart `showConflictBadgeOnTimetable`）。
                showConflictBadge = appSettings.showConflictBadgeOnTimetable,
                // 冲突课卡压淡：与周视图共用一个设置键（`WeekViewStyle.conflictCourseOpacity`
                // 从同一份存档映射），日视图此前没接这条。
                conflictCourseOpacity = appSettings.timetableConflictCourseOpacity.toFloat(),
                // 日视图课程卡是否按课程颜色上色（设置「日视图课程卡片颜色」）。
                useCourseColors = appSettings.dayViewUseCourseColor,
                // ── 作为首页展开层时：顶栏 / 星期栏由首页画（周视图那条共享玻璃带），
                // 日视图只画正文；正文从 homePager 的顶栏高度开始，避免两套壳重叠。
                showTopBar = dayOverlay == null,
                showWeekdayHeader = dayOverlay == null,
                contentTopInset = dayOverlay?.contentTopInset,
                // 首页星期栏点另一天：日视图 pager 跟着走（窗口常驻，不能靠 initial* 重开一页）。
                requestedWeek = dayOverlay?.requestedWeek,
                requestedDayOfWeek = dayOverlay?.requestedDayOfWeek,
                hasExamOnDate = { date ->
                    repository.exams.any { exam ->
                        CourseTask.dateOnly(exam.dateTime).toLocalDate() == date
                    }
                },
                hasScheduleOnDate = { date ->
                    snapshot.scheduleItems.any { item -> item.occursOn(date.atStartOfDay()) }
                },
                homeTitleStyle = appSettings.homeTitleStyle,
                homeMenuStyle = appSettings.homeMenuStyle,
                profileName = TimetableHostLogic.resolveProfileName(
                    profiles = snapshot.profiles,
                    activeProfileId = snapshot.activeProfileId,
                ),
                homeMenuItems = homeTopMenuItems(appSettings),
                // 「添加课程」要带当前浏览周与今天星期几（Dart `openCourseForm`，
                // `timetable_screen.dart:1745-1752`）；其余项按「页面映射 ∪ 弹层动作」分流。
                // 2026-11-10：月/日视图补上动作通道，与周视图同一判别 —— 只查页面映射会让
                // 用户排进八宫格的「课程重新配色 / 分享课表」在这里点了没反应。
                onHomeMenuSelect = { id ->
                    when {
                        id == HomeMenuNavModel.ACTION_COURSE_RECOLOR -> showRecolorSheet = true
                        id == HomeMenuNavModel.ACTION_SHARE_TIMETABLE ->
                            wiring.shareCurrentWeekImage(recolorContext)
                        else -> shellTimetableMenuPageId(id)?.let { target ->
                            if (target == "d1.addCourse") wiring.seedAddCourseFromMenu(snapshot.currentWeek)
                            onOpenPage(target)
                        }
                    }
                },
                // 壁纸层 + 材质快照 + 顶栏墨色（与周视图同一个推导出口）。
                backdrop = homeChrome.backdrop,
                chromeInk = homeChrome.chromeInk,
                // 星期栏 / 空态压在壁纸上的字色（2026-11-01）。
                wallpaperBands = homeChrome.bands,
                material = homeChrome.material,
                // 纯壁纸存在信号（不与材质开关相与）：卡片墨色的页底回退只认它。
                hasWallpaper = homeChrome.hasBackdrop,
                hasBackdrop = homeChrome.hasBackdrop,
                pageColorArgb = homeChrome.pageColorArgb,
                // 浮钮与列表的底部避让（玻璃坞形态按药丸占用算，见 HomeFloatingMetrics）。
                floatingButtonBottomInset = floatingInsets.buttonBottom,
                contentBottomInset = floatingInsets.contentBottom,
                // 数据装配**只在模型层一份**（`DayViewDataAssembler` + `dayViewPageDataOf`）。
                // 旧写法在壳里手拼 `DayViewPageData`：日程条目不构造、日程计数写死成 0、
                // 日期标题自造中文（「第 N 周 · 周X」）、考试与待办全丢。
                dataProvider = { week, dayOfWeek ->
                    dayViewPageDataOf(
                        DayViewDataAssembler.build(
                            week = week,
                            dayOfWeek = dayOfWeek,
                            courses = snapshot.courses,
                            settings = snapshot.settings,
                            currentWeek = snapshot.currentWeek,
                            // 与上面 `realCurrentWeek` 同一次取钟，杜绝跨零点错位。
                            now = dayViewNow,
                            scheduleItems = snapshot.scheduleItems,
                            exams = repository.exams,
                            tasks = repository.tasks,
                            showNonCurrentWeekCourses =
                                appSettings.timetableShowNonCurrentWeekCourses,
                            // 日卡天气行：取数器带当前页的 week，停课周整行不挂
                            //（Dart `day_view_course_agenda_card_variants.dart:166-169`）。
                            weatherOf = weatherOf?.let { resolve ->
                                { date, course -> resolve(week, date, course) }
                            },
                            // 预报还没到（开关开着 + 已选城市 + 未失败）：日卡先占住天气那一行的高度，
                            // 到货后淡入。不这样的话数据到达那一刻整张卡会突然长高一行（用户实报）。
                            weatherAwaiting = appSettings.weatherShowOnDayCard &&
                                weatherProvider.isAwaitingData,
                            // 情侣课表叠加（B1 · 2026-11-06）：TA 课追加进当天议程并带
                            // 「TA的课」徽标（`DayViewCourseCard` 的渲染已就位）。null =
                            // 未绑定，装配层走旧路径。外观编辑页预览（独立调用点）不传它，
                            // 预览不受绑定影响——与发布版一致。
                            partnerOverlay = partnerOverlay,
                        ),
                    )
                },
                // 装配结果的失效信号：仓储快照变了才重跑 `dataProvider`。
                // ⚠ 2026-11-07：天气也必须算进来。`weatherTick` 不参与的话，页面首次组合时
                // 预报还没到，`weatherLines` 就会一直空着（"今天那页刷过"、别的天永远没有，
                // 用户看到的就是"只有今天有天气"）。
                dataVersion = Triple(snapshot, coupleOverlayRevision, weatherTick),
                onCloseToWeekView = dayOverlay?.onRequestClose ?: onBack,
                // 待办带里「关联课程」的名字与颜色（Dart `provider.getCourseForTask`）。
                courseResolver = { task ->
                    snapshot.courses.firstOrNull { it.id == task.courseId }
                },
                onOpenCourse = { courseId ->
                    val target = snapshot.courses.firstOrNull { it.id == courseId }
                    wiring.pendingEditCourse = target
                    wiring.pendingAddCourseSeed = null
                    // 这一路是「从周视图看这门课」，不带来源周次（Dart 同款调用不传 initialWeek）。
                    // 清空是防止上一条「作业 → 查看课程」留下的周次串到这一次打开里。
                    wiring.pendingEditWeek = null
                    // 整组上下文：Dart `courseForm(courseGroup: provider.courseGroupForCourse(course), ...)`
                    //（同名课次编为一组），丢了它「改名 / 删整组」会退化成只改这一节。
                    val siblings = target?.let { picked ->
                        snapshot.courses.filter { it.name == picked.name }
                    }
                    wiring.pendingEditGroup = if (target == null || siblings.isNullOrEmpty()) {
                        null
                    } else {
                        com.mutx163.qingyu.pages.course.CourseGroup(
                            name = target.name,
                            courses = siblings,
                        )
                    }
                    onOpenPage("d1.addCourse")
                },
                // 日程卡 / 考试卡：Dart 分别去日程编辑页与考试列表页。壳里两条路都通，
                // 接上就不再有「卡片点了没反应」（不传回调时页面会直接把入口藏起来）。
                onOpenSchedule = { scheduleId, occurrenceDate ->
                    val item = snapshot.scheduleItems.firstOrNull { it.id == scheduleId }
                    if (item == null) {
                        onOpenPage("d2.scheduleList")
                    } else {
                        wiring.clearScheduleIntent()
                        wiring.pendingScheduleEdit = ScheduleItemBridge.toUiData(item)
                        // 跨天重复日程要带上是哪一天的那一次（Dart `occurrenceDate`，
                        // 与周网格点日程卡同一条口径）。
                        wiring.pendingScheduleOccurrenceDate =
                            occurrenceDate?.toLocalDate()?.toString()
                        onOpenPage("d2.addSchedule")
                    }
                },
                // 考试卡：Dart `examForm(exam: exam)`——直接开**这一场考试**的编辑页，
                // 不是考试列表（2026-10-31 审核 P1-4）。
                onOpenExam = { examId ->
                    val exam = repository.exams.firstOrNull { it.id == examId }
                    if (exam == null) {
                        onOpenPage("d3.examList")
                    } else {
                        wiring.pendingEditExam = exam
                        onOpenPage("d3.addExam")
                    }
                },
                // 课卡「备注」：单节备注弹层（Dart `showCourseNoteSheet(course:, week:)`）。
                onOpenCourseNotes = { courseId, week ->
                    val course = snapshot.courses.firstOrNull { it.id == courseId }
                    if (course != null) noteTarget = course to week
                },
                // 课卡「作业」：带课程 + **当前查看周**进作业表单（Dart `initialWeek: week`）。
                onOpenCourseTask = { courseId, week ->
                    val course = snapshot.courses.firstOrNull { it.id == courseId }
                    wiring.pendingTaskForEdit = null
                    wiring.pendingTaskCourse = course
                    wiring.pendingTaskWeek = if (course == null) null else week
                    onOpenPage("d2.addTask")
                },
                // 待办行 → 编辑表单。
                onOpenTask = { task ->
                    wiring.pendingTaskForEdit = task
                    wiring.pendingTaskCourse = null
                    wiring.pendingTaskWeek = null
                    onOpenPage("d2.addTask")
                },
                // 勾选待办：落盘失败会抛错，必须报出来（Dart `toggleTaskFromBand` 同口径），
                // 否则勾选框弹回去、用户零提示（2026-10-31 审核 P1-9）。
                onToggleTask = { task ->
                    runCatching { taskController.toggleTask(task) }
                        .onFailure {
                            Toast.makeText(
                                shellContext,
                                DayViewStrings.saveFailed.text,
                                Toast.LENGTH_SHORT,
                            ).show()
                        }
                },
                // 「还有 N 项逾期 ›」→ 任务清单（Dart `pushHomeMenuPage(context, homePage('taskListPage'))`）。
                onViewAllOverdue = { onOpenPage("d2.taskList") },
                // 翻页落定后做两件事：
                // ① 把仓储当前周同步过去 —— 否则退出日视图回到周视图还停在老周
                //   （Dart `settlePage` → `jumpToWeek(animatePage:false)` 同义）；
                // ② 把「看的是哪一天」写回存档 —— Dart `persistHomeViewState(mode:, dayOfWeek:)`
                //   同口径。外观编辑页的日预览与下次进入日视图的初始日都读这个键。
                //   只在真的变了才写（首帧停稳也会上报一次），写盘在 IO 上串行。
                onPageChanged = { week, dayOfWeek ->
                    if (snapshot.currentWeek != week) repository.setCurrentWeek(week)
                    // 作为首页展开层时，翻到哪一天要立刻回写首页（星期栏高亮、收起后的
                    // 落点都读它）。独立路由时 dayOverlay 为 null，不额外绕路。
                    dayOverlay?.onPageChanged?.invoke(week, dayOfWeek)
                    dayPersistScope.launch {
                        dayPersistMutex.withLock {
                            runCatching {
                                if (
                                    wiring.settingsModel.load().timetableLastViewedDayOfWeek !=
                                    dayOfWeek
                                ) {
                                    wiring.settingsModel.saveLastViewedDayOfWeek(dayOfWeek)
                                }
                            }.onFailure {
                                Log.w("home-day-view", "persist last viewed day failed", it)
                            }
                        }
                    }
                },
            )
            // 单节备注弹层（Dart 日课卡「备注」胶囊的落点）。
            val editingNotes = noteTarget
            CourseNoteSheet(
                show = editingNotes != null,
                course = editingNotes?.first,
                week = editingNotes?.second ?: snapshot.currentWeek,
                readOnly = false,
                onDismiss = { noteTarget = null },
                onSave = { wholeNote, sessionNote ->
                    val target = noteTarget
                    noteTarget = null
                    if (target != null) {
                        runCatching {
                            CourseActionDispatcher.saveCourseNotes(
                                port = repository,
                                courseId = target.first.id,
                                week = target.second,
                                wholeNote = wholeNote,
                                sessionNoteText = sessionNote,
                            )
                        }.onFailure {
                            Toast.makeText(
                                shellContext,
                                DayViewStrings.saveFailed.text,
                                Toast.LENGTH_SHORT,
                            ).show()
                        }
                    }
                },
            )
            }
        }

        // ── P3-D1 课程表单与概览 ───────────────────────────────────────
        // Phase 3.5：这一页改成**真接线**——周次表与节数取自仓储快照，
        // 保存回调真的写进仓储（以前 `onSave` 是默认的空实现，所以点了「保存」什么也不发生）。
        "d1.addCourse" -> {
            val snapshot = wiring.timetable.snapshot
            val shellContext = LocalContext.current
            // 「沿用已有课程」候选 + 教师/地点候选：发布版 provider.courseGroups /
            // uniqueTeachers / uniqueLocations 的拍平视图；同一个纯函数算一份，三处共用。
            val courseFieldSuggestions = CourseFieldSuggestionLogic.build(
                courses = snapshot.courses,
                scheduleLocations = snapshot.scheduleItems.map { it.location },
            )
            AddCoursePage(
                initialCourse = wiring.pendingEditCourse,
                // 组编辑：课程总览点某个课程组进来时带整组（Dart `AddCourseScreen(courseGroup:)`），
                // 让「改名 / 改整组课次」走 updateCourseGroup，而不是只改单门课。
                courseGroup = wiring.pendingEditGroup,
                // 「作业 → 查看课程」带进来的来源周次（Dart `AddCourseScreen(initialWeek: task.sourceWeek)`）。
                // 其余入口为 null，行为与之前一致。
                initialWeek = wiring.pendingEditWeek,
                initialDayOfWeek = wiring.pendingAddCourseSeed?.first,
                initialStartSection = wiring.pendingAddCourseSeed?.second,
                availableWeeks = (1..snapshot.settings.semesterWeekCount.coerceAtLeast(1)).toList(),
                globalSectionCount = snapshot.settings.sections.size,
                // 「沿用已有课程」候选（发布版 `provider.courseGroups` 的拍平视图）。
                courseTemplates = snapshot.courses,
                teacherSuggestions = courseFieldSuggestions.teachers,
                locationSuggestions = courseFieldSuggestions.locations,
                // 时间模板：候选 + 当前生效模板名（null = 没有生效模板，显示「跟随当前课表」）。
                timeSchemes = snapshot.timeSchemes,
                activeTimeSchemeName = snapshot.timeSchemes.firstOrNull { it.id == snapshot.activeTimeSchemeId }?.name,
                // 表单要一个「节次 → 起止时间」的解析器；优先用**用户自己的作息表**，
                // 拿不到才退回壳里的线性示例（08:00 起每节 45+10 分）。
                clockResolver = { entry ->
                    val sections = snapshot.settings.sections
                    val index = (entry.startSection - 1).coerceAtLeast(0)
                    val section = sections.getOrNull(index)
                    val templateStartTime = section?.startTime ?: clockText(8 * 60 + index * 55)
                    val templateEndTime = section?.endTime ?: clockText(8 * 60 + index * 55 + 45)
                    // Dart add_course_screen.dart:2021-2039：编辑既有课且原文 hasCustomTime、节次未变时，
                    // 模板不得覆盖适配脚本钉住的钟点（否则「改个教师再保存」会把 07:00 静默改回 08:00）。
                    val clock = com.mutx163.qingyu.course.CourseDomain.editCourseClock(
                        original = entry.originalCourse,
                        startSection = entry.startSection,
                        endSection = entry.endSection,
                        templateStartTime = templateStartTime,
                        templateEndTime = templateEndTime,
                    )
                    AddCourseEntryClock(
                        startTime = clock.startTime,
                        endTime = clock.endTime,
                        hasCustomTime = clock.hasCustomTime,
                    )
                },
                onSave = { payload ->
                    // 服务校验 / 落盘失败会抛异常。不接的话异常从 Compose 点击回调里逃逸，
                    // 用户可能看到闪退；Dart 口径是「失败弹保存失败、**不关页**」，填好的内容还在。
                    runCatching { wiring.applyAddCourseSave(payload) }
                        .onSuccess {
                            wiring.clearAddCourseIntent()
                            onBack()
                        }
                        .onFailure {
                            Toast.makeText(
                                shellContext,
                                AddCourseStrings.saveFailed.text,
                                Toast.LENGTH_SHORT,
                            ).show()
                        }
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
        // 课程总览：真接线收在 CourseOverviewHost（订阅仓储 + 冲突索引 + 排序档 UI 态 +
        // 组编辑/冲突详情/新建三条导航）。以前这里喂 `emptyList()` + 4 个空回调，
        // 于是页面永远空态、排序点不动、行点了没反应。
        "d1.overview" -> CourseOverviewHost(
            wiring = wiring,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )

        // ── P3-D2 日程域：从示例数据换成真宿主（Phase 3.5 接线）──────────
        // 列表/日期规则走 ScheduleHost 订阅仓储；添加/编辑页由壳带意图（编辑对象 / 默认日期 /
        // 某一次发生的日期）打开，保存/删除经 ShellWiring 的 ScheduleEditDispatcher 落盘。
        "d2.scheduleList" -> ScheduleListHost(
            repository = wiring.timetable,
            todayIso = LocalDate.now().toString(),
            onBack = onBack,
            onAdd = {
                wiring.clearScheduleIntent()
                wiring.pendingScheduleInitialDate = LocalDate.now().toString()
                onOpenPage("d2.addSchedule")
            },
            onEdit = { item ->
                wiring.pendingScheduleEdit = item
                wiring.pendingScheduleOccurrenceDate = null
                onOpenPage("d2.addSchedule")
            },
            onDelete = { item -> wiring.deleteScheduleItem(item, null) },
        )
        // 添加 / 编辑日程：必须经 `ScheduleEditHost`（不要直调 `AddScheduleItemPage`）。
        // 宿主负责三件页面自己做不到的事：① 落盘成败的反馈（失败不关页 + 提示，不能「点了没反应」）；
        // ② 通知权限状态机（`PermissionFlow` + `rememberLauncherForActivityResult`），
        // 选中提醒档位时把 `reminderPermissionMissing` / `onRequestNotificationPermission` /
        // `onReminderSelected` 三个参数喂给页面，让「检查通知权限」那块真的出现；
        // ③ 成功后关页并清一次性意图。壳里重复写一套权限判据必然与宿主漂移。
        // `successToast = false`：本版成功路径「关页即反馈」，不额外弹提示。
        "d2.addSchedule" -> ScheduleEditHost(
            scheduleItem = wiring.pendingScheduleEdit,
            initialDate = wiring.pendingScheduleInitialDate ?: LocalDate.now().toString(),
            occurrenceDate = wiring.pendingScheduleOccurrenceDate,
            onSave = { draft, applyToAll -> wiring.saveScheduleItem(draft, applyToAll) },
            onDelete = { item, applyToAll -> wiring.deleteScheduleItem(item, applyToAll) },
            onFinish = {
                wiring.clearScheduleIntent()
                onBack()
            },
            successToast = false,
        )
        // 日期规则：规则读写 + 保存后的「自动套用 + 四态提示」都收在宿主里。
        // 壳**不再**自己 launch applyDue —— 那样返回值只能丢掉，规则今天该套却套失败时
        // 用户会看到「已保存」而作息没变（2026-11-05 修）。
        "d2.dateRule" -> ScheduleDateRuleHost(
            repository = wiring.timetable,
            todayIso = LocalDate.now().toString(),
            onBack = onBack,
        )
        // 任务清单：宿主抽到 `app/TaskHost.kt`（`TaskListHost`），与底栏「任务」tab 复用同一份接线。
        //
        // 为什么要抽：这个页面有**两个渲染点**——本路由与 `PagesShellActivity` 的 `DockSlot.TASK`。
        // 抽出前，本路由是真数据、底栏那个还在喂 `shellSampleTaskViewState()`（演示空态 + 5 个空回调），
        // 于是「从路由进去能用、从底栏进去是死的」。两份各写一遍接线必然再次漂移。
        "d2.taskList" -> TaskListHost(
            repository = wiring.timetable,
            onBack = onBack,
            onOpenAddTask = {
                wiring.pendingTaskForEdit = null
                wiring.pendingTaskCourse = null
                onOpenPage("d2.addTask")
            },
            // 点任务行 → 带这条任务进「编辑任务」表单。
            onOpenEditTask = { task ->
                wiring.pendingTaskForEdit = task
                wiring.pendingTaskCourse = null
                onOpenPage("d2.addTask")
            },
            // 课程直达：带这门课进课程编辑页（与课程总览点课程同一落点 d1.addCourse）。
            // 2026-10-29：补上来源周次——Dart `task_list_screen.dart:346-357` 传的是
            // `AddCourseScreen(course: course, initialWeek: task.sourceWeek)`，
            // 少这一条则打开后周次区间落在默认值上，看不到这条作业的来源周。
            onOpenCourse = { course, sourceWeek ->
                wiring.pendingEditCourse = course
                wiring.pendingEditGroup = null
                wiring.pendingEditWeek = sourceWeek
                onOpenPage("d1.addCourse")
            },
        )
        // T1 收尾：作业表单接上真状态机（新建 + 编辑两路）。
        // 新建：来自课程操作弹层「作业」时预选课程，纯新建从「+」进入。
        // 编辑：清单页点任务行 → pendingTaskForEdit 带着原任务进来，表单载入原值、保存走 updateTask。
        "d2.addTask" -> {
            val taskSnapshot = wiring.timetable.snapshot
            val editingTask = wiring.pendingTaskForEdit
            val preselectedCourse = wiring.pendingTaskCourse
            // 日视图「作业」胶囊带的来源周（Dart `taskForm(initialWeek: week)`）；
            // 其余入口为 null ⇒ 退回仓储当前周，行为与之前一致。
            val sourceWeek = wiring.pendingTaskWeek ?: taskSnapshot.currentWeek
            val shellContext = LocalContext.current
            var taskForm by remember(editingTask?.id, preselectedCourse?.id, sourceWeek) {
                mutableStateOf(
                    if (editingTask != null) {
                        // 编辑既有任务：载入原任务的全部字段（对齐 Dart AddTaskScreen(task:)）。
                        AddTaskFormReducer.initialFromTask(editingTask, taskSnapshot.courses)
                    } else {
                        AddTaskFormReducer.initial(
                            preselectedCourse = preselectedCourse,
                            sourceWeek = sourceWeek,
                            courseOccurrenceDate = preselectedCourse?.let {
                                wiring.timetable.dateForCourseOccurrence(it, sourceWeek)
                            },
                        )
                    },
                )
            }
            AddTaskPage(
                viewState = taskForm,
                // 返回 / 保存都要清一次性意图：否则「从日视图第 5 周记作业」取消后再从
                // 任务清单点新建，来源周还停在第 5 周（2026-10-31 审核 P2-8）。
                onBack = {
                    wiring.pendingTaskForEdit = null
                    wiring.pendingTaskCourse = null
                    wiring.pendingTaskWeek = null
                    onBack()
                },
                onTitleChange = { taskForm = AddTaskFormReducer.withTitle(taskForm, it) },
                onNoteChange = { taskForm = AddTaskFormReducer.withNote(taskForm, it) },
                // task-18：两个子弹层的**候选数据 + 处理函数**（弹层由页面自己弹）。
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
                // 2026-10-29：原先还传过 `onPickCourseClick = {}` / `onPickDueDateClick = {}`。
                // 两个弹层都是页面内部行为（候选与结果走 `courseOptions` / `onDueDatePicked` 等），
                // 那两个参数只剩空实现，已从页面 API 删除，这里不再传。
                onHasDueDateChange = { taskForm = AddTaskFormReducer.withHasDueDate(taskForm, it) },
                onCompletedChange = { taskForm = AddTaskFormReducer.withCompleted(taskForm, it) },
                // 编辑态才显示删除按钮；删除前页面自己弹确认框（对齐 Dart _confirmDelete）。
                onDelete = if (editingTask != null) {
                    {
                        runCatching {
                            TimetableCourseService.deleteTask(wiring.timetable, editingTask.id)
                        }.onSuccess {
                            wiring.pendingTaskForEdit = null
                            onBack()
                        }.onFailure {
                            Toast.makeText(shellContext, TaskStrings.saveFailed, Toast.LENGTH_SHORT).show()
                        }
                    }
                } else {
                    null
                },
                onSave = {
                    val titleError = AddTaskFormReducer.validate(taskForm)
                    if (titleError != null) {
                        taskForm = taskForm.copy(titleError = titleError)
                    } else {
                        runCatching {
                            if (editingTask != null) {
                                TimetableCourseService.updateTask(
                                    wiring.timetable,
                                    AddTaskFormReducer.buildTask(taskForm, existingTask = editingTask),
                                )
                            } else {
                                TimetableCourseService.addTask(
                                    wiring.timetable,
                                    AddTaskFormReducer.buildTask(taskForm),
                                )
                            }
                        }.onSuccess {
                            wiring.pendingTaskForEdit = null
                            wiring.pendingTaskCourse = null
                            wiring.pendingTaskWeek = null
                            onBack()
                        }.onFailure { error ->
                            // 与 Dart 一致：标题必填 / 关联课程不存在 / 落盘失败分三种说法。
                            Toast.makeText(
                                shellContext,
                                TaskFilterLogic.mapSaveError(error),
                                Toast.LENGTH_SHORT,
                            ).show()
                        }
                    }
                },
            )
        }

        // ── P3-D3 作息与考试 ──────────────────────────────────────────
        // 2026-10-29（P35-TS 收口）：这一屏原先喂空模型 + 七个空回调 ⇒ 打开永远空列表、
        // 任何动作都无处落盘（审核见 `docs/plans/2026-10-29-compose-time-scheme-audit.md`）。
        // 现在换成真宿主：读仓储快照、动作落到仓储写入口、六个弹层由宿主状态机驱动。
        "d3.timeSchemes" -> TimeSchemeManagementHost(
            repository = wiring.timetable,
            onBack = onBack,
            onOpenEditor = { schemeId ->
                // 编辑器是独立壳路由：id 走一次性意图，页面 id 走路由串（与其余子页同构）。
                wiring.pendingTimeSchemeEditId = schemeId
                onOpenPage("d3.timeSchemeEditor")
            },
            onOpenLocationEntry = { onOpenPage("d3.locationMatch") },
            onOpenDateRules = { onOpenPage("d2.dateRule") },
        )
        // 时间模板「编辑节次」子页（`d3.timeSchemeEditor`）：没有任何模板 id 时直接退回，
        // 不渲染一个「不知道在编辑哪一套」的空壳。
        "d3.timeSchemeEditor" -> {
            val editingId = wiring.pendingTimeSchemeEditId
            if (editingId == null) {
                LaunchedEffect(Unit) { onBack() }
            } else {
                TimeSchemeEditorHost(
                    repository = wiring.timetable,
                    schemeId = editingId,
                    onBack = {
                        wiring.pendingTimeSchemeEditId = null
                        onBack()
                    },
                )
            }
        }
        // ── F10（2026-10-29）：地点作息匹配接真宿主 ───────────────────
        // 原先 `LocationTimeMatchModel()` 空模型 + 五个空回调 ⇒ 永远空列表、点哪都没反应。
        // 现在分组读仓储快照、增删改开关整份写回 `location_time_groups`
        //（`TimetableRepository.updateLocationTimeGroups`），编辑子页在同一宿主内切换。
        // 「重新匹配当前课表」已接入（2026-11-05）：纯逻辑 `LocationTimeApplyLogic`（JVM 可测）
        // 照 Dart `TimetableLocationRuleService.applyToActiveProfile` 移植，写盘走
        // `replaceActiveProfileContent`（先落盘成功才改内存，失败抛错由宿主弹「保存失败」）。
        "d3.locationMatch" -> {
            val snapshot = wiring.timetable.snapshot
            LocationTimeMatchHost(
                groups = snapshot.locationTimeGroups,
                // 模板 id → 名字，保持快照里的原顺序（编辑页默认选第一套）。
                schemeNames = snapshot.timeSchemes.associate { it.id to it.name },
                // 课表地点候选（去重、去空白），给编辑页的楼栋关键词挑选用。
                availableLocations = snapshot.courses
                    .map { it.location.trim() }
                    .filter { it.isNotEmpty() }
                    .distinct(),
                onBack = onBack,
                onSaveGroups = { groups ->
                    // 落盘失败会抛错，宿主据此不回显、给「保存失败」——不能吞掉异常。
                    // `resync = true`：分组变了就必须按新分组重算课程钟点（Dart 三个 CRUD
                    // 入口 createGroup/updateGroup/deleteGroup 都跟着 resyncAllProfiles，
                    // `timetable_location_rule_service.dart:199-205 / 236-240 / 256-260`）。
                    // 少了它，界面上模板名变了、课表时间仍是旧楼的节次（仓储
                    // `updateLocationTimeGroupsLocked` 的 `if (!resync)` 早退分支）。
                    wiring.timetable.updateLocationTimeGroups(groups, resync = true)
                },
                // 确认框正文里的「命中 N 门」：用**当前生效的分组**现算，
                // 与 Dart `_applyToActive` 的 `provider.matchLocationTime(course.location)`
                // 逐条同口径（`location_time_match_screen.dart:171-173`）。
                matchedCourseCount = { groups ->
                    snapshot.courses.count {
                        LocationTimeMatchLogic.match(it.location, groups) != null
                    }
                },
                onApplyActive = { groups ->
                    // 「重新匹配当前课表」：纯逻辑在 `LocationTimeApplyLogic`，这里只做
                    // 「算 → 有新东西才落盘 → 把统计回给宿主」（Dart `applyLocationTimeRulesToActiveProfile`）。
                    // `groups` 由宿主传入（列表里当前那份，也是确认框算命中数用的那份）；
                    // 不用 `snapshot.locationTimeGroups` 是为了避开「刚保存、还没重组」那一下
                    // 弹窗数与执行口径不一致的窄窗口。
                    val plan = LocationTimeApplyLogic.plan(
                        courses = snapshot.courses,
                        schemes = snapshot.timeSchemes,
                        settings = snapshot.settings,
                        locationTimeGroups = groups,
                        scheduleDateRules = snapshot.scheduleDateRules,
                    )
                    if (plan.stats.hasChanges) {
                        // 与 Dart 一致：没有任何变化就不落盘（只在有更新时写）。
                        // `replaceActiveProfileContent` 是「先落盘、成功才改内存」，失败会抛错，
                        // 宿主据此弹「保存失败」，不会出现「报了成功、盘上没变」。
                        wiring.timetable.replaceActiveProfileContent(
                            courses = plan.courses,
                            tasks = wiring.timetable.tasks,
                            exams = wiring.timetable.exams,
                        )
                    }
                    plan.stats
                },
            )
        }
        // ── F10（2026-10-29）：加考试页接真状态机 ─────────────────────
        // 之前这一屏是 `AddExamViewState(isEditing = false)` 写死 + 14 个空回调：
        // 整页静态图，而且 `isEditing` 恒 false ⇒「编辑既有考试」这条路根本不存在。
        // 现在表单状态由 `AddExamFormReducer`（纯函数、JVM 可测）驱动，
        // 写库走 `TimetableExamService`（`f70604b0` 已交付，`d3.examList` 的删除也用它）。
        // ⚠️ 提醒只做到「存得住、回显得出来」：通知换通道排在 Phase 4，本批不假装会响。
        "d3.addExam" -> {
            val snapshot = wiring.timetable.snapshot
            val editingExam = wiring.pendingEditExam
            var examForm by remember(editingExam?.id) {
                mutableStateOf(AddExamFormReducer.initial(editingExam))
            }
            // 四个弹层的开合：页面只暴露回调、不假装自己有选择器（见 AddExamPage KDoc）。
            var datePickerOpen by remember { mutableStateOf(false) }
            var startPickerOpen by remember { mutableStateOf(false) }
            var endPickerOpen by remember { mutableStateOf(false) }
            var coursePickerOpen by remember { mutableStateOf(false) }
            var reminderPickerOpen by remember { mutableStateOf(false) }
            // 正在改的那一条自定义提醒（分钟）；null = 新增
            var reminderEditing by remember { mutableStateOf<Int?>(null) }

            val selectedCourse = AddExamFormReducer.selectedCourse(examForm, snapshot.courses)
            AddExamPage(
                viewState = examForm,
                selectedCourse = selectedCourse,
                courseGroupsEmpty = AddExamFormReducer.courseGroupsEmpty(snapshot.courses),
                dateDisplayText = AddExamFormReducer.dateDisplay(
                    state = examForm,
                    semesterStart = snapshot.settings.semesterStartDate,
                    semesterWeekCount = snapshot.settings.semesterWeekCount,
                ),
                locationHintText = AddExamLogic.locationHint(selectedCourse),
                onBack = onBack,
                onSave = {
                    val checked = AddExamFormReducer.validate(examForm)
                    examForm = checked.state
                    if (checked.blocker == null) {
                        runCatching {
                            val exam = AddExamFormReducer.buildExam(
                                state = checked.state,
                                existing = editingExam,
                                now = LocalDateTime.now(),
                            )
                            val service = TimetableExamService(CoursePortExamAdapter(wiring.timetable))
                            if (editingExam != null) service.updateExam(exam) else service.addExam(exam)
                        }.onSuccess {
                            wiring.pendingEditExam = null
                            onBack()
                        }.onFailure {
                            // Dart `add_exam_screen.dart:1089-1103`：落盘失败弹「保存失败」
                            // 并且**不关页面**（填好的内容还在，用户能立刻重试）。
                            // 这里用页内错误条而不是系统 toast —— 与这一页其余校验失败同一个出口。
                            examForm = examForm.copy(toastMessage = ExamStrings.saveFailed.text)
                        }
                    }
                },
                onDelete = {
                    // 只有编辑态才显示删除按钮（页面按 viewState.isEditing 决定），
                    // 删除前的确认框也由页面自己弹。
                    editingExam?.let { target ->
                        runCatching {
                            TimetableExamService(CoursePortExamAdapter(wiring.timetable))
                                .deleteExam(target.id)
                        }.onSuccess {
                            wiring.pendingEditExam = null
                            onBack()
                        }.onFailure {
                            examForm = examForm.copy(toastMessage = ExamStrings.saveFailed.text)
                        }
                    }
                },
                onNameChange = { examForm = AddExamFormReducer.withName(examForm, it) },
                onPickCourse = { if (snapshot.courses.isNotEmpty()) coursePickerOpen = true },
                onPickDate = { datePickerOpen = true },
                onPickStartTime = { startPickerOpen = true },
                onPickEndTime = { endPickerOpen = true },
                onLocationChange = { examForm = AddExamFormReducer.withLocation(examForm, it) },
                onSeatChange = { examForm = AddExamFormReducer.withSeat(examForm, it) },
                onNoteChange = { examForm = AddExamFormReducer.withNote(examForm, it) },
                onReminderPresetChange = {
                    examForm = AddExamFormReducer.withReminderPreset(examForm, it)
                },
                onAddCustomReminder = {
                    reminderEditing = null
                    reminderPickerOpen = true
                },
                onEditCustomReminder = { minutes ->
                    reminderEditing = minutes
                    reminderPickerOpen = true
                },
                onRemoveCustomReminder = {
                    examForm = AddExamFormReducer.withCustomReminderRemoved(examForm, it)
                },
            )

            ExamCoursePickerSheet(
                show = coursePickerOpen,
                options = AddExamFormReducer.coursePickerOptions(
                    snapshot.courses,
                    examForm.selectedCourseId,
                ),
                onPick = { courseId ->
                    coursePickerOpen = false
                    examForm = AddExamFormReducer.withCourse(
                        examForm,
                        snapshot.courses.firstOrNull { it.id == courseId },
                    )
                },
                onDismiss = { coursePickerOpen = false },
            )
            ExamDatePickerSheet(
                show = datePickerOpen,
                semesterStart = snapshot.settings.semesterStartDate,
                totalWeeks = snapshot.settings.semesterWeekCount,
                // 没点过日期就不预选（Dart `:700-703`）
                selectedDate = examForm.selectedDate.takeIf { examForm.hasSelectedDate },
                onPick = { date ->
                    datePickerOpen = false
                    examForm = AddExamFormReducer.withDate(examForm, date)
                },
                onDismiss = { datePickerOpen = false },
            )
            ExamTimePickerSheet(
                show = startPickerOpen,
                title = ExamStrings.examStartTimeLabel.text,
                initial = examForm.startTime,
                onPick = { value ->
                    startPickerOpen = false
                    examForm = AddExamFormReducer.withStartTime(examForm, value)
                },
                onDismiss = { startPickerOpen = false },
            )
            ExamTimePickerSheet(
                show = endPickerOpen,
                title = ExamStrings.examEndTimeLabel.text,
                initial = examForm.endTime,
                onPick = { value ->
                    endPickerOpen = false
                    examForm = AddExamFormReducer.withEndTime(examForm, value)
                },
                onDismiss = { endPickerOpen = false },
            )
            ExamReminderPickerSheet(
                show = reminderPickerOpen,
                initialMinutes = reminderEditing,
                onPick = { totalMinutes ->
                    reminderPickerOpen = false
                    examForm = AddExamFormReducer.withCustomReminderAdded(
                        state = examForm,
                        totalMinutes = totalMinutes,
                        replacingMinutes = reminderEditing,
                    )
                },
                onDismiss = { reminderPickerOpen = false },
            )
        }
        "d3.examList" -> {
            val repository = wiring.timetable
            val shellContext = LocalContext.current
            // 快照 TimetableSnapshot 不含 exams，故用 tick 无条件触发重组：
            // deleteExam 会 notifyStateChanged，回调里 tick++ 让列表立刻刷新。
            var tick by remember(repository) { mutableStateOf(0) }
            DisposableEffect(repository) {
                val subscription = repository.observe { tick++ }
                onDispose { subscription.close() }
            }
            val examService = remember(repository) {
                TimetableExamService(CoursePortExamAdapter(repository))
            }
            ExamListPage(
                viewState = remember(tick) {
                    ExamListLogic.buildListViewState(
                        exams = repository.exams,
                        courses = repository.courses,
                        // 2026-11-01 F24：以前写死 null，屏上永远没有「第 N 周」。
                        // 与「添加/编辑考试」同源；没设开学日时模型自己退回只显示日期。
                        semesterStart = repository.snapshot.settings.semesterStartDate,
                        now = LocalDateTime.now(),
                    )
                },
                onBack = onBack,
                onAddExam = {
                    // 「+」是纯新建：必须清掉上一次「点考试进编辑」留下的意图，
                    // 否则会带着旧考试的表单打开（与课程页 `clearAddCourseIntent` 同一条纪律）。
                    wiring.pendingEditExam = null
                    onOpenPage("d3.addExam")
                },
                onOpenExam = { exam ->
                    // F10：以前这里不传 id ⇒ 点进去永远是空白新建表单。现在带对象进编辑态。
                    wiring.pendingEditExam = exam
                    onOpenPage("d3.addExam")
                },
                onDeleteExam = { exam ->
                    // 落盘失败会抛异常；不接就从点击回调逃逸（可能崩）。如实弹「保存失败」，
                    // 列表由仓储通知刷新，失败时列表保持不变。
                    runCatching { examService.deleteExam(exam.id) }
                        .onFailure {
                            Toast.makeText(
                                shellContext,
                                ExamStrings.saveFailed.text,
                                Toast.LENGTH_SHORT,
                            ).show()
                        }
                },
            )
        }

        // ── P3-E 统计族 ───────────────────────────────────────────────
        "e.statistics" -> {
            val context = LocalContext.current
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            // 壳内局部状态：分段（学期/周）与周视图选中的周。
            var semesterView by remember { mutableStateOf(true) }
            var selectedWeek by remember { mutableStateOf<Int?>(null) }
            // 导出模块选择弹层开关（2026-11-10 审核项 #6）：点分享先选模块、再按勾选渲染长图，
            // 与发布版 `course_statistics_screen.dart:37-70` 的「先弹 export sheet 再导出」同流程。
            var showExportSheet by remember { mutableStateOf(false) }
            // P0-a（切页首帧减负）：统计主页**只用 home**，不再调 `StatisticsFeed.feed(...)`
            // ——feed 会连 `session` 一起装配（`StatisticsFeed.kt:289-315`，对每门课跑
            // `CourseSessionStatsCalculator` 遍历整学期），对主页纯属白算；session 明细是
            // `e.session` 页才用。这里只算 home，首帧不再背那坨同步 CPU。行为不变（同源）。
            // 入参只换装一次：homeState 与导出时的排行读数共用同一份 `Input`，两处不会各算一套。
            val feedInput = remember(snapshot) { StatisticsFeed.Input.fromSnapshot(snapshot) }
            val homeState = remember(feedInput, semesterView, selectedWeek) {
                StatisticsFeed.homeViewState(
                    input = feedInput,
                    now = LocalDateTime.now(),
                    selectedWeek = selectedWeek,
                    semesterView = semesterView,
                )
            }
            CourseStatisticsPage(
                viewState = homeState,
                onBack = onBack,
                // tab 0 = 学期视图（`CourseStatisticsPage.kt:170` `selectedTabIndex == 0 && semester != null`）
                onTabSelected = { index -> semesterView = index == 0 },
                onOpenSettings = { onOpenPage("e.statisticsSettings") },
                // 2026-11-10（审核项 #6）：分享先弹「导出模块」弹层，选完再按勾选渲染长图
                // （发布版 `course_statistics_screen.dart:37-70` → `showStatisticsExportSheet`）。
                // 弹层显隐与确认都在本分支内，页面签名不动。
                onOpenShare = { showExportSheet = true },
                onWeekChanged = { week -> selectedWeek = week },
                onOpenAnalysis = { module ->
                    wiring.pendingAnalysisModule = module
                    onOpenPage("e.analysis")
                },
                onOpenSessions = { onOpenPage("e.session") },
            )

            // 导出模块选择弹层（常驻组合：show 只驱动显隐，关闭时官方退场动画才能播完）。
            // 学期内容为空（无课/空态）时分享按钮本来就不出现，这里再判一次是为了
            // 类型上拿到非空 `SemesterContent`，不靠 `!!`。
            val exportSemester = homeState.semester
            if (exportSemester != null) {
                StatisticsExportSheet(
                    show = showExportSheet,
                    hasAchievements = exportSemester.achievements.isNotEmpty(),
                    hasStories = exportSemester.stories.isNotEmpty(),
                    dark = isSystemInDarkTheme(),
                    onDismissRequest = { showExportSheet = false },
                    onConfirm = { options ->
                        showExportSheet = false
                        // 排行不在主页的学期内容块里（那是深度分析页的内容），按同一份
                        // `feedInput` 现算：行序、课时都出自同一条统计口径
                        // （`StatisticsAnalysisModel.analysisViewState(RANKING, …)`）。
                        val rankingRows = StatisticsAnalysisModel.analysisViewState(
                            module = StatisticsAnalysisModule.RANKING,
                            courses = feedInput.courses,
                            currentWeek = homeState.currentWeek,
                            semesterWeekCount = homeState.semesterWeekCount,
                            hasOtherProfiles = feedInput.hasOtherProfiles,
                            activeProfileName = feedInput.activeProfileName,
                        ).rankingRows
                        shareStatisticsExport(
                            context = context,
                            options = options,
                            content = StatisticsExportContent(
                                semester = exportSemester,
                                rankingRows = rankingRows,
                            ),
                            // 正文仍由 `StatisticsShareText` 用同一份 homeState 拼：
                            // 图与文本降级路径的字同源，不会出现「图里一套、文字里一套」。
                            text = StatisticsShareText.build(homeState),
                            subject = StatisticsShareText.subject(),
                        )
                    },
                )
            }
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
                //
                // 顺序与补偿都在 `WeeklyReportToggleLogic.applyToggle`（纯逻辑、L0 直测）：
                // 先查通知可达性 → 不可达拒绝打开（不写任何状态）→ 先调度成功再写 settings →
                // settings 写失败用开头算好的同一组值补偿回写。这里只注入真实副作用，**不重排顺序**。
                onWeeklyReportToggle = { enabled ->
                    WeeklyReportToggleLogic.applyToggle(
                        enabled = enabled,
                        plan = {
                            val now = LocalDateTime.now()
                            val snap = wiring.timetable.snapshot
                            WeeklyReportToggleLogic.Plan(
                                fireAtMillis = WeeklyReportScheduleLogic.nextFireAtMillis(now),
                                title = WeeklyReportScheduleLogic.buildTitle(),
                                body = WeeklyReportScheduleLogic.buildBody(
                                    courses = snap.courses,
                                    currentWeek = snap.currentWeek,
                                    semesterWeekCount = snap.settings.semesterWeekCount,
                                ),
                            )
                        },
                        canDeliver = { WeeklyReportScheduler.canDeliver(wiring.context) },
                        scheduleNext = { planned ->
                            WeeklyReportScheduler.scheduleNext(
                                context = wiring.context,
                                enabled = true,
                                fireAtMillis = planned.fireAtMillis,
                                title = planned.title,
                                body = planned.body,
                            )
                        },
                        cancel = { WeeklyReportScheduler.cancel(wiring.context) },
                        // 开关值同时写 settings，否则备份/导出永远读到旧的 false。
                        // settings 已是唯一真源（见 TimetableStore）。
                        //
                        // 2026-11-06 返工①（hy 首查+交叉复核坐实）：writeRawSettingsPatch
                        // 返回 Boolean、false = 底层抛错（TimetableRepository:464-484 内部
                        // catch），原先直接把 Boolean 当 Unit 丢掉 ⇒ 写失败无声吞掉，
                        // WeeklyReportToggleLogic 的两条补偿（挂 catch(Throwable)）永不执行
                        // ⇒ pref=开、settings 真源=关的假开关。现在**写失败必须抛**
                        // （同仓先例 LanTransferSettingsStore.kt:48-52）：逻辑层 catch 后
                        // 撤闹钟（开）/补偿回写（关）再 rethrow，页面 catch 回滚 UI。
                        // 接线由 WeeklyReportShellWiringGuardTest 钉住。
                        writeSettings = { value ->
                            if (!wiring.timetable.writeRawSettingsPatch(mapOf("weeklyReportEnabled" to value))) {
                                throw IllegalStateException("weekly_report_settings_write_failed")
                            }
                        },
                    )
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
                // 六张卡的真实读数由模型层算（`StatisticsAnalysisModel.analysisViewState`），
                // 这里只把快照/课表换装进去。原先前端只喂 module 与 courseCount，其余参数
                // 全是默认空表 ⇒ 六张卡恒空（P0）。对比卡要的其余课表逐份带进去。
                viewState = StatisticsAnalysisModel.analysisViewState(
                    module = wiring.pendingAnalysisModule,
                    courses = snapshot.courses,
                    currentWeek = snapshot.currentWeek,
                    semesterWeekCount = snapshot.settings.semesterWeekCount,
                    hasOtherProfiles = feedState.hasOtherProfiles,
                    activeProfileName = snapshot.profiles
                        .firstOrNull { it.id == snapshot.activeProfileId }
                        ?.name
                        ?: snapshot.profiles.firstOrNull()?.name.orEmpty(),
                    otherProfiles = snapshot.profiles
                        .filter { it.id != snapshot.activeProfileId }
                        .map { profile ->
                            StatisticsAnalysisModel.ProfileAnalysisInput(
                                name = profile.name,
                                courses = profile.courses,
                                currentWeek = profile.currentWeek.toInt(),
                                semesterWeekCount = profile.settings.semesterWeekCount,
                            )
                        },
                ),
                onBack = onBack,
                // 点排行里的课名 → 课程编辑页（Dart `statistics_analysis_screen.dart:190`
                // `_openCourseEdit`：按课名取第一门 + 同名整组，找不到就静默不动作）。
                // 可点性由渲染层按 `rankingOpenableNames` 逐行判定，这里只负责落点。
                onOpenCourse = { courseName ->
                    StatisticsRankingLinkModel.resolve(snapshot.courses, courseName)?.let { link ->
                        wiring.pendingEditCourse = link.course
                        wiring.pendingAddCourseSeed = null
                        // 排行这一路不带来源周次：不清会把上一次加课的周次串进来。
                        wiring.pendingEditWeek = null
                        // 必须带同名整组，否则保存时「改名 / 删整组」会退化成只改这一节。
                        wiring.pendingEditGroup = com.mutx163.qingyu.pages.course.CourseGroup(
                            name = link.courseName,
                            courses = link.groupCourses,
                        )
                        onOpenPage("d1.addCourse")
                    }
                },
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
                    repository = wiring.timetable,
                    passwordProvider = { configStore.readPassword() },
                )
            }
            var showConnect by remember { mutableStateOf(false) }
            // 2026-10-30（F12）：正在看详情的那条备份（null = 不展示弹层）。
            var openBackupId by remember { mutableStateOf<String?>(null) }
            // 2026-11-02：连接弹层的进行中状态 + IO 线程调度。connect / testConnection 是
            // 同步阻塞网络请求，直接在主线程调会 NetworkOnMainThreadException 闪退；
            // 写法沿用本仓既有的 scope + withContext(Dispatchers.IO)（同
            // CoupleTimetableSettingsHost / CloudBackupDetailHost），不自造线程池。
            var sheetTesting by remember { mutableStateOf(false) }
            var sheetConnecting by remember { mutableStateOf(false) }
            val scope = rememberCoroutineScope()
            CloudSyncPage(
                controller = controller,
                onBack = onBack,
                onConnect = { showConnect = true },
                // 2026-10-30（F12）：此前点某条备份只弹一句「备份详情尚未开放」——假入口。
                // 现在打开真详情弹层（设备 / 来源 / 内容 + 恢复 + 删除），
                // 恢复与删除都落到 `CloudSyncController` 的真动作上。
                onOpenBackup = { entryId -> openBackupId = entryId },
                onViewAllBackups = { onOpenPage("f.backupList") },
            )
            // 详情弹层（f.cloudSync 与 f.backupList 共用同一个宿主，只是列表来源不同）。
            CloudBackupDetailHost(
                controller = controller,
                entryId = openBackupId,
                onDismiss = { openBackupId = null },
            )
            if (showConnect) {
                WebdavConnectSheet(
                    initialUsername = controller.config.username,
                    testing = sheetTesting,
                    connecting = sheetConnecting,
                    onTestConnection = { u, p ->
                        scope.launch {
                            sheetTesting = true
                            val ok = withContext(Dispatchers.IO) { controller.testConnection(u, p) }
                            sheetTesting = false
                            if (!ok) {
                                // 失败不关弹层：错误码已写进 status（页面 lastErrorText 同步可见），
                                // Toast 沿用本分支既有提示通道给一句本地化的人话。
                                Toast.makeText(
                                    context,
                                    SyncStrings.localizeSyncError(controller.lastErrorCode),
                                    Toast.LENGTH_SHORT,
                                ).show()
                            }
                        }
                    },
                    onConfirm = { u, p ->
                        scope.launch {
                            sheetConnecting = true
                            val result = withContext(Dispatchers.IO) { controller.connect(u, p) }
                            sheetConnecting = false
                            if (result.success) {
                                // 只在成功时关弹层；失败留在弹层里改完重试，错误码已进 status。
                                showConnect = false
                            } else {
                                Toast.makeText(
                                    context,
                                    SyncStrings.localizeSyncError(result.errorCode),
                                    Toast.LENGTH_SHORT,
                                ).show()
                            }
                        }
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
                    repository = wiring.timetable,
                    passwordProvider = { configStore.readPassword() },
                )
            }
            var openBackupId by remember { mutableStateOf<String?>(null) }
            CloudBackupListPage(
                controller = controller,
                onBack = onBack,
                // 2026-10-30（F12）：同 f.cloudSync，占位提示换成真详情弹层。
                onOpenBackup = { entryId -> openBackupId = entryId },
            )
            CloudBackupDetailHost(
                controller = controller,
                entryId = openBackupId,
                onDismiss = { openBackupId = null },
            )
        }
        // 2026-10-29（C1 收口）：这一屏原先喂 `binding = null` + 默认配置 + 三个空回调
        // ⇒ 永远停在「尚未绑定」、九个按钮点了没反应（审核见
        // `docs/plans/2026-10-29-compose-couple-audit.md` §四）。现在换成真宿主：
        // 状态从仓储/prefs 读、九个动作落到控制器、导入导出走 SAF、结果弹 Toast。
        // 退出时自增 `coupleOverlayRevision`（B1 · 2026-11-06）：这一页改的绑定/颜色/周偏移
        // 只落键值存储、不碰课表仓储，日视图的 `dataVersion` 感知不到——不自增的话
        // 用户在情侣页改完颜色，回日视图看到的是旧色（「改了没反应」）。
        "f.couple" -> CoupleTimetableSettingsHost(
            wiring = wiring,
            onBack = {
                wiring.coupleOverlayRevision++
                onBack()
            },
        )

        // ── P3-G1 导入 · 基础 ────────────────────────────────────────
        // 2026-10-29 F07 接壳：此前三页都是「默认视图状态 + 空回调」——随机配色开关点了不动、
        // 四条导入方式点了不动、两个「选择文件」与「下载模板」全空。现在交给三个宿主：
        // 偏好读写走 `ImportRandomColorStore`、选文件走 SAF（20 MB 限长读）、解析走
        // `IcsImportModel` / `SpreadsheetImportModel`（xlsx 先过 `XlsxSheetDecoder`）、
        // 预览确认后 `replaceActiveProfileContent` 真落盘、模板写缓存再分享。
        "g1.importEntry" -> ImportEntryHost(
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
        "g1.icsImport" -> IcsImportHost(
            repository = wiring.timetable,
            onBack = onBack,
        )
        "g1.spreadsheetImport" -> SpreadsheetImportHost(
            repository = wiring.timetable,
            onBack = onBack,
        )

        // ── P3-G2 导入 · 仓库适配 ────────────────────────────────────
        // 2026-11-01 F24：接上 F08-8b 已交付、但壳里一直没调用的三个真宿主
        // （`WarehouseImportHosts.kt:84/148/213`）。此前三页走诚实空态，于是
        // 「导入课程 → 教务导入」永远显示「暂无可用学校」，而真实现就在隔壁文件里。
        // 直接进 `g2.schoolAdapters` 时先落到选校页，避免宿主内部再 push 造成来回跳。
        "g2.warehouseImport" -> WarehouseImportBranch(
            state = warehouseState,
            prefs = warehousePrefs,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
        "g2.schoolAdapters" -> WarehouseImportBranch(
            state = warehouseState,
            prefs = warehousePrefs,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
        // 详情页要学校 + 适配器两份暂存：交给宿主自己取交接件（[WarehouseImportHandoff]），
        // 拿不到时宿主显示诚实空态；壳里若改画选校页，用户会以为「点详情被弹回了列表」。
        "g2.adapterDetail" -> WarehouseAdapterDetailHost(
            state = warehouseState,
            prefs = warehousePrefs,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
        // 2026-11-01 F28：换成真宿主。地址链路（自定义覆盖 > 适配器 import_url）在宿主里，
        // 没有可用地址时由宿主自己显示诚实空态；抓回来的课表暂只记类型日志（见 F28 认领）。
        "g2.webLogin" -> WarehouseWebLoginHost(
            state = warehouseState,
            prefs = warehousePrefs,
            // 抓回的课程由宿主写回当前课表；不传就只剩日志（F32）。
            repository = wiring.timetable,
            onBack = onBack,
            // 导入落盘成功 → 直接回首页（发布版 pop 到栈底，不留在网页页）。
            onImported = onBackToRoot,
            onOpenPage = onOpenPage,
        )
        // 2026-11-01 F26：这两页原先只传 onBack，所有按钮都是空回调（点了没反应）。
        // 自定义调试：保存/删除真落盘（prefs 键与 Dart 同键），执行诚实报「不可用」。
        "g2.customDebug" -> WarehouseCustomDebugHost(onBack = onBack)
        // 识图导入：剪贴板复制/粘贴、官方提示词弹层、确认导入真写课表（失败回滚并提示）。
        "g2.aiImageImport" -> AiImageCourseImportHost(
            repository = wiring.timetable,
            onBack = onBack,
        )

        // ── P3-G3 导出与传输 ──────────────────────────────────────────
        "g3.dataTransfer" -> DataTransferHost(
            repository = wiring.timetable,
            onBack = onBack,
            onOpenPage = onOpenPage,
            onRequestQrSend = { onOpenPage("g3.qrSend") },
            onRequestQrScan = { onOpenPage("g3.qrScan") },
        )
        "g3.qrSend" -> {
            // 2026-10-29 修：此前这里发的是字符串 `"QingyuTimetable:<课表名>"`——
            // 对方扫码收到的根本不是传输包，解析必然失败。现在载荷由数据备份页打包并暂存到
            // `transferBridge`，本页只负责建会话与展示。
            val payload = transferBridge.outboundPayload ?: ByteArray(0)
            val session = remember(payload) {
                if (payload.isEmpty()) null else QrTransferSendSession.prepare(payload)
            }
            QrTransferSendHost(
                session = session,
                onBack = onBack,
                onStop = onBack,
                // 发送范围标题（「发送当前课表」/「发送全部数据」）跟着传输包一起从数据备份页
                // 带过来；不接就只剩分组标题兜底，两种发送范围看起来一模一样。
                title = transferBridge.outboundTitle,
            )
        }
        "g3.qrScan" -> {
            // 2026-10-29 修：此前把收到的字节直接丢掉（`onImportFullBackup = { onBack() }`），
            // 扫完等于什么都没发生。现在把字节交回数据备份页，走与选文件同一条导入链路。
            QrTransferScanHost(
                onBack = onBack,
                onImportFullBackup = { raw ->
                    transferBridge.inboundBytes = raw
                    onBack()
                },
            )
        }
        // 2026-10-29 F04 接壳：此前是「写死今天-7..今天 + 11 个空回调」——课表下拉永远空
        // （profiles 没喂）、日期点了不动、导出/分享/保存/同步/移除一个都不通。
        // 现在交给 `IcsExportHost`：真档案 + 真事件收集（课程/考试/日程）+ 真分享/SAF/系统日历。
        "g3.icsExport" -> IcsExportHost(wiring = wiring, onBack = onBack)
        // 2026-10-29 F03 接壳：此前 `g3.lanEdit` 喂的是**新建的空模型** + 3 个空回调
        // （开关不启服务、地址永远是「未检测到局域网 IP」、复制点了没反应），
        // `g3.pickupCodes` 的 7 条入口 `onEntryClick` 也是空的。现在两个都由宿主接手：
        // - `LanEditHost`：真 HTTP 服务 + 真 PIN/端口/客户端数 + 前台服务 + 剪贴板 + 「离开后保持开启」；
        // - `PickupCodesHost`：真 `Intent` 多级回退（直达 → 拉起 App → 网页兜底）+ 已安装探测。
        "g3.lanEdit" -> LanEditHost(wiring = wiring, onBack = onBack)
        "g3.pickupCodes" -> PickupCodesHost(
            onBack = onBack,
            hapticsEnabled = wiring.enableHaptics,
        )

        // ── P3-H 诊断与测试夹具 ──────────────────────────────────────
        // 2026-10-29 接真宿主（审核结论见 `docs/plans/2026-10-29-diagnostics-family-audit.md`）：
        // 这一族原先四页全部喂空数据、19 个交互是空 lambda ⇒ 页面在、功能没接。
        // 现在数据来自真文件 / 真采集 / 真仓储，交互落到真实现。
        "h.log" -> DiagnosticsLogHost(onBack = onBack)
        "h.memory" -> MemoryStatsHost(
            onBack = onBack,
            // 内存统计页里的「查看性能报告」：走壳内推页，不要在本页内嵌。
            onOpenPerfReport = { onOpenPage("h.perfReport") },
        )
        "h.perfReport" -> PerfReportHost(onBack = onBack)
        "h.fixture" -> LiveTestingFixtureHost(repository = wiring.timetable, onBack = onBack)

        // ── P3-I 引导与展示 ──────────────────────────────────────────
        // 启动引导（F11，2026-10-29）：三个回调原来全是默认空实现 ——
        // 用户填完开学日期点确认，**一个字节都没写**，下次启动又被拉来重填一遍。
        // 现在：确认 = 学期开始日 + 周数 + 当前周落盘（与 `b.semester` 同一对键）
        // + 写「引导已完成」标记；「去导入」推备份页；「打开旧版」真按包名拉起旧版。
        "i.startup" -> StartupFlowHost(
            repository = wiring.timetable,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
        "i.userGuide" -> {
            // 宿主抽到 pages/guide/UserGuideHost.kt：首启隐私门（FirstRunPrivacyGate）
            // 与「设置里复看指南」共用同一套真数据接线，这里只传参数。
            UserGuideHost(
                wiring = wiring,
                onBack = onBack,
                onOpenPage = onOpenPage,
            )
        }
        // 「全部功能」索引页：39 行每行都要能跳到对应页（F02 接线，2026-10-29）。
        // 目标页由 `shellTimetableMenuPageId`（条目 id → 壳页面 id）翻译，
        // 与顶栏「更多」菜单**共用同一张表**；表里没条目时由
        // `MoreFeaturesNavigationGuardTest` 先红，不靠人记。
        "i.more" -> MoreFeaturesWithSearch(
            onBack = onBack,
            onOpenPage = onOpenPage,
            repository = wiring.timetable,
        )
        // 独立路由进来的搜索浮层（同一组件的另一种入口）：选中 = 关浮层 + 跳页。
        // 两步都要，少一步就是「选了没反应」——这是本批要修的半接点之一。
        "i.moreSearch" -> MoreFeaturesSearchOverlay(
            onDismiss = onBack,
            onSelectFeature = { featureId ->
                val target = shellTimetableMenuPageId(featureId)
                if (target != null) {
                    // 顺序必须是「先关浮层、再推目标页」。壳里的 `onOpenPage` = push 一层、
                    // `onBack` = pop 栈顶：反过来的话 pop 弹掉的是刚 push 的目标页，用户
                    // 又回到浮层（P0：搜索选完回到浮层）。先 pop 掉本浮层再 push 目标页，
                    // 目标页落在原本浮层的那一层上。
                    onBack()
                    onOpenPage(target)
                }
            },
        )
        "i.hyperosShowcase" -> HyperosShowcasePage(onBack = onBack)

        // ── P3-I2 Miuix 展示册 ───────────────────────────────────────
        "i2.showcase" -> MiuixShowcasePage(onBack = onBack)

        // ── P3-J 实时活动与天气 ──────────────────────────────────────
        // 2026-10-29 F01：这三条原先调**状态化重载**，`initialState` 恒为默认值、
        // 三个回调（勿扰权限 / 速览起停）全是空实现 ⇒ 显示设置改了不落盘、退出去就没了。
        // 现在换真宿主：读盘 → 渲染 → 写补丁（两档键组由宿主按 forDuringEnd 选）。
        "j.live" -> LiveDisplayHost(forDuringEnd = false, onBack = onBack)
        "j.displayBefore" -> LiveDisplayHost(forDuringEnd = false, onBack = onBack)
        "j.displayDuring" -> LiveDisplayHost(forDuringEnd = true, onBack = onBack)
        // 2026-10-29 F01：原先 `onPersist` 是默认空实现 ⇒ 提醒时机改了不落盘。
        "j.reminderTiming" -> LiveReminderTimingHost(onBack = onBack)
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
                    // Lead 授权例外科改（行为接线，仅本函数体）：开关值同时写 settings，
                    // 保证备份/导出与运行时一致（否则导出永远读到旧的 false）。
                    wiring.timetable.writeRawSettingsPatch(mapOf("liveHideFromRecents" to hidden))
                    // `apply()` 是异步写，失败拿不到结果：会出现「开关看着关了、实际没关」。
                    // 改成 `commit()` 并检查返回值；失败交回页面（页面会把开关弹回原值），这里补 toast。
                    val prefs = context.getSharedPreferences("native_runtime_prefs", android.content.Context.MODE_PRIVATE)
                    val saved = runCatching {
                        prefs.edit().putBoolean("hide_from_recents", hidden).commit()
                    }.getOrDefault(false)
                    if (saved) {
                        // appTasks 是尽力而为：拿不到任务栈不算落盘失败——下次冷启动会按同一份 prefs 重放。
                        runCatching {
                            val am = context.getSystemService(android.content.Context.ACTIVITY_SERVICE) as? android.app.ActivityManager
                            am?.appTasks?.forEach { it.setExcludeFromRecents(hidden) }
                        }.onFailure { Log.w("ShellPageIndex", "hideFromRecents: 应用到 appTasks 失败", it) }
                    } else {
                        Toast.makeText(
                            context,
                            com.mutx163.qingyu.pages.live.LiveKeepAliveStrings.saveFailed.text,
                            Toast.LENGTH_SHORT,
                        ).show()
                    }
                    saved
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
        "j.weatherCity" -> WeatherCityPickerHost(
            provider = weatherProvider,
            onBack = onBack,
        )

        // ── P3-K 冲突与反馈 ──────────────────────────────────────────
        // 冲突详情：从「空列表」换成**真数据**（以前恒空态）。冲突对由模型层
        // `buildCourseConflictView(snapshot.courses)` 算好；点某行进该课的编辑页，
        // 与 Dart `course_conflict_screen.dart:_openCourseEditor` 同口径。
        "k.conflict" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            CourseConflictPage(
                view = buildCourseConflictView(snapshot.courses),
                onBack = onBack,
                onOpenCourse = { courseId ->
                    val target = snapshot.courses.firstOrNull { it.id == courseId }
                    wiring.pendingEditCourse = target
                    wiring.pendingAddCourseSeed = null
                    // 冲突页这一路同样不带来源周次，清掉上一条路径可能留下的意图。
                    wiring.pendingEditWeek = null
                    // 带**同名整组**进编辑页（Dart `course_conflict_screen.dart:104-125`：
                    // `AddCourseScreen(courseGroup: group, initialCourse: course)`）。
                    // 只带单课会让保存走整组替换时把同名其它课次一起清掉（P0）。
                    val siblings = target?.let { picked ->
                        snapshot.courses.filter { it.name == picked.name }
                    }
                    wiring.pendingEditGroup = if (target == null || siblings.isNullOrEmpty()) {
                        null
                    } else {
                        com.mutx163.qingyu.pages.course.CourseGroup(
                            name = target.name,
                            courses = siblings,
                        )
                    }
                    onOpenPage("d1.addCourse")
                },
            )
        }
        // 问题反馈页：点渠道行 / 点右侧复制按钮**真的做事**（F02，2026-10-29）。
        // 原先只传 onBack，两个回调是 FeedbackPage 的默认空实现 ⇒ 五行渠道全死。
        // 动作拆在 `runFeedbackOpenPlan`（main，纯 Kotlin，顺序有单测）里，
        // 这里只提供三件宿主能力：ACTION_VIEW 拉起、写剪贴板、Toast 回执。
        "k.feedback" -> {
            val context = LocalContext.current
            FeedbackPage(
                onBack = onBack,
                onOpenChannel = { channel ->
                    runFeedbackOpenPlan(
                        plan = feedbackOpenPlanFor(channel),
                        launch = { url -> FeedbackChannelHost.open(context, url) },
                        copy = { value -> FeedbackChannelHost.copy(context, value) },
                        notify = { message -> FeedbackChannelHost.toast(context, message) },
                    )
                },
                onCopyChannel = { channel ->
                    FeedbackChannelHost.copy(context, channel.copyValue)
                    FeedbackChannelHost.toast(context, channel.copyToast)
                },
            )
        }

        // 目录里登记了、分派里没接：**宁可明确报错，也不要静默显示空白**
        else -> ShellMissingPage(pageId = pageId, onBack = onBack)
    }
    }
}

/** 设置族 24 屏的统一入口：spec 由各页的模型层给，这里只负责壳的返回与「箭头行推页」。 */
@Composable
private fun SettingsScreen(
    spec: com.mutx163.qingyu.pages.settings.SettingsPageSpec,
    onBack: () -> Unit,
) {
    val openPage = LocalShellOpenPage.current
    SettingsPageScreen(
        spec = spec,
        onBack = onBack,
        // 这些页还没接真模型：开关/滑杆等写回仍是 no-op；但「箭头行」必须能推页，
        // 否则设置主页与子页之间的导航会整块断掉（actionTarget 就是 Dart 路由串）。
        onAction = { _, target, _ -> shellPageIdForRoute(target)?.let(openPage) },
    )
}

/**
 * 课程卡片 / 课表页面两页顶部那块预览：**真组件预览**（2026-11-03 用户口径「真组件挖洞」，
 * 2026-11-04 用户口径「完整显示星期栏 + 上/下不要圆角」）。
 *
 * 旧的自绘缩略图（星期栏 + Canvas 网格 + 色块）已被用户否掉，必须露出真实组件。
 * 2026-11-08 用户口径（实报「进页看不到星期栏、第一行是第 5 节」）：预览要像首页那样
 * **星期栏钉在窗口顶部、只有网格上下滑**，而不是把整页当一条长纸带滚（那样一滑就
 * 把星期栏顶出窗口，第一行变成随手滑到的某一节）。
 *
 * 所以走 [QingyuPreviewCutout] 的**按框排版**分支（`fitToBox = true`）：窗口多大，真组件
 * 就排多大，星期栏占顶上 40dp、网格自己滚动（滚动状态在 `TimetableWeekPage` 里）。
 * `isolateGestures = false`：手势要放给网格（框内上下滑就是这个手势），而「预览不可点」
 * 改由页面自己保证——预览分支里课卡 / 空白格 / 浮钮的回调本来就是空实现，星期栏那两处
 * 点击也按 `previewMode` 就地作废。
 * 节高**仍按首页算**：壳把「首页网格可用高」当基准传下去（自动充满档），窗口本身只露
 * 4 行左右，但一行的高度和首页逐像素相同。
 *
 * 数据：课程随仓储快照订阅实时变；显示偏好取**宿主当前草稿**——两页宿主把 `model`
 * 顺着 `preview(model)` 传进来（唯一取用口径 `settingsPreviewDraft`），改开关 / 拖滑杆
 * 当场跟着变，不必退出重进。旧实现在这里自己 `wiring.settingsModel.load()` 读一次盘，
 * 写盘又走 250ms 防抖，预览就永远停在进页那一刻（2026-11-03 用户实报）。
 */
@Composable
private fun SettingsTimetablePreviewSlot(wiring: ShellWiring, settingsModel: TimetableSettingsModel) {
    val configuration = LocalConfiguration.current
    // 星期栏高：previewMode 下顶栏只剩星期栏，取其固定高度 40dp（`WeekdayHeaderMetrics.HEIGHT_DP`）。
    val weekbarHeightDp = WeekdayHeaderMetrics.HEIGHT_DP
    // 首页网格的可用高 = 整屏 − 状态栏 − 首页顶栏 − 星期栏。
    // 自动充满档的节高在首页由「网格盒子的实际高 / 节数」算（`WeekPageContent` 拿的是
    // 星期栏以下的盒子），所以这里必须把首页那两条栏也扣掉。只减星期栏会让预览每行
    // 比首页高一档：800dp 屏 / 12 节时约高 8%（含状态栏约 12%），正好落在用户拿来
    // 对照密度的地方（2026-11-07 审读）。固定节高档不看这个值，只影响自动充满档。
    val statusBarTopDp = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val homeGridHeightDp = (
        configuration.screenHeightDp.dp - statusBarTopDp -
            TimetableTopBarMetrics.HEIGHT.dp - weekbarHeightDp.dp
        ).coerceAtLeast(0.dp)
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        QingyuPreviewCutout(
            // 按框排版：窗口多大内容就多大（scale 恒 1，不缩放）。
            contentWidth = maxWidth,
            contentHeight = maxHeight,
            // 方角（对齐 Flutter 已发布版预览无圆角）。
            cornerRadius = 0.dp,
            // 内容按窗口尺寸排版、不提供本组件自带的长条滚动。
            fitToBox = true,
            // 手势放给内容（框内上下滑 = 滚网格）；「不可点」由预览模式下的空回调保证。
            isolateGestures = false,
        ) {
            TimetableHost(
                repository = wiring.timetable,
                // 预览不可操作：所有入口给空实现（星期栏那两处点击在页面里按 previewMode 作废）。
                onOpenAddCourse = { _, _ -> },
                onOpenCourse = {},
                settingsModel = settingsModel,
                // 天气行与首页同一份数据源（壳里的设备级 provider）：漏传就等于
                // 「首页课卡有天气行、预览没有」，卡片高度与折行会跟着不同。
                weatherProvider = wiring.weather,
                // 预览不接截屏监听：真首页那一份已经接上了，再来一份等于截一次屏
                // 弹两次提示（Dart `_isPreview` 守卫，timetable_screen.dart:913-917）。
                screenshotSharePromptEnabled = false,
                // 预览模式：不画状态栏留白与顶栏，星期栏当首行、钉在窗口顶上。
                previewMode = true,
                // 节高基准 = 首页网格可用高：窗口只有 4 行高，但一行的高度与首页一致。
                previewSectionBasisDp = homeGridHeightDp,
            )
        }
    }
}

/**
 * 「全部功能」页 + 它自己的搜索浮层。
 *
 * 搜索浮层是同一页的组件（不是独立路由），所以在这里持有它的开关状态：
 * 点搜索胶囊 → 浮层盖上来；浮层里选一项 → 关掉浮层，**并且跳到那一页**。
 *
 * ## 两个入口，一个动作（F02 接线，2026-10-29）
 *
 * - 页内每行 `onOpenFeature`：条目 id → `shellTimetableMenuPageId` → `onOpenPage`；
 * - 浮层 `onSelectFeature`：同上，只是先关浮层再跳（浮层不关会盖住目标页）。
 *
 * 原先两处都是空 lambda / 只关浮层，于是「全部功能」39 行**全部点了没反应**——
 * 而这一页存在的意义就是「某个入口被我删了，来这儿找回来」。
 *
 * ## 副标题是「当前值」，必须读真仓储
 *
 * 条目副标题在 Dart 侧是「当前课表名 / 当前作息名」（`more_features_screen.dart:308-311`
 * 的 `activeProfileName` / `activeTimeSchemeName`），不是描述。所以这里订阅课表仓储：
 * 切了档案、改了作息名再进来，副标题跟着变——静态字符串会当场变成假信息。
 */
@Composable
private fun MoreFeaturesWithSearch(
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    repository: com.mutx163.qingyu.app.TimetableRepository,
) {
    var searchOpen by remember { mutableStateOf(false) }
    val snapshot = remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot.value = it }
        onDispose { subscription.close() }
    }
    val current = snapshot.value
    val activeProfileName = current.profiles.firstOrNull { it.id == current.activeProfileId }?.name
    val activeTimeSchemeName = current.timeSchemes.firstOrNull { it.id == current.activeTimeSchemeId }?.name
    val groups = MoreFeaturesModel.buildDefaultFeatureGroups(
        activeProfileName = activeProfileName,
        activeTimeSchemeName = activeTimeSchemeName,
    )
    val openFeature: (String) -> Unit = { featureId ->
        shellTimetableMenuPageId(featureId)?.let(onOpenPage)
    }

    MoreFeaturesPage(
        activeProfileName = activeProfileName,
        activeTimeSchemeName = activeTimeSchemeName,
        onBack = onBack,
        onOpenSearch = { searchOpen = true },
        onOpenFeature = openFeature,
    )
    if (searchOpen) {
        MoreFeaturesSearchOverlay(
            groups = groups,
            onDismiss = { searchOpen = false },
            onSelectFeature = { featureId ->
                searchOpen = false
                openFeature(featureId)
            },
        )
    }
}

/**
 * 启动引导的**真宿主**（F11，2026-10-29）。
 *
 * ## 原来坏在哪
 *
 * `StartupFlowPage` 的三个回调都是默认空实现，壳只传了 `onBack`：
 * - 「打开旧版去备份」按钮：点了没反应（Dart 是 `PackageManager` 拉起旧版包名）；
 * - 「我已完成备份，去导入」：点了没反应（Dart 关掉引导后走备份导入流程）；
 * - 「确认」：**开学日期与周数根本没落盘**，用户白填一遍，下次启动又重新问。
 *
 * ## 三条动作各自的落点
 *
 * | 动作 | 落点 | Dart 出处 |
 * |---|---|---|
 * | 确认（开学日期 + 周数） | `repository.updateSettings(...)`（与 `b.semester` 同一对键）+ `setCurrentWeek` + 写 `has_completed_onboarding` | `main.dart:1486` |
 * | 去导入 | 推壳里的 `f.backupList`（备份列表） | `main.dart:1166-1174` |
 * | 打开旧版 | 按 `STARTUP_LEGACY_PACKAGE_CANDIDATES` 顺序找**装了的**那个并拉起；找不到给 ARB 实话 | `app_migration_service.dart:13-35` |
 *
 * ## 诚实清单（没做的，不假装）
 *
 * - **不写** `has_handled_package_migration`：Dart 只在「迁移引导被处理过」时写它，
 *   且「去导入」那条要等**导入真的成功**才写（`main.dart:1168-1174`）——那属于备份导入
 *   流程的判断，本页看不到导入结果，不替它写。
 * - **不写** `has_seen_user_guide` / `accepted_privacy_policy`：那是用户指南页（`i.userGuide`）
 *   的职责（`main.dart:1474-1487`）。
 * - 旧版**是否装着**读的是系统包管理器；用户没装旧版时如实提示「未能打开旧版应用」，
 *   不静默失败、也不假装打开过。
 */
@Composable
private fun StartupFlowHost(
    repository: com.mutx163.qingyu.app.TimetableRepository,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val context = LocalContext.current
    val snapshot = remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot.value = it }
        onDispose { subscription.close() }
    }
    // 与 `ShellWiring` 里的 `keyValueStore` 同一个 SharedPreferences 文件（按名字缓存，进程内一份）。
    val preferences = remember(context) { StartupFlowPreferences(PrefsKeyValueStore(context)) }
    val current = snapshot.value

    StartupFlowPage(
        // 初始值取真仓储：用户在 `b.semester` 改过开学日期/周数，这里必须看到改后的值，
        // 否则「回显」当场就是假的（同一条数据两个入口显示两套值）。
        initialState = StartupFlowState(
            semesterStartDate = TimetableSettings.formatSemesterStartDateText(
                current.settings.semesterStartDate,
            ),
            totalWeeks = current.settings.semesterWeekCount,
            currentWeek = current.currentWeek,
        ),
        onBack = onBack,
        onOpenOldApp = {
            if (!openLegacyApp(context, STARTUP_LEGACY_PACKAGE_CANDIDATES)) {
                Toast.makeText(context, GuideStrings.openOldAppFailed.text, Toast.LENGTH_LONG).show()
            }
        },
        onGoImportBackup = { onOpenPage("f.backupList") },
        onFinishStartupFlow = { date, weeks ->
            val plan = planStartupSemesterWrite(date, weeks)
            if (plan == null) {
                // 非法输入不写半截数据：页面上的确认按钮本身有校验，这里是兜底。
                Toast.makeText(context, GuideStrings.saveFailed.text, Toast.LENGTH_SHORT).show()
            } else {
                val saved = runCatching {
                    // 与学期设置页同一个写入入口（没有第二条通道）。
                    val settings = repository.snapshot.settings
                    repository.updateSettings(
                        settings.copy(
                            semesterStartDate = plan.semesterStartDate,
                            semesterWeekCount = plan.semesterWeekCount,
                        ),
                    )
                    repository.setCurrentWeek(plan.currentWeek)
                    // 落盘 + 立刻回读；只有读回来真的是 true，才算引导走完。
                    preferences.markOnboardingCompletedAndVerify()
                }.getOrDefault(false)
                if (!saved) {
                    // 写不进去就**不许**显示成功：否则用户下次启动又被拉来重填，
                    // 而且这次他还以为自己已经设好了。
                    Toast.makeText(context, GuideStrings.saveFailed.text, Toast.LENGTH_SHORT).show()
                } else {
                    onBack()
                }
            }
        },
    )
}

/**
 * 按顺序找**装了**的旧版并拉起（Dart `AppMigrationService.openPackage` 的等价实现）。
 *
 * 为什么复制一份而不是调 `MainActivity` 的私有方法：那边是 Flutter 的 MethodChannel 处理函数，
 * 与 Compose 宿主不是同一条通道；`GuidePermissionProbe` 也是同样的处理（复制必要实现，不改 MainActivity）。
 * `getLaunchIntentForPackage` 对没装的包直接返回 null，所以「找装了哪个」与「能不能开」
 * 是同一次判断，不需要先 `getPackageInfo`。
 */
private fun openLegacyApp(context: Context, candidates: List<String>): Boolean {
    val manager = context.packageManager
    for (packageName in candidates) {
        val intent = manager.getLaunchIntentForPackage(packageName) ?: continue
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (runCatching { context.startActivity(intent) }.isSuccess) return true
    }
    return false
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
// 仓库适配与导入（g2.schoolAdapters / g2.adapterDetail / g2.webLogin / g2.warehouseImport）
// ────────────────────────────────────────────────────────────────────────

/**
 * 2026-11-01 F28：`g2.webLogin` 已接 `WarehouseWebLoginHost`（真 WebView + 地址链路），
 * `g2.schoolAdapters` / `g2.adapterDetail` 走选校/适配器宿主。三页都不再喂示例数据。
 */

/**
 * 仓库导入的两条入口（`g2.warehouseImport` / `g2.schoolAdapters`）共用同一段判断：
 *
 * - 还没选学校 ⇒ 选校页（数据源 `index/root_index.yaml`，真网络）；
 * - 已选学校 ⇒ 适配器列表。
 *
 * 为什么抽成函数而不是写成 `"a", "b" -> {...}`：`ShellPageDispatchCoverageTest` 的正则
 * 只认「一个分支一个 id」，合并写会让那两条被判成「目录里有、分派里没有」而红。
 */
@Composable
private fun WarehouseImportBranch(
    state: WarehouseShellState,
    prefs: WarehouseImportPrefs,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    // 先看**交接件**、再判本条目的 `state`：
    // 上面两个 id 共用本函数，而壳给**每个路由条目独立**的 WarehouseShellState。
    // 从选校页推过来时新条目 state.school 必为 null，只看 state 就会把选校页再画一遍
    // ——用户得把同一所学校点两遍（2026-11-05 用户实报）。
    // 判断锁在条目首次组合：交接件是一次性的，里面的适配器宿主 take() 之后 peek 就空了，
    // 而那之后 state.school 才由宿主补写；按实时值判会闪回一次选校页。
    val selectedSchool = remember(state) {
        state.school ?: WarehouseImportHandoff.peek()?.school
    }
    if (selectedSchool == null) {
        WarehouseImportPickerHost(
            state = state,
            prefs = prefs,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
    } else {
        WarehouseSchoolAdaptersHost(
            state = state,
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
    }
}

/** `mm:ss` → 起点算出来的 `HH:mm`。日视图与课程表单共用的一小段换算。 */
private fun clockText(minutesOfDay: Int): String {
    val normalized = ((minutesOfDay % (24 * 60)) + 24 * 60) % (24 * 60)
    val hour = normalized / 60
    val minute = normalized % 60
    return "${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"
}

// 2026-10-29：`shellSampleTaskViewState()` 已删除。
//
// 它是「任务清单空态示例」，被底栏 `DockSlot.TASK` 当数据源用了很久 —— 于是从底栏进任务 tab
// 永远空列表、任何点击都没反应，而路由 `d2.taskList` 早就是真数据（同页两个入口两套命运）。
// 留着这个函数等于给下一次「先接个假的凑合」留下抓手，故直接删掉；真数据走
// `app/TaskHost.kt` 的 `TaskListHost`。守卫见 `TaskWiringGuardTest`。

/**
 * 问题反馈页的**宿主三件套**：拉起外部应用 / 写剪贴板 / Toast 回执。
 *
 * ## 为什么不放在页面里
 *
 * `FeedbackPage`（composeP1）只负责画五行渠道并回调，`runFeedbackOpenPlan`
 * （main，纯 Kotlin）负责「按什么顺序做」。真正碰 Android 的三件事只有宿主能做，
 * 而且必须**在这一层**：Compose 页面不 import `android.content.*`，
 * 模型层进 JVM 单测 classpath 也不能 import。
 *
 * ## 与 Dart 的口径
 *
 * 对齐 `MainActivity` 的 `launch_url` 通道（`ACTION_VIEW` + `FLAG_ACTIVITY_NEW_TASK`）：
 * 不走 `url_launcher` 是历史结论——在 MIUI/OEM ROM 上 `url_launcher` 会有「返回 true
 * 但没跳走」的假成功，而直连 Intent 失败会抛 `ActivityNotFoundException`，判得准。
 *
 * 白名单在 [FeedbackLaunchRules]（main，可单测）：不在白名单的 scheme 一律当作
 * **打不开**，交给模型层回落复制，绝不放行 `javascript:` / `file:` / `content:`。
 */
private object FeedbackChannelHost {

    private const val TAG = "FeedbackChannelHost"

    /** 拉起一条候选 URL；返回 true 只代表系统接了这次 Intent。 */
    fun open(context: Context, url: String): Boolean {
        if (!FeedbackLaunchRules.isAllowed(url)) {
            Log.w(TAG, "open: 白名单外的 scheme，已拒绝：$url")
            return false
        }
        val uri = runCatching { Uri.parse(url) }.getOrNull() ?: return false
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (error: ActivityNotFoundException) {
            Log.w(TAG, "open: 没有应用能打开 $url", error)
            false
        } catch (error: SecurityException) {
            Log.w(TAG, "open: 权限被拒 $url", error)
            false
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "open: Intent 非法 $url", error)
            false
        } catch (error: Exception) {
            Log.e(TAG, "open: 未知失败 $url", error)
            false
        }
    }

    /** 写系统剪贴板（Android 10+ 只在应用在前台时可见，这正是需要的场景）。 */
    fun copy(context: Context, value: String) {
        if (value.isEmpty()) return
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (manager == null) {
            Log.w(TAG, "copy: 拿不到 ClipboardManager")
            return
        }
        // 剪贴板条目标签用 ASCII：这是系统剪贴板里的「来源说明」，不是界面文案，
        // 走 ARB 反而要为一个不渲染的字符串加键；也避免撞渲染层的 CJK 字面量门禁。
        runCatching { manager.setPrimaryClip(ClipData.newPlainText("qingyu-feedback", value)) }
            .onFailure { Log.w(TAG, "copy: 写剪贴板失败", it) }
    }

    /** 短 Toast 回执（只有一句话，不弹对话框——反馈页不宜打断用户）。 */
    fun toast(context: Context, message: String) {
        if (message.isEmpty()) return
        runCatching { Toast.makeText(context, message, Toast.LENGTH_SHORT).show() }
    }
}
