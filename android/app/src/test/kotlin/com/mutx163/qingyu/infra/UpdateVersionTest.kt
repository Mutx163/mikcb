package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 版本号比较单测。
 *
 * 期望值来源：
 * - Dart 测试抄录（test/services/app_update_service_test.dart）：
 *   `1.1.10.3`==`1.1.10-3+33`、`1.2.0.29`==`1.2.0-29-debug`、
 *   预发布 `1.1.10.4`>`1.1.10`、digest 同源两条；
 * - Dart 逐行（_parseVersion 各折叠分支）；
 * - 人推边界：构建元数据、文本预发布序、空 tag、draft/无资产过滤。
 */
class UpdateVersionTest {

    // ---------- normalizeVersion ----------

    @Test
    fun `normalize strips whitespace and single v prefix`() {
        assertEquals("2.1.4", normalizeVersion("  v2.1.4 "))
        assertEquals("2.1.4", normalizeVersion("V2.1.4"))
        assertEquals("2.1.4", normalizeVersion("2.1.4"))
        // 人推：只去首个 v，"vv1" → "v1"。
        assertEquals("v1", normalizeVersion("vv1"))
    }

    // ---------- compareVersions（Dart 测试锚点） ----------

    @Test
    fun `dotted tag suffix equals pubspec prerelease format`() {
        // 抄录 service_test:191：debug 语义下两者相等，不提示更新。
        assertEquals(0, compareVersions("1.1.10.3", "1.1.10-3+33"))
        assertEquals(0, compareVersions("1.1.10-3+33", "1.1.10.3"))
    }

    @Test
    fun `debug build with dash suffix is not newer than release`() {
        // 抄录 service_test:94：1.2.0-29-debug == 1.2.0.29。
        assertEquals(0, compareVersions("1.2.0.29", "1.2.0-29-debug"))
    }

    @Test
    fun `numbered prerelease upgrades from base release`() {
        // 抄录 service_test:226/282：1.1.10.4（预发布）> 1.1.10。
        assertTrue(compareVersions("1.1.10.4", "1.1.10") > 0)
        assertTrue(compareVersions("1.1.10", "1.1.10.4") < 0)
    }

    @Test
    fun `basic numeric ordering`() {
        assertTrue(compareVersions("1.10", "1.9") > 0)
        assertTrue(compareVersions("2.0", "1.99.99") > 0)
        assertEquals(0, compareVersions("1.0.0", "1.0"))
        assertTrue(compareVersions("1.0.1", "1.0") > 0)
    }

    @Test
    fun `build metadata is ignored`() {
        // 人推：Dart split('+').first，+ 后一律不参与。
        assertEquals(0, compareVersions("1.0.0+99", "1.0.0"))
        assertEquals(0, compareVersions("1.0.0+1", "1.0.0+2"))
    }

    @Test
    fun `release beats text prerelease`() {
        // 人推：无预发布 > 有预发布；文本预发布按段字典序。
        assertTrue(compareVersions("1.0.0", "1.0.0-beta") > 0)
        assertTrue(compareVersions("1.0.0-beta", "1.0.0-alpha") > 0)
        assertTrue(compareVersions("1.0.0-10", "1.0.0-2") > 0)
    }

    // ---------- hasUpdate ----------

    @Test
    fun `has update reflects comparison`() {
        assertTrue(hasUpdate("1.4.0", "1.3.0"))
        assertTrue(!hasUpdate("1.3.0", "1.3.0"))
        assertTrue(!hasUpdate("1.2.9", "1.3.0"))
    }

    // ---------- pickApkDownload（Dart 测试抄录 + 人推） ----------

