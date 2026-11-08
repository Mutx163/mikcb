package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 关于页更新判据测试。
 *
 * 期望值来源（独立于实现）：逐条对照 `about_screen.dart:53-127` 的判定顺序与分支，
 * 含 Dart 源码注释里记着的事故场景（hasRelease/hasUpdate 混用）。
 */
class AboutUpdateLogicTest {

    // ---------- 主按钮去向 ----------

    @Test
    fun `没有下载地址时打开release页`() {
        for (url in listOf(null, "", "   ")) {
            assertEquals(
                "url=$url",
                AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE,
                resolveAboutUpdatePrimaryAction(
                    isAndroid = true,
                    downloadUrl = url,
                    channel = AppUpdateDownloadChannel.GITHUB,
                ),
            )
        }
    }

    @Test
    fun `蒲公英渠道始终走外部链接`() {
        // Dart :62-65 —— 这条在 isAndroid 判断之前，Android 上也一样走浏览器。
        assertEquals(
            AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK,
            resolveAboutUpdatePrimaryAction(
                isAndroid = true,
                downloadUrl = "https://example.com/x.apk",
                channel = AppUpdateDownloadChannel.PGYER,
            ),
        )
    }

    @Test
    fun `github渠道在安卓上应用内下载`() {
        assertEquals(
            AboutUpdatePrimaryAction.DOWNLOAD_IN_APP,
            resolveAboutUpdatePrimaryAction(
                isAndroid = true,
                downloadUrl = "https://example.com/x.apk",
                channel = AppUpdateDownloadChannel.GITHUB,
            ),
        )
    }

    @Test
    fun `非安卓平台走外部链接`() {
        assertEquals(
            AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK,
            resolveAboutUpdatePrimaryAction(
                isAndroid = false,
                downloadUrl = "https://example.com/x.apk",
                channel = AppUpdateDownloadChannel.GITHUB,
            ),
        )
    }

    @Test
    fun `gitcode渠道与github同档`() {
        // Dart 只对 pgyer 特判，其余渠道一视同仁。
        assertEquals(
            AboutUpdatePrimaryAction.DOWNLOAD_IN_APP,
            resolveAboutUpdatePrimaryAction(
                isAndroid = true,
                downloadUrl = "https://gitcode.com/mutx/qingyu/releases/download/v1/x.apk",
                channel = AppUpdateDownloadChannel.GITCODE,
            ),
        )
    }

    // ---------- 卡片三态 ----------

    @Test
    fun `没拿到release一律检查失败`() {
        assertEquals(
            AboutUpdateCardState.CHECK_FAILED,
            resolveAboutUpdateCardState(hasRelease = false, hasUpdate = false),
        )
    }

    @Test
    fun `没拿到release时即使上游说可更新也按失败处理`() {
        // Dart :79-80 —— 上游自相矛盾的输入（既装不了也说不清）不能画成可更新，
        // 否则就是 2026-10-19 那个「已是最新下面挂着能点的立即下载」的翻版。
        assertEquals(
            AboutUpdateCardState.CHECK_FAILED,
            resolveAboutUpdateCardState(hasRelease = false, hasUpdate = true),
        )
    }

    @Test
    fun `拿到release且版本更高是可更新`() {
        assertEquals(
            AboutUpdateCardState.UPDATE_AVAILABLE,
            resolveAboutUpdateCardState(hasRelease = true, hasUpdate = true),
        )
    }

    @Test
    fun `拿到release且版本不高是最新`() {
        assertEquals(
            AboutUpdateCardState.ALREADY_LATEST,
            resolveAboutUpdateCardState(hasRelease = true, hasUpdate = false),
        )
    }

    // ---------- 镜像推荐 ----------

    private fun probe(success: Boolean, millis: Long) = DownloadProbeResult(success, millis)

    @Test
    fun `一个都没成功返回null`() {
        assertNull(
            resolveRecommendedMirrorPreset(
                mapOf(
                    MirrorPreset.GHFAST to probe(false, 10),
                    MirrorPreset.GH_PROXY_COM to probe(false, 20),
                ),
            ),
        )
    }

