package com.mutx163.qingyu.pages.topbar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 顶栏「右上动作键」玻璃圆底守卫（2026-11-05，2026-11-05 加固）。
 *
 * ## 为什么要有这条守卫
 *
 * 左上返回键早在 `QingyuPageScaffold.kt` 里收成了共享件 `QingyuGlassIconButton`
 * （44dp 圆底 + 细边 + 小外浮影 + 磨砂玻璃），右上动作键却各页自绘裸 `IconButton`。
 * 用户实报「右上角的按钮也要套上和返回键一样的玻璃效果和阴影」——两个槽同属一套 chrome，
 * 却只统一了一个。本轮把顶栏 `actions` 槽逐页换成共享件；这条守卫钉住「不许再漂回去」。
 *
 * ## 判据（每条都配过咬合探针，见 `docs` 记录）
 *
 * 1. **不许裸写（两个槽都算）**：顶栏 `actions` 与 `navigationIcon` 槽里出现裸 `IconButton(`
 *    的文件，必须且在 `pending` / `pendingNavigation` 里；
 * 2. **已迁移批次逐颗对齐**：文件级「颗数 + 图标语义 + 无障碍文案」三样一起钉
 *    —— 只钉颗数会漏掉「把 `Ok` 改成 `Delete`」「把 `contentDescription` 改成 `null`」
 *    这类假绿；
 * 3. **pending 颗数精确**：多一颗、少一颗都红（不是只判「有没有」）；
 * 4. **import 必须真在**：用了共享件却没 import 的写法不放过；
 * 5. **门控不许被拆**：共享件必须按 `LocalQingyuBackButtonGlass` 门控（内容压到顶栏带下才出圆底），
 *    右上动作键与左上返回键同一个信号——用户口径就是「和返回键一样」；
 * 6. **返回键槽也要收口**：`navigationIcon` 里应写 `QingyuBackIconButton(onBack = …)`，
 *    不许再手写 `IconButton { Icon(ChevronBackward) }`——2026-11-05 复核指出的漂移洞
 *    （只扫 `actions` 时，7 页手拼顶栏的返回键脱离开关却没人拦）；
 * 7. **门控只许骨架注入**：`LocalQingyuBackButtonGlass` 只能由 `QingyuPageScaffold` provide，
 *    页面不得自己 `provides true`——手拼顶栏的页现在「左上右上都是裸图标」是一致的，
 *    谁为了「让圆底出来」手动注入，会突然长出恒显圆底（形态从裸图标变成白圆点），
 *    那是新的观感变化，不是这次的目的。
 *
 * ## 只扫「顶栏的动作槽」，不是全文件的 `actions`
 *
 * 判据不是「文件里出现过 `actions = {`」——那样会把任何带 `actions` 参数的组件
 * （卡片、弹层、自定义控件）一起扫进来，日后必然误报。这里先定位**顶栏调用**
 * （`QingyuPageScaffold` / `TopAppBar` / `SmallTopAppBar`），再只在它的**顶层具名参数**
 * 里找 `actions = { … }`（嵌套在 lambda 里的同名参数不算）。
 *
 * ## 白名单（不算违规）
 *
 * 1. `pages/showcase/`：官方 demo 展示页，展示的是 miuix 原始控件，不进本规则；
 * 2. **文字按钮**（`TextButton`，如作息方案编辑 / 地点作息编组的「保存」）：套 44dp 圆底会把
 *    中文压成图标，形态错误，保持文字；
 * 3. **非图标控件的自绘 chrome**（如外观编辑页顶部两颗 84×40 胶囊 `CapsuleButton`）。
 *
 * 这三类都不需要额外放行表——规则只按「顶栏动作槽里的 `IconButton(`」判，其余写法自动通过。
 *
 * ## 过期必红
 *
 * `pending` 是**待办清单，不是豁免记录**：文件迁完之后必须删掉对应行；颗数变了也要同步。
 * 不许只进不出。
 */
class TopBarActionGlassGuardTest {

    /**
     * 一颗动作键该长什么样。
     *
     * 两种形态：
     * - **图标键**：[icon] 非空，钉图标语义 + 无障碍文案；
     * - **内容槽键**（加载中 / 导出中换转圈的）：`icon = null`，只钉无障碍文案，不要求图标
     *   （那种键按下时画的是转圈，`icon` 参数只是共享件的必填位，钉它没有意义）。
     */
    data class ExpectedAction(
        val icon: String?,
        val contentDescription: String,
        val usesContentSlot: Boolean = icon == null,
    ) {
        override fun toString(): String =
            if (usesContentSlot) "(内容槽) / $contentDescription" else "$icon / $contentDescription"
    }

