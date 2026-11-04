package com.mutx163.qingyu.core

import java.time.DateTimeException
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Locale

/**
 * 单节课提醒（`classReminders`）的**纯计算层**：条目 → AlarmManager 触发点。
 *
 * 逐行对齐 Dart `lib/services/class_reminder_service.dart`（`buildFires` 在
 * :64-116，其余方法见各函数注释）与 `lib/models/class_reminder.dart`。
 * 无 Android / Compose 依赖，JVM 单测直接跑。
 *
 * ## 这一层刻意不做什么
 *
 * - **不读设置、不写设置**：条目列表是外部传进来的（Dart 侧存于
 *   `TimetableSettings.classReminders`），本层不新增设置键、不碰 manifest。
 * - **不调度**：通道、AlarmManager、开机/换时区重建都在原生管线
 *   （`ExamReminderScheduler.kt`），本层只产出 fire。
 * - **不落盘**：条目持久化仍由设置族负责。
 *
 * ## 三处与 Dart 形状的显式差异（都是确定性/边界收紧，不是语义漂移）
 *
 * 1. [buildFires] 的 `now` 是必填参数。Dart 用 `now ?? DateTime.now()`（:69），
 *    纯函数层不允许读钟，否则测试无法固定参考时刻。
 * 2. 排序在 Dart 的**主键 `fireAtMillis`**（:114）之上补了**次级键 `entry.id`**。
 *    Dart 的 `List.sort` 不保证稳定，同刻多课的顺序在不同实现/不同批次下可能抖动；
 *    PendingIntent 身份不受顺序影响，但「同一批重建结果字节一致」可让对拍与排障
 *    不出现假 diff。主键不变，次级键只在主键相等时生效。
 * 3. [occurrenceDate] 在 Dart `class_reminder_sheet.dart:37-48` 的日期算术之外，
 *    先查 `Course.isActiveInWeek`。Dart 的 sheet 只从**已按周规则过滤过的网格**
 *    进入，所以 `_occurrenceDateFor` 不必复查；纯计算层没有网格上下文，
 *    周规则（单双周 / 停课周 / 自定义周 / 学期范围）必须在这里兜住。
 */
object ClassReminderPlan {

    /**
     * 默认提前量：一键添加时「上课前 N 分钟」
     * （Dart `defaultLeadMinutes`，`class_reminder_service.dart:12`）。
     */
    const val DEFAULT_LEAD_MINUTES: Int = 30

    /**
     * PendingIntent requestCode 的名字空间
     * （Dart `ExamReminderService.requestCodeNamespace`，`:38`）；
     * 原生取消按同一个整数找 PendingIntent，所以这里必须逐位一致。
     */
    const val REQUEST_CODE_NAMESPACE: Int = 0x46000000

    /** 一条「某课 × 某真实日期 × 某响点」的提醒条目（Dart `ClassReminderEntry`）。 */
    data class Entry(
        val courseId: String,
        /** 上课真实日期，`yyyy-MM-dd`（见 [formatDate]）。 */
        val date: String,
        /** 响点在该日内的分钟数；同日内表达，不跨午夜。 */
        val minuteOfDay: Int,
    ) {
        /** 全局唯一身份，同时是原生取消/去重用的 fire id（Dart `id`，`class_reminder.dart:25`）。 */
        val id: String get() = "classreminder:$courseId@$date"

        /**
         * Dart `isValid`（`class_reminder.dart:33-37`）：课程 id 非空白、
         * 日期是**真实存在**的 `yyyy-MM-dd`、响点 0..1439。
         * 设置 JSON 可能来自旧版本或手改备份，坏条目一律**丢弃**而不是抛错。
         */
        val isValid: Boolean
            get() = courseId.trim().isNotEmpty() &&
                parseDate(date) != null &&
                minuteOfDay in 0..1439
    }

