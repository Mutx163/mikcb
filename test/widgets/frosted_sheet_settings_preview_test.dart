import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
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
  group('FrostedSheetSettingsPreview.previewSafeTuning', () {
    test(
      'clamps thickness/blur at the dense preset (artifact-free ceiling)',
      () {
        final safe = FrostedSheetSettingsPreview.previewSafeTuning(
          const LiquidGlassTuning(thickness: 40, blur: 24),
        )!;
        expect(safe.thickness, LiquidGlassTuning.presetDense.thickness);
        expect(safe.blur, LiquidGlassTuning.presetDense.blur);
      },
    );

    test('passes values at or below the ceiling through unchanged', () {
      const tuning = LiquidGlassTuning(thickness: 16, blur: 5);
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(tuning)!;
      // dense 预设现为 thickness 36 / blur 6：低于上限的原样通过。
      expect(safe.thickness, 16);
      expect(safe.blur, 5);
    });

    test('keeps the dense preset itself intact', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        LiquidGlassTuning.presetDense,
      )!;
      expect(safe, LiquidGlassTuning.presetDense);
    });

    test('clamps from a mid-range tuning only up to the ceiling', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        const LiquidGlassTuning(thickness: 32, blur: 18),
      )!;
      // 高于 dense 上限的维度被钳回上限，未超的保持原值。
      expect(safe.thickness, 32);
      expect(safe.blur, LiquidGlassTuning.presetDense.blur);
    });

    test('does not touch the other knobs', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        const LiquidGlassTuning(
          thickness: 40,
          blur: 24,
          tintAlpha: 0.5,
          lightIntensity: 1.8,
          ambientStrength: 0.6,
          saturation: 2.0,
          refractiveIndex: 1.4,
        ),
      )!;
      expect(safe.tintAlpha, 0.5);
      expect(safe.lightIntensity, 1.8);
      expect(safe.ambientStrength, 0.6);
      expect(safe.saturation, 2.0);
      expect(safe.refractiveIndex, 1.4);
    });

    test('null tuning stays null', () {
      expect(FrostedSheetSettingsPreview.previewSafeTuning(null), isNull);
    });
  });

  group('demo sheet follows the selected glass mode', () {
    for (final mode in FrostedGlassMode.values) {
      testWidgets('$mode does not render liquid tiles unless selected', (
        tester,
      ) async {
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

        final liquid = mode == FrostedGlassMode.liquidGlass;
        expect(
          find.byType(HyperosLiquidGlassLayer),
          liquid ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(HyperosLiquidGlassSurface),
          liquid ? findsNWidgets(5) : findsNothing,
        );
      });
    }

    testWidgets(
      'demo route keeps the draft mode across the navigator boundary',
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

        // Without the appearance snapshot, the dialog route would resolve the
        // ancestor's saved liquid mode and build a liquid outer panel + tiles.
        expect(find.byType(HyperosLiquidGlassLayer), findsNothing);
        expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
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
              child: Stack(
                children: [
                  const Positioned.fill(child: UndimmedBackdropCapture()),
                  const HyperosLiquidGlassSurface(
                    role: HyperosLiquidGlassRole.header,
                    useAncestorBackdropGroup: true,
                    child: SizedBox(width: 100, height: 50),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The surface must request ancestor-group sampling — on real shader
      // engines this builds LiquidGlassLayer(useBackdropGroup: true) so the
      // band samples the group's full-size capture instead of its own
      // narrow bounds (the Skia/fake fallback keeps the group key on its
      // own). On this test engine the flag is what we can assert.
      final surface = tester.widget<HyperosLiquidGlassSurface>(
        find.byType(HyperosLiquidGlassSurface),
      );
      expect(surface.useAncestorBackdropGroup, isTrue);
    });

    testWidgets(
      'preview band renders inside a BackdropGroup over the wallpaper '
      'capture and requests ancestor-group sampling',
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
          homePageHeaderBlurEnabled: true,
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
        expect(fill.useAncestorBackdropGroup, isTrue);
        // (The fill's forwarding into HyperosLiquidGlassSurface is a one-line
        // pass-through inside its liquid branch, which this engine cannot
        // reach: liveBlurSupported is false off Android/iOS.)
      },
    );
  });
}
