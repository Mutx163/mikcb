package com.mutx163.qingyu.core

/**
 * Dart `settings/lenient_json_readers.dart` 的 Kotlin 对应物。
 *
 * 口径（与 Dart 逐条一致）：
 * - **有值就收，收不下按缺键（null）**，由调用方 `?: 默认值` 兜底；绝不猜值——
 * - bool 不认 '1'/1，只认真 bool 与 'true'/'false'（trim 后任意大小写）；
 * - 字符串数字转 Int/Double 走 tryParse（去首尾空白）；
 * - double 会截断（2.7 → 2）等价 Dart `(num)?.toInt()`；
 * - 非 String 的有值项按 toString() 收（数字 1 → "1"）。
 */
object LenientJson {

    /** Dart lenientString：非字符串按 toString 转（null 原样）。 */
    fun string(v: Any?): String? = when (v) {
        null -> null
        is String -> v
        else -> v.toString()
    }

    /** Dart lenientBool：不猜。'1'/1/0 都不是 bool。 */
    fun bool(v: Any?): Boolean? = when (v) {
        is Boolean -> v
        is String -> when (v.trim().lowercase()) {
            "true" -> true
            "false" -> false
            else -> null
        }
        else -> null
    }

    /** Dart lenientInt：数字直接收（double 截断），数字字符串 tryParse（trim）。 */
    fun int(v: Any?): Long? = when (v) {
        is Long -> v
        is Int -> v.toLong()
        is Number -> v.toLong() // Double 截断：2.7 → 2（与 Dart toInt 同）
        is String -> v.trim().toLongOrNull()
        else -> null
    }

    /** Dart lenientDouble：数字直接收；数字字符串 tryParse（trim）。 */
    fun double(v: Any?): Double? = when (v) {
        is Double -> v
        is Number -> v.toDouble()
        is String -> v.trim().toDoubleOrNull()
        else -> null
    }

    /** Dart lenientList：浅拷成 List，非 List 按缺键（null）。 */
    fun list(v: Any?): List<Any?>? = when (v) {
        is List<*> -> ArrayList(v)
        else -> null
    }

    /** Dart lenientStringList：只收 String 项，非 List 按缺键（null）。 */
    fun stringList(v: Any?): List<String>? {
        if (v !is List<*>) return null
        val out = ArrayList<String>()
        for (item in v) {
            if (item is String) out.add(item)
        }
        return out
    }
}
