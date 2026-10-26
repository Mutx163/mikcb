package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 错误归一化 / 传输失败分类 / 备份索引恢复单测。
 *
 * 抄录：
 * - test/services/webdav_error_message_test.dart（状态码行识别、allowlist、密钥不外泄）；
 * - test/services/webdav_client_service_test.dart（404 文本判定、嵌入数字不误判）；
 * - test/services/webdav_sync_service_test.dart（索引恢复四分支、listing 分类）。
 */
class WebdavFailuresTest {

    // ---------- sanitize ----------

    @Test
    fun `sanitize maps auth failures without leaking url`() {
        val message = sanitizeWebdavErrorMessage(
            kind = ErrorKind.HTTP,
            stateMessage = null,
            statusCode = null,
            text = "GET https://dav.example.com/secret failed: 401",
        )
        assertEquals("auth_failed", message)
        assertFalse(message.contains("dav.example.com"))
    }

    @Test
    fun `sanitize maps socket and certificate kinds`() {
        assertEquals(
            "connection_failed",
            sanitizeWebdavErrorMessage(ErrorKind.SOCKET, null, null, "Failed host lookup"),
        )
        assertEquals(
            "certificate_error",
            sanitizeWebdavErrorMessage(ErrorKind.HANDSHAKE, null, null, "CERT_INVALID"),
        )
    }

    @Test
    fun `sanitize maps format and timeout kinds`() {
        assertEquals(
            "invalid_response",
            sanitizeWebdavErrorMessage(ErrorKind.FORMAT, null, null, "bad json"),
        )
        assertEquals(
            "connection_timeout",
            sanitizeWebdavErrorMessage(ErrorKind.TIMEOUT, null, null, "webdav_operation_timeout"),
        )
    }

    @Test
    fun `sanitize does not infer status from embedded digits`() {
        for (value in listOf("request /archives/4040 failed", "failed to read lesson-404.json")) {
            assertEquals(
                "sync_failed",
                sanitizeWebdavErrorMessage(ErrorKind.STATE, "other_code", null, value),
            )
        }
    }

    @Test
    fun `sanitize maps generic http statuses safely`() {
        assertEquals("invalid_response", sanitizeWebdavErrorMessage(ErrorKind.OTHER, null, 429, "x"))
        assertEquals("invalid_response", sanitizeWebdavErrorMessage(ErrorKind.OTHER, null, 500, "x"))
        assertEquals("auth_failed", sanitizeWebdavErrorMessage(ErrorKind.HTTP, null, null, "HTTP/1.1 401 Unauthorized"))
        assertEquals("access_denied", sanitizeWebdavErrorMessage(ErrorKind.HTTP, null, null, "HTTP/1.1 403 Forbidden"))
    }

    @Test
    fun `sanitize keeps only allowlisted state codes`() {
        val allowlisted = listOf(
            "auth_failed", "access_denied", "certificate_error", "connection_timeout",
            "connection_failed", "network_error", "invalid_response",
            "local_changes_pending_sync", "missing_credentials", "backup_not_found",
            "missing_backup_snapshot", "cannot_delete_current_backup", "provider_not_ready",
            "insecure_url_blocked",
        )
        for (code in allowlisted) {
            assertEquals(
                code,
                sanitizeWebdavErrorMessage(ErrorKind.STATE, code, null, "StateError: $code"),
            )
        }
    }

    @Test
    fun `sanitize rejects arbitrary state error details`() {
        val secret = "https://dav.example.com/path Authorization=Bearer secret"
        val message = sanitizeWebdavErrorMessage(
            ErrorKind.STATE,
            "remote_backup_invalid: $secret",
            null,
            "remote_backup_invalid: $secret",
        )
        assertEquals("sync_failed", message)
        assertFalse(message.contains("dav.example.com"))
        assertFalse(message.contains("secret"))
    }

    @Test
    fun `sanitize uses direct status code first`() {
        assertEquals("auth_failed", sanitizeWebdavErrorMessage(ErrorKind.HTTP, null, 401, "anything"))
        assertEquals("access_denied", sanitizeWebdavErrorMessage(ErrorKind.HTTP, null, 403, "anything"))
        assertEquals("backup_not_found", sanitizeWebdavErrorMessage(ErrorKind.HTTP, null, 404, "anything"))
        assertEquals("invalid_response", sanitizeWebdavErrorMessage(ErrorKind.HTTP, null, 503, "anything"))
    }

    // ---------- classifyGetBytesFailure ----------

    @Test
    fun `classify maps timeout socket handshake format`() {
        assertEquals(
            "connection_timeout",
            classifyGetBytesFailure(null, TransportKind.TIMEOUT, "t").errorMessage,
        )
        assertEquals(
            "connection_failed",
            classifyGetBytesFailure(null, TransportKind.SOCKET, "s").errorMessage,
        )
        assertEquals(
            "certificate_error",
            classifyGetBytesFailure(null, TransportKind.HANDSHAKE, "h").errorMessage,
        )
        assertEquals(
            "invalid_response",
            classifyGetBytesFailure(null, TransportKind.FORMAT, "f").errorMessage,
        )
    }

