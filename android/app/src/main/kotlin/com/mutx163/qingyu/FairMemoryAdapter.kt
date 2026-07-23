package com.mutx163.qingyu

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.Parcel
import android.os.RemoteException
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 金标联盟 / ITGSA「公平运行内存机制」适配。
 *
 * 安全边界（硬约束）：
 * - 不停止 [LiveUpdateService]，不清理 `live_update_scheduler` 快照
 * - 不清理 `home_widget_prefs` / 桌面小组件调度
 * - 不清理 Flutter SharedPreferences、课表数据、考试提醒等持久化
 * - 不 cancel AlarmManager / WorkManager（超级岛与小组件依赖它们）
 * - TRIM 回收易失内存；KILL 先等待现场快照完成，再在 3s 内 Binder 回执
 *
 * 官方文档：
 * https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2304
 */
object FairMemoryAdapter {
    private const val TAG = "FairMemoryAdapter"
    /** 内存预警广播（官方文档 / 示例）。 */
    const val ITGSA_ACTION_TRIM = "itgsa.intent.action.TRIM"
    /** 应用查杀广播（官方「监听预警和异常广播」文字要求；示例代码未写，必须一并注册）。 */
    const val ITGSA_ACTION_KILL = "itgsa.intent.action.KILL"
    private const val CHANNEL_NAME = "com.mutx163.qingyu/fair_memory"
    private const val TRANSACTION_EXCEPTION_REPLY = IBinder.FIRST_CALL_TRANSACTION
    private const val HANDLING_BUDGET_MILLIS = 2_500L

    /** 与官方示例一致：0 表示处理完成。 */
    const val RESULT_OK = 0
    const val RESULT_FAILED = 1

    const val NOTIFY_TYPE_PHYSICAL = 1000
    const val NOTIFY_TYPE_JAVA_HEAP = 2000

    /**
     * 绝对禁止在 TRIM/KILL 路径中删除、清空或覆盖业务键的
     * SharedPreferences 名称。公平内存专用快照键只能追加写入 Flutter
     * SharedPreferences，不能影响其中已有的课表和设置键。
     */
    val PROTECTED_SHARED_PREFS_NAMES: Set<String> = setOf(
        "live_update_scheduler",
        "home_widget_prefs",
        "FlutterSharedPreferences",
        "native_runtime_prefs",
        "exam_reminder_prefs",
    )

    @Volatile
    private var initialized = false

    private var workerHandler: Handler? = null
    private var methodChannel: MethodChannel? = null
    private var replyBinder: IBinder? = null

    private val deathRecipient = IBinder.DeathRecipient {
        synchronized(this) {
            replyBinder = null
        }
    }

    fun initialize(context: Context) {
        synchronized(this) {
            if (initialized) {
                return
            }
            val appContext = context.applicationContext
            val handlerThread = HandlerThread(TAG).apply { start() }
            val handler = Handler(handlerThread.looper)
            workerHandler = handler

            // 文档 3.2：预警 TRIM + 查杀 KILL 两个 Action 都要监听。
            // 官方示例只注册了 TRIM；按「代码层确认适配」检查时必须两个都有。
            val filter = IntentFilter().apply {
                addAction(ITGSA_ACTION_TRIM)
                addAction(ITGSA_ACTION_KILL)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                appContext.registerReceiver(
                    broadcastReceiver,
                    filter,
                    null,
                    handler,
                    Context.RECEIVER_EXPORTED,
                )
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                appContext.registerReceiver(broadcastReceiver, filter, null, handler)
            }
            initialized = true
            Log.i(
                TAG,
                "ITGSA fair-memory receiver registered: " +
                    "$ITGSA_ACTION_TRIM , $ITGSA_ACTION_KILL",
            )
        }
    }

    /** Flutter 引擎就绪后绑定通道，用于内存清理和 KILL 现场快照。 */
    fun attachFlutterEngine(messenger: BinaryMessenger) {
        synchronized(this) {
            methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        }
    }