    /**
     * 已完成批次：文件 → **按源码顺序**的每一颗动作键。
     *
     * 为什么逐颗钉：文件级合计计数对「同文件删一颗、别处加一颗」是瞎的；
     * 图标名与无障碍文案对「换成别的图标」「`contentDescription = null`」也是瞎的
     * （2026-11-05 成员三 复核抓到的假绿点）。
     */
    private val expectedActions: Map<String, List<ExpectedAction>> = mapOf(
        "pages/course/AddCoursePage.kt" to listOf(
            ExpectedAction("MiuixIcons.Delete", "AddCourseStrings.deleteAction.text"),
            ExpectedAction("MiuixIcons.Ok", "AddCourseStrings.saveAction.text"),
        ),
        "pages/course/CourseOverviewPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Sort", "CourseOverviewStrings.sortAction.text"),
            ExpectedAction("MiuixIcons.Add", "CourseOverviewStrings.addNewCourseTooltip.text"),
        ),
        "pages/diagnostics/LiveDiagnosticsLogPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Tune", "DiagnosticsStrings.diagnosticsDisplayOptionsTitle.text"),
            ExpectedAction("MiuixIcons.Copy", "DiagnosticsStrings.appLogsCopyAction.text"),
            // 导出中换成转圈 ⇒ 内容槽；只钉文案。
            ExpectedAction(null, "DiagnosticsStrings.appLogsExportAction.text"),
            // 清空中换成转圈 ⇒ 内容槽；只钉文案。
            ExpectedAction(null, "DiagnosticsStrings.appLogsClearAction.text"),
        ),
        "pages/diagnostics/MemoryStatsPage.kt" to listOf(
            // 加载中换成转圈 ⇒ 内容槽；只钉文案。
            ExpectedAction(null, "MemoryStatsStrings.refreshTooltip"),
            ExpectedAction("MiuixIcons.Copy", "MemoryStatsStrings.copyJsonTooltip"),
        ),
        "pages/diagnostics/PerfReportPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Refresh", "PerfReportStrings.refreshTooltip"),
            ExpectedAction("MiuixIcons.Download", "PerfReportStrings.exportTooltip"),
        ),
        "pages/exam/AddExamPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Delete", "ExamStrings.deleteExam.text"),
            ExpectedAction("MiuixIcons.Ok", "ExamStrings.saveExam.text"),
        ),
        "pages/schedule/AddScheduleItemPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Delete", "ScheduleStrings.deleteAction.text"),
            ExpectedAction("MiuixIcons.Ok", "ScheduleStrings.saveAction.text"),
        ),
        "pages/schedule/ScheduleDateRulePage.kt" to listOf(
            ExpectedAction("MiuixIcons.Add", "ScheduleStrings.scheduleDateRuleAdd.text"),
        ),
        "pages/schedule/ScheduleListPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Add", "ScheduleStrings.addScheduleAction.text"),
        ),
        "pages/task/AddTaskPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Delete", "TaskStrings.taskDelete"),
            ExpectedAction("MiuixIcons.Ok", "TaskStrings.saveTask"),
        ),
        "pages/task/TaskListPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Add", "TaskStrings.addTask"),
        ),
        "pages/timetable/TimetableProfilesPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Add", "TimetableStrings.createTimetableTooltip.text"),
        ),
        "pages/time_scheme/LocationTimeMatchPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Add", "model.createGroupLabel"),
        ),
        "pages/time_scheme/TimeSchemeManagementPage.kt" to listOf(
            ExpectedAction("MiuixIcons.Add", "model.newSchemeTooltip"),
        ),
    )

    /**
     * 自定义顶栏区的页面（没有 `TopAppBar(` / `QingyuPageScaffold(` 的 actions 槽，顶栏由页面自己
     * 组合）：顶栏玻璃钮按**全文件**的 `QingyuGlassIconButton(` 清单钉，不走顶栏槽扫描。
     *
     * `AboutUpdatePage`（2026-11-08 起）：整页是渐变底 + 自绘 Row 顶栏，右上只留一颗 Tune 钮
     * （左上是 [QingyuBackIconButton]，那是「返回」公共件、不是动作键）。
     * 别把这类文件再塞回 [expectedActions]：`scan` 只认顶栏槽，这页没有槽，钉成「无槽」别扭。
     */
    private val customTopZonePinned: Map<String, List<ExpectedAction>> = mapOf(
        "pages/about/AboutUpdatePage.kt" to listOf(
            ExpectedAction("MiuixIcons.Tune", "AboutUpdatePageStrings.advancedOptionsTitle"),
        ),
    )

    /**
     * 待迁移：文件 → **允许保留的裸 `IconButton` 颗数**（精确值，不是「>0 就行」）。
     *
     * 迁移条件清掉后**必须删掉对应行**；颗数变了必须同步改数字（过期必红）。
     */
    private val pending: Map<String, Int> = mapOf(
        // 别的成员正在改这些文件：落完再换。
        "pages/exam/ExamListPage.kt" to 1,
        "pages/statistics/CourseStatisticsPage.kt" to 2,
        "pages/settings/SettingsPageRenderers.kt" to 1,
        "pages/settings/BingGalleryHost.kt" to 1,
        // 导入域（教务仓库）多人并行，先不碰。
        "pages/import/warehouse/WarehouseCourseImportPage.kt" to 1,
        "pages/import/warehouse/WarehouseCustomDebugPage.kt" to 1,
        "pages/import/warehouse/WarehouseSchoolAdaptersPage.kt" to 1,
        "pages/import/warehouse/WarehouseWebLoginPage.kt" to 4,
    )

    /**
     * 待迁移（**返回键槽**）：文件 → 允许保留的裸 `IconButton` 颗数。
     *
     * 这些是手拼 `TopAppBar` 的页：`navigationIcon` 里写的是裸
     * `IconButton { Icon(MiuixIcons.ChevronBackward) }`。现在没换是因为换过去在门控为
     * `false` 时渲染结果完全一样（视觉零收益），真正该做的是随「迁到共享骨架」一起拿到
     * 采样源（成员七 的 B 组迁移批）。**在那之前不许再加新的裸返回键**，也不许只进不出。
     */
    private val pendingNavigation: Map<String, Int> = mapOf(
        // 2026-11-05 批 1 迁走 AddTaskPage / ScheduleDateRulePage / TaskListPage；
        // 批 2 迁走 CourseOverviewPage / QrTransferScanPage / QrTransferSendPage；
        // 批 3 迁走 ScheduleListPage；课程表单批迁走 AddCoursePage。
        // 余下两页等外观批统一换 QingyuBackIconButton（AddScheduleItemPage 与 TimetableProfilesPage）。
        "pages/schedule/AddScheduleItemPage.kt" to 1,
        "pages/timetable/TimetableProfilesPage.kt" to 1,
        // 同样是手拼顶栏的页（不属这批，先登记以免新漂移没人看见）。
        "pages/transfer/LanEditPage.kt" to 1,
    )

    // ── 判据 ────────────────────────────────────────────────────────────

    @Test
    fun `顶栏 actions 里不许裸写 IconButton`() {
        val offenders = scan()
            .filter { it.value.bareInActions > 0 && it.key !in pending }
            .map { "${it.key}（${it.value.bareInActions} 颗裸 IconButton）" }
        assertTrue(
            "顶栏 `actions` 槽里出现了裸 IconButton，必须换成共享玻璃圆底 " +
                "`QingyuGlassIconButton(onClick=, contentDescription=, icon=, tint=)`：\n" +
                offenders.joinToString("\n").ifEmpty { "(无)" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `已迁移批次逐颗钉图标与无障碍文案`() {
        val scanned = scan()
        val problems = mutableListOf<String>()
        expectedActions.forEach { (owner, expected) ->
            val found = scanned[owner]
            if (found == null) {
                problems += "$owner：文件里已经没有顶栏 `actions = {` 槽（改名/删页？确认后更新清单）"
                return@forEach
            }
            if (found.bareInActions > 0) {
                problems += "$owner：仍混着 ${found.bareInActions} 颗裸 IconButton"
            }
            // 比对用「格式化后的标签」：内容槽键按 (内容槽) 记，不跟图标名纠缠；
            // 这样单行写法 / 多行写法 / 参数顺序都不会影响判定（只钉语义）。
            val expectedLabels = expected.map { it.toString() }
            val actualLabels = found.actions.map { it.toString() }
            if (actualLabels != expectedLabels) {
                problems += "$owner：动作键对不上\n" +
                    "  期望：" + expectedLabels.joinToString("；") + "\n" +
                    "  实际：" + actualLabels.joinToString("；")
            }
        }
        // 自定义顶栏区的页面：按全文件玻璃钮清单钉（见 customTopZonePinned 的注释）。
        customTopZonePinned.forEach { (owner, expected) ->
            val code = codeOf(File(composeRoot(), owner).readText())
            val foundActions = glassActions(code)
            val bare = BARE_ICON_BUTTON.findAll(code).count()
            if (bare > 0) {
                problems += "$owner：仍混着 $bare 颗裸 IconButton（全文件口径）"
            }
            val expectedLabels = expected.map { it.toString() }
            val actualLabels = foundActions.map { it.toString() }
            if (actualLabels != expectedLabels) {
                problems += "$owner：顶栏玻璃钮对不上\n" +
                    "  期望：" + expectedLabels.joinToString("；") + "\n" +
                    "  实际：" + actualLabels.joinToString("；")
            }
        }
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }

    @Test
    fun `已迁移文件必须真的 import 共享件`() {
        val missing = (expectedActions.keys + customTopZonePinned.keys).filter { owner ->
            !File(composeRoot(), owner).readText()
                .contains("import com.mutx163.qingyu.components.QingyuGlassIconButton")
        }
        assertTrue(
            "这些文件用了 QingyuGlassIconButton 却没 import（或 import 被删）：\n" +
                missing.joinToString("\n"),
            missing.isEmpty(),
        )
    }

    @Test
    fun `共享件按门控出圆底 静止不画`() {
        val code = codeOf(File(composeRoot(), "components/QingyuPageScaffold.kt").readText())
        assertTrue(
            "顶栏图标按钮必须按 `LocalQingyuBackButtonGlass` 门控：静止停在页顶时不画圆底。" +
                "用户口径是「右上和返回键一样」，而发布版返回键只在内容压到顶栏带下时才出圆底。",
            code.contains("if (!LocalQingyuBackButtonGlass.current)"),
        )
        assertFalse(
            "门控被改成恒真（`LocalQingyuBackButtonGlass.current || true`）等于回到「静止也挂圆底」：" +
                "会与返回键分叉，也会在静止时采到不透明顶栏底、显出一圈脏雾。",
            Regex("""LocalQingyuBackButtonGlass\.current\s*\|\|\s*true""").containsMatchIn(code),
        )
        // 两个「补进来的能力」也要钉住：删掉就是静默丢功能（禁用态 / 加载转圈）。
        // ⚠️ 必须限定在**本函数的签名**里判：整文件搜 `enabled: Boolean = true` 会被
        // `rememberQingyuBlurBackdrop(..., enabled: Boolean = true)` 撞上，删了参数也照样绿（假绿）。
        val signature = functionSignature(code, "fun QingyuGlassIconButton(")
        assertTrue(
            "找不到 `fun QingyuGlassIconButton(` 的签名——断言无法验证，按失败处理。",
            signature.isNotEmpty(),
        )
        assertTrue(
            "共享件必须保留禁用态参数 `enabled: Boolean = true`：动作键有「没有数据时不可导出」" +
                "这类情形，删掉这个参数会让禁用态静默失效。实际签名：$signature",
            signature.contains("enabled: Boolean = true"),
        )
        assertTrue(
            "共享件必须保留内容槽 `content: (@Composable () -> Unit)? = null`：加载中 / 导出中" +
                "换成转圈要用它，删掉就只能回退成自绘 IconButton。实际签名：$signature",
            signature.contains("content: (@Composable () -> Unit)? = null"),
        )
    }

    /**
     * 裸图标分支（门控 `false` = **默认态**）必须透传调用方的 `modifier`。
     *
     * 2026-11-05 回归：裸图标分支一度只写 `Modifier.semantics { … }`，把调用方传进来的
     * `modifier` 静默丢掉——课程总览页的排序键靠它做 `onGloballyPositioned` 测锚点，丢了之后
     * 弹层锚点永远为 null、只能退到窗口右上角。这种丢失编译过、测试过、视觉上还「看着正常」。
     *
     * 判据盯**门控 if 块内部那颗 `IconButton` 的 `modifier` 实参**：必须以小写 `modifier.`
     * 开头（透传参数），且**不许**是 `Modifier…`（丢掉调用方）。只判「出现 modifier 这个词」
     * 抓不住——`Modifier.semantics { … }` 里也满是 modifier。
     */
    @Test
    fun `裸图标分支必须透传调用方 modifier`() {
        val code = codeOf(File(composeRoot(), "components/QingyuPageScaffold.kt").readText())
        val gateStart = code.indexOf(GATE_IF)
        assertTrue("共享件里找不到门控判据 `$GATE_IF`——断言无法验证，按失败处理。", gateStart >= 0)
        val gateBrace = code.indexOf('{', gateStart)
        val gateClose = if (gateBrace >= 0) matchingClose(code, gateBrace, '{', '}') else -1
        assertTrue("门控 if 块的花括号不配对。", gateClose > gateBrace && gateBrace >= 0)
        val gateBlock = code.substring(gateBrace, gateClose + 1)

        val callStart = gateBlock.indexOf("IconButton(")
        assertTrue("门控分支里找不到 `IconButton(` 调用。", callStart >= 0)
        val callParen = gateBlock.indexOf('(', callStart)
        val callParenClose = matchingClose(gateBlock, callParen, '(', ')')
        assertTrue("门控分支的 `IconButton(` 括号不配对。", callParenClose > callParen)
        val lambdaBrace = gateBlock.indexOf('{', callParenClose)
        val lambdaClose = if (lambdaBrace >= 0) matchingClose(gateBlock, lambdaBrace, '{', '}') else -1
        val callBlock = if (lambdaClose > lambdaBrace && lambdaBrace >= 0) {
            gateBlock.substring(callStart, lambdaClose + 1)
        } else {
            gateBlock.substring(callStart, callParenClose + 1)
        }

        assertTrue(
            "裸图标分支丢了调用方的 `modifier`：`IconButton` 的 modifier 实参必须以 `modifier.` " +
                "开头（透传参数），不能是 `Modifier…`。丢了之后，靠 modifier 测量/占位的调用方" +
                "（课程总览排序键的 `onGloballyPositioned`）会静默失效。实际调用块：\n$callBlock",
            Regex("""modifier\s*=\s*modifier\s*\.""").containsMatchIn(callBlock),
        )
        assertFalse(
            "裸图标分支的 modifier 实参写成了 `Modifier…`——调用方那个被丢掉了。实际调用块：\n$callBlock",
            Regex("""modifier\s*=\s*Modifier\b""").containsMatchIn(callBlock),
        )
    }

    /**
     * 圆底分支只许画一层玻璃圆底：不许再套官方 `IconButton`（2026-11-08 用户实报「双重圈圈」）。
     *
     * miuix `IconButton` 自带圆底容器（40dp squircle + 水波圈），把它塞进外层 44dp 玻璃圆底里
     * 会同心叠成两圈。圆底分支改成普通 clickable Box 承载图标，静止时只有外层那层玻璃圈。
     * 裸图标分支不受影响（仍用官方 `IconButton`，静止不画圈）。
     *
     * 咬合探针：把圆底分支的可点击 Box 改回 `IconButton(` → 本条变红；改回 Box → 变绿。
     */
    @Test
    fun `圆底分支不再套第二层图标容器`() {
        val code = codeOf(File(composeRoot(), "components/QingyuPageScaffold.kt").readText())
        val fnStart = code.indexOf("fun QingyuGlassIconButton(")
        assertTrue("找不到 `fun QingyuGlassIconButton(`——守卫无法验证，按失败处理。", fnStart >= 0)
        val fnOpen = code.indexOf('(', fnStart)
        val fnClose = matchingClose(code, fnOpen, '(', ')')
        assertTrue("`fun QingyuGlassIconButton(` 签名括号不配对。", fnClose > fnOpen)
        val fnBodyStart = code.indexOf('{', fnClose)
        val fnBodyClose = matchingClose(code, fnBodyStart, '{', '}')
        assertTrue("`QingyuGlassIconButton` 函数体花括号不配对。", fnBodyClose > fnBodyStart)
        val fnBody = code.substring(fnBodyStart, fnBodyClose + 1)
        val glassStart = fnBody.indexOf("val backdrop = LocalQingyuPageBackdrop.current")
        assertTrue("圆底分支的采样源取值不见了——守卫无法定位圆底分支，按失败处理。", glassStart >= 0)
        val glass = fnBody.substring(glassStart)
        assertFalse(
            "圆底分支里又出现了 `IconButton(`：官方图标按钮自带一层 40dp 圆底，塞进外层 " +
                "44dp 玻璃圆底里就是双重圆圈。圆底分支要换成普通可点击 Box 承载图标，" +
                "裸图标分支才用 IconButton。",
            glass.contains("IconButton("),
        )
        assertTrue(
            "圆底分支的可点击节点丢了无障碍文案（`contentDescription = label`）：图标容器换了，" +
                "但读屏标签不能跟着丢。",
            glass.contains("contentDescription = label"),
        )
        assertTrue(
            "圆底分支必须仍然是圆底：`.size(44.dp)` 与 `.clip(CircleShape)` 不在，就退化成裸图标，" +
                "与返回键分叉。实际圆底分支：\n$glass",
            glass.contains(".size(44.dp)") && glass.contains(".clip(CircleShape)"),
        )
    }

    /** 取某个函数声明的参数列表原文（从函数名到配对 `)`），把断言限定在这个函数自身。 */    private fun functionSignature(code: String, head: String): String {
        val start = code.indexOf(head)
        if (start < 0) return ""
        val open = code.indexOf('(', start)
        if (open < 0) return ""
        val close = matchingClose(code, open, '(', ')')
        return if (close < 0) "" else code.substring(start, close + 1)
    }

    @Test
    fun `顶栏 navigationIcon 里不许裸写 IconButton`() {
        val offenders = scan()
            .filter { it.value.bareInNavigation > 0 && it.key !in pendingNavigation }
            .map { "${it.key}（${it.value.bareInNavigation} 颗裸 IconButton）" }
        assertTrue(
            "顶栏 `navigationIcon` 槽里出现了裸 IconButton：返回键必须走共享件 " +
                "`QingyuBackIconButton(onBack = …)`（圆底门控与右上动作键同一个信号）。" +
                "手写 `IconButton { Icon(MiuixIcons.ChevronBackward) }` 会脱开那个开关：" +
                "骨架迁好之后左边永远没有圆底、右边却跟着内容压带长出来，两边分叉。\n" +
                offenders.joinToString("\n").ifEmpty { "(无)" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `navigationIcon 待迁移颗数必须精确`() {
        val scanned = scan()
        val problems = mutableListOf<String>()
        pendingNavigation.forEach { (owner, allowed) ->
            val found = scanned[owner]
            when {
                found == null || found.bareInNavigation == 0 ->
                    problems += "$owner：navigationIcon 里已经没有裸 IconButton（迁完或文件改名/删页）" +
                        "——请删掉 pendingNavigation 对应行，别只进不出"
                found.bareInNavigation > allowed ->
                    problems += "$owner：navigationIcon 的裸 IconButton 从 $allowed 颗变成 " +
                        "${found.bareInNavigation} 颗（又加了一颗没走共享件的返回键）"
                found.bareInNavigation < allowed ->
                    problems += "$owner：navigationIcon 的裸 IconButton 从 $allowed 颗减到 " +
                        "${found.bareInNavigation} 颗——换了几颗就把数字改小，全换完删行"
            }
        }
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }

    @Test
    fun `门控只许骨架注入 页面不得自己 provide`() {
        val allowed = "components/QingyuPageScaffold.kt"
        // 豁免：AboutUpdatePage 整页没有顶栏（自绘渐变底 + 自定义 Row），右上只留 Tune 一颗玻璃钮；
        // 左边返回键走公共件 QingyuBackIconButton，骨架那层 provides 不在它子树里，所以作者显式
        // provide true（页面注释写明：本页没有栏，显式置 true 让两边从一开始就是同一颗圆钮）。
        // 豁免只对「提供的值」豁免——这页的 Tune 键仍由 customTopZonePinned 逐颗钉住。
        val exempt = setOf("pages/about/AboutUpdatePage.kt")
        val offenders = mutableListOf<String>()
        composeRoot().walkTopDown()
            // 官方 demo 展示页不进本规则。
            .onEnter { !it.name.equals("showcase", ignoreCase = true) }
            .filter { it.isFile && it.extension == "kt" }
            .forEach { file ->
                val owner = file.relativeTo(composeRoot()).invariantSeparatorsPath
                if (owner == allowed || owner in exempt) return@forEach
                if (GATE_PROVIDES.containsMatchIn(codeOf(file.readText()))) {
                    offenders += owner
                }
            }
        assertTrue(
            "顶栏门控 `LocalQingyuBackButtonGlass` 只能由 `QingyuPageScaffold` 注入（它按栏型算" +
                "「内容是否压到顶栏带下」）。页面自己 `provides true` 会让手拼顶栏的页突然长出恒显圆底，" +
                "形态从裸图标变成白圆点——那是观感变化，不是本任务的目的。违规模块：\n" +
                offenders.joinToString("\n").ifEmpty { "(无)" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `pending 的裸键颗数必须精确`() {
        val scanned = scan()
        val problems = mutableListOf<String>()
        pending.forEach { (owner, allowed) ->
            val found = scanned[owner]
            when {
                found == null || found.bareInActions == 0 ->
                    problems += "$owner：已经没有任何裸 IconButton（迁完或文件改名/删页）" +
                        "——请删掉 pending 对应行，别只进不出"
                found.bareInActions > allowed ->
                    problems += "$owner：裸 IconButton 从 $allowed 颗变成 ${found.bareInActions} 颗" +
                        "（又加了一颗未玻璃化的动作键）"
                found.bareInActions < allowed ->
                    problems += "$owner：裸 IconButton 从 $allowed 颗减到 ${found.bareInActions} 颗" +
                        "——迁了几颗就把 pending 的数字改小，全迁完删行"
            }
        }
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }

    // ── 扫描器 ──────────────────────────────────────────────────────────

    /** 一个文件顶栏两个槽的扫描结果。 */
    data class Scanned(
        val bareInActions: Int,
        val actions: List<ExpectedAction>,
        val bareInNavigation: Int,
    )

    private fun scan(): Map<String, Scanned> {
        val root = composeRoot()
        val result = mutableMapOf<String, Scanned>()
        root.walkTopDown()
            // 官方 demo 展示页：展示 miuix 原始控件，不进本规则。
            .onEnter { !it.name.equals("showcase", ignoreCase = true) }
            .filter { it.isFile && it.extension == "kt" }
            .forEach { file ->
                val code = codeOf(file.readText())
                val actionBlocks = topBarSlotBlocks(code, Slot.ACTIONS)
                val navigationBlocks = topBarSlotBlocks(code, Slot.NAVIGATION)
                if (actionBlocks.isEmpty() && navigationBlocks.isEmpty()) return@forEach
                val bareActions = actionBlocks.sumOf { BARE_ICON_BUTTON.findAll(it).count() }
                val bareNavigation = navigationBlocks.sumOf { BARE_ICON_BUTTON.findAll(it).count() }
                val actions = actionBlocks.flatMap { glassActions(it) }
                if (bareActions > 0 || bareNavigation > 0 || actions.isNotEmpty()) {
                    val owner = file.relativeTo(root).invariantSeparatorsPath
                    result[owner] = Scanned(bareActions, actions, bareNavigation)
                }
            }
        return result
    }

    /** 顶栏里本守卫要看的两个槽。 */
    private enum class Slot(val argName: String) {
        ACTIONS("actions"),
        NAVIGATION("navigationIcon"),
    }

    /**
     * 取「顶栏调用」里指定槽的 lambda 块（`actions = { … }` / `navigationIcon = { … }`）。
     *
     * 先定位 `QingyuPageScaffold(` / `TopAppBar(` / `SmallTopAppBar(`，再在它的实参里、
     * **相对嵌套深度 0** 的位置找具名参数（`content` 等 lambda 里的同名参数不算），
     * 这样「卡片 / 弹层自带 `actions` 参数」不会被误判成顶栏槽。
     */
    private fun topBarSlotBlocks(code: String, slot: Slot): List<String> {
        val blocks = mutableListOf<String>()
        BAR_CALL.findAll(code).forEach { match ->
            val open = code.indexOf('(', match.range.first)
            if (open < 0) return@forEach
            val close = matchingClose(code, open, '(', ')')
            if (close < 0) return@forEach
            var paren = 0
            var brace = 0
            var bracket = 0
            var i = open + 1
            while (i < close) {
                when (code[i]) {
                    '(' -> paren++
                    ')' -> paren--
                    '{' -> brace++
                    '}' -> brace--
                    '[' -> bracket++
                    ']' -> bracket--
                    else -> if (paren == 0 && brace == 0 && bracket == 0 &&
                        code[i] == slot.argName[0] &&
                        isNamedArgStart(code, i, slot.argName)
                    ) {
                        val braceStart = lambdaBraceStart(code, i, slot.argName)
                        if (braceStart >= 0) {
                            val braceEnd = matchingClose(code, braceStart, '{', '}')
                            if (braceEnd in 0 until close) {
                                blocks += code.substring(braceStart, braceEnd + 1)
                                i = braceEnd
                            }
                        }
                    }
                }
                i++
            }
        }
        return blocks
    }

    /** `i` 处是否正好是具名参数 [name]（前一个字符不能是标识符字符）。 */
    private fun isNamedArgStart(code: String, i: Int, name: String): Boolean {
        if (!code.startsWith(name, i)) return false
        val before = if (i > 0) code[i - 1] else ' '
        if (before.isLetterOrDigit() || before == '_') return false
        val afterIdx = i + name.length
        val after = if (afterIdx < code.length) code[afterIdx] else ' '
        return after.isWhitespace() || after == '='
    }

    /** 从具名参数名往后跳过空白与 `=`，返回 `{` 的下标；不是 `<name> = {` 则 -1。 */
    private fun lambdaBraceStart(code: String, i: Int, name: String): Int {
        var j = i + name.length
        while (j < code.length && code[j].isWhitespace()) j++
        if (j >= code.length || code[j] != '=') return -1
        j++
        while (j < code.length && code[j].isWhitespace()) j++
        return if (j < code.length && code[j] == '{') j else -1
    }

    /** 从 [open]（开符号下标）找到配对的闭符号下标；找不到返回 -1。 */
    private fun matchingClose(code: String, open: Int, openChar: Char, closeChar: Char): Int {
        var depth = 0
        var i = open
        while (i < code.length) {
            when (code[i]) {
                openChar -> depth++
                closeChar -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    /**
     * 槽里每一颗共享玻璃圆底动作键的语义（图标 / 内容槽 + 无障碍文案）。
     *
     * **按参数列表解析，不依赖换行**：Kotlin 允许把调用写成一整行
     * （`QingyuGlassIconButton(onClick = ::x, icon = MiuixIcons.Add, contentDescription = S)`），
     * 也允许参数换顺序；逐行 `startsWith("icon =")` 那种解析会对它们假红，逼人为了过守卫改格式。
     *
     * **内容槽合法**：给了 `content = …` 或调用末尾跟 `{ … }` trailing lambda 时，
     * 画的是转圈而不是图标，这种键只要求有 `contentDescription`，不要求 `icon`。
     */
    private fun glassActions(block: String): List<ExpectedAction> {
        val actions = mutableListOf<ExpectedAction>()
        GLASS_ICON_BUTTON.findAll(block).forEach { match ->
            val open = block.indexOf('(', match.range.first)
            if (open < 0) return@forEach
            val close = matchingClose(block, open, '(', ')')
            if (close < 0) return@forEach
            val named = splitTopLevelArgs(block.substring(open + 1, close))
                .mapNotNull { arg ->
                    val eq = arg.indexOf('=')
                    if (eq <= 0) null else arg.substring(0, eq).trim() to arg.substring(eq + 1).trim()
                }
                .toMap()
            var cursor = close + 1
            while (cursor < block.length && block[cursor].isWhitespace()) cursor++
            val trailingLambda = cursor < block.length && block[cursor] == '{'
            val usesContentSlot = named.containsKey("content") || trailingLambda
            val description = named["contentDescription"]
                ?: "(没解析到 contentDescription= 参数)"
            if (usesContentSlot) {
                actions += ExpectedAction(icon = null, contentDescription = description)
            } else {
                actions += ExpectedAction(
                    icon = named["icon"] ?: "(既没有 icon= 也没有 content=)",
                    contentDescription = description,
                )
            }
        }
        return actions
    }

    /** 按顶层逗号切参数（括号 / 大括号 / 方括号 / 字符串里的逗号不切）。 */
    private fun splitTopLevelArgs(text: String): List<String> {
        val out = mutableListOf<String>()
        var depth = 0
        var start = 0
        var inString = false
        var i = 0
        while (i < text.length) {
            val c = text[i]
            when {
                inString -> when (c) {
                    '\\' -> i++
                    '"' -> inString = false
                }
                c == '"' -> inString = true
                c == '(' || c == '{' || c == '[' -> depth++
                c == ')' || c == '}' || c == ']' -> depth--
                c == ',' && depth == 0 -> {
                    out += text.substring(start, i)
                    start = i + 1
                }
            }
            i++
        }
        out += text.substring(start)
        return out.map { it.trim() }.filter { it.isNotEmpty() }
    }

    /** 去掉块注释与行注释再判：KDoc / 行内说明里提到的写法不能算违规。 */
    private fun codeOf(source: String): String = source
        .replace(BLOCK_COMMENT, "")
        .replace(LINE_COMMENT, "")

    private fun composeRoot(): File = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu")

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }

    private companion object {
        val BLOCK_COMMENT = Regex("""/\*[\s\S]*?\*/""")
        val LINE_COMMENT = Regex("""//[^\n]*""")

        /** 门控判据原文（共享件里的唯一一处「内容压到顶栏带下」开关）。 */
        const val GATE_IF = "if (!LocalQingyuBackButtonGlass.current)"

        /**
         * 有人自行注入顶栏门控的写法：`CompositionLocalProvider(LocalQingyuBackButtonGlass provides …)`。
         *
         * 负向后顾**只排除标识符字符**，不排除点号——写成全限定名
         * `com.mutx163.qingyu.components.LocalQingyuBackButtonGlass provides` 一样抓得到
         * （与 [BARE_ICON_BUTTON] 同一条修法、同一个假绿点）。`Local…Glass` 名字前面
         * 不可能是字母数字，放宽后不会误报。
         */
        val GATE_PROVIDES = Regex("""(?<![\w])LocalQingyuBackButtonGlass\s+provides""")

        /** 顶栏调用点：只有这三类容器的 `actions` 参数算「顶栏动作槽」。 */
        val BAR_CALL = Regex("""\b(QingyuPageScaffold|SmallTopAppBar|TopAppBar)\s*\(""")

        /**
         * 裸 `IconButton(`：负向后顾**只排除标识符字符**，不排除点号——
         * 写成全限定名 `top.yukonga.miuix.kmp.basic.IconButton(` 一样抓得到
         * （排掉点号就是 2026-11-05 复核指出的假绿点）。
         * `QingyuGlassIconButton` 的名字里 `IconButton` 前面是字母 `s`，不会被误抓。
         */
        val BARE_ICON_BUTTON = Regex("""(?<![\w])IconButton\s*\(""")
        val GLASS_ICON_BUTTON = Regex("""(?<![\w])QingyuGlassIconButton\s*\(""")
    }
}
