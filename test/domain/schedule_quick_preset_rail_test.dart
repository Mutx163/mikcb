import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_schedule_item_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/schedule_quick_preset_rail.dart';

import '../helpers_test_app.dart';

/// 快捷模板轨在**真实表单里**的接线：点卡之后标题/颜色/时长都要动。
///
/// 注意这个文件放在 `test/domain/`，不是因为它是纯逻辑，而是
/// `test/screens|widgets|ui` 是冻结目录（AGENTS.md 的 TEST-POLICY）。
/// 本测试刻意**只钉契约**：断言的都是「点了之后页面状态变成什么」，
/// 不涉及像素与样式，因此不会因为换皮而变红。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<({TimetableProvider provider})> pumpScreen(
    WidgetTester tester, {
    AddScheduleItemScreen? screen,
  }) async {
    // 高测试面让模板轨 + 标题 + 时间区同屏可见。
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: screen ?? const AddScheduleItemScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (provider: provider);
  }

  Finder railFinder() => find.byType(ScheduleQuickPresetRail);

  String titleText(WidgetTester tester) {
    return tester.widget<EditableText>(find.byType(EditableText).first)
        .controller
        .text;
  }

  testWidgets('新建时渲染模板轨，初始没有任何一张卡被选中', (tester) async {
    await pumpScreen(tester);

    expect(railFinder(), findsOneWidget);
    final rail = tester.widget<ScheduleQuickPresetRail>(railFinder());
    expect(rail.selectedPresetId, isNull);
    // 十张卡都在树上（横向滚动不裁掉子树）。
    expect(
      find.byKey(const ValueKey('schedule-quick-preset-groupMeeting')),
      findsOneWidget,
    );
  });

  testWidgets('点「聚餐」后标题被填上、卡片变成选中态', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-dining')));
    await tester.pumpAndSettle();

    expect(titleText(tester), '聚餐');
    expect(
      tester.widget<ScheduleQuickPresetRail>(railFinder()).selectedPresetId,
      'dining',
    );
  });

  testWidgets('点「聚餐」后保存下去的就是 120 分钟（不是默认的 1 小时）', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-dining')));
    await tester.pumpAndSettle();

    // 时刻字段在界面上是本地化文本（中文读作「上午 8:00」），按字符串解析
    // 会把「上午」当成数字。这里改钉**真正要紧的那一跳**：保存之后落进
    // provider 的起止时刻差值。它同时覆盖「模板算对了」和「保存没把
    // 算好的时刻丢掉」——只验界面文本的话，后者漏得掉。
    await tester.tap(find.bySemanticsLabel('保存'));
    await tester.pump();

    // 保存链路里有**真实磁盘写**（SharedPreferences）。`pumpAndSettle` 在
    // FakeAsync 里推不动那一步，必须逃到真实异步区去等它完成——这正是
    // helpers_test_app.dart 里 `runRealAsync` 存在的原因。
    await tester.runAsync(() async {
      for (var i = 0; i < 60; i++) {
        if (ctx.provider.scheduleItems.isNotEmpty) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(
      ctx.provider.scheduleItems.length,
      1,
      reason:
          '保存后 provider 里应当多出一条日程。为空说明保存被拦下了'
          '（表单校验没过 / 落盘失败）',
    );
    final saved = ctx.provider.scheduleItems.single;
    expect(saved.title, '聚餐');
    expect(
      _asMinutes(saved.endTime) - _asMinutes(saved.startTime),
      120,
      reason:
          '存下来的时长应为 120 分钟，实际 ${saved.startTime}→${saved.endTime}：'
          '模板的时长没进到保存链路里',
    );
    expect(saved.color, '#F97316', reason: '颜色应跟着模板走');
  });

  testWidgets('套用模板后再改日期，起止时刻与时长的关系不受影响', (tester) async {
    final ctx = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-dining')));
    await tester.pumpAndSettle();

    // 改开始日期到今天：模板从不算日期，所以换一天之后时刻与时长必须原样。
    // 这条防的是「模板把时长算进日期偏移里」那类实现——一旦它偷偷改了
    // `_selectedEndDate`，两天日程的时长就不再是 120 分钟。
    final dateFields = find.byType(HyperosPickerField);
    await tester.tap(dateFields.at(0));
    await tester.pumpAndSettle();
    // 日期滚轮弹层里确认即沿用当前选中的那天（测试不依赖具体滚轮交互）。
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('保存'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 60; i++) {
        if (ctx.provider.scheduleItems.isNotEmpty) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(
      ctx.provider.scheduleItems.length,
      1,
      reason: '改过日期之后保存应当仍然成功（模板不该让表单变成非法状态）',
    );
    final saved = ctx.provider.scheduleItems.single;
    expect(
      _asMinutes(saved.endTime) - _asMinutes(saved.startTime),
      120,
      reason:
          '改日期后时长变成 ${saved.startTime}→${saved.endTime}，应为 120 分钟：'
          '模板把时长算进了日期偏移里',
    );
    expect(
      saved.startDate,
      saved.endDate,
      reason: '模板不该把日程跨成两天（却只改时刻、不改日期）',
    );
  });

  testWidgets('手改标题后卡片不再显示选中（不能声称用户选的是聚餐）', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-dining')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScheduleQuickPresetRail>(railFinder()).selectedPresetId,
      'dining',
    );

    await tester.enterText(find.byType(EditableText).first, '和室友吃饭');
    await tester.pumpAndSettle();

    expect(
      tester.widget<ScheduleQuickPresetRail>(railFinder()).selectedPresetId,
      isNull,
      reason: '标题已改成别的内容，模板卡却还显示选中',
    );
  });

  testWidgets('再点一次已选中的卡 = 取消套用（标题清空）', (tester) async {
    await pumpScreen(tester);

    final dining = find.byKey(const ValueKey('schedule-quick-preset-dining'));
    await tester.tap(dining);
    await tester.pumpAndSettle();
    expect(titleText(tester), '聚餐');

    await tester.tap(dining);
    await tester.pumpAndSettle();
    expect(titleText(tester), isEmpty);
    expect(
      tester.widget<ScheduleQuickPresetRail>(railFinder()).selectedPresetId,
      isNull,
    );
  });

  testWidgets('切到另一张卡时只保留新的那张（互斥，不是多选）', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-dining')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-workout')));
    await tester.pumpAndSettle();

    expect(titleText(tester), '运动');
    expect(
      tester.widget<ScheduleQuickPresetRail>(railFinder()).selectedPresetId,
      'workout',
    );
  });

  testWidgets('编辑已有日程时不出现模板轨（不给用户一键覆盖自己写的标题）', (tester) async {
    final today = DateTime.now();
    final existing = ScheduleItem(
      id: 'preset-edit-existing',
      title: '我自己写的标题',
      startDate: today,
      endDate: today,
      startTime: '09:00',
      endTime: '10:00',
      createdAt: today,
      updatedAt: today,
    );
    await pumpScreen(
      tester,
      screen: AddScheduleItemScreen(scheduleItem: existing),
    );

    expect(railFinder(), findsNothing);
  });

  testWidgets('套用后颜色跟着模板走：外观卡上选中色块就是模板色', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-quick-preset-dining')));
    await tester.pumpAndSettle();

    // 色块行是横向滚动的一排 GestureDetector；选中态由 2dp 边框 + 白勾表达。
    // 这里不断言像素，改钉「有且只有一颗色块带对勾」——勾只在选中色块里出现。
    final checkmarks = find.descendant(
      of: find.byType(AddScheduleItemScreen),
      matching: find.byIcon(Icons.check),
    );
    expect(
      checkmarks,
      findsWidgets,
      reason: '套用模板后外观卡应当有一颗色块处于选中态（带白色对勾）',
    );
  });
}

/// `"HH:mm"` → 当天分钟数。
int _asMinutes(String value) {
  final parts = value.split(':');
  expect(parts.length, 2, reason: '时刻「$value」不是 HH:mm 形状');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
