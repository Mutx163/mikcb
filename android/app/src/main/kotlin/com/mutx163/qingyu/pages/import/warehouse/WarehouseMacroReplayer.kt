package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.util.concurrent.CancellationException

/**
 * 宏回放引擎（P2 / N7 执行体）——**协程轮询版**。
 *
 * 与 Dart 版的模型差异（方案 §4.1，不能照搬清单第 1 条）：
 * Dart 的 `runJavaScriptReturningResult` 是同步等待、`await` 串起轮询；Kotlin 的
 * `evaluateJavascript` 是回调。本类把「求一次值」抽象成挂起函数 [evalJs]
 * （宿主用 `suspendCancellableCoroutine` 桥接平台回调并做结果归一化），
 * 轮询写成 `while + sleep(300)`，取消靠协程取消（不再需要 `_isCancelled` 布尔；
 * 所有 catch 都先放行 [CancellationException]）。
 *
 * ## 时序原语是注入的（L0 纪律）
 *
 * L0 的 JVM classpath 只有 kotlin-stdlib + junit，**没有 kotlinx-coroutines**；
 * 但 `suspend` 声明本身只需 stdlib。所以等待与时钟全部注入：
 * - [sleep]：宿主传 `{ kotlinx.coroutines.delay(it) }`（真机真实等待 + 响应取消），
 *   测试传 `{}`（no-op）；
 * - [nowMs]：宿主用默认 `System::currentTimeMillis`，测试注入可推进的虚拟时钟。
 * 预算数值逐字保留且在虚拟时钟下可瞬时跑完。
 *
 * **预算数值逐字保留**（硬要求）：等元素默认 10s（步骤自带 waitMs 优先）、
 * 等导航/URL/选择器默认 15s、入口文档就绪上限 15s、轮询一拍 300ms、
 * fill/click 成功后等页面 ready（URL 非空轮询 + readyState==complete 轮询 15s + 800ms）、
 * navigate 成功后固定 500ms、delay 步无预算时 1000ms。
 *
 * 失败全部以 `code|k=v` 服务消息抛出（[WarehouseMacroReplayStrings.localize] 负责人话），
 * 不静默吞——「卡在第几步、卡在哪个元素」必须能讲清楚。
 *
 * 纯 JVM：不 import `android.*`；WebView 平台桥在 composeP1 宿主里。
 */
