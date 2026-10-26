package com.mutx163.qingyu.pages.about

/**
 * 关于页「静态信息区」的纯结构模型（移植 `lib/screens/about_screen.dart:296-450`，
 * 2026-10-26 快照）。
 *
 * ## 本批只覆盖静态区，不是整页
 *
 * 关于页共 2727 行，其中静态信息区只有约 141 行（三段列表 + 两个说明弹层），
 * 余下约 2298 行是「检查更新 / 下载渠道 / 镜像探测 / 更新日志渲染」这条动态链路。
 * 本文件只落**静态区**；动态区是独立的一批，见 `docs/plans/2026-10-26-compose-phase3-prep.md`。
 *
 * ## 分层
 *
 * 与同目录另外两页一致：main 源集、零 Compose/Miuix 依赖（main 对全变体编译，
 * import miuix 会让 Flutter 的 prod 包编不过），渲染在 composeP1 源集。
 */

/** 静态区每一行的去向（决定点击后跳哪页/弹哪层，以及图标与配色档）。 */
enum class AboutEntryKind {
    /** 请喝咖啡 → 支持作者页。 */
    COFFEE,

    /** 问题反馈。 */
    FEEDBACK,

    /** 版本更新 → 动态区（本批不含）。 */
    UPDATES,

    /** 更新日志页。 */
    CHANGELOG,

    /** 应用日志页。 */
    APP_LOGS,

    /** 项目定位：点击弹说明层（带 [AboutInfoEntry.bullets]）。 */
    POSITIONING,

    /** 导入与迁移：点击弹说明层（带 [AboutInfoEntry.bullets]）。 */
    IMPORT_MIGRATION,

    /** 代码贡献者页。 */
    CONTRIBUTORS,

    /** 开源仓库。 */
    REPOSITORY,

    /** 开源许可页。 */
    OPEN_SOURCE_LICENSES,
}

/**
 * 一行：标题 + 副标题（+ 可选说明弹层的条目）。
 *
 * [bullets] 非空即代表「点开是说明层而不是跳页」——Dart 侧 `_showInfoSheet` 的调用点
 * 只有项目定位与导入迁移两处，这条区分让渲染层不必再写一遍判断。
 */
data class AboutInfoEntry(
    val kind: AboutEntryKind,
    val title: String,
    val subtitle: String,
    val bullets: List<String> = emptyList(),
)

/** 一个分组：小节标题 + 若干行。 */
data class AboutInfoSection(
    val label: String,
    val entries: List<AboutInfoEntry>,
)

/**
 * 静态区三个分组，**顺序与 Dart 源码逐行一致**（`about_screen.dart:297 / 369 / 414`）。
 *
 * 顺序是可见结果的一部分：分组顺序或行内顺序漂移，用户一眼就能看出与老版本不一致。
 */
fun aboutInfoSections(): List<AboutInfoSection> = listOf(
    AboutInfoSection(
        label = AboutInfoStrings.supportUpdatesSectionTitle,
        entries = listOf(
            AboutInfoEntry(
                kind = AboutEntryKind.COFFEE,
                title = AboutInfoStrings.coffeeTitle,
                subtitle = AboutInfoStrings.coffeeSubtitle,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.FEEDBACK,
                title = AboutInfoStrings.feedbackTitle,
                subtitle = AboutInfoStrings.feedbackSubtitle,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.UPDATES,
                title = AboutInfoStrings.updatesTitle,
                subtitle = AboutInfoStrings.updatesSubtitle,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.CHANGELOG,
                title = AboutInfoStrings.changelogTitle,
                subtitle = AboutInfoStrings.changelogSubtitle,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.APP_LOGS,
                title = AboutInfoStrings.appLogsTitle,
                subtitle = AboutInfoStrings.appLogsSubtitle,
            ),
        ),
    ),
    AboutInfoSection(
        label = AboutInfoStrings.productSectionTitle,
        entries = listOf(
            AboutInfoEntry(
                kind = AboutEntryKind.POSITIONING,
                title = AboutInfoStrings.positioningTitle,
                subtitle = AboutInfoStrings.positioningSubtitle,
                bullets = AboutInfoStrings.positioningBullets,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.IMPORT_MIGRATION,
                title = AboutInfoStrings.importMigrationTitle,
                subtitle = AboutInfoStrings.importMigrationSubtitle,
                bullets = AboutInfoStrings.importMigrationBullets,
            ),
        ),
    ),
    AboutInfoSection(
        label = AboutInfoStrings.communitySectionTitle,
        entries = listOf(
            AboutInfoEntry(
                kind = AboutEntryKind.CONTRIBUTORS,
                title = AboutInfoStrings.contributorsTitle,
                subtitle = AboutInfoStrings.contributorsSubtitle,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.REPOSITORY,
                title = AboutInfoStrings.repositoryTitle,
                subtitle = AboutInfoStrings.repositorySubtitle,
            ),
            AboutInfoEntry(
                kind = AboutEntryKind.OPEN_SOURCE_LICENSES,
                // 与开源许可页同源，避免同一句话在两处各写一遍（改一处漏一处）。
                title = OpenSourceLicensesStrings.title,
                subtitle = OpenSourceLicensesStrings.subtitle,
            ),
        ),
    ),
)

