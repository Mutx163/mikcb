package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.R
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.diagnostics.DEFAULT_FIXTURE_LEAD_MINUTES
import com.mutx163.qingyu.pages.diagnostics.LiveFixtureActions
import com.mutx163.qingyu.pages.diagnostics.LiveFixtureMessages
import com.mutx163.qingyu.pages.diagnostics.LiveTestingFixtureHost as FixtureHostPort
import com.mutx163.qingyu.pages.diagnostics.LiveTestingFixturePage
import com.mutx163.qingyu.pages.diagnostics.buildLiveFixtureViewState
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.widgetdata.MILESTONE_RECENT_END_LABEL_KEY
import com.mutx163.qingyu.widgetdata.SectionTimeData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDateTime

/**
 * 临时测试课程页的**真实宿主**（取代壳里 `sections = emptyList() / courses = emptyList()`
 * 那份空数据 + 四个空回调 ⇒ 装了/清了都没动静）。
 *
 * 源：`lib/screens/live_testing_fixture_screen.dart`（395 行）+
 * `lib/services/live_testing_fixture_service.dart`（481 行）。
 *
 * ## 四个交互的落点
 *
 * | 页面交互 | Dart | 本宿主 |
 * |---|---|---|
 * | 安装 24 时段测试课表 | `_installQuickFixtureGrid`（:209-250）→ `installSectionGrid` | [LiveFixtureActions.installGrid]：清旧夹具 → 套 24 段整点节次 → 每节一门夹具课，一次落盘 |
 * | 清除测试课表 | `_clearQuickFixtureGrid`（:252-284）→ `removeAllFixtureCourses` | [LiveFixtureActions.clear]：**只删 `live_test_` 前缀**，用户真课原样保留（单测反向验证过） |
 * | 课前提醒档位 | `HyperosSegmentedControl`（:106-114） | 页面内 state（[leadMinutes]），只影响触发时的提前量 |
 * | 触发某节 / 当前节 / 下一节 | `_triggerQuickFixtureSlot`（:286-312） | [LiveFixtureActions.upsertTimed] 真写一门「N 分钟后上课」的夹具课 → [LiveTestTrigger.productionRefresh]（快照同步 + reschedule，岛按课前提醒设置弹出） |
 *
 * ## 数据全来自仓储真快照
 *
 * 节次表 = `snapshot.settings.sections`，课程 = `snapshot.courses`，当前方案名 =
 * `snapshot.timeSchemes` 里 `id == activeTimeSchemeId` 的那条。仓储 `observe` 一变就重组，
 * 所以装完课页面立刻显示「已装 / 已装 24 门」。
 *
 * ## 未完成（不假装）
 *
 * **24 时段方案条目**：仓储有 `createTimeScheme/applyTimeScheme` 可补，但本批没接——
 * 装网格只套**节次表**（[RepositoryFixtureHost.applySections]），方案列表里不会多出
 * 「超级岛测试24时段」那条。效果上「左栏时间与课程对得上」已达成，
 * 仍登记在 `.agents/compose-phase3/claims/_DIAG-settings-fixture-gaps.md`。
 *
 * @param repository 课表仓储（壳里是 `wiring.timetable`）
 * @param onBack 返回
 */
