import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/course_grid_surface_host.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';
import 'package:university_timetable/widgets/timetable_week_preview.dart';

import '../helpers_test_app.dart';
import '../helpers_weather.dart';

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
    // 无壁纸时「高斯模糊」没有可采样的磨砂来源，预览与首页一样回退实体卡，
    // 也就没有必要再包一层 BackdropGroup。
    testWidgets('gaussian without a wallpaper falls back to solid', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        ),
      );

      expect(find.byType(CourseGridSurfaceHost), findsOneWidget);
      // 只检查课程卡宿主子树：预览其余玻璃带（标题/星期栏）自带
      // BackdropGroup，与课程卡是否回退实体卡无关。
      expect(
        find.descendant(
          of: find.byType(CourseGridSurfaceHost),
          matching: find.byType(BackdropGroup),
        ),
        findsNothing,
        reason: 'no wallpaper -> nothing to blur, cards render solid',
      );
    });

    testWidgets('gaussian over a wallpaper: host mirrors the cards (no group on VM)', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('week_preview_wallpaper');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}wall.png')
        ..writeAsBytesSync([1, 2, 3, 4]);
      await pumpPreview(
        tester,
        settings: TimetableSettings.defaults().copyWith(
          homePageWallpaperPath: file.path,
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        ),
      );

      expect(find.byType(CourseGridSurfaceHost), findsOneWidget);
      // 宿主与课程卡同判（卡片高斯档已按运行时模糊能力回退实体）：
      // 测试环境（VM）liveBlurSupported 恒 false → 管线不可用 → 卡片实体
      // 渲染，宿主不包 BackdropGroup，与首页网格口径一致。
      // 「真机管线可用时高斯+壁纸应包 Group」这半边契约由
      // effectiveCourseCardSurfaceStyle(gaussianBlurAvailable:) 单测钉住，
      // VM 无法复现真实模糊能力，观感由真机验收兜底。
      expect(
        find.descendant(
          of: find.byType(CourseGridSurfaceHost),
          matching: find.byType(BackdropGroup),
        ),
        findsNothing,
        reason: '模糊管线不可用时高斯卡回退实体，无需共享背景捕获',
      );
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
        expect(
          find.descendant(
            of: find.byType(CourseGridSurfaceHost),
            matching: find.byType(BackdropGroup),
          ),
          findsNothing,
        );
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

  // 回归护栏：窄带厚度按带高比例封顶，边缘光仍可见但不再糊成
  // 粗白线。此前底边贴着边界且厚度不封顶，thickness档（最高 40）
  // 的边缘区占满整个 40dp 孤立星期栏玻璃条，底边高光糊成一条
  // 贴着文字下方的粗白亮线。
  group('chrome glass band narrow strip caps thickness', () {
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

    testWidgets('isolated weekday strip caps glass thickness and keeps edge', (
      tester,
    ) async {
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
      final fill = tester.widget<HomePageChromeGlassFill>(
        find.byType(HomePageChromeGlassFill),
      );
      // 40dp 窄带按 height*0.28 封顶 ~11，仍是液态玻璃材质，只是不会
      // 让边缘光占满整个条带。
      expect(fill.maxRefraction, isNotNull);
      expect(fill.maxRefraction, inInclusiveRange(8.0, 14.0));
      // 顶边 / 左右 / 底边都越界：上缘发丝缝、角落倒三角、底边那条发丝边
      // 一律推出可见带切掉（底边只多画 4px，可见区内的折射仍在）。
      final glassRect = tester.getRect(find.byType(HomePageChromeGlassFill));
      final previewRect = tester.getRect(find.byType(TimetableWeekPreview));
      const headerHeight = 40.0;
      expect(
        glassRect.top,
        lessThan(previewRect.top),
        reason: 'top still overdrawn to hide hairline seam',
      );
      expect(
        glassRect.bottom,
        closeTo(
          previewRect.top +
              headerHeight +
              homePageChromeGlassBottomEdgeOverdraw,
          0.5,
        ),
        reason: 'bottom overdrawn by the same 4px as the home band',
      );
    });
  });

  group('天气行由外部显式传入', () {
    /// 造一个「今天有课」的 provider：semesterStartDate 会被归一到本周周一，
    /// 于是第 1 周第 `today.weekday` 天正好是今天，落在预报窗口内。
    Future<TimetableProvider> providerWithTodayCourse(WidgetTester tester) async {
      final provider = await createInitializedTestProvider(tester);
      final today = DateTime.now();
      await runRealAsync(tester, () async {
        await provider.updateTimetableSettings(
          provider.settings.copyWith(semesterStartDate: today),
        );
        await provider.addCourse(
          Course(
            id: 'preview-weather-course',
            name: '数据结构',
            teacher: '张老师',
            location: 'A101',
            dayOfWeek: today.weekday,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
          ),
        );
      });
      return provider;
    }

    Future<void> pumpWithWeather(
      WidgetTester tester, {
      required TimetableProvider provider,
      required WeatherProvider ancestorWeather,
      WeatherProvider? passedWeather,
    }) async {
      await tester.pumpWidget(
        // 天气 provider 挂在**祖先**上：导出文档就是插进根 Overlay 渲染的，
        // 环境里查得到真实 provider。这正是「不传就不画」要防的场景。
        ChangeNotifierProvider<WeatherProvider>.value(
          value: ancestorWeather,
          child: TestApp(
            home: SizedBox(
              width: 360,
              height: 320,
              child: TimetableWeekPreview(
                provider: provider,
                settings: provider.settings,
                week: 1,
                maxVisibleSections: 4,
                applyHomePageBackdrop: false,
                weather: passedWeather,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('传了天气源就画出来（设置页预览要跟首页一致）', (tester) async {
      final provider = await providerWithTodayCourse(tester);
      final weather = await readyWeatherProvider(tester);

      await pumpWithWeather(
        tester,
        provider: provider,
        ancestorWeather: weather,
        passedWeather: weather,
      );

      expect(find.text('小雨 · 23°'), findsOneWidget);
    });

    testWidgets('不传天气源时一张卡都不带天气（导出分享图走这条路）', (tester) async {
      final provider = await providerWithTodayCourse(tester);
      final weather = await readyWeatherProvider(tester);

      // 祖先上挂着能出数据的天气 provider，但预览不接收它。
      await pumpWithWeather(tester, provider: provider, ancestorWeather: weather);

      // 分享图不带天气靠的就是「显式不传」；这条红了说明有人改成了自动查
      // provider，天气会漏进导出图。
      expect(weather.forecast, isNotNull);
      expect(find.text('小雨 · 23°'), findsNothing);
      expect(find.text('数据结构'), findsWidgets);
    });
  });
}
