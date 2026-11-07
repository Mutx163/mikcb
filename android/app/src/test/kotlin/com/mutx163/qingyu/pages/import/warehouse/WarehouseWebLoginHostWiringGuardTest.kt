package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **登录页宿主接线守卫**（F28）：读 `WarehouseWebLoginHost.kt` 源码，钉住壳侧缺口的修复事实。
 *
 * 登录页宿主在 `composeP1` 源集，**不在 L0 编译范围**；但「地址是不是真地址」
 * 「脚本是不是真拉回来再注入」这类接线事实可以靠源码结构判（与 `test/architecture/` 同款做法）。
 *
 * 守卫要拦的是回退：
 * - 有人把登录地址换回占位常量（`example.com` / `SHELL_DEMO_*`）；
 * - 有人把「执行导入脚本」改回空回调，或跳过仓库直接注入假脚本；
 * - 有人把「没有任何合法地址」的情况改成加载空白网页（用户只看到白屏）。
 */
class WarehouseWebLoginHostWiringGuardTest {

    private val hostSource: String by lazy { stripKotlinComments(readHostSource()) }
    private val adapterSource: String by lazy { stripKotlinComments(readAdapterSource()) }

    @Test
    fun `判据必须剥掉注释 注释掉的接线不算接线`() {
        // 2026-11-03 咬合探针实测：把 `state.autoRecordMacro = false` 注释掉后旧判据仍命中。
        val fake = "fun fake() {\n    // state.autoRecordMacro = false\n}"
        assertFalse(
            "注释掉的判据不许再命中",
            stripKotlinComments(fake).contains("state.autoRecordMacro = false"),
        )
        assertTrue("字符串字面量里的内容不许被当注释吃掉", stripKotlinComments("val u = \"a//b\"").contains("a//b"))
    }

    @Test
    fun `登录地址必须来自解析函数 不许出现占位地址`() {
        assertTrue(
            "宿主必须用 resolveWarehouseWebLoginTarget(...) 决定加载地址（自定义覆盖 > 仓库 import_url）",
            hostSource.contains("resolveWarehouseWebLoginTarget("),
        )
        listOf("example.com", "SHELL_DEMO_LOGIN_URL", "SHELL_DEMO_SCHOOL").forEach { forbidden ->
            assertFalse(
                "登录宿主不许再出现占位常量/地址：`$forbidden`",
                hostSource.contains(forbidden),
            )
        }
    }

    @Test
    fun `没有可用地址时显示诚实空态 而不是空白网页`() {
        assertTrue(
            "没有合法地址时必须渲染 MissingUrl 空态",
            hostSource.contains("WarehouseWebLoginMissingUrlPage("),
        )
        assertTrue(
            "空态文案取 ARB 的 noValidWarehouseLoginUrl",
            hostSource.contains("noValidWarehouseLoginUrl"),
        )
    }

    @Test
    fun `执行导入必须真拉脚本 并包垫片后注入`() {
        assertTrue(
            "必须调用仓库拉脚本（loadAdapterScript）",
            hostSource.contains("loadAdapterScript("),
        )
        assertTrue(
            "注入前必须包 AndroidBridge 垫片（warehouseImportScriptWrapper）",
            hostSource.contains("warehouseImportScriptWrapper("),
        )
        assertTrue(
            "必须把脚本注入真 WebView 控制器",
            hostSource.contains("controller.injectJavaScript("),
        )
        assertTrue(
            "执行前必须过 planWarehouseScriptExecution 判定（页面没加载完不许注入）",
            hostSource.contains("planWarehouseScriptExecution("),
        )
    }

    @Test
    fun `真 WebView 与状态回写必须接在页面上`() {
        assertTrue("必须渲染 WarehouseWebLoginPage", hostSource.contains("WarehouseWebLoginPage("))
        assertTrue("必须把解析出的会话状态交给页面", hostSource.contains("sessionState = session"))
        assertTrue("必须自己持有控制器才能在载入完成后注入脚本", hostSource.contains("webViewController = controller"))
        listOf("onWebProgress =", "onWebPageStarted =", "onWebPageFinished =", "onWebError =")
            .forEach { marker ->
                assertTrue("缺少宿主回调接线：$marker", hostSource.contains(marker))
            }
    }

