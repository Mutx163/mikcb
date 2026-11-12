package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日视图展开层的**卡顿修复接线守卫**（2026-11-03 建，2026-11-05 补时序断言）。
 *
 * ## 它防的是哪一类事故
 *
 * 这几条都是「代码仍然编得过、页面也照常打开，但卡顿修复静默失效」的改动：
 * 1. 展开层不再复用首页宿主已解析的设置模型 ⇒ 展开首帧又要把整份
 *    `timetable_settings` JSON 解析一遍（MiniJson + 80+ 键 fromJson）；
 * 2. `DayViewPage` 的装配结果不再按 `dataVersion` 缓存 ⇒ 1Hz 心跳会每秒
 *    重跑整页装配（全量课程过滤 + 冲突表 + 日程/考试/任务扫描）；
 * 3. 展开层隐藏时没关掉绘制与命中 ⇒ 看不见的日视图把周视图的点击吞掉；
 * 4. **（2026-11-05 方案 1）打开日视图不再「先挂树 → 等首组合完成 → 再启动下推动画」**
 *    ⇒ 首组合 / 首测量又和动画第一帧挤在同一帧，「周 → 日开头一顿」回来。
 *
 * 第 4 条的现实教训：2026-11-04 的 `417db2569` 把「收起后保活」悄悄改成「收起即卸载」，
 * 而当时的守卫只断言 `dayMounted = dayVisible || dayLayerReady` 这行字在不在 ——
 * 归假那行它看不见，于是守卫一直是绿的（咬不住任何东西）。现在改成断言**时序结构**：
 * 启动 `dayExpand` 的 effect 必须挂在「首组合完成」信号上，且这个信号只能来自真正组合了
 * `dayContent` 的那两支（横滑支 / 上下翻支）；任何一个分支漏挂，那条路会一直卡在
 * 「等首组合」——`dayExpand` 停在 0 但 `dayVisible` 已为真，命中层一直吃事件，页面点不动。
 *
 * ## 为什么读源码文本
 *
 * 这些事都写在 Compose 调用与修饰器链里，反射与编译产物都不保留；
 * 与 `DayViewWiringGuardTest` / `DockPagerWiringGuardTest` 同一套做法。
 * 判据只看结构与顺序（花括号 / 圆括号配对后取块、比较下标），不依赖缩进与折行。
 */
class DayViewOverlayPerfWiringGuardTest {

    @Test
    fun `展开层必须复用宿主已解析的设置模型`() {
        val shell = readSource(ShellPageIndex)
        val wiring = readSource(ShellWiring)

        assertTrue(
            "`DayViewOverlayBinding` 没有 `settingsModel` 字段——展开层拿不到宿主那份模型，",
            "val settingsModel: TimetableSettingsModel? = null" in shell,
        )
        assertTrue(
            "`c3.day` 没有优先使用 `dayOverlay?.settingsModel`——会在展开首帧重复解析整份设置。",
            "dayOverlay?.settingsModel" in shell,
        )
        assertTrue(
            "`ShellWiring` 构造展开层时没有传 `settingsModel = settingsModel`——参数断了，日视图又会自己 load()。",
            // 必须看 `DayViewOverlayBinding(...)` **这个调用块**：同一个文件里
            // `TimetableHost(settingsModel = settingsModel, …)` 也有同样的字样，
            // 全文 contains 会在参数被删掉时仍然通过（已用咬合探针验过）。
            "settingsModel = settingsModel" in callBlock(wiring, "DayViewOverlayBinding("),
        )
    }

