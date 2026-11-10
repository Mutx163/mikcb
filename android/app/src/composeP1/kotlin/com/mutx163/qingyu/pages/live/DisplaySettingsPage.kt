package com.mutx163.qingyu.pages.live

import android.animation.ValueAnimator
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuColorChipSize
import com.mutx163.qingyu.components.QingyuColorChips
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSliderPreference
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.glass.GlassDockSpecular
import com.mutx163.qingyu.components.glass.QingyuGlassSurface
import com.mutx163.qingyu.components.glass.glassRimAlpha
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.GlassSpec
import com.mutx163.qingyu.core.GlassSpecResolver
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.dockGlassTuning
import com.mutx163.qingyu.theme.QingyuShapes
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Sort
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import kotlin.math.roundToInt

/** 图片选择目标（供宿主接线层落到各自目录 / 前缀）。 */
enum class LiveImagePickTarget { LABEL_LOGO, EXPANDED_ICON }

/**
 * 「超级岛 · 显示设置页」· Compose 渲染层（重建 Flutter `LiveDisplaySettingsScreen`）。
 *
 * 页面按发布版顺序铺开：**超级岛实时预览（标题正下方）** → 显示内容（6 开关）/
 * 倒计时格式 / 上课前快捷操作 / 小米岛左侧标签全套 / 展开态图标 /
 * 展开详情（显隐 + 拖动排序 + 恢复默认）；`forDuringEnd` 两个变体（课中/下课页多一组
 * 「配置方式 · 跟随上课前提醒设置」，且不显示上课前快捷操作）。
 *
 * 「试弹上课前岛」在顶栏右上（2026-11-10 用户拍板从底部浮钮上移），首屏可见、随时可点；
 * 预览卡本身用当前草稿实时渲染（开关一拨就跟着变），不截图、不烤位图。
 *
 * 本层不碰平台：选图、落库、速览起岛全部由宿主回调注入。文案一律取
 * [DisplaySettingsStrings]（与 `lib/l10n/app_zh.arb` 逐字一致），页面不自造第二套组件
 * （统一用 [QingyuPageScaffold] / [QingyuCard] / miuix preference）。
 */
