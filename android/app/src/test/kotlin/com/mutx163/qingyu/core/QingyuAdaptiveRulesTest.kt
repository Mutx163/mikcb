package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 宽屏三档判据（[QingyuAdaptiveRules]）单测 + 骨架接线守卫（2026-11-03 宽屏第一批）。
 *
 * 判据是纯数学，直接行为断言；骨架接线（composeP1）进不了 JVM classpath，
 * 按 `TopBarProgressiveBlurGuardTest` 同一套路用源码文本守卫钉「必须出现的最小集合」。
 * 判据出处：官方 demo `utils/AdaptiveUtils.kt:12-21` 与
 * `docs/plans/2026-11-03-compose-widescreen-adaptive-plan.md`（三档表 + 640dp 推荐值）。
 *
 * ## 咬合探针（2026-11-03 已做，改判据或接线时必须重做）
 *
 * - 把 [QingyuAdaptiveRules.WIDE_MIN_WIDTH_DP] 的 840f 临时改成 8400f →
 *   `宽屏边界` 与 `平板竖屏` 两条必须红（实测红）；
 * - 把 QingyuPageScaffold.kt 里 `?: adaptive.maxContentWidth` 临时改成不回退 →
 *   `骨架接线` 一条必须红（实测红；该探针不破坏编译，不影响并行会话的 L1）。
 */
class QingyuAdaptiveRulesTest {

    @Test
    fun `手机竖屏窗口永远是紧凑档`() {
        // 411x891 是典型手机竖屏；599 宽是紧凑档上界之下。
        assertFalse(QingyuAdaptiveRules.isWideScreen(411f, 891f))
        assertFalse(QingyuAdaptiveRules.isWideScreen(599f, 1200f))
        assertFalse(QingyuAdaptiveRules.shouldLimitContentWidth(411f))
        assertFalse(QingyuAdaptiveRules.shouldLimitContentWidth(599f))
    }

    @Test
    fun `平板竖屏是中宽档 限宽但不切小标题`() {
        // 800x1280：宽 ≥ 600 但高宽比 1.6 > 1.2，不满足宽屏 ⇒ 中宽档。
        assertFalse(QingyuAdaptiveRules.isWideScreen(800f, 1280f))
        assertTrue(QingyuAdaptiveRules.shouldLimitContentWidth(800f))
    }

    @Test
    fun `宽屏边界 840 与横扁窗口`() {
        assertTrue(QingyuAdaptiveRules.isWideScreen(840f, 1280f))
        assertFalse(QingyuAdaptiveRules.isWideScreen(839.9f, 1280f))
        // 700x500 横扁：宽 ≥ 600、高宽比 0.71 < 1.2 ⇒ 宽屏（折叠屏展开 / 桌面分屏形态）。
        assertTrue(QingyuAdaptiveRules.isWideScreen(700f, 500f))
        // 700x900 竖长：高宽比 1.29 ≥ 1.2 ⇒ 中宽。
        assertFalse(QingyuAdaptiveRules.isWideScreen(700f, 900f))
        // 高宽比正好 1.2 不算横扁（判据是严格小于，与 demo 一致）。
        assertFalse(QingyuAdaptiveRules.isWideScreen(600f, 720f))
    }

    @Test
    fun `限宽阈值与 640 推荐值钉死`() {
        assertEquals(600f, QingyuAdaptiveRules.MEDIUM_WIDE_MIN_WIDTH_DP, 0f)
        assertEquals(840f, QingyuAdaptiveRules.WIDE_MIN_WIDTH_DP, 0f)
        assertEquals(1.2f, QingyuAdaptiveRules.WIDE_MAX_HEIGHT_RATIO, 0f)
        assertEquals(640f, QingyuAdaptiveRules.DEFAULT_MAX_CONTENT_WIDTH_DP, 0f)
        assertTrue(QingyuAdaptiveRules.shouldLimitContentWidth(600f))
        assertTrue(QingyuAdaptiveRules.shouldLimitContentWidth(1200f))
    }

    @Test
    fun `宽度为零不炸也不误判`() {
        assertFalse(QingyuAdaptiveRules.isWideScreen(0f, 0f))
        assertFalse(QingyuAdaptiveRules.shouldLimitContentWidth(0f))
    }

    // ───────────── 2026-11-07 第 4 批：短窗口弹层限高 ─────────────

    @Test
    fun `高窗口的弹层限高原样返回`() {
        // 手机竖屏 / 平板竖屏都在 600dp 以上 ⇒ 必须与改造前逐像素一致。
        assertEquals(400f, QingyuAdaptiveRules.sheetMaxHeightDp(800f, 0.5f), 0.01f)
        assertEquals(576f, QingyuAdaptiveRules.sheetMaxHeightDp(800f, 0.72f), 0.01f)
        // 边界：高度正好 600 仍按原比例（不提前放宽）。
        assertEquals(252f, QingyuAdaptiveRules.sheetMaxHeightDp(600f, 0.42f), 0.01f)
    }

