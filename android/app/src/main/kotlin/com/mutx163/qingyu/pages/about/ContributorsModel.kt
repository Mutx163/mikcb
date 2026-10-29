package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.infra.MaintainerGroup

/**
 * 代码贡献者页的纯模型（移植 `lib/screens/about_screen.dart` 的 `ContributorsScreen`，
 * 2026-10-28 新建）。
 *
 * ## 页面在 Flutter 侧长什么样
 *
 * 三张卡：开发人员（Mutx163）/ 教务导入适配者（从 `qingyu_warehouse` 汇总 maintainer，
 * 缓存优先 + 后台刷新）/ 参与适配（打开适配仓、复制地址）。
 *
 * ## 分层
 *
 * 与 about 族其它模型一致：本文件在 main 源集、零 Compose/Miuix 依赖（main 对全变体编译）。
 * maintainer 分组结构复用 `infra/WarehouseInfra.kt` 的 [MaintainerGroup]（已带缓存编解码），
 * 这里只补「文案 + 排序」这些可单测的纯逻辑。
 */

/** 代码贡献者页文案（逐字取自 `lib/l10n/app_zh.arb`，键名写在注释里）。 */
object ContributorsStrings {
    /** aboutContributorsTitle */
    const val screenTitle = "代码贡献者"

    /** aboutDevelopersTitle */
    const val developersTitle = "开发人员"

    /** 开发者主账号（Dart `_ContributorRow(name: 'Mutx163', …)`，非 ARB）。 */
    const val developerName = "Mutx163"

    /** aboutDeveloperMaintainerSubtitle */
    const val developerSubtitle = "轻屿课表开发与维护"

    /** aboutWarehouseMaintainersTitle */
    const val maintainersTitle = "教务导入适配者"

    /** aboutWarehouseMaintainersIntro */
    const val maintainersIntro =
        "以下名单来自 qingyu_warehouse 适配仓的 maintainer 字段汇总，若本地已有缓存，会先显示缓存，再后台刷新"

    /** aboutWarehouseMaintainersEmpty */
    const val maintainersEmpty = "当前还没有读取到适配者信息"

    /** aboutParticipateWarehouseTitle */
    const val participateTitle = "参与教务适配"

    /** aboutParticipateWarehouseSubtitle */
    const val participateSubtitle =
        "如果你会抓包、网页调试、JavaScript，或者愿意长期维护自己学校的教务系统，欢迎去 qingyu_warehouse 提交新的学校适配与修复"

    /** aboutOpenWarehouseRepoAction */
    const val openWarehouseRepoAction = "打开教务适配仓"

    /** copyAddress */
    const val copyAddress = "复制地址"

    /** copiedWarehouseRepositoryAddress */
    const val copiedAddress = "已复制教务适配仓地址"

    /** ARB `aboutWarehouseMaintainerCount`（`{count} 个适配项`）。 */
    fun maintainerCount(count: Int): String = "$count 个适配项"

    /**
     * 名单缓存时间标注（ARB `updatedAtLabel`：`更新于 {time}`）。
     *
     * 复用支持作者页那条同义 ARB 键，不新造文案：本页要表达的正是「这份名单是那个时刻拉到的」，
     * 与鸣谢名单的「更新于 X」语义完全一致；新造一条只会在六份 ARB 里多一个同义键。
     * 逐字对拍由 `AboutFeedTest` 钉住。
     */
    fun cachedAtLabel(time: String): String = "更新于 $time"

    /** ARB `aboutWarehouseMaintainersLoadFailed`（`暂时无法读取适配者名单：{error}`）。 */
    fun loadFailed(error: String): String = "暂时无法读取适配者名单：$error"

    /** ARB `reloadAction`（`重新加载`）：失败后重试入口，与支持作者页共用同一条键。 */
    const val reloadAction = "重新加载"

    /** 教务适配仓地址（Dart `defaultQingyuWarehouseSource.repositoryUrl`）。 */
    const val warehouseRepoUrl = "https://github.com/Mutx163/qingyu_warehouse"
}

/**
 * 适配者分组按名字排序（Dart `..sort((l, r) => l.name.compareTo(r.name))`）。
 *
 * 保留成显式函数而非直接 `sortedBy`：排序口径是「显示顺序」的一部分，值得被测试钉住。
 */
fun sortedContributorGroups(groups: List<MaintainerGroup>): List<MaintainerGroup> =
    groups.sortedBy { it.name }
