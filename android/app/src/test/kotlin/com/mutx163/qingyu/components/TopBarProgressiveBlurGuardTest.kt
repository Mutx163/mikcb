package com.mutx163.qingyu.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 子页顶栏玻璃守卫（2026-11-02 建立；2026-11-07 晚改为**单次模糊 + 纵向渐变权重**，已登记自研例外）。
 *
 * ## 它钉住的是什么（当前方案实质，不是放水）
 *
 * 用户口径：顶部要“渐变模糊”——上面厚、向下连续变清、到底边自然消失；**不能整块均匀高斯，
 * 不能滚动时闪，不能底部切一条硬线，也不能顶部变透明**。
 *
 * 三种做法已经过真机，本守卫把失败原因也钉进反向断言：
 *
 * 1. miuix 官方渐进档（多层合成）：滚动时两层采样错位 → 闪。⇒ 顶栏**不得**出现 `ProgressiveBlur`；
 * 2. 均匀模糊 + 只变白纱：模糊本身是平的，仍是“整块高斯” ⇒ 必须有纵向权重乘在
 *    **模糊输出**上（`fadeEndFraction` → `QingyuVerticalFade` 着色器，不是乘在玻璃面上）；
 * 3. 只变白纱且顶部很淡：顶部不够“实” ⇒ 白纱顶边 0.60，且**跟着可见栏高收缩**
 *    （固定几何会在收起时被裁成一条均匀白带——用户 2026-11-07 截图实报）。
 *
 * 具体钉住：
 * - 顶栏走共享件 `QingyuGlassSurface`，`progressive = null`（单次模糊），纵向权重走 `fadeEndFraction`；
 * - 权重按**当前可见栏高**归一化（`barHeightOffsetPx()` 在绘制期读），底边恒为 0；
 * - 着色器坐标以 `y = 0` 为**顶**（Skia / AGSL 约定），并减掉 blur 图层的 padding；
 * - 白纱是 `Brush.verticalGradient`：`0.00f to tint` 最浓，向下 55% → 18% → `1.00f * f` 透明；
 *   末尾**不得**再压回不透明页底色（那会在栏底切一条硬边，用户 2026-11-08 截图实报）；
 * - 模糊面高度 = 展开高度 + 内容间距，Layout 高度含内容间距。
 *
 * ## 为什么是文本守卫
 *
 * Compose 的绘制效果在纯 JVM 里跑不起来（`drawBackdrop` 依赖 RuntimeShader / 设备）。
 * 和 `PageScaffoldGuardTest` 同一套路：只钉“必须出现的最小集合”与关键数字，不规定书写格式。
 * 找不到源文件时**失败而不是跳过**——跳过等于守卫不存在。
 *
 * ## 咬合探针（改这条测试或改接线时必须做）
 *
 * - 把 `progressive = null` 改回 `progressive = QingyuTopBarGradient` → 渐进档断言必红；
 * - 把 `fadeEndFraction = if (underHeader)` 删成 `fadeEndFraction = null` → 渐变断言必红；
 * - 把 `barHeightOffsetPx()` 换回常量 → “跟随可见栏高”断言必红；
 * - 把着色器的 `coord.y - in_topY` 改回 `1.0 - (coord.y / in_maxY)`（方向翻转）→ `weights from top` 断言必红；
 * - 把末尾 `1.00f * f to Color.Transparent` 改回 `1.00f * f to pageBackground` → 收尾断言必红；
 * - 把 `LightTintAlpha` 改回 0.62 / `DarkVeilAlpha` 改回 0.24 → `numbers` 必红。
 */
class TopBarProgressiveBlurGuardTest {

    /**
     * miuix 的「半径 → sigma」换算系数：`BLUR_RADIUS_TO_SIGMA = 0.45f`
     * （`top.yukonga.miuix.kmp.blur` 的 `blur/internal/BlurEffect.kt:22`，
     * `BackdropEffects.blur` 直接乘它）。
     *
     * **为什么在这里内联、不 import `HomeBackgroundModel.MIUIX_BLUR_SIGMA_PER_RADIUS`**：
     * 本守卫要能独立回答「顶栏的 sigma 读数有没有漂」。如果期望值直接引用被测模块的常量，
     * 那个常量被改掉时期望值会跟着一起漂，守卫永远绿——那不是守卫，是复读机。
     * 生产值的登记处仍是 `pages/shell/HomeBackgroundModel.kt`（那边已注明本守卫内联了它，
     * 改值时两边一起看）。
     */
    private val miuixBlurSigmaPerRadius = 0.45

