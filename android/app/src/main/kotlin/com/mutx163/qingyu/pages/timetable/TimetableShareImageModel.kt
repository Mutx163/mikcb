package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.statistics.ExportBrandModel
import java.io.File
import java.time.LocalDate
import java.util.Locale

/**
 * 「干净课表图」导出与分享的**纯逻辑**（2026-11-03 新增，Dart
 * `lib/widgets/timetable_export_document.dart` + `timetable_share_service.dart` 的移植）。
 *
 * ## 它管什么、不管什么
 *
 * 只算「图应该长什么样（几何 + 内容）、文件叫什么、落在哪、Intent 里该带什么」，
 * 一行 `android.*` 都没有，能进 JVM 单测。真正画像素的活在 composeP1 的
 * `TimetableShareImageRender`（framework Canvas，同统计域 `StatisticsShareImageRender`
 * 的分层——分享回调里没有 Composition，离屏 ComposeView 不挂 window 不跑 composition，
 * 官方截图能力走不通，先例已写明）。
 *
 * ## 渲染口径（与 Dart 导出文档逐条对齐）
 *
 * * **导出宽度**：屏幕宽收进 [MIN_WIDTH_DP]~[MAX_WIDTH_DP]（Dart 360~460，比统计域
 *   320~420 宽一档——七列网格，太窄课程名挤成省略号）。
 * * **像素比**：[PIXEL_RATIO] = 2.5（Dart `ImageExportCapture.preferredPixelRatio` 同值）。
 * * **底色**：外框 `#F2F2F2`（Dart `ShareExportStyle.background`，统计域同源）；
 *   网格/列表装在纯白圆角卡里（Dart `_surfaceColor = Colors.white`、圆角 16、内边距 10）。
 * * **恒浅色**：分享图不跟深色模式（Dart `lightExportThemeOf` 的产品口径——暗色卡片
 *   发到微信等浅底场景会糊成一片），墨色全是固定 ARGB，不读主题令牌。
 * * **节高**：clamp(用户节高, 56, 110)（Dart `_minSectionHeight`/`_maxSectionHeight`——
 *   屏内节高是「塞进一屏」调的，直接搬进可缩放的图片要么密到看不清、要么空得发虚）。
 * * **时间列**：34 / 40dp（Dart `_resolveTimeColumnWidth`，narrow/wide 两档）。
 * * **可见天数**：隐藏周末 = 5，否则 7；日列宽 =（白卡内容宽 − 时间列）/ 天数。
 *
 * ## 与 Dart 的已知差距（写清楚，不假装）
 *
 * 1. 周网格课卡画的是「干净版」：课名 + 教师/地点两行小字（跟随 WeekViewStyle
 *    的显示开关），Dart compact 卡里的角标排布 / 天气行 / 铃铛 / 假期压淡等细节
 *    只带透明度与「非本周」灰化，不逐像素复刻。
 * 2. 品牌条没有 logo 图（要 drawable 解码），文字 + 二维码与统计域同源
 *    （[ExportBrandModel]）。
 * 3. Dart 超高长图走「切片再拼接」；Canvas 直接画没有 GPU 纹理上限，这里改成
 *    [pixelScaleClamp]：超过 [MAX_PIXEL_HEIGHT] 时整图等比缩小，保证单张出图。
 */
object TimetableShareImageModel {

    // --------------------------------------------------------------- 文件 / Uri 契约

    /** 分享出去的图一定是 PNG（与 Dart `XFile(path, mimeType: 'image/png')` 同）。 */
    const val MIME_PNG: String = "image/png"

    /**
     * 落盘文件名前缀/后缀：`timetable_share_<毫秒时间戳>.png`
     * （与 Dart `timetable_share_service.dart:73` 的 `'timetable_share_$timestamp.png'` 同口径）。
     * 时间戳防覆盖：同名会让上一张分享图被覆盖，接收方点开旧消息拿到的是新图。
     */
    const val FILE_PREFIX: String = "timetable_share_"
    const val FILE_SUFFIX: String = ".png"

