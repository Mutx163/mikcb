package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.share.TransferShareContract

/**
 * 统计页「分享成果图」的**纯逻辑**（2026-10-30 F15 新增）。
 *
 * ## 它补的是哪个洞
 *
 * F12 把 `e.statistics` 顶栏那颗分享图标从空 lambda 接成了**真文本分享**
 * （[StatisticsShareText] + `shareStatisticsText`），但它自己把图片导出记成未做：
 * Dart `statistics_share_service.dart:45-108` 的产物是「**离屏光栅化的 PNG** +
 * subject + 正文」，用户分享出去的是一张图，不是一段文字。
 *
 * 本文件只算「图应该长什么样、文件叫什么、落在哪、Intent 里该带什么」，
 * 一行 `android.*` 都没有，所以能进 JVM 单测（[StatisticsShareImageModelTest]）。
 * 真正画像素的活在同名目录下的 `StatisticsShareImageRender`（composeP1，引 android.*）。
 *
 * ## 图的内容从哪来（重要，别把它当成「截图」）
 *
 * 壳（`ShellPageIndex.kt` 的 `e.statistics` 分支）传给分享函数的只有一个**已经拼好的正文
 * 字符串**（`StatisticsShareText.build(feedState.home)`：标题 + ARB 正文 + 真指标行）。
 * 壳文件不在本批写作用域，所以这里**把这段正文当导出文档来排版**——
 * 与 Dart 的口径其实一致：Dart 的 `StatisticsShareService` 也是「光栅化**调用方给的文档**」，
 * 不是截当前屏幕的图。
 *
 * 因此图里出现的每一个字**本来就在屏上/正文里**（标题、ARB 正文句、指标行），
 * 本批不新增任何 ARB 键、不自造标语。
 *
 * **已知差距**（写清楚，不假装）：Dart 文档里还有品牌条（logo + 二维码）、
 * 成就网格、数据故事、日分布/性质占比图、课程排行，以及「导出模块选择」弹层。
 * 那些要模型层的图表数据与 ARB 文案，本批不做——见认领文件 `claims/F15-statistics-share-image.md`
 * 的「未做」一节。
 *
 * ## 为什么不新开一个 cacheDir 子目录
 *
 * `res/xml/file_paths.xml`（FileProvider 白名单）**不在本批写作用域**，而
 * `FileProvider.getUriForFile` 只放行已登记目录、写在别处会直接抛
 * `IllegalArgumentException`。所以复用**已登记**的 `transfer-share/`：
 * 常量从 [TransferShareContract] 取（它有一条单测把常量和那份 XML 对拍），
 * 不在本文件里重抄一遍字符串——抄一份就等于多一条会静默漂移的隐式契约。
 * 同款先例：`pages/import/ImportTemplateModel`（导入模板 CSV）也复用这个目录。
 *
 * ## 目录语义不匹配这件事，直说
 *
 * 统计分享图放 `transfer-share/` 在语义上确实是借位（那个目录名讲的是 `.mikcb` 传输包）。
 * 想要一个语义干净的 `stats-share/`，需要 Lead 在 `file_paths.xml` 加一行
 * `<cache-path name="stats_share" path="stats-share/"/>`，然后这里改两行常量即可——
 * 已报给 Lead，没等它就先复用，不然这一步会一直卡着。
 */
object StatisticsShareImageModel {

    /** 分享出去的图一定是 PNG（与 Dart `XFile(path, mimeType: 'image/png')` 同）。 */
    const val MIME_PNG: String = "image/png"

    /**
     * 落盘文件名前缀/后缀。
     *
     * 与 Dart `statistics_share_service.dart:96` 的
     * `'${tempDirectory.path}/statistics_export_$timestamp.png'` 同一口径：
     * 前缀 + 毫秒时间戳 + `.png`。**用时间戳不是为了好看**——文件名相同会让上一张
     * 分享图被覆盖，接收方点开旧消息拿到的是新图。
     */
    const val FILE_PREFIX: String = "statistics_export_"
    const val FILE_SUFFIX: String = ".png"

    /** `ClipData` 标签：给接收方与排障用，不是用户文案。 */
    const val CLIP_LABEL: String = "qingyu-statistics-export"

    /**
     * 导出图宽度（dp）区间，与 Dart `exportWidth: mediaQuery.size.width.clamp(320, 420)` 同。
     *
     * 上限 420 是为了不让长图在聊天窗里缩得看不清字，下限 320 保底不挤成一条。
     */
    const val MIN_WIDTH_DP: Float = 320f
    const val MAX_WIDTH_DP: Float = 420f

    /**
     * 指标行的「标签：取值」分隔符。
     *
     * 全仓口径就是全角冒号（`StatisticsShareText.metricLines` 自己拼的），
     * 半角冒号与全角冒号混用会让「标签/取值」拆不开，指标行只能当整句正文画。
     */
    private const val LABEL_SEPARATOR: Char = '：'

