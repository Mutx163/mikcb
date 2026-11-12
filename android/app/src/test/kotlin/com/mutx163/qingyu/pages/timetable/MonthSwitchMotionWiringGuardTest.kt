package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 月视图过渡接线的**源码守卫**（2026-11-12，对抗审查 M1 的落地点）。
 *
 * ## 它咬的是什么行为
 *
 * 上一笔（`7147d183f`）给月页过渡补了两步门（先挂树 → 等首组合 → 再开播）与「外层 Pager
 * 在滑 ⇒ 当帧落定」的判据，但**判据读了却不会重进**：`MonthSwitchMotion.shouldSnap(...)`
 * 把 `homePagerScrolling` 当输入，而 `LaunchedEffect` 的键里没有它 ⇒ 外层 Pager 从静止开始滑
 * （`false → true`）时那个 effect 根本不重启，「接线后在叠加那一帧生效」只是没验证过的假设
 * （M1）。同一类退化还有三种：snap 分支被挪到「等首组合」门之后（底栏切月被拖一帧）、
 * 月层挂载点漏挂首组合信号（起步又空 1~2 帧、甚至永远等不到信号 ⇒ 命中层吃事件、点不动）、
 * 信号在组合期裸写状态（多一轮重组）。这四种都「编得过、页面也能打开」，只能靠读源码咬。
 *
 * ## 三条纪律
 *
 * 1. **一律走共享剥离器**（`readKotlinSourceNoStrings` / `stripKotlinComments`）：注释掉的
 *    接线不算接线。今天实测过 26 条同类文本守卫能被「把目标行注释掉」骗绿 —— 本文件除了
 *    主判据在剥注释后的源码上跑，还留了一条「整行注释掉 ⇒ 找不到那个 effect」的自测。
 * 2. **只看剥注释后的片段内相对位置**，不看行号（行号一挪就假红，最后没人敢动文件）。
 * 3. 接线类判据用**中性化字符串**那一档读法（`readKotlinSourceNoStrings`）：生产代码里随便一句
 *    日志 / 提示语含同样的字样，`contains` 就会被满足而假绿。
 */
class MonthSwitchMotionWiringGuardTest {

    /** 剥注释 + 抹掉字符串内容的页面源码：只剩真实代码骨架。 */
    private val page: String by lazy { readKotlinSourceNoStrings(WEEK_PAGE_PATH) }

    /** 文案无关的判据才用它；这里只给「纯函数存在」用（不参与接线判断）。 */
    private val motion: String by lazy { readKotlinSourceNoStrings(MOTION_PATH) }

    // ───────────────────────── a) 键必须三项齐全（M1） ─────────────────────────

    @Test
    fun `月过渡 effect 的键必须含 monthMode 与 monthContentComposed 与 homePagerScrolling`() {
        val effect = monthEffectOf(page)
        assertNotNull(
            "剥注释后找不到「键里带 `monthMode`」的 `LaunchedEffect` —— 月视图过渡的计时 effect 不见了" +
                "（或被整行注释掉）。若失败就意味着：月视图页内态不再有滑入 / 滑出过渡，" +
                "或者守卫自己失效（注释掉的接线不算接线，这条必须红）。",
            effect,
        )
        val keys = effect!!.keys
        listOf("monthMode", "monthContentComposed", "homePagerScrolling").forEach { key ->
            assertTrue(
                "月过渡 effect 的键里缺 `$key`（实际键：$keys）。" +
                    when (key) {
                        "homePagerScrolling" ->
                            "若失败就意味着 M1 复发：`MonthSwitchMotion.shouldSnap(...)` 读了它、键里却没有 ⇒" +
                                "外层 Pager 从静止开始滑（false → true）时该 effect 不重进，" +
                                "「接线后在叠加那一帧生效」又变回没验证的假设。"

                        "monthContentComposed" ->
                            "若失败就意味着打开方向的两步门失效：首组合和动画第一帧又挤同一帧，" +
                                "月内容起步空 / 顿 1~2 帧（月层是换档下一帧才首次组合）。"

                        else ->
                            "若失败就意味着 effect 不随月视图切换重启，滑入 / 滑出整个不播。"
                    },
                keys.contains(key),
            )
        }
    }

