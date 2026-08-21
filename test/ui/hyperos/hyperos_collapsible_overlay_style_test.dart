import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_collapsible_top_app_bar.dart';

/// Locks the status-bar overlay contract of [HyperosCollapsibleTopAppBar]:
///
/// The bar may only derive its own SystemUiOverlayStyle from a FULLY OPAQUE
/// background color. computeLuminance() ignores alpha, so transparent /
/// translucent colors read as "dark" and emit white icons — and because this
/// inner annotation paints above the page shell's annotation (which derives
/// from the real page background), it would win at the status-bar strip.
/// That is exactly how light-theme settings pages ended up white-on-white
/// (see commit 3482567).
Finder _barOverlayRegions() => find.descendant(
      of: find.byType(HyperosCollapsibleTopAppBar),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );

Future<void> _pumpBar(WidgetTester tester, Color? color) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HyperosCollapsibleTopAppBar(title: '设置', color: color),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('transparent bar emits no status-bar annotation', (tester) async {
    // Mirrors _HyperosBlurredPage._buildHeaderContent: the frosted shell tints
    // the bar itself, so the bar must let the outer AnnotatedRegion decide.
    await _pumpBar(tester, Colors.transparent);
    expect(_barOverlayRegions(), findsNothing);
  });

  testWidgets('translucent bar defers to the outer shell too', (tester) async {
    await _pumpBar(tester, const Color(0x80000000));
    expect(_barOverlayRegions(), findsNothing);
  });

  testWidgets('opaque dark bar derives light icons from its own color', (
    tester,
  ) async {
    await _pumpBar(tester, const Color(0xFF123456));
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      _barOverlayRegions(),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('opaque settings-like bar derives dark icons', (tester) async {
    // #F2F2F2 = HyperosTokens.background: exactly the settings-page case that
    // regressed to white icons before the fix.
    await _pumpBar(tester, const Color(0xFFF2F2F2));
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      _barOverlayRegions(),
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
  });
}
