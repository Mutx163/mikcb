package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 用户报的「后台每分钟唤醒整机」的**源码结构守卫**（2026-11-06 第四轮返工版）。
 *
 * ## 职责分工（为什么这里只钉结构）
 *
 * - **判定行为**由纯逻辑测试断言：`PromotedFormPolicyTest`（小米/开关/渠道三档）、
 *   `LiveUpdateChromePolicyTest`（上岛 ⇒ 藏 when）、`WidgetRefreshGateTest`、
 *   `NotificationDedupeTest`。
 * - 这里只钉「结构上真的接上了」，防止有人把整段逻辑删掉/绕开。
 *
 * ## 残余风险（如实写，别假装这里覆盖了一切）
 *
 * 本仓**没有 Robolectric / work-testing**，`LiveUpdateService` / `WidgetRefreshWorker` 等
 * Android 类的**真实接线行为无法在 JVM 里跑**。本守卫只能证明「代码结构里调了该调的函数」，
 * 证明不了「运行时真的按这个顺序执行」。谁执意绕过这些结构断言（例如把逻辑搬进另一个
 * 未被扫描的私有函数、或换成反射调用），本守卫抓不到 —— 那种情况靠 **L2 单测 + 复核**
 * 兜底。别把本文件当成行为层证据。
 *
 * 判据一律按**函数体**截取，且截取时**跳过注释与字符串字面量**（注释里的括号/调用示例
 * 会干扰大括号配平与 `contains` 断言）。
 *
 * ## 已知边界（别高估这些断言的强度）
 *
 * - **字面量断言可能假阳性**：`contains("setUsesChronometer(true)")` 之类只证明字面量在/不在，
 *   换成等价写法（`!true`、变量间接）就绕过了；真正的行为靠 `PromotedFormPolicyTest` /
 *   `LiveUpdateChromePolicyTest`。
 * - **`ensuredCount` 只数出现次数**：≥2 只说明代码里写了两处 `ensureScheduled(`，不保证两处
 *   都落在正确的控制流分支上。
 * - **三引号字符串未特殊处理**：`functionBody` 只跳过普通 `"..."` 与 `'...'`，Kotlin 的
 *   `"""..."""` 原始字符串里的 `{` / `if` 仍可能干扰截取（当前这些函数里没有原始字符串）。
 * - **A 判据的多入口（已知边界，不改）**：`computedPromotedFormActive` 另有 3 条一次性通知
 *   入口（`refreshNotificationForIslandFloat` / `onStartCommand` 首次 / `refreshQuickActionNotification`）
 *   与 debug 诊断面板会各自独立求值；它们是一次性触发、不构成**持续**冻岛，本轮明确不改。
 * - **BroadcastDedupe 的 200ms 是经验值**：同批组件通常几十毫秒内到齐，200ms 足够合并；
 *   某 ROM 若拆成 >200ms 的多次派发会各算一次（最多 2 次，不是 10 次）。加卡/首次启用走 `force` 兜底。
 * - **已接受的代价（双口径，别打架）**：
 *   - **按批次口径（10 Provider 各收一遍）**：合并前约 **130 次**、合并后约 **100 次**
 *     `getAppWidgetIds` 每广播（合并后每个 Provider 仍各自 `collectWidgetIds` 一次 × 10）。
 *   - **按单 onReceive 口径**：合并后约 **10 次**（一次 `collectWidgetIds` 查 10 类）。
 *   合并前每 Provider 内部又各自遍历 10 类（`allWidgetIds` ×10 + `classAllIds` 10 +
 *   `widgetInstanceCounts` 10 + `ensureScheduled` 10）。`onEnabled` 与 `onReceive` 可能双重重排
 *   （KEEP 策略下无害）；守卫只能防「已知的两种绕法」（删掉调用、搬进未扫描的私有函数），
 *   其它写法靠 L2 + 复核。
 * - **广播链外的遍历（记录，不改）**：`WidgetRefreshHost.kt:156` 与两个单类查询（直接
 *   `getAppWidgetIds`）不在本次广播链上，属一次性/订阅路径，本轮不合并（收益极小、风险更大）。
 */
class WidgetWakeupSourceGuardTest {

