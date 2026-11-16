package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Test

/**
 * 顶栏玻璃带接线（2026-11-16 重做后）。
 *
 * 用户实测：同一套材质参数，底栏是完美玻璃、顶栏折射拉满无作用。根因是顶栏那条**独立实现**
 * 采的是「只录壁纸」的 `pageBackdrop`，折射在纯色壁纸上等于没效果；且折射被夹具压到 8dp、
 * 采样 padding 只抬到 8dp。重做后顶栏改成调共享件 [com.mutx163.qingyu.components.glass.QingyuGlassSurface]，
 * 采样真实内容层，采样 padding 与底栏同值 40dp。
 *
 * 本测试钉四件事：① 带子确实走共享件、参数来自材质快照；② 采样 padding 与底栏同值；
 * ③ 旧的两遍玻璃 / 补色层路径已消失（不许回头补）；④ 周页把真实内容层交给带子。
 *
 * 读法：`readKotlinSourceNoStrings`（剥注释 + 字符串中性化），读不到源码直接红。
 */
class TimetableBandGlassWiringTest {

    @Test
    fun `带子走共享件且参数来自材质快照`() {
        val source = readKotlinSourceNoStrings(BAND_GLASS_PATH)
        assertSourceContains(source, "QingyuGlassSurface(", LABEL)
        assertSourceContains(source, "GlassSpec(", LABEL)
        assertSourceContains(source, "blurSigmaDp = material.liquidBlurSigma", LABEL)
        assertSourceContains(source, "refractionBandDp = material.liquidRefractionBand", LABEL)
        assertSourceContains(source, "refractionAmountDp = material.liquidRefraction", LABEL)
        assertSourceContains(source, "tintBrush = SolidColor(tint)", LABEL)
    }

    @Test
    fun `采样 padding 与底栏同值`() {
        val source = readKotlinSourceNoStrings(BAND_GLASS_PATH)
        assertSourceContains(source, "samplingPaddingDp = BAND_SAMPLING_PADDING_DP", LABEL)
        assertSourceContains(source, "BAND_SAMPLING_PADDING_DP = 40f", LABEL)
    }

    @Test
    fun `旧的两遍玻璃与补色层路径不许回来`() {
        val source = readKotlinSourceNoStrings(BAND_GLASS_PATH)
        // 自拼效果链：删了就别补回来（补回来就又会出现「采壁纸、折射无效」的老毛病）。
        assertSourceLacks(source, "onDrawSurface = { drawRect(tint) }", LABEL)
        assertSourceLacks(source, "tintTop", LABEL)
        assertSourceLacks(source, "bandTintLayerAlphas(", LABEL)
        assertSourceLacks(source, "underlayBackdrop", LABEL)
        assertSourceLacks(source, "timetableBandRefraction(", LABEL)
    }

    @Test
    fun `周页把真实内容层交给带子`() {
        val weekPage = readKotlinSourceNoStrings(WEEK_PAGE_PATH)
        assertSourceContains(weekPage, "backdrop = contentBackdrop", LABEL)
        assertSourceLacks(weekPage, "underlayBackdrop =", LABEL)
        // 内容录制层不能只在「回本周浮钮」可见时挂——顶栏也要吃它。
        assertSourceContains(weekPage, "if (pageBackdropActive || floatingGlassActive)", LABEL)
    }

    private companion object {
        const val LABEL = "TimetableChromeBandGlass"
        const val BAND_GLASS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableChromeBandGlass.kt"
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
    }
}