class WarehouseMacroReplayer(
    /**
     * 求值一段 JS 并返回**归一化后的结果**（平台 JSON 文本已解引号转义，
     * 见 [decodeWarehouseJsResult]）；视图未挂载 / JS 上下文销毁时返回 null。
     */
    private val evalJs: suspend (String) -> String?,
    /** 导航到指定地址（不替换导航代理：宿主的回调链在驱动导入状态机）。 */
    private val loadUrl: (String) -> Unit,
    private val callbacks: Callbacks,
    /** 等待原语：生产路径传协程 `delay`；JVM 测试传 no-op。 */
    private val sleep: suspend (Long) -> Unit,
    /** 时钟：生产路径默认系统毫秒钟；测试注入可推进的虚拟时钟。 */
    private val nowMs: () -> Long = System::currentTimeMillis,
    private val pollIntervalMs: Long = MACRO_POLL_INTERVAL_MS,
    private val entryReadyTimeoutMs: Long = MACRO_ENTRY_READY_TIMEOUT_MS,
    private val defaultElementWaitMs: Int = DEFAULT_MACRO_ELEMENT_WAIT_MS,
    /** 作废步骤跳过留痕（宿主接 Log.w 进导入日志；本类不依赖 android.util.Log）。 */
    private val onSkipLog: (String) -> Unit = {},
) {
    /** 回放引擎回调（Dart `ReplayCallbacks` 同形）。 */
    interface Callbacks {
        /** 进度更新（覆盖层「第 N / M 步」+「正在……」行）。 */
        fun onProgress(progress: WarehouseReplayProgress)

        /** 需要用户手动操作（验证码/无凭据密码）。挂起至用户作答；false = 取消。 */
        suspend fun onPauseForManualInput(step: WarehouseMacroStep, reason: String): Boolean

        /** 回放过程提示（加速回退等）。 */
        fun onShowTip(message: String)

        /** 回放结束：success + 失败时的服务消息负载（null = 成功或用户取消）。 */
        fun onComplete(success: Boolean, errorMessage: String?)
    }

    /** 执行整份宏。协程取消即用户取消（不额外报失败）。 */
    suspend fun execute(macro: WarehouseMacroRecord) {
        // 旧宏可能含逐字 fillField；先压缩，避免「已填满又重输」。
        val fullSteps = WarehouseMacroRecordingConverter.compactMacroFillSteps(macro.steps)
        if (fullSteps.isEmpty()) {
            callbacks.onComplete(false, encodeMacroServiceMessage("macro_no_steps"))
            return
        }

        // 先把进度摆到「第 1 / N 步」，再去等页面（否则等待期间显示「第 1 / 0 步」）。
        callbacks.onProgress(
            WarehouseReplayProgress(0, fullSteps.size, fullSteps.first(), ReplayStepStatus.PENDING),
        )

        waitForEntryDocumentReady(macro.importUrl)

        val acceleratedSteps = buildWarehouseAcceleratedMacroSteps(
            fullSteps,
            scriptPageUrl = macro.scriptPageUrl,
            importUrl = macro.importUrl,
        )
        if (acceleratedSteps.size < fullSteps.size) {
            val acceleratedSucceeded = runSteps(acceleratedSteps, reportFailureToHost = false)
            if (acceleratedSucceeded) return
            // 快捷路径失败：提示 + 重载入口页后走全量（失败静默，全量才报给宿主）。
            callbacks.onShowTip(WarehouseMacroReplayStrings.macroReplayAcceleratedFallbackTip.zh)
            val entryUrl = sanitizeWarehouseScriptPageUrl(macro.importUrl)
            if (entryUrl != null) {
                try {
                    executeNavigate(WarehouseMacroStep.navigate(entryUrl))
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    // 重载也失败：交给全量路径自己报失败。
                }
            }
        }

        runSteps(fullSteps, reportFailureToHost = true)
    }

    /** 顺序执行步骤；全成功返回 true。失败细节见类注释。 */
    private suspend fun runSteps(steps: List<WarehouseMacroStep>, reportFailureToHost: Boolean): Boolean {
        // 上一步点击有没有把文档带走（作废步骤判据的第三条件）。
        var previousClickNavigated = false
        for (i in steps.indices) {
            val step = steps[i]
            callbacks.onProgress(
                WarehouseReplayProgress(i, steps.size, step, ReplayStepStatus.RUNNING),
            )

            val hrefBeforeStep = if (step.type == WarehouseMacroStepType.CLICK) currentDocumentHref() else null
            val detail: String = try {
                executeStep(step)
                if (hrefBeforeStep != null) {
                    previousClickNavigated =
                        warehouseMacroDocumentChanged(hrefBeforeStep, currentDocumentHref())
                }
                callbacks.onProgress(
                    WarehouseReplayProgress(i, steps.size, step, ReplayStepStatus.SUCCEEDED),
                )
                continue
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                error.message ?: error.javaClass.simpleName
            }

            if (shouldSkipWarehouseStaleClickStep(
                    stepIsClick = step.type == WarehouseMacroStepType.CLICK,
                    elementNotFound = detail.startsWith("macro_element_not_found"),
                    previousClickNavigated = previousClickNavigated,
                )
            ) {
                // 这一步要点的元素属于「已经翻过去的那一页」：跳过并继续。必须留痕：
                // 少做一步要有日志可查，将来「导入成功但数据不对」要能解释是这里放过的。
                onSkipLog(
                    "playback skipped stale click step=${i + 1}/${steps.size} " +
                        "selector=${step.selector} reason=element_not_found_after_navigation",
                )
                previousClickNavigated = false
                continue
            }

            callbacks.onProgress(
                WarehouseReplayProgress(
                    i,
                    steps.size,
                    step,
                    ReplayStepStatus.FAILED,
                    errorMessage = detail,
                ),
            )
            if (reportFailureToHost) {
                callbacks.onComplete(
                    false,
                    encodeMacroServiceMessage(
                        "macro_step_failed",
                        "stepIndex" to (i + 1),
                        "totalSteps" to steps.size,
                        "detail" to detail,
                    ),
                )
            }
            return false
        }

        callbacks.onComplete(true, null)
        return true
    }

    private suspend fun executeStep(step: WarehouseMacroStep) {
        when (step.type) {
            WarehouseMacroStepType.NAVIGATE -> executeNavigate(step)
            WarehouseMacroStepType.FILL_FIELD -> executeFillField(step)
            WarehouseMacroStepType.CLICK -> executeClick(step)
            WarehouseMacroStepType.WAIT_FOR_URL -> executeWaitForUrl(step)
            WarehouseMacroStepType.WAIT_FOR_SELECTOR -> executeWaitForSelector(step)
            WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT -> executeWaitForManualInput(step)
            WarehouseMacroStepType.EXECUTE_SCRIPT -> {
                // 脚本执行由宿主在回放完成后处理（自动执行导入脚本），引擎只标记。
            }

            WarehouseMacroStepType.DELAY -> sleep((if (step.waitMs > 0) step.waitMs else 1000).toLong())
        }
    }

    private suspend fun executeNavigate(step: WarehouseMacroStep) {
        val url = step.value ?: ""
        if (url.isEmpty()) throw IllegalStateException(encodeMacroServiceMessage("macro_navigate_url_empty"))
        if (warehouseUrlHost(url).isEmpty()) {
            throw IllegalStateException(encodeMacroServiceMessage("macro_navigate_url_invalid", "url" to url))
        }
        val timeoutMs = (if (step.waitMs > 0) step.waitMs else MACRO_DEFAULT_NAVIGATION_WAIT_MS).toLong()

        // 导航前先读当前文档地址：判据是「文档换没换」，不是「URL 非空」——
        // 旧页面的 URL 本来就非空，那种条件第一拍就过，等于没等。
        val beforeHref = currentDocumentHref()
        loadUrl(url)
        pollCondition(
            stepLabel = WarehouseMacroReplayStrings.macroReplayNavigateTo.filled("url" to url),
            timeoutMs = timeoutMs,
        ) {
            val state = currentDocumentState()
            isWarehouseTargetDocumentLoaded(
                beforeHref = beforeHref,
                currentHref = state?.first,
                readyState = state?.second,
                targetHref = url,
            )
        }
        sleep(500)
    }

    private suspend fun executeFillField(step: WarehouseMacroStep) {
        val selector = step.selector ?: ""
        val value = step.value ?: ""
        if (selector.isEmpty()) throw IllegalStateException(encodeMacroServiceMessage("macro_fill_selector_empty"))
        runElementStep(selector, step.waitMs, fillElementJs(selector, value))
        // 填充后等待页面响应。
        waitForPageReady(timeoutMs = 15000)
    }

    private suspend fun executeClick(step: WarehouseMacroStep) {
        val selector = step.selector ?: ""
        if (selector.isEmpty()) throw IllegalStateException(encodeMacroServiceMessage("macro_click_selector_empty"))
        runElementStep(selector, step.waitMs, clickElementJs(selector))
        // 点击后等待页面加载（可能触发导航到新页）。
        waitForPageReady(timeoutMs = 15000)
    }

    private suspend fun executeWaitForUrl(step: WarehouseMacroStep) {
        val pattern = step.value ?: ""
        if (pattern.isEmpty()) throw IllegalStateException(encodeMacroServiceMessage("macro_url_pattern_empty"))
        pollCondition(
            stepLabel = WarehouseMacroReplayStrings.macroReplayWaitUrlPattern.filled("pattern" to pattern),
            timeoutMs = (if (step.waitMs > 0) step.waitMs else MACRO_DEFAULT_NAVIGATION_WAIT_MS).toLong(),
        ) {
            val href = currentDocumentHref()
            href != null && href.contains(pattern)
        }
    }

    private suspend fun executeWaitForSelector(step: WarehouseMacroStep) {
        val selector = step.selector ?: ""
        if (selector.isEmpty()) throw IllegalStateException(encodeMacroServiceMessage("macro_wait_selector_empty"))
        val probe = "document.querySelector(${MiniJson.encode(selector)}) !== null"
        pollCondition(
            stepLabel = WarehouseMacroReplayStrings.macroReplayWaitSelector.filled("selector" to selector),
            timeoutMs = (if (step.waitMs > 0) step.waitMs else MACRO_DEFAULT_NAVIGATION_WAIT_MS).toLong(),
        ) {
            evalJs(probe) == "true"
        }
        sleep(500)
    }

    private suspend fun executeWaitForManualInput(step: WarehouseMacroStep) {
        val reason = step.value ?: MANUAL_INPUT_DEFAULT_CODE
        val shouldContinue = callbacks.onPauseForManualInput(step, reason)
        if (!shouldContinue) {
            throw IllegalStateException(CODE_USER_CANCELLED)
        }
    }

    /**
     * 反复尝试直到脚本明确回报「找到了」，预算用完才报元素不存在。
     * 导航进行中 JS 上下文会被销毁，那一拍读不到属正常——继续轮询，不当成功。
     */
    private suspend fun runElementStep(selector: String, waitMs: Int, js: String) {
        val budgetMs = (if (waitMs > 0) waitMs else defaultElementWaitMs).toLong()
        val deadlineAt = nowMs() + budgetMs
        var found = false
        while (nowMs() < deadlineAt) {
            val normalized = try {
                evalJs(js)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                null
            }
            if (warehouseMacroElementFound(normalized)) {
                found = true
                break
            }
            sleep(pollIntervalMs)
        }
        if (!found) {
            throw IllegalStateException(
                encodeMacroServiceMessage("macro_element_not_found", "selector" to selector),
            )
        }
    }

    /**
     * 等入口网页成为完整文档；超时**不报失败**（「入口页慢」和「这个站永远
     * complete 不了」在用户眼里是两回事；每步自己的 10s 元素预算仍然兜得住）。
     */
    private suspend fun waitForEntryDocumentReady(importUrl: String) {
        if (importUrl.isBlank()) return
        try {
            pollCondition(
                stepLabel = WarehouseMacroReplayStrings.macroReplayWaitPageLoad.zh,
                timeoutMs = entryReadyTimeoutMs,
            ) {
                val state = currentDocumentState()
                isWarehouseEntryDocumentReady(state?.first, state?.second)
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            // 15 秒还没 complete：交给后续步骤自己等。
        }
    }

    /**
     * 等待页面就绪：URL 非空轮询 + readyState==complete 轮询（超时也继续，
     * readyState 可能受 iframe 影响）+ 固定 800ms 渲染时间。
     */
    private suspend fun waitForPageReady(timeoutMs: Long) {
        pollCondition(
            stepLabel = WarehouseMacroReplayStrings.macroReplayWaitPageLoad.zh,
            timeoutMs = timeoutMs,
        ) {
            !currentDocumentHref().isNullOrEmpty()
        }
        try {
            pollCondition(
                stepLabel = WarehouseMacroReplayStrings.macroReplayWaitDomReady.zh,
                timeoutMs = 15000,
            ) {
                currentDocumentState()?.second == "complete"
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            // DOM readyState 超时也继续。
        }
        sleep(800)
    }

    /** 轮询直到条件满足或超时；超时抛 `macro_poll_timeout`（带步骤文案与秒数）。 */
    private suspend fun pollCondition(
        stepLabel: String,
        timeoutMs: Long,
        check: suspend () -> Boolean,
    ) {
        var lastError = ""
        val deadlineAt = nowMs() + timeoutMs
        var satisfied = false
        while (nowMs() < deadlineAt) {
            satisfied = try {
                check()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                lastError = ": ${error.message ?: error.javaClass.simpleName}"
                false
            }
            if (satisfied) return
            sleep(pollIntervalMs)
        }
        throw IllegalStateException(
            encodeMacroServiceMessage(
                "macro_poll_timeout",
                "stepLabel" to stepLabel,
                "timeoutSeconds" to (timeoutMs / 1000),
                "lastError" to lastError,
            ),
        )
    }

    /** 当前文档的 href 与 readyState；导航提交瞬间 JS 上下文不可用 → null（下一拍重试）。 */
    private suspend fun currentDocumentState(): Pair<String, String>? {
        val href = evalJs("location.href") ?: return null
        if (href.isEmpty()) return null
        return Pair(href, evalJs("document.readyState").orEmpty())
    }

    private suspend fun currentDocumentHref(): String? = currentDocumentState()?.first

    companion object {
        const val MANUAL_INPUT_DEFAULT_CODE = "macro_manual_input_default"
        const val CODE_USER_CANCELLED = "macro_user_cancelled"

        /**
         * 填充一步的脚本（Dart `_executeFillField` 的 spec 逐字）：
         * 候选选择器逐个找；已有正确值则跳过改写（避免覆盖浏览器自动填充后逐字重输）；
         * 找到后 focus + 赋值 + input/change/blur 三个事件。
         */
        fun fillElementJs(selector: String, value: String): String {
            val candidatesJson = MiniJson.encode(warehouseMacroSelectorCandidates(selector))
            val escapedValue = MiniJson.encode(value)
            val escapedSelector = MiniJson.encode(selector)
            return """
(() => {
  const sels = $candidatesJson;
  var el = null;
  for (var i = 0; i < sels.length; i++) {
    el = document.querySelector(sels[i]);
    if (el) break;
  }
  if (!el) return JSON.stringify({found: false, selector: $escapedSelector});
  if (String(el.value || '') === $escapedValue) {
    return JSON.stringify({found: true, skipped: true, tag: el.tagName, type: el.type || ''});
  }
  el.focus();
  el.value = $escapedValue;
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  el.dispatchEvent(new Event('blur', { bubbles: true }));
  return JSON.stringify({found: true, tag: el.tagName, type: el.type || ''});
})();
""".trimIndent()
        }

        /** 点击一步的脚本（Dart `_executeClick` 的 spec 逐字）。 */
        fun clickElementJs(selector: String): String {
            val candidatesJson = MiniJson.encode(warehouseMacroSelectorCandidates(selector))
            val escapedSelector = MiniJson.encode(selector)
            return """
(() => {
  const sels = $candidatesJson;
  var el = null;
  for (var i = 0; i < sels.length; i++) {
    el = document.querySelector(sels[i]);
    if (el) break;
  }
  if (!el) return JSON.stringify({found: false, selector: $escapedSelector});
  if (typeof el.click === 'function') {
    el.click();
  } else {
    var evt = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
    el.dispatchEvent(evt);
  }
  return JSON.stringify({found: true, tag: el.tagName});
})();
""".trimIndent()
        }
    }
}

/** 回放步骤状态（Dart `ReplayStepStatus`）。 */
enum class ReplayStepStatus { PENDING, RUNNING, SUCCEEDED, FAILED, PAUSED_FOR_INPUT }

/** 回放进度快照（Dart `ReplayProgress`）。 */
data class WarehouseReplayProgress(
    val currentStepIndex: Int,
    val totalSteps: Int,
    val currentStep: WarehouseMacroStep,
    val status: ReplayStepStatus,
    val errorMessage: String? = null,
    val pauseReason: String? = null,
) {
    /** 0..1 进度（totalSteps 为 0 时回 0，避免除零）。 */
    val progressFraction: Float
        get() = if (totalSteps > 0) (currentStepIndex + 1).toFloat() / totalSteps else 0f

    /** 「正在……」行文案（失败/暂停带本地化原因）。 */
    val statusLabel: String
        get() = when (status) {
            ReplayStepStatus.RUNNING -> MacroReplayText.stepLabel(currentStep.type)
            ReplayStepStatus.FAILED ->
                WarehouseMacroReplayStrings.macroReplayStatusFailed
                    .filled("error" to WarehouseMacroReplayStrings.localize(errorMessage))
            ReplayStepStatus.PAUSED_FOR_INPUT ->
                WarehouseMacroReplayStrings.macroReplayStatusPaused
                    .filled("reason" to WarehouseMacroReplayStrings.localize(pauseReason))
            ReplayStepStatus.PENDING, ReplayStepStatus.SUCCEEDED -> ""
        }
}

/** 回放覆盖层五态（Dart `PlaybackUiState`；hidden 由宿主用空进度表达）。 */
enum class WarehousePlaybackUiState {
    PLAYING,
    PAUSED_FOR_INPUT,
    EXECUTING_IMPORT,
    FINISHED,
    ERROR,
}
