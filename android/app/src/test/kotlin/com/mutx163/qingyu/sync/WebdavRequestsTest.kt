package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 传输层的纯解析部分（不联网）。
 *
 * 期望值全部是**人推的**：URL 拼接按 baseUrl 语义推、百分号编码按 RFC 3986 unreserved
 * 集合推、Base64 用可手算的短串、PROPFIND 解析用一段手写 XML。
 */
class WebdavRequestsTest {

    // ---------- URL 拼接 ----------

    @Test
    fun joinWebdavUrlAppendsPathUnderBaseFolder() {
        assertEquals(
            "https://dav.jianguoyun.com/dav/Apps/qingyu-sync/snapshot.mikcb",
            joinWebdavUrl("https://dav.jianguoyun.com/dav/", "/Apps/qingyu-sync/snapshot.mikcb"),
        )
    }

    @Test
    fun joinWebdavUrlAddsMissingTrailingSlashToBase() {
        assertEquals(
            "https://host/dav/x.mikcb",
            joinWebdavUrl("https://host/dav", "/x.mikcb"),
        )
    }

    @Test
    fun joinWebdavUrlReturnsBaseWhenPathEmpty() {
        assertEquals("https://host/dav/", joinWebdavUrl("https://host/dav/", ""))
    }

    @Test
    fun joinWebdavUrlKeepsTrailingSlashOfCollectionPath() {
        assertEquals("https://host/dav/Apps/", joinWebdavUrl("https://host/dav/", "/Apps/"))
    }

    // ---------- 百分号编解码 ----------

    @Test
    fun encodeWebdavPathEncodesNonAsciiAndSpaceButKeepsSeparators() {
        // "备" UTF-8 = E5 A4 87，"份" = E4 BB BD；空格 = 0x20；'/' 与 '.' 保留。
        assertEquals(
            "%E5%A4%87%E4%BB%BD%202026.mikcb",
            encodeWebdavPath("备份 2026.mikcb"),
        )
        assertEquals("/Apps/qingyu-sync/", encodeWebdavPath("/Apps/qingyu-sync/"))
        assertEquals("a-b_c.d~e", encodeWebdavPath("a-b_c.d~e"))
    }

    @Test
    fun percentDecodeRestoresUtf8AndDoesNotTreatPlusAsSpace() {
        assertEquals("备份 2026.mikcb", percentDecode("%E5%A4%87%E4%BB%BD%202026.mikcb"))
        // 路径里 '+' 是字面加号（URLDecoder 会错当空格，本实现不许）。
        assertEquals("a+b", percentDecode("a+b"))
        // 落单的 '%' 不是合法转义，原样保留而不是丢字符。
        assertEquals("100%", percentDecode("100%"))
    }

    @Test
    fun encodeThenDecodeIsIdentityForMixedPath() {
        val original = "/Apps/情侣 课表/备份-2026.mikcb"
        assertEquals(original, percentDecode(encodeWebdavPath(original)))
    }

    // ---------- 状态码 / 重定向 ----------

    @Test
    fun redirectStatusesAreTheFiveKnownOnes() {
        assertTrue(isRedirectStatus(301))
        assertTrue(isRedirectStatus(302))
        assertTrue(isRedirectStatus(303))
        assertTrue(isRedirectStatus(307))
        assertTrue(isRedirectStatus(308))
        assertFalse(isRedirectStatus(200))
        assertFalse(isRedirectStatus(300))
        assertFalse(isRedirectStatus(304))
        assertFalse(isRedirectStatus(null))
    }

    @Test
    fun successStatusCovers207MultiStatus() {
        assertTrue(isSuccessStatus(200))
        assertTrue(isSuccessStatus(204))
        assertTrue(isSuccessStatus(207))
        assertFalse(isSuccessStatus(301))
        assertFalse(isSuccessStatus(null))
    }

    @Test
    fun resolveRedirectUrlHandlesAbsoluteRootRelativeAndSiblingForms() {
        assertEquals(
            "https://host/dav/new.mikcb",
            resolveRedirectUrl("https://host/dav/old.mikcb", "/dav/new.mikcb"),
        )
        assertEquals(
            "https://other/x.mikcb",
            resolveRedirectUrl("https://host/dav/old.mikcb", "https://other/x.mikcb"),
        )
        // 相对引用按「当前 URL 的目录」解析：/dav/Apps/index.json 的目录是 /dav/Apps/，
        // 所以 "history/index.json" → /dav/Apps/history/index.json（不是 /dav/history/…）。
        assertEquals(
            "https://host/dav/Apps/history/index.json",
            resolveRedirectUrl("https://host/dav/Apps/index.json", "history/index.json"),
        )
    }

    @Test
    fun resolveRedirectUrlRejectsNonHttpTargetsAndEmptyLocation() {
        assertNull(resolveRedirectUrl("https://host/a", "ftp://host/a"))
        assertNull(resolveRedirectUrl("https://host/a", "file:///etc/passwd"))
        assertNull(resolveRedirectUrl("https://host/a", ""))
        assertNull(resolveRedirectUrl("https://host/a", null))
    }

