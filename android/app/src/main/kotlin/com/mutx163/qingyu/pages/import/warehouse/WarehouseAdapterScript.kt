package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.security.MessageDigest

/**
 * 「登录之后跑适配脚本」里**能先落地的那半段**（F28 补 I2 / F08-8c 缺口）。
 *
 * ## 本文件负责什么
 *
 * | 能力 | 函数 |
 * |---|---|
 * | 脚本在适配仓里的相对路径 | [warehouseAdapterScriptPath] |
 * | 脚本完整性校验（`adapters.yaml` 声明了 `sha256` 时才校验） | [verifyWarehouseScriptSha256] |
 * | 「现在能不能执行导入脚本」的判定 | [planWarehouseScriptExecution] |
 * | 适配脚本注入前的桥接垫片（对齐 Dart） | [warehouseImportScriptWrapper] |
 * | 让网页侧 Promise 拿到原生结果 | [warehouseBridgeResolveScript] |
 *
 * ## 为什么只做这半段
 *
 * Dart 侧「执行导入脚本」= 拉脚本 → 包一层 `AndroidBridge` 垫片 → 注入 WebView →
 * 脚本通过 `QingyuBridge` 回传 `courses` → App 写课表。**写课表**要 `TimetableRepository`,
 * 不在本泳道作用域；而且桥接对话框（confirm / prompt / 单选）还要原生弹层。
 * 所以这里把「拉脚本 + 校验 + 垫片 + 注入」做成可测的纯逻辑与渲染宿主，
 * 回传的 `courses` 由上层接导入管线——**不假装已经能写进课表**。
 *
 * 本文件属 `main` 的仓库适配模块，L0（`test-kotlin-module.ps1`）直接编它、可测。
 */

/** 适配脚本路径拼不出来 / 执行时序不对的原因。 */
enum class WarehouseScriptBlockReason {
    /** 适配器没有 `asset_js_path`（或学校缺 `resource_folder`），没有可执行的脚本。 */
    NO_SCRIPT_PATH,

    /** 网页还没加载完成就点了执行——脚本注入进去也没有 `document` 可操作。 */
    PAGE_NOT_LOADED,
}

/** 「执行导入脚本」的判定结果；真正发请求/注入由调用方做。 */
sealed class WarehouseScriptExecutionPlan {
    /** 可以执行：[scriptPath] 是适配仓里的相对路径（`resources/<学校>/<脚本>`）。 */
    data class Ready(val scriptPath: String) : WarehouseScriptExecutionPlan()

    data class Blocked(val reason: WarehouseScriptBlockReason) : WarehouseScriptExecutionPlan()
}

/**
 * 适配器脚本在仓库里的相对路径：`resources/<resource_folder>/<asset_js_path>`。
 *
 * `asset_js_path` 前导 `/` 会被剥掉（仓库文件里不写，但自定义调试/未来数据可能带）。
 * 任意一段为空时回空串——调用方据此判 [WarehouseScriptBlockReason.NO_SCRIPT_PATH]，
 * 不要拼出 `resources//x` 这种必然 404 的地址。
 */
fun warehouseAdapterScriptPath(
    school: WarehouseSchoolEntry?,
    adapter: WarehouseAdapterEntry?,
): String {
    if (school == null || adapter == null) return ""
    val folder = school.resourceFolder.trim().trim('/')
    val script = adapter.script.trim().trimStart('/')
    if (folder.isEmpty() || script.isEmpty()) return ""
    return "resources/$folder/$script"
}

/**
 * 判定现在能不能执行导入脚本。
 *
 * 顺序：先判「有没有脚本」（用户能去反馈页解决），再判「页面加载完没有」（稍等即可）。
 * 只有 [WarehouseWebLoginStage.LOADED] 放行——LOADING / ERROR / 执行中都不行。
 */
