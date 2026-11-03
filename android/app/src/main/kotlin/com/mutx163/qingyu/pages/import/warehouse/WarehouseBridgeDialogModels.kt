package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 网页对话框的**原生请求与回答契约**（F32 收口：原生界面接上后的另一半）。
 *
 * ## 协议从哪来
 *
 * 字段清单逐字对齐 Dart 宿主注入的桥接垫片（`warehouseImportScriptWrapper` 里的
 * `AndroidBridgePromise.*`）：网页侧 `postMessage` 什么，这里就解析什么——
 * `confirm {requestId,title,message,confirmText}`、`prompt {…,defaultValue,validatorName}`、
 * `singleSelection {…,optionsJson,selectedIndex}`、`saveCourseConfig/savePresetTimeSlots {…,payload}`。
 *
 * ## 回传结构（Promise 的 resolve 值，逐字对齐 Dart `_resolveJavaScriptRequest`）
 *
 * Dart 侧 `jsonEncode(value)` 后注入 `window.__qingyuResolvers[id](value)`；
 * [WarehouseBridgeDialogAnswer.jsonValue] 就是那个 value 的 JSON 文本：
 *
 * | 交互 | 确认 | 取消 / 超时 | 依据（Dart 宿主） |
 * |---|---|---|---|
 * | confirm | `true` / `false` | `false` | `showAppConfirmDialog` 的返回值过 `confirmed == true` |
 * | prompt | 带引号字符串 | `null` | `jsonEncode(result)`；取消时 result 为 null |
 * | singleSelection | 下标数字 | `null` | `jsonEncode(result)`；取消时 result 为 null |
 * | saveCourseConfig | `true`（已落盘） | `false` | 落盘成功 true / 失败 false |
 *
 * 「超时」在新版是对挂起请求回**取消值**（旧版导入超时不回话、脚本 Promise 悬死；
 * 新版脚本窗口结束时统一排空，回传结构与旧版「用户取消」完全一致）。
 * 「页面关闭」时 WebView 随组合销毁、JS 上下文不复存在，Promise 无处可挂——
 * 原生侧只保证挂起状态不泄漏（随组合销毁），与 Dart dispose 的行为一致。
 *
 * ## 与降级路径（[warehouseBridgeFallbackAnswer]）的关系
 *
 * 降级路径原样保留：解析不出结构（坏 JSON / `savePresetTimeSlots` 的数组载荷 /
 * 不可信 requestId）、或同刻已有挂起请求时，宿主走降级默认值回答——那套默认值的
 * 理由见 `WarehouseBridgeFallback.kt` 文件头的表格，两处口径必须一致。
 */

/** 一次原生对话框请求：解析自网页桥接消息，字段即网页端传入的原样内容。 */
sealed class WarehouseBridgeDialogRequest {
    abstract val requestId: String
    abstract val kind: WarehouseBridgeDialogKind

    /** 网页原样标题；空串 = 网页没给，渲染层负责兜底文案（模型层不碰文案）。 */
    abstract val title: String

    /** `confirm` / `showAlert`：两按钮确认框。 */
    data class Confirm(
        override val requestId: String,
        override val title: String,
        val message: String,
        /** 网页指定的确认按钮文字；空串 = 渲染层兜底。 */
        val confirmText: String,
    ) : WarehouseBridgeDialogRequest() {
        override val kind: WarehouseBridgeDialogKind get() = WarehouseBridgeDialogKind.CONFIRM
    }

    /** `prompt` / `showPrompt`：单行输入。 */
    data class Prompt(
        override val requestId: String,
        override val title: String,
        val message: String,
        val defaultValue: String,
        /** 非空时按内置校验器名单匹配（目前只有 `validateYearInput`，对齐 Dart）。 */
        val validatorName: String,
    ) : WarehouseBridgeDialogRequest() {
        override val kind: WarehouseBridgeDialogKind get() = WarehouseBridgeDialogKind.PROMPT

        /** 输入是否通过校验。对齐 Dart：`validateYearInput` 要求 `^[0-9]{4}$`，其余一律放行。 */
        fun validate(text: String): Boolean =
            if (validatorName == YEAR_VALIDATOR) text.matches(Regex("[0-9]{4}")) else true

        companion object {
            const val YEAR_VALIDATOR = "validateYearInput"
        }
    }

