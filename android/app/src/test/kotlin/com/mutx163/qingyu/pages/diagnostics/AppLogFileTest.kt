package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.APP_LOG_HEADER_TITLE
import com.mutx163.qingyu.infra.appLogFingerprint
import com.mutx163.qingyu.infra.buildAppLogEntryPayload
import com.mutx163.qingyu.infra.buildAppLogHeader
import com.mutx163.qingyu.infra.composeAppLogText
import com.mutx163.qingyu.infra.extractAppLogBody
import com.mutx163.qingyu.infra.mergeAppLogText
import com.mutx163.qingyu.infra.recordingEnabledFromPrefs
import com.mutx163.qingyu.infra.trimAppLogIfNeeded
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * 应用日志落盘纯逻辑测试（源：`lib/services/app_log_service.dart`）。
 *
 * 期望值全部从 Dart 手推，**不抄实现**：
 * - 单条 payload：`_buildEntryPayload` 529-590 行（顺序 time/level/source/category/
 *   message/extras/error/stackTrace/空行；extras 缩进两格）；
 * - 头部：`_buildHeader` 515-527 行（`exportedAt` 只在导出时出现；拿不到版本整行省略）；
 * - 截断：`_trimIfNeeded` 499-513 行（超限保留**后一半**字符并 `trimLeft`）；
 * - 合并：`readMergedLogsText` 266-290 行（应用段在前、原生段在后，打 `source=`）；
 * - 指纹：`_logFileFingerprint` 489-497 行（`size:mtimeMillis`）；
 * - 记录开关：`_readLoggingEnabledFromPrefs` 429-480 行（档案优先 → 设置 → 默认 false）。
 */
class AppLogFileTest {

    private lateinit var tempDir: File

    @Before
    fun setUp() {
        tempDir = Files.createTempDirectory("app-log-file-test").toFile()
    }

    @After
    fun tearDown() {
        tempDir.deleteRecursively()
    }

    // ---------- 单条 payload ----------

    @Test
    fun `单条日志 payload 与 Dart 逐字一致`() {
        val payload = buildAppLogEntryPayload(
            level = "INFO",
            category = "update_check",
            message = "检查更新完成",
            extras = linkedMapOf<String, Any?>("from" to "1.0.0", "count" to 2),
            nowMillis = 1_700_000_000_000L,
        )
        // 级别大小写归一（Dart `_normalizeLevel`），extras 每行缩进两格，末尾一个空行。
        assertEquals(
            "time=1700000000000\n" +
                "level=info\n" +
                "source=app\n" +
                "category=update_check\n" +
                "message=检查更新完成\n" +
                "extras=\n" +
                "  from=1.0.0\n" +
                "  count=2\n" +
                "\n",
            payload,
        )
    }

    @Test
    fun `没有 extras 时不留 extras 行`() {
        val payload = buildAppLogEntryPayload(
            level = "warn",
            category = "warehouse",
            message = "脚本超时",
            nowMillis = 1L,
        )
        assertEquals("time=1\nlevel=warn\nsource=app\ncategory=warehouse\nmessage=脚本超时\n\n", payload)
    }

    @Test
    fun `个人信息字段的 extras 整值抹掉`() {
        val payload = buildAppLogEntryPayload(
            level = "info",
            category = "import",
            message = "导入完成",
            extras = linkedMapOf<String, Any?>("overflowNames" to "高等数学,线性代数"),
            nowMillis = 1L,
        )
        // Dart 口径：名字型字段整值 `**`（逐段匹配会漏掉逗号/竖线后面的名字）。
        assertTrue(payload.contains("  overflowNames=**\n"))
        assertFalse(payload.contains("高等数学"))
    }

    @Test
    fun `未知级别回落 info`() {
        val payload = buildAppLogEntryPayload("fatal", "c", "m", nowMillis = 1L)
        assertTrue(payload.startsWith("time=1\nlevel=info\n"))
    }

    // ---------- 头部 ----------

    @Test
    fun `非导出头部不含 exportedAt`() {
        assertEquals(
            "log_export_title\nplatform=android\n----",
            buildAppLogHeader(version = null, forExport = false, nowMillis = 1L),
        )
    }

    @Test
    fun `导出头部含 exportedAt 与版本`() {
        assertEquals(
            "log_export_title\nexportedAt=1700000000000\nplatform=android\nversion=1.2.3+456\n----",
            buildAppLogHeader(version = "1.2.3+456", forExport = true, nowMillis = 1_700_000_000_000L),
        )
    }

    @Test
    fun `首行标题与 Dart 常量一致`() {
        assertEquals("log_export_title", APP_LOG_HEADER_TITLE)
    }

    // ---------- 拼接 / 取正文 ----------

