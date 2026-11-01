package com.mutx163.qingyu.pages.settings

/**
 * 外观编辑页两条转场的**纯数值契约**（无 Compose / 无 Android，可在 JVM 单测里逐数断言）。
 *
 * 这一页在 Dart 里有两条完全不同的转场，讨论「洞」之前必须先分清：
 *
 * 1. **页面推入 / 弹出的滑动转场**（[NotchMode] / [LeadingCornerNotch]）：
 *    上层页面从右侧滑入时，它的**前缘两角**被裁成圆角 —— 这个缺口就是「洞」。
 *    洞是被覆盖页的像素透上来的，**不补色、不描边**。2026-10-18 用户定案后
 *    **整个裁切被关掉**（`clipLeadingCornersWhileMoving = false`，
 *    `lib/ui/hyperos/hyperos_miuix_spec.dart:813`），所以 Dart 出货形态是**直角、
 *    没有洞**。本模型把两个状态都表达出来，默认值取 Dart 出货态。
 * 2. **本页自己的缩放转场**（[ZOOM_*] / [zoomSnapshotFrame]）：首页整页缩进预览卡、
 *    退出时再长回全屏。它**没有洞**（「暗底挖洞」方案在 2026-09-19 被否，理由见
 *    `.agents/notes/implemented/feature/2026-09-19-home-zoom-transition.md` 第 32 条），
 *    圆角是卡片自身那圈 `屏幕圆角 × scale`。
 *
 * 两条转场的行号都写在常量注释里，改数值前先回 Dart 核对。
 *
 * ## 为什么抽成纯 Kotlin
 *
 * 「洞的半径 / 角点 / 是否补色」「卡片矩形」「退出图源能不能用」都是**数值判据**，
 * 真机只能看个大概，逐数断言必须在 JVM 单测里做（`AppearanceEditorTransitionTest`）。
 * Compose 侧只负责把这些数原样喂给官方 `NavDisplay` / `graphicsLayer`，不再自己算第二份。
 */
object AppearanceEditorTransitionSpec {

    // ── 缩放转场（本页真正的入场 / 退场）────────────────────────────────────

    /**
     * 总时长基数：Dart `HyperosZoomRoute.duration = HyperosMotionPlatform.scaledDuration(400)`
     * （`lib/ui/hyperos/hyperos_zoom_route.dart:52`）。用户「动效速度」设置不在本模型里，
     * 这里只留基数。
     */
    const val ZOOM_DURATION_MS = 400

    /**
     * 「首页缩到位」与「编辑页出场」两段的分界（总进度）：
     * Dart `HyperosZoomRoute.swapPoint = 0.45`（`hyperos_zoom_route.dart:41`）。
     */
    const val SWAP_POINT = 0.45f

    /**
     * 编辑页 chrome（顶部胶囊 / 底部圆钮）开始出场的**线性时间**点：
     * Dart `HyperosZoomRoute.chromeT` 里的 `start = 0.55`（`hyperos_zoom_route.dart:124`）。
     *
     * ⚠️ 它作用在**线性时间**上（经 [linearT] 反解），不是总进度 —— 直接拿总进度取段
     * 会让按钮在 4 帧内从 0 冲到 82%（Dart 注释的 2026-09-25 实测）。
     */
    const val CHROME_START_LINEAR_T = 0.55f

    /** 缩放转场里被覆盖页的压暗上限：Dart `HyperosMiuixNavigation.dimAmount = 0.5`（`:766`）。 */
    const val DIM_AMOUNT = 0.5f

    /**
     * 被覆盖页的视差比例：Dart **有意偏离官方 0.25，取 0**
     * （`hyperos_miuix_spec.dart:754`；理由是每帧位移会让磨砂顶栏整层重新采样）。
     * 官方 miuix 的 `NavTransitions.MiuixDefault` 仍是 0.25 —— 这是已知差距，不改官方件。
     */
    const val COVERED_PARALLAX_FRACTION = 0.0f

