package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.CoupleWebdavConfig
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

/**
 * 情侣课表设置页的纯逻辑（源：`lib/screens/couple_timetable_settings_screen.dart`，
 * 常量取自 `lib/domain/couple_timetable_logic.dart`）。
 *
 * 三块判据都在这里，渲染层只摆位置：
 * 1. 绑定态：未绑定只剩「导出 / 导入」两个按钮，绑定后多出解除、周次偏移、叠加颜色；
 * 2. 坚果云态：未连接只出「连接」，已连接出「拉取 / 上传 / 断开」；
 * 3. 忙碌态：按钮文案接 `...` 且不可点（Dart `'$label...'` + `onPressed: busy ? null`）。
 */

/** 对方课表绑定（Dart `PartnerTimetableBinding` 的展示子集）。 */
data class PartnerTimetableBindingModel(
    val partnerName: String,
    val lastImportedAtIso: String? = null,
    val weekOffset: Int = 0,
    val mineColorHex: String = CoupleTimetableSettingsLogic.MINE_COLOR_DEFAULT,
    val partnerColorHex: String = CoupleTimetableSettingsLogic.PARTNER_COLOR_DEFAULT,
    val togetherColorHex: String = CoupleTimetableSettingsLogic.TOGETHER_COLOR_DEFAULT,
)

/** 五个「正在做」开关（Dart 同名的五个 `_isXxx` 字段）。 */
data class CoupleBusyState(
    val isExporting: Boolean = false,
    val isImporting: Boolean = false,
    val isUnlinking: Boolean = false,
    val isPullingWebdav: Boolean = false,
    val isUploadingWebdav: Boolean = false,
)

enum class CoupleWebdavPullStatus { IMPORTED, UPDATED, UNCHANGED, FAILED }

data class CoupleActionButton(
    val id: String,
    val label: String,
    val loading: Boolean,
    val enabled: Boolean,
)

data class CoupleColorRowView(
    val label: String,
    val paletteHexes: List<String>,
    val selectedHex: String,
)

/** 解除绑定确认弹框（两按钮：取消 / 解除绑定）。 */
data class CoupleConfirmDialogView(
    val title: String,
    val message: String,
    val cancelLabel: String,
    val confirmLabel: String,
)

data class CoupleTimetableSettingsViewState(
    val title: String,
    val sectionTitle: String,
    val bound: Boolean,
    // 对方信息卡
    val partnerNameLabel: String,
    val partnerName: String,
    val courseCountLabel: String,
    val lastImportedText: String,
    // 坚果云段
    val webdavTitle: String,
    val webdavStatusText: String,
    val webdavRemotePathText: String,
    /** null = 从未拉取过，不渲染该行。 */
    val webdavLastPulledText: String?,
    val webdavButtons: List<CoupleActionButton>,
    // 情侣课表三段
    val coupleSectionTitle: String,
    val coupleButtons: List<CoupleActionButton>,
    // 周次偏移（未绑定不出现）
    val showWeekOffset: Boolean,
    val weekOffsetTitle: String,
    val weekOffsetLabel: String,
    val weekOffsetPreview: String,
    val canDecrementOffset: Boolean,
    val canIncrementOffset: Boolean,
    // 叠加颜色（未绑定不出现）
    val showColors: Boolean,
    val colorsTitle: String,
    val colorRows: List<CoupleColorRowView>,
    // 解除绑定确认弹框
    val unlinkConfirmTitle: String,
    val unlinkConfirmMessage: String,
    val unlinkConfirmCancelLabel: String,
    val unlinkConfirmActionLabel: String,
)

object CoupleTimetableSettingsLogic {

    /** Dart `CoupleTimetableLogic.minWeekOffset` / `maxWeekOffset`。 */
    const val MIN_WEEK_OFFSET: Int = -15
    const val MAX_WEEK_OFFSET: Int = 15

    const val MINE_COLOR_DEFAULT: String = "#2196F3"
    const val PARTNER_COLOR_DEFAULT: String = "#E91E63"
    const val TOGETHER_COLOR_DEFAULT: String = "#9C27B0"

    /** Dart `kCourseColorQuickPickHexes`（一族一色，19 个）。 */
    val QUICK_PICK_HEXES: List<String> = listOf(
        "#2196F3",
        "#EF4444",
        "#F97316",
        "#F59E0B",
        "#FACC15",
        "#84CC16",
        "#22C55E",
        "#10B981",
        "#14B8A6",
        "#06B6D4",
        "#0EA5E9",
        "#6366F1",
        "#8B5CF6",
        "#A855F7",
        "#D946EF",
        "#EC4899",
        "#F43F5E",
        "#64748B",
        "#78716C",
    )

