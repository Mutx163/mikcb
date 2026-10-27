package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * `lib/screens/settings/settings_shared.dart` 的 **Kotlin 侧覆盖核对**（P3-B-4 第 4 件事）。
 *
 * ## 这个 Dart 文件不是页面
 *
 * 289 行里混了六样东西，**都不产 spec**：
 *
 * | 内容 | Dart 出处 | Kotlin 侧现状 |
 * |---|---|---|
 * | 两个设置行组件 `MiuixSettingsSwitchPreference` / `MiuixSettingsPreference` | :182-289 | 由官方 Miuix 的 preference 系列承担（[MiuixRowComponent] 一行一类） |
 * | `normalizeLocaleTagForDropdown` | :84-105 | [SettingsGeneralPage.normalizeLocaleTag] ✅ |
 * | `buildLocaleMenuMap` | :111-125 | [SettingsGeneralPage.localeOptions] ✅ |
 * | `colorFromHex` | :128-130 | `SettingsRowRenderTable.colorFromHex`（**在 composeP1 源集**，见下） |
 * | `formatLiveTimeCorrection` | :25-33 | **缺**（宿主是 `settings_live.dart`，归 P3-B-3） |
 * | `liveDisplaySummary` | :133-161 | **缺**（同上） |
 * | `reportSettingsPersistFailure` / `reportSettingsPersistRejected` | :45-80 | 行为在 provider / 宿主层，非本层 |
 *
 * ## 为什么有些断言是「读源码」而不是「调函数」
 *
 * `SettingsRowRenderTable` 与 `SettingsPageRenderers` 在 **`composeP1` 源集**，
 * 而 `src/test` 只挂 `main` —— 测试里 `SettingsRowRenderTable.xxx` 会直接编译不过。
 * 这与 `SettingsRowComponentGuardTest` 是同一套做法：**能调的调、调不到的读源码钉**。
 * 读源码的断言弱一档（只能证明「写了什么」，不能证明「跑起来怎样」），
 * 所以只用在共享件上，本批自己的模型层一律走真正的行为断言。
 *
 * ## 缺口（本批只报，不改共享件）
 *
 * `formatLiveTimeCorrection` 与 `liveDisplaySummary` 在 Kotlin 侧**还没有实现**。
 * 它们的宿主页面是 `settings_live.dart`（P3-B-3 泳道的 `SettingsLivePage`），
 * 不在本批写作用域里。本批能做的是：把这两个函数用到的 11 条 ARB 文案
 * 一条不差登记进 [SettingsStringsExt4]，将来落地时文案已经就位。
 *
 * 剩下 1 条 `languageModeSystem` 已有实现（[SettingsGeneralPage.localeOptions]），
 * 所以「11 + 1 = Dart 源里的 12 条」正好对上——这条等式本身就是覆盖证明。
 */
class SettingsSharedParityTest {

    /**
     * Dart 源里实际出现的 12 个 `l10n.*` 引用
     * （`grep -o 'l10n\.[a-zA-Z0-9_]*' lib/screens/settings/settings_shared.dart | sort -u`）。
     */
    private val expectedKeysFromDart = listOf(
        "languageModeSystem",
        "liveDisplaySummaryCountdownShort",
        "liveDisplaySummaryCourseName",
        "liveDisplaySummaryLeftLabelImage",
        "liveDisplaySummaryLocation",
        "liveDisplaySummaryMinimal",
        "liveDisplaySummaryMore",
        "liveDisplaySummaryShortName",
        "liveDisplaySummaryStageText",
        "liveTimeCorrectionAdvance",
        "liveTimeCorrectionDelay",
        "liveTimeCorrectionNone",
    )

    /** 两个尚未实现的函数各自要用到的文案键（11 条，见类注释的加法）。 */
    private val gapKeyTemplates: Map<String, List<String>> = mapOf(
        "formatLiveTimeCorrection" to listOf(
            "liveTimeCorrectionNone",
            "liveTimeCorrectionDelay",
            "liveTimeCorrectionAdvance",
        ),
        "liveDisplaySummary" to listOf(
            "liveDisplaySummaryShortName",
            "liveDisplaySummaryCourseName",
            "liveDisplaySummaryLocation",
            "liveDisplaySummaryCountdownShort",
            "liveDisplaySummaryStageText",
            "liveDisplaySummaryLeftLabelImage",
            "liveDisplaySummaryMinimal",
            "liveDisplaySummaryMore",
        ),
    )

    // ------------------------------------------------- 一、12 个文案键的覆盖

