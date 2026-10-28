package com.mutx163.qingyu.pages.about

/**
 * 发布说明（`docs/releases/v*.md` / Release 正文）→「重点摘要」的纯逻辑。
 *
 * 逐条移植 `lib/utils/release_notes_digest.dart`(637 行，2026-10-28 快照)，
 * 供**更新日志页**（`ChangelogPage`）与后续的「本次更新说明」共用。
 *
 * ## 为什么要有这一层
 *
 * Dart 侧注释写得很清楚：一个版本的发布说明是**扁平的一长串**条目（实测 v2.1.3.2 有
 * 46 条、正文 90 多行），直接把正文丢给 Markdown 渲染，用户看到的是「一大串更新内容的
 * 顶部」——既不是重点，一条 60 字的说明还会在第二行中途被截断。
 *
 * 这里把正文解析成结构化条目，供界面只展示「说得清、看得完」的部分：
 * 至多 3 条重点 + 一行分类计数 + 按需展开的完整条目。
 *
 * ## 与 Dart 的对应关系（改动这一层前先读）
 *
 * | Dart | 这里 |
 * |---|---|
 * | `ReleaseChangeKind` | [ReleaseChangeKind]（枚举名大写，本仓惯例） |
 * | `ReleaseChangeEntry` | [ReleaseChangeEntry] |
 * | `ReleaseNotesDigest` | [ReleaseNotesDigest] |
 * | `buildReleaseNotesDigest` | [buildReleaseNotesDigest] |
 * | `releaseChangeCounts` | [releaseChangeCounts] |
 *
 * 分类词表、重点挑选优先级、声明重点的匹配阈值（0.34）**都取自 Dart**，
 * 不是这里另定的口径；调它们要两侧一起调。
 */

/** 一条发布说明条目的变更类型。 */
enum class ReleaseChangeKind { ADDED, IMPROVED, FIXED, REMOVED, OTHER }

/**
 * 解析后的一条变更。
 *
 * @param kind 归一化后的分类（决定重点的挑选顺序）。
 * @param text 条目原文（已去掉列表符号与分类前缀），展开列表里显示完整句子。
 * @param headline 短标题：第一个句内分隔符之前的那半句，供重点行使用。
 * @param label 正文里作者原本用的分类词（「新增」「Improved」…），空串表示没有分类前缀。
 *
 * 分类标签直接用作者自己的词，而不是另立一套翻译：发布说明是中文写、应用六种语言都显示
 * 同一份正文，标签跟正文保持同一种语言才不会有割裂感；将来正文改写成英文，标签也会
 * 自动跟着变成英文。
 */
data class ReleaseChangeEntry(
    val kind: ReleaseChangeKind,
    val text: String,
    val headline: String,
    val label: String = "",
)

/** 一版发布说明的重点摘要。 */
data class ReleaseNotesDigest(
    /** 全部条目，按正文顺序。 */
    val entries: List<ReleaseChangeEntry> = emptyList(),
    /** 至多 3 条重点，供重点行展示。 */
    val highlights: List<ReleaseChangeEntry> = emptyList(),
    /** 重点是否由发布说明自己声明（否则是按分类优先级推断的）。 */
    val highlightsDeclared: Boolean = false,
    /**
     * 版本标题之后、第一条条目之前的那句导语（如「首个推荐版本。」）。
     *
     * 老版本的发布说明常有一句概括；历史版本页与官网卡片用它当副标题，
     * 比只显示版本号更容易让人知道「这一版是什么」。空串表示没有导语。
     */
    val intro: String = "",
) {
    /** 正文里没有任何可用条目的哨兵值。 */
    val isEmpty: Boolean get() = entries.isEmpty() && highlights.isEmpty()

    /**
     * 声明的重点里**没能认回任何条目**的那些（返回的是声明时写的原文）。
     *
     * `> 本次重点：A、B、C` 允许写简写，但简写要能被认回某条条目（先看互相包含，
     * 再按二字组重合率兜底）。认不回来时解析器仍保留这条简写——[kind] 记为
     * [ReleaseChangeKind.OTHER]、[ReleaseChangeEntry.label] 为空、
     * [ReleaseChangeEntry.text] 与 [ReleaseChangeEntry.headline] 相同。
     *
     * 发版前用这个 getter 自检：非空就说明重点行里写了条目中没有的说法。
     */
    val unresolvedHighlights: List<ReleaseChangeEntry>
        get() = highlights.filter {
            it.kind == ReleaseChangeKind.OTHER && it.text == it.headline
        }

    /** 条目总数（展开按钮上的「查看全部 N 项」用它）。 */
    val total: Int get() = entries.size

    fun countOf(kind: ReleaseChangeKind): Int = entries.count { it.kind == kind }

    companion object {
        val EMPTY = ReleaseNotesDigest()
    }
}

