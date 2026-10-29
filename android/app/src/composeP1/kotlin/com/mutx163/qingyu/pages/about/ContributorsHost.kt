package com.mutx163.qingyu.pages.about

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.infra.MaintainerGroup
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.ZoneId

/**
 * 「代码贡献者」页的**宿主装配层**（2026-10-29 F09 新增）：把 [ContributorsPage] 接到
 * 真的仓储读取（[WarehouseMaintainersFeed]）+ 本地缓存。
 *
 * ## 接线前后
 *
 * 接线前壳里写的是 `maintainers = emptyList(), onReload = {}`：恒空态（文案说「还没读取到
 * 适配者」，实际是压根没请求过），点刷新没反应。现在按 Flutter 同一套顺序：
 *
 * 1. **先读缓存**（`warehouse_maintainers_cache_v1`）→ 有就立刻显示，并标注
 *    「更新于 <缓存写入时间>」——这样昨天的名单不会被当成刚刷到的；
 * 2. **再拉真数据**（`index/root_index.yaml` + 每校 `adapters.yaml`）→ 成功则替换并回写缓存；
 * 3. **失败**：保留缓存继续显示 + 显示真原因 + 给「重新加载」；无缓存时只有错误与重试。
 *
 * ## 诚实边界
 *
 * - 适配仓只用 `defaultQingyuWarehouseSource`（GitHub 主仓，GitCode 直连作兜底），
 *   不看设置里的「自定义适配仓」——那是 F08（教务适配族）的写作用域，等它把设置读通了
 *   这里改成从设置取源即可。
 * - 每校一次请求（222 所学校 ≈ 222 次 GET，默认 6 路并发），所以首次进页会「先缓存、后加载」，
 *   不是瞬间完成；无缓存时用户会看到一段转圈，这比假装「没有适配者」诚实。
 * - 只声明「编译通过 / JVM 单测通过」，真机联网路径归用户验收。
 */
@Composable
fun ContributorsHostPage(onBack: () -> Unit) {
    val context = LocalContext.current
    val store = remember(context) { PrefsKeyValueStore(context) }
    val http = remember { JdkAboutHttp() }
    val feed = remember(http) { WarehouseMaintainersFeed(http) }

    var maintainers by remember { mutableStateOf<List<MaintainerGroup>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var cachedAt by remember { mutableStateOf<String?>(null) }
    var reloadToken by remember { mutableStateOf(0) }

    LaunchedEffect(reloadToken) {
        val cached = readMaintainersCache(store)
        val cachedTime = readMaintainersCacheTime(store)
        if (cached.isNotEmpty()) {
            maintainers = cached
            cachedAt = cachedTime?.let { formatMaintainersCacheTime(it, ZoneId.systemDefault()) }
        }
        isLoading = true
        error = null

        when (val outcome = withContext(Dispatchers.IO) { feed.fetch() }) {
            is MaintainersFetchOutcome.Success -> {
                maintainers = outcome.groups
                // 刚拉到的数据：不再标缓存时间。
                cachedAt = null
                error = null
                if (outcome.groups.isNotEmpty()) {
                    withContext(Dispatchers.IO) {
                        writeMaintainersCache(store, outcome.groups, System.currentTimeMillis())
                    }
                }
            }

            is MaintainersFetchOutcome.Failure -> {
                // 缓存继续显示（比空屏有用），但错误与重试必须同时出现。
                error = outcome.reason
            }
        }
        isLoading = false
    }

    ContributorsPage(
        maintainers = maintainers,
        isLoading = isLoading,
        error = error,
        onBack = onBack,
        onReload = { reloadToken += 1 },
        cachedAt = cachedAt,
    )
}