    /** `ClipData` 标签：给接收方与排障用，不是用户文案。 */
    const val CLIP_LABEL: String = "qingyu-timetable-export"

    /** FileProvider 白名单里的 Uri 别名（↔ `file_paths.xml` 的 `name="timetable_share"`）。 */
    const val PROVIDER_PATH_NAME: String = "timetable_share"

    /** 真实子目录名（↔ `file_paths.xml` 的 `path="timetable-share/"`；连字符）。 */
    const val CACHE_DIR_NAME: String = "timetable-share"

    /** authority 后缀与 manifest `<provider>` 的 `${applicationId}.fileprovider` 逐字一致。 */
    const val PROVIDER_AUTHORITY_SUFFIX: String = ".fileprovider"

    fun fileName(epochMillis: Long): String = "$FILE_PREFIX$epochMillis$FILE_SUFFIX"

    /** 相对 `cacheDir` 的落盘路径：`timetable-share/timetable_share_<ts>.png`。 */
    fun cacheRelativePath(fileName: String): String = "$CACHE_DIR_NAME/$fileName"

    fun providerAuthority(applicationId: String): String = "$applicationId$PROVIDER_AUTHORITY_SUFFIX"

    /**
     * 导出前清理：删掉本目录里**上一次导出**留下的同前缀旧图（cacheDir 里的分享件
     * 本来就是临时副本，语义见 `file_paths.xml` 头注释；不清理会在长期使用后堆一小撮垃圾）。
     *
     * 只删 [FILE_PREFIX] 开头 + [FILE_SUFFIX] 结尾的文件，目录里别人（未来的其它导出）
     * 的东西不碰。删除失败不抛（cacheDir 被系统清过等场景），返回删掉几张。
     */
    fun cleanStaleExports(cacheDir: File): Int {
        if (!cacheDir.isDirectory) return 0
        var removed = 0
        cacheDir.listFiles()?.forEach { file ->
            val name = file.name
            if (file.isFile && name.startsWith(FILE_PREFIX) && name.endsWith(FILE_SUFFIX)) {
                if (file.delete()) removed++
            }
        }
        return removed
    }

    // --------------------------------------------------------------- 几何常量（dp）

    /** 导出图宽度（dp）区间（Dart `TimetableShareService._minExportWidth/_maxExportWidth`）。 */
    const val MIN_WIDTH_DP: Float = 360f
    const val MAX_WIDTH_DP: Float = 460f

    /** 像素比（Dart `ImageExportCapture.preferredPixelRatio`）：清晰度与绘制成本折中。 */
    const val PIXEL_RATIO: Float = 2.5f

    /** 单张 Bitmap 的像素高度上限；超过即整图等比缩小（见 [pixelScaleClamp]）。 */
    const val MAX_PIXEL_HEIGHT: Int = 16_384

    /** 外框内边距（Dart `EdgeInsets.fromLTRB(16, 16, 16, 20)`）。 */
    const val OUTER_PADDING_START_DP: Float = 16f
    const val OUTER_PADDING_TOP_DP: Float = 16f
    const val OUTER_PADDING_END_DP: Float = 16f
    const val OUTER_PADDING_BOTTOM_DP: Float = 20f

    /** 标题 / 副标题字号（Dart `HyperosTypography.sheetTitle` / `listDetail` 的视觉口径）。 */
    const val TITLE_TEXT_DP: Float = 17f
    const val SUBTITLE_TEXT_DP: Float = 13f
    const val TITLE_TO_SUBTITLE_GAP_DP: Float = 2f
    const val TITLE_BLOCK_TO_SURFACE_GAP_DP: Float = 12f
    const val SURFACE_TO_FOOTER_GAP_DP: Float = 12f