fun planWarehouseScriptExecution(
    stage: WarehouseWebLoginStage,
    school: WarehouseSchoolEntry?,
    adapter: WarehouseAdapterEntry?,
): WarehouseScriptExecutionPlan {
    val path = warehouseAdapterScriptPath(school, adapter)
    if (path.isEmpty()) {
        return WarehouseScriptExecutionPlan.Blocked(WarehouseScriptBlockReason.NO_SCRIPT_PATH)
    }
    if (stage != WarehouseWebLoginStage.LOADED) {
        return WarehouseScriptExecutionPlan.Blocked(WarehouseScriptBlockReason.PAGE_NOT_LOADED)
    }
    return WarehouseScriptExecutionPlan.Ready(path)
}

/**
 * 校验脚本 SHA-256。
 *
 * 与 Dart `fetchAdapterScript` 同口径：
 * - `declaredHex` 为空 ⇒ **跳过校验**（当前上游 204 份 adapters.yaml 全都没有 `sha256` 键，
 *   所以生产上这道门目前是「不生效」的；不能把它做成 fail-closed，否则所有学校都导不进来）；
 * - 声明了就必须匹配（大小写不敏感），且只认 64 位十六进制——声明格式坏了按**不匹配**处理，
 *   宁可拒绝执行也不要放过一个校验不了的脚本。
 *
 * 为什么校验的是「正文重新按 UTF-8 编码后的字节」：脚本是文本，经 GitCode 信封解码后
 * 已还原成 `String`；合法 UTF-8 文本重新编码与原字节一致，测试里钉住了这条。
 */
fun verifyWarehouseScriptSha256(bytes: ByteArray, declaredHex: String?): Boolean {
    val declared = declaredHex?.trim()?.lowercase().orEmpty()
    if (declared.isEmpty()) return true
    if (declared.length != 64 || declared.any { it !in '0'..'9' && it !in 'a'..'f' }) return false
    val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
    val actual = buildString(digest.size * 2) {
        for (byte in digest) {
            val value = byte.toInt() and 0xFF
            append(HEX[value ushr 4])
            append(HEX[value and 0x0F])
        }
    }
    return actual == declared
}

private const val HEX = "0123456789abcdef"

/**
 * 网页里「本轮导入脚本仍在执行」的哨兵变量名（[warehouseImportScriptWrapper] 置位、脚本收尾时复位）。
 *
 * 为什么需要它在网页里：用户取消回放 / 重试时，宿主侧只是停掉计时与 stage，
 * **网页里没有取消原语** —— 上一轮脚本可能还在抓数据、还可能自己弹原生对话框。
 * 宿主注入前用 [WAREHOUSE_IMPORT_RUNNING_PROBE_JS] 探它，为真就跳过本轮：
 * 同页面两个脚本实例并发会 ① 各回一条 courses；② 各弹一次 confirm，第二条被
 * 「同刻已有挂起」的兜底**自动答 true**——用户没见过的确认被原生替他点了。
 * 页面导航会重建 JS 上下文，哨兵随之自然清空，不会永久锁死。
 */
const val WAREHOUSE_IMPORT_RUNNING_FLAG = "__qingyuImportRunning"

/** 宿主侧探针脚本（`evaluateJavaScript` 的结果为 `"true"` = 上一轮脚本还在跑）。 */
const val WAREHOUSE_IMPORT_RUNNING_PROBE_JS = "!!window.$WAREHOUSE_IMPORT_RUNNING_FLAG"

/**
 * 适配脚本注入前的**桥接垫片**，逐字移植 Dart
 * `warehouse_adapter_web_login_screen.dart` 的 `wrappedScript`（含 v2 协议别名）。
 *
 * 提供的全局对象：
 * - `window.AndroidBridge`：`showToast` / `notifyTaskCompletion`；
 * - `window.AndroidBridgePromise`：`showAlert` / `showPrompt` / `showSingleSelection` /
 *   `saveCourseConfig` / `savePresetTimeSlots` / `saveImportedCourses`；
 * - `window.shiguangBridge` / `window.shiguangBridgePromise`：上游 v2 协议别名。
 *
 * ⚠️ **诚实边界**：`showAlert` / `showPrompt` / `showSingleSelection` / `saveCourseConfig` /
 * `savePresetTimeSlots` 返回的 Promise 要靠原生侧调 [warehouseBridgeResolveScript] 才能 resolve。
 * 原生对话框与课表写入**还没接**（见文件头），所以依赖它们的脚本会停在等待态；
 * `saveImportedCourses` 会立刻回 `true` 并回传 `courses` 消息，不依赖原生回答。
 *
 * @param confirmText 原生确认按钮文案（取 ARB `confirmImportAction`，不在这里硬写中文）
 */
