import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('glass dock: settings tab renders full settings page', (tester) async {
    final provider = TimetableProvider(autoInitialize: false);
    // 开启玻璃坞形态
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<TimetableProvider>.value(value: provider)],
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

    // 底栏存在
    expect(find.byType(GlassTabBar), findsOneWidget,
        reason: '玻璃坞形态下底栏应存在');

    // 点击「设置」Tab
    await tester.tap(find.text('课表设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 设置页内容应显示（「课表管理」是设置列表项，底栏 label 是「课表设置」）
    expect(find.text('课表管理'), findsOneWidget, reason: '设置页列表应渲染');
    expect(find.text('课表设置'), findsWidgets);
    final exceptions = tester.takeException();
    expect(exceptions, isNull, reason: '切到设置页不应有异常');
  });

  testWidgets('glass dock: switch back from settings to week view', (tester) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<TimetableProvider>.value(value: provider)],
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

    // 切到设置
    await tester.tap(find.text('课表设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('课表设置'), findsWidgets);

    // 切回周课表
    await tester.tap(find.text('周课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull,
        reason: '切回课表不应有异常');
    // 底栏仍在
    expect(find.byType(GlassTabBar), findsOneWidget);
  });

  testWidgets('glass dock: day view then settings then back', (tester) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<TimetableProvider>.value(value: provider)],
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

    // 切到日视图 Tab
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切日视图不应有异常');

    // 切到设置
    await tester.tap(find.text('课表设置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // 切回日视图
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切回日视图不应有异常');
    expect(find.byType(GlassTabBar), findsOneWidget);
  });

  /// 泵起玻璃坞应用并返回其 provider（供测试读取 currentWeek 等）。
  Future<TimetableProvider> pumpDockApp(
    WidgetTester tester,
    HomeNavigationForm form, {
    bool autoFitSectionHeight = false,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: form,
        timetableAutoFitSectionHeight: autoFitSectionHeight,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
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
    expect(find.byType(GlassTabBar), findsOneWidget);
    return provider;
  }

  /// 泵起玻璃坞应用并返回周课表 PageView 底边 y 坐标。
  Future<double> pumpDockAndWeekPagerBottom(
    WidgetTester tester,
    HomeNavigationForm form,
  ) async {
    await pumpDockApp(tester, form);
    return tester.getBottomRight(find.byType(PageView).first).dy;
  }

  /// 玻璃坞药丸固定占用高度（与屏幕源码 _glassDockPillOccupancy 一致）。
  const double kGlassDockPillOccupancy = 62.0;

  testWidgets('glass dock overlay layout: timetable reaches screen bottom',
      (tester) async {
    final pagerBottom = await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
    );
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 满屏悬浮：课表网格延伸到屏幕底、从玻璃坞药丸下方穿过，
    // 不再为底栏预留独占区域（曾复现：内容底部与药丸顶齐平，
    // 药丸下方留出一条只有壁纸的空带，看起来「没有全屏」）。
    // 测试环境无壁纸，课表面板内部还有 8px 的无壁纸底部内边距。
    const noWallpaperInnerPadding = 8.0;
    expect(pagerBottom,
        closeTo(screenHeight - noWallpaperInnerPadding, 0.5),
        reason: '满屏悬浮模式下课表应延伸到屏幕底部');
  });


  testWidgets(
      'glass dock overlay day view: list keeps scroll relief above pill',
      (tester) async {
    await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
    );
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切日视图不应有异常');

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    const noWallpaperInnerPadding = 8.0;
    // 满屏悬浮下日课表视口仍延伸到屏幕底（美学不变）。
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
    );
    expect(
      panelRect.bottom,
      closeTo(screenHeight - noWallpaperInnerPadding, 0.5),
      reason: 'overlay 下日课表视口应保持全屏',
    );

    // 但滚动余量必须兜底药丸占用（此前 overlay 余量为 0，下滑到底时
    // 最后一张卡压在药丸后面无法滑出来看）。
    final columnPads = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byKey(const ValueKey('timetable-day-view-panel')),
            matching: find.byType(Padding),
          ),
        )
        .toList(growable: false);
    final expectedBottom = noWallpaperInnerPadding + kGlassDockPillOccupancy;
    expect(
      columnPads.any(
        (p) =>
            (p.padding is EdgeInsets) &&
            ((p.padding as EdgeInsets).bottom - expectedBottom).abs() < 0.5,
      ),
      isTrue,
      reason: 'overlay 下日课表底部滚动余量应为药丸占用（62）+ 原有 8px 底距',
    );
  });

  testWidgets(
      'glass dock overlay week grid: vertical scroll gains bottom relief',
      (tester) async {
    await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
    );
    // 默认非自适应：周网格在纵向 SingleChildScrollView 里滚动。
    final scrollFinder = find.byKey(
      const PageStorageKey<String>('week-scroll-1'),
    );
    expect(scrollFinder, findsOneWidget);
    final scrollView = tester.widget<SingleChildScrollView>(scrollFinder);
    final child = scrollView.child;
    expect(child, isA<Padding>(),
        reason: 'overlay 下周网格滚动应包一层底部余量 padding');
    final bottom = ((child! as Padding).padding as EdgeInsets).bottom;
    expect(bottom, closeTo(kGlassDockPillOccupancy, 0.5),
        reason: '被药丸遮住的最后几节课程应能整体滑到药丸上方');
  });

  testWidgets(
      'glass dock overlay autofit grid: sits above pill leaving blank strip',
      (tester) async {
    await pumpDockApp(
      tester,
      HomeNavigationForm.glassDock,
      autoFitSectionHeight: true,
    );
    // 自适应网格没有纵向滚动可救：节高计算必须扣掉药丸占用，
    // 让网格收在药丸上方、课表下方留一条空白。
    // 时间列/网格盒本身会被 body 拉伸到满高，量不到内容底边；
    // 改量时间列的节单元格：内容底边 = 首格顶 + 各节高之和。
    final columnFinder = find.byKey(const ValueKey('timetable-time-column'));
    final column = tester.widget<Column>(
      find.descendant(of: columnFinder, matching: find.byType(Column)).first,
    );
    final sectionCells = column.children.whereType<Container>().toList();
    expect(sectionCells, isNotEmpty);
    // Container 的 height 参数没有公开 getter，直接量渲染矩形。
    final cellRects = sectionCells
        .map((c) => tester.getRect(find.byWidget(c)))
        .toList(growable: false);
    final contentBottom = cellRects.first.top +
        cellRects.fold<double>(0, (sum, r) => sum + r.height);
    final pagerBottom =
        tester.getBottomRight(find.byType(PageView).first).dy;
    expect(
      contentBottom,
      closeTo(pagerBottom - kGlassDockPillOccupancy, 1.0),
      reason: '自适应网格内容底边应在药丸上方（课表下方留白）',
    );
  });
}
