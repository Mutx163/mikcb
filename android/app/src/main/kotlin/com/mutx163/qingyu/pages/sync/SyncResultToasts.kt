package com.mutx163.qingyu.pages.sync

/**
 * WebDAV 同步 / 云备份结果 → 屏上提示（toast）的映射。
 *
 * 源：`lib/screens/cloud_sync_screen.dart`（`_syncNow` / `_createManualBackup` /
 * `_restoreBackupThroughTransferHub` / `_undoCloudRestore` / `_confirmBaseUrl`）与
 * `lib/screens/cloud_backup_list_screen.dart`（同名四段）。
 *
 * 渲染层只负责把 [SyncToast] 交给宿主 toast 组件，不再自己判种类——
 * 这些判据一旦两边各写一份，就会漂移（例如「备份成功」到底认几个 kind）。
 */

/** Dart `WebdavSyncResultKind` 的展示侧子集（含备份增删种类，值与原枚举同名）。 */
enum class SyncResultKind {
    BACKUP_CREATED,
    UPLOADED,
    DOWNLOADED,
    UP_TO_DATE,
    CANCELLED,
    FAILED,
    BACKUP_DELETED,

    /** 不认识 / 不该出现在该动作里的种类，走 Dart 的 `_ =>` 兜底分支。 */
    UNKNOWN,
}

/**
 * 一条待展示的提示。
 *
 * @param isError true = 错误样式（Dart `AppToastKind.error`）。
 * @param actionLabel 非空表示带一个动作按钮（Dart `showAppToastWithAction`）。
 * @param reloadBackups 提示之后是否要重新拉备份列表（Dart 里每处 `if (… ) await _loadBackups()`）。
 */
data class SyncToast(
    val message: String,
    val isError: Boolean,
    val actionLabel: String? = null,
    val reloadBackups: Boolean = false,
)

object SyncResultToasts {

    /**
     * 手动同步（Dart `_syncNow`）。
     *
     * 取消只会来自冲突弹窗放弃选边，因此另给「以本机为准备份」直达动作，
     * 且用的是 success 样式（不是错误）。
     */
    fun forSyncNow(kind: SyncResultKind, errorCode: String?): SyncToast = when (kind) {
        SyncResultKind.CANCELLED -> SyncToast(
            message = SyncStrings.cloudSyncResultCancelled.zh,
            isError = false,
            actionLabel = SyncStrings.cloudSyncKeepLocalBackupAction.zh,
        )

        SyncResultKind.UPLOADED -> SyncToast(
            message = SyncStrings.cloudSyncResultUploaded.zh,
            isError = false,
            reloadBackups = true,
        )

        SyncResultKind.DOWNLOADED -> SyncToast(
            message = SyncStrings.cloudSyncResultDownloaded.zh,
            isError = false,
            reloadBackups = true,
        )

        SyncResultKind.FAILED -> SyncToast(
            message = SyncStrings.cloudSyncResultFailed.filled(
                "message",
                SyncStrings.localizeSyncError(errorCode),
            ),
            isError = true,
        )

        // 其余（含 UP_TO_DATE）都落到 Dart 的 `_ => l10n.cloudSyncResultUpToDate`。
        else -> SyncToast(message = SyncStrings.cloudSyncResultUpToDate.zh, isError = false)
    }

    /** 立即备份（Dart：`backupCreated` 与 `uploaded` 都算成功）。 */
    fun forCreateBackup(kind: SyncResultKind, errorCode: String?): SyncToast {
        val succeeded = kind == SyncResultKind.BACKUP_CREATED || kind == SyncResultKind.UPLOADED
        return if (succeeded) {
            SyncToast(
                message = SyncStrings.cloudBackupCreateSuccess.zh,
                isError = false,
                reloadBackups = true,
            )
        } else {
            SyncToast(
                message = SyncStrings.cloudBackupCreateFailed.filled(
                    "message",
                    SyncStrings.localizeSyncError(errorCode),
                ),
                isError = true,
            )
        }
    }

    /** 删除备份（Dart：只有 `backupDeleted` 算成功）。 */
    fun forDeleteBackup(kind: SyncResultKind, errorCode: String?): SyncToast =
        if (kind == SyncResultKind.BACKUP_DELETED) {
            SyncToast(
                message = SyncStrings.cloudBackupDeleteSuccess.zh,
                isError = false,
                reloadBackups = true,
            )
        } else {
            SyncToast(
                message = SyncStrings.cloudBackupDeleteFailed.filled(
                    "message",
                    SyncStrings.localizeSyncError(errorCode),
                ),
                isError = true,
            )
        }

    /** 恢复备份（Dart：`result.applied` 成功带「撤销」动作，否则带本地化原因）。 */
    fun forRestore(applied: Boolean, errorCode: String?): SyncToast =
        if (applied) {
            SyncToast(
                message = SyncStrings.cloudBackupRestoreSuccess.zh,
                isError = false,
                actionLabel = SyncStrings.themeUndo.zh,
                reloadBackups = true,
            )
        } else {
            SyncToast(
                message = SyncStrings.cloudBackupRestoreFailed.filled(
                    "message",
                    SyncStrings.localizeSyncError(errorCode),
                ),
                isError = true,
            )
        }

    /**
     * 撤销上一次恢复。
     *
     * 与 Dart 的差异：Dart 失败分支直接拼原文 `'Undo failed'`（屏上是「恢复失败：Undo failed」），
     * 用户看不出到底哪一步失败。原生页改为「撤销失败：{本地化原因}」，成功也换成
     * 「已撤销恢复」——原来复用「已恢复到此备份」会把「撤销」说成「恢复」。
     *
     * @param errorCode 撤销失败时的原始错误码（取自 `controller.lastErrorCode`）
     */
    fun forUndoRestore(success: Boolean, errorCode: String? = null): SyncToast =
        if (success) {
            SyncToast(
                message = SyncStrings.cloudBackupUndoRestoreSuccess.zh,
                isError = false,
                reloadBackups = true,
            )
        } else {
            SyncToast(
                message = SyncStrings.cloudBackupUndoRestoreFailed.filled(
                    "message",
                    SyncStrings.localizeSyncError(errorCode),
                ),
                isError = true,
            )
        }

    /** 配置读取失败（Dart `_loadConfig` 的 catch 分支）。 */
    fun forConfigLoadFailed(): SyncToast =
        SyncToast(message = SyncStrings.cloudSyncConfigLoadFailed.zh, isError = true)

    /** baseUrl 非法（Dart `_confirmBaseUrl` 的 invalid 分支）。 */
    fun forBaseUrlInvalid(): SyncToast =
        SyncToast(message = SyncStrings.cloudSyncBaseUrlInvalid.zh, isError = true)

    /** 测试连接（Dart `_WebdavConnectSheetState._testConnection`）。 */
    fun forTestConnection(success: Boolean): SyncToast = SyncToast(
        message = if (success) SyncStrings.cloudSyncTestSuccess.zh else SyncStrings.cloudSyncTestFailed.zh,
        isError = !success,
    )
}
