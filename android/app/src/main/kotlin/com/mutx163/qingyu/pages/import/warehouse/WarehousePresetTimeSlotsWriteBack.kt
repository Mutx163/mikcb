package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime

/**
 * 教务脚本 `savePresetTimeSlots` → **应用作息模板**（F32 收口：写链路补上，
 * 替换「降级答 false」的诚实缺口）。
 *
 * ## Dart 链路逐跳对齐（warehouse_adapter_web_login_screen.dart）
 *
 * | Dart | 本层 |
 * |---|---|
 * | `_decodeImportedSections`：payload 必须 JSON 数组，坏位**按位留空** | [WarehousePresetTimeSlotsWriteBack.applyPayload] 里先验 List 再走 [decodeAlignedImportedSections]（同一份按位口径） |
 * | `_buildSectionSignature`：`start-end` 用 `\|` 连接 | [WarehousePresetTimeSlotsWriteBack.sectionSignature] |
 * | `_applyImportedSections`：找同名方案 → 有则 update+apply、无则 create+apply | 同构，全部走 [TimetableRepository] 的公共写入口（先落盘、成功才改内存并通知） |
 * | 失败上抛 → `showImportLightTip` + resolve `false` | [WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed]，宿主回 `false` 并提示 |
 *
 * ## 为什么必须走仓储
 *
 * 时间方案的写盘不是「存一份 JSON」：apply 时要切当前档案的 `activeTimeSchemeId`
 * 与镜像节次表、按新作息**重排课程钟点**、再通知铃铛 / 小组件等监听者。绕过仓储直接
 * 写盘会让这些停在旧值（本仓库已踩过的坑），所以本层只经 [TimetableRepository]
 * 的 createTimeScheme / updateTimeScheme / applyTimeScheme，不碰存储层。
 *
 * ## 失败语义（非法值不覆盖用户设置）
 *
 * - 解析失败（[WarehousePresetTimeSlotsWriteBack.PayloadResult.InvalidFormat] /
 *   [WarehousePresetTimeSlotsWriteBack.PayloadResult.NoSectionTimes]）：**不写盘**，
 *   对齐 Dart「解析不过直接抛」。
 * - 仓储校验失败（节次倒序 / 半空 / 收窄到课程用不到的节次等，错误码即
 *   service message）：仓储**先校验后落盘**，返回错误码时用户设置原样不动。
 * - 落盘异常：仓储内存保持旧值，宿主据此回 `false`。
 *
 * requestId 是不可信输入：与降级回答共用 [isSafeWarehouseBridgeRequestId] 同一份判据。
 */
data class WarehousePresetTimeSlotsRequest(
    val requestId: String,
    /** 网页原样载荷（节次时间数组的 JSON 文本），解析交给 [WarehousePresetTimeSlotsWriteBack.applyPayload]。 */
    val payload: String,
)

/**
 * 桥接消息 → `savePresetTimeSlots` 请求；不是这类消息 / requestId 不可信 / payload
 * 不是字符串时回 null（调用方按旧降级口径回话）。
 */
fun warehousePresetTimeSlotsRequest(raw: String?): WarehousePresetTimeSlotsRequest? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    if (parsed["type"] != "savePresetTimeSlots") return null
    val requestId = (parsed["requestId"] as? String)?.trim().orEmpty()
    if (!isSafeWarehouseBridgeRequestId(requestId)) return null
    val payload = parsed["payload"] as? String ?: return null
    return WarehousePresetTimeSlotsRequest(requestId = requestId, payload = payload)
}

/**
 * 节次 JSON → **按位对齐**的节次表；`null` 表示没有可用节次。
 *
 * 与 `pages/import` 的 `ImportSharedModel.decodeAlignedImportedSections` 同一份口径
 * （坏位留空而不是跳过——跳过会让一条坏记录把它之后每一节的时间整体前移一档；
 * 整表皆坏也回 null）。本域 L0 不收父域源码，故就地内联：改解析口径必须两处同改。
 */
