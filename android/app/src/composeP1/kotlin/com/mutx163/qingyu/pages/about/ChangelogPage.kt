package com.mutx163.qingyu.pages.about

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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
            // D1 档 A1（整页居中）：走共享加载件（24dp / 2.5 线宽，发布版 HyperosCircularProgress
            // 的刻度）。原先直接裸调 miuix 默认的 30dp / 4dp，比发布版粗一倍。
            QingyuLoadingCenter(modifier = Modifier.padding(innerPadding))
        } else {
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                // 官方配方：页面横向 0，留白由每个块自己带（卡片 12dp）——
                // 与关于族其它页同一套刻度（滚动条位置与此无关：miuix 竖条只用
                // trackPadding 的上下两个值）。
                horizontalPadding = QingyuPageCardMargin,
                // 发布版列表统一 `listPadding` 顶部 4dp（`hyperos_tokens.dart:71`）：本页没有
                // 分组标题兜底，首张卡直接顶在栏下会显得「被切掉一截」，补回这 4dp。
                extraTopPadding = 4.dp,
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
                // 这是**整段正文**不是条目：用 body2（14sp）+ 20 行高，段间 10dp，
                // 与上面重点行（body2/19）同一档字，不再缩成 13sp 的脚注。
                for (block in plainBlocks) {
                    Text(
                        text = block,
                        style = MiuixTheme.textStyles.body2,
                        color = colors.onSurface,
                        lineHeight = 20.sp,
                        modifier = Modifier.padding(bottom = 10.dp),
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
        // 版本号是这张卡的**身份**，不是附注：发布版 HyperosTag 的字色是 `onSurface`
        //（`hyperos_badge.dart:93`）。原先用次级墨色，一屏十几张卡时版本号整体发灰，
        // 第一眼看到的是一排小灰块而不是「这一版是哪个版本」。
        color = colors.onSurface,
        modifier = Modifier
            .background(colors.surfaceContainerHigh, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 2.dp),
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
            // 摘要与展开区之间的块级分节线（发布版 `Container(height: 1)` 同款：
            // 这不是卡内行间线，`RowDividerGuardTest` 判的是 `HorizontalDivider`）。
            // 颜色用主题的 `dividerLine` 槽，不再拿 `secondaryContainer` 当色块画——
            // 后者在暗色下会亮成一根白条。
            Spacer(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(colors.dividerLine),
            )
            Spacer(Modifier.height(10.dp))
            ReleaseNotesGroupedEntries(digest)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 ContributorsPage 样板铺）
//
// 只给实现阶段看效果，不进业务路径。喂 `entries` 时页面**不碰资产**（LaunchedEffect 直接跳过），
// 所以预览是确定的。覆盖：
//
//   · 有数据：三版，其中两版是「导语 + 分类分组」的新格式，一版是解析不出条目的纯段落旧版
//     （`ChangelogCard` 的 Markdown 原文回退分支，最容易只改新格式忘了它）；
//   · 空态：一版都读不到时只剩顶栏和空白，改列表间距时必看；
//   · 暗色 / 大字号：同 ContributorsPage 的理由（白字落白卡片 / 行内文案折行）。
//
// 没铺「读取中」：那一档等于 `entries = null`，会真的去读 APK 资产，预览里结果不确定
// （Studio 的假 Context 可能列不出目录），宁可不铺。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：新格式两版 + 旧纯段落一版。 */
private val previewChangelogEntries: List<ChangelogEntry> = listOf(
    ChangelogEntry(
        version = "v2.1.5",
        content = """
            # v2.1.5

            > 本次重点：周视图可拖动调课、导入自动识别表头、小组件刷新提速

            ## 新增 · 2

            - 周视图长按课表格子即可拖动换课，松手后按周次补到对应星期
            - 课程详情支持直接改上课地点，不必再回编辑页

            ## 优化 · 1

            - 桌面小组件刷新从约 800ms 降到约 480ms

            ## 修复 · 2

            - 修复跨周次课程在节次重叠时颜色错位
            - 修复夜间模式下课程卡片文字发灰
        """.trimIndent(),
    ),
    ChangelogEntry(
        version = "v2.1.4.1",
        content = """
            # v2.1.4.1

            > 首个推荐版本。

            ## 新增 · 1

            - 课表支持按周次切换，考试周自动归档到末尾
        """.trimIndent(),
    ),
    ChangelogEntry(
        version = "v2.0.0",
        content = """
            # v2.0.0

            本次重写了课表渲染，滑动更跟手，大课表也不再掉帧。
            历史课程数据自动迁移，不需要手动导入。
        """.trimIndent(),
    ),
)

/** 一档预览的公共身体：条目集合 + 外观档位。 */
@Composable
private fun PreviewChangelogPage(
    entries: List<ChangelogEntry>,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        ChangelogPage(onBack = {}, entries = entries)
    }
}

@Suppress("unused")
@Preview(name = "1 有数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ChangelogPagePreviewData() {
    PreviewChangelogPage(previewChangelogEntries)
}

@Suppress("unused")
@Preview(name = "2 空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ChangelogPagePreviewEmpty() {
    PreviewChangelogPage(emptyList())
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ChangelogPagePreviewDark() {
    PreviewChangelogPage(previewChangelogEntries, dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ChangelogPagePreviewLargeText() {
    PreviewChangelogPage(previewChangelogEntries, textScale = 1.3f)
}
