// 内置壁纸（bokeh-lava-gradient）首页回归测试。
//
// 内置壁纸由代码渲染成位图，没有磁盘文件，因此必须与图片壁纸共用同一套
// 背景判定（hasHomePageBackdrop）、亮度采样与玻璃管线；这里锁死「选中内置
// 壁纸后首页真的把它当作背景」，避免后续有人把判定退回只查文件。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/background/builtin_wallpaper.dart';
import 'package:university_timetable/utils/home_page_background.dart';

void _seedInitializedPrefs(TimetableSettings settings) {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings,
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

/// 交替真实异步与 pump，让「渲染位图 → 采样亮度 → setState」链跑完。
Future<void> _settleAsyncChain(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpHome(
  WidgetTester tester,
  TimetableSettings settings, {
  required bool expectBackdrop,
}) async {
  _seedInitializedPrefs(settings);
  final provider = TimetableProvider(autoInitialize: false);
  await tester.runAsync(() => provider.initialize());
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        ),
        home: const TimetableScreen(
          enableUpdateCheck: false,
          enableProgressTimer: false,
        ),
      ),
    ),
  );
  await tester.pump();
  await _settleAsyncChain(tester);

  // 有背景时首页背景层必须画出 Image（内置壁纸位图）；无背景时不应出现
  // 背景 Image（只有主题兜底色）。
  final images = find.byType(Image).evaluate().length;
  if (expectBackdrop) {
    expect(images, greaterThan(0), reason: '内置壁纸应作为背景 Image 渲染');
  } else {
    expect(images, 0, reason: '无背景时不应渲染背景 Image');
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('选中内置壁纸后首页把它当作背景（无磁盘文件）', (tester) async {
    final settings = TimetableSettings.defaults().copyWith(
      homePageBuiltInWallpaper: BuiltInWallpaper.lavaDark.value,
    );
    expect(hasHomePageBackdrop(settings), isTrue);
    expect(hasHomePageBackdropImage(settings), isFalse);

    await _pumpHome(tester, settings, expectBackdrop: true);
  });

  testWidgets('未选择任何壁纸时首页没有背景层', (tester) async {
    await _pumpHome(
      tester,
      TimetableSettings.defaults(),
      expectBackdrop: false,
    );
  });

  test('图片文件丢失时回退到内置壁纸，而不是停在失效路径', () {
    final withImage = TimetableSettings.defaults().copyWith(
      homePageBuiltInWallpaper: BuiltInWallpaper.lavaDark.value,
      homePageWallpaperPath: '/definitely/missing/wallpaper.png',
    );
    // 路径指向不存在的文件 → 按「无图片」处理，身份键回落到内置预设。
    expect(
      homePageBackdropKey(withImage),
      builtInWallpaperKey(BuiltInWallpaper.lavaDark),
    );
    expect(hasHomePageBackdrop(withImage), isTrue);
    expect(homePageBackdropProvider(withImage), isA<BuiltInWallpaperImage>());
  });

  test('既无图片也无内置壁纸时没有背景', () {
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: '/definitely/missing/wallpaper.png',
    );
    expect(homePageBackdropKey(settings), isNull);
    expect(hasHomePageBackdrop(settings), isFalse);
    expect(homePageBackdropProvider(settings), isNull);
  });
}
