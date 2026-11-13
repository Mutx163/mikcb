package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日志链路的**源码守卫**（读源码文本，纯 JVM）。
 *
 * ## 防的是哪一类回归
 *
 * 判据函数写好了、单测也绿，但：
 * - 回放每一步没被记（只记了「开始」没记「结果」）⇒ 用户拿到的日志说不出卡在第几步；
 * - 失败点没落 `FAILURE` ⇒ 用户看到「导入失败」四个字，没有那条 `code|k=v`；
 * - 闸门没落 `GATE` ⇒ 「点了没反应」分不清是闸门拒的还是脚本没回；
 * - 导出/写盘链路绕开脱敏，直接把 `entry.fields` 拼进文本 ⇒ 口令上盘；
 * - **轮询协程吞掉取消** ⇒ 用户退出页面后它还在跑，下一轮导入撞上游离的超时定时器
 *   （「修崩溃时顺手引入泄漏」的经典形态，见 `armImportTimeout`）。
 *
 * 这几种都不会让行为级用例红——它们只在源码形状上看得出来，所以单独钉。
 *
 * ## 写法纪律
 *
 * - 不自写剥注释正则，一律走 [readKotlinSourceNoStrings]（剥注释 + 字符串内容中性化）：
 *   这些判据要的是**代码结构**，被 KDoc 或字符串满足就是假绿。
 * - 否定式断言走 [assertSourceLacks]：空读先红，不会「没找到所以通过」。
 * - 切片一律点名两端锚，锚找不到就地红。
 */
class WarehouseImportLogWiringGuardTest {

    private val replayerSource: String by lazy { readKotlinSourceNoStrings(REPLAYER_PATH) }
    private val adapterSource: String by lazy { readKotlinSourceNoStrings(ADAPTER_SCRIPT_PATH) }
    private val exportSource: String by lazy { readKotlinSourceNoStrings(EXPORT_PATH) }
    private val writerSource: String by lazy { readKotlinSourceNoStrings(FILE_WRITER_PATH) }
    private val hostSource: String by lazy { readKotlinSourceNoStrings(WEB_LOGIN_HOST_PATH) }

    /** ① 回放引擎：每一步都要落一条 `MACRO_STEP`（成功 / 跳过 / 失败三条路径都算）。 */
    @Test
    fun `runSteps 的三种结局都要落 MACRO_STEP`() {
        val body = sliceBetween(replayerSource, RUN_STEPS, EXECUTE_STEP)
        assertSourceContains(body, "logMacroStep(", "runSteps")
        val callCount = body.split("logMacroStep(").size - 1
        assertTrue(
            "runSteps 里只有 $callCount 处 logMacroStep( —— 成功/跳过/失败三种结局" +
                "（跳过还有两条）都要留痕，漏一条用户就说不清「少做的那步是哪步」",
            callCount >= 4,
        )
        val helper = sliceBetween(replayerSource, LOG_MACRO_STEP, COMPANION)
        assertSourceContains(helper, "importLog.record(WarehouseLogCategory.MACRO_STEP", "logMacroStep")
        // 字段五样：步号 / 类型 / selector / 状态 / 耗时；跳过与失败各有附加项。
        assertSourceContains(helper, "durationMs", "logMacroStep")
        assertSourceContains(helper, "skipReason", "logMacroStep")
    }

    /** ② 失败点：宏步失败那条 `code|k=v` 原文必须进 buffer（`FAILURE`）。 */
    @Test
    fun `宏步失败要落一条 FAILURE`() {
        val body = sliceBetween(replayerSource, RUN_STEPS, EXECUTE_STEP)
        assertSourceContains(body, "importLog.record(WarehouseLogCategory.FAILURE", "runSteps")
        assertSourceContains(body, "encodeMacroServiceMessage(", "runSteps")
    }

    /** ③ 闸门点：`planWarehouseScriptExecution` 的判定必须落 `GATE`（Ready 或拒绝原因）。 */
    @Test
    fun `闸门判定要落一条 GATE`() {
        val body = sliceBetween(adapterSource, PLAN_EXECUTION, VERIFY_SHA)
        assertSourceContains(body, "log.record(", "planWarehouseScriptExecution")
        assertSourceContains(body, "WarehouseLogCategory.GATE", "planWarehouseScriptExecution")
        // Ready 与 Blocked 两支都要有裁决字样，否则只有一半判定被记下来。
        assertSourceContains(body, "WarehouseScriptExecutionPlan.Ready", "planWarehouseScriptExecution")
        assertSourceContains(body, "WarehouseScriptExecutionPlan.Blocked", "planWarehouseScriptExecution")
    }

