package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.net.URI

/**
 * 教务网页登录**之后**的纯逻辑层：把 WebView 里拿到的 Cookie 快照
 * **提取**成「这一趟能给教务站用的 Cookie」，据此**判定登录态**，并在
 * 登录态成立时给出**触发已有课表抓取适配器**的判定结果。
 *
 * 本文件**只允许纯 JVM 代码**：不得 import `android.*` / `androidx.compose.*` / miuix，
 * 否则 `scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"`（L0）编不过。
 * 它不碰网络、不碰 WebView——平台侧（`composeP1/.../WarehouseWebViewHost.kt`）只负责
 * 把 `CookieManager` 读到的 Cookie 快照喂进来、把判定结果接回去；真正的注入/发包
 * 由 Lead 接线完成。
 *
 * 与既有文件的分工（避免重复）：
 * - `WarehouseWebViewLogic.kt` 的 `parseWarehouseCookieHeader` /
 *   `buildWarehouseCookieHeader` / `mergeWarehouseCookieHeaders` 处理的是**请求头形状**
 *   （`name=value; name2=value2`，只有名值、没有属性）；
 * - 本文件处理的是**带属性的 Set-Cookie / 快照形状**（`Domain` / `Path` / `Expires` /
 *   `Max-Age` / `Secure` / `HttpOnly`），因此能做过期判定、按目标 URL 过滤、按名字判登录态。
 *   最终拼头仍复用 `buildWarehouseCookieHeader`，不另造一套口径。
 *
 * 参照物（只读）：`lib/domain/warehouse_session_probe.dart`（登录态「不确定时倒向未知」
 * 的取向）、`lib/domain/warehouse_course_import_logic.dart`（适配器下发数据一律宽容解析，
 * 畸形不抛错）。Cookie 的域/路径匹配口径遵循 RFC 6265 §5.1.3 / §5.1.4。
 *
 * 关于「过期」的现实来源（诚实说明，接线时别当已有）：`android.webkit.CookieManager`
 * 只暴露 `getCookie(url): String`（名值对），**不暴露单条 Cookie 的过期时间/域/路径**。
 * 所以本文件需要的属性化快照，要么由平台侧另找来源（如应用自建 Cookie 存储 / 适配器
 * 回传），要么由本逻辑只拿 `Expires`/`Max-Age` 字符串解析而来。这一层只保证**纯逻辑
 * 正确且可测**；数据从哪来属接线决策，本文件不假设。
 */

// ---------------------------------------------------------------------------
// 1. 带属性的会话 Cookie 模型 + 解析
// ---------------------------------------------------------------------------

/**
 * 一条带属性的 Cookie。
 *
 * - [domain] 为 `null` 表示「未知域」：保守当作**任何主机都适用**（多带一条 Cookie 顶多
 *   被服务器忽略，不会比漏带更糟）。域匹配时忽略前导点（RFC 6265：`Domain=.a.com` 与
 *   `Domain=a.com` 等价）。
 * - [expiresAtEpochSeconds] 为 `null` 表示**会话 Cookie**（关掉即失效，本逻辑永不过期）。
 * - [path] 空串按 `/` 处理。
 */
data class WarehouseCookieRecord(
    val name: String,
    val value: String,
    val domain: String? = null,
    val path: String = "/",
    val expiresAtEpochSeconds: Long? = null,
    val secure: Boolean = false,
    val httpOnly: Boolean = false,
)

/**
 * 解析**一条** `Set-Cookie` 形状的串。
 *
 * 形状：`name=value; Path=/; Domain=.jw.school.edu.cn; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Secure; HttpOnly`
 *
 * 规则：
 * - 首段必须是 `name=value`，名字非空且不含空白；否则整条判为畸形，返回 `null`
 *   （对应「缺关键字段 / 畸形 Cookie 串」）。
 * - 值可为空，且**允许再出现 `=`**（base64 / JWT），只在第一个 `=` 处切分。
 * - 属性名大小写不敏感；未知属性忽略。`Expires` 按 RFC 1123 解析成绝对秒数；
 *   `Max-Age` 是**相对**接收时刻的秒数，必须配合 [receivedAtEpochSeconds] 才能折算成
 *   绝对过期时间（不传则按会话 Cookie 处理——无法在缺参照时钟时凭空造绝对时间）。
 * - `Max-Age` 与 `Expires` 同时出现时，`Max-Age` 优先（RFC 6265 §4.1.2.2）。
 *
 * @param receivedAtEpochSeconds 收到这条 Cookie 的时刻（epoch 秒），仅 `Max-Age` 用得上。
 */
