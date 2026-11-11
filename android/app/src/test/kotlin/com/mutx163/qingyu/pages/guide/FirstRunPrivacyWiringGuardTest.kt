package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.stripKotlinComments
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首启隐私门的**源码接线守卫**（B1，2026-11-10）。
 *
 * 为什么需要它：这类接线最容易「模型绿、界面没接」——`PrivacyConsentPreferences`
 * 单测全绿，但壳冷启动没调闸、或某条路径又把 `PagesShell(` 渲染出来，用户照样
 * 第一次就能跳过隐私页。判据与 `DiagnosticsWiringGuardTest` 同一套：读源码文本。
 *
 * 2026-11-10 复核加固（hy模型 1 提的「字符串包含能误绿」）：
 * - `PagesShell(` 用**结构断言**：全文件只允许 1 个调用点，且必须落在
 *   `if (firstRunDone) { … }` 的块内；`else` 块里出现即红。
 * - `CrashLogInstaller.install()` 只允许 1 处，且在 `initializeAnalyticsIfNeeded`
 *   方法体里（该方法自己查同意键 ⇒ 只可能在同意后跑到）。
 * - `initializeAnalyticsIfNeeded` 的**调用方文件集合**钉死为
 *   `UmengApplication.kt`（定义 + 内部调用）与 `LiveSelfCheckHost.kt`（调试页两处）。
 *
 * 2026-11-11 P6-G1（守卫剥离统一）：私有 `codeOf` 换成 testutil 共享件
 * （`readKotlinSourceNoStrings` / `readKotlinSourceNormalized` / `stripKotlinComments`），
 * 并把两处裸子串判据升级成结构断言：
 * - `FirstRunPrivacyGate(`：全文件恰好 1 个调用点，且落在 `if (firstRunDone)` 的 else 分支；
 * - `UserGuideHost(`：全文件恰好 1 个调用点，且落在 `"i.userGuide"` 路由分支内。
 *
 * 咬合探针：把 `FirstRunPrivacyGate(` 那次调用整行注释掉 / 把 `requestNotificationPermissionOnce()`
 * 那次调用注释掉 ⇒ 对应用例红（注释掉的接线不算接线）；还原后绿。
 */
class FirstRunPrivacyWiringGuardTest {

    @Test
    fun `冷启动必须先过首启门再挂壳`() {
        val code = readKotlinSourceNoStrings(ACTIVITY)

        val definitionAt = code.indexOf("private fun PagesShell(")
        assertTrue("找不到 PagesShell 定义（解析可能坏了）", definitionAt >= 0)
        // 定义里的 `PagesShell(` 匹配从 "PagesShell" 开始，不在 "private fun " 起点；
        // 精确定位它，避免把函数定义误算成第二个调用点。
        val definitionCallAt = code.indexOf("PagesShell(", definitionAt)
        val calls = Regex("""PagesShell\s*\(""")
            .findAll(code)
            .map { it.range.first }
            .filter { it != definitionCallAt }
            .toList()
        assertEquals("PagesShell( 只允许 1 个调用点（多于 1 个说明有旁路）", 1, calls.size)

        val branchAt = code.indexOf("if (firstRunDone) {")
        assertTrue("找不到 if (firstRunDone) 分支", branchAt >= 0)
        val branchEnd = matchingBrace(code, code.indexOf('{', branchAt))
        assertTrue(
            "壳调用不在 if (firstRunDone) 分支内——未同意也能渲染首页",
            calls[0] in branchAt..branchEnd,
        )

        // P6-G1（2026-11-11）：这里原来是裸子串 `"FirstRunPrivacyGate(" in code`——只要
        // 源码里任何一处字符串 / 注释提到它就能满足（注释已由共享剥离器剥掉，字符串字面量
        // 也被 readKotlinSourceNoStrings 中性化，但它本身仍不能证明「闸真的挂上了」）。
        // 改成结构断言：全文件**恰好 1 个调用点**，且落在 `if (firstRunDone)` 的 else 分支里。
        val gateCalls = Regex("""FirstRunPrivacyGate\s*\(""")
            .findAll(code)
            .map { it.range.first }
            .toList()
        assertEquals(
            "FirstRunPrivacyGate( 全文件只允许 1 个调用点（多一处说明首启门挂了两次 / 有旁路）",
            1,
            gateCalls.size,
        )
        val elseAt = code.indexOf("} else {", branchAt)
        assertTrue("找不到 firstRunDone 的 else 分支（首启闸必须挂在这里）", elseAt >= 0)
        val elseEnd = matchingBrace(code, code.indexOf('{', elseAt))
        assertTrue(
            "首启闸没挂进 `if (firstRunDone) { … } else { … }` 的 else 分支" +
                "——未同意的用户会直接看到首页（或闸挂在了永远走不到的位置）",
            gateCalls[0] in elseAt..elseEnd,
        )
        // 5-1（评审组 2026-11-10）：只断言「出现过 isFirstRunComplete()」会被
        // `mutableStateOf(true)` 绕过（守卫仍绿、未同意直接见首页）。这里钉初值原文。
        assertTrue(
            "firstRunDone 的初值必须来自 privacyPrefs.isFirstRunComplete()" +
                "（改成 mutableStateOf(true) 会让未同意用户直接进首页）",
            Regex("""mutableStateOf\(\s*privacyPrefs\.isFirstRunComplete\(\)\s*\)""").containsMatchIn(code),
        )
    }

