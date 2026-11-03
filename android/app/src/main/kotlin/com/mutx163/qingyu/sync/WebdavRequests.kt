package com.mutx163.qingyu.sync

import java.io.ByteArrayOutputStream
import java.io.StringReader
import java.net.URI
import java.util.Base64
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element
import org.xml.sax.InputSource

/**
 * WebDAV 请求构造与响应解析（**纯逻辑，无 socket**）。
 *
 * 这是新增的传输层的一半：把「方法 / URL / 头 / 体」拼成可发出的形态，
 * 再把「状态码 / 头 / 体」解析成结构化数据。真正的 socket 收在
 * [WebdavHttpTransport]，两者分开是为了让 URL 拼接、百分号编解码、
 * PROPFIND XML 解析、ETag 归一化、重定向解析都能在无网络的 JVM 单测里钉住。
 *
 * 源：Dart 侧没有对等物——`lib/services/webdav_client_service.dart` 把收发交给
 * pub 包 `webdav_plus`（`WebdavClient`）。本文件是 `webdav_plus` 里
 * `_uriForPath` / `Resource.fromResponse` / 重定向处理那一小块的可验证重写，
 * 口径与 Dart 调用方（`getRemoteEtag`、`listHistoryBackupFilesResult`、
 * `_looksLikeUnsupportedLock`）对齐。
 *
 * 有意的偏离（都在 KDoc 里写明，不藏着）：
 * 1. **ETag 归一化**：PROPFIND 与 HEAD 两条路径都走 [normalizeEtag]（去掉 `W/`
 *    与包裹引号）。Dart 只从 PROPFIND 拿 ETag（GET 响应头拿不到），所以它
 *    从没被要求两路口径一致；本层要求一致，否则 `remoteMetaChanged` 会误判漂移。
 * 2. **URL 拼接**：baseUrl 末尾补 `/`，remotePath 去掉前导 `/` 后接上，
 *    路径段按 UTF-8 百分号编码。Dart 依赖 `webdav_plus` 的拼接，未逐字对拍。
 * 3. **写失败分类**：[classifyWebdavWriteFailure] 是新的——Dart 的
 *    `sanitizeWebdavErrorMessage` 把 404 映射成 `backup_not_found`，那对 PUT/MKCOL
 *    是错的（404 表示父目录不存在）。
 */

/** 单次响应体读取上限（超出即判 `invalid_response`，绝不返回半截快照）。 */
const val DEFAULT_MAX_RESPONSE_BYTES: Long = 32L * 1024 * 1024

/** 重定向最大跳数（含首次请求在内最多发 maxRedirects + 1 次）。 */
const val DEFAULT_MAX_REDIRECTS: Int = 5

/** 出站 User-Agent（诊断用，不含账号信息）。 */
const val WEBDAV_USER_AGENT: String = "mikcb-compose/1.0"

/** WebDAV 方法名（大写线格式原样）。 */
enum class WebdavMethod(val wire: String) {
    PROPFIND("PROPFIND"),
    PROPPATCH("PROPPATCH"),
    MKCOL("MKCOL"),
    PUT("PUT"),
    GET("GET"),
    HEAD("HEAD"),
    DELETE("DELETE"),
    LOCK("LOCK"),
    UNLOCK("UNLOCK"),
    OPTIONS("OPTIONS"),
}

/** PROPFIND 请求体（只问需要的属性）。 */
const val PROPFIND_REQUEST_BODY: String =
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
        "<d:propfind xmlns:d=\"DAV:\"><d:prop>" +
        "<d:resourcetype/><d:getcontentlength/><d:getetag/><d:getlastmodified/>" +
        "</d:prop></d:propfind>"

