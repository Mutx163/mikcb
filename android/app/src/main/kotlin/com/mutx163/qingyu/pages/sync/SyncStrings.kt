package com.mutx163.qingyu.pages.sync

/**
 * 同步 / 云备份模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [SyncStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 键名与 ARB 键逐字一致（`cloudSyncTitle` 等），便于 `grep` 双向核对。
 *
 * 覆盖源：`lib/screens/cloud_sync_screen.dart`、`cloud_backup_list_screen.dart`、
 * `cloud_backup_ui_helpers.dart`、`lib/l10n/sync_error_localizer.dart`。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

fun String.filled(name: String, value: String): String = replace("{$name}", value)

object SyncStrings {

    // ── 云同步页 (CloudSyncScreen) ──
    val cloudSyncTitle = ArbText("cloudSyncTitle", "云同步")
    val cloudSyncIntroTitle = ArbText("cloudSyncIntroTitle", "多设备同步")
    val cloudSyncIntroSubtitle =
        ArbText("cloudSyncIntroSubtitle", "配置坚果云 WebDAV 后，多设备间自动同步课表与设置")
    val cloudSyncAccountSectionTitle = ArbText("cloudSyncAccountSectionTitle", "云账号")
    val cloudSyncNotConnectedHint = ArbText("cloudSyncNotConnectedHint", "可在多设备间同步课表与导入数据")
    val cloudSyncConnectAccount = ArbText("cloudSyncConnectAccount", "连接坚果云")
    val cloudSyncConnectedAs = ArbText("cloudSyncConnectedAs", "已连接：{email}")
    val cloudSyncDisconnect = ArbText("cloudSyncDisconnect", "断开连接")
    val cloudSyncDisconnectTitle = ArbText("cloudSyncDisconnectTitle", "断开云同步账号")
    val cloudSyncDisconnectBody =
        ArbText("cloudSyncDisconnectBody", "断开后将清除本机保存的 WebDAV 凭据，课表数据仍保留在本机，是否继续？")
    val cloudSyncSettingsSectionTitle = ArbText("cloudSyncSettingsSectionTitle", "同步设置")
    val cloudSyncEnabledTitle = ArbText("cloudSyncEnabledTitle", "启用云同步")
    val cloudSyncProviderTitle = ArbText("cloudSyncProviderTitle", "服务提供商")
    val cloudSyncProviderJianguoyun = ArbText("cloudSyncProviderJianguoyun", "坚果云")
    val cloudSyncProviderCustom = ArbText("cloudSyncProviderCustom", "自定义 WebDAV")
    val cloudSyncModeTitle = ArbText("cloudSyncModeTitle", "同步方式")
    val cloudSyncModeAuto = ArbText("cloudSyncModeAuto", "自动同步")
    val cloudSyncModeManual = ArbText("cloudSyncModeManual", "手动同步")
    val cloudSyncAdvancedTitle = ArbText("cloudSyncAdvancedTitle", "高级设置")
    val cloudSyncBaseUrlLabel = ArbText("cloudSyncBaseUrlLabel", "WebDAV 地址")
    val cloudSyncRemoteFolderLabel = ArbText("cloudSyncRemoteFolderLabel", "远程目录")
    val cloudSyncBaseUrlInvalid =
        ArbText("cloudSyncBaseUrlInvalid", "WebDAV 地址必须以 http:// 或 https:// 开头")
    val cloudSyncHttpConfirmTitle = ArbText("cloudSyncHttpConfirmTitle", "使用明文 HTTP 连接？")
    val cloudSyncHttpConfirmMessage = ArbText(
        "cloudSyncHttpConfirmMessage",
        "地址以 http:// 开头时，账号密码将以明文传输，同一网络内的任何设备都可能截获。" +
            "仅建议在可信的局域网（如家庭 NAS）使用。仍要保存吗？",
    )
    val cloudSyncHttpConfirmProceed = ArbText("cloudSyncHttpConfirmProceed", "仍要保存")
    val cloudSyncStatusTitle = ArbText("cloudSyncStatusTitle", "同步状态")
    val cloudSyncLastSyncedLabel = ArbText("cloudSyncLastSyncedLabel", "上次同步")
    val cloudSyncLastErrorLabel = ArbText("cloudSyncLastErrorLabel", "最近错误")
    val cloudSyncSyncing = ArbText("cloudSyncSyncing", "正在同步……")
    val cloudSyncSyncNow = ArbText("cloudSyncSyncNow", "立即同步")
    val cloudSyncHelpTitle = ArbText("cloudSyncHelpTitle", "如何获取坚果云应用密码")
    val cloudSyncHelpBody = ArbText(
        "cloudSyncHelpBody",
        "打开坚果云网页或客户端 → 账户信息 → 安全选项 → 添加应用密码，" +
            "WebDAV 地址默认为 https://dav.jianguoyun.com/dav/ ",
    )
    val cloudSyncTestConnection = ArbText("cloudSyncTestConnection", "测试连接")
    val cloudSyncConfirmConnect = ArbText("cloudSyncConfirmConnect", "确认连接")
    val cloudSyncLoginSheetTitle = ArbText("cloudSyncLoginSheetTitle", "连接坚果云")
    val cloudSyncLoginSheetSubtitle =
        ArbText("cloudSyncLoginSheetSubtitle", "请使用应用专用密码，不要使用坚果云登录密码")
    val cloudSyncUsernameLabel = ArbText("cloudSyncUsernameLabel", "邮箱 / 用户名")
    val cloudSyncUsernameHint = ArbText("cloudSyncUsernameHint", "坚果云注册邮箱")
    val cloudSyncPasswordLabel = ArbText("cloudSyncPasswordLabel", "应用专用密码")
    val cloudSyncPasswordHint = ArbText("cloudSyncPasswordHint", "在坚果云账户安全选项中生成")
    val cloudSyncConfigLoadFailed =
        ArbText("cloudSyncConfigLoadFailed", "云同步设置读取失败，请重新输入应用专用密码")
    val webdavPasswordReentryBody = ArbText(
        "webdavPasswordReentryBody",
        "本次更新更改了密码的本地保存方式，需要重新输入一次应用专用密码；" +
            "服务器地址、账号与同步设置均已保留。",
    )
    val cloudSyncTestSuccess = ArbText("cloudSyncTestSuccess", "WebDAV 连接成功")
    val cloudSyncTestFailed = ArbText("cloudSyncTestFailed", "WebDAV 连接失败，请检查账号、应用密码和网络")
    val cloudSyncConnectSuccess = ArbText("cloudSyncConnectSuccess", "账号连接成功")
    val cloudSyncResultUploaded = ArbText("cloudSyncResultUploaded", "已上传到云端")
    val cloudSyncResultDownloaded = ArbText("cloudSyncResultDownloaded", "已从云端恢复")
    val cloudSyncResultUpToDate = ArbText("cloudSyncResultUpToDate", "本地与云端已一致")
    val cloudSyncResultCancelled = ArbText("cloudSyncResultCancelled", "已取消同步")
    val cloudSyncResultFailed = ArbText("cloudSyncResultFailed", "同步失败：{message}")
    val cloudSyncConflictTitle = ArbText("cloudSyncConflictTitle", "检测到同步冲突")
    val cloudSyncConflictBody =
        ArbText("cloudSyncConflictBody", "本机和云端都有新的修改，请选择保留哪一边的数据")
    val cloudSyncUseRemoteAction = ArbText("cloudSyncUseRemoteAction", "使用云端")
    val cloudSyncKeepLocalAction = ArbText("cloudSyncKeepLocalAction", "保留本机")
    val cloudSyncConflictFirstSyncTitle = ArbText("cloudSyncConflictFirstSyncTitle", "本机与云端数据不一致")
    val cloudSyncConflictFirstSyncBody = ArbText(
        "cloudSyncConflictFirstSyncBody",
        "云端与本机数据不一致。保留本机将上传并覆盖云端，使用云端将下载并覆盖本机。",
    )
    val cloudSyncKeepLocalBackupAction = ArbText("cloudSyncKeepLocalBackupAction", "以本机为准备份")

    // ── 云备份（两个页面共用：CloudSyncScreen / CloudBackupListScreen） ──
    val cloudBackupSectionTitle = ArbText("cloudBackupSectionTitle", "备份版本")
    val cloudBackupCurrentLabel = ArbText("cloudBackupCurrentLabel", "当前版本")
    val cloudBackupCurrentBadge = ArbText("cloudBackupCurrentBadge", "当前")
    val cloudBackupCreateNow = ArbText("cloudBackupCreateNow", "立即备份")
    val cloudBackupViewAll = ArbText("cloudBackupViewAll", "查看全部备份版本")
    val cloudBackupEmpty = ArbText("cloudBackupEmpty", "还没有备份版本")
    val cloudBackupSourceAuto = ArbText("cloudBackupSourceAuto", "自动备份")
    val cloudBackupSourceManual = ArbText("cloudBackupSourceManual", "手动备份")
    val cloudBackupDefaultDeviceLabel = ArbText("cloudBackupDefaultDeviceLabel", "本机")
    val cloudBackupDeviceLabelTitle = ArbText("cloudBackupDeviceLabelTitle", "设备名称")
    val cloudBackupDeviceLabelHint =
        ArbText("cloudBackupDeviceLabelHint", "在备份列表中显示的设备名称，例如 我的手机")
    val cloudBackupSummary = ArbText("cloudBackupSummary", "{profileCount} 个课表 · {courseCount} 门课程")
    val cloudBackupRestoreAction = ArbText("cloudBackupRestoreAction", "恢复")
    val cloudBackupRestoreTitle = ArbText("cloudBackupRestoreTitle", "恢复到此备份")
    val cloudBackupRestoreBody =
        ArbText("cloudBackupRestoreBody", "将恢复到 {time} 的课表，本地未同步的修改会丢失，是否继续？")
    val cloudBackupUploadAsCurrentTitle = ArbText("cloudBackupUploadAsCurrentTitle", "设为当前云端版本")
    val cloudBackupUploadAsCurrentBody = ArbText(
        "cloudBackupUploadAsCurrentBody",
        "是否将此备份设为当前云端版本？建议开启，可避免其他设备同步冲突",
    )
    val cloudBackupUploadAsCurrentYes = ArbText("cloudBackupUploadAsCurrentYes", "设为当前版本")
    val cloudBackupUploadAsCurrentNo = ArbText("cloudBackupUploadAsCurrentNo", "仅恢复本地")
    val cloudBackupRestoreSuccess = ArbText("cloudBackupRestoreSuccess", "已恢复到此备份")
    val cloudBackupRestoreFailed = ArbText("cloudBackupRestoreFailed", "恢复失败：{message}")
    // 原生页新增（Dart 的撤销是 toast 动作按钮，Android Toast 渲染不了动作按钮，
    // 改为备份区常驻撤销卡片；这四条在 Dart 源码里没有对应文案）。
    val cloudBackupUndoRestoreTitle = ArbText("cloudBackupUndoRestoreTitle", "撤销上次恢复")
    val cloudBackupUndoRestoreSummary = ArbText("cloudBackupUndoRestoreSummary", "重启应用后失效")
    val cloudBackupUndoRestoreSuccess = ArbText("cloudBackupUndoRestoreSuccess", "已撤销恢复")
    val cloudBackupUndoRestoreFailed = ArbText("cloudBackupUndoRestoreFailed", "撤销失败：{message}")
    // 恢复差异概要（2026-11-03 新增；Dart 源码无对应文案）。整宽段落，不适用行内单行口径。
    val cloudRestoreDiffProfiles = ArbText("cloudRestoreDiffProfiles", "课表：新增 {added}、覆盖 {overridden}、删除 {removed}")
    val cloudRestoreDiffCourses = ArbText("cloudRestoreDiffCourses", "课程：新增 {added}、覆盖 {overridden}、删除 {removed}")
    val cloudRestoreDiffTimeSchemes =
        ArbText("cloudRestoreDiffTimeSchemes", "作息时间：新增 {added}、覆盖 {overridden}、删除 {removed}")
    val cloudBackupDeleteTitle = ArbText("cloudBackupDeleteTitle", "删除此备份")
    val cloudBackupDeleteBody = ArbText("cloudBackupDeleteBody", "确定删除 {time} 的云端备份吗？此操作不可撤销")
    val cloudBackupDeleteSuccess = ArbText("cloudBackupDeleteSuccess", "备份已删除")
    val cloudBackupDeleteFailed = ArbText("cloudBackupDeleteFailed", "删除失败：{message}")
    val cloudBackupCreateSuccess = ArbText("cloudBackupCreateSuccess", "备份已保存到云端")
    val cloudBackupCreateFailed = ArbText("cloudBackupCreateFailed", "备份失败：{message}")
    val cloudBackupDetailDevice = ArbText("cloudBackupDetailDevice", "设备")
    val cloudBackupDetailSource = ArbText("cloudBackupDetailSource", "来源")
    val cloudBackupDetailSummary = ArbText("cloudBackupDetailSummary", "内容")
    val cloudBackupRetentionTitle = ArbText("cloudBackupRetentionTitle", "备份保留策略")
    val cloudBackupMaxCountTitle = ArbText("cloudBackupMaxCountTitle", "最多保留份数")
    val cloudBackupMaxCountSubtitle = ArbText("cloudBackupMaxCountSubtitle", "超过后自动删除最旧的备份")
    val cloudBackupMaxCountOption = ArbText("cloudBackupMaxCountOption", "{count} 份")
    val cloudBackupMaxAgeTitle = ArbText("cloudBackupMaxAgeTitle", "最长保留天数")
    val cloudBackupMaxAgeSubtitle = ArbText("cloudBackupMaxAgeSubtitle", "超过后自动删除过期备份")
    val cloudBackupMaxAgeOption = ArbText("cloudBackupMaxAgeOption", "{days} 天")
    val cloudBackupManualProtectedTitle = ArbText("cloudBackupManualProtectedTitle", "手动备份永不过期")

    // ── 通用按钮 / 动作 ──
    val cancelAction = ArbText("cancelAction", "取消")
    val deleteAction = ArbText("deleteAction", "删除")
    val saveAction = ArbText("saveAction", "保存")
    val themeUndo = ArbText("themeUndo", "撤销")

    // ── WebDAV / 同步错误码（`lib/l10n/sync_error_localizer.dart` 的映射目标） ──
    val syncErrorAuthFailed = ArbText("syncErrorAuthFailed", "账号或密码错误")
    val syncErrorAccessDenied = ArbText("syncErrorAccessDenied", "没有访问权限")
    val syncErrorCertificateError = ArbText("syncErrorCertificateError", "证书校验失败")
    val syncErrorConnectionTimeout = ArbText("syncErrorConnectionTimeout", "连接超时")
    val syncErrorConnectionFailed = ArbText("syncErrorConnectionFailed", "无法连接服务器")
    val syncErrorNetworkError = ArbText("syncErrorNetworkError", "网络异常")
    val syncErrorInvalidResponse = ArbText("syncErrorInvalidResponse", "服务器响应无效")
    val syncErrorLocalChangesPendingSync =
        ArbText("syncErrorLocalChangesPendingSync", "本地有未同步修改，已跳过自动覆盖")
    val syncErrorMissingCredentials = ArbText("syncErrorMissingCredentials", "请先配置云同步账号")
    val syncErrorBackupNotFound = ArbText("syncErrorBackupNotFound", "备份不存在")
    val syncErrorMissingBackupSnapshot = ArbText("syncErrorMissingBackupSnapshot", "备份缺失")
    val syncErrorCannotDeleteCurrentBackup =
        ArbText("syncErrorCannotDeleteCurrentBackup", "不能删除当前备份")
    val syncErrorProviderNotReady = ArbText("syncErrorProviderNotReady", "课表尚未就绪")
    val syncErrorNoLocalData = ArbText("syncErrorNoLocalData", "本机还没有课表数据可同步")
    val syncErrorInsecureUrl =
        ArbText("syncErrorInsecureUrl", "仅支持 HTTPS 加密连接，HTTP 明文协议已被禁用")
    val syncErrorSyncFailed = ArbText("syncErrorSyncFailed", "同步失败")

    /**
     * 错误码 → 屏上文案（Dart `localizeSyncError(l10n, code)` 原样）。
     *
     * 未知码与 `null`/空串/`sync_failed` 一律落到「同步失败」，不透出原始文本。
     */
    fun localizeSyncError(code: String?): String = when (code) {
        "auth_failed" -> syncErrorAuthFailed.zh
        "access_denied" -> syncErrorAccessDenied.zh
        "certificate_error" -> syncErrorCertificateError.zh
        "connection_timeout" -> syncErrorConnectionTimeout.zh
        "connection_failed" -> syncErrorConnectionFailed.zh
        "network_error" -> syncErrorNetworkError.zh
        "invalid_response" -> syncErrorInvalidResponse.zh
        "local_changes_pending_sync" -> syncErrorLocalChangesPendingSync.zh
        "missing_credentials" -> syncErrorMissingCredentials.zh
        "backup_not_found" -> syncErrorBackupNotFound.zh
        "missing_backup_snapshot" -> syncErrorMissingBackupSnapshot.zh
        "cannot_delete_current_backup" -> syncErrorCannotDeleteCurrentBackup.zh
        "provider_not_ready" -> syncErrorProviderNotReady.zh
        "no_local_user_data" -> syncErrorNoLocalData.zh
        "insecure_url_blocked" -> syncErrorInsecureUrl.zh
        // 恢复三件套提交失败（ARB 键为 camelCase：backupRestoreCommitFailed /
        // backupRestoreRollbackFailed，见 BackupFileStrings）。
        "backup_restore_commit_failed" -> BackupFileStrings.backupRestoreCommitFailed.zh
        "backup_restore_rollback_failed" -> BackupFileStrings.backupRestoreRollbackFailed.zh
        else -> syncErrorSyncFailed.zh
    }

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            cloudSyncTitle,
            cloudSyncIntroTitle,
            cloudSyncIntroSubtitle,
            cloudSyncAccountSectionTitle,
            cloudSyncNotConnectedHint,
            cloudSyncConnectAccount,
            cloudSyncConnectedAs,
            cloudSyncDisconnect,
            cloudSyncDisconnectTitle,
            cloudSyncDisconnectBody,
            cloudSyncSettingsSectionTitle,
            cloudSyncEnabledTitle,
            cloudSyncProviderTitle,
            cloudSyncProviderJianguoyun,
            cloudSyncProviderCustom,
            cloudSyncModeTitle,
            cloudSyncModeAuto,
            cloudSyncModeManual,
            cloudSyncAdvancedTitle,
            cloudSyncBaseUrlLabel,
            cloudSyncRemoteFolderLabel,
            cloudSyncBaseUrlInvalid,
            cloudSyncHttpConfirmTitle,
            cloudSyncHttpConfirmMessage,
            cloudSyncHttpConfirmProceed,
            cloudSyncStatusTitle,
            cloudSyncLastSyncedLabel,
            cloudSyncLastErrorLabel,
            cloudSyncSyncing,
            cloudSyncSyncNow,
            cloudSyncHelpTitle,
            cloudSyncHelpBody,
            cloudSyncTestConnection,
            cloudSyncConfirmConnect,
            cloudSyncLoginSheetTitle,
            cloudSyncLoginSheetSubtitle,
            cloudSyncUsernameLabel,
            cloudSyncUsernameHint,
            cloudSyncPasswordLabel,
            cloudSyncPasswordHint,
            cloudSyncConfigLoadFailed,
            webdavPasswordReentryBody,
            cloudSyncTestSuccess,
            cloudSyncTestFailed,
            cloudSyncConnectSuccess,
            cloudSyncResultUploaded,
            cloudSyncResultDownloaded,
            cloudSyncResultUpToDate,
            cloudSyncResultCancelled,
            cloudSyncResultFailed,
            cloudSyncConflictTitle,
            cloudSyncConflictBody,
            cloudSyncUseRemoteAction,
            cloudSyncKeepLocalAction,
            cloudSyncConflictFirstSyncTitle,
            cloudSyncConflictFirstSyncBody,
            cloudSyncKeepLocalBackupAction,
            cloudBackupSectionTitle,
            cloudBackupCurrentLabel,
            cloudBackupCurrentBadge,
            cloudBackupCreateNow,
            cloudBackupViewAll,
            cloudBackupEmpty,
            cloudBackupSourceAuto,
            cloudBackupSourceManual,
            cloudBackupDefaultDeviceLabel,
            cloudBackupDeviceLabelTitle,
            cloudBackupDeviceLabelHint,
            cloudBackupSummary,
            cloudBackupRestoreAction,
            cloudBackupRestoreTitle,
            cloudBackupRestoreBody,
            cloudBackupUploadAsCurrentTitle,
            cloudBackupUploadAsCurrentBody,
            cloudBackupUploadAsCurrentYes,
            cloudBackupUploadAsCurrentNo,
            cloudBackupRestoreSuccess,
            cloudBackupRestoreFailed,
            cloudBackupUndoRestoreTitle,
            cloudBackupUndoRestoreSummary,
            cloudBackupUndoRestoreSuccess,
            cloudBackupUndoRestoreFailed,
            cloudRestoreDiffProfiles,
            cloudRestoreDiffCourses,
            cloudRestoreDiffTimeSchemes,
            cloudBackupDeleteTitle,
            cloudBackupDeleteBody,
            cloudBackupDeleteSuccess,
            cloudBackupDeleteFailed,
            cloudBackupCreateSuccess,
            cloudBackupCreateFailed,
            cloudBackupDetailDevice,
            cloudBackupDetailSource,
            cloudBackupDetailSummary,
            cloudBackupRetentionTitle,
            cloudBackupMaxCountTitle,
            cloudBackupMaxCountSubtitle,
            cloudBackupMaxCountOption,
            cloudBackupMaxAgeTitle,
            cloudBackupMaxAgeSubtitle,
            cloudBackupMaxAgeOption,
            cloudBackupManualProtectedTitle,
            cancelAction,
            deleteAction,
            saveAction,
            themeUndo,
            syncErrorAuthFailed,
            syncErrorAccessDenied,
            syncErrorCertificateError,
            syncErrorConnectionTimeout,
            syncErrorConnectionFailed,
            syncErrorNetworkError,
            syncErrorInvalidResponse,
            syncErrorLocalChangesPendingSync,
            syncErrorMissingCredentials,
            syncErrorBackupNotFound,
            syncErrorMissingBackupSnapshot,
            syncErrorCannotDeleteCurrentBackup,
            syncErrorProviderNotReady,
            syncErrorNoLocalData,
            syncErrorInsecureUrl,
            syncErrorSyncFailed,
        )
    }
}
