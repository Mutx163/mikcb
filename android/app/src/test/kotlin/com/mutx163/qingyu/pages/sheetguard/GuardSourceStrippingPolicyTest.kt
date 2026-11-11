package com.mutx163.qingyu.pages.sheetguard

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 守卫源码剥离**元检查**（2026-11-10 守卫加固批 P6-G2）。
 *
 * ## 防的是什么
 *
 * 读源码做 `contains(...)` 的守卫，如果**不先剥注释**，把判据目标行注释掉它照样绿——
 * 2026-11-10 仓库域实弹发生过「已提交的接线被注释掉、守卫静默通过」，靠 J4 补的剥注释
 * 守卫才抓住。同一手法在课程 / 日程 / 设置 / 课表层的多份守卫上都成立。
 *
 * 所以口径是硬的：**读 `.kt` 源码做 `contains` 断言，必须先过
 * [stripKotlinComments] / [readKotlinSourceNormalized] / [readKotlinSourceNoStrings]**。
 *
 * ## 两条判据 + 自测
 *
 * 1. 新冒出来的「读 .kt 却没剥注释」⇒ 红，要求改代码（不是改这份表）；
 * 2. 表里的文件已迁移 / 已删除 ⇒ 红，要求把该行删掉（**只许缩不许增**，与 CJK 棘轮同款）；
 * 3. 剥离器本体自测：三种注释形态、字符串 / 原始字符串 / 转义引号、两档模式的差异，
 *    以及**两处已知边界**（插值里嵌引号、原始字符串多于三个引号收尾）钉桩。
 *
 * ## 扫描口径（**故意收窄**，2026-11-11 评审六要求）
 *
 * 一个测试文件只在这三件事同时成立时才算「读源码的守卫」：
 *
 * - 出现**带引号的 `*.kt` 路径字面量**（`"…/Foo.kt"`）——只是在报错文案里提到 `.kt` 不算；
 * - 用 `readText(` 或 `readSourceNormalized(` 读文件；
 * - 自己做 `.contains(` 断言。
 *
 * 已经走共享剥离、或自带 `fun strip…(` 私有剥离器的文件不算违规。
 * **已知盲区**（本判据故意不覆盖，不要为它把正则写复杂）：`readBytes` / `bufferedReader`
 * 等其它读法、以及把路径拆成几段拼出来的写法。
 *
 * ## 例外表怎么维护
 *
 * [LEGACY_UNSTRIPPED] 是**存量迁移表**：本轮迁移课程 / 日程 / 设置 / 课表 12 份守卫
 * （三路分工）＋ time_scheme 5 份，其余存量按批次收。**迁移一份就把对应一行删掉**；
 * 新守卫不许加行。删行时不用改判据——文件不再命中，留着就会被下面的 stale 断言点名。
 *
 * ⚠️ 本文件自己扫自己会误判（它本来就有 `.kt` 字面量与 `.contains`），所以扫描时跳过自身；
 * 剥离器本体 `testutil/SourceText.kt` 同理跳过（它是实现，不是守卫）。
 */
class GuardSourceStrippingPolicyTest {

    // ───────────────────────── 1. 元检查：读 .kt 必须剥注释 ─────────────────────────

    @Test
    fun `读 kt 源码做 contains 的守卫必须走共享注释剥离`() {
        val offenders = mutableListOf<String>()
        val seen = mutableSetOf<String>()
        testSources().forEach { file ->
            val rel = relativeName(file)
            if (rel == SELF || rel in NOT_GUARDS) return@forEach
            val text = file.readText()
            if (!looksLikeSourceReadingGuard(text)) return@forEach
            if (usesSharedStripping(text)) return@forEach
            seen += rel
            if (rel !in LEGACY_UNSTRIPPED) offenders += rel
        }

        val stale = LEGACY_UNSTRIPPED.filter { it !in seen }.sorted()

        assertEquals(
            "以下守卫读 .kt 源码做 contains 却没有剥注释——把判据目标行注释掉就能骗绿。" +
                "改用 testutil 的 stripKotlinComments(...) / readKotlinSourceNormalized(...) / " +
                "readKotlinSourceNoStrings(...)；**不要往例外表里加行**：" +
                offenders.sorted().joinToString(separator = "\n", prefix = "\n") { "    " + it },
            emptyList<String>(),
            offenders.sorted(),
        )
        assertEquals(
            "例外表里有条目已经不再命中（文件已迁移或已删除）——请删掉对应行，棘轮只许缩不许增：" +
                stale.joinToString(separator = "\n", prefix = "\n") { "    " + it },
            emptyList<String>(),
            stale,
        )
    }

