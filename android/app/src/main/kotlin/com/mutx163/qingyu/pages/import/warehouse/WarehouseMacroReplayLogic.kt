package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * 宏回放的「与真实页面打交道」判据面（P2 / N7-N10 的纯函数部分）。
 *
 * 逐字对齐 Dart 参照物（只读，不许改）：
 * - `lib/domain/warehouse_macro_replay_logic.dart`（等待/找到/换页/作废步骤/选择器候选/
 *   complete 处置/结果归一化）；
 * - `lib/domain/warehouse_macro_dialog_replay.dart`（文字→下标还原）；
 * - `lib/domain/warehouse_bridge_gate.dart`（成功/进度 toast 抑制判据）。
 *
 * 预算数值**逐字保留**：等元素默认 10s、等导航/URL/选择器默认 15s、轮询一拍 300ms。
 */

/** 等某个 DOM 元素出现（填充 / 点击）的默认时长（Dart `defaultMacroElementWaitMs`）。 */
const val DEFAULT_MACRO_ELEMENT_WAIT_MS = 10000

/** 开始回放前等入口页成为完整文档的上限（毫秒，Dart `entryReadyTimeout = 15s`）。 */
const val MACRO_ENTRY_READY_TIMEOUT_MS = 15000L

/** 等导航/URL/选择器没声明预算时的默认值（Dart 硬编码 15000）。 */
const val MACRO_DEFAULT_NAVIGATION_WAIT_MS = 15000

/** 轮询节拍（Dart `Future.delayed(300ms)`）。 */
const val MACRO_POLL_INTERVAL_MS = 300L

/** 脚本发来 `complete` 时该怎么收尾（Dart `ImportCompletionAction`）。 */
enum class WarehouseImportCompletionAction {
    /** 正常收尾：复位执行期、状态写「导入流程已完成」。 */
    FINALIZE,

    /** 宏回放还在等课程数据：只更新状态文字，不动执行期标记。 */
    SHOW_STATUS_ONLY,

    /** 本轮导入已经定局（取消/失败/超时/写完），不再由 complete 改写。 */
    IGNORE,
}

/**
 * `complete` 的处置判定（Dart `importCompletionAction`，判定顺序逐字一致）。
 *
 * 关键点：`saveImportedCourses` 在 JS 侧是 fire-and-forget——脚本 postMessage 完
 * 立刻返回，课程解析/写库在原生侧还在异步跑。所以脚本随后发的 `complete` 完全
 * 可能落在「本轮已定局」之后：不忽略它，用户取消掉的导入会在状态栏显示成功。
 * 执行期已结束的 `complete` 一律 [WarehouseImportCompletionAction.IGNORE]。
 */
fun warehouseImportCompletionAction(
    importExecutionActive: Boolean,
    macroReplayActive: Boolean,
    playbackWaitingForCourses: Boolean,
    quickResultHandled: Boolean,
): WarehouseImportCompletionAction {
    if (!importExecutionActive) return WarehouseImportCompletionAction.IGNORE
    if (macroReplayActive && playbackWaitingForCourses) {
        return WarehouseImportCompletionAction.SHOW_STATUS_ONLY
    }
    if (macroReplayActive && quickResultHandled) {
        return WarehouseImportCompletionAction.IGNORE
    }
    return WarehouseImportCompletionAction.FINALIZE
}

/**
 * 回放开始前，入口网页是不是已经成了「有内容的完整文档」（Dart `isEntryDocumentReady`）。
 *
 * 宿主在页面第一帧就启动回放，那一刻 WebView 里往往还是 `about:blank`：没有这道门，
 * 第一步填账号直接打在空白文档上（实测打开网页到回放启动只隔 2ms）。
 * 判据刻意宽松：href 非空白页且 readyState 为 complete 即放行；慢站由每步自己的
 * 10s 元素预算兜住。
 */
fun isWarehouseEntryDocumentReady(href: String?, readyState: String?): Boolean {
    val value = href?.trim() ?: return false
    if (value.isEmpty()) return false
    // about:blank / about:srcdoc 是 WebView 的初始空文档，不是学校的页面。
    if (value.startsWith("about:")) return false
    return readyState == "complete"
}

/**
 * 回放 navigate 的等待判据：当前文档是不是「已经落到目标页并且加载完成」。
 *
 * 判据是 href 相对导航前**发生了变化**且 readyState 为 complete——只看「URL 非空」
 * 不够（旧页面本来就非空，那种轮询第一拍就过，等于没等）。
 * [targetHref] 只在「目标就是当前页（重载）」时参与判断：那时 href 不会变化，
 * 退化成只要 complete 就算好。
 */