    @Test
    fun `日视图装配必须带数据版本`() {
        val shell = readSource(ShellPageIndex)
        val day = readSource(DayViewPage)

        assertTrue(
            "`DayViewPage` 没有 `dataVersion` 参数——装配结果无法按仓储变化失效。",
            "dataVersion: Any? = null" in day,
        )
        assertTrue(
            "`DayViewPage` 的 `dataProvider` 没有按「周次 + 星期 + dataVersion」缓存——1Hz 心跳会每秒重装配。",
            "remember(target.week, target.dayOfWeek, dataVersion)" in day,
        )
        assertTrue(
            "`c3.day` 调用 `DayViewPage` 时没有传包含 `snapshot` 的 `dataVersion`——仓储变了日视图不会跟着变。",
            // 2026-11-08 加宽：c3.day 现在传 `Triple(snapshot, coupleOverlayRevision, weatherTick)`
            // ——snapshot 仍在版本表达式里（且额外挂情侣叠加层与天气刻度），字面比对要认它，
            // 否则会为了过守卫把 weatherTick 拆回去，天气会退化成「今天以后无天气」。
            shell.contains("dataVersion = snapshot") || shell.contains("Triple(snapshot,"),
        )
    }

    @Test
    fun `展开层隐藏时不绘制不命中且收起只在落定后卸载`() {
        val week = readSource(TimetableWeekPage)

        assertTrue(
            "`TimetableWeekPage` 没有 `dayMounted = dayVisible || dayLayerReady`——收起后又把整棵树卸载了。",
            "val dayMounted = dayVisible || dayLayerReady" in week,
        )
        // 2141 简单面板改版（2026-11-04）：不再用 drawWithContent 裁切，隐藏靠
        // ① 组合门 `if (!monthVisible && dayMounted && dayContent != null)`（月视图接管时
        // 日层不组合）；② 面板 alpha=panelAlpha（收起 progress=0 → easeOutCubic(0)=0，透明）；
        // ③ 命中层按 `if (dayVisible)` 门控 pointerInput。
        assertTrue(
            "展开层没有 `if (!monthVisible && dayMounted && dayContent != null)` 组合门——收起且未就绪、或月视图接管时面板仍被组合/绘制。",
            "if (!monthVisible && dayMounted && dayContent != null)" in week,
        )
        assertTrue(
            "隐藏的展开层没有按 `graphicsLayer { alpha = panelAlpha }` 绘制（收起 progress=0 → alpha=0 透明）——隐藏的日视图仍会每帧重画。",
            "graphicsLayer { alpha = panelAlpha }" in week,
        )
        assertTrue(
            "展开层的命中层没有按 `if (dayVisible)` 门控 pointerInput——不绘制时仍抢周视图点击。",
            ("if (dayVisible) {" in week) && ("Modifier.pointerInput(Unit)" in week),
        )

        // ── G1：卸载只允许一处，且必须在收起动画落定（dayExpand.value <= 0）之后 ──
        // 多一处归假 ⇒ 打开/收起中途把整棵树卸掉；少了 dayExpand 那半句 ⇒ 收起动画被打断。
        val unmountCount = occurrences(week, "dayLayerReady = false")
        assertTrue(
            "`dayLayerReady = false` 出现了 $unmountCount 处（应为 1 处）——多出来的那处会在打开或收起中途把整棵树卸掉。",
            unmountCount == 1,
        )
        val unmountIdx = indexOfOrFail(
            week,
            "dayLayerReady = false",
            "找不到 `dayLayerReady = false`——守卫无法验证，按失败处理",
        )
        assertTrue(
            "卸载条件必须带 `!dayMode && dayExpand.value <= 0f`——去掉 `dayExpand.value` 那半句会在收起动画播到一半就卸树。",
            precedingEnclosingHead(week, unmountIdx).contains("if (!dayMode && dayExpand.value <= 0f)"),
        )
        // 收起方向还要把「已组合」清回假，否则下次打开会拿旧值直接开播。
        val clearCount = occurrences(week, "dayContentComposed = false")
        assertTrue(
            "`dayContentComposed = false` 出现了 $clearCount 处（应为 1 处）——不清假，下次打开会拿上一次的旧值直接开播，又变成首组合与首帧抢同一帧。",
            clearCount == 1,
        )
        val clearIdx = indexOfOrFail(
            week,
            "dayContentComposed = false",
            "找不到 `dayContentComposed = false`（收起清假）",
        )
        // 2026-11-05 最终版把清假放进独立的
        // `LaunchedEffect(dayMounted) { if (!dayMounted) dayContentComposed = false }`：
        // 它是计时 effect 的键，在计时 effect 体内写会把自己取消重启，所以必须另立一个 effect。
        val clearHead = week.substring(maxOf(0, clearIdx - 400), clearIdx)
        assertTrue(
            "`dayContentComposed = false` 不在 `!dayMounted` / `!dayMode` 的收起方向附近——在打开方向清假会把信号吃掉，日视图永远等不到首组合完成。",
            clearHead.contains("!dayMounted") || clearHead.contains("!dayMode"),
        )
    }

