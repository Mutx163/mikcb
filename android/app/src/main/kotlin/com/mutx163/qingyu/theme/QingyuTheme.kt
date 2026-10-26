package com.mutx163.qingyu.theme

/**
 * 语义取色层（`lib/ui/hyperos/hyperos_theme.dart:11-208` 的 Kotlin 端口）。
 *
 * - `dark = false/true` 对应 Flutter 侧 `Theme.of(context).brightness` 的
 *   light/dark 两条分支；
 * - 无 seed（`seedHex == null` 或非法）时保持 Miuix 固定蓝，与 Flutter
 *   `ThemeSeedScope` 未挂载时的回落一致；
 * - 有 seed 时走 [QingyuSeedAccent] 派生（深色近黑回落墨色、承载面提亮、
 *   禁用家族浅色状态）；
 * - Miuix `colorScheme` 形参名以 Phase 3 开工对照 0.9.4 实物为准，
 *   composeP1 接线层按本文件的语义逐项填入 `lightColorScheme()/darkColorScheme()`。
 */
object QingyuTheme {

    fun scaffoldBackground(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.BACKGROUND else QingyuMikcbOverrides.SETTINGS_BACKGROUND

    /**
     * 深色用最高级容器（`surfaceContainerHighest #FF2D2D2D`），不用与页底同色的
     * `surfaceContainer #FF242424`，否则设置组卡片在暗色下隐形
     *（`hyperos_theme.dart:21-29` 注释）。
     */
    fun card(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SURFACE_CONTAINER_HIGHEST
        else QingyuLightPalette.SURFACE_CONTAINER

    fun primaryText(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_BACKGROUND else QingyuMikcbOverrides.SETTINGS_PRIMARY_TEXT

    fun secondaryText(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_SURFACE_VARIANT_SUMMARY
        else QingyuMikcbOverrides.SETTINGS_SECONDARY_TEXT

    fun actionIcon(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_SURFACE_VARIANT_ACTIONS
        else QingyuLightPalette.ON_SURFACE_VARIANT_ACTIONS

    fun sectionLabel(dark: Boolean): Int = actionIcon(dark)

    /** 按压缩痕：Miuix 无 rowHighlight token，Compose 侧按 pressed 语义实现。 */
    fun rowHighlight(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SECONDARY else QingyuMikcbOverrides.SETTINGS_PRESSED

    fun primary(seedHex: String? = null, dark: Boolean): Int {
        val fallback =
            if (dark) QingyuDarkPalette.PRIMARY else QingyuLightPalette.PRIMARY
        if (seedHex == null) return fallback
        return QingyuSeedAccent.resolveSeedAccent(seedHex, dark) ?: inkFallback(dark)
    }

    fun primarySurface(seedHex: String? = null, dark: Boolean): Int {
        val fallback =
            if (dark) QingyuDarkPalette.PRIMARY else QingyuLightPalette.PRIMARY
        if (seedHex == null) return fallback
        return QingyuSeedAccent.resolveSeedSurface(seedHex, dark) ?: fallback
    }

    fun surfaceContainer(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SURFACE_CONTAINER else QingyuLightPalette.SURFACE_CONTAINER

    fun surfaceContainerHighest(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SURFACE_CONTAINER_HIGHEST
        else QingyuLightPalette.SURFACE_CONTAINER_HIGHEST

    fun error(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ERROR else QingyuLightPalette.ERROR

    fun onError(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_ERROR else QingyuLightPalette.ON_ERROR

    fun success(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SUCCESS else QingyuLightPalette.SUCCESS

    fun dividerLine(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.DIVIDER_LINE else QingyuLightPalette.DIVIDER_LINE

    fun outline(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.OUTLINE else QingyuLightPalette.OUTLINE

    fun windowDimming(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.WINDOW_DIMMING else QingyuLightPalette.WINDOW_DIMMING

    fun secondary(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SECONDARY else QingyuLightPalette.SECONDARY

    fun fieldLabel(dark: Boolean): Int =
        if (dark) QingyuFixedTokens.FIELD_LABEL_DARK else QingyuFixedTokens.FIELD_LABEL_LIGHT

    fun destructive(): Int = QingyuFixedTokens.DESTRUCTIVE

    /**
     * 输入框框体填充：亮降一级用 secondary（`#E6E6E6`，`#F0F0F0` 会融进页面），
     * 暗维持 Miuix 默认 secondaryContainer（`hyperos_theme.dart:256-266`）。
     */
    fun textFieldContainer(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SECONDARY_CONTAINER else QingyuLightPalette.SECONDARY

    fun elevatedSurface(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SURFACE_CONTAINER_HIGHEST
        else QingyuLightPalette.SURFACE_CONTAINER

    fun inverseSurface(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.SURFACE_CONTAINER_HIGHEST
        else QingyuLightPalette.ON_SURFACE

    fun onInverseSurface(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_SURFACE else QingyuLightPalette.ON_PRIMARY

    fun onAccent(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_SURFACE else QingyuLightPalette.ON_PRIMARY

    fun disabledPrimary(seedAccent: Int? = null, dark: Boolean): Int =
        QingyuSeedAccent.resolveSeedDisabled(seedAccent, dark)
            ?: if (dark) QingyuDarkPalette.DISABLED_PRIMARY else QingyuLightPalette.DISABLED_PRIMARY

    fun disabledOnPrimary(seedAccent: Int? = null, dark: Boolean): Int =
        QingyuSeedAccent.resolveSeedDisabledInk(seedAccent, dark)
            ?: if (dark) QingyuDarkPalette.DISABLED_ON_PRIMARY else QingyuLightPalette.DISABLED_ON_PRIMARY

    private fun inkFallback(dark: Boolean): Int =
        if (dark) QingyuDarkPalette.ON_BACKGROUND else QingyuMikcbOverrides.SETTINGS_PRIMARY_TEXT

    /**
     * 按槽位名取色（Compose 接线层用）。key 大小写不敏感、前后空白容忍；
     * **未知 key 返回 null**（调用方回落默认，不抛不崩）。
     */
    fun colorFor(slotKey: String, dark: Boolean, seedHex: String? = null): Int? =
        when (slotKey.trim().lowercase()) {
            "primary" -> primary(seedHex, dark)
            "primarysurface" -> primarySurface(seedHex, dark)
            "scaffoldbackground" -> scaffoldBackground(dark)
            "card" -> card(dark)
            "primarytext" -> primaryText(dark)
            "secondarytext" -> secondaryText(dark)
            "actionicon" -> actionIcon(dark)
            "sectionlabel" -> sectionLabel(dark)
            "rowhighlight" -> rowHighlight(dark)
            "surfacecontainer" -> surfaceContainer(dark)
            "surfacecontainerhighest" -> surfaceContainerHighest(dark)
            "error" -> error(dark)
            "onerror" -> onError(dark)
            "success" -> success(dark)
            "dividerline" -> dividerLine(dark)
            "outline" -> outline(dark)
            "windowdimming" -> windowDimming(dark)
            "secondary" -> secondary(dark)
            "fieldlabel" -> fieldLabel(dark)
            "destructive" -> destructive()
            "textfieldcontainer" -> textFieldContainer(dark)
            "elevatedsurface" -> elevatedSurface(dark)
            "inversesurface" -> inverseSurface(dark)
            "onaccent" -> onAccent(dark)
            else -> null
        }
}
