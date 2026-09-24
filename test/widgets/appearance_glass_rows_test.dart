// 玻璃材质各行可发现性回归（2026-09-19 第七轮起在「外观编辑」页的材质面板，
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
// 2026-09-20 八次调整：面板新增「课程卡片」一节（三档内联胶囊，写
// `courseCardSurfaceStyle`）—— 卡片是小格，材质要与全局材质**分开**选。
// 2026-09-22 九次调整：面板改成「通用 / 课程卡片」**左右两页**（标题行右侧是翻页
// 分段）。卡片那三档胶囊与它自己那八根旋钮都搬到第二页；课程卡片设置页不再有
// 那八根（那边当初单开一节的唯一理由是面板塞不下，分页之后这条理由消失）。
// 2026-09-23 十次调整：默认材质由两格改**三格**（实体卡片 / 高斯模糊 / 液态玻璃），
// 与引导页那三档同名同档；「磨砂玻璃」这个词从界面退场（它不是一档材质，是只读
// 总览里那个渲染状态词，现在与高斯模糊同叫一个名字）。
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
      // ⚠️ **不能取面板里第一个 `Scrollable`**：2026-09-22 起材质面板是「通用 /
      // 课程卡片」两页（横向翻页那一层自己也是 `Scrollable`，而且排在前面）。
      // 按页 key 指名取「通用」页自己的竖向滚动视图。
      of: find.byKey(const ValueKey('material-page-general')),
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

  testWidgets('默认设置下默认材质与顶栏两行恒常显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    await _openMaterialPanel(tester);

    // 默认材质三档置顶（出厂默认档 = 高斯模糊，显示成它就是它，不再归桶）。
    expect(find.text('默认材质'), findsOneWidget);
    // 面板顶上是「通用 / 课程卡片」两页的翻页分段（2026-09-22），默认停在「通用」页：
    // 所以「实体卡片」这一屏只有一处（默认材质那一段的选中态那三格之一）—— 卡片
    // 那一节的三档胶囊在第二页，没翻过去之前不在树上。
    expect(find.text('实体卡片'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    // 「课程卡片」两处：顶上的翻页分段标签，以及末尾只读总览里那一行
    //（卡片材质那一节的胶囊在第二页，没翻过去之前不在树上）。
    expect(find.text('课程卡片'), findsNWidgets(2));
    expect(find.text('卡片外观'), findsNothing, reason: '第二页还没翻过去');

    // 首页顶栏玻璃（两档，存量渐进档显示归桶为液态）+ 子页顶栏风格两档。
    await _scrollPanelTo(tester, find.text('首页顶栏玻璃'));
    expect(find.text('首页顶栏玻璃'), findsOneWidget);
    expect(find.text('液态玻璃'), findsWidgets);

    // 「各表面当前材质」地图存在，含表面行，且右侧材质值真实渲染
    // （HyperosListTile.details 只在可点行画，曾把整卡打成灰色空行）。
    await _scrollPanelTo(tester, find.text('各表面当前材质'));
    expect(find.text('首页玻璃带'), findsWidgets);
    // 「课程卡片」两处：新加的课程卡片材质那一节的标题，以及这张只读地图里的
    // 一行（面板里卡片材质与全局材质是分开的两档，见 settings_appearance_editor）。
    expect(find.text('课程卡片'), findsNWidgets(2));
    expect(find.text('实体'), findsWidgets);
  });

  testWidgets('默认材质三格：出厂档（高斯模糊）就在候选里，点它不改状态', (tester) async {
    // 2026-09-23 回归钉。此前这里只有两格，出厂档（模糊开着、非液态）被**谎报**
    // 成「实体卡片」选中 —— 用户看到「界面说我选的是实体卡片」，而点它会真的把
    // 全局模糊关掉（看着像"确认当前档"，其实是"换成那样"）。
    // 现在三格与 `GlassModeChoice` 一一对应，出厂档自己有位置：点它就是它本身。
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    final provider = await _openMaterialPanel(tester);

    // 三格都在候选里。
    expect(find.text('实体卡片'), findsOneWidget);
    expect(find.text('高斯模糊'), findsWidgets);
    expect(find.text('液态玻璃'), findsWidgets);

    // 点「默认材质」那一段里的「高斯模糊」（树序上它是第一处；第二处是子页顶栏
    // 模糊风格，第三处是只读总览里玻璃坞那一行）。
    await tester.tap(find.text('高斯模糊').first);
    await tester.pumpAndSettle();

    // 状态不变：模糊仍开着、档位仍是高斯 —— 出厂档点自己不会把模糊关掉。
    expect(provider.settings.frostedBlurEnabled, isTrue);
    expect(provider.settings.frostedGlassMode, FrostedGlassMode.gaussian);
    // 高斯档没有细项可调（折射参数只属于液态），所以「高级材质」那一节不出现。
    expect(find.text('高级材质'), findsNothing);
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

  testWidgets('切到液态玻璃后，面板下面照给细项（上下判据同源）', (tester) async {
    // 用户 2026-09-22 报的正是这条：「外观编辑里选了液态玻璃，下面没有出现
    // 玻璃相关设置」。根因是两处判据不同源 —— 顶部分段按显示归桶、下面给不给
    // 「高级材质」那一节看的是原始字段。
    //
    // 存量柔光那条读盘迁移的钉子在本轮单测里（`glass_mode_choice_test` 的
    // `fromValue('softGlass')` 一例）；这条钉的是用户直接操作后的自洽性。
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    final provider = await _openMaterialPanel(tester);

    // 出厂默认是高斯模糊档：此时下面不该有液态细项。
    expect(provider.settings.frostedGlassMode, FrostedGlassMode.gaussian);
    expect(find.text('高级材质'), findsNothing);

    // 点顶部分段的「液态玻璃」：设置写回，**下面立刻给液态细项**。
    await tester.tap(find.text('液态玻璃').first);
    await tester.pumpAndSettle();
    expect(provider.settings.frostedGlassMode, FrostedGlassMode.liquidGlass);
    expect(find.text('高级材质'), findsOneWidget, reason: '上面选液态，下面必须给细项');
    expect(find.text('柔光玻璃'), findsNothing);
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