fun parseWarehouseSetCookie(
    raw: String?,
    receivedAtEpochSeconds: Long? = null,
): WarehouseCookieRecord? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null

    val segments = text.split(';')
    val first = segments.firstOrNull()?.trim().orEmpty()
    val eq = first.indexOf('=')
    if (eq <= 0) return null
    val name = first.substring(0, eq).trim()
    if (name.isEmpty() || name.any { it.isWhitespace() }) return null
    val value = first.substring(eq + 1).trim()

    var domain: String? = null
    var path = "/"
    var expiresAt: Long? = null
    var maxAgeSeconds: Long? = null
    var secure = false
    var httpOnly = false

    for (index in 1 until segments.size) {
        val segment = segments[index].trim()
        if (segment.isEmpty()) continue
        val attrEq = segment.indexOf('=')
        val attrName = (if (attrEq >= 0) segment.substring(0, attrEq) else segment).trim().lowercase()
        val attrValue = if (attrEq >= 0) segment.substring(attrEq + 1).trim() else ""
        when (attrName) {
            "domain" -> if (attrValue.isNotEmpty()) domain = attrValue
            "path" -> if (attrValue.startsWith("/")) path = attrValue
            "expires" -> parseWarehouseHttpDateEpochSeconds(attrValue)?.let { expiresAt = it }
            "max-age" -> attrValue.toLongOrNull()?.let { maxAgeSeconds = it }
            "secure" -> secure = true
            "httponly" -> httpOnly = true
            else -> Unit
        }
    }

    // Max-Age 优先于 Expires；只有拿到「接收时刻」才能折成绝对时间。
    if (maxAgeSeconds != null && receivedAtEpochSeconds != null) {
        expiresAt = receivedAtEpochSeconds + maxAgeSeconds
    }

    return WarehouseCookieRecord(
        name = name,
        value = value,
        domain = domain,
        path = path,
        expiresAtEpochSeconds = expiresAt,
        secure = secure,
        httpOnly = httpOnly,
    )
}

/**
 * 把一串 **JSON 数组快照**解析成 [WarehouseCookieRecord] 列表。
 *
 * 这是平台侧最可能产出的形状（应用内部维护的 Cookie 存储导出）。每个元素是对象：
 * ```json
 * [ {"name":"JSESSIONID","value":"abc","domain":".jw.school.edu.cn","path":"/",
 *    "expiresAt":1792567680,"secure":true,"httpOnly":true} ]
 * ```
 * 容忍度与「适配器下发数据一律宽容解析」同口径：
 * - 非 JSON / 顶层不是数组 → 空列表（不抛）；
 * - 元素不是对象、缺 `name`、`name` 为空或含空白 → 跳过该条；
 * - `expiresAt`（别名 `expires` / `expiresAtEpochSeconds`）接受数字或数字字符串；
 *   非法值当作会话 Cookie（`null`），不抛；
 * - `secure` / `httpOnly` 接受布尔、`"true"/"1"`、非零数字。
 */
fun parseWarehouseCookieSnapshot(raw: String?): List<WarehouseCookieRecord> {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return emptyList()
    val decoded = MiniJson.tryParse(text) ?: return emptyList()
    val items = decoded as? List<*> ?: return emptyList()

    val cookies = ArrayList<WarehouseCookieRecord>()
    for (item in items) {
        val map = item as? Map<*, *> ?: continue
        val name = cookieCoerceText(map["name"]).trim()
        if (name.isEmpty() || name.any { it.isWhitespace() }) continue
        val value = cookieCoerceText(map["value"])
        val domain = cookieCoerceText(map["domain"]).trim().ifEmpty { null }
        var path = cookieCoerceText(map["path"]).trim()
        if (!path.startsWith("/")) path = "/"
        val expires = cookieCoerceLong(
            map["expiresAt"] ?: map["expires"] ?: map["expiresAtEpochSeconds"]
        )
        cookies.add(
            WarehouseCookieRecord(
                name = name,
                value = value,
                domain = domain,
                path = path,
                expiresAtEpochSeconds = expires,
                secure = cookieCoerceBool(map["secure"]),
                httpOnly = cookieCoerceBool(map["httpOnly"]),
            )
        )
    }
    return cookies
}

