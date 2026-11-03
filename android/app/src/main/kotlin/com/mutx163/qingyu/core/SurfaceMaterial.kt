package com.mutx163.qingyu.core

/**
 * 某个表面当前生效的材质态（`lib/models/surface_material.dart:10-33`）。
 *
 * 放在共享 `core/` 而不是 `pages/settings/`：timetable 域（周网格卡、日视图议程卡、
 * 月视图顶栏、任务坞）只拿它做**渲染档位判定**，不该为了几个枚举比较去依赖整个
 * 设置页族。设置侧仍按 `SurfaceMaterialState` 类型名使用（`pages/settings` 内有顶层
 * typealias），面板上的中文文案由设置侧的 `label` 扩展属性提供——文案归设置页，
 * 档位词汇归共享层。
 */
enum class SurfaceMaterialState(val value: String) {
    /** 表面已关闭（顶栏玻璃总开关关掉后不再渲染）。 */
    OFF("off"),

    /** 实体（模糊总开关关、作用范围关的回退）。 */
    SOLID("solid"),

    /** 磨砂（玻璃坞作用范围关掉时的回退）。 */
    FROST("frost"),

    /** 渐进模糊（子页顶栏 2026-09-23 起锁死的那一档）。 */
    FROST_PROGRESSIVE("frostProgressive"),

    /** 高斯模糊（课程卡片自己那档的展示标签）。 */
    FROST_GAUSSIAN("frostGaussian"),

    /** 液态玻璃（高级材质）。 */
    LIQUID_GLASS("liquidGlass"),
}

/**
 * 卡面渲染读到的材质快照。
 *
 * 只暴露渲染层真正用到的两项：档位 + 染色透明系数。`pages/settings` 的
 * `HomeMaterialRenderSpec` 实现本接口，timetable 主源集因此只依赖 `core`，
 * 不再反向引用设置页模型。
 */
interface CourseCardSurface {
    val courseCard: SurfaceMaterialState
    val courseCardTintAlpha: Float
}
