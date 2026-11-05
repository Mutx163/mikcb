package com.mutx163.qingyu.pages.import.warehouse

/**
 * 仓库记住登录账号密码。
 *
 * @param host 保存时绑定的教务站点 host（小写）。自动填充只允许发生在同一 host
 *   （见 [rememberedLoginAllowsUrl]）；旧版本数据没有这个字段（空串），
 *   按「只放行受信登录地址」处理，下次保存时补绑。
 */
data class WarehouseRememberedLogin(
    val username: String = "",
    val password: String = "",
    val host: String = "",
)

/**
 * 自动填充门禁（凭据绑定站点）：**只允许把记住的口令填回它来源的那个站**。
 *
 * 逐字对齐 Dart `warehouse_import_preferences_service.dart` 的 `rememberedLoginAllowsUrl`：
 * - 凭据已绑定 host ⇒ 当前页必须落在该 host（或它的子域，教务站常跨 `jw.x.edu` / `a.jw.x.edu`）；
 * - 凭据没绑 host（老数据）⇒ 只放行调用方给的受信 host（适配器登记地址 / 受信自定义地址），
 *   **不是**「哪儿都放行」——否则门禁对老用户等于没开。
 *
 * 为什么必须门禁：钓鱼页只要长得像登录页，就会因为「已记住账号」而被自动填入真口令，
 * 等于把密码直接送给攻击者。当前页 url 解析不出 host 一律拒绝（门禁只会更严）。
 */
fun rememberedLoginAllowsUrl(
    rememberedLogin: WarehouseRememberedLogin?,
    currentUrl: String?,
    trustedHosts: Iterable<String> = emptyList(),
): Boolean {
    if (rememberedLogin == null) return false
    val bound = rememberedLogin.host.trim().lowercase()
    if (bound.isNotEmpty()) {
        return warehouseUrlOnTrustedHosts(currentUrl, listOf(bound))
    }
    return warehouseUrlOnTrustedHosts(currentUrl, trustedHosts)
}

/**
 * 页面自报的登录框快照（宿主注入的观察脚本经桥回传 `loginState`）。
 *
 * @param hasPasswordField 页面当前有没有可用的密码框——没有就不该问「要不要帮你填密码」。
 */
data class WarehouseLoginFieldSnapshot(
    val username: String = "",
    val password: String = "",
    val hasPasswordField: Boolean = false,
)

/**
 * 解析 `loginState` 消息；形状不对回 `null`（坏载荷不该污染候选账号）。
 *
 * 注意：这里拿到的是**用户自己在页面上敲的内容**，只用于「记不记住」的判定，
 * 不落盘、不进日志（正文里有口令）。
 */
fun warehouseLoginStateSnapshot(raw: String?): WarehouseLoginFieldSnapshot? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = com.mutx163.qingyu.core.MiniJson.tryParse(text) as? Map<*, *> ?: return null
    if (parsed["type"] != "loginState") return null
    return WarehouseLoginFieldSnapshot(
        username = (parsed["username"] as? String)?.trim().orEmpty(),
        password = (parsed["password"] as? String).orEmpty(),
        hasPasswordField = parsed["hasPasswordField"] == true,
    )
}

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
