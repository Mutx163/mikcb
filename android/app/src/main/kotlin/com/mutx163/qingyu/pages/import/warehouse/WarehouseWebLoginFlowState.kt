package com.mutx163.qingyu.pages.import.warehouse

import java.net.URI

/**
 * 校验并解析教务导入地址：用户自定义覆盖地址优先，空或格式非法退回默认地址。
 */
fun resolveWarehouseImportUrl(
    customImportUrl: String?,
    defaultUrl: String,
): String? {
    val custom = customImportUrl?.trim()
    if (!custom.isNullOrEmpty()) {
        val uri = runCatching { URI(custom) }.getOrNull()
        if (uri != null && (uri.scheme == "http" || uri.scheme == "https")) {
            return custom
        }
    }
    val fallback = defaultUrl.trim()
    if (fallback.isNotEmpty()) {
        val uri = runCatching { URI(fallback) }.getOrNull()
        if (uri != null && (uri.scheme == "http" || uri.scheme == "https")) {
            return fallback
        }
    }
    return null
}

/**
 * 网页登录执行阶段。
 */
enum class WarehouseWebLoginStage {
    IDLE,
    LOADING,
    LOADED,
    INJECTING_SCRIPT,
    EXECUTING,
    SUCCESS,
    ERROR;
}

/**
 * 宏录制动作状态。
 */
enum class WarehouseMacroActionState {
    IDLE,
    RECORDING,
    STOPPED,
    PLAYING;
}

/**
 * 网页登录会话完整状态模型。
 */
data class WarehouseWebLoginSessionState(
    val currentUrl: String = "",
    val stage: WarehouseWebLoginStage = WarehouseWebLoginStage.IDLE,
    val macroState: WarehouseMacroActionState = WarehouseMacroActionState.IDLE,
    val recordedStepsCount: Int = 0,
    val isDesktopMode: Boolean = false,
    val canGoBack: Boolean = false,
    val canGoForward: Boolean = false,
    val errorMessage: String? = null,
    val rememberedAccount: WarehouseRememberedLogin? = null,
    val candidateAccount: WarehouseRememberedLogin = WarehouseRememberedLogin(),
    val hasPromptedAutofill: Boolean = false,
    val isAutofillPromptShowing: Boolean = false,
    val hasPromptedSave: Boolean = false,
    val isSavePromptShowing: Boolean = false,
    val sessionActive: Boolean = false,
    /**
     * 页面当前**真有**密码框（观察脚本 `loginState` 上报）。
     *
     * 以前这里是写死的 `true`：任何页面都会被问「要不要帮你填密码」，
     * 连没有登录框的课表页也问。默认 `false` = 没确认过就不打扰。
     */
    val hasPasswordField: Boolean = false,
    /**
     * 当前页**允许**自动填充（凭据绑定站点门禁的结果，由宿主算好传进来）。
     *
     * 门禁见 [rememberedLoginAllowsUrl]：跨站页面不提示、更不回填——否则钓鱼页
     * 只要长得像登录页就能把真口令骗走。默认 `false` = 宿主确认之前不放行。
     */
    val autofillHostAllowed: Boolean = false,
    /**
     * 页面发生过一次登录尝试（`submit` / 点「登录」）。
     *
     * 「记住密码」只在用户**真的试过登录**之后问，否则一边敲一边弹「记住密码」很烦。
     */
    val hasLoginAttempt: Boolean = false,
) {
    /** 是否应该触发自动填入提示 */
    val shouldPromptAutofill: Boolean
        get() = autofillHostAllowed && shouldPromptRememberedLoginAutofill(
            hasPasswordField = hasPasswordField,
            rememberedLogin = rememberedAccount,
            candidate = candidateAccount,
            hasPromptedAutofill = hasPromptedAutofill,
            isPromptShowing = isAutofillPromptShowing,
            sessionActive = sessionActive,
        )

    /** 是否应该触发保存凭据提示 */
    val shouldPromptSave: Boolean
        get() = hasLoginAttempt && shouldPromptRememberedLoginSave(
            rememberedLogin = rememberedAccount,
            hasPromptedSave = hasPromptedSave,
            isPromptShowing = isSavePromptShowing,
            candidateUsername = candidateAccount.username,
            candidatePassword = candidateAccount.password,
        )

    fun withStepRecorded(): WarehouseWebLoginSessionState {
        return copy(
            recordedStepsCount = recordedStepsCount + 1,
            macroState = WarehouseMacroActionState.RECORDING,
        )
    }

    fun withStage(newStage: WarehouseWebLoginStage, error: String? = null): WarehouseWebLoginSessionState {
        return copy(stage = newStage, errorMessage = error)
    }
}
