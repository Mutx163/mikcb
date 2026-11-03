package com.mutx163.qingyu.pages.sync

/**
 * 备份文件读取专用的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * ## 为什么另起一个对象（而不是往 [SyncStrings] / [CoupleStrings] 里加）
 *
 * 本批的写作用域**只允许新增文件**，`SyncStrings.kt` / `CoupleStrings.kt` 是别人交付的
 * 既有文件，一个字节都不能动。而下面这几条键在 ARB 里**早已存在**（六份语言齐全，
 * en/ja/ko/zh_HK/zh_TW 都在），Dart 侧由
 * `lib/l10n/service_message_localizer.dart` 的 `// Cloud sync snapshot` 分支消费
 * （`serviceMsgUnrecognizedSyncSnapshot` 等 5 个 case）；只是这两个页面族对象当初
 * 没收录它们。
 *
 * 所以这里**逐字抄录**既有 ARB 键——**不新增任何 ARB 条目、不改写任何措辞**。
 * [BackupFileStringsParityTest] 与 `lib/l10n/app_zh.arb` 机械对拍，抄错一个字即红。
 *
 * ## 与 Dart 的已知缺口（诚实清单，需 Lead 决定是否补 ARB）
 *
 * - 「版本不支持」（`schemaVersion` 不是 2）与「根本不是 mikcb 备份文件」在 ARB 里
 *   **共用** `serviceMsgUnrecognizedSyncSnapshot` 一句「不是可识别的 mikcb 备份文件」；
 *   要分成两句必须新增键（建议 `serviceMsgSyncSnapshotVersionUnsupported`，六语），
 *   本批不擅自新增 ARB，故两者共用。
 * - `invalid_sync_snapshot_meta`（元数据字段类型非法）在 ARB 里没有专用键，落到
 *   同族的 `serviceMsgSyncSnapshotUnrecognized`「备份文件无法识别」。
 *
 * 「超大文件 / 空文件 / JSON 损坏」三条不在这里——它们复用 [CoupleStrings] 里已有的
 * `importFileTooLarge` / `importFileReadFailed` / `importFailedInvalidFile`
 * （Dart `data_transfer_screen.dart:396-420` 的同一批键），不重复登记。
 */
object BackupFileStrings {

    /** Dart `unrecognized_sync_snapshot`：信封（app/backupType/schemaVersion）不认识。 */
    val serviceMsgUnrecognizedSyncSnapshot =
        ArbText("serviceMsgUnrecognizedSyncSnapshot", "不是可识别的 mikcb 备份文件")

    /** Dart `missing_sync_timetable_data`：`profiles` / `timeSchemes` 不在场或不是数组。 */
    val serviceMsgMissingSyncTimetableData =
        ArbText("serviceMsgMissingSyncTimetableData", "缺少云同步课表数据")

    /** Dart `sync_snapshot_checksum_failed`（声明哈希与重算不一致）与字段类型非法共用。 */
    val serviceMsgSyncSnapshotChecksumFailed =
        ArbText("serviceMsgSyncSnapshotChecksumFailed", "备份文件校验失败")

    /** Dart `sync_snapshot_unrecognized` / `invalid_sync_snapshot_meta` 的兜底文案。 */
    val serviceMsgSyncSnapshotUnrecognized =
        ArbText("serviceMsgSyncSnapshotUnrecognized", "备份文件无法识别")

    /** Dart `sync_snapshot_no_profiles`：文件里一张课表都没有，恢复没有意义。 */
    val serviceMsgSyncSnapshotNoProfiles =
        ArbText("serviceMsgSyncSnapshotNoProfiles", "备份文件里没有可恢复的课表")

    /** 恢复提交阶段失败：已回滚到操作前状态（原子化的用户可见结论）。 */
    val backupRestoreCommitFailed =
        ArbText("backup_restore_commit_failed", "恢复提交失败，已回滚")

    /** 恢复失败且回滚也失败：本地可能停在半写状态，需用户检查存储。 */
    val backupRestoreRollbackFailed =
        ArbText("backup_restore_rollback_failed", "恢复失败且回滚失败，请检查存储")

    /** 所有 ARB 文案清单，用于 [BackupFileStringsParityTest] 机械化逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            serviceMsgUnrecognizedSyncSnapshot,
            serviceMsgMissingSyncTimetableData,
            serviceMsgSyncSnapshotChecksumFailed,
            serviceMsgSyncSnapshotUnrecognized,
            serviceMsgSyncSnapshotNoProfiles,
            backupRestoreCommitFailed,
            backupRestoreRollbackFailed,
        )
    }
}