    @Test
    fun `头部加正文按 Dart 口径拼接_正文为空只回头部`() {
        val header = buildAppLogHeader(null, false, 1L)
        assertEquals(header, composeAppLogText(header, "   "))
        assertEquals("$header\ntime=1\nlevel=info", composeAppLogText(header, "time=1\nlevel=info"))
    }

    @Test
    fun `取正文时按分隔线切掉头部`() {
        val text = "log_export_title\nplatform=android\n----\ntime=1\nlevel=info\nmessage=a"
        assertEquals("time=1\nlevel=info\nmessage=a", extractAppLogBody(text))
    }

    // ---------- 截断 ----------

    @Test
    fun `未超限不动文件`() {
        val file = File(tempDir, "small.log").apply { writeText("0123456789") }
        assertFalse(trimAppLogIfNeeded(file, maxBytes = 10))
        assertEquals("0123456789", file.readText())
    }

    @Test
    fun `超限保留后一半字符并去掉前导空白`() {
        // maxBytes=6 ⇒ 保留后 3 个字符；前导换行被 trimStart 去掉（Dart `retained.trimLeft()`）。
        val file = File(tempDir, "big.log").apply { writeText("0123\n56789") }
        assertTrue(trimAppLogIfNeeded(file, maxBytes = 6))
        // "0123\n56789" 的后 3 个字符是 "789"
        assertEquals("789", file.readText())
    }

    @Test
    fun `文件不存在时截断是空操作且不抛`() {
        assertFalse(trimAppLogIfNeeded(File(tempDir, "missing.log"), maxBytes = 4))
    }

    // ---------- 合并 ----------

    @Test
    fun `合并源按应用在前原生在后打 source 标记`() {
        val appBody = "time=100\nlevel=info\ncategory=update\nmessage=app"
        val nativeBody = "time=200\nlevel=warn\ncategory=live_update\nmessage=native"
        assertEquals(
            "time=100\nsource=app\nlevel=info\ncategory=update\nmessage=app" +
                "\n\n" +
                "time=200\nsource=native\nlevel=warn\ncategory=live_update\nmessage=native",
            mergeAppLogText(appBody, nativeBody),
        )
    }

    @Test
    fun `已有 source 标记的段落不被覆盖`() {
        val nativeBody = "time=2\nsource=app\nlevel=info\nmessage=keep"
        assertEquals("time=2\nsource=app\nlevel=info\nmessage=keep", mergeAppLogText("", nativeBody))
    }

    @Test
    fun `单边为空时只留另一边`() {
        assertEquals("time=1\nsource=app\nlevel=info", mergeAppLogText("time=1\nlevel=info", ""))
        assertEquals("", mergeAppLogText("", ""))
    }

    // ---------- 指纹 ----------

    @Test
    fun `指纹是 size 冒号 mtime`() {
        val file = File(tempDir, "fp.log").apply { writeText("abcdef") }
        assertEquals("6:${file.lastModified()}", appLogFingerprint(file))
    }

    @Test
    fun `文件不存在时指纹为空`() {
        assertNull(appLogFingerprint(null))
        assertNull(appLogFingerprint(File(tempDir, "none.log")))
    }

    // ---------- 记录开关 ----------

    @Test
    fun `档案里的开关优先于设置`() {
        val profiles = """[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}}]"""
        val settings = """{"liveEnableLocalDiagnostics":false}"""
        assertTrue(recordingEnabledFromPrefs(settings, profiles, "p1"))
    }

    @Test
    fun `激活 id 找不到时取第一份档案`() {
        val profiles =
            """[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}},{"id":"p2","settings":{"liveEnableLocalDiagnostics":false}}]"""
        assertTrue(recordingEnabledFromPrefs(null, profiles, "missing"))
    }

    @Test
    fun `档案里没有该键时回落到设置`() {
        val profiles = """[{"id":"p1","settings":{}}]"""
        val settings = """{"liveEnableLocalDiagnostics":true}"""
        assertTrue(recordingEnabledFromPrefs(settings, profiles, "p1"))
    }

    @Test
    fun `两边都没有时默认关闭`() {
        assertFalse(recordingEnabledFromPrefs(null, null, null))
        assertFalse(recordingEnabledFromPrefs("", "", ""))
        assertFalse(recordingEnabledFromPrefs("not json", "[]", null))
        assertFalse(recordingEnabledFromPrefs("{}", null, null))
    }

    @Test
    fun `字符串形式的开关也认`() {
        assertTrue(recordingEnabledFromPrefs("""{"liveEnableLocalDiagnostics":"true"}""", null, null))
        assertFalse(recordingEnabledFromPrefs("""{"liveEnableLocalDiagnostics":"0"}""", null, null))
    }
}
