// 磨砂玻璃各行可发现性回归（2026-09-19 第七轮起在「外观编辑」页的材质面板，
// 且面板内可调项一律**内联控件**：分段选择 / 选项胶囊，不开二级弹层）。
//
// 历史口径（不变的部分）：顶栏两行**恒常显示、不做任何条件隐藏**（2026-09-12
// 反馈）；材质自由选择后不存在「暂不可用」状态。
// 2026-09-12 二次反馈：材质选择放在「课表页面」页属于放错位置，两行迁入
// 「外观与配色」玻璃模式组。
// 2026-09-19 三次调整：用户要求「玻璃档位改到课程页面调整」，整块材质设置
// 又搬回「课表页面」的玻璃 / 材质区块。
// 2026-09-19 五次调整：整块材质设置并入「外观编辑」页的材质面板。
// 2026-09-19 七次调整：整机只允许 实体卡片 / 液态玻璃 两种材质，面板改内联
// 分段与胶囊 —— 面板本身是根覆盖层自插条目，任何嵌套弹层都会被它压在背面
// （真机实锤），所以本文件还兼作「内联控件直接可调」的回归钉。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
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

/// 进入「设置 → 课表页面」子页（材质区块的入口行在这里），返回其 provider。
Future<TimetableProvider> _openTimetablePageSettings(WidgetTester tester) async {
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
  return provider;
}

/// 课表页面子页整页是一条 HyperosListView（分节渲染）。
Finder _appearanceList() => find.byType(HyperosListView).last;

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: _scrollableUnder(_appearanceList()),
  );
  await tester.pumpAndSettle();
}

Finder _panelScrollable() => find
    .descendant(
      of: find.byType(HyperosSheetFrame),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollPanelTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200, scrollable: _panelScrollable());
  await tester.pumpAndSettle();
}

/// 打开「外观编辑 → 材质」面板，返回其 provider。
Future<TimetableProvider> _openMaterialPanel(WidgetTester tester) async {
  final provider = await _openTimetablePageSettings(tester);
  await _scrollTo(tester, find.text('外观编辑'));
  await tester.tap(find.text('外观编辑'));
  await tester.pumpAndSettle();
  // 底部一排圆钮：圆钮与它下面那行名字同属一个点击区，点名字即可。
  await tester.tap(find.text('材质'));
  await tester.pumpAndSettle();
  return provider;
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

  testWidgets('默认设置下整体材质与顶栏两行恒常显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    await _openMaterialPanel(tester);

    // 整体材质两档置顶（出厂默认档在两材质口径下显示归桶为「实体卡片」）。
    expect(find.text('玻璃模式'), findsOneWidget);
    expect(find.text('实体卡片'), findsOneWidget);

    // 首页顶栏玻璃（两档，存量渐进档显示归桶为液态）+ 子页顶栏风格两档。
    await _scrollPanelTo(tester, find.text('首页顶栏玻璃'));
    expect(find.text('首页顶栏玻璃'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
    expect(find.text('液态玻璃'), findsWidgets);

    // 「各表面当前材质」地图存在，含表面行，且右侧材质值真实渲染
    // （HyperosListTile.details 只在可点行画，曾把整卡打成灰色空行）。
    await _scrollPanelTo(tester, find.text('各表面当前材质'));
    expect(find.text('首页玻璃带'), findsWidgets);
    expect(find.text('课程卡片'), findsWidgets);
    expect(find.text('实体'), findsWidgets);
  });

  testWidgets('全局液态下顶栏内联点选直接生效（层级回归钉）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(
      TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        homeBandGlassMaterial: 'liquid',
      ),
    );

    final provider = await _openMaterialPanel(tester);

    // 顶栏分段是内联控件：点「实体」段直接写回，不存在「弹层被面板压在
    // 背面、点按落空」的层级问题（2026-09-19 真机实锤的回归钉）。
    await _scrollPanelTo(tester, find.text('首页顶栏玻璃'));
    await tester.tap(find.text('实体').first);
    await tester.pumpAndSettle();
    expect(provider.settings.homeBandGlassMaterial, 'solid');

    // 地图卡的顶栏行同步显示实体（与设置同口径的只读推导）。
    expect(find.text('液态玻璃'), findsWidgets);
  });

  testWidgets('课表页面的玻璃区块只剩外观编辑入口行（整合后的回归钉）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    await _openTimetablePageSettings(tester);

    await _scrollTo(tester, find.text('外观编辑'));
    expect(find.text('外观编辑'), findsOneWidget);
    // 原区块里的行都已搬进外观编辑的材质面板，页面上不再有它们。
    expect(find.text('质感方案'), findsNothing);
    expect(find.text('首页顶栏玻璃'), findsNothing);
    expect(find.text('各表面当前材质'), findsNothing);
  });
}
