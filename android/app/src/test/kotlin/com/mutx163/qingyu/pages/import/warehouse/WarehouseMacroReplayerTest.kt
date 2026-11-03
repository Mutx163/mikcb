package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.coroutines.startCoroutine

/**
 * 回放执行体测试（P2 / N7）：注入式 evalJs + 虚拟时钟 + no-op sleep，
 * 预算（10s/15s）在虚拟时钟下瞬时跑完；脚本内容断言钉「照抄旧版」的形状。
 */
class WarehouseMacroReplayerTest {

    /** 虚拟时钟：sleep 推进，nowMs 读数——预算循环可瞬时走完。 */
    private class VirtualClock {
        var now: Long = 0L
        fun nowMs(): Long = now
        suspend fun sleep(ms: Long) {
            now += ms
        }
    }

    private class RecordingCallbacks : WarehouseMacroReplayer.Callbacks {
        val progressEvents = mutableListOf<WarehouseReplayProgress>()
        val tips = mutableListOf<String>()
        var completed = false
        var success: Boolean? = null
        var errorMessage: String? = null
        var pauseResume: Boolean = true
        var pauseCount = 0

        override fun onProgress(progress: WarehouseReplayProgress) {
            progressEvents.add(progress)
        }

        override suspend fun onPauseForManualInput(step: WarehouseMacroStep, reason: String): Boolean {
            pauseCount++
            return pauseResume
        }

        override fun onShowTip(message: String) {
            tips.add(message)
        }

        override fun onComplete(success: Boolean, errorMessage: String?) {
            completed = true
            this.success = success
            this.errorMessage = errorMessage
        }
    }