    @Test
    fun `未同意分支里不许再出现壳`() {
        val code = readKotlinSourceNoStrings(ACTIVITY)
        val branchAt = code.indexOf("if (firstRunDone) {")
        assertTrue("找不到 if (firstRunDone) 分支", branchAt >= 0)
        val elseAt = code.indexOf("} else {", branchAt)
        assertTrue("找不到 firstRunDone 的 else 分支", elseAt >= 0)
        val elseEnd = matchingBrace(code, code.indexOf('{', elseAt))
        assertTrue(
            "else 分支里出现了 PagesShell( —— 未同意会看到首页",
            "PagesShell(" !in code.substring(elseAt, elseEnd),
        )
    }

    @Test
    fun `通知权限申请只允许在首启门块内一次`() {
        val code = readKotlinSourceNoStrings(ACTIVITY)

        val gateAt = code.indexOf("LaunchedEffect(firstRunDone) {")
        assertTrue("找不到 LaunchedEffect(firstRunDone) 块", gateAt >= 0)
        val gateEnd = matchingBrace(code, code.indexOf('{', gateAt))

        // 5-2（评审组 2026-11-10）：只比「首次出现下标」会被两种改法绕过——
        // postFrameCallback 里再加一次调用（权限框提前弹）、或删掉唯一那次（永不弹）。
        // 这里钉「全文件恰好 1 个调用点，且落在 LaunchedEffect(firstRunDone) 块内」。
        val definitionAt = code.indexOf("private fun requestNotificationPermissionOnce(")
        assertTrue("找不到 requestNotificationPermissionOnce 定义", definitionAt >= 0)
        val definitionCallAt = code.indexOf("requestNotificationPermissionOnce()", definitionAt)
        val calls = Regex("""requestNotificationPermissionOnce\s*\(\)""")
            .findAll(code)
            .map { it.range.first }
            .filter { it != definitionCallAt }
            .toList()

        assertEquals(
            "requestNotificationPermissionOnce() 全文件只允许 1 个调用点" +
                "（多一处就会在首启门打开前再弹一次系统权限框）",
            1,
            calls.size,
        )
        assertTrue(
            "通知权限申请不在 LaunchedEffect(firstRunDone) 块内" +
                "——冷启第一帧就会把系统权限框盖在隐私页前面",
            calls[0] in gateAt..gateEnd,
        )
    }

    @Test
    fun `复看路由也必须走抽出的宿主`() {
        // 这一条要**保留字符串内容**：路由锚点 `"i.userGuide"` / `"i.more"` 本身就是字面量，
        // 中性化后就无处定位分支了。用 Normalized 档（剥注释、留字面量），再在分支切片内
        // 做结构断言——不再是「全文件出现一次 `UserGuideHost(` 就算过」。
        val code = readKotlinSourceNormalized(SHELL_INDEX)

        val calls = Regex("""UserGuideHost\s*\(""")
            .findAll(code)
            .map { it.range.first }
            .toList()
        assertEquals(
            "UserGuideHost( 全文件只允许 1 个调用点（多一处说明有分支绕开抽出的宿主）",
            1,
            calls.size,
        )
        val routeAt = code.indexOf("\"i.userGuide\"")
        assertTrue("找不到 \"i.userGuide\" 路由分支（解析可能坏了）", routeAt >= 0)
        val routeEnd = code.indexOf("\"i.more\"", routeAt)
        assertTrue("找不到 \"i.userGuide\" 之后的 \"i.more\" 路由（分支边界取不到）", routeEnd > routeAt)
        assertTrue(
            "ShellPageIndex 的 i.userGuide 分支没接 UserGuideHost（又退回直拼渲染层？）",
            calls[0] in routeAt..routeEnd,
        )
    }

