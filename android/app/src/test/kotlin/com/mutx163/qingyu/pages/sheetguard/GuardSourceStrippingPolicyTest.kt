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
 * ### 每条豁免都带元数据（2026-11-12）
 *
 * 表是 `Map<路径, LegacyMeta>`，一条豁免必须回答三个问题：**什么时候进来的**
 * （[LegacyMeta.introducedAt]，首次出现的 commit + 日期）、**为什么它算例外**
 * （[LegacyMeta.reason]，一句话事实，必须点名该文件的具体判据 / 私有剥离函数，不许写套话）、
 * **什么时候必须重看**（[LegacyMeta.reviewTrigger]，可机械判定的触发条件）。
 *
 * 棘轮不得有**无期限**豁免：`reviewTrigger` 全表统一为「该条目所指文件下次被 git diff
 * 触及时必须重新确认」，因此任何一次对该文件的改动都会把这条豁免变成待办。
 * **新增豁免 = 改这份代码 + 走 review**（两份元数据都要写实）；
 * **不许加运行时开关**（系统属性 / 环境变量 / 文件开关）把判据关掉——那等于给守卫开后门。
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
            // Map 的 `in` 判的是 key，与原来 Set<String> 的 membership 语义一致。
            if (rel !in LEGACY_UNSTRIPPED) offenders += rel
        }

        val stale = LEGACY_UNSTRIPPED.keys.filter { it !in seen }.sorted()

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
         * 一条豁免的全部元数据。三个字段都必填，**没有默认值**——想加一条豁免就必须回答
         * 「什么时候进来的 / 为什么算例外 / 什么时候重看」，答不出来就加不进去。
         */
        data class LegacyMeta(
            /**
             * 该文件**首次出现**的 commit（短 sha + 提交日期）。取法：
             * `git log --diff-filter=A --follow --format='%h %ad' --date=short -- <路径>`
             * （多条取最早；重命名靠 `--follow` 追到旧名）。
             */
            val introducedAt: String,
            /**
             * 一句话事实：它为什么在豁免表里。**必须点名该文件的具体判据 / 私有剥离函数**，
             * 同类可以共享措辞，但「为什么是这一条」要看得出来。
             */
            val reason: String,
            /**
             * 可机械判定的复核触发条件。[LEGACY_REVIEW_TRIGGER] 是全表统一的那一句，
             * 不写「定期检查」——「定期」等于没人负责。
             */
            val reviewTrigger: String,
        )

        /**
         * 全表统一的复核触发句。**统一成一份常量**而不是抄 44 遍：抄 44 遍就有 44 份会各自漂移，
         * 而这条句子的价值恰恰是「每一行都长一样，所以谁都没法挑一个宽松的版本留下」。
         */
        const val LEGACY_REVIEW_TRIGGER =
            "该条目所指文件下次被 git diff 触及时必须重新确认；确认后再决定修复或继续保留。"

        /**
         * 存量守卫（迁移一份删一行，**不许加**）。
         *
         * 口径：测试源码里同时出现带引号的 `.kt` 路径 + `readText(`/`readSourceNormalized(` +
         * `.contains(`，且没有走共享剥离、也没有自带 `fun strip…(`。
         *
         * 判据只读这份表的 **key**（`rel !in LEGACY_UNSTRIPPED` 判 key，`stale` 也只按 key 过滤），
         * 所以往里填元数据不会改变任何一条判定的宽严。
         */
        val LEGACY_UNSTRIPPED: Map<String, LegacyMeta> = mapOf(
            "com/mutx163/qingyu/app/SettingsActionDispatcherTest.kt" to LegacyMeta(
                introducedAt = "432727375 2026-10-28",
                reason = "主体是 dispatcher 模型用例；末条读 SettingsPageRenderers.kt，用 functionBody 截函数体 + 内联 codeOnly 行级剥注释，chips/controlCard 的 contains 仍打在原文上",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/architecture/SilentFailureCatchGuardTest.kt" to LegacyMeta(
                introducedAt = "1d0413169 2026-11-03",
                reason = "空 catch 判据委托共享词法器 KotlinCatchScanner（分词时已跳注释与字符串）；触发本扫描的 contains 打在 relativePath 上，判的是关键写路径白名单",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/components/GlassSingleChainGuardTest.kt" to LegacyMeta(
                introducedAt = "320adfa71 2026-11-03",
                reason = "扫 glass 链 API 前先过私有 codeOnly（去块注释 + 按行截 //），判的字符串是 QingyuGlassSurface 与 GlassSpec(",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/components/QingyuPageThemeSlotsGuardTest.kt" to LegacyMeta(
                introducedAt = "181b6e085 2026-11-02",
                reason = "读 QingyuPageTheme.kt 的亮/暗两个 colorScheme 函数体，codeOnly 剥注释后用 slotCount 数槽位，函数体由 matchDelimiter 自己截",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/components/TopBarProgressiveBlurGuardTest.kt" to LegacyMeta(
                introducedAt = "7d9ba9b99 2026-11-02",
                reason = "读 QingyuPageScaffold.kt 与 QingyuGlassSurface.kt 钉模糊与渐变数值，codeOnly 剥注释后逐条 contains，含暗色不许退回 #565656 的负例",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/core/QingyuAdaptiveRulesTest.kt" to LegacyMeta(
                introducedAt = "499b28d86 2026-11-03",
                reason = "读 QingyuPageScaffold.kt 与 QingyuPageList.kt 判自适应接线，codeOnly 剥注释后看 rememberQingyuWindowAdaptive() 与 widthIn(max = cap) 是否还在",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/import/IcsImportModelTest.kt" to LegacyMeta(
                introducedAt = "1b58806b0 2026-10-27",
                reason = "四十六条是 ICS 解析模型用例；末条读 IcsHeaderKeywords.kt 与解析器，用私有 cjkLiteralsIn 先滤掉星号、//、块注释开头的行再数中文字面量",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseCoursesImportApplyTest.kt" to LegacyMeta(
                introducedAt = "1f95d17ee 2026-11-03",
                reason = "扩节与回滚等十条是模型用例；末条读 WarehouseWebLoginHost.kt，判 requiredSectionCount(、WarehouseSectionExpansionDialog(、apply( 三处接线均在",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPageWiringGuardTest.kt" to LegacyMeta(
                introducedAt = "383df7435 2026-10-28",
                reason = "读 WarehouseWebLoginPage.kt 判桥接消息过 shouldDeliverBridgeMessage( 门禁、占位块不许回来；blockAfter 按花括号配平截块但不剥注释",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginUiGuardTest.kt" to LegacyMeta(
                introducedAt = "34b7a9296 2026-11-10",
                reason = "读 WarehouseWebLoginPage.kt 与 WarehouseMacroPlaybackUi.kt，判错误文案上屏、执行态换导入中、回放遮罩拦触摸；blockAfter 截块后原文 contains",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/settings/SettingsPreviewCutoutGuardTest.kt" to LegacyMeta(
                introducedAt = "5ecf2df02 2026-11-03",
                reason = "读 SettingsWeekPreview、TimetableWeekPage、AppearanceEditorScreen 等预览槽，先过私有 codeOf（去块注释 + 去行尾 //）再判挖洞件接线与假缩略图不许复活",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/settings/SettingsRowRenderingCapabilityGuardTest.kt" to LegacyMeta(
                introducedAt = "2083fa081 2026-10-29",
                reason = "只读 SettingsPageRenderers.kt，判行渲染能力 ROW_DIMMED_ALPHA、combinedClickable、bottomBar = footerSlot、topBarAction 逐条落在渲染层",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/settings/SettingsSharedParityTest.kt" to LegacyMeta(
                introducedAt = "459d7cebc 2026-10-27",
                reason = "Dart 共享件对拍（十二键登记表、locale 归一、colorFromHex 回退色）；读 SettingsRowRenderTable.kt 用 in 运算符，触发本扫描的 contains 打在文案键集合上",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/settings/WallpaperEvictionWiringGuardTest.kt" to LegacyMeta(
                introducedAt = "c26be91fd 2026-11-01",
                reason = "只读 AppearanceEditorHost.kt，判删除入口从档案原始 JSON 收集全部壁纸路径并调 WallpaperEvictionSources.planEviction(，hostSource 直接 readText",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/DockInkFallbackGuardTest.kt" to LegacyMeta(
                introducedAt = "2117a73a3 2026-11-04",
                reason = "读 HomeGlassDock.kt 与 HomeWallpaperBackdrop.kt，判亮度未知时取浅墨兜底与缓存回读；codeOnly 剥注释后再用 replace 造负例自测",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/DockInkGuardTest.kt" to LegacyMeta(
                introducedAt = "b35e425ec 2026-11-03",
                reason = "读玻璃坞、HomeGlassDock、DockInkRule 与壳，判坞墨色只走 DockInkRule.resolve( 且不含 onBackground；codeOnly 剥注释，另带守卫空转自检",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/DockPagerWiringGuardTest.kt" to LegacyMeta(
                introducedAt = "c65208abb 2026-11-03",
                reason = "读 PagesShellActivity.kt 与 ShellRoute.kt，判底栏切换必须 HorizontalPager( 加 springAnimateToPage(、不许自研转场；codeOnly 剥注释后逐条 contains",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/HomeBackToRootGuardTest.kt" to LegacyMeta(
                introducedAt = "893790123 2026-11-04",
                reason = "读 PagesShellActivity.kt 判系统返回回首页根，codeOnly 剥注释后判 systemBackBlock 内不许出现 selectRoot(ROOT_WEEK)",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/HomeDockInkBandsWiringGuardTest.kt" to LegacyMeta(
                introducedAt = "518437ff0 2026-11-08",
                reason = "读壳、坞、壁纸背板与 HomeInkBandsStore，判亮度带按视口取景落盘、三个冷读点都带 store；codeOnly 是逐字符状态机，能正确处理字符串里的双斜杠",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/RootEntryBackGuardTest.kt" to LegacyMeta(
                introducedAt = "cfb12cd90 2026-11-03",
                reason = "读 QingyuPageScaffold 与四个手拼顶栏根页，判返回键只由 rememberShellShouldShowBackButton() 决定、骨架签名不许加页面级显隐参数；codeOnly 剥注释",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/shell/ShellRailWiringGuardTest.kt" to LegacyMeta(
                introducedAt = "e2e335838 2026-11-03",
                reason = "读壳、ShellNavigationRail、HomeGlassDock、DayViewPage，判 Rail 出现时坞不组合、条目点击先弹回主屏；codeOnly 剥注释",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/sync/ButtonContrastGuardTest.kt" to LegacyMeta(
                introducedAt = "73b923ef7 2026-11-02",
                reason = "读 CoupleTimetableSettingsPage.kt 与 CoupleWebDavConnectSheet.kt，用 callArguments 与 topLevelArgument 切出着色调用，判不许 primarySurface 底配 primary 字",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/timetable/day/DayViewColorTokenGuardTest.kt" to LegacyMeta(
                introducedAt = "010c2e21f 2026-11-04",
                reason = "只读 DayViewCourseCard.kt，判非本周灰复用 WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX；readSource 直接 readText，另带守卫空转自检",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/timetable/day/DayViewStringsParityTest.kt" to LegacyMeta(
                introducedAt = "b5b8bba2f 2026-10-27",
                reason = "日视图文案逐字对拍 app_zh.arb；读 DayViewStrings.kt 只用正则抽 ArbText( 声明比集合，触发本扫描的 contains 打在 ARB 模板串上",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/topbar/TopBarActionGlassGuardTest.kt" to LegacyMeta(
                introducedAt = "925da76af 2026-11-05",
                reason = "扫二十余个页面顶栏的 actions 与 navigationIcon，判不许裸写 IconButton、待迁移颗数精确；文件先过私有 codeOf（块注释与行注释两条正则）",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/pages/transfer/PickupCodesPageGuardTest.kt" to LegacyMeta(
                introducedAt = "d29d73490 2026-11-02",
                reason = "读 PickupCodesPage.kt 与 PickupCodesHost.kt，判入口行走官方组件、忙碌态传到渲染层、无障碍标签接线；readAndroidSource 直接 readText",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
            "com/mutx163/qingyu/WidgetWakeupSourceGuardTest.kt" to LegacyMeta(
                introducedAt = "978a24d33 2026-11-07",
                reason = "读小组件 Provider、HomeWidgetStorage、WidgetRefreshWorker 与 LiveUpdateService，判广播重排、onDisabled、doWork 零实例、KEEP 周期等九条行为",
                reviewTrigger = LEGACY_REVIEW_TRIGGER,
            ),
        )
    }
}