    /** 被覆盖页透明度衰减上限：Dart `coveredAlphaFalloff = 0.1`（`hyperos_miuix_spec.dart:757`）。 */
    const val COVERED_ALPHA_FALLOFF = 0.1f

    /** 卡片浮影：Dart `blurRadius: 32`（`settings_appearance_editor.dart:1838`）。 */
    const val CARD_SHADOW_BLUR_DP = 32f

    /** 卡片浮影：Dart `spreadRadius: 2`（同一段）。 */
    const val CARD_SHADOW_SPREAD_DP = 2f

    /** 卡片浮影墨色 `Color(0x66000000)`（`:107`）的 alpha = 0x66 / 255。 */
    const val CARD_SHADOW_ALPHA = 0x66 / 255f

    // ── 屏幕圆角 ────────────────────────────────────────────────────────────

    /**
     * 屏幕圆角兜底值：Dart `kPageCornerRadiusFallbackDp = 28`
     * （`lib/models/page_corner_radius.dart:16`）。
     *
     * 适用于「平台读数拿不到」。⚠️ 平台**明确报告 0** 时不能套这个兜底（那表示这台机器
     * 没有可对齐的屏幕圆角，见该文件 2026-10-18 注释）；Kotlin 侧目前没有平台读数，
     * 所以统一用兜底值，并在报告里列为已知差异。
     */
    const val SCREEN_CORNER_FALLBACK_DP = 28f

    // ── 前缘圆角「洞」───────────────────────────────────────────────────────

    /**
     * Dart **出货态**的洞开关：`HyperosMiuixNavigation.clipLeadingCornersWhileMoving = false`
     * （`lib/ui/hyperos/hyperos_miuix_spec.dart:813`，2026-10-18 第十八轮用户定案）。
     *
     * 这句话的意思是：页面在转场全程是**完整矩形**，不挖洞、不补色、不画边。
     * 洞的几何仍然保留在 [LeadingCornerNotch] 里，为了两件事：
     * ① 预览区可以把「历史形态」按官方 `NavDisplayEffects` 真实演一遍；
     * ② 将来若要重开（改成把圆角画进页面自己的背景，而不是挖洞），半径与角点口径已经钉住。
     */
    const val NOTCH_SHIPPED_ENABLED = false

    /**
     * 预览区演示用的洞形态：**开**。
     *
     * 与 [NOTCH_SHIPPED_ENABLED] 故意不同：出货态没有洞，而用户要求「能真实演示这套
     * 转场的缩尺预览」，所以演示把官方前缘圆角开出来，让人看见洞是怎么被上层页面挖出来的。
     * 改成 `false` 即与 Dart 出货观感完全一致。
     */
    const val NOTCH_PREVIEW_ENABLED = true

    /** 洞**永不补色**：Dart 两轮补色（深色定值 / 页面底色）都被真机否掉（`hyperos_miuix_spec.dart:776-789`）。 */
    val NOTCH_FILL_ARGB: Int? = null

    /** 洞**永不描边**：Dart 的「前缘细线」随圆角一起撤掉（`hyperos_miuix_spec.dart:801-802`）。 */
    const val NOTCH_STROKE_DP = 0f

    // ── 时间曲线（逐条对应 Dart）─────────────────────────────────────────────

    /**
     * 原始动画值 → 总进度（0→1）：`Curves.easeInOutCubic`，即
     * `Cubic(0.645, 0.045, 0.355, 1.0)`（`hyperos_zoom_route.dart:55`）。
     */
    fun progress(t: Float): Float = cubicBezierYForX(
        t = t.coerceIn(0f, 1f),
        p1x = 0.645f,
        p1y = 0.045f,
        p2x = 0.355f,
        p2y = 1f,
    )

