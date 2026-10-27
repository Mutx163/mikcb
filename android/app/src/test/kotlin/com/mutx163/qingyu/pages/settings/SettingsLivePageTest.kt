package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 实时活动两页（`lib/screens/settings/settings_live.dart`）结构测试。
 *
 * 期望值来源：Dart 源（区块顺序 / 条件分支 / 上下限）+ ARB（文案），
 * 不从 Kotlin 实现倒推。每处断言都写了 Dart 出处，便于逐项复核。
 *
 * 覆盖两个屏：
 * 1. `LiveSettingsScreen`（:30-166）= 超级岛与通知的入口列表；
 * 2. `LiveTestingSettingsScreen`（:168-1186）= 自检页，14 个区块里有 9 个是
 *    原生诊断数据卡（条件渲染）。
 *
 * ## 两处模型口径的取舍（不是随手决定的）
 *
 * 1. **状态芯片**（`:756-763`、`:777-785`、`:875-895`）在 Dart 里是 `_DebugStatusChip`
 *    胶囊。模型词汇表没有「胶囊」槽位，这里落成 [SettingsDescription]（整宽一行字）：
 *    文案与顺序忠实，形状不同。渲染层将来补 chip 槽位时只改映射，不动文案。
 * 2. **``HyperosControlCard`` 的内部结构**被摊平成「卡头（CONTROL_CARD，含按钮）+
 *    后续整宽文案 + 开关分组」三串节点：Dart 那张卡把芯片、小标题、按钮、开关、
 *    脚注都塞在同一个 `Card` 里，本模型把卡内块按屏上顺序提到顶层——**顺序不变**，
 *    只是容器边界由渲染层决定。逐条对应见各断言的 Dart 行号。
 */
class SettingsLivePageTest {

    private fun page(data: LivePageData = LivePageData()) =
        SettingsLivePage.spec(SettingsPageState(), data)

    private fun selfCheck(data: LiveSelfCheckData = LiveSelfCheckData()) =
        SettingsLiveSelfCheckPage.spec(SettingsPageState(), data)

    private fun everythingLoaded(): LiveSelfCheckData = LiveSelfCheckData(
        debugLoaded = true,
        debugSections = LiveDebugSection.entries.associateWith { emptyList() },
    )

    // ================================================== 超级岛与通知（入口列表）

    @Test
    fun `入口页标题取自 liveSettingsTitle`() {
        // settings_live.dart:49-52 `HyperosSubpage(title: Text(l10n.liveSettingsTitle))`
        val spec = page()
        assertEquals("settings-live", spec.id)
        assertEquals("liveSettingsTitle", spec.titleKey)
        assertEquals("超级岛与通知", spec.title)
    }

    @Test
    fun `入口页三个带标签分组按提醒 显示 维护排列`() {
        // settings_live.dart:70-163：三个 HyperosSectionLabel 各带一个 HyperosListGroup，
        // 组间是两个 HyperosSectionGap（:92 / :132）
        assertEquals(
            listOf(
                "live.section.reminders",
                "live.group.reminders",
                "live.gap.display",
                "live.section.display",
                "live.group.display",
                "live.gap.maintenance",
                "live.section.maintenance",
                "live.group.maintenance",
            ),
            page().topLevelIds(),
        )
    }

    @Test
    fun `三个分组小标题的文案`() {
        // settings_live.dart:74 / :93 / :133
        val labels = page().flatten().filterIsInstance<SettingsLabel>()
        assertEquals(
            listOf("liveGroupReminders", "liveGroupDisplay", "liveGroupMaintenance"),
            labels.map { it.textKey },
        )
        assertEquals(listOf("提醒", "显示内容", "维护与自检"), labels.map { it.text })
    }

    @Test
    fun `提醒组只有提醒时段一行且是导航行`() {
        // settings_live.dart:75-91
        assertEquals(listOf("live.reminderTiming"), page().group("live.group.reminders").childRowIds())
        val row = page().row("live.reminderTiming")
        assertEquals("liveReminderTimingTitle", row.titleKey)
        assertEquals("提醒时段", row.title)
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals(SettingsLivePage.TARGET_REMINDER_TIMING, row.actionTarget)
        // 这一行在 Dart 里没有 details / subtitle
        assertNull(row.value)
        assertNull(row.subtitle)
    }

