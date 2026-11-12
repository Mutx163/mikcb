package com.mutx163.qingyu.testutil

import org.junit.Assert.fail

/**
 * 源码守卫的断言入口：**读不到就红**。
 *
 * ## 为什么必须有这个 API
 *
 * 源码守卫最常见的写法是 `assertFalse(source.contains("旧写法"))` 或 `"旧写法" !in source`。
 * 一旦 `source` 读成空窜（锚点改名、路径写错、或读法换档把内容擦掉了），这类**否定式断言恒真**：
 * 2026-11-12 全仓审计里 `HomePullQuickImportWiringGuardTest` 的判据是
 * `"homeViewMode" !in enabledLine`，而 `enabledLine = source.lineSequence()
 * .firstOrNull { it.contains("val pullImportEnabled =") }.orEmpty()`——锚点一改名就是空串，
 * 断言永远通过，测试看起来还在测。
 *
 * 把断言收进这两个函数之后，「忘了判空」从个人疏忽变成**API 层面不可能**：
 * 空读会先在诊断清晰的地方红，而不是静默通过。
 *
 * ## 本 API **不负责剥离**
 *
 * 只接受**已经处理好的** `source`。剥离档位（[readKotlinSourceNormalized] 默认档 /
 * [readKotlinSourceNoStrings] 中性化档）必须由调用方**显式选择**，并留在调用点一眼可读的位置。
 * 档位若被藏进 helper 里隐式决定，就会出现「判字面量却用了中性化档 ⇒ 被查的字面量自己被擦掉 ⇒ 恒真」
 * （`DayAgendaWallpaperInkWiringGuardTest` 的教训）。
 *
 * @param label 诊断用的来源名（文件路径或锚点名），会原样出现在失败消息里
 */
fun assertSourceContains(source: String, needle: String, label: String = "") {
    val where = sourceLabelPrefix(label)
    if (source.isBlank()) {
        fail("${where}源码没读到内容：期望包含 <$needle>；实际=${describeSourceHead(source)}")
    }
    if (!source.contains(needle)) {
        fail("${where}源码里没有 <$needle>；实际=${describeSourceHead(source)}")
    }
}

/**
 * [assertSourceContains] 的否定版：要求 [source] 里**不出现** [needle]。
 *
 * 否定侧才是恒真高发区，所以它**先判非空、再判缺席**——空读时直接失败，而不是「没找到所以通过」。
 */
fun assertSourceLacks(source: String, needle: String, label: String = "") {
    val where = sourceLabelPrefix(label)
    if (source.isBlank()) {
        fail(
            "${where}源码没读到内容：否定式断言在空串上恒真，拒绝通过（本不该出现 <$needle>）；" +
                "实际=${describeSourceHead(source)}",
        )
    }
    if (source.contains(needle)) {
        fail("${where}源码里出现了不该有的 <$needle>；实际=${describeSourceHead(source)}")
    }
}

/**
 * 失败消息里的「实际读到了什么」：**区分空串 / 只有空白 / 正常内容**。
 *
 * 只写「空」会把「路径错了」和「读到了 N 个空白字符」混成一类——后者通常意味着剥离档位选错
 * 或整段被中性化，处理方式完全不同。
 */
internal fun describeSourceHead(source: String): String = when {
    source.isEmpty() -> "空（0 字符）"
    source.isBlank() -> "只有 ${source.length} 个空白字符（读法把内容擦掉了？）"
    else -> "前 ${minOf(SOURCE_HEAD_LIMIT, source.length)} 字符=<" +
        source.take(SOURCE_HEAD_LIMIT).replace("\r", "").replace("\n", "\\n") + ">"
}

private fun sourceLabelPrefix(label: String): String = if (label.isBlank()) "" else "[$label] "

/** 失败消息里展示的实际内容长度（足够看出「是不是同一段代码」）。 */
private const val SOURCE_HEAD_LIMIT = 80
