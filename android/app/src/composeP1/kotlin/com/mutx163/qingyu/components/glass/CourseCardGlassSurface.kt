package com.mutx163.qingyu.components.glass

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.SurfaceMaterialState
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.drawBackdrop

/**
 * 课程卡「液态玻璃面」的**唯一画法**（2026-11-04 抽出）。
 *
 * 周网格课卡（`CourseGridCard`）与日视图各卡（经 `dayAgendaSurface`）都调它 ——
 * 以前两处各写一份 `drawBackdrop`，日卡那份漏了 `lens()` 折射，于是同一个材质参数在
 * 周卡像玻璃、在日卡像一块染色透明片。收成一份后，周/日卡玻璃物理上只有一处实现。
 *
 * ## 只看"卡片自己那套"参数
 *
 * 折射三参取 `material.courseCardRefraction / courseCardRefractionBand /
 * courseCardDispersion`（`courseCardGlassTuning`），**不**与顶栏带 / 坞的全局调参共用
 * （`HomeMaterialRenderSpec` 类注释：调一处不许两处都变）。边光强度 `liquidRimStrength`
 * 走 `glassRimAlpha`，与底栏同一口径。
 *
 * ## 采样源不在这里决定
 *
 * [backdrop] 由调用方给，仍是**整页共享的预糊壁纸层**（一屏只糊一次，逐卡只付一次矩形
 * 采样 + 一次折射）。刻意**不**改成实时内容层 —— 那会把卡背后的文字/卡片糊进卡面。
 *
 * ## 逐项与底栏 / 周卡同口径
 *
 * * `padding = maxOf(padding, refractionPx)`：折射要朝形状外采样，先把采样层撑起来
 *   （必须在任何读 padding 的效果之前抬，同玻璃坞）；
 * * `lens(refractionHeight, refractionAmount, chromaticAberration)`：带/位移任一为 0
 *   时 `lens()` 自己 return（清档 = 不折射）；
 * * `highlight = GlassDockSpecular.copy(alpha = glassRimAlpha(...))`：与底栏/周卡同一份
 *   边缘高光；
 * * `onDrawSurface = { drawRect(fill) }`：课色染在模糊后的背景上（`fill` 已含 alpha）。
 *
 * @param backdrop 采样源（调用方保证非空；实体 / 无壁纸 / 无 shader 时调用方根本不会走这条）。
 * @param shape 卡面圆角（每张卡自己的形状，折射按它跑）。
 * @param fill 卡面填充色（**已含**算好的 alpha）。
 * @param material 材质快照；取折射三参与 `liquidRimStrength`。null 时按 0 折射、出厂边光。
 */
@Composable
fun Modifier.courseCardGlassSurface(
    backdrop: Backdrop,
    shape: Shape,
    fill: Color,
    material: HomeMaterialRenderSpec?,
): Modifier {
    val density = LocalDensity.current
    val refractionPx = with(density) {
        (material?.courseCardRefraction ?: 0f).dp.toPx()
    }
    val refractionBandPx = with(density) {
        (material?.courseCardRefractionBand ?: 0f).dp.toPx()
    }
    val dispersion = material?.courseCardDispersion ?: 0f
    return this.drawBackdrop(
        backdrop = backdrop,
        shape = { shape },
        // 折射必须按**每张卡自己的圆角形状**做：共享采样层是一整块全屏矩形，在那一层
        // 折射只会弯屏幕四条边，弯不到任何一张卡的边（Dart 同结构：预糊位图共享、折射逐卡跑）。
        effects = {
            // 折射朝卡外采样：先按位移量把采样层撑起来。⚠️ 必须在任何读 padding 的效果之前抬。
            padding = maxOf(padding, refractionPx)
            // 两根滑杆任一为 0 时 `lens()` 自己 return（清档 = 不折射）。
            if (refractionBandPx > 0f && refractionPx > 0f) {
                lens(
                    refractionHeight = refractionBandPx,
                    refractionAmount = refractionPx,
                    chromaticAberration = dispersion,
                )
            }
        },
        // 边缘高光：与底栏**同一份** specular，强度同一口径。
        // ⚠️ 仅**液态玻璃档**加边光——磨砂 / 高斯 / 实体等其它档不应冒出边光（那是观感变化）。
        // 当前两处调用点本就只在 LIQUID_GLASS 时才调本件；这里再门控一道防呆，避免日后误用。
        highlight = if (material?.courseCard == SurfaceMaterialState.LIQUID_GLASS) {
            {
                GlassDockSpecular.copy(alpha = glassRimAlpha(material?.liquidRimStrength))
            }
        } else {
            null
        },
        onDrawSurface = { drawRect(fill) },
    )
}
