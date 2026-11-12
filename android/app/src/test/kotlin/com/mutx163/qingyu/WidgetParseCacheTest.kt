package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WidgetParseCache] 的 JVM 单测，钉三条契约：
 *
 * 1. **解析次数**：同一份源文本在一轮刷新里只解析一次；
 * 2. **失效**：文本变了、或显式 `invalidate()`，必须重新解析；
 * 3. **失败也缓存**（M3 修复点）：`parse` 抛异常时同一文本不反复重试，
 *    换文本/失效后允许再试一次。
 *
 * 被测值用 `data class`（不可变），对应 M4 修复点的契约：缓存只收不可变值，
 * 可变 JSON 一律由调用方现解析——这里不再断言「返回同一个可变对象」。
 *
 * 咬合探针（可复现命令见 `.agents/notes/2026-11-11-widget-refresh-goasync.md`）：
 * 去掉 `get()` 的命中分支 → 第 1、2、3 例红；去掉 `catch` → 第 4 例红；还原后绿。
 */
class WidgetParseCacheTest {

    private data class ImmutableValue(val text: String)

    private class CountingParser<T : Any>(private val parser: (String) -> T?) {
        var calls = 0
            private set

        fun parse(source: String): T? {
            calls++
            return parser(source)
        }
    }

    @Test
    fun `同一份源文本只解析一次`() {
        val parser = CountingParser { ImmutableValue("解析:$it") }
        val cache = WidgetParseCache(parser::parse)

        val first = cache.get("profiles-A")
        val second = cache.get("profiles-A")
        val third = cache.get("profiles-A")

        assertEquals("同一份文本不应重复解析", 1, parser.calls)
        assertEquals(ImmutableValue("解析:profiles-A"), first)
        assertEquals(first, second)
        assertEquals(first, third)
    }

    @Test
    fun `源文本变化必须重新解析`() {
        val parser = CountingParser { ImmutableValue("解析:$it") }
        val cache = WidgetParseCache(parser::parse)

        cache.get("profiles-A")
        cache.get("profiles-A")
        val afterChange = cache.get("profiles-B")

        assertEquals("换了一份数据必须重新解析", 2, parser.calls)
        assertEquals(ImmutableValue("解析:profiles-B"), afterChange)
    }

    @Test
    fun `显式失效后即使文本相同也重新解析`() {
        val parser = CountingParser { ImmutableValue("解析:$it") }
        val cache = WidgetParseCache(parser::parse)

        cache.get("profiles-A")
        cache.invalidate()
        cache.get("profiles-A")

        assertEquals(2, parser.calls)
    }

    @Test
    fun `解析抛异常时按失败缓存 同一文本不反复重试 且失败只通知一次`() {
        val parser = CountingParser<ImmutableValue> { throw IllegalArgumentException("坏 JSON") }
        var failures = 0
        val cache = WidgetParseCache(parser::parse, onParseFailed = { _, _ -> failures++ })

        assertNull(cache.get("坏 JSON"))
        assertNull(cache.get("坏 JSON"))
        assertEquals("坏数据不该在每张卡上反复解析/反复抛", 1, parser.calls)
        assertEquals("失败只通知一次（生产据此打一条 warning）", 1, failures)
        assertTrue("当前缓存项必须记为失败", cache.currentFailure())

        cache.invalidate()
        assertNull(cache.get("坏 JSON"))
        assertEquals("显式失效后允许再试一次", 2, parser.calls)
        assertEquals(2, failures)
    }

    @Test
    fun `解析成功但结果为空 与解析失败是两种状态`() {
        val parser = CountingParser<ImmutableValue> { null }
        var failures = 0
        val cache = WidgetParseCache(parser::parse, onParseFailed = { _, _ -> failures++ })

        assertNull(cache.get("空档案"))
        assertNull(cache.get("空档案"))

        assertEquals("空结果同样不反复重试", 1, parser.calls)
        assertEquals("空结果不是失败，不得打失败日志", 0, failures)
        assertFalse("当前缓存项不是失败状态", cache.currentFailure())
    }
}
