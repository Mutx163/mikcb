package com.mutx163.qingyu

/**
 * 小组件刷新链上的**单槽解析缓存**（纯 Kotlin，可 JVM 直测）。
 *
 * ## 契约（对抗审查 M3/M4 之后定形）
 *
 * 1. **`T` 必须不可变**：允许 `String`、`data class`、只含不可变字段的 `List`。
 *    **禁止缓存 `JSONObject` / `JSONArray`** —— 它们是可变对象，共享出去后调用方一个
 *    `put` 就会污染后续所有读取（源文本没变 ⇒ 不失效 ⇒ 没有任何测试会红）。
 *    需要 JSON 时缓存「原始字符串」，由调用方每次现解析一份新对象。
 * 2. **解析失败也缓存**：同一文本不再反复重试（否则 10 张卡各抛一次）；换文本或
 *    [invalidate] 后才重试。
 * 3. **「失败」与「空结果」是两种状态**，不共用一条路径互相覆盖：
 *    - 失败 = `parse` 抛 `Exception` ⇒ 记 `failed=true`、值按 `null` 返回，并通过
 *      [onParseFailed] 通知一次（生产用来打一条 warning，否则卡片空白且无日志）；
 *    - 空结果 = `parse` 正常返回 `null`（例如档案数组解析成功但里面没有可用档案）
 *      ⇒ `failed=false`，不调用 [onParseFailed]。
 *    两者对「要不要重试」的处置相同（都抑制重试），区别在**诊断与日志**；
 *    [currentFailure] 供诊断读取当前缓存项到底是哪一种。
 *
 * 命中靠源文本**全等**判断：课表被写、换档、导入都会让文本变，自然重新解析。
 */
internal class WidgetParseCache<T : Any>(
    private val parse: (source: String) -> T?,
    private val onParseFailed: (source: String, error: Exception) -> Unit = { _, _ -> },
) {

    private class Entry<T>(val value: T?, val failed: Boolean)

    private var cachedSource: String? = null
    private var cachedEntry: Entry<T>? = null

    /** 同一源文本只解析一次；源文本变化必然重新解析；两种结果都缓存，但状态分开记。 */
    @Synchronized
    fun get(source: String): T? {
        val existing = cachedEntry
        if (existing != null && source == cachedSource) {
            return existing.value
        }
        val parsed = try {
            Entry<T>(parse(source), failed = false)
        } catch (error: Exception) {
            // M3：解析失败也进缓存，否则同一轮刷新里每张卡都会再抛一次；
            // 但和「解析成功但没结果」分开记，日志与诊断不能混。
            onParseFailed(source, error)
            Entry<T>(null, failed = true)
        }
        cachedSource = source
        cachedEntry = parsed
        return parsed.value
    }

    /** 当前缓存项是不是**解析失败**（区别于「解析成功但结果为空」）。 */
    @Synchronized
    fun currentFailure(): Boolean = cachedEntry?.failed == true

    /** 已知源数据被改动时调用（正常路径靠源文本比对已能失效，这里是显式兜底）。 */
    @Synchronized
    fun invalidate() {
        cachedSource = null
        cachedEntry = null
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
