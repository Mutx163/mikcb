package com.mutx163.qingyu.pages

import android.app.Activity
import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.app.CourseActionDispatcher
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.ScheduleEditDispatcher
import com.mutx163.qingyu.app.TimetableHomeViewMode
import com.mutx163.qingyu.app.TimetableHost
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSaveDispatcher
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.calendar.HolidayPreferences
import com.mutx163.qingyu.calendar.HolidayProvider
import com.mutx163.qingyu.calendar.HolidayService
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.SystemAlarmHelper
import com.mutx163.qingyu.pages.course.AddCourseSavePayload
import com.mutx163.qingyu.core.ClassAlarmEvent
import com.mutx163.qingyu.core.ClassAlarmPlanLogic
import com.mutx163.qingyu.pages.course.CourseActionEvent
import com.mutx163.qingyu.pages.course.CourseActionSheet
import com.mutx163.qingyu.pages.course.CourseActionSheetModel
import com.mutx163.qingyu.pages.course.CourseDeleteScope
import com.mutx163.qingyu.pages.course.CourseGroup
import com.mutx163.qingyu.pages.course.CourseSheetWeatherInfo
import com.mutx163.qingyu.pages.course.CourseSheetWeatherPrefs
import com.mutx163.qingyu.pages.course.CourseSuspendScope
import com.mutx163.qingyu.pages.import.CourseAutoRefreshStore
import com.mutx163.qingyu.pages.schedule.ScheduleItemBridge
import com.mutx163.qingyu.pages.schedule.ScheduleItemData
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModule
import com.mutx163.qingyu.pages.shell.HomeMenuNavModel
import com.mutx163.qingyu.pages.shell.HomeNavIcons
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableStrings
import com.mutx163.qingyu.pages.timetable.WeekAgendaKind
import com.mutx163.qingyu.platform.AndroidWeatherLocationSource
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.weather.JdkWeatherHttp
import com.mutx163.qingyu.weather.WeatherPreferences
import com.mutx163.qingyu.weather.WeatherProvider
import com.mutx163.qingyu.weather.WeatherService
import java.time.LocalDate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 壳的**接线层**（Phase 3.5 · L5，Lead 专属写作用域）。
 *
 * ## 它解决什么
 *
 * Phase 3 把 78 屏页面搬完了，但页面是「纯函数 + 数据入口」形态：状态从哪来、
 * 点了写到哪，都留给宿主。壳以前的做法是**喂演示数据 + 空回调**（137 处 `{}`），
 * 所以「点了没反应」。这一层把真仓储接上去。
 *
 * ## 为什么放在 composeUi 而不是 `composeP1/.../app/`
 *
 * 那里放的是**可复用的宿主层**（`TimetableHost`，将来正式包也用）。
 * 这里放的是**壳专属的装配**：壳有自己的包名、自己的 prefs、自己的导航语义
 * （底部四个槽位 + 页面层），这些东西正式包一样都不要。
 *
 * ## 数据落点
 *
 * 壳的包名带 `.ui`，所以它读写的是**自己的** `FlutterSharedPreferences`——
 * 与正式版（Flutter）的数据互不可见，这是 Android 的包隔离，不是 bug。
 * 好处是：格式是**同一套冻结格式**，将来正式包换成 Compose 时，
 * 把这一层原样搬过去就能直接读用户已有数据。
 *
 * ## 已知未接线（诚实清单）
 *
 * 1. **课程详情入口**：Dart 点课程弹的是**操作弹层**（`course_action_sheet.dart`，6 个动作：
 *    编辑 / 调课 / 停课复课 / 删除 / 加作业 / 单节课提醒）。Kotlin 侧其中 4 个动作**全仓 0 命中**，
 *    且弹层要落在 `pages/course/`。补一个只剩「编辑 + 删除」的残弹层是负价值，
 *    所以本轮**不补**——这两个动作现在都能用（点课程进编辑页，编辑页里能删）。
 *    建议单列一批「课程操作弹层」。
 * 2. **档案管理 / 切档案**：只做到「能跳过去」，页内动作尚未接全。
 * 3. **显示偏好**（隐藏周末 / 时间列宽 / 节次行高 / 长按空档加课）来自宿主默认值，
 *    不是从用户存档读的——等设置族完整模型到位后改（见 `TimetableHostDisplayPrefs` KDoc）。
 */
class ShellWiring(context: Context) {

    /** 应用上下文：宿主需要它读系统侧状态（例如周报开关、通知权限）。 */
    val context: Context = context.applicationContext

    /** 壳自己的存储（`FlutterSharedPreferences`，冻结格式）。两者共用同一个实例。 */
    private val keyValueStore: KeyValueStore = PrefsKeyValueStore(context)

    private val timetableStore: TimetableStore = TimetableStore(keyValueStore)

    /** 课表仓储：壳里所有课表相关状态都从它来。 */
    val timetable: TimetableRepository = TimetableRepository(timetableStore)

    /**
     * 设置模型：**共用 `SettingsPageState` 的 4 页**（通用 / 外观 / 主题管理 / 课程卡片）的读写入口。
     *
     * 与 [timetable] 共用同一个 [TimetableStore]，两者写的键**不重叠**
     * （仓储只写 `timetable_settings` 的 core 4 键，本模型写另外那批显示键），
     * 且都走 `saveSettingsPatch` 的读-合并-写，所以谁都不会覆盖谁。
     */
    val settingsModel: TimetableSettingsModelStore = TimetableSettingsModelStore(timetableStore)

    /**
     * 读 `timetable_settings` 的**原始 JSON**（组合函数在 `settingsRevision` 变化时调一次）。
     *
     * 「这节课闹钟」的两个提醒键（`classAlarmLeadMinutes` / `classAlarmSkipUi`）属
     * 「提醒」设置族——设置完整模型（P35-settings-model）还没认领它们，这里按原始
     * 键只读，等设置族接线后迁回模型。
     */
    fun loadRawSettingsJson(): Map<String, Any?> = timetableStore.loadSettingsJson()

    /**
     * 设置变更序号：**页面内容重读设置模型**的重组信号。
     *
     * ## 它解决什么（2026-11-02 用户实报）
     *
     * 「外观编辑页改完材质 / 壁纸，返回首页，材质还是旧的；左右滑一下才变成新样式」。
     *
     * 设置存储没有变更通道（只有 `load` / `save`），而首页各视图（周 / 日 / 月）是在
     * **组合期裸调** `settingsModel.load()` 读盘的普通函数调用——它既不是可观察状态，
     * 也不会让 Compose 建立依赖。以前靠「`onBack` / `onOpenPage` 这些不稳定 lambda
     * 在返回首页时补一次重读」，但 Compose 的强跳过（Kotlin 2.x 默认）会把捕获值相等的
     * lambda 记住，整棵页面内容被跳过 ⇒ 返回那一刻没有重组，`load()` 也就没有再跑。
     * 用户随后滑动翻页会改仓储状态、逼出一次重组，新材质才「突然」出现。
     *
     * ## 用法（唯一正确姿势）
     *
     * 需要读整份设置的页面内容：
     * ```kotlin
     * val revision = wiring.settingsRevision            // 订阅：自增时本组合重组
     * val model = remember(revision) { wiring.settingsModel.load() }  // 只在这一刻读盘
     * ```
     *
     * 写者：壳在**回到主屏**时自增一次（`PagesShellActivity` 的 `LaunchedEffect(atRoot)`，
     * 与主题 / 底栏的 `onReloadSettings` 同一时刻）。只增不碰盘，成本是一次重组；
     * 不要在每帧或每次滚动里自增。
     */
    var settingsRevision: Int by mutableIntStateOf(0)

