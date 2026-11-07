package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.app.AppLocaleRuntime

/**
 * 支持作者页文案（逐字取自 `lib/l10n/app_zh.arb`）。
 *
 * 与许可页同一纪律：测试用 MiniJson 直读 ARB 逐字对拍，不手抄信任。
 *
 * 为什么独立成 `*Strings.kt` 而不是夹在 `SupportCreatorModel.kt` 里：
 * i18n 棘轮门禁（`CjkLiteralGateTest`）按**文件名**识别文案表，`*Strings*.kt`
 * 整文件豁免、由 `SupportCreatorModelTest.arbStringsMatchModel` 对拍管辖；
 * 夹在模型文件里则全表计入中文字面量基线（2026-11-02 `8114b625` 新增
 * `pageTitle` 时即因此把 HEAD 搞红）。与 `AboutUpdatePageStrings.kt` 同理。
 */
object SupportCreatorStrings {
    /** ARB `supportCreatorTitle`：顶栏标题（与头卡 `heroTitle` 不同，避免进页读两遍同一句）。 */
    val pageTitle: String get() = AppLocaleRuntime.text("supportCreatorTitle", "请作者喝杯咖啡")
    val heroTitle: String get() = AppLocaleRuntime.text("supportHeroTitle", "支持轻屿课表继续更新")
    val heroSubtitle: String get() = AppLocaleRuntime.text("supportHeroSubtitle", "你的支持会直接用于维护课表、教务导入适配与体验优化")
    val methodTitle: String get() = AppLocaleRuntime.text("supportMethodTitle", "选择支持方式")
    val wechatLabel: String get() = AppLocaleRuntime.text("wechatLabel", "微信")
    val alipayLabel: String get() = AppLocaleRuntime.text("alipayLabel", "支付宝")
    val scanQrWechatTitle: String get() = AppLocaleRuntime.text("scanQrWechatTitle", "使用微信扫描二维码")
    val scanQrAlipayTitle: String get() = AppLocaleRuntime.text("scanQrAlipayTitle", "使用支付宝扫描二维码")
    val scanQrSubtitle: String get() = AppLocaleRuntime.text("scanQrSubtitle", "截图并导入扫一扫，感谢支持")
    val weChatHint: String get() = AppLocaleRuntime.text("supportWeChatHint", "使用微信扫一扫支持作者")
    val alipayHint: String get() = AppLocaleRuntime.text("supportAlipayHint", "使用支付宝扫一扫支持作者")
    val tapQrHint: String get() = AppLocaleRuntime.text("supportTapQrHint", "点击放大扫码")
    val saveShort: String get() = AppLocaleRuntime.text("supportSaveShort", "保存")
    val saveToGallery: String get() = AppLocaleRuntime.text("saveToGallery", "保存到相册")
    val savedToGallery: String get() = AppLocaleRuntime.text("savedToGallery", "已保存到相册")
    val saveToGalleryFailed: String get() = AppLocaleRuntime.text("saveToGalleryFailed", "保存到相册失败")
    val donorListTitle: String get() = AppLocaleRuntime.text("donorListTitle", "鸣谢名单")
    val donorListEmpty: String get() = AppLocaleRuntime.text("donorListEmpty", "名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布")
    val donorListLoadFailed: String get() = AppLocaleRuntime.text("donorListLoadFailed", "暂时无法加载在线鸣谢名单")
    val reloadAction: String get() = AppLocaleRuntime.text("reloadAction", "重新加载")
    val runningBadge: String get() = AppLocaleRuntime.text("supportRunningBadge", "运行中")
    val chipAdapters: String get() = AppLocaleRuntime.text("supportChipAdapters", "教务适配")
    val chipFixes: String get() = AppLocaleRuntime.text("supportChipFixes", "修复问题")
    val chipPolish: String get() = AppLocaleRuntime.text("supportChipPolish", "体验优化")
    val completeThanks: String get() = AppLocaleRuntime.text("supportCompleteThanks", "感谢你支持轻屿课表继续打磨")
    val confirmedShort: String get() = AppLocaleRuntime.text("supportConfirmedShort", "已支持")

    /** ARB `closeAction`（与诊断/课表等域共用的全局键）：二维码预览弹层的「关闭」。 */
    val closeAction: String get() = AppLocaleRuntime.text("closeAction", "关闭")

    /** ARB `updatedAtLabel`（`更新于 {time}`）。 */
    fun updatedAtLabel(time: String): String = "更新于 $time"

    /** ARB `saveFailedWithError`（`保存失败：{error}`）。 */
    fun saveFailedWithError(error: String): String = "保存失败：$error"

    /** 当前支持方式对应的扫码标题（Dart 三元：wechat ? scanQrWechatTitle : scanQrAlipayTitle）。 */
    fun scanTitleFor(method: SupportMethod): String = when (method) {
        SupportMethod.WECHAT -> scanQrWechatTitle
        SupportMethod.ALIPAY -> scanQrAlipayTitle
    }

    /** 当前支持方式对应的提示语（Dart :_buildPaymentCard 的两条 hint）。 */
    fun hintFor(method: SupportMethod): String = when (method) {
        SupportMethod.WECHAT -> weChatHint
        SupportMethod.ALIPAY -> alipayHint
    }
}
