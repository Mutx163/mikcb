package com.mutx163.qingyu.core.permission

/**
 * 运行时权限流程的共用状态机（纯 Kotlin，零 Android 依赖，可进 JVM 单测）。
 *
 * ## 为什么要有这一层
 *
 * 旧版（Flutter）每个要权限的场景都走同一条路：**用到时主动申请 → 拒绝后给一句解释 →
 * 永久拒绝引导去系统设置 → 从设置回来重查**（见 `lib/services/device_location_service.dart`
 * 的 `_ensureUsablePermission`、`lib/screens/add_schedule_item_screen.dart` 的
 * `_requestNotificationPermission`）。Compose 侧此前各页各拼一套 launcher（天气选城市页
 * 有申请但没有跳设置，天气设置页干脆不申请直接失败），本类把流程逻辑收敛到一处，
 * 宿主只做三件事：把 [PermissionStep] 翻译成系统调用、把系统结果喂回来、按阶段显示文案。
 *
 * 与 `share/camera` 的 `CameraPermissionStateMachine` 语义一致（相机域已按它对齐旧版）；
 * 本类是权限无关的泛化版，供天气 / 日程 / 后续场景共用。
 *
 * ## 拒绝语义与系统口径
 *
 * `onSystemResult(granted = false, canAskAgain = false)` 判为 [PermissionStage.PERMANENTLY_DENIED]：
 * Android 规范里「拒绝且勾选不再询问」后 `shouldShowRequestPermissionRationale` 返回 false，
 * 系统也不再弹框（geolocator 的 `deniedForever` 与相机状态机都是同口径）。
 */
class PermissionFlow(initiallyGranted: Boolean = false) {

    var stage: PermissionStage = if (initiallyGranted) {
        PermissionStage.GRANTED
    } else {
        PermissionStage.NOT_REQUESTED
    }
        private set

    /** 权限当前是否可用（宿主据此决定继续原流程还是先走申请）。 */
    val isGranted: Boolean get() = stage == PermissionStage.GRANTED

    /** 是否应向用户解释（拒绝过一次、但系统仍会再给弹框机会）。 */
    val shouldExplain: Boolean get() = stage == PermissionStage.DENIED_ONCE

    /** 是否只能引导去系统设置（系统不再弹框）。 */
    val shouldOpenSettings: Boolean get() = stage == PermissionStage.PERMANENTLY_DENIED

    /**
     * 用户触发了入口（点「使用当前位置」、选了提醒档位等）。
     *
     * - 已授予：直接继续原流程；
     * - 没申请过 / 被拒过一次：弹系统框（拒绝一次后的解释由宿主在上一次失败时已给，
     *   这里与旧版 geolocator 一致——再点就再弹）；
     * - 申请中：防抖（系统框还没回来就再点，重发只会把回调槽顶掉）；
     * - 永久拒绝：跳系统设置。
     */
    fun onTrigger(): PermissionStep = when (stage) {
        PermissionStage.GRANTED -> PermissionStep.Proceed
        PermissionStage.NOT_REQUESTED, PermissionStage.DENIED_ONCE -> {
            stage = PermissionStage.REQUESTING
            PermissionStep.LaunchRequest
        }
        PermissionStage.REQUESTING -> PermissionStep.Proceed
        PermissionStage.PERMANENTLY_DENIED -> PermissionStep.OpenSettings
    }

    /**
     * 系统权限弹框的结果回调。
     *
     * @param granted 用户是否授予。
     * @param canAskAgain 拒绝后 `shouldShowRequestPermissionRationale` 的返回值：
     *        true = 还能再问（[PermissionStage.DENIED_ONCE]，宿主应给一句解释）；
     *        false = 系统不再问（[PermissionStage.PERMANENTLY_DENIED]，宿主应引导去设置）。
     */
    fun onSystemResult(granted: Boolean, canAskAgain: Boolean): PermissionStage {
        stage = when {
            granted -> PermissionStage.GRANTED
            canAskAgain -> PermissionStage.DENIED_ONCE
            else -> PermissionStage.PERMANENTLY_DENIED
        }
        return stage
    }

    /**
     * 宿主回到前台（onResume）：按系统真实状态自愈——用户可能刚去设置里开了权限，
     * 也可能把权限收回了。与相机状态机 `onAppResume` 同口径。
     */
    fun onHostResumed(grantedNow: Boolean): PermissionStage {
        stage = when {
            grantedNow -> PermissionStage.GRANTED
            stage == PermissionStage.GRANTED || stage == PermissionStage.REQUESTING ->
                PermissionStage.DENIED_ONCE
            else -> stage
        }
        return stage
    }
}

/** 权限流程所处阶段。 */
enum class PermissionStage {
    /** 尚未向系统发起过申请。 */
    NOT_REQUESTED,

    /** 系统弹框在等结果。 */
    REQUESTING,

    /** 被拒过一次，但系统还会再给弹框机会；宿主应给一句解释。 */
    DENIED_ONCE,

    /** 永久拒绝：系统不再弹框，只能去系统设置里开。 */
    PERMANENTLY_DENIED,

    /** 已授予。 */
    GRANTED,
}

/** 状态机建议宿主执行的下一步动作。 */
sealed class PermissionStep {
    /** 已授予或防抖：直接继续原流程。 */
    data object Proceed : PermissionStep()

    /** 调系统 launcher 弹权限框。 */
    data object LaunchRequest : PermissionStep()

    /** 永久拒绝：提示 + 跳系统设置页。 */
    data object OpenSettings : PermissionStep()
}
