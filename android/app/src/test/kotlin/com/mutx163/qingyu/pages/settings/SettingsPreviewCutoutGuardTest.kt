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
     * 2026-11-08 用户口径（实报「进页看不到星期栏、第一行是第 5 节」）：预览要像首页——
     * **星期栏钉在窗口顶部、只有网格上下滑**，不再是「整页当一条长纸带滚」。
     *
     * 钉住预览槽的形态：`fitToBox = true`（窗口多大内容就多大，不缩放、不自带长条滚动）、
     * `contentHeight = maxHeight`、`isolateGestures = false`（手势放给网格）、
     * `previewSectionBasisDp = homeGridHeightDp`（行高仍按首页算）、`cornerRadius = 0.dp`、
     * `previewMode = true`（不画状态栏/顶栏、星期栏当首行）。
     * 改回长条滚动（fitToBox = false / contentHeight = 自然高）、圆角、或节高不再按首页基准都会红。
     */
    @Test
    fun `两页预览槽星期栏钉住只有网格滚且无圆角`() {
        val shell = codeOf(sourceOf("main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"))
        assertEquals(
            "预览槽必须 fitToBox = true（内容按窗口尺寸排版，星期栏才能钉在顶上）",
            1,
            Regex("fitToBox = true").findAll(shell).count(),
        )
        assertEquals(
            "预览槽 contentWidth 必须取窗口宽（=maxWidth，scale 恒 1、整像素不缩放）",
            1,
            Regex("contentWidth = maxWidth").findAll(shell).count(),
        )
        assertEquals(
            "预览槽 contentHeight 必须取窗口高（内容按框排版、星期栏钉在顶上），" +
                "不再把整页当一条长纸带",
            1,
            Regex("contentHeight = maxHeight").findAll(shell).count(),
        )
        assertEquals(
            "旧写法「contentHeight = 整屏高 / 自然长条」必须删净",
            0,
            Regex("contentHeight = configuration\\.screenHeightDp\\.dp").findAll(shell).count(),
        )
        assertEquals(
            "旧写法「contentHeight = 自然长条」必须删净（长条滚会把星期栏顶出窗口）",
            0,
            Regex("contentHeight = contentHeightDp\\.dp").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须把「首页网格可用高」当节高基准传下去（previewSectionBasisDp）——" +
                "不然自动充满会在 4 行高的窗口里把 12 节压成 27dp 一行",
            1,
            Regex("previewSectionBasisDp = homeGridHeightDp").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须用 WeekdayHeaderMetrics.HEIGHT_DP 当星期栏高（首页网格可用高要扣掉它）",
            1,
            Regex("WeekdayHeaderMetrics\\.HEIGHT_DP").findAll(shell).count(),
        )
        assertEquals(
            "预览槽必须 isolateGestures = false（手势放给网格，框内上下滑才能滚）",
            1,
            Regex("isolateGestures = false").findAll(shell).count(),
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
     * 4. 「回本周」浮钮在预览里**不画**（2026-11-08 用户口径；此前 2026-11-07 为让浮钮不透明度滑杆
     *    有可看目标而显过，现按用户口径收回）。
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
            "预览里**不画**「回本周」浮钮（2026-11-08 用户口径：「这个页面不要显示」）：" +
                "它只写一个字「今」，存储周不是真实本周时会永久亮在预览框里，而预览不可点",
            Regex("""visible\s*=\s*!previewMode\s*&&\s*showBackToCurrentWeek\s*&&\s*!dayVisible""")
                .containsMatchIn(page),
        )
        assertTrue(
            "预览分支要把壳给的首页节高基准转给 WeekPageContent（sectionHeightBasisDp）——" +
                "4 行高的窗口里按自己盒子算会把 12 节压扁",
            page.contains("sectionHeightBasisDp = previewSectionBasisDp"),
        )
        assertTrue(
            "预览里点击必须就地失效（手势已放给网格，不能再靠挖洞件吃手势）：" +
                "星期栏的点击要由 previewMode 分支挡掉（允许与 monthMode 合在同一个 when 分支）",
            Regex("""\bpreviewMode\b[^\n]*->\s*Unit""").containsMatchIn(page),
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