fun isWarehouseTargetDocumentLoaded(
    beforeHref: String?,
    currentHref: String?,
    readyState: String?,
    targetHref: String,
): Boolean {
    if (currentHref.isNullOrEmpty()) return false
    if (readyState != "complete") return false
    val before = normalizeMacroHref(beforeHref)
    val current = normalizeMacroHref(currentHref)
    val target = normalizeMacroHref(targetHref)
    if (before == null) return true
    if (target != null && current == target) return true
    return before != current
}

/**
 * 两个 href 是不是「不同的文档」（忽略 fragment；Dart `macroDocumentChanged`）。
 *
 * 用于判断「上一步点击有没有把页面带走」：`?x=1` 与 `#/tab` 这种不算换页，
 * 只有 scheme+host+path 变了才说明旧页面的元素真的随之作废。
 * 任一 href 读不到返回 false（判不准就别认定换了页）。
 */
fun warehouseMacroDocumentChanged(beforeHref: String?, currentHref: String?): Boolean {
    val before = normalizeMacroHref(beforeHref) ?: return false
    val current = normalizeMacroHref(currentHref) ?: return false
    val beforeKey = macroHrefDocumentKey(before) ?: return before != current
    val currentKey = macroHrefDocumentKey(current) ?: return before != current
    return beforeKey != currentKey
}

/** 去掉 fragment 再比对；导航到 `#xxx` 只是换锚点，不该被当成两个页面。 */
private fun normalizeMacroHref(href: String?): String? {
    val value = href?.trim()
    if (value.isNullOrEmpty()) return null
    val fragmentIndex = value.indexOf('#')
    return if (fragmentIndex < 0) value else value.substring(0, fragmentIndex)
}

/** `scheme://host/path` 的小写文档键（query/fragment 不参与）；解析不出 host 返回 null。 */
private fun macroHrefDocumentKey(href: String): String? {
    val schemeEnd = href.indexOf("://")
    if (schemeEnd <= 0) return null
    var rest = href.substring(schemeEnd + 3)
    // query / fragment 不参与换页判定（`?x=1`、`#/tab` 都不算换页，与 Dart Uri.host/path 同口径）。
    val hashAt = rest.indexOf('#')
    if (hashAt >= 0) rest = rest.substring(0, hashAt)
    val queryAt = rest.indexOf('?')
    if (queryAt >= 0) rest = rest.substring(0, queryAt)
    val slashAt = rest.indexOf('/')
    val authority = if (slashAt >= 0) rest.substring(0, slashAt) else rest
    val path = if (slashAt >= 0) rest.substring(slashAt) else "/"
    // authority 去 userinfo / 端口（与 warehouseUrlHost 同口径的极简版）。
    var host = authority
    val userAt = host.lastIndexOf('@')
    if (userAt >= 0) host = host.substring(userAt + 1)
    if (!host.startsWith("[")) {
        val colonAt = host.lastIndexOf(':')
        if (colonAt >= 0 && host.substring(colonAt + 1).all { it in '0'..'9' }) {
            host = host.substring(0, colonAt)
        }
    }
    return "http://${host.lowercase()}$path"
}

/**
 * 一条「找不到元素」的点击步骤，是不是记录时留下的、已经作废的步骤。
 *
 * 三条件同时成立才跳过（Dart `shouldSkipStaleClickStep`）：是点击 + 元素确实没找到
 * （脚本明确回报）+ 上一步点击刚把页面带走。第 3 条是关键收紧项：页面没动还说
 * 找不到，就是真的缺东西，必须如实失败。
 */
fun shouldSkipWarehouseStaleClickStep(
    stepIsClick: Boolean,
    elementNotFound: Boolean,
    previousClickNavigated: Boolean,
): Boolean = stepIsClick && elementNotFound && previousClickNavigated

/**
 * 等待元素的结果判定：只有明确回报 `found: true` 才算真的找到了。
 * 读不懂（脚本抛错、上下文被导航销毁、空串）一律「还没找到」，继续轮到超时——
 * 绝不把「读不懂」当成「做成了」。
 */
fun warehouseMacroElementFound(normalizedResult: String?): Boolean {
    if (normalizedResult.isNullOrEmpty()) return false
    val decoded = MiniJson.tryParse(normalizedResult) as? Map<*, *> ?: return false
    return decoded["found"] == true
}

