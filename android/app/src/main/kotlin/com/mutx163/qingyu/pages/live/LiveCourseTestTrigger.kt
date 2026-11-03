package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.widgetdata.LiveTestingFixtureData
import java.time.LocalDateTime

/**
 * 超级岛「试弹」触发管线的**纯逻辑层**（移植 `lib/services/live_testing_trigger.dart`）。
 *
 * Dart 侧把这条管线拆成三块：合成时间窗（[buildCourseTestWindow]）、跨页面会话记录
 * （[LiveCourseTestSessions]）、下发载荷构造（[buildCourseTestPayload]）。本文件逐块
 * 对齐，全部零 Android 依赖、可直接 JVM 单测；Context 侧（起前台服务、暂停原生闹钟、
 * 退后台）由 `composeP1/app/LiveTestTriggerNative.kt` 的宿主完成。
 *
 * ## 岛本体在哪
 *
 * 岛由原生 `LiveUpdateService` 用通知承载（HyperOS 把它浮成超级岛）。试弹 = 向它投递
 * 一份**完整载荷**（`validateAgainstSchedule = false`，跳过快照校验），并双路暂停正式
 * 调度到会话终点——Kotlin 侧没有 Dart 30s tick，要暂停的只有原生闹钟一路。
 *
 * ## 载荷契约
 *
 * [buildCourseTestPayload] 产出的 Map **逐键对齐**
 * `LiveUpdateScheduler.buildServiceIntentFromMethodPayload`（同仓 `LiveUpdateScheduler.kt:1040`）
 * 的读取口径：顶层 stage / 起止毫秒 / 阶段开关，`islandConfig` 子树装显示样式，
 * `currentCourse` / `nextCourse` 只带展示七字段。可空值**缺省不写**（解析侧按默认值兜），
 * 与 Dart 写 null 同义。
 */

// ───────────────────────────── 阶段 ─────────────────────────────

/**
 * 试弹的阶段变体（Dart `LiveCourseTestStage`）。
 *
 * 强制会话必须锁定单一恒定阶段：调度被暂停期间，原生 ticker 的阶段切换分支会因
 * reschedule 被推迟而收岛，只有到点 / end+30s 两个收尾路径不经过切换。
 * 故不提供「完整生命周期」变体。
 */
enum class LiveCourseTestStage(val wireValue: String) {
    BEFORE_CLASS("beforeClass"),
    DURING_CLASS("duringClass"),
}

// ───────────────────────────── 合成时间窗 ─────────────────────────────

/**
 * 试弹会话的合成时间窗（Dart `LiveCourseTestWindow`）。
 *
 * @param startMillis 会话起点（课前变体 = now+lead，课中变体 = 已开课锚点）
 * @param endMillis 会话终点（到点后原生 ticker 因 stage→null / end 收尾）
 * @param clockEndMillis 岛上「开始-结束」钟面用的结束时刻：窗口不足 1 分钟时拉到
 *   start+1min，避免「10:16 - 10:16」的零时长观感；真实起止毫秒仍用 start/end。
 * @param suspendBufferMillis 原生闹钟共同的暂停缓冲（终点 = end + buffer）
 */
data class LiveCourseTestWindow(
    val startMillis: Long,
    val endMillis: Long,
    val clockEndMillis: Long,
    val suspendBufferMillis: Long,
) {
    /** UI 芯片/按钮的摘除终点（= 原生暂停终点）。 */
    fun sessionEndFrom(nowMillis: Long): Long =
        nowMillis + (endMillis - nowMillis) + suspendBufferMillis
}

/**
 * 合成试弹时间窗（Dart `buildCourseTestWindow`，`live_testing_trigger.dart:187-223`）。
 *
 * 经典变体（[sessionLengthMillis] == null）：课前 3 分钟倒计时 + 3 分钟课程，
 * 课中锚定已开课 1 分钟 + 4 分钟后收尾，缓冲 20 秒。
 * 速览变体（非空，显示设置页「试弹」固定 30 秒）：整段窗口锁在单一阶段——
 * 课前 = (sessionLength − 1 秒) 倒计时 + 1 秒课程尾巴；课中 = 已开课 2 秒、
 * sessionLength 后收尾；缓冲 1 秒。
 */
