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
            // 底色深浅），柔光调雾面倍率与边缘高光；作用范围段（只剩底栏一个）共用。
            //
            // 旋钮全部来自 `LiquidGlassTuning`：各表面拿不到自己的参数入口，
            // 这是「同一材质只有一种观感」的结构性保证。
            if (mode == FrostedGlassMode.liquidGlass) ...[
              HyperosSectionLabel(text: l10n.frostedSheetSectionTitle),
              Builder(
                builder: (context) {
                  final liquidTuning =
                      _draft.liquidGlassTuning ?? LiquidGlassTuning.defaults;
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
                          liquidGlassTuningDark: _draft.liquidGlassTuningDark,
                          linkLiquidGlassTuning: _draft.linkLiquidGlassTuning,
                          darkGlassBoostEnabled: _draft.darkGlassBoostEnabled,
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
                        // 浅色档的八根旋钮（与深色档共用同一份渲染）。
                        ..._liquidSliderTiles(
                          l10n,
                          tuning: liquidTuning,
                          onUpdate: _updateLiquidTuning,
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
              const SizedBox(height: 8),
              // ── 浅/深成对（2026-09-21）。设计见
              // `.agents/notes/proposed/architecture/2026-09-21-liquid-glass-light-dark-pair.md`
              // 两个开关都在**恒常**区（不进 `custom` 门内）：配方作用在预设档的
              // 旋钮上照样成立，只有「调深色档」才需要自定义档。
              HyperosListGroup(
                children: [
                  HyperosSwitchTile(
                    title: l10n.liquidGlassDarkBoostLabel,
                    subtitle: l10n.liquidGlassDarkBoostSubtitle,
                    value: _draft.darkGlassBoostEnabled,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(darkGlassBoostEnabled: value),
                      );
                    },
                  ),
                  HyperosSwitchTile(
                    // 开关语义是「独立」，而字段存的是「是否跟随」，所以取反。
                    title: l10n.liquidGlassDarkIndependentLabel,
                    subtitle: l10n.liquidGlassDarkIndependentSubtitle,
                    value: !_draft.linkLiquidGlassTuning,
                    onChanged: (independent) {
                      _updateDraft(
                        _draft.copyWith(
                          linkLiquidGlassTuning: !independent,
                          // 第一次打开、且从没设过深色档 ⇒ 以浅色档为起点。
                          // 配方照旧套在「选中的那一档」上，所以这一按
                          // **不会让画面跳**（跳了就是这里写错了）。
                          liquidGlassTuningDark: independent
                              ? (_draft.liquidGlassTuningDark ??
                                    _draft.liquidGlassTuning ??
                                    LiquidGlassTuning.defaults)
                              : _draft.liquidGlassTuningDark,
                        ),
                      );
                    },
                  ),
                ],
              ),
              // 深色档的八根旋钮：与浅色档同构、共用同一个渲染函数
              // （[_liquidSliderTiles]）。只在「自定义 + 深色独立」时出现 ——
              // 预设档下旋钮本就不可调，列出来只会误导。
              if (_draft.liquidGlassPreset == LiquidGlassPreset.custom &&
                  !_draft.linkLiquidGlassTuning) ...[
                const SizedBox(height: 12),
                HyperosListGroup(
                  children: _liquidSliderTiles(
                    l10n,
                    tuning: _draft.liquidGlassTuningDark ??
                        _draft.liquidGlassTuning ??
                        LiquidGlassTuning.defaults,
                    onUpdate: _updateDarkTuning,
                  ),
                ),
              ],
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
                          liquidGlassTuningDark: _draft.liquidGlassTuningDark,
                          linkLiquidGlassTuning: _draft.linkLiquidGlassTuning,
                          darkGlassBoostEnabled: _draft.darkGlassBoostEnabled,
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
            // 高级材质作用范围：**只剩底栏**。弹窗家族（下拉小弹窗 / 对话式
            // 全屏选择面板 / 底部弹窗与对话框 / 壁纸选点按钮）自 2026-09-19 起
            // 锁成「永远液态玻璃的标准档」，开关存不存在都不改变出图，四个
            // 开关与字段已整体删除（用户口径：「不允许用户调整这些的材质」）。
            // 这里保留的这一个：开 = 坞用当前全局高级材质（柔光 / 液态）；
            // 关 = 坞回落**实体**（不降级为高斯，见
            // [LiquidGlassDegradation.familyFallsBackToSolid]）。
            const HyperosSectionGap(),
            HyperosSectionLabel(text: l10n.liquidGlassScopeSectionTitle),
            HyperosListGroup(
              children: [
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

  /// 当前草稿是否在用渐进（渐变）模糊：子页顶栏走 inspire 风格。
  ///
  /// 首页玻璃带 2026-09-20 起只有「液态 / 实体」两档（见
  /// `TimetableSettings.sanitizeHomeBandGlassMaterial`），顶栏不再有渐进档，
  /// 所以判据只剩子页顶栏这一条。命中才在设置页露出档位段，避免给用不上的
  /// 用户加噪音。
  bool get _usesProgressiveBlur =>
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

  /// 深色档的滑杆落地口。取值回落链与面板里读的那条一致
  /// （`深色档 ?? 浅色档 ?? 默认`），否则拖杆会从另一档的初值开始跳。
  void _updateDarkTuning(
    LiquidGlassTuning Function(LiquidGlassTuning tuning) transform,
  ) {
    final base = _draft.liquidGlassTuningDark ??
        _draft.liquidGlassTuning ??
        LiquidGlassTuning.defaults;
    _updateDraft(
      _draft.copyWith(
        liquidGlassPreset: LiquidGlassPreset.custom,
        liquidGlassTuningDark: transform(base),
      ),
      debounce: true,
    );
  }

  String _tuningNum(double value, int digits) => value.toStringAsFixed(digits);
  String _tuningPct(double value) => '${(value * 100).round()}%';

  /// 液态玻璃的八根滑杆。**浅色档与深色档共用这一份** —— 两套各写一遍迟早会漂，
  /// 而「同一材质两种观感」正是这个仓库反复吃亏的那类病。
  List<Widget> _liquidSliderTiles(
    AppLocalizations l10n, {
    required LiquidGlassTuning tuning,
    required void Function(LiquidGlassTuning Function(LiquidGlassTuning)) onUpdate,
  }) => [
      HyperosSliderTile(
        title: l10n.liquidGlassRefractionLabel,
        value: tuning.refraction,
        max: LiquidGlassTuning.maxRefraction,
        divisions: 40,
        valueLabel: _tuningNum(tuning.refraction, 1),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(refraction: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassRefractionBandLabel,
        value: tuning.refractionBand,
        min: LiquidGlassTuning.minRefractionBand,
        max: LiquidGlassTuning.maxRefractionBand,
        divisions: 46,
        valueLabel: _tuningNum(tuning.refractionBand, 1),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(refractionBand: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassRefractionEdgePowLabel,
        value: tuning.refractionEdgePow,
        min: LiquidGlassTuning.minRefractionEdgePow,
        max: LiquidGlassTuning.maxRefractionEdgePow,
        divisions: 20,
        valueLabel: _tuningNum(tuning.refractionEdgePow, 2),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(refractionEdgePow: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassDispersionLabel,
        value: tuning.dispersion,
        divisions: 20,
        valueLabel: _tuningPct(tuning.dispersion),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(dispersion: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassRimStrengthLabel,
        value: tuning.rimStrength,
        divisions: 20,
        valueLabel: _tuningPct(tuning.rimStrength),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(rimStrength: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassRimWidthLabel,
        value: tuning.rimWidth,
        max: LiquidGlassTuning.maxRimWidth,
        // 步长 0.1（3 / 30）：细线口径的取值都在 0.6~1.1 之间，
        // 步长 0.5 会连默认值 0.8 都落不到格点上。
        divisions: 30,
        valueLabel: _tuningNum(tuning.rimWidth, 1),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(rimWidth: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassBlurSigmaLabel,
        value: tuning.blurSigma,
        max: LiquidGlassTuning.maxBlurSigma,
        divisions: 40,
        valueLabel: _tuningNum(tuning.blurSigma, 0),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(blurSigma: value),
        ),
      ),
      HyperosSliderTile(
        title: l10n.liquidGlassTintLabel,
        value: tuning.tintAlpha,
        divisions: 20,
        valueLabel: _tuningPct(tuning.tintAlpha),
        onChanged: (value) => onUpdate(
          (t) => t.copyWith(tintAlpha: value),
        ),
      ),
  ];

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
