package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 月视图页内态过渡的两处时序判据（[MonthSwitchMotion]，2026-11-12）。
 *
 * ## 它防的是哪两类事故
 *
 * 这两条判据都是「改完之后页面照样编得过、月视图照样能切，只是那两处时序毛病悄悄回来」：
 *
 * 1. `shouldSnap` 漏掉任一条 ⇒ 要么「减少动画」被无视（无障碍降级失效），要么跨过周档的
 *    直达又被播成滑入（周网格在中间露出来，`4bd6b1fe4` 修掉的问题复活），要么外层底栏
 *    Pager 的 spring 与页内 360ms tween **同帧叠加**（连点底栏时画面被拽两次）。
 * 2. `needsMountWait` 的真值判错 ⇒ 要么回到「首组合与动画第一帧挤同一帧」（起步空 1~2 帧），
 *    要么在 `hasContent = false` 时也去等 ⇒ 永远等不到信号，`monthExpand` 停在 0 而
 *    `monthVisible` 已为真，命中层一直吃事件，**页面点不动**。
 *
 * 判据是纯函数（无 Compose / 无 Android），所以这里直接把真值表钉死；渲染层只剩
 * 「取哪个布尔」的薄适配，由 `TimetableWeekPage` 的 effect 顺序（源码守卫）另行约束。
 */
class MonthSwitchMotionTest {

    /**
     * `shouldSnap` 的**全组合**（三个布尔 = 8 行）。
     *
     * 顺序按 [MonthSwitchMotion.shouldSnap] 的形参来：`reducedMotion, animate, outerPagerScrolling`。
     * 期望 = `reducedMotion || !animate || outerPagerScrolling`——三件「不该播」的事任一成立即落定。
     */
    @Test
    fun `shouldSnap 三输入全组合_任一为真即落定`() {
        // (reducedMotion, animate, outerPagerScrolling) -> 期望是否落定
        val expected = mapOf(
            // ── 唯一「播动画」的一行：没开减少动画、调用方允许播、外层也已停稳 ──
            Triple(false, true, false) to false,
            // ── 减少动画：无障碍降级，系统把动画时长缩放归零 ──
            Triple(true, true, false) to true,
            Triple(true, true, true) to true,
            Triple(true, false, false) to true,
            Triple(true, false, true) to true,
            // ── 调用方要求不播：跨过周档的直达（`HomeViewSwitchMotion.directAcrossWeek`）──
            Triple(false, false, false) to true,
            Triple(false, false, true) to true,
            // ── 外层底栏 Pager 仍在 spring 滑行：页内再播 tween 就是真叠加 ──
            Triple(false, true, true) to true,
        )

        // 表格必须覆盖全部 8 种组合，少一行等于漏测一个分支。
        assertEquals(
            "表里应覆盖 3 个布尔的全部 8 种组合（少一行就漏了一个分支）——现在是 ${expected.size} 行。",
            8,
            expected.size,
        )

        expected.forEach { (input, want) ->
            val (reducedMotion, animate, outerPagerScrolling) = input
            val what = "shouldSnap(reducedMotion=$reducedMotion, animate=$animate, " +
                "outerPagerScrolling=$outerPagerScrolling)"
            val got = MonthSwitchMotion.shouldSnap(reducedMotion, animate, outerPagerScrolling)
            assertEquals(
                "「$what」期望 $want，实际 $got。" +
                    if (want) {
                        "若失败意味着：这三条「不该播」的判据里有一条没进 `||` 链——" +
                            "要么减少动画降级失效、要么跨过周档的直达又被播成滑入（周网格会在中间露出来）、" +
                            "要么外层 spring 与页内 tween 真叠加。"
                    } else {
                        "若失败意味着：本来该正常播 360ms tween 的那一支被误判成「直接落定」，" +
                            "周 ↔ 月的横滑过渡会整个消失（变成瞬间换字，正是 2026-11-07 用户实报的问题）。"
                    },
                want,
                got,
            )
        }
    }

