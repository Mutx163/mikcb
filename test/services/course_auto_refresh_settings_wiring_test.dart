import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/course_auto_refresh_decision.dart';
import 'package:university_timetable/services/course_auto_refresh_store.dart';
import 'package:university_timetable/widgets/course_auto_refresh_settings.dart';

import '../helpers_test_app.dart';

/// 「课表自动更新」设置块的**接线**契约。
///
/// ## 为什么这一条必须有
///
/// `AGENTS.md` 的 TEST-POLICY 里记过一件事：存量 UI 测试大多只断言「页面打开了」，
/// 不断言「页面拿到了什么数据」，于是参数丢失那类 bug 一个都抓不到。这里钉的是
/// 三件具体的事：
///
/// 1. 开关关着时**不显示**时机/间隔/定时/立即试一次（避免用户看到一堆无效控件）；
/// 2. 打开后默认显示「第一次打开时」那一档；
/// 3. 切到「每隔几小时」会出现间隔滑杆，切到「每天定时」会出现时刻行。
///
/// 这些都是「渲染出什么」，比「点了会不会落盘」更容易坏（后者的落盘走的是
/// `CourseAutoRefreshStore`，已由 `test/services` 那组用例覆盖）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CourseAutoRefreshStore.resetForTesting();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CourseAutoRefreshSettingsSection(provider: provider),
          ),
        ),
      ),
    );
    // 块内首帧要读一次 store（异步），读完后才渲染开关。
    await tester.runAsync(() => CourseAutoRefreshStore.instance.load());
    await tester.pumpAndSettle();
  }

  testWidgets('开关关着：只显示开关本身，不显示时机与立即试一次', (tester) async {
    await pumpSection(tester);

    expect(find.text('自动更新课表'), findsOneWidget);
    expect(find.text('更新时机'), findsNothing);
    expect(find.text('立即试一次'), findsNothing);
  });

  testWidgets('打开开关后出现时机选择，默认是「每次打开时」', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('自动更新课表'));
    await tester.pumpAndSettle();

    expect(find.text('更新时机'), findsOneWidget);
    expect(find.text('每次打开时'), findsOneWidget);
    expect(find.text('立即试一次'), findsOneWidget);
    // 默认模式下不该出现间隔滑杆与定时行。
    expect(find.text('间隔小时数'), findsNothing);
    expect(find.text('每天更新时刻'), findsNothing);
  });

  testWidgets('选「每隔几小时」后出现间隔滑杆', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('自动更新课表'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('每次打开时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每隔几小时').last);
    await tester.pumpAndSettle();

    expect(find.text('间隔小时数'), findsOneWidget);
    expect(find.text('每天更新时刻'), findsNothing);
  });

  testWidgets('选「每天定时」后出现时刻行，且格式是 HH:mm', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('自动更新课表'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('每次打开时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每天定时').last);
    await tester.pumpAndSettle();

    expect(find.text('每天更新时刻'), findsOneWidget);
    // 默认 07:30（kCourseAutoRefreshDefaultDailyMinute）。
    expect(kCourseAutoRefreshDefaultDailyMinute, 7 * 60 + 30);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('间隔小时数'), findsNothing);
  });
}
