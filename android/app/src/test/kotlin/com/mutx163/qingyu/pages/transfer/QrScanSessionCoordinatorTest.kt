package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.camera.BarcodeScanResult
import com.mutx163.qingyu.share.camera.CameraPermissionStateMachine
import com.mutx163.qingyu.share.camera.PermissionAction
import com.mutx163.qingyu.share.camera.PermissionState
import com.mutx163.qingyu.share.camera.ScanClock
import com.mutx163.qingyu.share.camera.ScanPipeline
import com.mutx163.qingyu.share.camera.ScanPipelineConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 扫码会话协调器单测（Phase 3.5 · P35-B6）。
 *
 * ## 期望值是哪来的
 *
 * 全部是**人推的**，不是从实现里抄的：
 * - 节流 100ms / 去重窗口 1500ms / 跨码防抖 250ms 是 [ScanPipelineConfig] 的公开默认值；
 * - 「同一码在冷却窗口内只回调一次」是产品行为（拿手机对着同一张二维码别弹两次）；
 * - 「冷却窗口过后还能再扫到」同样是产品行为（用户回头再扫一次必须有效）。
 *
 * 时钟注入虚拟值，所以「连续 30 帧」在测试里不睡觉、不依赖真机。
 */
class QrScanSessionCoordinatorTest {

    private class FakeClock(var now: Long = 0L) : ScanClock {
        override fun currentTimeMillis(): Long = now
    }

    private fun grantedCoordinator(clock: FakeClock = FakeClock(1_000L)): QrScanSessionCoordinator {
        val pipeline = ScanPipeline(
            config = ScanPipelineConfig(),
            clock = clock,
            initialHasPermission = true,
        )
        return QrScanSessionCoordinator(pipeline)
    }

    private fun result(value: String, timestampMs: Long) = BarcodeScanResult(
        rawValue = value,
        timestampEpochMs = timestampMs,
    )

    @Test
    fun `权限未授予时一帧都不放行_连计数都不该增加`() {
        val clock = FakeClock(1_000L)
        val coordinator = QrScanSessionCoordinator(ScanPipeline(clock = clock, initialHasPermission = false))

        assertFalse("没权限不该放帧", coordinator.beginFrame(1_000L))
        assertFalse(coordinator.beginFrame(1_100L))
        // 关键：被权限挡下的帧**没有**进入节流统计 —— 说明解码器根本不会被叫到，不是「解了再丢」。
        assertEquals(0L, coordinator.pipeline.throttler.totalFramesReceived)

        coordinator.onPermissionResult(granted = true, shouldShowRationale = false)
        assertTrue("授权后应立刻放行", coordinator.beginFrame(1_200L))
    }

