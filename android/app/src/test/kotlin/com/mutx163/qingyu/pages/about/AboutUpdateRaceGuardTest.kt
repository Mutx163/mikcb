package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 版本更新竞速 / 清单体积 / 转圈复位 的源码棘轮（2026-11-11 R-1/R-3/R-5 建立，
 * 2026-11-14 随 OkHttp 统一入口重写）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户实报「检查更新一直转」。根因不是网络慢，而是**假竞速**：三路清单塞在调用方的
 * `coroutineScope` 里 —— 它必须等**全部**子协程结束才返回，而 `cancel()` 打不断阻塞的
 * socket 读，未胜出的两路要等满 `readTimeout`（6s）。发布版 `raceFutures`
 * （`async_utils.dart:42-66`）的语义是「首个成功立即返回、**不 join 落败者**」。
 *
 * ## 2026-11-14 结构变更（本文件随之重写）
 *
 * 竞速内核 `UpdateManifestRace.kt`（手写线程池 + `CompletableFuture`）**已删除**，语义搬进
 * `platform/QingyuHttp.firstSuccess(specs, lingerMs)`：赢家出现立即返回，`lingerMs=0` 时
 * 当场取消其余；`lingerMs>0` 时留一个窗口等兄弟路把结果收进 `successes`（按到达顺序），
 * 到点再取消。**所以本文件不再守内核**——旧内核那两条断言（`newFixedThreadPool` /
 * `shutdownNow` / `winner.complete(null)`）是「守着一份已删除的代码」，随内核一起删，
 * 不是把判据削弱。现在改成守两件事：宿主**怎么用**地基（显式传窗口、不许回退手搓并发），
 * 以及地基**自己**必须做到「赢家出现后取消败者」。
 *
 * 另两处同批收紧：
 * - `runCheck` 必须 try/finally 把 `checking` 复位，且复位点必须在 **`finally` 块内**；
 * - 清单响应的 2MB 上限不再由宿主手写流式计数 + `Content-Length` 预检，而是
 *   `HttpCallSpec.maxBytes` 交给地基做**有界读**（超限那一路落 `failure=too_large`）。
 *
 * ## 判据口径
 *
 * 接线类用 [readKotlinSourceNoStrings]（剥注释 + 中性化字符串），常量/字面量类用
 * [readKotlinSourceNormalized]（剥注释、保留字面量）；否定式断言一律走
 * [assertSourceLacks]（内部先判非空，读空不会恒真）。
 *
 * ## 咬合探针（改本文件或改这几处接线时必须做）
 *
 * 1. 把宿主 `firstSuccess` 的 `lingerMs = DIGEST_BACKFILL_WINDOW_MS` 删掉 ⇒ 用例 1 红；
 * 2. 地基 `firstSuccess` 去掉「取消败者」那句 ⇒ 用例 5 红；
 * 3. 宿主删掉 `maxBytes = MANIFEST_MAX_BYTES` ⇒ 用例 4 红；
 * 4. 把 `runCheck` 的 `checking = false` 从 `finally` 移出去 ⇒ 用例 3 红。
 */
class AboutUpdateRaceGuardTest {

    private fun hostPath() =
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdateHost.kt"

    private fun httpPath() =
        "android/app/src/main/kotlin/com/mutx163/qingyu/platform/QingyuHttp.kt"

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

    private fun digestBody(code: String): String =
        functionBody(code, "private fun mergeDigestFromSiblings(", "")

    private fun manifestSpecBody(code: String): String =
        functionBody(code, "private fun AppUpdateManifestCandidate.toManifestSpec(", "")

    /**
     * 取出文本里**所有** `finally { … }` 块的正文（按花括号配平；入参已剥过字符串字面量）。
     *
     * 为什么要单独切块：`runCheck` 头部有 `packageInfo ?: run { checking = false; return }`，
     * 那句也含 `checking = false`。只判「函数体里出现过」的话，把复位从 `finally` 挪回
     * 普通分支仍然会绿（评审四 R-3），所以判据必须落在块内。
     */
    private fun finallyBlocks(code: String): List<String> {
        val blocks = arrayListOf<String>()
        var index = code.indexOf("finally {")
        while (index >= 0) {
            val open = code.indexOf('{', index)
            var depth = 0
            var cursor = open
            while (cursor < code.length) {
                when (code[cursor]) {
                    '{' -> depth++
                    '}' -> {
                        depth--
                        if (depth == 0) break
                    }
                }
                cursor++
            }
            assertTrue("finally 块没有闭合（R-3 守卫取不到复位点）", cursor < code.length)
            blocks.add(code.substring(open, cursor + 1))
            index = code.indexOf("finally {", cursor)
        }
        return blocks
    }

