package com.mutx163.qingyu.core

/**
 * 课程预设色板（2026-11-02 自 `pages/import/ImportSharedModel.kt` 下沉）：
 * 与 Dart `kPresetCourseColorHexes` 逐字一致。
 *
 * 为什么必须放在 core：局域网编辑服务的 `GET /api/v1/meta` 要把色板回给网页端
 * （网页的选色块直接按这份渲染，`assets/lan_edit/app.js` 的 `state.meta.presetColors`），
 * 但 `transfer/` 不能静态依赖 `pages/import`——后者不在 L0 单测脚本的共享目录名单里，
 * 依赖它会让全队每一次 L0 都 unresolved。所以常量落 core（人人可引），
 * `ImportSharedModel` 保留同名转发，原引用方不需要改。
 */
object CourseColorPalette {

    /** 预设课程色板（与 Dart `kPresetCourseColorHexes` 逐字一致）。 */
    val PRESET_COURSE_COLOR_HEXES: List<String> = listOf(
        // 红 red
        "#FCA5A5", "#F87171", "#EF4444", "#DC2626", "#B91C1C",
        // 橙红（含原深橙）orange
        "#FF5722", "#FDBA74", "#FB923C", "#F97316", "#EA580C", "#C2410C",
        // 琥珀（含原橙）amber
        "#FCD34D", "#FBBF24", "#F59E0B", "#FF9800", "#D97706", "#B45309",
        // 黄 yellow
        "#FDE047", "#FACC15", "#EAB308", "#CA8A04", "#A16207",
        // 青柠 lime
        "#BEF264", "#A3E635", "#84CC16", "#65A30D", "#4D7C0F",
        // 绿（含原绿）green
        "#86EFAC", "#4ADE80", "#4CAF50", "#22C55E", "#16A34A", "#15803D",
        // 翠绿 emerald
        "#6EE7B7", "#34D399", "#10B981", "#059669", "#047857",
        // 青绿 teal
        "#5EEAD4", "#2DD4BF", "#14B8A6", "#0D9488", "#0F766E",
        // 青（含原青）cyan
        "#67E8F9", "#22D3EE", "#06B6D4", "#00BCD4", "#0891B2", "#0E7490",
        // 天蓝 sky
        "#7DD3FC", "#38BDF8", "#0EA5E9", "#0284C7", "#0369A1",
        // 蓝（含原默认蓝）blue
        "#93C5FD", "#60A5FA", "#2196F3", "#3B82F6", "#2563EB", "#1D4ED8",
        // 靛蓝 indigo
        "#A5B4FC", "#818CF8", "#6366F1", "#4F46E5", "#4338CA",
        // 紫罗兰 violet
        "#C4B5FD", "#A78BFA", "#8B5CF6", "#7C3AED", "#6D28D9",
        // 紫（含原紫）purple
        "#D8B4FE", "#C084FC", "#A855F7", "#9333EA", "#9C27B0", "#7E22CE",
        // 品红 fuchsia
        "#F0ABFC", "#E879F9", "#D946EF", "#C026D3", "#A21CAF",
        // 粉（含原粉）pink
        "#F9A8D4", "#F472B6", "#EC4899", "#E91E63", "#DB2777", "#BE185D",
        // 玫红 rose
        "#FDA4AF", "#FB7185", "#F43F5E", "#E11D48", "#BE123C",
        // 蓝灰（含原蓝灰）slate
        "#CBD5E1", "#94A3B8", "#607D8B", "#64748B", "#475569", "#334155",
        // 棕灰（含原棕）stone
        "#D6D3D1", "#A8A29E", "#78716C", "#795548", "#57534E", "#44403C",
    )
}