    /**
     * G2–G8：打开日视图的「先挂载 → 等首组合 → 再启动下推动画」时序。
     *
     * 这套断言对**改前**的代码是红的（`LaunchedEffect(dayMode)` 直接 animateTo、无任何首组合信号），
     * 已在 2026-11-05 用静态脚本对 HEAD 版本预演：G2a/G2b/G3a/G5/G6/G7b 六条同时红。
     * 正式红绿仍以 `:app:testDevDebugUnitTest` 为准。
     */
    @Test
    fun `打开日视图必须先挂载树再启动下推动画`() {
        val week = readSource(TimetableWeekPage)
        val animateIdx = indexOfOrFail(
            week,
            "dayExpand.animateTo(",
            "找不到 `dayExpand.animateTo(`——守卫无法验证，按失败处理",
        )
        val owner = ownerEffectContaining(week, animateIdx)
            ?: throw AssertionError("启动动画的 `dayExpand.animateTo(` 不在任何 `LaunchedEffect` 里")

        // ── G2：启动动画的 effect 必须挂「首组合完成」信号当键 ──
        val keys = owner.keys.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        assertTrue(
            "启动 `dayExpand` 的 `LaunchedEffect` 只有 `dayMode` 一个键（实际键：${owner.keys}）——首组合和动画第一帧又挤同一帧，本次修复被推翻。",
            keys.size >= 2,
        )
        assertTrue(
            "启动 `dayExpand` 的 `LaunchedEffect` 键里没有 `dayContentComposed`（实际键：${owner.keys}）——动画不会等首组合完成。",
            keys.any { it == "dayContentComposed" },
        )

        // ── G4：挂载（dayLayerReady = true）必须先于启动动画 ──
        val readyIdx = indexOfOrFail(
            week,
            "dayLayerReady = true",
            "找不到 `dayLayerReady = true`——树永远不会挂载",
        )
        assertTrue(
            "`dayLayerReady = true` 必须出现在 `dayExpand.animateTo(` 之前——否则动画起步时树还没挂上。",
            readyIdx < animateIdx,
        )
        // G4b：等待那一帧必须**空转**（不做事），且 animateTo 只在「还没到目标值」时才跑。
        // 前者保证等待真的只是等；后者保证收起后清假让 effect 因第二个键再进一次时，
        // value 已等于目标（0→0），不会白跑一趟 animateTo。
        val gateBody = blockBodyAfter(
            owner.block,
            indexOfOrFail(owner.block, "!dayContentComposed", "启动块里找不到「等首组合」门控"),
        )
        assertTrue(
            "gate（等首组合）那一支里不该有 `animateTo(` / `snapTo(`——等待帧必须空转，否则等于没等。",
            !gateBody.contains("animateTo(") && !gateBody.contains("snapTo("),
        )
        val shortCircuitIdx = owner.block.indexOf("else if (dayExpand.value != expandTarget)")
        assertTrue(
            "animateTo 没有「已经在目标值就跳过」的短路（`else if (dayExpand.value != expandTarget)`）——清假让 effect 重进时会白跑一趟 animateTo(0→0)。",
            shortCircuitIdx >= 0 && shortCircuitIdx < owner.block.indexOf("dayExpand.animateTo("),
        )

        // ── G3：信号必须来自真正组合了 dayContent 的挂载块 ──
        val mounted = mountedBlockBody(week)
        // 注意：`SideEffect` 在顶层 helper `DayContentMountSignal` 的定义里，挂载块内**看不到**它；
        // 这里咬的是「调用形式」——`DayContentMountSignal { dayContentComposed = true }`。
        assertTrue(
            "挂载块里没有 `DayContentMountSignal { dayContentComposed = true }`——信号不在真组合点，属假两步（动画照旧和首组合同帧）。",
            mounted.contains("DayContentMountSignal { dayContentComposed = true }"),
        )
        assertTrue(
            "挂载块里找不到 `dayContent(` 调用——信号没有落在真组合点上。",
            mounted.contains("dayContent("),
        )

        // ── G5：snap 分支（减动画 / 底栏来源）必须留在门控之前，当帧落定 ──
        val snapIdx = owner.block.indexOf("dayExpand.snapTo(")
        val gateIdx = owner.block.indexOf("!dayContentComposed")
        assertTrue(
            "启动块里找不到 `dayExpand.snapTo(`——底栏/减动画的当帧落定分支被删了？",
            snapIdx >= 0,
        )
        assertTrue(
            "启动块里找不到 `!dayContentComposed` 门控——「先挂树等首组合」被删了。",
            gateIdx >= 0,
        )
        assertTrue(
            "`dayExpand.snapTo(` 必须在「等首组合」门控之前——否则底栏切日会先空一帧再落定。",
            snapIdx < gateIdx,
        )

        // ── G6：门控只拦打开方向（条件里带 dayMode），否则收起永远播不完 ──
        val gateLine = owner.block.lines().first { it.contains("!dayContentComposed") }
        assertTrue(
            "门控条件必须带 `dayMode`（现在是：${gateLine.trim()}）——否则收起方向也被拦，日视图永远关不掉。",
            gateLine.contains("dayMode"),
        )

        // ── G7：横滑支 / 上下翻支两个 dayContent(...) 都必须各有信号 ──
        // 只挂一条：另一条路（底栏「周/日」互点走横滑支）永远等不到首组合 →
        // dayExpand 停在 0 而 dayVisible 已为真 → 命中层一直吃事件，页面点不动。
        val callNeedle = "dayContent(0.dp, Modifier)"
        val callIndices = indicesOf(week, callNeedle)
        assertEquals(
            "期望两个 `$callNeedle` 调用（横滑支 + 上下翻支），实际 ${callIndices.size} 个。",
            2,
            callIndices.size,
        )
        callIndices.forEachIndexed { i, idx ->
            assertTrue(
                "第 ${i + 1} 个 `dayContent(...)` 分支里没有 `dayContentComposed = true`——那条路会一直卡在「等首组合」，dayExpand 停在 0 而 dayVisible 已为真，命中层一直吃事件，页面点不动。",
                enclosingBlockText(week, idx).contains("dayContentComposed = true"),
            )
        }

        // ── G8：信号必须由 effect 作用域写，不能在组合期裸写；包装件必须真有定义 ──
        val writeIndices = indicesOf(week, "dayContentComposed = true")
        assertEquals(
            "`dayContentComposed = true` 应恰好两处（两支各一），实际 ${writeIndices.size} 处。",
            2,
            writeIndices.size,
        )
        writeIndices.forEach { idx ->
            val line = lineAt(week, idx)
            val head = precedingEnclosingHead(week, idx)
            assertTrue(
                "`dayContentComposed = true` 写在组合期（行：${line.trim()}）——组合期写状态会多一轮重组，必须放进 `LaunchedEffect(Unit)` / `SideEffect`（或 `DayContentMountSignal` 这类 effect 包装）。",
                line.contains("DayContentMountSignal {") ||
                    head.contains("SideEffect {") ||
                    head.contains("LaunchedEffect(Unit)"),
            )
        }
        if (occurrences(week, "DayContentMountSignal {") > 0) {
            val defIdx = indexOfOrFail(
                week,
                "fun DayContentMountSignal(",
                "用了 `DayContentMountSignal { … }` 却没定义 `fun DayContentMountSignal(`——文件编不过，首组合信号永远不触发。",
            )
            val defBody = blockBodyAfter(week, defIdx)
            assertTrue(
                "`DayContentMountSignal` 的定义里没有 `SideEffect { … }` / `LaunchedEffect(Unit) { … }`——它若在组合期直接调 lambda，就是组合期写状态。",
                defBody.contains("SideEffect(") || defBody.contains("LaunchedEffect(Unit)"),
            )
        }
    }

