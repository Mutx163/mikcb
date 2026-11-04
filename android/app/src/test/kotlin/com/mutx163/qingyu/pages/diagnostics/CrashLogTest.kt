package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.APP_LOG_FILE_NAME
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.infra.CRASH_LOG_CATEGORY
import com.mutx163.qingyu.infra.CrashLogRecorder
import com.mutx163.qingyu.infra.LocalCrashHandler
import com.mutx163.qingyu.infra.crashSignature
import com.mutx163.qingyu.infra.formatCrashEntry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * 本地崩溃落盘测试（源：Dart `lib/main.dart:321` / `:350` 的 app log 出口）。
 *
 * 覆盖：字段齐全、19 键脱敏（消息 / extras / 嵌套）、去重、真实落盘、
 * 以及「落盘失败仍交回原 handler」的不吞异常证据。
 */
class CrashLogTest {

    private lateinit var tempDir: File

    @Before
    fun setUp() {
        tempDir = Files.createTempDirectory("crash-log-test").toFile()
        AppLogStore.initialize(tempDir, "1.2.3+456")
    }

    @After
    fun tearDown() {
        AppLogStore.clear()
        tempDir.deleteRecursively()
    }

    private fun logFile() = File(File(tempDir, "logs"), APP_LOG_FILE_NAME)

    private val stack = """
        java.lang.IllegalStateException: boom
        	at com.mutx163.qingyu.PageKt.render(Page.kt:12)
    """.trimIndent()

    @Test
    fun `崩溃条目字段齐全 时间 类型 消息 栈`() {
        val payload = formatCrashEntry(
            timeMillis = 1700000000000L,
            threadName = "main",
            errorType = "java.lang.IllegalStateException",
            message = "boom",
            stackTrace = stack,
        )
        assertTrue(payload, payload.contains("time=1700000000000"))
        assertTrue(payload, payload.contains("level=error"))
        assertTrue(payload, payload.contains("source=app"))
        assertTrue(payload, payload.contains("category=$CRASH_LOG_CATEGORY"))
        assertTrue(payload, payload.contains("message=boom"))
        assertTrue(payload, payload.contains("  thread=main"))
        assertTrue(payload, payload.contains("  type=java.lang.IllegalStateException"))
        assertTrue(payload, payload.contains("error=java.lang.IllegalStateException"))
        assertTrue(payload, payload.contains("stackTrace="))
        // 原始栈帧保留（类/方法/行号），只脱敏消息文本。
        assertTrue(payload, payload.contains("at com.mutx163.qingyu.PageKt.render(Page.kt:12)"))
    }

    @Test
    fun `命中个人字段表的消息与extras都不出现原值`() {
        val payload = formatCrashEntry(
            timeMillis = 1700000000000L,
            threadName = "main",
            errorType = "java.lang.IllegalStateException",
            message = "排课失败 name=高等数学 teacher=张老师",
            stackTrace = "java.lang.IllegalStateException: name=高等数学\n\tat X.y(X.kt:1)",
            extras = mapOf("courseName" to "高等数学", "room" to "A101"),
        )
        assertFalse(payload, payload.contains("高等数学"))
        assertFalse(payload, payload.contains("张老师"))
        assertTrue(payload, payload.contains("name=**"))
        assertTrue(payload, payload.contains("courseName=**"))
        // 非个人字段照常保留（能定位问题）。
        assertTrue(payload, payload.contains("room=A101"))
    }

    @Test
    fun `嵌套extras递归脱敏`() {
        val payload = formatCrashEntry(
            timeMillis = 1700000000000L,
            threadName = "main",
            errorType = "java.lang.RuntimeException",
            message = "boom",
            stackTrace = stack,
            extras = mapOf(
                "payload" to mapOf("course" to "线性代数", "teacher" to "李四", "ok" to "normal"),
            ),
        )
        assertFalse(payload, payload.contains("线性代数"))
        assertFalse(payload, payload.contains("李四"))
        assertTrue(payload, payload.contains("course=**"))
        assertTrue(payload, payload.contains("ok=normal"))
    }

    @Test
    fun `重复崩溃不重复写同一份`() {
        var writes = 0
        val recorder = CrashLogRecorder(
            append = {
                writes += 1
                true
            },
            now = { 1700000000000L },
        )
        assertTrue(recorder.record("main", "java.lang.RuntimeException", "boom", stack))
        assertEquals(1, writes)
        // 同类型 + 同消息 + 同首帧：判定为同一次崩溃，不重复写。
        assertFalse(recorder.record("main", "java.lang.RuntimeException", "boom", stack))
        assertEquals(1, writes)
        // 换消息即新崩溃。
        assertTrue(recorder.record("main", "java.lang.RuntimeException", "other", stack))
        assertEquals(2, writes)
        assertTrue(crashSignature("T", "boom", stack) != crashSignature("T", "other", stack))
    }

    @Test
    fun `落盘失败也必定交回原handler 不吞异常`() {
        var delegated = 0
        val delegate = Thread.UncaughtExceptionHandler { _, _ -> delegated += 1 }
        val recorder = CrashLogRecorder(append = { throw IllegalStateException("disk full") })
        LocalCrashHandler(delegate, recorder).uncaughtException(
            Thread.currentThread(),
            IllegalStateException("boom"),
        )
        assertEquals(1, delegated)
    }

    @Test
    fun `崩溃真实写入app日志且不含PII`() {
        val recorder = CrashLogRecorder(
            append = { payload -> AppLogStore.appendRawPayload(payload) },
            now = { 1700000000000L },
        )
        val error = IllegalStateException("name=高等数学 崩溃")
        LocalCrashHandler(
            Thread.UncaughtExceptionHandler { _, _ -> },
            recorder,
        ).uncaughtException(Thread.currentThread(), error)

        val text = logFile().readText()
        assertTrue(text, text.contains("category=$CRASH_LOG_CATEGORY"))
        assertTrue(text, text.contains("stackTrace="))
        assertFalse(text, text.contains("高等数学"))
        assertTrue(text, text.contains("name=**"))
    }
}
