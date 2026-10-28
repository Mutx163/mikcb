package com.mutx163.qingyu.share.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraPermissionStateMachineTest {

    @Test
    fun `初始未授权状态机行为`() {
        val sm = CameraPermissionStateMachine(initialHasPermission = false)
        assertEquals(PermissionState.NOT_REQUESTED, sm.state)
        assertFalse(sm.isGranted)
        assertTrue(sm.canRequest)
        assertFalse(sm.requiresSettings)

        // 发起请求：进入 REQUESTING，动作是 Request
        val action = sm.onRequestPermission()
        assertEquals(PermissionAction.Request, action)
        assertEquals(PermissionState.REQUESTING, sm.state)
    }

    @Test
    fun `初始已授权状态机行为`() {
        val sm = CameraPermissionStateMachine(initialHasPermission = true)
        assertEquals(PermissionState.GRANTED, sm.state)
        assertTrue(sm.isGranted)
        assertFalse(sm.canRequest)

        val action = sm.onRequestPermission()
        assertEquals(PermissionAction.None, action)
    }

    @Test
    fun `用户同意授权流转`() {
        val sm = CameraPermissionStateMachine()
        sm.onRequestPermission()
        val newState = sm.onPermissionResult(granted = true, shouldShowRationale = false)
        assertEquals(PermissionState.GRANTED, newState)
        assertTrue(sm.isGranted)
        assertFalse(sm.canRequest)
    }

    @Test
    fun `用户单次拒绝流转至 DENIED 并支持 Rationale 引导`() {
        val sm = CameraPermissionStateMachine()
        sm.onRequestPermission()

        // 首次拒绝，系统 shouldShowRationale 返回 true
        val newState = sm.onPermissionResult(granted = false, shouldShowRationale = true)
        assertEquals(PermissionState.DENIED, newState)
        assertFalse(sm.isGranted)
        assertTrue(sm.canRequest)

        // 再次点击申请：状态机输出 ShowRationale，不直接弹系统窗
        val action = sm.onRequestPermission()
        assertTrue(action is PermissionAction.ShowRationale)
        assertEquals(PermissionState.REQUESTING, sm.state)

        // 用户确认 Rationale 后正式提交系统请求
        val confirmAction = sm.onRationaleConfirmed()
        assertEquals(PermissionAction.Request, confirmAction)
    }

    @Test
    fun `用户勾选不再询问流转至 PERMANENTLY_DENIED 引导去设置`() {
        val sm = CameraPermissionStateMachine()
        sm.onRequestPermission()

        // 拒绝且勾选不再询问，系统 shouldShowRationale 返回 false
        val newState = sm.onPermissionResult(granted = false, shouldShowRationale = false)
        assertEquals(PermissionState.PERMANENTLY_DENIED, newState)
        assertFalse(sm.isGranted)
        assertFalse(sm.canRequest)
        assertTrue(sm.requiresSettings)

        // 后续点击只能引导去系统设置
        val action = sm.onRequestPermission()
        assertEquals(PermissionAction.OpenSettings, action)
    }

    @Test
    fun `用户从系统设置返回前台的权限自愈与收回检测`() {
        val sm = CameraPermissionStateMachine()
        sm.onRequestPermission()
        sm.onPermissionResult(granted = false, shouldShowRationale = false)
        assertEquals(PermissionState.PERMANENTLY_DENIED, sm.state)

        // 用户切到系统设置并开启了权限，返回前台 onResume 检测到物理权限
        sm.onAppResume(hasSystemPermission = true)
        assertEquals(PermissionState.GRANTED, sm.state)
        assertTrue(sm.isGranted)

        // 如果在后台被系统或用户在设置中收回权限
        sm.onAppResume(hasSystemPermission = false)
        assertEquals(PermissionState.DENIED, sm.state)
        assertFalse(sm.isGranted)
    }

    @Test
    fun `重置状态机`() {
        val sm = CameraPermissionStateMachine(initialHasPermission = true)
        assertEquals(PermissionState.GRANTED, sm.state)
        sm.reset(hasPermission = false)
        assertEquals(PermissionState.NOT_REQUESTED, sm.state)
    }
}
