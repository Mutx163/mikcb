import 'package:flutter/material.dart';

import '../../../models/course_glass_tuning.dart';
import '../../../models/header_blur_style.dart';
import '../../../models/liquid_glass_tuning.dart';
import '../../../models/progressive_blur_tuning.dart';

/// Default frosted-glass tuning (aligned with app timetable defaults).
const kDefaultFrostedBlurEnabled = true;
const kDefaultFrostedSheetBlurSigma = 15.0;
const kDefaultFrostedSheetTintAlpha = 0.70;
const kDefaultFrostedSheetBarrierAlpha = 0.20;

/// 顶栏玻璃带的默认模糊材质：渐进模糊（inspire_blur）。
const kDefaultHeaderBlurStyle = HeaderBlurStyle.inspire;

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

/// User-tunable frosted glass appearance for home sheets and related surfaces.
/// Glass-surface rendering mode for frosted/Wallpaper-backgrounded sheets and cards.
enum FrostedGlassMode {
  /// 非液态磨砂的内部中性值：模型默认值、存量数据兜底（旧 translucent /
  /// gaussian 值经 [FrostedGlassModeX.fromValue] 归一，渲染完全等价）、
  /// 以及设置页「实体卡片」档的存储落点。渲染上与 [gaussian] 走同一条
  /// BackdropFilter + tint 链路，设置页不再作为独立档位暴露。
  frosted,

  /// 液态玻璃：实时背景上做圆角 SDF 边缘折射 + 受光边缘高光（见
  /// `shaders/glass_surface_refraction.frag` 与 `LiquidGlassSurface`）。
  /// 参数由 `LiquidGlassTuning` 统一提供，全 app 只此一套。
  liquidGlass,

  /// 设置页「高斯模糊」档的存储标记：渲染与 [frosted] 同一链路，仅用于
  /// 标记用户显式选择过该档。
  gaussian,
}

extension FrostedGlassModeX on FrostedGlassMode {
  String get value => name;

  static FrostedGlassMode fromValue(String? value) {
    // 存量迁移：折射档曾与液态档并列，现合并为一档（液态玻璃由本仓着色器
    // 实现）。老数据里写着 'refractionGlass' 的一律读作液态玻璃。
    if (value == 'refractionGlass') {
      return FrostedGlassMode.liquidGlass;
    }
    // 存量迁移（2026-09-22）：柔光档已从产品里退场（枚举值本身在当天晚些时候
    // 一并删除），老数据里写着 'softGlass' 的一律读作液态玻璃 —— 这正是外观
    // 编辑器当年对它的**显示口径**（归桶成液态），改成读入即迁移之后，界面说
    // 液态、渲染就真的画液态。
    // 迁移是懒迁移：不重写盘上的旧值，用户下次落盘时自然被写成 'liquidGlass'。
    if (value == 'softGlass') {
      return FrostedGlassMode.liquidGlass;
    }
    return FrostedGlassMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FrostedGlassMode.frosted,
    );
  }
}

/// 是否为「高级材质」档位（只有液态玻璃一种）。
///
/// 高级材质共享那组「作用范围」开关（见
/// [LiquidGlassDegradation.familyFallsBackToSolid]），也才会驱动首页玻璃带与玻璃坞
/// 脱离基础模糊档。实体卡片与高斯模糊是基础材质，不受开关约束。
bool isAdvancedGlassMode(FrostedGlassMode? mode) =>
    mode == FrostedGlassMode.liquidGlass;

class FrostedAppearance {
  const FrostedAppearance({
    required this.sheetBlurSigma,
    required this.sheetTintAlpha,
    required this.sheetBarrierAlpha,
    this.blurEnabled = kDefaultFrostedBlurEnabled,
    this.glassMode = FrostedGlassMode.frosted,
    this.subpageHeaderBlurStyle = kDefaultHeaderBlurStyle,
    this.homeBandGlassMaterial = kDefaultHomeBandGlassMaterial,
    this.liquidGlassTuning,
    this.liquidGlassTuningDark,
    this.linkLiquidGlassTuning = true,
    this.darkGlassBoostEnabled = true,
    this.courseCardGlassTuning,
    this.progressiveBlurTuning = ProgressiveBlurTuning.defaults,
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

  /// 子页顶栏（设置等 HyperosSubpage 页）的模糊材质风格（渐进 / 高斯）。
  ///
  /// 独立于首页玻璃带材质（[homeBandGlassMaterial]）：子页顶栏永不走高级
  /// 材质，此风格始终生效。
  final HeaderBlurStyle subpageHeaderBlurStyle;

  /// 首页顶栏玻璃带材质，独立自由选择（2026-09-12）：`liquid` / `solid`
  /// （2026-09-20 起收成两档，与外观编辑器里那两个选项逐字一致，见
  /// [kDefaultHomeBandGlassMaterial]）。
  ///
  /// 不跟随 [glassMode] 或「作用范围」开关——液态只作用弹窗、玻璃坞
  /// 等其他表面，顶栏选什么渲染什么。
  final String homeBandGlassMaterial;

  /// Glass surface rendering mode.
  final FrostedGlassMode glassMode;

  /// 液态玻璃参数（[glassMode] 为 [FrostedGlassMode.liquidGlass] 时生效）。
  /// 非空即用户调过的档；null = 出厂标准档（渲染期回落到
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

  /// 渐进（渐变）模糊参数——顶栏玻璃带走 `progressive` 材质 / 子页顶栏走
  /// `inspire` 风格时生效。非空缺省即标准档（与接入调参前的常量一致）。
  final ProgressiveBlurTuning progressiveBlurTuning;

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
          subpageHeaderBlurStyle == other.subpageHeaderBlurStyle &&
          homeBandGlassMaterial == other.homeBandGlassMaterial &&
          sheetBlurSigma == other.sheetBlurSigma &&
          sheetTintAlpha == other.sheetTintAlpha &&
          sheetBarrierAlpha == other.sheetBarrierAlpha &&
          glassMode == other.glassMode &&
          liquidGlassTuning == other.liquidGlassTuning &&
          liquidGlassTuningDark == other.liquidGlassTuningDark &&
          linkLiquidGlassTuning == other.linkLiquidGlassTuning &&
          darkGlassBoostEnabled == other.darkGlassBoostEnabled &&
          courseCardGlassTuning == other.courseCardGlassTuning &&
          progressiveBlurTuning == other.progressiveBlurTuning &&
          liquidGlassDockEnabled == other.liquidGlassDockEnabled;

  @override
  int get hashCode => Object.hash(
    blurEnabled,
    subpageHeaderBlurStyle,
    homeBandGlassMaterial,
    sheetBlurSigma,
    sheetTintAlpha,
    sheetBarrierAlpha,
    glassMode,
    liquidGlassTuning,
    liquidGlassTuningDark,
    linkLiquidGlassTuning,
    darkGlassBoostEnabled,
    courseCardGlassTuning,
    progressiveBlurTuning,
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

  @override
  bool updateShouldNotify(covariant FrostedAppearanceScope oldWidget) {
    return appearance != oldWidget.appearance;
  }
}
