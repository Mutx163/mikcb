package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.SourceSlice
import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 桥 / console 采集的**接线守卫**（第 1 步 A 半）。
 *
 * ## 为什么要读源码判
 *
 * `WarehouseWebViewHost.kt` 与 `WarehouseWebLoginHost.kt` 都在 `composeP1` 源集，**不在 L0
 * 编译范围**；「钩子到底接没接上」没有编译器能判。模型层用例（`WarehouseLogHooksTest`）
 * 只能证明「字段算得对」，证明不了「宿主真调了」——少一处调用，日志里就少一段证据，
 * 而用例照样全绿。
 *
 * ## 钉的是这四条
 *
 * 1. `postMessage` 路径上**有** `BRIDGE dir=req` 的记录，且记录落在既有的主线程投递里
 *    （`mainHandler.post`），`@JavascriptInterface` 方法本体只投递、不解析不落日志；
 * 2. 三处原生回话——`answerAndClose`（作答）、`handleDialogFallback`（兜底）、
 *    `cancelPendingDialog`（窗口结束排空）——各有一处记录，且排在 resolve 脚本注入之后
 *    （没真回话就不许记 resolved）；`answerRequest`（`savePresetTimeSlots` 直接回话）
 *    同样要记；
 * 3. `onConsoleMessage` 处有记录调用，截断常量与 `FAILURE` 升级落在纯逻辑层；
 * 4. `BRIDGE req` 的字段计算里**不出现 payload**（字段只有 `dir` / `requestId` / `type`）。
 *
 * ## 关于「超时排空」这一支（诚实边界）
 *
 * 老代码在超时收尾里调 `cancelPendingDialog("timeout")`；2026-11-13 的暂停模型把它删了
 * （不变量 ②：到点还挂着弹窗不可达，`WarehouseTimeoutWiringGuardTest` 钉着超时体内不许
 * 出现这个调用）。所以现在**没有**一条「超时 → 排空」的活路径可以挂记录。本守卫因此把
 * `reason` 记在唯一的排空函数 `cancelPendingDialog(reason)` 上：它按实际原因写
 * `reason=complete|error|page_navigation|re_execute`，`timeout` 走同一条（模型层用例已覆盖
 * 该取值），不为一条不可达的路径写假记录。
 *
 * 读源码默认走 `readKotlinSourceNoStrings`（剥注释 + 中性化字符串）：这些判据要的是代码
 * 结构，被 KDoc 或字符串满足就是假绿；只有「某个字符串键不许出现」那一类判据改用
 * `readKotlinSourceNormalized`（保留字符串内容），见 [logHooks] 的注释。
 * 否定式断言走 `assertSourceLacks`（空读先红）。
 */
class WarehouseBridgeConsoleWiringGuardTest {

    private val webViewHost: String by lazy { readKotlinSourceNoStrings(WEB_VIEW_HOST_PATH) }
    private val loginHost: String by lazy { readKotlinSourceNoStrings(LOGIN_HOST_PATH) }

    /**
     * 这一份用**保留字符串**的档位（[readKotlinSourceNormalized]）：下面有一条判据是
     * 「`requestFields` 里不许出现 `payload` 这个键」。字段名是字符串字面量，中性化档位会把
     * 它一起抹掉 ⇒ `fields["payload"] = …` 也能通过，正好放过要拦的那一类改动。
     * 注释仍被剥掉，所以 KDoc 里提 payload 不会让判据假红。
     */
    private val logHooks: String by lazy {
        readKotlinSourceNormalized(LOG_HOOKS_PATH)
    }

    /** 先自证三份源码都读到了（路径写错时下面几条会一起红，不如这里先红得清楚）。 */
    @Test
    fun `sources are readable and anchors exist`() {
        assertSourceContains(webViewHost, "fun postMessage(", "WarehouseWebViewHost")
        assertSourceContains(webViewHost, "override fun onConsoleMessage(", "WarehouseWebViewHost")
        assertSourceContains(loginHost, "fun answerAndClose(", "WarehouseWebLoginHost")
        assertSourceContains(loginHost, "fun cancelPendingDialog(", "WarehouseWebLoginHost")
        assertSourceContains(logHooks, "fun recordWarehouseBridgeRequest(", "WarehouseLogHooks")
        assertSourceContains(logHooks, "fun recordWarehouseConsoleMessage(", "WarehouseLogHooks")
    }

    /**
     * ① `postMessage` 路径：记录必须落在**已有的主线程投递**里。
     *
     * 反面判据同样重要：`@JavascriptInterface` 方法本体（JavaBridge 线程）里既不许直接记录，
     * 也不许做 JSON 解析——那是「投回主线程再记录」的接线承诺。
     */
    @Test
    fun `postMessage path records BRIDGE request on the main thread`() {
        val path = SourceSlice.between(webViewHost, "fun postMessage(", JAVASCRIPT_INTERFACE)
        assertSourceContains(path, "onMessage?.invoke(message)", "postMessage path (delivery)")
        assertSourceContains(path, "mainHandler.post", "postMessage path (main-thread delivery)")
        assertSourceContains(
            path,
            "recordWarehouseBridgeRequest(message)",
            "postMessage path (BRIDGE req record)",
        )

        // 记录先于投递：投递给页面层的回调抛错也不该把证据丢掉。
        val recordAt = path.indexOf("recordWarehouseBridgeRequest(message)")
        val deliverAt = path.indexOf("controller.onBridgeMessage?.invoke(message)")
        assertTrue(
            "recordWarehouseBridgeRequest( must come before controller.onBridgeMessage?.invoke(; " +
                "recordAt=$recordAt deliverAt=$deliverAt",
            recordAt >= 0 && deliverAt > recordAt,
        )

        val proxyBody = SourceSlice.functionBody(webViewHost, "fun postMessage(")
        assertSourceContains(proxyBody, "onMessage?.invoke(message)", "postMessage body")
        assertSourceLacks(
            proxyBody,
            "recordWarehouseBridgeRequest(",
            "postMessage body (JavaBridge thread: deliver only)",
        )
        assertSourceLacks(proxyBody, "MiniJson", "postMessage body (JavaBridge thread: no parsing)")
    }