    /**
     * `singleSelection` / `showSingleSelection`：单选列表。
     *
     * `optionsJson` 解析失败按空列表（对齐 Dart 的 catch 分支：脚本侧数据异常
     * 不中断导入）；[selectedIndex] 已按选项范围钳住（对齐 Dart `currentSelection`）。
     */
    data class SingleSelection(
        override val requestId: String,
        override val title: String,
        val options: List<String>,
        val selectedIndex: Int,
    ) : WarehouseBridgeDialogRequest() {
        override val kind: WarehouseBridgeDialogKind get() = WarehouseBridgeDialogKind.SINGLE_SELECTION
    }

    /**
     * `saveCourseConfig`：多字段配置表单。
     *
     * 字段清单就是网页 payload 的顶层键值对（**键名原样渲染，不翻译**）。
     * `savePresetTimeSlots` 的载荷是数组而不是对象，解析不出字段表 → 返回 null
     * → 宿主走降级回答，本类型不承载它（诚实边界：应用作息模板的写链路未移植，
     * 不能弹一个「确认保存」却什么都没存）。
     */
    data class SaveConfig(
        override val requestId: String,
        override val title: String,
        val fields: List<WarehouseBridgeFormField>,
    ) : WarehouseBridgeDialogRequest() {
        override val kind: WarehouseBridgeDialogKind get() = WarehouseBridgeDialogKind.SAVE_COURSE_CONFIG
    }
}

/** payload 顶层的一个字段：键名 + MiniJson 解析出的原始值。 */
data class WarehouseBridgeFormField(val key: String, val value: Any?) {
    /** 按传入值类型归类控件；解析不出的形状（嵌套对象 / 数组 / null）一律只读。 */
    val kind: WarehouseBridgeFormFieldKind
        get() = when (value) {
            is Boolean -> WarehouseBridgeFormFieldKind.FLAG
            is Byte, is Short, is Int, is Long, is Float, is Double -> WarehouseBridgeFormFieldKind.NUMBER
            is String -> WarehouseBridgeFormFieldKind.TEXT
            else -> WarehouseBridgeFormFieldKind.READONLY
        }
}

enum class WarehouseBridgeFormFieldKind { TEXT, NUMBER, FLAG, READONLY }

/**
 * 一个字段的编辑态：渲染层每字段持一份，确认时经 [warehouseBridgeFormFieldValue]
 * 重组回值树。抽成纯数据是为了「编辑 → 取值」整段在 JVM 测试里直测。
 */
data class WarehouseBridgeFormFieldEdit(
    val key: String,
    val kind: WarehouseBridgeFormFieldKind,
    val original: Any?,
    /** TEXT / NUMBER 的当前输入文本；FLAG / READONLY 恒为空串。 */
    val text: String,
    /** FLAG 的当前开关值（初值 = 网页原值）；其余类型恒 null。 */
    val flagValue: Boolean? = null,
)

/** 字段清单 → 初始编辑态（初值 = 网页原值）。 */
fun warehouseBridgeFormFieldEdits(fields: List<WarehouseBridgeFormField>): List<WarehouseBridgeFormFieldEdit> =
    fields.map { field ->
        WarehouseBridgeFormFieldEdit(
            key = field.key,
            kind = field.kind,
            original = field.value,
            text = when (field.kind) {
                WarehouseBridgeFormFieldKind.TEXT -> (field.value as? String).orEmpty()
                WarehouseBridgeFormFieldKind.NUMBER -> MiniJson.encode(field.value)
                WarehouseBridgeFormFieldKind.FLAG -> ""
                WarehouseBridgeFormFieldKind.READONLY -> ""
            },
            flagValue = (field.value as? Boolean),
        )
    }

