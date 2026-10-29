package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.infra.InfraJson

/**
 * 「支持作者」页鸣谢名单的取数层（2026-10-29 F09 新增）。
 *
 * 移植 `lib/services/support_creator_service.dart` 的 `fetchDonors` **主路径**：
 * 官方直连（GitHub raw）为主、GitCode 国内直连为备，拿到 JSON 后交给
 * [parseSupportDonorData]（纯解析，早就在 `SupportCreatorModel.kt` 里）。
 *
 * ## 有意没移植的部分（别当成漏了）
 *
 * - **镜像竞速池**：Dart 会把 4 个镜像前缀与官方地址一起 `raceFutures`。榜单是
 *   「展示型 JSON」，镜像能整份替换它（名单是谁、写了什么），而 Dart 那条路最后
 *   也只剩 `isOfficialDirectUrl` 的候选——竞速池对本页的净收益是 0，风险却是
 *   「镜像喂什么就显示什么」。所以这里只留两条**可信直连**：官方 raw 与 GitCode 官方 API。
 * - **下载渠道联动**（`preferGitCode`）：Dart 按「下载渠道选国内源」把 GitCode 提到前面。
 *   本版固定「官方直连优先，失败再试 GitCode」，顺序差异只影响弱网下的首个来源，
 *   不影响数据正确性；等设置桥接批（F05/F06）把渠道读进来再补也不迟。
 *
 * ## 失败纪律
 *
 * 拿不到就回 [DonorsFetchOutcome.Failure] 并带上**真原因**（`http_404` / `network_unreachable`
 * / `donors_payload_not_map` …），绝不回空名单冒充「名单就是空的」——空名单代表
 * 「作者确实还没填」，两者在用户眼里是相反的结论。
 */
sealed interface DonorsFetchOutcome {
    data class Success(val data: SupportDonorData) : DonorsFetchOutcome

    /**
     * 服务器回 304：**数据没变，沿用上一次成功的那份**。
     * 当前实现不发 `If-None-Match`，所以这条分支是防御性的（服务器/CDN 层可能自作主张）；
     * 调用方不许把 304 当成「拿到空名单」，也不许当成失败。
     */
    object NotModified : DonorsFetchOutcome

    data class Failure(val reason: String) : DonorsFetchOutcome
}

/** 鸣谢名单取数（构造不做 IO，[fetch] 才会真的发请求）。 */
class SupportDonorsFeed(private val http: AboutHttp) {

    /**
     * 依次尝试 [candidateUrls]，第一个 200 即返回。
     *
     * 全部候选都失败时：见过 304 就回 [DonorsFetchOutcome.NotModified]，
     * 否则回 [DonorsFetchOutcome.Failure]，原因取**最后一个**候选的（那是最终卡住用户的那条）。
     */
    fun fetch(): DonorsFetchOutcome {
        var sawNotModified = false
        var lastReason = "network_unreachable"
        for (url in candidateUrls) {
            when (val outcome = attempt(url)) {
                is DonorsFetchOutcome.Success -> return outcome
                DonorsFetchOutcome.NotModified -> sawNotModified = true
                is DonorsFetchOutcome.Failure -> lastReason = outcome.reason
            }
        }
        return if (sawNotModified) DonorsFetchOutcome.NotModified else DonorsFetchOutcome.Failure(lastReason)
    }

    /** 拉单个候选并解析（不做跨候选回退，由 [fetch] 决定顺序）。 */
    fun attempt(url: String): DonorsFetchOutcome {
        val response = runCatching { http.get(url) }.getOrNull()
            ?: return DonorsFetchOutcome.Failure("network_unreachable")
        if (response.statusCode == 304) {
            return DonorsFetchOutcome.NotModified
        }
        if (response.statusCode != 200) {
            return DonorsFetchOutcome.Failure("http_${response.statusCode}")
        }
        val text = if (isGitCodeContentsUrl(url)) {
            decodeGitCodeContentsBody(response.body)
                ?: return DonorsFetchOutcome.Failure("gitcode_contents_decode_failed")
        } else {
            response.body
        }
        val decoded = InfraJson.tryParse(text)
            ?: return DonorsFetchOutcome.Failure("donors_payload_not_json")
        @Suppress("UNCHECKED_CAST")
        val map = decoded as? Map<String, Any?>
            ?: return DonorsFetchOutcome.Failure("donors_payload_not_map")
        return DonorsFetchOutcome.Success(parseSupportDonorData(map))
    }

    companion object {
        /** 官方直连（`mutx163/mikcb` 仓库的 `docs/donors.json`，维护者发版后即生效）。 */
        const val DONORS_URL = "https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/donors.json"

        /** GitCode 国内直连（v5 contents API，免令牌可读，回 base64 信封）。 */
        const val GITCODE_DONORS_URL =
            "https://api.gitcode.com/api/v5/repos/mutx/qingyu/contents/docs/donors.json?ref=main"

        /** 候选顺序：官方直连优先，失败才回退国内直连。 */
        val candidateUrls: List<String> = listOf(DONORS_URL, GITCODE_DONORS_URL)
    }
}
