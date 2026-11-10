package com.mutx163.qingyu.infra

import java.net.URI
import java.net.URLEncoder
import java.time.Instant

/**
 * 更新信任根与下载地址纯逻辑（源：lib/services/app_update_service.dart、
 * lib/utils/async_utils.dart、lib/models/settings/timetable_settings_enums.dart）。
 *
 * 与 Dart 逐行对齐：
 * - 清单（发行版 JSON/页面 HTML）只走官方直连（[isTrustedManifestUrl]），镜像
 *   前缀一律不进候选池（2026-10-19 信任根收紧）；
 * - APK 字节流可用镜像加速（[isTrustedApkDownloadUrl] 认镜像主机），但安装前
 *   必须有直连渠道的 digest（[withDigestTrustMark]，缺省即剥离）；
 * - [isOfficialApkAssetUrl] 限定「本仓库 release 资产路径」（剥最多 3 层镜像外壳）；
 * - [isRedirectTargetAllowed] 限定重定向落点（官方资产路径或 GitHub CDN 域）。
 *
 * 枚举的 canonical 家在 `models/settings/timetable_settings_enums.dart`
 *（第一团队时间/周次族范围）；本族自持同名定义以保持零跨泳道依赖，
 * 合入时由 Lead 统一（包名不同，不会编译冲突）。
 */

const val repositoryUrl = "https://github.com/Mutx163/mikcb"
const val releasesApiUrl = "https://api.github.com/repos/Mutx163/mikcb/releases"
const val releasesPageUrl = "$repositoryUrl/releases"
const val gitcodeRepositoryUrl = "https://gitcode.com/mutx/qingyu"
const val gitcodeReleasesApiUrl = "https://api.gitcode.com/api/v5/repos/mutx/qingyu/releases"
const val defaultMirrorUrlPrefix = "https://ghfast.top/"
const val pgyerDownloadPageUrl = "https://www.pgyer.com/qingyu"

val allBuiltinMirrorUrlPrefixes: List<String> = listOf(
    "https://ghfast.top/",
    "https://gh.llkk.cc/",
    "https://gh-proxy.com/",
    "https://ghproxy.net/",
)

val officialManifestUrlHosts: List<String> = listOf(
    "github.com",
    "githubusercontent.com",
    "gitcode.com",
)

enum class AppUpdateDownloadSource { ORIGINAL, MIRROR }

enum class AppUpdateDownloadChannel { PGYER, GITHUB, GITCODE }

/**
 * 更新清单的三种**直连**来源（发布版 `app_update_service.dart:256-307` 的三路竞速）。
 *
 * 三者都是官方直连，镜像**永不**进清单候选池（2026-10-19 信任根收紧：镜像对清单有
 * 完全控制权，不该让它回答「有没有新版本」）。
 */
enum class AppUpdateManifestSource { GITHUB_API, RELEASES_PAGE_HTML, GITCODE_API }

/** 一条清单候选：来源 + 直连 URL。 */
data class AppUpdateManifestCandidate(
    val source: AppUpdateManifestSource,
    val url: String,
)

/**
 * 按下载渠道推导清单候选链（顺序 = 起跑顺序，也是同时完成时的优先级）。
 *
 * - **GitCode 渠道**：国内网络里 GitCode 通常最先通，把它排在第一位
 *   （`gitcodeReleasesApiUrl` 此前在 `UpdateUrls.kt` 里现成未用）；
 * - **GitHub / PGYER 渠道**：GitHub API 优先、Release 页 HTML 次之。
 *
 * 三条**永远都在**：发布版是三路并行竞速，渠道只决定顺序，不裁掉任何一路
 *（裁掉哪一路都会让对应网络环境退回到「单体超时」的老毛病）。
 */
fun appUpdateManifestCandidates(
    channel: AppUpdateDownloadChannel,
): List<AppUpdateManifestCandidate> {
    val gitCode = AppUpdateManifestCandidate(AppUpdateManifestSource.GITCODE_API, gitcodeReleasesApiUrl)
    val gitHubApi = AppUpdateManifestCandidate(AppUpdateManifestSource.GITHUB_API, releasesApiUrl)
    val releasesPage = AppUpdateManifestCandidate(AppUpdateManifestSource.RELEASES_PAGE_HTML, releasesPageUrl)
    return if (channel == AppUpdateDownloadChannel.GITCODE) {
        listOf(gitCode, gitHubApi, releasesPage)
    } else {
        listOf(gitHubApi, releasesPage, gitCode)
    }
}

