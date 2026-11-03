package com.mutx163.qingyu.pages.import.warehouse

/**
 * 脚本页 URL 脱敏（P1 / N2 前半）：把一次性 / 会话类参数从 URL 里摘掉，
 * 让保存下来的 `scriptPageUrl` 能跨会话复用，也绝不把会话凭据带进宏、云同步与日志。
 *
 * 逐字对齐 Dart `lib/models/warehouse_macro_models.dart` 的
 * `isWarehouseVolatileUrlParamKey` / `warehouseFragmentCarriesVolatileParam` /
 * `sanitizeWarehouseScriptPageUrl`（只读参照物，判据逐条机械抄）。
 *
 * ## 为什么手写解析而不用 `java.net.URI`
 *
 * - `URI` 对非 ASCII 主机名（中文域名）直接抛异常；Dart `Uri.tryParse` 收得下；
 * - Dart 的 `Uri` 会把 ROOT 应用的矩阵参数并进 **host**（`http://host;jsessionid=ABC/path`
 *   实测 host 变成 `host;jsessionid=ABC`），行为有实测对拍特例，见下文。
 *
 * ## 与 Dart 的已知差异（诚实边界）
 *
 * Dart 重建 `Uri` 时会按组件重新百分号编码；本实现**保持原字节**（只删段、不重编码），
 * 对已正常编码的教务 URL 输出功能等价（导航目标一致），但字节上可能与 Dart 输出
 * 在转义风格（如空格）上不同。脱敏判据与五类特例行为逐字对齐，测试钉死。
 * 另外 Dart 会对 path 做点段归一化，本实现不做（教务 URL 实际不出现 `..` 段）。
 */

/** 一次性 / 会话类参数名（Dart `warehouseVolatileUrlParamKeys`，逐字一致）。 */
private val WAREHOUSE_VOLATILE_URL_PARAM_KEYS: Set<String> = setOf(
    "jsessionid",
    "jsessionId",
    "JSESSIONID",
    "ticket",
    "token",
    "access_token",
    "refresh_token",
    "state",
    "nonce",
    "timestamp",
    "ts",
    "t",
    "random",
    "rnd",
    "sid",
    "sessionid",
    "sessionId",
)

/**
 * 某个 URL 参数名是不是「换一次会话就失效、而且可能是凭据」的那一类。
 *
 * 精确名单之外还有子串口径：PHP 的 `PHPSESSID`、ASP.NET 的 `ASP.NET_SessionId`
 * 靠 `sess` 子串兜住。query 与 fragment 共用这一份判据，两边口径不分叉。
 */
fun isWarehouseVolatileUrlParamKey(key: String): Boolean {
    if (key in WAREHOUSE_VOLATILE_URL_PARAM_KEYS) return true
    val lowerKey = key.lowercase()
    if (lowerKey in WAREHOUSE_VOLATILE_URL_PARAM_KEYS) return true
    return lowerKey.contains("token") ||
        lowerKey.contains("ticket") ||
        lowerKey.contains("jsession") ||
        lowerKey.contains("sess") ||
        lowerKey.contains("pwd") ||
        lowerKey.contains("passwd") ||
        lowerKey.contains("password")
}

/** fragment 里找 `key=` 形态的正则（Dart 同款）。 */
private val WAREHOUSE_FRAGMENT_PARAM_REGEX =
    Regex("""(?:^|[?&#;/])\s*([A-Za-z_][A-Za-z0-9_.\-]*)\s*=""")

/** path 里内嵌 `;jsessionid=…` 段的正则（Dart 同款，大小写不敏感）。 */
private val WAREHOUSE_PATH_JSESSIONID_REGEX = Regex(""";jsessionid=[^;/]+""", RegexOption.IGNORE_CASE)

/**
 * fragment 里有没有夹带会话 / 凭据参数（OAuth 回调风格的 `#access_token=…`）。
 *
 * 只要命中一个键名，整个 fragment 都不要：那种 fragment 本身就是一次性回调载荷，
 * 留半截没意义。纯路由 fragment（SPA 的 `#/schedule`）不受影响。
 */
fun warehouseFragmentCarriesVolatileParam(fragment: String): Boolean {
    for (match in WAREHOUSE_FRAGMENT_PARAM_REGEX.findAll(fragment)) {
        if (isWarehouseVolatileUrlParamKey(match.groupValues[1])) return true
    }
    return false
}

/**
 * 一次性 query 参数的判定要用**解码后**的键名（Dart `queryParameters` 返回解码值）：
 * `jsession%69d` 这类混淆写法解码后才是 `jsessionid`。只用于判定，重建时仍用原字节。
 * `+` 在 query 里按空格处理（Dart 同口径）；坏转义原样保留。
 */
private fun decodeQueryParamKeyForCheck(rawKey: String): String {
    val text = rawKey.replace('+', ' ')
    if (!text.contains('%')) return text
    val sb = StringBuilder(text.length)
    var i = 0
    while (i < text.length) {
        val c = text[i]
        if (c == '%' && i + 2 < text.length) {
            val hex = text.substring(i + 1, i + 3)
            val code = hex.toIntOrNull(16)
            if (code != null) {
                sb.append(code.toChar())
                i += 3
                continue
            }
        }
        sb.append(c)
        i++
    }
    return sb.toString()
}