    @Test
    fun `显示组两行分别是上课前与课中下课`() {
        // settings_live.dart:94-131
        assertEquals(
            listOf("live.beforeClassDisplay", "live.duringEndDisplay"),
            page().group("live.group.display").childRowIds(),
        )
        val before = page().row("live.beforeClassDisplay")
        assertEquals("beforeClassDisplaySettingsTitle", before.titleKey)
        assertEquals("上课前提醒显示", before.title)
        assertEquals(SettingsAction.NAVIGATE, before.action)
        assertEquals(SettingsLivePage.TARGET_BEFORE_CLASS_DISPLAY, before.actionTarget)
        val during = page().row("live.duringEndDisplay")
        assertEquals("duringEndDisplaySettingsTitle", during.titleKey)
        assertEquals("课中与下课提醒显示", during.title)
        assertEquals(SettingsLivePage.TARGET_DURING_END_DISPLAY, during.actionTarget)
    }

    @Test
    fun `维护组是后台保活与自检两行`() {
        // settings_live.dart:134-162
        assertEquals(
            listOf("live.keepAlive", "live.selfCheck"),
            page().group("live.group.maintenance").childRowIds(),
        )
        assertEquals("liveKeepAliveTitle", page().row("live.keepAlive").titleKey)
        assertEquals("后台保活", page().row("live.keepAlive").title)
        assertEquals(SettingsLivePage.TARGET_KEEP_ALIVE, page().row("live.keepAlive").actionTarget)
        assertEquals("liveSelfCheckTitle", page().row("live.selfCheck").titleKey)
        assertEquals("自检", page().row("live.selfCheck").title)
        // 自检页是唯一带真实路由名的一行（settings_live.dart:151-158）
        assertEquals("/settings/live/self-check", page().row("live.selfCheck").actionTarget)
    }

    // ------------------------------------------------------- 显示摘要（:59-68）

