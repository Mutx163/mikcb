package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.APP_LOG_FILE_NAME
import com.mutx163.qingyu.infra.APP_LOG_HEADER_TITLE
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.infra.NATIVE_DIAGNOSTICS_FILE_NAME
import com.mutx163.qingyu.infra.appLogMaxBytes
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * 应用日志存储壳测试（源：`lib/services/app_log_service.dart` 的 IO 段）。
 *
 * 用真实临时目录做真读写：`filesDir/logs/app_runtime.log`、512KB 上限、
 * 合并源、清空、指纹。Android 入口（`initialize(Context)`）的反射取 `filesDir`
 * 属平台胶水，JVM 侧无法构造 `Context`，因此**不在本测试覆盖范围**（见交付清单）。
 */
class AppLogStoreTest {

    private lateinit var tempDir: File

    @Before
    fun setUp() {
        tempDir = Files.createTempDirectory("app-log-store-test").toFile()
        AppLogStore.initialize(tempDir, "1.2.3+456")
    }

    @After
    fun tearDown() {
        AppLogStore.clear()
        AppLogStore.clearNative()
        tempDir.deleteRecursively()
    }

    private fun logFile() = File(File(tempDir, "logs"), APP_LOG_FILE_NAME)

    private fun nativeFile() = File(File(tempDir, "logs"), NATIVE_DIAGNOSTICS_FILE_NAME)

    @Test
    fun `初始化后落在 filesDir_logs_app_runtime_log`() {
        assertTrue(AppLogStore.isInitialized())
        AppLogStore.append("info", "c", "m")
        assertTrue(logFile().isFile)
    }

    @Test
    fun `追加一条后文件内容就是那条 payload`() {
        assertTrue(AppLogStore.append("info", "update_check", "检查更新"))
        val content = logFile().readText()
        assertTrue(content.startsWith("time="))
        assertTrue(content.contains("\nlevel=info\n"))
        assertTrue(content.contains("\nsource=app\n"))
        assertTrue(content.contains("\ncategory=update_check\n"))
        assertTrue(content.contains("\nmessage=检查更新\n"))
        assertTrue(content.endsWith("\n\n"))
    }

    @Test
    fun `多条追加是追加不是覆盖`() {
        AppLogStore.append("info", "a", "第一条")
        AppLogStore.append("warn", "b", "第二条")
        val content = logFile().readText()
        assertEquals(2, Regex("^time=", RegexOption.MULTILINE).findAll(content).count())
    }

    @Test
    fun `读取带回头部且导出档多一行 exportedAt`() {
        AppLogStore.append("debug", "c", "m")
        val plain = AppLogStore.readText()
        val exported = AppLogStore.readText(forExport = true)
        assertTrue(plain.startsWith("$APP_LOG_HEADER_TITLE\nplatform=android\nversion=1.2.3+456\n----\n"))
        assertTrue(exported.contains("\nexportedAt="))
        assertTrue(plain.contains("\nmessage=m"))
    }

    @Test
    fun `没有日志文件时读取只有头部`() {
        val text = AppLogStore.readText()
        assertEquals("$APP_LOG_HEADER_TITLE\nplatform=android\nversion=1.2.3+456\n----", text)
        assertFalse(text.contains("\n----\n"))
    }

    @Test
    fun `合并源把原生诊断日志一起带出并打 source 标记`() {
        AppLogStore.append("info", "app_side", "来自应用")
        nativeFile().parentFile?.mkdirs()
        nativeFile().writeText("time=999\nlevel=warn\nmessage=来自原生\n\n")
        val merged = AppLogStore.readMergedText()
        assertTrue(merged.contains("source=app"))
        assertTrue(merged.contains("source=native"))
        assertTrue(merged.indexOf("source=app") < merged.indexOf("source=native"))
        assertTrue(merged.contains("message=来自原生"))
    }

    @Test
    fun `超过 512KB 时保留后一半再追加`() {
        // 先造一个超限文件（真实日志里这是长期运行攒出来的），再追加一条。
        logFile().parentFile?.mkdirs()
        logFile().writeText("A".repeat(appLogMaxBytes + 1024))
        assertTrue(AppLogStore.append("info", "c", "截断之后的一条"))
        val length = logFile().length()
        assertTrue("截断后应显著小于上限，实际 $length", length < appLogMaxBytes)
        assertTrue(logFile().readText().contains("message=截断之后的一条"))
    }

    @Test
    fun `清空删掉应用日志与原生日志`() {
        AppLogStore.append("info", "c", "m")
        nativeFile().parentFile?.mkdirs()
        nativeFile().writeText("time=1\nmessage=n\n")
        assertTrue(AppLogStore.clear())
        assertFalse(logFile().isFile)
        assertTrue(AppLogStore.clearNative())
        assertFalse(nativeFile().isFile)
    }

    @Test
    fun `指纹随写入变化_清空后为空`() {
        AppLogStore.append("info", "c", "m")
        val first = AppLogStore.fingerprint()
        assertNotNull(first)
        assertTrue(first!!.contains(":"))
        Thread.sleep(5)
        AppLogStore.append("info", "c", "m2")
        assertTrue(AppLogStore.fingerprint() != first)
        AppLogStore.clear()
        assertNull(AppLogStore.fingerprint())
    }

    @Test
    fun `原生日志指纹单独一份`() {
        assertNull(AppLogStore.nativeFingerprint())
        nativeFile().parentFile?.mkdirs()
        nativeFile().writeText("time=1\nmessage=n\n")
        assertNotNull(AppLogStore.nativeFingerprint())
        assertTrue(AppLogStore.readNativeText().contains("message=n"))
    }
}
