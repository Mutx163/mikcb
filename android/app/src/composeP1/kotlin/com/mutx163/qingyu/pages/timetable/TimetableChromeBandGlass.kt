package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.glass.QingyuGlassSurface
import com.mutx163.qingyu.core.GlassSpec
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课表三视图（周 / 日 / 月）共用的**顶栏玻璃带玻璃层**。
 *
 * ## 2026-11-16 重做：不再自己拼 drawBackdrop
 *
 * 用户实测：同一套材质参数，**底栏是完美玻璃、顶栏折射毫无作用**；顶栏模糊拉到 0 直接透明。
 * 根因不是材质，而是顶栏这条**独立实现**采的是一层「只有壁纸」的录像层
 * （`pageBackdrop`），而底栏采的是**真实内容**（卡、字、色块都在里面）——
 * 折射位移作用在纯色壁纸上自然看不出任何变化。
 *
 * 现在顶栏**不再自己拼** `drawBackdrop + vibrancy + blur + lens + 染色`，而是直接调共享件
 * [QingyuGlassSurface]（坞、浮钮、卡片、页面球用的都是它），参数全部来自同一份材质快照：
 *
 * | 量 | 来源 |
 * |---|---|
 * | 模糊 σ | `material.liquidBlurSigma` |
 * | 染色 | `material.liquidTintAlpha`（`MiuixTheme.surface` 压色） |
 * | 折射作用带 / 位移 / 色散 | `material.liquidRefractionBand` / `liquidRefraction` / `liquidDispersion` |
 *
 * 调用方只要把**录了真实内容**的 backdrop 传进来（周页传 `contentBackdrop`），
 * 顶栏就与底栏走同一处实现、同一种采样源。
 *
 * ## 形状与外溢
 *
 * 带子上 / 左 / 右三条边压在屏幕边上，`lens()` 在这些边朝外推会采到画布之外
 * （真机读成一条淡竖边）。[bandGlassOverhang] 把玻璃节点整体推到屏幕外一圈，
 * 于是可见区里只有**底边**在折射——这一层几何仍在，与布局无关（带子尺寸、高度、
 * 内容与交互都不受影响）。
 *
 * @param material 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为。
 * @param hasBackdrop 有没有可用壁纸。没有壁纸时液态档不退化成玻璃（那会模糊空气）。
 * @param backdrop 背景采样源：**必须是录了真实内容的那一层**（周页 `contentBackdrop`）。
 * @param solidColor 无壁纸 / 实体档的页底色（`pageColorArgb` → 色，缺省给主题底）。
 * @param overdrawDp 形状边界要往屏幕外推多少（逻辑 dp）；左右还要叠安全区，那一步在调用方算。
 * @param content 带子里的内容（状态栏留白 / 标题行 / 星期栏 / 月份栏）。
 */
@Composable
fun TimetableChromeBandGlass(
    material: HomeMaterialRenderSpec?,
    hasBackdrop: Boolean,
    backdrop: Backdrop?,
    solidColor: Color,
    overdrawDp: Dp,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val bandSurface = material?.band
    // 液态档 + 真有壁纸 + 设备支持 runtime shader，三件事同时成立才画玻璃。
    val glassBackdrop = backdrop?.takeIf {
        bandSurface == SurfaceMaterialState.LIQUID_GLASS &&
            hasBackdrop &&
            isRuntimeShaderSupported()
    }
    // 压色：材质面板那根 `tintAlpha`，颜色取主题 surface（与底栏同一个色源）。
    val tint = MiuixTheme.colorScheme.surface.copy(
        alpha = material?.liquidTintAlpha ?: 1f,
    )

    Box(
        modifier = modifier.fillMaxWidth(),
    ) {
        when {
            material == null || bandSurface == SurfaceMaterialState.OFF -> Unit

            // 液态档：与底栏同一处实现（共享件 `QingyuGlassSurface`）。
            glassBackdrop != null -> QingyuGlassSurface(
                backdrop = glassBackdrop,
                spec = GlassSpec(
                    blurSigmaDp = material.liquidBlurSigma,
                    tintAlpha = material.liquidTintAlpha,
                    // 与旧版 `vibrancy()` 默认值一致（官方 colorControls saturation = 1.5）。
                    vibrancy = BAND_VIBRANCY,
                    // 带子不画边光（旧版也没有）：highlight 传 null，这两项只为填满 spec。
                    rimStrength = 0f,
                    rimWidthDp = 0f,
                    refractionBandDp = material.liquidRefractionBand,
                    refractionAmountDp = material.liquidRefraction,
                    dispersion = material.liquidDispersion,
                ),
                // 外溢几何仍在这边算：节点推到屏幕外一圈，只让底边参与折射。
                modifier = Modifier
                    .matchParentSize()
                    .bandGlassOverhang(overdrawDp),
                shape = RoundedCornerShape(0.dp),
                // 与底栏同一口径：采样层抬到 40dp，折射才取得到外圈像素。
                samplingPaddingDp = BAND_SAMPLING_PADDING_DP,
                tintBrush = SolidColor(tint),
            )

            else -> Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(solidColor),
            )
        }
        content()
    }
}

/** 顶栏玻璃的鲜活度：与旧版 `vibrancy()` 默认值一致（saturation 1.5），少它玻璃会发灰。 */
private const val BAND_VIBRANCY = 1.5f

/** 采样 padding（dp）：与底栏 GlassDockGeometry.SamplingPaddingReachDp 同值 40。 */
private const val BAND_SAMPLING_PADDING_DP = 40f