    // ───────────────────────── 2. 剥离器本体自测 ─────────────────────────

    @Test
    fun `共享剥离器必须剥掉三种注释形态`() {
        val source = listOf(
            "fun f() {",
            "    // state.autoRecordMacro = false",
            "    /* state.x = 1",
            "       /* 嵌套块注释 */ 仍是注释 */",
            "    state.ok = true",
            "}",
        ).joinToString("\n")

        val stripped = stripKotlinComments(source)

        assertFalse("行注释里的锚点不许再命中", stripped.contains("state.autoRecordMacro = false"))
        assertFalse("块注释里的锚点不许再命中", stripped.contains("state.x = 1"))
        assertFalse("嵌套块注释整体都要剥掉", stripped.contains("仍是注释"))
        assertTrue("正常代码必须保留", stripped.contains("state.ok = true"))
        assertEquals(
            "剥注释不许改变行数（报错行号还要能用）",
            source.lines().size,
            stripped.lines().size,
        )
    }

    @Test
    fun `字符串与原始字符串里的注释符号不被误剥`() {
        val normal = "val url = \"http://a/b\" // 注释"
        val normalStripped = stripKotlinComments(normal)
        assertTrue("普通字符串里的 // 不许被剥", normalStripped.contains("http://a/b"))
        assertFalse("行尾注释仍要剥掉", normalStripped.contains("注释"))

        val q3 = "\"\"\""
        val raw = "val q = ${q3}a//b /* not comment*/${q3}\nval x = 1 // 注释"
        val rawStripped = stripKotlinComments(raw)
        assertTrue("原始字符串内容必须原样保留", rawStripped.contains("a//b /* not comment*/"))
        assertTrue("原始字符串之后的代码必须还在", rawStripped.contains("val x = 1"))
        assertFalse("原始字符串之后的行尾注释照常剥", rawStripped.contains("注释"))

        val escaped = "val s = \"a\\\"//b\" // 注释"
        assertTrue(
            "转义引号后的 // 仍属字符串",
            stripKotlinComments(escaped).contains("a\\\"//b"),
        )
    }

    @Test
    fun `两档读法必须分清 保留字面量 与 中性化字面量`() {
        val noStrings = readKotlinSourceNoStrings(ADD_COURSE_PAGE)
        assertTrue("接线类判据要的是代码骨架，函数声明必须还在", noStrings.contains("fun AddCoursePage("))
        assertFalse("注释必须已剥掉（该文件注释里有 十色点阵 字样）", noStrings.contains("十色点阵"))
        assertFalse(
            "接线类判据必须抹掉字符串内容（否则日志 / 提示语里的同名片段会假绿）：" +
                "shared_info 这个 item key 是字符串字面量",
            noStrings.contains("shared_info"),
        )

        val normalized = readKotlinSourceNormalized(ADD_COURSE_PAGE)
        assertTrue(
            "「某字面量许不许出现」类判据要保留字符串内容",
            normalized.contains("shared_info"),
        )
        assertFalse("默认模式同样剥注释", normalized.contains("十色点阵"))
    }

    // ─────────────────── 3. 两个已知边界的钉桩（行为变了要显式改这里） ───────────────────

