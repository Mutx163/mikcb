package com.mutx163.qingyu.pages.settings

import java.util.Locale
import kotlin.math.roundToInt

/**
 * 材质面板「通用」页（`settings_appearance_editor.dart:921-1195` 的 `_buildGeneralMaterialPage`）。
 *
 * ## 页内顺序（:921-924）
 *
 * 「观感明显的在前」：总闸 → 首页顶栏玻璃 → 液态预设与八根旋钮 → 只读总览。
 *
 * ## 逐项对照
 *
 * | Flutter（行号） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSectionLabel(默认材质)`（:969） | `material.general.glassMode.label` | preference category |
 * | `_MaterialSegmented<GlassModeChoice>`（:974-983） | `material.general.glassMode` | `extra.SuperRadioButton`（两档，内联不开弹层） |
 * | 实体档说明（:985-993） | `SettingsDescription` | 整宽脚注 |
 * | `HyperosSectionLabel(首页顶栏玻璃)`（:995） | `material.general.homeBand.label` | preference category |
 * | `_MaterialSegmented<String>`（:1007-1017） | `material.general.homeBand` | `extra.SuperRadioButton` |
 * | `HyperosSectionLabel(高级材质)`（:1021） | `material.general.advanced.label` | preference category |
 * | 档位节点滑杆（:1423-1449） | `material.general.preset` | `MiuixSliderPreference`（10 格节点） |
 * | 八根旋钮（:1471-1577） | `material.general.tuning.*` | `MiuixSliderPreference` |
 * | 恢复默认按钮 + 范围说明（:1058-1082） | `material.general.reset` | `basic.Button` |
 * | 深色更暗 / 独立设置深色档（:1093-1125） | `material.general.darkBoost` / `.darkIndependent` | `MiuixSwitchPreference` |
 * | 深色档八根旋钮（:1130-1139） | `material.general.darkTuning.*` | `MiuixSliderPreference` |
 * | `HyperosSwitchTile(玻璃坞)`（:1148-1157） | `material.general.scopeDock` | `MiuixSwitchPreference` |
 * | 各表面当前材质地图（:1168-1191） | `material.general.surfaces` | 只读行（无官方对应物，`BasicComponent` 只展示） |
 *
 * ## 两条容易写反的地方
 *
 * 1. 「高级材质」整块（含档位滑杆、八根旋钮、深色档、坞开关）只在**显示出来的
 *    那一档是液态玻璃**时出现（:1019）；总闸在实体档时整块不渲染。
 * 2. 「独立设置深色档」开关的**语义是「独立」**，而字段存的是「是否跟随」，
 *    所以取值要**取反**（:1106-1109）。
 */
object SettingsMaterialGeneralPage {

    const val ID = "settings-material-general"

    /** 翻页胶囊本身就是标题（:2332）。 */
    val TITLE = SettingsStrings.generalSettingsTitle

    fun spec(
        state: SettingsPageState,
        material: MaterialPanelState = MaterialPanelState(),
    ): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()
        val tuning = material.liquidGlassTuning
        val displayed = SettingsMaterialModel.glassModeChoice(material)

