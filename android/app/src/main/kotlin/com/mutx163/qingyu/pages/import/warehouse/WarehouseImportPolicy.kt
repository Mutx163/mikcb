package com.mutx163.qingyu.pages.import.warehouse

/**
 * 仓库记住登录账号密码。
 */
data class WarehouseRememberedLogin(
    val username: String = "",
    val password: String = "",
)

/**
 * 教务会话探测裁决。
 */
enum class WarehouseSessionProbeVerdict {
    UNKNOWN,
    ACTIVE,
    INACTIVE,
    TIMEOUT;
}

/**
 * 教务会话探测配置。
 */
data class WarehouseSessionProbeConfig(
    val url: String = "",
    val method: String = "GET",
    val headers: Map<String, String> = emptyMap(),
)

/**
 * 路由反向退场时动画状态。
 */
enum class WarehouseAnimationStatus {
    DISMISSED,
    FORWARD,
    REVERSE,
    COMPLETED;
}

/**
 * 是否应弹「要不要帮你填密码」。
 */
fun shouldPromptRememberedLoginAutofill(
    hasPasswordField: Boolean,
    rememberedLogin: WarehouseRememberedLogin?,
    candidate: WarehouseRememberedLogin,
    hasPromptedAutofill: Boolean,
    isPromptShowing: Boolean,
    sessionActive: Boolean = false,
): Boolean {
    return hasPasswordField &&
            !sessionActive &&
            rememberedLogin != null &&
            rememberedLogin.password.isNotEmpty() &&
            candidate.password.isEmpty() &&
            !hasPromptedAutofill &&
            !isPromptShowing
}

/**
 * 登录尝试后是否应弹「记住密码？」。
 */
fun shouldPromptRememberedLoginSave(
    rememberedLogin: WarehouseRememberedLogin?,
    hasPromptedSave: Boolean,
    isPromptShowing: Boolean,
    candidateUsername: String,
    candidatePassword: String,
): Boolean {
    return !hasPromptedSave &&
            !isPromptShowing &&
            candidateUsername.isNotEmpty() &&
            candidatePassword.isNotEmpty() &&
            (rememberedLogin == null || rememberedLogin.password.isEmpty())
}

/**
 * 「要不要帮你填密码」的决定是否应该等在途的会话探针。
 */
fun sessionProbeMayStillSettle(
    config: WarehouseSessionProbeConfig?,
    verdict: WarehouseSessionProbeVerdict,
    inFlight: Boolean,
): Boolean {
    return config != null &&
            verdict == WarehouseSessionProbeVerdict.UNKNOWN &&
            inFlight
}

/**
 * 是否自动开启后台路径录制。
 */
fun shouldAutoRecordWarehouseImport(
    forceRecord: Boolean,
    hasExistingMacro: Boolean,
): Boolean {
    return forceRecord || !hasExistingMacro
}

/**
 * 返回摘除阈值：路由主动画反向走到这个值以下时，把 WebView 的平台视图摘出树。
 */
const val PLATFORM_VIEW_EXIT_DETACH_THRESHOLD: Double = 0.35

/**
 * 是否到了“把网页平台视图摘出树”的时机。
 */
fun shouldDetachPlatformViewOnExit(
    status: WarehouseAnimationStatus,
    value: Double,
): Boolean {
    return status == WarehouseAnimationStatus.REVERSE &&
            value <= PLATFORM_VIEW_EXIT_DETACH_THRESHOLD
}
