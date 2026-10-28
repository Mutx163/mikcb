package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.AppUpdateDownloadSource
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** 「版本更新页」纯逻辑层的契约测试（settings 快照 / 镜像 / 格式化 / 页面阶段 / 检查解析）。 */
class AppUpdateModelTest {

    // ---------- AppUpdateSettings ----------

    @Test
    fun `defaults match dart constructors`() {
        val s = AppUpdateSettings()
        assertEquals(AppUpdateDownloadSource.MIRROR, s.downloadSource)
        assertEquals(AppUpdateDownloadChannel.GITCODE, s.downloadChannel)
        assertEquals(false, s.useSystemDownloader)
        assertEquals(MirrorPreset.GHFAST, s.mirrorPreset)
        assertEquals(false, s.includePrerelease)
        assertEquals("https://ghfast.top/", s.mirrorUrlPrefix)
        assertEquals(true, s.promptEnabled)
    }

    @Test
    fun `fromJson reads values and falls back on unknown`() {
        val json = mapOf(
            "appUpdateDownloadSource" to "original",
            "appUpdateDownloadChannel" to "github",
            "appUpdateUseSystemDownloader" to true,
            "appUpdateMirrorPreset" to "gh_proxy_com",
            "appUpdateIncludePrerelease" to true,
            "appUpdateMirrorUrlPrefix" to "https://x.example/",
            "appUpdatePromptEnabled" to false,
        )
        val s = AppUpdateSettings.fromJson(json)
        assertEquals(AppUpdateDownloadSource.ORIGINAL, s.downloadSource)
        assertEquals(AppUpdateDownloadChannel.GITHUB, s.downloadChannel)
        assertTrue(s.useSystemDownloader)
        assertEquals(MirrorPreset.GH_PROXY_COM, s.mirrorPreset)
        assertTrue(s.includePrerelease)
        assertEquals("https://x.example/", s.mirrorUrlPrefix)
        assertEquals(false, s.promptEnabled)

        // 未知/缺键 → Dart 口径回落
        val fallback = AppUpdateSettings.fromJson(
            mapOf(
                "appUpdateDownloadSource" to "weird",
                "appUpdateDownloadChannel" to 123,
                "appUpdateMirrorPreset" to "nope",
            ),
        )
        assertEquals(AppUpdateDownloadSource.MIRROR, fallback.downloadSource)
        assertEquals(AppUpdateDownloadChannel.GITCODE, fallback.downloadChannel)
        assertEquals(MirrorPreset.GHFAST, fallback.mirrorPreset)
        assertEquals(true, fallback.promptEnabled)
    }

    @Test
    fun `toPatch writes all seven keys with dart value strings`() {
        val patch = AppUpdateSettings(
            downloadSource = AppUpdateDownloadSource.ORIGINAL,
            downloadChannel = AppUpdateDownloadChannel.PGYER,
            mirrorPreset = MirrorPreset.GH_LLKK,
        ).toPatch()
        assertEquals("original", patch["appUpdateDownloadSource"])
        assertEquals("pgyer", patch["appUpdateDownloadChannel"])
        assertEquals("gh_llkk", patch["appUpdateMirrorPreset"])
        assertEquals(7, patch.size)
        assertTrue(patch.containsKey("appUpdateUseSystemDownloader"))
        assertTrue(patch.containsKey("appUpdateIncludePrerelease"))
        assertTrue(patch.containsKey("appUpdateMirrorUrlPrefix"))
        assertTrue(patch.containsKey("appUpdatePromptEnabled"))
    }

    @Test
    fun `enum value round trip`() {
        for (p in MirrorPreset.entries) {
            assertEquals(p, mirrorPresetFromValue(mirrorPresetValue(p)))
        }
        for (c in AppUpdateDownloadChannel.entries) {
            assertEquals(c, downloadChannelFromValue(downloadChannelValue(c)))
        }
        for (s in AppUpdateDownloadSource.entries) {
            assertEquals(s, downloadSourceFromValue(downloadSourceValue(s)))
        }
    }

