import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../utils/hex_color.dart';
import '../utils/app_toast.dart';
import '../ui/hyperos/hyperos.dart';

const String _expandedIconDir = 'miui_expanded_icons';
const String _labelLogoDir = 'miui_label_logos';
const List<String> _labelColors = [
  '#FFFFFF',
  '#E2E8F0',
  '#BFDBFE',
  '#A7F3D0',
  '#FDE68A',
  '#F9A8D4',
];

String _formatLiveTimeCorrection(AppLocalizations l10n, int seconds) {
  if (seconds == 0) {
    return l10n.liveTimeCorrectionNone;
  }
  if (seconds > 0) {
    return l10n.liveTimeCorrectionDelay(seconds);
  }
  return l10n.liveTimeCorrectionAdvance(seconds.abs());
}

String _buildLiveClassReminderLeadSummary(
  AppLocalizations l10n,
  TimetableSettings settings,
) {
  if (settings.liveClassReminderStartMinutes == 0) {
    return l10n.liveClassReminderLeadSummaryImmediate(
      settings.liveEndSecondsCountdownThreshold,
    );
  }
  if (settings.liveEnableDuringClass &&
      settings.liveShowDuringClassNotification &&
      !settings.livePromoteDuringClass) {
    return l10n.liveClassReminderLeadSummaryKeepNormal(
      settings.liveClassReminderStartMinutes,
      settings.liveEndSecondsCountdownThreshold,
    );
  }
  if (settings.liveEnableDuringClass &&
      settings.liveShowDuringClassNotification) {
    return l10n.liveClassReminderLeadSummaryIsland(
      settings.liveClassReminderStartMinutes,
      settings.liveEndSecondsCountdownThreshold,
    );
  }
  return l10n.liveClassReminderLeadSummaryFocused(
    settings.liveClassReminderStartMinutes,
    settings.liveEndSecondsCountdownThreshold,
  );
}

class LiveReminderTimingScreen extends StatefulWidget {
  const LiveReminderTimingScreen({super.key});

  @override
  State<LiveReminderTimingScreen> createState() =>
      _LiveReminderTimingScreenState();
}

