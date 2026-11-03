package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * 网页对话框的**降级回答**（F32，第二步）。
 *
 * ## 为什么需要它
 *
 * 适配脚本通过 `AndroidBridgePromise.showAlert/showPrompt/showSingleSelection/...` 等
 * 拿到一个 Promise，原生不回话就**永远停在那里**：脚本不报错、不继续、导入没有任何反应。
 * 所以这里给一个**确定、可解释**的默认回答，让脚本在「原生没有对应界面」时也不挂起。
 *
 * ## 每种对话框的回答口径
 *
 * | 网页调用 | 降级回答 | 依据 |
 * |---|---|---|
 * | `confirm` / `showAlert` | `true` | 对齐 Dart 宏回放：未录到的 confirm 默认确认，不因缺弹窗取消自动化 |
 * | `prompt` | 脚本自带 `defaultValue` | 与 Dart 宏回放的兜底一致（`recorded ?? defaultValue`） |
 * | `singleSelection` | 脚本自带 `selectedIndex` | 与 Dart 后台导入一致（`selectedIndex`，缺省 0） |
 * | `saveCourseConfig` | （宿主有原生表单，正常不走这里） | 兜底 `false`：配置没落盘，不能回 `true` 骗脚本 |
 * | `savePresetTimeSlots` | （宿主已接写链路，正常不走这里） | 兜底 `false`：只剩坏结构消息（payload 非字符串等）会落到这里，同样不骗成功 |
 *
 * ⚠️ **诚实边界**：这些不是「用户选了」，只是「没有原生界面时的确定性兜底」。
 * 依赖用户选择（如选学期、选周次）的脚本，结果可能与用户真实意图不同；
 * `savePresetTimeSlots` 的正式回答在 `WarehousePresetTimeSlotsWriteBack`（直接落盘），
 * `saveCourseConfig` 的正式回答在宿主表单；本模块只剩坏结构消息的兜底职责。
 *
 * requestId 是不可信输入，和 [warehouseBridgeResolveScript] 共用同一份校验。
 */
enum class WarehouseBridgeDialogKind(val messageType: String) {
    CONFIRM("confirm"),
    PROMPT("prompt"),
    SINGLE_SELECTION("singleSelection"),
    SAVE_COURSE_CONFIG("saveCourseConfig"),
    SAVE_PRESET_TIME_SLOTS("savePresetTimeSlots");

    companion object {
        fun fromMessageType(type: String?): WarehouseBridgeDialogKind? =
            entries.firstOrNull { it.messageType == type }
    }
}

/** 一次降级回答：把 [jsonValue] resolve 给网页侧 [requestId] 对应的 Promise。 */
data class WarehouseBridgeFallbackAnswer(
    val requestId: String,
    val kind: WarehouseBridgeDialogKind,
    val jsonValue: String,
)

/**
 * 给网页对话框消息算一个确定回答；不是这类消息（或 requestId 不可信）时回 null。
 *
 * 返回 null 时调用方既不注入任何 JS，也不执行任何东西。
 */
fun warehouseBridgeFallbackAnswer(raw: String?): WarehouseBridgeFallbackAnswer? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    val type = parsed["type"] as? String
    val kind = WarehouseBridgeDialogKind.fromMessageType(type) ?: return null

    val requestId = parsed["requestId"] as? String ?: return null
    if (!isSafeWarehouseBridgeRequestId(requestId)) return null

    val jsonValue = when (kind) {
        WarehouseBridgeDialogKind.CONFIRM -> "true"
        WarehouseBridgeDialogKind.PROMPT -> MiniJson.encode(parsed["defaultValue"] as? String ?: "")
        WarehouseBridgeDialogKind.SINGLE_SELECTION -> {
            val index = (parsed["selectedIndex"] as? Number)?.toInt() ?: 0
            MiniJson.encode(index)
        }

        WarehouseBridgeDialogKind.SAVE_COURSE_CONFIG,
        WarehouseBridgeDialogKind.SAVE_PRESET_TIME_SLOTS,
        -> "false"
    }
    return WarehouseBridgeFallbackAnswer(
        requestId = requestId.trim(),
        kind = kind,
        jsonValue = jsonValue,
    )
}
