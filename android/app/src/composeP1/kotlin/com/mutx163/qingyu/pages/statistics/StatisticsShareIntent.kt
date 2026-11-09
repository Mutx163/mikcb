package com.mutx163.qingyu.pages.statistics

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
import android.widget.Toast
import androidx.core.content.FileProvider
import com.mutx163.qingyu.pages.statistics.charts.BarChartSpec
import com.mutx163.qingyu.pages.statistics.charts.ChartsStrings
import com.mutx163.qingyu.pages.statistics.charts.ExportBrandModel
import com.mutx163.qingyu.pages.statistics.charts.ExportDocumentModel
import com.mutx163.qingyu.pages.statistics.charts.ExportRankingModel
import com.mutx163.qingyu.pages.statistics.charts.ExportSectionKind
import com.mutx163.qingyu.pages.statistics.charts.QrEncodeModel
import com.mutx163.qingyu.pages.statistics.charts.StatisticsExportContent
import com.mutx163.qingyu.statistics.StatisticsExportOptions
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 统计页「分享」的 Android 落地（F12 建立 2026-10-30，F15 同日补上图片导出）。
 *
 * ## 为什么单独一个文件
 *
 * `StatisticsShareText` / `StatisticsShareImageModel` / `StatisticsShareImageDecision`（main 层）
 * 只算内容、契约与判断，零 Android 依赖，能进 JVM 单测；真正发 `ACTION_SEND` 需要 `Context`，
 * 按本仓约定这类胶水放 composeP1 的渲染侧，不污染模型层
 * （main 对全变体编译，import android.* 会让模型层进不了 L0）。
 *
 * ## 这一版的分工（对抗审核 P2 之后）
 *
 * 本文件**只搬砖**，不再自己判断「该不该发图」：
 *
 * | 环节 | 在哪 |
 * |---|---|
 * | 文件名 / 落盘路径 / MIME / 卡片排版 | [StatisticsShareImageModel]（纯逻辑，有单测） |
 * | 「该发图还是退回纯文本」 | [StatisticsShareImageDecision]（纯逻辑，有单测） |
 * | 离屏画成 PNG 字节 | [StatisticsShareImageRender] |
 * | 写盘 / `FileProvider` / `ACTION_SEND` | 本文件 |
 *
 * 这样排是因为原来五个 `return false` 全在这里、吃 `Context`、L0 跑不到，
 * 于是「发不出图就退回纯文本、绝不假装成功」这条承诺**一条用例都没有**。
 *
 * ## 与 Dart 的差异（F15 之后只剩「文档内容还不够全」这一条）
 *
 * Dart `StatisticsShareService.exportAndShare` 分享的是**PNG 图片 + 正文**；
 * 这里也是图 + 正文（`EXTRA_STREAM` + `EXTRA_TEXT` + `EXTRA_SUBJECT`，与
 * `ShareParams(files:, subject:, text:)` 同形）。差的只是文档内容本身：
 * Dart 那张图里有品牌 logo、成就、数据故事、图表、课程排行，这里只有标题 + 正文句
 * + 指标行 + 品牌条（应用名 / 一句话 / 网址 / 二维码）。补齐路径见认领文件
 * `claims/F15-statistics-share-image.md` 的「未做」——它要壳把 `SemesterStats` 交出来。
 *
 * ## 失败一律降级成纯文本，绝不假装
 *
 * 光栅化、落盘、`FileProvider` 三步任何一步失败都不抛给用户，而是退回 F12 那套纯文本分享
 * （内容仍然是真数据，只是没有 PNG 附件）。**绝不在界面上写「已导出图片」**，
 * 也绝不生成空图冒充成功（空正文在 [StatisticsShareImageModel.payload] 就被拦成 null）。
 *
 * 与 `DiagnosticsLogHost.shareLogText` 同一套「能发附件就发附件、发不了就发正文」的口径。
 */
private const val LOG_TAG = "[statistics-share]"

/**
 * 分享统计成果：**优先发 PNG 成果图**，发不出图就退回纯文本（内容同源、仍是真数据）。
 *
 * 入口名保持 `shareStatisticsText` 不改：调用点是壳 `ShellPageIndex.kt` 的 `e.statistics`
 * 分支（**不在本批写作用域**），改名会让那一行编译不过。语义已经不是「只发文本」了，
 * 所以口径写在这里，并已报 Lead 同步壳里的旧注释。
 */
fun shareStatisticsText(context: Context, text: String, subject: String) {
    if (shareStatisticsImage(context, text, subject)) return
    shareStatisticsTextOnly(context, text, subject)
}

/**
 * 尝试分享成果图。
 *
 * 判断「发图还是降级」全交给 [StatisticsShareImageDecision]；这里只把四步的真实结果
 * （载荷 / PNG / 写盘 / Uri）交给它，再照它的判决做事。
 *
 * @return 是否**真的**拉起过带 PNG 附件的分享面板；false = 调用方应降级成纯文本分享。
 */
