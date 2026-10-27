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
) {
    /** 是否应该触发自动填入提示 */
    val shouldPromptAutofill: Boolean
        get() = shouldPromptRememberedLoginAutofill(
            hasPasswordField = true,
            rememberedLogin = rememberedAccount,
            candidate = candidateAccount,
            hasPromptedAutofill = hasPromptedAutofill,
            isPromptShowing = isAutofillPromptShowing,
            sessionActive = sessionActive,
        )

    /** 是否应该触发保存凭据提示 */
    val shouldPromptSave: Boolean
        get() = shouldPromptRememberedLoginSave(
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
