package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * P3-B-3 四页的文案逐字对照 ARB（`lib/l10n/app_zh.arb` = template，见 `l10n.yaml`）。
 *
 * ## 与 `SettingsArbParityTest` 的分工
 *
 * 那一份覆盖 P3-B 的基线 4 页；这一份只覆盖 P3-B-3 的 4 页（实时活动两屏 /
 * 节假日两屏 / 天气 / 诊断）。分开是因为四条泳道并行，各自的对拍互不干扰。
 *
 * ## 比对口径
 *
 * 1. **spec 里出现的每一处文案**（行的标题/说明/行尾、分组小标题、整宽说明、
 *    内联块的标签与按钮、下拉选项名）都必须与 ARB 同键的值逐字一致；
 * 2. **`SettingsStringsExt3` 里的每一条**也必须与 ARB 一致——防「键抄了、
 *    值抄错」以及「文案表里有脏条目但页面没用上」；
 * 3. 带占位符的模板按「片段按序出现」判定（渲染值已替换占位符）。
 *
 * 外加一条反向守卫：**文案表里不许有 ARB 里不存在的键**。
 */
class SettingsStringsExt3ParityTest {

    /** 四页的最满状态：把所有条件分支都点亮，保证分支里的文案也被走到。 */
    private fun specs(): List<SettingsPageSpec> = listOf(
        SettingsLivePage.spec(
            SettingsPageState(),
            LivePageData(
                beforeClass = LiveDisplayInput(showCourseName = true, showLocation = true),
                duringEndFollowBeforeClass = false,
                duringEnd = LiveDisplayInput(showCourseName = true, showCountdown = true),
            ),
        ),
        SettingsLiveSelfCheckPage.spec(
            SettingsPageState(),
            LiveSelfCheckData(
                isReleaseBuild = false,
                holidayOverrideEnabled = true,
                sessionActive = true,
                courseTestLabel = "高等数学",
                semesterUnset = true,
                serviceRunning = true,
                notIslandReason = "",
                loadingDebugStatus = true,
                exportingDiagnostics = true,
                autoRefreshEnabled = true,
                refreshedAtText = "12:34:56",
                timeCorrectionSeconds = -3,
                debugLoaded = true,
                debugSections = LiveDebugSection.entries.associateWith { emptyList() },
                rawDebugJson = "{}",
                clearingDiagnostics = true,
            ),
        ),
        SettingsHolidayPage.spec(
            SettingsPageState(),
            HolidayPageData(
                year = "2026",
                customHolidays = listOf(
                    HolidayGroupRow("g1", "校庆", "2026-10-01", "2026-10-03", HolidayKind.VACATION),
                    HolidayGroupRow("g2", "补课", "2026-11-08", "2026-11-08", HolidayKind.ADJUSTED_WORKDAY),
                ),
                officialHolidays = listOf(
                    HolidayItem(
                        "国庆节", "2026-10-01", "2026-10-07", HolidayKind.VACATION,
                        isPast = false, nameKey = "holidayNameNationalDay",
                    ),
                    HolidayItem(
                        "补班", "2026-09-27", "2026-09-27", HolidayKind.ADJUSTED_WORKDAY,
                        isPast = true, nameKey = "holidayMakeupWorkday",
                    ),
                ),
            ),
        ),
        SettingsHolidayAdvancedPage.spec(
            SettingsPageState(),
            HolidayAdvancedData(logs = listOf(HolidayLogEntry("09:00", "已从内置数据加载"))),
        ),
        SettingsWeatherPage.spec(
            SettingsPageState(),
            WeatherPageData(enabled = true, status = WeatherStatus.FAILED, cityDisplayName = "杭州市"),
        ),
        SettingsDiagnosticsPage.spec(
            SettingsPageState(),
            DiagnosticsPageData(showMemoryStats = true, recordingEnabled = true),
        ),
    )

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        var checked = 0
        for (spec in specs()) {
            for ((key, text) in spec.allArbTexts()) {
                if (key == NON_ARB_TEXT) continue
                assertMatchesArb(key, text)
                checked++
            }
        }
        // 防空转：遍历器若坏掉（返回空清单）必须红，而不是「零违规=绿」。
        //
        // 阈值取 90 而不是 120：文案表里有 160 条，但**屏上并不全都出现**——
        // toast（保存失败 / 已写入应用日志 / 已开启应用日志记录…）、弹层正文
        // （自定义假期的新增/编辑/删除确认）、分享文本（导出日志的 subject/body）
        // 都不在 spec 里，它们只在动作被触发时才上屏。六份 spec 铺满条件分支后
        // 实测约 98 条，取 90 留一点余量。
        assertTrue("逐字对照的文案条数太少（$checked），遍历器可能失效", checked >= 90)
    }

    @Test
    fun `六个 spec 一个都不少且每份都有文案`() {
        // 这条专门防「漏挂某个子页」：总数阈值只要有一页被摘掉仍可能过线，
        // 逐页非零 + 页数钉死才拦得住。SettingsLiveSelfCheckPage 与
        // SettingsHolidayAdvancedPage 是最容易被忘在两个子页。
        val list = specs()
        assertEquals("spec 数量应恒为 6（4 个 Dart 源共 6 屏）", 6, list.size)
        val empty = list.filter { spec ->
            spec.allArbTexts().none { it.first != NON_ARB_TEXT }
        }.map { it.id }
        assertEquals("这些 spec 里一条 ARB 文案都没收到，递归遍历可能漏分支", emptyList<String>(), empty)
        assertEquals(
            listOf(
                "settings-live",
                "settings-live-self-check",
                "settings-holiday",
                "settings-holiday-advanced",
                "settings-weather",
                "settings-diagnostics",
            ),
            list.map { it.id },
        )
    }

    @Test
    fun `spec 里用到的每个 ARB 键都真的存在于 arb`() {
        val keys = specs().flatMap { it.allArbTexts() }.map { it.first }
            .filter { it != NON_ARB_TEXT }
            .toSet()
        val missing = keys.filter { !ArbZh.strings.containsKey(it) }
        assertEquals("这些键在 app_zh.arb 里不存在", emptyList<String>(), missing)
    }

    @Test
    fun `文案表里每一条都与 arb 一致`() {
        val entries = stringsExt3Entries()
        assertTrue("文案表条目太少（${entries.size}），反射可能失效", entries.size >= 150)
        entries.forEach { (key, text) -> assertMatchesArb(key, text) }
    }

    @Test
    fun `文案表里没有 arb 之外的自造键`() {
        val bogus = stringsExt3Entries().map { it.first }
            .filter { !ArbZh.strings.containsKey(it) }
        assertEquals("这些键是自造的，ARB 里没有", emptyList<String>(), bogus)
    }

    @Test
    fun `文案表覆盖了四页全部 153 个键`() {
        // 每个页面用到的键都必须在文案表里找得到（防止「页面引了 SettingsStringsExt3 里没有的键」
        // 这类编译错之外的口径错：现在它是编译期强制的，这里再加一条人可读的清单）
        val used = specs().flatMap { it.allArbTexts() }.map { it.first }
            .filter { it != NON_ARB_TEXT }
            .toSet()
        val declared = stringsExt3Entries().map { it.first }.toSet()
        val notDeclared = used - declared
        assertEquals("这些键页面在用但文案表没声明", emptySet<String>(), notDeclared)
    }

    @Test
    fun `占位符模板按片段比对而不是整串相等`() {
        // 人推的反例：holidayDateSameMonth 的渲染值是「10 月 1 日～3 日」，
        // 与模板不同但必须通过；改掉片段（「～」→「到」）必须红。
        assertMatchesArb("holidayDateSameMonth", "10 月 1 日～3 日")
        assertEquals("{month} 月 {start} 日～{end} 日", ArbZh.value("holidayDateSameMonth"))
        val failed = runCatching { assertMatchesArb("holidayDateSameMonth", "10 月 1 日到3 日") }
        assertTrue("改掉模板片段应当比对失败", failed.isFailure)
    }

    /**
     * 两条与 `DiagnosticsStrings` 逐字重复的死键，2026-11-06 已从 `SettingsStringsExt3` 删除：
     * `liveDiagnosticsCleared` / `liveDiagnosticsClearFailed`（同句在
     * `pages/diagnostics/DiagnosticsStrings.kt:34-35` 的 `appLogsCleared` / `appLogsClearFailed`，
     * Kotlin 侧真正在用的是后者，见 `DiagnosticsLogHost.kt:370-372` / `LiveSelfCheckHost.kt:348-350`）。
     *
     * ## 为什么只删 Kotlin、ARB 六份必须留着
     *
     * 这两个键**不是死键**：`lib/screens/settings/settings_live.dart:443-444` 仍在读
     * `AppLocalizations.liveDiagnosticsCleared/ClearFailed`。删 ARB 会让 `gen-l10n`
     * 少生成两个 getter，Flutter 侧直接编译失败。所以：
     * - Kotlin 文案表：不许再加回（第①段）；
     * - ARB 六份：**必须仍在**，少了就是有人误删（第②段）；
     * - Dart 消费点：仍在引用才成立；哪天 Dart 侧删了，这条会红——那时才该按
     *   `ExportStringsParityTest` 的先例把 ARB 一起删并改这里。
     *
     * 咬合探针（已实测）：把 `val liveDiagnosticsCleared = ArbText("liveDiagnosticsCleared", …)`
     * 加回 `SettingsStringsExt3` ⇒ 本测试红；删掉 ⇒ 绿。
     */
    @Test
    fun `两条与 DiagnosticsStrings 重复的死键不许加回`() {
        val removed = listOf("liveDiagnosticsCleared", "liveDiagnosticsClearFailed")

        // ① Kotlin 文案表里不许再出现（防加回）
        val declared = stringsExt3Entries().map { it.first }.toSet()
        for (key in removed) {
            assertFalse(
                "`$key` 又回到了 `SettingsStringsExt3`（Kotlin 侧把与 DiagnosticsStrings 重复的死键加回来了）。",
                key in declared,
            )
        }

        // ② ARB 六份必须保留：Dart 侧还在消费，删了 gen-l10n 产物会缺 getter。
        val arbDir = File(repoRoot(), "lib/l10n")
        val arbFiles = listOf(
            "app_zh.arb",
            "app_en.arb",
            "app_ja.arb",
            "app_ko.arb",
            "app_zh_HK.arb",
            "app_zh_TW.arb",
        )
        for (name in arbFiles) {
            val file = File(arbDir, name)
            assertTrue("找不到 ARB 文件：${file.absolutePath}", file.isFile)
            val text = file.readText(Charsets.UTF_8)
            for (key in removed) {
                assertTrue(
                    "`$key` 从 $name 里消失了：Dart 侧 settings_live.dart 还在读它，" +
                        "删了 `gen-l10n` 会缺 getter，Flutter 侧编译失败。",
                    text.contains("\"$key\""),
                )
            }
        }

        // ③ 消费点自检：Dart 侧确实还在用（换成「Dart 删了」时才该动 ARB）
        val dartFile = File(repoRoot(), "lib/screens/settings/settings_live.dart")
        assertTrue("找不到 Dart 消费点：${dartFile.absolutePath}", dartFile.isFile)
        val dartText = dartFile.readText(Charsets.UTF_8)
        for (key in removed) {
            assertTrue(
                "Dart 侧不再引用 `$key`：可以按 ExportStringsParityTest 的先例连 ARB 一起删，并同步改本测试。",
                key in dartText,
            )
        }
    }

    @Test
    fun `四个页面的标题都对上了`() {        assertEquals("liveSettingsTitle", SettingsLivePage.ID_TITLE_KEY)
        assertEquals("liveSelfCheckTitle", SettingsLiveSelfCheckPage.ID_TITLE_KEY)
        assertEquals("holidaySettingsTitle", SettingsHolidayPage.ID_TITLE_KEY)
        assertEquals("holidayAdvancedTitle", SettingsHolidayAdvancedPage.ID_TITLE_KEY)
        assertEquals("weatherSettingsTitle", SettingsWeatherPage.ID_TITLE_KEY)
        assertEquals("diagnosticsEntryTitle", SettingsDiagnosticsPage.ID_TITLE_KEY)
    }

    // ------------------------------------------------------------------ 工具

    /** 用反射摊平 `SettingsStringsExt3` 的每个 `ArbText` 属性（键 → 值）。 */
    private fun stringsExt3Entries(): List<Pair<String, String>> =
        SettingsStringsExt3::class.java.declaredMethods
            .filter { it.parameterCount == 0 && it.returnType == ArbText::class.java }
            .map { method ->
                val text = method.invoke(SettingsStringsExt3) as ArbText
                text.key to text.zh
            }

    /** 仓库根：以 `lib/l10n/app_zh.arb` 为标志文件向上找（L0 与 Gradle 的工作目录不同）。 */
    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "lib/l10n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（lib/l10n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }

    private fun assertMatchesArb(key: String, text: String) {
        val template = ArbZh.value(key)
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
    }
}
