package com.mutx163.qingyu.pages.shell

/**
 * 壳内「页面索引」的**清单数据**——纯 Kotlin，不含 Compose 依赖，因此能在 JVM 上直接测。
 *
 * ## 这份清单从哪来
 *
 * 逐条来自 `docs/plans/2026-10-27-compose-phase3-l4-checklist.md` §2（原始清单 82 个页面单元，
 * 按批次分组；本目录随后因补口与新增入口扩到 **88 条**，四档合计以
 * `ShellPageCatalogTest` 的断言为准——本段不再重复写会过期的数字）。那份清单是「真机逐页对照（L4）」的依据；本目录是它的**可点击版本**：
 * 有了它，用户在真机上不用记路径，点一行就能进某页做对照。
 *
 * ## 为什么不直接写进 Activity
 *
 * 1. **可测**：`ShellPageCatalogTest` 钉住「id 唯一 / 每条都有标题 / 暂无入口的都写了原因 /
 *    总数与批次对得上」。这些规则写在 Compose 文件里就只能靠人看。
 * 2. **单一真源**：索引界面与分派层（`ShellPageIndex.kt`）都读这一份，
 *    加页只改这里 + 分派里加一个分支，不会出现「界面里有、点进去空白」。
 *
 * ## kind 三档的判据（写死在这里，避免后来者含糊）
 *
 * - [ShellPageDataKind.DIRECT]：页面自带默认值，不需要喂任何数据就能渲染出完整界面。
 * - [ShellPageDataKind.DEMO]：页面必须收一份视图状态；壳里喂的是**演示数据**
 *   （空列表或示例条目），界面上会标出来，免得被当成真实数据。
 * - [ShellPageDataKind.UNAVAILABLE]：**进不去**，且原因必须是「代码里缺东西」而不是「懒得接」，
 *   并要用 [ShellBlockReason] 标出缺的是哪一类。目前 6 条：3 条没有整页渲染层、
 *   2 条要求宿主注入二维码/相机图形而仓库里没有对应实现、1 条页面已写好但壳侧没有数据层去喂。
 * - [ShellPageDataKind.ALWAYS_VISIBLE]：不是独立页面（本壳底栏），常驻可见，不需要入口。
 */
enum class ShellPageDataKind {
    DIRECT,
    DEMO,
    UNAVAILABLE,
    ALWAYS_VISIBLE,
}

/**
 * 「暂不可用」到底缺什么——**分类写进数据里，不靠人读整句话猜**。
 *
 * 存在的理由很实际：将来有人补齐了某个前置条件，要能一眼查出「哪几条因此可以放开」。
 * 只写一句「暂不支持」，下一个人得把 6 条原因重新读一遍才知道该动哪条。
 *
 * [label] 同时是索引行上原因文字的开头，测试拿它跟 [ShellPageEntry.note] 对拍：
 * 分类与文字不允许各说各的。
 */
enum class ShellBlockReason(val label: String) {
    /** 有模型/面板/解析层，**没有整页 Composable** —— 要补的是页面本身。 */
    MISSING_RENDERER("缺整页渲染层"),

    /** 页面实现了，但要宿主注入一块外部图形（二维码、相机预览）—— 要补的是槽位实现。 */
    MISSING_HOST_SLOT("缺宿主槽位"),

    /**
     * 页面实现了，但要宿主喂数据（数据提供函数 / 版本戳）—— 要补的是壳侧数据接线。
     *
     * 与 [MISSING_HOST_SLOT] 分开：那个缺的是「一块画出来的东西」，这个缺的是
     * 「一份查出来的数据」，将来动它们的人不是同一批。
     */
    MISSING_HOST_DATA("缺宿主数据"),

    /** 只差一个第三方库（本轮 6 条里没有单独属于这一类的，留位给后续）。 */
    MISSING_DEPENDENCY("缺依赖"),
}

