package com.mutx163.qingyu.app

/**
 * 桌面小组件「内容签名」：把**决定卡片画面的存储键**按固定顺序拼成一个可比较的字符串。
 *
 * ## 它解决什么
 *
 * 课表每次保存会连续写好几个 prefs 键（档案、活动档案 id、假期……），
 * 直接在每个键的变更回调里刷卡片，会在一次编辑里重画很多遍。
 * [com.mutx163.qingyu.WidgetRefreshBridge] 需要的是「**内容真的变了没有**」，
 * 而内容的唯一来源就是下面这些键的落盘值——本对象负责把它们折叠成一个签名。
 *
 * ## 为什么在 `app/` 而不是包根
 *
 * 本文件零 Android 依赖，放在 `app/` 才能被 `scripts/test-kotlin-module.ps1`
 * 收进每个模块的 L0 classpath（包根整目录不收，那里有 Activity 与 Provider）。
 * 判据是纯函数，期望值可以人推。
 *
 * ## 监视清单怎么定的（不是拍脑袋）
 *
 * 清单 = 桌面卡片**真正会读**的 prefs 键，逐条对过：
 * - [KEY_TIMETABLE_PROFILES]：课程 / 考试 / 每个档案自己的 settings 与 currentWeek
 *   （`TodayWidgetSupport.buildSnapshotFromFlutterState`、`StatsWidgetSupport.readSnapshot`）；
 * - [KEY_ACTIVE_PROFILE_ID]：卡片跟随哪份课表；
 * - [KEY_PARTNER_TIMETABLE_BINDING]：情侣合并视图的周偏移与三色；
 * - [KEY_CUSTOM_HOLIDAYS] 与 [HOLIDAY_DATA_KEY_PREFIX]：今天的假期态与周末文案。
 *
 * `timetable_settings` / `current_week` / `time_schemes` / `schedule_date_rules` /
 * `location_time_groups` **不在清单里**：卡片不读它们（它读的是档案内嵌的那份 settings，
 * 以及课程条目上已经算好的起止时间）。把它们加进来只会让「改了卡片根本不显示的东西」
 * 也触发一次重画。
 */
object WidgetRefreshSignature {

    /** 以「精确键」形式与卡片画面有关的契约 key（不带 `flutter.` 前缀）。 */
    val WATCHED_KEYS: List<String> = listOf(
        "timetable_profiles",
        "active_timetable_profile_id",
        "partner_timetable_binding",
        "custom_holidays",
    )

    /** 年度假期数据 `holiday_data_<year>`：年份不固定，按前缀匹配。 */
    const val HOLIDAY_DATA_KEY_PREFIX = "holiday_data_"

    /**
     * 这个契约 key 变了，卡片画面**可能**要重画吗？
     *
     * 只是粗筛，最终由 [build] 的签名比对决定——这里放行的键即使改了、签名没变也不会刷。
     * 空年份的 `holiday_data_` 不算相关：它不是任何一年的数据键。
     */
    fun isRelevant(logicalKey: String): Boolean {
        if (logicalKey in WATCHED_KEYS) return true
        return logicalKey.length > HOLIDAY_DATA_KEY_PREFIX.length &&
            logicalKey.startsWith(HOLIDAY_DATA_KEY_PREFIX)
    }

    /**
     * 把各段内容拼成签名。**长度前缀编码**，不用分隔符直接 join：
     * 值里出现分隔符时（例如课程名里带控制字符），直接 join 会让
     * `["a\u001Fb"]` 与 `["a", "b"]` 撞成同一个签名，改动被当成「没变」而漏刷。
     * 长度前缀下这两者分别是 `3:a\u001Fb;` 与 `1:a;1:b;`，不可能相等。
     *
     * `null`（键不存在）与空字符串是两种状态，也必须可区分：
     * 前者编码成 `N;`，后者编码成 `0:;`。
     */
    fun build(parts: List<String?>): String = buildString {
        for (part in parts) {
            if (part == null) {
                append("N;")
            } else {
                append(part.length).append(':').append(part).append(';')
            }
        }
    }
}
