package com.mutx163.qingyu.pages.about

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * 「支持作者」页的**宿主装配层**（2026-10-29 F09 新增）：把 [SupportCreatorPage] 接到
 * 真的网络拉取（[SupportDonorsFeed]）上。
 *
 * ## 接线前后
 *
 * 接线前壳里写的是 `donorData = null, onReload = {}`：名单恒空（空态文案说「作者还没填」，
 * 而实际是压根没请求过），点刷新没反应。现在：
 *
 * - **数据**：`docs/donors.json`（官方 raw 主 / GitCode 直连备）→ [SupportDonorData]；
 * - **动作**：刷新 = 真再发一次请求（[reloadToken] 自增触发 `LaunchedEffect`），不是空 lambda；
 * - **回显**：成功后名单与「更新于 X」同屏；失败后显示真原因 + 可点重试。
 *
 * ## 诚实边界
 *
 * - 本页**不做缓存**（与 Flutter 一致）：每次进页都重新拉。所以不存在「把上次缓存当新数据」，
 *   代价是断网时名单不可见——此时显示的是错误 + 重试，不冒充「名单是空的」。
 * - 镜像竞速池没移植（理由见 [SupportDonorsFeed] 的注释）；下载渠道联动（`preferGitCode`）
 *   等 F05/F06 把设置读出来再补。
 * - 只声明「编译通过 / JVM 单测通过」，真机联网路径归用户验收。
 */
@Composable
fun SupportCreatorHostPage(onBack: () -> Unit) {
    val http = remember { JdkAboutHttp() }
    val feed = remember(http) { SupportDonorsFeed(http) }

    var donorData by remember { mutableStateOf<SupportDonorData?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var reloadToken by remember { mutableStateOf(0) }

    LaunchedEffect(reloadToken) {
        isLoading = true
        loadError = null
        when (val outcome = withContext(Dispatchers.IO) { feed.fetch() }) {
            is DonorsFetchOutcome.Success -> donorData = outcome.data
            // 304 = 服务器说「没变」：保留上一次成功的数据，不当成失败也不当成空名单。
            DonorsFetchOutcome.NotModified -> Unit
            is DonorsFetchOutcome.Failure -> loadError = outcome.reason
        }
        isLoading = false
    }

    SupportCreatorPage(
        donorData = donorData,
        onBack = onBack,
        onReload = { reloadToken += 1 },
        isLoading = isLoading,
        loadError = loadError,
    )
}
