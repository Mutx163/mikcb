package com.mutx163.qingyu.pages.transfer

/**
 * 导出与传输族**余量三件**（局域网编辑 / 取件码 / 传输预览对话框）用到的 ARB 文案。
 *
 * 为什么不并进 `TransferStrings.kt`：那份是 P3-G3 前两页（日历导出、数据备份迁移）
 * 的已交付产物，被 `TransferStringsParityTest` 按内容钉住了。按台账 §8「后到者改设计避让」，
 * 本批新建一份，不改动别人的验收基线。
 *
 * **逐字抄录，不许改写**：每条都在 [TransferExtStringsParityTest] 里与 `lib/l10n/app_zh.arb`
 * 机械比对；键名与 ARB 键逐字一致，便于 `grep` 双向核对。
 */
object TransferExtStrings {

    // ── 局域网编辑（lan_edit_screen.dart） ──
    val lanEditEntryTitle = ArbText("lanEditEntryTitle", "局域网编辑")
    val lanEditTitle = ArbText("lanEditTitle", "局域网编辑")
    val lanEditIntro = ArbText(
        "lanEditIntro",
        "开启后，同一 WiFi 或手机热点下的电脑可通过浏览器编辑当前课表，数据不会上传云端，关闭后即停止访问",
    )
    val lanEditStart = ArbText("lanEditStart", "开启局域网编辑")
    val lanEditStop = ArbText("lanEditStop", "停止")
    val lanEditStatusRunning = ArbText("lanEditStatusRunning", "编辑会话进行中")
    val lanEditAddressLabel = ArbText("lanEditAddressLabel", "访问地址")
    val lanEditAddressUnavailable = ArbText("lanEditAddressUnavailable", "未检测到局域网 IP，请确认已连接 WiFi 或已开启热点")
    val lanEditPinLabel = ArbText("lanEditPinLabel", "PIN")
    val lanEditPortLabel = ArbText("lanEditPortLabel", "端口")
    val lanEditCopyAddress = ArbText("lanEditCopyAddress", "复制地址")
    val lanEditCopied = ArbText("lanEditCopied", "地址已复制")
    val lanEditHotspotHint = ArbText(
        "lanEditHotspotHint",
        "如果宿舍 WiFi 无法访问，请尝试用手机开热点，再让电脑连接该热点",
    )
    val lanEditQrHint = ArbText("lanEditQrHint", "电脑扫描二维码打开控制台，需处于同一局域网")
    val lanEditStartFailed = ArbText("lanEditStartFailed", "启动失败")
    val lanEditConnectedClientsLabel = ArbText("lanEditConnectedClientsLabel", "已连接")
    val lanEditConnectedClientsNone = ArbText("lanEditConnectedClientsNone", "暂无")
    val lanEditConnectedClientsValue = ArbText("lanEditConnectedClientsValue", "{count} 台")
    val lanEditLastActivityLabel = ArbText("lanEditLastActivityLabel", "最近活动")
    val lanEditKeepAliveWhenLeavingTitle = ArbText("lanEditKeepAliveWhenLeavingTitle", "离开后保持开启")
    val lanEditKeepAliveWhenLeavingSubtitle =
        ArbText("lanEditKeepAliveWhenLeavingSubtitle", "关闭后离开本页就停止")

    // ── 取件码（pickup_codes_screen.dart） ──
    val pickupCodeTitle = ArbText("pickupCodeTitle", "取件码")
    val pickupCodeIdentitySectionTitle = ArbText("pickupCodeIdentitySectionTitle", "出示身份码")
    val pickupCodeParcelsSectionTitle = ArbText("pickupCodeParcelsSectionTitle", "查待取快递")
    val pickupCodeUntitledEntry = ArbText("pickupCodeUntitledEntry", "未命名入口")
    val pickupCodeUnsupported = ArbText("pickupCodeUnsupported", "当前平台不支持跳到其它应用")
    val pickupCodeLaunchFailed = ArbText("pickupCodeLaunchFailed", "打不开「{name}」：{reason}")
    val pickupCodeLaunchFailedHint = ArbText("pickupCodeLaunchFailedHint", "入口可能失效，试试直接打开 App")
    val pickupCodeOpenedAppToast = ArbText(
        "pickupCodeOpenedAppToast",
        "「{name}」没有公开的直达页，已打开对应 App，请在 App 内查看",
    )
    val pickupCodeSemanticsEntry = ArbText("pickupCodeSemanticsEntry", "{name}，{group}")
    val pickupCodeSemanticsNotInstalled = ArbText("pickupCodeSemanticsNotInstalled", "未安装对应应用")