    /**
     * 总进度 → 原始动画值（[progress] 的数值逆）。
     *
     * 与 Dart 同构：Bézier 没有解析逆，走二分；端点直接短路（`chromeT(1)` 必须**精确**
     * 是 1，否则落定后按钮停在 0.9999 会被「没显全」的回归抓到）。
     */
    fun linearT(p: Float): Float {
        val target = p.coerceIn(0f, 1f)
        if (target <= 0f) return 0f
        if (target >= 1f) return 1f
        var lo = 0f
        var hi = 1f
        repeat(30) {
            val mid = (lo + hi) / 2f
            if (progress(mid) < target) lo = mid else hi = mid
        }
        return (lo + hi) / 2f
    }

    /**
     * 首页缩小段进度（0→1，超过 [SWAP_POINT] 后恒为 1）：
     * `Curves.easeOutCubic` 整形（`hyperos_zoom_route.dart:101-102`），
     * 让缩停在落点处速度归零，不「顿一下」。
     */
    fun shrinkT(p: Float): Float = cubicBezierYForX(
        t = (p.coerceIn(0f, 1f) / SWAP_POINT).coerceIn(0f, 1f),
        p1x = 0.215f,
        p1y = 0.61f,
        p2x = 0.355f,
        p2y = 1f,
    )

    /** 编辑页出场段进度（0→1，[SWAP_POINT] 之前恒为 0）：`hyperos_zoom_route.dart:105`。 */
    fun growT(p: Float): Float =
        ((p.coerceIn(0f, 1f) - SWAP_POINT) / (1f - SWAP_POINT)).coerceIn(0f, 1f)

    /**
     * chrome 出场进度：**线性时间**上从 [CHROME_START_LINEAR_T] 起、到 1 收满
     * （`hyperos_zoom_route.dart:119-126`）。
     */
    fun chromeT(p: Float): Float =
        ((linearT(p) - CHROME_START_LINEAR_T) / (1f - CHROME_START_LINEAR_T))
            .coerceIn(0f, 1f)

    /**
     * 卡片是否已经出场：Dart 用**阶跃** `growT(p) > 0`（`settings_appearance_editor.dart:1738`），
     * 不是淡入 —— 卡片与首页快照在切换那一帧是同一张图、位置逐像素重合，淡入反而会暗一下。
     */
    fun cardVisible(p: Float): Boolean = growT(p) > 0f

    /** 卡片浮影不透明度：跟着暗底（`growT`）一起长，不跟卡片阶跃（`:1834-1837`）。 */
    fun cardShadowAlpha(p: Float): Float = CARD_SHADOW_ALPHA * growT(p)

    /**
     * 「完成」退出时能不能发布新观感图（`hyperosZoomExitSource`）：
     * 有烤图 **且** 缩尺预览的视图与首页当前视图一致
     * （`settings_appearance_editor.dart:751-762`）。任何一条不满足就退回进页快照。
     */
    fun exitSourceEligible(
        hasPreviewImage: Boolean,
        previewDayView: Boolean,
        homeDayView: Boolean,
    ): Boolean = hasPreviewImage && previewDayView == homeDayView

    /**
     * 预览卡里那个缩尺洞的半径 = 屏幕圆角 × 缩放比。
     *
     * 缩放转场里首页快照的圆角也是「屏幕圆角 → 落点圆角」按 `shrinkT` 插值
     * （`hyperos_zoom_route.dart:475-481`）；预览卡是同一台机器的同一屏，所以半径同比收小。
     */
    fun previewNotchRadiusDp(deviceCornerRadiusDp: Float, scale: Float): Float =
        deviceCornerRadiusDp.coerceAtLeast(0f) * scale.coerceAtLeast(0f)

    // ── 数值工具 ────────────────────────────────────────────────────────────

    /**
     * 三次 Bézier 的 y(x)：先二分求参数 s 使 x(s)=t，再取 y(s)。
     *
     * 与 Flutter `Curves.easeInOutCubic` 同一条曲线；二分 30 次在 [0,1] 上足够
     * （Dart 的 `linearT` 也是同一套写法）。
     */
    internal fun cubicBezierYForX(
        t: Float,
        p1x: Float,
        p1y: Float,
        p2x: Float,
        p2y: Float,
    ): Float {
        if (t <= 0f) return 0f
        if (t >= 1f) return 1f
        var lo = 0f
        var hi = 1f
        var s = t
        repeat(30) {
            s = (lo + hi) / 2f
            val x = bezier(s, p1x, p2x)
            if (x < t) lo = s else hi = s
        }
        return bezier(s, p1y, p2y)
    }

