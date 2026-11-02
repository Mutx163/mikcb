package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 一条考试提醒的**响点**（纯数据，无 Android 依赖）。
 *
 * 与 Dart `ExamReminderFire`（`lib/services/exam_reminder_service.dart:14-59`）同一形状，
 * 字段名与 [toNativeMap] 的键逐字对齐 `ExamReminderScheduler.parseFires`
 * （`ExamReminderScheduler.kt:463-501`）的读侧——原生调度器只认这些键。
 *
 * @property examId 稳定 id（就是考试 id；日程提醒用 `schedule:` 前缀区分命名空间）。
 * @property offsetMinutes 提前量（分钟，恒 > 0）。
 * @property fireAtEpochMillis 响点（UTC 毫秒）。
 * @property examStartEpochMillis 考试开始时刻（UTC 毫秒）；开机 / 换时区重排的锚点。
 * @property requestCode PendingIntent 码；原生取消 / 去重只认它，不从 id 重算。
 * @property localDate 考试开始日的本地日历日 `yyyy-MM-dd`（换时区重排按墙上时钟重算）。
 * @property localTimeMinutes 考试开始的当天分钟数（同上）。
 */
data class ExamReminderFire(
    val examId: String,
    val offsetMinutes: Int,
    val fireAtEpochMillis: Long,
    val examStartEpochMillis: Long,
    val title: String,
    val body: String,
    val requestCode: Int,
    val localDate: String,
    val localTimeMinutes: Int,
) {
    /** 逻辑提醒身份：id + 提前量（Dart `fireKey`）。改了提前量即视为另一条提醒。 */
    val fireKey: String get() = "$examId#$offsetMinutes"

    /** 原生 map（键名与 `ExamReminderScheduler.parseFires` 逐字一致）。 */
    fun toNativeMap(): Map<String, Any?> = linkedMapOf(
        "examId" to examId,
        "offsetMinutes" to offsetMinutes,
        "fireAtMillis" to fireAtEpochMillis,
        "examStartMillis" to examStartEpochMillis,
        "title" to title,
        "body" to body,
        "requestCode" to requestCode,
        "localDate" to localDate,
        "localTimeMinutes" to localTimeMinutes,
    )
}

/**
 * 考试提醒的**排程计算层**——纯 Kotlin，无 Android / IO 依赖，JVM 单测可直接跑。
 *
 * 逐条移植 Dart `ExamReminderService.buildFires` / `assignDistinctRequestCodes` /
 * `buildPlannedFireKeys`（`lib/services/exam_reminder_service.dart:101-195` 与 `:363-439`），
 * 不改语义。产物交给 `ExamReminderScheduler.reconcile`（Android 侧）排 AlarmManager。
 *
 * ## 为什么 Compose 侧要有一份
 *
 * 原生调度器早就有了，但生产上唯一喂它的人是 MainActivity 的 MethodChannel ←
 * Dart 设置页。Compose 壳不跑 Dart，用户改考试后没有任何人重排闹钟——本层 +
 * `ExamReminderCoordinator` 把这条链在纯 Kotlin 侧接上（对位日程提醒的
 * `ScheduleReminderLogic` / `ScheduleReminderCoordinator`）。
 *
 * ## 只算考试，不并日程
 *
 * Dart 的 reconcile 是**三源合流**（考试 + 日程 + 单节课提醒）写同一份快照；Compose 壳
 * 的日程提醒已由 `ScheduleReminderScheduler` 用**独立 prefs / 渠道**接管
 * （`ScheduleReminderScheduler.kt:27-33` 的裁定），单节课提醒走系统时钟不走本管线。
 * 所以这里只产出考试源，日程与单节课不会因本侧整表替换而丢闹钟。
 */
object ExamReminderLogic {

    /** PendingIntent requestCode 命名空间（Dart `requestCodeNamespace = 0x46000000`）。 */
    const val REQUEST_CODE_NAMESPACE: Int = 0x46000000

