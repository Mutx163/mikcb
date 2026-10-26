package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.infra.AppUpdateDownloadChannel

/**
 * 关于页「版本更新」区的纯判据（移植 `lib/screens/about_screen.dart:46-120`，
 * 2026-10-26 快照）。
 *
 * 这批函数在 Dart 侧标着 `@visibleForTesting`，是**刻意抽出来的决策点**：卡片画哪一种
 * 形态、主按钮点下去干什么、镜像探针推荐哪一个。它们不碰 IO，所以能在 JVM 单测里
 * 逐个钉住；渲染层只做「按判据结果画」。
 *
 * ## 为什么这几条判据值得单独钉
 *
 * Dart 源码在 `AboutUpdateCardState` 上留了事故记录（2026-10-19）：`hasRelease` 与
 * `hasUpdate` 混用，导致「已是最新版本」下面挂着一个能点的「立即下载」，点下去装的
 * 还是同一个版本。这类「状态与动作不一致」的 bug 不会崩、只会让人困惑，靠人眼看
 * 容易漏——用测试把两个维度（能不能展示 / 要不要更新）各自钉死才守得住。
 */

// ---------- 更新卡片主按钮去向 ----------

/** Dart `AboutUpdatePrimaryAction`。 */
enum class AboutUpdatePrimaryAction {
    /** 打开 release 页面（没有直链时的兜底）。 */
    OPEN_RELEASE_PAGE,

    /** 应用内下载（Android + GitHub 渠道）。 */
    DOWNLOAD_IN_APP,

    /** 交给浏览器/外部应用打开下载链接。 */
    OPEN_DOWNLOAD_LINK,
}

/**
 * Dart `resolveAboutUpdatePrimaryAction`（`:53-68`）。判定顺序即优先级：
 *
 * 1. 下载地址为空（或只有空白）→ [AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE]；
 * 2. **蒲公英渠道** → [AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK]（始终走浏览器，
 *    不看是不是 Android）；
 * 3. Android → [AboutUpdatePrimaryAction.DOWNLOAD_IN_APP]；
 * 4. 其余平台 → [AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK]。
 *
 * 注意第 2 步在「是不是 Android」之前——顺序颠倒会让蒲公英渠道在 Android 上
 * 变成应用内下载，与 Dart 行为不一致。
 */
fun resolveAboutUpdatePrimaryAction(
    isAndroid: Boolean,
    downloadUrl: String?,
    channel: AppUpdateDownloadChannel,
): AboutUpdatePrimaryAction {
    val hasDownloadUrl = (downloadUrl ?: "").trim().isNotEmpty()
    if (!hasDownloadUrl) {
        return AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE
    }
    if (channel == AppUpdateDownloadChannel.PGYER) {
        return AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK
    }
    if (isAndroid) {
        return AboutUpdatePrimaryAction.DOWNLOAD_IN_APP
    }
    return AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK
}

// ---------- 更新卡片三态 ----------

/** Dart `AboutUpdateCardState`。 */
enum class AboutUpdateCardState {
    /** 没拿到 release：一律按「检查失败」画。 */
    CHECK_FAILED,

    /** 拿到了 release 且版本不高：已是最新。 */
    ALREADY_LATEST,

    /** 拿到了 release 且版本更高：可更新。 */
    UPDATE_AVAILABLE,
}

/**
 * Dart `resolveAboutUpdateCardState`（`:82-88`）：
 * `hasRelease == false` → [AboutUpdateCardState.CHECK_FAILED]（**即便** hasUpdate 为 true，
 * 上游自相矛盾时也按失败处理）；否则按 hasUpdate 分「可更新 / 已是最新」。
 */
fun resolveAboutUpdateCardState(hasRelease: Boolean, hasUpdate: Boolean): AboutUpdateCardState {
    if (!hasRelease) {
        return AboutUpdateCardState.CHECK_FAILED
    }
    return if (hasUpdate) AboutUpdateCardState.UPDATE_AVAILABLE else AboutUpdateCardState.ALREADY_LATEST
}

