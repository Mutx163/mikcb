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
 * 2026-11-08 全面优化（两轮）：第一轮对着官方 `miuix-demo` 的 `AboutPage` 去掉了垂直居中；
 * 第二轮按用户指定的参照（外部同类应用的更新页）重做状态区：
 *
 * - **取消身份块**：图标 + 居中标题 + 版本号那一堆东西全部不要了。参照页没有任何图标，
 *   状态就是一张普通卡里的两行字（「当前版本」+ 版本号）。
 * - **状态收进行尾**：「已是最新 / 有更新」只作为一个短标签挂在「重新检查」行的
 *   `endActions` 里，不再占一整块版面；有更新时另起「最新版本」区块 + 主按钮。
 * - **列表顶对齐**（去掉 `AboutPageListSpacingCentered`）：居中把约 165dp 空白搬到
 *   标题栏下方，被读成「没加载出来」。
 * - 「更新说明」回到 `QingyuSectionTitle` 卡外分组标题（28dp 轴线）；卡内不再重复一行
 *   「更新重点」小标题。
 * - `更新于 {时间}` 从卡首通栏降到卡尾弱色元信息：日期不该是这张卡最先被读到的内容。
 * - 行控件一律用官方 `ArrowPreference`（满行触控 + 右侧箭头），不再用裸文字当按钮。
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

    // 参照同类应用的更新页骨架：那边**没有大图标 + 居中状态块**，整个状态区就是一张卡里的
    // 两行文字（「当前版本」+ 版本号），下面才是可点行；「已是最新」只做一个行尾短标签。
    // 我们照这个骨架来：版本是陈述，行是动作，两者都不占整屏。
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // ── 版本块：两行普通文字，不再有图标与居中堆叠 ──
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp),
            ) {
                Text(
                    text = AboutUpdateStrings.currentVersionLabel,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = colors.onSurface,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = result.currentVersion,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            // 有更新：最新版本单独一行（主题色）+ 本页唯一的主按钮，仍在同一张卡里。
            // 不做「旧 → 新」的箭头行：把当前/最新拆成两个区块，读起来比箭头更直白。
            if (hasUpdate) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                ) {
                    Text(
                        text = AboutUpdateStrings.latestVersionLabel,
                        style = MiuixTheme.textStyles.footnote1,
                        color = colors.onSurfaceVariantActions,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = release?.version ?: AboutUpdatePageStrings.unreleasedLabel,
                        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = colors.primary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(Modifier.height(14.dp))
                    Button(
                        onClick = onPrimary,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColorsPrimary(),
                    ) {
                        Text(primaryLabel)
                    }
                    Spacer(Modifier.height(14.dp))
                }
            }

            // ── 可点行：检查/重新检查，行尾只挂一个状态词（`endActions` 手法）──
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(colors.secondaryContainer),
            )
            ArrowPreference(
                title = AboutUpdateStrings.retryAction,
                endActions = {
                    Text(
                        text = if (hasUpdate) {
                            AboutUpdateStrings.updateAvailableHeadline
                        } else {
                            AboutUpdateStrings.alreadyLatestHeadline
                        },
                        style = MiuixTheme.textStyles.footnote1,
                        color = if (hasUpdate) colors.primary else colors.onSurfaceVariantSummary,
                    )
                },
                onClick = onRefresh,
            )
            // 主按钮已经是「查看 Release」时不再重复给行，避免两处同一动作。
            if (!hasUpdate || primaryAction != AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE) {
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
