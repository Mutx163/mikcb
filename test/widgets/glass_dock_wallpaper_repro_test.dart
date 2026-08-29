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
/// 曾复现真机 bug：页面壳把 [HomePageSlidingBackdropLayer] /
/// [homePageBackdropLayer]（内含 Positioned）包进 Offstage，触发
/// "Incorrect use of ParentDataWidget"，release 下整页灰屏、
/// 底栏指示器停在原 Tab。修复后本测试断言：周→日→周 全链路无异常、
/// 指示器跟随 selectedIndex（「设置」Tab 已移除，
/// 原周→日→设置→日→周 路径随之收敛为 周→日→周）。
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
    expect(currentIndicatorIndex(), 1,
        reason: '初始指示器应在周课表 Tab（排序：日课表/周课表）');

    // Tab 排序：日课表(左) / 周课表(右)；「设置」Tab 已移除，底栏不再出现。
    expect(find.text('课表设置'), findsNothing,
        reason: '玻璃坞底栏只有 日/周 两个 Tab');
    final dayTabX = tester.getCenter(find.text('日课表').first).dx;
    final weekTabX = tester.getCenter(find.text('周课表').first).dx;
    expect(dayTabX, lessThan(weekTabX), reason: '日课表应位于周课表左侧');

    // 切日视图（玻璃坞：底栏闪现直切——animate:false，首帧即完整就位，
    // 无锚点缩放槽；日期栏路径才保留锚点展开动画）。
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '切日视图（有壁纸）不应有异常');
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsOneWidget,
      reason: '日视图面板应显示',
    );
    // 闪现直切：首帧即铺满全宽（不存在缩放中的 Align 槽）。
    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.widthFactor != null && w.widthFactor! < 0.9,
      ),
      findsNothing,
      reason: '玻璃坞切日视图应闪现直切（首帧无缩放中的 Align 槽）',
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(currentIndicatorIndex(), 0, reason: '日视图下指示器应在日课表 Tab');

    // 日视图自带顶部信息栏：显示星期几（不是空白栏）
    expect(
      find.text('周一'),
      findsWidgets,
      reason: '日视图顶部信息栏应显示星期',
    );

    // 切回周课表
    await tester.tap(find.text('周课表').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '切回周视图不应有异常');
    expect(currentIndicatorIndex(), 1, reason: '周视图下指示器应回到周课表 Tab');

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

  testWidgets('glass dock + wallpaper: 周→日→周（壁纸随周次滑动）', (tester) async {
    await runScenarios(tester, followsWeekPager: true);
  });

  testWidgets('glass dock + wallpaper: 周→日→周（壁纸固定）', (tester) async {
    await runScenarios(tester, followsWeekPager: false);
  });
}
