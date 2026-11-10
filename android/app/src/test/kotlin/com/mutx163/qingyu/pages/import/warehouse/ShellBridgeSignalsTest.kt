package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壳桥纯逻辑单测（2026-11-10 第二波）。
 *
 * 这一批修的是「桥每个路由条目一份」造成的三处失效。桥的宿主是 composeP1 里的进程级
 * object（进不了 JVM 单测），但它的**语义**放在 [ImportCompletionCounter] / [ShellOutboundSlot]
 * 里——本测试直接钉这些语义，而不是只读源码文本：
 *
 * 1. 入口页只认自己挂载**之后**增长的成功代数（外部导入的旧成功不许秒关下一次入口页）；
 * 2. 发送槽把字节与发送范围标题一起带过页（后一次覆盖前一次）。
 */
class ShellBridgeSignalsTest {

    // ── 导入成功代数 ────────────────────────────────────────────────────

    @Test
    fun `入口页挂载后子页成功 代数必须增长`() {
        val counter = ImportCompletionCounter()
        val mounted = counter.snapshot()

        counter.markImported()

        assertTrue(
            "子页导入成功后代数没有增长：入口页的 LaunchedEffect 不会触发，页面不会自关。",
            counter.snapshot() > mounted,
        )
    }

    @Test
    fun `外部打开方式导入留下的旧成功 不会关掉下一次进入的入口页`() {
        val counter = ImportCompletionCounter()
        // 外部「打开方式」直接进 ICS/表格导入：成功时代数增长，但没有入口页在等。
        counter.markImported()

        val laterMount = counter.snapshot()
        assertEquals(
            "新入口页挂载时把上一趟的旧成功当成了新信号（会一进页面就自关）。",
            false,
            counter.snapshot() > laterMount,
        )

        // 这一趟自己的子页成功才算数。
        counter.markImported()
        assertTrue(counter.snapshot() > laterMount)
    }

    @Test
    fun `代数单调递增 多次成功逐次可区分`() {
        val counter = ImportCompletionCounter()
        assertEquals(0, counter.snapshot())
        counter.markImported()
        assertEquals(1, counter.snapshot())
        counter.markImported()
        assertEquals(2, counter.snapshot())
    }

    // ── 发送槽 ──────────────────────────────────────────────────────────

    @Test
    fun `发送槽把字节与标题一起带过页`() {
        val slot = ShellOutboundSlot()
        val payload = byteArrayOf(1, 2, 3)

        slot.publish(payload, "发送全部数据")

        val current = slot.current()
        assertEquals("发送页标题没有跟着字节过页（两种发送范围会看起来一样）。", "发送全部数据", current?.title)
        assertTrue("发送字节没有过页（发送页 session 会是 null、出不了码）。", payload.contentEquals(current?.payload))
    }

    @Test
    fun `发送槽后一次覆盖前一次`() {
        val slot = ShellOutboundSlot()
        slot.publish(byteArrayOf(1), "发送当前课表")
        slot.publish(byteArrayOf(2), "发送全部数据")

        assertEquals("发送全部数据", slot.current()?.title)
        assertTrue(byteArrayOf(2).contentEquals(slot.current()?.payload))
    }

    @Test
    fun `空槽返回 null 标题可为空`() {
        assertNull(ShellOutboundSlot().current())

        val slot = ShellOutboundSlot()
        slot.publish(byteArrayOf(9), null)
        assertNull(slot.current()?.title)
        assertTrue(byteArrayOf(9).contentEquals(slot.current()?.payload))
    }

    @Test
    fun `发送页离开时清空槽_幂等且可再次发送`() {
        val slot = ShellOutboundSlot()
        slot.publish(byteArrayOf(1, 2, 3), "发送当前课表")

        slot.clear()
        assertNull(
            "离开发送页后槽必须清空：进程级 object 不许把最后一次 16MB/64MB 的包留到进程结束。",
            slot.current(),
        )

        // 幂等：back 与 onDispose 会各调一次，第二次不能抛。
        slot.clear()
        assertNull(slot.current())

        // 清空后下一次发送照常可用（进程内多次打开发送页）。
        slot.publish(byteArrayOf(4), "发送全部数据")
        assertTrue(byteArrayOf(4).contentEquals(slot.current()?.payload))
        assertEquals("发送全部数据", slot.current()?.title)
    }
}