/**
 * Strips one-time / session params so a saved script page URL can be reused across
 * sessions. Returns null when the URL is not a usable absolute http(s) location.
 *
 * 五类特例（每类都有测试钉着）：
 * 1. query 逐参过滤（键名判据见 [isWarehouseVolatileUrlParamKey]，键按解码值判、原字节保留）；
 * 2. path 内嵌 `;jsessionid=…` 整段摘除；
 * 3. host 内 `;`（Dart Uri 把 ROOT 应用的矩阵参数并进 host 的实测特例）从第一个 `;` 截断；
 * 4. fragment 命中凭据键名 → 整段丢（OAuth 回调载荷）；
 * 5. 纯路由 fragment（SPA `#/schedule`）保留。
 */
fun sanitizeWarehouseScriptPageUrl(rawUrl: String?): String? {
    val trimmed = rawUrl?.trim()
    if (trimmed.isNullOrEmpty()) return null

    // scheme://authority/path?query#fragment —— 手写拆分，不用 java.net.URI。
    val schemeEnd = trimmed.indexOf("://")
    if (schemeEnd <= 0) return null
    val scheme = trimmed.substring(0, schemeEnd).lowercase()
    if (scheme != "http" && scheme != "https") return null
    var rest = trimmed.substring(schemeEnd + 3)

    // fragment（第一个 '#' 之后）
    var fragment: String? = null
    val hashAt = rest.indexOf('#')
    if (hashAt >= 0) {
        fragment = rest.substring(hashAt + 1)
        rest = rest.substring(0, hashAt)
    }

    // query（第一个 '?' 之后）
    var query: String? = null
    val queryAt = rest.indexOf('?')
    if (queryAt >= 0) {
        query = rest.substring(queryAt + 1)
        rest = rest.substring(0, queryAt)
    }

    // authority + path
    val slashAt = rest.indexOf('/')
    val authority = if (slashAt >= 0) rest.substring(0, slashAt) else rest
    var path = if (slashAt >= 0) rest.substring(slashAt) else ""

    // host：去 userinfo；Dart Uri 的矩阵参数特例（`;` 段并进 host）从第一个 ';' 截断。
    var host = authority
    val userAt = host.lastIndexOf('@')
    if (userAt >= 0) host = host.substring(userAt + 1)
    var port: String? = null
    if (host.startsWith("[")) {
        // IPv6 字面量 [::1]:8080：方括号本体 + 其后可带的端口
        val bracketEnd = host.indexOf(']')
        if (bracketEnd < 0) return null
        val tail = host.substring(bracketEnd + 1)
        if (tail.startsWith(":") && tail.substring(1).isDigitsOnly()) {
            port = tail.substring(1)
            host = host.substring(0, bracketEnd + 1)
        }
    } else {
        val colonAt = host.lastIndexOf(':')
        if (colonAt >= 0) {
            val tail = host.substring(colonAt + 1)
            val digitRun = tail.takeWhile { it in '0'..'9' }
            if (digitRun.isNotEmpty()) {
                port = digitRun
                host = host.substring(0, colonAt)
            }
            // 冒号后不是数字：整段属于 host，交给下面的 ';' 截断处理。
        }
        val semiAt = host.indexOf(';')
        if (semiAt >= 0) host = host.substring(0, semiAt)
    }
    host = host.lowercase()
    if (host.isEmpty()) return null

    // query 逐参过滤：按解码键名判丢弃，保留的段用原字节（不重编码）。
    // 重复键后值覆盖前值（与 Dart queryParameters 的 map 语义一致）。
    var keptQuery: String? = null
    if (query != null && query.isNotEmpty()) {
        val keptSegments = LinkedHashMap<String, String>()
        for (segment in query.split('&')) {
            if (segment.isEmpty()) continue
            val eqAt = segment.indexOf('=')
            val rawKey = if (eqAt >= 0) segment.substring(0, eqAt) else segment
            if (isWarehouseVolatileUrlParamKey(decodeQueryParamKeyForCheck(rawKey))) continue
            keptSegments[rawKey] = segment
        }
        if (keptSegments.isNotEmpty()) keptQuery = keptSegments.values.joinToString("&")
    }

    // path 内嵌的 jsessionid 段摘除；空 path 回退根路径。
    path = WAREHOUSE_PATH_JSESSIONID_REGEX.replace(path, "")
    if (path.isEmpty()) path = "/"

    // fragment：命中凭据键名整段丢；纯路由保留。
    val keptFragment = fragment
        ?.takeIf { it.isNotEmpty() && !warehouseFragmentCarriesVolatileParam(it) }

    return buildString {
        append(scheme)
        append("://")
        append(host)
        if (port != null) {
            append(':')
            append(port)
        }
        append(path)
        if (keptQuery != null) {
            append('?')
            append(keptQuery)
        }
        if (keptFragment != null) {
            append('#')
            append(keptFragment)
        }
    }
}

private fun String.isDigitsOnly(): Boolean = isNotEmpty() && all { it in '0'..'9' }
