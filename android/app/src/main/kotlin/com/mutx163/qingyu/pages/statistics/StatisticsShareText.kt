package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.pages.statistics.charts.ChartsStrings

/**
 * 统计页「分享」的纯逻辑（2026-10-30 F12 新增）。
 *
 * ## 它解决什么问题
 *
 * `e.statistics` 顶栏那颗分享图标原先接的是 `onOpenShare = {}`：点了完全没反应。
 * 按清单 §二 F12 的要求，要么接真产物的分享，要么给一句实话——本文件选择**接真**，
 * 但没有照搬 Dart 的形态，原因见下。
 *
 * ## 与 Dart 的差异（有意，且必须说清楚）
 *
 * Dart `StatisticsShareService.exportAndShare` 是「把导出文档**光栅化成 PNG**，
 * 再连正文一起交给系统分享」（`statistics_share_service.dart:62-108`）。Kotlin 侧要复刻
 * 那条路需要：离屏 Compose 渲染 → Bitmap → 落盘 → `FileProvider` 授权（manifest 未注册，
 * 属 Lead 专属）→ `ACTION_SEND`。这条链本批不做（A 级批次，清单自己写着「改动最小、
 * 最忌回归」），**所以这里只做文本分享**：
 *
 * - 分享的是**真数据**（真统计快照算出来的指标，不是占位数字）；
 * - 走系统分享面板，用户能真的发出去；
 * - **不假装**是图片：不生成假的空图片，也不在界面上写「已导出图片」。
 *
 * 图片导出的缺口记在认领文件 `claims/F12-half-close.md` 的「未做」里，交下一批。
 *
 * ## 为什么这段文本不是「新文案」
 *
 * 正文用 ARB 现成的 `statisticsShareText`（`来自轻屿课表的学期统计`）+ `statisticsShareTitle`，
 * 指标行的标签与取值全部是**屏上已经在显示的那些字符串**（`StatisticsMetricView.label/value`）。
 * 也就是说：用户看到的每一个字，本来就在界面里；这里只是把它们按行连起来，
 * 没有引入任何需要重新审校的新句子（因此也不新增 ARB 键）。
 */
object StatisticsShareText {

    /** 分享面板的标题（Dart `ShareParams.subject: l10n.statisticsShareTitle`）。 */
    fun subject(): String = ChartsStrings.statisticsShareTitle.zh

    /**
     * 分享正文：标题 + 正文句 + 指标行。
     *
     * @param viewState 当前统计页视图状态（真数据）
     * @return 多行文本；**无数据时只回一句**（不拼空指标行）
     */
    fun build(viewState: CourseStatisticsViewState): String {
        val lines = arrayListOf(viewState.title, ChartsStrings.statisticsShareText.zh)
        lines += metricLines(viewState)
        return lines.joinToString("\n")
    }

    /**
     * 指标行：学期视图取 `semester.overview`，周视图取周次 + 课数 + 节数。
     *
     * 两个视图都给不出（`hasData == false` 或对应内容缺失）时回空表——
     * 绝不用「0 门课」冒充真实统计（那会是一句**假数据**）。
     *
     * 周视图第二行用 `statisticsWeeklyCourses`（「本周课程」）而不是
     * `statisticsSemesterLabelSections`（那句是「节课」，单独成行读不通）；
     * 第三节数用 `statisticsTrendTooltip`（「第 {week} 周 · {sections} 节」）整句拼，
     * 这样「周次 + 节数」共用一句现成文案，不必再造「节数」标签。
     */
    fun metricLines(viewState: CourseStatisticsViewState): List<String> {
        if (!viewState.hasData) return emptyList()

        viewState.semester?.let { semester ->
            if (semester.overview.isNotEmpty()) {
                return semester.overview.map { metric -> "${metric.label}：${metric.value}" }
            }
        }

        val week = viewState.week ?: return emptyList()
        return listOf(
            ChartsStrings.statisticsTrendTooltip.filled(
                "week" to week.weekNumber.toString(),
                "sections" to week.sectionCount.toString(),
            ),
            "${ChartsStrings.statisticsWeeklyCourses.zh}：${week.courseCount}",
        )
    }
}
