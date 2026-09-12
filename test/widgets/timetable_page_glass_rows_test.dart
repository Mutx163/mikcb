// 顶栏玻璃行的可发现性回归。
//
// 历史：ded4b7e5 把「顶栏模糊风格」（渐进 / 高斯）并进「玻璃材质」三选一，
// 页面上再也找不到一行叫这个名字的开关；随后拆回独立行，但一度按「改了
// 不生效就隐藏」的口径在高级材质 / 玻璃总关时把行藏掉，用户仍然找不到
// （2026-09-12 反馈）。最终口径：**该行恒常显示，不做任何条件隐藏**——
// 顶栏走基础磨砂时立即生效；跟随柔光 / 液态材质时只记住选择，切回基础
// 磨砂即恢复（由提示语说明）。
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

  testWidgets('基础材质（高斯）下渲染首页/子页两行模糊风格', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    await _openTimetablePageSettings(tester);
    await _scrollTo(tester, find.text('首页顶栏模糊风格'));

    // 首页玻璃带与子页顶栏相互独立，各有一行风格选择。
    expect(find.text('首页顶栏模糊风格'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
    // 独立材质三选一已下线：材质由全局选择器 + 作用范围决定。
    expect(find.text('玻璃材质'), findsNothing);
    // 两行当前值都是渐进模糊。
    expect(find.text('渐进模糊'), findsWidgets);
  });

  testWidgets('全局柔光 + 首页玻璃带作用范围开 → 风格行仍常显', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(
      TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
        liquidGlassHomeChromeEnabled: true,
      ),
    );

    await _openTimetablePageSettings(tester);
    await _scrollTo(tester, find.text('顶栏玻璃'));

    expect(find.text('顶栏玻璃'), findsOneWidget);
    // 恒常显示：高级材质下只是暂不参与渲染，选择仍可改、仍被记住。
    expect(find.text('首页顶栏模糊风格'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
    expect(find.text('渐进模糊'), findsWidgets);
    expect(find.text('玻璃材质'), findsNothing);
  });

  testWidgets('顶栏玻璃总开关关闭时风格行仍常显', (tester) async {
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
    // 恒常显示：玻璃总关时该行不隐藏，只等开关重新打开后再生效。
    expect(find.text('首页顶栏模糊风格'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
    expect(find.text('玻璃材质'), findsNothing);
  });
}