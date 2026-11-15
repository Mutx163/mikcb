package com.mutx163.qingyu.platform

import coil3.memory.MemoryCache
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * `AndroidImageLoader` 的三个内存口径必须真的对应 Coil 的 `memoryCache`。
 *
 * 为什么在 `platform` 测试目录：`platform/` 不在任何 L0 域里，而这条测试要 Coil 的类
 * （`MemoryCache` 接口）和钉死的 16MB 上限，只能由 L2 的 gradle 带依赖跑。
 *
 * 断言口径（不是「调一下不为 null」）：
 * - 占用 = `memoryCache.size`；
 * - 上限 = `memoryCache.maxSize`，且**未安装时回落到构造参数 16MB**（不随 Coil 默认百分比变）；
 * - 条目数 = `memoryCache.keys.size`。
 */
class AndroidImageLoaderMemoryStatsTest {

    private fun fakeCache(size: Long, maxSize: Long, entryCount: Int): MemoryCache =
        FakeMemoryCache(
            size = size,
            maxSize = maxSize,
            keys = (1..entryCount).map { MemoryCache.Key("key-$it", emptyMap()) }.toSet(),
        )

    @Test
    fun `占用上限条目数分别对应 size maxSize keys点size`() {
        val cache = fakeCache(size = 1234L, maxSize = 8L * 1024 * 1024, entryCount = 3)
        assertEquals(1234, MemoryCacheStats.bytes(cache))
        assertEquals(8 * 1024 * 1024, MemoryCacheStats.maxBytes(cache, fallback = 999))
        assertEquals(3, MemoryCacheStats.entries(cache))
    }

    @Test
    fun `没有 cache 时占用与条目为 0 上限回落到构造参数`() {
        assertEquals(0, MemoryCacheStats.bytes(null))
        assertEquals(0, MemoryCacheStats.entries(null))
        assertEquals(16 * 1024 * 1024, MemoryCacheStats.maxBytes(null, fallback = 16 * 1024 * 1024))
    }

    @Test
    fun `未安装时对外三个口径仍然安全且上限钉在16MB`() {
        // 构造不需要 Context（Handler 是 lazy），所以在 JVM 单测里可以直接建实例。
        val loader = AndroidImageLoader()
        assertEquals(0, loader.memoryCacheBytes())
        assertEquals(0, loader.memoryCacheEntryCount())
        assertEquals(16 * 1024 * 1024, loader.memoryCacheMaxBytes())
    }

    /** Coil `MemoryCache` 的最小假件：只提供三个口径要读的字段，其余方法空实现。 */
    @OptIn(coil3.annotation.ExperimentalCoilApi::class)
    private class FakeMemoryCache(
        override var size: Long,
        override var maxSize: Long,
        override val keys: Set<MemoryCache.Key>,
    ) : MemoryCache {

        override val initialMaxSize: Long get() = maxSize

        override fun get(key: MemoryCache.Key): MemoryCache.Value? = null

        override fun set(key: MemoryCache.Key, value: MemoryCache.Value) = Unit

        override fun remove(key: MemoryCache.Key): Boolean = true

        override fun trimToSize(size: Long) = Unit

        override fun clear() = Unit
    }
}
