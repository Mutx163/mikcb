package com.mutx163.qingyu.pages.import.warehouse

/**
 * 「脚本加载失败」的提示：把**试过哪些源**写进同一句话（2026-11-10 用户报「不知道选了哪个」）。
 *
 * ## 为什么需要它
 *
 * 执行导入时拉适配器脚本失败，原来只弹一句「脚本执行失败」——用户既不知道是不是网络问题，
 * 也不知道当前走的是 GitHub 还是 GitCode，更不知道有没有试镜像：只能猜。
 *
 * ## 数据从哪来
 *
 * - [WarehouseLoad.Failed.attempts]：这次一共试了几条候选（含被跳过的同族镜像之外的失败次数）；
 * - [WarehouseFetchOptions]：宿主手里的偏好快照——`preferGitCode` 决定主地址是 GitCode 还是
 *   GitHub raw，镜像前缀决定候选链里有没有镜像族；
 * - `url`：只有成功结果（`WarehouseLoad.Ok.url`）才有，**失败侧没有**。所以这里说「试过什么」，
 *   不编一个地址出来。
 *
 * ## 「试了几条镜像」怎么算
 *
 * 候选链是 `主地址 →（GitCode 时）GitHub raw 回退 → 镜像族`（见
 * [WarehouseRepositoryUrls.candidatePlan]），所以基线条数取决于渠道：GitCode 2、GitHub 1。
 * `attempts − 基线` 就是真试过的镜像条数，负数截 0（主机不可达时同族镜像会被跳过，
 * 这时说「试了 4 个镜像」就是假话）。
 *
 * @return 可直接上屏的一句话；`attempts == 0`（脚本路径都拼不出来，没有「源」可说）时
 *   退回原来那句「无法读取适配器脚本」。
 */
fun warehouseScriptLoadFailedMessage(
    options: WarehouseFetchOptions,
    attempts: Int,
): String {
    if (attempts <= 0) return WarehouseStrings.warehouseScriptLoadFailed.text

    // 完整基线链（GitCode 渠道的主地址失败后**必带**一条 GitHub raw 回退，GitHub 渠道没有）。
    val baseChain = if (options.preferGitCode) {
        listOf(WarehouseStrings.warehouseSourceGitCode, WarehouseStrings.warehouseSourceGitHubRaw)
    } else {
        listOf(WarehouseStrings.warehouseSourceGitHubRaw)
    }
    val baseTried = baseChain.take(attempts)
    // 偏好里没开镜像（`original` 渠道）就一条镜像候选都没有——宁可少说，不能说试过不存在的源。
    val mirrorsTried = if (options.mirrorUrlPrefix.isNullOrEmpty()) {
        0
    } else {
        (attempts - baseChain.size).coerceAtLeast(0)
    }
    val labels = baseTried.map { it.text }
    val sources = if (mirrorsTried > 0) {
        // 两段占位符都走 String 口径：`ArbText.filled(...)` 的 Int 重载只认第一个占位符，
        // 链式第二段会退回 String（值要自己 toString）。
        WarehouseStrings.warehouseSourceWithMirrors.text
            .filled("source", labels.joinToString(SOURCE_SEPARATOR))
            .filled("mirrorCount", mirrorsTried.toString())
    } else {
        labels.joinToString(SOURCE_SEPARATOR)
    }
    return WarehouseStrings.warehouseScriptLoadFailedWithSources.filled("sources", sources)
}

/**
 * 源名的连接符。用「 + 」而不是顿号：模板本身写的是「{source} + N 个镜像」，
 * 两处必须同一个符号，否则「GitCode 渠道、GitHub 直连 + 3 个镜像」读起来像三种东西。
 */
private const val SOURCE_SEPARATOR = " + "