    private fun macro(
        steps: List<WarehouseMacroStep>,
        scriptPageUrl: String? = null,
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
            scriptPageUrl = scriptPageUrl,
        )
    }

    /** 文档状态假页面：href / readyState 可随脚本切换；「点登录」后翻页（回放语义）。 */
    private class FakePage {
        var href: String = "http://jw.example.edu.cn/login"
        var readyState: String = "complete"
        var elementResult: (script: String) -> String? = { """{"found":false}""" }
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
        loadedUrls: MutableList<String>,
    ): WarehouseMacroReplayer = WarehouseMacroReplayer(
        evalJs = { script -> page.evalJs(script) },
        loadUrl = { url ->
            loadedUrls.add(url)
            // 导航后页面换址（判据要求「文档变化」），readyState 走过 loading。
            page.href = url
            page.readyState = "complete"
        },
        callbacks = callbacks,
        sleep = { clock.sleep(it) },
        nowMs = { clock.nowMs() },
    )

    private fun record(
        steps: List<WarehouseMacroStep>,
        scriptPageUrl: String?,
        importUrl: String,
    ): WarehouseMacroRecord = macro(steps, scriptPageUrl, importUrl)

    /**
     * 同步驱动挂起块（L0 classpath 没有 coroutines-test）：注入的 sleep/evalJs
     * 都不真挂起，startCoroutine 会同步跑完；完成续体把异常原样抛出（不吞），
     * 若意外挂起，各用例的 completed 断言会红，不会假绿。
     */
    private fun runSuspend(block: suspend () -> Unit) {
        block.startCoroutine(
            kotlin.coroutines.Continuation(kotlin.coroutines.EmptyCoroutineContext) { result ->
                result.exceptionOrNull()?.let { throw it }
            },
        )
    }

    private fun fill(selector: String, value: String = "v") =
        WarehouseMacroStep.fillField(selector, value, "username")

    // ---------------------------------------------------------------------
    // 全流程成功
    // ---------------------------------------------------------------------

    @Test
    fun `全流程成功 进度与完成回调齐全`() {
        val page = FakePage()
        page.elementResult = { script ->
            if (script.contains("\"#btnLogin\"")) {
                // 点登录 → 表单提交翻页（回放语义：点击把页面带走）
                page.href = "http://jw.example.edu.cn/xsMain.jsp"
            }
            """{"found":true,"tag":"INPUT"}"""
        }
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val loaded = mutableListOf<String>()
        val replayer = newReplayer(page, clock, callbacks, loaded)

        runSuspend {
            replayer.execute(
                macro(
                    listOf(
                        fill("#user", "20230001"),
                        WarehouseMacroStep.click("#btnLogin"),
                        WarehouseMacroStep.delay(2500),
                        WarehouseMacroStep.waitForUrl("xsMain"),
                    ),
                ),
            )
        }

        assertTrue("回放应跑完", callbacks.completed)
        assertEquals(true, callbacks.success)
        assertNull(callbacks.errorMessage)
        // 进度序列：先摆「第 1 / 4 步」（PENDING），等待页面期间读数才不是「第 1 / 0 步」
        assertEquals(4, callbacks.progressEvents.first().totalSteps)
        assertEquals(ReplayStepStatus.PENDING, callbacks.progressEvents.first().status)
        // fill 的注入脚本含候选选择器与正确值（照抄旧版形状的形状钉）
        val fillScript = page.executedScripts.first { it.contains("querySelector") && it.contains("focus()") }
        assertTrue(fillScript.contains("input[name=\\\"user\\\"]"))
        assertTrue(fillScript.contains("20230001"))
        assertTrue(fillScript.contains("dispatchEvent(new Event('change'"))
    }

    // ---------------------------------------------------------------------
    // 元素找不到：10s 预算耗尽 → macro_element_not_found（卡在哪一步可解释）
    // ---------------------------------------------------------------------

    @Test
    fun `元素找不到 预算耗尽报元素不存在并带步数`() {
        val page = FakePage()
        page.elementResult = { """{"found":false,"selector":"#missing"}""" }
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val replayer = newReplayer(page, clock, callbacks, mutableListOf())

        runSuspend {
            replayer.execute(macro(listOf(fill("#missing"))))
        }

        assertTrue(callbacks.completed)
        assertEquals(false, callbacks.success)
        val payload = callbacks.errorMessage!!
        val info = parseMacroStepFailed(payload)
        assertEquals(1, info!!.stepIndex)
        assertEquals(1, info.totalSteps)
        assertEquals("macro_element_not_found", info.detail)
        // 失败前经历了多拍轮询（预算 10s / 每拍 300ms）
        assertTrue("应轮询多拍而非一次放弃", clock.now >= 10000)
    }

    // ---------------------------------------------------------------------
    // 作废步骤跳过（旧宏第二次点击打在已翻过去的页面上）
    // ---------------------------------------------------------------------

    @Test
    fun `上一步点击翻页后 找不到的点击跳过且留痕`() {
        val page = FakePage()
        page.elementResult = { script ->
            if (script.contains("\"#btnLogin\"")) {
                // 第一下点击完成跳转：页面被带走
                page.href = "http://jw.example.edu.cn/xsMain.jsp"
                """{"found":true}"""
            } else {
                // 第二下点击打在新页面上：明确没找到
                """{"found":false,"selector":"#Form1"}"""
            }
        }
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val skips = mutableListOf<String>()
        val loaded = mutableListOf<String>()
        val replayer = WarehouseMacroReplayer(
            evalJs = { script -> page.evalJs(script) },
            loadUrl = { url -> loaded.add(url); page.href = url; page.readyState = "complete" },
            callbacks = callbacks,
            sleep = { clock.sleep(it) },
            nowMs = { clock.nowMs() },
            onSkipLog = { skips.add(it) },
        )

        runSuspend {
            replayer.execute(
                macro(
                    listOf(
                        WarehouseMacroStep.click("#btnLogin"),
                        WarehouseMacroStep.click("#Form1"),
                    ),
                ),
            )
        }

        assertTrue(callbacks.completed)
        assertEquals(true, callbacks.success)
        assertEquals(1, skips.size)
        assertTrue(skips.single().contains("selector=#Form1"))
    }

    // ---------------------------------------------------------------------
    // 等待手动输入：继续 → 往下跑；拒绝 → 用户取消
    // ---------------------------------------------------------------------

    @Test
    fun `等待手动输入 false 即用户取消`() {
        val page = FakePage()
        page.elementResult = { """{"found":true}""" }
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        callbacks.pauseResume = false
        val replayer = newReplayer(page, clock, callbacks, mutableListOf())

        runSuspend {
            replayer.execute(
                macro(listOf(WarehouseMacroStep.waitForManualInput("manual_input_captcha", "#code", "captcha"))),
            )
        }

        assertTrue(callbacks.completed)
        assertEquals(false, callbacks.success)
        assertTrue(callbacks.errorMessage!!.contains("macro_user_cancelled"))
        assertEquals(1, callbacks.pauseCount)
    }

    // ---------------------------------------------------------------------
    // 加速路径：成功不跑全量；失败静默回退并提示
    // ---------------------------------------------------------------------

    @Test
    fun `加速成功 不再跑全量步骤`() {
        val page = FakePage()
        page.elementResult = { """{"found":true}""" }
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val loaded = mutableListOf<String>()
        val replayer = newReplayer(page, clock, callbacks, loaded)

        val full = listOf(
            fill("#user"),
            WarehouseMacroStep.click("#btnLogin"),
            WarehouseMacroStep.delay(2500),
            WarehouseMacroStep.click("#menuKb"),
            WarehouseMacroStep.delay(800),
            WarehouseMacroStep.waitForUrl("xsMain"),
        )
        runSuspend {
            replayer.execute(
                macro(full, scriptPageUrl = "http://jw.example.edu.cn/xsMain.jsp"),
            )
        }

        assertTrue(callbacks.completed)
        assertEquals(true, callbacks.success)
        // 加速路径 = 前缀(3) + navigate + delay；脚本页的 menu 点击（#menuKb）不应被执行
        val scripts = page.executedScripts.joinToString("\n")
        assertTrue(!scripts.contains("\"#menuKb\""))
        assertTrue(loaded.contains("http://jw.example.edu.cn/xsMain.jsp"))
    }

    @Test
    fun `加速失败静默回退 提示后走全量`() {
        val page = FakePage()
        page.elementResult = { """{"found":true}""" }
        // 加速 navigate 后页面地址不变 → isTargetDocumentLoaded 永不满足 → 加速失败
        val clock = VirtualClock()
        val callbacks = RecordingCallbacks()
        val loaded = mutableListOf<String>()
        val replayer = WarehouseMacroReplayer(
            evalJs = { script -> page.evalJs(script) },
            loadUrl = { url ->
                loaded.add(url)
                // 快捷导航被站点弹回登录页：href 不变 → 目标加载判据超时
                page.href = "http://jw.example.edu.cn/login"
                page.readyState = "complete"
            },
            callbacks = callbacks,
            sleep = { clock.sleep(it) },
            nowMs = { clock.nowMs() },
        )

        val full = listOf(
            fill("#user"),
            WarehouseMacroStep.click("#btnLogin"),
            WarehouseMacroStep.delay(2500),
            WarehouseMacroStep.click("#menuKb"),
            WarehouseMacroStep.delay(800),
            WarehouseMacroStep.click("#menuExport"),
        )
        runSuspend {
            replayer.execute(
                macro(full, scriptPageUrl = "http://jw.example.edu.cn/xsMain.jsp"),
            )
        }

        assertTrue(callbacks.completed)
        assertEquals(true, callbacks.success)
        assertEquals(
            "回退前必须提示（macroReplayAcceleratedFallbackTip）",
            WarehouseMacroReplayStrings.macroReplayAcceleratedFallbackTip.zh,
            callbacks.tips.single(),
        )
        // 回退要先重载入口地址，再走全量（#menuKb 这一步在全量里被执行到）
        assertTrue(loaded.contains("http://jw.example.edu.cn/login"))
        assertTrue(page.executedScripts.any { it.contains("\"#menuKb\"") })
    }

    // ---------------------------------------------------------------------
    // 空宏与导航坏地址
    // ---------------------------------------------------------------------

    @Test
    fun `空宏报 no_steps 不崩`() {
        val callbacks = RecordingCallbacks()
        val replayer = WarehouseMacroReplayer(
            evalJs = { null },
            loadUrl = {},
            callbacks = callbacks,
            sleep = {},
        )
        runSuspend {
            replayer.execute(macro(emptyList()))
        }
        assertTrue(callbacks.completed)
        assertEquals(false, callbacks.success)
        assertEquals("macro_no_steps", callbacks.errorMessage)
    }

    @Test
    fun `导航坏地址报可解释失败`() {
        val callbacks = RecordingCallbacks()
        val replayer = WarehouseMacroReplayer(
            evalJs = { null },
            loadUrl = {},
            callbacks = callbacks,
            sleep = {},
        )
        runSuspend {
            replayer.execute(macro(listOf(WarehouseMacroStep.navigate("not-a-url"))))
        }
        assertTrue(callbacks.completed)
        assertTrue(
            "失败负载应能本地化成人话（无效的 URL: …）",
            WarehouseMacroReplayStrings.localize(callbacks.errorMessage!!).contains("无效的 URL"),
        )
    }

    // ---------------------------------------------------------------------
    // 注入脚本形状（照抄旧版钉形状，不做行为断言）
    // ---------------------------------------------------------------------

    @Test
    fun `fill 脚本对已有正确值跳过改写 click 脚本兜底 MouseEvent`() {
        val fillJs = WarehouseMacroReplayer.fillElementJs("#user", "20230001")
        assertTrue(fillJs.contains("skipped: true"))
        assertTrue(fillJs.contains("String(el.value || '') === \"20230001\""))
        val clickJs = WarehouseMacroReplayer.clickElementJs("#btn")
        assertTrue(clickJs.contains("el.click()"))
        assertTrue(clickJs.contains("new MouseEvent('click'"))
        // 纯 id 派生 name 候选进脚本（JSON 内层引号带转义）
        assertTrue(clickJs.contains("input[name=\\\"btn\\\"]"))
    }
}