fun warehouseImportScriptWrapper(script: String, confirmText: String): String {
    val escapedConfirm = confirmText.replace("\\", "\\\\").replace("'", "\\'")
    return listOf(
        "(() => {",
        // ---- 运行哨兵（对齐宏录制脚本的 `__qingyuLoginWatcherInstalled` 做法）----
        // 挡住「同一页面里第二个脚本实例并发跑」：用户取消后重执行时，上一轮脚本可能
        // 还活着（网页里没有取消原语）。两个实例并存会：① 各回一条 courses；② 各弹原生
        // 对话框，第二条被「同刻已有挂起」的兜底自动答 true——等于替用户点了他没见过的确认。
        // 结构上挡住比在宿主里加一堆防重入判断可靠：这一条在 JS 侧就断了。
        "  if (window.$WAREHOUSE_IMPORT_RUNNING_FLAG) { return; }",
        "  window.$WAREHOUSE_IMPORT_RUNNING_FLAG = true;",
        "  window.__qingyuResolvers = window.__qingyuResolvers || {};",
        "  window.AndroidBridge = {",
        "    showToast: (msg) => QingyuBridge.postMessage(JSON.stringify({type: 'toast', message: String(msg ?? '')})),",
        "    notifyTaskCompletion: () => {",
        "      window.$WAREHOUSE_IMPORT_RUNNING_FLAG = false;",
        "      QingyuBridge.postMessage(JSON.stringify({type: 'complete'}));",
        "    }",
        "  };",
        "  window.AndroidBridgePromise = {",
        "    showAlert: async (title, message, confirmText) => {",
        "      const requestId = 'confirm_' + Date.now() + '_' + Math.random().toString(36).slice(2);",
        "      return await new Promise((resolve) => {",
        "        window.__qingyuResolvers[requestId] = resolve;",
        "        QingyuBridge.postMessage(JSON.stringify({",
        "          type: 'confirm',",
        "          requestId,",
        "          title: String(title ?? ''),",
        "          message: String(message ?? ''),",
        "          confirmText: String(confirmText ?? '$escapedConfirm')",
        "        }));",
        "      });",
        "    },",
        "    showPrompt: async (title, message, defaultValue, validatorName) => {",
        "      const requestId = 'prompt_' + Date.now() + '_' + Math.random().toString(36).slice(2);",
        "      return await new Promise((resolve) => {",
        "        window.__qingyuResolvers[requestId] = resolve;",
        "        QingyuBridge.postMessage(JSON.stringify({",
        "          type: 'prompt',",
        "          requestId,",
        "          title: String(title ?? ''),",
        "          message: String(message ?? ''),",
        "          defaultValue: String(defaultValue ?? ''),",
        "          validatorName: String(validatorName ?? '')",
        "        }));",
        "      });",
        "    },",
        "    showSingleSelection: async (title, optionsJson, selectedIndex, dialogId) => {",
        "      const requestId = 'single_selection_' + Date.now() + '_' + Math.random().toString(36).slice(2);",
        "      return await new Promise((resolve) => {",
        "        window.__qingyuResolvers[requestId] = resolve;",
        "        QingyuBridge.postMessage(JSON.stringify({",
        "          type: 'singleSelection',",
        "          requestId,",
        "          title: String(title ?? ''),",
        "          optionsJson: String(optionsJson ?? '[]'),",
        "          selectedIndex: Number(selectedIndex ?? 0),",
        "          dialogId: dialogId ? String(dialogId) : undefined",
        "        }));",
        "      });",
        "    },",
        "    saveCourseConfig: async (json) => {",
        "      const requestId = 'course_config_' + Date.now() + '_' + Math.random().toString(36).slice(2);",
        "      return await new Promise((resolve) => {",
        "        window.__qingyuResolvers[requestId] = resolve;",
        "        QingyuBridge.postMessage(JSON.stringify({",
        "          type: 'saveCourseConfig',",
        "          requestId,",
        "          payload: String(json ?? '{}')",
        "        }));",
        "      });",
        "    },",
        "    savePresetTimeSlots: async (json) => {",
        "      const requestId = 'preset_time_slots_' + Date.now() + '_' + Math.random().toString(36).slice(2);",
        "      return await new Promise((resolve) => {",
        "        window.__qingyuResolvers[requestId] = resolve;",
        "        QingyuBridge.postMessage(JSON.stringify({",
        "          type: 'savePresetTimeSlots',",
        "          requestId,",
        "          payload: String(json ?? '[]')",
        "        }));",
        "      });",
        "    },",
        "    saveImportedCourses: async (json) => {",
        "      QingyuBridge.postMessage(JSON.stringify({type: 'courses', payload: String(json ?? '[]')}));",
        "      return true;",
        "    }",
        "  };",
        "  window.shiguangBridge = window.AndroidBridge;",
        "  window.shiguangBridgePromise = window.AndroidBridgePromise;",
        "  if (!window.AndroidBridge && window.shiguangBridge) { window.AndroidBridge = window.shiguangBridge; }",
        "  if (!window.AndroidBridgePromise && window.shiguangBridgePromise) { window.AndroidBridgePromise = window.shiguangBridgePromise; }",
        "  try {",
        script,
        "  } catch (error) {",
        "    window.$WAREHOUSE_IMPORT_RUNNING_FLAG = false;",
        "    QingyuBridge.postMessage(JSON.stringify({type: 'error', message: String(error)}));",
        "  }",
        "})();",
    ).joinToString("\n")
}

