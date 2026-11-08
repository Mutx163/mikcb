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

/**
 * 「无壁纸」页底回退的有效背景亮度（2026-11-07 瞬态修复）。
 *
 * 卡片的 `wallpaperLuminance` 为 null 有两种含义：真没壁纸，或者壁纸已上屏但亮度还没测出来。
 * 后者按页底判墨会闪出反极性文字：浅色主题页底（≈0.90）+ 深壁纸（≈0.05）时，中调卡按页底
 * 合成 ≈0.52 会选近黑字，而屏幕上实际是壁纸（合成 ≈0.14，应选白字）。
 *
 * 所以只有 [hasWallpaper] 为 false 时才把页底亮度交给卡判墨；为 true 时返回 null，
 * 卡片保持旧回退（按不透明卡色择优），等 `wallpaperBands` 量出来再用真壁纸亮度。
 *
 * @param hasWallpaper **纯**壁纸存在信号（`homeChrome.hasBackdrop`），不要与材质开关相与。
 * @param pageLuminance 页底亮度（自定义页底色优先、缺省主题页底）。
 */
fun dayAgendaPageFallbackLuminance(
    hasWallpaper: Boolean,
    pageLuminance: Double,
): Double? = if (hasWallpaper) null else pageLuminance
