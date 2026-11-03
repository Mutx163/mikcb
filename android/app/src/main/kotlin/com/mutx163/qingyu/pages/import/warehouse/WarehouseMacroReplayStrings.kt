package com.mutx163.qingyu.pages.import.warehouse

/**
 * 宏回放域文案（P2）：`macroReplay*` 与快捷导入过程键的 Kotlin 镜像 + 失败码
 * `serviceMsgMacro*` 的本地化（Dart `service_message_localizer.dart` 宏族在
 * Kotlin 侧的落点）。
 *
 * ## 为什么不放进 `WarehouseStrings.kt`
 *
 * 那个文件当时是并行会话的在途改动（MM）；宏回放域的镜像独立成文件，
 * 文件名含 `Strings`（i18n 棘轮豁免口径），与 ARB 的对拍由
 * [WarehouseMacroReplayStringsParityTest] 机械钉住。等 `WarehouseStrings.kt`
 * 落定后可再合并（并入时同步迁移对拍）。
 *
 * ## 文案与 ARB 逐字对齐
 *
 * 每条都是 `lib/l10n/app_zh.arb` 已有键的**逐字抄录**，零新增（硬要求 6）。
 * 失败码就是 Dart `encodeServiceMessage(code, args)` 的 `code|k=v` 形态：
 * 回放引擎抛的每个码都在 [localize] 里有一句人话，认不出的码**原样返回**，
 * 不猜语义（与 `TimeSchemeServiceMessages` 同一口径）。
 */
object WarehouseMacroReplayStrings {

    // ── 回放过程（macroReplay*，app_zh.arb:4559-4610）──
    val macroReplayStatusFailed = MacroReplayText("macroReplayStatusFailed", "失败：{error}")
    val macroReplayStatusPaused = MacroReplayText("macroReplayStatusPaused", "等待手动操作：{reason}")
    val macroReplayStepNavigating = MacroReplayText("macroReplayStepNavigating", "正在导航……")
    val macroReplayStepFilling = MacroReplayText("macroReplayStepFilling", "正在填充表单……")
    val macroReplayStepClicking = MacroReplayText("macroReplayStepClicking", "正在点击……")
    val macroReplayStepWaitUrl = MacroReplayText("macroReplayStepWaitUrl", "等待页面跳转……")
    val macroReplayStepWaitSelector = MacroReplayText("macroReplayStepWaitSelector", "等待页面元素……")
    val macroReplayStepWaitManual = MacroReplayText("macroReplayStepWaitManual", "等待用户操作")
    val macroReplayStepExecuteScript = MacroReplayText("macroReplayStepExecuteScript", "正在执行导入脚本……")
    val macroReplayStepDelay = MacroReplayText("macroReplayStepDelay", "等待中……")
    val macroReplayAcceleratedFallbackTip = MacroReplayText(
        "macroReplayAcceleratedFallbackTip",
        "快捷路径失败，正在使用完整录制步骤重试……",
    )
    val macroReplayWaitUrlPattern = MacroReplayText("macroReplayWaitUrlPattern", "等待 URL 匹配：{pattern}")
    val macroReplayWaitSelector = MacroReplayText("macroReplayWaitSelector", "等待元素：{selector}")
    val macroReplayManualActionRequired = MacroReplayText("macroReplayManualActionRequired", "需要手动操作")
    val macroReplayNavigateTo = MacroReplayText("macroReplayNavigateTo", "导航到 {url}")
    val macroReplayWaitPageLoad = MacroReplayText("macroReplayWaitPageLoad", "等待页面加载")
    val macroReplayWaitDomReady = MacroReplayText("macroReplayWaitDomReady", "等待 DOM 就绪")

    // ── 快捷导入过程（quickImport*，app_zh.arb:2306-2333；其余在 WarehouseStrings）──
    val quickImportPlayingTitle = MacroReplayText("quickImportPlayingTitle", "自动导入中……")
    val quickImportExecutingScriptTitle = MacroReplayText(
        "quickImportExecutingScriptTitle",
        "回放完成，正在执行导入脚本……",
    )
    val quickImportManualInputTitle = MacroReplayText("quickImportManualInputTitle", "需要手动操作")
    val quickImportManualInputHint = MacroReplayText(
        "quickImportManualInputHint",
        "请完成当前需要的手动操作，完成后点击继续",
    )
    val quickImportCancelImportAction = MacroReplayText("quickImportCancelImportAction", "取消导入")
    val quickImportContinueAction = MacroReplayText("quickImportContinueAction", "继续")
    val quickImportRetryAction = MacroReplayText("quickImportRetryAction", "重试")
    val quickImportPlaybackStepProgress = MacroReplayText(
        "quickImportPlaybackStepProgress",
        "步骤 {current} / {total}",
    )
    val quickImportCancelPlaybackAction = MacroReplayText("quickImportCancelPlaybackAction", "取消")
    val quickImportUnknownError = MacroReplayText("quickImportUnknownError", "发生未知错误")
    val closeAction = MacroReplayText("closeAction", "关闭")

