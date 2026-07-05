import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../utils/hex_color.dart';
import '../widgets/settings_section_widgets.dart';

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
    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.liveReminderTimingTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FTileGroup(
              label: Text(l10n.liveReminderSwitchesTitle),
              description: Text(l10n.liveReminderSwitchesSubtitle),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SettingSwitchTile(
                  title: Text(l10n.beforeClassReminderTitle),
                  subtitle: Text(
                    l10n.beforeClassReminderSubtitle(
                      _draft.liveShowBeforeClassMinutes,
                    ),
                  ),
                  value: _draft.liveEnableBeforeClass,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveEnableBeforeClass: value),
                  ),
                ),
                SettingSwitchTile(
                  title: Text(l10n.duringClassReminderTitle),
                  subtitle: Text(l10n.duringClassReminderSubtitle),
                  value:
                      _draft.liveEnableDuringClass ||
                      _draft.liveEnableBeforeEnd,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(
                      liveEnableDuringClass: value,
                      liveEnableBeforeEnd: value,
                    ),
                  ),
                ),
              ],
            ),
            if (_draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd) ...[
              const SizedBox(height: 12),
              SettingsSectionCard(
                title: l10n.liveClassReminderLeadTitle,
                subtitle: _buildLiveClassReminderLeadSummary(l10n, _draft),
                child: FSelect<int>(
                  hint: l10n.liveClassReminderLeadTitle,
                  items: {
                    l10n.liveClassReminderLeadOptionImmediate: 0,
                    l10n.liveClassReminderLeadOptionMinutes(5): 5,
                    l10n.liveClassReminderLeadOptionMinutes(10): 10,
                    l10n.liveClassReminderLeadOptionMinutes(15): 15,
                    l10n.liveClassReminderLeadOptionMinutes(20): 20,
                    l10n.liveClassReminderLeadOptionMinutes(30): 30,
                  },
                  control: FSelectControl.lifted(
                    value: _draft.liveClassReminderStartMinutes,
                    onChange: (value) {
                      if (value == null) return;
                      _updateDraft(
                        _draft.copyWith(liveClassReminderStartMinutes: value),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FTileGroup(
              label: Text(l10n.liveDisplayModeTitle),
              description: Text(l10n.liveDisplayModeSubtitle),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SettingSwitchTile(
                  title: Text(l10n.duringClassStatusNotificationTitle),
                  subtitle: Text(
                    _draft.liveClassReminderStartMinutes == 0
                        ? l10n.duringClassStatusNotificationImmediate
                        : _draft.livePromoteDuringClass
                        ? l10n.duringClassStatusNotificationBeforeEnd
                        : l10n.duringClassStatusNotificationPersistent,
                  ),
                  value: _draft.liveShowDuringClassNotification,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveShowDuringClassNotification: value),
                  ),
                ),
                SettingSwitchTile(
                  title: Text(l10n.enableIslandDisplayTitle),
                  subtitle: Text(l10n.enableIslandDisplaySubtitle),
                  value: _draft.livePromoteDuringClass,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(livePromoteDuringClass: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.liveTimeThresholdTitle,
              subtitle: l10n.liveTimeThresholdSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FSelect<int>(
                    hint: l10n.beforeClassPopupLabel,
                    items: {
                      for (final value in _beforeClassMinutesOptions)
                        l10n.beforeClassMinutesOption(value): value,
                    },
                    control: FSelectControl.lifted(
                      value: _draft.liveShowBeforeClassMinutes,
                      onChange: (value) {
                        if (value == null) return;
                        _updateDraft(
                          _draft.copyWith(liveShowBeforeClassMinutes: value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FSelect<int>(
                    hint: l10n.beforeEndSecondsLabel,
                    items: {
                      for (final value in _endSecondsOptions)
                        l10n.beforeEndSecondsOption(value): value,
                    },
                    control: FSelectControl.lifted(
                      value: _draft.liveEndSecondsCountdownThreshold,
                      onChange: (value) {
                        if (value == null) return;
                        _updateDraft(
                          _draft.copyWith(
                            liveEndSecondsCountdownThreshold: value,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.timeCorrectionLabel(timeCorrectionText),
                    style: context.theme.typography.body.sm,
                  ),
                  FSlider(
                    control: FSliderControl.managedDiscrete(
                      initial: FSliderValue(
                        max:
                            ((_draft.liveTimeCorrectionSeconds -
                                        _timeCorrectionMin) /
                                    (_timeCorrectionMax - _timeCorrectionMin))
                                .clamp(0.0, 1.0),
                      ),
                      onChange: (sv) => _updateDraft(
                        _draft.copyWith(
                          liveTimeCorrectionSeconds:
                              (_timeCorrectionMin +
                                      sv.max *
                                          (_timeCorrectionMax -
                                              _timeCorrectionMin))
                                  .round(),
                        ),
                        debounce: true,
                      ),
                    ),
                    marks: [
                      for (var i = 0; i <= 60; i++) FSliderMark(value: i / 60),
                    ],
                  ),
                  Text(
                    l10n.timeCorrectionHelp,
                    style: context.theme.typography.body.xs2,
                  ),
                  const SizedBox(height: 12),
                  FSelect<LiveDuringClassTimeDisplayMode>(
                    hint: l10n.duringEndTimeDisplayLabel,
                    items: {
                      for (final value in LiveDuringClassTimeDisplayMode.values)
                        value.label: value,
                    },
                    control: FSelectControl.lifted(
                      value: _draft.liveDuringEndTimeDisplayMode,
                      onChange: (value) {
                        if (value == null) return;
                        _updateDraft(
                          _draft.copyWith(liveDuringEndTimeDisplayMode: value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.duringEndTimeDisplayHelp,
                    style: context.theme.typography.body.xs2,
                  ),
                ],
              ),
            ),
          ],
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final sectionCards = [
      FTileGroup(
        label: Text(l10n.liveDisplayContentTitle),
        description: Text(l10n.liveDisplayContentSubtitle),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SettingSwitchTile(
            title: Text(l10n.showCourseNameTitle),
            value: display.showCourseName,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showCourseName: value)),
          ),
          SettingSwitchTile(
            title: Text(l10n.preferShortNameTitle),
            subtitle: Text(l10n.preferShortNameSubtitle),
            value: display.useShortName,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(useShortName: value)),
          ),
          SettingSwitchTile(
            title: Text(l10n.showLocationTitle),
            value: display.showLocation,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showLocation: value)),
          ),
          SettingSwitchTile(
            title: Text(l10n.showCountdownTitle),
            value: display.showCountdown,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showCountdown: value)),
          ),
          SettingSwitchTile(
            title: Text(l10n.showStageTextTitle),
            subtitle: Text(l10n.showStageTextSubtitle),
            value: display.showStageText,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showStageText: value)),
          ),
          SettingSwitchTile(
            title: Text(l10n.hidePrefixTextTitle),
            subtitle: Text(l10n.hidePrefixTextSubtitle),
            value: display.hidePrefixText,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(hidePrefixText: value)),
          ),
        ],
      ),
      if (display.showCountdown) ...[
        const SizedBox(height: 12),
        SettingsSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FSelect<LiveCountdownTextStyle>(
                hint: l10n.countdownFormatLabel,
                items: {
                  for (final value in LiveCountdownTextStyle.values)
                    value.label: value,
                },
                control: FSelectControl.lifted(
                  value: display.countdownTextStyle,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDisplay(display.copyWith(countdownTextStyle: value));
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.countdownFormatHelp,
                style: context.theme.typography.body.xs2,
              ),
            ],
          ),
        ),
      ],
      if (!widget.forDuringEnd) ...[
        const SizedBox(height: 12),
        SettingsSectionCard(
          title: l10n.beforeClassQuickActionTitle,
          subtitle: l10n.beforeClassQuickActionSubtitle,
          child: FSelect<LiveBeforeClassQuickAction>(
            hint: l10n.beforeClassQuickActionTitle,
            items: {
              for (final value in LiveBeforeClassQuickAction.values)
                value.label: value,
            },
            control: FSelectControl.lifted(
              value: _draft.liveBeforeClassQuickAction,
              onChange: (value) {
                if (value == null) return;
                _updateDraft(
                  _draft.copyWith(liveBeforeClassQuickAction: value),
                );
              },
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      FTileGroup(
        label: Text(l10n.liveIslandVisualTitle),
        description: Text(l10n.liveIslandVisualSubtitle),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SettingSwitchTile(
            title: Text(l10n.liveMiuiLabelImageTitle),
            subtitle: Text(l10n.liveMiuiLabelImageSubtitle),
            value: display.enableMiuiIslandLabelImage,
            onChanged: (value) => _updateDisplay(
              display.copyWith(enableMiuiIslandLabelImage: value),
            ),
          ),
        ],
      ),
      if (display.enableMiuiIslandLabelImage) ...[
        const SizedBox(height: 12),
        SettingsSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FSelect<MiuiIslandLabelContent>(
                hint: l10n.liveMiuiLabelContentLabel,
                items: {
                  for (final value in MiuiIslandLabelContent.values)
                    value.label: value,
                },
                control: FSelectControl.lifted(
                  value: display.miuiIslandLabelContent,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDisplay(
                      display.copyWith(miuiIslandLabelContent: value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FSelect<MiuiIslandLabelStyle>(
                hint: l10n.liveMiuiLabelStyleLabel,
                items: {
                  for (final value in MiuiIslandLabelStyle.values)
                    value.label: value,
                },
                control: FSelectControl.lifted(
                  value: display.miuiIslandLabelStyle,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDisplay(
                      display.copyWith(miuiIslandLabelStyle: value),
                    );
                  },
                ),
              ),
              if (display.miuiIslandLabelStyle ==
                  MiuiIslandLabelStyle.iconAndText) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.liveMiuiLabelLogoTitle,
                  style: context.theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.liveMiuiLabelLogoSubtitle,
                  style: context.theme.typography.body.xs2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.secondary,
                        onPress: () => _pickLabelLogoImage(display),
                        prefix: const Icon(Icons.image_outlined),
                        child: Text(
                          display.miuiIslandLabelLogoPath == null
                              ? l10n.selectImageAction
                              : l10n.replaceImageAction,
                        ),
                      ),
                    ),
                    if (display.miuiIslandLabelLogoPath != null) ...[
                      const SizedBox(width: 12),
                      FButton.icon(
                        variant: FButtonVariant.outline,
                        onPress: () async {
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
                        child: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ],
                ),
                if (display.miuiIslandLabelLogoPath != null) ...[
                  const SizedBox(height: 12),
                  _ImagePreview(
                    path: display.miuiIslandLabelLogoPath!,
                    imageCornerRadius: display.miuiIslandLabelLogoCornerRadius,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.liveMiuiLabelLogoCornerRadiusLabel(
                      display.miuiIslandLabelLogoCornerRadius.toStringAsFixed(
                        0,
                      ),
                    ),
                    style: context.theme.typography.body.sm,
                  ),
                  FSlider(
                    control: FSliderControl.managedDiscrete(
                      initial: FSliderValue(
                        max:
                            (display.miuiIslandLabelLogoCornerRadius.clamp(
                                      0.0,
                                      12.0,
                                    ) /
                                    12)
                                .clamp(0.0, 1.0),
                      ),
                      onChange: (sv) => _updateDisplay(
                        display.copyWith(
                          miuiIslandLabelLogoCornerRadius: sv.max * 12,
                        ),
                        debounce: true,
                      ),
                    ),
                    marks: [
                      for (var i = 0; i <= 12; i++) FSliderMark(value: i / 12),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.liveMiuiLabelFontSizeLabel(
                  display.miuiIslandLabelFontSize.toStringAsFixed(0),
                ),
                style: context.theme.typography.body.sm,
              ),
              FSlider(
                control: FSliderControl.managedDiscrete(
                  initial: FSliderValue(
                    max: ((display.miuiIslandLabelFontSize - 1) / 31).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                  onChange: (sv) => _updateDisplay(
                    display.copyWith(miuiIslandLabelFontSize: 1 + sv.max * 31),
                    debounce: true,
                  ),
                ),
                marks: [
                  for (var i = 0; i <= 31; i++) FSliderMark(value: i / 31),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.liveMiuiLabelOffsetXLabel(
                  display.miuiIslandLabelOffsetX.toStringAsFixed(1),
                ),
                style: context.theme.typography.body.sm,
              ),
              FSlider(
                control: FSliderControl.managedDiscrete(
                  initial: FSliderValue(
                    max:
                        ((display.miuiIslandLabelOffsetX.clamp(-2.0, 2.0) + 2) /
                                4)
                            .clamp(0.0, 1.0),
                  ),
                  onChange: (sv) => _updateDisplay(
                    display.copyWith(miuiIslandLabelOffsetX: -2 + sv.max * 4),
                    debounce: true,
                  ),
                ),
                marks: [
                  for (var i = 0; i <= 40; i++) FSliderMark(value: i / 40),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.liveMiuiLabelOffsetYLabel(
                  display.miuiIslandLabelOffsetY.toStringAsFixed(1),
                ),
                style: context.theme.typography.body.sm,
              ),
              FSlider(
                control: FSliderControl.managedDiscrete(
                  initial: FSliderValue(
                    max:
                        ((display.miuiIslandLabelOffsetY.clamp(-2.0, 2.0) + 2) /
                                4)
                            .clamp(0.0, 1.0),
                  ),
                  onChange: (sv) => _updateDisplay(
                    display.copyWith(miuiIslandLabelOffsetY: -2 + sv.max * 4),
                    debounce: true,
                  ),
                ),
                marks: [
                  for (var i = 0; i <= 40; i++) FSliderMark(value: i / 40),
                ],
              ),
              const SizedBox(height: 12),
              FSelect<MiuiIslandLabelFontWeight>(
                hint: l10n.liveMiuiLabelFontWeightLabel,
                items: {
                  for (final value in MiuiIslandLabelFontWeight.values)
                    value.label: value,
                },
                control: FSelectControl.lifted(
                  value: display.miuiIslandLabelFontWeight,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDisplay(
                      display.copyWith(miuiIslandLabelFontWeight: value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FSelect<MiuiIslandLabelRenderQuality>(
                hint: l10n.liveMiuiLabelRenderQualityLabel,
                items: {
                  for (final value in MiuiIslandLabelRenderQuality.values)
                    value.label: value,
                },
                control: FSelectControl.lifted(
                  value: display.miuiIslandLabelRenderQuality,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDisplay(
                      display.copyWith(miuiIslandLabelRenderQuality: value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
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
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      SettingsSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FSelect<MiuiIslandExpandedIconMode>(
              hint: l10n.liveMiuiExpandedIconLabel,
              items: {
                for (final value in MiuiIslandExpandedIconMode.values)
                  value.label: value,
              },
              control: FSelectControl.lifted(
                value: display.miuiIslandExpandedIconMode,
                onChange: (value) {
                  if (value == null) return;
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
              Row(
                children: [
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.secondary,
                      onPress: () => _pickExpandedIconImage(display),
                      prefix: const Icon(Icons.image_outlined),
                      child: Text(
                        display.miuiIslandExpandedIconPath == null
                            ? l10n.selectImageAction
                            : l10n.replaceImageAction,
                      ),
                    ),
                  ),
                  if (display.miuiIslandExpandedIconPath != null) ...[
                    const SizedBox(width: 12),
                    FButton.icon(
                      variant: FButtonVariant.outline,
                      onPress: () async {
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
                      child: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
              if (display.miuiIslandExpandedIconPath != null) ...[
                const SizedBox(height: 12),
                _ImagePreview(path: display.miuiIslandExpandedIconPath!),
              ],
            ],
          ],
        ),
      ),
    ];
    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(widget.title),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.forDuringEnd) ...[
              FTileGroup(
                label: Text(l10n.liveDisplayConfigModeTitle),
                description: Text(l10n.liveDisplayConfigModeSubtitle),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SettingSwitchTile(
                    title: Text(l10n.followBeforeClassDisplayTitle),
                    value: _draft.liveDuringEndFollowBeforeClass,
                    onChanged: (value) => _updateDraft(
                      _draft.copyWith(liveDuringEndFollowBeforeClass: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            IgnorePointer(
              ignoring: _followBeforeClass,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _followBeforeClass ? 0.5 : 1,
                child: Column(children: sectionCards),
              ),
            ),
          ],
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final result = await FilePicker.platform.pickFiles(
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
    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.liveKeepAliveTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FTileGroup(
              label: Text(l10n.liveKeepAliveOptionsTitle),
              description: Text(l10n.liveKeepAliveOptionsSubtitle),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SettingSwitchTile(
                  title: Text(l10n.hideFromRecentsTitle),
                  subtitle: Text(l10n.hideFromRecentsSubtitle),
                  value: _draft.liveHideFromRecents,
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final provider = context.read<TimetableProvider>();
                    final message = await provider.updateTimetableSettings(
                      _draft.copyWith(liveHideFromRecents: value),
                    );
                    if (!mounted) return;
                    if (message != null) {
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    }
                    setState(() => _draft = provider.settings);
                  },
                ),
                FTile(
                  prefix: Icon(
                    _enabled
                        ? Icons.check_circle_rounded
                        : Icons.accessibility_new_rounded,
                    color: _enabled
                        ? context.theme.colors.primary
                        : context.theme.colors.mutedForeground,
                  ),
                  title: Text(l10n.keepAliveServiceTitle),
                  subtitle: Text(
                    _enabled
                        ? l10n.keepAliveServiceEnabledSubtitle
                        : l10n.keepAliveServiceDisabledSubtitle,
                  ),
                  suffix: FButton(
                    variant: FButtonVariant.secondary,
                    onPress: _openSettings,
                    child: Text(l10n.goEnableAction),
                  ),
                  onPress: _openSettings,
                ),
              ],
            ),
          ],
        ),
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