    @Test
    fun `classify maps missing file text to notFound`() {
        val result = classifyGetBytesFailure(null, null, "404 Not Found")
        assertFalse(result.isFailed)
        assertTrue(result.isNotFound)
    }

    @Test
    fun `classify does not treat embedded 404 as notFound`() {
        for (message in listOf("request failed for /archives/4040", "failed to read lesson-404.json")) {
            val result = classifyGetBytesFailure(null, null, message)
            assertTrue(result.isFailed)
            assertEquals("sync_failed", result.errorMessage)
        }
    }

    @Test
    fun `classify maps http status messages safely`() {
        val cases = mapOf(
            "HTTP 400 Bad Request" to "invalid_response",
            "HTTP 409 Conflict" to "invalid_response",
            "HTTP 429 Too Many Requests" to "invalid_response",
            "HTTP 500 Internal Server Error" to "invalid_response",
            "HTTP/1.1 401 Unauthorized" to "auth_failed",
            "HTTP/2 403 Forbidden" to "access_denied",
        )
        for ((text, expected) in cases) {
            val result = classifyGetBytesFailure(null, null, text)
            assertTrue(result.isFailed)
            assertEquals(expected, result.errorMessage)
        }
    }

    @Test
    fun `classify sanitizes unknown error text`() {
        val result = classifyGetBytesFailure(null, null, "auth_failed_custom")
        assertTrue(result.isFailed)
        assertEquals("sync_failed", result.errorMessage)
    }

    @Test
    fun `classify maps direct status codes`() {
        assertTrue(classifyGetBytesFailure(404, null, "x").isNotFound)
        assertEquals("auth_failed", classifyGetBytesFailure(401, null, "x").errorMessage)
        assertEquals("access_denied", classifyGetBytesFailure(403, null, "x").errorMessage)
        assertEquals("invalid_response", classifyGetBytesFailure(500, null, "x").errorMessage)
    }

    @Test
    fun `history listing failure preserves not found`() {
        val missing = classifyHistoryListFailure(null, null, "404 Not Found")
        assertTrue(missing.isNotFound)
        assertFalse(missing.isFailed)
        val failed = classifyHistoryListFailure(null, null, "connection reset")
        assertTrue(failed.isFailed)
    }

    // ---------- unsupported lock ----------

    @Test
    fun `unsupported lock hint matches dart phrases`() {
        assertTrue(looksLikeUnsupportedLock("resource cannot be locked here"))
        assertTrue(looksLikeUnsupportedLock("LOCK NOT SUPPORTED by server"))
        assertTrue(looksLikeUnsupportedLock("lock method not allowed"))
        assertFalse(looksLikeUnsupportedLock("access denied"))
    }

    // ---------- backup index recovery ----------

    @Test
    fun `backup recovery aborts when index and listing both fail`() {
        val action = decideBackupIndexRecovery(
            index = GetBytesResult.failed("index_timeout"),
            listing = HistoryListResult.failed("listing_timeout"),
        )
        assertEquals(BackupIndexRecoveryAction.FAILED, action)
    }

    @Test
    fun `backup recovery aborts when failed index has no successful listing`() {
        assertEquals(
            BackupIndexRecoveryAction.FAILED,
            decideBackupIndexRecovery(
                index = GetBytesResult.failed("index_timeout"),
                listing = HistoryListResult.ok(emptyList()),
            ),
        )
        assertEquals(
            BackupIndexRecoveryAction.FAILED,
            decideBackupIndexRecovery(
                index = GetBytesResult.failed("index_timeout"),
                listing = HistoryListResult.notFound(),
            ),
        )
    }

    @Test
    fun `backup recovery treats missing index and empty listing as empty`() {
        assertEquals(
            BackupIndexRecoveryAction.EMPTY,
            decideBackupIndexRecovery(
                index = GetBytesResult.notFound(),
                listing = HistoryListResult.ok(emptyList()),
            ),
        )
    }

    @Test
    fun `backup recovery rebuilds from successful listing`() {
        assertEquals(
            BackupIndexRecoveryAction.REBUILD_FROM_LISTING,
            decideBackupIndexRecovery(
                index = GetBytesResult.failed("index_timeout"),
                listing = HistoryListResult.ok(listOf("one.mikcb")),
            ),
        )
        assertEquals(
            BackupIndexRecoveryAction.REBUILD_FROM_LISTING,
            decideBackupIndexRecovery(
                index = GetBytesResult.notFound(),
                listing = HistoryListResult.ok(listOf("one.mikcb")),
            ),
        )
    }

    @Test
    fun `backup recovery uses index when present`() {
        assertEquals(
            BackupIndexRecoveryAction.USE_INDEX,
            decideBackupIndexRecovery(
                index = GetBytesResult.ok(byteArrayOf(1, 2, 3)),
                listing = HistoryListResult.ok(emptyList()),
            ),
        )
    }

    // ---------- result models ----------

    @Test
    fun `result models expose notFound correctly`() {
        assertTrue(GetBytesResult.notFound().isNotFound)
        assertFalse(GetBytesResult.failed("x").isNotFound)
        assertTrue(HistoryListResult.notFound().isNotFound)
        assertTrue(HistoryListResult.ok(emptyList()).isEmpty)
        assertFalse(HistoryListResult.ok(listOf("a.mikcb")).isEmpty)
    }
}
