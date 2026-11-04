package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.infra.AppReleaseInfo
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.getEffectiveDownloadUrl
import com.mutx163.qingyu.infra.getSystemDownloaderUrl
import com.mutx163.qingyu.infra.releaseListUrlFor
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.icon.extended.Update
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.util.Locale

/**
 * 版本更新页 · Compose 渲染层。
 *
 * 2026-11-04 按已发布 Flutter（`lib/screens/about_screen.dart` 的 `AboutUpdateScreen`，
 * v2.1.4.1）重做观感，修正此前几处"丑点"：
 * - 主操作按钮用**主色**（原为 `buttonColors()` 灰底，看着像禁用/次要）；
 * - "更新说明"只在**一张卡**里出现一次（原先是 `QingyuSectionTitle` + 头部卡 + 正文卡
 *   三处重复"更新说明"、两张相邻卡片，层级散）；
 * - 卡片内边距/间距按 Flutter 的 16 / 8 / 20 分层，不再一律 10dp；
 * - "查看 Release" 改为**居中的文字动作**，不再与主按钮一样做成通栏按钮；
 * - 版本号用正文字阶（13sp）而非 11sp 等宽；检查中文案字号加大。
 *
 * 判据与结构逐段对应 Dart `:605-1720`：顶栏标题 +「高级选项」入口 / 三态（检查中 /
 * 检查失败 / 就绪）/ 就绪=状态卡 + 更新说明卡 / 底部下载进度条。
 * 文案全部取自 [AboutUpdatePageStrings] / [AboutUpdateStrings]（ARB 逐字），本文件无中文字面量。
 */

/** 下载进行时的 UI 快照（宿主每帧喂入）。 */
data class AboutUpdateDownloadUi(
    val downloadedBytes: Long,
    val totalBytes: Long?,
    val cancelling: Boolean = false,
)

@Composable
fun AboutUpdatePage(
    onBack: () -> Unit,
    packageInfoAvailable: Boolean = false,
    checking: Boolean = true,
    result: AppUpdateCheckResult? = null,
    settings: AppUpdateSettings = AppUpdateSettings(),
    appName: String = "",
    download: AboutUpdateDownloadUi? = null,
    onRefresh: () -> Unit = {},
    onOpenAdvancedOptions: () -> Unit = {},
    onOpenUrl: (String?) -> Unit = {},
    onInAppDownload: (url: String, expectedApkSha256: String?, fallbackUrl: String?) -> Unit = { _, _, _ -> },
    onSystemDownload: (url: String) -> Unit = {},
    onSystemDownloadUnavailable: () -> Unit = {},
    onCancelDownload: () -> Unit = {},
) {
    val phase = resolveAboutUpdatePagePhase(packageInfoAvailable, checking, result)

    QingyuPageScaffold(
        title = AboutUpdatePageStrings.screenTitle,
        onBack = onBack,
        actions = {
            IconButton(onClick = onOpenAdvancedOptions) {
                Icon(
                    imageVector = MiuixIcons.Tune,
                    contentDescription = AboutUpdatePageStrings.advancedOptionsTitle,
                )
            }
        },
        bottomBar = {
            if (download != null) {
                DownloadProgressBar(download = download, onCancel = onCancelDownload)
            }
        },
    ) {
        when (phase) {
            AboutUpdatePagePhase.CHECKING -> AboutUpdateCheckingView(
                appName = appName,
                innerPadding = innerPadding,
            )

            AboutUpdatePagePhase.CHECK_FAILED -> AboutUpdateCheckFailedView(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                onRefresh = onRefresh,
            )

            AboutUpdatePagePhase.READY -> AboutUpdateReadyView(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                result = result!!,
                settings = settings,
                onRefresh = onRefresh,
                onOpenUrl = onOpenUrl,
                onInAppDownload = onInAppDownload,
                onSystemDownload = onSystemDownload,
                onSystemDownloadUnavailable = onSystemDownloadUnavailable,
            )
        }
    }
}

