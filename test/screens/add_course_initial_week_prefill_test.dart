import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

/// `AddCourseScreen.initialWeek` 必须真的落到表单初值上（第 34 轮）。
///
/// 四个入口都在传它（`timetable_screen.dart:7344` 日/周视图空格「+」带着那一周、
/// `:8832`/`:9751` 传 `_visibleWeek`、`task_list_screen.dart:272`），
/// 而新建分支只写了 `dayOfWeek`/`startSection`/`endSection` 三个初值 —— 周次没接。
/// 于是在第 8 周的空格里加课，周次摘要仍是"第 1 周-第 16 周"，
/// 用户不手动改就从第 1 周开始排课；同族参数 `initialDayOfWeek`、
/// `initialStartSection` 都是生效的，唯独周次丢失。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
    // 故意不用第 8 周，免得"当前周"之类的文案把反面用例污染成假绿。
    currentWeek: 3,
    createdAt: now,
    lastUsedAt: now,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'did_migrate_app_logs_default': true,
      'did_migrate_live_hide_prefix_default': true,
      'timetable_profiles': jsonEncode([profile.toJson()]),
      'active_timetable_profile_id': profile.id,
      'time_schemes': '[]',
    });
    StorageService().resetForTesting();
  });

  Future<void> pumpForm(WidgetTester tester, {int? initialWeek}) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(home: AddCourseScreen(initialWeek: initialWeek)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final formScrollable = find.descendant(
      of: find.byType(AddCourseScreen),
      matching: find.byType(Scrollable),
    );
    await tester.drag(formScrollable.first, const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('带 initialWeek 进来时，周次摘要从那一周开始', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    await pumpForm(tester, initialWeek: 8);

    expect(
      find.textContaining(l10n.weekLabel(8)),
      findsWidgets,
      reason: '第 8 周的空格加课，摘要却仍写"第 1 周-第 16 周" = initialWeek 没被读',
    );
  });

  testWidgets('不传 initialWeek 时保持原有初值（第 1 周）', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    await pumpForm(tester);

    expect(
      find.textContaining(l10n.weekLabel(8)),
      findsNothing,
      reason: '没有入口周次时不该凭空跳到第 8 周',
    );
    expect(find.textContaining(l10n.weekLabel(1)), findsWidgets);
  });
}
