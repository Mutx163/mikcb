package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.CourseCardSurface
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.SurfaceMaterialState

/**
 * 日视图议程卡的**卡面填充透明度**（2026-11-01 接壁纸/玻璃时抽出）。
 *
 * ## 为什么单独一个纯函数
 *
 * 日视图原先的卡面一律是「课色 / 日程色 / 考试红 × 固定 alpha」的不透明填充，
 * 于是壁纸接上来以后卡片仍然把壁纸挡得死死的。现在卡面档位与**周网格课卡**
 * （`CourseGridCard` 的 `fillAlpha`）走同一条口径：
 *
 * | `material.courseCard` | 卡面 alpha |
 * |---|---|
 * | `SOLID` / `OFF` / 没传材质 / `FROST_PROGRESSIVE` | 原样（实体，旧行为） |
 * | `FROST` / `FROST_GAUSSIAN` | `0.55 ×`（无预糊管线时的降级观感，与周网格同值） |
 * | `LIQUID_GLASS` | `courseCardTintAlpha ×`（卡片自己那套染色旋钮） |
 *
 * 放在 main 源集、不含 Compose 依赖，是为了让 JVM 单测能直接钉住这张表 ——
 * 「哪一档压多少」写错时，编译和界面都不会红，只有这里能抓住。
 *
 * @param solidAlpha 该卡在实体档下的原透明度（课程卡按停课/非本周压淡，日程卡 0.95…）。
 */
fun dayAgendaSurfaceAlpha(
    material: CourseCardSurface?,
    solidAlpha: Float,
): Float = when (material?.courseCard) {
    SurfaceMaterialState.FROST,
    SurfaceMaterialState.FROST_GAUSSIAN,
    -> 0.55f * solidAlpha

    SurfaceMaterialState.LIQUID_GLASS ->
        material.courseCardTintAlpha.coerceIn(0.08f, 1f) * solidAlpha

    // SOLID / OFF / FROST_PROGRESSIVE / 没传材质：一律实体，旧行为不变。
    else -> solidAlpha
}
