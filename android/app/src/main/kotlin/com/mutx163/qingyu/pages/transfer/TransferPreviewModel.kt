package com.mutx163.qingyu.pages.transfer

/**
 * 传输预览对话框（`lib/screens/transfer_preview_dialog.dart`，56 行）模型层。
 *
 * ## 它挡的是什么
 *
 * 不管从哪条通道（二维码 / 局域网 / 文件）收到一个课表包，应用之前都要让用户
 * 亲口选一次「合并更改」还是「覆盖当前课表」。这个对话框就是那道闸门。
 *
 * ## 正文为什么这么长
 *
 * Dart 的正文是四段拼起来的（`showTransferPreviewDialog`，:20-35）：
 *
 * ```
 * selectImportModeMessage            ← 解释两种选择的后果
 *
 * channel=… / scope=… / transferId=…  ← 三个技术标识（排查问题时要报给用户）
 *
 * 合并： +a / ~b / -c …                ← 每种实体的增/改/删计数
 * 覆盖： +a / ~b / -c …
 * ```
 *
 * 有「另一条通道的预览」时才并列显示两段汇总（合并 vs 覆盖各自会带来什么），
 * 否则只显示一段。这套格式是**契约**：用户会拿它跟对方手机上的数字对比，
 * 所以拼法必须逐字照抄，不能改成更好看的写法。本类就把这套拼法钉在单测里。
 */
object TransferPreviewModel {

    /** 应用方式（Dart `TransferApplyMode`）。 */
    enum class ApplyMode(val dartName: String) {
        MERGE("merge"),
        OVERWRITE("overwrite"),
    }

    val title: String get() = TransferStrings.selectImportModeTitle.zh
    val message: String get() = TransferStrings.selectImportModeMessage.zh
    val cancelLabel: String get() = TransferStrings.cancelAction.zh
    val mergeLabel: String get() = TransferStrings.selectImportModeMerge.zh
    val overwriteLabel: String get() = TransferStrings.replaceCurrentTimetable.zh

    /** 一种实体的差异计数（Dart `TransferDiff` 里 `allSummaries` 的一项）。 */
    data class Summary(
        /** 实体种类原文（Dart `item.kind.value`，例如 `course` / `task`）。 */
        val kind: String,
        val added: Int,
        val updated: Int,
        val removed: Int,
    ) {
        /**
         * 一行的拼法：`kind: +added / ~updated / -removed`。
         *
         * 空格位置照抄 Dart 模板 —— 用户在两个手机之间逐字符对数字，差一个空格都会
         * 被当成「两边不一致」。
         */
        val line: String get() = "$kind: +$added / ~$updated / -$removed"
    }

    /** 包的技术标识（Dart 正文第二段的三行）。 */
    data class PackageIdentity(
        val channel: String,
        val scope: String,
        val packageId: String,
    )

    /** 汇总一串实体计数（Dart `formatSummary(value) = allSummaries.map(...).join('\n')`）。 */
    fun formatSummary(summaries: List<Summary>): String = summaries.joinToString("\n") { it.line }

    /**
     * 对话框正文（Dart :20-35 逐行对齐）。
     *
     * @param alternateSummaries 另一条通道（通常是「合并」那侧）的汇总；null = 不并列，
     *   只显示 `summaries` 一段。
     */
    fun body(
        identity: PackageIdentity,
        summaries: List<Summary>,
        alternateSummaries: List<Summary>? = null,
    ): String {
        val blocks = mutableListOf<String>()
        blocks += message
        // 三个技术标识在同一段里，用换行分隔（不是空行）
        blocks += "channel=${identity.channel}\nscope=${identity.scope}\ntransferId=${identity.packageId}"
        if (alternateSummaries != null) {
            // Dart：'merge:\n…' 与 'overwrite:\n…' 各是一段
            blocks += "merge:\n" + formatSummary(alternateSummaries)
            blocks += "overwrite:\n" + formatSummary(summaries)
        } else {
            blocks += formatSummary(summaries)
        }
        // 段与段之间空一行（Dart join('\n\n')）
        return blocks.joinToString("\n\n")
    }

    /**
     * 三个按钮：取消 / 合并更改 / 覆盖当前课表。
     *
     * 顺序照 Dart：取消在最左，覆盖是主按钮（`isPrimary: true`）。
     */
    data class Action(val label: String, val mode: ApplyMode?, val primary: Boolean)

    fun actions(): List<Action> = listOf(
        Action(cancelLabel, null, primary = false),
        Action(mergeLabel, ApplyMode.MERGE, primary = false),
        Action(overwriteLabel, ApplyMode.OVERWRITE, primary = true),
    )

    /**
     * 主按钮必须是「覆盖当前课表」。
     *
     * 这不是审美：主按钮是默认焦点，误触等于把用户课表整个换掉。单测钉住这一条，
     * 谁把它改成「合并」都会红。
     */
    fun primaryAction(): Action = actions().first { it.primary }
}
