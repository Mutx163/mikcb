package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.AppUpdateManifestSource
import com.mutx163.qingyu.infra.WarehouseRepositoryHost
import com.mutx163.qingyu.infra.WarehouseRepositorySource
import com.mutx163.qingyu.infra.appUpdateManifestCandidates
import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix
import com.mutx163.qingyu.infra.gitcodeReleasesApiUrl
import com.mutx163.qingyu.infra.isTrustedManifestUrl
import com.mutx163.qingyu.infra.releasesApiUrl
import com.mutx163.qingyu.infra.releasesPageUrl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 2026-11-10 联网审计三件的**纯逻辑钉口**（不碰真网络）：
 *
 * 1. `P0 更新检查接回 GitCode + 三路竞速`：候选链按渠道排序、三条都是官方直连；
 *    三条清单解析核（GitHub JSON / GitCode JSON / Release 页 HTML）各自能出结果；
 * 2. `P1 donors.json 顺序随渠道`：候选顺序函数与「先请求哪一条」；
 * 3. `P1 维护者名单改候选链`：主地址 → 镜像的回退顺序（与仓库索引同链）；
 * 4. `R-6/R-7 维护者名单的两个口径`（2026-11-11 评审四建议级）：镜像**保留**（与鸣谢名单
 *    不同的理由写在 `MaintainersFeed` 类注释里，这里钉行为锚点）；取数跳数预算
 *    （根索引 3 跳 / 单校 2 跳，主地址 200 时零变化）。
 *
 * 每件都配了咬合探针（把候选推导改坏 → 本文件红），见提交说明/回报。
 */
class UpdateManifestSourcesTest {

    // ── P0：清单候选链 ─────────────────────────────────────────────────────

    @Test
    fun `GitCode 渠道把 GitCode API 排在第一位`() {
        val candidates = appUpdateManifestCandidates(AppUpdateDownloadChannel.GITCODE)
        assertEquals(3, candidates.size)
        assertEquals(AppUpdateManifestSource.GITCODE_API, candidates[0].source)
        assertEquals(gitcodeReleasesApiUrl, candidates[0].url)
        assertEquals(
            listOf(AppUpdateManifestSource.GITHUB_API, AppUpdateManifestSource.RELEASES_PAGE_HTML),
            candidates.drop(1).map { it.source },
        )
    }

    @Test
    fun `GitHub 与 PGYER 渠道把 GitHub API 排在第一位`() {
        for (channel in listOf(AppUpdateDownloadChannel.GITHUB, AppUpdateDownloadChannel.PGYER)) {
            val candidates = appUpdateManifestCandidates(channel)
            assertEquals("channel=$channel", 3, candidates.size)
            assertEquals("channel=$channel", AppUpdateManifestSource.GITHUB_API, candidates[0].source)
            assertEquals("channel=$channel", releasesApiUrl, candidates[0].url)
            assertEquals(
                "channel=$channel",
                listOf(
                    AppUpdateManifestSource.GITHUB_API,
                    AppUpdateManifestSource.RELEASES_PAGE_HTML,
                    AppUpdateManifestSource.GITCODE_API,
                ),
                candidates.map { it.source },
            )
        }
    }

    @Test
    fun `三条候选全是官方直连且互不重复`() {
        for (channel in AppUpdateDownloadChannel.entries) {
            val candidates = appUpdateManifestCandidates(channel)
            assertEquals("channel=$channel", 3, candidates.size)
            assertEquals("channel=$channel 候选去重", 3, candidates.map { it.url }.toSet().size)
            for (candidate in candidates) {
                assertTrue(
                    "清单候选必须是官方直连（镜像对清单有完全控制权，2026-10-19 收紧）：${candidate.url}",
                    isTrustedManifestUrl(candidate.url),
                )
                assertFalse(
                    "镜像前缀不许进清单候选池：${candidate.url}",
                    candidate.url.contains("ghfast.top") ||
                        candidate.url.contains("ghproxy") ||
                        candidate.url.contains("gh-proxy"),
                )
            }
            // 三条固定 URL 都在（裁掉任何一条都会让某种网络环境退回单体超时）。
            assertEquals(
                "channel=$channel",
                setOf(releasesApiUrl, releasesPageUrl, gitcodeReleasesApiUrl),
                candidates.map { it.url }.toSet(),
            )
        }
    }

    // ── P0：三条清单解析核 ────────────────────────────────────────────────

    private val shaHex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