/**
 * 网页发来的 `requestId` 是否可信（可安全拼进 JS）。
 *
 * 不可信输入直接拼进 JS 会变成脚本注入（网页可以伪造一条 message 让原生把它当代码执行）。
 * 只放行 `[A-Za-z0-9_-]` 且长度 1~128 的 id；
 * [warehouseBridgeResolveScript] 与桥接降级回答共用这一份判据。
 */
fun isSafeWarehouseBridgeRequestId(requestId: String?): Boolean {
    val id = requestId?.trim().orEmpty()
    if (id.isEmpty() || id.length > 128) return false
    return id.all { it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' || it == '_' || it == '-' }
}

/**
 * 从桥接消息里取 `courses` 的载荷（`saveImportedCourses` 发来的课程数组 JSON 文本）。
 *
 * 只接受 `type == "courses"` 且 `payload` 是字符串的消息；其余一律 null。
 * 是否该在当下处理（导入执行期）由调用方判断——本函数只做解包。
 */
fun warehouseBridgeCoursesPayload(raw: String?): String? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    if (parsed["type"] != "courses") return null
    return parsed["payload"] as? String
}

/**
 * 让网页侧的 `await AndroidBridgePromise.xxx(...)` 拿到原生结果。
 *
 * 网页发来的 `requestId` 是不可信输入；只放行 [isSafeWarehouseBridgeRequestId]
 * 认可的 id，否则回空串（调用方就当这次没有回答，不要执行任何东西）。
 *
 * @param jsonValue 已序列化的 JSON（字符串要带引号），作为 Promise 的 resolve 值。
 */
fun warehouseBridgeResolveScript(requestId: String, jsonValue: String): String {
    if (!isSafeWarehouseBridgeRequestId(requestId)) return ""
    val id = requestId.trim()
    return "(window.__qingyuResolvers && window.__qingyuResolvers['$id']) ? " +
        "window.__qingyuResolvers['$id']($jsonValue) : undefined;"
}
