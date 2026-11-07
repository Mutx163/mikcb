package com.mutx163.qingyu.pages.transfer

/**
 * 服务层错误码 → 屏上文案（`lib/l10n/service_message_localizer.dart` 的
 * `localizeServiceMessage` 兜底口径移植）。
 *
 * ## 为什么需要它
 *
 * 服务层不抛「人话」，抛的是机器码（`transfer_exported_at_invalid` 这种 ASCII
 * 蛇形串）。把机器码原样摆到界面上，用户看到的就是一串看不懂的下划线；而如果
 * 一刀切全换成「发生未知错误」，`ImportFileTooLarge` 这类**本来就是人话**的串
 * 又会被吃掉——接收端真正的失败原因（文件太大）就消失了。
 *
 * ## 判据（照抄 Dart，不许自己发明）
 *
 * Dart 的 `default` 分支只做一件事：判断这个串**像不像内部错误码**。
 *
 * ```dart
 * final RegExp _internalCodePattern = RegExp(
 *   r'^[a-z][a-z0-9_]*(?::[A-Za-z0-9._-]+)?$',
 * );
 * ```
 *
 * - 命中 ⇒ 未登记的机器码 ⇒ 兜底文案（`quickImportUnknownError`），并把原始码留在日志里；
 * - 不命中 ⇒ 当人话原样透传。
 *
 * 这条正则的边界是刻意收窄的：`:` 后的细节只允许 ASCII 字母数字与 `._-`。
 * 所以 `Bad state: xxx`（带空格与大写）、`导入失败，文件内容无法识别`（中文）、
 * `ImportFileTooLarge`（大写开头）都**不**匹配，一定会原样返回。反过来
 * `settings_mirror_snapshot_invalid:key1`、`task_course_missing:abc` 会命中。
 *
 * ## 本页相关
 *
 * `transfer_*` 一族在 Dart 源码里 `case 'transfer_` 命中 **0** 次——它们全部未登记，
 * 所以在本页任何一条传输失败都会落到「发生未知错误」。这不是本实现的退化，
 * 与 Flutter 侧当前行为一致。
 *
 * ## 与 Dart 的已知差异
 *
 * 1. **登记表只覆盖「导入 / 备份」这一段**：Dart 的 switch 有 100+ 个 `case`，跨
 *    云同步、时间模板、教务导入、WebDAV 等多个域，全量移植属 l10n 专项批。这里
 *    只登记 Dart 源码 `// Import / backup` 注释段的 13 个码（本页真实会遇到的），
 *    其余码（含全部 `transfer_*`）走兜底。**登记表里的文案与 `app_zh.arb` 逐字一致**，
 *    由 `TransferServiceMessagesTest` 机械对拍。
 * 2. **带参数的行级警告不在这里**：Dart 的 `spreadsheet_row_warning` 会递归解析内层
 *    payload 并填 `{field}` / `{value}` 等占位符；本对象不持有那套形参表，遇到它
 *    会落到兜底文案。这个码出自表格导入，不是本页路径。
 * 3. **null 也落到兜底文案**：Dart 的入参不可空。Kotlin 侧宿主拿到的可能是一个
 *    丢了的异常消息，blank/null 归到「发生未知错误」比抛 StringIndexOutOfBounds
 *    或显示空白更安全。
 */
object TransferServiceMessages {

    /** 兜底文案（Dart 借用了这条 `quickImportUnknownError` 的措辞，本实现照抄）。 */
    private val unknownError = ArbText("quickImportUnknownError", "发生未知错误")

    /**
     * Dart `localizeServiceMessage` 里 `// Import / backup` 段登记过的 13 个码。
     *
     * 键名是 ARB 键（与 `AppLocalizations` 的 getter 同名），值逐字抄自
     * `lib/l10n/app_zh.arb`。要改界面文字先改 ARB，再同步这里。
     */
    private val registeredMessages: Map<String, ArbText> = linkedMapOf(
        "import_file_unrecognized" to
            ArbText("serviceMsgImportFileUnrecognized", "导入失败，文件内容无法识别"),
        "import_rollback_incomplete" to
            ArbText(
                "serviceMsgImportRollbackIncomplete",
                "导入失败，导入前的数据未能完整恢复，请重试或检查设备存储",
            ),
        "import_use_overwrite_for_full_backup" to
            ArbText("serviceMsgImportUseOverwriteForFullBackup", "此文件为完整备份，请使用覆盖方式导入"),
        "import_no_profiles_in_backup" to
            ArbText("serviceMsgImportNoProfilesInBackup", "备份文件中没有可恢复的课表"),
        "unrecognized_mikcb_data_file" to
            ArbText("serviceMsgUnrecognizedMikcbDataFile", "不是可识别的 mikcb 数据文件"),
        "partner_import_requires_single_profile" to
            ArbText("partnerImportRequiresSingleProfile", "请导入单课表备份文件，不支持全量备份"),
        "couple_webdav_not_connected" to
            ArbText("coupleWebdavNotConnectedError", "请先连接坚果云"),
        "couple_webdav_partner_file_missing" to
            ArbText("coupleWebdavPartnerFileMissing", "未找到对方课表文件，请让对方先上传"),
        "couple_webdav_pull_failed" to
            ArbText("coupleWebdavPullFailed", "拉取对方课表失败，请稍后重试"),
        "missing_settings_data" to
            ArbText("serviceMsgMissingSettingsData", "缺少设置数据"),
        "unrecognized_mikcb_full_backup" to
            ArbText("serviceMsgUnrecognizedMikcbFullBackup", "不是可识别的 mikcb 全量备份文件"),
        "missing_full_backup_data" to
            ArbText("serviceMsgMissingFullBackupData", "缺少完整备份数据"),
        "use_profile_backup_not_full" to
            ArbText("serviceMsgUseProfileBackupNotFull", "请使用课表档案备份 JSON，而非全部数据备份"),
    )

    /** 内部错误码的形状（Dart `_internalCodePattern` 原样；用 `matches` 即整串匹配）。 */
    private val internalCodePattern = Regex("[a-z][a-z0-9_]*(:[A-Za-z0-9._-]+)?")

    /** 本对象用到的全部文案（供 ARB 逐字对拍测试遍历）。 */
    val allTexts: List<ArbText> = listOf(unknownError) + registeredMessages.values

    /** 登记过的码（供测试遍历；顺序 = 登记顺序）。 */
    val registeredCodes: List<String> = registeredMessages.keys.toList()

    /**
     * 对齐 Dart `localizeServiceMessage` 的兜底口径：人话原样透传；未登记的
     * ASCII 蛇形机器码 → 「发生未知错误」。
     *
     * @param message 可能是裸码、可能是 `code|arg=value` 形式的 payload（Dart
     *   `encodeServiceMessage` 的产物，按 `|` 切、取第一段当码），也可能是一句人话。
     */
    fun localize(message: String?): String {
        if (message == null) return unknownError.text
        val code = codeOfPayload(message)
        registeredMessages[code]?.let { return it.text }
        return if (looksLikeInternalCode(code)) unknownError.text else code
    }

    /** Dart `parseServiceMessage` 的「取码」半边：按 `|` 切，第一段就是码。 */
    private fun codeOfPayload(payload: String): String = payload.substringBefore('|')

    /** Dart `_looksLikeInternalCode`：空串不算机器码（空串原样返回空串）。 */
    private fun looksLikeInternalCode(value: String): Boolean {
        if (value.isEmpty()) return false
        return internalCodePattern.matches(value)
    }
}
