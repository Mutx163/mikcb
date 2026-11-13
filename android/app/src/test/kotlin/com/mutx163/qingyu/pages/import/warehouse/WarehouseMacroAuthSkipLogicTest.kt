package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.coroutines.startCoroutine

/**
 * 宏回放「会话判定（甲）+ 登录前缀内 fill 跳过（乙）」判据测试（纯 JVM，无 Android/Compose）。
 *
 * ## 这两条判据修的是什么
 *
 * 教务导入 P0 的自动更新失败：适配脚本没问题，是**宏回放**卡住——`fill` / `waitForSelector`
 * 没有「元素不在就跳过」的容忍（只有 click 有），页面一改版、或者用户其实已经登录好了
 * （登录框本来就不在），整条宏就卡在登录前缀第 N 步红掉。
 *
 * 修法分两半：
 * - **甲** [shouldDropAuthPrefixOnReplay]：会话有效时可以把整段登录前缀丢掉。
 *   ⚠️ **当前无生产端**：全仓只有 `WarehouseSessionProbeVerdict` 枚举与一个消费点，
 *   **没有产生 verdict 的 producer**，所以它暂时没有调用点、也不造数据源。
 * - **乙** [shouldSkipWarehouseAuthFillStep]：前缀内单步容忍，信号用**现在就拿得到的**
 *   「当前文档是否已离开入口登录页」（[warehouseMacroDocumentChanged]）。
 *
 * ## 断言消息写法
 *
 * 每条断言都写「**若失败意味着什么**」，而不是复述「期望 false」。这类判据的失败几乎都不是
 * 「写错了」而是「容忍范围被悄悄放宽了」：只看 `expected false but was true` 根本看不出
 * 是把「还在登录页」放过去了，还是把「前缀外」放过去了。
 */
class WarehouseMacroAuthSkipLogicTest {

    // ---------------------------------------------------------------------
    // 甲：只有 ACTIVE 才丢弃登录前缀（5 档）
    // ---------------------------------------------------------------------

    @Test
    fun `甲 只有 ACTIVE 才丢弃登录前缀 其余四档一律不跳`() {
        assertTrue(
            "ACTIVE 返回 false ⇒ 会话明明有效却仍要整段重放登录前缀：甲想跳的场景直接失效",
            shouldDropAuthPrefixOnReplay(WarehouseSessionProbeVerdict.ACTIVE),
        )
        assertFalse(
            "UNKNOWN 返回 true ⇒ 探测没给结论就把登录前缀丢了，这是「不确定也冒险」；" +
                "猜错时人还停在登录页，后面每一步都是「元素不存在」",
            shouldDropAuthPrefixOnReplay(WarehouseSessionProbeVerdict.UNKNOWN),
        )
        assertFalse(
            "INACTIVE 返回 true ⇒ 会话**明确失效**还丢弃登录前缀：整条导入必然拿不到数据，" +
                "这是最坏的一种放宽",
            shouldDropAuthPrefixOnReplay(WarehouseSessionProbeVerdict.INACTIVE),
        )
        assertFalse(
            "TIMEOUT 返回 true ⇒ 探针没答话也被当成有效；超时是「不知道」，必须与 UNKNOWN 同档处理",
            shouldDropAuthPrefixOnReplay(WarehouseSessionProbeVerdict.TIMEOUT),
        )
        assertFalse(
            "null 返回 true ⇒ 「没有裁决」被当成「有效」：verdict producer 尚未存在的现状下，" +
                "等于凭空空跳登录前缀",
            shouldDropAuthPrefixOnReplay(null),
        )
    }

    // ---------------------------------------------------------------------
    // 乙：已离开登录页 + 前缀内 + 元素不在 ⇒ 跳过；其余组合一律不跳
    // ---------------------------------------------------------------------

