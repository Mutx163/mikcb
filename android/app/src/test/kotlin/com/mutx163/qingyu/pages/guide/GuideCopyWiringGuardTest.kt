package com.mutx163.qingyu.pages.guide

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 引导页文案接线守卫（2026-11-05 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * `GuideStrings` 里的键**定义齐全、`allTexts` 也登记了**（所以 [GuideStringsParityTest]
 * 一直是绿的），但页面上根本没有引用——文案永远上不了屏。这类「死键」编译过、文案对拍也过、
 * 甚至截图里都看不出来（那行字压根不存在），只能靠读源码判。
 *
 * ## 判据
 *
 * 1. [wired] 里每个键在 `pages/guide/UserGuidePage.kt` 里**至少有一个渲染点**
 *    （`GuideStrings.<键>` 出现在代码里；先剥注释，只写在 KDoc 里不算）。
 * 2. [pending] 里的键**必须仍然是 0 个渲染点**：一旦有人接上了，这行待办就过期，必须删掉
 *    —— 不许只进不出，否则待办会慢慢变成「已接也没人删」的假清单。
 * 3. 扫描器不许空转：composeP1 下源码文件数必须大于 100，页面文件必须存在。
 *
 * 找不到文件按失败处理（不许静默跳过），否则守卫会变成空跑。
 */
class GuideCopyWiringGuardTest {

    /** 发布版对照后必须上屏的文案键（A 类非隐私项）。 */
    private val wired: List<String> = listOf(
        // 欢迎页：两行动作的副标题（发布版 `_GuideActionTile(subtitle:)`）
        "importTimetableSubtitle",
        "restoreBackupSubtitle",
        // 系统权限页：摘要卡首句 + 列表后的提示条
        "guidePermissionsSubtitle",
        "guidePermissionsFooterHint",
        // 使用技巧页：两张卡片的首句 + 导入方式末尾的补充说明
        "guideShortNameAdviceSubtitle",
        "guideImportMethodsSubtitle",
        "guideImportMethodExtra",
    )

    /**
     * 待接（发布版有、Compose 版还没有承接区块）：键 → 缺的是什么。
     *
     * **接上之后必须从这里删掉**（判据②会红着提醒你）。
     */
    private val pending: Map<String, String> = mapOf(
        "languageSectionTitle" to
            "欢迎页还没有语言选择区块（发布版 `_buildLanguageSelector` 未迁移；" +
            "连 `languageModeLabel` 一起缺），单独挂一个「应用语言」标题会变成有标题没内容的空分组",
    )

    @Test
    fun `发布版文案键必须在引导页有渲染点`() {
        val code = pageCode()
        val missing = wired.filter { countOf(code, it) == 0 }
        assertTrue(
            "这些文案键在 pages/guide/UserGuidePage.kt 里没有任何渲染点（死键：ARB/GuideStrings " +
                "里都有、屏幕上永远看不到）：$missing。请按发布版位置接上，或说明原因后登记进 " +
                "本测试的 `pending`。",
            missing.isEmpty(),
        )
    }

    @Test
    fun `待接键一旦接上必须从待办删掉`() {
        val code = pageCode()
        val problems = pending.mapNotNull { (key, reason) ->
            val count = countOf(code, key)
            if (count > 0) {
                "$key 已经有 $count 个渲染点——请把它从 `pending` 删掉（只进不出的待办会变成假清单）。" +
                    "原登记原因：$reason"
            } else {
                null
            }
        }
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }

    @Test
    fun `扫描器没有空转`() {
        val root = composeRoot()
        val scanned = root.walkTopDown().count { it.isFile && it.extension == "kt" }
        assertTrue("只扫到 $scanned 个 composeP1 源文件，路径解析可能失效", scanned > 100)
        val page = pageFile()
        assertTrue("找不到引导页源码：${page.path}", page.isFile)
        assertTrue(
            "计数判据对明显样例没有反应（守卫等于空转）",
            countOf("Text(GuideStrings.guideImportMethodExtra.zh)", "guideImportMethodExtra") == 1 &&
                countOf("// GuideStrings.guideImportMethodExtra", "guideImportMethodExtra") == 0,
        )
    }

    // ---------------------------------------------------------------- 实现

    /** `GuideStrings.<key>` 的出现次数；注释（行注释 / 块注释 / KDoc）先剥掉。 */
    private fun countOf(code: String, key: String): Int =
        Regex("""\bGuideStrings\.${Regex.escape(key)}\b""").findAll(stripComments(code)).count()

    private fun pageCode(): String = stripComments(pageFile().readText(Charsets.UTF_8))

    private fun stripComments(text: String): String =
        text.replace(Regex("""/\*[\s\S]*?\*/"""), "")
            .lineSequence()
            .joinToString("\n") { line -> line.substringBefore("//") }

    private fun pageFile(): File =
        File(composeRoot(), "pages/guide/UserGuidePage.kt")

    private fun composeRoot(): File =
        File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu")

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
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }
}
