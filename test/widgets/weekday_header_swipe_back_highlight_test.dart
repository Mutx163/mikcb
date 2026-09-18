// 回归：日视图「滑出去又滑回来」后，星期栏多亮一格且不恢复。
//
// 症状（用户反馈）：日视图左右滑动，有时某个日期数字的高亮颜色不回到当前
// 显示的那一天；点摘要卡的「回到今天」就正常了。
//
// 根因：日视图滑动中，星期栏高亮走的是「页中点预览」——[_dayHeaderPreview]
// 在 pager 过中点时先指向目标日，松手 ScrollEnd 时由 [_settleDayViewPage]
// 清空并落定真正的选择。若手势滑过中点后又滑回**已选那天**：
//   1. onPageChanged 命中「目标 == 已选」分支直接返回，预览标记留在被滑
//      过去的那一天（旧的 bug）；
//   2. ScrollEnd 时选择没变 → 不 setState → 这一帧没有任何重建。
// 于是星期栏把旧预览的样子一直留在屏上，直到别的原因触发一次重建
// （「回到今天」正是这种整屏重建，所以它能"修好"）。
//
// 本测试用一次「过中点再滑回」的手势复现：滑出去的那一天不得仍带选中高亮色。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

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

/// 等到日分页彻底静止：回弹动画跑完、ScrollEnd 落定选择并重绘。
Future<void> _pumpUntilDayPagerSettled(
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

/// 星期栏某一天「星期」标签的实际颜色（格子里的第一个 Text）。
Color? _headerLabelColor(WidgetTester tester, int week, int day) {
  final slot = find.byKey(ValueKey('weekday-header-$week-$day'));
  if (slot.evaluate().isEmpty) {
    return null;
  }
  final text = find
      .descendant(of: slot.first, matching: find.byType(Text))
      .first;
  return tester.widget<Text>(text).style?.color;
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

  testWidgets('滑出中点又滑回当天后，星期栏高亮只剩当天', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();

    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
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
    await _pumpTimetableFrame(tester);

    // 点今天那一格进日视图，停在今天。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);
    await _pumpUntilDayPagerSettled(tester);
    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
      reason: '日视图应落在今天',
    );

    // 同周内的相邻一天：往周中方向滑，保证不跨周（跨周会换星期栏整行）。
    final goForward = today.weekday <= 3;
    final otherDay = goForward ? today.weekday + 1 : today.weekday - 1;
    final todayColor = _headerLabelColor(tester, 1, today.weekday);
    final otherColorBefore = _headerLabelColor(tester, 1, otherDay);
    expect(todayColor, isNotNull);
    expect(
      otherColorBefore,
      isNot(todayColor),
      reason: '滑动前，相邻那天的星期标签不应带选中高亮色',
    );

    // 过中点（预览高亮切到 otherDay）后滑回今天再松手。
    final rect = tester.getRect(
      find.byKey(const ValueKey('day-view-swipe-area')),
    );
    final dx = rect.width * 0.7 * (goForward ? -1 : 1);
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(Offset(dx, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(Offset(-dx, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await _pumpUntilDayPagerSettled(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
      reason: '分页应回弹停在今天',
    );
    expect(
      _headerLabelColor(tester, 1, otherDay),
      isNot(_headerLabelColor(tester, 1, today.weekday)),
      reason: '滑回今天后，滑出去那一天不应仍带选中高亮色（预览标记必须撤销）',
    );
  });
}
