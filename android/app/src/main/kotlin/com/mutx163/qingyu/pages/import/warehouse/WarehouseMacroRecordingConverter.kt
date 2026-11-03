package com.mutx163.qingyu.pages.import.warehouse

/**
 * 录制事件流 → 宏步骤（I2-4；逐字对齐 Dart `MacroRecordingConverter.convert` +
 * `compactMacroFillSteps` + `isRedundantSubmitAfterClick`）。
 *
 * 转换规则（Dart 原义，改了回放就会对不上）：
 * - 事件先去重（timestamp|eventType|selector|fieldType|value 五元组）；
 * - 相邻事件间隔 1.5s~60s 插 delay：≤5s 按实际间隔，>5s 记标准 3s；
 * - 同一输入框的连续 input/change 只留**最终值**（pending fill，遇其他动作才落盘）；
 * - 敏感字段（password/captcha）不落值，转成一次性 `waitForManualInput`（按选择器去重）；
 * - click 后补 800ms、submit 后补 2500ms 等待；
 * - 「点提交按钮」紧跟着的所属表单 submit 是**同一次动作**：丢弃 submit 的点击步骤、
 *   只保留等待（2026-10-21 城科实测：不丢会在跳转后的新页面上点一个不存在的表单，
 *   整条宏失败）；
 * - 收尾再做一次 [compactWarehouseMacroFillSteps]：相邻同选择器 fillField 合并为最终值，
 *   夹在中间的 delay 一并去掉。
 */
object WarehouseMacroRecordingConverter {

    private class PendingFill(val selector: String, val value: String, val fieldType: String?)

    fun convert(rawEvents: List<Map<String, Any?>>): List<WarehouseMacroStep> {
        if (rawEvents.isEmpty()) return emptyList()
        val deduped = dedupeRawEvents(rawEvents)
        if (deduped.isEmpty()) return emptyList()

        val steps = ArrayList<WarehouseMacroStep>()
        val sensitiveSelectors = HashSet<String>()
        val pendingFillBySelector = LinkedHashMap<String, PendingFill>()
        val startTime = deduped.first()["timestamp"].asLong() ?: 0L
        var lastTimestamp = startTime
        var previousEventType = ""
        var previousFieldType: String? = null
        var previousFormSelector: String? = null

        fun flushPendingFillFields() {
            if (pendingFillBySelector.isEmpty()) return
            for (pending in pendingFillBySelector.values) {
                steps.add(
                    WarehouseMacroStep.fillField(
                        selector = pending.selector,
                        value = pending.value,
                        fieldType = pending.fieldType,
                    ),
                )
            }
            pendingFillBySelector.clear()
        }

        for (event in deduped) {
            val eventType = event["eventType"] as? String ?: ""
            val selector = event["selector"] as? String ?: ""
            val value = event["value"] as? String ?: ""
            val fieldType = event["fieldType"] as? String
            val timestamp = event["timestamp"].asLong() ?: lastTimestamp

            val gap = timestamp - lastTimestamp
            if (gap in 1501..59999) {
                // 先落盘已有输入，再插入等待，避免 delay 夹在同一字段的中间按键之间。
                flushPendingFillFields()
                if (gap <= 5000) {
                    steps.add(WarehouseMacroStep.delay(gap.toInt()))
                } else {
                    steps.add(WarehouseMacroStep.delay(3000))
                }
            }

            val redundantSubmit = eventType == "submit" && isRedundantSubmitAfterClick(
                previousEventType = previousEventType,
                previousFieldType = previousFieldType,
                previousFormSelector = previousFormSelector,
                currentSelector = selector,
                gapMs = gap,
            )

            when (eventType) {
                "input", "change" -> {
                    if (isSensitiveWarehouseMacroFieldType(fieldType)) {
                        flushPendingFillFields()
                        val sensitiveKey = selector.ifEmpty { fieldType.orEmpty() }
                        if (sensitiveKey.isNotEmpty() && sensitiveSelectors.add(sensitiveKey)) {
                            steps.add(
                                WarehouseMacroStep.waitForManualInput(
                                    warehouseManualInputReasonForFieldType(fieldType),
                                    selector = selector,
                                    fieldType = fieldType,
                                ),
                            )
                        }
                    } else if (selector.isNotEmpty()) {
                        // 连续 keystroke 只更新缓存，最终 flush 时写成单步 fillField。
                        pendingFillBySelector[selector] = PendingFill(selector, value, fieldType)
                    }
                }

                "click" -> {
                    flushPendingFillFields()
                    if (selector.isNotEmpty()) {
                        steps.add(WarehouseMacroStep.click(selector))
                        // Allow navigation/DOM updates before the next step.
                        steps.add(WarehouseMacroStep.delay(800))
                    }
                }

                "submit" -> {
                    flushPendingFillFields()
                    // 若这条 submit 是上一条「点提交按钮」的同一次动作，**不生成点击步骤**，
                    // 但等待要保留：它表达的是「等这次提交把页面带走」。
                    if (selector.isNotEmpty() && !redundantSubmit) {
                        steps.add(WarehouseMacroStep.click(selector))
                    }
                    steps.add(WarehouseMacroStep.delay(2500))
                }
            }

            lastTimestamp = timestamp
            previousEventType = eventType
            previousFieldType = fieldType
            previousFormSelector = event["formSelector"] as? String
        }

        flushPendingFillFields()
        return compactWarehouseMacroFillSteps(steps)
    }

