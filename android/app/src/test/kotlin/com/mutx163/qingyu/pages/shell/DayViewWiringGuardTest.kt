package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日视图接线守卫（2026-10-30 建立，直接来自二轮质量审核 P0-2 / P1-1..P1-5）。
 *
 * ## 它防的是哪一类事故
 *
 * `c3.day` 的壳分支曾经有三处「看着正常、实际错」：
 * 1. `initialDayOfWeek = LocalDate.now().dayOfWeek.value` —— 点「周五」进去看到的永远是今天；
 * 2. 壳自己拼 `DayViewPageData`，`scheduleCount = 0`、日程条目不构造、日期标题拼成
 *    「第 3 周 · 周1」这类自造文案；
 * 3. `visibleDays` / `totalWeeks` 一个都不传 ⇒ 隐藏周末不生效、能翻到学期外。
 *
 * 修法是把装配交给模型层唯一实现 `DayViewDataAssembler` + `dayViewPageDataOf`，
 * 并且「点哪天」经 `pendingDayViewDayOfWeek` 单次意图传入。
 *
 * ## 为什么读源码文本
 *
 * 「这一分支喂了什么实参」写在 Compose 调用里，反射与编译产物都不保留；
 * 与同目录 `DiagnosticsWiringGuardTest` / `ShellPageDispatchCoverageTest` 同一套做法。
 * 判据是「出现/不出现某些字样」，不依赖缩进与折行。
 */
class DayViewWiringGuardTest {

    @Test
    fun `日视图必须接收点击意图而不是恒取今天`() {
        val branch = branchBody("c3.day")
        // 2026-11-02：日视图同时有两种入口——独立路由（`c3.day`）和首页里的展开层
        // （`dayOverlay != null`）。展开层的选中日由首页宿主直接给，不再借道单次意图。
        assertTrue(
            "`c3.day` 分支没有优先读展开层给的 `initialDayOfWeek`——" +
                "点星期栏某天会再次落到今天（P0-2 回退）。分支体：\n$branch",
            "initialDayOfWeek = dayOverlay?.initialDayOfWeek" in branch,
        )
        assertTrue(
            "`c3.day` 分支没有保留独立路由的意图回落（`dayIntent ?: timetableLastViewedDayOfWeek`）",
            "dayIntent ?: appSettings.timetableLastViewedDayOfWeek" in branch,
        )
        assertTrue(
            "`c3.day` 分支里仍出现 `initialDayOfWeek = LocalDate.now()`——这就是 P0-2 的原写法",
            "initialDayOfWeek = LocalDate.now()" !in branch,
        )
    }

    @Test
    fun `日视图数据必须走模型层装配器`() {
        val branch = branchBody("c3.day")
        assertTrue(
            "`c3.day` 分支没有调用 `dayViewPageDataOf(`：说明又在壳里手拼 DayViewPageData，" +
                "日程条目不构造、scheduleCount 写死 0 的老问题会重来。",
            "dayViewPageDataOf(" in branch,
        )
        assertTrue(
            "`c3.day` 分支没有调用 `DayViewDataAssembler.build(`：装配规则应当只在模型层一份。",
            "DayViewDataAssembler.build(" in branch,
        )
        assertTrue(
            "`c3.day` 分支里又出现 `scheduleCount = 0`（写死的假读数）",
            "scheduleCount = 0" !in branch,
        )
    }

    @Test
    fun `日视图必须传入学期周数与可见星期`() {
        val branch = branchBody("c3.day")
        assertTrue(
            "`c3.day` 分支没有传 `totalWeeks`：页面会退回「30 周」默认值，能翻到学期之外。",
            "totalWeeks =" in branch,
        )
        assertTrue(
            "`c3.day` 分支没有传 `visibleDays`：隐藏周末的设置在这个入口不生效。",
            "visibleDays =" in branch,
        )
    }

