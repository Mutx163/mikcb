package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 版本更新竞速守卫（2026-11-11 R-1/R-3/R-5 修复的源码棘轮）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户实报「检查更新一直转」。根因不是网络慢，而是**假竞速**：三路清单塞在调用方的
 * `coroutineScope` 里 —— 它必须等**全部**子协程结束才返回，而 `cancel()` 打不断阻塞的
 * socket 读，未胜出的两路要等满 `readTimeout`（6s）。国内丢包时 GitCode 200ms 就有结果，
 * 用户仍要干等 4s+。发布版 `raceFutures`（`async_utils.dart:42-66`）的语义是「首个成功
 * 立即返回、**不 join 落败者**」。
 *
 * 修复后的结构：竞速内核在 `main` 层 `UpdateManifestRace.kt`（独立线程池 + `CompletableFuture`，
 * 可 JVM 单测；计时判据在 `UpdateManifestRaceTest`），宿主只负责「用内核 + 回填摘要 + finally 取消」。
 * 同批另两处：
 * - `runCheck` 必须 try/finally 把 `checking` 复位（异常不再让页面永久转圈）；
 * - 清单响应体必须有 2MB 上限且先看 `Content-Length`。
 *
 * ## 判据口径（P6-G1/G2）
 *
 * 一律用 `testutil` 的 [readKotlinSourceNoStrings]（剥注释 + 中性化字符串）/
 * [readKotlinSourceNormalized]（剥注释、保留字面量）——不再自带私有剥离器。
 * 接线类判据用前者（字符串里提到 `joinAll` 不算违规），常量类判据用后者。
 *
 * ## 咬合探针（提交前必须各做一次并还原）
 *
 * 1. 删掉竞速里的 `race.cancel()` ⇒ 「必须 finally 取消」用例红；
 * 2. 从内核删掉全部失败兜底 `winner.complete(null)` ⇒ 「全部失败必须收场」用例红；
 * 3. 删掉 `MAX_MANIFEST_BODY_BYTES` 的体积判断 ⇒ 「体积上限」用例红。
 */
class AboutUpdateRaceGuardTest {

    private fun hostPath() =
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdateHost.kt"

    private fun kernelPath() =
        "android/app/src/main/kotlin/com/mutx163/qingyu/pages/about/UpdateManifestRace.kt"

    /**
     * 取函数体文本：从签名出现处到**下一个该缩进层级的闭花括号行**。
     *
     * 不走括号配平是因为函数体里有字符串与 lambda，宁可走缩进锚点；函数改写后缩进变了，
     * 用例会以「取不到函数体」显式失败，而不是静默放过。
     */
    private fun functionBody(code: String, signature: String, closingIndent: String): String {
        val start = code.indexOf(signature)
        assertTrue("源码里找不到函数签名：$signature", start >= 0)
        val end = code.indexOf("\n$closingIndent}\n", start)
        assertTrue("取不到函数体（签名：$signature）", end > start)
        return code.substring(start, end)
    }

    private fun raceBody(code: String): String =
        functionBody(code, "private suspend fun checkForUpdatesAcrossManifestSources(", "")

    private fun runCheckBody(code: String): String =
        functionBody(code, "fun runCheck() {", "    ")

    /**
     * `fetchManifestBody` 是**表达式体**（`= runCatching { … }.getOrNull()`），没有独占一行的
     * 顶层闭花括号，所以用「下一个空行」当结束锚点（函数体内没有空行）。
     */
    private fun fetchBody(code: String): String {
        val signature = "private fun fetchManifestBody("
        val start = code.indexOf(signature)
        assertTrue("源码里找不到函数签名：$signature", start >= 0)
        val end = code.indexOf("\n\n", start)
        assertTrue("取不到 fetchManifestBody 函数体", end > start)
        return code.substring(start, end)
    }

