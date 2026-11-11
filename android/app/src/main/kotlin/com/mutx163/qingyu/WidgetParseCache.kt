package com.mutx163.qingyu

/**
 * 小组件刷新链上的**单槽解析缓存**（纯 Kotlin，可 JVM 直测）。
 *
 * ## 为什么
 *
 * 一轮桌面刷新会多次读同一份 `flutter.timetable_profiles`：今日/考试卡每卡一次、
 * 统计卡 `readSnapshot` + `readChrome` 各一次、重排再一次。7 个今日/考试 Provider +
 * 3 个统计 Provider 各一张卡时，同一份 JSON 要被 `JSONArray(...)` 全量解析约 14 次，
 * 而内容在一次刷新内根本不会变。
 *
 * 本类把「同一份源文本只解析一次」这件事收成一个可测的点：
 * - 命中：源文本与上次**完全一致**才复用上次结果；
 * - 失效：源文本变了（课表被写、换课表、导入）自然重新解析，**绝不返回上一份数据的旧对象**；
 * - 显式 `invalidate()` 供调用方在已知写入后立刻丢弃。
 *
 * 不做 LRU、不做多槽：一次刷新只需要当前那份，多槽只会让「什么时候失效」变难讲清。
 */
internal class WidgetParseCache<T>(
    private val parse: (source: String) -> T?,
) {

    private var cachedSource: String? = null
    private var cachedValue: T? = null
    private var hasEntry = false

    /** 同一源文本只解析一次；源文本变化必然重新解析。 */
    @Synchronized
    fun get(source: String): T? {
        if (hasEntry && source == cachedSource) {
            return cachedValue
        }
        val parsed = parse(source)
        cachedSource = source
        cachedValue = parsed
        hasEntry = true
        return parsed
    }

    /** 已知源数据被改动时调用（正常路径靠源文本比对已能失效，这里是显式兜底）。 */
    @Synchronized
    fun invalidate() {
        cachedSource = null
        cachedValue = null
        hasEntry = false
    }
}