    /** 一维三次 Bézier（端点 0 / 1）。 */
    private fun bezier(s: Float, p1: Float, p2: Float): Float {
        val u = 1f - s
        return 3f * u * u * s * p1 + 3f * u * s * s * p2 + s * s * s
    }
}

/**
 * 前缘圆角的形态。
 *
 * [Disabled] 是 Dart **出货态**（直角、无洞）；[LeadingCorners] 是官方 miuix
 * `NavDisplayEffects` 的 `NavCornerClipMode.Leading` 口径，也是预览演示用的形态。
 */
enum class NotchMode { Disabled, LeadingCorners }

/** 洞的补色策略。当前**只有** [None]：补色两次都被真机否掉，见 `hyperos_miuix_spec.dart:776-789`。 */
enum class NotchFill { None }

/**
 * 上层页面在「上一屏」上挖出的那个洞（= 前缘两角的圆角切口）。
 *
 * 坐标系：页面局部坐标，原点在屏幕左上角，单位 dp。`enterProgress` 是滑动转场的
 * 原始动画值（0 = 完全在屏外，1 = 已停稳），不是缓动后的进度。
 *
 * 洞**不是**一个独立绘制的矩形：它是上层页面被 `ClipRRect` 裁掉的部分，露出的是
 * 被覆盖页自己的像素（同一层、同一条压暗公式），所以天然逐帧同色。
 */
data class LeadingCornerNotch(
    /** 是否真的裁圆角（= 洞是否存在）。 */
    val enabled: Boolean,
    /** 圆角半径。**恒定**，转场全程不随进度变（见 `hyperos_miuix_spec.dart:815-820`）。 */
    val radiusDp: Float,
    val topLeftRadiusDp: Float,
    val topRightRadiusDp: Float,
    val bottomRightRadiusDp: Float,
    val bottomLeftRadiusDp: Float,
    /** 上层页面前缘（LTR = 左边，RTL = 右边）在屏幕上的 x。 */
    val leadingEdgeXDp: Float,
    /** 洞的横向范围（与页面同侧）。 */
    val holeLeftDp: Float,
    val holeRightDp: Float,
    /** 洞的纵向范围：上角 `[0, radius]`、下角 `[height - radius, height]`。 */
    val holeTopDp: Float,
    val holeBottomDp: Float,
    /** 补色策略：恒 [NotchFill.None]。 */
    val fill: NotchFill,
    /** 描边宽度：恒 0。 */
    val strokeDp: Float,
    /** 此刻洞是否可见（只在移动中；停稳后页面贴边，洞与机身圆角重合）。 */
    val visible: Boolean,
) {
    /** 洞的宽度 = 圆角半径。 */
    val holeWidthDp: Float get() = radiusDp

    /** 洞的补色：恒为 null（不补）。 */
    val fillArgb: Int? get() = AppearanceEditorTransitionSpec.NOTCH_FILL_ARGB
}

/**
 * 算一次滑动转场的洞几何（逐行对应 `lib/ui/hyperos/hyperos_navigation.dart:424-533`
 * 与 `_MiuixNavClippedPage`，`:700-724`）。
 *
 * * 半径 = 设备屏幕圆角，**全程恒定**；[NotchMode.Disabled] 时为 0；
 * * 只裁**正在滑入的栈顶页**的前缘两角；被覆盖页**不裁** —— 两层洞对齐会直接
 *   看穿到窗口黑底（`hyperos_navigation.dart:706-708` 的第十轮真机截图）；
 * * 不补色、不描边；
 * * 停稳（`enterProgress == 1`）后裁切关闭 —— 官方 miuix 的判据是 `-1 < d < 0`
 *   （`NavDisplayEffects.shouldClipCornersAt`）。
 *
 * @param enterProgress 原始动画值，0 = 屏外、1 = 停稳。
 * @param screenWidthDp / screenHeightDp 转场容器尺寸（预览区里就是缩尺后的一屏）。
 * @param deviceCornerRadiusDp 设备屏幕圆角；平台明确报 0 时传 0（不要套兜底）。
 * @param isRtl RTL 时前缘在右侧，整体镜像。
 * @param mode 洞形态（出货态默认 [AppearanceEditorTransitionSpec.NOTCH_SHIPPED_ENABLED]）。
 */