    // ------------------------------------------------------------------ 工具

    /**
     * 取 `name(` 起到配对右括号为止的调用块（含嵌套括号）。
     *
     * 防止「同一个文件里别处也有同样字样」让判据变成假阳性：参数被删掉时，
     * 只要别处还写着同样的实参，全文 contains 仍然会绿。
     */
    private fun callBlock(source: String, callHead: String): String {
        val start = source.indexOf(callHead)
        if (start < 0) throw AssertionError("找不到 $callHead —— 守卫无法验证，按失败处理")
        var depth = 0
        val sb = StringBuilder()
        var index = source.indexOf('(', start)
        while (index < source.length) {
            val ch = source[index]
            if (ch == '(') depth++
            if (ch == ')') {
                depth--
                if (depth == 0) break
            }
            sb.append(ch)
            index++
        }
        return sb.toString()
    }

    private data class OwnerEffect(val keys: String, val block: String)

    /** 找到包含 [needle] 下标的那一个 `LaunchedEffect(...) { … }`，返回它的键串与块体。 */
    private fun ownerEffectContaining(source: String, needle: Int): OwnerEffect? {
        var from = 0
        while (true) {
            val open = source.indexOf("LaunchedEffect(", from)
            if (open < 0) return null
            val parenOpen = source.indexOf('(', open)
            val parenClose = matchingParen(source, parenOpen)
            if (parenClose > 0) {
                val keys = source.substring(parenOpen + 1, parenClose).trim()
                val brace = source.indexOf('{', parenClose)
                if (brace >= 0) {
                    val end = matchingBrace(source, brace)
                    if (end > 0 && needle > brace && needle < end) {
                        return OwnerEffect(keys, source.substring(brace + 1, end))
                    }
                }
            }
            from = open + 1
        }
    }

