package com.mutx163.qingyu.sync

/**
 * 失败归一化 / 传输分类 / 备份索引恢复纯逻辑。
 *
 * 源：
 * - lib/services/webdav_error_message.dart（`sanitizeWebdavErrorMessage`、
 *   allowlist `_safeSyncErrorCodes`）；
 * - lib/services/webdav_client_service.dart（`classifyGetBytesFailure`、
 *   `classifyHistoryListFailure`、`_looksLikeUnsupportedLock`、结果类型与
 *   `defaultOperationTimeout` 见 WebdavPaths）；
 * - lib/services/webdav_sync_service.dart（`decideWebdavBackupIndexRecovery`）。
 *
 * 不做网络收发：异常只以「种类 + 状态码 + 文本」输入，不触碰真实异常类型，
 * 文本外的 URL/凭据永不透出（Dart 同口径）。
 */

// ---------- 结果类型（Dart 结果类原样，无客户端依赖） ----------

data class GetBytesResult(
    val bytes: ByteArray?,
    val isFailed: Boolean,
    val errorMessage: String?,
) {
    companion object {
        fun ok(bytes: ByteArray) = GetBytesResult(bytes, false, null)
        fun notFound() = GetBytesResult(null, false, null)
        fun failed(message: String) = GetBytesResult(null, true, message)
    }

    val isNotFound: Boolean get() = !isFailed && bytes == null
    val isEmpty: Boolean get() = bytes?.isEmpty() ?: true
}

data class HistoryListResult(
    val fileNames: List<String> = emptyList(),
    val isFailed: Boolean = false,
    val isNotFound: Boolean = false,
    val errorMessage: String? = null,
) {
    companion object {
        fun ok(fileNames: List<String>) = HistoryListResult(fileNames = fileNames)
        fun notFound() = HistoryListResult(isNotFound = true)
        fun failed(message: String) = HistoryListResult(isFailed = true, errorMessage = message)
    }

    val isEmpty: Boolean get() = fileNames.isEmpty()
}

data class LockResult(
    val lockToken: String? = null,
    val isUnsupported: Boolean = false,
    val isFailed: Boolean = false,
    val errorMessage: String? = null,
) {
    companion object {
        fun acquired(lockToken: String) = LockResult(lockToken = lockToken)
        fun unsupported() = LockResult(isUnsupported = true)
        fun failed(message: String) = LockResult(isFailed = true, errorMessage = message)
    }
}

// ---------- 备份索引恢复 ----------

enum class BackupIndexRecoveryAction {
    USE_INDEX,
    EMPTY,
    REBUILD_FROM_LISTING,
    FAILED,
}

/**
 * 索引恢复决策（Dart `decideWebdavBackupIndexRecovery` 原样）。
 * 空远端与不可用远端不合并：瞬时错误不得用空索引覆盖远端好索引。
 */
fun decideBackupIndexRecovery(
    index: GetBytesResult,
    listing: HistoryListResult,
): BackupIndexRecoveryAction {
    if (index.isFailed) {
        if (listing.isFailed || listing.isNotFound || listing.fileNames.isEmpty()) {
            return BackupIndexRecoveryAction.FAILED
        }
        return BackupIndexRecoveryAction.REBUILD_FROM_LISTING
    }
    if (!index.isNotFound) {
        return BackupIndexRecoveryAction.USE_INDEX
    }
    if (listing.isFailed) {
        return BackupIndexRecoveryAction.FAILED
    }
    return if (listing.fileNames.isEmpty()) {
        BackupIndexRecoveryAction.EMPTY
    } else {
        BackupIndexRecoveryAction.REBUILD_FROM_LISTING
    }
}

// ---------- 传输失败分类 ----------

/** 调用方归纳的异常种类（替代 Dart 的 Socket/Handshake/Format/Timeout 类型分支）。 */
enum class TransportKind {
    TIMEOUT,
    SOCKET,
    HANDSHAKE,
    FORMAT,
}

/**
 * get 失败分类（Dart `classifyGetBytesFailure` 原样）。
 * 返回干净错误码（可进本地化表），不透出原文。
 */
