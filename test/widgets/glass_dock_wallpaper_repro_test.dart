import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 复现环境：真实壁纸文件存在（hasBackdrop=true），与真机一致。
///
/// 曾复现真机 bug：设置页壳把 [HomePageSlidingBackdropLayer] /
/// [homePageBackdropLayer]（内含 Positioned）包进 Offstage，触发
/// "Incorrect use of ParentDataWidget"，release 下整页灰屏、
/// 底栏指示器停在原 Tab。修复后本测试断言：周→日→设置→周 全链路
/// 无异常、设置内容渲染、指示器跟随 selectedIndex。
void main() {
  // 1x1 纯色 PNG
  const tinyPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  Future<(Directory, String)> makeWallpaper() async {
    final dir = await Directory.systemTemp.createTemp('glassdock-wallpaper');
    final file = File('${dir.path}/wallpaper.png');
    await file.writeAsBytes(base64Decode(tinyPngBase64));
    return (dir, file.path);
  }

  Future<void> pumpApp(
    WidgetTester tester,
    TimetableProvider provider,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance.defaults,
            child: TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// 读取底栏指示器当前 tabIndex（TabIndicator 由包内部提供）。
  int? currentIndicatorIndex() {
    final finder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TabIndicator',
    );
    if (finder.evaluate().isEmpty) {
      return null;
    }
    return (finder.evaluate().first.widget as dynamic).tabIndex as int?;
  }

  Future<void> runScenarios(
    WidgetTester tester, {
    required bool followsWeekPager,
  }) async {
    // 真实文件 IO 放进 runAsync；provider 设置更新保持与 smoke test 相同的
    // fake-async 调用方式（settings 在方法体内同步生效；未完成的异步链在
    // fake-async 下保持挂起，不会抛出未处理的平台通道异常）。
    late String wallpaperPath;
    late Directory dir;
    await tester.runAsync(() async {
      (dir, wallpaperPath) = await makeWallpaper();
    });
    addTearDown(() => dir.delete(recursive: true));

    final provider = TimetableProvider(autoInitialize: false);
    unawaited(
      provider.updateTimetableSettings(
        provider.settings.copyWith(
          homeNavigationForm: HomeNavigationForm.glassDock,
          homePageWallpaperPath: wallpaperPath,
          homePageBackdropFollowsWeekPager: followsWeekPager,
        ),
      ),
    );
    // 壁纸路径变化时 updateTimetableSettings 会 precache 壁纸（8 秒超时
    // Timer）；用 pump 推掉，避免测试结束报 pending timer / 挂死。
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));

    await pumpApp(tester, provider);
    expect(tester.takeException(), isNull, reason: '周视图初始渲染不应有异常');
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(currentIndicatorIndex(), 0,
        reason: '初始指示器应在周课表 Tab');

    // 切日视图（玻璃坞：横向滑动转场 + 直接全宽，无锚点展开渐变）
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '切日视图（有壁纸）不应有异常');
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsOneWidget,
      reason: '日视图面板应显示',
    );
    final earlyPanelRect = tester.getRect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
    );
    // 锚点展开动画会让面板处于 Align(widthFactor < 1) 的缩放槽中；
    // 玻璃坞切换不应有这种缩放（直接全宽）。
    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.widthFactor != null && w.widthFactor! < 0.9,
      ),
      findsNothing,
      reason: '玻璃坞切日视图应直接全宽（无锚点展开渐变）',
    );
    expect(
      earlyPanelRect.left,
      greaterThan(0),
      reason: '玻璃坞切日视图应横向滑动进入（从右侧滑入）',
    );
    await tester.pump(const Duration(milliseconds: 400));
    final settledPanelRect = tester.getRect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
    );
    expect(
      settledPanelRect.left,
      closeTo(0, 1),
      reason: '滑动完成后日视图应就位',
    );
    expect(currentIndicatorIndex(), 1, reason: '日视图下指示器应在日课表 Tab');

    // 切设置
    await tester.tap(find.text('课表设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切设置（有壁纸）不应有异常');
    expect(find.text('课表管理'), findsOneWidget, reason: '设置列表应渲染');
    expect(currentIndicatorIndex(), 2, reason: '设置下指示器应在设置 Tab');

    // —— 问题 2：周次概览不被浮动大标题遮挡 ——
    final weekText = find.textContaining('当前第');
    expect(weekText, findsOneWidget, reason: '设置页首屏应显示周次概览');
    final weekRect = tester.getRect(weekText);
    final titleRect = tester.getRect(find.byType(HyperosCollapsibleTopAppBar));
    expect(
      weekRect.top,
      greaterThanOrEqualTo(titleRect.bottom - 1),
      reason: '周次概览应位于展开的大标题下方，不被遮挡',
    );

    // —— 问题 3：列表视口全屏，玻璃坞悬浮其上（避让是滚动 padding）——
    final listRect = tester.getRect(find.byType(HyperosListView));
    expect(
      listRect.height,
      closeTo(600, 1),
      reason: '玻璃坞内嵌时设置列表视口应为全屏（不是被底部避让压缩）',
    );

    // 滚动到中间：大标题应折叠 + 内容应从悬浮玻璃坞后面穿过。
    // 慢速短距拖拽（惯性小），并等惯性完全结束再断言——否则惯性
    // （BallisticScrollActivity）会把列表滚到底部，玻璃坞区域只剩
    // 底部 padding，误判为「内容没有穿过玻璃坞」。
    await tester.timedDrag(
      find.byType(HyperosListView),
      const Offset(0, -250),
      const Duration(milliseconds: 800),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull, reason: '滚动设置页不应有异常');

    // 大标题应折叠为小标题
    final collapsibleState = tester
        .widget<HyperosCollapsibleTopAppBar>(
          find.byType(HyperosCollapsibleTopAppBar),
        )
        .scrollBehavior!
        .state;
    expect(
      collapsibleState.heightOffset,
      lessThan(-1),
      reason: '滚动后大标题应折叠为小标题',
    );

    // 内容从悬浮玻璃坞后面穿过：滚动后列表内有文本与玻璃坞区域相交
    // （玻璃坞是悬浮层，内容滚到它后面仍可见）。
    final glassRect = tester.getRect(find.byType(GlassTabBar));
    final glassOverlapTop = glassRect.top + 4;
    final listTexts = find
        .descendant(
          of: find.byType(HyperosListView),
          matching: find.byType(Text),
        )
        .evaluate();
    var crossedUnderGlass = false;
    for (final element in listTexts) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) {
        continue;
      }
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.bottom > glassOverlapTop && rect.top < glassRect.bottom) {
        crossedUnderGlass = true;
        break;
      }
    }
    expect(
      crossedUnderGlass,
      isTrue,
      reason: '滚动内容应从悬浮玻璃坞后面穿过（玻璃坞浮在内容之上）',
    );

    // 记录滚动位置（设置页可能在 Offstage 中，finder 需跳过 offstage 过滤）
    final scrollableFinder = find
        .descendant(
          of: find.byType(HyperosListView, skipOffstage: false),
          matching: find.byType(Scrollable, skipOffstage: false),
        )
        .first;
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    final pixelsBefore = scrollable.position.pixels;
    expect(pixelsBefore, greaterThan(50), reason: '列表应已滚动');

    // 切周课表再切回设置：滚动位置与大标题折叠状态都应保留
    await tester.tap(find.text('周课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('课表设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切回设置不应有异常');
    final scrollableAfter = tester.state<ScrollableState>(scrollableFinder);
    expect(
      (scrollableAfter.position.pixels - pixelsBefore).abs(),
      lessThan(1),
      reason: '切走再切回后设置页滚动位置应保留',
    );
    final collapsibleStateAfter = tester
        .widget<HyperosCollapsibleTopAppBar>(
          find.byType(HyperosCollapsibleTopAppBar),
        )
        .scrollBehavior!
        .state;
    expect(
      collapsibleStateAfter.heightOffset,
      lessThan(-1),
      reason: '切走再切回后大标题应保持折叠（不是重置为展开大字）',
    );

    // 设置 → 日视图（设置页滚动到中间后仍可切换）
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: '设置→日视图不应有异常');
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsOneWidget,
      reason: '设置切回后日视图面板应显示',
    );
    expect(currentIndicatorIndex(), 1, reason: '设置→日视图后指示器应在日课表 Tab');

    // 切回周课表
    await tester.tap(find.text('周课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: '切回周视图不应有异常');
    expect(currentIndicatorIndex(), 0, reason: '周视图下指示器应回到周课表 Tab');

    // 日期栏路径（点顶部日期单元格）：保持锚点展开动画（面板从小放大），
    // 不做横向滑动转场（面板无右滑位移，且存在缩放中的 Align 槽）。
    await tester.tap(find.byKey(const ValueKey('weekday-header-1-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final anchorRect = tester.getRect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
    );
    expect(
      anchorRect.left,
      closeTo(0, 1),
      reason: '日期栏路径不应有横向滑动位移',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.widthFactor != null && w.widthFactor! < 0.9,
      ),
      findsWidgets,
      reason: '日期栏路径应保持锚点展开动画（存在缩放中的 Align 槽）',
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.widthFactor != null && w.widthFactor! < 0.9,
      ),
      findsNothing,
      reason: '日期栏路径展开动画应最终铺满（缩放槽消失）',
    );
    expect(tester.takeException(), isNull, reason: '日期栏路径不应有异常');

    // 收尾：推掉任何遗留的 fake timer。
    await tester.pump(const Duration(seconds: 9));
  }

  testWidgets('glass dock + wallpaper: 周→日→设置→日→周（壁纸随周次滑动）', (tester) async {
    await runScenarios(tester, followsWeekPager: true);
  });

  testWidgets('glass dock + wallpaper: 周→日→设置→日→周（壁纸固定）', (tester) async {
    await runScenarios(tester, followsWeekPager: false);
  });
}
