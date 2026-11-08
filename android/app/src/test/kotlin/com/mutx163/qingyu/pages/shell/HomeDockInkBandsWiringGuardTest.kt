package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 底栏墨色「亮度带来源」守卫（2026-11-07 冷启动白字修复）。
 *
 * ## 钉什么
 *
 * 1. **壳把带子传给坞**：`PagesShellActivity` 必须把 `homeChrome.bands?.dock` 交给
 *    `HomeGlassDock`；不许注释掉、不许再显式置空。
 * 2. **坞的「有没有壁纸」走快照口径**：`chrome.hasBackdrop`（含文件存在性 / 旧字段解析），
 *    不能用原始路径字段——文件被删时页面按纯色底画，坞却会永久走「未知→白字」。
 * 3. **带子按「路径 + 视口 + 取景」落盘**：缓存键的**插值串**七个字段一个都不能少；
 *    磁盘回读必须在 `return null` 之前；store 的写入必须受 `MAX_ENTRIES` 限制。
 * 4. **三个冷读点都带 store**：页面 chrome、坞、壁纸背景层。
 *
 * 守卫只读源码字符串，所以断言前先 `codeOnly` 去掉注释；键字段断言看插值串（`"$path"`），
 * 不看形参列表——形参在不在与「有没有真的拼进键」是两件事。
 */
class HomeDockInkBandsWiringGuardTest {

    private val composeRoot = "android/app/src/composeP1/kotlin/com/mutx163/qingyu"
    private val mainRoot = "android/app/src/main/kotlin/com/mutx163/qingyu"

    @Test
    fun `壳必须把亮度带传给坞`() {
        val shell = codeOnly(readSource("$mainRoot/pages/PagesShellActivity.kt"))
        val dockCall = callBlock(shell, "HomeGlassDock(")
        assertTrue(
            "壳没把亮度带交给坞（缺 `wallpaperLuminance = rememberHomeBackdropChrome(settingsModel).bands?.dock`）：" +
                "坞在「有壁纸但亮度未知」时按保守白字兜底，亮壁纸下就是白底白字。",
            dockCall.contains(
                "wallpaperLuminance = rememberHomeBackdropChrome(settingsModel).bands?.dock",
            ),
        )
        assertFalse(
            "坞的墨色参数被显式置空：`wallpaperLuminance = null` 会让兜底重新退回首帧白字。",
            dockCall.contains("wallpaperLuminance = null"),
        )
        // 内嵌实色页（任务 / 设置）底下不是壁纸：壳会把带子传进来，渲染层必须按
        // `overWallpaper` 门控，否则实色页会被亮壁纸带误判成浅底。
        val bar = codeOnly(readSource("$composeRoot/pages/shell/GlassDockNavigationBar.kt"))
        assertTrue(
            "`GlassDockNavigationBar` 没按 `overWallpaper` 门控壁纸亮度：实色内嵌页会被亮壁纸带判成浅底。",
            bar.contains("isBlurActive && overWallpaper"),
        )
    }

    @Test
    fun `坞的壁纸存在性必须走快照`() {
        val dock = codeOnly(readSource("$composeRoot/pages/shell/HomeGlassDock.kt"))
        assertTrue(
            "坞的 `hasBackdrop` 没有走快照（缺 `val hasBackdrop = chrome.hasBackdrop`）：" +
                "原始路径字段不查文件存在性，文件被删时会永久走「未知→白字」。",
            dock.contains("val hasBackdrop = chrome.hasBackdrop"),
        )
        assertFalse(
            "坞又用原始路径字段判断有没有壁纸（旧字段 / 已删文件会被误判成有壁纸）。",
            dock.contains("val hasBackdrop = !settingsModel.homePageWallpaperPath"),
        )
        val barCall = callBlock(dock, "GlassDockNavigationBar(")
        assertTrue(
            "坞合并出的 `resolvedWallpaperLuminance` 没有真正传给底栏（判据拿到的仍是 null）。",
            barCall.contains("wallpaperLuminance = resolvedWallpaperLuminance"),
        )
        assertTrue(
            "坞没把快照口径的 `hasWallpaper` 传给底栏判据。",
            barCall.contains("hasWallpaper = hasBackdrop"),
        )
    }

