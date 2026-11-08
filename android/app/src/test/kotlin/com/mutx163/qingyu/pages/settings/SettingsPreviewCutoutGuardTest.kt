package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.core.PreviewCutoutGeometry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「课程卡片 / 课表页面两页的预览必须走真组件挖洞」的守卫与几何测试
 * （2026-11-03 用户口径：预览要和外观编辑页同一套挖洞，不许重新做样式）。
 *
 * 守两件事：
 *
 * 1. **假样式缩略图不许复活**：旧 `SettingsWeekPreview`（自绘星期栏 + Canvas 网格 +
 *    色块）已删，壳与页面源码不许再引用它；
 * 2. **挖洞实现只有一份共用件**：真实内容 1:1 排版 + 绘制层缩放 + 禁交互拦截
 *    （`consumeAllPointerEvents`）全站只有一份定义、使用面收敛在外观编辑两文件与
 *    共用挖洞件里，不许在页里各写一套。
 *
 * 读源码文本的判据都**先剥注释**（KDoc 里的说明不能算违规，与
 * `AppearanceEditorPreviewLayoutGuardTest` 同一套做法）；找不到文件判失败而不是跳过。
 */
class SettingsPreviewCutoutGuardTest {

    // ── 纯几何（core/PreviewCutoutGeometry）────────────────────────────

    @Test
    fun `缩放比是宽贴合`() {
        assertEquals(0.5f, PreviewCutoutGeometry.scale(windowWidthPx = 200f, contentWidthPx = 400f))
        assertEquals(1f, PreviewCutoutGeometry.scale(windowWidthPx = 400f, contentWidthPx = 400f))
    }

    @Test
    fun `非法输入缩放比退1不按无穷比画没内容`() {
        assertEquals(1f, PreviewCutoutGeometry.scale(0f, 400f))
        assertEquals(1f, PreviewCutoutGeometry.scale(-10f, 400f))
        assertEquals(1f, PreviewCutoutGeometry.scale(400f, 0f))
        assertEquals(1f, PreviewCutoutGeometry.scale(Float.POSITIVE_INFINITY, 400f))
        assertEquals(1f, PreviewCutoutGeometry.scale(400f, Float.NaN))
    }

    @Test
    fun `缩放后内容高决定滚动范围`() {
        assertEquals(
            407f,
            PreviewCutoutGeometry.scaledContentHeight(contentHeightPx = 814f, scale = 0.5f),
        )
        assertEquals(0f, PreviewCutoutGeometry.scaledContentHeight(0f, 0.5f))
        assertEquals(0f, PreviewCutoutGeometry.scaledContentHeight(814f, 0f))
        assertEquals(0f, PreviewCutoutGeometry.scaledContentHeight(Float.POSITIVE_INFINITY, 0.5f))
    }