/** 切换一个 FLAG 字段的开关值（渲染层开关回调用的不可变更新）。 */
fun WarehouseBridgeFormFieldEdit.withFlagValue(value: Boolean): WarehouseBridgeFormFieldEdit =
    copy(flagValue = value)

/**
 * 单字段编辑后的值。
 *
 * NUMBER 解析失败时回**原值**而不是 null：一个输坏的数字不许把配置悄悄改没
 * （落盘侧「非法值不覆盖用户设置」的同一口径）。
 */
fun warehouseBridgeFormFieldValue(edit: WarehouseBridgeFormFieldEdit): Any? = when (edit.kind) {
    WarehouseBridgeFormFieldKind.TEXT -> edit.text
    WarehouseBridgeFormFieldKind.NUMBER ->
        edit.text.trim().toLongOrNull() ?: edit.text.trim().toDoubleOrNull() ?: edit.original
    WarehouseBridgeFormFieldKind.FLAG -> edit.flagValue ?: edit.original
    WarehouseBridgeFormFieldKind.READONLY -> edit.original
}

/** 编辑态 → 确认后的 payload 值树（LinkedHashMap 保持网页原字段序）。 */
fun warehouseBridgeFormValues(edits: List<WarehouseBridgeFormFieldEdit>): LinkedHashMap<String, Any?> {
    val values = LinkedHashMap<String, Any?>()
    for (edit in edits) {
        values[edit.key] = warehouseBridgeFormFieldValue(edit)
    }
    return values
}

// ---------------------------------------------------------------------------
// toast / error 的正文提取
// ---------------------------------------------------------------------------

/**
 * 桥接消息里的展示文本（`message` 字段）。`toast` 与 `error` 共用同一字段名
 * （对齐网页端垫片：`{type:'toast',message}` / `{type:'error',message}`）。
 *
 * 缺字段 / 非字符串 / trim 后为空一律回 null：调用方对 toast 丢掉不显示
 * （对齐 Dart「空 toast 不弹」），对 error 落到兜底文案（`courseImportScriptFailed`）。
 */
fun warehouseBridgeMessageText(raw: String?): String? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    return (parsed["message"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
}

// ---------------------------------------------------------------------------
// 请求解析
// ---------------------------------------------------------------------------

/**
 * 桥接消息原文 → 原生对话框请求；不是可弹界面的消息回 null（调用方走降级）。
 *
 * 回 null 的情形：坏 JSON / 顶层不是对象 / 类型不在对话框名单 / requestId 不可信 /
 * `saveCourseConfig` 的 payload 解析不出对象 / `savePresetTimeSlots`（数组载荷）。
 * request 的 [WarehouseBridgeDialogRequest.requestId] 已过 [isSafeWarehouseBridgeRequestId]，
 * 但回答注入前 [warehouseBridgeResolveScript] 仍会再校验一次（纵深防御）。
 */
fun warehouseBridgeDialogRequest(raw: String?): WarehouseBridgeDialogRequest? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    val kind = WarehouseBridgeDialogKind.fromMessageType(parsed["type"] as? String) ?: return null
    val requestId = (parsed["requestId"] as? String)?.trim().orEmpty()
    if (!isSafeWarehouseBridgeRequestId(requestId)) return null
    val title = parsed["title"] as? String ?: ""

    return when (kind) {
        WarehouseBridgeDialogKind.CONFIRM -> WarehouseBridgeDialogRequest.Confirm(
            requestId = requestId,
            title = title,
            message = parsed["message"] as? String ?: "",
            confirmText = parsed["confirmText"] as? String ?: "",
        )

        WarehouseBridgeDialogKind.PROMPT -> WarehouseBridgeDialogRequest.Prompt(
            requestId = requestId,
            title = title,
            message = parsed["message"] as? String ?: "",
            defaultValue = parsed["defaultValue"] as? String ?: "",
            validatorName = parsed["validatorName"] as? String ?: "",
        )

        WarehouseBridgeDialogKind.SINGLE_SELECTION -> {
            // 对齐 Dart：optionsJson 解析失败按空列表，selectedIndex 缺省 0，
            // 再钳进选项范围（空列表恒为 0）。
            val options = (MiniJson.tryParse(parsed["optionsJson"] as? String) as? List<*>)
                ?.map { it?.toString() ?: "" }
                .orEmpty()
            val rawIndex = (parsed["selectedIndex"] as? Number)?.toInt() ?: 0
            val clamped = if (options.isEmpty()) 0 else rawIndex.coerceIn(0, options.size - 1)
            WarehouseBridgeDialogRequest.SingleSelection(
                requestId = requestId,
                title = title,
                options = options,
                selectedIndex = clamped,
            )
        }

        WarehouseBridgeDialogKind.SAVE_COURSE_CONFIG -> {
            val payload = MiniJson.tryParse(parsed["payload"] as? String) as? Map<*, *> ?: return null
            WarehouseBridgeDialogRequest.SaveConfig(
                requestId = requestId,
                title = title,
                fields = payload.entries.mapNotNull { entry ->
                    val key = entry.key as? String ?: return@mapNotNull null
                    WarehouseBridgeFormField(key, entry.value)
                },
            )
        }

        // 作息模板载荷是数组，渲染不出字段表；宿主对 null 走降级回答（false）。
        WarehouseBridgeDialogKind.SAVE_PRESET_TIME_SLOTS -> null
    }
}

