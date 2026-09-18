// 日视图底部「回今日」浮钮：位置（底部居中）、文案、主题色跟随、以及
// 「不许遮住列表最后一张卡」的底部余量。
//
// 背景：这颗钮原先在顶部摘要卡里（浅色胶囊，`primaryContainer` 底色）。
// 现改为日视图底部居中的玻璃浮钮，图标/文字取**外观里选的主题色本身**
// （不是它的浅色调），并在日课表列表底部补一段滚动余量，让最后一项能滑到
// 钮的上方——和底部导航栏一样不遮内容。
//
// 与周视图右下角的「回本周」是两套独立体系：那颗在日视图一律不显示，这颗
// 只在日视图且当前不是今天时出现，也不受「回本周」的浮态透明度设置影响。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/utils/theme_seed_accent.dart';

import '../helpers_test_app.dart';

/// 刻意挑一个和默认蓝、和星期栏强调色都不同的绿，验证"跟随主题色"。
const String _themeSeedHex = '#4CAF50';
const Color _themeSeedColor = Color(0xFF4CAF50);

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

String _clock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

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

Future<void> _pumpTimetableFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpUntilSettled(
  WidgetTester tester, {
  int maxFrames = 80,
  Duration step = const Duration(milliseconds: 80),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  testWidgets('回今日浮钮：底部居中、跟随主题色、不遮列表最后一项', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();
    final otherDay = today.weekday == 1 ? 2 : today.weekday - 1;

    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
          themeSeedColor: _themeSeedHex,
        ),
      );
      await provider.setCurrentWeek(1);
      // 给相邻那天排 8 门课：列表必然超出视口，才能验证"滑到底不被钮遮"。
      for (var section = 1; section <= 8; section++) {
        await provider.addCourse(
          Course(
            id: 'c$section',
            name: '课程$section',
            teacher: '老师',
            location: 'A10$section',
            dayOfWeek: otherDay,
            startSection: section,
            endSection: section,
            startTime: _clock(7 + section, 0),
            endTime: _clock(7 + section, 45),
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        // 主题色走 ThemeSeedScope（真机由 MaterialApp.builder 挂），这颗钮的
        // 配色就是从它读的，不挂就只能断言到回落色。
        child: const ThemeSeedScope(
          seedHex: _themeSeedHex,
          child: TestApp(
            home: TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    // 先停在今天：这颗钮不该出现（已经在今天，没有"回"的意义）。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);
    await _pumpUntilSettled(tester);
    expect(
      find.byKey(const ValueKey('back-to-today-button')),
      findsNothing,
      reason: '停在今天时不该有「回今日」',
    );

    // 切到相邻那天。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-$otherDay')));
    await _pumpUntilSettled(tester);

    final buttonFinder = find.byKey(const ValueKey('back-to-today-button'));
    expect(buttonFinder, findsOneWidget, reason: '不是今天时应出现「回今日」');
    expect(find.text('回今日'), findsOneWidget);

    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final buttonRect = tester.getRect(buttonFinder);
    // 底部居中：水平居中于屏幕，且贴屏幕底部（经典形态留 24 边距）。
    expect(
      (buttonRect.center.dx - screenSize.width / 2).abs(),
      lessThan(2),
      reason: '按钮应水平居中',
    );
    expect(
      buttonRect.bottom,
      greaterThan(screenSize.height - 80),
      reason: '按钮应在屏幕底部（导航栏上方）',
    );
    // 圆角矩形而非胶囊：按钮不是正方形，也不是整圆。
    expect(buttonRect.width, greaterThan(buttonRect.height));

    // 跟随主题色：图标与文字都取外观里选的 seed 本身。
    final labelStyle = tester
        .widget<Text>(find.descendant(of: buttonFinder, matching: find.text('回今日')))
        .style;
    expect(labelStyle?.color, _themeSeedColor);

    // 摘要卡里不再有第二个入口。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-view-summary')),
        matching: buttonFinder,
      ),
      findsNothing,
      reason: '顶部摘要卡不该再放「回今日」',
    );

    // 列表滑到底：最后一张卡必须停在按钮上方，不被遮住。
    final listFinder = find.byKey(
      PageStorageKey<String>('day-agenda-1-$otherDay'),
    );
    expect(listFinder, findsOneWidget);
    await tester.drag(listFinder, const Offset(0, -1200));
    await _pumpUntilSettled(tester);

    final lastCard = tester.getRect(
      find.byKey(const ValueKey('day-view-edit-card-c8')),
    );
    expect(
      lastCard.bottom,
      lessThanOrEqualTo(tester.getRect(buttonFinder).top),
      reason: '滑到底后最后一张卡应在「回今日」上方，不被遮挡',
    );

    // 点它回今天：选中天回到今天，钮随之消失。
    await tester.tap(buttonFinder);
    await _pumpUntilSettled(tester);
    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
      reason: '「回今日」应把选中天带回今天',
    );
    expect(
      find.byKey(const ValueKey('back-to-today-button')),
      findsNothing,
      reason: '回到今天后按钮应消失',
    );
  });
}
