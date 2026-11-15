package com.mutx163.qingyu.pages.timetable

/**
 * 顶栏玻璃带染色的**两层拆分**（2026-11-15，纯函数，main 源集无 Compose 依赖）。
 *
 * ## 为什么拆
 *
 * 带子由两遍玻璃叠成：第一遍 = 壁纸模糊 + 染色，第二遍 = 钻进带子底下的课卡模糊。
 * 染色只落在第一遍上时，第二遍画在它**上面**，于是带子下半截里的卡片区域是**没染过的
 * 原色**——用户读作「字糊、边锐，两块没融在一起」（周/日两视图同一个病）。
 *
 * ## 怎么拆
 *
 * 同一个颜色分两层画：第一遍按 [FIRST_LAYER_SHARE] 留一点点（只给壁纸串色，卡片那一遍
 * 看不到它），剩下的放在两遍**之上**的补色层。两层按 alpha 合成后仍然等于材质面板那根
 * `tintAlpha`：
 *
 * `1 - (1 - first) * (1 - top) == total`
 *
 * 这样「没内容钻进带子」的区段观感与改前一致（合成值不变），而「有课卡钻进带子」的区段
 * 卡片会被补色层一起压上材质色，不再是一块原色。
 *
 * @param totalAlpha 材质面板的染色强度（`HomeMaterialRenderSpec.liquidTintAlpha`，0..1）
 * @return `first to top`：第一遍 `onDrawSurface` 用的 alpha、以及顶层补色层的 alpha
 */
fun bandTintLayerAlphas(totalAlpha: Float): Pair<Float, Float> {
    val total = totalAlpha.coerceIn(0f, 1f)
    if (total <= 0f) return 0f to 0f
    val first = (total * FIRST_LAYER_SHARE).coerceIn(0f, 1f)
    if (first >= 1f) return 1f to 0f
    val top = ((total - first) / (1f - first)).coerceIn(0f, 1f)
    return first to top
}

/**
 * 第一遍染色在总强度里占的份额：18%。
 *
 * 取值理由：第一遍的色只影响「壁纸那块」，课卡那一遍盖在它上面、看不到它；把份额压到
 * 两成以下，补色层就能拿到绝大部分（总强度 0.70 时补色层 ≈ 0.657），卡片区域与壁纸区域
 * 的观感差 ≈ 0.04，肉眼看不出。份额再高就会让卡片明显比周围浅。
 */
const val FIRST_LAYER_SHARE = 0.18f
