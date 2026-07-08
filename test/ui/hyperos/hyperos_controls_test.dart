import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HyperosSwitchTile', () {
    testWidgets('uses HyperosSwitch and toggles on row tap', (tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  title: 'Dark mode',
                  subtitle: 'Follow system',
                  value: value,
                  onChanged: (v) => value = v,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HyperosSwitch), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Follow system'), findsOneWidget);

      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('disabled tile does not toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosSwitchTile(
              title: 'Locked',
              value: false,
              onChanged: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Locked'));
      await tester.pumpAndSettle();
      expect(find.byType(HyperosSwitch), findsOneWidget);
    });
  });

  group('HyperosSlider', () {
    testWidgets('renders HyperOS volume-style capsule track', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HyperosSlider(value: 0.5, onChanged: (_) {})),
        ),
      );

      final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(box.height, HyperosMiuixSlider.minHeight);

      final sliderTheme = tester.widget<SliderTheme>(
        find.descendant(
          of: find.byType(HyperosSlider),
          matching: find.byType(SliderTheme),
        ),
      );
      expect(sliderTheme.data.trackHeight, HyperosMiuixSlider.minHeight);
      expect(
        sliderTheme.data.thumbShape,
        isA<RoundSliderThumbShape>().having(
          (shape) => shape.enabledThumbRadius,
          'enabledThumbRadius',
          HyperosMiuixSlider.thumbRadius,
        ),
      );
    });

    testWidgets('hides division tick marks when divisions is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosSlider(
              value: 0.5,
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final sliderTheme = tester.widget<SliderTheme>(
        find.descendant(
          of: find.byType(HyperosSlider),
          matching: find.byType(SliderTheme),
        ),
      );
      expect(sliderTheme.data.tickMarkShape, SliderTickMarkShape.noTickMark);
    });

    testWidgets('adds card bottom inset when last tile in HyperosControlCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosControlCard(
              subtitle: 'Speed',
              edgeToEdge: true,
              child: HyperosSliderTile(
                title: 'Transition',
                value: 0.5,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(HyperosSlider),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding == _sliderTilePaddingForTest(
                  bottom: HyperosControlCardScope.defaultBodyBottomInset,
                ),
          ),
        ),
      );
      expect(
        padding.padding,
        _sliderTilePaddingForTest(
          bottom: HyperosControlCardScope.defaultBodyBottomInset,
        ),
      );
    });

    testWidgets('omits card bottom inset between stacked slider tiles', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosControlCard(
              edgeToEdge: true,
              child: HyperosControlCardRows(
                children: [
                  HyperosSliderTile(
                    title: 'First',
                    value: 0.2,
                    onChanged: (_) {},
                  ),
                  HyperosSliderTile(
                    title: 'Last',
                    value: 0.8,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(HyperosControlCard),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding &&
                    widget.child is Column &&
                    find
                        .descendant(
                          of: find.byWidget(widget),
                          matching: find.byType(HyperosSlider),
                        )
                        .evaluate()
                        .isNotEmpty,
              ),
            ),
          )
          .toList(growable: false);

      expect(paddings, hasLength(2));
      expect(paddings.first.padding, _sliderTilePaddingForTest());
      expect(
        paddings.last.padding,
        _sliderTilePaddingForTest(
          bottom: HyperosControlCardScope.defaultBodyBottomInset,
        ),
      );
    });

    testWidgets('shows chevron when slider tile supports tap editing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HyperosSliderTile(
              title: 'Font size',
              value: 9,
              valueLabel: '9.0',
              min: 7,
              max: 12,
              divisions: 10,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(HyperosChevron), findsOneWidget);
    });

    testWidgets('tap editing dialog updates slider value', (tester) async {
      var value = 9.0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: HyperosSliderTile(
                  title: 'Font size',
                  value: value,
                  min: 7,
                  max: 12,
                  divisions: 10,
                  onChanged: (next) => setState(() => value = next),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Font size'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '10.3');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(value, 10.5);
    });
  });

  group('HyperosControlCard', () {
    testWidgets('shows title and child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosControlCard(
              title: 'Layout',
              subtitle: 'Adjust spacing',
              child: const HyperosControlCardInset(child: Text('body')),
            ),
          ),
        ),
      );

      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Adjust spacing'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('spans list width when child is intrinsically narrow', (
      tester,
    ) async {
      const listWidth = 360.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(listWidth, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                HyperosControlCard(
                  title: 'Background',
                  subtitle: 'Pick a color',
                  child: HyperosControlCardInset(
                    child: Wrap(
                      children: List.generate(
                        6,
                        (_) => const SizedBox(width: 42, height: 42),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final cardRect = tester.getRect(find.byType(HyperosControlCard));
      expect(cardRect.width, listWidth);
    });

    testWidgets('headerless card applies uniform body padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosControlCard(
              child: HyperosHexColorChipGroup(
                colorHexes: const ['#FF0000', '#00FF00'],
                selectedHex: '#FF0000',
                colorParser: (hex) => Colors.red,
                onSelectedHex: (_) {},
              ),
            ),
          ),
        ),
      );

      final cardRect = tester.getRect(find.byType(HyperosControlCard));
      final chipRect = tester.getRect(find.byType(HyperosColorChip).first);

      expect(
        chipRect.left - cardRect.left,
        HyperosControlCardScope.defaultHorizontalPadding,
      );
      expect(
        chipRect.top - cardRect.top,
        HyperosControlCardScope.defaultHorizontalPadding,
      );
    });

    testWidgets('appearance background chips align with footnote inset', (
      tester,
    ) async {
      const footnote =
          'Only affects the large background of the timetable page.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HyperosHexColorChipGroup(
                        colorHexes: const ['#F8FAFC', '#F7F7F5'],
                        selectedHex: '#F8FAFC',
                        colorParser: (hex) => Colors.white,
                        onSelectedHex: (_) {},
                      ),
                      const SizedBox(height: 8),
                      Text(footnote),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final chipRect = tester.getRect(find.byType(HyperosColorChip).first);
      final textRect = tester.getRect(find.text(footnote));

      expect(chipRect.left, textRect.left);
    });

    testWidgets('distributed color chips have equal edge gaps', (tester) async {
      const listWidth = 360.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(listWidth, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: HyperosHexColorChipGroup(
                    colorHexes: const [
                      '#F8FAFC',
                      '#F7F7F5',
                      '#FDF6EC',
                      '#F2F7FF',
                      '#F5F3FF',
                      '#ECFDF5',
                    ],
                    selectedHex: '#F8FAFC',
                    colorParser: (hex) => Colors.white,
                    onSelectedHex: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final paddedRect = tester.getRect(
        find.descendant(
          of: find.byType(HyperosListGroup),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding && widget.padding == const EdgeInsets.all(16),
          ),
        ),
      );
      final firstChip = tester.getRect(find.byType(HyperosColorChip).first);
      final lastChip = tester.getRect(find.byType(HyperosColorChip).last);

      final leftGap = firstChip.left - paddedRect.left;
      final rightGap = paddedRect.right - lastChip.right;
      expect(leftGap, closeTo(rightGap, 1));
    });
  });

  group('HyperosButton', () {
    testWidgets('primary button fires onPressed', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosButton(label: 'Save', onPressed: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('loading disables tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosButton(
              label: 'Save',
              loading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HyperosButton));
      await tester.pump();
      expect(tapped, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

EdgeInsets _sliderTilePaddingForTest({double bottom = 0}) {
  return EdgeInsets.fromLTRB(
    HyperosControlCardScope.defaultHorizontalPadding,
    0,
    HyperosControlCardScope.defaultHorizontalPadding,
    bottom,
  );
}
