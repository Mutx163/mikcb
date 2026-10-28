package com.mutx163.qingyu.pages.about

/**
 * 开源许可页的纯结构模型（移植 `lib/screens/open_source_licenses_screen.dart`，
 * 2026-10-26 快照）。
 *
 * ## 为什么这一层不碰 Compose / Miuix
 *
 * `main` 源集对**所有变体**编译（含 Flutter 的 prod 包）。miuix 只在 `composeP1`
 * 变体的 classpath 上，所以这一层一旦 import 任何 Compose/Miuix 类型，`compileProdDebugKotlin`
 * 会立刻挂——这是实测过的边界，不是猜测。因此：
 * - 本文件只承载「分组 / 排序 / 过滤 / 文案」这些可单测的纯逻辑；
 * - 真正调 Miuix 组件渲染的代码在 composeP1 源集：
 *   `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/`。
 */

/**
 * `LicenseRegistry` 的一条原始记录（Dart 侧 `entry.packages` / `entry.paragraphs`）。
 *
 * 做成显式入参而不是直接读 `LicenseRegistry`，是为了让本层保持零 IO、可单测；
 * 采集注册表的那一步留在渲染层（与 Dart 的 async 采集同位置）。
 */
data class LicenseRegistryEntry(
    val packages: List<String>,
    val paragraphs: List<String>,
)

/** 一个包聚合后的许可证全文（Dart `OpenSourcePackageLicense`）。 */
data class OpenSourcePackageLicense(
    val packageName: String,
    val licenseBodies: List<String>,
) {
    /** Dart `licenseBodies.join('\n\n---\n\n')`。 */
    val combinedLicenseText: String
        get() = licenseBodies.joinToString("\n\n---\n\n")
}

/**
 * Dart `loadOpenSourcePackageLicenses()` 去掉注册表 IO 后的纯逻辑：
 *
 * 1. 每条记录：段落逐条 `trim`，空段落丢弃；**全空则整条跳过**（Dart :30-32）；
 * 2. 正文 = 段落以 `"\n\n"` 连接（Dart :33）；
 * 3. 包名 `trim`，空名跳过（Dart :36-38）；同名包的正文按**出现顺序**累积；
 * 4. 结果按包名**小写**字典序排序（Dart :52-56）。
 *
 * 顺序语义很重要：同名包的多份正文在详情页按累积顺序拼接，顺序漂移 = 全文变样。
 */
fun buildOpenSourcePackageLicenses(
    entries: List<LicenseRegistryEntry>,
): List<OpenSourcePackageLicense> {
    val bodiesByPackage = LinkedHashMap<String, MutableList<String>>()
    for (entry in entries) {
        val paragraphs = entry.paragraphs.map { it.trim() }.filter { it.isNotEmpty() }
        if (paragraphs.isEmpty()) {
            continue
        }
        val body = paragraphs.joinToString("\n\n")
        for (rawName in entry.packages) {
            val name = rawName.trim()
            if (name.isEmpty()) {
                continue
            }
            bodiesByPackage.getOrPut(name) { mutableListOf() }.add(body)
        }
    }
    return bodiesByPackage
        .map { (name, bodies) -> OpenSourcePackageLicense(name, bodies.toList()) }
        .sortedBy { it.packageName.lowercase() }
}

/**
 * Dart `_filteredPackages`：query `trim` + 小写后做 `contains`；
 * **空 query 原样返回**（Dart :111-114，注意返回的是同一个列表，不是副本）。
 */
fun filterOpenSourcePackages(
    packages: List<OpenSourcePackageLicense>,
    query: String,
): List<OpenSourcePackageLicense> {
    val normalized = query.trim().lowercase()
    if (normalized.isEmpty()) {
        return packages
    }
    return packages.filter { it.packageName.lowercase().contains(normalized) }
}