/** 索引里的一行。 */
data class ShellPageEntry(
    /** 稳定 id，格式 `<批次小写>.<名字>`，分派层按它选 Composable。 */
    val id: String,
    /** 屏上标题（与 L4 清单同一套名字，便于两边对照）。 */
    val title: String,
    val kind: ShellPageDataKind,
    /** `UNAVAILABLE` 必填：一句话说清缺什么。其余可为 null。 */
    val note: String? = null,
    /** `UNAVAILABLE` 必填：缺的是哪一类。其余必须为 null。 */
    val blockedBy: ShellBlockReason? = null,
)

/** 一个批次 = 索引里的一个分组。 */
data class ShellPageBatch(
    /** 台账批次号（`P3-A` 这种），也是 id 前缀的来源。 */
    val code: String,
    /** 分组标题（人话）。 */
    val title: String,
    val pages: List<ShellPageEntry>,
)

/**
 * 全量页面目录。
 *
 * 顺序 = L4 清单里的批次顺序，不按拼音重排：对照时要能照着清单一行行走。
 */
object ShellPageCatalog {

    /** 索引里显示在行尾的短标签。 */
    fun badgeOf(kind: ShellPageDataKind): String? = when (kind) {
        ShellPageDataKind.DIRECT -> null
        ShellPageDataKind.DEMO -> "演示数据"
        ShellPageDataKind.UNAVAILABLE -> "暂不可用"
        ShellPageDataKind.ALWAYS_VISIBLE -> "常驻"
    }

    private fun page(
        code: String,
        name: String,
        title: String,
        kind: ShellPageDataKind,
        note: String? = null,
        blockedBy: ShellBlockReason? = null,
    ): ShellPageEntry = ShellPageEntry(
        id = "${code.lowercase().removePrefix("p3-")}.$name",
        title = title,
        kind = kind,
        note = note,
        blockedBy = blockedBy,
    )

