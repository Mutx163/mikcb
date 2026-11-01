package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.core.ScheduleItem
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * 一条日程提醒的**响点**（纯数据，无 Android 依赖）。
 *
 * 与 Dart `ExamReminderFire`（`lib/services/exam_reminder_service.dart:14-59`）同一个
 * 形状：原生调度器只认这些字段，判重/取消一律按 [fireKey] 与 [requestCode]，
 * 不从日程对象重新推导。
 *
 * @property scheduleId 稳定 id，形如 `schedule:<occurrenceId>`；与考试 id 命名空间分开，
 *   因此原生快照里两类提醒可以共存而不会互相取消。
 * @property offsetMinutes 提前量（分钟，恒 > 0）。
 * @property fireAtEpochMillis 实际响点（UTC 毫秒）。
 * @property startEpochMillis 日程开始时刻（UTC 毫秒）。
 * @property localDate 日程开始日的本地日历日 `yyyy-MM-dd`（时区变更后重排用）。
 * @property localTimeMinutes 日程开始时刻的当天分钟数（时区变更后重排用）。
 */
data class ScheduleReminderFire(
    val scheduleId: String,
    val offsetMinutes: Int,
    val fireAtEpochMillis: Long,
    val startEpochMillis: Long,
    val title: String,
    val body: String,
    val requestCode: Int,
    val localDate: String,
    val localTimeMinutes: Int,
) {
    /** 逻辑提醒身份：id + 提前量。改了提前量即视为另一条提醒（旧闹钟不重试）。 */
    val fireKey: String get() = "$scheduleId#$offsetMinutes"
}

/**
 * 日程提醒的**排程计算层**——纯 Kotlin，无 Android / IO 依赖，JVM 单测可直接跑。
 *
 * 逐条移植 Dart `ExamReminderService.buildScheduleFires` /
 * `buildScheduleActiveIds` / `_buildScheduleInstances`（`lib/services/exam_reminder_service.dart:197-361`），
 * 不改语义。原生侧只负责「把这里算出来的响点交给 AlarmManager / 通知」。
 *
 * ## 为什么先展开再算响点
 *
 * 落盘的是**系列根 + 单次例外**，不是一个个发生实例。重复日程（每天 / 每周）必须
 * 先在有界窗口内展开成具体日期，才谈得上「某天几点提前几分钟响」。窗口取
 * 「今天 - 1 天 ~ 今天 + 366 天」与 Dart 一致：留 1 天是为了让「昨天到点但没弹出去」
 * 的提醒仍能被对账看到并重试一次，366 天保证一年内的重复日程都不会漏排。
 *
 * ## 去重口径必须与首页/月历一致
 *
 * 同一系列的两次不同例外被移到同一天时，是**两条真实存在、可分别撤销**的条目：
 * 展示层用 `occurrenceId` 做兄弟键各留一份，提醒层也必须各排一条。若这里退化成
 * 「sourceItemId@显示日」覆盖式去重，界面上两张卡都在、提醒表却只有一条，被吞的
 * 那条不在活跃集合里，原生对账会把用户已经设好的闹钟取消掉
 *（Dart 侧 `test/services/schedule_reminder_sibling_override_test.dart` 钉着这条）。
 */
object ScheduleReminderLogic {

    /** 与考试提醒 `0x46000000` 分开的 PendingIntent requestCode 命名空间。 */
    const val REQUEST_CODE_NAMESPACE: Int = 0x47000000

    /** 向前展开的天数（Dart `_scheduleReminderHorizon = 366 days`）。 */
    const val HORIZON_DAYS: Long = 366L

    /** 向后回看的天数（Dart `_scheduleReminderRetryWindow = 1 day`）。 */
    const val RETRY_WINDOW_DAYS: Long = 1L

    const val SCHEDULE_ID_PREFIX: String = "schedule:"

    /**
     * 稳定 requestCode（Dart `ExamReminderService.stableRequestCode` 同一算法）：
     * FNV-1a 变体截 24 位。同一个 (id, 提前量) 每次算出同一个码，原生取消才找得回。
     */
    fun stableRequestCode(scheduleId: String, offsetMinutes: Int): Int {
        val key = "$scheduleId#$offsetMinutes"
        var hash = 0x811c9dc5L
        for (codeUnit in key) {
            hash = hash xor codeUnit.code.toLong()
            hash = (hash * 0x01000193L) and 0x7fffffffL
        }
        return REQUEST_CODE_NAMESPACE or (hash and 0x00ffffffL).toInt()
    }

