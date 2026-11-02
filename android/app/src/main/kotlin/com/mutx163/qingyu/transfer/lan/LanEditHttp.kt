package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.core.MiniJson
import java.io.ByteArrayOutputStream

/**
 * 局域网编辑 HTTP 服务端的**报文层**（能力缺口 B2，P3-G3 域）。
 *
 * 为什么手写 HTTP/1.1：本工程不许加依赖（`build.gradle` 属 Lead），Android 上也没有
 * 可用的轻量 HTTP 服务端库；`com.sun.net.httpserver` 属于 JDK 私有实现，
 * **在 Gradle 的 Android 单测编译里不可见**（2026-10-28 刚因此让 CI 红过），
 * 所以只能用 `java.net.ServerSocket` / `Socket` 自己解。
 * 参照物（只读）：`lib/services/lan_edit_server_service.dart` 与
 * `lib/services/lan_edit_api_handlers.dart`。
 *
 * 本文件只做**纯函数**（请求行 / 头 / 查询串 / 响应字节），不碰 socket，
 * 所以能进 L0 的纯 JVM 单测；socket 那一层在 [LanEditHttpServer]。
 */

/** 报文层限额。数值与 Dart `LanEditApiHandlers` 的 `_maxRequestBodyBytes` 等保持一致。 */
object LanEditHttpLimits {
    /** 请求行上限（含 CRLF）。正常请求行不到 200 字节，8 KiB 足够宽。 */
    const val MAX_REQUEST_LINE_BYTES = 8 * 1024

    /** 单个头部字段上限。 */
    const val MAX_HEADER_LINE_BYTES = 8 * 1024

    /** 全部头部合计上限。 */
    const val MAX_HEADER_BYTES = 32 * 1024

    /** 头部条数上限（防「大量空头」把内存吃满）。 */
    const val MAX_HEADER_COUNT = 100

    /** 请求体上限 5 MiB —— 与 Dart `_maxRequestBodyBytes` 一致（整份课表备份也远小于它）。 */
    const val MAX_BODY_BYTES = 5 * 1024 * 1024

    /**
     * 全部在飞请求体的**总字节预算**（2026-11-02 新增内存闸门）。
     *
     * 为什么单请求上限不动、加总闸：真实的最大请求体是表格导入的 `contentBase64`
     *（base64 后膨胀 4/3，5 MiB 体 ≈ 3.7 MiB 文件，Dart 解析器单文件上限 20 MiB，
     * HTTP 这条管子本来就是更窄的那个），收到 2 MiB 会拒掉合法的大表格；
     * 但 16 并发 × 5 MiB 的字节数组再转一次字符串，理论峰值 80–160 MB，
     * 而且读体发生在路由层并发闸（`router.tryEnter`）**之前**，
     * 工作池 16+4 个线程可以同时停在 readBody 里。总预算 8 MiB 把任意时刻
     * 活着的体内存钉在 ≈8 MiB 字节 + ≤8 MiB 字符串（≈16–24 MB 峰值），
     * 一次只传一个大文件的正常使用完全无感。
     */
    const val MAX_INFLIGHT_BODY_BYTES = 8L * 1024 * 1024

    /** 读一个请求体的墙钟预算（Dart `_bodyReadBudget`）。 */
    const val BODY_READ_BUDGET_MILLIS = 20_000L

    /** 同时打开的请求数上限（Dart `_maxConcurrentRequests`）：超过回 503。 */
    const val MAX_CONCURRENT_REQUESTS = 16

    /** 空闲连接超时（Dart `idleTimeout` 60 秒）：这个 socket 同网段谁都能连。 */
    const val SOCKET_IDLE_TIMEOUT_MILLIS = 60_000

    /** 接受队列长度：局域网场景几十台设备足够，队列满了直接拒新连接而不是无限排队。 */
    const val BACKLOG = 32
}

