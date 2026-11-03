package com.mutx163.qingyu.pages.about

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 更新日志页 · Compose 渲染层（Phase 3 补口 A1）。
 *
 * 对应 Flutter `lib/screens/changelog_screen.dart`(345 行)：
 * 一页列出 `docs/releases/` 下所有版本（`v<版本号>.md`，版本倒序），每版一张卡——
 * 版本标签 + 导语 + 「更新重点」（至多 3 条）+ 分类计数 + 按需展开的完整条目。
 *
 * ## 数据从哪来（与 Dart 的分工一一对应）
 *
 * Dart 侧 `_loadChangelog` 扫的是 Flutter 的 `AssetManifest`；这里扫的是**同一个目录**
 * 在 APK 里的落点 `assets/docs/releases/`（`assets.list` + 直接按 key 读，
 * 与 Dart 的 manifest + `rootBundle.loadString` 是同一件事的两条路）。
 * 2026-11-02 资产迁移：`docs/releases` 下的 `v*.md` 已拷进 `android/app/src/main/assets/`，
 * Compose 不再依赖 Flutter 打包出来的 `flutter_assets/` 目录（删 Flutter 后不再生成）；
 * **真机运行时能否读到尚未验证**。
 *
 * 清单列举失败（目录不存在）时退回 [knownChangelogVersions]，与 Dart 的
 * `_getKnownVersions()` 回退同理——直接按 key 读文件这条路仍然可用。
 *
 * ## 零参可渲染
 *
 * [entries] 默认 `null` = 自己从 assets 扫；宿主零参调用 `ChangelogPage(onBack = …)`
 * 即可。要喂演示数据就传 `entries`（此时不读 assets），与壳里其它页的 DEMO 口径一致。
 *
 * ## 文案
 *
 * 本文件**不含任何中文字面量**（i18n 棘轮门禁 `CjkLiteralGateTest` 管着渲染层）：
 * 所有屏上文案都取自模型层的 [ChangelogStrings]，与 `lib/l10n/app_zh.arb` 逐字一致。
 */
@Composable
fun ChangelogPage(
    onBack: () -> Unit = {},
    entries: List<ChangelogEntry>? = null,
) {
    val context = LocalContext.current
    var scanned by remember { mutableStateOf<List<ChangelogEntry>?>(null) }

    // entries == null 时才去读 assets；宿主喂了数据就一次都不碰文件系统。
    LaunchedEffect(entries) {
        if (entries == null && scanned == null) {
            scanned = withContext(Dispatchers.IO) { scanChangelogEntries(context) }
        }
    }

    val resolved = entries ?: scanned

    QingyuPageScaffold(title = ChangelogStrings.title, onBack = onBack) {
        if (resolved == null) {
            // 读盘期间：与 Dart 的 HyperosCircularProgress 居中态一致。
            Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
        } else {
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                // 官方配方：横向留白由卡片自己带（12dp），滚动条才贴得到屏幕边缘。
                horizontalPadding = QingyuPageCardMargin,
                contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
                verticalArrangement = AboutPageListSpacing,
            ) {
                items(resolved, key = { it.version }) { entry ->
                    ChangelogCard(entry)
                }
            }
        }
    }
}

/** `docs/releases/` 在 APK 里的落点（2026-11-02 起为主 assets 直落，不再带 flutter_assets 前缀）。 */
private const val releaseAssetsDir = "docs/releases"

/** [matchReleaseAssetKey] 认的是 Flutter 口径的 asset key，不带 `flutter_assets/` 前缀。 */
private const val releaseAssetKeyDir = "docs/releases"

/**
 * 扫出所有版本并读入正文（纯数据，不碰 Compose）。
 *
 * 与 Dart `_loadChangelog` 的三步逐条对应：
 * 1. 列目录 → 文件名过 [matchReleaseAssetKey] → 去重 + 版本倒序；
 * 2. 目录列不出来（清单接口挂了）→ 用 [knownChangelogVersions] 回退；
 * 3. 逐个读正文，**读不到的跳过**（[assembleChangelogEntries]）。
 *
 * 目录里同时打包了 `index.html` / `feed.json` / `latest.json`，它们过不了
 * [matchReleaseAssetKey]，不会混进版本列表。
 */
