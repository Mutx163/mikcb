package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix

/**
 * 适配仓拉取的**用户偏好快照**（对齐 Dart `WarehouseFetchOptions`：
 * `lib/services/warehouse_repository_service.dart:14-45`）。
 *
 * ## 为什么要有这一层
 *
 * 发布版里「教务适配仓走哪个源」不是常量，而是跟着「更新下载渠道」走：
 * `preferGitCodeSync`（`timetable_settings_extensions.dart:446-450`）= 渠道是
 * **GitCode 或蒲公英**时为真（两者都是国内可直连），于是主地址用 GitCode；
 * GitHub 渠道则保持 GitHub raw 直连。镜像前缀同理——只有在「下载来源 = 镜像」时
 * 才拼（`original` 渠道不该把请求丢给第三方代理）。
 *
 * Kotlin 侧原来把这件事写死成「GitHub raw 主地址 + 恒用默认镜像前缀」，
 * 于是设置里切到 GitCode 对适配仓**一点作用都没有**。本类就是把那条偏好搬进来。
 *
 * ## 为什么是纯数据 + 纯函数（不放设置模型）
 *
 * `pages/import/warehouse` 要在 L0 模块单测里独立编译（`scripts/test-kotlin-module.ps1`），
 * 不能 import `pages/about` 的 `AppUpdateSettings`——那会把整个 about 域拖进本模块的
 * 编译单元。所以这里是**只含布尔与字符串**的快照，映射由宿主层
 * （`readWarehouseFetchOptions`）做。
 *
 * @param preferGitCode 主地址是否优先走 GitCode（国内渠道）。默认 `false` = 保持
 *   改动前的 GitHub raw 主地址，任何没接偏好的调用点行为不变。
 * @param mirrorUrlPrefix 镜像前缀；`null`/空串 = 不走镜像（候选只有主地址，
 *   GitCode 时再加一条 GitHub raw 回退）。
 */
data class WarehouseFetchOptions(
    val preferGitCode: Boolean = false,
    val mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
) {

    /**
     * 按偏好挑主宿主：`preferGitCode` 时把宿主换成 GitCode，否则原样返回。
     *
     * 只换 `host`——属主/仓库名仍取 [WarehouseRepositorySource] 自带的那份
     * （`gitcodeOwner` 缺省回落 `owner`），与 Dart `source.withHost(gitcode)` 逐字同口径。
     */
    fun source(base: WarehouseRepositorySource): WarehouseRepositorySource =
        if (preferGitCode) base.withHost(WarehouseRepositoryHost.GITCODE) else base
}