/**
 * 解析 `Set-Cookie` 里的日期（`Expires=...`）成 **UTC epoch 秒**；解不出返回 `null`。
 *
 * 支持 RFC 1123（`Wed, 21 Oct 2026 07:28:00 GMT`）、以及把日-月-年写成连字符的
 * RFC 850 变体（`21-Oct-2026 07:28:00 GMT`）。星期前缀被忽略。时区一律按 GMT/UTC
 * （`Set-Cookie` 的 `Expires` 就是 GMT）。
 *
 * 自己实现而不是用 `java.time`：本文件要能在最小 JVM classpath（只有 kotlin-stdlib）
 * 下编译，且不想给 Android 低 API 级别引入 desugaring 依赖。日期→秒用 GNSS/公历闭式
 * 算法（Howard Hinnant 的 days_from_civil），对格里高利历**精确**。
 */
fun parseWarehouseHttpDateEpochSeconds(raw: String?): Long? {
    var text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    // 去掉 "Wed," 这类星期前缀
    val comma = text.indexOf(',')
    if (comma >= 0) text = text.substring(comma + 1).trim()
    if (text.isEmpty()) return null
    // RFC 850 的 "21-Oct-2026" 用连字符；统一成空格再切
    val tokens = text.replace('-', ' ').split(' ').filter { it.isNotEmpty() }
    if (tokens.size < 4) return null
    val day = tokens[0].toIntOrNull() ?: return null
    val month = warehouseMonthIndex(tokens[1]) ?: return null
    val year = tokens[2].toIntOrNull() ?: return null
    val timeParts = tokens[3].split(':')
    if (timeParts.size < 2) return null
    val hour = timeParts[0].toIntOrNull() ?: return null
    val minute = timeParts[1].toIntOrNull() ?: return null
    val second = if (timeParts.size >= 3) timeParts[2].toIntOrNull() ?: 0 else 0
    if (year < 1970 || year > 9999) return null
    if (month !in 1..12) return null
    if (day !in 1..31) return null
    if (hour !in 0..23 || minute !in 0..59 || second !in 0..59) return null
    return warehouseEpochSecondsUtc(year, month, day, hour, minute, second)
}

private fun warehouseMonthIndex(token: String): Int? = when (token.take(3).lowercase()) {
    "jan" -> 1
    "feb" -> 2
    "mar" -> 3
    "apr" -> 4
    "may" -> 5
    "jun" -> 6
    "jul" -> 7
    "aug" -> 8
    "sep" -> 9
    "oct" -> 10
    "nov" -> 11
    "dec" -> 12
    else -> null
}

/** 公历日期 → UTC epoch 秒（Howard Hinnant `days_from_civil`）。 */
private fun warehouseEpochSecondsUtc(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    second: Int,
): Long {
    val a = (14 - month) / 12
    val y = year + 4800 - a
    val m = month + 12 * a - 3
    val julianDayNumber = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    val daysSinceEpoch = julianDayNumber.toLong() - 2440588L
    return daysSinceEpoch * 86400L + hour * 3600L + minute * 60L + second
}

// ---------------------------------------------------------------------------
// 2. 过期判定 + 按目标 URL 提取
// ---------------------------------------------------------------------------

/**
 * 过期判据：**有绝对过期时间**且 **`<= now`** 即过期。
 *
 * 用 `<=` 而不是 `<`：`Expires` 恰好等于当前时刻时，Cookie 已经到期（RFC 6265 的
 * max-age 语义也是 `<= now` 即失效）。会话 Cookie（`null`）永不过期。
 */
fun isWarehouseCookieExpired(cookie: WarehouseCookieRecord, nowEpochSeconds: Long): Boolean {
    val expiresAt = cookie.expiresAtEpochSeconds ?: return false
    return expiresAt <= nowEpochSeconds
}