    /** 白卡：圆角 16、内边距 10（Dart `_surfaceRadius` / `_surfacePadding`）。 */
    const val SURFACE_RADIUS_DP: Float = 16f
    const val SURFACE_PADDING_DP: Float = 10f

    /** 周网格：表头高 40（Dart `_weekdayHeaderHeight`）。 */
    const val WEEKDAY_HEADER_HEIGHT_DP: Float = 40f

    /** 节高上下限（Dart `_minSectionHeight` / `_maxSectionHeight`）。 */
    const val MIN_SECTION_HEIGHT_DP: Float = 56f
    const val MAX_SECTION_HEIGHT_DP: Float = 110f

    /** 日视图行：水平内边距 12、行内上下留白 12（Dart `_buildCourseRow` 的 Padding）。 */
    const val DAY_ROW_PADDING_HORIZONTAL_DP: Float = 12f
    const val DAY_ROW_PADDING_VERTICAL_DP: Float = 12f
    /** 色条 4×40、与文字间隙 10（Dart 同值）。 */
    const val DAY_ROW_BAR_WIDTH_DP: Float = 4f
    const val DAY_ROW_BAR_HEIGHT_DP: Float = 40f
    const val DAY_ROW_BAR_TO_TEXT_GAP_DP: Float = 10f
    /** 日行内容高度：时间行 13 + 2 + 课名 15（行高按 1.3 折算后取整，见 [dayRowContentHeightDp]）。 */
    const val DAY_ROW_MIN_CONTENT_HEIGHT_DP: Float = 40f
    /** 空日上下留白 28（Dart `_buildDaySurface` 空态 Padding）。 */
    const val DAY_EMPTY_PADDING_VERTICAL_DP: Float = 28f

    /** 品牌条：上间隙 12 + 分隔线 1 + 内容上间隙 10（统计域 render 同口径）。 */
    const val FOOTER_TOP_GAP_DP: Float = 12f
    const val FOOTER_DIVIDER_THICKNESS_DP: Float = 1f
    const val FOOTER_DIVIDER_GAP_DP: Float = 10f

    // --------------------------------------------------------------- 几何纯函数

    /** 导出宽度：屏幕可用宽收进 [MIN_WIDTH_DP]~[MAX_WIDTH_DP]（Dart 同口径）。 */
    fun exportWidthDp(availableWidthDp: Float): Float =
        availableWidthDp.coerceIn(MIN_WIDTH_DP, MAX_WIDTH_DP)

    /** 导出节高：用户节高收进 56~110（Dart `settings.sectionHeight.clamp(...)`）。 */
    fun exportSectionHeightDp(userSectionHeightDp: Float): Float =
        userSectionHeightDp.coerceIn(MIN_SECTION_HEIGHT_DP, MAX_SECTION_HEIGHT_DP)

    /** 周网格体高 = 节数 × 节高（不含表头）。节数 ≤ 0 回 0。 */
    fun weekGridBodyHeightDp(sectionCount: Int, sectionHeightDp: Float): Float =
        (sectionCount.coerceAtLeast(0) * sectionHeightDp)

    /** 周网格总高 = 表头 + 体高（白卡内网格的部分）。 */
    fun weekGridHeightDp(sectionCount: Int, sectionHeightDp: Float): Float =
        WEEKDAY_HEADER_HEIGHT_DP + weekGridBodyHeightDp(sectionCount, sectionHeightDp)

    /** 日列宽 =（可用宽 − 时间列）/ 天数（Dart `_buildTimetableGrid` 同式，天数保底 1）。 */
    fun dayColumnWidthDp(availableWidthDp: Float, timeColumnWidthDp: Float, visibleDayCount: Int): Float {
        val usable = (availableWidthDp - timeColumnWidthDp).coerceAtLeast(0f)
        return usable / visibleDayCount.coerceAtLeast(1)
    }

