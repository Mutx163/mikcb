package com.mutx163.qingyu.platform

/**
 * 截屏回调注册状态机的纯判定（零 Android 导入，供 JVM 单测钉住）。
 *
 * 契约与旧 `MainActivity.syncScreenCaptureRegistration` 逐条一致：
 * - 「调用方想听」与「宿主 Activity 已 STARTED」两者缺一不可 —— 官方回调只允许在
 *   STARTED 窗口内注册；后台截屏本来就不该归因到本页面。
 * - 状态不变化时不动作（幂等），可安全地随任意生命周期事件反复调用。
 */
internal enum class ScreenCaptureSyncAction {
    REGISTER,
    UNREGISTER,
    NONE,
}

internal fun screenCaptureSyncAction(
    wanted: Boolean,
    started: Boolean,
    registered: Boolean,
): ScreenCaptureSyncAction {
    val shouldRegister = wanted && started
    return when {
        shouldRegister && !registered -> ScreenCaptureSyncAction.REGISTER
        !shouldRegister && registered -> ScreenCaptureSyncAction.UNREGISTER
        else -> ScreenCaptureSyncAction.NONE
    }
}

/** 官方 `Activity.ScreenCaptureCallback` 是 Android 14（API 34）才有的 API。 */
internal fun isScreenCaptureCallbackSupported(sdkInt: Int): Boolean =
    sdkInt >= 34
