package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 更新信任根与下载地址单测。
 *
 * 期望值来源：
 * - Dart 测试抄录（app_update_asset_url_test / release_list_url_test /
 *   system_downloader_url_test / service_test digest 组）；
 * - Dart 逐行（async_utils.dart 候选与主机判定、service 主机剥壳循环）；
 * - 人推边界：畸形输入、伪造域名、双层镜像壳、64 位外摘要、空 tag。
 */
class UpdateUrlsTest {

    private val githubApk =
        "https://github.com/Mutx163/mikcb/releases/download/v2.1.4/mikcb-2.1.4-arm64-v8a.apk"

    private fun release(
        version: String = "2.1.4",
        downloadUrl: String? = githubApk,
        gitcodeDownloadUrl: String? = null,
        pgyerDownloadUrl: String? = null,
    ) = AppReleaseInfo(
        version = version,
        title = "title",
        body = "body",
        releaseUrl = "https://github.com/Mutx163/mikcb/releases/tag/v$version",
        downloadUrl = downloadUrl,
        gitcodeDownloadUrl = gitcodeDownloadUrl,
        pgyerDownloadUrl = pgyerDownloadUrl,
        updatedAtMillis = 0L,
        isPrerelease = false,
    )

    // ---------- buildMirrorCandidateUrls ----------

    @Test
    fun `mirror candidates order selected then builtins then original`() {
        val urls = buildMirrorCandidateUrls("https://github.com/x.apk", selectedMirrorPrefix = "https://custom.top/")
        assertEquals(6, urls.size)
        assertEquals("https://custom.top/https://github.com/x.apk", urls[0])
        assertEquals("https://ghfast.top/https://github.com/x.apk", urls[1])
        assertEquals("https://github.com/x.apk", urls.last())
    }

    @Test
    fun `mirror candidates deduplicate`() {
        // 人推：选中与内置重复时不出现两次。
        val urls = buildMirrorCandidateUrls("https://github.com/x.apk", selectedMirrorPrefix = "https://ghfast.top/")
        assertEquals(1, urls.count { it.startsWith("https://ghfast.top/") })
    }

    // ---------- isTrustedApkDownloadUrl ----------

    @Test
    fun `apk trust allows official hosts and mirrors`() {
        assertTrue(isTrustedApkDownloadUrl(githubApk))
        assertTrue(isTrustedApkDownloadUrl("https://gitcode.com/mutx/qingyu/releases/download/v1/x.apk"))
        assertTrue(isTrustedApkDownloadUrl("https://ghfast.top/https://github.com/x.apk"))
        assertTrue(
            isTrustedApkDownloadUrl(
                "https://mirror.example.com/x.apk",
                mirrorUrlPrefix = "https://mirror.example.com/",
            ),
        )
    }

    @Test
    fun `apk trust rejects http foreign and mismatched custom prefix`() {
        assertFalse(isTrustedApkDownloadUrl("http://github.com/Mutx163/mikcb/x.apk"))
        assertFalse(isTrustedApkDownloadUrl("https://evil.com/mikcb.apk"))
        assertFalse(
            isTrustedApkDownloadUrl(
                "https://other.example.com/x.apk",
                mirrorUrlPrefix = "https://mirror.example.com/",
            ),
        )
        assertFalse(isTrustedApkDownloadUrl("not a url"))
    }

    // ---------- manifest trust ----------

    @Test
    fun `manifest trust only allows official direct hosts`() {
        assertTrue(isTrustedManifestUrl("https://api.github.com/repos/Mutx163/mikcb/releases"))
        assertTrue(isTrustedManifestUrl("https://github.com/Mutx163/mikcb/releases"))
        assertTrue(isTrustedManifestUrl("https://gitcode.com/mutx/qingyu/releases"))
        // 镜像外壳的主机是镜像，不是官方：一律拒绝。
        assertFalse(isTrustedManifestUrl("https://ghfast.top/https://api.github.com/repos/Mutx163/mikcb/releases"))
        assertFalse(isTrustedManifestUrl("http://github.com/x"))
    }