fun buildCourseTestWindow(
    nowMillis: Long,
    stage: LiveCourseTestStage,
    sessionLengthMillis: Long?,
): LiveCourseTestWindow {
    val isBeforeClass = stage == LiveCourseTestStage.BEFORE_CLASS
    val secondMillis = 1_000L
    val minuteMillis = 60_000L
    val start: Long
    val end: Long
    val suspendBuffer: Long
    if (sessionLengthMillis != null) {
        if (isBeforeClass) {
            start = nowMillis + (sessionLengthMillis - secondMillis)
            end = start + secondMillis
        } else {
            start = nowMillis - 2 * secondMillis
            end = nowMillis + sessionLengthMillis
        }
        suspendBuffer = secondMillis
    } else {
        start = if (isBeforeClass) nowMillis + 3 * minuteMillis else nowMillis - minuteMillis
        end = if (isBeforeClass) start + 3 * minuteMillis else nowMillis + 4 * minuteMillis
        suspendBuffer = 20 * secondMillis
    }
    val clockEnd = if (end - start < minuteMillis) start + minuteMillis else end
    return LiveCourseTestWindow(
        startMillis = start,
        endMillis = end,
        clockEndMillis = clockEnd,
        suspendBufferMillis = suspendBuffer,
    )
}

// ───────────────────────────── 会话 ─────────────────────────────

/**
 * 进行中的强制起岛会话（Dart `LiveCourseTestSession`）。
 *
 * [course] 是用户选中的**原始**课程（钟点未改）；下发用的合成钟点在载荷构造时按
 * [startMillis] / [clockEndMillis] 现算，保证热更新拿到最新设置后仍能重建同一窗口。
 */
data class LiveCourseTestSession(
    val stage: LiveCourseTestStage,
    val courseName: String,
    val course: Course?,
    val sessionEndMillis: Long,
    val startMillis: Long?,
    val endMillis: Long?,
    val clockEndMillis: Long?,
    val suspendBufferMillis: Long = 5_000L,
    val source: String = "settings_screen",
)

/**
 * 试弹会话的跨页面单槽记录（Dart 顶层 `activeLiveCourseTestSession` + 设置指纹）。
 *
 * 单槽：新会话覆盖旧会话；正式路径刷新与取消清空。会话终点后原生自动收岛，
 * 记录不再有意义——读取一律走 [current]，它把已过终点的记录惰性清掉，无需定时器。
 * 此前会话状态只存页面内存，返回再进页面按钮就「忘了」测试还在跑，故上收到这里。
 */
object LiveCourseTestSessions {

    private val lock = Any()
    private var session: LiveCourseTestSession? = null

    /** 上一次下发的设置指纹（热更新判重用，Dart `_lastTestSessionSettingsSignature`）。 */
    @Volatile
    private var lastSignature: String? = null

    /** 读取当前会话；已过暂停终点（岛已被原生收尾）视为无会话并顺手清槽。 */
    fun current(nowMillis: Long = System.currentTimeMillis()): LiveCourseTestSession? {
        synchronized(lock) {
            val active = session ?: return null
            if (active.sessionEndMillis < nowMillis) {
                session = null
                lastSignature = null
                return null
            }
            return active
        }
    }

    /** 成功起岛后登记（覆盖旧会话）。 */
    fun install(active: LiveCourseTestSession, signature: String?) {
        synchronized(lock) {
            session = active
            lastSignature = signature
        }
    }

    /** 只更新指纹（热更新下发成功后）。 */
    fun updateSignature(signature: String?) {
        synchronized(lock) { lastSignature = signature }
    }

    /** 当前指纹（热更新判重用）。 */
    fun signature(): String? = synchronized(lock) { lastSignature }

    /** 清槽（取消 / 正式刷新接管）。 */
    fun clear() {
        synchronized(lock) {
            session = null
            lastSignature = null
        }
    }
}

// ───────────────────────────── 设置指纹 ─────────────────────────────

