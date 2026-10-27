package com.mutx163.qingyu.pages.settings

/**
 * `String` 模板的占位符替换（与 `ArbText.filled` 同义）。
 *
 * 为什么需要：settings 渲染表里有些字段是**运行时拼出来的模板字符串**（例如
 * `SettingsStringsExt2.semesterOverviewCurrentWeek`，它本身是 ARB 原文的 String 常量），
 * 另一些是 `ArbText`。两种都要能 `filled("current", …)`，所以在 String 上补同义扩展，
 * 而不是把调用点分别写成 `replace("{…}", …)` 两套写法。
 *
 * 语义与 `ArbText.filled` 逐字一致：只替换 `{name}`，找不到就原样返回（不抛错）。
 */
fun String.filled(name: String, value: String): String = replace("{$name}", value)

/** 多占位符版本（参数顺序即替换顺序，互不影响）。 */
fun String.filled(vararg pairs: Pair<String, String>): String {
    var result = this
    for ((name, value) in pairs) {
        result = result.replace("{$name}", value)
    }
    return result
}
