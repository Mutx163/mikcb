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

    testWidgets(
      'list group spans list width when child is intrinsically narrow',
      (tester) async {
        const listWidth = 360.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(listWidth, 640));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  HyperosListGroup(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          children: List.generate(
                            6,
                            (_) => const SizedBox(width: 42, height: 42),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        final groupRect = tester.getRect(find.byType(HyperosListGroup));
        expect(groupRect.width, listWidth);
      },
    );

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
        find.descendant(
          of: find.byType(HyperosNavTile),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height == HyperosTokens.listRowMinHeight,
          ),
        ),
      );
      expect(rowBox.size.height, HyperosTokens.listRowMinHeight);
    });
  });
}