    // ───────────────────────── b) 分支顺序（snap 在门之前） ─────────────────────────

    @Test
    fun `月过渡 effect 内 snap 分支必须在等首组合门之前 且都早于 animateTo`() {
        val block = requireMonthEffectBlock()
        val snapBranch = block.indexOf(SNAPSHOT_DECISION)
        val snapCall = block.indexOf("monthExpand.snapTo(")
        val gate = block.indexOf(MOUNT_WAIT_DECISION)
        val animate = block.indexOf("monthExpand.animateTo(")

        assertTrue(
            "月过渡 effect 里找不到 `$SNAPSHOT_DECISION` —— 当帧落定的判据被删了？" +
                "若失败就意味着：减少动画 / 跨过周档的直达 / 外层 Pager 在滑 这三种情形又开始播逐帧形变。",
            snapBranch >= 0,
        )
        assertTrue(
            "月过渡 effect 里找不到 `monthExpand.snapTo(` —— 判据还在但没人落定。",
            snapCall >= 0,
        )
        assertTrue(
            "月过渡 effect 里找不到 `$MOUNT_WAIT_DECISION` —— 「先挂树等首组合」的门被删了？" +
                "若失败就意味着：月层首组合 / 首测量又和 tween 第一帧挤在同一帧。",
            gate >= 0,
        )
        assertTrue(
            "月过渡 effect 里找不到 `monthExpand.animateTo(` —— 正常播动画的那一支被删了。" +
                "若失败就意味着：周 ↔ 月的页内横滑过渡整个消失（变瞬间换字，2026-11-07 用户实报过）。",
            animate >= 0,
        )
        assertTrue(
            "`$SNAPSHOT_DECISION` 不在 `monthExpand.snapTo(` 之前 —— 判据与落定调用被拆开了。",
            snapBranch < snapCall,
        )
        assertTrue(
            "`monthExpand.snapTo(` 出现在 `$MOUNT_WAIT_DECISION` 之后（snap 分支落到了等待门后面）。" +
                "若失败就意味着：底栏切月要先空转一帧「等首组合」才落定，被拖慢 1 帧 —— 正是本轮要避免的。",
            snapCall < gate,
        )
        assertTrue(
            "`$SNAPSHOT_DECISION` / `monthExpand.snapTo(` 与 `$MOUNT_WAIT_DECISION` 的相对位置被打乱" +
                "（应为 shouldSnap → snapTo → needsMountWait）。若失败就意味着两类判据混在一起，" +
                "将来改其中一支会静默改掉另一支的行为。",
            snapBranch < gate,
        )
        assertTrue(
            "`monthExpand.animateTo(` 出现在 `$MOUNT_WAIT_DECISION` 之前（开播跑到等待门前面了）。" +
                "若失败就意味着：清假 / 重进时会在首组合完成前就开播，起步空 1~2 帧回来。",
            gate < animate,
        )
    }

    // ───────────────────────── c) 首组合信号 ─────────────────────────