    @Test
    fun `桥接消息只记类型 不直接当导入结果`() {
        assertTrue(
            "桥接消息必须走 warehouseBridgeMessageType 记类型（正文含课表数据，不进日志）",
            hostSource.contains("warehouseBridgeMessageType(raw)"),
        )
        assertFalse(
            "宿主不许把原始桥接消息直接写进课表/仓库（当前无导入管线，写进去就是假接线）",
            hostSource.contains("repository.") && hostSource.contains("onWebBridgeMessage"),
        )
    }

    @Test
    fun `savePresetTimeSlots 失败提示的错误码必须过服务消息本地化`() {
        assertTrue(
            "savePresetTimeSlots 的 Failed 分支必须把错误码先过 TimeSchemeServiceMessages.localize " +
                "（认不出的码原样返回，不许把 `code|k=v` 原文摆上 Toast）",
            hostSource.contains("TimeSchemeServiceMessages.localize("),
        )
    }

    @Test
    fun `宏录制接线必须钉住 事件分发 自动录制消费一次 保存询问`() {
        assertTrue(
            "macro:event 必须分发到 handleMacroEvent（录制态收事件进缓冲）",
            hostSource.contains("\"macro:event\" -> handleMacroEvent(raw)"),
        )
        assertTrue(
            "首次导入自动录制必须消费一次意图（读后即清：回到本页不得再自动开录）",
            hostSource.contains("state.autoRecordMacro = false"),
        )
        assertTrue(
            "录制保存询问必须挂 WarehouseMacroSaveRecordingDialog（常驻组合，show 由状态驱动）",
            hostSource.contains("WarehouseMacroSaveRecordingDialog("),
        )
    }

    @Test
    fun `脚本执行窗口必须四个出口都复位 stage 且都走同一个收尾函数`() {
        // 用户实报：一次导入完成后（页面没跳转）再点「执行导入脚本」恒被拒。
        // 根因是 complete/error 只清 scriptActive、没把 stage 从 EXECUTING 放回 LOADED，
        // 而重执行闸门 planWarehouseScriptExecution 硬要求 stage == LOADED。
        val endWindow = blockAfter(hostSource, "fun endScriptWindow(")
        assertTrue("必须有统一的执行窗口收尾函数 endScriptWindow()", endWindow.isNotEmpty())
        assertTrue(
            "endScriptWindow 必须把 stage 放回 LOADED（否则重试会被闸门拒掉）",
            endWindow.contains("WarehouseWebLoginStage.LOADED"),
        )
        assertTrue("endScriptWindow 必须清掉执行期标志 scriptActive", endWindow.contains("scriptActive = false"))
        assertTrue("endScriptWindow 必须停掉 30 秒计时", endWindow.contains("cancelImportTimeout()"))

        // 出口：complete→FINALIZE、error、落盘完成、用户取消、取消回放、重试回放。
        val exits = listOf(
            "complete→FINALIZE" to blockAfter(hostSource, "WarehouseImportCompletionAction.FINALIZE ->"),
            "error 分支" to blockAfter(hostSource, "\"error\" ->"),
            "落盘完成" to blockAfter(hostSource, "fun finalizeCoursesImport("),
            "用户取消" to blockAfter(hostSource, "fun cancelCoursesImport("),
            // 2026-11-05 成员六复核：取消/重试回放不清脚本窗口 → 30 秒后仍会弹超时、
            // 且 stage 卡在 EXECUTING 让重试被拒。
            "取消回放" to blockAfter(hostSource, "fun cancelMacroPlayback("),
            "重试回放" to blockAfter(hostSource, "fun retryMacroPlayback("),
        )
        for ((label, block) in exits) {
            assertTrue("取不到 $label 的代码块（守卫自身失效，先修守卫）", block.isNotEmpty())
            assertTrue(
                "$label 必须调 endScriptWindow()（否则 stage 留在 EXECUTING，重试必败）",
                block.contains("endScriptWindow("),
            )
        }
    }

