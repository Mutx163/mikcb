// 内置壁纸（bokeh-lava-gradient）首页回归测试。
//
// 内置壁纸由代码渲染成位图，没有磁盘文件，因此必须与图片壁纸共用同一套
// 背景判定（hasHomePageBackdrop）、亮度采样与玻璃管线；这里锁死「选中内置
// 壁纸后首页真的把它当作背景」，避免后续有人把判定退回只查文件。
import 'dart:async';
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
import 'package:university_timetable/ui/background/bokeh_lava_gradient.dart';
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

/// 泵几帧让首页完成首帧构建与后台初始化的 setState 落地。
///
/// **刻意不用 `tester.runAsync`**：TimetableScreen 的 Ticker 与 runAsync
/// 假时钟会互相等待，历史上表现为整用例挂满 10 分钟超时（同款注释见
/// timetable_home_card_fallback_test）。本文件断言的「背景层存在/不存在」
/// 是构建期属性（BokehLavaGradient / 内置位图 Image 是否在树上），无需
/// 真实异步管线收敛。
Future<void> _pumpHome(
  WidgetTester tester,
  TimetableSettings settings, {
  required bool expectBackdrop,
}) async {
  _seedInitializedPrefs(settings);
  final provider = TimetableProvider(autoInitialize: false);
  unawaited(provider.initialize());
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
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // 有背景时首页背景层必须画出内置壁纸（动画 BokehLavaGradient 或位图
  // Image）；无背景时两者都不应出现（只有主题兜底色）。
  final hasAnimated = find.byType(BokehLavaGradient).evaluate().isNotEmpty;
  final hasStatic =
      find
          .byWidgetPredicate(
            (w) => w is Image && w.image is BuiltInWallpaperImage,
          )
          .evaluate()
          .isNotEmpty;
  if (expectBackdrop) {
    expect(
      hasAnimated || hasStatic,
      isTrue,
      reason: '内置壁纸应以 BokehLavaGradient 动画或静态位图渲染',
    );
  } else {
    expect(hasAnimated, isFalse, reason: '无背景时不应渲染内置壁纸动画');
    expect(hasStatic, isFalse, reason: '无背景时不应渲染内置壁纸位图');
  }
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    // TimetableScreen + Ticker 与 runAsync 假时钟会死锁；本用例只断言
    // 背景层是否出现，不需要真实漂移。
    BokehLavaGradient.debugDisableAnimationForced = true;
  });

  tearDown(() {
    BokehLavaGradient.debugDisableAnimationForced = false;
  });

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