// ---------------------------------------------------------------------------
// 回答（Promise 的 resolve 值）
// ---------------------------------------------------------------------------

/** 一次回答：把 [jsonValue] resolve 给网页侧 [requestId] 对应的 Promise。 */
data class WarehouseBridgeDialogAnswer(
    val requestId: String,
    val kind: WarehouseBridgeDialogKind,
    val jsonValue: String,
)

/** confirm 的回答：确认 `true`、取消 `false`（对齐 Dart `confirmed == true`）。 */
fun warehouseBridgeConfirmAnswer(requestId: String, confirmed: Boolean): WarehouseBridgeDialogAnswer =
    WarehouseBridgeDialogAnswer(requestId, WarehouseBridgeDialogKind.CONFIRM, confirmed.toString())

/**
 * prompt 的回答：保存 → 带引号字符串（MiniJson.encode 负责转义）；
 * 取消 → `"null"`（对齐 Dart `jsonEncode(result)` 在 result 为 null 时）。
 */
fun warehouseBridgePromptAnswer(requestId: String, text: String?): WarehouseBridgeDialogAnswer =
    WarehouseBridgeDialogAnswer(requestId, WarehouseBridgeDialogKind.PROMPT, MiniJson.encode(text))

/** 单选的回答：保存 → 下标数字；取消 → `"null"`。 */
fun warehouseBridgeSelectionAnswer(requestId: String, index: Int?): WarehouseBridgeDialogAnswer =
    WarehouseBridgeDialogAnswer(
        requestId,
        WarehouseBridgeDialogKind.SINGLE_SELECTION,
        index?.toString() ?: "null",
    )

/** 保存配置的回答：落盘成功 `true`；取消 / 失败 / 没接仓储 `false`（不许骗脚本已保存）。 */
fun warehouseBridgeSaveConfigAnswer(requestId: String, saved: Boolean): WarehouseBridgeDialogAnswer =
    WarehouseBridgeDialogAnswer(requestId, WarehouseBridgeDialogKind.SAVE_COURSE_CONFIG, saved.toString())

/**
 * 脚本窗口结束（complete / error / 新导航 / 重新执行）时对挂起请求的**取消回话**。
 *
 * 与旧版「用户取消」的回传结构逐字一致——超时不算失败，只算这次没人选。
 */