@Composable
fun DisplaySettingsPage(
    state: LiveDisplayState,
    onStateChange: (LiveDisplayState) -> Unit,
    onBack: () -> Unit,
    forDuringEnd: Boolean = false,
    /**
     * 真实当前（或下一节）课程。**默认 null = 诚实空态**：
     * 不再用演示数据兜底，没有真实课程就不画岛卡。
     */
    previewInfo: LiveIslandPreviewInfo? = null,
    /** 空态副句（例如「请先在课表设置里填写开学日期」）；null = 只画主句。 */
    previewEmptyHint: String? = null,
    onPickImage: (LiveImagePickTarget) -> String? = { null },
    onOpenDoNotDisturbAccess: () -> Unit = {},
    onStagePreviewStart: () -> Unit = {},
    onStagePreviewStop: () -> Unit = {},
    stagePreviewActive: Boolean = false,
    stagePreviewBusy: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    val followBeforeClass = forDuringEnd && state.duringEndFollowBeforeClass
    val editable = !followBeforeClass
    val sectionAlpha = if (editable) 1f else 0.5f
    val title = if (forDuringEnd) {
        DisplaySettingsStrings.displayEntryTitleDuringEnd.text
    } else {
        DisplaySettingsStrings.displayEntryTitleBeforeClass.text
    }
    val effectiveInfo = previewInfo?.copy(
        promoteDuringClass = state.promoteDuringClass,
        endSecondsCountdownThresholdSeconds = state.endSecondsCountdownThreshold,
    )

    // ── 速览 FAB 的玻璃采样源（2026-11-08 用户口径：这颗钮要“和首页导航栏一样的材质”）──
    //
    // 采的是**列表这一层**，不用骨架的 `LocalQingyuPageBackdrop`：那层把 FAB 自己也录进去
    // （miuix 是“先录后采”，玻璃会一点点把自己上一帧糊进底座），而这里 FAB 是列表的兄弟节点，
    // 只采它底下的卡片与页底色。`drawRect(pageBackground)` 不能省——`layerBackdrop` 只录
    // 自己这一层、不含 Scaffold 底色，透明区进了模糊会扩成色块。
    val pageBackground = Color(QingyuTheme.scaffoldBackground(dark))
    val fabGlassEnabled = isRuntimeShaderSupported() && ValueAnimator.areAnimatorsEnabled()
    val fabBackdrop = if (fabGlassEnabled) {
        rememberLayerBackdrop {
            drawRect(pageBackground)
            drawContent()
        }
    } else {
        null
    }

    // 顶栏保持原样（只有返回箭头）：2026-11-10 用户否掉「试弹」放右上角。
    // 试弹仍走底部浮钮；标题下方那一条是实时预览，两者分工：上面看、下面试。
    QingyuPageScaffold(title = title, onBack = onBack) {
        // 骨架照 `docs/reference/compose-page-style-rules.md` §三：滚动容器走共享套件
        //（官方三件套 + 右侧滚动条）。Box 保留：速览 FAB 要贴在底部居中。
        // innerPadding 由外层 Box 吃掉，所以列表这里传 0，避免顶/底留白叠加两次。
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                // 玻璃采样层挂在列表自己这一层：录的就是“FAB 底下那片卡片 + 页底色”。
                modifier = if (fabBackdrop != null) Modifier.layerBackdrop(fabBackdrop) else Modifier,
                scrollBehavior = scrollBehavior,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 104.dp),
            ) {
                // ── 0. 超级岛实时预览（标题正下方、首组之前，对齐发布版顶部形态）──
                //
                // 发布版 `live_settings_subpages.dart:1136-1137` 在列表最前放
                // `HyperosSectionLabel(liveIslandPreviewTitle)` + `LiveIslandPreviewCard`；
                // 卡片直接用当前草稿渲染（课程名/简称/地点/倒计时…拨一下就跟变）。
                // 这里复用同一颗真实岛组件，不截图、不烤位图；没有真实课程时画诚实空态。
                // 「展开态预览」仍是页尾一块（发布版 :1092-1093 也在展开详情之后），不放这里。
                item(key = "island-preview-label") { QingyuSectionTitle(DisplaySettingsStrings.islandPreviewTitle.text) }
                if (effectiveInfo == null) {
                    item(key = "island-preview-empty") {
                        IslandPreviewEmptyCard(
                            hint = previewEmptyHint,
                            dark = dark,
                            modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                        )
                    }
                } else {
                    item(key = "island-preview-card") {
                        LiveIslandPreviewCard(
                            state = state,
                            previewInfo = effectiveInfo,
                            modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                            forDuringEnd = forDuringEnd,
                            followBeforeClass = followBeforeClass,
                        )
                    }
                }

                // ── 课中/下课页顶部：配置方式（跟随上课前设置）──
                if (forDuringEnd) {
                    item(key = "config-mode-label") { QingyuSectionTitle(DisplaySettingsStrings.displayConfigModeTitle.text) }
                    item(key = "config-mode-card") {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin),
                        ) {
                            SwitchPreference(
                                checked = state.duringEndFollowBeforeClass,
                                onCheckedChange = { onStateChange(state.withDuringEndFollowBeforeClass(it)) },
                                title = DisplaySettingsStrings.followBeforeClassDisplayTitle.text,
                            )
                        }
                    }
                }

                // ── 1. 显示内容（6 开关）──
                item(key = "display-content-label") { QingyuSectionTitle(DisplaySettingsStrings.displayContentTitle.text) }
                item(key = "display-content-card") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin)
                            .alpha(sectionAlpha),
                    ) {
                        SwitchPreference(
                            checked = state.showCourseName,
                            onCheckedChange = { onStateChange(state.withShowCourseName(it)) },
                            title = DisplaySettingsStrings.showCourseNameTitle.text,
                            summary = if (LiveDisplayLogic.showCourseNameDuplicatedHint(state)) {
                                DisplaySettingsStrings.courseNameDuplicatedHint.text
                            } else null,
                            enabled = editable,
                        )
                        SwitchPreference(
                            checked = state.useShortName,
                            onCheckedChange = { onStateChange(state.withUseShortName(it)) },
                            title = DisplaySettingsStrings.preferShortNameTitle.text,
                            summary = DisplaySettingsStrings.preferShortNameSubtitle.text,
                            enabled = editable,
                        )
                        SwitchPreference(
                            checked = state.showLocation,
                            onCheckedChange = { onStateChange(state.withShowLocation(it)) },
                            title = DisplaySettingsStrings.showLocationTitle.text,
                            summary = if (LiveDisplayLogic.showLocationDuplicatedHint(state)) {
                                DisplaySettingsStrings.locationDuplicatedHint.text
                            } else null,
                            enabled = editable,
                        )
                        SwitchPreference(
                            checked = state.showCountdown,
                            onCheckedChange = { onStateChange(state.withShowCountdown(it)) },
                            title = DisplaySettingsStrings.showCountdownTitle.text,
                            enabled = editable,
                        )
                        Box(modifier = Modifier.alpha(if (LiveDisplayLogic.shouldDimStageText(state)) 0.55f else 1f)) {
                            SwitchPreference(
                                checked = state.showStageText,
                                onCheckedChange = { onStateChange(state.withShowStageText(it)) },
                                title = DisplaySettingsStrings.showStageTextTitle.text,
                                summary = if (state.showCountdown) DisplaySettingsStrings.showStageTextInactiveHint.text else null,
                                enabled = editable,
                            )
                        }
                        Box(modifier = Modifier.alpha(if (LiveDisplayLogic.shouldDimHidePrefix(state)) 0.55f else 1f)) {
                            SwitchPreference(
                                checked = state.hidePrefixText,
                                onCheckedChange = { onStateChange(state.withHidePrefixText(it)) },
                                title = DisplaySettingsStrings.hidePrefixTextTitle.text,
                                summary = if (!state.showCountdown) DisplaySettingsStrings.hidePrefixTextInactiveHint.text else null,
                                enabled = editable,
                            )
                        }
                    }
                }

                // ── 2. 倒计时格式 ──
                if (state.showCountdown) {
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            EnumDropdown(
                                title = DisplaySettingsStrings.countdownFormatLabel.text,
                                values = LiveCountdownTextStyle.entries,
                                selected = state.countdownTextStyle,
                                label = { DisplaySettingsStrings.countdownTextStyleLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withCountdownTextStyle(it)) },
                            )
                        }
                    }
                }

                // ── 3. 上课前快捷操作（仅上课前提醒页）──
                if (!forDuringEnd) {
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            EnumDropdown(
                                title = DisplaySettingsStrings.beforeClassQuickActionTitle.text,
                                values = LiveBeforeClassQuickAction.entries,
                                selected = state.beforeClassQuickAction,
                                label = { DisplaySettingsStrings.liveBeforeClassQuickActionLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withBeforeClassQuickAction(it)) },
                            )
                            if (state.beforeClassQuickAction != LiveBeforeClassQuickAction.NONE) {
                                val autoOptions = LiveDisplayLogic.quickActionAutoMinuteOptions()
                                OverlayDropdownPreference(
                                    items = autoOptions.map { DisplaySettingsStrings.quickActionAutoMinuteLabel(it) },
                                    selectedIndex = autoOptions.indexOf(state.beforeClassQuickActionAutoMinutes).coerceAtLeast(0),
                                    title = DisplaySettingsStrings.beforeClassQuickActionAutoTitle.text,
                                    enabled = editable,
                                    onSelectedIndexChange = { idx ->
                                        autoOptions.getOrNull(idx)?.let {
                                            onStateChange(state.withBeforeClassQuickActionAutoMinutes(it))
                                        }
                                    },
                                )
                            }
                            if (LiveDisplayLogic.requiresDoNotDisturbAccess(state.beforeClassQuickAction)) {
                                ArrowPreference(
                                    title = LiveKeepAliveStrings.guideStatusDoNotDisturbAccess.text,
                                    summary = LiveKeepAliveStrings.guideStatusDoNotDisturbAccessHint.text,
                                    onClick = onOpenDoNotDisturbAccess,
                                    enabled = editable,
                                )
                            }
                        }
                    }
                }

                // ── 4. 小米岛左侧标签全套 ──
                item(key = "island-visual-label") { QingyuSectionTitle(DisplaySettingsStrings.islandVisualTitle.text) }
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                        SwitchPreference(
                            checked = state.enableMiuiIslandLabelImage,
                            onCheckedChange = { onStateChange(state.withEnableMiuiIslandLabelImage(it)) },
                            title = DisplaySettingsStrings.miuiLabelImageTitle.text,
                            summary = DisplaySettingsStrings.miuiLabelImageSubtitle.text,
                            enabled = editable,
                        )
                    }
                }
                if (state.enableMiuiIslandLabelImage) {
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelContentLabel.text,
                                values = MiuiIslandLabelContent.entries,
                                selected = state.miuiIslandLabelContent,
                                label = { DisplaySettingsStrings.miuiIslandLabelContentLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelContent(it)) },
                            )
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelStyleLabel.text,
                                values = MiuiIslandLabelStyle.entries,
                                selected = state.miuiIslandLabelStyle,
                                label = { DisplaySettingsStrings.miuiIslandLabelStyleLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelStyle(it)) },
                            )
                            // 选图块（仅「图标+文字」样式）
                            if (state.miuiIslandLabelStyle == MiuiIslandLabelStyle.ICON_AND_TEXT) {
                                ImagePickerBlock(
                                    title = DisplaySettingsStrings.miuiLabelLogoTitle.text,
                                    subtitle = null,
                                    path = state.miuiIslandLabelLogoPath,
                                    enabled = editable,
                                    onPick = {
                                        onPickImage(LiveImagePickTarget.LABEL_LOGO)?.let { picked ->
                                            onStateChange(state.withMiuiIslandLabelLogoPath(picked))
                                        }
                                    },
                                    onDelete = { onStateChange(state.withMiuiIslandLabelLogoPath(null)) },
                                )
                            }
                            // 圆角（有 Logo 时）
                            if (state.miuiIslandLabelStyle == MiuiIslandLabelStyle.ICON_AND_TEXT &&
                                state.miuiIslandLabelLogoPath != null
                            ) {
                                LabelSlider(
                                    title = DisplaySettingsStrings.logoCornerRadiusLabel(
                                        state.miuiIslandLabelLogoCornerRadius.toInt().toString(),
                                    ),
                                    value = state.miuiIslandLabelLogoCornerRadius,
                                    range = LiveDisplayLogic.LABEL_LOGO_CORNER_MIN..LiveDisplayLogic.LABEL_LOGO_CORNER_MAX,
                                    divisions = LiveDisplayLogic.LABEL_LOGO_CORNER_DIVISIONS,
                                    enabled = editable,
                                    onChange = { onStateChange(state.withMiuiIslandLabelLogoCornerRadius(it.toDouble())) },
                                )
                            }
                            // 左侧文字颜色：全站统一色板（QingyuColorChips · 40dp 档）。
                            // 旧本地 `_ColorDot` 的 48dp 热区/6dp 间距已由组件配方取代
                            // （2026-11-10 用户拍板：FlowRow 12/12、官方 IconButton、选中 2dp 墨 + 勾）。
                            //
                            // 禁用态：点击交给官方 IconButton 的 `enabled`；明暗由整张卡的
                            // `alpha(sectionAlpha)` 负责一次，所以传 `dimWhenDisabled = false`，
                            // 否则卡片 0.5 × 组件 0.5 会叠成 25%。这与发布版的
                            // `IgnorePointer + AnimatedOpacity(0.5)`（只淡一次）同构。
                            QingyuColorChips(
                                colors = LiveDisplayLogic.LABEL_COLORS,
                                selectedHex = state.miuiIslandLabelFontColor,
                                onSelect = { onStateChange(state.withMiuiIslandLabelFontColor(it)) },
                                enabled = editable,
                                dimWhenDisabled = false,
                                dark = dark,
                                // 色板边长 40dp（[QingyuColorChipSize.Settings]）：本页就是该档位的
                                // 发布版出处（Dart `HyperosHexColorChipGroup` 在显示设置里用 40）。
                                size = QingyuColorChipSize.Settings,
                                modifier = Modifier.padding(
                                    horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                    vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
                                ),
                            )
                        }
                    }
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            // 「文字排版与位置微调」：Flutter 用 HyperosAccordion，Compose 无对位件，
                            // 这里本地包一层：用一行标题 + 直接展开的滑杆/下拉（不折叠）。
                            Text(
                                text = DisplaySettingsStrings.miuiLabelAdvancedAccordionTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = Color(QingyuTheme.primaryText(dark)),
                                modifier = Modifier.padding(
                                    start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                    top = QingyuShapes.ROW_PADDING_VERTICAL.dp,
                                    end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                ),
                            )
                            LabelSlider(
                                title = DisplaySettingsStrings.fontSizeLabel(state.miuiIslandLabelFontSize.toInt().toString()),
                                value = state.miuiIslandLabelFontSize,
                                range = LiveDisplayLogic.LABEL_FONT_SIZE_MIN..LiveDisplayLogic.LABEL_FONT_SIZE_MAX,
                                divisions = LiveDisplayLogic.LABEL_FONT_SIZE_DIVISIONS,
                                enabled = editable,
                                onChange = { onStateChange(state.withMiuiIslandLabelFontSize(it.toDouble())) },
                            )
                            LabelSlider(
                                title = DisplaySettingsStrings.offsetXLabel(formatOneDecimal(state.miuiIslandLabelOffsetX)),
                                value = state.miuiIslandLabelOffsetX,
                                range = LiveDisplayLogic.LABEL_OFFSET_MIN..LiveDisplayLogic.LABEL_OFFSET_MAX,
                                divisions = LiveDisplayLogic.LABEL_OFFSET_DIVISIONS,
                                enabled = editable,
                                onChange = { onStateChange(state.withMiuiIslandLabelOffsetX(it.toDouble())) },
                            )
                            LabelSlider(
                                title = DisplaySettingsStrings.offsetYLabel(formatOneDecimal(state.miuiIslandLabelOffsetY)),
                                value = state.miuiIslandLabelOffsetY,
                                range = LiveDisplayLogic.LABEL_OFFSET_MIN..LiveDisplayLogic.LABEL_OFFSET_MAX,
                                divisions = LiveDisplayLogic.LABEL_OFFSET_DIVISIONS,
                                enabled = editable,
                                onChange = { onStateChange(state.withMiuiIslandLabelOffsetY(it.toDouble())) },
                            )
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelFontWeightLabel.text,
                                values = MiuiIslandLabelFontWeight.entries,
                                selected = state.miuiIslandLabelFontWeight,
                                label = { DisplaySettingsStrings.miuiIslandLabelFontWeightLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelFontWeight(it)) },
                            )
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelRenderQualityLabel.text,
                                values = MiuiIslandLabelRenderQuality.entries,
                                selected = state.miuiIslandLabelRenderQuality,
                                label = { DisplaySettingsStrings.miuiIslandLabelRenderQualityLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelRenderQuality(it)) },
                            )
                        }
                    }
                }

                // ── 5. 展开态图标 ──
                item(key = "expanded-icon-label") { QingyuSectionTitle(DisplaySettingsStrings.expandedIconSectionTitle.text) }
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                        EnumDropdown(
                            title = DisplaySettingsStrings.miuiExpandedIconLabel.text,
                            values = MiuiIslandExpandedIconMode.entries,
                            selected = state.miuiIslandExpandedIconMode,
                            label = { DisplaySettingsStrings.miuiIslandExpandedIconModeLabel(it) },
                            enabled = editable,
                            onSelect = { mode ->
                                val clear = mode != MiuiIslandExpandedIconMode.CUSTOM_IMAGE
                                onStateChange(
                                    state.withMiuiIslandExpandedIconMode(mode)
                                        .let { if (clear) it.withMiuiIslandExpandedIconPath(null) else it },
                                )
                            },
                        )
                        if (state.miuiIslandExpandedIconMode == MiuiIslandExpandedIconMode.CUSTOM_IMAGE) {
                            ImagePickerBlock(
                                title = DisplaySettingsStrings.miuiExpandedIconLabel.text,
                                subtitle = null,
                                path = state.miuiIslandExpandedIconPath,
                                enabled = editable,
                                onPick = {
                                    onPickImage(LiveImagePickTarget.EXPANDED_ICON)?.let { picked ->
                                        onStateChange(
                                            state.withMiuiIslandExpandedIconMode(MiuiIslandExpandedIconMode.CUSTOM_IMAGE)
                                                .withMiuiIslandExpandedIconPath(picked),
                                        )
                                    }
                                },
                                onDelete = { onStateChange(state.withMiuiIslandExpandedIconPath(null)) },
                            )
                        }
                    }
                }

                // ── 6. 展开详情：显隐 + 排序 + 恢复默认 ──
                item(key = "expanded-detail-label") { QingyuSectionTitle(DisplaySettingsStrings.expandedDetailGroupTitle.text) }
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                        ExpandedDetailGroup(
                            state = state,
                            forDuringEnd = forDuringEnd,
                            enabled = editable,
                            dark = dark,
                            onToggle = { field ->
                                onStateChange(
                                    state.withExpandedDetailFields(
                                        LiveDisplayLogic.toggleDetailField(state, field, forDuringEnd),
                                    ),
                                )
                            },
                            onMoveTo = { from, to ->
                                onStateChange(
                                    state.withExpandedDetailFields(
                                        LiveDisplayLogic.reorderDetailField(state, from, to, forDuringEnd),
                                    ),
                                )
                            },
                            onMoveBy = { field, delta ->
                                onStateChange(
                                    state.withExpandedDetailFields(
                                        LiveDisplayLogic.moveDetailFieldBy(state, field, delta, forDuringEnd),
                                    ),
                                )
                            },
                        )
                    }
                }
                if (state.expandedDetailFields != null) {
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            ArrowPreference(
                                title = DisplaySettingsStrings.resetExpandedDetailDefaultAction.text,
                                onClick = { onStateChange(state.withExpandedDetailFields(LiveDisplayLogic.resetDetailFields())) },
                                enabled = editable,
                            )
                        }
                    }
                }

                // ── 7. 展开态预览（发布版 :1092-1093 也排在展开详情 / 恢复默认之后）──
                if (effectiveInfo != null) {
                    item(key = "island-expanded-preview-label") {
                        QingyuSectionTitle(DisplaySettingsStrings.islandExpandedPreviewTitle.text)
                    }
                    item(key = "island-expanded-preview-card") {
                        LiveIslandExpandedPreviewCard(
                            state = state,
                            previewInfo = effectiveInfo,
                            modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                            forDuringEnd = forDuringEnd,
                            followBeforeClass = followBeforeClass,
                        )
                    }
                }
            }

            // ── 试弹：底部浮钮（用户 2026-11-10 恢复原位；顶部只放实时预览）──
            StagePreviewFab(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(start = 24.dp, end = 24.dp, bottom = 16.dp),
                label = if (stagePreviewActive) {
                    DisplaySettingsStrings.stagePreviewStopAction.text
                } else if (forDuringEnd) {
                    DisplaySettingsStrings.stagePreviewDuringClassAction.text
                } else {
                    DisplaySettingsStrings.stagePreviewBeforeClassAction.text
                },
                active = stagePreviewActive,
                busy = stagePreviewBusy,
                dark = dark,
                backdrop = fabBackdrop,
                onClick = if (stagePreviewActive) onStagePreviewStop else onStagePreviewStart,
            )
        }
    }
}

