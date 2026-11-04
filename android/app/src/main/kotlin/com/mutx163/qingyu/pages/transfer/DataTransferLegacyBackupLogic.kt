package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.transfer.LegacyBackupPackage
import com.mutx163.qingyu.transfer.LegacyBackupParseResult
import com.mutx163.qingyu.transfer.LegacyBackupPayload

/**
 * `.mikcb` 文件 / 二维码文本的**兼容解析**（Dart `DataTransferService.parseCompatible`）。
 *
 * ## 为什么需要这一层
 *
 * Dart 的文件导入不是「一律走当前的 `TransferPackage` 信封」，而是三段：
 * 1. 文本是信封（`app == 'mikcb' && packageType == 'transfer'`）→ 只走
 *    `TransferPackage.decode`，坏了就**整份拒收**（fail closed，绝不回退）；
 * 2. 不是信封 → `parseFullBackupJson`（老的全量备份，`backupType: 'full'`）；
 * 3. 还不是 → `parseBackupJson`（老的 `.mikcb` 单课表单档备份：只有 `app` +
 *    `schemaVersion` + `courses` + `settings`，其余键可缺）。
 *
 * Kotlin 侧只实现了第 1 段（[DataTransferImportLogic.parse] 先跑
 * `validateTransferPackageJson`），于是库里已经注册好的
 * `unrecognized_mikcb_data_file` / `missing_settings_data` /
 * `unrecognized_mikcb_full_backup` / `missing_full_backup_data`
 * （见 [TransferServiceMessages]）从来没有被产出过——老文件导入一律报
 * `transfer_app_invalid` / `transfer_package_type_required`，用户手里的旧备份
 * 升级后直接报废。这不是文案问题，是**整条旧格式通道缺失**。
 *
 * ## 2026-11-04：解析实现已下沉到 `transfer/LegacyBackupPackage`
 *
 * 局域网导入（`transfer/lan/LanTransferLogic`）也要吃旧包；为守住
 * 「`transfer/` 不反向依赖 `pages/`」，第 2/3 段的纯解析搬到
 * [LegacyBackupPackage]，本对象只做「严格段 → 失败回落 → 映射成
 * [TransferImportParseResult]」。文件导入的对外行为（错误码、预览信息、
 * droppedCounts）保持不变，回归由 `DataTransferLegacyBackupLogicTest` 钉住。
 *
 * ## 逐条对拍后的语义（与 Dart `data_transfer_service.dart:228-409` 同）
 *
 * - **信封 fail closed**：`isTransferEnvelopeJson` 为真时原样返回严格解析的错码，
 *   绝不回退到旧格式——防止「信封里 `courses` 坏了」被旧通道当成单课表包救回。
 * - **`courses` 是唯一必需列表**：键缺失 / null → `unrecognized_mikcb_data_file`；
 *   **原始非空但一条都解析不出来** → 同码（否则整份替换会把用户课表清空）；
 *   部分坏 → 逐条跳过并计入 `droppedCounts`（成功提示里如实报「跳过了 N 条」）。
 * - 其余列表（tasks / scheduleItems / exams / timeSchemes / scheduleDateRules /
 *   locationTimeGroups）：键缺失 = 不导入该类数据（历史宽容），但**整表全坏**
 *   依旧拒收（Dart 同用 `_parseListWithTotalLossGuard`）。
 * - **`settings` 必须是对象** → 否则 `missing_settings_data`（Dart :269-272）。
 * - **`currentWeek`**：先 `clamp(1, 30)` 再按设置里的周次上限收敛（Dart :305-308）。
 * - **全量旧备份**：`app`/`schemaVersion`/`backupType == 'full'` 三者齐；
 *   `profiles` 与 `timeSchemes` 必须是数组且**容器不许静默变少**（一条坏 = 整份拒收
 *   `missing_full_backup_data`）；日期规则 / 地点分组仍是条目级 salvage。
 *
 * 云备份合并恢复（`canMerge` 恒 false）不在本文件里。
 */
object DataTransferLegacyBackupLogic {

    /**
     * 兼容解析入口。
     *
     * @param channel 传输通道覆盖（二维码 / 文件）。旧格式包里 `channel` 键可能缺失或
     *   写着 `file`，但用户是从二维码扫进来的，预览与落盘都该按实际通道记。
     */
    fun parseCompatible(
        content: String,
        channel: TransferChannel? = null,
    ): TransferImportParseResult {
        val strict = DataTransferImportLogic.parse(content)
        if (strict is TransferImportParseResult.Valid) {
            return if (channel == null) strict else withChannel(strict, channel)
        }
        // 信封坏 = 整份拒收（Dart `parseCompatible` 的 fail closed）。
        if (TransferEnvelope.isTransferEnvelopeJson(content)) return strict
        val root = LegacyBackupPackage.decodeRoot(content) ?: return strict
        // 外来形状（app 不对 / 已在信封里）保持严格段错误码，行为不变。
        if (!LegacyBackupPackage.looksLikeLegacyBackup(root)) return strict
        return when (val legacy = LegacyBackupPackage.parse(root, channel)) {
            is LegacyBackupParseResult.Invalid -> TransferImportParseResult.Invalid(legacy.code)
            is LegacyBackupParseResult.Valid -> legacy.payload.toImportParseResult()
        }
    }

    private fun LegacyBackupPayload.toImportParseResult(): TransferImportParseResult.Valid {
        val plan = TransferImportPlan(
            profiles = profiles,
            activeProfileId = activeProfileId,
            courses = courses,
            settings = settings,
            currentWeek = currentWeek,
            timeSchemes = timeSchemes,
            tasks = tasks,
            exams = exams,
            scheduleItems = scheduleItems,
            scheduleDateRules = scheduleDateRules,
            locationTimeGroups = locationTimeGroups,
        )
        val info = TransferImportPackageInfo(
            scope = scope,
            channel = channel,
            packageId = packageId,
            isFullBackup = isFullBackup,
            profileName = profileName,
            currentWeek = currentWeek,
            courseCount = if (isFullBackup) profiles.sumOf { it.courses.size } else courses.size,
            profileCount = profiles.size,
            droppedCounts = droppedCounts,
        )
        return TransferImportParseResult.Valid(info, plan)
    }

    private fun withChannel(
        valid: TransferImportParseResult.Valid,
        channel: TransferChannel,
    ): TransferImportParseResult.Valid =
        valid.copy(info = valid.info.copy(channel = channel))
}