    @Test
    fun `月层挂载块必须有首组合信号 且定义必须走 SideEffect`() {
        val mountHead = "if (monthMounted && monthContent != null)"
        val mountIdx = page.indexOf(mountHead)
        assertTrue(
            "剥注释后找不到月层挂载门 `$mountHead` —— 月层组合条件被改了。" +
                "若失败就意味着：守卫定位不到挂载块，「信号挂在真组合点」这件事没法验证。",
            mountIdx >= 0,
        )
        val mountBody = blockBodyAfter(page, mountIdx)
        assertTrue(
            "月层挂载块里找不到 `monthContent()` 调用 —— 守卫定位到了错误的块。",
            mountBody.contains("monthContent()"),
        )
        assertTrue(
            "月层挂载块里没有 `$SIGNAL_CALL`。若失败就意味着：月层首组合不再发信号 ⇒ 上面那个 effect" +
                "一直等在「先挂树」那一支，`monthExpand` 停在 0 而 `monthVisible` 已为真，" +
                "命中层一直吃事件，**页面点不动**。",
            mountBody.contains(SIGNAL_CALL),
        )
        assertEquals(
            "`$SIGNAL_CALL` 应恰好 1 处（月层只有一个挂载点）。若失败就意味着：要么信号挂在别处（假挂载点），" +
                "要么挂了两份（重复置真虽不进快照，但说明有人复制了挂载块）。",
            1,
            occurrences(page, SIGNAL_CALL),
        )
        val defIdx = page.indexOf("fun MonthContentMountSignal(")
        assertTrue(
            "用了 `MonthContentMountSignal { … }` 却没定义 `fun MonthContentMountSignal(` —— 文件编不过，" +
                "首组合信号永远不触发。",
            defIdx >= 0,
        )
        val defBody = blockBodyAfter(page, defIdx)
        assertTrue(
            "`MonthContentMountSignal` 的定义里不是 `SideEffect(onMounted)`。若失败就意味着：它在**组合期**" +
                "直接写状态 ⇒ 一轮额外重组；且置真时子树还没组好，「等首组合」等到的不是画好的树。",
            defBody.contains("SideEffect("),
        )
    }

    // ───────────────────────── d) 纯函数必须真被调用 ─────────────────────────

    @Test
    fun `MonthSwitchMotion 的两个判据在渲染侧必须真的被调用`() {
        assertTrue(
            "纯函数 `MonthSwitchMotion.shouldSnap(` 在 `MonthSwitchMotion.kt` 里找不到 —— 判据本体不见了。",
            motion.contains("fun shouldSnap("),
        )
        assertTrue(
            "纯函数 `MonthSwitchMotion.needsMountWait(` 在 `MonthSwitchMotion.kt` 里找不到 —— 判据本体不见了。",
            motion.contains("fun needsMountWait("),
        )
        val block = requireMonthEffectBlock()
        assertTrue(
            "月过渡 effect 里没有调用 `MonthSwitchMotion.shouldSnap(`。若失败就意味着：纯函数和真值表都还在、" +
                "单测全绿，但**渲染侧没人用** ⇒ 判据形同虚设，减少动画 / 跨过周档直达 / 外层 Pager 在滑" +
                "三种情形全部失效。",
            block.contains(SNAPSHOT_DECISION),
        )
        assertTrue(
            "月过渡 effect 里没有调用 `MonthSwitchMotion.needsMountWait(`。若失败就意味着：两步门退化成死代码，" +
                "「先挂树等首组合」实际没生效（首组合仍与 tween 第一帧挤同一帧）。",
            block.contains(MOUNT_WAIT_DECISION),
        )
    }

    // ───────────────────────── 咬合探针（合成片段，不读真源码） ─────────────────────────

