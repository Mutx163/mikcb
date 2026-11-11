package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「首页标题」预览必须由**宿主注入真组件**的守卫（2026-11-10 建立）。
 *
 * ## 防的是什么
 *
 * 用户实报「预览和实际差距太远，看不出来预览效果」：那张卡曾经走通用样张管线
 * （`SettingsPageRenderers.PreviewCard` → `PreviewTile`：72dp、主色蓝底、`body2` /
 * `footnote1` 两行白字），跟真标题零共用代码。真首页那行字是压在壁纸上的、坐在玻璃带里、
 * 字色还随壁纸明暗翻面——色块永远画不出这个。
 *
 * 重做后的契约（四层，缺一条就退回旧形态）：
 *
 * 1. **模型只占位**：`SettingsHomeNavigationPage.titleStylePreview()` 不再携带 `texts`
 *    —— 一带样张文字，渲染层就直接画色块，宿主槽位形同虚设；
 * 2. **渲染层留槽**：`SettingsPageScreen` / `SettingsNodeView` 的 `inlineSlots` **默认空表**
 *    （其它三页的样品预览不受影响），命中 node id 时调宿主内容；
 * 3. **宿主真的塞**：`HomeNavigationHost` 必须把 `HOME_TITLE_PREVIEW_ID` 的槽位填成
 *    `HomeTitlePreviewCard`，并喂同一份 `rememberHomeBackdropChrome` 与真课表名；
 * 4. **卡里是真组件**：`TimetableTopBar` + `TimetableChromeBandGlass` + `chrome.backdrop`，
 *    不许出现 `PreviewTile` / `colorScheme.primary` 这类自绘色块。
 *
 * 这是源码文本守卫：`composeP1` 进不了 L0 的 JVM classpath（`SettingsHost` /
 * `SettingsPageRenderers` / `HomeTitlePreviewCard` 都带 Compose 依赖）；判据对格式敏感，
 * 只钉最小集合——改这段接线会先红，**请同步本文件而不是删断言**。
 *
 * 咬合探针（2026-11-10 实跑）：把模型那段占位改回带 `texts =` 的样张 →
 * 本守卫红；还原 → 绿。
 */
class HomeTitlePreviewInjectionGuardTest {

    // ───────────────────── 0. 不空跑 ─────────────────────

    @Test
    fun `判据锚点存在`() {
        assertTrue(
            "SettingsHomeNavigationPage.kt 里找不到 HOME_TITLE_PREVIEW_ID（模型被改结构后必须同步本守卫）",
            "const val HOME_TITLE_PREVIEW_ID" in modelSource(),
        )
        assertTrue(
            "找不到 HomeTitlePreviewCard.kt（宿主注入件被挪走/改名后必须同步本守卫）",
            File(settingsComposeDir(), "HomeTitlePreviewCard.kt").isFile,
        )
        assertTrue(
            "找不到 HomeNavigationHost（宿主被挪走后必须同步本守卫）",
            "fun HomeNavigationHost(" in hostSource(),
        )
    }

    // ───────────────────── 1. 模型只占位、不带样张文字 ─────────────────────

    @Test
    fun `模型里的首页标题预览不再携带样张文字`() {
        val model = stripKotlinComments(modelSource())
        val at = model.indexOf("private fun titleStylePreview(")
        assertTrue("找不到 titleStylePreview()（判据会空跑）", at >= 0)
        // 函数很短（一个 `= SettingsInline(...)` 表达式体）；取到下一个成员声明之前的窗口。
        val window = model.substring(at, minOf(model.length, at + 700))
        assertTrue(
            "预览节点必须引用 HOME_TITLE_PREVIEW_ID（宿主按这个 id 注入）",
            "HOME_TITLE_PREVIEW_ID" in window,
        )
        assertFalse(
            "预览节点又开始携带 `texts =` 了：渲染层会立刻退回 PreviewTile 蓝图色块，" +
                "用户看到的又是「看不出真实效果」的旧形态。内容必须由宿主注入。" ,
            "texts =" in window,
        )
        assertFalse(
            "预览节点不应该再声明 label（会多出一行空标题 + 12dp 空白）",
            "label =" in window,
        )
    }

    // ───────────────────── 2. 渲染层：槽位默认空、按 node id 命中 ─────────────────────