    @Test
    fun `direct github url excludes mirror shells`() {
        assertTrue(isDirectGitHubUrl("https://api.github.com/x"))
        assertTrue(isDirectGitHubUrl("https://github.com/x"))
        assertFalse(isDirectGitHubUrl("https://ghfast.top/https://api.github.com/x"))
    }

    // ---------- isOfficialApkAssetUrl ----------

    @Test
    fun `official asset requires own repo path`() {
        assertTrue(isOfficialApkAssetUrl(githubApk))
        assertFalse(isOfficialApkAssetUrl("https://github.com/evil/mikcb.apk"))
        // 伪造域名不能靠路径前缀混进来。
        assertFalse(isOfficialApkAssetUrl("https://github.com.evil.com/Mutx163/mikcb/releases/download/x.apk"))
    }

    @Test
    fun `official asset peels mirror shells`() {
        // 人推：单层与双层镜像外壳剥掉后仍认得出本仓库路径。
        assertTrue(isOfficialApkAssetUrl("https://ghfast.top/https://github.com/Mutx163/mikcb/releases/download/v1/x.apk"))
        assertTrue(
            isOfficialApkAssetUrl(
                "https://gh-proxy.com/https://ghfast.top/https://github.com/Mutx163/mikcb/releases/download/v1/x.apk",
            ),
        )
        assertFalse(isOfficialApkAssetUrl("https://ghfast.top/https://github.com/evil/x.apk"))
    }

    // ---------- isRedirectTargetAllowed ----------

    @Test
    fun `redirect allows github cdn and official assets`() {
        assertTrue(isRedirectTargetAllowed("https://objects.githubusercontent.com/assets/x?token=1"))
        assertTrue(isRedirectTargetAllowed(githubApk))
        assertFalse(isRedirectTargetAllowed("https://evil.com/x.apk"))
    }

    // ---------- download url builders ----------

    @Test
    fun `build download url wraps only for mirror source`() {
        assertEquals("https://ghfast.top/$githubApk", buildDownloadUrl(githubApk, AppUpdateDownloadSource.MIRROR, defaultMirrorUrlPrefix))
        assertEquals(githubApk, buildDownloadUrl(githubApk, AppUpdateDownloadSource.ORIGINAL, defaultMirrorUrlPrefix))
        // 人推：空前缀回退原地址。
        assertEquals(githubApk, buildDownloadUrl(githubApk, AppUpdateDownloadSource.MIRROR, "  "))
    }

    @Test
    fun `effective url gitcode falls back to constructed apk`() {
        assertEquals(
            "https://gitcode.com/mutx/qingyu/releases/download/v2.1.4/mikcb-2.1.4-arm64-v8a.apk",
            getEffectiveDownloadUrl(release(), AppUpdateDownloadChannel.GITCODE, AppUpdateDownloadSource.ORIGINAL, ""),
        )
        assertNull(getEffectiveDownloadUrl(release(version = ""), AppUpdateDownloadChannel.GITCODE, AppUpdateDownloadSource.ORIGINAL, ""))
        // pgyer 缺页面时回退固定地址。
        assertEquals(pgyerDownloadPageUrl, getEffectiveDownloadUrl(release(), AppUpdateDownloadChannel.PGYER, AppUpdateDownloadSource.ORIGINAL, ""))
    }

    @Test
    fun `system downloader always uses direct urls`() {
        // 抄录 system_downloader_url_test：默认镜像设置下仍给直连。
        val effective = getEffectiveDownloadUrl(
            release(), AppUpdateDownloadChannel.GITHUB, AppUpdateDownloadSource.MIRROR, defaultMirrorUrlPrefix,
        )
        assertTrue(effective!!.contains("ghfast.top"))
        val direct = getSystemDownloaderUrl(release(), AppUpdateDownloadChannel.GITHUB)
        assertEquals(githubApk, direct)
        assertFalse(direct!!.contains("ghfast"))
    }

    @Test
    fun `release list url follows channel`() {
        assertEquals(releasesPageUrl, releaseListUrlFor(AppUpdateDownloadChannel.GITHUB))
        assertEquals("$gitcodeRepositoryUrl/releases", releaseListUrlFor(AppUpdateDownloadChannel.GITCODE))
        assertEquals("$gitcodeRepositoryUrl/releases", releaseListUrlFor(AppUpdateDownloadChannel.PGYER))
    }

