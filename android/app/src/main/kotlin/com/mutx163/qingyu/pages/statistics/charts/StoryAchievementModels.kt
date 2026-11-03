package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.Achievement
import com.mutx163.qingyu.statistics.DataStory
import com.mutx163.qingyu.statistics.SemesterStats
import com.mutx163.qingyu.statistics.StoryType

/** 学期总览的一格（数字在上、标签在下）。 */
data class OverviewCell(
    val value: String,
    val label: String,
    /** 首格用主题色强调（Dart 只给「门课程」那格 `highlight: true`）。 */
    val highlight: Boolean,
)

/**
 * 学期总览（单行四指标：门课程 / 节课 / 周 / 天连续）。
 *
 * 对应 Dart `lib/widgets/statistics/overview_section.dart`（108 行）。
 * 口径与本周小结卡一致（24sp 数字 + footnote2 标签），首格主题色。
 */
object OverviewModel {

    /** 没有课程时整块不显示（Dart `if (stats.totalCourses == 0) return shrink()`）。 */
    fun cells(stats: SemesterStats): List<OverviewCell> {
        if (stats.totalCourses == 0) return emptyList()
        return listOf(
            OverviewCell(
                value = stats.totalCourses.toString(),
                label = ChartsStrings.statisticsSemesterLabelCourses.zh,
                highlight = true,
            ),
            OverviewCell(
                value = stats.totalSections.toString(),
                label = ChartsStrings.statisticsSemesterLabelSections.zh,
                highlight = false,
            ),
            OverviewCell(
                value = stats.totalWeeks.toString(),
                label = ChartsStrings.statisticsSemesterLabelWeeks.zh,
                highlight = false,
            ),
            OverviewCell(
                value = stats.longestStreak.toString(),
                label = ChartsStrings.statisticsSemesterLabelDayStreak.zh,
                highlight = false,
            ),
        )
    }
}

/** 富文本片段：正文里 `**xx**` 会被拆成加粗段。 */
data class RichSegment(val text: String, val bold: Boolean)

/** 数据故事一条（标题 + 正文 + 富文本分段 + 语义色）。 */
data class StoryItem(
    val title: String,
    /** 原始正文（保留 `**` 标记，便于对照 ARB）。 */
    val content: String,
    /** 已解析的分段（渲染层直接铺）。 */
    val segments: List<RichSegment>,
    val tone: StoryTone,
)

/** 数据故事的语义色（Dart `_storyAccent`）。 */
enum class StoryTone { RED, TEAL, BLUE, PURPLE, ORANGE }

/**
 * 数据故事卡（最忙的一天 / 最轻松的一天 / 最常去的教室 / 教学楼探险 / 时间跨度）。
 *
 * 对应 Dart `lib/widgets/statistics/data_story_card.dart`（187 行）。
 *
 * 正文里的 `**xx**` 是**加粗标记**（ARB 里就带星号），由 [richSegments] 拆成
 * 普通段与加粗段——这一步是纯字符串处理，单测钉住，渲染层只管按 flag 换字重。
 */
object DataStoryModel {

    fun items(stories: List<DataStory>): List<StoryItem> = stories.map { item(it) }

    fun item(story: DataStory): StoryItem {
        val content = content(story)
        return StoryItem(
            title = title(story.type),
            content = content,
            segments = richSegments(content),
            tone = tone(story.type),
        )
    }

    /** 标题（ARB 逐字，按故事类型）。 */
    fun title(type: StoryType): String = when (type) {
        StoryType.BUSIEST_DAY -> ChartsStrings.storyBusiestDayTitle.zh
        StoryType.LIGHTEST_DAY -> ChartsStrings.storyLightestDayTitle.zh
        StoryType.FAVORITE_ROOM -> ChartsStrings.storyFavoriteRoomTitle.zh
        StoryType.BUILDING_COUNT -> ChartsStrings.storyBuildingCountTitle.zh
        StoryType.TIME_RANGE -> ChartsStrings.storyTimeRangeTitle.zh
    }

