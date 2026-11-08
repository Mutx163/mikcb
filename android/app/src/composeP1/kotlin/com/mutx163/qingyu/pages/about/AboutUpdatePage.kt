package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.app.CommonUiStrings
import com.mutx163.qingyu.components.LocalQingyuPageIsRootEntry
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
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
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Surface
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
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

    // 顶栏：本页不要标题，只留左右两颗胶囊。
    //
    // 骨架的 actions 槽是个 RowScope，且被摆在整条栏的最右侧；这里让它铺满整栏，
    // 用 SpaceBetween 把「返回」与「高级选项」分别顶到两端。
    // 骨架自带的返回键必须关掉——否则它会在 x=0 再画一颗箭头，和左胶囊叠成两个返回。
    // 关掉的方式沿用壳注入的同一个标记（本页自己 provide true，只影响这一棵子树）。
    CompositionLocalProvider(LocalQingyuPageIsRootEntry provides true) {
        QingyuPageScaffold(
            title = "",
            onBack = onBack,
            smallTopBar = true,
            actions = {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 8.dp, end = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    UpdateBarCapsule(
                        icon = MiuixIcons.Back,
                        contentDescription = CommonUiStrings.back,
                        onClick = onBack,
                    )
                    UpdateBarCapsule(
                        icon = MiuixIcons.Tune,
                        contentDescription = AboutUpdatePageStrings.advancedOptionsTitle,
                        onClick = onOpenAdvancedOptions,
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
                    onRefresh = onRefresh,
                )

                AboutUpdatePagePhase.READY -> AboutUpdateReadyView(
                    innerPadding = innerPadding,
                    scrollBehavior = scrollBehavior,
                    appName = appName,
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
}

/**
 * 顶栏胶囊按钮：左右两颗同形（56×36，两端全圆），容器白底 + 1dp 细边。
 *
 * 只承担导航与设置两个动作，不参与页面其余层级的强调色——强调色留给渐变、版本号与主按钮。
 */
@Composable
private fun UpdateBarCapsule(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(percent = 50),
        color = colors.surface,
        border = BorderStroke(1.dp, colors.secondaryContainer),
        shadowElevation = 0.dp,
    ) {
        Box(
            modifier = Modifier.size(width = 56.dp, height = 36.dp),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = contentDescription,
                tint = colors.onSurfaceVariantActions,
                modifier = Modifier.size(20.dp),
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
    appName: String,
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
        // 横向留白改为由每个块自己带：顶部身份区需要一层**通栏**的背景渐变，
        // 列表级 padding 会把渐变裁在两侧 12dp 里，边界看得见。
        horizontalPadding = 0.dp,
        contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
        verticalArrangement = AboutPageListSpacing,
    ) {
        item(key = "hero") {
            UpdateHeroBlock(appName = appName, version = result.currentVersion)
        }
        item(key = "status") {
            AboutUpdateStatusCardFull(
                modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
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
            // 分组标题用默认 28dp 内边距：列表本身不再加横向留白，28 = 卡外 12 + 卡内 16，
            // 正好和卡里的文字落在同一条轴线上。
            item(key = "notes-title") {
                QingyuSectionTitle(text = AboutUpdatePageStrings.releaseNotesTitle)
            }
            item(key = "notes") {
                NotesSection(
                    release = release,
                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                )
            }
        }
    }
}

/**
 * 顶部身份区：图标 + 软件名 + 版本号，背后一层**主色渐变**向下淡出。
 *
 * 渐变只用主题主色推透明度（上 8% → 中 3% → 透明），不引第二套色板；
 * 头一档压得低，是因为内容从顶栏下方开始，而顶栏那条是模糊后的页底色：
 * 首档太重会在顶栏下沿留一道看得见的接缝。
 * 高度跟随内容（图标 80、名称一行、版本一行 + 上下留白 ≈ 190dp），不用固定高度硬撑。
 * 这一块是整页唯一的装饰，下面的卡片全部是白底/容器色 + 12dp 等间距——
 * 装饰只用来建立「这是谁」，不用来装饰每一个块。
 */
@Composable
private fun UpdateHeroBlock(appName: String, version: String) {
    val colors = MiuixTheme.colorScheme
    Box(modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            colors.primary.copy(alpha = 0.08f),
                            colors.primary.copy(alpha = 0.03f),
                            Color.Transparent,
                        ),
                    ),
                ),
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 24.dp, top = 20.dp, end = 24.dp, bottom = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AppIconBadge(size = 80.dp)
            if (appName.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Text(
                    text = appName,
                    style = MiuixTheme.textStyles.title1.shiftWeight(QingyuWeightDelta.BOLD),
                    color = colors.onSurface,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = version,
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun AboutUpdateStatusCardFull(
    modifier: Modifier = Modifier,
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
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 有更新：最新版本单独一段（主题色）+ 本页唯一的主按钮；没有更新时这一段整体不出现。
            if (hasUpdate) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 14.dp),
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
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(colors.secondaryContainer),
                )
            }

            // 可点行：状态只挂在行尾（已是最新时），有更新时不重复说一遍。
            ArrowPreference(
                title = AboutUpdateStrings.retryAction,
                endActions = {
                    if (!hasUpdate) {
                        Text(
                            text = AboutUpdateStrings.alreadyLatestHeadline,
                            style = MiuixTheme.textStyles.footnote1,
                            color = colors.onSurfaceVariantSummary,
                        )
                    }
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
private fun NotesSection(release: AppReleaseInfo?, modifier: Modifier = Modifier) {
    val colors = MiuixTheme.colorScheme
    val body = release?.body.orEmpty()
    val updatedText = release?.updatedAtMillis?.let {
        AboutUpdatePageStrings.updatedAt(formatUpdateDateTime(it))
    }
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 ContributorsPage 样板铺）
//
// 只给实现阶段看效果，不进业务路径。本页主体由 `resolveAboutUpdatePagePhase` 分三屏，
// 就绪屏再按 hasUpdate 分「有更新 / 已是最新」，底部还有一条下载进度条，所以覆盖：
//
//   数据状态 5 档：有更新 / 已是最新 / 检查中 / 检查失败 / 下载中；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么是这几档：
//   · 检查中与检查失败是两张完全不同的整屏（居中转圈 vs 居中失败卡），最容易只改一张；
//   · 已是最新时状态卡只剩两行可点行，卡片高度和「有更新」差一截，改排版必看；
//   · 下载中会多出 bottomBar，进度条与内容区的分界只在真机/预览里看得见；
//   · 暗色档守「白字落在白卡片」，大字号档看行内文案折行。
//
// 固定写法同 ContributorsPage：主题一律包 QingyuPageTheme(isDark = …)、字号走 textScale、
// 宽度按 400dp。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：一版已发布的说明，格式与本仓 `docs/releases/v*.md` 一致（导语 + 分类分组）。 */
private fun previewUpdateRelease(): AppReleaseInfo = AppReleaseInfo(
    version = "2.1.5",
    title = "周视图可拖动调课",
    body = """
        # v2.1.5

        > 本次重点：周视图可拖动调课、导入自动识别表头、小组件刷新提速

        ## 新增 · 2

        - 周视图长按课表格子即可拖动换课，松手后按周次补到对应星期
        - 课程详情支持直接改上课地点，不必再回编辑页

        ## 优化 · 1

        - 桌面小组件刷新从约 800ms 降到约 480ms
    """.trimIndent(),
    releaseUrl = "https://github.com/Mutx163/mikcb/releases/tag/v2.1.5",
    downloadUrl = "https://github.com/Mutx163/mikcb/releases/download/v2.1.5/app-release.apk",
    updatedAtMillis = 1794096000000L,
)

/** 预览用假数据：当前版本 2.1.4.1，最新版本 2.1.5。 */
private fun previewUpdateResult(hasUpdate: Boolean): AppUpdateCheckResult = AppUpdateCheckResult(
    hasRelease = true,
    hasUpdate = hasUpdate,
    currentVersion = "2.1.4.1",
    latestRelease = previewUpdateRelease(),
    message = if (hasUpdate) "update_available" else "already_latest",
)

/**
 * 渲染层会收到的全部输入组合（`packageInfoAvailable` 固定 true：预览里拿不到包信息时才走检查中）。
 *
 * 这五档就是 `AboutUpdateHostPage` 能传给 [AboutUpdatePage] 的全部形态：
 * 有更新 / 已是最新 / 检查中 / 检查失败 / 下载中。
 */
private data class PreviewAboutUpdateState(
    /** 只用来给预览命名，不参与渲染。 */
    val name: String,
    val checking: Boolean,
    val result: AppUpdateCheckResult?,
    val download: AboutUpdateDownloadUi? = null,
)

private val previewAboutUpdateStates: List<PreviewAboutUpdateState> = listOf(
    PreviewAboutUpdateState(
        name = "有更新",
        checking = false,
        result = previewUpdateResult(hasUpdate = true),
    ),
    PreviewAboutUpdateState(
        name = "已是最新",
        checking = false,
        result = previewUpdateResult(hasUpdate = false),
    ),
    PreviewAboutUpdateState(
        name = "检查中",
        checking = true,
        result = null,
    ),
    PreviewAboutUpdateState(
        name = "检查失败",
        checking = false,
        result = null,
    ),
    PreviewAboutUpdateState(
        name = "下载中",
        checking = false,
        result = previewUpdateResult(hasUpdate = true),
        download = AboutUpdateDownloadUi(
            downloadedBytes = 18_000_000L,
            totalBytes = 42_000_000L,
        ),
    ),
)

private fun previewAboutUpdateState(name: String): PreviewAboutUpdateState =
    previewAboutUpdateStates.first { it.name == name }

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewAboutUpdatePage(
    state: PreviewAboutUpdateState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        AboutUpdatePage(
            onBack = {},
            packageInfoAvailable = true,
            checking = state.checking,
            result = state.result,
            settings = AppUpdateSettings(),
            appName = "轻屿课表",
            download = state.download,
        )
    }
}

// ── 单档：五态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有更新", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewUpdate() {
    PreviewAboutUpdatePage(previewAboutUpdateState("有更新"))
}

@Suppress("unused")
@Preview(name = "2 已是最新", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewLatest() {
    PreviewAboutUpdatePage(previewAboutUpdateState("已是最新"))
}

@Suppress("unused")
@Preview(name = "3 检查中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewChecking() {
    PreviewAboutUpdatePage(previewAboutUpdateState("检查中"))
}

@Suppress("unused")
@Preview(name = "4 检查失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewFailed() {
    PreviewAboutUpdatePage(previewAboutUpdateState("检查失败"))
}

@Suppress("unused")
@Preview(name = "5 下载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewDownloading() {
    PreviewAboutUpdatePage(previewAboutUpdateState("下载中"))
}

// ── 单档：外观两档（以「有更新」为基准）───────────────────────────────────

@Suppress("unused")
@Preview(name = "6 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewDark() {
    PreviewAboutUpdatePage(previewAboutUpdateState("有更新"), dark = true)
}

@Suppress("unused")
@Preview(name = "7 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutUpdatePagePreviewLargeText() {
    PreviewAboutUpdatePage(previewAboutUpdateState("有更新"), textScale = 1.3f)
}
