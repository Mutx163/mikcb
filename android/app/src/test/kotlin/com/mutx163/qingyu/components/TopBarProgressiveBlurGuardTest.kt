package com.mutx163.qingyu.components

import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 子页顶栏「渐进模糊」守卫（2026-11-02 建立）。
 *
 * ## 它钉住的是什么
 *
 * 用户要求把顶栏换成渐变模糊。Flutter 原版子页顶栏从 2026-09-23 起就锁死了渐进档
 * （`2026-09-23-lock-subpage-progressive-blur.md`），Compose 迁移时先接了均匀档
 * （`textureBlur(25f)`），本次补回。这条链路有三个**静默**失败点：
 *
 * 1. 退回 `textureBlur`：能编译、能上屏，只是顶栏又变成一整条均匀糊；
 * 2. `progressiveGradient` 与 effects 里的 `gradient` 不是同一份：miuix 不报错，
 *    draw 路径直接退回单级模糊，清晰端不再真正锐利；
 * 3. 参数漂移：半径 / 曲线 / 叠色都是从 Flutter 原版换算出来的，随手改一个数
 *    就与正式版观感对不上，而单测不会红。
 *
 * ## 为什么是文本守卫
 *
 * Compose 的绘制效果在纯 JVM 里跑不起来（`drawBackdrop` 依赖 RuntimeShader / 设备）。
 * 和 `PageScaffoldGuardTest` 同一套路：只钉「必须出现的最小集合」与关键数字，
 * 不规定书写格式。找不到源文件时**失败而不是跳过**——跳过等于守卫不存在。
 *
 * ## 咬合探针（改这条测试或改接线时必须做）
 *
 * - 把 `MaxRadiusDp` 49f 改成 25f → `numbers stay pinned` 与 `49dp peak` 必须红；
 * - 把 `progressiveGradient = QingyuTopBarGradient` 删掉 → 第 1 条必须红；
 * - 把 `drawBackdrop` 整段换回 `Modifier.textureBlur` → 第 1 条必须红。
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
     * 负向断言（不许出现 `.textureBlur(`）**必须**只看代码——注释里留一句历史说明
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
    fun `top bar uses progressive blur wiring, not uniform textureBlur`() {
        val code = codeOnly(scaffoldSource())
        assertTrue(
            "顶栏必须走全站唯一玻璃件：缺少 QingyuGlassSurface(",
            code.contains("QingyuGlassSurface("),
        )
        assertTrue(
            "顶栏必须把渐进曲线交给共享件（漏传会静默退回单级模糊）",
            code.contains("progressive = QingyuTopBarGradient"),
        )
        assertTrue(
            "渐变必须是 ProgressiveBlur.Top + 原版曲线",
            code.contains("ProgressiveBlur.Top.copy(curve = QingyuTopBarBlur.Curve)"),
        )
        assertTrue(
            "叠色必须是独立的线性 scrim（跟 Flutter 原版一样淡到透明）",
            code.contains("Brush.verticalGradient"),
        )
        assertFalse(
            "顶栏退回了均匀模糊：渐进档的顶强底清与叠色渐变都会消失",
            Regex("""(?<!progressive)\.textureBlur\s*\(""").containsMatchIn(code),
        )
        assertFalse(
            "顶栏不得绕过共享件自己拼玻璃链（drawBackdrop / blur / lens 只许出现在 QingyuGlassSurface）",
            code.contains("drawBackdrop(") ||
                Regex("""\blur\s*\(""").containsMatchIn(code) ||
                code.contains("progressiveTextureBlurEffect("),
        )
    }

    @Test
    fun `shared glass surface owns the progressive wiring`() {
        val code = codeOnly(glassSurfaceSource())
        assertTrue(
            "共享件必须调官方渐进档",
            code.contains("progressiveTextureBlurEffect("),
        )
        assertTrue(
            "共享件必须把同一份 gradient 同时交给 effects 与 progressiveGradient（漏传会静默退回单级模糊）",
            code.contains("gradient = progressive") && code.contains("progressiveGradient = progressive"),
        )
        assertTrue(
            "共享件必须按 GlassSpec 解释参数，不许出现第二套口径",
            code.contains("spec.blurSigmaDp") && code.contains("spec.refractionBandDp"),
        )
    }

    @Test
    fun `numbers stay pinned to the Flutter original`() {
        assertEquals(49f, QingyuTopBarBlur.MaxRadiusDp, 0f)
        assertEquals(0.5f, QingyuTopBarBlur.Curve, 0f)
        assertEquals(0.70f, QingyuTopBarBlur.LightTintAlpha, 0f)
        assertEquals(0.475f, QingyuTopBarBlur.DarkTintAlpha, 0f)
        assertEquals(0xFF565656, QingyuTopBarBlur.DarkTintArgb)
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
}
