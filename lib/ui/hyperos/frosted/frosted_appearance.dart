import 'package:flutter/material.dart';

import '../../../models/header_blur_style.dart';
import '../../../models/liquid_glass_tuning.dart';
import '../../../models/progressive_blur_tuning.dart';
import '../../../models/soft_glass_tuning.dart';

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

  /// 柔光玻璃（Hyper-PiliPlus SoftGlass 风格）：雾面胶囊 + 双影 + 边缘
  /// 高光。与液态折射解耦——不依赖 RuntimeShader，Blur + 蒙层即可。
  softGlass,

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
    return FrostedGlassMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FrostedGlassMode.frosted,
    );
  }
}

/// 是否为「高级材质」档位（柔光玻璃 / 液态玻璃）。
///
/// 高级材质共享同一组「作用范围」开关（见
/// [LiquidGlassDegradation.familyFallsBackToSolid]），也才会驱动首页玻璃带与玻璃坞
/// 脱离基础模糊档。实体卡片与高斯模糊是基础材质，不受开关约束。
bool isAdvancedGlassMode(FrostedGlassMode? mode) =>
    mode == FrostedGlassMode.liquidGlass || mode == FrostedGlassMode.softGlass;

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
    this.softGlassTuning = SoftGlassTuning.defaults,
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
  /// 不跟随 [glassMode] 或「作用范围」开关——柔光/液态只作用弹窗、玻璃坞
  /// 等其他表面，顶栏选什么渲染什么。
  final String homeBandGlassMaterial;

  /// Glass surface rendering mode.
  final FrostedGlassMode glassMode;

  /// 液态玻璃参数（[glassMode] 为 [FrostedGlassMode.liquidGlass] 时生效）。
  /// 非空即用户调过的档；null = 出厂标准档（渲染期回落到
  /// [LiquidGlassTuning.defaults]，其折射旋钮与课程卡片液态档逐字段一致）。
  final LiquidGlassTuning? liquidGlassTuning;

  /// 柔光玻璃参数（[glassMode] 为 [FrostedGlassMode.softGlass] 时生效）。
  /// 非空缺省即默认档，柔光任何后端都能画，无需可空判空。
  final SoftGlassTuning softGlassTuning;

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
          softGlassTuning == other.softGlassTuning &&
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
    softGlassTuning,
    progressiveBlurTuning,
    liquidGlassDockEnabled,
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