    val allTexts: List<MacroReplayText> by lazy {
        listOf(
            macroReplayStatusFailed,
            macroReplayStatusPaused,
            macroReplayStepNavigating,
            macroReplayStepFilling,
            macroReplayStepClicking,
            macroReplayStepWaitUrl,
            macroReplayStepWaitSelector,
            macroReplayStepWaitManual,
            macroReplayStepExecuteScript,
            macroReplayStepDelay,
            macroReplayAcceleratedFallbackTip,
            macroReplayWaitUrlPattern,
            macroReplayWaitSelector,
            macroReplayManualActionRequired,
            macroReplayNavigateTo,
            macroReplayWaitPageLoad,
            macroReplayWaitDomReady,
            quickImportPlayingTitle,
            quickImportExecutingScriptTitle,
            quickImportManualInputTitle,
            quickImportManualInputHint,
            quickImportCancelImportAction,
            quickImportContinueAction,
            quickImportRetryAction,
            quickImportPlaybackStepProgress,
            quickImportCancelPlaybackAction,
            quickImportUnknownError,
            closeAction,
        )
    }

    // ── 失败码 → 人话（serviceMsgMacro*，app_zh.arb:4283-4356）──

    val serviceMsgManualInputCaptcha = MacroReplayText(
        "serviceMsgManualInputCaptcha",
        "请手动输入验证码；完成后点击继续",
    )
    val serviceMsgManualInputPassword = MacroReplayText(
        "serviceMsgManualInputPassword",
        "请手动输入密码；如已自动填充请直接继续",
    )
    val serviceMsgMacroNoSteps = MacroReplayText("serviceMsgMacroNoSteps", "没有录制的步骤")
    val serviceMsgMacroUserCancelled = MacroReplayText("serviceMsgMacroUserCancelled", "用户取消")
    val serviceMsgMacroStepFailed = MacroReplayText(
        "serviceMsgMacroStepFailed",
        "第 {stepIndex}/{totalSteps} 步失败：{detail}",
    )
    val serviceMsgMacroNavigateUrlEmpty = MacroReplayText("serviceMsgMacroNavigateUrlEmpty", "导航 URL 为空")
    val serviceMsgMacroNavigateUrlInvalid = MacroReplayText(
        "serviceMsgMacroNavigateUrlInvalid",
        "无效的 URL: {url}",
    )
    val serviceMsgMacroFillSelectorEmpty = MacroReplayText(
        "serviceMsgMacroFillSelectorEmpty",
        "填充字段的选择器为空",
    )
    val serviceMsgMacroElementNotFound = MacroReplayText(
        "serviceMsgMacroElementNotFound",
        "未找到元素：{selector}",
    )
    val serviceMsgMacroClickSelectorEmpty = MacroReplayText(
        "serviceMsgMacroClickSelectorEmpty",
        "点击元素的选择器为空",
    )
    val serviceMsgMacroUrlPatternEmpty = MacroReplayText("serviceMsgMacroUrlPatternEmpty", "URL 模式为空")
    val serviceMsgMacroWaitSelectorEmpty = MacroReplayText(
        "serviceMsgMacroWaitSelectorEmpty",
        "等待元素的选择器为空",
    )
    val serviceMsgMacroManualInputDefault = MacroReplayText(
        "serviceMsgMacroManualInputDefault",
        "需要手动操作",
    )
    val serviceMsgMacroPollTimeout = MacroReplayText(
        "serviceMsgMacroPollTimeout",
        "{stepLabel} 超时 {timeoutSeconds} 秒 {lastError}",
    )
    val serviceMsgMacroReplayNavigate = MacroReplayText("serviceMsgMacroReplayNavigate", "正在导航……")
    val serviceMsgMacroReplayFillField = MacroReplayText("serviceMsgMacroReplayFillField", "正在填充表单……")
    val serviceMsgMacroReplayClick = MacroReplayText("serviceMsgMacroReplayClick", "正在点击……")
    val serviceMsgMacroReplayWaitUrl = MacroReplayText("serviceMsgMacroReplayWaitUrl", "等待页面跳转……")
    val serviceMsgMacroReplayWaitSelector = MacroReplayText("serviceMsgMacroReplayWaitSelector", "等待页面元素……")
    val serviceMsgMacroReplayWaitManual = MacroReplayText("serviceMsgMacroReplayWaitManual", "等待用户操作")
    val serviceMsgMacroReplayExecuteScript = MacroReplayText(
        "serviceMsgMacroReplayExecuteScript",
        "正在执行导入脚本……",
    )
    val serviceMsgMacroReplayDelay = MacroReplayText("serviceMsgMacroReplayDelay", "等待中……")
    val serviceMsgMacroReplayFailed = MacroReplayText("serviceMsgMacroReplayFailed", "失败：{detail}")
    val serviceMsgMacroReplayPaused = MacroReplayText("serviceMsgMacroReplayPaused", "等待手动操作：{reason}")