/**
 * 默认展示几条重点。
 *
 * 3 是「一屏能扫完、又装得下两个新增加一条优化」的量；再多就退化成又一份长列表了
 * （这正是要修的问题）。
 */
const val defaultReleaseHighlightCount: Int = 3

/** 重点的挑选顺序：新增 > 优化 > 移除 > 修复 > 无分类。 */
private val highlightKindPriority = listOf(
    ReleaseChangeKind.ADDED,
    ReleaseChangeKind.IMPROVED,
    ReleaseChangeKind.REMOVED,
    ReleaseChangeKind.FIXED,
    ReleaseChangeKind.OTHER,
)

/** 分类标签在计数行里的固定顺序（新增 · 优化 · 修复 · 移除）。 */
private val countKindOrder = listOf(
    ReleaseChangeKind.ADDED,
    ReleaseChangeKind.IMPROVED,
    ReleaseChangeKind.FIXED,
    ReleaseChangeKind.REMOVED,
)

/** 中文分类词表：顺序即优先级，先匹配到的算数（`新增功能` 必须排在 `新增` 前面）。 */
private val kindPrefixes: List<Pair<String, ReleaseChangeKind>> = listOf(
    "新增功能" to ReleaseChangeKind.ADDED,
    "新增" to ReleaseChangeKind.ADDED,
    "增加" to ReleaseChangeKind.ADDED,
    "优化" to ReleaseChangeKind.IMPROVED,
    "改进" to ReleaseChangeKind.IMPROVED,
    "改善" to ReleaseChangeKind.IMPROVED,
    "修复" to ReleaseChangeKind.FIXED,
    "修正" to ReleaseChangeKind.FIXED,
    "移除" to ReleaseChangeKind.REMOVED,
    "删除" to ReleaseChangeKind.REMOVED,
    "下线" to ReleaseChangeKind.REMOVED,
)

private val englishKinds: Map<String, ReleaseChangeKind> = mapOf(
    "new" to ReleaseChangeKind.ADDED,
    "add" to ReleaseChangeKind.ADDED,
    "adds" to ReleaseChangeKind.ADDED,
    "added" to ReleaseChangeKind.ADDED,
    "feature" to ReleaseChangeKind.ADDED,
    "features" to ReleaseChangeKind.ADDED,
    "improve" to ReleaseChangeKind.IMPROVED,
    "improved" to ReleaseChangeKind.IMPROVED,
    "improves" to ReleaseChangeKind.IMPROVED,
    "enhance" to ReleaseChangeKind.IMPROVED,
    "enhanced" to ReleaseChangeKind.IMPROVED,
    "optimize" to ReleaseChangeKind.IMPROVED,
    "optimized" to ReleaseChangeKind.IMPROVED,
    "fix" to ReleaseChangeKind.FIXED,
    "fixes" to ReleaseChangeKind.FIXED,
    "fixed" to ReleaseChangeKind.FIXED,
    "remove" to ReleaseChangeKind.REMOVED,
    "removes" to ReleaseChangeKind.REMOVED,
    "removed" to ReleaseChangeKind.REMOVED,
    "deprecate" to ReleaseChangeKind.REMOVED,
    "deprecated" to ReleaseChangeKind.REMOVED,
)

private val headingPattern = Regex("^#{1,6}\\s+")
private val bulletPattern = Regex("^(?:[-+*]|\\d+[.)])\\s*(.+)$")
private val rulePattern = Regex("^(?:-{3,}|\\*{3,}|_{3,})$")
private val tableRowPattern = Regex("^\\|")
private val imageLinePattern = Regex("^!\\[[^\\]]*\\]\\([^)]*\\)$")
private val inlineLinkPattern = Regex("\\[([^\\]]*)\\]\\([^)]*\\)")
private val markdownMarkerPattern = Regex("\\*\\*|__|~~|`")
private val whitespaceRunPattern = Regex("\\s+")
private val leadingSeparatorPattern = Regex("^[\\s:：\\-—–~·、,，]+")
private val headlineStopPattern = Regex("[：:；;。！!？?]")
private val englishKindPattern = Regex(
    "^(new|add|adds|added|feature|features|improve|improved|improves|enhance|enhanced|" +
        "optimize|optimized|fix|fixes|fixed|remove|removes|removed|deprecate|deprecated)\\b",
    RegexOption.IGNORE_CASE,
)

