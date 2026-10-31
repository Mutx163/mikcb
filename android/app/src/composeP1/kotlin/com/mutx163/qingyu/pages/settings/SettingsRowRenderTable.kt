package com.mutx163.qingyu.pages.settings

/**
 * 渲染层与模型层之间的**取值口径**（纯 Kotlin，不 import Compose）。
 *
 * ## 这个文件现在只管三件事
 *
 * 1. [trailingText]：行尾读数取哪个字段（`details` 优先，其次 `value`）；
 * 2. [selectedLabel]：单选/下拉行的当前项名字；
 * 3. 颜色串解析：[tryParseArgb] / [parseArgbOrFallback] / [colorFromHex]
 *    （逐字抄 Dart `lib/utils/hex_color.dart` 与 `settings_shared.dart`）。
 *
 * ## 删掉的东西（2026-10-29，一轮审核 P2）
 *
 * 这里原本还有一张「组件落点表」（`Requirement` / `Rendering` / `all` / `rendering()`），
 * 声明「由 `SettingsRenderContractTest` 逐项断言，两个方向都钉住」——但：
 *
 * - 全仓**不存在** `SettingsRenderContractTest` 这个类（引用它的只有这句注释本身）；
 * - `all` / `rendering()` / `miuixSymbols` **0 个调用点**，是纯死代码；
 * - 表里写的符号还是 0.9.4 已删除的 `top.yukonga.miuix.kmp.extra.Super*`，
 *   而渲染层实际用的是 `miuix-preference` 的 `ArrowPreference` 等 —— 表本身就是错的。
 *
 * 真正在起作用的是 `SettingsRowRenderingCapabilityGuardTest` / `SettingsRowComponentGuardTest`
 * （两者都读 `composeP1` 源码文本），不需要这张表。留着它只会让下一个接单的人
 * 以为「有契约测试在管」，所以整段删掉。
 */
object SettingsRowRenderTable {

    /**
     * 行尾文本：静态 [SettingsRow.details] 优先，其次动态 [SettingsRow.value]。
     *
     * 两者在 Flutter 侧是同一个槽位（`HyperosNavTile.details` /
     * `HyperosSelectTile` 的取值区），模型为了区分「来自 ARB」与「算出来的」
     * 拆成两个字段，这里合回一个。
     */
    fun trailingText(row: SettingsRow): String? = row.details ?: row.value

    /** 下拉/单选行的当前项名字（找不到就是 null，渲染层按空串处理）。 */
    fun selectedLabel(row: SettingsRow): String? =
        row.options.firstOrNull { it.id == row.selectedOptionId }?.label

    /**
     * `#RRGGBB` / `RRGGBB` → 不透明 ARGB；其余一律 null。
     *
     * 口径逐字抄 `lib/utils/hex_color.dart:3-17` 的 `tryParseHexColor`：
     * 去空白、可带一个 `#`、长度必须 6、按 16 进制解析，alpha 恒为 FF。
     */
    fun tryParseArgb(hex: String?): Int? {
        val normalized = hex?.trim().orEmpty()
        if (normalized.isEmpty()) return null
        val body = if (normalized.startsWith("#")) normalized.substring(1) else normalized
        if (body.length != 6) return null
        val parsed = body.toLongOrNull(16) ?: return null
        return (0xFF000000L or parsed).toInt()
    }

    /** `lib/utils/hex_color.dart:19-21` 的 `parseHexColorOrFallback`。 */
    fun parseArgbOrFallback(hex: String?, fallbackArgb: Int): Int =
        tryParseArgb(hex) ?: fallbackArgb

    /**
     * `settings_shared.dart:128-130` 的 `colorFromHex`：坏串回落品牌蓝 `#2563EB`。
     */
    fun colorFromHex(hex: String?): Int = parseArgbOrFallback(hex, FALLBACK_BLUE_ARGB)

    /** `Color(0xFF2563EB)`（`settings_shared.dart:129`）。 */
    const val FALLBACK_BLUE_ARGB: Int = 0xFF2563EB.toInt()
}