private fun decodeAlignedImportedSections(decoded: Any?): List<SectionTime>? {
    if (decoded !is List<*>) return null
    val (sections, healedCount) = SectionTime.parseListAligned(decoded) { emptyList() }
    if (sections.isEmpty() || healedCount == sections.size) return null
    return sections
}

object WarehousePresetTimeSlotsWriteBack {

    /** 一次落盘的结果。 */
    sealed interface PayloadResult {
        /**
         * 已落盘并套用。[created] 为真表示新建了一套方案（否则是更新同名方案）；
         * [signature] 是本次生效的节次签名，宿主记下来做同会话去重（对齐 Dart
         * `_appliedImportedSectionsSignature`）。
         */
        data class Applied(
            val schemeId: String,
            val created: Boolean,
            val sectionCount: Int,
            val signature: String,
        ) : PayloadResult

        /** 载荷不是 JSON 数组（对齐 Dart `invalidSectionTimeFormat` 的分支）。 */
        object InvalidFormat : PayloadResult

        /** 数组里没有一条可用的节次时间（按位补完后整表皆坏 / 空表）。 */
        object NoSectionTimes : PayloadResult

        /**
         * 没落盘：[errorCode] 是仓储返回的 service message 码（校验拒绝），
         * [cause] 是落盘异常（两者至多一个非空）。用户设置保持原值。
         */
        data class Failed(val errorCode: String?, val cause: Throwable?) : PayloadResult
    }

    /** 节次表签名（对齐 Dart `_buildSectionSignature`：`start-end` 用 `|` 连接）。 */
    fun sectionSignature(sections: List<SectionTime>): String =
        sections.joinToString("|") { "${it.startTime}-${it.endTime}" }

    /**
     * 载荷（节次时间数组 JSON 文本）→ 解析 → 落盘并套用。
     *
     * @param schemeName 导入方案的名称（宿主从 ARB 键 `warehouseImportedTimeSchemeName`
     *   填 schoolName 得到；本层不硬写文案）。
     */
    fun applyPayload(
        repository: TimetableRepository,
        payload: String,
        schemeName: String,
    ): PayloadResult {
        val decoded = MiniJson.tryParse(payload)
        if (decoded !is List<*>) {
            return PayloadResult.InvalidFormat
        }
        // 按位对齐解码：坏位留空而不是压缩（否则它之后的每一节时间整体前移一档）。
        val sections = decodeAlignedImportedSections(decoded)
            ?: return PayloadResult.NoSectionTimes

        return try {
            val existing = repository.snapshot.timeSchemes.firstOrNull { it.name == schemeName }
            if (existing == null) {
                // 对齐 Dart create 分支：create（不 apply）→ 显式 apply 并检查错误码。
                // createTimeScheme 内部的 applyToActiveProfile 不检查 apply 的错误码，
                // 而本链路必须把「apply 被拒」如实报给脚本。
                val created = repository.createTimeScheme(name = schemeName, sections = sections)
                val applyError = repository.applyTimeScheme(created.id)
                if (applyError != null) {
                    return PayloadResult.Failed(errorCode = applyError, cause = null)
                }
                PayloadResult.Applied(
                    schemeId = created.id,
                    created = true,
                    sectionCount = sections.size,
                    signature = sectionSignature(sections),
                )
            } else {
                val updateError = repository.updateTimeScheme(existing.id, existing.name, sections)
                if (updateError != null) {
                    return PayloadResult.Failed(errorCode = updateError, cause = null)
                }
                val applyError = repository.applyTimeScheme(existing.id)
                if (applyError != null) {
                    return PayloadResult.Failed(errorCode = applyError, cause = null)
                }
                PayloadResult.Applied(
                    schemeId = existing.id,
                    created = false,
                    sectionCount = sections.size,
                    signature = sectionSignature(sections),
                )
            }
        } catch (error: Exception) {
            // 仓储「成功才改内存并通知」：抛错时内存仍是旧设置，宿主据此回 false。
            PayloadResult.Failed(errorCode = null, cause = error)
        }
    }
}