fun leadingCornerNotch(
    enterProgress: Float,
    screenWidthDp: Float,
    screenHeightDp: Float,
    deviceCornerRadiusDp: Float,
    isRtl: Boolean = false,
    mode: NotchMode = if (AppearanceEditorTransitionSpec.NOTCH_SHIPPED_ENABLED) {
        NotchMode.LeadingCorners
    } else {
        NotchMode.Disabled
    },
): LeadingCornerNotch {
    val t = enterProgress.coerceIn(0f, 1f)
    val width = screenWidthDp.coerceAtLeast(0f)
    val height = screenHeightDp.coerceAtLeast(0f)
    val enabled = mode == NotchMode.LeadingCorners
    val radius = if (enabled) deviceCornerRadiusDp.coerceAtLeast(0f) else 0f
    val offset = (1f - t) * width
    val leadingEdge = if (isRtl) width - offset else offset
    val holeLeft = if (isRtl) leadingEdge - radius else leadingEdge
    val holeRight = if (isRtl) leadingEdge else leadingEdge + radius
    val leftRadius = if (isRtl) 0f else radius
    val rightRadius = if (isRtl) radius else 0f
    return LeadingCornerNotch(
        enabled = enabled,
        radiusDp = radius,
        topLeftRadiusDp = leftRadius,
        topRightRadiusDp = rightRadius,
        bottomRightRadiusDp = rightRadius,
        bottomLeftRadiusDp = leftRadius,
        leadingEdgeXDp = leadingEdge,
        holeLeftDp = holeLeft,
        holeRightDp = holeRight,
        holeTopDp = 0f,
        holeBottomDp = height,
        fill = NotchFill.None,
        strokeDp = AppearanceEditorTransitionSpec.NOTCH_STROKE_DP,
        visible = enabled && t > 0f && t < 1f,
    )
}

// ───────────────────────────────────────────── 预览卡几何（B3 / B4）

/** 预览卡的落点矩形（纯 dp）。字段与 Dart `LayoutBuilder` 里的局部变量一一对应（`:1617-1650`）。 */
data class AppearanceEditorCardBox(
    val scale: Float,
    val cardWidthDp: Float,
    val cardHeightDp: Float,
    val cardLeftDp: Float,
    val cardTopDp: Float,
    val radiusDp: Float,
    val topReserveDp: Float,
    val bottomReserveDp: Float,
    val availableHeightDp: Float,
)

object AppearanceEditorCardGeometrySpec {
    /** 卡片相对可用宽度的上限：Dart `_cardMaxWidthFactor = 0.86`（`:109-114`）。 */
    const val CARD_MAX_WIDTH_FACTOR = 0.86f

    /** 顶部净空扣除项：Dart `16 + 40 + 18`（`:1624`）。 */
    const val TOP_CHROME_RESERVE_DP = 16f + 40f + 18f

    /** 底部净空扣除项：Dart `24 + 56 + 8 + 18`（`:1625`）。 */
    const val BOTTOM_CHROME_RESERVE_DP = 24f + 56f + 8f + 18f

    /** 卡片可用高度下限：Dart `.clamp(120.0, double.infinity)`（`:1628`）。 */
    const val MIN_BAND_HEIGHT_DP = 120f
}

/**
 * 按 Dart 的几何公式算卡片矩形（`settings_appearance_editor.dart:1617-1650` 逐行对应）。
 *
 * 公式里**没有任何手工修正项**：Dart 明确撤掉了「视觉重心」偏移（`:1643-1646`）。
 */
