package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.net.URI
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 宏回放的**纯逻辑**（I2-5；逐条对齐 Dart `lib/domain/warehouse_macro_replay_logic.dart`）。
 *
 * 回放引擎（`WarehouseMacroReplayer`）本身离不开真 WebView，没法在 JVM 上测；
 * 但「什么时候算找到了元素」「录制的选项文字怎么换回下标」「navigate 到底等到了没有」
 * 这些判据全是纯函数，抽出来才能钉住录制口径与回放口径不漂移。
 */

/** 等某个 DOM 元素出现（填充 / 点击）的默认时长，Dart 同值。 */
const val DEFAULT_MACRO_ELEMENT_WAIT_MS = 10000

/** 录制期记住的学期配置（Dart `dialogResponses['semesterConfig']`）。 */
data class RecordedSemesterConfig(
    val semesterStartDate: LocalDateTime,
    val firstCourseWeek: Int,
)

/**
 * 还原录制期的学期配置。任一字段缺失/无法解析 → null（退回弹窗让用户重选）。
 *
 * 与 Dart 的读取口径一致：`startDate` 是 `DateTime.toIso8601String()`，
 * `firstCourseWeek` 是整数；Dart 用 `as int?`，这里对 JSON 数字统一取整。
 */
fun parseRecordedSemesterConfig(raw: Any?): RecordedSemesterConfig? {
    val map = raw as? Map<*, *> ?: return null
    val startRaw = (map["startDate"] as? String)?.trim().orEmpty()
    if (startRaw.isEmpty()) return null
    val start = runCatching {
        LocalDateTime.parse(startRaw, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
    }.getOrNull() ?: return null
    val week = (map["firstCourseWeek"] as? Number)?.toInt() ?: return null
    if (week < 1) return null
    return RecordedSemesterConfig(semesterStartDate = start, firstCourseWeek = week)
}

/** 把录制到的「选项文字」换算成脚本契约要的下标；换算不出来回 null（绝不越界）。 */
fun matchRecordedOptionIndex(options: List<String>, recorded: Any?): Int? {
    if (options.isEmpty() || recorded == null) return null
    if (recorded is Number) {
        val index = recorded.toInt()
        return if (index in options.indices) index else null
    }
    val label = recorded.toString()
    val index = options.indexOf(label)
    return if (index >= 0) index else null
}

private fun normalizeHref(href: String?): String? {
    val value = href?.trim().orEmpty()
    if (value.isEmpty()) return null
    val fragmentIndex = value.indexOf('#')
    return if (fragmentIndex < 0) value else value.substring(0, fragmentIndex)
}

/**
 * `navigate` 的等待判据：目标文档已经落到目标页并加载完成。
 *
 * 只看「URL 非空」不够——导航前的旧页面本来就非空，第一拍就会误判通过。
 */
fun isTargetDocumentLoaded(
    beforeHref: String?,
    currentHref: String?,
    readyState: String?,
    targetHref: String,
): Boolean {
    if (currentHref.isNullOrEmpty()) return false
    if (readyState != "complete") return false
    val before = normalizeHref(beforeHref)
    val current = normalizeHref(currentHref)
    val target = normalizeHref(targetHref)
    if (before == null) return true
    if (target != null && current == target) return true
    return before != current
}

/** 回放开始前入口网页是不是「有内容的完整文档」（不是 about:blank 半截页）。 */
fun isEntryDocumentReady(href: String?, readyState: String?): Boolean {
    val value = href?.trim().orEmpty()
    if (value.isEmpty()) return false
    if (value.startsWith("about:")) return false
    return readyState == "complete"
}

/** 等元素的轮询判定：只有明确 `found: true` 才算找到；读不懂继续等。 */
fun macroElementFound(normalizedResult: String): Boolean =
    macroFoundFlag(normalizedResult) == true

/** 断言场景：只有明确 `found: false` 才算「明确没找到」；读不懂不等于没找到。 */
fun macroElementExplicitlyMissing(normalizedResult: String): Boolean =
    macroFoundFlag(normalizedResult) == false

private fun macroFoundFlag(normalizedResult: String): Boolean? {
    if (normalizedResult.isEmpty()) return null
    val decoded = MiniJson.tryParse(normalizedResult) as? Map<*, *> ?: return null
    return decoded["found"] as? Boolean
}

/** 两个 href 是不是「不同的文档」（忽略 query 与 fragment）。 */
fun macroDocumentChanged(beforeHref: String?, currentHref: String?): Boolean {
    val before = normalizeHref(beforeHref) ?: return false
    val current = normalizeHref(currentHref) ?: return false
    val beforeUri = runCatching { URI(before) }.getOrNull()
    val currentUri = runCatching { URI(current) }.getOrNull()
    if (beforeUri == null || currentUri == null) return before != current
    if (beforeUri.scheme == null || currentUri.scheme == null) return before != current
    val beforeKey = "${beforeUri.scheme}://${beforeUri.host}${beforeUri.path.orEmpty()}"
    val currentKey = "${currentUri.scheme}://${currentUri.host}${currentUri.path.orEmpty()}"
    return beforeKey.lowercase() != currentKey.lowercase()
}

/**
 * 旧宏里「点按钮」后面那条等价于表单的 submit 点击是否已经作废。
 *
 * 三条同时成立才跳过：点击步骤、元素明确 found:false、上一步点击刚把页面带走。
 */
fun shouldSkipStaleClickStep(
    stepIsClick: Boolean,
    elementNotFound: Boolean,
    previousClickNavigated: Boolean,
): Boolean = stepIsClick && elementNotFound && previousClickNavigated

/**
 * 一个选择器之外还该试的等价选择器。
 *
 * 只有纯 id 形态（`#foo`）才派生 `input[name="foo"]`；把整条选择器当 name 用是旧实现的坏兜底。
 */
fun macroSelectorCandidates(selector: String): List<String> {
    val trimmed = selector.trim()
    if (trimmed.isEmpty()) return emptyList()
    val candidates = mutableListOf(trimmed)
    if (
        trimmed.startsWith("#") &&
        trimmed.length > 1 &&
        !trimmed.contains(' ') &&
        !trimmed.contains('>') &&
        !trimmed.contains('[') &&
        !trimmed.substring(1).contains('"')
    ) {
        candidates.add("input[name=\"${trimmed.substring(1)}\"]")
    }
    return candidates
}

/** 快捷导入的缩短路径（Dart `buildAcceleratedMacroSteps`，逐条同口径）。 */
fun buildAcceleratedMacroSteps(
    originalSteps: List<WarehouseMacroStep>,
    scriptPageUrl: String?,
    importUrl: String?,
): List<WarehouseMacroStep> {
    if (originalSteps.isEmpty()) return originalSteps
    val authPrefix = macroAuthPrefixSteps(originalSteps)
    if (authPrefix.isEmpty()) return originalSteps
    val droppedStepCount = originalSteps.size - authPrefix.size
    if (droppedStepCount < 2) return originalSteps

    val sanitizedScriptPageUrl = sanitizeWarehouseScriptPageUrl(scriptPageUrl)
    val sanitizedImportUrl = sanitizeWarehouseScriptPageUrl(importUrl)

    if (sanitizedScriptPageUrl != null) {
        if (sanitizedImportUrl != null && sanitizedImportUrl == sanitizedScriptPageUrl) {
            return authPrefix
        }
        return authPrefix + listOf(
            WarehouseMacroStep.navigate(sanitizedScriptPageUrl),
            WarehouseMacroStep.delay(1000),
        )
    }
    return authPrefix
}

/** 录到「最后一次填充/等待手动输入」为止，再吃掉紧跟的一次点击（可带一个 delay）。 */
private fun macroAuthPrefixSteps(originalSteps: List<WarehouseMacroStep>): List<WarehouseMacroStep> {
    var lastAuthStepIndex = -1
    originalSteps.forEachIndexed { index, step ->
        if (
            step.type == WarehouseMacroStepType.FILL_FIELD ||
            step.type == WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT
        ) {
            lastAuthStepIndex = index
        }
    }
    if (lastAuthStepIndex < 0) return emptyList()

    var authPrefixEndIndex = lastAuthStepIndex
    var index = lastAuthStepIndex + 1
    while (index < originalSteps.size && index <= lastAuthStepIndex + 3) {
        when (originalSteps[index].type) {
            WarehouseMacroStepType.CLICK -> {
                authPrefixEndIndex = index
                if (
                    index + 1 < originalSteps.size &&
                    originalSteps[index + 1].type == WarehouseMacroStepType.DELAY
                ) {
                    authPrefixEndIndex = index + 1
                }
                break
            }

            WarehouseMacroStepType.DELAY -> {
                authPrefixEndIndex = index
                index++
            }

            else -> break
        }
    }
    return originalSteps.subList(0, authPrefixEndIndex + 1)
}
