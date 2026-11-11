package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import com.mutx163.qingyu.testutil.stripKotlinComments
import java.io.File

/**
 * 设置页列表底距守卫（2026-11-10，Chief 批「底距三件」）。
 *
 * ## 钉的是哪件事
 *
 * 用户真机报「设置页滑到最底还能多滑出一块空白」。根因是**导航栏高度算了两次**：
 * `Scaffold` 的 `innerPadding.bottom` 本来就等于「底栏高度」或「导航栏高度」
 * （M3 `ScaffoldLayout`：`bottom = bottomBarHeight ?: insets.bottom`），
 * 而 `SettingsPageScreen` 又往列表的 `contentPadding` 里加了一遍 `navBottom`。
 *
 * - 无底栏页：底距 = 导航栏高 + 24 + 导航栏高；
 * - 有底栏页（节假日高级）：底距 = 栏高（已含导航栏）+ 24 + 导航栏高。
 *
 * 历史账：2026-11-07 那次补 `navBottom` **当时是对的**（旧底栏 `ControlCard` 自身不含
 * 导航栏内边距）；A1 换成 `FooterBar` 后它自己 `bottom = 12.dp + navBottom`，底栏高度
 * 已含 nav ⇒ 同一行变成纯多算。所以修法是「列表不再加」，**不是**「底栏也删」。
 *
 * ## 三条断言
 *
 * 1. `contentPadding` 恰好两处（预览分栏 / 普通列表各一），且都不许出现 `navBottom`；
 * 2. 两处的底距都是发布版 `HyperosTokens.listPadding` 的 24dp（防有人顺手连底距一起删）；
 * 3. `FooterBar` 仍然收 `navBottom`、仍然自己垫 `12.dp + navBottom`（防矫枉过正）。
 *
 * 咬合探针（本轮手跑过）：把 `+ navBottom` 加回任一处 ⇒ 断言 1 红并指出分支；
 * 还原 ⇒ 三条全绿。
 */
class SettingsListBottomInsetGuardTest {

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
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private fun renderersSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )
        assertTrue("渲染层源码不存在：${file.path}", file.isFile)
        return stripKotlinComments(file.readText())
    }

    /**
     * 剥掉行注释后，取出每一处 `contentPadding = PaddingValues(...)` 的**完整实参文本**
     * （按括号配平截到收尾的 `)`）。注释里出现 `navBottom` 不该被算成违规。
     */
    private fun contentPaddingCalls(): List<String> {
        val stripped = renderersSource().lines().joinToString("\n") { line ->
            val commentAt = line.indexOf("//")
            if (commentAt >= 0) line.substring(0, commentAt) else line
        }
        val marker = "contentPadding = PaddingValues("
        val calls = mutableListOf<String>()
        var from = 0
        while (true) {
            val start = stripped.indexOf(marker, from)
            if (start < 0) break
            var index = start + marker.length
            var depth = 1
            while (index < stripped.length && depth > 0) {
                when (stripped[index]) {
                    '(' -> depth++
                    ')' -> depth--
                }
                index++
            }
            calls += stripped.substring(start, index)
            from = index
        }
        return calls
    }

    @Test
    fun `两处列表底距都不许再叠导航栏高度`() {
        val calls = contentPaddingCalls()
        assertEquals(
            "渲染层的 contentPadding 只应有两处（预览分栏支 + 普通列表支）；" +
                "新增/合并分支后这条守卫需要重新核对，别让它空跑",
            2,
            calls.size,
        )
        val offenders = calls.filter { it.contains("navBottom") }
        assertTrue(
            "列表底距又叠了一次导航栏高度 —— Scaffold 的 innerPadding.bottom 已经含它，" +
                "会多出「24 + 导航栏」一截空白（用户真机报的「滑到底还能多滑一块」）。" +
                "违规写法：\n" + offenders.joinToString("\n") { "    $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `两处底距都是发布版列表底距 24dp`() {
        val calls = contentPaddingCalls()
        assertEquals(
            "两处底距都应为发布版 HyperosTokens.listPadding 的 24dp（16/4/16/24）；" +
                "这里少了/多了说明补白口径被改动",
            2,
            calls.count { it.contains("bottom = 24.dp") },
        )
    }

    @Test
    fun `底栏自己的导航栏内边距仍保留`() {
        val src = renderersSource()
        assertTrue(
            "FooterBar 没有收到 navBottom —— 底栏按钮会压在系统导航栏上",
            src.contains("FooterBar(node = footer, navBottom = navBottom"),
        )
        assertTrue(
            "FooterBar 丢了 12.dp + navBottom 的内边距 —— 栏式底栏要自己把按钮垫到导航栏上方",
            src.contains("bottom = 12.dp + navBottom"),
        )
    }
}
