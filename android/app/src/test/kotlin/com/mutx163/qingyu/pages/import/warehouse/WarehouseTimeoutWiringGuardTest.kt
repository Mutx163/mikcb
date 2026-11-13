package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.SourceSlice
import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **执行窗口预算的接线守卫**（2026-11-13，暂停即不可能超时模型）。
 *
 * 宿主 `WarehouseWebLoginHost.kt` 在 `composeP1` 源集，**不在 L0 编译范围**——计时器接没接、
 * 弹窗挂起时预算停没停、超时分支还认不认旧写法，都没有编译器能判。这里读源码判结构，
 * 与仓库既有的 `WarehouseWebLoginHostWiringGuardTest` / `WarehouseWebLoginPageWiringGuardTest`
 * 同一套做法。
 *
 * ## 钉的是这四条
 *
 * 1. `shouldFire` 的调用处传了**当下**的挂起弹窗数，超时入口还有一道 `pendingDialogCount == 0`
 *    的显式失败（不变量 ①）；
 * 2. 超时收尾体里**不再**出现 `cancelPendingDialog(...)`（不变量 ②：新模型下不可达，
 *    真到了就是 ① 该抓到的事）；
 * 3. 六条阶段文案 + 超时标题/建议 + 两个真按钮都真的在宿主里被引用（否则等于只落了 ARB）；
 * 4. 「查看日志」**没有被接上**（面板没做，接上去就是死按钮）。
 *
 * 读源码一律走 `readKotlinSourceNormalized`（剥注释、保留字符串内容）：把接线注释掉不算接线，
 * 但判据里有几处是在判「某个文案键被引用」，字符串档位不能抹掉。
 */
class WarehouseTimeoutWiringGuardTest {

    private val hostSource: String by lazy {
        readKotlinSourceNormalized(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt",
        )
    }

    @Test
    fun `判据先自证读到了源码`() {
        // 否定式断言在空串上恒真（testutil 的 assertSourceLacks 也拦，但这里先给一条明确的
        // 「读对了文件」的证据：路径写错时下面几条会一起红，不如在这里先红得清楚）。
        assertSourceContains(hostSource, "fun onScriptExecutionTimeout(", "宿主的超时入口")
        assertSourceContains(hostSource, "fun armImportTimeout(", "宿主的预算启动函数")
    }

    /**
     * 不变量 ①：`shouldFire` 拿的是**当下**的挂起数，超时入口还有一道显式断言。
     *
     * 两处都要在：
     * - 少 `shouldFire` 那一路 → 挂起期间照样到点收尾（老 bug 原样回来）；
     * - 少超时入口那道 `check` → 暂停逻辑失效时没人喊，用户正在读的对话框会被静默收掉。
     */
    @Test
    fun `shouldFire 必须带当下挂起数_超时入口必须断言为零`() {
        val arming = SourceSlice.functionBody(hostSource, "fun armImportTimeout(")
        assertSourceContains(arming, "shouldFire(", label = "armImportTimeout")
        assertSourceContains(
            arming,
            "val pendingDialogCount = if (pendingDialog != null) 1 else 0",
            label = "armImportTimeout（挂起数必须是现读的，不是缓存/常量）",
        )
        assertSourceContains(arming, "pendingDialogCount = pendingDialogCount", label = "armImportTimeout")

        val timeout = SourceSlice.functionBody(hostSource, "fun onScriptExecutionTimeout(")
        assertSourceContains(
            timeout,
            "check(pendingDialogCount == 0)",
            label = "onScriptExecutionTimeout（不变量 ① 的显式失败路径）",
        )
    }