    private fun gitCodeJson(prerelease: Boolean = false, tag: String = "v2.2.0"): String = """
        [
          {
            "tag_name": "$tag",
            "name": "轻屿课表 $tag",
            "body": "本次更新\n\nSHA-256: $shaHex",
            "prerelease": $prerelease,
            "created_at": "2026-11-09T10:00:00Z",
            "assets": [
              {
                "name": "mikcb-${tag.removePrefix("v")}-arm64-v8a.apk",
                "type": "attach",
                "browser_download_url": "https://gitcode.com/mutx/qingyu/releases/download/$tag/mikcb-${tag.removePrefix("v")}-arm64-v8a.apk"
              }
            ]
          }
        ]
    """.trimIndent()

    @Test
    fun `GitCode JSON 解析出版本_直链与正文摘要`() {
        val outcome = parseGitCodeReleasesResponse("2.1.4.1", gitCodeJson(), includePrerelease = false)
        assertTrue("outcome=$outcome", outcome is AppUpdateCheckOutcome.Success)
        val result = (outcome as AppUpdateCheckOutcome.Success).result
        assertTrue("应当有可用更新", result.hasUpdate)
        val release = assertNotNullAndGet(result.latestRelease)
        assertEquals("2.2.0", release.version)
        assertEquals(
            "https://gitcode.com/mutx/qingyu/releases/download/v2.2.0/mikcb-2.2.0-arm64-v8a.apk",
            release.gitcodeDownloadUrl,
        )
        assertEquals(shaHex, release.expectedApkSha256)
        assertTrue("GitCode API 是直连渠道", release.digestFromDirectChannel)
    }

    @Test
    fun `GitCode JSON 默认跳过预发布_开启后可选`() {
        val stable = parseGitCodeReleasesResponse("2.1.4.1", gitCodeJson(prerelease = true), false)
        assertTrue(stable is AppUpdateCheckOutcome.Success)
        assertFalse(
            "includePrerelease=false 时不该拿到预发布",
            (stable as AppUpdateCheckOutcome.Success).result.hasRelease,
        )

        val pre = parseGitCodeReleasesResponse("2.1.4.1", gitCodeJson(prerelease = true), true)
        assertTrue(pre is AppUpdateCheckOutcome.Success)
        val release = (pre as AppUpdateCheckOutcome.Success).result.latestRelease
        assertNotNull(release)
        assertTrue(release!!.isPrerelease)
    }

    @Test
    fun `GitCode JSON 坏响应判 Malformed`() {
        assertEquals(
            AppUpdateCheckOutcome.Malformed,
            parseGitCodeReleasesResponse("2.1.4.1", "not json", false),
        )
        assertEquals(
            AppUpdateCheckOutcome.Malformed,
            parseGitCodeReleasesResponse("2.1.4.1", "{}", false),
        )
    }

    private val releasesPageHtml = """
        <section><h2><a href="/Mutx163/mikcb/releases/tag/v2.0.0">v2.0.0</a></h2><span>Pre-release</span>
        <div data-test-selector="body-content">new</div></section>
        <section><h2><a href="/Mutx163/mikcb/releases/tag/v1.9.0">v1.9.0</a></h2>
        <div data-test-selector="body-content">old</div></section>
    """.trimIndent()

    @Test
    fun `Release 页 HTML 解析出版本与下载直链`() {
        val outcome = parseReleasesPageHtml("1.8.0", releasesPageHtml, includePrerelease = false)
        assertTrue("outcome=$outcome", outcome is AppUpdateCheckOutcome.Success)
        val result = (outcome as AppUpdateCheckOutcome.Success).result
        assertTrue(result.hasUpdate)
        val release = assertNotNullAndGet(result.latestRelease)
        assertEquals("1.9.0", release.version)
        assertEquals(
            "https://github.com/Mutx163/mikcb/releases/download/v1.9.0/mikcb-1.9.0-arm64-v8a.apk",
            release.downloadUrl,
        )
    }

    @Test
    fun `Release 页 HTML 空响应判 Malformed`() {
        assertEquals(
            AppUpdateCheckOutcome.Malformed,
            parseReleasesPageHtml("1.8.0", "", false),
        )
    }

    // ── P1：鸣谢名单候选顺序随渠道 ─────────────────────────────────────────

    @Test
    fun `鸣谢候选顺序随渠道_信任根仍只有两条直连`() {
        assertEquals(
            listOf(SupportDonorsFeed.GITCODE_DONORS_URL, SupportDonorsFeed.DONORS_URL),
            SupportDonorsFeed.donorCandidateUrls(preferGitCode = true),
        )
        assertEquals(
            listOf(SupportDonorsFeed.DONORS_URL, SupportDonorsFeed.GITCODE_DONORS_URL),
            SupportDonorsFeed.donorCandidateUrls(preferGitCode = false),
        )
        for (url in SupportDonorsFeed.donorCandidateUrls(preferGitCode = true)) {
            assertFalse("镜像不许进名单候选（内容可被整份替换）：$url", url.contains("ghfast.top"))
        }
    }

