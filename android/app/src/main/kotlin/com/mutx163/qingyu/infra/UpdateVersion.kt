package com.mutx163.qingyu.infra

/**
 * 版本号比较与发行版挑选纯逻辑（源：lib/services/app_update_service.dart）。
 *
 * 与 Dart 逐行对齐：
 * - [normalizeVersion]：去空白 + 去单个 `v`/`V` 前缀。
 * - [compareVersions]：主段按位补 0 比；显式 `-` 预发布按「数字全段并入主段」
 *   规则折叠（`1.1.10-3` == `1.1.10.3`）；`1.2.0-29-debug` 的数字前缀并入主段；
 *   无显式 `-` 的超长点分段（`1.1.10.3` 的第 4 段）同样并入主段后再比；
 *   剩余文本型预发布按段比（数字 < 文本，同数字前缀继续下一段）。
 * - [pickApkDownload]：URL 与 digest 必须同源（同一 asset），四档优先。
 * - [pickLatestEligibleRelease]：跳过 draft、（按需）跳过 prerelease、无可用
 *   下载地址的跳过，按 [compareVersions] 取最高。
 *
 * Dart 测试锚点（test/services/app_update_service_test.dart）：
 * `1.1.10.3` == `1.1.10-3+33`；`1.2.0.29` == `1.2.0-29-debug`；
 * `1.1.10.4`（预发布）> `1.1.10`；同源 asset 的 URL/digest 不交叉。
 */

fun normalizeVersion(raw: String): String {
    val trimmed = raw.trim()
    return if (trimmed.startsWith("v") || trimmed.startsWith("V")) {
        trimmed.substring(1)
    } else {
        trimmed
    }
}

data class ParsedVersion(val mainParts: List<Int>, val prerelease: String?)

fun parseVersion(version: String): ParsedVersion {
    val normalized = normalizeVersion(version).split("+").first()
    val dashIndex = normalized.indexOf('-')
    val hasExplicitPrerelease = dashIndex != -1
    val base = if (hasExplicitPrerelease) normalized.substring(0, dashIndex) else normalized
    val explicitPrerelease = if (hasExplicitPrerelease) {
        normalized.substring(dashIndex + 1).trim()
    } else {
        null
    }
    val baseParts = base.split(".")
    fun digitsOf(item: String): Int = item.filter { it.isDigit() }.toIntOrNull() ?: 0
    val numericExplicitParts = if (explicitPrerelease == null) {
        null
    } else {
        parseNumericParts(explicitPrerelease)
    }
    if (numericExplicitParts != null && numericExplicitParts.isNotEmpty()) {
        return ParsedVersion(
            mainParts = baseParts.map { digitsOf(it) } + numericExplicitParts,
            prerelease = null,
        )
    }
    if (explicitPrerelease != null) {
        val numericPrefix = extractNumericPrefixParts(explicitPrerelease)
        if (numericPrefix != null && numericPrefix.isNotEmpty()) {
            return ParsedVersion(
                mainParts = baseParts.map { digitsOf(it) } + numericPrefix,
                prerelease = null,
            )
        }
    }
    val numericDottedSuffixParts = if (!hasExplicitPrerelease && baseParts.size > 3) {
        parseNumericParts(baseParts.drop(3).joinToString("."))
    } else {
        null
    }
    if (numericDottedSuffixParts != null && numericDottedSuffixParts.isNotEmpty()) {
        return ParsedVersion(
            mainParts = baseParts.take(3).map { digitsOf(it) } + numericDottedSuffixParts,
            prerelease = null,
        )
    }
    val hasDottedPrerelease = !hasExplicitPrerelease && baseParts.size > 3
    val main = if (hasDottedPrerelease) baseParts.take(3).joinToString(".") else base
    val prerelease = if (hasExplicitPrerelease) {
        explicitPrerelease
    } else if (hasDottedPrerelease) {
        baseParts.drop(3).joinToString(".")
    } else {
        null
    }
    return ParsedVersion(
        mainParts = main.split(".").map { digitsOf(it) },
        prerelease = if (prerelease.isNullOrEmpty()) null else prerelease,
    )
}

internal fun parseNumericParts(raw: String): List<Int>? {
    val parts = raw.split(".").map { it.trim() }.filter { it.isNotEmpty() }
    if (parts.isEmpty()) {
        return null
    }
    val values = arrayListOf<Int>()
    for (part in parts) {
        values.add(part.toIntOrNull() ?: return null)
    }
    return values
}

internal fun extractNumericPrefixParts(raw: String): List<Int>? {
    val values = arrayListOf<Int>()
    for (part in raw.split(".")) {
        val direct = part.toIntOrNull()
        if (direct != null) {
            values.add(direct)
            continue
        }
        val prefix = Regex("^\\d+").find(part)?.value?.toIntOrNull()
        if (prefix != null) {
            values.add(prefix)
        }
        break
    }
    return if (values.isEmpty()) null else values
}

internal fun extractNumericPrefix(value: String): Int? =
    Regex("^\\d+").find(value)?.value?.toIntOrNull()

