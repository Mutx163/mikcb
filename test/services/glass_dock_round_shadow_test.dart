import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 玻璃坞「药丸 + 右侧独立圆钮」的阴影契约（2026-10-23）。
///
/// 用户口径：「右边独立的那个圈圈，也要加上这边底栏一样的阴影」。
///
/// 此前只有药丸在 `_dockPillSurface` 里垫了 `HyperosGlassShadow.compactShadow`，
/// 圆钮是一块裸玻璃 —— 纯白主题、无壁纸时两者并排，药丸有边界、圆钮和页面底
/// 糊成一片。本文件把「两者同源」钉死：圆钮也必须走同一份
/// `HyperosGlassShadow.wrap` + `compactShadow`，并且外阴影裁切层要挖空圆心
/// （否则 `BackdropFilter` 会把阴影采进玻璃中央，白玻璃发灰）。
void main() {
  Future<void> pumpDock(WidgetTester tester) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        // 圆钮默认不显示（settings 默认 false），要显式打开。
        glassDockShowAddButton: true,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
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
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
  }

  BoxDecoration shadowDecorationOf(WidgetTester tester, Key clipKey) {
    final clipFinder = find.byKey(clipKey);
    expect(clipFinder, findsOneWidget, reason: '缺少外浮影裁切层 $clipKey');
    final decorated = find.descendant(
      of: clipFinder,
      matching: find.byType(DecoratedBox),
    );
    expect(decorated, findsOneWidget);
    return tester.widget<DecoratedBox>(decorated).decoration as BoxDecoration;
  }

  testWidgets('右侧独立圆钮与药丸共用同一份外浮影（compactShadow）', (tester) async {
    await pumpDock(tester);

    const pillShadowKey = ValueKey('glass-dock-pill-shadow');
    const roundShadowKey = ValueKey('glass-dock-round-shadow');

    final pillDecoration = shadowDecorationOf(tester, pillShadowKey);
    final roundDecoration = shadowDecorationOf(tester, roundShadowKey);

    expect(
      pillDecoration.boxShadow?.single,
      HyperosGlassShadow.compactShadow,
      reason: '药丸浮影是这条契约的参照物',
    );
    expect(
      roundDecoration.boxShadow?.single,
      HyperosGlassShadow.compactShadow,
      reason: '圆钮必须与药丸同源，不能是裸玻璃',
    );
    expect(
      roundDecoration.borderRadius,
      BorderRadius.circular(28),
      reason: '圆钮 56 正圆，浮影半径取边长一半',
    );

    // 圆心的阴影必须被挖空：否则玻璃内部会透出阴影，白玻璃发灰。
    final roundClip = find.byKey(roundShadowKey);
    final size = tester.getSize(
      find.ancestor(of: roundClip, matching: find.byType(Stack)).first,
    );
    final path = tester.widget<ClipPath>(roundClip).clipper!.getClip(size);
    expect(
      path.contains(size.center(Offset.zero)),
      isFalse,
      reason: '玻璃内部必须完全透明，阴影不能渗进圆钮中央',
    );
  });
}
