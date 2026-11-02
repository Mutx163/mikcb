package com.mutx163.qingyu.platform

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import java.util.concurrent.Executor

/**
 * 截屏检测（Android 14+ 官方 `Activity.registerScreenCaptureCallback`）——
 * **不依赖 Flutter** 的独立组件，供 Compose 壳等任何 Activity 一行挂载。
 *
 * ## 由来
 *
 * 旧实现整段住在 `MainActivity`（Flutter 壳）里，事件走方法通道回 Dart；
 * 2026-11-02 启动页切到 [com.mutx163.qingyu.pages.PagesShellActivity] 后，
 * 主启动路径不再创建 Flutter 引擎，检测随之失效。本组件把注册/注销语义原样
 * 搬出来自管（生命周期观察者），壳与页面不再各自维护状态位。
 *
 * ## 契约（与旧 MainActivity 逐条一致）
 *
 * - 注册状态机 = [screenCaptureSyncAction]（纯函数，JVM 单测钉住）：
 *   「调用方想听」+「Activity 已 STARTED」缺一不可，幂等。
 * - 回调只报「刚截了一张」，**拿不到截图内容**；`DETECT_SCREEN_CAPTURE` 是
 *   普通权限，Manifest 已声明，无运行时弹框。
 * - ROM 实现异常时静默降级（Log.w），不影响宿主页面。
 *
 * ## 用法
 *
 * ```kotlin
 * // Activity.onCreate 里一行：
 * ScreenCaptureWatcher.attach(this)
 *
 * // 需要事件的消费方拿到实例后挂出口（主线程回调）：
 * watcher.onScreenshot = { showSharePrompt() }
 *
 * // 想跟设置开关走时（Dart 版 screenshotSharePromptEnabled 同口径）：
 * ScreenCaptureWatcher.attach(this) { settings.screenshotSharePromptEnabled }
 * ```
 *
 * ## 当前边界（2026-11-02）
 *
 * 壳里已挂 [attach]，但 `onScreenshot` 暂无消费方：Dart 版检测到截屏后浮
 * 「要分享干净的课表图吗」胶囊提示，其分享面板尚未移植到 Compose，且事件
 * 出口该由课表页接线（只在课表页置顶时提示）。能力探测
 * [isSupported] 已就绪，设置页 `screenshotShareSupported` 需要在分享提示
 * 落地后才会由 false 翻 true（`SettingsPageBridge.toTimetablePageState`）。
 */
class ScreenCaptureWatcher private constructor(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
    /** 是否想听（对齐旧 MainActivity 的 listenerWanted；缺省恒想听）。 */
    private val isListenerWanted: () -> Boolean,
) : DefaultLifecycleObserver {

    /** 截屏事件出口。主线程回调；只报「刚截了一张」，无任何图像数据。 */
    var onScreenshot: (() -> Unit)? = null

    private var started = false
    private var registered = false

    /** 字段本身是 API 34 才有的类型：挂 [RequiresApi]，否则 lintVitalRelease 按 NewApi 报错。 */
    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private var callback: Activity.ScreenCaptureCallback? = null

    /** 回调要求在主线程执行；minSdk 拿不到 Context.getMainExecutor()，自行转发。 */
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { command -> mainHandler.post(command) }

    override fun onStart(owner: LifecycleOwner) {
        started = true
        sync()
    }

    override fun onStop(owner: LifecycleOwner) {
        started = false
        sync()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        started = false
        sync()
        lifecycle.removeObserver(this)
    }

    private fun sync() {
        // 内联写 SDK 判断（不抽函数）：lint 的 NewApi 只认眼皮底下的
        // Build.VERSION.SDK_INT 比较（旧 MainActivity 同一条纪律）。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        when (
            screenCaptureSyncAction(
                wanted = isListenerWanted(),
                started = started,
                registered = registered,
            )
        ) {
            ScreenCaptureSyncAction.REGISTER -> register()
            ScreenCaptureSyncAction.UNREGISTER -> unregister()
            ScreenCaptureSyncAction.NONE -> Unit
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun register() {
        val newCallback = Activity.ScreenCaptureCallback {
            onScreenshot?.invoke()
        }
        try {
            activity.registerScreenCaptureCallback(mainExecutor, newCallback)
            callback = newCallback
            registered = true
        } catch (error: Exception) {
            // ROM 实现异常时静默降级：检测不可用不影响手动分享入口。
            Log.w(TAG, "registerScreenCaptureCallback failed", error)
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun unregister() {
        val oldCallback = callback ?: return
        callback = null
        registered = false
        try {
            activity.unregisterScreenCaptureCallback(oldCallback)
        } catch (error: Exception) {
            Log.w(TAG, "unregisterScreenCaptureCallback failed", error)
        }
    }

    companion object {
        private const val TAG = "ScreenCaptureWatcher"

        /** 设备是否支持截屏检测（Android 14+）；设置页能力探测同口径。 */
        val isSupported: Boolean
            get() = isScreenCaptureCallbackSupported(Build.VERSION.SDK_INT)

        /**
         * 把组件挂上宿主 Activity 的生命周期（onStart 注册 / onStop 注销 /
         * onDestroy 自摘），宿主无需再管任何状态位。
         *
         * 泛型约束：注册回调要 [Activity]，挂生命周期观察者要 [LifecycleOwner]
         * （androidx 系 Activity 都是；裸 `android.app.Activity` 不是）。
         *
         * @param isListenerWanted 是否想听；缺省恒想听。要与设置开关走时传
         *   `{ settings.screenshotSharePromptEnabled }`（Dart 版同口径）。
         */
        fun <T> attach(
            activity: T,
            isListenerWanted: () -> Boolean = { true },
        ): ScreenCaptureWatcher where T : Activity, T : LifecycleOwner {
            val watcher = ScreenCaptureWatcher(activity, activity.lifecycle, isListenerWanted)
            activity.lifecycle.addObserver(watcher)
            return watcher
        }
    }
}