    // ---------- 镜像 ----------

    @Test
    fun `resolveMirrorUrlPrefix maps five presets`() {
        assertEquals("https://ghfast.top/", resolveMirrorUrlPrefix(MirrorPreset.GHFAST, ""))
        assertEquals("https://gh.llkk.cc/", resolveMirrorUrlPrefix(MirrorPreset.GH_LLKK, ""))
        assertEquals("https://gh-proxy.com/", resolveMirrorUrlPrefix(MirrorPreset.GH_PROXY_COM, ""))
        assertEquals("https://ghproxy.net/", resolveMirrorUrlPrefix(MirrorPreset.GH_PROXY_NET, ""))
        assertEquals("https://custom.example/", resolveMirrorUrlPrefix(MirrorPreset.CUSTOM, " https://custom.example/ "))
        assertEquals("https://ghfast.top/", resolveMirrorUrlPrefix(MirrorPreset.CUSTOM, "   "))
    }

    @Test
    fun `normalizeMirrorUrlPrefix trims and validates`() {
        assertEquals("https://a.example/", normalizeMirrorUrlPrefix(" https://a.example "))
        assertEquals("https://a.example/x/", normalizeMirrorUrlPrefix("https://a.example/x/"))
        assertNull(normalizeMirrorUrlPrefix(""))
        assertNull(normalizeMirrorUrlPrefix("   "))
        assertNull(normalizeMirrorUrlPrefix("notaurl"))
    }

    @Test
    fun `buildMirrorPresetCandidates adds custom only when valid`() {
        assertEquals(4, buildMirrorPresetCandidates("").size)
        val withCustom = buildMirrorPresetCandidates("https://c.example")
        assertEquals(5, withCustom.size)
        assertEquals(MirrorPreset.CUSTOM, withCustom.last().first)
        assertEquals("https://c.example/", withCustom.last().second)
        // 非法自定义前缀不加
        assertEquals(4, buildMirrorPresetCandidates("notaurl").size)
    }

    // ---------- 格式化 ----------

    @Test
    fun `formatBytes matches dart thresholds`() {
        assertEquals("0 B", formatBytes(0))
        assertEquals("1023 B", formatBytes(1023))
        assertEquals("1.0 KB", formatBytes(1024))
        assertEquals("1.5 KB", formatBytes(1536))
        assertEquals("1.0 MB", formatBytes(1024L * 1024L))
        assertEquals("2.5 MB", formatBytes((2.5 * 1024 * 1024).toLong()))
    }

    @Test
    fun `debugPreviousVersion decrements last numeric segment`() {
        assertEquals("2.1.3.3", debugPreviousVersion("2.1.3.4"))
        assertEquals("2.0", debugPreviousVersion("2.1"))
        assertEquals("0.0.0", debugPreviousVersion("x"))
        assertEquals("0.0.0", debugPreviousVersion("1.0"))
        assertEquals("0.0.0", debugPreviousVersion(null))
    }

    @Test
    fun `formatUpdateDateTime is yyyy-MM-dd HH mm in UTC`() {
        // 2021-01-02T03:04:00Z
        val millis = 1609556640000L
        assertEquals("2021-01-02 03:04", formatUpdateDateTime(millis))
    }

    // ---------- 页面阶段 ----------

    @Test
    fun `page phase combos`() {
        val ready = AppUpdateCheckResult(hasRelease = true, hasUpdate = false, currentVersion = "1.0")
        assertEquals(AboutUpdatePagePhase.CHECKING, resolveAboutUpdatePagePhase(false, false, ready))
        assertEquals(AboutUpdatePagePhase.CHECKING, resolveAboutUpdatePagePhase(true, true, ready))
        assertEquals(AboutUpdatePagePhase.CHECK_FAILED, resolveAboutUpdatePagePhase(true, false, null))
        val noRelease = AppUpdateCheckResult(hasRelease = false, hasUpdate = true, currentVersion = "1.0")
        assertEquals(AboutUpdatePagePhase.CHECK_FAILED, resolveAboutUpdatePagePhase(true, false, noRelease))
        assertEquals(AboutUpdatePagePhase.READY, resolveAboutUpdatePagePhase(true, false, ready))
    }

