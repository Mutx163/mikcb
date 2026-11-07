package com.mutx163.qingyu.pages.sync

import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

/**
 * 云备份条目 / 列表的纯逻辑（源：`lib/services/cloud_backup_index_service.dart` 的
 * `CloudBackupEntry`、`lib/screens/cloud_backup_ui_helpers.dart`、
 * `lib/screens/cloud_backup_list_screen.dart`、`lib/screens/cloud_sync_screen.dart`）。
 *
 * 只做展示语义：解析、格式化、标题/副标题、排序、详情动作、整页 viewState。
 * 不碰网络、不碰 Compose / Android —— 必须有 JVM 单测兜住这些文案拼接。
 */

/** 备份来源（Dart `CloudBackupSource`）。 */
enum class CloudBackupSource(val wire: String) {
    AUTO("auto"),
    MANUAL("manual");

    companion object {
        /** 未知值回落自动备份（Dart `firstWhere(..., orElse: auto)`）。 */
        fun fromWire(raw: Any?): CloudBackupSource =
            entries.firstOrNull { it.wire == raw?.toString() } ?: AUTO
    }
}

/**
 * 备份条目（Dart `CloudBackupEntry` 的展示子集）。
 *
 * `exportedAtIso` 保留原始字符串，解析在 [CloudBackupListLogic.parseExportedAtMillis] 里做，
 * 免得把「解析失败回落纪元 0」这条 Dart 语义藏进数据类构造。
 */
data class CloudBackupEntryModel(
    val id: String,
    val fileName: String,
    val exportedAtIso: String,
    val contentSha256: String,
    val deviceId: String,
    val deviceLabel: String,
    val appVersion: String? = null,
    val isCurrent: Boolean = false,
    val source: CloudBackupSource = CloudBackupSource.AUTO,
    val profileCount: Int? = null,
    val courseCount: Int? = null,
) {
    companion object {
        /** Dart `CloudBackupEntry.fromJson` 的默认值口径（缺字段全给空/空集合语义）。 */
        fun fromJson(json: Map<String, Any?>): CloudBackupEntryModel = CloudBackupEntryModel(
            id = json["id"] as? String ?: "",
            fileName = json["fileName"] as? String ?: "",
            exportedAtIso = json["exportedAt"] as? String ?: "",
            contentSha256 = json["contentSha256"] as? String ?: "",
            deviceId = json["deviceId"] as? String ?: "",
            deviceLabel = json["deviceLabel"] as? String ?: "",
            appVersion = json["appVersion"] as? String,
            isCurrent = json["isCurrent"] as? Boolean ?: false,
            source = CloudBackupSource.fromWire(json["source"]),
            profileCount = (json["profileCount"] as? Number)?.toInt(),
            courseCount = (json["courseCount"] as? Number)?.toInt(),
        )
    }
}

/** 备份列表一行（`HyperosNavTile` 的 title / subtitle / details）。 */
data class CloudBackupRowView(
    val entryId: String,
    val title: String,
    val subtitle: String,
    val details: String?,
    val isCurrent: Boolean,
)

/** 备份详情弹框里可执行的动作。 */
enum class CloudBackupDetailAction { RESTORE, DELETE }

/** 备份详情弹框内容（`showCloudBackupDetailSheet` 的四行 + 按钮）。 */
data class CloudBackupDetailView(
    val entryId: String,
    val title: String,
    val deviceLine: String,
    val sourceLine: String,
    val summaryLine: String?,
    val actions: List<CloudBackupDetailAction>,
) {
    /** 当前版本没有删除按钮（Dart `if (!entry.isCurrent)`）。 */
    val canDelete: Boolean get() = actions.contains(CloudBackupDetailAction.DELETE)
}

/** 两按钮确认弹框（恢复前「是否设为当前版本」等共用）。 */
data class SyncConfirmDialogView(
    val title: String,
    val message: String,
    val confirmLabel: String,
    val cancelLabel: String,
)

/** 备份列表整页 viewState。 */
data class CloudBackupListViewState(
    val isLoading: Boolean,
    val isCreatingBackup: Boolean,
    val rows: List<CloudBackupRowView>,
    val title: String,
    val createLabel: String,
    val emptyText: String,
    /**
     * 拉取失败时给空列表换一句「为什么空」的文案；null = 正常空态（真的没有备份）。
     * 没有它时断网 / 密码失效都会显示「还没有备份版本」，把失败说成了正常。
     */
    val errorText: String? = null,
    // 撤销上一次恢复（仅当确有可撤销的恢复时才出现）
    val canUndoRestore: Boolean = false,
    val undoRestoreTitle: String = "",
    val undoRestoreSummary: String = "",
    val undoRestoreActionLabel: String = "",
) {
    val isEmpty: Boolean get() = rows.isEmpty()
}