/** 请求行解析失败 / 报文越界的种类；每种带一个 HTTP 状态码与稳定的 error 串。 */
enum class LanEditHttpFailure(val status: Int, val error: String) {
    MALFORMED_REQUEST_LINE(400, "bad_request"),
    UNSUPPORTED_HTTP_VERSION(505, "http_version_not_supported"),
    INVALID_HEADER(400, "bad_request"),
    HEADER_TOO_LARGE(431, "request_header_fields_too_large"),
    TOO_MANY_HEADERS(431, "request_header_fields_too_large"),
    INVALID_CONTENT_LENGTH(400, "bad_request"),
    UNSUPPORTED_METHOD(405, "method_not_allowed"),
    BODY_TOO_LARGE(413, "payload_too_large"),
    BODY_TIMEOUT(408, "request_timeout"),
}

/** 报文层异常：带一个可直接映射成响应的 [failure]。 */
class LanEditHttpException(
    val failure: LanEditHttpFailure,
    val detail: String = "",
) : RuntimeException(if (detail.isEmpty()) failure.error else "${failure.error}: $detail")

/**
 * 在飞请求体的字节预算闸门（纯逻辑，L0 可测；服务端每实例持一个）。
 *
 * `tryAcquire` 是「要么全拿、要么不动」：剩余不足时返回 false 且预算不变，
 * 调用方直接回 503。`release` 归还时按上限钳制，重复释放不会把预算放大到超过初值。
 * 零字节体（GET 等）不走这个闸。
 */
class LanEditBodyBudget(private val maxBytes: Long) {

    private var available = maxBytes

    fun tryAcquire(bytes: Long): Boolean = synchronized(this) {
        if (bytes <= 0) return true
        if (available < bytes) return false
        available -= bytes
        true
    }

    fun release(bytes: Long) {
        if (bytes <= 0) return
        synchronized(this) { available = minOf(maxBytes, available + bytes) }
    }

    /** 剩余预算（测试与诊断用）。 */
    fun availableBytes(): Long = synchronized(this) { available }
}

/** 请求行三元组。 */
data class LanEditRequestLine(
    val method: String,
    val target: String,
    val version: String,
)

