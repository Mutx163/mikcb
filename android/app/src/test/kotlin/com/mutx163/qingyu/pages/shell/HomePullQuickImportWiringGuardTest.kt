package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertTrue
import org.junit.Test

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
 *
 * ## 读法：剥注释 + **中性化档**（2026-11-12 B2 批）
 *
 * 走 `readKotlinSourceNoStrings`：**注释剥掉、字符串内容也抹成空格**。
 *
 * * 剥注释：不剥时把 `HomePullQuickImportHost(` / `weekScrollWrapper = { weekContent ->`
 *   这类承接行注释掉，`in source` 照样命中注释文本 —— 接线被摘掉而守卫全绿，正好是
 *   本文件要防的事故同款（开关宣称有功能、实际没接线）。B2 批实测过这个洞。
 * * 中性化：三条判据判的全是**调用 / 属性访问 / 结构**（挂没挂宿主、读没读设置、
 *   排没排日视图、走没走已有回放链路），一条都不判「某字面量许不许出现」。抹掉字符串
 *   内容能挡掉「日志 / 提示语里含同片段把判据喂饱」这一类假绿。
 *
 * 反向的坑确认过：两条文案判据判的是 `WarehouseStrings.noSavedQuickImportRecords.text`
 * 这类**属性名**（不是字符串字面量），中性化不会把它擦掉。
 */
class HomePullQuickImportWiringGuardTest {

    @Test
    fun `首页必须挂上下拉快捷导入并且受设置与视图态门控`() {
        val source = shellWiringSource()
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
            "首页没有把下拉层挂到周视图滚动体上（`weekScrollWrapper`）：" +
                "包整页时指示器会压状态栏或被正文盖住，且日/月视图会误触发。",
            "weekScrollWrapper = { weekContent ->" in source && "HomePullQuickImportHost(" in source,
        )
        val enabledLine = source.lineSequence().firstOrNull { it.contains("val pullImportEnabled =") }
        assertTrue(
            "`ShellWiring` 里找不到 `val pullImportEnabled =`（锚点被内联 / 改名 / 删除）：" +
                "下面那条「不许乘视图态」的判据在空串上会恒真，等于没守。",
            enabledLine != null,
        )
        assertTrue(
            "pullImportEnabled 又乘了视图态：`enabled` 翻转会把首页整棵销毁重建（日展开动画/滚动位置全丢）。",
            "homeViewMode" !in (enabledLine ?: ""),
        )
    }

    @Test
    fun `前置没过必须说人话而不是静默返回`() {
        val source = shellWiringSource()
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
        val source = shellWiringSource()
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

    /**
     * 读壳源码：**剥注释 + 字符串内容中性化**（`readKotlinSourceNoStrings`）。
     *
     * 两件事各自的原因见类注释「读法」一节；一句话：本文件判接线，注释掉的接线不算接线，
     * 而字符串里的同片段也不许当接线。
     */
    private fun shellWiringSource(): String = readKotlinSourceNoStrings(SHELL_WIRING)

    private companion object {
        const val SHELL_WIRING =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"
    }
}