    @Test
    fun `一次广播只重排一次_渲染兜底在onReceive回落分支`() {
        val recv = functionBody(widgetProviderSource(), "override fun onReceive(")
        assertNotNull("必须有 onReceive", recv)
        assertTrue("onReceive 必须用 BroadcastDedupe 去重", recv!!.contains("broadcastDedupe.shouldHandle"))
        assertTrue(
            "onReceive 必须一次 collectWidgetIds 取快照（合并遍历），不许每处各查 10 类",
            recv.contains("collectWidgetIds("),
        )
        assertTrue(
            "重排必须消费同一份快照：rescheduleRefresh(context, widgetIds)",
            recv.contains("rescheduleRefresh(context, widgetIds)"),
        )
        assertTrue(
            "并集必须消费同一份快照：allWidgetIds(widgetIds)",
            recv.contains("allWidgetIds(widgetIds)"),
        )
        assertFalse(
            "onReceive 不得自己 getAppWidgetIds（查询只许发生在 collectWidgetIds 内，否则就是绕过合并）",
            recv.contains("getAppWidgetIds("),
        )
        assertTrue(
            "加卡判据必须是「集合内容」：onReceive 要传 allWidgetIds（出现新 id 即强制重排）",
            recv.contains("allWidgetIds"),
        )
        assertTrue("去重后仍要重排一次", recv.contains("HomeWidgetStorage.rescheduleRefresh("))
        // 渲染兜底必须落在 onReceive 的「空/部分 ids」回落分支里（不是无条件）。
        val updateAllIdx = recv.indexOf("updateAll(context)")
        assertTrue(
            "空/部分 ids 广播必须有渲染兜底（updateAll）—— 空 ids 进不到 onUpdate，没有兜底卡片会空白",
            updateAllIdx >= 0,
        )
        val windowStart = maxOf(0, updateAllIdx - 220)
        assertTrue(
            "updateAll 必须落在 if (intentIds 判空/部分) 的回落分支内，不许无条件调用",
            recv.substring(windowStart, updateAllIdx).contains("if ("),
        )
        val upd = functionBody(widgetProviderSource(), "override fun onUpdate(")
        assertNotNull("必须有 onUpdate", upd)
        assertFalse(
            "onUpdate 不得直接 rescheduleRefresh（10 个 Provider 各调一次 = 10 倍放大）",
            upd!!.contains("HomeWidgetStorage.rescheduleRefresh("),
        )
        assertTrue("onUpdate 仍要渲染", upd.contains("renderWidget("))
        assertFalse(
            "onUpdate 不得再放 updateAll（空 ids 根本进不到 onUpdate，放这里就是死代码）",
            upd.contains("updateAll(context)"),
        )
        val enabled = functionBody(widgetProviderSource(), "override fun onEnabled(")
        assertNotNull("必须有 onEnabled（首次加卡必达重排）", enabled)
        assertTrue("onEnabled 必须重排", enabled!!.contains("HomeWidgetStorage.rescheduleRefresh("))
    }


    @Test
    fun `onDisabled 函数体同时停闹钟和WorkManager`() {
        val body = functionBody(widgetProviderSource(), "override fun onDisabled(")
        assertNotNull("BaseQingyuWidgetProvider 必须有 onDisabled 覆写", body)
        assertTrue(
            "onDisabled 必须用 WidgetRefreshGate.shouldSchedule 判「全部无实例」",
            body!!.contains("WidgetRefreshGate.shouldSchedule"),
        )
        assertTrue("onDisabled 必须取消精确闹钟", body.contains("cancelRefreshAlarm("))
        assertTrue("onDisabled 必须同时取消 WorkManager 兜底", body.contains("WidgetRefreshWorker.cancel("))
    }

    @Test
    fun `onDeleted 删除后必须重算刷新点`() {
        val body = functionBody(widgetProviderSource(), "override fun onDeleted(")
        assertNotNull("BaseQingyuWidgetProvider 必须有 onDeleted 覆写", body)
        assertTrue(
            "删 A 卡留 B 卡时刷新点必须重算，否则 A 的时间点还在调度",
            body!!.contains("HomeWidgetStorage.rescheduleRefresh("),
        )
    }

