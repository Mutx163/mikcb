package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **桥名一致性守卫**（2026-11-05 全 App 横切审核 S2 的落地）。
 *
 * ## 要挡住什么
 *
 * 平台 WebView 的 JS 通道由 `addJavascriptInterface(proxy, WAREHOUSE_WEBVIEW_BRIDGE_NAME)`
 * 注册；适配脚本垫片（[WarehouseAdapterScript.warehouseImportScriptWrapper]）与宏录制脚本
 * （`WarehouseMacroRecorderJs.INJECT_SCRIPT` / `DUMP_SCRIPT`）里的
 * `qingyu_js_bridge.postMessage(...)` 却是**手写字符串字面量**，不引用那个常量。
 * 三处任何一处改名（重命名常量、抄 Dart 时改字、脚本里手滑），桥就**静默断链**：
 * 脚本回不了话、导入卡在等待态，而 L1/L2 编译与既有测试**全绿**——这是最难查的一类回归。
 *
 * ## 守卫判据（源码级，与 `WarehouseWebLoginPageWiringGuardTest` 同款做法）
 *
 * 1. `WarehouseWebViewHost.kt`：常量字面量必须等于**既定桥名**（`QingyuBridge`，
 *    逐字钉死——改名即红，非三处同步地改名也会连带着把它改一条，测试能抓）；
 *    且 `addJavascriptInterface` 只用常量；
 * 2. `WarehouseAdapterScript.kt`：垫片里每处 `.postMessage(` 前的对象名都必须等于常量值
 *    （配平括号取调用对象，注释里提到 postMessage 不算）；
 * 3. `WarehouseMacroRecorderScript.kt`：同 2（INJECT/DUMP 两段脚本一起扫）。
 *
 * ⚠️ 判据是**对拍**不是「存在性检查」：桥名漂移（三处不一致）必红。
 *
 * 去 Flutter 化（P4-C，2026-11-08）：原先还与 Dart 侧 `addJavaScriptChannel("…")`
 * （`lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart`）逐字对拍，
 * Dart 层删除后参照物不存在，那两条已删——Kotlin 常量与垫片/宏脚本三方对拍仍在。
 */
class WarehouseBridgeNameGuardTest {

    /** 桥名钉死的既定字面量（去 Flutter 化前对应 Dart 侧 `addJavaScriptChannel` 的通道名）。 */
    private val bridgeName = "QingyuBridge"

