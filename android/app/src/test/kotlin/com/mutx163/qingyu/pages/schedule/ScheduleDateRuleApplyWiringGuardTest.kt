package com.mutx163.qingyu.pages.schedule

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日期规则「保存后自动套用」接线守卫（2026-11-05 建立）。
 *
 * ## 防的是什么
 *
 * 壳里原本自己起协程跑 `applyDue`，**返回值直接丢掉**：
 *
 * ```kotlin
 * onRulesChanged = { ruleScope.launch(Dispatchers.IO) { applyDue(wiring.timetable, rulePrefs) } }
 * ```
 *
 * 于是「规则今天该套、但模板节数不够 / 模板被删了」这类失败**一声不响**，用户看到的是
 * 「已保存」，作息却没变。四态提示（`ScheduleDateRuleSavedFeedback`）要能出来，
 * 前提就是这条返回值被交到判据里。
 *
 * 现在这条链收在 `ScheduleHost.kt` 的 `ScheduleDateRuleHost` 内：写盘 → `applyDue` →
 * `ScheduleDateRuleSavedFeedbackLogic.resolve` → 提示胶囊（失败档警示）。本守卫钉两件事：
 * **返回值必须被消费**、**壳不许再自己跑一次**（两处各跑一次会让同一档期先套一次、
 * 提示再按 NotDue 说成「已保存」）。
 *
 * 这是源码文本守卫：`ScheduleHost.kt` 与壳都带 Compose/Android 依赖，进不了 JVM 单测
 * classpath；四态判据本身由 `ScheduleDateRuleSavedFeedbackTest` 做行为断言。
 * 判据对格式敏感，只钉最小集合；改这段接线会先红，**请同步本文件而不是删断言**。
 *
 * ## 2026-11-05 追加：写盘抛错不许静默
 *
 * 仓储 `updateScheduleDateRules` 落盘失败是**抛异常**的（「先落盘、成功才改内存」）。
 * 宿主原先是裸调用 ⇒ 弹框关了、列表还是旧规则、一句话都没有（Dart 侧有 catch + 保存失败提示）。
 * 现在统一经 `writeRules`：`runCatching` + 失败提示 `SettingsStringsExt2.saveFailed`（警示样式），
 * 且失败时**不跑**自动套用/四态（没保存成功不许说「已保存」）。
 */
class ScheduleDateRuleApplyWiringGuardTest {

    // ───────────────────── 0. 不空跑 ─────────────────────

    @Test
    fun `判据锚点存在`() {
        val host = File(repoRoot(), SCHEDULE_HOST).readText()
        assertTrue(
            "ScheduleHost.kt 里找不到 ScheduleDateRuleHost（文件被挪走后必须同步本守卫）",
            host.contains("fun ScheduleDateRuleHost("),
        )
        assertTrue(
            "找不到 d2.dateRule 分支（壳改结构后必须同步本守卫）",
            dateRuleBranch(File(repoRoot(), SHELL_PAGE_INDEX).readText()).isNotBlank(),
        )
    }

    // ───────────────────── 1. applyDue 的返回值必须被消费 ─────────────────────

    @Test
    fun `宿主把 applyDue 的返回值交给四态判据`() {
        val host = File(repoRoot(), SCHEDULE_HOST).readText()
        assertTrue(
            "宿主没在调 `ScheduleDateRuleAutoApplyHost.applyDue(repository, prefs)`：自动套用断了",
            host.contains("ScheduleDateRuleAutoApplyHost.applyDue(repository, prefs)"),
        )
        assertTrue(
            "applyDue 的结果没有赋给局部变量（`val applyResult =`）——返回值又被丢了？",
            host.contains("val applyResult ="),
        )
        assertTrue(
            "四态判据没拿到 applyResult：`ScheduleDateRuleSavedFeedbackLogic.resolve(` 必须传 " +
                "`applyResult = applyResult`，否则「今天套失败」永远出不来失败档提示",
            host.contains("ScheduleDateRuleSavedFeedbackLogic.resolve(") &&
                host.contains("applyResult = applyResult"),
        )
    }