data class AppReleaseInfo(
    val version: String,
    val title: String,
    val body: String,
    val releaseUrl: String,
    val downloadUrl: String?,
    val gitcodeDownloadUrl: String? = null,
    val pgyerDownloadUrl: String? = null,
    val updatedAtMillis: Long? = null,
    val isPrerelease: Boolean = false,
    val expectedApkSha256: String? = null,
    val digestFromDirectChannel: Boolean = false,
)

data class AppUpdateCheckResult(
    val hasRelease: Boolean,
    val hasUpdate: Boolean,
    val currentVersion: String,
    val latestRelease: AppReleaseInfo? = null,
    val message: String? = null,
)

fun buildCheckResult(currentVersion: String, release: AppReleaseInfo): AppUpdateCheckResult {
    val update = hasUpdate(release.version, currentVersion)
    return AppUpdateCheckResult(
        hasRelease = true,
        hasUpdate = update,
        currentVersion = currentVersion,
        latestRelease = release,
        message = if (update) {
            if (release.isPrerelease) "update_available_prerelease" else "update_available"
        } else {
            "already_latest"
        },
    )
}

/** 清单候选是否为不经第三方镜像的直连渠道（host 恰为 api.github.com / github.com）。 */
fun isDirectGitHubUrl(candidate: String): Boolean {
    val uri = try {
        URI(candidate.trim())
    } catch (_: Exception) {
        return false
    }
    val host = uri.host?.lowercase() ?: return false
    return host == "api.github.com" || host == "github.com"
}

/**
 * 给页面链路产出的 release 补打 digest 信任标记；镜像渠道时剥离摘要
 * （缺省即剥离：expectedApkSha256/digestFromDirectChannel 回默认值）。
 */
fun withDigestTrustMark(release: AppReleaseInfo, digestFromDirectChannel: Boolean): AppReleaseInfo {
    if (digestFromDirectChannel) {
        return release
    }
    return release.copy(expectedApkSha256 = null, digestFromDirectChannel = false)
}

/** 为 [originalUrl] 构建镜像候选：选中前缀 → 全部内置 → 原始 URL，自动去重。 */
fun buildMirrorCandidateUrls(originalUrl: String, selectedMirrorPrefix: String? = null): List<String> {
    val seen = linkedSetOf<String>()
    val candidates = arrayListOf<String>()
    fun addPrefix(prefix: String) {
        val normalized = prefix.trim()
        if (normalized.isEmpty()) {
            return
        }
        val separator = if (normalized.endsWith('/')) "" else "/"
        val url = "$normalized$separator$originalUrl"
        if (seen.add(url)) {
            candidates.add(url)
        }
    }
    if (!selectedMirrorPrefix.isNullOrEmpty()) {
        addPrefix(selectedMirrorPrefix)
    }
    for (prefix in allBuiltinMirrorUrlPrefixes) {
        addPrefix(prefix)
    }
    if (seen.add(originalUrl)) {
        candidates.add(originalUrl)
    }
    return candidates
}

private fun hostMatchesPattern(host: String, pattern: String): Boolean =
    host == pattern || host.endsWith(".$pattern")

private fun isLoopbackTestHost(host: String, scheme: String): Boolean {
    if (System.getenv("FLUTTER_TEST") != "true") {
        return false
    }
    if (host != "localhost" && host != "127.0.0.1" && host != "::1") {
        return false
    }
    return scheme == "http" || scheme == "https"
}

/**
 * APK 下载 URL 是否来自受信任来源（主机级，仅用于 APK 字节流）。
 * GitHub/GitCode 全域 + 镜像前缀主机；loopback 豁免只在 `FLUTTER_TEST=true` 生效。
 */
