package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.infra.buildMirrorCandidateUrls
import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix
import java.net.URLEncoder

/**
 * 适配仓的地址构造与候选链（移植 `WarehouseRepositoryService._fetchBytes` 的候选顺序）。
 *
 * ## 为什么把「地址」和「拉取」分成两个文件
 *
 * 候选链是**纯字符串计算**，`L0` 里能直接钉住顺序；真正发请求的那层（[WarehouseJdkFetch]）
 * 要真网络，进不了单测。分成两个文件后，「先试哪个、什么时候回退 GitHub、镜像前缀怎么拼」
 * 全部有单测，只有 socket 那一行没测。
 *
 * ## 候选顺序（与 Dart 一致，顺序本身是安全要求）
 *
 * 1. **主地址**：GitCode 宿主 → `api.gitcode.com` v5 contents API（返回 base64 信封）；
 *    GitHub 宿主 → `raw.githubusercontent.com` 直链；
 * 2. GitCode 主地址失败才回退 GitHub raw（`addUnique`：不重复、不等于主地址）；
 * 3. 开了镜像时，再追加 GitHub raw 的镜像前缀候选（[buildMirrorCandidateUrls]）。
 *
 * 主地址**永远第一个**：镜像若被投毒，也不能靠「先到先得」赢过正主（Dart 的注释原文
 * 「Prefer the primary URL first so a poisoned mirror cannot win a race」）。
 */
object WarehouseRepositoryUrls {

    /** GitHub raw 直链：`https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`。 */
    fun rawGitHubUrl(source: WarehouseRepositorySource, relativePath: String): String {
        val normalized = relativePath.removePrefix("/")
        return "https://raw.githubusercontent.com/${source.owner}/${source.repo}/${source.branch}/$normalized"
    }

    /** GitCode v5 contents API（Gitee 兼容，免令牌可读，回 base64 信封）。 */
    fun gitCodeContentsUrl(source: WarehouseRepositorySource, relativePath: String): String {
        val normalized = relativePath.removePrefix("/")
        val encodedPath = normalized.split("/")
            .filter { it.isNotEmpty() }
            .joinToString("/") { URLEncoder.encode(it, "UTF-8").replace("+", "%20") }
        val ref = URLEncoder.encode(source.branch, "UTF-8")
        return "https://api.gitcode.com/api/v5/repos/" +
            "${source.effectiveOwner}/${source.effectiveRepo}/contents/" +
            "$encodedPath?ref=$ref"
    }

    /** 按宿主返回主拉取地址。 */
    fun primaryUrl(source: WarehouseRepositorySource, relativePath: String): String =
        when (source.host) {
            WarehouseRepositoryHost.GITHUB -> rawGitHubUrl(source, relativePath)
            WarehouseRepositoryHost.GITCODE -> gitCodeContentsUrl(source, relativePath)
        }

    /**
     * 完整候选链，第一个是主地址。
     *
     * [mirrorUrlPrefix] 传 `null` = 不走镜像（Dart `downloadSource != mirror` 的那支），
     * 此时候选只有「主地址（+ GitCode 时的 GitHub raw 回退）」。
     */
    fun candidateUrls(
        source: WarehouseRepositorySource,
        relativePath: String,
        mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
    ): List<String> = candidatePlan(source, relativePath, mirrorUrlPrefix).map { it.url }

    /**
     * 带**族**的候选链（顺序与 [candidateUrls] 完全一致）。
     *
     * 「族」是给快速收敛用的：四个镜像前缀其实是同一类设施（第三方代理），
     * 其中一个连不上时，余下三个通常也一样——把它们逐个各等一个超时，
     * 就是把「白等」乘上 4。拉取层据此在首个镜像传输失败后跳过同族其余候选。
     *
     * 主地址与 GitHub raw 回退**各算一族**、不参与跳过：它们是两台不同的真实服务，
     * 国内网络里「raw 被丢包、镜像反而通」是常态，不能因为主地址失败就不再试镜像。
     */
    fun candidatePlan(
        source: WarehouseRepositorySource,
        relativePath: String,
        mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
    ): List<WarehouseCandidate> {
        val primary = primaryUrl(source, relativePath)
        val githubRaw = rawGitHubUrl(source, relativePath)
        val candidates = mutableListOf(WarehouseCandidate(primary, WarehouseCandidateFamily.PRIMARY))
        fun add(url: String, family: WarehouseCandidateFamily) {
            if (candidates.none { it.url == url }) {
                candidates.add(WarehouseCandidate(url, family))
            }
        }
        if (source.host == WarehouseRepositoryHost.GITCODE) {
            add(githubRaw, WarehouseCandidateFamily.GITHUB_RAW_FALLBACK)
        }
        if (!mirrorUrlPrefix.isNullOrEmpty()) {
            buildMirrorCandidateUrls(githubRaw, mirrorUrlPrefix).forEach { url ->
                add(url, WarehouseCandidateFamily.MIRROR)
            }
        }
        return candidates
    }
}

/** 候选属于哪一族（决定超时额度与「失败后是否跳过同族其余候选」）。 */
enum class WarehouseCandidateFamily {
    /** 主地址：GitCode v5 contents API 或 GitHub raw，取决于宿主。 */
    PRIMARY,

    /** GitCode 主地址失败后的 GitHub raw 回退（真实服务，不参与同族跳过）。 */
    GITHUB_RAW_FALLBACK,

    /** 第三方镜像代理（同族，一个失败就跳过其余）。 */
    MIRROR,
}

/** 一条候选 = 地址 + 它属于哪一族。 */
data class WarehouseCandidate(
    val url: String,
    val family: WarehouseCandidateFamily,
)