    @Test
    fun `乙 已离开登录页且前缀内未找到 才允许跳过`() {
        assertTrue(
            "已离开登录页 + 前缀内 + 元素不在 却返回 false ⇒ P0 没修：登录框消失的宏仍然整条红",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 0,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = true,
            ),
        )
        // 边界：前缀内最后一步（下标 authPrefixEnd - 1）必须仍算「前缀内」。
        assertTrue(
            "下标 authPrefixEnd - 1 返回 false ⇒ 前缀最后一步被排除在外，常见形态" +
                "「填账号(0) / 填密码(1) / 点登录(2)」里的第 2 步就永远跳不过去",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 1,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = true,
            ),
        )
    }

    @Test
    fun `乙 未离开登录页时同一条件必须不跳`() {
        assertFalse(
            "pastLoginPage = false 却返回 true ⇒ 人还在登录页就敢跳过填账号：真缺元素时被当成" +
                "「做完了」，这是本条最不能反的方向",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 0,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = false,
            ),
        )
    }

    @Test
    fun `乙 URL 与入口相同即未离开登录页 信号为假 即使未找到也不跳`() {
        // 信号本身由调用方用 warehouseMacroDocumentChanged 算，这里连算法一起钉：
        val importUrl = "http://jw.example.edu.cn/login"
        val stillEntry = warehouseMacroDocumentChanged(
            importUrl,
            "http://jw.example.edu.cn/login#fragment", // 只换锚点不算换页
        )
        assertFalse(
            "入口 URL 与当前 href 只差 fragment 却被判成「已离开」⇒ pastLoginPage 会被顶成 true，" +
                "登录页上的 fill 从此一律可跳：这是把红变成绿的第一个漏洞",
            stillEntry,
        )
        assertFalse(
            "信号为假（仍在登录页）时判据却返回 true ⇒ 与上一条同源，方向反了",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 0,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = stillEntry,
            ),
        )
    }

    @Test
    fun `乙 前缀外一律不跳 边界就是 authPrefixEnd`() {
        assertFalse(
            "stepIndex == authPrefixEnd 返回 true ⇒ 登录后第一步（菜单点击/切 tab）也被放过：门开了，" +
                "后面的导出步骤同样可以「假装成功」而数据没取到。这是本条最必须咬住的边界",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 2,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = true,
            ),
        )
        assertFalse(
            "前缀外更后面的步骤返回 true ⇒ 整条宏都变成容忍模式，前缀判据形同不存在",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 7,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = true,
            ),
        )
    }

    @Test
    fun `乙 元素找到了就不该走跳过支`() {
        assertFalse(
            "elementNotFound = false 却返回 true ⇒ 会把「元素在、脚本执行成功」也当成跳过，" +
                "日志里留下假记录，排查时时序全乱",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 0,
                authPrefixEnd = 2,
                elementNotFound = false,
                pastLoginPage = true,
            ),
        )
    }

    @Test
    fun `乙 识别不出登录前缀时一条都不跳`() {
        assertFalse(
            "authPrefixEnd = 0（前缀识别不出来）却返回 true ⇒ 整条宏任意一步都能被跳过；" +
                "没有前缀就没有「登录段内」这个坐标系，容忍必须整体关闭",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = 0,
                authPrefixEnd = 0,
                elementNotFound = true,
                pastLoginPage = true,
            ),
        )
    }

    @Test
    fun `乙 负下标不许被当成前缀内`() {
        assertFalse(
            "stepIndex = -1 却返回 true ⇒ 越界写法被当成「前缀内」：调用方一旦算错下标，" +
                "判据反而替它放行",
            shouldSkipWarehouseAuthFillStep(
                stepIndex = -1,
                authPrefixEnd = 2,
                elementNotFound = true,
                pastLoginPage = true,
            ),
        )
    }

    // ---------------------------------------------------------------------
    // 行为级：真跑一遍回放引擎，钉「离开登录页才跳」与「还在登录页零变化」
    // ---------------------------------------------------------------------

    @Test
    fun `行为级 已离开入口登录页时前缀内 fill 未找到被跳过并留痕`() {
        // 入口是 login 页，但当前文档已经在 xsMain.jsp（登录后的落地页）。
        val page = FakePage(
            elementResult = { """{"found":false,"selector":"#missing"}""" },
            href = "http://jw.example.edu.cn/xsMain.jsp",
        )
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val skips = mutableListOf<String>()
        val replayer = newReplayer(page, clock, callbacks, skips)

        runSuspend { replayer.execute(macro(listOf(fill("#missing")))) }

        assertTrue("回放没跑完（挂起了？回调桥接坏了）", callbacks.completed)
        assertEquals(
            "已离开登录页 + 前缀内 fill 未找到，回放却报失败 ⇒ P0 未修：这一步照旧整条红",
            true,
            callbacks.success,
        )
        assertNull("成功路径不该带错误负载", callbacks.errorMessage)
        assertEquals(
            "跳过一步却没有留痕 ⇒ 将来「导入成功但数据不对」查不出是这里放过的",
            1,
            skips.size,
        )
        assertTrue(
            "留痕里应带步骤序号与原因，实际=${skips.singleOrNull()}",
            skips.single().contains("step=1/1") &&
                skips.single().contains("reason=element_not_found_in_auth_prefix"),
        )
    }

    @Test
    fun `行为级 仍在入口登录页时同一宏仍然失败 默认路径零变化`() {
        // 当前文档就是入口登录页（href 与 importUrl 相同）⇒ pastLoginPage = false。
        val page = FakePage(elementResult = { """{"found":false,"selector":"#missing"}""" })
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val skips = mutableListOf<String>()
        val replayer = newReplayer(page, clock, callbacks, skips)

        runSuspend { replayer.execute(macro(listOf(fill("#missing")))) }

        assertTrue("回放没跑完（挂起了？回调桥接坏了）", callbacks.completed)
        assertEquals(
            "还在登录页上、fill 未找到却「成功」了 ⇒ 元素真缺的宏会被静默放过（打工能页面还停在登录页，" +
                "后面每一步都会找不到元素）",
            false,
            callbacks.success,
        )
        assertTrue(
            "失败负载必须仍是 macro_step_failed + 元素不存在，实际=${callbacks.errorMessage}",
            callbacks.errorMessage!!.contains("macro_step_failed") &&
                callbacks.errorMessage!!.contains("macro_element_not_found"),
        )
        assertTrue(
            "未离开登录页时不该产生任何跳过留痕，实际=$skips",
            skips.isEmpty(),
        )
    }

    // ---------------------------------------------------------------------
    // 与现有 scaffold 同形的最小装置（不复用 WarehouseMacroReplayerTest 的私有类）
    // ---------------------------------------------------------------------

    /** 虚拟时钟：sleep 推进、nowMs 读数——10s/15s 预算在虚拟时钟下瞬时跑完。 */
    private class VirtualClock {
        var now: Long = 0L
        fun nowMs(): Long = now
        suspend fun sleep(ms: Long) {
            now += ms
        }
    }

    private class RecordingCallbacks : WarehouseMacroReplayer.Callbacks {
        val progressEvents = mutableListOf<WarehouseReplayProgress>()
        var completed = false
        var success: Boolean? = null
        var errorMessage: String? = null

        override fun onProgress(progress: WarehouseReplayProgress) {
            progressEvents.add(progress)
        }

        override suspend fun onPauseForManualInput(step: WarehouseMacroStep, reason: String): Boolean = true

        override fun onShowTip(message: String) {}

        override fun onComplete(success: Boolean, errorMessage: String?) {
            completed = true
            this.success = success
            this.errorMessage = errorMessage
        }
    }

    /** 文档状态假页面：href / readyState 给定，元素类脚本一律回 [elementResult]。 */
    private class FakePage(
        private val elementResult: (String) -> String?,
        var href: String = "http://jw.example.edu.cn/login",
    ) {
        var readyState: String = "complete"
        val executedScripts = mutableListOf<String>()

        fun evalJs(script: String): String? {
            executedScripts.add(script)
            return when (script) {
                "location.href" -> href
                "document.readyState" -> readyState
                else -> elementResult(script)
            }
        }
    }

    private fun newReplayer(
        page: FakePage,
        clock: VirtualClock,
        callbacks: RecordingCallbacks,
        skips: MutableList<String>,
    ): WarehouseMacroReplayer = WarehouseMacroReplayer(
        evalJs = { script -> page.evalJs(script) },
        loadUrl = { url -> page.href = url; page.readyState = "complete" },
        callbacks = callbacks,
        sleep = { clock.sleep(it) },
        nowMs = { clock.nowMs() },
        onSkipLog = { skips.add(it) },
    )

    private fun fill(selector: String, value: String = "v") =
        WarehouseMacroStep.fillField(selector, value, "username")

    private fun macro(
        steps: List<WarehouseMacroStep>,
        importUrl: String = "http://jw.example.edu.cn/login",
    ): WarehouseMacroRecord {
        val now = java.time.LocalDateTime.parse("2026-11-03T09:00:00")
        return WarehouseMacroRecord(
            schoolId = "s1",
            adapterId = "a1",
            schoolName = "示例大学",
            adapterName = "教务A",
            importUrl = importUrl,
            schoolResourceFolder = "s1",
            adapterAssetJsPath = "a.js",
            steps = steps,
            createdAt = now,
            updatedAt = now,
        )
    }

    /** 同步驱动挂起块（L0 classpath 没有 coroutines-test）：异常原样抛出，不吞。 */
    private fun runSuspend(block: suspend () -> Unit) {
        block.startCoroutine(
            kotlin.coroutines.Continuation(kotlin.coroutines.EmptyCoroutineContext) { result ->
                result.exceptionOrNull()?.let { throw it }
            },
        )
    }
}
