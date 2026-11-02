package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「恢复默认」确认链路的回归网（2026-11-01 修的四处缺陷）。
 *
 * ## 修的是什么
 *
 * 1. 确认弹窗正文只覆盖 courseCard / appearance / homeNavigation 三个作用域，其余
 *    （timetablePage / homeWidget）落到外观口径 —— 用户看到「主题、字体…」却点了
 *    「课表页 / 桌面小组件」的恢复默认；
 * 2. `HomeNavigationHost` 收到 `RESET_SCOPE` **直接落盘**，破坏性动作没有确认；
 * 3. 确认按钮用了主题那条 `themeResetToPreset`（「重置」），Dart 登记的是
 *    `settingsResetDefaultsTitle`（「恢复默认设置」）；
 * 4. 成功后没有任何提示，`settingsResetDoneMessage`（「设置已重置」）全仓 0 消费。
 *
 * ## 为什么一半是纯逻辑、一半读源码文本
 *
 * 作用域名 → 枚举 → 正文是纯 Kotlin，直接调 [SettingsResetScope.fromArg] 验证；
 * 「弹窗按枚举取正文」「RESET_SCOPE 只登记不落盘」「成功后弹提示」写在 composeP1
 * 的 Compose 源码里，`src/test` 只挂 `main` 源集，那些类根本编不进来（与
 * `SettingsHostIntentWiringGuardTest` 同一套做法）。找不到文件**判失败而不是跳过**。
 */
class SettingsResetConfirmationGuardTest {

    /** Dart `settings_reset.dart:237-247` `_confirmBody` 的五个分支，逐字对照 ARB 键。 */
    private val expectedBodies = mapOf(
        "courseCard" to "settingsResetConfirmBodyCourseCard",
        "timetablePage" to "settingsResetConfirmBodyTimetablePage",
        "appearance" to "settingsResetConfirmBodyAppearance",
        "homeNavigation" to "settingsResetConfirmBodyHomeNavigation",
        "homeWidget" to "settingsResetConfirmBodyHomeWidget",
    )

    // ------------------------------------------------------------ 纯逻辑

    @Test
    fun `五个作用域名都能反查到自己那句确认正文`() {
        expectedBodies.forEach { (arg, expectedKey) ->
            val scope = SettingsResetScope.fromArg(arg)
            assertNotNull("作用域名 $arg 反查不到枚举 —— 宿主会画不出正确的确认正文", scope)
            assertEquals("$arg 的确认正文错配", expectedKey, scope!!.confirmBody.key)
        }
    }

    @Test
    fun `五个作用域的确认正文两两不同`() {
        // 修复前 timetablePage / homeWidget 都落回外观那一句，这里必须能抓住「重复」。
        val keys = SettingsResetScope.entries.map { it.confirmBody.key }
        assertEquals(5, keys.size)
        assertEquals("五个作用域必须各说一句，不能有重复", 5, keys.toSet().size)
    }

    @Test
    fun `未知作用域返回 null 不给假正文`() {
        // 修复前未知作用域会落到 `else -> settingsResetScopeNoticeAppearance`；
        // 现在宿主拿不到枚举就不弹框、只留痕，不会画一句内容不对的正文。
        assertNull(SettingsResetScope.fromArg("nope"))
        assertNull(SettingsResetScope.fromArg(""))
    }

    // ------------------------------------------------------------ 接线守卫

    @Test
    fun `确认弹窗按枚举取正文 按钮是恢复默认设置`() {
        val dialog = functionBlock(settingsHostSource(), "internal fun SettingsConfirmResetDialog(")
        assertTrue(
            "确认正文必须取 scope.confirmBody（五个作用域的唯一真源）",
            "scope.confirmBody" in dialog,
        )
        assertTrue(
            "确认按钮应是 settingsResetDefaultsTitle（「恢复默认设置」）",
            "settingsResetDefaultsTitle" in dialog,
        )
        assertFalse(
            "确认按钮不许再用主题那条 themeResetToPreset（「重置」）",
            "themeResetToPreset" in dialog,
        )
        assertFalse(
            "未知作用域不许落回外观口径（settingsResetScopeNoticeAppearance）",
            "settingsResetScopeNoticeAppearance" in dialog,
        )
        // 危险色的载体随 2026-11-02「危险操作改实心红」一起从 theme/ 固定 token
        // 换成了官方语义槽 `MiuixTheme.colorScheme.error`（`9a4f1a7e`）；判据跟着事实走，
        // 但仍然要求「实心红底 + onError 字」，不许退回默认灰。
        assertTrue(
            "Dart 传了 destructive: true，确认按钮必须用危险色（error / onError）",
            "MiuixTheme.colorScheme.error" in dialog &&
                "MiuixTheme.colorScheme.onError" in dialog,
        )
    }