    @Test
    fun `矮窗口放宽但给标题与按钮留位置`() {
        // 400dp 高（手机横屏 / 小窗）：0.5 只剩 200，抬到 400-180 = 220。
        assertEquals(220f, QingyuAdaptiveRules.sheetMaxHeightDp(400f, 0.5f), 0.01f)
        // 0.72 原本更大（288）：不能因为放宽反而变小，保持 288。
        assertEquals(288f, QingyuAdaptiveRules.sheetMaxHeightDp(400f, 0.72f), 0.01f)
        // 320dp 高：0.45 → 144，放宽上限 140 比它还小 ⇒ 仍是 144（只放大不缩小）。
        assertEquals(144f, QingyuAdaptiveRules.sheetMaxHeightDp(320f, 0.45f), 0.01f)
        // 500dp 高：0.55 → 275，放宽到 320。
        assertEquals(320f, QingyuAdaptiveRules.sheetMaxHeightDp(500f, 0.55f), 0.01f)
    }

    @Test
    fun `短窗口预留量固定为 180dp 且优先保按钮`() {
        // 官方 DialogContentLayout 在非大屏时高度不设上限，预留不足会裁掉按钮。
        assertEquals(180f, QingyuAdaptiveRules.SHORT_WINDOW_SHEET_RESERVED_DP, 0f)
        // 放宽后恰好剩 180dp 给标题 / 动作行 / 系统栏。
        assertEquals(220f, QingyuAdaptiveRules.sheetMaxHeightDp(400f, 0.5f), 0.01f)
        assertEquals(320f, QingyuAdaptiveRules.sheetMaxHeightDp(500f, 0.55f), 0.01f)
        // 极端矮窗（360dp）原比例已经比「屏高−180」大：保持原值，宁可不放大也不缩小。
        assertEquals(198f, QingyuAdaptiveRules.sheetMaxHeightDp(360f, 0.55f), 0.01f)
    }

    @Test
    fun `短窗口只放大不缩小 也不超过窗口高`() {
        val tiny = QingyuAdaptiveRules.sheetMaxHeightDp(240f, 0.5f)
        assertEquals(120f, tiny, 0.01f)
        listOf(200f, 320f, 480f, 599f).forEach { height ->
            listOf(0.42f, 0.5f, 0.72f).forEach { fraction ->
                val result = QingyuAdaptiveRules.sheetMaxHeightDp(height, fraction)
                assertTrue("${height}dp×$fraction 不得小于原比例", result >= height * fraction - 0.01f)
                assertTrue("${height}dp×$fraction 不得超过窗口高", result <= height)
            }
        }
    }

    @Test
    fun `非法入参返回零 调用方即不额外限高`() {
        assertEquals(0f, QingyuAdaptiveRules.sheetMaxHeightDp(0f, 0.5f), 0f)
        assertEquals(0f, QingyuAdaptiveRules.sheetMaxHeightDp(-10f, 0.5f), 0f)
        assertEquals(0f, QingyuAdaptiveRules.sheetMaxHeightDp(800f, 0f), 0f)
    }

    @Test
    fun `写死上限的弹层在矮窗被夹到可用高度`() {
        // 高窗：原固定值不动（380/420/360 的现有观感不变）。
        assertEquals(380f, QingyuAdaptiveRules.cappedSheetHeightDp(800f, 380f), 0.01f)
        assertEquals(360f, QingyuAdaptiveRules.cappedSheetHeightDp(700f, 360f), 0.01f)
        // 矮窗：夹到屏高 − 180。
        assertEquals(220f, QingyuAdaptiveRules.cappedSheetHeightDp(400f, 380f), 0.01f)
        assertEquals(419f, QingyuAdaptiveRules.cappedSheetHeightDp(599f, 420f), 0.01f)
        // 原本就更小的上限保持不动。
        assertEquals(100f, QingyuAdaptiveRules.cappedSheetHeightDp(400f, 100f), 0.01f)
        // 非法入参：返回原值（导 0 会让 heightIn(max = 0.dp) 直接消失）。
        assertEquals(380f, QingyuAdaptiveRules.cappedSheetHeightDp(0f, 380f), 0.01f)
        assertEquals(0f, QingyuAdaptiveRules.cappedSheetHeightDp(400f, 0f), 0.01f)
    }

    // ───────────── 2026-11-03 第 2 批：Rail 展开阈值与内容区宽 ─────────────

    @Test
    fun `Rail 展开阈值 1200`() {
        assertFalse(QingyuAdaptiveRules.shouldExpandNavigationRail(1199.9f))
        assertTrue(QingyuAdaptiveRules.shouldExpandNavigationRail(1200f))
        assertEquals(1200f, QingyuAdaptiveRules.EXPANDED_RAIL_MIN_WIDTH_DP, 0f)
    }

