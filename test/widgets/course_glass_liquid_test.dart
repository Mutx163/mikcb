// 课程卡片「液态玻璃」档（CourseCardSurfaceStyle.liquidGlass）的回归测试。
//
// 这一档是「实体卡片 / 高斯模糊」之外的第三种材质：与高斯档采**同一份**共享
// 预模糊位图，差别只在最后一步多跑一次液态玻璃着色器。因此它的契约有两块：
//   ① 档位语义 —— 它属于「玻璃材质」，前置条件与墨色规则必须跟高斯档同源
//      （判据是 CourseCardSurfaceStyleX.isGlass，不是 == gaussian）；
//   ② 着色器契约 —— `.frag` 的 uniform 名字必须与 Dart 侧解析的名字对得上，
//      错一个就在绘制期抛异常，且只会在真机上被看见；
//   ③ 绘制结果 —— 名字对得上不等于画得对。真把着色器画进位图读像素，圆角覆盖、
//      uv 窗口映射、折射作用带、染色直通才有自动化拦截。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/surface_material.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/course_color_palette.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/course_glass_shader.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CourseCardSurfaceStyle.liquidGlass 档位语义', () {
    test('value 与 fromValue 往返一致', () {
      // 枚举名换成了 liquidGlass，但磁盘上仍写 'refraction'：'liquidGlass'
      // 这个字符串已经被老版本的「玻璃」档占用（见下一条）。
      expect(CourseCardSurfaceStyle.liquidGlass.value, 'refraction');
      expect(
        CourseCardSurfaceStyleX.fromValue('refraction'),
        CourseCardSurfaceStyle.liquidGlass,
      );
    });

    test('历史字符串 glass / liquidGlass 仍归高斯，不会被新档抢走', () {
      // 回归点：老配置里的 'glass' 指的是当年那档液态玻璃，语义就是现在的
      // 高斯磨砂。新档的持久化值用 'refraction' 正是为了不与它撞车。
      expect(
        CourseCardSurfaceStyleX.fromValue('glass'),
        CourseCardSurfaceStyle.gaussian,
      );
      expect(
        CourseCardSurfaceStyleX.fromValue('liquidGlass'),
        CourseCardSurfaceStyle.gaussian,
      );
      expect(
        CourseCardSurfaceStyleX.fromValue('translucent'),
        CourseCardSurfaceStyle.solid,
      );
    });

    test('isGlass：两种玻璃档为真，实体档为假', () {
      expect(CourseCardSurfaceStyle.solid.isGlass, isFalse);
      expect(CourseCardSurfaceStyle.gaussian.isGlass, isTrue);
      expect(CourseCardSurfaceStyle.liquidGlass.isGlass, isTrue);
    });

    test('液态玻璃档同样被视为「壁纸会透出来」', () {
      // 墨色对比度判据：玻璃档不能拿实体卡面色做对比度基准。
      expect(courseCardSurfaceShowsWallpaper(CourseCardSurfaceStyle.liquidGlass), isTrue);
      expect(courseCardSurfaceShowsWallpaper(CourseCardSurfaceStyle.gaussian), isTrue);
      expect(courseCardSurfaceShowsWallpaper(CourseCardSurfaceStyle.solid), isFalse);
    });
  });

  group('effectiveCourseCardSurfaceStyle 对液态玻璃档的口径', () {
    test('没有壁纸：液态玻璃档回落实体', () {
      final settings = TimetableSettings.defaults().copyWith(
        courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.solid,
      );
    });

    test('有壁纸：液态玻璃档保持液态玻璃', () async {
      final dir = await Directory.systemTemp.createTemp('refraction_style');
      final file = File('${dir.path}/wall.png')..writeAsBytesSync([1, 2, 3, 4]);
      addTearDown(() => dir.deleteSync(recursive: true));
      final settings = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: file.path,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.liquidGlass,
      );
    });

    test('模糊管线不可用：液态玻璃档与高斯档一样回落实体', () async {
      // 液态玻璃档也寄生在同一份预模糊位图 / 全局模糊管线上，管线关了就没有可
      // 采样的磨砂背景，裸 tint 过壁纸读作透明卡片。
      final dir = await Directory.systemTemp.createTemp('refraction_blur');
      final file = File('${dir.path}/wall.png')..writeAsBytesSync([1, 2, 3, 4]);
      addTearDown(() => dir.deleteSync(recursive: true));
      final settings = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: file.path,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings, gaussianBlurAvailable: false),
        CourseCardSurfaceStyle.solid,
      );
    });
  });

  group('courseCardSurfaceMaterial 的展示标签', () {
    test('液态玻璃档在模糊开着时报 refractionGlass，而不是 frostGaussian', () async {
      // 玻璃档依赖可用壁纸（2026-09-25 就地归真）：先造一张真图。
      final dir = await Directory.systemTemp.createTemp('card_label_liquid');
      final file = File('${dir.path}/wall.png')..writeAsBytesSync([1, 2, 3, 4]);
      addTearDown(() => dir.deleteSync(recursive: true));
      final settings = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: true,
        homePageWallpaperPath: file.path,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
      );
      expect(
        courseCardSurfaceMaterial(settings),
        SurfaceMaterial.liquidGlass,
      );
    });

    test('模糊关掉时仍然回落实体', () {
      final settings = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: false,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
      );
      expect(courseCardSurfaceMaterial(settings), SurfaceMaterial.solid);
    });

    test('高斯档不受影响', () async {
      final dir = await Directory.systemTemp.createTemp('card_label_gauss');
      final file = File('${dir.path}/wall.png')..writeAsBytesSync([1, 2, 3, 4]);
      addTearDown(() => dir.deleteSync(recursive: true));
      final settings = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: true,
        homePageWallpaperPath: file.path,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
      );
      expect(
        courseCardSurfaceMaterial(settings),
        SurfaceMaterial.frostGaussian,
      );
    });
  });

  group('液态玻璃着色器契约', () {
    test('资产已声明且文件存在', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('- shaders/course_card_glass.frag'),
        isTrue,
        reason: '着色器没在 pubspec 的 flutter.shaders 里声明，运行时取不到资产',
      );
      expect(
        File(CourseCardGlassShader.instance.assetKey).existsSync(),
        isTrue,
        reason: '声明的资产键必须对应一个真实文件',
      );
    });

    test('着色器能编译，且 Dart 侧解析的每个 uniform 名字都存在', () async {
      await CourseCardGlassShader.instance.ensureLoaded();
      expect(
        CourseCardGlassShader.instance.isLoaded,
        isTrue,
        reason: '着色器编译失败（语法错误 / 缺 uniform 声明）会静默降级成磨砂，'
            '这里必须红',
      );
      final shader = CourseCardGlassShader.instance.newShader();
      expect(shader, isNotNull);
      // 名字错一个就抛 ArgumentError —— 这是「改 .frag 忘了改 Dart」的唯一
      // 自动化拦截点（绘制期才炸，真机上才看得见）。
      debugValidateCourseGlassUniforms(shader!);
      shader.dispose();
    });
  });

  group('CourseSurface 液态玻璃档', () {
    Future<void> pumpSurface(
      WidgetTester tester,
      CourseCardSurfaceStyle style,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CourseSurface(
            style: style,
            color: const Color(0xFF2196F3),
            borderRadius: 12,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('模糊管线不可用：液态玻璃档回退实体卡面，不留裸 tint', (tester) async {
      // 测试环境（VM）liveBlurSupported 恒为 false，正对应「模糊管线不可用」。
      await pumpSurface(tester, CourseCardSurfaceStyle.liquidGlass);

      expect(find.byType(BackdropFilter), findsNothing);
      final surface = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = surface.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
      expect(
        decoration.gradient!.colors.first.a,
        1.0,
        reason: '回退卡面必须不透明，否则过壁纸仍读作透明卡片',
      );
    });

    testWidgets('没有预模糊位图时不会去挂着色器画', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CourseSurface(
            style: CourseCardSurfaceStyle.liquidGlass,
            color: Color(0xFF2196F3),
            borderRadius: 12,
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(PreblurredWallpaperAlignedFill), findsNothing);
    });
  });

  group('PreblurredWallpaperAlignedFill 的液态玻璃参数', () {
    testWidgets('带 glass 参数时正常占位、不抛异常', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 120,
              height: 60,
              child: PreblurredWallpaperAlignedFill(
                glass: CourseGlassStyle(
                  borderRadius: 12,
                  tint: Color(0x552196F3),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(PreblurredWallpaperAlignedFill)),
        const Size(120, 60),
      );
    });

    testWidgets('仍然不吞掉落在卡片上的点击', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(
                width: 120,
                height: 60,
                child: PreblurredWallpaperAlignedFill(
                  glass: CourseGlassStyle(
                    borderRadius: 12,
                    tint: Color(0x552196F3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byType(PreblurredWallpaperAlignedFill),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('CourseGlassStyle', () {
    test('同值相等，可作为 RenderObject 的更新判据', () {
      const a = CourseGlassStyle(
        borderRadius: 12,
        tint: Color(0x552196F3),
      );
      const b = CourseGlassStyle(
        borderRadius: 12,
        tint: Color(0x552196F3),
      );
      const c = CourseGlassStyle(
        borderRadius: 8,
        tint: Color(0x552196F3),
      );
      // 色散必须参与判等：渲染对象靠它决定要不要重绘，漏了就是「拖色散不动」。
      const d = CourseGlassStyle(
        borderRadius: 12,
        tint: Color(0x552196F3),
        dispersion: 0.9,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
    });
  });

  group('CourseCardGlassShader 降级', () {
    test('未加载时 newShader 返回 null（绘制侧据此走磨砂外观）', () {
      final loader = CourseCardGlassShader.instance;
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

  // ── 绘制结果 ─────────────────────────────────────────────────────────────
  //
  // 上面几组只证明「档位接对了、uniform 名字对得上」，不证明「画出来是对的」。
  // 这一组把着色器真画进位图再读像素。
  //
  // 场景刻意与真机同构：卡片只有 100x100，纹理比卡片大、且 texOrigin 为负 ——
  // 真机上卡片就是整屏预模糊位图上的一个移动窗口，而不是把位图拉伸铺满自己。
  //
  // 所有坐标推算都按「像素中心在 +0.5」来（Impeller 与本地测试后端同一口径）。
  group('液态玻璃着色器绘制结果', () {
    test('圆角内不透明且就是背景位图，圆角外全透明', () async {
      final texture = await _glassTexture(
        const Size(100, 100),
        (canvas) => canvas.drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          ui.Paint()..color = const Color(0xFF3366AA),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderGlass(
        texture: texture,
        texOrigin: Offset.zero,
        texDestSize: const Size(100, 100),
      );

      expect(_glassPixel(bytes, 50, 50), const Color(0xFF3366AA));
      // 半径 20 的圆角把 (1,1) 与 (98,98) 切在形状外。
      expect(_glassPixel(bytes, 1, 1).a, 0);
      expect(_glassPixel(bytes, 98, 98).a, 0);
    });

    test('卡片是纹理的一个窗口，不是把纹理拉伸铺满', () async {
      // 纹理 200x200：tex x<50 红、[50,175) 绿、≥175 蓝。
      // 卡片窗口落在 tex x∈[50,150]，所以卡内几乎全是绿（只有最左边一线是红）。
      // 若哪天 texOrigin 被漏掉（退化成 uv = 卡内坐标 / 卡尺寸），卡右部会读到蓝。
      final texture = await _glassTexture(
        const Size(200, 200),
        (canvas) {
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
        },
      );
      addTearDown(texture.dispose);

      final bytes = await _renderGlass(
        texture: texture,
        texOrigin: const Offset(-50, -50),
        texDestSize: const Size(200, 200),
      );

      expect(_glassPixel(bytes, 1, 50), const Color(0xFF00FF00));
      expect(_glassPixel(bytes, 50, 50), const Color(0xFF00FF00));
      expect(_glassPixel(bytes, 90, 50), const Color(0xFF00FF00));
    });

    test('折射把窗口外的内容拉进边缘，且只在作用带内生效', () async {
      // 同上纹理。卡左缘往左推 6~7px 就会越过 tex 50 这条红/绿分界 ——
      // 正是「边缘把背景掰弯」在像素上的样子。
      final texture = await _glassTexture(
        const Size(200, 200),
        (canvas) {
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
        },
      );
      addTearDown(texture.dispose);

      Future<Uint8List> render(double refract) => _renderGlass(
        texture: texture,
        texOrigin: const Offset(-50, -50),
        texDestSize: const Size(200, 200),
        refract: refract,
      );
      final off = await render(0);
      final on = await render(8);

      expect(_glassPixel(off, 1, 50), const Color(0xFF00FF00));
      expect(
        _glassPixel(on, 1, 50),
        const Color(0xFFFF0000),
        reason: '关折射读窗口内的绿，开折射该读到窗口外的红',
      );
      // 作用带只有 7px：卡心与更靠里处必须逐位一致，否则就是整卡在位移。
      expect(_glassPixel(on, 50, 50), _glassPixel(off, 50, 50));
      expect(_glassPixel(on, 90, 50), _glassPixel(off, 90, 50));
    });

    test('色散把红/蓝采样点错开：边缘像素变了，带内逐位不变', () async {
      // 高频条纹纹理（每 4px 换一次色）：折射位移 ~3.9px，所以「红再往外一点、
      // 蓝往回退一点」这两个采样点必然落到**不同的条纹**上，像素颜色因此改变。
      // 条纹用红/绿交替而不是纯色块：位移的方向错了也照样会变，所以这里断言的是
      // 「三采样分支真的接上了、uniform 真的传进来了」，方向由着色器里那三行保证。
      final texture = await _glassTexture(
        const Size(200, 200),
        (canvas) {
          for (var x = 0; x < 200; x += 8) {
            canvas.drawRect(
              Rect.fromLTWH(x.toDouble(), 0, 4, 200),
              ui.Paint()..color = const Color(0xFFFF0000),
            );
            canvas.drawRect(
              Rect.fromLTWH(x + 4.0, 0, 4, 200),
              ui.Paint()..color = const Color(0xFF00FF00),
            );
          }
        },
      );
      addTearDown(texture.dispose);

      Future<Uint8List> render(double dispersion) => _renderGlass(
        texture: texture,
        texOrigin: const Offset(-50, -50),
        texDestSize: const Size(200, 200),
        refract: 8,
        dispersion: dispersion,
      );
      final off = await render(0);
      final on = await render(1);

      expect(
        _glassPixel(on, 1, 50),
        isNot(_glassPixel(off, 1, 50)),
        reason: '色散开了边缘却没变 —— uniform 没传进来，或三采样分支没接上',
      );
      // 作用带只有 7px：带内像素必须逐位一致，否则就是整卡在位移。
      expect(_glassPixel(on, 50, 50), _glassPixel(off, 50, 50));
      expect(_glassPixel(on, 90, 50), _glassPixel(off, 90, 50));
    });

    test('边光整圈均匀：四条边的中点与四角一样亮', () async {
      // 回归点（2026-09-20 真机口径「四个角落有白线、上下左右都没有」）：边光
      // 曾经按边界曲率加权 —— 圆角满档、长直段归零，而判据的过渡宽度是
      // 1.5 × 圆角半径。卡片每条直边都短，中点到最近转角的距离远超那个宽度，
      // 于是四条边中点全黑、只剩四个白色钩子。
      //
      // 这里画一张纯黑纹理、关掉折射、只开边光：卡内非边光区应为纯黑，边光带内
      // 为白。修复前四个中点会读到与卡心一样的黑。
      final texture = await _glassTexture(
        const Size(100, 100),
        (canvas) => canvas.drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderGlass(
        texture: texture,
        texOrigin: Offset.zero,
        texDestSize: const Size(100, 100),
        rim: 1,
      );

      // 边光带峰值在离边 0.35 × 1.5 = 0.53px 处，只有最外那一圈像素落在带内
      // （第 1 圈像素中心深度 0.5，第 2 圈深度 1.5 已经出了带宽）。
      Color edge(int x, int y) => _glassPixel(bytes, x, y);
      final midpoints = <String, Color>{
        '上边中点': edge(50, 0),
        '下边中点': edge(50, 99),
        '左边中点': edge(0, 50),
        '右边中点': edge(99, 50),
      };
      for (final entry in midpoints.entries) {
        expect(
          entry.value.a,
          1.0,
          reason: '${entry.key}应落在形状内（圆角只切四角）',
        );
        expect(
          (entry.value.r * 255).round(),
          greaterThan(200),
          reason:
              '${entry.key}必须和四角一样亮 —— 读到黑就是「只留转角」又回来了',
        );
      }
      // 四边等亮（同一份均匀权重，容差取浮点误差）。
      for (final entry in midpoints.entries) {
        expect(
          (entry.value.r * 255 - midpoints['上边中点']!.r * 255).abs(),
          lessThan(2),
          reason: '${entry.key}与上边中点不等亮，就不是「整圈均匀」',
        );
      }

      // 45° 转角弧上同样亮着（这一格修复前后都亮，钉住「四角没被顺手删掉」）。
      expect((edge(6, 6).r * 255).round(), greaterThan(100));
      // 带外与卡心保持纯黑：边光不许漫进卡内。
      expect(edge(50, 50), const Color(0xFF000000));
      expect(edge(50, 10), const Color(0xFF000000));
    });

    test('染色按 sRGB 分量直通，不做色彩空间转换', () async {
      // u_tint 直接吃 Color.r/g/b（sRGB 编码值）。若引擎把着色器输出当线性值
      // 再编码一次，课程色会整体变亮（0.5 灰会从 128 变 188）。
      final texture = await _glassTexture(
        const Size(100, 100),
        (canvas) => canvas.drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderGlass(
        texture: texture,
        texOrigin: Offset.zero,
        texDestSize: const Size(100, 100),
        tint: const Color(0xFF2196F3),
      );

      final pixel = _glassPixel(bytes, 50, 50);
      expect((pixel.r * 255).round(), closeTo(0x21, 1));
      expect((pixel.g * 255).round(), closeTo(0x96, 1));
      expect((pixel.b * 255).round(), closeTo(0xF3, 1));
      expect(pixel.a, 1.0);
    });
  });
}

/// 卡片探针的统一尺寸，与 [_renderGlass] 里的 `u_size` 一致。
const Size _glassCardSize = Size(100, 100);

Future<ui.Image> _glassTexture(
  Size size,
  void Function(ui.Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  return image;
}

/// 把液态玻璃着色器按给定参数画进 [_glassCardSize] 的位图，返回 rawRgba 像素。
///
/// 这里直接摆 uniform，而不是走 `CourseSurface` → `PreblurredWallpaperAlignedFill`：
/// 那条路要求 `HyperosBlurredHeader.backdropBlurEnabled` 为真，而测试环境恒为假
/// （见 course_surface_blur_fallback_test.dart 的说明）。所以「Dart 侧接线」由档位
/// 语义与尺寸/命中测试那几组负责，这里只管着色器算得对不对。
///
/// 默认值刻意与 [CourseGlassStyle] 的默认参数一致（band 7 / edgePow 2.5 /
/// rimWidth 1.5），于是这组同时钉住了默认参数下的观感。
Future<Uint8List> _renderGlass({
  required ui.Image texture,
  required Offset texOrigin,
  required Size texDestSize,
  double radius = 20,
  Color tint = const Color(0x00000000),
  double refract = 0,
  double dispersion = 0,
  double rim = 0,
}) async {
  final shader = CourseCardGlassShader.instance.newShader()!;
  shader.setImageSampler(0, texture);
  shader.getUniformVec2('u_size').set(
    _glassCardSize.width,
    _glassCardSize.height,
  );
  shader.getUniformVec2('u_tex_origin').set(texOrigin.dx, texOrigin.dy);
  shader.getUniformVec2('u_tex_dest_size').set(
    texDestSize.width,
    texDestSize.height,
  );
  shader.getUniformFloat('u_radius').set(radius);
  shader.getUniformVec4('u_tint').set(tint.r, tint.g, tint.b, tint.a);
  shader.getUniformFloat('u_refract').set(refract);
  shader.getUniformFloat('u_band').set(7);
  shader.getUniformFloat('u_edge_pow').set(2.5);
  shader.getUniformFloat('u_dispersion').set(dispersion);
  shader.getUniformVec3('u_rim_color').set(1, 1, 1);
  shader.getUniformFloat('u_rim').set(rim);
  shader.getUniformFloat('u_rim_width').set(1.5);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(Offset.zero & _glassCardSize, ui.Paint()..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _glassCardSize.width.round(),
    _glassCardSize.height.round(),
  );
  picture.dispose();
  // toByteData 默认就是 rawRgba。
  final data = await image.toByteData();
  image.dispose();
  shader.dispose();
  return data!.buffer.asUint8List();
}

/// rawRgba 是预乘的；下面只读 alpha 为 255 的像素，所以直接当直通值用。
Color _glassPixel(Uint8List bytes, int x, int y) {
  final i = (y * _glassCardSize.width.round() + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}
