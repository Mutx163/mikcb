import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/course_grid_surface_host.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';
import 'package:university_timetable/widgets/timetable_week_preview.dart';

import '../helpers_test_app.dart';

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
  });

  Future<void> pumpPreview(
    WidgetTester tester, {
    required TimetableSettings settings,
    bool? applyHomePageBackdrop,
  }) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance(
            sheetBlurSigma: settings.frostedSheetBlurSigma,
            sheetTintAlpha: settings.frostedSheetTintAlpha,
            sheetBarrierAlpha: settings.frostedSheetBarrierAlpha,
            blurEnabled: settings.frostedBlurEnabled,
            glassMode: settings.frostedGlassMode,
            liquidGlassTuning: settings.liquidGlassTuning,
          ),
          child: SizedBox(
            width: 360,
            height: 320,
            child: TimetableWeekPreview(
              provider: provider,
              settings: settings,
              week: provider.currentWeek,
              maxVisibleSections: 4,
              applyHomePageBackdrop: applyHomePageBackdrop ?? true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('applyHomePageBackdrop defaults to true', (tester) async {
    // Regression guard: the settings previews rely on the default to show the
    // wallpaper. Two of them used to render flat because no caller passed it.
    final provider = await createInitializedTestProvider(tester);
    final preview = TimetableWeekPreview(
      provider: provider,
      settings: TimetableSettings.defaults(),
      week: 1,
    );
    expect(preview.applyHomePageBackdrop, isTrue);
  });

  group('glass hosting matches the home grid', () {
    testWidgets('gaussian grid gets a shared BackdropGroup', (tester) async {
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        ),
      );

      expect(find.byType(CourseGridSurfaceHost), findsOneWidget);
      expect(find.byType(BackdropGroup), findsAtLeastNWidgets(1));
    });

    for (final style in [CourseCardSurfaceStyle.solid]) {
      testWidgets('$style grid needs no glass host', (tester) async {
        await pumpPreview(
          tester,
          settings: TimetableSettings.defaults().copyWith(
            courseCardSurfaceStyle: style,
          ),
        );

        expect(find.byType(CourseGridSurfaceHost), findsOneWidget);
      });
    }
  });

  testWidgets('renders every surface style without throwing', (tester) async {
    for (final style in CourseCardSurfaceStyle.values) {
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          courseCardSurfaceStyle: style,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'style: $style');
    }
  });

  // 回归护栏：星期栏玻璃形状必须四边全部越出可见裁剪区，可见区内只出现
  // 玻璃内部。此前底边贴着带边界，thickness 档（最高 40）宽度的边缘折射/
  // 边缘光在 40dp 孤立星期栏玻璃条上糊成一条贴着文字下方的粗白亮线，随
  // 「预览去模拟标题行」「玻璃包升级」等周边改动已经复发两次；任何把底边
  // 改回贴边的实现都会在此断言爆掉。
  group('chrome glass band edges never land inside the visible strip', () {
    Future<File> writeOpaqueWallpaper() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 1000000, 1000000),
        Paint()..color = const Color(0xFF6688AA),
      );
      final image = await recorder.endRecording().toImage(16, 16);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await Directory.systemTemp.createTemp('weekbar_glass_test');
      return File('${dir.path}/wall.png')
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    testWidgets('isolated weekday strip overdraws all four sides',
        (tester) async {
      final wallpaper = (await tester.runAsync(writeOpaqueWallpaper))!;
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          homePageWallpaperPath: wallpaper.path,
          homePageWeekdayBarBlurEnabled: true,
          frostedGlassMode: FrostedGlassMode.liquidGlass,
        ),
      );

      expect(find.byType(HomePageChromeGlassFill), findsOneWidget);
      final glassRect = tester.getRect(find.byType(HomePageChromeGlassFill));
      final previewRect = tester.getRect(find.byType(TimetableWeekPreview));
      const headerHeight = 40.0; // 预览私有常量 _headerHeight
      expect(
        glassRect.top,
        lessThanOrEqualTo(
          previewRect.top - homePageChromeGlassTopEdgeOverdraw,
        ),
      );
      expect(
        glassRect.left,
        lessThanOrEqualTo(previewRect.left - homePageChromeGlassEdgeOverdraw),
      );
      expect(
        glassRect.right,
        greaterThanOrEqualTo(
          previewRect.right + homePageChromeGlassEdgeOverdraw,
        ),
      );
      expect(
        glassRect.bottom,
        greaterThanOrEqualTo(
          previewRect.top +
              headerHeight +
              homePageChromeGlassBottomEdgeOverdraw,
        ),
      );
    });
  });
}
