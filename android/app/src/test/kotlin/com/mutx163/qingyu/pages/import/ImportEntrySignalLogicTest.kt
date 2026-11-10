package com.mutx163.qingyu.pages.import

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 导入入口页「子页导入成功」三态决策的行为契约测试（J8 / J11，2026-11-10 评审六三态方案）。
 *
 * 直接断言 [ImportEntrySignalLogic.decide] 与 [ImportEntrySignalLogic.baselineAfter]，
 * 不经 Compose。三态各自对应一条真实流程：
 *
 * | 用例 | awaiting | resumed | 期望 |
 * |---|---|---|---|
 * | 自己的子页回来了（正常流程收尾） | true | true | Consume |
 * | 自己的子页还盖在上面（正常流程中段） | true | false | Wait（**不推进基线**） |
 * | 外部「打开方式」推来的子页（入口页无辜） | false | 任意 | Ignore（推进基线、不消费） |
 */
class ImportEntrySignalLogicTest {

    private fun decide(awaiting: Boolean, resumed: Boolean, gen: Int, baseline: Int) =
        ImportEntrySignalLogic.decide(
            awaitingMyChild = awaiting,
            pageResumed = resumed,
            importGeneration = gen,
            importGenerationAtMount = baseline,
        )

    @Test
    fun `自己的子页回来且本页在前台 才 Consume`() {
        assertEquals(
            "入口页自己 push 的子页导入成功、入口页已回到前台时必须自关（发布版 pop(true) 为真）。",
            ImportEntrySignalLogic.Decision.Consume,
            decide(awaiting = true, resumed = true, gen = 5, baseline = 4),
        )
    }

    @Test
    fun `自己的子页还盖在上面时 Wait 且不推进基线`() {
        assertEquals(
            "子页还在上面时不许自关（会把正在展示的页面抽掉）。",
            ImportEntrySignalLogic.Decision.Wait,
            decide(awaiting = true, resumed = false, gen = 5, baseline = 4),
        )
        assertEquals(
            "Wait 决策绝不许推进基线：推进了就等于把这次增长作废，正常流程的自关直接丢失。",
            4,
            ImportEntrySignalLogic.baselineAfter(
                decision = ImportEntrySignalLogic.Decision.Wait,
                importGeneration = 5,
                importGenerationAtMount = 4,
            ),
        )
    }

    @Test
    fun `Wait 之后回到前台 仍能 Consume`() {
        // Wait 不推进基线 ⇒ 回前台时代数仍然 > 基线，这一判据才成立。
        assertEquals(
            "被盖住那一下等了之后，回到前台必须还能消费（正常流程自关的收尾）。",
            ImportEntrySignalLogic.Decision.Consume,
            decide(awaiting = true, resumed = true, gen = 5, baseline = 4),
        )
    }

    @Test
    fun `外部入口推来的子页 被盖住是 Ignore 并推进基线`() {
        assertEquals(
            "不是本页推的子页（外部「打开方式」），被盖住时只能 Ignore。",
            ImportEntrySignalLogic.Decision.Ignore,
            decide(awaiting = false, resumed = false, gen = 5, baseline = 4),
        )
        assertEquals(
            "Ignore 必须推进基线：外部那页的结果不属于本页，否则回到前台会拿旧增长补触发。",
            5,
            ImportEntrySignalLogic.baselineAfter(
                decision = ImportEntrySignalLogic.Decision.Ignore,
                importGeneration = 5,
                importGenerationAtMount = 4,
            ),
        )
    }

    @Test
    fun `外部入口回到前台 基线已推进所以不补触发`() {
        // 模拟调用方：被盖住那一下 Ignore → 基线变 5；回到前台再判仍是 Ignore。
        val afterCovered = ImportEntrySignalLogic.baselineAfter(
            decision = decide(awaiting = false, resumed = false, gen = 5, baseline = 4),
            importGeneration = 5,
            importGenerationAtMount = 4,
        )
        assertEquals(
            "回到前台不许拿外部入口那笔旧增长补触发（会把用户脚下的入口页弹掉）。",
            ImportEntrySignalLogic.Decision.Ignore,
            decide(awaiting = false, resumed = true, gen = 5, baseline = afterCovered),
        )
    }

    @Test
    fun `前台但代数没增长也是 Ignore`() {
        assertEquals(
            "代数等于基线时不许自关。",
            ImportEntrySignalLogic.Decision.Ignore,
            decide(awaiting = true, resumed = true, gen = 4, baseline = 4),
        )
        assertEquals(
            "代数小于基线（跨次残留的旧值）时不许自关。",
            ImportEntrySignalLogic.Decision.Ignore,
            decide(awaiting = true, resumed = true, gen = 3, baseline = 4),
        )
    }

    @Test
    fun `Consume 也要推进基线`() {
        assertEquals(
            "Consume 之后同样要推进基线（否则同一笔增长会反复触发 onBack）。",
            5,
            ImportEntrySignalLogic.baselineAfter(
                decision = ImportEntrySignalLogic.Decision.Consume,
                importGeneration = 5,
                importGenerationAtMount = 4,
            ),
        )
    }
}
