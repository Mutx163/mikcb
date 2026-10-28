package com.mutx163.qingyu.pages.about

import android.content.Context
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.theme.Colors
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
 * 在 APK 里的落点 `assets/flutter_assets/docs/releases/`（`assets.list` + 直接按 key 读，
 * 与 Dart 的 manifest + `rootBundle.loadString` 是同一件事的两条路）。
 * 已用 2026-10-26 构建出的 `app-composep1-debug.apk` 核对过该目录确实存在
 * （134 个文件，含全部 `v*.md`）；**真机运行时能否读到尚未验证**。
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
            LazyColumn(
                // 把滚动手势喂给顶栏的折叠行为；漏了这一步大标题就永不收起。
                modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = innerPadding.calculateTopPadding(),
                    // 底部必须把系统手势条那段算进去，否则最后一张卡会钻到小白条底下。
                    bottom = innerPadding.calculateBottomPadding() + 24.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(resolved, key = { it.version }) { entry ->
                    ChangelogCard(entry)
                }
            }
        }
    }
}

/** `docs/releases/` 在 APK 里的实际落点（已用构建出的 APK 核对）。 */
private const val releaseAssetsDir = "flutter_assets/docs/releases"

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
        style = MiuixTheme.textStyles.footnote1,
        fontWeight = FontWeight.Medium,
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
            style = MiuixTheme.textStyles.footnote1,
            color = colors.onSurfaceVariantSummary,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(8.dp))

        for (highlight in digest.highlights) {
            HighlightRow(highlight)
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
            ExpandToggle(
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
            GroupedEntries(digest)
        }
    }
}

/** 条目分组的固定顺序（与挑选重点的优先级一致，Dart `_groupOrder`）。 */
private val digestGroupOrder = listOf(
    ReleaseChangeKind.ADDED,
    ReleaseChangeKind.IMPROVED,
    ReleaseChangeKind.REMOVED,
    ReleaseChangeKind.FIXED,
    ReleaseChangeKind.OTHER,
)

/** 展开区按分类分组：标题形如「新增 · 12」，条目本身不再重复分类词。 */
@Composable
private fun GroupedEntries(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    var isFirstGroup = true

    for (kind in digestGroupOrder) {
        val group = digest.entries.filter { it.kind == kind }
        if (group.isEmpty()) {
            continue
        }
        if (!isFirstGroup) {
            Spacer(Modifier.height(12.dp))
        }
        isFirstGroup = false

        val label = group.firstOrNull { it.label.isNotEmpty() }?.label
        if (label != null) {
            Text(
                text = "$label · ${group.size}",
                style = MiuixTheme.textStyles.footnote1,
                color = kindColor(kind, colors),
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(6.dp))
        }

        for (entry in group) {
            EntryRow(entry = entry, showLabel = false)
        }
    }
}

/** 一条重点：分类色点 + 分类标签 + 短标题（最多两行）。 */
@Composable
private fun HighlightRow(entry: ReleaseChangeEntry) {
    val colors = MiuixTheme.colorScheme
    val accent = kindColor(entry.kind, colors)

    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Spacer(
            modifier = Modifier
                .padding(top = 7.dp)
                .size(5.dp)
                .background(accent, CircleShape),
        )
        Spacer(Modifier.width(8.dp))

        if (entry.label.isNotEmpty()) {
            Text(
                text = entry.label,
                style = MiuixTheme.textStyles.footnote1,
                color = accent,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.width(8.dp))
        }

        Text(
            text = entry.headline,
            style = MiuixTheme.textStyles.body2,
            color = colors.onBackground,
            lineHeight = 19.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 展开后的一条完整条目：分类标签（可选）+ 完整说明。 */
@Composable
private fun EntryRow(entry: ReleaseChangeEntry, showLabel: Boolean) {
    val colors = MiuixTheme.colorScheme

    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        if (showLabel && entry.label.isNotEmpty()) {
            Text(
                text = entry.label,
                style = MiuixTheme.textStyles.footnote2,
                color = kindColor(entry.kind, colors),
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = entry.text,
            style = MiuixTheme.textStyles.footnote1,
            color = colors.onSurfaceSecondary,
            lineHeight = 20.sp,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 展开/收起入口：纯文字动作 + 箭头（与 Dart 的 GestureDetector 写法对应）。 */
@Composable
private fun ExpandToggle(
    expanded: Boolean,
    revealsHiddenEntries: Boolean,
    total: Int,
    onToggle: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val label = when {
        expanded -> ChangelogStrings.collapseAction
        revealsHiddenEntries -> ChangelogStrings.viewAllAction(total)
        else -> ChangelogStrings.viewFullAction
    }

    Row(
        modifier = Modifier.clickable { onToggle() }.padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = colors.primary,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.width(2.dp))
        Icon(
            imageVector = if (expanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
            contentDescription = null,
            tint = colors.primary,
            modifier = Modifier.size(16.dp),
        )
    }
}

/**
 * 分类色：新增用主题色（一版里最希望被看到的就是它），移除用错误色，
 * 其余用次要墨色——三种颜色足够区分，不会把界面染成调色板（Dart `_kindColor`）。
 */
private fun kindColor(kind: ReleaseChangeKind, colors: Colors): Color = when (kind) {
    ReleaseChangeKind.ADDED -> colors.primary
    ReleaseChangeKind.REMOVED -> colors.error
    ReleaseChangeKind.IMPROVED, ReleaseChangeKind.FIXED -> colors.onSurfaceSecondary
    ReleaseChangeKind.OTHER -> colors.onSurfaceVariantSummary
}
