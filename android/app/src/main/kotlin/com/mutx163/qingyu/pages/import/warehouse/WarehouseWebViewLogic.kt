package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * 教务网页登录 WebView 的**纯逻辑层**（能力缺口 B3，P3-G2 域）。
 *
 * 本文件**只允许纯 JVM 代码**：不得 import `android.*` / `androidx.compose.*` / miuix，
 * 否则 `scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"`（L0）编不过。
 * 渲染层宿主在同包的 `composeP1/.../WarehouseWebViewHost.kt`，它把这些函数接到
 * 平台 `android.webkit.WebView` 上。
 *
 * 参照物（只读，不许改）：`lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart`
 * 与 `lib/domain/warehouse_bridge_gate.dart`。凡标「逐字对齐 Dart」的地方都有测试钉住，
 * 并尽量从 Dart 源文件里**机械读出来对拍**（见 `WarehouseWebViewLogicTest`）。
 */

// ---------------------------------------------------------------------------
// 1. User-Agent 选择
// ---------------------------------------------------------------------------

/**
 * 桌面 / 移动两套 UA，**逐字对齐 Dart**
 * `warehouse_adapter_web_login_screen.dart:107-112` 的 `_desktopUserAgent` / `_mobileUserAgent`。
 *
 * 为什么必须是同一串：教务站（强智一类）按 UA 决定回哪个登录页；UA 一变，
 * 「桌面版/移动版」这个开关就不再复刻老版行为，L4 逐页对照也无从比对。
 */
object WarehouseWebViewUserAgents {
    const val DESKTOP: String =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    const val MOBILE: String =
        "Mozilla/5.0 (Linux; Android 14; 25060RK16C) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

    /** 按模式取 UA；`desktopMode == true` 时返回 [DESKTOP]。 */
    fun forDesktopMode(desktopMode: Boolean): String = if (desktopMode) DESKTOP else MOBILE
}

/**
 * 桌面/移动切换的**另一半**：浏览器的「桌面版网站」不只换 UA，还会把布局视口强制
 * 拉宽、让页面自己的 viewport meta 失效，页面才按桌面版重排。平台 WebView 换 UA
 * 不改布局视口，两种模式渲染会一模一样，所以要注入这段 JS 复刻（配合
 * `WebSettings.useWideViewPort = true` 才生效）。
 *
 * 逐字对齐 Dart `_applyViewportOverrideJs`（`warehouse_adapter_web_login_screen.dart:1097-1130`）：
 * 桌面强制 `width=1024`（略宽于 Chrome 的 980，避免强智这类固定 1000px 模板出现横向滚动），
 * 移动恢复页面原始 meta（没有则回退 `width=device-width, initial-scale=1`）。
 * 原始 meta 存在 `window.__qingyuOriginalViewport`，同一次加载里重复注入不会把
 * 「原始值」覆盖成上一次改写后的值。
 */
fun warehouseViewportOverrideScript(desktopMode: Boolean): String = """
(() => {
  const KEY = '__qingyuOriginalViewport';
  let meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.setAttribute('name', 'viewport');
    (document.head || document.documentElement).appendChild(meta);
  }
  if (window[KEY] === undefined) {
    window[KEY] = meta.getAttribute('content');
  }
  const content = $desktopMode
      ? 'width=1024'
      : (window[KEY] || 'width=device-width, initial-scale=1');
  if (meta.getAttribute('content') !== content) {
    meta.setAttribute('content', content);
  }
})();
""".trimIndent()

// ---------------------------------------------------------------------------
// 2. 主框架导航白名单（安全门禁）
// ---------------------------------------------------------------------------

/**
 * 取出 URL 的 scheme（小写）；取不到返回空串。
 *
 * 不用 `java.net.URI`：它对非 ASCII 主机名（`http://例.com`）直接抛
 * `URISyntaxException`，而 Dart 的 `Uri.parse` 收得下——用 URI 会把合法中文域名
 * 判成「没有 scheme」而被白名单拦掉，行为与 Dart 不一致。
 */
