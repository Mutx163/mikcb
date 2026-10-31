package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「壳分支必须接真宿主」守卫（2026-10-29 建立，直接来自诊断族审计）。
 *
 * ## 它防的是哪一类事故
 *
 * P3-H「诊断与测试夹具」台账写「5/5 已交付、91 例单测绿」，实际用户点进去是五张死页：
 * `ShellPageIndex.kt` 里四条分支喂的是空快照（`DiagnosticsLogSnapshot.EMPTY` /
 * `snapshot = null` / `emptyList()`），回调是 `= {}`；第五条用 `SettingsPageState()`
 * 空构造渲染。**页面能打开、永远没数据、点了没反应**，而当时所有单测都是绿的——
 * 因为它们测的是模型层与渲染层，那两层确实是对的。
 *
 * 教训：渲染层交付 ≠ 页面可用，**回路必须过壳**。这条守卫把这条纪律变成机器可判：
 * 受管页面（见 [MANAGED]）在分派层的分支里
 * ① 必须出现指定的宿主符号（说明数据/交互由宿主负责），
 * ② 不许出现「空数据 / 空回调 / 空构造 state」这几种写法。
 *
 * ## 为什么读源码文本
 *
 * 「这一分支喂了什么实参」写在 Compose 的调用里，Kotlin 反射与编译产物都不保留。
 * 与同目录的 `ShellPageDispatchCoverageTest` 同一套做法（那边管「有没有分支」，
 * 这边管「分支是不是真的」）。
 *
 * **代价写清**：文本解析对格式敏感，但判据是「分支体里出现/不出现某些字样」，
 * 不依赖缩进与折行。若哪天把宿主换名，这条会先红——那是**故意的**，
 * 提醒改接线的人同时更新 [MANAGED]，而不是静默失效。
 *
 * ## 加新受管页面
 *
 * 只往 [MANAGED] 加一行（页面 id → 必须出现的宿主符号）。判据通用，不用改代码。
 *
 * ## 2026-10-30（F14）：从 9 条扩到 65 条
 *
 * 建立时只守了诊断族等 9 条；§十 复核指出「其余已接线的 20 多条没人守，随时能被改回空回调」。
 * 本轮把 [MANAGED] 扩到**当时已交付且已干净的全部路由**：
 * 87 条分派分支 − 15 条命中 [FORBIDDEN] 的在途/未收口路由 − 7 条 F06 / F08 尚未交付的路由 = **65 条**。
 *
 * ## 2026-10-31（F20）：65 → 66 条
 *
 * `b.homeWidget` 由空构造 state 换成 [HomeWidgetHost]，从「未交付」名单转入受管清单。
 *
 * 没纳入的那 22 条**不是遗漏**，逐条原因写在 [MANAGED] 的注释里。纳入它们会让守卫必红，
 * 等于逼下一个人把断言删掉（§十一 F14 红线）。
 *
 * 类名带 `Diagnostics` 是历史（它出生于诊断族审计），**有意没改名**：§十.3 与台账按这个名字
 * 引用它，改名要连那些引用一起动。看覆盖面请读 [MANAGED]，不要看类名。
 */
class DiagnosticsWiringGuardTest {

    // ------------------------------------------------------------------ 守卫

    @Test
    fun `受管页面全部在分派层找到分支`() {
        val blocks = branchBlocks()
        val missing = MANAGED.keys.filter { it !in blocks }.sorted()
        assertEquals(
            "这些页面在 ShellPageIndex.kt 里找不到分派分支（正则或格式变了？）：$missing",
            emptyList<String>(),
            missing,
        )
    }

    @Test
    fun `受管页面必须由真宿主渲染`() {
        val blocks = branchBlocks()
        val wrong = MANAGED.entries
            .flatMap { (id, symbols) ->
                val code = codeOf(blocks[id].orEmpty())
                symbols.filter { it !in code }
                    .map { "$id 的分支（去注释后）里没有 $it —— 说明它还直接拼渲染层，数据和回调很可能又是空壳" }
            }
            .sorted()
        assertEquals(
            "这些页面的壳分支没接真宿主：\n" + wrong.joinToString("\n") { "  $it" },
            emptyList<String>(),
            wrong,
        )
    }

