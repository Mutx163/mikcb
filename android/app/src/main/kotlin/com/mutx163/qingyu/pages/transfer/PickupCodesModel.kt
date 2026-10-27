package com.mutx163.qingyu.pages.transfer

/**
 * 取件码页（`lib/screens/pickup_codes_screen.dart`，466 行）模型层。
 *
 * ## 这一页的全部内容就是一张固定表
 *
 * Dart 侧注释写得很直白：「固定入口表：**这就是这个页面的全部内容**，用户不能增删改。」
 * 七个入口分成两组（出示身份码 / 查待取快递），每组里按「一天里最可能用到的」排序。
 * 每个入口带一串按顺序尝试的跳转链接，全失败再拉起官方 App，最后网页兜底。
 *
 * ## 为什么模型层只做分组与文案
 *
 * 真正的「试一串链接」需要 `PackageManager` / `Intent`，属 Android 依赖，不能进模型层
 * （进了 JVM 单测就跑不了）。所以这里只负责：
 *
 * 1. **固定表本身**（顺序、分组、标题键、图标名）—— 数据，可单测；
 * 2. **失败原因码 → 文案**（`no_activity` / `app_not_found` / … / 未知兜底）；
 * 3. **跳转结果的三种话术**：直接跳成功（toast 说「没有公开直达页」）、
 *    拉起 App 兜底、彻底失败（带原因与建议）。
 *
 * 跳转动作由渲染层交给 [com.mutx163.qingyu.PickupCodeLauncher]，本类不碰 Intent。
 */
object PickupCodesModel {

    /** 一个固定入口（数据照 QuickJump 的 ENTRIES 抄下来，只做数据）。 */
    data class Preset(
        /** ARB 标题键（`pickupCodePreset*`）。 */
        val titleKey: String,
        /** ARB 说明键（`*Hint`）。 */
        val hintKey: String,
        /** 图标名：`qrCode`（身份码）/ `parcel`（查件）。 */
        val icon: String,
        /** 分组：身份码在前，查件在后（去柜子跟前第一件事是出示码）。 */
        val group: Group,
    ) {
        val title: String get() = TransferExtStrings.valueOf(titleKey)?.zh ?: titleKey
        val hint: String get() = TransferExtStrings.valueOf(hintKey)?.zh ?: hintKey
    }

    enum class Group { IDENTITY, PARCELS }

    /**
     * 七个入口，顺序照抄 Dart `kPickupCodePresets`（:23-190）。
     *
     * 这个顺序**有意义**：列表按「一天里最可能用到的」从上往下排。
     * 单测钉住顺序，防止有人「整理」时按字母排。
     */
    val presets: List<Preset> = listOf(
        Preset("pickupCodePresetCainiao", "pickupCodePresetCainiaoHint", "qrCode", Group.IDENTITY),
        Preset("pickupCodePresetTaobao", "pickupCodePresetTaobaoHint", "qrCode", Group.IDENTITY),
        Preset("pickupCodePresetPinduoduo", "pickupCodePresetPinduoduoHint", "qrCode", Group.IDENTITY),
        Preset("pickupCodePresetTaobaoParcels", "pickupCodePresetTaobaoParcelsHint", "parcel", Group.PARCELS),
        Preset("pickupCodePresetPinduoduoParcels", "pickupCodePresetPinduoduoParcelsHint", "parcel", Group.PARCELS),
        Preset("pickupCodePresetJdParcels", "pickupCodePresetJdParcelsHint", "parcel", Group.PARCELS),
        Preset("pickupCodePresetDouyinParcels", "pickupCodePresetDouyinParcelsHint", "parcel", Group.PARCELS),
    )

    val title: String get() = TransferExtStrings.pickupCodeTitle.zh

    fun groupTitle(group: Group): String = when (group) {
        Group.IDENTITY -> TransferExtStrings.pickupCodeIdentitySectionTitle.zh
        Group.PARCELS -> TransferExtStrings.pickupCodeParcelsSectionTitle.zh
    }

