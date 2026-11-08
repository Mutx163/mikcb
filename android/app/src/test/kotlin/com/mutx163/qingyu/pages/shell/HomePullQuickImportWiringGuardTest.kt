package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 首页下拉快捷导入的接线守卫（2026-11-07）。
 *
 * ## 它防的是哪一类事故
 *
 * 设置里「首页下拉快捷导入」这颗开关存在了很久，但 Compose 侧只有组件
 * （`HomePullQuickImportHost`）与状态胶囊，**没有任何调用点** —— 开关是死的，
 * 下拉只会出现 Compose 默认的橡皮筋拉伸。这类「设置项宣称有功能、实际没接线」
 * 的问题编译不会报错，只能靠源码断言钉住。
 *
 * ## 判据
 *
 * 1. 首页必须把 `TimetableHost` 包进 `HomePullQuickImportHost`，且 `enabled` 同时看
 *    设置开关与「不在日视图」两条（日视图没有纵向滚动可拉）；
 * 2. 前置判据两条（无宏 / 无登录地址）必须给出各自的现成文案，不跳页；
 * 3. 放行时必须走已有的跨页交接件 + 仓库登录页回放（不改导入内核）。
 */
class HomePullQuickImportWiringGuardTest {

    @Test
    fun `首页必须挂上下拉快捷导入并且受设置与视图态门控`() {
        val source = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        assertTrue(
            "首页没有 `HomePullQuickImportHost(`：下拉快捷导入只剩开关，手指下拉只有橡皮筋。",
            "HomePullQuickImportHost(" in source,
        )
        assertTrue(
            "下拉导入没有读设置 `homePullQuickImportEnabled`：开关仍然无效。",
            "homePullQuickImportEnabled" in source,
        )
        assertTrue(
            "下拉导入没有排除日视图：日视图没有纵向滚动，拉了只会误触。",
            "TimetableHomeViewMode.DAY" in source,
        )
        assertTrue(
            "`HomePullQuickImportHost` 没有包住 `TimetableHost(" +
                "（必须罩住首页滚动体，否则拉不到）。",
            source.indexOf("HomePullQuickImportHost(") < source.indexOf("TimetableHost("),
        )
        // 2026-11-07 用户实报：指示器画到状态栏上了。本层包的是整页，必须把
        // 「状态栏 + 顶栏 + 星期栏」那条带的高度交给它，muiix 才会把环下移到星期栏底下。
        assertTrue(
            "下拉指示器没有 contentTopInset：它会又画到状态栏/顶栏上面。",
            "contentTopInset = WindowInsets.statusBars" in source,
        )
        assertTrue(
            "contentTopInset 没算顶栏/星期栏高度：指示器会落在两者中间而不是星期栏底下。",
            "TimetableTopBarMetrics.HEIGHT.dp" in source &&
                "WeekdayHeaderMetrics.HEIGHT_DP.dp" in source,
        )
    }

    @Test
    fun `前置没过必须说人话而不是静默返回`() {
        val source = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        // 两条阻塞各有现成 ARB 文案，与 Dart `home_pull_quick_import.dart:130-200` 同口径。
        assertTrue(
            "没有宏记录时没有给 `noSavedQuickImportRecords` 文案：用户拉一下什么都不会发生。",
            "noSavedQuickImportRecords" in source,
        )
        assertTrue(
            "没有可用登录地址时没有给 `noValidWarehouseLoginUrl` 文案。",
            "noValidWarehouseLoginUrl" in source,
        )
    }

    @Test
    fun `放行必须复用已有回放链路而不是另起一套`() {
        val source = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        for (expected in listOf(
            "WarehouseMacroStore(",
            "WarehouseImportHandoff.publish(",
            "onNavigate(WarehouseRoutes.WEB_LOGIN)",
        )) {
            assertTrue(
                "下拉导入没有走已有回放链路：缺少 `$expected`。" +
                    "（本刀只接线，导入内核不许复制第二份。）",
                expected in source,
            )
        }
    }

    /** 与同目录守卫同一套「向上找仓库根」的定位方式；找不到仍判失败。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