    @Test
    fun `Dart 共享件用到的 12 个键一条不差地登记在 Ext4`() {
        assertEquals("沿用清单本身应当是 12 条", 12, expectedKeysFromDart.size)
        val registered = SettingsStringsExt4.allTexts.map { it.key }.toSet()
        val missing = expectedKeysFromDart.filterNot { registered.contains(it) }
        assertEquals("这些键没登记在 SettingsStringsExt4 里：$missing", emptyList<String>(), missing)
    }

    @Test
    fun `Dart 源里的键清单没有变化`() {
        // 直接读源文件再数一遍：源里新增第 13 条而这里还写 12，「文案覆盖」就是假的
        val keys = Regex("""l10n\.([a-zA-Z0-9_]+)""").findAll(sharedDartSource())
            .map { it.groupValues[1] }
            .toSortedSet()
        assertEquals(
            "settings_shared.dart 的 l10n 键清单变了，请同步 expectedKeysFromDart",
            expectedKeysFromDart.sorted(),
            keys.toList(),
        )
    }

    @Test
    fun `这 12 条文案在 arb 里逐字存在`() {
        expectedKeysFromDart.forEach { key ->
            val kotlin = SettingsStringsExt4.allTexts.first { it.key == key }.zh
            assertEquals("键 `$key` 的 Kotlin 值被改写了", ArbZh.value(key), kotlin)
        }
    }

    // ------------------------------------------- 二、已有对等实现的几项（行为断言）

    @Test
    fun `语言下拉表与 buildLocaleMenuMap 同口径`() {
        // settings_shared.dart:111-125：首项「跟随系统」空 tag，其余按 supportedLocales 顺序、以自称显示
        val options = SettingsGeneralPage.localeOptions()
        assertEquals("跟随系统", options.first().label)
        assertEquals("", options.first().id)
        assertEquals("languageModeSystem", options.first().labelKey)
        assertEquals(listOf("en", "ja", "ko", "zh", "zh_HK", "zh_TW"), options.drop(1).map { it.id })
        assertEquals(
            listOf("English", "日本語", "한국어", "简体中文", "繁體中文（香港）", "繁體中文（台灣）"),
            options.drop(1).map { it.label },
        )
        // Dart 用 seen 去重；这里同样不该有重复 tag
        assertEquals(options.size, options.map { it.id }.toSet().size)
    }