fun warehouseUrlScheme(url: String?): String {
    val text = url?.trim().orEmpty()
    val colon = text.indexOf(':')
    if (colon <= 0) return ""
    val scheme = text.substring(0, colon)
    val first = scheme.first()
    if (!(first in 'a'..'z' || first in 'A'..'Z')) return ""
    for (ch in scheme) {
        val ok = ch in 'a'..'z' || ch in 'A'..'Z' || ch in '0'..'9' || ch == '+' || ch == '-' || ch == '.'
        if (!ok) return ""
    }
    return scheme.lowercase()
}

/**
 * 主框架导航的 scheme 白名单：**逐字对齐 Dart**
 * `lib/domain/warehouse_bridge_gate.dart` 的 `warehouseAllowsMainFrameNavigation`。
 *
 * 只放行 `http` / `https`（教务站大量明文 http，NSC 已放行）与 `about:`；
 * `intent:` / `file:` / `javascript:` / `data:` 等一律拒绝——老版 Flutter 侧
 * 最初没有 `onNavigationRequest`，任意 scheme 都能导航，是一次真实的安全收紧，
 * Compose 侧接线时不能把它丢掉。子框架导航不经过此判据（平台 WebView 的
 * `shouldOverrideUrlLoading` 同样只对主框架调用）。
 */
fun warehouseAllowsMainFrameNavigation(url: String?): Boolean {
    return when (warehouseUrlScheme(url)) {
        "http", "https", "about" -> true
        else -> false
    }
}

// ---------------------------------------------------------------------------
// 3. WebView 错误码 → 文案分类
// ---------------------------------------------------------------------------

/**
 * `android.webkit.WebViewClient.ERROR_*` 的数值镜像。
 *
 * 纯逻辑层不能 import `android.webkit.*`（L0 编不过），所以在这里复刻一份；
 * 数值取自 `android-37.2/android.jar` 的 `javap -constants`（见测试注释）。
 * 渲染层只把平台的 `error.errorCode` 原样喂给 [classifyWarehouseWebViewError]，
 * 不参与映射，所以镜像失真只会表现为「分类退化成 UNKNOWN」，不会误报成别的种类。
 */
object WarehouseWebViewErrorCodes {
    const val UNKNOWN = -1
    const val HOST_LOOKUP = -2
    const val UNSUPPORTED_AUTH_SCHEME = -3
    const val AUTHENTICATION = -4
    const val PROXY_AUTHENTICATION = -5
    const val CONNECT = -6
    const val IO = -7
    const val TIMEOUT = -8
    const val REDIRECT_LOOP = -9
    const val UNSUPPORTED_SCHEME = -10
    const val FAILED_SSL_HANDSHAKE = -11
    const val BAD_URL = -12
    const val FILE = -13
    const val FILE_NOT_FOUND = -14
    const val TOO_MANY_REQUESTS = -15
    const val UNSAFE_RESOURCE = -16
}

/**
 * 网页加载失败的分类。**只分类、不出文案**：真正给用户看的那句话由调用方从 ARB 取
 * （[arbKey] 给出现成键名，取不到时调用方自己兜底），避免在 Kotlin 里硬写中文字面量
 * ——那会被 `b9bc98d1` 立的中文字面量棘轮门禁拦下。
 */