    @Test
    fun `亮度带必须按路径视口取景落盘并回读`() {
        val backdrop = codeOnly(readSource("$composeRoot/pages/shell/HomeWallpaperBackdrop.kt"))
        assertTrue(
            "`cachedWallpaperInkBands` 没有 `store: HomeInkBandsStore?` 参数：落盘没接进冷读路径。",
            backdrop.contains("store: HomeInkBandsStore? = null"),
        )
        assertTrue("冷启动没先读磁盘（缺 `store?.read(key)`）", backdrop.contains("store?.read(key)"))
        assertTrue("同步测量后没写磁盘（缺 `store?.write(key, bands)`）", backdrop.contains("store?.write(key, bands)"))
        assertTrue("异步测量回调后没写磁盘（缺 `inkBandsStore.write(key, bands)`）", backdrop.contains("inkBandsStore.write(key, bands)"))

        // 磁盘回读必须在 `return null` 之前：放到后面时位图未解码会先 return，磁盘永远读不到。
        val cachedFn = memberBlock(backdrop, "fun cachedWallpaperInkBands(")
        val readAt = cachedFn.indexOf("store?.read(key)")
        val bitmapAt = cachedFn.indexOf("wallpaperBitmapCache.get(")
        assertTrue(
            "磁盘回读被放到 `wallpaperBitmapCache.get(...) ?: return null` 之后：冷启动永远读不到磁盘。",
            readAt in 0 until bitmapAt,
        )

        val keyFn = memberBlock(backdrop, "private fun wallpaperInkBandsCacheKey(")
        for (field in listOf(
            "path",
            "decodeWidthPx",
            "viewportWidthPx",
            "viewportHeightPx",
            "scale",
            "alignX",
            "alignY",
        )) {
            assertTrue(
                "亮度带缓存键的**插值串**里缺 `\\$$field`：换壁纸 / 视口 / 取景后会读到别的图的带子。",
                keyFn.contains("$" + field),
            )
        }

        val cachedBranch = backdrop
            .substringAfter("if (cached != null) {")
            .substringBefore("return@LaunchedEffect")
        assertTrue(
            "缓存命中分支没有 bump 版本号：同步量完的带子不会通知坞重组，" +
                "表现就是「必须切到设置再回来才变黑」。",
            cachedBranch.contains("wallpaperInkBandsCacheVersionState.value++"),
        )
        assertTrue(
            "缓存命中分支的 bump 在 `callback(cached)` 之后：坞可能先拿到旧值再被通知。",
            cachedBranch.indexOf("wallpaperInkBandsCacheVersionState.value++") <
                cachedBranch.indexOf("callback(cached)"),
        )

        val store = codeOnly(readSource("$composeRoot/pages/shell/HomeInkBandsStore.kt"))
        assertTrue("持久化 store 没有 prefs 名", store.contains("PREF_NAME"))
        assertTrue(
            "持久化 store 没有真正使用条数上限（`take(MAX_ENTRIES)`）：反复调取景会无限膨胀。",
            store.contains("take(MAX_ENTRIES)"),
        )
        assertTrue("持久化 store 没走统一编码", store.contains("HomeInkBandsCodec"))
        assertTrue(
            "持久化 store 没拒绝「编码后读不回来」的全空带子：索引里会留一条永远读不到的键。",
            store.contains("HomeInkBandsCodec.decode(encoded) == null"),
        )
    }

    @Test
    fun `三个冷读点都必须带 store`() {
        val expectedCalls = mapOf(
            "$composeRoot/app/HomeBackdropChrome.kt" to 1,
            "$composeRoot/pages/shell/HomeGlassDock.kt" to 1,
            "$composeRoot/pages/shell/HomeWallpaperBackdrop.kt" to 2,
        )
        for ((path, expected) in expectedCalls) {
            val source = codeOnly(readSource(path))
            val calls = callBlocks(source, "cachedWallpaperInkBands(")
            assertTrue(
                "$path 只找到 ${calls.size} 处 `cachedWallpaperInkBands(` 调用（预期 $expected）。",
                calls.size >= expected,
            )
            for ((index, call) in calls.withIndex()) {
                assertTrue(
                    "$path 第 ${index + 1} 处调用没传 `store = inkBandsStore`：" +
                        "冷启动回读漏一处，那个读点就还会拿到 null。",
                    call.contains("store = inkBandsStore"),
                )
            }
        }
    }

    @Test
    fun `守卫本身没有空转`() {
        for (path in listOf(
            "$mainRoot/pages/PagesShellActivity.kt",
            "$composeRoot/pages/shell/HomeWallpaperBackdrop.kt",
            "$composeRoot/pages/shell/HomeInkBandsStore.kt",
            "$composeRoot/pages/shell/HomeGlassDock.kt",
        )) {
            val source = readSource(path)
            assertTrue("$path 源码读取太短（${source.length} 字符），路径解析可能坏了", source.length > 1000)
            assertTrue("$path 去掉注释后太短，`codeOnly` 可能吃掉了代码", codeOnly(source).length > 500)
        }
    }

    /** 去掉 `//` 与 `/* */` 注释，保留换行；只用于源码断言，不参与编译。 */
    private fun codeOnly(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var inLine = false
        var inBlock = false
        while (i < source.length) {
            val c = source[i]
            val next = source.getOrNull(i + 1)
            when {
                inLine -> {
                    if (c == '\n') {
                        inLine = false
                        out.append(c)
                    }
                    i++
                }

                inBlock -> {
                    if (c == '*' && next == '/') {
                        inBlock = false
                        i += 2
                    } else {
                        if (c == '\n') out.append('\n')
                        i++
                    }
                }

                c == '/' && next == '/' -> {
                    inLine = true
                    i += 2
                }

                c == '/' && next == '*' -> {
                    inBlock = true
                    i += 2
                }

                else -> {
                    out.append(c)
                    i++
                }
            }
        }
        return out.toString()
    }

    private fun memberBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到 `$marker`，判据失效" }
        var end = source.length
        for (next in listOf("\n/**", "\nfun ", "\nprivate fun ", "\nprivate val ", "\nclass ")) {
            val idx = source.indexOf(next, start + marker.length)
            if (idx in (start + 1) until end) end = idx
        }
        return source.substring(start, end)
    }

    private fun callBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到 `$marker`，判据失效" }
        val open =
            if (marker.endsWith('(')) start + marker.length - 1 else source.indexOf('(', start + marker.length)
        return blockAt(source, open)
    }

    /** 所有 `marker` 调用（跳过 `fun marker(` 声明）的实参块。 */
    private fun callBlocks(source: String, marker: String): List<String> {
        val blocks = mutableListOf<String>()
        var from = 0
        while (true) {
            val idx = source.indexOf(marker, from)
            if (idx < 0) break
            val declaration = source.substring(0, idx).trimEnd().endsWith("fun")
            if (!declaration) {
                blocks += blockAt(source, idx + marker.length - 1)
            }
            from = idx + marker.length
        }
        return blocks
    }

    private fun blockAt(source: String, open: Int): String {
        check(open > 0) { "调用后面没有实参括号，判据失效" }
        var depth = 0
        for (i in open until source.length) {
            when (source[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return source.substring(open, i + 1)
                }
            }
        }
        error("实参括号没有闭合")
    }

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
