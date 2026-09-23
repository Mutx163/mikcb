// 「外观编辑」页：整页一张**真首页缩尺图** + 顶部日 / 周切换 + 底部两个弹窗入口。
//
// 这一页的公开入口只有 [settingsSubpageById] 一个（页面类本身是库内私有），
// 所以测试顺便把它与首页菜单的注册串起来验：注册表里拿不到页 = 菜单点了没反应。
//
// 关键口径（用户 2026-09-19 明确）：预览**直接用首页那份页面**缩尺，而不是另写一套
// 小屏布局 —— 所以这里断言的是 `TimetableScreen` 本体嵌在里面，不是预览替身。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/preview_bake_boundary.dart';
import 'package:university_timetable/widgets/timetable_home_preview_scope.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

import '../helpers_test_app.dart';

void _seedInitializedPrefs([TimetableSettings? settings]) {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings ?? TimetableSettings.defaults(),
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

  /// 走「首页整页缩进预览小屏」那条缩放转场推入本页（首页菜单那条路的形状）。
  ///
  /// 普通 pump 进不来这条转场的两个前提：路由是 [HyperosZoomPageRoute]，
  /// 以及首页被 [HyperosZoomShrinkScope] 包着。两者都照首页的真实结构搭。
  Future<void> pumpEditorViaZoomRoute(WidgetTester tester) async {
    final provider = await createInitializedTestProvider(tester);
    final editor = settingsSubpageById('appearanceEditor')!;
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HyperosZoomShrinkScope(
            // 首页那份的周期计时器与更新检查在测试里只会制造额外的帧。
            child: RepaintBoundary(
              child: TimetableScreen(
                enableUpdateCheck: false,
                enableProgressTimer: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: unawaited_futures
    navKey.currentState!.push<void>(
      HyperosZoomPageRoute<void>(builder: (_) => editor),
    );
    await tester.pump(); // 路由安装，转场起点
  }

  Finder dayViewPanel() =>
      find.byKey(const ValueKey('timetable-day-view-panel'));

  testWidgets('注册表能拿到页面，页面里嵌的是**真首页**本体', (tester) async {
    await pumpEditor(tester);
    // 缩尺预览用的就是首页那一份页面（用户口径：「直接使用首页的代码……让那个
    // 页面缩小」），不是另写的预览替身。
    expect(find.byType(TimetableScreen), findsOneWidget);
    // 顶栏**不再有页面标题**：2026-09-20 撤掉，位置让给日 / 周切换（省下那一行给
    // 预览卡）。页面名只出现在别处（设置行 / 首页菜单条目），这里按「页面里没有」
    // 钉住。
    expect(find.text('外观编辑'), findsNothing);

    // 方案 A（烤图）结构钉（2026-09-19 定案）：渲染源不再被 FittedBox 缩着 ——
    // 它整屏 1:1 躲在底衬下只为烤图而活，卡片显示烤出来的快照图。
    expect(
      find.ancestor(
        of: find.byType(TimetableScreen),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
      reason: '渲染源必须 1:1 渲染，缩放只发生在烤出的图上',
    );
    expect(find.byType(PreviewBakeBoundary), findsOneWidget);
    // 首帧烤完、下一帧卡片就该有图（烤图走 CPU 光栅，测试环境端到端可验）。
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.image, isNotNull, reason: '渲染源首帧后必须烤出快照图');
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

  testWidgets('首页在日视图时进页：预览与分段按钮一起停在日，不闪回周视图', (tester) async {
    // 回归钉（用户 2026-09-20：「在日视图进入外观编辑页会闪现到周视图」）。
    // 预览的初始视图曾经写死「永远从周视图起步」，而那条判断要等
    // didChangeDependencies 才拿得到（initState 里恒为 false）—— 它从来没生效：
    // 预览先按日视图搭起来、隔一帧才被同步指令关掉，卡片于是「先日、后跳周」。
    // 现在预览跟着首页那份持久化视图走，进页第一帧就是日，且不会被自己关掉。
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        timetableHomeViewMode: TimetableHomeViewMode.day,
        timetableLastViewedDayOfWeek: 3,
      ),
    );
    await pumpEditor(tester);

    final scope = previewScope(tester);
    expect(scope.dayView.value, isTrue, reason: '预览要跟着首页停在日视图');
    expect(scope.dayOfWeek.value, 3, reason: '看哪一天取首页「上次看到的那一天」');
    expect(dayViewPanel(), findsOneWidget, reason: '进页第一帧就该是日视图');

    // 隔几帧再看：那条帧末同步指令不能把日视图关掉（曾经就是「切过去又闪回周」）。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(dayViewPanel(), findsOneWidget);
    expect(scope.dayView.value, isTrue);
  });

  testWidgets('缩放转场途中点「日课表」要生效（看得见就点得动）', (tester) async {
    // 回归钉（用户 2026-09-20：「切换日视图切不过去」）。顶部 chrome 在转场末段
    // 就淡入可见了，但点击被挡到转场 100% 才放行 —— 那一刻点按钮毫无反应，而
    // 转场一结束预览又自己跳回周视图，读起来就是「切不过去」。
    await pumpEditorViaZoomRoute(tester);
    // 转场 400ms：推进到 300ms —— chrome 已经淡入可见，转场还没结束。
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('日课表'), findsOneWidget);

    await tester.tap(find.text('日课表'));
    await tester.pumpAndSettle();

    expect(previewScope(tester).dayView.value, isTrue);
    expect(dayViewPanel(), findsOneWidget, reason: '转场途中的点按不能被吞掉');
  });

  testWidgets('底部「材质」打开材质面板（默认材质三档内联控件）', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();

    // 面板 = 标题行（「材质」+ 通用 / 课程卡片 两格翻页分段）+ 第一页正文。
    // 出厂默认档 = 高斯模糊（三档之一，显示成它就是它，不再归桶）；液态调校
    // 分区只在选到液态时出现，此时隐藏。
    expect(find.text('材质'), findsWidgets);
    expect(find.text('通用'), findsOneWidget);
    // 「课程卡片」两处：翻页分段标签 + 末尾只读总览里那一行。
    expect(find.text('课程卡片'), findsNWidgets(2));
    expect(find.text('默认材质'), findsOneWidget);
    // 三档全在候选里，「实体卡片」这一屏只有分段里那一处（只读总览那几行写的是
    // 「实体」而不是「实体卡片」，卡片出厂档正是实体）。
    expect(find.text('实体卡片'), findsOneWidget);
    expect(find.text('液态玻璃'), findsWidgets);
    // 「高斯模糊」三处：默认材质那一格 + 子页顶栏模糊风格那一格（同一根轴上
    // 的另一个真档位，2026-09-23 起子页顶栏锁定渐进后这一处会消失）+
    // 只读总览里玻璃坞那一行（模糊开着、非液态）。
    expect(find.text('高斯模糊'), findsNWidgets(3));
    expect(find.text('首页顶栏玻璃'), findsOneWidget);
    expect(find.text('子页顶栏模糊风格'), findsOneWidget);
    expect(find.text('各表面当前材质'), findsOneWidget);
    expect(find.text('首页玻璃带'), findsWidgets);
    expect(find.text('高级材质'), findsNothing);
    // 第二页的内容在翻过去之前不在树上（翻页层只建当前那一页）。
    expect(find.text('卡片外观'), findsNothing);

    // 第七轮口径回归钉：质感方案（与模式开关重复）撤下；弹窗家族等锁定
    // 表面不再显示。
    expect(find.text('质感方案'), findsNothing);
    expect(find.text('弹窗与对话框'), findsNothing);
    expect(find.text('经典磨砂'), findsNothing);
  });

  testWidgets('材质面板第二页：左右滑得过去，分段跟着同步（2026-09-22 翻页）', (
    tester,
  ) async {
    // 用户口径 2026-09-22：「做成左右切换内部页面，第一个是通用，第二个课程卡片」，
    // 并明确要**能滑**。滑的是面板正文那一层（横向翻页），不是把手的关闭手势。
    await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();
    expect(find.text('卡片外观'), findsNothing);

    // 面板正文那一层才是翻页（页面上还嵌着一份真首页，那里也有 PageView，
    // 所以要把查找范围收到弹层里）。
    await tester.drag(
      find.descendant(
        of: find.byType(HyperosSheetFrame),
        matching: find.byType(PageView),
      ),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('卡片外观'), findsOneWidget, reason: '滑过去要真的落在第二页');
    // 分段标签两页都在（它是标题行的一部分），第一页内容已经离场。
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('默认材质'), findsNothing, reason: '第一页已翻走');
  });

  testWidgets('底部「调整壁纸」打开壁纸弹窗（选图按钮在里面）', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    expect(find.text('背景图片'), findsOneWidget);
    expect(find.text('选择图片'), findsOneWidget);
  });

  testWidgets('材质面板第二页的「卡片外观」写的是卡片自己的档位', (tester) async {
    // 用户口径（2026-09-20）：卡片是方格、弹窗与顶栏是别的东西，所以卡片的材质
    // 要能**与全局材质分开**选。2026-09-22 起这一节整节在面板第二页，胶囊直接写
    // TimetableSettings.courseCardSurfaceStyle，渲染门控仍走
    // effectiveCourseCardSurfaceStyle（无壁纸 / 模糊总开关关 → 回落实体）。
    final provider = await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();
    // 进第二页：点顶上那格分段标签（`.first` = 标题行里的标签，另一个在只读总览里）。
    await tester.tap(find.text('课程卡片').first);
    await tester.pumpAndSettle();

    // 第二页只剩一个「课程卡片」：分段标签自己（这一页的节标题是「卡片外观」，
    // 只读总览在第一页）。
    expect(find.text('课程卡片'), findsOneWidget);
    expect(find.text('卡片外观'), findsOneWidget);
    // 胶囊串（`_MaterialChoiceChips` 用 Wrap 排布）这一页只有这一处，
    // 用它把「课程卡片的液态玻璃」与第一页「默认材质」里同名的那个词分开。
    final cardChips = find.byType(Wrap);
    expect(cardChips, findsOneWidget);
    final liquidChip = find.descendant(
      of: cardChips,
      matching: find.text('液态玻璃'),
    );
    expect(liquidChip, findsOneWidget);

    await tester.tap(liquidChip);
    // 不用 pumpAndSettle：这一档会改首页渲染源（卡片重烤 + 玻璃重采样），测试
    // 环境下没有「静下来」的保证；断言读的是 provider.settings，两帧足够让草稿
    // 与落盘队列走完。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      provider.settings.courseCardSurfaceStyle,
      CourseCardSurfaceStyle.liquidGlass,
      reason: '点卡片那一节的胶囊必须写进 courseCardSurfaceStyle',
    );
  });

  testWidgets('材质面板第二页：卡片液态档下的八根旋钮写卡片自己的配置（搬家回归钉）', (
    tester,
  ) async {
    // 这八根原先在「课程卡片设置页」（那边单开一节的唯一理由是材质面板塞不下），
    // 2026-09-22 面板分页之后搬到第二页。这条用例钉两件事：旋钮真的在这一页，
    // 且写的是 `courseCardGlassTuning` —— 不是全局那份。
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
      ),
    );
    final provider = await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程卡片').first);
    await tester.pumpAndSettle();

    expect(find.byType(HyperosSlider), findsNWidgets(8), reason: '卡片这套八根');
    // 没设过卡片档 ⇒ 显示卡片出厂档：折射强度 8.0（前五项与全局标准档同值）。
    expect(find.text('8.0'), findsOneWidget);

    // 「磨砂强度」这根的量程跟出图侧同口径：0 是有效的「清」档（出原图、不跑高斯），
    // 上限就是预糊位图的 sigma 上限 —— 拖到哪、出图就认到哪，两头不留死区。
    final blurSlider = tester.widget<HyperosSlider>(
      find.descendant(
        of: find.ancestor(
          of: find.text('磨砂强度'),
          matching: find.byType(HyperosSliderTile),
        ),
        matching: find.byType(HyperosSlider),
      ),
    );
    expect(blurSlider.min, 0, reason: '0 = 清档');
    expect(blurSlider.max, kPreblurMaxSigma, reason: '上限 = 位图 sigma 的区间上限');

    // 走滑杆自己的回调（拖动时走的就是这条）。
    tester
        .widget<HyperosSlider>(find.byType(HyperosSlider).first)
        .onChanged!(13);
    // 滑杆落盘是 debounce 的（250ms），推帧要推过那个窗口才看得到
    // provider.settings；不用 pumpAndSettle —— 这一档会让渲染源重烤，
    // 测试环境下没有「静下来」的保证。
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(provider.settings.courseCardGlassTuning!.refraction, 13);
    expect(
      provider.settings.liquidGlassTuning,
      isNull,
      reason: '卡片那八根不能顺手把全局那份也写掉',
    );
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

  testWidgets('弹层正文跟着草稿走：壁纸弹窗里清除后那行立刻刷新（回归钉）', (tester) async {
    // 弹层是独立路由，不在本页 widget 树下 —— 页面 setState 带不动它里面的
    // 内容，只能靠草稿版本号订阅重画。曾经的表现是「设置清了、卡片也变了，
    // 弹窗里还写着原文件名、『清除图片』还杵着」，必须关掉重开才更新。
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: r'C:\fake\wall.png',
      ),
    );
    await pumpEditor(tester);

    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();
    expect(find.text('wall.png'), findsOneWidget);
    expect(find.text('清除图片'), findsOneWidget);

    await tester.tap(find.text('清除图片'));
    await tester.pumpAndSettle();

    expect(find.text('wall.png'), findsNothing);
    expect(find.text('清除图片'), findsNothing);
    expect(find.text('未选择'), findsOneWidget);
  });

  testWidgets('已有壁纸时多一颗「调整位置」：点它先收起弹窗、再进位置编辑页', (tester) async {
    // 「调整位置」补的是 2026-09-20 那次口径改动腾出来的能力：改之前「选择图片」
    // 在已有壁纸时**直接进位置页**，所以"只想微调一下位置"点它就够了；改成
    // 「一律先开相册」之后，没有这颗就等于"想调位置必须重选一张图"。
    // 必须用 **sync** 版：`testWidgets` 跑在 fake-async 区里，`await` 一个真实
    // 文件 IO 的 Future 永远不会完成（症状是整条用例挂到 10 分钟超时）。
    final dir = Directory.systemTemp.createTempSync('appearance_wall_pos');
    final file = File('${dir.path}/wall.png')
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 这张图可能还被解码器 / 预览持有（Windows 上会短暂锁文件，errno 32）。
        // 断言不依赖这次清理，留着由系统临时目录回收即可。
      }
    });
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(homePageWallpaperPath: file.path),
    );
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    expect(find.text('调整位置'), findsOneWidget);
    await tester.tap(find.text('调整位置'));
    // ⚠️ 不用 pumpAndSettle：位置页转场期间玻璃在自激重绘，settle 不下来
    //（同 wallpaper_position_picker_glass_test.dart 里那句说明）。用固定帧数推 ——
    // 帧数要够弹层退场动画跑完，否则位置页还没推。
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(
      find.byType(WallpaperPositionPickerPage),
      findsOneWidget,
      reason: '「调整位置」要真的把位置编辑页推起来（不是空按钮）',
    );
    // 弹层**必须先收起**：面板是上游插进根覆盖层的条目，`OverlayState.rearrange`
    // 把非路由条目排在所有路由之上 —— 不收起就推，页面会落在面板下面、还被它那层
    // 全屏透明屏障挡住点击（用户口径 2026-09-20：「在弹窗背后，什么东西都点不到」）。
    expect(
      find.text('背景图片'),
      findsNothing,
      reason: '推整页之前弹层必须已经退场，否则页面在面板背后、点不到',
    );
  });

  testWidgets('壁纸行三颗钮分两排：主操作独占一行，次级两颗平分', (tester) async {
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: r'C:\fake\wall.png',
      ),
    );
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    final pickY = tester.getCenter(find.text('选择图片')).dy;
    final adjustY = tester.getCenter(find.text('调整位置')).dy;
    final clearY = tester.getCenter(find.text('清除图片')).dy;
    expect(
      adjustY,
      moreOrLessEquals(clearY, epsilon: 0.5),
      reason: '「调整位置」「清除图片」同排平分',
    );
    expect(
      pickY,
      lessThan(adjustY - 20),
      reason: '「选择图片」独占一行 —— 三颗挤一行时每颗只剩约 105dp，四字文案会折行',
    );

    // 左右内边距：面板自己 16（`hyperosMiuixBottomSheetInsideMargin`）+ 壁纸行
    // 自带 16 = 32。上游默认的 24 会让它变成 40（用户口径 2026-09-20：
    //「左右边距留的那么大」）。窗口比面板上限（640）宽时面板居中。
    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final panelLeft = logicalWidth > 640 ? (logicalWidth - 640) / 2 : 0.0;
    expect(
      tester.getTopLeft(find.text('背景图片')).dx,
      closeTo(panelLeft + 32, 0.5),
    );
  });

  testWidgets('「选择图片」不再看状态分岔：已有壁纸时也走相册，不进位置页', (tester) async {
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: r'C:\fake\wall.png',
      ),
    );
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择图片'));
    await tester.pumpAndSettle();

    // VM 下相册通道没有实现，`pickAndStoreManagedImage` 返回 null —— 正好用来
    // 证明这条路走的是**相册**：改回旧写法（已有壁纸时直接进位置页）这条会红。
    expect(
      find.byType(WallpaperPositionPickerPage),
      findsNothing,
      reason: '「选择图片」的下一步是相册，不再是位置编辑页',
    );
    expect(find.text('背景图片'), findsOneWidget, reason: '仍停在壁纸弹窗里');
  });

  testWidgets('没有壁纸时不显示「调整位置」「清除图片」', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    expect(find.text('选择图片'), findsOneWidget);
    expect(find.text('调整位置'), findsNothing);
    expect(find.text('清除图片'), findsNothing);
  });

  testWidgets('弹层正文跟着草稿走：材质面板拖滑杆面板自己刷新（回归钉）', (tester) async {
    // 面板曾经是「每个控件各喊一声重画」，滑杆那条路径漏喊了：拖动只把设置
    // 写进去，面板上数字和滑块纹丝不动（松手还会弹回旧位置）。
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        liquidGlassPreset: LiquidGlassPreset.custom,
        liquidGlassTuning: LiquidGlassTuning.defaults,
      ),
    );
    final provider = await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();

    // 自定义档下 8 个旋钮全在，折射强度默认 8.0（其它旋钮的显示值都不是它）。
    expect(find.byType(HyperosSlider), findsNWidgets(8));
    expect(find.text('8.0'), findsOneWidget);

    // 走滑杆自己的回调（拖动时走的就是这条）。
    tester
        .widget<HyperosSlider>(find.byType(HyperosSlider).first)
        .onChanged!(13);
    await tester.pumpAndSettle();

    expect(find.text('13.0'), findsOneWidget);
    expect(find.text('8.0'), findsNothing);
    expect(provider.settings.liquidGlassTuning!.refraction, 13);
  });

  testWidgets('材质面板里点滑杆标题不开二级弹层（回归钉）', (tester) async {
    // 面板是根覆盖层自插条目，嵌套弹层会被压在背面（2026-09-19 真机实锤），
    // 所以面板里的可调项一律内联：滑杆行自带的「点击改值」必须关掉。
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        liquidGlassPreset: LiquidGlassPreset.custom,
      ),
    );
    await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();
    expect(find.byType(HyperosSheetFrame), findsOneWidget);

    // 面板最多占半屏、超出部分要自己滚，所以这里先照面板的滚动条把这一行带进
    // 视野（真机上用户就是这么滑的；不带进来点按会落空，这条回归钉就成空的了）。
    await tester.scrollUntilVisible(
      find.text('折射强度'),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('material-page-general')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('折射强度'));
    await tester.pumpAndSettle();

    expect(find.byType(HyperosSheetFrame), findsOneWidget);
    // 面板本身还开着（点空白处不该把面板关掉）。
    expect(find.text('默认材质'), findsOneWidget);
  });
}