    // ------------------------------------------------------------------ 文件 / Uri

    /** 文件名：`statistics_export_<毫秒时间戳>.png`。 */
    fun fileName(epochMillis: Long): String = "$FILE_PREFIX$epochMillis$FILE_SUFFIX"

    /**
     * 相对 `cacheDir` 的落盘路径，形如 `transfer-share/statistics_export_<ts>.png`。
     *
     * 走 [TransferShareContract.providerCacheRelativePath]——那个目录名有一份单测
     * （`TransferShareContractTest`）与 `file_paths.xml` 对拍，这里再抄一遍字符串
     * 只会在哪天那边改名时静默坏掉。
     */
    fun cacheRelativePath(fileName: String): String =
        TransferShareContract.providerCacheRelativePath(fileName)

    /**
     * `FileProvider` authority（`<applicationId>.fileprovider`）。
     *
     * 必须用运行期 applicationId：`dev`/`perf`/`itest` 三个变体带 `applicationIdSuffix`，
     * 写死正式包名只有正式包能分享出去。
     */
    fun providerAuthority(applicationId: String): String =
        TransferShareContract.providerAuthority(applicationId)

    /** 导出宽度：把当前可用宽度收进 [MIN_WIDTH_DP]~[MAX_WIDTH_DP]（Dart 同口径）。 */
    fun exportWidthDp(availableWidthDp: Float): Float =
        availableWidthDp.coerceIn(MIN_WIDTH_DP, MAX_WIDTH_DP)

    // ------------------------------------------------------------------ 卡片模型

    /**
     * 正文 → 卡片行（**去空行**）。
     *
     * 去空行不是洁癖：`StatisticsShareText.build` 在无数据时只回两句，中间不留空行；
     * 但一旦上游拼出空行，空行会被画成一段白条。空正文回空表。
     */
    fun cardLines(text: String): List<String> =
        text.lineSequence().map { it.trimEnd() }.filter { it.isNotBlank() }.toList()

    /**
     * 卡片行：`label` 必有，`value` 只有「标签：取值」那种行才有。
     *
     * value 为 null 表示「整行当正文画」（例如 ARB 正文句），不是「取值为空」。
     */
    data class Row(val label: String, val value: String?)

    /** 一张待光栅化的导出卡：标题 / 正文句（可空）/ 指标行 / 原样正文。 */
    data class Card(
        val title: String,
        val body: String?,
        val rows: List<Row>,
        val lines: List<String>,
    )

    /** Intent 契约 + 渲染输入（Android 侧只消费它，不自己拍字符串）。 */
    data class Payload(
        val fileName: String,
        val cacheRelativePath: String,
        val mimeType: String,
        val subject: String,
        val text: String,
        val clipLabel: String,
        val card: Card,
    )

    /**
     * 正文 → 卡片。**空正文回 null**。
     *
     * 回 null 的语义是「没有真内容，别生成一张空图」：调用方据此**不假装导出成功**，
     * 退回纯文本分享（与 F12 行为一致）。生成一张只有底色的 PNG 比不生成更糟——
     * 用户会以为「统计没数据」，而事实可能是上游把文案弄丢了。
     *
     * 行序约定与 [StatisticsShareText.build] 一致：第 0 行标题、第 1 行正文句、
     * 其余为指标行。只有 1 行时没有正文句也没有指标行（不是错误）。
     */
    fun card(text: String): Card? {
        val lines = cardLines(text)
        if (lines.isEmpty()) return null
        return Card(
            title = lines[0],
            body = lines.getOrNull(1),
            rows = lines.drop(2).map(::rowOf),
            lines = lines,
        )
    }

    /**
     * 指标行 → 标签 / 取值。
     *
     * 只在**第一个**全角冒号处切：取值本身可能带冒号（「第 3 周 · 12 节」不会，
     * 但时间类文案会，例如「08:00-09:40」是半角冒号不受影响；全角冒号也只切第一处）。
     * 切不出「两边都非空」就整行当正文，绝不造一个空标签。
     */
    private fun rowOf(line: String): Row {
        val at = line.indexOf(LABEL_SEPARATOR)
        if (at <= 0) return Row(label = line, value = null)
        val label = line.substring(0, at).trim()
        val value = line.substring(at + 1).trim()
        if (label.isEmpty() || value.isEmpty()) return Row(label = line, value = null)
        return Row(label = label, value = value)
    }

    /**
     * 分享载荷；正文算不出卡片时回 null（调用方据此降级成纯文本，不装成功）。
     */
    fun payload(text: String, subject: String, epochMillis: Long): Payload? {
        val card = card(text) ?: return null
        val fileName = fileName(epochMillis)
        return Payload(
            fileName = fileName,
            cacheRelativePath = cacheRelativePath(fileName),
            mimeType = MIME_PNG,
            subject = subject,
            text = text,
            clipLabel = CLIP_LABEL,
            card = card,
        )
    }
}