/**
 * 静态区文案（逐字取自 `lib/l10n/app_zh.arb`）。
 *
 * 测试直读 ARB 逐字对拍（不手抄信任），与许可页/支持作者页同一纪律。
 */
object AboutInfoStrings {
    const val supportUpdatesSectionTitle = "支持与更新"
    const val coffeeTitle = "请喝咖啡"
    /** Dart 把支持作者页的标题直接当副标题用（`about_screen.dart:304`）。 */
    const val coffeeSubtitle = "支持轻屿课表继续更新"
    const val feedbackTitle = "问题反馈"
    const val feedbackSubtitle = "Issue、社区渠道和建议反馈入口"
    const val updatesTitle = "版本更新"
    const val updatesSubtitle = "检查更新与立即下载"
    const val changelogTitle = "更新日志"
    const val changelogSubtitle = "查看所有版本的更新内容"
    const val appLogsTitle = "应用日志"
    const val appLogsSubtitle = "查看运行日志"

    const val productSectionTitle = "产品"
    const val positioningTitle = "项目定位"
    const val positioningSubtitle = "这是什么、适合谁、核心能力是什么"
    val positioningBullets = listOf(
        "支持周视图课表、课程增删改、.ics 导入",
        "已支持适配学校的教务系统网页登录导入与完整备份迁移",
        "支持实时通知；HyperOS 3.0.300 起支持超级岛 / 焦点通知展示",
        "支持多课表、时间模板、主题色和卡片样式自定义",
    )
    const val importMigrationTitle = "导入与迁移"
    const val importMigrationSubtitle = "当前导入方式、备份恢复和迁移建议"
    val importMigrationBullets = listOf(
        "支持教务系统网页登录导入。进入 导入课程 > 教务系统导入 选择学校即可。",
        "如果你的学校暂时还没适配，仍然可以先在其他课表应用里导入课程，再导出为日历格式，然后在本应用导入",
        "若已有他人使用，可导出完整备份文件，在 数据备份与迁移 中导入恢复。",
        "如果你会抓包、网页调试或 JavaScript，也欢迎去 qingyu_warehouse 参与教务适配补充",
    )

    const val communitySectionTitle = "社区"
    const val contributorsTitle = "代码贡献者"
    const val contributorsSubtitle = "开发人员与教务导入适配者名单"
    const val repositoryTitle = "开源仓库"
    const val repositorySubtitle = "GitHub 源码、Release 和反馈入口"

    /**
     * 第三方免责声明：位于静态区之前的头部卡片里（`about_screen.dart:288`）。
     * 那张头图卡不在本批切片内，这里先把文案钉住，供后续批次接线时直接用。
     */
    const val thirdPartyDisclaimer =
        "特此声明：本应用由第三方开发者独立开发，仅用于学习研究用途，不属于小米官方软件，" +
            "与小米科技有限责任公司无任何隶属、合作或授权关系。如涉及内容侵权，请权利方联系作者，" +
            "我们将第一时间下架并删除相关内容。"
}