/**
 * 状态化重载：内部 `remember` 持有 [LiveDisplayState]，壳可直接
 * `DisplaySettingsPage(forDuringEnd = true, onBack = { ... })` 挂载。
 */
@Composable
fun DisplaySettingsPage(
    forDuringEnd: Boolean = false,
    onBack: () -> Unit,
    initialState: LiveDisplayState = LiveDisplayState(),
    previewInfo: LiveIslandPreviewInfo? = null,
    previewEmptyHint: String? = null,
    onPickImage: (LiveImagePickTarget) -> String? = { null },
    onOpenDoNotDisturbAccess: () -> Unit = {},
    onStagePreviewStart: () -> Unit = {},
    onStagePreviewStop: () -> Unit = {},
) {
    var state by remember { mutableStateOf(initialState) }
    var previewActive by remember { mutableStateOf(false) }
    var previewBusy by remember { mutableStateOf(false) }
    DisplaySettingsPage(
        state = state,
        onStateChange = { state = it },
        onBack = onBack,
        forDuringEnd = forDuringEnd,
        previewInfo = previewInfo,
        previewEmptyHint = previewEmptyHint,
        onPickImage = onPickImage,
        onOpenDoNotDisturbAccess = onOpenDoNotDisturbAccess,
        onStagePreviewStart = {
            previewBusy = false
            previewActive = true
            onStagePreviewStart()
        },
        onStagePreviewStop = {
            previewActive = false
            onStagePreviewStop()
        },
        stagePreviewActive = previewActive,
        stagePreviewBusy = previewBusy,
    )
}

