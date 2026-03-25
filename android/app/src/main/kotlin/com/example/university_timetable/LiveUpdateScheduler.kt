package com.example.university_timetable

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

private data class NativeSectionTime(
    val startTime: String,
    val endTime: String,
)

private data class NativeCourse(
    val id: String,
    val name: String,
    val shortName: String?,
    val teacher: String,
    val location: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String,
    val startWeek: Int,
    val endWeek: Int,
    val isOddWeek: Boolean,
    val isEvenWeek: Boolean,
    val note: String?,
) {
    fun isInWeek(week: Int): Boolean {
        if (week < startWeek || week > endWeek) {
            return false
        }
        if (isOddWeek && week % 2 == 0) {
            return false
        }
        if (isEvenWeek && week % 2 != 0) {
            return false
        }
        return true
    }
}

private data class NativeLiveSettings(
    val sections: List<NativeSectionTime>,
    val liveShowCourseName: Boolean,
    val liveShowLocation: Boolean,
    val liveShowCountdown: Boolean,
    val liveEnableBeforeClass: Boolean,
    val liveEnableDuringClass: Boolean,
    val liveEnableBeforeEnd: Boolean,
    val livePromoteDuringClass: Boolean,
    val liveShowDuringClassNotification: Boolean,
    val liveUseShortName: Boolean,
    val liveHidePrefixText: Boolean,
    val liveDuringClassTimeDisplayMode: String,
    val liveEnableMiuiIslandLabelImage: Boolean,
    val liveMiuiIslandLabelStyle: String,
    val liveMiuiIslandLabelContent: String,
    val liveMiuiIslandLabelFontSize: Float,
    val liveMiuiIslandExpandedIconMode: String,
    val liveMiuiIslandExpandedIconPath: String?,
    val liveShowBeforeClassMinutes: Int,
    val liveClassReminderStartMinutes: Int,
    val liveEndSecondsCountdownThreshold: Int,
)

private data class NativeScheduleSnapshot(
    val currentWeek: Int,
    val semesterStartMillis: Long?,
    val endReminderLeadMillis: Long,
    val courses: List<NativeCourse>,
    val settings: NativeLiveSettings,
)

private data class ScheduledSelection(
    val currentCourse: NativeCourse,
    val nextCourse: NativeCourse?,
    val stage: String,
    val triggerAtMillis: Long,
    val startAtMillis: Long,
    val endAtMillis: Long,
    val progressBreakOffsetsMillis: LongArray,
    val progressMilestoneLabels: List<String>,
    val progressMilestoneTimeTexts: List<String>,
)

private data class FutureStageTrigger(
    val stage: String,
    val triggerAtMillis: Long,
)

private data class LiveUpdatePayload(
    val currentCourse: NativeCourse,
    val nextCourse: NativeCourse?,
    val stage: String,
    val startAtMillis: Long,
    val endAtMillis: Long,
    val beforeClassLeadMillis: Long,
    val endReminderLeadMillis: Long,
    val liveClassReminderStartMinutes: Int,
    val endSecondsCountdownThreshold: Int,
    val enableBeforeClass: Boolean,
    val enableDuringClass: Boolean,
    val enableBeforeEnd: Boolean,
    val promoteDuringClass: Boolean,
    val showNotificationDuringClass: Boolean,
    val showCountdown: Boolean,
    val showCourseNameInIsland: Boolean,
    val showLocationInIsland: Boolean,
    val useShortNameInIsland: Boolean,
    val hidePrefixText: Boolean,
    val duringClassTimeDisplayMode: String,
    val enableMiuiIslandLabelImage: Boolean,
    val miuiIslandLabelStyle: String,
    val miuiIslandLabelContent: String,
    val miuiIslandLabelFontSize: Float,
    val miuiIslandExpandedIconMode: String,
    val miuiIslandExpandedIconPath: String?,
    val progressBreakOffsetsMillis: LongArray,
    val progressMilestoneLabels: List<String>,
    val progressMilestoneTimeTexts: List<String>,
)

