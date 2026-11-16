package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 顶栏玻璃带「首帧就有玻璃」守卫（2026-11-08 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户口径（2026-11-08 原话）：「进入外观编辑页面的过程中，星期栏会变成透明的一瞬间，
 * 然后又变回来」。
 *
 * 根因不是壁纸 / 墨色 / 转场，而是这条带子的**几何要等状态回填**：
 * `bandSize` 由 `onSizeChanged` 写入、初值是 `IntSize.Zero`，液态档首帧只能走
 * 「什么都不画」的分支 ⇒ 带子裸透一帧（露出未模糊、未染色的壁纸）⇒ 下一帧玻璃回来。
 * 进外观编辑页之所以最显眼：预览卡是**整棵新组合**，且入场从整屏缩进卡片，这一帧正好
 * 落在用户眼前。
 *
 * ## 钉住的四条（改这里必须做咬合探针）
 *
 * 1. 玻璃节点挂 `Modifier.matchParentSize()`：带子尺寸在**同一次测量**里由 Box 的固定
 *    约束给出（`min == max == 带子尺寸`），不是量完之后回填的状态；
 * 2. `bandGlassOverhang` 只收外溢量（`Dp`），自己从 `constraints` 读带子尺寸
 *    —— 不许再加回尺寸参数；且**上报的尺寸必须等于带子尺寸**：`matchParentSize()` 写的
 *    父数据里 `alignment` 是 `Alignment.Center`，报小了（特别是 `0×0`）会被居中摆放，
 *    玻璃就从带子中心往右下画（2026-11-08 截图实报「模糊跑到右半边」）；
 * 3. 组件里不许再出现 `onSizeChanged` / `bandSize` / `IntSize.Zero`
 *    （＝「等尺寸」那条路不能回流）；
 * 4. 折射夹具的带盒高必须来自**绘制期**尺寸（`size.height - overdrawDp.roundToPx()`），
 *    否则要么用错高度、要么又绕回状态。
 *
 * ## 咬合探针（改这条测试或改接线时必须做）
 *
 * - 把 `.matchParentSize()` 换回 `.onSizeChanged { bandSize = it }` → 断言 1 / 3 必红；
 * - 给 `bandGlassOverhang` 加回 `bandSize: IntSize` 参数 → 断言 2 必红；
 * - 把 `layout(constraints.maxWidth, constraints.maxHeight)` 改回 `layout(0, 0)`
 *   → 断言 2 必红（这就是「模糊跑到右半边」那个事故的写法）；
 * - 把带盒高改回 `bandSize.height` 常量 / 改用 `size.height` 不减外溢 → 断言 4 必红；
 * - 删掉 `drawBackdrop(` / `lens(` → 断言 5 必红（组件被掏空也算失败）。
 *
 * ## 为什么读源码文本
 *
 * Compose 的布局 / 绘制在纯 JVM 里跑不起来（`drawBackdrop` 还要 RuntimeShader）。
 * 与 `TimetableBandRefractionGuardTest` / `GlassSingleChainGuardTest` 同一套路：
 * 只钉「必须出现的最小集合」和「不许回流的写法」。负向断言先剥注释，免得注释里的
 * 历史说明把守卫判红；源文件找不到时**失败而不是跳过**——跳过等于守卫不存在。
 */
class BandGlassFirstFrameGuardTest {

    private val bandGlassSource: String by lazy { stripComments(readAndroidSource(BAND_GLASS_PATH)) }
    private val overhangSource: String by lazy { stripComments(readAndroidSource(OVERHANG_PATH)) }

    @Test
    fun `玻璃节点必须从同一趟布局拿到带子尺寸`() {
        assertTrue(
            "玻璃节点没有挂 Modifier.matchParentSize()——带子尺寸又回到了「先量完再回填」的路，" +
                "首帧没有几何可用，液态档只能先不画（星期栏裸透一帧会复发）。",
            Regex("""matchParentSize\(\)\s*\.\s*bandGlassOverhang\(""").containsMatchIn(bandGlassSource),
        )
        assertTrue(
            "bandGlassOverhang 的入参必须是外溢量本身（overdrawDp）——尺寸从 constraints 读。",
            bandGlassSource.contains("bandGlassOverhang(overdrawDp)"),
        )
    }

    @Test
    fun `组件里不许再等尺寸回填`() {
        assertFalse(
            "TimetableChromeBandGlass 又出现了 onSizeChanged：那是「首帧没有尺寸」的源头。",
            bandGlassSource.contains("onSizeChanged"),
        )
        assertFalse(
            "TimetableChromeBandGlass 又出现了 bandSize 状态：尺寸必须在同一次布局里读完。",
            bandGlassSource.contains("bandSize"),
        )
        assertFalse(
            "TimetableChromeBandGlass 又出现了 IntSize.Zero 分支：液态档首帧必须真的画玻璃，" +
                "不能再有「尺寸为零先不画」的退路。",
            bandGlassSource.contains("IntSize.Zero"),
        )
        assertFalse(
            "液态档分支又加上了尺寸判据（blurBackdrop != null && …）：会退回首帧不画。",
            Regex("""blurBackdrop\s*!=\s*null\s*&&""").containsMatchIn(bandGlassSource),
        )
    }