    private fun scaffoldSource(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(
                dir,
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageScaffold.kt",
            )
            if (candidate.isFile) return candidate.readText()
            // Gradle 通常以 android/ 为工作目录。
            val direct = File(
                dir,
                "app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageScaffold.kt",
            )
            if (direct.isFile) return direct.readText()
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 QingyuPageScaffold.kt —— 守卫无法验证，按失败处理。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    /**
     * 只留代码：先把块注释 / KDoc 和行注释剥掉。
     *
     * 负向断言（不许出现 `bottomFadeBrush` 等）**必须**只看代码——注释里留一句历史说明
     * 不该把守卫判红。`PageScaffoldGuardTest` 也踩过同类假红。
     */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    private fun glassSurfaceSource(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(
                dir,
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/glass/QingyuGlassSurface.kt",
            )
            if (candidate.isFile) return candidate.readText()
            val direct = File(
                dir,
                "app/src/composeP1/kotlin/com/mutx163/qingyu/components/glass/QingyuGlassSurface.kt",
            )
            if (direct.isFile) return direct.readText()
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 QingyuGlassSurface.kt —— 守卫无法验证，按失败处理。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    @Test
    fun `top bar uses one blur pass and a top-heavy veil`() {
        val code = codeOnly(scaffoldSource())
        assertTrue(
            "顶栏必须走全站唯一玻璃件：缺少 QingyuGlassSurface(",
            code.contains("QingyuGlassSurface("),
        )
        assertTrue(
            "顶栏必须保持单次均匀模糊（progressive = null）；官方多层渐进在真机滚动会闪",
            code.contains("progressive = null"),
        )
        assertFalse(
            "顶栏不得接回 miuix 多层渐进合成（ProgressiveBlur）",
            code.contains("ProgressiveBlur"),
        )
        assertFalse(
            "顶栏不得自己拼渐进效果（progressiveTextureBlurEffect）",
            code.contains("progressiveTextureBlurEffect("),
        )
        assertFalse(
            "不得再用给模糊乘 alpha 的掩膜（backdropMask）：真机上权重没生效，底边仍硬切",
            code.contains("backdropMask"),
        )
        assertTrue(
            "顶栏骨架必须在绘制期传入当前 heightOffset",
            code.contains("barHeightOffsetPx = { scrollBehavior.state.heightOffset }"),
        )
        assertTrue(
            "必须把纵向权重交给模糊效果链（fadeEndFraction = if (underHeader) …）",
            code.contains("fadeEndFraction = if (underHeader)"),
        )
        assertTrue(
            "白纱必须自己成形且按可见栏高缩放（qingyuTopBarScrim(dark, visibleFraction, pageBackground)）",
            code.contains("private fun qingyuTopBarScrim(") &&
                code.contains("pageBackground: Color): Brush") &&
                code.contains("Brush.verticalGradient") &&
                code.contains("qingyuTopBarScrim(dark, visibleFraction, pageBackground)"),
        )
        assertTrue(
            "白纱顶部必须满浓度（0.00f to tint）",
            code.contains("0.00f to tint"),
        )
        assertTrue(
            "底部必须自己收到全透（1.00f * f to Color.Transparent）；再压回页底色会在栏底切一条硬边",
            code.contains("1.00f * f to Color.Transparent"),
        )
        assertFalse(
            "白纱末尾不得压回不透明页底色（1.00f * f to pageBackground 就是那条硬边）",
            code.contains("1.00f * f to pageBackground"),
        )
        assertFalse(
            "白纱不得再有 0.84f 全透那一档（和末尾收尾两档互揍 = 清晰文字从栏底漏出来）",
            code.contains("0.84f * f to"),
        )
        assertTrue(
            "顶栏叠色必须用页面底色（不能纯白：纯白会比页面亮一档，收起时成一条白带）",
            code.contains("pageBackground.copy(") &&
                code.contains("private fun qingyuTopBarTint(dark: Boolean, pageBackground: Color): Color"),
        )
        assertTrue(
            "暗色亮白纱 alpha 必须取 QingyuTopBarBlur.DarkVeilAlpha",
            code.contains("QingyuTopBarBlur.DarkVeilAlpha"),
        )
        assertFalse("暗色退回了灰纱 #565656", code.contains("0xFF565656"))
        assertTrue(
            "模糊面高度必须对齐内容起点（bandHeightPx + contentGapPx）",
            code.contains("bandHeightPx + contentGapPx"),
        )
        assertTrue(
            "顶栏 Layout 高度必须含内容间距（layout(width, height + contentGapPx)）",
            code.contains("height + contentGapPx"),
        )
    }

    @Test
    fun `shared glass surface keeps the official chain only`() {
        val code = codeOnly(glassSurfaceSource())
        assertFalse("共享件不得再带 backdropMask（已证伪）", code.contains("backdropMask"))
        assertFalse("共享件不得自拼 DstIn 蒙版", code.contains("BlendMode.DstIn"))
        assertTrue(
            "权重必须接在模糊效果链上（runtimeShaderEffect + in_fadeEnd）",
            code.contains("runtimeShaderEffect(") &&
                code.contains("\"QingyuVerticalFade\"") &&
                code.contains("in_fadeEnd"),
        )
        assertTrue(
            "着色器坐标必须以 y=0 为顶（Skia/AGSL 约定）：in_topY 偏移 + clamp((coord.y - in_topY) / in_maxY)",
            code.contains("coord.y - in_topY") &&
                code.contains("setFloatUniform(\"in_topY\", padding / sf)"),
        )
        assertFalse(
            "着色器不得再按“原点在底部”翻转（1 - coord.y / in_maxY 会把权重上下颠倒）",
            code.contains("1.0 - (coord.y / in_maxY)"),
        )
        assertTrue(
            "共享件必须仍能调官方渐进档（其它表面可用）",
            code.contains("progressiveTextureBlurEffect("),
        )
        assertTrue(
            "共享件必须把同一份 gradient 同时交给 effects 与 progressiveGradient",
            code.contains("gradient = progressive") && code.contains("progressiveGradient = progressive"),
        )
        assertTrue(
            "共享件必须按 GlassSpec 解释参数，不许出现第二套口径",
            code.contains("spec.blurSigmaDp") && code.contains("spec.refractionBandDp"),
        )
    }

    @Test
    fun `numbers stay pinned to the approved scheme`() {
        assertEquals("σ≈12 的模糊半径", 26f, QingyuTopBarBlur.MaxRadiusDp, 0f)
        assertEquals("浅色顶边 alpha", 0.60f, QingyuTopBarBlur.LightTintAlpha, 0f)
        assertEquals("暗色顶边 alpha", 0.60f, QingyuTopBarBlur.DarkVeilAlpha, 0f)
        assertTrue(
            "浅色顶边不能太厚（>0.7 会把模糊整个盖住，看上去只剩一条白带）",
            QingyuTopBarBlur.LightTintAlpha <= 0.7f,
        )
    }

    @Test
    fun `26dp peak keeps sigma near 12`() {
        // miuix: sigma = radius × 0.45；σ22 会把内容抹成一块颜色，“上糊下清”看不出来。
        assertEquals(
            11.7,
            QingyuTopBarBlur.MaxRadiusDp.toDouble() * miuixBlurSigmaPerRadius,
            0.2,
        )
    }

    @Test
    fun `back button glass appears only once content tucks under the bar`() {
        val code = codeOnly(scaffoldSource())
        assertTrue(
            "必须有共享玻璃图标按钮 QingyuGlassIconButton(",
            code.contains("fun QingyuGlassIconButton("),
        )
        assertTrue("圆底必须是 CircleShape", code.contains("CircleShape"))
        assertTrue("玻璃按钮必须带外浮影（Modifier.shadow）", code.contains(".shadow("))
        assertTrue("玻璃按钮必须有细边（Modifier.border）", code.contains(".border("))
        assertTrue(
            "返回键必须按「内容压到带下」才切玻璃（LocalQingyuBackButtonGlass.current）",
            code.contains("LocalQingyuBackButtonGlass.current"),
        )
        assertTrue(
            "骨架必须在顶栏子树注入压带判据（provides contentUnderHeader）",
            code.contains("LocalQingyuBackButtonGlass provides contentUnderHeader"),
        )
        assertTrue(
            "压带判据必须来自滚动量（contentOffset <），不能恒真",
            code.contains("contentOffset <"),
        )
        assertFalse(
            "返回键不得无条件走玻璃（把 current 去掉/改成 true 视为回退）",
            Regex("""LocalQingyuBackButtonGlass\.current\s*\|\|\s*true""").containsMatchIn(code),
        )
    }
}
