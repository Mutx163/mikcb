package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * `core.ScheduleItem`（落盘模型，`LocalDateTime`）↔ `ScheduleItemData`（渲染模型，ISO 字符串）的桥。
 *
 * 为什么单独一层：`core/` 是落盘契约（冻结格式），`pages/schedule/` 是渲染契约（页面只认字符串），
 * 两者字段语义一一对应但类型不同。把转换集中在这里，宿主层只调用、不各写一份，
 * 避免「列表页转一套、日视图转另一套」的漂移。
 *
 * 全部是纯函数、无 UI 依赖，放在 `main/pages/schedule/` 里可直接被 L0 覆盖。
 */
object ScheduleItemBridge {

    // ---------- 日程条目 ----------

    /** 落盘模型 → 渲染模型。 */
    fun toUiData(item: ScheduleItem): ScheduleItemData = ScheduleItemData(
        id = item.id,
        title = item.title,
        location = item.location,
        note = item.note,
        startDate = ScheduleItem.formatCalendarDate(item.startDate),
        endDate = ScheduleItem.formatCalendarDate(item.endDate),
        startTime = item.startTime,
        endTime = item.endTime,
        color = item.color,
        createdAt = "",
        updatedAt = "",
        recurrence = ScheduleRecurrence.fromValue(item.recurrence.value),
        exceptionDates = item.exceptionDates.map { ScheduleItem.formatCalendarDate(it) },
        reminderMinutesBefore = item.reminderMinutesBefore?.toInt(),
        enabled = item.enabled,
        seriesId = item.seriesId,
        occurrenceDate = item.occurrenceDate?.let { ScheduleItem.formatCalendarDate(it) },
    )

    /**
     * 渲染模型 → 落盘模型。
     *
     * @param preserveCreatedAt 编辑既有条目时传入原条目的 `createdAt`，避免「改一下 createdAt 就变成现在」。
     * @param now 注入时钟，便于 JVM 测试断言 `updatedAt`。
     */
    fun toCore(
        draft: ScheduleItemData,
        preserveCreatedAt: LocalDateTime? = null,
        now: LocalDateTime = LocalDateTime.now(),
    ): ScheduleItem {
        val startDate = parseDateIsoOrNull(draft.startDate)
            ?: LocalDateTime.of(now.toLocalDate(), LocalTime.MIDNIGHT)
        val endDate = parseDateIsoOrNull(draft.endDate) ?: startDate
        return ScheduleItem(
            id = draft.id,
            title = draft.title,
            location = draft.location,
            note = draft.note,
            startDate = startDate,
            endDate = endDate,
            startTime = draft.startTime,
            endTime = draft.endTime,
            color = draft.color,
            createdAt = preserveCreatedAt ?: now,
            updatedAt = now,
            recurrence = com.mutx163.qingyu.core.ScheduleRecurrence.fromValue(draft.recurrence.value),
            exceptionDates = draft.exceptionDates.mapNotNull { parseDateIsoOrNull(it) },
            reminderMinutesBefore = draft.reminderMinutesBefore?.toLong(),
            enabled = draft.enabled,
            seriesId = draft.seriesId,
            occurrenceDate = draft.occurrenceDate?.let { parseDateIsoOrNull(it) },
        )
    }

    /** 列表页三组（即将到来 / 已过期 / 已暂停）。 */
    fun buildListGroups(items: List<ScheduleItem>, todayIso: String): ScheduleListGroups =
        ScheduleListGrouper.group(items.map { toUiData(it) }, todayIso)

    // ---------- 日期规则 ----------

    fun toUiRule(rule: ScheduleDateRule): ScheduleDateRuleData = ScheduleDateRuleData(
        id = rule.id,
        name = rule.name,
        timeSchemeId = rule.timeSchemeId,
        startDate = rule.startDate,
        endDate = rule.endDate,
        enabled = rule.enabled,
    )

    fun toCoreRule(data: ScheduleDateRuleData): ScheduleDateRule = ScheduleDateRule(
        id = data.id,
        name = data.name,
        timeSchemeId = data.timeSchemeId,
        startDate = data.startDate,
        endDate = data.endDate,
        enabled = data.enabled,
    )

    /** 日期规则卡片视图（带「今天是否生效」与作息方案名）。 */
    fun buildDateRuleViews(
        rules: List<ScheduleDateRule>,
        schemeNames: Map<String, String>,
        todayIso: String,
    ): List<ScheduleDateRuleItemView> = rules.map { rule ->
        val ui = toUiRule(rule)
        ScheduleDateRuleItemView(
            rule = ui,
            schemeName = schemeNames[rule.timeSchemeId] ?: "",
            isActiveToday = ScheduleDateRuleDomain.isActiveOn(ui, todayIso),
        )
    }

    /** 保存规则时按 id upsert（新规则替换同 id，没有则追加）。 */
    fun upsertRule(rules: MutableList<ScheduleDateRuleData>, incoming: ScheduleDateRuleData) {
        val index = rules.indexOfFirst { it.id == incoming.id }
        if (index >= 0) rules[index] = incoming else rules.add(incoming)
    }

    // ---------- 内部 ----------

    private fun parseDateIsoOrNull(raw: String): LocalDateTime? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        return try {
            LocalDateTime.of(LocalDate.parse(trimmed), LocalTime.MIDNIGHT)
        } catch (_: Exception) {
            null
        }
    }
}