    @Test
    fun `无 Rail 时内容区取值与窗口宽等价`() {
        // 紧凑档 / 用户关掉导航形态：railWidth = 0，与第 1 批的窗口宽判据完全一致。
        assertEquals(
            QingyuAdaptiveRules.isWideScreen(411f, 891f),
            QingyuAdaptiveRules.contentAreaAdaptive(411f, 891f, 0f).isWideScreen,
        )
        assertEquals(
            QingyuAdaptiveRules.shouldLimitContentWidth(800f),
            QingyuAdaptiveRules.contentAreaAdaptive(800f, 1280f, 0f).limitContentWidth,
        )
    }

    @Test
    fun `Rail 占掉左侧后 页面档位按内容区宽重算`() {
        // 850x1280 平板竖屏：窗口宽 850 ≥ 840 → Rail 出现（收起 80dp）；
        // 内容区 = 770 宽 × 1280 高，高宽比 1.66 > 1.2 → 页面**不是**宽屏档（中宽）。
        // 若错按窗口宽算，页面会误切小顶栏——这正是内容区注入要防的错位。
        val area = QingyuAdaptiveRules.contentAreaAdaptive(850f, 1280f, 80f)
        assertTrue(area.limitContentWidth)
        assertFalse(area.isWideScreen)

        // 1280x800 横扁：Rail 展开态 240dp；内容区 1040 宽 → 仍是宽屏档。
        val wide = QingyuAdaptiveRules.contentAreaAdaptive(1280f, 800f, 240f)
        assertTrue(wide.isWideScreen)
        assertTrue(wide.limitContentWidth)

        // 内容区被 Rail 压到 600 以下（如分屏窄窗 + 展开态 Rail）：限宽退回紧凑档。
        val squeezed = QingyuAdaptiveRules.contentAreaAdaptive(660f, 900f, 240f)
        assertFalse(squeezed.limitContentWidth)
        assertFalse(squeezed.isWideScreen)
    }
}

/**
 * 骨架接线守卫：宽屏分支不许被静默拆掉。
 *
 * QingyuPageScaffold 的宽屏行为全是「静默失败」型：删掉自适应取值、删掉默认限宽回退，
 * 编译照过、手机竖屏看不出任何差别，只有平板/折叠屏宽窗才显形——和当年
 * 「大标题永不收起」同一类病。所以按源码文本钉最小集合，找不到文件按失败处理。
 */
class QingyuAdaptiveWiringGuardTest {

    /** 从当前工作目录向上找仓库根（含 android/app/src），Gradle（android/ 起跑）与 IDE 都能跑。 */
    private fun repoSrcDir(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。工作目录：${System.getProperty("user.dir")}",
        )
    }

    private fun composeSource(relative: String): String {
        val file = File(
            repoSrcDir(),
            "composeP1/kotlin/com/mutx163/qingyu/components/$relative",
        )
        assertTrue("受管源文件不存在：${file.path}", file.isFile)
        return file.readText()
    }

    /** 只留代码：剥掉块注释与行注释，防止 KDoc 里的历史描述把守卫喂假绿/假红。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    @Test
    fun `骨架接线必须消费自适应取值`() {
        val scaffold = codeOnly(composeSource("QingyuPageScaffold.kt"))
        assertTrue(
            "QingyuPageScaffold 不再读取宽屏自适应取值（宽屏行为整体失效）：缺少 rememberQingyuWindowAdaptive()",
            scaffold.contains("rememberQingyuWindowAdaptive()"),
        )
        assertTrue(
            "页面显式 maxContentWidth 之外必须有自适应默认限宽回退（中宽/宽档限宽失效）：缺少 \"?: adaptive.maxContentWidth\"",
            scaffold.contains("?: adaptive.maxContentWidth"),
        )
        assertTrue(
            "宽屏档必须把可折叠大标题换成 SmallTopAppBar（缺少 adaptive.isWideScreen 分支）",
            scaffold.contains("adaptive.isWideScreen"),
        )
        val adaptive = codeOnly(composeSource("QingyuAdaptive.kt"))
        assertTrue(
            "壳层注入 seam（QingyuLocalWindowAdaptive）不许被拆：Rail 批次要靠它在根部注入内容区宽度",
            adaptive.contains("staticCompositionLocalOf<QingyuWindowAdaptive?>"),
        )
    }

    @Test
    fun `列表组件也要消费自适应限宽`() {
        val list = codeOnly(composeSource("QingyuPageList.kt"))
        assertTrue(
            "QingyuPageList 不再读取宽屏自适应取值：手拼 Scaffold 的页面会退回通栏",
            list.contains("rememberQingyuWindowAdaptive()"),
        )
        assertTrue(
            "QingyuPageList 的限宽分支缺少 widthIn(max = cap)",
            list.contains("widthIn(max = cap)"),
        )
    }
}