fun warehouseBridgeDialogCancelAnswer(request: WarehouseBridgeDialogRequest): WarehouseBridgeDialogAnswer =
    when (request) {
        is WarehouseBridgeDialogRequest.Confirm ->
            warehouseBridgeConfirmAnswer(request.requestId, confirmed = false)

        is WarehouseBridgeDialogRequest.Prompt ->
            warehouseBridgePromptAnswer(request.requestId, text = null)

        is WarehouseBridgeDialogRequest.SingleSelection ->
            warehouseBridgeSelectionAnswer(request.requestId, index = null)

        is WarehouseBridgeDialogRequest.SaveConfig ->
            warehouseBridgeSaveConfigAnswer(request.requestId, saved = false)
    }

// ---------------------------------------------------------------------------
// saveCourseConfig 落盘白名单（对齐 Dart WarehouseCourseConfigLogic.resolve）
// ---------------------------------------------------------------------------

/**
 * `saveCourseConfig` 确认后真正要落盘的设置。
 *
 * 白名单与 Dart `WarehouseCourseConfigLogic.resolve` 一致：只有
 * `semesterTotalWeeks`（正整数）与 `semesterStartDate`（真实日历日）进设置；
 * `firstDayOfWeek` / `defaultClassDuration` / `defaultBreakDuration` 上游脚本
 * 会下发但本 App 无处可存，宿主只记日志忽略。null = 脚本没给可用值，保持用户现值。
 */
data class WarehouseCourseConfigResolution(
    val semesterWeekCount: Int?,
    val semesterStartDate: LocalDateTime?,
) {
    val hasAnything: Boolean get() = semesterWeekCount != null || semesterStartDate != null
}

/**
 * 整数宽容解析，对齐 Dart `WarehouseCourseImportLogic.coerceInt`：
 * `"20"` / `20.0` / `20` 都收，`"20.5"` 与垃圾字符串回 null。
 */
fun warehouseCourseConfigCoerceInt(raw: Any?): Int? = when (raw) {
    is Int -> raw
    is Long -> if (raw in Int.MIN_VALUE..Int.MAX_VALUE) raw.toInt() else null
    is Double -> if (raw.isFinite() && raw == Math.floor(raw)) raw.toInt() else null
    is Float -> if (raw.isFinite() && raw.toDouble() == Math.floor(raw.toDouble())) raw.toInt() else null
    is String -> raw.trim().toIntOrNull()
    else -> null
}

/**
 * 学期开始日期解析，对齐 Dart `warehouseSemesterStartDate`：
 * 取 `YYYY-M-D` 前缀并要求它**命名一个真实的日子**——`2026-13-45` 这类溢出值
 * 直接拒绝（回 null 保持用户现值），绝不滚动成另一个日期：这个值是全 App
 * 「现在是第几周」的唯一输入，静默滚动会坏掉一整个学期的周数。
 */
fun warehouseSemesterStartDate(raw: Any?): LocalDateTime? {
    val text = raw?.toString()?.trim() ?: return null
    if (text.isEmpty()) return null
    val match = Regex("^(\\d{4})-(\\d{1,2})-(\\d{1,2})").find(text) ?: return null
    val year = match.groupValues[1].toIntOrNull() ?: return null
    val month = match.groupValues[2].toIntOrNull() ?: return null
    val day = match.groupValues[3].toIntOrNull() ?: return null
    // LocalDate.of 对月/日溢出直接抛异常（拒绝，不滚动）——与 Dart 的 round-trip
    // 校验同一语义：只有真实存在的日子能通过。
    return try {
        LocalDate.of(year, month, day).atStartOfDay()
    } catch (_: Exception) {
        null
    }
}

/** 编辑后的表单值树 → 落盘解析（白名单之外的键不进设置）。 */
fun warehouseCourseConfigResolution(values: Map<*, *>): WarehouseCourseConfigResolution {
    val weekCount = warehouseCourseConfigCoerceInt(values["semesterTotalWeeks"])
    // 0 / 负数按「脚本没下发」处理，不是字面上的 0 周学期。
    return WarehouseCourseConfigResolution(
        semesterWeekCount = weekCount?.takeIf { it > 0 },
        semesterStartDate = warehouseSemesterStartDate(values["semesterStartDate"]),
    )
}
