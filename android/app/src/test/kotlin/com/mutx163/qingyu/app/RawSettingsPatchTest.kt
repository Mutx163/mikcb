package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import java.time.LocalDateTime
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `TimetableRepository` 整份 settings 带锁通道（[TimetableRepository.readRawSettings] /
 * [TimetableRepository.writeRawSettingsPatch]）的**并发与合并语义**测试。
 *
 * 背景：局域网导入（`transfer/lan/TimetableStoreLanSettings`）按整份 JSON 读改写设置，
 * 与设置页模型（[TimetableSettingsModel]）、灵动显示共用同一个 [TimetableStore]。
 * 没有锁时两次 patch 会「读到同一份旧值 → 各自合并 → 后写覆盖先写」，先写的键被吃掉。
 *
 * 咬合探针（已实测）：摘掉 [TimetableStore.saveSettingsPatch] /
 * `saveSettingsPatchToActiveProfile` 上的 `@Synchronized` 后，
 * `既有 saveSettingsPatch 直接并发也不丢更新` 变红（丢键），还原后转绿。
 */
class RawSettingsPatchTest {

    // ---------- 并发 ----------

    @Test
    fun `并发两次 patch 不丢更新`() {
        val backend = InMemoryKeyValueStore()
        // 每次读/写各让出 1ms：没有锁时两个线程几乎必然在同一份旧值上叠加。
        val store = TimetableStore(SlowKeyValueStore(backend, 1))
        store.saveSettingsPatch(mapOf("baseKey" to "base"))
        val repository = TimetableRepository(store)

        val perThread = 120
        val start = CyclicBarrier(2)
        val errors = AtomicReference<Throwable?>(null)

        val writer = { threadIndex: Int ->
            try {
                start.await()
                repeat(perThread) { i ->
                    repository.writeRawSettingsPatch(
                        mapOf("th${threadIndex}_$i" to "v$i"),
                    )
                }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }

        val t0 = Thread { writer(0) }
        val t1 = Thread { writer(1) }
        t0.start(); t1.start()
        t0.join(60_000); t1.join(60_000)

        errors.get()?.let { throw it }
        val raw = repository.readRawSettings()
        assertEquals("基线键不能被并发 patch 吃掉", "base", raw["baseKey"])
        for (threadIndex in 0..1) {
            repeat(perThread) { i ->
                assertEquals(
                    "线程 $threadIndex 的第 $i 个键丢了（读改写未持锁）",
                    "v$i",
                    raw["th${threadIndex}_$i"],
                )
            }
        }
    }

    // ---------- 合并 / 删除 ----------

    @Test
    fun `既有 saveSettingsPatch 直接并发也不丢更新`() {
        // 不走仓储、直接调存储的两路写入（设置页模型 / 灵动显示 / 局域网导入的真实路径）：
        // 这层没有仓储对象锁兜底，只能靠 TimetableStore 自己的 @Synchronized 串行化读改写。
        val store = TimetableStore(SlowKeyValueStore(InMemoryKeyValueStore(), 1))
        store.saveSettingsPatch(mapOf("baseKey" to "base"))

        val perThread = 60
        val start = CyclicBarrier(2)
        val errors = AtomicReference<Throwable?>(null)
        val writer = { threadIndex: Int ->
            try {
                start.await()
                repeat(perThread) { i ->
                    store.saveSettingsPatch(mapOf("direct${threadIndex}_$i" to "v$i"))
                }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }
        val t0 = Thread { writer(0) }
        val t1 = Thread { writer(1) }
        t0.start(); t1.start()
        t0.join(60_000); t1.join(60_000)

        errors.get()?.let { throw it }
        val raw = store.loadSettingsJson()
        assertEquals("base", raw["baseKey"])
        for (threadIndex in 0..1) {
            repeat(perThread) { i ->
                assertEquals(
                    "存储层直接并发 patch 丢了 direct${threadIndex}_$i",
                    "v$i",
                    raw["direct${threadIndex}_$i"],
                )
            }
        }
    }

    @Test
    fun `patch 按键合并且 null 显式删键`() {
        val repository = repositoryOn()
        repository.writeRawSettingsPatch(
            linkedMapOf("customA" to "a", "customB" to "b", "customDel" to "x"),
        )

        repository.writeRawSettingsPatch(linkedMapOf("customB" to "B", "customDel" to null))

        val raw = repository.readRawSettings()
        assertEquals("a", raw["customA"])
        assertEquals("未提及的键不能被覆盖", "B", raw["customB"])
        // 显式 null 落盘后读回仍是 null 键（删键语义，不是「保留旧值」）。
        assertTrue("customDel 应仍以 null 存在于键集", raw.containsKey("customDel"))
        assertNull(raw["customDel"])
        // 再次读取时 Dart 口径把 null 当缺键，读取方按需 filterValues。
        assertEquals(setOf("customA", "customB"), raw.filterValues { it != null }.keys)
    }

    @Test
    fun `readRawSettings 返回副本改动不外溢`() {
        val repository = repositoryOn()
        repository.writeRawSettingsPatch(mapOf("k" to "v"))

        @Suppress("UNCHECKED_CAST")
        (repository.readRawSettings() as MutableMap<String, Any?>)["k"] = "hacked"

        assertEquals("v", repository.readRawSettings()["k"])
    }

    @Test
    fun `空 patch 直接成功且不写盘`() {
        val repository = repositoryOn()
        assertTrue(repository.writeRawSettingsPatch(emptyMap()))
        assertEquals(emptyMap<String, Any?>(), repository.readRawSettings())
    }

    // ---------- 落盘后内存/档案同步 ----------

    @Test
    fun `写后内存快照与活动档案内嵌 settings 同步`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        val repository = repositoryOn(store)
        // 先放一份旧值，确认被 patch 覆盖而不是叠加。
        store.saveSettingsPatch(mapOf("semesterWeekCount" to 20))

        val ok = repository.writeRawSettingsPatch(mapOf("semesterWeekCount" to 18))

        assertTrue(ok)
        assertEquals("内存快照必须重新装载", 18, repository.snapshot.settings.semesterWeekCount)
        // 桌面卡片读的是档案内嵌 settings（不是顶层 key），这里必须同步。
        val profiles = MiniJson.parse(store.rawJson(TimetableStore.KEY_PROFILES)!!) as List<*>
        val embedded = ((profiles.first() as Map<*, *>)["settings"] as Map<*, *>)
        assertEquals(18L, (embedded["semesterWeekCount"] as Number).toLong())
        assertEquals(18L, (repository.readRawSettings()["semesterWeekCount"] as Number).toLong())
        // 通知只在锁外排空：至少要有一个监听者收到一次「设置变了」。
        var notified = 0
        val handle = repository.observe { notified++ }
        repository.writeRawSettingsPatch(mapOf("semesterWeekCount" to 19))
        handle.close()
        assertTrue("每次成功写入都应通知监听者", notified >= 1)
    }

    @Test
    fun `非法 patch 值不影响其它键仍可读`() {
        val repository = repositoryOn()
        repository.writeRawSettingsPatch(mapOf("sane" to "ok"))

        // 嵌套空 map 是合法 JSON，写进去不影响已有键（合并是浅合并）。
        repository.writeRawSettingsPatch(mapOf("nested" to emptyMap<String, Any?>()))

        val raw = repository.readRawSettings()
        assertEquals("ok", raw["sane"])
        assertTrue(raw.containsKey("nested"))
        assertFalse("顶层键集不能被当成子对象展开", raw.containsKey("nested.inner"))
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun repositoryOn(
        store: TimetableStore = TimetableStore(InMemoryKeyValueStore()),
    ): TimetableRepository {
        val now = LocalDateTime.of(2026, 11, 3, 9, 0)
        store.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    currentWeek = 1,
                    createdAt = now,
                    lastUsedAt = now,
                    courses = listOf(course()),
                ),
            ),
        )
        store.saveActiveProfileId("p1")
        return TimetableRepository(store)
    }

    private fun course(): Course = Course(
        id = "c1",
        name = "数学",
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    /** 让出 CPU 的存储包装：把「读改写窗口」放大到必然发生，用来证明锁是真的。 */
    private class SlowKeyValueStore(
        private val delegate: KeyValueStore,
        private val delayMillis: Long,
    ) : KeyValueStore by delegate {
        override fun getString(key: String): String? {
            Thread.sleep(delayMillis)
            return delegate.getString(key)
        }

        override fun putString(key: String, value: String) {
            Thread.sleep(delayMillis)
            delegate.putString(key, value)
        }
    }
}
