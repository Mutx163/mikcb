package com.mutx163.qingyu.pages.statistics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.mutx163.qingyu.pages.statistics.charts.ExportBrandModel
import com.mutx163.qingyu.pages.statistics.charts.QrEncodeModel
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 统计分享图的光栅化（2026-10-30 F15 新增，composeP1 = 渲染侧）。
 *
 * ## 职责边界
 *
 * 只做一件事：把已经算好的 [StatisticsShareImageModel.Card]（标题 / 正文句 / 指标行）
 * **离屏画成一张 PNG**，末尾带一条与 Dart 同一个来源的品牌条。
 * 文件名、落盘目录、MIME、Intent 契约全在 main 的 [StatisticsShareImageModel] 里
 * （那部分能进 JVM 单测），这里只负责像素。
 *
 * 品牌条上的三个字符串与网址/二维码内容**不在这里写字**：
 * 从 [ExportBrandModel]（`timetableAppName` / `statisticsExportBrandTagline` /
 * `StatisticsExportBrand.WEBSITE_*`）取，二维码矩阵由 [QrEncodeModel] 算——
 * 与 Compose 文档 `charts/StatisticsExportCards.kt` 共用同一份真源，
 * 将来改品牌口号不会出现「屏上一种、分享图另一种」。
 *
 * ## 为什么用 framework 的 Canvas + StaticLayout，而不是 Compose 离屏渲染
 *
 * 这一条是**有意选择**，不是偷懒，写清楚免得下一个人以为漏了：
 *
 * 1. 分享回调要的那一帧**没有 Composition**。壳传下来的
 *    `onOpenShare = { shareStatisticsText(context, text, subject) }` 是个普通 lambda，
 *    调用点在 `ShellPageIndex.kt`（**不在本批写作用域**）。要拿 Compose 的
 *    `GraphicsLayer` / `DrawScope` 就得有 `Composition` 或一个挂到 window 上的
 *    `ComposeView`，两条路都要动壳或引入 View 生命周期依赖（离屏 `ComposeView`
 *    不挂 window 时 composition 不会正常跑）。
 * 2. 导出文档**本来就该与屏内主题解耦**。Dart 侧同一个判断写在
 *    `share_export_style.dart`：分享图恒用亮色底，注释原话是「刻意**不**引用
 *    主题令牌……那是发到微信等外部浅底场景后仍然看得清的产品口径」。也就是说
 *    这里用固定色/固定字号是**产品规则**，不是绕开页面样式守卫 R4/R5 的变通。
 * 3. 同仓先例：`WidgetPreviewRenderer`（桌面卡片 1:1 预览图）也是
 *    `inflate → measure/layout → Canvas.draw → PNG`，不拉起 Compose。
 *
 * ## 「离屏」的含义
 *
 * 全程不 attach 任何 View：自己 new 一张 `Bitmap`、自己量文字高度、自己往 Canvas 上画。
 * 不依赖当前屏幕尺寸，也不截屏。
 *
 * ## 已知差距（与 Dart 文档比，写清楚不假装）
 *
 * Dart 文档里还有品牌 logo 图、成就网格、数据故事、日分布 / 性质占比图、课程排行，
 * 以及「导出模块选择」弹层。前四项要模型层的图表数据
 * （`SemesterStats` / achievements / stories）——壳当前只把**一段正文**交给分享函数，
 * 那些数据不在 `StatisticsFeedState` 上；补它们需要改壳（Lead 专属）与
 * `main/statistics/`（不在本批写作用域）。第五项要弹层 + 选项状态，同样是壳的范围。
 * 认领文件 `claims/F15-statistics-share-image.md` 的「未做」一节记了这件事与补齐路径。
 */
internal object StatisticsShareImageRender {

    // 分享图配色：底色与 Dart `ShareExportStyle.background`（0xFFF2F2F2）逐位相同。
    // 这几个值是**产物的一部分**（改它等于改用户发出去的图），不是主题令牌。
    private val BACKGROUND_ARGB: Int = 0xFFF2F2F2.toInt()
    private val TITLE_ARGB: Int = 0xFF111111.toInt()
    private val BODY_ARGB: Int = 0xFF6B6B6B.toInt()
    private val ROW_ARGB: Int = 0xFF111111.toInt()
    private val BRAND_DETAIL_ARGB: Int = 0xFF6B6B6B.toInt()
    private val QR_INK_ARGB: Int = 0xFF111111.toInt()
    private val DIVIDER_ARGB: Int = 0x1F000000

