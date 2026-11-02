package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「恢复默认 / RGB 取色」两个弹窗必须走官方 `OverlayDialog` 的源码级守卫。
 *
 * ## 修的是什么（2026-11-02）
 *
 * 这两个弹窗原来由 `SettingsDialogFrame` 手搓：
 * `Box + Color.Black(0.45f) + QingyuCard`。后果是
 * 1. 没有 `NavigationBackHandler` —— 弹窗开着按返回键会退出设置页，而不是关弹窗；
 * 2. 没有官方 `OverlayDialog` 的遮罩层级、进出动画与大屏/IME 行为；
 * 3. 内容再套一层 `QingyuCard`，单边留白变成 24 + 16（或 16 + 16），与官方 16dp 不一致。
 *
 * 现在统一交给 `OverlayDialog`；这层守卫防止退回自绘容器。
 *
 * ## 为什么读源码文本
 *
 * composeP1 源集不进 `src/test` 的编译单元（与 [SettingsResetConfirmationGuardTest]
 * 同一套做法）。找不到文件**判失败而不是跳过**。
 */
class SettingsDialogOverlayGuardTest {

    @Test
    fun `两个弹窗都用官方 OverlayDialog 自绘遮罩已消失`() {
        val source = settingsHostSource()

        assertFalse(
            "自绘遮罩 `Color.Black.copy(alpha = 0.45f)` 必须消失（交给 OverlayDialog）",
            "Color.Black.copy(alpha = 0.45f)" in source,
        )
        assertFalse(
            "自绘容器 SettingsDialogFrame 必须删除",
            "SettingsDialogFrame" in source,
        )

        val markers = listOf(
            "internal fun SettingsConfirmResetDialog(",
            "private fun SettingsColorPickerDialog(",
        )
        val blocks = markers.map { marker -> marker to functionBlock(source, marker) }
        // 防守卫空跑：两个函数都真的被截出来了。
        assertEquals("应扫描到 2 个弹窗函数，实际 ${blocks.size}", 2, blocks.size)

        blocks.forEach { (marker, block) ->
            assertTrue("$marker 必须用官方 OverlayDialog", "OverlayDialog(" in block)
            assertTrue(
                "$marker 必须把关闭交给官方 onDismissRequest（返回键 / 点遮罩都靠它）",
                "onDismissRequest = onDismiss" in block,
            )
            assertFalse(
                "$marker 不许再套 QingyuCard（官方对话框已自带背景与 16dp 内边距）",
                "QingyuCard(" in block,
            )
        }
    }

    // ------------------------------------------------------------ 工具

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }

    private fun settingsHostSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        // 源码在 Windows 上是 CRLF；[functionBlock] 按 `\n}\n` 截行首收尾，
        // 这里先归一成 LF，否则行尾多出的 \r 会让「行首 }」永远匹配不到。
        return file.readText().replace("\r\n", "\n")
    }

    /** 截出顶层函数体：从 `marker` 起到第一个行首 `}`（顶层函数的收尾）为止。 */
    private fun functionBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        assertTrue("源码里找不到 $marker", start >= 0)
        val rest = source.substring(start)
        val end = rest.indexOf("\n}\n")
        assertTrue("$marker 的函数体没有找到行首收尾 `}`", end > 0)
        val block = rest.substring(0, end)
        assertTrue("$marker 的函数体为空", block.isNotBlank())
        return block
    }
}