/** 解析好的请求（不含 socket）。 */
data class LanEditHttpRequest(
    val method: String,
    /** 原始 request-target，原样保留（回显/审计要用）。 */
    val target: String,
    /** 已百分号解码的路径（`/api/v1/courses`）。 */
    val path: String,
    /** 已解码的查询串（同名取第一个，与 Dart `queryParameters` 同口径）。 */
    val query: Map<String, String>,
    /** 头部名统一小写；重复的同名头按 RFC 合并成逗号串。 */
    val headers: Map<String, String>,
    /** 请求体原文（UTF-8 解码；非法字节用替换字符兜住，不让一次坏请求打崩服务）。 */
    val body: String,
    val remoteAddress: String,
) {
    fun header(name: String): String? = headers[name.lowercase()]

    fun queryParam(name: String): String? = query[name]

    val contentTypeMime: String
        get() = header("content-type")?.substringBefore(';')?.trim()?.lowercase().orEmpty()

    val contentLength: Long?
        get() = header("content-length")?.trim()?.toLongOrNull()

    /** `Bearer <token>` → `<token>`；不是这个形状返回 null（Dart `_extractBearerToken`）。 */
    val bearerToken: String?
        get() {
            val header = header("authorization") ?: return null
            val prefix = "Bearer "
            if (!header.startsWith(prefix)) return null
            return header.substring(prefix.length).trim()
        }

    /** `Origin` 头的 host（小写；IPv6 字面量保留方括号）；缺省 / `null` / 解析不出返回空串。 */
    val originHost: String
        get() {
            val origin = header("origin")?.trim().orEmpty()
            if (origin.isEmpty() || origin.equals("null", ignoreCase = true)) return ""
            return hostOf(origin)
        }

    /** `Host` 头的 host（小写；IPv6 字面量保留方括号）；解析不出返回空串。 */
    val requestHost: String
        get() = hostOf(header("host")?.trim().orEmpty())

    /**
     * 同源判定（Kotlin 侧收紧版；Dart `_isSameOrigin` 仍是「只比 host」，两端已分叉，
     * 分叉理由见 [LanEditOriginPolicy]）：
     *
     * 1. **没有 `Origin` 放行**——原生客户端 / 地址栏直接导航不带头；
     * 2. **`Origin: null` 一律拒**（旧版放行）——sandbox iframe / `file://` 判不出真实来源，
     *    而正常网页端永远是 `http://<地址>`，不需要这个口子；
     * 3. `Origin` 的 host 必须等于请求 `Host` 的 host（端口不比，Dart 口径不变）；
     * 4. **且这个 host 必须是本机 / 局域网私有网段**（[LanEditOriginPolicy]）——
     *    这是 DNS rebinding 的闸门：恶意页面把自家域名解析到手机 IP 时，
     *    `Origin` 与 `Host` 都是同一个外来域名，第 3 条拦不住，第 4 条拦得住。
     */
    val isSameOrigin: Boolean
        get() {
            val origin = header("origin")?.trim().orEmpty()
            if (origin.isEmpty()) return true
            if (origin.equals("null", ignoreCase = true)) return false
            val originHost = originHost
            if (originHost.isEmpty()) return false
            val requestHost = requestHost
            if (requestHost.isEmpty()) return false
            if (originHost != requestHost) return false
            return LanEditOriginPolicy.isLocalOrPrivateHost(requestHost)
        }

    private fun hostOf(value: String): String {
        if (value.isEmpty()) return ""
        val withScheme = if (value.startsWith("http://") || value.startsWith("https://")) {
            value
        } else {
            "http://$value"
        }
        val afterScheme = withScheme.substringAfter("://", "")
        if (afterScheme.isEmpty()) return ""
        // 去掉 userinfo / 端口 / 路径，只留主机名。
        // IPv6 字面量自带方括号（[::1]:8080）：端口分隔符『:』在括号里面，
        // 不能对它做 substringBefore(':')，否则会截成『[』。
        val hostPort = afterScheme.substringBefore('/').substringAfterLast('@')
        if (hostPort.startsWith("[")) {
            val close = hostPort.indexOf(']')
            return (if (close < 0) hostPort else hostPort.substring(0, close + 1)).lowercase()
        }
        return hostPort.substringBefore(':').trim().lowercase()
    }
}

/**
 * 来源可信判定（纯函数，L0 全覆盖）。
 *
 * 只认「本机 / 链路本地 / 局域网私有网段」的**地址字面量**与 `localhost`：
 * - IPv4：回环 `127.0.0.0/8`、私网 `10/8`、`172.16/12`、`192.168/16`、链路本地 `169.254/16`；
 * - IPv6：回环 `::1`、唯一本地 `fc00::/7`、链路本地 `fe80::/10`、
 *   IPv4 映射 `::ffff:a.b.c.d`（按 IPv4 规则判）。
 *
 * 为什么不放行任何域名：服务绑的是全部网卡、同网段谁都能连，而 DNS rebinding 的
 * 攻击形状就是「外来域名 ↔ 手机 IP」——放行域名等于把这道闸整个让出去。
 * 正常用户路径是 App 展示的 `http://<LAN IPv4>:port`（Dart `findPreferredLanIPv4`
 * 只挑 192.168 / 10 / 172.16-31 这三族），手机自开是 `127.0.0.1` / `localhost`，全覆盖。
 * 判不准的形状（缩写过短的 IPv6、前导 0 的 IPv4、段数不对）一律按不可信拒。
 */
object LanEditOriginPolicy {

    /** `localhost` 与本机 / 局域网私有网段地址字面量为 true；域名与公网地址为 false。 */
    fun isLocalOrPrivateHost(host: String): Boolean {
        val value = host.trim().lowercase()
        if (value.isEmpty()) return false
        if (value == "localhost") return true
        val literal = if (value.startsWith('[') && value.endsWith(']')) {
            value.substring(1, value.length - 1)
        } else {
            value
        }
        return if (literal.contains(':')) isTrustedIpv6(literal) else isTrustedIpv4(literal)
    }