/**
 * 试弹会话的设置指纹（Dart `computeTestSessionSettingsSignature`，`:565-597`）。
 *
 * 只收**影响岛渲染**的字段：用户改了别的（无关开关）不重发通道，改了这里列出的
 * 任何一个 → 指纹变 → 热更新已在运行中的岛。
 */
fun computeTestSessionSettingsSignature(
    stage: LiveCourseTestStage,
    display: LiveDisplayState,
): String = listOf(
    stage.wireValue,
    display.showCountdown,
    display.countdownTextStyle.wireValue(),
    display.showStageText,
    display.showCourseName,
    display.showLocation,
    display.useShortName,
    display.hidePrefixText,
    display.duringClassTimeDisplayMode.value,
    display.enableMiuiIslandLabelImage,
    display.miuiIslandLabelStyle.wireValue(),
    display.miuiIslandLabelContent.wireValue(),
    display.miuiIslandLabelFontColor,
    display.miuiIslandLabelFontWeight.wireValue(),
    display.miuiIslandLabelRenderQuality.wireValue(),
    display.miuiIslandLabelFontSize,
    display.miuiIslandLabelOffsetX,
    display.miuiIslandLabelOffsetY,
    display.miuiIslandLabelLogoPath,
    display.miuiIslandLabelLogoCornerRadius,
    display.miuiIslandExpandedIconMode.wireValue(),
    display.miuiIslandExpandedIconPath,
    display.expandedDetailFields?.joinToString(",") { it.wireValue },
    if (stage == LiveCourseTestStage.BEFORE_CLASS) display.beforeClassQuickAction.wireValue() else "",
    display.beforeClassQuickActionAutoMinutes,
    display.endSecondsCountdownThreshold,
).joinToString(":")

// ───────────────────────────── 下发载荷 ─────────────────────────────

/**
 * 构造试弹会话的超级岛载荷（Dart `_dispatchLiveUpdateForCourseTest`，`:599-713`）。
 *
 * @param course 用户选中的原始课程；钟点已被 [startMillis] / [clockEndMillis] 的合成
 *   窗口覆盖后写入载荷（岛按钟面渲染，全按测试窗口走）
 * @param nextCourse 「下一节」，与正式路径同一解析规则（[resolveNextCourseForTest]）；
 *   只取名称/简称等静态展示字段，不参与任何时间计算
 * @param beforeClassLeadMillis 课前变体 = start−now（已过点则 0）；课中恒 0
 * @param display 用户当前阶段的显示设置（样式照抄用户，**开关强度不照抄**：
 *   阶段启用开关在下方强制放开——测试的目的是「看到岛的显示」，不能被用户关掉的
 *   课上/课下开关吞掉）
 * @param progress* 里程碑由调用方按课程节次解析后传入（widgetdata
 *   `LiveActivityLogicData.buildLiveProgressMilestones`），本层不重复实现
 * @return Map 契约见文件头注释；调用方原样交给
 *   `LiveUpdateScheduler.buildServiceIntentFromMethodPayload`
 */
