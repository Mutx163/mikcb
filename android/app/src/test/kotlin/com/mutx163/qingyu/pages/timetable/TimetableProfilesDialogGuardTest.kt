package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 课表管理页五个弹层的源码级守卫（2026-11-02 建立）。
 *
 * ## 防的是什么
 *
 * `TimetableProfilesPage.kt` 原来用 `androidx.compose.ui.window.Dialog` + `QingyuCard`
 * 手搓五个弹窗：外层 24dp + 卡片 20dp/16dp，单边内容缩进约 44dp（官方口径 16dp）；
 * 确认按钮全是默认灰底，危险动作只有红字没有红底；弹层没有官方返回键 / 遮罩行为。
 * 现在：
 *
 * - 新建 / 重命名 / 清空确认 / 删除确认 → 官方 `OverlayDialog`（单边 16dp）；
 * - 更多操作 → `QingyuSheet`（Dart 是 `HyperosSheet` 底部弹层，不是居中 Dialog）。
 *
 * ## 为什么读源码文本
 *
 * composeP1 源集不进 `src/test` 的编译单元（与 [com.mutx163.qingyu.pages.settings.SettingsDialogOverlayGuardTest]
 * 同一套做法）。找不到文件 / 函数**判失败而不是跳过**，避免空跑假绿。
 */
class TimetableProfilesDialogGuardTest {

    @Test
    fun `五个弹层函数都必须被扫到`() {
        val source = pageSource()
        val blocks = EXPECTED_CONTAINERS.mapKeys { (marker, _) -> marker to functionBlock(source, marker) }
        assertEquals("应扫描到 5 个弹层函数，实际 ${blocks.size}", 5, blocks.size)
        blocks.forEach { (marker, block) ->
            assertTrue("$marker 的函数体为空，守卫会空跑", block.isNotBlank())
        }
    }

    @Test
    fun `原生 Dialog 导入与旧卡片容器都已移除`() {
        val source = pageSource()
        assertFalse(
            "还留着 `import androidx.compose.ui.window.Dialog`；五个弹层应全部改用 miuix 官方弹层",
            source.contains("import androidx.compose.ui.window.Dialog"),
        )
        EXPECTED_CONTAINERS.forEach { (marker, container) ->
            val block = functionBlock(source, marker)
            assertTrue("$marker 必须用 $container", container in block)
            assertFalse(
                "$marker 不许再套 QingyuCard（官方弹层已自带背景与 16dp 内边距）",
                "QingyuCard(" in block,
            )
        }
    }

    @Test
    fun `四个确认编辑弹窗走 OverlayDialog 且单边 16dp`() {
        OVERLAY_FUNCTIONS.forEach { marker ->
            val block = functionBlock(pageSource(), marker)
            assertTrue(
                "$marker 缺少 `insideMargin = DpSize(16.dp, 16.dp)`（单边 44dp 已收到 16dp）",
                "insideMargin = DpSize(16.dp, 16.dp)" in block,
            )
            assertTrue(
                "$marker 缺少官方 `onDismissRequest`（返回键 / 点遮罩靠它关闭）",
                "onDismissRequest = onDismiss" in block,
            )
        }
    }

    @Test
    fun `新建与重命名使用主色按钮并自动聚焦`() {
        listOf(CREATE, RENAME).forEach { marker ->
            val block = functionBlock(pageSource(), marker)
            assertTrue(
                "$marker 的确认按钮缺 `buttonColorsPrimary()`（主操作不能是默认灰底）",
                "ButtonDefaults.buttonColorsPrimary()" in block,
            )
            assertTrue("$marker 缺 FocusRequester", "FocusRequester()" in block)
            assertTrue("$marker 缺 requestFocus()，打开不会自动弹键盘", "requestFocus()" in block)
            assertTrue(
                "$marker 的输入框没挂 focusRequester",
                "focusRequester(focusRequester)" in block,
            )
            assertTrue(
                "$marker 的取消键应为 TextButton",
                "TextButton(" in block,
            )
        }
    }

    @Test
    fun `新建课表弹窗必须常驻组合 显隐只由 show 驱动`() {
        val source = pageSource()
        assertFalse(
            "禁止条件挂载：`if (showCreateDialog)` 会让官方退场动画一次都播不出来",
            source.contains("if (showCreateDialog)"),
        )
        assertTrue(
            "CreateProfileDialog 必须常驻组合，显隐由 `show = showCreateDialog` 驱动",
            source.contains("show = showCreateDialog"),
        )
    }

    @Test
    fun `清空与删除使用危险色实心按钮`() {
        listOf(CLEAR, DELETE).forEach { marker ->
            val block = functionBlock(pageSource(), marker)
            assertTrue(
                "$marker 的危险确认按钮缺 error 底色",
                "color = MiuixTheme.colorScheme.error" in block,
            )
            assertTrue(
                "$marker 的危险确认按钮缺 onError 前景色（红底灰字不可读）",
                "contentColor = MiuixTheme.colorScheme.onError" in block,
            )
            assertFalse(
                "$marker 的正文写成了两处（summary 与自绘 Text 只能二选一）",
                "summary =" in block && "style = MiuixTheme.textStyles.body2" in block,
            )
        }
    }

    // ------------------------------------------------------------ 工具

    private fun pageSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        // 源码是 CRLF；统一成 LF，函数收尾判据 `\n}\n` 才匹配得上。
        return file.readText().replace("\r\n", "\n")
    }

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

    private companion object {
        const val CREATE = "private fun CreateProfileDialog("
        const val RENAME = "private fun RenameProfileDialog("
        const val CLEAR = "private fun ClearCoursesConfirmDialog("
        const val DELETE = "private fun DeleteProfileConfirmDialog("
        const val MORE_ACTIONS = "private fun ProfileMoreActionsDialog("

        val OVERLAY_FUNCTIONS = listOf(CREATE, RENAME, CLEAR, DELETE)

        /** 函数标记 → 它必须使用的容器。 */
        val EXPECTED_CONTAINERS = mapOf(
            CREATE to "OverlayDialog(",
            RENAME to "OverlayDialog(",
            CLEAR to "OverlayDialog(",
            DELETE to "OverlayDialog(",
            MORE_ACTIONS to "QingyuSheet(",
        )
    }
}