    private fun isTrustedIpv4(value: String): Boolean {
        val parts = value.split('.')
        if (parts.size != 4) return false
        var first = -1
        var second = -1
        for ((index, part) in parts.withIndex()) {
            // 前导 0（192.168.01.1）在部分解析器里按八进制解释：形状歧义一律不认
            if (part.isEmpty() || part.length > 3 || (part.length > 1 && part[0] == '0')) return false
            var octet = 0
            for (c in part) {
                if (c < '0' || c > '9') return false
                octet = octet * 10 + (c - '0')
            }
            if (octet > 255) return false
            if (index == 0) first = octet
            if (index == 1) second = octet
        }
        return first == 127 || first == 10 ||
            (first == 172 && second in 16..31) ||
            (first == 192 && second == 168) ||
            (first == 169 && second == 254)
    }

    private fun isTrustedIpv6(value: String): Boolean {
        if (value == "::1") return true
        if (value.startsWith("::ffff:")) return isTrustedIpv4(value.removePrefix("::ffff:"))
        // fc00::/7 与 fe80::/10 只认「首组四位完整十六进制」的规范写法（fd12:… / fe80::…）。
        // 首组不足四位时首字节判不准（"fc::1" 的首字节其实是 0x00），按不可信拒。
        val first = value.substringBefore(':')
        if (first.length != 4) return false
        val high = first.substring(0, 2).toIntOrNull(16) ?: return false
        val low = first.substring(2, 4).toIntOrNull(16) ?: return false
        return high == 0xfc || high == 0xfd || (high == 0xfe && low in 0x80..0xbf)
    }
}

/** 纯解析：请求行 / 头部 / 查询串。全部是可单测的纯函数。 */
object LanEditHttpParse {

    /** HTTP 允许的方法（其余一律 405；`TRACE` / `CONNECT` 在服务端没有意义，不列）。 */
    val ALLOWED_METHODS: Set<String> = setOf("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD")

    /**
     * 解析请求行 `METHOD SP request-target SP HTTP-version`。
     *
     * 严格按 RFC 9112 §3 收：**只允许单个空格分隔**（多空格/前导空格是请求走私的经典形状），
     * 三个部分都必须存在。方法必须是 [ALLOWED_METHODS] 里的，版本只收 HTTP/1.0 与 HTTP/1.1。
     */
    fun parseRequestLine(line: String): LanEditRequestLine {
        if (line.isEmpty()) {
            throw LanEditHttpException(LanEditHttpFailure.MALFORMED_REQUEST_LINE, "empty request line")
        }
        if (line.startsWith(" ") || line.endsWith(" ")) {
            throw LanEditHttpException(LanEditHttpFailure.MALFORMED_REQUEST_LINE, "leading/trailing space")
        }
        val parts = line.split(' ')
        if (parts.size != 3) {
            throw LanEditHttpException(
                LanEditHttpFailure.MALFORMED_REQUEST_LINE,
                "expected 3 parts, got ${parts.size}",
            )
        }
        val (method, target, version) = parts
        if (method.isEmpty() || target.isEmpty() || version.isEmpty()) {
            throw LanEditHttpException(LanEditHttpFailure.MALFORMED_REQUEST_LINE, "empty part")
        }
        if (!isToken(method)) {
            throw LanEditHttpException(LanEditHttpFailure.MALFORMED_REQUEST_LINE, "bad method token")
        }
        if (method !in ALLOWED_METHODS) {
            throw LanEditHttpException(LanEditHttpFailure.UNSUPPORTED_METHOD, method)
        }
        if (version != "HTTP/1.1" && version != "HTTP/1.0") {
            throw LanEditHttpException(LanEditHttpFailure.UNSUPPORTED_HTTP_VERSION, version)
        }
        // origin-form（/path）与 absolute-form（http://host/path，代理场景）都收；
        // authority-form（CONNECT）与 `*`（OPTIONS *）不收——本服务用不到，收进来只是攻击面。
        if (!target.startsWith("/") && !target.startsWith("http://") && !target.startsWith("https://")) {
            throw LanEditHttpException(LanEditHttpFailure.MALFORMED_REQUEST_LINE, "bad target form")
        }
        return LanEditRequestLine(method = method, target = target, version = version)
    }

