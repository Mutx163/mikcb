package com.mutx163.qingyu.pages.import.warehouse

/**
 * 录制事件 → 宏步骤的转换层（P1 / N4）。
 *
 * 逐字对齐 Dart 参照物（只读，不许改）：
 * - `lib/widgets/warehouse_macro_recorder.dart` 的 `MacroRecordingConverter.convert` /
 *   `compactMacroFillSteps`；
 * - `lib/domain/warehouse_macro_replay_logic.dart` 的 `isRedundantSubmitAfterClick`。
 *
 * 转换规则（与旧版一一对应）：
 * - 原始事件先按五元组（时间戳/类型/选择器/字段类型/值）去重；
 * - 相邻事件间隔 >1.5s 且 <60s 插入 delay 步：≤5s 记精确值，>5s 记 3s 标准等待；
 *   插 delay 前先落盘已缓存的输入；
 * - `input` / `change`：敏感字段 → `waitForManualInput`（每个选择器只记一次）；
 *   普通字段进 pending 缓存，同一选择器连续按键只保留最终值，flush 时写成单条
 *   `fillField`；
 * - `click` → click + delay(800)；
 * - `submit` → 非冗余时 click(表单选择器) + delay(2500)；冗余 submit（上一条是
 *   点提交按钮、间隔 ≤2s、当前选择器等于该表单）整条丢弃——点按钮已触发提交，
 *   而 submit 的选择器是表单本身，跳转后必然找不到（2026-10-21 城科实测事故）；
 * - 输出前再过 [compactMacroFillSteps]：合并相邻同选择器 fillField（跳过中间 delay），
 *   兼容逐字录制的旧宏。
 */
object WarehouseMacroRecordingConverter {

    /**
     * 「click + submit 是同一个动作」的冗余判定（Dart `isRedundantSubmitAfterClick`）。
     *
     * 上一条必须是「点提交按钮」：只有 `input[type=submit|button]` 会带 formSelector。
     * 两个事件紧挨着（≤2s）才算是同一次动作；窗口外说明用户先做了别的、之后才提交。
     */
    fun isRedundantSubmitAfterClick(
        previousEventType: String,
        previousFieldType: String?,
        previousFormSelector: String?,
        currentSelector: String,
        gapMs: Int,
    ): Boolean {
        if (previousEventType != "click") return false
        if (previousFieldType != "button") return false
        val form = previousFormSelector?.trim() ?: ""
        if (form.isEmpty()) return false
        if (gapMs < 0 || gapMs > SUBMIT_AFTER_CLICK_WINDOW_MS) return false
        return currentSelector.trim() == form
    }

    /**
     * 将原始录制事件列表转换为 [WarehouseMacroStep] 列表，并按事件时间戳自动插入 delay 步。
     *
     * 输入元素是录制 JS 上报的事件 map（eventType / selector / value / fieldType /
     * timestamp / formSelector），形状与 Dart 侧完全一致。
     */
    fun convert(rawEvents: List<Map<String, Any?>>): List<WarehouseMacroStep> {
        if (rawEvents.isEmpty()) return emptyList()

        val dedupedEvents = dedupeRawEvents(rawEvents)
        if (dedupedEvents.isEmpty()) return emptyList()

        val steps = ArrayList<WarehouseMacroStep>()
        val sensitiveSelectors = HashSet<String>()
        // 同一输入框连续按键只保留最终值，避免回放时「先整段填充再逐字覆盖」。
        val pendingFillBySelector = LinkedHashMap<String, PendingFillField>()
        val startTime = (dedupedEvents.first()["timestamp"] as? Number)?.toLong() ?: 0L
        var lastTimestamp = startTime
        // 「上一条事件」的类型与选择器：用于识别「click + submit 是同一个动作」。
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

        for (event in dedupedEvents) {
            val eventType = event["eventType"] as? String ?: ""
            val selector = event["selector"] as? String ?: ""
            val value = event["value"] as? String ?: ""
            val fieldType = event["fieldType"] as? String
            val timestamp = (event["timestamp"] as? Number)?.toLong() ?: lastTimestamp

            // 事件间隔超过 1.5 秒：先落盘已有输入，再插入等待，
            // 避免 delay 夹在同一字段的中间按键之间。
            val gap = timestamp - lastTimestamp
            if (gap > DELAY_INSERT_THRESHOLD_MS && gap < DELAY_INSERT_CAP_MS) {
                flushPendingFillFields()
                if (gap <= DELAY_PRECISE_LIMIT_MS) {
                    steps.add(WarehouseMacroStep.delay(gap.toInt()))
                } else {
                    steps.add(WarehouseMacroStep.delay(STANDARD_WAIT_MS))
                }
            }

            // 同一次「点登录」会先发 click、再发 submit：这两条是同一个动作。
            // 丢弃的是 submit 那条：click 已经足以触发提交，而 submit 的选择器是
            // 表单本身，跳转后必然找不到。但等待要保留：它表达「等这次提交把页面带走」。
            val redundantSubmit = eventType == "submit" &&
                isRedundantSubmitAfterClick(
                    previousEventType = previousEventType,
                    previousFieldType = previousFieldType,
                    previousFormSelector = previousFormSelector,
                    currentSelector = selector,
                    gapMs = gap.toInt(),
                )

            when (eventType) {
                "input", "change" -> {
                    if (isSensitiveMacroFieldType(fieldType)) {
                        flushPendingFillFields()
                        val sensitiveKey = selector.ifEmpty { fieldType ?: "" }
                        if (sensitiveKey.isNotEmpty() && sensitiveSelectors.add(sensitiveKey)) {
                            steps.add(
                                WarehouseMacroStep.waitForManualInput(
                                    reason = manualInputReasonForFieldType(fieldType),
                                    selector = selector,
                                    fieldType = fieldType,
                                ),
                            )
                        }
                    } else if (selector.isNotEmpty()) {
                        // 连续 keystroke 只更新缓存，最终 flush 时写成单步 fillField。
                        pendingFillBySelector[selector] = PendingFillField(selector, value, fieldType)
                    }
                }

                "click" -> {
                    flushPendingFillFields()
                    if (selector.isNotEmpty()) {
                        steps.add(WarehouseMacroStep.click(selector))
                        // Allow navigation/DOM updates before the next step.
                        steps.add(WarehouseMacroStep.delay(CLICK_SETTLE_MS))
                    }
                }

                "submit" -> {
                    flushPendingFillFields()
                    if (selector.isNotEmpty() && !redundantSubmit) {
                        steps.add(WarehouseMacroStep.click(selector))
                    }
                    steps.add(WarehouseMacroStep.delay(SUBMIT_SETTLE_MS))
                }
            }

            lastTimestamp = timestamp
            previousEventType = eventType
            previousFieldType = fieldType
            previousFormSelector = event["formSelector"] as? String
        }

        flushPendingFillFields()
        return compactMacroFillSteps(steps)
    }