/** 正文顶部用来声明重点的引用行，例如 `> 本次重点：A、B、C`。 */
private val declaredBlockquotePattern = Regex("^(?:本次|这次)?(?:更新|版本)?(?:的)?(?:重点|亮点|看点)\\s*[:：]?\\s*")
private val declaredBlockquoteEnPattern = Regex(
    "^(?:(?:update|release)\\s+)?(?:highlights?|key\\s*points?)\\s*[-:：]?\\s*",
    RegexOption.IGNORE_CASE,
)

/** 用来声明重点的小节标题，例如 `## 本次重点`。 */
private val declaredSectionPattern = Regex("^(?:本次|这次)?(?:更新|版本)?(?:的)?(?:重点|亮点|看点)$")
private val declaredSectionEnPattern = Regex(
    "^(?:(?:update|release)\\s+)?(?:highlights?|key\\s*points?)$",
    RegexOption.IGNORE_CASE,
)

/**
 * 把一版发布说明解析成可展示的摘要。
 *
 * @param maxHighlights 要挑出的重点条数，默认 [defaultReleaseHighlightCount]。
 */
fun buildReleaseNotesDigest(
    body: String,
    maxHighlights: Int = defaultReleaseHighlightCount,
): ReleaseNotesDigest {
    val normalized = body
        .replace("\r\n", "\n")
        .replace("\r", "\n")
        .removePrefix("\uFEFF")
    if (normalized.trim().isEmpty()) {
        return ReleaseNotesDigest.EMPTY
    }

    val entries = mutableListOf<ReleaseChangeEntry>()
    val declared = mutableListOf<String>()
    var insideCodeFence = false
    var insideDeclaredSection = false
    var sawBullet = false
    var intro = ""
    // 新版按分类分组（`## 新增`），条目本身不带前缀；旧版是扁平列表、条目自带
    // 「新增 」前缀。分组标题定下的分类会继承给后面不带前缀的条目。
    var sectionKind = ReleaseChangeKind.OTHER
    var sectionLabel = ""

    for (rawLine in normalized.split("\n")) {
        // 用没被 trimLeft 的行判断列表符号：发布说明里的二级条目是缩进的，
        // 属于上一条的细节说明，不该被当成独立条目重复计数。
        val line = rawLine.trimEnd()
        val trimmed = line.trim()
        if (trimmed.startsWith("```") || trimmed.startsWith("~~~")) {
            insideCodeFence = !insideCodeFence
            continue
        }
        if (insideCodeFence || trimmed.isEmpty()) {
            continue
        }
        if (rulePattern.containsMatchIn(trimmed) ||
            tableRowPattern.containsMatchIn(trimmed) ||
            imageLinePattern.containsMatchIn(trimmed)
        ) {
            continue
        }
        if (headingPattern.containsMatchIn(trimmed)) {
            val headingText = trimmed
                .replaceFirst(headingPattern, "")
                .replaceFirst(Regex("[:：\\s]+$"), "")
            insideDeclaredSection =
                declaredSectionPattern.containsMatchIn(headingText) ||
                    declaredSectionEnPattern.containsMatchIn(headingText)
            val headingKind = kindFromHeading(trimmed)
            sectionKind = headingKind?.first ?: ReleaseChangeKind.OTHER
            sectionLabel = headingKind?.second ?: ""
            continue
        }
        if (trimmed.startsWith(">")) {
            val quoted = cleanInline(trimmed.replaceFirst(Regex("^>+\\s*"), ""))
            val rest = stripDeclaredLabel(quoted, declaredBlockquotePattern)
                ?: stripDeclaredLabel(quoted, declaredBlockquoteEnPattern)
            if (rest != null) {
                declared.addAll(splitDeclaredItems(rest))
            }
            continue
        }
        // 正文里的 `SHA-256: ...` 一行（GitCode 发行版正文由 CI 追加）不是条目。
        if (!trimmed.startsWith("-") &&
            !trimmed.startsWith("*") &&
            !trimmed.startsWith("+") &&
            trimmed.lowercase().contains("sha-256")
        ) {
            continue
        }
        val bulletMatch = bulletPattern.find(line)
        if (bulletMatch == null) {
            // 第一条条目之前的一小段普通文字，是这一版的导语（老版本常见：
            // 「首个推荐版本。」）。以冒号结尾的「本次更新：」这类引导句不算。
            if (!sawBullet && intro.isEmpty()) {
                val prose = cleanInline(trimmed)
                if (prose.isNotEmpty() && !prose.endsWith("：") && !prose.endsWith(":")) {
                    intro = truncateRunes(prose, introMaxRunes)
                }
            }
            continue
        }
        sawBullet = true
        val bulletText = cleanInline(bulletMatch.groupValues[1])
        if (bulletText.isEmpty()) {
            continue
        }
        val entry = entryFromBullet(bulletText, sectionKind, sectionLabel)
        if (insideDeclaredSection && entry.kind == ReleaseChangeKind.OTHER) {
            // 「## 本次重点」小节里作者写的是短句（可能不带分类前缀），
            // 整句就是声明本身；同时它也是一条真实变更。
            declared.add(entry.text)
        } else if (insideDeclaredSection) {
            declared.add(entry.headline)
        }
        entries.add(entry)
    }

    val highlights = selectHighlights(entries, declared, maxHighlights)

    return ReleaseNotesDigest(
        entries = entries,
        highlights = highlights.first,
        highlightsDeclared = highlights.second,
        intro = intro,
    )
}

