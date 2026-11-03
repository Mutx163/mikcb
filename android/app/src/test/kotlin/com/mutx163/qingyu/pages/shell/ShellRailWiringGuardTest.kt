package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 宽屏侧边导航栏（Rail）的壳层接线守卫（2026-11-03 第 2 批）。
 *
 * ## 它防的是哪一类事故
 *
 * Rail 接线全是「静默失败」型：绕过注入自己算宽度（页面限宽列对着 Rail 底下的区域
 * 居中）、Rail 点条目直接调 `selectRoot`（被栈守卫吞掉 = 压着页面时点了没反应）、
 * 坞用 alpha 藏而不是不组合（白留一层图层）——编译过、手机竖屏看不出、只有宽窗才显形。
 * 与同目录 `GlassDockRoundButtonIconWiringGuardTest` 同一套路：读源码文本钉最小集合。
 *
 * ## 咬合探针（不产生第二次运行）
 *
 * 每条判据写成「文本 → 布尔」函数，并在同一用例里喂一份**故意改坏**的副本：改坏后
 * 必须为假。判据本身的数值行为（Rail 该出现时出现）由
 * `core/QingyuAdaptiveRulesTest` 的行为断言 + 咬合探针（阈值 1200→12000 必红）负责。
 */
class ShellRailWiringGuardTest {

    // ---------------------------------------------------------------- 壳层接线

    @Test
    fun `壳层消费 Rail 判据并注入内容区宽`() {
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "PagesShellActivity 没有消费 rememberQingyuShellRailAdaptive —— Rail 显隐别在壳里另起一套判据",
            activity.contains("rememberQingyuShellRailAdaptive("),
        )
        assertTrue(
            "壳层没有注入 QingyuLocalWindowAdaptive —— 页面骨架会退回按窗口宽自算，" +
                "Rail 出现后限宽列会对着 Rail 底下的区域居中（上一批预留的注入口必须用上）",
            activity.contains("QingyuLocalWindowAdaptive provides"),
        )
        // 反向探针：把注入删掉，判据必须红。
        assertFalse(
            "咬合探针失效：删掉注入后判据仍为真",
            shellInjectsAdaptive(activity.replace("QingyuLocalWindowAdaptive provides", "X provides")),
        )
    }

    @Test
    fun `坞被 Rail 取代时不组合而不是藏 alpha`() {
        val dock = source(DOCK)
        assertTrue(
            "HomeGlassDock 缺少 replacedByRail 参数（宽屏档整块不组合的开关）",
            dock.contains("replacedByRail: Boolean = false"),
        )
        assertTrue(
            "HomeGlassDock 的早退分支没有消费 replacedByRail",
            dock.contains("|| replacedByRail) return"),
        )
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "壳没有把 railVisible 传给坞（宽屏档坞必须让位给 Rail）",
            activity.contains("replacedByRail = shellRail.railVisible"),
        )
        // 反向探针：把传参改恒 false，判据必须红。
        assertFalse(
            "咬合探针失效：传参改恒 false 后判据仍为真",
            shellHidesDockForRail(activity.replace("replacedByRail = shellRail.railVisible", "replacedByRail = false")),
        )
    }

    @Test
    fun `Rail 点条目先弹回主屏再切换`() {
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "壳里没有 railSelectRoot —— Rail 常驻可点，直接调 selectRoot 会被它的栈守卫吞掉（点了没反应）",
            activity.contains("fun railSelectRoot"),
        )
        assertTrue(
            "Rail 的 onSelect 必须走 railSelectRoot（先 pop 回主屏再 selectRoot）",
            activity.contains("onSelect = { id -> railSelectRoot(id) }"),
        )
        // 反向探针：Rail 直接调 selectRoot，判据必须红。
        assertFalse(
            "咬合探针失效：onSelect 改成直调 selectRoot 后判据仍为真",
            railPopsThenSelects(activity.replace("railSelectRoot(id)", "selectRoot(id)")),
        )
    }

    @Test
    fun `Rail 条目与坞同源`() {
        val rail = codeOnly(source(RAIL))
        assertTrue(
            "ShellNavigationRail 必须复用 HomeDockNavModel.resolveDockIds（用户存档驱动的" +
                "同一张排列表；2026-11-03 起与壳 Pager 页列表三处同一入口）",
            rail.contains("HomeDockNavModel.resolveDockIds"),
        )
        assertTrue(
            "ShellNavigationRail 必须复用 HomeDockNavModel.selectedIndex（高亮口径同源，排列没有则整栏不亮）",
            rail.contains("HomeDockNavModel.selectedIndex"),
        )
        assertTrue(
            "Rail 展开态接线缺失（跨 1200dp 阈值 expand/collapse，与 demo 同一套写法）",
            rail.contains("rememberNavigationRailState") && rail.contains("railState.expand()"),
        )
        assertTrue(
            "Rail 头部圆钮必须消费 glassDockRoundButtonIcon（设置里选的图标不能被丢掉）",
            rail.contains("glassDockRoundButtonIcon("),
        )
    }

    // ------------------------------------------------------------------ 判据

    private fun shellInjectsAdaptive(text: String): Boolean =
        text.contains("QingyuLocalWindowAdaptive provides")

    private fun shellHidesDockForRail(text: String): Boolean =
        text.contains("replacedByRail = shellRail.railVisible")

    private fun railPopsThenSelects(text: String): Boolean =
        text.contains("fun railSelectRoot") && text.contains("onSelect = { id -> railSelectRoot(id) }")

    // ------------------------------------------------------------------ 定位

    /** 只留代码：剥掉块注释与行注释，历史注释里的旧写法不参与判定。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    /** 从工作目录向上找仓库根，再读文件；与同目录守卫测试同一套做法。 */
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

        /** 宽屏档的侧边导航栏渲染件（2026-11-03 第 2 批新增）。 */
        const val RAIL =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/shell/ShellNavigationRail.kt"

        /** 玻璃坞（药丸 + 圆钮）的渲染点；宽屏档由壳传 replacedByRail 让位给 Rail。 */
        const val DOCK =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/shell/HomeGlassDock.kt"
    }
}