    @Test
    fun `竞速必须走不等落败者的内核`() {
        val body = raceBody(readKotlinSourceNoStrings(hostPath()))
        assertTrue(
            "竞速没有走竞速内核 startRaceFirstSuccess( ——回退成手搓并发时要重新证明「不 join 落败者」",
            body.contains("startRaceFirstSuccess("),
        )
        assertFalse(
            "竞速里出现了 coroutineScope —— 它会 join 全部子协程，cancel() 又打不断阻塞 socket 读，" +
                "首个成功也要等落败者超时（R-1 用户报「一直转」的根因）",
            body.contains("coroutineScope"),
        )
        assertFalse(
            "竞速里出现了 joinAll / join( ——等着落败者结束就是假竞速",
            body.contains("joinAll") || Regex("""\.join\s*\(""").containsMatchIn(body),
        )
        assertTrue(
            "竞速没有在 finally 里取消落败者：回填结束后必须 race.cancel()，别把后台任务留成孤儿",
            body.contains("finally {") && body.contains("race.cancel()"),
        )
    }

    @Test
    fun `竞速内核必须独立线程池且全部失败能收场`() {
        val kernel = readKotlinSourceNoStrings(kernelPath())
        assertTrue(
            "竞速内核没有独立线程池（Executors.newFixedThreadPool）：落败者的阻塞读会拖住调用方",
            kernel.contains("newFixedThreadPool"),
        )
        assertTrue(
            "竞速内核没有用 CompletableFuture 的「首个 complete 生效」语义",
            kernel.contains("CompletableFuture") && kernel.contains("winner.complete("),
        )
        assertTrue(
            "竞速内核缺少「全部失败也要收场」：三路都失败时没有人 complete，调用方会一直等" +
                "（必须有 remaining 归零后 winner.complete(null) 的兜底）",
            Regex("""decrementAndGet\(\)\s*==\s*0[\s\S]{0,200}?winner\.complete\(null\)""")
                .containsMatchIn(kernel),
        )
        assertFalse(
            "竞速内核里出现了 join —— 内核的本职就是不 join 落败者",
            kernel.contains("joinAll") || Regex("""\.join\s*\(""").containsMatchIn(kernel),
        )
        assertTrue(
            "竞速内核的 cancel 没有 shutdownNow：落败任务会被一直留着",
            kernel.contains("shutdownNow"),
        )
    }

    @Test
    fun `检查更新必须兜住异常并复位转圈态`() {
        val body = runCheckBody(readKotlinSourceNoStrings(hostPath()))
        assertTrue(
            "runCheck 没有 try/catch → 网络层任何未捕获异常都会让 checking 永久停在 true" +
                "（页面「一直转」的另一条路径，R-3）",
            body.contains("catch") || body.contains("runCatching"),
        )
        assertTrue(
            "runCheck 没有 finally 复位：无论成功/失败/取消都要把 checking 置回 false",
            body.contains("finally {") && body.contains("checking = false"),
        )
    }

    @Test
    fun `清单响应体必须有体积上限`() {
        val source = readKotlinSourceNormalized(hostPath())
        val body = fetchBody(source)
        assertTrue(
            "清单响应体没有体积上限：异常大响应会整段读进内存（R-5）",
            body.contains("MAX_MANIFEST_BODY_BYTES"),
        )
        assertTrue(
            "清单读取没有先看 Content-Length（有长度信息时应当先挡）",
            body.contains("Content-Length"),
        )
        assertFalse(
            "清单读取又回到了无上限的 readText()（R-5 回退）",
            body.contains("readText()"),
        )
        val cap = Regex("""MAX_MANIFEST_BODY_BYTES\s*=\s*([0-9L*.\s]+)""").find(source)
        assertTrue("找不到清单体积上限常量：MAX_MANIFEST_BODY_BYTES", cap != null)
        assertTrue(
            "清单体积上限必须是 2MB（2L * 1024L * 1024L）；改动前先确认三类清单正文的真实量级",
            cap!!.groupValues[1].replace(" ", "").contains("2L*1024L*1024L"),
        )
    }
}
