import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

/// 快速连点回归：玻璃坞 日/周 两 Tab 快速交替连点不允许丢拍
/// （原 1→3→1→3 三 Tab 场景随「设置」Tab 移除而改为两态交替）。
void main() {
  testWidgets(
      'glass dock: rapid day/week alternating taps never drop a beat',
      (tester) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
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
            GlobalWidgetsLocalizations.delegate,
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

    int? indicatorIndex() {
      final finder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'TabIndicator',
      );
      if (finder.evaluate().isEmpty) {
        return null;
      }
      return (finder.evaluate().first.widget as dynamic).tabIndex as int?;
    }

    expect(indicatorIndex(), 1, reason: '初始应在周课表 Tab');

    // 底栏 label 用 .last（树序最后是底栏，避开页面内同名文本）
    final dayTab = find.text('日课表').last;
    final weekTab = find.text('周课表').last;

    // 快速连点 周→日→周→日：动画未完成就点下一个（每拍之间只 pump 一帧），
    // 防抖/丢拍实现会让最后一下丢失。
    await tester.tap(dayTab);
    await tester.pump();
    await tester.tap(weekTab);
    await tester.pump();
    await tester.tap(dayTab);
    await tester.pump();

    // 等全部弹簧动画收敛
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '快速连点不应有异常');
    expect(indicatorIndex(), 0, reason: '连点后应最终停在日课表 Tab（不丢最后一下）');
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsOneWidget,
      reason: '日课表应最终渲染',
    );
  });
}
