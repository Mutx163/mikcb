package com.mutx163.qingyu

import java.lang.reflect.Field

/**
 * 自动崩溃采集链路（U-APM）与手动诊断链路的 PII 脱敏一致性
 * （2026-10-19 审计 #27）。
 *
 * 手动链路（[UmengDiagnosticReporter.report] / record）出口前统一过
 * `redactPersonalFields`；自动崩溃链路**没有**改写崩溃负载的公开 API ——
 * apm 1.5.2 里 `UMCrash.registerUMCrashCallback` 的 `onCallback()` 返回值
 * 只是追加进崩溃报告的自定义字段（反编译确认进入 CustomLogInfo.mCallbacks），
 * 拦不到异常 message 本身。所以在这里把默认 UncaughtExceptionHandler 包一层：
 * U-APM 的 handler 装好后在其上再压一层，异常交给上报链路**之前**，把异常链
 * 上每个节点的 message 就地过同一张脱敏表。
 *
 * `detailMessage` 是 Throwable 的私有字段，反射改写。若反射被系统拦截
 * （隐藏 API 限制）或任何一步失败，按「放行原始 message」回退 —— 最坏情况
 * 等于没装这层包装，绝不会让崩溃处理路径本身失败。类名与栈帧不动：
 * U-APM 崩溃分组不漂移，且栈帧（类/方法名）不携带课表 PII。
 */
internal object UmengCrashRedaction {

    /** cause 链遍历上限：防 a→b→a 这类理论环（initCause 只禁自指，不禁双节点环）。 */
    private const val MAX_CAUSE_HOPS = 16

    private val detailMessageField: Field? by lazy {
        try {
            Throwable::class.java.getDeclaredField("detailMessage").apply {
                isAccessible = true
            }
        } catch (_: Throwable) {
            null
        }
    }

    /**
     * 在 [UmengApplication.initializeAnalyticsIfNeeded] 的 `UMConfigure.init`
     * 之后调用：U-APM 已把默认 handler 换成自己的，这里再包一层脱敏层。
     * 重复调用幂等。
     */
    fun install() {
        val current = Thread.getDefaultUncaughtExceptionHandler() ?: return
        if (current is RedactingHandler) {
            return
        }
        Thread.setDefaultUncaughtExceptionHandler(RedactingHandler(current))
    }

    internal class RedactingHandler(
        private val delegate: Thread.UncaughtExceptionHandler,
    ) : Thread.UncaughtExceptionHandler {
        override fun uncaughtException(thread: Thread, throwable: Throwable) {
            try {
                redactThrowableMessageChain(throwable)
            } catch (_: Throwable) {
                // 脱敏失败不阻断崩溃处理，按原样交给 U-APM。
            }
            delegate.uncaughtException(thread, throwable)
        }
    }

    /** 把 [root] 及其 cause 链上的 message 过脱敏表，返回成功改写的节点数。 */
    internal fun redactThrowableMessageChain(root: Throwable): Int {
        var redactedCount = 0
        var node: Throwable? = root
        repeat(MAX_CAUSE_HOPS) {
            val current = node ?: return redactedCount
            if (redactSingleMessage(current)) {
                redactedCount += 1
            }
            node = current.cause
        }
        return redactedCount
    }

    private fun redactSingleMessage(error: Throwable): Boolean {
        val message = error.message ?: return false
        val redactedMessage = UmengDiagnosticReporter.redactPersonalFields(message)
        if (redactedMessage == message) {
            return false
        }
        val field = detailMessageField ?: return false
        return try {
            field.set(error, redactedMessage)
            true
        } catch (_: Throwable) {
            false
        }
    }
}
