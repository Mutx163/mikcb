import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';

import '../models/liquid_glass_tuning.dart';
import '../models/soft_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../widgets/frosted_sheet_settings_preview.dart';

/// 高级材质精细参数（液态 / 柔光）：从外观主路径下沉，避免刷屏。
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
    final mode = _draft.frostedGlassMode;

    return FrostedAppearanceScope(
      appearance: _draft.frostedAppearance,
      child: HyperosSubpage(
        onBack: () => Navigator.pop(context),
        title: Text(l10n.advancedMaterialTitle),
        child: HyperosListView(
          children: [
            // 折射 / 雾面参数各档各自有意义：液态调折射管线，柔光调
            // 雾面倍率与折射透镜；作用范围开关两组共用。
            if (mode == FrostedGlassMode.liquidGlass) ...[
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
                      max: LiquidGlassTuning.maxThickness,
                      divisions: 40,
                      valueLabel: _draft.liquidGlassTuning!.thickness
                          .toStringAsFixed(0),
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(thickness: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassBlurLabel,
                      value: _draft.liquidGlassTuning!.blur,
                      max: LiquidGlassTuning.maxBlur,
                      divisions: 24,
                      valueLabel: _draft.liquidGlassTuning!.blur
                          .toStringAsFixed(0),
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(blur: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassTintLabel,
                      value: _draft.liquidGlassTuning!.tintAlpha,
                      max: LiquidGlassTuning.maxTintAlpha,
                      divisions: 55,
                      valueLabel:
                          '${(_draft.liquidGlassTuning!.tintAlpha * 100).round()}%',
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(tintAlpha: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassLightIntensityLabel,
                      value: _draft.liquidGlassTuning!.lightIntensity,
                      max: LiquidGlassTuning.maxLightIntensity,
                      divisions: 40,
                      valueLabel: _draft.liquidGlassTuning!.lightIntensity
                          .toStringAsFixed(2),
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(lightIntensity: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassAmbientStrengthLabel,
                      value: _draft.liquidGlassTuning!.ambientStrength,
                      divisions: 20,
                      valueLabel: _draft.liquidGlassTuning!.ambientStrength
                          .toStringAsFixed(2),
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(ambientStrength: value),
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
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(refractiveIndex: value),
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
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(saturation: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassChromaticAberrationLabel,
                      value: _draft.liquidGlassTuning!.chromaticAberration,
                      max: LiquidGlassTuning.maxChromaticAberration,
                      divisions: 24,
                      valueLabel: _draft.liquidGlassTuning!.chromaticAberration
                          .toStringAsFixed(3),
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(chromaticAberration: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassLightAngleLabel,
                      value: _draft.liquidGlassTuning!.lightAngleDegrees,
                      max: LiquidGlassTuning.maxLightAngleDegrees,
                      divisions: 72,
                      valueLabel:
                          '${_draft.liquidGlassTuning!.lightAngleDegrees.round()}°',
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(lightAngleDegrees: value),
                          ),
                          debounce: true,
                        );
                      },
                    ),
                    HyperosSliderTile(
                      title: l10n.liquidGlassVisibilityLabel,
                      value: _draft.liquidGlassTuning!.visibility,
                      divisions: 20,
                      valueLabel:
                          '${(_draft.liquidGlassTuning!.visibility * 100).round()}%',
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: LiquidGlassPreset.custom,
                            liquidGlassTuning: _draft.liquidGlassTuning!
                                .copyWith(visibility: value),
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
            ],
            // 柔光玻璃：与液态同构的 预设 + 自定义参数，雾面/底色按
            // 表面配方整体缩放（倍率），折射/色散为绝对 dp。
            if (mode == FrostedGlassMode.softGlass) ...[
              HyperosSectionLabel(text: l10n.frostedSheetSectionTitle),
              Builder(
                builder: (context) {
                  final softTuning =
                      _draft.softGlassTuning ?? SoftGlassTuning.defaults;
                  String pct(double value) =>
                      '${(value * 100).round()}%';
                  return HyperosListGroup(
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
                          softGlassTuning: softTuning,
                          onOpenDemoSheet: () =>
                              showFrostedSheetSettingsDemo(context),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          l10n.softGlassHint,
                          style: HyperosTypography.sectionDescription(context),
                        ),
                      ),
                      HyperosSelectTile<SoftGlassPreset>(
                        label: l10n.softGlassPresetLabel,
                        items: {
                          for (final preset in SoftGlassPreset.values)
                            softGlassPresetLabel(l10n, preset): preset,
                        },
                        value: _draft.softGlassPreset,
                        onChanged: (preset) {
                          if (preset == SoftGlassPreset.custom) {
                            _updateDraft(
                              _draft.copyWith(
                                softGlassPreset: SoftGlassPreset.custom,
                              ),
                            );
                            return;
                          }
                          _updateDraft(
                            _draft.copyWith(
                              softGlassPreset: preset,
                              softGlassTuning: preset.recommendedTuning,
                            ),
                          );
                        },
                      ),
                      if (_draft.softGlassPreset == SoftGlassPreset.custom) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            l10n.softGlassCustomExpandedTitle,
                            style: HyperosTypography.sectionDescription(context),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.softGlassBlurLabel,
                          value: softTuning.blurRadiusMultiplier,
                          max: SoftGlassTuning.maxBlurRadiusMultiplier,
                          divisions: 15,
                          valueLabel: pct(softTuning.blurRadiusMultiplier),
                          onChanged: (value) => _updateSoftTuning(
                            (t) => t.copyWith(blurRadiusMultiplier: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.softGlassTintLabel,
                          value: softTuning.tintAlphaMultiplier,
                          max: SoftGlassTuning.maxTintAlphaMultiplier,
                          divisions: 40,
                          valueLabel: pct(softTuning.tintAlphaMultiplier),
                          onChanged: (value) => _updateSoftTuning(
                            (t) => t.copyWith(tintAlphaMultiplier: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.softGlassRefractionLabel,
                          value: softTuning.refraction,
                          max: SoftGlassTuning.maxRefraction,
                          divisions: 30,
                          valueLabel: softTuning.refraction.toStringAsFixed(0),
                          onChanged: (value) => _updateSoftTuning(
                            (t) => t.copyWith(refraction: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.softGlassDepthLabel,
                          value: softTuning.depthEffect,
                          divisions: 20,
                          valueLabel: softTuning.depthEffect.toStringAsFixed(2),
                          onChanged: (value) => _updateSoftTuning(
                            (t) => t.copyWith(depthEffect: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.softGlassChromaticAberrationLabel,
                          value: softTuning.chromaticAberration,
                          max: SoftGlassTuning.maxChromaticAberration,
                          divisions: 30,
                          valueLabel: softTuning.chromaticAberration
                              .toStringAsFixed(1),
                          onChanged: (value) => _updateSoftTuning(
                            (t) => t.copyWith(chromaticAberration: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.softGlassEdgeHighlightLabel,
                          value: softTuning.edgeHighlight,
                          divisions: 20,
                          valueLabel: pct(softTuning.edgeHighlight),
                          onChanged: (value) => _updateSoftTuning(
                            (t) => t.copyWith(edgeHighlight: value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: HyperosButton(
                            label: l10n.softGlassResetAction,
                            variant: HyperosButtonVariant.secondary,
                            expand: true,
                            onPressed: () {
                              _updateDraft(
                                _draft.copyWith(
                                  softGlassPreset: SoftGlassPreset.standard,
                                  softGlassTuning: SoftGlassTuning.defaults,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            // 高级材质作用范围：逐表面家族开关。开 = 该表面用
            // 当前全局高级材质（柔光 / 液态）；关 = 该表面回落
            // **实体卡片**（不降级为高斯，见
            // [LiquidGlassDegradation.familyFallsBackToSolid]）。
            HyperosSectionLabel(text: l10n.liquidGlassScopeSectionTitle),
            HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  title: l10n.liquidGlassScopePopupTitle,
                  subtitle: l10n.liquidGlassScopePopupSubtitle,
                  value: _draft.liquidGlassPopupEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(liquidGlassPopupEnabled: value),
                    );
                  },
                ),
                HyperosSwitchTile(
                  title: l10n.liquidGlassScopeSelectSheetTitle,
                  subtitle: l10n.liquidGlassScopeSelectSheetSubtitle,
                  value: _draft.liquidGlassSelectSheetEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(liquidGlassSelectSheetEnabled: value),
                    );
                  },
                ),
                HyperosSwitchTile(
                  title: l10n.liquidGlassScopeSheetDialogTitle,
                  subtitle: l10n.liquidGlassScopeSheetDialogSubtitle,
                  value: _draft.liquidGlassSheetDialogEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(liquidGlassSheetDialogEnabled: value),
                    );
                  },
                ),
                HyperosSwitchTile(
                  title: l10n.liquidGlassScopeHomeChromeTitle,
                  subtitle: l10n.liquidGlassScopeHomeChromeSubtitle,
                  value: _draft.liquidGlassHomeChromeEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(liquidGlassHomeChromeEnabled: value),
                    );
                  },
                ),
                HyperosSwitchTile(
                  title: l10n.liquidGlassScopeDockTitle,
                  subtitle: l10n.liquidGlassScopeDockSubtitle,
                  value: _draft.liquidGlassDockEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(liquidGlassDockEnabled: value),
                    );
                  },
                ),
                HyperosSwitchTile(
                  title: l10n.liquidGlassScopePickerButtonsTitle,
                  subtitle: l10n.liquidGlassScopePickerButtonsSubtitle,
                  value: _draft.liquidGlassPickerButtonsEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(liquidGlassPickerButtonsEnabled: value),
                    );
                  },
                ),
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

  /// 柔光滑杆统一写入口：任意滑杆拖动都落 [SoftGlassPreset.custom]，
  /// 拖动防抖（与液态滑杆一致）。
  void _updateSoftTuning(
    SoftGlassTuning Function(SoftGlassTuning tuning) transform,
  ) {
    final base = _draft.softGlassTuning ?? SoftGlassTuning.defaults;
    _updateDraft(
      _draft.copyWith(
        softGlassPreset: SoftGlassPreset.custom,
        softGlassTuning: transform(base),
      ),
      debounce: true,
    );
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