/**
 * 域是否匹配：忽略前导点，`host == domain` 或 `host` 以 `.domain` 结尾即算匹配。
 * [cookieDomain] 为空表示「未知域」，保守放行（返回 true）。
 */
fun warehouseCookieDomainMatches(host: String, cookieDomain: String?): Boolean {
    val normalizedDomain = cookieDomain?.trim()?.trimStart('.')?.lowercase().orEmpty()
    if (normalizedDomain.isEmpty()) return true
    val normalizedHost = host.trim().trimEnd('.').lowercase()
    if (normalizedHost.isEmpty()) return false
    return normalizedHost == normalizedDomain || normalizedHost.endsWith(".$normalizedDomain")
}

/**
 * 路径是否匹配（RFC 6265 §5.1.4）：
 * - 完全相等 → 匹配；
 * - 请求路径以 Cookie 路径为前缀，且 Cookie 路径以 `/` 结尾 → 匹配；
 * - 请求路径以 Cookie 路径为前缀，且紧接的下一个字符是 `/` → 匹配。
 * 空 Cookie 路径按 `/` 处理。
 */
fun warehouseCookiePathMatches(requestPath: String, cookiePath: String): Boolean {
    val path = cookiePath.ifBlank { "/" }
    val request = requestPath.ifBlank { "/" }
    if (request == path) return true
    if (!request.startsWith(path)) return false
    if (path.endsWith("/")) return true
    return request.getOrElse(path.length) { '/' } == '/'
}

/**
 * 从 Cookie 快照里提取**这一趟真正能给 [targetUrl] 用的** Cookie，保持原顺序。
 *
 * 过滤条件（全部满足才保留）：未过期、域匹配、路径匹配、`Secure` 的只在 https 下带。
 * [targetUrl] 不是合法的 http/https 地址时返回空列表（拿不到主机就无从过滤）。
 */
fun extractWarehouseCookiesForUrl(
    cookies: List<WarehouseCookieRecord>,
    targetUrl: String?,
    nowEpochSeconds: Long,
): List<WarehouseCookieRecord> {
    val target = parseWarehouseCookieTarget(targetUrl) ?: return emptyList()
    return cookies.filter { cookie ->
        !isWarehouseCookieExpired(cookie, nowEpochSeconds) &&
            warehouseCookieDomainMatches(target.host, cookie.domain) &&
            warehouseCookiePathMatches(target.path, cookie.path) &&
            (!cookie.secure || target.secure)
    }
}

/** 把提取结果拼成请求头值（复用 `buildWarehouseCookieHeader` 的同一口径）。 */
fun warehouseSessionCookieHeader(cookies: List<WarehouseCookieRecord>): String =
    buildWarehouseCookieHeader(cookies.map { WarehouseCookie(it.name, it.value) })

private data class WarehouseCookieTarget(
    val host: String,
    val path: String,
    val secure: Boolean,
)

private fun parseWarehouseCookieTarget(url: String?): WarehouseCookieTarget? {
    val text = url?.trim().orEmpty()
    if (text.isEmpty()) return null
    val uri = runCatching { URI(text) }.getOrNull() ?: return null
    val scheme = uri.scheme?.lowercase() ?: return null
    if (scheme != "http" && scheme != "https") return null
    val host = uri.host ?: return null
    if (host.isEmpty()) return null
    val path = uri.path?.ifEmpty { "/" } ?: "/"
    return WarehouseCookieTarget(host = host, path = path, secure = scheme == "https")
}

// ---------------------------------------------------------------------------
// 3. 登录态判定
// ---------------------------------------------------------------------------

/** 由 Cookie 得到的登录态三值结论。 */
enum class WarehouseLoginState(
    /** 仅供测试与日志友好显示，不参与判定。 */
    val label: String,
) {
    /** 关键 Cookie 齐全且未过期。 */
    LOGGED_IN("loggedIn"),

    /** 关键 Cookie 缺失或已过期。 */
    LOGGED_OUT("loggedOut"),

    /** 判不出来（没配关键 Cookie 名 / 目标地址非法）。**不等于没登录**。 */
    UNKNOWN("unknown"),
}