/**
 * 计数行用的分类标签顺序与文案取自正文本身（见 [ReleaseChangeEntry.label]）。
 *
 * @param kinds 计数行的分类顺序，默认「新增 · 优化 · 修复 · 移除」。
 */
fun releaseChangeCounts(
    digest: ReleaseNotesDigest,
    kinds: List<ReleaseChangeKind> = countKindOrder,
): List<Pair<String, Int>> {
    val counts = mutableListOf<Pair<String, Int>>()
    for (kind in kinds) {
        val count = digest.countOf(kind)
        if (count == 0) {
            continue
        }
        val label = labelOfKind(digest.entries, kind)
        if (label.isEmpty()) {
            continue
        }
        counts.add(label to count)
    }
    return counts
}

private fun labelOfKind(entries: List<ReleaseChangeEntry>, kind: ReleaseChangeKind): String {
    for (entry in entries) {
        if (entry.kind == kind && entry.label.isNotEmpty()) {
            return entry.label
        }
    }
    return ""
}

/** 返回 (重点列表, 是否由正文声明)。 */
private fun selectHighlights(
    entries: List<ReleaseChangeEntry>,
    declared: List<String>,
    maxHighlights: Int,
): Pair<List<ReleaseChangeEntry>, Boolean> {
    if (maxHighlights <= 0) {
        return emptyList<ReleaseChangeEntry>() to false
    }

    val resolved = mutableListOf<ReleaseChangeEntry>()
    val seen = mutableSetOf<String>()
    for (wanted in declared) {
        if (resolved.size >= maxHighlights) {
            break
        }
        val matched = matchDeclared(entries, wanted)
        val item = ReleaseChangeEntry(
            kind = matched?.kind ?: ReleaseChangeKind.OTHER,
            text = matched?.text ?: wanted,
            headline = wanted,
            label = matched?.label ?: "",
        )
        if (seen.add(item.headline)) {
            resolved.add(item)
        }
    }
    if (resolved.isNotEmpty()) {
        return resolved to true
    }

    val fallback = mutableListOf<ReleaseChangeEntry>()
    for (kind in highlightKindPriority) {
        for (entry in entries) {
            if (entry.kind != kind) {
                continue
            }
            fallback.add(entry)
            if (fallback.size >= maxHighlights) {
                break
            }
        }
        if (fallback.size >= maxHighlights) {
            break
        }
    }
    return fallback to false
}

/**
 * 声明的简写要认回正文里的那条条目，靠两步：
 * 先看是否互相包含（「Bing 每日壁纸库」是原文子串），再按相似度兜底。
 *
 * 兜底不是锦上添花：作者声明时写的是给人看的简写（「十档玻璃滑杆」），正文那条是
 * （「液态玻璃的档位改成一根 10 格节点滑杆」），两者**字面上不互为子串**。没有这一层，
 * 声明的重点就会整条对不上分类，标签只能显示成「其他」。
 */
