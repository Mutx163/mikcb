package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimetableProfile
import java.time.LocalDateTime

/**
 * 日程（安排事项）族需要的最小宿主面（纯逻辑端口，无 IO）。
 *
 * 逐条移植自 Dart `lib/services/timetable_schedule_item_service.dart` 的
 * `TimetableScheduleItemPort`：内存里的日程列表与档案列表、初始化、落盘、通知、埋点、提醒同步。
 * `TimetableRepository` 已实现其中大部分成员（继承自 `TimetableCoursePort`），
 * 本接口只额外要求一个 [scheduleItems] 属性。
 */
interface TimetableScheduleItemPort {
    var scheduleItems: List<ScheduleItem>
    var profiles: List<TimetableProfile>

    fun initialize()

    /** 把当前设置与活动档案落盘；失败时抛错，由服务回滚内存。 */
    fun persistActiveProfileState()

    fun notifyStateChanged()

    fun logEvent(name: String, parameters: Map<String, Any>)

    /** 日程改动会影响考试提醒的派生列表，写完后重新同步原生提醒（Phase 4 前是空实现）。 */
    fun syncExamReminders()
}

/** 一个「日程实例」的定位：源条目 + 发生日 + （可选）覆盖行原日期。 */
data class ScheduleItemInstance(
    val item: ScheduleItem,
    val date: LocalDateTime,
    val occurrenceDate: LocalDateTime? = null,
) {
    /** 源条目 id（覆盖行取 seriesId，否则取自身 id）。 */
    val sourceItemId: String get() = item.seriesId ?: item.id

    /** 实际发生日：覆盖行优先取 occurrenceDate。 */
    val effectiveOccurrenceDate: LocalDateTime get() = item.occurrenceDate ?: date
}

/**
 * 日程（安排事项）族的读写实现 —— **只有这一份定义**。
 *
 * 逐条移植自 Dart `lib/services/timetable_schedule_item_service.dart`（488 行）。
 * 关键语义（都是「写错就是用户数据丢/错」的地方）：
 *
 * - **[update] 改系列根 = 改全部**：会把该系列的所有「单次覆盖行」一起摘掉（Dart :188-192）；
 *   落盘失败要把被连带摘掉的覆盖行一起退回内存（Dart :203-210）。
 * - **[delete] 连根带覆盖整系列摘除**：按 `seriesId ?? id` 判（Dart :228-231）。
 * - **[updateOccurrence] / [deleteOccurrence] 只动一次**：根条目记一条 exception，
 *   覆盖行以 `seriesId@yyyy-MM-dd` 为 id；绝不误删整个系列。
 * - **[normalize] 只 trim 文本、归一日期**，**不碰钟点**（外来 `9:00` 原样收下，排序另有钟点比较）。
 */
object ScheduleItemService {

    /** 日程列表的**存量顺序**（写入口与读盘装配都会经过它，Dart :56-73）。 */
    fun sort(source: List<ScheduleItem>): List<ScheduleItem> =
        source.sortedWith { left, right ->
            val dateCompare = left.startDate.compareTo(right.startDate)
            if (dateCompare != 0) return@sortedWith dateCompare
            val startCompare = compareClockText(left.startTime, right.startTime)
            if (startCompare != 0) return@sortedWith startCompare
            val endCompare = compareClockText(left.endTime, right.endTime)
            if (endCompare != 0) return@sortedWith endCompare
            left.id.compareTo(right.id)
        }

    /** 落盘前的归一（Dart :76-98）：trim 文本、空串当没有、日期压到「日」、结束日钳到不早于开始日。 */
    fun normalize(item: ScheduleItem): ScheduleItem {
        val normalizedStart = ScheduleItem.dateOnly(item.startDate)
        val normalizedEndRaw = ScheduleItem.dateOnly(item.endDate)
        return item.copy(
            title = item.title.trim(),
            location = item.location?.trim()?.takeIf { it.isNotEmpty() },
            note = item.note?.trim()?.takeIf { it.isNotEmpty() },
            startDate = normalizedStart,
            endDate = if (normalizedEndRaw.isBefore(normalizedStart)) normalizedStart else normalizedEndRaw,
        )
    }