    @Test
    fun `locale 归一与 normalizeLocaleTagForDropdown 同口径`() {
        // settings_shared.dart:84-105
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag(""))
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag("   "))
        assertEquals("zh", SettingsGeneralPage.normalizeLocaleTag("zh-Hans"))
        assertEquals("en", SettingsGeneralPage.normalizeLocaleTag("en_US_POSIX"))
        assertEquals("zh_HK", SettingsGeneralPage.normalizeLocaleTag("zh-HK"))
        assertEquals("", SettingsGeneralPage.normalizeLocaleTag("fr"))
    }

    // ------------------------------------- 三、composeP1 侧的两项（读源码钉）

    @Test
    fun `colorFromHex 的坏串回退色与 Dart 一致`() {
        // settings_shared.dart:128-130 `Color(0xFF2563EB)`；Kotlin 侧在 composeP1 的
        // SettingsRowRenderTable（测试源集看不到，只能读源码）。
        val table = composeP1File("SettingsRowRenderTable.kt").readText()
        assertTrue(
            "颜色解析的回退色应当是品牌蓝 0xFF2563EB（Dart :129）",
            "0xFF2563EB" in table,
        )
        assertTrue(
            "SettingsRowRenderTable 应提供 colorFromHex（对应 Dart 的 colorFromHex）",
            "fun colorFromHex(" in table,
        )
        // 解析口径逐字抄 lib/utils/hex_color.dart：去空白、最多一个 #、长度必须 6、alpha 恒 FF
        assertTrue("解析应当去空白", "trim()" in table)
        assertTrue("解析应当处理开头的 #", "startsWith(\"#\")" in table)
        assertTrue("长度必须 6 位", "length != 6" in table)
    }

    @Test
    fun `行尾取值槽位在渲染层统一走 details 优先`() {
        // settings_shared.dart:258-268 把值塞进官方 ArrowPreference 的 endActions，
        // 值本身由调用方给；Kotlin 侧由 SettingsRowRenderTable.trailingText 统一取。
        val table = composeP1File("SettingsRowRenderTable.kt").readText()
        assertTrue(
            "trailingText 应存在（渲染层的取值槽位唯一入口）",
            "fun trailingText(" in table,
        )
        assertTrue(
            "取值应当是 details 优先、其次 value（与模型的静态/动态之分对应）",
            "row.details ?: row.value" in table,
        )
        // 模型层这两个字段的语义在 SettingsRow 的注释里：details 来自 ARB、
        // value 是算出来的。这里用真行为把同一件事再钉一次。
        val row = settingsRow(
            id = "shared.trailing",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt4.homeGridEditorResetAction,
            details = SettingsStringsExt4.glassDockTabWeek,
            value = "不该被取到",
        )
        assertEquals("周课表", row.details)
        assertEquals("不该被取到", row.value)
    }

    @Test
    fun `两个设置行组件在模型里有各自的官方落点`() {
        // Dart：MiuixSettingsSwitchPreference（开关行）/ MiuixSettingsPreference（导航行）
        // Kotlin：SWITCH / ARROW 两个 MiuixRowComponent，渲染层各接一个官方组件
        // （渲染层具体符号由 SettingsRowComponentGuardTest 钉，这里只钉模型侧的区分）
        val switch = MiuixRowComponent.SWITCH
        val arrow = MiuixRowComponent.ARROW
        assertTrue("开关行应有官方 preference 对应物", switch.officialPreference.isNotEmpty())
        assertTrue("导航行应有官方 preference 对应物", arrow.officialPreference.isNotEmpty())
        assertTrue("两者不能是同一个组件", switch.officialPreference != arrow.officialPreference)
        // 差异点：开关行要承载当前态，导航行不需要
        val switchRow = settingsRow(
            id = "shared.switch",
            component = MiuixRowComponent.SWITCH,
            title = SettingsStringsExt4.homeGridEditorRemoveTooltip,
            switchValue = true,
        )
        assertEquals(true, switchRow.switchValue)
        val arrowRow = settingsRow(
            id = "shared.arrow",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt4.homeGridEditorRemoveTooltip,
        )
        assertNull("导航行不该有 switchValue", arrowRow.switchValue)
    }

    // ----------------------------------------------- 四、缺口：文案就位，实现待补

    @Test
    fun `两个未实现函数的文案模板已全部就位`() {
        val registered = SettingsStringsExt4.allTexts.map { it.key }.toSet()
        gapKeyTemplates.forEach { (function, keys) ->
            val missing = keys.filterNot { registered.contains(it) }
            assertEquals("`$function` 的文案模板缺了：$missing", emptyList<String>(), missing)
        }
        // 11 条（3 + 8）加上已有实现的 languageModeSystem，正好是 12 条
        assertEquals(11, gapKeyTemplates.values.flatten().size)
        assertEquals(12, gapKeyTemplates.values.flatten().size + 1)
        assertTrue(expectedKeysFromDart.contains("languageModeSystem"))
    }

    @Test
    fun `缺口函数的模板拼合结果符合 Dart 口径`() {
        // :25-33 formatLiveTimeCorrection：0 → 不矫正；正 → 整体延后 N 秒；负 → 整体提前 |N| 秒
        assertEquals("不矫正", SettingsStringsExt4.liveTimeCorrectionNone.zh)
        assertEquals(
            "整体延后 5 秒",
            SettingsStringsExt4.liveTimeCorrectionDelay.filled("seconds", "5"),
        )
        assertEquals(
            "整体提前 3 秒",
            SettingsStringsExt4.liveTimeCorrectionAdvance.filled("seconds", "3"),
        )
        // :133-161 liveDisplaySummary：超过两项收进 more 文案（首项 + 总项数）
        assertEquals(
            "简称 等 3 项",
            SettingsStringsExt4.liveDisplaySummaryMore
                .filled("first", "简称")
                .filled("count", "3"),
        )
        // 最简显示（全部关掉时的那句）
        assertEquals("最简显示", SettingsStringsExt4.liveDisplaySummaryMinimal.zh)
    }

    @Test
    fun `保存失败提示的文案就位`() {
        // reportSettingsPersistFailure（:45-59）用 l10n.saveFailed。它不是本批三个 Dart 源的
        // 文案预算，但既然要核对共享件，就把「这句字真的在 ARB 里」钉住。
        assertEquals("保存失败", SettingsStringsExt4.saveFailed.zh)
        assertEquals(ArbZh.value("saveFailed"), SettingsStringsExt4.saveFailed.zh)
    }

    // ------------------------------------------------------------------ 支撑

    private fun sharedDartSource(): String =
        repoFile("lib/screens/settings/settings_shared.dart").readText(Charsets.UTF_8)

    private fun composeP1File(name: String): File =
        repoFile("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/$name")

    private fun repoFile(relative: String): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.exists()) return candidate
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
