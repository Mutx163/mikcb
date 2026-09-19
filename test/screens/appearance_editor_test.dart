// 「外观编辑」页：整页一张首页微缩图 + 顶部日 / 周切换 + 底部两个弹窗入口。
//
// 这一页的公开入口只有 [settingsSubpageById] 一个（页面类本身是库内私有），
// 所以测试顺便把它与首页菜单的注册串起来验：注册表里拿不到页 = 菜单点了没反应。
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
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/widgets/timetable_week_preview.dart';

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
    // 设置库里的平台通道在 VM 下没有实现，不 mock 会抛 MissingPluginException。
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
          // 预览显式读天气（字段说明要求），缺失会抛 ProviderNotFound。
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: TestApp(home: page!),
      ),
    );
    await tester.pump();
    return provider;
  }

  testWidgets('注册表能拿到页面，页面里是首页微缩预览', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(TimetableWeekPreview), findsOneWidget);
    // 标题在折叠顶栏里会渲染大小两处（小标题 + 大标题），所以用 findsWidgets。
    expect(find.text('外观编辑'), findsWidgets);
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

    expect(find.byType(TimetableWeekPreview), findsOneWidget);
    expect(find.text('调整壁纸'), findsOneWidget);
    expect(find.text('材质'), findsOneWidget);
  });

  testWidgets('顶部日 / 周切换只改预览：周视图整周、日视图收成一天', (tester) async {
    await pumpEditor(tester);

    TimetableWeekPreview preview() =>
        tester.widget<TimetableWeekPreview>(find.byType(TimetableWeekPreview));

    // 进页默认周视图：不裁天。
    expect(preview().onlyDayOfWeek, isNull);

    await tester.tap(find.text('日课表'));
    await tester.pumpAndSettle();
    expect(preview().onlyDayOfWeek, DateTime.now().weekday);

    await tester.tap(find.text('周课表'));
    await tester.pumpAndSettle();
    expect(preview().onlyDayOfWeek, isNull);
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

  testWidgets('预览不自己上液态玻璃（测试环境没有 shader 后端，走既有基础材质）', (
    tester,
  ) async {
    // 这只是钉住「预览不会因为材质缺后端而崩」：VM 上 isShaderFilterSupported
    // 恒 false，所以这里断言的是**没有**液态玻璃层，而不是有。
    await pumpEditor(tester);
    expect(find.byType(LiquidGlassSurface), findsNothing);
  });
}
