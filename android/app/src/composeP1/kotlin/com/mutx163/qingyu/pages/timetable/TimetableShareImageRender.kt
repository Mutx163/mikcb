package com.mutx163.qingyu.pages.timetable

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import com.mutx163.qingyu.pages.statistics.charts.ExportBrandModel
import com.mutx163.qingyu.pages.statistics.charts.QrEncodeModel
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 「干净课表图」的光栅化（2026-11-03 新增，composeP1 = 渲染侧）。
 *
 * ## 职责边界
 *
 * 只做一件事：把已经算好的 [TimetableShareImageModel.Document]（标题 / 周网格或日列表 /
 * 品牌条素材）**离屏画成一张 PNG**。几何（列宽 / 行高 / 总高）、文件名、落盘路径、
 * MIME 全在 main 的 [TimetableShareImageModel] 里（那部分能进 JVM 单测），这里只负责像素。
 *
 * ## 为什么用 framework Canvas 而不是 Compose 离屏渲染
 *
 * 与统计域 `StatisticsShareImageRender` 同一条裁定：分享回调里没有 Composition，
 * 离屏 `ComposeView` 不挂 window 不跑 composition；且导出图**本来就该与屏内主题解耦**
 * （恒浅色、固定字号是产品规则不是偷懒）。同仓先例还有 `WidgetPreviewRenderer`。
 *
 * ## 字号为什么不乘 fontScale（与统计域的一处刻意差异）
 *
 * 统计域的卡片高度用 StaticLayout 实测量，乘 fontScale 不影响布局；
 * 课表图是**网格布局**，总高度预算在模型层是纯函数（`documentHeightDp`），
 * 两侧必须同一口径——模型侧不乘，渲染侧也不能乘，否则大字体用户的图会溢出画布。
 * Dart 侧没这个问题是因为 Flutter 走 widget 实测高度。代价是无障碍大字体用户
 * 发出去的图字号是标准档，记入已知差距。
 *
 * ## 与 Dart 导出文档的其余差距
 *
 * 周网格课卡是「干净版」（课名 + 教师/地点 + 非本周灰化，不含角标排布 / 天气 / 铃铛）；
 * 品牌条没有 logo 图。清单在 [TimetableShareImageModel] 类头，本文件不重复。
 */
internal object TimetableShareImageRender {

    // 分享图配色：恒浅色（产物的一部分，不是主题令牌）。底色与 Dart
    // `ShareExportStyle.background`（0xFFF2F2F2）逐位相同。
    private val BACKGROUND_ARGB: Int = 0xFFF2F2F2.toInt()
    private val SURFACE_ARGB: Int = 0xFFFFFFFF.toInt()
    private val INK_ARGB: Int = 0xFF111111.toInt()
    private val SECONDARY_INK_ARGB: Int = 0xFF6B6B6B.toInt()
    private val TIME_AXIS_INK_ARGB: Int = 0xFF757575.toInt()
    private val TIME_AXIS_MUTED_ARGB: Int = 0xFF999999.toInt()
    private val DIVIDER_ARGB: Int = 0x1F000000
    private val CARD_TEXT_ARGB: Int = 0xFFFFFFFF.toInt()
    private val ACCENT_ARGB: Int = 0xFF2563EB.toInt()

    /** 非本周课卡的固定灰（`WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX` 同值）。 */
    private val NON_CURRENT_WEEK_ARGB: Int = 0xFF94A3B8.toInt()