    @Test
    fun `空探针表返回null`() {
        assertNull(resolveRecommendedMirrorPreset(emptyMap()))
    }

    @Test
    fun `在成功的里面挑最快的`() {
        assertEquals(
            MirrorPreset.GH_PROXY_COM,
            resolveRecommendedMirrorPreset(
                mapOf(
                    MirrorPreset.GHFAST to probe(true, 300),
                    MirrorPreset.GH_PROXY_COM to probe(true, 120),
                    MirrorPreset.GH_LLKK to probe(false, 50), // 更快但失败，不参与
                ),
            ),
        )
    }

    @Test
    fun `全部成功时取最慢也不要失败的`() {
        assertEquals(
            MirrorPreset.GH_LLKK,
            resolveRecommendedMirrorPreset(
                mapOf(
                    MirrorPreset.GHFAST to probe(true, 900),
                    MirrorPreset.GH_LLKK to probe(true, 200),
                ),
            ),
        )
    }

    // ---------- 镜像回退 ----------

    @Test
    fun `回退取第一个不等于当前的`() {
        // Dart :116-127 —— 注意是「不等于」而不是「排在后面」：当前在中间时，
        // 回退会取到它前面那个。
        assertEquals(
            MirrorPreset.GHFAST,
            resolveMirrorFallbackPreset(
                currentPreset = MirrorPreset.GH_PROXY_COM,
                availablePresets = listOf(
                    MirrorPreset.GHFAST,
                    MirrorPreset.GH_PROXY_COM,
                    MirrorPreset.GH_PROXY_NET,
                ),
            ),
        )
    }

    @Test
    fun `只有一个可选且就是当前时返回null`() {
        assertNull(
            resolveMirrorFallbackPreset(
                currentPreset = MirrorPreset.CUSTOM,
                availablePresets = listOf(MirrorPreset.CUSTOM),
            ),
        )
    }

    @Test
    fun `空列表返回null`() {
        assertNull(
            resolveMirrorFallbackPreset(
                currentPreset = MirrorPreset.GHFAST,
                availablePresets = emptyList(),
            ),
        )
    }

    // ---------- 文案与 ARB 对拍 ----------

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../i18n/app_zh.arb"),
            File("../i18n/app_zh.arb"),
            File("i18n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 i18n/app_zh.arb，工作目录=" + File(".").absolutePath)
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 " + key)
    }

    @Test
    fun `更新卡片文案与ARB逐字一致`() {
        // 这批文案第一版是"意译"的（"检查更新失败/请检查网络后重试"），
        // 与 ARB 真原文不符，被这条对拍抓住后改成原文。
        val pairs = listOf(
            "aboutUpdateStatusTitle" to AboutUpdateStrings.statusSectionTitle,
            "aboutCheckingLatestVersion" to AboutUpdateStrings.checkingTitle,
            "aboutReadVersionFailed" to AboutUpdateStrings.checkFailedTitle,
            "aboutReadVersionFailedHint" to AboutUpdateStrings.checkFailedHint,
            "aboutRefreshCheckTooltip" to AboutUpdateStrings.retryAction,
            "aboutUpdateAvailableHeadline" to AboutUpdateStrings.updateAvailableHeadline,
            "aboutAlreadyLatestHeadline" to AboutUpdateStrings.alreadyLatestHeadline,
            "aboutUpdateNoUpdateHint" to AboutUpdateStrings.noUpdateHint,
            "aboutViewReleaseAction" to AboutUpdateStrings.viewReleaseAction,
            "aboutDownloadNowAction" to AboutUpdateStrings.downloadNowAction,
            "aboutOpenDownloadPageAction" to AboutUpdateStrings.openDownloadPageAction,
            "aboutCurrentVersionLabel" to AboutUpdateStrings.currentVersionLabel,
            "aboutLatestVersionLabel" to AboutUpdateStrings.latestVersionLabel,
        )
        for ((key, value) in pairs) {
            assertEquals("ARB 键 " + key + " 与模型不一致", arbString(key), value)
        }
    }
}