object CloudBackupListLogic {

    /** `yyyy-MM-dd HH:mm`（Dart `formatBackupDateTime`，本地时间）。 */
    fun formatBackupDateTime(epochMillis: Long, zone: ZoneId = ZoneId.systemDefault()): String {
        val local = LocalDateTime.ofInstant(Instant.ofEpochMilli(epochMillis), zone)
        return "${pad4(local.year)}-${pad2(local.monthValue)}-${pad2(local.dayOfMonth)} " +
            "${pad2(local.hour)}:${pad2(local.minute)}"
    }

    /**
     * 解析导出时间（Dart `DateTime.tryParse(...) ?? DateTime.fromMillisecondsSinceEpoch(0)`）。
     *
     * 带时区的 ISO 串直接取瞬时；不带时区的按 [zone] 解释成当地时间
     * （Dart 的 `DateTime.parse` 对无时区串同样按本地处理）；解析不了回落纪元 0。
     */
    fun parseExportedAtMillis(raw: String?, zone: ZoneId = ZoneId.systemDefault()): Long {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return 0L
        runCatching { return OffsetDateTime.parse(text).toInstant().toEpochMilli() }
        runCatching {
            return LocalDateTime.parse(text).atZone(zone).toInstant().toEpochMilli()
        }
        return 0L
    }

    fun entryMillis(entry: CloudBackupEntryModel, zone: ZoneId = ZoneId.systemDefault()): Long =
        parseExportedAtMillis(entry.exportedAtIso, zone)

    fun formatEntryTime(entry: CloudBackupEntryModel, zone: ZoneId = ZoneId.systemDefault()): String =
        formatBackupDateTime(entryMillis(entry, zone), zone)

    /** 设备名空白回落「本机」（Dart `resolveBackupDeviceLabel`）。 */
    fun resolveBackupDeviceLabel(rawDeviceLabel: String): String {
        val trimmed = rawDeviceLabel.trim()
        return trimmed.ifEmpty { SyncStrings.cloudBackupDefaultDeviceLabel.zh }
    }

    fun resolveBackupSourceLabel(source: CloudBackupSource): String = when (source) {
        CloudBackupSource.AUTO -> SyncStrings.cloudBackupSourceAuto.zh
        CloudBackupSource.MANUAL -> SyncStrings.cloudBackupSourceManual.zh
    }

    /** 内容摘要；两项计数缺一即为 null（Dart 同口径）。 */
    fun summaryText(entry: CloudBackupEntryModel): String? {
        val profiles = entry.profileCount ?: return null
        val courses = entry.courseCount ?: return null
        return SyncStrings.cloudBackupSummary.filled(
            "profileCount" to profiles.toString(),
            "courseCount" to courses.toString(),
        )
    }

    /** 行副标题：`设备` 或 `设备 · 摘要`。 */
    fun buildSubtitle(entry: CloudBackupEntryModel): String {
        val device = resolveBackupDeviceLabel(entry.deviceLabel)
        val summary = summaryText(entry) ?: return device
        return "$device · $summary"
    }

    fun buildRow(entry: CloudBackupEntryModel, zone: ZoneId = ZoneId.systemDefault()): CloudBackupRowView =
        CloudBackupRowView(
            entryId = entry.id,
            title = if (entry.isCurrent) {
                SyncStrings.cloudBackupCurrentLabel.zh
            } else {
                formatEntryTime(entry, zone)
            },
            subtitle = buildSubtitle(entry),
            details = if (entry.isCurrent) SyncStrings.cloudBackupCurrentBadge.zh else null,
            isCurrent = entry.isCurrent,
        )

