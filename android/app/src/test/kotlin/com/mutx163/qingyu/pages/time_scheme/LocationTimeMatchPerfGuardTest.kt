package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **地点匹配的「每次新建 Regex」不许长回来**（2026-11-10 A1 性能修复的守卫）。
 *
 * ## 为什么必须有这条
 *
 * 归一化函数的行为没变（[LocationTimeMatchNormalizeEquivalenceTest] 钉等价性），
 * 所以「把正则改回每次 new」这种回退**不会让任何行为用例变红**——它只是让时间模板页
 * 又变慢一次。唯一能自动化的信号是源码结构：
 *
 * 1. 正则必须是**文件级常量**（`BRACKETED_CONTENT`），函数体内不许再出现 `Regex(`；
 * 2. 归一化必须有缓存（`normalizeCache`），否则同一串在「课程 × 模板 × 关键词」的量级下
 *    反复重算；
 * 3. 候选关键词必须在构造时把归一化结果存下来（`patternLength`），排序比较器不许再调
 *    `normalizePattern`。
 */
class LocationTimeMatchPerfGuardTest {

    private val source: String by lazy { stripLineComments(readSource(PATH)) }

    @Test
    fun `正则只许在文件级常量里编译一次`() {
        val regexConstructions = Regex("""Regex\s*\(""").findAll(source).count()
        assertEquals(
            "`LocationTimeGroup.kt` 里出现了 $regexConstructions 处 `Regex(...)`——" +
                "归一化里的那条必须留在文件级常量（BRACKETED_CONTENT），函数体内不许每次新建",
            1,
            regexConstructions,
        )
        assertTrue(
            "找不到文件级常量 BRACKETED_CONTENT",
            source.contains("BRACKETED_CONTENT"),
        )
        assertFalse(
            "`normalizeForMatch` 里又出现了 `Regex(`——这就是「进页转圈久」的根因回退",
            normalizeBody().contains("Regex("),
        )
    }

    @Test
    fun `归一化必须有缓存`() {
        assertTrue("找不到归一化缓存 normalizeCache", source.contains("normalizeCache"))
        assertTrue(
            "normalizeForMatch 必须走缓存（先查后写），否则同一地点串会被反复重算",
            normalizeBody().contains("normalizeCache"),
        )
        assertTrue(
            "缓存必须是**有界**的（removeEldestEntry），否则长期运行会一直长",
            source.contains("removeEldestEntry"),
        )
    }

    @Test
    fun `候选关键词在构造时记住归一化结果`() {
        assertTrue(
            "CandidateKeyword 没见过 patternLength：排序比较器会退回每次调用 normalizePattern",
            source.contains("patternLength"),
        )
        assertFalse(
            "排序比较器里又出现 `normalizePattern(` 了——它会被调用 O(k·log k) 次",
            sortComparatorBody().contains("normalizePattern("),
        )
    }

    // ------------------------------------------------------------------ 定位

    /** `normalizeForMatch` 函数体（从签名到下一个顶层 `}`）。 */
    private fun normalizeBody(): String = sliceFrom("private fun normalizeForMatch(")

    /** `candidates.sortWith {` 到匹配的 `}`。 */
    private fun sortComparatorBody(): String = sliceFrom("candidates.sortWith {")

    private fun sliceFrom(marker: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到 $marker（定位失效，请同步本守卫）" }
        var depth = 0
        var index = source.indexOf('{', start).let { if (it < 0) start else it }
        val begin = index
        while (index < source.length) {
            when (source[index]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(begin, index + 1)
                }
            }
            index++
        }
        error("$marker 的括号没有闭合")
    }

    /**
     * 去掉 `//` 与块注释：KDoc 里正写着「原先每次 `Regex(...)` 新建」这句说明，
     * 不剥掉就会把**解释**当成**调用**，判据自己先红（2026-11-03 守卫同款假红）。
     */
    private fun stripLineComments(text: String): String =
        text.replace(Regex("""(?s)/\*.*?\*/"""), " ")
            .lineSequence()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val PATH = "android/app/src/main/kotlin/com/mutx163/qingyu/core/LocationTimeGroup.kt"
    }
}