fun isTrustedApkDownloadUrl(url: String, mirrorUrlPrefix: String? = null): Boolean {
    val uri = try {
        URI(url)
    } catch (_: Exception) {
        return false
    }
    val host = uri.host?.lowercase() ?: return false
    val scheme = (uri.scheme ?: "").lowercase()
    if (isLoopbackTestHost(host, scheme)) {
        return true
    }
    if (scheme != "https") {
        return false
    }
    if (hostMatchesPattern(host, "github.com") || hostMatchesPattern(host, "githubusercontent.com")) {
        return true
    }
    if (hostMatchesPattern(host, "gitcode.com")) {
        return true
    }
    fun prefixHostMatches(prefix: String?): Boolean {
        if (prefix.isNullOrBlank()) {
            return false
        }
        val prefixHost = try {
            URI(prefix.trim()).host?.lowercase()
        } catch (_: Exception) {
            null
        }
        return !prefixHost.isNullOrEmpty() && host == prefixHost
    }
    if (prefixHostMatches(mirrorUrlPrefix)) {
        return true
    }
    for (prefix in allBuiltinMirrorUrlPrefixes) {
        if (prefixHostMatches(prefix)) {
            return true
        }
    }
    return false
}

/** 更新清单 URL 是否为官方直连主机（不含任何镜像；与 [isOfficialDirectUrl] 同语义）。 */
fun isOfficialDirectUrl(url: String): Boolean {
    val uri = try {
        URI(url)
    } catch (_: Exception) {
        return false
    }
    val host = uri.host?.lowercase() ?: return false
    val scheme = (uri.scheme ?: "").lowercase()
    if (isLoopbackTestHost(host, scheme)) {
        return true
    }
    if (scheme != "https") {
        return false
    }
    for (pattern in officialManifestUrlHosts) {
        if (hostMatchesPattern(host, pattern)) {
            return true
        }
    }
    return false
}

fun isTrustedManifestUrl(url: String): Boolean = isOfficialDirectUrl(url)

private val githubAssetPathPrefix: String
    get() = try {
        "${URI(repositoryUrl).path}/releases/download/"
    } catch (_: Exception) {
        "/Mutx163/mikcb/releases/download/"
    }

private val gitcodeAssetPathPrefix: String
    get() = try {
        "${URI(gitcodeRepositoryUrl).path}/releases/download/"
    } catch (_: Exception) {
        "/mutx/qingyu/releases/download/"
    }

private val mirrorShellPattern = Regex("^/?(https?:/{1,2}[^/].*)$")
private val slashCollapsePattern = Regex("^(https?:)/+")

/**
 * APK 必须是本仓库的 release 资产（Dart `isOfficialApkAssetUrl` 加严版）。
 * 路径前缀命中时必须同时满足主机恰为官方域名（github.com / gitcode.com），
 * 否则 `github.com.evil.com` 配真路径会混入（Dart 原实现与初版移植同有此洞，
 * Dart 自家测试未覆盖；2026-10-26 收紧）。
 * 镜像外壳（path 里嵌整段原始 URL）先剥掉再判定，最多剥 3 层。
 */
fun isOfficialApkAssetUrl(url: String): Boolean {
    if (System.getenv("FLUTTER_TEST") == "true") {
        val host = try {
            URI(url).host?.lowercase()
        } catch (_: Exception) {
            null
        }
        if (host == "localhost" || host == "127.0.0.1" || host == "::1") {
            return true
        }
    }
    var candidate = url
    repeat(3) {
        val uri = try {
            URI(candidate)
        } catch (_: Exception) {
            return false
        }
        val path = uri.path ?: ""
        // 路径前缀命中时再验主机：伪造域名配真路径（如 github.com.evil.com）
        // 不得混入。镜像壳走下面的剥壳循环，剥完 host 自然是官方域名，不受影响。
        val host = uri.host?.lowercase()
        if (path.startsWith(githubAssetPathPrefix) && host == "github.com") {
            return true
        }
        if (path.startsWith(gitcodeAssetPathPrefix) && host == "gitcode.com") {
            return true
        }
        val embedded = mirrorShellPattern.find(path)?.groupValues?.getOrNull(1) ?: return false
        val collapsed = slashCollapsePattern.find(embedded)
        candidate = if (collapsed == null) {
            embedded
        } else {
            collapsed.groupValues[1] + "//" + embedded.substring(collapsed.range.last + 1)
        }
    }
    return false
}

/**
 * 重定向终点是否允许继续下载：先过主机白名单，再限定官方资产路径或
 * GitHub 自有 CDN 域（objects.githubusercontent.com 等签名短链落点）。
 */
