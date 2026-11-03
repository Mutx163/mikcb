package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 弹层遮罩档守卫（2026-11-03 弹窗材质对齐批建立）。
 *
 * ## 它防的是哪一类事故
 *
 * `MiuixTheme.colorScheme.windowDimming` 是**全部弹层**（`OverlayDialog` / `OverlayBottomSheet`
 * / 列表弹层）共用的遮罩色。官方默认亮 30% / 暗 60% 黑、且全量绘制——比 NexioSchedule
 * （fork 在 `DialogContentLayout` 绘制处乘 0.6，等效 18% / 36%）重约 1.7 倍，是用户
 * 「弹窗观感简陋」的成分之一。官方 `OverlayDialog` 没有遮罩 alpha 参数，等效值只能写在
 * 主题桥的色板槽上（`QingyuPageTheme` 亮/暗两块 `windowDimming = Color.Black.copy(alpha = …)`）。
 *
 * 本守卫钉住：**两块色板都必须显式映射 `windowDimming`**。删掉任何一行 = 全部弹层静默
 * 回落官方默认重遮罩（不报错、单测不红，只有真机盯屏才看得出）——这正是本守卫要拦的。
 *
 * 判据沿用仓库源码文本守卫做法，**先剥注释再判**（`ComposeSheetGuardTest` 同款字符串感知
 * 剥离）：注释里写「windowDimming」不影响判定，两行真代码缺一即红。
 *
 * 放在 course 域：本守卫随 course 域 L0 跑（`scripts/test-kotlin-module.ps1 -Module
 * "pages/course"`）；被钉的文件在 components/，选 course 只是因为宿主域 git 状态干净，
 * 与 course 业务无归属关系。
 */
class QingyuDialogMaterialGuardTest {

    /** 判据只看**代码**：先整篇剥注释（字符串感知、块注释按 Kotlin 语义可嵌套）。 */
    private val themeSource: String by lazy {
        stripKotlinComments(readAndroidSource(THEME_PATH))
    }

    @Test
    fun `弹层遮罩档必须在亮暗两块色板上显式映射`() {
        for ((label, token) in listOf("亮色" to LIGHT_DIM_TOKEN, "深色" to DARK_DIM_TOKEN)) {
            assertTrue(
                "${label}色板缺少 $token ——全部弹层的遮罩会静默回落官方默认（亮 30%/暗 60% 黑），\n" +
                    "比 NexioSchedule ×0.6 软化档重约 1.7 倍。请恢复 QingyuPageTheme 色板上的 " +
                    "windowDimming 映射，或走例外审批改档并同步更新本守卫。",
                themeSource.contains(token),
            )
        }
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

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
        /**
         * 两行真代码的判据（NexioSchedule ×0.6 等效档：官方默认亮 30%→18%、暗 60%→36%）。
         * 判据对格式敏感：改档位时这条会先红——那是**故意的**，提醒改档的人同步更新守卫。
         */
        const val LIGHT_DIM_TOKEN = "windowDimming = Color.Black.copy(alpha = 0.18f)"
        const val DARK_DIM_TOKEN = "windowDimming = Color.Black.copy(alpha = 0.36f)"

        const val THEME_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageTheme.kt"
    }
}
