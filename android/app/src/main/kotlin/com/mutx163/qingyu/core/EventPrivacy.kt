package com.mutx163.qingyu.core

/**
 * 埋点参数的**隐私闸门**（纯函数，无 IO、无 Android 依赖，L0 可直接单测）。
 *
 * ## 口径（默认拒绝）
 *
 * 事件参数里**不许出现**：课程名、教师名、地点名（教室/教学楼）、档案名、URL、账号，
 * 以及任何自由文本。**只许出现**：计数、布尔、枚举（数值编码）、耗时、错误码——
 * 落到类型上就是「数值或布尔」。
 *
 * 实现为两道门：
 *
 * 1. **类型门**：参数值必须是 `Number`（Int/Long/Double/…，不含 Boolean）或 `Boolean`，
 *    否则剥掉。这一道已经挡住所有自由文本（字符串、对象、列表、null）。
 * 2. **键黑名单**（[SENSITIVE_PARAMETER_KEYS]）：即便将来有人把敏感值编码成数字
 *    （例如把课名 hash 成 Int——那是变相用户标识，同样禁止），键名命中的也一律剥。
 *
 * String 参数有一道**白名单**机制（[SAFE_STRING_KEYS]）：确有必要的字符串维度
 * （如与主题无关的固定枚举语义值）必须先登记到这个集合、在基线行写明理由才放行。
 * **初始为空集**——2026-11-03 盘点的存量 String 参数（`schedule_item_id` /
 * `occurrence_date` / `exam_id`）全部被剥：随机 id 可关联单用户行为、日期是行为时间线，
 * 从严不进本地缓冲。相关事件（exam_updated / schedule_item_occurrence_*）退化为
 * 「无参数事件」，仍保留「发生了什么」的信号。
 *
 * 闸门在 [com.mutx163.qingyu.app.TimetableRepository.logEvent] 入口统一过，
 * 任何 [EventSink] 实现（含以后接的真分析后端）拿到的都已经是脱敏后参数。
 */
object EventPrivacy {

    /**
     * 敏感键黑名单：值无论什么类型都不许进事件。只列「曾经在仓里出现过的语义」
     * 与最常见的人名/位置/标识维度；类型门本身已挡住自由文本，这里是第二道保险。
     * 命中即剥，不做部分保留。
     */
    val SENSITIVE_PARAMETER_KEYS: Set<String> = setOf(
        "course_name", "course", "teacher", "teacher_name", "location", "location_name",
        "classroom", "seat_number", "profile_name", "profile", "note", "title", "name",
        "url", "link", "account", "user_id", "device_id", "ip", "email", "phone",
        "schedule_item_id", "exam_id", "occurrence_date",
    )

    /**
     * String 值白名单：**确有必要的**字符串维度才放行。初始为空集；
     * 加入即等于放宽隐私口径，必须同步更新 `EventPrivacyTest` 并在提交说明里写明理由。
     */
    val SAFE_STRING_KEYS: Set<String> = emptySet()

    /** 是否放行单个参数（键, 值）。 */
    fun allows(key: String, value: Any?): Boolean {
        if (key in SENSITIVE_PARAMETER_KEYS) return false
        return when (value) {
            is Boolean -> true
            is Number -> true
            is String -> key in SAFE_STRING_KEYS
            else -> false
        }
    }

    /** 过滤一份事件参数，返回只含允许项的新 map（入参不被修改）。 */
    fun sanitize(parameters: Map<String, Any?>): Map<String, Any> {
        val result = linkedMapOf<String, Any>()
        for ((key, value) in parameters) {
            if (value != null && allows(key, value)) result[key] = value
        }
        return result
    }
}
