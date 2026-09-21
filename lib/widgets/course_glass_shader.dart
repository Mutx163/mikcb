import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import '../models/course_glass_tuning.dart';
import '../ui/hyperos/frosted/frosted_appearance.dart';
import 'glass_shader_program.dart';

/// 课程卡片「液态玻璃」档的片元程序。
///
/// 加载/预热/降级逻辑全在 [GlassShaderProgram]（与全局折射表面共用同一套），
/// 这里只钉住资产键与日志名。
///
/// 加载失败时保持 [isLoaded] 为 false，卡片按「高斯磨砂」外观绘制 —— 见
/// `CourseSurface._buildRefraction` 的降级分支，绝不出现破相。
class CourseCardGlassShader extends GlassShaderProgram {
  CourseCardGlassShader._()
    : super(
        assetKey: 'shaders/course_card_glass.frag',
        debugLabel: 'CourseCardGlassShader',
      );

  static final CourseCardGlassShader instance = CourseCardGlassShader._();
}

/// 一张卡片液态玻璃的绘制参数。
///
/// 这里刻意只有纯数据、不持有 `FragmentShader`：着色器实例是**可变 uniform 的
/// 载体**，必须由绘制对象自己创建与释放（见 `_RenderPreblurredFill`），
/// 否则一个 [StatelessWidget] 每次 build 都会新建一个实例并泄漏。
@immutable
class CourseGlassStyle {
  const CourseGlassStyle({
    required this.borderRadius,
    required this.tint,
    this.refraction = CourseGlassTuning.defaultRefraction,
    this.refractionBand = CourseGlassTuning.defaultRefractionBand,
    this.refractionEdgePow = CourseGlassTuning.defaultRefractionEdgePow,
    this.dispersion = CourseGlassTuning.defaultDispersion,
    this.rimStrength = CourseGlassTuning.defaultRimStrength,
    this.rimWidth = CourseGlassTuning.defaultRimWidth,
    this.rimColor = const Color(0xFFFFFFFF),
  });

  /// 卡片圆角，必须与外面 [ClipRRect] 用的一致：着色器拿它算 SDF 遮罩，
  /// 对不上会出现「圆角被裁掉了但玻璃边缘还是直角」。
  final double borderRadius;

  /// 染色（直通 alpha）。已含 conflict / holiday 的 opacityScale。
  final Color tint;

  /// 边缘处的最大折射位移（逻辑 px）。
  final double refraction;

  /// 折射作用带宽度（逻辑 px）。
  final double refractionBand;

  /// 位移沿边缘上升的陡缓，越大越集中在最外圈。
  final double refractionEdgePow;

  /// 色散强度（0–1）：折射带内红/蓝采样点沿折射方向再错开 `位移 × 本值`
  /// （绿不动），读作玻璃边缘的彩虹镶边。0 = 关（走单采样，与加色散前逐像素一致）。
  ///
  /// 与全局那份 `glass_surface_refraction.frag` 同口径：都在作用带内多两次采样，
  /// 带外（`push == 0`）恒走单采样，所以整卡成本不变。
  final double dispersion;

  /// 边缘高光强度（0–1）。**一圈均匀**（四角与四条直边一样亮）：着色器不看法线
  /// 朝向、也不按边界曲率收角 —— 卡片没有贯屏长直边，收角只会剩四个角上的白钩
  /// （2026-09-20 真机口径，实算与理由见 `shaders/course_card_glass.frag` 文件头）。
  final double rimStrength;

  /// 边缘高光带宽（逻辑 px）。
  final double rimWidth;

  /// 边缘高光颜色。
  final Color rimColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseGlassStyle &&
          other.borderRadius == borderRadius &&
          other.tint == tint &&
          other.refraction == refraction &&
          other.refractionBand == refractionBand &&
          other.refractionEdgePow == refractionEdgePow &&
          other.dispersion == dispersion &&
          other.rimStrength == rimStrength &&
          other.rimWidth == rimWidth &&
          other.rimColor == rimColor;

  @override
  int get hashCode => Object.hash(
    borderRadius,
    tint,
    refraction,
    refractionBand,
    refractionEdgePow,
    dispersion,
    rimStrength,
    rimWidth,
    rimColor,
  );
}

/// 卡片染色底的不透明度下限。
///
/// 冲突 / 放假的自定义压暗（`CourseSurface.opacityScale`）可以把底色压得很低，
/// 但压到 0 会让卡片连色相都不剩 —— 留 4% 兜底，保证"这是哪门课"永远读得出来。
const double minCourseGlassFillAlpha = 0.04;

/// 把「卡片档的染色强度 × 压暗系数」收成最终 alpha，带下限。
///
/// 与 [CourseGlassStyle.tint] 的算法共用这一处：`CourseSurface` 的三个档位
/// （实体 / 高斯 / 液态）都按同一条式子压暗，各写一遍迟早会漂。
double courseGlassFillAlpha(double baseAlpha, double opacityScale) =>
    (baseAlpha * opacityScale).clamp(minCourseGlassFillAlpha, 1.0);

/// 按**卡片自己的**档位 + 当前明暗，解析这张卡片该用的玻璃参数。
///
/// 全流程只经 [LiquidGlassTuning.toStyle] 这一个参数出口：形状、深浅配方、区间收口都在那里，
/// 卡片这边只做两件它特有的映射 ——
///
/// * **底色取课程色**：`toStyle` 产出的 `tint` 是「玻璃底色白 / 深色的中性灰」，卡片不要它，
///   只**借它的 alpha**（= 卡片档的染色强度 × 深色配方系数），RGB 用课程色；
/// * **课程色的压暗系数**（冲突 / 放假）由 [opacityScale] 在 alpha 上再乘一次。
///
/// **磨砂不在这里**：卡片的预糊位图按 [CourseGlassTuning.blurSigma] 单独烤一张
/// （见 `resolveCourseCardPreblurSigma`），而 `toStyle` 算出来的 blurSigma 是逐帧的
/// 光照适配值，两者不是一个东西，别互相顶替。
///
/// [appearance] 传 `FrostedAppearanceScope` 里的那份（没有 scope 时上游会给
/// [FrostedAppearance.defaults]，此时卡片回落出厂档）。
CourseGlassStyle courseGlassStyleFor({
  required FrostedAppearance appearance,
  required double borderRadius,
  required Color courseColor,
  required Brightness brightness,
  double opacityScale = 1,
}) {
  final tuning = appearance.courseCardGlassTuning ?? CourseGlassTuning.courseCard;
  final shape = tuning.toLiquidGlassTuning().toStyle(
    borderRadius: borderRadius,
    brightness: brightness,
    // 卡片没有「深色档独立」那一层：形状永远跟着用户这一套走（`dark` 不给、
    // `link` 保持默认），但**配方照吃** —— 与 `pinnedChrome` 同口径，
    // 配方是光照适配、对所有表面一视同仁。
    darkBoost: appearance.darkGlassBoostEnabled,
  );
  return CourseGlassStyle(
    borderRadius: borderRadius,
    tint: courseColor.withValues(
      alpha: courseGlassFillAlpha(shape.tint.a, opacityScale),
    ),
    refraction: shape.refraction,
    refractionBand: shape.refractionBand,
    refractionEdgePow: shape.refractionEdgePow,
    dispersion: shape.dispersion,
    rimStrength: shape.rimStrength,
    rimWidth: shape.rimWidth,
  );
}