fun appearanceEditorCardBox(
    areaWidthDp: Float,
    areaHeightDp: Float,
    screenWidthDp: Float,
    screenHeightDp: Float,
    topInsetDp: Float,
    bottomInsetDp: Float,
    screenCornerRadiusDp: Float = AppearanceEditorTransitionSpec.SCREEN_CORNER_FALLBACK_DP,
): AppearanceEditorCardBox {
    val topReserve = topInsetDp + AppearanceEditorCardGeometrySpec.TOP_CHROME_RESERVE_DP
    val bottomReserve = bottomInsetDp + AppearanceEditorCardGeometrySpec.BOTTOM_CHROME_RESERVE_DP
    val availableHeight = (areaHeightDp - topReserve - bottomReserve)
        .coerceAtLeast(AppearanceEditorCardGeometrySpec.MIN_BAND_HEIGHT_DP)
    val availableWidth = areaWidthDp * AppearanceEditorCardGeometrySpec.CARD_MAX_WIDTH_FACTOR
    val widthScale = if (screenWidthDp > 0f) availableWidth / screenWidthDp else 0f
    val heightScale = if (screenHeightDp > 0f) availableHeight / screenHeightDp else 0f
    val scale = minOf(widthScale, heightScale)
    val cardWidth = screenWidthDp * scale
    val cardHeight = screenHeightDp * scale
    val radius = minOf(screenCornerRadiusDp * scale, cardHeight / 2f)
    val cardCenterY = topReserve + availableHeight / 2f
    return AppearanceEditorCardBox(
        scale = scale,
        cardWidthDp = cardWidth,
        cardHeightDp = cardHeight,
        cardLeftDp = (areaWidthDp - cardWidth) / 2f,
        cardTopDp = cardCenterY - cardHeight / 2f,
        radiusDp = radius,
        topReserveDp = topReserve,
        bottomReserveDp = bottomReserve,
        availableHeightDp = availableHeight,
    )
}

// ───────────────────────────────────────────── 缩放转场的首页快照帧

/**
 * 首页快照在某一进度上的矩形与圆角（`hyperos_zoom_route.dart:447-493` 的纯数值部分）。
 *
 * * 矩形：整屏矩形 → 落点矩形，按 [AppearanceEditorTransitionSpec.shrinkT] 插值；
 * * 圆角：**从屏幕圆角起**（不是 0）与矩形同步收到落点圆角
 *   （`hyperos_zoom_route.dart:462-481` 的 2026-09-22 用户口径）；
 * * [clipRadiusBeforeScaleDp] 是 `ClipRRect` 在 **Transform 内层**时该用的半径
 *   （= 显示半径 / 横向缩放比），否则圆角会跟着变换再收一次。
 */
data class ZoomSnapshotFrame(
    val leftDp: Float,
    val topDp: Float,
    val widthDp: Float,
    val heightDp: Float,
    val radiusDp: Float,
    val clipRadiusBeforeScaleDp: Float,
)

/**
 * 算首页快照在 [progress]（总进度 0→1）时的帧。
 *
 * @param landing 预览卡落点（[appearanceEditorCardBox] 的结果）。
 * @param deviceCornerRadiusDp 屏幕圆角；平台明确报 0 时传 0。
 */
fun zoomSnapshotFrame(
    progress: Float,
    screenWidthDp: Float,
    screenHeightDp: Float,
    landing: AppearanceEditorCardBox,
    deviceCornerRadiusDp: Float = AppearanceEditorTransitionSpec.SCREEN_CORNER_FALLBACK_DP,
): ZoomSnapshotFrame {
    val landT = AppearanceEditorTransitionSpec.shrinkT(progress)
    val targetLeft = lerp(0f, landing.cardLeftDp, landT)
    val targetTop = lerp(0f, landing.cardTopDp, landT)
    val targetWidth = lerp(screenWidthDp, landing.cardWidthDp, landT)
    val targetHeight = lerp(screenHeightDp, landing.cardHeightDp, landT)
    val startRadius = minOf(
        deviceCornerRadiusDp.coerceAtLeast(0f),
        minOf(screenWidthDp, screenHeightDp).coerceAtLeast(0f) / 2f,
    )
    val radius = lerp(startRadius, landing.radiusDp, landT)
    val sx = if (screenWidthDp > 0f) targetWidth / screenWidthDp else 1f
    return ZoomSnapshotFrame(
        leftDp = targetLeft,
        topDp = targetTop,
        widthDp = targetWidth,
        heightDp = targetHeight,
        radiusDp = radius,
        clipRadiusBeforeScaleDp = if (sx > 0f) radius / sx else 0f,
    )
}

