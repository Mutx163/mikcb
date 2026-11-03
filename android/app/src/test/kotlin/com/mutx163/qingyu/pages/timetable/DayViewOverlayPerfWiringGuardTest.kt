package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日视图展开层的**卡顿修复接线守卫**（2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * 这三条都是「代码仍然编得过、页面也照常打开，但卡顿修复静默失效」的改动：
 * 1. 展开层不再复用首页宿主已解析的设置模型 ⇒ 展开首帧又要把整份
 *    `timetable_settings` JSON 解析一遍（MiniJson + 80+ 键 fromJson）；
 * 2. `DayViewPage` 的装配结果不再按 `dataVersion` 缓存 ⇒ 1Hz 心跳会每秒
 *    重跑整页装配（全量课程过滤 + 冲突表 + 日程/考试/任务扫描）；
 * 3. 收起后不再保活 / 隐藏时没关掉绘制与命中 ⇒ 要么每次开合都重建整棵树，
 *    要么看不见的日视图把周视图的点击吞掉。
 *
 * ## 为什么读源码文本
 *
 * 这三件事都写在 Compose 调用与修饰器链里，反射与编译产物都不保留；
 * 与 `DayViewWiringGuardTest` / `DockPagerWiringGuardTest` 同一套做法。
 * 判据只看「关键字样在不在」，不依赖缩进与折行。
 */
class DayViewOverlayPerfWiringGuardTest {

    @Test
    fun `展开层必须复用宿主已解析的设置模型`() {
        val shell = readSource(ShellPageIndex)
        val wiring = readSource(ShellWiring)

        assertTrue(
            "`DayViewOverlayBinding` 没有 `settingsModel` 字段——展开层拿不到宿主那份模型，",
            "val settingsModel: TimetableSettingsModel? = null" in shell,
        )
        assertTrue(
            "`c3.day` 没有优先使用 `dayOverlay?.settingsModel`——会在展开首帧重复解析整份设置。",
            "dayOverlay?.settingsModel" in shell,
        )
        assertTrue(
            "`ShellWiring` 构造展开层时没有传 `settingsModel = settingsModel`——参数断了，日视图又会自己 load()。",
            // 必须看 `DayViewOverlayBinding(...)` **这个调用块**：同一个文件里
            // `TimetableHost(settingsModel = settingsModel, …)` 也有同样的字样，
            // 全文 contains 会在参数被删掉时仍然通过（已用咬合探针验过）。
            "settingsModel = settingsModel" in callBlock(wiring, "DayViewOverlayBinding("),
        )
    }

    @Test
    fun `日视图装配必须带数据版本`() {
        val shell = readSource(ShellPageIndex)
        val day = readSource(DayViewPage)

        assertTrue(
            "`DayViewPage` 没有 `dataVersion` 参数——装配结果无法按仓储变化失效。",
            "dataVersion: Any? = null" in day,
        )
        assertTrue(
            "`DayViewPage` 的 `dataProvider` 没有按「周次 + 星期 + dataVersion」缓存——1Hz 心跳会每秒重装配。",
            "remember(target.week, target.dayOfWeek, dataVersion)" in day,
        )
        assertTrue(
            "`c3.day` 调用 `DayViewPage` 时没有传 `dataVersion = snapshot`——仓储变了日视图不会跟着变。",
            "dataVersion = snapshot" in shell,
        )
    }

    @Test
    fun `展开层收起后必须保活且隐藏时不绘制不命中`() {
        val week = readSource(TimetableWeekPage)

        assertTrue(
            "`TimetableWeekPage` 没有 `dayMounted = dayVisible || dayLayerReady`——收起后又把整棵树卸载了。",
            "val dayMounted = dayVisible || dayLayerReady" in week,
        )
        assertTrue(
            "隐藏的展开层没有提前退出绘制——保活的日视图仍会每帧重画。",
            "if (!dayVisible) return@drawWithContent" in week,
        )
        assertTrue(
            "隐藏的展开层没有 `inertUnless(dayVisible)`——不绘制的子树仍会抢走周视图的点击。",
            ".inertUnless(dayVisible)" in week,
        )
    }

    // ------------------------------------------------------------------ 工具

    /**
     * 取 `name(` 起到配对右括号为止的调用块（含嵌套括号）。
     *
     * 防止「同一个文件里别处也有同样字样」让判据变成假阳性：参数被删掉时，
     * 只要别处还写着同样的实参，全文 contains 仍然会绿。
     */
    private fun callBlock(source: String, callHead: String): String {
        val start = source.indexOf(callHead)
        if (start < 0) throw AssertionError("找不到 $callHead —— 守卫无法验证，按失败处理")
        var depth = 0
        val sb = StringBuilder()
        var index = source.indexOf('(', start)
        while (index < source.length) {
            val ch = source[index]
            if (ch == '(') depth++
            if (ch == ')') {
                depth--
                if (depth == 0) break
            }
            sb.append(ch)
            index++
        }
        return sb.toString()
    }

    private fun readSource(relative: String): String {
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
        const val ShellPageIndex =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
        const val ShellWiring =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"
        const val DayViewPage =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt"
        const val TimetableWeekPage =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
    }
}