/** 应用图标徽标：全族共享 [AboutAppIconBadge]（两层 PNG；历史根因见 PagesCommon 注释）。 */
@Composable
private fun AppIconBadge(size: Dp = 72.dp) {
    AboutAppIconBadge(size = size)
}

@Composable
private fun AboutUpdateCheckingView(appName: String, innerPadding: PaddingValues) {
    val colors = MiuixTheme.colorScheme
    Box(
        modifier = Modifier.fillMaxSize().padding(innerPadding),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AppIconBadge(size = 96.dp)
            if (appName.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                Text(
                    text = appName,
                    style = MiuixTheme.textStyles.title2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = colors.onSurface,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(16.dp))
            CircularProgressIndicator()
            Spacer(Modifier.height(10.dp))
            Text(
                text = AboutUpdatePageStrings.checkingForUpdate,
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun AboutUpdateCheckFailedView(
    innerPadding: PaddingValues,
    scrollBehavior: ScrollBehavior,
    onRefresh: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    QingyuPageList(
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
        verticalArrangement = AboutPageListSpacing,
    ) {
        item(key = "check-failed") {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    AppIconBadge()
                    Spacer(Modifier.height(16.dp))
                    Text(
                        text = AboutUpdateStrings.checkFailedTitle,
                        style = MiuixTheme.textStyles.main,
                        color = colors.onSurface,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(20.dp))
                    Button(
                        onClick = onRefresh,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColorsPrimary(),
                    ) {
                        Text(AboutUpdateStrings.retryAction)
                    }
                }
            }
        }
    }
}

@Composable
private fun AboutUpdateReadyView(
    innerPadding: PaddingValues,
    scrollBehavior: ScrollBehavior,
    result: AppUpdateCheckResult,
    settings: AppUpdateSettings,
    onRefresh: () -> Unit,
    onOpenUrl: (String?) -> Unit,
    onInAppDownload: (url: String, expectedApkSha256: String?, fallbackUrl: String?) -> Unit,
    onSystemDownload: (url: String) -> Unit,
    onSystemDownloadUnavailable: () -> Unit,
) {
    val release = result.latestRelease
    QingyuPageList(
        innerPadding = innerPadding,
        scrollBehavior = scrollBehavior,
        horizontalPadding = QingyuPageCardMargin,
        contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
        verticalArrangement = AboutPageListSpacing,
    ) {
        item(key = "status") {
            AboutUpdateStatusCardFull(
                result = result,
                settings = settings,
                onRefresh = onRefresh,
                onOpenUrl = onOpenUrl,
                onInAppDownload = onInAppDownload,
                onSystemDownload = onSystemDownload,
                onSystemDownloadUnavailable = onSystemDownloadUnavailable,
            )
        }
        if (!release?.body.isNullOrBlank()) {
            item(key = "notes") { NotesSection(release) }
        }
    }
}

@Composable
private fun AboutUpdateStatusCardFull(
    result: AppUpdateCheckResult,
    settings: AppUpdateSettings,
    onRefresh: () -> Unit,
    onOpenUrl: (String?) -> Unit,
    onInAppDownload: (url: String, expectedApkSha256: String?, fallbackUrl: String?) -> Unit,
    onSystemDownload: (url: String) -> Unit,
    onSystemDownloadUnavailable: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val release = result.latestRelease
    val channel = settings.downloadChannel
    val mirrorPrefix = resolveMirrorUrlPrefix(settings.mirrorPreset, settings.mirrorUrlPrefix)
    val effectiveUrl = getEffectiveDownloadUrl(release, channel, settings.downloadSource, mirrorPrefix)
    val primaryAction = resolveAboutUpdatePrimaryAction(
        isAndroid = true,
        downloadUrl = effectiveUrl,
        channel = channel,
    )
    val hasUpdate = result.hasUpdate
    val primaryLabel = when (primaryAction) {
        AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE -> AboutUpdateStrings.viewReleaseAction
        AboutUpdatePrimaryAction.DOWNLOAD_IN_APP -> AboutUpdateStrings.downloadNowAction
        AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK -> AboutUpdateStrings.openDownloadPageAction
    }
    val onPrimary: () -> Unit = {
        when (primaryAction) {
            AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE -> onOpenUrl(release?.releaseUrl)
            AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK -> onOpenUrl(effectiveUrl)
            AboutUpdatePrimaryAction.DOWNLOAD_IN_APP -> {
                if (settings.useSystemDownloader) {
                    val direct = getSystemDownloaderUrl(release, channel)
                    if (direct.isNullOrEmpty()) onSystemDownloadUnavailable() else onSystemDownload(direct)
                } else if (effectiveUrl != null) {
                    val fallback = if (channel == AppUpdateDownloadChannel.GITCODE) release?.downloadUrl else null
                    onInAppDownload(effectiveUrl, release?.expectedApkSha256, fallback)
                }
            }
        }
    }

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AppIconBadge()
            Spacer(Modifier.height(16.dp))
            Text(
                text = if (hasUpdate) {
                    AboutUpdateStrings.updateAvailableHeadline
                } else {
                    AboutUpdateStrings.alreadyLatestHeadline
                },
                style = MiuixTheme.textStyles.main
                    .shiftWeight(if (hasUpdate) QingyuWeightDelta.SEMIBOLD else 0),
                color = if (hasUpdate) colors.primary else colors.onSurface,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            if (hasUpdate) {
                VersionTransition(
                    currentVersion = result.currentVersion,
                    latestVersion = release?.version ?: AboutUpdatePageStrings.unreleasedLabel,
                )
            } else {
                Text(
                    text = "${AboutUpdateStrings.currentVersionLabel} ${result.currentVersion}",
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(Modifier.height(20.dp))
            if (hasUpdate) {
                Button(
                    onClick = onPrimary,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(primaryLabel)
                }
            } else {
                Button(
                    onClick = onRefresh,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(AboutUpdateStrings.retryAction)
                }
            }
            // 「查看 Release」是次级出口：用居中的文字动作，不做第二个通栏按钮（形状别和主按钮抢）。
            if (!hasUpdate || primaryAction != AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE) {
                Spacer(Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    TextButton(
                        text = AboutUpdateStrings.viewReleaseAction,
                        onClick = { onOpenUrl(releaseListUrlFor(channel)) },
                    )
                }
            }
        }
    }
}

/** Dart `_buildVersionTransition`：旧版本弱化 → 箭头 → 新版本强调（版本号走正文字阶，不用等宽）。 */
@Composable
private fun VersionTransition(currentVersion: String, latestVersion: String) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = currentVersion,
            style = MiuixTheme.textStyles.footnote1,
            color = colors.onSurfaceVariantSummary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
        Spacer(Modifier.width(6.dp))
        Text(text = "→", style = MiuixTheme.textStyles.footnote1, color = colors.onSurfaceVariantSummary)
        Spacer(Modifier.width(6.dp))
        Text(
            text = latestVersion,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = colors.primary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
    }
}

/**
 * 「更新说明」卡：一张卡里做「头部（更新图标 + 标题 + 更新时间）→ 分隔线 → 正文」，
 * 与 Flutter `_buildNotesHeader` / `_buildNotesDigest` + `_buildNotesSurface` 同构。
 *
 * 以前这里是 `QingyuSectionTitle` + 独立头部卡 + 独立正文卡：一屏出现三次「更新说明」、
 * 两张相邻卡片，层级又散又重复——这是"丑"的主因之一。
 */
@Composable
private fun NotesSection(release: AppReleaseInfo?) {
    val colors = MiuixTheme.colorScheme
    val body = release?.body.orEmpty()
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = MiuixIcons.Update,
                        contentDescription = null,
                        tint = colors.primary,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = AboutUpdatePageStrings.releaseNotesTitle,
                        style = MiuixTheme.textStyles.main,
                        color = colors.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                release?.updatedAtMillis?.let { millis ->
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = AboutUpdatePageStrings.updatedAt(formatUpdateDateTime(millis)),
                        style = MiuixTheme.textStyles.footnote1,
                        color = colors.onSurfaceVariantSummary,
                    )
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(colors.secondaryContainer),
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 16.dp),
            ) {
                NotesBodyContent(body)
            }
        }
    }
}

