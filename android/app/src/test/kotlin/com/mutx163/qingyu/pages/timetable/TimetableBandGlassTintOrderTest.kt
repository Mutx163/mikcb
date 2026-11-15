package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 顶栏玻璃带「染色层位置」测试（2026-11-15）。
 *
 * 用户口径：透过顶栏玻璃看底下的课程卡片时，**字是糊的、边却是锐的**；并观察到
 * 「日视图从本日滑到非本日时带子会暗一下，那一瞬间的模糊才是对的」。
 *
 * 那「暗一下」= 第二遍玻璃当帧还没录到内容，带子上只剩「壁纸模糊 + 材质染色」。
 * 稳态时第二遍把课卡糊进来，但这一遍以前**不染**，于是带子里露出的是没被压色的
 * 原色课卡（截图里是一条条鲜艳色柱）。修法：第一遍保留自己那层薄色，**第二遍画完
 * 再补一层色**，两层合成后仍等于材质面板那根 `tintAlpha`（算式见 `bandTintLayerAlphas`）。
 *
 * 本测试钉四件事：① 第一遍的 `onDrawSurface` 染色仍在（既有守卫
 * `BandGlassFirstFrameGuardTest` 的口径，两层拆分不能把它顺手删掉）；② 补色层只有一处、
 * 画在第二遍之后；③ 补色层在带子内容之前；④ 两层 alpha 来自同一个纯函数。
 *
 * ## 读法（R21 口径，2026-11-15）
 *
 * 判的是**接线 / 挂载**，不是文案，所以走 [readKotlinSourceNoStrings]（剥注释 + 字符串
 * 内容中性化）：生产代码里只要有一句含同样片段的日志或 KDoc 示例，`contains` 就会被它
 * 满足而假绿。断言统一用 [assertSourceContains] / [assertSourceLacks]——读不到源码时
 * 直接红，不许静默通过。
 */
class TimetableBandGlassTintOrderTest {

    @Test
    fun `第一遍仍在自己的玻璃表面上染色`() {
        assertSourceContains(
            bandGlassSource(),
            "onDrawSurface = { drawRect(tint) }",
            LABEL,
        )
    }

    @Test
    fun `第一遍不许退化成空染色`() {
        // 否证侧：只剩补色层、第一遍空着的话，带子下沿（没内容钻进来的那块）会变成
        // 没有底色的生采样，观感就退回「两层色各画各的」。
        assertSourceLacks(bandGlassSource(), "onDrawSurface = { }", LABEL)
    }

    @Test
    fun `补色层只有一处`() {
        assertEquals(
            "TimetableChromeBandGlass 里应当只有一处 drawRect(tintTop)；" +
                "多一处就是补了两次色，带子会被压厚一倍。",
            1,
            Regex("""drawRect\(tintTop\)""").findAll(bandGlassSource()).count(),
        )
    }

    @Test
    fun `补色层必须在第二遍玻璃之后 且在带子内容之前`() {
        val source = bandGlassSource()
        val topIndex = source.indexOf("drawRect(tintTop)")
        val underlayIndex = source.indexOf("backdrop = underlay")
        val contentIndex = source.indexOf("        content()")
        assertTrue("找不到补色层 —— 第二遍的课卡又会是没被压色的原色。", topIndex >= 0)
        assertTrue("找不到第二遍玻璃（underlay）—— 判据顺序不可信。", underlayIndex >= 0)
        assertTrue("找不到带子内容绘制点（content()）—— 判据顺序不可信。", contentIndex >= 0)
        assertTrue(
            "补色层排在了第二遍玻璃之前 —— 课卡那一遍看不到这层色，等于没修。",
            topIndex > underlayIndex,
        )
        assertTrue(
            "补色层排在了带子内容之后 —— 会把标题行 / 星期栏一起压色。",
            topIndex < contentIndex,
        )
    }

    @Test
    fun `两层 alpha 来自同一个纯函数`() {
        val source = bandGlassSource()
        assertSourceContains(source, "bandTintLayerAlphas(", LABEL)
        assertSourceContains(source, "bandTintFirstAlpha", LABEL)
        assertSourceContains(source, "bandTintTopAlpha", LABEL)
    }

    private fun bandGlassSource(): String = readKotlinSourceNoStrings(BAND_GLASS_PATH)

    private companion object {
        const val LABEL = "TimetableChromeBandGlass"
        const val BAND_GLASS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableChromeBandGlass.kt"
    }
}