    @Test
    fun `日视图必须喂星期条数据`() {
        val branch = branchBody("c3.day")
        // 2026-10-31 审核：星期条曾有骨架但拿不到日期/考试/日程数据 ⇒ 日期空、今天没
        // 下划线、圆点恒不亮；这四条实参就是那一整条链的入口。
        for (expected in listOf(
            "semesterStartDate =",
            "realCurrentWeek =",
            "hasExamOnDate =",
            "hasScheduleOnDate =",
        )) {
            assertTrue(
                "`c3.day` 分支没有传 `$expected`：星期条的日期/今天标记/考试·日程圆点会失效。",
                expected in branch,
            )
        }
    }

    @Test
    fun `日视图的能力回调必须全部有落点`() {
        val branch = branchBody("c3.day")
        // 每一项都对应一处「画在屏上但点了没反应」的历史缺陷：
        // 备注/作业胶囊、待办勾选、逾期折叠行、任务行课程解析、天气行。
        for (expected in listOf(
            "onOpenCourseNotes =",
            "onOpenCourseTask =",
            "onToggleTask =",
            "onViewAllOverdue =",
            "courseResolver =",
            "weatherOf =",
        )) {
            assertTrue(
                "`c3.day` 分支没有接 `$expected`：页面上对应入口会消失或点了没反应。",
                expected in branch,
            )
        }
    }

    @Test
    fun `考试卡必须落到那场考试而不是列表`() {
        val branch = branchBody("c3.day")
        assertTrue(
            "`c3.day` 的考试卡没有写入 `pendingEditExam`：点考试卡只会在列表里再找一遍，" +
                "Dart 是 `examForm(exam: exam)` 直接开这一场。",
            "pendingEditExam =" in branch,
        )
        assertTrue(
            "`c3.day` 没有打开 `d3.addExam`：考试卡落点仍然是列表页。",
            "\"d3.addExam\"" in branch,
        )
    }

    @Test
    fun `日程卡必须带上哪一次发生`() {
        val branch = branchBody("c3.day")
        assertTrue(
            "`c3.day` 没有写 `pendingScheduleOccurrenceDate`：重复日程从日视图点进去会变成" +
                "「改整条系列」，而不是「改这一次」。",
            "pendingScheduleOccurrenceDate =" in branch,
        )
    }

    @Test
    fun `日视图必须接上首页壁纸与材质`() {
        val branch = branchBody("c3.day")
        // 2026-11-01：日视图原先是一块不透明主题底 —— 周视图有壁纸、玻璃带、液态卡，
        // 一切到日视图全没了。这五个实参就是那条链接进来的入口；少一个，对应的那一层
        // 就静默消失（页面全有默认值，编译不会报错）。
        for (expected in listOf(
            "backdrop =",
            "chromeInk =",
            "material =",
            "hasBackdrop =",
            "pageColorArgb =",
        )) {
            assertTrue(
                "`c3.day` 分支没有传 `$expected`：日视图会退回不透明主题底，" +
                    "壁纸 / 顶栏玻璃带 / 议程卡液态档整条链断在这里。",
                expected in branch,
            )
        }
        assertTrue(
            "`c3.day` 分支没有走 `rememberHomeBackdropChrome(`：壁纸快照、材质快照、" +
                "顶栏墨色必须在那一份推导里算，别在壳里另写一遍。",
            "rememberHomeBackdropChrome(" in branch,
        )
    }

