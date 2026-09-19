import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../hyperos/liquid/liquid_glass_shader.dart';

/// **临时探针**（2026-09-19）：量出 `ImageFilter.compose(着色器, 模糊)` 里那层
/// 高斯模糊把绑定纹理往外扩边之后，着色器眼里的坐标原点到底有没有跟着动。
///
/// ## 为什么必须实测
///
/// 真机上「模糊一开就有、归零就消失」的那条黑边，我先前推断是「纹理扩边 →
/// `FlutterFragCoord()` 的原点前移 → SDF 跟着位移」。按那个推断做了补偿，结果
/// 真机上是**错位 + 黑边更大**：错位量约等于 3σ —— 说明原点**根本没动**，我把
/// 一个没验证的推断当成了事实。这两个数（引擎填的纹理尺寸、内容在纹理里的偏移）
/// 只有引擎知道，着色器的 uniform 只能写不能读，所以只能这样量一次。
///
/// ## 怎么量
///
/// 把 `u_probe` 置 1（见 `shaders/glass_surface_refraction.frag` 的探针分支），
/// 用**和真机同一条滤镜链**（同一个着色器 + 同一个模糊，compose 起来）把一张
/// 纯色画面过滤一遍，再把结果回读成像素：
///
/// * 回读图里带**红**的位置 = 那个片元的 `FlutterFragCoord` 落在纹理原点附近；
///   若红出现在回读图的左上角，说明「纹理原点 == 画面原点」→ 没有位移；
///   若红整条不见，说明纹理原点在画面原点**之前** → 有位移，量级由绿通道给。
/// * 绿 = `fract(FlutterFragCoord.y / 128)`，从它在回读图第 0 行的取值可反推位移量
///   （每 128 个物理像素一循环，配合「红条是否可见」消歧）。
///
/// 结果用 `debugPrint` 打出来（非 release 会进 flutter_blackbox 的日志面板）。
abstract final class LiquidGlassUvProbe {
  static bool _done = false;

  /// 只在第一块液态玻璃绘制时跑一次；量到了就不再打扰画面。
  static void runOnce() {
    if (kReleaseMode || _done) {
      return;
    }
    _done = true;
    unawaited(_measure());
  }

  static Future<void> _measure() async {
    // 视口尺寸直接从引擎问，免得为了探针再往表面里塞一个只在探针期用到的参数。
    final view = ui.PlatformDispatcher.instance.views.first;
    final dpr = view.devicePixelRatio;
    final viewSize = view.physicalSize / dpr;
    final shader = LiquidGlassSurfaceShader.instance.newShader();
    if (shader == null) {
      debugPrint('[glass-probe] 着色器还没加载，跳过这次');
      return;
    }
    // 着色器要求「第一个 vec2」「至少一个 sampler2D」的槽位存在；探针分支不用它们，
    // 但为了让引擎认这张滤镜，该有的都留着（槽位取不到会当场抛，正好当自检）。
    shader.getUniformVec2('u_size').set(0, 0);
    shader.getUniformVec2('u_area_origin').set(0, 0);
    shader.getUniformVec2('u_area_size').set(0, 0);
    shader.getUniformFloat('u_radius').set(0);
    shader.getUniformVec4('u_tint').set(0, 0, 0, 0);
    shader.getUniformFloat('u_refract').set(0);
    shader.getUniformFloat('u_band').set(1);
    shader.getUniformFloat('u_edge_pow').set(1);
    shader.getUniformVec3('u_rim_color').set(0, 0, 0);
    shader.getUniformFloat('u_rim').set(0);
    shader.getUniformFloat('u_rim_width').set(1);
    shader.getUniformVec2('u_light_dir').set(-0.6, -0.8);
    shader.getUniformFloat('u_probe').set(1);

    // 与真机同一条链：内层高斯（sigma 取默认档 15）+ 外层着色器。
    const sigma = 15.0;
    final filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: ui.TileMode.clamp,
      ),
    );

    final logical = ui.Offset.zero & viewSize;
    final width = (viewSize.width * dpr).round();
    final height = (viewSize.height * dpr).round();
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(dpr);
      canvas.saveLayer(logical, ui.Paint()..imageFilter = filter);
      canvas.drawRect(
        logical,
        ui.Paint()..color = const ui.Color(0xFF808080),
      );
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      final data = await image.toByteData();
      image.dispose();
      shader.dispose();
      if (data == null) {
        debugPrint('[glass-probe] 回读失败：toByteData 给了 null');
        return;
      }
      final bytes = data.buffer.asUint8List();

      ui.Color at(int x, int y) {
        final i = (y * width + x) * 4;
        return ui.Color.fromARGB(
          bytes[i + 3],
          bytes[i],
          bytes[i + 1],
          bytes[i + 2],
        );
      }

      String rgb(int x, int y) {
        final c = at(x, y);
        return '($x,$y)=${c.r.toStringAsFixed(3)},'
            '${c.g.toStringAsFixed(3)},${c.b.toStringAsFixed(3)}';
      }

      debugPrint(
        '[glass-probe] 回读 ${width}x$height dpr=$dpr '
        '视口逻辑=${viewSize.width.toStringAsFixed(1)}x'
        '${viewSize.height.toStringAsFixed(1)}',
      );
      // 左上角那一带：红 = 纹理原点就落在回读原点附近（没有位移）。
      debugPrint(
        '[glass-probe] 纹理原点附近 ${rgb(0, 0)} ${rgb(1, 0)} ${rgb(4, 0)} '
        '${rgb(7, 0)} ${rgb(8, 0)} ${rgb(9, 0)} ${rgb(20, 0)}',
      );
      debugPrint(
        '[glass-probe] 纵向 ${rgb(0, 0)} ${rgb(0, 1)} ${rgb(0, 4)} '
        '${rgb(0, 7)} ${rgb(0, 8)} ${rgb(0, 9)} ${rgb(0, 20)}',
      );
      // 远端：纹理原点若被推走，远端会先失去真实内容。
      debugPrint(
        '[glass-probe] 远端 ${rgb(width - 1, 0)} ${rgb(0, height - 1)} '
        '${rgb(width ~/ 2, height ~/ 2)}',
      );
      debugPrint(
        '[glass-probe] 期望（无位移时）: 红只在 x<8 或 y<8，绿≈0 于 y=0',
      );
    } catch (error, stack) {
      debugPrint('[glass-probe] 探针失败: $error');
      debugPrint('$stack');
      shader.dispose();
    }
  }
}
