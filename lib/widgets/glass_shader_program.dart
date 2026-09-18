import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 一份片元着色器资产（`pubspec.yaml` 的 `flutter.shaders` 条目）的加载器。
///
/// 为什么不让每个绘制对象各自 `FragmentProgram.fromAsset`：着色器程序解析是
/// 一次异步的引擎调用，一屏几十个绘制对象各来一次纯属重复；而程序本身是
/// 不可变的，天然可共享。这里把它解析一次，绘制对象各自
/// [newShader] 取一份**可变 uniform 载体**（`FragmentShader`），各自释放。
///
/// 加载是异步的，而卡片/表面往往在加载完成前就已经画出来了。继承
/// [ChangeNotifier] 是为了把「程序已就绪」播出去：绘制对象在 paint 阶段订阅它
/// 并 `markNeedsPaint` —— 于是玻璃会在程序到达的下一帧自动补上，不需要重建
/// 整棵树，也不需要把「加载中」这个状态往上层传。
///
/// 加载失败（后端不支持、资产缺失、测试环境没有 GPU）时保持 [isLoaded] 为
/// false，调用方据此走非着色器的降级外观，**绝不抛出**：桌面/测试环境没有可用
/// 的着色器后端是预期情况，不该让整个界面渲染失败。
abstract class GlassShaderProgram extends ChangeNotifier {
  GlassShaderProgram({required this.assetKey, required this.debugLabel});

  /// 资产键，必须与 `pubspec.yaml` 的 `flutter.shaders` 条目一致。
  final String assetKey;

  /// 失败日志里用的名字（`debugPrint` 前缀），也方便测试定位。
  final String debugLabel;

  ui.FragmentProgram? _program;
  Future<void>? _loading;

  /// 着色器程序是否可用。false 时调用方应走非着色器的降级路径。
  bool get isLoaded => _program != null;

  /// 幂等预热。与绘制对象内部的调用合起来只加载一次。
  Future<void> ensureLoaded() => _loading ??= _load();

  /// 一份新的着色器实例；程序不可用时返回 null。
  ///
  /// 调用方拥有返回的实例，需自行 `dispose()` —— 与 [ui.FragmentProgram] 不同，
  /// [ui.FragmentShader] 是每次绘制各自持有的可变 uniform 载体。
  ui.FragmentShader? newShader() => _program?.fragmentShader();

  Future<void> _load() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(assetKey);
      // 绘制对象在 paint 阶段订阅，靠这一次通知把玻璃补上。
      notifyListeners();
    } catch (error, stackTrace) {
      // 降级而非抛出：见类注释。
      debugPrint('$debugLabel 加载失败，相关材质降级：$error\n$stackTrace');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _program = null;
    _loading = null;
  }
}