/**
 * 一次登录态判定的结果。
 *
 * - [missingRequiredCookieNames]：既没有、也不是「过期」的关键 Cookie 名（真缺）。
 * - [expiredRequiredCookieNames]：曾经有、但已过期的关键 Cookie 名。
 * - [cookieHeader]：登录成功时可直接用的请求头值（失败时为空串）。
 */
data class WarehouseLoginEvaluation(
    val state: WarehouseLoginState,
    val missingRequiredCookieNames: List<String> = emptyList(),
    val expiredRequiredCookieNames: List<String> = emptyList(),
    val cookieHeader: String = "",
)

/**
 * 判定登录态。
 *
 * 判据（取向与 `warehouse_session_probe.dart` 一致：**不确定就倒向 UNKNOWN**）：
 * - 没配置关键 Cookie 名，或 [targetUrl] 不是合法 http/https → `UNKNOWN`（判不了不硬判）；
 * - 每个关键名都能在「对该 URL 有效且未过期」的 Cookie 里找到非空值 → `LOGGED_IN`；
 * - 否则 `LOGGED_OUT`，并把关键名分成「真缺」与「已过期」两类回报。
 *
 * @param requiredCookieNames 各校自己的会话 Cookie 名（如 `JSESSIONID`），由适配器/学校配置提供。
 */
fun evaluateWarehouseLoginState(
    cookies: List<WarehouseCookieRecord>,
    requiredCookieNames: List<String>,
    targetUrl: String?,
    nowEpochSeconds: Long,
): WarehouseLoginEvaluation {
    val target = parseWarehouseCookieTarget(targetUrl)
    val required = requiredCookieNames.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
    if (target == null || required.isEmpty()) {
        return WarehouseLoginEvaluation(WarehouseLoginState.UNKNOWN)
    }

    val applicable = extractWarehouseCookiesForUrl(cookies, targetUrl, nowEpochSeconds)
    val presentNames = applicable.filter { it.value.isNotBlank() }.map { it.name }.toSet()

    // 只统计「域/路径适用、但已过期」的关键 Cookie，用于区分「过期」和「真缺」。
    val expiredNames = cookies.filter { cookie ->
        isWarehouseCookieExpired(cookie, nowEpochSeconds) &&
            warehouseCookieDomainMatches(target.host, cookie.domain) &&
            warehouseCookiePathMatches(target.path, cookie.path)
    }.map { it.name }.toSet()

    if (required.all { it in presentNames }) {
        return WarehouseLoginEvaluation(
            state = WarehouseLoginState.LOGGED_IN,
            cookieHeader = warehouseSessionCookieHeader(applicable),
        )
    }

    val notPresent = required.filter { it !in presentNames }
    val expired = notPresent.filter { it in expiredNames }
    val missing = notPresent.filter { it !in expiredNames }
    return WarehouseLoginEvaluation(
        state = WarehouseLoginState.LOGGED_OUT,
        missingRequiredCookieNames = missing,
        expiredRequiredCookieNames = expired,
    )
}

// ---------------------------------------------------------------------------
// 4. 触发已有课表抓取适配器（纯判定，不真的发包 / 不注入）
// ---------------------------------------------------------------------------

/** 不能触发抓取的原因。 */
enum class WarehouseFetchBlockReason {
    /** 登录态判不出来（没配关键 Cookie 名 / 目标地址非法）。 */
    LOGIN_STATE_UNKNOWN,

    /** 关键 Cookie 缺失或过期。 */
    NOT_LOGGED_IN,

    /** 适配器脚本为空——没有可执行的东西。 */
    NO_ADAPTER_SCRIPT,

    /** 目标地址缺失或非法。 */
    NO_TARGET_URL,

    /** 登录成功却拼不出 Cookie 头（防御性兜底，正常不该发生）。 */
    EMPTY_COOKIE_HEADER,
}

/**
 * 触发「已有课表抓取适配器」的判定结果。
 *
 * 这是**纯数据 + 判定**，真正把 [Ready.adapterScript] 注入 WebView、或按
 * [Ready.cookieHeader] 发请求，属 Lead 接线（本文件不碰平台）。
 */
sealed class WarehouseTimetableFetchPlan {
    /** 可以触发：把 [adapterScript] 注入 WebView 执行即可（脚本内 `fetch` 自带 Cookie）。 */
    data class Ready(
        val adapterId: String,
        val targetUrl: String,
        val cookieHeader: String,
        val adapterScript: String,
    ) : WarehouseTimetableFetchPlan()

