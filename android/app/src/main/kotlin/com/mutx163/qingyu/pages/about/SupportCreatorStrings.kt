package com.mutx163.qingyu.pages.about

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
    const val pageTitle = "请作者喝杯咖啡"
    const val heroTitle = "支持轻屿课表继续更新"
    const val heroSubtitle = "你的支持会直接用于维护课表、教务导入适配与体验优化"
    const val methodTitle = "选择支持方式"
    const val wechatLabel = "微信"
    const val alipayLabel = "支付宝"
    const val scanQrWechatTitle = "使用微信扫描二维码"
    const val scanQrAlipayTitle = "使用支付宝扫描二维码"
    const val scanQrSubtitle = "截图并导入扫一扫，感谢支持"
    const val weChatHint = "使用微信扫一扫支持作者"
    const val alipayHint = "使用支付宝扫一扫支持作者"
    const val tapQrHint = "点击放大扫码"
    const val saveShort = "保存"
    const val saveToGallery = "保存到相册"
    const val savedToGallery = "已保存到相册"
    const val saveToGalleryFailed = "保存到相册失败"
    const val donorListTitle = "鸣谢名单"
    const val donorListEmpty = "名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布"
    const val donorListLoadFailed = "暂时无法加载在线鸣谢名单"
    const val reloadAction = "重新加载"
    const val runningBadge = "运行中"
    const val chipAdapters = "教务适配"
    const val chipFixes = "修复问题"
    const val chipPolish = "体验优化"
    const val completeThanks = "感谢你支持轻屿课表继续打磨"
    const val confirmedShort = "已支持"

    /** ARB `closeAction`（与诊断/课表等域共用的全局键）：二维码预览弹层的「关闭」。 */
    const val closeAction = "关闭"

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
