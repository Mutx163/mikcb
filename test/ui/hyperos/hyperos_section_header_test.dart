import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hyperos section headers', () {
    testWidgets('section label uses light footnote style', (tester) async {
      late TextStyle style;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              style = HyperosTypography.sectionLabel(context);
              return const Scaffold(body: HyperosSectionLabel(text: '权限管控'));
            },
          ),
        ),
      );

      expect(find.text('权限管控'), findsOneWidget);
      expect(style.fontSize, HyperosMiuixSpec.settingsSectionLabelSize);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, HyperosMiuixSpec.settingsSectionLabelColor);
      expect(style.color, isNot(HyperosTokens.secondaryText));
      expect(style.color, isNot(HyperosTokens.primaryText));
    });

    test('list group card uses squircle shape token', () {
      expect(HyperosTheme.cardShape(), isA<RoundedSuperellipseBorder>());
    });

    test('strip card uses stadium shape token', () {
      expect(HyperosTheme.stripShape(), isA<StadiumBorder>());
    });

    testWidgets('single-row nav tile keeps 56dp touch height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(children: [HyperosNavTile(title: '已下载的应用')]),
          ),
        ),
      );

      final rowBox = tester.renderObject<RenderBox>(
        find.ancestor(of: find.text('已下载的应用'), matching: find.byType(SizedBox)),
      );
      expect(rowBox.size.height, HyperosTokens.listRowMinHeight);
    });
  });
}
