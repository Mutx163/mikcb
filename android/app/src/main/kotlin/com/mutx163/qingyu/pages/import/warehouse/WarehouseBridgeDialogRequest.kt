package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * 网页脚本对话框（confirm / prompt / singleSelection）的**原生请求模型**（I2-1）。
 *
 * 脚本经 `AndroidBridgePromise.showAlert/showPrompt/showSingleSelection` 发来的消息，
 * 在这里解包成强类型请求，交给宿主弹**原生对话框**；用户回答后由宿主调
 * [warehouseBridgeResolveScript] 把值 resolve 回网页侧的 Promise。
 *
 * ## 与降级回答 [warehouseBridgeFallbackAnswer] 的分工
 *
 * - 本文件是「有人问就弹窗给人选」；
 * - fallback 是「没人能弹时的确定兜底」（如第二个弹窗并发到来、非 UI 场景）。
 *   两者对同一条消息给出的**请求 id 校验**是同一份（[isSafeWarehouseBridgeRequestId]）。
 *
 * ## 字段口径（逐字对齐 Dart `_showScript*Dialog`）
 *
 * - 非字符串字段一律当没给（Dart 2026-10 修过的 TypeError 洞）；
 * - `optionsJson` 解析失败按**空选项**处理，不中断导入；
 * - `selectedIndex` clamp 进 `[0, options.size-1]`（空选项时归 0）。
 */
data class WarehouseBridgeDialogRequest(
    val kind: WarehouseBridgeDialogKind,
    val requestId: String,
    val title: String = "",
    val message: String = "",
    val confirmText: String = "",
    val defaultValue: String = "",
    val validatorName: String = "",
    val options: List<String> = emptyList(),
    val selectedIndex: Int = 0,
    val dialogId: String? = null,
    /** 解析前的 optionsJson 原文；录制匹配键要与 Dart 逐字一致，不能用解析后重拼的。 */
    val optionsJsonRaw: String = "[]",
) {
    /** 录制期的应答匹配键（[warehouseDialogResponseKey] 需要原始字段口径）。 */
    fun responseKey(): String = warehouseDialogResponseKey(
        kind.messageType,
        buildMap {
            // Dart 的原始消息里 singleSelection 根本没有 message 键；这里空串等同于没给，
            // 否则正文位落不到 optionsJson 上，键就与 Dart 对不上。
            if (title.isNotEmpty()) put("title", title)
            if (message.isNotEmpty()) put("message", message)
            if (optionsJsonRaw != "[]" || options.isNotEmpty()) put("optionsJson", optionsJsonRaw)
            dialogId?.let { put("dialogId", it) }
        },
    )

    /** 录制 singleSelection 时 Dart 存的是「用户选的那一项的文字」，不是下标。 */
    fun optionTextAt(index: Int): String? = options.getOrNull(index)
}

/**
 * 解包 confirm / prompt / singleSelection 桥消息；不是这三类、requestId 不可信、
 * 或形状不对时回 null（调用方走降级回答或丢弃）。
 */
fun warehouseBridgeDialogRequest(raw: String?): WarehouseBridgeDialogRequest? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    val kind = WarehouseBridgeDialogKind.fromMessageType(parsed["type"] as? String)
        ?: return null
    if (kind == WarehouseBridgeDialogKind.SAVE_COURSE_CONFIG ||
        kind == WarehouseBridgeDialogKind.SAVE_PRESET_TIME_SLOTS
    ) {
        // 保存类消息没有 UI，走 [warehouseBridgeSaveRequest]。
        return null
    }
    val requestId = (parsed["requestId"] as? String)?.trim().orEmpty()
    if (!isSafeWarehouseBridgeRequestId(requestId)) return null

    val optionsJson = parsed["optionsJson"] as? String ?: "[]"
    val options = parseWarehouseSelectionOptions(optionsJson)
    val selectedIndex = WarehouseCourseImportLogic.coerceInt(parsed["selectedIndex"]) ?: 0

    return WarehouseBridgeDialogRequest(
        kind = kind,
        requestId = requestId,
        title = parsed["title"] as? String ?: "",
        message = parsed["message"] as? String ?: "",
        confirmText = parsed["confirmText"] as? String ?: "",
        defaultValue = parsed["defaultValue"] as? String ?: "",
        validatorName = parsed["validatorName"] as? String ?: "",
        options = options,
        selectedIndex = if (options.isEmpty()) 0 else selectedIndex.coerceIn(0, options.size - 1),
        dialogId = (parsed["dialogId"] as? String)?.takeIf { it.isNotBlank() },
        optionsJsonRaw = optionsJson,
    )
}

/**
 * 解析 singleSelection 的 `optionsJson`（JSON 字符串数组）。
 * 解析失败/不是数组 → 空列表（Dart 同口径：「解析失败按空选项处理，不中断导入」）；
 * 元素一律 `toString()`（Dart `item.toString()`）。
 */
fun parseWarehouseSelectionOptions(optionsJson: String?): List<String> {
    val decoded = MiniJson.tryParse(optionsJson) as? List<*> ?: return emptyList()
    return decoded.map { it?.toString() ?: "null" }
}