    /**
     * 一个已经算好的通知触发点（Dart `ExamReminderFire`，`exam_reminder_service.dart:6-33`）。
     *
     * `offsetMinutes` 恒为 0：Dart 在 `class_reminder_service.dart:105-107` 解释了
     * 为什么——原生侧会拿提前量做减法反推响点（`ExamReminderScheduler.kt:186-187`）
     * 与加法反推上课时刻（`:426-427`），而条目的 `minuteOfDay` **就是响点本身**，
     * 把它当提前量填进去会让开机/换时区后的响点整体前移「当日分钟数」。
     * 填 0 让两套加减退化成恒等。身份不靠这个字段：`entryId` 已含课程与日期，
     * `requestCode` 另含 `minuteOfDay`。
     */
    data class Fire(
        /** Dart `examId`；原生侧对 id 字符串完全通用。 */
        val entryId: String,
        /** 响点（本地墙上时刻）。 */
        val fireAt: LocalDateTime,
        val title: String,
        val body: String,
        val requestCode: Int,
        val offsetMinutes: Int = 0,
    ) {
        /**
         * 原生 Payload 的 `fireAtMillis` / `examStartMillis`。Dart 两处都填
         * `fireAt.millisecondsSinceEpoch`（`:106-107`），故只存一个时刻。
         */
        val fireAtMillis: Long get() = DartTime.toEpochMillis(fireAt)
    }

    /** `"HH:mm"` → 当日分钟数；格式非法或越界 ⇒ null（Dart `:15-29`）。 */
    fun parseClockMinutes(value: String): Int? = ClassAlarmPlanLogic.parseClockMinutes(value)

    /** 当日分钟数 → `"HH:mm"`，自动归一到一天内（Dart `:32-40`）。 */
    fun formatClock(minutes: Int): String = ClassAlarmPlanLogic.formatClock(minutes)

