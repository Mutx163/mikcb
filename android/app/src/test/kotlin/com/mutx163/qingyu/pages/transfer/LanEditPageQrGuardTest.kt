package com.mutx163.qingyu.pages.transfer

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **局域网编辑页「有没有真的画出二维码」源码守卫**（2026-11-05 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 这一页曾经只画一行提示「电脑扫描二维码打开控制台」（`lanEditQrHint`），
 * 而页面上**没有码**：宿主也没画（`LanEditHost` 全文无二维码渲染）。用户照着提示找码，
 * 只能手打 `192.168.x.x:5xxxx`，这个入口实际不能用。
 *
 * 这类事故**编译不会红、模型层单测也全绿**（模型只负责给文本，画不画是渲染层的事），
 * 只有看渲染层源码才能发现，所以用文本守卫钉住，同仓先例 `TimeSchemeWiringGuardTest`。
 *
 * ## 钉住的事实
 *
 * 1. `LanEditPage.kt` 里必须调用 `QrMatrixCanvas(`（本域现成的绘制件，白底黑块 + 整数模块）；
 * 2. 二维码必须画在**提示行上方**（发布版 `lan_edit_screen.dart:325-347` 的顺序：码在上、提示在下）；
 * 3. 内容由 `QrEncoder.encode(` 从访问地址编出来，不是写死图或占位；
 * 4. 容器必须是**纯白底**（`Color.White`）：深色主题下反成浅底深块，摄像头按「深色 = 1」
 *    判读，对比度一反过来就扫不出。
 */
class LanEditPageQrGuardTest {

    /** 页面源码去掉 `//` 行注释——注释里写「原先没有码」不算复发。 */
    private val source: String by lazy { stripLineComments(readPageSource()) }

    @Test
    fun `会话块画出二维码且位于提示行上方()`() {
        val canvas = source.indexOf("QrMatrixCanvas(")
        val hint = source.indexOf("model.qrHint")
        assertTrue(
            "LanEditPage.kt 里没有 QrMatrixCanvas( 调用——页面又变成「只有提示、没有码」，" +
                "用户照提示找不到二维码，局域网编辑入口等于不能用",
            canvas >= 0,
        )
        assertTrue(
            "找不到 model.qrHint（定位失效，本守卫会空转）",
            hint >= 0,
        )
        assertTrue(
            "二维码必须画在二维码提示行的**上方**（发布版 lan_edit_screen.dart:325-347：" +
                "先码、后提示）",
            canvas < hint,
        )
    }

    @Test
    fun `二维码由访问地址编码且用白底容器()`() {
        assertTrue(
            "二维码内容必须由 QrEncoder.encode( 从访问地址现编，不能写死字符串/占位图",
            source.contains("QrEncoder.encode("),
        )
        assertTrue(
            "二维码容器必须是纯白底（Color.White）——深色主题下反色就扫不出",
            source.contains("Color.White"),
        )
        assertTrue(
            "没有地址时不该画码：判据要用 hasAddress，而不是把「地址不可用」那句提示编成码",
            source.contains("model.hasAddress"),
        )
    }

    // ------------------------------------------------------------------ 定位

    private fun readPageSource(): String {
        val relative = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditPage.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 LanEditPage.kt（工作目录 ${File("").absolutePath}），试过：$relative")
    }

    /** 去掉 `//` 行注释（保留换行）。 */
    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }
}
