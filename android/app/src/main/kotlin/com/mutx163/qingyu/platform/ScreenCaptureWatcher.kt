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
 * ## 当前边界（2026-11-03）
 *
 * 壳里已挂 [attach]；`attach` 的返回值壳没有留下，消费方通过 [activeWatcher]
 * 拿到当前实例接线：课表页的「分享课表图」提示宿主
 * （`pages/timetable/ScreenshotSharePromptHost`）是唯一消费方，自己守
 * 「只在课表页置顶时提示」与设置开关（Dart `ModalRoute.isCurrent` +
 * `screenshotSharePromptEnabled` 的同口径判据）。能力探测 [isSupported]
 * 已接进设置页（`SettingsHost` 传 `screenshotShareSupported`）。
 *
 * 「干净课表图」的导出面板（Dart `TimetableExportDocument` → PNG → 系统分享）
 * 尚未移植到 Compose，所以提示本体暂不带「分享」动作按钮——没有去处的按钮不画。
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
        // 摘掉进程级引用：Activity 销毁后不该再有活实例可拿（拿到的永远是当前那个）。
        if (activeWatcher === this) {
            active = null
        }
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
         * 当前已挂载的实例。壳 `attach` 后不保留返回值，页面消费方从这里取；
         * 同一时刻至多一个（一台 Activity 一个），Activity 销毁时清空。
         * 进程级引用在主线程写（[attach] 与生命周期回调都在主线程），读侧只在
         * 组装期取一次，`@Volatile` 保证跨线程可见性即可。
         */
        @Volatile
        private var active: ScreenCaptureWatcher? = null

        val activeWatcher: ScreenCaptureWatcher?
            get() = active

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
            active = watcher
            return watcher
        }
    }
}
