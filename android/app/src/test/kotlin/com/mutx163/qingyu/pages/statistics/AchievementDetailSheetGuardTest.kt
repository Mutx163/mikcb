package com.mutx163.qingyu.pages.statistics

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 成就详情弹层守卫（2026-11-03，弹层全参数审核 statistics ×3 修复后的棘轮）。
 *
 * 钉三件事（都是「不编译报错、单测照绿、只有盯屏才看得出」的弹层病）：
 *
 * 1. **常驻组合**：不许退回 `if (achievement == null) return` / `show = true` 的
 *    条件挂载——那会让官方退场动画一次都不播。必须 `show = achievement != null` +
 *    `rememberLastNonNull` 退场快照（与 time_scheme 域同口径）。
 * 2. **per-id 语义色**：accent 必须按 `AchievementModel.accentOf(id)` 取
 *    （Dart `_achievementAccent` 的「每个成就一个颜色身份」），不许退回主题 `primary` 一刀切。
 * 3. **未解锁淡染**：锁定徽章用 accent 的 `LOCKED_FILL_*` 淡染，不许退回中性的
 *    `surfaceContainerHighest` 填底（徽章颜色身份丢失）。
 */
class AchievementDetailSheetGuardTest {

    @Test
    fun `扫描器必须真的扫到弹层源文件`() {
        assertTrue(
            "AchievementDetailSheet.kt 不在预期位置，扫描根疑似失效（门禁空跑会假绿）",
            sheetFile().isFile,
        )
        assertTrue(
            "CourseStatisticsPage.kt 不在预期位置，扫描根疑似失效（门禁空跑会假绿）",
            pageFile().isFile,
        )
    }

    @Test
    fun `详情弹层常驻组合 show 驱动 且有退场快照`() {
        val text = codeLines(sheetFile())
        assertTrue(
            "AchievementDetailSheet 必须常驻组合、用 `show = achievement != null` 驱动显隐",
            text.contains("show = achievement != null"),
        )
        assertTrue(
            "AchievementDetailSheet 必须用 rememberLastNonNull 钉住最后一份非空成就（退场动画期间照常渲染）",
            text.contains("rememberLastNonNull(achievement)"),
        )
        assertFalse(
            "禁止条件挂载弹层：`if (achievement == null) return` 会让退场动画一次都不播",
            text.contains("if (achievement == null) return"),
        )
        assertFalse(
            "禁止 `show = true` 静态挂载：显隐必须交给入参判空驱动",
            text.contains("show = true"),
        )
    }

    @Test
    fun `成就配色按 id 取语义色 锁定徽章淡染`() {
        val text = codeLines(sheetFile())
        assertTrue(
            "详情弹层 accent 必须按 AchievementModel.accentOf(id) 取 per-id 语义色（Dart _achievementAccent）",
            text.contains("AchievementModel.accentOf(view.id)"),
        )
        assertTrue(
            "锁定徽章必须用 accent 淡染（LOCKED_FILL_*），不许用中性 surfaceContainerHighest 填徽章",
            text.contains("AchievementModel.LOCKED_FILL_LIGHT") &&
                text.contains("AchievementModel.LOCKED_FILL_DARK"),
        )

        val page = codeLines(pageFile())
        assertTrue(
            "CourseStatisticsPage 徽章格子同样要 per-id 语义色（审核 :59 项同病同修）",
            page.contains("AchievementModel.accentOf(item.id)"),
        )
    }

    // ------------------------------------------------------------------

    /**
     * 只取**代码行**（与 `scripts/compose-style-lint.ps1` 同口径）：
     * 行首是行注释 / 块注释续行标记的注释行不参与判定——KDoc 里摆着「原来是 `show = true`」
     * 这类反面示例，不能把它当成代码命中。
     */
    private fun codeLines(file: File): String = file.readLines()
        .filter { line ->
            val t = line.trimStart()
            !t.startsWith("//") && !t.startsWith("*") && !t.startsWith("/*")
        }
        .joinToString("\n")

    private fun sheetFile(): File = File(
        repoRoot(),
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/AchievementDetailSheet.kt",
    )

    private fun pageFile(): File = File(
        repoRoot(),
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/CourseStatisticsPage.kt",
    )

    /** 与 `ComposeSheetGuardTest.repoRoot()` 同一口径。 */
    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) {
                var up: File? = dir
                while (up != null) {
                    if (File(up, "lib/screens").isDirectory && File(up, "pubspec.yaml").isFile) {
                        return up.path
                    }
                    up = up.parentFile
                }
                return dir.path
            }
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }
}