/** Dart `_buildNotesDigest` / `_buildNotesBlock`：有可解析条目画摘要，否则退回原文分块纯文本。 */
@Composable
private fun NotesBodyContent(body: String) {
    val colors = MiuixTheme.colorScheme
    val digest = remember(body) { buildReleaseNotesDigest(body) }
    val markdownBlocks = remember(body) {
        if (digest.isEmpty) buildReleaseNotesMarkdownBlocks(body, stripVersionHeading = true) else emptyList()
    }

    if (digest.isEmpty) {
        if (markdownBlocks.isEmpty()) {
            Text(
                text = AboutUpdatePageStrings.noUpdateHint,
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
                lineHeight = 20.sp,
            )
        } else {
            ReleaseNotesMarkdownView(markdownBlocks)
        }
    } else {
        ExpandedDigest(digest)
    }
}

/** 更新重点 + 分类计数；完整条目默认收起、点开铺开（共享件，与更新日志页同一形态）。
 *
 *  与 Dart 的刻意分歧（Dart `initiallyExpanded: true`）：一版动辄几十条全部铺开会把
 *  状态卡挤出一整屏灰字；现在重点行 + 计数常显，全文在「查看全部 N 项」后面，
 *  信息一条不少、首屏只给重点。展开/收起文案复用更新日志页的既有 ARB 键。 */