/** 一个 PROPFIND 条目。 */
data class WebdavResource(
    /** 响应里的 href 原文（未解码）。 */
    val href: String,
    /** href 的路径部分（去 query/fragment）。 */
    val path: String,
    /** 目录判定：`<resourcetype><collection/>` 或 href 以 `/` 结尾。 */
    val isDirectory: Boolean,
    val contentLength: Long? = null,
    /** 已归一化（去 `W/` 与引号）。 */
    val etag: String? = null,
    val lastModified: String? = null,
) {
    /** href 末段（UTF-8 百分号解码后的名字；目录取最后一段而非空串）。 */
    val name: String
        get() = webdavResourceName(path)
}

/** 远端路径 → 末段名字（UTF-8 百分号解码）。目录路径取最后一段。 */
fun webdavResourceName(path: String): String {
    val trimmed = path.trimEnd('/')
    val slash = trimmed.lastIndexOf('/')
    val raw = if (slash >= 0) trimmed.substring(slash + 1) else trimmed
    return percentDecode(raw)
}

/** 响应头（键统一小写，JDK 的 `headerFields` 可能带 null 值）。 */
class WebdavResponseHeaders(private val map: Map<String, List<String>>) {
    fun first(name: String): String? = map[name.lowercase()]?.firstOrNull()

    fun all(name: String): List<String> = map[name.lowercase()] ?: emptyList()

    fun asMap(): Map<String, List<String>> = map

    companion object {
        val EMPTY = WebdavResponseHeaders(emptyMap())

        fun from(raw: Map<String, List<String>>?): WebdavResponseHeaders {
            if (raw == null) return EMPTY
            val out = linkedMapOf<String, List<String>>()
            for (entry in raw.entries) {
                val key = entry.key ?: continue
                out[key.lowercase()] = entry.value.filterNotNull()
            }
            return WebdavResponseHeaders(out)
        }
    }
}

// ---------- URL / 路径 ----------

/**
 * baseUrl + remotePath 拼成可发出的绝对 URL。
 * remotePath 为空时返回 baseUrl 本身；baseUrl 末尾补 `/`。
 */
fun joinWebdavUrl(baseUrl: String, remotePath: String): String {
    val base = baseUrl.trim()
    if (remotePath.isEmpty()) return base
    val normalizedBase = if (base.endsWith("/")) base else "$base/"
    return normalizedBase + encodeWebdavPath(remotePath.trimStart('/'))
}

/**
 * 路径百分号编码：保留 `/` 与 unreserved（`A-Za-z0-9-._~`），其余按 UTF-8 逐字节编码。
 * 中文目录名与空格必须编码，否则真实服务器上直接 400。
 */
fun encodeWebdavPath(path: String): String {
    val hex = "0123456789ABCDEF"
    val sb = StringBuilder(path.length)
    for (b in path.toByteArray(Charsets.UTF_8)) {
        val value = b.toInt() and 0xFF
        val ch = value.toChar()
        when {
            ch == '/' -> sb.append('/')
            ch in 'A'..'Z' || ch in 'a'..'z' || ch in '0'..'9' -> sb.append(ch)
            ch == '-' || ch == '_' || ch == '.' || ch == '~' -> sb.append(ch)
            else -> sb.append('%').append(hex[(value shr 4) and 0xF]).append(hex[value and 0xF])
        }
    }
    return sb.toString()
}

/**
 * 路径百分号解码（UTF-8）。
 * 不用 `URLDecoder`：它把 `+` 当空格，在路径上是错的。
 */
fun percentDecode(raw: String): String {
    if (!raw.contains('%')) return raw
    val out = ByteArrayOutputStream(raw.length)
    var i = 0
    while (i < raw.length) {
        val c = raw[i]
        if (c == '%' && i + 3 <= raw.length) {
            val value = raw.substring(i + 1, i + 3).toIntOrNull(16)
            if (value != null) {
                out.write(value)
                i += 3
                continue
            }
        }
        out.write(c.toString().toByteArray(Charsets.UTF_8))
        i++
    }
    return String(out.toByteArray(), Charsets.UTF_8)
}