        // ── 总闸：默认材质两档（:965-993）
        nodes += SettingsLabel(
            id = "material.general.glassMode.label",
            textKey = SettingsStringsExt1.frostedGlassModeLabel.key,
            text = SettingsStringsExt1.frostedGlassModeLabel.zh,
        )
        nodes += SettingsGroup(
            id = "material.general.glassMode",
            children = listOf(
                settingsRow(
                    id = "material.general.glassMode.row",
                    component = MiuixRowComponent.RADIO,
                    title = SettingsStringsExt1.frostedGlassModeLabel,
                    options = GlassModeChoice.entries.map { option(it.value, it.label) },
                    selectedOptionId = displayed.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )
        // 只在实体档出现：这是唯一与直觉不符的档（顺带关掉全 App 模糊，:984-993）
        if (displayed == GlassModeChoice.SOLID) {
            nodes += SettingsDescription(
                id = "material.general.glassMode.notice",
                textKey = SettingsStringsExt1.frostedGlassModeSolidNotice.key,
                text = SettingsStringsExt1.frostedGlassModeSolidNotice.zh,
            )
        }

        // ── 首页顶栏玻璃三档（:995-1017）
        nodes += SettingsGap("material.general.gap.homeBand")
        nodes += SettingsLabel(
            id = "material.general.homeBand.label",
            textKey = SettingsStringsExt1.homeBandGlassMaterialLabel.key,
            text = SettingsStringsExt1.homeBandGlassMaterialLabel.zh,
        )
        nodes += SettingsGroup(
            id = "material.general.homeBand",
            children = listOf(
                settingsRow(
                    id = "material.general.homeBand.row",
                    component = MiuixRowComponent.RADIO,
                    title = SettingsStringsExt1.homeBandGlassMaterialLabel,
                    options = homeBandOptions(),
                    selectedOptionId = material.homeBandGlassMaterial,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // ── 高级材质整块只在液态档出现（:1019-1160）
        if (displayed == GlassModeChoice.LIQUID_GLASS) {
            nodes += advancedNodes(material, tuning)
        }

        // ── 各表面当前材质地图（:1162-1191）：**不在条件里**，实体档照样显示。
        //    只列可调表面：锁死的（弹窗家族、子页顶栏）一律不显示——固定的东西
        //    不出现，用户就不会以为它可调（:1164-1167）。
        nodes += SettingsGap("material.general.gap.surfaces")
        nodes += SettingsLabel(
            id = "material.general.surfaces.label",
            textKey = SettingsStringsExt1.surfaceMaterialSectionTitle.key,
            text = SettingsStringsExt1.surfaceMaterialSectionTitle.zh,
        )
        nodes += SettingsGroup(
            id = "material.general.surfaces",
            children = surfaceRows(material),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = TITLE.key,
            title = TITLE.zh,
            nodes = nodes,
        )
    }

    /** 「高级材质」整块：档位滑杆 + 八根旋钮 + 恢复默认 + 两个开关 + 深色档旋钮 + 坞开关。 */
    private fun advancedNodes(
        material: MaterialPanelState,
        tuning: LiquidGlassTuning,
    ): List<SettingsNode> {
        val nodes = mutableListOf<SettingsNode>()
        nodes += SettingsGap("material.general.gap.advanced")
        nodes += SettingsLabel(
            id = "material.general.advanced.label",
            textKey = SettingsStringsExt1.advancedMaterialTitle.key,
            text = SettingsStringsExt1.advancedMaterialTitle.zh,
        )

        // 档位：一根 10 格节点滑杆，读数只给数字（:1410-1449）
        nodes += SettingsGroup(
            id = "material.general.presetGroup",
            children = listOf(
                settingsRow(
                    id = "material.general.preset",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStringsExt1.liquidGlassPresetLabel,
                    value = presetStepLabel(material, tuning, material.liquidGlassPreset),
                    slider = SettingsSliderSpec(
                        min = 1.0,
                        max = LiquidGlassTuning.PRESET_STEPS.toDouble(),
                        divisions = LiquidGlassTuning.PRESET_STEPS - 1,
                        defaultValue = 7.0,
                        // Dart :1441-1444：轨道上把 10 格全画成节点（滑到附近被吸附），
                        // 读数仍只给数字 —— 节点由官方 SliderPreference 自己画。
                        showKeyPoints = true,
                        keyPoints = (1..LiquidGlassTuning.PRESET_STEPS).map { it.toDouble() },
                    ),
                    sliderValue = SettingsMaterialModel
                        .presetStep(material, tuning, material.liquidGlassPreset)
                        .toDouble(),
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 八根旋钮：**一直显示**，动任何一根就把档位打成「自定义」（:1047-1052）
        nodes += SettingsGap("material.general.gap.tuning")
        nodes += SettingsGroup(
            id = "material.general.tuning",
            children = tuningRows(
                idPrefix = "material.general.tuning",
                tuning = tuning,
                blurSigmaMax = LiquidGlassTuning.MAX_BLUR_SIGMA,
            ),
        )

        // 恢复默认 + 一句范围说明（:1053-1085）
        nodes += SettingsGap("material.general.gap.reset")
        nodes += SettingsGroup(
            id = "material.general.resetGroup",
            children = listOf(
                settingsRow(
                    id = "material.general.reset",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt1.liquidGlassResetAction,
                    action = SettingsAction.RESET_SCOPE,
                    // 只恢复液态玻璃的调参，不动整体材质（:1072-1082）
                    actionTarget = RESET_SCOPE_LIQUID_GLASS,
                ),
            ),
        )
        nodes += SettingsDescription(
            id = "material.general.reset.notice",
            textKey = SettingsStringsExt1.liquidGlassResetScopeNotice.key,
            text = SettingsStringsExt1.liquidGlassResetScopeNotice.zh,
        )

        // 浅 / 深成对的两个开关（:1088-1125）：都在**恒常**区，不进自定义门内
        nodes += SettingsGap("material.general.gap.darkSwitches")
        nodes += SettingsGroup(
            id = "material.general.darkSwitches",
            children = listOf(
                settingsRow(
                    id = "material.general.darkBoost",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt1.liquidGlassDarkBoostLabel,
                    subtitle = SettingsStringsExt1.liquidGlassDarkBoostSubtitle,
                    switchValue = material.darkGlassBoostEnabled,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "material.general.darkIndependent",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt1.liquidGlassDarkIndependentLabel,
                    subtitle = SettingsStringsExt1.liquidGlassDarkIndependentSubtitle,
                    // 开关语义是「独立」，字段存的是「是否跟随」→ 取反（:1106-1109）
                    switchValue = !material.linkLiquidGlassTuning,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 深色档八根旋钮：与浅色档同构，深浅开关一开就显示（:1130-1139）
        if (!material.linkLiquidGlassTuning) {
            nodes += SettingsGap("material.general.gap.darkTuning")
            nodes += SettingsGroup(
                id = "material.general.darkTuning",
                children = tuningRows(
                    idPrefix = "material.general.darkTuning",
                    tuning = material.liquidGlassTuningDark ?: tuning,
                    blurSigmaMax = LiquidGlassTuning.MAX_BLUR_SIGMA,
                ),
            )
        }

        // 作用范围 → 玻璃坞（:1141-1159）
        nodes += SettingsGap("material.general.gap.scopeDock")
        nodes += SettingsGroup(
            id = "material.general.scopeDockGroup",
            children = listOf(
                settingsRow(
                    id = "material.general.scopeDock",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt1.liquidGlassScopeDockTitle,
                    subtitle = SettingsStringsExt1.liquidGlassScopeDockSubtitle,
                    switchValue = material.liquidGlassDockEnabled,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )
        return nodes
    }

    /** 首页顶栏玻璃的三档（:1008-1012）。 */
    fun homeBandOptions(): List<SettingsOption> = listOf(
        option(SettingsMaterialModel.HOME_BAND_FOLLOW, SettingsStringsExt1.homeBandGlassMaterialFollow),
        // 复用「实体」「液态玻璃」这两个既有选项名（同物同名）
        option(SettingsMaterialModel.HOME_BAND_SOLID, SettingsStringsExt1.materialStateSolid),
        option(SettingsMaterialModel.HOME_BAND_LIQUID, SettingsStringsExt1.frostedGlassModeLiquid),
    )

    /**
     * 液态玻璃的八根滑杆（:1471-1577）。**浅色档 / 深色档 / 卡片档共用这一份**
     * ——三套各写一遍迟早会漂，而「同一材质两种观感」正是这个仓库反复吃亏的那类病。
     *
     * [blurSigmaMax] 是按档走的**上限**：全局 / 深色是 0~40（那些面走实时模糊），
     * 卡片是 0~24（磨砂量只喂那张预糊位图）。不收的话卡片那根两头都是死区。
     *
     * 滑杆一律关掉「点标题弹数字输入框」（`tapToEdit: false`）：那会开出二级弹层，
     * 而本面板是根覆盖层自插条目，嵌套弹层会被压在背面（:1454-1455）。
     *
     * [showRecommendedKeyPoints] 只有**卡片档**传 true：那四根旋钮在轨道上画「建议点位」
     * （= 出厂值那一点；画点、划过变亮、经过一次触感，:1457-1459）。点位值取自
     * `CourseGlassTuning.defaultRefraction` 等四个常量，而在 Dart 里那四个**全部**引用全局
     * 标准档（`course_glass_tuning.dart:45-71`），所以这里直接用他们那组
     * `LiquidGlassTuning.DEFAULT_*`，不再抄一份数——两套类型各自的染色语义不同，但点数同源。
     */
    fun tuningRows(
        idPrefix: String,
        tuning: LiquidGlassTuning,
        blurSigmaMax: Double,
        showRecommendedKeyPoints: Boolean = false,
    ): List<SettingsNode> {
        // 存量值可能高于本档上限（旧版卡片那根能拖到 40）：拇指与数字都夹到上限
        val blurSigma = LiquidGlassTuning.clampBlur(tuning.blurSigma, blurSigmaMax)
        // 建议点位只给四根旋钮（Dart :1492-1495 / :1506-1509 / :1521-1524 / :1571-1574）；
        // 其余四根 Dart 传 `keyPoints: null`，轨道上不画点。
        fun keyPointOf(defaultValue: Double): List<Double>? =
            if (showRecommendedKeyPoints) listOf(defaultValue) else null
        return listOf(
            tuningRow(
                id = "$idPrefix.refraction",
                title = SettingsStringsExt1.liquidGlassRefractionLabel,
                value = tuning.refraction,
                min = LiquidGlassTuning.MIN_REFRACTION,
                max = LiquidGlassTuning.MAX_REFRACTION,
                divisions = 40,
                // 读数一位小数（:1491）
                label = format(tuning.refraction, 1),
                // 建议点位 = 出厂折射强度（:1492-1495）
                keyPoints = keyPointOf(LiquidGlassTuning.DEFAULT_REFRACTION),
            ),
            tuningRow(
                id = "$idPrefix.refractionBand",
                title = SettingsStringsExt1.liquidGlassRefractionBandLabel,
                value = tuning.refractionBand,
                min = LiquidGlassTuning.MIN_REFRACTION_BAND,
                max = LiquidGlassTuning.MAX_REFRACTION_BAND,
                divisions = 46,
                label = format(tuning.refractionBand, 1),
                // 建议点位 = 出厂作用带宽度（:1506-1509）
                keyPoints = keyPointOf(LiquidGlassTuning.DEFAULT_REFRACTION_BAND),
            ),
            tuningRow(
                id = "$idPrefix.edgePow",
                title = SettingsStringsExt1.liquidGlassRefractionEdgePowLabel,
                value = tuning.refractionEdgePow,
                min = LiquidGlassTuning.MIN_REFRACTION_EDGE_POW,
                max = LiquidGlassTuning.MAX_REFRACTION_EDGE_POW,
                divisions = 20,
                // 陡缓两位小数（:1520）
                label = format(tuning.refractionEdgePow, 2),
                // 建议点位 = 出厂边缘陡缓（:1521-1524）
                keyPoints = keyPointOf(LiquidGlassTuning.DEFAULT_REFRACTION_EDGE_POW),
            ),
            tuningRow(
                id = "$idPrefix.dispersion",
                title = SettingsStringsExt1.liquidGlassDispersionLabel,
                value = tuning.dispersion,
                min = LiquidGlassTuning.MIN_DISPERSION,
                max = LiquidGlassTuning.MAX_DISPERSION,
                divisions = 20,
                label = percent(tuning.dispersion),
            ),
            tuningRow(
                id = "$idPrefix.rimStrength",
                title = SettingsStringsExt1.liquidGlassRimStrengthLabel,
                value = tuning.rimStrength,
                min = LiquidGlassTuning.MIN_RIM_STRENGTH,
                max = LiquidGlassTuning.MAX_RIM_STRENGTH,
                divisions = 20,
                label = percent(tuning.rimStrength),
            ),
            tuningRow(
                id = "$idPrefix.rimWidth",
                title = SettingsStringsExt1.liquidGlassRimWidthLabel,
                value = tuning.rimWidth,
                min = LiquidGlassTuning.MIN_RIM_WIDTH,
                max = LiquidGlassTuning.MAX_RIM_WIDTH,
                // 步长 0.1（3 / 30）：细线口径的取值都在 0.6~1.1 之间，
                // 步长 0.5 会连默认值 0.8 都落不到格点上（:1549-1551）
                divisions = 30,
                label = format(tuning.rimWidth, 1),
            ),
            tuningRow(
                id = "$idPrefix.blurSigma",
                title = SettingsStringsExt1.liquidGlassBlurSigmaLabel,
                value = blurSigma,
                min = LiquidGlassTuning.MIN_BLUR_SIGMA,
                max = blurSigmaMax,
                // 每格 1：两条量程（0~40 / 0~24）都按 1 递增，档数跟着上限走，
                // 别写死 40（:1560-1561）
                divisions = blurSigmaMax.roundToInt(),
                label = format(blurSigma, 0),
            ),
            tuningRow(
                id = "$idPrefix.tint",
                title = SettingsStringsExt1.liquidGlassTintLabel,
                value = tuning.tintAlpha,
                min = LiquidGlassTuning.MIN_TINT_ALPHA,
                max = LiquidGlassTuning.MAX_TINT_ALPHA,
                // 染色 20 档（步长 0.05）：10 格预设的染色全都落在它上面（:1461-1465）
                divisions = 20,
                label = percent(tuning.tintAlpha),
                // 建议点位 = 出厂染色强度（:1571-1574）
                keyPoints = keyPointOf(LiquidGlassTuning.DEFAULT_TINT_ALPHA),
            ),
        )
    }

    private fun tuningRow(
        id: String,
        title: ArbText,
        value: Double,
        min: Double,
        max: Double,
        divisions: Int,
        label: String,
        keyPoints: List<Double>? = null,
    ) = settingsRow(
        id = id,
        component = MiuixRowComponent.SLIDER,
        title = title,
        value = label,
        slider = SettingsSliderSpec(
            min = min,
            max = max,
            divisions = divisions,
            defaultValue = value,
            // 建议点位原样交给官方 `SliderPreference`：它自己画刻点并按
            // `magnetThreshold` 吸附（Dart `HyperosSliderTile.showKeyPoints/keyPoints`）。
            showKeyPoints = keyPoints != null,
            keyPoints = keyPoints,
        ),
        sliderValue = value,
        action = SettingsAction.WRITE_SETTING,
    )

    /**
     * 「各表面当前材质」三行只读（:1173-1191）。
     *
     * 左表面名 + 右材质值；**没有动作**（`action = null`），渲染层不画箭头。
     * 不用 `HyperosListTile` 的理由见 :1319-1322：它的 details 只在可点行渲染，
     * 纯展示行会把标题打到 45% 透明度且不画值。
     */
    fun surfaceRows(material: MaterialPanelState): List<SettingsNode> = listOf(
        surfaceRow(
            id = "material.general.surface.homeBand",
            title = SettingsStringsExt1.liquidGlassScopeHomeChromeTitle,
            value = SettingsMaterialModel.homeBandSurfaceMaterial(material),
        ),
        surfaceRow(
            id = "material.general.surface.dock",
            title = SettingsStringsExt1.liquidGlassScopeDockTitle,
            value = SettingsMaterialModel.dockSurfaceMaterial(material),
        ),
        surfaceRow(
            id = "material.general.surface.courseCard",
            title = SettingsStringsExt1.surfaceCourseCard,
            value = SettingsMaterialModel.courseCardSurfaceMaterial(material),
        ),
    )

    private fun surfaceRow(id: String, title: ArbText, value: SurfaceMaterialState) = settingsRow(
        id = id,
        component = MiuixRowComponent.ARROW,
        title = title,
        // 材质名来自 ARB（同物同名：磨砂报的就是「高斯模糊」那一档的名字）。
        // 静态行尾文案走 `details`，渲染层取 `details ?: value`
        details = value.label,
        // 只读：不给动作，渲染层自然不画箭头、也不可点
        action = null,
    )

    /** 档位滑杆读数（:1430 `(preset.step ?? nearest.step) ?? 1`），只给数字。 */
    fun presetStepLabel(
        material: MaterialPanelState,
        tuning: LiquidGlassTuning,
        preset: String,
    ): String = SettingsMaterialModel.presetStep(material, tuning, preset).toString()

    /** `LiquidGlassPreset.std` 恢复作用域（`settings_reset.dart` 的课表页面作用域之外的那颗按钮）。 */
    const val RESET_SCOPE_LIQUID_GLASS = "liquidGlass"

    /** Dart `toStringAsFixed(digits)` 的等价物（Locale 无关）。 */
    private fun format(value: Double, digits: Int): String =
        String.format(Locale.ROOT, "%.${digits}f", value)

    /** `_tuningPct`（:1388）：`(value * 100).round()` 加百分号。 */
    private fun percent(value: Double): String = "${(value * 100).roundToInt()}%"
}

/**
 * 材质面板「课程卡片」页（`settings_appearance_editor.dart:1197-1317` 的
 * `_buildCourseCardMaterialPage`）。
 *
 * ## 与「通用」页的关系
 *
 * 卡片是小格，弹窗 / 顶栏 / 玻璃坞是别的东西——所以从 2026-09-20 起它是**与全局
 * 材质分开**的一档：这一档写 `courseCardSurfaceStyle`，渲染门控与墨色规则一律走
 * `effectiveCourseCardSurfaceStyle`（没有壁纸、或模糊总开关关掉时回落实体卡面）。
 *
 * ## ⚠️ 整机总闸会盖过这一页
 *
 * `effectiveCourseCardSurfaceStyle` 在模糊总开关关掉（= 整体材质「实体卡片」）时
 * 一律回落实体卡片——这里选了液态也不生效。总闸在第一页，用户站在这一页看不到它，
 * 所以这一页必须把那句话说出来（:1211-1214，用户 2026-09-22 口径：「第二页加一行提示」）。
 *
 * ## 逐项对照
 *
 * | Flutter（行号） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSectionLabel(卡片外观)`（:1242） | `material.courseCard.surfaceStyle.label` | preference category |
 * | `_MaterialChoiceChips<CourseCardSurfaceStyle>`（:1244-1253） | `material.courseCard.surfaceStyle` | `extra.SuperRadioButton`（内联胶囊） |
 * | 总闸提示（:1254-1262） | `SettingsDescription` | 整宽脚注 |
 * | 档位滑杆（:1274-1290） | `material.courseCard.preset` | `MiuixSliderPreference` |
 * | 八根旋钮（:1294-1312） | `material.courseCard.tuning.*` | `MiuixSliderPreference` |
 */
object SettingsMaterialCourseCardPage {

    const val ID = "settings-material-course-card"

    /** 翻页胶囊本身就是标题（:2332）。 */
    val TITLE = SettingsStringsExt1.surfaceCourseCard

    fun spec(
        state: SettingsPageState,
        material: MaterialPanelState = MaterialPanelState(),
    ): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()
        // 卡片那份参数的真源在 state 上（共享件已有字段），材质面板输入只补别的
        val card = material.copy(courseCardSurfaceStyle = state.courseCardSurfaceStyle)
        val tuning = card.courseCardGlassTuning

        // ── 卡片外观三档（:1240-1253）
        nodes += SettingsLabel(
            id = "material.courseCard.surfaceStyle.label",
            textKey = SettingsStrings.courseCardSurfaceStyleLabel.key,
            text = SettingsStrings.courseCardSurfaceStyleLabel.zh,
        )
        nodes += SettingsGroup(
            id = "material.courseCard.surfaceStyle",
            children = listOf(
                settingsRow(
                    id = "material.courseCard.surfaceStyle.row",
                    component = MiuixRowComponent.RADIO,
                    title = SettingsStrings.courseCardSurfaceStyleLabel,
                    options = CourseCardSurfaceStyle.entries.map { option(it.value, it.label) },
                    selectedOptionId = card.courseCardSurfaceStyle.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )
        // 只在这一档**确实被总闸压住**时提示（:1221-1262）
        if (SettingsMaterialModel.courseCardMaskedByMaster(card)) {
            nodes += SettingsDescription(
                id = "material.courseCard.masterOffHint",
                textKey = SettingsStringsExt1.courseCardMaterialMasterOffHint.key,
                text = SettingsStringsExt1.courseCardMaterialMasterOffHint.zh,
            )
        }

        // ── 旋钮只在卡片档为液态时出现（实体 / 高斯档没有折射可调，:1263-1313）
        if (card.courseCardSurfaceStyle == CourseCardSurfaceStyle.LIQUID_GLASS) {
            nodes += SettingsGap("material.courseCard.gap.advanced")
            nodes += SettingsLabel(
                id = "material.courseCard.advanced.label",
                textKey = SettingsStringsExt1.advancedMaterialTitle.key,
                text = SettingsStringsExt1.advancedMaterialTitle.zh,
            )
            // 档位滑杆：与通用页同一枚部件、同一份枚举、同一套分格（:1263-1266）
            nodes += SettingsGroup(
                id = "material.courseCard.presetGroup",
                children = listOf(
                    settingsRow(
                        id = "material.courseCard.preset",
                        component = MiuixRowComponent.SLIDER,
                        title = SettingsStringsExt1.liquidGlassPresetLabel,
                        value = SettingsMaterialGeneralPage.presetStepLabel(
                            card,
                            tuning,
                            card.courseCardGlassPreset,
                        ),
                        slider = SettingsSliderSpec(
                            min = 1.0,
                            max = LiquidGlassTuning.PRESET_STEPS.toDouble(),
                            divisions = LiquidGlassTuning.PRESET_STEPS - 1,
                            defaultValue = 7.0,
                            // 与第一页**同一个部件、同一套分格**（:1263-1266 / :1423-1449）：
                            // 两页既然共用一套档位预设，节点也必须一模一样，否则同一格拖出来
                            // 的值不同。
                            showKeyPoints = true,
                            keyPoints = (1..LiquidGlassTuning.PRESET_STEPS).map { it.toDouble() },
                        ),
                        sliderValue = SettingsMaterialModel
                            .presetStep(card, tuning, card.courseCardGlassPreset)
                            .toDouble(),
                        action = SettingsAction.WRITE_SETTING,
                    ),
                ),
            )
            nodes += SettingsGap("material.courseCard.gap.tuning")
            nodes += SettingsGroup(
                id = "material.courseCard.tuning",
                children = SettingsMaterialGeneralPage.tuningRows(
                    idPrefix = "material.courseCard.tuning",
                    tuning = tuning,
                    // 卡片的磨砂量只喂它那张预糊位图，出图侧夹到 kPreblurMaxSigma：
                    // 滑杆上限取同一个常量，0 是有效的「清」档（:1299-1302）
                    blurSigmaMax = LiquidGlassTuning.PREBLUR_MAX_SIGMA,
                    // 卡片档四根旋钮画建议点位（:1298 的 `showKeyPoints: true`）
                    showRecommendedKeyPoints = true,
                ),
            )
        }

        return SettingsPageSpec(
            id = ID,
            titleKey = TITLE.key,
            title = TITLE.zh,
            nodes = nodes,
        )
    }
}
