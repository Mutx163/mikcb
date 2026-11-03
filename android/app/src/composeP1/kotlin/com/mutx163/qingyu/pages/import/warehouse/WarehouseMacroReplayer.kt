package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * 「快捷导入」宏回放引擎（I2-5；对齐 Dart `lib/widgets/warehouse_macro_replayer.dart`）。
 *
 * 职责边界：
 * - 只操作 [WarehouseWebViewController]（导航 / 注入 JS / 读 URL），不碰仓储、不写课表；
 * - 回放成功后的「执行导入脚本」由宿主负责（Dart `_startPlayback` 的 `onSuccess`）；
 * - 需要人工接管（密码/验证码）时通过 [onManualInput] 暂停，等用户在原生覆盖层点「继续」。
 *
 * ## 与 Dart 同一套回放口径（别简化）
 *
 * 1. **先压缩逐字填充**：旧宏把「a → ab → abc」记成三次 fill，加载时只留最终值；
 * 2. **先走加速路径**：登录前缀 + navigate(scriptPageUrl)；加速路径失败**不立刻报错**，
 *    而是提示「快捷路径失败」→ 重新载入入口页 → 用完整录制步骤重跑一次；
 * 3. **点击后用 href 变化判页**：只有上一步点击真把文档带走了，才把紧随其后的
 *    `submit` 点击当作旧宏作废步骤跳过（[shouldSkipStaleClickStep]）；
 * 4. 填充/点击后都等页面就绪（URL 非空 + readyState，超时也放过 + 800ms 沉降）。
 *
 * 线程：在主线程协程里跑（WebView 同线程）；所有等待用 `delay` 轮询，不阻塞 UI。
 */

enum class WarehouseReplayStatus {
    PENDING,
    NAVIGATING,
    FILLING,
    CLICKING,
    WAITING_URL,
    WAITING_ELEMENT,
    WAITING_MANUAL_INPUT,
    EXECUTING_SCRIPT,
    DELAY,
    WAITING_PAGE_LOAD,
}

data class WarehouseReplayProgress(
    val stepIndex: Int,
    val totalSteps: Int,
    val step: WarehouseMacroStep,
    val status: WarehouseReplayStatus,
)

sealed class WarehouseReplayOutcome {
    object Success : WarehouseReplayOutcome()
    object Cancelled : WarehouseReplayOutcome()
    data class Failed(val message: String) : WarehouseReplayOutcome()
}

