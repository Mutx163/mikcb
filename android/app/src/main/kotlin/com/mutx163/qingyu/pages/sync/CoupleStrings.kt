package com.mutx163.qingyu.pages.sync

/**
 * 情侣课表设置页用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：在 [CoupleStringsParityTest] 里与 ARB 机械比对。
 * 覆盖源：`lib/screens/couple_timetable_settings_screen.dart`。
 */
object CoupleStrings {

    // ── 绑定状态与对方信息 ──
    val coupleTimetableTitle = ArbText("coupleTimetableTitle", "情侣课表")
    val coupleTimetableBoundTitle = ArbText("coupleTimetableBoundTitle", "已绑定对方课表")
    val coupleTimetableUnboundTitle = ArbText("coupleTimetableUnboundTitle", "尚未绑定对方课表")
    val coupleTimetablePartnerNameLabel = ArbText("coupleTimetablePartnerNameLabel", "对方名称")
    val coupleTimetableLastImportedAt = ArbText("coupleTimetableLastImportedAt", "上次导入：{time}")
    val courseCountBullet = ArbText("courseCountBullet", "课程数量：{count} 门")
    val increaseAction = ArbText("increaseAction", "增加一门")
    val decreaseAction = ArbText("decreaseAction", "减少一门")
    val colorOptionLabel = ArbText("colorOptionLabel", "{name}")

    // ── 三个主按钮 ──
    val coupleTimetableExportForPartner =
        ArbText("coupleTimetableExportForPartner", "导出我的课表给对方")
    val coupleTimetableImportPartner = ArbText("coupleTimetableImportPartner", "导入对方课表")
    val coupleTimetableUnlink = ArbText("coupleTimetableUnlink", "解除绑定")
    val coupleTimetableImportSuccess = ArbText("coupleTimetableImportSuccess", "已导入对方课表")
    val coupleTimetableImportUpdated = ArbText("coupleTimetableImportUpdated", "已更新对方课表")
    val coupleTimetableUnlinkConfirmTitle = ArbText("coupleTimetableUnlinkConfirmTitle", "解除情侣课表绑定？")
    val coupleTimetableUnlinkConfirmMessage =
        ArbText("coupleTimetableUnlinkConfirmMessage", "解除后将删除本地保存的对方课表，叠加视图也会关闭")
    val coupleTimetableUnlinkSuccess = ArbText("coupleTimetableUnlinkSuccess", "已解除绑定")

    // ── 叠加颜色 ──
    val coupleTimetableColorsTitle = ArbText("coupleTimetableColorsTitle", "叠加颜色")
    val coupleTimetableLegendMine = ArbText("coupleTimetableLegendMine", "我的课")
    val coupleTimetableLegendPartner = ArbText("coupleTimetableLegendPartner", "TA的课")
    val coupleTimetableLegendTogether = ArbText("coupleTimetableLegendTogether", "一起上课")

    // ── 周次偏移 ──
    val coupleTimetableWeekOffsetTitle = ArbText("coupleTimetableWeekOffsetTitle", "周次偏移")
    val coupleTimetableWeekOffsetZero = ArbText("coupleTimetableWeekOffsetZero", "无偏移")
    val coupleTimetableWeekOffsetSigned = ArbText("coupleTimetableWeekOffsetSigned", "{offset} 周")
    val coupleTimetableWeekOffsetPreview = ArbText(
        "coupleTimetableWeekOffsetPreview",
        "查看你的第 {myWeek} 周时，显示对方第 {partnerWeek} 周的课",
    )

    // ── 情侣 WebDAV（坚果云拉取） ──
    val coupleWebdavTitle = ArbText("coupleWebdavTitle", "坚果云拉取")
    val coupleWebdavNotConnected = ArbText("coupleWebdavNotConnected", "尚未连接坚果云")
    val coupleWebdavConnectedAs = ArbText("coupleWebdavConnectedAs", "已连接：{username}")
    val coupleWebdavRemotePathHint = ArbText("coupleWebdavRemotePathHint", "远程文件路径：{path}")
    val coupleWebdavLastPulledAt = ArbText("coupleWebdavLastPulledAt", "上次拉取：{time}")
    val coupleWebdavConnect = ArbText("coupleWebdavConnect", "连接坚果云")
    val coupleWebdavDisconnect = ArbText("coupleWebdavDisconnect", "断开连接")
    val coupleWebdavPullNow = ArbText("coupleWebdavPullNow", "立即拉取对方课表")
    val coupleWebdavUploadForPartner =
        ArbText("coupleWebdavUploadForPartner", "上传我的课表到坚果云")
    val coupleWebdavTestFailed = ArbText("coupleWebdavTestFailed", "连接失败，请检查账号、应用专用密码与网络")
    val coupleWebdavPullImported = ArbText("coupleWebdavPullImported", "已从坚果云导入对方课表")
    val coupleWebdavPullUpdated = ArbText("coupleWebdavPullUpdated", "已从坚果云更新对方课表")
    val coupleWebdavPullUnchanged = ArbText("coupleWebdavPullUnchanged", "对方课表无变化")
    val coupleWebdavUploadSuccess = ArbText("coupleWebdavUploadSuccess", "已上传课表，对方可拉取")
    val coupleWebdavPullFailed = ArbText("coupleWebdavPullFailed", "拉取对方课表失败，请稍后重试")
    val coupleWebdavPartnerFileMissing =
        ArbText("coupleWebdavPartnerFileMissing", "未找到对方课表文件，请让对方先上传")
    val coupleWebdavNotConnectedError = ArbText("coupleWebdavNotConnectedError", "请先连接坚果云")

