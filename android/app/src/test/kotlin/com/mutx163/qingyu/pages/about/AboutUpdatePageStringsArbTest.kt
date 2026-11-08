package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** [AboutUpdatePageStrings] 与 `i18n/app_zh.arb` 逐字对拍（不手抄期望值，直读 ARB）。 */
class AboutUpdatePageStringsArbTest {

    private fun repoFile(relative: String): File {
        val candidates = listOf(
            File("../../$relative"),
            File("../$relative"),
            File(relative),
        )
        return candidates.firstOrNull { it.exists() }
            ?: error("找不到 $relative，工作目录=${File(".").absolutePath}")
    }

    private fun arb(): Map<String, Any?> {
        val json = MiniJson.parse(repoFile("i18n/app_zh.arb").readText(Charsets.UTF_8))
        @Suppress("UNCHECKED_CAST")
        return json as Map<String, Any?>
    }

    @Test
    fun `all screen strings match arb verbatim`() {
        val arb = arb()
        val pairs = mapOf(
            "aboutUpdateScreenTitle" to AboutUpdatePageStrings.screenTitle,
            "aboutCheckingForUpdate" to AboutUpdatePageStrings.checkingForUpdate,
            "aboutUnreleasedLabel" to AboutUpdatePageStrings.unreleasedLabel,
            "aboutReleaseNotesTitle" to AboutUpdatePageStrings.releaseNotesTitle,
            "aboutAdvancedOptionsTitle" to AboutUpdatePageStrings.advancedOptionsTitle,
            "aboutUpdateNoUpdateHint" to AboutUpdatePageStrings.noUpdateHint,
            "aboutUpdatedAt" to AboutUpdatePageStrings.updatedAtTemplate,
            "aboutUpdatePromptTitle" to AboutUpdatePageStrings.updatePromptTitle,
            "aboutUpdatePromptSubtitle" to AboutUpdatePageStrings.updatePromptSubtitle,
            "aboutDownloadChannelSectionTitle" to AboutUpdatePageStrings.downloadChannelSectionTitle,
            "aboutDownloadPackageMethodTitle" to AboutUpdatePageStrings.downloadPackageMethodTitle,
            "aboutInAppDownloadTitle" to AboutUpdatePageStrings.inAppDownloadTitle,
            "aboutInAppDownloadSubtitle" to AboutUpdatePageStrings.inAppDownloadSubtitle,
            "aboutSystemDownloaderTitle" to AboutUpdatePageStrings.systemDownloaderTitle,
            "aboutSystemDownloaderChoiceSubtitle" to AboutUpdatePageStrings.systemDownloaderChoiceSubtitle,
            "aboutCheckPrereleaseTitle" to AboutUpdatePageStrings.checkPrereleaseTitle,
            "aboutCheckPrereleaseSubtitle" to AboutUpdatePageStrings.checkPrereleaseSubtitle,
            "aboutMirrorSectionTitle" to AboutUpdatePageStrings.mirrorSectionTitle,
            "aboutRecommended" to AboutUpdatePageStrings.recommended,
            "aboutProbingMirrors" to AboutUpdatePageStrings.probingMirrors,
            "aboutProbeMirrorsAction" to AboutUpdatePageStrings.probeMirrorsAction,
            "aboutEditCustomMirrorAction" to AboutUpdatePageStrings.editCustomMirrorAction,
            "aboutSetCustomMirrorAction" to AboutUpdatePageStrings.setCustomMirrorAction,
            "aboutFillCustomMirrorFirst" to AboutUpdatePageStrings.fillCustomMirrorFirst,
            "aboutMirrorProbeFailedLabel" to AboutUpdatePageStrings.mirrorProbeFailedLabel,
            "aboutDiagnosticsTitle" to AboutUpdatePageStrings.diagnosticsTitle,
            "aboutViewPhoneLogsAction" to AboutUpdatePageStrings.viewPhoneLogsAction,
            "aboutSetMirrorSourceTitle" to AboutUpdatePageStrings.setMirrorSourceTitle,
            "aboutMirrorPrefixLabel" to AboutUpdatePageStrings.mirrorPrefixLabel,
            "appUpdateMirrorPresetCustomDescription" to AboutUpdatePageStrings.mirrorPresetCustomDescription,
            "aboutDownloadCancelling" to AboutUpdatePageStrings.downloadCancelling,
            "aboutDownloadingBytes" to AboutUpdatePageStrings.downloadingBytesTemplate,
            "aboutDownloadingPercent" to AboutUpdatePageStrings.downloadingPercentTemplate,
            "aboutMirrorUnknownSizeHint" to AboutUpdatePageStrings.mirrorUnknownSizeHint,
            "aboutCancelDownloadAction" to AboutUpdatePageStrings.cancelDownloadAction,
            "aboutInstallReady" to AboutUpdatePageStrings.installReady,
            "aboutSystemDownloaderQueued" to AboutUpdatePageStrings.systemDownloaderQueued,
            "aboutSystemDownloaderFailed" to AboutUpdatePageStrings.systemDownloaderFailed,
            "aboutMirrorSaved" to AboutUpdatePageStrings.mirrorSaved,
            "aboutMirrorPrefixInvalid" to AboutUpdatePageStrings.mirrorPrefixInvalid,
            // 2026-10-29 修「镜像地址编辑只弹 toast」时补的 5 条：全部是**已有** ARB 键的移植，
            // 不是新文案。`serviceMsg*` 属于 Dart 的 service message 表，Kotlin 侧还没有那张表，
            // 所以先按原键名逐字抄进本族 strings（等那张表移植过来后改成查表）。
            "cancelAction" to AboutUpdatePageStrings.cancelAction,
            "confirmAction" to AboutUpdatePageStrings.confirmAction,
            "serviceMsgUpdateDownloadHashMismatch" to AboutUpdatePageStrings.hashMismatch,
            "serviceMsgUpdateSha256UnverifiedRefused" to AboutUpdatePageStrings.sha256Unverified,
            "serviceMsgUpdateOpenInstallerFailed" to AboutUpdatePageStrings.openInstallerFailedTemplate,
        )
        val mismatches = mutableListOf<String>()
        for ((key, actual) in pairs) {
            val expected = arb[key]
            if (expected != actual) mismatches.add("$key: arb=<$expected> model=<$actual>")
        }
        assertTrue("ARB 对拍失败:\n" + mismatches.joinToString("\n"), mismatches.isEmpty())
    }