    @Test
    fun `digest and url come from the same apk asset`() {
        // 抄录 service_test:1098：首个无 digest 的 arm APK 不得与后续 arm64 的 digest 错配。
        val assets = listOf<Any?>(
            mapOf(
                "name" to "mikcb-1.4.0-armeabi-v7a.apk",
                "browser_download_url" to "https://example.com/1.4.0-arm.apk",
            ),
            mapOf(
                "name" to "mikcb-1.4.0-arm64-v8a.apk",
                "browser_download_url" to "https://example.com/1.4.0-arm64.apk",
                "digest" to "sha256:def456",
            ),
        )
        val (url, digest) = pickApkDownload(assets)
        assertEquals("https://example.com/1.4.0-arm64.apk", url)
        assertEquals("def456", digest)
    }

    @Test
    fun `short api digest is kept as is`() {
        // 抄录 service_test:1063：'sha256:abc123' → 'abc123'。
        val assets = listOf<Any?>(
            mapOf(
                "name" to "mikcb-1.4.0-arm64-v8a.apk",
                "browser_download_url" to "https://example.com/1.4.0.apk",
                "digest" to "sha256:abc123",
            ),
        )
        assertEquals("abc123", pickApkDownload(assets).second)
    }

    @Test
    fun `no digest yields null digest with url`() {
        // 抄录 service_test:1141：无 digest 时 digest 为 null。
        val assets = listOf<Any?>(
            mapOf(
                "name" to "mikcb-1.4.0-arm64-v8a.apk",
                "browser_download_url" to "https://example.com/1.4.0.apk",
            ),
        )
        val (url, digest) = pickApkDownload(assets)
        assertEquals("https://example.com/1.4.0.apk", url)
        assertNull(digest)
    }

    @Test
    fun `debug apk is skipped in favor of release apk`() {
        // 人推：debug 资产只在没有其他 APK 时才选中（第三档）。
        val assets = listOf<Any?>(
            mapOf("name" to "mikcb-debug.apk", "browser_download_url" to "https://e.com/d.apk"),
            mapOf("name" to "mikcb-1.0.apk", "browser_download_url" to "https://e.com/r.apk"),
        )
        assertEquals("https://e.com/r.apk", pickApkDownload(assets).first)
    }

    @Test
    fun `empty assets yield nulls`() {
        val (url, digest) = pickApkDownload(emptyList())
        assertNull(url)
        assertNull(digest)
    }

    // ---------- pickLatestEligibleRelease ----------

    private fun release(
        tag: String,
        draft: Boolean = false,
        prerelease: Boolean = false,
        withApk: Boolean = true,
    ): Map<String, Any?> = linkedMapOf<String, Any?>(
        "tag_name" to tag,
        "name" to tag,
        "draft" to draft,
        "prerelease" to prerelease,
        "html_url" to "https://example.com/$tag",
        "assets" to if (withApk) {
            listOf(mapOf("name" to "mikcb.apk", "browser_download_url" to "https://example.com/$tag.apk"))
        } else {
            emptyList<Any>()
        },
    )

    @Test
    fun `picks highest version skipping draft prerelease and assetless`() {
        // 人推：draft/预发布（未包含时）/无资产一律跳过，取最高。
        val list = listOf(
            release("v1.0.0", withApk = false),
            release("v9.9.9", draft = true),
            release("v1.0.1", prerelease = true),
            release("v1.0.2"),
        )
        val picked = pickLatestEligibleRelease(list, includePrerelease = false)
        assertEquals("v1.0.2", picked?.get("tag_name"))
    }

    @Test
    fun `include prerelease picks highest even if listed first`() {
        // 抄录 service_test:135：即使排在前面，最高预发布胜出。
        val list = listOf(release("v1.1.9.4", prerelease = true), release("v1.1.9.3"))
        val picked = pickLatestEligibleRelease(list, includePrerelease = true)
        assertEquals("v1.1.9.4", picked?.get("tag_name"))
    }

    @Test
    fun `empty version tags are skipped`() {
        assertNull(pickLatestEligibleRelease(listOf(release("")), includePrerelease = true))
        assertNull(pickLatestEligibleRelease(emptyList(), includePrerelease = true))
    }
}