    /**
     * 边界一：`"${…}"` 插值里再嵌引号。状态机按「第一个未转义引号收尾」，会在内层引号处
     * 提前退出字符串状态——于是插值里剩下的 `//` 会被**当成真正的行注释**剥掉。
     *
     * 这不是 bug，是本剥离器刻意接受的边界（见 `testutil/SourceText.kt` 的「已知不覆盖」）。
     * 钉桩的目的：将来有人把状态机改强/改弱，这里会红，逼他显式决定。
     */
    @Test
    fun `已知边界 插值里嵌引号会让状态机提前退出字符串`() {
        val source = "val s = \"${'$'}{m[\"a//b\"]}\"\nval x = 1 // 注释"
        val stripped = stripKotlinComments(source)

        assertFalse(
            "边界现状：插值里的 // 被当成行注释，a//b 不再完整出现（完整插值解析不在范围内）",
            stripped.contains("a//b"),
        )
        assertFalse("行尾注释照常剥掉", stripped.contains("注释"))
        assertTrue("插值之后在同一行的代码片段必须还在", stripped.contains("a"))
        assertTrue("后续真实代码必须还在", stripped.contains("val x = 1"))
        assertEquals("行数不变", source.lines().size, stripped.lines().size)
    }

    /**
     * 边界二：原始字符串以**多于三个引号**收尾（`\"\"\"a\"\"\"\"`）。状态机在第一个三连引号处
     * 收尾，多出来的那个引号会被当成新字符串开头——于是其后的 `//` 不再被剥。
     *
     * 同样是刻意边界；钉桩理由同上。
     */
    @Test
    fun `已知边界 原始字符串多出引号收尾会多开一个字符串`() {
        val q3 = "\"\"\""
        val source = "val q = ${q3}a${q3}${q3}\nval x = 1 // 注释"
        val stripped = stripKotlinComments(source)

        assertTrue(
            "边界现状：多出来的引号开了新字符串，其后的 // 不再当注释",
            stripped.contains("// 注释"),
        )
        assertTrue("原始字符串内容必须还在", stripped.contains("a"))
        assertTrue("被吞进字符串的代码原文仍然可见（只是不再被当代码）", stripped.contains("val x = 1"))
        assertEquals("行数不变", source.lines().size, stripped.lines().size)
    }

    // ───────────────────────── 判据 ─────────────────────────

    /** 三件事同时成立才算「读源码的守卫」，见类注释的扫描口径。 */
    private fun looksLikeSourceReadingGuard(text: String): Boolean =
        KOTLIN_PATH_LITERAL.containsMatchIn(text) &&
            (text.contains("readText(") || text.contains("readSourceNormalized(")) &&
            text.contains(".contains(")

    private fun usesSharedStripping(text: String): Boolean =
        text.contains("stripKotlinComments(") ||
            text.contains("readKotlinSourceNormalized(") ||
            text.contains("readKotlinSourceNoStrings(") ||
            OWN_STRIPPER_PATTERN.containsMatchIn(text)

    private fun testSources(): List<File> =
        File(androidSrc(), "test/kotlin/com/mutx163/qingyu")
            .walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .sortedBy { it.absolutePath }
            .toList()

    /**
     * 测试源码的相对路径。Windows 的 [File.separatorChar] 是反斜杠，而例外表用 `/`，
     * 所以先把分隔符归一**再**截前缀（顺序反了会永远截不到，整表都成 stale）。
     */
    private fun relativeName(file: File): String =
        file.absolutePath.replace('\\', '/').substringAfter("test/kotlin/")

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
        const val ADD_COURSE_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt"

        const val SELF = "com/mutx163/qingyu/pages/sheetguard/GuardSourceStrippingPolicyTest.kt"

        /** 不是守卫、按设计不受本条扫描的文件（剥离器本体）。 */
        val NOT_GUARDS = setOf("com/mutx163/qingyu/testutil/SourceText.kt")

