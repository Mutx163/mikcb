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
 * 换页后的候选账号取舍：**已提交登录、还没回答「记住密码」时，不许被空口令冲掉**。
 *
 * 为什么需要这条：点「登录」会触发表单提交 ⇒ 页面跳转，新文档装好观察脚本就立刻
 * `collect()` 一次。新页面（课表页 / 个人中心）通常没有密码框，回传的是
 * 「username = 页面上第一个文本框（往往是搜索框），password = ""」。照单全收会把
 * 刚采集到的「账号 + 口令」冲成空口令，[shouldPromptRememberedLoginSave] 立刻变假，
 * 「记住密码」卡片闪一下就消失——真机表现就是「第一次输密码不弹记住密码」。
 *
 * 发布版不受影响：它在 `_handleLoginAttempt` 里**当场弹模态框**，之后新页面再回传
 * 什么都影响不到已经弹出的框。卡片式提示要活到用户作答，所以在这里把「已提交、
 * 未作答」的候选钉住；作答后（`hasPromptedSave = true`）恢复跟随页面输入，
 * 下一次登录仍能采集新值。
 *
 * 另一条：**同一份账号口令已经在登录页绑过 host 时，不再改绑**。
 * `handleLoginState` 取的是消息处理时的地址，若 `onPageStarted` 先到，拿到的已经
 * 是落地页 host；统一认证 `cas.x` → `jw.x` 时会把口令绑到错误站点，下一次在真登录页
 * 的自动填充会被门禁永久拒掉（用户看到的是「记住了但没用」）。口令没变 ⇒ 沿用第一次
 * 观察到的 host；用户重输了新口令才允许重新绑定。
 *
 * @param previous 当前内存里的候选（可能还留着提交时采集的账号口令）。
 * @param incoming 新页面刚回传的候选。
 */
fun warehouseLoginCandidateAfterState(
    previous: WarehouseRememberedLogin,
    incoming: WarehouseRememberedLogin,
    hasLoginAttempt: Boolean,
    hasPromptedSave: Boolean,
): WarehouseRememberedLogin {
    val keepSubmitted = hasLoginAttempt &&
        !hasPromptedSave &&
        previous.password.isNotEmpty() &&
        incoming.password.isEmpty()
    if (keepSubmitted) return previous
    val sameCredential = incoming.username == previous.username &&
        incoming.password == previous.password &&
        incoming.password.isNotEmpty() &&
        previous.host.isNotEmpty()
    return if (sameCredential) incoming.copy(host = previous.host) else incoming
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