    /**
     * 「课表自动更新」的配置与台账（通用设置页那一整块）。
     *
     * 为什么**不**塞进 [settingsModel]：Dart 侧明确把它另存一个 prefs 键
     * （`lib/services/course_auto_refresh_store.dart:9-18`：台账必须留本机，
     * 不能跟着课表备份/同步跑到别的设备上去）。键名与值类型逐字对齐 Dart。
     */
    val autoRefresh: CourseAutoRefreshStore = CourseAutoRefreshStore(keyValueStore)

    /** 只读一次盘：下面两个运行期偏好初值来自同一份设置，别为了两行解析两遍 JSON。 */
    private val initialSettings: TimetableSettingsModel = settingsModel.load()

    /**
     * 页面转场速度（Dart `pageTransitionSpeed`，0.5~2.5，1.0 = 原速）。
     *
     * 设为**可观察状态**：设置页拖滑杆时经 `SettingsHost.onTransitionSpeedChanged`
     * 当场写这里，`NavDisplay` 读到新值后按倍率缩放转场时长 —— 与 Dart
     * `HyperosMotionPlatform.applyUserTransitionSpeed` 的「不重启也立刻变快变慢」一致。
     */
    var pageTransitionSpeed: Double by mutableStateOf(initialSettings.pageTransitionSpeed)

    /**
     * 应用内震动总开关（Dart `enableHaptics`）。
     *
     * 壳在 `PagesShell` 根部按它决定要不要把 [androidx.compose.ui.hapticfeedback.HapticFeedback]
     * 换成空实现 —— 这样 miuix 组件自带的触感（滚轮、滚到尽头）也跟着这个开关走。
     */
    var enableHaptics: Boolean by mutableStateOf(initialSettings.enableHaptics)

    // ── 首页课表的「周 / 日」展开态（2026-11-02）────────────────────────────
    //
    // 原版 Flutter 里，日视图**不是一页路由**，而是首页内部的一种展开态：
    // 点星期栏某一天 / 底栏「日」，选中那天从网格列位长到整屏，底栏始终保留
    // （`day_view_transition_controller.dart` 的 `toggle`）。迁移到 Compose 后曾把它做成
    // 独立页面 `c3.day`：周→日是「推一页」、底栏切换是「替换栈底」，miuix 按 pop 播
    // 「从左侧滑入」——与原版差得很远（2026-11-02 用户实报）。
    //
    // 现在周 / 日共用同一个首页宿主（`c1.week`），切换只改下面这三个状态，
    // 不碰返回栈 ⇒ 不存在路由转场，展开动画由页面自己按 `homeViewExpandWindow` 播。

    /** 首页课表当前停在周视图还是日视图（Dart `timetableHomeViewMode`）。 */
    var homeViewMode: TimetableHomeViewMode by mutableStateOf(initialSettings.timetableHomeViewMode)

    /** 日视图「正看着」的那一周（底栏「日」进入时取当前浏览周）。 */
    var homeSelectedWeek: Int by mutableIntStateOf(
        timetable.snapshot.currentWeek.coerceAtLeast(1),
    )

    /** 日视图「正看着」的那一天（1..7；Dart `timetableLastViewedDayOfWeek`）。 */
    var homeSelectedDayOfWeek: Int by mutableIntStateOf(
        initialSettings.timetableLastViewedDayOfWeek.coerceIn(1, 7),
    )

    /**
     * 下一次宿主挂载时，首页展开动画该从哪一档起步。
     *
     * 只在「底栏从别的页面切回课表」这种**宿主会被重建**的路径上需要：
     * 路由替换是瞬时切换（`PagesShellActivity.instantOnReplace`），新宿主第一帧
     * 如果直接按 `homeViewMode` 落定，就会跳过展开/收起动画。页面在常驻时切换
     * 不读这个值（`dayMode` 变化本身就会触发动画），由 `PagesShellActivity` 在换路由前
     * 经 [requestHomeViewMotion] 显式登记。
     *
     * `consumeHomeViewMotionSeed()` 读一次就清：冷启动不应该播动画。
     */
    private var homeViewMotionSeed: TimetableHomeViewMode? = null

    /** 设置落盘串行、离屏（整份档案 JSON 的重编码很贵，不能堵主线程）。 */
    private val homeViewPersistScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val homeViewPersistMutex = Mutex()

    /**
     * 切周 / 日课表（Dart `timetableHomeViewMode` 的写入口）。
     *
     * 只在真的换档时改状态：重复点当前档不写盘、也不触发动画（Dart
     * `timetable_dock_actions.dart` 的「重复点日/周 Tab 无动作」同口径）。
     */
    fun switchHomeViewMode(mode: TimetableHomeViewMode) {
        if (mode == homeViewMode) return
        homeViewMode = mode
        homeViewPersistScope.launch {
            homeViewPersistMutex.withLock {
                runCatching { settingsModel.saveHomeViewMode(mode) }
            }
        }
    }

    /**
     * 标记「这次周/日切换会让首页宿主**重建**」，让新宿主首帧知道从哪一档起步。
     *
     * 只在底栏从**别的页面**切回课表时调用（那一路径必须换栈底路由）；页内切换
     * 不需要它 —— 宿主常驻，`dayMode` 变化本身就会触发动画。
     */
    fun requestHomeViewMotion(from: TimetableHomeViewMode) {
        homeViewMotionSeed = from
    }

    /** 记下日视图正在看的那一天/周（翻页停稳、点某天、底栏进入都走这里）。 */
    fun setHomeSelection(week: Int, dayOfWeek: Int) {
        val normalizedWeek = week.coerceAtLeast(1)
        val normalizedDay = dayOfWeek.coerceIn(1, 7)
        homeSelectedWeek = normalizedWeek
        if (normalizedDay == homeSelectedDayOfWeek) return
        homeSelectedDayOfWeek = normalizedDay
        homeViewPersistScope.launch {
            homeViewPersistMutex.withLock {
                runCatching { settingsModel.saveLastViewedDayOfWeek(normalizedDay) }
            }
        }
    }

    /** 宿主挂载时取一次「展开动画从哪档起步」，读完即清（理由见字段注释）。 */
    fun consumeHomeViewMotionSeed(): TimetableHomeViewMode? {
        val seed = homeViewMotionSeed
        homeViewMotionSeed = null
        return seed
    }

    /**
     * 节假日数据（设备级状态：年度缓存 / 自定义假期 / 更新日志），2026-10-29 新增。
     *
     * 三处共用同一份实例，这就是「一处改、多处跟着变」的前提：
     * 1. 设置页的「节假日标记」两页（`b.holiday` / `b.holidayAdvanced`）；
     * 2. 月视图的节假日底色与补班标记（`MonthViewHost(holidayData = …)`，下一步接）；
     * 3. 桌面小组件 / 超级岛（`HolidayData.holidayDateKeysForSnapshot()`）。
     *
     * 读的是**壳自己**的 `FlutterSharedPreferences`（与正式版同一套冻结格式），
     * 键 `holiday_data_<year>`（年度数据）与 `custom_holidays`（用户自建），与
     * `lib/services/holiday_service.dart:36-37` 逐字一致。
     *
     * `builtinJson` 注入的是 APK 内兜底资产 `assets/holidays/<year>.json`；
     * 远端两个端点都失败且本地无缓存时用它（Dart `_loadBuiltin`，`:245-253`）。
     */
    val holiday: HolidayProvider by lazy {
        HolidayProvider(
            service = HolidayService(),
            preferences = HolidayPreferences(keyValueStore),
            builtinJson = ::builtinHolidayJson,
        )
    }