internal fun shareStatisticsImage(context: Context, text: String, subject: String): Boolean {
    val payload = StatisticsShareImageModel.payload(
        text = text,
        subject = subject,
        epochMillis = System.currentTimeMillis(),
    )
    val png = payload?.let {
        StatisticsShareImageRender.renderPng(context, it.card, exportWidthDp(context))
    }
    val file = if (payload != null && png != null) {
        writeSharePng(context, payload.cacheRelativePath, png)
    } else {
        null
    }
    val uri = file?.let { resolveShareUri(context, it) }

    return when (
        val decision = StatisticsShareImageDecision.decide(
            payload = payload,
            png = png,
            writeSucceeded = file != null,
            uri = uri,
        )
    ) {
        is StatisticsShareImageDecision.Decision.FallbackToText -> {
            Log.w(LOG_TAG, "这次不发图，降级成纯文本分享：${decision.reason}")
            // 2026-11-05 审核修复：降级不再无声。用户点的是「分享图」，收到的却是
            // 文字面板——发布版三种失败都弹「分享失败：{detail}」
            // （statistics_share_service.dart:78-117 的 showAppToast），这里补齐同一条。
            // EMPTY_CONTENT 不提示：那不是失败，是没有内容（payload 为 null 的诚实出口）。
            if (decision.reason != StatisticsShareImageDecision.FallbackReason.EMPTY_CONTENT) {
                Toast.makeText(
                    context,
                    ChartsStrings.serviceMsgStatisticsShareFailed
                        .filled("detail", decision.reason.toDetailCode()),
                    Toast.LENGTH_SHORT,
                ).show()
            }
            false
        }

        is StatisticsShareImageDecision.Decision.ShareImage ->
            launchImageShare(context, decision.payload, decision.uri)
    }
}

// ---------------------------------------------------------------------- 搬砖

/**
 * 降级原因 → toast `{detail}` 位的机器短码。
 *
 * 对齐 Dart `statistics_share_service.dart` 的 detail 取值风格（`capture_empty` /
 * `overlay_missing` 一类小写下划线码）：这不是用户文案，是排障锚点——真因要查日志
 * （[LOG_TAG] 里有完整 reason）。与发布版同口径：detail 原样进模板，不做二次转义。
 */
private fun StatisticsShareImageDecision.FallbackReason.toDetailCode(): String = when (this) {
    StatisticsShareImageDecision.FallbackReason.EMPTY_CONTENT -> "empty_content"
    StatisticsShareImageDecision.FallbackReason.RASTERIZE_FAILED -> "rasterize_failed"
    StatisticsShareImageDecision.FallbackReason.WRITE_FAILED -> "write_failed"
    StatisticsShareImageDecision.FallbackReason.PROVIDER_UNAVAILABLE -> "provider_unavailable"
    StatisticsShareImageDecision.FallbackReason.NO_TARGET -> "no_target"
}

/** 把 PNG 写进 `cacheDir` 的**已登记**子目录；失败回 null（不抛、不吞原因）。 */
private fun writeSharePng(context: Context, relativePath: String, png: ByteArray): File? = runCatching {
    File(context.cacheDir, relativePath).apply {
        parentFile?.mkdirs()
        writeBytes(png)
    }
}.onFailure {
    Log.w(LOG_TAG, "分享图落盘失败（$relativePath）", it)
}.getOrNull()

/** 换成 `FileProvider` 的 content Uri；provider 没注册 / 白名单没覆盖时回 null。 */
private fun resolveShareUri(context: Context, file: File): String? = runCatching {
    FileProvider.getUriForFile(
        context,
        StatisticsShareImageModel.providerAuthority(context.packageName),
        file,
    ).toString()
}.onFailure {
    Log.w(LOG_TAG, "FileProvider 不可用（${file.path}）", it)
}.getOrNull()

/** 拉起系统分享面板；没有能接图的应用回 false（调用方再退回纯文本）。 */
private fun launchImageShare(
    context: Context,
    payload: StatisticsShareImageModel.Payload,
    uri: String,
): Boolean {
    val contentUri = Uri.parse(uri)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = payload.mimeType
        putExtra(Intent.EXTRA_STREAM, contentUri)
        putExtra(Intent.EXTRA_SUBJECT, payload.subject)
        putExtra(Intent.EXTRA_TEXT, payload.text)
        // ClipData 不是可选装饰：没有它，部分接收方拿不到读权限，图会显示成空白/裂图。
        clipData = ClipData.newUri(context.contentResolver, payload.clipLabel, contentUri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(intent, payload.subject).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return runCatching {
        context.startActivity(chooser)
        true
    }.getOrElse {
        // 2026-11-05 成员八复核②：这里此前无声降级——用户点的是分享图、收到的是
        // 文字面板，没有任何解释（FallbackToText 分支的提示只覆盖判决期失败，
        // NO_TARGET 发生在判决之后、永远走不到）。补齐同一条提示，
        // 文案复用 ARB 既有键 `serviceMsgStatisticsShareFailed`。
        Log.w(LOG_TAG, "没有能接收图片分享的应用，降级成纯文本分享", it)
        Toast.makeText(
            context,
            ChartsStrings.serviceMsgStatisticsShareFailed.filled(
                "detail",
                StatisticsShareImageDecision.FallbackReason.NO_TARGET.toDetailCode(),
            ),
            Toast.LENGTH_SHORT,
        ).show()
        false
    }
}

/** F12 那套纯文本分享（真数据、无附件）。图片路径失败时才会走到这里。 */
private fun shareStatisticsTextOnly(context: Context, text: String, subject: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, text)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    val chooser = Intent.createChooser(intent, subject).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(chooser) }
}