    /** `yyyy-MM-dd`（Dart `ClassReminderEntry.formatDate`，`class_reminder.dart:28-31`）。 */
    fun formatDate(date: LocalDate): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)

    /**
     * 条目所在真实日期的完整本地时间（即提醒响点），Dart `occurrenceDateTime`（`:43-55`）。
     *
     * Dart 只做正则 + `DateTime(y,m,d,...)`（越界日会顺延）；这里要求日期**真实存在**，
     * 与 `isValid` 同口径。[buildFires] 先查 `isValid`，所以两条路径对生产的
     * 条目集合结果一致；单独调用时本函数更严格，坏日期返回 null 而不是顺延。
     */
    fun occurrenceDateTime(entry: Entry): LocalDateTime? {
        val date = parseDate(entry.date) ?: return null
        if (entry.minuteOfDay !in 0..1439) return null
        return date.atStartOfDay().plusMinutes(entry.minuteOfDay.toLong())
    }

    /**
     * 与原生取消逻辑共享的稳定 requestCode（Dart `:59-60` →
     * `ExamReminderService.stableRequestCode`，`exam_reminder_service.dart:74-83`）。
     *
     * 键是 `"$id#$minuteOfDay"`，**`minuteOfDay` 参与哈希**：用户改提醒时间后
     * PendingIntent 身份随之改变，旧闹钟才会被真正换掉（而不是被新时刻顶替、
     * 或与新时刻共用身份导致其中一条静默丢失）。
     */
    fun requestCode(entry: Entry): Int {
        val key = "${entry.id}#${entry.minuteOfDay}"
        var hash = 0x811c9dc5L
        for (codeUnit in key) { // Char = 一个 UTF-16 码元，与 Dart `codeUnits` 同口径
            hash = hash xor codeUnit.code.toLong()
            hash = (hash * 0x01000193L) and 0x7fffffffL
        }
        return REQUEST_CODE_NAMESPACE or (hash and 0x00ffffffL).toInt()
    }

    /**
     * 展开为**未来**的通知触发点（Dart `buildFires`，`:64-116`）。
     *
     * 丢弃规则（原生 reconcile 是「先全量取消旧的、再排新的」，所以丢弃不会残留旧调度）：
     * 条目非法（[Entry.isValid]）、课程已删除（`resolveCourse` 返回 null）、
     * 响点解析不出、响点**不晚于** [now]（`!fireAt.isAfter(now)`，与 Dart 同一判据：
     * 恰好等于 now 也算过期）。
     *
     * 产出字段：
     * - `title` = 课程名 `trim()`（Dart `:108`）；
     * - `body` = 地点 `trim()`；地点为空白时回落响点钟点 `HH:mm`
     *   （Dart `:83-92`，避开原生「你有一场即将开始的考试」的空白正文兜底）；
     * - `offsetMinutes` = 0（见 [Fire] 注释）；
     * - 排序：主键 `fireAt`、次级键 `entryId`（见类头差异 2）。
     *
     * @param entries 条目列表（顺序无关；同一集合的重建结果一致）。
     * @param resolveCourse 课程 id → 课程；返回 null 表示课程已被删除。
     * @param now 参考「此刻」，由调用方传入。
     */
    fun buildFires(
        entries: List<Entry>,
        resolveCourse: (String) -> Course?,
        now: LocalDateTime,
    ): List<Fire> {
        val fires = ArrayList<Fire>(entries.size)
        for (entry in entries) {
            if (!entry.isValid) continue
            val course = resolveCourse(entry.courseId) ?: continue
            val fireAt = occurrenceDateTime(entry) ?: continue
            if (!fireAt.isAfter(now)) continue
            val location = course.location.trim()
            fires += Fire(
                entryId = entry.id,
                fireAt = fireAt,
                title = course.name.trim(),
                body = location.ifEmpty { formatClock(entry.minuteOfDay) },
                requestCode = requestCode(entry),
                offsetMinutes = 0,
            )
        }
        fires.sortWith(compareBy({ it.fireAt }, { it.entryId }))
        return fires
    }

    /**
     * 课程在第 [week] 周的那一次课的真实日期；算不出来（或这周不上）⇒ null。
     *
     * 日期算术取 Dart `class_reminder_sheet.dart:37-48`：
     * 开学日先归到**所在周的周一零点**，再加 `(week - 1) * 7 + dayOfWeek - 1`。
     * 开学日缺失 ⇒ null（Dart `:39-40`）。
     *
     * 周规则复查（见类头差异 3）走 [Course.isActiveInWeek]：单双周错位、
     * 停课周、自定义周、学期范围外都在这里被拦下。
     */
    fun occurrenceDate(
        course: Course,
        week: Int,
        semesterStart: LocalDateTime?,
    ): LocalDate? {
        if (semesterStart == null) return null
        if (week < 1) return null
        if (course.dayOfWeek !in 1..7) return null
        if (!course.isActiveInWeek(week)) return null
        val monday = LocalDate.of(semesterStart.year, semesterStart.monthValue, semesterStart.dayOfMonth)
            .minusDays((semesterStart.dayOfWeek.value - 1).toLong())
        return monday.plusDays(((week - 1) * 7 + course.dayOfWeek - 1).toLong())
    }

    /**
     * 由「上课日 + 上课钟点 + 提前量」生成条目；响点越过午夜时**日期回退一天**。
     *
     * 条目的 `minuteOfDay` 是**响点**而不是上课钟点：提前量 30 分钟时，
     * 00:10 的课 → 前一天 23:40（`class_reminder.dart:21` 明确「同日内表达，
     * 不跨午夜」，所以跨日只能靠 date 回退表达）。
     *
     * @param startMinuteOfDay 上课钟点（当日分钟数）；解析失败应由调用方拦下。
     */
    fun entryFor(
        courseId: String,
        occurrence: LocalDate,
        startMinuteOfDay: Int,
        leadMinutes: Int = DEFAULT_LEAD_MINUTES,
    ): Entry {
        val raw = startMinuteOfDay - leadMinutes
        return if (raw < 0) {
            Entry(courseId, formatDate(occurrence.minusDays(1)), raw + 1440)
        } else {
            Entry(courseId, formatDate(occurrence), raw)
        }
    }

    // ------------------------------------------------------------------
    // 严格日期解析（Dart `_isValidDate`，`class_reminder.dart:84-100`）
    // ------------------------------------------------------------------

    private val DATE_PATTERN = Regex("""^(\d{4})-(\d{2})-(\d{2})$""")

    /** `yyyy-MM-dd` 且**真实存在**（2026-02-31 不顺延）⇒ 该日期；否则 null。 */
    private fun parseDate(value: String): LocalDate? {
        val match = DATE_PATTERN.matchEntire(value) ?: return null
        val (year, month, day) = match.destructured
        return try {
            LocalDate.of(year.toInt(), month.toInt(), day.toInt())
        } catch (_: DateTimeException) {
            null
        }
    }
}
