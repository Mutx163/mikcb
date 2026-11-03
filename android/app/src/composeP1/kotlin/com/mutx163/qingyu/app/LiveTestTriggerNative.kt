package com.mutx163.qingyu.app

import android.app.Activity
import android.content.Context
import android.os.Build
import com.mutx163.qingyu.LiveUpdateScheduler
import com.mutx163.qingyu.LiveUpdateService
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.pages.live.LiveCourseTestSession
import com.mutx163.qingyu.pages.live.LiveCourseTestSessions
import com.mutx163.qingyu.pages.live.LiveCourseTestStage
import com.mutx163.qingyu.pages.live.LiveCurrentCourseSource
import com.mutx163.qingyu.pages.live.LiveDisplayState
import com.mutx163.qingyu.pages.live.LiveNativeSnapshotBuilder
import com.mutx163.qingyu.pages.live.buildCourseTestPayload
import com.mutx163.qingyu.pages.live.buildCourseTestWindow
import com.mutx163.qingyu.pages.live.computeTestSessionSettingsSignature
import com.mutx163.qingyu.pages.live.resolveLivePreviewTestCourse
import com.mutx163.qingyu.pages.live.resolveNextCourseForTest
import com.mutx163.qingyu.widgetdata.LiveActivityLogicData
import com.mutx163.qingyu.widgetdata.SectionTimeData
import com.mutx163.qingyu.widgetdata.WidgetDataClock
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 试弹管线的 **Context 侧宿主**（Dart `MiuiLiveActivitiesService` 的 Kotlin 对应物）。
 *
 * 纯逻辑（窗口合成 / 载荷构造 / 会话槽 / 选课）都在 `pages/live/LiveCourseTestTrigger.kt`；
 * 本类只做碰系统的那几件事：
 *
 * | Dart | 本类 |
 * |---|---|
 * | `suspendScheduleTriggers(until)`（通道） | [LiveUpdateScheduler.suspendScheduleTriggers]（同进程直调） |
 * | `startLiveUpdate`（通道 → MainActivity 组 Intent 起服务） | [dispatchPayloadAwaitingNotification]（直接组 Intent，等「通知已交给系统」回执再返回） |
 * | `stopLiveUpdate` | [LiveUpdateScheduler.stopRunningLiveUpdate] + 重排正式调度 |
 * | `refreshLiveActivityNow(forceSnapshotSync)` | [productionRefresh]（壳自建整份快照 + reschedule） |
 * | `moveTaskToBack`（通道） | [moveTaskToBack]（宿主 Activity 直调） |
 *
 * ## 为什么起服务要等回执
 *
 * 岛由 [LiveUpdateService] 在主线程发通知，HyperOS 只在 App **退后台**后才把它浮成
 * 超级岛。若起完服务立刻 `moveTaskToBack`，进程组被冻结时通知可能还没发出去——
 * 真机实测会「点了测试，岛很久才弹」（MainActivity 同款问题的同款解法）：
 * 先挂 [LiveUpdateService.awaitNotificationPosted] 回执、超过
 * [NOTIFICATION_ACK_TIMEOUT_MILLIS] 兜底放行，把「发通知」锁在 App 仍在前台的窗口里。
 *
 * ## 快照从哪来
 *
 * 正式路径（生产刷新 / 取消后接管）里，`reschedule` 从原生快照选课。纯 Compose 壳
 * 没有 Dart 通道，盘上从来没有过带课程的快照——[productionRefresh] 用
 * [LiveNativeSnapshotBuilder] 从仓储现造一份再 `syncSnapshot`，这是壳自己的数据源
 * （`TimetableSnapshot`），不依赖任何 Dart 侧遗产。
 */
