package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **设置三页「保存失败静默」守卫**（2026-11-05 复核查实后补）。
 *
 * 底栏编辑器、自定义菜单编辑器、首页导航三个宿主的写盘失败分支以前只写一行日志：
 * 用户点完「加 / 删 / 移」或改完导航，界面上没有任何反馈，重进页面又回到旧值——
 * 看着像「点了没反应」，实际是没落盘。
 *
 * 修法是**宿主级 toast**（键复用 `SettingsStringsExt2.saveFailed`），**不给编辑器的状态类
 * 扩错误通道**：那会把结构撑大，而失败提示本来就只需要一句话。
 *
 * 两条判据：
 * 1. 三个宿主各自的函数块里必须同时有失败日志（便于排查）与 `saveFailed` 提示（用户能读到的反馈）；
 * 2. 「没落盘就不改内存」的既有语义保留 —— 仍然只经 `saveVerified` 校验后才赋值，
 *    界面停在旧值是对的，缺的只是那句话。
 *
 * 探针：删掉任意一处的 toast 调用 → 本守卫变红。
 */
class SettingsSaveFailureToastGuardTest {

    private val source: String by lazy { stripKotlinComments(readSettingsHostSource()) }

    @Test
    fun `三个宿主写盘失败必须给用户提示 不能只写日志`() {
        val hosts = listOf(
            "底栏编辑器" to "glass dock editor save did not land",
            "菜单编辑器" to "home menu editor save did not land",
            "首页导航" to "home navigation save did not land",
        )
        for ((label, marker) in hosts) {
            val window = windowAfter(marker)
            assertTrue("取不到 $label 的失败日志（守卫自身失效，先修守卫）：$marker", window != null)
            assertTrue(
                "$label 写盘失败必须给用户 toast（SettingsStringsExt2.saveFailed）；" +
                    "只写日志等于没反馈，用户读不到 logcat",
                window!!.contains("SettingsStringsExt2.saveFailed"),
            )
        }
    }

    @Test
    fun `失败时不许改内存 只有落盘成功才赋值`() {
        // 修的是「不说话」，不是「回退式赋值」：model 只在 saveVerified 为真时改。
        listOf(
            "底栏编辑器" to "glass dock editor save did not land",
            "菜单编辑器" to "home menu editor save did not land",
            "首页导航" to "home navigation save did not land",
        ).forEach { (label, marker) ->
            // 判据在日志**之前**：失败分支的形态是 `if (saveVerified(...)) { model = … } else { Log.e(…) }`，
            // 日志前面的那段才是校验点（第一版判据写成「日志之后」直接把自己判红了，2026-11-05 修正）。
            val window = windowBefore(marker)
            assertTrue("取不到 $label 的失败日志（守卫自身失效，先修守卫）", window != null)
            assertTrue("$label 必须先用 saveVerified 校验再赋值（没落盘就不改内存）", window!!.contains("saveVerified("))
        }
    }

    /** 取 `marker` 之前的一段窗口（默认 600 字符）。 */
    private fun windowBefore(marker: String, size: Int = 600): String? {
        val at = source.indexOf(marker)
        if (at < 0) return null
        return source.substring(maxOf(0, at - size), at)
    }

    /**
     * 取 `marker` 之后的一段窗口（默认 600 字符）。
     *
     * 为什么不用「按花括号配平取函数块」：`SettingsHost.kt` 里的日志文案与字符串模板含括号，
     * 朴素配平会提前收尾/越界，判据会假绿或假红。这里只关心「日志那行之后紧跟着提示」，
     * 定长窗口足够（实测两处提示都在 200 字符内），且删除 toast 后窗口里必然为空 —— 探针能咬合。
     */
    private fun windowAfter(marker: String, size: Int = 600): String? {
        val at = source.indexOf(marker)
        if (at < 0) return null
        return source.substring(at, minOf(source.length, at + size))
    }

    private fun readSettingsHostSource(): String {
        val relative = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 SettingsHost.kt（当前目录 ${File("").absolutePath}）")
    }

    /**
     * 剥掉行注释与块注释再判：把 toast 那行注释掉不算还接着线；
     * 字符串字面量原样保留（日志文案里有括号，不能当结构判）。
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