    // ── 导入结果 / 通用失败 ──
    val importFailedInvalidFile = ArbText("importFailedInvalidFile", "导入失败，请确认文件有效")
    val importFileReadFailed = ArbText("importFileReadFailed", "无法读取所选文件")
    val importFileTooLarge = ArbText("importFileTooLarge", "文件超出大小上限 {size}，请选择较小的文件")
    val importPartialSkippedSuffix = ArbText("importPartialSkippedSuffix", "，其中 {count} 条格式损坏已跳过")
    val quickImportUnknownError = ArbText("quickImportUnknownError", "发生未知错误")
    val saveFailed = ArbText("saveFailed", "保存失败")

    /**
     * 通用「删除失败」（ARB 键 `deleteFailed`，`lib/l10n/app_zh.arb:490`）。
     *
     * 情侣页解绑要先删对方课表档案：那一步失败时**不能**说成「保存失败」——
     * 档案还在、绑定也还在，用户该做的是重试解绑，不是去查保存。同一句在本仓
     * `AddCourseStrings` / `ScheduleStrings` / `TimetableStrings` 里各有一份同值声明，
     * 这里按同一惯例只复述 ARB，不新造键。
     */
    val deleteFailed = ArbText("deleteFailed", "删除失败")
    val cancelAction = ArbText("cancelAction", "取消")

    // ── 连接坚果云弹层（Dart `couple_webdav_connect_sheet.dart`） ──
    val coupleWebdavLoginSheetTitle = ArbText("coupleWebdavLoginSheetTitle", "连接坚果云情侣课表")
    val coupleWebdavLoginSheetSubtitle = ArbText(
        "coupleWebdavLoginSheetSubtitle",
        "请使用坚果云应用专用密码，对方需先将课表上传到约定路径",
    )
    val coupleWebdavMySlotLabel = ArbText("coupleWebdavMySlotLabel", "本机槽位")
    val coupleWebdavMySlotHint = ArbText(
        "coupleWebdavMySlotHint",
        "双方必须选不同槽位：一方选 1，另一方选 2，否则会互相读不到课表",
    )
    val coupleWebdavSlotOne = ArbText("coupleWebdavSlotOne", "槽位 1")
    val coupleWebdavSlotTwo = ArbText("coupleWebdavSlotTwo", "槽位 2")
    val coupleWebdavConfirmConnect = ArbText("coupleWebdavConfirmConnect", "连接并拉取")
    val coupleWebdavTestSuccess = ArbText("coupleWebdavTestSuccess", "坚果云连接成功")
    val cloudSyncUsernameLabel = ArbText("cloudSyncUsernameLabel", "邮箱 / 用户名")
    val cloudSyncUsernameHint = ArbText("cloudSyncUsernameHint", "坚果云注册邮箱")
    val cloudSyncPasswordLabel = ArbText("cloudSyncPasswordLabel", "应用专用密码")
    val cloudSyncPasswordHint = ArbText("cloudSyncPasswordHint", "在坚果云账户安全选项中生成")
    val cloudSyncTestConnection = ArbText("cloudSyncTestConnection", "测试连接")

    // ── 导出分享 ──
    val coupleTimetableShareText = ArbText(
        "coupleTimetableShareText",
        "这是我的课表，导入到轻屿课表的情侣课表即可一起查看",
    )
    val coupleTimetableShareSubject = ArbText(
        "coupleTimetableShareSubject",
        "轻屿课表 · 情侣课表分享",
    )

    // ── 单档包解析错误码（Dart `parseBackupJson` 抛的那三个） ──
    val partnerImportRequiresSingleProfile = ArbText(
        "partnerImportRequiresSingleProfile",
        "请导入单课表备份文件，不支持全量备份",
    )
    val serviceMsgUnrecognizedMikcbDataFile =
        ArbText("serviceMsgUnrecognizedMikcbDataFile", "不是可识别的 mikcb 数据文件")
    val serviceMsgMissingSettingsData = ArbText("serviceMsgMissingSettingsData", "缺少设置数据")

    /**
     * 内部错误码形状（Dart `_internalCodePattern` 原样）：ASCII 小写蛇形，可带 `:细节`。
     * `Regex.matches` 已是全串匹配，锚点省掉（也避开 raw string 末尾 `$` 的歧义）。
     */
    private val internalCodePattern = Regex("""[a-z][a-z0-9_]*(?::[A-Za-z0-9._-]+)?""")