    /**
     * 本地化一条宏回放失败码（`code` 或 `code|k=v`）。
     *
     * - 参数缺失：数字补 0、字符串补空串（与 Dart `_intArg ?? 0` 一致）；
     * - `macro_step_failed` 的 `detail` **递归本地化**（它可能是另一条码，
     *   如 `macro_element_not_found|selector=#Form1`——直接插码会把
     *   ASCII 码摆到用户面前）；
     * - 认不出的码**原样返回入参**，不猜。
     */
    fun localize(payload: String?): String {
        if (payload.isNullOrEmpty()) return ""
        val parts = payload.split("|")
        val code = parts.first()
        val args = LinkedHashMap<String, String>()
        for (part in parts.drop(1)) {
            val eq = part.indexOf('=')
            if (eq <= 0) continue
            args[part.substring(0, eq)] = part.substring(eq + 1)
        }
        return localizeCode(code, args) ?: payload
    }

    private fun localizeCode(code: String, args: Map<String, String>): String? = when (code) {
        "manual_input_captcha" -> serviceMsgManualInputCaptcha.zh
        "manual_input_password" -> serviceMsgManualInputPassword.zh
        "macro_no_steps" -> serviceMsgMacroNoSteps.zh
        "macro_user_cancelled" -> serviceMsgMacroUserCancelled.zh
        "macro_step_failed" -> serviceMsgMacroStepFailed.filled(
            "stepIndex" to numberArg(args, "stepIndex"),
            "totalSteps" to numberArg(args, "totalSteps"),
            // detail 可能是另一条码：递归到人话（认不出原样保留）。
            "detail" to localize(args["detail"]),
        )

        "macro_navigate_url_empty" -> serviceMsgMacroNavigateUrlEmpty.zh
        "macro_navigate_url_invalid" -> serviceMsgMacroNavigateUrlInvalid.filled(
            "url" to args["url"].orEmpty(),
        )
        "macro_fill_selector_empty" -> serviceMsgMacroFillSelectorEmpty.zh
        "macro_element_not_found" -> serviceMsgMacroElementNotFound.filled(
            "selector" to args["selector"].orEmpty(),
        )
        "macro_click_selector_empty" -> serviceMsgMacroClickSelectorEmpty.zh
        "macro_url_pattern_empty" -> serviceMsgMacroUrlPatternEmpty.zh
        "macro_wait_selector_empty" -> serviceMsgMacroWaitSelectorEmpty.zh
        "macro_manual_input_default" -> serviceMsgMacroManualInputDefault.zh
        "macro_poll_timeout" -> serviceMsgMacroPollTimeout.filled(
            "stepLabel" to args["stepLabel"].orEmpty(),
            "timeoutSeconds" to numberArg(args, "timeoutSeconds"),
            "lastError" to args["lastError"].orEmpty(),
        )

        "macro_replay_navigate" -> serviceMsgMacroReplayNavigate.zh
        "macro_replay_fill_field" -> serviceMsgMacroReplayFillField.zh
        "macro_replay_click" -> serviceMsgMacroReplayClick.zh
        "macro_replay_wait_url" -> serviceMsgMacroReplayWaitUrl.zh
        "macro_replay_wait_selector" -> serviceMsgMacroReplayWaitSelector.zh
        "macro_replay_wait_manual" -> serviceMsgMacroReplayWaitManual.zh
        "macro_replay_execute_script" -> serviceMsgMacroReplayExecuteScript.zh
        "macro_replay_delay" -> serviceMsgMacroReplayDelay.zh
        "macro_replay_failed" -> serviceMsgMacroReplayFailed.filled(
            "detail" to localize(args["detail"]),
        )
        "macro_replay_paused" -> serviceMsgMacroReplayPaused.filled(
            "reason" to localize(args["reason"]),
        )

        else -> null
    }