    @Test
    fun `竞速必须走统一入口的 firstSuccess 且显式传摘要窗口`() {
        val body = raceBody(readKotlinSourceNoStrings(hostPath()))
        assertTrue(
            "竞速没有走统一入口 QingyuHttp.firstSuccess( ——回退成手搓并发时要重新证明「不 join 落败者」",
            body.contains("QingyuHttp.firstSuccess("),
        )
        assertTrue(
            "调用 firstSuccess 时必须显式传 lingerMs = DIGEST_BACKFILL_WINDOW_MS：" +
                "删掉它回落到默认 0，Release 页 HTML 赢家就再也等不到兄弟路的 SHA 摘要，" +
                "安装闸门退化成「一律引导去 Release 页」",
            body.contains("lingerMs = DIGEST_BACKFILL_WINDOW_MS"),
        )
        assertSourceContains(
            readKotlinSourceNoStrings(hostPath()),
            "private const val DIGEST_BACKFILL_WINDOW_MS: Long = 1600L",
            "AboutUpdateHost（摘要窗口常量，值仍是发布版同档 1600ms）",
        )
        assertSourceLacks(
            body,
            "startRaceFirstSuccess",
            "竞速（旧内核已删，不许回退）",
        )
        assertSourceLacks(body, "shutdownNow", "竞速（旧内核已删，不许回退）")
        assertSourceLacks(body, "coroutineScope", "竞速（会 join 全部子协程）")
        assertSourceLacks(body, "joinAll", "竞速（等落败者就是假竞速）")
        assertFalse(
            "竞速里出现了 join( ——等着落败者结束就是假竞速",
            Regex("""\.join\s*\(""").containsMatchIn(body),
        )
    }

    @Test
    fun `摘要回填由地基窗口承载_宿主不再自己轮询`() {
        val body = digestBody(readKotlinSourceNoStrings(hostPath()))
        assertSourceContains(
            body,
            "successes.values.firstNotNullOfOrNull",
            "mergeDigestFromSiblings（只在窗口内到达的兄弟路里查表）",
        )
        assertSourceLacks(
            body,
            "withTimeoutOrNull",
            "mergeDigestFromSiblings（等待已搬进 firstSuccess 的 lingerMs，宿主不该再有超时轮询）",
        )
        assertSourceLacks(
            body,
            "currentTimeMillis",
            "mergeDigestFromSiblings（墙上时钟算 deadline 的老问题，随轮询一起去掉）",
        )
        assertSourceLacks(
            body,
            "delay(",
            "mergeDigestFromSiblings（120ms 轮询式等待已删除）",
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
        val finallyBlocks = finallyBlocks(body)
        assertTrue(
            "runCheck 里没有 finally 块：无论成功/失败/取消都要把 checking 置回 false（R-3）",
            finallyBlocks.isNotEmpty(),
        )
        assertTrue(
            "runCheck 的 finally **块里**没有 checking = false —— 复位被挪到别处时" +
                "（例如只在 `?: run { checking = false }` 这类早退分支里），" +
                "只要有一条出口漏掉，页面就永久停在「检查中」（评审四 R-3 收紧项）",
            finallyBlocks.any { it.contains("checking = false") },
        )
    }

    @Test
    fun `清单体积上限交给地基有界读`() {
        val body = manifestSpecBody(readKotlinSourceNoStrings(hostPath()))
        assertSourceContains(
            body,
            "maxBytes = MANIFEST_MAX_BYTES",
            "toManifestSpec（体积上限必须逐请求交给地基，否则超大响应会整段进内存）",
        )
        val source = readKotlinSourceNormalized(hostPath())
        assertSourceContains(
            source,
            "private const val MANIFEST_MAX_BYTES: Long = 2L * 1024L * 1024L",
            "AboutUpdateHost（2MB 上限常量）",
        )
        // 反向：宿主不许再自己手写流式计数 / Content-Length 预检（那正是被删掉的旧实现）。
        assertSourceLacks(source, "fetchManifestBody", "AboutUpdateHost（旧的手写抓取已删）")
        assertSourceLacks(source, "HttpURLConnection", "AboutUpdateHost（已改走统一入口）")
        assertSourceLacks(source, "Content-Length", "AboutUpdateHost（预检交给地基）")
        assertSourceLacks(source, "readText()", "AboutUpdateHost（无上限整块读的旧写法）")
    }

    @Test
    fun `地基 firstSuccess 必须在赢家出现后取消败者`() {
        val kernel = readKotlinSourceNoStrings(httpPath())
        assertSourceContains(kernel, "fun firstSuccess(", "QingyuHttp（竞速入口）")
        assertTrue(
            "firstSuccess 里没有「赢家出现后取消其余」的代码：找不到 calls.forEach + call.cancel()，" +
                "落败者会一直跑到底（原来那个「假竞速」的病就是这么回来的）",
            Regex("""calls\.forEach\s*\{[^}]*call\.cancel\(\)""").containsMatchIn(kernel) ||
                Regex("""forEach\s*\{\s*call\s*->[\s\S]{0,160}?call\.cancel\(\)""")
                    .containsMatchIn(kernel),
        )
        assertTrue(
            "取消必须先于「通用 IO 失败」判断，且取消落 failure=cancelled（与 timeout 分开）",
            kernel.contains("FAILURE_CANCELLED"),
        )
        // 反向：地基不许自建线程池 / 不许写死窗口数字（窗口由宿主传）。
        assertSourceLacks(kernel, "newFixedThreadPool", "QingyuHttp（地基不自建线程池）")
        assertSourceLacks(kernel, "Executors", "QingyuHttp（地基不自建线程池）")
        assertSourceLacks(kernel, "1600", "QingyuHttp（窗口宽度只由宿主传，地基不写死）")
    }
}