    /**
     * 算出 [now] 之后（[includePastOffsets] 时含窗口内已过点）的全部提醒响点。
     *
     * @param items 当前日程列表（系列根 + 例外行，与落盘一致）。
     * @param now 参考时刻；测试注入固定时钟。
     * @param zone 本地时区，决定日期 + `HH:mm` 换算成的 UTC 毫秒。
     * @param includePastOffsets 仅供对账重试使用：投递列表永远只收严格未来的响点
     *   （刚响过的再排一次会让 AlarmManager 立刻重复投递）；重试通道需要「已到点
     *   但可能没弹出去」的那些，由调用方显式打开。
     */
    fun buildFires(
        items: List<ScheduleItem>,
        now: LocalDateTime = LocalDateTime.now(),
        zone: ZoneId = ZoneId.systemDefault(),
        includePastOffsets: Boolean = false,
    ): List<ScheduleReminderFire> {
        val fromDate = now.toLocalDate().minusDays(RETRY_WINDOW_DAYS)
        val toDate = now.toLocalDate().plusDays(HORIZON_DAYS)
        val instances = buildInstances(items, fromDate, toDate)

        val fires = mutableListOf<ScheduleReminderFire>()
        for (instance in instances) {
            val item = instance.item
            if (!item.enabled) {
                continue
            }
            val offsetMinutes = item.reminderMinutesBefore?.toInt() ?: continue
            if (offsetMinutes <= 0) {
                continue
            }
            val start = buildDateTime(instance.date, item.startTime) ?: continue
            val fireAt = start.minusMinutes(offsetMinutes.toLong())
            if (!includePastOffsets && !fireAt.isAfter(now)) {
                continue
            }
            val scheduleId = SCHEDULE_ID_PREFIX + instance.occurrenceId
            fires.add(
                ScheduleReminderFire(
                    scheduleId = scheduleId,
                    offsetMinutes = offsetMinutes,
                    fireAtEpochMillis = fireAt.atZone(zone).toInstant().toEpochMilli(),
                    startEpochMillis = start.atZone(zone).toInstant().toEpochMilli(),
                    title = item.title.trim(),
                    body = buildBody(item),
                    requestCode = stableRequestCode(scheduleId, offsetMinutes),
                    localDate = formatDate(instance.date),
                    localTimeMinutes = start.hour * 60 + start.minute,
                ),
            )
        }
        return assignDistinctRequestCodes(fires)
    }

    /**
     * 当前仍在「计划内」的提醒 id 集合（原生按它撤销已删除 / 已停用日程的闹钟）。
     *
     * 与投递列表不同：这里**包含窗口内已过点**的日程（范围从昨天开始），
     * 因为原生重试通道要判断「这条逾期未投递的提醒是否还该重试」。
     */
    fun buildActiveIds(
        items: List<ScheduleItem>,
        now: LocalDateTime = LocalDateTime.now(),
    ): Set<String> {
        val fromDate = now.toLocalDate().minusDays(RETRY_WINDOW_DAYS)
        val toDate = now.toLocalDate().plusDays(HORIZON_DAYS)
        return buildInstances(items, fromDate, toDate)
            .asSequence()
            .filter { instance ->
                val item = instance.item
                item.enabled && (item.reminderMinutesBefore?.toInt() ?: 0) > 0
            }
            .map { SCHEDULE_ID_PREFIX + it.occurrenceId }
            .toCollection(linkedSetOf())
    }

