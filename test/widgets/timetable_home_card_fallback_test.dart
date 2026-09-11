// 首页课程卡片表面样式的回归测试。
//
// **无壁纸**时「高斯模糊」档没有可采样的磨砂背景，卡片统一按实体卡片渲染，
// 网格宿主也不再包共享 BackdropGroup（没有可采样的东西，白付一次捕获）。
//
// 有壁纸时实体 / 高斯各自生效的语义由
// `test/utils/home_page_effective_card_style_test.dart` 确定性覆盖——
// 那两种情形要挂真实的壁纸解码管线，在假时钟下无法稳定收敛，
// 因此不在 widget 层重复。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/background/bokeh_lava_gradient.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/course_grid_surface_host.dart';

Course _course() => Course(
  id: 'c1',
  name: '高等数学',
  teacher: '王老师',
  location: 'A101',
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  startTime: '08:00',
  endTime: '09:40',
);

void _seedInitializedPrefs(TimetableSettings settings) {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: [_course()],
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

/// 挂载首页并推动启动链若干帧。
///
/// **刻意不用 `tester.runAsync`**：本文件断言的是课程卡在构建期就确定的
/// `surfaceStyle`（纯 build 期属性），不依赖预模糊位图 / 壁纸解码等真实异步
/// 管线。让真实管线跑起来只会与假时钟互相等待——历史上这个组合表现为
/// 整个用例挂到 10 分钟超时。壁纸「有没有」由同步的文件存在性检查判定，
/// 因此不上真异步也能覆盖到本文件的全部语义。
Future<void> _pumpHome(WidgetTester tester, TimetableSettings settings) async {
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
}

void main() {
  setUp(() {
    BokehLavaGradient.debugDisableAnimationForced = true;
  });

  tearDown(() {
    BokehLavaGradient.debugDisableAnimationForced = false;
  });

  testWidgets('无壁纸 + 高斯模糊设置：课程卡片按实体卡片渲染', (tester) async {
    final settings = TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    );
    expect(
      effectiveCourseCardSurfaceStyle(settings),
      CourseCardSurfaceStyle.solid,
      reason: '前置条件：无壁纸时该设置收敛为实体卡片',
    );
    await _pumpHome(tester, settings);

    final cards = find.byType(CourseCard);
    expect(cards, findsWidgets, reason: '首页应渲染出课程卡');
    for (var i = 0; i < cards.evaluate().length; i++) {
      expect(
        tester.widget<CourseCard>(cards.at(i)).surfaceStyle,
        CourseCardSurfaceStyle.solid,
        reason: '未设置壁纸时高斯卡片应回退为实体卡片',
      );
    }

    // 网格宿主不应再包共享 BackdropGroup（没有可采样的壁纸）。
    expect(
      find.descendant(
        of: find.byType(CourseGridSurfaceHost),
        matching: find.byType(BackdropGroup),
      ),
      findsNothing,
    );
  });
}