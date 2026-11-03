package com.mutx163.qingyu.pages.live

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSliderPreference
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuShapes
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference

/** 图片选择目标（供宿主接线层落到各自目录 / 前缀）。 */
enum class LiveImagePickTarget { LABEL_LOGO, EXPANDED_ICON }

/**
 * 「超级岛 · 显示设置页」· Compose 渲染层（重建 Flutter `LiveDisplaySettingsScreen`）。
 *
 * 8 个 section 全量：显示内容（6 开关）/ 倒计时格式 / 上课前快捷操作 /
 * 小米岛左侧标签全套 / 展开态图标 / 展开详情（显隐 + 排序 + 恢复默认）/
 * 两张预览卡 / 速览 FAB；`forDuringEnd` 两个变体（课中/下课页顶部多一组
 * 「配置方式 · 跟随上课前提醒设置」，且不显示上课前快捷操作）。
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
        DisplaySettingsStrings.displayEntryTitleDuringEnd.zh
    } else {
        DisplaySettingsStrings.displayEntryTitleBeforeClass.zh
    }
    val effectiveInfo = previewInfo?.copy(
        promoteDuringClass = state.promoteDuringClass,
        endSecondsCountdownThresholdSeconds = state.endSecondsCountdownThreshold,
    )

    QingyuPageScaffold(title = title, onBack = onBack) {
        // 骨架照 `docs/reference/compose-page-style-rules.md` §三：滚动容器走共享套件
        //（官方三件套 + 右侧滚动条）。Box 仍保留：速览 FAB 要贴在底部居中。
        // innerPadding 由外层 Box 吃掉，所以列表这里传 0，避免顶/底留白叠加两次。
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                scrollBehavior = scrollBehavior,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 104.dp),
            ) {
                // ── 课中/下课页顶部：配置方式（跟随上课前设置）──
                if (forDuringEnd) {
                    item(key = "config-mode-label") { QingyuSectionTitle(DisplaySettingsStrings.displayConfigModeTitle.zh) }
                    item(key = "config-mode-card") {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin),
                        ) {
                            SwitchPreference(
                                checked = state.duringEndFollowBeforeClass,
                                onCheckedChange = { onStateChange(state.withDuringEndFollowBeforeClass(it)) },
                                title = DisplaySettingsStrings.followBeforeClassDisplayTitle.zh,
                            )
                        }
                    }
                }

                // ── 1. 显示内容（6 开关）──
                item(key = "display-content-label") { QingyuSectionTitle(DisplaySettingsStrings.displayContentTitle.zh) }
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
                            title = DisplaySettingsStrings.showCourseNameTitle.zh,
                            summary = if (LiveDisplayLogic.showCourseNameDuplicatedHint(state)) {
                                DisplaySettingsStrings.courseNameDuplicatedHint.zh
                            } else null,
                            enabled = editable,
                        )
                        SwitchPreference(
                            checked = state.useShortName,
                            onCheckedChange = { onStateChange(state.withUseShortName(it)) },
                            title = DisplaySettingsStrings.preferShortNameTitle.zh,
                            summary = DisplaySettingsStrings.preferShortNameSubtitle.zh,
                            enabled = editable,
                        )
                        SwitchPreference(
                            checked = state.showLocation,
                            onCheckedChange = { onStateChange(state.withShowLocation(it)) },
                            title = DisplaySettingsStrings.showLocationTitle.zh,
                            summary = if (LiveDisplayLogic.showLocationDuplicatedHint(state)) {
                                DisplaySettingsStrings.locationDuplicatedHint.zh
                            } else null,
                            enabled = editable,
                        )
                        SwitchPreference(
                            checked = state.showCountdown,
                            onCheckedChange = { onStateChange(state.withShowCountdown(it)) },
                            title = DisplaySettingsStrings.showCountdownTitle.zh,
                            enabled = editable,
                        )
                        Box(modifier = Modifier.alpha(if (LiveDisplayLogic.shouldDimStageText(state)) 0.55f else 1f)) {
                            SwitchPreference(
                                checked = state.showStageText,
                                onCheckedChange = { onStateChange(state.withShowStageText(it)) },
                                title = DisplaySettingsStrings.showStageTextTitle.zh,
                                summary = if (state.showCountdown) DisplaySettingsStrings.showStageTextInactiveHint.zh else null,
                                enabled = editable,
                            )
                        }
                        Box(modifier = Modifier.alpha(if (LiveDisplayLogic.shouldDimHidePrefix(state)) 0.55f else 1f)) {
                            SwitchPreference(
                                checked = state.hidePrefixText,
                                onCheckedChange = { onStateChange(state.withHidePrefixText(it)) },
                                title = DisplaySettingsStrings.hidePrefixTextTitle.zh,
                                summary = if (!state.showCountdown) DisplaySettingsStrings.hidePrefixTextInactiveHint.zh else null,
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
                                title = DisplaySettingsStrings.countdownFormatLabel.zh,
                                summary = DisplaySettingsStrings.countdownFormatHelp.zh,
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
                                title = DisplaySettingsStrings.beforeClassQuickActionTitle.zh,
                                summary = DisplaySettingsStrings.beforeClassQuickActionSubtitle.zh,
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
                                    title = DisplaySettingsStrings.beforeClassQuickActionAutoTitle.zh,
                                    summary = DisplaySettingsStrings.beforeClassQuickActionAutoSubtitle.zh,
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
                                    title = LiveKeepAliveStrings.guideStatusDoNotDisturbAccess.zh,
                                    summary = LiveKeepAliveStrings.guideStatusDoNotDisturbAccessHint.zh,
                                    onClick = onOpenDoNotDisturbAccess,
                                    enabled = editable,
                                )
                            }
                        }
                    }
                }

                // ── 4. 小米岛左侧标签全套 ──
                item(key = "island-visual-label") { QingyuSectionTitle(DisplaySettingsStrings.islandVisualTitle.zh) }
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                        SwitchPreference(
                            checked = state.enableMiuiIslandLabelImage,
                            onCheckedChange = { onStateChange(state.withEnableMiuiIslandLabelImage(it)) },
                            title = DisplaySettingsStrings.miuiLabelImageTitle.zh,
                            summary = DisplaySettingsStrings.miuiLabelImageSubtitle.zh,
                            enabled = editable,
                        )
                    }
                }
                if (state.enableMiuiIslandLabelImage) {
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelContentLabel.zh,
                                values = MiuiIslandLabelContent.entries,
                                selected = state.miuiIslandLabelContent,
                                label = { DisplaySettingsStrings.miuiIslandLabelContentLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelContent(it)) },
                            )
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelStyleLabel.zh,
                                values = MiuiIslandLabelStyle.entries,
                                selected = state.miuiIslandLabelStyle,
                                label = { DisplaySettingsStrings.miuiIslandLabelStyleLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelStyle(it)) },
                            )
                            // 选图块（仅「图标+文字」样式）
                            if (state.miuiIslandLabelStyle == MiuiIslandLabelStyle.ICON_AND_TEXT) {
                                ImagePickerBlock(
                                    title = DisplaySettingsStrings.miuiLabelLogoTitle.zh,
                                    subtitle = DisplaySettingsStrings.miuiLabelLogoSubtitle.zh,
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
                            // 6 色点
                            ColorDotRow(
                                selectedHex = state.miuiIslandLabelFontColor,
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelFontColor(it)) },
                            )
                        }
                    }
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                            // 「文字排版与位置微调」：Flutter 用 HyperosAccordion，Compose 无对位件，
                            // 这里本地包一层：用一行标题 + 直接展开的滑杆/下拉（不折叠）。
                            Text(
                                text = DisplaySettingsStrings.miuiLabelAdvancedAccordionTitle.zh,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = Color(QingyuTheme.primaryText(dark)),
                                modifier = Modifier.padding(
                                    start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                    top = QingyuShapes.ROW_PADDING_VERTICAL.dp,
                                    end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                ),
                            )
                            Text(
                                text = DisplaySettingsStrings.miuiLabelAdvancedAccordionSubtitle.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(
                                    start = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                    end = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                                    bottom = 4.dp,
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
                                title = DisplaySettingsStrings.miuiLabelFontWeightLabel.zh,
                                values = MiuiIslandLabelFontWeight.entries,
                                selected = state.miuiIslandLabelFontWeight,
                                label = { DisplaySettingsStrings.miuiIslandLabelFontWeightLabel(it) },
                                enabled = editable,
                                onSelect = { onStateChange(state.withMiuiIslandLabelFontWeight(it)) },
                            )
                            EnumDropdown(
                                title = DisplaySettingsStrings.miuiLabelRenderQualityLabel.zh,
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
                item(key = "expanded-icon-label") { QingyuSectionTitle(DisplaySettingsStrings.expandedIconSectionTitle.zh) }
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin).alpha(sectionAlpha)) {
                        EnumDropdown(
                            title = DisplaySettingsStrings.miuiExpandedIconLabel.zh,
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
                                title = DisplaySettingsStrings.miuiExpandedIconLabel.zh,
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
                item(key = "expanded-detail-label") { QingyuSectionTitle(DisplaySettingsStrings.expandedDetailGroupTitle.zh) }
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
                            onMoveUp = { field ->
                                onStateChange(
                                    state.withExpandedDetailFields(
                                        LiveDisplayLogic.moveDetailFieldBy(state, field, -1, forDuringEnd),
                                    ),
                                )
                            },
                            onMoveDown = { field ->
                                onStateChange(
                                    state.withExpandedDetailFields(
                                        LiveDisplayLogic.moveDetailFieldBy(state, field, 1, forDuringEnd),
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
                                title = DisplaySettingsStrings.resetExpandedDetailDefaultAction.zh,
                                onClick = { onStateChange(state.withExpandedDetailFields(LiveDisplayLogic.resetDetailFields())) },
                                enabled = editable,
                            )
                        }
                    }
                }

                // ── 7. 两张预览卡（没有真实课程时只画诚实空态）──
                item(key = "island-preview-label") { QingyuSectionTitle(DisplaySettingsStrings.islandPreviewTitle.zh) }
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
                    item(key = "island-expanded-preview-label") {
                        QingyuSectionTitle(DisplaySettingsStrings.islandExpandedPreviewTitle.zh)
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

            // ── 8. 速览 FAB ──
            StagePreviewFab(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(start = 24.dp, end = 24.dp, bottom = 16.dp),
                label = if (stagePreviewActive) {
                    DisplaySettingsStrings.stagePreviewStopAction.zh
                } else if (forDuringEnd) {
                    DisplaySettingsStrings.stagePreviewDuringClassAction.zh
                } else {
                    DisplaySettingsStrings.stagePreviewBeforeClassAction.zh
                },
                active = stagePreviewActive,
                busy = stagePreviewBusy,
                dark = dark,
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

/** 6 色点选择行（对照 Flutter `_ColorDot`）。 */
@Composable
private fun ColorDotRow(
    selectedHex: String,
    enabled: Boolean,
    onSelect: (String) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
            ),
        // 色点可点区从 40dp 撑到 48dp 后，6 个点需要更紧的间距；收间距而不是缩命中面。
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        LiveDisplayLogic.LABEL_COLORS.forEach { hex ->
            val selected = selectedHex.equals(hex, ignoreCase = true)
            // 可点区撑到 48dp，色块视觉本体仍是 40dp。
            Box(
                modifier = Modifier
                    .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
                    .clickable(enabled = enabled) { onSelect(hex) },
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(parseColor(hex))
                        .border(
                            width = if (selected) 2.5.dp else 1.dp,
                            color = if (selected) MiuixTheme.colorScheme.primary else Color(QingyuTheme.dividerLine(dark)),
                            shape = RoundedCornerShape(16.dp),
                        ),
                )
            }
        }
    }
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
                text = if (path == null) DisplaySettingsStrings.selectImageAction.zh else DisplaySettingsStrings.replaceImageAction.zh,
                onClick = onPick,
                enabled = enabled,
                modifier = Modifier.weight(1f),
            )
            if (path != null) {
                TextButton(
                    text = DisplaySettingsStrings.deleteAction.zh,
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

/** 展开详情分组：已显示区（可上/下移排序 + 开关）+ 已隐藏区（仅开关）。 */
@Composable
private fun ExpandedDetailGroup(
    state: LiveDisplayState,
    forDuringEnd: Boolean,
    enabled: Boolean,
    dark: Boolean,
    onToggle: (LiveExpandedDetailField) -> Unit,
    onMoveUp: (LiveExpandedDetailField) -> Unit,
    onMoveDown: (LiveExpandedDetailField) -> Unit,
) {
    val enabledFields = LiveDisplayLogic.resolveDetailWorkOrder(state, forDuringEnd)
    val hiddenFields = LiveDisplayLogic.resolveHiddenDetailFields(state, forDuringEnd)

    enabledFields.forEachIndexed { index, field ->
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                    vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
                )
                .heightIn(min = QingyuShapes.LIST_ROW_MIN_HEIGHT.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // 拖动手柄位（Compose 无内置 ReorderableListView，改用上/下移按钮替代拖拽）
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(
                    text = DisplaySettingsStrings.detailMoveUpAction.zh,
                    onClick = { onMoveUp(field) },
                    enabled = enabled && index > 0,
                )
                TextButton(
                    text = DisplaySettingsStrings.detailMoveDownAction.zh,
                    onClick = { onMoveDown(field) },
                    enabled = enabled && index < enabledFields.lastIndex,
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = DisplaySettingsStrings.liveExpandedDetailFieldLabel(field),
                modifier = Modifier.weight(1f),
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Switch(
                checked = true,
                onCheckedChange = { onToggle(field) },
                enabled = enabled,
            )
        }
    }
    if (hiddenFields.isNotEmpty()) {
        Text(
            text = DisplaySettingsStrings.detailHiddenCaption.zh,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.padding(
                horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                vertical = 6.dp,
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
                text = DisplaySettingsStrings.islandPreviewEmpty.zh,
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

/** 速览悬浮按钮（对照 Flutter `_LiveStagePreviewFab` 的胶囊玻璃钮；此处用实心胶囊兜底）。 */
@Composable
private fun StagePreviewFab(
    label: String,
    active: Boolean,
    busy: Boolean,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val ink = if (active) Color(QingyuTheme.error(dark)) else MiuixTheme.colorScheme.primary
    Box(
        modifier = modifier
            .heightIn(min = 48.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(MiuixTheme.colorScheme.surface)
            .border(1.dp, Color(QingyuTheme.outline(dark)), RoundedCornerShape(24.dp))
            .clickable(enabled = !busy, onClick = onClick)
            .alpha(if (busy) 0.55f else 1f)
            .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text = label, style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM), color = ink)
    }
}

// ───────────────────────── 小工具 ─────────────────────────

/** 一位小数格式化（用于偏移滑杆标题，避免出现浮点抖动长尾）。 */
private fun formatOneDecimal(value: Double): String {
    val rounded = Math.round(value * 10.0) / 10.0
    return "%.1f".format(rounded)
}

/**
 * `#RRGGBB` 解析（失败回落中性灰）。
 *
 * 色值来自设置里存的字符串，所以这里逐通道拆出来构造，不写死 `Color(0x…)` 字面量
 * ——写死的十六进制在深色模式/换主题色后必然与周围不一致（规则 R5）。
 */
private fun parseColor(hex: String): Color {
    val cleaned = hex.trim().removePrefix("#")
    return try {
        if (cleaned.length == 6) {
            val rgb = cleaned.toInt(16)
            Color(
                red = (rgb shr 16) and 0xFF,
                green = (rgb shr 8) and 0xFF,
                blue = rgb and 0xFF,
            )
        } else {
            NeutralFallback
        }
    } catch (_: NumberFormatException) {
        NeutralFallback
    }
}

/**
 * 非法色值时的中性灰兜底色（0xFF888888）。
 *
 * 这是**故意固定**的语义色：它只出现在「用户存的色值解析失败」这条异常路径上，
 * 与主题无关（深色下也应当是中性灰），所以不进主题语义槽。
 */
private val NeutralFallback = Color(red = 0x88, green = 0x88, blue = 0x88)