    fun find(port: TimetableScheduleItemPort, itemId: String): ScheduleItem? =
        port.scheduleItems.firstOrNull { it.id == itemId }

    /** 目标所属系列的根条目（`seriesId ?? id`，Dart :109-118）。 */
    fun seriesRoot(port: TimetableScheduleItemPort, target: ScheduleItem?): ScheduleItem? {
        if (target == null) return null
        val rootId = target.seriesId ?: target.id
        return find(port, rootId)
    }

    /** 按稳定 occurrenceId（`rootId@yyyy-MM-dd` 或覆盖行 id）定位实例（Dart :120-152）。 */
    fun findInstanceById(port: TimetableScheduleItemPort, occurrenceId: String): ScheduleItemInstance? {
        for (item in port.scheduleItems) {
            if (item.id != occurrenceId) continue
            if (item.seriesId != null) {
                val date = item.occurrenceDate ?: item.startDate
                return ScheduleItemInstance(item = item, date = item.startDate, occurrenceDate = date)
            }
            if (!item.isRecurring) {
                return ScheduleItemInstance(item = item, date = item.startDate)
            }
        }
        val separatorIndex = occurrenceId.lastIndexOf('@')
        if (separatorIndex <= 0 || separatorIndex == occurrenceId.length - 1) return null
        val sourceId = occurrenceId.substring(0, separatorIndex)
        val date = ScheduleItem.dateOnly(
            com.mutx163.qingyu.core.DartTime.tryParseIso(occurrenceId.substring(separatorIndex + 1)) ?: return null,
        )
        val source = find(port, sourceId) ?: return null
        return ScheduleItemInstance(item = source, date = date)
    }

    /** 新增一条日程（Dart :154-171）。 */
    fun add(port: TimetableScheduleItemPort, item: ScheduleItem) {
        port.initialize()
        val normalized = normalize(item)
        port.scheduleItems = sort(port.scheduleItems + normalized)
        port.persistActiveProfileState()
        port.notifyStateChanged()
        port.logEvent(
            "schedule_item_created",
            mapOf(
                "has_location" to if (!normalized.location.isNullOrEmpty()) 1 else 0,
                "has_note" to if (!normalized.note.isNullOrEmpty()) 1 else 0,
            ),
        )
        port.syncExamReminders()
    }

    /**
     * 更新一条日程（Dart :173-217）。
     *
     * 若被改的是**系列根**（`seriesId == null`），按系列语义会把该系列的所有单次覆盖行一起摘掉；
     * 落盘失败时把覆盖行一并退回，避免「编辑报了失败、单独改过的几次却自己消失」。
     */
    fun update(port: TimetableScheduleItemPort, item: ScheduleItem) {
        port.initialize()
        val index = port.scheduleItems.indexOfFirst { it.id == item.id }
        if (index == -1) return

        val normalized = normalize(item)
        val nextItems = port.scheduleItems.toMutableList()
        val existing = nextItems[index]
        if (existing.seriesId == null) {
            // 改系列根 = 改全部：单次覆盖行被这次系列操作刻意丢弃。
            nextItems.removeAll { it.seriesId == existing.id }
        }
        val nextIndex = nextItems.indexOfFirst { it.id == existing.id }
        if (nextIndex == -1) return
        nextItems[nextIndex] = normalized

        val snapshotItems = port.scheduleItems
        val snapshotProfiles = port.profiles
        port.scheduleItems = sort(nextItems)
        try {
            port.persistActiveProfileState()
        } catch (t: Throwable) {
            // 被系列语义连带摘掉的覆盖行也要一起退回来。
            port.scheduleItems = snapshotItems
            port.profiles = snapshotProfiles
            throw t
        }
        port.notifyStateChanged()
        port.logEvent(
            "schedule_item_updated",
            mapOf(
                "has_location" to if (!normalized.location.isNullOrEmpty()) 1 else 0,
                "has_note" to if (!normalized.note.isNullOrEmpty()) 1 else 0,
            ),
        )
        port.syncExamReminders()
    }

