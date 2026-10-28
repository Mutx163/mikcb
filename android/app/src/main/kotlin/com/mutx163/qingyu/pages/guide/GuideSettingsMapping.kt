package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.AppThemeMode
import com.mutx163.qingyu.app.ForuiTheme
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.TimetableSettingsModel

/**
 * 引导页「个性化定制」页的**宿主侧设置映射**（纯 Kotlin，零 Android 依赖，可 JVM 单测）。
 *
 * 职责边界：
 * - 渲染层（`composeP1` 的 `UserGuidePage`）只认 [GuideSettingsSnapshot] / [GuideSettingsPatch]，
 *   自己**不读不写** `TimetableSettingsModel`；
 * - 宿主（`ShellPageIndex`）在进入引导页时用 [snapshotFrom] 把当前设置投射成只读快照，
 *   在收到 `onSettingsPatch` 时用 [applyPatch] 算出新模型再落盘；
 * - [seedOptions] 给渲染层画主题色色板（来自 [ForuiTheme] 的种子色 + 中文名）。
 *
 * 与 Dart 原版 `lib/screens/user_guide_screen.dart:721+` 的个性化页对齐：
 * 菜单样式（列表/宫格）、深浅色（系统/浅色/深色）、主题色（种子色板）。
 */
object GuideSettingsMapping {

    /**
     * 默认材质目前**恒为 false（液态玻璃）**。
     *
     * 原因：Compose 侧的 `TimetableSettingsModel` 目前**没有**对应 Dart `frostedBlur` /
     * `GlassModeChoice` 的字段（玻璃材质调参由外观编辑器的材质系统单独接入）。
     * 在材质系统接进设置模型之前，个性化页的材质卡只能显示默认态，写回也走 [GuideSettingsPatch.MaterialSolid]
     * 的 no-op 分支——等材质字段落地后，这里再改成从模型读取。
     */
    private const val MATERIAL_SOLID_UNAVAILABLE = false

    /** 从 `TimetableSettingsModel` 投射出个性化页的只读快照。 */
    fun snapshotFrom(model: TimetableSettingsModel): GuideSettingsSnapshot {
        return GuideSettingsSnapshot(
            homeMenuGrid = model.homeMenuStyle == HomeMenuStyle.GRID,
            materialSolid = MATERIAL_SOLID_UNAVAILABLE,
            themeMode = toGuideThemeMode(model.appThemeMode),
            // 快照的 seedHex 用来高亮色板里“当前选中”的那一块，所以取 foruiTheme 的种子色，
            // 保证它一定是 [seedOptions] 里某个已存在的色值（themeSeedColor 可能是自定义色，
            // 不在色板里，会出现“没有任何一块被选中”）。
            seedHex = model.foruiTheme.seedHex,
        )
    }

    /**
     * 把渲染层发来的 [patch] 应用到设置模型，返回**新**的 [TimetableSettingsModel]。
     *
     * - [GuideSettingsPatch.HomeMenuGrid]：写 `homeMenuStyle`；
     * - [GuideSettingsPatch.ThemeMode]：写 `appThemeMode`；
     * - [GuideSettingsPatch.SeedColor]：写 `foruiTheme`（按 seedHex 反查最近枚举）+ `themeSeedColor`；
     * - [GuideSettingsPatch.MaterialSolid]：**原样返回**（模型暂无材质字段，见 [MATERIAL_SOLID_UNAVAILABLE]）。
     */
    fun applyPatch(model: TimetableSettingsModel, patch: GuideSettingsPatch): TimetableSettingsModel {
        return when (patch) {
            is GuideSettingsPatch.HomeMenuGrid -> model.copy(
                homeMenuStyle = if (patch.grid) HomeMenuStyle.GRID else HomeMenuStyle.LIST,
            )

            is GuideSettingsPatch.ThemeMode -> model.copy(
                appThemeMode = toAppThemeMode(patch.mode),
            )

            is GuideSettingsPatch.SeedColor -> {
                // 按 seedHex 反查对应的 ForuiTheme；找不到（自定义色）就保留原枚举，只改 themeSeedColor。
                val matched = ForuiTheme.entries.firstOrNull {
                    it.seedHex.equals(patch.hex, ignoreCase = true)
                } ?: model.foruiTheme
                model.copy(foruiTheme = matched, themeSeedColor = patch.hex)
            }

            // 材质字段尚未接入 Compose 设置模型：补丁落地为 no-op，等材质系统接入后再实现。
            is GuideSettingsPatch.MaterialSolid -> model
        }
    }

    /**
     * 主题色色板：来自 [ForuiTheme] 的每个种子色 + 中文名。
     *
     * 中文名复用 `app_zh.arb` 的 `foruiTheme*` 现成键（[GuideStrings] 里已有对应 [ArbText]），
     * 逐字对齐，不做自造译名。顺序即 [ForuiTheme] 的枚举声明顺序。
     */
    fun seedOptions(): List<GuideSeedOption> {
        return ForuiTheme.entries.map { theme ->
            GuideSeedOption(
                hex = theme.seedHex,
                label = foruiThemeLabel(theme).zh,
            )
        }
    }

    /** [ForuiTheme] → 中文名 [ArbText]（键名与 `lib/l10n/app_zh.arb` 一致）。 */
    private fun foruiThemeLabel(theme: ForuiTheme): ArbText = when (theme) {
        ForuiTheme.MIUI -> GuideStrings.foruiThemeMiuix
        ForuiTheme.NEUTRAL -> GuideStrings.foruiThemeNeutral
        ForuiTheme.ZINC -> GuideStrings.foruiThemeZinc
        ForuiTheme.SLATE -> GuideStrings.foruiThemeSlate
        ForuiTheme.BLUE -> GuideStrings.foruiThemeBlue
        ForuiTheme.GREEN -> GuideStrings.foruiThemeGreen
        ForuiTheme.ORANGE -> GuideStrings.foruiThemeOrange
        ForuiTheme.RED -> GuideStrings.foruiThemeRed
        ForuiTheme.ROSE -> GuideStrings.foruiThemeRose
        ForuiTheme.VIOLET -> GuideStrings.foruiThemeViolet
        ForuiTheme.YELLOW -> GuideStrings.foruiThemeYellow
    }

    /** `app.AppThemeMode` → 引导页展示用的 [GuideThemeMode]。 */
    private fun toGuideThemeMode(mode: AppThemeMode): GuideThemeMode = when (mode) {
        AppThemeMode.SYSTEM -> GuideThemeMode.SYSTEM
        AppThemeMode.LIGHT -> GuideThemeMode.LIGHT
        AppThemeMode.DARK -> GuideThemeMode.DARK
    }

    /** [GuideThemeMode] → `app.AppThemeMode`（写回设置模型用）。 */
    private fun toAppThemeMode(mode: GuideThemeMode): AppThemeMode = when (mode) {
        GuideThemeMode.SYSTEM -> AppThemeMode.SYSTEM
        GuideThemeMode.LIGHT -> AppThemeMode.LIGHT
        GuideThemeMode.DARK -> AppThemeMode.DARK
    }
}