/** `Basic base64(user:password)`（UTF-8，与 Dart 侧 http Basic 头一致）。 */
fun basicAuthorizationHeader(username: String, password: String): String =
    "Basic " + Base64.getEncoder().encodeToString("$username:$password".toByteArray(Charsets.UTF_8))

// ---------- 状态码 ----------

fun isRedirectStatus(statusCode: Int?): Boolean =
    statusCode == 301 || statusCode == 302 || statusCode == 303 || statusCode == 307 || statusCode == 308

fun isSuccessStatus(statusCode: Int?): Boolean = statusCode != null && statusCode in 200..299

/**
 * 重定向目标解析；`Location` 为空、相对解析失败、或落到非 http(s) 协议时返回 null
 * （调用方把 3xx 原样当失败处理，绝不跟随到 `ftp:` / `file:` 这类协议）。
 */
fun resolveRedirectUrl(currentUrl: String, location: String?): String? {
    val raw = location?.trim()
    if (raw.isNullOrEmpty()) return null
    return try {
        val resolved = URI(currentUrl).resolve(raw)
        val scheme = resolved.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") null else resolved.toString()
    } catch (_: Exception) {
        null
    }
}

// ---------- ETag / 锁 ----------

/**
 * ETag 归一化：去掉弱标记 `W/` 与包裹引号，空串归 null。
 * PROPFIND 与 HEAD 两条路径共用，保证 `remoteMetaChanged` 的 ETag 比对不会
 * 因为一个带引号一个不带而误判漂移。
 */
fun normalizeEtag(raw: String?): String? {
    var value = raw?.trim() ?: return null
    if (value.isEmpty()) return null
    if (value.length >= 2 && (value.startsWith("W/") || value.startsWith("w/"))) {
        value = value.substring(2).trim()
    }
    if (value.length >= 2 && value.startsWith("\"") && value.endsWith("\"")) {
        value = value.substring(1, value.length - 1).trim()
    }
    return value.ifEmpty { null }
}

/** `Lock-Token: <opaquelocktoken:...>` → 去掉尖括号的 token；空返回 null。 */
fun parseLockToken(headerValue: String?): String? {
    val raw = headerValue?.trim() ?: return null
    if (raw.isEmpty()) return null
    if (raw.startsWith("<") && raw.endsWith(">")) {
        return raw.substring(1, raw.length - 1).trim().ifEmpty { null }
    }
    return raw
}

/** LOCK 请求体（独占写锁）。 */
fun lockRequestBody(timeoutSeconds: Int, owner: String = "mikcb"): String =
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
        "<d:lockinfo xmlns:d=\"DAV:\"><d:lockscope><d:exclusive/></d:lockscope>" +
        "<d:locktype><d:write/></d:locktype>" +
        "<d:owner><d:href>$owner</d:href></d:owner></d:lockinfo>"

/** `If: (<token>)` 头值（Dart `putBytes` 的 `If` 原样）。 */
fun lockTokenIfHeader(lockToken: String): String = "(<$lockToken>)"

// ---------- 写失败分类 ----------

/**
 * 写操作（PUT / MKCOL / DELETE / LOCK / UNLOCK）失败 → 安全短码。
 *
 * 与读路径的区别只有一处、但很关键：**404 不映射成 `backup_not_found`**——
 * 写时的 404 表示父目录不存在（`invalid_response`），把它当「备份不存在」
 * 会让 UI 说错话。其余状态码与 [sanitizeWebdavErrorMessage] 同口径。
 */