// ───────────────────────── 子组件 ─────────────────────────

/** 枚举下拉的通用封装：`values` 顺序即下拉项顺序，选中回传给 [onSelect]。 */
@Composable
private fun <T> EnumDropdown(
    title: String,
    values: List<T>,
    selected: T,
    label: (T) -> String,
    enabled: Boolean,
    onSelect: (T) -> Unit,
    summary: String? = null,
) {
    OverlayDropdownPreference(
        items = values.map(label),
        selectedIndex = values.indexOf(selected).coerceAtLeast(0),
        title = title,
        summary = summary,
        enabled = enabled,
        onSelectedIndexChange = { idx -> values.getOrNull(idx)?.let(onSelect) },
    )
}

/**
 * 滑杆行封装（官方 `SliderPreference` 的逐字副本 + 点击跳转，见 `QingyuSliderPreference`）。
 *
 * [divisions] 是 Dart `HyperosSliderTile` 的口径 —— **区间数**（`step = span / divisions`，
 * `lib/ui/hyperos/hyperos_controls.dart:318-338`），而官方 `steps` 是「端点之间的档数」，
 * 少 1（区间数 = steps + 1）。所以这里和 `SettingsPageRenderers.SliderRow` 一样减 1，
 * 否则网格会比 Flutter 版多一格：字号 1..32 会变成 31/32 的步长，读数还是整数、
 * 落盘却是小数。
 */