    /** 五元组去重（Dart `_dedupeRawEvents`，键拼接口径逐字一致）。 */
    private fun dedupeRawEvents(rawEvents: List<Map<String, Any?>>): List<Map<String, Any?>> {
        val seen = HashSet<String>()
        val deduped = ArrayList<Map<String, Any?>>()
        for (event in rawEvents) {
            val key = listOf(
                event["timestamp"]?.toString() ?: "",
                event["eventType"] ?: "",
                event["selector"] ?: "",
                event["fieldType"] ?: "",
                event["value"] ?: "",
            ).joinToString("|")
            if (seen.add(key)) {
                deduped.add(event)
            }
        }
        return deduped
    }

    /**
     * 将相邻的同选择器 `fillField` 合并为最终值。
     *
     * 旧宏可能按按键逐步记录 `a` → `ab` → `abc`，回放时会先清空再像打字一样重输。
     * 新录制与加载旧录制都应走此压缩，只保留每个连续输入序列的最终值。
     * 中间的 delay 一并去掉：用户逐字输入时的自然停顿不应拆成多次填充。
     */
    fun compactMacroFillSteps(steps: List<WarehouseMacroStep>): List<WarehouseMacroStep> {
        if (steps.isEmpty()) return emptyList()

        val compacted = ArrayList<WarehouseMacroStep>()
        for (step in steps) {
            if (step.type != WarehouseMacroStepType.FILL_FIELD) {
                compacted.add(step)
                continue
            }
            val selector = step.selector ?: ""
            if (selector.isEmpty()) {
                compacted.add(step)
                continue
            }

            // 跳过中间 delay 找前一条 fillField。
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
                    value = step.value ?: previous.value ?: "",
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

    /** 间隔超过该值（毫秒）才考虑插 delay（Dart 硬编码 1500）。 */
    private const val DELAY_INSERT_THRESHOLD_MS = 1500L

    /** 间隔达到该值（毫秒）不再插等待（Dart 硬编码 60000）。 */
    private const val DELAY_INSERT_CAP_MS = 60000L

    /** 1.5~5s 记精确值，超过记标准等待（Dart 硬编码 5000 / 3000）。 */
    private const val DELAY_PRECISE_LIMIT_MS = 5000L
    private const val STANDARD_WAIT_MS = 3000

    private const val CLICK_SETTLE_MS = 800
    private const val SUBMIT_SETTLE_MS = 2500

    /** 冗余 submit 判定的间隔窗口（Dart 硬编码 2000）。 */
    private const val SUBMIT_AFTER_CLICK_WINDOW_MS = 2000
}

/** 待落盘的一次连续输入缓存（Dart `_PendingFillField`）。 */
private data class PendingFillField(
    val selector: String,
    val value: String,
    val fieldType: String?,
)