/**
 * 导出宽度：把当前可用宽度收进 320~420dp（Dart `mediaQuery.size.width.clamp(320, 420)` 同口径）。
 *
 * `screenWidthDp` 在非 Activity context 上可能是 0，所以退回按像素/密度算——
 * 0 会让整张图缩成 1px 宽，比拿不到精确窗口宽度糟糕得多。
 */
private fun exportWidthDp(context: Context): Float {
    val resources = context.resources
    val screenWidthDp = resources.configuration.screenWidthDp
    val availableDp = if (screenWidthDp > 0) {
        screenWidthDp.toFloat()
    } else {
        resources.displayMetrics.widthPixels / resources.displayMetrics.density
    }
    return StatisticsShareImageModel.exportWidthDp(availableDp)
}

// ══════════════════════ 导出长图（模块选择 → 文档 → PNG） ══════════════════════

/**
 * 导出失败时 toast 模板 `{detail}` 位的机器短码（与 `toDetailCode()` 同风格，排障锚点）。
 */
private const val EXPORT_FAILED_DETAIL = "export_failed"

/**
 * 「分享统计」的**导出文档**路径：按用户勾选的模块渲染长图，再走系统分享面板。
 *
 * 这条链路对应发布版 `course_statistics_screen.dart:37-70` → `showStatisticsExportSheet`
 * → `statistics_export_document.dart`；重构版此前点分享直接调 [shareStatisticsText]
 * （只有一张小卡），弹层与文档都没接线（审核项 #6）。
 *
 * ## 失败一律降级成纯文本，绝不假装
 *
 * 光栅化 / 落盘 / `FileProvider` 任一步失败都退回 [shareStatisticsTextOnly]，并弹
 * `serviceMsgStatisticsShareFailed`（detail = [EXPORT_FAILED_DETAIL]）；与
 * [shareStatisticsImage] 同一条纪律：**不生成空图冒充「已导出图片」**。
 */
fun shareStatisticsExport(
    context: Context,
    options: StatisticsExportOptions,
    content: StatisticsExportContent,
    text: String,
    subject: String,
) {
    val png = StatisticsExportImageRender.renderPng(
        context = context,
        options = options,
        content = content,
        widthDp = exportWidthDp(context),
    )
    // 载荷为空 = 正文真的没有内容（`StatisticsShareImageModel` 的诚实出口）：
    // 不发空图，直接退回纯文本。
    val payload = StatisticsShareImageModel.payload(
        text = text,
        subject = subject,
        epochMillis = System.currentTimeMillis(),
    )
    val file = if (png != null && payload != null) {
        writeSharePng(context, payload.cacheRelativePath, png)
    } else {
        null
    }
    val uri = file?.let { resolveShareUri(context, it) }

    if (payload == null || file == null || uri == null) {
        Toast.makeText(
            context,
            ChartsStrings.serviceMsgStatisticsShareFailed
                .filled("detail", EXPORT_FAILED_DETAIL),
            Toast.LENGTH_SHORT,
        ).show()
        shareStatisticsTextOnly(context, text, subject)
        return
    }
    // `launchImageShare` 在「没有能收图的应用」时自己弹提示并回 false → 再降级成纯文本。
    if (!launchImageShare(context, payload, uri)) {
        shareStatisticsTextOnly(context, text, subject)
    }
}

/**
 * 导出长图的光栅化：把 [StatisticsExportContent] 按勾选模块画成一张 PNG。
 *
 * ## 为什么是 framework Canvas，而不是把屏内 Compose 文档离屏捕获
 *
 * 与 [StatisticsShareImageRender] / `TimetableShareImageRender` 同一条裁定：
 * 分享回调里没有 Composition，Android 侧离屏 `ComposeView` 不挂 window 不跑组合；
 * 而且导出图**本来就该与屏内主题解耦**（恒浅色 + 固定字号是产物规则）。
 * 屏内那份 Compose 文档（`charts/StatisticsExportCards.kt` 的 `StatisticsExportDocument`）
 * 仍是同一份段落模型的「所见即所得」实现；两条路径共用
 * [ExportDocumentModel.sections] 决定「画哪几段、什么顺序、什么标题」，
 * 不会出现「勾了排行、图里没有」。
 *
 * ## 与屏内文档的已知差距（诚实清单，不是漏抄）
 *
 * - 品牌条没有应用图标 / logo 图（同 `StatisticsShareImageRender` 的既有取舍）；
 * - 日课时分布画成柱条（不画纵轴刻度），性质占比画成图例行（不画环图），
 *   排行不带「上课时间摘要」列——数值与文案同源，只是版式更省。
 */
internal object StatisticsExportImageRender {

    // 导出图配色：恒浅色（产物的一部分，不是主题令牌）。底色与 Dart
    // `ShareExportStyle.background`（0xFFF2F2F2）逐位相同，同 `StatisticsShareImageRender`。
    private val BACKGROUND_ARGB: Int = 0xFFF2F2F2.toInt()
    private val SURFACE_ARGB: Int = 0xFFFFFFFF.toInt()
    private val INK_ARGB: Int = 0xFF111111.toInt()
    private val SECONDARY_INK_ARGB: Int = 0xFF6B6B6B.toInt()
    private val ACCENT_ARGB: Int = 0xFF2563EB.toInt()
    private val DIVIDER_ARGB: Int = 0x1F000000
    private val BAR_TRACK_ARGB: Int = 0x14000000

