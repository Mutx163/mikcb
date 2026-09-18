import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color, Offset;

/// 课程卡片「折射玻璃」档的片元程序。
///
/// 为什么单独做一个加载器而不是塞进 `CourseSurface`：
/// * 卡片一屏 20~50 张，每张各自 `FragmentProgram.fromAsset` 会重复解析同一份
///   着色器资产；这里只解析一次，绘制对象各自 `fragmentShader()` 并自己释放。
/// * 加载是异步的，而卡片会在加载完成前就先画出来。用 [instance] 这个
///   [ChangeNotifier] 把「程序已就绪」播出去，绘制对象在 paint 阶段监听它并
///   `markNeedsPaint` —— 于是玻璃会在程序到达的下一帧自动补上，不需要重建
///   整棵树，也不需要把「加载中」这个状态往上层传。
///
/// 加载失败（后端不支持、资产缺失、测试环境没有 GPU）时保持 [isLoaded] 为
/// false，卡片按「高斯磨砂」外观绘制 —— 见 `CourseSurface._buildRefraction`
/// 的降级分支，绝不出现破相。
class CourseCardGlassShader extends ChangeNotifier {
  CourseCardGlassShader._();

  static final CourseCardGlassShader instance = CourseCardGlassShader._();

  /// 资产键必须与 `pubspec.yaml` 的 `flutter.shaders` 条目一致。
  static const String assetKey = 'shaders/course_card_glass.frag';

  ui.FragmentProgram? _program;
  Future<void>? _loading;

  /// 着色器程序是否可用。false 时调用方应走非折射的降级路径。
  bool get isLoaded => _program != null;

  /// 幂等预热。与绘制对象内部的调用合起来只加载一次。
  Future<void> ensureLoaded() => _loading ??= _load();

  /// 一份新的着色器实例；程序不可用时返回 null。
  ///
  /// 调用方拥有返回的实例，需自行 `dispose()`（与 `FragmentProgram` 不同，
  /// `FragmentShader` 是每次绘制各自持有的可变 uniform 载体）。
  ui.FragmentShader? newShader() => _program?.fragmentShader();

  Future<void> _load() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(assetKey);
      // 绘制对象在 paint 阶段订阅，靠这一次通知把玻璃补上。
      notifyListeners();
    } catch (error, stackTrace) {
      // 降级而非抛出：桌面/测试环境没有可用的着色器后端是预期情况，
      // 卡片回落到磨砂外观即可，不该让整个课表渲染失败。
      debugPrint(
        'CourseCardGlassShader 加载失败，折射玻璃档降级为磨砂：$error\n$stackTrace',
      );
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _program = null;
    _loading = null;
  }
}

/// 一张卡片折射玻璃的绘制参数。
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
    this.rimWidth = 3,
    this.rimColor = const Color(0xFFFFFFFF),
    this.lightDirection = const Offset(-0.6, -0.8),
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

  /// 边缘高光强度（0–1）。
  final double rimStrength;

  /// 边缘高光带宽（逻辑 px）。
  final double rimWidth;

  /// 边缘高光颜色。
  final Color rimColor;

  /// 光来向（卡片局部坐标，y 向下）。默认左上。
  final Offset lightDirection;

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
          other.rimColor == rimColor &&
          other.lightDirection == lightDirection;

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
    lightDirection,
  );
}
