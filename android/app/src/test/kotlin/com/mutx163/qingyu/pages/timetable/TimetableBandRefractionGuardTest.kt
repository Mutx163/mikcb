package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
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
    fun `带子的折射必须交给共享件`() {
        // 2026-11-16 重做：折射不再经过 8dp 夹具，也不再由带子自己调 lens；
        // 三项参数进 GlassSpec，由共享件 QingyuGlassSurface 统一调 lens。
        assertTrue(
            "TimetableChromeBandGlass 没有走共享件 QingyuGlassSurface —— 折射又回到顶栏私有链路。",
            bandGlassSource.contains("QingyuGlassSurface("),
        )
        assertTrue(
            "作用带参数没有进 GlassSpec（refractionBandDp = material.liquidRefractionBand）。",
            bandGlassSource.contains("refractionBandDp = material.liquidRefractionBand"),
        )
        assertTrue(
            "折射位移参数没有进 GlassSpec（refractionAmountDp = material.liquidRefraction）。",
            bandGlassSource.contains("refractionAmountDp = material.liquidRefraction"),
        )
        assertFalse(
            "带子又开始自己调 lens( —— 折射必须只在共享件里发生一次。",
            bandGlassSource.contains("lens("),
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

    /**
     * 非法值不许进 shader（2026-11-16 P0 追加，真机 SIGSEGV / 顶栏透明那次的处方之一）。
     *
     * 三类漏洞，少一条就会复发：
     * 1. `spec` 里的 dp 值可能 NaN / ±Inf / 负——`toPx()` 不校验，直接进 uniform；
     * 2. `NaN` 与任何数比较都是 false，所以 `> 0f` 这种守卫**挡不住 NaN**，必须在调用点
     *    再用 `isFinite()` 守一次；
     * 3. 采样 padding 必须钳上限（现在 64dp），否则采样坐标越出录制层边界。
     */
    @Test
    fun `折射参数必须过有限性保护 才进 shader`() {
        val surface = readKotlinSourceNoStrings(GLASS_SURFACE_PATH)
        assertSourceContains(
            surface,
            "fun safe(value: Float): Float = if (value.isFinite() && value > 0f) value else 0f",
            GLASS_SURFACE_PATH,
        )
        assertSourceContains(surface, "coerceAtMost(64f)", GLASS_SURFACE_PATH)

        // 调用点必须**自己也**守一次：`safe()` 只保证进 spec 的值干净，`lens(` 这一处
        // 仍要显式 isFinite，否则以后有人拿别处的值直接调 lens 就又漏了。
        assertSourceContains(
            surface,
            "refractionBandPx.isFinite() && refractionAmountPx.isFinite()",
            GLASS_SURFACE_PATH,
        )

        val lensIndex = surface.indexOf("lens(")
        assertTrue("QingyuGlassSurface 里已经没有 lens( 调用 —— 折射链被删了。", lensIndex >= 0)
        assertSourceContains(
            surface.substring(0, lensIndex),
            "isFinite()",
            "$GLASS_SURFACE_PATH 的 lens( 之前",
        )

        // 底层再守一次：NaN 骗得过 `<= 0`，所以入口必须显式 isFinite 拒绝。
        val lensSource = readKotlinSourceNoStrings(LIQUID_LENS_PATH)
        assertSourceContains(
            lensSource,
            "if (!refractionHeight.isFinite() || !refractionAmount.isFinite()) return",
            LIQUID_LENS_PATH,
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
        const val GLASS_SURFACE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/glass/QingyuGlassSurface.kt"
        const val LIQUID_LENS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/liquid/LiquidLens.kt"
    }
}