class LiveTestTrigger(
    private val context: Context,
    private val repository: TimetableRepository,
    private val settingsJson: () -> Map<String, Any?>,
    private val localizeMilestone: (String) -> String,
) {

    /** 试弹结果（宿主据其挑 toast 文案与按钮态）。 */
    sealed interface Outcome {
        /** 起岛成功；会话已登记，终点后原生自动收岛。 */
        data class Started(val session: LiveCourseTestSession) : Outcome

        /** 已有会话在跑（单槽互斥），拒绝重复触发。 */
        data object InFlight : Outcome

        /** 服务没起来 / 通知未在超时内交出（暂停已回滚，不留死会话）。 */
        data class DispatchFailed(val detail: String) : Outcome
    }

    /**
     * 显示设置页「试弹」：对指定阶段强制起岛约 [sessionLengthMillis]（默认 30 秒）。
     *
     * 智能挑选当前或最近一门课程；课表为空时用自检预设课（只进岛，不写入课表）。
     * 窗口/暂停/载荷与选课测试同路（Dart `triggerLiveStagePreviewTest` 同义）。
     */
    suspend fun startStagePreview(
        forDuringEnd: Boolean,
        display: LiveDisplayState,
        sessionLengthMillis: Long = DEFAULT_PREVIEW_SESSION_MILLIS,
        source: String = "display_settings_preview",
    ): Outcome {
        if (LiveCourseTestSessions.current() != null) return Outcome.InFlight

        val snapshot = repository.snapshot
        val now = LocalDateTime.now()
        val nowMillis = System.currentTimeMillis()
        val stage = if (forDuringEnd) LiveCourseTestStage.DURING_CLASS else LiveCourseTestStage.BEFORE_CLASS

        // 目标课程：优先当前/今天接下来最近的一门（与预览卡同一来源），空表走预设兜底。
        val semesterStart = semesterStartOf(snapshot)
        val calendarWeek = if (semesterStart != null) {
            WeekCalculator.calendarWeekForDate(now, semesterStart, snapshot.currentWeek)
        } else {
            snapshot.currentWeek
        }
        val currentSelection = LiveCurrentCourseSource.resolve(snapshot, now).course
        // 选课自带四条兜底（含空表预设课），总能给出一门目标课。
        val course = resolveLivePreviewTestCourse(
            courses = snapshot.courses,
            calendarWeek = calendarWeek,
            semesterWeekCount = snapshot.settings.semesterWeekCount,
            now = now,
            currentSelection = currentSelection,
        )

        val window = buildCourseTestWindow(nowMillis, stage, sessionLengthMillis)
        val session = LiveCourseTestSession(
            stage = stage,
            courseName = course.name,
            course = course,
            sessionEndMillis = window.endMillis + window.suspendBufferMillis,
            startMillis = window.startMillis,
            endMillis = window.endMillis,
            clockEndMillis = window.clockEndMillis,
            suspendBufferMillis = window.suspendBufferMillis,
            source = source,
        )
        val signature = computeTestSessionSettingsSignature(stage, display)

        // 双路暂停的 Kotlin 侧只剩原生一路（没有 Dart 30s tick）：会话终点前
        // 正式闹钟不得收岛或用真实课覆盖。失败路径必须回滚，否则正式调度被吊死。
        LiveUpdateScheduler.suspendScheduleTriggers(context, session.sessionEndMillis)
        val payload = buildSessionPayload(session, display)
        val dispatched = dispatchPayloadAwaitingNotification(payload)
        if (!dispatched) {
            LiveUpdateScheduler.suspendScheduleTriggers(context, 0)
            return Outcome.DispatchFailed(
                detail = lastDispatchDetail ?: "notification ack timeout",
            )
        }
        LiveCourseTestSessions.install(session, signature)
        return Outcome.Started(session)
    }

    /**
     * 停止试弹：解除暂停并按正式路径重刷（真实课在窗则立即接管）。
     *
     * 顺序敏感：先清会话与暂停，再停服务，最后重排——`reschedule` 见到未过期的
     * 暂停会直接退避（`SUSPENDED`），永远收不了尾。
     */
    suspend fun cancelStagePreview() {
        LiveCourseTestSessions.clear()
        LiveUpdateScheduler.suspendScheduleTriggers(context, 0)
        LiveUpdateScheduler.stopRunningLiveUpdate(context)
        productionRefresh()
    }

    /**
     * 试弹会话进行中、用户改了显示设置时，热更新已在运行中的岛
     * （Dart `hotUpdateLiveCourseTestSession`）。指纹没变 = 无关改动，不重发。
     */
    suspend fun hotUpdateIfSettingsChanged(display: LiveDisplayState): Boolean {
        val session = LiveCourseTestSessions.current() ?: return false
        if (session.course == null || session.startMillis == null || session.endMillis == null) {
            return false
        }
        val signature = computeTestSessionSettingsSignature(session.stage, display)
        if (signature == LiveCourseTestSessions.signature()) return false
        val dispatched = dispatchPayloadAwaitingNotification(buildSessionPayload(session, display))
        if (!dispatched) return false
        LiveCourseTestSessions.updateSignature(signature)
        return true
    }

    /**
     * 正式路径刷新：把仓储现况整份同步给原生（课程 + 设置 + 周次 + 开学日），
     * 然后重排调度——有课在窗立即起岛，否则按下一节课排闹钟。
     *
     * 诊断页「触发某节」（写完测试课后）与试弹取消后的正式接管都走这里，
     * 对应 Dart `triggerLiveUpdateProductionRefresh` 的核心两步。
     */
    fun productionRefresh() {
        val snapshot = repository.snapshot
        val snapshotJson = LiveNativeSnapshotBuilder.buildJson(
            courses = snapshot.courses,
            settingsJson = settingsJson(),
            currentWeek = snapshot.currentWeek,
            semesterStartMillis = semesterStartMillis(snapshot),
        )
        LiveUpdateScheduler.syncSnapshot(context, snapshotJson)
        LiveUpdateScheduler.reschedule(context, allowImmediateStart = true)
    }

    /** 等效按 Home：岛只在桌面/状态栏可见，试弹成功后自动退后台省用户手动按。 */
    fun moveTaskToBack(): Boolean = (context as? Activity)?.moveTaskToBack(true) ?: false

    // ───────────────────────────── 私有 ─────────────────────────────

    /**
     * 由会话重建下发载荷（首次起岛与热更新共用，Dart `_dispatchLiveUpdateForCourseTest`
     * 的统一下发口径）。
     *
     * 课程钟点按会话窗口**现算**：热更新时用户设置已变，但窗口锚点不动。
     */
    private fun buildSessionPayload(
        session: LiveCourseTestSession,
        display: LiveDisplayState,
    ): Map<String, Any> {
        // 不变式：startStagePreview/hotUpdateIfSettingsChanged 都先验过才走到这。
        val course = session.course ?: error("live test session missing course")
        val startMillis = session.startMillis ?: error("live test session missing start")
        val endMillis = session.endMillis ?: error("live test session missing end")
        val clockEndMillis = session.clockEndMillis ?: endMillis
        val zone = ZoneId.systemDefault()
        val displayCourse = course.copy(
            startTime = WidgetDataClock.formatClock(
                java.time.Instant.ofEpochMilli(startMillis).atZone(zone).toLocalDateTime(),
            ),
            endTime = WidgetDataClock.formatClock(
                java.time.Instant.ofEpochMilli(clockEndMillis).atZone(zone).toLocalDateTime(),
            ),
        )
        val nowMillis = System.currentTimeMillis()
        val beforeClassLeadMillis =
            if (session.stage == LiveCourseTestStage.BEFORE_CLASS && startMillis > nowMillis) {
                startMillis - nowMillis
            } else {
                0L
            }

        // 「下一节」与正式路径同一解析规则；只取静态展示字段，不参与时间计算。
        val snapshot = repository.snapshot
        val nextCourse = resolveNextCourseForTest(
            courses = snapshot.courses,
            course = course,
            calendarWeek = calendarWeekOrFallback(snapshot),
        )

        val milestones = LiveActivityLogicData.buildLiveProgressMilestones(
            displayCourse,
            resolveSectionsForCourse(displayCourse),
            startMillis,
            endMillis,
        )
        return buildCourseTestPayload(
            stage = session.stage,
            course = displayCourse,
            nextCourse = nextCourse,
            startMillis = startMillis,
            endMillis = endMillis,
            beforeClassLeadMillis = beforeClassLeadMillis,
            display = display,
            progressBreakOffsetsMillis = milestones.map { it.offsetMillis },
            progressMilestoneLabels = milestones.map { localizeMilestone(it.labelKey) },
            progressMilestoneTimeTexts = milestones.map { it.timeText },
        )
    }

    /** 逐门课解析作息（手动覆盖 → 地点分组 → 档案默认，与预览宿主同一套优先级）。 */
    private fun resolveSectionsForCourse(course: Course): List<SectionTimeData>? {
        val snapshot = repository.snapshot
        val scheme = TimeSchemeLogic.resolveCourseTimeScheme(
            schemes = snapshot.timeSchemes,
            settings = snapshot.settings,
            course = course,
            locationTimeGroups = snapshot.locationTimeGroups,
        )
        val sections = scheme?.sections?.takeIf { it.isNotEmpty() } ?: snapshot.settings.sections
        return sections
            .takeIf { it.isNotEmpty() }
            ?.map { SectionTimeData(startTime = it.startTime, endTime = it.endTime) }
    }

    /**
     * 投递载荷并等「通知已交给系统」回执；超过 [NOTIFICATION_ACK_TIMEOUT_MILLIS]
     * 兜底放行（退化为不等回执的旧行为，不会更差）。
     */
    private suspend fun dispatchPayloadAwaitingNotification(payload: Map<String, Any>): Boolean {
        lastDispatchDetail = null
        val intent = LiveUpdateScheduler.buildServiceIntentFromMethodPayload(context, payload)
        val posted = CompletableDeferred<Boolean>()
        val callback: () -> Unit = { posted.complete(true) }
        // 先挂回执再起服务：服务可能在同一轮主线程消息里就发完通知，晚了会漏。
        LiveUpdateService.awaitNotificationPosted(callback)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            if (e is CancellationException) throw e
            // Dart 同口径：失败提示里带异常文本（`sendFailedWithError('$error')`）。
            lastDispatchDetail = e.message ?: e.javaClass.simpleName
            return false
        }
        val ack = try {
            withTimeoutOrNull(NOTIFICATION_ACK_TIMEOUT_MILLIS) { posted.await() }
        } finally {
            LiveUpdateService.cancelNotificationPostedWait(callback)
        }
        return ack == true
    }

    /** 最近一次投递失败的细节（异常文本），供宿主 toast 复述。 */
    @Volatile
    private var lastDispatchDetail: String? = null

    /** 开学日双键口径（与 [LiveCurrentCourseSource.semesterStartOf] 同一套）。 */
    private fun semesterStartOf(snapshot: TimetableSnapshot): LocalDateTime? =
        snapshot.semesterStartEpochDay?.let { LocalDate.ofEpochDay(it).atStartOfDay() }
            ?: snapshot.settings.semesterStartDate

    private fun semesterStartMillis(snapshot: TimetableSnapshot): Long? =
        semesterStartOf(snapshot)?.atZone(ZoneId.systemDefault())?.toInstant()?.toEpochMilli()

    /** 没设开学日时选课兜底用当前教学周（无学期日历可推，不编造）。 */
    private fun calendarWeekOrFallback(snapshot: TimetableSnapshot): Int {
        val semesterStart = semesterStartOf(snapshot) ?: return snapshot.currentWeek
        return WeekCalculator.calendarWeekForDate(
            LocalDateTime.now(),
            semesterStart,
            snapshot.currentWeek,
        )
    }

    private companion object {
        /** 与 MainActivity 的通知回执上限同值（对方 private，引用不到）。 */
        const val NOTIFICATION_ACK_TIMEOUT_MILLIS = 1_000L

        /** 显示设置页速览窗口（Dart `triggerLiveStagePreviewTest` 默认 30 秒）。 */
        const val DEFAULT_PREVIEW_SESSION_MILLIS = 30_000L
    }
}