    private fun numberArg(args: Map<String, String>, key: String): String =
        (args[key]?.toIntOrNull() ?: 0).toString()
}

/** 宏回放域文案条目（与 [WarehouseArbText] 同形，独立成类避免跨文件混淆对拍集合）。 */
data class MacroReplayText(val key: String, val zh: String) {
    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }

    companion object {
        /** 步骤类型 → 过程文案（回放覆盖层「正在……」行）。 */
        fun stepLabel(type: WarehouseMacroStepType): String = when (type) {
            WarehouseMacroStepType.NAVIGATE -> WarehouseMacroReplayStrings.macroReplayStepNavigating.zh
            WarehouseMacroStepType.FILL_FIELD -> WarehouseMacroReplayStrings.macroReplayStepFilling.zh
            WarehouseMacroStepType.CLICK -> WarehouseMacroReplayStrings.macroReplayStepClicking.zh
            WarehouseMacroStepType.WAIT_FOR_URL -> WarehouseMacroReplayStrings.macroReplayStepWaitUrl.zh
            WarehouseMacroStepType.WAIT_FOR_SELECTOR -> WarehouseMacroReplayStrings.macroReplayStepWaitSelector.zh
            WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT -> WarehouseMacroReplayStrings.macroReplayStepWaitManual.zh
            WarehouseMacroStepType.EXECUTE_SCRIPT -> WarehouseMacroReplayStrings.macroReplayStepExecuteScript.zh
            WarehouseMacroStepType.DELAY -> WarehouseMacroReplayStrings.macroReplayStepDelay.zh
        }
    }
}

/**
 * 编一条 `code|k=v` 服务消息（Dart `encodeServiceMessage` 的等价物）。
 * 值原样放（本域的值都是码/选择器/数字，不含 `|` 与 `=`）。
 */
fun encodeMacroServiceMessage(code: String, vararg args: Pair<String, Any>): String =
    if (args.isEmpty()) {
        code
    } else {
        code + args.joinToString("|", prefix = "|") { (key, value) -> "$key=$value" }
    }

/**
 * 从「宏步骤失败」的原始负载里取结构化字段（覆盖层「第几步/共几步/卡在哪」用）。
 * 解析不出（非 `macro_step_failed` 形态）返回 null，调用方退回原始文本展示。
 */
fun parseMacroStepFailed(payload: String?): MacroStepFailedInfo? {
    if (payload.isNullOrEmpty()) return null
    val parts = payload.split("|")
    if (parts.first() != "macro_step_failed") return null
    val args = LinkedHashMap<String, String>()
    for (part in parts.drop(1)) {
        val eq = part.indexOf('=')
        if (eq <= 0) continue
        args[part.substring(0, eq)] = part.substring(eq + 1)
    }
    return MacroStepFailedInfo(
        stepIndex = args["stepIndex"]?.toIntOrNull() ?: 0,
        totalSteps = args["totalSteps"]?.toIntOrNull() ?: 0,
        detail = args["detail"].orEmpty(),
    )
}

/** `macro_step_failed` 的结构化字段：第几步 / 共几步 / 卡在哪（detail 已是码或原文）。 */
data class MacroStepFailedInfo(
    val stepIndex: Int,
    val totalSteps: Int,
    val detail: String,
) {
    /**
     * 「元素没找到」时的选择器（覆盖层把「卡在哪」落到具体元素）。
     * detail 是 `macro_element_not_found|selector=x` 形态；别的码返回 null。
     */
    val missingSelector: String?
        get() {
            if (detail.split("|").firstOrNull() != "macro_element_not_found") return null
            for (part in detail.split("|").drop(1)) {
                val eq = part.indexOf('=')
                if (eq > 0 && part.substring(0, eq) == "selector") {
                    return part.substring(eq + 1)
                }
            }
            return null
        }
}
