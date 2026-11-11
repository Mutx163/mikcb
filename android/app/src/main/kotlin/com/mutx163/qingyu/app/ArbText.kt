package com.mutx163.qingyu.app

import java.util.Locale

/**
 * 一条 ARB 文案：`key` 是对拍用的 ARB 键，`zh` 是简体中文原文（兜底值）。
 *
 * ## 为什么 `.zh` 还在、但界面不许再读它
 *
 * `zh` 保留成**纯字面量**，只给两条路径用：
 * 1. `*Strings*ParityTest` 与 `i18n/app_zh.arb` 逐字对拍（断言原文，不受当前语言影响）；
 * 2. [AppLocaleRuntime] 在目标语言缺键时兜底。
 *
 * 界面与模型层一律读 [text]：它按当前语言查 [ArbCatalog]。
 *
 * ## 为什么这里不用 Compose 的 snapshot state
 *
 * `app/` 是纯 Kotlin 层（`AppLayerPurityTest` 守着：L0 直接 kotlinc 跑真 JVM，没有
 * Compose 运行时），所以语言只能是一个普通 `@Volatile` 字段。重组由壳负责：
 * `PagesShellActivity` 在语言变化时给 `PagesShell` 换一个 `key`，整棵子树重建，
 * 所有 `ArbText.text` 自然按新语言重算（不靠局部 `remember` 缓存）。
 *
 * 本类原先在 22 个包里各抄了一份（只有 `zh` 字段）。现在统一到这里，
 * 各包用 `typealias ArbText = com.mutx163.qingyu.app.ArbText` 保留旧名字，
 * 2950+ 处构造点无需改签名。
 */
data class ArbText(
    val key: String,
    val zh: String,
    /**
     * 非空 = 已经按实参填好的整句（例如「已启用 3/5 个」）。
     *
     * 为什么需要它：`text` 默认按 [key] 去 `ArbCatalog` 取**模板**，模板里的 `{count}`
     * 不会被替换；而有些行要先算好实参再塞回 `ArbText`（`customizeDetails` / 周数读数 /
     * 日期副标题…）。这类值放这里，既保留 [key] 供对拍，又让 `text` 直接返回填好的句子。
     */
    val resolved: String? = null,
) {

    /** 当前语言下的文案；已填好的整句优先，否则查表，缺键 / 未初始化语言时回落 [zh]。 */
    val text: String
        get() = resolved ?: AppLocaleRuntime.text(key, zh)

    /** 替换模板里的单个占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String =
        fill(text, mapOf(name to value))

    /** [value] 为数字时的便利重载（Dart 侧多为 int）。 */
    fun filled(name: String, value: Int): String = filled(name, value.toString())

    /** 替换模板里的多个占位符（按传入顺序逐个替换）。 */
    fun filled(vararg pairs: Pair<String, String>): String =
        fill(text, pairs.toMap())

    /**
     * 由模板派生一条**已带实参**的文案：key 不变（供对拍），`text` 直接返回填好结果。
     *
     * 界面不得直读 `zh`；需要“先算实参再上屏”的构造点一律走这里。
     */
    fun withArguments(name: String, value: String): ArbText = copy(resolved = filled(name, value))

    /** 多占位符版本（`{count}` / `{max}` 这类）。 */
    fun withArguments(vararg pairs: Pair<String, String>): ArbText = copy(resolved = filled(*pairs))
}

/**
 * 极简 ICU 复数展开：只处理 ARB 里真实出现过的
 * `{count, plural, =1{…} other{…}}` 形态（目前全仓仅 `lanEditConnectedClientsValue` 一条）。
 *
 * 不做完整 ICU 解析——遇到没见过的形态原样保留，宁可显示模板也不吞文案。
 */
private fun expandPlural(template: String, values: Map<String, String>): String {
    if (!template.contains(", plural,")) return template
    val start = template.indexOf('{')
    if (start < 0) return template
    val close = template.lastIndexOf('}')
    if (close <= start) return template
    val head = template.substring(start + 1, close)
    val name = head.substringBefore(',').trim()
    val count = values[name]?.toIntOrNull() ?: return template
    val body = head.substringAfter(", plural,", "")
    val branches = Regex("""(=\d+|other)\s*\{([^{}]*)}""").findAll(body).associate {
        it.groupValues[1] to it.groupValues[2]
    }
    val chosen = branches["=$count"] ?: branches["other"] ?: return template
    return template.replaceRange(start, close + 1, chosen)
}

/** 先展开复数，再替换普通占位符。 */
private fun fill(template: String, values: Map<String, String>): String {
    var result = expandPlural(template, values)
    for ((name, value) in values) {
        result = result.replace("{$name}", value)
    }
    return result
}