    @Test
    fun `失败档走警示样式`() {
        val host = File(repoRoot(), SCHEDULE_HOST).readText()
        // 2026-11-05：提示内容由 `RuleToast`（文案 + 是否警示）承载，四态的 `isWarning` 在
        // `applyDueAndReport` 里就翻进 `RuleToast`；胶囊读 `current.isError`。
        // 语义没变（失败档仍走警示样式），载体换了一层，所以判据从 `current.isWarning` 改成 `current.isError`。
        assertTrue(
            "宿主把四态的 isWarning 翻进 RuleToast 的那一步没了：失败态会与成功态长得一样",
            host.contains("RuleToast(resolved.message, resolved.isWarning)"),
        )
        assertTrue(
            "提示胶囊没把警示标记接到错误/警示样式（`isError = current.isError`）",
            host.contains("isError = current.isError"),
        )
        assertTrue(
            "宿主没有渲染提示胶囊（AppToastCapsule），四态文案没有落点",
            host.contains("AppToastCapsule("),
        )
    }

    // ───────────────────── 1.5 写盘抛错不许静默 ─────────────────────

    /**
     * 仓储 `updateScheduleDateRules` 是「先落盘、成功才改内存」并**抛异常**的（见
     * `TimetableRepository.updateScheduleDateRulesLocked`）。裸调用时异常会从点击回调里抛出去：
     * 好一点是被上层吞掉 ⇒「弹框关了、列表还是旧规则、一句话没有」，差一点直接把应用带崩。
     *
     * 判据（缺一条就红）：
     * 1. 写盘必须包在 `runCatching` 里；
     * 2. 失败分支必须给用户一句话（`SettingsStringsExt2.saveFailed`，零 ARB 改动）；
     * 3. 失败分支**不许**继续跑自动套用（否则等于把没保存说成「已保存」）。
     */
    @Test
    fun `写盘抛错必须提示 不许静默也不许假成功`() {
        val host = File(repoRoot(), SCHEDULE_HOST).readText()
        val guardAt = host.indexOf("runCatching { repository.updateScheduleDateRules(rules) }")
        assertTrue(
            "写盘没包 runCatching：仓储抛错时会从点击回调里抛出去（用户看到「点了没反应」或应用崩）",
            guardAt >= 0,
        )
        val window = host.substring(guardAt, minOf(host.length, guardAt + 700))
        assertTrue(
            "写盘失败分支没有给用户提示：必须用 `SettingsStringsExt2.saveFailed`（「保存失败」，零 ARB 改动）",
            window.contains("SettingsStringsExt2.saveFailed"),
        )
        assertTrue(
            "写盘失败分支没有走警示样式（isError = true）",
            window.contains("isError = true"),
        )
        val failureBranch = window.substringBefore("} else {")
        assertTrue(
            "失败分支里出现了 `applyDueAndReport(` / `applyDue(`：写盘没成功却去套用并报四态，" +
                "用户会看到「已保存」而规则没落盘",
            !failureBranch.contains("applyDue"),
        )
    }

    // ───────────────────── 2. 壳不许再自己跑一次 ─────────────────────

    @Test
    fun `壳不再自己 launch applyDue`() {
        val branch = dateRuleBranch(File(repoRoot(), SHELL_PAGE_INDEX).readText())
        assertTrue(
            "d2.dateRule 分支必须调 `ScheduleDateRuleHost(`（规则页宿主）",
            branch.contains("ScheduleDateRuleHost("),
        )
        assertFalse(
            "d2.dateRule 分支里又出现 `applyDue(`：自动套用收在宿主里，壳再跑一次会重复套用、" +
                "并且第二次必是 NotDue ⇒ 提示会被说成「已保存」",
            branch.contains("applyDue("),
        )
    }

    // ------------------------------------------------------------------
    // 工具
    // ------------------------------------------------------------------

    /** 切出 `d2.dateRule` 那一个 `when` 分支的源码（到 `d2.taskList` 为止）。 */
    private fun dateRuleBranch(shell: String): String {
        val start = shell.indexOf("\"d2.dateRule\" ->")
        if (start < 0) return ""
        val end = shell.indexOf("\"d2.taskList\" ->", start)
        return if (end <= start) "" else shell.substring(start, end)
    }

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

    private companion object {
        const val SCHEDULE_HOST =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/ScheduleHost.kt"
        const val SHELL_PAGE_INDEX =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
    }
}