// ───────────────────────────────────────────── 入场 / 退场的缩放与分层出场
//
// 这一层与上面两条转场都不是同一件事：
// * [NotchMode] 那套是「页面推入」的滑动转场；
// * [zoomSnapshotFrame] 那套是首页缩进卡片时**快照**的帧；
// * 这里这套是**本页自己的**入场 / 退场：整屏内容缩成卡片、上下 chrome 分层归位。
//   这套时间线写在页面内部（卡片缩放 380ms、顶栏 1.5→1、底部工具淡入 /
//   上移 80dp / 模糊 8→0），与导航路由无关；我们照同一套数值复刻成纯函数，
//   Compose 侧只负责把值喂给 `graphicsLayer`，不再自己算第二份。

/**
 * 入场 / 退场时间线的数值契约。
 *
 * 缓动是一条三次 Bézier `(0.3, 0.5, 0.2, 1.0)`：前段很快、后段慢慢收尾
 * （半程就已走完约 89%）。三条动画共用这条曲线，只是目标值不同，所以「分层」来自
 * 各层起止值的差异，而不是各自再挂一条不同的缓动。
 */
object AppearanceEditorEntranceSpec {

    /** 入场总时长（毫秒）：卡片缩放 / 顶栏归位 / 底部工具归位共用。 */
    const val ENTER_DURATION_MS = 380

    /** 退场总时长（毫秒）：卡片长回整屏、顶栏放大离场、底部工具退走。 */
    const val EXIT_DURATION_MS = 500

    /** 顶栏出场时的起始缩放（1.5 → 1，绕整屏中心缩放，看起来从屏幕上方压进来）。 */
    const val TOP_CHROME_START_SCALE = 1.5f

    /** 底部工具起始纵向位移（80dp → 0，自下而上归位）。 */
    const val BOTTOM_CHROME_SLIDE_DP = 80f

    /** 底部工具起始模糊半径（8dp → 0，归位过程中逐渐对焦）。 */
    const val BOTTOM_CHROME_START_BLUR_DP = 8f

    /**
     * 统一的缓动：三次 Bézier (0.3, 0.5, 0.2, 1.0)。
     *
     * 端点精确（0 → 0、1 → 1）：落定帧必须是 1，否则卡片停在 0.999 的缩放上、
     * 与真实卡片差半个像素，截图对比会被抓出来。
     */
    fun eased(t: Float): Float = AppearanceEditorTransitionSpec.cubicBezierYForX(
        t = t.coerceIn(0f, 1f),
        p1x = 0.3f,
        p1y = 0.5f,
        p2x = 0.2f,
        p2y = 1f,
    )

    /** 顶栏缩放：1.5 → 1。 */
    fun topChromeScale(t: Float): Float =
        lerp(TOP_CHROME_START_SCALE, 1f, eased(t))

    /** 底部工具不透明度：0 → 1。 */
    fun bottomChromeAlpha(t: Float): Float = eased(t)

    /** 底部工具纵向位移：80dp → 0。 */
    fun bottomChromeOffsetDp(t: Float): Float =
        BOTTOM_CHROME_SLIDE_DP * (1f - eased(t))

    /** 底部工具模糊半径：8dp → 0。 */
    fun bottomChromeBlurDp(t: Float): Float =
        BOTTOM_CHROME_START_BLUR_DP * (1f - eased(t))
}