    // ---------- 认证头 ----------

    @Test
    fun basicAuthorizationHeaderIsBase64OfUserColonPassword() {
        // base64("u:p") = "dTpw"（可手算：3 字节 → 4 个 base64 字符）。
        assertEquals("Basic dTpw", basicAuthorizationHeader("u", "p"))
        // base64(":") = "Og=="（单字节 + 两个填充）。
        assertEquals("Basic Og==", basicAuthorizationHeader("", ""))
    }

    // ---------- ETag / 锁 ----------

    @Test
    fun normalizeEtagStripsWeakMarkerAndQuotes() {
        assertEquals("abc", normalizeEtag("W/\"abc\""))
        assertEquals("abc", normalizeEtag("\"abc\""))
        assertEquals("abc", normalizeEtag("abc"))
        assertEquals("abc", normalizeEtag("  \"abc\"  "))
        assertNull(normalizeEtag("\"\""))
        assertNull(normalizeEtag("   "))
        assertNull(normalizeEtag(null))
    }

    @Test
    fun parseLockTokenStripsAngleBrackets() {
        assertEquals("opaquelocktoken:xyz", parseLockToken("<opaquelocktoken:xyz>"))
        assertEquals("opaquelocktoken:xyz", parseLockToken("opaquelocktoken:xyz"))
        assertNull(parseLockToken("<>"))
        assertNull(parseLockToken(""))
        assertNull(parseLockToken(null))
    }

    @Test
    fun lockTokenIfHeaderWrapsTokenInParentheses() {
        assertEquals("(<opaquelocktoken:xyz>)", lockTokenIfHeader("opaquelocktoken:xyz"))
    }

    // ---------- 写失败分类 ----------

