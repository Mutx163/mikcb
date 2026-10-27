package com.mutx163.qingyu.pages.live

import java.time.Duration
import java.time.LocalDateTime

/**
 * 实时活动样式枚举。
 */
enum class LiveIslandStyle(val label: String, val description: String) {
    STANDARD("标准胶囊", "系统状态栏灵动胶囊，居中收拢"),
    CARD("小卡片", "带进度与详细地点的展开卡片"),
    MINIMAL("极简文字", "仅显示课程简称与倒计时秒数"),
}

/**
 * 实时活动展示阶段枚举。
 */
enum class LiveDisplayPhase(val label: String) {
    IDLE("空闲"),
    BEFORE("即将上课"),
    ONGOING("上课中"),
    AFTER("已下课"),
}

/**
 * 实时活动设置状态数据类。
 */
data class LiveSettingsState(
    val isLiveEnabled: Boolean = true,
    val showIsland: Boolean = true,
    val islandStyle: LiveIslandStyle = LiveIslandStyle.STANDARD,
    val leadMinutesBeforeClass: Int = 20,
    val keepMinutesAfterClass: Int = 10,
    val showOngoingProgress: Boolean = true,
    val customFormatTemplate: String = "",
)

/**
 * 实时活动屏上推导信息。
 */
data class LiveDisplayInfo(
    val phase: LiveDisplayPhase,
    val phaseLabel: String,
    val title: String,
    val subtitle: String,
    val countdownText: String,
    val progress: Float,
    val courseName: String,
    val location: String,
)

/**
 * 实时活动模型与纯函数逻辑。
 */
object LiveSettingsModel {

    const val MIN_LEAD_MINUTES = 5
    const val MAX_LEAD_MINUTES = 60
    const val DEFAULT_LEAD_MINUTES = 20

    const val MIN_KEEP_MINUTES = 0
    const val MAX_KEEP_MINUTES = 30
    const val DEFAULT_KEEP_MINUTES = 10

    fun clampLeadMinutes(minutes: Int): Int =
        minutes.coerceIn(MIN_LEAD_MINUTES, MAX_LEAD_MINUTES)

    fun clampKeepMinutes(minutes: Int): Int =
        minutes.coerceIn(MIN_KEEP_MINUTES, MAX_KEEP_MINUTES)

    /**
     * 阶段判定纯函数（零 IO、确定性）：
     *
     * 1. 若 [isLiveEnabled] 为 false 或 [endTime] 早于 [startTime] -> [LiveDisplayPhase.IDLE]
     * 2. 当前时间早于提前提醒开始时间 [startTime - leadMinutes] -> [LiveDisplayPhase.IDLE]
     * 3. 当前时间处于 [startTime - leadMinutes, startTime) -> [LiveDisplayPhase.BEFORE]
     * 4. 当前时间处于 [startTime, endTime) -> [LiveDisplayPhase.ONGOING]
     * 5. 当前时间处于 [endTime, endTime + keepMinutes) -> [LiveDisplayPhase.AFTER]
     * 6. 当前时间处于 [endTime + keepMinutes] 及以后 -> [LiveDisplayPhase.IDLE]
     */
    fun resolveLiveDisplayPhase(
        currentTime: LocalDateTime,
        startTime: LocalDateTime,
        endTime: LocalDateTime,
        leadMinutesBeforeClass: Int = DEFAULT_LEAD_MINUTES,
        keepMinutesAfterClass: Int = DEFAULT_KEEP_MINUTES,
        isLiveEnabled: Boolean = true,
    ): LiveDisplayPhase {
        if (!isLiveEnabled) return LiveDisplayPhase.IDLE
        if (endTime.isBefore(startTime)) return LiveDisplayPhase.IDLE

        val lead = clampLeadMinutes(leadMinutesBeforeClass)
        val leadStartTime = startTime.minusMinutes(lead.toLong())
        val keep = clampKeepMinutes(keepMinutesAfterClass)
        val afterEndTime = endTime.plusMinutes(keep.toLong())

        return when {
            currentTime.isBefore(leadStartTime) -> LiveDisplayPhase.IDLE
            currentTime.isBefore(startTime) -> LiveDisplayPhase.BEFORE
            currentTime.isBefore(endTime) -> LiveDisplayPhase.ONGOING
            currentTime.isBefore(afterEndTime) -> LiveDisplayPhase.AFTER
            else -> LiveDisplayPhase.IDLE
        }
    }

