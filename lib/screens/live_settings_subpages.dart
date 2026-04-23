import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../utils/hex_color.dart';

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

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveReminderTimingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: l10n.liveReminderSwitchesTitle,
            subtitle: l10n.liveReminderSwitchesSubtitle,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.duringClassReminderTitle),
                  subtitle: Text(l10n.duringClassReminderSubtitle),
                  value: _draft.liveEnableDuringClass ||
                      _draft.liveEnableBeforeEnd,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(
                      liveEnableDuringClass: value,
                      liveEnableBeforeEnd: value,
                    ),
                  ),
                ),
                if (_draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.liveClassReminderLeadTitle,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildLiveClassReminderLeadSummary(l10n, _draft),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _draft.liveClassReminderStartMinutes,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: l10n.liveClassReminderLeadTitle,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                l10n.liveClassReminderLeadOptionImmediate,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 5,
                              child: Text(
                                l10n.liveClassReminderLeadOptionMinutes(5),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text(
                                l10n.liveClassReminderLeadOptionMinutes(10),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text(
                                l10n.liveClassReminderLeadOptionMinutes(15),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 20,
                              child: Text(
                                l10n.liveClassReminderLeadOptionMinutes(20),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text(
                                l10n.liveClassReminderLeadOptionMinutes(30),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            _updateDraft(
                              _draft.copyWith(
                                liveClassReminderStartMinutes: value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.liveDisplayModeTitle,
            subtitle: l10n.liveDisplayModeSubtitle,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.enableIslandDisplayTitle),
                  subtitle: Text(l10n.enableIslandDisplaySubtitle),
                  value: _draft.livePromoteDuringClass,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(livePromoteDuringClass: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.liveTimeThresholdTitle,
            subtitle: l10n.liveTimeThresholdSubtitle,
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _draft.liveShowBeforeClassMinutes,
                  decoration: InputDecoration(
                    labelText: l10n.beforeClassPopupLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: _beforeClassMinutesOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(l10n.beforeClassMinutesOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(liveShowBeforeClassMinutes: value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _draft.liveEndSecondsCountdownThreshold,
                  decoration: InputDecoration(
                    labelText: l10n.beforeEndSecondsLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: _endSecondsOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(l10n.beforeEndSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(
                        liveEndSecondsCountdownThreshold: value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.timeCorrectionLabel(timeCorrectionText),
                ),
                Slider(
                  value: _draft.liveTimeCorrectionSeconds
                      .toDouble()
                      .clamp(_timeCorrectionMin, _timeCorrectionMax),
                  min: _timeCorrectionMin,
                  max: _timeCorrectionMax,
                  divisions: (_timeCorrectionMax - _timeCorrectionMin).toInt(),
                  label: timeCorrectionText,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(
                      liveTimeCorrectionSeconds: value.round(),
                    ),
                    debounce: true,
                  ),
                ),
                Text(
                  l10n.timeCorrectionHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LiveDuringClassTimeDisplayMode>(
                  initialValue: _draft.liveDuringEndTimeDisplayMode,
                  decoration: InputDecoration(
                    labelText: l10n.duringEndTimeDisplayLabel,
                    helperText: l10n.duringEndTimeDisplayHelp,
                    border: OutlineInputBorder(),
                  ),
                  items: LiveDuringClassTimeDisplayMode.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(liveDuringEndTimeDisplayMode: value),
                    );
                  },
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
      _SectionCard(
        title: l10n.liveDisplayContentTitle,
        subtitle: l10n.liveDisplayContentSubtitle,
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showCourseNameTitle),
              value: display.showCourseName,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showCourseName: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.preferShortNameTitle),
              subtitle: Text(l10n.preferShortNameSubtitle),
              value: display.useShortName,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(useShortName: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showLocationTitle),
              value: display.showLocation,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showLocation: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showCountdownTitle),
              value: display.showCountdown,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showCountdown: value)),
            ),
            if (display.showCountdown) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<LiveCountdownTextStyle>(
                initialValue: display.countdownTextStyle,
                decoration: InputDecoration(
                  labelText: l10n.countdownFormatLabel,
                  helperText: l10n.countdownFormatHelp,
                  border: OutlineInputBorder(),
                ),
                items: LiveCountdownTextStyle.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(countdownTextStyle: value),
                  );
                },
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showStageTextTitle),
              subtitle: Text(l10n.showStageTextSubtitle),
              value: display.showStageText,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showStageText: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.hidePrefixTextTitle),
              subtitle: Text(l10n.hidePrefixTextSubtitle),
              value: display.hidePrefixText,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(hidePrefixText: value)),
            ),
          ],
        ),
      ),
      if (!widget.forDuringEnd) ...[
        const SizedBox(height: 16),
        _SectionCard(
          title: l10n.beforeClassQuickActionTitle,
          subtitle: l10n.beforeClassQuickActionSubtitle,
          child: DropdownButtonFormField<LiveBeforeClassQuickAction>(
            initialValue: _draft.liveBeforeClassQuickAction,
            decoration: InputDecoration(
              labelText: l10n.beforeClassQuickActionTitle,
              border: OutlineInputBorder(),
            ),
            items: LiveBeforeClassQuickAction.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _updateDraft(
                _draft.copyWith(liveBeforeClassQuickAction: value),
              );
            },
          ),
        ),
      ],
      const SizedBox(height: 16),
      _SectionCard(
        title: l10n.liveIslandVisualTitle,
        subtitle: l10n.liveIslandVisualSubtitle,
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.liveMiuiLabelImageTitle),
              subtitle: Text(l10n.liveMiuiLabelImageSubtitle),
              value: display.enableMiuiIslandLabelImage,
              onChanged: (value) => _updateDisplay(
                display.copyWith(enableMiuiIslandLabelImage: value),
              ),
            ),
            if (display.enableMiuiIslandLabelImage) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelContent>(
                initialValue: display.miuiIslandLabelContent,
                decoration: InputDecoration(
                  labelText: l10n.liveMiuiLabelContentLabel,
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelContent.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(miuiIslandLabelContent: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelStyle>(
                initialValue: display.miuiIslandLabelStyle,
                decoration: InputDecoration(
                  labelText: l10n.liveMiuiLabelStyleLabel,
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelStyle.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(miuiIslandLabelStyle: value),
                  );
                },
              ),
              if (display.miuiIslandLabelStyle ==
                  MiuiIslandLabelStyle.iconAndText) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.liveMiuiLabelLogoTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.liveMiuiLabelLogoSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _pickLabelLogoImage(display),
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          display.miuiIslandLabelLogoPath == null
                              ? l10n.selectImageAction
                              : l10n.replaceImageAction,
                        ),
                      ),
                    ),
                    if (display.miuiIslandLabelLogoPath != null) ...[
                      const SizedBox(width: 12),
                      IconButton.outlined(
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
                        icon: const Icon(Icons.delete_outline),
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
                      display.miuiIslandLabelLogoCornerRadius
                          .toStringAsFixed(0),
                    ),
                  ),
                  Slider(
                    value: display.miuiIslandLabelLogoCornerRadius.clamp(
                      0.0,
                      12.0,
                    ),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    label: display.miuiIslandLabelLogoCornerRadius
                        .toStringAsFixed(0),
                    onChanged: (value) => _updateDisplay(
                      display.copyWith(
                        miuiIslandLabelLogoCornerRadius: value,
                      ),
                      debounce: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.liveMiuiLabelFontSizeLabel(
                  display.miuiIslandLabelFontSize.toStringAsFixed(0),
                ),
              ),
              Slider(
                value: display.miuiIslandLabelFontSize,
                min: 1,
                max: 32,
                divisions: 31,
                label: display.miuiIslandLabelFontSize.toStringAsFixed(0),
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelFontSize: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.liveMiuiLabelOffsetXLabel(
                  display.miuiIslandLabelOffsetX.toStringAsFixed(1),
                ),
              ),
              Slider(
                value: display.miuiIslandLabelOffsetX.clamp(-2.0, 2.0),
                min: -2,
                max: 2,
                divisions: 40,
                label: display.miuiIslandLabelOffsetX.toStringAsFixed(1),
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelOffsetX: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.liveMiuiLabelOffsetYLabel(
                  display.miuiIslandLabelOffsetY.toStringAsFixed(1),
                ),
              ),
              Slider(
                value: display.miuiIslandLabelOffsetY.clamp(-2.0, 2.0),
                min: -2,
                max: 2,
                divisions: 40,
                label: display.miuiIslandLabelOffsetY.toStringAsFixed(1),
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelOffsetY: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelFontWeight>(
                initialValue: display.miuiIslandLabelFontWeight,
                decoration: InputDecoration(
                  labelText: l10n.liveMiuiLabelFontWeightLabel,
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelFontWeight.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(miuiIslandLabelFontWeight: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelRenderQuality>(
                initialValue: display.miuiIslandLabelRenderQuality,
                decoration: InputDecoration(
                  labelText: l10n.liveMiuiLabelRenderQualityLabel,
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelRenderQuality.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(
                      miuiIslandLabelRenderQuality: value,
                    ),
                  );
                },
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
                          display.copyWith(
                            miuiIslandLabelFontColor: color,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<MiuiIslandExpandedIconMode>(
              initialValue: display.miuiIslandExpandedIconMode,
              decoration: InputDecoration(
                labelText: l10n.liveMiuiExpandedIconLabel,
                border: OutlineInputBorder(),
              ),
              items: MiuiIslandExpandedIconMode.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ))
                  .toList(),
              onChanged: (value) {
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
            if (display.miuiIslandExpandedIconMode ==
                MiuiIslandExpandedIconMode.customImage) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _pickExpandedIconImage(display),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        display.miuiIslandExpandedIconPath == null
                            ? l10n.selectImageAction
                            : l10n.replaceImageAction,
                      ),
                    ),
                  ),
                  if (display.miuiIslandExpandedIconPath != null) ...[
                    const SizedBox(width: 12),
                    IconButton.outlined(
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
                      icon: const Icon(Icons.delete_outline),
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.forDuringEnd) ...[
            _SectionCard(
              title: l10n.liveDisplayConfigModeTitle,
              subtitle: l10n.liveDisplayConfigModeSubtitle,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.followBeforeClassDisplayTitle),
                value: _draft.liveDuringEndFollowBeforeClass,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveDuringEndFollowBeforeClass: value),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
    final display = widget.forDuringEnd
        ? next.duringEndDisplaySettings
        : next.beforeClassDisplaySettings;
    if (display.miuiIslandExpandedIconMode ==
            MiuiIslandExpandedIconMode.customImage &&
        (display.miuiIslandExpandedIconPath == null ||
            display.miuiIslandExpandedIconPath!.isEmpty)) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
    _updateDisplay(
      display.copyWith(
        miuiIslandLabelLogoPath: targetPath,
      ),
    );
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
    final bytes = file.bytes ??
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
    final preservedAbsolutePath =
        preservePath == null ? null : File(preservePath).absolute.path;
    await for (final entity in targetDir.list()) {
      if (entity is! File) {
        continue;
      }
      final fileName =
          entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
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
    extends State<LiveKeepAliveSettingsScreen> with WidgetsBindingObserver {
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveKeepAliveTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: l10n.liveKeepAliveOptionsTitle,
            subtitle: l10n.liveKeepAliveOptionsSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _enabled
                        ? Icons.check_circle_rounded
                        : Icons.accessibility_new_rounded,
                    color: _enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.keepAliveServiceTitle),
                  subtitle: Text(
                    _enabled
                        ? l10n.keepAliveServiceEnabledSubtitle
                        : l10n.keepAliveServiceDisabledSubtitle,
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => _openSettings(),
                    child: Text(l10n.goEnableAction),
                  ),
                ),
              ],
            ),
          ),
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

  const _ImagePreview({
    required this.path,
    this.imageCornerRadius = 12,
  });

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
                ? Image.file(file, width: 56, height: 56, fit: BoxFit.cover)
                : Container(
                    width: 56,
                    height: 56,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
              style: Theme.of(context).textTheme.bodySmall,
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