private fun matchDeclared(
    entries: List<ReleaseChangeEntry>,
    wanted: String,
): ReleaseChangeEntry? {
    val key = normalizeForMatch(wanted)
    if (key.isEmpty()) {
        return null
    }
    for (entry in entries) {
        if (normalizeForMatch(entry.text).contains(key)) {
            return entry
        }
    }
    for (entry in entries) {
        if (normalizeForMatch(entry.headline).contains(key)) {
            return entry
        }
    }
    for (entry in entries) {
        val headlineKey = normalizeForMatch(entry.headline)
        if (headlineKey.isNotEmpty() && key.contains(headlineKey)) {
            return entry
        }
    }

    var best: ReleaseChangeEntry? = null
    var bestScore = 0.0
    for (entry in entries) {
        val score = similarity(key, normalizeForMatch(entry.text))
        val headlineScore = similarity(key, normalizeForMatch(entry.headline))
        val resolved = if (score > headlineScore) score else headlineScore
        if (resolved > bestScore) {
            bestScore = resolved
            best = entry
        }
    }
    return if (bestScore >= declaredMatchThreshold) best else null
}

/**
 * 相似度阈值：中文按二字组重合率算，40% 上下足够认出简写与正文的同一件事，
 * 又不会把两条无关的变更凑到一起。
 */
private const val declaredMatchThreshold: Double = 0.34

private val asciiWordPattern = Regex("^[a-z0-9 ]+$")
private val tokenSeparatorPattern = Regex("\\s+")

private fun similarity(key: String, candidate: String): Double {
    if (key.isEmpty() || candidate.isEmpty()) {
        return 0.0
    }
    if (asciiWordPattern.containsMatchIn(key) && asciiWordPattern.containsMatchIn(candidate)) {
        return tokenOverlap(key, candidate)
    }
    val keyBigrams = bigrams(key)
    if (keyBigrams.isEmpty()) {
        return if (candidate.contains(key)) 1.0 else 0.0
    }
    val candidateBigrams = bigrams(candidate)
    var overlap = 0
    for (gram in keyBigrams) {
        if (candidateBigrams.contains(gram)) {
            overlap++
        }
    }
    return overlap.toDouble() / keyBigrams.size
}

private fun tokenOverlap(key: String, candidate: String): Double {
    val keyTokens = key.split(tokenSeparatorPattern).filter { it.isNotEmpty() }
    if (keyTokens.isEmpty()) {
        return 0.0
    }
    val candidateTokens = candidate.split(tokenSeparatorPattern)
        .filter { it.isNotEmpty() }
        .toSet()
    var overlap = 0
    for (token in keyTokens) {
        if (token.length >= 2 && candidateTokens.contains(token)) {
            overlap++
        }
    }
    return overlap.toDouble() / keyTokens.size
}

/** 按**码点**取二字组：代理对（emoji）不会被劈成两个半字符。 */
private fun bigrams(value: String): Set<String> {
    val runes = value.codePoints().toArray()
    val grams = mutableSetOf<String>()
    for (index in 0 until runes.size - 1) {
        grams.add(codePointString(runes[index]) + codePointString(runes[index + 1]))
    }
    return grams
}

private fun codePointString(codePoint: Int): String {
    val builder = StringBuilder()
    builder.appendCodePoint(codePoint)
    return builder.toString()
}

/**
 * 归一化时要去掉的标点（Dart `_normalizeForMatch` 的字符类，逐字对应）。
 *
 * ⚠️ 连字符必须写成 `\-`：写成裸 `-` 会被正则当成**范围**（`.` 到 `—`），
 * 那会把数字、字母、汉字全部吃掉，声明重点永远匹配不上。
 */
private val normalizeForMatchPattern =
    Regex("[\\s，。、；：:;,\\.\\-—…「」『』（）()《》\\[\\]\"“”']")

private fun normalizeForMatch(value: String): String =
    value.lowercase().replace(normalizeForMatchPattern, "")

private fun stripDeclaredLabel(value: String, pattern: Regex): String? {
    val match = pattern.find(value) ?: return null
    return value.substring(match.range.last + 1)
}

private fun splitDeclaredItems(value: String): List<String> = value
    .split(Regex("[、,，;；|/]"))
    .map { it.trim() }
    .filter { it.isNotEmpty() }

