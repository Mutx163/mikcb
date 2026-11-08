package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
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
import com.mutx163.qingyu.components.QingyuGlassIconButton
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
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.preference.ArrowPreference
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
 * 2026-11-08 全面优化（对着官方 `miuix-demo` 的 `AboutPage` 找参照）：
 * - 列表改**顶对齐**（去掉 `AboutPageListSpacingCentered`）：居中把约 165dp 空白搬到
 *   标题栏下方，被读成「没加载出来」；demo 的身份块也是从顶部开始的。
 * - 标题抬到 `title2 + SEMIBOLD`，图标 72 → 64dp：标题和版本号之间要有明显的字重落。
 * - 动作从「两个等重蓝色文字链」改成官方 `ArrowPreference` 行（满行触控 + 右侧箭头），
 *   与身份块用 1dp 细线分开：上面是「什么状态」，下面是「能做什么」。
 * - 「更新说明」回到 `QingyuSectionTitle` 卡外分组标题（28dp 轴线）；卡内不再重复一行
 *   「更新重点」小标题。
 * - `更新于 {时间}` 从卡首通栏降到卡尾弱色元信息：日期不该是这张卡最先被读到的内容。
 *
 * 判据与结构逐段对应 Dart `:605-1720`：顶栏标题 +「高级选项」入口 / 三态（检查中 /
 * 检查失败 / 就绪）/ 就绪=状态卡 + 更新说明分组 + 说明卡 / 底部下载进度条。
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
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
        actions = {
            QingyuGlassIconButton(
                onClick = onOpenAdvancedOptions,
                contentDescription = AboutUpdatePageStrings.advancedOptionsTitle,
                icon = MiuixIcons.Tune,
            )
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

/** 应用图标徽标：全族共享 [AboutAppIconBadge]（单层干净图标；历史根因见 PagesCommon 注释）。 */
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
            AppIconBadge()
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
    onRefresh: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Box(
        modifier = Modifier.fillMaxSize().padding(innerPadding),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 32.dp),
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
            Spacer(Modifier.height(12.dp))
            InlineTextAction(text = AboutUpdateStrings.retryAction, onClick = onRefresh)
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
        // 2026-11-08 版面重排：改成**顶对齐**。原先的 `AboutPageListSpacingCentered` 把整组
        // 内容垂直居中，结果标题栏下面空出约 165dp，被读成「内容没加载出来」；空白放在
        // 视觉动线起点比放在底部更刺眼。现在内容从顶栏下 8dp 开始，空白只留在末尾。
        extraTopPadding = 8.dp,
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
            // 分组标题走官方 SmallTitle 包装（28dp 轴线）。状态卡不再自称「这次更新」之后，
            // 这里就是说明块唯一的入口，不会出现「一条信息说三遍」。列表已统一加 12dp
            // 横向留白，所以标题内边距给 16dp 才能和卡内文字一起落在 28dp 轴线上。
            item(key = "notes-title") {
                QingyuSectionTitle(
                    text = AboutUpdatePageStrings.releaseNotesTitle,
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                )
            }
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
    val openReleaseList: () -> Unit = { onOpenUrl(releaseListUrlFor(channel)) }

    // 卡内不再放 16dp 统一内边距：上半是自排的身份块（居中、20/16），下半是官方
    // ArrowPreference 行（自带 16dp），两者要各自控制内边距，否则行会缩进成 32dp。
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, top = 20.dp, end = 16.dp, bottom = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AppIconBadge(size = 64.dp)
            Spacer(Modifier.height(12.dp))
            Text(
                text = if (hasUpdate) {
                    AboutUpdateStrings.updateAvailableHeadline
                } else {
                    AboutUpdateStrings.alreadyLatestHeadline
                },
                // 标题抬到 title2 + 半粗：标题和版本号只差一级半粗度不够时，
                // 全卡最宽的那行（版本号）会抢走视觉重心。
                style = MiuixTheme.textStyles.title2
                    .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = if (hasUpdate) colors.primary else colors.onSurface,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(6.dp))
            if (hasUpdate) {
                VersionTransition(
                    currentVersion = result.currentVersion,
                    latestVersion = release?.version ?: AboutUpdatePageStrings.unreleasedLabel,
                )
                Spacer(Modifier.height(18.dp))
                // 只有「有更新」才用醒目的主按钮下载——本页唯一的主操作。
                Button(
                    onClick = onPrimary,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(primaryLabel)
                }
            } else {
                // 已是最新：版本号降级成一行弱化小字（单行省略，技术串不许把卡撑宽）。
                Text(
                    text = result.currentVersion,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        // 动作区：身份块陈述「现在是什么状态」，这一块才回答「我能做什么」。
        // 用一根 1dp 细线分开，动作换成官方 ArrowPreference 行（自带 16dp 内边距、
        // 满行触控高度与右侧箭头）——比两个等重的蓝色文字链挤在卡片中间清楚得多，
        // 也不会再把 30dp 高的裸文字当按钮。
        val showReleaseRow = !hasUpdate || primaryAction != AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE
        if (showReleaseRow) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(colors.secondaryContainer),
            )
            if (hasUpdate) {
                ArrowPreference(title = AboutUpdateStrings.viewReleaseAction, onClick = openReleaseList)
            } else {
                ArrowPreference(title = AboutUpdateStrings.retryAction, onClick = onRefresh)
                ArrowPreference(title = AboutUpdateStrings.viewReleaseAction, onClick = openReleaseList)
            }
        }
    }
}

/**
 * 一行纯文字动作：主色可点、无底色、无药丸背景——用于「检查失败 → 重新检查」这种唯一出口。
 *
 * 触控区最小 44dp（高）12dp（横向内边距）：之前是 30dp 高的裸文字，手指按不准；
 * 视觉尺寸不变，靠透明热区把命中范围扩大。
 */
@Composable
private fun InlineTextAction(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .heightIn(min = 44.dp)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = MiuixTheme.colorScheme.primary,
        )
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
 * 更新说明正文卡：**不再贴「更新说明」标题与装饰图标**——分组标题已经在卡外说明这是什么，
 * 卡片正文直接就是更新内容（用户原则：让布局自己说话、一条信息只出现一次）。
 *
 * 2026-11-08：`更新于 {时间}` 从**卡首通栏**降到**卡尾弱色元信息**。日期放在最上面时，
 * 它是这张卡里最先被读到的内容，而它恰恰是最不重要的；通栏细线还把圆角卡切成两段。
 * 现在信息次序是「重点 → 计数 → 展开 → 时间」，时间作为出处收尾。
 */
@Composable
private fun NotesSection(release: AppReleaseInfo?) {
    val colors = MiuixTheme.colorScheme
    val body = release?.body.orEmpty()
    val updatedText = release?.updatedAtMillis?.let {
        AboutUpdatePageStrings.updatedAt(formatUpdateDateTime(it))
    }
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 16.dp),
            ) {
                NotesBodyContent(body)
            }
            if (updatedText != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(colors.secondaryContainer),
                )
                Text(
                    text = updatedText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, top = 10.dp, end = 16.dp, bottom = 14.dp),
                )
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
 *  文案堆成一整屏灰字；现在重点行 + 计数常显，全文在「查看全部 N 项」后面，
 *  信息一条不少、首屏只给重点。
 *
 *  2026-11-08：删掉卡内的「更新重点」小标题——卡外已经有「更新说明」分组标题，
 *  再压一行灰字就是同一句话说两遍；重点直接以列表开场，计数字接在列表尾部。 */
@Composable
private fun ExpandedDigest(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    Column(modifier = Modifier.fillMaxWidth()) {
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
