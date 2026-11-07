package com.mutx163.qingyu.pages.weather

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 天气三处接线的守卫（2026-11-05 审核 S3 / S4 / G1 的落地证据）。
 *
 * 三条都不是「渲染层的观感」而是**接线有没有接上**，编译产物里看不到，只能读源码文本：
 *
 * | 守卫 | 防的回退 |
 * |---|---|
 * | 冷启动初始化 | 唯一调用点退回「只在设置页 initialize」⇒ 冷启动日卡/周卡天气行整块不渲染 |
 * | 日视图挂载后补刷 | `ensureFresh` 在生产代码里零调用 ⇒ 3h TTL / 15min 退避形同虚设 |
 * | 搜索失败 vs 空结果 | HTTP 失败又折回 `emptyList()` ⇒ 断网被说成「这个城市不存在」，且没有重试出口 |
 *
 * 断言一律锚在**代码行**上（`^[ \t]*...$`），注释里出现同样的字不会让探针假绿。
 */
class WeatherWiringGuardTest {

    // ---------------------------------------------------------------- 冷启动初始化

    @Test
    fun `天气必须在壳启动处初始化一次`() {
        val source = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt")
        val boot = slice(
            source,
            "LaunchedEffect(wiring) {",
            "A1（2026-11-03）",
        )
        assertTrue("壳启动块的解析范围过短（守卫可能坏了）", boot.length > 200)
        assertTrue(
            "壳启动处没有调 `wiring.weather.initialize()`：冷启动到首页时 provider 仍是默认" +
                "「未启用」，日卡 / 周卡的天气行整块不渲染（Dart `lib/main.dart:492` 是启动即初始化）。",
            BOOT_INIT.find(boot) != null,
        )
    }

    // ---------------------------------------------------------------- 日视图补刷

    @Test
    fun `日视图挂载后必须补一次 ensureFresh`() {
        val page = readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt")
        assertTrue(
            "DayViewPage 没有 `weatherProvider` 入参：日卡天气行挂载后无从补刷" +
                "（Dart `day_course_weather_row.dart:72-80` 每行 ensureFresh）。",
            WEATHER_PROVIDER_PARAM.find(page) != null,
        )
        assertTrue(
            "DayViewPage 没有在协程里调 `weatherProvider.ensureFresh()`：initialize 之后预报再不更新" +
                "（跨天 / 跨 3 小时都停在同一份，失败也不会退避重试）。",
            ENSURE_FRESH.find(page) != null,
        )
        assertTrue(
            "ensureFresh 必须走 IO 线程（它会读缓存盘并可能同步等一次 HTTP），不能放在组合/绘制路径上。",
            IO_CONTEXT.find(page) != null,
        )

        val shell = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
        assertTrue(
            "壳没把 provider 交给日视图（日视图分支缺 `weatherProvider = weatherProvider,`）：" +
                "页面里那条补刷等于没接上。独立日页与首页展开层走的是同一个 `DayViewPage(` 调用。",
            SHELL_PASSES_PROVIDER.find(shell) != null,
        )
    }

    // ---------------------------------------------------------------- 搜索失败态

    @Test
    fun `城市搜索失败必须与真空结果分开`() {
        val service = readSource("android/app/src/main/kotlin/com/mutx163/qingyu/weather/WeatherService.kt")
        val body = slice(service, "override fun searchLocations(", "按坐标反查可读地名")
        assertTrue("searchLocations 的解析范围过短（守卫可能坏了）", body.length > 200)
        assertTrue(
            "searchLocations 在 HTTP 取不到 body 时没有 `?: return null`（失败被折成空表）：" +
                "断网时界面会显示「没有找到匹配的城市」，事实相反且没有重试出口。",
            SEARCH_HTTP_FAIL.find(body) != null,
        )
        assertTrue(
            "searchLocations 在 body 解析不出 JSON 时没有 `?: return null`（同上）。",
            SEARCH_PARSE_FAIL.find(body) != null,
        )
        assertTrue(
            "「合法 JSON 但没有 results」是真空结果，必须仍返回空表（不能报失败，否则让用户白点重试）。",
            SEARCH_EMPTY_OK.find(body) != null,
        )

        val host = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerHost.kt",
        )
        assertTrue(
            "宿主没有把「null = 失败」翻译成 `searchFailed`：失败态再也到不了界面。",
            HOST_FAILED_FLAG.find(host) != null,
        )
        assertTrue(
            "宿主没有 `found.orEmpty()`：结果列表还得靠可空值，界面拿不到稳定类型。",
            HOST_RESULTS.find(host) != null,
        )

