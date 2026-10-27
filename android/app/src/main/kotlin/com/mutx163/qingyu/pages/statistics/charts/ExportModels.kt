package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.CourseSemesterStat
import com.mutx163.qingyu.statistics.CourseSlot
import com.mutx163.qingyu.statistics.StatisticsExportModule
import com.mutx163.qingyu.statistics.StatisticsExportOptions

/**
 * 导出长图（`lib/widgets/statistics/statistics_export_*.dart` 四个文件，共 697 行）的纯逻辑。
 *
 * 四个 Dart 文件分工：弹层选模块（sheet 155 行）、拼文档（document 121 行）、
 * 品牌条（brand_footer 162 行）、导出专用精简排行（course_ranking 259 行）。
 *
 * 这里只搬「哪些块、按什么顺序、多大尺寸、文案怎么拼」这些能用单测钉住的判断；
 * 真正画出来的部分在渲染层 `StatisticsExportCards.kt`。
 */

/** 导出文档里的一块。 */
enum class ExportSectionKind {
    OVERVIEW, ACHIEVEMENTS, STORIES, DAILY_DISTRIBUTION, NATURE_RATIO, RANKING,
}

/**
 * 文档中的一段。
 *
 * [title] 为空表示这一段不套「块标题」（总览块自带标题）；其余五段外面都套一层
 * `HyperosSettingsBlock`（对应 Kotlin 的 `ChartCardHeader` + 卡片）。
 */
data class ExportSection(val kind: ExportSectionKind, val title: String)

/** 导出文档的顺序与筛选（document:33-96）。 */
object ExportDocumentModel {

    /**
     * 按 Dart `appendSection` 的顺序产出要放进长图的段落。
     *
     * 门槛与 Dart 逐条一致：
     * - 总览：只看模块开关，**不**看课程数（没课时 `OverviewSection` 自己收缩成空）；
     * - 成就 / 故事：模块开关 **且** 数据非空（`achievements.isNotEmpty()` / `stories.isNotEmpty()`）；
     * - 每日课时 / 必修选修 / 课程排行：只看模块开关（排行的空态自己显示「暂无课程数据」）。
     */
    fun sections(
        options: StatisticsExportOptions,
        achievementCount: Int,
        storyCount: Int,
    ): List<ExportSection> {
        val out = mutableListOf<ExportSection>()
        val modules = options.modules
        if (StatisticsExportModule.OVERVIEW in modules) {
            out.add(ExportSection(ExportSectionKind.OVERVIEW, ""))
        }
        if (StatisticsExportModule.ACHIEVEMENTS in modules && achievementCount > 0) {
            out.add(
                ExportSection(
                    ExportSectionKind.ACHIEVEMENTS,
                    ChartsStrings.statisticsAchievementsTitle.zh,
                ),
            )
        }
        if (StatisticsExportModule.STORIES in modules && storyCount > 0) {
            out.add(
                ExportSection(
                    ExportSectionKind.STORIES,
                    ChartsStrings.statisticsStoriesTitle.zh,
                ),
            )
        }
        if (StatisticsExportModule.DAILY_DISTRIBUTION in modules) {
            out.add(
                ExportSection(
                    ExportSectionKind.DAILY_DISTRIBUTION,
                    ChartsStrings.statisticsDailyDistribution.zh,
                ),
            )
        }
        if (StatisticsExportModule.NATURE_RATIO in modules) {
            out.add(
                ExportSection(
                    ExportSectionKind.NATURE_RATIO,
                    ChartsStrings.statisticsNatureRatio.zh,
                ),
            )
        }
        if (StatisticsExportModule.RANKING in modules) {
            out.add(
                ExportSection(
                    ExportSectionKind.RANKING,
                    ChartsStrings.statisticsRankingTitle.zh,
                ),
            )
        }
        return out
    }

    /** 文档标题（`l10n.statisticsShareTitle`）。 */
    val title: String get() = ChartsStrings.statisticsShareTitle.zh

    /** 段落之间的竖距：Dart 用 `HyperosSectionGap`，取值 12（= `QingyuSectionGap`）。 */
    const val SECTION_GAP_DP = 12

    /** 文档内边距 `EdgeInsets.fromLTRB(16, 16, 16, 20)`。 */
    const val PADDING_START_DP = 16
    const val PADDING_TOP_DP = 16
    const val PADDING_END_DP = 16
    const val PADDING_BOTTOM_DP = 20

    /** 品牌条与标题之间 `SizedBox(height: 10)`，标题与段落之间 `SizedBox(height: 12)`。 */
    const val BRAND_TO_TITLE_GAP_DP = 10
    const val TITLE_TO_SECTIONS_GAP_DP = 12