    /**
     * 按导出时间倒序（`WebdavSyncService.fetchBackupList` 的 `sort((a, b) => b.exportedAt.compareTo(a.exportedAt))`）。
     * 同刻备份保持输入顺序（Dart `List.sort` 不保证稳定，这里取稳定、可预测的一支）。
     */
    fun sortByExportedAtDesc(
        entries: List<CloudBackupEntryModel>,
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<CloudBackupEntryModel> =
        entries.sortedByDescending { entryMillis(it, zone) }

    fun buildDetail(
        entry: CloudBackupEntryModel,
        zone: ZoneId = ZoneId.systemDefault(),
    ): CloudBackupDetailView {
        val actions = if (entry.isCurrent) {
            listOf(CloudBackupDetailAction.RESTORE)
        } else {
            listOf(CloudBackupDetailAction.RESTORE, CloudBackupDetailAction.DELETE)
        }
        val summary = summaryText(entry)
        return CloudBackupDetailView(
            entryId = entry.id,
            title = if (entry.isCurrent) {
                SyncStrings.cloudBackupCurrentLabel.zh
            } else {
                formatEntryTime(entry, zone)
            },
            deviceLine = "${SyncStrings.cloudBackupDetailDevice.zh}：${resolveBackupDeviceLabel(entry.deviceLabel)}",
            sourceLine = "${SyncStrings.cloudBackupDetailSource.zh}：${resolveBackupSourceLabel(entry.source)}",
            summaryLine = summary?.let { "${SyncStrings.cloudBackupDetailSummary.zh}：$it" },
            actions = actions,
        )
    }

    fun deleteConfirmMessage(
        entry: CloudBackupEntryModel,
        zone: ZoneId = ZoneId.systemDefault(),
    ): String = SyncStrings.cloudBackupDeleteBody.filled("time", formatEntryTime(entry, zone))

    /** 恢复流程里预览弹框的标题（Dart `showTransferPreviewDialog(title: cloudBackupRestoreTitle)`）。 */
    fun restorePreviewTitle(): String = SyncStrings.cloudBackupRestoreTitle.zh

    /**
     * 恢复完的「是否设为当前云端版本」确认弹框（Dart `showAppConfirmDialog`）。
     *
     * 默认动作是「设为当前版本」：不设的话其他设备下次同步会撞冲突。
     */
    fun uploadAsCurrentDialog(): SyncConfirmDialogView = SyncConfirmDialogView(
        title = SyncStrings.cloudBackupUploadAsCurrentTitle.zh,
        message = SyncStrings.cloudBackupUploadAsCurrentBody.zh,
        confirmLabel = SyncStrings.cloudBackupUploadAsCurrentYes.zh,
        cancelLabel = SyncStrings.cloudBackupUploadAsCurrentNo.zh,
    )

    /** 整页 viewState：排序在这里做，渲染层只遍历 [CloudBackupListViewState.rows]。 */
    fun buildListViewState(
        entries: List<CloudBackupEntryModel>,
        isLoading: Boolean,
        isCreatingBackup: Boolean,
        zone: ZoneId = ZoneId.systemDefault(),
        errorCode: String? = null,
        canUndoRestore: Boolean = false,
    ): CloudBackupListViewState = CloudBackupListViewState(
        isLoading = isLoading,
        isCreatingBackup = isCreatingBackup,
        rows = sortByExportedAtDesc(entries, zone).map { buildRow(it, zone) },
        title = SyncStrings.cloudBackupSectionTitle.zh,
        createLabel = SyncStrings.cloudBackupCreateNow.zh,
        emptyText = SyncStrings.cloudBackupEmpty.zh,
        // 2026-11-06 第三轮返工①（hy1 推翻「有缓存静默用缓存」）：errorCode **有值即透出**，
        // 不再按「列表是否为空」过滤——两个状态都要有可见出口：空态用 errorText 替代
        // emptyText（失败原因 + 重试），非空列表顶部出轻量错误条 + 重试（列表照常展示，
        // 下面的数据是上次拉到的缓存）。此前「非空丢 errorCode」正是最初审核的 S2 原病
        // （刷新失败完全静默），且曾被两条测试钉死＝把 bug 宣布成语义，已改。
        errorText = errorCode?.let { SyncStrings.localizeSyncError(it) },
        canUndoRestore = canUndoRestore,
        undoRestoreTitle = SyncStrings.cloudBackupUndoRestoreTitle.zh,
        undoRestoreSummary = SyncStrings.cloudBackupUndoRestoreSummary.zh,
        undoRestoreActionLabel = SyncStrings.themeUndo.zh,
    )

    private fun pad2(value: Int): String = value.toString().padStart(2, '0')

    private fun pad4(value: Int): String = value.toString().padStart(4, '0')
}
