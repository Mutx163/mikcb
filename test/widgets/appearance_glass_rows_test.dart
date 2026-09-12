// 顶栏模糊风格两行的可发现性回归（现居「外观与配色」页玻璃模式组）。
//
// 历史：ded4b7e5 把「顶栏模糊风格」（渐进 / 高斯）并进「玻璃材质」三选一，
// 页面上再也找不到一行叫这个名字的开关；随后拆回独立行，但一度按「改了
// 不生效就隐藏」的口径在高级材质 / 玻璃总关时把行藏掉，用户仍然找不到
// （2026-09-12 反馈）。最终口径：**两行恒常显示，不做任何条件隐藏**。
// 2026-09-12 二次反馈：材质选择放在「课表页面」页属于放错位置，两行迁入
// 「外观与配色」玻璃模式组（课表页面只留顶栏玻璃显示开关），提示语同步
// 改为按「玻璃模式」措辞的人话；本文件随之钉住外观页的常驻两行。
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

/// 进入「设置 → 外观与配色」子页。
Future<void> _openAppearanceSettings(WidgetTester tester) async {
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
    find.text('外观与配色'),
    200,
    scrollable: _scrollableUnder(homeList),
  );
  await tester.tap(find.text('外观与配色'));
  await tester.pumpAndSettle();
}

/// 外观子页整页是一条 HyperosListView（分节渲染）。
Finder _appearanceList() => find.byType(HyperosListView).last;

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: _scrollableUnder(_appearanceList()),
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

  testWidgets('默认设置下两行风格恒常显示，附人话提示语', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    await _openAppearanceSettings(tester);

    // 质感方案行存在，出厂默认命中「经典磨砂」。
    await _scrollTo(tester, find.text('质感方案'));
    expect(find.text('质感方案'), findsOneWidget);
    expect(find.text('经典磨砂'), findsWidgets);

    await _scrollTo(tester, find.text('首页顶栏模糊风格'));
    expect(find.text('首页顶栏模糊风格'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
    // 两行当前值都是渐进模糊。
    expect(find.text('渐进模糊'), findsWidgets);
    // 提示语按「玻璃模式」措辞（人话口径），不再是「基础磨砂」黑话。
    expect(find.textContaining('改回『高斯模糊』'), findsOneWidget);

    // 「各表面当前材质」地图卡存在，含表面行。
    await _scrollTo(tester, find.text('各表面当前材质'));
    expect(find.text('首页玻璃带'), findsWidgets);
    expect(find.text('课程卡片'), findsWidgets);
  });

  testWidgets('全局柔光下两行仍常显（不回归条件隐藏）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(
      TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
      ),
    );

    await _openAppearanceSettings(tester);
    await _scrollTo(tester, find.text('首页顶栏模糊风格'));

    expect(find.text('首页顶栏模糊风格'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
  });
}
