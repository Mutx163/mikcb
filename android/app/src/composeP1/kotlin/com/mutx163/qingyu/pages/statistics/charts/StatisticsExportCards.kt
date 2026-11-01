package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.R
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.statistics.Achievement
import com.mutx163.qingyu.statistics.CourseSemesterStat
import com.mutx163.qingyu.statistics.DataStory
import com.mutx163.qingyu.statistics.SemesterStats
import com.mutx163.qingyu.statistics.StatisticsExportModule
import com.mutx163.qingyu.statistics.StatisticsExportOptions
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.preference.CheckboxPreference

/**
 * 统计导出的四件套（对应 `lib/widgets/statistics/statistics_export_*.dart`，697 行）：
 * 文档、品牌条、精简排行、勾选弹层。
 *
 * 除品牌条右下角的二维码外没有新画法：二维码由 [QrEncodeModel] 算出黑白矩阵，
 * [QrCodeCanvas] 一格格填方块（Dart 侧是 `qr_flutter` 的 `QrImageView`）。
 *
 * 文档本身是**不可滚动的 Column**（Dart 注释：离屏截图要能量出完整高度），
 * 所以这里也不加 `verticalScroll`——外层要截多高就由它自己撑。
 */

// ══════════════════════ 二维码 ══════════════════════

/**
 * 二维码画布。
 *
 * 25×25 模块按边长均分；每个模块补 1 像素的绘制余量，避免相邻黑块之间出现发丝缝
 * （Dart 侧 `qr_flutter` 用矢量绘制，没有这个问题）。
 */
@Composable
fun QrCodeCanvas(
    matrix: QrMatrix,
    ink: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        val cell = size.minDimension / matrix.size
        // 多画 0.5px 把缝隙盖掉
        val paint = cell + 0.5f
        for (y in 0 until matrix.size) {
            for (x in 0 until matrix.size) {
                if (!matrix.isDark(x, y)) continue
                drawRect(
                    color = ink,
                    topLeft = Offset(x * cell, y * cell),
                    size = Size(paint, paint),
                )
            }
        }
    }
}

// ══════════════════════ 品牌条 ══════════════════════

/**
 * 导出图专属的品牌条（顶部 / 底部各用一次）。
 *
 * 左边 40dp 圆角图标，中间三行（App 名 / 一句话 / 网址），右边正方形二维码。
 * 二维码边长跟着文字块高度走（[ExportBrandModel.qrSize]，夹在 48~72），
 * 与 Dart 一样**不用**「文字块撑高再定宽」的写法——那会让 LayoutBuilder 类的
 * 二维码参与固有测量而崩掉。
 *
 * @param showTopDivider 顶部分隔线（页脚用）
 * @param showBottomDivider 底部分隔线（页头用）
 */
