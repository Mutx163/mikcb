import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/settings/timetable_settings_enums.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/home_menu_route_catalog.dart';
import 'package:university_timetable/widgets/timetable_home_preview_scope.dart';

/// 月视图作为**首页第三个视图**的持久化与恢复契约。
///
/// 为什么放 `test/services/` 而不是 `test/widgets/`：本仓 TEST-POLICY 冻结了
/// `test/widgets|screens|ui` 三处（不许新增），而 `test/services/` 已有
/// `testWidgets` 先例（`month_view_*_test.dart` 全在这里泵真页面）。
///
/// 为什么直接断言 `provider.settings.timetableHomeViewMode` 而不是只看
/// 「月视图页面打开了」：AGENTS.md「参数透传类改动」那条 —— 页面打开了不等于
/// 模式落盘了。用户下次冷启动读的是**落盘值**，不是这一屏。
void main() {
  setUp(() {
    // 内嵌页登记表由首页挂载时注入；测试直接调一次，否则底栏会退化成推路由。
    registerHomeMenuRoutes(
      const HomeMenuRouteRegistry(
        inlineDockPages: [
          HomeMenuPageDescriptor(id: 'monthView', build: SizedBox.new),
        ],
        catalogPages: [],
        pushUpdateEntry: _noopPush,
      ),
    );
  });

  Future<TimetableProvider> pumpHome(
    WidgetTester tester, {
    TimetableHomeViewMode mode = TimetableHomeViewMode.week,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockActions: const ['day', 'monthView', 'week'],
        timetableHomeViewMode: mode,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
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
    expect(tester.takeException(), isNull);
    return provider;
  }

  Future<void> settle(WidgetTester tester, TimetableProvider provider) async {
    // persistHomeViewState 是 unawaited + _runMutation 串行队列，放到帧后再等一轮。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    provider.settings.toString();
  }

  testWidgets('点底栏月视图：模式落盘为 month（不是只把页面打开）', (tester) async {
    final provider = await pumpHome(tester);
    expect(provider.settings.timetableHomeViewMode, TimetableHomeViewMode.week);

    await tester.tap(find.text('月视图').first);
    await settle(tester, provider);

    expect(
      provider.settings.timetableHomeViewMode,
      TimetableHomeViewMode.month,
      reason: '月视图是第三个视图：切过去就得把「停在哪个视图」记住，'
          '否则杀进程重开会掉回周视图（本轮要修的就是这个）。',
    );
  });

  testWidgets('持久化为 month：冷启动首页直接落在月视图', (tester) async {
    await pumpHome(tester, mode: TimetableHomeViewMode.month);

    expect(
      find.byType(MonthViewScreen),
      findsOneWidget,
      reason: '恢复只认持久化模式。这一条现在红：'
          '首页只认 day / week 两个值，month 走 else 分支变周课表。',
    );
  });

  testWidgets('缩尺预览不摆月视图：编辑器的分段只有日 / 周两档', (tester) async {
    // 预览那份首页被 IgnorePointer 包着（点不动），宿主唯一的视图控件是
    // 「日课表 / 周课表」两档分段。若按持久化值把月视图摆进预览，用户会看到
    // 一个分段怎么拨都不改变的页面 —— 等于让编辑器的控件看起来是坏的。
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockActions: const ['day', 'monthView', 'week'],
        timetableHomeViewMode: TimetableHomeViewMode.month,
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
          home: TimetableHomePreviewScope(
            dayView: ValueNotifier(false),
            dayOfWeek: ValueNotifier(1),
            // 预览宿主自己带 FrostedAppearanceScope，这里照宿主用法给一份。
            child: const FrostedAppearanceScope(
              appearance: FrostedAppearance.defaults,
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
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(MonthViewScreen), findsNothing);
  });

  testWidgets('从月视图切回周课表：模式落回 week，不再停在 month', (tester) async {
    final provider = await pumpHome(tester, mode: TimetableHomeViewMode.month);
    expect(find.byType(MonthViewScreen), findsOneWidget);

    await tester.tap(find.text('周课表').first);
    await settle(tester, provider);

    expect(
      provider.settings.timetableHomeViewMode,
      TimetableHomeViewMode.week,
      reason: '离开内嵌页若还回 month，就写成「关掉月视图 → 又落回月视图」。',
    );
    expect(find.byType(MonthViewScreen), findsNothing);
  });
}

Future<void> _noopPush(BuildContext context) async {}
