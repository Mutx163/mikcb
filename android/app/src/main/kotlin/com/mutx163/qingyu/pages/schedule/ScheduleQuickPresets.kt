package com.mutx163.qingyu.pages.schedule

/**
 * 新建日程快捷模板模型（移植 `lib/domain/schedule_quick_presets.dart`）。
 */
data class ScheduleQuickPreset(
    val id: String,
    val icon: String,
    val colorHex: String,
    val durationMinutes: Int,
)

val kScheduleQuickPresets = listOf(
    ScheduleQuickPreset(
        id = "groupMeeting",
        icon = "groups",
        colorHex = "#6366F1",
        durationMinutes = 60,
    ),
    ScheduleQuickPreset(
        id = "lecture",
        icon = "lecture",
        colorHex = "#0EA5E9",
        durationMinutes = 90,
    ),
    ScheduleQuickPreset(
        id = "meeting",
        icon = "meeting",
        colorHex = "#2196F3",
        durationMinutes = 60,
    ),
    ScheduleQuickPreset(
        id = "defense",
        icon = "defense",
        colorHex = "#8B5CF6",
        durationMinutes = 60,
    ),
    ScheduleQuickPreset(
        id = "interview",
        icon = "interview",
        colorHex = "#D946EF",
        durationMinutes = 30,
    ),
    ScheduleQuickPreset(
        id = "dining",
        icon = "dining",
        colorHex = "#F97316",
        durationMinutes = 120,
    ),
    ScheduleQuickPreset(
        id = "workout",
        icon = "workout",
        colorHex = "#22C55E",
        durationMinutes = 60,
    ),
    ScheduleQuickPreset(
        id = "study",
        icon = "study",
        colorHex = "#14B8A6",
        durationMinutes = 120,
    ),
    ScheduleQuickPreset(
        id = "clinic",
        icon = "clinic",
        colorHex = "#EF4444",
        durationMinutes = 60,
    ),
    ScheduleQuickPreset(
        id = "commute",
        icon = "commute",
        colorHex = "#F59E0B",
        durationMinutes = 120,
    ),
)

data class PresetTimeWindow(
    val startMinutes: Int,
    val endMinutes: Int,
)

const val LAST_MINUTE_OF_DAY = 23 * 60 + 59

/**
 * 套用模板后的起止时刻计算（0～1439）。
 *
 * 若 [durationMinutes] 在当天塞不下，整段前移使得结束时刻落在 23:59（1439）。
 */
fun resolveSchedulePresetWindow(startMinutes: Int, durationMinutes: Int): PresetTimeWindow {
    val start = startMinutes.coerceIn(0, LAST_MINUTE_OF_DAY)
    if (durationMinutes <= 0) {
        return PresetTimeWindow(start, start)
    }
    val end = start + durationMinutes
    if (end <= LAST_MINUTE_OF_DAY) {
        return PresetTimeWindow(start, end)
    }
    val shiftedStart = LAST_MINUTE_OF_DAY - durationMinutes
    return PresetTimeWindow(
        startMinutes = maxOf(0, shiftedStart),
        endMinutes = LAST_MINUTE_OF_DAY,
    )
}

/**
 * 模板 ID 到其中文标题映射（对齐 ARB 原文）。
 */
fun scheduleQuickPresetTitle(presetId: String): String = when (presetId) {
    "groupMeeting" -> ScheduleStrings.scheduleQuickPresetGroupMeeting.text
    "lecture" -> ScheduleStrings.scheduleQuickPresetLecture.text
    "meeting" -> ScheduleStrings.scheduleQuickPresetMeeting.text
    "defense" -> ScheduleStrings.scheduleQuickPresetDefense.text
    "interview" -> ScheduleStrings.scheduleQuickPresetInterview.text
    "dining" -> ScheduleStrings.scheduleQuickPresetDining.text
    "workout" -> ScheduleStrings.scheduleQuickPresetWorkout.text
    "study" -> ScheduleStrings.scheduleQuickPresetStudy.text
    "clinic" -> ScheduleStrings.scheduleQuickPresetClinic.text
    "commute" -> ScheduleStrings.scheduleQuickPresetCommute.text
    else -> ""
}

/**
 * 当前仍然成立的快捷模板 ID：套用过、且标题没有被用户改掉。
 */
fun scheduleQuickPresetActiveId(appliedId: String?, currentTitle: String): String? {
    if (appliedId == null) return null
    val expected = scheduleQuickPresetTitle(appliedId)
    return if (expected.isNotEmpty() && currentTitle.trim() == expected) appliedId else null
}