    fun detachFlutterEngine() {
        synchronized(this) {
            methodChannel = null
        }
    }

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            val action = intent?.action
            if (intent == null ||
                (action != ITGSA_ACTION_TRIM && action != ITGSA_ACTION_KILL)
            ) {
                return
            }
            val pendingResult = goAsync()
            try {
                handleFairMemoryIntent(context.applicationContext, intent)
            } catch (error: Exception) {
                Log.e(TAG, "handleFairMemoryIntent failed", error)
                UmengDiagnosticReporter.report(
                    context = context.applicationContext,
                    category = "fair_memory_handle_failed",
                    message = DiagnosticLogMessages.FAIR_MEMORY_HANDLE_FAILED,
                    throwable = error,
                    dedupeKey = "fair_memory_handle_failed",
                )
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun handleFairMemoryIntent(context: Context, intent: Intent) {
        val startedAt = SystemClock.elapsedRealtime()
        val rootExtras = intent.extras ?: return
        val common = rootExtras.getBundle("common") ?: return
        val notifyType = common.getInt("notifyType", 0)
        val notifyId = common.getInt("notifyId", 0)
        val reason = common.getString("reason").orEmpty()
        val actionRaw = common.getString("action").orEmpty()
        // Intent.action 是系统级 TRIM/KILL；common.action 为额外说明字段。
        val actionKind = classifyFairMemoryAction(
            intentAction = intent.action,
            actionRaw = actionRaw,
            notifyType = notifyType,
        )
        val callback = common.getBinder("callback")
        val extra = rootExtras.getBundle("extra") ?: Bundle()

        val pss = extra.getInt("pss", -1)
        val pssLimit = extra.getInt("pssLimit", -1)
        val heapAlloc = extra.getInt("heapAlloc", -1)
        val heapCapacity = extra.getInt("heapCapacity", -1)

        UmengDiagnosticReporter.record(
            context = context,
            category = "fair_memory_event",
            message = DiagnosticLogMessages.FAIR_MEMORY_EVENT_RECEIVED,
            extras = mapOf(
                "action" to actionKind.name,
                "actionRaw" to actionRaw,
                "notifyType" to notifyType,
                "notifyId" to notifyId,
                "reason" to reason,
                "pss" to pss,
                "pssLimit" to pssLimit,
                "heapAlloc" to heapAlloc,
                "heapCapacity" to heapCapacity,
            ),
        )

        var handledOk = true
        var flutterOutcome = FlutterHandlingOutcome.ENGINE_UNAVAILABLE
        try {
            when (actionKind) {
                FairMemoryActionKind.TRIM -> {
                    releaseVolatileMemoryOnly(context)
                    flutterOutcome = notifyFlutterAndWait(
                        method = "onTrim",
                        payload = buildFlutterPayload(
                            actionKind = actionKind,
                            notifyType = notifyType,
                            notifyId = notifyId,
                            reason = reason,
                            pss = pss,
                            pssLimit = pssLimit,
                            heapAlloc = heapAlloc,
                            heapCapacity = heapCapacity,
                        ),
                        timeoutMillis = remainingHandlingTime(startedAt),
                    )
                }
                FairMemoryActionKind.KILL -> {
                    handledOk = persistKillMarker(context, notifyType, notifyId, reason)
                    releaseVolatileMemoryOnly(context)
                    flutterOutcome = notifyFlutterAndWait(
                        method = "onKill",
                        payload = buildFlutterPayload(
                            actionKind = actionKind,
                            notifyType = notifyType,
                            notifyId = notifyId,
                            reason = reason,
                            pss = pss,
                            pssLimit = pssLimit,
                            heapAlloc = heapAlloc,
                            heapCapacity = heapCapacity,
                        ),
                        timeoutMillis = remainingHandlingTime(startedAt),
                    )
                }
                FairMemoryActionKind.UNKNOWN -> {
                    releaseVolatileMemoryOnly(context)
                }
            }
            handledOk = isFairMemoryHandlingSuccessful(handledOk, flutterOutcome)
        } catch (error: Exception) {
            handledOk = false
            Log.e(TAG, "fair-memory business handling failed", error)
            UmengDiagnosticReporter.report(
                context = context,
                category = "fair_memory_business_failed",
                message = DiagnosticLogMessages.FAIR_MEMORY_BUSINESS_FAILED,
                throwable = error,
                dedupeKey = "fair_memory_business_failed",
            )
        }

        if (callback != null) {
            val resultCode = if (handledOk) RESULT_OK else RESULT_FAILED
            val replyExtra = Bundle().apply {
                putString("reply", "qingyu_fair_memory_${actionKind.name.lowercase(Locale.US)}")
            }
            replyToSystem(
                callback = callback,
                notifyType = notifyType,
                notifyId = notifyId,
                result = resultCode,
                extra = replyExtra,
            )
            Log.i(
                TAG,
                "fair-memory handled action=$actionKind flutter=$flutterOutcome " +
                    "elapsed=${SystemClock.elapsedRealtime() - startedAt}ms result=$resultCode",
            )
        } else {
            Log.w(TAG, "ITGSA callback binder missing; cannot reply within 3s protocol")
        }
    }

    /**
     * 仅回收易失内存。禁止删除 protected prefs / filesDir / 数据库 / 服务。
     */
    private fun releaseVolatileMemoryOnly(context: Context) {
        assertProtectedPrefsUntouched()
        try {
            Runtime.getRuntime().gc()
        } catch (_: Exception) {
        }
        Log.i(
            TAG,
            "volatile memory release requested; live/widget prefs protected=${PROTECTED_SHARED_PREFS_NAMES.size}",
        )
        @Suppress("UNUSED_EXPRESSION")
        context.packageName
    }

    private fun persistKillMarker(
        context: Context,
        notifyType: Int,
        notifyId: Int,
        reason: String,
    ): Boolean {
        val prefsName = "fair_memory_runtime"
        check(prefsName !in PROTECTED_SHARED_PREFS_NAMES) {
            "fair_memory prefs must not collide with protected names"
        }
        return context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putLong("last_kill_at_millis", System.currentTimeMillis())
            .putInt("last_kill_notify_type", notifyType)
            .putInt("last_kill_notify_id", notifyId)
            .putString("last_kill_reason", reason.take(200))
            .commit()
    }

    private fun assertProtectedPrefsUntouched() {
        check(PROTECTED_SHARED_PREFS_NAMES.contains("live_update_scheduler"))
        check(PROTECTED_SHARED_PREFS_NAMES.contains("home_widget_prefs"))
    }

    private fun buildFlutterPayload(
        actionKind: FairMemoryActionKind,
        notifyType: Int,
        notifyId: Int,
        reason: String,
        pss: Int,
        pssLimit: Int,
        heapAlloc: Int,
        heapCapacity: Int,
    ): Map<String, Any?> {
        return mapOf(
            "action" to actionKind.name,
            "notifyType" to notifyType,
            "notifyId" to notifyId,
            "reason" to reason,
            "pss" to pss,
            "pssLimit" to pssLimit,
            "heapAlloc" to heapAlloc,
            "heapCapacity" to heapCapacity,
            "protectedLiveAndWidget" to true,
        )
    }

    private fun remainingHandlingTime(startedAt: Long): Long {
        return (HANDLING_BUDGET_MILLIS - (SystemClock.elapsedRealtime() - startedAt))
            .coerceAtLeast(0L)
    }

    private fun notifyFlutterAndWait(
        method: String,
        payload: Map<String, Any?>,
        timeoutMillis: Long,
    ): FlutterHandlingOutcome {
        val channel = synchronized(this) { methodChannel }
            ?: return FlutterHandlingOutcome.ENGINE_UNAVAILABLE
        if (timeoutMillis <= 0L) {
            return FlutterHandlingOutcome.TIMED_OUT
        }

        val completed = CountDownLatch(1)
        val succeeded = AtomicBoolean(false)
        Handler(Looper.getMainLooper()).post {
            try {
                channel.invokeMethod(
                    method,
                    payload,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            succeeded.set(result == true)
                            completed.countDown()
                        }

                        override fun error(
                            errorCode: String,
                            errorMessage: String?,
                            errorDetails: Any?,
                        ) {
                            Log.w(TAG, "Flutter $method failed: $errorCode $errorMessage")
                            completed.countDown()
                        }

                        override fun notImplemented() {
                            Log.w(TAG, "Flutter $method is not implemented")
                            completed.countDown()
                        }
                    },
                )
            } catch (error: Exception) {
                Log.w(TAG, "notify Flutter $method failed (engine may be gone)", error)
                completed.countDown()
            }
        }

