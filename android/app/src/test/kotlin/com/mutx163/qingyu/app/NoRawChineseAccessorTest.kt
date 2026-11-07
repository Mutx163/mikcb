package com.mutx163.qingyu.app

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
                file.readLines(Charsets.UTF_8).forEachIndexed { index, line ->
                    val code = line.substringBefore("//")
                    if (Regex("""\.zh\b""").containsMatchIn(code) && !code.trimStart().startsWith("*")) {
                        offenders += "${file.relativeTo(repoRoot())}:${index + 1}: ${line.trim()}"
                    }
                }
            }
        }
        assertTrue(
            "这些地方还在直读中文原文（改成 `.text`）：\n" + offenders.joinToString("\n"),
            offenders.isEmpty(),
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

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "lib/l10n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（lib/l10n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}