    /**
     * 读内置节假日资产；该年没有文件（或读失败）返回 null。
     *
     * 放在这里而不是 `calendar/`：`calendar` 是**纯 Kotlin 模型目录**，一旦 import
     * `android.content.res.AssetManager`，`scripts/test-kotlin-module.ps1` 会把整个目录
     * 跳过，全队 L0 都会少掉节假日那一层（见脚本里 `sharedModelDirs` 的说明）。
     */
    private fun builtinHolidayJson(year: Int): String? = runCatching {
        context.assets.open("holidays/$year.json").bufferedReader().use { it.readText() }
    }.getOrNull()

    /**
     * 天气（设备级状态：开关 / 城市 / 预报缓存），2026-10-29 从 `ShellPageIndex` 的
     * `remember` 挪到这里。
     *
     * ## 为什么必须挪
     *
     * 课表的**两个入口**（底部坞 `DockSlot.TIMETABLE` 与页面层 `c1.week`）都要弹课程操作层，
     * 弹层里有「天气」行。provider 原先只在 `ShellPageIndex` 的 `remember` 里造一份，
     * 底部坞那条路根本拿不到 ⇒ 同一次点击从两个入口进去，一个有天气行、一个没有。
     *
     * 挪进 `ShellWiring` 后全 App 只有**一份**（`rememberShellWiring` 保证），
     * 与 Dart 把 `WeatherProvider` 挂在 Navigator 之上同一语义：
     * 设置页改城市 → 弹层那一行跟着变。
     *
     * 它同时被三处消费：设置页 `b.weather`、选城页 `j.weatherCity`、课表操作弹层。
     */
    val weather: WeatherProvider by lazy {
        val service = WeatherService(JdkWeatherHttp())
        WeatherProvider(
            service = service,
            preferences = WeatherPreferences(PrefsKeyValueStore(context)),
            locationSource = AndroidWeatherLocationSource(
                context = context,
                reverseGeocode = { lat, lon -> service.reverseGeocode(lat, lon) },
                networkGeocode = { service.networkGeocode() },
            ),
        )
    }

    /**
     * 从课表空档进加课页时要预填的 `(星期, 节次)`。
     *
     * 放这里而不是 `remember` 在 Composable 里，是因为「点空档」发生在课表槽位，
     * 而加课页在页面层渲染——两者不是同一棵子树，共享不到局部状态。
     * 用完即清（见 [clearAddCourseSeed]），否则下次从按钮进加课页会被上次的坑位污染。
     */
    var pendingAddCourseSeed: Pair<Int, Int>? = null

    /** 从课表点某门课进加课页时要带进去的编辑对象；null = 新建。 */
    var pendingEditCourse: Course? = null

    /**
     * 从课程总览点某个课程组进编辑页时要带进去的**整组**；null = 不是组编辑。
     *
     * 与 [pendingEditCourse] 同属「跨子树传一次、用完即清」的意图载体：
     * 课程总览页的行是「同名课聚合组」，Dart 侧 `AddCourseScreen(courseGroup: group)`
     * 编辑的是整组（改名走 `updateCourseGroup`），不是单门课。
     * 两者互斥：组编辑只填本字段，单课编辑只填 [pendingEditCourse]。
     */
    var pendingEditGroup: CourseGroup? = null

    /**
     * 「作业行 → 查看课程」时要带进加课页的**来源周次**（2026-10-29 任务族复刻收口）。
     *
     * Dart 侧 `task_list_screen.dart:346-357` 是
     * `AddCourseScreen(course: course, initialWeek: task.sourceWeek)`：点作业行的「查看课程」
     * 不只看那门课，还要把课程周次区间的**起点定位到这条作业的来源周**。
     * 与 [pendingEditCourse] 同属「跨子树传一次、用完即清」的意图载体（见 [clearAddCourseIntent]）。
     */
    var pendingEditWeek: Int? = null

    /**
     * 从课程操作弹层点「加作业」时要带进作业页的预选课程（T1）。
     *
     * 与 [pendingEditCourse] 同生命周期：都是「跨子树传一次、用完即清」的意图载体。
     */
    var pendingTaskCourse: Course? = null

    /**
     * 从日视图课卡的「作业」胶囊进来时要带的**来源周**
     *（Dart `taskForm(initialCourse:, initialWeek: week)`，`day_view_course_agenda_card.dart:174-183`）。
     *
     * 不传时 `d2.addTask` 退回仓储当前周；跨周查看日视图（翻到第 5 周）时来源周会记成
     * 「今天这一周」，作业与那节课就对不上了。与 [pendingTaskCourse] 同生命周期。
     */
    var pendingTaskWeek: Int? = null

    /**
     * 从任务清单点某条任务进入编辑页时要带进去的对象；null = 新建（T1 收尾 · 2026-10-28）。
     *
     * 与 [pendingTaskCourse] 互斥使用：进「编辑任务」时用本字段，进「添加任务」时清空它。
     * `d2.addTask` 分支据此选择「载入已有任务」还是「预选课程新建」。
     */
    var pendingTaskForEdit: com.mutx163.qingyu.core.CourseTask? = null

    /**
     * 从考试列表点某场考试进入编辑页时要带进去的对象；null = 新建（F10 · 2026-10-29）。
     *
     * 与 [pendingTaskForEdit] 同一范式：`d3.examList` 写、`d3.addExam` 读，用完即清。
     * 没有它，`d3.addExam` 只可能是「新建」——清单 §二 F10 记的
     * 「`isEditing` 永远是 false ⇒ 编辑既有考试这条路根本不存在」正是缺这一条。
     */
    var pendingEditExam: com.mutx163.qingyu.core.Exam? = null

    /**
     * 从日程列表点某条日程进入编辑页时要带进去的对象；null = 新建。
     *
     * 与 [pendingEditCourse] 同属「跨子树传一次、用完即清」的意图载体：日程槽位（或索引里的
     * 日程列表）与添加/编辑页是两棵子树，共享不到局部状态。
     */
    var pendingScheduleEdit: ScheduleItemData? = null

    /** 从某一次重复日程进入编辑/删除时带的 occurrenceDate（`yyyy-MM-dd`）；null = 非单次编辑。 */
    var pendingScheduleOccurrenceDate: String? = null

    /** 新建日程时的默认日期（`yyyy-MM-dd`）；null 时页面自己取今天。 */
    var pendingScheduleInitialDate: String? = null

    /**
     * 从星期栏点进日视图时要打开的那一天（1..7）；`null` = 没有具体意图。
     *
     * 2026-10-30 修 P0-2：此前 `c3.day` 的 `initialDayOfWeek` 恒取 `LocalDate.now()`，
     * 点「周五」进去看到的永远是**今天**。现在由星期栏写入、日视图读完立即清空
     * （一次性意图，不该约束之后的翻页）。
     */
    var pendingDayViewDayOfWeek: Int? = null

    /**
     * 取出并**清空**「点哪天进日视图」的意图。
     *
     * 必须原子地读一次就清：`c3.day` 分支每次进入都会重组多次，用裸读会让同一次
     * 打开多轮读取都拿到同一个值（看着没问题），但下一次**从底栏或菜单**进日视图时
     * 就会沿用上次点的那天 —— Dart 侧是 `Navigator` 带参数的一次性传参，没有这个残留。
     *
     * @return 1..7；没有意图时 null（页面自己落今天）。
     */
    fun consumeDayViewDayOfWeek(): Int? {
        val value = pendingDayViewDayOfWeek
        pendingDayViewDayOfWeek = null
        return value
    }

    fun clearScheduleIntent() {
        pendingScheduleEdit = null
        pendingScheduleOccurrenceDate = null
        pendingScheduleInitialDate = null
    }