    /** 坚果云是否已连接（Dart `_isCoupleWebdavConnected`）。 */
    fun isWebdavConnected(username: String, hasStoredPassword: Boolean): Boolean =
        username.trim().isNotEmpty() && hasStoredPassword

    fun sectionTitle(bound: Boolean): String = if (bound) {
        CoupleStrings.coupleTimetableBoundTitle.zh
    } else {
        CoupleStrings.coupleTimetableUnboundTitle.zh
    }

    /** `yyyy-MM-dd HH:mm`；null / 解析失败 → "-"（Dart `_formatDateTime` 的调用形态）。 */
    fun formatDateTimeOrDash(iso: String?, zone: ZoneId = ZoneId.systemDefault()): String {
        val text = iso?.trim().orEmpty()
        if (text.isEmpty()) return "-"
        val millis = runCatching { OffsetDateTime.parse(text).toInstant().toEpochMilli() }
            .recoverCatching { LocalDateTime.parse(text).atZone(zone).toInstant().toEpochMilli() }
            .recoverCatching { Instant.parse(text).toEpochMilli() }
            .getOrNull() ?: return "-"
        return CloudBackupListLogic.formatBackupDateTime(millis, zone)
    }

    fun courseCountLabel(count: Int): String =
        CoupleStrings.courseCountBullet.filled("count", count.toString())

    fun webdavStatusText(username: String, hasStoredPassword: Boolean): String =
        if (isWebdavConnected(username, hasStoredPassword)) {
            CoupleStrings.coupleWebdavConnectedAs.filled("username", username.trim())
        } else {
            CoupleStrings.coupleWebdavNotConnected.zh
        }

    fun remotePathText(remotePath: String): String =
        CoupleStrings.coupleWebdavRemotePathHint.filled("path", remotePath)

    fun lastPulledText(iso: String?, zone: ZoneId = ZoneId.systemDefault()): String? {
        val formatted = formatDateTimeOrDash(iso, zone)
        if (formatted == "-") return null
        return CoupleStrings.coupleWebdavLastPulledAt.filled("time", formatted)
    }

    /** 0 → 「无偏移」；其余带符号（Dart `'${offset > 0 ? '+$offset' : '$offset'}'`）。 */
    fun weekOffsetLabel(offset: Int): String {
        if (offset == 0) return CoupleStrings.coupleTimetableWeekOffsetZero.zh
        val signed = if (offset > 0) "+$offset" else offset.toString()
        return CoupleStrings.coupleTimetableWeekOffsetSigned.filled("offset", signed)
    }

    fun weekOffsetPreview(myWeek: Int, partnerWeek: Int): String =
        CoupleStrings.coupleTimetableWeekOffsetPreview.filled(
            "myWeek" to myWeek.toString(),
            "partnerWeek" to partnerWeek.toString(),
        )

    fun canDecrement(offset: Int): Boolean = offset > MIN_WEEK_OFFSET

    fun canIncrement(offset: Int): Boolean = offset < MAX_WEEK_OFFSET

    /**
     * 颜色快选列表：选中色在快捷表里就原样用；不在就补到行首
     * （Dart `_paletteIncluding`，比较时忽略大小写）。
     */
    fun paletteIncluding(selectedHex: String): List<String> {
        val normalized = selectedHex.uppercase()
        val present = QUICK_PICK_HEXES.any { it.uppercase() == normalized }
        return if (present) QUICK_PICK_HEXES else listOf(selectedHex) + QUICK_PICK_HEXES
    }

    fun colorRows(binding: PartnerTimetableBindingModel): List<CoupleColorRowView> = listOf(
        CoupleColorRowView(
            label = CoupleStrings.coupleTimetableLegendMine.zh,
            paletteHexes = paletteIncluding(binding.mineColorHex),
            selectedHex = binding.mineColorHex,
        ),
        CoupleColorRowView(
            label = CoupleStrings.coupleTimetableLegendPartner.zh,
            paletteHexes = paletteIncluding(binding.partnerColorHex),
            selectedHex = binding.partnerColorHex,
        ),
        CoupleColorRowView(
            label = CoupleStrings.coupleTimetableLegendTogether.zh,
            paletteHexes = paletteIncluding(binding.togetherColorHex),
            selectedHex = binding.togetherColorHex,
        ),
    )

