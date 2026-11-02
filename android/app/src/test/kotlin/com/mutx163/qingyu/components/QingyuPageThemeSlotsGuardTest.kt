package com.mutx163.qingyu.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 主题桥槽位守卫（2026-11-02 建立）。
 *
 * ## 它钉住的是什么
 *
 * 官方弹层默认取 `onSurface` / `onSurfaceSecondary`：
 * - `OverlayBottomSheet` 的标题用 `onSurface`（`BottomSheetContentLayout.kt`）；
 * - `OverlayDialog` 的 `summary` 正文用 `onSurfaceSecondary`（`DialogContentLayout.kt`）。
 *
 * 官方默认值是亮色纯黑 / 80% 黑，与本仓主文本 `#333`、次级文本 `#999` 对不上。
 * 如果 [qingyuLightColors] / [qingyuDarkColors] 漏桥这两槽，后果是**静默**的：
 * 编译通过、页面正常，只有底部弹层标题偏黑、对话框次级正文看起来像主文本。
 * 单测不会自己红，所以这里用源码守卫钉住。
 *
 * ## 为什么是文本守卫
 *
 * `qingyuLightColors` / `qingyuDarkColors` 是 `@Composable`，依赖 miuix / Compose 运行时，
 * 纯 JVM 单测里起不来（与 `TopBarProgressiveBlurGuardTest` 同一取舍）。
 *
 * ## 取函数体的方式
 *
 * 两个函数都是表达式体（`= lightColorScheme(...)`），没有花括号。这里剥掉注释后，
 * 从函数声明定位到 `=`，再用**括号配对**取到调用末尾——不用 `[^)]*` 硬抠，
 * 避免函数体里再嵌套括号时截断。找不到源文件或函数时**失败而不是跳过**。
 *
 * ## 咬合探针（改本测试或改主题桥时必须做）
 *
 * - 删掉亮色板的 `onSurfaceSecondary =` ⇒ 亮色那条必须红；
 * - 把 `primaryText` / `secondaryText` 对调 ⇒ 哨兵断言必须红；
 * - 还原后必须重新变绿。
 */
class QingyuPageThemeSlotsGuardTest {

    private fun themeSource(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(
                dir,
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageTheme.kt",
            )
            if (candidate.isFile) return candidate.readText()
            // Gradle 或其他入口可能以 android/app 为工作目录。
            val direct = File(
                dir,
                "app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageTheme.kt",
            )
            if (direct.isFile) return direct.readText()
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 QingyuPageTheme.kt —— 守卫无法验证，按失败处理。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    /** 只留代码：剥掉块注释 / KDoc 与行注释，避免注释里的示例文本干扰括号配对。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    /** 从 [open] 处的左括号开始，返回与之配对的右括号下标。 */
    private fun matchDelimiter(code: String, open: Int, left: Char, right: Char): Int {
        assertTrue("括号配对起点非法：$open", open in code.indices && code[open] == left)
        var depth = 0
        for (i in open until code.length) {
            when (code[i]) {
                left -> depth++
                right -> {
                    depth--
                    if (depth == 0) return i
                }
            }
        }
        throw AssertionError("括号未闭合：从下标 $open 开始")
    }

    /** 取表达式体函数 `= xxx(...)` 的完整文本（含 `=` 与调用括号）。 */
    private fun expressionBody(code: String, functionName: String): String {
        val decl = code.indexOf("fun $functionName(")
        assertTrue("未找到函数 $functionName —— 守卫失去目标，按失败处理", decl >= 0)
        val paramsOpen = code.indexOf('(', decl)
        val paramsClose = matchDelimiter(code, paramsOpen, '(', ')')
        val eq = code.indexOf('=', paramsClose)
        assertTrue("$functionName 不是表达式体，守卫取体方式需同步修改", eq >= 0)
        val callOpen = code.indexOf('(', eq)
        assertTrue("$functionName 的返回值不是函数调用，守卫取体方式需同步修改", callOpen >= 0)
        val callClose = matchDelimiter(code, callOpen, '(', ')')
        return code.substring(eq, callClose + 1)
    }

    /** 统计槽位在函数体里出现的次数（只认行首赋值，避免注释 / 子串误算）。 */
    private fun slotCount(body: String, slot: String): Int =
        Regex("""(?m)^\s*${Regex.escape(slot)}\s*=""").findAll(body).count()

    private fun assertBothSlots(body: String, scheme: String) {
        assertEquals("$scheme 必须且只能桥接一次 onSurface", 1, slotCount(body, "onSurface"))
        assertEquals(
            "$scheme 必须且只能桥接一次 onSurfaceSecondary",
            1,
            slotCount(body, "onSurfaceSecondary"),
        )
    }

    @Test
    fun `both schemes are located and non-empty`() {
        val code = codeOnly(themeSource())
        assertTrue("亮色板函数缺失", code.contains("fun qingyuLightColors("))
        assertTrue("深色板函数缺失", code.contains("fun qingyuDarkColors("))
        assertTrue(
            "亮色板取体为空，守卫会空跑",
            expressionBody(code, "qingyuLightColors").let {
                it.contains("lightColorScheme(") && slotCount(it, "background") == 1
            },
        )
        assertTrue(
            "深色板取体为空，守卫会空跑",
            expressionBody(code, "qingyuDarkColors").let {
                it.contains("darkColorScheme(") && slotCount(it, "background") == 1
            },
        )
    }

    @Test
    fun `light scheme bridges onSurface and onSurfaceSecondary`() {
        val body = expressionBody(codeOnly(themeSource()), "qingyuLightColors")
        assertBothSlots(body, "亮色板")
        // 哨兵：值必须来自本仓主 / 次级文本，且明暗档一致，防止对调或用错档位。
        assertTrue(
            "亮色板 onSurface 必须取 QingyuTheme.primaryText(dark = false)",
            body.contains("onSurface = Color(QingyuTheme.primaryText(dark = false))"),
        )
        assertTrue(
            "亮色板 onSurfaceSecondary 必须取 QingyuTheme.secondaryText(dark = false)",
            body.contains("onSurfaceSecondary = Color(QingyuTheme.secondaryText(dark = false))"),
        )
    }

    @Test
    fun `dark scheme bridges onSurface and onSurfaceSecondary`() {
        val body = expressionBody(codeOnly(themeSource()), "qingyuDarkColors")
        assertBothSlots(body, "深色板")
        assertTrue(
            "深色板 onSurface 必须取 QingyuTheme.primaryText(dark = true)",
            body.contains("onSurface = Color(QingyuTheme.primaryText(dark = true))"),
        )
        assertTrue(
            "深色板 onSurfaceSecondary 必须取 QingyuTheme.secondaryText(dark = true)",
            body.contains("onSurfaceSecondary = Color(QingyuTheme.secondaryText(dark = true))"),
        )
    }
}
