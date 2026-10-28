package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置族**路由落点守卫**：设置页里出现的每个导航目标，都必须能在壳的
 * [shellPageIdForRoute] 里找到映射。
 *
 * ## 为什么要这条（2026-10-28 的真实缺陷）
 *
 * 设置族 20+ 页共用一个 `SettingsPageScreen(spec)` 渲染层，行上的导航目标写在
 * `actionTarget`（Dart 路由串）/ `ROUTE_*` 常量里。壳用一个映射表把路由串翻成页面 id。
 * 只要漏一条，那一行就是「点了没反应」——而这类缺陷**编译能过、单测能过、真机上才看得见**。
 *
 * 本轮实测漏过两条：`/settings/time-schemes`（时间模板）与 `app-logs`（诊断日志）。
 * 这条守卫把「页面写了什么路由」与「壳认不认」钉在一起，以后新增设置页忘了补表会先红。
 *
 * ## 它读文件，所以守两条纪律
 *
 * 1. 路径从工作目录向上找 `android/app/src`，不写死盘符（CI 也能跑）；
 * 2. 找不到文件**失败而不是跳过**——跳过等于这条守卫不存在。
 */
class SettingsRouteWiringGuardTest {

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

    private fun shellWiringSource(): String {
        val file = File(androidSrc(), "composeUi/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt")
        assertTrue("壳路由表文件不存在：${file.path}", file.isFile)
        return file.readText()
    }

    /** 页面里声明的所有导航目标：`ROUTE_*` 常量值 + 以 `/` 开头的 `actionTarget` 字面量。 */
    private fun referencedRoutes(): Set<String> {
        val routeConst = Regex("""const val ROUTE_[A-Z0-9_]+ = "([^"]+)"""")
        val routeLiteral = Regex("""actionTarget = "(/[^"]+)"""")
        val routes = sortedSetOf<String>()
        for (file in settingsSources()) {
            val text = file.readText()
            routeConst.findAll(text).forEach { routes += it.groupValues[1] }
            routeLiteral.findAll(text).forEach { routes += it.groupValues[1] }
        }
        return routes
    }

    @Test
    fun `每个设置导航目标都能被壳映射到页面`() {
        val body = shellWiringSource().substringAfter("fun shellPageIdForRoute", "")
        assertTrue("没在 ShellWiring.kt 里找到 shellPageIdForRoute", body.isNotBlank())

        val missing = referencedRoutes().filter { route -> "\"$route\" ->" !in body }
        assertTrue(
            "以下设置导航目标没有在 shellPageIdForRoute 里落点（点了会没反应）：\n" +
                missing.joinToString("\n") { "  $it" },
            missing.isEmpty(),
        )
    }
}