        /** 带引号的 `*.kt` 路径字面量：`"…/Foo.kt"`。 */
        val KOTLIN_PATH_LITERAL = Regex("\"[^\"\\n]*\\.kt\"")

        /** 自带私有剥离器（`fun strip…(`）视为已处理。 */
        val OWN_STRIPPER_PATTERN = Regex("""fun\s+strip[A-Za-z0-9_]*\s*\(""")

        /**
         * 存量守卫（迁移一份删一行，**不许加**）。
         *
         * 口径：测试源码里同时出现带引号的 `.kt` 路径 + `readText(`/`readSourceNormalized(` +
         * `.contains(`，且没有走共享剥离、也没有自带 `fun strip…(`。
         */
        val LEGACY_UNSTRIPPED = setOf(
            "com/mutx163/qingyu/app/SettingsActionDispatcherTest.kt",
            "com/mutx163/qingyu/architecture/SilentFailureCatchGuardTest.kt",
            "com/mutx163/qingyu/components/GlassSingleChainGuardTest.kt",
            "com/mutx163/qingyu/components/QingyuPageThemeSlotsGuardTest.kt",
            "com/mutx163/qingyu/components/TopBarProgressiveBlurGuardTest.kt",
            "com/mutx163/qingyu/core/QingyuAdaptiveRulesTest.kt",
            "com/mutx163/qingyu/NotificationLaunchPageContractTest.kt",
            "com/mutx163/qingyu/NotificationLaunchShellWiringGuardTest.kt",
            "com/mutx163/qingyu/NotificationLaunchTargetGuardTest.kt",
            "com/mutx163/qingyu/pages/diagnostics/MemoryStatsCollectorKeyCompatTest.kt",
            "com/mutx163/qingyu/pages/exam/ExamDialogMountGuardTest.kt",
            "com/mutx163/qingyu/pages/import/IcsImportModelTest.kt",
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseCoursesImportApplyTest.kt",
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPageWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginUiGuardTest.kt",
            "com/mutx163/qingyu/pages/schedule/ScheduleDateRuleApplyWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/schedule/ScheduleDialogGuardTest.kt",
            "com/mutx163/qingyu/pages/schedule/ScheduleOccurrenceScopeTest.kt",
            "com/mutx163/qingyu/pages/settings/SettingsPreviewCutoutGuardTest.kt",
            "com/mutx163/qingyu/pages/settings/SettingsRowRenderingCapabilityGuardTest.kt",
            "com/mutx163/qingyu/pages/settings/SettingsSharedParityTest.kt",
            "com/mutx163/qingyu/pages/settings/WallpaperEvictionWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/DockInkFallbackGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/DockInkGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/DockPagerWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/DockSwitchNoDayReplayGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/HomeBackToRootGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/HomeDockInkBandsWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/HomeMenuEntryDestinationGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/HomeMenuPreviewWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/HomePullQuickImportWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/RootEntryBackGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/ScheduleEditWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/shell/ShellRailWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/sync/ButtonContrastGuardTest.kt",
            "com/mutx163/qingyu/pages/timetable/DayViewOverlayPerfWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/timetable/TimetableProfilesDialogGuardTest.kt",
            "com/mutx163/qingyu/pages/timetable/TimetableShareImageModelTest.kt",
            "com/mutx163/qingyu/pages/timetable/WeekViewCoupleOverlayWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/timetable/day/DayAgendaWallpaperInkWiringGuardTest.kt",
            "com/mutx163/qingyu/pages/timetable/day/DayViewColorTokenGuardTest.kt",
            "com/mutx163/qingyu/pages/timetable/day/DayViewStringsParityTest.kt",
            "com/mutx163/qingyu/pages/topbar/TopBarActionGlassGuardTest.kt",
            "com/mutx163/qingyu/pages/transfer/PickupCodesPageGuardTest.kt",
            "com/mutx163/qingyu/WidgetWakeupSourceGuardTest.kt",
        )
    }
}
