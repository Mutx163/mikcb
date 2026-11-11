package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 设置首页 / 课表设置 hub（`lib/screens/timetable_settings_screen.dart`）结构测试。
 *
 * 期望值来源：Dart 源（8 个 section / 条件分支 / 行尾取值）+ ARB，不从实现倒推。
 *
 * 本页最容易写错的五处，各有独立用例：
 * 1. 学期摘要卡的标题按「当前周 / 总周数」拼，开学日期未设置时给另一句；
 * 2. 超级岛入口行尾**优先报权限缺口**，已授权才报开/关（:919-926）；
 * 3. 云同步入口行尾有四种状态，配置未读完时留白（:998-1007）；
 * 4. 开发者工具组按 `kReleaseMode` / 诊断构建分别门控（:1065-1144）；
 * 5. 学期设置子页的「同步当前周」在没开学日期时禁用并说明（:736-747）。
 */
class SettingsTimetablePageTest {

    private fun spec(state: SettingsTimetableState = SettingsTimetableState()) =
        SettingsTimetablePage.spec(state)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 settingsTitle`() {
        val page = spec()
        assertEquals("settings-timetable", page.id)
        assertEquals("settingsTitle", page.titleKey)
        assertEquals("课表设置", page.title)
        // timetable_settings_screen.dart:322 `title: Text(l10n.settingsTitle)`
    }

    @Test
    fun `八个 section 的顺序`() {
        // timetable_settings_screen.dart:287 `itemCount: 8`；分区注释见 :342-344。
        // section 0 是学期摘要卡（无前导空档），1-7 各自「gap + label + 组」。
        assertEquals(
            listOf(
                "timetable.summary",
                "timetable.gap.timetable",
                "timetable.section.timetable.label",
                "timetable.section.timetable",
                "timetable.gap.timetableDisplay",
                "timetable.section.timetableDisplay.label",
                "timetable.section.display",
                "timetable.gap.timetableReminder",
                "timetable.section.timetableReminder.label",
                "timetable.section.reminder",
                "timetable.gap.timetableApp",
                "timetable.section.timetableApp.label",
                "timetable.section.app",
                "timetable.gap.timetableDataShare",
                "timetable.section.timetableDataShare.label",
                "timetable.section.dataShare",
                "timetable.gap.timetableAbout",
                "timetable.section.timetableAbout.label",
                "timetable.section.about",
                "timetable.gap.developer",
                "timetable.section.developer.label",
                "timetable.section.developer",
                "timetable.gap.bottom",
            ),
            spec().topLevelIds(),
        )
    }

    // ------------------------------------------------------------ 学期摘要卡

    @Test
    fun `摘要卡标题按当前周与总周数拼`() {
        // timetable_settings_screen.dart:389-392 `semesterOverviewCurrentWeek(current, total)`
        val page = spec(SettingsTimetableState(currentWeek = 5, semesterWeekCount = 20))
        val summary = page.row("timetable.summary")
        assertEquals("第 5 周，共 20 周", summary.title)
        assertEquals("semesterOverviewCurrentWeek", summary.titleKey)
        assertEquals(SettingsAction.NAVIGATE, summary.action)
        assertEquals("/settings/semester", summary.actionTarget)
    }

    @Test
    fun `摘要卡副标题按开学日期是否设置二选一`() {
        // :393-395
        val unset = spec(SettingsTimetableState(semesterStartDate = null)).row("timetable.summary")
        assertEquals("semesterStartUnset", unset.subtitleKey)
        assertEquals("未设置开学日期", unset.subtitle)

        val set = spec(
            SettingsTimetableState(semesterStartDate = Triple(2026, 9, 1)),
        ).row("timetable.summary")
        // _formatDate（:1154-1156）：月日补零，年不补
        assertEquals("开学日期：2026-09-01", set.subtitle)
        assertEquals("semesterStartSet", set.subtitleKey)
    }

    @Test
    fun `日期格式化月日补零`() {
        assertEquals("2026-09-01", SettingsTimetablePage.formatDate(2026, 9, 1))
        assertEquals("2026-12-31", SettingsTimetablePage.formatDate(2026, 12, 31))
        assertEquals("2027-01-05", SettingsTimetablePage.formatDate(2027, 1, 5))
    }

    // ------------------------------------------------------ 课表 section

    @Test
    fun `课表组三行与行尾取值`() {
        // :404-457
        val page = spec(
            SettingsTimetableState(
                activeProfileName = "大二上",
                activeTimeSchemeName = "标准作息",
                holidayMarkingEnabled = true,
            ),
        )
        val label = page.flatten().filterIsInstance<SettingsLabel>()
            .first { it.id == "timetable.section.timetable.label" }
        assertEquals("课表", label.text)
        assertEquals(
            listOf(
                "timetable.profiles",
                "timetable.timeScheme",
                "timetable.holiday",
            ),
            page.group("timetable.section.timetable").childRowIds(),
        )
        val profiles = page.row("timetable.profiles")
        assertEquals(MiuixRowComponent.ARROW, profiles.component)
        assertEquals("课表管理", profiles.title)
        // 行尾**不显示**课表档案名（2026-11-10 用户指令：用户自起名长度不可控，
        // 拉满整行很难看；全名在「课表档案」管理页可见）⇒ 有值也不挂 details。
        assertNull(profiles.details)
        assertNull(profiles.detailsKey)

        val scheme = page.row("timetable.timeScheme")
        assertEquals("时间模板", scheme.title)
        // 同一口径：模板名「标准作息」这类用户数据不上行尾。
        assertNull(scheme.details)
        assertNull(scheme.detailsKey)
        assertEquals("/settings/time-schemes", scheme.actionTarget)

        val holiday = page.row("timetable.holiday")
        assertEquals("节假日标记", holiday.title)
        assertEquals("已开启", holiday.details)
        assertEquals("liveIslandLabelEntryEnabled", holiday.detailsKey)
        assertEquals("/settings/holiday", holiday.actionTarget)
    }

    @Test
    fun `课表与时间模板两行恒定不带行尾值`() {
        // 2026-11-10 用户指令：这两行的行尾值是用户自起的长文本（档案名 / 模板名），
        // 长度不可控，统一去掉、只留「图标 + 标题 + 箭头」；空与非空两种输入都不挂 details。
        val empty = spec(SettingsTimetableState(activeProfileName = null, activeTimeSchemeName = null))
        assertNull(empty.row("timetable.profiles").details)
        assertNull(empty.row("timetable.profiles").detailsKey)
        assertNull(empty.row("timetable.timeScheme").details)
        assertNull(empty.row("timetable.timeScheme").detailsKey)

        val filled = spec(
            SettingsTimetableState(activeProfileName = "大二上", activeTimeSchemeName = "标准作息"),
        )
        assertNull(filled.row("timetable.profiles").details)
        assertNull(filled.row("timetable.profiles").detailsKey)
        assertNull(filled.row("timetable.timeScheme").details)
        assertNull(filled.row("timetable.timeScheme").detailsKey)
    }

    @Test
    fun `节假日标记关闭时行尾写已关闭`() {
        // :447-451
        val row = spec(SettingsTimetableState(holidayMarkingEnabled = false)).row("timetable.holiday")
        assertEquals("已关闭", row.details)
        assertEquals("liveIslandLabelEntryDisabled", row.detailsKey)
    }

    // ------------------------------------------------------ 显示 section

    @Test
    fun `显示组三行与天气行尾取值`() {
        // :466-500
        val page = spec(SettingsTimetableState(weatherCityName = "杭州"))
        assertEquals(
            listOf(
                "timetable.courseCard",
                "timetable.pageSettings",
                "timetable.weather",
            ),
            page.group("timetable.section.display").childRowIds(),
        )
        assertEquals("课程卡片", page.row("timetable.courseCard").title)
        assertEquals("/settings/course-card", page.row("timetable.courseCard").actionTarget)
        assertEquals("课表页面", page.row("timetable.pageSettings").title)
        assertEquals("/settings/timetable-page", page.row("timetable.pageSettings").actionTarget)
        assertEquals("课程卡天气", page.row("timetable.weather").title)
        assertEquals("杭州", page.row("timetable.weather").details)
        assertEquals("/settings/weather", page.row("timetable.weather").actionTarget)
    }

    @Test
    fun `天气未设置城市时写未设置`() {
        // :493 `weather?.location?.name ?? l10n.weatherCityNotSet`
        val row = spec(SettingsTimetableState(weatherCityName = null)).row("timetable.weather")
        assertEquals("未设置", row.details)
        assertEquals("weatherCityNotSet", row.detailsKey)
    }

    // --------------------------------------------------- 提醒与桌面 section

    @Test
    fun `提醒与桌面组两行`() {
        // :508-527
        val page = spec()
        assertEquals(
            listOf("timetable.live", "timetable.homeWidget"),
            page.group("timetable.section.reminder").childRowIds(),
        )
        assertEquals("超级岛与通知", page.row("timetable.live").title)
        assertEquals("/settings/live", page.row("timetable.live").actionTarget)
        assertEquals("桌面小组件", page.row("timetable.homeWidget").title)
        assertEquals("/settings/home-widget", page.row("timetable.homeWidget").actionTarget)
    }

    @Test
    fun `超级岛行尾权限缺口优先`() {
        // :919-926：hasPermission == false 时只报权限，不看开关状态
        val missing = spec(
            SettingsTimetableState(notificationPermissionGranted = false, liveReminderEnabled = true),
        ).row("timetable.live")
        assertEquals("缺少通知权限", missing.details)
        assertEquals("liveNotificationPermissionMissing", missing.detailsKey)

        // 已授权 + 有提醒开 → 已开启
        val on = spec(
            SettingsTimetableState(notificationPermissionGranted = true, liveReminderEnabled = true),
        ).row("timetable.live")
        assertEquals("已开启", on.details)

        // 已授权 + 全关 → 已关闭
        val off = spec(
            SettingsTimetableState(notificationPermissionGranted = true, liveReminderEnabled = false),
        ).row("timetable.live")
        assertEquals("已关闭", off.details)

        // 还没查到 → 留白，避免首帧闪错
        val unknown = spec(
            SettingsTimetableState(notificationPermissionGranted = null, liveReminderEnabled = true),
        ).row("timetable.live")
        assertNull(unknown.details)
    }

    // --------------------------------------------------------- 应用 section

    @Test
    fun `应用组三行`() {
        // :532-567
        val page = spec()
        assertEquals(
            listOf("timetable.appearance", "timetable.homeNavigation", "timetable.general"),
            page.group("timetable.section.app").childRowIds(),
        )
        assertEquals("外观与配色", page.row("timetable.appearance").title)
        assertEquals("/settings/appearance", page.row("timetable.appearance").actionTarget)
        assertEquals("首页与导航", page.row("timetable.homeNavigation").title)
        assertEquals("/settings/home-navigation", page.row("timetable.homeNavigation").actionTarget)
        assertEquals("通用", page.row("timetable.general").title)
        assertEquals("/settings/general", page.row("timetable.general").actionTarget)
    }

    // ----------------------------------------------------- 数据与共享 section

    @Test
    fun `数据与共享组四行`() {
        // :569-613
        val page = spec()
        assertEquals(
            listOf(
                "timetable.dataTransfer",
                "timetable.cloudSync",
                "timetable.lanEdit",
                "timetable.coupleTimetable",
            ),
            page.group("timetable.section.dataShare").childRowIds(),
        )
        assertEquals("数据备份与迁移", page.row("timetable.dataTransfer").title)
        assertEquals("云同步", page.row("timetable.cloudSync").title)
        assertEquals("局域网编辑", page.row("timetable.lanEdit").title)
        assertEquals("情侣课表", page.row("timetable.coupleTimetable").title)
        assertEquals("/settings/couple-timetable", page.row("timetable.coupleTimetable").actionTarget)
    }

    @Test
    fun `情侣课表行尾按是否绑定二选一`() {
        // :600-607
        assertEquals(
            "已绑定",
            spec(SettingsTimetableState(partnerBound = true)).row("timetable.coupleTimetable").details,
        )
        assertEquals(
            "未绑定",
            spec(SettingsTimetableState(partnerBound = false)).row("timetable.coupleTimetable").details,
        )
    }

    @Test
    fun `云同步行尾四态且配置未读完时留白`() {
        // :998-1007
        fun details(state: SettingsTimetableState) = spec(state).row("timetable.cloudSync").details

        assertNull(details(SettingsTimetableState(cloudSyncState = "loading")))
        assertEquals("已关闭", details(SettingsTimetableState(cloudSyncState = "disabled")))
        assertEquals("同步中", details(SettingsTimetableState(cloudSyncState = "syncing")))
        assertEquals("上次同步失败", details(SettingsTimetableState(cloudSyncState = "error")))
        assertEquals("已开启", details(SettingsTimetableState(cloudSyncState = "enabled")))

        assertEquals(
            "cloudSyncEntryError",
            spec(SettingsTimetableState(cloudSyncState = "error")).row("timetable.cloudSync").detailsKey,
        )
        assertNull(
            spec(SettingsTimetableState(cloudSyncState = "loading")).row("timetable.cloudSync").detailsKey,
        )
    }

    // -------------------------------------------------------- 关于 section

    @Test
    fun `关于组三行与诊断行尾`() {
        // :615-656
        val page = spec()
        assertEquals(
            listOf("timetable.about", "timetable.userGuide", "timetable.diagnostics"),
            page.group("timetable.section.about").childRowIds(),
        )
        assertEquals("关于软件", page.row("timetable.about").title)
        assertEquals("使用引导与权限", page.row("timetable.userGuide").title)
        assertEquals("诊断", page.row("timetable.diagnostics").title)
        assertEquals("日志 · 自检 · 内存", page.row("timetable.diagnostics").details)
        assertEquals("/settings/diagnostics", page.row("timetable.diagnostics").actionTarget)
    }

    // ------------------------------------------------------ 开发者 section

    @Test
    fun `调试版只留两组组件展示`() {
        // :1065-1144：非诊断构建 + kReleaseMode → 整块不渲染；
        // 非诊断构建 + 非 release（即调试版）→ 两组「组件展示」（HyperOS / Miuix）。
        //
        // 2026-11-10：HyperOS 组件展示行补回。迁移时（10-27 建本页）展示页还没移植，
        // 于是整行漏掉；`HyperosShowcasePage` 后来落地（路由 `i.hyperosShowcase`），
        // 但设置页没人指向它 = 死页面。发布版 `timetable_settings_screen.dart:1216-1229`
        // 也正是「HyperOS 展示 + Miuix 展示」两行。
        // 同批把「调试 UI 叠层」「调试面板」两行藏起：重构版两者都没有实现
        // （无 `BlackBoxOverlayPreferences`、无面板落点），留着就是点了必无效的入口。
        val debug = spec(
            SettingsTimetableState(releaseBuild = false, diagnosticsBuild = false),
        )
        assertEquals(
            listOf(
                "timetable.hyperosShowcase",
                "timetable.miuixShowcase",
            ),
            debug.group("timetable.section.developer").childRowIds(),
        )
    }

    @Test
    fun `诊断构建多出内存与实况样例行`() {
        // :1077-1094：showDiagnosticsTools 时多两行
        val diagnostics = spec(
            SettingsTimetableState(releaseBuild = false, diagnosticsBuild = true),
        )
        assertEquals(
            listOf(
                "timetable.memoryStats",
                "timetable.liveTestingFixture",
                "timetable.hyperosShowcase",
                "timetable.miuixShowcase",
            ),
            diagnostics.group("timetable.section.developer").childRowIds(),
        )
    }

    @Test
    fun `正式发布版整块开发者工具不渲染`() {
        // :1066-1068 `if (!showDiagnosticsTools && kReleaseMode) return SizedBox.shrink()`
        // —— shrink 发生在 _SettingsDeveloperListGroup 内部，所以 :668 那个
        // HyperosSectionGap 仍然会渲染（不是整段 section 被替换掉）。
        val release = spec(SettingsTimetableState(releaseBuild = true, diagnosticsBuild = false))
        assertFalse(release.topLevelIds().contains("timetable.section.developer"))
        assertFalse(release.topLevelIds().contains("timetable.gap.developer"))
        assertFalse(release.topLevelIds().contains("timetable.section.developer.label"))
        // 底部空档照旧在最后（忠实搬运：Dart 里它在 shrink 之外）
        assertEquals("timetable.gap.bottom", release.topLevelIds().last())
    }

    // ------------------------------------------------------- 学期设置子页

    @Test
    fun `学期设置子页三行与行尾`() {
        // :679-756
        val page = SettingsTimetablePage.semesterSpec(
            SettingsTimetableState(semesterStartDate = Triple(2026, 9, 1), semesterWeekCount = 20),
        )
        assertEquals("settings-timetable-semester", page.id)
        assertEquals("settingsSemesterScreenTitle", page.titleKey)
        assertEquals("学期设置", page.title)
        assertEquals(
            listOf(
                "timetable.semester.startDate",
                "timetable.semester.weekCount",
                "timetable.semester.syncWeek",
            ),
            page.group("timetable.semester.main").childRowIds(),
        )
        val start = page.row("timetable.semester.startDate")
        assertEquals("开学日期", start.title)
        assertEquals("semesterStartDateAction", start.titleKey)
        assertEquals("2026-09-01", start.details)

        val weeks = page.row("timetable.semester.weekCount")
        assertEquals("选择学期周数", weeks.title)
        assertEquals("20 周", weeks.details)
        assertEquals("semesterWeekCountAction", weeks.detailsKey)

        val sync = page.row("timetable.semester.syncWeek")
        assertEquals("同步当前周", sync.title)
        assertTrue(sync.enabled)
        assertNull(sync.details)
    }

    @Test
    fun `学期设置三行的动作必须与宿主认的三种一致`() {
        // 宿主（composeP1 `SettingsSemesterHost`）按 `动作 + 行 id` 分派：
        // 前两行 SHEET（弹日期 / 弹周数），第三行 RUN_NOW（同步当前周）。
        // 这里钉住动作与行 id——任一侧改了名字而另一侧没跟上，页面就会「点了没反应」，
        // 而那条路径在 JVM 侧没有渲染测试可抓，只能靠这两条契约测试各钉一半。
        val page = SettingsTimetablePage.semesterSpec(SettingsTimetableState())
        assertEquals(SettingsAction.SHEET, page.row(SemesterSettingsLogic.ROW_START_DATE).action)
        assertEquals(SettingsAction.SHEET, page.row(SemesterSettingsLogic.ROW_WEEK_COUNT).action)
        assertEquals(SettingsAction.RUN_NOW, page.row(SemesterSettingsLogic.ROW_SYNC_WEEK).action)
    }

    @Test
    fun `没开学日期时首行动作变成设置开学日期`() {
        // :701-703 `semesterStartDate == null ? setSemesterStartDateAction : semesterStartDateAction`
        val page = SettingsTimetablePage.semesterSpec(
            SettingsTimetableState(semesterStartDate = null, semesterWeekCount = 20),
        )
        val start = page.row("timetable.semester.startDate")
        assertEquals("设置开学日期", start.title)
        assertEquals("setSemesterStartDateAction", start.titleKey)
        assertNull(start.details)
    }

    @Test
    fun `没开学日期时同步当前周禁用并说明原因`() {
        // :736-747
        val page = SettingsTimetablePage.semesterSpec(
            SettingsTimetableState(semesterStartDate = null),
        )
        val sync = page.row("timetable.semester.syncWeek")
        assertFalse(sync.enabled)
        assertEquals("请先设置开学日期", sync.details)
        assertEquals("syncCurrentWeekNeedsStartDate", sync.detailsKey)
    }

    // ------------------------------------------------------------ 纯函数行为

    @Test
    fun `云同步行尾状态取值`() {
        assertEquals(SettingsTimetablePage.CloudSyncTrailing.LOADING, SettingsTimetablePage.cloudSyncTrailingOf(loaded = false, enabled = false, syncing = false, hasError = false))
        assertEquals(SettingsTimetablePage.CloudSyncTrailing.DISABLED, SettingsTimetablePage.cloudSyncTrailingOf(loaded = true, enabled = false, syncing = false, hasError = false))
        assertEquals(SettingsTimetablePage.CloudSyncTrailing.SYNCING, SettingsTimetablePage.cloudSyncTrailingOf(loaded = true, enabled = true, syncing = true, hasError = false))
        // 有错优先于「已开启」，但与「同步中」相比是「同步中」先（:1003-1006 的嵌套三元）
        assertEquals(SettingsTimetablePage.CloudSyncTrailing.ERROR, SettingsTimetablePage.cloudSyncTrailingOf(loaded = true, enabled = true, syncing = false, hasError = true))
        assertEquals(SettingsTimetablePage.CloudSyncTrailing.SYNCING, SettingsTimetablePage.cloudSyncTrailingOf(loaded = true, enabled = true, syncing = true, hasError = true))
        // 关闭时不看同步态与错误（Dart 三元先判 enabled）
        assertEquals(SettingsTimetablePage.CloudSyncTrailing.DISABLED, SettingsTimetablePage.cloudSyncTrailingOf(loaded = true, enabled = false, syncing = true, hasError = true))
    }

    @Test
    fun `超级岛行尾状态取值`() {
        assertEquals(SettingsTimetablePage.LiveTrailing.HIDDEN, SettingsTimetablePage.liveTrailingOf(hasPermission = null, reminderEnabled = true))
        assertEquals(SettingsTimetablePage.LiveTrailing.PERMISSION_MISSING, SettingsTimetablePage.liveTrailingOf(hasPermission = false, reminderEnabled = true))
        assertEquals(SettingsTimetablePage.LiveTrailing.ENABLED, SettingsTimetablePage.liveTrailingOf(hasPermission = true, reminderEnabled = true))
        assertEquals(SettingsTimetablePage.LiveTrailing.DISABLED, SettingsTimetablePage.liveTrailingOf(hasPermission = true, reminderEnabled = false))
    }

    @Test
    fun `开发者工具可见性矩阵`() {
        // 诊断构建 → 全显示；正式发布版 → 全隐藏（连整块）；调试版 → 只显示后四行
        assertEquals(
            SettingsTimetablePage.DeveloperToolsVisibility.HIDDEN,
            SettingsTimetablePage.developerToolsVisibility(releaseBuild = true, diagnosticsBuild = false),
        )
        assertEquals(
            SettingsTimetablePage.DeveloperToolsVisibility.DEBUG_ONLY,
            SettingsTimetablePage.developerToolsVisibility(releaseBuild = false, diagnosticsBuild = false),
        )
        assertEquals(
            SettingsTimetablePage.DeveloperToolsVisibility.FULL,
            SettingsTimetablePage.developerToolsVisibility(releaseBuild = true, diagnosticsBuild = true),
        )
        assertEquals(
            SettingsTimetablePage.DeveloperToolsVisibility.FULL,
            SettingsTimetablePage.developerToolsVisibility(releaseBuild = false, diagnosticsBuild = true),
        )
    }

    @Test
    fun `周数读数按模板拼`() {
        // semesterWeekCountAction = `{count} 周`（ARB 模板，返回 ArbText）
        assertEquals("20 周", SettingsTimetablePage.weekCountLabel(20).text)
        assertEquals("semesterWeekCountAction", SettingsTimetablePage.weekCountLabel(20).key)
        assertEquals("1 周", SettingsTimetablePage.weekCountLabel(1).text)
    }
}