    @Test
    fun `受管页面的分支里没有空数据与空回调`() {
        val blocks = branchBlocks()
        val offences = mutableListOf<String>()
        for ((id, _) in MANAGED) {
            val body = codeOf(blocks[id].orEmpty())
            for ((pattern, why) in FORBIDDEN) {
                if (pattern.containsMatchIn(body)) {
                    offences += "$id：$why（命中 ${pattern.pattern}）"
                }
            }
        }
        assertEquals(
            "这些页面的壳分支还在喂空数据 / 空回调 / 空构造 state：\n" +
                offences.sorted().joinToString("\n") { "  $it" },
            emptyList<String>(),
            offences,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：正则若失效，上面三条会全部变绿——那比没有守卫更糟。
        val blocks = branchBlocks()
        assertTrue("分派层解析出的分支太少（${blocks.size}），解析可能坏了", blocks.size >= 70)
        assertTrue("受管页面清单不该为空", MANAGED.isNotEmpty())
        // 每条分支体都该是非空的（分支至少有一行调用）。
        val emptyBlocks = blocks.filterValues { it.isBlank() }.keys
        assertEquals("这些分支解析出来是空的（解析可能只吃到了箭头）：$emptyBlocks", emptySet<String>(), emptyBlocks)
    }

    // ------------------------------------------------------------------ 解析

    /**
     * 分派层 `when (pageId)` 的「id → 分支体」。
     *
     * 分支体 = 从 `"id" ->` 的箭头之后，到**下一条**分支箭头之前。
     * 最后一条分支取到文件末尾（`else ->` 之前的内容会一并算进去，
     * 但受管页面都不会是最后一条，且判据只在分支体里找字样，不影响结论）。
     */
    private fun branchBlocks(): Map<String, String> {
        val source = dispatchSource().readText(Charsets.UTF_8)
        val matches = BRANCH.findAll(source).toList()
        val blocks = LinkedHashMap<String, String>()
        matches.forEachIndexed { index, match ->
            val start = match.range.last + 1
            val end = matches.getOrNull(index + 1)?.range?.first ?: source.length
            val id = match.groupValues[1]
            // 同一个 id 出现多次时不覆盖：次数由 `ShellPageDispatchCoverageTest` 管，
            // 这里取第一段即可（Kotlin 也只认第一条）。
            blocks.putIfAbsent(id, source.substring(start, end))
        }
        return blocks
    }

    /**
     * 去掉注释后的代码文本。
     *
     * 为什么需要：宿主符号原先用**纯文本包含**判断，在注释里写一次宿主名
     * 就能让守卫变绿（2026-10-29 二轮质量审核实测的绕过通道之一）。
     * 判据只看代码——注释里提到宿主不算接线。
     */
    private fun codeOf(body: String): String =
        body.replace(Regex("""/\*[\s\S]*?\*/"""), " ")
            .replace(Regex("""//[^\n]*"""), " ")

    /**
     * 从工作目录向上找仓库根，再定位分派层源码。
     *
     * 与 `ShellPageDispatchCoverageTest.dispatchSource()` 同一套做法：L0 脚本与
     * Gradle 的工作目录不同，所以按「向上找标志文件」而不是写死相对路径。
     * 路径候选里保留已删除的 `composeUi` 只是为了给出更清楚的报错线索——
     * **都不在仍判失败**，守卫不许因为「路径变了」静默跳过。
     */
    private fun dispatchSource(): File {
        val candidates = listOf(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
            "android/app/src/composeUi/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        var dir: File? = File("").absoluteFile
        repeat(8) {
            for (relative in candidates) {
                val candidate = File(dir, relative)
                if (candidate.isFile) return candidate
            }
            dir = dir?.parentFile
        }
        error(
            "找不到 ShellPageIndex.kt（工作目录 ${File("").absolutePath}）；试过：\n" +
                candidates.joinToString("\n") { "  $it" },
        )
    }

    private companion object {

        /**
         * 受管页面：页面 id → 该分支里**必须出现**的符号（宿主名，可多条）。
         *
         * 2026-10-29 起纳入诊断族五页（本轮接线的对象）。这三行注释是给出征/收摊时的
         * 读数口径：以后每接一页真宿主，就往这里加一行；页面被删，就删这一行。
         *
         * 2026-10-29 二轮质量审核加固：
         * - 判据改成「**去注释后**的代码里必须出现」——原先注释里写一遍宿主名就能骗过守卫；
         * - `= null` 判据开了 `MULTILINE`，原先只有落在分支体末尾的 null 才会被抓；
         * - 值从单字符串改成列表，接一页真宿主时可以同时钉住「宿主 + 关键回调落点」。
         */
        val MANAGED: Map<String, List<String>> = linkedMapOf(
            // 设置 → 诊断：四行（应用日志 / 记录开关 / 内存状态 / 设置快照）
            "b.diagnostics" to listOf("DiagnosticsSettingsHost"),
            // 应用日志查看器：真文件 + 9 个交互
            "h.log" to listOf("DiagnosticsLogHost"),
            // 内存统计：真采集 + 自动刷新 + 跳性能报告
            "h.memory" to listOf("MemoryStatsHost"),
            // 性能报告：帧探针 + 台账
            "h.perfReport" to listOf("PerfReportHost"),
            // 临时测试夹具：仓储真读写
            "h.fixture" to listOf("LiveTestingFixtureHost"),

            // ── 2026-10-29 二轮审核补登记（F02 / F11 收口时自查发现「修好的接线没人守」）──
            // 反馈页：五条渠道真打开 / 真复制（宿主三件套都在 FeedbackChannelHost 里）
            "k.feedback" to listOf("FeedbackChannelHost", "runFeedbackOpenPlan"),
            // 全部功能：39 行每行都要跳页（宿主是同文件里的 MoreFeaturesWithSearch；
            // 表在同文件更下方，本守卫只看分支体，所以只钉宿主名）
            "i.more" to listOf("MoreFeaturesWithSearch"),
            // 搜索浮层独立路由：选中 = 先退浮层再跳页，两步都在这一个回调里
            "i.moreSearch" to listOf("shellTimetableMenuPageId"),
            // 启动引导：开学日期/周数/当前周落盘 + 引导完成标记（宿主 StartupFlowHost）
            "i.startup" to listOf("StartupFlowHost"),

            // ── 2026-10-30 F14 扩面：把「已交付且已干净」的路由全部纳入 ──────────
            // 口径（2026-10-30 11:40 Lead 复算 + 本批独立复扫）：
            //   干净 = 分支体去注释后不命中 [FORBIDDEN]；已交付 = 真宿主 / 真仓储 / 真桥接。
            // 未纳入（命中 [FORBIDDEN]，纳入必红）：
            //   b.live / b.liveSelfCheck / b.glassDockIcon（F06 在途，SettingsPageState()）
            //   g2.webLogin（F08 在途，onWebBridgeMessage = { }）
            //   c2.month / c3.day / d2.scheduleList / d2.taskList / d2.addTask /
            //   d3.timeSchemeEditor / d3.locationMatch / d3.addExam / d3.examList /
            //   e.analysis / k.conflict（这些分支里的 `wiring.pendingX = null` 是**一次性意图
            //   清空**，本意不是空数据，但它落在 FORBIDDEN 的「末尾 null」判据上；属在途/未收口，
            //   明细见认领文件 F14 的备注。要纳入得先单独讨论判据，不许顺手放宽。）
            // 未纳入（未交付，F06/F08 正在做）：
            //   g2.schoolAdapters / g2.adapterDetail / g2.warehouseImport /
            //   g2.customDebug / g2.aiImageImport
            // -- a --
            "a.about" to listOf("AboutStaticPage"),
            "a.changelog" to listOf("ChangelogPage"),
            "a.licenses" to listOf("OpenSourceLicensesHost"),
            "a.support" to listOf("SupportCreatorHostPage"),
            "a.contributors" to listOf("ContributorsHostPage"),
            "a.update" to listOf("AboutUpdateHostPage"),
            // -- b --
            "b.settingsHome" to listOf("SettingsTimetableHubHost"),
            "b.semester" to listOf("SettingsSemesterHost"),
            "b.general" to listOf("SettingsHost", "wiring.settingsModel"),
            "b.appearance" to listOf("SettingsHost", "SettingsAppearancePage.ID"),
            "b.theme" to listOf("SettingsHost", "SettingsThemeManagePage.ID"),
            "b.appearanceEditor" to listOf("AppearanceEditorHost"),
            "b.materialGeneral" to listOf("AppearanceEditorHost", "MaterialSheetPages.GENERAL"),
            "b.materialCourseCard" to listOf("AppearanceEditorHost", "MaterialSheetPages.COURSE_CARD"),
            "b.backdropFlow" to listOf("AppearanceEditorHost", "WallpaperSheetPages.PICKER"),
            "b.recentWallpaper" to listOf("AppearanceEditorHost", "WallpaperSheetPages.PICKER"),
            "b.bingGallery" to listOf("BingGalleryHost"),
            "b.homeNavigation" to listOf("HomeNavigationHost"),
            // 2026-10-31 F20：桌面小组件页从空构造 state 换成真宿主（读设置模型 +
            // 原生渲染 10 卡预览 + 桌面真实卡片绑定 + 添加到桌面 / 精确闹钟授权）。
            "b.homeWidget" to listOf("HomeWidgetHost"),
            "b.homeMenuEditor" to listOf("HomeMenuEditorHost"),
            "b.courseCard" to listOf("SettingsHost", "SettingsCourseCardPage.ID"),
            "b.timetablePage" to listOf("TimetablePageSettingsHost"),
            "b.holiday" to listOf("SettingsHolidayHost"),
            "b.holidayAdvanced" to listOf("SettingsHolidayAdvancedHost"),
            "b.weather" to listOf("WeatherSettingsHost"),
            "b.glassDock" to listOf("GlassDockEditorHost"),
            // -- c1 --
            "c1.week" to listOf("TimetableWithCourseActions"),
            "c1.profiles" to listOf("TimetableProfilesPage", "TimetableProfilesController"),
            // -- d1 --
            "d1.addCourse" to listOf("AddCoursePage", "wiring.pendingEditCourse"),
            "d1.overview" to listOf("CourseOverviewHost"),
            // -- d2 --
            "d2.addSchedule" to listOf("AddScheduleItemPage", "wiring.saveScheduleItem"),
            "d2.dateRule" to listOf("ScheduleDateRuleHost"),
            // -- d3 --
            "d3.timeSchemes" to listOf("TimeSchemeManagementHost"),
            // -- e --
            "e.statistics" to listOf("CourseStatisticsPage", "StatisticsFeed"),
            "e.statisticsSettings" to listOf("StatisticsSettingsPage", "StatisticsSettingsLogic.buildViewState"),
            "e.session" to listOf("StatisticsSessionPage", "StatisticsFeed"),
            // -- f --
            "f.cloudSync" to listOf("CloudSyncController", "CloudBackupDetailHost"),
            "f.backupList" to listOf("CloudBackupListPage", "CloudBackupDetailHost"),
            "f.couple" to listOf("CoupleTimetableSettingsHost"),
            // -- g1 --
            "g1.importEntry" to listOf("ImportEntryHost"),
            "g1.icsImport" to listOf("IcsImportHost"),
            "g1.spreadsheetImport" to listOf("SpreadsheetImportHost"),
            // -- g3 --
            "g3.dataTransfer" to listOf("DataTransferHost"),
            "g3.qrSend" to listOf("QrTransferSendHost", "transferBridge.outboundPayload"),
            "g3.qrScan" to listOf("QrTransferScanHost", "transferBridge.inboundBytes"),
            "g3.icsExport" to listOf("IcsExportHost"),
            "g3.lanEdit" to listOf("LanEditHost"),
            "g3.pickupCodes" to listOf("PickupCodesHost"),
            // -- i --
            "i.userGuide" to listOf("UserGuidePage", "GuidePermissionProbe.probe"),
            "i.hyperosShowcase" to listOf("HyperosShowcasePage"),
            // -- i2 --
            "i2.showcase" to listOf("MiuixShowcasePage"),
            // -- j --
            "j.live" to listOf("LiveDisplayHost"),
            "j.displayBefore" to listOf("LiveDisplayHost"),
            "j.displayDuring" to listOf("LiveDisplayHost", "forDuringEnd = true"),
            "j.reminderTiming" to listOf("LiveReminderTimingHost"),
            "j.keepAlive" to listOf("LiveKeepAliveSettingsPage", "native_runtime_prefs"),
            "j.weatherCity" to listOf("WeatherCityPickerHost"),
        )

        /**
         * 分支体里**不许出现**的写法（正则 → 白话原因）。
         *
         * 只放「一定是空壳」的几种写法，不追求覆盖所有可能：
         * 空 lambda、空列表、空快照、空构造 state、常量空快照。
         */
        val FORBIDDEN: List<Pair<Regex, String>> = listOf(
            Regex("""=\s*\{\s*}""") to "空回调 `= {}`",
            Regex("""\bemptyList\(\s*\)""") to "空列表 `emptyList()`",
            Regex("""\bnull\b\s*,?\s*$|snapshot\s*=\s*null""", RegexOption.MULTILINE) to "空快照 `snapshot = null`",
            Regex("""DiagnosticsLogSnapshot\.EMPTY""") to "常量空快照 `DiagnosticsLogSnapshot.EMPTY`",
            Regex("""SettingsPageState\(\s*\)""") to "空构造 state `SettingsPageState()`",
        )

        /** 分派分支：行首空白 + 引号 id + 箭头（与覆盖守卫同一口径）。 */
        val BRANCH = Regex("""^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->""", RegexOption.MULTILINE)
    }
}
