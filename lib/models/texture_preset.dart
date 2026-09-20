import 'header_blur_style.dart';
import 'liquid_glass_tuning.dart';
import 'soft_glass_tuning.dart';
import 'timetable_settings.dart';
import '../ui/hyperos/frosted/frosted_appearance.dart' show FrostedGlassMode;

/// 「质感方案」预设：一键把一组材质轴写穿成推荐的搭配。
///
/// 用户 2026-09-12 拍板前的现状是 4 条调整路线 × 多个轴（全局玻璃模式、
/// 作用范围开关、子页顶栏风格、首页顶栏材质、卡片表面、各调参滑杆），
/// 想要某个整体观感要到 3 个页面逐项拨。预设是**纯增量层**：写穿既有字段、
/// 不锁定、不新增持久化字段——[texturePresetOf] 每次按「当前值 vs 预设声明
/// 字段集」派生显示，应用后用户改任何一项即回落「自定义」。
///
/// 边界（既有拍板，全部保留）：
/// - 首页顶栏材质与子页顶栏风格独立，预设只写初值不合并；
/// - 单一全局材质轴的结构不变（不恢复每表面独立材质，首页顶栏是唯一的例外，
///   2026-09-12 拍板）；
/// - 子页顶栏永不走液态；
/// - 不碰壁纸、字色等非材质字段。
///
/// 2026-09-19 起「作用范围」只剩**底栏**一个开关（弹窗家族锁标准档，四个
/// 开关已删），所以预设只在坞这一档上还写范围：全液态开坞、轻雾柔光关坞。
///
/// 2026-09-20 起首页顶栏材质口径收成**「液态 / 实体」两档**（与外观编辑器里
/// 那两个选项逐字一致，见 `TimetableSettings.sanitizeHomeBandGlassMaterial`），
/// 所以预设写穿的顶栏值只有这两个：中间三档（渐进/高斯/柔光）已归到液态。
enum TexturePreset {
  /// 经典磨砂——出厂默认档：全局高斯 + 现行默认作用范围 + 液态顶栏 +
  /// 实体卡。作用是「一键回家」。
  classicFrost,

  /// 全液态——全局液态 + 坞作用范围开 + 液态标准预设 + 高斯卡片。
  fullLiquid,

  /// 轻雾柔光——全局柔光 + 坞保持磨砂，柔光标准预设 + 液态顶栏 + 实体卡。
  softMist,

  /// 极简实体——模糊总开关关闭 + 实体卡片。低性能设备 / 护眼的最小态；
  /// 只声明这 3 个字段，作用范围等不可达轴不参与匹配。
  minimalSolid,
}

/// 把 [preset] 声明的字段集写穿到 [settings]，其余字段原样保留。
///
/// 每个预设只动它声明的轴：例如「极简实体」不碰作用范围开关（实体档下
/// 它们不可达，动了也看不见，反而会在切回高斯时带出意外状态）。
TimetableSettings applyTexturePreset(
  TimetableSettings settings,
  TexturePreset preset,
) => switch (preset) {
  TexturePreset.classicFrost => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.frosted,
    frostedSheetBlurSigma: TimetableSettings.defaultFrostedSheetBlurSigma,
    frostedSheetTintAlpha: TimetableSettings.defaultFrostedSheetTintAlpha,
    liquidGlassDockEnabled: TimetableSettings.defaultLiquidGlassDockEnabled,
    subpageHeaderBlurStyle: HeaderBlurStyle.inspire,
    homeBandGlassMaterial: TimetableSettings.defaultHomeBandGlassMaterial,
    courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
  ),
  TexturePreset.fullLiquid => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.liquidGlass,
    liquidGlassDockEnabled: true,
    liquidGlassPreset: LiquidGlassPreset.standard,
    liquidGlassTuning: LiquidGlassPreset.standard.recommendedTuning,
    homeBandGlassMaterial: 'liquid',
    courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
  ),
  TexturePreset.softMist => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.softGlass,
    liquidGlassDockEnabled: false,
    softGlassPreset: SoftGlassPreset.standard,
    softGlassTuning: SoftGlassPreset.standard.recommendedTuning,
    homeBandGlassMaterial: 'liquid',
    courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
  ),
  TexturePreset.minimalSolid => settings.copyWith(
    frostedBlurEnabled: false,
    frostedGlassMode: FrostedGlassMode.frosted,
    homeBandGlassMaterial: 'solid',
    courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
  ),
};

/// 当前设置命中的质感方案；任一声明字段被手动改过即返回 `null`
/// （UI 显示「自定义」）。
///
/// 只比对**该预设声明写穿的字段集**：比如「极简实体」只声明模糊总开关、
/// 玻璃模式、卡片表面三项，柔光/液态调参和作用范围开关不参与匹配——
/// 否则碰巧调过不可达开关的用户会永远显示「自定义」。
TexturePreset? texturePresetOf(TimetableSettings s) {
  final d = TimetableSettings.defaults();
  // 经典磨砂：全局高斯 + 出厂默认的全部基础磨砂轴。
  if (s.frostedBlurEnabled &&
      s.frostedGlassMode == FrostedGlassMode.frosted &&
      s.frostedSheetBlurSigma == d.frostedSheetBlurSigma &&
      s.frostedSheetTintAlpha == d.frostedSheetTintAlpha &&
      s.liquidGlassDockEnabled == d.liquidGlassDockEnabled &&
      s.subpageHeaderBlurStyle == HeaderBlurStyle.inspire &&
      s.homeBandGlassMaterial == TimetableSettings.defaultHomeBandGlassMaterial &&
      s.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid) {
    return TexturePreset.classicFrost;
  }
  // 全液态：全局液态 + 底栏范围开 + 顶栏液态 + 标准预设（调参须与标准
  // 一致）+ 高斯卡。
  if (s.frostedBlurEnabled &&
      s.frostedGlassMode == FrostedGlassMode.liquidGlass &&
      s.liquidGlassDockEnabled &&
      s.liquidGlassPreset == LiquidGlassPreset.standard &&
      s.liquidGlassTuning == LiquidGlassPreset.standard.recommendedTuning &&
      s.homeBandGlassMaterial == 'liquid' &&
      s.courseCardSurfaceStyle == CourseCardSurfaceStyle.gaussian) {
    return TexturePreset.fullLiquid;
  }
  // 轻雾柔光：全局柔光 + 底栏保持磨砂 + 顶栏液态 + 柔光标准预设 + 实体卡。
  // （顶栏 2026-09-20 起只有「液态 / 实体」两档，柔光档不再可选，故写液态。）
  if (s.frostedBlurEnabled &&
      s.frostedGlassMode == FrostedGlassMode.softGlass &&
      !s.liquidGlassDockEnabled &&
      s.softGlassPreset == SoftGlassPreset.standard &&
      s.softGlassTuning == SoftGlassPreset.standard.recommendedTuning &&
      s.homeBandGlassMaterial == 'liquid' &&
      s.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid) {
    return TexturePreset.softMist;
  }
  // 极简实体：模糊关 + 经典磨砂模式 + 顶栏实体 + 实体卡。
  if (!s.frostedBlurEnabled &&
      s.frostedGlassMode == FrostedGlassMode.frosted &&
      s.homeBandGlassMaterial == 'solid' &&
      s.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid) {
    return TexturePreset.minimalSolid;
  }
  return null;
}
