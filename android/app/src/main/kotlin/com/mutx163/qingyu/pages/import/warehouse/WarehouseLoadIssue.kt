package com.mutx163.qingyu.pages.import.warehouse

/**
 * 导入失败与脚本状态的**渲染契约**（2026-11-05 由 Chief 锁定）。
 *
 * 定义放本域（main 层、零 Compose 依赖），页面只消费——两边各写一份是明令禁止的：
 * 「失败原因怎么分类」与「脚本读成什么样」都只有这一处真源。
 *
 * ## 分层
 *
 * | 层 | 拿到的 | 干什么 |
 * |---|---|---|
 * | 拉取层 [WarehouseRepositoryService] | `WarehouseLoad.Failed(code, attempts, transport)` | 只给事实 |
 * | 本文件 | [WarehouseLoadIssue] 四档 + [WarehouseScriptStatus] 四态 | 把事实翻成**给人看的口径** |
 * | 宿主（`WarehouseImportHosts`） | `failure = …` / `scriptStatus = …` | 透传给页面 |
 * | 页面 | 这两个值 | 出文案，**不许自己再按 code 解析一遍** |
 *
 * ## 为什么 code 留着
 *
 * [WarehouseLoadFailed.code] 只进日志与排查（`warehouse_network_unreachable` 这类串对用户毫无意义）；
 * 页面出文案只用 [WarehouseLoadFailed.issue]。两者都留着是因为「用户看什么」与
 * 「事后查什么」本来就该分开。
 */

/**
 * 「这次为什么没成功」——用户能理解的四档。
 *
 * 四档而不是直接暴露 `WarehouseFeedCodes` 的七八个串：用户只需要知道
 * 「网不通 / 太慢 / 仓库那边全挂了 / 拉回来的内容不对」这四种处置方式完全不同的情况。
 */
enum class WarehouseLoadIssue {
    /** 网整体不通：挂 VPN/代理断网、飞行模式、DNS 全灭。处置 = 检查网络/代理，别换镜像。 */
    NETWORK_UNREACHABLE,

    /** 一路都是慢失败（超时）：网是通的，但每台都拖到额度用完。处置 = 换个网络或稍后再试。 */
    TIMEOUT,

    /** 仓库/镜像那边全挂了（拿到 4xx/5xx，或失败原因分不清）。处置 = 稍后再试、或换下载渠道。 */
    MIRRORS_FAILED,

    /** 拉回来了但内容不能用：索引解析不出学校/适配器，或脚本为空 / 校验不符。处置 = 反馈适配仓问题。 */
    INVALID_FORMAT,
}

/**
 * 一次失败要交给页面的全部信息。
 *
 * @param code [WarehouseFeedCodes] 的原串，**只进日志**，页面不出文案。
 * @param attempts 试过几个候选（成功的那次是 1..n；脚本路径拼不出来这种 0 候选的情形是 0）。
 * @param issue 四档分类；理论上恒非 null——宿主用 [warehouseLoadIssueOf] 填。
 */
data class WarehouseLoadFailed(
    val code: String,
    val attempts: Int,
    val issue: WarehouseLoadIssue?,
)

/**
 * 详情页「脚本状态卡」的四态。
 *
 * 详情页要在**不注入脚本**的前提下告诉用户「这个适配器的脚本到底能不能用」，
 * 所以由宿主在 IO 里拉一次脚本正文，把结果降维成这四态。
 */
sealed interface WarehouseScriptStatus {
    /** 还在拉（首帧就是这个）：页面给进度指示，不要写「不可用」。 */
    data object Loading : WarehouseScriptStatus

    /** 拉到了且有内容。[length] 是字符数，给用户一个「看起来正常」的凭据。 */
    data class Loaded(val length: Int) : WarehouseScriptStatus

    /** 拉到了但全是空白：注入进去只会白等，等同于坏脚本。 */
    data object Empty : WarehouseScriptStatus

    /** 没拉到。[issue] 让页面出同一套人话，不必再按 [code] 解析一遍。 */
    data class Failed(
        val code: String,
        val issue: WarehouseLoadIssue? = null,
    ) : WarehouseScriptStatus
}

/**
 * 失败码 + 传输层类别 → 四档。
 *
 * 判据只看两样：`code`（内容类错误直接可定档）与 `transport`（[WarehouseLoad.Failed.transport]，
 * 由 `WarehouseJdkFetch` 顺着 cause 链认出来的失败类别）。
 *
 * | 情形 | 档 |
 * |---|---|
 * | `warehouse_network_unreachable` | [WarehouseLoadIssue.NETWORK_UNREACHABLE] |
 * | 索引/脚本内容不合法（`no_schools_index` / `no_adapters` / `script_*`） | [WarehouseLoadIssue.INVALID_FORMAT] |
 * | 候选全失败且最后一次是超时 | [WarehouseLoadIssue.TIMEOUT] |
 * | 其余（4xx/5xx、失败原因分不清、DNS 之外的杂错） | [WarehouseLoadIssue.MIRRORS_FAILED] |
 *
 * **恒有值**：这个函数没有「不知道」这一档可用（页面拿到 null 就只能退回通用标题）。
 */