/** 脚本明确回报「没找到」（`found: false`）；读不懂不算「明确没找到」。 */
fun warehouseMacroElementExplicitlyMissing(normalizedResult: String?): Boolean {
    if (normalizedResult.isNullOrEmpty()) return false
    val decoded = MiniJson.tryParse(normalizedResult) as? Map<*, *> ?: return false
    return decoded["found"] == false
}

/**
 * 一个选择器之外还该试的等价选择器（Dart `macroSelectorCandidates`）。
 *
 * 只在选择器是纯 id 形态（`#foo`）时派生 `input[name="foo"]`——真正的意图是
 * 「旧录制把 id 当选择器存了，而页面只写了 name」。含空格/子选择器/属性的一律不派生。
 */
fun warehouseMacroSelectorCandidates(selector: String): List<String> {
    val trimmed = selector.trim()
    if (trimmed.isEmpty()) return emptyList()
    val candidates = mutableListOf(trimmed)
    if (trimmed.startsWith("#") &&
        trimmed.length > 1 &&
        !trimmed.contains(" ") &&
        !trimmed.contains(">") &&
        !trimmed.contains("[") &&
        !trimmed.substring(1).contains("\"")
    ) {
        candidates.add("input[name=\"${trimmed.substring(1)}\"]")
    }
    return candidates
}

/**
 * 把录制下来的**选项文字**还原成脚本要的**序号**（Dart `resolveRecordedSelectionIndex`）。
 *
 * 三种回法都要认：文字（录制侧存的是 `options[用户选的下标]` 的文字）优先；
 * 数字/数字串（下标）其次——必须解析后再比，不能直接字符串相等；
 * 都换算不出回退脚本给的默认下标（**不是**取消：答案过期时退回脚本默认值
 * 是用户能预期的行为）。换算不出且默认下标越界返回 null（绝不返回越界下标）。
 */
fun resolveWarehouseRecordedSelectionIndex(
    recorded: Any?,
    options: List<String>,
    fallbackIndex: Int,
): Int? {
    matchWarehouseOptionByText(recorded, options)?.let { return it }
    matchWarehouseOptionByIndex(recorded, options.size)?.let { return it }
    if (fallbackIndex < 0 || fallbackIndex >= options.size) return null
    return fallbackIndex
}

/** 文字精确匹配（trim 后整串相等，同名取第一个）。 */
private fun matchWarehouseOptionByText(recorded: Any?, options: List<String>): Int? {
    val text = (recorded as? String)?.trim() ?: return null
    if (text.isEmpty()) return null
    for (i in options.indices) {
        if (options[i] == text) return i
    }
    return null
}

/** 数字 / 数字串下标（小数不是合法下标；越界返回 null）。 */
private fun matchWarehouseOptionByIndex(recorded: Any?, length: Int): Int? {
    val index = when (recorded) {
        is Int -> recorded
        is Long -> recorded.toInt()
        is Double ->
            // 小数不是合法下标（Dart：recorded != roundToDouble() → null）。
            if (recorded.isFinite() && recorded == Math.floor(recorded)) recorded.toInt() else null
        is String -> recorded.trim().toIntOrNull()
        else -> null
    }
    if (index == null || index < 0 || index >= length) return null
    return index
}

/**
 * 成功类脚本 toast 的抑制判据（Dart `isScriptImportSuccessToast` 逐字一致）。
 * 回放期间完成 sheet 已会展示结果，这类轻提示一律丢弃，不叠两条。
 */
fun isWarehouseScriptImportSuccessToast(message: String?): Boolean {
    val text = message?.trim() ?: return false
    if (text.isEmpty()) return false
    val lower = text.lowercase()
    return text.contains("成功导入") ||
        text.contains("导入成功") ||
        text.contains("导入完成") ||
        (text.contains("导入") && text.contains("条课程")) ||
        lower.contains("import success") ||
        (lower.contains("imported") && lower.contains("course"))
}

/**
 * 进度类脚本 toast 的抑制判据（Dart `isScriptImportProgressToast` 逐字一致）。
 * 「正在获取课表…」这类提示与回放覆盖层重复。
 */
fun isWarehouseScriptImportProgressToast(message: String?): Boolean {
    val text = message?.trim() ?: return false
    if (text.isEmpty()) return false
    return text.contains("正在通过接口") ||
        text.contains("正在获取") ||
        text.contains("正在导入") ||
        text.contains("请稍候") ||
        text.contains("请稍等")
}
