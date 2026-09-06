import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_schedule_item_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> pumpScreen(WidgetTester tester) async {
    // 高测试面保证四个选择字段同屏可见（矮面会折叠到视口外/顶栏底下）。
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const AddScheduleItemScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Iterable<EditableText> focusedEditables(WidgetTester tester) {
    return tester
        .widgetList<EditableText>(find.byType(EditableText))
        .where((editable) => editable.focusNode.hasFocus);
  }

  testWidgets('标题输入框聚焦后打开时间滚轮，确认关闭不回弹输入法', (tester) async {
    await pumpScreen(tester);

    // 模拟先点标题输入框（输入法已弹出），再去调时间。
    await tester.showKeyboard(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    expect(focusedEditables(tester), isNotEmpty);

    // 四个选择字段：开始日期 / 开始时间 / 结束日期 / 结束时间。
    await tester.tap(find.byType(HyperosPickerField).at(1));
    await tester.pumpAndSettle();
    expect(find.text('选择开始时间'), findsOneWidget);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('选择开始时间'), findsNothing);

    // 弹层关闭后焦点恢复不得把文本框重新顶出输入法。
    expect(focusedEditables(tester), isEmpty);
  });

  testWidgets('标题输入框聚焦后打开日期滚轮，确认关闭不回弹输入法', (tester) async {
    await pumpScreen(tester);

    await tester.showKeyboard(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    expect(focusedEditables(tester), isNotEmpty);

    await tester.tap(find.byType(HyperosPickerField).at(0));
    await tester.pumpAndSettle();
    expect(find.text('开学日期'), findsOneWidget);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('开学日期'), findsNothing);

    expect(focusedEditables(tester), isEmpty);
  });
}