    // ---------- construct urls ----------

    @Test
    fun `construct apk urls follow naming rule`() {
        assertEquals(githubApk, constructApkDownloadUrl("v2.1.4", "2.1.4"))
        // 人推：空 tag 无法构造（调用方走 expanded_assets 或记 saw404）。
        assertNull(constructApkDownloadUrl("v", ""))
        assertNull(constructApkDownloadUrl("", "2.1.4"))
        assertEquals(
            "https://gitcode.com/mutx/qingyu/releases/download/v2.1.4/mikcb-2.1.4-arm64-v8a.apk",
            constructGitcodeApkDownloadUrl("v2.1.4", "2.1.4"),
        )
        assertNull(constructGitcodeApkDownloadUrl("v", "2.1.4"))
    }

    // ---------- sha / constant time / status ----------

    @Test
    fun `extract sha256 variants`() {
        val hex = "a1b2c3d4".repeat(8)
        assertEquals(hex, extractSha256FromBody("v1\n\n---\nSHA-256: $hex"))
        assertEquals(hex, extractSha256FromBody("sha256=$hex"))
        assertEquals(hex.uppercase(), extractSha256FromBody("SHA256 ${hex.uppercase()}")?.uppercase())
        assertNull(extractSha256FromBody("no digest here"))
        // 人推：63 位不认。
        assertNull(extractSha256FromBody("SHA-256: ${hex.dropLast(1)}"))
    }

    @Test
    fun `constant time equals`() {
        assertTrue(constantTimeEquals("abc", "abc"))
        assertFalse(constantTimeEquals("abc", "abd"))
        assertFalse(constantTimeEquals("abc", "abcd"))
    }

    @Test
    fun `pick last non 404 status`() {
        assertEquals(500, pickLastNon404StatusCode(500, 404))
        assertEquals(500, pickLastNon404StatusCode(404, 500))
        assertNull(pickLastNon404StatusCode(404, 404))
        assertNull(pickLastNon404StatusCode(null, null))
        assertNull(pickLastNon404StatusCode(404, null))
    }

    // ---------- html ----------

    @Test
    fun `html to plain text strips tags and decodes entities`() {
        assertEquals("x\ny &", htmlToPlainText("<b>x</b><br>y&nbsp;&amp;"))
    }

    @Test
    fun `html body to markdown restores headings lists quotes`() {
        val md = htmlBodyToMarkdown("<h1>v2.1.4</h1><ul><li>新增 A</li><li>修复 B</li></ul>")
        assertEquals("# v2.1.4\n\n- 新增 A\n\n- 修复 B", md)
        assertEquals("> 本次重点：快", htmlBodyToMarkdown("<blockquote><p>本次重点：快</p></blockquote>"))
    }

    @Test
    fun `extract title body updatedAt`() {
        val block = "<a href=\"/Mutx163/mikcb/releases/tag/v2.1.4\"> v2.1.4 </a>" +
            "<div data-test-selector=\"body-content\"><ul><li>新增 A</li></ul></div>" +
            "<relative-time datetime=\"2026-04-20T09:00:00Z\">"
        assertEquals("v2.1.4", extractReleaseTitle(block))
        assertEquals("- 新增 A", extractReleaseBody(block))
        // 人推手算：2026-04-20T09:00:00Z = 1776675600000。
        assertEquals(1776675600000L, extractReleaseUpdatedAtMillis(block))
        assertNull(extractReleaseTitle("no link here"))
        assertEquals("", extractReleaseBody("no body here"))
    }

    // ---------- page release picking ----------

    private val pageHtml = """
<section><h2><a href="/Mutx163/mikcb/releases/tag/v2.0.0">v2.0.0</a></h2><span>Pre-release</span>
<div data-test-selector="body-content">new</div></section>
<section><h2><a href="/Mutx163/mikcb/releases/tag/v1.9.0">v1.9.0</a></h2>
<div data-test-selector="body-content">old</div></section>
    """.trimIndent()