    /**
     * 另外两条单点断言（不靠上面的表）：全假必须**不落定**、任一为真必须**落定**。
     *
     * 与上面的全组合重复是**故意**的：表驱动写错（比如把 `to false` 抄成 `to true`）时，
     * 这两条会单独红，直接指出「最核心的那一支翻了」，而不是让人对着 8 行表逐行数。
     */
    @Test
    fun `shouldSnap 全假不落定_任一为真必落定`() {
        assertFalse(
            "「减少动画关 + 允许播 + 外层已停稳」本应正常播动画，却判成落定。" +
                "若失败意味着：周 ↔ 月的页内横滑过渡被抹平，用户只看到瞬间换字。",
            MonthSwitchMotion.shouldSnap(
                reducedMotion = false,
                animate = true,
                outerPagerScrolling = false,
            ),
        )
        assertTrue(
            "开了「减少动画」却仍要播逐帧形变。若失败意味着：无障碍降级失效，" +
                "用户关掉系统动画后仍被这套 360ms 形变拖着。",
            MonthSwitchMotion.shouldSnap(
                reducedMotion = true,
                animate = true,
                outerPagerScrolling = false,
            ),
        )
        assertTrue(
            "调用方明确要求不播（跨过周档的直达）却仍要播。" +
                "若失败意味着：`4bd6b1fe4` 修掉的「月 ↔ 日在周网格上停一下」会复发。",
            MonthSwitchMotion.shouldSnap(
                reducedMotion = false,
                animate = false,
                outerPagerScrolling = false,
            ),
        )
        assertTrue(
            "外层底栏 Pager 还在 spring 滑行，页内却仍要播 360ms tween。" +
                "若失败意味着：连点底栏时外层位移与页内形变同帧叠加，画面像被拽了两次（唯一真叠加窗口）。",
            MonthSwitchMotion.shouldSnap(
                reducedMotion = false,
                animate = true,
                outerPagerScrolling = true,
            ),
        )
    }

    /**
     * `needsMountWait` 的真值表（3 个布尔 = 8 行）：`monthMode && !contentComposed && hasContent`。
     *
     * 重点两处：`hasContent = false` 时**必须不等**（没有内容可挂就永远等不到信号），
     * 以及收起方向（`monthMode = false`）**必须不等**（否则收起永远播不完、月层永不卸载）。
     */
    @Test
    fun `needsMountWait 真值表_只有已进月且未组好且有内容才等`() {
        // (monthMode, contentComposed, hasContent) -> 期望是否等首组合信号
        val expected = mapOf(
            // ── 唯一「等」的一行：已进月、还没组好、有正文可挂 ──
            Triple(true, false, true) to true,
            // ── 已组好：信号已经到了，直接开播，再等就是白等一帧 ──
            Triple(true, true, true) to false,
            // ── 没有内容可挂：等不到信号，monthExpand 停在 0 而 monthVisible 已真 ⇒ 页面点不动 ──
            Triple(true, false, false) to false,
            Triple(true, true, false) to false,
            // ── 收起方向：一律不等，否则收起动画播不完、monthMounted 永远不归假 ──
            Triple(false, false, true) to false,
            Triple(false, true, true) to false,
            Triple(false, false, false) to false,
            Triple(false, true, false) to false,
        )

        assertEquals(
            "表里应覆盖 3 个布尔的全部 8 种组合（少一行就漏了一个分支）——现在是 ${expected.size} 行。",
            8,
            expected.size,
        )

        expected.forEach { (input, want) ->
            val (monthMode, contentComposed, hasContent) = input
            val what = "needsMountWait(monthMode=$monthMode, contentComposed=$contentComposed, " +
                "hasContent=$hasContent)"
            val got = MonthSwitchMotion.needsMountWait(monthMode, contentComposed, hasContent)
            assertEquals(
                "「$what」期望 $want，实际 $got。" +
                    if (want) {
                        "若失败意味着：打开方向的「先挂树 → 等首组合 → 再开播」两步门被绕开，" +
                            "首组合 / 首测量又和 tween 第一帧挤在同一帧，月内容起步空 1~2 帧。"
                    } else {
                        "若失败意味着：本该直接开播（或直接收起）的那一支被拖进「等信号」——" +
                            "轻则白等一帧；重则 `hasContent = false` 时永远等不到信号、" +
                            "`monthExpand` 停在 0 而 `monthVisible` 已为真，命中层一直吃事件、页面点不动；" +
                            "收起方向被拦则月层永不卸载、下一次打开拿旧值直接开播。"
                    },
                want,
                got,
            )
        }
    }

    /** 单点兜底：`hasContent = false` 永不等待（防「永远等不到信号」这条最致命的退化）。 */
    @Test
    fun `needsMountWait 没有内容可挂时永不等待`() {
        assertFalse(
            "`monthContent == null` 时仍要等首组合信号。若失败意味着：没有东西会被挂上树，" +
                "信号永远不来，`monthExpand` 卡在 0 而 `monthVisible` 已为真 —— 命中层一直吃事件，页面点不动。",
            MonthSwitchMotion.needsMountWait(
                monthMode = true,
                contentComposed = false,
                hasContent = false,
            ),
        )
        assertFalse(
            "收起方向（monthMode = false）仍要等首组合信号。" +
                "若失败意味着：收起动画被无限期挂起，`monthMounted` 不归假、月层不卸载。",
            MonthSwitchMotion.needsMountWait(
                monthMode = false,
                contentComposed = false,
                hasContent = true,
            ),
        )
    }
}