fun buildCourseTestPayload(
    stage: LiveCourseTestStage,
    course: Course,
    nextCourse: Course?,
    startMillis: Long,
    endMillis: Long,
    beforeClassLeadMillis: Long,
    display: LiveDisplayState,
    progressBreakOffsetsMillis: List<Long>,
    progressMilestoneLabels: List<String>,
    progressMilestoneTimeTexts: List<String>,
): Map<String, Any> {
    val isBeforeClass = stage == LiveCourseTestStage.BEFORE_CLASS
    val payload = LinkedHashMap<String, Any>()
    payload["autoDismissAfterStartMinutes"] = 0
    payload["stage"] = stage.wireValue
    payload["beforeClassLeadMillis"] = beforeClassLeadMillis
    payload["validateAgainstSchedule"] = false
    payload["startAtMillis"] = startMillis
    payload["endAtMillis"] = endMillis
    // 测试会话不做「即将下课」提醒（Dart 同口径），下课秒级阈值照用户设置。
    payload["endReminderLeadMillis"] = 0L
    payload["liveClassReminderStartMinutes"] = 0
    payload["endSecondsCountdownThreshold"] = display.endSecondsCountdownThreshold
    payload["beforeClassQuickAction"] =
        if (isBeforeClass) display.beforeClassQuickAction.wireValue() else "none"
    payload["beforeClassQuickActionAutoMinutes"] = display.beforeClassQuickActionAutoMinutes
    // 展示开关按阶段强制放开（见 @param display）。
    payload["promoteDuringClass"] = !isBeforeClass
    payload["showNotificationDuringClass"] = !isBeforeClass
    payload["enableBeforeClass"] = isBeforeClass
    payload["enableDuringClass"] = !isBeforeClass
    payload["enableBeforeEnd"] = false
    payload["showCountdown"] = display.showCountdown
    payload["countdownTextStyle"] = display.countdownTextStyle.wireValue()
    payload["showStageText"] = display.showStageText
    payload["progressBreakOffsetsMillis"] = progressBreakOffsetsMillis
    payload["progressMilestoneLabels"] = progressMilestoneLabels
    payload["progressMilestoneTimeTexts"] = progressMilestoneTimeTexts
    val islandConfig = LinkedHashMap<String, Any>()
    islandConfig["showCourseName"] = display.showCourseName
    islandConfig["showLocation"] = display.showLocation
    islandConfig["useShortName"] = display.useShortName
    islandConfig["hidePrefixText"] = display.hidePrefixText
    islandConfig["duringClassTimeDisplayMode"] = display.duringClassTimeDisplayMode.value
    islandConfig["enableMiuiIslandLabelImage"] = display.enableMiuiIslandLabelImage
    islandConfig["miuiIslandLabelStyle"] = display.miuiIslandLabelStyle.wireValue()
    islandConfig["miuiIslandLabelContent"] = display.miuiIslandLabelContent.wireValue()
    islandConfig["miuiIslandLabelFontColor"] = display.miuiIslandLabelFontColor
    islandConfig["miuiIslandLabelFontWeight"] = display.miuiIslandLabelFontWeight.wireValue()
    islandConfig["miuiIslandLabelRenderQuality"] = display.miuiIslandLabelRenderQuality.wireValue()
    islandConfig["miuiIslandLabelFontSize"] = display.miuiIslandLabelFontSize
    islandConfig["miuiIslandLabelOffsetX"] = display.miuiIslandLabelOffsetX
    islandConfig["miuiIslandLabelOffsetY"] = display.miuiIslandLabelOffsetY
    display.miuiIslandLabelLogoPath?.let { islandConfig["miuiIslandLabelLogoPath"] = it }
    islandConfig["miuiIslandLabelLogoCornerRadius"] = display.miuiIslandLabelLogoCornerRadius
    islandConfig["miuiIslandExpandedIconMode"] = display.miuiIslandExpandedIconMode.wireValue()
    display.miuiIslandExpandedIconPath?.let { islandConfig["miuiIslandExpandedIconPath"] = it }
    display.expandedDetailFields
        ?.map { it.wireValue }
        ?.let { islandConfig["expandedDetailFields"] = it }
    payload["islandConfig"] = islandConfig
    payload["currentCourse"] = courseDisplayMap(course)
    if (nextCourse != null) payload["nextCourse"] = courseDisplayMap(nextCourse)
    return payload
}

/** 载荷里的课程展示子树（七字段，键名与 Dart `startLiveUpdate` 逐字一致）。 */
private fun courseDisplayMap(course: Course): Map<String, Any> {
    val map = LinkedHashMap<String, Any>()
    map["name"] = course.name
    course.shortName?.let { map["shortName"] = it }
    map["teacher"] = course.teacher
    map["location"] = course.location
    course.liveNote?.let { map["note"] = it }
    map["startTime"] = course.startTime
    map["endTime"] = course.endTime
    return map
}

// ───────────────────────────── 选课 ─────────────────────────────

/**
 * 试弹会话的「下一节」解析（Dart `_resolveNextCourseForTest`，`:555-562`）。
 *
 * 正式路径同款规则：同一节课所在教学日、按起始节次排序的下一条课。
 * 找不到同日下一条时返回 null，原生跳过「下一节」行。
 */
