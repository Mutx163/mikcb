package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 首页「周 ↔ 日」展开转场的形态守卫（2026-11-03，与「减少动画」降级一并建立）。
 *
 * ## 它钉住哪三件事
 *
 * 1. **不自研转场**（仓库铁律 miuix-first）：展开路径的两个源文件（转场宿主
 *    `TimetableWeekPage.kt` + 纯几何 `HomeViewExpandMotion.kt`）不得出现
 *    `AnimatedContent` / `slideIn*` / `fadeIn*`——周↔日是同页模式切换（不是路由，
 *    miuix-nav 无此能力，例外登记见
 *    `docs/reference/miuix-component-first-standard.md` 第 4 条），动画只能走现有
 *    `Animatable` + 窗口几何这一条已批通道。
 * 2. **降级接线在场**：`homeViewExpandReducedMotion` 判据必须同时存在「纯函数定义」
 *    与「渲染层 Android 取值」（`ANIMATOR_DURATION_SCALE`）——删掉任何一半，判据就
 *    静默失效，系统「减少动画」用户又会开始看到逐帧形变。
 * 3. **两个方向都降级**：snap 分支必须吃 `if (dayMode) 1f else 0f` 的双向目标，
 *    而不是只挡展开（收起同样要直接落定）。
 *
 * 沿用仓库源码文本守卫做法（`CourseOverviewSortPopupGuardTest` 同套路）：判据先整篇
 * 剥注释（字符串感知、块注释按 Kotlin 语义可嵌套），注释里提这些名字不影响判定。
 *
 * **代价写清**：文本判据对格式敏感。真把接线改成别的写法时这条会先红——那是**故意的**，
 * 提醒改接线的人同时更新判据，而不是静默失效。
 */
class HomeViewExpandTransitionGuardTest {

    private val weekPageSource: String by lazy {
        stripKotlinComments(readAndroidSource(WEEK_PAGE_PATH))
    }

    private val motionSource: String by lazy {
        stripKotlinComments(readAndroidSource(MOTION_PATH))
    }

    private val flightSource: String by lazy {
        stripKotlinComments(readAndroidSource(FLIGHT_PATH))
    }

    private val flightCardSource: String by lazy {
        stripKotlinComments(readAndroidSource(FLIGHT_CARD_PATH))
    }

    @Test
    fun `展开路径不得出现自研转场 API`() {
        for (source in listOf(weekPageSource, motionSource)) {
            assertFalse(
                "展开路径出现了 AnimatedContent——周↔日是同页模式切换，转场只能走已批的 " +
                    "Animatable + 窗口几何通道（miuix-first 例外登记第 4 条），" +
                    "换自研转场等于把例外范围私自扩大。user.dir=${System.getProperty("user.dir")}",
                FORBIDDEN_ANIMATED_CONTENT.containsMatchIn(source),
            )
            assertFalse(
                "展开路径出现了 slideIn* 自研滑入——禁止（同上）。",
                FORBIDDEN_SLIDE_IN.containsMatchIn(source),
            )
            assertFalse(
                "展开路径出现了 fadeIn* 自研淡入——玻璃卡进半透明层会塌（Dart 真机否过" +
                    "「黑→白」），禁止（同上）。",
                FORBIDDEN_FADE_IN.containsMatchIn(source),
            )
        }
    }

    @Test
    fun `减少动画降级的判据与 Android 取值都必须在场`() {
        assertTrue(
            "HomeViewExpandMotion 里没有 homeViewExpandReducedMotion 纯函数——判据被删，" +
                "系统「减少动画」用户将重新看到逐帧形变（Flutter 口径必须直接落定）。",
            motionSource.contains("fun homeViewExpandReducedMotion("),
        )
        assertTrue(
            "TimetableWeekPage 里没有读 ANIMATOR_DURATION_SCALE——渲染层不再喂系统取值，" +
                "纯函数判据成了空转的死代码。",
            weekPageSource.contains("ANIMATOR_DURATION_SCALE"),
        )
        assertTrue(
            "TimetableWeekPage 里没有调用 homeViewExpandReducedMotion——降级判据没接进转场。",
            weekPageSource.contains("homeViewExpandReducedMotion("),
        )
    }

    @Test
    fun `降级必须覆盖展开与收起两个方向`() {
        assertTrue(
            "snap 目标必须是双向的（if (dayMode) 1f else 0f）——只挡展开不挡收起的话，" +
                "「减少动画」用户收起时还是会看到逐帧形变（Dart expand/collapse 两个分支同判据）。",
            weekPageSource.contains("val expandTarget = if (dayMode) 1f else 0f"),
        )
        assertTrue(
            "降级分支必须用 snapTo(expandTarget) 直接落定——snap 后 value 恰为端点，" +
                "落定判据（dayVisible + value < 0.999f 才画周网格）当帧成立，无中间帧。",
            weekPageSource.contains("dayExpand.snapTo(expandTarget)"),
        )
    }

