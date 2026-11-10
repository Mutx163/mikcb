package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「三个首页视图的『更多』菜单同源」守卫（2026-11-10 建）。
 *
 * ## 它防的是哪一类事故
 *
 * 首页的周 / 日 / 月三个视图各画一次八宫格菜单，条目必须都来自**同一处解析**：
 * `ShellWiring.homeTopMenuItems(settings)`（读用户存档 `homeGridMenuActions` + 目录清洗
 * + 弹层动作白名单 + 空表回退发布版默认八项）。
 *
 * 2026-10-28 迁移期月视图偷懒传了死表 `TimetableMenuDefaults.entries()`，于是：
 * 用户自定义的八宫格**在月视图不生效**，同一台手机上三个视图出现两套菜单。
 * 2026-11-10 评审 5-6 把月视图改回 `homeTopMenuItems(appSettings)`，本守卫钉住它不许退回。
 *
 * ## 判据（源码级，无需 Compose classpath）
 *
 * - `ShellWiring.kt`（周视图接线）至少一处 `homeMenuItems = homeTopMenuItems(`；
 * - `ShellPageIndex.kt`（日视图 :~960、月视图 :~809）**恰好两处**同一写法；
 * - 两文件都不许出现 `homeMenuItems = TimetableMenuDefaults.entries()`（死表）。
 */
class HomeMenuSingleSourceGuardTest {

    @Test
    fun `三个首页视图的更多菜单都读用户存档`() {
        val wiring = source("main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        val index = source("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")

        val call = Regex("""homeMenuItems\s*=\s*homeTopMenuItems\(""")

        assertTrue(
            "周视图没有接 homeTopMenuItems（ShellWiring.kt）",
            call.containsMatchIn(wiring),
        )
        assertEquals(
            "日/月两个视图都必须接 homeTopMenuItems（ShellPageIndex.kt 期望 2 处，实际 " +
                "${call.findAll(index).count()} 处）",
            2,
            call.findAll(index).count(),
        )
        for ((name, text) in listOf("ShellWiring.kt" to wiring, "ShellPageIndex.kt" to index)) {
            assertFalse(
                "$name 又出现死表 TimetableMenuDefaults.entries() —— 月视图 5-6 的退化会回来",
                Regex("""homeMenuItems\s*=\s*TimetableMenuDefaults\.entries\(""").containsMatchIn(text),
            )
        }
    }

    @Test
    fun `三个首页视图的点击分流都接弹层动作通道`() {
        val wiring = source("main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        val index = source("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
        val host = source("composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt")

        // 周视图：配色在 ShellWiring 的分流里直接弹面板；分享由 TimetableHost 在宿主层拦截
        // （`SHARE_TIMETABLE_MENU_ID`，要带「当前可见周/日视图」上下文，页面自己发）。
        assertTrue(
            "周视图没有接 courseRecolor 动作通道",
            wiring.contains("id == HomeMenuNavModel.ACTION_COURSE_RECOLOR -> showRecolorSheet = true"),
        )
        assertTrue(
            "TimetableHost 没有拦截 shareTimetable（周视图分享通道）",
            host.contains("SHARE_TIMETABLE_MENU_ID"),
        )

        // 月/日两个独立页：两条动作都必须有分支，不然用户排进八宫格后点了没反应。
        val recolorBranch = Regex("""id\s*==\s*HomeMenuNavModel\.ACTION_COURSE_RECOLOR\s*->""")
        val shareBranch = Regex("""id\s*==\s*HomeMenuNavModel\.ACTION_SHARE_TIMETABLE\s*->""")
        assertEquals(
            "月/日视图的 courseRecolor 分支必须是 2 处（实际 ${recolorBranch.findAll(index).count()}）",
            2,
            recolorBranch.findAll(index).count(),
        )
        assertEquals(
            "月/日视图的 shareTimetable 分支必须是 2 处（实际 ${shareBranch.findAll(index).count()}）",
            2,
            shareBranch.findAll(index).count(),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 如果源码定位失败，上面的断言会 error 而不是假绿；这里再钉一次「确实读到了两个文件」。
        val wiring = source("main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        val index = source("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
        assertTrue("ShellWiring.kt 读出来太短", wiring.length > 10_000)
        assertTrue("ShellPageIndex.kt 读出来太短", index.length > 10_000)
    }

    /** 读源码文本（与 `MoreFeaturesNavigationGuardTest` 同一套「向上找 android/app/src」）。 */
    private fun source(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(10) {
            dir?.let { current ->
                val file = File(current, "android/app/src/$relative")
                if (file.isFile) return stripComments(file.readText(Charsets.UTF_8).replace("\r\n", "\n"))
            }
            dir = dir?.parentFile
        }
        error("找不到源码 android/app/src/$relative（工作目录 ${File("").absolutePath}）")
    }

    /**
     * 剥掉 `//` 行注释与 `/* */` 块注释（字符串字面量内的 `/` 与括号不动）。
     *
     * 2026-11-10 复核员指出：判据直接在原文上 `contains`/正则，把接线**注释掉仍会命中**
     * ⇒ 功能拆了守卫还绿（假绿）。判据一律在剥注释后的文本上做；
     * 咬合探针：注释掉 `homeMenuItems = homeTopMenuItems(` 一行 → 计数 2→1 → 红。
     */
    private fun stripComments(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var inString = false
        while (i < source.length) {
            val c = source[i]
            if (inString) {
                out.append(c)
                if (c == '\\' && i + 1 < source.length) {
                    out.append(source[i + 1]); i += 2; continue
                }
                if (c == '"') inString = false
                i++
                continue
            }
            if (c == '"') { inString = true; out.append(c); i++; continue }
            if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
                while (i < source.length && source[i] != '\n') i++
                continue
            }
            if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
                i += 2
                while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) i++
                i += 2
                continue
            }
            out.append(c); i++
        }
        return out.toString()
    }
}