    @Test
    fun `执行导入必须有 30 秒超时并按 Dart 两分支给文案`() {
        assertTrue(
            "必须定义 30 秒预算常量（Dart _importTimeout = Duration(seconds: 30)）",
            hostSource.contains("SCRIPT_EXECUTION_TIMEOUT_MS"),
        )
        // 判据必须落在**调用点**：只查 "armImportTimeout()" 会被函数定义行
        // `fun armImportTimeout() {` 自己满足，等于没钉住（2026-11-05 咬合探针实测发现）。
        val ready = blockAfter(hostSource, "is WarehouseScriptExecutionPlan.Ready ->")
        assertTrue("取不到 Ready 分支（守卫自身失效，先修守卫）", ready.isNotEmpty())
        assertTrue(
            "注入成功后必须起计时：Ready 分支里要有 armImportTimeout() 调用",
            ready.contains("armImportTimeout()"),
        )
        val arming = blockAfter(hostSource, "fun armImportTimeout(")
        assertTrue("计时器必须真的 delay 到预算再收尾", arming.contains("delay(SCRIPT_EXECUTION_TIMEOUT_MS)"))

        val timeout = blockAfter(hostSource, "fun onScriptExecutionTimeout(")
        assertTrue("超时必须走统一收尾 endScriptWindow", timeout.contains("endScriptWindow("))
        assertTrue(
            "回放等课程期间的超时文案必须是 courseImportScriptNoCourses（Dart 同分支）",
            timeout.contains("courseImportScriptNoCourses"),
        )
        assertTrue(
            "其余超时文案必须是 executeFailedWithError('timeout')（Dart 同分支）",
            timeout.contains("executeFailedWithError"),
        )
        assertFalse(
            "超时文案不许写死中文（ARB 逐字对拍）",
            timeout.contains("脚本执行失败"),
        )
        // 2026-11-05 DeepSeek成员1 复核发现：超时落在「回放等课程」那段时，覆盖层会停在
        // EXECUTING_IMPORT 永不结束，用户只能点覆盖层的取消才逃得出来。
        assertTrue(
            "超时收尾必须把回放覆盖层切成 ERROR（否则「正在执行导入脚本」永不结束）",
            timeout.contains("WarehousePlaybackUiState.ERROR"),
        )
    }

    /**
     * 注入闸门的两个时刻（2026-11-05 DeepSeek成员1 推演成立，复核员提出）。
     *
     * 时刻 A：回放中途取消时页面可能正被 `loadUrl` 带向新文档。收尾若直接落 `LOADED`，
     * 「执行导入脚本」闸门就是开着的 → 脚本注入到**即将被销毁的旧文档**，什么都不回，
     * 用户白等 30 秒才见一条 timeout；抢跑成功时还会在「用户已取消」之后弹一次导入确认。
     * → 收尾必须看导航标志，导航中只落 `LOADING`。
     *
     * 时刻 B：取消只停宿主侧计时与 stage，**网页里没有取消原语**，旧脚本可能还活着。
     * 直接再注入就是同页面两个实例并发：各回一条 courses；各弹一次 confirm，
     * 第二条被「同刻已有挂起」的兜底**自动答 true**——用户没见过的确认被替他点了。
     * → 注入前先问网页里的运行哨兵，为真就跳过本轮（不新开状态分支）。
     */
    @Test
    fun `注入闸门必须在导航中关闭 且网页脚本仍在跑时拒绝注入`() {
        // ---- 时刻 A ----
        val endWindow = blockAfter(hostSource, "fun endScriptWindow(")
        assertTrue("取不到 endScriptWindow（守卫自身失效，先修守卫）", endWindow.isNotEmpty())
        assertTrue(
            "endScriptWindow 必须看导航标志：导航中只落 LOADING（闸门据此保持关闭）",
            endWindow.contains("pageNavigating") && endWindow.contains("WarehouseWebLoginStage.LOADING"),
        )
        listOf(
            "导航开始" to "onWebPageStarted = {",
            "加载完成" to "onWebPageFinished = {",
            "加载失败" to "onWebError = {",
        ).forEach { (label, marker) ->
            val block = blockAfter(hostSource, marker)
            assertTrue("取不到 $label 回调（守卫自身失效，先修守卫）", block.isNotEmpty())
            assertTrue(
                "$label 必须写导航标志 pageNavigating（否则该关闸门的时候是开的）",
                block.contains("pageNavigating ="),
            )
        }
        assertTrue(
            "导航开始必须置真",
            blockAfter(hostSource, "onWebPageStarted = {").contains("pageNavigating = true"),
        )
        listOf("onWebPageFinished = {", "onWebError = {").forEach { marker ->
            assertTrue(
                "导航结束（$marker）必须置假，否则标志永远挂着把闸门锁死",
                blockAfter(hostSource, marker).contains("pageNavigating = false"),
            )
        }

        // ---- 时刻 B ----
        val ready = blockAfter(hostSource, "is WarehouseScriptExecutionPlan.Ready ->")
        assertTrue("取不到 Ready 分支（守卫自身失效，先修守卫）", ready.isNotEmpty())
        assertTrue(
            "注入前必须先探网页里的运行哨兵（WAREHOUSE_IMPORT_RUNNING_PROBE_JS）",
            ready.contains("WAREHOUSE_IMPORT_RUNNING_PROBE_JS"),
        )
        assertTrue(
            "哨兵为真时必须走统一收尾并给可行动文案（不许静默返回、不许新开状态分支）",
            ready.contains("endScriptWindow(") && ready.contains("courseImportScriptStillRunning"),
        )
        assertTrue(
            "哨兵常量必须集中定义（宿主探针与 wrapper 置位同名同源，不能各写一份字符串）",
            adapterSource.contains("const val WAREHOUSE_IMPORT_RUNNING_FLAG"),
        )
        assertTrue(
            "wrapper 必须在 IIFE 开头用哨兵挡掉第二个实例",
            adapterSource.contains("if (window.\$WAREHOUSE_IMPORT_RUNNING_FLAG) { return; }"),
        )
        assertTrue(
            "wrapper 必须置位哨兵",
            adapterSource.contains("window.\$WAREHOUSE_IMPORT_RUNNING_FLAG = true"),
        )
        // 注：这里刻意不用正则、也不写 raw string —— `$` 在两种写法里含义不同
        // （raw string 里的 `\$` 会被当字面 `$` 注入正则变成行尾锚点，2026-11-05 实测计数恒 0）。
        val resetMarker = "window." + '$' + "WAREHOUSE_IMPORT_RUNNING_FLAG = false"
        var resets = 0
        var from = adapterSource.indexOf(resetMarker)
        while (from >= 0) {
            resets++
            from = adapterSource.indexOf(resetMarker, from + resetMarker.length)
        }
        assertTrue(
            "wrapper 必须复位哨兵（complete 的 notifyTaskCompletion 与外层 catch 各一处），当前 $resets 处",
            resets >= 2,
        )
    }