    @Test
    fun `圆角形变必须走统一的纯函数因子`() {
        // 2026-11-03 起窗口是圆角形变（替换直角 clipRect）。圆角收束只有
        // homeViewExpandCornerRadiusFactor 这一份（28dp 种子 + 0.002 收尾带，出处见其
        // KDoc）；渲染层直接写死半径或另立公式都会让「贴边前圆角消失」的旧病复发。
        assertTrue(
            "HomeViewExpandMotion 里没有 homeViewExpandCornerRadiusFactor 纯函数——" +
                "圆角收束判据被删。",
            motionSource.contains("fun homeViewExpandCornerRadiusFactor("),
        )
        assertTrue(
            "TimetableWeekPage 没有调用 homeViewExpandCornerRadiusFactor——圆角窗口没接判据，" +
                "等于退回直角擦除或自造半径。",
            weekPageSource.contains("homeViewExpandCornerRadiusFactor("),
        )
    }

    // ------------------------------------------------------------------
    // 卡顿守卫（2026-11-03）：绘制期读进度 ⇒ 内容层必须有恒定缓存图层
    // ------------------------------------------------------------------

    /**
     * 两层内容的绘制命令不得每帧重录。
     *
     * 展开/收起期间，周网格与日视图各自的 draw 块**逐帧**执行（进度只能在绘制阶段读）。
     * 子树若没有自己的图层，整棵绘制命令会被并进外层 DisplayList、每帧重录一遍——
     * 这就是用户报的「日↔周那一下卡」。修法是给两层内容各挂一个 `graphicsLayer`，
     * 配置**恒定**（不读进度）：内容录一次后复用，动画帧只换外层裁切。
     */
    @Test
    fun `两处内容层必须各挂一个配置恒定的缓存图层`() {
        val blocks = graphicsLayerBlocks(weekPageSource)
        assertTrue(
            "只找到 ${blocks.size} 处 graphicsLayer——周网格页与日视图内容两层都要挂，" +
                "少一层就退化回「每帧重录整层」。",
            blocks.size >= 2,
        )
        for (block in blocks) {
            assertFalse(
                "缓存图层的配置里出现了 dayExpand——配置随进度变化会让图层逐帧失效，" +
                    "缓存等于没挂。恒定配置只能写常量（如 alpha = 1f）。block=$block",
                block.contains("dayExpand"),
            )
            assertFalse(
                "缓存图层的配置里出现了 progress 之类的动画取值——同上，图层会逐帧失效。block=$block",
                block.contains("progress"),
            )
            assertFalse(
                "缓存图层的配置里出现了 homeViewExpand 几何——几何只能留在 draw 阶段。block=$block",
                block.contains("homeViewExpand"),
            )
        }
        assertTrue(
            "缓存图层的配置里找不到任何恒定属性（alpha = 1f）——空配置挡不住后续有人把" +
                "动画值接进来，判据要能咬住这条线。",
            blocks.any { it.contains("alpha = 1f") },
        )
    }

    /** 裁切 Path 必须 `remember` 一份、逐帧 `rewind()` 复用；逐帧 new 等于每帧分配。 */
    @Test
    fun `裁切 Path 必须复用而不是逐帧新建`() {
        assertTrue(
            "找不到 `remember { Path() }`——裁切路径改为逐帧新建，动画期每帧都会分配新 Path。",
            weekPageSource.contains("remember { Path() }"),
        )
        assertTrue(
            "找不到 `expandWindowClip.rewind()`——Path 没有复用回收，逐帧新建退回旧病。",
            weekPageSource.contains("expandWindowClip.rewind()"),
        )
        val allocations = Regex("""Path\(\)""").findAll(weekPageSource).count()
        assertTrue(
            "`Path()` 出现了 $allocations 次（应恰为 1 次，在 remember 里）——多于 1 次说明" +
                "有人在绘制路径上新建 Path。",
            allocations == 1,
        )
    }

    // ------------------------------------------------------------------
    // 摘要卡飞行守卫（2026-11-03，阶段 A）
    //
    // 用户口径「还是很恶心的展开效果」：只做圆角窗口裁切 = 一块窗口从选中列擦开。
    // Flutter 最新那套的主体是**卡片自己从格位飞到落点**。这组判据钉住「飞行这一刀
    // 不能退回纯裁切」，也钉住「落点/起点不许写死比例」。
    // ------------------------------------------------------------------

    @Test
    fun `摘要卡飞行必须调用纯几何与节奏函数`() {
        assertTrue(
            "摘要卡飞行的插值/圆角/文案节奏必须在 HomeViewExpandFlight 的纯函数里——" +
                "渲染层自己算，单测就钉不住「t=0 在格位、t=1 在卡位」。",
            flightSource.contains("fun homeViewSummaryFlightRect(") &&
                flightSource.contains("fun homeViewSummaryStartCell(") &&
                flightSource.contains("fun homeViewSummaryFlightCornerDp("),
        )
        assertTrue(
            "飞行卡没有调用 homeViewSummaryFlightRect——它自己在拼矩形，" +
                "等于绕开了上一条判据。",
            flightCardSource.contains("homeViewSummaryFlightRect("),
        )
        assertTrue(
            "飞行卡没有调用 homeViewSummaryFlightCornerDp——圆角另算了。",
            flightCardSource.contains("homeViewSummaryFlightCornerDp("),
        )
        assertFalse(
            "飞行卡里出现了自己的 lerp——插值公式只能有一份（HomeViewExpandFlight）。",
            flightCardSource.contains("private fun lerp") ||
                Regex("""\blerp\(""").containsMatchIn(flightCardSource),
        )
    }

