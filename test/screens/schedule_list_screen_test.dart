import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/screens/schedule_list_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

ScheduleItem _item({
  required String id,
  required String title,
  required DateTime startDate,
  DateTime? endDate,
  String startTime = '09:00',
  String endTime = '10:00',
  ScheduleRecurrence recurrence = ScheduleRecurrence.none,
  bool enabled = true,
}) {
  final now = DateTime.now();
  return ScheduleItem(
    id: id,
    title: title,
    startDate: startDate,
    endDate: endDate ?? startDate,
    startTime: startTime,
    endTime: endTime,
    recurrence: recurrence,
    enabled: enabled,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('空列表渲染空态与添加入口', (tester) async {
    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const ScheduleListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日程安排'), findsOneWidget);
    expect(find.text('暂无日程'), findsOneWidget);
    expect(find.text('添加日程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三组分区与每周重复徽标按分组渲染', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await createInitializedTestProvider(tester);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = [
      _item(
        id: 'list-upcoming',
        title: '小组会',
        startDate: today.add(const Duration(days: 3)),
      ),
      _item(
        id: 'list-past',
        title: '旧事项',
        startDate: today.subtract(const Duration(days: 10)),
      ),
      _item(
        id: 'list-paused',
        title: '暂停事项',
        startDate: today.add(const Duration(days: 5)),
        enabled: false,
      ),
      // 重复以开始日的星期为准：开始日取今天，徽标即为「每周+今天星期」。
      _item(
        id: 'list-weekly',
        title: '周会',
        startDate: today,
        endDate: today.add(const Duration(days: 56)),
        recurrence: ScheduleRecurrence.weekly,
        startTime: '14:00',
        endTime: '15:00',
      ),
    ];
    await runRealAsync(tester, () async {
      for (final item in items) {
        await provider.addScheduleItem(item);
      }
    });

    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const ScheduleListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日程安排'), findsOneWidget);
    expect(find.text('即将到来'), findsOneWidget);
    expect(find.text('已过期'), findsOneWidget);
    expect(find.text('已暂停'), findsOneWidget);
    // 每个条目只出现在自己的分组里（分组串位会在这里暴露）。
    expect(find.text('小组会'), findsOneWidget);
    expect(find.text('旧事项'), findsOneWidget);
    expect(find.text('暂停事项'), findsOneWidget);
    expect(find.text('周会'), findsOneWidget);
    const weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    expect(
      find.text('每周${weekdayLabels[today.weekday - 1]}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