fun warehouseLoadIssueOf(failed: WarehouseLoad.Failed): WarehouseLoadIssue = when {
    failed.code == WarehouseFeedCodes.NETWORK_UNREACHABLE -> WarehouseLoadIssue.NETWORK_UNREACHABLE

    failed.code == WarehouseFeedCodes.NO_SCHOOLS ||
        failed.code == WarehouseFeedCodes.NO_ADAPTERS ||
        failed.code == WarehouseFeedCodes.SCRIPT_EMPTY ||
        failed.code == WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED ||
        failed.code == WarehouseFeedCodes.SCRIPT_PATH_MISSING -> WarehouseLoadIssue.INVALID_FORMAT

    failed.code == WarehouseFeedCodes.FETCH_FAILED_MIRROR ||
        failed.code == WarehouseFeedCodes.FETCH_FAILED_GITHUB ->
        if (failed.transport == WarehouseTransportFailure.TIMEOUT) {
            WarehouseLoadIssue.TIMEOUT
        } else {
            WarehouseLoadIssue.MIRRORS_FAILED
        }

    else -> WarehouseLoadIssue.MIRRORS_FAILED
}

/** [WarehouseLoad.Failed] → 页面要的形状（`issue` 已按 [warehouseLoadIssueOf] 填好）。 */
fun WarehouseLoad.Failed.toLoadFailed(): WarehouseLoadFailed = WarehouseLoadFailed(
    code = code,
    attempts = attempts,
    issue = warehouseLoadIssueOf(this),
)

/**
 * 脚本正文的拉取结果 → 详情页要的四态。
 *
 * 全空白算 [WarehouseScriptStatus.Empty]：`loadAdapterScript` 已经把空正文当
 * [WarehouseFeedCodes.SCRIPT_EMPTY] 抛掉了，这里再判一次是为了防「服务层以后放宽了判据」——
 * 页面能看见的永远是「有内容」或「空」，不会出现 `Loaded(0)` 这种自相矛盾的状态。
 */
fun warehouseScriptStatusOf(load: WarehouseLoad<String>): WarehouseScriptStatus = when (load) {
    is WarehouseLoad.Ok ->
        if (load.value.isBlank()) {
            WarehouseScriptStatus.Empty
        } else {
            WarehouseScriptStatus.Loaded(load.value.length)
        }

    is WarehouseLoad.Failed -> WarehouseScriptStatus.Failed(
        code = load.code,
        issue = warehouseLoadIssueOf(load),
    )
}

/**
 * 四档原因 → **屏上一句人话**（`null` = 这一档没有可说的话，调用方不要画任何东西）。
 *
 * 放 main 层而不是页面里的原因：文案要能被 L0 单测逐字钉住，页面只负责摆位置；
 * 页面也不许自己按 [WarehouseLoadFailed.code] 再解析一遍（那是两处各解析一次）。
 *
 * 四档各有一句 ARB 原文（2026-11-05 ARB 窗口落地）：
 * - [WarehouseStrings.warehouseLoadIssueNetworkUnreachable] 网不通：查网络/代理，别换镜像；
 * - [WarehouseStrings.warehouseLoadIssueTimeout] 一路慢失败：换网络或稍后再试；
 * - [WarehouseStrings.warehouseLoadIssueInvalidFormat] 内容不能用：反馈适配仓；
 * - `MIRRORS_FAILED` 复用 [WarehouseStrings.serviceMsgWarehouseFetchFailedMirror]，
 *   `{candidatesCount}` 用 [WarehouseLoadFailed.attempts] 填。
 *
 * ## 为什么有个 [showingCachedList]
 *
 * 名单还在（命中缓存、只是这次刷新失败）时，把「已尝试 N 条线路…」这种细节压给用户没意义，
 * 他手上能用；这时只说 [WarehouseStrings.warehouseLoadIssueShowingCached]（「网络不太顺畅，
 * 下面是上次的列表」）。**但内容格式错要例外**：那不是网络的事，说「网络不太顺畅」就是假话，
 * 所以 `INVALID_FORMAT` 无论有没有缓存都用格式那句。
 */
fun warehouseLoadIssueText(
    failed: WarehouseLoadFailed,
    showingCachedList: Boolean = false,
): String? {
    if (showingCachedList && failed.issue != WarehouseLoadIssue.INVALID_FORMAT) {
        return WarehouseStrings.warehouseLoadIssueShowingCached.text
    }
    return when (failed.issue) {
        // 「已尝试 0 条线路」是句病句——真出现 0 候选（脚本地址拼不出来）就不显示这句。
        WarehouseLoadIssue.MIRRORS_FAILED ->
            if (failed.attempts > 0) {
                WarehouseStrings.serviceMsgWarehouseFetchFailedMirror
                    .filled("candidatesCount", failed.attempts.toString())
            } else {
                null
            }

        WarehouseLoadIssue.NETWORK_UNREACHABLE -> WarehouseStrings.warehouseLoadIssueNetworkUnreachable.text
        WarehouseLoadIssue.TIMEOUT -> WarehouseStrings.warehouseLoadIssueTimeout.text
        WarehouseLoadIssue.INVALID_FORMAT -> WarehouseStrings.warehouseLoadIssueInvalidFormat.text
        null -> null
    }
}
