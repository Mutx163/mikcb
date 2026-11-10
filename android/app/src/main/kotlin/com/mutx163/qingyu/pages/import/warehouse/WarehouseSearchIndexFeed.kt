package com.mutx163.qingyu.pages.import.warehouse

/**
 * 适配器（脚本）名搜索索引 `index/search_index.yaml` 的**尽力拉取**。
 *
 * ## 为什么单独一层、且失败回 `null`
 *
 * 发布版在选校页 `initState` 里单独拉这份索引（`_fetchSearchIndex`），失败只把索引留成
 * `null`——搜索退化成「只按学校名/ID/首字母/代码」，页面照常可用。本仓照此办理：
 * 拉取/解析任何一步失败都回 `null`，**绝不让它拖垮学校清单**（清单有自己的缓存与失败页）。
 *
 * ## 为什么不复用 [WarehouseRepositoryService] 的 `load`
 *
 * 那个 `load` 是私有的（G2 的根索引/适配器清单/脚本三条专用链）。这里只借它公开的
 * [WarehouseRepositoryService.candidateUrlsFor] 拿同一条候选链（GitCode 主地址 →
 * GitHub raw 回退 → 镜像），再自己走「第一个 HTTP 200 且能解析的候选」。
 * 搜索索引只有几 KB，**不参与**根索引那套整链预算；每候选 8s、整链最多
 * [SEARCH_INDEX_TOTAL_BUDGET_MILLIS]，失败就静默降级。
 *
 * 线程约定：同步 IO，调用方放 `Dispatchers.IO`。
 */
fun loadWarehouseSearchIndex(
    fetch: WarehouseFetch,
    options: WarehouseFetchOptions? = null,
    source: WarehouseRepositorySource = WarehouseRepositorySource.DEFAULT,
    timeoutMillis: Int = SEARCH_INDEX_TIMEOUT_MILLIS,
): WarehouseSearchIndex? {
    val service = WarehouseRepositoryService(fetch, source = source, options = options)
    val deadline = System.currentTimeMillis() + SEARCH_INDEX_TOTAL_BUDGET_MILLIS

    for (url in service.candidateUrlsFor(SEARCH_INDEX_RELATIVE_PATH)) {
        if (System.currentTimeMillis() >= deadline) {
            break
        }
        val response = fetch.get(url, timeoutMillis) ?: continue
        if (response.statusCode != 200) {
            continue
        }
        // GitCode 主地址回的是 base64 信封；解不出来就换下一个候选（与根索引同口径）。
        val body = if (isGitCodeContentsUrl(url)) {
            decodeGitCodeContentsBody(response.body) ?: continue
        } else {
            response.body
        }
        if (body.isBlank()) {
            continue
        }
        // 宽松解析器理论上不抛；仍然 runCatching 兜一层，坏文件只等于「这份索引没有」。
        val parsed = runCatching { parseWarehouseSearchIndex(body) }.getOrNull() ?: continue
        return parsed
    }
    return null
}

/** 搜索索引在适配仓里的固定相对路径（发布版 `fetchSearchIndex` 同一条）。 */
private const val SEARCH_INDEX_RELATIVE_PATH = "index/search_index.yaml"

/** 单候选额度：几 KB 的小文件，8s 不回基本就是这条链路半死。 */
private const val SEARCH_INDEX_TIMEOUT_MILLIS = 8_000

/** 整条链预算：最多让背景协程活这么久，超了就当这次没拿到（搜索退化，页面不受影响）。 */
private const val SEARCH_INDEX_TOTAL_BUDGET_MILLIS = 20_000L