fun resolveNextCourseForTest(
    courses: List<Course>,
    course: Course,
    calendarWeek: Int,
): Course? {
    val sameDay = courses
        .filter { it.dayOfWeek == course.dayOfWeek && it.isActiveInWeek(calendarWeek) }
        .sortedBy { it.startSection }
    val index = sameDay.indexOfFirst { it.id == course.id }
    if (index == -1 || index + 1 >= sameDay.size) return null
    return sameDay[index + 1]
}

/**
 * 显示设置页「试弹」的目标课程解析（Dart `resolveLivePreviewTestCourse`，`:781-879`）。
 *
 * 选课规则与用户认知对齐：
 * 1. 优先用调用方传来的当前/今天接下来最近的一门（[currentSelection]，宿主侧来自
 *    `LiveCurrentCourseSource.resolve`）；
 * 2. 今天无课时，扫描课表内日历时间最接近当前时间的未来课程（按周次、星期与节次）；
 * 3. 课表内所有课程周次均已过期 → 从已有课程中挑（优先填有简称者，否则首门）；
 * 4. 课表完全为空 → 自检预设课 A（只进超级岛内存层，不写入课表）。
 */
fun resolveLivePreviewTestCourse(
    courses: List<Course>,
    calendarWeek: Int,
    semesterWeekCount: Int,
    now: LocalDateTime,
    currentSelection: Course?,
): Course {
    // 1. 当前活跃或今天接下来的课程
    if (currentSelection != null) return currentSelection

    // 2. 今天无课时，扫描接下来时间最近的课程
    if (courses.isNotEmpty()) {
        val maxWeek = maxOf(calendarWeek, courses.maxOf { it.endWeek })
        val today = now.toLocalDate()
        var nearest: Course? = null
        var nearestDelta: Long? = null
        for (candidate in courses) {
            for (week in calendarWeek..maxWeek) {
                if (!candidate.isInWeek(week)) continue
                val dayOffset = (week - calendarWeek) * 7 + candidate.dayOfWeek - now.dayOfWeek.value
                if (dayOffset < 0) continue
                val courseDate = today.plusDays(dayOffset.toLong())
                // 估算上课起始时间：优先课程实际 startTime，缺钟面时按节次推（8 点起每节 1 小时）。
                val startMinutes = parseClockMinutes(candidate.startTime)
                val candidateStart = if (startMinutes != null) {
                    courseDate.atStartOfDay().plusMinutes(startMinutes.toLong())
                } else {
                    courseDate.atTime(8 + (candidate.startSection - 1), 0)
                }
                if (candidateStart.isAfter(now)) {
                    val delta = java.time.Duration.between(now, candidateStart).toMillis()
                    if (nearestDelta == null || delta < nearestDelta) {
                        nearestDelta = delta
                        nearest = candidate
                    }
                }
                // 找到该课程的最近可用周即可
                break
            }
        }
        if (nearest != null) return nearest

        // 3. 课表有课但都在过去：挑填有简称者，否则首门
        val withShortName = courses.firstOrNull {
            !it.shortName.isNullOrBlank()
        }
        return withShortName ?: courses.first()
    }

    // 4. 课表完全为空：自检预设课 A 兜底。临近午夜无法生成不跨日预设课时，
    //    退回固定钟面的同名副本（展示字段与 buildPresetCourses 同源）。
    return try {
        LiveTestingFixtureData.buildPresetCourses(
            now = now,
            targetWeek = calendarWeek,
            semesterWeekCount = semesterWeekCount,
        ).first()
    } catch (_: IllegalStateException) {
        Course(
            id = LiveTestingFixtureData.PRESET_COURSE_ID_A,
            name = LiveTestingFixtureData.PRESET_COURSE_A_NAME,
            shortName = LiveTestingFixtureData.PRESET_COURSE_A_SHORT_NAME,
            teacher = LiveTestingFixtureData.PRESET_COURSE_A_TEACHER,
            location = LiveTestingFixtureData.PRESET_COURSE_A_LOCATION,
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            startTime = "08:00",
            endTime = "09:40",
        )
    }
}

