package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课表三视图（周 / 日 / 月）共用的**顶栏玻璃带玻璃层**。
 *
 * ## 它补的是什么
 *
 * 周视图与日视图各写了一份一模一样的「玻璃节点画到盒子之外 + drawBackdrop +
 * vibrancy + blur + lens + 染色」的代码块（2026-11-01 逐行 diff 过，只有注释不同），
 * 月视图要补同一条带就成了**第三份**。三份各自演化必然漂开 —— 所以抽成这一个
 * 组件，三处共用一份口径。
 *
 * ## 谁负责什么
 *
 * 本组件只管**玻璃这一层**（采样、高斯、折射、染色、实体降级）。带子里的内容
 * （状态栏留白 / 标题行 / 星期栏 / 月份栏）由调用方排，装在同一个
 * `Box(fillMaxWidth)` 里传进来当 [content] —— 玻璃必须与内容**同处一个盒子**，
 * 否则外溢几何按错尺寸算。
 *
 * ## 三档（判据与数值全部来自 [material]）
 *
 * | 档 | 画什么 |
 * |---|---|
 * | `OFF` / [material] 为 null | 什么也不画（内容照常上屏） |
 * | `LIQUID_GLASS` + 有采样源 + 设备支持 | 玻璃：外溢到屏幕外 + 高斯 + 折射 + 染色 |
 * | 其它（实体档 / 无 shader 后端） | 不透明页底色条，**不是**半透明水洗 |
 *
 * 液态档**首帧就画玻璃**：带子尺寸在同一次布局里由 `Modifier.matchParentSize()` 的固定
 * 约束给出，`bandGlassOverhang` 直接读约束算外溢几何（2026-11-08 之前靠 `onSizeChanged`
 * 回填状态，首帧恒为 0，只能「什么都不画」⇒ 进外观编辑页时星期栏那条带裸透一帧）。
 * 也不许改回「首帧落实体条」：那样每切一次视图都会先闪一条不透明页面底色（浅色主题 = 白条）。
 *
 * @param material 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为。
 * @param hasBackdrop 有没有可用壁纸。没有壁纸时液态档不退化成玻璃（那会模糊空气）。
 * @param backdrop 背景采样源（页面自己的 `rememberLayerBackdrop()`）。null = 没采样源。
 * @param solidColor 无壁纸 / 实体档的页底色（`pageColorArgb` → 色，缺省给主题底）。
 * @param overdrawDp 形状边界要往屏幕外推多少（逻辑 dp）。理由见
 *   `SettingsMaterialModel.bandGlassOverdrawDp`；屏幕左右还要叠安全区，那一步在调用方算。
 * @param underlayBackdrop 「带子底下正在穿过去的内容」的采样源（2026-11-08）。周视图把
 *   周网格顶到带子底下之后，课卡是画在壁纸**上面**的另一层，`backdrop` 那层只录壁纸，
 *   看不出课卡。这里再挂一片只做高斯、**不染色**的第二遍玻璃：卡片区域糊出来，
 *   空隙保持透明 ⇒ 底下的第一遍（壁纸玻璃）原样透出。null = 老行为（只有一遍）。
 * @param content 带子里的内容。
 */