fun isRedirectTargetAllowed(targetUrl: String, mirrorUrlPrefix: String? = null): Boolean {
    if (!isTrustedApkDownloadUrl(targetUrl, mirrorUrlPrefix = mirrorUrlPrefix)) {
        return false
    }
    val host = try {
        URI(targetUrl).host?.lowercase()
    } catch (_: Exception) {
        null
    } ?: return false
    if (host == "objects.githubusercontent.com" || host.endsWith(".githubusercontent.com")) {
        return true
    }
    return isOfficialApkAssetUrl(targetUrl)
}

/** 镜像渠道时拼镜像外壳，否则返回原地址（空前缀回退原地址）。 */
fun buildDownloadUrl(
    originalUrl: String,
    source: AppUpdateDownloadSource,
    mirrorUrlPrefix: String,
): String {
    if (source != AppUpdateDownloadSource.MIRROR) {
        return originalUrl
    }
    val normalizedPrefix = mirrorUrlPrefix.trim()
    if (normalizedPrefix.isEmpty()) {
        return originalUrl
    }
    val separator = if (normalizedPrefix.endsWith('/')) "" else "/"
    return "$normalizedPrefix$separator$originalUrl"
}

/** 按下载渠道取应用内下载地址（GitCode 缺失附件时按命名规律兜底构造）。 */
fun getEffectiveDownloadUrl(
    release: AppReleaseInfo?,
    channel: AppUpdateDownloadChannel,
    source: AppUpdateDownloadSource,
    mirrorUrlPrefix: String,
): String? {
    return when (channel) {
        AppUpdateDownloadChannel.GITCODE -> {
            val gitcodeUrl = release?.gitcodeDownloadUrl
            if (!gitcodeUrl.isNullOrEmpty()) {
                return gitcodeUrl
            }
            val version = release?.version?.trim() ?: ""
            if (version.isEmpty()) {
                return null
            }
            constructGitcodeApkDownloadUrl(tag = "v$version", version = version)
        }
        AppUpdateDownloadChannel.PGYER -> release?.pgyerDownloadUrl ?: pgyerDownloadPageUrl
        AppUpdateDownloadChannel.GITHUB -> {
            val originalUrl = release?.downloadUrl ?: return null
            buildDownloadUrl(
                originalUrl = originalUrl,
                source = source,
                mirrorUrlPrefix = mirrorUrlPrefix,
            )
        }
    }
}

/**
 * 系统下载器通道只用官方直连 URL（原生 `UpdateDownloadTrust` 同口径）。
 * 镜像外壳（`https://ghfast.top/https://github.com/…`）在这里一律不产出。
 */
fun getSystemDownloaderUrl(release: AppReleaseInfo?, channel: AppUpdateDownloadChannel): String? {
    return when (channel) {
        AppUpdateDownloadChannel.GITCODE -> {
            val gitcodeUrl = release?.gitcodeDownloadUrl?.trim()
            if (!gitcodeUrl.isNullOrEmpty()) {
                return gitcodeUrl
            }
            val version = release?.version?.trim() ?: ""
            if (version.isEmpty()) {
                return null
            }
            constructGitcodeApkDownloadUrl(tag = "v$version", version = version)
        }
        AppUpdateDownloadChannel.PGYER -> release?.pgyerDownloadUrl ?: pgyerDownloadPageUrl
        AppUpdateDownloadChannel.GITHUB -> {
            val directUrl = release?.downloadUrl?.trim() ?: ""
            if (directUrl.isEmpty()) null else directUrl
        }
    }
}

/** 「查看 Release」统一打开发布页列表：GitHub 渠道给 GitHub，其余给 GitCode。 */
fun releaseListUrlFor(channel: AppUpdateDownloadChannel): String =
    if (channel == AppUpdateDownloadChannel.GITHUB) {
        releasesPageUrl
    } else {
        "$gitcodeRepositoryUrl/releases"
    }