    /**
     * 证明上面四条判据**有牙齿**：拿一段与真源码同形的合成片段，逐项改坏，谓词必须给出 `false`。
     *
     * ## 为什么用合成片段而不是就地改真源码
     *
     * 这里测的是**谓词本身**咬不咬得住。若探针直接 `page.replace(...)`，真源码一旦真被改坏
     * （比如外部咬合探针把键删了），替换就失效，探针会先报「探针失效」——那会把真正的
     * 失败原因盖住，看报告的人得先拆两层。合成片段让外部探针只留下**一条**真因。
     *
     * 真源码那一侧的保证由上面四条主判据负责（它们跑在真文件上）。
     *
     * 4 号探针覆盖「把接线整行注释掉」这个真实事故形态（今天实测过 26 条同类守卫会因此骗绿）：
     * 同样的片段注释掉 `LaunchedEffect(...)` 那一行、再走**共享剥离器**，必须找不到月过渡 effect。
     */
    @Test
    fun `负例自测_键缺项或顺序颠倒或信号裸写或整行注释掉都必须判红`() {
        // 与真源码同形的合成片段：三键 effect + snap 在前 + 等待门在后 + 真信号 + SideEffect 定义。
        val good = listOf(
            "fun f() {",
            "    LaunchedEffect(monthMode, monthContentComposed, homePagerScrolling) {",
            "        if (MonthSwitchMotion.shouldSnap(a, b, c)) {",
            "            monthExpand.snapTo(1f)",
            "        } else if (MonthSwitchMotion.needsMountWait(m, c, h)) {",
            "        } else if (monthExpand.value != 1f) {",
            "            monthExpand.animateTo(1f)",
            "        }",
            "    }",
            "    if (monthMounted && monthContent != null) {",
            "        MonthContentMountSignal { monthContentComposed = true }",
            "        monthContent()",
            "    }",
            "}",
            "@Composable",
            "private fun MonthContentMountSignal(onMounted: () -> Unit) { SideEffect(onMounted) }",
        ).joinToString("\n")

        // 片段自身必须先通过——否则下面的「改坏后必须为假」可能只是因为谓词恒假，属于空转。
        assertTrue("自测片段自身应通过（三键齐全）——否则下面的负例是空转。", hasAllThreeKeys(good))
        assertTrue(
            "自测片段自身应通过（snap 在等待门之前）。",
            orderOk(monthEffectOf(good)!!.block),
        )
        assertTrue("自测片段自身应通过（信号挂在挂载块里且定义走 SideEffect）。", signalOk(good))

        // 探针 1：把 homePagerScrolling 从键里摘掉（M1 原样复发）。
        val droppedKey = good.replace(", homePagerScrolling", "")
        assertFalse("探针锚点失效：片段里没有 `, homePagerScrolling`，替换没发生。", droppedKey == good)
        assertFalse(
            "探针失效：把 `homePagerScrolling` 从键里摘掉后，键判据仍然通过 —— 这条断言咬不住 M1。",
            hasAllThreeKeys(droppedKey),
        )

        // 探针 2：把等待门挪到 snap 分支前面（顺序坏了）。
        val reordered = good.replace(
            "        if (MonthSwitchMotion.shouldSnap(a, b, c)) {",
            "        if (MonthSwitchMotion.needsMountWait(a, b, c)) { } else if (MonthSwitchMotion.shouldSnap(a, b, c)) {",
        )
        assertFalse("探针锚点失效：片段里没找到 shouldSnap 分支那行。", reordered == good)
        assertFalse(
            "探针失效：等待门跑到 snap 分支之前后，顺序判据仍然通过 —— 那样底栏切月会被拖一帧。",
            orderOk(monthEffectOf(reordered)!!.block),
        )

        // 探针 3：把信号调用改成组合期裸写状态。
        val bareWrite = good.replace(SIGNAL_CALL, "monthContentComposed = true")
        assertFalse("探针锚点失效：片段里没找到信号调用。", bareWrite == good)
        assertFalse(
            "探针失效：把 `$SIGNAL_CALL` 换成组合期裸写后，信号判据仍然通过 —— 那会多一轮重组。",
            signalOk(bareWrite),
        )

        // 探针 4：整行注释掉（真实事故形态）—— 先确认注释前找得到，再确认注释后找不到。
        val commented = good.replace(
            "    LaunchedEffect(monthMode, monthContentComposed, homePagerScrolling) {",
            "    // LaunchedEffect(monthMode, monthContentComposed, homePagerScrolling) {",
        )
        assertFalse("探针锚点失效：片段里没找到那行 `LaunchedEffect(...)`。", commented == good)
        assertNotNull(
            "自测片段自身应通过：不注释时应该找得到月过渡 effect。",
            monthEffectOf(stripKotlinComments(good)),
        )
        assertNull(
            "探针失效：把 `LaunchedEffect(...)` 整行注释掉、再走共享剥离器之后，仍然找得到月过渡 effect ——" +
                "说明判据能被「注释掉目标行」骗绿（今日实测 26 条同类守卫中招）。",
            monthEffectOf(stripKotlinComments(commented)),
        )
    }

    // ───────────────────────── 工具 ─────────────────────────

    private data class Effect(val keys: List<String>, val block: String)

