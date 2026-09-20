import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
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
    String? homeBandGlassMaterial,
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
            homeBandGlassMaterial:
                homeBandGlassMaterial ?? kDefaultHomeBandGlassMaterial,
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

  /// 一张不透明壁纸：让预览真的走进「有背景」那条路（玻璃带只在 hasBackdrop 时建）。
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

  // 回归护栏：窄带厚度按带高比例封顶，边缘光仍可见但不再糊成
  // 粗白线。此前底边贴着边界且厚度不封顶，thickness档（最高 40）
  // 的边缘区占满整个 40dp 孤立星期栏玻璃条，底边高光糊成一条
  // 贴着文字下方的粗白亮线。
  group('chrome glass band narrow strip caps thickness', () {
    testWidgets('isolated weekday strip caps glass thickness and keeps edge', (
      tester,
    ) async {
      final wallpaper = (await tester.runAsync(writeOpaqueWallpaper))!;
      await pumpPreview(
        tester,
        homeBandGlassMaterial: 'liquid',
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
      // 顶边 / 左右越界：上缘发丝缝、角落倒三角一律推出可见带切掉；**底边不推**
      // （液态档外溢 0，见下一条用例）—— 底边是这条带唯一可见的形状边界。
      final glassRect = tester.getRect(find.byType(HomePageChromeGlassFill));
      final previewRect = tester.getRect(find.byType(TimetableWeekPreview));
      const headerHeight = 40.0;
      // 本用例是液态玻璃：**上边**按「作用带宽度」推出去（默认调参作用带 7、边光带宽 3
      // ⇒ max(8, 7+1) = 8），让可见区最上一行不再朝形状外采样（那会读成一条发丝线）。
      // 下边仍是 0（见下一条用例）。顺带钉住「默认材质就是液态」这个口径：界面只有
      // 「液态 / 实体」两档，默认档不允许再回落到渐进磨砂（那会让上边外溢变 0）。
      expect(
        glassRect.top,
        closeTo(previewRect.top - 8, 0.5),
        reason: '液态档上边必须推出可见区：可见区第一行还在作用带里就会读成一条发丝线',
      );
      expect(
        glassRect.bottom,
        closeTo(
          previewRect.top + headerHeight + homePageFrostedRegionSeamOverlap,
          0.5,
        ),
        reason:
            '带底外溢恒为 0（与底栏药丸同口径），但带本身必须落到课表第一行的上沿：'
            '停在星期行下沿会留下一条没有玻璃的横条，磨砂一开读成一条暗线',
      );
    });

    testWidgets('液态玻璃材质：上边跟着「作用带宽度」走，下边与底栏药丸同为 0', (tester) async {
      // 上边压在屏幕顶边上，着色器在作用带内朝形状**外**采样，朝上落到屏幕外就是空样本
      // （读成近黑）⇒ 作用带 20 时上边外溢必须是 21。
      //
      // 下边是这条带唯一可见的形状边界，所以它必须**留在可见区边界上（外溢 0）**：外溢 > 0
      // 时可见区里只剩被截断的后半截位移曲线（边界上从 `profile(外溢)` 掉到 0 ⇒ 读成一条
      // 线），而且边光带宽 2.1 < 外溢时那一圈也整条被推出可见区 —— 用户 2026-09-20 在
      // 「下边 4」那版上的原话就是「没有黑线，但也没有任何玻璃效果」。底栏药丸是同一份
      // 材质的活证据：零外溢、整圈折射与边光都在可见区里，用户口径「折射效果特别好看」。
      final wallpaper = (await tester.runAsync(writeOpaqueWallpaper))!;
      await pumpPreview(
        tester,
        homeBandGlassMaterial: 'liquid',
        settings: TimetableSettings.defaults().copyWith(
          homePageWallpaperPath: wallpaper.path,
          homePageWeekdayBarBlurEnabled: true,
          liquidGlassPreset: LiquidGlassPreset.custom,
          liquidGlassTuning: const LiquidGlassTuning(refractionBand: 20),
        ),
      );

      final glassRect = tester.getRect(find.byType(HomePageChromeGlassFill));
      final previewRect = tester.getRect(find.byType(TimetableWeekPreview));
      const headerHeight = 40.0;
      expect(glassRect.top, closeTo(previewRect.top - 21, 0.5));
      expect(
        glassRect.bottom,
        closeTo(
          previewRect.top +
              headerHeight +
              homePageFrostedRegionSeamOverlap +
              homePageChromeGlassBottomEdgeOverdraw,
          0.5,
        ),
        reason: '带底落在课表上沿，不再往下多画：多画就等于把可见区里的位移曲线截断成一条线',
      );
    });
  });

  group('转场期间预览带逐帧重画（进场时那根细竖线的对策）', () {
    testWidgets('预览的玻璃带必须被转场重画驱动包住', (tester) async {
      // 用户 2026-09-20 实测：进「课表页面」设置页时，预览的顶栏 / 星期栏里扫出一根
      // 细竖线，位置每次还不太一样。成因见
      // [HomePageChromeGlassTransitionRepaint] 的类注释：转场外壳把整页包进重绘边界，
      // 滑动期间页面只换图层偏移、不重画，而玻璃的形状按 paint 期的屏幕坐标算 ——
      // 不重画就偏，偏到左右那 48px 外溢被扫进可见区时就是那根线。
      //
      // 这里钉「接线」：驱动必须在树上、而且是这条玻璃的祖先（少了它，上面那根线会回来）。
      // 驱动本身的逐帧行为由 `home_page_region_blur_test.dart` 的真转场用例量。
      final wallpaper = (await tester.runAsync(writeOpaqueWallpaper))!;
      await pumpPreview(
        tester,
        homeBandGlassMaterial: 'liquid',
        settings: TimetableSettings.defaults().copyWith(
          homePageWallpaperPath: wallpaper.path,
          homePageWeekdayBarBlurEnabled: true,
        ),
      );

      expect(
        find.ancestor(
          of: find.byType(HomePageChromeGlassFill),
          matching: find.byType(HomePageChromeGlassTransitionRepaint),
        ),
        findsOneWidget,
        reason: '转场期间不重画 ⇒ 形状按旧屏幕位置画 ⇒ 那条直边扫进带里，真机读作一根细线',
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