    private fun dedupeRawEvents(rawEvents: List<Map<String, Any?>>): List<Map<String, Any?>> {
        val seen = HashSet<String>()
        val deduped = ArrayList<Map<String, Any?>>(rawEvents.size)
        for (event in rawEvents) {
            val key = listOf(
                event["timestamp"]?.toString().orEmpty(),
                event["eventType"]?.toString().orEmpty(),
                event["selector"]?.toString().orEmpty(),
                event["fieldType"]?.toString().orEmpty(),
                event["value"]?.toString().orEmpty(),
            ).joinToString("|")
            if (seen.add(key)) {
                deduped.add(event)
            }
        }
        return deduped
    }

    /** JS 时间戳是 Number（Long 或 Double 都有可能，取决于 MiniJson 解析路径）。 */
    private fun Any?.asLong(): Long? = when (this) {
        is Long -> this
        is Int -> toLong()
        is Double -> toLong()
        is Float -> toLong()
        is Number -> toLong()
        is String -> trim().toLongOrNull()
        else -> null
    }
}

/**
 * 「submit 是上一条『点提交按钮』的同一次动作」的判据
 * （Dart `isRedundantSubmitAfterClick`，`warehouse_macro_replay_logic.dart`）。
 */
fun isRedundantSubmitAfterClick(
    previousEventType: String,
    previousFieldType: String?,
    previousFormSelector: String?,
    currentSelector: String,
    gapMs: Long,
): Boolean {
    // 上一条必须是「点提交按钮」：只有 input[type=submit|button] 会带 formSelector。
    if (previousEventType != "click") return false
    if (previousFieldType != "button") return false
    val form = previousFormSelector?.trim().orEmpty()
    if (form.isEmpty()) return false
    // 同一次动作的两个事件紧挨着；窗口外说明是用户先做了别的、之后才提交。
    if (gapMs < 0 || gapMs > 2000) return false
    return currentSelector.trim() == form
}

/**
 * 将相邻的同选择器 `fillField` 合并为最终值（Dart `compactMacroFillSteps`）。
 *
 * 旧宏可能按按键逐步记录 `a` → `ab` → `abc`，回放时会先清空再像打字一样重输。
 * 新录制与加载旧录制都应走此压缩，只保留每个连续输入序列的最终值。
 */
fun compactWarehouseMacroFillSteps(steps: List<WarehouseMacroStep>): List<WarehouseMacroStep> {
    if (steps.isEmpty()) return emptyList()
    val compacted = ArrayList<WarehouseMacroStep>()
    for (step in steps) {
        if (step.type != WarehouseMacroStepType.FILL_FIELD) {
            compacted.add(step)
            continue
        }
        val selector = step.selector.orEmpty()
        if (selector.isEmpty()) {
            compacted.add(step)
            continue
        }

        // 跳过中间 delay：用户逐字输入时的自然停顿不应拆成多次填充。
        var mergeIndex = compacted.size - 1
        while (mergeIndex >= 0 && compacted[mergeIndex].type == WarehouseMacroStepType.DELAY) {
            mergeIndex--
        }

        if (mergeIndex >= 0 &&
            compacted[mergeIndex].type == WarehouseMacroStepType.FILL_FIELD &&
            compacted[mergeIndex].selector == selector
        ) {
            val previous = compacted[mergeIndex]
            compacted[mergeIndex] = WarehouseMacroStep.fillField(
                selector = selector,
                value = step.value ?: previous.value.orEmpty(),
                fieldType = step.fieldType ?: previous.fieldType,
            )
            // 合并后去掉夹在两次 fill 之间的 delay。
            if (mergeIndex < compacted.size - 1) {
                compacted.subList(mergeIndex + 1, compacted.size).clear()
            }
            continue
        }

        compacted.add(step)
    }
    return compacted
}