    /**
     * 不变量 ②：超时收尾**不许**再排空挂起弹层。
     *
     * 老代码在这里调 `cancelPendingDialog("timeout")`：那等于替用户把正在看的对话框按「取消」。
     * 新模型下「到点还挂着弹窗」不可达，真到了要当场失败（见上一条），不能顺手把它关掉。
     */
    @Test
    fun `超时收尾体内不许再排空挂起弹层`() {
        val timeout = SourceSlice.functionBody(hostSource, "fun onScriptExecutionTimeout(")
        // 先给正向证据：这一段确实是超时收尾（否则「不出现」可能只是切错了地方）。
        assertSourceContains(timeout, "endScriptWindow(errorMessage = message)", label = "超时收尾体")
        assertSourceLacks(
            timeout,
            "cancelPendingDialog(",
            label = "超时收尾体（不变量 ②）",
        )
    }

    /**
     * 预算与暂停都得接在宿主上：常量 60 秒、策略对象、两个挂起点的 pause / resume。
     *
     * 为什么 resume 要数到两处：`answerAndClose`（用户作答）与 `cancelPendingDialog`
     * （窗口结束排空）各有一个清理点。漏掉后者，脚本窗口结束时刚好挂着弹窗的那一轮
     * 会永远停在暂停态——界面看着像「一直没超时」，其实是预算再也不会走。
     */
    @Test
    fun `预算常量与暂停恢复都接在宿主上`() {
        assertSourceContains(
            hostSource,
            "SCRIPT_EXECUTION_TIMEOUT_MS = 60_000L",
            label = "预算常量（暂停模型下的 60 秒硬上限）",
        )
        assertSourceContains(hostSource, "WarehouseExecutionTimerPolicy()", label = "宿主")
        assertSourceContains(hostSource, "executionTimer.shouldFire(", label = "宿主")

        // 挂起点：创建挂起请求的那一行之后必须紧跟 pause（切出那一小段再判）。
        val creation = SourceSlice.between(hostSource, "pendingDialog = request", "}")
        assertSourceContains(creation, "pauseExecutionBudget()", label = "挂起请求的创建点")

        // 清理点：answerAndClose 与 cancelPendingDialog 各自都要 resume。
        val answered = SourceSlice.functionBody(hostSource, "fun answerAndClose(")
        assertSourceContains(answered, "resumeExecutionBudget()", label = "answerAndClose")
        val cancelled = SourceSlice.functionBody(hostSource, "fun cancelPendingDialog(")
        assertSourceContains(cancelled, "resumeExecutionBudget()", label = "cancelPendingDialog")
    }

    /**
     * 六条阶段文案 + 超时标题/建议 + 两个真按钮：都必须真的在宿主里被引用。
     *
     * 只落 ARB 不接线 = 用户什么都看不到；这六句正是「现在到底在等谁」的答案。
     */
    @Test
    fun `六条阶段文案与超时弹窗的键都在宿主里被引用`() {
        listOf(
            "executeStageWaitingPage",
            "executeStageAwaitConfirm",
            "executeStageAwaitSelection",
            "executeStageAwaitInput",
            "executeStageFetching",
            "executeStageSlowNetwork",
            "executeTimeoutTitle",
            "executeTimeoutAdvice",
            "executeSwitchToManualAction",
            // 重试按钮复用快捷导入的既有键（不为同一件事再起一个新键）。
            "quickImportRetryAction",
        ).forEach { key ->
            assertSourceContains(hostSource, key, label = "宿主引用 ARB 键 $key")
        }
        // 超时标题必须把秒数填进去（`{seconds}` 留在屏上就是模板泄漏）。
        assertSourceContains(hostSource, "filled(\"seconds\"", label = "超时标题占位符")
    }

    /**
     * 「查看日志」只收进文案访问器，**不许**先接在宿主上。
     *
     * 日志面板还没移植（壳侧「更多」菜单当初也是这个理由没接「导入执行日志」）；
     * 接上去就是一颗点了没反应的死按钮，比没有这颗按钮更差。
     */
    @Test
    fun `查看日志不许先接上`() {
        assertSourceLacks(hostSource, "executeViewLogAction", label = "宿主（面板未落地，禁止先接）")
    }
}
