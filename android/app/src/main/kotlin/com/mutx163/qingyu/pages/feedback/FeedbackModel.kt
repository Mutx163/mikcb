package com.mutx163.qingyu.pages.feedback

/**
 * 问题反馈页的纯结构模型（移植 `lib/screens/feedback_screen.dart` 的数据与交互语义，
 * 2026-10-26 快照）。
 *
 * ## 分层
 *
 * 与同批页面一致：本文件在 **main** 源集、零 Compose/Miuix 依赖（main 对全变体编译，
 * import miuix 会让 Flutter 的 prod 包编不过）；渲染在 composeP1 源集
 * `FeedbackPage.kt`。文案纪律、渠道顺序、URL 顺序都按 Dart 行号逐条对齐。
 *
 * ## 本页真正的“逻辑”在哪
 *
 * 页面本身几乎全是静态内容，Dart 侧真正有行为的是两条异步链路：
 * 1. `_openChannel`（`feedback_screen.dart:195-250`）——按顺序尝试候选 URL，
 *    **空串跳过**，任一成功就结束（成功时**不**污染剪贴板）；全部失败才复制
 *    `fallbackCopyValue` 并给黄色提示；
 * 2. `_openWechatOfficialAccount`（`:169-186`）——先把公众号名复制到剪贴板，
 *    再走同一条打开链路，提示语换成「请到微信中粘贴搜索」。
 *
 * 这里把两条链路抽成**纯函数** [runFeedbackOpenPlan]（打开动作与复制动作注入），
 * 于是顺序、跳过、回落语义都能在 JVM 单测里断言，不需要真机与剪贴板。
 */

/** 联系入口常量（Dart `feedback_screen.dart:36-59`，逐字照抄）。 */
object FeedbackContact {
    /** GitHub Issues。 */
    const val issuesUrl = "https://github.com/Mutx163/mikcb/issues"

    /** 小红书号（复制目标与副标题参数）。 */
    const val xiaohongshuId = "4976443029"
    const val xiaohongshuShareUrl = "https://xhslink.com/m/ALcscDMw39N"
    const val xiaohongshuProfileUrl = "https://www.xiaohongshu.com/user/profile/4976443029"

    /** 酷安号 + 网页/应用内两个候选入口。 */
    const val coolapkId = "Mutx666"
    const val coolapkUrl = "https://www.coolapk.com/u/739248"
    const val coolapkAppUrl = "coolmarket://www.coolapk.com/u/739248"

    /** QQ 群号与入群 key（深链与网页两条入口共用）。 */
    const val qqGroupId = "1077077989"
    const val qqGroupJoinKey = "TMCg23sigjbqS5nYrBx0kxc7JcuwHN8Q"

    /** 公众号名称（复制目标）与「只能唤起微信、进不去具体公众号」的入口。 */
    const val wechatOaName = "轻屿课表"
    const val wechatOpenUrl = "weixin://"

    /** 入群网页链接（Dart `_qqGroupJoinWebUrl`）。 */
    const val qqGroupJoinWebUrl =
        "https://qm.qq.com/cgi-bin/qm/qr?from=app&p=android&jump_from=webapi&k=$qqGroupJoinKey"

    /**
     * 入群深链（Dart `_qqGroupJoinAppUrl`）：
     * `mqqopensdkapi://bizAgent/qm/qr?url=` + `Uri.encodeComponent(网页链接)`。
     */
    val qqGroupJoinAppUrl: String =
        "mqqopensdkapi://bizAgent/qm/qr?url=" + dartEncodeComponent(qqGroupJoinWebUrl)
}

/** 渠道在界面上用的品牌徽标（Phase 4 换真图时按这些记录对齐）。 */
data class FeedbackBadge(
    /** 原 Flutter 资产路径（Flutter 打包在 assets/flutter_assets 下，Compose 暂不读）。 */
    val assetPath: String,
    /** 是否 SVG（Flutter 侧走 SvgPicture；PNG 走 Image.asset）。 */
    val isSvg: Boolean = false,
    /** 资产染色（Dart `ColorFilter.srcIn` 的目标色），null = 不染色。 */
    val tintHex: String? = null,
    /** 徽标底色；null = 跟随明暗（深色 #1E1E1E / 浅色白）。 */
    val backgroundColorHex: String? = null,
)