/** `HH:mm` → 当天分钟数；解析不了返回 null（调用方按节次推）。 */
private fun parseClockMinutes(clock: String): Int? {
    val parts = clock.split(":")
    if (parts.size < 2) return null
    val hour = parts[0].trim().toIntOrNull() ?: return null
    val minute = parts[1].trim().toIntOrNull() ?: return null
    return hour * 60 + minute
}

// ───────────────────────────── 原生快照构建 ─────────────────────────────

/**
 * 组装原生调度快照（Dart `syncScheduleSnapshot` 的 Compose 壳对应物）。
 *
 * 为什么壳要自己造：正式路径（诊断页「触发某节」→ 生产刷新）里，原生
 * `LiveUpdateScheduler.reschedule` 从 `snapshot_json` 选课；纯 Compose 壳没有 Dart
 * 通道，盘上**从来没有过**带课程的快照——不补这一块，正式路径永远选不出课。
 *
 * 口径：结构与 Dart `syncScheduleSnapshot` 同名同义；课程 JSON 键名与原生解析器
 * （`LiveUpdateScheduler.kt:1735-1762`）逐字对齐，note 下发合并后的 [Course.liveNote]。
 * 节假日：壳的快照数据源（`TimetableSnapshot`）不拥有节假日数据，与预览
 * （`SnapshotLiveHost.isHoliday` 恒 false）同一边界——按「非假期」下发，不编造。
 */
object LiveNativeSnapshotBuilder {

    const val KEY_EXPANDED_DETAIL_SCHEMA_VERSION = "liveExpandedDetailSchemaVersion"

    /** 展开详情写法版本号，与 `LiveSnapshotBuilder.EXPANDED_DETAIL_SCHEMA_VERSION` 同值。 */
    const val EXPANDED_DETAIL_SCHEMA_VERSION = 1

    /**
     * 组装快照 JSON。
     *
     * @param settingsJson 完整 `timetable_settings`（`TimetableStore.loadSettingsJson()`）
     * @param semesterStartMillis 开学日毫秒；null = 未配置（原生按无学期处理）
     */
    fun buildJson(
        courses: List<Course>,
        settingsJson: Map<String, Any?>,
        currentWeek: Int,
        semesterStartMillis: Long?,
        endReminderLeadMillis: Long = 600_000L,
    ): String {
        val root = LinkedHashMap<String, Any?>()
        root["currentWeek"] = currentWeek
        if (semesterStartMillis != null) root["semesterStartMillis"] = semesterStartMillis
        root["endReminderLeadMillis"] = endReminderLeadMillis
        root["isHoliday"] = false
        root["holidayDates"] = emptyList<String>()
        root["adjustedWorkdayDates"] = emptyList<String>()
        root["holidayOverrideEnabled"] = false
        root["enableHolidayMarking"] = true
        root["courses"] = courses.map { courseJson(it) }
        val settings = LinkedHashMap<String, Any?>(settingsJson)
        settings[KEY_EXPANDED_DETAIL_SCHEMA_VERSION] = EXPANDED_DETAIL_SCHEMA_VERSION
        root["settings"] = settings
        return MiniJson.encode(root)
    }

    /** 课程 → 快照 JSON 子树（键名与原生解析器契约逐字一致）。 */
    private fun courseJson(course: Course): Map<String, Any?> {
        val map = LinkedHashMap<String, Any?>()
        map["id"] = course.id
        map["name"] = course.name
        map["shortName"] = course.shortName
        map["teacher"] = course.teacher
        map["location"] = course.location
        map["dayOfWeek"] = course.dayOfWeek
        map["startSection"] = course.startSection
        map["endSection"] = course.endSection
        map["startTime"] = course.startTime
        map["endTime"] = course.endTime
        map["startWeek"] = course.startWeek
        map["endWeek"] = course.endWeek
        map["isOddWeek"] = course.isOddWeek
        map["isEvenWeek"] = course.isEvenWeek
        map["customWeeks"] = course.normalizedCustomWeeks
        map["suspendedWeeks"] = course.normalizedSuspendedWeeks
        map["note"] = course.liveNote
        return map
    }
}