    /**
     * 解析头部行。
     *
     * 规则（每条都对应一个真实攻击面）：
     * - `obs-fold`（以空格/Tab 续行）一律拒：折叠头是请求走私的经典载体；
     * - 头名必须是 token、后面必须紧跟 `:`；
     * - 同名头按 RFC 合并成 `a, b`，**但 `content-length` 重复直接拒**——
     *   两个不同长度的 Content-Length 是标准的走私形状；
     * - 条数与总字节数超限分别抛 [LanEditHttpFailure.TOO_MANY_HEADERS] /
     *   [LanEditHttpFailure.HEADER_TOO_LARGE]。
     */
    fun parseHeaders(lines: List<String>): Map<String, String> {
        val headers = LinkedHashMap<String, String>()
        var totalBytes = 0
        for (raw in lines) {
            if (raw.isEmpty()) continue
            totalBytes += raw.length
            if (totalBytes > LanEditHttpLimits.MAX_HEADER_BYTES) {
                throw LanEditHttpException(LanEditHttpFailure.HEADER_TOO_LARGE, "$totalBytes bytes")
            }
            if (raw[0] == ' ' || raw[0] == '\t') {
                throw LanEditHttpException(LanEditHttpFailure.INVALID_HEADER, "obs-fold")
            }
            val colon = raw.indexOf(':')
            if (colon <= 0) {
                throw LanEditHttpException(LanEditHttpFailure.INVALID_HEADER, "missing colon")
            }
            val name = raw.substring(0, colon)
            if (!isToken(name)) {
                throw LanEditHttpException(LanEditHttpFailure.INVALID_HEADER, "bad header name")
            }
            val value = raw.substring(colon + 1).trim()
            val key = name.lowercase()
            val existing = headers[key]
            if (existing == null) {
                headers[key] = value
                if (headers.size > LanEditHttpLimits.MAX_HEADER_COUNT) {
                    throw LanEditHttpException(LanEditHttpFailure.TOO_MANY_HEADERS, "${headers.size}")
                }
            } else if (key == "content-length") {
                throw LanEditHttpException(LanEditHttpFailure.INVALID_CONTENT_LENGTH, "duplicate")
            } else {
                headers[key] = "$existing, $value"
            }
        }
        return headers
    }

    /**
     * 校验 `Content-Length` 并返回要读的字节数。
     *
     * 本服务**不支持** `Transfer-Encoding: chunked`：分块编码要么自己写一遍解码器，
     * 要么就得信对端的长度声明——两个都不划算。明确回 400 比半信半疑地读要安全。
     */
    fun requireContentLength(headers: Map<String, String>): Long {
        if (headers.containsKey("transfer-encoding")) {
            throw LanEditHttpException(
                LanEditHttpFailure.INVALID_CONTENT_LENGTH,
                "transfer-encoding not supported",
            )
        }
        val raw = headers["content-length"] ?: return 0L
        // 头值两侧的 OWS 按 RFC 允许；真实路径上 parseHeaders 已经 trim 过，
        // 这里再 trim 一次是为了「直接构造 headers 的调用方」（测试 / 将来的调用点）也不会被坑。
        val value = raw.trim().toLongOrNull()
            ?: throw LanEditHttpException(LanEditHttpFailure.INVALID_CONTENT_LENGTH, raw)
        if (value < 0) {
            throw LanEditHttpException(LanEditHttpFailure.INVALID_CONTENT_LENGTH, raw)
        }
        if (value > LanEditHttpLimits.MAX_BODY_BYTES) {
            throw LanEditHttpException(LanEditHttpFailure.BODY_TOO_LARGE, "$value bytes")
        }
        return value
    }

