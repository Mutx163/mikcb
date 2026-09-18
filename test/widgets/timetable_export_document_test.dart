import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/widgets/timetable_export_document.dart';

import '../helpers_test_app.dart';

/// 课表分享图（离屏捕获文档）的渲染契约。
///
/// 这里验的是「图里有什么」：整周/单日两种形态、空白天、以及分享图必须
/// 是**干净**的（不带壁纸、不带「回本周」这类交互件）。
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

Course _course({
  required String id,
  required String name,
  required int dayOfWeek,
  String teacher = '张老师',
  String location = 'A101',
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    // 特意用非默认色：列表左侧的色条要真的读这条 color。
    color: '#E91E63',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
  });

  /// 学期从 2026-09-07（周一）开学，第 3 周的周三 = 2026-09-23。
  TimetableSettings settingsWithSemesterStart() {
    return TimetableSettings.defaults().copyWith(
      semesterStartDate: DateTime(2026, 9, 7),
      semesterWeekCount: 20,
    );
  }

  Future<void> pumpDocument(
    WidgetTester tester, {
    required Widget document,
  }) async {
    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance.defaults,
          child: SingleChildScrollView(
            child: SizedBox(width: 400, child: document),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('周视图：标题、课程都在，且不印「回本周」浮钮', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(
      tester,
      () => provider.addCourse(
        _course(id: 'c1', name: '高等数学', dayOfWeek: 1),
      ),
    );

    await pumpDocument(
      tester,
      document: TimetableExportDocument(
        provider: provider,
        settings: settingsWithSemesterStart(),
        week: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('第 3 周课表'), findsOneWidget);
    expect(find.text('高等数学'), findsWidgets);
    // 浮钮是交互件，只在非当前周出现 —— 第 3 周不是当前周，正是它会冒出来的
    // 场景。分享图上不该有它。
    expect(find.byIcon(Icons.my_location_rounded), findsNothing);
  });

  testWidgets('日视图：标题带周次与周几，列出当天的课', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.addCourse(
        _course(id: 'c1', name: '高等数学', dayOfWeek: 3),
      );
      await provider.addCourse(
        _course(id: 'c2', name: '大学物理', dayOfWeek: 5, teacher: '李老师'),
      );
    });

    await pumpDocument(
      tester,
      document: TimetableExportDocument(
        provider: provider,
        settings: settingsWithSemesterStart(),
        week: 3,
        dayOfWeek: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('第 3 周 · 周三'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('08:00-09:40'), findsOneWidget);
    expect(find.text('张老师 · A101'), findsOneWidget);
    // 别的天的课不能混进来。
    expect(find.text('大学物理'), findsNothing);
  });

  testWidgets('日视图：那天没课时给空态文案', (tester) async {
    final provider = await createInitializedTestProvider(tester);

    await pumpDocument(
      tester,
      document: TimetableExportDocument(
        provider: provider,
        settings: settingsWithSemesterStart(),
        week: 3,
        dayOfWeek: 4,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('这天没有课'), findsOneWidget);
  });

  testWidgets('配了壁纸也不画背景层：分享图保持干净', (tester) async {
    final dir = Directory.systemTemp.createTempSync('timetable_export_wallpaper');
    addTearDown(() => dir.deleteSync(recursive: true));
    final wallpaper = File('${dir.path}${Platform.pathSeparator}wall.png')
      ..writeAsBytesSync([1, 2, 3, 4]);

    final provider = await createInitializedTestProvider(tester);
    final settings = settingsWithSemesterStart().copyWith(
      homePageWallpaperPath: wallpaper.path,
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    );

    await pumpDocument(
      tester,
      document: TimetableExportDocument(
        provider: provider,
        settings: settings,
        week: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byType(UndimmedBackdropCapture),
      findsNothing,
      reason: '导出文档要清掉壁纸，否则离屏渲染里卡片会采到空底面塌成裸 tint',
    );
  });
}