/** `mikcb-{version}-arm64-v8a.apk` 命名规律的 GitHub 直链；tag 非法时返回 null。 */
fun constructApkDownloadUrl(rawTag: String, version: String): String? {
    val tagWithoutPrefix = if (rawTag.startsWith("v") || rawTag.startsWith("V")) {
        rawTag.substring(1)
    } else {
        rawTag
    }
    if (tagWithoutPrefix.isEmpty()) {
        return null
    }
    val fileName = "mikcb-$version-arm64-v8a.apk"
    return "$repositoryUrl/releases/download/${encodeUrlComponent(rawTag)}/$fileName"
}

/** GitCode 发行版附件直链（与 GitHub 同命名规律）。 */
fun constructGitcodeApkDownloadUrl(tag: String, version: String): String? {
    val trimmedTag = tag.trim()
    val withoutPrefix = if (trimmedTag.startsWith("v") || trimmedTag.startsWith("V")) {
        trimmedTag.substring(1)
    } else {
        trimmedTag
    }
    val normalizedVersion = version.trim()
    if (withoutPrefix.isEmpty() || normalizedVersion.isEmpty()) {
        return null
    }
    val fileName = "mikcb-$normalizedVersion-arm64-v8a.apk"
    return "$gitcodeRepositoryUrl/releases/download/${encodeUrlComponent(trimmedTag)}/$fileName"
}

/** 从发行版正文中解析 CI 写入的 `SHA-256: <hex>` 行（大小写不敏感，统一小写）。 */
fun extractSha256FromBody(body: String): String? {
    val match = Regex(
        "sha[\\s-]?256(?:\\s*[:=]\\s*|\\s+)([0-9a-fA-F]{64})",
        setOf(RegexOption.IGNORE_CASE),
    ).find(body) ?: return null
    val value = match.groupValues.getOrNull(1) ?: return null
    if (value.isEmpty()) {
        return null
    }
    return value.lowercase()
}

/** 恒定时间字符串比较（防时序侧信道，Dart `_constantTimeEquals`）。 */
fun constantTimeEquals(a: String, b: String): Boolean {
    if (a.length != b.length) {
        return false
    }
    var diff = 0
    for (i in a.indices) {
        diff = diff or (a[i].code xor b[i].code)
    }
    return diff == 0
}

/** 两个候选状态码里取最后一个非 404（Dart `_pickLastNon404StatusCode` 两两折叠）。 */
fun pickLastNon404StatusCode(a: Int?, b: Int?): Int? {
    if (a != null && a != 404) {
        return a
    }
    if (b != null && b != 404) {
        return b
    }
    return null
}

internal fun encodeUrlComponent(value: String): String =
    URLEncoder.encode(value, "UTF-8").replace("+", "%20").replace("%7E", "~")

internal fun parseInstantMillis(raw: String): Long? {
    return try {
        Instant.parse(raw.trim()).toEpochMilli()
    } catch (_: Exception) {
        null
    }
}

private val releaseSectionPattern = Regex(
    "<section\\b[^>]*>(.*?)</section>",
    setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
)
private val releaseTagPattern = Regex(
    "href=\"/Mutx163/mikcb/releases/tag/([^\"#?]+)\"",
    setOf(RegexOption.IGNORE_CASE),
)
private val releaseTitlePattern = Regex(
    "<a[^>]*href=\"/Mutx163/mikcb/releases/tag/[^\"]+\"[^>]*>(.*?)</a>",
    setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
)
private val releaseBodyPattern = Regex(
    "<div[^>]*data-test-selector=\"body-content\"[^>]*>(.*?)</div>",
    setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
)
private val releaseUpdatedAtPattern = Regex(
    "<relative-time[^>]*datetime=\"([^\"]+)\"",
    setOf(RegexOption.IGNORE_CASE),
)
private val apkDownloadPattern = Regex(
    "href=\"(/Mutx163/mikcb/releases/download/[^\"]+?\\.apk)\"",
    setOf(RegexOption.IGNORE_CASE),
)

fun resolveGitHubUrl(pathOrUrl: String): String =
    if (pathOrUrl.startsWith("http://") || pathOrUrl.startsWith("https://")) {
        pathOrUrl
    } else {
        "https://github.com$pathOrUrl"
    }

