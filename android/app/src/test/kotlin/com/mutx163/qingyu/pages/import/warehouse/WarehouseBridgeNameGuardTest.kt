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
 * 1. `WarehouseWebViewHost.kt`：常量值必须是 Dart 侧的通道名
 *    （`lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart` 的
 *    `addJavaScriptChannel("…")` 字面量，机械读出），且 `addJavascriptInterface` 只用常量；
 * 2. `WarehouseAdapterScript.kt`：垫片里每处 `.postMessage(` 前的对象名都必须等于常量值
 *    （配平括号取调用对象，注释里提到 postMessage 不算）；
 * 3. `WarehouseMacroRecorderScript.kt`：同 2（INJECT/DUMP 两段脚本一起扫）。
 *
 * ⚠️ 判据是**对拍**不是「存在性检查」：桥名漂移（三处不一致）必红；把 Dart 侧通道名改了
 * 而没同步 Kotlin，这里也红（防两端单向漂移）。
 */
class WarehouseBridgeNameGuardTest {

    /** Dart 与 Kotlin 三处必须同时等于这个名字。 */
    private val bridgeName: String by lazy { readDartBridgeName() }

    private val hostSource: String by lazy { readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebViewHost.kt") }
    private val shimSource: String by lazy { readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterScript.kt") }
    private val macroSource: String by lazy { readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseMacroRecorderScript.kt") }
    private val dartLoginSource: String by lazy { readSource("lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart") }
    private val dartMacroSource: String by lazy { readSource("lib/widgets/warehouse_macro_recorder.dart") }

    // -----------------------------------------------------------------------
    // 1. 注册端：Kotlin 常量 ↔ Dart addJavaScriptChannel
    // -----------------------------------------------------------------------

    @Test
    fun `Kotlin 常量值与 Dart 通道名逐字一致`() {
        assertTrue(
            "Dart 登录页里必须有一处 addJavaScriptChannel（找不到说明 Dart 侧结构变了，守卫判据失效）",
            dartLoginSource.contains("addJavaScriptChannel("),
        )
        val registered = Regex("""addJavaScriptChannel\(\s*["']([^"']+)["']""")
            .findAll(dartLoginSource)
            .map { it.groupValues[1] }
            .distinct()
            .toList()
        assertEquals(
            "Dart 登录页只应注册一个 JS 通道（多了说明结构变了，先改本守卫判据）",
            1,
            registered.size,
        )
        assertEquals(
            "Kotlin 常量 WAREHOUSE_WEBVIEW_BRIDGE_NAME 与 Dart addJavaScriptChannel 的通道名不一致——" +
                "桥会静默断链（脚本回不了话），必须同步改齐再提交",
            registered.single(),
            bridgeName,
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

    /** Dart 侧宏录制脚本也走同一个通道名；两端对拍，防单向漂移。 */
    @Test
    fun `Dart 宏录制脚本与 Kotlin 宏录制脚本通道名一致`() {
        val dartNames = Regex("""([A-Za-z_$][\w$]*)\s*\.\s*postMessage\s*\(""")
            .findAll(dartMacroSource)
            .map { it.groupValues[1] }
            .distinct()
            .toList()
        assertTrue(
            "Dart warehouse_macro_recorder.dart 里应有 postMessage 调用（找不到说明 Dart 侧结构变了）",
            dartNames.isNotEmpty(),
        )
        assertEquals(
            "Dart 宏录制脚本回传用的对象名与 Kotlin 常量不一致——桥会静默断链，必须同步改齐",
            listOf(bridgeName),
            dartNames,
        )
        val kotlinNames = postMessageReceivers(macroSource)
        assertTrue(
            "Kotlin 宏录制脚本里应有 postMessage 调用（找不到说明脚本被移走，守卫判据失效）",
            kotlinNames.isNotEmpty(),
        )
        assertEquals(
            "Kotlin 宏录制脚本回传用的对象名与常量不一致——桥会静默断链，必须同步改齐",
            listOf(bridgeName),
            kotlinNames,
        )
    }

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

    /** Dart 登录页 `addJavaScriptChannel("…")` 的通道名字面量（机械读出，不手抄）。 */
    private fun readDartBridgeName(): String {
        val registered = Regex("""addJavaScriptChannel\(\s*["']([^"']+)["']""")
            .findAll(dartLoginSource)
            .map { it.groupValues[1] }
            .distinct()
            .toList()
        assertEquals("Dart 登录页只应注册一个 JS 通道", 1, registered.size)
        return registered.single()
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
