package com.mutx163.qingyu.pages.import.warehouse

/**
 * 导入日志的**脱敏规则**（纯 Kotlin，无副作用，可单测）。
 *
 * ## 为什么单独一个文件
 *
 * 「日志里不能有密码」这类约束写进 `Log.w` 的调用点是拦不住的：下一个接钩子的人
 * 换个字段名就漏了。所以做成**入口就脱敏**的一层——`WarehouseImportLogBuffer.record`
 * 在入队前跑一遍 [redact]，Buffer 里从头到尾没有明文；导出/写盘再跑一遍（幂等）当第二道。
 *
 * ## 规则（与派单逐条对应）
 *
 * | 输入 | 输出 |
 * |---|---|
 * | 键含 `password` / `pwd` / `passwd` / `口令` | 值 → `***` |
 * | 键含 `account` / `user` / `login` / `phone` / `mobile` / `tel` / `账号` / `手机号` | 值 ≥6 位保留首尾（`13800138000` → `1**********0`）；≤5 位整遮成 `***` |
 * | 键是 `Cookie` / `Set-Cookie` | `cookie(n=<条数>)`，**不记任何 cookie 值** |
 * | 任何值里的 URL | 只留 `scheme://host`（路径、查询串、userinfo 全丢），并另记 `endpoint`（`login` / `timetable` / `other`） |
 * | 任何值里的 `token=` / `JSESSIONID=` 这类内联凭据 | `token=***` |
 *
 * ## 已知边界（刻意的，别当 bug 修）
 *
 * - 只认**键名**判账号/手机号：值里散落的 11 位数字（比如课表节次里的 `13800138000`
 *   恰好是课程号）不会被动。反过来 `userAgent` 这种含 `user` 的键会被当账号遮掉首尾——
 *   少见、且遮掉比漏掉安全。
 * - 只认 `http` / `https`：别的 scheme（`file:` / `content:`）原样留着，它们不含主机凭据。
 */
object WarehouseLogRedaction {
    /** 整段遮掉的固定形态。 */
    const val MASK = "***"

    /** 追加在 fields 里的「接口类别」键（英文；不记 URL 原文）。 */
    const val ENDPOINT_FIELD = "endpoint"

    const val ENDPOINT_LOGIN = "login"
    const val ENDPOINT_TIMETABLE = "timetable"
    const val ENDPOINT_OTHER = "other"

    private val PASSWORD_TOKENS = listOf("password", "passwd", "pwd", "口令")
    private val COOKIE_TOKENS = listOf("cookie")
    private val CREDENTIAL_TOKENS = listOf(
        "account", "user", "login", "phone", "mobile", "tel", "账号", "手机号",
    )
    private val LOGIN_PATH_TOKENS = listOf("login", "signin", "sign_in", "sso", "cas", "auth")
    private val TIMETABLE_PATH_TOKENS = listOf("xskb", "timetable", "kbcx", "course")

    /**
     * 内联凭据 `k=v`（不在 URL 里的那些）。
     *
     * 长 token 必须排在短 token 前面（`authorization` 先于 `auth`），否则
     * `authorization: x` 会被切成 `auth` + 剩下的 `orization: x`。
     */
    private val INLINE_SECRET_REGEX = Regex(
        "(?i)\\b(password|passwd|pwd|authorization|jsessionid|sessionid|session_id|" +
            "token|secret|cookie|auth)\\s*[=:]\\s*([^\\s&;,\"'|]+)",
    )

    private val URL_REGEX = Regex("(?i)\\bhttps?://[^\\s\"'<>|,;)]+")