    /** 段落到页脚品牌条之间也是 `SizedBox(height: 12)`。 */
    const val SECTIONS_TO_FOOTER_GAP_DP = 12
}

/** 导出弹层（sheet:41-153）。 */
object ExportSheetModel {

    /** 弹层里可勾选的模块顺序（sheet:96-105）：成就 / 故事没有数据时直接不出现。 */
    fun availableModules(
        hasAchievements: Boolean,
        hasStories: Boolean,
    ): List<StatisticsExportModule> {
        val out = mutableListOf(StatisticsExportModule.OVERVIEW)
        if (hasAchievements) out.add(StatisticsExportModule.ACHIEVEMENTS)
        if (hasStories) out.add(StatisticsExportModule.STORIES)
        out.add(StatisticsExportModule.DAILY_DISTRIBUTION)
        out.add(StatisticsExportModule.NATURE_RATIO)
        out.add(StatisticsExportModule.RANKING)
        return out
    }

    /**
     * 打开弹层时的初始勾选（sheet:42-54）：
     * 先取「默认除排行外全选」，再把没有数据的成就 / 故事摘掉。
     */
    fun initialSelection(
        hasAchievements: Boolean,
        hasStories: Boolean,
    ): Set<StatisticsExportModule> {
        val out = StatisticsExportOptions.defaultModules.toMutableSet()
        if (!hasAchievements) out.remove(StatisticsExportModule.ACHIEVEMENTS)
        if (!hasStories) out.remove(StatisticsExportModule.STORIES)
        return out
    }

    /** 勾选 / 取消（sheet:56-64）。 */
    fun toggle(
        selection: Set<StatisticsExportModule>,
        module: StatisticsExportModule,
        enabled: Boolean,
    ): Set<StatisticsExportModule> {
        val out = selection.toMutableSet()
        if (enabled) out.add(module) else out.remove(module)
        return out
    }

    /** 每个模块在弹层里显示的名字（sheet:84-94）。 */
    fun moduleTitle(module: StatisticsExportModule): String = when (module) {
        StatisticsExportModule.OVERVIEW -> ChartsStrings.statisticsExportModuleOverview.zh
        StatisticsExportModule.ACHIEVEMENTS -> ChartsStrings.statisticsAchievementsTitle.zh
        StatisticsExportModule.STORIES -> ChartsStrings.statisticsStoriesTitle.zh
        StatisticsExportModule.DAILY_DISTRIBUTION -> ChartsStrings.statisticsDailyDistribution.zh
        StatisticsExportModule.NATURE_RATIO -> ChartsStrings.statisticsNatureRatio.zh
        StatisticsExportModule.RANKING -> ChartsStrings.statisticsRankingTitle.zh
    }

    /** 一个都没勾时的提示（sheet:68-74），返回 null 表示可以导出。 */
    fun submitHintOrNull(selection: Set<StatisticsExportModule>): String? =
        if (selection.isEmpty()) ChartsStrings.statisticsExportSelectModuleHint.zh else null

    /** 点「开始导出」得到的选项；空选择返回 null（弹层此时只弹提示、不关闭）。 */
    fun submit(selection: Set<StatisticsExportModule>): StatisticsExportOptions? =
        if (selection.isEmpty()) null else StatisticsExportOptions(selection.toSet())

    /** 模块区间小标题（`l10n.statisticsExportModulesSection`）与按钮文案。 */
    val modulesSectionLabel: String get() = ChartsStrings.statisticsExportModulesSection.zh
    val actionLabel: String get() = ChartsStrings.statisticsExportAction.zh
    val sheetTitle: String get() = ChartsStrings.statisticsExportTitle.zh

    /** 小标题到列表 `SizedBox(height: 8)`；列表到按钮 `SizedBox(height: 20)`。 */
    const val LABEL_TO_LIST_GAP_DP = 8
    const val LIST_TO_ACTION_GAP_DP = 20
}

/**
 * 品牌条（brand_footer:36-139）。
 *
 * 左边 40dp 圆角图标、中间三行字（App 名 / 一句话 / 网址）、右边方形二维码。
 * 二维码边长**跟着文字块高度走**（48~72 之间夹住），这样右侧不留大片空白，
 * 也不用 `IntrinsicHeight`（Dart 注释明确写了二维码里的 `LayoutBuilder` 不参与固有测量）。
 */
object ExportBrandModel {

    val appName: String get() = ChartsStrings.timetableAppName.zh
    val tagline: String get() = ChartsStrings.statisticsExportBrandTagline.zh

    /** 网址展示串（`StatisticsExportBrand.WEBSITE_DISPLAY`）。 */
    val websiteDisplay: String
        get() = com.mutx163.qingyu.statistics.StatisticsExportBrand.WEBSITE_DISPLAY