    /** 课卡顶部 =（起始节 − 1）× 节高；起始节 < 1 按 1。 */
    fun cardTopDp(startSection: Int, sectionHeightDp: Float): Float =
        (startSection - 1).coerceAtLeast(0) * sectionHeightDp

    /** 课卡高 = 跨度 × 节高；跨度保底 1。 */
    fun cardHeightDp(startSection: Int, endSection: Int, sectionHeightDp: Float): Float =
        (endSection - startSection + 1).coerceAtLeast(1) * sectionHeightDp

    /**
     * 日视图一行的内容高度：时间行与课名行按 1.3 行距折算 + 间隙 2 + 详情行（可空）。
     * 与色条高（40）取大者——Dart 的 Row 高由两者撑开，这里显式算死，渲染层不再量。
     */
    fun dayRowContentHeightDp(hasDetails: Boolean): Float {
        val timeLine = DAY_ROW_TEXT_DP * 1.3f
        val nameLine = DAY_ROW_NAME_TEXT_DP * 1.3f
        val detailLine = if (hasDetails) DAY_ROW_DETAIL_TEXT_DP * 1.3f + DAY_ROW_TEXT_GAP_DP else 0f
        val textBlock = timeLine + DAY_ROW_TEXT_GAP_DP + nameLine + detailLine
        return maxOf(DAY_ROW_BAR_HEIGHT_DP, textBlock)
    }

    /** 日行内文字间隙 / 时间行与课名行间隙（Dart `SizedBox(height: 2)`）。 */
    const val DAY_ROW_TEXT_GAP_DP: Float = 2f
    /** 日行字号（Dart `listDetail`=13 / `listTitle`=15 的视觉口径）。 */
    const val DAY_ROW_TEXT_DP: Float = 13f
    const val DAY_ROW_NAME_TEXT_DP: Float = 15f
    const val DAY_ROW_DETAIL_TEXT_DP: Float = 13f

    /** 日视图列表体高 = Σ 行高 + 行间分隔线（1px 按 1dp 画）；行数 0 回 0。 */
    fun dayListHeightDp(rows: List<DayRow>): Float {
        if (rows.isEmpty()) return 0f
        val rowHeights = rows.sumOf { (dayRowContentHeightDp(it.details != null) + DAY_ROW_PADDING_VERTICAL_DP * 2).toDouble() }
        val dividers = (rows.size - 1).toDouble()
        return (rowHeights + dividers).toFloat()
    }

    /**
     * 整张图的逻辑高度（dp）。
     *
     * 周图 = 上边距 + 标题块 + 12 + 白卡（10 + 网格 + 10）+ 12 + 品牌条 + 下边距；
     * 日图把白卡里的网格换成日列表（或空态）。品牌条内容高与统计域同一套
     * [ExportBrandModel] 口径（文字块高夹 48~72dp）。
     */
    fun documentHeightDp(doc: Document): Float {
        val titleBlock = TITLE_TEXT_DP * 1.3f +
            (doc.subtitle?.let { TITLE_TO_SUBTITLE_GAP_DP + SUBTITLE_TEXT_DP * 1.3f } ?: 0f)
        val surfacePadding = SURFACE_PADDING_DP * 2
        val surfaceContent = if (doc.dayOfWeek == null) {
            weekGridHeightDp(doc.sections.size, doc.sectionHeightDp)
        } else if (doc.dayRows.isEmpty()) {
            DAY_EMPTY_PADDING_VERTICAL_DP * 2 + SUBTITLE_TEXT_DP * 1.3f
        } else {
            dayListHeightDp(doc.dayRows)
        }
        val footerContent = maxOf(
            ExportBrandModel.textBlockHeight(
                titleFontSize = FOOTER_TITLE_TEXT_DP,
                detailFontSize = FOOTER_DETAIL_TEXT_DP,
            ),
            ExportBrandModel.qrSize(
                ExportBrandModel.textBlockHeight(
                    titleFontSize = FOOTER_TITLE_TEXT_DP,
                    detailFontSize = FOOTER_DETAIL_TEXT_DP,
                ),
            ),
        )
        val footer = FOOTER_TOP_GAP_DP + FOOTER_DIVIDER_THICKNESS_DP + FOOTER_DIVIDER_GAP_DP + footerContent
        return OUTER_PADDING_TOP_DP + titleBlock + TITLE_BLOCK_TO_SURFACE_GAP_DP +
            surfacePadding + surfaceContent +
            SURFACE_TO_FOOTER_GAP_DP + footer + OUTER_PADDING_BOTTOM_DP
    }