    /**
     * 正文（ARB 占位符逐个填好）。
     *
     * 缺字段时的兜底与 Dart 完全一致：平均课时为空串、星期为空串、周次缺省 0、
     * 教室空串、次数 0——**不要**在这里改成「未知」，那会与 ARB 模板拼出病句。
     */
    fun content(story: DataStory): String {
        val week = (story.weekNumber ?: 0).toString()
        val day = story.dayOfWeek?.let { ChartsStrings.weekdayFull(it) } ?: ""
        val avg = story.averageSections?.let { ChartMath.oneDecimal(it) } ?: ""
        return when (story.type) {
            StoryType.BUSIEST_DAY -> ChartsStrings.storyBusiestDayContent.filled(
                "week" to week,
                "day" to day,
                "avg" to avg,
            )
            StoryType.LIGHTEST_DAY -> ChartsStrings.storyLightestDayContent.filled(
                "week" to week,
                "day" to day,
                "avg" to avg,
            )
            StoryType.FAVORITE_ROOM -> ChartsStrings.storyFavoriteRoomContent.filled(
                "week" to week,
                "room" to (story.room ?: ""),
                "count" to (story.visitCount ?: 0).toString(),
            )
            StoryType.BUILDING_COUNT -> ChartsStrings.storyBuildingCountContent.filled(
                "week" to week,
                "count" to (story.buildingCount ?: 0).toString(),
            )
            StoryType.TIME_RANGE -> ChartsStrings.storyTimeRangeContent.filled(
                "earliest" to (story.earliestTime ?: ""),
                "latest" to (story.latestTime ?: ""),
            )
        }
    }

    /** 语义色（Dart `_storyAccent`）：最忙红、最轻松青、教室蓝、跨楼紫、时间跨度橙。 */
    fun tone(type: StoryType): StoryTone = when (type) {
        StoryType.BUSIEST_DAY -> StoryTone.RED
        StoryType.LIGHTEST_DAY -> StoryTone.TEAL
        StoryType.FAVORITE_ROOM -> StoryTone.BLUE
        StoryType.BUILDING_COUNT -> StoryTone.PURPLE
        StoryType.TIME_RANGE -> StoryTone.ORANGE
    }

    /**
     * 把 `**加粗**` 标记拆成分段。
     *
     * 规则与 Dart 的 `RegExp(r'\*\*(.*?)\*\*')` 一致：非贪婪匹配成对星号；
     * 落单的 `**` 不匹配、原样留在普通段里（不吞字）。
     * 空串返回空表（渲染层不铺任何 Text）。
     */
    fun richSegments(content: String): List<RichSegment> {
        if (content.isEmpty()) return emptyList()
        val pattern = Regex("""\*\*(.*?)\*\*""")
        val segments = mutableListOf<RichSegment>()
        var lastEnd = 0
        for (match in pattern.findAll(content)) {
            val start = match.range.first
            if (start > lastEnd) {
                segments.add(RichSegment(content.substring(lastEnd, start), false))
            }
            segments.add(RichSegment(match.groupValues[1], true))
            lastEnd = match.range.last + 1
        }
        if (lastEnd < content.length) {
            segments.add(RichSegment(content.substring(lastEnd), false))
        }
        return segments
    }
}

/** 成就的语义色（Dart `_achievementAccent` 的 12 个 id 映射）。 */
enum class AchievementAccent { ORANGE, GREEN, PURPLE, YELLOW, BLUE, TEAL, INDIGO, CYAN, RED }

/** 徽章渲染所需的全部信息。 */
data class AchievementBadgeModel(
    val name: String,
    val description: String,
    val detail: String,
    val unlocked: Boolean,
    /** 勋章下方的进度小字：已解锁 → `已达成`；有进度 → `6/100`；都没有 → `null`。 */
    val progressLabel: String?,
    /** 进度比例 0..1（详情页进度条用；没有进度时 0）。 */
    val progressFraction: Double,
    val accent: AchievementAccent,
)

