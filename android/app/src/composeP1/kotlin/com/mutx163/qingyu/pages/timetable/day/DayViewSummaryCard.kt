package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.timetable.CourseCardInk
import com.mutx163.qingyu.statistics.ClockTime
import com.mutx163.qingyu.theme.QingyuTheme
import java.util.Locale
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图顶部全天概览卡（Day View Summary Card）。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_summary_card.dart`：
 * - 顶部日期与周次标题（带关闭返回周视图叉号按钮）
 * - 大字日期标题
 * - 课程/日程/待办三合一统计胶囊
 * - 当前进行状态（正在上课/今日课程已结束）、冲突警告、非本周、考试倒计时高亮
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DayViewSummaryCard(
    state: DayViewSummaryState,
    onClose: () -> Unit,
    /** 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为（主题实底卡）。 */
    material: HomeMaterialRenderSpec? = null,
    /** 液态档的整页共享背景采样源（见 [dayAgendaSurface]）。 */
    glassBackdrop: Backdrop? = null,
    /**
     * 卡背后壁纸的**星期栏那档**亮度（与摘要卡的星期栏字色同源）：玻璃压壁纸时用它按
     * 卡面有效亮度自动翻黑/白，避免灰字糊在灰玻璃上。null = 没壁纸 / 亮度未知 ⇒ 用主题前景。
     */
    wallpaperLuminance: Double? = null,
    /**
     * 用户自定义的**星期栏字色**（hex，`WeekViewStyle.weekdayFontColorLight/Dark` 同一对键）：
     * 摘要卡墨色本来就与星期栏同一套配色；非空且非默认时优先用它（对比不足再按亮度推）。
     * null = 没接 / 未配置 ⇒ 维持「按明暗自动翻黑/白」。
     */
    weekdayFontColorHex: String? = null,
    /** 该主题档下「星期栏字色」的**内置默认值**（hex）：等于它时视作「没改过」⇒ 按亮度翻黑/白。 */
    weekdayFontColorDefaultHex: String? = null,
    /**
     * 「共同空闲」模块（发布版 `timetable_screen.dart:4286-4447` 的
     * `_buildDayViewSharedFreeSummary`）——挂在摘要卡**内部**、状态胶囊之后。
     *
     * null = 不渲染：没有情侣绑定 / 没开叠加 / 数据源没注入（[LocalDayViewSharedFree]）。
     * 求解与取色的纯逻辑在 [DayViewSharedFreeLogic]。
     */
    sharedFree: DayViewSharedFreeUi? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()

    // ── 摘要卡与下面的议程卡**同材质**（2026-11-01）──
    // Dart `day_view_summary_card.dart:126-133` 记着用户口径：「日视图顶部的日期卡片……
    // 也要跟日视图的课程卡片是一样的材质，选什么就是什么，不要第二种」。
    // 所以这里不另判一档，直接走议程卡那套（[dayAgendaSurfaceAlpha] + [dayAgendaSurface]）。
    val shape = RoundedCornerShape(QingyuCardDefaults.Corner)
    val glass = dayAgendaGlassBackdrop(material, glassBackdrop)
    val fillAlpha = dayAgendaSurfaceAlpha(material, 1f).coerceIn(0.08f, 1f)
    val translucent = glass != null || fillAlpha < 1f

    // ── 摘要卡文字墨色（2026-11-07 按卡面有效亮度重算）──
    // 卡面半透明（玻璃 / 高斯 / 染色 < 1）时：按**卡面有效亮度**
    //（卡底色亮度 × α + 壁纸亮度 × (1−α)，见 `CourseCardInk.compositeLuminanceOverWallpaper`）
    // 在黑 / 白里挑对比度更高的一档 —— 与四张议程卡同一份实现。
    // 旧实现有两处门槛会漏判：①要求 `glass != null`（只认液态档），高斯档 alpha 已经 0.55
    // 却仍用主题前景色；②翻面用写死的 0.20 阈值，分界点附近白给了 ~4% 亮度差。
    // 非半透明档（实色）：按卡底色自身亮度择优（`fallbackArgb`），次级行用其派生 muted。
    // 卡面底色：画法与判墨**共用这一份**，避免一处改了另一处漏（`DayViewTaskBandCard` 同）。
    val cardFill = MiuixTheme.colorScheme.surface
    val inkArgb = if (translucent && wallpaperLuminance != null) {
        CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = cardFill.toArgb(),
            fillAlpha = fillAlpha,
            wallpaperLuminance = wallpaperLuminance,
            showsWallpaper = true,
            fallbackArgb = QingyuTheme.primaryText(dark),
            // 与星期栏同一套自定义字色：配置了（且不是内置默认值）就优先用它，
            // 只有它在卡面有效亮度上达不到 3:1 时才回自动黑 / 白（与
            // `HomeBackgroundModel.MIN_INK_CONTRAST_RATIO` 同一条达标线）。
            preferredArgb = HomeBackgroundModel.parseInkArgb(weekdayFontColorHex)
                ?.takeIf { it != HomeBackgroundModel.parseInkArgb(weekdayFontColorDefaultHex) },
        )
    } else {
        QingyuTheme.primaryText(dark)
    }
    val summaryInk = Color(inkArgb)
    val summaryMutedInk = Color(HomeBackgroundModel.mutedInkOverWallpaperArgb(inkArgb))

    QingyuCard(
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (translucent) {
                    Modifier.dayAgendaSurface(
                        glassBackdrop = glass,
                        shape = shape,
                        fill = cardFill.copy(alpha = fillAlpha),
                        material = material,
                    )
                } else {
                    Modifier
                },
            ),
        // 卡面自己画（上面那条 modifier），卡片本体的底色让开；不透明档保持官方默认配色。
        colors = if (translucent) {
            CardDefaults.defaultColors(color = Color.Transparent)
        } else {
            CardDefaults.defaultColors()
        },
        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // ── 顶部栏：今天 · 第几周 + 关闭叉号按钮 ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f, fill = false),
                ) {
                    if (state.isToday) {
                        Text(
                            text = DayViewStrings.todayTimetableTitle.text,
                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = summaryMutedInk,
                        )
                        Text(
                            text = " · ",
                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = summaryMutedInk,
                        )
                    }
                    Text(
                        text = DayViewStrings.weekLabel(state.week),
                        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = summaryMutedInk,
                    )
                }

                IconButton(
                    onClick = onClose,
                    modifier = Modifier.size(28.dp),
                ) {
                    Icon(
                        imageVector = MiuixIcons.Close,
                        contentDescription = DayViewStrings.backToWeekViewAction.text,
                        tint = summaryInk,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // ── 大字日期标题（如 "10月27日 周二"）──
            Text(
                text = state.dateLabel,
                style = MiuixTheme.textStyles.title3,
                lineHeight = 26.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = summaryInk,
            )

            Spacer(modifier = Modifier.height(10.dp))

            // ── 统计胶囊区（课程数 / 日程数 / 议程起止时间）──
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // 主计数胶囊（"4 门课" 或 "日程 2 项" 或 "作业 1 项" 或 "0 门课"）
                SummaryNeutralCapsule(text = state.countLabel, ink = summaryInk, mutedInk = summaryMutedInk)

                // 辅日程计数胶囊（既有课又有日程时展示）
                if (!state.scheduleLabel.isNullOrBlank()) {
                    SummaryNeutralCapsule(text = state.scheduleLabel, ink = summaryInk, mutedInk = summaryMutedInk)
                }

                // 议程时间区间（如 "08:00 开始 · 20:30 结束"）
                if (!state.agendaRangeLabel.isNullOrBlank()) {
                    Text(
                        text = state.agendaRangeLabel,
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = summaryMutedInk,
                    )
                }
            }

            // ── 状态胶囊区（正在上课、冲突节数、非本周、考试倒计时等）──
            if (state.statusChips.isNotEmpty()) {
                Spacer(modifier = Modifier.height(10.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    state.statusChips.forEach { chip ->
                        SummaryStatusCapsule(chip = chip, dark = dark, mutedInk = summaryMutedInk)
                    }
                }
            }

            // ── 共同空闲（情侣叠加）：发布版在状态胶囊**之后**、卡内底部 ──
            // 发布版 `timetable_day_view_part.dart:767-777`：`_isCoupleOverlayActive` 为真时
            // 先空 12dp 再挂 `_buildDayViewSharedFreeSummary`。这里同一位置、同一间距。
            if (sharedFree != null) {
                Spacer(modifier = Modifier.height(12.dp))
                DayViewSharedFreePanel(ui = sharedFree, ink = summaryInk, dark = dark)
            }
        }
    }
}

/**
 * 摘要卡中性信息胶囊（灰色浅底）。
 */
@Composable
private fun SummaryNeutralCapsule(
    text: String,
    ink: Color,
    mutedInk: Color,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(ink.copy(alpha = 0.10f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = mutedInk,
        )
    }
}

/**
 * 摘要卡状态胶囊（圆角药丸胶囊，带不同语义高亮色彩）。
 */
@Composable
private fun SummaryStatusCapsule(
    chip: SummaryChip,
    dark: Boolean,
    mutedInk: Color,
) {
    val accentColor = when (chip.kind) {
        SummaryChipKind.ONGOING_COURSE -> Color(QingyuTheme.primary(null, dark))
        SummaryChipKind.CONFLICT -> Color(QingyuTheme.error(dark))
        SummaryChipKind.NON_CURRENT_WEEK -> mutedInk
        SummaryChipKind.EXAM -> Color(QingyuTheme.error(dark))
    }

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(accentColor.copy(alpha = 0.12f))
            .padding(horizontal = 9.dp, vertical = 4.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            // 小圆点装饰指示器
            Box(
                modifier = Modifier
                    .size(5.dp)
                    .clip(CircleShape)
                    .background(accentColor),
            )
            Text(
                text = chip.text,
                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = accentColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 共同空闲（情侣叠加）
// ════════════════════════════════════════════════════════════════════════════

/**
 * 摘要卡「共同空闲」模块的**渲染快照**（纯数据，算好再上屏）。
 *
 * 与 Dart 一样把「求解」「格式化」「可用性判断」都放在 [DayViewSharedFreeSource.uiFor]
 * 里一次做完，Composable 只负责画——这样模块的所有分支都能被纯函数单测钉住。
 */
data class DayViewSharedFreeUi(
    /** 标题：今天 / 非今天两档（发布版 `:4310-4312`）。 */
    val title: String,
    /** 空态正文（有区间时为 null；发布版 `:4313-4315`）。 */
    val emptyLabel: String?,
    /** 「共 N 段」徽标（空态时为 null；发布版 `:4388-4394`）。 */
    val metaLabel: String?,
    /** 已格式化的分钟区间（`HH:mm-HH:mm`），空表 = 当天没有共同空闲。 */
    val intervals: List<String>,
    /** 「还有 N 段」展开按钮文案（区间数超过可见上限时非 null；发布版 `:4428-4434`）。 */
    val moreLabel: String?,
    /** 过期提示（对方课表上次导入超过 7 天 / 时间缺失；发布版 `:4346-4349`、`:4440-4443`）。 */
    val staleHint: String?,
)

/**
 * 「共同空闲」的**数据源**：由日页外层（`TimetableWeekPage`）在组合时 provide，
 * 摘要卡按 `(周次, 星期, 是否今天)` 自己取一份 [DayViewSharedFreeUi]。
 *
 * ## 为什么走 CompositionLocal 而不是逐层加参数
 *
 * 摘要卡在 `DayViewPage` → `DayViewScrollContent` 深处，而数据（我的课 / 对方课 /
 * 周偏移 / 节次表）只在首页周视图这一层拿得到。逐层加参数要动三个文件、还会把
 * `pages/timetable/day` 的公开签名绑到情侣数据上；CompositionLocal 与同目录既有的
 * `LocalEmbeddedDayGlassBackdrop` 一族同一套做法。
 *
 * 没有绑定 / 没开叠加时 provide null ⇒ 模块整块不渲染（发布版同口径：
 * `_isCoupleOverlayActive` 为假就不挂）。
 */
data class DayViewSharedFreeSource(
    /** 我的全部课程（按周筛选在 [DayViewSharedFreeLogic] 里做）。 */
    val myCourses: List<Course>,
    /** 对方档案里的全部课程。 */
    val partnerCourses: List<Course>,
    /** 绑定里的周偏移（原值；钳制在 [DayViewSharedFreeLogic.partnerWeekForMyWeek]）。 */
    val partnerWeekOffset: Int,
    /** 当前生效节次表：只在课程缺墙上钟点时兜底（发布版 `_sectionsForSharedFree`）。 */
    val sections: List<SectionTime>,
    /** 对方课表上次导入时间（null = 未知 ⇒ 按过期处理，与 Dart 同口径）。 */
    val partnerImportedAtMillis: Long? = null,
) {

    /** 解析这一天的模块快照。 */
    fun uiFor(
        week: Int,
        dayOfWeek: Int,
        isToday: Boolean,
        nowMillis: Long = System.currentTimeMillis(),
    ): DayViewSharedFreeUi {
        val intervals = DayViewSharedFreeLogic.sharedFreeIntervalsForDay(
            myCourses = myCourses,
            partnerCourses = partnerCourses,
            dayOfWeek = dayOfWeek,
            week = week,
            partnerWeekOffset = partnerWeekOffset,
            sections = sections,
        )
        val formatted = intervals.map { DayViewSharedFreeLogic.formatMinuteInterval(it) }
        val isStale = DayViewSharedFreeLogic.isPartnerScheduleStale(partnerImportedAtMillis, nowMillis)
        return DayViewSharedFreeUi(
            title = if (isToday) {
                DayViewStrings.coupleTimetableSharedFreeTitle.text
            } else {
                DayViewStrings.coupleTimetableSharedFreeTitleOtherDay.text
            },
            emptyLabel = if (formatted.isEmpty()) {
                if (isToday) {
                    DayViewStrings.coupleTimetableNoSharedFree.text
                } else {
                    DayViewStrings.coupleTimetableNoSharedFreeOtherDay.text
                }
            } else {
                null
            },
            metaLabel = if (formatted.isEmpty()) {
                null
            } else {
                DayViewStrings.coupleTimetableSharedFreeMeta.filled("count", formatted.size)
            },
            intervals = formatted,
            moreLabel = (formatted.size - DayViewSharedFreeLogic.VISIBLE_SEGMENT_LIMIT)
                .takeIf { it > 0 }
                ?.let { DayViewStrings.coupleTimetableSharedFreeMoreCount.filled("count", it) },
            staleHint = if (isStale) DayViewStrings.coupleTimetableSharedFreeStaleHint.text else null,
        )
    }
}

/** 首页周视图 provide、摘要卡 consume 的共同空闲数据源（见 [DayViewSharedFreeSource]）。 */
val LocalDayViewSharedFree = staticCompositionLocalOf<DayViewSharedFreeSource?> { null }

/**
 * 共同空闲的纯逻辑（逐行对齐 `lib/domain/couple_timetable_logic.dart`，v2.1.4.1）。
 *
 * 口径要点（照抄发布版注释，别自己简化）：
 * - 观测窗口是**整个自然日 00:00–24:00**，不是节次跨度：凌晨课 / 晚课都算忙碌
 *   （`couple_timetable_logic.dart:27-34`）；
 * - 节次表只在课程**缺有效墙上钟点**时兜底，不用来裁剪窗口（`:209-215`）；
 * - 对方周次 = 我的周次 + 周偏移（`:46-48`，`+` 不是 `-`）；
 * - 空闲 = 双方忙碌并集的补集（`:216-246`）。
 */
object DayViewSharedFreeLogic {

    /** `CoupleTimetableLogic.freeSlotColorHex`（`:23`）：空闲绿。 */
    const val FREE_SLOT_COLOR_HEX = "#4CAF50"

    /** 发布版 `_sharedFreeVisibleSegmentLimit = 2`（`timetable_screen.dart:419`）。 */
    const val VISIBLE_SEGMENT_LIMIT = 2

    /** 发布版 `_partnerScheduleStaleAfter = Duration(days: 7)`（`:420`）。 */
    const val STALE_AFTER_MILLIS = 7L * 24L * 60L * 60L * 1000L

    const val DAY_OBSERVATION_START_MINUTES = 0
    const val DAY_OBSERVATION_END_MINUTES = 24 * 60

    const val MIN_WEEK_OFFSET = -15
    const val MAX_WEEK_OFFSET = 15

    /** 对方课表是否可能过期：没记导入时间（旧绑定）也算（Dart `:827-833`）。 */
    fun isPartnerScheduleStale(partnerImportedAtMillis: Long?, nowMillis: Long): Boolean {
        val importedAt = partnerImportedAtMillis ?: return true
        return nowMillis - importedAt > STALE_AFTER_MILLIS
    }

    /** 「我的第 N 周」↔「对方的第几周」（Dart `partnerWeekForMyWeek`，`:46-48`）。 */
    fun partnerWeekForMyWeek(myWeek: Int, weekOffset: Int): Int =
        myWeek + weekOffset.coerceIn(MIN_WEEK_OFFSET, MAX_WEEK_OFFSET)

    /** 该天该周有课、且能算出钟点区间的课程 → 忙碌区间（已合并）。 */
    fun busyIntervalsForDay(
        courses: List<Course>,
        dayOfWeek: Int,
        week: Int,
        sections: List<SectionTime>,
    ): List<DayViewMinuteInterval> {
        val intervals = mutableListOf<DayViewMinuteInterval>()
        courses.forEach { course ->
            if (course.dayOfWeek != dayOfWeek || !course.isActiveInWeek(week)) return@forEach
            val interval = courseBusyInterval(course, sections) ?: return@forEach
            intervals.add(interval)
        }
        return mergeMinuteIntervals(intervals)
    }

    /**
     * 单门课的忙碌区间：优先课程自己的墙上钟点，其次按节次表换算。
     *
     * 钟点串非法（`08.30` / `8` / 空串）不能当 0 用——发布版 `:411-420` 记录了这条
     * 历史事故：一端当 0 会让「从午夜开始占一整天」，空闲段凭空少一大截。
     */
    fun courseBusyInterval(course: Course, sections: List<SectionTime>): DayViewMinuteInterval? {
        val clockStart = clockToMinutes(course.startTime)
        val clockEnd = clockToMinutes(course.endTime)
        if (clockStart != null && clockEnd != null && clockEnd > clockStart) {
            return DayViewMinuteInterval(clockStart, clockEnd)
        }
        val sectionStart = sectionStartMinutes(sections, course.startSection) ?: return null
        val sectionEnd = sectionEndMinutes(sections, course.endSection) ?: return null
        if (sectionEnd <= sectionStart) return null
        return DayViewMinuteInterval(sectionStart, sectionEnd)
    }

    /** 双方共同空闲：双方忙碌区间并集的补集（Dart `:216-246`）。 */
    fun sharedFreeIntervalsForDay(
        myCourses: List<Course>,
        partnerCourses: List<Course>,
        dayOfWeek: Int,
        week: Int,
        partnerWeekOffset: Int,
        sections: List<SectionTime>,
    ): List<DayViewMinuteInterval> {
        val partnerWeek = partnerWeekForMyWeek(week, partnerWeekOffset)
        val myBusy = busyIntervalsForDay(myCourses, dayOfWeek, week, sections)
        val partnerBusy = busyIntervalsForDay(partnerCourses, dayOfWeek, partnerWeek, sections)
        val unionBusy = mergeMinuteIntervals(myBusy + partnerBusy)
        return invertMinuteIntervals(
            unionBusy,
            rangeStart = DAY_OBSERVATION_START_MINUTES,
            rangeEnd = DAY_OBSERVATION_END_MINUTES,
        )
    }

    /** 合并相邻 / 重叠区间（Dart `:288-312`）。 */
    fun mergeMinuteIntervals(intervals: List<DayViewMinuteInterval>): List<DayViewMinuteInterval> {
        if (intervals.isEmpty()) return emptyList()
        val sorted = intervals.sortedBy { it.startMinutes }
        val merged = mutableListOf(sorted.first())
        for (index in 1 until sorted.size) {
            val current = sorted[index]
            val last = merged.last()
            if (current.startMinutes <= last.endMinutes) {
                merged[merged.size - 1] = DayViewMinuteInterval(
                    startMinutes = last.startMinutes,
                    endMinutes = maxOf(current.endMinutes, last.endMinutes),
                )
            } else {
                merged.add(current)
            }
        }
        return merged
    }

    /** 补集（Dart `:314-345`）。 */
    fun invertMinuteIntervals(
        busy: List<DayViewMinuteInterval>,
        rangeStart: Int,
        rangeEnd: Int,
    ): List<DayViewMinuteInterval> {
        if (rangeEnd <= rangeStart) return emptyList()
        if (busy.isEmpty()) return listOf(DayViewMinuteInterval(rangeStart, rangeEnd))
        val free = mutableListOf<DayViewMinuteInterval>()
        var cursor = rangeStart
        busy.forEach { interval ->
            if (interval.startMinutes > cursor) {
                free.add(DayViewMinuteInterval(cursor, interval.startMinutes))
            }
            if (interval.endMinutes > cursor) cursor = interval.endMinutes
        }
        if (cursor < rangeEnd) free.add(DayViewMinuteInterval(cursor, rangeEnd))
        return free
    }

    /** `HH:mm-HH:mm`（Dart `formatMinuteInterval`，`:391-393`）。 */
    fun formatMinuteInterval(interval: DayViewMinuteInterval): String =
        "${minutesToClock(interval.startMinutes)}-${minutesToClock(interval.endMinutes)}"

    fun minutesToClock(minutes: Int): String =
        String.format(Locale.ROOT, "%02d:%02d", minutes / 60, minutes % 60)

    /** 宽进的 `HH:mm` 解析（`24:00` 合法；畸形串返回 null，不回 0）。 */
    fun clockToMinutes(raw: String?): Int? =
        ClockTime.tryParse(raw, allowEndOfDay = true)?.totalMinutes

    /**
     * 卡面内强调色文字的可读变体（Dart `readableAccentOnCardInk`，
     * `lib/utils/home_page_background.dart:958-981`）：
     * 只调明度不换色相——浅卡向黑压暗（亮度 ≤0.12），深卡向白提亮（≥0.50），
     * 本就可读的原样返回。`#4CAF50` 直接当文字色在中明度卡面上只有 ~2.8:1。
     */
    fun readableAccentOnCardInk(accent: Color, cardInk: Color): Color {
        val cardIsLight = cardInk.luminance() <= 0.5f
        fun readable(luminance: Float): Boolean =
            if (cardIsLight) luminance <= 0.12f else luminance >= 0.50f
        if (readable(accent.luminance())) return accent
        val target = if (cardIsLight) Color.Black else Color.White
        for (step in 1..20) {
            val candidate = lerpColor(accent, target, step / 20f)
            if (readable(candidate.luminance())) return candidate
        }
        return target
    }

    /** 按通道线性插值（Dart `Color.lerp` 的 sRGB 口径；20 步 = 每步 5%）。 */
    private fun lerpColor(start: Color, stop: Color, fraction: Float): Color = Color(
        red = start.red + (stop.red - start.red) * fraction,
        green = start.green + (stop.green - start.green) * fraction,
        blue = start.blue + (stop.blue - start.blue) * fraction,
        alpha = start.alpha + (stop.alpha - start.alpha) * fraction,
    )

    private fun sectionStartMinutes(sections: List<SectionTime>, section: Int): Int? {
        val index = section - 1
        if (index < 0 || index >= sections.size) return null
        return clockToMinutes(sections[index].startTime)
    }

    private fun sectionEndMinutes(sections: List<SectionTime>, section: Int): Int? {
        val index = section - 1
        if (index < 0 || index >= sections.size) return null
        return clockToMinutes(sections[index].endTime)
    }
}