class WarehouseMacroReplayer(
    private val controller: WarehouseWebViewController,
    private val defaultElementWaitMs: Int = DEFAULT_MACRO_ELEMENT_WAIT_MS,
    private val entryReadyTimeoutMs: Int = 15000,
) {
    @Volatile
    private var cancelled = false

    fun cancel() {
        cancelled = true
    }

    private sealed class RunResult {
        object Success : RunResult()
        object Cancelled : RunResult()
        data class Failure(val message: String) : RunResult()
    }

    suspend fun execute(
        record: WarehouseMacroRecord,
        onProgress: (WarehouseReplayProgress) -> Unit,
        onTip: (String) -> Unit,
        onManualInput: suspend (WarehouseMacroStep) -> Boolean,
    ): WarehouseReplayOutcome {
        cancelled = false
        // 旧宏可能含逐字 fillField；加载时压缩，避免「已填满又重输」。
        val fullSteps = compactWarehouseMacroFillSteps(record.steps)
        if (fullSteps.isEmpty()) {
            return WarehouseReplayOutcome.Failed(failureText("macro_no_steps"))
        }
        // 先把进度摆到「第 1 / N 步」，再去等页面（等待期读数才是对的）。
        onProgress(
            WarehouseReplayProgress(
                stepIndex = 1,
                totalSteps = fullSteps.size,
                step = fullSteps.first(),
                status = WarehouseReplayStatus.PENDING,
            ),
        )

        // 宿主是在页面第一帧就启动回放的：先等入口页成为完整文档（超时也放行）。
        if (record.importUrl.trim().isNotEmpty()) {
            waitForEntryDocumentReady()
        }
        if (cancelled) return WarehouseReplayOutcome.Cancelled

        val acceleratedSteps = buildAcceleratedMacroSteps(
            originalSteps = fullSteps,
            scriptPageUrl = record.scriptPageUrl,
            importUrl = record.importUrl,
        )
        if (acceleratedSteps.size < fullSteps.size) {
            when (val accelerated = runSteps(acceleratedSteps, onProgress, onManualInput)) {
                is RunResult.Success -> return WarehouseReplayOutcome.Success
                is RunResult.Cancelled -> return WarehouseReplayOutcome.Cancelled
                is RunResult.Failure -> {
                    // 加速路径失败不立刻报错：先把入口页重新载入，再用完整步骤兜底。
                    onTip(WarehouseStrings.macroReplayAcceleratedFallbackTip.zh)
                    val entryUrl = sanitizeWarehouseScriptPageUrl(record.importUrl)
                    if (entryUrl != null) {
                        try {
                            executeNavigate(WarehouseMacroStep.navigate(entryUrl))
                        } catch (_: Exception) {
                            // 重载失败交给下面的完整路径自己报。
                        }
                    }
                }
            }
        }

        return when (val full = runSteps(fullSteps, onProgress, onManualInput)) {
            is RunResult.Success -> WarehouseReplayOutcome.Success
            is RunResult.Cancelled -> WarehouseReplayOutcome.Cancelled
            is RunResult.Failure -> WarehouseReplayOutcome.Failed(full.message)
        }
    }

    private suspend fun runSteps(
        steps: List<WarehouseMacroStep>,
        onProgress: (WarehouseReplayProgress) -> Unit,
        onManualInput: suspend (WarehouseMacroStep) -> Boolean,
    ): RunResult {
        // 上一步点击有没有把文档带走（见 shouldSkipStaleClickStep）。
        var previousClickNavigated = false
        for ((index, step) in steps.withIndex()) {
            if (cancelled) return RunResult.Cancelled
            onProgress(
                WarehouseReplayProgress(
                    stepIndex = index + 1,
                    totalSteps = steps.size,
                    step = step,
                    status = statusFor(step.type),
                ),
            )
            try {
                when (step.type) {
                    WarehouseMacroStepType.NAVIGATE -> executeNavigate(step)

                    WarehouseMacroStepType.FILL_FIELD -> executeFillField(step)

                    WarehouseMacroStepType.CLICK -> {
                        val hrefBefore = currentDocumentHref()
                        executeClick(step)
                        previousClickNavigated = macroDocumentChanged(hrefBefore, currentDocumentHref())
                    }

                    WarehouseMacroStepType.WAIT_FOR_URL -> executeWaitForUrl(step)

                    WarehouseMacroStepType.WAIT_FOR_SELECTOR -> executeWaitForSelector(step)

                    WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT -> {
                        if (!onManualInput(step)) return RunResult.Cancelled
                    }

                    WarehouseMacroStepType.EXECUTE_SCRIPT -> Unit

                    WarehouseMacroStepType.DELAY -> delay((step.waitMs.takeIf { it > 0 } ?: 1000).toLong())
                }
            } catch (cancellation: kotlinx.coroutines.CancellationException) {
                throw cancellation
            } catch (failure: Exception) {
                val detail = failure.message ?: failure.toString()
                if (shouldSkipStaleClickStep(
                        stepIsClick = step.type == WarehouseMacroStepType.CLICK,
                        elementNotFound = detail.contains("macro_element_not_found"),
                        previousClickNavigated = previousClickNavigated,
                    )
                ) {
                    // 这一步要点的元素属于「已经翻过去的那一页」：跳过并继续。
                    previousClickNavigated = false
                    continue
                }
                return RunResult.Failure(failureText(detail))
            }
        }
        return if (cancelled) RunResult.Cancelled else RunResult.Success
    }

    private suspend fun executeNavigate(step: WarehouseMacroStep) {
        val url = step.value.orEmpty()
        if (url.isEmpty()) throw IllegalStateException("macro_navigate_url_empty")
        val uri = runCatching { java.net.URI(url) }.getOrNull()
        if (uri == null || uri.host.isNullOrEmpty()) {
            throw IllegalStateException("macro_navigate_url_invalid|url=$url")
        }
        val timeout = step.waitMs.takeIf { it > 0 } ?: 15000
        // 判据是「文档换没换」；导航前的旧页面 URL 本来就非空，只看 URL 非空会第一拍误判通过。
        val beforeHref = currentDocumentHref()
        controller.loadUrl(url)
        val loaded = poll(timeoutMs = timeout) {
            val current = currentDocumentHref()
            isTargetDocumentLoaded(
                beforeHref = beforeHref,
                currentHref = current,
                readyState = awaitReadyState(),
                targetHref = url,
            )
        }
        if (!loaded) throw IllegalStateException("macro_navigate_timeout|target=$url")
        // 额外等待确保页面完全渲染。
        delay(500)
    }

    private suspend fun executeFillField(step: WarehouseMacroStep) {
        val selector = step.selector.orEmpty()
        if (selector.isEmpty()) throw IllegalStateException("macro_fill_selector_empty")
        runElementStep(
            selector = selector,
            waitMs = step.waitMs,
            script = fillFieldScript(selector, step.value.orEmpty()),
        )
        // 填充后等待页面响应。
        waitForPageReady(15000)
    }

    private suspend fun executeClick(step: WarehouseMacroStep) {
        val selector = step.selector.orEmpty()
        if (selector.isEmpty()) throw IllegalStateException("macro_click_selector_empty")
        runElementStep(
            selector = selector,
            waitMs = step.waitMs,
            script = clickScript(selector),
        )
        // 点击后等待页面加载（可能触发导航到新页）。
        waitForPageReady(15000)
    }

    /**
     * 反复尝试直到脚本明确回报「找到了」；整个预算用完才报元素不存在
     * （[macro_element_not_found]，供旧宏的作废点击判定识别）。
     */
    private suspend fun runElementStep(selector: String, waitMs: Int, script: String) {
        val budget = waitMs.takeIf { it > 0 } ?: defaultElementWaitMs
        val found = poll(timeoutMs = budget) {
            macroElementFound(awaitJavaScript(script).orEmpty())
        }
        if (!found) throw IllegalStateException("macro_element_not_found|selector=$selector")
    }

    private suspend fun executeWaitForUrl(step: WarehouseMacroStep) {
        val pattern = step.value.orEmpty()
        if (pattern.isEmpty()) throw IllegalStateException("macro_url_pattern_empty")
        val timeout = step.waitMs.takeIf { it > 0 } ?: 15000
        val matched = poll(timeoutMs = timeout) {
            val current = controller.liveUrl().orEmpty()
            current.isNotEmpty() && current.contains(pattern)
        }
        if (!matched) throw IllegalStateException("macro_wait_url_timeout|pattern=$pattern")
    }

    private suspend fun executeWaitForSelector(step: WarehouseMacroStep) {
        val selector = step.selector.orEmpty()
        if (selector.isEmpty()) throw IllegalStateException("macro_wait_selector_empty")
        val timeout = step.waitMs.takeIf { it > 0 } ?: 15000
        val found = poll(timeoutMs = timeout) {
            macroElementFound(awaitJavaScript(queryElementScript(selector)).orEmpty())
        }
        if (!found) throw IllegalStateException("macro_wait_selector_timeout|selector=$selector")
        delay(500)
    }

    private suspend fun waitForEntryDocumentReady() {
        var elapsed = 0
        while (elapsed < entryReadyTimeoutMs && !cancelled) {
            if (isEntryDocumentReady(controller.liveUrl(), awaitReadyState())) return
            delay(300)
            elapsed += 300
        }
    }

    /** Dart `_waitForPageReady`：URL 非空 + readyState（超时也放过）+ 800ms 沉降。 */
    private suspend fun waitForPageReady(timeoutMs: Int) {
        poll(timeoutMs = timeoutMs) { !controller.liveUrl().isNullOrBlank() }
        var elapsed = 0
        while (elapsed < 15000 && !cancelled) {
            if (awaitReadyState() == "complete") break
            delay(300)
            elapsed += 300
        }
        delay(800)
    }

    private suspend fun poll(timeoutMs: Int, predicate: suspend () -> Boolean): Boolean {
        var elapsed = 0
        while (elapsed < timeoutMs) {
            if (cancelled) return false
            if (predicate()) return true
            delay(300)
            elapsed += 300
        }
        return false
    }

    private suspend fun currentDocumentHref(): String? =
        awaitJavaScript("location.href")?.takeIf { it.isNotEmpty() }

    private suspend fun awaitReadyState(): String? =
        awaitJavaScript("document.readyState")

    private suspend fun awaitJavaScript(script: String): String? =
        withTimeoutOrNull(5000) {
            suspendCancellableCoroutine { continuation ->
                controller.evaluateJavaScript(script) { result ->
                    if (continuation.isActive) continuation.resume(result)
                }
            }
        }

    private fun failureText(detail: String): String =
        WarehouseStrings.macroReplayStatusFailed.filled("error", detail)

    private fun statusFor(type: WarehouseMacroStepType): WarehouseReplayStatus = when (type) {
        WarehouseMacroStepType.NAVIGATE -> WarehouseReplayStatus.NAVIGATING
        WarehouseMacroStepType.FILL_FIELD -> WarehouseReplayStatus.FILLING
        WarehouseMacroStepType.CLICK -> WarehouseReplayStatus.CLICKING
        WarehouseMacroStepType.WAIT_FOR_URL -> WarehouseReplayStatus.WAITING_URL
        WarehouseMacroStepType.WAIT_FOR_SELECTOR -> WarehouseReplayStatus.WAITING_ELEMENT
        WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT -> WarehouseReplayStatus.WAITING_MANUAL_INPUT
        WarehouseMacroStepType.EXECUTE_SCRIPT -> WarehouseReplayStatus.EXECUTING_SCRIPT
        WarehouseMacroStepType.DELAY -> WarehouseReplayStatus.DELAY
    }
}

