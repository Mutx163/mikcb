package com.mutx163.qingyu.pages.exam

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 页面级主滚动收口守卫（2026-11-04 建立，exam 域）。
 *
 * ## 钉的是什么
 *
 * `ExamListPage` 原本是 `Column(padding(innerPadding))` 里的**裸** `LazyColumn`：
 * 各个页面自己拼「末端轻震 / 过度滚动 / nestedScroll」三件套，写法一多就开始漂
 * （有的漏 nestedScroll、有的漏回弹），滚动条更是靠各自记得加。收口后一律走
 * `components/QingyuPageList.kt`，三件套与滚动条由组件统一负责。
 *
 * 判据是**行首锚定**的：注释掉 `QingyuPageList(` 会直接红（代码行被注释后不再以它开头），
 * 而挪到别处的调用、内联写法都逃不过。反向那条同理——行首出现 `LazyColumn(` 就红。
 *
 * ## 为什么是源码文本守卫
 *
 * 组件编译不在任何 L0 模块里（composeP1 的 androidx 依赖 L0 解析不了），
 * 真机截图又跑不进 CI；「有没有走共享列表」是文本可判的，所以用文本守卫
 * （与 `PageScaffoldGuardTest` 同一套路）。找不到文件按失败处理，不许静默跳过。
 */
class ExamListScrollGuardTest {

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

    private val pageFile: File
        get() = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt",
        )

    /**
     * 去掉注释后的代码文本：行尾 `//` 之后一律丢掉，整行注释行置空。
     *
     * 「注释掉就红」靠的就是这一步——把 `QingyuPageList(` 注释掉之后，
     * 它不再是代码行，正向判据自然不成立。
     */
    private fun codeText(text: String): String =
        text.lineSequence().joinToString("\n") { line ->
            val trimmed = line.trimStart()
            val commented = trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")
            if (commented) "" else line.substringBefore("//")
        }

    private fun read(): String {
        val file = pageFile
        assertTrue("受管页面文件不存在：${file.path}", file.isFile)
        return codeText(file.readText())
    }

    /** 行首锚定：允许前导空白，不许出现在表达式内部。 */
    private val startsWithPageList = Regex("(?m)^\\s*QingyuPageList\\s*\\(")
    private val startsWithBareLazyColumn = Regex("(?m)^\\s*LazyColumn\\s*\\(")

    @Test
    fun `页面级主滚动必须走 QingyuPageList`() {
        val text = read()
        assertTrue(
            "ExamListPage.kt 里没有行首的 QingyuPageList( —— 主滚动可能被改回裸 LazyColumn， " +
                "或者调用被注释掉了（注释掉也算失效）。",
            startsWithPageList.containsMatchIn(text),
        )
    }

    @Test
    fun `不许再出现行首裸 LazyColumn`() {
        val text = read()
        assertTrue(
            "ExamListPage.kt 里出现了行首 LazyColumn( —— 页面级主滚动必须走 QingyuPageList， " +
                "自己拼三件套会再次漂移。",
            !startsWithBareLazyColumn.containsMatchIn(text),
        )
    }

    @Test
    fun `走共享列表时必须把 innerPadding 与 scrollBehavior 接上`() {
        val text = read()
        // 换成组件但漏传 innerPadding = 内容钻到顶栏/手势条底下；
        // 漏传 scrollBehavior = 大标题收不起来（见 PageScaffoldGuardTest）。
        assertTrue(
            "QingyuPageList 调用里没有 innerPadding = innerPadding（版面会钻到顶栏/手势条底下）。",
            "innerPadding = innerPadding" in text,
        )
        assertTrue(
            "QingyuPageList 调用里没有 scrollBehavior（折叠大标题收不起来）。",
            Regex("QingyuPageList\\([\\s\\S]{0,600}?scrollBehavior").containsMatchIn(text),
        )
    }
}
