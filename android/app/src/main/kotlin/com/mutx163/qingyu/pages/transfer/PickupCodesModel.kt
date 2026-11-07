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

    /**
     * 一条直达链接：URI + 可选的目标包名（Dart `PickupCodeLink`）。
     *
     * 包名不是必填：`cainiao://` 这类私有 scheme 在多数机型上要靠 `setPackage`
     * 才不会被别的 App 抢走；https 兜底链接不需要限定。
     */
    data class Link(
        val uri: String,
        val packageName: String? = null,
    )

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
        /** 按书写顺序逐条尝试的直达链接（Dart `links`）。 */
        val links: List<Link> = emptyList(),
        /** 直达全失败后逐个拉起的官方 App 包名（Dart `appPackages`）。 */
        val appPackages: List<String> = emptyList(),
        /** 最后才用的网页兜底；null = 没有兜底。 */
        val webUri: String? = null,
        /** 是否强制新开目标页（QuickJump 用它修「淘宝在后台时跳不动」的机型）。 */
        val clearTask: Boolean = false,
    ) {
        /**
         * 屏上标题；**键不在文案表里时返回空串**，由 [entryTitle] 统一回落成「未命名入口」。
         *
         * 不能回落成键名（`pickupCodePresetFoo`）：键名非空，`entryTitle` 的
         * `takeIf { it.isNotBlank() }` 就永远走不到兜底，内部标识符会直接上屏。
         */
        val title: String get() = TransferExtStrings.valueOf(titleKey)?.text.orEmpty()

        /** 屏上行说明；缺键时为空串，渲染层据此不画说明行。 */
        val hint: String get() = TransferExtStrings.valueOf(hintKey)?.text.orEmpty()
    }

    enum class Group { IDENTITY, PARCELS }

    /**
     * 七个入口，顺序照抄 Dart `kPickupCodePresets`（:23-190）。
     *
     * 这个顺序**有意义**：列表按「一天里最可能用到的」从上往下排。
     * 单测钉住顺序，防止有人「整理」时按字母排。
     *
     * 链接、包名、网页兜底同样逐字照抄 Dart —— 这些不是「可选优化」，
     * 是「点了有没有反应」的全部内容；随手改一个百分号编码，淘宝那条就永远打不开。
     */
    val presets: List<Preset> = listOf(
        Preset(
            titleKey = "pickupCodePresetCainiao",
            hintKey = "pickupCodePresetCainiaoHint",
            icon = "qrCode",
            group = Group.IDENTITY,
            links = listOf(
                Link("cainiao://desktop/station_code", "com.cainiao.wireless"),
                Link("cainiao://client.main", "com.cainiao.wireless"),
            ),
            appPackages = listOf("com.cainiao.wireless"),
            webUri = "https://market.m.taobao.com/app/cn-yz/multi-activity/authCode.html" +
                "?bizEntry=ALIPAY_GUOGUO",
        ),
        Preset(
            titleKey = "pickupCodePresetTaobao",
            hintKey = "pickupCodePresetTaobaoHint",
            icon = "qrCode",
            group = Group.IDENTITY,
            links = listOf(
                Link(
                    "taobao://m.taobao.com/tbopen/index.html?h5Url=" +
                        "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                        "1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code" +
                        "%3Fx-ssr%3Dtrue",
                    "com.taobao.taobao",
                ),
                Link(
                    "tbopen://m.taobao.com/tbopen/index.html?h5Url=" +
                        "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                        "1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code" +
                        "%3Fx-ssr%3Dtrue",
                    "com.taobao.taobao",
                ),
            ),
            appPackages = listOf("com.taobao.taobao"),
            webUri = "https://pages-fast.m.taobao.com/wow/z/uniapp/1011717/last-mile-fe/" +
                "end-collect-platform/identity-code?x-ssr=true",
        ),
        Preset(
            titleKey = "pickupCodePresetPinduoduo",
            hintKey = "pickupCodePresetPinduoduoHint",
            icon = "qrCode",
            group = Group.IDENTITY,
            links = listOf(
                Link(
                    "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE" +
                        "&entry_source=11&refer_page_name=login&refer_page_sn=10169",
                    "com.xunmeng.pinduoduo",
                ),
                Link(
                    "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE" +
                        "&entry_source=11",
                    "com.xunmeng.pinduoduo",
                ),
                Link("pinduoduo://com.xunmeng.pinduoduo/mdkd/package", "com.xunmeng.pinduoduo"),
            ),
            appPackages = listOf("com.xunmeng.pinduoduo"),
            webUri = "https://m.pinduoduo.net/mdkd/package?entry_source=18" +
                "&extra_params=from_wx_jump%3D1&p_channel=0",
        ),
        Preset(
            titleKey = "pickupCodePresetTaobaoParcels",
            hintKey = "pickupCodePresetTaobaoParcelsHint",
            icon = "parcel",
            group = Group.PARCELS,
            links = listOf(
                Link(
                    "taobao://m.taobao.com/tbopen/index.html?h5Url=" +
                        "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                        "1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome",
                    "com.taobao.taobao",
                ),
                Link(
                    "tbopen://m.taobao.com/tbopen/index.html?h5Url=" +
                        "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F" +
                        "1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome",
                    "com.taobao.taobao",
                ),
            ),
            appPackages = listOf("com.taobao.taobao"),
            webUri = "https://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/" +
                "m-end-school-tab/home",
        ),
        Preset(
            titleKey = "pickupCodePresetPinduoduoParcels",
            hintKey = "pickupCodePresetPinduoduoParcelsHint",
            icon = "parcel",
            group = Group.PARCELS,
            links = listOf(Link("pinduoduo://com.xunmeng.pinduoduo/mdkd/package", "com.xunmeng.pinduoduo")),
            appPackages = listOf("com.xunmeng.pinduoduo"),
            webUri = "https://m.pinduoduo.net/mdkd/package?entry_source=18" +
                "&extra_params=from_wx_jump%3D1&p_channel=0",
        ),
        Preset(
            titleKey = "pickupCodePresetJdParcels",
            hintKey = "pickupCodePresetJdParcelsHint",
            icon = "parcel",
            group = Group.PARCELS,
            links = listOf(
                Link(
                    "openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C" +
                        "%22des%22%3A%22orderlist%22%7D",
                    "com.jingdong.app.mall",
                ),
            ),
            appPackages = listOf("com.jingdong.app.mall"),
            webUri = "https://order.jd.com/center/list.action",
        ),
        Preset(
            titleKey = "pickupCodePresetDouyinParcels",
            hintKey = "pickupCodePresetDouyinParcelsHint",
            icon = "parcel",
            group = Group.PARCELS,
            links = listOf(
                Link("snssdk1128://ecom_order_list", "com.ss.android.ugc.aweme"),
                Link("snssdk1128://wallet", "com.ss.android.ugc.aweme"),
                Link("snssdk2329://ecom_order_list", "com.ss.android.ugc.aweme.lite"),
                Link("snssdk2329://wallet", "com.ss.android.ugc.aweme.lite"),
            ),
            appPackages = listOf("com.ss.android.ugc.aweme", "com.ss.android.ugc.aweme.lite"),
            // 抖音没有公开的「待取快递」网页入口（电商页要求登录 App 内账号，
            // 网页会落到商城首页）。兜底用订单列表页，至少比「点了没反应」强（Dart 原文）。
            webUri = "https://haohuo.jinritemai.com/views/order/list",
        ),
    )

    /**
     * 全部入口需要探测的包名（去重，保持首次出现顺序）。
     *
     * 给「一次查完装没装」用（Dart `pickupCodeAllPackages`）：逐个入口各查一遍同一批包名
     * 会在按了七下之后把 `PackageManager` 查七遍。
     */
    fun allPackages(): List<String> {
        val result = LinkedHashSet<String>()
        for (preset in presets) {
            result.addAll(preset.appPackages)
        }
        return result.toList()
    }

    /**
     * 某个包名装没装（渲染层据此把整行淡到 55%、首字加删除线，并把状态写进无障碍标签）。
     *
     * `installed` 为 null = 还没查到 / 查不到 ⇒ **当作已安装**：宁可少显示一句提示，
     * 也不能把「能点、点了就跳过去」的入口标成「未安装」（Android 11+ 包可见性没配好时
     * 查询会一律返回 false，那时候照实显示会变成七个入口全标未安装）。
     */
    fun isInstalled(preset: Preset, installed: Set<String>?): Boolean {
        if (installed == null) return true
        // 没有 App 级兜底的入口（只有网页）不存在「未安装」：`any {}` 在空列表上返回
        // false，会把「只有网页兜底」的入口恒标成未安装（Dart `_isMissing` 同款判据）。
        if (preset.appPackages.isEmpty()) return true
        return preset.appPackages.any { installed.contains(it) }
    }

    // ── 品牌色与首字（Dart `pickup_code_icons.dart` / `_PickupCodeGlyph`） ──

    /** 兜底色：不在品牌表里的入口沿用它（Dart `pickupCodeAccentFor` 的 `_` 分支）。 */
    const val DEFAULT_ACCENT_LIGHT: Long = 0xFF3482FF
    const val DEFAULT_ACCENT_DARK: Long = 0xFF7EB0FF

    /**
     * 品牌强调色（ARGB，亮/暗两档），按入口键取。
     *
     * 为什么颜色在模型层：这是**固定语义色**（各平台品牌主色），与主题无关；放在渲染层
     * 会变成页面里的 `Color(0x…)` 字面量，深色/换肤时看着像漏改。颜色属于入口数据，
     * 与链接、包名同一张表，因此跟数据一起放这里。
     *
     * 与 Dart 的唯一有意差异：Dart 的 switch 漏了 `*Parcels` 两条，导致「淘宝（查待取）」
     * 「拼多多（查待取）」拿到兜底蓝，与同品牌的身份码行不同色。这里按品牌补齐——
     * 同一平台在两个分组里颜色一致，才符合「首字认平台、颜色做辅助」的原设计。
     */
    private val brandAccents: Map<String, Pair<Long, Long>> = mapOf(
        "pickupCodePresetCainiao" to (0xFFF97316L to 0xFFFFA24DL),
        "pickupCodePresetTaobao" to (0xFFEF4444L to 0xFFFF7A6EL),
        "pickupCodePresetPinduoduo" to (0xFFDC2626L to 0xFFF87171L),
        "pickupCodePresetTaobaoParcels" to (0xFFEF4444L to 0xFFFF7A6EL),
        "pickupCodePresetPinduoduoParcels" to (0xFFDC2626L to 0xFFF87171L),
        "pickupCodePresetJdParcels" to (0xFFE11D48L to 0xFFFB7185L),
        "pickupCodePresetDouyinParcels" to (0xFF18181BL to 0xFFE4E4E7L),
    )

    /** 某入口的品牌色；未知入口回落到 [DEFAULT_ACCENT_LIGHT] / [DEFAULT_ACCENT_DARK]。 */
    fun accentFor(preset: Preset, dark: Boolean): Long {
        val pair = brandAccents[preset.titleKey]
        return when {
            pair == null -> if (dark) DEFAULT_ACCENT_DARK else DEFAULT_ACCENT_LIGHT
            dark -> pair.second
            else -> pair.first
        }
    }

    /**
     * 平台首字（Dart `_PickupCodeGlyph` 的 `title.characters.first`）。
     *
     * 用 `offsetByCodePoints` 而不是 `take(1)`：后者会把代理对（emoji / 生僻字）
     * 劈成半个字符，界面上出现方块。空标题回落 `?`，与 Dart 一致。
     */
    fun glyphOf(preset: Preset): String = firstGlyph(preset.title)

    /** [glyphOf] 的纯函数内核（可单独用任意标题验证切字行为）。 */
    internal fun firstGlyph(title: String): String {
        if (title.isEmpty()) return "?"
        return title.substring(0, title.offsetByCodePoints(0, 1))
    }

    val title: String get() = TransferExtStrings.pickupCodeTitle.text

    fun groupTitle(group: Group): String = when (group) {
        Group.IDENTITY -> TransferExtStrings.pickupCodeIdentitySectionTitle.text
        Group.PARCELS -> TransferExtStrings.pickupCodeParcelsSectionTitle.text
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
     * 「一个原因码都没有」时的兜底值。
     *
     * 这条是给 [reasonText] 用的：全部尝试都没留下原因码（例如入口一条链接都没配）时，
     * 界面仍要念出「未知原因」，不能把冒号后面留空。Dart 的 `_reasonLabel` 接的是可空值，
     * 落到 `_ =>` 兜底；这里显式给一个常量，避免调用方各写一份 `?:`。
     */
    const val REASON_UNKNOWN_FALLBACK = "unknown"

    /**
     * 原因码 → 屏上文字。
     *
     * 未知原因码回落「未知原因」——**不能返回 null 或空串**：Dart 的 switch 有 `_ =>` 兜底，
     * 少了兜底用户会看到「打不开「京东」：」后面空着。
     */
    fun reasonText(code: String): String = when (code) {
        REASON_NO_ACTIVITY -> TransferExtStrings.pickupCodeReasonNoActivity.text
        REASON_APP_NOT_FOUND -> TransferExtStrings.pickupCodeReasonAppNotFound.text
        REASON_INVALID_URI -> TransferExtStrings.pickupCodeReasonInvalidUri.text
        REASON_INVALID_PACKAGE -> TransferExtStrings.pickupCodeReasonInvalidPackage.text
        REASON_TIMEOUT -> TransferExtStrings.pickupCodeReasonTimeout.text
        REASON_UNSUPPORTED -> TransferExtStrings.pickupCodeReasonUnsupported.text
        else -> TransferExtStrings.pickupCodeReasonUnknown.text
    }

    // ── 跳转结果的三种话术 ──

    /** 一条入口的标题（找不到就是「未命名入口」，不显示空串）。 */
    fun entryTitle(preset: Preset?): String = preset?.title?.takeIf { it.isNotBlank() }
        ?: TransferExtStrings.pickupCodeUntitledEntry.text

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
    val launchFailedHint: String get() = TransferExtStrings.pickupCodeLaunchFailedHint.text

    /** 平台完全不支持时的提示（桌面 / Web）。 */
    val unsupportedMessage: String get() = TransferExtStrings.pickupCodeUnsupported.text

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
            base + "，" + TransferExtStrings.pickupCodeSemanticsNotInstalled.text
        }
    }
}