    @Test
    fun `飞行起点与终点必须来自实测`() {
        assertTrue(
            "周视图页没有调用 homeViewSummaryStartCell——起点没按星期栏实测换算。",
            weekPageSource.contains("homeViewSummaryStartCell("),
        )
        assertTrue(
            "周视图页没有量星期栏（flightHeaderBounds）——起点会变成写死常量。",
            weekPageSource.contains("flightHeaderBounds"),
        )
        assertTrue(
            "周视图页没有量真摘要卡（flightSummaryBounds）——终点必须实测，" +
                "卡片高度随考试/进行中/冲突变化，算不出来。",
            weekPageSource.contains("flightSummaryBounds"),
        )
        assertTrue(
            "周视图页没有把测量值换算到内容区局部坐标（positionInRoot）——" +
                "起点与终点会落在不同的坐标系里，飞行轨迹整体偏移。",
            weekPageSource.contains("positionInRoot()"),
        )
    }

    @Test
    fun `真摘要卡在飞行期间必须在绘制阶段隐藏`() {
        assertTrue(
            "找不到 `dayVisible && dayExpand.value < 0.999f` 的绘制守卫——" +
                "真摘要卡会从起点一路被窗口裁到终点，读起来还是擦除。",
            weekPageSource.contains("dayVisible && dayExpand.value < 0.999f"),
        )
        assertTrue(
            "摘要卡的隐藏修饰器没有挂在 drawWithContent 里——在组合阶段读进度会逐帧重组整棵页面。",
            weekPageSource.contains("summaryFlightModifier") &&
                weekPageSource.contains(".drawWithContent {"),
        )
        assertTrue(
            "dayContent 没收到 summaryFlightModifier——壳拿不到测量/隐藏修饰器，" +
                "飞行终点量不到、真卡也会和飞行卡一起画出来。",
            weekPageSource.contains("dayContent(0.dp, summaryFlightModifier)"),
        )
    }

    @Test
    fun `飞行层必须是裁切盒子的兄弟且排在它之后`() {
        val dayContentIndex = weekPageSource.indexOf("dayContent(0.dp, summaryFlightModifier)")
        val flightLayerIndex = weekPageSource.indexOf("DayViewSummaryFlightLayer(")
        assertTrue(
            "找不到 DayViewSummaryFlightLayer 调用——飞行层被删了（退回纯窗口擦除）。",
            flightLayerIndex >= 0,
        )
        assertTrue(
            "飞行层排在 dayContent 之前——它会被裁切盒子盖住；" +
                "起点在星期栏里（内容区局部 y 为负），必须作为裁切盒子的兄弟、排在它后面才画得上去。",
            flightLayerIndex > dayContentIndex,
        )
        assertTrue(
            "飞行层没有 matchParentSize——它的坐标系必须和内容区一致（起点/终点都按内容区局部坐标算）。",
            weekPageSource.contains("DayViewSummaryFlightLayer(") &&
                weekPageSource.substring(flightLayerIndex).contains("Modifier.matchParentSize()"),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具（与 CourseOverviewSortPopupGuardTest 同一套路）
    // ------------------------------------------------------------------

    /**
     * 抽出所有 `graphicsLayer { … }` 的花括号块（按大括号配平到闭合处）。
     * 只看 lambda 里写了什么，位置由计数断言另判。
     */
    private fun graphicsLayerBlocks(source: String): List<String> {
        val blocks = mutableListOf<String>()
        // 只认**同一行的调用**（`graphicsLayer {`）：`import …graphicsLayer` 这种也含这个词，
        // 但 import 行后面没有花括号，跨行匹配会把它误算成一个调用点。
        val callPattern = Regex("""graphicsLayer[ \t]*\{""")
        for (match in callPattern.findAll(source)) {
            val open = match.range.last
            var depth = 0
            var i = open
            while (i < source.length) {
                when (source[i]) {
                    '{' -> depth++
                    '}' -> {
                        depth--
                        if (depth == 0) break
                    }
                }
                i++
            }
            blocks += source.substring(open, minOf(i + 1, source.length))
        }
        return blocks
    }

    /**
     * 剥掉 `//` 与 `/* */`（块注释按 Kotlin 语义**可嵌套**），字符串字面量感知
     * （`"https://…"` 里的 `//` 不算注释）；块注释里的换行保留。
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

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        val FORBIDDEN_ANIMATED_CONTENT = Regex("""\bAnimatedContent\b""")
        val FORBIDDEN_SLIDE_IN = Regex("""\bslideIn""")
        val FORBIDDEN_FADE_IN = Regex("""\bfadeIn""")

        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val MOTION_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/HomeViewExpandMotion.kt"
        const val FLIGHT_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/HomeViewExpandFlight.kt"
        const val FLIGHT_CARD_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewSummaryFlight.kt"
    }
}