    /** ② 三处原生回话 + `answerRequest`：先注入 resolve 脚本，再记 `BRIDGE dir=resolved`。 */
    @Test
    fun `every native reply site records BRIDGE resolved after injecting the script`() {
        val answered = SourceSlice.functionBody(loginHost, "fun answerAndClose(")
        assertReplyRecord(answered, "recordWarehouseBridgeResolved(", "answerAndClose")

        val fallback = SourceSlice.functionBody(loginHost, "fun handleDialogFallback(")
        assertReplyRecord(fallback, "recordWarehouseBridgeFallback(", "handleDialogFallback")

        val drained = SourceSlice.functionBody(loginHost, "fun cancelPendingDialog(")
        assertReplyRecord(drained, "recordWarehouseBridgeDrain(", "cancelPendingDialog")
        // 排空原因必须写实际值（complete / error / page_navigation / re_execute / timeout）。
        assertSourceContains(
            drained,
            "recordWarehouseBridgeDrain(answer.requestId, reason)",
            "cancelPendingDialog (drain reason)",
        )

        val answeredRequest = SourceSlice.functionBody(loginHost, "fun answerRequest(")
        assertReplyRecord(answeredRequest, "recordWarehouseBridgeResolved(", "answerRequest")
    }

    /**
     * ③ console 钩子：宿主处有记录调用，截断常量 / 脱敏 / FAILURE 升级落在纯逻辑层。
     *
     * 截断不在宿主里写死 500——常量只有一份（[WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS]），
     * 所以这里判「常量与它的使用都在 `WarehouseLogHooks.kt`」，宿主侧只判调用了记录函数。
     */
    @Test
    fun `console hook records SCRIPT with the truncation constant and failure escalation`() {
        val console = SourceSlice.functionBody(webViewHost, "override fun onConsoleMessage(")
        assertSourceContains(console, "recordWarehouseConsoleMessage(level, text)", "onConsoleMessage")
        assertSourceContains(
            console,
            "message.messageLevel().name.lowercase()",
            "onConsoleMessage (level source)",
        )
        // 原回调不能因为记日志被吞掉：页面层的 onConsoleMessage 还要照常收到。
        assertSourceContains(console, "onConsoleMessage(level, text)", "onConsoleMessage (forwarding)")

        assertSourceContains(
            logHooks,
            "const val WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS: Int = 500",
            "WarehouseLogHooks (cap constant)",
        )
        assertSourceContains(
            logHooks,
            "truncateChars(singleLine, WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS)",
            "WarehouseLogHooks (cap is used, not just declared)",
        )
        assertSourceContains(
            logHooks,
            "WarehouseLogRedaction.redactText(",
            "WarehouseLogHooks (console text goes through redaction)",
        )
        assertSourceContains(logHooks, "WarehouseLogCategory.SCRIPT", "WarehouseLogHooks (SCRIPT)")
        assertSourceContains(
            logHooks,
            "WarehouseLogCategory.FAILURE",
            "WarehouseLogHooks (FAILURE escalation)",
        )
    }

    /** ④ `BRIDGE req` 的字段计算里不许出现 payload（只有 dir / requestId / type）。 */
    @Test
    fun `bridge log field builder never mentions payload`() {
        val builder = SourceSlice.between(logHooks, "fun requestFields(", "fun resolvedFields(")
        assertSourceContains(builder, "DIR_REQUEST", "requestFields")
        assertSourceContains(builder, "REQUEST_ID_FIELD", "requestFields")
        assertSourceContains(builder, "TYPE_FIELD", "requestFields")
        assertSourceLacks(builder, "payload", "requestFields (no payload transport)")
    }

    /**
     * 回话记录的公共判据：先有 resolve 脚本注入，再有记录。
     *
     * 两条都要在：少了注入 = 网页 Promise 永远悬着；少了记录 = 日志里看不出「到底答了谁」。
     * 顺序反了（先记后注入）等于把「准备回话」记成「已回话」——注入失败时日志会说谎。
     */
    private fun assertReplyRecord(body: String, recordMarker: String, label: String) {
        assertSourceContains(body, "warehouseBridgeResolveScript(", label)
        assertSourceContains(body, recordMarker, label)
        val resolveAt = body.indexOf("warehouseBridgeResolveScript(")
        val recordAt = body.indexOf(recordMarker)
        assertTrue(
            "$label: $recordMarker must come after warehouseBridgeResolveScript(; " +
                "resolveAt=$resolveAt recordAt=$recordAt",
            resolveAt >= 0 && recordAt > resolveAt,
        )
    }

    private companion object {
        const val WEB_VIEW_HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebViewHost.kt"
        const val LOGIN_HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt"
        const val LOG_HOOKS_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseLogHooks.kt"

        /** 桥代理注册之后就是 WebView 装配段：用它把 `postMessage` 路径切片收尾。 */
        const val JAVASCRIPT_INTERFACE = "webView.addJavascriptInterface("
    }
}
