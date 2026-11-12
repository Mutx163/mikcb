package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

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
 *
 * ## 读法：剥注释 + **中性化档**，而且**先切片再剥离**（2026-11-12 B3 批）
 *
 * 两条口径，与 `GuardSourceStrippingPolicyTest` 绑在一起：
 *
 * 1. **剥注释**（`readKotlinSourceNoStrings` / `stripKotlinComments`）：不剥时把目标行注释掉
 *    它照样命中——注释掉的那行**原文还在**（`// toast = RuleToast(SettingsStringsExt2.saveFailed…`），
 *    `contains` 被自己的注释喂饱。B3 批实测过：注释掉失败分支那句提示，迁移前版本仍全绿。
 * 2. **中性化字符串**（`neutralizeStrings = true`）：本文件九条判据判的全是**代码结构**
 *    （调用、实参名、赋值、分支里有没有 `applyDue(`），没有一条判「某字面量许不许出现」。
 *    这类判据最怕生产代码里一句日志 / 提示语含同样片段把 `contains` 喂饱，抹掉字符串正好消掉这个面。
 *    反向的坑确认过：没有任何一条判据需要读字符串内容，中性化不会把判据擦空。
 *
 * **为什么必须「先切片再剥离」**：`dateRuleBranch()` 的切片锚是**字符串字面量**
 * `"d2.dateRule" ->`（壳的路由 key）。先中性化再切，锚会变成一串空格、`indexOf` 永远返回 -1
 * ⇒ 分支恒空 ⇒ 判据要么假红要么空跑。所以顺序固定为：**在「剥过注释、保留字面量」的文本上切，
 * 切出来的片段再中性化**。两步各有各的用处，别合并。
 */
class ScheduleDateRuleApplyWiringGuardTest {

    /** 宿主源码：剥注释 + 中性化字符串（口径见类注释）。 */
    private val host by lazy { readKotlinSourceNoStrings(SCHEDULE_HOST) }

    // ───────────────────── 0. 不空跑 ─────────────────────

    @Test
    fun `判据锚点存在`() {
        assertTrue(
            "ScheduleHost.kt 里找不到 ScheduleDateRuleHost（文件被挪走后必须同步本守卫）",
            host.contains("fun ScheduleDateRuleHost("),
        )
        assertTrue(
            "找不到 d2.dateRule 分支（壳改结构后必须同步本守卫）",
            dateRuleBranch().isNotBlank(),
        )
    }

    // ───────────────────── 1. applyDue 的返回值必须被消费 ─────────────────────

    @Test
    fun `宿主把 applyDue 的返回值交给四态判据`() {
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
     *
     * 切片口径：窗口从写盘那行起取 700 个字符（**在已剥注释 + 已中性化**的文本上取），
     * 失败分支 = 窗口里 `} else {` 之前那段。窗口长度沿用迁移前的 700，没有放宽。
     */
    @Test
    fun `写盘抛错必须提示 不许静默也不许假成功`() {
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
        val branch = dateRuleBranch()
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

    /**
     * 切出 `d2.dateRule` 那一个 `when` 分支（到 `d2.taskList` 为止）并剥成「只剩代码骨架」。
     *
     * **顺序不许反**：起点/终点锚都是字符串字面量（路由 key），所以先在
     * `readKotlinSourceNormalized`（剥注释、保留字面量）的文本上切片，再对切片中性化。
     * 找不到起点返回空串——由上层断言报红，不静默跳过。
     */
    private fun dateRuleBranch(): String {
        val shell = readKotlinSourceNormalized(SHELL_PAGE_INDEX)
        val start = shell.indexOf(ROUTE_DATE_RULE)
        if (start < 0) return ""
        val end = shell.indexOf(ROUTE_TASK_LIST, start)
        if (end <= start) return ""
        return stripKotlinComments(shell.substring(start, end), neutralizeStrings = true)
    }

    private companion object {
        const val SCHEDULE_HOST =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/ScheduleHost.kt"
        const val SHELL_PAGE_INDEX =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"

        /** 分支切片锚（壳里的路由 key，本身是字符串字面量 ⇒ 只能先切后剥）。 */
        const val ROUTE_DATE_RULE = "\"d2.dateRule\" ->"
        const val ROUTE_TASK_LIST = "\"d2.taskList\" ->"
    }
}