    /** 忙碌时按钮文案接 `...`（Dart `'$base...'`）。 */
    fun busyLabel(base: String, busy: Boolean): String = if (busy) "$base..." else base

    fun unlinkDialog(): CoupleConfirmDialogView = CoupleConfirmDialogView(
        title = CoupleStrings.coupleTimetableUnlinkConfirmTitle.zh,
        message = CoupleStrings.coupleTimetableUnlinkConfirmMessage.zh,
        cancelLabel = CoupleStrings.cancelAction.zh,
        confirmLabel = CoupleStrings.coupleTimetableUnlink.zh,
    )

    /**
     * 整页 viewState。
     *
     * @param binding null = 尚未绑定（未绑定态只剩导出/导入两个按钮）。
     * @param partnerProfileName 本地缓存里的对方课表档案名，优先于绑定名（Dart
     *   `partnerProfile?.name ?? binding.partnerName`）。
     */
    @Suppress("LongParameterList")
    fun buildViewState(
        binding: PartnerTimetableBindingModel?,
        webdavConfig: CoupleWebdavConfig,
        hasStoredPassword: Boolean,
        busy: CoupleBusyState,
        partnerCourseCount: Int,
        partnerProfileName: String?,
        myWeek: Int,
        partnerWeek: Int,
        zone: ZoneId = ZoneId.systemDefault(),
    ): CoupleTimetableSettingsViewState {
        val webdavConnected = isWebdavConnected(webdavConfig.username, hasStoredPassword)
        val bound = binding != null

        val webdavButtons = if (!webdavConnected) {
            listOf(
                CoupleActionButton(
                    id = WEBDAV_CONNECT,
                    label = CoupleStrings.coupleWebdavConnect.zh,
                    loading = false,
                    enabled = true,
                ),
            )
        } else {
            listOf(
                CoupleActionButton(
                    id = WEBDAV_PULL,
                    label = busyLabel(CoupleStrings.coupleWebdavPullNow.zh, busy.isPullingWebdav),
                    loading = busy.isPullingWebdav,
                    enabled = !busy.isPullingWebdav,
                ),
                CoupleActionButton(
                    id = WEBDAV_UPLOAD,
                    label = busyLabel(
                        CoupleStrings.coupleWebdavUploadForPartner.zh,
                        busy.isUploadingWebdav,
                    ),
                    loading = busy.isUploadingWebdav,
                    enabled = !busy.isUploadingWebdav,
                ),
                CoupleActionButton(
                    id = WEBDAV_DISCONNECT,
                    label = CoupleStrings.coupleWebdavDisconnect.zh,
                    loading = false,
                    enabled = true,
                ),
            )
        }

        val coupleButtons = buildList {
            add(
                CoupleActionButton(
                    id = COUPLE_EXPORT,
                    label = busyLabel(CoupleStrings.coupleTimetableExportForPartner.zh, busy.isExporting),
                    loading = busy.isExporting,
                    enabled = !busy.isExporting,
                ),
            )
            add(
                CoupleActionButton(
                    id = COUPLE_IMPORT,
                    label = busyLabel(CoupleStrings.coupleTimetableImportPartner.zh, busy.isImporting),
                    loading = busy.isImporting,
                    enabled = !busy.isImporting,
                ),
            )
            if (bound) {
                add(
                    CoupleActionButton(
                        id = COUPLE_UNLINK,
                        label = busyLabel(CoupleStrings.coupleTimetableUnlink.zh, busy.isUnlinking),
                        loading = busy.isUnlinking,
                        enabled = !busy.isUnlinking,
                    ),
                )
            }
        }

        val weekOffset = binding?.weekOffset ?: 0

        return CoupleTimetableSettingsViewState(
            title = CoupleStrings.coupleTimetableTitle.zh,
            sectionTitle = sectionTitle(bound),
            bound = bound,
            partnerNameLabel = CoupleStrings.coupleTimetablePartnerNameLabel.zh,
            partnerName = partnerProfileName ?: binding?.partnerName.orEmpty(),
            courseCountLabel = courseCountLabel(partnerCourseCount),
            lastImportedText = formatDateTimeOrDash(binding?.lastImportedAtIso, zone),
            webdavTitle = CoupleStrings.coupleWebdavTitle.zh,
            webdavStatusText = webdavStatusText(webdavConfig.username, hasStoredPassword),
            webdavRemotePathText = remotePathText(webdavConfig.partnerTimetableRemotePath),
            webdavLastPulledText = lastPulledText(webdavConfig.lastPulledAtIso, zone),
            webdavButtons = webdavButtons,
            coupleSectionTitle = CoupleStrings.coupleTimetableTitle.zh,
            coupleButtons = coupleButtons,
            showWeekOffset = bound,
            weekOffsetTitle = CoupleStrings.coupleTimetableWeekOffsetTitle.zh,
            weekOffsetLabel = weekOffsetLabel(weekOffset),
            weekOffsetPreview = weekOffsetPreview(myWeek, partnerWeek),
            canDecrementOffset = canDecrement(weekOffset),
            canIncrementOffset = canIncrement(weekOffset),
            showColors = bound,
            colorsTitle = CoupleStrings.coupleTimetableColorsTitle.zh,
            colorRows = binding?.let { colorRows(it) }.orEmpty(),
            unlinkConfirmTitle = CoupleStrings.coupleTimetableUnlinkConfirmTitle.zh,
            unlinkConfirmMessage = CoupleStrings.coupleTimetableUnlinkConfirmMessage.zh,
            unlinkConfirmCancelLabel = CoupleStrings.cancelAction.zh,
            unlinkConfirmActionLabel = CoupleStrings.coupleTimetableUnlink.zh,
        )
    }