@Composable
fun StatisticsExportBrandBar(
    dark: Boolean,
    modifier: Modifier = Modifier,
    showTopDivider: Boolean = false,
    showBottomDivider: Boolean = false,
) {
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val linkColor = Color(QingyuTheme.primary(dark = dark))
    val dividerColor = Color(QingyuTheme.dividerLine(dark))
        .copy(alpha = ExportBrandModel.DIVIDER_ALPHA)

    val qrSize = ExportBrandModel.defaultQrSize().dp
    val matrix = remember { QrEncodeModel.encode(ExportBrandModel.websiteUrl) }
    // 二维码的墨色：亮色用黑、暗色用白（Dart `isDark ? Colors.white : 0xFF111111`）。
    //
    // 这是**功能性固定色**，不是主题色：二维码靠模块与静默区的高对比被扫码器识别，
    // 跟着主题色走（比如取 primary）会直接降低识别率。所以这里取 Compose 内置常量
    // `Color.Black` / `Color.White`——亮色下 0xFF000000 与 Dart 的 0xFF111111 都是「纯黑系」，
    // 对比度只增不减；同时不再往页面里写十六进制字面量（规则 R5）。
    val ink = if (dark) Color.White else Color.Black

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = ExportBrandModel.OUTER_PADDING_DP.dp),
    ) {
        if (showTopDivider) {
            HorizontalDivider(color = dividerColor)
            Spacer(Modifier.height(ExportBrandModel.DIVIDER_GAP_DP.dp))
        }
        Row(verticalAlignment = Alignment.Top) {
            // 图标：自适应图标的两层 PNG 叠起来画（Compose 侧没有 Flutter 的 bundled asset）
            Box(
                modifier = Modifier
                    .size(ExportBrandModel.LOGO_SIZE_DP.dp)
                    .clip(RoundedCornerShape(ExportBrandModel.LOGO_RADIUS_DP.dp)),
            ) {
                Image(
                    painter = painterResource(id = R.mipmap.ic_launcher_background),
                    contentDescription = null,
                    modifier = Modifier.size(ExportBrandModel.LOGO_SIZE_DP.dp),
                    contentScale = ContentScale.Crop,
                )
                Image(
                    painter = painterResource(id = R.mipmap.ic_launcher_foreground),
                    contentDescription = null,
                    modifier = Modifier.size(ExportBrandModel.LOGO_SIZE_DP.dp),
                    contentScale = ContentScale.Crop,
                )
            }
            Spacer(Modifier.width(ExportBrandModel.LOGO_TO_TEXT_GAP_DP.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = ExportBrandModel.appName,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
                    color = primaryText,
                )
                Spacer(Modifier.height(ExportBrandModel.TITLE_TO_TAGLINE_GAP_DP.dp))
                Text(
                    text = ExportBrandModel.tagline,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                )
                Spacer(Modifier.height(ExportBrandModel.TAGLINE_TO_URL_GAP_DP.dp))
                Text(
                    text = ExportBrandModel.websiteDisplay,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = linkColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.width(ExportBrandModel.TEXT_TO_QR_GAP_DP.dp))
            QrCodeCanvas(
                matrix = matrix,
                ink = ink,
                modifier = Modifier.size(qrSize),
            )
        }
        if (showBottomDivider) {
            Spacer(Modifier.height(ExportBrandModel.DIVIDER_GAP_DP.dp))
            HorizontalDivider(color = dividerColor)
        }
    }
}

// ══════════════════════ 文档 ══════════════════════

/**
 * 完整导出长图：品牌页头 + 勾选的模块 + 品牌页脚。
 *
 * 段落顺序与取舍全部来自 [ExportDocumentModel.sections]（勾了成就/故事但没数据时
 * 那一段不出现，总览段不看课程数）。
 */