    val batches: List<ShellPageBatch> = listOf(
        ShellPageBatch(
            code = "P3-A",
            title = "关于与说明",
            pages = listOf(
                page("P3-A", "about", "关于", ShellPageDataKind.DIRECT),
                // 2026-10-28 补口：这一屏原先标「暂不可用」（只有解析模型没有界面）。
                // 现已补上 `ChangelogPage`（零参渲染，页面自己去读 assets 里的发布说明）。
                // 归 DIRECT：不需要壳喂任何数据。至此台账虚标的三处全部收口。
                page("P3-A", "changelog", "更新日志", ShellPageDataKind.DIRECT),
                // 版本更新页：渲染层 + 宿主装配层由「版本更新页 1:1 复刻」批次交付（真检查/下载/设置）。
                page("P3-A", "update", "版本更新", ShellPageDataKind.DIRECT),
                page("P3-A", "contributors", "代码贡献者", ShellPageDataKind.DEMO),
                page("P3-A", "licenses", "开源许可", ShellPageDataKind.DEMO),
                page("P3-A", "support", "支持作者", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-B",
            title = "设置族（共用一个渲染层）",
            pages = listOf(
                page("P3-B", "settingsHome", "设置首页 / 课表设置", ShellPageDataKind.DEMO),
                page("P3-B", "semester", "设置 · 学期", ShellPageDataKind.DEMO),
                page("P3-B", "general", "设置 · 通用", ShellPageDataKind.DEMO),
                page("P3-B", "appearance", "设置 · 外观", ShellPageDataKind.DEMO),
                page("P3-B", "theme", "设置 · 主题管理", ShellPageDataKind.DEMO),
                page("P3-B", "appearanceEditor", "设置 · 外观编辑器", ShellPageDataKind.DEMO),
                page("P3-B", "materialGeneral", "设置 · 材质（通用页签）", ShellPageDataKind.DEMO),
                page("P3-B", "materialCourseCard", "设置 · 材质（课程卡页签）", ShellPageDataKind.DEMO),
                page("P3-B", "backdropFlow", "设置 · 首页背景", ShellPageDataKind.DEMO),
                page("P3-B", "recentWallpaper", "设置 · 最近壁纸", ShellPageDataKind.DEMO),
                page("P3-B", "bingGallery", "设置 · Bing 壁纸画廊", ShellPageDataKind.DEMO),
                // 2026-11-01 F24：壁纸取景页（外观编辑 → 壁纸面板 → 调整位置）。
                // 真实入口是壁纸面板；这里登记是为了 L4 能直接点到它做对照。
                page("P3-B", "wallpaperPosition", "设置 · 壁纸取景", ShellPageDataKind.DIRECT),
                page("P3-B", "homeWidget", "设置 · 首页小组件", ShellPageDataKind.DEMO),
                page("P3-B", "homeNavigation", "设置 · 首页导航", ShellPageDataKind.DEMO),
                page("P3-B", "homeMenuEditor", "设置 · 首页菜单编辑器", ShellPageDataKind.DEMO),
                // 2026-10-28 补口：这一屏原先标「暂不可用」（缺整页渲染层），
                // 现已补上 spec（`SettingsTimetablePageSettingsPage`）并登记进
                // `SettingsBatchCoverageTest`，同时接上分派分支。台账原记
                // P3-B「20 页全迁」是人工登记失真——20 页共用一个
                // `SettingsPageScreen(spec)`，「没写页面函数」与「没写页面」长得一样。
                page("P3-B", "timetablePage", "设置 · 课表页面", ShellPageDataKind.DEMO),
                page("P3-B", "courseCard", "设置 · 课程卡片", ShellPageDataKind.DEMO),
                page("P3-B", "live", "设置 · 实时活动", ShellPageDataKind.DEMO),
                page("P3-B", "liveSelfCheck", "设置 · 实时活动自检", ShellPageDataKind.DEMO),
                page("P3-B", "holiday", "设置 · 节假日", ShellPageDataKind.DEMO),
                page("P3-B", "holidayAdvanced", "设置 · 节假日（高级）", ShellPageDataKind.DEMO),
                page("P3-B", "weather", "设置 · 天气", ShellPageDataKind.DIRECT),
                page("P3-B", "diagnostics", "设置 · 诊断", ShellPageDataKind.DEMO),
                page("P3-B", "glassDock", "设置 · 玻璃坞编辑器", ShellPageDataKind.DEMO),
                page("P3-B", "glassDockIcon", "设置 · 玻璃坞图标", ShellPageDataKind.DEMO),
                page("P3-B", "reset", "设置 · 重置", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-C1",
            title = "课表 · 周视图",
            pages = listOf(
                page("P3-C1", "week", "课表 · 周视图", ShellPageDataKind.DEMO),
                page("P3-C1", "profiles", "课表 · 多课表管理", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-C2",
            title = "课表 · 月视图",
            pages = listOf(
                page("P3-C2", "month", "月视图", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-C3",
            title = "课表 · 日视图",
            pages = listOf(
                page("P3-C3", "day", "日视图", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-D1",
            title = "课程表单与概览",
            pages = listOf(
                page("P3-D1", "addCourse", "添加 / 编辑课程", ShellPageDataKind.DEMO),
                page("P3-D1", "overview", "课程概览", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-D2",
            title = "日程与任务",
            pages = listOf(
                page("P3-D2", "scheduleList", "日程列表", ShellPageDataKind.DEMO),
                page("P3-D2", "addSchedule", "添加 / 编辑日程", ShellPageDataKind.DEMO),
                page("P3-D2", "dateRule", "日程日期规则", ShellPageDataKind.DEMO),
                page("P3-D2", "taskList", "任务列表", ShellPageDataKind.DEMO),
                page("P3-D2", "addTask", "添加 / 编辑任务", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-D3",
            title = "作息与考试",
            pages = listOf(
                page("P3-D3", "timeSchemes", "作息管理", ShellPageDataKind.DEMO),
                // 2026-10-29（P35-TS）：时间模板的「编辑节次」子页。DIRECT 表示有真渲染层且不需要外部数据：
                // 它由 `d3.timeSchemes` 写入 `ShellWiring.pendingTimeSchemeEditId` 后推入（与 `b.appearanceEditor` 同构）。
                page("P3-D3", "timeSchemeEditor", "编辑时间模板节次", ShellPageDataKind.DIRECT),
                page("P3-D3", "locationMatch", "地点时间匹配", ShellPageDataKind.DEMO),
                page("P3-D3", "addExam", "添加 / 编辑考试", ShellPageDataKind.DEMO),
                page("P3-D3", "examList", "考试列表", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-E",
            title = "统计族",
            pages = listOf(
                page("P3-E", "statistics", "课程统计主页", ShellPageDataKind.DEMO),
                page("P3-E", "statisticsSettings", "统计设置", ShellPageDataKind.DEMO),
                page("P3-E", "analysis", "统计分析", ShellPageDataKind.DEMO),
                page("P3-E", "session", "单节课明细", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-F",
            title = "同步与备份",
            pages = listOf(
                page("P3-F", "cloudSync", "云同步", ShellPageDataKind.DEMO),
                page("P3-F", "backupList", "备份列表", ShellPageDataKind.DEMO),
                page("P3-F", "couple", "情侣课表", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-G1",
            title = "导入 · 基础",
            pages = listOf(
                page("P3-G1", "importEntry", "导入入口", ShellPageDataKind.DEMO),
                page("P3-G1", "icsImport", "ICS 导入", ShellPageDataKind.DIRECT),
                page("P3-G1", "spreadsheetImport", "表格导入", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-G2",
            title = "导入 · 仓库适配",
            pages = listOf(
                // 2026-10-31 F23 更正：上一条注释（F08-8b 写的「前两页转 DIRECT、
                // 数据源换成真适配仓、演示常量已删」）与代码不符——当时常量仍在壳里，
                // 两页标 DIRECT 导致索引行不贴角标，看着像「页面自带真数据」，
                // 实际喂的是「示例学校 / 示例适配器」，角标在说谎。
                //
                // 现状与规则：壳侧**没有**学校列表数据源（适配仓只接到了
                // warehouseImport 一页），所以 schoolAdapters / adapterDetail / webLogin
                // 三页一律不编数据，由分派层显示空态——「暂无可用学校」
                // 「暂时无法读取适配器列表」「未找到有效的教务登录地址」。
                // 三页都必须收一份视图状态，按本枚举文档归 DEMO（空列表也算 DEMO）。
                // 真正的宿主数据（学校清单 / 适配器 import_url / 抓课表脚本）属 F08-8c。
                page("P3-G2", "schoolAdapters", "学校适配器列表", ShellPageDataKind.DEMO),
                page("P3-G2", "adapterDetail", "适配器详情", ShellPageDataKind.DEMO),
                page("P3-G2", "warehouseImport", "仓库课程导入", ShellPageDataKind.DIRECT),
                page("P3-G2", "webLogin", "教务网页登录", ShellPageDataKind.DEMO),
                page("P3-G2", "customDebug", "自定义调试", ShellPageDataKind.DIRECT),
                page("P3-G2", "aiImageImport", "AI 识图导入", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-G3",
            title = "导出与传输",
            pages = listOf(
                page("P3-G3", "dataTransfer", "数据传输", ShellPageDataKind.DEMO),
                page("P3-G3", "icsExport", "ICS 导出", ShellPageDataKind.DEMO),
                page("P3-G3", "qrSend", "二维码发送", ShellPageDataKind.DIRECT),
                page("P3-G3", "qrScan", "二维码扫码", ShellPageDataKind.DIRECT),
                page("P3-G3", "lanEdit", "局域网编辑", ShellPageDataKind.DEMO),
                page("P3-G3", "pickupCodes", "取件码", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-H",
            title = "诊断与测试夹具",
            pages = listOf(
                page("P3-H", "log", "实时诊断日志", ShellPageDataKind.DEMO),
                page("P3-H", "memory", "内存统计", ShellPageDataKind.DEMO),
                page("P3-H", "perfReport", "性能报告", ShellPageDataKind.DEMO),
                page("P3-H", "fixture", "实时测试夹具", ShellPageDataKind.DEMO),
            ),
        ),
        ShellPageBatch(
            code = "P3-I",
            title = "引导与展示",
            pages = listOf(
                page("P3-I", "startup", "启动引导", ShellPageDataKind.DIRECT),
                page("P3-I", "userGuide", "使用指南", ShellPageDataKind.DIRECT),
                page("P3-I", "more", "全部功能", ShellPageDataKind.DIRECT),
                page("P3-I", "moreSearch", "全部功能 · 搜索浮层", ShellPageDataKind.DIRECT),
                page("P3-I", "hyperosShowcase", "HyperOS 展示", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-I2",
            title = "Miuix 展示册",
            pages = listOf(
                page("P3-I2", "showcase", "Miuix 展示册", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-J",
            title = "实时活动与天气",
            pages = listOf(
                page("P3-J", "live", "实时活动 / 灵动岛", ShellPageDataKind.DIRECT),
                page("P3-J", "displayBefore", "上课前显示设置", ShellPageDataKind.DIRECT),
                page("P3-J", "displayDuring", "下课前显示设置", ShellPageDataKind.DIRECT),
                page("P3-J", "reminderTiming", "提醒时机设置", ShellPageDataKind.DIRECT),
                // 2026-10-28 补口：这一屏原先标「暂不可用」（缺整页渲染层），
                // 现已补上（`LiveKeepAliveSettingsPage` 的状态化重载）。
                // 归 DIRECT：无障碍状态读的是**平台真值**（`KeepAliveAccessibilityStatus`），
                // 不是编造的演示数据；页面自带默认值即可渲染。
                // 唯一不真实的地方是「从最近任务中隐藏」不落盘（壳没有数据层）——
                // 这一点写在 L4 清单该行的对照点里，不靠行尾标记表达。
                page("P3-J", "keepAlive", "实时活动 · 保持后台运行", ShellPageDataKind.DIRECT),
                page("P3-J", "weatherCity", "天气城市选择", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-K",
            title = "冲突与反馈",
            pages = listOf(
                page("P3-K", "conflict", "课程冲突详情", ShellPageDataKind.DEMO),
                page("P3-K", "feedback", "意见反馈", ShellPageDataKind.DIRECT),
            ),
        ),
        ShellPageBatch(
            code = "P3-0",
            title = "壳自身",
            pages = listOf(
                page(
                    "P3-0", "dock", "底部玻璃坞", ShellPageDataKind.ALWAYS_VISIBLE,
                    "常驻底栏，不需要单独入口",
                ),
            ),
        ),
    )

    /** 全部页面（按批次顺序展平）。 */
    val all: List<ShellPageEntry> by lazy { batches.flatMap { it.pages } }

    /** 能点进去的页面（索引里可点击的那些）。 */
    val openable: List<ShellPageEntry> by lazy { all.filter { it.isOpenable } }

    fun find(id: String): ShellPageEntry? = all.firstOrNull { it.id == id }

    fun countOf(kind: ShellPageDataKind): Int = all.count { it.kind == kind }

    val totalCount: Int get() = all.size
}

/**
 * 这一行点下去会不会有东西。
 *
 * 故意做成扩展属性而不是让界面各自判断：界面里出现第二套判据，迟早与分派层漂开。
 */
val ShellPageEntry.isOpenable: Boolean
    get() = kind == ShellPageDataKind.DIRECT || kind == ShellPageDataKind.DEMO
