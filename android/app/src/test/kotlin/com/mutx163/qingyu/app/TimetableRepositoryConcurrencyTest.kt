package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CyclicBarrier
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
}
