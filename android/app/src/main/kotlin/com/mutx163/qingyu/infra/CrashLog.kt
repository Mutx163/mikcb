package com.mutx163.qingyu.infra

/**
 * 本地崩溃落盘（Dart `lib/main.dart:321` / `:350` 的等价层）。
 *
 * Dart 的 `FlutterError.onError` 与 `PlatformDispatcher.onError` 会把框架/平台错误
 * `force` 写进本地 `app_runtime.log`；Compose/Kotlin 侧没有 Flutter 错误出口，
 * 原生崩溃过去只进 U-APM，本地诊断包里查不到。这里补一条等价链路：
 *
 * 1. **先脱敏**：条目统一走 [buildLogEntryPayload]（message / stackTrace / extras
 *    都过 19 键个人字段表），命中键整值写成 `key=**`；
 * 2. **再落盘**：经 [AppLogStore.appendRawPayload] 追加到与 Dart 同一个
 *    `filesDir/logs/app_runtime.log`；
 * 3. **最后交回**：无论落盘成功失败，[LocalCrashHandler] 都会调用原 handler
 *    （U-APM），不吞异常、不改变进程终止语义。
 *
 * 本文件保持纯 JVM（只用 `java.lang.Thread`），因此 `scripts/test-kotlin-module.ps1`
 * 可以编译并单测；Android 侧接线只在 `UmengApplication` 里两行。
 */

const val CRASH_LOG_CATEGORY: String = "native_crash"

/**
 * 崩溃条目纯格式化（复用 [buildLogEntryPayload] 的字段顺序与脱敏出口）。
 *
 * 输出与 Dart `_buildEntryPayload` 同构：
 * `time` → `level=error` → `source=app` → `category=native_crash` → `message`
 * → `extras`（`thread` / `type` 等）→ `error=<类型>` → `stackTrace`。
 */
fun formatCrashEntry(
    timeMillis: Long,
    threadName: String,
    errorType: String,
    message: String?,
    stackTrace: String?,
    extras: Map<String, Any?> = emptyMap(),
): String = buildLogEntryPayload(
    level = "error",
    category = CRASH_LOG_CATEGORY,
    message = message ?: errorType,
    extras = extras + mapOf("thread" to threadName, "type" to errorType),
    error = errorType,
    stackTrace = stackTrace,
    timeMillis = timeMillis,
)

/**
 * 去重签名：类型 + 消息 + 首帧。
 *
 * 同一进程内 handler 被重入（例如崩溃处理里又触发同类崩溃）时不重复写同一份；
 * 换线程/换首帧/换消息都算新崩溃，照常落盘。
 */
fun crashSignature(errorType: String, message: String?, stackTrace: String?): String {
    val firstFrame = stackTrace
        ?.lineSequence()
        ?.map { it.trim() }
        ?.firstOrNull { it.startsWith("at ") }
        ?: ""
    return errorType + "|" + (message ?: "") + "|" + firstFrame
}

/**
 * 崩溃记录器（纯逻辑，append 由调用方注入，便于 JVM 单测）。
 *
 * - [record] 返回 true 表示本次确实调用过 append；
 * - 与上次成功写入签名相同则跳过（[lastSignature] 只在写成功后更新，
 *   写失败的下一次仍会重试）；
 * - 自身异常一律吞掉并返回 false，绝不影响调用方交给原 handler。
 */
class CrashLogRecorder(
    private val append: (String) -> Boolean,
    private val now: () -> Long = { System.currentTimeMillis() },
) {
    private var lastSignature: String? = null

    @Synchronized
    fun record(
        threadName: String,
        errorType: String,
        message: String?,
        stackTrace: String?,
        extras: Map<String, Any?> = emptyMap(),
    ): Boolean {
        val signature = crashSignature(errorType, message, stackTrace)
        if (signature == lastSignature) {
            return false
        }
        return try {
            val payload = formatCrashEntry(
                timeMillis = now(),
                threadName = threadName,
                errorType = errorType,
                message = message,
                stackTrace = stackTrace,
                extras = extras,
            )
            val written = append(payload)
            if (written) {
                lastSignature = signature
            }
            written
        } catch (_: Throwable) {
            false
        }
    }
}

/**
 * 本地落盘 handler：**先写本地日志，再把异常原样交给 [delegate]**。
 *
 * [delegate] 通常是 U-APM 的 handler（可能已被 `UmengCrashRedaction` 包过一层）。
 * 无论本地写入抛什么，`delegate.uncaughtException` 都必定执行。
 */
class LocalCrashHandler(
    private val delegate: Thread.UncaughtExceptionHandler,
    private val recorder: CrashLogRecorder,
) : Thread.UncaughtExceptionHandler {

    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        try {
            recorder.record(
                threadName = thread.name,
                errorType = throwable::class.java.name,
                message = throwable.message,
                stackTrace = throwable.stackTraceToString(),
            )
        } catch (e: Throwable) {
            // 本地日志失败不能改变崩溃处理语义；写一行 stderr 留痕后继续交给原 handler。
            System.err.println("CrashLog: failed to record crash entry: ${e.message}")
        }
        // 不吞异常：原 handler（U-APM / 系统默认）照常终止进程。
        delegate.uncaughtException(thread, throwable)
    }
}

/** 安装本地崩溃落盘层（幂等：当前 handler 已经是本层时不重复包）。 */
object CrashLogInstaller {

    private val recorder = CrashLogRecorder(
        append = { payload -> AppLogStore.appendRawPayload(payload) },
    )

    /**
     * @return true 表示本次装了新的一层；false 表示已装过或拿不到默认 handler。
     *
     * 注意安装时机（2026-11-10 B1 复核修正）：**只在隐私同意后安装**——
     * `initializeAnalyticsIfNeeded` 里 `UMConfigure.init` 之后、`UmengCrashRedaction.install()`
     * 之后再装（保证本层在最外层、崩溃时一定先落盘）。未同意阶段不装，崩溃不写
     * `app_runtime.log`，对齐 v2.1.4.1 Dart `app_log_service.dart:424-426` 的
     * `_shouldRecord=false`（未同意隐私时连崩溃都不落盘）。
     */
    fun install(): Boolean {
        val current = Thread.getDefaultUncaughtExceptionHandler() ?: return false
        if (current is LocalCrashHandler) {
            return false
        }
        Thread.setDefaultUncaughtExceptionHandler(LocalCrashHandler(current, recorder))
        return true
    }
}
