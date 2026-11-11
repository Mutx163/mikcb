package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 控制卡 / 底栏 / 行尾转圈 三条观感能力的守卫（2026-11-10）。
 *
 * ## 为什么要有这一份
 *
 * - **空标题**：发布版有些控制卡卡里只有一颗整宽按钮、卡本身没有标题（假期「添加假期」
 *   `settings_holiday.dart:562-578`、节假日高级页「检查更新」`:777-798`）。模型照抄按钮名
 *   填进 `label` 时，屏上就是标题与按钮同名两遍；传空串同样不行——`Text("")` 仍占一行高度。
 * - **固定底栏**：发布版那条是「实心栏 + 顶部 0.5dp 细线 + 整宽主色按钮」
 *   （`settings_holiday.dart:777-798`），不是圆角卡、也没有标题。
 * - **行尾转圈**：发布版天气页定位中在行尾给一颗 16dp 圈（`settings_weather.dart:71-78`）。
 *
 * ## 评审 2026-11-10 的两处加固（原版判据是「假绿」）
 *
 * 1. 旧断言直接在**原始源码**里 `contains("controlCardTitle(node.label)?.let {")`——
 *    而渲染层的 KDoc 注释里也写着这串字，把真调用删掉、只留注释，这条守卫照样绿。
 *    现在一律先 `stripCommentsAndStrings` 再匹配（与 `RowDividerGuardTest` 同家法）。
 * 2. 正向钉住底栏与行尾转圈：只钉「有这个名字」不够，钉**具体写法**
 *    （`buttonColorsPrimary()`、busy 时 `QingyuLoadingInButtonLarge()`、`trailingSpinner = data.locating`）。
 *
 * ## 咬合探针（本次手跑过，红→绿各一次）
 *
 * - 把 `ControlCard` 的 `controlCardTitle(node.label)` 换回 `node.label` → 渲染层判据红；
 * - 把 `FooterBar` 的 `buttonColorsPrimary()` 删掉 → 底栏配色判据红；
 * - 把天气页 `trailingSpinner = data.locating` 删掉 → 接线判据红；
 * - 还原后全部恢复绿。
 */
class SettingsControlCardTitleGuardTest {

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

    private fun readSource(relative: String): String {
        val file = File(androidSrc(), relative)
        assertTrue("源码不存在：${file.path}", file.isFile)
        return file.readText()
    }

    private fun renderersSource(): String = readSource(
        "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
    )

    /** 渲染层源码**剥掉注释与字符串**后的正文（防止注释里写着判据名就假绿）。 */
    private fun renderersCode(): String = stripCommentsAndStrings(renderersSource())

    // ------------------------------------------------------------ A：空标题不渲染

    @Test
    fun `空标题一律返回 null`() {
        assertNull("null 标题必须整块不画（发布版这类卡本来就没有标题）", controlCardTitle(null))
        assertNull("空串会占掉一行 headline1 的高度，屏上是卡片顶部一条空白带", controlCardTitle(""))
        assertNull("纯空白与空串同效", controlCardTitle("   "))
    }

    @Test
    fun `正常标题原样返回`() {
        // 对照：有标题的卡（主题卡「当前主题」、小组件授权提示…）必须一字不改地渲染。
        assertEquals("当前主题", controlCardTitle("当前主题"))
        assertEquals("已启用", controlCardTitle("已启用"))
    }

    @Test
    fun `渲染层读同一个判据 不回退成就地判空`() {
        // 剥注释后再判：KDoc 里同样写着 `controlCardTitle(node.label)?.let {`，
        // 不剥的话「删掉真调用、只留注释」也是绿的（评审指出的假绿）。
        val code = renderersCode()
        // 用朴素子串计数（不要用 toRegex：`?.let {` 里的 `?` `.` `{` 都是正则元字符）。
        val needle = "controlCardTitle(node.label)?.let {"
        var hits = 0
        var from = code.indexOf(needle)
        while (from >= 0) {
            hits++
            from = code.indexOf(needle, from + needle.length)
        }
        assertTrue(
            "控制卡与预览卡两处都要走模型判据 controlCardTitle(node.label)，实际命中 $hits 处",
            hits >= 2,
        )
        assertFalse(
            "渲染层又写回了就地判空（判据要只有一个，否则两处迟早分叉）",
            code.contains("isNullOrBlank"),
        )
    }

    // ------------------------------------------------------------ B：固定底栏是「栏」不是「卡」

    @Test
    fun `底栏是栏式且按钮取主色 busy 时整块换圈`() {
        val code = renderersCode()
        assertTrue(
            "找不到 FooterBar —— 固定底栏被改回通用节点渲染了",
            code.contains("private fun FooterBar("),
        )
        assertTrue(
            "底栏按钮没有取主色：miuix Button 默认是 secondaryVariant（灰），" +
                "发布版 HyperosButton 默认 primary（`hyperos_controls.dart`）",
            code.contains("ButtonDefaults.buttonColorsPrimary("),
        )
        assertTrue(
            "busy 态没有把文案整块换成圈（发布版 labelChild 的写法），" +
                "且按钮内圈必须走 18/2 的大档 QingyuLoadingInButtonLarge()" +
                "（发布版 `SizedBox(18×18) + strokeWidth: 2`，见评审 三-08）",
            code.contains("if (node.busy) {") && code.contains("QingyuLoadingInButtonLarge()"),
        )
        assertTrue(
            "disabled 主色没有接 `QingyuTheme.disabledPrimary`（发布版 disabledPrimaryButton）",
            code.contains("QingyuTheme.disabledPrimary("),
        )
    }

