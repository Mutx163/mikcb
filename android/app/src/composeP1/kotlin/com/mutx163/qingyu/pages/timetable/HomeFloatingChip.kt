package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 首页两颗浮钮（周视图「回本周」/ 日视图「回今日」）共用的**玻璃底**。
 *
 * ## 对应 Dart 的哪一条
 *
 * 两颗钮在 Dart 里是各自实现的 widget，但材质判据完全一样
 * （`timetable_back_to_current_week_button.dart` / `timetable_back_to_today_button.dart`）：
 *
 * 1. 跟随**玻璃坞**那一档（`FrostedAppearanceScope.liquidGlassDockEnabled`），不是跟随
 *    课程卡片的材质 —— 它们是「浮在首页上的控件」，与底栏同一族；
 * 2. 液态 / 磨砂两档都是「采样背后的画面 + 高斯 + 染色」，差别只是液态多一层折射；
 * 3. 全局模糊关掉、或设备画不出着色器时回落成实底（Dart `HyperosFrostedSurface` 在没有
 *    `backdropBlurEnabled` 时也是纯色）。
 *
 * 本仓的液态档暂时没有折射着色器（与日视图顶栏带同一条缺口），所以
 * `LIQUID_GLASS` 与 `FROST` 画出来一样：**模糊 + 染色**。等折射那套在周视图顶栏稳定后
 * 再统一对齐，不在这里先造一份。
 *
 * ## 采样源
 *
 * 直接用页面那一层**壁纸录像**（`pageBackdrop`），自己带上模糊 —— 与顶栏玻璃带同一手法。
 * 没有复用「卡片的整屏预糊层」：那颗层只在课程卡是液态档时才存在，而浮钮跟的是坞的档位，
 * 两者可以不同；自采一次比多挂一条互斥的采样链简单，也不会出现「卡片实体但浮钮要玻璃」
 * 时采样层为空的情况。
 *
 * 已知差异：Dart 的 `BackdropFilter` 采的是**屏幕**，所以卡片滚到浮钮底下时会被一起糊掉；
 * 这里只糊壁纸（浮钮下面是糊过的壁纸纹理）。与日视图吸顶摘要卡同一条已知差异。
 *
 * @param backdrop 页面壁纸录像层；`null` = 这一档不采样（实底回落）。
 * @param material 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。
 * @param hasBackdrop 当前有没有可用壁纸；没有壁纸时模糊无物可采，一律实底。
 * @param shape 钮的形状（圆角胶囊）。
 * @param solidColor 非玻璃档 / 无壁纸时的实底颜色。
 * @param tintAlphaScale 染色再乘的系数：「回本周」按钮的浮态透明度设置作用在这一层
 *   （Dart 把透明度压在 tint 与内容两层，而不是包住整块玻璃 —— 包住会让采样失真）。
 */
@Composable
fun homeFloatingChipSurface(
    backdrop: Backdrop?,
    material: HomeMaterialRenderSpec?,
    hasBackdrop: Boolean,
    shape: Shape,
    solidColor: Color,
    tintAlphaScale: Float = 1f,
): Modifier {
    val dockState = material?.dock
    val glassActive = hasBackdrop &&
        backdrop != null &&
        isRuntimeShaderSupported() &&
        (dockState == SurfaceMaterialState.LIQUID_GLASS || dockState == SurfaceMaterialState.FROST)
    if (!glassActive) {
        return Modifier.background(solidColor, shape)
    }
    val density = LocalDensity.current
    val blurSigmaPx = with(density) { (material?.liquidBlurSigma ?: 0f).dp.toPx() }
    val tint = MiuixTheme.colorScheme.surface.copy(
        alpha = ((material?.liquidTintAlpha ?: 1f) * tintAlphaScale).coerceIn(0f, 1f),
    )
    return Modifier.drawBackdrop(
        backdrop = backdrop,
        shape = { shape },
        effects = {
            blur(blurSigmaPx)
            // 与顶栏带同一条：少了它玻璃会发灰。
            vibrancy()
        },
        onDrawSurface = { drawRect(tint) },
    )
}