class _LiveReminderTimingScreenState extends State<LiveReminderTimingScreen> {
  static const List<int> _beforeClassMinutesOptions = [
    1,
    5,
    10,
    15,
    20,
    30,
    40,
    50,
    60,
  ];
  static const List<int> _endSecondsOptions = [15, 30, 45, 60, 90];
  static const double _timeCorrectionMin = -30;
  static const double _timeCorrectionMax = 30;

  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  void dispose() {
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeCorrectionText = _formatLiveTimeCorrection(
      l10n,
      _draft.liveTimeCorrectionSeconds,
    );
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveReminderTimingTitle),
      child: HyperosListView(
        children: [
          HyperosSectionLabel(text: l10n.liveReminderSwitchesTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.beforeClassReminderTitle,
                subtitle: l10n.beforeClassReminderSubtitle(
                  _draft.liveShowBeforeClassMinutes,
                ),
                value: _draft.liveEnableBeforeClass,
                onChanged: (value) =>
                    _updateDraft(_draft.copyWith(liveEnableBeforeClass: value)),
              ),
              HyperosSwitchTile(
                title: l10n.duringClassReminderTitle,
                subtitle: l10n.duringClassReminderSubtitle,
                value:
                    _draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(
                    liveEnableDuringClass: value,
                    liveEnableBeforeEnd: value,
                  ),
                ),
              ),
            ],
          ),
          HyperosSectionDescription(text: l10n.liveReminderSwitchesSubtitle),
          if (_draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd) ...[
            const HyperosSectionGap(),
            HyperosControlCard(
              title: l10n.liveClassReminderLeadTitle,
              subtitle: _buildLiveClassReminderLeadSummary(l10n, _draft),
              child: HyperosSelectTile<int>(
                label: l10n.liveClassReminderLeadTitle,
                items: {
                  l10n.liveClassReminderLeadOptionImmediate: 0,
                  l10n.liveClassReminderLeadOptionMinutes(5): 5,
                  l10n.liveClassReminderLeadOptionMinutes(10): 10,
                  l10n.liveClassReminderLeadOptionMinutes(15): 15,
                  l10n.liveClassReminderLeadOptionMinutes(20): 20,
                  l10n.liveClassReminderLeadOptionMinutes(30): 30,
                },
                value: _draft.liveClassReminderStartMinutes,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveClassReminderStartMinutes: value),
                ),
              ),
            ),
          ],
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.liveDisplayModeTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.duringClassStatusNotificationTitle,
                subtitle: _draft.liveClassReminderStartMinutes == 0
                    ? l10n.duringClassStatusNotificationImmediate
                    : _draft.livePromoteDuringClass
                    ? l10n.duringClassStatusNotificationBeforeEnd
                    : l10n.duringClassStatusNotificationPersistent,
                value: _draft.liveShowDuringClassNotification,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveShowDuringClassNotification: value),
                ),
              ),
              HyperosSwitchTile(
                title: l10n.enableIslandDisplayTitle,
                subtitle: l10n.enableIslandDisplaySubtitle,
                value: _draft.livePromoteDuringClass,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(livePromoteDuringClass: value),
                ),
              ),
            ],
          ),
          HyperosSectionDescription(text: l10n.liveDisplayModeSubtitle),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.liveTimeThresholdTitle,
            subtitle: l10n.liveTimeThresholdSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HyperosSelectTile<int>(
                  label: l10n.beforeClassPopupLabel,
                  items: {
                    for (final value in _beforeClassMinutesOptions)
                      l10n.beforeClassMinutesOption(value): value,
                  },
                  value: _draft.liveShowBeforeClassMinutes,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveShowBeforeClassMinutes: value),
                  ),
                ),
                const SizedBox(height: 12),
                HyperosSelectTile<int>(
                  label: l10n.beforeEndSecondsLabel,
                  items: {
                    for (final value in _endSecondsOptions)
                      l10n.beforeEndSecondsOption(value): value,
                  },
                  value: _draft.liveEndSecondsCountdownThreshold,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveEndSecondsCountdownThreshold: value),
                  ),
                ),
                const SizedBox(height: 12),
                HyperosSliderTile(
                  title: l10n.timeCorrectionLabel(timeCorrectionText),
                  value: _draft.liveTimeCorrectionSeconds.toDouble(),
                  min: _timeCorrectionMin,
                  max: _timeCorrectionMax,
                  divisions: (_timeCorrectionMax - _timeCorrectionMin).round(),
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveTimeCorrectionSeconds: value.round()),
                    debounce: true,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal:
                        HyperosControlCardScope.defaultHorizontalPadding,
                  ),
                  child: Text(
                    l10n.timeCorrectionHelp,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
                const SizedBox(height: 12),
                HyperosSelectTile<LiveDuringClassTimeDisplayMode>(
                  label: l10n.duringEndTimeDisplayLabel,
                  items: {
                    for (final value in LiveDuringClassTimeDisplayMode.values)
                      liveDuringClassTimeDisplayModeLabel(l10n, value): value,
                  },
                  value: _draft.liveDuringEndTimeDisplayMode,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveDuringEndTimeDisplayMode: value),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal:
                        HyperosControlCardScope.defaultHorizontalPadding,
                  ),
                  child: Text(
                    l10n.duringEndTimeDisplayHelp,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() => _draft = next);
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) return;
    if (message != null) {
      showAppToast(context, message: message);
      setState(() => _draft = provider.settings);
    }
  }
}

class LiveDisplaySettingsScreen extends StatefulWidget {
  final String title;
  final bool forDuringEnd;

  const LiveDisplaySettingsScreen({
    super.key,
    required this.title,
    required this.forDuringEnd,
  });

