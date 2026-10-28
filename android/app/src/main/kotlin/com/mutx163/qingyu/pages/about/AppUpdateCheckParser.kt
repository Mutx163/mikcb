package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.buildCheckResult
import com.mutx163.qingyu.infra.pickLatestEligibleRelease
import com.mutx163.qingyu.infra.releaseFromGitHubJson

/**
 * `AppUpdateService.checkForUpdates`（`lib/services/app_update_service.dart:256-380`）里
 * **不碰网络、不碰文件**的那一段：拿到一份 GitHub releases 响应体后，挑出最高可用版本并构造
 * 检查结果。抽成纯函数是为了能在 JVM 单测里直接跑真实响应样本，而不拉 HttpURLConnection。
 *
 * 网络细节（候选 URL、超时、404 处理、镜像 digest 信任）留在平台适配器里；这里只吃字符串。
 */
sealed interface AppUpdateCheckOutcome {

    /** 解析成功。[result.hasRelease] 决定画「失败卡」还是「状态卡」。 */
    data class Success(val result: AppUpdateCheckResult) : AppUpdateCheckOutcome

    /** 响应体不是合法 JSON 对象数组（拿不到任何版本信息）。 */
    data object Malformed : AppUpdateCheckOutcome
}

/**
 * 解析 GitHub releases 响应体（`[{...}, {...}]`）→ 检查结果。
 *
 * - 挑版本走 [pickLatestEligibleRelease]（跳过 draft / prerelease（可选）/ 无可用 apk / 空版本号）；
 * - 构造模型走 [releaseFromGitHubJson]，`digestFromDirectChannel = true`（GitHub API 是直连渠道，
 *   摘要来自响应本身，与 Dart 在直连策略下取摘要一致）；
 * - 没有可用版本时返回 `hasRelease = false` 的空结果（页面据此画「检查更新失败」）。
 */
fun parseGithubReleasesResponse(
    currentVersion: String,
    jsonText: String?,
    includePrerelease: Boolean,
): AppUpdateCheckOutcome {
    if (jsonText.isNullOrBlank()) return AppUpdateCheckOutcome.Malformed
    val decoded = MiniJson.tryParse(jsonText) ?: return AppUpdateCheckOutcome.Malformed
    if (decoded !is List<*>) return AppUpdateCheckOutcome.Malformed

    val rawList = ArrayList<Any?>(decoded.size)
    for (item in decoded) rawList.add(item)

    val picked = pickLatestEligibleRelease(rawList, includePrerelease)
        ?: return AppUpdateCheckOutcome.Success(
            AppUpdateCheckResult(
                hasRelease = false,
                hasUpdate = false,
                currentVersion = currentVersion,
                latestRelease = null,
                message = null,
            ),
        )

    val release = releaseFromGitHubJson(picked, digestFromDirectChannel = true)
    return AppUpdateCheckOutcome.Success(buildCheckResult(currentVersion, release))
}