enum class WarehouseWebViewErrorKind(
    /** 现有 ARB 键名；没有对应现成文案时为 null。 */
    val arbKey: String?,
) {
    /** 明文 HTTP 被网络安全配置拦掉（`ERR_CLEARTEXT_NOT_PERMITTED`）。 */
    CLEARTEXT_BLOCKED("importCleartextBlockedHint"),

    /** DNS 解析不出来：域名写错、或当前网络没有 DNS。 */
    HOST_UNREACHABLE(null),

    /** 连不上：网络断开、被防火墙拦、对端拒绝。 */
    CONNECTION_FAILED(null),

    /** 超时。 */
    TIMEOUT(null),

    /** TLS 握手失败（证书过期 / 自签 / 协议不匹配）。 */
    SSL_FAILED(null),

    /** 需要认证（含代理认证）。 */
    AUTH_REQUIRED(null),

    /** 地址本身不合法。 */
    BAD_URL(null),

    /** scheme 不受支持。 */
    UNSUPPORTED_SCHEME(null),

    /** 重定向成环。 */
    REDIRECT_LOOP(null),

    /** 被服务端限流（HTTP 429）。 */
    TOO_MANY_REQUESTS(null),

    /** 其余一切，含平台 `ERROR_UNKNOWN` 与将来新增的码。 */
    UNKNOWN(null),
}

/**
 * 明文拦截判据：**逐字对齐 Dart** 的
 * `error.description.contains('ERR_CLEARTEXT_NOT_PERMITTED')`（区分大小写，
 * Chromium 侧恒为大写常量）。
 */
fun isWarehouseCleartextBlocked(description: String?): Boolean {
    return description?.contains("ERR_CLEARTEXT_NOT_PERMITTED") == true
}

/**
 * 把平台错误码 + 描述分类成 [WarehouseWebViewErrorKind]。
 *
 * 明文拦截**优先于**错误码：Chromium 把这类失败报成 `ERROR_CONNECT(-6)` 一类
 * 通用码，只看码会把「站点不在明文白名单里」讲成「网络连不上」，用户会一直重试。
 * 顺序与 Dart 的 `onWebResourceError` 一致。
 */
fun classifyWarehouseWebViewError(
    errorCode: Int,
    description: String? = null,
): WarehouseWebViewErrorKind {
    if (isWarehouseCleartextBlocked(description)) {
        return WarehouseWebViewErrorKind.CLEARTEXT_BLOCKED
    }
    return when (errorCode) {
        WarehouseWebViewErrorCodes.HOST_LOOKUP -> WarehouseWebViewErrorKind.HOST_UNREACHABLE
        WarehouseWebViewErrorCodes.CONNECT,
        WarehouseWebViewErrorCodes.IO,
        -> WarehouseWebViewErrorKind.CONNECTION_FAILED
        WarehouseWebViewErrorCodes.TIMEOUT -> WarehouseWebViewErrorKind.TIMEOUT
        WarehouseWebViewErrorCodes.FAILED_SSL_HANDSHAKE -> WarehouseWebViewErrorKind.SSL_FAILED
        WarehouseWebViewErrorCodes.UNSUPPORTED_AUTH_SCHEME,
        WarehouseWebViewErrorCodes.AUTHENTICATION,
        WarehouseWebViewErrorCodes.PROXY_AUTHENTICATION,
        -> WarehouseWebViewErrorKind.AUTH_REQUIRED
        WarehouseWebViewErrorCodes.BAD_URL -> WarehouseWebViewErrorKind.BAD_URL
        WarehouseWebViewErrorCodes.UNSUPPORTED_SCHEME -> WarehouseWebViewErrorKind.UNSUPPORTED_SCHEME
        WarehouseWebViewErrorCodes.REDIRECT_LOOP -> WarehouseWebViewErrorKind.REDIRECT_LOOP
        WarehouseWebViewErrorCodes.TOO_MANY_REQUESTS -> WarehouseWebViewErrorKind.TOO_MANY_REQUESTS
        else -> WarehouseWebViewErrorKind.UNKNOWN
    }
}

/**
 * 一次主框架加载失败的完整快照，宿主通过回调交给页面层。
 * 不含 Android 类型，便于单测直接构造断言。
 */
data class WarehouseWebViewError(
    val errorCode: Int,
    val description: String,
    val url: String?,
    val kind: WarehouseWebViewErrorKind = classifyWarehouseWebViewError(errorCode, description),
) {
    /** 给用户看的那句文案的 ARB 键名（没有现成键时为 null）。 */
    val arbKey: String? get() = kind.arbKey
}