private fun entryFromBullet(
    bullet: String,
    fallbackKind: ReleaseChangeKind = ReleaseChangeKind.OTHER,
    fallbackLabel: String = "",
): ReleaseChangeEntry {
    var kind = ReleaseChangeKind.OTHER
    var label = ""
    var rest = bullet

    for ((keyword, prefixKind) in kindPrefixes) {
        if (rest.startsWith(keyword) && rest.length > keyword.length) {
            kind = prefixKind
            label = keyword
            rest = rest.substring(keyword.length)
            break
        }
    }
    if (kind == ReleaseChangeKind.OTHER) {
        val match = englishKindPattern.find(rest)
        if (match != null && rest.length > match.range.last + 1) {
            val keyword = match.groupValues[1]
            kind = englishKinds.getValue(keyword.lowercase())
            label = titleCaseLabel(keyword, bullet)
            rest = rest.substring(match.range.last + 1)
        }
    }
    if (kind == ReleaseChangeKind.OTHER && fallbackKind != ReleaseChangeKind.OTHER) {
        // 新版发布说明按分类分组（`## 新增`），条目本身不带前缀 ——
        // 分类从分组标题继承，历史扁平格式仍走上面的前缀识别。
        kind = fallbackKind
        label = fallbackLabel
    }

    val text = stripLeadingSeparators(rest)
    val resolved = if (text.isEmpty()) bullet else text
    return ReleaseChangeEntry(
        kind = kind,
        text = resolved,
        headline = headlineOf(resolved),
        label = label,
    )
}

/**
 * 从「## 新增 · 12」「### ✨ 修复」「### Removed」这类分组标题里认出分类。
 *
 * 返回分类与标题里作者用的词（计数行与重点行沿用这个词）。认不出时返回 null，
 * 后面的条目就按「无分类」处理，不会错误继承上一个分组的类型。
 */
private fun kindFromHeading(rawHeading: String): Pair<ReleaseChangeKind, String>? {
    var text = rawHeading
        .replaceFirst(headingPattern, "")
        .replace(markdownMarkerPattern, "")
        .trim()
    // 去掉标题前的 emoji / 装饰符号（`### ✨ 新增`）。
    text = text.replaceFirst(Regex("^[^A-Za-z0-9\\u4e00-\\u9fff]+"), "")
    if (text.isEmpty()) {
        return null
    }
    for ((keyword, prefixKind) in kindPrefixes) {
        if (text.startsWith(keyword)) {
            return prefixKind to keyword
        }
    }
    val match = englishKindPattern.find(text)
    if (match != null) {
        val keyword = match.groupValues[1]
        return englishKinds.getValue(keyword.lowercase()) to titleCaseLabel(keyword, text)
    }
    return null
}

/**
 * 英文分类词按作者原本的大小写展示（`New` / `NEW` 各自保持），
 * 这样标签不会和正文里那一行看起来是两种写法。
 */
private fun titleCaseLabel(keyword: String, source: String): String {
    val start = source.lowercase().indexOf(keyword.lowercase())
    if (start < 0) {
        return keyword
    }
    return source.substring(start, start + keyword.length)
}

private fun stripLeadingSeparators(value: String): String =
    value.replaceFirst(leadingSeparatorPattern, "").trim()

private fun cleanInline(raw: String): String {
    var text = inlineLinkPattern.replace(raw) { match -> match.groupValues[1] }
    text = text.replace(markdownMarkerPattern, "")
    return text.replace(whitespaceRunPattern, " ").trim()
}

/**
 * 短标题的长度上限。
 *
 * 重点行按 14sp、两行收住，窄屏每行约 18～20 个汉字，40 字是「两行刚好、再多就靠
 * 省略号」的尺度。
 */
private const val headlineMaxRunes: Int = 40

/** 导语长度上限：历史版本页与官网卡片只留一行到两行。 */
private const val introMaxRunes: Int = 80

private fun headlineOf(text: String): String {
    val match = headlineStopPattern.find(text)
    var headline = if (match == null) text else text.substring(0, match.range.first)
    headline = headline.trim()
    if (headline.isEmpty()) {
        headline = text.trim()
    }
    return truncateRunes(headline, headlineMaxRunes)
}

/** 按**码点**截断，超长补省略号（Dart 的 `runes.take(max)`）。 */
private fun truncateRunes(value: String, max: Int): String {
    val runes = value.codePoints().toArray()
    if (runes.size <= max) {
        return value
    }
    val builder = StringBuilder()
    for (index in 0 until max) {
        builder.appendCodePoint(runes[index])
    }
    return builder.append('…').toString()
}
