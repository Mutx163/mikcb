package com.mutx163.qingyu.app

import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 防回退闸：界面与模型层不许再读「只给中文」的 `.zh` 原文。
 *
 * 2026-11-07 把全站 2600+ 处 `.zh` 全部换成 [ArbText.text]（按当前语言取文案），
 * 并删掉了 19 个包内重复的 `data class ArbText`。这条测试守住两件事：
 *
 * 1. 谁再写 `.zh` 上屏就会被拦下（单测默认中文，肉眼看不出来，只能靠机器）；
 * 2. 不许把包内重复的 `ArbText` 定义加回来——两份同名类会让语言解析只在一半页面生效。
 */
class NoRawChineseAccessorTest {

    @Test
    fun `生产源码里不再出现点 zh 取值`() {
        val offenders = ArrayList<String>()
        for (rootName in listOf("main", "composeP1")) {
            val root = File(repoRoot(), "android/app/src/$rootName")
            root.walkTopDown().filter { it.isFile && it.extension == "kt" }.forEach { file ->
                if (file.name == "ArbText.kt") return@forEach
                // 注释一律先剥（含「续行不带星号」的块注释）：逐行 `substringBefore("//")`
                // +「行首是 * 才算注释」的启发式会把块注释正文化当代码——2026-11-12 实测误报
                // （`/* … resourceAccessor.zh … */` 被报成「直读中文原文」）。
                val rawLines = file.readLines(Charsets.UTF_8)
                for ((lineNo, _) in zhAccessorHits(file.readText(Charsets.UTF_8))) {
                    val shown = rawLines.getOrNull(lineNo - 1)?.trim().orEmpty()
                    offenders += "${file.relativeTo(repoRoot())}:$lineNo: $shown"
                }
            }
        }
        assertTrue(
            "这些地方还在直读中文原文（改成 `.text`）：\n" + offenders.joinToString("\n"),
            offenders.isEmpty(),
        )
    }

    @Test
    fun `无星号续行的块注释不算直读中文`() {
        val sample = buildString {
            appendLine("val anchor = 1")
            appendLine("/*")
            appendLine("这是没有星号续行的块注释")
            appendLine("resourceAccessor.zh")
            appendLine("*/")
            appendLine("val tail = 2")
        }
        assertEquals(
            "块注释里的 .zh 被当成代码了——行首启发式又回来了。",
            emptyList<Int>(),
            zhAccessorHits(sample).map { it.first },
        )
        assertEquals(
            "真实 .zh 读取必须仍被抓到，否则守卫会退化成永远绿。",
            listOf(1),
            zhAccessorHits("val a = arb.zh").map { it.first },
        )
    }

    @Test
    fun `ArbText 只有一份共享定义`() {
        val definitions = ArrayList<String>()
        for (rootName in listOf("main", "composeP1")) {
            val root = File(repoRoot(), "android/app/src/$rootName")
            root.walkTopDown().filter { it.isFile && it.extension == "kt" }.forEach { file ->
                file.readLines(Charsets.UTF_8).forEachIndexed { index, line ->
                    if (line.startsWith("data class ArbText(")) {
                        definitions += "${file.relativeTo(repoRoot())}:${index + 1}"
                    }
                }
            }
        }
        assertEquals(
            "`ArbText` 应只在 app/ArbText.kt 定义一次；发现：$definitions",
            1,
            definitions.size,
        )
    }

    private val ZH_ACCESSOR = Regex("""\.zh\b""")

    /**
     * 代码里出现 `.zh` 的行号（1 起，与原文行号一致）。
     *
     * 先按共享剥离器把注释整段剥掉（支持嵌套块注释 / 原始字符串），**字符串内容保留**——
     * 判据关心的是「有没有真的按 `.zh` 取值」这个访问本身，不涉及字符串里恰好写了 `.zh` 的极端情况。
     * 共享剥离器只把注释换成空格、保留换行与列，所以行号可以直接对回原文。
     */
    private fun zhAccessorHits(text: String): List<Pair<Int, String>> =
        stripKotlinComments(text).lines().mapIndexedNotNull { index, line ->
            if (ZH_ACCESSOR.containsMatchIn(line)) (index + 1) to line.trim() else null
        }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（i18n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}