    /** 删除整条（按 `seriesId ?? id` 连根带覆盖，Dart :219-252）。 */
    fun delete(port: TimetableScheduleItemPort, itemId: String) {
        port.initialize()
        val target = find(port, itemId) ?: return
        val seriesId = target.seriesId ?: target.id
        val previousCount = port.scheduleItems.size
        val nextItems = port.scheduleItems.filter { it.id != seriesId && it.seriesId != seriesId }
        if (nextItems.size == previousCount) return

        val snapshotItems = port.scheduleItems
        val snapshotProfiles = port.profiles
        port.scheduleItems = nextItems
        try {
            port.persistActiveProfileState()
        } catch (t: Throwable) {
            port.scheduleItems = snapshotItems
            port.profiles = snapshotProfiles
            throw t
        }
        port.notifyStateChanged()
        port.logEvent("schedule_item_deleted", mapOf("remaining_schedule_item_count" to port.scheduleItems.size))
        port.syncExamReminders()
    }

    /**
     * 只删除某一次发生，保留系列其余（Dart :254-313）。
     *
     * - 单日一次性日程删掉这一次 = 整条消失（走 [delete]）。
     * - 否则在根条目上补一条 exception，并摘掉该次对应的覆盖行。
     */
    fun deleteOccurrence(port: TimetableScheduleItemPort, itemId: String, occurrenceDate: LocalDateTime) {
        port.initialize()
        val target = find(port, itemId)
        val root = seriesRoot(port, target) ?: return

        val requestedDate = if (target?.seriesId != null && target.occurrenceDate != null) {
            target.occurrenceDate
        } else {
            ScheduleItem.dateOnly(occurrenceDate)
        }
        val hasOverride = port.scheduleItems.any { isOverrideForOccurrence(it, root.id, requestedDate) }
        if (!root.occursOn(requestedDate) && !hasOverride) return

        // 单日一次性日程：删这一次就是整条消失。
        if (root.seriesId == null &&
            root.recurrence == com.mutx163.qingyu.core.ScheduleRecurrence.NONE &&
            isSameDate(root.startDate, root.endDate) &&
            isSameDate(root.startDate, requestedDate)
        ) {
            delete(port, root.id)
            return
        }

        val updatedRoot = root.copy(
            exceptionDates = normalizedExceptionDates(root.exceptionDates, requestedDate),
            updatedAt = LocalDateTime.now(),
        )
        val nextItems = mutableListOf<ScheduleItem>()
        for (item in port.scheduleItems) {
            if (item.id == root.id) {
                nextItems.add(updatedRoot)
            } else if (isOverrideForOccurrence(item, root.id, requestedDate)) {
                continue
            } else {
                nextItems.add(item)
            }
        }
        port.scheduleItems = sort(nextItems)
        port.persistActiveProfileState()
        port.notifyStateChanged()
        port.logEvent(
            "schedule_item_occurrence_deleted",
            mapOf(
                "schedule_item_id" to root.id,
                "occurrence_date" to ScheduleItem.formatCalendarDate(requestedDate),
            ),
        )
        port.syncExamReminders()
    }