@Composable
private fun LabelSlider(
    title: String,
    value: Double,
    range: ClosedFloatingPointRange<Double>,
    divisions: Int,
    enabled: Boolean,
    onChange: (Float) -> Unit,
) {
    QingyuSliderPreference(
        value = value.toFloat().coerceIn(range.start.toFloat(), range.endInclusive.toFloat()),
        onValueChange = onChange,
        title = title,
        enabled = enabled,
        valueRange = range.start.toFloat()..range.endInclusive.toFloat(),
        steps = (divisions - 1).coerceAtLeast(0),
    )
}

/** 选图块（对照 Flutter 里的 HyperosButton 组 + `_ImagePreview`）。 */
@Composable
private fun ImagePickerBlock(
    title: String,
    subtitle: String?,
    path: String?,
    enabled: Boolean,
    onPick: () -> Unit,
    onDelete: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
            ),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(text = title, style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM), color = Color(QingyuTheme.primaryText(dark)))
        if (subtitle != null) {
            Text(text = subtitle, style = MiuixTheme.textStyles.footnote1, color = Color(QingyuTheme.secondaryText(dark)))
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TextButton(
                text = if (path == null) DisplaySettingsStrings.selectImageAction.text else DisplaySettingsStrings.replaceImageAction.text,
                onClick = onPick,
                enabled = enabled,
                modifier = Modifier.weight(1f),
            )
            if (path != null) {
                TextButton(
                    text = DisplaySettingsStrings.deleteAction.text,
                    onClick = onDelete,
                    enabled = enabled,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        // 图片预览：这里只显示路径占位（不加载真实位图，避免预览层依赖图片解码）。
        if (path != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .border(1.dp, Color(QingyuTheme.dividerLine(dark)), RoundedCornerShape(12.dp))
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(QingyuTheme.surfaceContainerHighest(dark))),
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = path,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/**
 * 展开详情分组：已显示区可拖动排序 + 开关；已隐藏区只有开关。
 *
 * 形态对齐发布版 `_ExpandedDetailGroup`（`live_settings_subpages.dart:2043-2150`）：
 * 行首是拖动手柄（miuix `Sort` 图标），**不再有可视的上/下移按钮**；拖动即时跟手、
 * 松手落位。读屏用户走行上挂的自定义动作「上移 / 下移」，与发布版同一口径。
 */
@Composable
private fun ExpandedDetailGroup(
    state: LiveDisplayState,
    forDuringEnd: Boolean,
    enabled: Boolean,
    dark: Boolean,
    onToggle: (LiveExpandedDetailField) -> Unit,
    onMoveTo: (from: Int, to: Int) -> Unit,
    onMoveBy: (field: LiveExpandedDetailField, delta: Int) -> Unit,
) {
    val enabledFields = LiveDisplayLogic.resolveDetailWorkOrder(state, forDuringEnd)
    val hiddenFields = LiveDisplayLogic.resolveHiddenDetailFields(state, forDuringEnd)

    var draggingIndex by remember { mutableStateOf(-1) }
    var dragOffset by remember { mutableFloatStateOf(0f) }

    Column(modifier = Modifier.fillMaxWidth()) {
        enabledFields.forEachIndexed { index, field ->
            val dragging = index == draggingIndex
            key(field) {
                DetailRow(
                title = DisplaySettingsStrings.liveExpandedDetailFieldLabel(field),
                checked = true,
                enabled = enabled,
                dark = dark,
                modifier = if (dragging) {
                    Modifier
                        .zIndex(1f)
                        .offset { IntOffset(0, dragOffset.roundToInt()) }
                } else {
                    Modifier
                },
                onToggle = { onToggle(field) },
                onMoveUp = if (index > 0) {
                    { onMoveBy(field, -1) }
                } else {
                    null
                },
                onMoveDown = if (index < enabledFields.lastIndex) {
                    { onMoveBy(field, 1) }
                } else {
                    null
                },
                onDragStart = {
                    if (enabled) {
                        draggingIndex = index
                        dragOffset = 0f
                    }
                },
                onDrag = { delta ->
                    if (draggingIndex == index) dragOffset += delta
                },
                onDragEnd = {
                    if (draggingIndex == index) {
                        val steps = (dragOffset / DetailRowHeight.value).roundToInt()
                        val target = (index + steps).coerceIn(0, enabledFields.lastIndex)
                        draggingIndex = -1
                        dragOffset = 0f
                        if (target != index) onMoveTo(index, target)
                    }
                },
                onDragCancel = {
                    draggingIndex = -1
                    dragOffset = 0f
                },
                )
            }
        }
        if (hiddenFields.isNotEmpty()) {
            Text(
                text = DisplaySettingsStrings.detailHiddenCaption.text,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(
                    start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                    end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                    top = 8.dp,
                    bottom = 4.dp,
                ),
            )
            hiddenFields.forEach { field ->
                SwitchPreference(
                    checked = false,
                    onCheckedChange = { onToggle(field) },
                    title = DisplaySettingsStrings.liveExpandedDetailFieldLabel(field),
                    enabled = enabled,
                )
            }
        }
    }
}

/**
 * 展开详情的一行：`[手柄] 标题 [开关]`。
 *
 * 拖动只从手柄起手（页面纵向滚动、行尾开关都不抢手势）；拖动期间整行跟手位移，
 * 由父层按 [DetailRowHeight] 换算目标位，松手一次落位——没有自写动画。
 */
@Composable
private fun DetailRow(
    title: String,
    checked: Boolean,
    enabled: Boolean,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onToggle: () -> Unit,
    onMoveUp: (() -> Unit)?,
    onMoveDown: (() -> Unit)?,
    onDragStart: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit,
    onDragCancel: () -> Unit,
) {
    val secondary = Color(QingyuTheme.secondaryText(dark))
    val moveUpLabel = DisplaySettingsStrings.detailMoveUpAction.text
    val moveDownLabel = DisplaySettingsStrings.detailMoveDownAction.text
    // 拖动手势协程只在 `enabled` 变化时重启；回调走 latest-state，避免拿到重排前的旧 index。
    val currentDragStart by rememberUpdatedState(onDragStart)
    val currentDrag by rememberUpdatedState(onDrag)
    val currentDragEnd by rememberUpdatedState(onDragEnd)
    val currentDragCancel by rememberUpdatedState(onDragCancel)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(DetailRowHeight)
            .semantics {
                val actions = buildList {
                    if (onMoveUp != null) {
                        add(
                            CustomAccessibilityAction(moveUpLabel) {
                                onMoveUp()
                                true
                            },
                        )
                    }
                    if (onMoveDown != null) {
                        add(
                            CustomAccessibilityAction(moveDownLabel) {
                                onMoveDown()
                                true
                            },
                        )
                    }
                }
                if (actions.isNotEmpty()) customActions = actions
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 拖动手柄格：宽 = 行高（发布版 `SizedBox(width: listRowMinHeight)`）。
        Box(
            modifier = Modifier
                .width(DetailRowHeight)
                .fillMaxHeight()
                .semantics {
                    contentDescription = DisplaySettingsStrings.detailReorderHandleLabel.text
                }
                .pointerInput(enabled) {
                    if (enabled) {
                        detectDragGestures(
                            onDragStart = { currentDragStart() },
                            onDrag = { change, amount ->
                                change.consume()
                                currentDrag(amount.y)
                            },
                            onDragEnd = { currentDragEnd() },
                            onDragCancel = { currentDragCancel() },
                        )
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Sort,
                contentDescription = null,
                tint = secondary,
                modifier = Modifier.size(20.dp),
            )
        }
        Text(
            text = title,
            modifier = Modifier
                .weight(1f)
                .padding(end = 8.dp),
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Switch(
            checked = checked,
            onCheckedChange = { onToggle() },
            enabled = enabled,
            modifier = Modifier.padding(end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        )
    }
}

/** 展开详情单行高度 = 拖动位移换算目标位的步长（与列表行最小高一致）。 */
private val DetailRowHeight: Dp = QingyuShapes.LIST_ROW_MIN_HEIGHT.dp

/** 预览空态：没有真实当前/下一节课时**如实说没有**，不画假课程。 */
@Composable
private fun IslandPreviewEmptyCard(
    hint: String?,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    QingyuCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                    vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
                ),
        ) {
            Text(
                text = DisplaySettingsStrings.islandPreviewEmpty.text,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            if (!hint.isNullOrBlank()) {
                Text(
                    text = hint,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

/**
 * 速览悬浮按钮（对照 Flutter `_LiveStagePreviewFab` 的胶囊玻璃钮）。
 *
 * ## 材质 = 首页导航栏那一档（2026-11-08 用户口径）
 *
 * 原先是“主题面实心 + 1dp 描边”的白胶囊，与底下的列表毫无关系。现在走与玻璃坞**同一条**
 * 渲染管线 [QingyuGlassSurface]（模糊 + 鲜活度 + 折射 + 边光）与**同一组出厂数值**
 *（[StagePreviewFabGlassSpec] = `HomeMaterialRenderSpec.dockGlassTuning()`），染色色也用坞面的
 * `surfaceContainer`，投影同口径（黑、10dp、亮色更淡）——屏幕上是“底栏那颗药丸的短版”。
 *
 * 拿不到采样源（设备不支持 runtime shader / 用户关了动效）时退回原来的实心胶囊：
 * 不对着空气做模糊。
 *
 * @param backdrop 采样源 = **列表那一层**（见页面里 `fabBackdrop` 的注释）；null = 实心回落。
 */
@Composable
private fun StagePreviewFab(
    label: String,
    active: Boolean,
    busy: Boolean,
    dark: Boolean,
    backdrop: LayerBackdrop?,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val ink = if (active) Color(QingyuTheme.error(dark)) else MiuixTheme.colorScheme.primary
    val shape = remember { RoundedCornerShape(StagePreviewFabCornerDp.dp) }
    val surface = MiuixTheme.colorScheme.surfaceContainer
    val shadow = remember(dark) {
        Shadow(
            radius = StagePreviewFabShadowRadiusDp.dp,
            color = Color.Black,
            // 亮色下更淡：深色阴影压在浅色页面上会显出一圈灰边（与底栏同一口径）。
            alpha = if (dark) 0.2f else 0.1f,
        )
    }
    /** 按钮内容：玻璃与实心两条分支共用一份，形态不会分叉。 */
    val content: @Composable () -> Unit = {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = ink,
            modifier = Modifier.padding(horizontal = StagePreviewFabHorizontalPaddingDp.dp),
        )
    }
    // 触达目标 ≥48dp（`AccessibilitySemanticsGuardTest` 判据：源码须有 `sizeIn` + 48dp）。
    // 这颗胶囊本身高度就是 48（[StagePreviewFabMinHeightDp]），这里改用 `sizeIn` 同时钉住
    // 最小宽高：窄屏 / 大字号下圆角收窄时，点击热区不会被内容缩到 48 以下。
    val base = modifier.sizeIn(minWidth = 48.dp, minHeight = StagePreviewFabMinHeightDp.dp)

    if (backdrop != null) {
        Box(
            // 投影必须在 clip **之前**：写在条之后会被裁掉，胶囊就浮不起来。
            modifier = base
                .dropShadow(shape = shape, shadow = shadow)
                .clip(shape)
                .clickable(enabled = !busy, onClick = onClick)
                .alpha(if (busy) 0.55f else 1f),
            contentAlignment = Alignment.Center,
        ) {
            QingyuGlassSurface(
                backdrop = backdrop,
                spec = StagePreviewFabGlassSpec,
                modifier = Modifier.matchParentSize(),
                shape = shape,
                // 染色就是坞面的 `surfaceContainer × liquidTintAlpha`，不是另调一个色。
                tintBrush = SolidColor(surface.copy(alpha = StagePreviewFabGlassSpec.tintAlpha)),
                highlight = GlassDockSpecular.copy(
                    alpha = glassRimAlpha(StagePreviewFabGlassSpec.rimStrength),
                ),
            )
            content()
        }
    } else {
        Box(
            modifier = base
                .clip(shape)
                .background(surface)
                .border(1.dp, Color(QingyuTheme.outline(dark)), shape)
                .clickable(enabled = !busy, onClick = onClick)
                .alpha(if (busy) 0.55f else 1f),
            contentAlignment = Alignment.Center,
        ) {
            content()
        }
    }
}

/**
 * 速览 FAB 的玻璃口径 = **首页导航栏的出厂档**。
 *
 * 数值只经 `HomeMaterialRenderSpec.dockGlassTuning()` → [GlassSpecResolver.resolve] 一条链，
 * 不在本页另写一份（模糊 15 / 染色 0.70 / 折射 8 带 11 / 边光 0.2 / 色散 0.35）。
 *
 * 为什么不接用户的材质滑杆：本页拿不到材质快照（`SettingsMaterialModel.renderSpecOf` 要
 * `TimetableSettingsModel`，它只在首页壳那一支上），所以先用出厂档；日后壳肯把快照传进来时，
 * 只需把这里换成调用方传入的 spec，形状与调用点不用改。
 */
private val StagePreviewFabGlassSpec: GlassSpec =
    GlassSpecResolver.resolve(HomeMaterialRenderSpec().dockGlassTuning())

/** 胶囊圆角（dp）= 高度 48 的一半：两端是半圆，与底栏药丸同一读感。 */
private const val StagePreviewFabCornerDp = 24f

/** 命中区 / 视觉高度下限（dp）。 */
private const val StagePreviewFabMinHeightDp = 48f

/** 文字左右呼吸（dp）。 */
private const val StagePreviewFabHorizontalPaddingDp = 24f

/** 投影半径（dp），与底栏药丸同值。 */
private const val StagePreviewFabShadowRadiusDp = 10f

// ───────────────────────── 小工具 ─────────────────────────

/** 一位小数格式化（用于偏移滑杆标题，避免出现浮点抖动长尾）。 */
private fun formatOneDecimal(value: Double): String {
    val rounded = Math.round(value * 10.0) / 10.0
    return "%.1f".format(rounded)
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 4 档：课前页 / 课中下课·跟随课前 / 课中下课·独立设置 / 无课程空态；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 暗色 —— 页面取色走 isSystemInDarkTheme()，只有 QingyuPageTheme 会把
//     LocalConfiguration 的 uiMode 一起改写，预览才和真机同口径；
//   · 大字号 —— 行内文案的折行点，只在字被放大后才暴露；
//   · 跟随 / 独立 —— duringEndFollowBeforeClass 决定整页是否半透明、上课前快捷操作出不出现；
//   · 无课程 —— 没有真实课程时必须画诚实空态，不许拿演示课冒充。
//
// 固定写法：主题一律 QingyuPageTheme(isDark = …)、字号走 textScale 参数
//（@Preview(fontScale = …) 绕过了应用的 appTextScale 口径）；宽度按 400dp（本仓折行实测口径）。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假课程：一门正在上的课 + 下一节，全用中文实义值。 */
private fun previewIslandInfo(): LiveIslandPreviewInfo = LiveIslandPreviewInfo(
    courseName = "高等数学（下）",
    courseShortName = "高数",
    location = "示例大学 · 理科楼 302",
    teacher = "王老师",
    startTime = "08:00",
    endTime = "09:40",
    note = "带计算器",
    nextCourseName = "大学物理",
)

/** 渲染层能收到的四种输入组合；[name] 只用来给预览命名，不参与渲染。 */
private data class PreviewDisplaySettingsState(
    val name: String,
    val forDuringEnd: Boolean,
    val duringEndFollowBeforeClass: Boolean,
    val previewInfo: LiveIslandPreviewInfo?,
    val previewEmptyHint: String?,
)

private val previewDisplaySettingsStates: List<PreviewDisplaySettingsState> = listOf(
    PreviewDisplaySettingsState(
        name = "课前页",
        forDuringEnd = false,
        duringEndFollowBeforeClass = true,
        previewInfo = previewIslandInfo(),
        previewEmptyHint = null,
    ),
    PreviewDisplaySettingsState(
        name = "课中下课·跟随",
        forDuringEnd = true,
        duringEndFollowBeforeClass = true,
        previewInfo = previewIslandInfo(),
        previewEmptyHint = null,
    ),
    PreviewDisplaySettingsState(
        name = "课中下课·独立",
        forDuringEnd = true,
        duringEndFollowBeforeClass = false,
        previewInfo = previewIslandInfo(),
        previewEmptyHint = null,
    ),
    PreviewDisplaySettingsState(
        name = "无课程",
        forDuringEnd = false,
        duringEndFollowBeforeClass = true,
        previewInfo = null,
        previewEmptyHint = "请先在课表设置里填写开学日期",
    ),
)

private fun previewDisplaySettingsState(name: String): PreviewDisplaySettingsState =
    previewDisplaySettingsStates.first { it.name == name }

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewDisplaySettingsPage(
    state: PreviewDisplaySettingsState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        DisplaySettingsPage(
            state = LiveDisplayState(
                duringEndFollowBeforeClass = state.duringEndFollowBeforeClass,
            ),
            onStateChange = {},
            onBack = {},
            forDuringEnd = state.forDuringEnd,
            previewInfo = state.previewInfo,
            previewEmptyHint = state.previewEmptyHint,
        )
    }
}

// ── 单档：四态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 课前页", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewBeforeClass() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("课前页"))
}

@Suppress("unused")
@Preview(name = "2 课中下课·跟随", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewDuringEndFollow() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("课中下课·跟随"))
}

@Suppress("unused")
@Preview(name = "3 课中下课·独立", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewDuringEndEditable() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("课中下课·独立"))
}

@Suppress("unused")
@Preview(name = "4 无课程", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewNoCourse() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("无课程"))
}

// ── 单档：外观两档（以「课前页」为基准，其余状态换外观直接加参数）───────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewDark() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("课前页"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewLargeText() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("课前页"), textScale = 1.3f)
}

// ── 整页：1400 高，一屏看完整个页面 ────────────────────────────────────────
//
// 900 高那几档只够看前半页：胶囊左侧图标、展开卡片大图标、展开详情、
// 超级岛预览这几段都被裁在下面，改后半段时得靠滚动猜。这一档专门给「整页」，
// 原 900 档全部保留——它们仍是逐项对照时最省眼力的尺寸。

@Suppress("unused")
@Preview(name = "7 整页 1400", showBackground = true, widthDp = 400, heightDp = 1400)
@Composable
private fun DisplaySettingsPagePreviewFullPage() {
    PreviewDisplaySettingsPage(previewDisplaySettingsState("课前页"))
}

// ── 总览：四态并排，一屏看完 ────────────────────────────────────────────────

/**
 * 一屏总览：四种状态横向并排，用来一眼比结构差异（谁多了 / 少了哪一块）。
 *
 * 4 × 400dp + 3 × 16dp 间距 = 1648dp，所以画布给 1700dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~6 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·四态并排", showBackground = true, widthDp = 1700, heightDp = 900)
@Composable
private fun DisplaySettingsPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (state in previewDisplaySettingsStates) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewDisplaySettingsPage(state)
            }
        }
    }
}
