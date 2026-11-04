package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import com.mutx163.qingyu.components.glass.courseCardGlassSurface
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import top.yukonga.miuix.kmp.blur.Backdrop

/**
 * 日视图卡面的**画法**：有共享采样层时画「模糊背景 + 卡色染色」，否则就是原来的实底填充。
 *
 * 与周网格课卡（`CourseGridCard` 的 `surfaceModifier`）逐字同源，包括两处口径：
 *
 * 1. 采样层由**宿主整页建好、所有卡共用**（日视图一屏十来张卡，每卡各建一层会把
 *    整屏复制十几份）；这里每张卡只付一次矩形采样，高斯已经在共享层里糊过一次。
 * 2. 染色用 [dayAgendaSurfaceAlpha] 算出来的 alpha —— 卡色压在模糊背景上，
 *    不是把卡色换成半透明（那是两回事，后者会让壁纸从卡片里"穿"出来）。
 *
 * @param glassBackdrop 共享采样层；`null` = 这一档不该采样（实体 / 高斯 / 没壁纸 /
 *   没材质快照），退回 [background] 的实底填充。
 * @param fill 卡面填充色（**已含**算好的 alpha）。
 * @param material 材质快照：只用来取 `liquidRimStrength` 决定边光强度，与底栏同一口径；
 *   `null` 时按出厂值（0.75）。
 */
@Composable
fun Modifier.dayAgendaSurface(
    glassBackdrop: Backdrop?,
    shape: Shape,
    fill: Color,
    material: HomeMaterialRenderSpec? = null,
): Modifier = if (glassBackdrop != null) {
    // 与周网格课卡同一份实现：折射(padding+lens) + 边光 + 染色都在共享件里
    //（[courseCardGlassSurface]），采样源仍是整页共享的预糊壁纸层。
    this.courseCardGlassSurface(
        backdrop = glassBackdrop,
        shape = shape,
        fill = fill,
        material = material,
    )
} else {
    background(fill, shape)
}

/**
 * 日视图卡面该不该走采样：液态档 + 宿主确实给了共享采样层。
 *
 * 判据只在这里一份 —— 卡片自己不再各自读 `material.courseCard`，否则
 * 「有的卡采样、有的卡只染色」这种半接线状态迟早出现。
 */
fun dayAgendaGlassBackdrop(
    material: HomeMaterialRenderSpec?,
    glassBackdrop: Backdrop?,
): Backdrop? = glassBackdrop?.takeIf {
    material?.courseCard == SurfaceMaterialState.LIQUID_GLASS
}