    @Test
    fun `page picking skips prerelease unless included`() {
        val stable = pickLatestEligibleReleaseFromHtml(pageHtml, includePrerelease = false)
        assertEquals("1.9.0", stable?.version)
        assertFalse(stable!!.isPrerelease)
        val pre = pickLatestEligibleReleaseFromHtml(pageHtml, includePrerelease = true)
        assertEquals("2.0.0", pre?.version)
        assertTrue(pre!!.isPrerelease)
        assertEquals(
            "https://github.com/Mutx163/mikcb/releases/download/v2.0.0/mikcb-2.0.0-arm64-v8a.apk",
            pre.downloadUrl,
        )
    }

    // ---------- json release mapping ----------

    @Test
    fun `github json release carries digest`() {
        val json = linkedMapOf<String, Any?>(
            "tag_name" to "v1.4.0",
            "name" to "v1.4.0",
            "draft" to false,
            "prerelease" to false,
            "html_url" to "https://example.com/1.4.0",
            "assets" to listOf(
                linkedMapOf<String, Any?>(
                    "name" to "mikcb-1.4.0-arm64-v8a.apk",
                    "browser_download_url" to "https://example.com/1.4.0.apk",
                    "digest" to "sha256:abc123",
                ),
            ),
            "updated_at" to "2026-04-20T09:00:00Z",
        )
        val info = releaseFromGitHubJson(json, digestFromDirectChannel = true)
        assertEquals("1.4.0", info.version)
        assertEquals("https://example.com/1.4.0.apk", info.downloadUrl)
        assertEquals("abc123", info.expectedApkSha256)
        assertTrue(info.digestFromDirectChannel)
        assertEquals(1776675600000L, info.updatedAtMillis)
    }

    @Test
    fun `mirror channel strips digest`() {
        val json = linkedMapOf<String, Any?>(
            "tag_name" to "v1.4.0",
            "body" to "SHA-256: ${"a1b2c3d4".repeat(8)}",
            "assets" to emptyList<Any>(),
        )
        val stripped = withDigestTrustMark(
            releaseFromGitHubJson(json, digestFromDirectChannel = true),
            digestFromDirectChannel = false,
        )
        // 镜像渠道：摘要与信任标记一并剥离，其他字段保留。
        assertNull(stripped.expectedApkSha256)
        assertFalse(stripped.digestFromDirectChannel)
        assertEquals("1.4.0", stripped.version)
    }

    @Test
    fun `gitcode json skips source archives and reads body digest`() {
        val hex = "a1b2c3d4".repeat(8)
        val picked = linkedMapOf<String, Any?>(
            "tag_name" to "v2.1.1.4",
            "name" to "v2.1.1.4",
            "prerelease" to false,
            "body" to "v2.1.1.4\n\n---\nSHA-256: $hex",
            "created_at" to "2026-09-03T11:10:15+08:00",
            "assets" to listOf(
                linkedMapOf<String, Any?>(
                    "name" to "v2.1.1.4.zip",
                    "type" to "source",
                    "browser_download_url" to "https://raw.gitcode.com/mutx/qingyu/archive/v2.1.1.4.zip",
                ),
                linkedMapOf<String, Any?>(
                    "name" to "mikcb-2.1.1.4-arm64-v8a.apk",
                    "type" to "attach",
                    "browser_download_url" to "https://gitcode.com/mutx/qingyu/releases/download/v2.1.1.4/mikcb-2.1.1.4-arm64-v8a.apk",
                ),
            ),
        )
        val info = releaseFromGitCodeJson(picked, includePrerelease = false)
        assertEquals("2.1.1.4", info?.version)
        assertEquals(
            "https://gitcode.com/mutx/qingyu/releases/download/v2.1.1.4/mikcb-2.1.1.4-arm64-v8a.apk",
            info?.gitcodeDownloadUrl,
        )
        assertEquals(hex, info?.expectedApkSha256)
        assertTrue(info!!.digestFromDirectChannel)
    }

    @Test
    fun `build check result messages`() {
        assertEquals("update_available", buildCheckResult("1.3.0", release(version = "1.4.0")).message)
        assertEquals(
            "update_available_prerelease",
            buildCheckResult("1.3.0", release(version = "1.4.0").copy(isPrerelease = true)).message,
        )
        assertEquals("already_latest", buildCheckResult("1.4.0", release(version = "1.4.0")).message)
    }
}
