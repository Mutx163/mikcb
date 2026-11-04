package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 页面级主滚动收口守卫（2026-11-04 建立，timetable 域）。
 *
 * ## 钉的是什么
 *
 * `TimetableProfilesPage` 原本是 `Box(padding(innerPadding))` → `Column` → 裸 `LazyColumn`，
 * Toast 浮层也一起躺在带内边距的 Box 里。收口后列表走 `QingyuPageList`，
 * 外层 Box 只负责把 Toast 压上去（Toast 自己补 `innerPadding` 底部偏移）。
 *
 * ## 判据
 *
 * 行首锚定（允许前导空白）；注释行先剥掉，`QingyuPageList(` 被注释掉 → 红，
 * 行首重新出现 `LazyColumn(` → 红。找不到文件按失败处理。
 */
class TimetableProfilesScrollGuardTest {

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
            "composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt",
        )

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

    private val startsWithPageList = Regex("(?m)^\\s*QingyuPageList\\s*\\(")
    private val startsWithBareLazyColumn = Regex("(?m)^\\s*LazyColumn\\s*\\(")

    @Test
    fun `页面级主滚动必须走 QingyuPageList`() {
        assertTrue(
            "TimetableProfilesPage.kt 里没有行首的 QingyuPageList( —— 主滚动可能被改回裸 LazyColumn， " +
                "或者调用被注释掉了（注释掉也算失效）。",
            startsWithPageList.containsMatchIn(read()),
        )
    }

    @Test
    fun `不许再出现行首裸 LazyColumn`() {
        assertTrue(
            "TimetableProfilesPage.kt 里出现了行首 LazyColumn( —— 页面级主滚动必须走 QingyuPageList。",
            !startsWithBareLazyColumn.containsMatchIn(read()),
        )
    }

    @Test
    fun `Toast 必须自己补 innerPadding 底部偏移`() {
        // 列表不再由外层 Box 吃 innerPadding，Toast 也就失去了那份底部内边距；
        // 漏补的话 Toast 会压到系统手势条上。
        val text = read()
        assertTrue(
            "Toast 浮层没有补 innerPadding.calculateBottomPadding() 的底部偏移（会压到手势条上）。",
            Regex("""padding\([\s\S]{0,120}?bottom = innerPadding\.calculateBottomPadding\(\)""")
                .containsMatchIn(text),
        )
        assertTrue(
            "QingyuPageList 调用里没有 scrollBehavior（折叠大标题收不起来）。",
            Regex("QingyuPageList\\([\\s\\S]{0,600}?scrollBehavior").containsMatchIn(text),
        )
    }
}
