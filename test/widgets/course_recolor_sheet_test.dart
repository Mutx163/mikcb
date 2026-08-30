import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/course_recolor_sheet.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';

import '../helpers_test_app.dart';

// 「课表重新配色」弹层核心口径：换一批 → 上一套回到导入原色 → 下一套再
// 前进。配色落库跨 plugin channel，断言一律走 runAsync 轮询（仓库惯例）。

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

Course _entry({
  required String id,
  required String name,
  required int dayOfWeek,
  required String color,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: color,
  );
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

  testWidgets('换一批 → 上一套回原色 → 下一套再前进（历史往返）', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.runAsync(() async {
      await provider.addCourse(
        _entry(id: 'c1', name: '高等数学', dayOfWeek: 1, color: '#E91E63'),
      );
      await provider.addCourse(
        _entry(id: 'c2', name: '线性代数', dayOfWeek: 3, color: '#4CAF50'),
      );
    });
    final originalColors = provider.courses.map((c) => c.color).toList();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showCourseRecolorSheet(context),
                  child: const Text('open-recolor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open-recolor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('课表重新配色'), findsOneWidget);
    // 历史为空：导航按钮禁用（点了也没反应），只有主按钮可点。
    expect(find.text('上一套'), findsOneWidget);
    expect(find.text('下一套'), findsOneWidget);

    await tester.tap(find.text('换一批颜色'));
    var applied = false;
    for (var i = 0; i < 60 && !applied; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      applied = provider.courses
          .map((c) => c.color)
          .toList()
          .toString()
          .contains('#E91E63') ==
          false;
    }
    expect(applied, true, reason: '换一批必须真的改掉全部课程颜色');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 两门课同名才共享色；这里名字不同，必须拿到两种不同颜色。
    final batchColors = provider.courses.map((c) => c.color).toList();
    expect(batchColors[0], isNot(batchColors[1]));
    // 历史 = 导入原色快照 + 新批次，指向第 2 套。
    expect(find.text('第 2/2 套'), findsOneWidget);

    await tester.tap(find.text('上一套'));
    var restored = false;
    for (var i = 0; i < 60 && !restored; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      restored = provider.courses.map((c) => c.color).toList().toString() ==
          originalColors.toString();
    }
    expect(restored, true, reason: '上一套必须恢复导入原色');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('第 1/2 套'), findsOneWidget);

    await tester.tap(find.text('下一套'));
    var forwarded = false;
    for (var i = 0; i < 60 && !forwarded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      forwarded = provider.courses.map((c) => c.color).toList().toString() ==
          batchColors.toString();
    }
    expect(forwarded, true, reason: '下一套必须回到刚才那批随机配色');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('第 2/2 套'), findsOneWidget);
  });

  testWidgets('换一批之后再换一批：快照仍在，可一路切回导入原色', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.runAsync(() async {
      await provider.addCourse(
        _entry(id: 'c1', name: '高等数学', dayOfWeek: 1, color: '#E91E63'),
      );
      await provider.addCourse(
        _entry(id: 'c2', name: '线性代数', dayOfWeek: 3, color: '#4CAF50'),
      );
    });
    final originalColors = provider.courses.map((c) => c.color).toList();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showCourseRecolorSheet(context),
                  child: const Text('open-recolor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open-recolor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    Future<bool> tapUntil(
      String label,
      bool Function() condition,
    ) async {
      await tester.tap(find.text(label));
      for (var i = 0; i < 60 && !condition(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      return condition();
    }

    List<String> colors() => provider.courses.map((c) => c.color).toList();

    expect(
      await tapUntil('换一批颜色', () => !colors().contains('#E91E63')),
      true,
      reason: '第一批换色必须落地',
    );
    final firstBatch = colors();
    expect(
      await tapUntil(
        '换一批颜色',
        () => colors().toString() != firstBatch.toString(),
      ),
      true,
      reason: '第二批必须换出与第一批不同的观感',
    );
    expect(find.text('第 3/3 套'), findsOneWidget);

    // 连按两次上一套：第二批 → 第一批 → 导入原色。
    expect(
      await tapUntil('上一套', () => colors().toString() == firstBatch.toString()),
      true,
    );
    expect(
      await tapUntil(
        '上一套',
        () => colors().toString() == originalColors.toString(),
      ),
      true,
      reason: '快照层必须能一路切回导入原色',
    );
    expect(find.text('第 1/3 套'), findsOneWidget);
  });

  testWidgets('目录条目 courseRecolor 的 open 直接拉起弹层（八宫格/圆钮/坞共用分发）', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.runAsync(() async {
      await provider.addCourse(
        _entry(id: 'c1', name: '高等数学', dayOfWeek: 1, color: '#E91E63'),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      homeMenuEntryById('courseRecolor')!.open(context),
                  child: const Text('open-catalog'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open-catalog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('课表重新配色'), findsOneWidget);
  });
}