    private const val PADDING_DP: Float = 16f
    private const val TITLE_TEXT_DP: Float = 17f
    private const val BODY_TEXT_DP: Float = 13f
    private const val ROW_TEXT_DP: Float = 14f

    private const val TITLE_GAP_DP: Float = 12f
    private const val BODY_GAP_DP: Float = 10f
    private const val ROW_GAP_DP: Float = 8f
    private const val LABEL_WIDTH_RATIO: Float = 0.62f
    private const val LINE_SPACING_MULTIPLIER: Float = 1.15f
    private const val DIVIDER_THICKNESS_DP: Float = 1f

    /** 品牌条字号，与 [ExportBrandModel.FALLBACK_TITLE_FONT_SIZE] / `FALLBACK_DETAIL_FONT_SIZE` 同源口径。 */
    private const val BRAND_TITLE_TEXT_DP: Float = 15f
    private const val BRAND_DETAIL_TEXT_DP: Float = 11f

    /** 末行到分隔线 12dp；分隔线到品牌内容 10dp（@see ExportBrandModel.DIVIDER_GAP_DP）。 */
    private const val FOOTER_TOP_GAP_DP: Float = 12f
    private const val FOOTER_DIVIDER_GAP_DP: Float = 10f

    /**
     * 把卡片画成 PNG 字节；任何一步失败回 `null`（调用方据此降级成纯文本分享，
     * **不假装导出成功**——与 F12「不生成空图冒充已导出」是同一条纪律）。
     *
     * 本身不碰磁盘、不碰 Intent。
     *
     * @param widthDp 导出宽度，调用方用 [StatisticsShareImageModel.exportWidthDp] 收口。
     */
    fun renderPng(
        context: Context,
        card: StatisticsShareImageModel.Card,
        widthDp: Float,
    ): ByteArray? = runCatching {
        val resources = context.resources
        val density = resources.displayMetrics.density
        val fontScale = resources.configuration.fontScale

        val widthPx = (widthDp * density).roundToInt().coerceAtLeast(1)
        val padPx = (PADDING_DP * density).roundToInt()
        val contentWidthPx = (widthPx - padPx * 2).coerceAtLeast(1)

        val titlePaint = textPaint(TITLE_TEXT_DP, density, fontScale, TITLE_ARGB, bold = true)
        val bodyPaint = textPaint(BODY_TEXT_DP, density, fontScale, BODY_ARGB, bold = false)
        val rowPaint = textPaint(ROW_TEXT_DP, density, fontScale, ROW_ARGB, bold = false)
        val valuePaint = textPaint(ROW_TEXT_DP, density, fontScale, ROW_ARGB, bold = true)

        val blocks = buildList {
            add(Block(listOf(Part(layout(card.title, titlePaint, contentWidthPx), 0)), gapPx = dp(TITLE_GAP_DP, density)))
            card.body?.let {
                add(Block(listOf(Part(layout(it, bodyPaint, contentWidthPx), 0)), gapPx = dp(BODY_GAP_DP, density)))
            }
            card.rows.forEach { row ->
                val value = row.value
                if (value == null) {
                    // 整行正文（含切不出标签取值的指标行）。
                    add(
                        Block(
                            parts = listOf(Part(layout(row.label, rowPaint, contentWidthPx), 0)),
                            gapPx = dp(ROW_GAP_DP, density),
                            divider = true,
                        ),
                    )
                } else {
                    val labelWidthPx = (contentWidthPx * LABEL_WIDTH_RATIO)
                        .roundToInt().coerceIn(1, contentWidthPx - 1)
                    add(
                        Block(
                            parts = listOf(
                                Part(layout(row.label, rowPaint, labelWidthPx), 0),
                                Part(
                                    layout(
                                        text = value,
                                        paint = valuePaint,
                                        widthPx = contentWidthPx - labelWidthPx,
                                        alignment = Layout.Alignment.ALIGN_OPPOSITE,
                                    ),
                                    x = labelWidthPx,
                                ),
                            ),
                            gapPx = dp(ROW_GAP_DP, density),
                            divider = true,
                        ),
                    )
                }
            }
        }

        val footer = footerOf(density, fontScale, contentWidthPx)

        // 高度 = 上下内边距 + 各块高度 + 块间间隙（最后一块的间隙并进品牌条上方的留白）+ 品牌条。
        val blocksHeight = blocks.sumOf { it.heightPx }
        val gapsHeight = (blocks.sumOf { it.gapPx } - (blocks.lastOrNull()?.gapPx ?: 0)).coerceAtLeast(0)
        val heightPx = (padPx * 2 + blocksHeight + gapsHeight + footer.totalHeightPx).coerceAtLeast(1)

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(BACKGROUND_ARGB)

            var y = padPx.toFloat()
            blocks.forEach { block ->
                block.parts.forEach { part ->
                    canvas.save()
                    canvas.translate((padPx + part.x).toFloat(), y)
                    part.layout.draw(canvas)
                    canvas.restore()
                }
                if (block.divider) {
                    val dividerY = y + block.heightPx + block.gapPx / 2f
                    canvas.drawLine(
                        padPx.toFloat(),
                        dividerY,
                        (widthPx - padPx).toFloat(),
                        dividerY,
                        dividerPaint(density),
                    )
                }
                y += (block.heightPx + block.gapPx).toFloat()
            }

            drawFooter(
                canvas = canvas,
                density = density,
                footer = footer,
                left = padPx.toFloat(),
                right = (widthPx - padPx).toFloat(),
                top = (padPx + blocksHeight + gapsHeight).toFloat(),
            )

            ByteArrayOutputStream().use { out ->
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)) return@runCatching null
                out.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }.getOrNull()

    // ------------------------------------------------------------------ 品牌条

    private class Footer(
        val titleLayout: StaticLayout,
        val taglineLayout: StaticLayout,
        val websiteLayout: StaticLayout,
        val qrSizePx: Int,
        val qrMatrix: com.mutx163.qingyu.pages.statistics.charts.QrMatrix,
        val textWidthPx: Int,
        val contentHeightPx: Int,
        val totalHeightPx: Int,
    )

    /**
     * 品牌条：分隔线 + 左侧三行文字（应用名 / 一句介绍 / 网址）+ 右侧二维码。
     *
     * 尺寸口径照抄 `StatisticsExportBrandBar`（Dart `brand_footer`）：
     * 二维码边长 = 文字块高度夹在 48~72dp；文字块 = 标题行 + 1dp + 说明行 + 2dp + 说明行。
     * 这里只少了 logo 图（要按 drawable 解码，留给「用真文档」那一版；不影响可读性与二维码）。
     */
    private fun footerOf(density: Float, fontScale: Float, contentWidthPx: Int): Footer {
        val title = ExportBrandModel.appName
        val tagline = ExportBrandModel.tagline
        val website = ExportBrandModel.websiteDisplay

        val titlePaint = textPaint(BRAND_TITLE_TEXT_DP, density, fontScale, TITLE_ARGB, bold = true)
        val detailPaint = textPaint(BRAND_DETAIL_TEXT_DP, density, fontScale, BRAND_DETAIL_ARGB, bold = false)

        // 二维码先按「文字块高」估算，再用它反过来定文字区宽度；两者互相依赖一轮就够
        // （Dart 用 clamp(48,72) 把这段依赖截断，这里同样截断）。
        val textBlockHeightDp = ExportBrandModel.textBlockHeight(
            titleFontSize = BRAND_TITLE_TEXT_DP,
            detailFontSize = BRAND_DETAIL_TEXT_DP,
        )
        val qrSizeDp = ExportBrandModel.qrSize(textBlockHeightDp)
        val qrSizePx = (qrSizeDp * density).roundToInt()
        val textWidthPx = (contentWidthPx - qrSizePx - ExportBrandModel.TEXT_TO_QR_GAP_DP * density)
            .roundToInt().coerceAtLeast(1)

        val titleLayout = layout(title, titlePaint, textWidthPx)
        val taglineLayout = layout(tagline, detailPaint, textWidthPx)
        val websiteLayout = layout(website, detailPaint, textWidthPx)

        val textHeightPx = titleLayout.height +
            dp(ExportBrandModel.TITLE_TO_TAGLINE_GAP_DP.toFloat(), density) +
            taglineLayout.height +
            dp(ExportBrandModel.TAGLINE_TO_URL_GAP_DP.toFloat(), density) +
            websiteLayout.height
        val contentHeightPx = max(textHeightPx, qrSizePx)

        return Footer(
            titleLayout = titleLayout,
            taglineLayout = taglineLayout,
            websiteLayout = websiteLayout,
            qrSizePx = qrSizePx,
            qrMatrix = QrEncodeModel.encode(ExportBrandModel.websiteUrl),
            textWidthPx = textWidthPx,
            contentHeightPx = contentHeightPx,
            totalHeightPx = dp(FOOTER_TOP_GAP_DP, density) +
                dp(DIVIDER_THICKNESS_DP, density) +
                dp(FOOTER_DIVIDER_GAP_DP, density) +
                contentHeightPx,
        )
    }

    private fun drawFooter(
        canvas: Canvas,
        density: Float,
        footer: Footer,
        left: Float,
        right: Float,
        top: Float,
    ) {
        val dividerY = top + dp(FOOTER_TOP_GAP_DP, density)
        canvas.drawLine(left, dividerY, right, dividerY, dividerPaint(density))

        val contentTop = dividerY + dp(DIVIDER_THICKNESS_DP, density) + dp(FOOTER_DIVIDER_GAP_DP, density)

        // 左侧三行文字
        val titleY = contentTop
        val taglineY = titleY + footer.titleLayout.height + dp(ExportBrandModel.TITLE_TO_TAGLINE_GAP_DP.toFloat(), density)
        val websiteY = taglineY + footer.taglineLayout.height + dp(ExportBrandModel.TAGLINE_TO_URL_GAP_DP.toFloat(), density)
        listOf(footer.titleLayout to titleY, footer.taglineLayout to taglineY, footer.websiteLayout to websiteY)
            .forEach { (textLayout, textY) ->
                canvas.save()
                canvas.translate(left, textY)
                textLayout.draw(canvas)
                canvas.restore()
            }

        // 右侧二维码：一格格填方块（与 `QrCodeCanvas` 同一算法，只是画在 framework canvas 上）。
        // +0.5px 余量盖住相邻黑块间的发丝缝。
        val matrix = footer.qrMatrix
        val cell = footer.qrSizePx.toFloat() / matrix.size
        val qrLeft = right - footer.qrSizePx
        val qrPaint = Paint().apply { color = QR_INK_ARGB }
        for (row in 0 until matrix.size) {
            for (column in 0 until matrix.size) {
                if (!matrix.isDark(column, row)) continue
                val x = qrLeft + column * cell
                val y = contentTop + row * cell
                canvas.drawRect(x, y, x + cell + 0.5f, y + cell + 0.5f, qrPaint)
            }
        }
    }

    // ------------------------------------------------------------------ 内部

    private class Part(val layout: StaticLayout, val x: Int)

    private class Block(val parts: List<Part>, val gapPx: Int, val divider: Boolean = false) {
        val heightPx: Int = parts.maxOfOrNull { it.layout.height } ?: 0
    }

    private fun dividerPaint(density: Float): Paint = Paint().apply {
        color = DIVIDER_ARGB
        strokeWidth = DIVIDER_THICKNESS_DP * density
    }

    private fun dp(value: Float, density: Float): Int = (value * density).roundToInt()

    /**
     * 字号换算。
     *
     * 乘 `fontScale` 是**故意的**（无障碍大字体用户发出去的图不该比屏上小一号），
     * 但**不**读主题的 textStyles：见类头注释第 2 条，导出文档与屏内主题解耦。
     */
    private fun textPaint(
        sizeDp: Float,
        density: Float,
        fontScale: Float,
        argb: Int,
        bold: Boolean,
    ): TextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = sizeDp * density * fontScale
        color = argb
        typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
    }

    private fun layout(
        text: String,
        paint: TextPaint,
        widthPx: Int,
        alignment: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
    ): StaticLayout = StaticLayout.Builder
        .obtain(text, 0, text.length, paint, widthPx)
        .setAlignment(alignment)
        .setIncludePad(false)
        .setLineSpacing(0f, LINE_SPACING_MULTIPLIER)
        .build()
}
