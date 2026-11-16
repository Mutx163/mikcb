package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页顶栏「更多」球必须跟着**材质档**走（2026-11-14，实体档多边形实报）。
 *
 * ## 用户看到的现象与前因
 *
 * 实体材质下右上角那颗球露出多边形底板。根因不是形状被写成多边形，而是：
 *
 * 1. 带子（`TimetableChromeBandGlass`）只有 `band == LIQUID_GLASS && hasBackdrop &&
 *    isRuntimeShaderSupported()` 才画玻璃，其它档位画不透明页底色条；
 * 2. 但那层采样源 `pageBackdrop` 是 `rememberLayerBackdrop()` 的对象、**永远不为 null**，
 *    而录制层只在 `pageBackdropActive` 为真时才挂（`Modifier.layerBackdrop`）；
 * 3. 三个视图把 `backdrop = pageBackdrop` **无条件**传给顶栏 ⇒ 实体档下球仍走玻璃分支，
 *    对着一个没录进内容的采样层做模糊。模糊把球自己圆形蒙版的边缘按降采样格量化，
 *    肉眼就是「多边形环」。
 *
 * 修法（2026-11-14 批准）：三处调用点各加一个门
 * `backdrop = pageBackdrop.takeIf { bandBlurActive }`——带子不画玻璃时传 null，
 * 球走 `HomeTopBarActionBallChrome` 已有的「实心圆」退化分支。
 *
 * ## 判据
 *
 * 三份源码各自钉住：① 本页确实算了 `bandBlurActive`（门必须有真实来源）；
 * ② 顶栏调用块里的 backdrop 必须带 `takeIf { bandBlurActive }`；③ 没退化成裸传；
 * 另钉顶栏的退化分支仍在（传 null 时有东西可画）。
 *
 * 读法：接线类，走中性化档（剥注释 + 抹字符串）——注释里提到这些名字不算数。
 * 探针见落地提交说明：任一处撤掉 `takeIf` ⇒ 本文件对应用例红。
 */
class HomeTopBarBallMaterialGuardTest {

    @Test
    fun `周视图顶栏球的采样源必须跟带子同档`() {
        assertBallGatedByBandMaterial(WEEK_PAGE_PATH)
    }

    @Test
    fun `日视图顶栏球的采样源必须跟带子同档`() {
        assertBallGatedByBandMaterial(DAY_PAGE_PATH)
    }

    @Test
    fun `月视图顶栏球的采样源必须跟带子同档`() {
        assertBallGatedByBandMaterial(MONTH_PAGE_PATH)
    }

    @Test
    fun `顶栏必须保留实心圆退化分支，传 null 时有东西可画`() {
        val topBar = readKotlinSourceNoStrings(TOP_BAR_PATH)
        // 球在 backdrop == null 时要落到底色 + 白纱的实心圆，不是「什么都不画」。
        assertSourceContains(topBar, "if (backdrop != null) {", TOP_BAR_PATH)
        assertSourceContains(
            topBar,
            "Color(QingyuTheme.scaffoldBackground(dark))",
            TOP_BAR_PATH,
        )
    }

    private fun assertBallGatedByBandMaterial(path: String) {
        val source = readKotlinSourceNoStrings(path)
        // ① 门要有真实来源：本页确实按材质判过带子要不要画玻璃。
        assertSourceContains(source, "val bandBlurActive =", path)
        // ② 球与带子必须引用**同一个对象**：2026-11-16 起带子采的是壁纸+内容合成层
        //（`bandGlassSource`），球若还单独采 `pageBackdrop`，同一根带子里就有两套口径。
        assertSourceContains(source, "val bandGlassSource = rememberCombinedBackdrop(", path)
        assertSourceContains(
            topBarCallBlock(source, path),
            "backdrop = bandGlassSource.takeIf { bandBlurActive }",
            "$path 的 TimetableTopBar 调用",
        )
        // ③ 反向：不许退回无条件裸传（那正是实体档「模糊空气」的写法），
        //    也不许退回只采壁纸层的旧口径。
        val block = topBarCallBlock(source, path)
        assertSourceLacks(block, "backdrop = bandGlassSource,", "$path 的 TimetableTopBar 调用")
        assertSourceLacks(block, "backdrop = pageBackdrop", "$path 的 TimetableTopBar 调用")
    }

    /** 从 `TimetableTopBar(` 起到本页文件末尾——只有一处调用，切到文件尾即可判全。 */
    private fun topBarCallBlock(source: String, path: String): String {
        val at = source.indexOf("TimetableTopBar(")
        assertTrue("$path 里找不到 TimetableTopBar( 调用点，判据无效", at >= 0)
        return source.substring(at)
    }

    private companion object {
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val DAY_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt"
        const val MONTH_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt"
        const val TOP_BAR_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableTopBar.kt"
    }
}
