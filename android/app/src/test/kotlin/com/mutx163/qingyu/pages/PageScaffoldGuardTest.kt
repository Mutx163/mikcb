package com.mutx163.qingyu.pages

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 已验收两批（P3-A 关于域 / P3-D2 日程与任务域）的**页面骨架守卫**。
 *
 * ## 它钉住的是什么
 *
 * 2026-10-27 审核发现这 9 个页面存在四处骨架问题，都是「静默出错」型——
 * 编译能过、测试能绿、只有真机盯屏才看得出来，所以必须用守卫钉住：
 *
 * 1. **状态栏被算两遍**：官方 `TopAppBar` 自己会加 `WindowInsets.systemBars` 顶部内边距
 *    （`TopAppBar.kt:806`），页面又额外写了 `statusBarsPadding()`，标题整体下移一个状态栏；
 * 2. **大标题永不折叠**：`largeTitle` 不传时默认等于 `title`，于是每页都白送一个 32sp
 *    大标题；不传 `scrollBehavior` 就永远不会收起，白占约 60dp；
 * 3. **底部手势条被忽略**：只取 `innerPadding.calculateTopPadding()` 时，
 *    列表最后一行会钻到小白条下面；
 * 4. **深色模式内容不可读**：两个壳用的是无参 `MiuixTheme { }`，配色恒为亮色，
 *    而正文按 `isSystemInDarkTheme()` 取白字 → 白字落在白卡片上。页面侧用
 *    `QingyuPageTheme` 兜住，壳的彻底修复另做。
 *
 * ## 它是源码文本守卫，不是行为测试
 *
 * 和 `SettingsRowComponentGuardTest` 同一套路：真机截图要用户配合、在 CI 里跑不了，
 * 但「有没有写这几个必要参数」是文本可判的。文本守卫的代价是**容易被绕过**
 * （改个换行、换个写法），所以这里的断言刻意只钉「必须出现的最小集合」，
 * 不去规定书写格式。
 *
 * 读文件所以纪律上要做两件事：路径从工作目录向上找（CI 与 IDE 都能跑）；
 * 找不到文件时**失败而不是跳过**——跳过等于守卫不存在。
 */
class PageScaffoldGuardTest {

    /** 从当前工作目录向上找 `android/app/src`，兼容 Gradle（在 android/ 跑）与 IDE。 */
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

    private fun pageFile(relative: String): File =
        File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages/$relative")

    /** 本次受管的 9 个页面（P3-A 三页 + P3-D2 五页 + 共用骨架）。 */
    private val guardedPages = listOf(
        "about/PagesCommon.kt",
        "about/AboutStaticPage.kt",
        "about/OpenSourceLicensesPage.kt",
        "about/SupportCreatorPage.kt",
        "schedule/AddScheduleItemPage.kt",
        "schedule/ScheduleDateRulePage.kt",
        "schedule/ScheduleListPage.kt",
        "task/AddTaskPage.kt",
        "task/TaskListPage.kt",
    )

    private fun read(relative: String): String {
        val file = pageFile(relative)
        assertTrue("受管页面文件不存在：${file.path}", file.isFile)
        return file.readText()
    }

    @Test
    fun `受管页面一个都不能少`() {
        // 防止有人删页/改名后守卫静默变成空跑。
        val missing = guardedPages.filter { !pageFile(it).isFile }
        assertTrue("以下受管页面文件不见了：$missing", missing.isEmpty())
    }

    @Test
    fun `不允许再手写状态栏内边距`() {
        // 顶栏进 Scaffold 的 topBar 槽位后，状态栏由官方组件自己吃。
        // 再手加一次就是重复计算，标题会整体下移一个状态栏高度。
        val offenders = guardedPages.filter {
            "statusBarsPadding" in read(it)
        }
        assertTrue(
            "以下页面还在手写 statusBarsPadding（顶栏已自带系统栏内边距，会算两遍）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `有顶栏的页面必须传 largeTitle 与 scrollBehavior`() {
        // 官方 TopAppBar 的 largeTitle 默认等于 title、scrollBehavior 默认 null：
        // 不传 = 常驻一个 32sp 大标题且永不折叠，与 Dart 侧 HyperosSubpage
        // （overlayHeader=true + collapsibleLargeTitle=true）的可折叠行为不符。
        val offenders = guardedPages.filter { rel ->
            val text = read(rel)
            if ("TopAppBar(" !in text) return@filter false
            val missingLarge = "largeTitle" !in text
            val missingScroll = "scrollBehavior" !in text
            missingLarge || missingScroll
        }
        assertTrue(
            "以下页面用了 TopAppBar 却没传 largeTitle / scrollBehavior：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `每个滚动容器都要挂 nestedScroll`() {
        // 顶栏折叠靠 nestedScroll 把滚动手势喂给 ScrollBehavior；
        // 漏了这一步就是「参数传了、行为没接」，看起来像没做。
        val offenders = guardedPages.filter { rel ->
            val text = read(rel)
            // 只要求有滚动容器的页面挂
            val scrollable = "LazyColumn(" in text || "verticalScroll(" in text
            scrollable && "nestedScroll(" !in text
        }
        assertTrue(
            "以下页面有滚动容器却没挂 nestedScroll（大标题不会折叠）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `底部内边距必须包含手势条高度`() {
        // 页面底色延伸到手势条下方是 Edge-to-Edge 的正确行为，
        // 但内容必须给自己留出那一段，否则最后一行钻到小白条底下。
        //
        // 骨架 PagesCommon 只把 innerPadding 转发给内容、自身不持有列表，
        // 所以不受这条约束（它由各页负责用对）。
        val offenders = guardedPages.filter { rel ->
            if (rel.startsWith("about/PagesCommon")) return@filter false
            val text = read(rel)
            if ("innerPadding" !in text) return@filter false
            "calculateBottomPadding()" !in text
        }
        assertTrue(
            "以下页面取了 innerPadding 却没把底部手势条高度算进去：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `受管页面必须走页面主题桥`() {
        // 两个壳用的是无参 MiuixTheme{ }（配色恒亮），页面侧必须自己兜住深色，
        // 否则深色下卡片是白的、正文也取白 → 内容不可读。
        // about 三页共用骨架，所以只要求 PagesCommon 里有；
        // 其余 5 页各自包一层。
        //
        // 判据只认组件名出现，不钉调用写法（`QingyuPageTheme { … }` 与
        // `QingyuPageTheme(content = …)` 都算），避免守卫变成格式警察。
        assertTrue(
            "about/PagesCommon.kt 没有包 QingyuPageTheme，关于域三页在深色下会白字白底",
            "QingyuPageTheme" in read("about/PagesCommon.kt"),
        )
        val standalone = listOf(
            "schedule/AddScheduleItemPage.kt",
            "schedule/ScheduleDateRulePage.kt",
            "schedule/ScheduleListPage.kt",
            "task/AddTaskPage.kt",
            "task/TaskListPage.kt",
        )
        val offenders = standalone.filter { "QingyuPageTheme" !in read(it) }
        assertTrue(
            "以下页面没有包 QingyuPageTheme（深色下白字白底）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }
}
