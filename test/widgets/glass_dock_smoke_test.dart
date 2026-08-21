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

  /// 泵起玻璃坞应用并返回周课表 PageView 底边 y 坐标。
  Future<double> pumpDockAndWeekPagerBottom(
    WidgetTester tester,
    HomeNavigationForm form,
    GlassDockLayout layout, {
    double? insetClearance,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: form,
        glassDockLayout: layout,
        glassDockInsetClearance:
            insetClearance ?? glassDockInsetClearanceDefault,
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
    return tester.getBottomRight(find.byType(PageView).first).dy;
  }

  testWidgets('glass dock overlay layout: timetable reaches screen bottom',
      (tester) async {
    final pagerBottom = await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
      GlassDockLayout.overlay,
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

  testWidgets('glass dock inset layout: content reserves pill clearance',
      (tester) async {
    final pagerBottom = await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
      GlassDockLayout.inset,
    );
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 内容避让：课表底部预留默认避让高度（62，即可调下限=药丸占用），
    // 最后一行不被遮挡。
    const noWallpaperInnerPadding = 8.0;
    expect(pagerBottom,
        closeTo(
          screenHeight -
              glassDockInsetClearanceDefault -
              noWallpaperInnerPadding,
          0.5,
        ),
        reason: '内容避让模式课表底部应预留玻璃坞空间');
  });

  testWidgets(
      'glass dock inset layout: custom clearance height is respected',
      (tester) async {
    const customClearance = 100.0;
    final pagerBottom = await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
      GlassDockLayout.inset,
      insetClearance: customClearance,
    );
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 用户自定义避让高度（滑动条）应直接决定内容底边位置。
    const noWallpaperInnerPadding = 8.0;
    expect(pagerBottom,
        closeTo(screenHeight - customClearance - noWallpaperInnerPadding, 0.5),
        reason: '内容避让模式应使用用户设定的避让高度');
  });

  testWidgets('glass dock inset day view: panel reaches screen bottom',
      (tester) async {
    await pumpDockAndWeekPagerBottom(
      tester,
      HomeNavigationForm.glassDock,
      GlassDockLayout.inset,
    );
    // 切到日课表：列表视口应全屏（不再被外层布局 padding 在避让边界
    // 硬裁），避让改由列表滚动 padding 承担——否则滚动时卡片在边界被
    // 裁断，裁切线下的生壁纸空带与上方磨砂卡片区色差明显。
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切日视图不应有异常');

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 测试环境无壁纸：课表面板外还有 8px 的无壁纸底部内边距。
    const noWallpaperInnerPadding = 8.0;
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
    );
    expect(
      panelRect.bottom,
      closeTo(screenHeight - noWallpaperInnerPadding, 0.5),
      reason: '日课表面板视口应延伸到屏幕底部（不再被避让 padding 压缩）',
    );

    // 避让量转移到滚动/内容 padding 上（默认避让高度 + 原有 8px 底距；
    // 测试环境底部安全区为 0）。
    final columnPads = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byKey(const ValueKey('timetable-day-view-panel')),
            matching: find.byType(Padding),
          ),
        )
        .toList(growable: false);
    final expectedBottom =
        noWallpaperInnerPadding + glassDockInsetClearanceDefault;
    expect(
      columnPads.any(
        (p) =>
            (p.padding is EdgeInsets) &&
            ((p.padding as EdgeInsets).bottom - expectedBottom).abs() < 0.5,
      ),
      isTrue,
      reason: '日课表列/空态的底部 padding 应包含玻璃坞避让量',
    );
  });
}