/**
 * 一个反馈渠道。[urls] 是**按尝试顺序**排好的候选，
 * [fallbackCopyValue] 是全部打不开时复制的内容；
 * [preCopy] 仅在微信公众号渠道使用（先复制名称再打开微信）。
 */
data class FeedbackChannel(
    /** 稳定 id（渲染层 key、测试锚点；不是 ARB 键）。 */
    val id: String,
    val title: String,
    val subtitle: String,
    /** 点右侧复制按钮复制的值。 */
    val copyValue: String,
    /** 复制成功的提示（Dart `_copyText` 的 successMessage）。 */
    val copyToast: String,
    val urls: List<String>,
    /** 所有候选都打不开时复制的内容。 */
    val fallbackCopyValue: String,
    /** 打开前的提示；默认「正在打开……」。 */
    val openingToast: String = FeedbackStrings.openingChannel,
    /** 打开前先复制的值（微信公众号专用）。 */
    val preCopy: String? = null,
    val badge: FeedbackBadge,
)

/** 整页视图状态（目前无外部输入：渠道是常量清单）。 */
data class FeedbackPageView(
    val title: String,
    val channels: List<FeedbackChannel>,
)

/**
 * 渠道清单 —— 顺序即界面顺序（Dart `:72-157`）：
 * GitHub → 小红书 → 酷安 → QQ 群 → 微信公众号。
 */
fun buildFeedbackPageView(): FeedbackPageView = FeedbackPageView(
    title = FeedbackStrings.title,
    channels = listOf(
        FeedbackChannel(
            id = "github",
            title = FeedbackStrings.githubIssueTitle,
            subtitle = FeedbackStrings.githubIssueSubtitle,
            copyValue = FeedbackContact.issuesUrl,
            copyToast = FeedbackStrings.copiedIssueAddress,
            urls = listOf(FeedbackContact.issuesUrl),
            fallbackCopyValue = FeedbackContact.issuesUrl,
            badge = FeedbackBadge(
                assetPath = "assets/branding/github.svg",
                isSvg = true,
                tintHex = "#FF181717",
            ),
        ),
        FeedbackChannel(
            id = "xiaohongshu",
            title = FeedbackStrings.xiaohongshuTitle,
            subtitle = FeedbackStrings.xiaohongshuSubtitle(FeedbackContact.xiaohongshuId),
            copyValue = FeedbackContact.xiaohongshuId,
            copyToast = FeedbackStrings.copiedXiaohongshuId,
            // 先分享短链、再主页；失败依次继续。
            urls = listOf(
                FeedbackContact.xiaohongshuShareUrl,
                FeedbackContact.xiaohongshuProfileUrl,
            ),
            fallbackCopyValue = FeedbackContact.xiaohongshuId,
            badge = FeedbackBadge(
                assetPath = "assets/branding/xiaohongshu.svg",
                isSvg = true,
                tintHex = "#FFFFFFFF",
                backgroundColorHex = "#FFFF2442",
            ),
        ),
        FeedbackChannel(
            id = "coolapk",
            title = FeedbackStrings.coolapkTitle,
            subtitle = FeedbackStrings.coolapkSubtitle(FeedbackContact.coolapkId),
            copyValue = FeedbackContact.coolapkId,
            copyToast = FeedbackStrings.copiedCoolapkId,
            // Dart 顺序：网页在前、coolmarket:// 在后。
            urls = listOf(FeedbackContact.coolapkUrl, FeedbackContact.coolapkAppUrl),
            fallbackCopyValue = FeedbackContact.coolapkId,
            badge = FeedbackBadge(
                assetPath = "assets/branding/coolapk.png",
                backgroundColorHex = "#FF4CAF50",
            ),
        ),
        FeedbackChannel(
            id = "qq",
            title = FeedbackStrings.qqGroupTitle,
            subtitle = FeedbackStrings.qqGroupSubtitle(FeedbackContact.qqGroupId),
            copyValue = FeedbackContact.qqGroupId,
            copyToast = FeedbackStrings.copiedQqGroupId,
            // 先 QQ 深链（能直接拉起入群页），再网页。
            urls = listOf(
                FeedbackContact.qqGroupJoinAppUrl,
                FeedbackContact.qqGroupJoinWebUrl,
            ),
            fallbackCopyValue = FeedbackContact.qqGroupId,
            badge = FeedbackBadge(
                assetPath = "assets/branding/qq.svg",
                isSvg = true,
                tintHex = "#FF12B7F5",
            ),
        ),
        FeedbackChannel(
            id = "wechat",
            title = FeedbackStrings.wechatOaTitle,
            subtitle = FeedbackStrings.wechatOaSubtitle(FeedbackContact.wechatOaName),
            copyValue = FeedbackContact.wechatOaName,
            copyToast = FeedbackStrings.copiedWechatOaName,
            // 公众号没有可靠的深链：只能唤起微信，让用户粘贴搜索。
            urls = listOf(FeedbackContact.wechatOpenUrl),
            fallbackCopyValue = FeedbackContact.wechatOaName,
            openingToast = FeedbackStrings.wechatOaOpenHint,
            preCopy = FeedbackContact.wechatOaName,
            badge = FeedbackBadge(
                assetPath = "assets/branding/launcher_icon.png",
            ),
        ),
    ),
)