@Composable
private fun ExpandedDigest(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = ChangelogStrings.highlightsTitle,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = colors.onSurfaceVariantSummary,
        )
        Spacer(Modifier.height(8.dp))
        for (highlight in digest.highlights) {
            ReleaseNotesHighlightRow(highlight)
        }
        val counts = releaseChangeCounts(digest)
        if (counts.isNotEmpty()) {
            Spacer(Modifier.height(2.dp))
            Text(
                text = counts.joinToString(" · ") { "${it.first} ${it.second}" },
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
            )
        }
        ReleaseNotesExpandableBody(digest)
    }
}

/** 底部下载进度条（Dart `_buildDownloadProgressBar`）。 */
@Composable
private fun DownloadProgressBar(download: AboutUpdateDownloadUi, onCancel: () -> Unit) {
    val colors = MiuixTheme.colorScheme
    val progress = resolveDownloadProgress(download.downloadedBytes, download.totalBytes)
    val text = when {
        download.cancelling -> AboutUpdatePageStrings.downloadCancelling
        progress.fraction != null ->
            AboutUpdatePageStrings.downloadingPercent(String.format(Locale.US, "%.1f", progress.fraction * 100))
        else -> AboutUpdatePageStrings.downloadingBytes(formatBytes(download.downloadedBytes))
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surface)
            .padding(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 16.dp),
    ) {
        Text(text = text, style = MiuixTheme.textStyles.body2, color = colors.primary)
        if (progress.fraction == null && download.downloadedBytes > 0) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = AboutUpdatePageStrings.mirrorUnknownSizeHint,
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
            )
        }
        Spacer(Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(colors.secondaryContainer),
        ) {
            val fraction = progress.fraction
            if (fraction != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction.toFloat())
                        .height(8.dp)
                        .background(colors.primary),
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(
                text = if (download.cancelling) {
                    AboutUpdatePageStrings.downloadCancelling
                } else {
                    AboutUpdatePageStrings.cancelDownloadAction
                },
                onClick = onCancel,
                enabled = !download.cancelling,
            )
        }
    }
}
