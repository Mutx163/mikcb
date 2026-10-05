import 'package:flutter/material.dart';

import '../../../models/course_glass_tuning.dart';
import '../../../models/liquid_glass_tuning.dart';

/// Default frosted-glass tuning (aligned with app timetable defaults).
const kDefaultFrostedBlurEnabled = true;
const kDefaultFrostedSheetBlurSigma = 15.0;
const kDefaultFrostedSheetTintAlpha = 0.70;
const kDefaultFrostedSheetBarrierAlpha = 0.20;

/// 首页顶栏玻璃带默认材质：液态玻璃。独立自由选择，不随全局玻璃模式。
///
/// 2026-09-20 起这一档只有「液态玻璃 / 实体」两个取值（见
/// `TimetableSettings.sanitizeHomeBandGlassMaterial`）：界面早就只给这两个选项，
/// 存量中间档在读取时一并归到液态，避免「界面显示液态、实际渲染渐进磨砂」。
const kDefaultHomeBandGlassMaterial = 'liquid';

/// 玻璃坞（含坞内圆钮）要不要走高级材质（「课表页面 → 玻璃 / 材质」里保留的唯一作用范围开关）。
///
/// 其余「作用范围」开关（下拉小弹窗 / 对话式全屏选择面板 / 底部弹窗与对话框 /
/// 壁纸选点按钮）已于 2026-09-19 整体删除：这些表面锁成「永远液态玻璃的标准档」
/// （见 `LiquidGlassRole.pinnedChrome`），开关存不存在都不影响出图，留着只是
/// 让用户以为改得动。坞跟随用户档位，故保留。
const kDefaultLiquidGlassDockEnabled = true;

// 2026-09-30：「高斯模糊」这一档退场，连枚举值一起删（`FrostedGlassMode` 本体
// 随之消失，见 `.agents/notes/implemented/simplification/
// 2026-09-30-retire-gaussian-material-tier.md`）。它承诺的「全局都是磨砂」从来
// 不成立：子页顶栏锁死渐进模糊、弹窗家族锁标准液态、课程卡片另有自己一档，
// 真正被它切换的只有玻璃坞与弹窗遮罩深浅 —— 而这两处液态档下也各有开关。
//
// 现在整机的玻璃材质只有一种（液态玻璃），用户选的是**要不要玻璃**：
// `GlassModeChoice` 的两档「实体卡片 / 液态玻璃」，实体卡片 = 模糊总开关关掉
// （[FrostedAppearance.blurEnabled]），不是第三种材质。

class FrostedAppearance {
  const FrostedAppearance({
    required this.sheetBlurSigma,
    required this.sheetTintAlpha,
    required this.sheetBarrierAlpha,
    this.blurEnabled = kDefaultFrostedBlurEnabled,
    this.homeBandGlassMaterial = kDefaultHomeBandGlassMaterial,
    this.liquidGlassTuning,
    this.liquidGlassTuningDark,
    this.linkLiquidGlassTuning = true,
    this.darkGlassBoostEnabled = true,
    this.courseCardGlassTuning,
    this.liquidGlassDockEnabled = kDefaultLiquidGlassDockEnabled,
  });

  static const defaults = FrostedAppearance(
    sheetBlurSigma: kDefaultFrostedSheetBlurSigma,
    sheetTintAlpha: kDefaultFrostedSheetTintAlpha,
    sheetBarrierAlpha: kDefaultFrostedSheetBarrierAlpha,
  );

  /// BackdropFilter sigma for frosted panels (logical pixels).
  final double sheetBlurSigma;

  /// Light-mode milky frosted overlay strength (0 = clear glass, higher = brighter).
  final double sheetTintAlpha;

  /// Modal barrier dimming behind frosted home sheets.
  final double sheetBarrierAlpha;

  /// Global backdrop blur master switch.
  final bool blurEnabled;

  /// 首页顶栏玻璃带材质，独立自由选择：`follow`（跟随模糊总开关）/
  /// `liquid` / `solid`（2026-09-30 收成三档，与外观编辑器里那三个选项逐字
  /// 一致，见 [kDefaultHomeBandGlassMaterial]）。
  ///
  /// 只被本字段自己那把轴决定，不受「玻璃坞作用范围」开关影响。
  final String homeBandGlassMaterial;

