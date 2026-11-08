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

    /**
     * Rail 展开态（带文字标签，宽 240dp）的最小窗口宽（dp）。
     * 数值出处：demo `AdaptiveUtils.kt:24-40`（`shouldExpandNavigationRail`）。
     */
    const val EXPANDED_RAIL_MIN_WIDTH_DP = 1200f

    /** Rail 是否用展开态：≥ 1200dp 展开，否则收起（80dp 图标条）。 */
    fun shouldExpandNavigationRail(widthDp: Float): Boolean = widthDp >= EXPANDED_RAIL_MIN_WIDTH_DP

    /**
     * 壳层用：Rail 出现后，页面骨架的自适应按「内容区宽」（窗口宽 − Rail 宽）算——
     * 否则限宽列会对着 Rail 底下的区域居中、顶栏档位也会判错。
     * [railWidthDp] 传 0 = 无 Rail（紧凑档或用户关掉导航形态），此时与按窗口宽算等价。
     */
    fun contentAreaAdaptive(
        windowWidthDp: Float,
        windowHeightDp: Float,
        railWidthDp: Float,
    ): ContentAreaAdaptive {
        val width = windowWidthDp - railWidthDp
        return ContentAreaAdaptive(
            isWideScreen = isWideScreen(width, windowHeightDp),
            limitContentWidth = shouldLimitContentWidth(width),
        )
    }

    /**
     * 短窗口判定线（dp）：窗口高度低于它才放宽弹层限高。
     *
     * 来源是「手机横屏 / 平板分屏 / 桌面自由窗口」的常见高度（360～599dp）。
     * 平板竖屏（≥960dp）与手机竖屏（≥640dp）都在这条线以上，**行为与改造前一致**。
     */
    const val SHORT_WINDOW_MAX_HEIGHT_DP = 600f

    /**
     * 短窗口下给面板「非正文」部分预留的高度（dp）。
     *
     * 账目（都是实测过的固定件）：弹窗标题 ≈ 40 + 动作行 ≈ 52 + 上下外缘 24～32
     * + 状态栏 / 导航栏 ≈ 48。官方 `DialogContentLayout` 在**非大屏**时对高度**不设上限**
     * （`heightIn(max = if (isLargeScreen) … else Dp.Unspecified)`），预留不够就会把
     * 取消 / 确认挤出屏幕。取 180 而不是更小，是因为宁少放大一点也不能裁掉按钮。
     */
    const val SHORT_WINDOW_SHEET_RESERVED_DP = 180f

    /**
     * 弹层正文的限高（dp）= 屏高 × [fraction]，短窗口下放宽为「屏高 − 预留」。
     *
     * 高窗口（≥ [SHORT_WINDOW_MAX_HEIGHT_DP]）**原样返回** `height × fraction`，
     * 保证手机竖屏 / 平板竖屏逐像素不变；矮窗口把正文上限抬到
     * `height − [SHORT_WINDOW_SHEET_RESERVED_DP]`，同时**不小于**原比例算出的值
     * （只放大、不缩小，避免把已有的「矮屏已知债」改得更糟）。
     *
     * 例：h=360、fraction=0.55 → 198（原本就是 198，不动）；
     * h=500、0.55 → 320（原 275）；h=900 → 原比例，与改造前一模一样。
     *
     * 入参非法（高度 / 比例 ≤ 0）返回 0，调用方得到 0dp 即「不额外限高」。
     */
    fun sheetMaxHeightDp(windowHeightDp: Float, fraction: Float): Float {
        if (windowHeightDp <= 0f || fraction <= 0f) return 0f
        val base = windowHeightDp * fraction
        if (windowHeightDp >= SHORT_WINDOW_MAX_HEIGHT_DP) return base
        val relaxed = (windowHeightDp - SHORT_WINDOW_SHEET_RESERVED_DP).coerceAtLeast(0f)
        return maxOf(base, relaxed).coerceAtMost(windowHeightDp)
    }

    /**
     * 把「写死的 dp 上限」夹到矮窗口可用高度：`min(desired, height − 180)`。
     *
     * 用于原本写 `heightIn(max = 380.dp / 420.dp)` 的弹层。锁竖屏时这些值永远碰不到屏幕
     * 边界，解锁后手机横屏 / 分屏只剩 360～500dp 高，420dp 的列表会把取消/确认挤出屏幕。
     * 高窗口原样返回 [desiredDp]，不影响现有观感。
     */
    fun cappedSheetHeightDp(windowHeightDp: Float, desiredDp: Float): Float {
        if (windowHeightDp <= 0f || desiredDp <= 0f) return desiredDp
        if (windowHeightDp >= SHORT_WINDOW_MAX_HEIGHT_DP) return desiredDp
        return minOf(desiredDp, (windowHeightDp - SHORT_WINDOW_SHEET_RESERVED_DP).coerceAtLeast(0f))
    }
}

/** [contentAreaAdaptive] 的结果：给 composeP1 的注入层换算成 [QingyuWindowAdaptive] 同名字段。 */
data class ContentAreaAdaptive(
    val isWideScreen: Boolean,
    val limitContentWidth: Boolean,
)