/**
 * 把 Flutter 的 `NOTICES`（`flutter_assets/NOTICES.Z` 解压后的全文）解析成注册表条目。
 *
 * ## 为什么需要它（2026-10-28 补的数据源）
 *
 * Flutter 侧用 `LicenseRegistry.licenses` 拿许可证；Compose 侧没有这个运行时，但 APK 里打包的
 * `NOTICES` 文件就是 `LicenseRegistry` 的**同一份底层来源**（Flutter 工具链把所有依赖包 LICENSE
 * 汇总成一个文件）。这里把它的文本格式解析出来，复用 [buildOpenSourcePackageLicenses] 做聚合——
 * 于是列表**真的有内容**，而不是永远空。
 *
 * ## NOTICES 的文本格式（与 Flutter 一致，已用构建产物实测）
 *
 * 每个条目之间用**一整行恰好 80 个 `-`** 分隔。条目内：
 * 1. 开头连续若干**非空行** = 包名（一个包一行）；
 * 2. 空行之后是许可证正文，正文里的空行分段（对应 [LicenseRegistryEntry.paragraphs]）。
 *
 * 解析不出来（空块 / 无包名 / 正文全空）的条目**跳过**，绝不产生空条目。
 *
 * @param text `NOTICES` 解压后的全文
 * @return 按出现顺序的注册表条目（聚合与排序交给 [buildOpenSourcePackageLicenses]）
 */
fun parseFlutterNotices(text: String): List<LicenseRegistryEntry> {
    val normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    if (normalized.isBlank()) {
        return emptyList()
    }
    val separator = "-".repeat(80)
    val blocks = mutableListOf<MutableList<String>>()
    var current = mutableListOf<String>()
    for (line in normalized.split("\n")) {
        if (line == separator) {
            blocks.add(current)
            current = mutableListOf()
        } else {
            current.add(line)
        }
    }
    if (current.isNotEmpty()) {
        blocks.add(current)
    }

    val entries = mutableListOf<LicenseRegistryEntry>()
    for (block in blocks) {
        val trimmed = block.dropWhile { it.isBlank() }.dropLastWhile { it.isBlank() }
        if (trimmed.isEmpty()) {
            continue
        }
        val packageLines = trimmed.takeWhile { it.isNotBlank() }
        val bodyLines = trimmed.drop(packageLines.size).dropWhile { it.isBlank() }
        val packages = packageLines.map { it.trim() }.filter { it.isNotEmpty() }
        val paragraphs = splitNoticesParagraphs(bodyLines)
        if (packages.isEmpty() || paragraphs.isEmpty()) {
            continue
        }
        entries.add(LicenseRegistryEntry(packages = packages, paragraphs = paragraphs))
    }
    return entries
}

/** 按空行分段，逐段 `trim`，丢弃空段（与 Flutter `LicenseEntryWithLineBreaks` 口径一致）。 */
private fun splitNoticesParagraphs(lines: List<String>): List<String> {
    val paragraphs = mutableListOf<String>()
    val buffer = mutableListOf<String>()
    fun flush() {
        if (buffer.isNotEmpty()) {
            val paragraph = buffer.joinToString("\n").trim()
            if (paragraph.isNotEmpty()) {
                paragraphs.add(paragraph)
            }
            buffer.clear()
        }
    }
    for (line in lines) {
        if (line.isBlank()) {
            flush()
        } else {
            buffer.add(line)
        }
    }
    flush()
    return paragraphs
}

/**
 * 开源许可页文案（逐字取自 `lib/l10n/app_zh.arb`）。
 *
 * 不做手抄信任：`OpenSourceLicensesModelTest` 会用 MiniJson 直接读 ARB 文件逐字对拍，
 * 任何一处与 ARB 不一致都会红。这样以后改文案时，忘了同步这里就会被测试抓住。
 */
object OpenSourceLicensesStrings {
    const val title = "开源许可"
    const val subtitle = "本应用协议与第三方组件许可证"
    const val searchHint = "搜索组件名称"
    const val appSectionTitle = "许可说明"
    const val appLicenseLabel = "轻屿课表源码以 GPL-3.0-or-later 发布。"
    const val intro = "下方列表为本应用使用的开源组件及其许可证，点进可查看全文。"
    const val extraUmeng = "友盟统计等分析服务仅在你同意隐私政策后启用，适用友盟自身的用户协议与隐私政策。"
    const val loadFailed = "加载许可证失败，请稍后重试"
    const val empty = "没有匹配的组件"

    /** ARB `aboutOpenSourceLicensesPackagesSectionTitle`（`开源组件 {count}`）。 */
    fun packagesSectionTitle(count: Int): String = "开源组件 $count"

    /** ARB `aboutOpenSourceLicensesPackageSubtitle`（`{count} 份许可证文本`）。 */
    fun packageSubtitle(count: Int): String = "$count 份许可证文本"
}