    /** 二维码内容（`StatisticsExportBrand.WEBSITE_URL`）。 */
    val websiteUrl: String
        get() = com.mutx163.qingyu.statistics.StatisticsExportBrand.WEBSITE_URL

    const val LOGO_SIZE_DP = 40
    const val LOGO_RADIUS_DP = 11
    const val LOGO_TO_TEXT_GAP_DP = 10
    const val TEXT_TO_QR_GAP_DP = 8

    /** 顶部分隔线到内容、内容到底部分隔线都是 `SizedBox(height: 10)`。 */
    const val DIVIDER_GAP_DP = 10

    /** 条自身外边距 `EdgeInsets.symmetric(horizontal: 2, vertical: 2)`。 */
    const val OUTER_PADDING_DP = 2

    /** 分隔线透明度 `withValues(alpha: 0.7)`。 */
    const val DIVIDER_ALPHA = 0.7f

    /** 二维码边长夹取区间 `clamp(48.0, 72.0)`。 */
    const val QR_MIN_DP = 48f
    const val QR_MAX_DP = 72f

    /** 文字块三行之间的两个空隙：标题→一句话 1dp，一句话→网址 2dp。 */
    const val TITLE_TO_TAGLINE_GAP_DP = 1
    const val TAGLINE_TO_URL_GAP_DP = 2

    /** 字号 / 行高的兜底值（Dart `titleStyle.fontSize ?? 17` 等）。 */
    const val FALLBACK_TITLE_FONT_SIZE = 17f
    const val FALLBACK_TITLE_LINE_HEIGHT = 1.1f
    const val FALLBACK_DETAIL_FONT_SIZE = 13f
    const val FALLBACK_DETAIL_LINE_HEIGHT = 1.15f

    /** 标题行高（brand_footer:46-47）：字号 × 行高，取不到就用 17 × 1.1。 */
    fun titleLineHeight(
        fontSize: Float? = null,
        lineHeight: Float? = null,
    ): Float = (fontSize ?: FALLBACK_TITLE_FONT_SIZE) *
        (lineHeight ?: FALLBACK_TITLE_LINE_HEIGHT)

    /** 说明行高（brand_footer:48-49）：字号 × 行高，兜底 13 × 1.15。 */
    fun detailLineHeight(
        fontSize: Float? = null,
        lineHeight: Float? = null,
    ): Float = (fontSize ?: FALLBACK_DETAIL_FONT_SIZE) *
        (lineHeight ?: FALLBACK_DETAIL_LINE_HEIGHT)

    /**
     * 估算文字块总高（brand_footer:46-51）：
     * 标题高 + 1 + 说明高 + 2 + 说明高（两行说明分别是「一句话」和「网址」）。
     */
    fun textBlockHeight(
        titleFontSize: Float? = null,
        titleLineHeight: Float? = null,
        detailFontSize: Float? = null,
        detailLineHeight: Float? = null,
    ): Float = titleLineHeight(titleFontSize, titleLineHeight) +
        TITLE_TO_TAGLINE_GAP_DP +
        detailLineHeight(detailFontSize, detailLineHeight) +
        TAGLINE_TO_URL_GAP_DP +
        detailLineHeight(detailFontSize, detailLineHeight)

    /** 二维码边长 = 文字块高度夹在 48~72（brand_footer:66）。 */
    fun qrSize(textBlockHeight: Float): Float =
        textBlockHeight.coerceIn(QR_MIN_DP, QR_MAX_DP)

    /** 便捷入口：直接用兜底字号算二维码边长（等价于亮色主题下的实际值）。 */
    fun defaultQrSize(): Float = qrSize(textBlockHeight())
}

/** 导出排行的名次徽章配色（course_ranking:218-239）。 */
enum class ExportRankTone {
    /** 第 1 名：黄色 18% 底 + 奖杯。 */
    GOLD,

    /** 第 2 名：次要文字色 14% 底 + 奖杯。 */
    SILVER,

    /** 第 3 名：橙色 16% 底 + 奖杯。 */
    ORANGE,

    /** 第 4 名及以后：次要文字色 10% 底 + 数字。 */
    PLAIN,
}

/** 导出用的精简课程排行（course_ranking:26-208）。 */
object ExportRankingModel {

    /**
     * 长图里最多画 20 门（course_ranking:20）。
     *
     * Dart 注释写明原因：整块导出会被截成一张超长纹理，条目太多会撞 GPU 纹理上限。
     */
    const val MAX_ITEMS = 20

    /** 上课时间摘要最多列 3 段，多的用 ` · …` 收尾（course_ranking:183-195）。 */
    const val MAX_SLOT_SUMMARY = 3

    /** 徽章尺寸与圆角（course_ranking:242-247）。 */
    const val BADGE_SIZE_DP = 36
    const val BADGE_RADIUS_DP = 10
    const val TROPHY_ICON_SIZE_DP = 18

