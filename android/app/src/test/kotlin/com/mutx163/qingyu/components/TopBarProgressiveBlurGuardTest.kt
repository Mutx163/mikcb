package com.mutx163.qingyu.components

import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 子页顶栏玻璃守卫（2026-11-02 建立；2026-11-04 随「换方案」改为**单档磨砂 + 两段线性白纱**）。
 *
 * ## 它钉住的是什么（新方案实质，不是放水）
 *
 * 用户口径：原来的 miuix 多级渐进 stack 观感廉价，要求换成更高级的通透做法。现方案 =
 * 单档均匀磨砂 + 两段线性白纱。本守卫钉住这五条实质，任一条被改回旧方案就红：
 *
 * 1. 顶栏玻璃走共享件 `QingyuGlassSurface`，且 **单档**（`progressive = null`），不再有
 *    `ProgressiveBlur` 多级 stack / `progressiveTextureBlurEffect`；
 * 2. 白纱是**两段纯线性 `[顶边 tint → 带底 transparent]`**（旧的「前 62% 满浓度」实心段视为红）；
 * 3. 暗色用**亮白纱**（`Color.White.copy` + `DarkVeilAlpha`），退回灰 `#565656` 视为红；
 * 4. 玻璃面/带底与**内容起点对齐**（`bandHeightPx + contentGapPx` 且 `layout(width, height + contentGapPx)`），
 *    保证底部平滑归零、无硬线；
 * 5. 不用自研转场/动画（不出现 `textureBlur(` / `drawBackdrop(` / `progressiveTextureBlurEffect(`）。
 *
 * ## 为什么是文本守卫
 *
 * Compose 的绘制效果在纯 JVM 里跑不起来（`drawBackdrop` / `BackdropFilter` 依赖 RuntimeShader / 设备）。
 * 和 `PageScaffoldGuardTest` 同一套路：只钉「必须出现的最小集合」与关键数字，不规定书写格式。
 * 找不到源文件时**失败而不是跳过**——跳过等于守卫不存在。
 *
 * ## 咬合探针（改这条测试或改接线时必须做）
 *
 * - 把 scrim 改回 `0.62f to tint`（实心段）→ 第 1 条必红；
 * - 把 `progressive = null` 改回 `progressive = QingyuTopBarGradient`（多级）→ 第 1 条必红；
 * - 把暗色改回 `Color(0xFF565656)` → 第 1 条必红；
 * - 把 `bandHeightPx + contentGapPx` 改回 `+ overhangPx` → 第 1 条必红；
 * - 把 `MaxRadiusDp` 49f 改成 25f → `numbers` 与 `49dp peak` 必红。
 */
class TopBarProgressiveBlurGuardTest {

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
     * 负向断言（不许出现 `.textureBlur(` 等）**必须**只看代码——注释里留一句历史说明
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
    fun `top bar uses single-pass blur and two-stop linear veil`() {
        val code = codeOnly(scaffoldSource())
        assertTrue(
            "顶栏必须走全站唯一玻璃件：缺少 QingyuGlassSurface(",
            code.contains("QingyuGlassSurface("),
        )
        assertTrue(
            "顶栏必须单档模糊（progressive = null）；改回多级渐进视为方案回退",
            code.contains("progressive = null"),
        )
        assertFalse(
            "顶栏退回了多级渐进 stack（出现 ProgressiveBlur）",
            code.contains("ProgressiveBlur"),
        )
        assertFalse(
            "顶栏自己拼渐进模糊（出现 progressiveTextureBlurEffect）",
            code.contains("progressiveTextureBlurEffect("),
        )
        assertFalse(
            "顶栏不得绕过共享件自己拼玻璃链（drawBackdrop / blur / textureBlur 只许在 QingyuGlassSurface）",
            code.contains("drawBackdrop(") ||
                Regex("""\blur\s*\(""").containsMatchIn(code) ||
                Regex("""(?<!progressive)\.textureBlur\s*\(""").containsMatchIn(code),
        )
        assertTrue("白纱必须是 Brush.verticalGradient", code.contains("Brush.verticalGradient"))
        assertTrue("白纱必须是两段线性：顶边满浓度（0.0f to tint）", code.contains("0.0f to tint"))
        assertTrue(
            "白纱必须两段线性：带底全透明（1.0f to tint.copy(alpha = 0f)）",
            code.contains("1.0f to tint.copy(alpha = 0f)"),
        )
        assertFalse(
            "白纱退回了旧的「前 62% 满浓度」实心段（0.62f to tint）",
            code.contains("0.62f to tint"),
        )
        assertTrue("暗色必须用亮白纱：Color.White.copy(", code.contains("Color.White.copy("))
        assertTrue(
            "暗色亮白纱 alpha 必须取 QingyuTopBarBlur.DarkVeilAlpha",
            code.contains("QingyuTopBarBlur.DarkVeilAlpha"),
        )
        assertFalse("暗色退回了灰纱 #565656", code.contains("0xFF565656"))
        assertTrue(
            "玻璃面高度必须对齐真实底边（bandHeightPx + contentGapPx）",
            code.contains("bandHeightPx + contentGapPx"),
        )
        assertTrue(
            "顶栏 Layout 高度必须含内容间距（layout(width, height + contentGapPx)），保证无硬线",
            code.contains("height + contentGapPx"),
        )
    }

    @Test
    fun `shared glass surface owns the progressive wiring`() {
        // 共享玻璃件仍保留“渐进档”能力供其它表面使用；顶栏只是不再传它。
        val code = codeOnly(glassSurfaceSource())
        assertTrue(
            "共享件必须仍能调官方渐进档（progressiveTextureBlurEffect）",
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
        assertEquals("σ≈22 的模糊半径", 49f, QingyuTopBarBlur.MaxRadiusDp, 0f)
        assertEquals("浅色白纱 alpha", 0.62f, QingyuTopBarBlur.LightTintAlpha, 0f)
        assertEquals("暗色亮白纱 alpha", 0.24f, QingyuTopBarBlur.DarkVeilAlpha, 0f)
    }

    @Test
    fun `49dp peak matches Flutter sigma 22`() {
        // miuix: sigma = radius × 0.45（常量复用 HomeBackgroundModel，别再抄第二份）。
        // Flutter 原版 sigma = 22 逻辑 px；49 × 0.45 = 22.05，所以 delta 放到 0.1。
        assertEquals(
            22.0,
            QingyuTopBarBlur.MaxRadiusDp.toDouble() * HomeBackgroundModel.MIUIX_BLUR_SIGMA_PER_RADIUS,
            0.1,
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