    @Test
    fun `rescheduleRefresh 先判后撤且每个出口都有正向收尾`() {
        val body = functionBody(widgetStorageSource(), "internal fun rescheduleRefresh(")
        assertNotNull("HomeWidgetStorage.rescheduleRefresh 必须存在", body)
        val gateIdx = body!!.indexOf("WidgetRefreshGate.shouldSchedule")
        val cancelIdx = body.indexOf("cancelRefreshAlarm(")
        assertTrue("零实例门判据必须在函数体内", gateIdx >= 0)
        assertTrue(
            "**先判后撤**：实例数判定必须发生在 cancelRefreshAlarm 之前，" +
                "否则第一张卡刚加、ids 未刷新的窗口会把闹钟误杀且无补偿",
            cancelIdx >= 0 && gateIdx < cancelIdx,
        )
        assertTrue("零实例才取消 WorkManager", body.contains("WidgetRefreshWorker.cancel("))
        // 正向收尾必须覆盖**两个出口**：正常排完闹钟后 + 「算不出刷新点」的 ?: 分支。
        val ensuredCount = body.split("WidgetRefreshWorker.ensureScheduled(").size - 1
        assertTrue(
            "非零实例的每个出口都必须 ensureScheduled（正常收尾 + ?: 无刷新点分支），当前 $ensuredCount 处",
            ensuredCount >= 2,
        )
        assertFalse(
            "?: 早退分支也必须消费快照：不许出现无参 ensureScheduled(context)（会二次 collect）",
            body.contains("WidgetRefreshWorker.ensureScheduled(context)"),
        )
    }

    @Test
    fun `doWork 零实例先取消自己再退出`() {
        val body = functionBody(workerSource(), "override suspend fun doWork(")
        assertNotNull("WidgetRefreshWorker.doWork 必须存在", body)
        assertTrue("doWork 必须过零实例门", body!!.contains("WidgetRefreshGate.shouldSchedule"))
        assertTrue(
            "doWork 零实例时必须 cancel(context) 再 return —— periodic work 不会因为 return 就消失",
            body.contains("cancel("),
        )
    }

    @Test
    fun `ensureScheduled 零实例不排任务`() {
        val body = functionBody(workerSource(), "internal fun ensureScheduled(")
        assertNotNull("WidgetRefreshWorker.ensureScheduled 必须存在", body)
        assertTrue("ensureScheduled 必须过零实例门", body!!.contains("WidgetRefreshGate.shouldSchedule"))
        assertTrue("零实例时应 cancel 而不是 enqueue", body.contains("cancel("))
    }

    @Test
    fun `Worker 用 KEEP 不重置周期`() {
        val body = functionBody(workerSource(), "internal fun ensureScheduled(")
        assertNotNull("WidgetRefreshWorker.ensureScheduled 必须存在", body)
        assertTrue(
            "必须用 ExistingPeriodicWorkPolicy.KEEP：UPDATE 会把 15 分钟周期重置成「最后一次调用后 15 分钟」",
            body!!.contains("ExistingPeriodicWorkPolicy.KEEP"),
        )
    }

    @Test
    fun `syncSnapshot 不再单独 ensureScheduled`() {
        val body = functionBody(widgetStorageSource(), "fun syncSnapshot(")
        assertNotNull("HomeWidgetStorage.syncSnapshot 必须存在", body)
        assertFalse(
            "syncSnapshot 不应再自己 ensureScheduled（两处各自判零会不一致）；交给 rescheduleRefresh 统一收口",
            body!!.contains("WidgetRefreshWorker.ensureScheduled("),
        )
        assertTrue("syncSnapshot 仍要触发调度", body.contains("rescheduleRefresh("))
    }