    /**
     * 稳定 requestCode（Dart `ExamReminderService.stableRequestCode` 同一算法）：
     * FNV-1a 变体截 24 位。同一个 (id, 提前量) 每次算出同一个码，原生取消才找得回。
     */
    fun stableRequestCode(examId: String, offsetMinutes: Int): Int {
        val key = "$examId#$offsetMinutes"
        var hash = 0x811c9dc5L
        for (codeUnit in key) {
            hash = hash xor codeUnit.code.toLong()
            hash = (hash * 0x01000193L) and 0x7fffffffL
        }
        return REQUEST_CODE_NAMESPACE or (hash and 0x00ffffffL).toInt()
    }

    /**
     * 展开考试列表为响点（Dart `buildFires`，`exam_reminder_service.dart:369-439`）。
     *
     * 口径逐条对齐：
     * - 考试**结束**（考试日 + endTime，解析失败回落 23:59）不晚于 [now] ⇒ 整场跳过；
     * - 提前量取 `effectiveReminderMinutes` 去重升序；空表 / 全部 ≤ 0 ⇒ 跳过；
     * - 响点 = 开始时刻 − 提前量，**只收严格未来**（[includePastOffsets] 时放行已过点，
     *   仅供计划键对账用；投递列表收已过点会让 AlarmManager 立刻重复投递）；
     * - 通知正文 = `HH:mm-HH:mm · 地点（课程地点兜底）· 座位号`，空段不拼。
     *
     * @param resolveCourse 考试关联课程（正文地点兜底用；壳传 `repository::getCourseById`）。
     */
    fun buildFires(
        exams: List<Exam>,
        resolveCourse: (Exam) -> Course? = { null },
        now: LocalDateTime = LocalDateTime.now(),
        zone: ZoneId = ZoneId.systemDefault(),
        includePastOffsets: Boolean = false,
    ): List<ExamReminderFire> {
        val fires = mutableListOf<ExamReminderFire>()
        for (exam in exams) {
            val (endHour, endMinute) = Exam.parseTimeOfDayParts(
                exam.endTime,
                fallbackHour = 23,
                fallbackMinute = 59,
            )
            val examEnd = LocalDateTime.of(
                exam.dateTime.year,
                exam.dateTime.monthValue,
                exam.dateTime.dayOfMonth,
                endHour,
                endMinute,
            )
            if (!examEnd.isAfter(now)) {
                continue
            }
            val offsets = exam.effectiveReminderMinutes.toSet().sorted()
            if (offsets.isEmpty()) {
                continue
            }
            val examStart = exam.examStartDateTime
            val examStartMillis = atZone(examStart, zone)
            val body = buildBody(exam, resolveCourse(exam))
            val title = exam.name.trim()
            for (offsetMinutes in offsets) {
                if (offsetMinutes <= 0) {
                    continue
                }
                val fireAt = examStart.minusMinutes(offsetMinutes.toLong())
                if (!includePastOffsets && !fireAt.isAfter(now)) {
                    continue
                }
                fires.add(
                    ExamReminderFire(
                        examId = exam.id,
                        offsetMinutes = offsetMinutes,
                        fireAtEpochMillis = atZone(fireAt, zone),
                        examStartEpochMillis = examStartMillis,
                        title = title,
                        body = body,
                        requestCode = stableRequestCode(exam.id, offsetMinutes),
                        localDate = String.format(
                            java.util.Locale.US,
                            "%04d-%02d-%02d",
                            examStart.year,
                            examStart.monthValue,
                            examStart.dayOfMonth,
                        ),
                        localTimeMinutes = examStart.hour * 60 + examStart.minute,
                    ),
                )
            }
        }
        fires.sortBy { it.fireAtEpochMillis }
        return fires
    }

    /**
     * 给一整批响点分配**互不重复**的 requestCode（Dart `assignDistinctRequestCodes`，
     * `exam_reminder_service.dart:101-142`）。
     *
     * 24 位散列空间在大量考试时会碰撞：两条 fire 的 PendingIntent 身份相同，后写入的
     * 整条顶掉前一条 → 更早的那条提醒静默丢失。碰撞消解按 (examId, offset, fireAt)
     * 排序后逐个探测 `examId#collision<n>`，结果只取决于**集合**，与拼装顺序无关。
     */
    fun assignDistinctRequestCodes(fires: List<ExamReminderFire>): List<ExamReminderFire> {
        val ordered = fires.sortedWith(
            compareBy({ it.examId }, { it.offsetMinutes }, { it.fireAtEpochMillis }),
        )
        val taken = HashSet<Int>(ordered.size * 2)
        val result = ArrayList<ExamReminderFire>(ordered.size)
        for (fire in ordered) {
            var code = fire.requestCode
            var probe = 0
            val registered = taken.add(code)
            if (!registered) {
                do {
                    probe++
                    code = stableRequestCode("${fire.examId}#collision$probe", fire.offsetMinutes)
                } while (!taken.add(code))
            }
            result.add(
                if (probe == 0) fire else fire.copy(requestCode = code),
            )
        }
        result.sortBy { it.fireAtEpochMillis }
        return result
    }

