package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「首页按系统返回 = 回首页根，而不是回周视图」的壳层守卫（2026-11-04）。
 *
 * ## 用户口径
 *
 * 在首页区域的任何一个页面（底栏内嵌页：任务 / 设置 / 统计 / 考试 / 总览…，以及日视图）
 * 按手机系统返回键，应回到**首页根**（课表本体，视图档按用户当前所在：日→日、周→周、
 * 月→月），而不是被硬拉回周视图。
 *
 * ## 它防的是什么回归
 *
 * 1. **返回目标被写死回 `selectRoot(ROOT_WEEK)` / `switchHomeViewMode(WEEK)`** ——
 *    这正是修掉的旧写法，任何一处回流都会让「返回 → 周视图」复发；
 * 2. **首页根定义退化**：不再用 `rootItemIdForView(wiring.homeViewMode)` 映射，
 *    改成某个写死的条目 id；
 * 3. **`enabled` 判据回退**：不再用 `atRoot && currentRootId != homeRootId`
 *    （已停在首页根时若还拦返回，用户就退不了 App / 或又被切视图）。
 *
 * ## 为什么是源码文本守卫而不是 Compose UI 测试
 *
 * 壳的返回是 `BackHandler` 事件，JVM 单测驱动不了；仓库既有做法就是用源码文本守卫
 * （见同目录 `RootEntryBackGuardTest`）。本文件的咬合探针在同一用例里把目标改回旧写法，
 * 判据必须变红。
 */
class HomeBackToRootGuardTest {

    @Test
    fun `系统返回回首页根而不是写死周视图`() {
        val code = codeOnly(source(ACTIVITY))
        assertTrue(
            "缺首页根定义：应复用 rootItemIdForView(wiring.homeViewMode) 映射，" +
                "而不是写死某个条目 id",
            code.contains("val homeRootId = rootItemIdForView(wiring.homeViewMode)"),
        )
        val block = systemBackBlock(code)
        assertTrue(
            "没定位到根级系统返回 BackHandler（判据应含 atRoot && currentRootId != homeRootId）",
            block.contains("atRoot && currentRootId != homeRootId"),
        )
        assertTrue(
            "返回体应 animateDockPagerTo(homeRootId)（走 indexOfPage 对齐，不猜）",
            block.contains("animateDockPagerTo(homeRootId)"),
        )
        assertFalse(
            "返回目标不许再写死 selectRoot(ROOT_WEEK)：那会落回周视图",
            block.contains("selectRoot(ROOT_WEEK)"),
        )
        assertFalse(
            "返回不许再强行 switchHomeViewMode(WEEK)：那会把日/月档拉回周视图",
            block.contains("switchHomeViewMode(TimetableHomeViewMode.WEEK)"),
        )
    }

    @Test
    fun `咬合探针 旧写法必须判红`() {
        val broken = codeOnly(source(ACTIVITY))
            .replace("animateDockPagerTo(homeRootId)", "selectRoot(ROOT_WEEK)")
        assertFalse(
            "咬合探针失效：把返回体换回 selectRoot(ROOT_WEEK) 后守卫仍为真",
            systemBackBlock(broken).contains("animateDockPagerTo(homeRootId)"),
        )
    }

    // ------------------------------------------------------------------ 定位

    /**
     * 只取「enabled = atRoot …」那个 `BackHandler(…) { … }` 整段（含尾随 lambda）。
     *
     * 必须只判这一段，避开同文件 :904/:909 里 Dock 条目的 `onBack = { selectRoot(ROOT_WEEK) }`
     * ——那两处是根条目的死回调（顶栏返回箭头被隐藏），不在本守卫口径内。
     */
    private fun systemBackBlock(text: String): String {
        val en = text.indexOf("enabled = atRoot")
        if (en < 0) return ""
        val bh = text.lastIndexOf("BackHandler(", en)
        if (bh < 0) return ""
        // 先配平 BackHandler( … ) 的圆括号
        var depth = 0
        var i = text.indexOf('(', bh)
        var close = -1
        while (i < text.length) {
            when (text[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) {
                        close = i
                        break
                    }
                }
            }
            i++
        }
        if (close < 0) return text.substring(bh)
        // 再配平尾随 lambda { … }
        val braceOpen = text.indexOf('{', close)
        if (braceOpen < 0) return text.substring(bh, close + 1)
        var d2 = 0
        var j = braceOpen
        while (j < text.length) {
            when (text[j]) {
                '{' -> d2++
                '}' -> {
                    d2--
                    if (d2 == 0) return text.substring(bh, j + 1)
                }
            }
            j++
        }
        return text.substring(bh)
    }

    /** 只留代码：剥掉块注释与行注释，历史/说明里的旧写法不参与判定。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    /** 从工作目录向上找仓库根再读文件；与同目录守卫测试同一套做法。 */
    private fun source(relativePath: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relativePath)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relativePath（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val ACTIVITY =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
    }
}