// ---------------------------------------------------------------------------
// 4. Cookie 拼装
// ---------------------------------------------------------------------------

/** 一条 Cookie 的 `name=value` 对。 */
data class WarehouseCookie(val name: String, val value: String) {
    /** 拼成请求头里的一段。 */
    fun toPair(): String = "$name=$value"
}

/**
 * 解析 `Cookie` 请求头的值（`android.webkit.CookieManager.getCookie(url)` 返回的
 * 就是这种形状：`name=value; name2=value2`）。
 *
 * 规则：
 * - 按 `;` 切开，逐段 trim；空段丢弃；
 * - 段里没有 `=`、或 `=` 在首位（没有名字）→ 丢弃；
 * - **值里允许再出现 `=`**（base64 / JWT 一类），只在第一个 `=` 处切分；
 * - 名字与值都 trim（`CookieManager` 输出的段首常带一个空格）。
 *
 * ⚠️ 这里只认**请求 Cookie**。`Set-Cookie` 响应头（带 `Path=` / `Expires=` 属性）
 * 不适用：那会把 `Path` 当成一条名为 Path 的 Cookie。宿主取 Cookie 用的是
 * `CookieManager.getCookie`，天然是请求头形状。
 */
fun parseWarehouseCookieHeader(raw: String?): List<WarehouseCookie> {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return emptyList()
    val cookies = ArrayList<WarehouseCookie>()
    for (part in text.split(';')) {
        val segment = part.trim()
        if (segment.isEmpty()) continue
        val eq = segment.indexOf('=')
        if (eq <= 0) continue
        val name = segment.substring(0, eq).trim()
        if (name.isEmpty()) continue
        cookies.add(WarehouseCookie(name, segment.substring(eq + 1).trim()))
    }
    return cookies
}

/**
 * 把若干条 Cookie 拼回请求头值（`name=value; name2=value2`）。
 * 名字为空的条目直接丢掉；顺序按传入顺序，不排序——Cookie 的先后在部分
 * 教务站上有语义（后出现的同名项覆盖先出现的），排序会改变语义。
 */
fun buildWarehouseCookieHeader(cookies: List<WarehouseCookie>): String {
    return cookies
        .filter { it.name.isNotBlank() }
        .joinToString("; ") { it.toPair() }
}

/**
 * 合并多段 Cookie 头（后一段覆盖前一段的同名项），再拼成一段。
 *
 * 用途：`CookieManager.getCookie(url)` 只回**该 URL** 能看到的 Cookie，
 * 而导入脚本常常要跨子域（`jw.` / `cas.`）取会话。合并顺序即优先级：
 * 同名时**后面的赢**，但位置沿用第一次出现的位置（避免把已有顺序搅乱）。
 */
fun mergeWarehouseCookieHeaders(vararg raws: String?): String {
    val order = LinkedHashMap<String, WarehouseCookie>()
    for (raw in raws) {
        for (cookie in parseWarehouseCookieHeader(raw)) {
            // 后面的赢 = 直接 put：LinkedHashMap 对同名 key 只覆盖值、不挪位
            // （位置沿用第一次出现），不需要先读旧值比较。
            order[cookie.name] = cookie
        }
    }
    return buildWarehouseCookieHeader(order.values.toList())
}

// ---------------------------------------------------------------------------
// 5. JS 求值结果解码
// ---------------------------------------------------------------------------

/**
 * 解码 `WebView.evaluateJavascript` 的回调结果。
 *
 * 平台回调给的是**JSON 文本**而不是原值：字符串带引号并转义（`"\"abc\""`）、
 * 数字与布尔是字面量、JS 的 `null` / `undefined` 都回字符串 `"null"`。
 * 直接把它当文本用会连引号一起显示在界面上。
 *
 * 规则：
 * - `null` / 空串 / `"null"` → `null`（对应用户关心的「没取到值」）；
 * - JSON 字符串 → 解转义后的内容；
 * - 其他合法 JSON（数字 / 布尔 / 对象 / 数组）→ 原样返回 JSON 文本；
 * - 解不出来（理论上不该发生）→ 原样返回，宁可露出原文也不要静默吞掉。
 */