internal fun comparePrerelease(left: String, right: String): Int {
    val leftParts = left.split(".")
    val rightParts = right.split(".")
    val maxLength = maxOf(leftParts.size, rightParts.size)
    for (index in 0 until maxLength) {
        val leftValue = if (index < leftParts.size) leftParts[index] else ""
        val rightValue = if (index < rightParts.size) rightParts[index] else ""
        if (leftValue == rightValue) {
            continue
        }
        val leftNumber = leftValue.toIntOrNull()
        val rightNumber = rightValue.toIntOrNull()
        if (leftNumber != null && rightNumber != null) {
            return leftNumber.compareTo(rightNumber)
        }
        val leftPrefix = leftNumber ?: extractNumericPrefix(leftValue)
        val rightPrefix = rightNumber ?: extractNumericPrefix(rightValue)
        if (leftPrefix != null && rightPrefix != null) {
            if (leftPrefix != rightPrefix) {
                return leftPrefix.compareTo(rightPrefix)
            }
            continue
        }
        if (leftNumber != null) {
            return -1
        }
        if (rightNumber != null) {
            return 1
        }
        return leftValue.compareTo(rightValue)
    }
    return 0
}

/** >0 左新，<0 右新，0 相等。+ 构建元数据不参与比较（Dart `split('+').first`）。 */
fun compareVersions(left: String, right: String): Int {
    val leftVersion = parseVersion(left)
    val rightVersion = parseVersion(right)
    val maxLength = maxOf(leftVersion.mainParts.size, rightVersion.mainParts.size)
    for (index in 0 until maxLength) {
        val leftValue = if (index < leftVersion.mainParts.size) leftVersion.mainParts[index] else 0
        val rightValue = if (index < rightVersion.mainParts.size) rightVersion.mainParts[index] else 0
        if (leftValue != rightValue) {
            return leftValue.compareTo(rightValue)
        }
    }
    val leftPre = leftVersion.prerelease
    val rightPre = rightVersion.prerelease
    if (leftPre == null && rightPre == null) {
        return 0
    }
    if (leftPre == null) {
        return 1
    }
    if (rightPre == null) {
        return -1
    }
    return comparePrerelease(leftPre, rightPre)
}

/** 是否有可用更新（Dart `_buildCheckResult` 的比较核）。 */
fun hasUpdate(latestVersion: String, currentVersion: String): Boolean =
    compareVersions(latestVersion, currentVersion) > 0

private const val sha256DigestPrefix = "sha256:"

private fun digestOf(asset: Map<String, Any?>): String? {
    val digest = (asset["digest"] as? String)?.trim() ?: ""
    if (digest.length <= sha256DigestPrefix.length) {
        return null
    }
    val value = digest.lowercase()
    return if (value.startsWith(sha256DigestPrefix)) {
        value.substring(sha256DigestPrefix.length)
    } else {
        null
    }
}

private fun urlOf(asset: Map<String, Any?>): String? = asset["browser_download_url"] as? String

/**
 * 取下载地址与官方 SHA-256（Dart `_pickApkDownload`）。
 *
 * URL 与 digest 必须来自同一个 asset：四档优先（带摘要的非 debug APK →
 * 无摘要的非 debug APK → 任意 APK → 首个资产兜底且无摘要）。
 */
fun pickApkDownload(assets: List<Any?>): Pair<String?, String?> {
    val normalized = assets.filterIsInstance<Map<*, *>>().map { raw ->
        val mapped = linkedMapOf<String, Any?>()
        for ((k, v) in raw) {
            mapped[k.toString()] = v
        }
        mapped
    }
    for (asset in normalized) {
        val name = (asset["name"] as? String)?.lowercase() ?: ""
        if (name.endsWith(".apk") && !name.contains("debug") && digestOf(asset) != null) {
            return Pair(urlOf(asset), digestOf(asset))
        }
    }
    for (asset in normalized) {
        val name = (asset["name"] as? String)?.lowercase() ?: ""
        if (name.endsWith(".apk") && !name.contains("debug")) {
            return Pair(urlOf(asset), null)
        }
    }
    for (asset in normalized) {
        val name = (asset["name"] as? String)?.lowercase() ?: ""
        if (name.endsWith(".apk")) {
            return Pair(urlOf(asset), digestOf(asset))
        }
    }
    val first = normalized.firstOrNull()
    return Pair(if (first == null) null else urlOf(first), null)
}

private fun releaseAssetsOf(releaseJson: Map<String, Any?>): List<Any?> =
    (releaseJson["assets"] as? List<*>) ?: emptyList<Any?>()

fun hasUsableDownloadUrl(releaseJson: Map<String, Any?>): Boolean =
    pickApkDownload(releaseAssetsOf(releaseJson)).first != null

/**
 * 从发行版 JSON 列表里挑最高可用版本（Dart `_pickLatestEligibleRelease`）。
 *
 * 跳过：draft、（includePrerelease=false 时）prerelease、无可用下载地址、
 * 版本号为空。返回原始 map（调用方再按需构造模型）。
 */
fun pickLatestEligibleRelease(
    rawList: List<Any?>,
    includePrerelease: Boolean,
): Map<String, Any?>? {
    var bestRelease: Map<String, Any?>? = null
    var bestVersion: String? = null
    for (item in rawList) {
        if (item !is Map<*, *>) {
            continue
        }
        val release = linkedMapOf<String, Any?>()
        for ((k, v) in item) {
            release[k.toString()] = v
        }
        if (release["draft"] == true) {
            continue
        }
        if (!includePrerelease && release["prerelease"] == true) {
            continue
        }
        if (!hasUsableDownloadUrl(release)) {
            continue
        }
        val candidateVersion = normalizeVersion(
            (release["tag_name"] as? String) ?: (release["name"] as? String) ?: "",
        )
        if (candidateVersion.isEmpty()) {
            continue
        }
        val currentBest = bestVersion
        if (bestRelease == null || currentBest == null ||
            compareVersions(candidateVersion, currentBest) > 0
        ) {
            bestRelease = release
            bestVersion = candidateVersion
        }
    }
    return bestRelease
}