    @Test
    fun `渲染层的注入槽默认空表 并且按 node id 找宿主内容`() {
        val renderers = stripKotlinComments(renderersSource())
        val slotSignature = "inlineSlots: Map<String, @Composable () -> Unit> = emptyMap()"
        val declarations = Regex(Regex.escape(slotSignature)).findAll(renderers).count()
        assertTrue(
            "inlineSlots 的形参必须是「默认空表」且同时挂在 SettingsPageScreen 与 SettingsNodeView 上" +
                "（实际出现 $declarations 次）—— 不默认空表的话，另外三页的样品预览会全部变成空块",
            declarations >= 2,
        )
        assertTrue(
            "调用链没有把 inlineSlots 传下去（`inlineSlots = inlineSlots`）：槽位永远到不了 PreviewCard",
            "inlineSlots = inlineSlots" in renderers,
        )
        assertTrue(
            "PreviewCard 没有按 node id 取宿主内容（`inlineSlots[node.id]`）",
            "inlineSlots[node.id]" in renderers,
        )
        val card = functionBlock(renderers, "private fun PreviewCard(")
        assertTrue(
            "PreviewCard 拿到宿主内容却没画（`injected()`）",
            "injected()" in card,
        )
    }

    // ───────────────────── 3. 宿主真的把真组件塞进槽位 ─────────────────────

    @Test
    fun `首页导航宿主给预览槽喂真组件与同一份壁纸快照`() {
        val host = functionBlock(hostSource(), "fun HomeNavigationHost(")
        assertTrue(
            "宿主没有传 inlineSlots：首页标题预览会留在通用色块",
            "inlineSlots = mapOf(" in host,
        )
        assertTrue(
            "槽位键必须用模型常量 SettingsHomeNavigationPage.HOME_TITLE_PREVIEW_ID",
            "SettingsHomeNavigationPage.HOME_TITLE_PREVIEW_ID" in host,
        )
        assertTrue(
            "槽位内容必须是 HomeTitlePreviewCard（真组件卡）",
            "HomeTitlePreviewCard(" in host,
        )
        assertTrue(
            "壁纸/材质/墨色必须取 rememberHomeBackdropChrome（与首页、外观编辑预览同一份推导）",
            "rememberHomeBackdropChrome(" in host,
        )
        assertTrue(
            "brand 档副行要用真课表名（previewProfileName），不是固定示意名",
            "profileName = previewProfileName" in host,
        )
    }

    // ───────────────────── 4. 卡里是真组件、真材质，不许自绘色块 ─────────────────────

    @Test
    fun `预览卡复用真顶栏与真玻璃 不许回到自绘色块`() {
        val card = stripKotlinComments(
            File(settingsComposeDir(), "HomeTitlePreviewCard.kt").readText().replace("\r\n", "\n"),
        )
        assertTrue("预览卡必须复用真顶栏 TimetableTopBar(", "TimetableTopBar(" in card)
        assertTrue("预览卡必须复用真玻璃带 TimetableChromeBandGlass(", "TimetableChromeBandGlass(" in card)
        assertTrue(
            "壁纸样例必须来自 HomeBackdropChrome.backdrop（同一份快照）",
            "chrome.backdrop" in card,
        )
        assertTrue(
            "玻璃要采样壁纸就得录样（Modifier.layerBackdrop(...)）",
            "layerBackdrop(" in card,
        )
        assertTrue(
            "预览里不该画「更多」球（menuItems 空表）：那是菜单能力，不是标题样式",
            "menuItems = emptyList()" in card,
        )
        assertFalse(
            "预览卡里出现了 PreviewTile(：又开始自绘色块了（用户报的就是这个）",
            "PreviewTile(" in card,
        )
        assertFalse(
            "预览卡里出现了主色蓝底（colorScheme.primary）：那是旧蓝图色块的配色",
            "colorScheme.primary" in card,
        )
    }

    // ------------------------------------------------------------------
    // 工具
    // ------------------------------------------------------------------

    private fun androidSrc(): File {
        var dir = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (true) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            dir = dir.parentFile ?: throw AssertionError(
                "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                    "当前工作目录：${System.getProperty("user.dir")}",
            )
        }
    }

    private fun settingsComposeDir(): File =
        File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages/settings")

    private fun modelSource(): String =
        File(androidSrc(), "main/kotlin/com/mutx163/qingyu/pages/settings/SettingsHomeNavigationPage.kt")
            .readText()
            .replace("\r\n", "\n")

    private fun renderersSource(): String =
        File(settingsComposeDir(), "SettingsPageRenderers.kt").readText().replace("\r\n", "\n")

    private fun hostSource(): String =
        File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt")
            .readText()
            .replace("\r\n", "\n")

    /** 截出顶层函数体：从 `marker` 起到第一个行首 `}`（顶层函数收尾）为止。 */
    private fun functionBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        assertTrue("源码里找不到 $marker", start >= 0)
        val rest = source.substring(start)
        val end = rest.indexOf("\n}\n")
        assertTrue("$marker 的函数体没有找到行首收尾 `}`", end > 0)
        return rest.substring(0, end)
    }

    /** 剥掉行注释与块注释（KDoc 里的说明不能算违规，与 `SettingsSaveFailureToastGuardTest` 同一套做法）。 */
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
}