fun classifyWebdavWriteFailure(
    statusCode: Int?,
    kind: TransportKind?,
    message: String,
): String {
    when (kind) {
        TransportKind.TIMEOUT -> return "connection_timeout"
        TransportKind.SOCKET -> return "connection_failed"
        TransportKind.HANDSHAKE -> return "certificate_error"
        TransportKind.FORMAT -> return "invalid_response"
        null -> Unit
    }
    if (statusCode != null) {
        return when (statusCode) {
            401 -> "auth_failed"
            403 -> "access_denied"
            404, 409, 412, 423, 507 -> "invalid_response"
            // Dart 写路径走 `sanitizeWebdavErrorMessage`：除 401/403/404/5xx 外，
            // 其余任何状态（含 405/422/429/3xx）一律 `invalid_response`，
            // 不能落成泛化的 `sync_failed`。
            else -> "invalid_response"
        }
    }
    // 无状态码的文本分支：只认关键词，绝不透出原文（Dart sanitize 同口径）。
    val lower = message.lowercase()
    if (lower.contains("certificate") || lower.contains("handshake")) return "certificate_error"
    if (lower.contains("timeout")) return "connection_timeout"
    if (lower.contains("connection") || lower.contains("socket") || lower.contains("network")) {
        return "connection_failed"
    }
    return "sync_failed"
}

// ---------- PROPFIND 解析 ----------

/**
 * 解析 `207 Multi-Status` 的 XML。
 * @throws Exception XML 不合法时抛出（调用方转 `invalid_response`）。
 */
fun parsePropfindResources(xml: String): List<WebdavResource> {
    val factory = DocumentBuilderFactory.newInstance()
    factory.isNamespaceAware = true
    factory.isExpandEntityReferences = false
    factory.setFeatureQuietly("http://apache.org/xml/features/disallow-doctype-decl", true)
    factory.setFeatureQuietly("http://xml.org/sax/features/external-general-entities", false)
    factory.setFeatureQuietly("http://xml.org/sax/features/external-parameter-entities", false)
    val builder = factory.newDocumentBuilder()
    // 不解析外部实体（防 XXE）；`resolveEntity` 的返回类型是 InputSource!。
    builder.setEntityResolver { _, _ -> InputSource(StringReader("")) }
    val document = builder.parse(InputSource(StringReader(xml)))

    val responseNodes = document.getElementsByTagNameNS("*", "response")
    val out = ArrayList<WebdavResource>(responseNodes.length)
    for (i in 0 until responseNodes.length) {
        val element = responseNodes.item(i) as? Element ?: continue
        val href = element.firstChildText("href") ?: continue
        val path = hrefPath(href)
        val isCollection = element.getElementsByTagNameNS("*", "collection").length > 0
        out.add(
            WebdavResource(
                href = href,
                path = path,
                isDirectory = isCollection || path.endsWith("/"),
                contentLength = element.firstChildText("getcontentlength")?.trim()?.toLongOrNull(),
                etag = normalizeEtag(element.firstChildText("getetag")),
                lastModified = element.firstChildText("getlastmodified")?.trim()?.takeIf { it.isNotEmpty() },
            ),
        )
    }
    return out
}

/** href → 路径（绝对 URL 取 path，去 query/fragment）。 */
fun hrefPath(href: String): String {
    val trimmed = href.trim()
    if (trimmed.isEmpty()) return ""
    return try {
        val uri = URI(trimmed)
        if (uri.scheme != null) uri.path ?: "" else trimmed.substringBefore('?').substringBefore('#')
    } catch (_: Exception) {
        trimmed.substringBefore('?').substringBefore('#')
    }
}

/** 历史备份目录 listing 的文件名（Dart `listHistoryBackupFilesResult` 原样口径）。 */
fun historyFileNamesFromResources(resources: List<WebdavResource>): List<String> =
    resources.filter { !it.isDirectory }.map { it.name }.filter { it.endsWith(".mikcb") }

private fun Element.firstChildText(localName: String): String? {
    val nodes = getElementsByTagNameNS("*", localName)
    for (i in 0 until nodes.length) {
        val text = nodes.item(i)?.textContent
        if (text != null && text.isNotBlank()) return text
    }
    return null
}

private fun DocumentBuilderFactory.setFeatureQuietly(name: String, value: Boolean) {
    try {
        setFeature(name, value)
    } catch (_: Exception) {
        // 某些实现不支持该 feature；解析仍可继续（我们只解析本地可信文本）。
    }
}