    @Test
    fun `channel and preset labels match arb`() {
        val arb = arb()
        assertEquals(arb["appUpdateDownloadChannelPgyer"], AboutUpdatePageStrings.channelPgyer)
        assertEquals(arb["appUpdateDownloadChannelGithub"], AboutUpdatePageStrings.channelGithub)
        assertEquals(arb["appUpdateDownloadChannelGitcode"], AboutUpdatePageStrings.channelGitcode)
        assertEquals(
            arb["appUpdateDownloadChannelPgyerDescription"],
            AboutUpdatePageStrings.channelPgyerDescription,
        )
        assertEquals(
            arb["appUpdateDownloadChannelGithubDescription"],
            AboutUpdatePageStrings.channelGithubDescription,
        )
        assertEquals(
            arb["appUpdateDownloadChannelGitcodeDescription"],
            AboutUpdatePageStrings.channelGitcodeDescription,
        )
        assertEquals(arb["appUpdateMirrorPresetGhfast"], AboutUpdatePageStrings.presetGhfast)
        assertEquals(arb["appUpdateMirrorPresetGhLlkk"], AboutUpdatePageStrings.presetGhLlkk)
        assertEquals(arb["appUpdateMirrorPresetGhProxyCom"], AboutUpdatePageStrings.presetGhProxyCom)
        assertEquals(arb["appUpdateMirrorPresetGhproxyNet"], AboutUpdatePageStrings.presetGhproxyNet)
        assertEquals(arb["appUpdateMirrorPresetCustom"], AboutUpdatePageStrings.presetCustom)
    }
}