/** 一天的分钟区间（`[start, end)`，Dart `MinuteInterval`，`couple_timetable_logic.dart:10-17`）。 */
data class DayViewMinuteInterval(
    val startMinutes: Int,
    val endMinutes: Int,
) {
    val durationMinutes: Int get() = endMinutes - startMinutes
}

/**
 * 「共同空闲」面板本体：浅洗底 + 细描边，**跟随母卡墨色**（发布版
 * `_buildSharedFreeSummaryShell`，`timetable_day_view_part.dart:852-874`）。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DayViewSharedFreePanel(
    ui: DayViewSharedFreeUi,
    ink: Color,
    dark: Boolean,
) {
    val shape = RoundedCornerShape(12.dp)
    // 次级文字与母卡同一套派生（浅墨 0.72 / 深墨 0.70，与摘要卡其他地方同源）。
    val mutedInk = Color(HomeBackgroundModel.mutedInkOverWallpaperArgb(ink.toArgb()))
    val accent = DayViewSharedFreeLogic.readableAccentOnCardInk(
        accent = Color(
            HomeBackgroundModel.parseInkArgb(DayViewSharedFreeLogic.FREE_SLOT_COLOR_HEX)
                ?: QingyuTheme.primary(null, dark),
        ),
        cardInk = ink,
    )
    var expanded by remember { mutableStateOf(false) }
    // 先把可空字段取成本地值：`if (x != null)` 之后再读参数上的属性，交给局部变量可读性
    // 与空安全都更直白（Compose 的 @Composable 参数列表不做智能转换）。
    val metaLabel = ui.metaLabel
    val emptyLabel = ui.emptyLabel
    val moreLabel = ui.moreLabel
    val staleHint = ui.staleHint
    val visibleLimit = if (expanded) {
        ui.intervals.size
    } else {
        DayViewSharedFreeLogic.VISIBLE_SEGMENT_LIMIT
    }
    val visibleIntervals = ui.intervals.take(visibleLimit)
    val hiddenCount = ui.intervals.size - visibleIntervals.size

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(ink.copy(alpha = 0.06f))
            .border(1.dp, ink.copy(alpha = 0.10f), shape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = ui.title,
                style = MiuixTheme.textStyles.footnote1,
                color = ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (metaLabel != null) {
                Spacer(modifier = Modifier.width(8.dp))
                SharedFreePill(text = metaLabel, accent = accent, radius = 7.dp)
            }
        }
        Spacer(modifier = Modifier.height(if (ui.intervals.isEmpty()) 6.dp else 10.dp))
        if (ui.intervals.isEmpty()) {
            if (emptyLabel != null) {
                Text(
                    text = emptyLabel,
                    style = MiuixTheme.textStyles.footnote2,
                    color = mutedInk,
                )
            }
        } else {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                visibleIntervals.forEach { label ->
                    SharedFreePill(text = label, accent = accent, radius = 999.dp)
                }
                if (hiddenCount > 0 && moreLabel != null) {
                    SharedFreePill(
                        text = moreLabel,
                        accent = accent,
                        radius = 999.dp,
                        onClick = { expanded = true },
                    )
                }
            }
        }
        if (staleHint != null) {
            Spacer(modifier = Modifier.height(if (ui.intervals.isEmpty()) 4.dp else 8.dp))
            Text(
                text = staleHint,
                style = MiuixTheme.textStyles.footnote2,
                color = mutedInk,
            )
        }
    }
}

/** 面板里的小胶囊：强调色 10% 底 + 强调色文字；`onClick` 非空时是展开按钮。 */
@Composable
private fun SharedFreePill(
    text: String,
    accent: Color,
    radius: Dp,
    onClick: (() -> Unit)? = null,
) {
    val shape = RoundedCornerShape(radius)
    val padding = if (onClick != null) {
        PaddingValues(horizontal = 9.dp, vertical = 5.dp)
    } else {
        PaddingValues(horizontal = 8.dp, vertical = 3.dp)
    }
    Box(
        modifier = Modifier
            .clip(shape)
            .background(accent.copy(alpha = 0.10f))
            .then(
                if (onClick != null) {
                    Modifier.clickable(role = Role.Button, onClick = onClick)
                } else {
                    Modifier
                },
            )
            .padding(padding),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2,
            color = accent,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
