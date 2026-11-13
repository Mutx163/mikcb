package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 执行窗口预算的纯逻辑（[WarehouseExecutionTimerPolicy]）。
 *
 * ## 这一组测试能证明什么、不能证明什么
 *
 * 能证明的：**预算只累计「没有用户交互」的时间**——暂停期间不走表、恢复后不重开满额、
 * 有弹窗挂着时任何时刻都不会 fire。这是「暂停即不可能超时」模型在逻辑层的全部承诺。
 *
 * **它替不了真机**：这些用例喂的是假时钟（`nowMs` 参数），测的是策略对象自己的账。
 * 「用户在真机上把弹窗放十分钟，App 真的不超时」要真机跑一遍——宿主里
 * `pause/resume` 有没有接在弹窗的创建/清理处、Compose 状态在真机重组成什么顺序，
 * JVM 单测都看不见。所以本文件**不构成**「真机不超时」的证据。
 */
class WarehouseExecutionTimerPolicyTest {

    private val limitMs = 60_000L

    @Test
    fun `没有弹窗时到点就要收尾`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)

        assertFalse("刚起步不该 fire", policy.shouldFire(0L, limitMs, pendingDialogCount = 0))
        assertFalse("差 1ms 不该 fire", policy.shouldFire(limitMs - 1L, limitMs, pendingDialogCount = 0))
        assertTrue("到点必须 fire", policy.shouldFire(limitMs, limitMs, pendingDialogCount = 0))
        assertTrue("过了也照样 fire", policy.shouldFire(limitMs * 5, limitMs, pendingDialogCount = 0))
    }

    @Test
    fun `没有开始就永远不 fire`() {
        val policy = WarehouseExecutionTimerPolicy()
        assertFalse("未 start 的执行窗口不该 fire", policy.shouldFire(10_000_000L, limitMs, 0))
        assertEquals("未 start 的 elapsed 必须是 0", 0L, policy.elapsedMs(10_000_000L))
    }

    /**
     * 核心用例：**弹窗挂着的十分钟里，即使真实时间早就超了预算，也不许 fire**。
     *
     * 它替不了真机——它只证「逻辑上没有上限被触碰」：挂起期间 elapsed 不涨，
     * `shouldFire` 的两道闸（`paused` 与 `pendingDialogCount == 0`）都关着。
     */
    @Test
    fun `有弹窗挂着时过十分钟也不 fire`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)
        // 跑到 30 秒时网页弹了个确认框。
        policy.pause(nowMs = 30_000L)

        val tenMinutesLater = 30_000L + 10 * 60 * 1000L
        assertEquals(
            "暂停期不计入：elapsed 必须停在暂停那一刻的 30 秒（不是 10 分 30 秒）",
            30_000L,
            policy.elapsedMs(tenMinutesLater),
        )
        assertFalse(
            "有挂起弹窗就不许 fire——用户读弹窗的时间不是脚本的预算",
            policy.shouldFire(tenMinutesLater, limitMs, pendingDialogCount = 1),
        )
    }

    /**
     * 纵深防御：就算暂停接线坏了（`paused` 没被置上），只要还有弹窗挂着也不许 fire。
     *
     * 宿主里那道 `check(pendingDialogCount == 0)` 就是靠这条兜底的——两层都不许破。
     */
    @Test
    fun `暂停失效时挂起数量仍然挡住 fire`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)

        assertFalse(
            "没 pause 但有一个弹窗挂着：shouldFire 必须看 pendingDialogCount",
            policy.shouldFire(limitMs * 2, limitMs, pendingDialogCount = 1),
        )
        assertTrue(
            "同一时刻没有弹窗了就该 fire（说明判据是数量而不是别的）",
            policy.shouldFire(limitMs * 2, limitMs, pendingDialogCount = 0),
        )
    }

    @Test
    fun `暂停段不计入恢复后的 elapsed`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 1_000L)
        // 走 20 秒。
        assertEquals(20_000L, policy.elapsedMs(21_000L))
        // 弹窗挂 5 分钟。
        policy.pause(nowMs = 21_000L)
        policy.resume(nowMs = 321_000L)
        // 恢复后 1 秒：账面 21 秒，不是 5 分 21 秒。
        assertEquals(
            "暂停段必须被扣掉",
            21_000L,
            policy.elapsedMs(322_000L),
        )
        // 恢复后的走表是真的在走（不是把游标冻住）。
        assertEquals(22_000L, policy.elapsedMs(323_000L))
    }

    /**
     * 「应答本身不重置预算」——它的目的是让「多次应答 = 没有上限」不可能成立。
     */
    @Test
    fun `应答不重置预算_剩余时间不回到满额`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)
        // 已经花掉 50 秒，然后弹窗、用户答完。
        policy.pause(nowMs = 50_000L)
        policy.resume(nowMs = 50_000L)

        assertEquals(
            "恢复后剩余必须还是 10 秒（不是回到 60 秒）",
            10_000L,
            policy.remainingMs(50_000L, limitMs),
        )
        assertFalse(
            "还剩 10 秒，此刻不该 fire",
            policy.shouldFire(59_999L, limitMs, pendingDialogCount = 0),
        )
        assertTrue(
            "同一轮里剩下的 10 秒走完就 fire——预算不会被应答续命",
            policy.shouldFire(60_000L, limitMs, pendingDialogCount = 0),
        )
    }

    @Test
    fun `反复应答不会把预算续成无限`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)
        // 十轮「走 6 秒 → 弹窗挂很久 → 应答」：累计 60 秒后就该结束，不管应答了几次。
        var now = 0L
        repeat(9) {
            now += 6_000L
            policy.pause(nowMs = now)
            now += 60 * 60 * 1000L // 每轮用户都读了整整一小时
            policy.resume(nowMs = now)
        }
        assertEquals("九轮只累计 54 秒", 54_000L, policy.elapsedMs(now))
        assertFalse("还没到 60 秒", policy.shouldFire(now, limitMs, pendingDialogCount = 0))

        now += 6_000L
        policy.pause(nowMs = now)
        now += 60 * 60 * 1000L
        policy.resume(nowMs = now)
        assertEquals("十轮累计 60 秒", 60_000L, policy.elapsedMs(now))
        assertTrue(
            "累计到 60 秒必须 fire：应答再多次也不续命",
            policy.shouldFire(now, limitMs, pendingDialogCount = 0),
        )
    }

    @Test
    fun `重复暂停与重复恢复都是空操作`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)
        policy.pause(nowMs = 10_000L)
        // 第二次 pause 不许把同一段算两遍。
        policy.pause(nowMs = 20_000L)
        assertEquals("重复 pause 不许重复记账", 10_000L, policy.elapsedMs(30_000L))

        policy.resume(nowMs = 30_000L)
        // 没在暂停态时 resume 不许把游标挪走（挪走会把中间这段吞掉）。
        policy.resume(nowMs = 40_000L)
        assertEquals("重复 resume 不许吞掉时间", 20_000L, policy.elapsedMs(40_000L))
    }

    @Test
    fun `reset 之后回到未开始`() {
        val policy = WarehouseExecutionTimerPolicy()
        policy.start(nowMs = 0L)
        policy.pause(nowMs = 5_000L)
        policy.reset()

        assertFalse("reset 后不该还在跑", policy.started)
        assertFalse("reset 后不该还在暂停态", policy.paused)
        assertEquals(0L, policy.accumulatedMs)
        assertFalse("reset 后任何时刻都不 fire", policy.shouldFire(99_999L, limitMs, 0))
    }
}
