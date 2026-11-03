package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **登录页宿主接线守卫**（F28）：读 `WarehouseWebLoginHost.kt` 源码，钉住壳侧缺口的修复事实。
 *
 * 登录页宿主在 `composeP1` 源集，**不在 L0 编译范围**；但「地址是不是真地址」
 * 「脚本是不是真拉回来再注入」这类接线事实可以靠源码结构判（与 `test/architecture/` 同款做法）。
 *
 * 守卫要拦的是回退：
 * - 有人把登录地址换回占位常量（`example.com` / `SHELL_DEMO_*`）；
 * - 有人把「执行导入脚本」改回空回调，或跳过仓库直接注入假脚本；
 * - 有人把「没有任何合法地址」的情况改成加载空白网页（用户只看到白屏）。
 */
class WarehouseWebLoginHostWiringGuardTest {

    private val hostSource: String by lazy { stripKotlinComments(readHostSource()) }

    @Test
    fun `判据必须剥掉注释 注释掉的接线不算接线`() {
        // 2026-11-03 咬合探针实测：把 `state.autoRecordMacro = false` 注释掉后旧判据仍命中。
        val fake = "fun fake() {\n    // state.autoRecordMacro = false\n}"
        assertFalse(
            "注释掉的判据不许再命中",
            stripKotlinComments(fake).contains("state.autoRecordMacro = false"),
        )
        assertTrue("字符串字面量里的内容不许被当注释吃掉", stripKotlinComments("val u = \"a//b\"").contains("a//b"))
    }

    @Test
    fun `登录地址必须来自解析函数 不许出现占位地址`() {
        assertTrue(
            "宿主必须用 resolveWarehouseWebLoginTarget(...) 决定加载地址（自定义覆盖 > 仓库 import_url）",
            hostSource.contains("resolveWarehouseWebLoginTarget("),
        )
        listOf("example.com", "SHELL_DEMO_LOGIN_URL", "SHELL_DEMO_SCHOOL").forEach { forbidden ->
            assertFalse(
                "登录宿主不许再出现占位常量/地址：`$forbidden`",
                hostSource.contains(forbidden),
            )
        }
    }

    @Test
    fun `没有可用地址时显示诚实空态 而不是空白网页`() {
        assertTrue(
            "没有合法地址时必须渲染 MissingUrl 空态",
            hostSource.contains("WarehouseWebLoginMissingUrlPage("),
        )
        assertTrue(
            "空态文案取 ARB 的 noValidWarehouseLoginUrl",
            hostSource.contains("noValidWarehouseLoginUrl"),
        )
    }

    @Test
    fun `执行导入必须真拉脚本 并包垫片后注入`() {
        assertTrue(
            "必须调用仓库拉脚本（loadAdapterScript）",
            hostSource.contains("loadAdapterScript("),
        )
        assertTrue(
            "注入前必须包 AndroidBridge 垫片（warehouseImportScriptWrapper）",
            hostSource.contains("warehouseImportScriptWrapper("),
        )
        assertTrue(
            "必须把脚本注入真 WebView 控制器",
            hostSource.contains("controller.injectJavaScript("),
        )
        assertTrue(
            "执行前必须过 planWarehouseScriptExecution 判定（页面没加载完不许注入）",
            hostSource.contains("planWarehouseScriptExecution("),
        )
    }

    @Test
    fun `真 WebView 与状态回写必须接在页面上`() {
        assertTrue("必须渲染 WarehouseWebLoginPage", hostSource.contains("WarehouseWebLoginPage("))
        assertTrue("必须把解析出的会话状态交给页面", hostSource.contains("sessionState = session"))
        assertTrue("必须自己持有控制器才能在载入完成后注入脚本", hostSource.contains("webViewController = controller"))
        listOf("onWebProgress =", "onWebPageStarted =", "onWebPageFinished =", "onWebError =")
            .forEach { marker ->
                assertTrue("缺少宿主回调接线：$marker", hostSource.contains(marker))
            }
    }

    @Test
    fun `桥接消息只记类型 不直接当导入结果`() {
        assertTrue(
            "桥接消息必须走 warehouseBridgeMessageType 记类型（正文含课表数据，不进日志）",
            hostSource.contains("warehouseBridgeMessageType(raw)"),
        )
        assertFalse(
            "宿主不许把原始桥接消息直接写进课表/仓库（当前无导入管线，写进去就是假接线）",
            hostSource.contains("repository.") && hostSource.contains("onWebBridgeMessage"),
        )
    }

    @Test
    fun `savePresetTimeSlots 失败提示的错误码必须过服务消息本地化`() {
        assertTrue(
            "savePresetTimeSlots 的 Failed 分支必须把错误码先过 TimeSchemeServiceMessages.localize " +
                "（认不出的码原样返回，不许把 `code|k=v` 原文摆上 Toast）",
            hostSource.contains("TimeSchemeServiceMessages.localize("),
        )
    }

    @Test
    fun `宏录制接线必须钉住 事件分发 自动录制消费一次 保存询问`() {
        assertTrue(
            "macro:event 必须分发到 handleMacroEvent（录制态收事件进缓冲）",
            hostSource.contains("\"macro:event\" -> handleMacroEvent(raw)"),
        )
        assertTrue(
            "首次导入自动录制必须消费一次意图（读后即清：回到本页不得再自动开录）",
            hostSource.contains("state.autoRecordMacro = false"),
        )
        assertTrue(
            "录制保存询问必须挂 WarehouseMacroSaveRecordingDialog（常驻组合，show 由状态驱动）",
            hostSource.contains("WarehouseMacroSaveRecordingDialog("),
        )
    }

    private fun readHostSource(): String {
        val relative =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到宿主源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    /**
     * 剥掉行注释与斜杠星块注释再判（正本在 `ComposeSheetGuardTest.stripKotlinComments`）：
     * 把守卫判据那行注释掉不算还接着线；块注释按 Kotlin 语义可嵌套；
     * 字符串字面量（含转义）原样保留，`"https://…"` 不会把行尾真参吃掉。
     */
    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }
}
