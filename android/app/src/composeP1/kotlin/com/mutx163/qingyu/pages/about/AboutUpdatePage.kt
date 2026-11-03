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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
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
 * 版本更新页 · Compose 渲染层（1:1 复刻 `lib/screens/about_screen.dart` 的 `AboutUpdateScreen`，
 * `:605-1720`）。判据与本页结构逐段对应：
 *
 * - 顶栏：标题「版本更新」+ 右上角「高级选项」入口（Dart `suffixes: FHeaderAction(tune)`）；
 * - 三态（[AboutUpdatePagePhase]）：检查中 / 检查失败 / 就绪；
 * - 就绪：状态卡（图标 / 标题 / 版本迁移或当前版本 / 主按钮 / 查看 Release）+
 *   「更新说明」头 + 摘要（更新重点 + 分类计数 + 分组条目；解析不出条目时退回原文分块）；
 * - 底部：下载进行时的进度条（Dart `_buildDownloadProgressBar`）。
 *
 * 本文件只画；数据与副作用（检查 / 下载 / 打开链接 / 进高级选项）由宿主经回调注入。
 * 全部屏上文案取自 [AboutUpdatePageStrings] / [AboutUpdateStrings]（ARB 逐字），本文件无中文字面量。
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
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AppIconBadge(size = 96.dp)
            if (appName.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                Text(
                    text = appName,
                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = colors.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(16.dp))
            // 进行中反馈（2026-11-03 补）：原先只有一行灰字、连转圈都没有，
            // 「点了重新检查没反应」的观感就来自这里。官方指示器 + 文案同屏。
            CircularProgressIndicator()
            Spacer(Modifier.height(12.dp))
            Text(
                text = AboutUpdatePageStrings.checkingForUpdate,
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
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
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    AppIconBadge()
                    Text(
                        text = AboutUpdateStrings.checkFailedTitle,
                        style = MiuixTheme.textStyles.main,
                        color = colors.onSurface,
                    )
                    Button(
                        onClick = onRefresh,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(),
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
        item(key = "notes-title") { QingyuSectionTitle(AboutUpdatePageStrings.releaseNotesTitle) }
        item(key = "notes-header") { NotesHeaderCard(release) }
        item(key = "notes-body") { NotesBodyCard(release?.body.orEmpty()) }
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
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            AppIconBadge()
            Text(
                text = if (hasUpdate) {
                    AboutUpdateStrings.updateAvailableHeadline
                } else {
                    AboutUpdateStrings.alreadyLatestHeadline
                },
                style = MiuixTheme.textStyles.main
                    .shiftWeight(if (hasUpdate) QingyuWeightDelta.SEMIBOLD else 0),
                color = if (hasUpdate) colors.primary else colors.onSurface,
            )
            if (hasUpdate) {
                VersionTransition(
                    currentVersion = result.currentVersion,
                    latestVersion = release?.version ?: AboutUpdatePageStrings.unreleasedLabel,
                )
            } else {
                Text(
                    text = "${AboutUpdateStrings.currentVersionLabel} ${result.currentVersion}",
                    style = MiuixTheme.textStyles.footnote1.copy(fontFamily = FontFamily.Monospace),
                    color = colors.onSurfaceVariantSummary,
                )
            }
            if (hasUpdate) {
                Button(
                    onClick = onPrimary,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(primaryLabel)
                }
            } else {
                TextButton(
                    text = AboutUpdateStrings.retryAction,
                    onClick = onRefresh,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (!hasUpdate || primaryAction != AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE) {
                TextButton(
                    text = AboutUpdateStrings.viewReleaseAction,
                    onClick = { onOpenUrl(releaseListUrlFor(channel)) },
                )
            }
        }
    }
}

/** Dart `_buildVersionTransition`：旧版本弱化 → 箭头 → 新版本强调。版本号用等宽字体，数字对齐干净。 */
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
            style = MiuixTheme.textStyles.footnote1.copy(fontFamily = FontFamily.Monospace),
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
            style = MiuixTheme.textStyles.footnote1
                .copy(fontFamily = FontFamily.Monospace)
                .shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = colors.primary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
    }
}

/** Dart `_buildNotesHeader`：更新图标 + 「更新说明」+「更新于 …」。 */
@Composable
private fun NotesHeaderCard(release: AppReleaseInfo?) {
    val colors = MiuixTheme.colorScheme
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(imageVector = MiuixIcons.Update, contentDescription = null, tint = colors.primary)
            Spacer(Modifier.width(8.dp))
            Text(
                text = AboutUpdatePageStrings.releaseNotesTitle,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.SEMIBOLD),
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
}

/** Dart `_buildNotesDigest` / `_buildNotesBlock`：有可解析条目画摘要，否则退回原文分块纯文本。 */
@Composable
private fun NotesBodyCard(body: String) {
    val colors = MiuixTheme.colorScheme
    val digest = remember(body) { buildReleaseNotesDigest(body) }
    val markdownBlocks = remember(body) {
        if (digest.isEmpty) buildReleaseNotesMarkdownBlocks(body, stripVersionHeading = true) else emptyList()
    }

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
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