    private const val PADDING_DP: Float = 16f
    private const val SECTION_GAP_DP: Float = 12f
    private const val SECTION_TITLE_GAP_DP: Float = 6f
    private const val ROW_GAP_DP: Float = 8f
    private const val ROW_INNER_GAP_DP: Float = 8f
    private const val ROW_SUB_GAP_DP: Float = 2f
    private const val METRIC_CELL_HEIGHT_DP: Float = 58f
    private const val METRIC_CELL_GAP_DP: Float = 8f
    private const val METRIC_CELL_PADDING_DP: Float = 10f
    private const val CELL_RADIUS_DP: Float = 10f
    private const val BAR_MAX_HEIGHT_DP: Float = 64f
    private const val RANK_BADGE_DP: Float = 20f

    /** 单张 PNG 的高度上限（超过就降级成文本，别赌 GPU/内存上限）。 */
    private const val MAX_BITMAP_HEIGHT_PX = 20000

    private const val TITLE_TEXT_DP: Float = 17f
    private const val SECTION_TITLE_TEXT_DP: Float = 12f
    private const val ROW_TEXT_DP: Float = 13f
    private const val DETAIL_TEXT_DP: Float = 11f
    private const val METRIC_VALUE_TEXT_DP: Float = 20f
    private const val BAR_LABEL_TEXT_DP: Float = 9f
    private const val BRAND_TITLE_TEXT_DP: Float = 15f
    private const val BRAND_DETAIL_TEXT_DP: Float = 11f
    private const val LINE_SPACING_MULTIPLIER: Float = 1.15f

