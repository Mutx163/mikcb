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
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/wallpaper_history_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/inspire/inspire_header_blur.dart';
import 'package:university_timetable/ui/hyperos/preview_bake_boundary.dart';
import 'package:university_timetable/widgets/timetable_home_preview_scope.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

import '../helpers_test_app.dart';

void _seedInitializedPrefs([
  TimetableSettings? settings,
  List<WallpaperHistoryEntry>? wallpaperHistory,
]) {
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
    // 「最近使用」的真源是全局 prefs 那一份，settings 里那份只是镜像（见
    // WallpaperHistoryService 的类注释）—— 只塞 settings 的话条子不会出现在
    // 界面上，所以这里必须直接写全局那个键。
    if (wallpaperHistory != null)
      WallpaperHistoryService.preferenceKey: jsonEncode([
        for (final entry in wallpaperHistory) entry.toJson(),
      ]),
  });
}

/// 切壁纸弹窗的页签（2026-09-28 双页改造：左边「壁纸」、右边「设置」）。
///
/// 按**页签文字**找而不是按 `PageController`：这是 widget 测试，动画与翻页状态都在
/// widget 树里，直接点页签就够。限定在 `HyperosChipRow` 内，免得命中编辑器页面背后
/// 那些同样叫「设置」的文字。
Future<void> _switchWallpaperSheetPage(
  WidgetTester tester,
  String tabLabel,
) async {
  final tab = find.descendant(
    of: find.byType(HyperosChipRow),
    matching: find.text(tabLabel),
  );
  expect(tab, findsOneWidget, reason: '壁纸弹窗顶部应有「$tabLabel」这个页签');
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    AppGlobalSettingsService.resetCacheForTest();
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

  /// 「外观编辑」页的整页加载罩（`_previewCoverPhase`，见设置里那个文件的注释）。
  ///
  /// 它是不透明的一整页、也挡点按，所以 pumpWidget 之后直接 tap 底部按钮会被它
  /// 吃掉 —— 得先等它撤。真机上就是路由落定 + 烤出第一张图那几帧。
  Finder previewCover() =>
      find.byKey(const ValueKey('appearance-editor-loading-cover'));

  /// 推进到加载罩撤掉为止（罩子淡出 180ms + 一帧重建）。
  Future<void> pumpUntilPreviewCoverGone(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      if (previewCover().evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('加载罩一直没撤：第一张预览图没烤出来（_previewBake 停在 null）');
  }

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
    await pumpUntilPreviewCoverGone(tester);
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

  /// 材质面板顶部模糊带上的**翻页胶囊**。
  ///
  /// 按「在 [HyperosChipRow] 里」收窄，不靠树序（2026-09-26 起带与正文是
  /// `HyperosSheetBlurTop` 里 `Stack` 的两个子节点，正文排在前面，所以
  /// `find.text('课程卡片').first` 命中的是第一页只读总览那一行而不是标签）。
  /// 2026-09-27 起翻页控件由药丸分段换成筛选胶囊（与面板里的选值分段按语义分家），查找
  /// 也跟着换。
  Finder panelPageTab(String label) => find.descendant(
    of: find.byType(HyperosChipRow),
    matching: find.text(label),
  );

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

  testWidgets('从设置页进来：第一张预览图出炉前整页盖着加载罩（2026-09-28）', (
    tester,
  ) async {
    // 用户反馈原文：「在设置页面进入外观编辑页面的时候……现在页面进来了，然后画面
    // 是隔了几秒突然出现的预览」。从设置页这条路进来**没有首页快照可顶替**，卡片
    // 在自家烤出第一张图之前是空的 —— 那个空档必须被一个加载态讲清楚。
    final provider = await createInitializedTestProvider(tester);
    final page = settingsSubpageById('appearanceEditor')!;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: TestApp(home: page),
      ),
    );
    await tester.pump();

    expect(previewCover(), findsOneWidget, reason: '没图可显示时必须盖住整页');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('appearance-editor-preview-card')),
        matching: find.byType(RawImage),
      ),
      findsNothing,
      reason: '卡片此刻确实还没有图 —— 这正是「突然出现」的那个空档',
    );
    // 盖住整页 = 上下 chrome 也在底下（Stack 的最后一项）。
    expect(
      find.descendant(of: previewCover(), matching: find.byType(Center)),
      findsWidgets,
      reason: '加载态整体居中',
    );
    // 转圈 + 「加载中」三字（2026-09-28 用户口径：光一个圈看不懂在干嘛）。
    expect(
      find.descendant(
        of: previewCover(),
        matching: find.byType(HyperosInfiniteProgress),
      ),
      findsOneWidget,
      reason: '用环 + 绕行小圆点那款转圈（不可测进度，转圈感最强）',
    );
    expect(
      find.descendant(of: previewCover(), matching: find.text('加载中')),
      findsOneWidget,
      reason: '转圈下面要有一行文案说明这是加载态',
    );
    // 转圈在上、文字在下（用户拍板的摆法）。
    final ring = tester.getRect(
      find.descendant(
        of: previewCover(),
        matching: find.byType(HyperosInfiniteProgress),
      ),
    );
    final label = tester.getRect(
      find.descendant(of: previewCover(), matching: find.text('加载中')),
    );
    expect(
      label.top,
      greaterThan(ring.top),
      reason: '文字在转圈下方，不是并排',
    );
    expect(
      label.center.dx,
      closeTo(ring.center.dx, 1),
      reason: '两者中线对齐',
    );

    await pumpUntilPreviewCoverGone(tester);

    expect(previewCover(), findsNothing, reason: '第一张图到位后必须撤掉罩子');
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image,
      isNotNull,
      reason: '撤罩子的那一刻卡片上必须已经有图',
    );
  });

  test('加载文案六语齐全，且英文环境不是中文（2026-09-28）', () async {
    // 本仓有「展示文案一律走 arb」的规矩（2026-09-25 那篇笔记），所以「加载中」
    // 是个新键。真正的风险是**漏一个语种**（漏了那个语言的设备上会退回模板语言
    // 或露出键名），所以这里直接把每个受支持语种都 load 一遍。
    //
    // ⚠️ 刻意**不**做成 widget 用例：预览里那份真首页的周视图在英文下本身就容易
    // RenderFlex 溢出（英文课程名比中文高，与本条无关），拿它当载体会把这条用例
    // 绑在一个别人的脆弱点上。查文案不需要渲染整棵首页。
    // ⚠️ 键必须是 `Locale.toString()`（`zh_TW` / `zh_HK`），不是 `languageCode`
    // —— 后者对这两个都只给 `zh`，会把繁简两个语种算成一个。
    final expected = <String, String>{
      'zh': '加载中',
      'zh_TW': '載入中',
      'zh_HK': '載入中',
      'en': 'Loading…',
      'ja': '読み込み中',
      'ko': '불러오는 중',
    };
    expect(
      AppLocalizations.supportedLocales.map((l) => l.toString()).toSet(),
      expected.keys.toSet(),
      reason: '语种清单变了就同步改这张表，别让新语种静默漏掉',
    );
    for (final entry in expected.entries) {
      final l10n = await AppLocalizations.delegate.load(
        Locale.fromSubtags(
          languageCode: entry.key.split('_').first,
          countryCode: entry.key.contains('_') ? entry.key.split('_').last : null,
        ),
      );
      expect(
        l10n.commonLoadingLabel,
        entry.value,
        reason: '${entry.key} 的「加载中」译文不对',
      );
    }
  });

  testWidgets('从首页菜单进来：缩放转场全程不盖加载罩（快照有图可接力）', (
    tester,
  ) async {
    // 反向守卫：首页菜单那条路首页正缩进预览卡片、全程有图，盖一层等于把这条
    // 转场废掉（`shrinkT` 那套观感全没了）。
    await pumpEditorViaZoomRoute(tester);
    for (var i = 0; i < 20; i++) {
      expect(
        previewCover().evaluate(),
        isEmpty,
        reason: '第 $i 帧：缩放转场里不该出现加载罩',
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
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
    // 「高斯模糊」两处：默认材质那一格 + 只读总览里玻璃坞那一行（模糊开着、
    // 非液态）。子页顶栏那把轴 2026-09-23 起锁死为渐进，所以不再有第三处。
    expect(find.text('高斯模糊'), findsNWidgets(2));
    expect(
      find.text('子页顶栏模糊风格'),
      findsNothing,
      reason: '子页顶栏 2026-09-23 起锁死渐进，这一节整体撤下',
    );
    expect(find.text('首页顶栏玻璃'), findsOneWidget);
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

  testWidgets('材质面板的顶部模糊带：模糊层让开圆角，白纱满宽（2026-09-28 第六版）', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    await tester.pumpAndSettle();

    // 接线钉：面板顶部那条带子的**模糊层**矩形左右各内缩一个圆角半径（与上沿
    // 圆弧相切），圆角区域里没有模糊材料 —— 治用户口径「页面滑动到中间位置的时候，
    // 卡片（面板）的右上角左上角还会在圆角外面出现模糊效果」。
    //
    // ⚠️ 期望值随修订翻过两次：第三版钉 `> 0`（内缩+白纱一起缩，真机打回：两端无料），
    // 第二次修订钉 `== 0`（归零、全靠 ClipRRect —— 圆角问题一直没修掉），**第六版
    // 钉回半径**，但这次只缩模糊、白纱满宽（白纱的钉在
    // sheet_top_band_ramp_engages_test.dart 的「树里不许有 ShaderMask」）。
    //
    // ⚠️ 与此同时**别的带子不许开**（用户 2026-09-28：「设置页面顶部的渐变模糊
    // 视觉效果非常好，不要改动导致它坏掉」）—— 那条守卫在
    // header_blur_style_wiring_test.dart。
    final band = tester.widget<InspireHeaderBlur>(
      find.ancestor(
        of: find.byType(HyperosChipRow),
        matching: find.byType(InspireHeaderBlur),
      ),
    );
    expect(
      band.cornerRampIn,
      hyperosMiuixBottomSheetCornerRadius,
      reason: '模糊层必须与面板圆弧相切（内缩一个半径），否则圆角区域还有模糊材料',
    );
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
    // 进第二页：点顶部模糊带上的那个标签。
    //
    // ⚠️ **不能再用 `find.text('课程卡片').first`**（2026-09-26 改版）：带与正文是
    // `HyperosSheetBlurTop` 里的 `Stack` 两个子节点，**正文排在前面**（带必须后画才能
    // 压住从底下滚上来的内容），于是树序里第一个「课程卡片」变成第一页只读总览那一行，
    // `.first` 点到了它、页面根本没翻。这里按「在翻页标签栏里」收窄，与树序解耦。
    await tester.tap(panelPageTab('课程卡片'));
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

  testWidgets('课程卡片设置页的「卡片外观」是跳转牌：点了直达面板课程卡片页', (tester) async {
    // 2026-09-25 入口收敛（用户拍板）：同一开关只留材质面板一扇门。设置页这行
    // 只显示当前值，点了进外观编辑并**自动打开**材质面板、停在第二页。
    final provider = await createInitializedTestProvider(tester);
    final page = settingsSubpageById('courseCardSettings');
    expect(page, isNotNull, reason: '注册表里必须有课程卡片子页');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: TestApp(home: page!),
      ),
    );
    await tester.pump();

    // 行在列表第四节，先滚出来（懒列表不滚不建）。
    final row = find.widgetWithText(HyperosListTile, '卡片外观');
    final list = find.byType(HyperosListView).last;
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();

    final sheet = find.byType(HyperosSheetFrame);
    expect(sheet, findsOneWidget, reason: '点了要自动打开材质面板');
    expect(
      find.descendant(of: sheet, matching: find.text('课程卡片')),
      findsOneWidget,
      reason: '标题行分段标签在，且停在课程卡片那格',
    );
    expect(
      find.descendant(of: sheet, matching: find.text('卡片外观')),
      findsOneWidget,
      reason: '第二页正文（卡片外观节）在面板里',
    );
    expect(
      find.descendant(of: sheet, matching: find.text('默认材质')),
      findsNothing,
      reason: '没有停在第一页（通用页还没被建出来）',
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
    // 同上：按「在翻页标签栏里」收窄，不靠树序（`.first` 会点到第一页只读总览那一行）。
    await tester.tap(panelPageTab('课程卡片'));
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

    // 面板改成「最多半屏」之后（双页 + 顶部渐变模糊带），第一页的按钮可能落在折叠
    // 线以下，`tester.tap` 对屏幕外的东西点不到 —— 症状是 "would not hit test"。
    //
    // 必须用 alignment: 0.5（滚到视口中间）而不是 `tester.ensureVisible` 的默认 0：
    // 默认对齐把目标的**顶边**贴到视口顶边，而那一截正压在顶部模糊带的**着色层**底下 ——
    // 着色层没包 IgnorePointer、而渐变末端全透明照样吃命中（`BoxDecoration.hitTest` 对
    // 无圆角矩形恒为 true），点下去什么都不会发生。滚到中间就离开了那条命中区。
    // 同一条陷阱见 test/widgets/appearance_glass_rows_test.dart。
    await Scrollable.ensureVisible(
      tester.element(find.text('清除图片')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();

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

    // 左右内边距 = **面板自己那 16**（`hyperosMiuixBottomSheetInsideMargin`），
    // 壁纸行不再自带一层（`backdropRowHorizontalInset` 在弹窗这一侧是 0）。
    //
    // 之前这里是 16 + 16 = 32，比兄弟弹窗（选周、删除确认、课程备注…标题与按钮
    // 都从 16 起）多缩一截，两颗按钮点开的版式对不上（用户口径 2026-09-27）。
    // 窗口比面板上限（640）宽时面板居中。
    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final panelLeft = logicalWidth > 640 ? (logicalWidth - 640) / 2 : 0.0;
    expect(
      tester.getTopLeft(find.text('背景图片')).dx,
      closeTo(panelLeft + 16, 0.5),
    );
  });

  testWidgets('壁纸弹窗里两块（选图行 / 最近使用）左右齐平，都从面板的 16 起', (
    tester,
  ) async {
    // 必须给**真实存在**的图：失效路径进不了「最近使用」（那一栏只列文件真在的
    // 条目），两块齐平这条就无从验证。
    final dir = Directory.systemTemp.createTempSync('appearance_wall_inset');
    final current = File('${dir.path}/current.png')
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    final older = File('${dir.path}/older.png')
      ..writeAsBytesSync(const [5, 6, 7, 8]);
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows 上解码器可能短暂锁着（errno 32）；断言不依赖这次清理。
      }
    });
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: current.path,
      ),
      [
        WallpaperHistoryEntry(key: current.path, usedAt: 200),
        WallpaperHistoryEntry(key: older.path, usedAt: 100),
      ],
    );
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final panelLeft = logicalWidth > 640 ? (logicalWidth - 640) / 2 : 0.0;
    expect(find.text('最近使用'), findsOneWidget, reason: '有两条可用历史');
    expect(
      tester.getTopLeft(find.text('背景图片')).dx,
      closeTo(panelLeft + 16, 0.5),
    );
    expect(
      tester.getTopLeft(find.text('最近使用')).dx,
      closeTo(panelLeft + 16, 0.5),
      reason: '两块不许一个 16 一个 32 —— 那正是这次要消掉的不协调',
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

  testWidgets('壁纸弹窗底部有「背景随周次滑动」开关：默认关，切了写进同一份设置', (
    tester,
  ) async {
    // 2026-09-28 用户口径：调壁纸的地方就能决定背景要不要跟着周次动，不必先去
    // 「设置 → 课表页面」找；而且默认**关**（背景不再整片横移）。
    final provider = await pumpEditor(tester);
    expect(
      provider.settings.homePageBackdropFollowsWeekPager,
      isFalse,
      reason: '默认必须是关',
    );

    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    // 2026-09-28 双页改造：开关在**第二页「设置」**，第一页只有选图与最近使用。
    await _switchWallpaperSheetPage(tester, '设置');

    final tile = find.ancestor(
      of: find.text('背景随周次滑动'),
      matching: find.byType(HyperosSwitchTile),
    );
    expect(tile, findsOneWidget, reason: '壁纸弹窗里必须有这颗开关');
    expect(
      tester.widget<HyperosSwitchTile>(tile).value,
      isFalse,
      reason: '弹窗里读的就是同一份设置，默认关',
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();

    // 同一个字段：「设置 → 课表页面」那行读的就是它，所以两处永远同进同退。
    expect(provider.settings.homePageBackdropFollowsWeekPager, isTrue);
    // 弹层正文不在本页 widget 树下，靠草稿版本号订阅重画（见上面那几条回归钉）。
    expect(tester.widget<HyperosSwitchTile>(tile).value, isTrue);
  });

  testWidgets('开关搬到第二页，且那行外面不再垫一层留白', (tester) async {
    // 2026-09-28 两件事：
    //
    // ① 壁纸弹窗改成「壁纸 / 设置」两页（与材质面板同形状），开关从「最近使用」下面
    //    挪到**第二页**。原先钉的「开关紧接在最近使用之后、只隔 14」测的是**同页相邻**
    //    ——两页之后这个关系不存在了，坐标钉法作废。
    // ② 但它当初要治的病还在：那行外面**不能**再垫一层 `Padding`（行自己已经带
    //    `hyperosRowPadding` 的 13/13）。所以改成钉结构 + 钉「行顶正好落在页面让位处」：
    //    页面顶部让位由 `topInsetFor` 给死，行就该紧接着它开始；多垫一层这里就多一截。
    final dir = Directory.systemTemp.createTempSync('appearance_wall_switch_gap');
    final current = File('${dir.path}/current.png')
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    final older = File('${dir.path}/older.png')
      ..writeAsBytesSync(const [5, 6, 7, 8]);
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows 上解码器可能短暂锁着（errno 32）；断言不依赖这次清理。
      }
    });
    _seedInitializedPrefs(
      TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: current.path,
      ),
      [
        WallpaperHistoryEntry(key: current.path, usedAt: 200),
        WallpaperHistoryEntry(key: older.path, usedAt: 100),
      ],
    );
    await pumpEditor(tester);
    await tester.tap(find.text('调整壁纸'));
    await tester.pumpAndSettle();

    // 分页胶囊就在顶部渐变模糊带上（与材质面板同款形状）。
    final chips = find.byType(HyperosChipRow);
    expect(chips, findsOneWidget);
    expect(
      find.descendant(of: chips, matching: find.text('壁纸')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chips, matching: find.text('设置')),
      findsOneWidget,
    );

    // 切到第二页。
    await _switchWallpaperSheetPage(tester, '设置');

    final row = find.ancestor(
      of: find.text('背景随周次滑动'),
      matching: find.byType(HyperosSwitchTile),
    );
    expect(row, findsOneWidget);

    // 行顶 = 第二页视口顶 + 该页的顶部让位。外面多垫一层留白这条就会红。
    final page = find.byKey(const ValueKey('wallpaper-page-settings'));
    final inset = HyperosSheetBlurTop.topInsetFor(
      headerHeight: hyperosMiuixBottomSheetDragHandleHeight + 40,
    );
    expect(
      tester.getTopLeft(row).dy - tester.getTopLeft(page).dy,
      closeTo(inset, 0.5),
      reason: '行自己已经带 hyperosRowPadding，外面不该再垫一层',
    );
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
    final pageScroll = find
        .descendant(
          of: find.byKey(const ValueKey('material-page-general')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('折射强度'), 120, scrollable: pageScroll);
    await tester.pumpAndSettle();

    // ⚠️ `scrollUntilVisible` 一「看得见」就停手，可能刚好把目标停在**顶部渐变模糊带
    // 底下**。带子（含它的翻页标签）是浮在滚动内容之上的，那一带整片吃点击 —— 与任何
    // 吸顶栏同理，内容停在它底下就点不到。所以这里再把内容往下推一截，让目标落到带子
    // 下面真正能点的位置。（别用 `headerHeight` 之类的数把这钉子写死：带高一变它就红，
    // 而真机上「停在带底点不到」本来就是既有行为，不是回归。）
    await tester.drag(pageScroll, const Offset(0, 80));
    await tester.pumpAndSettle();

    await tester.tap(find.text('折射强度'));
    await tester.pumpAndSettle();

    expect(find.byType(HyperosSheetFrame), findsOneWidget);
    // 面板本身还开着（点空白处不该把面板关掉）。
    expect(find.text('默认材质'), findsOneWidget);
  });
}
