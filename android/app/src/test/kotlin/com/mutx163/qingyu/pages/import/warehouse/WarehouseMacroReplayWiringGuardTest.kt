package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「登录前缀内 fill 跳过」接线守卫（读源码文本，纯 JVM）。
 *
 * ## 防的是哪一类回归
 *
 * 判据函数写好了、测试也绿，但**没人调**（或调用被挪到 `onComplete(false` 之后，永远走不到）、
 * 新容忍把 click 那条既有容忍**顶掉**了、或调用点把信号写死成 `true`（于是登录页上的 fill
 * 一律可跳）。这几种都不会让行为级用例红——它们只在「源码形状」上看得出来，所以单独钉。
 *
 * ## 写法纪律
 *
 * - **不自写剥注释正则**：一律走 `testutil` 的 [readKotlinSourceNoStrings]（剥注释 + 字符串内容
 *   中性化）。字符串中性化是必需的：`onSkipLog` 的留痕里就有 `playback skipped auth prefix…`
 *   这类字样，不中性化时「判据被字符串满足」就是假绿。
 * - 否定式断言走 `assertSourceLacks`：空读先红，不会「没找到所以通过」。
 * - 切片一律**点名两端锚**（本方法签名 → 下一个成员签名）并先断言两端都在；块体函数中间有
 *   空行，用「到下一个空行」切会切掉函数体（那样 `onComplete(false` 根本不在切片里，断言反而
 *   因为找不到而红得莫名其妙）。
 */
class WarehouseMacroReplayWiringGuardTest {

    /** 回放引擎（接线在 `runSteps`）。 */
    private val replayerSource: String by lazy {
        readKotlinSourceNoStrings(REPLAYER_PATH)
    }

    /** 判据面（两条纯函数）。 */
    private val logicSource: String by lazy {
        readKotlinSourceNoStrings(LOGIC_PATH)
    }

    /**
     * ①②③⑤：`runSteps` 里，新增的跳过判据必须在失败上报**之前**、必须有 `onSkipLog` 留痕、
     * 必须与既有 click 容忍**并列**，且信号必须由 `warehouseMacroDocumentChanged` 现算。
     */
    @Test
    fun `runSteps 里登录前缀跳过在失败上报之前 且不覆盖既有 click 容忍`() {
        val body = sliceBetween(replayerSource, RUN_STEPS, EXECUTE_STEP)

        // ① 调用点在，且在失败上报之前。
        assertSourceContains(body, "shouldSkipWarehouseAuthFillStep(", "runSteps")
        val skipCallAt = body.indexOf("shouldSkipWarehouseAuthFillStep(")
        // 源码里 onComplete 的实参是换行缩进的（`onComplete(\n    false,`），所以用容忍空白的正则，
        // 而不是字面量 "onComplete(false"——后者在格式化过的代码里永远找不到，会把这条守卫
        // 变成「锚点失效型红灯」而不是真正的判据。
        val failReport = Regex("""onComplete\(\s*false""").find(body)
        assertTrue(
            "runSteps 里找不到 `onComplete(false`（失败上报）——解析锚点可能失效了",
            failReport != null,
        )
        assertTrue(
            "runSteps 里 onComplete(false 出现在 shouldSkipWarehouseAuthFillStep( 之前 ⇒ 跳过判据在" +
                "失败上报之后，永远走不到：写好了等于没接",
            failReport!!.range.first > skipCallAt,
        )

        // ② 跳过必须留痕。
        assertSourceContains(body, "onSkipLog(", "runSteps")
        val skipLogAt = body.indexOf("onSkipLog(", skipCallAt)
        assertTrue(
            "shouldSkipWarehouseAuthFillStep( 之后没有 onSkipLog( ⇒ 少做一步不留痕：" +
                "将来「导入成功但数据不对」查不出是这里放过的",
            skipLogAt > skipCallAt,
        )

        // ③ 既有 click 容忍必须仍在，且在新增判据之前（并列，不是被替换）。
        assertSourceContains(body, "shouldSkipWarehouseStaleClickStep(", "runSteps")
        val staleCallAt = body.indexOf("shouldSkipWarehouseStaleClickStep(")
        assertTrue(
            "既有 shouldSkipWarehouseStaleClickStep 不见了 ⇒ 新容忍把作废点击那条顶掉了：" +
                "旧宏「点在已翻过去的页面上」会重新变成整条失败",
            staleCallAt >= 0,
        )
        assertTrue(
            "shouldSkipWarehouseStaleClickStep 被挪到新判据之后 ⇒ 两条容忍的先后关系变了",
            staleCallAt < skipCallAt,
        )
        // click 那条自己的判据参数也必须在（防「留着调用、把实参写死」的空壳）。
        assertSourceContains(body, "previousClickNavigated = previousClickNavigated", "runSteps")

        // ⑤ 信号不许写死：pastLoginPage 必须由 warehouseMacroDocumentChanged(importUrl, 当前 href) 现算。
        assertSourceContains(body, "pastLoginPage = warehouseMacroDocumentChanged(", "runSteps")
        assertSourceContains(body, "importUrl", "runSteps")
    }

