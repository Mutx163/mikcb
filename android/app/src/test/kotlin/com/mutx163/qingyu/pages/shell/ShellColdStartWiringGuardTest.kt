package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「设置只解析一次 + 启动分段打点」的接线守卫（A1/A2 · 2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * A1：首帧前同一份 `timetable_settings` JSON 曾被主线程解析 **4 遍**
 * （attachBaseContext / ShellWiring 构造 / setContent 的 remember / initialRootId 的
 * remember）——静态审计的确证问题。修法：ShellWiring 构造时全量解析**一次**
 * （`initialSettings`），两处 remember 改用共享值；attachBaseContext 只读语言单键
 * （`localeTagFromRawSettingsJson`，不建模型）。本守卫钉住「解析一次 + 共享传递」，
 * 谁把任何一处改回自己重新解析，这里必须红。
 *
 * A2：启动分段补 `mainEnter`（Application 首行、显式时间戳）与 `firstFrame`
 * （setContent 后第一个 vsync）。加上既有的 `shellAttach`，「进程 → Application →
 * 壳挂载 → 首帧」三段在报表里都可归因；谁删了任何一段，这里必须红。
 *
 * ## 为什么读源码文本
 *
 * 「谁在组合期 / onCreate 里调了什么」在编译产物里看不出来；与同目录
 * `HomeSettingsRefreshGuardTest` / `DayViewWiringGuardTest` 同一套做法：
 * 判据是「出现/不出现 + 计数」，不依赖缩进与折行。
 */
class ShellColdStartWiringGuardTest {

    // ------------------------------------------------------------------ A1

    @Test
    fun `壳的全量设置解析只有一处且必须共享`() {
        val wiring = readSource("${MAIN}/pages/ShellWiring.kt")
        assertTrue(
            "`ShellWiring.initialSettings` 必须是公开 val、由 settingsModel 解析：\n" +
                "setContent 的主题桥初值与 initialRootId 都靠它共享冷启动那一次解析。",
            "val initialSettings: TimetableSettingsModel = settingsModel.load()" in wiring,
        )
    }

    @Test
    fun `attachBaseContext 只读语言单键不建模型`() {
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        assertTrue(
            "withAppLocale 必须走单键读取（localeTagFromRawSettingsJson）：重新出现" +
                "整模型反序列化会把首帧前的解析次数弹回去。",
            "localeTagFromRawSettingsJson(" in shell,
        )
        assertTrue(
            "PagesShellActivity 不允许再构造 TimetableSettingsModelStore（那是整模型" +
                "解析）：语言覆写只需 timetable_settings 里的一个键。",
            "TimetableSettingsModelStore(" !in shell,
        )
    }

    @Test
    fun `首帧前的两处 remember 必须用共享初值`() {
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        assertTrue(
            "setContent 的主题桥初值必须用 wiring.initialSettings（共享解析），" +
                "不能自己重新解析 JSON。",
            "mutableStateOf(wiring.initialSettings)" in shell,
        )
        assertTrue(
            "initialRootId 必须用 wiring.initialSettings.timetableHomeViewMode" +
                "（共享解析）。",
            "rootItemIdForView(wiring.initialSettings.timetableHomeViewMode)" in shell,
        )
        // PagesShellActivity 里允许保留的设置重读只剩「回到主屏」那一次
        //（LaunchedEffect(atRoot)，revision 触发，不在冷启动首帧路径上）。
        val loadCalls = Regex(Regex.escape("wiring.settingsModel.load()")).findAll(shell).count()
        assertTrue(
            "PagesShellActivity 里出现 $loadCalls 次设置整份重读，只允许 1 次" +
                "（回到主屏的 LaunchedEffect(atRoot)）。多出来的每一次都是冷启动" +
                "首帧前多解析一遍同一份 JSON（A1 修的就是它）。",
            loadCalls == 1,
        )
    }

    // ------------------------------------------------------------------ A2

    @Test
    fun `启动分段必须有三段且 mainEnter 在 super 之前`() {
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        val app = readSource("${MAIN}/UmengApplication.kt")
        val mainEnter = """PerfProbeCore.markStartup("mainEnter", """
        assertTrue(
            "UmengApplication.onCreate 必须打 mainEnter，且用 PerfProbeCore 的" +
                "**显式时间戳**重载（此刻探针未安装、内部时钟未配置，" +
                "platform 层无时间戳版本会把打点丢掉）。",
            mainEnter in app,
        )
        assertTrue(
            "mainEnter 必须在 onCreate 首行（super.onCreate() 之前）：晚了就把" +
                "Application 自己的耗时漏进上一段，分段失真。",
            app.indexOf(mainEnter) in 0 until app.indexOf("super.onCreate()"),
        )
        assertTrue(
            "壳挂载打点 shellAttach 不许删：mainEnter 与 firstFrame 之间的分段靠它。",
            """PerfProbe.markStartup("shellAttach")""" in shell,
        )
        assertTrue(
            "首帧必须补 firstFrame 打点（setContent 后第一个 vsync）：没有它，" +
                "「壳挂载 → 首帧」这段最贵的开销在报表里不可归因。",
            """PerfProbe.markStartup("firstFrame")""" in shell,
        )
    }

    // ------------------------------------------------ 冷启动首帧：天气缓存 / 启动对账

    @Test
    fun `天气缓存必须在首帧前同步进内存`() {
        val wiring = readSource("${MAIN}/pages/ShellWiring.kt")
        assertTrue(
            "ShellWiring 构造时必须调 weather.loadCached()：只在页面里 LaunchedEffect 调 " +
                "initialize() 的话，首帧没有天气行，数据到了才突然多出一行（用户实报）。",
            "weather.loadCached()" in wiring,
        )
        assertTrue(
            "weather.loadCached() 必须写在 `val weather: WeatherProvider by lazy` 之后：" +
                "Kotlin 的 init 块按书写顺序执行，写在前面时 by lazy 的委托还没初始化，会 NPE。",
            wiring.indexOf("val weather: WeatherProvider by lazy") in
                0 until wiring.indexOf("weather.loadCached()"),
        )
    }

    @Test
    fun `启动对账必须搬到首帧之后`() {
        val wiring = readSource("${MAIN}/pages/ShellWiring.kt")
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        assertTrue(
            "ShellWiring 构造函数里不允许再调 reconcileNativePrefsFromSettings()：" +
                "它要读整份设置 JSON、还可能排一次 AlarmManager（binder）。" +
                "改成首帧后由 reconcileStartupPrefs() 在 IO 块里调。",
            "fun reconcileStartupPrefs()" in wiring,
        )
        assertTrue(
            "首帧之后的 IO 副作用块必须调 wiring.reconcileStartupPrefs()，否则对账永远不跑。",
            "wiring.reconcileStartupPrefs()" in shell,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：解析器坏了会让上面几条全部变绿 —— 那比没有守卫更糟。
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        assertTrue(
            "PagesShellActivity.kt 读出来太短（${shell.length} 字符），解析可能坏了",
            shell.length > 1000,
        )
        val wiring = readSource("${MAIN}/pages/ShellWiring.kt")
        assertTrue(
            "ShellWiring.kt 读出来太短（${wiring.length} 字符），解析可能坏了",
            wiring.length > 1000,
        )
    }

    /**
     * 从工作目录向上找仓库根再定位文件：L0 脚本与 Gradle 的工作目录不同，
     * 所以按「向上找标志文件」而不是写死相对路径；**找不到仍判失败**。
     * 与 `HomeSettingsRefreshGuardTest.readSource` 同一份实现。
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
        const val MAIN = "android/app/src/main/kotlin/com/mutx163/qingyu"
    }
}