fun htmlToPlainText(html: String): String {
    var text = html
    text = Regex("<br\\s*/?>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = Regex("</li>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = Regex("<[^>]+>").replace(text, "")
    text = text.replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
    return text
}

/**
 * Release 页面 HTML 还原成带 Markdown 标记的文本（标题级别/引用/列表）。
 * 旧实现拍平成纯文本会丢标记（2026-10-19 真机复现），三种结构标记补回。
 */
fun htmlBodyToMarkdown(html: String): String {
    var text = html
    text = Regex("<h1[^>]*>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n\n# ")
    text = Regex("<h[2-6][^>]*>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n\n## ")
    text = Regex("</h[1-6]>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = Regex("<blockquote[^>]*>(\\s*<p[^>]*>\\s*)?", setOf(RegexOption.IGNORE_CASE))
        .replace(text, "\n\n> ")
    text = Regex("</blockquote>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = Regex("<li[^>]*>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n- ")
    text = Regex("</p>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = Regex("</li>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = Regex("<br\\s*/?>", setOf(RegexOption.IGNORE_CASE)).replace(text, "\n")
    text = htmlToPlainText(text)
    text = Regex("[ \\t]+\\n").replace(text, "\n")
    text = Regex("\\n{3,}").replace(text, "\n\n")
    return text.trim()
}

fun extractReleaseTitle(block: String): String? {
    val rawTitle = releaseTitlePattern.find(block)?.groupValues?.getOrNull(1)
    if (rawTitle.isNullOrEmpty()) {
        return null
    }
    val title = htmlToPlainText(rawTitle).trim()
    return if (title.isEmpty()) null else title
}

fun extractReleaseBody(block: String): String {
    val rawBody = releaseBodyPattern.find(block)?.groupValues?.getOrNull(1)
    if (rawBody.isNullOrEmpty()) {
        return ""
    }
    return htmlBodyToMarkdown(rawBody).trim()
}

fun extractReleaseUpdatedAtMillis(block: String): Long? {
    val raw = releaseUpdatedAtPattern.find(block)?.groupValues?.getOrNull(1) ?: return null
    return parseInstantMillis(raw)
}

fun extractExpandedAssetsUrl(block: String, tag: String): String {
    val pattern = Regex(
        "src=\"([^\"]+/releases/expanded_assets/[^\"]+)\"",
        setOf(RegexOption.IGNORE_CASE),
    )
    val expanded = pattern.find(block)?.groupValues?.getOrNull(1)
    if (!expanded.isNullOrEmpty()) {
        return expanded
    }
    return "$repositoryUrl/releases/expanded_assets/${encodeUrlComponent(tag)}"
}

fun extractApkAssetPath(html: String): String? =
    apkDownloadPattern.find(html)?.groupValues?.getOrNull(1)

/**
 * 从 Release 页面 HTML 里挑首个可用版本（Dart `_pickLatestEligibleReleaseFromPage`
 * 的纯计算核；页面按新到旧排列，故首个命中即胜出）。
 *
 * 注：Dart 在 tag 命名不合规律时还会请求 expanded_assets 子页面（网络行为），
 * 本层只做纯构造：构造不出直链的段落直接跳过，由调用方决定是否走网络兜底。
 */
fun pickLatestEligibleReleaseFromHtml(html: String, includePrerelease: Boolean): AppReleaseInfo? {
    for (section in releaseSectionPattern.findAll(html)) {
        val block = section.groupValues.getOrNull(1)
        if (block.isNullOrEmpty()) {
            continue
        }
        val rawTag = releaseTagPattern.find(block)?.groupValues?.getOrNull(1)
        if (rawTag.isNullOrEmpty()) {
            continue
        }
        val isPrerelease = block.contains("Pre-release")
        if (!includePrerelease && isPrerelease) {
            continue
        }
        val version = normalizeVersion(rawTag)
        val downloadUrl = constructApkDownloadUrl(rawTag, version) ?: continue
        return AppReleaseInfo(
            version = version,
            title = extractReleaseTitle(block) ?: version,
            body = extractReleaseBody(block),
            releaseUrl = resolveGitHubUrl("/Mutx163/mikcb/releases/tag/$rawTag"),
            downloadUrl = downloadUrl,
            gitcodeDownloadUrl = constructGitcodeApkDownloadUrl(tag = rawTag, version = version),
            updatedAtMillis = extractReleaseUpdatedAtMillis(block),
            isPrerelease = isPrerelease,
        )
    }
    return null
}

/** GitHub API 单条发行版 JSON → 模型（Dart `_releaseFromGitHubJson` 的纯核）。 */
fun releaseFromGitHubJson(
    releaseJson: Map<String, Any?>,
    digestFromDirectChannel: Boolean,
): AppReleaseInfo {
    val latestVersion = normalizeVersion(
        (releaseJson["tag_name"] as? String) ?: (releaseJson["name"] as? String) ?: "",
    )
    val apkDownload = pickApkDownload(
        (releaseJson["assets"] as? List<*>) ?: emptyList<Any?>(),
    )
    val rawTag = (releaseJson["tag_name"] as? String)?.trim() ?: ""
    val body = (releaseJson["body"] as? String)?.trim() ?: ""
    val bodyDigest = if (digestFromDirectChannel) extractSha256FromBody(body) else null
    val rawName = (releaseJson["name"] as? String)?.trim() ?: ""
    return AppReleaseInfo(
        version = latestVersion,
        title = if (rawName.isNotEmpty()) rawName else latestVersion,
        body = body,
        releaseUrl = (releaseJson["html_url"] as? String) ?: repositoryUrl,
        downloadUrl = apkDownload.first,
        gitcodeDownloadUrl = constructGitcodeApkDownloadUrl(
            tag = if (rawTag.isNotEmpty()) rawTag else "v$latestVersion",
            version = latestVersion,
        ),
        updatedAtMillis = parseInstantMillis(
            (releaseJson["updated_at"] as? String)
                ?: (releaseJson["published_at"] as? String) ?: "",
        ),
        isPrerelease = releaseJson["prerelease"] == true,
        expectedApkSha256 = apkDownload.second ?: bodyDigest,
        digestFromDirectChannel = digestFromDirectChannel,
    )
}

/**
 * GitCode API 单条发行版 JSON → 模型（Dart `_fetchFromGitCodeApi` 的纯核，
 * 不含网络与胜出后的跨策略摘要合并）。
 * 附件取首个「.apk + 非 debug + 非 source 类型 + gitcode 主机」；找不到时按
 * 命名规律兜底；仍无可用地址返回 null（调用方记 saw404）。
 */
fun releaseFromGitCodeJson(picked: Map<String, Any?>, includePrerelease: Boolean): AppReleaseInfo? {
    if (!includePrerelease && picked["prerelease"] == true) {
        return null
    }
    val rawTag = (picked["tag_name"] as? String)?.trim() ?: ""
    val version = normalizeVersion(rawTag)
    if (version.isEmpty()) {
        return null
    }
    var gitcodeUrl: String? = null
    val assets = (picked["assets"] as? List<*>) ?: emptyList<Any?>()
    for (rawAsset in assets) {
        if (rawAsset !is Map<*, *>) {
            continue
        }
        val name = (rawAsset["name"] as? String)?.lowercase() ?: ""
        val type = (rawAsset["type"] as? String)?.lowercase() ?: ""
        val url = rawAsset["browser_download_url"] as? String
        val host = try {
            URI(url ?: "").host?.lowercase()
        } catch (_: Exception) {
            null
        } ?: ""
        if (name.endsWith(".apk") && !name.contains("debug") && type != "source" &&
            (host == "gitcode.com" || host.endsWith(".gitcode.com"))
        ) {
            gitcodeUrl = url
            break
        }
    }
    gitcodeUrl = gitcodeUrl ?: constructGitcodeApkDownloadUrl(tag = rawTag, version = version)
    if (gitcodeUrl.isNullOrEmpty()) {
        return null
    }
    val rawName = (picked["name"] as? String)?.trim() ?: ""
    val body = (picked["body"] as? String) ?: ""
    return AppReleaseInfo(
        version = version,
        title = if (rawName.isNotEmpty()) rawName else version,
        body = body,
        releaseUrl = "$gitcodeRepositoryUrl/releases/tag/${encodeUrlComponent(rawTag)}",
        downloadUrl = constructApkDownloadUrl(rawTag, version),
        gitcodeDownloadUrl = gitcodeUrl,
        updatedAtMillis = parseInstantMillis((picked["created_at"] as? String) ?: ""),
        isPrerelease = picked["prerelease"] == true,
        expectedApkSha256 = extractSha256FromBody(body),
        digestFromDirectChannel = true,
    )
}
