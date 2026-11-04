package com.mutx163.qingyu.pages.guide

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 页面级主滚动收口守卫（2026-11-04 建立，guide 域）。
 *
 * ## 钉的是什么
 *
 * 三页原本各自在 `Column(padding(innerPadding))` 里拼裸 `LazyColumn`：
 * `StartupFlowPage` 两处（迁移引导 / 开学日期）、`MoreFeaturesPage`、`HyperosShowcasePage`。
 * 收口后统一走 `components/QingyuPageList.kt`，三件套 + 滚动条由组件负责，
 * 页面只补「顶栏下额外留白」与「底部再叠一次手势条」的历史账面。
 *
 * ## 判据
 *
 * 行首锚定（允许前导空白）。`QingyuPageList(` 被注释掉就不再是代码行 → 正向判据红；
 * 行首重新出现 `LazyColumn(` → 反向判据红。注释行先剥掉再判，避免说明性注释造成假红。
 *
 * 找不到文件按失败处理（不许静默跳过），否则守卫会变成空跑。
 */
class GuidePageScrollGuardTest {

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
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

    /** 受管文件 → 期望的 QingyuPageList 调用次数（StartupFlowPage 两个互斥步骤各一处）。 */
    private val guarded: Map<String, Int> = mapOf(
        "StartupFlowPage.kt" to 2,
        "MoreFeaturesPage.kt" to 1,
        "HyperosShowcasePage.kt" to 1,
    )

    private fun codeText(text: String): String =
        text.lineSequence().joinToString("\n") { line ->
            val trimmed = line.trimStart()
            val commented = trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")
            if (commented) "" else line.substringBefore("//")
        }

    private fun pageFile(name: String): File =
        File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages/guide/$name")

    private fun read(name: String): String {
        val file = pageFile(name)
        assertTrue("受管页面文件不存在：${file.path}", file.isFile)
        return codeText(file.readText())
    }

    private val startsWithPageList = Regex("(?m)^\\s*QingyuPageList\\s*\\(")
    private val startsWithBareLazyColumn = Regex("(?m)^\\s*LazyColumn\\s*\\(")

    @Test
    fun `页面级主滚动必须走 QingyuPageList`() {
        val offenders = guarded.mapNotNull { (name, expected) ->
            val count = startsWithPageList.findAll(read(name)).count()
            if (count == expected) null else "$name（期望 $expected 处，实际 $count 处）"
        }
        assertTrue(
            "以下 guide 页面没有按约定走 QingyuPageList（被改回裸 LazyColumn、或调用被注释掉了）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `不许再出现行首裸 LazyColumn`() {
        val offenders = guarded.keys.filter { startsWithBareLazyColumn.containsMatchIn(read(it)) }
        assertTrue(
            "以下 guide 页面里出现了行首 LazyColumn(（页面级主滚动必须走 QingyuPageList）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `走共享列表时必须把 innerPadding 与 scrollBehavior 接上`() {
        val offenders = guarded.keys.filter { name ->
            val text = read(name)
            "innerPadding = innerPadding" !in text ||
                !Regex("QingyuPageList\\([\\s\\S]{0,600}?scrollBehavior").containsMatchIn(text)
        }
        assertTrue(
            "以下 guide 页面的 QingyuPageList 没接 innerPadding / scrollBehavior" +
                "（内容钻到顶栏底下，或大标题收不起来）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }
}
