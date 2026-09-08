// 测试目标：真机 "A RenderFlex overflowed by 0.500 pixels on the bottom"（星
// 期信息栏日单元格，timetable_screen.dart 的 fullWeekRowFor）。
//
// 固定 40dp 的星期栏在 opaque 外观下扣掉单元格 3+3 内边距与 0.5dp 底部分隔
// 线后，Column 只剩 33.5dp 可用；考试红点此前作为 Column 子项平铺（2dp 上
// 边距 + 4dp 圆点），把内容顶到 ~34dp 触发底部溢出。修复后红点改为悬浮层
// （Stack + Align，不占布局高度），基础内容恒为 28dp。
//
// 本测试让考试落在当前显示的第 1 周第 1 天，整屏 pump 后断言：
//  1. 不抛任何 RenderFlex 溢出异常（widget 测试里溢出会直接判失败）；
//  2. 考试红点仍然渲染（修复不得丢功能）。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import '../helpers_test_app.dart';

/// 本周一 0 点。provider 激活课表时按开学时间对齐日历周（2026-08-31
/// 口径），屏幕显示周 = 今天所在周；学期起点必须取本周一才能保证
/// 「今天」恒在第 1 周内、红点恒落在第一格。取一次快照供 setUp 与
/// 考试构造共用，避免两处 DateTime.now() 跨午夜抖动。
final DateTime _startOfCurrentTestWeek = () {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - 1));
}();

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    // 学期开始日取本周一：provider 激活课表时按开学时间对齐日历周，
    // 屏幕显示周 = 今天所在周。此前写死 2026-08-31，现实日期跨过第 1 周
    // （9-7 起）后屏幕落在第 2 周，weekday-header-1-1 不复存在、测试恒挂
    // （CI 2026-09-08 实录）。取本周一保证红点恒落第一格；若当天恰为
    // 周一，格子额外带 2dp today 底边框——基础内容恒 28dp、红点是悬浮
    // 层，不改变 33.5dp 预算下的溢出结论。opaque 模式的 0.5dp 分隔线
    // 仍是真机报溢出的最紧场景。
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        semesterStartDate: _startOfCurrentTestWeek,
        semesterWeekCount: 20,
      ),
    );
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

  testWidgets('exam dot in weekday bar renders without flex overflow', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      // addExam 强校验关联课程存在（linked_course_not_found），先建课。
      await provider.addCourse(
        Course(
          id: 'course-1',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.addExam(
        Exam(
          id: 'exam-1',
          courseId: 'course-1',
          name: '高等数学期末考试',
          dateTime: DateTime(
            _startOfCurrentTestWeek.year,
            _startOfCurrentTestWeek.month,
            _startOfCurrentTestWeek.day,
            8,
            30,
          ),
          startTime: '08:30',
          endTime: '10:30',
          location: 'A-301',
          createdAt: DateTime(2026, 4, 12),
          updatedAt: DateTime(2026, 4, 12),
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('weekday-header-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('weekday-exam-dot')), findsOneWidget);
  });
}
