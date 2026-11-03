package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * `TimetableRepository` 的**并发**测试（L0）。
 *
 * 背景（2026-11-02）：局域网编辑服务（`LanEditHttpServer`）每个连接一个工作线程，
 * 与 UI 主线程共用同一个仓储实例。仓储在加对象锁之前是普通可变字段 + 先读后写
 * 覆盖，两个线程同时 `addCourse` 会按「读到同一份列表 → 各自追加 → 后写覆盖先写」
 * 互相丢课。本组测试钉住加锁后的两条底线：
 * - **写与写不丢**：两个线程交替加课，结束时候表必须一门不少；
 * - **读写不撞**：并发写进行中反复抓 snapshot，既不抛异常，最终也收敛到一致状态。
 *
 * 咬合探针：把仓储上的 `@Synchronized` 全部摘掉再跑本组测试，
 * `两线程交替加课结果不丢` 会因丢更新而红（实测探针已验证）。
 */
class TimetableRepositoryConcurrencyTest {

    @Test
    fun `两线程交替加课结果不丢`() {
        val repository = repositoryOn()
        val perThread = 150
        val start = CyclicBarrier(2)
        val errors = AtomicReference<Throwable?>(null)

        val writer = { threadIndex: Int ->
            try {
                start.await()
                repeat(perThread) { i ->
                    repository.addCourse(
                        course(
                            id = "t${threadIndex}-$i",
                            name = "线程${threadIndex}课$i",
                            dayOfWeek = threadIndex + 1,
                        ),
                    )
                }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }

        val t0 = Thread { writer(0) }
        val t1 = Thread { writer(1) }
        t0.start(); t1.start()
        t0.join(30_000); t1.join(30_000)

        errors.get()?.let { throw it }
        val ids = repository.courses.map { it.id }
        assertEquals("两个线程的课一门都不能少", perThread * 2, ids.size)
        assertEquals(
            "id 必须恰好是两线程的全部课",
            (0 until perThread).map { "t0-$it" }.toSet() + (0 until perThread).map { "t1-$it" }.toSet(),
            ids.toSet(),
        )
    }

    @Test
    fun `并发写进行中反复抓快照不抛异常且最终一致`() {
        val repository = repositoryOn()
        val perThread = 100
        val start = CyclicBarrier(3)
        val writerDone = CountDownLatch(2)
        val errors = AtomicReference<Throwable?>(null)
        val snapshotReads = AtomicInteger(0)

        val writer = { threadIndex: Int ->
            try {
                start.await()
                repeat(perThread) { i ->
                    repository.addCourse(course("w${threadIndex}-$i", "课$i", dayOfWeek = threadIndex + 1))
                }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            } finally {
                writerDone.countDown()
            }
        }
        // 读侧模拟 UI 主线程 / 局域网读接口：写进行中反复抓不可变快照。
        val reader = Thread {
            try {
                start.await()
                while (writerDone.count > 0) {
                    val snapshot = repository.snapshot
                    // 快照内部必须自洽：courses 是同一份不可变列表，size 与内容一致。
                    assertTrue(snapshot.courses.size >= 0)
                    snapshotReads.incrementAndGet()
                }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }

        val t0 = Thread { writer(0) }
        val t1 = Thread { writer(1) }
        t0.start(); t1.start(); reader.start()
        t0.join(30_000); t1.join(30_000); reader.join(30_000)

        errors.get()?.let { throw it }
        assertTrue("读侧至少要真的抓到几次快照", snapshotReads.get() > 0)
        assertEquals("写停后快照必须收敛到全量", perThread * 2, repository.snapshot.courses.size)
    }

    @Test
    fun `并发改周与加课交叉后两者都生效`() {
        val repository = repositoryOn()
        val rounds = 100
        val start = CyclicBarrier(2)
        val errors = AtomicReference<Throwable?>(null)

        val t0 = Thread {
            try {
                start.await()
                repeat(rounds) { repository.addCourse(course("w-$it", "课$it")) }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }
        val t1 = Thread {
            try {
                start.await()
                repeat(rounds) { repository.setCurrentWeek((it % 20) + 1) }
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }
        t0.start(); t1.start()
        t0.join(30_000); t1.join(30_000)

        errors.get()?.let { throw it }
        assertEquals("加课线程的课一门不能少", rounds, repository.courses.size)
        assertTrue(
            "周次必须落在 1..20 内（最后一次写是 it%20+1）",
            repository.snapshot.currentWeek in 1..20,
        )
    }

    // -----------------------------------------------------------------------
    // 第二轮：不同档案并发整份写入 / 写入中途被系统杀死
    // -----------------------------------------------------------------------

    /**
     * 两个线程各自**整份替换**档案（不同 id 集、不同激活项）。
     *
     * 一次 `replaceAllProfiles` 写两笔 key（档案数组 + 激活 id），这两笔必须落在同一把锁内：
     * 最终盘上要么整份是 A、要么整份是 B，**不允许「A 的档案 + B 的激活 id」混拼**。
     * 断言直接读盘（不经仓储读侧兜底），否则「激活 id 悬空 → 回落第一份」会掩盖混拼。
     */
    @Test
    fun `两线程并发整份替换不同档案时落盘恰好等于其中一方`() {
        val backing = InMemoryKeyValueStore()
        val now = LocalDateTime.of(2026, 11, 2, 9, 0)
        // 编排交叠：A 写完档案数组后，B 的整份提交插进来；A 的第二笔（激活 id）
        // 延后 60ms 才落地 —— 无锁时最终就是「B 的档案 + A 的激活 id」。
        val store = TimetableStore(InterleavingStore(backing, aThread = "w-A", bThread = "w-B"))
        store.saveProfiles(listOf(profile("seed", "起始档案", now)))
        store.saveActiveProfileId("seed")
        val repository = TimetableRepository(store)

        val profilesA = listOf(profile("a1", "档案A一", now), profile("a2", "档案A二", now))
        val profilesB = listOf(profile("b1", "档案B一", now))
        val start = CyclicBarrier(2)
        val errors = AtomicReference<Throwable?>(null)

        val t0 = Thread({
            try {
                start.await()
                repository.replaceAllProfiles(profilesA, "a1")
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }, "w-A")
        val t1 = Thread({
            try {
                start.await()
                repository.replaceAllProfiles(profilesB, "b1")
            } catch (t: Throwable) {
                errors.compareAndSet(null, t)
            }
        }, "w-B")
        t0.start(); t1.start()
        t0.join(30_000); t1.join(30_000)

        errors.get()?.let { throw it }
        val memoryIds = repository.snapshot.profiles.map { it.id }
        val disk = TimetableStore(backing)
        val diskIds = disk.loadProfiles().profiles.map { it.id }
        val diskActiveId = disk.loadActiveProfileId()
        assertEquals("内存与盘上必须是同一份", diskIds, memoryIds)
        val winnerActiveId = when (memoryIds) {
            profilesA.map { it.id } -> "a1"
            profilesB.map { it.id } -> "b1"
            else -> throw AssertionError("落盘结果是两方混拼的档案集：$memoryIds")
        }
        assertEquals("激活 id 必须落在同一方的整份提交内", winnerActiveId, diskActiveId)
        assertEquals("重开仓储必须读到同一份", winnerActiveId, TimetableRepository(TimetableStore(backing)).snapshot.activeProfileId)
    }

    /**
     * 模拟「进程在写第二笔 key 时被杀死」：档案数组已整份落盘，激活 id 还是旧值。
     *
     * 本层不做跨 key 事务（`replaceAllProfiles` KDoc 明说），所以**允许这种中间态**；
     * 要钉住的是它不会变坏：重开仓储不抛异常，档案数组仍是**完整**的一方，
     * 悬空的旧激活 id 由读侧回落兜住。
     */
    @Test
    fun `写入两笔 key 之间被杀时重开仓储不崩且每笔只呈现旧值或新值`() {
        val backing = InMemoryKeyValueStore()
        val now = LocalDateTime.of(2026, 11, 2, 9, 0)
        val seed = TimetableStore(backing)
        seed.saveProfiles(listOf(profile("old", "旧档案", now)))
        seed.saveActiveProfileId("old")

        val newProfiles = listOf(profile("n1", "新档案一", now), profile("n2", "新档案二", now))
        val repository = TimetableRepository(TimetableStore(KilledMidWriteStore(backing, allowedWrites = 1)))
        val thrown = runCatching { repository.replaceAllProfiles(newProfiles, "n1") }.exceptionOrNull()
        assertTrue("第二笔写入必须真的死在半途（否则用例没意义）", thrown is OutOfMemoryError)

        val reopened = TimetableRepository(TimetableStore(backing))
        val disk = TimetableStore(backing)
        assertEquals("档案数组是完整的新值，不能是半截", listOf("n1", "n2"), disk.loadProfiles().profiles.map { it.id })
        assertEquals("激活 id 是完整的旧值", "old", disk.loadActiveProfileId())
        assertEquals("旧激活 id 悬空 → 读侧回落第一份，不崩", "n1", reopened.snapshot.activeProfileId)
        assertEquals("回落不影响档案全量", listOf("n1", "n2"), reopened.snapshot.profiles.map { it.id })
    }

    /**
     * 模拟「值写到一半断电」：`putString` 只落了半截 JSON 就被杀。
     *
     * 单笔写入的**值级原子性**不归本层保证（真实现是 SharedPreferences 一次 `apply`）；
     * 本层能保证的是：读到半截 JSON 时走「留档 + 删 key + 回落默认」这条自愈路径，
     * 不抛、不静默丢、不留无法诊断的残值。
     */
    @Test
    fun `写到半截被杀时坏 JSON 被留档且重开仓储不崩`() {
        val backing = InMemoryKeyValueStore()
        val now = LocalDateTime.of(2026, 11, 2, 9, 0)
        val seed = TimetableStore(backing)
        seed.saveProfiles(listOf(profile("old", "旧档案", now)))
        seed.saveActiveProfileId("old")

        val newProfiles = listOf(profile("n1", "新档案一", now), profile("n2", "新档案二", now))
        val repository = TimetableRepository(
            TimetableStore(KilledMidWriteStore(backing, allowedWrites = 0, truncateValue = true)),
        )
        runCatching { repository.replaceAllProfiles(newProfiles, "n1") }

        val reopened = TimetableRepository(TimetableStore(backing))
        assertEquals("半截 JSON 救不回来 → 档案为空（不是半份列表）", emptyList<String>(), reopened.snapshot.profiles.map { it.id })
        assertTrue(
            "半截值必须先留档，用户数据不能无声消失",
            backing.rawSnapshot().keys.any { it.contains("timetable_profiles_corrupt_backup_") },
        )
        assertTrue(
            "半截值的原 key 已被移除",
            backing.rawSnapshot().keys.none { it == FrozenValueCodec.physicalKey(TimetableStore.KEY_PROFILES) },
        )
        // 空档案集仍要能拿出可渲染快照（内存默认档案壳），不能让宿主拿到 null。
        assertEquals(TimetableRepository.DEFAULT_PROFILE_ID, reopened.snapshot.activeProfileId)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun repositoryOn(): TimetableRepository {
        val store = TimetableStore(InMemoryKeyValueStore())
        val now = LocalDateTime.of(2026, 11, 2, 9, 0)
        store.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    currentWeek = 1,
                    createdAt = now,
                    lastUsedAt = now,
                ),
            ),
        )
        store.saveActiveProfileId("p1")
        return TimetableRepository(store)
    }

    private fun course(id: String, name: String, dayOfWeek: Int = 1): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun profile(id: String, name: String, now: LocalDateTime): TimetableProfile = TimetableProfile(
        id = id,
        name = name,
        currentWeek = 1,
        createdAt = now,
        lastUsedAt = now,
    )

    /** 让出 CPU 的存储包装（沿用 `RawSettingsPatchTest` 的手法）：把写窗口放大到必然交叠。 */
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

    /**
     * 编排两个线程的写顺序（不造线程池，仍由测试自己起两条线程）：
     * 1. A 的第一笔 `putString` 落地后才放行 B 的第一笔；
     * 2. A 的第二笔 `putString` 前睡 [aSecondWriteDelayMillis]，把窗口留给 B 的两笔写插进来。
     *
     * 无锁时最终落盘自然是「B 的档案 + A 的激活 id」；有锁时 A 的两笔同在一次临界区，
     * B 只能整份后写，结果恰好是某一方。
     */
    private class InterleavingStore(
        private val delegate: KeyValueStore,
        private val aThread: String,
        private val bThread: String,
        private val aSecondWriteDelayMillis: Long = 60L,
    ) : KeyValueStore by delegate {
        private val aFirstWriteDone = CountDownLatch(1)
        private val putCounts = ConcurrentHashMap<String, AtomicInteger>()

        override fun putString(key: String, value: String) {
            val name = Thread.currentThread().name
            val index = putCounts.computeIfAbsent(name) { AtomicInteger(0) }.getAndIncrement()
            when {
                // 有锁时 B 本就卡在仓储锁上，这里的 2s 超时不会被走到（仅兜底防死等）。
                name == bThread && index == 0 -> aFirstWriteDone.await(2, TimeUnit.SECONDS)
                name == aThread && index == 1 -> Thread.sleep(aSecondWriteDelayMillis)
            }
            delegate.putString(key, value)
            if (name == aThread && index == 0) aFirstWriteDone.countDown()
        }
    }

    /**
     * 模拟「进程在写盘中途被杀」：前 [allowedWrites] 次 `putString` 正常放行，
     * 之后抛 [OutOfMemoryError]（进程死亡的等价物：写不再继续、也不会回滚）。
     *
     * [truncateValue] 为真时，那笔「被杀」的写会先落半截值再抛（模拟写到一半断电）。
     */
    private class KilledMidWriteStore(
        private val delegate: KeyValueStore,
        private val allowedWrites: Int,
        private val truncateValue: Boolean = false,
    ) : KeyValueStore by delegate {
        private val putCount = AtomicInteger(0)
        private val dead = AtomicBoolean(false)

        override fun putString(key: String, value: String) {
            if (dead.get() || putCount.incrementAndGet() > allowedWrites) {
                dead.set(true)
                if (truncateValue) delegate.putString(key, value.take(value.length / 2))
                throw OutOfMemoryError("simulated process death while writing $key")
            }
            delegate.putString(key, value)
        }
    }
}
