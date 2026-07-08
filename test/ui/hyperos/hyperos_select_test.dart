import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hyperosSelectPopupLayout', () {
    test('flips popup above anchor when space below is insufficient', () {
      const anchor = Rect.fromLTWH(24, 560, 312, 56);
      const estimatedHeight = 240.0;
      const screenHeight = 640.0;
      const safeTop = 24.0;
      const safeBottom = 628.0;

      final layout = hyperosSelectPopupLayout(
        anchorRect: anchor,
        estimatedPopupHeight: estimatedHeight,
        screenHeight: screenHeight,
        safeTop: safeTop,
        safeBottom: safeBottom,
      );

      expect(layout.top + layout.maxHeight, lessThanOrEqualTo(safeBottom + 0.01));
      expect(layout.top, lessThan(anchor.top));
    });
  });

  group('HyperosSelectTile', () {
    testWidgets('shows label and current value', (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: HyperosSelectTile<String>(
            label: 'Theme mode',
            items: const {'Light': 'light', 'Dark': 'dark'},
            value: 'light',
            onChanged: _noop,
          ),
        ),
      );

      expect(find.text('Theme mode'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.byType(HyperosUpDownChevron), findsOneWidget);
    });

    testWidgets('shows subtitle below label with multiline wrap', (
      tester,
    ) async {
      const subtitle =
          'Follow system light/dark mode and apply detected theme automatically.';

      await tester.pumpWidget(
        TestApp(
          home: SizedBox(
            width: 280,
            child: HyperosSelectTile<String>(
              label: 'Theme mode',
              subtitle: subtitle,
              items: const {'Light': 'light', 'Dark': 'dark'},
              value: 'light',
              onChanged: _noop,
            ),
          ),
        ),
      );

      expect(find.text('Theme mode'), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
    });

    testWidgets('aligns current value next to chevron', (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: SizedBox(
            width: 320,
            child: HyperosSelectTile<String>(
              label: 'Theme mode',
              items: const {'Light': 'light', 'Dark': 'dark'},
              value: 'light',
              onChanged: _noop,
            ),
          ),
        ),
      );

      final valueRect = tester.getRect(find.text('Light'));
      final chevronRect = tester.getRect(find.byType(HyperosUpDownChevron));
      final rowRect = tester.getRect(find.byType(Row));

      expect(
        chevronRect.left - valueRect.right,
        greaterThanOrEqualTo(HyperosMiuixDropdown.valueEndPadding - 1),
      );
      expect(valueRect.center.dx, greaterThan(rowRect.center.dx));
    });

    testWidgets('inside HyperosControlCard does not use negative padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: HyperosControlCard(
            title: 'Lead time',
            child: HyperosSelectTile<int>(
              label: 'Minutes before class',
              items: const {'5 min': 5, '10 min': 10},
              value: 5,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Minutes before class'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
    });

    testWidgets(
      'inside HyperosControlCard chevron aligns near card right edge',
      (tester) async {
        const listWidth = 360.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(listWidth, 640));

        await tester.pumpWidget(
          TestApp(
            home: ListView(
              children: [
                HyperosControlCard(
                  title: 'Display mode',
                  child: HyperosSelectTile<String>(
                    label: 'Theme mode',
                    items: const {'Light': 'light', 'Dark': 'dark'},
                    value: 'light',
                    onChanged: _noop,
                  ),
                ),
              ],
            ),
          ),
        );

        final cardRect = tester.getRect(find.byType(HyperosControlCard));
        final chevronRect = tester.getRect(find.byType(HyperosUpDownChevron));

        expect(
          cardRect.right - chevronRect.right,
          closeTo(HyperosTokens.rowPaddingUniform.left, 1),
        );
      },
    );

    testWidgets('matches label leading inset to chevron trailing inset', (
      tester,
    ) async {
      const listWidth = 360.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(listWidth, 640));

      await tester.pumpWidget(
        TestApp(
          home: ListView(
            children: [
              HyperosControlCard(
                title: 'Display mode',
                child: HyperosSelectTile<String>(
                  label: 'Theme mode',
                  items: const {'Light': 'light', 'Dark': 'dark'},
                  value: 'light',
                  onChanged: _noop,
                ),
              ),
            ],
          ),
        ),
      );

      final cardRect = tester.getRect(find.byType(HyperosControlCard));
      final labelRect = tester.getRect(find.text('Theme mode'));
      final chevronRect = tester.getRect(find.byType(HyperosUpDownChevron));
      final leadingInset = labelRect.left - cardRect.left;
      final trailingInset = cardRect.right - chevronRect.right;

      expect(leadingInset, closeTo(HyperosTokens.rowPaddingUniform.left, 1));
      expect(trailingInset, closeTo(leadingInset, 1));
    });

    testWidgets('last row extends to card bottom for press highlight', (
      tester,
    ) async {
      const listWidth = 360.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(listWidth, 640));

      await tester.pumpWidget(
        TestApp(
          home: ListView(
            children: [
              HyperosControlCard(
                title: 'Display mode',
                child: HyperosSelectTile<String>(
                  label: 'Theme mode',
                  items: const {'Light': 'light', 'Dark': 'dark'},
                  value: 'light',
                  onChanged: _noop,
                ),
              ),
            ],
          ),
        ),
      );

      final cardRect = tester.getRect(find.byType(HyperosControlCard));
      final rowRect = tester.getRect(find.byType(HyperosPressableRow));

      expect(cardRect.bottom - rowRect.bottom, closeTo(0, 1));
    });

    testWidgets('opens sheet and reports selection', (tester) async {
      String? selected;

      await tester.pumpWidget(
        TestApp(
          home: HyperosSelectTile<String>(
            label: 'Theme mode',
            items: const {'Light': 'light', 'Dark': 'dark'},
            value: 'light',
            useSheetForPopup: true,
            onChanged: (value) => selected = value,
          ),
        ),
      );

      await tester.tap(find.text('Theme mode'));
      await tester.pumpAndSettle();

      expect(find.text('Dark'), findsWidgets);

      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      expect(selected, 'dark');
    });

    testWidgets('anchored popup stays on screen when anchor is near bottom', (
      tester,
    ) async {
      const screenHeight = 640.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, screenHeight));

      await tester.pumpWidget(
        TestApp(
          home: ListView(
            children: [
              const SizedBox(height: 500),
              HyperosControlCard(
                child: HyperosSelectTile<int>(
                  label: 'Keep at most',
                  items: {
                    for (final count in [5, 10, 15, 20, 30])
                      '$count versions': count,
                  },
                  value: 15,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Keep at most'));
      await tester.pumpAndSettle();

      for (final label in ['5 versions', '30 versions']) {
        final option = find.text(label).last;
        expect(option, findsOneWidget);
        final rect = tester.getRect(option);
        expect(rect.bottom, lessThanOrEqualTo(screenHeight));
        expect(rect.top, greaterThanOrEqualTo(0));
      }
    });
  });

  group('showHyperosSelectSheet', () {
    testWidgets('floats card with horizontal and bottom insets', (
      tester,
    ) async {
      const screenWidth = 360.0;
      const screenHeight = 800.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(
        const Size(screenWidth, screenHeight),
      );

      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showHyperosSelectSheet<String>(
                    context: context,
                    title: 'Pick one',
                    items: const {'Light': 'light', 'Dark': 'dark'},
                    currentValue: 'light',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cardMaterial = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.borderRadius is BorderRadius &&
            (widget.borderRadius as BorderRadius).topLeft.x ==
                HyperosMiuixDialog.minBottomCornerRadius,
      );
      final cardRect = tester.getRect(cardMaterial);
      const horizontalInset = HyperosMiuixBasicComponent.insideMarginHorizontal;
      const bottomInset = HyperosMiuixBasicComponent.selectSheetBottomMargin;
      expect(cardRect.left, closeTo(horizontalInset, 1));
      expect(cardRect.right, closeTo(screenWidth - horizontalInset, 1));
      expect(cardRect.bottom, closeTo(screenHeight - bottomInset, 1));
    });
  });

  group('HyperosChoiceTile dialog variant', () {
    testWidgets('selected background spans card width', (tester) async {
      const cardWidth = 320.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: cardWidth,
              child: Material(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HyperosChoiceTile(
                      title: 'Light',
                      selected: true,
                      highlightSelectedText: true,
                      variant: HyperosChoiceVariant.dialog,
                      onTap: () {},
                    ),
                    HyperosChoiceTile(
                      title: 'Dark',
                      variant: HyperosChoiceVariant.dialog,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final highlightRect = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color.a > 0,
        ),
      );

      expect(highlightRect.width, cardWidth);
    });
  });
}

void _noop(String _) {}