/**
 * 成就徽章（12 枚：早八战士、全勤达人、周末战士、课王、学霸…）。
 *
 * 对应 Dart `lib/widgets/statistics/achievement_badge.dart`（454 行）。
 * 本批不搬 Dart 的进场动画（`AnimationController` + `ScaleTransition/FadeTransition`）——
 * 动画属于交互层批次，且它不影响「锁没锁、进度多少」这两个真判据。
 * 徽章尺寸 36dp、圆角 12、锁定态填充 14%/描边 28%（暗色 26%/44%）照抄。
 */
object AchievementModel {

    fun badge(achievement: Achievement): AchievementBadgeModel = AchievementBadgeModel(
        name = ChartsStrings.achievementName(achievement.id),
        description = ChartsStrings.achievementDescription(achievement.id),
        detail = ChartsStrings.achievementDetail(achievement.id),
        unlocked = achievement.isUnlocked,
        progressLabel = progressLabel(achievement),
        progressFraction = progressFraction(achievement),
        accent = accentOf(achievement.id),
    )

    /**
     * 进度小字：**已解锁优先显示「已达成」**（哪怕还带着进度值），
     * 其次才是 `6/100`，没有进度信息就整行不显示。
     */
    fun progressLabel(achievement: Achievement): String? = when {
        // 「空档 ≤ 2」这类越小越好的成就不能显示 `当前/上限`（会出现 6/2），
        // 未解锁时宁可不显示线性进度。
        achievement.isLowerBetterProgress && !achievement.isUnlocked -> null
        !achievement.hasProgress -> null
        achievement.isUnlocked -> ChartsStrings.statisticsAchievementDone.zh
        else -> ChartsStrings.statisticsAchievementProgress.filled(
            "current" to (achievement.progressCurrent ?: 0).toString(),
            "target" to (achievement.progressTarget ?: 0).toString(),
        )
    }

    /** 进度比例，钳在 0..1（目标为 0 或缺失时返回 0，不除零）。 */
    fun progressFraction(achievement: Achievement): Double {
        if (achievement.isLowerBetterProgress && !achievement.isUnlocked) return 0.0
        if (!achievement.hasProgress) return 0.0
        val current = achievement.progressCurrent ?: 0
        val target = achievement.progressTarget ?: 0
        return ChartMath.normalize(current.toDouble(), target.toDouble())
    }

    /** id → 语义色；未知 id 回落蓝色（与 Dart `_ => blue` 一致）。 */
    fun accentOf(id: String): AchievementAccent = when (id) {
        "early_bird" -> AchievementAccent.ORANGE
        "perfect_attendance" -> AchievementAccent.GREEN
        "weekend_warrior" -> AchievementAccent.PURPLE
        "class_king" -> AchievementAccent.YELLOW
        "scholar" -> AchievementAccent.BLUE
        "balanced" -> AchievementAccent.TEAL
        "night_owl" -> AchievementAccent.INDIGO
        "explorer" -> AchievementAccent.CYAN
        "full_day_king" -> AchievementAccent.RED
        "building_hopper" -> AchievementAccent.GREEN
        "morning_person" -> AchievementAccent.YELLOW
        "gap_master" -> AchievementAccent.CYAN
        else -> AchievementAccent.BLUE
    }

    /** 徽章尺寸与圆角（`_medalSize` / `_medalRadius`）。 */
    const val MEDAL_SIZE_DP = 36f
    const val MEDAL_RADIUS_DP = 12f

    /** 锁定态填充 / 描边 / 图标透明度（亮色，Dart `_lockedFill/_lockedBorder/_lockedIcon`）。 */
    const val LOCKED_FILL_LIGHT = 0.14f
    const val LOCKED_FILL_DARK = 0.26f
    const val LOCKED_BORDER_LIGHT = 0.28f
    const val LOCKED_BORDER_DARK = 0.44f
    const val LOCKED_ICON_LIGHT = 0.55f
    const val LOCKED_ICON_DARK = 0.86f
}