    /** 品牌条字号（统计域 `StatisticsShareImageRender` 的 BRAND_* 同值）。 */
    const val FOOTER_TITLE_TEXT_DP: Float = 15f
    const val FOOTER_DETAIL_TEXT_DP: Float = 11f

    /**
     * 像素高度保护：实际像素高超过 [MAX_PIXEL_HEIGHT] 时回「等比缩小系数」（<1），
     * 否则回 1。Canvas 侧按它 `scale` 绘制，保证单张出图不炸内存。
     * （Dart 走切片拼接是因为 Flutter `toImage` 有 GPU 纹理上限；Canvas 软绘没有，
     * 缩放比切片简单且不会出现接缝。）
     */
    fun pixelScaleClamp(heightDp: Float, density: Float): Float {
        val pixelHeight = heightDp * density * PIXEL_RATIO
        if (pixelHeight <= MAX_PIXEL_HEIGHT) return 1f
        return MAX_PIXEL_HEIGHT / pixelHeight
    }

    // --------------------------------------------------------------- 颜色

    /**
     * `#RRGGBB` → ARGB（不透明）。畸形输入回 [fallback]。
     * 与 Dart `parseHexColorOrFallback` 同语义（课程色 / 表头强调色都走它）。
     */
    fun parseHexArgb(hex: String?, fallback: Int): Int {
        val trimmed = hex?.trim() ?: return fallback
        if (trimmed.isEmpty()) return fallback
        val body = if (trimmed.startsWith("#")) trimmed.substring(1) else trimmed
        if (body.length != 6) return fallback
        if (body.any { it !in '0'..'9' && it !in 'a'..'f' && it !in 'A'..'F' }) return fallback
        return (0xFF000000.toInt() or body.toInt(16))
    }

    // --------------------------------------------------------------- 数据模型

    /** 周网格一张课卡（几何与文案都在模型层算好，渲染层只画）。 */
    data class Card(
        val dayOfWeek: Int,
        val startSection: Int,
        val endSection: Int,
        val topDp: Float,
        val heightDp: Float,
        /** 课程色（统一卡色优先），已解析成 ARGB。 */
        val colorArgb: Int,
        /** 卡面透明度（冲突 / 非本周压淡，`WeekCardModel.opacity` 原样）。 */
        val opacity: Float,
        /** 课名（compact 卡标题；空课名画不出东西，调用方给 shortName 兜底）。 */
        val title: String,
        /** 教师 / 地点合并行（各自为空就略，全空为 null——不画空行）。 */
        val subtitle: String?,
        /** 左上角小字（「非本周」；Dart compact 卡同位）。null = 不画。 */
        val overline: String?,
        /**
         * 是否非本周课（Dart 非本周固定灰 `#94A3B8` + 0.62 透明度）。
         * 与 [overline] 分开：冲突卡有小字但不灰化。
         */
        val isNonCurrentWeek: Boolean,
    )

    /** 日视图一行（Dart `_buildCourseRow` 的数据面）。 */
    data class DayRow(
        val timeRange: String,
        val sectionLabel: String,
        val name: String,
        /** 教师 · 地点（全空为 null——不画空行）。 */
        val details: String?,
        /** 色条颜色（课程色原样，Dart 日视图不取统一卡色）。 */
        val colorArgb: Int,
    )