    /**
     * 只修改某一次发生：用一条持久化的单次覆盖行替换它，根条目记 exception（Dart :315-402）。
     *
     * @param dateWasExplicitlyEdited 用户把这次发生**显式移到**与系列起点同一天时为 true，
     *   用于与「编辑器沿用系列起点当哨兵」区分（Dart :450-465）。
     */
    fun updateOccurrence(
        port: TimetableScheduleItemPort,
        itemId: String,
        occurrenceDate: LocalDateTime,
        updatedItem: ScheduleItem,
        dateWasExplicitlyEdited: Boolean = false,
    ) {
        port.initialize()
        val target = find(port, itemId)
        val root = seriesRoot(port, target) ?: return

        val requestedDate = if (target?.seriesId != null && target.occurrenceDate != null) {
            target.occurrenceDate
        } else {
            ScheduleItem.dateOnly(occurrenceDate)
        }
        val existingOverride = port.scheduleItems.any { isOverrideForOccurrence(it, root.id, requestedDate) }
        if (!root.occursOn(requestedDate) && !existingOverride) return

        // 单日一次性日程改这一次 = 直接更新原行，保留既有 id，不制造多余覆盖。
        if (root.seriesId == null &&
            root.recurrence == com.mutx163.qingyu.core.ScheduleRecurrence.NONE &&
            isSameDate(root.startDate, root.endDate) &&
            isSameDate(root.startDate, requestedDate)
        ) {
            update(port, updatedItem.copy(id = root.id))
            return
        }

        val effectiveDate = resolveOccurrenceEditDate(root, requestedDate, updatedItem, dateWasExplicitlyEdited)
        val overrideId = ScheduleItem.buildOccurrenceId(root.id, requestedDate)
        val override = normalize(
            updatedItem.copy(
                id = overrideId,
                startDate = effectiveDate,
                endDate = effectiveDate,
                recurrence = com.mutx163.qingyu.core.ScheduleRecurrence.NONE,
                exceptionDates = emptyList(),
                seriesId = root.id,
                occurrenceDate = requestedDate,
            ),
        )
        val updatedRoot = root.copy(
            exceptionDates = normalizedExceptionDates(root.exceptionDates, requestedDate),
            updatedAt = LocalDateTime.now(),
        )
        val nextItems = mutableListOf<ScheduleItem>()
        for (item in port.scheduleItems) {
            if (item.id == root.id) {
                nextItems.add(updatedRoot)
            } else if (isOverrideForOccurrence(item, root.id, requestedDate)) {
                continue
            } else {
                nextItems.add(item)
            }
        }
        nextItems.add(override)
        port.scheduleItems = sort(nextItems)
        port.persistActiveProfileState()
        port.notifyStateChanged()
        port.logEvent(
            "schedule_item_occurrence_updated",
            mapOf(
                "schedule_item_id" to root.id,
                "occurrence_date" to ScheduleItem.formatCalendarDate(requestedDate),
            ),
        )
        port.syncExamReminders()
    }

    /** 按稳定 occurrenceId 删除一次（Dart :404-415）。 */
    fun deleteInstance(port: TimetableScheduleItemPort, occurrenceId: String) {
        port.initialize()
        val instance = findInstanceById(port, occurrenceId) ?: return
        deleteOccurrence(port, instance.sourceItemId, instance.effectiveOccurrenceDate)
    }

    /** 按稳定 occurrenceId 更新一次（Dart :417-436）。 */
    fun updateInstance(
        port: TimetableScheduleItemPort,
        occurrenceId: String,
        updatedItem: ScheduleItem,
        dateWasExplicitlyEdited: Boolean = false,
    ) {
        port.initialize()
        val instance = findInstanceById(port, occurrenceId) ?: return
        updateOccurrence(port, instance.sourceItemId, instance.effectiveOccurrenceDate, updatedItem, dateWasExplicitlyEdited)
    }

    // ---------- 内部 ----------

    private fun isOverrideForOccurrence(item: ScheduleItem, seriesId: String, occurrenceDate: LocalDateTime): Boolean {
        if (item.seriesId != seriesId) return false
        val candidateDate = item.occurrenceDate ?: item.startDate
        return isSameDate(candidateDate, occurrenceDate)
    }

