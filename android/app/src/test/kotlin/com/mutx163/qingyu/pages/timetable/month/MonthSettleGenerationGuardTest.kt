package com.mutx163.qingyu.pages.timetable.month

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「吸附世代令牌」守卫（2026-11-11 复核发现）。
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
 * 3. `finally` 里**只在本世代**落端点（`if (settleGeneration == generation)`）。
 *
 * 这是 composeP1 里的状态机，L0 编译不到，所以按仓库惯例用源码扫描 + 负例自测钉住。
 */
class MonthSettleGenerationGuardTest {

    private val page: String by lazy { read(VIEW_PAGE_PATH) }

    @Test
    fun `吸附收尾带世代令牌_三条缺一不可`() {
        assertTrue(
            "onDragStart 打断旧吸附时没有自增 settleGeneration：旧 job 迟到的 finally 仍会写。",
            page.contains("settleGeneration++"),
        )
        assertTrue(
            "onDragEnd 起吸附时没有记本次世代（val generation = ++settleGeneration）。",
            page.contains("val generation = ++settleGeneration"),
        )
        assertTrue(
            "finally 里没有 `if (settleGeneration == generation)` 门控：" +
                "旧吸附的收尾会把进度写回旧 target（一帧回跳）。",
            page.contains("if (settleGeneration == generation)"),
        )
    }

    // 咬合探针：把 finally 的世代门控去掉，判据必须变红。
    @Test
    fun `负例自测_去掉世代门控会被判红`() {
        assertTrue("原文件应通过（三条都在）", hasTokenGuard(page))
        val mutated = page.replace("if (settleGeneration == generation)", "if (true)")
        assertFalse(
            "探针失效：去掉 finally 的世代门控后，判据仍为真。",
            hasTokenGuard(mutated),
        )
    }

    private fun hasTokenGuard(source: String): Boolean =
        source.contains("settleGeneration++") &&
            source.contains("val generation = ++settleGeneration") &&
            source.contains("if (settleGeneration == generation)")

    private fun read(rel: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, rel)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $rel —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val VIEW_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt"
    }
}