    /**
     * 一张待光栅化的导出文档。周图（[dayOfWeek] = null）与日图共用一个形状：
     * 周图吃 [cardsByDay]，日图吃 [dayRows]（空表 = 画空态文案）。
     */
    data class Document(
        val title: String,
        /** 日图副标题（「10月8日」）；周图恒 null（Dart 同口径：开学日没配也不显示）。 */
        val subtitle: String?,
        /** null = 周图；1..7 = 日图。 */
        val dayOfWeek: Int?,
        /** 节次表（周图时间轴文本用；日图给空表）。 */
        val sections: List<SectionTime>,
        /** 时间列显示档（周图；日图忽略）。 */
        val sectionTimeMode: WeekSectionTimeMode,
        val sectionHeightDp: Float,
        val timeColumnWidthDp: Float,
        val visibleDays: List<Int>,
        /** 表头左侧「{week} 周」文案。 */
        val weekCompactLabel: String,
        /** 表头每天的「周一」标签（键 = 1..7 的可见子集）。 */
        val weekdayLabels: Map<Int, String>,
        /** 表头每天的日期（MM/dd）；开学日没配为 null → 不写日期。 */
        val weekdayDates: Map<Int, String?>,
        /**
         * 「今天」在这周里的星期几（1..7）；今天不在本周 / 没配开学日为 null。
         * 表头高亮在组装时算好（渲染层不再摸日期换算）。
         */
        val todayDayOfWeek: Int?,
        /** 表头强调色（今天的周几/日期；Dart weekdayBarAccentColorLight 的默认 #2563EB）。 */
        val accentArgb: Int,
        val cardsByDay: Map<Int, List<Card>>,
        val dayRows: List<DayRow>,
        /** 日图空态文案（[dayOfWeek] 非空且 [dayRows] 空时画）。 */
        val emptyDayText: String?,
        /** 分享正文（`EXTRA_TEXT`，ARB timetableShareText）。 */
        val shareText: String,
    )

    // --------------------------------------------------------------- 组装

    /**
     * 周图组装：整周排版 → 卡片模型。
     *
     * 排版直接复用 [WeekGridCourseMapping.cardsForWeek]（与屏上周网格同一份域逻辑：
     * 非本周过滤 / 冲突压淡 / 排序），渲染层与屏层「同一个坑位画同一门课」。
     *
     * @param overlineLabels 左上角小字文案（键对齐 [WeekCardOverline]；周图只出现
     *   「非本周」——「冲突」在 compact 卡上是角标不是小字，本版不画角标）。
     */
    fun buildWeekDocument(
        week: Int,
        cardsByDay: Map<Int, List<WeekCardModel>>,
        sections: List<SectionTime>,
        sectionTimeMode: WeekSectionTimeMode,
        style: WeekViewStyle,
        visibleDays: List<Int>,
        weekdayLabels: Map<Int, String>,
        weekdayDates: Map<Int, String?>,
        todayDayOfWeek: Int?,
        accentHex: String,
        title: String,
        weekCompactLabel: String,
        overlineLabels: Map<WeekCardOverline, String>,
        shareText: String,
    ): Document {
        val sectionHeight = exportSectionHeightDp(style.sectionHeightDp)
        val accent = parseHexArgb(accentHex, fallback = 0xFF2563EB.toInt())
        val cards = cardsByDay.mapValues { (_, models) ->
            models.map { model ->
                val colorHex = model.colorHex ?: model.course.color
                Card(
                    dayOfWeek = model.course.dayOfWeek,
                    startSection = model.course.startSection,
                    endSection = model.course.endSection,
                    topDp = cardTopDp(model.course.startSection, sectionHeight),
                    heightDp = cardHeightDp(model.course.startSection, model.course.endSection, sectionHeight),
                    colorArgb = parseHexArgb(colorHex, fallback = 0xFF2196F3.toInt()),
                    opacity = model.opacity,
                    title = model.course.shortName?.takeIf { it.isNotBlank() } ?: model.course.name,
                    subtitle = joinDetails(model.course.teacher, model.course.location),
                    overline = model.overline?.let { overlineLabels[it] },
                    isNonCurrentWeek = !model.isCurrentWeek,
                )
            }
        }
        return Document(
            title = title,
            subtitle = null,
            dayOfWeek = null,
            sections = sections,
            sectionTimeMode = sectionTimeMode,
            sectionHeightDp = sectionHeight,
            timeColumnWidthDp = style.timeColumnWidthDp,
            visibleDays = visibleDays,
            weekCompactLabel = weekCompactLabel,
            weekdayLabels = weekdayLabels,
            weekdayDates = weekdayDates,
            todayDayOfWeek = todayDayOfWeek,
            accentArgb = accent,
            cardsByDay = cards,
            dayRows = emptyList(),
            emptyDayText = null,
            shareText = shareText,
        )
    }