    /** 把 request-target 拆成「已解码路径 + 查询串」。 */
    fun splitTarget(target: String): Pair<String, String> {
        // absolute-form：先剥掉 scheme://authority
        val normalized = if (target.startsWith("http://") || target.startsWith("https://")) {
            val afterScheme = target.substringAfter("://", "")
            val slash = afterScheme.indexOf('/')
            if (slash < 0) "/" else afterScheme.substring(slash)
        } else {
            target
        }
        val hash = normalized.indexOf('#')
        val withoutFragment = if (hash >= 0) normalized.substring(0, hash) else normalized
        val question = withoutFragment.indexOf('?')
        return if (question < 0) {
            decodePercent(withoutFragment) to ""
        } else {
            decodePercent(withoutFragment.substring(0, question)) to withoutFragment.substring(question + 1)
        }
    }

    /** 解析查询串：同名取第一个（与 Dart `Uri.queryParameters` 同口径），值做 `+`→空格与百分号解码。 */
    fun parseQuery(query: String): Map<String, String> {
        if (query.isEmpty()) return emptyMap()
        val result = LinkedHashMap<String, String>()
        for (pair in query.split('&')) {
            if (pair.isEmpty()) continue
            val eq = pair.indexOf('=')
            val rawName = if (eq < 0) pair else pair.substring(0, eq)
            val rawValue = if (eq < 0) "" else pair.substring(eq + 1)
            val name = decodeFormComponent(rawName)
            if (name.isEmpty() || result.containsKey(name)) continue
            result[name] = decodeFormComponent(rawValue)
        }
        return result
    }

    /**
     * 百分号解码，**按 UTF-8 还原字节**（不是把每个转义当独立字符）。
     *
     * 逐字节 `toChar()` 的写法对 ASCII 正确、对多字节就是错的：
     * `%E4%B8%AD` 是「中」的三个 UTF-8 字节，逐个当字符会解成三个拉丁字符，
     * 于是 `/api/v1/courses/%E4%B8%AD` 这条路径永远匹配不上。所以这里先还原成
     * 字节流再整体按 UTF-8 解码。
     *
     * 坏序列（`%` 后面不是两位十六进制）**原样保留**而不抛异常：
     * 路径里出现一个裸 `%` 不该把整个请求打成 400（对方只是想要 404）。
     */
    fun decodePercent(value: String): String {
        if (value.indexOf('%') < 0) return value
        val out = ByteArrayOutputStream(value.length)
        var i = 0
        while (i < value.length) {
            val c = value[i]
            if (c == '%' && i + 2 < value.length) {
                val hi = hexValue(value[i + 1])
                val lo = hexValue(value[i + 2])
                if (hi >= 0 && lo >= 0) {
                    out.write((hi shl 4) or lo)
                    i += 3
                    continue
                }
            }
            // 未转义的原字符：按 UTF-8 写回（输入里可能直接带中文）
            out.write(c.toString().toByteArray(Charsets.UTF_8))
            i++
        }
        return out.toByteArray().toString(Charsets.UTF_8)
    }

    /** 表单/查询串组件解码：`+` 当空格（路径里 `+` 是字面量，所以单独一个函数）。 */
    fun decodeFormComponent(value: String): String = decodePercent(value.replace('+', ' '))

    /** RFC 9110 token 字符集。 */
    fun isToken(value: String): Boolean {
        if (value.isEmpty()) return false
        for (c in value) {
            val ok = c in 'a'..'z' || c in 'A'..'Z' || c in '0'..'9' ||
                c == '!' || c == '#' || c == '$' || c == '%' || c == '&' || c == '\'' ||
                c == '*' || c == '+' || c == '-' || c == '.' || c == '^' || c == '_' ||
                c == '`' || c == '|' || c == '~'
            if (!ok) return false
        }
        return true
    }