private fun scanChangelogEntries(context: Context): List<ChangelogEntry> {
    val fileNames = runCatching {
        context.assets.list(releaseAssetsDir)?.toList().orEmpty()
    }.getOrDefault(emptyList())

    val versions = if (fileNames.isEmpty()) {
        knownChangelogVersions()
    } else {
        sortReleaseVersionsDesc(
            fileNames.mapNotNull { matchReleaseAssetKey("$releaseAssetKeyDir/$it") },
        )
    }

    return assembleChangelogEntries(versions) { version ->
        runCatching {
            context.assets.open("$releaseAssetsDir/$version.md")
                .bufferedReader()
                .use { it.readText() }
        }.getOrNull()
    }
}

/**
 * 一版一张卡：版本标签 + 导语 + 摘要（解析不出条目时退回原文分块）。
 *
 * 摘要只在版本变化时算一次（`remember`）：一版正文几十条，展开/收起是纯展示，
 * 不该每次重组都重新解析——Dart 侧也是在加载时解析一次。
 */
@Composable
private fun ChangelogCard(entry: ChangelogEntry) {
    val colors = MiuixTheme.colorScheme
    val digest = remember(entry.version) { buildReleaseNotesDigest(entry.content) }
    val plainBlocks = remember(entry.version) {
        if (digest.isEmpty) splitReleaseNotesIntoBlocks(entry.content) else emptyList()
    }

    QingyuCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 16.dp),
        ) {
            VersionTag(entry.version)

            if (digest.intro.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = digest.intro,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceSecondary,
                    lineHeight = 20.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Spacer(Modifier.height(10.dp))

            if (digest.isEmpty) {
                // 老版本里可能有解析不出条目的正文（纯段落），退回原文渲染，
                // 不让「更新了但这里什么都没有」发生（Dart :326-332）。
                for (block in plainBlocks) {
                    Text(
                        text = block,
                        style = MiuixTheme.textStyles.footnote1,
                        color = colors.onSurface,
                        lineHeight = 20.sp,
                        modifier = Modifier.padding(bottom = 6.dp),
                    )
                }
            } else {
                ChangelogDigestView(digest)
            }
        }
    }
}

/** 版本号小标签（Dart `HyperosTag(label:, backgroundColor: surfaceContainerHigh)`）。 */
@Composable
private fun VersionTag(version: String) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = version,
        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
        color = colors.onSurfaceSecondary,
        modifier = Modifier
            .background(colors.surfaceContainerHigh, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/**
 * 「更新重点」摘要（移植 `lib/widgets/release_digest_view.dart` 的三段式）。
 *
 * 历史版本页的调用口径是 `groupEntries = true` + `alwaysExpandable = true`，
 * 且**默认全部收起**：一版动辄几十条，进页面先看到每版的「3 条重点 + 分类计数」，
 * 想读细节再点开。
 *
 * 与 Dart 一致的两处「不显示」判据：
 * - 分类计数只在它提供重点行之外的信息时才出现（单一分类且条目已全部列在重点行里时，
 *   这一行就是把上面几行又数了一遍）；
 * - `alwaysExpandable` 下只要有条目就给展开入口，标签按「还有没露过面的条目」选
 *   「查看全部 N 项」或「查看完整说明」——后者用于「一共 2 条、2 条都看得见」的版本，
 *   否则用户会读到一句像是撒谎的话。
 */
@Composable
private fun ChangelogDigestView(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    val counts = releaseChangeCounts(digest)
    val hasHiddenEntries = digest.total > digest.highlights.size
    val canExpand = digest.total > 0
    val showCounts = counts.isNotEmpty() && (counts.size > 1 || hasHiddenEntries)
    var expanded by remember(digest) { mutableStateOf(false) }

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

        if (showCounts) {
            Spacer(Modifier.height(2.dp))
            Text(
                text = counts.joinToString(" · ") { "${it.first} ${it.second}" },
                style = MiuixTheme.textStyles.footnote1,
                color = colors.onSurfaceVariantSummary,
            )
        }

        if (canExpand) {
            Spacer(Modifier.height(4.dp))
            ReleaseNotesExpandToggle(
                expanded = expanded,
                revealsHiddenEntries = hasHiddenEntries,
                total = digest.total,
                onToggle = { expanded = !expanded },
            )
        }

        if (expanded) {
            Spacer(Modifier.height(10.dp))
            Spacer(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(colors.secondaryContainer),
            )
            Spacer(Modifier.height(10.dp))
            ReleaseNotesGroupedEntries(digest)
        }
    }
}