    /** ④ 甲的实现判据只认 ACTIVE：放宽成「不等于 INACTIVE」会把 UNKNOWN/TIMEOUT 也放过去。 */
    @Test
    fun `shouldDropAuthPrefixOnReplay 的返回条件只有 ACTIVE`() {
        val body = sliceBetween(logicSource, DROP_AUTH_PREFIX, SKIP_AUTH_FILL)

        assertSourceContains(body, "WarehouseSessionProbeVerdict.ACTIVE", "shouldDropAuthPrefixOnReplay")
        assertSourceLacks(body, "INACTIVE", "shouldDropAuthPrefixOnReplay")
        assertSourceLacks(body, "UNKNOWN", "shouldDropAuthPrefixOnReplay")
        assertSourceLacks(body, "TIMEOUT", "shouldDropAuthPrefixOnReplay")
    }

    /** 乙的信号必须是 `pastLoginPage`（「已离开入口登录页」），不是会话裁决；前缀边界不许丢。 */
    @Test
    fun `shouldSkipWarehouseAuthFillStep 的信号参数是 pastLoginPage 且保留前缀边界`() {
        val body = sliceBetween(logicSource, SKIP_AUTH_FILL, ELEMENT_FOUND)

        assertSourceContains(body, "pastLoginPage: Boolean", "shouldSkipWarehouseAuthFillStep")
        assertSourceLacks(body, "sessionActive", "shouldSkipWarehouseAuthFillStep")
        // 前缀边界是判据本体：去掉 `stepIndex < authPrefixEnd` 就变成「整条宏都能跳」。
        assertSourceContains(body, "stepIndex < authPrefixEnd", "shouldSkipWarehouseAuthFillStep")
        assertSourceContains(body, "stepIndex >= 0", "shouldSkipWarehouseAuthFillStep")
    }

    // ---------------------------------------------------------------------
    // 工具
    // ---------------------------------------------------------------------

    /**
     * 取两个锚之间的源码：从 [signature] 起、到其后第一个 [nextSignature] 为止。
     *
     * 两端都必须找得到，否则**就地红**——拿空串做 `contains` 的守卫是最危险的那种（恒真/恒假
     * 都看不出来）。剥注释后 KDoc 留下的是空行，被切掉的只是注释，判据只看真实代码骨架。
     */
    private fun sliceBetween(source: String, signature: String, nextSignature: String): String {
        val start = source.indexOf(signature)
        assertTrue("源码里找不到锚点 $signature（守卫锚点失效，别让它静默通过）", start >= 0)
        val end = source.indexOf(nextSignature, start + signature.length)
        assertTrue(
            "找不到 $signature 之后的锚点 $nextSignature（切片解析可能失效）",
            end > start,
        )
        return source.substring(start, end)
    }

    private companion object {
        const val REPLAYER_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseMacroReplayer.kt"
        const val LOGIC_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseMacroReplayLogic.kt"

        // 切片锚：函数签名文本（剥注释后仍然逐字存在）。
        const val RUN_STEPS = "private suspend fun runSteps("
        const val EXECUTE_STEP = "private suspend fun executeStep("
        const val DROP_AUTH_PREFIX = "fun shouldDropAuthPrefixOnReplay("
        const val SKIP_AUTH_FILL = "fun shouldSkipWarehouseAuthFillStep("
        const val ELEMENT_FOUND = "fun warehouseMacroElementFound("
    }
}