fun classifyGetBytesFailure(
    statusCode: Int?,
    kind: TransportKind?,
    message: String,
): GetBytesResult {
    when (kind) {
        TransportKind.TIMEOUT -> return GetBytesResult.failed("connection_timeout")
        TransportKind.SOCKET -> return GetBytesResult.failed("connection_failed")
        TransportKind.HANDSHAKE -> return GetBytesResult.failed("certificate_error")
        TransportKind.FORMAT -> return GetBytesResult.failed("invalid_response")
        null -> Unit
    }
    if (statusCode != null) {
        return when (statusCode) {
            401 -> GetBytesResult.failed("auth_failed")
            403 -> GetBytesResult.failed("access_denied")
            404 -> GetBytesResult.notFound()
            else -> if (statusCode >= 500) {
                GetBytesResult.failed("invalid_response")
            } else {
                GetBytesResult.failed("invalid_response")
            }
        }
    }
    val lower = message.lowercase()
    // Dart webdav_client_service.dart 的文本状态码正则（含 HTTP/1.1 线格式）。
    val statusMatch = Regex(
        """\b(?:https?\s*/\s*\d+(?:\.\d+)?\s+|http\s+|statuscode\s*[=:]\s*)(\d{3})\b""",
        RegexOption.IGNORE_CASE,
    ).find(lower)
    val textualStatusCode = statusMatch?.groupValues?.getOrNull(1)?.toIntOrNull()
    if (textualStatusCode != null) {
        return when (textualStatusCode) {
            401 -> GetBytesResult.failed("auth_failed")
            403 -> GetBytesResult.failed("access_denied")
            404 -> GetBytesResult.notFound()
            else -> if (textualStatusCode >= 500 || textualStatusCode >= 400) {
                GetBytesResult.failed("invalid_response")
            } else {
                GetBytesResult.failed("sync_failed")
            }
        }
    }
    // 仅显式缺文件表述才算 notFound（Dart 原文：通用服务端文本不可覆盖 failed）。
    val looksMissing =
        Regex("""\b404\s+not[ _-]?found\b""").containsMatchIn(lower) ||
            Regex("""\b(?:file|resource|path|collection)\s+not[ _-]?found\b""")
                .containsMatchIn(lower) ||
            lower.contains("no such file or directory")
    if (looksMissing) {
        return GetBytesResult.notFound()
    }
    if (lower.contains("certificate") || lower.contains("handshake")) {
        return GetBytesResult.failed("certificate_error")
    }
    if (lower.contains("timeout")) {
        return GetBytesResult.failed("connection_timeout")
    }
    if (lower.contains("connection") || lower.contains("socket") || lower.contains("network")) {
        return GetBytesResult.failed("connection_failed")
    }
    return GetBytesResult.failed("sync_failed")
}

/** history 目录 listing 失败分类（Dart `classifyHistoryListFailure` 原样）。 */
fun classifyHistoryListFailure(
    statusCode: Int?,
    kind: TransportKind?,
    message: String,
): HistoryListResult {
    val classified = classifyGetBytesFailure(statusCode, kind, message)
    if (classified.isNotFound) {
        return HistoryListResult.notFound()
    }
    return HistoryListResult.failed(classified.errorMessage ?: "sync_failed")
}

/** LOCK 不被支持的文本特征（Dart `_looksLikeUnsupportedLock` 原样）。 */
fun looksLikeUnsupportedLock(message: String): Boolean {
    val lower = message.lowercase()
    return lower.contains("cannot be locked") ||
        lower.contains("can not be locked") ||
        lower.contains("lock not supported") ||
        lower.contains("unsupported lock") ||
        lower.contains("lock method not allowed")
}

// ---------- 错误文案归一化 ----------

/** sanitize 输入的异常种类（替代 Dart 的 Socket/Handshake 等类型分支）。 */
enum class ErrorKind {
    SOCKET,
    HANDSHAKE,
    FORMAT,
    TIMEOUT,
    STATE,
    HTTP,
    OTHER,
}

private val safeSyncErrorCodes = setOf(
    "auth_failed",
    "access_denied",
    "certificate_error",
    "connection_timeout",
    "connection_failed",
    "network_error",
    "invalid_response",
    "local_changes_pending_sync",
    "missing_credentials",
    "backup_not_found",
    "missing_backup_snapshot",
    "cannot_delete_current_backup",
    "provider_not_ready",
    "insecure_url_blocked",
)

/**
 * WebDAV/网络异常 → 安全短码（Dart `sanitizeWebdavErrorMessage` 原样）。
 * @param kind 调用方归纳的异常种类；STATE 时 [stateMessage] 命中 allowlist 才透出。
 * @param statusCode 已知 HTTP 状态（WebDAVException.statusCode 等价）。
 * @param text 异常文本（含 URL 时只做关键词匹配，永不原文返回）。
 */
fun sanitizeWebdavErrorMessage(
    kind: ErrorKind,
    stateMessage: String?,
    statusCode: Int?,
    text: String,
): String {
    when (kind) {
        ErrorKind.SOCKET -> return "connection_failed"
        ErrorKind.HANDSHAKE -> return "certificate_error"
        ErrorKind.FORMAT -> return "invalid_response"
        ErrorKind.TIMEOUT -> return "connection_timeout"
        ErrorKind.STATE -> {
            if (stateMessage != null && safeSyncErrorCodes.contains(stateMessage)) {
                return stateMessage
            }
        }
        ErrorKind.HTTP, ErrorKind.OTHER -> Unit
    }
    if (statusCode != null) {
        return when (statusCode) {
            401 -> "auth_failed"
            403 -> "access_denied"
            404 -> "backup_not_found"
            else -> "invalid_response"
        }
    }
    val lower = text.lowercase()
    // Dart webdav_error_message.dart 的文本状态码正则（含 failed: 变体）。
    val statusMatch = Regex(
        """\b(?:https?\s*/\s*\d+(?:\.\d+)?\s+|http\s+|statuscode\s*[=:]\s*|failed\s*:\s*)(\d{3})\b""",
        RegexOption.IGNORE_CASE,
    ).find(lower)
    val textualStatusCode = statusMatch?.groupValues?.getOrNull(1)?.toIntOrNull()
    if (textualStatusCode != null) {
        return when (textualStatusCode) {
            401 -> "auth_failed"
            403 -> "access_denied"
            404 -> "backup_not_found"
            else -> "invalid_response"
        }
    }
    if (lower.contains("certificate") || lower.contains("handshake")) {
        return "certificate_error"
    }
    if (lower.contains("timeout")) {
        return "connection_timeout"
    }
    if (lower.contains("connection") || lower.contains("socket") || lower.contains("network")) {
        return "connection_failed"
    }
    return "sync_failed"
}
