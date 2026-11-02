package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.DartTime

/**
 * 支持作者页的纯结构模型（移植 `lib/screens/support_creator_screen.dart` +
 * `lib/services/support_creator_service.dart` 的数据部分，2026-10-26 快照）。
 *
 * ## 分层
 *
 * 与开源许可页同一套约定：本文件在 main 源集、**零 Compose/Miuix 依赖**
 * （main 对全变体编译，import miuix 会让 Flutter 的 prod 包编不过），
 * 只承载「JSON 解析 / 排序 / 文案」；渲染在 composeP1 源集。
 */

/** 一位支持者（Dart `SupportDonorEntry`）。 */
data class SupportDonorEntry(
    val name: String,
    val amount: String? = null,
    val date: String? = null,
    val message: String? = null,
)

/** 鸣谢名单整体（Dart `SupportDonorData`）。 */
data class SupportDonorData(
    val title: String? = null,
    val subtitle: String? = null,
    val subtitleNote: String? = null,
    val updatedAt: String? = null,
    val donors: List<SupportDonorEntry> = emptyList(),
)

/**
 * Dart `SupportDonorData.fromJson` 的纯逻辑部分（去掉网络 IO）：
 *
 * 1. `donors` 只收 Map 元素（Dart `whereType<Map<String,dynamic>>()`）；
 * 2. 每个条目四个字段各自 `trim`，`name` 缺省空串；
 * 3. **name 为空的条目被丢弃**（Dart :59）；
 * 4. 按 [compareDonorDateDesc] 排序（Dart :62）；
 * 5. title/subtitle/subtitleNote/updatedAt 各自 `trim`（可为 null）。
 *
 * ⚠️ 已知口径差：Dart 用 `List.sort`（非稳定排序），Kotlin 的 `sortedWith` 是稳定排序。
 * 两条记录**排序键完全相等**时，Dart 侧的相对顺序本来就不保证，这里以稳定排序为准。
 * 有日期可比的真实数据不受影响（见测试）。
 */
fun parseSupportDonorData(json: Map<String, Any?>): SupportDonorData {
    val donors = (json["donors"] as? List<*>)
        .orEmpty()
        .filterIsInstance<Map<*, *>>()
        .map { raw ->
            @Suppress("UNCHECKED_CAST")
            val map = raw as Map<String, Any?>
            SupportDonorEntry(
                name = (map["name"] as? String)?.trim() ?: "",
                amount = (map["amount"] as? String)?.trim(),
                date = (map["date"] as? String)?.trim(),
                message = (map["message"] as? String)?.trim(),
            )
        }
        .filter { it.name.isNotEmpty() }
        .sortedWith { a, b -> compareDonorDateDesc(a, b) }

    return SupportDonorData(
        title = (json["title"] as? String)?.trim(),
        subtitle = (json["subtitle"] as? String)?.trim(),
        subtitleNote = (json["subtitleNote"] as? String)?.trim(),
        updatedAt = (json["updatedAt"] as? String)?.trim(),
        donors = donors,
    )
}

/**
 * Dart `_compareDonorDateDesc`：**新的在前**。
 *
 * 分三段（顺序即优先级）：
 * 1. 两个日期都能解析 → 按时刻倒序；
 * 2. 只有一个能解析 → 能解析的在前（`-1`/`1`）；
 * 3. 都不能解析 → 拿**原始字符串**倒序比较；只有一个非空则它在前；都空则相等。
 */
fun compareDonorDateDesc(a: SupportDonorEntry, b: SupportDonorEntry): Int {
    val dateA = parseDonorDate(a.date)
    val dateB = parseDonorDate(b.date)
    if (dateA != null && dateB != null) {
        val cmp = dateB.compareTo(dateA)
        if (cmp != 0) return cmp
    } else if (dateA != null) {
        return -1
    } else if (dateB != null) {
        return 1
    } else {
        val rawA = a.date?.trim() ?: ""
        val rawB = b.date?.trim() ?: ""
        if (rawA.isNotEmpty() && rawB.isNotEmpty()) {
            val cmp = rawB.compareTo(rawA)
            if (cmp != 0) return cmp
        } else if (rawA.isNotEmpty()) {
            return -1
        } else if (rawB.isNotEmpty()) {
            return 1
        }
    }
    return 0
}

/** Dart `DateTime.tryParse`：解析不出返回 null（空白串同 null）。 */
private fun parseDonorDate(raw: String?): java.time.LocalDateTime? {
    if (raw == null) return null
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) return null
    return DartTime.tryParseIso(trimmed)
}

/** 支持方式（Dart `_SupportMethod`）。 */
enum class SupportMethod { WECHAT, ALIPAY }

/**
 * 支持作者页文案（逐字取自 `lib/l10n/app_zh.arb`）。
 *
 * 与许可页同一纪律：测试用 MiniJson 直读 ARB 逐字对拍，不手抄信任。
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
