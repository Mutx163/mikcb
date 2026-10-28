package com.mutx163.qingyu.share.camera

/**
 * 相机权限状态枚举。
 */
enum class PermissionState {
    /** 初始状态：尚未向系统发起过权限请求。 */
    NOT_REQUESTED,

    /** 正在请求中：系统权限弹窗已弹出，等待用户选择。 */
    REQUESTING,

    /** 已授予：用户已授权相机权限，可以安全开启相机。 */
    GRANTED,

    /** 已拒绝（临时拒绝）：用户本次拒绝，但尚未勾选「不再询问」，可出 rationale 引导二次请求。 */
    DENIED,

    /** 永久拒绝：用户勾选了「不再询问」或设备策略限制，只能引导用户去「系统应用设置」开启。 */
    PERMANENTLY_DENIED,
}

/**
 * 权限状态机建议 UI 执行的动作。
 */
sealed class PermissionAction {
    /** 无需动作。 */
    object None : PermissionAction()

    /** 触发系统权限请求弹窗（如 ActivityCompat.requestPermissions）。 */
    object Request : PermissionAction()

    /** 显示权限解释理由（Rationale）弹窗或提示。 */
    data class ShowRationale(val message: String) : PermissionAction()

    /** 跳转系统应用详情设置页（Intent ACTION_APPLICATION_DETAILS_SETTINGS）。 */
    object OpenSettings : PermissionAction()
}

/**
 * 相机权限状态机（纯 Kotlin 实现，零 Android SDK 耦合，JVM 确定性测试）。
 *
 * 状态机维护用户对相机权限的授予流转，对以下典型生命周期场景进行状态闭环：
 * 1. 首次进入扫码页：NOT_REQUESTED -> 请求权限 -> GRANTED 或 DENIED；
 * 2. 二次进入或被拒后重试：DENIED -> 弹出 Rationale 解释 -> 二次请求；
 * 3. 勾选不再询问：PERMANENTLY_DENIED -> 引导去系统设置；
 * 4. 从后台或系统设置返回（onAppResume）：检测物理权限变化（去设置里开启了、或在设置里关掉了）。
 */
class CameraPermissionStateMachine(
    initialHasPermission: Boolean = false,
    val rationaleMessage: String = "相机权限用于扫描课表数据传输二维码",
) {
    var state: PermissionState = if (initialHasPermission) {
        PermissionState.GRANTED
    } else {
        PermissionState.NOT_REQUESTED
    }
        private set

    /** 是否已获得权限。 */
    val isGranted: Boolean get() = state == PermissionState.GRANTED

    /** 是否可以发起请求（未请求或被临时拒绝）。 */
    val canRequest: Boolean
        get() = state == PermissionState.NOT_REQUESTED || state == PermissionState.DENIED

    /** 是否需要引导去设置。 */
    val requiresSettings: Boolean get() = state == PermissionState.PERMANENTLY_DENIED

    /**
     * 用户点击「允许使用相机」或页面主动触发权限申请。
     *
     * @return 建议 UI 层的下一步动作。
     */
    fun onRequestPermission(): PermissionAction {
        return when (state) {
            PermissionState.GRANTED -> PermissionAction.None
            PermissionState.REQUESTING -> PermissionAction.None
            PermissionState.NOT_REQUESTED -> {
                state = PermissionState.REQUESTING
                PermissionAction.Request
            }
            PermissionState.DENIED -> {
                state = PermissionState.REQUESTING
                PermissionAction.ShowRationale(rationaleMessage)
            }
            PermissionState.PERMANENTLY_DENIED -> {
                PermissionAction.OpenSettings
            }
        }
    }

    /**
     * UI 层在确认了 Rationale 弹窗后，正式向系统提交请求。
     */
    fun onRationaleConfirmed(): PermissionAction {
        if (state == PermissionState.REQUESTING) {
            return PermissionAction.Request
        }
        return PermissionAction.None
    }

    /**
     * 收到系统 onRequestPermissionsResult 回调。
     *
     * @param granted 权限是否被用户授予
     * @param shouldShowRationale 系统 API 的 shouldShowRequestPermissionRationale 返回值。
     *        注意：Android 规范中，如果用户拒绝且勾选了「不再询问」，shouldShowRationale 返回 false。
     */
    fun onPermissionResult(granted: Boolean, shouldShowRationale: Boolean): PermissionState {
        state = if (granted) {
            PermissionState.GRANTED
        } else {
            if (shouldShowRationale) {
                PermissionState.DENIED
            } else {
                PermissionState.PERMANENTLY_DENIED
            }
        }
        return state
    }

    /**
     * Activity/页面重新进入前台（onResume）。
     *
     * @param hasSystemPermission 从 ContextCompat.checkSelfPermission 获取的真实物理状态。
     */
    fun onAppResume(hasSystemPermission: Boolean): PermissionState {
        if (hasSystemPermission) {
            state = PermissionState.GRANTED
        } else {
            // 如果原本以为有权限，但返回前台发现没了（用户在设置里收回了权限）
            if (state == PermissionState.GRANTED) {
                state = PermissionState.DENIED
            }
            // 如果原本处于 REQUESTING 却没给权限（可能弹窗被外界取消）
            if (state == PermissionState.REQUESTING) {
                state = PermissionState.DENIED
            }
        }
        return state
    }

    /** 重置状态机。 */
    fun reset(hasPermission: Boolean = false) {
        state = if (hasPermission) PermissionState.GRANTED else PermissionState.NOT_REQUESTED
    }
}
