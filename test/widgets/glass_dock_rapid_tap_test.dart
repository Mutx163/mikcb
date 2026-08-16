import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

/// 快速连点回归：玻璃坞 1→3→1→3（日课表→设置→日课表→设置）不允许丢拍。
void main() {
  testWidgets('glass dock: rapid 1-3-1-3 taps never drop a beat', (tester) async {
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

    // 底栏 label 用 .last（树序最后是底栏；设置页可见时 .first 会命中其大标题）
    final dayTab = find.text('日课表').last;
    final settingsTab = find.text('课表设置').last;

    // 快速连点 1→3→1→3：动画未完成就点下一个（每拍之间只 pump 一帧）
    await tester.tap(dayTab);
    await tester.pump();
    await tester.tap(settingsTab);
    await tester.pump();
    await tester.tap(dayTab);
    await tester.pump();
    await tester.tap(settingsTab);
    await tester.pump();

    // 等全部弹簧动画收敛
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '快速连点不应有异常');
    expect(indicatorIndex(), 2, reason: '连点 1313 后应最终停在设置 Tab（不丢最后一下）');
    expect(find.text('课表管理'), findsOneWidget, reason: '设置页应最终渲染');
  });
}