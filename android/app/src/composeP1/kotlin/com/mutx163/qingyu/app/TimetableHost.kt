package com.mutx163.qingyu.app

import android.content.Context
import android.content.SharedPreferences
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import com.mutx163.qingyu.pages.shell.HomeNavIcons
import com.mutx163.qingyu.pages.shell.rememberHomeFloatingInsets
import com.mutx163.qingyu.pages.about.rememberHomeUpdateAvailability
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayPreferences
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableHomeTopBarState
import com.mutx163.qingyu.pages.timetable.LocalTimetableHomeTopBarState
import com.mutx163.qingyu.pages.timetable.TimetableShareImageModel
import com.mutx163.qingyu.pages.timetable.TimetableShareRequests
import com.mutx163.qingyu.pages.timetable.TimetableStyleMapping
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
import com.mutx163.qingyu.pages.timetable.WeekAgendaCardModel
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.pages.timetable.TimetableStrings
import com.mutx163.qingyu.pages.timetable.WeekHolidayMarking
import com.mutx163.qingyu.pages.timetable.WeekViewStyle
import com.mutx163.qingyu.pages.timetable.month.MonthHolidaySettings
import com.mutx163.qingyu.pages.timetable.shareTimetableImage
import com.mutx163.qingyu.pages.weather.WeatherStrings
import com.mutx163.qingyu.weather.WeatherProvider
import com.mutx163.qingyu.widgetdata.CoupleOverlaySource
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Phase 3.5 · L4 课表宿主层：把 [TimetableRepository] 接到 [TimetableWeekPage] 上。
 *
 * ## 这一层存在的理由
 *
 * Phase 3 交付的页面是「纯函数 + 数据入口」形态：模型层不持有状态、渲染层只负责画。
 * 壳里原先写的是 `TimetableWeekPage()` **零参调用**，于是既没有真数据、也没有真回调，
 * 表现就是「按钮点了没反应」。本层负责：订阅仓储快照 → 逐参喂给页面 → 把页面回调
 * 接到导航/仓储上。
 *
 * ## 参数透传纪律（这类 bug 的高发区）
 *
 * 页面每个业务参数都**逐个显式**传下去，不靠默认值（历史事故：删掉一个转发，
 * 全仓测试仍全绿，因为存量 UI 测试只断言「页面打开了」）。
 *
 * ## 2026-10-29 重做：设置终于进到渲染层
 *
 * 旧版把 `sectionHeight` / `timeColumnWidth` 两个值当「全部显示偏好」传给页面，
 * 设置里的卡面字段开关、字号、材质、冲突开关、时间列显示档、星期栏字色一个都没传，
 * 于是「设置里改了没反应」。现在由 [TimetableStyleMapping.weekViewStyle] 一次映射成
 * [WeekViewStyle] 交给页面，映射表逐键带 Dart 行号（见该函数 KDoc）。
 *
 * @param repository 课表仓储（task-7 交付）。
 * @param onOpenAddCourse **长按**空白格加课（带星期几与节次预填）。
 * @param onOpenAddCourseSpan 同上，但带上**起止节次**（两步式长按拖出来的多节跨度）。
 *   发布版 `_openAddCourseFromEmptySlot(week, day, startSection, endSection)`
 *   （`timetable_screen.dart:4854-4858`）同一口径；给后续「预填起止节次」用。
 *   本轮先留宿主入口（页面 / 网格的三参贯通在 `TimetableWeekPage` / `TimetableWeekGrid`，
 *   不在本文件），null = 退回 [onOpenAddCourse] 的两参行为。
 * @param onOpenCourse 点课程卡片：由壳决定先去操作层还是编辑页。
 * @param onSwitchProfile 点标题区：切换课表（Dart 标题触发器口径）。
 * @param onWeekChanged 翻周/选周后回调，壳写回 `currentWeek`（Dart `commitPendingWeek`）。
 * @param onAgendaClicked 点周网格里的考试/日程卡（Dart 去考试页 / 日程编辑页）。
 * @param settingsModel 完整设置模型（用户存档）。给了它才读得到真实显示偏好。
 * @param display 显示偏好**注入点**（测试用）；`null` = 按 [settingsModel] 推导。
 */
