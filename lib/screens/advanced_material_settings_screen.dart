import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';

import '../models/liquid_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../widgets/frosted_sheet_settings_preview.dart';

/// 液态玻璃精细参数：从外观主路径下沉，避免刷屏。
class AdvancedMaterialSettingsScreen extends StatefulWidget {
  const AdvancedMaterialSettingsScreen({super.key});

  @override
  State<AdvancedMaterialSettingsScreen> createState() =>
      _AdvancedMaterialSettingsScreenState();
}

class _AdvancedMaterialSettingsScreenState
    extends State<AdvancedMaterialSettingsScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
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
    final provider = context.watch<TimetableProvider>();

    return FrostedAppearanceScope(
      appearance: _draft.frostedAppearance,
      child: HyperosSubpage(
        onBack: () => Navigator.pop(context),
        title: Text(l10n.advancedMaterialTitle),
        child: HyperosListView(
          children: [
            HyperosSectionLabel(text: l10n.frostedSheetSectionTitle),
            HyperosListGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FrostedSheetSettingsPreview(
                    provider: provider,
                    settings: _draft,
                    week: provider.currentWeek,
                    blurSigma: _draft.frostedSheetBlurSigma,
                    tintAlpha: _draft.frostedSheetTintAlpha,
                    barrierAlpha: _draft.frostedSheetBarrierAlpha,
                    blurEnabled: _draft.frostedBlurEnabled,
                    glassMode: _draft.frostedGlassMode,
                    liquidGlassTuning: _draft.liquidGlassTuning,
                    onOpenDemoSheet: () =>
                        showFrostedSheetSettingsDemo(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.frostedLiquidGlassHint,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                ),
                HyperosSelectTile<LiquidGlassPreset>(
                  label: l10n.liquidGlassPresetLabel,
                  items: {
                    for (final preset in LiquidGlassPreset.values)
                      liquidGlassPresetLabel(l10n, preset): preset,
                  },
                  value: _draft.liquidGlassPreset,
                  onChanged: (preset) {
                    if (preset == LiquidGlassPreset.custom) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                        ),
                      );
                      return;
                    }
                    _updateDraft(
                      _draft.copyWith(
                        liquidGlassPreset: preset,
                        liquidGlassTuning: preset.recommendedTuning,
                      ),
                    );
                  },
                ),
if (_draft.liquidGlassPreset == LiquidGlassPreset.custom) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l10n.liquidGlassCustomExpandedTitle,
                      style: HyperosTypography.sectionDescription(context),
                    ),
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassThicknessLabel,
                    value: _draft.liquidGlassTuning!.thickness,
                    min: LiquidGlassTuning.minThickness,
                    max: LiquidGlassTuning.maxThickness,
                    divisions: 40,
                    valueLabel: _draft.liquidGlassTuning!.thickness
                        .toStringAsFixed(0),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            thickness: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassBlurLabel,
                    value: _draft.liquidGlassTuning!.blur,
                    min: LiquidGlassTuning.minBlur,
                    max: LiquidGlassTuning.maxBlur,
                    divisions: 24,
                    valueLabel: _draft.liquidGlassTuning!.blur.toStringAsFixed(
                      0,
                    ),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            blur: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassTintLabel,
                    value: _draft.liquidGlassTuning!.tintAlpha,
                    min: LiquidGlassTuning.minTintAlpha,
                    max: LiquidGlassTuning.maxTintAlpha,
                    divisions: 55,
                    valueLabel:
                        '${(_draft.liquidGlassTuning!.tintAlpha * 100).round()}%',
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            tintAlpha: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassLightIntensityLabel,
                    value: _draft.liquidGlassTuning!.lightIntensity,
                    min: LiquidGlassTuning.minLightIntensity,
                    max: LiquidGlassTuning.maxLightIntensity,
                    divisions: 40,
                    valueLabel: _draft.liquidGlassTuning!.lightIntensity
                        .toStringAsFixed(2),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            lightIntensity: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassAmbientStrengthLabel,
                    value: _draft.liquidGlassTuning!.ambientStrength,
                    min: LiquidGlassTuning.minAmbientStrength,
                    max: LiquidGlassTuning.maxAmbientStrength,
                    divisions: 20,
                    valueLabel: _draft.liquidGlassTuning!.ambientStrength
                        .toStringAsFixed(2),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            ambientStrength: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassRefractiveIndexLabel,
                    value: _draft.liquidGlassTuning!.refractiveIndex,
                    min: LiquidGlassTuning.minRefractiveIndex,
                    max: LiquidGlassTuning.maxRefractiveIndex,
                    divisions: 50,
                    valueLabel: _draft.liquidGlassTuning!.refractiveIndex
                        .toStringAsFixed(2),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            refractiveIndex: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassSaturationLabel,
                    value: _draft.liquidGlassTuning!.saturation,
                    min: LiquidGlassTuning.minSaturation,
                    max: LiquidGlassTuning.maxSaturation,
                    divisions: 30,
                    valueLabel: _draft.liquidGlassTuning!.saturation
                        .toStringAsFixed(2),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            saturation: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassChromaticAberrationLabel,
                    value: _draft.liquidGlassTuning!.chromaticAberration,
                    min: LiquidGlassTuning.minChromaticAberration,
                    max: LiquidGlassTuning.maxChromaticAberration,
                    divisions: 24,
                    valueLabel: _draft.liquidGlassTuning!.chromaticAberration
                        .toStringAsFixed(3),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            chromaticAberration: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassLightAngleLabel,
                    value: _draft.liquidGlassTuning!.lightAngleDegrees,
                    min: LiquidGlassTuning.minLightAngleDegrees,
                    max: LiquidGlassTuning.maxLightAngleDegrees,
                    divisions: 72,
                    valueLabel:
                        '${_draft.liquidGlassTuning!.lightAngleDegrees.round()}°',
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            lightAngleDegrees: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  HyperosSliderTile(
                    title: l10n.liquidGlassVisibilityLabel,
                    value: _draft.liquidGlassTuning!.visibility,
                    min: LiquidGlassTuning.minVisibility,
                    max: LiquidGlassTuning.maxVisibility,
                    divisions: 20,
                    valueLabel:
                        '${(_draft.liquidGlassTuning!.visibility * 100).round()}%',
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          liquidGlassPreset: LiquidGlassPreset.custom,
                          liquidGlassTuning: _draft.liquidGlassTuning!.copyWith(
                            visibility: value,
                          ),
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: HyperosButton(
                      label: l10n.liquidGlassResetAction,
                      variant: HyperosButtonVariant.secondary,
                      expand: true,
                      onPressed: () {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.standard,
                            liquidGlassTuning: LiquidGlassTuning.defaults,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            const HyperosSectionGap(),
          ],
        ),
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    final provider = _timetableProvider;
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      setState(() {
        _draft = provider.settings;
      });
    }
  }
}