@Composable
fun StatisticsExportDocument(
    options: StatisticsExportOptions,
    semesterStats: SemesterStats,
    achievements: List<Achievement>,
    stories: List<DataStory>,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val sections = ExportDocumentModel.sections(
        options = options,
        achievementCount = achievements.size,
        storyCount = stories.size,
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(Color(QingyuTheme.scaffoldBackground(dark)))
            .padding(
                start = ExportDocumentModel.PADDING_START_DP.dp,
                top = ExportDocumentModel.PADDING_TOP_DP.dp,
                end = ExportDocumentModel.PADDING_END_DP.dp,
                bottom = ExportDocumentModel.PADDING_BOTTOM_DP.dp,
            ),
    ) {
        StatisticsExportBrandBar(dark = dark, showBottomDivider = true)
        Spacer(Modifier.height(ExportDocumentModel.BRAND_TO_TITLE_GAP_DP.dp))
        Text(
            text = ExportDocumentModel.title,
            style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(Modifier.height(ExportDocumentModel.TITLE_TO_SECTIONS_GAP_DP.dp))

        sections.forEachIndexed { index, section ->
            if (index > 0) Spacer(Modifier.height(ExportDocumentModel.SECTION_GAP_DP.dp))
            when (section.kind) {
                // 总览块自带版式与标题，不套外层块标题
                ExportSectionKind.OVERVIEW -> OverviewSection(stats = semesterStats, dark = dark)
                ExportSectionKind.ACHIEVEMENTS -> ExportBlock(section.title, dark) {
                    AchievementBadgeGrid(achievements = achievements, dark = dark)
                }
                ExportSectionKind.STORIES -> ExportBlock(section.title, dark) {
                    DataStoryList(stories = stories, dark = dark)
                }
                ExportSectionKind.DAILY_DISTRIBUTION -> ExportBlock(section.title, dark) {
                    DailyChartCard(
                        spec = DailyChartModel.averageSpec(semesterStats.dailyAverages),
                        dark = dark,
                        chartHeightDp = DailyChartModel.AVERAGE_CHART_HEIGHT_DP,
                    )
                }
                ExportSectionKind.NATURE_RATIO -> ExportBlock(section.title, dark) {
                    NatureRatioCard(stats = semesterStats.natureStats, dark = dark)
                }
                ExportSectionKind.RANKING -> ExportBlock(section.title, dark) {
                    StatisticsExportCourseRanking(
                        courseRanking = semesterStats.courseRanking,
                        dark = dark,
                    )
                }
            }
        }

        Spacer(Modifier.height(ExportDocumentModel.SECTIONS_TO_FOOTER_GAP_DP.dp))
        StatisticsExportBrandBar(dark = dark, showTopDivider = true)
    }
}

/** 带块标题的一段（Dart `HyperosSettingsBlock`：标题在外、卡片在内）。 */
@Composable
private fun ExportBlock(
    title: String,
    dark: Boolean,
    content: @Composable () -> Unit,
) {
    Column {
        Text(
            text = title,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
        )
        content()
    }
}

// ══════════════════════ 精简课程排行 ══════════════════════

/**
 * 导出专用的紧凑课程排行。
 *
 * 与交互版 [CourseRankingCard] 的差异照抄 Dart：没有展开箭头、上课时间压成一行、
 * 硬性截断到 20 门（超长纹理会把 GPU 纹理上限顶爆）。
 */
@Composable
fun StatisticsExportCourseRanking(
    courseRanking: List<CourseSemesterStat>,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (courseRanking.isEmpty()) {
        QingyuCard(modifier = modifier.fillMaxWidth(), insideMargin = PaddingValues(0.dp)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 24.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = ExportRankingModel.emptyMessage,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
        return
    }

    val visible = ExportRankingModel.visible(courseRanking)
    val remainingLabel = ExportRankingModel.remainingLabel(courseRanking.size, visible.size)

    Column(modifier = modifier.fillMaxWidth()) {
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(0.dp)) {
            visible.forEachIndexed { index, stat ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 60.dp),
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                }
                ExportRankingRow(stat = stat, rank = index + 1, dark = dark)
            }
        }
        if (remainingLabel != null) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = remainingLabel,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp),
            )
        }
    }
}

/** 一行：名次徽章 + 课名/教师/时间 + 右侧节数。 */
@Composable
private fun ExportRankingRow(
    stat: CourseSemesterStat,
    rank: Int,
    dark: Boolean,
) {
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val scheduleSummary = ExportRankingModel.scheduleSummary(stat.slots)
    val isRequired = stat.nature == com.mutx163.qingyu.core.CourseNature.REQUIRED

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ExportRankBadge(rank = rank, dark = dark)
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stat.name,
                    style = MiuixTheme.textStyles.body1,
                    color = primaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Spacer(Modifier.width(6.dp))
                ExportNatureChip(isRequired = isRequired)
            }
            if (stat.teacher.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = stat.teacher,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (scheduleSummary.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = scheduleSummary,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Spacer(Modifier.width(8.dp))
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = stat.totalSections.toString(),
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.EXTRABOLD),
                color = Color(QingyuTheme.primary(dark = dark)),
            )
            Text(
                text = ExportRankingModel.sectionUnit,
                style = MiuixTheme.textStyles.footnote2,
                color = secondaryText,
            )
        }
    }
}

