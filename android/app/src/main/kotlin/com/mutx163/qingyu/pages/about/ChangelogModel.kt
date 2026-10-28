package com.mutx163.qingyu.pages.about

import java.util.Comparator

/**
 * 更新日志页的纯逻辑（移植 `lib/screens/changelog_screen.dart` 的扫描 / 排序 / 装载三段，
 * 2026-10-28 快照）。
 *
 * ## 这个文件负责什么
 *
 * Dart 侧这一页的全部数据逻辑就三件事，界面只负责画：
 *
 * 1. **扫出有哪些版本**：`docs/releases/` 下文件名符合 `v<数字版本号>.md` 的才算，
 *    同目录的 `index.html` / `feed.json` / `latest.json` 一律不认（[matchReleaseAssetKey]）；
 *    （KDoc 里不能写「斜杠 + 星号」——Kotlin 的块注释会嵌套，那样会把整个文件注释掉。）
 * 2. **按版本倒序排**（最新在前）：`v2.1.1.4 > v2.1.1 > v2.0.5.6`，
 *    缺位补 0 比较，不是字符串比较（[compareReleaseVersionsDesc] / [sortReleaseVersionsDesc]）；
 * 3. **逐个读正文、读不到的跳过**（[assembleChangelogEntries]）。
 *
 * 正文 → 摘要的解析不在这里，见 [buildReleaseNotesDigest]。
 */

/**
 * `docs/releases/<version>.md` 的 asset key 匹配规则。
 *
 * 目录同时打包了 html / json 等文件，正则只接受数字版本号（允许 `-a` 等后缀）。
 */
val releaseAssetKeyPattern: Regex = Regex("^docs/releases/(v\\d+(?:\\.\\d+)*(?:-[\\w.]+)?)\\.md$")

/** 匹配 asset key 中的版本号，如 `docs/releases/v2.1.1.4.md` → `v2.1.1.4`。 */
fun matchReleaseAssetKey(assetKey: String): String? =
    releaseAssetKeyPattern.find(assetKey)?.groupValues?.get(1)

private val releaseVersionPattern = Regex("v?(\\d+(?:\\.\\d+)*)")

/** 解析版本字符串中的数字段，如 `v2.1.1.4` → `[2, 1, 1, 4]`；解析不出时返回 `[0]`。 */
fun parseReleaseVersion(version: String): List<Int> {
    val match = releaseVersionPattern.find(version) ?: return listOf(0)
    return match.groupValues[1].split(".").map { it.toInt() }
}

/**
 * 按语义版本号倒序排列（最新在前），如 `v2.1.1.4 > v2.1.1 > v2.0.5.6`。
 *
 * 逐段比较、短的一侧补 0，所以 `v2.1.1` 与 `v2.1.1.0` 相等（返回 0）。
 */
fun compareReleaseVersionsDesc(a: String, b: String): Int {
    val va = parseReleaseVersion(a)
    val vb = parseReleaseVersion(b)
    val segments = maxOf(va.size, vb.size)
    for (index in 0 until segments) {
        val na = if (index < va.size) va[index] else 0
        val nb = if (index < vb.size) vb[index] else 0
        if (na != nb) return nb.compareTo(na)
    }
    return 0
}

/**
 * 去重后按 [compareReleaseVersionsDesc] 排序。
 *
 * 对应 Dart 的 `.toSet().toList()` + `sort(compareReleaseVersionsDesc)`：
 * 去重按**先出现者**保留，排序是稳定排序。
 */
fun sortReleaseVersionsDesc(versions: Collection<String>): List<String> =
    versions.toSet().toList().sortedWith(Comparator { a, b -> compareReleaseVersionsDesc(a, b) })

/**
 * 更新日志页的一条：版本号 + 该版本的 Markdown 正文。
 *
 * 正文保持原样（不做解析），摘要由 [buildReleaseNotesDigest] 在渲染时算一次——
 * Dart 侧也是「加载时解析一次、展开/收起只做展示」，这里保持同一分工。
 */
data class ChangelogEntry(
    val version: String,
    val content: String,
)

/**
 * 按给定顺序读入正文，**读不到的版本跳过**（不占位、不错位）。
 *
 * 对应 Dart `_loadChangelog` 里的 `Future.wait(versions.map(_loadEntry))` +
 * `whereType<_ChangelogEntry>()`：并发加载在 Kotlin 侧由调用方决定（这里只保证
 * 顺序与容错），任何一次读取抛异常都按「这个版本没有正文」处理。
 */
fun assembleChangelogEntries(
    versions: List<String>,
    read: (String) -> String?,
): List<ChangelogEntry> = versions.mapNotNull { version ->
    val content = runCatching { read(version) }.getOrNull()
    if (content == null) null else ChangelogEntry(version, content)
}