    @Test
    fun `同一码在冷却窗口内只回调一次`() {
        val coordinator = grantedCoordinator()

        // 第 1 帧：解出 "QR-A"，应交给业务。
        assertTrue(coordinator.beginFrame(1_000L))
        coordinator.endFrame(1_000L)
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 1_000L)))

        // 之后 1.4 秒内同一码连续命中（相机每秒出十几帧），一次都不能再回调。
        var frame = 1_100L
        while (frame < 2_400L) {
            assertTrue(coordinator.beginFrame(frame))
            coordinator.endFrame(frame)
            assertNull("冷却窗口内重复命中必须被抑制（frame=$frame）", coordinator.deliverDecoded(result("QR-A", frame)))
            frame += 100L
        }

        assertEquals("同一码只该回调 1 次", 1, coordinator.deliveredCount)
    }

    @Test
    fun `冷却窗口过后同一码可以再次扫到`() {
        val coordinator = grantedCoordinator()
        coordinator.beginFrame(1_000L)
        coordinator.endFrame(1_000L)
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 1_000L)))

        // 1500ms 冷却窗口 + 250ms 全局防抖都过去了，用户回头再扫同一张码必须有效。
        coordinator.beginFrame(2_800L)
        coordinator.endFrame(2_800L)
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 2_800L)))
        assertEquals(2, coordinator.deliveredCount)
    }

    @Test
    fun `不同码在全局防抖窗口内被抑制`() {
        val coordinator = grantedCoordinator()
        coordinator.beginFrame(1_000L)
        coordinator.endFrame(1_000L)
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 1_000L)))

        // 100ms 后视野里晃过另一张码：防抖窗口 250ms 内不许切换，否则界面会剧烈抖动。
        coordinator.beginFrame(1_100L)
        coordinator.endFrame(1_100L)
        assertNull(coordinator.deliverDecoded(result("QR-B", 1_100L)))

        // 300ms 后同一张新码再出现：窗口过了，应放行。
        coordinator.beginFrame(1_400L)
        coordinator.endFrame(1_400L)
        assertNotNull(coordinator.deliverDecoded(result("QR-B", 1_400L)))
        assertEquals(2, coordinator.deliveredCount)
    }

    @Test
    fun `帧节流_同一帧周期内只解一次`() {
        val coordinator = grantedCoordinator()
        assertTrue(coordinator.beginFrame(1_000L))
        coordinator.endFrame(1_000L)

        assertFalse("50ms 后的帧应被 100ms 节流拦下", coordinator.beginFrame(1_050L))
        assertTrue("100ms 后的帧应放行", coordinator.beginFrame(1_100L))
        assertEquals(1L, coordinator.pipeline.throttler.framesDroppedInterval)
    }

    @Test
    fun `解码未完时新帧被丢弃_结算后才放行`() {
        val coordinator = grantedCoordinator()
        assertTrue(coordinator.beginFrame(1_000L))
        // 上一帧还在解码（没有 endFrame）：这一帧必须丢，否则会排队积压、越扫越旧。
        assertFalse(coordinator.beginFrame(1_100L))
        coordinator.endFrame(1_150L)
        assertTrue(coordinator.beginFrame(1_200L))
        assertEquals(1L, coordinator.pipeline.throttler.framesDroppedBusy)
    }

    @Test
    fun `空白内容不当作有效扫码`() {
        val coordinator = grantedCoordinator()
        assertNull(coordinator.deliverDecoded(null))
        assertNull(coordinator.deliverDecoded(result("   ", 1_000L)))
        assertEquals(0, coordinator.deliveredCount)
        // 空白帧不该占用去重状态，否则紧接着的真码会被当成「重复」放不进来。
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 1_000L)))
    }

    @Test
    fun `重置后同一码可以立刻重新扫到`() {
        val coordinator = grantedCoordinator()
        coordinator.beginFrame(1_000L)
        coordinator.endFrame(1_000L)
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 1_000L)))
        assertNull(coordinator.deliverDecoded(result("QR-A", 1_100L)))

        coordinator.reset()
        assertEquals(0, coordinator.deliveredCount)
        // 重置只清去重/节流，权限结论要留着（否则每次重来都要再弹一次系统框）。
        assertTrue(coordinator.isPermissionGranted)
        assertNotNull(coordinator.deliverDecoded(result("QR-A", 1_200L)))
    }

    @Test
    fun `权限状态机与B5保持同一份状态`() {
        val coordinator = QrScanSessionCoordinator(ScanPipeline(initialHasPermission = false))
        assertEquals(PermissionState.NOT_REQUESTED, coordinator.permissionState)

        // 首次申请：应当要求弹系统框。
        assertTrue(coordinator.onPermissionRequested() is PermissionAction.Request)
        assertEquals(PermissionState.REQUESTING, coordinator.permissionState)

        // 用户拒绝且没勾「不再询问」：进入可解释的拒绝态。
        assertEquals(
            PermissionState.DENIED,
            coordinator.onPermissionResult(granted = false, shouldShowRationale = true),
        )
        assertFalse(coordinator.isPermissionGranted)

        // 二次申请：先给理由再弹框。
        val second = coordinator.onPermissionRequested()
        assertTrue(second is PermissionAction.ShowRationale)
        assertEquals(
            CameraPermissionStateMachine().rationaleMessage,
            (second as PermissionAction.ShowRationale).message,
        )

        // 勾了「不再询问」：只能去系统设置。
        assertEquals(PermissionState.PERMANENTLY_DENIED, coordinator.onPermissionResult(granted = false, shouldShowRationale = false))
        assertTrue(coordinator.onPermissionRequested() is PermissionAction.OpenSettings)
    }

    @Test
    fun `宿主回前台时跟随真实权限收回`() {
        val coordinator = grantedCoordinator()
        assertTrue(coordinator.isPermissionGranted)

        // 用户在系统设置里关掉了相机权限，回到 App：必须立刻停止放帧。
        assertEquals(PermissionState.DENIED, coordinator.onHostResumed(hasSystemPermission = false))
        assertFalse(coordinator.beginFrame(2_000L))

        // 又去设置里开回来：恢复放帧。
        assertEquals(PermissionState.GRANTED, coordinator.onHostResumed(hasSystemPermission = true))
        assertTrue(coordinator.beginFrame(2_100L))
    }
}