    private fun hexValue(c: Char): Int = when (c) {
        in '0'..'9' -> c - '0'
        in 'a'..'f' -> c - 'a' + 10
        in 'A'..'F' -> c - 'A' + 10
        else -> -1
    }
}

/** HTTP 状态码 → reason phrase（Dart 由 `HttpResponse` 自动填，手写就得自己带）。 */
object LanEditHttpStatus {
    fun reason(status: Int): String = when (status) {
        200 -> "OK"
        201 -> "Created"
        204 -> "No Content"
        400 -> "Bad Request"
        401 -> "Unauthorized"
        403 -> "Forbidden"
        404 -> "Not Found"
        405 -> "Method Not Allowed"
        408 -> "Request Timeout"
        409 -> "Conflict"
        413 -> "Content Too Large"
        429 -> "Too Many Requests"
        431 -> "Request Header Fields Too Large"
        500 -> "Internal Server Error"
        501 -> "Not Implemented"
        503 -> "Service Unavailable"
        505 -> "HTTP Version Not Supported"
        else -> "Unknown"
    }

    /** 这些状态按 RFC 9110 **不得**带消息体。 */
    fun mustNotHaveBody(status: Int): Boolean = status == 204 || status == 304 || status in 100..199
}

/**
 * 一个已算好的响应。
 *
 * 只做「结构 → 字节」，不发 socket，因此能在 L0 里直接断言状态行 / 头部 / Content-Length。
 * 响应头固定带 `Connection: close`：本服务每个连接只处理一个请求（Dart 的 `HttpServer`
 * 会做 keep-alive，但那需要完整的连接复用状态机；局域网场景每次请求一个新连接完全够用，
 * 少一个状态机就少一类走私面）。
 */
class LanEditHttpResponse(
    val status: Int,
    val headers: List<Pair<String, String>> = emptyList(),
    val body: ByteArray = ByteArray(0),
) {
    fun toByteArray(): ByteArray {
        val hasBody = !LanEditHttpStatus.mustNotHaveBody(status) && body.isNotEmpty()
        val head = StringBuilder()
        head.append("HTTP/1.1 ").append(status).append(' ').append(LanEditHttpStatus.reason(status)).append("\r\n")
        for ((name, value) in headers) {
            head.append(name).append(": ").append(value).append("\r\n")
        }
        if (!LanEditHttpStatus.mustNotHaveBody(status)) {
            head.append("Content-Length: ").append(body.size).append("\r\n")
        }
        head.append("Connection: close\r\n")
        head.append("\r\n")
        val headBytes = head.toString().toByteArray(Charsets.UTF_8)
        if (!hasBody) return headBytes
        val out = ByteArray(headBytes.size + body.size)
        System.arraycopy(headBytes, 0, out, 0, headBytes.size)
        System.arraycopy(body, 0, out, headBytes.size, body.size)
        return out
    }

    companion object {
        /** JSON 响应；`Cache-Control: no-store` 与 Dart `_writeJson` 一致。 */
        fun json(status: Int, body: Any?): LanEditHttpResponse = LanEditHttpResponse(
            status = status,
            headers = listOf(
                "Content-Type" to "application/json; charset=utf-8",
                "Cache-Control" to "no-store",
            ),
            body = MiniJson.encode(body).toByteArray(Charsets.UTF_8),
        )

        /** 错误响应体形状与 Dart `_writeError` 完全一致：`{"error":…,"message":…}`。 */
        fun error(status: Int, error: String, message: String): LanEditHttpResponse =
            json(status, linkedMapOf<String, Any?>("error" to error, "message" to message))

        fun empty(status: Int): LanEditHttpResponse = LanEditHttpResponse(status = status)

        fun text(status: Int, text: String, contentType: String = "text/plain; charset=utf-8"): LanEditHttpResponse =
            LanEditHttpResponse(
                status = status,
                headers = listOf("Content-Type" to contentType),
                body = text.toByteArray(Charsets.UTF_8),
            )
    }
}
