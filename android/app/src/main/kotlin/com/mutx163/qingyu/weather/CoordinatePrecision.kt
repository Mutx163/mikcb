package com.mutx163.qingyu.weather

/**
 * Dart `lib/utils/coordinate_precision.dart` 的移植（泳道 D · 业务族 8 天气/壁纸）。
 *
 * 经纬度的统一精度：小数点后 2 位（赤道附近约 1.1 公里）。
 *
 * 同一个取整口径在 Dart 侧三层共用（services 出网 / providers 比对 / models
 * WeatherLocation.coarsened）；Kotlin 侧同样作为横切层住在本包顶部，谁都能依赖。
 *
 * 四舍五入口径与 Dart `num.round()` 一致：半远离零（0.5 → 1，-0.5 → -1）。
 * Dart 的 `roundToDouble()` 是「half away from zero」，JVM 的 `Math.rint` 是
 * 「half to even」，在 x.xx5 这类值上两者会分叉，所以这里显式实现。
 */
fun coarsenCoordinate(value: Double): Double {
    val scaled = value * 100.0
    val rounded = if (scaled >= 0) Math.floor(scaled + 0.5) else Math.ceil(scaled - 0.5)
    return rounded / 100.0
}