    /**
     * 时间模板「编辑节次」页要打开哪一套（P35-TS，2026-10-29）。
     *
     * `d3.timeSchemes`（列表页宿主）写、`d3.timeSchemeEditor`（编辑页宿主）读：
     * 两者是**两条独立的壳路由分支**，共享不到局部状态，与 [pendingEditCourse] 同属
     * 「跨子树传一次、用完即清」的意图载体。用完由编辑页宿主清空（返回时清）。
     */
    var pendingTimeSchemeEditId: String? = null

    /**
     * 统计深度分析页当前要打开的模块（ST1）：`e.statistics` 的 `onOpenAnalysis` 写入、
     * `e.analysis` 读取。
     *
     * 为什么放这里：`e.statistics` 与 `e.analysis` 是**两个独立的路由分支**，不是同一棵子树，
     * 共享不到局部状态；与 [pendingEditCourse] 同属「跨子树传一次」的意图载体。
     * 默认 `TREND` 与页面原有的写死值一致，避免未设置时行为变化。
     */
    var pendingAnalysisModule: StatisticsAnalysisModule = StatisticsAnalysisModule.TREND

    fun clearAddCourseIntent() {
        pendingAddCourseSeed = null
        pendingEditCourse = null
        pendingEditGroup = null
        pendingEditWeek = null
    }

    /**
     * 顶栏「更多」菜单 → 添加课程时的统一预填（Dart `timetable_screen.dart:1745-1752`
     * 的 `openCourseForm`：`AddCourseScreen(initialWeek: _visibleWeek, initialDayOfWeek: …)`）。
     *
     * 三个视图的顶栏菜单都走这里：带**当前浏览周**与**今天星期几**。
     * 只带星期不带节次 —— Dart 不传 `initialStartSection`，页面默认从第 1 节起，
     * 所以 [pendingAddCourseSeed] 的第二节固定 1 与页面默认值等价，不会预填错节次。
     *
     * @param browseWeek 当前浏览的周（= 仓储 `currentWeek`，三个视图同源）。
     */
    fun seedAddCourseFromMenu(browseWeek: Int) {
        pendingAddCourseSeed = LocalDate.now().dayOfWeek.value to 1
        pendingEditCourse = null
        pendingEditGroup = null
        pendingEditWeek = browseWeek
    }

    /**
     * 加课页的保存载荷 → 仓储。
     *
     * `AddCoursePage` 的 KDoc 明确写着「保存载荷交给壳层落盘，由壳层按 mode 分派」，
     * 所以这个分派属于宿主职责，不是页面职责。
     */
    fun applyAddCourseSave(payload: AddCourseSavePayload) {
        // **整组替换**，不是逐课 update：编辑态删掉的课次必须真的从仓储消失。
        // 判据等价关系由 `TimetableHostLogicTest` 的跨层契约测试钉住：
        // 编辑 ⟺ `payload.targetGroupName != null`（所以这里只传组名，不传 mode）。
        TimetableSaveDispatcher.applySave(
            port = timetable,
            originalGroupName = payload.targetGroupName,
            courses = payload.courses,
        )
    }

    /**
     * 编辑态删除。
     *
     * 壳目前只以**单课形态**进编辑页（没有 courseGroup 上下文），所以走 SingleCourse
     * （Dart `add_course_screen.dart:448-473`）；将来接组编辑入口时，
     * 这里把 `originalGroupName` 传成组名就会自动走整组删除（`:1406-1425`），分派器不用改。
     *
     * @return true 表示删除成功（调用方据此决定是否关页）
     */
    fun deleteEditingCourse(): Boolean {
        // 编辑上下文二选一：组编辑（课程总览入口）传组名 → WholeGroup；
        // 单课编辑传 initialCourse → SingleCourse。resolveDeleteTarget 自带这条优先级。
        val target = TimetableSaveDispatcher.resolveDeleteTarget(
            originalGroupName = pendingEditGroup?.name,
            initialCourse = pendingEditCourse,
        ) ?: return false
        return try {
            TimetableSaveDispatcher.applyDelete(timetable, target)
            true
        } catch (_: Exception) {
            // Dart 口径：落盘失败**不报成功、不关页**，由页面弹 deleteFailed。
            false
        }
    }

