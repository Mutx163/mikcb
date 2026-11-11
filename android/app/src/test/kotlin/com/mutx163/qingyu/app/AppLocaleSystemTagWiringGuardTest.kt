package com.mutx163.qingyu.app

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **「跟随系统」的真源必须是全局系统资源**（2026-11-11 评审 L-01/L-02）。
 *
 * ## 它防的事故
 *
 * 2026-11-10 修过一次自指：`AppLocaleRuntime.set()` 会把手选语言写进进程
 * `Locale.setDefault`，而「跟随系统」又去读它，切过英语就永远回不去。
 *
 * 2026-11-11 评审发现**同一类自指还能换条路回来**：壳的 `withAppLocale` 用
 * `createConfigurationContext` 把 Activity 的 base 按手选语言覆写过，如果转屏/切深色时
 * 从 `newConfig.locales[0]`（或 Activity 的 resources）读「系统语言」，读到的就是**覆写值**，
 * 一刷就把 `systemLocaleTag` 写成手选语言，自指链原样复发。
 *
 * 所以这三件事必须同时成立，删任何一处都要红：
 *
 * 1. 以 `Resources.getSystem()` 为真源（不受任何 Activity 覆写影响）；
 * 2. 冷启动在覆盖**之前**注入一次；
 * 3. `onConfigurationChanged` 用同一处真源刷新，不许读 `newConfig.locales[0]`；
 * 4. `systemLanguage()` 优先读注入值，不许只读 `Locale.getDefault()`。
 */
class AppLocaleSystemTagWiringGuardTest {

    private val shell by lazy { strip(readSource(SHELL_PATH)) }
    private val runtime by lazy { strip(readSource(RUNTIME_PATH)) }

    @Test
    fun `系统语言必须从全局系统资源读`() {
        assertTrue(
            "PagesShellActivity 里找不到 `Resources.getSystem()`——系统语言真源必须绕过" +
                "被 createConfigurationContext 覆写过的 Activity resources",
            shell.contains("Resources.getSystem()"),
        )
        assertFalse(
            "又去读 `newConfig.locales[0]` 了——转屏/切深色时它可能带着手选语言覆写值",
            shell.contains("newConfig.locales[0]"),
        )
    }

    @Test
    fun `冷启动覆盖前注入一次`() {
        val applyIndex = shell.indexOf("fun withAppLocale(")
        val attachIndex = shell.indexOf("AppLocaleRuntime.setSystemLocaleTag(systemLocaleTagOf())", applyIndex)
        // 从函数体里找「读手选语言」：文件顶部还有一行 import 同名函数，直接 indexOf 会拿到它。
        val tagRead = shell.indexOf("localeTagFromRawSettingsJson", applyIndex)
        assertTrue("withAppLocale 里没有注入系统语言（setSystemLocaleTag）", attachIndex >= 0)
        assertTrue(
            "注入必须发生在读手选语言 tag 之前（先记系统语言、再覆盖）",
            tagRead < 0 || attachIndex < tagRead,
        )
        assertTrue("找不到 withAppLocale(", applyIndex >= 0)
    }

    @Test
    fun `配置变化时刷新且不丢注入`() {
        assertTrue(
            "缺少 onConfigurationChanged 刷新——用户改系统语言后不重启 App，「跟随系统」不会跟随",
            shell.contains("override fun onConfigurationChanged(") &&
                shell.contains("AppLocaleRuntime.setSystemLocaleTag("),
        )
    }

    @Test
    fun `跟随系统优先用注入值而不是进程默认 Locale`() {
        assertTrue(
            "AppLocaleRuntime 缺少 setSystemLocaleTag / systemLocaleTag 注入点",
            runtime.contains("fun setSystemLocaleTag(") && runtime.contains("systemLocaleTag"),
        )
        val systemLanguageBody = sliceFrom(runtime, "private fun systemLanguage()")
        assertTrue(
            "systemLanguage() 没有走 systemLocale()——又只读 Locale.getDefault() 就回到了自指链",
            systemLanguageBody.contains("systemLocale()"),
        )
        assertFalse(
            "systemLanguage() 里直接读 Locale.getDefault() 了",
            systemLanguageBody.contains("Locale.getDefault()"),
        )
    }

    // ------------------------------------------------------------------ 工具

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private fun strip(text: String): String =
        text.replace(Regex("""(?s)/\*.*?\*/"""), " ")
            .lineSequence()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    private fun sliceFrom(text: String, marker: String): String {
        val start = text.indexOf(marker)
        check(start >= 0) { "找不到 $marker" }
        val next = text.indexOf("\n    private fun ", start + marker.length)
        return if (next < 0) text.substring(start) else text.substring(start, next)
    }

    private companion object {
        const val SHELL_PATH = "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
        const val RUNTIME_PATH = "android/app/src/main/kotlin/com/mutx163/qingyu/app/ArbText.kt"
    }
}
