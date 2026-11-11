package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「吸附世代令牌」守卫（2026-11-11 复核发现，同日升档）。
 *
 * ## 咬的是什么缺陷
 *
 * `cancel()` **不等待**：挂在 `withFrameNanos` 上的取消要下一帧才落地，所以旧吸附 job 的
 * `finally` 会在**新手势第一发 update 之后**才执行。没有令牌时它会把 `expandValue` 写回
 * **旧 target**（一帧回跳）、还会把可能已是新目标的 `settleTargetValue` 清成 null ——
 * 也就是「刚按下就被上一笔的收尾拽回去一帧」。
 *
 * 正确写法（本守卫逐条咬）：
 * 1. 每次按下打断都自增令牌（`settleGeneration++`），让在跑的吸附立刻作废；
 * 2. 每次起吸附记下本次世代（`val generation = ++settleGeneration`）；
 * 3. `finally` 里**只在本世代**落端点，且必须先开 `finally` 再判门控。
 *
 * ## 为什么读源码要剥注释（2026-11-11 升档）
 *
 * 这份 KDoc 本身就会写出上面那几段代码形态。旧版直接用 `readText()` + `contains()`，
 * 于是「把真实接线删掉、只留下注释里的示例」也能骗绿 —— 本轮升到共享件
 * [readKotlinSourceNormalized]（剥注释、保字面量），再补**顺序**断言：光有这三个片段还不够，
 * 必须按「记世代 → 进 finally → 门控」的次序出现，否则就是拼凑出来的假接线。
 *
 * 这是 composeP1 里的状态机，L0 编译不到，所以按仓库惯例用源码扫描 + 负例自测钉住。
 */
class MonthSettleGenerationGuardTest {

    // 剥掉注释后的源码：注释里写同款形态不会假绿（`页` 这个变量的含义就是「代码骨架」）。
    private val page: String by lazy { readKotlinSourceNormalized(VIEW_PAGE_PATH) }

    @Test
    fun `吸附收尾带世代令牌_三条缺一不可`() {
        assertTrue(
            "onDragStart 打断旧吸附时没有自增 settleGeneration：旧 job 迟到的 finally 仍会写。",
            page.contains(DRAG_START_BUMP),
        )
        assertTrue(
            "onDragEnd 起吸附时没有记本次世代（$GENERATION_RECORD）。",
            page.contains(GENERATION_RECORD),
        )
        assertTrue(
            "finally 里没有 `$GENERATION_GATE` 门控：旧吸附的收尾会把进度写回旧 target（一帧回跳）。",
            page.contains(GENERATION_GATE),
        )
    }

    @Test
    fun `世代令牌必须按 打断自增_记世代_进 finally_门控 的顺序出现`() {
        val bump = page.indexOf(DRAG_START_BUMP)
        val record = page.indexOf(GENERATION_RECORD)
        val finallyBlock = if (record >= 0) page.indexOf("finally {", record) else -1
        val gate = if (finallyBlock >= 0) page.indexOf(GENERATION_GATE, finallyBlock) else -1

        assertTrue("找不到打断自增（$DRAG_START_BUMP）", bump >= 0)
        assertTrue("找不到记世代（$GENERATION_RECORD）", record >= 0)
        assertTrue(
            "记世代之后没有 finally 块：端点写入不在 finally 里，被打断/取消时就不会落端点。",
            finallyBlock > record,
        )
        assertTrue(
            "finally 里没有世代门控（$GENERATION_GATE）：迟到的旧 job 仍会写。",
            gate > finallyBlock,
        )
        assertTrue(
            "打断自增必须出现在起吸附之前（先作废旧世代，再开新世代）。",
            bump in 0 until record,
        )
    }

    // 咬合探针：把 finally 的世代门控去掉，判据必须变红（用剥注释后的源码做变异，
    // 与真实判据同一条读法，避免「只在 readText 上红」的假探针）。
    @Test
    fun `负例自测_去掉世代门控会被判红`() {
        assertTrue("原文件应通过（三件都在且顺序对）", hasOrderedToken(page))
        val mutated = page.replace(GENERATION_GATE, "if (true)")
        assertFalse(
            "探针失效：去掉 finally 的世代门控后，判据仍为真。",
            hasOrderedToken(mutated),
        )
    }

    /** 判据本体：三件齐全 + 顺序「打断自增 → 记世代 → finally → 门控」。 */
    private fun hasOrderedToken(source: String): Boolean {
        val bump = source.indexOf(DRAG_START_BUMP)
        val record = source.indexOf(GENERATION_RECORD)
        if (bump < 0 || record < 0 || bump >= record) return false
        val finallyBlock = source.indexOf("finally {", record)
        if (finallyBlock <= record) return false
        return source.indexOf(GENERATION_GATE, finallyBlock) > finallyBlock
    }

    private companion object {
        const val VIEW_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt"

        const val DRAG_START_BUMP = "settleGeneration++"
        const val GENERATION_RECORD = "val generation = ++settleGeneration"
        const val GENERATION_GATE = "if (settleGeneration == generation)"
    }
}