    // ── 源码守卫 ────────────────────────────────────────────────────────

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
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }

    /** 读相对 `src/` 的源文件；不存在判失败（守卫不许静默跳过）。 */
    private fun sourceOf(relative: String): String {
        val file = File(androidSrc(), relative)
        assertTrue("源文件不存在：$relative（${file.path}）", file.isFile)
        return file.readText()
    }

    /** 去掉块注释与行注释再判（KDoc 里摆的示例/说明不能算违规）。 */
    private fun codeOf(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .replace(Regex("""//[^\n]*"""), "")

    /** 全部 Kotlin 源（main + composeP1）→ 代码文本（已剥注释）。 */
    private fun allKotlinCode(): List<Pair<String, String>> {
        val root = androidSrc()
        val dirs = listOf("main/kotlin", "composeP1/kotlin")
        val result = mutableListOf<Pair<String, String>>()
        dirs.forEach { rel ->
            File(root, rel).walkTopDown()
                .filter { it.isFile && it.name.endsWith(".kt") }
                .forEach { result.add("${rel}/${it.name}" to codeOf(it.readText())) }
        }
        return result
    }

    @Test
    fun `假样式缩略图不许复活`() {
        val dead = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsWeekPreview.kt",
        )
        assertFalse(
            "SettingsWeekPreview.kt 又出现了：预览要走真组件挖洞（QingyuPreviewCutout），" +
                "不许再画自绘缩略图（2026-11-03 用户口径「不许重新做样式」）",
            dead.exists(),
        )
        val shell = codeOf(sourceOf("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"))
        assertFalse(
            "壳里还有对自绘缩略图的代码引用（注释不算）：预览槽必须是真组件挖洞",
            "SettingsWeekPreview" in shell,
        )
    }

    @Test
    fun `两页预览槽接的是真组件挖洞件`() {
        val shell = codeOf(sourceOf("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"))
        assertEquals(
            "壳里应恰好一处使用 QingyuPreviewCutout（预览槽函数内）；多了说明又有人在页里各写一套",
            1,
            Regex("QingyuPreviewCutout\\(").findAll(shell).count(),
        )
        assertEquals(
            "课程卡片与课表页面两页的 preview 槽都应接 SettingsTimetablePreviewSlot（挖洞真预览），" +
                "并传进宿主当前草稿（不跟草稿就要退出重进才变）",
            2,
            Regex("SettingsTimetablePreviewSlot\\(wiring, it\\)").findAll(shell).count(),
        )
    }

    /**
     * 2026-11-04 用户口径：两块设置页预览「和首页同比例 + 框内上下滑 + 完整显示星期栏 + 无圆角」。
     * 钉住预览槽走**静态 1:1 裁窗 + 框内纵向滚动**：`contentWidth = 窗口宽`（scale 恒 1、整像素、
     * 不缩放）、`contentHeight = 真实自然高`（星期栏高 + 节数 × 首页节高；2026-11-04 三修，不再取
     * 整屏高，否则拉到底多出空白）、`fitToBox = false`（走滚动分支而非按框自适应）、
     * `cornerRadius = 0.dp`（方角）、`previewMode = true`（不画状态栏/顶栏、星期栏当首行）、
     * `initialScroll = 0`（初始从顶部/星期栏开始）。
     * 改回 `fitToBox = true`（按框压扁）、圆角、内容高不再按自然高算、或初始滚动非 0 都会红。
     */
    @Test
    fun `两页预览槽走1比1静态裁窗加框内滚动且无圆角`() {
        val shell = codeOf(sourceOf("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"))
        assertEquals(
            "预览槽必须 fitToBox = false（走静态裁窗 + 框内滚动分支，不再按框自适应压扁）",
            1,
            Regex("fitToBox = false").findAll(shell).count(),
        )
        assertEquals(
            "预览槽 contentWidth 必须取窗口宽（=maxWidth，scale 恒 1、整像素不缩放）",
            1,
            Regex("contentWidth = maxWidth").findAll(shell).count(),
        )
        assertEquals(
            "预览槽 contentHeight 必须取真实自然高（contentHeightDp），不再取整屏高——" +
                "否则滚动总高比内容多，拉到底会多出空白",
            1,
            Regex("contentHeight = contentHeightDp\\.dp").findAll(shell).count(),
        )
        assertEquals(
            "旧写法「contentHeight = 整屏高」必须删净（滚动总高比内容多会多出底部空白）",
            0,
            Regex("contentHeight = configuration\\.screenHeightDp\\.dp").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须用 weekSectionHeight 按首页节高算自然高（不强行拉满屏高）",
            1,
            Regex("weekSectionHeight\\(").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须用 WeekdayHeaderMetrics.HEIGHT_DP 当星期栏高参与自然高计算",
            1,
            Regex("WeekdayHeaderMetrics\\.HEIGHT_DP").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须传 initialScroll = 0（初始从顶部/星期栏开始，不沿用上次滚动位）",
            1,
            Regex("initialScroll = 0").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须 cornerRadius = 0.dp（方角，对齐 Flutter 已发布版无圆角）",
            1,
            Regex("cornerRadius = 0\\.dp").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须传 previewMode = true（不画状态栏/顶栏、星期栏当首行）",
            1,
            Regex("previewMode = true").findAll(shell).count(),
        )
    }

    /**
     * 2026-11-07 审读修正：预览必须与首页逐行同比例，且本页能调的视觉项都要有可看的目标。
     *
     * 钉四件事：
     * 1. 自动充满的可用高要扣掉状态栏与首页顶栏（只扣星期栏会让每行比首页高一档）；
     * 2. 天气 provider 必须从壳传进预览（否则课卡天气行永远不出现）；
     * 3. 页面里的预览分支不许再用 `maxHeight / sectionCount` 覆盖节高（双重来源会静默变形）；
     * 4. 「回本周」浮钮在预览里也要可见（本页的浮钮不透明度滑杆才有反馈）。
     */
    @Test
    fun `预览自然高与首页同口径且天气浮钮都接进预览`() {
        val shell = codeOf(sourceOf("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"))
        val slotMarker =
            "private fun SettingsTimetablePreviewSlot(wiring: ShellWiring, settingsModel: TimetableSettingsModel)"
        val slotStart = shell.indexOf(slotMarker)
        assertTrue("找不到预览槽声明：$slotMarker", slotStart >= 0)
        val slot = shell.substring(slotStart).let { rest ->
            val end = rest.indexOf("\nprivate fun ")
            if (end > 0) rest.substring(0, end) else rest
        }

        assertTrue(
            "预览的自动充满可用高必须扣掉状态栏（WindowInsets.statusBars）：" +
                "首页网格盒子的 maxHeight 在状态栏下面",
            slot.contains("WindowInsets.statusBars"),
        )
        assertTrue(
            "预览的自动充满可用高必须扣掉首页顶栏（TimetableTopBarMetrics.HEIGHT）：" +
                "只减星期栏会让预览每行比首页高一档",
            slot.contains("TimetableTopBarMetrics.HEIGHT"),
        )
        assertTrue(
            "预览必须接壳里的天气 provider（weatherProvider = wiring.weather）——" +
                "否则「周课卡显示天气」开着时首页有天气行、预览没有",
            slot.contains("weatherProvider = wiring.weather"),
        )

        val page = codeOf(
            sourceOf("composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"),
        )
        assertEquals(
            "预览分支不许再用 maxHeight / sectionCount 覆盖节高（会静默拉伸行高、掩盖估值偏差）",
            0,
            Regex("""maxHeight\s*/\s*sectionCount""").findAll(page).count(),
        )
        assertEquals(
            "节高只留 weekSectionHeight 一个来源：预览分支不许再传 sectionHeightOverride",
            0,
            Regex("""sectionHeightOverride\s*=""").findAll(page).count(),
        )
        assertTrue(
            "预览里也要画「回本周」浮钮（visible 不能再带 !previewMode）——" +
                "否则本页的浮钮不透明度滑杆永远没有可看的目标",
            Regex("""visible\s*=\s*showBackToCurrentWeek\s*&&\s*!dayVisible""").containsMatchIn(page),
        )
    }

    @Test
    fun `禁交互拦截只有一份实现且使用面收敛在三个文件`() {
        val sources = allKotlinCode()
        val definitionFiles = sources.filter { (_, code) ->
            "fun Modifier.consumeAllPointerEvents()" in code
        }
        assertEquals(
            "consumeAllPointerEvents 必须只有一份定义（AppearanceEditorScreen.kt）；" +
                "定义文件：${definitionFiles.map { it.first }}",
            listOf("composeP1/kotlin/AppearanceEditorScreen.kt"),
            definitionFiles.map { it.first },
        )
        val allow = setOf(
            "composeP1/kotlin/AppearanceEditorScreen.kt",
            "composeP1/kotlin/AppearanceEditorPreviewStage.kt",
            "composeP1/kotlin/QingyuPreviewCutout.kt",
        )
        val users = sources
            .filter { (_, code) -> "consumeAllPointerEvents" in code }
            .map { it.first }
        val offenders = users.filterNot { it in allow }
        assertTrue(
            "consumeAllPointerEvents 出现了允许清单外的使用（挖洞/预览禁交互必须共用同一条拦截，" +
                "不许在页里再写一套）：$offenders",
            offenders.isEmpty(),
        )
    }
}