    /** 剥注释后的源码里所有 `LaunchedEffect(keys) { … }`（含嵌套，按出现顺序）。 */
    private fun effectsOf(source: String): List<Effect> {
        val out = ArrayList<Effect>()
        var from = 0
        while (true) {
            val open = source.indexOf("LaunchedEffect(", from)
            if (open < 0) return out
            val parenOpen = source.indexOf('(', open)
            val parenClose = matchingParen(source, parenOpen)
            if (parenClose < 0) return out
            val keys = source.substring(parenOpen + 1, parenClose)
                .split(",")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
            val brace = source.indexOf('{', parenClose)
            if (brace >= 0) {
                val end = matchingBrace(source, brace)
                if (end > 0) out.add(Effect(keys, source.substring(brace + 1, end)))
            }
            from = open + 1
        }
    }

    /** 键里带 `monthMode` 的那个 effect（月视图过渡计时）。找不到返回 null。 */
    private fun monthEffectOf(source: String): Effect? =
        effectsOf(source).firstOrNull { it.keys.contains("monthMode") }

    private fun requireMonthEffectBlock(): String {
        val effect = monthEffectOf(page)
        assertNotNull(
            "剥注释后找不到「键里带 `monthMode`」的 `LaunchedEffect` —— 月视图过渡的计时 effect 不见了" +
                "（或被整行注释掉）。守卫无法验证，按失败处理。",
            effect,
        )
        return effect!!.block
    }

    private fun hasAllThreeKeys(source: String): Boolean {
        val keys = monthEffectOf(source)?.keys ?: return false
        return keys.contains("monthMode") &&
            keys.contains("monthContentComposed") &&
            keys.contains("homePagerScrolling")
    }

    /** 顺序判据的纯谓词（与主断言同一口径，探针直接调它）。 */
    private fun orderOk(block: String): Boolean {
        val snapBranch = block.indexOf(SNAPSHOT_DECISION)
        val snapCall = block.indexOf("monthExpand.snapTo(")
        val gate = block.indexOf(MOUNT_WAIT_DECISION)
        val animate = block.indexOf("monthExpand.animateTo(")
        return snapBranch >= 0 && snapCall > snapBranch && gate > snapCall && animate > gate
    }

    /** 信号判据的纯谓词：挂载块里有信号调用，且定义走 `SideEffect`。 */
    private fun signalOk(source: String): Boolean {
        val mountIdx = source.indexOf("if (monthMounted && monthContent != null)")
        if (mountIdx < 0) return false
        if (!blockBodyAfter(source, mountIdx).contains(SIGNAL_CALL)) return false
        if (occurrences(source, SIGNAL_CALL) != 1) return false
        val defIdx = source.indexOf("fun MonthContentMountSignal(")
        if (defIdx < 0) return false
        return blockBodyAfter(source, defIdx).contains("SideEffect(")
    }

    /** 从 [fromIndex] 起第一个 `{` 到其配对 `}` 之间的块体。 */
    private fun blockBodyAfter(source: String, fromIndex: Int): String {
        val open = source.indexOf('{', fromIndex)
        if (open < 0) throw AssertionError("从下标 $fromIndex 起找不到 `{`")
        val end = matchingBrace(source, open)
        if (end < 0) throw AssertionError("花括号不配对")
        return source.substring(open + 1, end)
    }

    private fun matchingBrace(source: String, openIndex: Int): Int {
        if (openIndex < 0) return -1
        var depth = 0
        for (i in openIndex until source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
        }
        return -1
    }

    private fun matchingParen(source: String, openIndex: Int): Int {
        if (openIndex < 0) return -1
        var depth = 0
        for (i in openIndex until source.length) {
            when (source[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
        }
        return -1
    }

    private fun occurrences(source: String, needle: String): Int {
        var count = 0
        var from = 0
        while (true) {
            val i = source.indexOf(needle, from)
            if (i < 0) return count
            count++
            from = i + 1
        }
    }

    private companion object {
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val MOTION_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/MonthSwitchMotion.kt"

        /** 判据调用的完整形态，锚到「哪个对象」避免同名函数骗过守卫。 */
        val SNAPSHOT_DECISION = "MonthSwitchMotion.shouldSnap("
        val MOUNT_WAIT_DECISION = "MonthSwitchMotion.needsMountWait("
        const val SIGNAL_CALL = "MonthContentMountSignal { monthContentComposed = true }"
    }
}
