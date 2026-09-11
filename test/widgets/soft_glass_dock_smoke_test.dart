import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_tab_bar.dart';

/// 底栏材质跟随**全局材质**（不再有独立的「底栏材质」开关），
/// 因此这里的 appearance 就是唯一输入。
FrostedAppearance _appearanceWith(FrostedGlassMode mode) => FrostedAppearance(
  sheetBlurSigma: FrostedAppearance.defaults.sheetBlurSigma,
  sheetTintAlpha: FrostedAppearance.defaults.sheetTintAlpha,
  sheetBarrierAlpha: FrostedAppearance.defaults.sheetBarrierAlpha,
  glassMode: mode,
);

void main() {
  Future<TimetableProvider> pumpDock(
    WidgetTester tester,
    FrostedGlassMode mode,
  ) async {
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
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: FrostedAppearanceScope(
            appearance: _appearanceWith(mode),
            child: const TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  testWidgets('全局柔光玻璃 → 底栏走 SoftGlassTabBar', (tester) async {
    await pumpDock(tester, FrostedGlassMode.softGlass);
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
    expect(find.byType(GlassTabBar), findsNothing);
  });

  testWidgets('柔光底栏 tab 点击可切到日课表', (tester) async {
    final provider = await pumpDock(tester, FrostedGlassMode.softGlass);
    expect(provider.settings.timetableHomeViewMode, TimetableHomeViewMode.week);
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('全局液态玻璃 → 底栏仍走 GlassTabBar', (tester) async {
    await pumpDock(tester, FrostedGlassMode.liquidGlass);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byType(SoftGlassTabBar), findsNothing);
  });
}