private fun queryElementScript(selector: String): String =
    "(function(){try{return JSON.stringify({found: document.querySelector(" +
        "${MiniJson.encode(selector)}) !== null});}catch(e){return JSON.stringify({found:false});}})()"

private fun fillFieldScript(selector: String, value: String): String {
    val candidates = MiniJson.encode(macroSelectorCandidates(selector))
    return "(function(){try{var sels=$candidates;var el=null;" +
        "for(var i=0;i<sels.length;i++){el=document.querySelector(sels[i]);if(el)break;}" +
        "if(!el)return JSON.stringify({found:false});" +
        "if(String(el.value||'')===${MiniJson.encode(value)}" +
        ")return JSON.stringify({found:true,skipped:true});" +
        "el.focus();el.value=${MiniJson.encode(value)};" +
        "el.dispatchEvent(new Event('input',{bubbles:true}));" +
        "el.dispatchEvent(new Event('change',{bubbles:true}));" +
        "el.dispatchEvent(new Event('blur',{bubbles:true}));" +
        "return JSON.stringify({found:true});}catch(e){return JSON.stringify({found:false});}})()"
}

private fun clickScript(selector: String): String {
    val candidates = MiniJson.encode(macroSelectorCandidates(selector))
    return "(function(){try{var sels=$candidates;var el=null;" +
        "for(var i=0;i<sels.length;i++){el=document.querySelector(sels[i]);if(el)break;}" +
        "if(!el)return JSON.stringify({found:false});" +
        "if(typeof el.click==='function'){el.click();}" +
        "else{el.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,view:window}));}" +
        "return JSON.stringify({found:true});}catch(e){return JSON.stringify({found:false});}})()"
}