object LiveUpdateScheduler {
    private const val TAG = "LiveUpdateScheduler"
    private const val PREFS_NAME = "live_update_scheduler"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    private const val REQUEST_CODE_TRIGGER = 2002
    const val ACTION_TRIGGER = "com.example.university_timetable.ACTION_TRIGGER_LIVE_UPDATE"

    fun syncSnapshot(context: Context, snapshotJson: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, snapshotJson)
            .apply()
        reschedule(context, allowImmediateStart = false)
    }

    fun clearSnapshot(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT_JSON)
            .apply()
        cancelScheduledAlarm(context)
    }

    fun handleAlarm(context: Context) {
        reschedule(context, allowImmediateStart = true)
    }

    fun handleSystemReschedule(context: Context) {
        reschedule(context, allowImmediateStart = true)
    }

    fun onLiveUpdateStopped(context: Context) {
        reschedule(context, allowImmediateStart = false)
    }

    fun buildServiceIntentFromMethodPayload(
        context: Context,
        data: Map<String, Any>,
    ): Intent {
        val current = data["currentCourse"] as? Map<String, Any> ?: emptyMap()
        val next = data["nextCourse"] as? Map<String, Any>
        val islandConfig = data["islandConfig"] as? Map<String, Any> ?: emptyMap()
        val progressBreakOffsetsMillis =
            (data["progressBreakOffsetsMillis"] as? List<*>)?.mapNotNull {
                (it as? Number)?.toLong()
            }?.toLongArray() ?: longArrayOf()
        val progressMilestoneLabels =
            (data["progressMilestoneLabels"] as? List<*>)?.mapNotNull { it as? String }
                ?: emptyList()
        val progressMilestoneTimeTexts =
            (data["progressMilestoneTimeTexts"] as? List<*>)?.mapNotNull { it as? String }
                ?: emptyList()

        val payload = LiveUpdatePayload(
            currentCourse = mapToNativeCourse(current),
            nextCourse = next?.let(::mapToNativeCourse),
            stage = data["stage"] as? String ?: "",
            startAtMillis = (data["startAtMillis"] as? Number)?.toLong() ?: 0L,
            endAtMillis = (data["endAtMillis"] as? Number)?.toLong() ?: 0L,
            beforeClassLeadMillis = (data["beforeClassLeadMillis"] as? Number)?.toLong() ?: 0L,
            endReminderLeadMillis = (data["endReminderLeadMillis"] as? Number)?.toLong()
                ?: 600_000L,
            liveClassReminderStartMinutes =
                (data["liveClassReminderStartMinutes"] as? Number)?.toInt() ?: 0,
            endSecondsCountdownThreshold =
                (data["endSecondsCountdownThreshold"] as? Number)?.toInt() ?: 60,
            enableBeforeClass = data["enableBeforeClass"] as? Boolean ?: true,
            enableDuringClass = data["enableDuringClass"] as? Boolean ?: true,
            enableBeforeEnd = data["enableBeforeEnd"] as? Boolean ?: true,
            promoteDuringClass = data["promoteDuringClass"] as? Boolean ?: true,
            showNotificationDuringClass =
                data["showNotificationDuringClass"] as? Boolean ?: true,
            showCountdown = data["showCountdown"] as? Boolean ?: true,
            showCourseNameInIsland = islandConfig["showCourseName"] as? Boolean ?: true,
            showLocationInIsland = islandConfig["showLocation"] as? Boolean ?: true,
            useShortNameInIsland = islandConfig["useShortName"] as? Boolean ?: false,
            hidePrefixText = islandConfig["hidePrefixText"] as? Boolean ?: false,
            duringClassTimeDisplayMode =
                islandConfig["duringClassTimeDisplayMode"] as? String ?: "nearest",
            enableMiuiIslandLabelImage =
                islandConfig["enableMiuiIslandLabelImage"] as? Boolean ?: false,
            miuiIslandLabelStyle =
                islandConfig["miuiIslandLabelStyle"] as? String ?: "text_only",
            miuiIslandLabelContent =
                islandConfig["miuiIslandLabelContent"] as? String ?: "course_name",
            miuiIslandLabelFontSize =
                (islandConfig["miuiIslandLabelFontSize"] as? Number)?.toFloat() ?: 14f,
            miuiIslandExpandedIconMode =
                islandConfig["miuiIslandExpandedIconMode"] as? String ?: "app_icon",
            miuiIslandExpandedIconPath =
                islandConfig["miuiIslandExpandedIconPath"] as? String,
            progressBreakOffsetsMillis = progressBreakOffsetsMillis,
            progressMilestoneLabels = progressMilestoneLabels,
            progressMilestoneTimeTexts = progressMilestoneTimeTexts,
        )
        return buildServiceIntent(context, payload)
    }

    fun reschedule(context: Context, allowImmediateStart: Boolean): Boolean {
        cancelScheduledAlarm(context)
        val snapshot = loadSnapshot(context) ?: return false
        val now = System.currentTimeMillis()
        val activeSelection = findActiveSelection(snapshot, now)
        if (allowImmediateStart && activeSelection != null) {
            startForegroundService(context, selectionToPayload(snapshot, activeSelection))
            return true
        }

        val nextSelection = findNextSelection(snapshot, now) ?: return false
        scheduleAlarm(context, nextSelection.triggerAtMillis)
        return false
    }

    private fun loadSnapshot(context: Context): NativeScheduleSnapshot? {
        val snapshotJson = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null) ?: return null
        return try {
            parseSnapshot(JSONObject(snapshotJson))
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse snapshot", e)
            null
        }
    }

    private fun parseSnapshot(json: JSONObject): NativeScheduleSnapshot {
        val settingsJson = json.optJSONObject("settings") ?: JSONObject()
        val sectionsJson = settingsJson.optJSONArray("sections") ?: JSONArray()
        val sections = mutableListOf<NativeSectionTime>()
        for (index in 0 until sectionsJson.length()) {
            val sectionJson = sectionsJson.optJSONObject(index) ?: continue
            sections += NativeSectionTime(
                startTime = sectionJson.optString("startTime"),
                endTime = sectionJson.optString("endTime"),
            )
        }
        val settings = NativeLiveSettings(
            sections = sections,
            liveShowCourseName = settingsJson.optBoolean("liveShowCourseName", true),
            liveShowLocation = settingsJson.optBoolean("liveShowLocation", true),
            liveShowCountdown = settingsJson.optBoolean("liveShowCountdown", true),
            liveEnableBeforeClass = settingsJson.optBoolean("liveEnableBeforeClass", true),
            liveEnableDuringClass = settingsJson.optBoolean("liveEnableDuringClass", true),
            liveEnableBeforeEnd = settingsJson.optBoolean("liveEnableBeforeEnd", true),
            livePromoteDuringClass = settingsJson.optBoolean("livePromoteDuringClass", true),
            liveShowDuringClassNotification =
                settingsJson.optBoolean("liveShowDuringClassNotification", true),
            liveUseShortName = settingsJson.optBoolean("liveUseShortName", true),
            liveHidePrefixText = settingsJson.optBoolean("liveHidePrefixText", false),
            liveDuringClassTimeDisplayMode =
                settingsJson.optString("liveDuringClassTimeDisplayMode", "nearest"),
            liveEnableMiuiIslandLabelImage =
                settingsJson.optBoolean("liveEnableMiuiIslandLabelImage", false),
            liveMiuiIslandLabelStyle =
                settingsJson.optString("liveMiuiIslandLabelStyle", "text_only"),
            liveMiuiIslandLabelContent =
                settingsJson.optString("liveMiuiIslandLabelContent", "course_name"),
            liveMiuiIslandLabelFontSize =
                settingsJson.optDouble("liveMiuiIslandLabelFontSize", 14.0).toFloat(),
            liveMiuiIslandExpandedIconMode =
                settingsJson.optString("liveMiuiIslandExpandedIconMode", "app_icon"),
            liveMiuiIslandExpandedIconPath =
                settingsJson.optString("liveMiuiIslandExpandedIconPath").takeIf { it.isNotBlank() },
            liveShowBeforeClassMinutes = settingsJson.optInt("liveShowBeforeClassMinutes", 20),
            liveClassReminderStartMinutes =
                settingsJson.optInt("liveClassReminderStartMinutes", 0),
            liveEndSecondsCountdownThreshold =
                settingsJson.optInt("liveEndSecondsCountdownThreshold", 60),
        )

        val coursesJson = json.optJSONArray("courses") ?: JSONArray()
        val courses = mutableListOf<NativeCourse>()
        for (index in 0 until coursesJson.length()) {
            val courseJson = coursesJson.optJSONObject(index) ?: continue
            courses += NativeCourse(
                id = courseJson.optString("id"),
                name = courseJson.optString("name"),
                shortName = courseJson.optString("shortName").ifBlank { null },
                teacher = courseJson.optString("teacher"),
                location = courseJson.optString("location"),
                dayOfWeek = courseJson.optInt("dayOfWeek", 1),
                startSection = courseJson.optInt("startSection", 1),
                endSection = courseJson.optInt("endSection", 1),
                startTime = courseJson.optString("startTime"),
                endTime = courseJson.optString("endTime"),
                startWeek = courseJson.optInt("startWeek", 1),
                endWeek = courseJson.optInt("endWeek", 16),
                isOddWeek = courseJson.optBoolean("isOddWeek", false),
                isEvenWeek = courseJson.optBoolean("isEvenWeek", false),
                note = courseJson.optString("note").ifBlank { null },
            )
        }

        return NativeScheduleSnapshot(
            currentWeek = json.optInt("currentWeek", 1),
            semesterStartMillis = json.optLong("semesterStartMillis").takeIf { it > 0L },
            endReminderLeadMillis = json.optLong("endReminderLeadMillis", 600_000L),
            courses = courses,
            settings = settings,
        )
    }

    private fun buildServiceIntent(context: Context, payload: LiveUpdatePayload): Intent {
        return Intent(context, LiveUpdateService::class.java).apply {
            putExtra("courseName", payload.currentCourse.name)
            putExtra("shortName", payload.currentCourse.shortName ?: "")
            putExtra("location", payload.currentCourse.location)
            putExtra("teacher", payload.currentCourse.teacher)
            putExtra("note", payload.currentCourse.note ?: "")
            putExtra("startTime", payload.currentCourse.startTime)
            putExtra("endTime", payload.currentCourse.endTime)
            putExtra("nextName", payload.nextCourse?.name ?: "")
            putExtra("autoDismissAfterStartMinutes", 0)
            putExtra("stage", payload.stage)
            putExtra("beforeClassLeadMillis", payload.beforeClassLeadMillis)
            putExtra("startAtMillis", payload.startAtMillis)
            putExtra("endAtMillis", payload.endAtMillis)
            putExtra("endReminderLeadMillis", payload.endReminderLeadMillis)
            putExtra("liveClassReminderStartMinutes", payload.liveClassReminderStartMinutes)
            putExtra(
                "endSecondsCountdownThreshold",
                payload.endSecondsCountdownThreshold
            )
            putExtra("enableBeforeClass", payload.enableBeforeClass)
            putExtra("enableDuringClass", payload.enableDuringClass)
            putExtra("enableBeforeEnd", payload.enableBeforeEnd)
            putExtra("promoteDuringClass", payload.promoteDuringClass)
            putExtra(
                "showNotificationDuringClass",
                payload.showNotificationDuringClass
            )
            putExtra("showCountdown", payload.showCountdown)
            putExtra("progressBreakOffsetsMillis", payload.progressBreakOffsetsMillis)
            putStringArrayListExtra(
                "progressMilestoneLabels",
                ArrayList(payload.progressMilestoneLabels)
            )
            putStringArrayListExtra(
                "progressMilestoneTimeTexts",
                ArrayList(payload.progressMilestoneTimeTexts)
            )
            putExtra("showCourseNameInIsland", payload.showCourseNameInIsland)
            putExtra("showLocationInIsland", payload.showLocationInIsland)
            putExtra("useShortNameInIsland", payload.useShortNameInIsland)
            putExtra("hidePrefixText", payload.hidePrefixText)
            putExtra("duringClassTimeDisplayMode", payload.duringClassTimeDisplayMode)
            putExtra("enableMiuiIslandLabelImage", payload.enableMiuiIslandLabelImage)
            putExtra("miuiIslandLabelStyle", payload.miuiIslandLabelStyle)
            putExtra("miuiIslandLabelContent", payload.miuiIslandLabelContent)
            putExtra("miuiIslandLabelFontSize", payload.miuiIslandLabelFontSize)
            putExtra("miuiIslandExpandedIconMode", payload.miuiIslandExpandedIconMode)
            putExtra("miuiIslandExpandedIconPath", payload.miuiIslandExpandedIconPath)
        }
    }

    private fun mapToNativeCourse(data: Map<String, Any>): NativeCourse {
        return NativeCourse(
            id = data["id"] as? String ?: "",
            name = data["name"] as? String ?: "",
            shortName = (data["shortName"] as? String)?.ifBlank { null },
            teacher = data["teacher"] as? String ?: "",
            location = data["location"] as? String ?: "",
            dayOfWeek = (data["dayOfWeek"] as? Number)?.toInt() ?: 1,
            startSection = (data["startSection"] as? Number)?.toInt() ?: 1,
            endSection = (data["endSection"] as? Number)?.toInt() ?: 1,
            startTime = data["startTime"] as? String ?: "",
            endTime = data["endTime"] as? String ?: "",
            startWeek = (data["startWeek"] as? Number)?.toInt() ?: 1,
            endWeek = (data["endWeek"] as? Number)?.toInt() ?: 16,
            isOddWeek = data["isOddWeek"] as? Boolean ?: false,
            isEvenWeek = data["isEvenWeek"] as? Boolean ?: false,
            note = (data["note"] as? String)?.ifBlank { null },
        )
    }

    private fun findActiveSelection(
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
    ): ScheduledSelection? {
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val targetWeek = calculateWeekForDate(snapshot, nowCalendar)
        val todayCourses = snapshot.courses
            .filter { it.dayOfWeek == nowCalendar.get(Calendar.DAY_OF_WEEK).toWeekday() && it.isInWeek(targetWeek) }
            .sortedBy { it.startSection }
        if (todayCourses.isEmpty()) {
            return null
        }

        for ((index, course) in todayCourses.withIndex()) {
            val startAtMillis = buildCourseDateTimeMillis(nowCalendar, course.startTime) ?: continue
            val endAtMillis = buildCourseDateTimeMillis(nowCalendar, course.endTime) ?: continue
            val stage = resolveStage(snapshot, nowMillis, startAtMillis, endAtMillis) ?: continue
            val progressMilestones =
                buildProgressMilestones(snapshot.settings.sections, course, startAtMillis, endAtMillis)
            return ScheduledSelection(
                currentCourse = course,
                nextCourse = todayCourses.getOrNull(index + 1),
                stage = stage,
                triggerAtMillis = startAtMillis,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                progressBreakOffsetsMillis =
                    progressMilestones.map { it.first }.toLongArray(),
                progressMilestoneLabels = progressMilestones.map { it.second.first },
                progressMilestoneTimeTexts = progressMilestones.map { it.second.second },
            )
        }
        return null
    }

    private fun findNextSelection(
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
    ): ScheduledSelection? {
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val targetWeek = calculateWeekForDate(snapshot, nowCalendar)
        val todayStart = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val maxWeek = snapshot.courses.maxOfOrNull { it.endWeek } ?: targetWeek

        var bestSelection: ScheduledSelection? = null

        for (course in snapshot.courses) {
            for (week in targetWeek..maxWeek) {
                if (!course.isInWeek(week)) {
                    continue
                }
                val dayOffset =
                    ((week - targetWeek) * 7) + course.dayOfWeek - nowCalendar.get(Calendar.DAY_OF_WEEK).toWeekday()
                if (dayOffset < 0) {
                    continue
                }
                val candidateDate = Calendar.getInstance().apply {
                    timeInMillis = todayStart.timeInMillis
                    add(Calendar.DAY_OF_YEAR, dayOffset)
                }
                val startAtMillis = buildCourseDateTimeMillis(candidateDate, course.startTime) ?: continue
                val endAtMillis = buildCourseDateTimeMillis(candidateDate, course.endTime) ?: continue
                val nextTrigger =
                    resolveNextTrigger(snapshot, startAtMillis, endAtMillis, nowMillis) ?: continue
                if (nextTrigger.triggerAtMillis <= nowMillis) {
                    continue
                }
                val progressMilestones =
                    buildProgressMilestones(snapshot.settings.sections, course, startAtMillis, endAtMillis)
                val sameDayCourses = snapshot.courses
                    .filter { it.dayOfWeek == course.dayOfWeek && it.isInWeek(week) }
                    .sortedBy { it.startSection }
                val currentIndex = sameDayCourses.indexOfFirst { it.id == course.id }
                val selection = ScheduledSelection(
                    currentCourse = course,
                    nextCourse = sameDayCourses.getOrNull(currentIndex + 1),
                    stage = nextTrigger.stage,
                    triggerAtMillis = nextTrigger.triggerAtMillis,
                    startAtMillis = startAtMillis,
                    endAtMillis = endAtMillis,
                    progressBreakOffsetsMillis =
                        progressMilestones.map { it.first }.toLongArray(),
                    progressMilestoneLabels = progressMilestones.map { it.second.first },
                    progressMilestoneTimeTexts = progressMilestones.map { it.second.second },
                )
                if (bestSelection == null || selection.triggerAtMillis < bestSelection.triggerAtMillis) {
                    bestSelection = selection
                }
                break
            }
        }

        return bestSelection
    }

    private fun selectionToPayload(
        snapshot: NativeScheduleSnapshot,
        selection: ScheduledSelection,
    ): LiveUpdatePayload {
        return LiveUpdatePayload(
            currentCourse = selection.currentCourse,
            nextCourse = selection.nextCourse,
            stage = selection.stage,
            startAtMillis = selection.startAtMillis,
            endAtMillis = selection.endAtMillis,
            beforeClassLeadMillis =
                snapshot.settings.liveShowBeforeClassMinutes * 60_000L,
            endReminderLeadMillis = snapshot.endReminderLeadMillis,
            liveClassReminderStartMinutes =
                snapshot.settings.liveClassReminderStartMinutes,
            endSecondsCountdownThreshold =
                snapshot.settings.liveEndSecondsCountdownThreshold,
            enableBeforeClass = snapshot.settings.liveEnableBeforeClass,
            enableDuringClass = snapshot.settings.liveEnableDuringClass,
            enableBeforeEnd = snapshot.settings.liveEnableBeforeEnd,
            promoteDuringClass = snapshot.settings.livePromoteDuringClass,
            showNotificationDuringClass =
                snapshot.settings.liveShowDuringClassNotification,
            showCountdown = snapshot.settings.liveShowCountdown,
            showCourseNameInIsland = snapshot.settings.liveShowCourseName,
            showLocationInIsland = snapshot.settings.liveShowLocation,
            useShortNameInIsland = snapshot.settings.liveUseShortName,
            hidePrefixText = snapshot.settings.liveHidePrefixText,
            duringClassTimeDisplayMode =
                snapshot.settings.liveDuringClassTimeDisplayMode,
            enableMiuiIslandLabelImage =
                snapshot.settings.liveEnableMiuiIslandLabelImage,
            miuiIslandLabelStyle =
                snapshot.settings.liveMiuiIslandLabelStyle,
            miuiIslandLabelContent =
                snapshot.settings.liveMiuiIslandLabelContent,
            miuiIslandLabelFontSize =
                snapshot.settings.liveMiuiIslandLabelFontSize.toFloat(),
            miuiIslandExpandedIconMode =
                snapshot.settings.liveMiuiIslandExpandedIconMode,
            miuiIslandExpandedIconPath =
                snapshot.settings.liveMiuiIslandExpandedIconPath,
            progressBreakOffsetsMillis = selection.progressBreakOffsetsMillis,
            progressMilestoneLabels = selection.progressMilestoneLabels,
            progressMilestoneTimeTexts = selection.progressMilestoneTimeTexts,
        )
    }

    private fun resolveNextTrigger(
        snapshot: NativeScheduleSnapshot,
        startAtMillis: Long,
        endAtMillis: Long,
        nowMillis: Long,
    ): FutureStageTrigger? {
        val settings = snapshot.settings
        val beforeClassLeadMillis = settings.liveShowBeforeClassMinutes * 60_000L
        val aheadTime = startAtMillis - beforeClassLeadMillis
        val reminderStartMillis = if (settings.liveClassReminderStartMinutes == 0) {
            startAtMillis
        } else {
            maxOf(startAtMillis, endAtMillis - settings.liveClassReminderStartMinutes * 60_000L)
        }
        val endReminderStart = maxOf(startAtMillis, endAtMillis - snapshot.endReminderLeadMillis)
        val candidates = mutableListOf<FutureStageTrigger>()
        if (settings.liveEnableBeforeClass && aheadTime > nowMillis) {
            candidates += FutureStageTrigger("beforeClass", aheadTime)
        }
        if (settings.liveClassReminderStartMinutes == 0 &&
            canDisplayDuring(settings) &&
            startAtMillis > nowMillis
        ) {
            candidates += FutureStageTrigger("duringClass", startAtMillis)
        }
        if (settings.liveClassReminderStartMinutes > 0) {
            if (settings.liveEnableBeforeEnd && reminderStartMillis > nowMillis) {
                candidates += FutureStageTrigger("beforeEnd", reminderStartMillis)
            } else if (canDisplayDuring(settings) && reminderStartMillis > nowMillis) {
                candidates += FutureStageTrigger("duringClass", reminderStartMillis)
            }
        } else if (settings.liveEnableBeforeEnd && endReminderStart > nowMillis) {
            candidates += FutureStageTrigger("beforeEnd", endReminderStart)
        }
        return candidates.minByOrNull { it.triggerAtMillis }
    }

    private fun resolveStage(
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
        startAtMillis: Long,
        endAtMillis: Long,
    ): String? {
        val settings = snapshot.settings
        val beforeClassLeadMillis = settings.liveShowBeforeClassMinutes * 60_000L
        val aheadTime = startAtMillis - beforeClassLeadMillis
        if (nowMillis < aheadTime || nowMillis >= endAtMillis) {
            return null
        }
        if (nowMillis < startAtMillis) {
            return if (settings.liveEnableBeforeClass) "beforeClass" else null
        }
        val reminderStartMillis = if (settings.liveClassReminderStartMinutes == 0) {
            startAtMillis
        } else {
            maxOf(startAtMillis, endAtMillis - settings.liveClassReminderStartMinutes * 60_000L)
        }
        if (nowMillis < reminderStartMillis) {
            return null
        }
        if (settings.liveClassReminderStartMinutes > 0) {
            if (settings.liveEnableBeforeEnd) {
                return "beforeEnd"
            }
            return if (canDisplayDuring(settings)) "duringClass" else null
        }
        val endReminderStart = maxOf(startAtMillis, endAtMillis - snapshot.endReminderLeadMillis)
        if (nowMillis >= endReminderStart) {
            if (settings.liveEnableBeforeEnd) {
                return "beforeEnd"
            }
            if (canDisplayDuring(settings)) {
                return "duringClass"
            }
            return null
        }
        return if (canDisplayDuring(settings)) "duringClass" else null
    }

    private fun canDisplayDuring(settings: NativeLiveSettings): Boolean {
        return settings.liveEnableDuringClass &&
            (settings.livePromoteDuringClass || settings.liveShowDuringClassNotification)
    }

    private fun calculateWeekForDate(
        snapshot: NativeScheduleSnapshot,
        dateCalendar: Calendar,
    ): Int {
        val semesterStartMillis = snapshot.semesterStartMillis ?: return snapshot.currentWeek
        val normalizedDate = Calendar.getInstance().apply {
            timeInMillis = dateCalendar.timeInMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val normalizedStart = Calendar.getInstance().apply {
            timeInMillis = semesterStartMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val diffDays =
            ((normalizedDate.timeInMillis - normalizedStart.timeInMillis) / 86_400_000L).toInt()
        val week = (diffDays / 7) + 1
        return if (week < 1) 1 else week
    }

    private fun buildCourseDateTimeMillis(
        dateCalendar: Calendar,
        courseTime: String,
    ): Long? {
        val parts = courseTime.split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return Calendar.getInstance().apply {
            timeInMillis = dateCalendar.timeInMillis
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun buildProgressMilestones(
        sections: List<NativeSectionTime>,
        course: NativeCourse,
        startAtMillis: Long,
        endAtMillis: Long,
    ): List<Pair<Long, Pair<String, String>>> {
        if (course.endSection - course.startSection + 1 < 2) {
            return emptyList()
        }
        val firstSectionIndex = course.startSection - 1
        val lastSectionIndex = course.endSection - 1
        if (firstSectionIndex < 0 || lastSectionIndex >= sections.size) {
            return emptyList()
        }
        val sectionStartMinutes = parseClockMinutes(sections[firstSectionIndex].startTime) ?: return emptyList()
        val sectionEndMinutes = parseClockMinutes(sections[lastSectionIndex].endTime) ?: return emptyList()
        if (sectionEndMinutes <= sectionStartMinutes) {
            return emptyList()
        }
        val referenceTotalMinutes = sectionEndMinutes - sectionStartMinutes
        val totalDurationMillis = endAtMillis - startAtMillis
        if (totalDurationMillis <= 0L) {
            return emptyList()
        }

        val milestones = mutableListOf<Pair<Long, Pair<String, String>>>()
        for (sectionIndex in firstSectionIndex until lastSectionIndex) {
            val currentSection = sections[sectionIndex]
            val nextSection = sections[sectionIndex + 1]
            val currentEndMinutes = parseClockMinutes(currentSection.endTime) ?: continue
            val nextStartMinutes = parseClockMinutes(nextSection.startTime) ?: continue
            if (nextStartMinutes <= currentEndMinutes) {
                continue
            }
            val breakStartOffsetMillis =
                ((((currentEndMinutes - sectionStartMinutes).toDouble() / referenceTotalMinutes) *
                    totalDurationMillis).toLong()).coerceIn(1L, totalDurationMillis - 1L)
            val breakEndOffsetMillis =
                ((((nextStartMinutes - sectionStartMinutes).toDouble() / referenceTotalMinutes) *
                    totalDurationMillis).toLong()).coerceIn(1L, totalDurationMillis - 1L)
            milestones += breakStartOffsetMillis to ("最近下课" to currentSection.endTime)
            milestones += breakEndOffsetMillis to ("下节上课" to nextSection.startTime)
        }
        return milestones.sortedBy { it.first }
    }

    private fun parseClockMinutes(value: String): Int? {
        val parts = value.split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return hour * 60 + minute
    }

    private fun scheduleAlarm(context: Context, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = buildTriggerPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
        Log.d(TAG, "Scheduled next live update at=$triggerAtMillis")
    }

    private fun cancelScheduledAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(buildTriggerPendingIntent(context))
    }

    private fun buildTriggerPendingIntent(context: Context): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_TRIGGER,
            Intent(context, LiveUpdateReceiver::class.java).apply {
                action = ACTION_TRIGGER
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun startForegroundService(context: Context, payload: LiveUpdatePayload) {
        try {
            ContextCompat.startForegroundService(context, buildServiceIntent(context, payload))
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start live update service", e)
        }
    }
}

class LiveUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> LiveUpdateScheduler.handleSystemReschedule(context)
            LiveUpdateScheduler.ACTION_TRIGGER -> LiveUpdateScheduler.handleAlarm(context)
        }
    }
}

private fun Int.toWeekday(): Int {
    return when (this) {
        Calendar.MONDAY -> 1
        Calendar.TUESDAY -> 2
        Calendar.WEDNESDAY -> 3
        Calendar.THURSDAY -> 4
        Calendar.FRIDAY -> 5
        Calendar.SATURDAY -> 6
        Calendar.SUNDAY -> 7
        else -> 1
    }
}
