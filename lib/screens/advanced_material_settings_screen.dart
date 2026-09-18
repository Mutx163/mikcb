import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';

import '../models/header_blur_style.dart';
import '../models/liquid_glass_tuning.dart';
import '../models/progressive_blur_tuning.dart';
import '../models/soft_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../widgets/frosted_sheet_settings_preview.dart';

/// 高级材质精细参数（液态 / 柔光 / 渐进）：从外观主路径下沉，避免刷屏。
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
            // 液态 / 柔光参数各档各自有意义：液态调折射管线的七个旋钮
            // （折射位移 / 作用带宽度 / 边缘陡缓 / 高光强度 / 高光带宽 / 磨砂量 /
            // 底色深浅），柔光调雾面倍率与边缘高光；作用范围开关两组共用。
            //
            // 旋钮全部来自 `LiquidGlassTuning`：各表面拿不到自己的参数入口，
            // 这是「同一材质只有一种观感」的结构性保证。
            if (mode == FrostedGlassMode.liquidGlass) ...[
              HyperosSectionLabel(text: l10n.frostedSheetSectionTitle),
              Builder(
                builder: (context) {
                  final liquidTuning =
                      _draft.liquidGlassTuning ?? LiquidGlassTuning.defaults;
                  String num(double value, int digits) =>
                      value.toStringAsFixed(digits);
                  String pct(double value) => '${(value * 100).round()}%';
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
                          onOpenDemoSheet: () =>
                              showFrostedSheetSettingsDemo(context),
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
                      if (_draft.liquidGlassPreset ==
                          LiquidGlassPreset.custom) ...[
                        HyperosSliderTile(
                          title: l10n.liquidGlassRefractionLabel,
                          value: liquidTuning.refraction,
                          max: LiquidGlassTuning.maxRefraction,
                          divisions: 40,
                          valueLabel: num(liquidTuning.refraction, 1),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(refraction: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.liquidGlassRefractionBandLabel,
                          value: liquidTuning.refractionBand,
                          min: LiquidGlassTuning.minRefractionBand,
                          max: LiquidGlassTuning.maxRefractionBand,
                          divisions: 46,
                          valueLabel: num(liquidTuning.refractionBand, 1),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(refractionBand: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.liquidGlassRefractionEdgePowLabel,
                          value: liquidTuning.refractionEdgePow,
                          min: LiquidGlassTuning.minRefractionEdgePow,
                          max: LiquidGlassTuning.maxRefractionEdgePow,
                          divisions: 20,
                          valueLabel: num(liquidTuning.refractionEdgePow, 2),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(refractionEdgePow: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.liquidGlassRimStrengthLabel,
                          value: liquidTuning.rimStrength,
                          divisions: 20,
                          valueLabel: pct(liquidTuning.rimStrength),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(rimStrength: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.liquidGlassRimWidthLabel,
                          value: liquidTuning.rimWidth,
                          max: LiquidGlassTuning.maxRimWidth,
                          divisions: 24,
                          valueLabel: num(liquidTuning.rimWidth, 1),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(rimWidth: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.liquidGlassBlurSigmaLabel,
                          value: liquidTuning.blurSigma,
                          max: LiquidGlassTuning.maxBlurSigma,
                          divisions: 40,
                          valueLabel: num(liquidTuning.blurSigma, 0),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(blurSigma: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.liquidGlassTintLabel,
                          value: liquidTuning.tintAlpha,
                          divisions: 20,
                          valueLabel: pct(liquidTuning.tintAlpha),
                          onChanged: (value) => _updateLiquidTuning(
                            (t) => t.copyWith(tintAlpha: value),
                          ),
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
                  );
                },
              ),
            ],
            // 柔光玻璃：与液态同构的 预设 + 自定义参数。自研折射链路删除后
            // 只剩「雾面 / 底色 / 边缘高光」三项，直接作用到上游 OS4 玻璃材质。
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
                          progressiveBlurTuning:
                              _draft.progressiveBlurTuning ??
                              ProgressiveBlurTuning.defaults,
                          onOpenDemoSheet: () =>
                              showFrostedSheetSettingsDemo(context),
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
            // 渐进（渐变）模糊：顶栏玻璃带的 progressive 材质 / 子页顶栏的
            // inspire 风格共用这一套档位。它不是「高级材质」（任何后端都能画、
            // 不受作用范围开关约束），因此在作用范围段之外单独成段。
            if (_usesProgressiveBlur) ...[
              // 小标题上方补标准节间距：label 自带的是下方 8px，上方 0，
              // 紧跟上一张卡片时会贴死（其余页面的惯例是节前 HyperosSectionGap）。
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.headerBlurStyleInspire),
              Builder(
                builder: (context) {
                  final tuning =
                      _draft.progressiveBlurTuning ??
                      ProgressiveBlurTuning.defaults;
                  String num(double value, int digits) =>
                      value.toStringAsFixed(digits);
                  return HyperosListGroup(
                    children: [
                      HyperosSelectTile<ProgressiveBlurPreset>(
                        label: l10n.progressiveBlurPresetLabel,
                        items: {
                          for (final preset in ProgressiveBlurPreset.values)
                            progressiveBlurPresetLabel(l10n, preset): preset,
                        },
                        value: _draft.progressiveBlurPreset,
                        onChanged: (preset) {
                          if (preset == ProgressiveBlurPreset.custom) {
                            _updateDraft(
                              _draft.copyWith(
                                progressiveBlurPreset:
                                    ProgressiveBlurPreset.custom,
                              ),
                            );
                            return;
                          }
                          _updateDraft(
                            _draft.copyWith(
                              progressiveBlurPreset: preset,
                              progressiveBlurTuning: preset.recommendedTuning,
                            ),
                          );
                        },
                      ),
                      if (_draft.progressiveBlurPreset ==
                          ProgressiveBlurPreset.custom) ...[
                        HyperosSliderTile(
                          title: l10n.progressiveBlurSigmaLabel,
                          value: tuning.sigma,
                          max: ProgressiveBlurTuning.maxSigma,
                          divisions: 40,
                          valueLabel: num(tuning.sigma, 0),
                          onChanged: (value) => _updateProgressiveTuning(
                            (t) => t.copyWith(sigma: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.progressiveBlurExtentLabel,
                          value: tuning.extent,
                          min: ProgressiveBlurTuning.minExtent,
                          // 上限就是滑杆默认的 1：延伸 >1 会在带底留残留模糊，
                          // 与下方清晰内容硬切出一条横向边。
                          divisions: 24,
                          valueLabel: num(tuning.extent, 2),
                          onChanged: (value) => _updateProgressiveTuning(
                            (t) => t.copyWith(extent: value),
                          ),
                        ),
                        HyperosSliderTile(
                          title: l10n.progressiveBlurTintBottomLabel,
                          value: tuning.tintBottomScale,
                          max: ProgressiveBlurTuning.maxTintBottomScale,
                          divisions: 12,
                          valueLabel: num(tuning.tintBottomScale, 2),
                          onChanged: (value) => _updateProgressiveTuning(
                            (t) => t.copyWith(tintBottomScale: value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: HyperosButton(
                            label: l10n.progressiveBlurResetAction,
                            variant: HyperosButtonVariant.secondary,
                            expand: true,
                            onPressed: () {
                              _updateDraft(
                                _draft.copyWith(
                                  progressiveBlurPreset:
                                      ProgressiveBlurPreset.standard,
                                  progressiveBlurTuning:
                                      ProgressiveBlurTuning.defaults,
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
            const HyperosSectionGap(),
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
                // 「首页玻璃带」开关已下线（2026-09-12）：首页顶栏材质独立
                // 自由选择（外观与配色页「首页顶栏玻璃」五档），不再跟随全局。
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

  /// 当前草稿是否在用渐进（渐变）模糊：首页玻璃带选 progressive，或子页顶栏
  /// 走 inspire 风格。命中才在设置页露出档位段，避免给用不上的用户加噪音。
  bool get _usesProgressiveBlur =>
      _draft.homeBandGlassMaterial == 'progressive' ||
      _draft.subpageHeaderBlurStyle == HeaderBlurStyle.inspire;

  /// 渐进模糊滑杆统一写入口：任意滑杆拖动都落
  /// [ProgressiveBlurPreset.custom]，拖动防抖（与液态/柔光一致）。
  void _updateProgressiveTuning(
    ProgressiveBlurTuning Function(ProgressiveBlurTuning tuning) transform,
  ) {
    final base =
        _draft.progressiveBlurTuning ?? ProgressiveBlurTuning.defaults;
    _updateDraft(
      _draft.copyWith(
        progressiveBlurPreset: ProgressiveBlurPreset.custom,
        progressiveBlurTuning: transform(base),
      ),
      debounce: true,
    );
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

  /// 液态玻璃滑杆统一写入口：任意滑杆拖动都落
  /// [LiquidGlassPreset.custom]，拖动防抖（与柔光/渐进一致）。
  void _updateLiquidTuning(
    LiquidGlassTuning Function(LiquidGlassTuning tuning) transform,
  ) {
    final base = _draft.liquidGlassTuning ?? LiquidGlassTuning.defaults;
    _updateDraft(
      _draft.copyWith(
        liquidGlassPreset: LiquidGlassPreset.custom,
        liquidGlassTuning: transform(base),
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