    @Test
    fun `GitCode 渠道时先请求 GitCode 直连`() {
        val donorsJson = "{\"donors\":[]}"
        val envelope = "{\"encoding\":\"base64\",\"content\":\"" +
            java.util.Base64.getEncoder().encodeToString(donorsJson.toByteArray(Charsets.UTF_8)) + "\"}"
        val http = RecordingHttp { url ->
            if (url == SupportDonorsFeed.GITCODE_DONORS_URL) AboutHttpResponse(200, envelope) else null
        }
        val outcome = SupportDonorsFeed(http, preferGitCode = true).fetch()
        assertTrue("outcome=$outcome", outcome is DonorsFetchOutcome.Success)
        assertEquals(SupportDonorsFeed.GITCODE_DONORS_URL, http.requested.first())
    }

    // ── P1：维护者名单候选链（主地址 → 镜像） ─────────────────────────────

    private fun rootYaml() = """
        schools:
          - id: s1
            name: 甲大学
            resource_folder: s1
    """.trimIndent()

    private fun schoolYaml(maintainer: String) = """
        adapters:
          - adapter_id: id-教务A
            adapter_name: 教务A
            asset_js_path: 教务A.js
            maintainer: $maintainer
    """.trimIndent()

    private fun mirrorPrefix() = defaultMirrorUrlPrefix

    @Test
    fun `维护者名单先走主地址_失败再走镜像`() {
        val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")
        val rawRoot = source.buildRawFileUri(WarehouseMaintainersFeed.ROOT_INDEX_PATH).toString()
        val rawAdapters = source.buildRawFileUri("resources/s1/adapters.yaml").toString()
        fun mirrored(url: String) = mirrorPrefix() + url

        val http = RecordingHttp { url ->
            when (url) {
                rawRoot, rawAdapters -> AboutHttpResponse(500, "")
                mirrored(rawRoot) -> AboutHttpResponse(200, rootYaml())
                mirrored(rawAdapters) -> AboutHttpResponse(200, schoolYaml("张三"))
                else -> null
            }
        }

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertTrue("outcome=$outcome", outcome is MaintainersFetchOutcome.Success)
        assertEquals(
            "第一跳必须是主地址（raw 主链），镜像只能兜底",
            rawRoot,
            http.requested.first(),
        )
        assertEquals(
            "主地址 500 后第二跳应是镜像前缀（ghfast）拼出的同一路径",
            mirrored(rawRoot),
            http.requested[1],
        )
        assertEquals(listOf("张三"), (outcome as MaintainersFetchOutcome.Success).groups.map { it.name })
        assertTrue("学校清单也要走同一条链兜底", http.requested.contains(mirrored(rawAdapters)))
    }

    @Test
    fun `GitCode 宿主的回退顺序是 GitCode 主地址再到 GitHub raw`() {
        val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")
            .withHost(WarehouseRepositoryHost.GITCODE)
        val gitcodeRoot = source.buildGitCodeContentsUri(WarehouseMaintainersFeed.ROOT_INDEX_PATH).toString()
        val rawRoot = source.buildRawFileUri(WarehouseMaintainersFeed.ROOT_INDEX_PATH).toString()
        val gitcodeAdapters = source.buildGitCodeContentsUri("resources/s1/adapters.yaml").toString()
        val rawAdapters = source.buildRawFileUri("resources/s1/adapters.yaml").toString()

        val http = RecordingHttp { url ->
            when (url) {
                gitcodeRoot, gitcodeAdapters -> AboutHttpResponse(500, "")
                rawRoot -> AboutHttpResponse(200, rootYaml())
                rawAdapters -> AboutHttpResponse(200, schoolYaml("张三"))
                else -> null
            }
        }

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertTrue("outcome=$outcome", outcome is MaintainersFetchOutcome.Success)
        assertEquals("第一跳必须是 GitCode 主地址", gitcodeRoot, http.requested.first())
        assertEquals("GitCode 主地址失败后回退 GitHub raw", rawRoot, http.requested[1])
        assertEquals(listOf("张三"), (outcome as MaintainersFetchOutcome.Success).groups.map { it.name })
    }

    // ── R-7：维护者名单取数的跳数预算（2026-11-11 评审四建议级） ─────────────