    // 周网格字号（Dart 表头 10 / 日期 8.5 / 时间轴节号 compactFontSize、时间 −2 档、
    // 课卡标题 courseCardFontSize 默认 9）。
    private const val WEEKDAY_TEXT_DP: Float = 10f
    private const val WEEKDAY_DATE_TEXT_DP: Float = 8.5f
    private const val SECTION_NUMBER_TEXT_DP: Float = 9f
    private const val SECTION_TIME_TEXT_DP: Float = 7f
    private const val CARD_TITLE_TEXT_DP: Float = 9f
    private const val CARD_SUBTITLE_TEXT_DP: Float = 8f
    private const val CARD_OVERLINE_TEXT_DP: Float = 7f
    private const val CARD_RADIUS_DP: Float = 8f
    private const val CARD_PADDING_DP: Float = 5f
    private const val CARD_LINE_GAP_DP: Float = 2f
    private const val CARD_INSET_DP: Float = 1.5f
    private const val SECTION_STACK_GAP_DP: Float = 1f
    /** 行距口径（模型层高度公式同值，改一处必须同步另一处）。 */
    private const val LINE_HEIGHT_MULTIPLIER: Float = 1.3f

    /**
     * 把文档画成 PNG 字节；任何一步失败回 `null`（调用方降级成纯文本分享，
     * **不假装导出成功**——与统计域同一纪律）。
     *
     * 本身不碰磁盘、不碰 Intent。
     */
    fun renderPng(
        context: Context,
        doc: TimetableShareImageModel.Document,
        widthDp: Float,
    ): ByteArray? = runCatching {
        val density = context.resources.displayMetrics.density

        val widthPx = (widthDp * density * TimetableShareImageModel.PIXEL_RATIO)
            .roundToInt().coerceAtLeast(1)
        val heightDp = TimetableShareImageModel.documentHeightDp(doc)
        val scale = TimetableShareImageModel.pixelScaleClamp(heightDp, density)
        val heightPx = (heightDp * density * TimetableShareImageModel.PIXEL_RATIO * scale)
            .roundToInt().coerceAtLeast(1)

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(BACKGROUND_ARGB)
            // 逻辑坐标系 = dp；一次 scale 把 dp 折成最终像素（含像素比与超高保护）。
            val drawScale = density * TimetableShareImageModel.PIXEL_RATIO * scale
            canvas.scale(drawScale, drawScale)

            val paints = Paints()
            val left = TimetableShareImageModel.OUTER_PADDING_START_DP
            val right = widthDp - TimetableShareImageModel.OUTER_PADDING_END_DP
            var y = TimetableShareImageModel.OUTER_PADDING_TOP_DP

            // ── 标题（+ 日图副标题）──
            val titleLine = paints.lineHeightDp(paints.title)
            canvas.drawText(doc.title, paints.title, left, y + paints.title.textSize)
            y += titleLine
            if (doc.subtitle != null) {
                y += TimetableShareImageModel.TITLE_TO_SUBTITLE_GAP_DP
                val subtitleLine = paints.lineHeightDp(paints.subtitle)
                canvas.drawText(doc.subtitle, paints.subtitle, left, y + paints.subtitle.textSize)
                y += subtitleLine
            }
            y += TimetableShareImageModel.TITLE_BLOCK_TO_SURFACE_GAP_DP

            // ── 白卡 ──
            val surfaceHeight = if (doc.dayOfWeek == null) {
                TimetableShareImageModel.weekGridHeightDp(doc.sections.size, doc.sectionHeightDp)
            } else if (doc.dayRows.isEmpty()) {
                TimetableShareImageModel.DAY_EMPTY_PADDING_VERTICAL_DP * 2 + paints.lineHeightDp(paints.subtitle)
            } else {
                TimetableShareImageModel.dayListHeightDp(doc.dayRows)
            }
            drawSurface(canvas, paints, doc, left, y, right - left, surfaceHeight)
            y += TimetableShareImageModel.SURFACE_PADDING_DP * 2 + surfaceHeight

            // ── 品牌条 ──
            drawFooter(canvas, paints, left, right, y + TimetableShareImageModel.SURFACE_TO_FOOTER_GAP_DP)

            ByteArrayOutputStream().use { out ->
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)) return@runCatching null
                out.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }.getOrNull()

    // ------------------------------------------------------------------ 白卡

    private fun drawSurface(
        canvas: Canvas,
        paints: Paints,
        doc: TimetableShareImageModel.Document,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
    ) {
        val radius = TimetableShareImageModel.SURFACE_RADIUS_DP
        val path = Path().apply {
            addRoundRect(RectF(left, top, left + width, top + height), radius, radius, Path.Direction.CW)
        }
        canvas.save()
        canvas.clipPath(path)
        canvas.drawRect(left, top, left + width, top + height, paints.fill(SURFACE_ARGB))

        val contentLeft = left + TimetableShareImageModel.SURFACE_PADDING_DP
        val contentTop = top + TimetableShareImageModel.SURFACE_PADDING_DP
        val contentWidth = width - TimetableShareImageModel.SURFACE_PADDING_DP * 2
        if (doc.dayOfWeek == null) {
            drawWeekGrid(canvas, paints, doc, contentLeft, contentTop, contentWidth)
        } else {
            drawDayList(canvas, paints, doc, contentLeft, contentTop, contentWidth)
        }
        canvas.restore()
    }

    // ------------------------------------------------------------------ 周网格

    private fun drawWeekGrid(
        canvas: Canvas,
        paints: Paints,
        doc: TimetableShareImageModel.Document,
        left: Float,
        top: Float,
        width: Float,
    ) {
        val headerHeight = TimetableShareImageModel.WEEKDAY_HEADER_HEIGHT_DP
        val dayWidth = TimetableShareImageModel.dayColumnWidthDp(
            availableWidthDp = width,
            timeColumnWidthDp = doc.timeColumnWidthDp,
            visibleDayCount = doc.visibleDays.size,
        )

        // ── 表头：时间列位置放「{week} 周」，每天一列「周一」+ 日期（今天高亮）。──
        val headerBottom = top + headerHeight
        canvas.drawText(
            doc.weekCompactLabel, paints.weekLabel,
            left, top + headerHeight / 2f,
            doc.timeColumnWidthDp, Align.CENTER_VERT,
        )
        doc.visibleDays.forEachIndexed { index, dayOfWeek ->
            val columnLeft = left + doc.timeColumnWidthDp + dayWidth * index
            val highlight = doc.todayDayOfWeek == dayOfWeek
            val labelPaint = if (highlight) paints.weekdayToday else paints.weekday
            val datePaint = if (highlight) paints.weekdayDateToday else paints.weekdayDate
            val label = doc.weekdayLabels[dayOfWeek].orEmpty()
            val date = doc.weekdayDates[dayOfWeek]
            val labelLine = paints.lineHeightDp(labelPaint)
            val dateLine = if (date != null) paints.lineHeightDp(datePaint) + 2f else 0f
            var textY = top + (headerHeight - labelLine - dateLine) / 2f
            canvas.drawText(label, labelPaint, columnLeft, textY + labelLine / 2f, dayWidth, Align.CENTER_VERT)
            if (date != null) {
                textY += labelLine + 2f
                canvas.drawText(date, datePaint, columnLeft, textY + paints.lineHeightDp(datePaint) / 2f, dayWidth, Align.CENTER_VERT)
            }
        }
        // 表头底线（Dart 0.5px 分隔线的视觉口径）。
        canvas.drawLine(left, headerBottom, left + width, headerBottom, paints.hairline)

        // ── 时间轴：每节「节号 + 开始时间(+结束时间)」纵向居中。──
        val bodyTop = headerBottom
        val sectionHeight = doc.sectionHeightDp
        val showStart = doc.sectionTimeMode != WeekSectionTimeMode.HIDDEN
        val showEnd = doc.sectionTimeMode == WeekSectionTimeMode.START_AND_END
        val timeLine = paints.lineHeightDp(paints.sectionTime)
        val stackHeight = paints.lineHeightDp(paints.sectionNumber) +
            (if (showStart) SECTION_STACK_GAP_DP + timeLine * (if (showEnd) 2f else 1f) else 0f)
        for (index in doc.sections.indices) {
            val center = bodyTop + index * sectionHeight + sectionHeight / 2f
            var cursor = center - stackHeight / 2f
            canvas.drawText(
                "${index + 1}", paints.sectionNumber,
                left, cursor + paints.lineHeightDp(paints.sectionNumber) / 2f,
                doc.timeColumnWidthDp, Align.CENTER_VERT,
            )
            cursor += paints.lineHeightDp(paints.sectionNumber)
            if (showStart) {
                val section = doc.sections[index]
                cursor += SECTION_STACK_GAP_DP
                canvas.drawText(section.startTime, paints.sectionTime, left, cursor + timeLine / 2f, doc.timeColumnWidthDp, Align.CENTER_VERT)
                cursor += timeLine
                if (showEnd) {
                    canvas.drawText(section.endTime, paints.sectionTime, left, cursor + timeLine / 2f, doc.timeColumnWidthDp, Align.CENTER_VERT)
                }
            }
        }

        // ── 日列课卡。──
        doc.cardsByDay.forEach { (dayOfWeek, cards) ->
            val index = doc.visibleDays.indexOf(dayOfWeek)
            if (index < 0) return@forEach
            val columnLeft = left + doc.timeColumnWidthDp + dayWidth * index
            cards.forEach { card ->
                drawCard(canvas, paints, card, columnLeft, bodyTop + card.topDp, dayWidth)
            }
        }
    }

    private fun drawCard(
        canvas: Canvas,
        paints: Paints,
        card: TimetableShareImageModel.Card,
        columnLeft: Float,
        top: Float,
        dayWidth: Float,
    ) {
        val left = columnLeft + CARD_INSET_DP
        val right = columnLeft + dayWidth - CARD_INSET_DP
        // 非本周：固定灰；冲突/其它：课程色按透明度混白（分享图是最终产物，
        // 卡底永远白卡——alpha 预混，PNG 不带透明度，深色聊天背景下不变色）。
        val fillArgb = when {
            card.isNonCurrentWeek -> NON_CURRENT_WEEK_ARGB
            card.opacity < 0.99f -> blendOverWhite(card.colorArgb, card.opacity)
            else -> card.colorArgb
        }
        canvas.drawRoundRect(
            RectF(left, top, right, top + card.heightDp),
            CARD_RADIUS_DP, CARD_RADIUS_DP, paints.fill(fillArgb),
        )

        val textLeft = left + CARD_PADDING_DP
        val textWidthDp = (right - left - CARD_PADDING_DP * 2).coerceAtLeast(1f)
        val cardBottom = top + card.heightDp
        var y = top + CARD_PADDING_DP
        if (card.overline != null) {
            canvas.drawText(card.overline, paints.cardOverline, textLeft, y + paints.cardOverline.textSize)
            y += paints.lineHeightDp(paints.cardOverline) + CARD_LINE_GAP_DP
        }
        val titleLayout = paints.layout(card.title, paints.cardTitle, textWidthDp, maxLines = 1)
        canvas.save()
        canvas.translate(textLeft, y)
        titleLayout.draw(canvas)
        canvas.restore()
        // StaticLayout 的坐标系与本画布一致（textSize 即 dp），高度直接累加。
        y += titleLayout.height
        val subtitleLine = paints.lineHeightDp(paints.cardSubtitle)
        if (card.subtitle != null && cardBottom - y > subtitleLine + CARD_LINE_GAP_DP) {
            y += CARD_LINE_GAP_DP
            val subtitleLayout = paints.layout(card.subtitle, paints.cardSubtitle, textWidthDp, maxLines = 2)
            canvas.save()
            canvas.translate(textLeft, y)
            subtitleLayout.draw(canvas)
            canvas.restore()
        }
    }

    /** 半透明课卡压白底的实色预混。 */
    private fun blendOverWhite(argb: Int, opacity: Float): Int {
        val clamped = opacity.coerceIn(0f, 1f)
        val mix = { channel: Int ->
            (channel * clamped + 255 * (1 - clamped)).roundToInt().coerceIn(0, 255)
        }
        val r = mix(argb ushr 16 and 0xFF)
        val g = mix(argb ushr 8 and 0xFF)
        val b = mix(argb and 0xFF)
        return 0xFF000000.toInt() or (r shl 16) or (g shl 8) or b
    }

    // ------------------------------------------------------------------ 日列表

    private fun drawDayList(
        canvas: Canvas,
        paints: Paints,
        doc: TimetableShareImageModel.Document,
        left: Float,
        top: Float,
        width: Float,
    ) {
        if (doc.dayRows.isEmpty()) {
            val blockHeight = TimetableShareImageModel.DAY_EMPTY_PADDING_VERTICAL_DP * 2 +
                paints.lineHeightDp(paints.subtitle)
            canvas.drawText(
                doc.emptyDayText.orEmpty(), paints.subtitle,
                left, top + blockHeight / 2f,
                width, Align.CENTER_VERT,
            )
            return
        }
        var y = top
        doc.dayRows.forEachIndexed { index, row ->
            if (index > 0) {
                canvas.drawLine(left, y, left + width, y, paints.hairline)
            }
            val contentHeight = TimetableShareImageModel.dayRowContentHeightDp(row.details != null)
            val rowTop = y + TimetableShareImageModel.DAY_ROW_PADDING_VERTICAL_DP
            val rowLeft = left + TimetableShareImageModel.DAY_ROW_PADDING_HORIZONTAL_DP
            val rowRight = left + width - TimetableShareImageModel.DAY_ROW_PADDING_HORIZONTAL_DP

            // 色条（4×40，圆角 2）。
            canvas.drawRoundRect(
                RectF(
                    rowLeft,
                    rowTop,
                    rowLeft + TimetableShareImageModel.DAY_ROW_BAR_WIDTH_DP,
                    rowTop + TimetableShareImageModel.DAY_ROW_BAR_HEIGHT_DP,
                ),
                2f, 2f, paints.fill(row.colorArgb),
            )

            // 文字块（色条右侧 10）。
            val textLeft = rowLeft + TimetableShareImageModel.DAY_ROW_BAR_WIDTH_DP +
                TimetableShareImageModel.DAY_ROW_BAR_TO_TEXT_GAP_DP
            val textWidth = (rowRight - textLeft).coerceAtLeast(1f)
            var textY = rowTop
            canvas.drawText(row.timeRange, paints.dayTime, textLeft, textY + paints.dayTime.textSize)
            val timeWidth = paints.measureWidth(row.timeRange, paints.dayTime)
            canvas.drawText(
                row.sectionLabel, paints.daySection,
                textLeft + timeWidth + 6f, textY + paints.daySection.textSize,
                (textWidth - timeWidth - 6f).coerceAtLeast(1f), Align.LEFT,
            )
            textY += paints.lineHeightDp(paints.dayTime) + TimetableShareImageModel.DAY_ROW_TEXT_GAP_DP
            canvas.drawText(row.name, paints.dayName, textLeft, textY + paints.dayName.textSize)
            textY += paints.lineHeightDp(paints.dayName)
            if (row.details != null) {
                textY += TimetableShareImageModel.DAY_ROW_TEXT_GAP_DP
                canvas.drawText(row.details, paints.dayDetail, textLeft, textY + paints.dayDetail.textSize)
            }
            y = rowTop + contentHeight + TimetableShareImageModel.DAY_ROW_PADDING_VERTICAL_DP
        }
    }

    // ------------------------------------------------------------------ 品牌条

    /**
     * 品牌条：分隔线 + 左侧三行文字（应用名 / 一句介绍 / 网址）+ 右侧二维码。
     * 数据源与统计域同一个 [ExportBrandModel]，改品牌口号不会出现「屏上一种、分享图另一种」。
     */
    private fun drawFooter(
        canvas: Canvas,
        paints: Paints,
        left: Float,
        right: Float,
        top: Float,
    ) {
        val dividerY = top + TimetableShareImageModel.FOOTER_TOP_GAP_DP
        canvas.drawLine(left, dividerY, right, dividerY, paints.hairline)

        val contentTop = dividerY + TimetableShareImageModel.FOOTER_DIVIDER_THICKNESS_DP +
            TimetableShareImageModel.FOOTER_DIVIDER_GAP_DP
        val textBlockHeight = ExportBrandModel.textBlockHeight(
            titleFontSize = TimetableShareImageModel.FOOTER_TITLE_TEXT_DP,
            detailFontSize = TimetableShareImageModel.FOOTER_DETAIL_TEXT_DP,
        )
        val qrSizeDp = ExportBrandModel.qrSize(textBlockHeight)
        val textWidthDp = (right - left - qrSizeDp - ExportBrandModel.TEXT_TO_QR_GAP_DP).coerceAtLeast(1f)

        val titleLine = paints.lineHeightDp(paints.footerTitle)
        val detailLine = paints.lineHeightDp(paints.footerDetail)
        val textHeight = titleLine + ExportBrandModel.TITLE_TO_TAGLINE_GAP_DP +
            detailLine + ExportBrandModel.TAGLINE_TO_URL_GAP_DP + detailLine

        var y = contentTop + max(0f, (textBlockHeight - textHeight) / 2f)
        canvas.drawText(ExportBrandModel.appName, paints.footerTitle, left, y + paints.footerTitle.textSize, textWidthDp)
        y += titleLine + ExportBrandModel.TITLE_TO_TAGLINE_GAP_DP
        canvas.drawText(ExportBrandModel.tagline, paints.footerDetail, left, y + paints.footerDetail.textSize, textWidthDp)
        y += detailLine + ExportBrandModel.TAGLINE_TO_URL_GAP_DP
        canvas.drawText(ExportBrandModel.websiteDisplay, paints.footerDetail, left, y + paints.footerDetail.textSize, textWidthDp)

        // 右侧二维码：一格格填方块，+0.05dp 盖发丝缝（统计域同款画法）。
        val matrix = QrEncodeModel.encode(ExportBrandModel.websiteUrl)
        val cell = qrSizeDp / matrix.size
        val qrLeft = right - qrSizeDp
        val qrPaint = paints.fill(INK_ARGB)
        for (row in 0 until matrix.size) {
            for (column in 0 until matrix.size) {
                if (!matrix.isDark(column, row)) continue
                val x = qrLeft + column * cell
                val yy = contentTop + row * cell
                canvas.drawRect(x, yy, x + cell + 0.05f, yy + cell + 0.05f, qrPaint)
            }
        }
    }

    // ------------------------------------------------------------------ 画笔

    /**
     * 画笔集合。坐标与字号**全走 dp 口径**（画布已 scale）；导出图与屏内主题解耦，
     * 不读主题 textStyles（统计域同一条裁定）。字号不乘 fontScale——见类头注释。
     */
    private class Paints {
        val title = text(TimetableShareImageModel.TITLE_TEXT_DP, INK_ARGB, bold = true)
        val subtitle = text(TimetableShareImageModel.SUBTITLE_TEXT_DP, SECONDARY_INK_ARGB, bold = false)
        val weekLabel = text(WEEKDAY_TEXT_DP, INK_ARGB, bold = true)
        val weekday = text(WEEKDAY_TEXT_DP, INK_ARGB, bold = false)
        val weekdayToday = text(WEEKDAY_TEXT_DP, ACCENT_ARGB, bold = true)
        val weekdayDate = text(WEEKDAY_DATE_TEXT_DP, SECONDARY_INK_ARGB, bold = false)
        val weekdayDateToday = text(WEEKDAY_DATE_TEXT_DP, ACCENT_ARGB, bold = false)
        val sectionNumber = text(SECTION_NUMBER_TEXT_DP, TIME_AXIS_INK_ARGB, bold = true)
        val sectionTime = text(SECTION_TIME_TEXT_DP, TIME_AXIS_MUTED_ARGB, bold = false)
        val cardTitle = text(CARD_TITLE_TEXT_DP, CARD_TEXT_ARGB, bold = true)
        val cardSubtitle = text(CARD_SUBTITLE_TEXT_DP, CARD_TEXT_ARGB, bold = false)
        val cardOverline = text(CARD_OVERLINE_TEXT_DP, CARD_TEXT_ARGB, bold = false)
        val dayTime = text(TimetableShareImageModel.DAY_ROW_TEXT_DP, ACCENT_ARGB, bold = true)
        val daySection = text(TimetableShareImageModel.DAY_ROW_TEXT_DP, SECONDARY_INK_ARGB, bold = false)
        val dayName = text(TimetableShareImageModel.DAY_ROW_NAME_TEXT_DP, INK_ARGB, bold = true)
        val dayDetail = text(TimetableShareImageModel.DAY_ROW_DETAIL_TEXT_DP, SECONDARY_INK_ARGB, bold = false)
        val footerTitle = text(TimetableShareImageModel.FOOTER_TITLE_TEXT_DP, INK_ARGB, bold = true)
        val footerDetail = text(TimetableShareImageModel.FOOTER_DETAIL_TEXT_DP, SECONDARY_INK_ARGB, bold = false)
        val hairline: Paint = Paint().apply {
            color = DIVIDER_ARGB
            strokeWidth = 0.75f
            isAntiAlias = true
        }

        private fun text(sizeDp: Float, argb: Int, bold: Boolean): TextPaint =
            TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = sizeDp
                color = argb
                typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            }

        fun fill(argb: Int): Paint = Paint().apply {
            color = argb
            isAntiAlias = true
        }

        /** 单行高（dp）；模型层高度公式同乘 [LINE_HEIGHT_MULTIPLIER]，两侧同一口径。 */
        fun lineHeightDp(paint: TextPaint): Float = paint.textSize * LINE_HEIGHT_MULTIPLIER

        fun measureWidth(text: String, paint: TextPaint): Float = paint.measureText(text)

        /** 多行 / 截断布局（StaticLayout 宽度按 dp 传——画布坐标系就是 dp）。 */
        fun layout(text: String, paint: TextPaint, widthDp: Float, maxLines: Int): StaticLayout =
            StaticLayout.Builder
                .obtain(text, 0, text.length, paint, widthDp.roundToInt().coerceAtLeast(1))
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setIncludePad(false)
                .setMaxLines(maxLines)
                .setEllipsize(TextUtils.TruncateAt.END)
                .build()
    }

    /** 对齐模式。 */
    private enum class Align { LEFT, CENTER_VERT }

    /**
     * drawText 的窄封装：垂直居中（[Align.CENTER_VERT]）时按 baseline = centerY + 字高的
     * 视觉修正排；水平居中按实际文本宽平移。
     */
    private fun Canvas.drawText(
        text: String,
        paint: TextPaint,
        x: Float,
        baselineY: Float,
        width: Float = Float.MAX_VALUE,
        align: Align = Align.LEFT,
    ) {
        if (text.isEmpty()) return
        when (align) {
            Align.LEFT -> drawText(text, x, baselineY, paint)
            Align.CENTER_VERT -> {
                val textWidth = paint.measureText(text)
                val startX = if (width == Float.MAX_VALUE) x else x + (width - textWidth) / 2f
                // baseline 修正：居中 ≈ centerY + 0.35 × 字号（字面高约 0.7 倍字号）。
                drawText(text, startX, baselineY + paint.textSize * 0.35f, paint)
            }
        }
    }
}