    /** 计划键（id + 提前量）集合；含窗口内已过点，供原生判断逾期条目是否该重试。 */
    fun buildPlannedFireKeys(
        items: List<ScheduleItem>,
        now: LocalDateTime = LocalDateTime.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Set<String> = buildFires(
        items = items,
        now = now,
        zone = zone,
        includePastOffsets = true,
    ).mapTo(linkedSetOf()) { it.fireKey }

    // ---------- 内部 ----------

    private data class Instance(
        val item: ScheduleItem,
        val date: LocalDateTime,
        val occurrenceId: String,
        val isSeriesOverride: Boolean,
    )

    /**
     * 在闭区间内展开实例并按显示日去重（Dart `_buildScheduleInstances` +
     * `ScheduleItemExpander.putByDisplayDate`）。
     *
     * 停用的系列根会连同它的所有例外一起被跳过；根不存在时例外仍保留
     *（Dart 注释：`rootEnabledById` 只包含列表里真实存在的根）。
     */
    private fun buildInstances(
        items: List<ScheduleItem>,
        fromDate: LocalDate,
        toDate: LocalDate,
    ): List<Instance> {
        val rootEnabledById = HashMap<String, Boolean>()
        for (item in items) {
            if (item.seriesId == null) {
                rootEnabledById[item.id] = item.enabled
            }
        }
        val instancesByDisplayDate = LinkedHashMap<String, Instance>()
        for (item in items) {
            if (item.seriesId == null && !item.enabled) {
                continue
            }
            if (item.seriesId != null && rootEnabledById[item.seriesId] == false) {
                continue
            }
            expandItem(item, fromDate, toDate, instancesByDisplayDate)
        }
        return instancesByDisplayDate.values.toList()
    }

    private fun expandItem(
        item: ScheduleItem,
        fromDate: LocalDate,
        toDate: LocalDate,
        out: MutableMap<String, Instance>,
    ) {
        val start = item.startDate.toLocalDate()
        val end = item.endDate.toLocalDate()
        val first = if (fromDate.isAfter(start)) fromDate else start
        val last = if (toDate.isBefore(end)) toDate else end
        if (last.isBefore(first)) {
            return
        }
        val sourceItemId = item.seriesId ?: item.id
        var current = first
        while (!current.isAfter(last)) {
            val day = current.atStartOfDay()
            if (item.occursOn(day)) {
                val occurrenceDate = if (item.seriesId != null) {
                    item.occurrenceDate ?: day
                } else {
                    day
                }
                val occurrenceId = if (item.isRecurring || item.seriesId != null) {
                    ScheduleItem.buildOccurrenceId(sourceItemId, occurrenceDate)
                } else {
                    item.id
                }
                val instance = Instance(
                    item = item,
                    date = day,
                    occurrenceId = occurrenceId,
                    isSeriesOverride = item.seriesId != null,
                )
                putByDisplayDate(out, instance, sourceItemId)
            }
            current = current.plusDays(1)
        }
    }

    /**
     * 同一天同系列的实例只留一份；系列例外压住自然展开的那一次；
     * 两条例外撞在同一天时用 occurrenceId 做兄弟键各留一份。
     */
    private fun putByDisplayDate(
        out: MutableMap<String, Instance>,
        instance: Instance,
        sourceItemId: String,
    ) {
        val key = "$sourceItemId@${formatDate(instance.date)}"
        val existing = out[key]
        when {
            existing == null -> out[key] = instance
            instance.isSeriesOverride && !existing.isSeriesOverride -> out[key] = instance
            existing.isSeriesOverride && instance.isSeriesOverride ->
                out["$key#${instance.occurrenceId}"] = instance
            // 同为非例外的同系列同显示日 = 同一个自然实例被展开两次，丢弃即正确。
        }
    }

    /** Dart `_buildScheduleDateTime`：`HH:mm` 非法（位数不对 / 越界）返回 null。 */
    private fun buildDateTime(date: LocalDateTime, value: String): LocalDateTime? {
        val parts = value.trim().split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
            return null
        }
        return LocalDateTime.of(date.toLocalDate(), LocalTime.of(hour, minute))
    }

    /** Dart `_buildScheduleBody`：`开始-结束`，有地点再缀 ` · 地点`。 */
    private fun buildBody(item: ScheduleItem): String {
        val parts = mutableListOf("${item.startTime.trim()}-${item.endTime.trim()}")
        val location = item.location?.trim()
        if (!location.isNullOrEmpty()) {
            parts.add(location)
        }
        return parts.joinToString(" · ")
    }

    /**
     * 24 位散列空间下同一批响点可能撞码；撞了就必须换一个，否则
     * `PendingIntent.getBroadcast(..., FLAG_UPDATE_CURRENT)` 会让后写入的整条顶掉前一条，
     * 更早那条提醒静默丢失。分配结果只取决于响点集合本身（先排序再消解），
     * 同一批数据每次重建拿到同一套码。
     */
    private fun assignDistinctRequestCodes(
        fires: List<ScheduleReminderFire>,
    ): List<ScheduleReminderFire> {
        val ordered = fires.sortedWith(
            compareBy<ScheduleReminderFire> { it.scheduleId }
                .thenBy { it.offsetMinutes }
                .thenBy { it.fireAtEpochMillis },
        )
        val taken = HashSet<Int>()
        val result = ArrayList<ScheduleReminderFire>(ordered.size)
        for (fire in ordered) {
            var code = fire.requestCode
            if (taken.add(code)) {
                result.add(fire)
                continue
            }
            var probe = 0
            do {
                probe++
                code = stableRequestCode("${fire.scheduleId}#collision$probe", fire.offsetMinutes)
            } while (!taken.add(code))
            result.add(fire.copy(requestCode = code))
        }
        return result.sortedBy { it.fireAtEpochMillis }
    }

    private fun formatDate(date: LocalDateTime): String =
        "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
}