    /** `if (!monthVisible && dayMounted && dayContent != null) { … }` 的块体。 */
    private fun mountedBlockBody(source: String): String {
        val head = source.indexOf("if (!monthVisible && dayMounted && dayContent != null)")
        if (head < 0) throw AssertionError("找不到挂载块 `if (!monthVisible && dayMounted && dayContent != null)`")
        return blockBodyAfter(source, head)
    }

    /** 从 [fromIndex] 起第一个 `{` 到其配对 `}` 之间的块体。 */
    private fun blockBodyAfter(source: String, fromIndex: Int): String {
        val open = source.indexOf('{', fromIndex)
        if (open < 0) throw AssertionError("从下标 $fromIndex 起找不到 `{`")
        val end = matchingBrace(source, open)
        if (end < 0) throw AssertionError("花括号不配对")
        return source.substring(open + 1, end)
    }

    /** 包住 [index] 的最内层 `{ … }` 块（含两端花括号）。 */
    private fun enclosingBlockText(source: String, index: Int): String {
        val depths = depthAt(source)
        val open = enclosingBraceIndex(source, index, depths)
        if (open < 0) throw AssertionError("找不到下标 $index 处的外层块")
        val end = matchingBrace(source, open)
        if (end < 0) throw AssertionError("花括号不配对")
        return source.substring(open, end + 1)
    }

    /** [index] 所在最内层块的开头（含条件）到 [index] 之间的文本，用来断言 `if (...)` 条件。 */
    private fun precedingEnclosingHead(source: String, index: Int, chars: Int = 240): String {
        val depths = depthAt(source)
        val open = enclosingBraceIndex(source, index, depths)
        val from = if (open < 0) maxOf(0, index - chars) else maxOf(0, open - chars)
        return source.substring(from, index)
    }

