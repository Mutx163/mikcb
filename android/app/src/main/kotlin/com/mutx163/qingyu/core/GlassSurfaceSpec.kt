package com.mutx163.qingyu.core

/**
 * 全站玻璃表面的**统一参数语义**。
 *
 * ## 为什么要有这一层（2026-11-03）
 *
 * 用户反馈「同一个参数在两处看起来两个效果」。盘点后根因有四条：
 * 各处自己对参数做缩放/夹取、压色底不同、采样层不同、能力补齐不同。
 *
 * 本层只做一件事：把「用户旋钮」[GlassTuning] 归一成渲染口径 [GlassSpec]，
 * 且**签名里没有任何表面维度** —— 同一份 tuning 在任何表面必须得到逐字段相同的
 * spec（JVM 单测钉死）。形状差异（药丸 / 大卡 / 通栏）只允许在几何适配层处理，
 * 不允许改动 spec 里的 band / amount / sigma。
 *
 * ## 量程统一
 *
 * 所有表面共用 [GlassSpecLimits]：模糊 σ 0..40dp、染色 0..1、rim 0..1、
 * 折射带 0..24dp、折射位移 0..24dp、色散 0..1。卡片域此前有 24dp 的专属上限，
 * 属于「一个参数两个解释」，迁移时一并归到统一量程（预糊成本由共享层一次录制承担）。
 */
data class GlassTuning(
    /** 模糊强度 σ（dp）。0 = 不糊，只做压色。 */
    val blurSigmaDp: Float = 15f,
    /** 压色 alpha（0..1），压在 [GlassSpec.tintAlpha] 对应的底色上。 */
    val tintAlpha: Float = 0.70f,
    /** 鲜活度（饱和度倍数）。1 = 原样，0 = 关闭这一步。 */
    val vibrancy: Float = 1.5f,
    /** 边缘高光强度（0..1）。0 = 不画高光。 */
    val rimStrength: Float = 0.2f,
    /** 边缘高光宽度（dp）。 */
    val rimWidthDp: Float = 1f,
    /** 折射作用带宽度（dp）。 */
    val refractionBandDp: Float = 11f,
    /** 折射位移量（dp）。 */
    val refractionAmountDp: Float = 8f,
    /** 色散强度（0..1）。0 = 走无色散着色器。 */
    val dispersion: Float = 0.35f,
)

object GlassSpecLimits {
    const val BlurSigmaMinDp = 0f
    const val BlurSigmaMaxDp = 40f
    const val RefractionBandMaxDp = 24f
    const val RefractionAmountMaxDp = 24f
    const val RimWidthMaxDp = 4f
}

/** 渲染层照单执行的玻璃口径。与「是哪一处玻璃表面」无关。 */
data class GlassSpec(
    val blurSigmaDp: Float,
    val tintAlpha: Float,
    val vibrancy: Float,
    val rimStrength: Float,
    val rimWidthDp: Float,
    val refractionBandDp: Float,
    val refractionAmountDp: Float,
    val dispersion: Float,
)

object GlassSpecResolver {

    /**
     * 键 → 统一 spec。纯函数：同一 [tuning] 恒得同一输出，不读任何表面上下文。
     */
    fun resolve(tuning: GlassTuning): GlassSpec = GlassSpec(
        blurSigmaDp = tuning.blurSigmaDp.coerceIn(
            GlassSpecLimits.BlurSigmaMinDp,
            GlassSpecLimits.BlurSigmaMaxDp,
        ),
        tintAlpha = tuning.tintAlpha.coerceIn(0f, 1f),
        vibrancy = tuning.vibrancy.coerceIn(0f, 2f),
        rimStrength = tuning.rimStrength.coerceIn(0f, 1f),
        rimWidthDp = tuning.rimWidthDp.coerceIn(0f, GlassSpecLimits.RimWidthMaxDp),
        refractionBandDp = tuning.refractionBandDp.coerceIn(0f, GlassSpecLimits.RefractionBandMaxDp),
        refractionAmountDp = tuning.refractionAmountDp.coerceIn(0f, GlassSpecLimits.RefractionAmountMaxDp),
        dispersion = tuning.dispersion.coerceIn(0f, 1f),
    )
}

/**
 * 设置快照 → 各表面的旋钮。**只做字段搬运，不做任何缩放或夹取**。
 *
 * 缩放/夹取统一交给 [GlassSpecResolver.resolve]，这样「参数在哪儿被改过」永远只有一处。
 */
fun HomeMaterialRenderSpec.dockGlassTuning(): GlassTuning = GlassTuning(
    blurSigmaDp = liquidBlurSigma,
    tintAlpha = liquidTintAlpha,
    vibrancy = 1.5f,
    rimStrength = liquidRimStrength,
    rimWidthDp = 1f,
    refractionBandDp = liquidRefractionBand,
    refractionAmountDp = liquidRefraction,
    dispersion = liquidDispersion,
)

fun HomeMaterialRenderSpec.bandGlassTuning(): GlassTuning = dockGlassTuning()

fun HomeMaterialRenderSpec.courseCardGlassTuning(): GlassTuning = GlassTuning(
    blurSigmaDp = courseCardBlurSigma,
    tintAlpha = courseCardTintAlpha,
    vibrancy = 1.5f,
    rimStrength = 0.2f,
    rimWidthDp = 1f,
    refractionBandDp = courseCardRefractionBand,
    refractionAmountDp = courseCardRefraction,
    dispersion = courseCardDispersion,
)