/**
 * 一次「打开渠道」的完整计划：提示语 + 打开前是否先复制 + 候选 URL + 回落复制值。
 *
 * [urls] 里允许出现空串（Dart 侧有 `if (candidateUrl.isEmpty) continue;` 的防御），
 * 由 [runFeedbackOpenPlan] 统一跳过，宿主不需要自己清。
 */
data class FeedbackOpenPlan(
    val openingToast: String,
    val preCopy: String?,
    val urls: List<String>,
    val fallbackCopyValue: String,
    val failureToast: String = FeedbackStrings.openChannelFailed,
)

/** 由渠道构造打开计划（渲染层只需要 [FeedbackChannel]，语义都在这里）。 */
fun feedbackOpenPlanFor(channel: FeedbackChannel): FeedbackOpenPlan = FeedbackOpenPlan(
    openingToast = channel.openingToast,
    preCopy = channel.preCopy,
    urls = channel.urls,
    fallbackCopyValue = channel.fallbackCopyValue,
)

/** 打开结果：要么某个 URL 成功拉起，要么全部失败并已复制回落值。 */
sealed interface FeedbackOpenOutcome {
    /** 第 [url] 个候选成功拉起（此时**不**复制任何东西）。 */
    data class Opened(val url: String) : FeedbackOpenOutcome

    /** 全部候选失败：已复制 [value]，提示 [toast]（黄色提示，Dart `AppToastKind.warning`）。 */
    data class CopiedFallback(val value: String, val toast: String) : FeedbackOpenOutcome
}

/**
 * `_openChannel` 的纯函数版本：
 *
 * 1. [FeedbackOpenPlan.preCopy] 非空时先复制一次（微信公众号）；
 * 2. 按顺序尝试 [FeedbackOpenPlan.urls]，**空串跳过**、不调用 [launch]；
 * 3. 任一 [launch] 返回 true 即返回 [FeedbackOpenOutcome.Opened]，**不再复制**；
 * 4. 全部失败：复制 [FeedbackOpenPlan.fallbackCopyValue] 并返回
 *    [FeedbackOpenOutcome.CopiedFallback]（含失败提示语）。
 *
 * [launch] / [copy] 由宿主注入（真实实现走 `launch_url` 通道与剪贴板），
 * 所以这段逻辑可测、可复用到 Android/iOS 之外的场景。
 */
