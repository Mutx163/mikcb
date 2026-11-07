package com.mutx163.qingyu

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * [FairMemoryAdapter.FlutterHandlingBridge] 的 MethodChannel 实现（去 Flutter 化阶段 1，2026-11-07）。
 *
 * 逐字搬自 `FairMemoryAdapter.notifyFlutterAndWait` 的通道段：主线程投递、
 * 三种回投（`success` 只认 `result == true`；`error` / `notImplemented` 记日志后放弃）、
 * 超时与线程中断语义全部不变。
 *
 * **Flutter 专有文件**：`-PwithFlutter=false` 构型下本文件不参与编译（见 `app/build.gradle`
 * 的 `withFlutter` 门），那时没有任何东西会 [FairMemoryAdapter.attachFlutterBridge]，
 * `notifyFlutterAndWait` 直接走 `ENGINE_UNAVAILABLE` 分支。
 */
internal class MethodChannelFairMemoryBridge(
    messenger: BinaryMessenger,
) : FairMemoryAdapter.FlutterHandlingBridge {

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    override fun invokeAndWait(
        method: String,
        payload: Map<String, Any?>,
        timeoutMillis: Long,
    ): FlutterHandlingOutcome {
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

    private companion object {
        /** 与 `FairMemoryAdapter` 旧字段同名同值（通道契约冻结）。 */
        const val CHANNEL_NAME = "com.mutx163.qingyu/fair_memory"
        const val TAG = "FairMemoryAdapter"
    }
}