    /**
     * 把文档画成 PNG 字节；任何一步失败回 `null`（调用方据此降级成纯文本分享）。
     *
     * 本身不碰磁盘、不碰 Intent。
     */
    fun renderPng(
        context: Context,
        options: StatisticsExportOptions,
        content: StatisticsExportContent,
        widthDp: Float,
    ): ByteArray? = runCatching {
        val resources = context.resources
        val density = resources.displayMetrics.density
        val fontScale = resources.configuration.fontScale
        val widthPx = (widthDp * density).roundToInt().coerceAtLeast(1)
        val padPx = dp(PADDING_DP, density)
        val contentWidthPx = (widthPx - padPx * 2).coerceAtLeast(1)
        val paints = paintsOf(density, fontScale)

        val sections = ExportDocumentModel.sections(
            options = options,
            achievementCount = content.semester.achievements.size,
            storyCount = content.semester.stories.size,
        )

        val blocks = ArrayList<DocBlock>()
        // ── 品牌页头（Dart 文档：品牌条 + 底部分隔线）──
        blocks += brandBlock(contentWidthPx, paints, density)
        blocks += dividerBlock(
            contentWidthPx = contentWidthPx,
            gapBeforePx = dp(ExportDocumentModel.BRAND_TO_TITLE_GAP_DP.toFloat(), density),
            gapAfterPx = 0,
            density = density,
        )
        // ── 标题 ──
        blocks += textBlock(
            layout(ExportDocumentModel.title, paints.title, contentWidthPx),
            dp(ExportDocumentModel.TITLE_TO_SECTIONS_GAP_DP.toFloat(), density),
        )
        // ── 勾选的各段 ──
        sections.forEachIndexed { index, section ->
            if (index > 0) blocks += DocBlock(dp(SECTION_GAP_DP, density)) { }
            if (section.title.isNotEmpty()) {
                blocks += textBlock(
                    layout(section.title, paints.section, contentWidthPx),
                    dp(SECTION_TITLE_GAP_DP, density),
                )
            }
            when (section.kind) {
                ExportSectionKind.OVERVIEW ->
                    blocks += overviewBlocks(content.semester.overview, contentWidthPx, paints, density)

                ExportSectionKind.ACHIEVEMENTS ->
                    blocks += achievementBlocks(content.semester.achievements, contentWidthPx, paints, density)

                ExportSectionKind.STORIES ->
                    blocks += storyBlocks(content.semester.stories, contentWidthPx, paints, density)

                ExportSectionKind.DAILY_DISTRIBUTION ->
                    blocks += dailyBlocks(content.semester.dailyChart, contentWidthPx, paints, density)

                ExportSectionKind.NATURE_RATIO ->
                    blocks += natureBlocks(content.semester.nature, contentWidthPx, paints, density)

                ExportSectionKind.RANKING ->
                    blocks += rankingBlocks(content.rankingRows, contentWidthPx, paints, density)
            }
        }
        // ── 品牌页脚（分隔线 + 品牌条）──
        blocks += dividerBlock(
            contentWidthPx = contentWidthPx,
            gapBeforePx = dp(ExportDocumentModel.SECTIONS_TO_FOOTER_GAP_DP.toFloat(), density),
            gapAfterPx = dp(ExportBrandModel.DIVIDER_GAP_DP.toFloat(), density),
            density = density,
        )
        blocks += brandBlock(contentWidthPx, paints, density)

        val totalContentHeight = blocks.sumOf { it.heightPx }
        val heightPx = (padPx * 2 + totalContentHeight).coerceAtLeast(1)
        if (heightPx > MAX_BITMAP_HEIGHT_PX) return@runCatching null

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(BACKGROUND_ARGB)
            var y = padPx.toFloat()
            blocks.forEach { block ->
                canvas.save()
                canvas.translate(padPx.toFloat(), y)
                block.draw(canvas)
                canvas.restore()
                y += block.heightPx
            }

            ByteArrayOutputStream().use { out ->
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)) return@runCatching null
                out.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }.getOrNull()

    // ------------------------------------------------------------------ 品牌条

    /**
     * 品牌条：左侧三行（应用名 / 一句介绍 / 网址）+ 右侧二维码。
     *
     * 尺寸口径照抄 `StatisticsExportBrandBar`：二维码边长 = 文字块高度夹在 48~72dp。
     */
    private fun brandBlock(contentWidthPx: Int, paints: Paints, density: Float): DocBlock {
        val qrSizePx = (ExportBrandModel.defaultQrSize() * density).roundToInt().coerceAtLeast(1)
        val gapToQr = dp(ExportBrandModel.TEXT_TO_QR_GAP_DP.toFloat(), density)
        val textWidthPx = (contentWidthPx - qrSizePx - gapToQr).coerceAtLeast(1)

        val titleLayout = layout(ExportBrandModel.appName, paints.brandTitle, textWidthPx)
        val taglineLayout = layout(ExportBrandModel.tagline, paints.brandDetail, textWidthPx)
        val websiteLayout = layout(ExportBrandModel.websiteDisplay, paints.brandDetail, textWidthPx)

        val titleToTagline = dp(ExportBrandModel.TITLE_TO_TAGLINE_GAP_DP.toFloat(), density)
        val taglineToUrl = dp(ExportBrandModel.TAGLINE_TO_URL_GAP_DP.toFloat(), density)
        val textHeight = titleLayout.height + titleToTagline +
            taglineLayout.height + taglineToUrl + websiteLayout.height
        val heightPx = max(textHeight, qrSizePx)

        val matrix = QrEncodeModel.encode(ExportBrandModel.websiteUrl)
        val qrPaint = Paint().apply { color = INK_ARGB }

        return DocBlock(heightPx) { canvas ->
            canvas.save()
            titleLayout.draw(canvas)
            canvas.restore()
            canvas.save()
            canvas.translate(0f, (titleLayout.height + titleToTagline).toFloat())
            taglineLayout.draw(canvas)
            canvas.restore()
            canvas.save()
            canvas.translate(
                0f,
                (titleLayout.height + titleToTagline + taglineLayout.height + taglineToUrl).toFloat(),
            )
            websiteLayout.draw(canvas)
            canvas.restore()

            // 二维码：一格格填方块（与 `QrCodeCanvas` 同一算法，只是画在 framework canvas 上）。
            val cell = qrSizePx.toFloat() / matrix.size
            val qrLeft = (contentWidthPx - qrSizePx).toFloat()
            for (row in 0 until matrix.size) {
                for (column in 0 until matrix.size) {
                    if (!matrix.isDark(column, row)) continue
                    val x = qrLeft + column * cell
                    val y = row * cell
                    canvas.drawRect(x, y, x + cell + 0.5f, y + cell + 0.5f, qrPaint)
                }
            }
        }
    }

    // ------------------------------------------------------------------ 各段

    /** 总览：2 列 × N 行的指标格（值在上、标签在下；首格主题色高亮在模型层已定）。 */
    private fun overviewBlocks(
        metrics: List<StatisticsMetricView>,
        contentWidthPx: Int,
        paints: Paints,
        density: Float,
    ): List<DocBlock> {
        if (metrics.isEmpty()) return emptyList()
        val rows = metrics.chunked(2)
        val cellGap = dp(METRIC_CELL_GAP_DP, density)
        val cellWidth = ((contentWidthPx - cellGap) / 2).coerceAtLeast(1)
        val innerPad = dp(METRIC_CELL_PADDING_DP, density)
        val cellHeight = dp(METRIC_CELL_HEIGHT_DP, density)
        val radius = dp(CELL_RADIUS_DP, density).toFloat()
        val textWidth = (cellWidth - innerPad * 2).coerceAtLeast(1)
        val subGap = dp(ROW_SUB_GAP_DP, density)

        val out = ArrayList<DocBlock>()
        rows.forEachIndexed { rowIndex, cells ->
            val valueLayouts = cells.map { metric ->
                layout(
                    metric.value,
                    if (metric.highlight) paints.metricValueHighlight else paints.metricValue,
                    textWidth,
                    Layout.Alignment.ALIGN_CENTER,
                )
            }
            val labelLayouts = cells.map { metric ->
                layout(metric.label, paints.metricLabel, textWidth, Layout.Alignment.ALIGN_CENTER)
            }
            val gapAfter = if (rowIndex < rows.lastIndex) cellGap else 0
            out += DocBlock(cellHeight + gapAfter) { canvas ->
                cells.forEachIndexed { column, _ ->
                    val left = column * (cellWidth + cellGap)
                    canvas.drawRoundRect(
                        RectF(left.toFloat(), 0f, (left + cellWidth).toFloat(), cellHeight.toFloat()),
                        radius,
                        radius,
                        paints.surface,
                    )
                    val valueLayout = valueLayouts[column]
                    val labelLayout = labelLayouts[column]
                    val textHeight = valueLayout.height + subGap + labelLayout.height
                    val top = ((cellHeight - textHeight) / 2).coerceAtLeast(0)
                    canvas.save()
                    canvas.translate((left + innerPad).toFloat(), top.toFloat())
                    valueLayout.draw(canvas)
                    canvas.restore()
                    canvas.save()
                    canvas.translate(
                        (left + innerPad).toFloat(),
                        (top + valueLayout.height + subGap).toFloat(),
                    )
                    labelLayout.draw(canvas)
                    canvas.restore()
                }
            }
        }
        return out
    }

    /** 成就：名称 + 右上状态（已达成 / 未解锁）+ 说明一行。 */
    private fun achievementBlocks(
        achievements: List<AchievementView>,
        contentWidthPx: Int,
        paints: Paints,
        density: Float,
    ): List<DocBlock> {
        if (achievements.isEmpty()) return emptyList()
        val statusWidth = (contentWidthPx * 0.30f).roundToInt().coerceAtLeast(1)
        val nameWidth = (contentWidthPx - statusWidth - dp(ROW_INNER_GAP_DP, density)).coerceAtLeast(1)
        val subGap = dp(ROW_SUB_GAP_DP, density)

        val out = ArrayList<DocBlock>()
        achievements.forEach { achievement ->
            val nameLayout = layout(achievement.name, paints.rowBold, nameWidth)
            val statusLayout = layout(
                achievement.statusLabel,
                paints.detail,
                statusWidth,
                Layout.Alignment.ALIGN_OPPOSITE,
            )
            val descLayout = achievement.description.takeIf { it.isNotBlank() }?.let { layout(it, paints.detail, contentWidthPx) }
            val rowHeight = max(nameLayout.height, statusLayout.height)
            val heightPx = rowHeight + (descLayout?.let { subGap + it.height } ?: 0) + dp(ROW_GAP_DP, density)
            out += DocBlock(heightPx) { canvas ->
                canvas.save()
                nameLayout.draw(canvas)
                canvas.restore()
                canvas.save()
                canvas.translate((contentWidthPx - statusWidth).toFloat(), 0f)
                statusLayout.draw(canvas)
                canvas.restore()
                descLayout?.let {
                    canvas.save()
                    canvas.translate(0f, (rowHeight + subGap).toFloat())
                    it.draw(canvas)
                    canvas.restore()
                }
            }
        }
        return out
    }

    /** 数据故事：标题 + 正文（正文里的 `**` 是屏上富文本标记，图里去掉）。 */
    private fun storyBlocks(
        stories: List<StoryView>,
        contentWidthPx: Int,
        paints: Paints,
        density: Float,
    ): List<DocBlock> {
        if (stories.isEmpty()) return emptyList()
        val subGap = dp(ROW_SUB_GAP_DP, density)
        val out = ArrayList<DocBlock>()
        stories.forEach { story ->
            val titleLayout = layout(story.title, paints.rowBold, contentWidthPx)
            val bodyLayout = layout(story.content.replace("**", ""), paints.detail, contentWidthPx)
            out += DocBlock(titleLayout.height + subGap + bodyLayout.height + dp(ROW_GAP_DP, density)) { canvas ->
                canvas.save()
                titleLayout.draw(canvas)
                canvas.restore()
                canvas.save()
                canvas.translate(0f, (titleLayout.height + subGap).toFloat())
                bodyLayout.draw(canvas)
                canvas.restore()
            }
        }
        return out
    }

    /** 每日课时分布：7 根柱（值在上、周几在下）；没有数据给一行空态。 */
    private fun dailyBlocks(
        spec: BarChartSpec?,
        contentWidthPx: Int,
        paints: Paints,
        density: Float,
    ): List<DocBlock> {
        if (spec == null || spec.bars.isEmpty()) {
            return listOf(
                textBlock(
                    layout(ExportRankingModel.emptyMessage, paints.detail, contentWidthPx),
                    dp(ROW_GAP_DP, density),
                ),
            )
        }
        val barMaxHeight = dp(BAR_MAX_HEIGHT_DP, density)
        val valueLine = lineHeight(paints.barValue)
        val labelLine = lineHeight(paints.barLabel)
        val subGap = dp(ROW_SUB_GAP_DP, density)
        val slot = contentWidthPx.toFloat() / spec.bars.size
        val barWidth = slot * 0.46f
        val radius = dp(4f, density).toFloat()
        val maxY = if (spec.maxY > 0.0) spec.maxY else 1.0
        val baseline = (valueLine + subGap + barMaxHeight).toFloat()

        return listOf(
            DocBlock(valueLine + subGap + barMaxHeight + subGap + labelLine + dp(ROW_GAP_DP, density)) { canvas ->
                spec.bars.forEachIndexed { index, bar ->
                    val ratio = (bar.value / maxY).coerceIn(0.0, 1.0).toFloat()
                    val barHeight = barMaxHeight * ratio
                    val left = slot * index + (slot - barWidth) / 2f
                    canvas.drawRoundRect(
                        RectF(left, baseline - barHeight, left + barWidth, baseline),
                        radius,
                        radius,
                        if (bar.value > 0.0) paints.accent else paints.barTrack,
                    )
                    val centerX = left + barWidth / 2f
                    if (bar.value > 0.0) {
                        canvas.drawText(
                            CourseStatisticsLogic.oneDecimal(bar.value),
                            centerX,
                            baseline - barHeight - subGap,
                            paints.barValue,
                        )
                    }
                    canvas.drawText(
                        bar.label,
                        centerX,
                        baseline + subGap - paints.barLabel.fontMetrics.ascent,
                        paints.barLabel,
                    )
                }
            },
        )
    }

    /** 必修 / 选修：图例行（标签 + 右侧占比 + 说明）；没有数据给一行空态。 */
    private fun natureBlocks(
        nature: NatureRatioView,
        contentWidthPx: Int,
        paints: Paints,
        density: Float,
    ): List<DocBlock> {
        if (!nature.hasData || nature.legend.isEmpty()) {
            return listOf(
                textBlock(
                    layout(ExportRankingModel.emptyMessage, paints.detail, contentWidthPx),
                    dp(ROW_GAP_DP, density),
                ),
            )
        }
        val ratioWidth = (contentWidthPx * 0.32f).roundToInt().coerceAtLeast(1)
        val labelWidth = (contentWidthPx - ratioWidth - dp(ROW_INNER_GAP_DP, density)).coerceAtLeast(1)
        val subGap = dp(ROW_SUB_GAP_DP, density)

        val out = ArrayList<DocBlock>()
        nature.legend.forEach { legend ->
            val labelLayout = layout(legend.label, paints.row, labelWidth)
            val ratioLayout = layout(
                legend.ratioText,
                paints.rowBold,
                ratioWidth,
                Layout.Alignment.ALIGN_OPPOSITE,
            )
            val detailLayout = legend.detail.takeIf { it.isNotBlank() }?.let { layout(it, paints.detail, contentWidthPx) }
            val rowHeight = max(labelLayout.height, ratioLayout.height)
            out += DocBlock(
                rowHeight + (detailLayout?.let { subGap + it.height } ?: 0) + dp(ROW_GAP_DP, density),
            ) { canvas ->
                canvas.save()
                labelLayout.draw(canvas)
                canvas.restore()
                canvas.save()
                canvas.translate((contentWidthPx - ratioWidth).toFloat(), 0f)
                ratioLayout.draw(canvas)
                canvas.restore()
                detailLayout?.let {
                    canvas.save()
                    canvas.translate(0f, (rowHeight + subGap).toFloat())
                    it.draw(canvas)
                    canvas.restore()
                }
            }
        }
        return out
    }

    /** 课程排行：名次徽标 + 课名 + 右侧课时；最多画 20 门，多出的给「另有 N 门」。 */
    private fun rankingBlocks(
        rows: List<Pair<String, String>>,
        contentWidthPx: Int,
        paints: Paints,
        density: Float,
    ): List<DocBlock> {
        if (rows.isEmpty()) {
            return listOf(
                textBlock(
                    layout(ExportRankingModel.emptyMessage, paints.detail, contentWidthPx),
                    dp(ROW_GAP_DP, density),
                ),
            )
        }
        val visible = rows.take(ExportRankingModel.MAX_ITEMS)
        val badge = dp(RANK_BADGE_DP, density)
        val badgeGap = dp(ROW_INNER_GAP_DP, density)
        val valueWidth = (contentWidthPx * 0.22f).roundToInt().coerceAtLeast(1)
        val nameWidth = (contentWidthPx - badge - badgeGap - valueWidth - badgeGap).coerceAtLeast(1)
        val radius = dp(6f, density).toFloat()

        val out = ArrayList<DocBlock>()
        visible.forEachIndexed { index, row ->
            val nameLayout = layout(row.first, paints.row, nameWidth)
            val valueLayout = layout(row.second, paints.detail, valueWidth, Layout.Alignment.ALIGN_OPPOSITE)
            val rowHeight = max(badge, max(nameLayout.height, valueLayout.height))
            out += DocBlock(rowHeight + dp(ROW_GAP_DP, density)) { canvas ->
                canvas.drawRoundRect(
                    RectF(0f, 0f, badge.toFloat(), badge.toFloat()),
                    radius,
                    radius,
                    paints.rankBadge,
                )
                val centerY = badge / 2f -
                    (paints.rankNumber.fontMetrics.ascent + paints.rankNumber.fontMetrics.descent) / 2f
                canvas.drawText((index + 1).toString(), badge / 2f, centerY, paints.rankNumber)

                canvas.save()
                canvas.translate(
                    (badge + badgeGap).toFloat(),
                    ((rowHeight - nameLayout.height) / 2f).coerceAtLeast(0f),
                )
                nameLayout.draw(canvas)
                canvas.restore()

                canvas.save()
                canvas.translate(
                    (contentWidthPx - valueWidth).toFloat(),
                    ((rowHeight - valueLayout.height) / 2f).coerceAtLeast(0f),
                )
                valueLayout.draw(canvas)
                canvas.restore()
            }
        }
        ExportRankingModel.remainingLabel(rows.size, visible.size)?.let { remaining ->
            out += textBlock(
                layout(remaining, paints.detail, contentWidthPx, Layout.Alignment.ALIGN_CENTER),
                dp(ROW_GAP_DP, density),
            )
        }
        return out
    }

    // ------------------------------------------------------------------ 内部

    /** 一块「先量高、后绘制」的内容；坐标原点 = 内容区左上角（内边距由外层统一加）。 */
    private class DocBlock(val heightPx: Int, val draw: (Canvas) -> Unit)

    private fun textBlock(layout: StaticLayout, gapAfterPx: Int): DocBlock =
        DocBlock(layout.height + gapAfterPx) { canvas ->
            canvas.save()
            layout.draw(canvas)
            canvas.restore()
        }

    private fun dividerBlock(
        contentWidthPx: Int,
        gapBeforePx: Int,
        gapAfterPx: Int,
        density: Float,
    ): DocBlock {
        val thickness = (1f * density).roundToInt().coerceAtLeast(1)
        return DocBlock(gapBeforePx + thickness + gapAfterPx) { canvas ->
            val y = gapBeforePx.toFloat()
            canvas.drawLine(0f, y, contentWidthPx.toFloat(), y, dividerPaint(density))
        }
    }

    private fun dividerPaint(density: Float): Paint = Paint().apply {
        color = DIVIDER_ARGB
        strokeWidth = 1f * density
    }

    private class Paints(
        val title: TextPaint,
        val section: TextPaint,
        val row: TextPaint,
        val rowBold: TextPaint,
        val detail: TextPaint,
        val metricValue: TextPaint,
        val metricValueHighlight: TextPaint,
        val metricLabel: TextPaint,
        val barLabel: TextPaint,
        val barValue: TextPaint,
        val brandTitle: TextPaint,
        val brandDetail: TextPaint,
        val rankNumber: TextPaint,
        val surface: Paint,
        val accent: Paint,
        val barTrack: Paint,
        val rankBadge: Paint,
    )

    private fun paintsOf(density: Float, fontScale: Float): Paints = Paints(
        title = textPaint(TITLE_TEXT_DP, density, fontScale, INK_ARGB, bold = true),
        section = textPaint(SECTION_TITLE_TEXT_DP, density, fontScale, SECONDARY_INK_ARGB, bold = true),
        row = textPaint(ROW_TEXT_DP, density, fontScale, INK_ARGB, bold = false),
        rowBold = textPaint(ROW_TEXT_DP, density, fontScale, INK_ARGB, bold = true),
        detail = textPaint(DETAIL_TEXT_DP, density, fontScale, SECONDARY_INK_ARGB, bold = false),
        metricValue = textPaint(METRIC_VALUE_TEXT_DP, density, fontScale, INK_ARGB, bold = true),
        metricValueHighlight = textPaint(METRIC_VALUE_TEXT_DP, density, fontScale, ACCENT_ARGB, bold = true),
        metricLabel = textPaint(DETAIL_TEXT_DP, density, fontScale, SECONDARY_INK_ARGB, bold = false),
        barLabel = textPaint(BAR_LABEL_TEXT_DP, density, fontScale, SECONDARY_INK_ARGB, bold = false)
            .apply { textAlign = Paint.Align.CENTER },
        barValue = textPaint(BAR_LABEL_TEXT_DP, density, fontScale, INK_ARGB, bold = false)
            .apply { textAlign = Paint.Align.CENTER },
        brandTitle = textPaint(BRAND_TITLE_TEXT_DP, density, fontScale, INK_ARGB, bold = true),
        brandDetail = textPaint(BRAND_DETAIL_TEXT_DP, density, fontScale, SECONDARY_INK_ARGB, bold = false),
        rankNumber = textPaint(DETAIL_TEXT_DP, density, fontScale, SURFACE_ARGB, bold = true)
            .apply { textAlign = Paint.Align.CENTER },
        surface = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = SURFACE_ARGB },
        accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ACCENT_ARGB },
        barTrack = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = BAR_TRACK_ARGB },
        rankBadge = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ACCENT_ARGB },
    )

    /**
     * 字号换算。乘 `fontScale` 是故意的（大字体用户发出去的图不该比屏上小一号），
     * 但**不**读主题的 textStyles：导出图与屏内主题解耦（见对象头注释）。
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
        textAlign = Paint.Align.LEFT
    }

    private fun layout(
        text: String,
        paint: TextPaint,
        widthPx: Int,
        alignment: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
    ): StaticLayout = StaticLayout.Builder
        .obtain(text, 0, text.length, paint, widthPx.coerceAtLeast(1))
        .setAlignment(alignment)
        .setIncludePad(false)
        .setLineSpacing(0f, LINE_SPACING_MULTIPLIER)
        .build()

    private fun lineHeight(paint: Paint): Int =
        (paint.fontMetrics.descent - paint.fontMetrics.ascent).roundToInt().coerceAtLeast(1)

    private fun dp(value: Float, density: Float): Int = (value * density).roundToInt()
}