    /**
     * 预算常量本身是「用户愿意等多久」的上界，改大必须先算一遍最坏耗时。
     *
     * 每条候选最坏吃满 `JdkAboutHttp` 的 10s 超时：根索引 3×10s、单校 2×10s。
     * 这里钉死数值（不是「跟常量走」），否则把 2 改成 6 时下面的计数用例会跟着变绿。
     */
    @Test
    fun `取数预算钉死在根索引三跳与单校两跳`() {
        assertEquals(
            "根索引取数预算改动前先算一遍最坏耗时（每跳最坏 10s 超时）",
            3,
            WarehouseMaintainersFeed.MAX_ROOT_INDEX_ATTEMPTS,
        )
        assertEquals(
            "单校取数预算必须 ≤2 跳：222 所学校 × 每跳 10s 就是「读名单读成十分钟」",
            2,
            WarehouseMaintainersFeed.MAX_SCHOOL_ADAPTER_ATTEMPTS,
        )
    }

    /**
     * 主地址 200 时预算一分不花：根索引 1 跳 + 单校 1 跳。
     *
     * 这条是 R-7 的「零变化」半边：加预算不许把成功路径变慢或多发请求。
     */
    @Test
    fun `主地址都通时_根索引与单校各只发一次请求`() {
        val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")
        val rawRoot = source.buildRawFileUri(WarehouseMaintainersFeed.ROOT_INDEX_PATH).toString()
        val rawAdapters = source.buildRawFileUri("resources/s1/adapters.yaml").toString()
        val http = RecordingHttp { url ->
            when (url) {
                rawRoot -> AboutHttpResponse(200, rootYaml())
                rawAdapters -> AboutHttpResponse(200, schoolYaml("张三"))
                else -> null
            }
        }

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertTrue("outcome=$outcome", outcome is MaintainersFetchOutcome.Success)
        assertEquals(
            "主地址都通时必须恰好两跳（根索引 + 单校各一次）；多发的一跳就是白等一次超时",
            listOf(rawRoot, rawAdapters),
            http.requested.toList(),
        )
    }

    /**
     * 根索引全失败：最多 [WarehouseMaintainersFeed.MAX_ROOT_INDEX_ATTEMPTS] 跳就放手。
     *
     * 这条是 R-7 的「有上界」半边：候选链原本最长 6 跳，每跳最坏 10s 超时。
     */
    @Test
    fun `根索引全失败时最多三跳就放手`() {
        val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")
        val http = RecordingHttp { AboutHttpResponse(500, "") }

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertEquals(MaintainersFetchOutcome.Failure("http_500"), outcome)
        assertEquals(
            "根索引取数预算应是 ${WarehouseMaintainersFeed.MAX_ROOT_INDEX_ATTEMPTS} 跳",
            WarehouseMaintainersFeed.MAX_ROOT_INDEX_ATTEMPTS,
            http.requested.size,
        )
    }

    /**
     * 单校全失败：2 跳就放手（原先是主地址 + GitHub raw + 4 个镜像共 5~6 跳）。
     *
     * 同时钉住 R-6 的行为侧：名单链里**仍然有镜像**（第二跳就是镜像前缀）；
     * 谁要把镜像摘掉，这条会先红，然后得去改 `MaintainersFeed` 的 KDoc 理由。
     */
    @Test
    fun `单校直连全失败时最多两跳且第二跳是镜像`() {
        val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")
        val rawRoot = source.buildRawFileUri(WarehouseMaintainersFeed.ROOT_INDEX_PATH).toString()
        val rawAdapters = source.buildRawFileUri("resources/s1/adapters.yaml").toString()
        val http = RecordingHttp { url ->
            if (url == rawRoot) AboutHttpResponse(200, rootYaml()) else AboutHttpResponse(500, "")
        }

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertEquals(
            MaintainersFetchOutcome.Failure(WarehouseMaintainersFeed.REASON_ALL_SCHOOLS_FAILED),
            outcome,
        )
        assertEquals(
            "根索引 1 跳 + 单校 ${WarehouseMaintainersFeed.MAX_SCHOOL_ADAPTER_ATTEMPTS} 跳",
            1 + WarehouseMaintainersFeed.MAX_SCHOOL_ADAPTER_ATTEMPTS,
            http.requested.size,
        )
        assertEquals("第一跳是根索引主地址", rawRoot, http.requested.first())
        assertEquals(
            "单校第二跳必须是镜像兜底（R-6 保留镜像的行为锚点）：${http.requested}",
            mirrorPrefix() + rawAdapters,
            http.requested[2],
        )
    }

    // ── 工具 ──────────────────────────────────────────────────────────────

    private fun <T> assertNotNullAndGet(value: T?): T {
        assertNotNull(value)
        return value as T
    }

    private class RecordingHttp(
        private val respond: (String) -> AboutHttpResponse?,
    ) : AboutHttp {
        val requested = java.util.Collections.synchronizedList(arrayListOf<String>())

        override fun get(url: String): AboutHttpResponse? {
            requested.add(url)
            return respond(url)
        }
    }
}