fun decodeWarehouseJsResult(raw: String?): String? {
    if (raw == null) return null
    val text = raw.trim()
    if (text.isEmpty() || text == "null") return null
    val parsed = MiniJson.tryParse(text) ?: return text
    return if (parsed is String) parsed else text
}

// ---------------------------------------------------------------------------
// 6. 桥接消息门禁（宿主开放 `QingyuBridge` 之后的安全边界）
// ---------------------------------------------------------------------------

/**
 * 只在导入执行期才处理的桥接消息类型（UI 类）。**逐字对齐 Dart**
 * `lib/domain/warehouse_bridge_gate.dart` 的 `kWarehouseImportOnlyBridgeMessageTypes`。
 *
 * 为什么接线必须带上这条门禁：登录 WebView 对**任意**页面开放 `QingyuBridge`，
 * 页面（登录跳转的中间页、被劫持的重定向、诱导用户访问的钓鱼页）随时可以
 * `postMessage`。UI 类消息的唯一合法生产者是导入执行期正在跑的适配脚本；
 * 不判就会让任意网页在原生层弹任意标题/内容的对话框（伪造「请输入身份证号」一类），
 * 这是 Dart 侧真实修过的洞（见该文件库注释第 1 点）。
 */
val WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES: Set<String> = setOf(
    "toast",
    "confirm",
    "prompt",
    "singleSelection",
    "error",
)

/**
 * 从桥接消息原始文本里取 `type` 字段。
 *
 * 页面脚本按 Dart 协议发 `QingyuBridge.postMessage(JSON.stringify({type: …}))`，
 * 所以这里要的是「JSON 文本里的 type 字符串」。不是合法 JSON、顶层不是对象、
 * `type` 不是字符串一律返回 null（调用方按「类型未知」处理）。
 */
fun warehouseBridgeMessageType(raw: String?): String? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) ?: return null
    val map = parsed as? Map<*, *> ?: return null
    return map["type"] as? String
}

/**
 * 桥接消息门禁：**逐字对齐 Dart** 的 `shouldProcessWarehouseBridgeMessage`
 * （`lib/domain/warehouse_bridge_gate.dart`，2026-11-02 第二轮安全审计 #2 后的新语义）。
 *
 * - UI 类消息（[WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES]）只在导入执行期放行；
 * - `macro:event` 只认**录制态**：唯一合法生产者是宿主在录制态注入的录制脚本，
 *   非录制态一律丢弃（原先这个判据写在事件处理器内部，现与其它消息一样收进门禁）；
 * - `loginAttempt` 取并集放行：执行期 / 录制态 / 前台回放导航阶段 /
 *   当前页在受信 host 上（[trustedPageOrigin]，锚点见 [warehouseUrlOnTrustedHosts]）——
 *   普通手动登录不在执行期，主路径靠受信 host 这条放行；钓鱼页/第三方页上的
 *   伪造登录尝试在这里被挡下（伪造的落点是「保存密码」弹窗，存盘即覆盖真凭据）；
 * - 其余非 UI 类消息（`loginState` / `sessionProbe` / 数据类…）照常处理；
 * - [type] 为 null（判不出类型）时交回调用方——与 Dart「非 UI 类一律照常处理」同一口径。
 *
 * Kotlin 侧现状（诚实边界）：宏录制与回放引擎尚未移植（F08-8c），边界处
 * `macroRecordingActive` 传的是真实会话状态（现在恒为 IDLE ⇒ 恒 false）、
 * `foregroundReplayActive` 无对应状态传默认 false；受信 host 一条已随
 * [trustedPageOrigin] 接到边界（见 `WarehouseWebLoginWebState.shouldDeliverBridgeMessage`）。
 * 这两个参数先落位，消费方移植时不再改门禁签名。
 */
