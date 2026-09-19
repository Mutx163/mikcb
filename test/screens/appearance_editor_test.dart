// 「外观编辑」页：整页一张**真首页缩尺图** + 顶部日 / 周切换 + 底部两个弹窗入口。
//
// 这一页的公开入口只有 [settingsSubpageById] 一个（页面类本身是库内私有），
// 所以测试顺便把它与首页菜单的注册串起来验：注册表里拿不到页 = 菜单点了没反应。
//
// 关键口径（用户 2026-09-19 明确）：预览**直接用首页那份页面**缩尺，而不是另写一套
// 小屏布局 —— 所以这里断言的是 `TimetableScreen` 本体嵌在里面，不是预览替身。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/timetable_home_preview_scope.dart';

import '../helpers_test_app.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
    // 设置库 / 首页里的平台通道在 VM 下没有实现，不 mock 会抛 MissingPluginException。
    for (final channel in const [
      'com.mutx163.qingyu/home_widget',
      'com.mutx163.qingyu/umeng_analytics',
      'com.mutx163.qingyu/miui_live',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (call) async => null);
    }
  });

  tearDown(() {
    for (final channel in const [
      'com.mutx163.qingyu/home_widget',
      'com.mutx163.qingyu/umeng_analytics',
      'com.mutx163.qingyu/miui_live',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  Future<TimetableProvider> pumpEditor(WidgetTester tester) async {
    final provider = await createInitializedTestProvider(tester);
    final page = settingsSubpageById('appearanceEditor');
    expect(page, isNotNull, reason: '注册表里必须有 appearanceEditor 子页');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          // 首页/预览可能读天气，缺失会抛 ProviderNotFound。
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: TestApp(home: page!),
      ),
    );
    await tester.pump();
    return provider;
  }

  TimetableHomePreviewScope previewScope(WidgetTester tester) =>
      tester.widget<TimetableHomePreviewScope>(
        find.byType(TimetableHomePreviewScope),
      );

  testWidgets('注册表能拿到页面，页面里嵌的是**真首页**本体', (tester) async {
    await pumpEditor(tester);
    // 缩尺预览用的就是首页那一份页面（用户口径：「直接使用首页的代码……让那个
    // 页面缩小」），不是另写的预览替身。
    expect(find.byType(TimetableScreen), findsOneWidget);
    // 标题只有顶栏那一行：折叠大标题已关（用户反馈「不应该显示大标题小标题」）。
    expect(find.text('外观编辑'), findsOneWidget);
  });

  testWidgets('顶部日 / 周切换驱动嵌进来的首页（不是本地替身）', (tester) async {
    await pumpEditor(tester);

    expect(previewScope(tester).dayView.value, isFalse);

    await tester.tap(find.text('日课表'));
    await tester.pumpAndSettle();
    expect(previewScope(tester).dayView.value, isTrue);
    // 首页那一份真的切到了日视图（日视图面板挂上了）。
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsOneWidget,
    );

    await tester.tap(find.text('周课表'));
    await tester.pumpAndSettle();
    expect(previewScope(tester).dayView.value, isFalse);
    expect(find.byKey(const ValueKey('timetable-day-view-panel')), findsNothing);
  });

  testWidgets('缩尺预览不进回访状态：改日/周不动真实首页的视图', (tester) async {
    final provider = await pumpEditor(tester);
    final before = provider.settings.timetableHomeViewMode;
    await tester.tap(find.text('日课表'));
    await tester.pumpAndSettle();
    expect(provider.settings.timetableHomeViewMode, before);
  });

  testWidgets('底部「材质」打开材质弹窗（玻璃模式四档在里面）', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();

    // 弹窗标题、质感方案与玻璃模式两行都在；玻璃模式那行显示的是当前档位
    // （出厂默认不是液态，所以这里断言的是档位名而不是「液态玻璃」——四档
    // 候选在选择气泡里，不在行上）。
    expect(find.text('材质'), findsWidgets);
    expect(find.text('质感方案'), findsOneWidget);
    expect(find.text('玻璃模式'), findsOneWidget);
    expect(find.text('高斯模糊'), findsWidgets);
  });

  testWidgets('底部「调整壁纸」打开壁纸弹窗（选图按钮在里面）', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    expect(find.text('背景图片'), findsOneWidget);
    expect(find.text('选择图片'), findsOneWidget);
  });

  testWidgets('从「设置 → 课表页面」的材质区块一键进得来（入口行必须常驻）', (
    tester,
  ) async {
    // 入口的可发现性回归钉：首页右上角菜单那条路受八宫格 8 格上限与用户自存
    // 排列的限制（新条目不会自动出现），所以设置页里这一行才是保证可达的那条路。
    tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    Finder scrollableUnder(Finder host) =>
        find.descendant(of: host, matching: find.byType(Scrollable)).first;

    final homeList = find.byType(HyperosListView).first;
    await tester.scrollUntilVisible(
      find.text('课表页面'),
      200,
      scrollable: scrollableUnder(homeList),
    );
    await tester.tap(find.text('课表页面'));
    await tester.pumpAndSettle();

    final pageList = find.byType(HyperosListView).last;
    await tester.scrollUntilVisible(
      find.text('外观编辑'),
      200,
      scrollable: scrollableUnder(pageList),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观编辑'));
    await tester.pumpAndSettle();

    expect(find.byType(TimetableScreen), findsOneWidget);
    expect(find.text('调整壁纸'), findsOneWidget);
    expect(find.text('材质'), findsOneWidget);
  });
}
