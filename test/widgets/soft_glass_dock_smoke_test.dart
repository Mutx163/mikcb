import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';
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

  testWidgets('全局柔光玻璃 → 底栏药丸走 SoftGlassSurface', (tester) async {
    await pumpDock(tester, FrostedGlassMode.softGlass);
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
    expect(find.byType(SoftGlassSurface), findsWidgets);
    expect(find.byType(LiquidGlassSurface), findsNothing);
  });

  testWidgets('柔光底栏 tab 点击可切到日课表', (tester) async {
    final provider = await pumpDock(tester, FrostedGlassMode.softGlass);
    expect(provider.settings.timetableHomeViewMode, TimetableHomeViewMode.week);
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('全局液态玻璃 → 同一套底栏，药丸走 LiquidGlassSurface', (tester) async {
    // 四种材质共用同一套底栏实现（拖拽切换 / 弹簧指示器 / 速度拉伸），
    // 差异只在注入的底面（见 TimetableScreen._dockPillSurface）。
    await pumpDock(tester, FrostedGlassMode.liquidGlass);
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
    expect(find.byType(LiquidGlassSurface), findsWidgets);
    expect(find.byType(SoftGlassSurface), findsNothing);
  });

  testWidgets('全局基础档 → 底栏实体药丸 + 主题墨色', (tester) async {
    // 基础档（实体/高斯）不受作用范围开关约束；VM 上无模糊能力，
    // 高斯档落到实体药丸——正对应全局实体卡片档在真机上的材质。
    await pumpDock(tester, FrostedGlassMode.frosted);
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
    expect(find.byType(LiquidGlassSurface), findsNothing);
    expect(find.byType(SoftGlassSurface), findsNothing);

    final barContext = tester.element(find.byType(SoftGlassTabBar));
    // 实体药丸：不透明主题卡面（浅色主题 ≈ 纯白）。
    expect(
      find.descendant(
        of: find.byType(SoftGlassTabBar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == HyperosColors.surfaceContainer(barContext),
        ),
      ),
      findsOneWidget,
    );
    // 墨色跟主题（浅色主题 = 深墨），不跟壁纸亮度——暗壁纸下不再白底白字。
    final bar = tester.widget<SoftGlassTabBar>(find.byType(SoftGlassTabBar));
    expect(bar.unselectedColor, Colors.black.withValues(alpha: 0.48));
  });
}