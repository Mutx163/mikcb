package com.mutx163.qingyu.theme

import kotlin.math.roundToInt

/**
 * 字阶（`lib/ui/hyperos/hyperos_miuix_spec.dart:221-237` 转录）+ 字重口径
 *（`lib/ui/app_fonts.dart:84-116`、`timetable_settings_enums.dart:27-43`）。
 *
 * Miuix `defaultTextStyles` 形参名以 Phase 3 开工对照 0.9.4 实物为准，
 * 这里只定字号语义；Compose 侧按语义填入全局覆写 + fontFamily/字重 scope
 *（硬编码 HyperOS 文本不继承 textTheme，必须显式解析 scope）。
 */
object QingyuTypography {
    const val MAIN = 17.0
    const val PARAGRAPH = 17.0
    const val PARAGRAPH_LINE_HEIGHT = 1.2
    const val BODY1 = 16.0
    const val BODY2 = 14.0
    const val BUTTON = 17.0
    const val FOOTNOTE1 = 13.0
    const val FOOTNOTE2 = 11.0
    const val HEADLINE1 = 17.0
    const val HEADLINE2 = 16.0
    const val SUBTITLE = 14.0
    const val TITLE1 = 32.0
    const val TITLE2 = 24.0
    const val TITLE3 = 20.0
    const val TITLE4 = 18.0

    /** 设置行标题 / 列表标题（与 main/headline1/button 同 17）。 */
    const val PREFERENCE_TITLE = 17.0

    /** 行内说明（= body2）。 */
    const val LIST_DETAIL = 14.0

    /** 分组小标题（= footnote1，色走 actionIcon）。 */
    const val SECTION_LABEL = 13.0

    /** 整宽段说明（= footnote1，不受单行口径约束）。 */
    const val SECTION_DESCRIPTION = 13.0

    /** 磨砂子页居中标题。 */
    const val NESTED_HEADER_TITLE = 20.0

    const val TITLE_LINE_HEIGHT = 1.25
    const val LIST_DETAIL_LINE_HEIGHT = 1.4
    const val SECTION_LABEL_LINE_HEIGHT = 1.3
    const val SECTION_DESCRIPTION_LINE_HEIGHT = 1.5
    const val METRIC_LARGE = 24.0
    const val METRIC_MEDIUM = 18.0

    const val WEIGHT_DEFAULT = 400
    const val WEIGHT_MIN = 100
    const val WEIGHT_MAX = 900

    /** 按槽位名取字号；未知 key 返回 null（调用方回落默认，不抛不崩）。 */
    fun sizeFor(slotKey: String): Double? =
        when (slotKey.trim().lowercase()) {
            "main" -> MAIN
            "paragraph" -> PARAGRAPH
            "body1" -> BODY1
            "body2" -> BODY2
            "button" -> BUTTON
            "footnote1" -> FOOTNOTE1
            "footnote2" -> FOOTNOTE2
            "headline1" -> HEADLINE1
            "headline2" -> HEADLINE2
            "subtitle" -> SUBTITLE
            "title1" -> TITLE1
            "title2" -> TITLE2
            "title3" -> TITLE3
            "title4" -> TITLE4
            else -> null
        }

    /**
     * 用户设了非默认字重则整页绝对覆盖，否则只做系统粗体增量补偿
     *（钳在 100–900）。
     */
    fun resolveWeight(userWeight: Int, designWeight: Int, systemDelta: Int): Int {
        if (userWeight != WEIGHT_DEFAULT) return userWeight.coerceIn(WEIGHT_MIN, WEIGHT_MAX)
        return (designWeight - systemDelta).coerceIn(WEIGHT_MIN, WEIGHT_MAX)
    }

    /**
     * 整体平移：保留角色之间的字重差（课卡标题 700 / 详情 400 同步变粗变细），
     * 同样钳在 100–900（极值收敛是有意的）。
     */
    fun resolveShiftedWeight(userWeight: Int, designWeight: Int, systemDelta: Int): Int {
        if (userWeight != WEIGHT_DEFAULT) {
            return (designWeight + userWeight - WEIGHT_DEFAULT).coerceIn(WEIGHT_MIN, WEIGHT_MAX)
        }
        return (designWeight - systemDelta).coerceIn(WEIGHT_MIN, WEIGHT_MAX)
    }

    /** 非法/缺失字重回落默认（与 Dart `normalizeAppFontWeight` 同口径）。 */
    fun normalizeWeight(value: Double?): Int {
        if (value == null) return WEIGHT_DEFAULT
        return value.roundToInt().coerceIn(WEIGHT_MIN, WEIGHT_MAX)
    }
}