    // ---------- 下载进度 ----------

    @Test
    fun `download progress fraction and unknown total`() {
        val unknown = resolveDownloadProgress(100, null)
        assertNull(unknown.fraction)
        val zero = resolveDownloadProgress(100, 0)
        assertNull(zero.fraction)
        val half = resolveDownloadProgress(50, 100)
        assertEquals(0.5, half.fraction!!, 1e-9)
        val over = resolveDownloadProgress(200, 100)
        assertEquals(1.0, over.fraction!!, 1e-9)
    }

    // ---------- 检查解析 ----------

    private val sampleReleases = """
        [
          {
            "tag_name": "v2.1.0",
            "name": "2.1.0",
            "body": "本次重点：修复若干问题",
            "html_url": "https://github.com/Mutx163/mikcb/releases/tag/v2.1.0",
            "updated_at": "2021-01-02T03:04:00Z",
            "prerelease": false,
            "draft": false,
            "assets": [
              {"name": "app-arm64.apk", "browser_download_url": "https://github.com/Mutx163/mikcb/releases/download/v2.1.0/app-arm64.apk"}
            ]
          },
          {
            "tag_name": "v2.2.0-1",
            "name": "2.2.0-1 test",
            "body": "pre",
            "html_url": "https://github.com/Mutx163/mikcb/releases/tag/v2.2.0-1",
            "prerelease": true,
            "draft": false,
            "assets": [
              {"name": "app.apk", "browser_download_url": "https://github.com/Mutx163/mikcb/releases/download/v2.2.0-1/app.apk"}
            ]
          },
          {
            "tag_name": "v3.0.0",
            "name": "draft",
            "draft": true,
            "prerelease": false,
            "assets": [
              {"name": "app.apk", "browser_download_url": "https://github.com/Mutx163/mikcb/releases/download/v3.0.0/app.apk"}
            ]
          },
          {
            "tag_name": "v2.0.5",
            "name": "no asset",
            "draft": false,
            "prerelease": false,
            "assets": []
          }
        ]
    """.trimIndent()

    @Test
    fun `parse picks highest stable skipping prerelease draft and no-asset`() {
        val outcome = parseGithubReleasesResponse("2.0.0", sampleReleases, includePrerelease = false)
        assertTrue(outcome is AppUpdateCheckOutcome.Success)
        val result = (outcome as AppUpdateCheckOutcome.Success).result
        assertTrue(result.hasRelease)
        assertTrue(result.hasUpdate)
        assertEquals("2.1.0", result.latestRelease!!.version)
    }

    @Test
    fun `parse includes prerelease when requested`() {
        val outcome = parseGithubReleasesResponse("2.0.0", sampleReleases, includePrerelease = true)
        val result = (outcome as AppUpdateCheckOutcome.Success).result
        assertEquals("2.2.0-1", result.latestRelease!!.version)
    }

    @Test
    fun `parse empty list yields no release`() {
        val outcome = parseGithubReleasesResponse("2.0.0", "[]", includePrerelease = false)
        val result = (outcome as AppUpdateCheckOutcome.Success).result
        assertEquals(false, result.hasRelease)
    }

    @Test
    fun `parse malformed yields Malformed`() {
        assertEquals(AppUpdateCheckOutcome.Malformed, parseGithubReleasesResponse("2.0.0", "not json", false))
        assertEquals(AppUpdateCheckOutcome.Malformed, parseGithubReleasesResponse("2.0.0", null, false))
        assertEquals(AppUpdateCheckOutcome.Malformed, parseGithubReleasesResponse("2.0.0", "{}", false))
    }
}