/**
 * 入场 / 退场某一片刻的整页状态（纯 dp / 无单位）。
 *
 * 约定 [progress]：0 = 整屏铺开（卡片还没缩进来），1 = 卡片落到 [appearanceEditorCardBox]
 * 的落点。**入场**从 0 跑到 1，**退场**从 1 跑回 0，所以复刻退场不需要第二套公式。
 */
data class AppearanceEditorEntranceFrame(
    /** 卡片**绘制**矩形的左边 / 上边（整屏→落点插值）。 */
    val cardLeftDp: Float,
    val cardTopDp: Float,
    /** 卡片绘制矩形的宽高。 */
    val cardWidthDp: Float,
    val cardHeightDp: Float,
    /**
     * 相对**落点容器**的绘制缩放：容器始终按落点尺寸布局，只把这个缩放交给
     * `graphicsLayer`，子树不会再被重新 measure。
     */
    val cardDrawScale: Float,
    /** 绘制后的圆角（= 落点圆角 × 绘制缩放；起点正好回到屏幕圆角）。 */
    val cardRadiusDp: Float,
    /** 顶栏缩放（1.5 → 1）。 */
    val topChromeScale: Float,
    /** 底部工具不透明度（0 → 1）。 */
    val bottomChromeAlpha: Float,
    /** 底部工具纵向位移（80dp → 0）。 */
    val bottomChromeOffsetDp: Float,
    /** 底部工具模糊半径（8dp → 0）。 */
    val bottomChromeBlurDp: Float,
    /** 缓动后的进度（0..1），给不透明度和「是否落定」用。 */
    val easedFraction: Float,
) {
    /** 是否已经落定（缓动值精确到 1）。 */
    val settled: Boolean get() = easedFraction >= 1f
}

/**
 * 算某一进度上的入场 / 退场状态。
 *
 * 卡片矩形从**整屏矩形**插到 [landing]（落点），圆角随绘制缩放一起收小：
 * 起点绘制缩放 = `整屏宽 / 落点宽`，落点圆角乘上它正好回到屏幕圆角，
 * 所以「缩进来」与「长回去」两端都不会出现圆角跳变。
 *
 * @param progress 0 = 整屏，1 = 落定（入场正向、退场反向共用）。
 * @param screenWidthDp / screenHeightDp 整屏逻辑尺寸。
 * @param landing 卡片落点（[appearanceEditorCardBox] 的结果）。
 */
fun appearanceEditorEntranceFrame(
    progress: Float,
    screenWidthDp: Float,
    screenHeightDp: Float,
    landing: AppearanceEditorCardBox,
): AppearanceEditorEntranceFrame {
    val eased = AppearanceEditorEntranceSpec.eased(progress)
    val width = lerp(screenWidthDp, landing.cardWidthDp, eased)
    val height = lerp(screenHeightDp, landing.cardHeightDp, eased)
    val drawScale = if (landing.cardWidthDp > 1e-4f) {
        width / landing.cardWidthDp
    } else {
        1f
    }
    return AppearanceEditorEntranceFrame(
        cardLeftDp = lerp(0f, landing.cardLeftDp, eased),
        cardTopDp = lerp(0f, landing.cardTopDp, eased),
        cardWidthDp = width,
        cardHeightDp = height,
        cardDrawScale = drawScale,
        cardRadiusDp = landing.radiusDp * drawScale,
        topChromeScale = AppearanceEditorEntranceSpec.topChromeScale(progress),
        bottomChromeAlpha = AppearanceEditorEntranceSpec.bottomChromeAlpha(progress),
        bottomChromeOffsetDp = AppearanceEditorEntranceSpec.bottomChromeOffsetDp(progress),
        bottomChromeBlurDp = AppearanceEditorEntranceSpec.bottomChromeBlurDp(progress),
        easedFraction = eased,
    )
}

private fun lerp(start: Float, stop: Float, fraction: Float): Float =
    start + (stop - start) * fraction.coerceIn(0f, 1f)