@Composable
fun TimetableHost(
    repository: TimetableRepository,
    onOpenAddCourse: (dayOfWeek: Int, section: Int) -> Unit,
    onOpenCourse: (Course) -> Unit,
    /**
     * 长按空档的**多节跨度**回调（起止节次，1 基、含两端）。
     *
     * 发布版两步式长按：虚线框可跟手换格、拖上下边拉长到多节，点框才进加课
     * （`timetable_screen.dart:4751-4810` 手势 + `:4854-4858` 带起止节次）。
     * 本轮网格/页面侧的贯通由 `TimetableWeekGrid` / `TimetableWeekPage` 负责，宿主这里
     * 先把入口开出来；null = 回退两参 [onOpenAddCourse]（end 视作 start），
     * 现有壳调用点不用改签名。
     */
    onOpenAddCourseSpan: ((dayOfWeek: Int, startSection: Int, endSection: Int) -> Unit)? = null,
    onSwitchProfile: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    onAgendaClicked: (WeekAgendaCardModel) -> Unit = {},
    // ⚠️ 名字带 Model 后缀是**必须的**：函数体里已有一个局部 `settings`（= `snapshot.settings`，
    // 是 `core.TimetableSettings` 那个子集），同名的参数会被它遮蔽、且极易读错。
    settingsModel: TimetableSettingsModel? = null,
    display: TimetableHostDisplayPrefs? = null,
    // 顶栏「轻屿课表」+ 右上角「更多」菜单：条目与选中回调由壳注入（页面不认识路由）。
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
    // 天气：设备级 provider 只在壳里（`ShellWiring` 那一份）。不传 = 课卡不出现天气行
    //（Dart `weatherShowOnWeekCard` 默认开，但没有数据时同样不画）。
    weatherProvider: WeatherProvider? = null,
    // ── 首页「周 ↔ 日」展开态（2026-11-02）────────────────────────────────
    // 日视图是同一页里的展开层，不是路由：状态由壳持有（底栏也要读它），
    // 页面只负责按 `homeViewMode` 播窗口动画。
    homeViewMode: TimetableHomeViewMode = TimetableHomeViewMode.WEEK,
    selectedWeek: Int = repository.snapshot.currentWeek.coerceAtLeast(1),
    selectedDayOfWeek: Int = 1,
    /** 宿主被重建时的首帧展开进度（0/1）；常驻切换不看它。 */
    dayProgressSeed: Float = 0f,
    /**
     * 本次周↔日切换是否 `animateTo`（来源判据）。`false` = 页面直接 `snapTo`。
     *
     * 由 [com.mutx163.qingyu.pages.ShellWiring] 的 `homeViewSwitchAnimate` 透传：
     * 底栏两格互点 = `true`（配合 [daySwitchHorizontal] 横滑）；跨页切回课表 = `false`
     * （snap，只让 Pager 横滑）；点星期栏/页内关闭 = `true`（上下翻）。
     */
    daySwitchAnimate: Boolean = true,
    /**
     * 本次周↔日切换几何是否走横滑（translateX）——底栏「周/日」两格互点 = `true`；
     * 点星期栏 / 页内关闭 = `false`（heightFactor 上下翻）。与 [daySwitchAnimate] 正交。
     */
    daySwitchHorizontal: Boolean = false,
    /**
     * 外层底栏 Pager 是否**仍在 spring 滑行**（逐字转发给 [TimetableWeekPage] 的同名参数）。
     *
     * 默认 `false` = **未接线**：`MonthSwitchMotion.shouldSnap` 的第三项恒不成立，周 / 日 / 月
     * 全部行为与接线前一致。壳侧接上 `pagerState.isScrollInProgress` 之后，连点底栏时页内
     * 过渡会当帧落定、只让外层 spring 收尾（不再出现外层 spring 与页内 360ms tween 同帧叠加）。
     */
    homePagerScrolling: Boolean = false,
    /** 点星期栏某天：壳记下选中日并切到日视图。 */
    onSelectDay: (week: Int, dayOfWeek: Int) -> Unit = { _, _ -> },
    /** 日视图摘要卡的关闭叉：壳收回周视图。 */
    onCloseDay: () -> Unit = {},
    /**
     * 日视图正文（整屏页面），窗口 / 裁切由页面负责。
     *
     * 参数 ① 是顶栏高度；参数 ② 是页面要求挂在**真摘要卡**上的修饰器（摘要卡飞行
     * 的落点实测 + 飞行期间隐藏，阶段 A）。壳必须把它原样透传到卡片上，否则飞行
     * 终点量不到、真卡也会和飞行卡一起画出来。
     */
    dayContent: (@Composable (contentTop: Dp, summaryModifier: Modifier) -> Unit)? = null,
    /** 月视图第三种页内态（与日视图互斥）。 */
    monthMode: Boolean = false,
    /** 月视图顶部角格显示哪个月（只月份，不带年份）。 */
    monthLabel: String? = null,
    /** 月视图选中的日期（顶部星期栏据此显示选中周）。 */
    monthSelectedDate: java.time.LocalDateTime? = null,
    /** 月视图正文（宿主注入；内层自己不再搭顶栏/壁纸/Scaffold）。 */
    monthContent: (@Composable () -> Unit)? = null,
    /** 周视图滚动体的可选外层（首页下拉快捷导入）：只包玻璃带下方那一块。 */
    weekScrollWrapper: (@Composable (content: @Composable () -> Unit) -> Unit)? = null,
    /** 用户「页面转场速度」，周→日展开按同一倍率缩放。 */
    transitionSpeed: Double = 1.0,
    /**
     * 截屏「分享课表图」提示是否接到这棵宿主树（默认接；**预览卡必须传 false**）。
     *
     * 外观编辑页的缩尺预览复用整个 [TimetableHost]——预览再接一份截屏监听，
     * 等于截一次屏弹两次提示（Dart `_isPreview` 守卫，`timetable_screen.dart:913-917`）。
     * 最终生效 = 本参数 × 用户存档 `screenshotSharePromptEnabled`，与页面 / 门控的
     * 同名参数是两道不同的门：这里守「预览不接」，门控守「开关关不弹」。
     */
    screenshotSharePromptEnabled: Boolean = true,
    /**
     * 设置页顶部预览模式（2026-11-04）：透传给 [TimetableWeekPage]，预览里不画状态栏留白
     * 与顶栏「轻屿课表」，星期栏当首行、网格按预览框高自适应。只给两个设置页挖洞预览用。
     */
    previewMode: Boolean = false,
    /**
     * 预览里单独放开「点星期栏 → 日视图」（2026-11-10 用户指令，课程卡片设置页预览）。
     *
     * 只透传给 [TimetableWeekPage] 的 `previewAllowsDaySwitch`：预览里除这一条外的交互
     * （顶栏/周次弹窗/回本周浮钮/课卡点击/长按加课/pager）仍全部封着。默认 `false`。
     */
    previewAllowsDaySwitch: Boolean = false,
    /**
     * 预览里的**节高基准**：首页网格的可用高（= 整屏 − 状态栏 − 首页顶栏 − 星期栏）。
     *
     * 只在 [previewMode] 下有意义（2026-11-08）：预览窗口只有 4 行高，但行高必须与首页
     * 一致——所以「自动充满」这两档算节高时用这个基准，而不是拿窗口高去除节数
     *（那会把 12 节压成 27dp 一行，正是 2026-11-04 被用户否掉的「逐节压扁」）。
     * null = 以自己的盒子为基准（真页面的旧口径）。
     */
    previewSectionBasisDp: Dp? = null,
    /**
     * 玻璃 / backdrop 表面是否启用（默认 true，其它调用点行为不变）。
     *
     * 外观编辑页的入场缩放期间传 false：预览按**实心**渲染（不建 BackdropFilter 采样层），
     * 缩放的是不透明层、不会每帧重采样玻璃；落定后再置回 true 显示实时玻璃。
     */
    glassSurfacesEnabled: Boolean = true,
    /**
     * 情侣叠加数据版本号（B1 第二阶段，2026-11-06）：情侣页改叠加色 / 周偏移只写键值存储、
     * 不碰课表仓储，宿主靠这个序号重读 [CoupleOverlaySource]。0 = 默认（未接 / 无绑定）。
     */
    coupleOverlayRevision: Int = 0,
) {
    // 首帧直接用仓储当前快照，避免「先画空网格再跳成有课」的闪一下。
    // ⚠️ 这不是优化，是**接口语义**：`TimetableRepository.observe` 只在**后续变更**时回调，
    // 订阅那一刻**不会**推一次当前值（见 `TimetableRepository.kt:56-61` 的通知语义）。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }

    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    // 情侣叠加数据（B1 第二阶段，2026-11-06）：有绑定且对方档有课才有值，否则 null = 现行为。
    // 外观编辑页的缩尺预览（previewMode）**不叠加**，与日视图预览「不受绑定影响」同一口径。
    val loadedCoupleOverlay = remember(coupleOverlayRevision, snapshot) {
        CoupleOverlaySource.load(repository)
    }
    // 绑定态判据 = 存档里有 `partner_timetable_binding`（发布版 `provider.hasPartnerBinding`
    // 同口径）。不能用 `loadedCoupleOverlay != null` 代替：那只表示「绑定且对方档有课」，
    // 对方档空了爱心就会消失（发布版不会）。
    val hasPartnerBinding = remember(coupleOverlayRevision, snapshot) {
        runCatching { !repository.rawStoredJson(CoupleOverlaySource.BINDING_KEY).isNullOrBlank() }
            .getOrDefault(false)
    }

    val settings = snapshot.settings
    // 显示偏好解析（S1）：注入点优先 → 用户存档推导 → Dart 默认。
    // `remember` 必须**无条件**调用（Compose 的调用结构要稳定），所以三种情况都在这一个
    // remember 里算完，而不是写成 `display ?: settingsModel?.let { remember { … } }`。
    val resolvedDisplay = remember(display, settingsModel) {
        display
            ?: settingsModel?.let { TimetableHostDisplayPrefs.fromSettings(it) }
            ?: TimetableHostDisplayPrefs()
    }
    // 渲染风格：设置模型 → 页面（唯一映射点，纯 Kotlin 可测）。
    val style: WeekViewStyle = remember(settingsModel) {
        settingsModel?.let { TimetableStyleMapping.weekViewStyle(it) } ?: WeekViewStyle()
    }
    // 周次钳制复用模型层判据（Dart `clampWeek`，domain/timetable_layout.dart:23-27），不重写。
    val currentWeek = clampCurrentWeekToSettings(snapshot.currentWeek.toLong(), settings).toInt()
    val visibleDays = remember(resolvedDisplay.hideWeekends) {
        TimetableHostLogic.visibleDayNumbers(resolvedDisplay.hideWeekends)
    }
    // 课表课时数据 + 考试 + 日程：周网格的考试/日程落格卡要用（Dart `_agendaEntriesFor`）。
    // 考试不在 `TimetableSnapshot` 里（各自仓储），从 `repository.exams` 现取。
    val exams = repository.exams
    val scheduleItems = snapshot.scheduleItems
    // 「此刻」按分钟粒度前移：只 `remember(snapshot)` 取一次的话，首页常驻跨零点后
    // 「今天」高亮 / 「回本周」入口 / 考试过期判定会一直停在昨天。Dart 侧周视图每次
    // 构建都重读 `DateTime.now()`（`timetable_screen.dart:1404`/`:1429`/`:1438`），
    // 日视图心跳按日内分钟数节流（同文件 `:559-574`）；节流判据收敛在
    // [TimetableDateLogic.homeClockShouldAdvance]（模型层，可单测）。
    var now by remember(snapshot) { mutableStateOf(LocalDateTime.now()) }
    LaunchedEffect(snapshot) {
        while (isActive) {
            delay(1000L)
            val fresh = LocalDateTime.now()
            if (!TimetableDateLogic.homeClockShouldAdvance(now, fresh)) continue
            val previousDate = now.toLocalDate()
            now = fresh
            // 跨日把「当前周」写回仓储，补齐 Dart 时间上下文刷新的日历部分
            //（`timetable_provider.dart:3271-3287`：`didChangeWeek` 时才夹到学期内写回）。
            // 幂等：只在与本帧快照不同才调；写失败由壳回调吞掉并每分钟重试一次，
            // 不影响渲染 —— 不新增仓储 API，也不碰 `TimetableStore`。
            if (fresh.toLocalDate() != previousDate) {
                val commitWeek = TimetableDateLogic.weekToCommitOnDayChange(
                    semesterStart = settings.semesterStartDate?.toLocalDate(),
                    totalWeeks = settings.semesterWeekCount,
                    today = fresh.toLocalDate(),
                    currentWeek = snapshot.currentWeek,
                    clamp = repository::clampWeekToSettings,
                )
                if (commitWeek != null) runCatching { onWeekChanged(commitWeek) }
            }
        }
    }

    // ── 假期判定（P1-7）──
    // Dart 周网格每列都问 `provider.isHoliday(date)`（`timetable_day_column.dart:76`）。
    // 数据在 HolidayPreferences（官方年度缓存 + 自定义条目），与 IcsExportHost 同一来源。
    val appContext = LocalContext.current.applicationContext

    // ── 情侣课表叠加开关（发布版顶栏爱心，`timetable_screen.dart:1036-1059`）────────
    // 存档键 `coupleTimetableOverlayEnabled`（默认 false，`timetable_settings.dart:805`）：
    // 默认关，点一下爱心才把对方课叠进来，再点关掉。渲染判据与发布版同一条
    // `_isCoupleOverlayActive = _coupleOverlayEnabled && hasPartnerBinding`（`:517`），
    // 存档开关在这里**真正生效**——修前 `CoupleOverlaySource` 只按绑定判断，
    // 绑了就一直叠、页面里也没有开关。
    //
    // 本地状态先翻（乐观），落盘失败 toast「保存失败」并翻回去：发布版是乐观不回退
    //（`_persistCoupleOverlayEnabled`，`:1574-1600` 只 toast）；这里多退一步，避免界面
    // 停在一个「看着开了、其实没存上」的假态。
    val storedOverlayEnabled = settingsModel?.coupleTimetableOverlayEnabled ?: false
    var coupleOverlayEnabled by remember(settingsModel) { mutableStateOf(storedOverlayEnabled) }
    fun setCoupleOverlayEnabled(enabled: Boolean) {
        coupleOverlayEnabled = enabled
        runCatching {
            // 合并写：只覆盖这一个键，盘上 Dart 侧 250+ 键与活动档案内嵌投影都保留。
            repository.updateSettingsPatch(mapOf("coupleTimetableOverlayEnabled" to enabled))
        }.onFailure {
            coupleOverlayEnabled = !enabled
            Toast.makeText(appContext, SettingsStringsExt2.saveFailed.text, Toast.LENGTH_SHORT).show()
        }
    }
    val coupleOverlay = if (previewMode || !coupleOverlayEnabled || !hasPartnerBinding) {
        null
    } else {
        loadedCoupleOverlay
    }

    // ── 首页「待更新」检查（发布版 `_scheduleUpdateCheckIfNeeded`/`_runUpdateCheck`）──
    // 结果驱动三处提示：顶栏「更多」红点、八宫格「更新」瓷贴角标、列表档「更新」行提示。
    // 预览（外观编辑页缩尺预览）不跑网络检查。
    val hasAvailableUpdate = rememberHomeUpdateAvailability(enabled = !previewMode)
    val holidayPrefs = remember(appContext) { HolidayPreferences(PrefsKeyValueStore(appContext)) }

    // ⚠️ 假期这块必须**跟着变**（2026-11-05 修）：节假日两个设置页是**另一个宿主**
    // （`SettingsHolidayHost`），它改的是 prefs（`custom_holidays` / `holiday_data_<year>` /
    // `timetable_settings`），而壳没把那份 `HolidayProvider` 实例传到本宿主来，所以这里
    // 直接订阅**同一个 SharedPreferences 文件**：命中这三类键就把 revision 加一，
    // 下面几处 `remember` 随之重读。
    // 修前实测：加/改/删自定义假期后，已挂载的周视图要重启才更新；且「今天放假」被写死 false。
    var holidayRevision by remember { mutableIntStateOf(0) }
    val holidayScope = rememberCoroutineScope()
    DisposableEffect(appContext) {
        val preferences = appContext.getSharedPreferences(PrefsKeyValueStore.PREFS_NAME, Context.MODE_PRIVATE)
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, physicalKey ->
            val logical = physicalKey?.let { FrozenValueCodec.logicalKey(it) }
                ?: return@OnSharedPreferenceChangeListener
            val relevant = logical == HolidayPreferences.CUSTOM_HOLIDAYS_KEY ||
                logical.startsWith(HolidayPreferences.DATA_KEY_PREFIX) ||
                logical == TimetableStore.KEY_SETTINGS
            // 回调线程 = 真正的写入线程（设置页在 IO 上写），Compose 状态必须回主线程改。
            if (relevant) holidayScope.launch { holidayRevision++ }
        }
        preferences.registerOnSharedPreferenceChangeListener(listener)
        onDispose { preferences.unregisterOnSharedPreferenceChangeListener(listener) }
    }

    val holidayMarkingEnabled = settingsModel?.enableHolidayMarking ?: true
    // 「今天放假」覆盖（`timetable_settings.holidayOverrideEnabled`）：与月视图 / 桌面卡片 /
    // 自检页同一份真值（读侧缺键或坏值 = false，口径见 `MonthHolidaySettings`）。
    // 修前这里是写死的 `false`，于是同一个开关在月视图生效、周视图永远不生效。
    val holidayOverrideEnabled = remember(repository, holidayRevision) {
        runCatching { MonthHolidaySettings.fromSettingsJson(repository.settingsJson()).overrideEnabled }
            .getOrDefault(false)
    }
    val holidayOfficialByYear = remember(holidayPrefs, holidayRevision) { mutableMapOf<Int, HolidayData?>() }
    val customHolidays = remember(holidayPrefs, holidayRevision) {
        runCatching { holidayPrefs.loadCustomHolidays() }.getOrNull().orEmpty()
    }
    val semesterStart = settings.semesterStartDate?.toLocalDate()
    val holidayOf: (week: Int, dayOfWeek: Int) -> Boolean = { week, dayOfWeek ->
        val date: LocalDate? = TimetableDateLogic.dateForWeekDay(semesterStart, week, dayOfWeek)
        if (date == null) {
            false
        } else {
            val official = holidayOfficialByYear.getOrPut(date.year) {
                runCatching { holidayPrefs.loadYear(date.year) }.getOrNull()
            }
            WeekHolidayMarking.isHoliday(
                date = date,
                official = official,
                custom = customHolidays,
                // 真值来自 `timetable_settings.holidayOverrideEnabled`（见上），不再写死。
                overrideEnabled = holidayOverrideEnabled,
                markingEnabled = holidayMarkingEnabled,
            )
        }
    }

    // ── 天气（P1-11 课卡天气行；provider 是 addListener 那套，用计数触发重组）──
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
    val weatherOf: ((week: Int, dayOfWeek: Int, Course) -> String?)? = remember(
        weatherProvider, weatherTick, settingsModel, settings, snapshot,
    ) {
        val provider = weatherProvider
        if (provider == null || settingsModel?.weatherShowOnWeekCard == false) {
            null
        } else {
            val showPhenomenon = settingsModel?.weatherShowPhenomenon ?: true
            val showTemperature = settingsModel?.weatherShowTemperature ?: true
            val showProbability = settingsModel?.weatherShowProbability ?: false
            val start = settings.semesterStartDate?.toLocalDate()
            val lookup: (Int, Int, Course) -> String? = { week, dayOfWeek, course ->
                val date = TimetableDateLogic.dateForWeekDay(start, week, dayOfWeek)
                val occurrence = repository.dateForCourseOccurrence(course, week)
                when {
                    // Dart `timetable_home_page_assembly.dart:456`：停课周（及单双周错位、
                    // 尚未开课的周）这节并不上，挂那天的天气会让人误以为要带伞——是
                    // 整行不挂，不是挂空值。
                    !course.isActiveInWeek(week) -> null
                    date == null || occurrence == null -> null
                    else -> provider.summaryForCourse(occurrence, course.startTime, course.endTime)?.let { summary ->
                        TimetableStrings.formatWeatherLine(
                            phenomenon = WeatherStrings.categoryLabel(summary.category),
                            temperatureC = summary.temperatureC,
                            probability = summary.precipitationProbability,
                            showPhenomenon = showPhenomenon,
                            showTemperature = showTemperature,
                            showProbability = showProbability,
                        )
                    }
                }
            }
            lookup
        }
    }

    // ── 首页壁纸背景 + 材质 + 顶栏墨色（Dart `lib/utils/home_page_background.dart` 那整条链）──
    // 三样东西的推导只在 [rememberHomeBackdropChrome] 一份：日视图走同一条路，
    // 写两遍必然漂（2026-11-01 之前日视图就是纯色底，正是因为这里没有共用点）。
    val homeChrome = rememberHomeBackdropChrome(settingsModel)
    // 「回本周」浮钮的底边距：按玻璃坞药丸的真实占用算（见 `HomeFloatingMetrics`）。
    // 以前页面写死 72dp，手势导航下正好落在药丸里 —— 用户报的「按钮在导航栏底下」。
    val floatingInsets = rememberHomeFloatingInsets(settingsModel)

    // ── 「分享当前视图的干净课表图」的组装（2026-11-03）──────────────────────
    // 截屏提示与顶栏菜单「分享课表图片」两个入口共用这一份（Dart 同一条
    // `_shareTimetableImage`：dayOfWeek 为 null ⇒ 周图，绝不出第二份导图逻辑）。
    // week 取调用方给的「用户正看着的周」：截屏提示由页面给 pager 落定周，
    // 菜单动作这里用仓储当前周（翻页落定时 onWeekChanged 已写回；菜单「先收完
    // 再执行」的时序下两者一致——Dart `_visibleWeek` 是屏层直接持有，无此差）。
    fun shareCurrentView(week: Int, dayOfWeek: Int?) {
        shareTimetableImage(
            context = appContext,
            doc = if (dayOfWeek == null) {
                TimetableShareRequests.weekDocument(
                    courses = snapshot.courses,
                    week = week,
                    settings = settings,
                    style = style,
                    visibleDays = visibleDays,
                    today = LocalDate.now(),
                )
            } else {
                TimetableShareRequests.dayDocument(
                    courses = snapshot.courses,
                    week = week,
                    dayOfWeek = dayOfWeek,
                    settings = settings,
                    showNonCurrentWeekCourses = style.showNonCurrentWeekCourses,
                )
            },
            exportWidthDp = TimetableShareImageModel.exportWidthDp(
                appContext.resources.displayMetrics.widthPixels /
                    appContext.resources.displayMetrics.density,
            ),
        )
    }

    // 顶栏「更多」菜单条目补挂：壳的过滤只认「有页面去处」的 id（`homeTopMenuItems`），
    // 「分享课表图片」不是推页动作会被滤掉——用户排列里显式加过它时在这里补挂
    // （判据在 [TimetableHostLogic.shouldAppendShareTimetableEntry]，JVM 单测钉住；
    // 图标/文案走 [HomeNavIcons] 与底栏/全部功能页同一份解析，零新增文案）。
    // 追加位置在列表末尾：壳过滤时已丢掉它在用户排列里的原位，这里是补偿不是复刻。
    val menuItemsWithShare = remember(homeMenuItems, settingsModel?.homeGridMenuActions) {
        val wantsShare = TimetableHostLogic.shouldAppendShareTimetableEntry(
            itemIds = homeMenuItems.mapTo(mutableSetOf()) { it.id },
            homeGridMenuActions = settingsModel?.homeGridMenuActions.orEmpty(),
        )
        if (wantsShare) {
            homeMenuItems + HomeNavIcons.menuItem(TimetableHostLogic.SHARE_TIMETABLE_MENU_ID)
        } else {
            homeMenuItems
        }
    }

    // 顶栏附加状态（爱心 / 待更新）用 CompositionLocal 注入给所有共用
    // [TimetableTopBar] 的视图：周 / 日 / 月三处调用点不必各自加参数转发
    //（漏一处就漂），页面层也不认识仓储与设置。
    CompositionLocalProvider(
        LocalTimetableHomeTopBarState provides TimetableHomeTopBarState(
            hasAvailableUpdate = hasAvailableUpdate,
            coupleOverlayAvailable = hasPartnerBinding,
            coupleOverlayEnabled = coupleOverlayEnabled,
            onToggleCoupleOverlay = { setCoupleOverlayEnabled(!coupleOverlayEnabled) },
        ),
    ) {
    TimetableWeekPage(
        courses = snapshot.courses,
        // 情侣叠加（B1 第二阶段）：绑定且对方档有课时非空，周视图据此把 TA 课叠进来。
        coupleOverlay = coupleOverlay,
        timeScheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = snapshot.timeSchemes,
            activeTimeSchemeId = snapshot.activeTimeSchemeId,
        ),
        settings = settings,
        style = style,
        profileName = TimetableHostLogic.resolveProfileName(
            profiles = snapshot.profiles,
            activeProfileId = snapshot.activeProfileId,
        ),
        currentWeek = currentWeek,
        totalWeeks = settings.semesterWeekCount,
        initialWeek = currentWeek,
        visibleDays = visibleDays,
        exams = exams,
        scheduleItems = scheduleItems,
        now = now,
        onCourseClick = onOpenCourse,
        holidayOf = holidayOf,
        weatherOf = weatherOf,
        // 长按空白格加课：Dart 判据是「开关打开 + 这一格要有跨度」
        // （`timetable_empty_slot_layer.dart:46`），开关本身由 style 下传，页面只在
        // 开关开着时才装长按手势。
        //
        // 三参跨度（[onOpenAddCourseSpan] 的 end）本轮**还不从页面回传**：
        // `TimetableWeekPage` 的签名本周由成员十四改、网格手势由成员八改，宿主这里
        // 先把两参行为保持住（end = start）；等页面暴露 span 回调后改成
        // `{ d, s, e -> (onOpenAddCourseSpan ?: { d2, s2, _ -> onOpenAddCourse(d2, s2) })(d, s, e) }`，
        // 一行接通、壳调用点不用动。
        onLongPressEmptySlot = { dayOfWeek, section -> onOpenAddCourse(dayOfWeek, section) },
        onAgendaClick = onAgendaClicked,
        // 首页「周 ↔ 日」展开态（2026-11-02）：不再把日视图当成一页推出去。
        dayMode = homeViewMode == TimetableHomeViewMode.DAY,
        selectedWeek = selectedWeek,
        selectedDayOfWeek = selectedDayOfWeek,
        dayProgressSeed = dayProgressSeed,
        daySwitchAnimate = daySwitchAnimate,
        daySwitchHorizontal = daySwitchHorizontal,
        // 月视图过渡的叠加门（2026-11-12）：壳侧接 `pagerState.isScrollInProgress`；
        // 不接线时默认 false = 只按 daySwitchAnimate 判断，行为与今天一致。
        homePagerScrolling = homePagerScrolling,
        onSelectDay = onSelectDay,
        onCloseDay = onCloseDay,
        dayContent = dayContent,
        monthMode = monthMode,
        monthLabel = monthLabel,
        monthSelectedDate = monthSelectedDate,
        monthContent = monthContent,
        weekScrollWrapper = weekScrollWrapper,
        transitionSpeed = transitionSpeed,
        onSwitchProfileClick = onSwitchProfile,
        onWeekChanged = onWeekChanged,
        // 标题样式取自用户存档（Dart `homeTitleStyle`，:1478 默认 classic）。
        homeTitleStyle = settingsModel?.homeTitleStyle ?: HomeTitleStyle.CLASSIC,
        // 菜单形态取自用户存档（Dart `homeMenuStyle`，:1489 默认 list）；壳没传就走默认。
        homeMenuStyle = settingsModel?.homeMenuStyle ?: HomeMenuStyle.LIST,
        homeMenuItems = menuItemsWithShare,
        // 顶栏菜单「分享课表图片」在宿主拦截（Dart timetable_screen.dart:966-968 同口径：
        // 分享要带「当前可见周」与周/日视图，只有首页这一层知道，不走壳的推页映射）。
        // 周视图分享仓储当前周（翻页落定时已写回，见 shareCurrentView 注释）；日视图
        // 分享正看着的那一天。条目可见性见 [menuItemsWithShare] 的补挂判据。
        onHomeMenuSelect = { id ->
            if (id == TimetableHostLogic.SHARE_TIMETABLE_MENU_ID) {
                if (homeViewMode == TimetableHomeViewMode.DAY) {
                    shareCurrentView(selectedWeek, selectedDayOfWeek)
                } else {
                    shareCurrentView(currentWeek, null)
                }
            } else {
                onHomeMenuSelect(id)
            }
        },
        // 壁纸层：页面画在内容最底下，并据此把底色改透明。
        backdrop = homeChrome.backdrop,
        // 壁纸上的顶栏墨色（深壁纸 ⇒ 浅墨）。null = 没壁纸 / 亮度还没测出来 ⇒ 主题墨色。
        chromeInk = homeChrome.chromeInk,
        // 壁纸三档亮度带：星期栏 / 时间列压在壁纸上的字色靠它翻深/翻浅（2026-11-01）。
        wallpaperBands = homeChrome.bands,
        // 材质快照（2026-11-01）：让「默认材质 / 顶栏玻璃 / 八根旋钮」真正落到屏幕上。
        material = if (glassSurfacesEnabled) homeChrome.material else null,
        hasBackdrop = glassSurfacesEnabled && homeChrome.hasBackdrop,
        pageColorArgb = homeChrome.pageColorArgb,
        // 浮钮避让（玻璃坞形态 = 药丸占用 + 12；经典形态 = 24 + 系统手势条）。
        floatingButtonBottomInset = floatingInsets.buttonBottom,
        // 截屏提示：宿主意愿 × 用户存档开关（Dart `_syncScreenshotListener` 读
        // `settings.screenshotSharePromptEnabled` 同口径）。存档没接（null）按关处理。
        screenshotSharePromptEnabled =
            screenshotSharePromptEnabled && settingsModel?.screenshotSharePromptEnabled == true,
        // 截屏提示「分享」按钮的动作（2026-11-03 导出链路落地）：页面给「用户正看着的
        // 周 / 日」，组装与发起走 [shareCurrentView]——与顶栏菜单「分享课表图片」
        // 同一份（Dart `_shareTimetableImage` 同口径——截屏提示直接分享当前视图的图，
        // 没有中间面板）。dayOfWeek = null ⇒ 周图。
        onShareScreenshot = { week, dayOfWeek -> shareCurrentView(week, dayOfWeek) },
        previewMode = previewMode,
        previewAllowsDaySwitch = previewAllowsDaySwitch,
        previewSectionBasisDp = previewSectionBasisDp,
    )
    }
}
