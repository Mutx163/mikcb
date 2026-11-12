package com.mutx163.qingyu

/**
 * 小组件刷新链上的**单槽解析缓存**（纯 Kotlin，可 JVM 直测）。
 *
 * ## 契约（两条，都是对抗审查 M3/M4 之后补的硬约束）
 *
 * 1. **`T` 必须不可变**：允许 `String`、`data class`、只含不可变字段的 `List`。
 *    **禁止缓存 `JSONObject` / `JSONArray`** —— 它们是可变对象，共享出去后调用方一个
 *    `put` 就会污染后续所有读取（源文本没变 ⇒ 不失效 ⇒ 没有任何测试会红）。
 *    需要 JSON 时缓存「原始字符串」，由调用方每次现解析一份新对象。
 * 2. **解析失败也缓存**：`parse` 抛 `Exception` 时把「这份文本解析不出来」记下来，
 *    同一文本不再重复重试（否则 10 张卡会各抛一次）；换文本或 [invalidate] 后才重试。
 *
 * 命中靠源文本**全等**判断：课表被写、换档、导入都会让文本变，自然重新解析。
 */
internal class WidgetParseCache<T : Any>(
    private val parse: (source: String) -> T?,
) {

    private var cachedSource: String? = null
    private var cachedValue: T? = null
    private var hasEntry = false

    /** 同一源文本只解析一次；源文本变化必然重新解析；解析异常按「无结果」缓存。 */
    @Synchronized
    fun get(source: String): T? {
        if (hasEntry && source == cachedSource) {
            return cachedValue
        }
        val parsed = try {
            parse(source)
        } catch (_: Exception) {
            // M3：解析失败（JSONArray 对坏文本抛 JSONException）也记进缓存，
            // 否则同一轮刷新里每张卡都会再抛一次。
            null
        }
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

/**
 * 缓存里存的一份课表档案：**只有不可变字段**（id 与原始 JSON 字符串）。
 *
 * 卡片渲染时用它现造 `JSONObject`，所以每张卡拿到的是自己的新对象，
 * 不存在「共享可变 JSON」被下游写脏的风险（M4）。
 */
internal data class CachedProfile(
    val id: String,
    val raw: String,
)