    @Test
    fun writeFailureMaps404ToInvalidResponseNotBackupNotFound() {
        // 写路径的 404 表示父目录不存在；Dart 的 sanitize 会错报 backup_not_found。
        assertEquals("invalid_response", classifyWebdavWriteFailure(404, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(409, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(412, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(423, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(507, null, ""))
        assertEquals("auth_failed", classifyWebdavWriteFailure(401, null, ""))
        assertEquals("access_denied", classifyWebdavWriteFailure(403, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(500, null, ""))
        // Dart 写路径走 sanitizeWebdavErrorMessage：除 401/403/404/5xx 外一律
        // invalid_response，405/422/429/3xx 不能落成泛化的 sync_failed。
        assertEquals("invalid_response", classifyWebdavWriteFailure(400, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(405, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(422, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(429, null, ""))
        assertEquals("invalid_response", classifyWebdavWriteFailure(302, null, ""))
    }

    @Test
    fun writeFailureMapsTransportKindsAndNeverLeaksMessage() {
        assertEquals(
            "connection_timeout",
            classifyWebdavWriteFailure(null, TransportKind.TIMEOUT, "java.net.SocketTimeoutException: Read timed out"),
        )
        assertEquals(
            "connection_failed",
            classifyWebdavWriteFailure(null, TransportKind.SOCKET, "https://user@host/dav/ refused"),
        )
        assertEquals(
            "certificate_error",
            classifyWebdavWriteFailure(null, TransportKind.HANDSHAKE, "PKIX path building failed"),
        )
        assertEquals(
            "invalid_response",
            classifyWebdavWriteFailure(null, TransportKind.FORMAT, "bad url"),
        )
        assertEquals("sync_failed", classifyWebdavWriteFailure(null, null, "opaque server text"))
    }

    // ---------- PROPFIND 解析 ----------

    @Test
    fun parsePropfindResourcesReadsHrefCollectionLengthEtag() {
        val resources = parsePropfindResources(PROPFIND_XML)

        assertEquals(5, resources.size)
        assertEquals(
            listOf(
                "history",
                "snapshot-abc-123-dev.mikcb",
                "备份-2026.mikcb",
                "notes.txt",
                "archive",
            ),
            resources.map { it.name },
        )
        assertEquals(
            listOf(true, false, false, false, true),
            resources.map { it.isDirectory },
        )
        assertEquals(2048L, resources[1].contentLength)
        assertEquals("rev-7", resources[1].etag)
        // 弱 ETag 也归一化成裸值，和 HEAD 路径口径一致。
        assertEquals("rev-8", resources[2].etag)
        assertEquals("Tue, 27 Oct 2026 21:10:00 GMT", resources[1].lastModified)
        assertNull(resources[3].etag)
    }

    @Test
    fun parsePropfindResourcesToleratesDocumentWithoutNamespacePrefix() {
        val xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <multistatus>
              <response>
                <href>/dav/Apps/qingyu-sync/history/</href>
                <propstat><prop><resourcetype><collection/></resourcetype></prop></propstat>
              </response>
              <response>
                <href>/dav/Apps/qingyu-sync/history/snapshot-1.mikcb</href>
                <propstat><prop><resourcetype/><getcontentlength>12</getcontentlength></prop></propstat>
              </response>
            </multistatus>
        """.trimIndent()

        val resources = parsePropfindResources(xml)

        assertEquals(2, resources.size)
        assertTrue(resources[0].isDirectory)
        assertEquals("history", resources[0].name)
        assertFalse(resources[1].isDirectory)
        assertEquals("snapshot-1.mikcb", resources[1].name)
        assertEquals(12L, resources[1].contentLength)
    }

    @Test
    fun parsePropfindResourcesUsesAbsoluteHrefPath() {
        val xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>https://dav.jianguoyun.com/dav/Apps/x.mikcb</D:href>
                <D:propstat><D:prop><D:resourcetype/></D:prop></D:propstat>
              </D:response>
            </D:multistatus>
        """.trimIndent()

        val resources = parsePropfindResources(xml)

        assertEquals(1, resources.size)
        assertEquals("/dav/Apps/x.mikcb", resources[0].path)
        assertEquals("x.mikcb", resources[0].name)
    }

    @Test
    fun historyFileNamesKeepOnlyNonDirectoryMikcbEntries() {
        val names = historyFileNamesFromResources(parsePropfindResources(PROPFIND_XML))
        assertEquals(listOf("snapshot-abc-123-dev.mikcb", "备份-2026.mikcb"), names)
    }

    @Test
    fun hrefPathStripsQueryAndFragment() {
        assertEquals("/dav/Apps/x.mikcb", hrefPath("/dav/Apps/x.mikcb?rev=2#frag"))
        assertEquals("/dav/Apps/x.mikcb", hrefPath("https://host/dav/Apps/x.mikcb?rev=2"))
        assertEquals("", hrefPath(""))
    }

    // ---------- 端点门禁 ----------

    @Test
    fun cloudEndpointRejectsInsecureHttpUnlessExplicitlyAllowed() {
        val insecure = WebdavSyncConfig(baseUrl = "http://192.168.1.10:5005/dav/", username = "alice")
        assertNull(WebdavEndpoint.from(insecure, "pw"))
        val allowed = WebdavEndpoint.from(insecure, "pw", allowInsecureHttp = true)
        assertEquals("http://192.168.1.10:5005/dav/", allowed?.baseUrl)
        assertEquals("alice", allowed?.username)
        assertEquals("pw", allowed?.password)
    }

    @Test
    fun cloudEndpointRejectsUnknownScheme() {
        assertNull(WebdavEndpoint.from(WebdavSyncConfig(baseUrl = "ftp://host/dav/"), "pw"))
        assertNull(WebdavEndpoint.from(WebdavSyncConfig(baseUrl = "not a url"), "pw"))
    }

    @Test
    fun cloudEndpointAcceptsHttps() {
        val endpoint = WebdavEndpoint.from(WebdavSyncConfig(baseUrl = "https://dav.example.com/dav/"), "pw")
        assertEquals("https://dav.example.com/dav/", endpoint?.baseUrl)
    }

    @Test
    fun coupleEndpointRejectsInsecureHttpEvenWithAllowFlagAbsent() {
        assertNull(WebdavEndpoint.fromCouple(CoupleWebdavConfig(baseUrl = "http://host/dav/"), "pw"))
        assertNull(WebdavEndpoint.fromCouple(CoupleWebdavConfig(baseUrl = "ftp://host/dav/"), "pw"))
    }

    @Test
    fun coupleEndpointAcceptsHttpsAndFallsBackToDefaultOnBlank() {
        val explicit = WebdavEndpoint.fromCouple(
            CoupleWebdavConfig(baseUrl = "https://dav.example.com/dav/", username = "me"),
            "pw",
        )
        assertEquals("https://dav.example.com/dav/", explicit?.baseUrl)
        assertEquals("me", explicit?.username)

        val blank = WebdavEndpoint.fromCouple(CoupleWebdavConfig(baseUrl = "   "), "pw")
        assertEquals(CoupleWebdavConfig.DEFAULT_JIANGUOYUN_BASE_URL, blank?.baseUrl)
    }

    companion object {
        /** 手写 207 Multi-Status：目录本身 + 两个 .mikcb + 一个 .txt + 一个子目录。 */
        private val PROPFIND_XML = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/snapshot-abc-123-dev.mikcb</D:href>
                <D:propstat>
                  <D:prop>
                    <D:resourcetype/>
                    <D:getcontentlength>2048</D:getcontentlength>
                    <D:getetag>"rev-7"</D:getetag>
                    <D:getlastmodified>Tue, 27 Oct 2026 21:10:00 GMT</D:getlastmodified>
                  </D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/%E5%A4%87%E4%BB%BD-2026.mikcb</D:href>
                <D:propstat>
                  <D:prop>
                    <D:resourcetype/>
                    <D:getcontentlength>16</D:getcontentlength>
                    <D:getetag>W/"rev-8"</D:getetag>
                  </D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/notes.txt</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype/><D:getcontentlength>3</D:getcontentlength></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/archive/</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
            </D:multistatus>
        """.trimIndent()
    }
}
