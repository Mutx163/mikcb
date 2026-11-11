package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * [WidgetParseCache] 的 JVM 单测。
 *
 * 钉两件事（Tob 给的契约）：
 * 1. **解析次数**：同一份 `timetable_profiles` 文本在一轮刷新里只能被解析一次；
 * 2. **失效**：文本变了（课表被写）必须重新解析，绝不能把旧对象当新数据返回。
 *
 * 咬合探针记录：把 `get()` 改成「无条件 `parse(source)`」→ 第 1、2 例立即红；
 * 把 `source == cachedSource` 改成 `true`（永不失效）→ 第 3、4 例红；还原后全绿。
 */
class WidgetParseCacheTest {

    private class CountingParser<T>(private val parser: (String) -> T?) {
        var calls = 0
            private set

        fun parse(source: String): T? {
            calls++
            return parser(source)
        }
    }

    @Test
    fun `同一份源文本只解析一次`() {
        val parser = CountingParser<String> { "已解析:$it" }
        val cache = WidgetParseCache(parser::parse)

        val first = cache.get("profiles-A")
        val second = cache.get("profiles-A")
        val third = cache.get("profiles-A")

        assertEquals("同一份文本不应重复解析", 1, parser.calls)
        assertEquals("已解析:profiles-A", first)
        assertSame("命中缓存应返回同一个对象", first, second)
        assertSame(first, third)
    }

    @Test
    fun `源文本变化必须重新解析`() {
        val parser = CountingParser<String> { "已解析:$it" }
        val cache = WidgetParseCache(parser::parse)

        cache.get("profiles-A")
        cache.get("profiles-A")
        val afterChange = cache.get("profiles-B")

        assertEquals("换了一份数据必须重新解析", 2, parser.calls)
        assertEquals("已解析:profiles-B", afterChange)
    }

    @Test
    fun `显式失效后即使文本相同也重新解析`() {
        val parser = CountingParser<String> { "已解析:$it" }
        val cache = WidgetParseCache(parser::parse)

        cache.get("profiles-A")
        cache.invalidate()
        cache.get("profiles-A")

        assertEquals(2, parser.calls)
    }

    @Test
    fun `解析失败也按文本缓存空结果 不反复重试`() {
        val parser = CountingParser<String?> { null }
        val cache = WidgetParseCache(parser::parse)

        cache.get("坏 JSON")
        cache.get("坏 JSON")

        assertEquals("坏数据不该在每张卡上反复解析", 1, parser.calls)
        cache.invalidate()
        cache.get("坏 JSON")
        assertEquals("显式失效后允许再试一次", 2, parser.calls)
    }
}
