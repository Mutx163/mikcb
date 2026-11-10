package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.LocalQingyuBackButtonGlass
import com.mutx163.qingyu.components.QingyuBackIconButton
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuLoadingProgressBar
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.rememberShellShouldShowBackButton
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.infra.AppReleaseInfo
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.getEffectiveDownloadUrl
import com.mutx163.qingyu.infra.getSystemDownloaderUrl
import com.mutx163.qingyu.infra.releaseListUrlFor
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.overlay.OverlayDialog
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
 *
 * ## 2026-11-10 用户真机三件（同批修）
 *
 * 1. **展开更新说明后整页滑不动**：本页自 2026-11-08 起不画顶栏，却仍给列表挂了
 *    `MiuixScrollBehavior`。它的 `TopAppBarState.heightOffsetLimit` 没有 `TopAppBar`
 *    来写，停在默认 `-Float.MAX_VALUE`，`onPreScroll` 于是把每一段向上滚动都当成
 *    「收起不存在的大标题」整段吃掉。修法：本页**不建折叠行为、列表不传 `scrollBehavior`**
 *    （没有栏可折）；全仓由 `FoldBehaviorNeedsTopBarGuardTest` 钉住。
 * 2. **顶栏两钮离屏幕边缘不等**：原先 `padding(start = 4.dp, end = 8.dp)`，两颗都是同一个
 *    44dp 玻璃圆钮（`QingyuBackIconButton` 是 `QingyuGlassIconButton` 的薄封装），
 *    差异纯粹来自这行写死的边距。两侧统一 8dp。
 * 3. **从首页八宫格进入时不显示返回键**（用户指令「这样才才对」）：显隐走全站唯一判据
 *    [rememberShellShouldShowBackButton]（壳注入的顶页标记 → `ShellRootEntryRule`），
 *    本页自绘顶栏原先无条件画返回键、从没读过它。现在顶级目的地（八宫格进入）不画返回
 *    胶囊，但保留 44dp 占位防止 `SpaceBetween` 把右上那颗贴到左边。
 *    **有意偏离发布版**：`v2.1.4.1` 八宫格进更新页一律推路由、始终有返回箭头
 *    （`home_top_menu.dart:59-64`），按用户 2026-11-10 指令改成顶级态无返回。
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
    QingyuPageTheme {
        val dark = isSystemInDarkTheme()
        val colors = MiuixTheme.colorScheme
        // 本页**不向列表挂折叠行为**（`rememberQingyuScrollBehavior()` 已删，2026-11-10）：
        // 本页没有 `TopAppBar`，`MiuixScrollBehavior` 的 `TopAppBarState.heightOffsetLimit`
        // 会停在默认 `-Float.MAX_VALUE`，于是它的 `onPreScroll` 把每一段向上滚动都当成
        // 「收起（不存在的）大标题」整段吃掉 —— 展开更新说明后整页就滑不动了。
        // 没有栏可折，就不该建这个行为：列表不传 `scrollBehavior`（套件默认 null）。
        // 这一页**不画顶栏**：没有标题、没有栏底、没有毛玻璃。
        // 只有两颗胶囊浮在状态栏下面，页面内容直接在它们下面开始。
        // 背景的蓝白渐变画在**最底层、不随内容滚动**（之前它做了列表的第一项，
        // 一滑就被推走，看起来就是“壁纸在跟着动”）。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(QingyuTheme.scaffoldBackground(dark))),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            0.0f to colors.primary.copy(alpha = 0.10f),
                            0.28f to colors.primary.copy(alpha = 0.045f),
                            0.65f to Color.Transparent,
                        ),
                    ),
            )
            Column(modifier = Modifier.fillMaxSize()) {
                // 顶栏两枚按钮用全站同一套：返回键 [QingyuBackIconButton]、右上动作键
                // [QingyuGlassIconButton]，都是圆底玻璃钮。
                // 骨架默认只在内容压到栏下时才给返回键长圆底；本页没有栏，就显式把
                // `LocalQingyuBackButtonGlass` 置 true，让左边与右边从一开始就是同一颗圆钮。
                //
                // 返回键的**显隐**走全站唯一判据（与 `QingyuPageScaffold` 同一条）：
                // 从首页八宫格进入时壳把本页标成顶级目的地 ⇒ 不画返回胶囊；从关于页
                // 等嵌套路径进入时照常画。左右两侧统一 8dp：原先 start=4 / end=8，
                // 两颗同尺寸玻璃钮离屏幕边缘差 4dp（2026-11-10 用户实报）。
                CompositionLocalProvider(LocalQingyuBackButtonGlass provides true) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .windowInsetsPadding(WindowInsets.statusBars)
                            .padding(start = 8.dp, top = 4.dp, end = 8.dp, bottom = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        // 写法与 `RootEntryBackGuardTest` 对「手拼顶栏页」的期望一致：
                        // 直接在 if 里调唯一取法（该守卫若将来把本页加进名单，不会因写法不合而红）。
                        if (rememberShellShouldShowBackButton()) {
                            QingyuBackIconButton(onBack = onBack)
                        } else {
                            // 顶级目的地：不画返回胶囊，但**占住同尺寸空位**——
                            // `Row` 是 `SpaceBetween`，只剩一个子项时右上那颗会贴到左边。
                            Spacer(Modifier.size(44.dp))
                        }
                        QingyuGlassIconButton(
                            onClick = onOpenAdvancedOptions,
                            contentDescription = AboutUpdatePageStrings.advancedOptionsTitle,
                            icon = MiuixIcons.Tune,
                        )
                    }
                }

                val contentInsets = PaddingValues(
                    bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding(),
                )
                when (phase) {
                    AboutUpdatePagePhase.CHECKING -> AboutUpdateCheckingView(
                        appName = appName,
                        innerPadding = contentInsets,
                    )

                    AboutUpdatePagePhase.CHECK_FAILED -> AboutUpdateCheckFailedView(
                        innerPadding = contentInsets,
                        onRefresh = onRefresh,
                    )

                    AboutUpdatePagePhase.READY -> AboutUpdateReadyView(
                        innerPadding = contentInsets,
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

            if (download != null) {
                DownloadProgressDialog(download = download, onCancel = onCancelDownload)
            }
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
            // 发布版 `about_screen.dart:749-779` 的「检查中」整页只有图标 + 应用名 + 这句
            // 「正在检查更新……」，**没有转圈**（2026-11-10 按发布版去掉，Chief 已拍板；
            // D1 方案 §1.6 同一结论）。文字本身已经说明状态，多一颗转圈反而像还在干别的。
            Spacer(Modifier.height(12.dp))
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
        // 不传 `scrollBehavior`：本页没有顶栏可折，挂折叠行为会把向上滚动整段吃掉
        //（根因见 [AboutUpdatePage] 头注，2026-11-10 修「展开更新说明后滑不动」）。
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
 * 渐变只用主题主色推透明度，而且**从透明起步**（0 → 9% → 3% → 0）：
 * 页底是浅色、顶栏也是页底色，如果渐变第一档就有颜色，栏底会切出一条硬边，
 * 整条顶栏看起来就像一张白卡片浮在上面。从 0 起步后，白底色是无缝接到淡蓝色上的。
 * 高度跟随内容（图标 80、名称一行、版本一行 + 上下留白 ≈ 190dp），不用固定高度硬撑。
 * 这一块是整页唯一的装饰，下面的卡片全部是白底/容器色 + 12dp 等间距——
 * 装饰只用来建立「这是谁」，不用来装饰每一个块。
 */
@Composable
private fun UpdateHeroBlock(appName: String, version: String) {
    val colors = MiuixTheme.colorScheme
    Box(modifier = Modifier.fillMaxWidth()) {
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
            // 版本号改成**右侧取值**（与下面两行 preference 的「标题左 / 取值右」同一语法），
            // 不再堆成「小字标签 + 大字版本」两层——两层在小卡里会多出一条重量级字行。
            if (hasUpdate) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 16.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = AboutUpdateStrings.latestVersionLabel,
                            style = MiuixTheme.textStyles.footnote1,
                            color = colors.onSurfaceVariantSummary,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            text = release?.version ?: AboutUpdatePageStrings.unreleasedLabel,
                            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = colors.primary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = onPrimary,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColorsPrimary(),
                    ) {
                        Text(primaryLabel)
                    }
                }
                // 细线内缩 16dp：继续贴到卡片圆角上会把一张卡看成上下两张。
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    color = colors.dividerLine,
                )
            }

            // 可点行：状态只挂在行尾（已是最新时），有更新时不重复说一遍。
            ArrowPreference(
                title = AboutUpdateStrings.retryAction,
                endActions = {
                    if (!hasUpdate) {
                        // 「已是最新」是结论，不是取值：做成中性淡底小胶囊，
                        // 跟右侧箭头分开层次，不再是一行灰字跟着箭头跑。
                        Text(
                            text = AboutUpdateStrings.alreadyLatestHeadline,
                            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = colors.onSurfaceSecondary,
                            maxLines = 1,
                            modifier = Modifier
                                .background(colors.secondaryContainer, RoundedCornerShape(6.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp),
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
 * 现在信息次序是「重点 → 展开 → 分类计数 / 时间」。
 *
 * 2026-11-08 第二轮：分类计数从正文尾巴（紧跟条目、看着像第四行内容）移到卡尾，
 * 与更新时间并成一条元信息行（左计数 / 右时间，14dp 内边距、顶部内缩细线）。
 * 一条卡尾同时收尾「这版改了多少」和「何时发布」，正文区就只剩真正要读的字。
 */
@Composable
private fun NotesSection(release: AppReleaseInfo?, modifier: Modifier = Modifier) {
    val colors = MiuixTheme.colorScheme
    val body = release?.body.orEmpty()
    val digest = remember(body) { buildReleaseNotesDigest(body) }
    val countsText = releaseChangeCounts(digest).joinToString(" · ") { "${it.first} ${it.second}" }
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
                    .padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 14.dp),
            ) {
                NotesBodyContent(body = body, digest = digest)
            }
            if (countsText.isNotEmpty() || updatedText != null) {
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    color = colors.dividerLine,
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, top = 10.dp, end = 16.dp, bottom = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (countsText.isNotEmpty()) {
                        Text(
                            text = countsText,
                            style = MiuixTheme.textStyles.footnote1,
                            color = colors.onSurfaceVariantSummary,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (updatedText != null) {
                        Text(
                            text = updatedText,
                            style = MiuixTheme.textStyles.footnote1,
                            color = colors.onSurfaceVariantSummary,
                        )
                    }
                }
            }
        }
    }
}

/** Dart `_buildNotesDigest` / `_buildNotesBlock`：有可解析条目画摘要，否则退回原文分块纯文本。 */
@Composable
private fun NotesBodyContent(body: String, digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
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
 *  再压一行灰字就是同一句话说两遍；重点直接以列表开场，计数字接在列表尾部。
 *
 *  2026-11-08 第二轮：重点行的分类标签改成淡色胶囊（[ReleaseNotesHighlightRow] 的
 *  `useLabelChip`），并在「重点」与「展开入口」之间加一条内缩细线——把「读的内容」
 *  和「可以展开」两个动作分开。计数行已上提到卡尾（见 [NotesSection]）。
 *
 *  2026-11-08 第三轮（用户贴「已是最新」截图说不好看）：**去掉胶囊/圆点混排**。
 *  正文只给每组第一条挂分类词（「新增 2」下的第二条 label 是空串），直接按 label 判空
 *  会让同一分类的第 1、3 行是胶囊（文字从 88 起）、第 2 行退成圆点（文字从 40 起），
 *  左缘排成三档。现在用 [highlightsWithLabels] 把同分类的标签补齐，三行统一胶囊宽度；
 *  同时**删掉展开入口上方那条细线**——它和卡尾细线只隔 44dp，把链接夹成一条“工具条”。 */
@Composable
private fun ExpandedDigest(digest: ReleaseNotesDigest) {
    val highlights = remember(digest) { highlightsWithLabels(digest) }
    Column(modifier = Modifier.fillMaxWidth()) {
        for (highlight in highlights) {
            ReleaseNotesHighlightRow(highlight, useLabelChip = true)
        }
        if (digest.entries.isNotEmpty()) {
            ReleaseNotesExpandableBody(digest)
        }
    }
}

/**
 * 给重点行补上分类标签：同分类的第一条带 label、其余为空串，直接渲染就变成
 * 「胶囊 / 圆点 / 胶囊」的错位。这里按 kind 把同组的标签借过来——标签本来就取自正文
 * 的分组标题（见 `ReleaseChangeEntry.label` 的注释），同一组共用同一个词是准确的，
 * 不是另造文案。找不到标签的 kind（老版本无分组标题）继续走圆点回退。
 */
private fun highlightsWithLabels(digest: ReleaseNotesDigest): List<ReleaseChangeEntry> {
    val labelByKind = digest.entries
        .filter { it.label.isNotEmpty() }
        .associate { it.kind to it.label }
    return digest.highlights.map { entry ->
        if (entry.label.isNotEmpty()) entry else entry.copy(label = labelByKind[entry.kind].orEmpty())
    }
}

/** 下载进度弹窗：官方 `OverlayDialog` + D1 档 D 进度条（`QingyuLoadingProgressBar`）。
 *
 * 2026-11-08：原先是一条钉在页底的进度条，切页/滑一半都还挂在那里，不像系统行为；
 * 改成标准弹窗后：下载中弹、下完自动消失，不能点外面关（写盘还在继续），只能按“取消下载”。
 */
@Composable
private fun DownloadProgressDialog(download: AboutUpdateDownloadUi, onCancel: () -> Unit) {
    val colors = MiuixTheme.colorScheme
    val progress = resolveDownloadProgress(download.downloadedBytes, download.totalBytes)
    val fraction = progress.fraction?.toFloat()
    val title = when {
        download.cancelling -> AboutUpdatePageStrings.downloadCancelling
        progress.fraction != null ->
            AboutUpdatePageStrings.downloadingPercent(String.format(Locale.US, "%.1f", progress.fraction * 100))
        else -> AboutUpdatePageStrings.downloadingBytes(formatBytes(download.downloadedBytes))
    }

    OverlayDialog(
        show = true,
        // 16dp 口径见 ComposeSheetGuardTest S1D（官方默认 24dp 与本仓不一致）：
        insideMargin = DpSize(16.dp, 16.dp),
        title = title,
        onDismissRequest = null,
        // 本页不走页面骨架，没有根 Scaffold 可挂；直接投到自己的窗口里。
        renderInRootScaffold = false,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 档 D（D1 统一）：文案在上（本弹窗的标题就是百分比/字节数），条不传高度走官方默认 6dp；
            // 进行中/完成 primary、底槽 secondaryContainer（发布版 `home_update_prompt.dart:642-646`）。
            QingyuLoadingProgressBar(
                progress = fraction,
                modifier = Modifier.fillMaxWidth(),
            )
            if (fraction == null && download.downloadedBytes > 0) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = AboutUpdatePageStrings.mirrorUnknownSizeHint,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                )
            }
            Spacer(Modifier.height(4.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
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