/**
 * 名次徽章：36dp、圆角 10。
 *
 * miuix 0.9.4 的扩展图标里没有奖杯，前三名改用「强调色底 + 加粗名次数字」，
 * 第 4 名起是灰底数字（Dart 前三名画 `emoji_events_rounded`）。
 */
@Composable
private fun ExportRankBadge(rank: Int, dark: Boolean) {
    val tone = ExportRankingModel.rankTone(rank)
    val foreground = when (tone) {
        ExportRankTone.GOLD -> ChartPalette.Yellow
        ExportRankTone.SILVER -> Color(QingyuTheme.secondaryText(dark))
        ExportRankTone.ORANGE -> ChartPalette.Orange
        ExportRankTone.PLAIN -> Color(QingyuTheme.secondaryText(dark))
    }
    Box(
        modifier = Modifier
            .size(ExportRankingModel.BADGE_SIZE_DP.dp)
            .clip(RoundedCornerShape(ExportRankingModel.BADGE_RADIUS_DP.dp))
            .background(foreground.copy(alpha = ExportRankingModel.badgeAlpha(rank))),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = ExportRankingModel.badgeText(rank) ?: rank.toString(),
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.BOLD),
            color = foreground,
        )
    }
}

/** 必修 / 选修小标签：必修蓝、选修紫，都是 12% 底色。 */
@Composable
private fun ExportNatureChip(isRequired: Boolean) {
    val accent = if (isRequired) ChartPalette.Blue else ChartPalette.Purple
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(accent.copy(alpha = ExportRankingModel.NATURE_CHIP_ALPHA))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(
            text = ExportRankingModel.natureLabel(isRequired),
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = accent,
        )
    }
}

// ══════════════════════ 勾选弹层 ══════════════════════

/**
 * 导出选项弹层的**内容**（Dart `_StatisticsExportSheet`，155 行）。
 *
 * 弹层外壳（`showHyperosSheet`）属交互层，这里只给内容：可勾选的模块列表 + 开始导出。
 * 勾选状态在内部用 `remember` 管；一个都没勾时**不**调 [onConfirm]，改调
 * [onEmptySelection]（Dart 此时弹一条警告 toast，toast 归调用方）。
 */
@Composable
fun StatisticsExportSheetContent(
    hasAchievements: Boolean,
    hasStories: Boolean,
    dark: Boolean,
    onConfirm: (StatisticsExportOptions) -> Unit,
    onEmptySelection: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val modules = remember(hasAchievements, hasStories) {
        ExportSheetModel.availableModules(
            hasAchievements = hasAchievements,
            hasStories = hasStories,
        )
    }
    var selection by remember(hasAchievements, hasStories) {
        mutableStateOf(
            ExportSheetModel.initialSelection(
                hasAchievements = hasAchievements,
                hasStories = hasStories,
            ),
        )
    }

    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = ExportSheetModel.modulesSectionLabel,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.padding(start = 4.dp),
        )
        Spacer(Modifier.height(ExportSheetModel.LABEL_TO_LIST_GAP_DP.dp))
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(0.dp)) {
            modules.forEachIndexed { index, module ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                }
                CheckboxPreference(
                    title = ExportSheetModel.moduleTitle(module),
                    checked = module in selection,
                    onCheckedChange = { enabled ->
                        selection = ExportSheetModel.toggle(selection, module, enabled)
                    },
                )
            }
        }
        Spacer(Modifier.height(ExportSheetModel.LIST_TO_ACTION_GAP_DP.dp))
        Button(
            onClick = {
                val options = ExportSheetModel.submit(selection)
                if (options == null) onEmptySelection() else onConfirm(options)
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(text = ExportSheetModel.actionLabel)
        }
    }
}