@Composable
fun TimetableChromeBandGlass(
    material: HomeMaterialRenderSpec?,
    hasBackdrop: Boolean,
    backdrop: Backdrop?,
    solidColor: Color,
    overdrawDp: Dp,
    modifier: Modifier = Modifier,
    underlayBackdrop: Backdrop? = null,
    content: @Composable () -> Unit,
) {
    val bandSurface = material?.band
    // 液态档 + 真有壁纸 + 设备支持 runtime shader，三件事同时成立才画玻璃。
    val blurBackdrop = backdrop?.takeIf {
        bandSurface == SurfaceMaterialState.LIQUID_GLASS &&
            hasBackdrop &&
            isRuntimeShaderSupported()
    }
    // 染色强度就是材质面板那根 `tintAlpha`（0 = 全透，0.9 = 最厚）。
    val tint = MiuixTheme.colorScheme.surface.copy(
        alpha = material?.liquidTintAlpha ?: 1f,
    )

    // 形状必须是 `CornerBasedShape`：`lens()` 靠它取四角半径，传 `RectangleShape`
    // 会整段 return、一点折射都没有。0dp 圆角与直角同形，观感不变。
    val shape = remember { RoundedCornerShape(0.dp) }

    Box(
        modifier = modifier
            .fillMaxWidth(),
    ) {
        when {
            material == null || bandSurface == SurfaceMaterialState.OFF -> Unit

            // ⚠️ 玻璃节点挂 `matchParentSize()`：Box 会在**同一次测量**里先定下带子的最终
            // 尺寸，再用固定约束量这个子节点。`bandGlassOverhang` 就是拿这份约束算外溢
            // 几何的 —— 于是玻璃首帧就有正确尺寸，不存在「等尺寸回填」的空窗。
            blurBackdrop != null -> Box(
                modifier = Modifier
                    .matchParentSize()
                    .bandGlassOverhang(overdrawDp)
                    .drawBackdrop(
                        backdrop = blurBackdrop,
                        shape = { shape },
                        effects = {
                            // ── 折射收窄（2026-11-03）──
                            // 用户口径：作用带一宽，交界处的画面被弯得上下对不上
                            // （读作「壁纸错位」）。作用带与位移都先过夹具
                            // [timetableBandRefraction]：作用带压到紧贴交界的一小条
                            // （≤8dp），位移压到 ≤8dp；位移拖到 0 时输出 (0,0)，
                            // 整段不挂折射、严格零偏移。周/日/月三视图共用本组件，
                            // 同一套参数只有这一处。
                            // 带盒高（**不含**顶部外溢）从绘制期尺寸反推：`size` 是这一帧
                            // 节点自己的 px 尺寸（= 带子 + 外溢），首帧就有值。
                            // 非有限值只出现在 draw 之前那次预构建（miuix 在 `onAttach`
                            // 里也会跑一遍 effects），此时按 0 处理 ⇒ 不挂折射，绘制帧
                            // 会带着真尺寸重跑。
                            val bandHeightDp = if (size.height.isFinite()) {
                                (size.height - overdrawDp.roundToPx()).coerceAtLeast(0f) / density
                            } else {
                                0f
                            }
                            val refraction = timetableBandRefraction(
                                bandBoxHeightDp = bandHeightDp,
                                requestedBandDp = material.liquidRefractionBand,
                                requestedAmountDp = material.liquidRefraction,
                            )
                            val refractionPx = refraction.amountDp.dp.toPx()
                            // 折射朝形状外采样：先把采样层按位移量撑起来。
                            // ⚠️ 必须在 blur() 读 padding 之前抬 —— 事后抬会让 miuix
                            // 把整段 effects 重跑一遍。
                            padding = maxOf(padding, refractionPx)
                            // `vibrancy()` = 官方 `colorControls(saturation = 1.5)`：
                            // 少了它玻璃会发灰。
                            vibrancy()
                            blur(material.liquidBlurSigma.dp.toPx())
                            // 夹具输出为 0（位移拖到 0 / 作用带为 0）时整段不挂折射。
                            val bandPx = refraction.bandDp.dp.toPx()
                            if (bandPx > 0f && refractionPx > 0f) {
                                lens(
                                    refractionHeight = bandPx,
                                    refractionAmount = refractionPx,
                                    chromaticAberration = material.liquidDispersion,
                                )
                            }
                        },
                        onDrawSurface = { drawRect(tint) },
                    ),
            ) {
                // ── 第二遍：钻到带子底下的课卡（2026-11-08）──
                // 只做「采样 + 高斯 + 振奋」，**不染色、不折射**：
                //   · 不染色 —— 第一遍已经铺了不透明的「壁纸模糊 + 染色」，这一遍只负责把
                //     卡片糊出来盖在上面；再染一次会把整条带压厚一倍；
                //   · 不折射 —— 卡片在交界处本来就在动，再叠一层位移只会读成「卡片被撕开」。
                // 采样源的录制范围由调用方夹在「带高 + 下沿余量」（见 `TimetableBandUnderlap`），
                // 这一层本身不额外扩大开销。
                val underlay = underlayBackdrop?.takeIf { isRuntimeShaderSupported() }
                if (underlay != null) {
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .bandGlassOverhang(overdrawDp)
                            .drawBackdrop(
                                backdrop = underlay,
                                shape = { shape },
                                effects = {
                                    vibrancy()
                                    blur(material.liquidBlurSigma.dp.toPx())
                                },
                            ),
                    )
                }
            }

            else -> Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(solidColor),
            )
        }
        content()
    }
}