    /**
     * 取 `marker` 之后**第一对配平的 `{}`**（含两端）。
     *
     * 用配平而不是「往后截 N 个字符」：截长度会因为格式化差异假红/假绿，
     * 而这些 lambda 里还有嵌套的花括号（与 `WarehouseWebLoginPageWiringGuardTest` 同款）。
     */
    private fun blockAfter(source: String, marker: String): String {
        val markerAt = source.indexOf(marker)
        if (markerAt < 0) return ""
        val begin = source.indexOf('{', markerAt)
        if (begin < 0) return ""
        var depth = 0
        var i = begin
        while (i < source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(begin, i + 1)
                }
            }
            i++
        }
        return source.substring(begin)
    }

    // ---- 2026-11-07 用户实报三件（学期弹窗按钮出界 + 首登不弹记住密码）----

    /**
     * 「记住密码」卡片必须在**登录提交引发的跳转之后**还能出现。
     *
     * 用户实报「第一次输密码不会弹记住密码」：填完账号密码点登录 → submit 事件发
     * `loginAttempt` 并跳转 → 新页面 `onWebPageStarted`。旧写法在跳转时把
     * `candidateAccount` / `hasLoginAttempt` / `hasPromptedSave` 一起清零，而
     * `loginAttempt` 与候选采集常在新文档注入观察脚本之前/同时到达 ⇒ 门禁读到的是
     * 全空状态 ⇒ `shouldPromptSave` 恒假 ⇒ 卡片永远不出现。发布版
     * （`_onPageStarted` :390）只重置 `_hasPromptedAutofill`，候选与问过标记留在
     * 内存里等 `_handleLoginAttempt` 消费。
     *
     * 钉两头：跳转回调不许再清那三个字段；「记住密码」的保存路径必须挂在
     * `onSaveRememberedLogin`（消费端还在）。
     */
    @Test
    fun `换页不许清候选账号与登录尝试 记住密码要能跨跳转弹出`() {
        val started = blockAfter(hostSource, "onWebPageStarted = {")
        assertTrue("取不到 onWebPageStarted 回调（守卫自身失效，先修守卫）", started.isNotEmpty())
        listOf("candidateAccount", "hasLoginAttempt", "hasPromptedSave").forEach { field ->
            assertFalse(
                "onWebPageStarted 不许清 `$field`：登录提交会跳转，清了它「记住密码」卡片就永远不弹" +
                    "（发布版 `_onPageStarted` 只重置 `_hasPromptedAutofill`）",
                started.contains("$field ="),
            )
        }
        assertTrue(
            "「记住密码」保存路径必须接在页面上（消费端不许丢）",
            hostSource.contains("onSaveRememberedLogin"),
        )
    }

    /**
     * 保存后只在「人还停在触发卡片的那一页」时回填。
     *
     * 卡片会活到跳转之后（这正是本次修复的前提）；若保存动作照旧无条件注入填充脚本，
     * 同 host 的登录后落地页会通过站点门禁，`__qingyuAutofillLogin` 会把学号写进
     * 页面第一个文本框（搜索框 / 个人中心表单）。所以必须同时校验：
     * 1. 当前页还有密码框；2. 文档仍是触发卡片的那一页。
     */
    @Test
    fun `保存后只在仍停在登录页时才回填`() {
        val save = blockAfter(hostSource, "fun saveRememberedLogin(")
        assertTrue("取不到 saveRememberedLogin（守卫自身失效，先修守卫）", save.isNotEmpty())
        assertTrue("回填前必须确认当前页仍有密码框", save.contains("session.hasPasswordField"))
        assertTrue("回填前必须确认文档仍是触发卡片的那一页", save.contains("warehouseDocumentKey("))
        assertTrue("触发卡片的文档键必须来自 handleLoginAttempt", save.contains("savePromptDocumentKey"))
    }

    /**
     * 网页导入顶栏不再显示学校名（2026-11-07 用户实报）。
     *
     * 所有校名在顶栏都会被截成两三个字（截图里是「重庆城…」），而发布版本来就传
     * `title: SizedBox.shrink()`。这一页的网页自身有校名页头，返回上一级也能看到。
     */
    @Test
    fun `网页导入顶栏不显示学校名`() {
        assertFalse(
            "顶栏不许再传 school.name：所有校名都会被截成两三个字",
            hostSource.contains("title = school.name"),
        )
        assertTrue(
            "网页导入页标题必须显式传空（对齐发布版 SizedBox.shrink）",
            hostSource.contains("title = \"\","),
        )
    }

    /**
     * 导入落盘成功后自动回首页（2026-11-07 用户实报「导入完成后没有返回首页」）。
     *
     * 钉四件事：普通成功调 `onImported()`；录制/回放不抢跑；不保存宏也离开；
     * 失败/取消路径**绝不**调（否则连重试机会都没了）。壳侧同时钉「接到回栈底」。
     */
    @Test
    fun `普通导入成功后必须回首页 失败路径不许回`() {
        val done = blockAfter(hostSource, "is WarehouseCoursesImportApply.Result.Done ->")
        assertTrue("取不到 Done 分支（守卫自身失效）", done.isNotEmpty())
        assertTrue("普通成功必须调 onImported()", done.contains("onImported()"))
        assertTrue(
            "必须排除录制/回放（它们各有收尾）",
            done.contains("WarehouseMacroActionState.RECORDING") && done.contains("playbackFinishing"),
        )
        val discard = blockAfter(hostSource, "fun discardCurrentMacro(")
        assertTrue("取不到 discardCurrentMacro（守卫自身失效）", discard.isNotEmpty())
        assertTrue("不保存宏也要离开网页页", discard.contains("onImported()"))
        val finished = blockAfter(hostSource, "WarehouseQuickImportFinishedDialog(")
        assertTrue("完成 sheet 关闭后要回首页", finished.contains("onImported()"))
        // 失败/取消路径不许把用户甩回首页：连重试机会都没了。
        listOf(
            "fun cancelCoursesImport(",
            "is WarehouseCoursesImportApply.Result.Failed ->",
            "fun onScriptExecutionTimeout(",
        ).forEach { marker ->
            val block = blockAfter(hostSource, marker)
            assertTrue("取不到 $marker", block.isNotEmpty())
            assertFalse("失败/取消路径不许调 onImported()：$marker", block.contains("onImported()"))
        }
        val shellIndex = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
        val webLogin = shellIndex
            .substringAfter("\"g2.webLogin\" ->", "")
            .substringBefore("\"g2.customDebug\"", "")
        assertTrue(
            "壳必须把 onImported 接到「回栈底」，否则只退一层、停在上一个导入页",
            webLogin.contains("onImported = onBackToRoot"),
        )
    }

    private fun readHostSource(): String =
        readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt")

    private fun readAdapterSource(): String =
        readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterScript.kt")

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    /**
     * 剥掉行注释与斜杠星块注释再判（正本在 `ComposeSheetGuardTest.stripKotlinComments`）：
     * 把守卫判据那行注释掉不算还接着线；块注释按 Kotlin 语义可嵌套；
     * 字符串字面量（含转义）原样保留，`"https://…"` 不会把行尾真参吃掉。
     */
    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }
}