    /**
     * 服务层码 → 屏上文案。
     *
     * 覆盖 Dart `service_message_localizer.dart` 里的情侣码，另接三类码：
     * - 传输类 7 码直接委托 [SyncStrings.localizeSyncError]，与云同步同文案；
     * - `couple_webdav_invalid_base_url` 复用云同步的「地址不安全」键；
     * - `not_utf8` / `not_json` 复用 [importFailedInvalidFile]。
     *
     * **有意偏离 Dart**（裁决记录）：Dart 把 401/超时/网络错误折叠成
     * `couple_webdav_partner_file_missing`（「请让对方先上传」），属误导性文案——
     * 真实原因可能是网络。这里按真实原因提示。
     *
     * 其余仍按 Dart 兜底口径：像内部机器码 → 「发生未知错误」；本来就是人话 → 原样透出。
     */
    fun localizeServiceMessage(code: String?): String {
        val raw = code?.trim().orEmpty()
        return when (raw) {
            "couple_webdav_not_connected" -> coupleWebdavNotConnectedError.zh
            "couple_webdav_partner_file_missing" -> coupleWebdavPartnerFileMissing.zh
            "couple_webdav_pull_failed" -> coupleWebdavPullFailed.zh
            "partner_import_requires_single_profile" -> partnerImportRequiresSingleProfile.zh
            "unrecognized_mikcb_data_file" -> serviceMsgUnrecognizedMikcbDataFile.zh
            "missing_settings_data" -> serviceMsgMissingSettingsData.zh
            "couple_webdav_invalid_base_url" -> SyncStrings.syncErrorInsecureUrl.zh
            "couple_webdav_partner_file_not_utf8",
            "couple_webdav_partner_file_not_json" -> importFailedInvalidFile.zh
            "auth_failed",
            "access_denied",
            "certificate_error",
            "connection_timeout",
            "connection_failed",
            "network_error",
            "invalid_response" -> SyncStrings.localizeSyncError(raw)
            else -> if (internalCodePattern.matches(raw)) quickImportUnknownError.zh else raw
        }
    }

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            coupleTimetableTitle,
            coupleTimetableBoundTitle,
            coupleTimetableUnboundTitle,
            coupleTimetablePartnerNameLabel,
            coupleTimetableLastImportedAt,
            courseCountBullet,
            increaseAction,
            decreaseAction,
            colorOptionLabel,
            coupleTimetableExportForPartner,
            coupleTimetableImportPartner,
            coupleTimetableUnlink,
            coupleTimetableImportSuccess,
            coupleTimetableImportUpdated,
            coupleTimetableUnlinkConfirmTitle,
            coupleTimetableUnlinkConfirmMessage,
            coupleTimetableUnlinkSuccess,
            coupleTimetableColorsTitle,
            coupleTimetableLegendMine,
            coupleTimetableLegendPartner,
            coupleTimetableLegendTogether,
            coupleTimetableWeekOffsetTitle,
            coupleTimetableWeekOffsetZero,
            coupleTimetableWeekOffsetSigned,
            coupleTimetableWeekOffsetPreview,
            coupleWebdavTitle,
            coupleWebdavNotConnected,
            coupleWebdavConnectedAs,
            coupleWebdavRemotePathHint,
            coupleWebdavLastPulledAt,
            coupleWebdavConnect,
            coupleWebdavDisconnect,
            coupleWebdavPullNow,
            coupleWebdavUploadForPartner,
            coupleWebdavTestFailed,
            coupleWebdavPullImported,
            coupleWebdavPullUpdated,
            coupleWebdavPullUnchanged,
            coupleWebdavUploadSuccess,
            coupleWebdavPullFailed,
            coupleWebdavPartnerFileMissing,
            coupleWebdavNotConnectedError,
            importFailedInvalidFile,
            importFileReadFailed,
            importFileTooLarge,
            importPartialSkippedSuffix,
            quickImportUnknownError,
            saveFailed,
            deleteFailed,
            cancelAction,
            coupleWebdavLoginSheetTitle,
            coupleWebdavLoginSheetSubtitle,
            coupleWebdavMySlotLabel,
            coupleWebdavMySlotHint,
            coupleWebdavSlotOne,
            coupleWebdavSlotTwo,
            coupleWebdavConfirmConnect,
            coupleWebdavTestSuccess,
            cloudSyncUsernameLabel,
            cloudSyncUsernameHint,
            cloudSyncPasswordLabel,
            cloudSyncPasswordHint,
            cloudSyncTestConnection,
            coupleTimetableShareText,
            coupleTimetableShareSubject,
            partnerImportRequiresSingleProfile,
            serviceMsgUnrecognizedMikcbDataFile,
            serviceMsgMissingSettingsData,
        )
    }
}