    /**
     * 日程页的保存载荷 → 仓储（新增 / 改全部 / 改这一次）。
     *
     * 分派判据在 [ScheduleEditDispatcher]（纯 Kotlin，已单测）：新建 → add；正在编辑某一次发生
     * 且用户选「只这一次」→ updateOccurrence；否则 → update（改整条/整系列）。
     *
     * @return true 表示保存成功（调用方据此决定是否关页）；失败留在页面上，不假装成功。
     */
    fun saveScheduleItem(draft: ScheduleItemData, applyToAll: Boolean?): Boolean {
        return try {
            val existing = timetable.snapshot.scheduleItems.firstOrNull { it.id == draft.id }
            val core = ScheduleItemBridge.toCore(draft, preserveCreatedAt = existing?.createdAt)
            ScheduleEditDispatcher.save(
                port = timetable,
                item = core,
                isNew = existing == null,
                isOccurrenceEditing = draft.occurrenceDate != null,
                applyToAll = applyToAll,
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 日程页的删除 → 仓储（删整条/整系列 或 只删这一次）。
     *
     * @return true 表示删除成功（调用方据此决定是否关页）。
     */
    fun deleteScheduleItem(item: ScheduleItemData, applyToAll: Boolean?): Boolean {
        return try {
            val core = ScheduleItemBridge.toCore(item)
            ScheduleEditDispatcher.delete(
                port = timetable,
                item = core,
                isOccurrenceEditing = item.occurrenceDate != null,
                applyToAll = applyToAll,
            )
            true
        } catch (_: Exception) {
            false
        }
    }
}

/**
 * 取（并在首次组合时构造）壳的接线层。
 *
 * 用 `applicationContext`：仓储要活过 Activity 重建，持有 Activity 的 Context 会泄漏。
 */
@Composable
fun rememberShellWiring(): ShellWiring {
    val context = LocalContext.current.applicationContext
    return remember { ShellWiring(context) }
}

/**
 * **课表槽位 + 课程操作弹层**（T1，`8866b3b5` 的壳侧接线）。
 *
 * ## 为什么抽成一个 Composable
 *
 * 课表有两个入口——底部坞的「课表」槽位（`PagesShellActivity`）和页面层的 `c1.week`
 * （`ShellPageIndex`）。操作弹层必须**两处都在**，否则从某一个入口进去点课程还是没反应。
 * 抽成一份就不会两边漂。
 *
 * ## 行为变化（这是 T1 的核心）
 *
 * **点课程卡片不再直接进编辑页**，而是先弹操作层：编辑 / 调课 / 删除 / 停课复课 / 加作业。
 * 老版就是这个形态（`course_action_sheet.dart`）；之前直接进编辑页是 Phase 3 的临时接法。
 *
 * ## 订阅语义
 *
 * 先读 `repository.snapshot` 拿初值再 `observe`——`observe` **订阅那一刻不推当前值**
 * （见 `TimetableRepository` 的 KDoc）。`week` 必须跟着快照走：调课/停课都按「当前周」算，
 * 用一次性的旧值会把课挪错周。
 *
 * ## 参数透传（2026-10-29 重做后新增的两条硬要求）
 *
 * 1. **操作对象按事件里的 `courseId` 现取**，不用 `actionTarget`：弹层内部允许切到冲突课
 *    （Dart `_selectedIndex`），用旧引用会把编辑/删除落到「最初点开的那门课」上。
 * 2. **`weatherProvider` 必须传下来**：弹层「天气」行的数据只在壳里有（设备级 provider），
 *    不传就是「设置里开了天气、弹层里没有那一行」。
 *
 * ## 失败不假装成功
 *
 * 写库失败（分派器回滚并 rethrow，Dart 同一口径）一律如实 toast，**不静默关掉**——
 * 静默就是「点了没反应」的另一种形态。单节课提醒这一行由模型层按
 * `ClassAlarmPlanLogic.isAvailable`（未来课可设 / 当天开课前可设）决定出现与否，
 * 确认后经 `onAlarmEvent` 走系统时钟（`SystemAlarmHelper`）。
 */
@Composable
fun TimetableWithCourseActions(
    wiring: ShellWiring,
    onNavigate: (String) -> Unit,
    weatherProvider: WeatherProvider? = null,
) {
    val repository = wiring.timetable
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    var actionTarget by remember { mutableStateOf<Course?>(null) }
    val context = LocalContext.current
    val week = snapshot.currentWeek
    // 设置模型：首页材质 / 壁纸 + 弹层里的天气四开关都读它。
    // ⚠️ `settingsModel.load()` 是**普通函数调用**，不是可观察状态：必须把
    // [ShellWiring.settingsRevision] 读进组合才会在「返回首页」时重读一次盘。
    // 否则从外观编辑页 / 设置页回来，材质、壁纸、显示偏好全部停在旧值上，
    // 直到用户翻一下页（仓储状态变化逼出重组）才刷新 —— 2026-11-02 用户实报。
    val settingsRevision = wiring.settingsRevision
    val settingsModel = remember(settingsRevision) { wiring.settingsModel.load() }
    // 「这节课闹钟」的两个提醒设置键（Dart `classAlarmLeadMinutes` / `classAlarmSkipUi`，
    // timetable_settings.dart:1746-1747 的读口径在 ClassAlarmPlanLogic）。这两个键属
    // 「提醒」设置族（P35-settings-model 认领表里未覆盖的键），这里按原始 JSON 只读，
    // 不动设置模型的 OWNED_KEYS。
    val alarmSettings = remember(settingsRevision) { wiring.loadRawSettingsJson() }
    val classAlarmLeadMinutes = ClassAlarmPlanLogic.leadMinutesFromSettings(alarmSettings)
    val classAlarmSkipUi = ClassAlarmPlanLogic.skipUiFromSettings(alarmSettings)

    // 天气 provider **不是** Compose 可观察的（它是 `addListener` 那套）。这里用一个计数
    // 把「数据到了 / 城市变了」转成重组；`DisposableEffect` 负责订阅与退订，
    // 退订必须用**同一个** lambda 引用，否则监听器会漏在 provider 里。
    var weatherTick by remember(weatherProvider) { mutableIntStateOf(0) }
    DisposableEffect(weatherProvider) {
        val provider = weatherProvider
        if (provider == null) {
            onDispose { }
        } else {
            val listener: () -> Unit = { weatherTick += 1 }
            provider.addListener(listener)
            onDispose { provider.removeListener(listener) }
        }
    }

    // 预览条目：主课 + 同周冲突课（Dart `timetable_course_action_items.dart`）。
    // 情侣课本轮**没有数据源**（Compose 周视图还没有情侣叠加层），按缺口留空口、不伪造。
    val previewItems = remember(actionTarget, week, snapshot.courses) {
        val target = actionTarget
        if (target == null) {
            emptyList()
        } else {
            CourseActionSheetModel.buildPreviewItems(
                courses = snapshot.courses,
                primary = target,
                week = week,
            )
        }
    }

    val weatherPrefs = remember(settingsModel) {
        CourseSheetWeatherPrefs(
            showOnSheet = settingsModel.weatherShowOnSheet,
            showPhenomenon = settingsModel.weatherShowPhenomenon,
            showTemperature = settingsModel.weatherShowTemperature,
            showProbability = settingsModel.weatherShowProbability,
        )
    }

    // 调课弹层要的节次表：Dart 是
    // `resolvedSectionsForCourse(course) ?? scheme?.sections ?? settings.sections`
    // （`timetable_screen.dart:9153-9158`）。**不能**直接传全局 `settings.sections`：
    // 钉了自定义钟点的课会显示错时间、选到越界节还会被写库校验拒掉。
    // 这里按**主课**解析（弹层允许切到冲突课，冲突课一般同作息；差异记在审核报告诚实清单）。
    val sectionTimes = remember(actionTarget, snapshot.timeSchemes, snapshot.settings) {
        val target = actionTarget
        val scheme = if (target == null) {
            null
        } else {
            TimeSchemeLogic.resolveCourseTimeScheme(
                schemes = snapshot.timeSchemes,
                settings = snapshot.settings,
                course = target,
            )
        }
        scheme?.sections?.takeIf { it.isNotEmpty() } ?: snapshot.settings.sections
    }

    // 弹层内容描述（模型层算，渲染层只画）。
    // 依赖里带 `snapshot`：作业 / 设置 / 课程任何一处变更后都要重算那一行的标题与副题。
    val details = remember(previewItems, week, snapshot, weatherTick, weatherPrefs, sectionTimes) {
        CourseActionSheetModel.build(
            previewItems = previewItems,
            week = week,
            tasks = repository.tasks,
            weatherPrefs = weatherPrefs,
            dateOf = { course -> repository.dateForCourseOccurrence(course, week)?.toLocalDate() },
            weatherOf = { course ->
                val date = repository.dateForCourseOccurrence(course, week)
                val provider = weatherProvider
                when {
                    date == null -> CourseSheetWeatherInfo()
                    provider == null -> CourseSheetWeatherInfo(date = date.toLocalDate())
                    else -> CourseSheetWeatherInfo(
                        date = date.toLocalDate(),
                        summary = provider.summaryForCourse(date, course.startTime, course.endTime),
                        awaiting = provider.isAwaitingData,
                    )
                }
            },
            weekCount = snapshot.settings.semesterWeekCount,
            sectionTimes = sectionTimes,
        )
    }

    // 首页周 / 日展开态的初始进度：只在宿主**被重建**时才有意义（冷启动 = 直接落定，
    // 从别的底栏页切回来 = 播一次展开/收起）。种子读一次即清，见 `ShellWiring`。
    val homeMotionSeed = remember { wiring.consumeHomeViewMotionSeed() }
    val dayProgressSeed = when {
        wiring.homeViewMode == TimetableHomeViewMode.DAY &&
            homeMotionSeed == TimetableHomeViewMode.WEEK -> 0f
        wiring.homeViewMode == TimetableHomeViewMode.WEEK &&
            homeMotionSeed == TimetableHomeViewMode.DAY -> 1f
        wiring.homeViewMode == TimetableHomeViewMode.DAY -> 1f
        else -> 0f
    }

    TimetableHost(
        repository = repository,
        onOpenAddCourse = { dayOfWeek, section ->
            wiring.pendingAddCourseSeed = dayOfWeek to section
            wiring.pendingEditCourse = null
            wiring.pendingEditGroup = null
            // 长按空档要落在**当前浏览周**：原先前端漏了它，加课页 `initialWeek = null → 1`，
            // 在第 5 周点空档会被记到第 1 周（Dart `_openAddCourseFromEmptySlot(week: …)`，
            // `timetable_screen.dart:1334-1351`）。`week` 就是仓储当前周（本帧快照）。
            wiring.pendingEditWeek = week
            onNavigate("d1.addCourse")
        },
        // T1：点课程 → 先弹操作层，不直接进编辑页。
        onOpenCourse = { course -> actionTarget = course },
        onWeekChanged = { week ->
            repository.setCurrentWeek(week)
            // 周视图翻到哪一周也要更新「日视图的落点周」：底栏「日」进入时 Dart 取的是
            // 当前浏览周（`visibleWeek`），不取仓储里可能更旧的值。
            wiring.homeSelectedWeek = week
        },
        // 点星期栏某一天 / 底栏「日」→ 首页在同一页里展开日视图（Dart
        // `DayViewTransitionController.toggle` 的入口）。**不推页面**：推一页会被
        // miuix 播成「从左侧滑入」，与原版「选中的那一列长成整屏」完全不同
        // （2026-11-02 用户实报）。周 / 日是同一宿主里的两种展开态。
        homeViewMode = wiring.homeViewMode,
        selectedWeek = wiring.homeSelectedWeek,
        selectedDayOfWeek = wiring.homeSelectedDayOfWeek,
        dayProgressSeed = dayProgressSeed,
        onSelectDay = { selectedWeek, selectedDayOfWeek ->
            wiring.setHomeSelection(selectedWeek, selectedDayOfWeek)
            wiring.switchHomeViewMode(TimetableHomeViewMode.DAY)
            // 仓储当前周跟着「正在看的那一周」走：日视图跨周翻页后收起，周视图要落在同一周。
            repository.setCurrentWeek(selectedWeek)
        },
        onCloseDay = { wiring.switchHomeViewMode(TimetableHomeViewMode.WEEK) },
        transitionSpeed = wiring.pageTransitionSpeed,
        // 日视图的**内容**仍由 `c3.day` 那一条分支提供（数据装配、点击落点都只有一份）。
        // 这里只是把同一个页面塞进首页的展开窗口里，并告诉它「顶栏/星期栏已由周视图画好，
        // 你的正文从 contentTop 开始」——避免两套壳重叠、也避免再抄一份 200 行接线。
        dayContent = { contentTopInset ->
            ShellPageContent(
                pageId = "c3.day",
                onBack = {},
                wiring = wiring,
                onOpenPage = onNavigate,
                dayOverlay = DayViewOverlayBinding(
                    contentTopInset = contentTopInset,
                    initialWeek = wiring.homeSelectedWeek,
                    initialDayOfWeek = wiring.homeSelectedDayOfWeek,
                    requestedWeek = wiring.homeSelectedWeek,
                    requestedDayOfWeek = wiring.homeSelectedDayOfWeek,
                    onPageChanged = { week, dayOfWeek ->
                        wiring.setHomeSelection(week, dayOfWeek)
                    },
                    onRequestClose = { wiring.switchHomeViewMode(TimetableHomeViewMode.WEEK) },
                ),
            )
        },
        // 周网格里的考试 / 日程卡：Dart 侧考试卡 → 考试页、日程卡 → 日程编辑页
        // （`week_grid_agenda_card.dart` 的 closedBuilder/openBuilder 同一条路）。
        // 这里按 id 找回实体再带进目标页；找不到就退到列表页，不让点击变哑。
        onAgendaClicked = { entry ->
            when (entry.kind) {
                WeekAgendaKind.EXAM -> onNavigate("d3.examList")
                WeekAgendaKind.SCHEDULE -> {
                    val item = snapshot.scheduleItems.firstOrNull { candidate ->
                        entry.id == candidate.id || entry.id.startsWith("${candidate.id}@")
                    }
                    if (item == null) {
                        onNavigate("d2.scheduleList")
                    } else {
                        wiring.clearScheduleIntent()
                        wiring.pendingScheduleEdit = ScheduleItemBridge.toUiData(item)
                        wiring.pendingScheduleOccurrenceDate =
                            entry.id.substringAfter('@', missingDelimiterValue = "")
                                .takeIf { it.isNotBlank() }
                        onNavigate("d2.addSchedule")
                    }
                }
            }
        },
        // 标题区点击 = 切课表（Dart `TimetableProfileSwitcherTrigger` 的口径）：
        // 壳里没有独立快切弹层，推到课表管理页，行为可预期、不空点。
        onSwitchProfile = { onNavigate("c1.profiles") },
        // S1：显示偏好改从**用户存档**读，不再吃宿主默认值。
        // ⚠️ 这里每次重组都会 `load()` 一次——设置存储没有变更通道（见交付方诚实清单第 2 条）。
        // 验收路径（杀进程重开 / 离开再回课表）都拿得到新值；「课表页正开着时后台改设置」
        // 不会自刷，但本 App 里不存在这种同屏场景。
        settingsModel = settingsModel,
        // 顶栏右上角「更多」菜单：**用户存档的排列**（`homeGridMenuActions`），
        // 空表 / 只剩钉住项时回退 Dart 默认八项；条目 id → 壳页面 id 见
        // `shellTimetableMenuPageId`。2026-10-31 之前这里喂的是固定八项，
        // 「自定义八宫格按钮」改了没有任何效果。
        homeMenuItems = homeTopMenuItems(settingsModel),
        // 「添加课程」这一项要带当前浏览周与今天星期几（Dart `openCourseForm`，见
        // [ShellWiring.seedAddCourseFromMenu]）；其余项只按映射表推页。
        onHomeMenuSelect = { id ->
            shellTimetableMenuPageId(id)?.let { target ->
                if (target == "d1.addCourse") wiring.seedAddCourseFromMenu(week)
                onNavigate(target)
            }
        },
    )

    val course = actionTarget
    CourseActionSheet(
        course = course,
        week = week,
        previewItems = previewItems,
        details = details,
        leadMinutes = classAlarmLeadMinutes,
        skipUi = classAlarmSkipUi,
        onDismiss = { actionTarget = null },
        // 弹层只抛事件、不写库；写库与导航都在这里。
        //
        // ⚠️ **不能**用 `actionTarget` 当被操作对象：弹层内部允许切到冲突课
        // （Dart `_selectedIndex`），事件自带 `courseId`。一律按 id 回最新快照取实体，
        // 这样既不会把操作落到「最初点开的那门课」，也不会拿旧对象覆盖别人刚写过的字段。
        onEvent = { event ->
            val target = snapshot.courses.firstOrNull { it.id == event.courseId }
            actionTarget = null
            // 课程在弹层打开期间被删掉了（或换了课表）：不写库、不假装成功。
            if (target != null) {
                when (event) {
                    is CourseActionEvent.Edit -> {
                        // 带**同名整组**进编辑页（Dart `_editCourse` → `courseGroupForCourse`，
                        // `timetable_screen.dart:1644-1655`）。只带单门课会让组编辑上下文缺失：
                        // 保存走整组替换时，同名其它课次会被当成「被删掉的课次」一起清掉
                        // （P0：编辑一门课删掉同名其它课次）。`siblings` 必含 target，不会为空。
                        val siblings = snapshot.courses.filter { it.name == target.name }
                        wiring.pendingEditCourse = target
                        wiring.pendingAddCourseSeed = null
                        wiring.pendingEditWeek = null
                        wiring.pendingEditGroup = CourseGroup(name = target.name, courses = siblings)
                        onNavigate("d1.addCourse")
                    }
                    is CourseActionEvent.AddTask -> {
                        wiring.pendingTaskCourse = target
                        // 从课程加作业是「新建」，必须清掉可能残留的「编辑目标」，
                        // 否则会误把上一次没保存的编辑对象载进表单。
                        wiring.pendingTaskForEdit = null
                        onNavigate("d2.addTask")
                    }
                    // 删除 / 停课 / 调课 / 备注：分派器写库并通知，宿主会自己重组。
                    // 落盘失败的分派器会回滚并 rethrow（Dart 同一口径），**不接就是静默失败**，
                    // 所以每条都如实 toast 出来。
                    is CourseActionEvent.Delete -> try {
                        when (event.scope) {
                            CourseDeleteScope.WHOLE_COURSE ->
                                CourseActionDispatcher.deleteCourse(repository, target.id)
                            CourseDeleteScope.THIS_WEEK ->
                                CourseActionDispatcher.deleteOccurrence(repository, target.id, week)
                        }
                    } catch (_: Exception) {
                        Toast.makeText(context, TimetableStrings.deleteFailed.zh, Toast.LENGTH_SHORT).show()
                    }
                    is CourseActionEvent.Suspend -> try {
                        when (event.scope) {
                            CourseSuspendScope.THIS_WEEK ->
                                CourseActionDispatcher.toggleSuspensionThisWeek(repository, target.id, week)
                            // 整门：当前有停课记录 ⇒ 恢复全部；否则停全部。
                            // 判据与弹层里那两行文案同源（`CourseFollowupModel.suspendScopeOptions`）。
                            CourseSuspendScope.ALL_WEEKS ->
                                if (target.suspendedWeeks.isNullOrEmpty()) {
                                    CourseActionDispatcher.suspendAllWeeks(repository, target.id)
                                } else {
                                    CourseActionDispatcher.unsuspendAllWeeks(repository, target.id)
                                }
                        }
                    } catch (_: Exception) {
                        Toast.makeText(context, TimetableStrings.saveFailed.zh, Toast.LENGTH_SHORT).show()
                    }
                    is CourseActionEvent.Reschedule -> try {
                        CourseActionDispatcher.rescheduleOccurrence(
                            port = repository,
                            courseId = target.id,
                            sourceWeek = week,
                            targetWeek = event.target.targetWeek,
                            targetDayOfWeek = event.target.targetDayOfWeek,
                            targetStartSection = event.target.targetStartSection,
                            targetEndSection = event.target.targetEndSection,
                            targetLocation = event.target.targetLocation,
                        )
                    } catch (_: Exception) {
                        Toast.makeText(context, TimetableStrings.saveFailed.zh, Toast.LENGTH_SHORT).show()
                    }
                    is CourseActionEvent.SaveNotes -> try {
                        // `hasHomework` 由分派器保留原值（Dart `course_note_sheet.dart:160-175`）。
                        CourseActionDispatcher.saveCourseNotes(
                            port = repository,
                            courseId = target.id,
                            week = week,
                            wholeNote = event.wholeNote,
                            sessionNoteText = event.sessionNote,
                        )
                    } catch (_: Exception) {
                        Toast.makeText(context, TimetableStrings.saveFailed.zh, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        },
        // 「这节课闹钟」事件 → 系统时钟（Dart `SystemAlarmService` ← `class_reminder_sheet`）。
        // 闹钟标签 = 应用名 + ` · ` + 短课名（Dart `'轻屿 · $label'`，`class_reminder_sheet.dart:96`）；
        // 应用名走 PackageManager 运行时取，不在壳里写死文案。
        onAlarmEvent = { event ->
            val activity = context as? Activity
            when (event) {
                is ClassAlarmEvent.SetSystemAlarm -> {
                    val appName = activity?.applicationInfo?.loadLabel(context.packageManager)
                        ?.toString()?.trim().orEmpty()
                    val label = if (appName.isEmpty()) event.courseLabel else "$appName · ${event.courseLabel}"
                    val outcome = activity?.let {
                        SystemAlarmHelper.fireSetAlarm(
                            activity = it,
                            hour = event.hour,
                            minute = event.minute,
                            label = label,
                            skipUi = event.skipUi,
                            days = event.repeatDays,
                        )
                    }
                    val ok = outcome?.launched == true
                    Toast.makeText(
                        context,
                        (if (ok) {
                            com.mutx163.qingyu.app.CourseActionStrings.classAlarmAddedToast
                        } else {
                            com.mutx163.qingyu.app.CourseActionStrings.classAlarmLaunchFailedToast
                        }).zh,
                        Toast.LENGTH_SHORT,
                    ).show()
                }
                ClassAlarmEvent.OpenSystemClock -> {
                    val ok = activity?.let { SystemAlarmHelper.fireShowAlarms(it) } ?: false
                    if (!ok) {
                        Toast.makeText(
                            context,
                            com.mutx163.qingyu.app.CourseActionStrings.classAlarmLaunchFailedToast.zh,
                            Toast.LENGTH_SHORT,
                        ).show()
                    }
                }
            }
        },
    )
}

/**
 * 设置页的 `actionTarget` 路由 → **壳页面 id**。
 *
 * ## 为什么需要这张表
 *
 * 设置页的 `actionTarget` 用的是 Dart 时代的**路由字符串**（`/settings/appearance` 这种），
 * 而壳的页面层用的是**目录 id**（`b.appearance`）。两套命名空间之间原本没有任何映射，
 * 所以设置页里点一行「推页」的箭头，壳这边不知道推哪一页。
 *
 * ## 规则
 *
 * 只映射**目录里真实存在**的 id；映射不到的返回 null，调用方**什么都不做**（不崩、不猜）。
 * 这张表会随设置族逐刀接线而变长——**每接一页就补上它的出站路由**。
 *
 * ⚠️ 已知缺口：本表覆盖的是设置族 4 页当前会发出的路由 + 一批常用路由；
 * 没列到的路由会静默 no-op。下一刀接更多设置页时，**先来这里补表**，别在页面里硬编码。
 */
fun shellPageIdForRoute(route: String?): String? = when (route) {
    // —— 设置族（4 页当前出站 + 兄弟页）——
    "/settings/general" -> "b.general"
    "/settings/appearance" -> "b.appearance"
    "/settings/theme" -> "b.theme"
    "/settings/course-card" -> "b.courseCard"
    "/settings/appearance-editor" -> "b.appearanceEditor"
    // 外观编辑页「每日壁纸」行的去向。串取自 `SettingsBackdropFlowPage.BING_GALLERY_TARGET`，
    // **没有前导 `/`**——它是页内目标 id 不是路由串，别顺手改成 `/settings/...`（那要同时改 Dart 侧）。
    "bingWallpaperGallery" -> "b.bingGallery"
    // 课程卡片页「卡片外观」直达到材质面板的课程卡片页签（Dart `initialMaterialPage`）。
    // 同样是没有前导 `/` 的页内目标 id。
    "materialCourseCard" -> "b.materialCourseCard"
    // 壁纸取景页（外观编辑 → 壁纸面板 → 调整位置）。串带点号，是**页内动作 id** 不是路由串；
    // 分派器原样转成 NAVIGATE，这里必须给落点，否则「调整位置」还是静默没反应。
    // ⚠️ `SettingsRouteWiringGuardTest` 按设计**不扫**带点号的值（那是页内动作的形状），
    // 所以这条只能靠人守——删了不会有测试报红。
    "backdrop.image.adjust" -> "b.wallpaperPosition"
    // 课表页面设置里「背景图片 / 最近使用」两行的去向（2026-11-01）。分派器产出的 SHEET
    // 不带 target，`TimetablePageSettingsHost` 按 rowId 翻成下面这两个页 id；这里是
    // 页 id → 页 id 的自映射，只为让 `shellPageIdForRoute` 有出口，别误当成 Dart 路由串。
    "b.backdropFlow" -> "b.backdropFlow"
    "b.recentWallpaper" -> "b.recentWallpaper"
    "/settings/semester" -> "b.semester"
    "/settings/time-schemes" -> "d3.timeSchemes"
    // 时间模板「编辑节次」子页（P35-TS）：列表页点卡片按钮 / 新建成功后推这一页，
    // 具体编辑哪一套走 `ShellWiring.pendingTimeSchemeEditId`（路由串不带参数，与其余页面同构）。
    "/settings/time-schemes/editor" -> "d3.timeSchemeEditor"
    "/settings/timetable-page" -> "b.timetablePage"
    "/settings/holiday" -> "b.holiday"
    "/settings/holiday/advanced" -> "b.holidayAdvanced"
    "/settings/weather" -> "b.weather"
    "/settings/weather/city" -> "j.weatherCity"
    "/settings/live" -> "b.live"
    "/settings/live/self-check" -> "b.liveSelfCheck"
    "/settings/live/keep-alive" -> "j.keepAlive"
    "/settings/live/reminder-timing" -> "j.reminderTiming"
    "/settings/live/display/before-class" -> "j.displayBefore"
    "/settings/live/display/during-end" -> "j.displayDuring"
    "/settings/home-widget" -> "b.homeWidget"
    "/settings/home-navigation" -> "b.homeNavigation"
    "/settings/home-menu" -> "b.homeMenuEditor"
    "/settings/glass-dock" -> "b.glassDock"
    "/settings/glass-dock-icon" -> "b.glassDockIcon"
    "/settings/diagnostics" -> "b.diagnostics"
    "app-logs" -> "h.log"
    "/settings/reset" -> "b.reset"
    "/settings/cloud-sync" -> "f.cloudSync"
    "/settings/couple-timetable" -> "f.couple"
    "/settings/data-transfer" -> "g3.dataTransfer"
    "/settings/lan-edit" -> "g3.lanEdit"
    "/settings/memory-stats" -> "h.memory"
    "/settings/live-testing-fixture" -> "h.fixture"
    "/settings/miuix-showcase" -> "i2.showcase"
    "/settings/hyperos-showcase" -> "i.hyperosShowcase"
    // —— 跨域常用 ——
    "/about" -> "a.about"
    "/user-guide" -> "i.userGuide"
    "/profiles" -> "c1.profiles"
    else -> null
}

/**
 * 顶栏右上角「更多」菜单的条目：**用户存档的排列**（`homeGridMenuActions`）。
 *
 * Dart `resolveHomeGridMenuEntries`（`lib/widgets/home_menu_catalog.dart:499-533`）：
 * 丢掉目录里没有的 id、去重保序、空表或只剩钉住项时回退 `HomeGridMenu.defaultActions`
 * 那 8 项。取舍规则在 [HomeMenuNavModel]（纯 Kotlin，L0 单测钉住），这里只负责
 * 「id 有没有去处」与「id → 文案 / 图标」两件事。
 *
 * 2026-10-31 之前这个菜单写死 8 项：设置里「自定义八宫格按钮」改完，首页一点都不变。
 */
fun homeTopMenuItems(settings: TimetableSettingsModel): List<TimetableMenuItem> =
    HomeMenuNavModel.resolveIds(settings.homeGridMenuActions) { id ->
        shellTimetableMenuPageId(id) != null
    }.map { HomeNavIcons.menuItem(it) }

/**
 * 菜单/索引条目 id → 壳页面 id。
 *
 * ## 为什么单独一张表
 *
 * 菜单条目 id 沿用 Dart `HomeGridMenu.defaultActions` 与 `kHomeMenuCatalog`
 * （`lib/widgets/home_menu_catalog.dart`）的稳定主键（`overview` / `statistics` /
 * `addCourse` / `exams` / `tasks` / `importCourses` / `settings` / `support` …），
 * 与 `shellPageIdForRoute` 的 Dart 路由字符串是**两套命名空间**。
 * 页面层只回传 id（不认路由），点哪一项推到哪一页由这张表决定。
 *
 * ## 两个消费者，一张表（2026-10-29 F02 收口）
 *
 * 1. 课表页顶栏右上角「更多」菜单（`MoreMenu`）——原本只有 9 条；
 * 2. 「全部功能」索引页（`i.more` / `i.moreSearch`，39 条）——2026-10-29 之前
 *    它的 `onOpenFeature` 是空 lambda，**整页点了没反应**。现在两条入口共用本表：
 *    在 `MoreFeaturesModel`（纯 Kotlin）里新增条目后，**必须**在这里补一行，
 *    否则 `MoreFeaturesNavigationGuardTest` 会红。
 *
 * 映射不到时返回 null，调用方什么都不做（不崩、不猜）。
 * 表里的目标 id 必须在 `ShellPageCatalog` 里存在且可进入（同一条守卫会查）。
 */
fun shellTimetableMenuPageId(id: String): String? = when (id) {
    // —— 顶栏「更多」菜单原有的 9 条 ——
    "overview" -> "d1.overview"
    "statistics" -> "e.statistics"
    "addCourse" -> "d1.addCourse"
    "exams" -> "d3.examList"
    "tasks" -> "d2.taskList"
    "importCourses" -> "g1.importEntry"
    "settings" -> "b.settingsHome"
    "support" -> "a.support"
    // —— 2026-10-31 补齐：这四项在目录/底栏编辑器里都能选，但此前映射表里没有，
    //    选了之后底栏或菜单点了没反应（被解析层当成「没有去处」丢掉）。
    "addExam" -> "d3.addExam"
    "addTask" -> "d2.addTask"
    "addScheduleItem" -> "d2.addSchedule"
    // —— 2026-11-01：「添加」行的二级列表（Dart `kAddCourseSubmenu*` 的三个 id）——
    // 列表档菜单里「添加」展开成课程 / 日程 / 考试三选，子项 id 沿用 Dart 的
    // `addCourse:course|schedule|exam`。父行 `addCourse` 只作展开开关，不再直接
    // 回传（它下面那条 `"addCourse" -> "d1.addCourse"` 仍是八宫格瓷贴的去处）。
    "addCourse:course" -> "d1.addCourse"
    "addCourse:schedule" -> "d2.addSchedule"
    "addCourse:exam" -> "d3.addExam"
    // 「全部功能」索引：classic 形态没有底栏，它同时也是回到设置的一条退路。
    "more" -> "i.more"
    // 快速切课表：壳里没有独立快切弹层，与顶栏点标题同口径推课表管理页。
    "quickSwitchTimetable" -> "c1.profiles"
    // 首页/更多菜单里的「版本更新」→ 版本更新页（1:1 复刻批次交付）。
    "update" -> "a.update"

    // —— 课表内容（MoreFeaturesModel `timetable_content` 分组）——
    "profiles" -> "c1.profiles"
    "timeSchemes" -> "d3.timeSchemes"
    "locationTimeMatch" -> "d3.locationMatch"
    "scheduleDateRule" -> "d2.dateRule"
    "scheduleList" -> "d2.scheduleList"
    "courseConflict" -> "k.conflict"
    "monthView" -> "c2.month"
    "pickupCode" -> "g3.pickupCodes"

    // —— 外观显示（`timetable_appearance`）——
    "appearanceEditor" -> "b.appearanceEditor"
    "appearanceSettings" -> "b.appearance"
    "timetablePageSettings" -> "b.timetablePage"
    "courseCardSettings" -> "b.courseCard"
    "weatherSettings" -> "b.weather"
    "holidaySettings" -> "b.holiday"

    // —— 通知与桌面（`notification_desktop`）——
    "liveSettings" -> "b.live"
    "homeWidgetSettings" -> "b.homeWidget"

    // —— 应用偏好（`app_preferences`）——
    "homeNavigation" -> "b.homeNavigation"
    "generalSettings" -> "b.general"
    "statisticsSettings" -> "e.statisticsSettings"

    // —— 数据同步（`data_sync`）——
    "icsExport" -> "g3.icsExport"
    "dataTransfer" -> "g3.dataTransfer"
    "cloudSync" -> "f.cloudSync"
    "lanEdit" -> "g3.lanEdit"
    "coupleTimetable" -> "f.couple"

    // —— 关于支持（`about_support`）——
    "aboutApp" -> "a.about"
    "userGuide" -> "i.userGuide"
    "diagnosticsSettings" -> "b.diagnostics"
    "changelog" -> "a.changelog"
    "feedback" -> "k.feedback"
    "openSourceLicenses" -> "a.licenses"
    "memoryStats" -> "h.memory"
    else -> null
}

