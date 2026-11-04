package com.mutx163.qingyu.pages.timetable

import androidx.compose.animation.core.Easing
import kotlin.math.roundToInt

/**
 * 首页「周视图 ↔ 日视图」切换的时长 / 曲线 / 降级判据（对齐已发布 2141 / tag v2.1.4.1）。
 *
 * ## 2141 的真实做法（`lib/screens/timetable_screen.dart` 4157-4245）
 *
 * - **周网格**：`Opacity = 1 - controller.value`（随展开淡出，原始 value，不缓动）。
 * - **日面板一整块**：`AnimatedBuilder` 上 `progress = easeInOutCubicEmphasized(value)`，
 *   `widthFactor = 0.18 + 0.82*progress`、`heightFactor = max(0.04, progress)`、
 *   `translateY = (1-progress)*(-24)`、`opacity = easeOutCubic(progress)`、
 *   圆角 = `anchorExpandRadius(progress)`（起始圆角 → 落定方角）；
 *   外层 `Align(top, anchorX)+widthFactor/heightFactor` + `ClipRRect` + `Transform.translate`。
 * - **时长 360ms**、曲线 `easeInOutCubicEmphasized`。**无逐卡飞行、无窗口裁切**。
 *
 * 本文件只放**纯函数/纯常量**（时长、曲线、降级判据），渲染在 `TimetableWeekPage`。
 */
object HomeViewExpandMotion {
    /** 基准时长 360ms（2141）。按用户「页面转场速度」倍率缩放。 */
    const val BASE_MILLISECONDS = 360
}

/** 实际时长：360ms ÷ 用户倍率（倍率区间 0.5~2.5，夹紧后算，避免 0/负把时长打成 0）。 */
fun homeViewExpandDurationMillis(speed: Double): Int {
    val clamped = speed.coerceIn(0.5, 2.5)
    return (HomeViewExpandMotion.BASE_MILLISECONDS / clamped).roundToInt().coerceAtLeast(1)
}

/**
 * 「减少动画」降级判据：系统「动画时长缩放」归零时不播逐帧形变，直接落定 1/0。
 * Android 侧取值（`Settings.Global.ANIMATOR_DURATION_SCALE`）在渲染层；本文件保持纯函数可测。
 */
fun homeViewExpandReducedMotion(animatorDurationScale: Float): Boolean = animatorDurationScale <= 0f

/** 圆角收束带：2141 圆角全程保持 28dp，只在贴边最后 0.2%（progress→1）才收平成方角。 */
const val HOME_VIEW_EXPAND_CORNER_SETTLE_BAND = 0.002f

/**
 * 圆角收束因子（0..1）：2141 `anchorExpandRadius` 口径——progress 未到 `1-band` 前恒为 1（圆角保持 28dp），
 * 仅贴边最后 `band` 段线性收平到 0。**不要用 `28*(1-progress)` 线性收**（圆角会过半就消失，
 * 正是 Dart `hyperos_navigation.dart:131-137` 记录的被否做法）。
 */
fun homeViewExpandCornerRadiusFactor(progress: Float): Float =
    ((1f - progress.coerceIn(0f, 1f)) / HOME_VIEW_EXPAND_CORNER_SETTLE_BAND).coerceIn(0f, 1f)

/**
 * `easeOutCubic`（标准三次缓出）：`1-(1-t)^3`。2141 日面板的 opacity 用它。
 */
fun homeViewEaseOutCubic(t: Float): Float {
    val k = t.coerceIn(0f, 1f)
    val inv = 1f - k
    return 1f - inv * inv * inv
}

/**
 * Flutter `Curves.easeInOutCubicEmphasized` —— **ThreePointCubic**（Compose 无内建）。
 *
 * 两条三次贝塞尔在中点 (0.1667, 0.4) 相接：
 * - 段1：(0,0) → 控制点 (0.05,0)、(0.133333,0.06) → 中点 (0.166666,0.4)；
 * - 段2：(0.166666,0.4) → 控制点 (0.208333,0.82)、(0.25,1.0) → (1,1)。
 *
 * 给定 x（0..1）先按 x 反解段内参数 t（二分），再求 y。这样与 Flutter 三点贝塞尔逐点一致，
 * **不要**用单点 `CubicBezierEasing(0.25,0,0.75,1)` 近似（那会前 1/6 就跑完大半个行程）。
 */
val homeViewEaseInOutCubicEmphasized: Easing = ThreePointCubicEasing(
    ax1 = 0.05f, ay1 = 0f,
    bx1 = 0.133333f, by1 = 0.06f,
    midX = 0.166666f, midY = 0.4f,
    ax2 = 0.208333f, ay2 = 0.82f,
    bx2 = 0.25f, by2 = 1f,
)

/**
 * 三点贝塞尔缓动（Flutter `ThreePointCubic`）：两段三次贝塞尔在中点相接，按 x 反解参数。
 */
class ThreePointCubicEasing(
    private val ax1: Float, private val ay1: Float,
    private val bx1: Float, private val by1: Float,
    private val midX: Float, private val midY: Float,
    private val ax2: Float, private val ay2: Float,
    private val bx2: Float, private val by2: Float,
) : Easing {
    override fun transform(fraction: Float): Float {
        val x = fraction.coerceIn(0f, 1f)
        return if (x <= midX) {
            val t = solveT(0f, ax1, bx1, midX, x)
            cubic(0f, ay1, by1, midY, t)
        } else {
            val t = solveT(midX, ax2, bx2, 1f, x)
            cubic(midY, ay2, by2, 1f, t)
        }
    }

    /** 在 [0,1] 上二分求三次贝塞尔 x(t) = target 的参数 t。 */
    private fun solveT(p0: Float, p1: Float, p2: Float, p3: Float, target: Float): Float {
        var lo = 0f
        var hi = 1f
        var t = 0.5f
        repeat(30) {
            t = (lo + hi) * 0.5f
            val xt = cubic(p0, p1, p2, p3, t)
            if (xt < target) lo = t else hi = t
        }
        return t
    }

    private fun cubic(p0: Float, p1: Float, p2: Float, p3: Float, t: Float): Float {
        val u = 1f - t
        return u * u * u * p0 + 3f * u * u * t * p1 + 3f * u * t * t * p2 + t * t * t * p3
    }
}