fun runFeedbackOpenPlan(
    plan: FeedbackOpenPlan,
    launch: (String) -> Boolean,
    copy: (String) -> Unit = {},
): FeedbackOpenOutcome {
    plan.preCopy?.let { copy(it) }
    for (url in plan.urls) {
        if (url.isEmpty()) continue
        if (launch(url)) return FeedbackOpenOutcome.Opened(url)
    }
    copy(plan.fallbackCopyValue)
    return FeedbackOpenOutcome.CopiedFallback(
        value = plan.fallbackCopyValue,
        toast = plan.failureToast,
    )
}

/**
 * Dart `Uri.encodeComponent` 的等价实现——**只保留**未保留字符
 * `A-Z a-z 0-9 - _ . ! ~ * ' ( )`，其余按 UTF-8 字节百分号编码（大写十六进制）。
 *
 * 为什么不用 `java.net.URLEncoder`：它是表单编码（空格→`+`，保留集会不同），
 * 拼出来的 QQ 深链与 Flutter 版会不一致。QQ 入群链接是唯一依赖它的地方，
 * 但这条必须逐字节一致，否则微信/QQ 拉不起来又没有回退提示。
 */
fun dartEncodeComponent(value: String): String {
    val unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
    val hex = "0123456789ABCDEF"
    val out = StringBuilder()
    for (byte in value.toByteArray(Charsets.UTF_8)) {
        val code = byte.toInt() and 0xFF
        val ch = code.toChar()
        if (code < 0x80 && unreserved.indexOf(ch) >= 0) {
            out.append(ch)
        } else {
            out.append('%').append(hex[code shr 4]).append(hex[code and 0x0F])
        }
    }
    return out.toString()
}

/**
 * 问题反馈页文案（逐字取自 `lib/l10n/app_zh.arb`，2026-10-26 快照）。
 *
 * 纪律：测试用 MiniJson 直读 ARB 逐字对拍；带参文案按同一占位符拼装。
 * 多语言资源本身留 Phase 4 接线（本批只钉 zh）。
 */
object FeedbackStrings {
    /** ARB `feedbackTitle`。 */
    const val title = "问题反馈"

    /** ARB `githubIssueTitle` / `githubIssueSubtitle`。 */
    const val githubIssueTitle = "GitHub Issue"
    const val githubIssueSubtitle = "提交问题、建议，查看已有反馈"

    /** ARB `feedbackXiaohongshuTitle` / `feedbackXiaohongshuSubtitle`。 */
    const val xiaohongshuTitle = "小红书"

    fun xiaohongshuSubtitle(id: String): String = "小红书号：$id"

    /** ARB `feedbackCoolapkTitle` / `feedbackCoolapkSubtitle`。 */
    const val coolapkTitle = "酷安"

    fun coolapkSubtitle(id: String): String = "酷安号：$id"

    /** ARB `feedbackQqGroupTitle` / `feedbackQqGroupSubtitle`。 */
    const val qqGroupTitle = "QQ 群"

    fun qqGroupSubtitle(id: String): String = "群号：$id"

    /** ARB `feedbackWechatOaTitle` / `feedbackWechatOaSubtitle`。 */
    const val wechatOaTitle = "微信公众号"

    fun wechatOaSubtitle(name: String): String = name

    /** 各渠道复制成功提示。 */
    const val copiedIssueAddress = "已复制 Issue 地址"
    const val copiedXiaohongshuId = "已复制小红书号"
    const val copiedCoolapkId = "已复制酷安号"
    const val copiedQqGroupId = "已复制 QQ 群号"
    const val copiedWechatOaName = "已复制公众号名称"

    /** ARB `feedbackWechatOaOpenHint`：微信渠道专用的打开前提示。 */
    const val wechatOaOpenHint = "已复制公众号名称，请到微信中粘贴搜索"

    /** ARB `feedbackOpeningChannel`：普通渠道打开前提示。 */
    const val openingChannel = "正在打开……"

    /** ARB `feedbackOpenChannelFailed`：全部候选失败后的黄色提示。 */
    const val openChannelFailed = "无法打开，已复制相关信息"
}