    // 失败原因（launcher 回传的原因码 → 文案）
    val pickupCodeReasonNoActivity = ArbText("pickupCodeReasonNoActivity", "没有 App 响应这条链接")
    val pickupCodeReasonAppNotFound = ArbText("pickupCodeReasonAppNotFound", "没有找到这个 App")
    val pickupCodeReasonInvalidUri = ArbText("pickupCodeReasonInvalidUri", "链接格式不对")
    val pickupCodeReasonInvalidPackage = ArbText("pickupCodeReasonInvalidPackage", "包名格式不对")
    val pickupCodeReasonTimeout = ArbText("pickupCodeReasonTimeout", "系统没有响应（超时）")
    val pickupCodeReasonUnsupported = ArbText("pickupCodeReasonUnsupported", "当前平台不支持")
    val pickupCodeReasonUnknown = ArbText("pickupCodeReasonUnknown", "未知原因")

    // 七个固定入口的标题与说明（顺序即 Dart kPickupCodePresets 的顺序）
    val pickupCodePresetCainiao = ArbText("pickupCodePresetCainiao", "菜鸟")
    val pickupCodePresetCainiaoHint = ArbText("pickupCodePresetCainiaoHint", "驿站自提 / 快递柜")
    val pickupCodePresetTaobao = ArbText("pickupCodePresetTaobao", "淘宝")
    val pickupCodePresetTaobaoHint = ArbText("pickupCodePresetTaobaoHint", "菜鸟裹裹同款码")
    val pickupCodePresetPinduoduo = ArbText("pickupCodePresetPinduoduo", "拼多多")
    val pickupCodePresetPinduoduoHint = ArbText("pickupCodePresetPinduoduoHint", "驿站自提 / 快递柜")
    val pickupCodePresetTaobaoParcels = ArbText("pickupCodePresetTaobaoParcels", "淘宝")
    val pickupCodePresetTaobaoParcelsHint =
        ArbText("pickupCodePresetTaobaoParcelsHint", "淘宝的包裹列表")
    val pickupCodePresetPinduoduoParcels = ArbText("pickupCodePresetPinduoduoParcels", "拼多多")
    val pickupCodePresetPinduoduoParcelsHint =
        ArbText("pickupCodePresetPinduoduoParcelsHint", "拼多多的包裹列表")
    val pickupCodePresetJdParcels = ArbText("pickupCodePresetJdParcels", "京东")
    val pickupCodePresetJdParcelsHint = ArbText("pickupCodePresetJdParcelsHint", "京东的包裹列表")
    val pickupCodePresetDouyinParcels = ArbText("pickupCodePresetDouyinParcels", "抖音")
    val pickupCodePresetDouyinParcelsHint =
        ArbText("pickupCodePresetDouyinParcelsHint", "抖音的包裹列表")

    /**
     * 按 ARB 键取文案（不确定键名时用，例如从数据表里拿到的 key）。
     *
     * 返回 null 表示键不在本文件里 —— 调用方必须自己兜底，别把 null 直接拼进界面。
     */
    fun valueOf(key: String): ArbText? = allTexts.firstOrNull { it.key == key }

    /** 文案对拍用全集：新增文案必须加进这里，否则对拍测试看不见它。 */
    val allTexts: List<ArbText> = listOf(
        lanEditEntryTitle,
        lanEditTitle,
        lanEditIntro,
        lanEditStart,
        lanEditStop,
        lanEditStatusRunning,
        lanEditAddressLabel,
        lanEditAddressUnavailable,
        lanEditPinLabel,
        lanEditPortLabel,
        lanEditCopyAddress,
        lanEditCopied,
        lanEditHotspotHint,
        lanEditQrHint,
        lanEditStartFailed,
        lanEditConnectedClientsLabel,
        lanEditConnectedClientsNone,
        lanEditConnectedClientsValue,
        lanEditLastActivityLabel,
        lanEditKeepAliveWhenLeavingTitle,
        lanEditKeepAliveWhenLeavingSubtitle,
        pickupCodeTitle,
        pickupCodeIdentitySectionTitle,
        pickupCodeParcelsSectionTitle,
        pickupCodeUntitledEntry,
        pickupCodeUnsupported,
        pickupCodeLaunchFailed,
        pickupCodeLaunchFailedHint,
        pickupCodeOpenedAppToast,
        pickupCodeSemanticsEntry,
        pickupCodeSemanticsNotInstalled,
        pickupCodeReasonNoActivity,
        pickupCodeReasonAppNotFound,
        pickupCodeReasonInvalidUri,
        pickupCodeReasonInvalidPackage,
        pickupCodeReasonTimeout,
        pickupCodeReasonUnsupported,
        pickupCodeReasonUnknown,
        pickupCodePresetCainiao,
        pickupCodePresetCainiaoHint,
        pickupCodePresetTaobao,
        pickupCodePresetTaobaoHint,
        pickupCodePresetPinduoduo,
        pickupCodePresetPinduoduoHint,
        pickupCodePresetTaobaoParcels,
        pickupCodePresetTaobaoParcelsHint,
        pickupCodePresetPinduoduoParcels,
        pickupCodePresetPinduoduoParcelsHint,
        pickupCodePresetJdParcels,
        pickupCodePresetJdParcelsHint,
        pickupCodePresetDouyinParcels,
        pickupCodePresetDouyinParcelsHint,
    )
}
