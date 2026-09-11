// 顶栏玻璃两行的可发现性回归。
//
// 「顶栏模糊风格」（渐进 / 高斯）曾在 ded4b7e5 被并进「玻璃材质」三选一，
// 结果页面上再也找不到一行叫这个名字的开关。拆回独立行后这里锁死三件事：
// 1. 玻璃开启时两行同时可见（可发现性）；
// 2. 「玻璃材质 = 液态玻璃」时风格行隐藏 —— 折射面不看衰减风格，
//    留着就是一个改了不生效的选项；
// 3. 顶栏玻璃总开关关闭时两行都不渲染。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import '../helpers_test_app.dart';

/// 用给定设置起一个「已初始化」的 profile，供设置页读取。
void _seedPrefs(TimetableSettings settings) {
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

Finder _scrollableUnder(Finder host) =>
    find.descendant(of: host, matching: find.byType(Scrollable)).first;

/// 进入「设置 → 课表页面」子页。
Future<void> _openTimetablePageSettings(WidgetTester tester) async {
  final provider = await createInitializedTestProvider(tester);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const TestApp(home: TimetableSettingsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  final homeList = find.byType(HyperosListView).first;
  await tester.scrollUntilVisible(
    find.text('课表页面'),
    200,
    scrollable: _scrollableUnder(homeList),
  );
  await tester.tap(find.text('课表页面'));
  await tester.pumpAndSettle();
}

/// 子页的下半屏编辑器列表（上半屏是预览，不是 HyperosListView）。
Finder _editorList() => find.byType(HyperosListView).last;

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: _scrollableUnder(_editorList()),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
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

  testWidgets('顶栏玻璃开启时同时提供「玻璃材质」与「顶栏模糊风格」', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    await _openTimetablePageSettings(tester);
    await _scrollTo(tester, find.text('玻璃材质'));

    expect(find.text('玻璃材质'), findsOneWidget);
    // 这就是之前「找不到」的那一行：必须有独立行，而不是只在材质档位里。
    expect(find.text('顶栏模糊风格'), findsOneWidget);
    // 默认渐进档：两行都显示「渐进模糊」为当前值。
    expect(find.text('渐进模糊'), findsNWidgets(2));
  });

  testWidgets('玻璃材质选液态玻璃时「顶栏模糊风格」行隐藏', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(
      TimetableSettings.defaults().copyWith(
        homeChromeGlassMaterial: 'liquid',
        liquidGlassHomeChromeEnabled: true,
      ),
    );

    await _openTimetablePageSettings(tester);
    await _scrollTo(tester, find.text('玻璃材质'));

    expect(find.text('玻璃材质'), findsOneWidget);
    expect(find.text('液态玻璃'), findsOneWidget);
    // 折射面不看衰减风格，不留无效选项。
    expect(find.text('顶栏模糊风格'), findsNothing);
  });

  testWidgets('顶栏玻璃总开关关闭时两行都不渲染', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(
      TimetableSettings.defaults().copyWith(
        homePageHeaderBlurEnabled: false,
        homePageWeekdayBarBlurEnabled: false,
      ),
    );

    await _openTimetablePageSettings(tester);
    await _scrollTo(tester, find.text('顶栏玻璃'));

    expect(find.text('顶栏玻璃'), findsOneWidget);
    expect(find.text('玻璃材质'), findsNothing);
    expect(find.text('顶栏模糊风格'), findsNothing);
  });
}