  /// 液态玻璃参数。非空即用户调过的档；null = 出厂标准档（渲染期回落到
  /// [LiquidGlassTuning.defaults]，其折射旋钮与课程卡片液态档逐字段一致）。
  ///
  /// **2026-09-21 起语义明确为「浅色档」**（存储 key 未变，存量零迁移）。
  final LiquidGlassTuning? liquidGlassTuning;

  /// 液态玻璃的**深色档**（null = 跟随浅色档，见 [linkLiquidGlassTuning]）。
  final LiquidGlassTuning? liquidGlassTuningDark;

  /// 深色档是否跟随浅色档。
  ///
  /// `true`（默认）时深色以 [liquidGlassTuning] 为形状、再套深色配方；
  /// `false` 时才真的用 [liquidGlassTuningDark]。
  final bool linkLiquidGlassTuning;

  /// 深色模式是否套用「变暗配方」（[LiquidGlassDarkRecipe.standard]）。
  ///
  /// 产品默认开；关掉即退回今天的行为（白底 + 深色收 15% = 配方表的
  /// [LiquidGlassDarkRecipe.legacy]），这也是本改动的回滚开关。
  /// **只作用于深色**：浅色永远走恒等配方，逐位不变。
  ///
  /// 2026-09-21 起**课程卡片也吃它**（见 `courseGlassStyleFor`）：配方是光照适配，
  /// 与「哪个表面」无关，漏给某一族表面就会重现「同一材质深浅两套观感」的翻版。
  final bool darkGlassBoostEnabled;

  /// 课程卡片自己那套液态玻璃参数（null = 出厂卡片档
  /// [CourseGlassTuning.courseCard]）。
  ///
  /// **刻意与 [liquidGlassTuning] 分开**：卡片与全局是两套独立配置，用户要的正是
  /// 「别处一个样、卡片另一个样」。两者共享的是解析入口与深浅配方，不是数值。
  final CourseGlassTuning? courseCardGlassTuning;

  /// 唯一保留的「作用范围」开关：玻璃坞导航（底部悬浮药丸与加课圆钮）。
  ///
  /// 弹窗家族那四个同族开关已随「小件永远锁标准档」删除——它们存不存在都不
  /// 改变出图（见 `LiquidGlassRole.pinnedChrome`），留着是死开关。
  final bool liquidGlassDockEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrostedAppearance &&
          blurEnabled == other.blurEnabled &&
          homeBandGlassMaterial == other.homeBandGlassMaterial &&
          sheetBlurSigma == other.sheetBlurSigma &&
          sheetTintAlpha == other.sheetTintAlpha &&
          sheetBarrierAlpha == other.sheetBarrierAlpha &&
          liquidGlassTuning == other.liquidGlassTuning &&
          liquidGlassTuningDark == other.liquidGlassTuningDark &&
          linkLiquidGlassTuning == other.linkLiquidGlassTuning &&
          darkGlassBoostEnabled == other.darkGlassBoostEnabled &&
          courseCardGlassTuning == other.courseCardGlassTuning &&
          liquidGlassDockEnabled == other.liquidGlassDockEnabled;

  @override
  int get hashCode => Object.hash(
    blurEnabled,
    homeBandGlassMaterial,
    sheetBlurSigma,
    sheetTintAlpha,
    sheetBarrierAlpha,
    liquidGlassTuning,
    liquidGlassTuningDark,
    linkLiquidGlassTuning,
    darkGlassBoostEnabled,
    courseCardGlassTuning,
  );
}

/// Provides [FrostedAppearance] to frosted HyperOS widgets.
class FrostedAppearanceScope extends InheritedWidget {
  const FrostedAppearanceScope({
    required this.appearance,
    required super.child,
    super.key,
  });

  final FrostedAppearance appearance;

  static FrostedAppearance of(BuildContext context) {
    return maybeOf(context)?.appearance ?? FrostedAppearance.defaults;
  }

  static FrostedAppearanceScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FrostedAppearanceScope>();
  }

  /// Reads the scope **without** registering an inherited dependency.
  ///
  /// For callers that sit high in the tree (e.g. the page shell) and only need
  /// the current value as a paint hint — a tracked read there would rebuild the
  /// whole open page every time the user changes an appearance setting.
  static FrostedAppearanceScope? maybeOfUntracked(BuildContext context) {
    return context.getInheritedWidgetOfExactType<FrostedAppearanceScope>();
  }

  @override
  bool updateShouldNotify(covariant FrostedAppearanceScope oldWidget) {
    return appearance != oldWidget.appearance;
  }
}
