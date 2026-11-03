package com.mutx163.qingyu.core.permission

import com.mutx163.qingyu.core.permission.PermissionStage.DENIED_ONCE
import com.mutx163.qingyu.core.permission.PermissionStage.GRANTED
import com.mutx163.qingyu.core.permission.PermissionStage.NOT_REQUESTED
import com.mutx163.qingyu.core.permission.PermissionStage.PERMANENTLY_DENIED
import com.mutx163.qingyu.core.permission.PermissionStage.REQUESTING
import com.mutx163.qingyu.core.permission.PermissionStep.LaunchRequest
import com.mutx163.qingyu.core.permission.PermissionStep.OpenSettings
import com.mutx163.qingyu.core.permission.PermissionStep.Proceed
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 共用权限状态机全路径（旧版权限行为的状态化移植）。
 *
 * 对齐旧版语义的出处：
 * - 首次点入口直接弹系统框、拒绝一次后再点再弹：`device_location_service.dart:302-305`
 *   （`checkPermission` → `denied` 则 `requestPermission`）；
 * - 「拒绝且系统不再问」= 永久拒绝：geolocator `deniedForever`（`device_location_service.dart:309-310`）；
 * - 从设置回来按系统真实状态自愈：`QrCameraHost` ON_RESUME 观察（`QrCameraHost.kt:121-131`）。
 */
class PermissionFlowLogicTest {

    // ---------- 初始态 ----------

    @Test
    fun `初始未授予时入口触发弹系统框`() {
        val flow = PermissionFlow(initiallyGranted = false)
        assertEquals(NOT_REQUESTED, flow.stage)
        assertEquals(LaunchRequest, flow.onTrigger())
        assertEquals(REQUESTING, flow.stage)
    }

    @Test
    fun `初始已授予时入口直接放行`() {
        val flow = PermissionFlow(initiallyGranted = true)
        assertEquals(GRANTED, flow.stage)
        assertTrue(flow.isGranted)
        assertEquals(Proceed, flow.onTrigger())
    }

    // ---------- 系统弹框结果 ----------

    @Test
    fun `授予后回到已授予且入口放行`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        assertEquals(GRANTED, flow.onSystemResult(granted = true, canAskAgain = false))
        assertTrue(flow.isGranted)
        assertFalse(flow.shouldExplain)
        assertFalse(flow.shouldOpenSettings)
        assertEquals(Proceed, flow.onTrigger())
    }

    @Test
    fun `拒绝且系统还会再问进入拒绝一次态`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        assertEquals(DENIED_ONCE, flow.onSystemResult(granted = false, canAskAgain = true))
        assertTrue(flow.shouldExplain)
        assertFalse(flow.shouldOpenSettings)
    }

    @Test
    fun `拒绝且系统不再问进入永久拒绝态`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        assertEquals(PERMANENTLY_DENIED, flow.onSystemResult(granted = false, canAskAgain = false))
        assertTrue(flow.shouldOpenSettings)
        assertFalse(flow.shouldExplain)
    }

    // ---------- 拒绝后的再触发 ----------

    @Test
    fun `拒绝一次后入口仍会再弹系统框（对齐旧版再次 requestPermission）`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        flow.onSystemResult(granted = false, canAskAgain = true)
        assertEquals(LaunchRequest, flow.onTrigger())
    }

    @Test
    fun `永久拒绝后入口改为跳系统设置`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        flow.onSystemResult(granted = false, canAskAgain = false)
        assertEquals(OpenSettings, flow.onTrigger())
        // 跳设置不改阶段：用户可能不去开就返回，下次入口仍是 OpenSettings。
        assertEquals(PERMANENTLY_DENIED, flow.stage)
    }

    @Test
    fun `申请中重复触发防抖不重发（对齐相机状态机 None）`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        assertEquals(Proceed, flow.onTrigger())
        assertEquals(REQUESTING, flow.stage)
    }

    // ---------- 回前台自愈 ----------

    @Test
    fun `永久拒绝后用户去设置开了权限回前台自愈为已授予`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        flow.onSystemResult(granted = false, canAskAgain = false)
        assertEquals(GRANTED, flow.onHostResumed(grantedNow = true))
        assertEquals(Proceed, flow.onTrigger())
    }

    @Test
    fun `已授予后用户在设置里收回权限回前台降级为拒绝一次`() {
        val flow = PermissionFlow(initiallyGranted = true)
        assertEquals(DENIED_ONCE, flow.onHostResumed(grantedNow = false))
        // 收回后再点入口还能弹框（系统可能重新询问）。
        assertEquals(LaunchRequest, flow.onTrigger())
    }

    @Test
    fun `申请中弹框被外界取消回前台降级为拒绝一次`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        assertEquals(DENIED_ONCE, flow.onHostResumed(grantedNow = false))
    }

    @Test
    fun `永久拒绝回前台仍未授予则保持永久拒绝`() {
        val flow = PermissionFlow()
        flow.onTrigger()
        flow.onSystemResult(granted = false, canAskAgain = false)
        assertEquals(PERMANENTLY_DENIED, flow.onHostResumed(grantedNow = false))
        assertEquals(OpenSettings, flow.onTrigger())
    }

    // ---------- 完整旅程（授予 / 永久拒绝两条到头） ----------

    @Test
    fun `完整旅程-用户拒绝一次后改主意授予`() {
        val flow = PermissionFlow()
        assertEquals(LaunchRequest, flow.onTrigger())
        flow.onSystemResult(granted = false, canAskAgain = true) // 第一次拒绝
        assertEquals(LaunchRequest, flow.onTrigger()) // 再点再弹
        flow.onSystemResult(granted = true, canAskAgain = false)
        assertTrue(flow.isGranted)
    }

    @Test
    fun `完整旅程-勾选不再询问后只能去设置并在回来时接上原流程`() {
        val flow = PermissionFlow()
        assertEquals(LaunchRequest, flow.onTrigger())
        flow.onSystemResult(granted = false, canAskAgain = false) // 勾了不再询问
        assertEquals(OpenSettings, flow.onTrigger()) // 入口引导去设置
        assertEquals(GRANTED, flow.onHostResumed(grantedNow = true)) // 用户开完回来
        assertEquals(Proceed, flow.onTrigger()) // 入口继续原流程
    }
}