// ---------- 镜像探针推荐 ----------

/** Dart `AppUpdateMirrorPreset`（`timetable_settings_enums.dart:8`）。 */
enum class MirrorPreset { GHFAST, GH_LLKK, GH_PROXY_COM, GH_PROXY_NET, CUSTOM }

/** Dart `AppUpdateDownloadProbeResult` 里判据用到的那几个字段。 */
data class DownloadProbeResult(
    val isSuccess: Boolean,
    val elapsedMillis: Long,
    val statusCode: Int? = null,
    val message: String? = null,
)

/**
 * Dart `resolveRecommendedMirrorPreset`（`:104-114`）：在**成功**的探针里挑耗时最短的
 * 那个镜像；一个都没成功返回 null。
 *
 * ⚠️ 已知口径差：Dart 的 `List.sort` 是非稳定排序，两条探针耗时**完全相等**时
 * Dart 侧的胜者不保证；这里用稳定排序，平手时取 [probes] 的迭代顺序（即插入顺序）。
 */
fun resolveRecommendedMirrorPreset(
    probes: Map<MirrorPreset, DownloadProbeResult>,
): MirrorPreset? {
    val successful = probes.entries
        .filter { it.value.isSuccess }
        .sortedBy { it.value.elapsedMillis }
    return successful.firstOrNull()?.key
}

/**
 * Dart `resolveMirrorFallbackPreset`（`:116-127`）：在 [availablePresets] 里取第一个
 * **不等于** [currentPreset] 的镜像；没有别的可选就返回 null。
 *
 * 注意「不等于」而不是「排在后面」——当前镜像在列表中间时，回退会取到它**前面**那个，
 * 这是 Dart 的既有行为，不是笔误。
 */
fun resolveMirrorFallbackPreset(
    currentPreset: MirrorPreset,
    availablePresets: List<MirrorPreset>,
): MirrorPreset? {
    for (preset in availablePresets) {
        if (preset != currentPreset) {
            return preset
        }
    }
    return null
}

/**
 * 更新卡片的文案（逐字取自 `lib/l10n/app_zh.arb`，键名写在每行注释里）。
 *
 * 与另外三页同一纪律：测试直读 ARB 对拍。这批文案一开始我按语义"意译"过一版
 * （写成"检查更新失败/请检查网络后重试"），对 ARB 时发现与真原文不符——
 * 已全部改成 ARB 原文，并补上对拍用例，防止再出现"看起来对、其实不一样"。
 */
object AboutUpdateStrings {
    /** aboutUpdateStatusTitle */
    const val statusSectionTitle = "更新状态"

    /** aboutCheckingLatestVersion */
    const val checkingTitle = "正在检查最新版本信息……"

    /** aboutReadVersionFailed */
    const val checkFailedTitle = "检查更新失败，请稍后重试"

    /** aboutReadVersionFailedHint */
    const val checkFailedHint = "如果你当前网络访问 GitHub 不稳定，可稍后再试，或切到下面的国内下载方式后重试"

    /** aboutRefreshCheckTooltip */
    const val retryAction = "重新检查"

    /** aboutUpdateAvailableHeadline */
    const val updateAvailableHeadline = "发现新版本"

    /** aboutAlreadyLatestHeadline */
    const val alreadyLatestHeadline = "已是最新版本"

    /** aboutUpdateNoUpdateHint */
    const val noUpdateHint = "当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测"

    /** aboutViewReleaseAction */
    const val viewReleaseAction = "查看 Release"

    /** aboutDownloadNowAction */
    const val downloadNowAction = "立即下载"

    /** aboutOpenDownloadPageAction */
    const val openDownloadPageAction = "打开下载页"

    /** aboutCurrentVersionLabel */
    const val currentVersionLabel = "当前版本"

    /** aboutLatestVersionLabel */
    const val latestVersionLabel = "最新版本"
}