    /**
     * 日图组装：当天课程按时间排成列表（Dart `getCoursesForDay` 已排好）。
     *
     * 行色用课程**原色**（Dart `_buildCourseRow` 直接 `course.color`，不走统一卡色）。
     */
    fun buildDayDocument(
        week: Int,
        dayOfWeek: Int,
        dayCourses: List<Course>,
        title: String,
        subtitle: String?,
        emptyDayText: String,
        shareText: String,
    ): Document = Document(
        title = title,
        subtitle = subtitle,
        dayOfWeek = dayOfWeek,
        // 日图不画网格，这几项只作占位；高度公式走 dayRows 分支。
        sections = emptyList(),
        sectionTimeMode = WeekSectionTimeMode.HIDDEN,
        sectionHeightDp = MIN_SECTION_HEIGHT_DP,
        timeColumnWidthDp = 0f,
        visibleDays = listOf(dayOfWeek),
        weekCompactLabel = "",
        weekdayLabels = emptyMap(),
        weekdayDates = emptyMap(),
        todayDayOfWeek = null,
        accentArgb = 0xFF2563EB.toInt(),
        cardsByDay = emptyMap(),
        dayRows = dayCourses.map { course ->
            DayRow(
                timeRange = "${course.startTime}-${course.endTime}",
                sectionLabel = sectionRangeLabel(course.startSection, course.endSection),
                name = course.name,
                details = joinDetails(course.teacher, course.location),
                colorArgb = parseHexArgb(course.color, fallback = 0xFF2196F3.toInt()),
            )
        },
        emptyDayText = emptyDayText,
        shareText = shareText,
    )

    /** 「第 3-4 节」/「第 3 节」（Dart `_buildCourseRow` 的 sectionLabel 同式）。 */
    fun sectionRangeLabel(startSection: Int, endSection: Int): String =
        if (startSection == endSection) "$startSection" else "$startSection-$endSection"

    /** 「张老师 · A101」；两端去空白后逐段略空，全空回 null。 */
    fun joinDetails(teacher: String, location: String): String? {
        val parts = listOf(teacher.trim(), location.trim()).filter { it.isNotEmpty() }
        return if (parts.isEmpty()) null else parts.joinToString(" · ")
    }

    /** 表头日期「MM/dd」（Dart `'${date.month.padLeft(2)}/${date.day.padLeft(2)}'` 同式）。 */
    fun weekdayDateText(date: LocalDate): String =
        "%02d/%02d".format(Locale.ROOT, date.monthValue, date.dayOfMonth)

    /** 日图副标题「M月d日」（Dart `DateFormat.MMMd(zh)` 在中文 locale 的输出同形）。 */
    fun daySubtitleText(date: LocalDate): String = "${date.monthValue}月${date.dayOfMonth}日"
}
