import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_shader.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/widgets/course_glass_shader.dart';

/// 模拟的「屏幕」尺寸 = 绑定纹理尺寸 = 着色器里的 `u_size`。
const Size _screenSize = Size(200, 200);

/// 本表面在屏幕上的位置与尺寸 = `u_area_origin` / `u_area_size`。
const Offset _surfaceOrigin = Offset(50, 50);
const Size _surfaceSize = Size(100, 100);

const LiquidGlassStyle _style = LiquidGlassStyle(
  borderRadius: 20,
  tint: Color(0x00000000),
);

void main() {
  group('液态玻璃表面着色器契约', () {
    test('资产已声明且文件存在', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('- shaders/glass_surface_refraction.frag'),
        isTrue,
        reason: '着色器没在 pubspec 的 flutter.shaders 里声明，运行时取不到资产',
      );
      expect(
        File(LiquidGlassSurfaceShader.instance.assetKey).existsSync(),
        isTrue,
        reason: '声明的资产键必须对应一个真实文件',
      );
    });

    test('着色器能编译，且 Dart 侧解析的每个 uniform 名字都存在', () async {
      await LiquidGlassSurfaceShader.instance.ensureLoaded();
      expect(
        LiquidGlassSurfaceShader.instance.isLoaded,
        isTrue,
        reason: '着色器编译失败（语法错误 / 缺 uniform 声明）会静默降级成基础材质，'
            '这里必须红',
      );
      final shader = LiquidGlassSurfaceShader.instance.newShader();
      expect(shader, isNotNull);
      // 名字错一个就抛 ArgumentError —— 这是「改 .frag 忘了改 Dart」的唯一
      // 自动化拦截点（绘制期才炸，真机上才看得见）。
      debugValidateLiquidGlassUniforms(shader!);
      shader.dispose();
    });

    test('与卡片那份是两个独立程序，资产键不同', () {
      expect(
        LiquidGlassSurfaceShader.instance.assetKey,
        isNot(CourseCardGlassShader.instance.assetKey),
        reason: '卡片吃预模糊位图、按局部坐标画；这一份吃实时背景、按屏幕坐标画，'
            '两个程序不能互相顶替',
      );
    });
  });

  group('LiquidGlassStyle', () {
    test('同值相等，可作为 RenderObject 的更新判据', () {
      const a = LiquidGlassStyle(borderRadius: 12, tint: Color(0x552196F3));
      const b = LiquidGlassStyle(borderRadius: 12, tint: Color(0x552196F3));
      const c = LiquidGlassStyle(borderRadius: 8, tint: Color(0x552196F3));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('逻辑长度按 dpr 换算成物理像素', () {
      const style = LiquidGlassStyle(
        borderRadius: 12,
        tint: Color(0xFF000000),
      );
      final at2 = style.scaledLengths(2);
      expect(at2.radius, 24);
      expect(at2.refract, 16);
      expect(at2.band, 14);
      expect(at2.rimWidth, 6);
      // dpr 为 1 时换算必须是恒等，否则桌面/低密度设备上玻璃会整体缩水。
      final at1 = style.scaledLengths(1);
      expect(at1.radius, 12);
      expect(at1.refract, 8);
      expect(at1.band, 7);
      expect(at1.rimWidth, 3);
    });

    test('折射旋钮的默认值与课程卡片液态玻璃档逐字段一致', () {
      // 「同一个材质只有一种观感」：全局液态玻璃与卡片液态玻璃出厂必须长得一样，
      // 否则用户会在两个页面看到两种玻璃。任何一边改默认值都必须同步另一边。
      const card = CourseGlassStyle(borderRadius: 12, tint: Color(0xFF000000));
      expect(_style.refraction, card.refraction);
      expect(_style.refractionBand, card.refractionBand);
      expect(_style.refractionEdgePow, card.refractionEdgePow);
      expect(_style.rimStrength, card.rimStrength);
      expect(_style.rimWidth, card.rimWidth);
      expect(_style.rimColor, card.rimColor);
      expect(_style.lightDirection, card.lightDirection);
    });
  });

  // ── 绘制结果 ─────────────────────────────────────────────────────────────
  //
  // 上面几组只证明「uniform 名字对得上、参数换算对」，不证明「画出来是对的」。
  // 这一组把着色器真画进位图再读像素。
  //
  // 场景刻意与真机同构：绑定纹理是**整屏**（200x200），本表面只是它上面
  // 100x100 的一块（origin 50,50）—— 这正是 `BackdropFilter` 的形态，也是这一份
  // 着色器与卡片那份最大的口径差别（卡片按局部坐标画、自己映射纹理窗口）。
  //
  // 所有坐标推算都按「像素中心在 +0.5」来（Impeller 与本地测试后端同一口径）。
  group('液态玻璃表面着色器绘制结果', () {
    test('玻璃只落在 u_area_origin 指定的屏幕矩形里，圆角外全透明', () async {
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF3366AA),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(texture: texture);

      // 表面中心：不透明且就是背景。
      expect(_pixel(bytes, 100, 100), const Color(0xFF3366AA));
      // 半径 20 的圆角把 (51,51) 切在形状外。
      expect(_pixel(bytes, 51, 51).a, 0);
      // 表面矩形之外（左上角、右侧、下方）一律透明 —— 说明 SDF 是相对
      // u_area_origin/u_area_size 算的，而不是相对这次绘制的矩形算的。
      expect(_pixel(bytes, 10, 10).a, 0);
      expect(_pixel(bytes, 195, 100).a, 0);
      expect(_pixel(bytes, 100, 195).a, 0);
    });

    test('表面是整屏纹理的一个窗口，不是把纹理拉伸铺满自己', () async {
      // 纹理 x<50 红、[50,175) 绿、≥175 蓝。表面窗口落在 x∈[50,150]，
      // 所以表面内几乎全是绿。若哪天 u_area_origin 被漏掉（退化成
      // uv = 表面内坐标 / 表面尺寸），表面右部会读到蓝。
      final texture = await _screenTexture(_stripedScreen);
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(texture: texture);

      expect(_pixel(bytes, 60, 100), const Color(0xFF00FF00));
      expect(_pixel(bytes, 100, 100), const Color(0xFF00FF00));
      expect(_pixel(bytes, 148, 100), const Color(0xFF00FF00));
    });

    test('折射把表面外的内容拉进边缘，且只在作用带内生效', () async {
      // 同上纹理。左缘（屏幕 x=50）往左推几 px 就会越过红/绿分界 ——
      // 正是「边缘把背景掰弯」在像素上的样子。
      final texture = await _screenTexture(_stripedScreen);
      addTearDown(texture.dispose);

      final off = await _renderSurface(texture: texture);
      final on = await _renderSurface(texture: texture, refract: 8);

      expect(_pixel(off, 51, 100), const Color(0xFF00FF00));
      expect(
        _pixel(on, 51, 100),
        const Color(0xFFFF0000),
        reason: '关折射读表面内的绿，开折射该读到表面外的红',
      );
      // 作用带只有 7px：表面中心与更靠里处必须逐位一致，否则就是整块在位移。
      expect(_pixel(on, 100, 100), _pixel(off, 100, 100));
      expect(_pixel(on, 140, 100), _pixel(off, 140, 100));
    });

    test('染色按 sRGB 分量直通，不做色彩空间转换', () async {
      // u_tint 直接吃 Color.r/g/b（sRGB 编码值）。若引擎把着色器输出当线性值
      // 再编码一次，颜色会整体变亮（0.5 灰会从 128 变 188）。
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(
        texture: texture,
        tint: const Color(0xFF2196F3),
      );

      final pixel = _pixel(bytes, 100, 100);
      expect((pixel.r * 255).round(), closeTo(0x21, 1));
      expect((pixel.g * 255).round(), closeTo(0x96, 1));
      expect((pixel.b * 255).round(), closeTo(0xF3, 1));
      expect(pixel.a, 1.0);
    });
  });

  group('LiquidGlassSurface 降级', () {
    testWidgets('测试环境没有 shader filter 后端：返回 fallback，不建玻璃层', (
      tester,
    ) async {
      // `flutter test` 跑的是软件后端，`ImageFilter.isShaderFilterSupported` 恒为
      // false —— 也就是真机上「引擎不支持实时折射」那一档。所以这里能验的正是
      // 最要紧的降级行为：不抛异常、不留半透明空壳、内容由调用方的基础材质接管。
      expect(
        ui.ImageFilter.isShaderFilterSupported,
        isFalse,
        reason: '这条路径在测试环境跑不到，本组只能验降级',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => LiquidGlassSurface(
                borderRadius: _style.borderRadius,
                fallbackBuilder: (context) =>
                    const ColoredBox(key: Key('fallback'), color: Color(0xFF112233)),
                child: const ColoredBox(
                  key: Key('glass-child'),
                  color: Color(0xFF445566),
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      expect(LiquidGlassSurface.isAvailable(context), isFalse);
      expect(find.byKey(const Key('fallback')), findsOneWidget);
      expect(
        find.byKey(const Key('glass-child')),
        findsNothing,
        reason: '不可用时不能把内容画上去 —— 那样会得到一块没有背景模糊的空壳',
      );
    });

    test('未加载时 newShader 返回 null（绘制侧据此走基础材质）', () {
      final loader = LiquidGlassSurfaceShader.instance;
      final wasLoaded = loader.isLoaded;
      loader.resetForTesting();
      expect(loader.isLoaded, isFalse);
      expect(loader.newShader(), isNull);
      // 还原，避免影响同进程内的其他用例。
      if (wasLoaded) {
        return loader.ensureLoaded();
      }
      return Future<void>.value();
    });
  });
}

void _stripedScreen(ui.Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 50, 200),
    ui.Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(50, 0, 125, 200),
    ui.Paint()..color = const Color(0xFF00FF00),
  );
  canvas.drawRect(
    const Rect.fromLTWH(175, 0, 25, 200),
    ui.Paint()..color = const Color(0xFF0000FF),
  );
}

Future<ui.Image> _screenTexture(void Function(ui.Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _screenSize.width.round(),
    _screenSize.height.round(),
  );
  picture.dispose();
  return image;
}

/// 把液态玻璃表面着色器按给定参数画进 [_screenSize] 的位图，返回 rawRgba 像素。
///
/// 这里直接摆 uniform，而不是走 [LiquidGlassSurface]：那条路要求
/// `ImageFilter.isShaderFilterSupported` 为真，测试环境恒为假。所以「Dart 侧接线」
/// 由上面那组降级用例负责，这里只管着色器算得对不对。
///
/// 默认值刻意与 [LiquidGlassStyle] 的默认参数一致（band 7 / edgePow 2.5 /
/// rimWidth 3），于是这组同时钉住了默认参数下的观感。
Future<Uint8List> _renderSurface({
  required ui.Image texture,
  double radius = 20,
  Color tint = const Color(0x00000000),
  double refract = 0,
  double rim = 0,
}) async {
  final shader = LiquidGlassSurfaceShader.instance.newShader()!;
  shader.setImageSampler(0, texture);
  // 真机上这两项由引擎填/绑（第一个 vec2 / 第一个 sampler2D），这里手动摆成
  // 「整屏纹理 + 表面只占其中一块」的形态。
  shader.getUniformVec2('u_size').set(_screenSize.width, _screenSize.height);
  shader
      .getUniformVec2('u_area_origin')
      .set(_surfaceOrigin.dx, _surfaceOrigin.dy);
  shader
      .getUniformVec2('u_area_size')
      .set(_surfaceSize.width, _surfaceSize.height);
  shader.getUniformFloat('u_radius').set(radius);
  shader.getUniformVec4('u_tint').set(tint.r, tint.g, tint.b, tint.a);
  shader.getUniformFloat('u_refract').set(refract);
  shader.getUniformFloat('u_band').set(7);
  shader.getUniformFloat('u_edge_pow').set(2.5);
  shader.getUniformVec3('u_rim_color').set(1, 1, 1);
  shader.getUniformFloat('u_rim').set(rim);
  shader.getUniformFloat('u_rim_width').set(3);
  shader.getUniformVec2('u_light_dir').set(-0.6, -0.8);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(Offset.zero & _screenSize, ui.Paint()..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _screenSize.width.round(),
    _screenSize.height.round(),
  );
  picture.dispose();
  // toByteData 默认就是 rawRgba。
  final data = await image.toByteData();
  image.dispose();
  shader.dispose();
  return data!.buffer.asUint8List();
}

/// rawRgba 是预乘的；下面只读 alpha 为 255 的像素，所以直接当直通值用。
Color _pixel(Uint8List bytes, int x, int y) {
  final i = (y * _screenSize.width.round() + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}
