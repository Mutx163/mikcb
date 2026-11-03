package com.mutx163.qingyu.pages.import.warehouse

/**
 * 加速回放（P2 / N2 后半）：为快捷导入构造更短的回放路径——登录前缀 +
 * `navigate(scriptPageUrl)`，跳过登录后的菜单点击。
 *
 * 逐字对齐 Dart `lib/models/warehouse_macro_models.dart` 的
 * `buildAcceleratedMacroSteps` / `_macroAuthPrefixSteps`（只读参照）。
 */

/**
 * 构造更短的回放路径；不划算或缺 `scriptPageUrl` 时原样返回 [originalSteps]。
 *
 * 不加速的三种情况：
 * - 没有可识别的登录前缀（全程没有 fill / 等手动输入，无从确定登录在哪一步结束）；
 * - 登录后的剩余步骤不足 2 步（跳不出多少，不值得冒回退风险）；
 * - 有 `scriptPageUrl` 但脱敏后不可用且与入口页相同之外的兜底路径也不适用（见下）。
 */
fun buildWarehouseAcceleratedMacroSteps(
    originalSteps: List<WarehouseMacroStep>,
    scriptPageUrl: String?,
    importUrl: String?,
): List<WarehouseMacroStep> {
    if (originalSteps.isEmpty()) return originalSteps

    val authPrefix = warehouseMacroAuthPrefixSteps(originalSteps)
    // 没有可识别的登录前缀 → 不能安全跳过任何东西。
    if (authPrefix.isEmpty()) return originalSteps
    val droppedStepCount = originalSteps.size - authPrefix.size
    // 登录后至少还剩 2 步，跳过才划算。
    if (droppedStepCount < 2) return originalSteps

    val sanitizedScriptPageUrl = sanitizeWarehouseScriptPageUrl(scriptPageUrl)
    val sanitizedImportUrl = sanitizeWarehouseScriptPageUrl(importUrl)

    // 优先显式脚本页（如成绩/课表 HTML）。入口页就是脚本页时只保留前缀：
    // 全量录制里登录后的导航是多余的。
    if (sanitizedScriptPageUrl != null) {
        if (sanitizedImportUrl != null && sanitizedImportUrl == sanitizedScriptPageUrl) {
            return authPrefix
        }
        return authPrefix +
            WarehouseMacroStep.navigate(sanitizedScriptPageUrl) +
            WarehouseMacroStep.delay(1000)
    }

    // 没有脚本页的旧宏：保留登录、丢掉其余（许多 API 型适配器在任意已登录页都能跑）。
    return authPrefix
}

/**
 * 「最后一次 fill / 等手动输入，以及其后至多 3 步内的 click（含紧随 delay）」
 * 作为登录前缀（Dart `_macroAuthPrefixSteps` 逐字一致）。
 *
 * 登录动作以「填账号/密码（或等验证码）」收尾，随后一拍内通常有一次点提交；
 * 前缀取到这次点击为止，后面的菜单点击全部属于「登录后」。
 */
fun warehouseMacroAuthPrefixSteps(originalSteps: List<WarehouseMacroStep>): List<WarehouseMacroStep> {
    var lastAuthStepIndex = -1
    for (index in originalSteps.indices) {
        val type = originalSteps[index].type
        if (type == WarehouseMacroStepType.FILL_FIELD ||
            type == WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT
        ) {
            lastAuthStepIndex = index
        }
    }
    if (lastAuthStepIndex < 0) return emptyList()

    var authPrefixEndIndex = lastAuthStepIndex
    var index = lastAuthStepIndex + 1
    while (index < originalSteps.size && index <= lastAuthStepIndex + 3) {
        val type = originalSteps[index].type
        if (type == WarehouseMacroStepType.CLICK) {
            authPrefixEndIndex = index
            if (index + 1 < originalSteps.size &&
                originalSteps[index + 1].type == WarehouseMacroStepType.DELAY
            ) {
                authPrefixEndIndex = index + 1
            }
            break
        }
        if (type == WarehouseMacroStepType.DELAY) {
            authPrefixEndIndex = index
            index++
            continue
        }
        break
    }
    return originalSteps.subList(0, authPrefixEndIndex + 1).toList()
}