    /** 脱敏一整行 fields（键名判类别；值就地改写；需要时补 `endpoint`）。 */
    fun redact(fields: Map<String, String>): Map<String, String> {
        val out = LinkedHashMap<String, String>(fields.size + 1)
        var endpoint: String? = null
        for ((rawKey, rawValue) in fields) {
            val key = rawKey.trim()
            val lowered = key.lowercase()
            when {
                lowered.containsAny(PASSWORD_TOKENS) -> out[key] = MASK
                lowered.containsAny(COOKIE_TOKENS) -> out[key] = "cookie(n=${cookieCount(rawValue)})"
                lowered.containsAny(CREDENTIAL_TOKENS) -> out[key] = maskCredential(rawValue)
                else -> {
                    URL_REGEX.find(rawValue)?.let { match ->
                        if (endpoint == null) endpoint = endpointLabel(match.value)
                    }
                    out[key] = redactText(rawValue)
                }
            }
        }
        // 「另记 endpoint 枚举标签，不记原文」：值里出现过 URL 就补一个类别，方便看
        // 「这次卡在登录还是课表接口」，而不必把地址写下来。
        endpoint?.let { label ->
            if (!out.containsKey(ENDPOINT_FIELD)) out[ENDPOINT_FIELD] = label
        }
        return out
    }

    /** 脱敏一段自由文本（URL 只留 host + 内联凭据遮掉）。 */
    fun redactText(text: String): String {
        if (text.isEmpty()) return text
        var out = URL_REGEX.replace(text) { hostOnly(it.value) }
        out = INLINE_SECRET_REGEX.replace(out) { match ->
            "${match.groupValues[1]}=$MASK"
        }
        return out
    }

    /** URL → `scheme://host`（解析不了就整段遮掉，宁可少信息也不留原文）。 */
    fun hostOnly(url: String): String {
        val parts = splitUrl(url) ?: return MASK
        return "${parts.first}://${parts.second}"
    }

    /** URL 的接口类别：`login` / `timetable` / `other`（看**路径**，不看主机）。 */
    fun endpointLabel(url: String): String {
        val parts = splitUrl(url) ?: return ENDPOINT_OTHER
        val tail = parts.third.lowercase()
        return when {
            tail.containsAny(LOGIN_PATH_TOKENS) -> ENDPOINT_LOGIN
            tail.containsAny(TIMETABLE_PATH_TOKENS) -> ENDPOINT_TIMETABLE
            else -> ENDPOINT_OTHER
        }
    }

    /** 账号 / 手机号：≥6 位保留首尾，≤5 位整遮。 */
    fun maskCredential(value: String): String {
        val text = value.trim()
        if (text.length <= MIN_MASKABLE_CREDENTIAL_LENGTH) return MASK
        return text.first() + "*".repeat(text.length - 2) + text.last()
    }

    /** `Cookie` 头里的条数（`a=1; b=2` → 2；`JSESSIONID=x` → 1）。 */
    fun cookieCount(value: String): Int = value.split(';').count { it.isNotBlank() }

    /**
     * 拆 `scheme` / `authority(host[:port])` / `路径+查询+片段`。
     *
     * @return null = 不是能拆的 http(s) 地址
     */
    private fun splitUrl(url: String): Triple<String, String, String>? {
        val schemeEnd = url.indexOf("://")
        if (schemeEnd <= 0) return null
        val scheme = url.substring(0, schemeEnd)
        val afterScheme = url.substring(schemeEnd + 3)
        if (afterScheme.isEmpty()) return null
        var end = afterScheme.length
        for (index in afterScheme.indices) {
            val ch = afterScheme[index]
            if (ch == '/' || ch == '?' || ch == '#') {
                end = index
                break
            }
        }
        var authority = afterScheme.substring(0, end)
        // `https://user:pass@host/x`：userinfo 也是凭据，一并丢掉。
        val at = authority.lastIndexOf('@')
        if (at >= 0) authority = authority.substring(at + 1)
        if (authority.isEmpty()) return null
        return Triple(scheme, authority, afterScheme.substring(end))
    }

    private fun String.containsAny(tokens: List<String>): Boolean = tokens.any { contains(it) }

    private const val MIN_MASKABLE_CREDENTIAL_LENGTH = 6
}