    /**
     * 展示文案与进度推导纯函数。
     */
    fun deriveLiveDisplayInfo(
        currentTime: LocalDateTime,
        startTime: LocalDateTime,
        endTime: LocalDateTime,
        courseName: String = LiveStrings.liveIslandPreviewSampleCourse.zh,
        location: String = LiveStrings.liveIslandPreviewSampleLocation.zh,
        settings: LiveSettingsState = LiveSettingsState(),
    ): LiveDisplayInfo {
        val phase = resolveLiveDisplayPhase(
            currentTime = currentTime,
            startTime = startTime,
            endTime = endTime,
            leadMinutesBeforeClass = settings.leadMinutesBeforeClass,
            keepMinutesAfterClass = settings.keepMinutesAfterClass,
            isLiveEnabled = settings.isLiveEnabled,
        )

        return when (phase) {
            LiveDisplayPhase.IDLE -> LiveDisplayInfo(
                phase = LiveDisplayPhase.IDLE,
                phaseLabel = "空闲",
                title = courseName,
                subtitle = location,
                countdownText = "",
                progress = 0f,
                courseName = courseName,
                location = location,
            )
            LiveDisplayPhase.BEFORE -> {
                val secondsUntilStart = Duration.between(currentTime, startTime).seconds.coerceAtLeast(0)
                val countdown = LiveStrings.formatCountdown(secondsUntilStart)
                LiveDisplayInfo(
                    phase = LiveDisplayPhase.BEFORE,
                    phaseLabel = LiveStrings.liveIslandPreviewStageBeforeClass.zh,
                    title = LiveStrings.liveIslandPreviewTitleBeforeClass.filled("course", courseName),
                    subtitle = location,
                    countdownText = LiveStrings.formatUntilClassStart(countdown),
                    progress = 0f,
                    courseName = courseName,
                    location = location,
                )
            }
            LiveDisplayPhase.ONGOING -> {
                val totalSeconds = Duration.between(startTime, endTime).seconds.coerceAtLeast(1)
                val elapsedSeconds = Duration.between(startTime, currentTime).seconds.coerceIn(0, totalSeconds)
                val remainingSeconds = (totalSeconds - elapsedSeconds).coerceAtLeast(0)
                val progress = (elapsedSeconds.toFloat() / totalSeconds.toFloat()).coerceIn(0f, 1f)
                val countdown = LiveStrings.formatCountdown(remainingSeconds)
                LiveDisplayInfo(
                    phase = LiveDisplayPhase.ONGOING,
                    phaseLabel = LiveStrings.liveIslandPreviewStageInClass.zh,
                    title = courseName,
                    subtitle = location,
                    countdownText = LiveStrings.formatUntilClassEnd(countdown),
                    progress = if (settings.showOngoingProgress) progress else 0f,
                    courseName = courseName,
                    location = location,
                )
            }
            LiveDisplayPhase.AFTER -> {
                LiveDisplayInfo(
                    phase = LiveDisplayPhase.AFTER,
                    phaseLabel = LiveStrings.liveIslandPreviewStageBeforeEnd.zh,
                    title = LiveStrings.liveIslandPreviewTitleBeforeEnd.filled("course", courseName),
                    subtitle = location,
                    countdownText = "已下课",
                    progress = 1f,
                    courseName = courseName,
                    location = location,
                )
            }
        }
    }
}

// 状态变异纯函数扩展
fun LiveSettingsState.withToggledLive(): LiveSettingsState =
    copy(isLiveEnabled = !isLiveEnabled)

fun LiveSettingsState.withToggledIsland(): LiveSettingsState =
    copy(showIsland = !showIsland)

fun LiveSettingsState.withToggledOngoingProgress(): LiveSettingsState =
    copy(showOngoingProgress = !showOngoingProgress)

fun LiveSettingsState.withLeadMinutes(minutes: Int): LiveSettingsState =
    copy(leadMinutesBeforeClass = LiveSettingsModel.clampLeadMinutes(minutes))

fun LiveSettingsState.withKeepMinutes(minutes: Int): LiveSettingsState =
    copy(keepMinutesAfterClass = LiveSettingsModel.clampKeepMinutes(minutes))

fun LiveSettingsState.withIslandStyle(style: LiveIslandStyle): LiveSettingsState =
    copy(islandStyle = style)

fun LiveSettingsState.resetDefaults(): LiveSettingsState =
    LiveSettingsState()
