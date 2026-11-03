package com.mutx163.qingyu.statistics

/**
 * 导出分享图**品牌条**的尺寸与文案（2026-11-03 从 `pages/statistics/charts/ExportModels.kt`
 * 下沉到本共享层——域边界治理）。
 *
 * ## 为什么下沉
 *
 * 品牌条被**两个页面域**消费：统计域（导出文档 `StatisticsExportCards` 与分享图
 * `StatisticsShareImageRender`）和课表域（「干净课表图」`TimetableShareImageModel`
 * 的高度预算要用 `textBlockHeight`/`qrSize`）。课表域的 main 层 import 统计域类型
 * 会被域边界守卫（`pages/DomainBoundaryImportGuardTest`）判红——「被 ≥2 个域用的
 * 纯数据下沉共享层」正是守卫头注释指定的去处。本目录（`com.mutx163.qingyu.statistics`）
 * 在 L0 脚本的共享收编清单里，两个域都能无参编译。
 *
 * ## 与 charts 包那份的关系
 *
 * `pages/statistics/charts/ExportModels.kt` 原位留了一个**委托保形 val**
 * （指向本 object 的同一单例），统计域既有代码与其 `ExportModelsTest` 不用改一行
 * ——那些值断言经保形 val 继续钉住本文件的实现，不会出现「屏上一种、分享图另一种」。
 *
 * ## 文案真源
 *
 * [appName] / [tagline] 的真源是 ARB（`timetableAppName` / `statisticsExportBrandTagline`，
 * 六语已齐）；charts 包的 `ChartsStrings` 仍保有这两条并被其对拍测试钉住 ARB 一致性。
 * 共享层不反引页面域（那是比跨域更糟的依赖方向），所以这里**逐字内联**同值，
 * 由统计域 `ExportModelsTest` 的值断言（经保形 val）与 charts 的 ARB 对拍双侧钉住漂移。
 * 网址两串沿用同包 [StatisticsExportBrand]。
 */
object ExportBrandModel {

    /** 应用名（ARB `timetableAppName`，与 charts 包 `ChartsStrings.timetableAppName` 逐字同值）。 */
    val appName: String get() = "轻屿课表"

    /** 一句介绍（ARB `statisticsExportBrandTagline`，与 charts 包同键逐字同值）。 */
    val tagline: String get() = "把课程信息做成系统体验"

    /** 网址展示串（[StatisticsExportBrand.WEBSITE_DISPLAY]）。 */
    val websiteDisplay: String
        get() = StatisticsExportBrand.WEBSITE_DISPLAY

    /** 二维码内容（[StatisticsExportBrand.WEBSITE_URL]）。 */
    val websiteUrl: String
        get() = StatisticsExportBrand.WEBSITE_URL

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