  @override
  State<LiveDisplaySettingsScreen> createState() =>
      _LiveDisplaySettingsScreenState();
}

class _LiveDisplaySettingsScreenState extends State<LiveDisplaySettingsScreen> {
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
    unawaited(
      context.read<TimetableProvider>().refreshLiveActivityNow(
        forceSnapshotSync: true,
      ),
    );
  }

  @override
  void dispose() {
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  LiveDisplaySettings get _display => widget.forDuringEnd
      ? _draft.duringEndDisplaySettings
      : _draft.beforeClassDisplaySettings;

  bool get _followBeforeClass =>
      widget.forDuringEnd && _draft.liveDuringEndFollowBeforeClass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final display = _display;
    final sectionCards = <Widget>[
      HyperosSectionLabel(text: l10n.liveDisplayContentTitle),
      HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.showCourseNameTitle,
            value: display.showCourseName,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showCourseName: value)),
          ),
          HyperosSwitchTile(
            title: l10n.preferShortNameTitle,
            subtitle: l10n.preferShortNameSubtitle,
            value: display.useShortName,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(useShortName: value)),
          ),
          HyperosSwitchTile(
            title: l10n.showLocationTitle,
            value: display.showLocation,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showLocation: value)),
          ),
          HyperosSwitchTile(
            title: l10n.showCountdownTitle,
            value: display.showCountdown,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showCountdown: value)),
          ),
          HyperosSwitchTile(
            title: l10n.showStageTextTitle,
            subtitle: l10n.showStageTextSubtitle,
            value: display.showStageText,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showStageText: value)),
          ),
          HyperosSwitchTile(
            title: l10n.hidePrefixTextTitle,
            subtitle: l10n.hidePrefixTextSubtitle,
            value: display.hidePrefixText,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(hidePrefixText: value)),
          ),
        ],
      ),
      HyperosSectionDescription(text: l10n.liveDisplayContentSubtitle),
      if (display.showCountdown) ...[
        const HyperosSectionGap(),
        HyperosControlCard(
          edgeToEdge: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HyperosSelectTile<LiveCountdownTextStyle>(
                label: l10n.countdownFormatLabel,
                items: {
                  for (final value in LiveCountdownTextStyle.values)
                    liveCountdownTextStyleLabel(l10n, value): value,
                },
                value: display.countdownTextStyle,
                onChanged: (value) =>
                    _updateDisplay(display.copyWith(countdownTextStyle: value)),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HyperosControlCardScope.defaultHorizontalPadding,
                  0,
                  HyperosControlCardScope.defaultHorizontalPadding,
                  HyperosControlCardScope.defaultBodyBottomInset,
                ),
                child: Text(
                  l10n.countdownFormatHelp,
                  style: HyperosTypography.listDetail(context),
                ),
              ),
            ],
          ),
        ),
      ],
      if (!widget.forDuringEnd) ...[
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.beforeClassQuickActionTitle,
          subtitle: l10n.beforeClassQuickActionSubtitle,
          child: HyperosSelectTile<LiveBeforeClassQuickAction>(
            label: l10n.beforeClassQuickActionTitle,
            items: {
              for (final value in LiveBeforeClassQuickAction.values)
                liveBeforeClassQuickActionLabel(l10n, value): value,
            },
            value: _draft.liveBeforeClassQuickAction,
            onChanged: (value) => _updateDraft(
              _draft.copyWith(liveBeforeClassQuickAction: value),
            ),
          ),
        ),
      ],
      const HyperosSectionGap(),
      HyperosSectionLabel(text: l10n.liveIslandVisualTitle),
      HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.liveMiuiLabelImageTitle,
            subtitle: l10n.liveMiuiLabelImageSubtitle,
            value: display.enableMiuiIslandLabelImage,
            onChanged: (value) => _updateDisplay(
              display.copyWith(enableMiuiIslandLabelImage: value),
            ),
          ),
        ],
      ),
      HyperosSectionDescription(text: l10n.liveIslandVisualSubtitle),
      if (display.enableMiuiIslandLabelImage) ...[
        const HyperosSectionGap(),
        HyperosControlCard(
          edgeToEdge: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HyperosSelectTile<MiuiIslandLabelContent>(
                label: l10n.liveMiuiLabelContentLabel,
                items: {
                  for (final value in MiuiIslandLabelContent.values)
                    miuiIslandLabelContentLabel(l10n, value): value,
                },
                value: display.miuiIslandLabelContent,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelContent: value),
                ),
              ),
              const SizedBox(height: 12),
              HyperosSelectTile<MiuiIslandLabelStyle>(
                label: l10n.liveMiuiLabelStyleLabel,
                items: {
                  for (final value in MiuiIslandLabelStyle.values)
                    miuiIslandLabelStyleLabel(l10n, value): value,
                },
                value: display.miuiIslandLabelStyle,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelStyle: value),
                ),
              ),
              if (display.miuiIslandLabelStyle ==
                  MiuiIslandLabelStyle.iconAndText) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HyperosControlCardScope.defaultHorizontalPadding,
                  ),
                  child: Text(
                    l10n.liveMiuiLabelLogoTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HyperosControlCardScope.defaultHorizontalPadding,
                  ),
                  child: Text(
                    l10n.liveMiuiLabelLogoSubtitle,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HyperosControlCardScope.defaultHorizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: HyperosButton(
                          label: display.miuiIslandLabelLogoPath == null
                              ? l10n.selectImageAction
                              : l10n.replaceImageAction,
                          variant: HyperosButtonVariant.secondary,
                          expand: true,
                          onPressed: () => _pickLabelLogoImage(display),
                        ),
                      ),
                      if (display.miuiIslandLabelLogoPath != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: HyperosButton(
                            label: l10n.deleteAction,
                            variant: HyperosButtonVariant.destructive,
                            expand: true,
                            onPressed: () async {
                              await _deleteManagedImageArtifacts(
                                directoryName: _labelLogoDir,
                                filePrefix: widget.forDuringEnd
                                    ? 'during_end_label_logo'
                                    : 'before_class_label_logo',
                              );
                              _updateDisplay(
                                display.copyWith(
                                  clearMiuiIslandLabelLogoPath: true,
                                ),
                                clearLabelLogoPath: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (display.miuiIslandLabelLogoPath != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HyperosControlCardScope.defaultHorizontalPadding,
                    ),
                    child: _ImagePreview(
                      path: display.miuiIslandLabelLogoPath!,
                      imageCornerRadius: display.miuiIslandLabelLogoCornerRadius,
                    ),
                  ),
                  const SizedBox(height: 12),
                  HyperosSliderTile(
                    title: l10n.liveMiuiLabelLogoCornerRadiusLabel(
                      display.miuiIslandLabelLogoCornerRadius.toStringAsFixed(
                        0,
                      ),
                    ),
                    value: display.miuiIslandLabelLogoCornerRadius.clamp(
                      0.0,
                      12.0,
                    ),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    onChanged: (value) => _updateDisplay(
                      display.copyWith(miuiIslandLabelLogoCornerRadius: value),
                      debounce: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              HyperosSliderTile(
                title: l10n.liveMiuiLabelFontSizeLabel(
                  display.miuiIslandLabelFontSize.toStringAsFixed(0),
                ),
                value: display.miuiIslandLabelFontSize,
                min: 1,
                max: 32,
                divisions: 31,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelFontSize: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              HyperosSliderTile(
                title: l10n.liveMiuiLabelOffsetXLabel(
                  display.miuiIslandLabelOffsetX.toStringAsFixed(1),
                ),
                value: display.miuiIslandLabelOffsetX.clamp(-2.0, 2.0),
                min: -2,
                max: 2,
                divisions: 40,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelOffsetX: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              HyperosSliderTile(
                title: l10n.liveMiuiLabelOffsetYLabel(
                  display.miuiIslandLabelOffsetY.toStringAsFixed(1),
                ),
                value: display.miuiIslandLabelOffsetY.clamp(-2.0, 2.0),
                min: -2,
                max: 2,
                divisions: 40,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelOffsetY: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              HyperosSelectTile<MiuiIslandLabelFontWeight>(
                label: l10n.liveMiuiLabelFontWeightLabel,
                items: {
                  for (final value in MiuiIslandLabelFontWeight.values)
                    miuiIslandLabelFontWeightLabel(l10n, value): value,
                },
                value: display.miuiIslandLabelFontWeight,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelFontWeight: value),
                ),
              ),
              const SizedBox(height: 12),
              HyperosSelectTile<MiuiIslandLabelRenderQuality>(
                label: l10n.liveMiuiLabelRenderQualityLabel,
                items: {
                  for (final value in MiuiIslandLabelRenderQuality.values)
                    miuiIslandLabelRenderQualityLabel(l10n, value): value,
                },
                value: display.miuiIslandLabelRenderQuality,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelRenderQuality: value),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HyperosControlCardScope.defaultHorizontalPadding,
                  0,
                  HyperosControlCardScope.defaultHorizontalPadding,
                  HyperosControlCardScope.defaultBodyBottomInset,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _labelColors
                      .map(
                        (color) => _ColorDot(
                          colorHex: color,
                          selected: display.miuiIslandLabelFontColor == color,
                          onTap: () => _updateDisplay(
                            display.copyWith(miuiIslandLabelFontColor: color),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
      const HyperosSectionGap(),
      HyperosControlCard(
        edgeToEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HyperosControlCardRowScope(
              isFirst: true,
              isLast: false,
              child: HyperosSelectTile<MiuiIslandExpandedIconMode>(
                label: l10n.liveMiuiExpandedIconLabel,
                items: {
                  for (final value in MiuiIslandExpandedIconMode.values)
                    miuiIslandExpandedIconModeLabel(l10n, value): value,
                },
                value: display.miuiIslandExpandedIconMode,
                onChanged: (value) {
                  () async {
                    if (value != MiuiIslandExpandedIconMode.customImage) {
                      await _deleteManagedImageArtifacts(
                        directoryName: _expandedIconDir,
                        filePrefix: widget.forDuringEnd
                            ? 'during_end_expanded_icon'
                            : 'before_class_expanded_icon',
                      );
                    }
                    _updateDisplay(
                      display.copyWith(
                        miuiIslandExpandedIconMode: value,
                        clearMiuiIslandExpandedIconPath:
                            value != MiuiIslandExpandedIconMode.customImage,
                      ),
                      clearExpandedIconPath:
                          value != MiuiIslandExpandedIconMode.customImage,
                    );
                  }();
                },
              ),
            ),
            if (display.miuiIslandExpandedIconMode ==
                MiuiIslandExpandedIconMode.customImage) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HyperosControlCardScope.defaultHorizontalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: HyperosButton(
                        label: display.miuiIslandExpandedIconPath == null
                            ? l10n.selectImageAction
                            : l10n.replaceImageAction,
                        variant: HyperosButtonVariant.secondary,
                        expand: true,
                        onPressed: () => _pickExpandedIconImage(display),
                      ),
                    ),
                    if (display.miuiIslandExpandedIconPath != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: HyperosButton(
                          label: l10n.deleteAction,
                          variant: HyperosButtonVariant.destructive,
                          expand: true,
                          onPressed: () async {
                            await _deleteManagedImageArtifacts(
                              directoryName: _expandedIconDir,
                              filePrefix: widget.forDuringEnd
                                  ? 'during_end_expanded_icon'
                                  : 'before_class_expanded_icon',
                            );
                            _updateDisplay(
                              display.copyWith(
                                clearMiuiIslandExpandedIconPath: true,
                              ),
                              clearExpandedIconPath: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (display.miuiIslandExpandedIconPath != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HyperosControlCardScope.defaultHorizontalPadding,
                    0,
                    HyperosControlCardScope.defaultHorizontalPadding,
                    HyperosControlCardScope.defaultBodyBottomInset,
                  ),
                  child: _ImagePreview(path: display.miuiIslandExpandedIconPath!),
                ),
              ] else
                const SizedBox(
                  height: HyperosControlCardScope.defaultBodyBottomInset,
                ),
            ],
          ],
        ),
      ),
    ];
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.title),
      child: HyperosListView(
        children: [
          if (widget.forDuringEnd) ...[
            HyperosSectionLabel(text: l10n.liveDisplayConfigModeTitle),
            HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  title: l10n.followBeforeClassDisplayTitle,
                  value: _draft.liveDuringEndFollowBeforeClass,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveDuringEndFollowBeforeClass: value),
                  ),
                ),
              ],
            ),
            HyperosSectionDescription(text: l10n.liveDisplayConfigModeSubtitle),
            const HyperosSectionGap(),
          ],
          if (_followBeforeClass)
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sectionCards,
                ),
              ),
            )
          else
            ...sectionCards,
        ],
      ),
    );
  }

  void _updateDisplay(
    LiveDisplaySettings next, {
    bool debounce = false,
    bool clearExpandedIconPath = false,
    bool clearLabelLogoPath = false,
  }) {
    final nextSettings = widget.forDuringEnd
        ? _draft.copyWithDuringEndDisplaySettings(
            next,
            clearExpandedIconPath: clearExpandedIconPath,
            clearLabelLogoPath: clearLabelLogoPath,
          )
        : _draft.copyWithBeforeClassDisplaySettings(
            next,
            clearExpandedIconPath: clearExpandedIconPath,
            clearLabelLogoPath: clearLabelLogoPath,
          );
    _updateDraft(nextSettings, debounce: debounce);
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() => _draft = next);
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) return;
    if (message != null) {
      showAppToast(context, message: message);
      setState(() => _draft = provider.settings);
    }
  }

  Future<void> _pickExpandedIconImage(LiveDisplaySettings display) async {
    final targetPath = await _pickAndStoreImage(
      directoryName: _expandedIconDir,
      filePrefix: widget.forDuringEnd
          ? 'during_end_expanded_icon'
          : 'before_class_expanded_icon',
    );
    if (!mounted || targetPath == null) return;
    _updateDisplay(
      display.copyWith(
        miuiIslandExpandedIconMode: MiuiIslandExpandedIconMode.customImage,
        miuiIslandExpandedIconPath: targetPath,
      ),
    );
  }

  Future<void> _pickLabelLogoImage(LiveDisplaySettings display) async {
    final targetPath = await _pickAndStoreImage(
      directoryName: _labelLogoDir,
      filePrefix: widget.forDuringEnd
          ? 'during_end_label_logo'
          : 'before_class_label_logo',
    );
    if (!mounted || targetPath == null) return;
    _updateDisplay(display.copyWith(miuiIslandLabelLogoPath: targetPath));
  }

  Future<String?> _pickAndStoreImage({
    required String directoryName,
    required String filePrefix,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) return null;
    final ext = (file.extension?.isNotEmpty ?? false)
        ? file.extension!.toLowerCase()
        : 'png';
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${dir.path}${Platform.pathSeparator}$directoryName',
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final targetPath =
        '${targetDir.path}${Platform.pathSeparator}$filePrefix.$ext';
    await File(targetPath).writeAsBytes(bytes, flush: true);
    await _deleteManagedImageArtifacts(
      directoryName: directoryName,
      filePrefix: filePrefix,
      preservePath: targetPath,
    );
    return targetPath;
  }

  Future<void> _deleteManagedImageArtifacts({
    required String directoryName,
    required String filePrefix,
    String? preservePath,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${dir.path}${Platform.pathSeparator}$directoryName',
    );
    if (!await targetDir.exists()) {
      return;
    }
    final preservedAbsolutePath = preservePath == null
        ? null
        : File(preservePath).absolute.path;
    await for (final entity in targetDir.list()) {
      if (entity is! File) {
        continue;
      }
      final fileName = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      if (!fileName.startsWith('$filePrefix.')) {
        continue;
      }
      if (preservedAbsolutePath != null &&
          entity.absolute.path == preservedAbsolutePath) {
        continue;
      }
      try {
        if (await entity.exists()) {
          await entity.delete();
        }
      } catch (_) {}
    }
  }
}

