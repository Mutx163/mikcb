package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 自动崩溃链路的 PII 脱敏（2026-10-19 审计 #27）。
 *
 * U-APM 没有改写崩溃负载的公开 API（registerUMCrashCallback 的 onCallback
 * 只是向报告追加自定义字段），所以在 UncaughtExceptionHandler 一层把异常链
 * message 过脱敏表后再交上报。这里钉住 [UmengCrashRedaction
 * .redactThrowableMessageChain] 的口径：message 过
 * [UmengDiagnosticReporter.redactPersonalFields]，类名与栈不动。
 */
class UmengCrashRedactionTest {
    @Test
    fun redactsPersonalFieldsInCrashMessage() {
        val error = IllegalStateException("起岛失败 course=高等数学 loc=A101")
        val redacted = UmengCrashRedaction.redactThrowableMessageChain(error)
        assertEquals(1, redacted)
        assertEquals("起岛失败 course=** loc=**", error.message)
        // 类名不动：U-APM 崩溃分组不漂移。
        assertEquals(IllegalStateException::class.java.name, error.javaClass.name)
        // 栈不动：栈帧是类/方法名，没有课表 PII。
        assertTrue(error.stackTrace.isNotEmpty())
    }

    @Test
    fun redactsWholeCauseChain() {
        val root = RuntimeException(
            "name=线性代数|id=c-1",
            IllegalStateException("teacher=王老师"),
        )
        val redacted = UmengCrashRedaction.redactThrowableMessageChain(root)
        assertEquals(2, redacted)
        assertFalse(root.message!!.contains("线性代数"))
        // 取证量（id）原样保留，与脱敏表口径一致。
        assertTrue(root.message!!.contains("id=c-1"))
        assertFalse(root.cause!!.message!!.contains("王老师"))
    }

    @Test
    fun passesThroughNullMessageAndNonPersonalMessage() {
        // null message（cause 直接挂构造）与不含敏感键的 message 原样保留。
        val root = RuntimeException(IllegalStateException("retry scheduled delay=30s"))
        val redacted = UmengCrashRedaction.redactThrowableMessageChain(root)
        assertEquals(0, redacted)
        assertEquals("retry scheduled delay=30s", root.cause!!.message)
    }
}