    private val hostSource: String by lazy { readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebViewHost.kt") }
    private val shimSource: String by lazy { readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterScript.kt") }
    private val macroSource: String by lazy { readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseMacroRecorderScript.kt") }

    // -----------------------------------------------------------------------
    // 1. 注册端：常量字面量钉死 + 调用只用常量
    // -----------------------------------------------------------------------

    @Test
    fun `桥名钉死为既定字面量`() {
        val declared = Regex("""WAREHOUSE_WEBVIEW_BRIDGE_NAME[^=\n]*=\s*"([^"]+)"""")
            .find(hostSource)?.groupValues?.get(1)
        assertEquals(
            "桥名是跨三处（注册 + 垫片 + 宏脚本）的契约字面量：改值必须三处同步，" +
                "且先改本守卫的既定值——直接改常量的值不会有人拦得住",
            bridgeName,
            declared,
        )
    }

    @Test
    fun `宿主注册只用常量不许写死字面量`() {
        val call = callAfter(hostSource, "addJavascriptInterface(")
        assertTrue(
            "WarehouseWebViewHost.kt 必须有 addJavascriptInterface( 调用（找不到说明接线被移走，守卫判据失效）",
            call.isNotEmpty(),
        )
        assertTrue(
            "addJavascriptInterface 的名字参数必须用常量 WAREHOUSE_WEBVIEW_BRIDGE_NAME（写死字面量会绕开常量对拍）",
            call.contains("WAREHOUSE_WEBVIEW_BRIDGE_NAME"),
        )
        // 注册调用里不许再出现引号包起来的桥名字面量（防有人「顺手」写死）。
        val literalInCall = Regex("""["']$bridgeName["']""").find(call)
        assertTrue(
            "addJavascriptInterface 调用里不许出现桥名字面量 \"$bridgeName\"（必须用常量）",
            literalInCall == null,
        )
    }

    // -----------------------------------------------------------------------
    // 2. 生产端：垫片脚本与宏录制脚本的每处 postMessage 调用对象
    // -----------------------------------------------------------------------

    @Test
    fun `垫片脚本每处 postMessage 的对象名与常量一致`() {
        assertAllPostMessageReceiversMatchBridgeName(
            source = shimSource,
            label = "WarehouseAdapterScript.kt（适配脚本垫片）",
            minCount = 5,
        )
    }

    @Test
    fun `宏录制脚本每处 postMessage 的对象名与常量一致`() {
        assertAllPostMessageReceiversMatchBridgeName(
            source = macroSource,
            label = "WarehouseMacroRecorderScript.kt（宏录制/导出脚本）",
            minCount = 1,
        )
    }

    // （原有「Dart 宏录制脚本与 Kotlin 通道名对拍」已随 Dart 层删除而退役——Kotlin 宏脚本
    //   自身的一致性由上面的 receivers 断言覆盖。）

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    /**
     * 扫 `source` 里每一处 `<对象>.postMessage(`，取调用对象名，全部必须等于常量值。
     *
     * 判据刻意**全量**而不是抽样：垫片 9 处、宏脚本 2 处，漏一处桥就半身不遂。
     */
    private fun assertAllPostMessageReceiversMatchBridgeName(
        source: String,
        label: String,
        minCount: Int,
    ) {
        val receivers = postMessageReceivers(source)
        assertTrue(
            "$label 里应至少有 $minCount 处 postMessage 调用（找不到说明脚本被移走，守卫判据失效）",
            receivers.size >= minCount,
        )
        val wrong = receivers.filter { it != bridgeName }
        assertTrue(
            "$label 存在与桥名常量不一致的 postMessage 对象：$wrong（期望全部为 \"$bridgeName\"）。" +
                "桥名漂移 = 脚本回不了话、导入卡死等待态，且编译与既有测试全绿——必须同步改齐再提交",
            wrong.isEmpty(),
        )
    }

    /**
     * 取 `source` 里每处 `postMessage(` 的**接收对象名**。
     *
     * 只认「`标识符.postMessage(`」形状（`window.X.postMessage` 取最后一段 `X`），
     * 剥掉行注释后扫描（`// … postMessage` 这类提及不触发）。
     */
    private fun postMessageReceivers(source: String): List<String> {
        val stripped = stripLineComments(source)
        val regex = Regex("""([A-Za-z_$][\w$.]*)\s*\.\s*postMessage\s*\(""")
        return regex.findAll(stripped).map { match ->
            val qualified = match.groupValues[1]
            qualified.substringAfterLast('.')
        }.toList()
    }

    /** 剥掉 `// …` 行注释（Kotlin/JS/Dart 通用口径）；块注释与字符串不剥——三份源文件里没有会误伤的形状。 */
    private fun stripLineComments(source: String): String =
        source.lines().joinToString("\n") { line ->
            val idx = line.indexOf("//")
            if (idx >= 0) line.substring(0, idx) else line
        }

    /** 从当前目录向上找仓库根，再定位源文件（不依赖 cwd，与既有接线守卫同款）。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源文件 $relative（当前目录 ${File("").absolutePath}）")
    }

    /** 取 `marker`（如 `addJavascriptInterface(`）之后的第一个调用参数块（配平到右括号）。 */
    private fun callAfter(source: String, marker: String): String {
        val markerAt = source.indexOf(marker)
        if (markerAt < 0) return ""
        val open = source.indexOf('(', markerAt)
        if (open < 0) return ""
        var depth = 0
        var i = open
        while (i < source.length) {
            when (source[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return source.substring(open, i + 1)
                }
            }
            i++
        }
        return ""
    }
}