    private fun resolveOccurrenceEditDate(
        root: ScheduleItem,
        occurrenceDate: LocalDateTime,
        updatedItem: ScheduleItem,
        dateWasExplicitlyEdited: Boolean,
    ): LocalDateTime {
        val requestedDate = ScheduleItem.dateOnly(updatedItem.startDate)
        // 编辑器通常把系列起点原样带回来：未显式改日期时视为「保持这次发生的日期」。
        if (!dateWasExplicitlyEdited && isSameDate(requestedDate, root.startDate)) {
            return ScheduleItem.dateOnly(occurrenceDate)
        }
        return requestedDate
    }

    private fun normalizedExceptionDates(existing: List<LocalDateTime>, candidate: LocalDateTime): List<LocalDateTime> {
        val normalizedCandidate = ScheduleItem.dateOnly(candidate)
        val merged = linkedMapOf<String, LocalDateTime>()
        for (date in existing) {
            val normalized = ScheduleItem.dateOnly(date)
            merged[ScheduleItem.formatCalendarDate(normalized)] = normalized
        }
        merged[ScheduleItem.formatCalendarDate(normalizedCandidate)] = normalizedCandidate
        return merged.values.sorted()
    }

    private fun isSameDate(left: LocalDateTime, right: LocalDateTime): Boolean =
        left.year == right.year && left.monthValue == right.monthValue && left.dayOfMonth == right.dayOfMonth

    /** 钟点比较：`9:00` 与 `10:00` 必须按分钟序，不能按字典序（Dart clock_order.dart 正源）。 */
    private fun compareClockText(left: String, right: String): Int =
        clockMinutesLenient(left).compareTo(clockMinutesLenient(right))

    private fun clockMinutesLenient(value: String): Int {
        val parts = value.trim().split(":")
        if (parts.size != 2) return 0
        val hour = parts[0].toIntOrNull() ?: return 0
        val minute = parts[1].toIntOrNull() ?: return 0
        if (minute !in 0..59) return 0
        return hour * 60 + minute
    }
}

/**
 * 保存 / 删除的**分派判据**（纯 Kotlin，可单测）。
 *
 * 逐条对齐 Dart `add_schedule_item_screen.dart:848-902`（保存）与 `:970-1024`（删除）：
 * 先由页面（重复日程）问「改这一次 / 改全部」，再按 [applyToAll] 与「是否正在编辑某一次发生」分流。
 */
object ScheduleEditDispatcher {

    /**
     * @param isNew 新建（仓储里还没有这个 id）
     * @param isOccurrenceEditing 正在编辑「某一次发生」（页面带了 occurrenceDate）
     * @param applyToAll 页面的范围选择：null = 非重复/非单次编辑，true = 全部，false = 只这一次
     */
    fun save(
        port: TimetableScheduleItemPort,
        item: ScheduleItem,
        isNew: Boolean,
        isOccurrenceEditing: Boolean,
        applyToAll: Boolean?,
    ) {
        when {
            isNew -> ScheduleItemService.add(port, item)
            isOccurrenceEditing && applyToAll != true ->
                ScheduleItemService.updateOccurrence(
                    port,
                    item.id,
                    item.occurrenceDate ?: item.startDate,
                    item,
                )
            else -> ScheduleItemService.update(port, item)
        }
    }

    /**
     * @param applyToAll 页面范围选择：null = 非单次编辑，true = 删全部，false = 只删这一次
     */
    fun delete(
        port: TimetableScheduleItemPort,
        item: ScheduleItem,
        isOccurrenceEditing: Boolean,
        applyToAll: Boolean?,
    ) {
        val occurrence = item.occurrenceDate
        if (isOccurrenceEditing && applyToAll == false && occurrence != null) {
            ScheduleItemService.deleteOccurrence(port, item.id, occurrence)
        } else {
            ScheduleItemService.delete(port, item.id)
        }
    }
}