    @Test
    fun `buildNotification 走 chrome 策略且标准通知不走字`() {
        val body = functionBody(liveUpdateSource(), "private fun buildNotification(")
        assertNotNull("buildNotification 必须存在", body)
        assertTrue(
            "buildNotification 必须通过 LiveUpdateChromePolicy.chromeFor 决定 when",
            body!!.contains("LiveUpdateChromePolicy.chromeFor("),
        )
        assertTrue(
            "必须消费单一求值源 stageChrome.promotedFormActive（不许在构建里再算一遍）",
            body.contains("stageChrome.promotedFormActive"),
        )
        assertFalse(
            "buildNotification 里不得再 computedPromotedFormActive 重算（否则 ticker 与构建两处各判，" +
                "状态翻转窄窗口里可能岛形态+60秒心跳同时成立）",
            body.contains("computedPromotedFormActive("),
        )
        assertFalse(
            "标准通知**不许**再启用 chronometer 走字（方案已撤：悬空句 + 架空 showCountdown）",
            body.contains("setUsesChronometer(true)"),
        )
        assertTrue(
            "必须显式写 setUsesChronometer(false)，防止上游误开走字",
            body.contains("setUsesChronometer(false)"),
        )
    }

    // ── 辅助 ────────────────────────────────────────────────────────────

    /**
     * 从 `signature` 起，按大括号配对截出函数体；**跳过注释与字符串字面量**，
     * 返回的是「去注释/去字符串后的代码」—— `contains` 断言因此不会被注释里的示例骗过。
     */
    private fun functionBody(source: String, signature: String): String? {
        val idx = source.indexOf(signature)
        if (idx < 0) return null
        var i = idx
        var braceStart = -1
        var lineComment = false
        var blockComment = false
        var quote: Char? = null
        while (i < source.length) {
            val c = source[i]
            val n = if (i + 1 < source.length) source[i + 1] else '\u0000'
            if (lineComment) {
                if (c == '\n') lineComment = false
                i++
                continue
            }
            if (blockComment) {
                if (c == '*' && n == '/') {
                    blockComment = false
                    i += 2
                } else {
                    i++
                }
                continue
            }
            if (quote != null) {
                if (c == '\\') {
                    i += 2
                    continue
                }
                if (c == quote) quote = null
                i++
                continue
            }
            when {
                c == '/' && n == '/' -> {
                    lineComment = true
                    i += 2
                }
                c == '/' && n == '*' -> {
                    blockComment = true
                    i += 2
                }
                c == '"' -> {
                    quote = '"'
                    i++
                }
                c == '\'' -> {
                    quote = '\''
                    i++
                }
                c == '{' -> {
                    braceStart = i
                    i = source.length // 跳出
                }
                else -> i++
            }
        }
        if (braceStart < 0) return null

        val out = StringBuilder()
        var depth = 0
        i = braceStart
        lineComment = false
        blockComment = false
        quote = null
        while (i < source.length) {
            val c = source[i]
            val n = if (i + 1 < source.length) source[i + 1] else '\u0000'
            if (lineComment) {
                if (c == '\n') {
                    lineComment = false
                    out.append('\n')
                }
                i++
                continue
            }
            if (blockComment) {
                if (c == '*' && n == '/') {
                    blockComment = false
                    i += 2
                } else {
                    i++
                }
                continue
            }
            if (quote != null) {
                if (c == '\\') {
                    i += 2
                    continue
                }
                if (c == quote) quote = null
                i++
                continue
            }
            when {
                c == '/' && n == '/' -> {
                    lineComment = true
                    i += 2
                }
                c == '/' && n == '*' -> {
                    blockComment = true
                    i += 2
                }
                c == '"' -> {
                    quote = '"'
                    out.append("__STR__")
                    i++
                }
                c == '\'' -> {
                    quote = '\''
                    out.append("__CHR__")
                    i++
                }
                c == '{' -> {
                    depth++
                    out.append(c)
                    i++
                }
                c == '}' -> {
                    depth--
                    out.append(c)
                    i++
                    if (depth == 0) return out.toString()
                }
                else -> {
                    out.append(c)
                    i++
                }
            }
        }
        return null
    }

    private fun root(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError("找不到 android/app/src，守卫无法验证")
    }

    private fun source(relative: String): String {
        val f = File(root(), "main/kotlin/com/mutx163/qingyu/$relative")
        if (!f.isFile) throw AssertionError("找不到源文件：$relative")
        return f.readText()
    }

    private fun widgetProviderSource(): String = source("BaseQingyuWidgetProvider.kt")
    private fun widgetStorageSource(): String = source("HomeWidgetStorage.kt")
    private fun workerSource(): String = source("WidgetRefreshWorker.kt")
    private fun liveUpdateSource(): String = source("LiveUpdateService.kt")
}
