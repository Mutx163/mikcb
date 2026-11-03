package com.mutx163.qingyu.core

/**
 * 弹窗玻璃材质配方（2026-11-03 用户批准「改库」）。
 *
 * ## 为什么单独一份纯 Kotlin
 *
 * 玻璃的**数值**必须只有一处：渲染在本地 fork 的 miuix-ui 里
 * （`third_party/miuix-ui/.../layout/DialogContentLayout.kt`），取值在本对象里，
 * 两者靠调用点串起来。这里不 import 任何 Compose / Android 类型，因此能被 JVM 单测直接钉住
 * ——「同一档参数 ⇒ 同一观感」才有可验证的落点。
 *
 * 数值口径对齐 NexioSchedule 的 dialog 档：模糊 24dp、压色亮 0.78 / 暗 0.87、
 * 饱和度增益 1.5、半径 32dp 起。
 *
 * 与玻璃统一线的 `core/GlassSurfaceSpec.kt` 关系：那份是**表面**统一量（坞/顶栏/卡片），
 * 本份是**弹窗**这一档的定值。等弹窗也并进统一层时，本对象整体并入那份（由统一线负责）。
 */
object DialogGlassSpec {

    /**
     * 一键回退开关：`false` = 试点弹窗整条玻璃链不组合，回到官方实心板。
     * 不需要改调用点（调用点判这个开关后传 `glass = null`）。
     */
    @Volatile
    var enabled: Boolean = true

    /** 模糊半径（面板档，dp）。 */
    const val BLUR_RADIUS_DP: Float = 24f

    /** 玻璃层之上的压色 alpha：亮色 0.78 / 深色 0.87（保证文字对比度）。 */
    const val TINT_ALPHA_LIGHT: Float = 0.78f
    const val TINT_ALPHA_DARK: Float = 0.87f

    /** 通透感：饱和度增益（<1 发灰，1 原样）。 */
    const val SATURATION: Float = 1.5f

    /** 圆角：官方贴底档下限 / 居中档默认；容器与玻璃面同值，防漂移。 */
    const val CORNER_RADIUS_DP: Float = 32f

    /** 降级描边宽度（dp）：糊不了时的统一退化形态。 */
    const val FALLBACK_BORDER_WIDTH_DP: Float = 1f

    /** 亮度阈值：与官方 `DialogDefaults` 同口径（0.299R + 0.587G + 0.114B < 0.5 判深色）。 */
    const val DARK_LUMINANCE_THRESHOLD: Float = 0.5f

    /** 压色 alpha：按底色深浅取档。 */
    fun tintAlpha(isDark: Boolean): Float = if (isDark) TINT_ALPHA_DARK else TINT_ALPHA_LIGHT

    /**
     * 深浅判定：只看底色亮度，不看 `isSystemInDarkTheme`（与官方弹窗取色一致——
     * 主题可以是「浅色主题 + 深色系统」，此时弹窗仍按底色判断）。
     *
     * @param argb 底色（`Color.toArgb()` 的产物）。
     */
    fun isDarkBackground(argb: Int): Boolean {
        val r = ((argb shr 16) and 0xFF) / 255f
        val g = ((argb shr 8) and 0xFF) / 255f
        val b = (argb and 0xFF) / 255f
        return 0.299f * r + 0.587f * g + 0.114f * b < DARK_LUMINANCE_THRESHOLD
    }

    /**
     * 实时模糊是否真的能画：既要拿到背景录像带，也要设备支持 `RuntimeShader`。
     * 任一不满足就走「同一档压色 + 描边」的统一降级形态（判定本身在 fork 容器里执行，
     * 这里是同一口径的可测副本，供调用点与守卫对齐）。
     */
    fun canBlur(hasBackdrop: Boolean, runtimeShaderSupported: Boolean): Boolean =
        hasBackdrop && runtimeShaderSupported
}
