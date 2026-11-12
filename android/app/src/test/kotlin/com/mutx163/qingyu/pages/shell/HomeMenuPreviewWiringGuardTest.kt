package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外观编辑页预览的「首页顶栏菜单」接线守卫（2026-11-10）。
 *
 * ## 为什么钉这条
 *
 * 用户实报「外观编辑页的预览里右上角缺三个点」。根因不是渲染层：`TimetableTopBar` 里
 * `if (menuItems.isNotEmpty())` 才画那颗球，而预览的宿主 `AppearanceEditorHost` 调
 * `TimetableHost(...)` / `DayViewPage(...)` 时**没传 `homeMenuItems`**，落到默认空表 ⇒ 球不画。
 * 真首页那三处（`ShellPageIndex` / `ShellWiring`）都是 `homeMenuItems = homeTopMenuItems(settings)`。
 *
 * ## 判据为什么是源码文本
 *
 * `AppearanceEditorHost.kt` 在 composeP1，不参与 L0 的 JVM 编译闭包，预览树里也拿不到实例断言
 * （`find.byType` 式断言在这里更不可能）。所以按仓里既有做法读源码、按括号配对截**调用块**，
 * 断言这两个调用必须把菜单条目传下去、且不许传空表。
 *
 * 判据不许写成「全文出现 `homeMenuItems` 就算过」：那正是这条 bug 的原始状态
 *（参数声明、KDoc、别的调用点都会命中）。只看这两个调用块的实参。
 *
 * ## 读法：剥注释 + **中性化档**（2026-11-12 B2 批）
 *
 * 走 `readKotlinSourceNoStrings`：**注释剥掉、字符串内容也抹成空格**。
 *
 * * 剥注释：不剥时把 `homeMenuItems = homeMenuItems,` 注释掉，`contains` 照样命中注释文本
 *   ⇒ 用户实报的那条「预览里缺三个点」可以原样复发而守卫全绿。B2 批实测过这个洞。
 * * 中性化：本文件四条判据判的全是**代码结构**（实参有没有传、走没走 `homeTopMenuItems` 解析、
 *   有没有 `.ifEmpty` 兜底、有没有传空表），一条都不判「某字面量许不许出现」。这类判据最怕
 *   生产代码里一句日志 / 提示语含同样片段把 `contains` 喂饱 —— 抹掉字符串内容正好消掉这个面。
 *
 * 反向的坑也确认过：本文件没有一条判据需要看字符串内容（负例 `homeMenuItems = emptyList()`
 * 本身是代码表达式，不含任何字面量），所以中性化不会把判据擦空。
 */
class HomeMenuPreviewWiringGuardTest {

    private val source by lazy { readKotlinSourceNoStrings(APPEARANCE_EDITOR_HOST) }

    @Test
    fun `周视图预览必须把菜单条目传进 TimetableHost`() {
        val block = callBlock(source, "TimetableHost(")
        assertTrue(
            "外观编辑页的 `TimetableHost(...)` 没有传 `homeMenuItems = homeMenuItems`：" +
                "`TimetableTopBar` 只在菜单非空时画右上角那颗球，不传就是「预览里缺三个点」。\n" +
                "实际调用块：$block",
            block.contains("homeMenuItems = homeMenuItems"),
        )
    }

    @Test
    fun `日视图预览必须把菜单条目传进 DayViewPage`() {
        val block = callBlock(source, "DayViewPage(")
        assertTrue(
            "外观编辑页的 `DayViewPage(...)` 没有传 `homeMenuItems = homeMenuItems`：" +
                "日视图预览同样要画出那颗球（真首页 `c3.day` 是有球的）。\n" +
                "实际调用块：$block",
            block.contains("homeMenuItems = homeMenuItems"),
        )
    }

    @Test
    fun `条目必须按草稿设置解析 不许写死或传空表`() {
        assertTrue(
            "预览没有用 `homeTopMenuItems(settingsModel)` 解析条目：真首页三视图都走这一份，" +
                "写死一份列表会让「设置里自定义菜单」在预览里失效。",
            source.contains("homeTopMenuItems(settingsModel)"),
        )
        assertTrue(
            "预览缺 `ifEmpty { TimetableMenuDefaults.entries() }` 兜底：理论上 `resolveIds` 会回退默认，" +
                "但预览是最常被独立打开的一屏，兜底不能只剩下一层。",
            source.contains(".ifEmpty { TimetableMenuDefaults.entries() }"),
        )
        assertFalse(
            "预览把菜单传成了空表（`homeMenuItems = emptyList()`）：球会整颗消失。",
            source.contains("homeMenuItems = emptyList()"),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        assertTrue(
            "AppearanceEditorHost.kt 源码读取太短（${source.length} 字符），路径解析可能坏了",
            source.length > 10_000,
        )
        for (marker in listOf("TimetableHost(", "DayViewPage(")) {
            assertTrue(
                "$marker 的调用块太短（判据可能截错了），实际：${callBlock(source, marker)}",
                callBlock(source, marker).length > 80,
            )
        }
    }

    /** 按括号配对取出 `marker(` 那一整个调用块（含括号内的实参）。 */
    private fun callBlock(text: String, marker: String): String {
        val start = text.indexOf(marker)
        check(start >= 0) { "源码里找不到 `$marker`，判据失效" }
        val open =
            if (marker.endsWith('(')) {
                start + marker.length - 1
            } else {
                text.indexOf('(', start + marker.length)
            }
        check(open > 0) { "`$marker` 后面没有实参括号，判据失效" }
        var depth = 0
        for (i in open until text.length) {
            when (text[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return text.substring(open, i + 1)
                }
            }
        }
        error("`$marker` 的实参括号没有闭合")
    }

    private companion object {
        /** 仓库相对路径；读法见上层 `source`（剥注释 + 中性化字面量）。 */
        const val APPEARANCE_EDITOR_HOST =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt"
    }
}