    @Test
    fun `SettingsHost 的恢复默认只登记 确认前不落盘`() {
        val action = functionBlock(settingsHostSource(), "fun onRowAction(")
        val branch = action
            .substringAfter("SettingsActionKind.RESET_SCOPE ->")
            .substringBefore("SettingsActionKind.COLOR_PICKER")
        assertTrue("RESET_SCOPE 必须先经 SettingsResetScope.fromArg", "SettingsResetScope.fromArg" in branch)
        assertTrue("点行只登记待确认作用域", "pendingReset" in branch)
        assertFalse("确认前不许调 applyResetScope 落盘", "applyResetScope(" in branch)
    }

    @Test
    fun `首页与导航先弹确认再落盘 成功后给提示`() {
        val host = functionBlock(settingsHostSource(), "fun HomeNavigationHost(")
        assertTrue("必须先登记待确认作用域", "pendingReset" in host)
        assertTrue("必须弹同一份确认弹窗", "SettingsConfirmResetDialog(" in host)
        assertTrue("作用域走 SettingsResetScope.fromArg", "SettingsResetScope.fromArg" in host)
        val branch = host
            .substringAfter("SettingsActionKind.RESET_SCOPE ->")
            .substringBefore("else ->")
        assertFalse("确认前不许直接落盘", "applyResetScope(" in branch)
        assertTrue("成功后必须提示 settingsResetDoneMessage", "settingsResetDoneMessage" in host)
    }

    @Test
    fun `桌面小组件复用同一份确认弹窗 不再自己抄一份`() {
        val source = homeWidgetSource()
        assertFalse(
            "HomeWidgetResetConfirmDialog 已收敛到 SettingsHost 那份，不许再出现",
            "HomeWidgetResetConfirmDialog" in source,
        )
        assertTrue("必须复用 SettingsConfirmResetDialog", "SettingsConfirmResetDialog(" in source)
        assertTrue("作用域走 SettingsResetScope.fromArg", "SettingsResetScope.fromArg" in source)
        assertTrue("成功后必须提示 settingsResetDoneMessage", "settingsResetDoneMessage" in source)
    }

    @Test
    fun `设置族两处重置成功都要给提示`() {
        // SettingsHost.applyReset（覆盖 b.reset 等页）与 HomeNavigationHost 各一处。
        val count = Regex("settingsResetDoneMessage")
            .findAll(settingsHostSource())
            .count()
        assertTrue("SettingsHost.kt 应有两处完成提示，实际 $count", count >= 2)
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

    private fun settingsHostSource(): String = composeSource("SettingsHost.kt")

    private fun homeWidgetSource(): String = composeSource("HomeWidgetHost.kt")

    private fun composeSource(name: String): String {
        val file = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/app/$name")
        assertTrue("${file.path} 不存在", file.isFile)
        return file.readText()
    }

    /**
     * 截出顶层函数体：从 `marker` 起到第一个行首 `}`（顶层函数的收尾）为止。
     *
     * 用于把断言限制在「这一个函数」里，避免文件里别处的同名文案让守卫假绿/假红。
     * 局部函数（如 `onRowAction`）的收尾是缩进的 `}`，截取会顺延到外层函数末尾——
     * 对本测试的断言无影响，因为分支断言还用了 `substringAfter` / `substringBefore` 收窄。
     */
    private fun functionBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        assertTrue("源码里找不到 $marker", start >= 0)
        val rest = source.substring(start)
        val end = rest.indexOf("\n}\n")
        assertTrue("$marker 的函数体没有找到行首收尾 `}`", end > 0)
        return rest.substring(0, end)
    }
}
