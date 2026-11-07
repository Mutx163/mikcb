package com.mutx163.qingyu.pages.statistics

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 周报开关**壳接线**守卫（2026-11-06 返工①）。
 *
 * ## 它防的是哪一类事故
 *
 * `WeeklyReportToggleLogic` 是纯逻辑、副作用全注入，`WeeklyReportToggleLogicTest` 注入的
 * 「写失败抛异常」假对象**与生产不抛不符**：真壳的 `writeSettings` lambda 曾把
 * `writeRawSettingsPatch` 的 Boolean 返回值当 Unit 丢掉 ⇒ 写失败无声吞掉、逻辑层挂在
 * `catch (Throwable)` 上的两条补偿永不执行 ⇒ pref=开、settings 真源=关的假开关，
 * 而**纯逻辑测试全绿（假绿）**。本守卫读 ShellPageIndex 源码，钉的是「真实接线里
 * 写失败必须抛」——注入假对象测得再全，也替不了接线本身。
 *
 * 为什么读源码文本：lambda 里怎么调 repository，编译产物与反射都不保留；
 * 与 `pages/sync/WebdavConnectSheetWiringGuardTest` 同一套做法（提取分支体 + 单行
 * 子串的 indexOf **顺序**断言——不碰跨行字面量，行尾/缩进变了也不失配）。
 */
class WeeklyReportShellWiringGuardTest {

    @Test
    fun `壳的writeSettings写失败必须抛异常`() {
        // 第三轮返工②判别力补洞：先**剥注释**再断言——把 `if (!` / `throw` 两行注释掉
        // 只留注释文字，源码里字符串还在，不剥注释的守卫照样全绿（洞）。
        val branch = stripComments(branchBody("e.statisticsSettings"))
        val writeIndex = branch.indexOf("writeSettings = { value ->")
        val guardIndex = branch.indexOf("if (!wiring.timetable.writeRawSettingsPatch(")
        val throwIndex = branch.indexOf("throw IllegalStateException(")
        assertTrue(
            "ShellPageIndex 周报段找不到 writeSettings lambda（接线挪走了，守卫要跟着改）。",
            writeIndex >= 0,
        )
        assertTrue(
            "writeSettings 没有检查 writeRawSettingsPatch 的返回值（`if (!`）：写失败被当 Unit " +
                "吞掉，WeeklyReportToggleLogic 的补偿（挂 catch(Throwable)）永不执行，" +
                "pref=开、settings 真源=关的假开关（2026-11-06 返工①坐实的链路）。",
            guardIndex > writeIndex,
        )
        assertTrue(
            "writeSettings 写失败没有抛异常：必须对齐 LanTransferSettingsStore.kt:48-52 的先例" +
                "（`throw IllegalStateException`），让逻辑层的补偿与页面的回滚有东西可接。",
            throwIndex > guardIndex,
        )
    }

    @Test
    fun `页面的catch必须接住壳抛出的异常`() {
        // 第三轮返工②判别力补洞：断「toggle 调用嵌在同一个 try 块里」，不是文件里
        // 随便有个 catch 就算——把 toggle 挪出 try（try 包着别的语句）原断言照样全绿。
        val raw = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSettingsPage.kt",
        )
        val page = stripComments(raw)
        val tryIndex = page.indexOf("try {", page.indexOf("onCheckedChange = { want ->"))
        val toggleIndex = page.indexOf("onWeeklyReportToggle(want)")
        val catchIndex = page.indexOf("} catch (error: Throwable)", toggleIndex)
        assertTrue(
            "找不到开关回调的 try 块（页面结构变了，守卫要跟着改）。",
            tryIndex >= 0,
        )
        assertTrue(
            "onWeeklyReportToggle(want) 不在 try 块内（被挪出 try / 压根没进 try）：壳 " +
                "writeSettings 抛出的异常没人接，界面不会回滚也不会有失败提示（链路要通到底）。",
            toggleIndex > tryIndex && catchIndex > toggleIndex,
        )
    }

    // ── 辅助：从仓库根定位 ShellPageIndex.kt 并截取指定分支体（同 WebdavConnectSheetWiringGuardTest） ──

    /**
     * 剥掉 `//` 行注释与 `/* */` 块注释（字符串字面量内的 `/` 不剥）——防「把实现
     * 注释掉、字符串还在」骗过守卫（第三轮返工②判别力补洞）。
     */
    private fun stripComments(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var inString = false
        while (i < source.length) {
            val c = source[i]
            if (inString) {
                out.append(c)
                if (c == '\\' && i + 1 < source.length) {
                    out.append(source[i + 1])
                    i += 2
                    continue
                }
                if (c == '"') inString = false
                i++
                continue
            }
            if (c == '"') {
                inString = true
                out.append(c)
                i++
                continue
            }
            if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
                while (i < source.length && source[i] != '\n') i++
                continue
            }
            if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
                i += 2
                while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) i++
                i += 2
                continue
            }
            out.append(c)
            i++
        }
        return out.toString()
    }

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

    /** 从工作目录向上找仓库根再定位文件；找不到仍判失败，守卫不许静默跳过。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private val BRANCH = Regex("""^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->""", RegexOption.MULTILINE)
}