        return try {
            if (!completed.await(timeoutMillis, TimeUnit.MILLISECONDS)) {
                FlutterHandlingOutcome.TIMED_OUT
            } else if (succeeded.get()) {
                FlutterHandlingOutcome.COMPLETED
            } else {
                FlutterHandlingOutcome.FAILED
            }
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            FlutterHandlingOutcome.FAILED
        }
    }

    private fun replyToSystem(
        callback: IBinder,
        notifyType: Int,
        notifyId: Int,
        result: Int,
        extra: Bundle,
    ) {
        synchronized(this) {
            if (replyBinder !== callback) {
                try {
                    replyBinder?.unlinkToDeath(deathRecipient, 0)
                } catch (_: Exception) {
                }
                replyBinder = callback
                try {
                    callback.linkToDeath(deathRecipient, 0)
                } catch (error: RemoteException) {
                    Log.w(TAG, "linkToDeath failed", error)
                    replyBinder = null
                    return
                }
            }
        }

        val remote = synchronized(this) { replyBinder } ?: return
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        try {
            data.writeInt(notifyType)
            data.writeInt(notifyId)
            data.writeInt(result)
            data.writeBundle(extra)
            remote.transact(TRANSACTION_EXCEPTION_REPLY, data, reply, IBinder.FLAG_ONEWAY)
            reply.readException()
            Log.i(TAG, "replied notifyType=$notifyType notifyId=$notifyId result=$result")
        } catch (error: Exception) {
            Log.e(TAG, "reply failed", error)
        } finally {
            reply.recycle()
            data.recycle()
        }
    }
}