@Composable
fun LiveTestingFixtureHost(
    repository: TimetableRepository,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    /** 仓储变更计数：只为触发重组（值本身不参与渲染）。 */
    var version by remember(repository) { mutableStateOf(0) }
    /** 当前「课前提醒」档位（Dart `_fixtureLeadMinutes` 默认 1）。 */
    var leadMinutes by remember { mutableStateOf(DEFAULT_FIXTURE_LEAD_MINUTES) }
    var installing by remember { mutableStateOf(false) }
    var clearing by remember { mutableStateOf(false) }
    /**
     * 「现在几点」：Dart 只在页面重建时取 `DateTime.now()`，页面停着不动「当前节次」
     * 就会一直是进页面那一刻的。这里每 30 秒推一次（只在诊断页跑，成本可忽略）。
     */
    var now by remember { mutableStateOf(LocalDateTime.now()) }

    DisposableEffect(repository) {
        val subscription = repository.observe { version++ }
        onDispose { subscription.close() }
    }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            now = LocalDateTime.now()
        }
    }
    // 建立对 version 的读取，供重组订阅。
    @Suppress("UNUSED_EXPRESSION")
    version

    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun detailOf(error: Throwable): String =
        (error as? IllegalStateException)?.message ?: error.toString()

    val fixtureHost = remember(repository) { RepositoryFixtureHost(repository) }

    // 生产刷新宿主：写完测试课后把仓储整份同步给原生并立即重排（岛按课前提醒弹出）。
    // 壳没有 Dart 通道，快照由 LiveNativeSnapshotBuilder 现造——这是触发管线迁完的标志。
    val triggerStore = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }
    val productionTrigger = remember(context, repository, triggerStore) {
        LiveTestTrigger(
            context = context,
            repository = repository,
            settingsJson = { triggerStore.loadSettingsJson() },
            localizeMilestone = { key ->
                context.getString(
                    if (key == MILESTONE_RECENT_END_LABEL_KEY) {
                        R.string.milestone_recent_end
                    } else {
                        R.string.milestone_next_start
                    },
                )
            },
        )
    }

    val snapshot = repository.snapshot
    val viewState = buildLiveFixtureViewState(
        sections = snapshot.settings.sections.map(LiveFixtureActions::toSectionTimeData),
        courses = snapshot.courses,
        activeSchemeName = snapshot.activeTimeSchemeId
            ?.let { id -> snapshot.timeSchemes.firstOrNull { it.id == id }?.name },
        now = now,
        leadMinutes = leadMinutes,
        isInstalling = installing,
        isClearing = clearing,
    )

    fun install() {
        if (installing) return
        installing = true
        val startedAt = LocalDateTime.now()
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val settings = repository.snapshot.settings
                    LiveFixtureActions.installGrid(
                        host = fixtureHost,
                        now = startedAt,
                        semesterWeekCount = settings.semesterWeekCount,
                    )
                }
            }
            installing = false
            result
                .onSuccess { count ->
                    // Dart :222-224：方案名优先取当前激活方案，取不到才用测试方案名。
                    val schemeName = repository.snapshot.activeTimeSchemeId
                        ?.let { id -> repository.snapshot.timeSchemes.firstOrNull { it.id == id }?.name }
                        ?: LiveFixtureActions.TIME_SCHEME_NAME
                    showToast(
                        LiveFixtureMessages.installed(schemeName, count, startedAt.dayOfWeek.value),
                    )
                }
                .onFailure { showToast(LiveFixtureMessages.installFailed(detailOf(it))) }
        }
    }

    fun clear() {
        if (clearing) return
        clearing = true
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching { LiveFixtureActions.clear(fixtureHost) }
            }
            clearing = false
            result
                .onSuccess { count -> showToast(LiveFixtureMessages.cleared(count)) }
                .onFailure { showToast(LiveFixtureMessages.clearFailed(it.toString())) }
        }
    }

    fun trigger(sectionNumber: Int, @Suppress("UNUSED_PARAMETER") source: String) {
        // Dart `triggerLiveUpdateTestForSectionSlot` 两步：先写测试课（只挪钟点），
        // 再走生产刷新（快照同步 + reschedule，有课在窗立即起岛）。两步都真做。
        val lead = leadMinutes.toLong()
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    LiveFixtureActions.upsertTimed(
                        host = fixtureHost,
                        sectionNumber = sectionNumber,
                        now = LocalDateTime.now(),
                        leadMinutes = lead,
                    )
                    // 刷新失败按触发失败上报：课已改好但岛没接管，不能报成功。
                    productionTrigger.productionRefresh()
                }
            }
            result
                .onSuccess { showToast(LiveFixtureMessages.triggered(sectionNumber, lead)) }
                .onFailure { showToast(LiveFixtureMessages.triggerFailed(detailOf(it))) }
        }
    }

    LiveTestingFixturePage(
        viewState = viewState,
        onBack = onBack,
        onInstall = { install() },
        onClear = { clear() },
        onSelectLead = { minutes -> leadMinutes = minutes },
        onTriggerSection = { sectionNumber, source -> trigger(sectionNumber, source) },
    )
}

/**
 * [FixtureHostPort] 在 [TimetableRepository] 上的实现（Dart `LiveFixtureProviderAccess`
 * 的 Kotlin 对应物，`lib/providers/live_testing_fixture_access.dart`）。
 *
 * 成员一律一行转发：装课/清空的**时序**（先清旧、再套节次、再写入）全在
 * [LiveFixtureActions] 里，这里只回答「怎么落到仓储」。
 */
private class RepositoryFixtureHost(
    private val repository: TimetableRepository,
) : FixtureHostPort {

    override fun courses(): List<Course> = repository.snapshot.courses

    override fun settings(): TimetableSettings = repository.snapshot.settings

    override fun addCourse(course: Course) {
        repository.addCourse(course)
    }

    override fun updateCourse(course: Course) {
        repository.updateCourse(course)
    }

    /**
     * 一次性替换活动档案的课程（保留作业 / 考试 / 日程）。
     *
     * 为什么不是逐条 `deleteCourse` / `addCourse`：Dart 装课走 `importParsedCourses`
     * （一次写一次通知），逐条写 24 门会让界面闪 24 次，也会让「清空只删夹具课」
     * 这条硬要求散落在调用点的循环里，单测钉不住。
     */
    override fun replaceCourses(courses: List<Course>) {
        repository.replaceActiveProfileContent(
            courses = courses,
            tasks = repository.tasks,
            exams = repository.exams,
        )
    }

    /**
     * 把节次表套进当前设置（Dart `applyTimeScheme` 的节次部分）。
     *
     * 与 Dart 的差异：Dart 会先创建/更新名叫「超级岛测试24时段」的方案、再把
     * `activeTimeSchemeId` 指过去。Kotlin 仓储只有 `updateSettings`，
     * 没有方案写入口 ⇒ 这里**只写 `sections`，不动 `activeTimeSchemeId`**。
     *
     * 为什么不动方案 id：把它指向一个不存在的方案会让「按方案解析节次」这条路悬空；
     * 保持原 id 至少让用户原来的方案还在，之后在作息方案页重新套用一次就恢复原状。
     *
     * 节次表已经一致时不写盘（避免每次装课都无谓落一次）。
     */
    override fun applySections(sections: List<SectionTimeData>) {
        val current = repository.snapshot.settings
        val next = sections.map { SectionTime(startTime = it.startTime, endTime = it.endTime) }
        if (current.sections == next) return
        repository.updateSettings(current.copy(sections = next))
    }
}
