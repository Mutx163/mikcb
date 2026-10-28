package com.mutx163.qingyu.pages

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.app.CourseActionDispatcher
import com.mutx163.qingyu.app.CourseActionOutcome
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableHost
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSaveDispatcher
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.course.AddCourseSavePayload
import com.mutx163.qingyu.pages.course.CourseActionSheet
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModule
import com.mutx163.qingyu.platform.PrefsKeyValueStore

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
     * 从课程操作弹层点「加作业」时要带进作业页的预选课程（T1）。
     *
     * 与 [pendingEditCourse] 同生命周期：都是「跨子树传一次、用完即清」的意图载体。
     */
    var pendingTaskCourse: Course? = null

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
        val target = TimetableSaveDispatcher.resolveDeleteTarget(
            originalGroupName = null,
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
 * ## 失败不假装成功
 *
 * `NotWired`（例如「单节课提醒」本机没有调度能力）弹真实原因，**不静默关掉**——
 * 静默关掉正是「点了没反应」的另一种形态。
 */
@Composable
fun TimetableWithCourseActions(
    wiring: ShellWiring,
    onNavigate: (String) -> Unit,
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

    TimetableHost(
        repository = repository,
        onOpenAddCourse = { dayOfWeek, section ->
            wiring.pendingAddCourseSeed = dayOfWeek to section
            wiring.pendingEditCourse = null
            onNavigate("d1.addCourse")
        },
        // T1：点课程 → 先弹操作层，不直接进编辑页。
        onOpenCourse = { course -> actionTarget = course },
        onOpenProfiles = { onNavigate("c1.profiles") },
        onOpenAddCoursePlain = {
            wiring.clearAddCourseIntent()
            onNavigate("d1.addCourse")
        },
        onWeekChanged = { repository.setCurrentWeek(it) },
        // S1：显示偏好改从**用户存档**读，不再吃宿主默认值。
        // ⚠️ 这里每次重组都会 `load()` 一次——设置存储没有变更通道（见交付方诚实清单第 2 条）。
        // 验收路径（杀进程重开 / 离开再回课表）都拿得到新值；「课表页正开着时后台改设置」
        // 不会自刷，但本 App 里不存在这种同屏场景。
        settingsModel = wiring.settingsModel.load(),
    )

    val course = actionTarget
    CourseActionSheet(
        course = course,
        week = week,
        onDismiss = { actionTarget = null },
        onAction = { action ->
            if (course == null) {
                actionTarget = null
            } else {
                when (val outcome = CourseActionDispatcher.dispatch(action, course, week, repository)) {
                    is CourseActionOutcome.OpenEdit -> {
                        // 带**同一门课**进编辑页（参数透传，别丢）。
                        wiring.pendingEditCourse = outcome.course
                        wiring.pendingAddCourseSeed = null
                        actionTarget = null
                        onNavigate("d1.addCourse")
                    }
                    is CourseActionOutcome.OpenAddTask -> {
                        wiring.pendingTaskCourse = outcome.course
                        actionTarget = null
                        onNavigate("d2.addTask")
                    }
                    is CourseActionOutcome.NotWired -> {
                        Toast.makeText(context, outcome.reason, Toast.LENGTH_SHORT).show()
                        actionTarget = null
                    }
                    // 删除 / 停课 / 调课：分派器已经写库并通知，宿主会自己重组。
                    else -> actionTarget = null
                }
            }
        },
        onReschedule = { targetWeek, day, start, end ->
            if (course != null) {
                CourseActionDispatcher.rescheduleOccurrence(
                    port = repository,
                    courseId = course.id,
                    sourceWeek = week,
                    targetWeek = targetWeek,
                    targetDayOfWeek = day,
                    targetStartSection = start,
                    targetEndSection = end,
                )
            }
            actionTarget = null
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
    "/settings/semester" -> "b.semester"
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