    /** 名次底色透明度（course_ranking:220-236）。 */
    const val GOLD_ALPHA = 0.18f
    const val SILVER_ALPHA = 0.14f
    const val ORANGE_ALPHA = 0.16f
    const val PLAIN_ALPHA = 0.10f

    /** 必修 / 选修小标签底色透明度（course_ranking:121-122）。 */
    const val NATURE_CHIP_ALPHA = 0.12f

    /** 取前 [MAX_ITEMS] 门（course_ranking:45）。 */
    fun visible(ranking: List<CourseSemesterStat>): List<CourseSemesterStat> =
        ranking.take(MAX_ITEMS)

    /** 被截掉的门数（course_ranking:46）；0 表示不显示「另有 N 门未展示」。 */
    fun remaining(total: Int, shown: Int): Int = total - shown

    /** 「另有 {count} 门课程未展示」的文案；没有剩余时返回 null。 */
    fun remainingLabel(total: Int, shown: Int): String? {
        val left = remaining(total, shown)
        if (left <= 0) return null
        return ChartsStrings.statisticsExportRankingMore.filled("count" to left.toString())
    }

    /** 空态文案（course_ranking:36）。 */
    val emptyMessage: String get() = ChartsStrings.statisticsNoData.zh

    /** 节数单位（`l10n.statisticsSectionUnit`，排行里是单数「节」）。 */
    val sectionUnit: String get() = ChartsStrings.statisticsSectionUnit.zh

    /**
     * 节次区间（course_ranking:185-187）：起止相同只写一个数字，否则 `起-止`。
     *
     * 注意用的是半角连字符 `-`（Dart 写的 `'${a}-${b}'`），不是区间连接号 `–`。
     */
    fun sectionRange(startSection: Int, endSection: Int): String =
        if (startSection == endSection) startSection.toString() else "$startSection-$endSection"

    /** 星期的短名（course_ranking:197-208）：1~7 取 ARB，越界直接显示数字。 */
    fun weekdayShortLabel(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> ChartsStrings.weekdayShortMonday.zh
        2 -> ChartsStrings.weekdayShortTuesday.zh
        3 -> ChartsStrings.weekdayShortWednesday.zh
        4 -> ChartsStrings.weekdayShortThursday.zh
        5 -> ChartsStrings.weekdayShortFriday.zh
        6 -> ChartsStrings.weekdayShortSaturday.zh
        7 -> ChartsStrings.weekdayShortSunday.zh
        else -> dayOfWeek.toString()
    }

    /** 单段上课时间：「一 1-2节」。 */
    fun slotLabel(slot: CourseSlot): String =
        "${weekdayShortLabel(slot.dayOfWeek)} " +
            "${sectionRange(slot.startSection, slot.endSection)}$sectionUnit"

    /**
     * 整门课的时间摘要（course_ranking:179-195）：最多 3 段，用 ` · ` 连接，
     * 超出的补 ` · …`；没有上课时间返回空串（调用方据此不画这一行）。
     */
    fun scheduleSummary(slots: List<CourseSlot>): String {
        if (slots.isEmpty()) return ""
        val labels = slots.take(MAX_SLOT_SUMMARY).map { slotLabel(it) }
        val joined = labels.joinToString(" · ")
        return if (slots.size <= MAX_SLOT_SUMMARY) joined else "$joined · …"
    }

    /** 名次配色（course_ranking:218-239）。 */
    fun rankTone(rank: Int): ExportRankTone = when (rank) {
        1 -> ExportRankTone.GOLD
        2 -> ExportRankTone.SILVER
        3 -> ExportRankTone.ORANGE
        else -> ExportRankTone.PLAIN
    }

    /** 前三名画奖杯、其余画数字（course_ranking:249-256）。 */
    fun showsTrophy(rank: Int): Boolean = rank in 1..3

    /** 名次底色透明度。 */
    fun badgeAlpha(rank: Int): Float = when (rankTone(rank)) {
        ExportRankTone.GOLD -> GOLD_ALPHA
        ExportRankTone.SILVER -> SILVER_ALPHA
        ExportRankTone.ORANGE -> ORANGE_ALPHA
        ExportRankTone.PLAIN -> PLAIN_ALPHA
    }

    /** 名下文字：奖杯名次不画数字，返回 null。 */
    fun badgeText(rank: Int): String? = if (showsTrophy(rank)) null else rank.toString()

    /** 必修 / 选修小标签文案（course_ranking:117-119）。 */
    fun natureLabel(isRequired: Boolean): String = if (isRequired) {
        ChartsStrings.courseNatureRequired.zh
    } else {
        ChartsStrings.courseNatureElective.zh
    }
}
