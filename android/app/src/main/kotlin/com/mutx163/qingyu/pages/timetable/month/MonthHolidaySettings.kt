package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.core.LenientJson

/**
 * 月视图消费的两个假期开关（纯 Kotlin，无 Android / IO 依赖）。
 *
 * 这两个键**不在** `core.TimetableSettings` 的四键子集里，`TimetableSettingsModel`
 * 也只收了 `enableHolidayMarking`（`holidayOverrideEnabled` 当前由
 * `LiveSelfCheckHost` 自己读盘）。月视图的 `MonthViewHost` / `MonthViewDataSource`
 * 只接收布尔值，所以「从设置存档里取真值」这一小段放在这里，且只放一份。
 *
 * ## 读取口径（与 Dart / 小组件 / 自检页逐字一致）
 *
 * | 键 | 缺键 / 坏值 | 出处 |
 * |---|---|---|
 * | `holidayOverrideEnabled` | `false` | `timetable_settings.dart` 同名键；`LiveSelfCheckHost.readHolidayOverride` |
 * | `enableHolidayMarking` | `true` | `TimetableSettingsModel.enableHolidayMarking` 的读侧默认值 |
 *
 * 坏值走 [LenientJson.bool]：只认 bool 与 `"true"` / `"false"` 字符串，
 * `1` / `"1"` / 任意其它类型都按缺键处理——**不猜**，与 Dart `lenientBool` 同口径。
 */
data class MonthHolidaySettings(
    /** 「今天放假」覆盖：开启后所有非调休上班日都按假期处理。 */
    val overrideEnabled: Boolean = false,

    /** 假期标记总开关：关闭后月网格不再打假期底色 / 补班标记。 */
    val markingEnabled: Boolean = true,
) {

    companion object {

        /** `timetable_settings.holidayOverrideEnabled`。 */
        const val KEY_OVERRIDE_ENABLED = "holidayOverrideEnabled"

        /** `timetable_settings.enableHolidayMarking`。 */
        const val KEY_MARKING_ENABLED = "enableHolidayMarking"

        /**
         * 从设置存档的 JSON 对象里取两个开关。
         *
         * @param json `TimetableStore.loadSettingsJson()` 的返回值（顶层 `timetable_settings`）。
         */
        fun fromSettingsJson(json: Map<String, Any?>): MonthHolidaySettings =
            MonthHolidaySettings(
                overrideEnabled = LenientJson.bool(json[KEY_OVERRIDE_ENABLED]) ?: false,
                markingEnabled = LenientJson.bool(json[KEY_MARKING_ENABLED]) ?: true,
            )
    }
}