/**
 * 进程级「当前界面语言」。
 *
 * ## 取值口径
 *
 * - [set] 写入 `appLocaleTag` 的规范化值（`""` = 跟随系统）；
 * - [UNSET] 表示「宿主还没告诉我们」——此时 [text] 一律回落简体中文。单测没走宿主，
 *   断言的中文原文因此不会被 JVM 默认语言（常见 en_US）改掉；
 * - 正式启动时 `PagesShellActivity.attachBaseContext` 会先把存档里的 tag 写进来，
 *   所以首帧就是正确语言，不存在「先闪一下中文」。
 *
 * ## 为什么用普通字段（而不是 snapshot state）
 *
 * `app/` 必须保持纯 Kotlin（见 `AppLayerPurityTest`），不能 import Compose。
 * 语言变化的「可观察性」由 UI 层注入的两个钩子解决：
 * - [revisionReader]：`text` 每次取值先读一下；UI 层把它接到 snapshot state，
 *   于是所有读文案的 Composable 自动订阅重组；
 * - [onLocaleChanged]：语言真正变化时通知 UI 层把上面的 state 自增。
 * 这样既不需要重建壳（返回栈不丢），也不用让 `app/` 依赖 Compose。
 */
object AppLocaleRuntime {

    /** 尚未初始化：单测与纯 JVM 调用的默认态，按简体中文出字。 */
    const val UNSET: String = "\u0000unset"

    /** 支持的语言标签，顺序与 `AppLocalizations.supportedLocales` 一致。 */
    val SUPPORTED_TAGS: List<String> = listOf("en", "ja", "ko", "zh", "zh_HK", "zh_TW")

    /**
     * UI 层注入的「订阅点」：`text` 每次取值都会读它。
     * UI 层接成 snapshot state 后，这个读操作会自动把当前 Composable 登记为观察者。
     */
    @Volatile
    var revisionReader: () -> Int = { 0 }

    /** 语言真正变化时通知 UI 层（由 UI 层把 revision state 自增）。 */
    @Volatile
    var onLocaleChanged: (() -> Unit)? = null

    /**
     * **真实系统语言**（语言标签，如 `zh-Hans-CN` / `en-US`），由壳注入。
     *
     * ## 为什么必须有它（2026-11-10 用户报障的根因）
     *
     * [set] 为了日期格式化会把进程默认 Locale 改成**用户手选的**语言。而「跟随系统」
     * 原来又去读 `Locale.getDefault()`——读到的正是 App 自己刚改过的值：切到英语后再
     * 选「跟随系统」，永远回到英语，系统是中文也不管用（自指链）。
     *
     * 现在「跟随系统」只认真实系统语言：壳在 `attachBaseContext` 里、**覆盖之前**从
     * `resources.configuration.locales[0]` 读出并注入，系统语言变化时（`onConfigurationChanged`）
     * 再刷新一次。`null` = 还没注入（单测 / 纯 JVM），此时才退回 `Locale.getDefault()`。
     */
    @Volatile
    private var systemLocaleTag: String? = null

    @Volatile
    private var currentTag: String = UNSET

    /** 当前 tag；未初始化时返回 [UNSET]。 */
    val tag: String
        get() = currentTag

    /** 当前实际生效的语言（`en` / `ja` / `ko` / `zh` / `zh_HK` / `zh_TW`），未初始化返回 `null`。 */
    val language: String?
        get() = languageOf(currentTag)

    /**
     * 壳注入 / 刷新**真实系统语言**（`zh-Hans-CN`、`en-US`…）。
     *
     * 只在壳里调：冷启动在覆盖配置语言**之前**注入一次；系统语言变化时
     * （`onConfigurationChanged`）再刷一次。当前是「跟随系统」时，刷新会立刻
     * 通知 UI 并把默认 Locale 换成新的系统语言——用户改了系统语言、不重启 App 也跟随。
     */
    fun setSystemLocaleTag(rawTag: String?) {
        val normalized = rawTag?.trim().orEmpty()
        if (normalized == systemLocaleTag) return
        systemLocaleTag = normalized.ifEmpty { null }
        // `currentTag` 为空串 = 跟随系统；此时系统语言变了，界面与日期都要跟着走。
        if (currentTag.isEmpty()) {
            onLocaleChanged?.invoke()
            Locale.setDefault(systemLocale())
        }
    }

    /** 单测用：当前注入的系统语言（未注入 = null）。 */
    fun systemLocaleTagForTest(): String? = systemLocaleTag