    /**
     * 交给原生的「这条逻辑提醒仍在计划里」键集（Dart `buildPlannedFireKeys` 的考试部分）：
     * **含已过点的提前量**（`includePastOffsets = true`）。原生逾期未投递重试通道
     * （`ExamReminderScheduler.kt:108-136`）靠它判断一条到点没弹出去的 fire 要不要重试；
     * 投递列表刻意只收严格未来，两边各指认对方兜底。
     */
    fun buildPlannedFireKeys(
        exams: List<Exam>,
        resolveCourse: (Exam) -> Course? = { null },
        now: LocalDateTime = LocalDateTime.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Set<String> = buildFires(
        exams = exams,
        resolveCourse = resolveCourse,
        now = now,
        zone = zone,
        includePastOffsets = true,
    ).mapTo(LinkedHashSet()) { it.fireKey }

    /**
     * 一次算齐交给 `ExamReminderScheduler.reconcile` 的全部参数：
     * 响点列表（原生 map 形态）、活跃考试 id、计划键。
     *
     * `Coordinator` 拿它直接喂原生，不含任何 Android 类型。
     */
    data class NativePayload(
        val fires: List<Map<String, Any?>>,
        val activeExamIds: Set<String>,
        val activeFireKeys: Set<String>,
    )

    /** 组装 [NativePayload]（对位 Dart `ExamReminderService.reconcile` 的参数拼装）。 */
    fun buildPayload(
        exams: List<Exam>,
        resolveCourse: (Exam) -> Course? = { null },
        now: LocalDateTime = LocalDateTime.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): NativePayload {
        val fires = assignDistinctRequestCodes(
            buildFires(exams = exams, resolveCourse = resolveCourse, now = now, zone = zone),
        )
        val activeExamIds = exams
            .filter { !isExpired(it, now) }
            .mapTo(LinkedHashSet()) { it.id }
        return NativePayload(
            fires = fires.map { it.toNativeMap() },
            activeExamIds = activeExamIds,
            activeFireKeys = buildPlannedFireKeys(
                exams = exams,
                resolveCourse = resolveCourse,
                now = now,
                zone = zone,
            ),
        )
    }

    /** 考试是否已过（Dart `Exam.isExpired`：now 晚于「考试日 + endTime」，fallback 23:59）。 */
    fun isExpired(exam: Exam, now: LocalDateTime): Boolean {
        val (endHour, endMinute) = Exam.parseTimeOfDayParts(
            exam.endTime,
            fallbackHour = 23,
            fallbackMinute = 59,
        )
        return now.isAfter(
            LocalDateTime.of(
                exam.dateTime.year,
                exam.dateTime.monthValue,
                exam.dateTime.dayOfMonth,
                endHour,
                endMinute,
            ),
        )
    }

    /** 通知正文（Dart `_buildBody`，`exam_reminder_service.dart:441-454`）。 */
    private fun buildBody(exam: Exam, course: Course?): String {
        val parts = mutableListOf("${exam.startTime}-${exam.endTime}")
        val location = exam.location?.trim().takeUnless { it.isNullOrEmpty() }
            ?: course?.location?.trim().takeUnless { it.isNullOrEmpty() }
        if (location != null) {
            parts.add(location)
        }
        val seatNumber = exam.seatNumber?.trim()
        if (!seatNumber.isNullOrEmpty()) {
            parts.add(seatNumber)
        }
        return parts.joinToString(" · ")
    }

    private fun atZone(time: LocalDateTime, zone: ZoneId): Long =
        time.atZone(zone).toInstant().toEpochMilli()
}