    @Test
    fun `友盟与崩溃落盘只在同意后`() {
        val code = readKotlinSourceNoStrings(UMENG_APPLICATION)

        val initAt = code.indexOf("fun initializeAnalyticsIfNeeded(")
        assertTrue("找不到 initializeAnalyticsIfNeeded 定义", initAt >= 0)
        val initBody = code.substring(initAt, matchingBrace(code, code.indexOf('{', initAt)))
        assertTrue(
            "initializeAnalyticsIfNeeded 没查 accepted_privacy_policy —— raw 入口可以绕过同意",
            "hasAcceptedPrivacyPolicy()" in initBody,
        )

        val installs = Regex("""CrashLogInstaller\.install\(\)""")
            .findAll(code)
            .map { it.range.first }
            .toList()
        assertEquals("CrashLogInstaller.install() 只允许 1 处（在 initializeAnalyticsIfNeeded 里）", 1, installs.size)
        assertTrue(
            "CrashLogInstaller.install() 出现在 initializeAnalyticsIfNeeded 之外",
            installs[0] in initAt..matchingBrace(code, code.indexOf('{', initAt)),
        )

        val onCreateAt = code.indexOf("override fun onCreate()")
        assertTrue("找不到 Application.onCreate", onCreateAt >= 0)
        val onCreateEnd = matchingBrace(code, code.indexOf('{', onCreateAt))
        assertTrue(
            "Application.onCreate 里还在安装崩溃落盘 —— 未同意就会写本地日志",
            "CrashLogInstaller.install()" !in code.substring(onCreateAt, onCreateEnd),
        )
    }

    @Test
    fun `init 调用方文件集合被钉死`() {
        val callers = mutableSetOf<String>()
        for (root in SOURCE_ROOTS) {
            val dir = repoFile(root)
            if (!dir.isDirectory) continue
            dir.walkTopDown()
                .filter { it.isFile && it.extension == "kt" }
                .forEach { file ->
                    if ("initializeAnalyticsIfNeeded(" in
                        stripKotlinComments(file.readText(), neutralizeStrings = true)
                    ) {
                        callers += file.name
                    }
                }
        }
        assertEquals(
            "initializeAnalyticsIfNeeded 出现了新的调用方：必须确认它带同意门，并更新本守卫",
            setOf("UmengApplication.kt", "LiveSelfCheckHost.kt"),
            callers,
        )
    }

    // ------------------------------------------------------------------ 工具

    // P6-G1（2026-11-11）：私有剥离器 `codeOf` 已删除，改用 testutil 共享件
    // `readKotlinSourceNoStrings` / `readKotlinSourceNormalized` / `stripKotlinComments`
    // ——各守卫自写一份时强弱不一，最弱的版本连嵌套块注释都剥不干净（注释掉的接线照样绿）。

    private fun matchingBrace(text: String, openIndex: Int): Int {
        var depth = 0
        for (i in openIndex until text.length) {
            when (text[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
        }
        error("大括号不平衡（起点 $openIndex，文件可能被截断）")
    }

    /** 从工作目录向上找仓库根，再定位文件（目录扫描用；单文件读一律走 testutil 共享件）。 */
    private fun repoFile(relative: String): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.exists()) return candidate
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val ACTIVITY =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
        const val SHELL_INDEX =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
        const val UMENG_APPLICATION =
            "android/app/src/main/kotlin/com/mutx163/qingyu/UmengApplication.kt"
        val SOURCE_ROOTS = listOf(
            "android/app/src/main/kotlin",
            "android/app/src/composeP1/kotlin",
        )
    }
}