        val page = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/weather/WeatherCityPickerPage.kt",
        )
        assertTrue(
            "选城市页没有 `state.searchFailed ->` 分支：失败仍会落到「没有找到匹配的城市」那句空态上。",
            PAGE_FAILED_BRANCH.find(page) != null,
        )
        assertTrue(
            "失败分支没用现成的「搜索失败，请稍后重试」（`WeatherStrings.weatherCitySearchFailed`）。",
            "WeatherStrings.weatherCitySearchFailed.text" in page,
        )
        assertTrue(
            "失败分支没给「重试」入口（`WeatherStrings.weatherRetryAction` + `onRetrySearch`）：" +
                "用户只能改一下输入框才可能重发。",
            "WeatherStrings.weatherRetryAction.text" in page && "onRetrySearch" in page,
        )
    }

    // ---------------------------------------------------------------- 解析

    private fun slice(source: String, from: String, to: String): String {
        val start = source.indexOf(from)
        assertTrue("源码里找不到起点 `$from`", start >= 0)
        val end = source.indexOf(to, start)
        assertTrue("源码里找不到终点 `$to`（在 `$from` 之后）", end > start)
        return source.substring(start, end)
    }

    /**
     * 从工作目录向上找仓库根再定位文件：L0 脚本与 Gradle 的工作目录不同，
     * 按「向上找标志文件」而不是写死相对路径；**找不到仍判失败**。
     */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        val BOOT_INIT = Regex("""^[ \t]*wiring\.weather\.initialize\(\)[ \t]*$""", RegexOption.MULTILINE)
        val WEATHER_PROVIDER_PARAM =
            Regex("""^[ \t]*weatherProvider: WeatherProvider\?[ \t]*=[ \t]*null[ \t]*,[ \t]*$""", RegexOption.MULTILINE)
        val ENSURE_FRESH = Regex("""^[ \t]*withContext\(Dispatchers\.IO\) \{ weatherProvider\.ensureFresh\(\) \}[ \t]*$""", RegexOption.MULTILINE)
        val IO_CONTEXT = Regex("""^import kotlinx\.coroutines\.withContext[ \t]*$""", RegexOption.MULTILINE)
        val SHELL_PASSES_PROVIDER =
            Regex("""^[ \t]*weatherProvider = weatherProvider,[ \t]*$""", RegexOption.MULTILINE)
        val SEARCH_HTTP_FAIL = Regex("""^[ \t]*\) \?: return null[ \t]*$""", RegexOption.MULTILINE)
        val SEARCH_PARSE_FAIL = Regex("""^[ \t]*val json = parseObject\(body\) \?: return null[ \t]*$""", RegexOption.MULTILINE)
        val SEARCH_EMPTY_OK = Regex("""^[ \t]*if \(results !is List<\*>\) return emptyList\(\)[ \t]*$""", RegexOption.MULTILINE)
        val HOST_FAILED_FLAG = Regex("""^[ \t]*searchFailed = found == null[ \t]*$""", RegexOption.MULTILINE)
        val HOST_RESULTS = Regex("""^[ \t]*results = found\.orEmpty\(\)[ \t]*$""", RegexOption.MULTILINE)
        val PAGE_FAILED_BRANCH = Regex("""^[ \t]*state\.searchFailed -> item\(key = "search-failed"\) \{[ \t]*$""", RegexOption.MULTILINE)
    }
}
