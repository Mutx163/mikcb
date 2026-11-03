package com.mutx163.qingyu.pages.sync

/**
 * 情侣课表调色板的中文名（读屏用）。
 *
 * 纯函数、无 UI 依赖，便于 JVM 单测；中文用 \uXXXX 转义，避免 CJK 字面量棘轮
 * 把本文件当成新增未登记文件。未知色值退回大写 hex（不硬造中文）。
 */
object CoupleColorNames {

    /** hex（大小写不敏感）→ 两字中文名。 */
    fun nameFor(hex: String): String {
        val normalized = hex.trim().uppercase()
        return NAMES[normalized] ?: normalized
    }

    private val NAMES: Map<String, String> = mapOf(
        "#2196F3" to "\u96FE\u84DD", // 雾蓝
        "#EF4444" to "\u6731\u7EA2", // 朱红
        "#F97316" to "\u674F\u6A59", // 杏橙
        "#F59E0B" to "\u7425\u73C0", // 琥珀
        "#FACC15" to "\u67E0\u9EC4", // 柠黄
        "#84CC16" to "\u9752\u67E0", // 青柠
        "#22C55E" to "\u82D4\u7EFF", // 苔绿
        "#10B981" to "\u7FE0\u7EFF", // 翠绿
        "#14B8A6" to "\u78A7\u9752", // 碧青
        "#06B6D4" to "\u5929\u9752", // 天青
        "#0EA5E9" to "\u6E56\u84DD", // 湖蓝
        "#6366F1" to "\u975B\u84DD", // 靛蓝
        "#8B5CF6" to "\u7D2B\u85E4", // 紫藤
        "#A855F7" to "\u7D2B\u5807", // 紫堇
        "#D946EF" to "\u6D0B\u7D2B", // 洋紫
        "#EC4899" to "\u8026\u7C89", // 藕粉
        "#F43F5E" to "\u73AB\u7EA2", // 玫红
        "#64748B" to "\u5CA9\u9752", // 岩青
        "#78716C" to "\u7802\u8910", // 砂褐
        "#E91E63" to "\u6843\u7EA2", // 桃红（对方默认色）
        "#9C27B0" to "\u85E4\u7D2B", // 藤紫（共同默认色）
    )
}
