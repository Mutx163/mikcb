package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 学期摘要卡（`SummaryCardRow`）**按压热区 = 整卡**守卫（2026-11-10，Chief 批）。
 *
 * ## 钉的是哪一件事
 *
 * 用户真机报「设置首页顶部那张『当前第 N 周 / 共 N 周』的卡（带 > 箭头），按压只亮中间
 * 一个小长方形」。根因：外层 `QingyuCard` 没有 `onClick`，点击挂在**内层 `Row`** 上，
 * 而那张卡把 16dp 内边距放在 `insideMargin` 里——miuix `Card` 的 clickable 节点挂在
 * `insideMargin` **外面**，于是热区只剩「卡减去四周 16dp」的中间块，水洗也只亮那一块。
 *
 * 发布版基准：`HyperosSummaryCard` → `HyperosPressableRow` 铺满整行，按压是 25ms 延迟的
 * 整面 alpha 水洗（无 Sink 缩放）。
 *
 * ## 四条断言
 *
 * 1. `SummaryCardRow` 的 `QingyuCard(` 实参里有 `onClick = click`（整卡可点）；
 * 2. `pressFeedbackType = PressFeedbackType.None` 在场（只要水洗、不要下沉缩放）；
 * 3. 该函数体内**不许再出现** `.clickable(`（点击回退到内层节点就等于热区回退）；
 * 4. `insideMargin = PaddingValues(0.dp)` 与内容 `Row` 的 `.padding(16.dp)` 同时在场
 *    （内边距只能待在其中一处，两处都在或都不在都会让视觉/热区出错）。
 *
 * 咬合探针（本轮手跑过）：把点击改回内层 `Row` 并恢复 `insideMargin = 16dp` ⇒
 * 断言 1/3/4 红；还原 ⇒ 四条全绿。
 */
class SettingsSummaryCardPressGuardTest {

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

    /** 只取 `SummaryCardRow` 这一个函数的源码片段（到下一个 `@Composable` 之前）。 */
    private fun summaryCardRowSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )
        assertTrue("渲染层源码不存在：${file.path}", file.isFile)
        val src = file.readText()
        val start = src.indexOf("private fun SummaryCardRow(")
        assertTrue("渲染层找不到 SummaryCardRow（改名后本守卫需要跟着改）", start >= 0)
        val end = src.indexOf("\n@Composable", start).let { if (it < 0) src.length else it }
        return src.substring(start, end)
    }

    @Test
    fun `摘要卡整卡可点`() {
        val body = summaryCardRowSource()
        assertTrue(
            "SummaryCardRow 的外层 QingyuCard 没有 onClick —— 热区又会被内边距切小",
            body.contains("onClick = click"),
        )
    }

    @Test
    fun `摘要卡只要水洗不要下沉缩放`() {
        val body = summaryCardRowSource()
        assertTrue(
            "SummaryCardRow 缺少 pressFeedbackType = PressFeedbackType.None" +
                "（发布版整卡水洗、无 Sink 缩放）",
            body.contains("pressFeedbackType = PressFeedbackType.None"),
        )
    }

    @Test
    fun `摘要卡函数体内不许把点击挂回内层`() {
        val body = summaryCardRowSource()
        assertFalse(
            "SummaryCardRow 里又出现了 .clickable( —— 点击挂回内层节点就会回到" +
                "「按压只亮中间小长方形」的老 bug",
            body.contains(".clickable("),
        )
    }

    @Test
    fun `内边距只在内容一处`() {
        val body = summaryCardRowSource()
        assertTrue(
            "卡片 insideMargin 应为 0（内边距要挪进内容，否则热区被切小）",
            body.contains("insideMargin = PaddingValues(0.dp)"),
        )
        assertTrue(
            "内容 Row 缺少 .padding(16.dp) —— 内边距两处都没有，字会贴卡片边",
            body.contains(".padding(16.dp)"),
        )
    }
}