    /** ④ 导出/写盘链路不许直写未脱敏字段；落盘失败必须留 `INTERNAL`。 */
    @Test
    fun `导出链路不直写未脱敏字段`() {
        assertSourceContains(
            exportSource,
            "val redacted = WarehouseLogRedaction.redact(entry.fields)",
            "WarehouseImportLogExport",
        )
        // 「把 fields 原样拼进文本」的调用形态：直接遍历 entry.fields 写盘。
        assertSourceLacks(exportSource, "in entry.fields", "WarehouseImportLogExport")
        assertSourceContains(
            writerSource,
            "WarehouseLogCategory.INTERNAL",
            "WarehouseImportLogFileWriter",
        )
        // 写盘是覆盖写（`writeText` 覆盖语义，天然自限），不许追加。
        assertSourceLacks(writerSource, "appendText(", "WarehouseImportLogFileWriter")
        // 宿主收尾真的把这份日志写出去（否则前面全白搭）。
        assertSourceContains(hostSource, "writeWarehouseImportLogFile(", "WarehouseWebLoginHost")
    }

    /**
     * ⑤ 执行预算的轮询协程**不许吞掉取消**：`catch` 体第一步就是重抛
     * `CancellationException`，且排在日志与失败出口**之前**（按剥注释后的相对位置判，
     * 不依赖行号）。
     */
    @Test
    fun `armImportTimeout 的 catch 第一步重抛取消 且排在日志之前`() {
        val launch = sliceBetween(hostSource, ARM_TIMEOUT, EXECUTE_IMPORT_SCRIPT)
        assertSourceContains(launch, "try {", "armImportTimeout")
        assertSourceContains(launch, "catch (t: Throwable)", "armImportTimeout")
        assertSourceContains(launch, RETHROW_CANCELLATION, "armImportTimeout")

        val catchRegion = launch.substring(launch.indexOf("catch (t: Throwable)"))
        assertTrue("取不到 catch 体（守卫自身失效）", catchRegion.isNotBlank())
        val rethrowAt = catchRegion.indexOf(RETHROW_CANCELLATION)
        val logAt = catchRegion.indexOf("Log.e(")
        val exitAt = catchRegion.indexOf("endScriptWindow(")
        assertTrue("catch 体里没有 Log.e( —— 不变量被踩时连痕迹都不留", logAt > 0)
        assertTrue("catch 体里没有 endScriptWindow( —— 用户等不到失败出口", exitAt > 0)
        assertTrue(
            "CancellationException 的重抛排在 Log.e( 之后 ⇒ 取消会被当成故障处理，" +
                "轮询协程变得无法取消（用户退出后还在跑，下一轮导入撞上游离的超时定时器）",
            rethrowAt < logAt,
        )
        assertTrue(
            "CancellationException 的重抛排在 endScriptWindow( 之后 ⇒ 取消会顺手走失败出口，" +
                "用户取消/退出页面时凭空多一条「导入失败」",
            rethrowAt < exitAt,
        )
        assertSourceContains(catchRegion, "WarehouseLogCategory.INTERNAL", "armImportTimeout")
    }

    // ---------------------------------------------------------------------
    // 工具
    // ---------------------------------------------------------------------

    private fun sliceBetween(source: String, signature: String, nextSignature: String): String {
        val start = source.indexOf(signature)
        assertTrue("源码里找不到锚点 <$signature>（守卫锚点失效，别让它静默通过）", start >= 0)
        val end = source.indexOf(nextSignature, start + signature.length)
        assertTrue("找不到 <$signature> 之后的锚点 <$nextSignature>（切片解析可能失效）", end > start)
        return source.substring(start, end)
    }

    private companion object {
        const val REPLAYER_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseMacroReplayer.kt"
        const val ADAPTER_SCRIPT_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterScript.kt"
        const val EXPORT_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseImportLogExport.kt"
        const val FILE_WRITER_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseImportLogFileWriter.kt"
        const val WEB_LOGIN_HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt"

        const val RUN_STEPS = "private suspend fun runSteps("
        const val EXECUTE_STEP = "private suspend fun executeStep("
        const val LOG_MACRO_STEP = "private fun logMacroStep("
        const val COMPANION = "companion object {"
        const val PLAN_EXECUTION = "fun planWarehouseScriptExecution("
        const val VERIFY_SHA = "fun verifyWarehouseScriptSha256("
        const val ARM_TIMEOUT = "fun armImportTimeout("
        const val EXECUTE_IMPORT_SCRIPT = "fun executeImportScript("
        const val RETHROW_CANCELLATION = "if (t is CancellationException) throw t"
    }
}