    /** `depth[i]` = 处理第 i 个字符之前的 `{`/`}` 净深度。 */
    private fun depthAt(source: String): IntArray {
        val depths = IntArray(source.length + 1)
        var d = 0
        for (i in source.indices) {
            depths[i] = d
            when (source[i]) {
                '{' -> d++
                '}' -> d--
            }
        }
        depths[source.length] = d
        return depths
    }

    /** 包住 [index] 的最内层 `{` 的下标。 */
    private fun enclosingBraceIndex(source: String, index: Int, depths: IntArray = depthAt(source)): Int {
        if (index < 0) return -1
        val want = depths[index] - 1
        for (j in index - 1 downTo 0) {
            if (source[j] == '{' && depths[j] == want) return j
        }
        return -1
    }

    private fun matchingBrace(source: String, openIndex: Int): Int {
        if (openIndex < 0) return -1
        var d = 0
        for (i in openIndex until source.length) {
            when (source[i]) {
                '{' -> d++
                '}' -> {
                    d--
                    if (d == 0) return i
                }
            }
        }
        return -1
    }

    private fun matchingParen(source: String, openIndex: Int): Int {
        if (openIndex < 0) return -1
        var d = 0
        for (i in openIndex until source.length) {
            when (source[i]) {
                '(' -> d++
                ')' -> {
                    d--
                    if (d == 0) return i
                }
            }
        }
        return -1
    }

    private fun occurrences(source: String, needle: String): Int {
        var count = 0
        var from = 0
        while (true) {
            val i = source.indexOf(needle, from)
            if (i < 0) return count
            count++
            from = i + 1
        }
    }

    private fun indicesOf(source: String, needle: String): List<Int> {
        val out = ArrayList<Int>()
        var from = 0
        while (true) {
            val i = source.indexOf(needle, from)
            if (i < 0) return out
            out.add(i)
            from = i + 1
        }
    }

    private fun indexOfOrFail(source: String, needle: String, why: String): Int {
        val i = source.indexOf(needle)
        if (i < 0) throw AssertionError(why)
        return i
    }

    private fun lineAt(source: String, index: Int): String {
        if (index < 0) return ""
        val start = source.lastIndexOf('\n', index).let { if (it < 0) 0 else it + 1 }
        val end = source.indexOf('\n', index).let { if (it < 0) source.length else it }
        return source.substring(start, end)
    }

    /**
     * 读生产源码，走**中性化字符串档**（`readKotlinSourceNoStrings`：剥注释 + 字符串内容换空格）。
     *
     * ## 为什么这一档（2026-11-12 B1 批，选档判据留给后来人）
     *
     * 本文件的判据**全部是「调用 / 实参 / effect 键 / 赋值结构在不在」**这类接线型问题：
     * `DayViewOverlayBinding(settingsModel = settingsModel)`、`dayExpand.animateTo(`、
     * `LaunchedEffect` 的键里有 `dayContentComposed`、`dayContentComposed = true` 恰好两处、
     * `HorizontalPager(`/`graphicsLayer { alpha = panelAlpha }`……要的是**代码骨架**，
     * 不是文案。所以字符串内容必须抹掉：否则生产代码里一句日志 / 提示语 / 示例写进
     * 字符串，就能把对应 `contains` 喂饱（假绿）。
     *
     * 反过来说，**这里没有一条判据判「某个字面量许不许出现」**，所以不需要默认档；
     * 一旦以后有人要加这类判据，必须另起一个走 `readKotlinSourceNormalized` 的读法，
     * 不能图省事把这里整档换掉——中性化会把被判的字面量自己擦掉，判据变永绿。
     *
     * 剥注释这一半解决的是另一件事：**注释掉的接线不算接线**。此前这里直接
     * `readText()` 读原文，「把目标行注释掉仍绿」是实测可复现的绕过面。
     */
    private fun readSource(relative: String): String = readKotlinSourceNoStrings(relative)

    private companion object {
        const val ShellPageIndex =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
        const val ShellWiring =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"
        const val DayViewPage =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt"
        const val TimetableWeekPage =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
    }
}