    // ── 结果提示（Toast） ──

    /** 导入对方课表：成功/更新 + 「其中 N 条格式损坏已跳过」后缀（Dart 原样拼接）。 */
    fun importToast(updated: Boolean, droppedTotal: Int): SyncToast {
        val base = if (updated) {
            CoupleStrings.coupleTimetableImportUpdated.zh
        } else {
            CoupleStrings.coupleTimetableImportSuccess.zh
        }
        val suffix = if (droppedTotal > 0) {
            CoupleStrings.importPartialSkippedSuffix.filled("count", droppedTotal.toString())
        } else {
            ""
        }
        return SyncToast(message = base + suffix, isError = false)
    }

    /** 坚果云拉取：四态（失败时错误码走本地化表，缺省为「拉取失败」）。 */
    fun pullToast(status: CoupleWebdavPullStatus, errorCode: String?): SyncToast = when (status) {
        CoupleWebdavPullStatus.IMPORTED -> SyncToast(CoupleStrings.coupleWebdavPullImported.zh, isError = false)
        CoupleWebdavPullStatus.UPDATED -> SyncToast(CoupleStrings.coupleWebdavPullUpdated.zh, isError = false)
        CoupleWebdavPullStatus.UNCHANGED -> SyncToast(CoupleStrings.coupleWebdavPullUnchanged.zh, isError = false)
        CoupleWebdavPullStatus.FAILED -> SyncToast(
            message = CoupleStrings.localizeServiceMessage(errorCode ?: "couple_webdav_pull_failed"),
            isError = true,
        )
    }

    /** 上传我的课表：返回错误码即失败（Dart `errorCode != null` 分支）。 */
    fun uploadToast(errorCode: String?): SyncToast = if (errorCode == null) {
        SyncToast(CoupleStrings.coupleWebdavUploadSuccess.zh, isError = false)
    } else {
        SyncToast(CoupleStrings.localizeServiceMessage(errorCode), isError = true)
    }

    fun webdavConnectFailedToast(): SyncToast =
        SyncToast(CoupleStrings.coupleWebdavTestFailed.zh, isError = true)

    fun disconnectFailedToast(): SyncToast =
        SyncToast(CoupleStrings.saveFailed.zh, isError = true)

    fun unlinkSuccessToast(): SyncToast =
        SyncToast(CoupleStrings.coupleTimetableUnlinkSuccess.zh, isError = false)

    // 按钮 id（渲染层回调里判身份用，避免按文案匹配）。
    const val WEBDAV_CONNECT = "webdav_connect"
    const val WEBDAV_PULL = "webdav_pull"
    const val WEBDAV_UPLOAD = "webdav_upload"
    const val WEBDAV_DISCONNECT = "webdav_disconnect"
    const val COUPLE_EXPORT = "couple_export"
    const val COUPLE_IMPORT = "couple_import"
    const val COUPLE_UNLINK = "couple_unlink"
}