    // ------------------------------------------------------------ C：行尾转圈接线

    @Test
    fun `行尾转圈默认关闭且天气页真的接上了`() {
        val plain = settingsRow(
            id = "general.haptics",
            component = MiuixRowComponent.SWITCH,
            title = ArbText("generalHapticsTitle", "触感反馈"),
        )
        assertFalse("默认必须 false（既有行零变化）", plain.trailingSpinner)

        val weather = readSource(
            "main/kotlin/com/mutx163/qingyu/pages/settings/SettingsWeatherPage.kt",
        )
        assertTrue(
            "天气页「使用当前位置」定位中必须接 trailingSpinner = data.locating" +
                "（发布版 settings_weather.dart:71-78）",
            weather.contains("trailingSpinner = data.locating"),
        )
        val code = renderersCode()
        assertTrue(
            "渲染层没有消费 trailingSpinner（传了也不生效）",
            code.contains("if (row.trailingSpinner)"),
        )
        assertTrue(
            "行尾转圈没有走共享件（评审 P6-1：统一 QingyuLoadingInline）",
            code.contains("QingyuLoadingInline(slot = QingyuLoadingSlot.Button)"),
        )
    }

    // ------------------------------------------------------------ D：紧凑行只是可选档

    @Test
    fun `紧凑档默认关闭且只影响堆叠行`() {
        val plain = settingsRow(
            id = "general.haptics",
            component = MiuixRowComponent.SWITCH,
            title = ArbText("generalHapticsTitle", "触感反馈"),
        )
        assertFalse("默认必须是官方 16dp 四边（其它页零变化）", plain.compact)

        val spec = SettingsHolidayAdvancedPage.spec(
            SettingsPageState(),
            SettingsHolidayAdvancedPage.buildData(
                listOf(com.mutx163.qingyu.calendar.HolidayLogLine("09:00:12", "已从内置数据加载")),
                refreshing = false,
            ),
        )
        val logRow = spec.row("holidayAdvanced.log.0")
        assertTrue("更新日志是一卡多条目，必须显式走紧凑档", logRow.compact)
        assertTrue("紧凑档只挂在上下两行的堆叠行上", logRow.stacked)

        val code = renderersCode()
        assertTrue(
            "渲染层没有消费 compact（传了也不生效）",
            code.contains("if (row.compact)"),
        )
        // 紧凑档的**代码事实**（评审 E2R-08：原判据只认 KDoc 里的一句话——改注释会红、
        // 真把行为改回去反而不红）。现在钉三件：
        // ① 紧凑分支存在；② 它真的绕开 BasicComponent（分支体里不出现该类）；③ 非紧凑档回落到官方 16dp 四边。
        val compactStart = code.indexOf("if (row.compact) {")
        assertTrue("渲染层缺少 `if (row.compact) {` 分支", compactStart >= 0)
        val compactEnd = code.indexOf("return", compactStart)
        assertTrue("紧凑分支没有以 return 结束（会落回 BasicComponent）", compactEnd > compactStart)
        val compactBody = code.substring(compactStart, compactEnd)
        assertFalse(
            "紧凑分支里仍调用 BasicComponent —— 它内部写死 heightIn(min = 56.dp)，行高压不下去",
            compactBody.contains("BasicComponent("),
        )
        assertTrue(
            "紧凑分支没有照发布版排「左右 16dp、上下 0」",
            compactBody.contains("padding(start = 16.dp, end = 16.dp)"),
        )
        assertTrue(
            "非紧凑档没回落到 BasicComponentDefaults.InsideMargin（官方 16dp 四边）",
            code.contains("insideMargin = BasicComponentDefaults.InsideMargin"),
        )
    }

    // ------------------------------------------------------------ 判据工具

    /** 剥掉行注释、块注释与字符串字面量（普通 + `"""` 原始串），保留换行防行号漂移。 */
    private fun stripCommentsAndStrings(text: String): String {
        val out = StringBuilder(text.length)
        var i = 0
        var blockDepth = 0
        while (i < text.length) {
            if (blockDepth > 0) {
                when {
                    text.startsWith("/*", i) -> {
                        blockDepth++
                        i += 2
                    }
                    text.startsWith("*/", i) -> {
                        blockDepth--
                        i += 2
                    }
                    else -> {
                        if (text[i] == '\n') out.append('\n')
                        i++
                    }
                }
                continue
            }
            if (text.startsWith("//", i)) {
                while (i < text.length && text[i] != '\n') i++
                continue
            }
            if (text.startsWith("/*", i)) {
                blockDepth = 1
                i += 2
                continue
            }
            if (text.startsWith("\"\"\"", i)) {
                var j = i + 3
                while (j < text.length && !text.startsWith("\"\"\"", j)) j++
                i = if (j >= text.length) text.length else j + 3
                continue
            }
            if (text[i] == '"') {
                i++
                while (i < text.length) {
                    when {
                        text[i] == '\\' -> i += 2
                        text[i] == '"' -> {
                            i++
                            break
                        }
                        else -> i++
                    }
                }
                continue
            }
            out.append(text[i])
            i++
        }
        return out.toString()
    }
}
