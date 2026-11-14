package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.SourceSlice
import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入日志 run 生命周期的**接线守卫**（2026-11-14，Chief 指定的发布阻断项）。
 *
 * 钉的是四处**生产调用点**，不是「函数存在」：
 * 1. 执行入口 `executeImportScript` 必须开轮（把 school / adapter 填进表头）；
 * 2. `complete` 的 FINALIZE 分支必须在「没有课程写回」时才收尾（N10：complete 可能迟到）；
 * 3. `error` 分支必须落 `FAILURE` 并失败收尾；
 * 4. 写库结果回调（成功 / 失败 / 抛异常）必须定局。
 *
 * 反方向也钉：宿主**不许**直接调 `beginRun` / `markEnd` / `markFailure`，状态只能经
 * `WarehouseImportLogLifecycle` 改——否则「只在一处收尾」的语义立刻散掉。
 *
 * 读法：`readKotlinSourceNormalized`（剥注释、保留字符串）。判据要的是真实代码行：
 * 注释掉的接线不算接线；而这里需要的锚点含 `"error" ->` 这类带字符串的分支，所以不能
 * 用中性化档。
 */
class WarehouseImportLogLifecycleGuardTest {

    private val host: String by lazy { readKotlinSourceNormalized(WEB_LOGIN_HOST_PATH) }
    private val lifecycle: String by lazy { readKotlinSourceNormalized(LIFECYCLE_PATH) }

    /** ① 执行入口：先开轮，闸门 / 桥 / console 的记录才有表头。 */
    @Test
    fun `执行入口必须开轮 且表头字段来自 beginAttempt`() {
        val body = SourceSlice.functionBody(host, "fun executeImportScript()")
        assertSourceContains(
            body,
            "WarehouseImportLogLifecycle.beginAttempt(",
            "executeImportScript",
        )
        // 开轮必须排在闸门判定之前：否则 GATE 那条会落进 auto- 轮（表头空）。
        val beginAt = body.indexOf("WarehouseImportLogLifecycle.beginAttempt(")
        val planAt = body.indexOf("planWarehouseScriptExecution(")
        assertTrue("beginAttempt 必须排在 planWarehouseScriptExecution 之前", beginAt in 0 until planAt)
    }

    /** ② complete 的 FINALIZE：课程写回没结束时不许收尾（迟到 complete 不能改写结论）。 */
    @Test
    fun `FINALIZE 分支只在没有课程写回时收尾`() {
        val block = SourceSlice.between(
            host,
            "WarehouseImportCompletionAction.FINALIZE -> {",
            "WarehouseImportCompletionAction.SHOW_STATUS_ONLY -> {",
        )
        assertSourceContains(
            block,
            "coursesSession == null && !importWriting",
            "complete FINALIZE",
        )
        assertSourceContains(block, "WarehouseImportLogLifecycle.endIfOpen(", "complete FINALIZE")
        assertSourceLacks(block, "WarehouseImportLog.markEnd(", "complete FINALIZE")
        // 收尾（endIfOpen）必须排在 endScriptWindow 之前：后者会立刻把日志落盘。
        val endAt = block.indexOf("WarehouseImportLogLifecycle.endIfOpen(")
        val writeAt = block.indexOf("endScriptWindow()")
        assertTrue("endIfOpen 必须排在 endScriptWindow 之前", endAt in 0 until writeAt)
    }

    /** ③ error 分支：脚本自报错必须落 FAILURE + 失败收尾。 */
    @Test
    fun `error 分支必须落 FAILURE 并失败收尾`() {
        val block = SourceSlice.between(host, "\"error\" -> {", "\"loginState\" ->")
        assertSourceContains(block, "WarehouseImportLogLifecycle.recordFailure(", "bridge error")
        assertSourceContains(block, "WarehouseImportLogLifecycle.failIfOpen(", "bridge error")
    }

    /** ④ 写库结果：成功 / 失败两条出口都必须定局（抛异常那条按 Chief 决定拆到后一笔）。 */
    @Test
    fun `写库结果回调两条出口都定局`() {
        val body = SourceSlice.functionBody(host, "fun finalizeCoursesImport(")
        assertSourceContains(body, "WarehouseImportLogLifecycle.endIfOpen(\"complete\")", "finalize Done")
        assertSourceContains(body, "WarehouseImportLogLifecycle.failIfOpen(\"import-apply-failed\")", "finalize Failed")
        // 两条出口都要把终稿落盘（否则 last.txt / 应用日志还写着 running）。
        assertTrue(
            "写库成功 / 失败后没有 persistImportLog()：文件里的 verdict 会停在 running",
            body.split("persistImportLog()").size - 1 >= 2,
        )
    }

    /** 反方向：日志状态只能经 lifecycle 改，宿主不许绕过它。 */
    @Test
    fun `宿主不许直接调用 buffer 的收尾函数`() {
        assertSourceLacks(host, "WarehouseImportLog.beginRun(", "WarehouseWebLoginHost")
        assertSourceLacks(host, "WarehouseImportLog.markEnd(", "WarehouseWebLoginHost")
        assertSourceLacks(host, "WarehouseImportLog.markFailure(", "WarehouseWebLoginHost")
        assertSourceContains(host, "WarehouseImportLogLifecycle.beginSession(", "会话边界")
    }

    /** lifecycle 自己是四个函数的唯一生产调用点（门禁官提议的守卫也靠这条兜底）。 */
    @Test
    fun `lifecycle 必须调用 buffer 的四个函数`() {
        assertSourceContains(lifecycle, "WarehouseImportLog.reset()", "beginSession")
        assertSourceContains(lifecycle, "WarehouseImportLog.beginRun(", "beginAttempt")
        assertSourceContains(lifecycle, "WarehouseImportLog.markEnd(", "endIfOpen")
        assertSourceContains(lifecycle, "WarehouseImportLog.markFailure(", "failIfOpen")
    }

    private companion object {
        const val WEB_LOGIN_HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt"
        const val LIFECYCLE_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseImportLogLifecycle.kt"
    }
}
