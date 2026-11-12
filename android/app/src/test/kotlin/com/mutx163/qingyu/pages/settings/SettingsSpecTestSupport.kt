package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.core.MiniJson
import java.io.File

/**
 * 设置族三页结构测试的共用支撑件（无 @Test，纯遍历 / 加载 / 度量）。
 *
 * 这里只做三件事：
 * 1. 把 [SettingsPageSpec] 的节点树摊平成「(ARB 键, 屏上文案)」清单，供逐字对照；
 * 2. 从工作目录向上找到 `i18n/app_zh.arb` 并解析（文案的**唯一真源**）；
 * 3. 文案宽度口径的**断言镜像**（权威定义在 `AGENTS.md`「界面文案风格」段：标题 ≤11 / 说明 ≤17
 *    + 渲染宽度算法；`tool/copy_style_rules.dart` 已随 P4-C 删除，这里不是第二处定义
 *    ——改口径请改那条纪律，然后同步这里）。
 */

// ---------------------------------------------------------------- spec 遍历

/** 深度优先摊平节点树（保持声明顺序，测试断言的就是屏上顺序）。 */
fun SettingsPageSpec.flatten(): List<SettingsNode> {
    val out = ArrayList<SettingsNode>()
    fun visit(node: SettingsNode) {
        out.add(node)
        if (node is SettingsGroup) node.children.forEach { visit(it) }
    }
    nodes.forEach { visit(it) }
    return out
}

/** 所有行控件（含分组内层），保持屏上顺序。 */
fun SettingsPageSpec.rows(): List<SettingsRow> = flatten().filterIsInstance<SettingsRow>()

/** 按 id 取行；取不到直接失败（避免拼错 id 的断言静默通过）。 */
fun SettingsPageSpec.row(id: String): SettingsRow =
    rows().firstOrNull { it.id == id } ?: error("页面 ${this.id} 里没有 id=$id 的行")

/**
 * 屏上顺序的**顶层**节点 id 清单（区块骨架对照用）。
 *
 * 只看顶层：分组内的行顺序由 `SettingsGroup.childRowIds()` / `childIds()` 单独钉，
 * 两处合起来才是「层级 + 顺序」的完整断言。用全树摊平会把两者混成一条长清单。
 */
fun SettingsPageSpec.topLevelIds(): List<String> = nodes.map { it.id }

/** 全树摊平后的 id 清单（含分组内层），排查用。 */
fun SettingsPageSpec.flattenedIds(): List<String> = flatten().map { it.id }

/** 分组：取出 id 为 [id] 的组。 */
fun SettingsPageSpec.group(id: String): SettingsGroup =
    flatten().filterIsInstance<SettingsGroup>().firstOrNull { it.id == id }
        ?: error("页面 ${this.id} 里没有 id=$id 的分组")

/** 分组内直接子行的 id 顺序（层级 + 顺序一起钉）。 */
fun SettingsGroup.childRowIds(): List<String> = children.filterIsInstance<SettingsRow>().map { it.id }

/** 分组内直接子节点的 id 顺序（含内联块，如字号实时预览）。 */
fun SettingsGroup.childIds(): List<String> = children.map { it.id }

/**
 * 收集这份 spec 里所有「(ARB 键, 逐字文案)」。
 *
 * 覆盖：行标题/说明/行尾值、分组标题、整宽说明、内联块里的按钮与预览文案、
 * 以及下拉选项名（选项名也是屏上的字）。
 *
 * **固定底栏（[SettingsPageSpec.footerNode]）与顶栏动作也在口径内**（2026-10-29 补）：
 * 节假日高级页把「检查更新」从 `nodes` 移到了底栏，如果这里只看 `nodes`，
 * 那颗按钮的文案就悄悄退出了逐字对拍——一个「越改越安全」的假象。
 * 顶栏动作只有语义标签（无障碍朗读），没有 ARB 键，所以不进这个清单。
 */
fun SettingsPageSpec.allArbTexts(): List<Pair<String, String>> {
    val out = ArrayList<Pair<String, String>>()
    fun add(key: String?, text: String?) {
        // 空键 = 文案不来自 ARB（用户数据，如已存主题名），对照时跳过
        if (!key.isNullOrEmpty() && text != null) out.add(key to text)
    }
    // 底栏节点不在 nodes 里，单独并进同一份遍历（顺序：正文在前、底栏在后，与屏上一致）。
    (flatten() + listOfNotNull(footerNode)).forEach { node ->
        when (node) {
            is SettingsRow -> {
                add(node.titleKey, node.title)
                add(node.subtitleKey, node.subtitle)
                add(node.detailsKey, node.details)
                add(node.valueKey, node.value)
                node.options.forEach { add(it.labelKey, it.label) }
            }
            is SettingsLabel -> add(node.textKey, node.text)
            is SettingsDescription -> add(node.textKey, node.text)
            is SettingsInline -> {
                add(node.labelKey, node.label)
                add(node.valueKey, node.value)
                node.texts.forEach { add(it.key, it.text) }
            }
            is SettingsGroup -> Unit
            is SettingsGap -> Unit
        }
    }
    return out
}

// ------------------------------------------------------------------- ARB 真源

object ArbZh {

    /** `i18n/app_zh.arb` 的解析结果（key → zh 文案）。 */
    val strings: Map<String, String> by lazy { load() }

    fun value(key: String): String =
        strings[key] ?: error("ARB(app_zh.arb) 里没有键 `$key`——文案必须逐字来自 ARB")

    private fun load(): Map<String, String> {
        val file = findArb()
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }

    /** 从工作目录向上找仓库根，再定位 `i18n/app_zh.arb`。 */
    private fun findArb(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) return candidate
            dir = dir?.parentFile
        }
        error("找不到 i18n/app_zh.arb（工作目录 ${File("").absolutePath}）")
    }
}

// --------------------------------------------------------------- 宽度镜像

/**
 * 文案渲染宽度的镜像实现，口径与 `AGENTS.md`「界面文案风格」段第 128-129 行
 * 逐字一致：占位符 `{...}` → `000`，rune > 0x2E80 → 1.0，
 * 其余 ASCII → 0.55。单位≈一个汉字宽。
 */
object CopyWidthMirror {
    private val PLACEHOLDER = Regex("""\{[^}]*\}""")

    fun of(text: String): Double {
        val resolved = PLACEHOLDER.replace(text, "000")
        var total = 0.0
        resolved.forEach { ch ->
            total += if (ch.code > 0x2E80) 1.0 else 0.55
        }
        return total
    }
}

/** 行控件单行口径上限（`AGENTS.md`「界面文案风格」段：标题 ≤11 / 说明 ≤17）。 */
const val TITLE_MAX_WIDTH = 11.0
const val SUBTITLE_MAX_WIDTH = 17.0