    @Test
    fun `冲突透明度必须从设置喂进日视图`() {
        // 2026-11-07：日课卡原先只写死了非本周 0.62，**设置里的 conflict opacity 没读** ——
        // 周视图跟着滑杆变、日视图不变。这条同时钉住壳与外观预览两个调用点：
        // 少一处，那一边的日课卡就退回写死值（页面有默认值，编译不会报错）。
        val branch = branchBody("c3.day")
        assertTrue(
            "`c3.day` 没有传 `conflictCourseOpacity`：日视图会退回默认 0.70，" +
                "设置里的「冲突课程透明度」对它无效。",
            "conflictCourseOpacity = appSettings.timetableConflictCourseOpacity.toFloat()" in branch,
        )
        val editor = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt",
        )
        assertTrue(
            "外观预览没有把草稿设置里的冲突透明度喂给日视图：拖滑杆卡片不会跟着变。",
            "conflictCourseOpacity = settingsModel.timetableConflictCourseOpacity.toFloat()" in editor,
        )
    }

    @Test
    fun `日视图课程卡颜色开关必须从设置喂进日视图`() {
        // 2026-11-09：日课卡此前恒按 `course.color` 上色，设置页没有开关。
        // 这条同时钉住壳与外观预览两个调用点：少一处，那一边的开关就静默失效
        // （页面参数有默认值 true，编译不会报错）。
        val branch = branchBody("c3.day")
        assertTrue(
            "`c3.day` 没有传 `useCourseColors`：日视图会退回默认「按课程色上色」，" +
                "设置里的「日视图课程卡片颜色」对它无效。",
            "useCourseColors = appSettings.dayViewUseCourseColor" in branch,
        )
        val editor = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt",
        )
        assertTrue(
            "外观预览没有把草稿设置里的日视图课卡颜色喂给日视图：开关切了预览不变。",
            "useCourseColors = settingsModel.dayViewUseCourseColor" in editor,
        )
    }

    @Test
    fun `预览必须共用真首页的天气数据源`() {
        // 2026-11-07 用户实报：外观编辑页的预览里课卡没有天气行。壳里真首页喂的是
        // `wiring.weather`，预览没接 ⇒ 首页有、预览没有，卡片高度也跟着不同。
        val editor = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt",
        )
        assertTrue(
            "外观宿主没有 `weatherProvider` 参数：预览拿不到天气数据源。",
            "weatherProvider: WeatherProvider?" in editor,
        )
        assertTrue(
            "日视图预览没有用 `DayViewWeather.lineProvider` 拼天气行。",
            "DayViewWeather.lineProvider(settingsModel, weatherProvider)" in editor,
        )
        assertTrue(
            "周视图预览没有把 `weatherProvider` 交给 TimetableHost。",
            "weatherProvider = weatherProvider" in editor,
        )
        val shell = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
        assertTrue(
            "壳没有把设备级 weatherProvider 传给外观宿主。",
            "weatherProvider = weatherProvider" in shell,
        )
        // 首页那一份也必须接：周课卡的天气行走 TimetableHost 自己的 weatherOf，
        // 漏传就是「首页没有、外观预览有」（2026-11-07 用户实报）。
        val wiringSrc = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        // 日视图页面本身由 ShellPageIndex 按 pageId 分发（`ShellWiring` 只传 pageId="c3.day"），
        // 所以两处要分开看：TimetableHost 在 ShellWiring，DayViewPage 在 ShellPageIndex。
        assertTrue(
            "ShellWiring 里没有把 `weatherProvider` 交给首页 TimetableHost：" +
                "周课卡的天气行会读不到设备级数据源。",
            "weatherProvider = weatherProvider" in wiringSrc,
        )
        assertTrue(
            "ShellPageIndex 的 c3.day 分支调 `DayViewPage` 时没有传 `weatherProvider`：" +
                "日视图课卡天气行会空着。",
            Regex("""DayViewPage\([\s\S]{0,600}?weatherProvider\s*=\s*weatherProvider""")
                .containsMatchIn(shell),
        )
    }

    @Test
    fun `星期栏点击必须直接切到日视图展开态`() {
        // 2026-11-02：点星期栏某天**不再推 `c3.day` 路由**（推页会被 miuix 播成
        // 「从左侧滑入」，与原版「选中的列长成整屏」完全不同）。现在走首页的
        // `onSelectDay`：记下选中日 + 切到日视图展开态，由页面自己播窗口动画。
        val wiring = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        val weekPage = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt",
        )
        assertTrue(
            "`ShellWiring` 的日视图入口没有调用 `wiring.setHomeSelection(selectedWeek, selectedDayOfWeek)`——" +
                "日视图拿不到「点的是哪一天」。",
            "wiring.setHomeSelection(selectedWeek, selectedDayOfWeek)" in wiring,
        )
        assertTrue(
            "`ShellWiring` 的日视图入口没有切到 `TimetableHomeViewMode.DAY`——点了不会进日视图。",
            "wiring.switchHomeViewMode(TimetableHomeViewMode.DAY)" in wiring,
        )
        assertTrue(
            "`ShellWiring` 仍在为星期栏点击推 `c3.day` 路由（`onNavigate(\"c3.day\")`）——" +
                "那正是「从左侧滑入」的来源，必须改走页内展开。",
            "onNavigate(\"c3.day\")" !in wiring,
        )
        assertTrue(
            "`TimetableWeekPage` 的星期栏点击没有接到 `onSelectDay`：周视图点某天不会切到日视图。",
            "onSelectDay(displayedPage + 1, dayOfWeek)" in weekPage,
        )
        assertTrue(
            "`TimetableWeekPage` 的日视图内换日没有接到 `onSelectDay`：点另一天不会切过去。",
            "onSelectDay(selectedWeek, dayOfWeek)" in weekPage,
        )
    }

    @Test
    fun `日视图必须记住上次看的那一天`() {
        val branch = branchBody("c3.day")
        // 2026-11-02 用户实报：「我滑到其他天，点外观编辑，预览显示的是另一天」。
        // 根因是日视图的浏览位置只活在 pagerState 里：不落盘，外观编辑页的日预览
        // （按 `timetableLastViewedDayOfWeek` 取日期）就只能看到旧值。
        assertTrue(
            "`c3.day` 的无意图初始日没有回落到 `appSettings.timetableLastViewedDayOfWeek`：" +
                "从底栏再进日视图会跳回今天，与外观编辑页预览也对不上。",
            "dayIntent ?: appSettings.timetableLastViewedDayOfWeek" in branch,
        )
        assertTrue(
            "`c3.day` 的 `onPageChanged` 没有把看的那一天写回存档（找不到 " +
                "`saveLastViewedDayOfWeek(`）：日视图的浏览位置永远不会落盘。",
            "saveLastViewedDayOfWeek(" in branch,
        )
        assertTrue(
            "`c3.day` 的 `onPageChanged` 仍然只收 week、把 dayOfWeek 丢掉（`{ week, _ ->`）：" +
                "翻到哪一天不会写进设置，外观编辑页的日预览会停在旧日期上。",
            "onPageChanged = { week, _ ->" !in branch,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：解析器坏了会让上面几条全部变绿——那比没有守卫更糟。
        val branch = branchBody("c3.day")
        assertTrue("`c3.day` 分支解析出来太短（${branch.length} 字符），解析可能坏了", branch.length > 200)
        assertTrue("分支体里应当有 DayViewPage( 调用", "DayViewPage(" in branch)
    }

    // ------------------------------------------------------------------ 解析

    private fun branchBody(id: String): String {
        val source = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        val matches = BRANCH.findAll(source).toList()
        val index = matches.indexOfFirst { it.groupValues[1] == id }
        assertTrue("ShellPageIndex.kt 里找不到分支 `$id`", index >= 0)
        val start = matches[index].range.last + 1
        val end = matches.getOrNull(index + 1)?.range?.first ?: source.length
        return source.substring(start, end)
    }

    /**
     * 从工作目录向上找仓库根再定位文件：L0 脚本与 Gradle 的工作目录不同，
     * 所以按「向上找标志文件」而不是写死相对路径；**找不到仍判失败**，
     * 守卫不许因为路径变了静默跳过。
     */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        /** 分派分支：行首空白 + 引号 id + 箭头（与同目录守卫同一口径）。 */
        val BRANCH = Regex("""^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->""", RegexOption.MULTILINE)
    }
}
