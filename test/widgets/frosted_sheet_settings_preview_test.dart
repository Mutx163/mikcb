import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/widgets/frosted_sheet_settings_preview.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

import '../helpers_test_app.dart';

/// 1x1 transparent PNG — a real decodable file for the wallpaper backdrop.
const _tinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

const _liquidAppearance = FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
  glassMode: FrostedGlassMode.liquidGlass,
);

void main() {
  group('demo sheet follows the selected glass mode', () {
    for (final mode in FrostedGlassMode.values) {
      testWidgets('$mode 下演示瓦片仍是锁标准档的液态玻璃', (tester) async {
        final appearance = FrostedAppearance(
          sheetBlurSigma: 15,
          sheetTintAlpha: 0.7,
          sheetBarrierAlpha: 0.2,
          glassMode: mode,
        );

        await tester.pumpWidget(
          TestApp(
            home: FrostedAppearanceScope(
              appearance: appearance,
              child: const FrostedSheetSettingsDemoSheet(),
            ),
          ),
        );
        await tester.pump();

        // 演示弹层属于弹窗家族：自 2026-09-19 起**永远**是液态玻璃的标准档，
        // 不再随全局材质档位变（用户口径：不允许用户调整这些的材质）。
        // 5 块 = 弹层自己的面板 1 + 演示的四块瓦片。
        expect(find.byType(LiquidGlassSurface), findsNWidgets(5));
      });
    }

    testWidgets(
      'demo route opens and renders its four entry rows',
      (tester) async {
        const savedAppearance = _liquidAppearance;
        const draftAppearance = FrostedAppearance(
          sheetBlurSigma: 15,
          sheetTintAlpha: 0.7,
          sheetBarrierAlpha: 0.2,
          glassMode: FrostedGlassMode.gaussian,
        );

        await tester.pumpWidget(
          TestApp(
            home: FrostedAppearanceScope(
              appearance: savedAppearance,
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (context) => FrostedAppearanceScope(
                    appearance: draftAppearance,
                    child: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () => showFrostedSheetSettingsDemo(context),
                        child: const Text('Open demo'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open demo'));
        await tester.pumpAndSettle();

        // 弹层锁标准档之后，「用草稿档还是存档档」在**材质上**已经看不出来了
        // （两边都是液态玻璃），所以这里退化成冒烟：路由能开、五块面都在、
        // 四行入口都渲染。档位跨越路由边界的语义由上面那组逐档用例覆盖。
        expect(find.byType(LiquidGlassSurface), findsNWidgets(5));
        expect(find.text('课程统计'), findsOneWidget);
        expect(find.text('课表设置'), findsOneWidget);
        expect(find.text('导入课程'), findsOneWidget);
      },
    );
  });

  group('grouped backdrop sampling for the chrome band', () {
    testWidgets('own-layer glass requests the grouped backdrop', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: _liquidAppearance,
            child: BackdropGroup(
              child: const Stack(
                children: [
                  Positioned.fill(child: UndimmedBackdropCapture()),
                  LiquidGlassSurface(
                    borderRadius: 12,
                    grouped: true,
                    fallbackBuilder: _noopFallback,
                    child: SizedBox(width: 100, height: 50),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 表面必须进祖先组的共享采样点：真机上这样才会拿到组内全尺寸捕获，
      // 而不是自己那条窄带 bounds 里的背景（折射位移在带边会被钳制）。
      // 测试引擎没有 shader filter 后端，能断言的就是这个开关本身。
      final surface = tester.widget<LiquidGlassSurface>(
        find.byType(LiquidGlassSurface),
      );
      expect(surface.grouped, isTrue);
    });

    testWidgets(
      'preview band renders inside a BackdropGroup over the wallpaper '
      'capture',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('mikcb_preview_');
        final wallpaper = File('${dir.path}/wallpaper.png')
          ..writeAsBytesSync(_tinyPng);
        addTearDown(() {
          // Release the FileImage handle before deleting the temp dir
          // (Windows may hold it open past the last frame; a failed delete
          // is fine — the OS temp dir is swept anyway).
          PaintingBinding.instance.imageCache.clear();
          try {
            dir.deleteSync(recursive: true);
          } on FileSystemException {
            // ignored
          }
        });

        SharedPreferences.setMockInitialValues({});
        final settings = TimetableSettings(
          sections: const [
            SectionTime(startTime: '08:00', endTime: '08:45'),
            SectionTime(startTime: '08:55', endTime: '09:40'),
            SectionTime(startTime: '10:00', endTime: '10:45'),
            SectionTime(startTime: '10:55', endTime: '11:40'),
            SectionTime(startTime: '14:00', endTime: '14:45'),
          ],
          homePageWallpaperPath: wallpaper.path,
        );
        final provider = await createInitializedTestProvider(tester);

        await tester.pumpWidget(
          TestApp(
            home: FrostedSheetSettingsPreview(
              provider: provider,
              settings: settings,
              week: 1,
              blurSigma: 15,
              tintAlpha: 0.5,
              barrierAlpha: 0.2,
              blurEnabled: true,
              glassMode: FrostedGlassMode.liquidGlass,
              liquidGlassTuning: LiquidGlassTuning.presetDense,
              onOpenDemoSheet: () {},
            ),
          ),
        );
        // Let the wallpaper file decode and the luminance sample settle.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.byType(BackdropGroup), findsOneWidget);
        expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
        final fill = tester.widget<HomePageChromeGlassFill>(
          find.byType(HomePageChromeGlassFill),
        );
        // 预览侧不自己申请祖先组采样：玻璃形状四边全部越出可见裁剪区，
        // 包内任何边缘处理都够不到可见区（四边越界断言见
        // timetable_week_preview_test.dart 的 chrome glass band 组）。
        expect(fill.useAncestorBackdropGroup, isFalse);
      },
    );
  });

  group('preview scope mirrors the settings band material', () {
    testWidgets('scope carries settings.homeBandGlassMaterial / subpageHeaderBlurStyle', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'gaussian',
        subpageHeaderBlurStyle: HeaderBlurStyle.inspire,
      );
      final provider = await createInitializedTestProvider(tester);

      await tester.pumpWidget(
        TestApp(
          home: FrostedSheetSettingsPreview(
            provider: provider,
            settings: settings,
            week: 1,
            blurSigma: 15,
            tintAlpha: 0.5,
            barrierAlpha: 0.2,
            blurEnabled: true,
            glassMode: FrostedGlassMode.gaussian,
            onOpenDemoSheet: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // 回归背景（2026-09-12）：scope 漏传顶栏材质/子页风格时，预览里的
      // 首页玻璃带（HomePageChromeGlassFill）永远按默认渐进档渲染，与真
      // 实首页不符。
      final scope = tester.widget<FrostedAppearanceScope>(
        find.byType(FrostedAppearanceScope),
      );
      expect(scope.appearance.homeBandGlassMaterial, 'gaussian');
      expect(
        scope.appearance.subpageHeaderBlurStyle,
        HeaderBlurStyle.inspire,
      );
    });
  });
}

Widget _noopFallback(BuildContext context) => const SizedBox.shrink();