internal enum class FairMemoryActionKind {
    TRIM,
    KILL,
    UNKNOWN,
}

internal enum class FlutterHandlingOutcome {
    COMPLETED,
    ENGINE_UNAVAILABLE,
    FAILED,
    TIMED_OUT,
}

internal fun isFairMemoryHandlingSuccessful(
    nativeHandlingSucceeded: Boolean,
    flutterOutcome: FlutterHandlingOutcome,
): Boolean {
    return nativeHandlingSucceeded &&
        flutterOutcome != FlutterHandlingOutcome.FAILED &&
        flutterOutcome != FlutterHandlingOutcome.TIMED_OUT
}

/**
 * 将系统广播归类为 TRIM 或 KILL。
 * 优先看 [intentAction]（itgsa.intent.action.TRIM / KILL），再看 common 里的 action 字段。
 */
internal fun classifyFairMemoryAction(
    intentAction: String?,
    actionRaw: String?,
    notifyType: Int,
): FairMemoryActionKind {
    val intentNormalized = intentAction?.trim().orEmpty()
    if (intentNormalized == FairMemoryAdapter.ITGSA_ACTION_KILL ||
        intentNormalized.endsWith(".KILL")
    ) {
        return FairMemoryActionKind.KILL
    }
    if (intentNormalized == FairMemoryAdapter.ITGSA_ACTION_TRIM ||
        intentNormalized.endsWith(".TRIM")
    ) {
        // common.action 仍可能写 kill；以 Intent 为准时 TRIM 即预警。
        // 若 Intent 已是 TRIM，不再被 common 字段误导成 KILL。
        return FairMemoryActionKind.TRIM
    }

    val normalized = actionRaw
        ?.trim()
        ?.lowercase(Locale.US)
        .orEmpty()
    if (normalized.contains("kill") ||
        normalized.contains("exception") ||
        normalized == "die"
    ) {
        return FairMemoryActionKind.KILL
    }
    if (normalized.contains("trim") ||
        normalized.contains("warn") ||
        normalized.contains("warning") ||
        normalized.contains("low")
    ) {
        return FairMemoryActionKind.TRIM
    }
    if (notifyType == FairMemoryAdapter.NOTIFY_TYPE_PHYSICAL ||
        notifyType == FairMemoryAdapter.NOTIFY_TYPE_JAVA_HEAP
    ) {
        return FairMemoryActionKind.TRIM
    }
    return if (normalized.isEmpty()) {
        FairMemoryActionKind.TRIM
    } else {
        FairMemoryActionKind.UNKNOWN
    }
}

/** 供测试：确认某 prefs 名是否被保护（不可在 fair-memory 路径清理）。 */
internal fun isFairMemoryProtectedPrefsName(prefsName: String): Boolean {
    return FairMemoryAdapter.PROTECTED_SHARED_PREFS_NAMES.contains(prefsName)
}
