import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

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
    this.refraction = 8,
    this.refractionBand = 7,
    this.refractionEdgePow = 2.5,
    this.rimStrength = 0.2,
    this.rimWidth = 1.5,
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
    rimStrength,
    rimWidth,
    rimColor,
  );
}