fun shouldProcessWarehouseBridgeMessage(
    type: String?,
    importExecutionActive: Boolean,
    macroRecordingActive: Boolean = false,
    foregroundReplayActive: Boolean = false,
    trustedPageOrigin: Boolean = false,
): Boolean {
    if (type == null) return true
    return when (type) {
        "macro:event" -> macroRecordingActive
        "loginAttempt" ->
            importExecutionActive || macroRecordingActive ||
                foregroundReplayActive || trustedPageOrigin
        else -> if (type !in WAREHOUSE_IMPORT_ONLY_BRIDGE_MESSAGE_TYPES) true else importExecutionActive
    }
}

/**
 * 取 URL 的 host（小写，去掉 userinfo / 端口 / 路径）；解析不出返回空串。
 *
 * 不用 `java.net.URI`：它对非 ASCII 主机名（`http://例.com`）直接抛
 * `URISyntaxException`，而 Dart 的 `Uri.tryParse` 收得下——用 URI 会把合法中文域名的
 * 门禁判定从「放行/拒绝」扭曲成「抛异常」，行为与 Dart 不一致（同 [warehouseUrlScheme]
 * 的取舍）。没有 `://` 的输入（相对地址、`about:blank` 一类）按「没有 host」处理。
 */
fun warehouseUrlHost(url: String?): String {
    val text = url?.trim().orEmpty()
    if (text.isEmpty()) return ""
    val schemeSep = text.indexOf("://")
    if (schemeSep < 0) return ""
    var rest = text.substring(schemeSep + 3)
    for (sep in charArrayOf('/', '?', '#')) {
        val cut = rest.indexOf(sep)
        if (cut >= 0) rest = rest.substring(0, cut)
    }
    val at = rest.lastIndexOf('@')
    if (at >= 0) rest = rest.substring(at + 1)
    rest = if (rest.startsWith("[")) {
        // IPv6 字面量 [::1]:8080：取方括号里的地址本体
        val end = rest.indexOf(']')
        if (end < 0) return ""
        rest.substring(1, end)
    } else {
        val colon = rest.lastIndexOf(':')
        if (colon >= 0) rest.substring(0, colon) else rest
    }
    return rest.trim().lowercase()
}

/**
 * 当前页 URL 是否落在受信 host 集合内（精确或子域）——loginAttempt 门禁的
 * 「同源放行」锚点。**逐字对齐 Dart**
 * `lib/domain/warehouse_bridge_gate.dart` 的 `warehouseUrlOnTrustedHosts`。
 *
 * 受信 host 由调用方从现有配置构造（[warehouseTrustedLoginHosts]：适配器登记地址 +
 * 受信自定义地址），这里不做任何硬编码名单。两处（Dart/Kotlin）测试都必须覆盖
 * `a.trusted.cn` 匹配 `trusted.cn`、而 `trusted.cn.evil.com` 的后缀伪装被拒绝。
 *
 * 解析不出 host 的输入（空串、相对地址、非 http 形态）按拒绝处理：门禁
 * 因此只会更严，不会更松。
 */
fun warehouseUrlOnTrustedHosts(url: String?, trustedHosts: Iterable<String>): Boolean {
    val host = warehouseUrlHost(url)
    if (host.isEmpty()) return false
    for (trusted in trustedHosts) {
        val t = trusted.trim().lowercase()
        if (t.isEmpty()) continue
        if (host == t || host.endsWith(".$t")) return true
    }
    return false
}

/**
 * 受信 host 集合的构造：从**现有配置地址**取 host（适配器登记的登录地址 + 受信的
 * 自定义导入地址），与 Dart 侧「受信 host 由宿主提供」同一来源口径——不另造一份
 * 硬编码名单。解析不出 host 的地址直接跳过（门禁只会更严）。
 */
fun warehouseTrustedLoginHosts(vararg urls: String?): Set<String> =
    urls.mapNotNull { warehouseUrlHost(it).takeIf { host -> host.isNotEmpty() } }.toSet()