    @Test
    fun `外溢修饰符自己从约束读带子尺寸`() {
        assertTrue(
            "bandGlassOverhang 不再从 constraints 读带子尺寸——它必须用" +
                "matchParentSize 给的固定约束（constraints.maxWidth / maxHeight）。",
            overhangSource.contains("constraints.maxWidth") && overhangSource.contains("constraints.maxHeight"),
        )
        assertTrue(
            "bandGlassOverhang 已经没有「带子尺寸」入参了：只收 overdrawDp: Dp。",
            Regex("""fun Modifier\.bandGlassOverhang\(\s*overdrawDp:\s*Dp\s*,?\s*\)""")
                .containsMatchIn(overhangSource),
        )
        assertFalse(
            "bandGlassOverhang 又收回了默认值 / 尺寸参数（bandSize / IntSize）。",
            overhangSource.contains("bandSize") || overhangSource.contains("IntSize"),
        )
        assertTrue(
            "外溢节点不能「不占位」上报（layout(0, 0)）：matchParentSize 的父数据带 Center 对齐，" +
                "报 0×0 会被摆到盒子中心 ⇒ 玻璃从中心往右下画（模糊跑到右半边那个事故）。",
            !overhangSource.contains("layout(0, 0)"),
        )
        assertTrue(
            "外溢节点必须上报**带子尺寸**（layout(constraints.maxWidth, constraints.maxHeight)）：" +
                "这样任何对齐方式算出的偏移都是 (0, 0)，且 LayoutCoordinates 是真实带子矩形。",
            Regex("""layout\(\s*constraints\.maxWidth\s*,\s*constraints\.maxHeight\s*\)""")
                .containsMatchIn(overhangSource),
        )
        assertTrue(
            "外溢节点必须仍然往左上角摆（place(-overdrawPx, -overdrawPx)）。",
            Regex("""place\(-overdrawPx,\s*-overdrawPx\)""").containsMatchIn(overhangSource),
        )
    }

    @Test
    fun `折射三参数必须来自同一份材质快照`() {
        // 2026-11-16 重做 + 单链收敛：带子不再手拼 GlassSpec，改为
        // `GlassSpecResolver.resolve(material.bandGlassTuning()… )` —— 参数只在 resolver 里解释一次，
        // 与底栏/页面脚手架同一条链（`GlassSingleChainGuardTest` 钉的就是这条）。
        assertTrue(
            "带子没有走 GlassSpecResolver.resolve( —— 又回到手拼 GlassSpec 的老路。",
            bandGlassSource.contains("GlassSpecResolver.resolve("),
        )
        assertTrue(
            "带子没有从材质快照取参数（material.bandGlassTuning()）—— 玻璃参数会与底栏漂开。",
            bandGlassSource.contains("material.bandGlassTuning()"),
        )
        assertFalse(
            "带子又开始手拼 GlassSpec( —— 玻璃参数必须只在 resolver 里解释一次。",
            bandGlassSource.contains("GlassSpec("),
        )
        assertFalse(
            "色散又被强制关闭（dispersion = 0f）——2026-11-16 已开回：除 halfSize 的除零路径" +
                "由 LiquidLens 入口的零尺寸守卫兜底（size ≤ 0 这一帧不挂折射）。" +
                "要关请先更新这条判据并跑一遍探针。",
            bandGlassSource.contains("dispersion = 0f"),
        )
        assertTrue(
            "LiquidLens 的零尺寸守卫不在场——首帧 size=0 时色散着色器会除 halfSize 出非法坐标。",
            stripComments(readAndroidSource(LENS_PATH)).contains("if (size.width <= 0f || size.height <= 0f) return"),
        )
        assertFalse(
            "带子又开始自己调 timetableBandRefraction 了——折射统一走共享件的 lens。",
            bandGlassSource.contains("timetableBandRefraction("),
        )
        assertFalse(
            "带盒高又改回了非绘制期来源（bandSize / IntSize）——首帧会拿到 0。",
            bandGlassSource.contains("bandSize") || bandGlassSource.contains("IntSize"),
        )
    }

    @Test
    fun `玻璃链本身没被掏空`() {
        // 2026-11-16 重做：顶栏不再自己拼 drawBackdrop + vibrancy + blur + lens + 染色，
        // 改为调共享件 QingyuGlassSurface（坞 / 浮钮 / 卡片 / 页面球同一处实现）。
        assertTrue(
            "顶栏没有走共享件 QingyuGlassSurface —— 又回到自己拼玻璃链的老路（折射会再次失效）。",
            bandGlassSource.contains("QingyuGlassSurface("),
        )
        assertTrue(
            "采样 padding 没有交给共享件（samplingPaddingDp = BAND_SAMPLING_PADDING_DP）——" +
                "折射会再次取不到外圈像素。",
            bandGlassSource.contains("samplingPaddingDp = BAND_SAMPLING_PADDING_DP"),
        )
        assertFalse(
            "顶栏又出现了自己拼的 drawBackdrop( —— 那是重做前那条独立实现。",
            bandGlassSource.contains("drawBackdrop("),
        )
        assertFalse(
            "顶栏又出现了自己拼的 lens( —— 折射必须走共享件。",
            bandGlassSource.contains("lens("),
        )
        assertFalse(
            "顶栏又出现了自己拼的染色（onDrawSurface）—— 染色改走共享件的 tintBrush。",
            bandGlassSource.contains("onDrawSurface"),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具
    // ------------------------------------------------------------------

    /** 剥掉块注释与行注释；字符串字面量保持原样（只用于正向 / 负向关键词判据）。 */
    private fun stripComments(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            // Gradle 通常以 android/ 为工作目录。
            val direct = File(dir, relative.removePrefix("android/"))
            if (direct.isFile) return direct.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val BAND_GLASS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableChromeBandGlass.kt"
        const val OVERHANG_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/BandGlassOverhang.kt"
        const val LENS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/liquid/LiquidLens.kt"
    }
}
