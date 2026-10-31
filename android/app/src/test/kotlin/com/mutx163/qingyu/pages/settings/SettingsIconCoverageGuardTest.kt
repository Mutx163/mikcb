package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置行**图标名落点守卫**：模型里出现的每个 `SettingsRowIcon("名字", …)`，
 * 渲染层 `miuixIconByName` 都必须认得；否则会被静默画成 Info 图标（点了像图标丢了）。
 *
 * ## 为什么要有这条（2026-10-29 的真实问句）
 *
 * 用户问「设置页面为什么一个图标也没有」——根因之一就是模型没给行配 icon；
 * 配了但名字漏映射，也会退化成 Info，屏上看起来仍然是「不对的图标」。
 * 图标是**跨源集契约**（模型在 `main`，映射在 `composeP1`），编译期不会互查，
 * 所以只能在源码层钉住。
 *
 * 与 [SettingsRouteWiringGuardTest] 同一套读文件规矩：从工作目录向上找 `android/app/src`，
 * 找不到就失败（不许静默跳过）。
 */
class SettingsIconCoverageGuardTest {

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private fun settingsSources(): List<File> {
        val dir = File(androidSrc(), "main/kotlin/com/mutx163/qingyu/pages/settings")
        assertTrue("设置页源码目录不存在：${dir.path}", dir.isDirectory)
        return dir.listFiles { f -> f.isFile && f.extension == "kt" }!!.toList()
    }

    @Test
    fun `设置页用到的每个图标名渲染层都认得`() {
        val used = sortedSetOf<String>()
        val iconCall = Regex("""SettingsRowIcon\("([^"]+)"""")
        for (file in settingsSources()) {
            iconCall.findAll(file.readText()).forEach { used += it.groupValues[1] }
        }
        assertTrue("设置页里一个 SettingsRowIcon 都没找到（模型没配图标？）", used.isNotEmpty())

        val renderer = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )
        assertTrue("渲染层文件不存在：${renderer.path}", renderer.isFile)
        val body = renderer.readText()
            .substringAfter("private fun miuixIconByName")
            .substringBefore("private fun parseHexColor")
        assertTrue("没在渲染层找到 miuixIconByName", body.isNotBlank())
        val mapped = sortedSetOf<String>()
        Regex("""(?m)^\s*"([^"]+)"\s*->""").findAll(body).forEach { mapped += it.groupValues[1] }

        val missing = used.filter { it !in mapped }
        assertTrue(
            "以下图标名在 miuixIconByName 里没有映射，会退化成 Info：\n" +
                missing.joinToString("\n") { "  $it" },
            missing.isEmpty(),
        )
    }
}