/**
 * `AssetManifest` 解析失败时的回退版本列表，按倒序排列（最新在前）。
 *
 * 逐字抄自 Dart `_getKnownVersions()`（`changelog_screen.dart:125-240`）。
 * 它的意义不是「显示这些版本」，而是**清单接口挂了、直接按 key 读文件仍然可用**：
 * 列表里每个版本仍会去读 `docs/releases/<version>.md`，读不到的照旧跳过。
 *
 * ⚠️ 这份列表本身必须严格按 [compareReleaseVersionsDesc] 倒序（有测试钉住）；
 * 新增版本时插到正确位置，不要往末尾追加。
 */
fun knownChangelogVersions(): List<String> = listOf(
    "v2.1.1.9", "v2.1.1.8", "v2.1.1.7", "v2.1.1.6", "v2.1.1.5", "v2.1.1.4",
    "v2.1.1.3", "v2.1.1.2", "v2.1.1.1", "v2.1.1", "v2.1.0",
    "v2.0.5.6", "v2.0.5.5", "v2.0.5.4", "v2.0.5.3", "v2.0.5.2", "v2.0.5.1", "v2.0.5",
    "v2.0.4.5", "v2.0.4.4", "v2.0.4.3", "v2.0.4.2", "v2.0.4.1", "v2.0.4",
    "v2.0.3", "v2.0.2", "v2.0.1", "v2.0",
    "v1.3.2", "v1.3.1", "v1.3",
    "v1.2.1.15", "v1.2.1.14", "v1.2.1.13", "v1.2.1.12", "v1.2.1.11", "v1.2.1.9",
    "v1.2.1.8", "v1.2.1.7", "v1.2.1.6", "v1.2.1.5", "v1.2.1.4", "v1.2.1.3",
    "v1.2.1.2", "v1.2.1.1", "v1.2.1",
    "v1.2.0.30", "v1.2.0.29", "v1.2.0.28", "v1.2.0.27", "v1.2.0.24", "v1.2.0.22",
    "v1.2.0.20", "v1.2.0.19", "v1.2.0.18", "v1.2.0.17", "v1.2.0.16", "v1.2.0.15",
    "v1.2.0.12", "v1.2.0.11", "v1.2.0.10", "v1.2.0.9", "v1.2.0.8", "v1.2.0.7",
    "v1.2.0.6", "v1.2.0.5", "v1.2.0.4", "v1.2.0.2", "v1.2.0.1",
    "v1.1.10.28", "v1.1.10.24", "v1.1.10.23", "v1.1.10.22", "v1.1.10.21",
    "v1.1.10.20", "v1.1.10.19", "v1.1.10.18", "v1.1.10.17", "v1.1.10.16",
    "v1.1.10.15", "v1.1.10.14", "v1.1.10.13", "v1.1.10.12", "v1.1.10.11",
    "v1.1.10.10", "v1.1.10.9", "v1.1.10.8", "v1.1.10.7", "v1.1.10.6",
    "v1.1.10.5", "v1.1.10.4", "v1.1.10.3", "v1.1.10.2", "v1.1.10.1", "v1.1.10",
    "v1.1.9.7", "v1.1.9.6", "v1.1.9.5", "v1.1.9.4", "v1.1.9.3", "v1.1.9.2", "v1.1.9.1",
    "v1.1.8.2", "v1.1.8.1", "v1.1.8",
    "v1.1.7.1", "v1.1.7", "v1.1.6", "v1.1.5-a", "v1.1.4", "v1.1.3", "v1.1.2", "v1.1.1", "v1.1.0",
)

/**
 * 更新日志页与发布说明摘要用到的文案。
 *
 * 与 `lib/l10n/app_zh.arb` **逐字一致**（有测试直读 ARB 对拍，不手抄）：
 * 每条上面的注释就是 ARB 键名。
 *
 * ⚠️ 其中 `aboutUpdateHighlightsTitle` / `aboutUpdateViewAllAction` /
 * `aboutUpdateViewFullAction` / `aboutUpdateCollapseAction` 四条是**与「关于 → 版本更新」
 * 页共用**的键（Dart 侧同一个 `ReleaseDigestView` 被两处使用）。更新卡那一批要用时
 * 直接引这里，不要再抄一份。
 */
object ChangelogStrings {
    /** aboutChangelogTitle */
    const val title = "更新日志"

    /** aboutUpdateHighlightsTitle */
    const val highlightsTitle = "更新重点"

    /** aboutUpdateViewFullAction */
    const val viewFullAction = "查看完整说明"

    /** aboutUpdateCollapseAction */
    const val collapseAction = "收起"

    /** aboutUpdateViewAllAction（ARB 原文 `查看全部 {count} 项`） */
    fun viewAllAction(count: Int): String = "查看全部 $count 项"
}
