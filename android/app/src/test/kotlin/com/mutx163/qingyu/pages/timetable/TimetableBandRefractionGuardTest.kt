package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 顶栏玻璃带「底边折射」收窄守卫（2026-11-03）。
 *
 * 用户口径：作用带一宽，交界处画面被弯得上下对不上（读作「壁纸错位」）。
 * 本守卫钉住两条：
 *
 * 1. **折射必须过夹具**：`TimetableChromeBandGlass`（周/日/月三视图共用的**唯一**
 *    带子组件——两处同一套参数由「只有一处」保证）的 lens 参数必须来自
 *    [timetableBandRefraction] 的输出；把用户值直接喂 `lens`（整条带都参与折射）
 *    的写法一旦回流即红；
 * 2. **纯函数在场**：夹具判据（位移 0 ⇒ 零折射、作用带 ≤8dp、不超带盒）钉在
 *    `TimetableBandRefractionTest`，这里只钉「渲染层确实在用它」。
 *
 * 判据先整篇剥注释（字符串感知、块注释按 Kotlin 语义可嵌套）。
 */
class TimetableBandRefractionGuardTest {

    private val bandGlassSource: String by lazy { stripKotlinComments(readAndroidSource(BAND_GLASS_PATH)) }
    private val clampSource: String by lazy { stripKotlinComments(readAndroidSource(CLAMP_PATH)) }

    @Test
    fun `带子折射必须过夹具`() {
        assertTrue(
            "TimetableChromeBandGlass 没有调用 timetableBandRefraction——折射绕开了夹具，" +
                "整条带都会参与弯折（用户口径「壁纸错位」会复发）。",
            bandGlassSource.contains("timetableBandRefraction("),
        )
        assertTrue(
            "lens 的作用带参数没有来自夹具输出（bandPx）——作用带被直接用用户值喂进去了。",
            bandGlassSource.contains(Regex("""refractionHeight\s*=\s*bandPx""")),
        )
        assertFalse(
            "lens 的参数里出现了 liquidRefractionBand 直传——作用带绕开夹具。",
            bandGlassSource.contains(Regex("""liquidRefractionBand\.dp\.toPx\(\)""")),
        )
    }

    @Test
    fun `夹具纯函数必须在场`() {
        assertTrue(
            "timetableBandRefraction 纯函数被删——折射夹具判据（零位移⇒零折射、" +
                "作用带 ≤8dp、不超带盒）失效。",
            clampSource.contains("fun timetableBandRefraction("),
        )
        assertTrue(
            "夹具上限常量不在场——作用带/位移的 8dp 上限丢了。",
            clampSource.contains("TIMETABLE_BAND_REFRACTION_MAX_BAND_DP") &&
                clampSource.contains("TIMETABLE_BAND_REFRACTION_MAX_AMOUNT_DP"),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具
    // ------------------------------------------------------------------

    /** 剥掉 `//` 与块注释（可嵌套），字符串字面量感知；块注释里的换行保留。 */
    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val BAND_GLASS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableChromeBandGlass.kt"
        const val CLAMP_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/TimetableBandRefraction.kt"
    }
}
