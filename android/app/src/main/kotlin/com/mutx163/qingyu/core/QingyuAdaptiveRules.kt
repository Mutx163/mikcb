package com.mutx163.qingyu.core

/**
 * 宽屏三档判据的纯数学内核（Compose 接线在 composeP1 的 components/QingyuAdaptive.kt，
 * 那边不含任何数值，本文件是断点与限宽值的**唯一事实源**）。
 *
 * ## 数值出处（照抄官方 demo，不发明新刻度）
 *
 * 官方 `utils/AdaptiveUtils.kt:12-21`（`shouldShowSplitPane`）：
 * `widthDp >= 840.dp || (widthDp >= 600.dp && 高宽比 < 1.2)`。三档划分见
 * `docs/plans/2026-11-03-compose-widescreen-adaptive-plan.md`：
 *
 * - **紧凑**：宽 < 600dp（手机竖屏），行为与宽屏适配落地前完全一致；
 * - **中宽**：宽 ≥ 600dp 且不满足宽屏条件（平板竖屏、折叠屏内屏竖持），单列限宽居中；
 * - **宽屏**：宽 ≥ 840dp，或宽 ≥ 600dp 且「高宽比 < 1.2」的横扁窗口。
 *
 * 断点是**窗口宽度**，不是设备型号：折叠屏展开、桌面分屏、平板横竖屏都自然工作。
 * 判据放在 core/（而非 components/）是因为 L0 轻量单测只收 main 源集的纯 Kotlin 目录，
 * composeP1 进不了 JVM classpath——判据是纯数学，落在这里才能被每个域的 L0 直接钉住。
 *
 * ## 纯 Kotlin 纪律
 *
 * 本文件不得 import android.* / androidx.compose.*（test-kotlin-module.ps1 的判定是
 * 「整目录只要有一个 .kt 引 Android 依赖就跳过」，一旦混入，全队每个域的 L0 都会
 * 静默少编 core/）。宽度单位一律用 dp 数值（Float），Dp 类型留给 Compose 侧换算。
 */
object QingyuAdaptiveRules {

    /** 宽屏档的最小窗口宽（dp）。 */
    const val WIDE_MIN_WIDTH_DP = 840f

    /** 中宽档（内容列限宽居中）的最小窗口宽（dp）。 */
    const val MEDIUM_WIDE_MIN_WIDTH_DP = 600f

    /** 宽屏判据里的「横扁」阈值：高宽比**严格低于**它视为横扁窗口（demo 原判据）。 */
    const val WIDE_MAX_HEIGHT_RATIO = 1.2f

    /**
     * 中宽/宽档的内容列上限（dp）。方案文档 2026-11-03 的推荐值，本批落地默认打开。
     *
     * 与 demo「宽屏不限制内容宽度」的取向有一处**有理由的偏离**：demo 的宽屏把导航
     * 挪到左侧 Rail 之后内容仍通栏；本项目 Rail 属壳层批次、本批未落地，宽档窗口
     * （≥840dp）里一根通栏单列文字行不可读，所以宽档同样限宽。Rail 批次落地后由
     * Lead 复核是否放宽。
     */
    const val DEFAULT_MAX_CONTENT_WIDTH_DP = 640f

    /**
     * 宽屏判据（= demo `shouldShowSplitPane`）：
     * 宽 ≥ 840dp，或宽 ≥ 600dp 且高宽比 < 1.2 的横扁窗口。
     *
     * 除零安全：宽为 0 时高宽比按 Float 除法得 Infinity，不满足 < 1.2，返回 false。
     */
    fun isWideScreen(widthDp: Float, heightDp: Float): Boolean =
        widthDp >= WIDE_MIN_WIDTH_DP ||
            (widthDp >= MEDIUM_WIDE_MIN_WIDTH_DP && heightDp / widthDp < WIDE_MAX_HEIGHT_RATIO)

    /** 内容列是否限宽居中：中宽与宽档都限（640dp），紧凑档保持通栏（现状）。 */
    fun shouldLimitContentWidth(widthDp: Float): Boolean = widthDp >= MEDIUM_WIDE_MIN_WIDTH_DP
}