    /** 不能触发，附原因与（可空）登录态细节。 */
    data class Blocked(
        val reason: WarehouseFetchBlockReason,
        val evaluation: WarehouseLoginEvaluation? = null,
    ) : WarehouseTimetableFetchPlan()

    val isReady: Boolean get() = this is Ready
}

/**
 * 决定「现在能不能触发课表抓取适配器」。
 *
 * 判定顺序（先给用户最能行动的原因）：
 * 1. 目标地址非法 → [WarehouseFetchBlockReason.NO_TARGET_URL]；
 * 2. 登录态 `UNKNOWN` → `LOGIN_STATE_UNKNOWN`；`LOGGED_OUT` → `NOT_LOGGED_IN`；
 * 3. 适配器脚本为空 → `NO_ADAPTER_SCRIPT`；
 * 4. 拼不出 Cookie 头 → `EMPTY_COOKIE_HEADER`；
 * 5. 否则 [WarehouseTimetableFetchPlan.Ready]。
 *
 * @param adapterScript 适配器脚本正文（`WarehouseAdapterEntry.script`）。
 * @param requiredCookieNames 该学校的会话 Cookie 名。
 */
fun planWarehouseTimetableFetch(
    adapterId: String,
    adapterScript: String?,
    targetUrl: String?,
    cookies: List<WarehouseCookieRecord>,
    requiredCookieNames: List<String>,
    nowEpochSeconds: Long,
): WarehouseTimetableFetchPlan {
    val urlText = targetUrl?.trim().orEmpty()
    if (parseWarehouseCookieTarget(urlText) == null) {
        return WarehouseTimetableFetchPlan.Blocked(WarehouseFetchBlockReason.NO_TARGET_URL)
    }

    val evaluation = evaluateWarehouseLoginState(
        cookies = cookies,
        requiredCookieNames = requiredCookieNames,
        targetUrl = urlText,
        nowEpochSeconds = nowEpochSeconds,
    )
    when (evaluation.state) {
        WarehouseLoginState.UNKNOWN ->
            return WarehouseTimetableFetchPlan.Blocked(WarehouseFetchBlockReason.LOGIN_STATE_UNKNOWN, evaluation)
        WarehouseLoginState.LOGGED_OUT ->
            return WarehouseTimetableFetchPlan.Blocked(WarehouseFetchBlockReason.NOT_LOGGED_IN, evaluation)
        WarehouseLoginState.LOGGED_IN -> Unit
    }

    val script = adapterScript?.trim().orEmpty()
    if (script.isEmpty()) {
        return WarehouseTimetableFetchPlan.Blocked(WarehouseFetchBlockReason.NO_ADAPTER_SCRIPT, evaluation)
    }

    val header = evaluation.cookieHeader.ifBlank {
        warehouseSessionCookieHeader(extractWarehouseCookiesForUrl(cookies, urlText, nowEpochSeconds))
    }
    if (header.isBlank()) {
        return WarehouseTimetableFetchPlan.Blocked(WarehouseFetchBlockReason.EMPTY_COOKIE_HEADER, evaluation)
    }

    return WarehouseTimetableFetchPlan.Ready(
        adapterId = adapterId.trim(),
        targetUrl = urlText,
        cookieHeader = header,
        adapterScript = script,
    )
}

// ---------------------------------------------------------------------------
// 5. 宽容取值小工具（与 MiniJson 解出的类型对齐）
// ---------------------------------------------------------------------------

private fun cookieCoerceText(value: Any?): String = when (value) {
    null -> ""
    is String -> value
    else -> value.toString()
}

private fun cookieCoerceLong(value: Any?): Long? = when (value) {
    null -> null
    is Long -> value
    is Int -> value.toLong()
    is Number -> value.toLong()
    is String -> value.trim().toLongOrNull()
    else -> null
}

private fun cookieCoerceBool(value: Any?): Boolean = when (value) {
    is Boolean -> value
    is String -> value.trim().lowercase() == "true" || value.trim() == "1"
    is Number -> value.toDouble() != 0.0
    else -> false
}