    /** 某一组里的入口（保持表内顺序）。 */
    fun presetsOf(group: Group): List<Preset> = presets.filter { it.group == group }

    /** 列表顺序即分组顺序：身份码组、查件组，各自内部保持表序。 */
    val groups: List<Group> = listOf(Group.IDENTITY, Group.PARCELS)

    // ── 失败原因码 → 文案（Dart `_reasonText`，:126-133） ──

    const val REASON_NO_ACTIVITY = "no_activity"
    const val REASON_APP_NOT_FOUND = "app_not_found"
    const val REASON_INVALID_URI = "invalid_uri"
    const val REASON_INVALID_PACKAGE = "invalid_package"
    const val REASON_TIMEOUT = "timeout"
    const val REASON_UNSUPPORTED = "unsupported"

    /**
     * 原因码 → 屏上文字。
     *
     * 未知原因码回落「未知原因」——**不能返回 null 或空串**：Dart 的 switch 有 `_ =>` 兜底，
     * 少了兜底用户会看到「打不开「京东」：」后面空着。
     */
    fun reasonText(code: String): String = when (code) {
        REASON_NO_ACTIVITY -> TransferExtStrings.pickupCodeReasonNoActivity.zh
        REASON_APP_NOT_FOUND -> TransferExtStrings.pickupCodeReasonAppNotFound.zh
        REASON_INVALID_URI -> TransferExtStrings.pickupCodeReasonInvalidUri.zh
        REASON_INVALID_PACKAGE -> TransferExtStrings.pickupCodeReasonInvalidPackage.zh
        REASON_TIMEOUT -> TransferExtStrings.pickupCodeReasonTimeout.zh
        REASON_UNSUPPORTED -> TransferExtStrings.pickupCodeReasonUnsupported.zh
        else -> TransferExtStrings.pickupCodeReasonUnknown.zh
    }

    // ── 跳转结果的三种话术 ──

    /** 一条入口的标题（找不到就是「未命名入口」，不显示空串）。 */
    fun entryTitle(preset: Preset?): String = preset?.title?.takeIf { it.isNotBlank() }
        ?: TransferExtStrings.pickupCodeUntitledEntry.zh

    /** 该入口所在的组名（语义标签里要念出来，用户才知道这是身份码还是查件）。 */
    fun entryGroupTitle(preset: Preset): String = groupTitle(preset.group)

    /** 直接拉起 App、但没有公开直达页时的 toast（Dart `pickupCodeOpenedAppToast`）。 */
    fun openedAppToast(name: String): String =
        TransferExtStrings.pickupCodeOpenedAppToast.filled("name", name)

    /** 彻底失败时的标题行（Dart `pickupCodeLaunchFailed`：`打不开「{name}」：{reason}`）。 */
    fun launchFailedMessage(name: String, reasonCode: String): String =
        TransferExtStrings.pickupCodeLaunchFailed.filled(
            "name" to name,
            "reason" to reasonText(reasonCode),
        )

    /** 失败提示下面的建议行。 */
    val launchFailedHint: String get() = TransferExtStrings.pickupCodeLaunchFailedHint.zh

    /** 平台完全不支持时的提示（桌面 / Web）。 */
    val unsupportedMessage: String get() = TransferExtStrings.pickupCodeUnsupported.zh

    /**
     * 无障碍标签（Dart `pickupCodeSemanticsEntry` + 未安装提示）。
     *
     * 读屏时只念「菜鸟」是不够的：用户要知道它在哪个组、以及装没装。
     */
    fun semanticsLabel(preset: Preset, installed: Boolean): String {
        val base = TransferExtStrings.pickupCodeSemanticsEntry.filled(
            "name" to entryTitle(preset),
            "group" to entryGroupTitle(preset),
        )
        return if (installed) {
            base
        } else {
            base + "，" + TransferExtStrings.pickupCodeSemanticsNotInstalled.zh
        }
    }
}