    /**
     * 设置当前语言（`""` = 跟随系统）。
     *
     * 同时把 `Locale.setDefault` 调成对应语言——日期格式化（`DateFormat` 的等价实现）
     * 读的是默认 Locale，不跟着改会出现「界面英文、日期仍按中文格式」。
     *
     * 选「跟随系统」时**改成真实系统语言**（[systemLocaleTag]），不再沿用上一次手选语言：
     * 否则切过英语再回来，界面和日期都会停在英语（2026-11-10 用户报障）。
     */
    fun set(tag: String?) {
        val normalized = normalize(tag)
        if (normalized == currentTag) return
        currentTag = normalized
        // 先通知 UI 层（触发重组），再改默认 Locale；两者都在主线程回调里完成。
        onLocaleChanged?.invoke()
        val effective = languageOf(normalized) ?: return
        Locale.setDefault(
            if (normalized.isEmpty()) systemLocale() else localeOf(effective),
        )
    }

    /** 单测用：恢复到未初始化态，避免用例之间互相污染。 */
    fun resetForTest() {
        currentTag = UNSET
        systemLocaleTag = null
    }

    /** 按当前语言取文案；未初始化或目标语言缺键时回落 [fallbackZh]。 */
    fun text(key: String, fallbackZh: String): String {
        // 读一下 UI 层的订阅点：Composable 里调用会登记重组依赖，语言一变自动刷新。
        revisionReader()
        val language = languageOf(currentTag) ?: return fallbackZh
        return ArbCatalog.text(language, key) ?: fallbackZh
    }

    /**
     * 规范化语言标签：`en-US` / `en_US_POSIX` → `en`；`zh-Hant-HK` → `zh_HK`。
     * 不认识的值返回空串（= 跟随系统），与 `SettingsGeneralPage.normalizeLocaleTag` 同口径。
     */
    fun normalize(raw: String?): String {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return ""
        val canonical = trimmed.replace('-', '_')
        if (canonical in SUPPORTED_TAGS) return canonical
        val parts = canonical.split('_')
        val language = parts.firstOrNull()?.lowercase(Locale.ROOT).orEmpty()
        if (language == "zh") {
            val rest = parts.drop(1).joinToString("_").lowercase(Locale.ROOT)
            if (rest.contains("hk") || rest.contains("mo") || rest.contains("hant_hk")) return "zh_HK"
            if (rest.contains("tw") || rest.contains("hant_tw")) return "zh_TW"
            return "zh"
        }
        return if (language in SUPPORTED_TAGS) language else ""
    }

    /** tag → 实际语言；空串按系统语言解析，未初始化返回 `null`。 */
    fun languageOf(tag: String): String? {
        if (tag == UNSET) return null
        if (tag.isNotEmpty()) return normalize(tag).ifEmpty { systemLanguage() }
        return systemLanguage()
    }

    /**
     * 系统语言 → 支持的语言，口径对齐 Flutter `basicLocaleListResolution`：
     * 先按语言码匹配；中文再按地区/文字分简繁；都不认识回落 `en`（与 Flutter 取
     * `supportedLocales` 第一项一致）。
     *
     * **真源是壳注入的 [systemLocaleTag]**，不是 `Locale.getDefault()`——后者会被
     * [set] 改成用户手选的语言，反读会形成自指（见该字段 KDoc）。
     * 只有壳没注入时（单测 / 纯 JVM）才退回进程默认 Locale。
     */
    private fun systemLanguage(): String = matchSupportedLocale(systemLocale())

    /** 真实系统 Locale：优先注入值，没有就用进程默认（单测场景）。 */
    private fun systemLocale(): Locale {
        val injected = systemLocaleTag
        if (!injected.isNullOrBlank()) {
            runCatching { Locale.forLanguageTag(injected.replace('_', '-')) }
                .getOrNull()
                ?.let { return it }
        }
        return Locale.getDefault()
    }

    /** 设备 locale → 支持的语言标签（中文按地区/文字分简繁，其余不认识回落 `en`）。 */
    private fun matchSupportedLocale(locale: Locale): String {
        val language = locale.language.lowercase(Locale.ROOT)
        return when (language) {
            "zh" -> {
                val country = locale.country.uppercase(Locale.ROOT)
                val script = locale.script.lowercase(Locale.ROOT)
                when {
                    country == "HK" || country == "MO" -> "zh_HK"
                    country == "TW" -> "zh_TW"
                    script == "hant" -> "zh_TW"
                    else -> "zh"
                }
            }
            "ja", "ko", "en" -> language
            else -> "en"
        }
    }

    private fun localeOf(language: String): Locale = when (language) {
        "zh_HK" -> Locale.forLanguageTag("zh-Hant-HK")
        "zh_TW" -> Locale.forLanguageTag("zh-Hant-TW")
        else -> Locale.forLanguageTag(language)
    }
}