class LiveKeepAliveSettingsScreen extends StatefulWidget {
  const LiveKeepAliveSettingsScreen({super.key});

  @override
  State<LiveKeepAliveSettingsScreen> createState() =>
      _LiveKeepAliveSettingsScreenState();
}

class _LiveKeepAliveSettingsScreenState
    extends State<LiveKeepAliveSettingsScreen>
    with WidgetsBindingObserver {
  final MiuiLiveActivitiesService _liveService = MiuiLiveActivitiesService();
  late TimetableSettings _draft;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft = context.read<TimetableProvider>().settings;
    unawaited(_refresh(retryIfDisabled: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(retryIfDisabled: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveKeepAliveTitle),
      child: HyperosListView(
        children: [
          HyperosSectionLabel(text: l10n.liveKeepAliveOptionsTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.hideFromRecentsTitle,
                subtitle: l10n.hideFromRecentsSubtitle,
                value: _draft.liveHideFromRecents,
                onChanged: (value) async {
                  final provider = context.read<TimetableProvider>();
                  final message = await provider.updateTimetableSettings(
                    _draft.copyWith(liveHideFromRecents: value),
                  );
                  if (!context.mounted) return;
                  if (message != null) {
                    showAppToast(context, message: message);
                  }
                  setState(() => _draft = provider.settings);
                },
              ),
              _LiveKeepAliveServiceTile(
                enabled: _enabled,
                onOpenSettings: _openSettings,
              ),
            ],
          ),
          HyperosSectionDescription(text: l10n.liveKeepAliveOptionsSubtitle),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await _liveService.openAccessibilitySettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _refresh(retryIfDisabled: true);
  }

  Future<void> _refresh({bool retryIfDisabled = false}) async {
    var enabled = await _liveService.isKeepAliveAccessibilityEnabled();
    if (!enabled && retryIfDisabled) {
      for (var i = 0; i < 3 && !enabled; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        enabled = await _liveService.isKeepAliveAccessibilityEnabled();
      }
    }
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
    });
  }
}

class _LiveKeepAliveServiceTile extends StatelessWidget {
  const _LiveKeepAliveServiceTile({
    required this.enabled,
    required this.onOpenSettings,
  });

  final bool enabled;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final iconAccent = enabled
        ? HyperosIconColors.green
        : HyperosIconColors.orange;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPaddingUniform,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HyperosIconBadge(
              icon: enabled
                  ? Icons.check_circle_rounded
                  : Icons.accessibility_new_rounded,
              accent: iconAccent,
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.keepAliveServiceTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? l10n.keepAliveServiceEnabledSubtitle
                        : l10n.keepAliveServiceDisabledSubtitle,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HyperosButton(
              label: l10n.goEnableAction,
              variant: HyperosButtonVariant.secondary,
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onOpenSettings,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _parseColor(colorHex),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String path;
  final double imageCornerRadius;

  const _ImagePreview({required this.path, this.imageCornerRadius = 12});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(imageCornerRadius),
            child: file.existsSync()
                ? Image.file(
                    file,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 56,
                        height: 56,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.body.xs2,
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hexColor) {
  return parseHexColorOrFallback(hexColor, fallback: const Color(0xFF2563EB));
}