    @Test
    fun `显示摘要勾选项不超过两项时用点号连接`() {
        // settings_shared.dart:157-159 `parts.join('·')`
        val two = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = true,
                showLocation = true,
                showCountdown = false,
                showStageText = false,
            ),
        )
        assertEquals("简称·地点", two.text)
        // 拼出来的串不是单条 ARB 文案
        assertNull(two.key)
        // 只有一项时就是那一项本身（:137-143）
        val one = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = true,
                useShortName = false,
                showLocation = false,
                showCountdown = false,
                showStageText = false,
            ),
        )
        assertEquals("课程名", one.text)
        assertEquals("liveDisplaySummaryCourseName", one.key)
    }

    @Test
    fun `显示摘要超过两项时收成 first 等 N 项`() {
        // settings_shared.dart:160 `l10n.liveDisplaySummaryMore(parts.first, parts.length)`
        val summary = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = true,
                showLocation = true,
                showCountdown = true,
                enableMiuiIslandLabelImage = true,
            ),
        )
        assertEquals("简称 等 4 项", summary.text)
        assertEquals("liveDisplaySummaryMore", summary.key)
    }

    @Test
    fun `显示摘要恰好三项也收成 more`() {
        // `parts.length <= 2` 才原样拼，三项进 more 分支
        val summary = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = true,
                showLocation = true,
                showCountdown = true,
            ),
        )
        assertEquals("简称 等 3 项", summary.text)
        assertEquals("liveDisplaySummaryMore", summary.key)
    }

    @Test
    fun `显示摘要全关时是最简显示`() {
        // settings_shared.dart:154-156
        val summary = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = false,
                showLocation = false,
                showCountdown = false,
                showStageText = false,
                enableMiuiIslandLabelImage = false,
            ),
        )
        assertEquals("最简显示", summary.text)
        assertEquals("liveDisplaySummaryMinimal", summary.key)
    }

    @Test
    fun `倒计时优先于阶段文字`() {
        // settings_shared.dart:146-150：`if (showCountdown) … else if (showStageText) …`
        val withCountdown = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = false,
                showLocation = false,
                showCountdown = true,
                showStageText = true,
            ),
        )
        assertEquals("倒计时", withCountdown.text)
        assertEquals("liveDisplaySummaryCountdownShort", withCountdown.key)
        val withStageOnly = SettingsLivePage.displaySummary(
            LiveDisplayInput(
                showCourseName = false,
                showLocation = false,
                showCountdown = false,
                showStageText = true,
            ),
        )
        assertEquals("阶段文字", withStageOnly.text)
        assertEquals("liveDisplaySummaryStageText", withStageOnly.key)
    }

    @Test
    fun `图标是第四项参与计数`() {
        // settings_shared.dart:151-153 `if (enableMiuiIslandLabelImage) parts.add(图标)`
        assertEquals(
            "简称·图标",
            SettingsLivePage.displaySummary(
                LiveDisplayInput(
                    showCourseName = true,
                    showLocation = false,
                    showCountdown = false,
                    showStageText = false,
                    enableMiuiIslandLabelImage = true,
                ),
            ).text,
        )
    }

    @Test
    fun `课中下课跟随上课前时摘要就是跟随文案`() {
        // settings_live.dart:65-67
        val during = page(LivePageData(duringEndFollowBeforeClass = true)).row("live.duringEndDisplay")
        assertEquals("followBeforeClassSetting", during.valueKey)
        assertEquals("跟随上课前提醒", during.value)
    }

    @Test
    fun `课中下课不跟随时用自己那一份摘要`() {
        // settings_live.dart:67 的 else 分支
        val data = LivePageData(
            duringEndFollowBeforeClass = false,
            duringEnd = LiveDisplayInput(
                showCourseName = false,
                showLocation = false,
                showCountdown = false,
                showStageText = false,
            ),
        )
        val during = page(data).row("live.duringEndDisplay")
        assertEquals("最简显示", during.value)
        assertEquals("liveDisplaySummaryMinimal", during.valueKey)
    }

    @Test
    fun `上课前行摘要随状态走`() {
        val data = LivePageData(
            beforeClass = LiveDisplayInput(
                showCourseName = true,
                showLocation = false,
                showCountdown = false,
                showStageText = false,
            ),
        )
        assertEquals("简称", page(data).row("live.beforeClassDisplay").value)
    }

    // ======================================================= 自检页（:168-1186）

    @Test
    fun `自检页标题取自 liveSelfCheckTitle`() {
        // settings_live.dart:642-644
        val spec = selfCheck()
        assertEquals("settings-live-self-check", spec.id)
        assertEquals("liveSelfCheckTitle", spec.titleKey)
        assertEquals("自检", spec.title)
    }

    @Test
    fun `自检页区块顺序在调试数据未就绪时不含九块调试卡`() {
        // settings_live.dart:671-690：!kReleaseMode 的假期覆盖 → 测试通知 → 上岛状态 →
        // 时间校正 →（debugStatus == null 时九块调试卡全部跳过）→ 本地日志
        assertEquals(
            listOf(
                "liveSelfCheck.section.holidayOverride",
                "liveSelfCheck.group.holidayOverride",
                "liveSelfCheck.gap.holidayOverride",
                "liveSelfCheck.card.notification",
                "liveSelfCheck.gap.notification",
                "liveSelfCheck.card.islandStatus",
                "liveSelfCheck.desc.serviceStatus",
                "liveSelfCheck.label.noIslandReason",
                "liveSelfCheck.desc.noIslandReason",
                "liveSelfCheck.group.islandStatus",
                "liveSelfCheck.desc.refreshedAt",
                "liveSelfCheck.gap.islandStatus",
                "liveSelfCheck.section.timeCorrection",
                "liveSelfCheck.group.timeCorrection",
                "liveSelfCheck.gap.timeCorrection",
                "liveSelfCheck.card.localLogs",
            ),
            selfCheck().topLevelIds(),
        )
    }

    @Test
    fun `正式版隐藏假期覆盖区块`() {
        // settings_live.dart:672 `if (!kReleaseMode) _LiveTestingSection.holidayOverride`
        val ids = selfCheck(LiveSelfCheckData(isReleaseBuild = true)).topLevelIds()
        assertFalse(ids.contains("liveSelfCheck.section.holidayOverride"))
        assertFalse(ids.contains("liveSelfCheck.group.holidayOverride"))
        assertFalse(ids.contains("liveSelfCheck.gap.holidayOverride"))
        // 其余区块照旧
        assertEquals("liveSelfCheck.card.notification", ids.first())
    }

    @Test
    fun `假期覆盖开关的标题与副标题随开关态翻转`() {
        // settings_live.dart:720-732：开 → Enabled / EnabledDesc；关 → Disabled / OverridePurpose
        val on = selfCheck(LiveSelfCheckData(holidayOverrideEnabled = true))
            .row("liveSelfCheck.holidaySwitch")
        assertEquals("liveTestingHolidayModeEnabled", on.titleKey)
        assertEquals("假期模式已开启", on.title)
        assertEquals("liveTestingHolidayModeEnabledDesc", on.subtitleKey)
        assertEquals("课程提醒和小组件将隐藏所有课程", on.subtitle)
        assertEquals(true, on.switchValue)
        val off = selfCheck(LiveSelfCheckData(holidayOverrideEnabled = false))
            .row("liveSelfCheck.holidaySwitch")
        assertEquals("liveTestingHolidayModeDisabled", off.titleKey)
        assertEquals("假期模式已关闭", off.title)
        assertEquals("liveTestingHolidayOverridePurpose", off.subtitleKey)
        assertEquals(false, off.switchValue)
        assertEquals(SettingsAction.WRITE_SETTING, off.action)
    }

    @Test
    fun `假期覆盖区块的小标题文案`() {
        // settings_live.dart:717
        val label = selfCheck().flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "liveSelfCheck.section.holidayOverride" }
        assertEquals("liveTestingHolidayOverride", label.textKey)
        assertEquals("假期状态覆盖", label.text)
    }

    @Test
    fun `测试通知卡头的文案`() {
        // settings_live.dart:749-751
        val card = selfCheck(LiveSelfCheckData(isReleaseBuild = true))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.notification" }
        assertEquals(InlineKind.CONTROL_CARD, card.kind)
        assertEquals("liveTestingNotificationTitle", card.labelKey)
        assertEquals("测试通知", card.label)
        assertEquals("liveTestingNotificationSubtitle", card.valueKey)
        assertEquals("验证超级岛与通知栏的显示效果", card.value)
    }

    @Test
    fun `测试通知卡的按钮按 Dart 自上而下顺序排列`() {
        // settings_live.dart:760-822：开始/取消测试 → if 课中测试芯片 + 停止测试
        //   → 选课测试 → if !release 崩溃 + 卡顿
        val idle = selfCheck(LiveSelfCheckData(isReleaseBuild = true, sessionActive = false))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.notification" }
        assertEquals(
            listOf("liveTestingStartAction", "liveTestingCourseTestAction"),
            idle.texts.map { it.key },
        )
        assertEquals(listOf("开始测试", "选课测试"), idle.texts.map { it.text })
    }

    @Test
    fun `自检测试进行中时按钮换成取消测试`() {
        // settings_live.dart:764-775 `sessionActive ? CancelAction : StartAction`
        val card = selfCheck(LiveSelfCheckData(isReleaseBuild = true, sessionActive = true))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.notification" }
        assertEquals("liveTestingCancelAction", card.texts.first().key)
        assertEquals("取消测试", card.texts.first().text)
    }

    @Test
    fun `课中测试进行中时停止测试排在选课测试之前`() {
        // settings_live.dart:786-795（停止测试）在 :796-803（选课测试）之前
        val card = selfCheck(LiveSelfCheckData(isReleaseBuild = true, courseTestLabel = "高等数学"))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.notification" }
        assertEquals(
            listOf(
                "liveTestingStartAction",
                "liveTestingCourseTestStopAction",
                "liveTestingCourseTestAction",
            ),
            card.texts.map { it.key },
        )
        assertEquals("停止测试", card.texts[1].text)
    }

    @Test
    fun `调试版多出崩溃与异常卡顿两个按钮`() {
        // settings_live.dart:804-823 `if (!kReleaseMode)`
        val debugCard = selfCheck(LiveSelfCheckData(isReleaseBuild = false))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.notification" }
        assertEquals(
            listOf(
                "liveTestingStartAction",
                "liveTestingCourseTestAction",
                "liveTestingCrashAction",
                "liveTestingAnrAction",
            ),
            debugCard.texts.map { it.key },
        )
        assertEquals(listOf("崩溃测试", "异常卡顿测试"), debugCard.texts.takeLast(2).map { it.text })
    }

    @Test
    fun `自检测试进行中的芯片只在会话活跃时出现`() {
        // settings_live.dart:756-763
        assertFalse(
            selfCheck().flattenedIds().contains("liveSelfCheck.desc.sessionRunning"),
        )
        val chip = selfCheck(LiveSelfCheckData(sessionActive = true))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.sessionRunning" }
        assertEquals("liveTestingSessionRunning", chip.textKey)
        assertEquals("自检测试进行中", chip.text)
        // 芯片在卡之前（Dart 里在卡内、按钮之上）
        val ids = selfCheck(LiveSelfCheckData(sessionActive = true)).topLevelIds()
        assertTrue(
            ids.indexOf("liveSelfCheck.desc.sessionRunning") < ids.indexOf("liveSelfCheck.card.notification"),
        )
    }

    @Test
    fun `课中测试芯片只在有测试课程时出现`() {
        // settings_live.dart:777-785 `if (_courseTestLabel != null)`
        val chip = selfCheck(LiveSelfCheckData(courseTestLabel = "高等数学"))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.courseTestChip" }
        assertEquals("liveTestingCourseTestActiveChip", chip.textKey)
        assertEquals("选课测试中 · 高等数学", chip.text)
    }

    @Test
    fun `上岛状态卡片头与两个动作按钮`() {
        // settings_live.dart:847-848 卡头；:914-941 刷新诊断 / 导出并分享日志
        val card = selfCheck().flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.islandStatus" }
        assertEquals("liveTestingIslandStatusTitle", card.labelKey)
        assertEquals("上岛状态诊断", card.label)
        // 副标题刻意删掉了（:849 注释），模型里也没有
        assertNull(card.value)
        assertEquals(listOf("刷新诊断", "导出并分享日志"), card.texts.map { it.text })
    }

    @Test
    fun `刷新按钮在加载中显示刷新中`() {
        // settings_live.dart:919-928：label = loading ? Refreshing : RefreshAction
        val busy = selfCheck(LiveSelfCheckData(loadingDebugStatus = true))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.islandStatus" }
        assertEquals("liveTestingRefreshing", busy.texts.first().key)
        assertEquals("刷新中", busy.texts.first().text)
        val idle = selfCheck(LiveSelfCheckData(loadingDebugStatus = false))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.islandStatus" }
        assertEquals("liveTestingRefreshAction", idle.texts.first().key)
        assertEquals("刷新诊断", idle.texts.first().text)
    }

    @Test
    fun `导出按钮在导出中显示导出中`() {
        // settings_live.dart:930-939
        val card = selfCheck(LiveSelfCheckData(exportingDiagnostics = true))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.islandStatus" }
        assertEquals("liveTestingExporting", card.texts[1].key)
        assertEquals("导出中", card.texts[1].text)
    }

    @Test
    fun `学期未填时多出一行提示且排在卡之后`() {
        // settings_live.dart:860-870
        val ids = selfCheck(LiveSelfCheckData(semesterUnset = true)).topLevelIds()
        assertTrue(
            ids.indexOf("liveSelfCheck.card.islandStatus") < ids.indexOf("liveSelfCheck.desc.semester"),
        )
        assertTrue(
            ids.indexOf("liveSelfCheck.desc.semester") < ids.indexOf("liveSelfCheck.desc.serviceStatus"),
        )
        val desc = selfCheck(LiveSelfCheckData(semesterUnset = true))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.semester" }
        assertEquals("pleaseSetSemesterStartDate", desc.textKey)
        assertEquals("请先在课表设置里填写开学日期", desc.text)
    }

    @Test
    fun `学期已填时没有那句提示`() {
        assertFalse(
            selfCheck().flattenedIds().contains("liveSelfCheck.desc.semester"),
        )
    }

    @Test
    fun `服务状态行两种文案`() {
        // settings_live.dart:875-885
        val running = selfCheck(LiveSelfCheckData(serviceRunning = true))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.serviceStatus" }
        assertEquals("liveTestingServiceStatusRunning", running.textKey)
        assertEquals("服务运行中", running.text)
        val stopped = selfCheck(LiveSelfCheckData(serviceRunning = false))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.serviceStatus" }
        assertEquals("liveTestingServiceStatusStopped", stopped.textKey)
        assertEquals("服务未运行", stopped.text)
    }

    @Test
    fun `上岛判定芯片只在原生给了文案时出现`() {
        // settings_live.dart:886-895：第二颗芯片的 label 是原生 statusText
        assertFalse(selfCheck().flattenedIds().contains("liveSelfCheck.desc.promotableStatus"))
        val chip = selfCheck(LiveSelfCheckData(statusText = "可上岛"))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.promotableStatus" }
        assertEquals("可上岛", chip.text)
        // 原生文案，不来自 ARB
        assertEquals(NON_ARB_TEXT, chip.textKey)
    }

    @Test
    fun `不上岛原因的小标题与三档正文`() {
        // settings_live.dart:898-912
        val label = selfCheck().flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "liveSelfCheck.label.noIslandReason" }
        assertEquals("liveTestingNoIslandReasonTitle", label.textKey)
        assertEquals("不上岛原因", label.text)

        // 假期优先于一切（holidayBlocksIsland）
        val holiday = selfCheck(LiveSelfCheckData(holidayBlocksIsland = true, notIslandReason = "周次不对"))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.noIslandReason" }
        assertEquals("liveTestingHolidayHidden", holiday.textKey)
        assertEquals("当前处于假期范围，超级岛在假期期间不显示", holiday.text)

        val empty = selfCheck(LiveSelfCheckData(notIslandReason = ""))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.noIslandReason" }
        assertEquals("liveTestingNoIslandReasonEmpty", empty.textKey)
        assertEquals("当前无拦截原因", empty.text)

        val raw = selfCheck(LiveSelfCheckData(notIslandReason = "周次不对"))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.noIslandReason" }
        assertEquals("周次不对", raw.text)
        // 原生文案，不来自 ARB
        assertEquals(NON_ARB_TEXT, raw.textKey)
    }

    @Test
    fun `自动刷新开关的副标题随开关态翻转`() {
        // settings_live.dart:956-962
        val on = selfCheck(LiveSelfCheckData(autoRefreshEnabled = true, autoRefreshIntervalSeconds = 1))
            .row("liveSelfCheck.island.autoRefresh")
        assertEquals("自动刷新", on.title)
        assertEquals("liveTestingAutoRefreshOn", on.subtitleKey)
        assertEquals("每 1 秒自动拉取一次诊断状态", on.subtitle)
        assertEquals(true, on.switchValue)
        val off = selfCheck(LiveSelfCheckData(autoRefreshEnabled = false))
            .row("liveSelfCheck.island.autoRefresh")
        assertEquals("liveTestingAutoRefreshOffReason", off.subtitleKey)
        assertEquals("便于稳定查看当前状态", off.subtitle)
        assertEquals(false, off.switchValue)
    }

    @Test
    fun `自动刷新间隔读数随配置走`() {
        // settings_live.dart:178 `_autoRefreshInterval = Duration(seconds: 1)`
        assertEquals(
            "每 5 秒自动拉取一次诊断状态",
            selfCheck(LiveSelfCheckData(autoRefreshIntervalSeconds = 5))
                .row("liveSelfCheck.island.autoRefresh").subtitle,
        )
    }

    @Test
    fun `上岛状态组里只有自动刷新开关`() {
        // 其余内容都在卡与整宽文案里，组内只有一个 HyperosSwitchTile（:946-964）
        assertEquals(
            listOf("liveSelfCheck.island.autoRefresh"),
            selfCheck().group("liveSelfCheck.group.islandStatus").childRowIds(),
        )
    }

    @Test
    fun `上次刷新两态`() {
        // settings_live.dart:637-640 + :972-975
        val never = selfCheck(LiveSelfCheckData(refreshedAtText = null))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.refreshedAt" }
        assertEquals("尚未刷新", never.text)
        assertEquals("liveTestingNotRefreshed", never.textKey)

        val done = selfCheck(LiveSelfCheckData(refreshedAtText = "12:34:56"))
            .flatten().filterIsInstance<SettingsDescription>()
            .single { it.id == "liveSelfCheck.desc.refreshedAt" }
        assertEquals("上次刷新：12:34:56", done.text)
        assertEquals("liveTestingRefreshedAt", done.textKey)
    }

    @Test
    fun `时间校正滑杆的上下限与档数`() {
        // settings_live.dart:995-1004：min -30 / max 30 / divisions 60
        val row = selfCheck().row("liveSelfCheck.timeCorrection")
        val slider = row.slider!!
        assertEquals(-30.0, slider.min, 0.0)
        assertEquals(30.0, slider.max, 0.0)
        assertEquals(60, slider.divisions)
        assertEquals(MiuixRowComponent.SLIDER, row.component)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
    }

    @Test
    fun `时间校正读数三档`() {
        // settings_live.dart:996-998 把 formatLiveTimeCorrection 的结果填进 timeCorrectionLabel；
        // settings_shared.dart:25-33 的三分支
        assertEquals(
            "铃声时间矫正：不矫正",
            selfCheck(LiveSelfCheckData(timeCorrectionSeconds = 0))
                .row("liveSelfCheck.timeCorrection").title,
        )
        assertEquals(
            "铃声时间矫正：整体延后 5 秒",
            selfCheck(LiveSelfCheckData(timeCorrectionSeconds = 5))
                .row("liveSelfCheck.timeCorrection").title,
        )
        assertEquals(
            "铃声时间矫正：整体提前 3 秒",
            selfCheck(LiveSelfCheckData(timeCorrectionSeconds = -3))
                .row("liveSelfCheck.timeCorrection").title,
        )
    }

    @Test
    fun `时间校正行标题的 ARB 模板是 timeCorrectionLabel`() {
        assertEquals(
            "timeCorrectionLabel",
            selfCheck().row("liveSelfCheck.timeCorrection").titleKey,
        )
    }

    @Test
    fun `时间校正区块小标题是 timeCorrectionTitle`() {
        // settings_live.dart:992
        val label = selfCheck().flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "liveSelfCheck.section.timeCorrection" }
        assertEquals("timeCorrectionTitle", label.textKey)
        assertEquals("铃声时间矫正", label.text)
    }

    @Test
    fun `时间校正行的滑杆值取当前秒数并夹在上下限内`() {
        // settings_live.dart:1001 `seconds.toDouble().clamp(-30, 30)`
        assertEquals(
            5.0,
            selfCheck(LiveSelfCheckData(timeCorrectionSeconds = 5))
                .row("liveSelfCheck.timeCorrection").sliderValue!!,
            0.0,
        )
        assertEquals(
            -30.0,
            selfCheck(LiveSelfCheckData(timeCorrectionSeconds = -99))
                .row("liveSelfCheck.timeCorrection").sliderValue!!,
            0.0,
        )
        assertEquals(
            30.0,
            selfCheck(LiveSelfCheckData(timeCorrectionSeconds = 99))
                .row("liveSelfCheck.timeCorrection").sliderValue!!,
            0.0,
        )
    }

    // -------------------------------------------------- 九块原生诊断卡（:671-690）

    @Test
    fun `调试数据就绪后按固定顺序插入八块数据卡加原始 JSON`() {
        // settings_live.dart:678-686：八个数据卡，每块 = 标题 + 数据行 + 段后空档；
        // :687 的 rawJson 是折叠卡（也算一张卡）；:689 的本地日志卡排最后且没有段后空档。
        val ids = selfCheck(everythingLoaded()).topLevelIds()
        val debugPart = ids.subList(
            ids.indexOf("liveSelfCheck.section.debugEnvironment"),
            ids.indexOf("liveSelfCheck.card.localLogs"),
        )
        val expected = mutableListOf<String>()
        listOf(
            "Environment",
            "Service",
            "Course",
            "Timing",
            "Switches",
            "Display",
            "Notification",
            "RecentLogs",
        ).forEach { suffix ->
            expected += "liveSelfCheck.section.debug$suffix"
            expected += "liveSelfCheck.group.debug$suffix"
            expected += "liveSelfCheck.gap.debug$suffix"
        }
        expected += "liveSelfCheck.card.rawJson"
        expected += "liveSelfCheck.gap.rawJson"
        assertEquals(expected, debugPart)
        assertEquals("liveSelfCheck.card.localLogs", ids.last())
    }

    @Test
    fun `九块调试卡排在时间校正之后 本地日志之前`() {
        // settings_live.dart:677-689 的插入位置
        val ids = selfCheck(everythingLoaded()).topLevelIds()
        val timeCorrection = ids.indexOf("liveSelfCheck.group.timeCorrection")
        val firstDebug = ids.indexOf("liveSelfCheck.section.debugEnvironment")
        val localLogs = ids.indexOf("liveSelfCheck.card.localLogs")
        assertTrue("时间校正应在调试卡之前", timeCorrection < firstDebug)
        assertTrue("本地日志应在调试卡之后", firstDebug < localLogs)
    }

    @Test
    fun `调试数据未就绪时九块一个都不出现`() {
        val ids = selfCheck(LiveSelfCheckData(debugLoaded = false)).topLevelIds()
        assertFalse(ids.any { it.contains(".debug") })
        assertFalse(ids.contains("liveSelfCheck.card.rawJson"))
        assertFalse(ids.contains("liveSelfCheck.gap.rawJson"))
    }

    @Test
    fun `八块诊断卡的标题文案与顺序`() {
        // settings_live.dart:1041-1114
        val page = selfCheck(everythingLoaded())
        val labels = LiveDebugSection.entries.map { section ->
            page.flatten().filterIsInstance<SettingsLabel>()
                .single { it.id == "liveSelfCheck.section.debug" + camel(section.name) }
        }
        assertEquals(
            listOf(
                "liveTestingSectionEnvironment",
                "liveTestingSectionService",
                "liveTestingSectionCourse",
                "liveTestingSectionTiming",
                "liveTestingSectionSwitches",
                "liveTestingSectionDisplay",
                "liveTestingSectionNotification",
                "liveTestingSectionRecentLogs",
            ),
            labels.map { it.textKey },
        )
        assertEquals(
            listOf(
                "环境与权限",
                "服务状态",
                "课程数据",
                "时间与阶段",
                "阶段开关",
                "岛显示配置",
                "通知判定结果",
                "最近诊断日志",
            ),
            labels.map { it.text },
        )
    }

    @Test
    fun `诊断卡的数据行按原生字段名逐条列出`() {
        // settings_live.dart:1274-1285：`data.entries.map(_DebugValueRow)`
        val data = LiveSelfCheckData(
            debugLoaded = true,
            debugSections = mapOf(
                LiveDebugSection.ENVIRONMENT to listOf(
                    LiveDebugRow("androidSdk", "33"),
                    LiveDebugRow("permission", "granted"),
                ),
            ),
        )
        val rows = selfCheck(data).group("liveSelfCheck.group.debugEnvironment")
            .children.filterIsInstance<SettingsRow>()
        assertEquals(listOf("androidSdk", "permission"), rows.map { it.title })
        assertEquals(listOf("33", "granted"), rows.map { it.value })
        // 原生字段名不是 ARB 文案（:1214-1222 直接 toString），对拍时跳过
        rows.forEach { assertEquals(NON_ARB_TEXT, it.titleKey) }
    }

    @Test
    fun `诊断卡的空值显示为减号`() {
        // settings_live.dart:1278-1280 `isEmpty ? '-' : value`
        val data = LiveSelfCheckData(
            debugLoaded = true,
            debugSections = mapOf(LiveDebugSection.COURSE to listOf(LiveDebugRow("courseName", ""))),
        )
        assertEquals(
            "-",
            selfCheck(data).group("liveSelfCheck.group.debugCourse")
                .children.filterIsInstance<SettingsRow>().single().value,
        )
    }

    @Test
    fun `诊断卡的行都不可点`() {
        // settings_live.dart:1290-1325 `_DebugValueRow` 是纯展示 Row，没有 onTap
        val page = selfCheck(everythingLoaded())
        LiveDebugSection.entries.forEach { section ->
            page.group("liveSelfCheck.group.debug" + camel(section.name))
                .children.filterIsInstance<SettingsRow>()
                .forEach {
                    assertNull("诊断行 ${it.id} 不该有动作", it.action)
                    assertFalse("诊断行 ${it.id} 不该可点", it.enabled)
                }
        }
    }

    @Test
    fun `原始 JSON 折叠卡的两句文案`() {
        // settings_live.dart:1119-1145
        val card = selfCheck(everythingLoaded().copy(rawDebugJson = "{\"a\":1}"))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.rawJson" }
        assertEquals("liveTestingExpandRawJson", card.labelKey)
        assertEquals("展开原始 JSON", card.label)
        assertEquals("liveTestingExpandRawJsonSubtitle", card.valueKey)
        assertEquals("避免大段原始字段一直占满页面", card.value)
        // 折叠内容是运行时 JSON，不是 ARB
        assertEquals(listOf("{\"a\":1}"), card.texts.map { it.text })
        assertEquals(listOf(NON_ARB_TEXT), card.texts.map { it.key })
    }

    @Test
    fun `本地日志卡三个按钮`() {
        // settings_live.dart:1149-1182
        val card = selfCheck().flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.localLogs" }
        assertEquals("liveTestingLocalLogsTitle", card.labelKey)
        assertEquals("本地诊断日志", card.label)
        assertEquals(
            listOf("清空日志", "查看手机日志", "更多测试者选项"),
            card.texts.map { it.text },
        )
        // 卡头副标题在 Dart 里被删了（:1151 注释：文案与实际不符）
        assertNull(card.value)
    }

    @Test
    fun `清空日志按钮在清空中显示清空中`() {
        // settings_live.dart:1158-1163
        val card = selfCheck(LiveSelfCheckData(clearingDiagnostics = true))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "liveSelfCheck.card.localLogs" }
        assertEquals("liveTestingClearingLogs", card.texts.first().key)
        assertEquals("清空中", card.texts.first().text)
    }

    // ------------------------------------------------------------------ 工具

    private fun camel(name: String): String =
        name.lowercase().split('_').joinToString("") { part ->
            part.replaceFirstChar { it.uppercase() }
        }

    @Test
    fun `两个真实路由名与 Dart 一致`() {
        // settings_live.dart:154-158 与 debug_deep_link_route_registry.dart:70
        assertEquals("/settings/live/self-check", SettingsLiveSelfCheckPage.ROUTE_SELF_CHECK)
        assertEquals("/settings/live/keep-alive", SettingsLiveSelfCheckPage.ROUTE_KEEP_ALIVE)
    }
}
